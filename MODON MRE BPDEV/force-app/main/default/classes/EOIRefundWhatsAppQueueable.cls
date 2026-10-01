/* **
 * 1.0          Sivannarayana                               27 June 2026    Initial Draft
 ****/
public with sharing class EOIRefundWhatsAppQueueable implements Queueable, Database.AllowsCallouts {

    private Id caseId;
    private String phoneNumber;
    private List<Id> eoiIds;
    private String messageType;
    private String templateName;

    private static final String WHATSAPP_URL =System.Label.EOI_WHATS_APP_URL;
    private static final String API_KEY =System.Label.EOI_API_KEY;

    public EOIRefundWhatsAppQueueable(
        Id caseId,
        String phoneNumber,
        List<Id> eoiIds,
        String messageType,
        String templateName
    ) {
        this.caseId = caseId;
        this.phoneNumber = phoneNumber;
        this.eoiIds = eoiIds;
        this.messageType = messageType;
        this.templateName = templateName;
    }

    public void execute(QueueableContext qc) {

        if (caseId == null || String.isBlank(phoneNumber) || eoiIds == null || eoiIds.isEmpty()) {
            return;
        }

        String jsonBody = '';
        String responseBody = '';
        String logStatus = '';

        Case caseToUpdate = new Case(Id = caseId);

        try {
            Case cs = [
                SELECT Id,
                       CaseNumber,
                       AccountId,
                       Account.FirstName,
                       Account.LastName,
                       Account.Name
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            List<Expressionofinterest__c> eoiList = [
                SELECT Id,
                       Name,
                       EOI_Amount_AED__c
                FROM Expressionofinterest__c
                WHERE Id IN :eoiIds
                ORDER BY CreatedDate ASC
            ];
            
            
            EOIRefundRequest requestBody = new EOIRefundRequest();
            requestBody.phone_number = phoneNumber;
            requestBody.case_id = String.valueOf(cs.Id);
            requestBody.template_name = getTemplateName(messageType, templateName);
            requestBody.first_name = cs.Account != null ? cs.Account.FirstName : null;
            requestBody.last_name = cs.Account != null ? cs.Account.LastName : null;
            requestBody.case_number = cs.CaseNumber;
            requestBody.eoi_details = new List<EOIDetail>();

            for (Expressionofinterest__c eoi : eoiList) {
                EOIDetail detail = new EOIDetail();
                detail.eoi_id = String.valueOf(eoi.Name);
                detail.eoi_amount = String.valueOf(eoi.EOI_Amount_AED__c);
                requestBody.eoi_details.add(detail);
            }
            
            if (!eoiList.isEmpty()) {
                Expressionofinterest__c firstEOI = eoiList[0];
                requestBody.eoi_id=String.valueOf(firstEOI.Name);
                requestBody.eoi_amount=String.valueOf(firstEOI.EOI_Amount_AED__c);
           }
            
            jsonBody = JSON.serialize(requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(WHATSAPP_URL);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-api-key', API_KEY);
            req.setTimeout(120000);
            req.setBody(jsonBody);
            System.debug('*** WhatsApp Request Body *** ' + jsonBody);
            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            responseBody = res.getBody();

            System.debug('*** WhatsApp Response Body *** ' + responseBody);

            logStatus = 'Status Code: ' + statusCode;

            if (statusCode >= 200 && statusCode < 300) {
                caseToUpdate.Whats_App_Integration_Status__c = 'Target Inserted';
            } else {
                caseToUpdate.Whats_App_Integration_Status__c = 'Initiated';
                
                caseToUpdate.Whats_App_Customer_Delivery_Status__c =
                    'WhatsApp API failed. Status Code: ' +
                    statusCode +
                    ', Response: ' +
                    responseBody;
              
            }

            insert LoggerService.createAPILog(
                'EOI Refund WhatsApp API',
                'EOIRefundWhatsAppQueueable',
                'execute',
                jsonBody,
                responseBody,
                logStatus,
                'Outbound REST API'
            );

        } catch (Exception ex) {

            responseBody = 'Exception: ' + ex.getMessage();

            caseToUpdate.Whats_App_Integration_Status__c = 'Initiated';
            caseToUpdate.Description =
                'WhatsApp API exception: ' + ex.getMessage();

            insert LoggerService.createAPILog(
                'EOI Refund WhatsApp API',
                'EOIRefundWhatsAppQueueable',
                'execute',
                jsonBody,
                responseBody,
                'Exception',
                'Outbound REST API'
            );

            insert LoggerService.createApexLog(
                ex,
                'EOI Refund WhatsApp API',
                'EOIRefundWhatsAppQueueable',
                'execute'
            );
        }

        update caseToUpdate;
    }

    private static String getTemplateName(String messageType, String templateName) {

        if (String.isBlank(messageType) || String.isBlank(templateName)) {
            return 'eoi_initial_outreach';
        }

        String key = messageType.trim() + '|' + templateName.trim();

        Map<String, String> templateMap = new Map<String, String>{
            'Initial Outreach|eoi_initial_outreach' => 'eoi_initial_outreach',
            'Initial Outreach|eoi_initial_reminder_1' => 'eoi_initial_reminder_1',
            'Initial Outreach|eoi_initial_reminder_2' => 'eoi_initial_reminder_2',
            'Initial Outreach|eoi_initial_reminder_3' => 'eoi_initial_reminder_3',

            'IBAN Letter Reminder Messages|eoi_iban_reminder_1' => 'eoi_iban_reminder_1',
            'IBAN Letter Reminder Messages|eoi_iban_reminder_2' => 'eoi_iban_reminder_2',
            'IBAN Letter Reminder Messages|eoi_iban_reminder_3' => 'eoi_iban_reminder_3',

            'Credit Applied Confirmation|eoi_credit_applied_confirmation' => 'eoi_credit_applied_confirmation',
            'Refund Processed Confirmation|eoi_refund_confirmation' => 'eoi_refund_confirmation'
        };

        if (templateMap.containsKey(key)) {
            return templateMap.get(key);
        }
        return 'eoi_initial_outreach';
    }

    public class EOIRefundRequest {
        public String phone_number;
        public String case_id;
        public List<EOIDetail> eoi_details;
        public String template_name;
        public String first_name;
        public String last_name;
        public String case_number;
        public String eoi_id;
        Public String eoi_amount;
    }

    public class EOIDetail {
        public String eoi_id;
        public String unit;
        public String eoi_amount;
    }
}