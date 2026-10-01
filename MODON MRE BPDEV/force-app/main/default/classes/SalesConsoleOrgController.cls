/**
 * SalesConsoleOrgController - the organisation half of the booking journey.
 *
 * Version  Author      Date         Detail
 * 2.x+1    Aurelix Dev  29 Sep 2026  No Power of Attorney row is asked for when the primary contact already
 *                                    passes MODON's KYC test (KYC Active or manually approved), as the row is
 *                                    only needed for sendKYCForm's link (kycSettled, poaRowNeeded).
 * 2.x      Aurelix Dev  18 Sep 2026  MSC-176 (B6). The signatory's MAILING address (Contact
 *                                    Mailing*, five parts) is captured on the Power of Attorney
 *                                    pane beside the company's Billing address - the decision of
 *                                    17 Sep names it as the organisation's "Mailing" for KYC. The
 *                                    five are optional here (they do not gate the compliance
 *                                    submission), writable through saveOrgDetails, and left out of
 *                                    the New Contact form. The signatory group's count now skips
 *                                    optional fields, as the company group already did.
 * 2.0      Aurelix Dev 30 Aug 2026  MSC-181. The Power of Attorney, named and assigned.
 *                                   One Power of Attorney per company - the client's
 *                                   rule, and the data's shape (every account carries
 *                                   at most one row). assignSignatory REPLACES that one
 *                                   row and repoints Opportunity.PrimaryContact__c in
 *                                   the same transaction; it refuses once the person it
 *                                   would unfile has completed identity verification,
 *                                   and refuses a change of person once the company is
 *                                   with compliance. createSignatoryContact creates a
 *                                   contact with exactly sendKYCForm's required set and
 *                                   assigns them in the same transaction.
 *                                   recordSignatory now delegates to assignSignatory:
 *                                   its fill-only body could file a SECOND row when one
 *                                   stood against another contact, and sendKYCForm
 *                                   links every row it finds. people now ride on every
 *                                   corporate answer - the workspace's lookup is drawn
 *                                   from them - each with the four link fields and what
 *                                   the link would still be missing, worded;
 *                                   newPersonFields carries the New Contact form's
 *                                   labels, types and picklist options from the same
 *                                   describe the pane's own cells use. Wording:
 *                                   "authorized signatory" is now "Power of Attorney"
 *                                   everywhere a rep reads it, and nothing is said to
 *                                   be "recorded" - a Power of Attorney is assigned.
 * 1.7      Aurelix Dev 25 Aug 2026  MSC-171. The company workspace's risk group is
 *                                   labelled 'Profile'. Display string only - the group
 *                                   key, its fields and every gate are untouched.
 * 1.6      Aurelix Dev 23 Aug 2026  MSC-152. submitForRecord stamps the two Checkbox
 *                                   flags getEntityRecords leaves null, and READS the
 *                                   string createPassfortTransactionRecords returns.
 *                                   Together those two lines were reporting a
 *                                   submission that never happened.
 * 1.5      Aurelix Dev 23 Aug 2026  MSC-151. nextStep - the ONE thing to do now, and
 *                                   the order of the eight states, decided here so the
 *                                   bar, the cards and the workspace cannot tell three
 *                                   different stories.
 * 1.4      Aurelix Dev 23 Aug 2026  MSC-149. The workspace sends the verification link
 *                                   itself, so the rep never leaves it for the card; and
 *                                   the submission waits on the signatory's identity
 *                                   documents, because getEntityRecords files a corporate
 *                                   booking as TWO Passfort entities and the second one
 *                                   was going out empty. outstandingForSubmission is the
 *                                   whole gate; outstandingForCompany stays the company's
 *                                   own half.
 * 1.3      Aurelix Dev 23 Aug 2026  MSC-148. The verification workspace: getOrgDetails,
 *                                   saveOrgDetails, recordSignatory and
 *                                   uploadCompanyLicence, plus the two gates the whole
 *                                   organisation path now reads - outstandingForCompany
 *                                   (what compliance still needs) and missingForLink
 *                                   (what sendKYCForm would refuse). Both are derived
 *                                   ONCE and read by three callers each, so the screen,
 *                                   the buttons and the automatic path cannot disagree.
 *                                   submitOrganisationCompliance now refuses on the same
 *                                   list rather than on Is_Trade_License_Uploaded__c,
 *                                   which is false on all 14 PREPROD companies that have
 *                                   actually cleared Passfort - the old gate was stricter
 *                                   than production. getOrgState, uploadTradeLicence and
 *                                   the shareholder methods are untouched.
 * 1.0      Aurelix IT  10 Aug 2026  Initial. Shareholders and the trade licence.
 * 1.2      Aurelix IT  22 Aug 2026  MSC-113. The outstanding list agrees with the
 *                                   eligibility gate, field for field: the registered
 *                                   address check gains State and Postal code (it said
 *                                   "done" while checkBookingEligibility still blocked),
 *                                   and the UnifiedNumber__c item is named 'Licence
 *                                   number' - the customer card's word for the same
 *                                   field. The shareholder methods stay whole though the
 *                                   console UI no longer calls them (GAP 10): they have
 *                                   no other consumer and deleting live @AuraEnabled
 *                                   surface buys nothing.
 * 1.1      Aurelix IT  10 Aug 2026  Owners no longer block a submission - the org has 94
 *                                   Company submissions and 1 Shareholder, so Passfort
 *                                   does not require them. Residency no longer picks the
 *                                   company document either; getEntityRecords creates both
 *                                   placeholders and a human fills the right one.
 */

/**
 * Passfort assesses a company through its people, so a corporate booking needs both
 * the company record and its shareholders before compliance can be submitted.
 *
 * Reuses the org's existing corporate verification rather than inventing one:
 * CustomerKYCHandler.mapKYCTradeLicenseValues is public, and it is what sets
 * Is_Trade_License_Uploaded__c, raises the Corporate_KYC KYC_Response__c and fills the
 * Account from a Signzy extraction. Nothing in CustomerKYCHandler is modified.
 */
public with sharing class SalesConsoleOrgController {

    /** The document name PassfortCompanyDocNames requires for a resident company. */
    private static final String DOC_RESIDENT = 'Commercial trade License (Resident)';
    private static final String DOC_NON_RESIDENT = 'Certificate of Incorporation (Non Resident)';
    private static final String SHAREHOLDER_RT = 'Shareholder';

    // ======================================================================
    // State
    // ======================================================================

    public class OrgStateDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String companyName;
        @AuraEnabled public Boolean isOrganisation = false;
        @AuraEnabled public Boolean tradeLicenceUploaded = false;
        @AuraEnabled public String tradeLicenceNumber;
        @AuraEnabled public Date tradeLicenceExpiry;
        @AuraEnabled public String residentStatus;
        /** Which document this company owes, by residency. */
        @AuraEnabled public String requiredDocName;
        @AuraEnabled public Boolean requiredDocPresent = false;
        @AuraEnabled public List<ShareholderDTO> shareholders = new List<ShareholderDTO>();
        @AuraEnabled public Decimal ownershipTotal = 0;
        /** What is still standing between this company and a compliance submission. */
        @AuraEnabled public List<String> outstanding = new List<String>();
    }

    public class ShareholderDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String name;
        @AuraEnabled public String nationality;
        @AuraEnabled public Date birthdate;
        @AuraEnabled public Decimal ownershipPercentage;
    }

    @AuraEnabled(cacheable=false)
    public static OrgStateDTO getOrgState(Id opportunityId) {
        OrgStateDTO dto = new OrgStateDTO();
        if (opportunityId == null) {
            return dto;
        }
        List<Opportunity> opps = [
            SELECT Id, AccountId, Account.Name, Account.IsPersonAccount,
                   Account.UnifiedNumber__c, Account.TradeLicenseExpiryDate__c,
                   Account.Is_Trade_License_Uploaded__c, Account.DateOfEstablishment__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState,
                   Account.BillingPostalCode, Account.BillingCountry,
                   UAE_Resident_Status__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].AccountId == null) {
            return dto;
        }
        Opportunity opp = opps[0];
        dto.accountId = opp.AccountId;
        dto.isOrganisation = !opp.Account.IsPersonAccount;
        if (!dto.isOrganisation) {
            return dto;
        }

        dto.companyName          = opp.Account.Name;
        dto.tradeLicenceNumber   = opp.Account.UnifiedNumber__c;
        dto.tradeLicenceExpiry   = opp.Account.TradeLicenseExpiryDate__c;
        dto.tradeLicenceUploaded = opp.Account.Is_Trade_License_Uploaded__c == true;
        dto.residentStatus       = opp.UAE_Resident_Status__c;
        dto.requiredDocName      = DOC_RESIDENT;
        dto.requiredDocPresent   = docPresent(opp.AccountId, companyDocNames());
        dto.shareholders         = loadShareholders(opp.AccountId);

        for (ShareholderDTO s : dto.shareholders) {
            if (s.ownershipPercentage != null) {
                dto.ownershipTotal += s.ownershipPercentage;
            }
        }

        /* Named rather than counted. "3 items outstanding" tells a rep nothing they
           can act on; the field name does. */
        if (!dto.tradeLicenceUploaded && !dto.requiredDocPresent) {
            dto.outstanding.add('Trade licence');
        }
        // 1.2 - the card's word for UnifiedNumber__c, one name everywhere.
        if (String.isBlank(opp.Account.UnifiedNumber__c)) {
            dto.outstanding.add('Licence number');
        }
        if (opp.Account.DateOfEstablishment__c == null) {
            dto.outstanding.add('Date of establishment');
        }
        /* 1.2 - all five parts, because that is what checkBookingEligibility
           blocks on. The old three-part check let this list say "done" while
           Continue was still held on State or Postal code. */
        if (String.isBlank(opp.Account.BillingStreet)
                || String.isBlank(opp.Account.BillingCity)
                || String.isBlank(opp.Account.BillingState)
                || String.isBlank(opp.Account.BillingPostalCode)
                || String.isBlank(opp.Account.BillingCountry)) {
            dto.outstanding.add('Registered address');
        }
        /* 1.1 - owners are NOT listed as outstanding. The org has 94 Company
           submissions and 1 Shareholder between them, so Passfort plainly does not
           require them; blocking on one would stop every booking. */
        return dto;
    }

    /**
     * 1.1 - residency no longer picks the document.
     *
     * getEntityRecords creates a placeholder for BOTH company doc names and lets a
     * human fill whichever applies. Branching here was an invention that diverged
     * from the internal path.
     */
    @TestVisible
    private static List<String> companyDocNames() {
        return new List<String>{ DOC_RESIDENT, DOC_NON_RESIDENT };
    }

    /**
     * Present means the same thing AutoPassfortComplianceService means by it: a
     * Documents__c whose Status__c is 'Uploaded', or one with a file attached.
     */
    private static Boolean docPresent(Id accountId, List<String> docNames) {
        Set<Id> docIds = new Set<Id>();
        for (Documents__c d : [
            SELECT Id, Status__c FROM Documents__c
            WHERE Account__c = :accountId AND Name IN :docNames
        ]) {
            if (d.Status__c == 'Uploaded') {
                return true;
            }
            docIds.add(d.Id);
        }
        if (docIds.isEmpty()) {
            return false;
        }
        return ![SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :docIds].isEmpty();
    }

    // ======================================================================
    // Shareholders
    // ======================================================================

    private static List<ShareholderDTO> loadShareholders(Id accountId) {
        List<ShareholderDTO> out = new List<ShareholderDTO>();
        for (Contact c : [
            SELECT Id, FirstName, LastName, Name, Nationality__c, Birthdate,
                   OwnershipPercentage__c
            FROM Contact
            WHERE AccountId = :accountId
            AND RecordType.DeveloperName = :SHAREHOLDER_RT
            ORDER BY OwnershipPercentage__c DESC NULLS LAST, Name
        ]) {
            ShareholderDTO s = new ShareholderDTO();
            s.id                  = c.Id;
            s.firstName           = c.FirstName;
            s.lastName            = c.LastName;
            s.name                = c.Name;
            s.nationality         = c.Nationality__c;
            s.birthdate           = c.Birthdate;
            s.ownershipPercentage = c.OwnershipPercentage__c;
            out.add(s);
        }
        return out;
    }

    /**
     * Upsert one shareholder onto the booking's company.
     *
     * The record type is resolved here rather than taken from the client, so a
     * shareholder can never be filed as an ordinary contact - which is what
     * PassfortRelatedEntitiesController.getShareholderRecords filters on.
     */
    @AuraEnabled
    public static OrgStateDTO saveShareholder(
        Id opportunityId,
        Id shareholderId,
        String firstName,
        String lastName,
        String nationality,
        Date birthdate,
        Decimal ownershipPercentage
    ) {
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('A shareholder needs a last name.');
        }
        Id accountId = accountFor(opportunityId);
        try {
            Contact c = new Contact(
                Id                    = shareholderId,
                AccountId             = accountId,
                FirstName             = String.isBlank(firstName) ? null : firstName.trim(),
                LastName              = lastName.trim(),
                Nationality__c        = String.isBlank(nationality) ? null : nationality,
                Birthdate             = birthdate,
                OwnershipPercentage__c = ownershipPercentage
            );
            if (shareholderId == null) {
                c.RecordTypeId = shareholderRecordTypeId();
            }
            upsert c;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return getOrgState(opportunityId);
    }

    @AuraEnabled
    public static OrgStateDTO deleteShareholder(Id opportunityId, Id shareholderId) {
        if (shareholderId == null) {
            throw new AuraHandledException('No shareholder was supplied.');
        }
        try {
            delete new Contact(Id = shareholderId);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return getOrgState(opportunityId);
    }

    private static Id shareholderRecordTypeId() {
        Schema.RecordTypeInfo rt = Contact.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(SHAREHOLDER_RT);
        if (rt == null) {
            throw new AuraHandledException(
                'The Shareholder record type is not available to you.');
        }
        return rt.getRecordTypeId();
    }

    private static Id accountFor(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].AccountId == null) {
            throw new AuraHandledException('This booking has no customer yet.');
        }
        return opps[0].AccountId;
    }

    // ======================================================================
    // Trade licence
    // ======================================================================

    /**
     * Attach the licence, then read it.
     *
     * That order is deliberate. CustomerKYCHandler.tradeLicenseuploadFile calls the
     * extraction BEFORE inserting the ContentVersion, so a callout failure loses the
     * upload entirely. Here the file is safe before anything can fail, and the
     * extraction is a Queueable because Signzy is given 120 seconds - far past what
     * a synchronous Aura request allows.
     */
    @AuraEnabled
    public static OrgStateDTO uploadTradeLicence(
        Id opportunityId,
        String base64,
        String fileName
    ) {
        if (String.isBlank(base64) || String.isBlank(fileName)) {
            throw new AuraHandledException('No file was supplied.');
        }
        String ext = fileName.substringAfterLast('.').toLowerCase();
        if (!(new Set<String>{ 'pdf', 'png', 'jpg', 'jpeg' }).contains(ext)) {
            throw new AuraHandledException('Only PDF, PNG and JPG files are accepted.');
        }
        Id accountId = accountFor(opportunityId);
        // 1.1 - the console books UAE companies only, so the licence is the doc.
        String docName = DOC_RESIDENT;

        try {
            ContentVersion cv = new ContentVersion(
                Title        = fileName,
                PathOnClient = fileName,
                VersionData  = EncodingUtil.base64Decode(base64)
            );
            insert cv;

            Id contentDocumentId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
            ].ContentDocumentId;

            Documents__c doc = new Documents__c(
                Name       = docName,
                Account__c = accountId,
                Status__c  = 'Uploaded'
            );
            for (Documents__c existing : [
                SELECT Id FROM Documents__c
                WHERE Account__c = :accountId AND Name = :docName LIMIT 1
            ]) {
                doc.Id = existing.Id;
            }
            upsert doc;

            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId    = doc.Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );

            // The file is stored. Extraction can now fail without costing the upload.
            System.enqueueJob(new TradeLicenceReadQueueable(accountId, base64, ext));
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return getOrgState(opportunityId);
    }

    // ======================================================================
    // Compliance
    // ======================================================================

    /**
     * Submit a company for compliance, gated on the trade licence.
     *
     * Is_Trade_License_Uploaded__c is to an organisation what KYC_Completed_Date__c is
     * to an individual: the org's own signal that the buyer has been verified. Set by
     * CustomerKYCHandler.mapKYCTradeLicenseValues off a Signzy extraction.
     *
     * The submission itself is NOT rebuilt. getEntityRecords already assembles the
     * company, its shareholders and their documents, and createPassfortTransactionRecords
     * already turns that into PassfortTransaction__c records - the same two calls
     * passfortRelatedEntitiesLwc makes. AutoPassfortComplianceService is untouched: it
     * queries `IsPersonAccount = true` and has no company payload, so extending it would
     * have meant duplicating this.
     *
     * @return null when submitted, or the reason it was not.
     */
    @AuraEnabled
    public static String submitOrganisationCompliance(Id opportunityId, Id salesOrderId) {
        if (salesOrderId == null) {
            return 'Compliance is submitted once the booking has a Sales Order.';
        }
        OrgStateDTO state = getOrgState(opportunityId);
        if (!state.isOrganisation) {
            return null;
        }
        /* 1.3 - the workspace's own list, not this method's. The licence is required
           as a DOCUMENT (which is what PassfortCompanyDocNames and docPresent already
           mean by it) rather than through Is_Trade_License_Uploaded__c, which only
           means "Signzy read a licence successfully" and is false on all 14 PREPROD
           companies that have actually cleared Passfort. */
        List<String> outstanding = outstandingForSubmission(opportunityId);
        if (!outstanding.isEmpty()) {
            return 'Still outstanding: ' + String.join(outstanding, ', ') + '.';
        }
        return submitForRecord(salesOrderId);
    }

    /** Shared by the console button and the post-extraction hook. */
    public static String submitForRecord(Id salesOrderId) {
        try {
            List<PassfortRelatedEntitiesController.EntityWrapper> entities =
                PassfortRelatedEntitiesController.getEntityRecords(salesOrderId);
            if (entities == null || entities.isEmpty()) {
                return 'No entities were found to submit.';
            }
            /* 1.6 - MSC-152. TWO DEFECTS, ONE PRESS.
               1. getEntityRecords leaves IsCommercialProject and IsSecondaryMarket
                  NULL, and both map onto Checkbox fields, which cannot hold null:
                  the insert failed with INVALID_TYPE_ON_FIELD_IN_RECORD on every
                  record. Every other caller stamps them - SalesConsoleComplianceService
                  cls:2199 and AutoPassfortComplianceService cls:539 - and this one
                  did not. false is the truthful value for a console booking: the
                  console books residential plots and no secondary market. */
            for (PassfortRelatedEntitiesController.EntityWrapper e : entities) {
                if (e.IsCommercialProject == null) { e.IsCommercialProject = false; }
                if (e.IsSecondaryMarket == null)   { e.IsSecondaryMarket = false; }
            }
            /* Already submitted entities carry a profile id; resubmitting is what the
               existing guard in PassfortTransactionProcessHelper skips, so this does
               not need its own dedupe. */
            String outcome = PassfortRelatedEntitiesController.createPassfortTransactionRecords(
                JSON.serialize(entities), salesOrderId
            );
            /* 2. createPassfortTransactionRecords inserts with allOrNone = false and
                  REPORTS its per-record failures in the return string rather than
                  throwing. Discarding that string is how Send for compliance answered
                  null - submitted - while creating nothing at all, and the screen then
                  redrew itself identically because nothing had in fact moved. */
            if (String.isBlank(outcome) || outcome.containsIgnoreCase('error')) {
                System.debug(LoggingLevel.ERROR,
                    'Passfort transactions were not created for sales order '
                    + salesOrderId + '. ' + outcome);
                return String.isBlank(outcome)
                    ? 'Compliance did not accept this booking. Please contact Sales Operations.'
                    : outcome;
            }
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    // ======================================================================
    // 1.3 - MSC-148. The verification workspace.
    //
    // ONE READINESS, three readers: this DTO, submitOrganisationCompliance and
    // TradeLicenceReadQueueable all call outstandingForCompany, so the screen, the
    // button and the automatic path can never disagree about what is missing.
    //
    // Nothing MODON owns is touched. The ten fields PREPROD's cleared companies all
    // carry are written here, through an allowlist rebuilt from the describe.
    // ======================================================================

    /** Account fields this workspace may write. Anything else is dropped. */
    private static final Set<String> ACCOUNT_WRITABLE = new Set<String>{
        'UnifiedNumber__c', 'DateOfEstablishment__c', 'TradeLicenseExpiryDate__c',
        'LegalStructure__c', 'UAEVATRegisterNumber__c', 'Description',
        'SourceOfIncome__c', 'OtherSourceOfIncome__c', 'PaymentMethod__c',
        'DeliveryChannel__c'
    };
    /** Signatory fields, and only the four sendKYCForm refuses without. */
    private static final Set<String> CONTACT_WRITABLE = new Set<String>{
        'Nationality__c', 'UAE_Resident_Status__c', 'Email', 'MobilePhone',
        'MailingStreet', 'MailingCity', 'MailingState', 'MailingPostalCode', 'MailingCountry'
    };
    /** Written once and never overwritten - the record's value is somebody's decision. */
    private static final Set<String> FILL_ONLY = new Set<String>{
        'Account.UnifiedNumber__c', 'Contact.Nationality__c',
        'Contact.UAE_Resident_Status__c', 'Contact.Email', 'Contact.MobilePhone'
    };
    private static final String OTHER_INCOME = 'Others (please specify)';

    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionDTO(String v) { this.label = v; this.value = v; }
    }

    public class OrgFieldDTO {
        /** 'Account.Description' - the subject and the field, which is what save reads. */
        @AuraEnabled public String key;
        @AuraEnabled public String api;
        @AuraEnabled public String subject;
        @AuraEnabled public String label;
        @AuraEnabled public String note;
        /** text | textarea | email | phone | date | picklist */
        @AuraEnabled public String type;
        @AuraEnabled public String value;
        @AuraEnabled public String display;
        @AuraEnabled public Boolean filled = false;
        @AuraEnabled public Boolean readOnly = false;
        /** shown, never counted, never blocks a submission */
        @AuraEnabled public Boolean optional = false;
        @AuraEnabled public List<OptionDTO> options;
    }

    public class OrgGroupDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        /** false for a ledger the rep only reads - it carries no n/m */
        @AuraEnabled public Boolean counted = true;
        @AuraEnabled public Integer ready = 0;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public List<OrgFieldDTO> fields = new List<OrgFieldDTO>();
    }

    public class OrgDocDTO {
        @AuraEnabled public String name;
        @AuraEnabled public Boolean received = false;
        @AuraEnabled public Datetime receivedOn;
    }

    public class OrgPersonDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String title;
        /* 2.0 - the four fields sendKYCForm refuses a contact on. `phone` above stays
           the row's reach line (mobile, else phone); `mobile` is the field itself. */
        @AuraEnabled public String mobile;
        @AuraEnabled public String nationality;
        @AuraEnabled public String residency;
        /** what the link would still be missing for this person, worded; null when nothing */
        @AuraEnabled public String missing;
    }

    public class OrgSignatoryDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        /** 2.0 - the role line under the name on the card */
        @AuraEnabled public String title;
        /** 2.0 - what the link would still be missing, worded; null when nothing is */
        @AuraEnabled public String missing;
        /** a Power of Attorney row already files this person for the company */
        @AuraEnabled public Boolean recorded = false;
        /** the booking names them and nothing else is needed to file them */
        @AuraEnabled public Boolean canRecord = false;
        /** nobody is named: the rep picks from the people the company already has */
        @AuraEnabled public Boolean canPick = false;
        @AuraEnabled public Date kycCompletedOn;
        /* 1.4 - the link, so the workspace can send it without a round trip to the
           card. Stamped on the CONTACT by sendKYCForm, never on the Account. */
        @AuraEnabled public Datetime linkSentAt;
        @AuraEnabled public Boolean canSendLink = false;
        /* 2.x+1 - also true when the primary contact's KYC is Active or manually approved */
        @AuraEnabled public Boolean verified = false;
        /** 2.x+1 - approved by hand (Contact.Manual_KYC_Approval__c): verified with no completion date */
        @AuraEnabled public Boolean manuallyApproved = false;
        /** 2.x+1 - false when the primary contact's KYC is Active or manually approved (no link, no row) */
        @AuraEnabled public Boolean poaRowNeeded = true;
    }

    public class OrgDetailsDTO {
        @AuraEnabled public Boolean available = false;
        @AuraEnabled public String blockedReason;

        @AuraEnabled public Id accountId;
        @AuraEnabled public String companyName;

        @AuraEnabled public Integer readyCount = 0;
        @AuraEnabled public Integer totalCount = 0;
        @AuraEnabled public List<OrgGroupDTO> groups = new List<OrgGroupDTO>();

        /** the one file the rep supplies */
        @AuraEnabled public String licenceDocName;
        @AuraEnabled public Boolean licencePresent = false;
        @AuraEnabled public Boolean licenceRead = false;

        @AuraEnabled public OrgSignatoryDTO signatory;
        @AuraEnabled public List<OrgPersonDTO> people = new List<OrgPersonDTO>();
        /** 2.0 - the New Contact form: labels, types and options from the describe */
        @AuraEnabled public List<OrgFieldDTO> newPersonFields = new List<OrgFieldDTO>();
        @AuraEnabled public List<OrgDocDTO> documents = new List<OrgDocDTO>();

        /** what the company still owes compliance, named */
        @AuraEnabled public List<String> outstanding = new List<String>();
        @AuraEnabled public Boolean alreadySubmitted = false;
        @AuraEnabled public Boolean canSubmit = false;
        @AuraEnabled public String submitBlockedReason;

        /** what sendKYCForm would refuse on today */
        @AuraEnabled public Boolean linkReady = false;
        @AuraEnabled public String linkBlockedReason;
    }

    // ----------------------------------------------------------------------
    // What the workspace collects, in the order a rep meets it
    // ----------------------------------------------------------------------

    private class Spec {
        String subject;
        String api;
        String label;
        String note;
        Boolean fillOnly = false;
        Boolean optional = false;
        Spec(String subject, String api, String label, String note) {
            this.subject = subject;
            this.api = api;
            this.label = label;
            this.note = note;
        }
        Spec lock()  { this.fillOnly = true; return this; }
        Spec spare() { this.optional = true; return this; }
    }

    /* The four sendKYCForm returns an error label for, before any DML. Fill-only:
       Signzy writes all four back when the journey completes, so a value already on
       the record is stated rather than offered. */
    private static List<Spec> signatorySpecs() {
        return new List<Spec>{
            new Spec('Contact', 'Nationality__c', 'Nationality', null).lock(),
            new Spec('Contact', 'UAE_Resident_Status__c', 'Residency', null).lock(),
            new Spec('Contact', 'Email', 'Email address', null).lock(),
            new Spec('Contact', 'MobilePhone', 'Mobile number', null).lock()
        };
    }

    /* B6 - the signatory's Mailing address. Optional: captured for the KYC form, never a gate. */
    private static List<Spec> signatoryAddressSpecs() {
        return new List<Spec>{
            new Spec('Contact', 'MailingStreet', 'Mailing street', null).spare(),
            new Spec('Contact', 'MailingCity', 'Mailing city', null).spare(),
            new Spec('Contact', 'MailingState', 'Mailing state', null).spare(),
            new Spec('Contact', 'MailingPostalCode', 'Mailing postal code', null).spare(),
            new Spec('Contact', 'MailingCountry', 'Mailing country', null).spare()
        };
    }

    private static List<Spec> companySpecs() {
        return new List<Spec>{
            new Spec('Account', 'UnifiedNumber__c', 'Licence number',
                     'Also recorded as the company\'s Unified Number').lock(),
            new Spec('Account', 'DateOfEstablishment__c', 'Date the company was formed',
                     'Compliance cannot read the company without it'),
            new Spec('Account', 'TradeLicenseExpiryDate__c', 'Licence expires', null),
            new Spec('Account', 'LegalStructure__c', 'Type of company', null),
            new Spec('Account', 'Description', 'What the company does', null),
            new Spec('Account', 'UAEVATRegisterNumber__c', 'VAT number',
                     'Only if the company is registered for VAT').spare()
        };
    }

    private static List<Spec> riskSpecs() {
        return new List<Spec>{
            new Spec('Account', 'SourceOfIncome__c', 'Source of income', null),
            new Spec('Account', 'OtherSourceOfIncome__c', 'Please specify', null),
            new Spec('Account', 'PaymentMethod__c', 'How the customer is paying', null),
            new Spec('Account', 'DeliveryChannel__c', 'How this sale was made', null)
        };
    }

    // ----------------------------------------------------------------------
    // Reading
    // ----------------------------------------------------------------------

    @AuraEnabled(cacheable=false)
    public static OrgDetailsDTO getOrgDetails(Id opportunityId) {
        return buildDetails(opportunityId);
    }

    private class Ctx {
        Opportunity opp;
        Account acc;
        Contact signatory;
        Boolean ok = false;
        String reason;
    }

    private static Ctx resolve(Id opportunityId) {
        Ctx c = new Ctx();
        if (opportunityId == null) {
            c.reason = 'No booking was supplied.';
            return c;
        }
        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c,
                   Account.Id, Account.Name, Account.IsPersonAccount,
                   Account.UnifiedNumber__c, Account.DateOfEstablishment__c,
                   Account.TradeLicenseExpiryDate__c, Account.LegalStructure__c,
                   Account.UAEVATRegisterNumber__c, Account.Description,
                   Account.Nature_Of_Business__c, Account.SourceOfIncome__c,
                   Account.OtherSourceOfIncome__c, Account.PaymentMethod__c,
                   Account.DeliveryChannel__c, Account.Is_Trade_License_Uploaded__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState,
                   Account.BillingPostalCode, Account.BillingCountry,
                   Account.profileId__c, Account.PassfortApprovalStatus__c,
                   PrimaryContact__r.Id, PrimaryContact__r.Name,
                   PrimaryContact__r.Title,
                   PrimaryContact__r.Email, PrimaryContact__r.MobilePhone,
                   PrimaryContact__r.Nationality__c,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.KYC_Completed_Date__c,
                   PrimaryContact__r.KYC_Send_Date_Time__c,
                   /* 2.x+1 - MODON's two KYC tests on the primary contact (kycSettled) */
                   PrimaryContact__r.KYC_Status__c,
                   PrimaryContact__r.Manual_KYC_Approval__c,
                   PrimaryContact__r.MailingStreet, PrimaryContact__r.MailingCity,
                   PrimaryContact__r.MailingState, PrimaryContact__r.MailingPostalCode,
                   PrimaryContact__r.MailingCountry
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].AccountId == null) {
            c.reason = 'This booking has no customer yet.';
            return c;
        }
        c.opp = opps[0];
        c.acc = opps[0].Account;
        if (c.acc.IsPersonAccount == true) {
            c.reason = 'This booking is for an individual buyer.';
            return c;
        }
        c.signatory = opps[0].PrimaryContact__c == null ? null : opps[0].PrimaryContact__r;
        c.ok = true;
        return c;
    }

    /**
     * The whole workspace, in one answer.
     *
     * Never throws by contract: the popup renders `blockedReason` rather than an
     * error banner behind its own scrim.
     */
    private static OrgDetailsDTO buildDetails(Id opportunityId) {
        OrgDetailsDTO dto = new OrgDetailsDTO();
        Ctx c;
        try {
            c = resolve(opportunityId);
        } catch (Exception e) {
            dto.blockedReason = 'These details could not be read right now.';
            return dto;
        }
        if (!c.ok) {
            dto.blockedReason = c.reason;
            return dto;
        }
        try {
            dto.available   = true;
            dto.accountId   = c.acc.Id;
            dto.companyName = c.acc.Name;

            Map<String, Schema.SObjectField> accF =
                Schema.SObjectType.Account.fields.getMap();
            Map<String, Schema.SObjectField> conF =
                Schema.SObjectType.Contact.fields.getMap();

            // --- the licence, the single highest-value action here -------------
            dto.licenceDocName = DOC_RESIDENT;
            dto.licencePresent = docPresent(c.acc.Id, companyDocNames());
            dto.licenceRead    = c.acc.Is_Trade_License_Uploaded__c == true;

            // --- who signs -----------------------------------------------------
            dto.signatory = signatoryOf(c);
            /* 2.0 - the people ride on EVERY corporate answer: the lookup that chooses
               the Power of Attorney is drawn from them, whoever is assigned today. */
            dto.people = peopleAt(c.acc.Id);
            /* 2.0 - the New Contact form's fields, from the same describe the pane's
               own cells read - its picklists are the org's, never the client's. */
            for (Spec sp : signatorySpecs()) {
                dto.newPersonFields.add(fieldOf(null, sp, conF));
            }

            // --- group 1 - before the link -------------------------------------
            OrgGroupDTO sig = new OrgGroupDTO();
            sig.key   = 'signatory';
            /* 2.0 - the client's name for the role. The KEY is load-bearing (paneKey,
               the rail, the pane all match on it) and does not change. */
            sig.label = 'Power of Attorney';
            if (c.signatory != null) {
                for (Spec s : signatorySpecs()) {
                    sig.fields.add(fieldOf(c.signatory, s, conF));
                }
                /* B6 - the Mailing address, after the four the link needs */
                for (Spec s : signatoryAddressSpecs()) {
                    sig.fields.add(fieldOf(c.signatory, s, conF));
                }
            }
            // the Power of Attorney row itself is an item, not a field
            /* 2.x+1 - counted only while a link may still be needed */
            Boolean rowCounted = dto.signatory.poaRowNeeded == true;
            sig.total = rowCounted ? 1 : 0;
            for (OrgFieldDTO f : sig.fields) {
                if (f.optional == true) { continue; }
                sig.total++;
                if (f.filled == true) { sig.ready++; }
            }
            if (rowCounted && dto.signatory.recorded == true) { sig.ready++; }
            dto.groups.add(sig);

            // --- group 2 - the company ------------------------------------------
            OrgGroupDTO co = new OrgGroupDTO();
            co.key   = 'company';
            co.label = 'Company';
            for (Spec s : companySpecs()) {
                OrgFieldDTO f = fieldOf(c.acc, s, accF);
                /* Decision 3 of the plan. Passfort reads Account.Description; the
                   licence extraction writes the activity list to Nature_Of_Business__c,
                   a field it never reads. Offer it, say where it came from, and let
                   the rep press Save - one field is written and its source is named. */
                if (s.api == 'Description' && f.filled != true
                        && String.isNotBlank(c.acc.Nature_Of_Business__c)) {
                    f.value = c.acc.Nature_Of_Business__c;
                    f.note  = 'Read from the trade licence. Save to record it.';
                }
                co.fields.add(f);
            }
            co.fields.add(addressFact(c.acc));
            for (OrgFieldDTO f : co.fields) {
                if (f.optional == true) { continue; }
                co.total++;
                if (f.filled == true) { co.ready++; }
            }
            // the licence document is the group's first item
            co.total++;
            if (dto.licencePresent == true) { co.ready++; }
            dto.groups.add(co);

            // --- group 3 - the company's risk profile ---------------------------
            OrgGroupDTO risk = new OrgGroupDTO();
            risk.key   = 'risk';
            /* 1.7 - MSC-171. 'Profile', not 'Risk profile'. Display only: the group is
               identified by risk.key = 'risk' everywhere that matters - paneKey, the
               rail's on/ok classes and mscOrgDetails.group all match on the key, never
               on this string. Renaming it moves the rail item and the pane heading
               together, because paneTitle is this same label. */
            risk.label = 'Profile';
            Boolean othersChosen = OTHER_INCOME.equalsIgnoreCase(c.acc.SourceOfIncome__c);
            for (Spec s : riskSpecs()) {
                OrgFieldDTO f = fieldOf(c.acc, s, accF);
                /* Asked for only when the picklist above it says "Others". */
                if (s.api == 'OtherSourceOfIncome__c' && !othersChosen) {
                    f.optional = true;
                }
                risk.fields.add(f);
            }
            for (OrgFieldDTO f : risk.fields) {
                if (f.optional == true) { continue; }
                risk.total++;
                if (f.filled == true) { risk.ready++; }
            }
            dto.groups.add(risk);

            /* --- the signatory's documents ---------------------------------------
               1.4 - COUNTED, because they now block the submission. getEntityRecords
               files a corporate booking as TWO Passfort entities - the company AND its
               primary contact - so pressing Send before Signzy has written back sends
               the signatory with no documents attached. Counting them is what turns
               that ordering rule from something a rep has to remember into something
               the button simply will not let them get wrong. */
            dto.documents = signatoryDocs(c);
            if (!dto.documents.isEmpty()) {
                OrgGroupDTO docs = new OrgGroupDTO();
                docs.key   = 'documents';
                docs.label = 'Documents';
                docs.total = dto.documents.size();
                for (OrgDocDTO d : dto.documents) {
                    if (d.received == true) { docs.ready++; }
                }
                dto.groups.add(docs);
            }

            for (OrgGroupDTO g : dto.groups) {
                if (g.counted == true) {
                    dto.readyCount += g.ready;
                    dto.totalCount += g.total;
                }
            }

            // --- the two gates, both the server's ---------------------------------
            dto.outstanding = outstandingFor(c.acc, dto.licencePresent);
            dto.outstanding.addAll(signatoryOutstanding(c));
            dto.alreadySubmitted = String.isNotBlank(c.acc.profileId__c)
                || String.isNotBlank(c.acc.PassfortApprovalStatus__c);
            if (dto.alreadySubmitted == true) {
                dto.submitBlockedReason = 'This company is already with compliance.';
            } else if (!dto.outstanding.isEmpty()) {
                dto.submitBlockedReason =
                    'Still needed: ' + String.join(dto.outstanding, ', ') + '.';
            } else {
                dto.canSubmit = true;
            }

            List<String> forLink = missingForLink(c.acc.Id);
            dto.linkReady = forLink.isEmpty();
            /* 2.x+1 - no link to send, so no reason to give why it cannot be sent */
            if (!dto.linkReady && dto.signatory.poaRowNeeded == true) {
                dto.linkBlockedReason =
                    'Before the verification link can be sent: '
                    + String.join(forLink, ', ') + '.';
            }
            /* 1.4 - the link is sent FROM HERE, so the rep never leaves the workspace
               to do it. Offered while it would work and the customer has not already
               finished; the card's own button is the same act on the same gate. */
            dto.signatory.canSendLink =
                dto.linkReady == true && dto.signatory.verified != true;
        } catch (Exception e) {
            dto.available = false;
            dto.blockedReason = 'These details could not be read right now.';
        }
        return dto;
    }

    /**
     * The registered address, as one fact.
     *
     * Five fields, one answer, and it is not editable here: c/mscAddress owns it on
     * the customer's own card, and a second address editor is how two screens start
     * disagreeing about where a company is.
     */
    private static OrgFieldDTO addressFact(Account acc) {
        OrgFieldDTO d = new OrgFieldDTO();
        d.key      = 'Account.__address';
        d.api      = '__address';
        d.subject  = 'Account';
        d.label    = 'Registered address';
        d.type     = 'text';
        d.readOnly = true;
        d.filled   = String.isNotBlank(acc.BillingStreet)
            && String.isNotBlank(acc.BillingCity)
            && String.isNotBlank(acc.BillingState)
            && String.isNotBlank(acc.BillingPostalCode)
            && String.isNotBlank(acc.BillingCountry);
        List<String> parts = new List<String>();
        for (String p : new List<String>{
                acc.BillingStreet, acc.BillingCity, acc.BillingState,
                acc.BillingPostalCode, acc.BillingCountry }) {
            if (String.isNotBlank(p)) { parts.add(p.trim()); }
        }
        d.display = parts.isEmpty() ? null : String.join(parts, ', ');
        d.value   = d.display;
        if (d.filled != true) {
            d.note = 'Completed on the customer\'s details.';
        }
        return d;
    }

    private static OrgFieldDTO fieldOf(SObject rec, Spec s,
                                       Map<String, Schema.SObjectField> fields) {
        OrgFieldDTO d = new OrgFieldDTO();
        d.key      = s.subject + '.' + s.api;
        d.api      = s.api;
        d.subject  = s.subject;
        d.label    = s.label;
        d.note     = s.note;
        d.optional = s.optional == true;

        Schema.SObjectField token = fields.get(s.api);
        if (token == null) {
            d.type = 'text';
            return d;
        }
        Schema.DescribeFieldResult f = token.getDescribe();
        d.type = uiTypeOf(f);

        Object raw = rec == null ? null : rec.get(s.api);
        d.filled = raw != null && String.valueOf(raw).trim() != '';
        if (d.filled == true) {
            if (f.getType() == Schema.DisplayType.DATE) {
                Date dt = (Date) raw;
                d.value   = String.valueOf(dt);
                d.display = formatDay(dt);
            } else {
                d.value   = String.valueOf(raw);
                d.display = d.value;
            }
        }
        /* Fill-only: what the record already holds is stated, not offered. Enforced
           again in saveOrgDetails, because a read-only flag is a courtesy and the
           write is the guarantee. */
        d.readOnly = s.fillOnly == true && d.filled == true;

        if (f.getType() == Schema.DisplayType.PICKLIST) {
            d.options = new List<OptionDTO>();
            for (Schema.PicklistEntry pe : f.getPicklistValues()) {
                if (pe.isActive()) { d.options.add(new OptionDTO(pe.getValue())); }
            }
        }
        return d;
    }

    private static String uiTypeOf(Schema.DescribeFieldResult f) {
        Schema.DisplayType t = f.getType();
        if (t == Schema.DisplayType.PICKLIST) { return 'picklist'; }
        if (t == Schema.DisplayType.DATE)     { return 'date'; }
        if (t == Schema.DisplayType.EMAIL)    { return 'email'; }
        if (t == Schema.DisplayType.PHONE)    { return 'phone'; }
        if (t == Schema.DisplayType.TEXTAREA) { return 'textarea'; }
        return 'text';
    }

    private static final List<String> MONTHS = new List<String>{
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    };
    private static String formatDay(Date d) {
        return d == null ? null : d.day() + ' ' + MONTHS[d.month() - 1] + ' ' + d.year();
    }

    // ----------------------------------------------------------------------
    // Who signs
    // ----------------------------------------------------------------------

    private static OrgSignatoryDTO signatoryOf(Ctx c) {
        OrgSignatoryDTO s = new OrgSignatoryDTO();
        if (c.signatory != null) {
            s.contactId      = c.signatory.Id;
            s.name           = c.signatory.Name;
            s.title          = c.signatory.Title;
            s.missing        = andJoin(linkGapsOf(
                c.signatory.Nationality__c, c.signatory.UAE_Resident_Status__c,
                c.signatory.Email, c.signatory.MobilePhone));
            s.kycCompletedOn = c.signatory.KYC_Completed_Date__c;
            s.linkSentAt     = c.signatory.KYC_Send_Date_Time__c;
            /* 2.x+1 - KYC Active or manually approved: verified, and no link (so no row) needed */
            Boolean settled  = kycSettled(c.signatory);
            s.manuallyApproved = 'Approved'.equalsIgnoreCase(c.signatory.Manual_KYC_Approval__c);
            s.verified       = c.signatory.KYC_Completed_Date__c != null || settled;
            s.poaRowNeeded   = !settled;
            s.recorded       = poaExists(c.acc.Id, c.signatory.Id);
            s.canRecord      = s.recorded != true;
            return s;
        }
        /* Nobody is named on the booking. The rep picks from the people the company
           already has - never a new contact, which is the hole that gave PREPROD
           companies with thirteen of them. */
        s.canPick = true;
        return s;
    }

    /**
     * 2.x+1 - True when the primary contact passes checkKYCEligibility's two tests (KYC_Status__c
     * 'KYC Active' or Manual_KYC_Approval__c 'Approved'), so no link and no Power_of_Attorney__c
     * row is needed. Only reads fields resolve() selects.
     */
    @TestVisible
    private static Boolean kycSettled(Contact con) {
        if (con == null) {
            return false;
        }
        return 'KYC Active'.equalsIgnoreCase(con.KYC_Status__c)
            || 'Approved'.equalsIgnoreCase(con.Manual_KYC_Approval__c);
    }

    private static Boolean poaExists(Id accountId, Id contactId) {
        if (accountId == null || contactId == null) {
            return false;
        }
        return ![
            SELECT Id FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :accountId AND Contact__c = :contactId
            LIMIT 1
        ].isEmpty();
    }

    /**
     * The company's own people, oldest first - the longest-standing contact is the
     * likeliest signatory, and the newest is very often a duplicate.
     */
    private static List<OrgPersonDTO> peopleAt(Id accountId) {
        List<OrgPersonDTO> out = new List<OrgPersonDTO>();
        for (Contact c : [
            SELECT Id, Name, Email, MobilePhone, Phone, Title,
                   Nationality__c, UAE_Resident_Status__c
            FROM Contact WHERE AccountId = :accountId
            ORDER BY CreatedDate ASC LIMIT 50
        ]) {
            OrgPersonDTO p = new OrgPersonDTO();
            p.contactId   = c.Id;
            p.name        = c.Name;
            p.email       = c.Email;
            p.phone       = String.isNotBlank(c.MobilePhone) ? c.MobilePhone : c.Phone;
            p.title       = c.Title;
            p.mobile      = c.MobilePhone;
            p.nationality = c.Nationality__c;
            p.residency   = c.UAE_Resident_Status__c;
            p.missing     = andJoin(linkGapsOf(
                c.Nationality__c, c.UAE_Resident_Status__c, c.Email, c.MobilePhone));
            out.add(p);
        }
        return out;
    }

    /**
     * 2.0 - kept for the shipped signature; the semantics are assignSignatory's.
     *
     * The 1.3 body was fill-only, and fill-only could FILE A SECOND ROW: with a row
     * standing against one contact, recording another inserted a second, and
     * sendKYCForm addresses a link to every row it finds. One company, one Power of
     * Attorney is the client's rule, so there is exactly one way to write it.
     */
    @AuraEnabled
    public static OrgDetailsDTO recordSignatory(Id opportunityId, Id contactId) {
        return assignSignatory(opportunityId, contactId);
    }

    /**
     * 2.0 - MSC-181. Assigns the company's Power of Attorney: the person sendKYCForm
     * addresses the verification link to, and the person the booking itself names.
     *
     * ONE ROW PER COMPANY. A company with no row gains one; a company whose row names
     * somebody else has that row REPOINTED - never joined by a second - and
     * Opportunity.PrimaryContact__c moves with it, in the same transaction.
     *
     * REFUSED once the verification is anchored to a person: when the person this
     * write would unfile - the booking's assigned signatory, or whoever the standing
     * row names - has completed identity verification, and when the company is
     * already with compliance. Both locks protect the same thing: compliance assessed
     * a named person, and this write would make the screen describe a different one.
     */
    @AuraEnabled
    public static OrgDetailsDTO assignSignatory(Id opportunityId, Id contactId) {
        Ctx c = resolve(opportunityId);
        if (!c.ok) {
            throw new AuraHandledException(
                String.isBlank(c.reason) ? 'This booking cannot be read.' : c.reason);
        }
        Id target = contactId != null ? contactId : c.opp.PrimaryContact__c;
        if (target == null) {
            throw new AuraHandledException('Choose who signs for the company first.');
        }
        List<Contact> owned = [
            SELECT Id FROM Contact
            WHERE Id = :target AND AccountId = :c.acc.Id LIMIT 1
        ];
        if (owned.isEmpty()) {
            throw new AuraHandledException('That person is not on this company.');
        }

        List<Power_of_Attorney__c> rows = [
            SELECT Id, Contact__c, Contact__r.Name, Contact__r.KYC_Completed_Date__c
            FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :c.acc.Id
            ORDER BY CreatedDate ASC
        ];
        Boolean filed = false;
        Boolean otherFiled = false;
        for (Power_of_Attorney__c row : rows) {
            if (row.Contact__c == target) {
                filed = true;
            } else if (row.Contact__c != null) {
                otherFiled = true;
            }
        }

        /* The lock. Whoever this write would unfile must not have completed their
           identity verification - their journey is the company's verification. */
        if (c.signatory != null && c.signatory.Id != target
                && c.signatory.KYC_Completed_Date__c != null) {
            throw new AuraHandledException(c.signatory.Name
                + ' has already completed identity verification for this company.'
                + ' The Power of Attorney cannot be changed.');
        }
        if (!filed) {
            for (Power_of_Attorney__c row : rows) {
                if (row.Contact__c != null
                        && row.Contact__r.KYC_Completed_Date__c != null) {
                    throw new AuraHandledException(row.Contact__r.Name
                        + ' has already completed identity verification for this company.'
                        + ' The Power of Attorney cannot be changed.');
                }
            }
        }
        /* Once the company is with compliance the submission described a person.
           Completing that same person's record stays allowed - sendKYCForm still
           needs the row - but a different person is refused. */
        Boolean changesPerson =
            (c.signatory != null && c.signatory.Id != target)
            || (c.signatory == null && otherFiled);
        if (changesPerson
                && (String.isNotBlank(c.acc.profileId__c)
                    || String.isNotBlank(c.acc.PassfortApprovalStatus__c))) {
            throw new AuraHandledException('This company is already with compliance.'
                + ' The Power of Attorney cannot be changed.');
        }

        try {
            if (!filed) {
                if (rows.isEmpty()) {
                    /* Name is an AutoNumber on this object - the org names the record. */
                    insert new Power_of_Attorney__c(
                        Organization_Account__c = c.acc.Id,
                        Contact__c = target
                    );
                } else {
                    /* ONE row per company: the standing row is repointed, never joined. */
                    rows[0].Contact__c = target;
                    update rows[0];
                }
            }
            if (c.opp.PrimaryContact__c != target) {
                update new Opportunity(Id = c.opp.Id, PrimaryContact__c = target);
            }
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return buildDetails(opportunityId);
    }

    /**
     * 2.0 - MSC-181. The lookup's New Contact: created with EXACTLY sendKYCForm's
     * required set - nationality, residency, email, mobile - so the person is
     * sendable the moment they exist, and assigned in the same transaction. A
     * refusal from the assign rolls the insert back; no half-made contact remains.
     */
    @AuraEnabled
    public static OrgDetailsDTO createSignatoryContact(Id opportunityId, String fullName,
            String nationality, String residency, String email, String mobile) {
        Ctx c = resolve(opportunityId);
        if (!c.ok) {
            throw new AuraHandledException(
                String.isBlank(c.reason) ? 'This booking cannot be read.' : c.reason);
        }
        if (String.isBlank(fullName) || String.isBlank(nationality)
                || String.isBlank(residency) || String.isBlank(email)
                || String.isBlank(mobile)) {
            throw new AuraHandledException('Enter the full name, nationality, residency,'
                + ' email address and mobile number first.');
        }
        String name = fullName.trim();
        Integer cut = name.lastIndexOf(' ');
        Contact fresh = new Contact(
            AccountId              = c.acc.Id,
            FirstName              = cut > 0 ? name.substring(0, cut).trim() : null,
            LastName               = cut > 0 ? name.substring(cut + 1).trim() : name,
            Nationality__c         = nationality.trim(),
            UAE_Resident_Status__c = residency.trim(),
            Email                  = email.trim(),
            MobilePhone            = mobile.trim(),
            Title                  = 'Power of Attorney'
        );
        try {
            insert fresh;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return assignSignatory(opportunityId, fresh.Id);
    }

    // ----------------------------------------------------------------------
    // Writing
    // ----------------------------------------------------------------------

    /**
     * Writes what the rep filled in and hands back the recomputed picture, so the
     * workspace can never show a readiness the records do not actually have.
     *
     * The allowlist is rebuilt here from the describe rather than trusted from the
     * payload: a caller naming any other field writes nothing, and the save carries
     * on with the rest.
     */
    @AuraEnabled
    public static OrgDetailsDTO saveOrgDetails(Id opportunityId, String fieldsJson) {
        Ctx c = resolve(opportunityId);
        if (!c.ok) {
            throw new AuraHandledException(
                String.isBlank(c.reason) ? 'This booking cannot be read.' : c.reason);
        }
        if (String.isBlank(fieldsJson)) {
            return buildDetails(opportunityId);
        }
        Map<String, Object> supplied;
        try {
            supplied = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
        } catch (Exception e) {
            throw new AuraHandledException('Those details could not be read. Please try again.');
        }

        Map<String, Schema.SObjectField> accF = Schema.SObjectType.Account.fields.getMap();
        Map<String, Schema.SObjectField> conF = Schema.SObjectType.Contact.fields.getMap();

        Account accUpd = new Account(Id = c.acc.Id);
        Boolean accTouched = false;
        Contact conUpd = c.signatory == null ? null : new Contact(Id = c.signatory.Id);
        Boolean conTouched = false;

        for (String key : supplied.keySet()) {
            String subject = key.substringBefore('.');
            String api     = key.substringAfter('.');
            if (String.isBlank(subject) || String.isBlank(api)) { continue; }

            Boolean isAccount = subject == 'Account';
            if (isAccount && !ACCOUNT_WRITABLE.contains(api))  { continue; }
            if (!isAccount && subject != 'Contact')            { continue; }
            if (!isAccount && !CONTACT_WRITABLE.contains(api)) { continue; }
            if (!isAccount && conUpd == null)                  { continue; }

            /* Fill-only, enforced on the write. The read-only flag is a courtesy to
               the screen; this is the guarantee. */
            if (FILL_ONLY.contains(key)) {
                Object held = isAccount ? c.acc.get(api) : c.signatory.get(api);
                if (held != null && String.valueOf(held).trim() != '') { continue; }
            }

            Schema.SObjectField token = isAccount ? accF.get(api) : conF.get(api);
            if (token == null) { continue; }
            Schema.DescribeFieldResult f = token.getDescribe();
            if (!f.isUpdateable()) { continue; }

            Object value = supplied.get(key);
            String raw = value == null ? null : String.valueOf(value);
            Object coerced;
            try {
                coerced = coerceValue(f, raw);
            } catch (Exception e) {
                // A value the field cannot hold is dropped; the rest still saves.
                continue;
            }
            if (isAccount) {
                accUpd.put(api, coerced);
                accTouched = true;
            } else {
                conUpd.put(api, coerced);
                conTouched = true;
            }
        }

        try {
            if (accTouched) { update accUpd; }
            if (conTouched) { update conUpd; }
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return buildDetails(opportunityId);
    }

    /** Turns the rep's string back into what the field actually holds. */
    private static Object coerceValue(Schema.DescribeFieldResult f, String s) {
        if (String.isBlank(s)) {
            return null;
        }
        Schema.DisplayType t = f.getType();
        if (t == Schema.DisplayType.DATE) {
            return Date.valueOf(s);
        }
        if (t == Schema.DisplayType.PICKLIST) {
            // Anything not on the list is refused rather than written.
            for (Schema.PicklistEntry pe : f.getPicklistValues()) {
                if (pe.isActive() && pe.getValue() == s) { return s; }
            }
            throw new IllegalArgumentException('value not in picklist');
        }
        Integer max = f.getLength();
        if (max > 0 && s.length() > max) {
            return s.substring(0, max);
        }
        return s;
    }

    /**
     * The same upload, answering with the workspace's own picture.
     *
     * uploadTradeLicence is left exactly as it is: it answers with OrgStateDTO and
     * changing its return type would change a shipped @AuraEnabled signature.
     */
    @AuraEnabled
    public static OrgDetailsDTO uploadCompanyLicence(
        Id opportunityId,
        String base64,
        String fileName
    ) {
        uploadTradeLicence(opportunityId, base64, fileName);
        return buildDetails(opportunityId);
    }

    // ----------------------------------------------------------------------
    // The two gates, each derived once
    // ----------------------------------------------------------------------

    /**
     * What compliance still needs from this company, named rather than counted.
     *
     * THE ONE READINESS. buildDetails renders it, submitOrganisationCompliance
     * refuses on it and TradeLicenceReadQueueable waits on it, so the screen, the
     * button and the automatic path cannot disagree.
     *
     * The set is PREPROD's answer sheet: every one of the 14 companies that has
     * actually cleared Passfort carries all of these.
     */
    public static List<String> outstandingForCompany(Id accountId) {
        if (accountId == null) {
            return new List<String>{ 'Company' };
        }
        List<Account> found = [
            SELECT Id, UnifiedNumber__c, DateOfEstablishment__c,
                   TradeLicenseExpiryDate__c, LegalStructure__c, Description,
                   SourceOfIncome__c, OtherSourceOfIncome__c, PaymentMethod__c,
                   DeliveryChannel__c, BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (found.isEmpty()) {
            return new List<String>{ 'Company' };
        }
        return outstandingFor(found[0], docPresent(accountId, companyDocNames()));
    }

    /**
     * The signatory's half of the submission gate.
     *
     * getEntityRecords files a corporate booking as TWO Passfort entities - the company
     * AND its primary contact - so a submission with no signatory, or with a signatory
     * whose identity documents have not arrived, files half a customer. Named as ONE
     * item: the documents all arrive together from one Signzy journey, and the
     * Documents pane names them individually.
     */
    private static List<String> signatoryOutstanding(Ctx c) {
        List<String> out = new List<String>();
        if (c.signatory == null) {
            out.add('a Power of Attorney');
            return out;
        }
        for (OrgDocDTO d : signatoryDocs(c)) {
            if (d.received != true) {
                out.add('the customer\'s identity documents');
                return out;
            }
        }
        return out;
    }

    /**
     * THE WHOLE submission gate: the company's own list plus the signatory's.
     *
     * Read by the workspace, by submitOrganisationCompliance and by
     * TradeLicenceReadQueueable, so the screen, the button and the automatic path
     * cannot disagree about what a submission is still waiting on.
     */
    public static List<String> outstandingForSubmission(Id opportunityId) {
        Ctx c;
        try {
            c = resolve(opportunityId);
        } catch (Exception e) {
            return new List<String>{ 'this booking' };
        }
        if (!c.ok) {
            return new List<String>{ 'this booking' };
        }
        List<String> out = outstandingFor(c.acc, docPresent(c.acc.Id, companyDocNames()));
        out.addAll(signatoryOutstanding(c));
        return out;
    }

    private static List<String> outstandingFor(Account acc, Boolean licencePresent) {
        List<String> out = new List<String>();
        if (licencePresent != true) {
            out.add('Trade licence');
        }
        if (String.isBlank(acc.UnifiedNumber__c))          { out.add('Licence number'); }
        if (acc.DateOfEstablishment__c == null)            { out.add('Date the company was formed'); }
        if (acc.TradeLicenseExpiryDate__c == null)         { out.add('Licence expiry'); }
        if (String.isBlank(acc.LegalStructure__c))         { out.add('Type of company'); }
        if (String.isBlank(acc.Description))               { out.add('What the company does'); }
        if (String.isBlank(acc.SourceOfIncome__c))         { out.add('Source of income'); }
        if (OTHER_INCOME.equalsIgnoreCase(acc.SourceOfIncome__c)
                && String.isBlank(acc.OtherSourceOfIncome__c)) {
            out.add('Source of income - please specify');
        }
        if (String.isBlank(acc.PaymentMethod__c))          { out.add('How the customer is paying'); }
        if (String.isBlank(acc.DeliveryChannel__c))        { out.add('How this sale was made'); }
        if (String.isBlank(acc.BillingStreet)
                || String.isBlank(acc.BillingCity)
                || String.isBlank(acc.BillingState)
                || String.isBlank(acc.BillingPostalCode)
                || String.isBlank(acc.BillingCountry)) {
            out.add('Registered address');
        }
        return out;
    }

    /** The four fields sendKYCForm refuses a contact on, worded as the booking words them. */
    private static List<String> linkGapsOf(String nationality, String residency,
                                           String email, String mobile) {
        List<String> gaps = new List<String>();
        if (String.isBlank(nationality)) { gaps.add('nationality'); }
        if (String.isBlank(residency))   { gaps.add('residency'); }
        if (String.isBlank(email))       { gaps.add('email address'); }
        if (String.isBlank(mobile))      { gaps.add('mobile number'); }
        return gaps;
    }

    /** "nationality and email address" - never a bare count. Null when whole. */
    private static String andJoin(List<String> words) {
        if (words == null || words.isEmpty()) { return null; }
        if (words.size() == 1) { return words[0]; }
        List<String> head = new List<String>(words);
        String tail = head.remove(head.size() - 1);
        return String.join(head, ', ') + ' and ' + tail;
    }

    /**
     * What sendKYCForm would refuse this company on today, in its own order.
     *
     * Mirrors CustomerKYCHandler.sendKYCForm's organisation branch, which returns a
     * label and sends nothing: no Power of Attorney row, or a POA contact missing
     * nationality, residency, email or mobile. The loop returns on the FIRST
     * incomplete contact before any DML, so one unfinished person stops the link for
     * everybody - which is why every POA contact is checked here, not just the
     * booking's own signatory.
     *
     * Never throws: SalesConsoleController.getComplianceState calls this on every
     * corporate booking page, and a field-level-security gap on Power_of_Attorney__c
     * must close the button, not break the page.
     */
    public static List<String> missingForLink(Id accountId) {
        List<String> out = new List<String>();
        if (accountId == null) {
            out.add('a customer');
            return out;
        }
        try {
            List<Power_of_Attorney__c> rows = [
                SELECT Id, Contact__c, Contact__r.Name, Contact__r.Nationality__c,
                       Contact__r.UAE_Resident_Status__c, Contact__r.Email,
                       Contact__r.MobilePhone
                FROM Power_of_Attorney__c
                WHERE Organization_Account__c = :accountId AND Contact__c != null
            ];
            if (rows.isEmpty()) {
                out.add('a Power of Attorney');
                return out;
            }
            for (Power_of_Attorney__c p : rows) {
                Contact con = p.Contact__r;
                List<String> gaps = new List<String>();
                if (String.isBlank(con.Nationality__c))         { gaps.add('nationality'); }
                if (String.isBlank(con.UAE_Resident_Status__c)) { gaps.add('residency'); }
                if (String.isBlank(con.Email))                  { gaps.add('email address'); }
                if (String.isBlank(con.MobilePhone))            { gaps.add('mobile number'); }
                if (!gaps.isEmpty()) {
                    /* Named, because the rep cannot see this person on the card and
                       would otherwise get an error about somebody invisible. */
                    out.add(con.Name + '\'s ' + String.join(gaps, ', '));
                }
            }
        } catch (Exception e) {
            out.add('access to the company\'s Power of Attorney');
        }
        return out;
    }

    /** The signatory's own documents. Status and date, never the file. */
    private static List<OrgDocDTO> signatoryDocs(Ctx c) {
        List<OrgDocDTO> out = new List<OrgDocDTO>();
        if (c.signatory == null) {
            return out;
        }
        List<String> required =
            SalesConsoleController.requiredComplianceDocNames(c.signatory.UAE_Resident_Status__c);
        if (required == null || required.isEmpty()) {
            return out;
        }
        Id contactId = c.signatory.Id;
        Map<String, Documents__c> byName = new Map<String, Documents__c>();
        Set<Id> docIds = new Set<Id>();
        for (Documents__c d : [
            SELECT Id, Name, Status__c, LastModifiedDate FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name IN :required
            ORDER BY LastModifiedDate ASC
        ]) {
            byName.put(d.Name, d);
            docIds.add(d.Id);
        }
        Set<Id> withFile = new Set<Id>();
        if (!docIds.isEmpty()) {
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
            ]) {
                withFile.add(l.LinkedEntityId);
            }
        }
        for (String name : required) {
            OrgDocDTO d = new OrgDocDTO();
            d.name = name;
            Documents__c row = byName.get(name);
            if (row != null) {
                d.received = row.Status__c == 'Uploaded' || withFile.contains(row.Id);
                if (d.received == true) { d.receivedOn = row.LastModifiedDate; }
            }
            out.add(d);
        }
        return out;
    }

    // ======================================================================
    // 1.5 - MSC-151. The next step.
    //
    // A corporate booking has exactly ONE thing to do at a time, and the order
    // of those things lives HERE and nowhere else. The bar renders this answer;
    // the cards below it render progress and carry no controls at all. Three
    // surfaces deciding the same question for themselves is what let a card say
    // "the company's details are needed" while every group behind it read full.
    // ======================================================================

    public class OrgNextStepDTO {
        /** which of the eight states this is - the client styles on it, never decides */
        @AuraEnabled public String key;
        /** 'Next step', or who is being waited on */
        @AuraEnabled public String label;
        @AuraEnabled public String headline;
        /** null when there is nothing to press, which is a real answer twice */
        @AuraEnabled public String buttonLabel;
        /** opendetails | sendlink | submit | check */
        @AuraEnabled public String action;
        /** go | wait | rest */
        @AuraEnabled public String tone;
        /**
         * 2.x+1 - the primary contact is approved by hand (Manual_KYC_Approval__c): verified with
         * no completion date. For c/mscVerifyList.
         */
        @AuraEnabled public Boolean signatoryManual = false;
    }

    private static OrgNextStepDTO step(String key, String tone, String label,
                                       String headline, String buttonLabel, String action) {
        OrgNextStepDTO s = new OrgNextStepDTO();
        s.key         = key;
        s.tone        = tone;
        s.label       = label;
        s.headline    = headline;
        s.buttonLabel = buttonLabel;
        s.action      = action;
        return s;
    }

    private static final String L_NEXT     = 'Next step';
    private static final String L_CUSTOMER = 'Waiting on the customer';
    private static final String L_COMPLIANCE = 'With compliance';

    /**
     * The one thing to do now, or the one thing being waited on.
     *
     * The two 'submitted' facts are PASSED IN rather than re-derived: getComplianceState
     * has already asked Passfort's three questions for both subjects, and asking them a
     * second time here would be a second answer waiting to disagree with the first.
     *
     * Never throws. getComplianceState renders this on every corporate booking page, and
     * a failure here must leave the step without a bar, not without a page.
     *
     * @return null for an individual booking - there is no such thing to say about one.
     */
    public static OrgNextStepDTO nextStep(Id opportunityId,
                                          Boolean companySubmitted,
                                          Boolean signatorySubmitted) {
        try {
            Ctx c = resolve(opportunityId);
            if (!c.ok) {
                return null;
            }
            OrgNextStepDTO s = stepFor(c, companySubmitted == true, signatorySubmitted == true);
            /* 2.x+1 - said on every answer, whatever the step */
            if (s != null && c.signatory != null) {
                s.signatoryManual =
                    'Approved'.equalsIgnoreCase(c.signatory.Manual_KYC_Approval__c);
            }
            return s;
        } catch (Exception e) {
            return null;
        }
    }

    /** The eight states, in order. nextStep's body, split out in 2.x+1. */
    private static OrgNextStepDTO stepFor(Ctx c, Boolean coDone, Boolean sigDone) {
        /* 2.x+1 - KYC Active or manually approved: no row to assign, and verified */
        Boolean settled = kycSettled(c.signatory);
        Boolean verified = c.signatory != null
            && (c.signatory.KYC_Completed_Date__c != null || settled);
        Datetime sentAt = c.signatory == null
            ? null : c.signatory.KYC_Send_Date_Time__c;
        String who = c.signatory == null ? 'the Power of Attorney' : c.signatory.Name;

        /* 1 - nobody is filed. sendKYCForm addresses the link to a Power of
               Attorney contact and to nobody else, so this blocks everything.
               2.x+1 - unless no link is needed: then the row is not asked for. */
        if (c.signatory == null || (!settled && !poaExists(c.acc.Id, c.signatory.Id))) {
            return step('signatory', 'go', L_NEXT,
                'No Power of Attorney is assigned for this company.',
                'Assign Power of Attorney', 'opendetails');
        }

        /* 2 - filed, but the link would be refused. Named, because the rep cannot
               see the missing field from the card. */
        if (!verified) {
            List<String> gaps = missingForLink(c.acc.Id);
            if (!gaps.isEmpty()) {
                return step('fixsignatory', 'go', L_NEXT,
                    'Add ' + String.join(gaps, ', ')
                    + ' before the verification link can be sent.',
                    'Complete Power of Attorney details', 'opendetails');
            }
            /* 3 - the link has never gone out. First, because it starts the
                   customer's half and everything else can be done alongside it. */
            if (sentAt == null) {
                return step('sendlink', 'go', L_NEXT,
                    'Send ' + who + ' their verification link.',
                    'Send verification link', 'sendlink');
            }
        }

        /* 4 - THE REP'S OWN WORK BEFORE THE CUSTOMER'S WAIT. The company's own
               list, not the whole submission gate: a rep told to "complete company
               details" when the only gap is the customer's documents opens the
               workspace, finds nothing to fill, and closes it none the wiser. */
        if (!coDone) {
            List<String> owed = outstandingForCompany(c.acc.Id);
            if (!owed.isEmpty()) {
                return step('details', 'go', L_NEXT,
                    owed.size() == 1
                        ? '1 company detail is still needed.'
                        : owed.size() + ' company details are still needed.',
                    'Complete company details', 'opendetails');
            }
        }

        /* 5 - nothing left on this desk. */
        if (!verified) {
            return step('customer', 'wait', L_CUSTOMER,
                who + ' has not finished verifying their identity yet.',
                null, null);
        }

        /* 6 - the company and its signatory go together: getEntityRecords files a
               corporate booking as both entities on one press. */
        if (!coDone) {
            return step('submit', 'go', L_NEXT,
                'Everything compliance needs has been collected.',
                'Send for compliance', 'submit');
        }

        /* 7 - the signatory's own submission, once the company is away. */
        if (!sigDone) {
            return step('check', 'go', L_NEXT,
                who + '\'s identity is verified and ready to submit.',
                'Check Power of Attorney', 'check');
        }

        /* 8 - both away. Nothing to press is the honest answer. */
        return step('done', 'rest', L_COMPLIANCE,
            'The company and the signatory are both with compliance.',
            null, null);
    }
}