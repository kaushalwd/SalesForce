/* **
 * 1.0          Sivannarayana                               27 June 2026    Initial Draft
 ****/
@RestResource(urlMapping='/refundCaseUpdateAPI/*')
global with sharing class CaseUpdateAPI {

    global class CaseUpdateRequest {
        public String case_id;
        public String refund_option;
        public Boolean iban_uploaded;
        public String iban_file_link;
        public String iban_number;
        public String case_comments;
        public BankDetails bank_details;

        public String status;
        public String message_body;
        public String message_id;
        public String correlation_id;
        public String conversation_id;
        public Boolean deliveryStatusUpdate;
    }

    global class BankDetails {
        public String bank_name;
        public String beneficiary_name;
        public String bank_account_number;
        public String iban_number;
        public String bank_branch_name;
        public String swift_code;
        public String bank_country;
    }

    global class CaseUpdateResponse {
        public String case_id;
        public String status;
        public String response_message;

        public CaseUpdateResponse(String caseId, String status, String message) {
            this.case_id = caseId;
            this.status = status;
            this.response_message = message;
        }
    }

    @HttpPost
    global static void updateCaseDetails() {
        String requestBody = '';
        String responseBody = '';
        try {
            requestBody = RestContext.request.requestBody.toString();
            if (String.isBlank(requestBody)) {
                CaseUpdateResponse responseObj =
                    new CaseUpdateResponse(null, 'Failure', 'Request body is empty');
                sendResponseAndLog(400, responseObj, requestBody);
                return;
            }

            CaseUpdateRequest requestObj =
                (CaseUpdateRequest) JSON.deserialize(requestBody, CaseUpdateRequest.class);

            if (requestObj == null || String.isBlank(requestObj.case_id)) {
                CaseUpdateResponse responseObj =
                    new CaseUpdateResponse(null, 'Failure', 'case_id is required');

                sendResponseAndLog(400, responseObj, requestBody);
                return;
            }

            List<Case> caseList = [
                SELECT Id, Description
                FROM Case
                WHERE Id = :requestObj.case_id
                LIMIT 1
            ];

            if (caseList.isEmpty()) {
                CaseUpdateResponse responseObj =
                    new CaseUpdateResponse(requestObj.case_id, 'Failure', 'Case not found');
                sendResponseAndLog(404, responseObj, requestBody);
                return;
            }

            Case caseToUpdate = caseList[0];
            if (!String.isBlank(requestObj.refund_option)) {
                caseToUpdate.Customer_Refund_Options__c=requestObj.refund_option;
            }
            
            if (!String.isBlank(requestObj.iban_file_link)) {
                caseToUpdate.Customer_IBAN_Letter_Link__c=requestObj.iban_file_link;
            }
            
             if (!String.isBlank(requestObj.iban_number)) {
                caseToUpdate.IBAN_Number__c=requestObj.iban_number;
            }

            if (!String.isBlank(requestObj.case_comments)) {
                caseToUpdate.Description =requestObj.case_comments;
                   
            }

            if (requestObj.deliveryStatusUpdate == true) {
                if (!String.isBlank(requestObj.status)) {
                     caseToUpdate.Whats_App_Customer_Delivery_Status__c= requestObj.status;
                }             
            }
          
            CaseTriggerHandler.isTriggerDisabled = true;
            update caseToUpdate;

            CaseUpdateResponse responseObj =
                new CaseUpdateResponse(caseToUpdate.Id, 'Success', 'Case updated successfully');
            sendResponseAndLog(200, responseObj, requestBody);

        } catch (Exception ex) {
            CaseUpdateResponse responseObj =
                new CaseUpdateResponse(null, 'Failure', ex.getMessage());

            sendResponseAndLog(500, responseObj, requestBody);
            insert LoggerService.createApexLog(
                ex,
                'Refund Case Update API',
                'CaseUpdateAPI',
                'updateCaseDetails'
            );
        }
    }

    private static void sendResponseAndLog(
        Integer statusCode,
        CaseUpdateResponse responseObj,
        String requestBody
    ) {
        String responseBody = JSON.serialize(responseObj);

        insert LoggerService.createAPILog(
            'Refund Case Update API',
            'CaseUpdateAPI',
            'updateCaseDetails',
            requestBody,
            responseBody,
            'Status Code: ' + statusCode,
            'Inbound REST API'
        );
        sendResponse(statusCode, responseObj);
    }

    private static void sendResponse(Integer statusCode, CaseUpdateResponse responseObj) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseObj));
    }
}