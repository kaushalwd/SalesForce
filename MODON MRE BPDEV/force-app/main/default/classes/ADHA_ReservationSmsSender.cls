/**********************************************************************************************************************
* Name               : ADHA_ReservationSmsSender
* Description        : Reservation confirmation and release SMS. Off by default: the template needs registering with
*                      the aggregator before delivery is reliable, and an unregistered template fails quietly.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_ReservationSmsSender {
    private static final String CREDENTIAL_NAME = 'CommunicationAPI';
    @TestVisible private static final String TEMPLATE_CONFIRMED = 'ADHA_Baniyas_Reservation_Confirmed';
    // ADHA_Baniyas_Undertaking_Signed is retired. Its message merged into the confirmation on
    // 25 Aug 2026; the aggregator registration can be withdrawn once this is live in production.
    @TestVisible private static final String TEMPLATE_RELEASED = 'ADHA_Baniyas_Reservation_Released';

    @TestVisible private static OIC_Credential__mdt credentialOverride;
    @TestVisible private static List<String> sent = new List<String>();

    /** ONE MESSAGE, AND ONLY AFTER THE SIGNATURE - an unsigned customer must never be told their
     *  reservation is confirmed. Fire and forget: an SMS outage must not roll back the reservation. */
    public static void confirmedAndSigned(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        try {
            dispatch(applicant, TEMPLATE_CONFIRMED, confirmedAndSignedBody(applicant, reservation));
        } catch (Exception e) {
            swallow(e);
        }
    }

    /** The villa they had committed to has gone back on the map. Only sent for a confirmed
     *  reservation - the caller decides; a swapped unsigned hold is browsing, not a loss. */
    public static void released(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        try {
            dispatch(applicant, TEMPLATE_RELEASED, releasedBody(applicant, reservation));
        } catch (Exception e) {
            swallow(e);
        }
    }

    /** Outer net: a field the caller did not SELECT throws on read, before dispatch()'s own try.
     *  Unhandled, that rolled back a reservation the customer had just been shown as confirmed. */
    private static void swallow(Exception e) {
        System.debug(LoggingLevel.ERROR, 'Reservation SMS failed: ' + e.getTypeName() + ': ' + e.getMessage());
    }

    @TestVisible
    private static void dispatch(ADHA_Applicant__c applicant, String template, String body) {
        if (ADHA_JourneyController.settings().Confirmation_SMS_Enabled__c != true) {
            return;
        }
        // Before the field reads below, not after: a batch caller would otherwise throw on the read
        // instead of returning at the guard that exists to protect it.
        if (System.isBatch() || System.isFuture() || System.isQueueable()) {
            System.debug(LoggingLevel.WARN, 'Reservation SMS skipped: async context cannot chain a future');
            return;
        }
        if (applicant == null || String.isBlank(applicant.Mobile_Number__c) || String.isBlank(body)) {
            return;
        }
        try {
            OIC_Credential__mdt credential = credential();
            String payload = payload(
                applicant.Customer_Name__c, applicant.Mobile_Number__c, body, template
            );
            sent.add(payload);
            if (!Test.isRunningTest()) {
                sendAsync(credential.Endpoint__c, credential.Username__c, credential.Password__c, payload);
            }
        } catch (Exception e) {
            // Swallowed on purpose. The reservation stands whether or not the message went.
            System.debug(LoggingLevel.ERROR, 'Reservation SMS failed: ' + e.getTypeName() + ': ' + e.getMessage());
        }
    }

    /** Project first, then every number on its own line: SMS carries no markup, so mixed Arabic and
     *  Latin on one line is placed by the handset's bidi algorithm and lands differently per phone. */
    /** THREE SEGMENTS IN EVERY CASE: the worst realistic row lands at 190 of the 201 characters
     *  three UCS-2 segments allow, and the wording was cut deliberately to hold that. */
    @TestVisible
    private static String confirmedAndSignedBody(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        if (reservation == null) {
            return null;
        }
        Decimal additional = reservation.Additional_Amount__c == null ? 0 : reservation.Additional_Amount__c;

        String text = 'غرب بني ياس / West Baniyas\n'
            + reservation.Name + '\n'
            + plotOf(reservation) + '\n';
        if (additional > 0) {
            text += money(additional) + ' AED\n'
                + dateOf(reservation.Additional_Payment_Due__c) + '\n';
        }
        return text
            + villaLine(reservation, true)
            + 'تهانينا! تم توقيع التعهد وتأكيد الحجز\n'
            + villaLine(reservation, false)
            + 'Undertaking signed, reservation confirmed.';
    }

    /** Same shape as the other: project, then each number alone on its line, then both languages. */
    @TestVisible
    private static String releasedBody(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        if (reservation == null) {
            return null;
        }
        return 'غرب بني ياس / West Baniyas\n'
            + reservation.Name + '\n'
            + plotOf(reservation) + '\n'
            + villaLine(reservation, true)
            + 'تم إلغاء حجز هذا المسكن. يمكنك اختيار مسكن آخر.\n'
            + villaLine(reservation, false)
            + 'This villa has been released. You can choose another villa.';
    }

    /** Approved pieces joined, never a sentence: Arabic has six plural forms, so bedrooms stay
     *  label-plus-value. Duplicated from PICKLISTS in adhaLabels.js - keep the two in step. */
    @TestVisible
    private static String villaLine(ADHA_Reservation__c reservation, Boolean arabic) {
        ADHA_Unit__c unit = reservation == null ? null : reservation.Unit__r;
        if (unit == null) {
            return '';
        }
        String style = styleLabel(unit.Villa_Type__c, arabic);
        String beds = unit.Rooms_Count__c == null
            ? ''
            : String.valueOf(Integer.valueOf(unit.Rooms_Count__c));
        if (String.isBlank(style) && String.isBlank(beds)) {
            return '';
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(style)) {
            parts.add(style);
        }
        if (String.isNotBlank(beds)) {
            parts.add(arabic ? 'غرف النوم: ' + beds : beds + ' bedrooms');
        }
        return String.join(parts, ' · ') + '\n';
    }

    @TestVisible
    private static String styleLabel(String villaType, Boolean arabic) {
        if (String.isBlank(villaType)) {
            return '';
        }
        if (!arabic) {
            // Heritage is the stored value; ADHA renamed the style to Andalusian for display only.
            return villaType == 'Heritage' ? 'Andalusian' : villaType;
        }
        Map<String, String> translated = new Map<String, String>{
            'Modern' => 'عصري',
            'Heritage' => 'أندلسي'
        };
        String label = translated.get(villaType);
        return label == null ? villaType : label;
    }

    private static String plotOf(ADHA_Reservation__c reservation) {
        return reservation.Unit__r != null && String.isNotBlank(reservation.Unit__r.Plot_UID__c)
            ? reservation.Unit__r.Plot_UID__c
            : '';
    }

    /** Grouped thousands, no decimals. A trailing .00 on a six figure number reads as noise. */
    @TestVisible
    private static String money(Decimal amount) {
        return Decimal.valueOf(amount.round(System.RoundingMode.HALF_UP)).format();
    }

    /** Numeric, not a month name: an Arabic month name beside Latin digits reorders on the handset. */
    @TestVisible
    private static String dateOf(Date value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value.day()).leftPad(2, '0') + '/'
            + String.valueOf(value.month()).leftPad(2, '0') + '/'
            + String.valueOf(value.year());
    }

    /** Same Communication API contract the OTP sender satisfies. */
    @TestVisible
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

    @future(callout=true)
    private static void sendAsync(String endpoint, String username, String password, String payload) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader(
            'Authorization',
            'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password))
        );
        request.setBody(payload);
        HttpResponse response = new Http().send(request);
        Integer status = response == null ? 0 : response.getStatusCode();
        if (status < 200 || status >= 300) {
            // Nothing to roll back from a future context; the log is the record that it failed.
            System.debug(LoggingLevel.ERROR, 'Reservation SMS API returned ' + status);
        }
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
        // Checked on both routes, so a blank endpoint in a test fails the same way it would live.
        if (found == null || String.isBlank(found.Endpoint__c)) {
            throw new ADHA_SigningService.SigningException('Communication API credential is not configured.');
        }
        return found;
    }
}