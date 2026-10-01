/**********************************************************************************************************************
* Name               : ADHA_InvitationSmsSender
* RETIRED 29 Aug 2026 : MODON removed the SMS from batch release; nothing calls this class any more. Kept deployed
*                       because deleting buys nothing; excluded from the production manifests.
* Description        : Tells a beneficiary their batch has opened; the outcome feeds the Login_Enabled__c access
*                      decision. An unregistered aggregator template fails QUIETLY, reporting a clean release.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     27 Aug 2026     Initial.
* 1.1           Aurelix                     28 Aug 2026     Invitation_SMS_Enabled__c master switch, off by default.
**********************************************************************************************************************/
public without sharing class ADHA_InvitationSmsSender {
    private static final String CREDENTIAL_NAME = 'CommunicationAPI';
    @TestVisible private static final String TEMPLATE_INVITATION = 'ADHA_Baniyas_Batch_Invitation';

    @TestVisible private static OIC_Credential__mdt credentialOverride;
    @TestVisible private static List<String> sent = new List<String>();

    /** Why a beneficiary was not enabled, in the words the record keeps. */
    public class SendResult {
        public Boolean ok = false;
        public String providerRef;
        public String failureReason;
    }

    /** Never throws: one bad mobile number must not take the rest of the cohort down, so the
     *  failure is carried back on the result and written to the record instead. */
    public static SendResult send(ADHA_Applicant__c applicant) {
        SendResult result = new SendResult();
        // Before the mobile number check, so a disabled run reports the switch rather than the data.
        // ok stays false, so the batch enables nobody and everyone remains re-runnable once it is on.
        if (ADHA_JourneyController.settings().Invitation_SMS_Enabled__c != true) {
            result.failureReason = 'Invitation SMS is switched off';
            return result;
        }
        if (applicant == null || String.isBlank(applicant.Mobile_Number__c)) {
            result.failureReason = 'No mobile number on the applicant';
            return result;
        }
        try {
            OIC_Credential__mdt credential = credential();
            String payload = payload(
                applicant.Customer_Name__c, applicant.Mobile_Number__c,
                invitationBody(), TEMPLATE_INVITATION
            );
            sent.add(payload);
            // Synchronous on purpose: called under Database.AllowsCallouts, the only way to see the
            // outcome. No test short circuit - this decides sign-in, so tests run the real branch.
            return dispatch(credential, payload);
        } catch (Exception e) {
            result.failureReason = truncate(e.getTypeName() + ': ' + e.getMessage());
            return result;
        }
    }

    private static SendResult dispatch(OIC_Credential__mdt credential, String payload) {
        SendResult result = new SendResult();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(credential.Endpoint__c);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader(
            'Authorization',
            'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(credential.Username__c + ':' + credential.Password__c)
            )
        );
        request.setBody(payload);

        HttpResponse response = new Http().send(request);
        Integer status = response == null ? 0 : response.getStatusCode();
        if (status >= 200 && status < 300) {
            result.ok = true;
            result.providerRef = providerRefFrom(response.getBody());
            return result;
        }
        result.failureReason = truncate('SMS API returned ' + status + ': ' + safeBody(response));
        return result;
    }

    /** The provider's message id, for reconciling delivery later. Best effort: missing it is no
     *  reason to withhold a login the aggregator has already accepted the message for. */
    private static String providerRefFrom(String body) {
        if (String.isBlank(body)) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(body);
            if (parsed instanceof List<Object>) {
                List<Object> rows = (List<Object>) parsed;
                parsed = rows.isEmpty() ? null : rows[0];
            }
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> row = (Map<String, Object>) parsed;
                for (String key : new List<String>{ 'MessageId', 'messageId', 'Id', 'id', 'Reference' }) {
                    if (row.get(key) != null) {
                        return truncate(String.valueOf(row.get(key)), 100);
                    }
                }
            }
        } catch (Exception e) {
            // A body we cannot parse is not a failed send.
        }
        return null;
    }

    /** Project first, Arabic then English, no numbers - which keeps it clear of the bidi placement
     *  problem. PLACEHOLDER WORDING: ADHA signs off both languages before production. */
    @TestVisible
    private static String invitationBody() {
        return 'غرب بني ياس / West Baniyas\n'
            + 'حان دوركم لحجز مسكنكم. يرجى تسجيل الدخول لاختيار المسكن.\n'
            + 'It is your turn to reserve. Please sign in to choose your home.';
    }

    private static String payload(String name, String mobile, String text, String template) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('CustomerName', String.isBlank(name) ? 'Customer' : name);
        body.put('MobileNumber', mobile);
        body.put('TextMessage', text);
        body.put('TemplateName', template);
        body.put('QRCodeURL', '');
        body.put('SendWhatsapp', false);
        body.put('SendSMS', true);
        body.put('InvitationFormURL', '');
        return JSON.serialize(new List<Object>{ body });
    }

    private static OIC_Credential__mdt credential() {
        OIC_Credential__mdt found;
        if (Test.isRunningTest() && credentialOverride != null) {
            found = credentialOverride;
        } else {
            List<OIC_Credential__mdt> rows = [
                SELECT Endpoint__c, Username__c, Password__c
                FROM OIC_Credential__mdt
                WHERE DeveloperName = :CREDENTIAL_NAME
                LIMIT 1
            ];
            found = rows.isEmpty() ? null : rows[0];
        }
        if (found == null || String.isBlank(found.Endpoint__c)) {
            throw new ADHA_SigningService.SigningException('Communication API credential is not configured.');
        }
        return found;
    }

    private static String safeBody(HttpResponse response) {
        String body = response == null ? null : response.getBody();
        return String.isBlank(body) ? '' : body;
    }

    /** SMS_Failure_Reason__c is 255 and SMS_Provider_Ref__c is 100; an overrun would fail the DML
     *  for the whole chunk, which is the one thing this job must not do. */
    private static String truncate(String value) {
        return truncate(value, 255);
    }

    private static String truncate(String value, Integer max) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }
}