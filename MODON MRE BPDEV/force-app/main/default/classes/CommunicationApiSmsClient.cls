/**********************************************************************************************
 * Name           : CommunicationApiSmsClient
 * Description     : Reusable SMS client over the Communication API (Oracle OIC), reusing the same
 *                   OIC_Credential__mdt 'CommunicationAPI' record as the verification SMS sender.
 *                   Read-only credential reuse - does not modify the existing verification flow.
 * Usage           : CommunicationApiSmsClient.sendBulk(requests);
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    26 Jun 2026    Initial version.
 **********************************************************************************************/
public without sharing class CommunicationApiSmsClient {

    private static final String CREDENTIAL_NAME = 'CommunicationAPI';
    // Set this if the gateway requires a registered SMS template; left blank to send free text.
    private static final String DEFAULT_TEMPLATE = '';
    @TestVisible private static OIC_Credential__mdt credentialOverride;

    public class SmsRequest {
        public String mobileNumber;
        public String text;
        public String customerName;
        public String templateName;
    }

    public class SmsResult {
        public Boolean success = false;
        public Integer statusCode;
        public String body;
        public String error;
    }

    public static List<SmsResult> sendBulk(List<SmsRequest> requests) {
        List<SmsResult> results = new List<SmsResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        OIC_Credential__mdt cred = getCredential();
        Boolean configured = cred != null && String.isNotBlank(cred.Endpoint__c);
        String authHeader = configured
            ? 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(cred.Username__c + ':' + cred.Password__c))
            : null;

        for (SmsRequest r : requests) {
            SmsResult res = new SmsResult();
            if (!configured) {
                res.error = 'Communication API credential is not configured.';
                results.add(res);
                continue;
            }
            if (r == null || String.isBlank(r.mobileNumber) || String.isBlank(r.text)) {
                res.error = 'Missing recipient or message text.';
                results.add(res);
                continue;
            }
            try {
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(cred.Endpoint__c);
                httpReq.setMethod('POST');
                httpReq.setTimeout(120000);
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setHeader('Authorization', authHeader);
                httpReq.setBody(buildPayload(r));
                HttpResponse resp = new Http().send(httpReq);
                res.statusCode = resp.getStatusCode();
                res.body = resp.getBody();
                res.success = res.statusCode >= 200 && res.statusCode < 300;
                if (!res.success) {
                    res.error = 'SMS gateway returned status ' + res.statusCode;
                }
            } catch (Exception ex) {
                res.error = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    private static String buildPayload(SmsRequest r) {
        String template = String.isBlank(r.templateName) ? DEFAULT_TEMPLATE : r.templateName;
        Map<String, Object> body = new Map<String, Object>{
            'CustomerName' => String.isBlank(r.customerName) ? 'Customer' : r.customerName,
            'MobileNumber' => r.mobileNumber,
            'TextMessage' => r.text,
            'SendWhatsapp' => false,
            'SendSMS' => true
        };
        if (String.isNotBlank(template)) {
            body.put('TemplateName', template);
        }
        return JSON.serialize(new List<Object>{ body });
    }

    private static OIC_Credential__mdt getCredential() {
        if (Test.isRunningTest() && credentialOverride != null) {
            return credentialOverride;
        }
        List<OIC_Credential__mdt> creds = [
            SELECT Endpoint__c, Username__c, Password__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = :CREDENTIAL_NAME
            LIMIT 1
        ];
        return creds.isEmpty() ? null : creds[0];
    }
}