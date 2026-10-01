/**********************************************************************************************
 * Name            : CustomerKYCSmsNotifier
 * Description     : Sends the Signzy KYC verification link to the customer over SMS, alongside the
 *                   email that "Send KYC Form" already triggers. The email itself is still sent by
 *                   the record-triggered flows (Send KYC Email to Customer / to Organization
 *                   Account) off Send_KYC_Verification_Email__c - this class does not touch that
 *                   path, it only adds the SMS leg.
 *                   Delivery reuses the shared NotificationDispatcher framework, so every SMS is
 *                   logged to Outbound_Message_Log__c (Queued -> Sent/Failed) and goes out through
 *                   CommunicationApiSmsClient on the same OIC 'CommunicationAPI' credential as the
 *                   rest of the org.
 * Usage           : CustomerKYCSmsNotifier.sendForAccount(accountId);
 *                   CustomerKYCSmsNotifier.sendForContacts(contactIds);
 *                   Called from CustomerKYCHandler.sendKYCForm() after the link has been saved.
 * Created By      : Rushi Patel
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date              Comment
 * 1.0        Rushi Patel       22 September 2026  Initial version - KYC link SMS.
 **********************************************************************************************/
public without sharing class CustomerKYCSmsNotifier {

    private static final String RELATED_OBJECT_ACCOUNT = 'Account';
    private static final String RELATED_OBJECT_CONTACT = 'Contact';
    private static final String MESSAGE_TYPE = 'KYC Link Sent';
    private static final String FALLBACK_NAME = 'Customer';
    private static final String NAME_TOKEN = '{!Name}';
    private static final String LINK_TOKEN = '{!KYCLink}';
    // One GSM SMS segment carries 160 characters; a concatenated message is split every 153. A split
    // can land inside the link (CP-00227 on the payment link SMS). The approved KYC copy is ~277
    // characters, so it always goes out as 2 segments and the 153 boundary falls inside the link -
    // raised with the business 23 September 2026, wording is theirs to call. Dropping the name is
    // kept as a guard for the day the copy is shortened; it does not help at the current length, so
    // the customer's name is retained rather than needlessly replaced with 'Customer'.
    @TestVisible private static final Integer SMS_MAX_CHARS = 160;

    /**
     * description : Person Account path. Reads the link back from the record so it works both when a
     *               fresh journey was created and when the existing active link is being re-sent.
     */
    public static void sendForAccount(Id accountId) {
        if (accountId == null) {
            return;
        }
        sendForAccounts(new Set<Id>{ accountId });
    }

    public static void sendForAccounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        List<NotificationDispatcher.Message> messages = new List<NotificationDispatcher.Message>();
        for (Account acc : [
            SELECT Id, FirstName, Name, PersonMobilePhone, KYCSiteLink__pc
            FROM Account
            WHERE Id IN :accountIds
        ]) {
            NotificationDispatcher.Message m = buildMessage(
                acc.Id, acc.PersonMobilePhone, acc.FirstName, acc.Name, acc.KYCSiteLink__pc, RELATED_OBJECT_ACCOUNT);
            if (m != null) {
                messages.add(m);
            }
        }
        dispatch(messages);
    }

    /**
     * description : Organization Account path - one SMS per Power of Attorney contact, each with its
     *               own KYC link.
     */
    public static void sendForContacts(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }
        List<NotificationDispatcher.Message> messages = new List<NotificationDispatcher.Message>();
        for (Contact con : [
            SELECT Id, FirstName, Name, MobilePhone, KYCSiteLink__c
            FROM Contact
            WHERE Id IN :contactIds
        ]) {
            NotificationDispatcher.Message m = buildMessage(
                con.Id, con.MobilePhone, con.FirstName, con.Name, con.KYCSiteLink__c, RELATED_OBJECT_CONTACT);
            if (m != null) {
                messages.add(m);
            }
        }
        dispatch(messages);
    }

    /**
     * description : The SMS is best-effort. A gateway or logging problem must never turn a KYC link
     *               that was successfully created and emailed into an error toast on the button.
     */
    private static void dispatch(List<NotificationDispatcher.Message> messages) {
        if (messages.isEmpty()) {
            return;
        }
        try {
            NotificationDispatcher.send(messages);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[CustomerKYCSmsNotifier] SMS dispatch failed: ' + ex.getMessage());
            CustomerKYCErrorLogHelper.logErrorHandler(
                null, null, 'Signzy Process', 'CustomerKYCSmsNotifier', 'dispatch', null, ex.getMessage());
        }
    }

    private static NotificationDispatcher.Message buildMessage(
        Id recordId, String phone, String firstName, String fullName, String kycLink, String relatedObject) {
        // No link means the journey callout failed upstream; nothing useful to text.
        if (String.isBlank(phone) || String.isBlank(kycLink)) {
            return null;
        }
        String name = String.isNotBlank(firstName) ? firstName
                    : (String.isNotBlank(fullName) ? fullName : FALLBACK_NAME);

        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.phone = phone;
        m.customerName = name;
        m.smsText = buildSmsText(name, kycLink);
        m.correlationId = String.valueOf(recordId);
        m.relatedObject = relatedObject;
        m.messageType = MESSAGE_TYPE;
        // Email is deliberately left blank - the flow off Send_KYC_Verification_Email__c still owns it.
        return m;
    }

    @TestVisible
    private static String buildSmsText(String name, String kycLink) {
        String template = System.Label.Signzy_KYC_Link_SMS_Message;
        String text = template.replace(NAME_TOKEN, name).replace(LINK_TOKEN, kycLink);
        if (text.length() <= SMS_MAX_CHARS) {
            return text;
        }
        // Drop the name rather than let the carrier split the message inside the link.
        String withoutName = template.replace(NAME_TOKEN, FALLBACK_NAME).replace(LINK_TOKEN, kycLink);
        return withoutName.length() <= SMS_MAX_CHARS ? withoutName : text;
    }
}