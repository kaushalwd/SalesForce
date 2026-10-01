/**
 * @description       : REST API that returns the Lead sync queue.
 *                      Returns every Lead flagged with Sync_Lead__c = true that has not been
 *                      stamped yet (Sync_Lead_Date__c = null), is Retired, and carries one of
 *                      the agreed retired reasons - then stamps the returned records with
 *                      today's date so they are not sent twice.
 *
 *                      Endpoint : /services/apexrest/lead
 *                      Method   : GET
 *                      Params   : limit (optional, integer 1..2000, default 200)
 *
 * @author            : Rushi Patel
 * @group             : Lead Integration
 * @date              : 18 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     18 September 2026   Initial draft
 *  *********************************************************************************
 *
 * NOTE: declared "without sharing" on purpose. This is a system-to-system integration
 * endpoint and must return the complete sync queue irrespective of the record sharing
 * granted to the integration user. Access is still controlled by the connected app /
 * profile, and object level security is checked explicitly below.
 */
@RestResource(urlMapping='/lead/*')
global without sharing class SF_GetLeadAPI {

    private static final Integer DEFAULT_LIMIT = 200;
    private static final Integer MAX_LIMIT     = 2000;

    private static final String STATUS_RETIRED = 'Retired';

    // ONLY THESE RETIRED REASONS ARE IN SCOPE FOR THE SYNC
    private static final Set<String> RETIRED_REASONS = new Set<String>{
        'Retired',
        'Future Potential',
        'No Answer',
        'Interest Lost',
        'Unit Location',
        'Payment Plan',
        'Price'
    };

    /** Thrown for anything the caller can fix, and translated into an HTTP 400. */
    public class BadRequestException extends Exception {}

    /**
     * @description HTTP GET entry point. Never throws - every failure path is turned into
     *              a structured JSON response with the matching HTTP status code.
     */
    @HttpGet
    global static void getLeadRecords() {

        ResponseWrapper response = new ResponseWrapper();
        Savepoint sp;

        try {
            Integer recordLimit = getRequestedLimit();

            if (!hasRequiredAccess()) {
                respond(403, response.fail('The running user does not have read/update access on Lead.'));
                return;
            }

            // Single, bounded, selective query - heap and the 50,000 row SOQL limit are
            // never at risk, and the oldest records drain first.
            List<Lead> leadRecords = [
                SELECT Id, Name, Status, RetiredReason__c
                FROM   Lead
                WHERE  Sync_Lead__c = true
                AND    Sync_Lead_Date__c = null
                AND    Status = :STATUS_RETIRED
                AND    RetiredReason__c IN :RETIRED_REASONS
                ORDER BY CreatedDate ASC
                LIMIT  :recordLimit
            ];

            if (leadRecords.isEmpty()) {
                respond(200, response.succeed('No Lead records are pending synchronisation.'));
                return;
            }

            // Stamp first, then build the payload from whatever stamped successfully.
            // A record that fails to stamp is left out and simply comes back on the
            // next call, so nothing is ever silently lost.
            sp = Database.setSavepoint();
            Set<Id> failedIds = stampSyncDate(leadRecords, response.errors);

            for (Lead leadRecord : leadRecords) {
                if (!failedIds.contains(leadRecord.Id)) {
                    response.records.add(new LeadWrapper(leadRecord));
                }
            }
            response.totalRecords = response.records.size();

            respond(200, response.succeed(
                response.errors.isEmpty()
                    ? 'Lead records retrieved and stamped successfully.'
                    : 'Lead records retrieved. Some records could not be stamped and will be returned on the next call.'
            ));

        } catch (BadRequestException bre) {
            respond(400, response.fail(bre.getMessage()));

        } catch (Exception ex) {
            if (sp != null) {
                // Roll the stamp back so the whole batch is re-delivered next time.
                Database.rollback(sp);
            }
            // Stamp the requestId on the log so the id quoted back to us by the consumer
            // leads straight to this record. Logging must never mask the original
            // failure, so it gets its own guard.
            try {
                Logger__c log = LoggerService.createApexLog(
                    ex, 'SF Get Lead API', 'SF_GetLeadAPI', 'getLeadRecords'
                );
                log.UUID__c = response.requestId;
                LoggerService.save(log);
            } catch (Exception loggingEx) {
                System.debug(LoggingLevel.ERROR, 'SF_GetLeadAPI logging failed for requestId '
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
     * @description Stamps Sync_Lead_Date__c on every record in one partial-success DML
     *              call and returns the ids that failed, adding their reason to errors.
     */
    private static Set<Id> stampSyncDate(List<Lead> leadRecords, List<String> errors) {

        List<Lead> recordsToUpdate = new List<Lead>();
        for (Lead leadRecord : leadRecords) {
            recordsToUpdate.add(new Lead(
                Id                = leadRecord.Id,
                Sync_Lead_Date__c = Date.today()
            ));
        }

        // allOrNone = false, so one bad record (validation rule, trigger, row lock) does
        // not take the whole batch down. One DML statement for the entire collection.
        Set<Id> failedIds = new Set<Id>();
        List<Database.SaveResult> saveResults = Database.update(recordsToUpdate, false);

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                continue;
            }
            failedIds.add(recordsToUpdate[i].Id);
            for (Database.Error err : saveResults[i].getErrors()) {
                errors.add(recordsToUpdate[i].Id + ' - ' + err.getStatusCode() + ': ' + err.getMessage());
            }
        }
        return failedIds;
    }

    /** @description Object level security check on what the endpoint reads and writes. */
    private static Boolean hasRequiredAccess() {
        Schema.DescribeSObjectResult leadDescribe = Lead.SObjectType.getDescribe();
        return leadDescribe.isAccessible()
            && leadDescribe.isUpdateable()
            && Lead.Sync_Lead_Date__c.getDescribe().isUpdateable();
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
        global Boolean           success      = false;
        global Integer           statusCode   = 200;
        global String            message      = '';
        global String            requestId    = UUID.randomUUID().toString();
        global String            timestamp    = Datetime.now().formatGmt('yyyy-MM-dd HH:mm:ss') + ' GMT';
        global Integer           totalRecords = 0;
        global List<LeadWrapper> records      = new List<LeadWrapper>();
        global List<String>      errors       = new List<String>();

        private ResponseWrapper succeed(String message) {
            this.success = true;
            this.message = message;
            return this;
        }

        private ResponseWrapper fail(String message) {
            this.success      = false;
            this.message      = message;
            this.totalRecords = 0;
            this.records      = new List<LeadWrapper>();
            return this;
        }
    }

    /**
     * @description One Lead record as consumed by the calling system.
     *              Add further fields here and to the SOQL above as the contract grows.
     */
    global class LeadWrapper {
        global String leadId;
        global String leadName;
        global String status;
        global String retiredReason;

        private LeadWrapper(Lead leadRecord) {
            this.leadId        = leadRecord.Id;
            this.leadName      = safeString(leadRecord.Name);
            this.status        = safeString(leadRecord.Status);
            this.retiredReason = safeString(leadRecord.RetiredReason__c);
        }
    }
}