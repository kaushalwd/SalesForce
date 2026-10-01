/**-------------------------------------------------------------------
 * Description : A controller for opportunityApprovalRequest lwc action button
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Abdallah Hdaib   16-02-2024         Code Creation
 * -------------------------------------------------------------------
 * Notes: NaN
*/
public without sharing class OpportunityApprovalRequestController {

    @AuraEnabled
    public static RespondWrap checkCondsAndSubmitApproval(String requestWrapParam) {

        //declaration and deseriliaze of wrapper
        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap =  new RespondWrap();

        List<Opportunity> myOpportunity = [SELECT Id,UAE_Resident_Status__c, EmiratesIDExpiryDate__c, IBAN_Number__c, PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c, EIDNumber__c,
                                            (SELECT Id, Name, Status__c FROM Documents__r) FROM Opportunity WHERE Id = :reqWrap.oppId];
        // List<Boolean> docsCheck = new List<Boolean>();
        Set<String> missingFields = new Set<String>();
        Set<String> docNames = new Set<String>();
        Set<String> mandatoryDocuments = new Set<String>{'Passport Copy'};


        if(!myOpportunity.isEmpty()){
            for(Opportunity opp : myOpportunity){
                if(opp.UAE_Resident_Status__c == null){
                    missingFields.add('UAE Resident Status');
                }
                if(opp.IBAN_Number__c == null){
                    missingFields.add('IBAN Number');
                }
                if(opp.PassportNumber__c == null) {
                    missingFields.add('Passport Number');
                }
                if(opp.PassportIssueDate__c == null) {
                    missingFields.add('Passport Issue Date');
                }
                if(opp.PassportExpiryDate__c == null) {
                    missingFields.add('Passport Expiry Date');
                }
                if(opp.UAE_Resident_Status__c == 'Resident'){
                    mandatoryDocuments.add('Emirates ID');
                    if(opp.EmiratesIDExpiryDate__c == null) {
                        missingFields.add('Emirates ID Expiry Date');
                    }
                    if(opp.EIDNumber__c == null) {
                        missingFields.add('Emirates ID Number');
                    }
                }
                for(Documents__c doc : opp.Documents__r){
                    if(doc.Status__c != 'Uploaded' && mandatoryDocuments.contains(doc.Name)){
                        docNames.add(doc.Name);
                    }
                }
            }

            if(docNames.isEmpty() && missingFields.isEmpty()){
                // Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
                // request.setComments(reqWrap.comments);
                // request.setObjectId( myOpportunity[0].id);

                // request.setSubmitterId(UserInfo.getUserId()); 
                
                // request.setProcessDefinitionNameOrId('Opportunity_Approval');
                // request.setSkipEntryCriteria(true);

                // Approval.ProcessResult result = Approval.process(request);
                respWrap.resultMessage = 'Approval request submitted successfully.';
            } else {
                if(!docNames.isEmpty()){
                    respWrap.resultMessage = 'Please upload required documents: ' + String.join(docNames, ', ');
                    
                }
                if(!missingFields.isEmpty()){
                    respWrap.resultMessage = 'Please populate required fields: ' + String.join(missingFields, ', ');
                }
                
            }
        }

        return respWrap;
    }

    @AuraEnabled
    public static RespondWrap submitForApproval(String requestWrapParam) {
    
        //declaration and deseriliaze of wrapper
        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap =  new RespondWrap();

        List<Opportunity> myOpportunity = [SELECT Id,UAE_Resident_Status__c, EmiratesIDExpiryDate__c, IBAN_Number__c, PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c, EIDNumber__c,
                                            (SELECT Id, Name, Status__c FROM Documents__r) FROM Opportunity WHERE Id = :reqWrap.oppId];
        
        Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
        request.setComments(reqWrap.comments);
        request.setObjectId( myOpportunity[0].id);

        request.setSubmitterId(UserInfo.getUserId()); 
        
        request.setProcessDefinitionNameOrId('Opportunity_Approval');
        request.setSkipEntryCriteria(true);

        Approval.ProcessResult result = Approval.process(request);
        respWrap.resultMessage = 'Approval request submitted successfully.';

        return respWrap;
    }


    // ------------ Wrapper List ----------- //
    public class RequestWrap{
        @AuraEnabled public String oppId;
        @AuraEnabled public String comments;
    }
    
    public class RespondWrap {

        @AuraEnabled public List<Opportunity> myOpps = new List<Opportunity>();
        // @AuraEnabled public List<String> docNames = new List<String>();
        @AuraEnabled public String allDocNamesInString;
        @AuraEnabled public string resultMessage;
    }
}