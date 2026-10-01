/**********************************************************************************************
 * Name           : CheckoutNotificationService
 * Description     : Builds customer email/SMS notifications for Checkout_Payment__c lifecycle events.
 * Usage           : Called from CheckoutPaymentTrigger (after insert / after update).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 2.0        Prateek Bansal    15 Sep 2026    Wording comes from config, and a declined card now tells the customer and broker.
 * 1.9        Prateek Bansal    13 Sep 2026    Message 9 gains its WhatsApp leg, sent to the agent's mobile.
 * 1.8        Prateek Bansal    13 Sep 2026    Link and expiry wording from config, split by origin.
 * 1.7        Prateek Bansal    12 Sep 2026    replacedRowIds silences every event on a flagged row, not
 *                                             only the link-expired one. An administrative status change
 *                                             must never tell a customer their money moved again.
 * 1.6        Prateek Bansal    12 Sep 2026    Reads the new Authorization Expired status directly instead
 *                                             of inferring a lapsed hold from the previous value. The old
 *                                             inference stays as a fallback for in-flight rows.
 * 1.5        Prateek Bansal    11 Sep 2026    Header and footer brought onto the current Modon assets.
 *                                             Every image was hotlinked from a personal GitHub repo,
 *                                             and the banner was an ADNOC kiosk EDM asset. Now the
 *                                             Wadeem hero plus the Modon CDN logo and icons, on the
 *                                             navy footer the rest of Modon's mail uses. Wording,
 *                                             SMS and send behaviour untouched.
 * 1.4        Aurelix IT        10 Sep 2026    BP-044. The link SMS fits one segment (160 GSM characters):
 *                                             first name, the client's approved wording, the whole link on
 *                                             its own line. A wording ladder shortens the sentence before
 *                                             anything else and the link always goes out, never split.
 * 1.3        Prateek Bansal    10 Sep 2026    An expiry after an authorization is a lapsed hold, not
 *                                             an unused link, and gets its own wording: the money
 *                                             was never taken and the customer must be told so.
 * 1.2        Aurelix Dev       02 Sep 2026    MSC-229. resendLink: the console's Resend action
 *                                             re-sends the SAME stored link message (email + SMS)
 *                                             for still-payable rows only - Link Created or
 *                                             Authorized with a link URL. Nothing new is created
 *                                             and no expiry moves; an Expired row never sends.
 * 1.1        Aurelix Dev       02 Sep 2026    MSC-228. Link-created wording per the client's
 *                                             pay-first spec: the message asks the customer to
 *                                             complete the payment to confirm their Expression
 *                                             of Interest. No EOI number can appear - the EOI
 *                                             does not exist until the payment captures.
 * 1.3        Aurelix IT        10 Sep 2026    BP-043. Customer messages sent from the org-wide address
 *                                             noreply@modon.com instead of the creating user's address.
 * 1.0        Prateek Bansal    26 Jun 2026    Initial version.
 **********************************************************************************************/
public without sharing class CheckoutNotificationService {

    // Wadeem hero. NOT the Wadeem Gardens header the EOI templates use: this shell also wraps the
    // booking fee and instalment mails, which belong to whichever project the payment is for, and
    // Wadeem and Wadeem Gardens are separate projects. Making it follow the payment to its project
    // is the real fix; until then it stays on the broader asset.
    private static final String HEADER_IMG =
        'https://rsvp.modon.com/uploads/media/media_20260909105143_01d14dd708ae.jpg';
    private static final String LOGO_IMG =
        'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/3392d909-fefa-4cf0-9ead-0c840c5db421.png';
    private static final String SIGN_OFF =
        '<p style="margin:0 0 4px;">Best regards,</p><p style="margin:0;"><strong>Modon</strong></p>';
    // Social icons, all on the Modon CDN. Previously these and the logo were hotlinked from a personal
    // GitHub repo, which would have taken the branding off every payment email the day it went away.
    private static final String ICON_BASE = 'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/';

    private static final String FOOTER_HTML =
        '<table bgcolor="#2B2940" border="0" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#2B2940; width:100%; margin:0; padding:0;" width="100%"><tr><td align="center">'
        + '<table border="0" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px; width:100%; margin:0 auto;" width="100%"><tr><td style="padding:20px 16px;">'
        + '<table border="0" cellpadding="0" cellspacing="0" role="presentation" width="100%"><tr>'
        + '<td class="footer-left" align="left" style="width:70%;" valign="middle" width="70%">'
        + '<table border="0" cellpadding="0" cellspacing="0" role="presentation">'
        + '<tr><td style="font-family:Arial, sans-serif; font-size:11px; line-height:14px; color:#ffffff; padding-bottom:8px; text-transform:uppercase;">Follow us on social media</td></tr>'
        + '<tr><td><table align="left" border="0" cellpadding="0" cellspacing="0" role="presentation"><tr>'
        + '<td style="padding-right:8px;"><a href="https://www.linkedin.com/company/modon/" target="_blank"><img alt="LinkedIn" border="0" height="20" src="' + ICON_BASE + '68f4a192-4070-47d0-987e-5d195b6ed826.png" style="display:block;" width="20"/></a></td>'
        + '<td style="padding-right:8px;"><a href="https://www.instagram.com/modonproperties" target="_blank"><img alt="Instagram" border="0" height="20" src="' + ICON_BASE + '9aa75f22-01a3-492d-a1f1-7c7e3818854f.png" style="display:block;" width="20"/></a></td>'
        + '<td style="padding-right:8px;"><a href="https://x.com/ModonProperties" target="_blank"><img alt="X" border="0" height="20" src="' + ICON_BASE + 'f3f7cb4d-dcbf-47e1-9a3c-0b0d643e84dc.png" style="display:block;" width="20"/></a></td>'
        + '<td style="padding-right:8px;"><a href="https://www.facebook.com/modonproperties" target="_blank"><img alt="Facebook" border="0" height="20" src="' + ICON_BASE + 'caf8d960-1f00-40b8-88d0-cf473c5993e7.png" style="display:block;" width="20"/></a></td>'
        + '<td><a href="https://www.youtube.com/@modonproperties" target="_blank"><img alt="YouTube" border="0" height="20" src="' + ICON_BASE + '00da0fb2-43e6-4954-a6ca-59f0eb66865a.png" style="display:block;" width="20"/></a></td>'
        + '</tr></table></td></tr></table></td>'
        + '<td class="footer-right" align="right" style="width:30%;" valign="middle" width="30%">'
        + '<a href="https://www.modon.com/" target="_blank"><img alt="Modon" border="0" src="' + LOGO_IMG + '" style="display:block; max-width:100%; height:auto;" width="90"/></a>'
        + '</td></tr></table></td></tr></table></td></tr></table>';

    /**
     * MSC-229. Re-send the link message for still-payable links (console Resend action).
     * Same stored URL, same expiry - resending can never extend any clock. Returns how many
     * messages were actually queued (an Expired row or a blank URL queues nothing).
     */
    public static Integer resendLink(Set<Id> paymentIds) {
        if (paymentIds == null || paymentIds.isEmpty()) {
            return 0;
        }
        List<NotificationDispatcher.Message> messages = new List<NotificationDispatcher.Message>();
        for (Checkout_Payment__c row : [
            SELECT Id, Reference__c, Status__c, Customer_Name__c, Customer_Email__c, Customer_Phone__c,
                   Currency_Code__c, Amount__c, Payment_Link_Url__c, Expires_On__c, Error_Message__c
            FROM Checkout_Payment__c
            WHERE Id IN :paymentIds AND Status__c IN ('Link Created', 'Authorized')
        ]) {
            NotificationDispatcher.Message m = buildMessage(row, 'created');
            if (m != null) {
                messages.add(m);
            }
        }
        if (!messages.isEmpty()) {
            NotificationDispatcher.send(messages);
        }
        return messages.size();
    }

    /* BP-060 (11 Sep 2026, Aurelix IT): rows being closed because a replacement request has just
       been created for the same interest. Their link did expire, but the customer already holds a
       newer link, so "your payment link has expired, please contact us for a new link" would be
       wrong. Filled and emptied around that one update by MBP_EoiPaymentLinkController; empty in
       every other transaction, so nothing else changes behaviour. */
    /** Rows whose status is being changed administratively, not because anything happened to the
        customer's money: a request retired by a newer link, or a backfill. No message is sent for
        them, whatever the change resolves to. */
    public static Set<Id> replacedRowIds = new Set<Id>();

    @TestVisible private static final String ORIGIN_SITE = 'Site';
    @TestVisible private static final String ORIGIN_SALES = 'Sales';
    @TestVisible private static final String ORIGIN_BROKER = 'Broker';

    public static void handle(List<Checkout_Payment__c> newRows, Map<Id, Checkout_Payment__c> oldMap) {
        Map<Id, String> eventByRowId = new Map<Id, String>();
        for (Checkout_Payment__c row : newRows) {
            String evt = resolveEvent(row, oldMap == null ? null : oldMap.get(row.Id));
            if (evt == null || replacedRowIds.contains(row.Id)) {
                continue;
            }
            eventByRowId.put(row.Id, evt);
        }
        if (eventByRowId.isEmpty()) {
            return;
        }

        Map<Id, Checkout_Payment__c> originById = originContext(eventByRowId.keySet());

        List<NotificationDispatcher.Message> messages = new List<NotificationDispatcher.Message>();
        for (Checkout_Payment__c row : newRows) {
            String evt = eventByRowId.get(row.Id);
            if (evt == null) {
                continue;
            }
            Checkout_Payment__c ctx = originById.get(row.Id);
            NotificationDispatcher.Message m = buildMessage(row, evt, ctx);
            if (m != null) {
                messages.add(m);
            }
            NotificationDispatcher.Message broker = buildBrokerMessage(row, evt, ctx);
            if (broker != null) {
                messages.add(broker);
            }
        }
        NotificationDispatcher.send(messages);
    }

    /** Trigger.new has no parent fields, so re-read the creating user's contact and agency once. */
    private static Map<Id, Checkout_Payment__c> originContext(Set<Id> rowIds) {
        // Carries the payment's own fields as well as the creator's, because the SMS wording is rendered
        // against this record: Trigger.new has no parent fields, so a token like
        // {{CreatedBy.Contact.Account.Name}} would silently render empty against it.
        return new Map<Id, Checkout_Payment__c>([
            SELECT Id, Reference__c, Amount__c, Currency_Code__c, Customer_Name__c, Customer_Email__c,
                   Customer_Phone__c, Payment_Link_Url__c, Expires_On__c, Status__c,
                   Expression_of_Interest__c,
                   CreatedBy.UserType, CreatedBy.Contact.Name, CreatedBy.Contact.Email,
                   CreatedBy.Contact.MobilePhone, CreatedBy.Contact.Account.Name
            FROM Checkout_Payment__c
            WHERE Id IN :rowIds
        ]);
    }

    /** Guest = EOI site, partner user = broker agency, anything else = Modon sales. */
    @TestVisible
    private static String originOf(Checkout_Payment__c ctx) {
        String userType = ctx == null || ctx.CreatedBy == null ? null : ctx.CreatedBy.UserType;
        if (userType == 'Guest') {
            return ORIGIN_SITE;
        }
        if (userType == 'PowerPartner') {
            return ORIGIN_BROKER;
        }
        return ORIGIN_SALES;
    }

    @TestVisible
    private static String resolveEvent(Checkout_Payment__c row, Checkout_Payment__c oldRow) {
        if (oldRow == null) {
            // Portal top-ups redirect the customer in-session, so there is no link to send.
            if (row.Portal_Initiated__c == true) {
                return null;
            }
            return row.Status__c == 'Link Created' ? 'created' : null;
        }
        if (row.Status__c == oldRow.Status__c) {
            return null;
        }
        // An EOI-backed ending is the EOI rail's to announce, or the customer hears it twice.
        // Payments with no EOI (booking fees, instalments) keep their own wording.
        Boolean backsAnEoi = row.Expression_of_Interest__c != null;
        switch on row.Status__c {
            when 'Captured' { return backsAnEoi ? null : 'captured'; }
            when 'Refunded' { return backsAnEoi ? null : 'refunded'; }
            when 'Partially Refunded' { return backsAnEoi ? null : 'refunded'; }
            when 'Voided' { return backsAnEoi ? null : 'voided'; }
            when 'Declined' { return backsAnEoi ? null : 'declined'; }
            // A hold that lapsed: the customer paid, the money was held and then released. Telling
            // them their link expired would be wrong.
            when 'Authorization Expired' { return backsAnEoi ? null : 'hold_expired'; }
            // Kept for rows that were already in flight when the new status shipped, and for any
            // writer still stamping plain Expired on an authorized row.
            when 'Expired' {
                if (oldRow.Status__c == 'Authorized') {
                    return backsAnEoi ? null : 'hold_expired';
                }
                return 'expired';
            }
            when else { return null; }
        }
    }

    // Customer messages must never show the user who made the link (a broker) as the sender.
    // No org-wide address is set on purpose: without a DKIM key for modon.com in the org, mail from
    // noreply@modon.com fails DMARC and Google drops it (proven 9 Sep 2026). With no org-wide address
    // Salesforce sends from its own signed domain and shows this display name instead.
    @TestVisible private static final String CUSTOMER_SENDER_NAME = 'Modon';
    // BP-043 (10 Sep 2026): every customer message is sent from Modon's verified org-wide address. Without it,
    // Salesforce stamps the From header with the user who created the payment row - a broker's own login
    // address on the portal - and receivers that check that domain's SPF / DMARC quarantine the mail (proven
    // with the client's test users on 10 Sep: SMS delivered, email never seen). modon.com's SPF includes
    // Salesforce and DKIM is in place, so this address is the one the customer can trust.
    @TestVisible private static final String CUSTOMER_SENDER_ADDRESS = 'noreply@modon.com';

    /** Wording the team owns: subject and body from the named email template, SMS from the config row. */
    private static NotificationDispatcher.Message buildConfiguredMessage(
        Checkout_Payment__c row, String messageType, Checkout_Payment__c ctx
    ) {
        MessagingConfigService.OutboundConfig emailCfg = MessagingConfigService.getOutboundConfig(messageType, 'Email');
        MessagingConfigService.OutboundConfig smsCfg = MessagingConfigService.getOutboundConfig(messageType, 'SMS');

        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.email = row.Customer_Email__c;
        m.phone = row.Customer_Phone__c;
        m.correlationId = String.valueOf(row.Id);
        m.customerName = String.isBlank(row.Customer_Name__c) ? 'Customer' : row.Customer_Name__c;
        m.relatedObject = 'Checkout_Payment__c';
        m.messageType = messageType;
        m.senderDisplayName = CUSTOMER_SENDER_NAME;
        m.fromEmail = CUSTOMER_SENDER_ADDRESS;

        if (emailCfg != null && emailCfg.isActive == true && String.isNotBlank(emailCfg.emailTemplateDeveloperName)) {
            // Rendered here rather than at send time so the outbound log records the words that went out.
            Messaging.SingleEmailMessage rendered =
                EmailOutboundClient.renderStored(emailCfg.emailTemplateDeveloperName, row.Id);
            if (rendered != null) {
                m.emailSubject = rendered.getSubject();
                m.emailBody = rendered.getPlainTextBody();
                m.emailHtmlBody = rendered.getHtmlBody();
            }
            if (String.isNotBlank(emailCfg.fromEmail)) {
                m.fromEmail = emailCfg.fromEmail;
            }
        }

        if (smsCfg != null && smsCfg.isActive == true && String.isNotBlank(smsCfg.smsBody)) {
            // 'due' is pre-composed so a row with no expiry loses the whole clause rather than
            // rendering a dangling "by" with nothing after it.
            String shortExpiry = SmsTextBuilder.shortExpiry(row.Expires_On__c);
            Map<String, Object> runtime = new Map<String, Object>{
                'first_name'    => SmsTextBuilder.firstName(row.Customer_Name__c),
                'name'          => m.customerName,
                'due'           => String.isBlank(shortExpiry) ? '' : ' by ' + shortExpiry,
                'eoi_site_url'  => System.Label.EOI_Site_Url,
                'phone_number'  => row.Customer_Phone__c,
                'reason'        => String.isBlank(row.Error_Message__c) ? '' : ' (' + row.Error_Message__c + ')'
            };
            // Render against ctx, which carries the parent fields; row does not.
            Checkout_Payment__c source = ctx == null ? row : ctx;
            String primary = OutboundPayloadRenderer.render(smsCfg.smsBody, source, smsCfg, runtime, false);
            String fallback = OutboundPayloadRenderer.render(smsCfg.smsBodyFallback, source, smsCfg, runtime, false);
            m.smsText = SmsTextBuilder.fit(SmsTextBuilder.toGsm(primary), SmsTextBuilder.toGsm(fallback));
        }
        return m;
    }

    /** Message 9. The agency that raised a lapsed link is told, since they raise the next one. */
    private static NotificationDispatcher.Message buildBrokerMessage(
        Checkout_Payment__c row, String evt, Checkout_Payment__c ctx
    ) {
        if ((evt != 'expired' && evt != 'declined') || originOf(ctx) != ORIGIN_BROKER
            || ctx.CreatedBy.Contact == null) {
            return null;
        }
        String messageType = evt == 'declined' ? 'Broker Payment Declined' : 'Broker Payment Not Completed';
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();

        String brokerEmail = ctx.CreatedBy.Contact.Email;
        MessagingConfigService.OutboundConfig emailCfg = MessagingConfigService.getOutboundConfig(messageType, 'Email');
        if (String.isNotBlank(brokerEmail) && emailCfg != null && emailCfg.isActive == true
            && String.isNotBlank(emailCfg.emailTemplateDeveloperName)) {
            Messaging.SingleEmailMessage rendered = EmailOutboundClient.renderStored(emailCfg.emailTemplateDeveloperName, row.Id);
            if (rendered != null) {
                m.email = brokerEmail;
                m.senderDisplayName = CUSTOMER_SENDER_NAME;
                m.fromEmail = String.isBlank(emailCfg.fromEmail) ? CUSTOMER_SENDER_ADDRESS : emailCfg.fromEmail;
                m.emailSubject = rendered.getSubject();
                m.emailBody = rendered.getPlainTextBody();
                m.emailHtmlBody = rendered.getHtmlBody();
            }
        }

        // Rendered against ctx, not row: the agent's contact fields only exist on the re-read record.
        String brokerPhone = ctx.CreatedBy.Contact.MobilePhone;
        MessagingConfigService.OutboundConfig waCfg = MessagingConfigService.getOutboundConfig(messageType, 'WhatsApp');
        if (String.isNotBlank(brokerPhone) && waCfg != null && waCfg.isActive == true
            && String.isNotBlank(waCfg.payloadTemplate)) {
            m.phone = brokerPhone;
            m.whatsAppPayload = OutboundPayloadRenderer.render(
                waCfg.payloadTemplate, ctx, waCfg,
                new Map<String, Object>{ 'phone_number' => brokerPhone, 'name' => ctx.CreatedBy.Contact.Name }
            );
            m.whatsAppTemplate = waCfg.templateName;
        }

        if (String.isBlank(m.email) && String.isBlank(m.whatsAppPayload)) {
            return null;
        }
        m.correlationId = String.valueOf(row.Id);
        m.customerName = ctx.CreatedBy.Contact.Name;
        m.relatedObject = 'Checkout_Payment__c';
        m.messageType = messageType;
        return m;
    }

    @TestVisible
    private static NotificationDispatcher.Message buildMessage(Checkout_Payment__c row, String evt) {
        return buildMessage(row, evt, null);
    }

    @TestVisible
    private static NotificationDispatcher.Message buildMessage(
        Checkout_Payment__c row, String evt, Checkout_Payment__c ctx
    ) {
        // Messages 2 and 3 are configured. A link with no URL still sends nothing.
        if (evt == 'created') {
            if (String.isBlank(row.Payment_Link_Url__c)) {
                return null;
            }
            return buildConfiguredMessage(row, 'Checkout Link Created', ctx);
        }
        if (evt == 'expired') {
            return buildConfiguredMessage(row, 'Checkout Link Expired - ' + originOf(ctx), ctx);
        }
        return buildConfiguredMessage(row, messageTypeFor(evt), ctx);
    }

    // BP-044 (10 Sep 2026): one SMS segment carries 160 GSM characters. Longer texts are split into 153-character
    // parts and on the client's phone the split fell inside the payment link (CP-00227). The link SMS is now built
    // from a ladder of wordings: the first rung that fits SMS_MAX_CHARS is sent, and the last rung is sent even if
    // nothing fits, so the whole link always goes out. Text outside the GSM 03.38 alphabet would make the carrier
    // switch to UCS-2 (70 characters per segment), so every variable part is mapped onto that alphabet first; the
    // link itself is never touched.
    @TestVisible private static final Integer SMS_MAX_CHARS = 160;
    private static final String SMS_FALLBACK_NAME = 'Customer';
    private static final List<String> SMS_MONTHS = new List<String>{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' };
    private static final Set<String> SMS_SALUTATIONS = new Set<String>{
        'mr', 'mrs', 'ms', 'miss', 'mx', 'dr', 'prof', 'sheikh', 'sheikha' };
    // GSM 03.38 basic alphabet (one septet each): the ASCII part as a literal, the rest by code point.
    private static final String GSM_BASIC =
        '@$\n\r_ !"#%&\'()*+,-./0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        + String.fromCharArray(new List<Integer>{ 163, 165, 232, 233, 249, 236, 242, 199, 216, 248, 197, 229, 916, 934,
            915, 923, 937, 928, 936, 931, 920, 926, 198, 230, 223, 201, 164, 161, 196, 214, 209, 220, 167, 191, 228, 246,
            241, 252, 224 });
    // GSM 03.38 extension characters (two septets each).
    private static final String GSM_EXTENSION = '^{}\\[~]|' + String.fromCharArray(new List<Integer>{ 8364 });
    // Typographic characters with a GSM equivalent are mapped, not dropped.
    private static final Map<String, String> GSM_SUBSTITUTES = gsmSubstitutes();

    private static Map<String, String> gsmSubstitutes() {
        Map<String, String> subs = new Map<String, String>();
        for (Integer quote : new List<Integer>{ 8216, 8217, 8218, 180, 96 }) {      // ' variants, acute accent, backtick
            subs.put(String.fromCharArray(new List<Integer>{ quote }), '\'');
        }
        for (Integer quote : new List<Integer>{ 8220, 8221, 8222 }) {               // " variants
            subs.put(String.fromCharArray(new List<Integer>{ quote }), '"');
        }
        for (Integer dash : new List<Integer>{ 8211, 8212, 8722 }) {                // en dash, em dash, minus
            subs.put(String.fromCharArray(new List<Integer>{ dash }), '-');
        }
        for (Integer space : new List<Integer>{ 160, 8201, 8239 }) {                // no-break, thin, narrow no-break space
            subs.put(String.fromCharArray(new List<Integer>{ space }), ' ');
        }
        subs.put(String.fromCharArray(new List<Integer>{ 8230 }), '...');           // ellipsis
        return subs;
    }

    // The client's approved wording (10 Sep 2026), then shorter rungs: the purpose phrase goes first, the name second,
    // the expiry last. The floor still carries "Dear Customer", the amount and the whole link.
    @TestVisible
    private static String linkSms(String firstName, String amount, String url, String expiry) {
        String due = expiry == null ? '' : ' by ' + expiry;
        List<String> greetings = new List<String>{ firstName };
        if (firstName != SMS_FALLBACK_NAME) {
            greetings.add(SMS_FALLBACK_NAME);
        }
        List<String> rungs = new List<String>();
        for (String who : greetings) {
            rungs.add('Dear ' + who + ', To complete your Expression of Interest, please pay ' + amount + due + ':\n' + url);
            rungs.add('Dear ' + who + ', please pay ' + amount + due + ':\n' + url);
        }
        if (expiry != null) {
            rungs.add('Dear ' + SMS_FALLBACK_NAME + ', please pay ' + amount + ':\n' + url);
        }
        return fitSms(rungs);
    }

    // First rung that fits one segment; the last rung is sent regardless so the link is never dropped.
    @TestVisible
    private static String fitSms(List<String> rungs) {
        String last = null;
        for (String rung : rungs) {
            if (rung == null) {
                continue;
            }
            last = rung;
            if (gsmLength(rung) <= SMS_MAX_CHARS) {
                return rung;
            }
        }
        return last;
    }

    // First name for the SMS greeting: the first word of the stored customer name (a salutation is skipped), kept
    // only when every character has a GSM equivalent so a name is never mangled; otherwise "Customer".
    @TestVisible
    private static String smsFirstName(String customerName) {
        if (String.isBlank(customerName)) {
            return SMS_FALLBACK_NAME;
        }
        for (String word : substituteGsm(customerName).trim().split('\\s+')) {
            if (String.isBlank(word) || SMS_SALUTATIONS.contains(word.replaceAll('\\.', '').toLowerCase())) {
                continue;
            }
            return isGsm(word) ? word : SMS_FALLBACK_NAME;
        }
        return SMS_FALLBACK_NAME;
    }

    // Expiry for the SMS, e.g. 11 Sep 14:51, in the same timezone the email uses, with English month names whatever
    // the running user's locale. Never throws: falls back to the email's numeric format.
    @TestVisible
    private static String smsExpiry(Datetime expiresOn) {
        if (expiresOn == null) {
            return null;
        }
        try {
            return expiresOn.format('d') + ' ' + SMS_MONTHS[Integer.valueOf(expiresOn.format('M')) - 1] + ' ' + expiresOn.format('HH:mm');
        } catch (Exception e) {
            return expiresOn.format('dd/MM/yyyy HH:mm');
        }
    }

    // Maps typographic characters to their GSM equivalent and drops what has none.
    @TestVisible
    private static String toGsm(String text) {
        if (text == null) {
            return '';
        }
        List<String> kept = new List<String>();
        String mapped = substituteGsm(text);
        for (Integer i = 0; i < mapped.length(); i++) {
            String ch = mapped.substring(i, i + 1);
            if (GSM_BASIC.contains(ch) || GSM_EXTENSION.contains(ch)) {
                kept.add(ch);
            }
        }
        return String.join(kept, '');
    }

    private static String substituteGsm(String text) {
        String mapped = text;
        for (String original : GSM_SUBSTITUTES.keySet()) {
            mapped = mapped.replace(original, GSM_SUBSTITUTES.get(original));
        }
        return mapped;
    }

    private static Boolean isGsm(String text) {
        for (Integer i = 0; i < text.length(); i++) {
            String ch = text.substring(i, i + 1);
            if (!GSM_BASIC.contains(ch) && !GSM_EXTENSION.contains(ch)) {
                return false;
            }
        }
        return true;
    }

    // Septets an SMS needs: an extension character costs two, everything else one.
    @TestVisible
    private static Integer gsmLength(String text) {
        if (text == null) {
            return 0;
        }
        Integer septets = 0;
        for (Integer i = 0; i < text.length(); i++) {
            septets += GSM_EXTENSION.contains(text.substring(i, i + 1)) ? 2 : 1;
        }
        return septets;
    }

    private static String messageTypeFor(String evt) {
        if (evt == 'created') { return 'Checkout Link Created'; }
        if (evt == 'captured') { return 'Checkout Payment Captured'; }
        if (evt == 'refunded') { return 'Checkout Payment Refunded'; }
        if (evt == 'voided') { return 'Checkout Payment Voided'; }
        if (evt == 'hold_expired') { return 'Checkout Hold Expired'; }
        if (evt == 'declined') { return 'Checkout Payment Declined'; }
        return 'Checkout Link Expired';
    }

    private static String amountPlain(Checkout_Payment__c row) {
        return (String.isBlank(row.Currency_Code__c) ? '' : row.Currency_Code__c + ' ')
            + (row.Amount__c == null ? '' : row.Amount__c.setScale(2).format());
    }

    private static String brandedHtml(String innerHtml) {
        return '<html lang="en"><head><meta charset="UTF-8"/>'
            + '<style type="text/css">'
            + 'body, table, td, a { -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; }'
            + 'table, td { mso-table-lspace:0pt; mso-table-rspace:0pt; }'
            + 'img { -ms-interpolation-mode:bicubic; }'
            + 'body { margin:0; padding:0; width:100% !important; height:100% !important; }'
            + '@media only screen and (max-width:600px) { .container { width:100% !important; } .footer-left td img { width:16px !important; height:16px !important; } .footer-left td { font-size:10px !important; line-height:14px !important; } .footer-right img { width:80px !important; height:14px !important; } }'
            + '</style></head>'
            + '<body style="margin:0; padding:0; background:#f4f4f4;">'
            + '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0; padding:0; border-collapse:collapse; background:#f4f4f4;"><tr><td align="center">'
            + '<table class="container" role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="width:100%; max-width:600px; border-collapse:collapse; background:#ffffff;">'
            + '<tr><td style="padding:0; margin:0; line-height:0; font-size:0;"><img src="' + HEADER_IMG + '" alt="Modon" width="600" style="display:block; width:100%; max-width:600px; height:auto; border:0;" /></td></tr>'
            + '<tr><td style="padding:28px 32px;"><div style="font-family:Arial, sans-serif; font-size:16px; line-height:1.5; color:#000000;">' + innerHtml + '</div></td></tr>'
            + '<tr><td style="padding:0; margin:0; line-height:0; font-size:0;">' + FOOTER_HTML + '</td></tr>'
            + '</table></td></tr></table></body></html>';
    }

    private static String p(String content) {
        return '<p style="margin:0 0 16px;">' + content + '</p>';
    }

    private static String esc(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}