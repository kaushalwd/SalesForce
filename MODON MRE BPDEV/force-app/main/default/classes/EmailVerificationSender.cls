/**********************************************************************************************************************
* Name               : EmailVerificationSender
* Description        : Sends verification OTP codes through Salesforce email
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    11 May 2026     Initial email sender implementation
* 1.1           Prateek Bansal                    14 May 2026     Send OTP email using Modon HTML header and footer
* 1.2           Prateek Bansal                    14 May 2026     Support configurable OTP email template markup
* 1.3           Prateek Bansal                    14 May 2026     Use configured org-wide sender email when available
* 1.4           Prateek Bansal                    11 Sep 2026     Same header and footer fix as the payment emails, for
*                                                                 the fallback markup used when no template is configured.
*                                                                 Wadeem hero instead of the ADNOC kiosk banner, Modon CDN
*                                                                 logo and icons instead of a personal GitHub repo, navy
*                                                                 footer. The live path is Generic_OTP_Verification, which
*                                                                 carries the same change.
**********************************************************************************************************************/
public class EmailVerificationSender implements VerificationSender {
    @TestVisible private static Boolean forceFailureForTest = false;

    // Same assets as the payment emails. The header is the Wadeem hero, project-specific on purpose;
    // the logo and icons sit on the Modon CDN, where they used to be hotlinked from a personal GitHub
    // repo that would have taken the branding off every OTP mail the day it went away.
    private static final String HEADER_IMG =
        'https://rsvp.modon.com/uploads/media/media_20260909105143_01d14dd708ae.jpg';
    private static final String LOGO_IMG =
        'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/3392d909-fefa-4cf0-9ead-0c840c5db421.png';
    private static final String ICON_BASE = 'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/';

    public void send(VerificationMessage message) {
        if (message == null || String.isBlank(message.target)) {
            throw new VerificationService.VerificationException('Email address is required to send a verification code.');
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ message.target });
        email.setSubject(String.isBlank(message.subject) ? 'Your verification code' : message.subject);
        email.setHtmlBody(buildHtmlBody(message));
        email.setPlainTextBody(message.body);
        setOrgWideEmailAddress(email, message.fromEmail);
        email.setSaveAsActivity(false);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
        if (forceFailureForTest || results == null || results.isEmpty() || !results[0].isSuccess()) {
            String errorMessage = 'Unable to send verification email.';
            if (!forceFailureForTest && results != null && !results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
                errorMessage = results[0].getErrors()[0].getMessage();
            }
            throw new VerificationService.VerificationException(errorMessage);
        }
    }

    private static String buildHtmlBody(VerificationMessage message) {
        String configuredTemplate = getConfiguredTemplateBody(message == null ? null : message.templateName);
        if (String.isNotBlank(configuredTemplate)) {
            return applyTemplateTokens(configuredTemplate, message);
        }

        String code = message == null ? null : escapeHtml(message.code);
        String body = String.isBlank(code)
            ? escapeHtml(message == null ? null : message.body)
            : 'Your verification code is <strong>' + code + '</strong>. This code will expire in 5 minutes.';

        return '<html lang="en"><head><meta charset="UTF-8"></meta><style type="text/css">'
            + 'body,table,td,a{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}'
            + 'table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}img{-ms-interpolation-mode:bicubic;}'
            + 'body{margin:0;padding:0;width:100% !important;height:100% !important;}'
            + '@media only screen and (max-width:600px){.container{width:100% !important;}.footer-left td img{width:16px !important;height:16px !important;}.footer-left td{font-size:10px !important;line-height:14px !important;}.footer-right img{width:80px !important;height:14px !important;}}'
            + '</style></head><body style="margin:0; padding:0; background:#f4f4f4;">'
            + '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0; padding:0; border-collapse:collapse; background:#f4f4f4;"><tr><td align="center">'
            + '<table class="container" role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="width:100%; max-width:600px; border-collapse:collapse; background:#ffffff;">'
            + '<tr><td style="padding:0; margin:0; line-height:0; font-size:0;"><img src="' + HEADER_IMG + '" alt="Modon" width="600" style="display:block; width:100%; max-width:600px; height:auto; border:0;" /></td></tr>'
            + '<tr><td style="padding:28px 32px;"><div style="font-family:Arial, sans-serif; font-size:16px; line-height:1.5; color:#000000;">'
            + '<p style="margin:0 0 16px;">Dear Customer,</p>'
            + '<p style="margin:0 0 16px;">' + body + '</p>'
            + '<p style="margin:0 0 16px;">If you did not request this code, please ignore this email.</p>'
            + '<p style="margin:0 0 4px;">Best regards,</p><p style="margin:0;"><strong>Modon</strong></p>'
            + '</div></td></tr>'
            + '<tr><td style="padding:0; margin:0; line-height:0; font-size:0;">' + getFooterHtml() + '</td></tr>'
            + '</table></td></tr></table></body></html>';
    }

    private static String getConfiguredTemplateBody(String templateDeveloperName) {
        if (String.isBlank(templateDeveloperName)) return null;

        List<EmailTemplate> templates = [
            SELECT Markup, HtmlValue, Body
            FROM EmailTemplate
            WHERE DeveloperName = :templateDeveloperName
            LIMIT 1
        ];
        if (templates.isEmpty()) return null;

        EmailTemplate template = templates[0];
        if (String.isNotBlank(template.Markup)) return extractVisualforceHtmlBody(template.Markup);
        if (String.isNotBlank(template.HtmlValue)) return template.HtmlValue;
        if (String.isNotBlank(template.Body)) return template.Body;
        return null;
    }

    private static String extractVisualforceHtmlBody(String markup) {
        if (String.isBlank(markup)) return null;
        Pattern bodyPattern = Pattern.compile('(?is)<messaging:htmlEmailBody[^>]*>(.*)</messaging:htmlEmailBody>');
        Matcher matcher = bodyPattern.matcher(markup);
        if (matcher.find()) return matcher.group(1);
        return markup;
    }

    private static String applyTemplateTokens(String templateBody, VerificationMessage message) {
        String body = templateBody;
        String code = message == null ? '' : escapeHtml(message.code);
        String maskedTarget = message == null ? '' : escapeHtml(message.maskedTarget);
        String plainBody = message == null ? '' : escapeHtml(message.body);
        String expiryMinutes = getExpiryMinutesFromBody(message == null ? null : message.body);

        body = body.replace('{{OTP_CODE}}', code);
        body = body.replace('{{MASKED_TARGET}}', maskedTarget);
        body = body.replace('{{BODY}}', plainBody);
        body = body.replace('{{EXPIRY_MINUTES}}', expiryMinutes);
        return body;
    }

    private static String getExpiryMinutesFromBody(String body) {
        if (String.isBlank(body)) return '5';
        Pattern expiryPattern = Pattern.compile('(?i)expire in\\s+(\\d+)\\s+minutes');
        Matcher matcher = expiryPattern.matcher(body);
        return matcher.find() ? matcher.group(1) : '5';
    }

    private static String getFooterHtml() {
        return '<table bgcolor="#2B2940" border="0" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#2B2940; width:100%; margin:0; padding:0;" width="100%"><tr><td align="center">'
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
    }

    private static String escapeHtml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeHtml4();
    }

    private static void setOrgWideEmailAddress(Messaging.SingleEmailMessage email, String fromEmail) {
        Id orgWideEmailAddressId = EmailSenderConfigService.getOrgWideEmailAddressId(fromEmail);
        if (orgWideEmailAddressId != null) {
            email.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
    }
}