public with sharing class mbpCommunicationWhatsAppService {

    public static void sendWhatsAppMessages(List<String> contactIds, String message) {
        if (contactIds == null || contactIds.isEmpty() || String.isBlank(message)) {
            return;
        }

        Map<Integer, Set<Id>> batchedContactIds = new Map<Integer, Set<Id>>();
        Integer batchKey = 0;

        for (String contactIdValue : contactIds) {
            if (String.isBlank(contactIdValue)) {
                continue;
            }

            if (batchedContactIds.containsKey(batchKey) && batchedContactIds.get(batchKey).size() < 50) {
                batchedContactIds.get(batchKey).add((Id) contactIdValue);
            } else {
                batchKey++;
                batchedContactIds.put(batchKey, new Set<Id>{ (Id) contactIdValue });
            }
        }

        for (Integer keyValue : batchedContactIds.keySet()) {
            Set<Id> batchIds = batchedContactIds.get(keyValue);
            if (batchIds != null && !batchIds.isEmpty()) {
                sendWhatsAppMessagesFuture(new List<Id>(batchIds), message);
            }
        }
    }

    @future(callout=true)
    public static void sendWhatsAppMessagesFuture(List<Id> contactIds, String message) {
        try {
            if (contactIds == null || contactIds.isEmpty() || String.isBlank(message)) {
                return;
            }

            List<Contact> contactRecords = [
                SELECT Id, Name, MobilePhone, Phone
                FROM Contact
                WHERE Id IN :contactIds
            ];

            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');

            if (!Test.isRunningTest()) {
                req = OIC_CredentialsController.getCredentials('CommunicationAPI');
                req.setTimeout(120000);
                req.setHeader('Accept', 'application/json');
                req.setHeader('Content-Type', 'application/json');
            }

            Http http = new Http();

            List<WhatsAppApiRequest> payloadList = new List<WhatsAppApiRequest>();

            for (Contact contactRecord : contactRecords) {
                String phoneNumber = !String.isBlank(contactRecord.MobilePhone)
                    ? contactRecord.MobilePhone
                    : contactRecord.Phone;

                if (String.isBlank(phoneNumber)) {
                    continue;
                }

                WhatsAppApiRequest reqObj = new WhatsAppApiRequest();
                reqObj.CustomerName = contactRecord.Name;
                reqObj.MobileNumber = phoneNumber;
                reqObj.TextMessage = message;
                reqObj.TemplateName = 'muheira_launch_jan2026_qr_code_public';
                reqObj.QRCodeURL = 'https://test.com/qr';
                reqObj.SendWhatsapp = true;
                reqObj.SendSMS = true;
                reqObj.InvitationFormURL = 'https://test.com/form';

                payloadList.add(reqObj);
            }
            if (payloadList.isEmpty()) {
                return;
            }

            req.setBody(JSON.serialize(payloadList));

            HttpResponse response = new HttpResponse();

            if (!Test.isRunningTest()) {
                response = http.send(req);
            } else {
                response.setStatusCode(200);
                response.setBody('[{"MessageId":"12345","Status":"sent"}]');
            }

            System.debug('CommunicationWhatsAppService response >>> ' + response.getBody());

        } catch (Exception ex) {
            System.debug('CommunicationWhatsAppService error >>> ' + ex.getMessage());
        }
    }

    public class WhatsAppApiRequest {
        public String CustomerName;
        public String MobileNumber;
        public String TextMessage;
        public String TemplateName;
        public String QRCodeURL;
        public Boolean SendWhatsapp;
        public Boolean SendSMS;
        public String InvitationFormURL;
    }

    public class WhatsappMessageResponse {
        public String MessageId;
        public String Status;
        public String BitlyURL;
        public String ErrorMessage;
    }
}