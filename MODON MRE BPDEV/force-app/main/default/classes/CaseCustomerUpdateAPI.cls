/**********************************************************************************************************************
* Name               : CaseCustomerUpdateAPI
* Description        : Updates the Customer Follow-Up / Customer Remarks fields on an existing
*                       Case. The Case is identified by the customer's mobile number plus the
*                       Case Number (instead of the Salesforce record Id), since the calling
*                       external system only knows those two values. Returns an error response
*                       when no Case matches that combination.
*
*                       Uses the same field API names as the standard PATCH /sobjects/Case
*                       contract (IS_Customer_Follow_Up__c, Customer_Follow_Up_Comments__c,
*                       Customer_Remarks__c). A field that is omitted from the request body
*                       keeps its current Salesforce value unchanged - e.g. sending only
*                       Customer_Remarks__c will not reset IS_Customer_Follow_Up__c.
*                       Sub_Vertical__c and CaseCategory__c only update when sent with a
*                       non-empty value - an omitted or empty value leaves them unchanged.
*                       Setting either one also re-applies the Case_Config_Category__mdt
*                       mapping (Organization/Department/Vertical/Queue/Priority/SLA),
*                       same as Case creation - the rest of the Case trigger stays
*                       disabled for this endpoint. The mobile number is matched
*                       against ContactMobile, Customer_Phone__c, and
*                       Visitor_Phone_Search__c - a match on any one of these is
*                       sufficient.
* Usage              : POST /services/apexrest/caseCustomerUpdateAPI/
* Sample body (Customer Follow-Up):
*   {
*     "mobileNumber": "971501234567",
*     "caseNumber": "00012345",
*     "IS_Customer_Follow_Up__c": true,
*     "Customer_Follow_Up_Comments__c": "Customer requested a callback regarding the payment status."
*   }
* Sample body (Customer Remarks only):
*   {
*     "mobileNumber": "971501234567",
*     "caseNumber": "00012345",
*     "Customer_Remarks__c": "Customer confirmed that the issue has been resolved."
*   }
***********************************************************************************************************************/
@RestResource(urlMapping='/caseCustomerUpdateAPI/*')
global with sharing class CaseCustomerUpdateAPI {

    global class CaseCustomerUpdateResponse {
        public String status;
        public String message;
        public String caseId;

        public CaseCustomerUpdateResponse(String status, String message, String caseId) {
            this.status = status;
            this.message = message;
            this.caseId = caseId;
        }
    }

    @HttpPost
    global static void updateCase() {

        String requestBody = '';

        try {
            requestBody = RestContext.request.requestBody.toString();

            if (String.isBlank(requestBody)) {
                sendResponseAndLog(
                    400,
                    new CaseCustomerUpdateResponse('Failure', 'Request body is empty', null),
                    requestBody
                );
                return;
            }

            Map<String, Object> reqMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            String mobileNumber = (String) reqMap.get('mobileNumber');
            String caseNumber = (String) reqMap.get('caseNumber');

            if (String.isBlank(mobileNumber) || String.isBlank(caseNumber)) {
                sendResponseAndLog(
                    400,
                    new CaseCustomerUpdateResponse('Failure', 'mobileNumber and caseNumber are required', null),
                    requestBody
                );
                return;
            }

            // Match on digits only: ContactMobile / Customer_Phone__c /
            // Visitor_Phone_Search__c are stored inconsistently with and without a
            // leading '+' / country code formatting, so a plain digit substring
            // match is the most reliable way to line them up with the
            // caller-supplied mobileNumber.
            String digitsOnlyMobile = mobileNumber.replaceAll('[^0-9]', '');

            if (String.isBlank(digitsOnlyMobile)) {
                sendResponseAndLog(
                    400,
                    new CaseCustomerUpdateResponse('Failure', 'mobileNumber is not a valid phone number', null),
                    requestBody
                );
                return;
            }

            // RecordTypeId/CaseCategory__c/CaseSubCategory__c/Sub_Vertical__c/Department__c/
            // Organization__c/Vertical__c/Queue__c/Priority/OwnerId are queried so
            // CaseConfigService.applyCategoryConfig (called below) can read them - it throws
            // if it touches a field that was never queried or assigned on this row.
            // Any one of the three phone fields matching is sufficient.
            List<Case> matches = [
                SELECT Id, RecordTypeId, CaseCategory__c, CaseSubCategory__c, Sub_Vertical__c,
                       Department__c, Organization__c, Vertical__c, Queue__c, Priority, OwnerId, Origin
                FROM Case
                WHERE CaseNumber = :caseNumber
                AND (
                    ContactMobile LIKE :('%' + digitsOnlyMobile + '%')
                    OR Customer_Phone__c LIKE :('%' + digitsOnlyMobile + '%')
                    OR Visitor_Phone_Search__c LIKE :('%' + digitsOnlyMobile + '%')
                )
                LIMIT 1
            ];

            if (matches.isEmpty()) {
                sendResponseAndLog(
                    404,
                    new CaseCustomerUpdateResponse('Failure', 'No case found', null),
                    requestBody
                );
                return;
            }

            Case caseToUpdate = matches[0];

            // Only touch a field when the caller actually included that key, so an
            // omitted field keeps its current Salesforce value unchanged.
            if (reqMap.containsKey('IS_Customer_Follow_Up__c')) {
                caseToUpdate.IS_Customer_Follow_Up__c = (Boolean) reqMap.get('IS_Customer_Follow_Up__c');
            }

            if (reqMap.containsKey('Customer_Follow_Up_Comments__c')) {
                caseToUpdate.Customer_Follow_Up_Comments__c = (String) reqMap.get('Customer_Follow_Up_Comments__c');
            }

            if (reqMap.containsKey('Customer_Remarks__c')) {
                caseToUpdate.Customer_Remarks__c = (String) reqMap.get('Customer_Remarks__c');
            }

            // Sub_Vertical__c / CaseCategory__c only update when a non-empty value is
            // supplied, regardless of whether the key is present in the request body.
            String subVertical = (String) reqMap.get('Sub_Vertical__c');
            if (String.isNotBlank(subVertical)) {
                caseToUpdate.Sub_Vertical__c = subVertical;
            }

            String caseCategory = (String) reqMap.get('CaseCategory__c');
            if (String.isNotBlank(caseCategory)) {
                caseToUpdate.CaseCategory__c = caseCategory;
            }

            // The trigger is disabled below (this API intentionally skips owner
            // reassignment, SLA recalculation, access validation, etc.), so when a new
            // Sub_Vertical__c/CaseCategory__c was supplied, the Case_Config_Category__mdt
            // mapping (Organization/Department/Queue/Priority) has to be applied directly -
            // otherwise it would never run for this endpoint.
            if (String.isNotBlank(subVertical) || String.isNotBlank(caseCategory)) {
                CaseConfigService.applyCategoryConfig(new List<Case>{ caseToUpdate }, null);
            }

            CaseTriggerHandler.isTriggerDisabled = true;
            update caseToUpdate;

            sendResponseAndLog(
                200,
                new CaseCustomerUpdateResponse('Success', 'Case updated successfully', caseToUpdate.Id),
                requestBody
            );

        } catch (Exception ex) {
            sendResponseAndLog(
                500,
                new CaseCustomerUpdateResponse('Failure', ex.getMessage(), null),
                requestBody
            );

            insert LoggerService.createApexLog(
                ex,
                'Case Customer Update API',
                'CaseCustomerUpdateAPI',
                'updateCase'
            );
        }
    }

    private static void sendResponseAndLog(
        Integer statusCode,
        CaseCustomerUpdateResponse responseObj,
        String requestBody
    ) {
        String responseBody = JSON.serialize(responseObj);

        insert LoggerService.createAPILog(
            'Case Customer Update API',
            'CaseCustomerUpdateAPI',
            'updateCase',
            requestBody,
            responseBody,
            'Status Code: ' + statusCode,
            'Inbound REST API'
        );

        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(responseBody);
    }
}