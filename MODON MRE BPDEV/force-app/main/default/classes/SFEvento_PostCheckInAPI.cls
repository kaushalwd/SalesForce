/**
 * @description       : REST API exposed to Evento to push event check-in details back onto the
 *                      Expression of Interest (EOI) record. The EOI is matched on its record id,
 *                      which Evento returns to us as "EventId".
 *
 *                      Endpoint : /services/apexrest/evento/checkin
 *                      Method   : POST
 *                      Body     : a single JSON object, or a JSON ARRAY of them. Several
 *                                 objects separated by commas but not wrapped in [ ] is not
 *                                 valid JSON and is rejected with HTTP 400. Shape:
 *                                 {
 *                                   "CheckinStatus"  : "...",
 *                                   "SalesAgentName" : "...",
 *                                   "EventId"        : "a0X...",
 *                                   "LeadId"         : "...",
 *                                   "EventName"      : "...",
 *                                   "TokenNumber"    : "..."
 *                                 }
 *
 *                      Every row is processed independently. A malformed body is the only thing
 *                      that fails the whole call (HTTP 400); anything wrong with an individual
 *                      row is reported against that row and the rest still save. "success" is
 *                      true only when every row saved.
 *
 *                      Each response row echoes eventId as received plus eoiNumber, the
 *                      matched record's EOIId__c. NOTE: SFEvento_GetEOIAPI also returns a
 *                      field called eoiNumber, but that one carries Name. Different values.
 *
 *                      When SalesAgentName is supplied it is matched against the Name of
 *                      ACTIVE users, and that user becomes the owner of the EOI's Opportunity.
 *                      The EOI update and the owner change are one unit per row: if the agent
 *                      cannot be resolved (not found, inactive, more than one match) or either
 *                      save fails, nothing is written for that row, it is reported as failed,
 *                      and the rest of the batch carries on.
 *
 * @author            : Rushi Patel
 * @group             : Evento Integration
 * @date              : 21 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     21 September 2026   Initial draft
 *  1.1      Rushi Patel     21 September 2026   Reject a body carrying more than one top
 *                                               level JSON value instead of silently
 *                                               saving only the first record
 *  1.2      Rushi Patel     21 September 2026   Return EOIId__c as eoiNumber on each row
 *  1.3      Rushi Patel     25 September 2026   Set the Opportunity owner from SalesAgentName,
 *                                               matched on active User Name, saved together
 *                                               with the EOI as one unit per row
 *  *********************************************************************************
 *
 * NOTE: declared "without sharing" on purpose, and for the same reason as
 * SFEvento_GetEOIAPI - this is a system-to-system integration endpoint and must be able
 * to stamp the whole batch irrespective of the record sharing granted to the integration
 * user. Access is still controlled by the connected app / profile, and object and field
 * level security are checked explicitly below.
 */
@RestResource(urlMapping='/evento/checkin/*')
global without sharing class SFEvento_PostCheckInAPI {

    private static final Integer MAX_RECORDS  = 2000;
    private static final Integer MAX_TEXT_LEN = 255;

    /** Bounds the rollback-and-retry loop in saveRows. See there for why it exists. */
    private static final Integer MAX_SAVE_ATTEMPTS = 3;

    /** Thrown for anything the caller can fix, and translated into an HTTP 400. */
    public class BadRequestException extends Exception {}

    /**
     * @description HTTP POST entry point. Never throws - every failure path is turned into
     *              a structured JSON response with the matching HTTP status code.
     */
    @HttpPost
    global static void upsertCheckInDetails() {

        ResponseWrapper response = new ResponseWrapper();
        Savepoint sp;

        try {
            List<CheckInRequest> requests = parseRequestBody();

            if (!hasRequiredAccess()) {
                respond(403, response.fail('No update access on Expressionofinterest__c or the Evento check-in fields'));
                return;
            }

            // Pass 1 - validate every row and work out which EOI ids we actually need.
            // A result row is created for every request row, in the order received, so
            // Evento can line the response up against what it sent.
            Map<Id, CheckInRequest> requestByEoiId = new Map<Id, CheckInRequest>();
            Map<Id, ResultWrapper>  resultByEoiId  = new Map<Id, ResultWrapper>();

            for (CheckInRequest request : requests) {

                ResultWrapper result = new ResultWrapper(request);
                response.records.add(result);

                Id eoiId = validateRow(request, result);
                if (eoiId == null) {
                    continue;
                }
                // Duplicate ids in one payload cannot go into a single DML call, and
                // silently letting the last one win would hide a caller side bug.
                if (requestByEoiId.containsKey(eoiId)) {
                    result.fail('Duplicate EventId, first occurrence used');
                    continue;
                }
                requestByEoiId.put(eoiId, request);
                resultByEoiId.put(eoiId, result);
            }

            // Pass 2 - one query for the whole batch, doing triple duty: it confirms the
            // records exist, collects EOIId__c for the response, and picks up the
            // Opportunity and its current owner for the owner handover, all in one trip.
            Map<Id, Expressionofinterest__c> existingEois = new Map<Id, Expressionofinterest__c>();
            if (!requestByEoiId.isEmpty()) {
                existingEois = new Map<Id, Expressionofinterest__c>([
                    SELECT Id, EOIId__c, Opportunity__c, Opportunity__r.OwnerId
                    FROM   Expressionofinterest__c
                    WHERE  Id IN :requestByEoiId.keySet()
                ]);

                // Iterate a copy of the keys so the map can be pruned inside the loop.
                for (Id eoiId : new List<Id>(requestByEoiId.keySet())) {
                    if (!existingEois.containsKey(eoiId)) {
                        resultByEoiId.get(eoiId).fail('EOI not found');
                        requestByEoiId.remove(eoiId);
                        continue;
                    }
                    // Stamped now rather than after the DML, so a row that fails to save
                    // still comes back carrying the reference Evento can quote to us.
                    resultByEoiId.get(eoiId).eoiNumber = safeString(existingEois.get(eoiId).EOIId__c);
                }
            }

            // Pass 3 - resolve SalesAgentName to an active user. No DML yet, so a row whose
            // agent cannot be resolved is dropped before anything is written for it.
            Map<Id, User> agentByEoiId = resolveSalesAgents(requestByEoiId, resultByEoiId, existingEois);

            // Pass 4 - save the Opportunity owner and the EOI together, per row.
            if (!requestByEoiId.isEmpty()) {
                sp = Database.setSavepoint();
                saveRows(requestByEoiId, resultByEoiId, existingEois, agentByEoiId);
            }

            for (ResultWrapper result : response.records) {
                if (result.success) {
                    response.successCount++;
                } else {
                    response.failureCount++;
                }
            }
            response.totalRecords = response.records.size();

            respond(200, response.finish());

        } catch (BadRequestException bre) {
            respond(400, response.fail(bre.getMessage()));

        } catch (Exception ex) {
            if (sp != null) {
                // Roll the batch back so Evento can safely resend the whole payload.
                Database.rollback(sp);
            }
            // Stamp the requestId on the log so the id quoted back to us by Evento
            // leads straight to this record. Logging must never mask the original
            // failure, so it gets its own guard.
            try {
                Logger__c log = LoggerService.createApexLog(
                    ex, 'SF Evento Post Check In API', 'SFEvento_PostCheckInAPI', 'upsertCheckInDetails'
                );
                log.UUID__c = response.requestId;
                LoggerService.save(log);
            } catch (Exception loggingEx) {
                System.debug(LoggingLevel.ERROR, 'SFEvento_PostCheckInAPI logging failed for requestId '
                    + response.requestId + ': ' + loggingEx.getMessage());
            }
            respond(500, response.fail('Unexpected error, quote requestId ' + response.requestId));
        }
    }

    /**
     * @description Reads the POST body and returns it as a list, so a single object and an
     *              array of objects travel down exactly the same code path from here on.
     * @throws BadRequestException when the body is missing, unparseable or oversized.
     */
    private static List<CheckInRequest> parseRequestBody() {

        RestRequest req = RestContext.request;
        String body = (req == null || req.requestBody == null) ? null : req.requestBody.toString();

        if (String.isBlank(body)) {
            throw new BadRequestException('Request body required');
        }

        String trimmedBody = body.trim();
        List<CheckInRequest> requests;
        try {
            if (trimmedBody.startsWith('[')) {
                requests = (List<CheckInRequest>) JSON.deserialize(trimmedBody, List<CheckInRequest>.class);
            } else {
                requests = new List<CheckInRequest>{
                    (CheckInRequest) JSON.deserialize(trimmedBody, CheckInRequest.class)
                };
            }
        } catch (Exception ex) {
            throw new BadRequestException('Invalid JSON: ' + ex.getMessage());
        }

        // Deserialisation stops at the end of the first value and ignores whatever follows,
        // so comma separated objects that were never wrapped in [ ] would quietly save only
        // the first record. Checked after the deserialise above so genuinely malformed JSON
        // still reports its own parser message rather than this one.
        assertSingleJsonValue(trimmedBody);

        if (requests == null || requests.isEmpty()) {
            throw new BadRequestException('No records in request body');
        }
        if (requests.size() > MAX_RECORDS) {
            throw new BadRequestException('Max ' + MAX_RECORDS + ' records per request, received ' + requests.size());
        }
        return requests;
    }

    /**
     * @description Rejects a body that carries more than one top level JSON value.
     * @throws BadRequestException naming the array wrapper the caller is missing.
     */
    private static void assertSingleJsonValue(String body) {

        String guidance = 'Multiple records must be wrapped in a JSON array: [ {...}, {...} ]';
        try {
            JSONParser parser = JSON.createParser(body);
            parser.nextToken();
            parser.skipChildren();
            if (parser.nextToken() != null) {
                throw new BadRequestException(guidance);
            }
        } catch (BadRequestException bre) {
            throw bre;
        } catch (Exception ex) {
            // The body already deserialised cleanly, so anything the parser trips over here
            // is trailing content rather than a malformed record.
            throw new BadRequestException(guidance);
        }
    }

    /**
     * @description Validates one row and returns the EOI id to update, or null when the row
     *              cannot be processed - in which case the reason is written onto the result.
     */
    private static Id validateRow(CheckInRequest request, ResultWrapper result) {

        if (request == null) {
            result.fail('Empty record');
            return null;
        }
        if (String.isBlank(request.EventId)) {
            result.fail('EventId required');
            return null;
        }

        Id eoiId;
        try {
            eoiId = Id.valueOf(request.EventId.trim());
        } catch (Exception ex) {
            result.fail('Invalid EventId');
            return null;
        }
        if (eoiId.getSObjectType() != Expressionofinterest__c.SObjectType) {
            result.fail('EventId is not an EOI id');
            return null;
        }

        // Every target field is Text(255). Rejecting an oversized value is better than
        // silently truncating something Evento believes it has stored.
        String tooLong = firstOversizedField(request);
        if (tooLong != null) {
            result.fail(tooLong + ' exceeds ' + MAX_TEXT_LEN + ' chars');
            return null;
        }

        if (!hasAnyValue(request)) {
            result.fail('No values supplied');
            return null;
        }
        return eoiId;
    }

    /** @description Returns the name of the first field that is too long, or null. */
    private static String firstOversizedField(CheckInRequest request) {
        if (isTooLong(request.CheckinStatus))  { return 'CheckinStatus';  }
        if (isTooLong(request.SalesAgentName)) { return 'SalesAgentName'; }
        if (isTooLong(request.LeadId))         { return 'LeadId';         }
        if (isTooLong(request.EventName))      { return 'EventName';      }
        if (isTooLong(request.TokenNumber))    { return 'TokenNumber';    }
        if (isTooLong(request.EventId))        { return 'EventId';        }
        return null;
    }

    private static Boolean isTooLong(String value) {
        return value != null && value.trim().length() > MAX_TEXT_LEN;
    }

    /** @description A row with nothing in it would burn a DML row for no reason. */
    private static Boolean hasAnyValue(CheckInRequest request) {
        return normalise(request.CheckinStatus)  != null
            || normalise(request.SalesAgentName) != null
            || normalise(request.LeadId)         != null
            || normalise(request.EventName)      != null
            || normalise(request.TokenNumber)    != null;
    }

    /**
     * @description Resolves SalesAgentName to exactly one active User for every row that
     *              supplies one. A row that cannot be resolved is failed and removed from
     *              requestByEoiId, so nothing is ever written for it.
     *              Rows with no SalesAgentName are left alone and save the check-in only.
     * @return      the resolved agent per EOI id, for the rows that supplied a name.
     */
    private static Map<Id, User> resolveSalesAgents(
        Map<Id, CheckInRequest> requestByEoiId,
        Map<Id, ResultWrapper> resultByEoiId,
        Map<Id, Expressionofinterest__c> eoiById
    ) {
        Map<Id, User> agentByEoiId = new Map<Id, User>();

        Map<Id, String> agentNameByEoiId = new Map<Id, String>();
        for (Id eoiId : requestByEoiId.keySet()) {
            String agentName = normaliseName(requestByEoiId.get(eoiId).SalesAgentName);
            if (agentName != null) {
                agentNameByEoiId.put(eoiId, agentName);
            }
        }
        if (agentNameByEoiId.isEmpty()) {
            return agentByEoiId;
        }

        Boolean canSetOwner = hasOpportunityOwnerAccess();
        Map<String, List<User>> usersByName = canSetOwner
            ? findActiveUsersByName(new Set<String>(agentNameByEoiId.values()))
            : new Map<String, List<User>>();

        // Several EOIs can hang off one Opportunity. The first row to claim it wins - the
        // same rule as duplicate EventIds - and a later row naming someone else is failed.
        Map<Id, User> ownerByOppId = new Map<Id, User>();

        for (Id eoiId : agentNameByEoiId.keySet()) {
            String     agentName = agentNameByEoiId.get(eoiId);
            List<User> matches   = usersByName.get(agentName.toLowerCase());
            Id         oppId     = eoiById.get(eoiId).Opportunity__c;

            String reason;
            if (!canSetOwner) {
                reason = 'No update access on Opportunity owner';
            } else if (oppId == null) {
                reason = 'EOI has no Opportunity to assign to ' + agentName;
            } else if (matches == null) {
                // The query only returns active users, so this covers inactive as well.
                reason = 'No active user found with name ' + agentName;
            } else if (matches.size() > 1) {
                reason = matches.size() + ' active users found with name ' + agentName;
            } else if (ownerByOppId.containsKey(oppId) && ownerByOppId.get(oppId).Id != matches[0].Id) {
                reason = 'Opportunity already assigned to ' + ownerByOppId.get(oppId).Name
                    + ' by an earlier row in this request';
            }

            if (reason != null) {
                resultByEoiId.get(eoiId).fail(reason);
                requestByEoiId.remove(eoiId);
                continue;
            }
            ownerByOppId.put(oppId, matches[0]);
            agentByEoiId.put(eoiId, matches[0]);
        }
        return agentByEoiId;
    }

    /**
     * @description Returns the active users whose Name matches each agent name, keyed by the
     *              lower-cased agent name. A name with no entry has no active match.
     */
    private static Map<String, List<User>> findActiveUsersByName(Set<String> agentNames) {

        Map<String, List<User>> usersByName = new Map<String, List<User>>();

        // SOQL compares text case-insensitively, so "evento AGENT" still finds Evento Agent.
        for (User u : [
            SELECT Id, Name
            FROM   User
            WHERE  IsActive = true
            AND    Name IN :agentNames
        ]) {
            String key = normaliseName(u.Name).toLowerCase();
            if (!usersByName.containsKey(key)) {
                usersByName.put(key, new List<User>());
            }
            usersByName.get(key).add(u);
        }
        return usersByName;
    }

    /**
     * @description Saves the Opportunity owner and the EOI for every row, as one unit per row:
     *              a row either gets both or neither, and one bad row never stops the others.
     *
     *              Owners are saved first, so a row whose owner change fails never has its
     *              EOI touched. The reverse case - owner saved, then the EOI fails - leaves an
     *              owner change behind with no row to justify it. When that happens the whole
     *              attempt is rolled back and replayed without the failed rows. Each replay
     *              drops at least one row, and MAX_SAVE_ATTEMPTS caps the DML spent on it.
     *
     *              A null incoming value means "not supplied" and leaves the field alone,
     *              so Evento can send a partial payload without wiping what is already there.
     */
    private static void saveRows(
        Map<Id, CheckInRequest> requestByEoiId,
        Map<Id, ResultWrapper> resultByEoiId,
        Map<Id, Expressionofinterest__c> eoiById,
        Map<Id, User> agentByEoiId
    ) {
        Set<Id>         pending        = new Set<Id>(requestByEoiId.keySet());
        Map<Id, String> failureByEoiId = new Map<Id, String>();

        for (Integer attempt = 1; attempt <= MAX_SAVE_ATTEMPTS; attempt++) {

            Savepoint attemptSp = Database.setSavepoint();

            // 1. Opportunity owners. An Opportunity the agent already owns needs no DML.
            Map<Id, Opportunity> oppsToUpdate  = new Map<Id, Opportunity>();
            Map<Id, List<Id>>    eoiIdsByOppId = new Map<Id, List<Id>>();
            for (Id eoiId : pending) {
                User agent = agentByEoiId.get(eoiId);
                Expressionofinterest__c eoi = eoiById.get(eoiId);
                if (agent == null || eoi.Opportunity__r.OwnerId == agent.Id) {
                    continue;
                }
                Id oppId = eoi.Opportunity__c;
                oppsToUpdate.put(oppId, new Opportunity(Id = oppId, OwnerId = agent.Id));
                if (!eoiIdsByOppId.containsKey(oppId)) {
                    eoiIdsByOppId.put(oppId, new List<Id>());
                }
                eoiIdsByOppId.get(oppId).add(eoiId);
            }

            Set<Id> savedOppIds = new Set<Id>();
            if (!oppsToUpdate.isEmpty()) {
                List<Opportunity> opps = oppsToUpdate.values();
                List<Database.SaveResult> oppResults = Database.update(opps, false);
                for (Integer i = 0; i < oppResults.size(); i++) {
                    Id oppId = opps[i].Id;
                    if (oppResults[i].isSuccess()) {
                        savedOppIds.add(oppId);
                        continue;
                    }
                    String reason = 'Opportunity owner not updated: ' + describeErrors(oppResults[i].getErrors());
                    for (Id eoiId : eoiIdsByOppId.get(oppId)) {
                        failureByEoiId.put(eoiId, reason);
                        pending.remove(eoiId);
                    }
                }
            }

            // 2. EOIs, only for the rows whose owner change went through (or was not needed).
            List<Expressionofinterest__c> eois = new List<Expressionofinterest__c>();
            for (Id eoiId : pending) {
                eois.add(buildEoiUpdate(eoiId, requestByEoiId.get(eoiId)));
            }
            if (!eois.isEmpty()) {
                List<Database.SaveResult> eoiResults = Database.update(eois, false);
                for (Integer i = 0; i < eoiResults.size(); i++) {
                    if (!eoiResults[i].isSuccess()) {
                        failureByEoiId.put(eois[i].Id, describeErrors(eoiResults[i].getErrors()));
                        pending.remove(eois[i].Id);
                    }
                }
            }

            // 3. Any owner change left with no saved row behind it breaks the unit.
            Boolean orphanedOwnerChange = false;
            for (Id oppId : savedOppIds) {
                Boolean stillBacked = false;
                for (Id eoiId : eoiIdsByOppId.get(oppId)) {
                    stillBacked |= pending.contains(eoiId);
                }
                orphanedOwnerChange |= !stillBacked;
            }
            if (!orphanedOwnerChange) {
                break;
            }

            Database.rollback(attemptSp);
            if (attempt == MAX_SAVE_ATTEMPTS) {
                // Out of attempts and everything above was just undone, so report the rows
                // still standing honestly rather than as saved.
                for (Id eoiId : pending) {
                    failureByEoiId.put(eoiId, 'Not saved, another row in this request kept failing. Resend this record');
                }
                pending.clear();
            }
        }

        for (Id eoiId : requestByEoiId.keySet()) {
            ResultWrapper result = resultByEoiId.get(eoiId);
            if (failureByEoiId.containsKey(eoiId)) {
                result.fail(failureByEoiId.get(eoiId));
                continue;
            }
            result.succeed();
        }
    }

    private static Expressionofinterest__c buildEoiUpdate(Id eoiId, CheckInRequest request) {

        Expressionofinterest__c eoi = new Expressionofinterest__c(Id = eoiId);
        // EventId is the match key, so it is always present and always stamped.
        eoi.Evento_Event_Id__c = normalise(request.EventId);

        if (normalise(request.CheckinStatus)  != null) { eoi.Evento_Check_In_Status__c  = normalise(request.CheckinStatus);  }
        if (normalise(request.SalesAgentName) != null) { eoi.Evento_Sales_Agent_Name__c = normalise(request.SalesAgentName); }
        if (normalise(request.LeadId)         != null) { eoi.Evento_lead_Id__c          = normalise(request.LeadId);         }
        if (normalise(request.EventName)      != null) { eoi.Evento_Event_Name__c       = normalise(request.EventName);      }
        if (normalise(request.TokenNumber)    != null) { eoi.Evento_Token_Number__c     = normalise(request.TokenNumber);    }
        return eoi;
    }

    private static String describeErrors(List<Database.Error> errors) {
        List<String> reasons = new List<String>();
        for (Database.Error err : errors) {
            reasons.add(err.getStatusCode() + ': ' + err.getMessage());
        }
        return String.join(reasons, ' | ');
    }

    /** @description Object and field level security on what the endpoint reads and writes. */
    private static Boolean hasRequiredAccess() {

        Schema.DescribeSObjectResult eoiDescribe = Expressionofinterest__c.SObjectType.getDescribe();
        if (!eoiDescribe.isAccessible() || !eoiDescribe.isUpdateable()) {
            return false;
        }

        List<Schema.SObjectField> writtenFields = new List<Schema.SObjectField>{
            Expressionofinterest__c.Evento_Check_In_Status__c,
            Expressionofinterest__c.Evento_Sales_Agent_Name__c,
            Expressionofinterest__c.Evento_Event_Id__c,
            Expressionofinterest__c.Evento_lead_Id__c,
            Expressionofinterest__c.Evento_Event_Name__c,
            Expressionofinterest__c.Evento_Token_Number__c
        };
        for (Schema.SObjectField field : writtenFields) {
            if (!field.getDescribe().isUpdateable()) {
                return false;
            }
        }
        return true;
    }

    /**
     * @description Checked separately from hasRequiredAccess on purpose - only rows carrying a
     *              SalesAgentName need it, so it fails those rows rather than 403ing the call.
     */
    private static Boolean hasOpportunityOwnerAccess() {
        return Opportunity.SObjectType.getDescribe().isUpdateable()
            && Opportunity.OwnerId.getDescribe().isUpdateable();
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

    /** @description Trims, and collapses a blank into null so it reads as "not supplied". */
    private static String normalise(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    /** @description normalise, plus runs of whitespace collapsed so names split cleanly. */
    private static String normaliseName(String value) {
        String trimmed = normalise(value);
        return trimmed == null ? null : trimmed.replaceAll('\\s+', ' ');
    }

    /** @description Inbound record, named to match the JSON keys Evento sends. */
    global class CheckInRequest {
        global String CheckinStatus;
        global String SalesAgentName;
        global String EventId;
        global String LeadId;
        global String EventName;
        global String TokenNumber;
    }

    /**
     * @description Outbound envelope. Success, validation failure and server error all
     *              share this same shape.
     */
    global class ResponseWrapper {
        global Boolean success      = false;
        global Integer statusCode   = 200;
        global String  message      = '';
        global String  requestId    = UUID.randomUUID().toString();
        global String  timestamp    = Datetime.now().formatGmt('yyyy-MM-dd HH:mm:ss') + ' GMT';
        global Integer totalRecords = 0;
        global Integer successCount = 0;
        global Integer failureCount = 0;
        global List<ResultWrapper> records = new List<ResultWrapper>();

        /** Success only when every single row saved. */
        private ResponseWrapper finish() {
            this.success = this.failureCount == 0;
            this.message = this.successCount + ' of ' + this.totalRecords + ' updated';
            return this;
        }

        private ResponseWrapper fail(String message) {
            this.success      = false;
            this.message      = message;
            this.totalRecords = 0;
            this.successCount = 0;
            this.failureCount = 0;
            this.records      = new List<ResultWrapper>();
            return this;
        }
    }

    /** @description The outcome of one inbound row, echoed back in the order received. */
    global class ResultWrapper {
        global String  eventId   = '';
        global String  eoiNumber = '';
        global Boolean success   = false;
        global String  message   = '';

        private ResultWrapper(CheckInRequest request) {
            this.eventId = request == null ? '' : safeString(request.EventId);
        }

        private void succeed() {
            this.success = true;
            this.message = 'Updated';
        }

        private void fail(String message) {
            this.success = false;
            this.message = message;
        }
    }
}