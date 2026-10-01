/**
 * RelixCallbackResource - the public endpoint Relix calls when a journey ends.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. Review fixes: EXPIRED is no longer closed (a late
 *                                    callback can still flag the row for a read), and a failed event
 *                                    publish answers 503 so Relix retries instead of a silent 200.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Exposed through the Relix_Callback site at
 *                                    /services/apexrest/relix/callback/<token>. Dalil has not
 *                                    documented the callback body or how it is signed (review note
 *                                    R6), so the body is never read. The call is only a signal: the
 *                                    token in the path names the case, and the case is then read
 *                                    from Relix with the API key by a user who holds it, not by this
 *                                    guest. The guest writes nothing; it publishes one platform
 *                                    event, and even that only when the case is still open and no
 *                                    callback arrived in the last minute.
 *
 * WHY A TOKEN. The Relix caseId is not a secret (it appears in emails and logs on Dalil's side). A
 * 256 bit token minted per case, of which only the SHA-256 hash is stored, means a guessed or leaked
 * caseId cannot make Salesforce do anything.
 *
 * OWNERSHIP. Owner: MODON. Needs the guest permission set Relix_Callback_Guest.
 */
@RestResource(urlMapping='/relix/callback/*')
global without sharing class RelixCallbackResource {

    private static final Set<String> CLOSED = new Set<String>{
        RelixPassRule.PASSED, RelixPassRule.REFUSED
    };
    @TestVisible private static final Integer THROTTLE_SECONDS = 60;

    @HttpPost
    global static void receive() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) { res = new RestResponse(); RestContext.response = res; }
        res.addHeader('Content-Type', 'application/json');

        String token = lastSegment(req == null ? null : req.requestURI);
        if (String.isBlank(token) || token.length() > 128 || !token.isAlphanumeric()) {
            answer(res, 404, 'unknown');
            return;
        }
        String hash = RelixKycService.hashToken(token);
        List<Relix_KYC_Case__c> rows = [
            SELECT Id, Decision__c, Callback_Received_At__c
            FROM Relix_KYC_Case__c WHERE Callback_Token_Hash__c = :hash LIMIT 1
        ];
        if (rows.isEmpty()) {
            answer(res, 404, 'unknown');
            return;
        }
        Relix_KYC_Case__c row = rows[0];
        if (CLOSED.contains(row.Decision__c)) {
            answer(res, 200, 'closed');   // 200 so Relix does not retry a case we are done with
            return;
        }
        if (row.Callback_Received_At__c != null
                && row.Callback_Received_At__c > System.now().addSeconds(-THROTTLE_SECONDS)) {
            answer(res, 200, 'throttled');
            return;
        }
        Database.SaveResult published = EventBus.publish(new Relix_Signal__e(
            Case_Row_Id__c = row.Id, Kind__c = RelixKycService.SIGNAL_CALLBACK));
        if (!published.isSuccess()) {
            String code = published.getErrors().isEmpty() ? 'unknown' : String.valueOf(published.getErrors()[0].getStatusCode());
            RelixLogger.failure('callback', 'Signal not published: ' + code, row.Id);
            answer(res, 503, 'retry');
            return;
        }
        answer(res, 200, 'queued');
    }

    /** The token is the last path segment: .../relix/callback/<token>. */
    @TestVisible
    private static String lastSegment(String uri) {
        if (String.isBlank(uri)) { return null; }
        String u = uri;
        Integer q = u.indexOf('?');
        if (q >= 0) { u = u.substring(0, q); }
        while (u.endsWith('/')) { u = u.removeEnd('/'); }
        Integer i = u.lastIndexOf('/');
        String seg = i >= 0 ? u.substring(i + 1) : u;
        return seg == 'callback' ? null : seg;
    }

    private static void answer(RestResponse res, Integer status, String action) {
        res.statusCode = status;
        res.responseBody = Blob.valueOf('{"received":' + (status == 200 ? 'true' : 'false') + ',"action":"' + action + '"}');
    }
}