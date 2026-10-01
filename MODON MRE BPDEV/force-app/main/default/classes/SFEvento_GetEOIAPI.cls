/**
 * @description       : REST API exposed to Evento to pull the Expression of Interest (EOI) records.
 *                      Returns every Expressionofinterest__c flagged with Sync_with_Evento__c = true
 *                      that already carries an event date (Sync_with_Evento_Date__c != null).
 *                      The endpoint is strictly read only - Sync_with_Evento_Date__c is populated
 *                      upstream and is never written to from here, so a record keeps coming back
 *                      on every call for as long as it matches the filter.
 *
 *                      Endpoint : /services/apexrest/evento/eoi
 *                      Method   : GET
 *                      Params   : limit (optional, integer 1..2000, default 200)
 *
 * @author            : Rushi Patel
 * @group             : Evento Integration
 * @date              : 18 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     18 September 2026   Initial draft
 *  1.1      Rushi Patel     21 September 2026   Added primary contact phone and the
 *                                               converted lead id to the payload
 *  1.2      Rushi Patel     22 September 2026   Split contactName into contactFirstName
 *                                               and contactLastName
 *  1.3      Rushi Patel     24 September 2026   Read only. Filters on
 *                                               Sync_with_Evento_Date__c != null, no longer
 *                                               stamps the field, returns it as eventDate
 *  1.4      Rushi Patel     28 September 2026   Added eoiUniqueId (EOIId__c) to the payload
 *  *********************************************************************************
 *
 * NOTE: declared "without sharing" on purpose. This is a system-to-system integration
 * endpoint and must return the complete result set irrespective of the record sharing
 * granted to the integration user. Access is still controlled by the connected app /
 * profile, and object level security is checked explicitly below.
 */
@RestResource(urlMapping='/evento/eoi/*')
global without sharing class SFEvento_GetEOIAPI {

    private static final Integer DEFAULT_LIMIT = 200;
    private static final Integer MAX_LIMIT     = 2000;

    /** Thrown for anything the caller can fix, and translated into an HTTP 400. */
    public class BadRequestException extends Exception {}

    /**
     * @description HTTP GET entry point. Never throws - every failure path is turned into
     *              a structured JSON response with the matching HTTP status code.
     */
    @HttpGet
    global static void getEOIRecords() {

        ResponseWrapper response = new ResponseWrapper();

        try {
            Integer recordLimit = getRequestedLimit();

            if (!hasRequiredAccess()) {
                respond(403, response.fail('The running user does not have read access on Expressionofinterest__c.'));
                return;
            }

            // Single, bounded, selective query - heap and the 50,000 row SOQL limit are
            // never at risk, and the oldest records are returned first.
            List<Expressionofinterest__c> eoiRecords = [
                SELECT Id, Name, EOIId__c, Status__c, Lead_Source__c, Opportunity__c,
                       Sync_with_Evento_Date__c,
                       Opportunity__r.Owner.Name,
                       Opportunity__r.BrokerAgency__r.Name,
                       Opportunity__r.BrokerAgent__r.Name,
                       Opportunity__r.BrokerAgent__r.Email,
                       Opportunity__r.BrokerAgent__r.MobilePhone,
                       Opportunity__r.Account.Name,
                       Opportunity__r.PrimaryContact__r.FirstName,
                       Opportunity__r.PrimaryContact__r.LastName,
                       Opportunity__r.PrimaryContact__r.Email,
                       Opportunity__r.PrimaryContact__r.Phone,
                       Opportunity__r.PrimaryContact__r.CustomerType__c
                FROM   Expressionofinterest__c
                WHERE  Sync_with_Evento__c = true
                AND    Sync_with_Evento_Date__c != null
                ORDER BY CreatedDate ASC
                LIMIT  :recordLimit
            ];

            if (eoiRecords.isEmpty()) {
                respond(200, response.succeed('No EOI records are available for synchronisation with Evento.'));
                return;
            }

            Set<Id> opportunityIds = new Set<Id>();
            for (Expressionofinterest__c eoi : eoiRecords) {
                if (eoi.Opportunity__c != null) {
                    opportunityIds.add(eoi.Opportunity__c);
                }
            }

            // One extra query for the whole batch, never one per record.
            Map<Id, Id> leadIdByOpportunityId = getConvertedLeadIds(opportunityIds, response.errors);

            for (Expressionofinterest__c eoi : eoiRecords) {
                response.records.add(new EOIWrapper(eoi, leadIdByOpportunityId.get(eoi.Opportunity__c)));
            }
            response.totalRecords = response.records.size();

            respond(200, response.succeed(
                response.errors.isEmpty()
                    ? 'EOI records retrieved successfully.'
                    : 'EOI records retrieved with warnings. See the errors collection for details.'
            ));

        } catch (BadRequestException bre) {
            respond(400, response.fail(bre.getMessage()));

        } catch (Exception ex) {
            // Stamp the requestId on the log so the id quoted back to us by Evento
            // leads straight to this record. Logging must never mask the original
            // failure, so it gets its own guard.
            try {
                Logger__c log = LoggerService.createApexLog(
                    ex, 'SF Evento Get EOI API', 'SFEvento_GetEOIAPI', 'getEOIRecords'
                );
                log.UUID__c = response.requestId;
                LoggerService.save(log);
            } catch (Exception loggingEx) {
                System.debug(LoggingLevel.ERROR, 'SFEvento_GetEOIAPI logging failed for requestId '
                    + response.requestId + ': ' + loggingEx.getMessage());
            }
            respond(500, response.fail(
                'An unexpected error occurred. Please quote requestId ' + response.requestId + ' when raising a support ticket.'
            ));
        }
    }

    /**
     * @description Reads and validates the optional "limit" query parameter.
     * @throws BadRequestException when the value is not an integer or is out of range.
     */
    private static Integer getRequestedLimit() {

        RestRequest req = RestContext.request;
        String rawLimit = (req == null || req.params == null) ? null : req.params.get('limit');

        if (String.isBlank(rawLimit)) {
            return DEFAULT_LIMIT;
        }

        Integer requestedLimit;
        try {
            requestedLimit = Integer.valueOf(rawLimit.trim());
        } catch (Exception ex) {
            throw new BadRequestException('Parameter "limit" must be a valid integer. Received: ' + rawLimit);
        }

        if (requestedLimit < 1 || requestedLimit > MAX_LIMIT) {
            throw new BadRequestException('Parameter "limit" must be between 1 and ' + MAX_LIMIT + '. Received: ' + rawLimit);
        }
        return requestedLimit;
    }

    /**
     * @description Resolves the Lead that was converted into each opportunity, keyed by
     *              opportunity id. An opportunity can in theory be the conversion target of
     *              more than one Lead, so the earliest conversion wins - that is the Lead
     *              that actually created the opportunity.
     *              A missing Lead read permission is reported as a warning rather than
     *              failing the whole call, because leadId is additive to the payload.
     */
    private static Map<Id, Id> getConvertedLeadIds(Set<Id> opportunityIds, List<String> errors) {

        Map<Id, Id> leadIdByOpportunityId = new Map<Id, Id>();
        if (opportunityIds.isEmpty()) {
            return leadIdByOpportunityId;
        }

        if (!Lead.SObjectType.getDescribe().isAccessible()) {
            errors.add('The running user does not have read access on Lead, so leadId has been returned empty.');
            return leadIdByOpportunityId;
        }

        for (Lead convertedLead : [
            SELECT Id, ConvertedOpportunityId
            FROM   Lead
            WHERE  ConvertedOpportunityId IN :opportunityIds
            ORDER BY ConvertedDate ASC NULLS LAST, CreatedDate ASC
        ]) {
            // putIfAbsent semantics - the first row per opportunity is the earliest conversion.
            if (!leadIdByOpportunityId.containsKey(convertedLead.ConvertedOpportunityId)) {
                leadIdByOpportunityId.put(convertedLead.ConvertedOpportunityId, convertedLead.Id);
            }
        }
        return leadIdByOpportunityId;
    }

    /** @description Object level security check. The endpoint only ever reads. */
    private static Boolean hasRequiredAccess() {
        return Expressionofinterest__c.SObjectType.getDescribe().isAccessible()
            && Expressionofinterest__c.Sync_with_Evento_Date__c.getDescribe().isAccessible();
    }

    /** @description Single exit point so every response is serialised the same way. */
    private static void respond(Integer statusCode, ResponseWrapper response) {
        RestResponse res = RestContext.response;
        if (res == null) {
            return;
        }
        response.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json;charset=UTF-8');
        res.statusCode   = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    private static String safeString(String value) {
        return String.isBlank(value) ? '' : value;
    }

    /**
     * @description Outbound envelope. Success, validation failure and server error all
     *              share this same shape.
     */
    global class ResponseWrapper {
        global Boolean          success      = false;
        global Integer          statusCode   = 200;
        global String           message      = '';
        global String           requestId    = UUID.randomUUID().toString();
        global String           timestamp    = Datetime.now().formatGmt('yyyy-MM-dd HH:mm:ss') + ' GMT';
        global Integer          totalRecords = 0;
        global List<EOIWrapper> records      = new List<EOIWrapper>();
        global List<String>     errors       = new List<String>();

        private ResponseWrapper succeed(String message) {
            this.success = true;
            this.message = message;
            return this;
        }

        private ResponseWrapper fail(String message) {
            this.success      = false;
            this.message      = message;
            this.totalRecords = 0;
            this.records      = new List<EOIWrapper>();
            return this;
        }
    }

    /** @description One EOI record as consumed by Evento. */
    global class EOIWrapper {
        global String eoiId;
        global String eoiNumber;
        global String eoiUniqueId      = '';
        global String status;
        global String leadSource;
        global String eventDate        = '';
        global String opportunityId;
        global String leadId           = '';
        global String opportunityOwner = '';
        global String brokerAgencyName = '';
        global String brokerAgentName  = '';
        global String brokerAgentEmail = '';
        global String brokerAgentMobilePhone = '';
        global String accountName      = '';
        global String contactFirstName = '';
        global String contactLastName  = '';
        global String email            = '';
        global String phone            = '';
        global String customerType     = '';

        private EOIWrapper(Expressionofinterest__c eoi, Id convertedLeadId) {
            this.eoiId         = eoi.Id;
            this.eoiNumber     = safeString(eoi.Name);
            this.eoiUniqueId   = safeString(eoi.EOIId__c);
            this.status        = safeString(eoi.Status__c);
            this.leadSource    = safeString(eoi.Lead_Source__c);
            // Sync_with_Evento_Date__c is set upstream, never by this endpoint. Serialised
            // as an ISO-8601 date string so Evento parses it the same way every time.
            this.eventDate     = eoi.Sync_with_Evento_Date__c == null
                                 ? ''
                                 : String.valueOf(eoi.Sync_with_Evento_Date__c);
            this.opportunityId = eoi.Opportunity__c == null ? '' : String.valueOf(eoi.Opportunity__c);
            this.leadId        = convertedLeadId == null ? '' : String.valueOf(convertedLeadId);

            // Opportunity__c is required on the object, but the payload must never blow
            // up on a null relationship - defensive null handling all the way down.
            if (eoi.Opportunity__r == null) {
                return;
            }
            Opportunity opp = eoi.Opportunity__r;

            if (opp.Owner != null)           { this.opportunityOwner = safeString(opp.Owner.Name); }
            if (opp.BrokerAgency__r != null) { this.brokerAgencyName = safeString(opp.BrokerAgency__r.Name); }

            // BrokerAgent__c and PrimaryContact__c are both Contact lookups. Name, FirstName,
            // LastName and Email resolve for a standard contact and a person account contact
            // alike - on a person account, Contact.Email is the same underlying field as
            // Account.PersonEmail.
            if (opp.BrokerAgent__r != null) {
                this.brokerAgentName        = safeString(opp.BrokerAgent__r.Name);
                this.brokerAgentEmail       = safeString(opp.BrokerAgent__r.Email);
                this.brokerAgentMobilePhone = safeString(opp.BrokerAgent__r.MobilePhone);
            }

            if (opp.Account != null) { this.accountName = safeString(opp.Account.Name); }

            if (opp.PrimaryContact__r != null) {
                this.contactFirstName = safeString(opp.PrimaryContact__r.FirstName);
                this.contactLastName  = safeString(opp.PrimaryContact__r.LastName);
                this.email        = safeString(opp.PrimaryContact__r.Email);
                this.phone        = safeString(opp.PrimaryContact__r.Phone);
                this.customerType = safeString(opp.PrimaryContact__r.CustomerType__c);
            }
        }
    }
}