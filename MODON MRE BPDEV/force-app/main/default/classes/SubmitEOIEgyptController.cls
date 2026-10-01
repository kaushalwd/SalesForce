/**-------------------------------------------------------------------
 * Description : A controller for submitsubmitEoiEgyptLwcEoiLwc Component
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Harshit Pareek   08-07-2025         Code Creation
 * -------------------------------------------------------------------
 * Notes: NaN
*/
public without sharing class SubmitEOIEgyptController {
    // Check eligibility of EOI if it should be Submitted.
    @AuraEnabled(cacheable=true)
    public static RespondWrap eoiSubmissionCheck(String eoiId) {

        //declaration and deseriliaze of wrapper
        //RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap =  new RespondWrap();
		respWrap.result='';
        Expressionofinterest__c eoi = [SELECT Id, Status__c, Amount__c FROM Expressionofinterest__c WHERE Id = :eoiId];
        List<Documents__c> eoiDocs = [SELECT Id, Status__c, Name FROM Documents__c WHERE Expressionofinterest__c = :eoiId AND Name IN ('KYC and Wealth Form')]; // Removed document - 'Signed EOI Form'
        // List<Boolean> eoiCheckList = new List<Boolean>();
        List<String> docNames = new List<String>();

        if(eoi != null){
            if( !eoiDocs.isEmpty()){
                for(Documents__c doc : eoiDocs){
                    if(doc.Status__c != 'Uploaded'){
                        docNames.add(doc.Name);
                    }
                }
                
                if(!docNames.isEmpty()){
                    respWrap.result = 'Please upload the required signed documents: ' + String.join(docNames, ', ');
                }
            }
            List<Receipt__c> receiptObj = [SELECT Id FROM Receipt__c WHERE Expressionofinterest__c =:eoiId];
            if(receiptObj.isEmpty() && eoi.Amount__c != '0'){
                respWrap.result = 'Please make sure payment is created.';
            } 
            
            
            if(respWrap.result==''){ 
                respWrap.result = 'Success'; 
            }
        }

        return respWrap;
    }

    @AuraEnabled
    public static RespondWrap submitEoi(String requestWrapParam) {

        //declaration and deseriliaze of wrapper
        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap =  new RespondWrap();

        Expressionofinterest__c eoi = [SELECT Id, Status__c FROM Expressionofinterest__c WHERE Id = :reqWrap.eoiId];

        if(eoi != null){
            eoi.Status__c = 'Submitted';
            update eoi;
            
            /*Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setComments(reqWrap.comments);
            request.setObjectId( eoi.Id);
    
            request.setSubmitterId(UserInfo.getUserId()); 
            
            request.setProcessDefinitionNameOrId('EOI_Approval_Process_Egypt');
            request.setSkipEntryCriteria(true);
    
            Approval.ProcessResult result = Approval.process(request);*/
        
        }
        return respWrap;
    }

    // ------------ Wrapper List ----------- //
    public class RequestWrap{
        @AuraEnabled public String eoiId;
        @AuraEnabled public String comments;
    }
    
    public class RespondWrap {
        @AuraEnabled public String result;
    }
}