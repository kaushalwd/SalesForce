/**********************************************************************************************
 * Name           : PaymentLinkNotificationService
 * Description     : Sends the customer their Payment_Link__c URL over Email + SMS when the link is
 *                   created (Status = Sent), and an expiry notice when it moves to Expired. Recipient
 *                   and amount are resolved from the related Booking Fee Line -> Opportunity ->
 *                   PrimaryContact. Reuses the shared NotificationDispatcher (Email + SMS); no WhatsApp.
 * Usage           : Called from PaymentLinkTrigger (after insert / after update).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    06 Aug 2026    Initial version.
 **********************************************************************************************/
public without sharing class PaymentLinkNotificationService {

    private static final String HEADER_IMG =
        'https://github.com/Nibraz999/sendgridemo/blob/main/Modon_ADNOC_Koysk_EDM%20Header%20-%20Footer_SH_V01(High)-01.jpg?raw=true';
    private static final String SIGN_OFF =
        '<p style="margin:0 0 4px;">Best regards,</p><p style="margin:0;"><strong>Modon</strong></p>';
    private static final String FOOTER_HTML =
        '<table bgcolor="#000000" border="0" cellpadding="0" cellspacing="0" style="background-color:#000000; width:100%; margin:0; padding:0;" width="100%"><tr><td align="center">'
        + '<table border="0" cellpadding="0" cellspacing="0" style="max-width:600px; width:100%; padding:8px 16px;" width="100%"><tr>'
        + '<td class="footer-left" align="left" style="font-family:Arial, sans-serif; font-size:11px; color:#ffffff; line-height:16px; padding-bottom:8px; width:70%;" valign="top">'
        + '<p style="margin:0 0 4px;">FOLLOW US ON SOCIAL MEDIA</p>'
        + '<table align="left" border="0" cellpadding="0" cellspacing="0" style="margin-top:4px;"><tr>'
        + '<td style="padding-right:6px;"><a href="https://www.linkedin.com/company/modon" target="_blank"><img height="20" src="https://github.com/Nibraz999/sendgridemo/blob/main/linkedin.png?raw=true" style="display:block; border:0;" width="20"/></a></td>'
        + '<td style="padding-right:6px;"><a href="https://www.instagram.com/modonproperties" target="_blank"><img height="20" src="https://github.com/Nibraz999/sendgridemo/blob/main/insta.png?raw=true" style="display:block; border:0;" width="20"/></a></td>'
        + '<td style="padding-right:6px;"><a href="https://x.com/ModonProperties" target="_blank"><img height="20" src="https://github.com/Nibraz999/sendgridemo/blob/main/twitter.png?raw=true" style="display:block; border:0;" width="20"/></a></td>'
        + '<td style="padding-right:6px;"><a href="https://www.facebook.com/modonproperties" target="_blank"><img height="20" src="https://github.com/Nibraz999/sendgridemo/blob/main/fb_icon.png?raw=true" style="display:block; border:0;" width="20"/></a></td>'
        + '<td style="padding-right:6px;"><a href="https://www.youtube.com/@ModonRealEstate-n9p" target="_blank"><img height="20" src="https://github.com/Nibraz999/sendgridemo/blob/main/youtube.png?raw=true" style="display:block; border:0;" width="20"/></a></td>'
        + '</tr></table></td>'
        + '<td class="footer-right" align="right" style="padding-left:16px; width:30%;" valign="middle">'
        + '<img height="18" src="https://github.com/Nibraz999/sendgridemo/blob/main/MODON%20LOGO_White%201.png?raw=true" style="display:block; border:0; line-height:18px;" width="100"/>'
        + '</td></tr></table></td></tr></table>';

    public static void handle(List<Payment_Link__c> newRows, Map<Id, Payment_Link__c> oldMap) {
        Map<Id, String> eventByLink = new Map<Id, String>();
        Set<Id> bflIds = new Set<Id>();
        for (Payment_Link__c row : newRows) {
            String evt = resolveEvent(row, oldMap == null ? null : oldMap.get(row.Id));
            if (evt == null) {
                continue;
            }
            eventByLink.put(row.Id, evt);
            if (row.Booking_Fee_Line__c != null) {
                bflIds.add(row.Booking_Fee_Line__c);
            }
        }
        if (eventByLink.isEmpty()) {
            return;
        }

        Map<Id, Booking_Fee_Line__c> bflById = new Map<Id, Booking_Fee_Line__c>();
        if (!bflIds.isEmpty()) {
            bflById = new Map<Id, Booking_Fee_Line__c>([
                SELECT Id, Type__c, Total_Amount__c, CurrencyIsoCode,
                       Opportunity__r.PrimaryContact__r.Name,
                       Opportunity__r.PrimaryContact__r.Email,
                       Opportunity__r.PrimaryContact__r.MobilePhone
                FROM Booking_Fee_Line__c
                WHERE Id IN :bflIds
            ]);
        }

        List<NotificationDispatcher.Message> messages = new List<NotificationDispatcher.Message>();
        for (Payment_Link__c row : newRows) {
            String evt = eventByLink.get(row.Id);
            if (evt == null) {
                continue;
            }
            // Only Booking Fee Line sourced links are supported today (EOI / Invoice / Payment sources are future).
            Booking_Fee_Line__c bfl = row.Booking_Fee_Line__c == null ? null : bflById.get(row.Booking_Fee_Line__c);
            if (bfl == null) {
                continue;
            }
            NotificationDispatcher.Message m = buildMessage(row, evt, bfl);
            if (m != null) {
                messages.add(m);
            }
        }
        NotificationDispatcher.send(messages);
    }

    private static String resolveEvent(Payment_Link__c row, Payment_Link__c oldRow) {
        if (oldRow == null) {
            return row.Status__c == 'Sent' ? 'sent' : null;
        }
        if (row.Status__c == oldRow.Status__c) {
            return null;
        }
        return row.Status__c == 'Expired' ? 'expired' : null;
    }

    private static NotificationDispatcher.Message buildMessage(Payment_Link__c row, String evt, Booking_Fee_Line__c bfl) {
        Contact pc = (bfl.Opportunity__r == null) ? null : bfl.Opportunity__r.PrimaryContact__r;
        String rawName = (pc == null || String.isBlank(pc.Name)) ? 'Customer' : pc.Name;
        String name = esc(rawName);
        String amount = esc(amountPlain(bfl));
        String feeType = String.isBlank(bfl.Type__c) ? 'booking' : bfl.Type__c;
        String url = row.Payment_URL__c;
        String reference = esc(row.Name);
        String expiry = row.Expiry_Timestamp__c == null ? null : row.Expiry_Timestamp__c.format('dd/MM/yyyy HH:mm');

        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.email = (pc == null) ? null : pc.Email;
        m.phone = (pc == null) ? null : pc.MobilePhone;
        m.customerName = rawName;
        m.correlationId = String.valueOf(row.Id);
        m.relatedObject = 'Payment_Link__c';
        m.messageType = evt == 'sent' ? 'Payment Link Sent' : 'Payment Link Expired';

        String bodyHtml;
        if (evt == 'sent') {
            if (String.isBlank(url)) {
                return null;
            }
            m.emailSubject = 'Your Modon payment link - ' + row.Name;
            m.emailBody = 'Dear ' + rawName + ',\n\nPlease complete your ' + feeType + ' payment of '
                + amountPlain(bfl) + ' using the secure link below:\n' + url + '\n\n'
                + (expiry == null ? '' : 'This link expires on ' + expiry + '.\n\n')
                + 'If you have any questions, contact us on 800 MODON (800 66366) or customercare@modon.com.\n\nBest regards,\nModon';
            bodyHtml = p('Dear ' + name + ',')
                + p('Please complete your ' + esc(feeType) + ' payment of <strong>' + amount + '</strong> using the secure link below:')
                + p('<a href="' + url + '" style="color:#000000; text-decoration:underline;">' + url + '</a>')
                + (expiry == null ? '' : p('This link expires on <strong>' + esc(expiry) + '</strong>.'))
                + p('If you have any questions, contact us on 800 MODON (800 66366) or customercare@modon.com.')
                + SIGN_OFF;
        } else {
            m.emailSubject = 'Payment link expired - ' + row.Name;
            m.emailBody = 'Dear ' + rawName + ',\n\nYour Modon payment link for ' + amountPlain(bfl) + ' (' + feeType
                + ', ref ' + row.Name + ') has expired. Please contact us for a new link.\n\nBest regards,\nModon';
            bodyHtml = p('Dear ' + name + ',')
                + p('Your Modon payment link for <strong>' + amount + '</strong> (' + esc(feeType) + ', ref ' + reference
                    + ') has expired. Please contact us for a new link.')
                + SIGN_OFF;
        }

        m.emailHtmlBody = brandedHtml(bodyHtml);
        m.smsText = smsText(evt, rawName, amountPlain(bfl), feeType, row.Name, url, expiry);
        return m;
    }

    private static String smsText(String evt, String name, String amount, String feeType, String reference, String url, String expiry) {
        if (evt == 'sent') {
            return 'Dear ' + name + ', complete your Modon ' + feeType + ' payment of ' + amount + ' here: ' + url
                + (expiry == null ? '' : ' (expires ' + expiry + ')');
        }
        return 'Dear ' + name + ', your Modon payment link for ' + amount + ' (' + feeType + ', ref ' + reference
            + ') has expired. Please contact us for a new link.';
    }

    private static String amountPlain(Booking_Fee_Line__c bfl) {
        return (String.isBlank(bfl.CurrencyIsoCode) ? '' : bfl.CurrencyIsoCode + ' ')
            + (bfl.Total_Amount__c == null ? '' : bfl.Total_Amount__c.setScale(2).format());
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