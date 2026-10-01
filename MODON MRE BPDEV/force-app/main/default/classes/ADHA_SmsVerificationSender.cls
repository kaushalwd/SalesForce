/**********************************************************************************************************************
* Name               : ADHA_SmsVerificationSender
* Description        : Sends the Baniyas one-time code over the Communication API, bilingually. Separate from the shared
*                      EOI sender; wired in by Verification_Config.ADHA_BANIYAS_SMS -> Sender_Class__c via Type.forName.
* Usage              : Never called directly. VerificationService.getSender instantiates it.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial.
**********************************************************************************************************************/
public class ADHA_SmsVerificationSender implements VerificationSender {
    private static final String CREDENTIAL_NAME = 'CommunicationAPI';
    @TestVisible private static OIC_Credential__mdt credentialOverride;

    public void send(VerificationMessage message) {
        if (message == null || String.isBlank(message.target)) {
            throw new VerificationService.VerificationException('Mobile number is required to send a verification code.');
        }
        OIC_Credential__mdt credential = getCredential();
        sendSmsAsync(
            credential.Endpoint__c,
            credential.Username__c,
            credential.Password__c,
            buildPayload(message, nameFor(message.contextKey))
        );
    }

    /** Project first so the code is attributed, then the CODE ALONE ON ITS OWN LINE: SMS carries no
     *  markup, and a code on a mixed Arabic/Latin line is reordered by the handset's bidi algorithm. */
    @TestVisible
    private static String bodyFor(String code, Integer expiryMinutes) {
        Integer minutes = expiryMinutes == null ? 5 : expiryMinutes;
        return 'West Baniyas / غرب بني ياس\n'
            + 'OTP: ' + code + '\n\n'
            + 'هذا رمز التحقق صالح لمدة ' + arabicMinutes(minutes) + ' فقط. يرجى عدم مشاركة الرمز.\n\n'
            + 'This verification code is valid for ' + englishMinutes(minutes) + ' only. '
            + 'Please do not share the code.';
    }

    /** English agreement, which the old wording dodged by abbreviating to "min". */
    @TestVisible
    private static String englishMinutes(Integer minutes) {
        return minutes == 1 ? '1 minute' : minutes + ' minutes';
    }

    /** Arabic counted-noun agreement changes with the number: one, two, a small plural for 3-10,
     *  singular again from 11. OTP_TTL_Minutes__c is configurable, so one interpolated form misrendered. */
    @TestVisible
    private static String arabicMinutes(Integer minutes) {
        if (minutes == 1) {
            return 'دقيقة واحدة';
        }
        if (minutes == 2) {
            return 'دقيقتان';
        }
        return minutes >= 3 && minutes <= 10
            ? minutes + ' دقائق'
            : minutes + ' دقيقة';
    }

    /** The applicant Id travels on the verification row as Context_Key__c. */
    private static String nameFor(String contextKey) {
        if (String.isBlank(contextKey)) {
            return 'Customer';
        }
        List<ADHA_Applicant__c> rows = [
            SELECT Customer_Name__c FROM ADHA_Applicant__c WHERE Id = :contextKey LIMIT 1
        ];
        return rows.isEmpty() || String.isBlank(rows[0].Customer_Name__c)
            ? 'Customer'
            : rows[0].Customer_Name__c;
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
            throw new VerificationService.VerificationException(
                'SMS verification API failed with status ' + statusCode + '.'
            );
        }
    }

    private static OIC_Credential__mdt getCredential() {
        if (Test.isRunningTest() && credentialOverride != null) {
            return credentialOverride;
        }
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
        return EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
    }

    /** Payload keys match the Communication API contract the EOI sender satisfies; its WhatsApp/QR
     *  fields are sent empty rather than with another project's placeholder strings. */
    @TestVisible
    private static String buildPayload(VerificationMessage message, String customerName) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('CustomerName', customerName);
        body.put('MobileNumber', message.target);
        body.put('TextMessage', bodyFor(message.code, expiryMinutes(message)));
        body.put('TemplateName', message.templateName);
        body.put('QRCodeURL', '');
        body.put('SendWhatsapp', false);
        body.put('SendSMS', true);
        body.put('InvitationFormURL', '');
        return JSON.serialize(new List<Object>{ body });
    }

    /** VerificationService puts the expiry into its own English body, not onto the DTO, so it is
     *  read back from the configured setting rather than parsed out of that sentence. */
    private static Integer expiryMinutes(VerificationMessage message) {
        MessagingConfigService.VerificationConfig config =
            MessagingConfigService.getVerificationConfig(message.context, message.channel);
        return config == null || config.expiryMinutes == null ? 5 : config.expiryMinutes;
    }
}