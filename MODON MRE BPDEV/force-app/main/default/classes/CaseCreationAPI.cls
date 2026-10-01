/**
 * REST API Class: Creates a Case from an external system (e.g. the Modon Connect customer app).
 * Returns the created Case's Id and CaseNumber.
 */
@RestResource(urlMapping='/caseCreationAPI/*')
global with sharing class CaseCreationAPI {

    // Whitelisted request keys, mapped 1:1 onto Case fields. Apex identifiers can't contain
    // "__", so these are read as map keys rather than typed wrapper properties.
    private static final List<String> ALLOWED_FIELDS = new List<String>{
        'AccountId', 'ContactId', 'Unit__c', 'Requestor_Phone__c', 'Requestor_Email__c',
        'Requestor_Name__c', 'Language_Preference__c', 'Description', 'Subject',
        'Customer_Type__c', 'Case_Comments__c', 'Origin', 'Channel__c', 'Source__c',
        'Sub_Vertical__c', 'CaseCategory__c', 'CaseSubCategory__c', 'Customer_Remarks__c',
        'Genesys_Conversation_ID__c'
    };

    global class CaseCreationResponse {
        global String CaseId;
        global String CaseNumber;
        global String Status;
        global String ErrorMessage;

        global CaseCreationResponse(String caseId, String caseNumber, String status, String errorMessage) {
            this.CaseId = caseId;
            this.CaseNumber = caseNumber;
            this.Status = status;
            this.ErrorMessage = errorMessage;
        }
    }

    @HttpPost
    global static void createCase() {

        String requestBody = '';

        try {
            requestBody = (RestContext.request != null && RestContext.request.requestBody != null)
                ? RestContext.request.requestBody.toString()
                : '';

            if (String.isBlank(requestBody)) {
                sendResponseAndLog(
                    400,
                    new CaseCreationResponse(null, null, 'Failure', 'Request body is empty'),
                    requestBody
                );
                return;
            }

            Map<String, Object> reqMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            Case newCase = new Case();
            for (String fieldName : ALLOWED_FIELDS) {
                if (reqMap.get(fieldName) != null) {
                    newCase.put(fieldName, String.valueOf(reqMap.get(fieldName)));
                }
            }

            // RecordTypeId isn't caller-supplied - the Id differs per org, so it's looked
            // up by DeveloperName and always set to the standard Case record type.
            newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get('Standard').getRecordTypeId();

            insert newCase;

            Case insertedCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :newCase.Id LIMIT 1];

            sendResponseAndLog(
                200,
                new CaseCreationResponse(insertedCase.Id, insertedCase.CaseNumber, 'Success', null),
                requestBody
            );
        }
        catch (Exception ex) {
            sendResponseAndLog(
                500,
                new CaseCreationResponse(null, null, 'Failure', ex.getMessage()),
                requestBody
            );
            insert LoggerService.createApexLog(ex, 'Case Creation API', 'CaseCreationAPI', 'createCase');
        }
    }

    private static void sendResponseAndLog(Integer statusCode, CaseCreationResponse responseObj, String requestBody) {

        String responseBody = JSON.serialize(responseObj);

        insert LoggerService.createAPILog(
            'Case Creation API',
            'CaseCreationAPI',
            'createCase',
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