/**********************************************************************************************************************
* Name               : SmsVerificationSender
* Description        : Sends verification OTP codes through the Communication API SMS channel
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial SMS sender implementation
**********************************************************************************************************************/
public class SmsVerificationSender implements VerificationSender {
    private static final String CREDENTIAL_NAME = 'CommunicationAPI';
    private static final String TEMPLATE_NAME = 'muheira_launch_jan2026_qr_code_public';
    @TestVisible private static OIC_Credential__mdt credentialOverride;

    public void send(VerificationMessage message) {
        if (message == null || String.isBlank(message.target)) {
            throw new VerificationService.VerificationException('Mobile number is required to send a verification code.');
        }

        OIC_Credential__mdt credential = getCredential();
        sendSmsAsync(credential.Endpoint__c, credential.Username__c, credential.Password__c, buildPayload(message));
    }

    @future(callout=true)
    private static void sendSmsAsync(String endpoint, String username, String password, String payload) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Basic ' + getBasicAuthToken(username, password));
        request.setBody(payload);

        HttpResponse response = new Http().send(request);
        Integer statusCode = response == null ? 0 : response.getStatusCode();
        if (statusCode < 200 || statusCode >= 300) {
            throw new VerificationService.VerificationException('SMS verification API failed with status ' + statusCode + '.');
        }
    }

    private static OIC_Credential__mdt getCredential() {
        if (Test.isRunningTest() && credentialOverride != null) return credentialOverride;
        List<OIC_Credential__mdt> credentials = [
            SELECT Endpoint__c, Username__c, Password__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = :CREDENTIAL_NAME
            LIMIT 1
        ];
        if (credentials.isEmpty() || String.isBlank(credentials[0].Endpoint__c)) {
            throw new VerificationService.VerificationException('SMS verification credential is not configured.');
        }
        return credentials[0];
    }

    private static String getBasicAuthToken(String username, String password) {
        String authString = username + ':' + password;
        return EncodingUtil.base64Encode(Blob.valueOf(authString));
    }

    private static String buildPayload(VerificationMessage message) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('CustomerName', 'Customer');
        body.put('MobileNumber', message.target);
        body.put('TextMessage', message.body);
        body.put('TemplateName', String.isBlank(message.templateName) ? TEMPLATE_NAME : message.templateName);
        body.put('QRCodeURL', 'Bashayer');
        body.put('SendWhatsapp', false);
        body.put('SendSMS', true);
        body.put('InvitationFormURL', 'test');
        return JSON.serialize(new List<Object>{ body });
    }
}