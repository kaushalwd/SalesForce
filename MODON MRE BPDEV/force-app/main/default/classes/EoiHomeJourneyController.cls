/**********************************************************************************************************************
* Name               : EoiHomeJourneyController
* Description        : Apex controller for the Home Page EOI journey
* Usage              : Supports customer identification, opportunity preparation, EOI creation, and project quota checks
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial EOI Home journey controller
* 1.1           Prateek Bansal                    13 May 2026     Guarded dynamic SOQL filters for BPDev field metadata
* 1.2           Prateek Bansal                    13 May 2026     Excluded broker agency and broker agent records
* 1.3           Prateek Bansal                    14 May 2026     Create and convert Lead for existing and new customers
* 1.4           Prateek Bansal                    14 May 2026     Support optional unit typology during EOI selection
* 1.5           Prateek Bansal                    15 May 2026     Store selected payment type on EOI records
* 1.6           Prateek Bansal                    15 May 2026     Capture resident-specific document expiry dates
* 1.7           Aurelix Dev                       03 Sep 2026     MSC-230. validateEOI counts pay-first links awaiting
*                                                                 payment toward the project quota (EoiQuotaGuard)
* 1.8           Rushi Patel                       12 Sep 2026     Ranges must also be published to the Sales channel:
*                                                                 getProjects and getEoiRangeMatrix now require
*                                                                 Show_On__c INCLUDES 'Sales' alongside Is_Active__c
**********************************************************************************************************************/
public without sharing class EoiHomeJourneyController {
    public class EoiPublicException extends Exception {}

    // v1.8 - the Show_On__c channel this journey publishes from. A range must name this channel
    // to appear here, matching how the invite and Par Typology journeys filter their own.
    private static final String SHOW_ON_SALES = 'Sales';

    @AuraEnabled
    public static CustomerSearchResult searchCustomer(CustomerRequest request) {
        CustomerSearchResult result = new CustomerSearchResult();
        result.matches = new List<CustomerMatch>();

        if (request == null || !hasAnyIdentifier(request)) {
            result.sourceType = Constants.EOI_HOME_SOURCE_TYPE_NEW;
            result.isEditable = true;
            attachSearchDebug(result, request, new List<SObject>(), new List<SObject>());
            return result;
        }

        List<SObject> personAccounts = queryMatchingAccounts(request);
        List<SObject> organizationAccounts = queryMatchingOrganizationAccounts(request);
        Map<Id, SObject> matchedContactByAccountId = queryMatchingOrganizationContacts(request);
        List<SObject> accounts = new List<SObject>();
        accounts.addAll(personAccounts);
        accounts.addAll(organizationAccounts);
        Map<Id, Boolean> portalByAccountId = getPortalUserMap(accounts);
        for (SObject accountRecord : personAccounts) {
            result.matches.add(toAccountMatch(accountRecord, portalByAccountId));
        }
        for (SObject accountRecord : organizationAccounts) {
            result.matches.add(toOrganizationAccountMatch(accountRecord, portalByAccountId, matchedContactByAccountId.get((Id) accountRecord.get('Id'))));
        }

        // Existing Lead lookup is intentionally skipped for this journey.
        // If Lead matching is needed later, re-enable this block:
        // List<SObject> leads = queryMatchingLeads(request);
        // System.debug(LoggingLevel.ERROR, '[EOI_HOME] searchCustomer leadIds=' + JSON.serialize(toIdStrings(leads)));
        // for (SObject leadRecord : leads) {
        //     result.matches.add(toLeadMatch(leadRecord));
        // }
        List<SObject> leads = new List<SObject>();

        CustomerMatch selected = chooseBestMatch(result.matches);
        if (selected == null) {
            result.sourceType = Constants.EOI_HOME_SOURCE_TYPE_NEW;
            result.isEditable = true;
        } else {
            result.selected = selected;
            result.sourceType = selected.sourceType;
            result.isEditable = selected.sourceType == Constants.EOI_HOME_SOURCE_TYPE_LEAD;
        }
        attachSearchDebug(result, request, accounts, leads);
        return result;
    }

    @AuraEnabled
    public static OpportunityResult prepareOpportunity(CustomerRequest request) {
        if (request == null) {
            throw new EoiPublicException('Customer details are required.');
        }
        assertProjectCanAcceptEoi(request.projectId);

        Id leadId = request.leadId;
        if (leadId == null) {
            if (request.skipFrontendValidation != true) validateCustomerForLead(request);
            assertProjectCanAcceptEoi(request.projectId);
            if (request.accountId == null) assertNoExistingAccountForNewCustomer(request);
            leadId = createLead(request);
        } else {
            assertProjectCanAcceptEoi(request.projectId);
            updateLeadFromRequest(leadId, request);
        }

        Id contactId = request.contactId;
        if (request.accountId != null && isOrganization(request) && contactId == null) {
            contactId = findOrCreateOrganizationContact(request);
        }
        assertProjectCanAcceptEoi(request.projectId);
        return convertLeadToOpportunity(leadId, request.accountId, contactId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getProjects() {
        Map<Id, String> seen = new Map<Id, String>();
        for (SObject row : queryRows(
            'SELECT Project__c, Project__r.Name FROM EOI_Range__c ' +
            'WHERE Is_Active__c = true AND Project__c != null ' +
            'AND Show_On__c INCLUDES (:showOn) ' + // v1.8
            'ORDER BY Project__r.Name ASC',
            new Map<String, Object>{ 'showOn' => SHOW_ON_SALES }
        )) {
            Id projectId = (Id) row.get('Project__c');
            SObject project = row.getSObject('Project__r');
            if (projectId != null && !seen.containsKey(projectId)) {
                seen.put(projectId, getString(project, 'Name'));
            }
        }
        return toSortedOptions(seen);
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getPhases(Id projectId) {
        Map<Id, String> seen = new Map<Id, String>();
        for (SObject row : queryRows(
            'SELECT Phase__c, Phase__r.Name FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Is_Active__c = true AND Phase__c != null ' +
            'ORDER BY Phase__r.Name ASC',
            new Map<String, Object>{ 'projectId' => projectId }
        )) {
            Id phaseId = (Id) row.get('Phase__c');
            SObject phase = row.getSObject('Phase__r');
            if (phaseId != null && !seen.containsKey(phaseId)) {
                seen.put(phaseId, getString(phase, 'Name'));
            }
        }
        return toSortedOptions(seen);
    }

    @AuraEnabled(cacheable=true)
    public static List<EOIRangeMatrixRow> getEoiRangeMatrix(Id projectId) {
        List<EOIRangeMatrixRow> matrix = new List<EOIRangeMatrixRow>();
        Boolean hasTypologyField = hasField('EOI_Range__c', 'UnitTypologyMRE__c');
        String queryText =
            'SELECT Id, Project__c, Phase__c, Phase__r.Name, Unit_Type__c, No_of_Bedrooms__c, Amount__c' +
            (hasTypologyField ? ', UnitTypologyMRE__c ' : ' ') +
            'FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Is_Active__c = true ' +
            'AND Show_On__c INCLUDES (:showOn) ' + // v1.8
            'ORDER BY Phase__r.Name ASC, Unit_Type__c ASC, No_of_Bedrooms__c ASC';

        for (SObject row : queryRows(queryText, new Map<String, Object>{
            'projectId' => projectId, 'showOn' => SHOW_ON_SALES
        })) {
            EOIRangeMatrixRow item = new EOIRangeMatrixRow();
            item.rangeId = (Id) row.get('Id');
            item.projectId = (Id) row.get('Project__c');
            item.phaseId = (Id) row.get('Phase__c');
            item.phaseName = getString(row.getSObject('Phase__r'), 'Name');
            item.unitType = getString(row, 'Unit_Type__c');
            item.bedrooms = getString(row, 'No_of_Bedrooms__c');
            item.amount = (Decimal) row.get('Amount__c');
            if (hasTypologyField) item.unitTypology = getString(row, 'UnitTypologyMRE__c');
            matrix.add(item);
        }
        return matrix;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getUnitTypes(Id projectId, Id phaseId) {
        List<Option> options = new List<Option>();
        // SOQL injection fix: portal Ids/params via queryWithBinds.
        for (AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
            'SELECT Unit_Type__c value FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Phase__c = :phaseId AND Is_Active__c = true ' +
            'GROUP BY Unit_Type__c ORDER BY Unit_Type__c ASC',
            new Map<String, Object>{ 'projectId' => projectId, 'phaseId' => phaseId },
            AccessLevel.SYSTEM_MODE
        )) {
            String value = (String) row.get('value');
            options.add(new Option(value, value));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getBedrooms(Id projectId, Id phaseId, String unitType) {
        List<Option> options = new List<Option>();
        for (AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
            'SELECT No_of_Bedrooms__c value FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Phase__c = :phaseId ' +
            'AND Unit_Type__c = :unitType AND Is_Active__c = true ' +
            'GROUP BY No_of_Bedrooms__c ORDER BY No_of_Bedrooms__c ASC',
            new Map<String, Object>{
                'projectId' => projectId,
                'phaseId' => phaseId,
                'unitType' => unitType
            },
            AccessLevel.SYSTEM_MODE
        )) {
            String value = (String) row.get('value');
            options.add(new Option(value, value));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static EOIRangeResult getEOIRange(Id projectId, Id phaseId, String unitType, String bedrooms) {
        return getEOIRangeByTypology(projectId, phaseId, unitType, bedrooms, null);
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getUnitTypologies(Id projectId, Id phaseId, String unitType, String bedrooms) {
        List<Option> options = new List<Option>();
        if (!hasField('EOI_Range__c', 'UnitTypologyMRE__c')) return options;

        for (AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
            'SELECT UnitTypologyMRE__c value FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Phase__c = :phaseId ' +
            'AND Unit_Type__c = :unitType AND No_of_Bedrooms__c = :bedrooms ' +
            'AND Is_Active__c = true AND UnitTypologyMRE__c != null ' +
            'GROUP BY UnitTypologyMRE__c ORDER BY UnitTypologyMRE__c ASC',
            new Map<String, Object>{
                'projectId' => projectId,
                'phaseId' => phaseId,
                'unitType' => unitType,
                'bedrooms' => bedrooms
            },
            AccessLevel.SYSTEM_MODE
        )) {
            String value = (String) row.get('value');
            if (String.isNotBlank(value)) options.add(new Option(value, value));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static EOIRangeResult getEOIRangeByTypology(Id projectId, Id phaseId, String unitType, String bedrooms, String unitTypology) {
        Boolean hasTypologyField = hasField('EOI_Range__c', 'UnitTypologyMRE__c');
        String queryText =
            'SELECT Id, Amount__c' + (hasTypologyField ? ', UnitTypologyMRE__c ' : ' ') +
            'FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId AND Phase__c = :phaseId ' +
            'AND Unit_Type__c = :unitType AND No_of_Bedrooms__c = :bedrooms ' +
            'AND Is_Active__c = true ';
        if (hasTypologyField) {
            queryText += String.isBlank(unitTypology)
                ? 'AND UnitTypologyMRE__c = null '
                : 'AND UnitTypologyMRE__c = :unitTypology ';
        }
        queryText += 'LIMIT 1';

        List<SObject> rows = queryRows(
            queryText,
            new Map<String, Object>{
                'projectId' => projectId,
                'phaseId' => phaseId,
                'unitType' => unitType,
                'bedrooms' => bedrooms,
                'unitTypology' => unitTypology
            }
        );
        if (rows.isEmpty()) return null;

        EOIRangeResult result = new EOIRangeResult();
        result.rangeId = (Id) rows[0].get('Id');
        result.amount = (Decimal) rows[0].get('Amount__c');
        if (hasTypologyField) result.unitTypology = getString(rows[0], 'UnitTypologyMRE__c');
        return result;
    }

    @AuraEnabled
    public static ValidationResult validateEOI(Id opportunityId, Id projectId) {
        ValidationResult result = new ValidationResult();
        if (opportunityId != null) {
            List<SObject> existing = queryRows(
                'SELECT Id, Name FROM Expressionofinterest__c WHERE Opportunity__c = :opportunityId LIMIT 1',
                new Map<String, Object>{ 'opportunityId' => opportunityId }
            );
            if (!existing.isEmpty()) {
                result.isDuplicate = true;
                result.existingEOIRef = getString(existing[0], 'Name');
                return result;
            }
        }

        if (projectId != null) {
            Integer limitVal = 0;
            List<SObject> projects = queryRows(
                'SELECT EOI_Limit__c FROM Project__c WHERE Id = :projectId LIMIT 1',
                new Map<String, Object>{ 'projectId' => projectId }
            );
            if (!projects.isEmpty() && projects[0].get('EOI_Limit__c') != null) {
                limitVal = ((Decimal) projects[0].get('EOI_Limit__c')).intValue();
            }
            Integer used = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Expressionofinterest__c WHERE Project__c = :projectId',
                new Map<String, Object>{ 'projectId' => projectId },
                AccessLevel.SYSTEM_MODE
            );
            // MSC-230: pay-first links awaiting payment reserve quota - no EOI row exists
            // until the payment captures, so live links must count or reps can over-send.
            // Expired links free their slot automatically (they drop out of the count).
            Integer pendingLinks = EoiQuotaGuard.pendingLinkCount(projectId);
            result.quotaLimit = limitVal;
            result.quotaUsed = used + pendingLinks;
            result.quotaRemaining = limitVal - result.quotaUsed;
            result.quotaExceeded = limitVal > 0 && result.quotaUsed >= limitVal;
        }
        return result;
    }

    private static void assertProjectCanAcceptEoi(Id projectId) {
        ValidationResult validation = validateEOI(null, projectId);
        if (validation.quotaExceeded == true) {
            throw new EoiPublicException('EOI submission is closed for the selected project. Limit '
                + validation.quotaLimit + ' has already been reached.');
        }
    }

    @AuraEnabled
    public static JourneyResult createEoiAndOptionalReceipt(EOIRequest request) {
        if (request == null || request.opportunityId == null) {
            throw new EoiPublicException('Opportunity is required before creating EOI.');
        }

        // Support creating multiple EOI records under the same prepared Opportunity.
        List<EOISelectionRequest> selections = getEoiSelections(request);
        validateEoiSelections(request, selections);

        List<Id> eoiIds = createEois(request, selections);
        JourneyResult result = new JourneyResult();
        result.eoiId = eoiIds.isEmpty() ? null : eoiIds[0];
        result.eoiIds = eoiIds;
        result.opportunityId = request.opportunityId;
        populateJourneySummary(result, eoiIds, request.opportunityId);
        // EOI creation notifications and payment reminders are queued by EOITriggerHandler.afterInsert.

        return result;
    }

    private static List<Id> createEois(EOIRequest request, List<EOISelectionRequest> selections) {
        SObjectType eoiType = Schema.getGlobalDescribe().get('Expressionofinterest__c');
        if (eoiType == null) {
            throw new EoiPublicException('Expression of Interest object is not available.');
        }

        Id opportunityId = request.opportunityId;
        List<SObject> opportunities = queryRows(
            'SELECT Id, AccountId, ContactId FROM Opportunity WHERE Id = :opportunityId LIMIT 1',
            new Map<String, Object>{ 'opportunityId' => opportunityId }
        );
        if (opportunities.isEmpty()) {
            throw new EoiPublicException('Opportunity was not found.');
        }

        SObject opportunityRecord = opportunities[0];
        List<SObject> eois = new List<SObject>();
        for (EOISelectionRequest selection : selections) {
            // Each selection creates exactly one EOI; Number_of_Units__c is intentionally fixed to 1.
            SObject eoi = eoiType.newSObject();
            putIfFieldExists(eoi, 'Opportunity__c', request.opportunityId);
            putIfFieldExists(eoi, 'Project__c', request.projectId);
            putIfFieldExists(eoi, 'Phase__c', selection.phaseId);
            putIfFieldExists(eoi, 'UnitType__c', selection.unitType);
            putIfFieldExists(eoi, 'NumberofBedrooms__c', selection.bedrooms);
            putIfFieldExists(eoi, 'UnitTypologyMRE__c', selection.unitTypology);
            putIfFieldExists(eoi, 'Number_of_Units__c', Constants.EOI_HOME_NUMBER_OF_UNITS);
            putIfFieldExists(eoi, 'EOI_Range__c', selection.eoiRangeId);
            putIfFieldExists(eoi, 'EOI_Amount_AED__c', selection.eoiAmount);
            putIfFieldExists(eoi, 'Payment_Type__c', request.paymentType);
            putIfFieldExists(eoi, 'EOIComments__c', request.remarks);
            putIfFieldExists(eoi, 'Account__c', opportunityRecord.get('AccountId'));
            putIfFieldExists(eoi, 'Contact__c', safeGet(opportunityRecord, 'ContactId'));
            eois.add(eoi);
        }
        safeInsert(eois);

        List<Id> eoiIds = new List<Id>();
        for (SObject eoi : eois) eoiIds.add((Id) eoi.get('Id'));
        return eoiIds;
    }

    private static void populateJourneySummary(JourneyResult result, List<Id> eoiIds, Id opportunityId) {
        result.eoiReferences = new List<String>();
        List<String> eoiFields = new List<String>{ 'Id' };
        if (hasField('Expressionofinterest__c', 'EOIId__c')) eoiFields.add('EOIId__c');
        List<SObject> eoiRows = queryRows(
            'SELECT ' + String.join(eoiFields, ', ') + ' FROM Expressionofinterest__c WHERE Id IN :eoiIds ORDER BY CreatedDate ASC',
            new Map<String, Object>{ 'eoiIds' => eoiIds }
        );
        for (SObject eoiRow : eoiRows) {
            String reference = String.isNotBlank(getString(eoiRow, 'EOIId__c'))
                ? getString(eoiRow, 'EOIId__c')
                : String.valueOf(eoiRow.get('Id'));
            result.eoiReferences.add(reference);
        }
        if (!result.eoiReferences.isEmpty()) result.eoiReference = result.eoiReferences[0];

        List<SObject> opportunityRows = queryRows(
            'SELECT AccountId, Account.Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1',
            new Map<String, Object>{ 'opportunityId' => opportunityId }
        );
        if (!opportunityRows.isEmpty()) {
            result.accountId = (Id) opportunityRows[0].get('AccountId');
            SObject accountRecord = opportunityRows[0].getSObject('Account');
            result.accountName = getString(accountRecord, 'Name');
        }
    }

    private static List<EOISelectionRequest> getEoiSelections(EOIRequest request) {
        List<EOISelectionRequest> selections = request.selections == null
            ? new List<EOISelectionRequest>()
            : request.selections;
        if (!selections.isEmpty()) return selections;

        EOISelectionRequest fallback = new EOISelectionRequest();
        fallback.phaseId = request.phaseId;
        fallback.unitType = request.unitType;
        fallback.bedrooms = request.bedrooms;
        fallback.unitTypology = request.unitTypology;
        fallback.eoiRangeId = request.eoiRangeId;
        fallback.eoiAmount = request.eoiAmount;
        return new List<EOISelectionRequest>{ fallback };
    }

    private static void validateEoiSelections(EOIRequest request, List<EOISelectionRequest> selections) {
        if (selections.isEmpty()) throw new EoiPublicException('At least one EOI selection is required.');
        ValidationResult validation = validateEOI(null, request.projectId);
        Integer requestedCount = selections.size();
        if (validation.quotaLimit > 0 && requestedCount > validation.quotaRemaining) {
            throw new EoiPublicException('Only ' + validation.quotaRemaining + ' EOI submission(s) are remaining for this project.');
        }

        for (EOISelectionRequest selection : selections) {
            if (selection.phaseId == null) throw new EoiPublicException('Phase is required for each EOI.');
            if (String.isBlank(selection.unitType)) throw new EoiPublicException('Unit Type is required for each EOI.');
            if (String.isBlank(selection.bedrooms)) throw new EoiPublicException('Number of Bedrooms is required for each EOI.');
            if (selection.eoiRangeId == null) throw new EoiPublicException('EOI Range is required for each EOI.');
            if (selection.eoiAmount == null || selection.eoiAmount <= 0) throw new EoiPublicException('EOI Amount is required for each EOI.');
        }
    }

    private static Boolean hasAnyIdentifier(CustomerRequest request) {
        if (isOrganization(request)) {
            return String.isNotBlank(request.companyName)
                || String.isNotBlank(request.tradeLicenseNumber)
                || String.isNotBlank(request.registeredEmail)
                || String.isNotBlank(request.registeredPhone)
                || String.isNotBlank(request.authorizedEmail)
                || String.isNotBlank(request.authorizedPhone)
                || String.isNotBlank(request.email)
                || String.isNotBlank(request.phone);
        }
        return String.isNotBlank(request.email)
            || String.isNotBlank(request.phone)
            || String.isNotBlank(request.emiratesId)
            || String.isNotBlank(request.passportNumber);
    }

    private static void validateCustomerForLead(CustomerRequest request) {
        if (isOrganization(request)) {
            validateOrganizationForLead(request);
            return;
        }
        if (String.isBlank(request.firstName)) throw new EoiPublicException('First Name is required.');
        if (String.isBlank(request.lastName)) throw new EoiPublicException('Last Name is required.');
        if (String.isBlank(request.email)) throw new EoiPublicException('Email is required.');
        if (String.isBlank(request.phone)) throw new EoiPublicException('Phone is required.');
        if (String.isBlank(request.residentStatus)) throw new EoiPublicException('Resident Status is required.');
        if (String.isBlank(request.nationality)) throw new EoiPublicException('Nationality is required.');
        if (String.isBlank(request.countryOfResidence)) throw new EoiPublicException('Country of Residence is required.');
        if (String.isBlank(request.projectInterest)) throw new EoiPublicException('Project Interest is required.');
        if (isResident(request)) {
            if (String.isBlank(request.emiratesId)) {
                throw new EoiPublicException('Emirates ID is required for residents.');
            }
            if (String.isNotBlank(request.passportNumber) && !Pattern.matches('^[A-Za-z0-9]+$', request.passportNumber.trim())) {
                throw new EoiPublicException('Passport Number must contain letters and numbers only.');
            }
            return;
        }
        if (String.isBlank(request.passportNumber)) throw new EoiPublicException('Passport Number is required for non-residents.');
        if (!Pattern.matches('^[A-Za-z0-9]+$', request.passportNumber.trim())) {
            throw new EoiPublicException('Passport Number must contain letters and numbers only.');
        }
    }

    private static void validateOrganizationForLead(CustomerRequest request) {
        if (String.isBlank(request.companyName)) throw new EoiPublicException('Company Name is required.');
        if (String.isBlank(request.tradeLicenseNumber)) throw new EoiPublicException('Trade License Number is required.');
        if (String.isBlank(request.residentStatus)) throw new EoiPublicException('Resident Status is required.');
        if (isResident(request)) {
            if (String.isBlank(request.emiratesId)) {
                throw new EoiPublicException('Emirates ID is required for residents.');
            }
            if (String.isNotBlank(request.passportNumber) && !Pattern.matches('^[A-Za-z0-9]+$', request.passportNumber.trim())) {
                throw new EoiPublicException('Passport Number must contain letters and numbers only.');
            }
        } else {
            if (String.isBlank(request.passportNumber)) throw new EoiPublicException('Passport Number is required for non-residents.');
            if (!Pattern.matches('^[A-Za-z0-9]+$', request.passportNumber.trim())) {
                throw new EoiPublicException('Passport Number must contain letters and numbers only.');
            }
        }
        if (String.isBlank(request.authorizedFirstName)) throw new EoiPublicException('Authorized Contact First Name is required.');
        if (String.isBlank(request.authorizedLastName)) throw new EoiPublicException('Authorized Contact Last Name is required.');
        if (String.isBlank(request.authorizedEmail)) throw new EoiPublicException('Authorized Contact Email is required.');
        if (String.isBlank(request.authorizedPhone)) throw new EoiPublicException('Authorized Contact Phone is required.');
        if (String.isBlank(request.projectInterest)) throw new EoiPublicException('Project Interest is required.');
    }

    private static Boolean isOrganization(CustomerRequest request) {
        return request != null && String.isNotBlank(request.customerType)
            && request.customerType.trim().equalsIgnoreCase(Constants.EOI_HOME_CUSTOMER_TYPE_ORGANIZATION);
    }

    private static Boolean isResident(CustomerRequest request) {
        return String.isNotBlank(request.residentStatus)
            && request.residentStatus.trim().equalsIgnoreCase(Constants.RESIDENT);
    }

    private static String normaliseResidentStatusForLead(String value) {
        if (String.isBlank(value)) return value;
        return value.trim().equalsIgnoreCase('Non Resident') ? 'Non-Resident' : value;
    }

    private static void assertNoExistingAccountForNewCustomer(CustomerRequest request) {
        if (request == null || request.accountId != null || !hasAnyIdentifier(request)) return;
        List<SObject> accounts = new List<SObject>();
        accounts.addAll(queryMatchingAccounts(request));
        accounts.addAll(queryMatchingOrganizationAccounts(request));
        if (!accounts.isEmpty()) {
            throw new EoiPublicException('An existing customer account was found using the entered details. Please verify identity again and select the existing customer account.');
        }
    }

    private static List<SObject> queryMatchingAccounts(CustomerRequest request) {
        List<String> selectFields = new List<String>{ 'Id', 'Name', 'Phone', 'CreatedDate' };
        for (String fieldName : new List<String>{ 'FirstName', 'LastName', 'PersonEmail', 'PersonMobilePhone', 'PersonContactId', 'EIDNumber__pc', 'EmiratesIDExpiryDate__pc', 'PassportNumber__pc', 'PassportExpiryDate__pc', 'UAE_Resident_Status__pc', 'Nationality__pc', 'CountryOfResidence__pc' }) {
            if (hasField('Account', fieldName)) selectFields.add(fieldName);
        }

        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        Set<String> eids = new Set<String>();
        Set<String> passports = new Set<String>();
        if (String.isNotBlank(request.email)) emails.add(request.email.trim().toLowerCase());
        if (String.isNotBlank(request.phone)) phones.add(normalisePhone(request.phone));
        if (String.isNotBlank(request.emiratesId)) eids.add(request.emiratesId.trim());
        if (String.isNotBlank(request.passportNumber)) passports.add(request.passportNumber.trim());
        List<String> ors = new List<String>();
        if (!emails.isEmpty() && hasField('Account', 'PersonEmail')) ors.add('PersonEmail IN :emails');
        if (!phones.isEmpty()) {
            List<String> phoneFields = new List<String>{ 'Phone IN :phones' };
            if (hasField('Account', 'PersonMobilePhone')) phoneFields.add('PersonMobilePhone IN :phones');
            ors.add('(' + String.join(phoneFields, ' OR ') + ')');
        }
        if (!eids.isEmpty() && hasField('Account', 'EIDNumber__pc')) ors.add('EIDNumber__pc IN :eids');
        if (!passports.isEmpty() && hasField('Account', 'PassportNumber__pc')) ors.add('PassportNumber__pc IN :passports');
        if (ors.isEmpty()) {
            return new List<SObject>();
        }

        List<String> whereParts = new List<String>{ '(' + String.join(ors, ' OR ') + ')' };
        if (hasField('Account', 'IsPersonAccount')) whereParts.add('IsPersonAccount = TRUE');
        if (hasField('Account', 'Is_Merged__c')) whereParts.add('Is_Merged__c = FALSE');

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM Account WHERE ' +
            String.join(whereParts, ' AND ') + ' ORDER BY CreatedDate DESC LIMIT 20';
        List<SObject> rows = queryRows(
            soql,
            new Map<String, Object>{
                'emails' => emails,
                'phones' => phones,
                'eids' => eids,
                'passports' => passports
            }
        );
        return rows;
    }

    private static List<SObject> queryMatchingOrganizationAccounts(CustomerRequest request) {
        List<String> selectFields = new List<String>{ 'Id', 'Name', 'Phone', 'CreatedDate' };
        for (String fieldName : new List<String>{
            'TradeLicenseNumber__c',
            'En_TradeLicenseNumber__c',
            'UnifiedNumber__c',
            'Company_Email_Address__c',
            'Company_MobileNumberTRD__c',
            'IsPersonAccount'
        }) {
            if (hasField('Account', fieldName)) selectFields.add(fieldName);
        }

        Set<String> tradeLicenses = new Set<String>();
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        if (String.isNotBlank(request.tradeLicenseNumber)) tradeLicenses.add(request.tradeLicenseNumber.trim());
        if (String.isNotBlank(request.registeredEmail)) emails.add(request.registeredEmail.trim().toLowerCase());
        if (String.isNotBlank(request.authorizedEmail)) emails.add(request.authorizedEmail.trim().toLowerCase());
        if (String.isNotBlank(request.email)) emails.add(request.email.trim().toLowerCase());
        if (String.isNotBlank(request.registeredPhone)) phones.add(normalisePhone(request.registeredPhone));
        if (String.isNotBlank(request.authorizedPhone)) phones.add(normalisePhone(request.authorizedPhone));
        if (String.isNotBlank(request.phone)) phones.add(normalisePhone(request.phone));
        // Bind-safe LIKE pattern (escapeSingleQuotes not needed / harmful when using binds).
        String companyNameLike = String.isBlank(request.companyName) ? null : '%' + request.companyName.trim() + '%';

        List<String> ors = new List<String>();
        if (!tradeLicenses.isEmpty()) {
            List<String> tradeFields = new List<String>();
            for (String fieldName : new List<String>{ 'TradeLicenseNumber__c', 'En_TradeLicenseNumber__c', 'UnifiedNumber__c' }) {
                // v1.1: Some BPDev fields exist but are not filterable, so only use SOQL-safe fields in WHERE.
                if (hasFilterableField('Account', fieldName)) tradeFields.add(fieldName + ' IN :tradeLicenses');
            }
            if (!tradeFields.isEmpty()) ors.add('(' + String.join(tradeFields, ' OR ') + ')');
        }
        if (!emails.isEmpty() && hasFilterableField('Account', 'Company_Email_Address__c')) ors.add('Company_Email_Address__c IN :emails');
        if (!phones.isEmpty()) {
            List<String> phoneFields = new List<String>();
            if (hasFilterableField('Account', 'Phone')) phoneFields.add('Phone IN :phones');
            if (hasFilterableField('Account', 'Company_MobileNumberTRD__c')) phoneFields.add('Company_MobileNumberTRD__c IN :phones');
            if (!phoneFields.isEmpty()) ors.add('(' + String.join(phoneFields, ' OR ') + ')');
        }
        if (String.isNotBlank(companyNameLike) && hasFilterableField('Account', 'Name')) ors.add('Name LIKE :companyNameLike');
        Set<Id> contactAccountIds = queryMatchingOrganizationContactAccountIds(request);
        if (!contactAccountIds.isEmpty()) ors.add('Id IN :contactAccountIds');
        if (ors.isEmpty()) return new List<SObject>();

        List<String> whereParts = new List<String>{ '(' + String.join(ors, ' OR ') + ')' };
        if (hasField('Account', 'IsPersonAccount')) whereParts.add('IsPersonAccount = FALSE');
        if (hasField('Account', 'Is_Merged__c')) whereParts.add('Is_Merged__c = FALSE');
        // v1.2: Broker agencies are sales-channel records, not EOI customers.
        if (hasField('Account', 'RecordTypeId')) whereParts.add('RecordType.DeveloperName NOT IN :excludedOrgAccountRecordTypes');

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM Account WHERE '
            + String.join(whereParts, ' AND ') + ' ORDER BY CreatedDate DESC LIMIT 20';
        return queryRows(
            soql,
            new Map<String, Object>{
                'tradeLicenses' => tradeLicenses,
                'emails' => emails,
                'phones' => phones,
                'companyNameLike' => companyNameLike,
                'contactAccountIds' => contactAccountIds,
                'excludedOrgAccountRecordTypes' => Constants.EOI_HOME_EXCLUDED_ORG_ACCOUNT_RECORD_TYPES
            }
        );
    }

    private static Set<Id> queryMatchingOrganizationContactAccountIds(CustomerRequest request) {
        return queryMatchingOrganizationContacts(request).keySet();
    }

    private static Map<Id, SObject> queryMatchingOrganizationContacts(CustomerRequest request) {
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        if (String.isNotBlank(request.registeredEmail)) emails.add(request.registeredEmail.trim().toLowerCase());
        if (String.isNotBlank(request.authorizedEmail)) emails.add(request.authorizedEmail.trim().toLowerCase());
        if (String.isNotBlank(request.email)) emails.add(request.email.trim().toLowerCase());
        if (String.isNotBlank(request.registeredPhone)) phones.add(normalisePhone(request.registeredPhone));
        if (String.isNotBlank(request.authorizedPhone)) phones.add(normalisePhone(request.authorizedPhone));
        if (String.isNotBlank(request.phone)) phones.add(normalisePhone(request.phone));

        List<String> ors = new List<String>();
        if (!emails.isEmpty()) ors.add('Email IN :emails');
        if (!phones.isEmpty()) ors.add('(MobilePhone IN :phones OR Phone IN :phones)');
        if (ors.isEmpty()) return new Map<Id, SObject>();

        String accountTypeFilter = hasField('Account', 'IsPersonAccount') ? ' AND Account.IsPersonAccount = FALSE' : '';
        // v1.2: Exclude broker contacts and contacts under broker agency accounts from customer identity matching.
        String brokerFilter = '';
        if (hasField('Account', 'RecordTypeId')) brokerFilter += ' AND Account.RecordType.DeveloperName NOT IN :excludedOrgAccountRecordTypes';
        if (hasField('Contact', 'RecordTypeId')) brokerFilter += ' AND RecordType.DeveloperName NOT IN :excludedOrgContactRecordTypes';
        List<SObject> contacts = queryRows(
            'SELECT Id, AccountId, FirstName, LastName, Name, Email, MobilePhone, Phone ' +
            'FROM Contact WHERE AccountId != null AND (' + String.join(ors, ' OR ') + ')' + accountTypeFilter + brokerFilter +
            ' ORDER BY CreatedDate DESC LIMIT 20',
            new Map<String, Object>{
                'emails' => emails,
                'phones' => phones,
                'excludedOrgAccountRecordTypes' => Constants.EOI_HOME_EXCLUDED_ORG_ACCOUNT_RECORD_TYPES,
                'excludedOrgContactRecordTypes' => Constants.EOI_HOME_EXCLUDED_ORG_CONTACT_RECORD_TYPES
            }
        );
        Map<Id, SObject> contactByAccountId = new Map<Id, SObject>();
        for (SObject contactRecord : contacts) {
            Id accountId = (Id) contactRecord.get('AccountId');
            if (accountId != null && !contactByAccountId.containsKey(accountId)) {
                contactByAccountId.put(accountId, contactRecord);
            }
        }
        return contactByAccountId;
    }

    private static List<SObject> queryMatchingLeads(CustomerRequest request) {
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        Set<String> eids = new Set<String>();
        Set<String> passports = new Set<String>();
        if (String.isNotBlank(request.email)) emails.add(request.email.trim().toLowerCase());
        if (String.isNotBlank(request.phone)) phones.add(normalisePhone(request.phone));
        if (String.isNotBlank(request.emiratesId)) eids.add(request.emiratesId.trim());
        if (String.isNotBlank(request.passportNumber)) passports.add(request.passportNumber.trim());
        List<String> ors = new List<String>();
        if (!emails.isEmpty()) ors.add('Email IN :emails');
        if (!phones.isEmpty()) ors.add('(MobilePhone IN :phones OR Phone IN :phones)');
        if (!eids.isEmpty() && hasField('Lead', 'EIDNumber__c')) ors.add('EIDNumber__c IN :eids');
        if (!passports.isEmpty() && hasField('Lead', 'PassportNumber__c')) ors.add('PassportNumber__c IN :passports');
        if (ors.isEmpty()) {
            return new List<SObject>();
        }

        List<String> fields = new List<String>{ 'Id', 'FirstName', 'LastName', 'Name', 'Email', 'MobilePhone', 'Phone', 'CreatedDate' };
        for (String fieldName : new List<String>{ 'EIDNumber__c', 'EmiratesIDExpiryDate__c', 'PassportNumber__c', 'PassportExpiryDate__c', 'UAEResidentStatus__c', 'Nationality__c', 'CountryOfResidence__c' }) {
            if (hasField('Lead', fieldName)) fields.add(fieldName);
        }
        String soql = 'SELECT ' + String.join(fields, ', ') + ' FROM Lead WHERE IsConverted = FALSE AND (' +
            String.join(ors, ' OR ') + ') ORDER BY CreatedDate DESC LIMIT 20';
        List<SObject> rows = queryRows(
            soql,
            new Map<String, Object>{
                'emails' => emails,
                'phones' => phones,
                'eids' => eids,
                'passports' => passports
            }
        );
        return rows;
    }

    private static Map<Id, Boolean> getPortalUserMap(List<SObject> accounts) {
        Map<Id, Id> contactToAccount = new Map<Id, Id>();
        Set<Id> organizationAccountIds = new Set<Id>();
        for (SObject accountRecord : accounts) {
            Id contactId = (Id) safeGet(accountRecord, 'PersonContactId');
            if (contactId != null) contactToAccount.put(contactId, (Id) accountRecord.get('Id'));
            if (contactId == null) organizationAccountIds.add((Id) accountRecord.get('Id'));
        }

        Map<Id, Boolean> portalByAccountId = new Map<Id, Boolean>();
        if (!contactToAccount.isEmpty()) {
            Set<Id> contactIds = contactToAccount.keySet();
            for (User userRecord : [
                SELECT Id, ContactId FROM User WHERE IsActive = TRUE AND ContactId IN :contactIds
            ]) {
                portalByAccountId.put(contactToAccount.get(userRecord.ContactId), true);
            }
        }
        if (!organizationAccountIds.isEmpty()) {
            for (User userRecord : [
                SELECT Id, Contact.AccountId FROM User
                WHERE IsActive = TRUE
                AND Contact.AccountId IN :organizationAccountIds
            ]) {
                portalByAccountId.put(userRecord.Contact.AccountId, true);
            }
        }
        return portalByAccountId;
    }

    private static CustomerMatch chooseBestMatch(List<CustomerMatch> matches) {
        CustomerMatch accountMatch;
        CustomerMatch leadMatch;
        for (CustomerMatch match : matches) {
            if (match.sourceType == Constants.EOI_HOME_SOURCE_TYPE_ACCOUNT && match.hasPortalUser == true) return match;
            if (match.sourceType == Constants.EOI_HOME_SOURCE_TYPE_ACCOUNT && accountMatch == null) accountMatch = match;
            if (match.sourceType == Constants.EOI_HOME_SOURCE_TYPE_LEAD && leadMatch == null) leadMatch = match;
        }
        return accountMatch != null ? accountMatch : leadMatch;
    }

    private static void attachSearchDebug(CustomerSearchResult result, CustomerRequest request, List<SObject> accounts, List<SObject> leads) {
        Map<String, Object> debugInfo = new Map<String, Object>();
        debugInfo.put('orgId', UserInfo.getOrganizationId());
        debugInfo.put('userId', UserInfo.getUserId());
        debugInfo.put('receivedEmail', request == null ? null : request.email);
        debugInfo.put('receivedPhone', request == null ? null : request.phone);
        debugInfo.put('receivedEmiratesId', request == null ? null : request.emiratesId);
        debugInfo.put('receivedPassportNumber', request == null ? null : request.passportNumber);
        debugInfo.put('accountQueryCount', accounts == null ? 0 : accounts.size());
        debugInfo.put('leadQueryCount', leads == null ? 0 : leads.size());
        debugInfo.put('accountIds', toIdStrings(accounts));
        debugInfo.put('leadIds', toIdStrings(leads));
        debugInfo.put('selectedRecordId', result == null || result.selected == null ? null : result.selected.recordId);
        result.debugInfo = JSON.serialize(debugInfo);
    }

    private static List<String> toIdStrings(List<SObject> records) {
        List<String> ids = new List<String>();
        if (records == null) return ids;
        for (SObject record : records) {
            ids.add(String.valueOf(record.get('Id')));
        }
        return ids;
    }

    private static CustomerMatch toAccountMatch(SObject accountRecord, Map<Id, Boolean> portalByAccountId) {
        CustomerMatch match = new CustomerMatch();
        match.sourceType = Constants.EOI_HOME_SOURCE_TYPE_ACCOUNT;
        match.accountType = Constants.EOI_HOME_CUSTOMER_TYPE_INDIVIDUAL;
        match.recordId = (Id) accountRecord.get('Id');
        match.accountId = match.recordId;
        match.contactId = (Id) safeGet(accountRecord, 'PersonContactId');
        match.name = getString(accountRecord, 'Name');
        match.firstName = getString(accountRecord, 'FirstName');
        match.lastName = getString(accountRecord, 'LastName');
        match.email = getString(accountRecord, 'PersonEmail');
        match.phone = String.isNotBlank(getString(accountRecord, 'PersonMobilePhone'))
            ? getString(accountRecord, 'PersonMobilePhone')
            : getString(accountRecord, 'Phone');
        match.emiratesId = getString(accountRecord, 'EIDNumber__pc');
        match.emiratesIdExpiryDate = (Date) safeGet(accountRecord, 'EmiratesIDExpiryDate__pc');
        match.passportNumber = getString(accountRecord, 'PassportNumber__pc');
        match.passportExpiryDate = (Date) safeGet(accountRecord, 'PassportExpiryDate__pc');
        match.residentStatus = getString(accountRecord, 'UAE_Resident_Status__pc');
        match.nationality = getString(accountRecord, 'Nationality__pc');
        match.countryOfResidence = getString(accountRecord, 'CountryOfResidence__pc');
        match.hasPortalUser = portalByAccountId.containsKey(match.accountId);
        match.isEditable = false;
        return match;
    }

    private static CustomerMatch toOrganizationAccountMatch(SObject accountRecord, Map<Id, Boolean> portalByAccountId) {
        return toOrganizationAccountMatch(accountRecord, portalByAccountId, null);
    }

    private static CustomerMatch toOrganizationAccountMatch(SObject accountRecord, Map<Id, Boolean> portalByAccountId, SObject contactRecord) {
        CustomerMatch match = new CustomerMatch();
        match.sourceType = Constants.EOI_HOME_SOURCE_TYPE_ACCOUNT;
        match.accountType = Constants.EOI_HOME_CUSTOMER_TYPE_ORGANIZATION;
        match.recordId = (Id) accountRecord.get('Id');
        match.accountId = match.recordId;
        match.contactId = contactRecord == null ? null : (Id) contactRecord.get('Id');
        match.name = getString(accountRecord, 'Name');
        match.companyName = match.name;
        match.firstName = contactRecord == null ? null : getString(contactRecord, 'FirstName');
        match.lastName = contactRecord == null ? null : getString(contactRecord, 'LastName');
        match.email = String.isNotBlank(getString(contactRecord, 'Email'))
            ? getString(contactRecord, 'Email')
            : getString(accountRecord, 'Company_Email_Address__c');
        match.phone = String.isNotBlank(getString(contactRecord, 'MobilePhone'))
            ? getString(contactRecord, 'MobilePhone')
            : String.isNotBlank(getString(contactRecord, 'Phone'))
                ? getString(contactRecord, 'Phone')
                : String.isNotBlank(getString(accountRecord, 'Company_MobileNumberTRD__c'))
            ? getString(accountRecord, 'Company_MobileNumberTRD__c')
            : getString(accountRecord, 'Phone');
        match.tradeLicenseNumber = String.isNotBlank(getString(accountRecord, 'TradeLicenseNumber__c'))
            ? getString(accountRecord, 'TradeLicenseNumber__c')
            : getString(accountRecord, 'UnifiedNumber__c');
        match.hasPortalUser = portalByAccountId.containsKey(match.accountId);
        match.isEditable = false;
        return match;
    }

    private static CustomerMatch toLeadMatch(SObject leadRecord) {
        CustomerMatch match = new CustomerMatch();
        match.sourceType = Constants.EOI_HOME_SOURCE_TYPE_LEAD;
        match.recordId = (Id) leadRecord.get('Id');
        match.leadId = match.recordId;
        match.name = getString(leadRecord, 'Name');
        match.firstName = getString(leadRecord, 'FirstName');
        match.lastName = getString(leadRecord, 'LastName');
        match.email = getString(leadRecord, 'Email');
        match.phone = String.isNotBlank(getString(leadRecord, 'MobilePhone'))
            ? getString(leadRecord, 'MobilePhone')
            : getString(leadRecord, 'Phone');
        match.emiratesId = getString(leadRecord, 'EIDNumber__c');
        match.emiratesIdExpiryDate = (Date) safeGet(leadRecord, 'EmiratesIDExpiryDate__c');
        match.passportNumber = getString(leadRecord, 'PassportNumber__c');
        match.passportExpiryDate = (Date) safeGet(leadRecord, 'PassportExpiryDate__c');
        match.residentStatus = getString(leadRecord, 'UAEResidentStatus__c');
        match.nationality = getString(leadRecord, 'Nationality__c');
        match.countryOfResidence = getString(leadRecord, 'CountryOfResidence__c');
        match.isEditable = true;
        match.hasPortalUser = false;
        return match;
    }

    private static Id createLead(CustomerRequest request) {
        Lead leadRecord = new Lead();
        leadRecord.FirstName = isOrganization(request) ? request.authorizedFirstName?.trim() : request.firstName?.trim();
        leadRecord.LastName = isOrganization(request) ? request.authorizedLastName.trim() : request.lastName.trim();
        leadRecord.Email = isOrganization(request) ? request.authorizedEmail?.trim() : request.email?.trim();
        leadRecord.MobilePhone = isOrganization(request) ? request.authorizedPhone?.trim() : request.phone?.trim();
        leadRecord.Phone = isOrganization(request)
            ? firstNotBlank(new List<String>{ request.registeredPhone, request.authorizedPhone })
            : request.phone?.trim();
        putIfFieldExists(leadRecord, 'En_Email__c', leadRecord.Email);
        putIfFieldExists(leadRecord, 'En_MobilePhone__c', leadRecord.MobilePhone);
        putIfFieldExists(leadRecord, 'En_Phone__c', leadRecord.Phone);
        if (isOrganization(request)) leadRecord.Company = request.companyName.trim();
        leadRecord.Status = Constants.LEAD_STATUS_NEW;
        leadRecord.LeadSource = String.isNotBlank(request.leadSource) ? request.leadSource : Constants.LEAD_SOURCE_SELF_LEAD;
        if (String.isNotBlank(request.subSource)) putIfFieldExists(leadRecord, 'SubSource__c', request.subSource);
        applyUtmFieldsToLead(leadRecord, request);
        putIfFieldExists(leadRecord, 'IsEOI__c', true);
        putIfFieldExists(leadRecord, 'Existing_Account__c', request.accountId);
        putIfFieldExists(leadRecord, 'ProjectInterest__c', request.projectInterest);
        putIfFieldExists(leadRecord, 'UAEResidentStatus__c', normaliseResidentStatusForLead(request.residentStatus));
        putIfFieldExists(leadRecord, 'Nationality__c', request.nationality);
        putIfFieldExists(leadRecord, 'CountryOfResidence__c', request.countryOfResidence);
        if (isResident(request)) {
            putIfFieldExists(leadRecord, 'EIDNumber__c', request.emiratesId);
            putIfFieldExists(leadRecord, 'En_EIDNumber__c', request.emiratesId);
            putIfFieldExists(leadRecord, 'EmiratesIDExpiryDate__c', request.emiratesIdExpiryDate);
        }
        putIfFieldExists(leadRecord, 'PassportNumber__c', request.passportNumber);
        putIfFieldExists(leadRecord, 'En_PassportNumber__c', request.passportNumber);
        putIfFieldExists(leadRecord, 'PassportExpiryDate__c', request.passportExpiryDate);
        putIfFieldExists(leadRecord, 'UnifiedNumber__c', request.tradeLicenseNumber);
        putIfFieldExists(leadRecord, 'Trade_License_Expiry_Date__c', request.tradeLicenseExpiryDate);
        safeInsert(leadRecord);
        return leadRecord.Id;
    }

    private static void updateLeadFromRequest(Id leadId, CustomerRequest request) {
        validateCustomerForLead(request);
        Lead leadRecord = new Lead(Id = leadId);
        leadRecord.FirstName = isOrganization(request) ? request.authorizedFirstName?.trim() : request.firstName?.trim();
        leadRecord.LastName = isOrganization(request) ? request.authorizedLastName.trim() : request.lastName.trim();
        leadRecord.Email = isOrganization(request) ? request.authorizedEmail?.trim() : request.email?.trim();
        leadRecord.MobilePhone = isOrganization(request) ? request.authorizedPhone?.trim() : request.phone?.trim();
        leadRecord.Phone = isOrganization(request)
            ? firstNotBlank(new List<String>{ request.registeredPhone, request.authorizedPhone })
            : request.phone?.trim();
        putIfFieldExists(leadRecord, 'En_Email__c', leadRecord.Email);
        putIfFieldExists(leadRecord, 'En_MobilePhone__c', leadRecord.MobilePhone);
        putIfFieldExists(leadRecord, 'En_Phone__c', leadRecord.Phone);
        if (isOrganization(request)) leadRecord.Company = request.companyName.trim();
        leadRecord.LeadSource = String.isNotBlank(request.leadSource) ? request.leadSource : Constants.LEAD_SOURCE_SELF_LEAD;
        if (String.isNotBlank(request.subSource)) putIfFieldExists(leadRecord, 'SubSource__c', request.subSource);
        applyUtmFieldsToLead(leadRecord, request);
        putIfFieldExists(leadRecord, 'IsEOI__c', true);
        putIfFieldExists(leadRecord, 'Existing_Account__c', request.accountId);
        putIfFieldExists(leadRecord, 'ProjectInterest__c', request.projectInterest);
        putIfFieldExists(leadRecord, 'UAEResidentStatus__c', normaliseResidentStatusForLead(request.residentStatus));
        putIfFieldExists(leadRecord, 'Nationality__c', request.nationality);
        putIfFieldExists(leadRecord, 'CountryOfResidence__c', request.countryOfResidence);
        if (isResident(request)) {
            putIfFieldExists(leadRecord, 'EIDNumber__c', request.emiratesId);
            putIfFieldExists(leadRecord, 'En_EIDNumber__c', request.emiratesId);
            putIfFieldExists(leadRecord, 'EmiratesIDExpiryDate__c', request.emiratesIdExpiryDate);
        }
        putIfFieldExists(leadRecord, 'PassportNumber__c', request.passportNumber);
        putIfFieldExists(leadRecord, 'En_PassportNumber__c', request.passportNumber);
        putIfFieldExists(leadRecord, 'PassportExpiryDate__c', request.passportExpiryDate);
        putIfFieldExists(leadRecord, 'UnifiedNumber__c', request.tradeLicenseNumber);
        putIfFieldExists(leadRecord, 'Trade_License_Expiry_Date__c', request.tradeLicenseExpiryDate);
        safeUpdate(leadRecord);
    }

    private static OpportunityResult convertLeadToOpportunity(Id leadId) {
        return convertLeadToOpportunity(leadId, null, null);
    }

    private static OpportunityResult convertLeadToOpportunity(Id leadId, Id accountId, Id contactId) {
        List<String> fields = new List<String>{ 'Id', 'FirstName', 'LastName', 'Company' };
        if (hasField('Lead', 'Existing_Account__c')) fields.add('Existing_Account__c');
        Lead leadRecord = (Lead) Database.queryWithBinds(
            'SELECT ' + String.join(fields, ', ') + ' FROM Lead WHERE Id = :leadId LIMIT 1',
            new Map<String, Object>{ 'leadId' => leadId },
            AccessLevel.SYSTEM_MODE
        );

        Database.LeadConvert convertRequest = new Database.LeadConvert();
        convertRequest.setLeadId(leadId);
        convertRequest.setConvertedStatus(getConvertedStatus());
        convertRequest.setDoNotCreateOpportunity(false);
        convertRequest.setOpportunityName(buildOpportunityName(leadRecord.FirstName, String.isNotBlank(leadRecord.Company) ? leadRecord.Company : leadRecord.LastName));
        Id existingAccountId = accountId != null ? accountId : (Id) safeGet(leadRecord, 'Existing_Account__c');
        if (existingAccountId != null) convertRequest.setAccountId(existingAccountId);
        if (contactId != null) convertRequest.setContactId(contactId);
        if (UserInfo.getUserType() == 'Guest') {
            List<Site_Config__mdt> cfg = [SELECT Default_Owner_Id__c FROM Site_Config__mdt WHERE DeveloperName = 'Active_Microsite' LIMIT 1];
            if (!cfg.isEmpty() && String.isNotBlank(cfg[0].Default_Owner_Id__c)) convertRequest.setOwnerId(cfg[0].Default_Owner_Id__c);
        }

        Database.LeadConvertResult convertResult;
        try {
            convertResult = Database.convertLead(convertRequest);
        } catch (DmlException ex) {
            throw new EoiPublicException(getDmlErrorMessage(ex));
        }
        if (!convertResult.isSuccess()) {
            List<String> messages = new List<String>();
            for (Database.Error err : convertResult.getErrors()) messages.add(err.getMessage());
            throw new EoiPublicException('Lead conversion failed: ' + String.join(messages, '; '));
        }

        OpportunityResult result = new OpportunityResult();
        result.leadId = leadId;
        result.accountId = convertResult.getAccountId();
        result.contactId = convertResult.getContactId();
        result.opportunityId = convertResult.getOpportunityId();
        return result;
    }

    private static OpportunityResult createOpportunityForAccount(Id accountId) {
        return createOpportunityForAccount(accountId, null);
    }

    private static Id findOrCreateOrganizationContact(CustomerRequest request) {
        if (request == null || request.accountId == null) return null;
        List<String> filters = new List<String>{ 'AccountId = :accountId' };
        Map<String, Object> binds = new Map<String, Object>{ 'accountId' => request.accountId };
        if (String.isNotBlank(request.authorizedEmail)) {
            filters.add('Email = :authorizedEmail');
            binds.put('authorizedEmail', request.authorizedEmail.trim());
        }
        if (String.isNotBlank(request.authorizedPhone)) {
            filters.add('(MobilePhone = :authorizedPhone OR Phone = :authorizedPhone)');
            binds.put('authorizedPhone', request.authorizedPhone.trim());
        }
        List<SObject> contacts = filters.size() > 1
            ? queryRows('SELECT Id FROM Contact WHERE ' + String.join(filters, ' AND ') + ' ORDER BY CreatedDate DESC LIMIT 1', binds)
            : new List<SObject>();
        if (!contacts.isEmpty()) return (Id) contacts[0].get('Id');

        Contact contactRecord = new Contact();
        contactRecord.AccountId = request.accountId;
        contactRecord.FirstName = request.authorizedFirstName?.trim();
        contactRecord.LastName = request.authorizedLastName.trim();
        contactRecord.Email = request.authorizedEmail?.trim();
        contactRecord.MobilePhone = request.authorizedPhone?.trim();
        contactRecord.Phone = request.authorizedPhone?.trim();
        safeInsert(contactRecord);
        return contactRecord.Id;
    }

    private static OpportunityResult createOpportunityForAccount(Id accountId, Id requestedContactId) {
        List<String> fields = new List<String>{ 'Id', 'Name' };
        if (hasField('Account', 'PersonContactId')) fields.add('PersonContactId');
        SObject accountRecord = queryRows(
            'SELECT ' + String.join(fields, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1',
            new Map<String, Object>{ 'accountId' => accountId }
        )[0];

        Opportunity opportunityRecord = new Opportunity(
            Name = buildOpportunityName(null, getString(accountRecord, 'Name')),
            AccountId = accountId,
            StageName = Constants.EOI_HOME_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(Constants.EOI_HOME_OPPORTUNITY_CLOSE_DAYS)
        );
        Id contactId = requestedContactId != null ? requestedContactId : (Id) safeGet(accountRecord, 'PersonContactId');
        if (contactId != null && hasField('Opportunity', 'ContactId')) opportunityRecord.put('ContactId', contactId);
        safeInsert(opportunityRecord);

        OpportunityResult result = new OpportunityResult();
        result.accountId = accountId;
        result.contactId = contactId;
        result.opportunityId = opportunityRecord.Id;
        return result;
    }

    private static String getConvertedStatus() {
        List<SObject> statuses = queryRows(
            'SELECT MasterLabel, ApiName FROM LeadStatus WHERE IsConverted = TRUE ORDER BY SortOrder LIMIT 1'
        );
        if (statuses.isEmpty()) return Constants.EOI_HOME_FALLBACK_CONVERTED_STATUS;
        String apiName = getString(statuses[0], 'ApiName');
        return String.isNotBlank(apiName) ? apiName : getString(statuses[0], 'MasterLabel');
    }

    private static String buildOpportunityName(String firstName, String lastName) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(firstName)) parts.add(firstName.trim());
        if (String.isNotBlank(lastName)) parts.add(lastName.trim());
        String customerName = String.join(parts, ' ').trim();
        return Constants.EOI_HOME_OPPORTUNITY_NAME_PREFIX
            + (String.isBlank(customerName) ? Constants.EOI_HOME_DEFAULT_CUSTOMER_NAME : customerName);
    }

    private static String firstNotBlank(List<String> values) {
        if (values == null) return null;
        for (String value : values) {
            if (String.isNotBlank(value)) return value.trim();
        }
        return null;
    }

    private static List<Option> toSortedOptions(Map<Id, String> valuesById) {
        List<Option> options = new List<Option>();
        for (Id key : valuesById.keySet()) options.add(new Option(String.valueOf(key), valuesById.get(key)));
        options.sort();
        return options;
    }

    private static List<SObject> queryRows(String soql) {
        return queryRows(soql, new Map<String, Object>());
    }

    private static List<SObject> queryRows(String soql, Map<String, Object> binds) {
        try {
            return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        } catch (Exception ex) {
            throw ex;
        }
    }

    private static void safeInsert(SObject record) {
        try {
            insert record;
        } catch (DmlException ex) {
            throw new EoiPublicException(getDmlErrorMessage(ex));
        }
    }

    private static void safeInsert(List<SObject> records) {
        try {
            insert records;
        } catch (DmlException ex) {
            throw new EoiPublicException(getDmlErrorMessage(ex));
        }
    }

    private static void safeUpdate(SObject record) {
        try {
            update record;
        } catch (DmlException ex) {
            throw new EoiPublicException(getDmlErrorMessage(ex));
        }
    }

    private static String getDmlErrorMessage(DmlException ex) {
        List<String> messages = new List<String>();
        for (Integer i = 0; i < ex.getNumDml(); i++) {
            String message = cleanDmlMessage(ex.getDmlMessage(i));
            if (String.isNotBlank(message)) messages.add(message);
        }
        return messages.isEmpty() ? cleanDmlMessage(ex.getMessage()) : String.join(messages, '; ');
    }

    private static String cleanDmlMessage(String message) {
        if (String.isBlank(message)) return message;
        String cleaned = message.trim();
        for (String marker : new List<String>{
            'FIELD_CUSTOM_VALIDATION_EXCEPTION,',
            'REQUIRED_FIELD_MISSING,',
            'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,',
            'INVALID_FIELD_FOR_INSERT_UPDATE,',
            'DUPLICATES_DETECTED,',
            'CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,'
        }) {
            Integer idx = cleaned.indexOf(marker);
            if (idx >= 0) {
                cleaned = cleaned.substring(idx + marker.length()).trim();
            }
        }
        cleaned = cleaned.replaceAll(': \\[.*\\]$', '').trim();
        return cleaned;
    }

    private static Boolean hasField(String objectName, String fieldName) {
        SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        return objectType != null && objectType.getDescribe().fields.getMap().containsKey(fieldName);
    }

    private static Boolean hasFilterableField(String objectName, String fieldName) {
        SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        if (objectType == null) return false;
        Schema.SObjectField fieldToken = objectType.getDescribe().fields.getMap().get(fieldName);
        return fieldToken != null && fieldToken.getDescribe().isFilterable();
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record == null || value == null) return;
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static void applyUtmFieldsToLead(Lead leadRecord, CustomerRequest request) {
        if (leadRecord == null || request == null) return;
        if (String.isNotBlank(request.utmSource))   putIfFieldExists(leadRecord, 'UTMSource__c', request.utmSource);
        if (String.isNotBlank(request.utmCampaign)) putIfFieldExists(leadRecord, 'UTMCampaign__c', request.utmCampaign);
        if (String.isNotBlank(request.utmMedium))   putIfFieldExists(leadRecord, 'UTMMedium__c', request.utmMedium);
        if (String.isNotBlank(request.utmUrl))      putIfFieldExists(leadRecord, 'UTMURL__c', request.utmUrl);
        if (String.isNotBlank(request.adName))      putIfFieldExists(leadRecord, 'AdName__c', request.adName);
        if (String.isNotBlank(request.adSetName))   putIfFieldExists(leadRecord, 'AdSetName__c', request.adSetName);
    }

    private static Object safeGet(SObject record, String fieldName) {
        if (record == null) return null;
        // v1.1: Avoid noisy caught exceptions when mixed person/org Account queries do not include the same fields.
        if (!record.getPopulatedFieldsAsMap().containsKey(fieldName)) return null;
        try {
            return record.get(fieldName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String getString(SObject record, String fieldName) {
        Object value = safeGet(record, fieldName);
        return value == null ? null : String.valueOf(value);
    }

    private static String normalisePhone(String raw) {
        if (raw == null) return '';
        Boolean hasPlus = raw.trim().startsWith('+');
        String digits = raw.replaceAll('[^0-9]', '');
        return hasPlus ? '+' + digits : digits;
    }

    public class Option implements Comparable {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        public Option(String value, String label) {
            this.value = value;
            this.label = label;
        }
        public Integer compareTo(Object other) {
            return label.compareTo(((Option) other).label);
        }
    }

    public class CustomerRequest {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String customerType { get; set; }
        @AuraEnabled public String requestId { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        @AuraEnabled public String nationality { get; set; }
        @AuraEnabled public String countryOfResidence { get; set; }
        @AuraEnabled public String emiratesId { get; set; }
        @AuraEnabled public Date emiratesIdExpiryDate { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        @AuraEnabled public Date passportExpiryDate { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public String projectInterest { get; set; }
        @AuraEnabled public Boolean skipFrontendValidation { get; set; }
        @AuraEnabled public String leadSource { get; set; }
        @AuraEnabled public String subSource { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String tradeLicenseNumber { get; set; }
        @AuraEnabled public Date tradeLicenseExpiryDate { get; set; }
        @AuraEnabled public String registeredEmail { get; set; }
        @AuraEnabled public String registeredPhone { get; set; }
        @AuraEnabled public String authorizedFirstName { get; set; }
        @AuraEnabled public String authorizedLastName { get; set; }
        @AuraEnabled public String authorizedEmail { get; set; }
        @AuraEnabled public String authorizedPhone { get; set; }
        @AuraEnabled public String utmSource { get; set; }
        @AuraEnabled public String utmCampaign { get; set; }
        @AuraEnabled public String utmMedium { get; set; }
        @AuraEnabled public String utmUrl { get; set; }
        @AuraEnabled public String adName { get; set; }
        @AuraEnabled public String adSetName { get; set; }
    }

    public class CustomerSearchResult {
        @AuraEnabled public String sourceType;
        @AuraEnabled public Boolean isEditable;
        @AuraEnabled public CustomerMatch selected;
        @AuraEnabled public List<CustomerMatch> matches;
        @AuraEnabled public String debugInfo;
    }

    public class CustomerMatch {
        @AuraEnabled public String sourceType;
        @AuraEnabled public String accountType;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id leadId;
        @AuraEnabled public String name;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String nationality;
        @AuraEnabled public String countryOfResidence;
        @AuraEnabled public String emiratesId;
        @AuraEnabled public Date emiratesIdExpiryDate;
        @AuraEnabled public String passportNumber;
        @AuraEnabled public Date passportExpiryDate;
        @AuraEnabled public String companyName;
        @AuraEnabled public String tradeLicenseNumber;
        @AuraEnabled public Boolean hasPortalUser;
        @AuraEnabled public Boolean isEditable;
    }

    public class OpportunityResult {
        @AuraEnabled public Id leadId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id opportunityId;
    }

    public class EOIRangeResult {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String unitTypology;
    }

    public class EOIRangeMatrixRow {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public Id phaseId;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Decimal amount;
    }

    public class ValidationResult {
        @AuraEnabled public Boolean isDuplicate = false;
        @AuraEnabled public String existingEOIRef;
        @AuraEnabled public Integer quotaLimit = 0;
        @AuraEnabled public Integer quotaUsed = 0;
        @AuraEnabled public Integer quotaRemaining = 0;
        @AuraEnabled public Boolean quotaExceeded = false;
    }

    public class EOIRequest {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public String bedrooms { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public Integer numberOfUnits { get; set; }
        @AuraEnabled public Id eoiRangeId { get; set; }
        @AuraEnabled public Decimal eoiAmount { get; set; }
        @AuraEnabled public String paymentType { get; set; }
        @AuraEnabled public String remarks { get; set; }
        @AuraEnabled public List<EOISelectionRequest> selections { get; set; }
    }

    public class EOISelectionRequest {
        // Represents one EOI row from the multi-selection journey UI.
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public String bedrooms { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public Id eoiRangeId { get; set; }
        @AuraEnabled public Decimal eoiAmount { get; set; }
    }

    public class JourneyResult {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id eoiId;
        @AuraEnabled public List<Id> eoiIds;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String eoiReference;
        @AuraEnabled public List<String> eoiReferences;
    }
}