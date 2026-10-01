/**********************************************************************************************************************
* Name               : MBP_SendGridVerificationSender
* Description        : Sends broker portal OTPs over SendGrid. Hooked into the verification framework through
*                      Verification_Config__mdt.Sender_Class__c so the mail keeps the subject, wording and Modon
*                      wrapper it has always had. The context decides which of the two wordings goes out.
* Created By         : Kiran Rehan
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Kiran Rehan                       13 Sep 2026     Initial version
**********************************************************************************************************************/
public without sharing class MBP_SendGridVerificationSender implements VerificationSender {

    private static final String GRID_CONFIG_NAME = 'Al Naseem';
    @TestVisible private static final String CONTEXT_AGENCY_BANK = 'BROKER_AGENCY_BANK';

    public void send(VerificationMessage message) {
        if (message == null || String.isBlank(message.target)) {
            throw new VerificationService.VerificationException('Email address is required to send a verification code.');
        }
        if (String.isBlank(message.code)) {
            throw new VerificationService.VerificationException('Verification code is required.');
        }

        Boolean isAgencyBank = message.context == CONTEXT_AGENCY_BANK;

        // The framework passes a generic subject, so set our own either way.
        String subject = isAgencyBank ? 'Your OTP for Bank Details Update' : 'Your OTP from Modon';
        String bodyHtml = isAgencyBank ? agencyBankBody(message.code) : registrationBody(message.code);

        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyHtml);
        String personalizationsEntry = '[{"to": [{"email": "' + escapeForJson(message.target) + '" } ] }]';

        BP_SendGridUtilityClass.sendEmail(personalizationsEntry, GRID_CONFIG_NAME, subject, emailHtml, true);
    }

    private static String registrationBody(String code) {
        return 'Dear Partner,<br><br>' +
            'Please use the following One-Time Password (OTP):<br><br>' +
            '<strong>OTP: ' + code + '</strong><br><br>' +
            'This OTP is valid for a one time use and is issued in accordance with Modon policies.<br><br>' +
            'Please do not share this code with anyone.<br><br>' +
            'If you did not request this, please contact Modon support immediately.<br><br>';
    }

    private static String agencyBankBody(String code) {
        return 'Dear Owner, <br><br>' +
            'Please use the following One-Time Password (OTP):<br><br>' +
            '<strong>OTP: ' + code + '</strong><br><br>' +
            'This OTP is valid for a one time use and is issued in accordance with Modon policies.<br><br>' +
            'Please do not share this code with anyone.<br><br>' +
            'If you did not request, please contact Modon support immediately.<br><br>' +
            'Thank you,<br><br>Regards,<br>Modon Broker Team';
    }

    // The personalizations block is hand built JSON, so escape the address before it goes in.
    private static String escapeForJson(String value) {
        return value == null ? '' : value.trim().replace('\\', '\\\\').replace('"', '\\"');
    }
}