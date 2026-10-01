/**********************************************************************************************************************
* Name               : MBP_RegistrationGatewayController
* Description        : Entry point for the broker registration form on the portal. Checks the caller is allowed to
*                      touch the registration, then hands the work to MBP_RegistrationFormController.
*
*                      A registration carries a secret key in Session_Id__c. It is handed out when the record is
*                      created here, or once the email OTP is verified, and every later call has to send it back.
*                      A logged in broker on the same agency is allowed without one, which is the Required More
*                      Information flow.
*
*                      OTP runs on VerificationService (context BROKER_REGISTRATION) with a send cap here, the same
*                      way EOIService guards its sign in codes.
* Created By         : Kiran Rehan
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Kiran Rehan                       13 Sep 2026     Initial version
**********************************************************************************************************************/
public without sharing class MBP_RegistrationGatewayController {

    private static final String OTP_CONTEXT = 'BROKER_REGISTRATION';
    private static final String OTP_CHANNEL = 'Email';

    // startVerification only caps resends of one request, so cap new requests per email here as well.
    private static final Integer SENDS_PER_WINDOW = 5;
    private static final Integer SEND_WINDOW_MINUTES = 10;

    private static final String STATUS_DRAFT = 'Draft';

    // One message for every refusal, so nothing about the record leaks through the error.
    @TestVisible private static final String MSG_DENIED = 'This registration could not be opened. Please resume it with your Trade License Number.';

    public class SessionResult {
        @AuraEnabled public Id registrationId;
        @AuraEnabled public String sessionId;
        @AuraEnabled public Registration__c registration;
    }

    public class OtpStartResult {
        @AuraEnabled public Id registrationId;
        @AuraEnabled public String maskedTarget;
        @AuraEnabled public String status;       // SENT | NOT_FOUND | NOT_DRAFT
        @AuraEnabled public String statusValue;  // the real status when NOT_DRAFT
    }

    public class ExistsResult {
        @AuraEnabled public Boolean exists;
        @AuraEnabled public Boolean resumable;
        @AuraEnabled public String statusValue;
    }

    /* ---------------- Opening a session ---------------- */

    // Tells the form whether a registration is already there. No record data comes back.
    @AuraEnabled(cacheable=false)
    public static ExistsResult checkExistingRegistration(String value) {
        ExistsResult out = new ExistsResult();
        out.exists = false;
        out.resumable = false;
        if (String.isBlank(value)) {
            return out;
        }
        String needle = value.trim();
        List<Registration__c> rows = [
            SELECT Id, Status__c
            FROM Registration__c
            WHERE Company_Email_Address__c = :needle OR Trade_License_Number__c = :needle
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return out;
        }
        out.exists = true;
        out.statusValue = rows[0].Status__c;
        out.resumable = rows[0].Status__c == STATUS_DRAFT;
        return out;
    }

    // First save of step 1. The browser that created the record gets the key.
    @AuraEnabled
    public static SessionResult createRegistration(Registration__c registrationRec) {
        if (registrationRec == null) {
            throw new AuraHandledException('Registration record is null.');
        }
        if (registrationRec.Id != null) {
            throw new AuraHandledException(MSG_DENIED);
        }
        Id newId = (Id) MBP_RegistrationFormController.upsertRegistrationRecord(registrationRec);

        SessionResult out = new SessionResult();
        out.registrationId = newId;
        out.sessionId = issueKey(newId);
        return out;
    }

    @AuraEnabled
    public static OtpStartResult startResume(String value) {
        OtpStartResult out = new OtpStartResult();
        if (String.isBlank(value)) {
            out.status = 'NOT_FOUND';
            return out;
        }
        String needle = value.trim();
        List<Registration__c> rows = [
            SELECT Id, Status__c, Company_Email_Address__c
            FROM Registration__c
            WHERE Company_Email_Address__c = :needle OR Trade_License_Number__c = :needle
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            out.status = 'NOT_FOUND';
            return out;
        }
        Registration__c reg = rows[0];
        if (reg.Status__c != STATUS_DRAFT) {
            out.status = 'NOT_DRAFT';
            out.statusValue = reg.Status__c;
            return out;
        }
        // Nothing to send the code to, so it cannot be resumed from the public form.
        if (String.isBlank(reg.Company_Email_Address__c)) {
            out.status = 'NOT_FOUND';
            return out;
        }

        sendCode(reg.Id, reg.Company_Email_Address__c);

        out.registrationId = reg.Id;
        out.maskedTarget = maskEmail(reg.Company_Email_Address__c);
        out.status = 'SENT';
        return out;
    }

    // Taken out: nothing on the site calls this, and it sends a code off a record id alone,
    // which is the same shape as the reported OTP finding. Resending is done by calling
    // startResume again with the email the form already has.
    /*
    @AuraEnabled
    public static OtpStartResult resendResumeCode(Id registrationId) {
        OtpStartResult out = new OtpStartResult();
        if (registrationId == null) {
            out.status = 'NOT_FOUND';
            return out;
        }
        List<Registration__c> rows = [
            SELECT Id, Status__c, Company_Email_Address__c
            FROM Registration__c WHERE Id = :registrationId LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Status__c != STATUS_DRAFT || String.isBlank(rows[0].Company_Email_Address__c)) {
            out.status = 'NOT_FOUND';
            return out;
        }
        sendCode(rows[0].Id, rows[0].Company_Email_Address__c);
        out.registrationId = rows[0].Id;
        out.maskedTarget = maskEmail(rows[0].Company_Email_Address__c);
        out.status = 'SENT';
        return out;
    }
    */

    // Null for a wrong code so the form can show its own inline error.
    @AuraEnabled
    public static SessionResult verifyResumeOtp(Id registrationId, String code) {
        if (registrationId == null || String.isBlank(code)) {
            return null;
        }
        if (!verifyCode(registrationId, code)) {
            return null;
        }
        SessionResult out = new SessionResult();
        out.registrationId = registrationId;
        out.sessionId = issueKey(registrationId);
        out.registration = MBP_RegistrationFormController.getRegistrationById(registrationId);
        return out;
    }

    /* ---------------- Everything below needs the key ---------------- */

    @AuraEnabled
    public static Registration__c getRegistration(Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        return MBP_RegistrationFormController.getRegistrationById(registrationId);
    }

    @AuraEnabled
    public static List<MBP_RegistrationFormController.RegistrationAgentWrapper> getAgents(Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        return MBP_RegistrationFormController.getRegistrationAgents(String.valueOf(registrationId));
    }

    @AuraEnabled
    public static String saveRegistration(Registration__c registrationRec, String sessionId) {
        if (registrationRec == null || registrationRec.Id == null) {
            throw new AuraHandledException(MSG_DENIED);
        }
        authorize(registrationRec.Id, sessionId);
        return MBP_RegistrationFormController.upsertRegistrationRecord(registrationRec);
    }

    @AuraEnabled
    public static List<String> saveAgents(List<Registration_Agent__c> registrationAgentRecs, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        assertAgentsBelong(registrationAgentRecs, registrationId);
        return MBP_RegistrationFormController.upsertRegistrationAgentRecords(registrationAgentRecs);
    }

    @AuraEnabled
    public static List<Id> saveAgentsWithFiles(List<MBP_RegistrationFormController.RegistrationAgentWrapper> agentDataList, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        if (agentDataList != null) {
            for (MBP_RegistrationFormController.RegistrationAgentWrapper w : agentDataList) {
                if (String.isNotBlank(w.registrationId) && w.registrationId != String.valueOf(registrationId)) {
                    throw new AuraHandledException(MSG_DENIED);
                }
                w.registrationId = String.valueOf(registrationId);
                if (String.isNotBlank(w.sfId)) {
                    assertAgentIdBelongs(w.sfId, registrationId);
                }
            }
        }
        return MBP_RegistrationFormController.saveAgentsWithFiles(agentDataList);
    }

    @AuraEnabled
    public static void deleteAgent(String agentRecordId, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        assertAgentIdBelongs(agentRecordId, registrationId);
        MBP_RegistrationFormController.deleteRegistrationAgentRecord(agentRecordId);
    }

    @AuraEnabled
    public static Id uploadFile(String recordId, String fileName, String base64Data, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        // The steps only ever upload against the registration itself.
        if (String.valueOf(registrationId) != String.valueOf(recordId)) {
            throw new AuraHandledException(MSG_DENIED);
        }
        return MBP_RegistrationFormController.uploadFile(recordId, fileName, base64Data);
    }

    @AuraEnabled
    public static Map<String, Object> getExistingFile(String recordId, String fileNamePrefix, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        if (String.valueOf(registrationId) != String.valueOf(recordId)) {
            throw new AuraHandledException(MSG_DENIED);
        }
        return MBP_RegistrationFormController.getExistingFile(recordId, fileNamePrefix);
    }

    // The key is not enough on its own here: the file has to sit under this registration.
    @AuraEnabled
    public static void deleteFile(String contentDocumentId, Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        assertFileBelongs(contentDocumentId, registrationId);
        MBP_RegistrationFormController.deleteFile(contentDocumentId);
    }

    @AuraEnabled
    public static String getLatestServiceRequestNumber(Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        return MBP_RegistrationFormController.getLatestServiceRequestNumber(registrationId);
    }

    /* ---------------- Bank step OTP ---------------- */

    // Returns where the code went, never the code.
    @AuraEnabled
    public static String sendBankOtp(Id registrationId, String sessionId) {
        authorize(registrationId, sessionId);
        List<Registration_Agent__c> owners = [
            SELECT Id, Agent_Email__c
            FROM Registration_Agent__c
            WHERE Registration_Name__c = :registrationId
              AND Type__c = 'Owner'
              AND Agent_Email__c != NULL
              AND Primary_Owner__c = TRUE
            LIMIT 1
        ];
        if (owners.isEmpty()) {
            throw new AuraHandledException('No Primary Agency Admin found for this registration.');
        }
        String target = owners[0].Agent_Email__c;
        sendCode(registrationId, target);
        return target;
    }

    @AuraEnabled
    public static Boolean verifyBankOtp(Id registrationId, String code, String sessionId) {
        authorize(registrationId, sessionId);
        if (String.isBlank(code)) {
            return false;
        }
        return verifyCode(registrationId, code);
    }

    /* ---------------- Pass through, no record data ---------------- */

    @AuraEnabled(cacheable=false)
    public static String checkDuplicateValue(String value, String type) {
        return MBP_RegistrationFormController.checkDuplicateValue(value, type);
    }

    @AuraEnabled(cacheable=false)
    public static String validateDuplicateTradeLicenseNumber(String licenseNumber) {
        return MBP_RegistrationFormController.validateDuplicateTradeLicenseNumber(licenseNumber);
    }

    @AuraEnabled
    public static String checkDuplicateEmailOrMobile(String value, String type) {
        return MBP_RegistrationFormController.checkDuplicateEmailOrMobile(value, type);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLegalStructurePicklist() {
        return MBP_RegistrationFormController.getLegalStructurePicklist();
    }

    /* ---------------- Access checks ---------------- */

    @TestVisible
    private static void authorize(Id registrationId, String sessionId) {
        if (registrationId == null) {
            throw new AuraHandledException(MSG_DENIED);
        }
        List<Registration__c> rows = [
            SELECT Id, Session_Id__c, Broker_Agency__c
            FROM Registration__c
            WHERE Id = :registrationId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException(MSG_DENIED);
        }
        Registration__c reg = rows[0];

        // The browser holds the key.
        if (String.isNotBlank(sessionId)
            && String.isNotBlank(reg.Session_Id__c)
            && constantTimeEquals(reg.Session_Id__c, sessionId.trim())) {
            return;
        }

        // Or a logged in broker on the same agency, same rule Draftstagecontroller uses. A guest has no contact,
        // so this never passes for one.
        Id ownAccount = ownAccountId();
        if (ownAccount != null && reg.Broker_Agency__c == ownAccount) {
            return;
        }

        throw new AuraHandledException(MSG_DENIED);
    }

    @TestVisible
    private static Id ownAccountId() {
        if (UserInfo.getUserType() == 'Guest') {
            return null;
        }
        List<User> users = [
            SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (users.isEmpty() || users[0].Contact == null) {
            return null;
        }
        return users[0].Contact.AccountId;
    }

    // A new key replaces any earlier one. The guest user already updates this object through the form, so a plain
    // update is fine here.
    @TestVisible
    private static String issueKey(Id registrationId) {
        String key = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        update new Registration__c(Id = registrationId, Session_Id__c = key);
        return key;
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) {
            return false;
        }
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) {
            if (a.substring(i, i + 1) != b.substring(i, i + 1)) {
                diff++;
            }
        }
        return diff == 0;
    }

    private static void assertAgentsBelong(List<Registration_Agent__c> rows, Id registrationId) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> existingIds = new Set<Id>();
        for (Registration_Agent__c row : rows) {
            if (row.Registration_Name__c != null && row.Registration_Name__c != registrationId) {
                throw new AuraHandledException(MSG_DENIED);
            }
            row.Registration_Name__c = registrationId;
            if (row.Id != null) {
                existingIds.add(row.Id);
            }
        }
        assertAgentIdsBelong(existingIds, registrationId);
    }

    private static void assertAgentIdBelongs(String agentId, Id registrationId) {
        if (String.isBlank(agentId)) {
            throw new AuraHandledException(MSG_DENIED);
        }
        assertAgentIdsBelong(new Set<Id>{ (Id) agentId }, registrationId);
    }

    private static void assertAgentIdsBelong(Set<Id> agentIds, Id registrationId) {
        if (agentIds == null || agentIds.isEmpty()) {
            return;
        }
        Integer mine = [
            SELECT COUNT()
            FROM Registration_Agent__c
            WHERE Id IN :agentIds AND Registration_Name__c = :registrationId
        ];
        if (mine != agentIds.size()) {
            throw new AuraHandledException(MSG_DENIED);
        }
    }

    private static void assertFileBelongs(String contentDocumentId, Id registrationId) {
        if (String.isBlank(contentDocumentId)) {
            throw new AuraHandledException(MSG_DENIED);
        }
        Set<Id> allowed = new Set<Id>{ registrationId };
        for (Registration_Agent__c agent : [
            SELECT Id FROM Registration_Agent__c WHERE Registration_Name__c = :registrationId
        ]) {
            allowed.add(agent.Id);
        }
        for (Documents__c doc : [
            SELECT Id FROM Documents__c
            WHERE Registration__c = :registrationId OR Registration_Agent__c IN :allowed
        ]) {
            allowed.add(doc.Id);
        }
        Integer links = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId IN :allowed
        ];
        if (links == 0) {
            throw new AuraHandledException(MSG_DENIED);
        }
    }

    /* ---------------- OTP ---------------- */

    private static void sendCode(Id registrationId, String target) {
        String value = target == null ? '' : target.trim();
        if (String.isBlank(value)) {
            throw new AuraHandledException('No email address is on file for this registration.');
        }
        Datetime since = Datetime.now().addMinutes(-SEND_WINDOW_MINUTES);
        Integer sends = [
            SELECT COUNT()
            FROM Verification_Request__c
            WHERE Target__c = :value AND Context__c = :OTP_CONTEXT AND CreatedDate >= :since
        ];
        if (sends >= SENDS_PER_WINDOW) {
            throw new AuraHandledException('Too many codes were requested for this email. Please try again in a few minutes.');
        }

        VerificationService.VerificationStartRequest req = new VerificationService.VerificationStartRequest();
        req.channel = OTP_CHANNEL;
        req.target = value;
        req.context = OTP_CONTEXT;
        req.contextKey = String.valueOf(registrationId);
        VerificationService.startVerification(req);
    }

    // Looks up the request by registration, so the request id never has to go to the browser.
    private static Boolean verifyCode(Id registrationId, String code) {
        String key = String.valueOf(registrationId);
        List<Verification_Request__c> rows = [
            SELECT Id
            FROM Verification_Request__c
            WHERE Context__c = :OTP_CONTEXT
              AND Context_Key__c = :key
              AND Status__c = 'Pending'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return false;
        }
        try {
            VerificationService.VerificationResult result = VerificationService.verifyCode(rows[0].Id, code.trim());
            return result != null && result.verified == true;
        } catch (Exception e) {
            // Expired or already used. Treated as a wrong code.
            return false;
        }
    }

    private static String maskEmail(String email) {
        List<String> parts = (email == null ? '' : email).split('@');
        if (parts.size() != 2 || parts[0].length() == 0) {
            return '***';
        }
        Integer visible = Math.min(2, parts[0].length());
        return parts[0].substring(0, visible) + '***@' + parts[1];
    }
}