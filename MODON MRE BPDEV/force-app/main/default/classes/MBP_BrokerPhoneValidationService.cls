/**********************************************************************************************************************
* Name          : MBP_BrokerPhoneValidationService
* Description   : REST endpoint for external systems to check whether a phone number belongs to a
*                  Broker Agent Contact (RecordType.Name = 'Broker Agent', MobilePhone populated).
*
* Endpoint      : POST /services/apexrest/BrokerPhoneValidation/
* Auth          : Standard Salesforce REST API auth (OAuth session/bearer token) — set up a
*                 Connected App / Named Principal on the external system's side as usual; this

**********************************************************************************************************************/
@RestResource(urlMapping='/BrokerPhoneValidation/*')
global with sharing class MBP_BrokerPhoneValidationService {

    @HttpPost
    global static void checkPhone() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        ResponseWrapper result = new ResponseWrapper();

        try {
            RequestWrapper body = (req.requestBody != null && req.requestBody.toString() != null)
                ? (RequestWrapper) JSON.deserialize(req.requestBody.toString(), RequestWrapper.class)
                : null;

            String phone = (body != null) ? body.phoneNumber : null;
            result.phoneNumber = phone;

            if (String.isBlank(phone)) {
                res.statusCode = 400;
                result.isValid = false;
                result.message = 'phoneNumber is required.';
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                return;
            }

            String canonical = normalizePhone(phone);

            if (String.isBlank(canonical)) {
                res.statusCode = 400;
                result.isValid = false;
                result.message = 'phoneNumber does not contain any digits.';
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                return;
            }

            
            String likePattern = '%' + canonical + '%';
            List<Contact> candidates = [
                SELECT Id, MobilePhone
                FROM Contact
                WHERE RecordType.Name = 'Broker Agent'
                  AND MobilePhone != null
                  AND MobilePhone LIKE :likePattern
            ];

            Id matchedContactId;
            for (Contact c : candidates) {
                if (normalizePhone(c.MobilePhone) == canonical) {
                    matchedContactId = c.Id;
                    break;
                }
            }

            if (matchedContactId != null) {
                result.isValid   = true;
                result.contactId = matchedContactId;
                result.message   = 'Valid — a Broker Agent contact was found with this mobile number.';
            } else {
                result.isValid   = false;
                result.contactId = null;
                result.message   = 'Not valid — no Broker Agent contact found with this mobile number.';
            }

            res.statusCode = 200;

        } catch (Exception e) {
            res.statusCode = 500;
            result.isValid = false;
            result.message = 'Error while validating phone number: ' + e.getMessage();
        }

        res.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    // Strips everything down to digits, then strips a leading UAE country code (+971 / 00971 /
    // 971) and a leading local trunk '0', so '+971 50 382 1112', '00971503821112',
    // '971503821112', '0503821112' and '503821112' all normalize to the same '503821112'.
    private static String normalizePhone(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }

        String digits = raw.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) {
            return null;
        }

        if (digits.startsWith('00971') && digits.length() > 9) {
            digits = digits.substring(5);
        } else if (digits.startsWith('971') && digits.length() > 9) {
            digits = digits.substring(3);
        }

        while (digits.startsWith('0') && digits.length() > 9) {
            digits = digits.substring(1);
        }

        return digits;
    }

    global class RequestWrapper {
        global String phoneNumber;
    }

    global class ResponseWrapper {
        global String phoneNumber;
        global Boolean isValid;
        global Id contactId;
        global String message;
    }
}