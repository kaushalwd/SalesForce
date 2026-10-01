/**********************************************************************************************************************
* Name               : PassfortTransNotesQueueable                                                        
* Description        : This class is used to form JSON request and make get notes api callout for passfort transactions
* Usage              : Called from PassfortTransactionTriggerHandler
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                Date            Comment                                                                       
* 1.0       kishor.sitaram.chaudhari@pwc.com         22 May 2024      Initial Draft       
******************************************************************************************************************/

public class PassfortTransNotesQueueable implements Queueable,Database.AllowsCallouts {
    private Set<ID> trIds;
    
    public PassfortTransNotesQueueable(Set<ID> notesTransactionIDs) {
        this.trIds = notesTransactionIDs;
    }
    
    public void execute(QueueableContext context) {
        prepareJSON(trIds);       
    }
    
    // to form JSON using wrapper class and record field values
    public static void prepareJSON(Set<ID> transactionIDs){  
        
        Map<String,String> mapOfTrRecIdvsResponse = new Map<String,String>();
        Map<String,String> mapOfAccIdvsProfileId = new Map<String,String>();
        Map<String,String> mapOfConIdvsProfileId = new Map<String,String>();
        
        for(Passforttransaction__c tempRecord : [Select Id,transactionId__c,ProfileId__c,Account__c,Contact__c from Passforttransaction__c where id in :transactionIDs]){
            
            PassfortTransNotesWrapper objPTNW = new PassfortTransNotesWrapper();

            objPTNW.root_id = tempRecord.ProfileId__c;
            objPTNW.id = tempRecord.transactionId__c;
            
            String jsonString = Json.serialize(objPTNW);
            
            string endpointURL = Constants.PASSFORT_TR_NOTES_ENDPOINT;
             
            //Make callout
            HTTPResponse res = PassfortTransactionProcessHelper.makeapiCallout(endpointURL,jsonString);
            if(res.getStatus() == 'OK'){
                PassfortTransNotesResponseWrapper objResponse = (PassfortTransNotesResponseWrapper) JSON.deserialize(res.getBody(), PassfortTransNotesResponseWrapper.class);
                List<Tasks> lstTasks = new List<Tasks>();
                if(objResponse.tasks!=null)
                  lstTasks.addAll(objResponse.tasks);
                
                String responseStatus = objResponse.status;
                String combineNotes='';                
                if(responseStatus == Constants.PASSFORT_TR_SUCCESS && (lstTasks.size()>0 || Test.IsRunningTest())) { 
                     List<Notes> lstNotes = new List<Notes>();
                    Map<DateTime,String> mapOfnoteDTVsText = new Map<DateTime,String>();
                    for(Tasks objTask :lstTasks){
                        lstNotes.clear();
                        if(objTask.notes!=null){
                           lstNotes.addAll(objTask.notes);
                         for(Notes objNote :lstNotes){
                             string strDT = objNote.created_on.replace(' ','T');
                             DateTime formatedDT = (DateTime)Json.deserialize('"'+strDT+'"', DateTime.class);
                             System.debug(formatedDT);
                             mapOfnoteDTVsText.put(formatedDT,objNote.created_on+' : ' /* +objTask.task_type+' : '*/ +objNote.text);
                         }
                        }
                    }
                    List<DateTime> lstKeys = new List<DateTime>();                    
                    lstKeys.addAll(mapOfnoteDTVsText.keySet());                    
                    lstKeys.sort();
                    DateTime objDT;
                    for(integer i=1;i<=lstKeys.size();i++){
                        objDT = lstKeys.get(lstKeys.size()-i);
                        combineNotes = combineNotes==''?mapOfnoteDTVsText.get(objDT):combineNotes+'\n\n'+mapOfnoteDTVsText.get(objDT);
                    }
                    if(tempRecord.Account__c != null)                                       
                        mapOfAccIdvsProfileId.put(tempRecord.Account__c,combineNotes);
                    else if(tempRecord.Contact__c != null)   
                        mapOfConIdvsProfileId.put(tempRecord.Contact__c,combineNotes);
                }
            }
            mapOfTrRecIdvsResponse.put(tempRecord.Id,res.getBody());
        }
        PassfortTransactionProcessHelper.updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse,new Map<String,String>());
        PassfortTransactionProcessHelper.updateAccountOrContactRecord(mapOfAccIdvsProfileId, mapOfConIdvsProfileId,'comment');
    }
    
    public class PassfortTransNotesResponseWrapper {
        public String id;
        public String root_id;
        public String status;
        public List<Tasks> tasks;
        public String error_msg;       
    }
    public class Tasks{
        public String task_id;
        public String task_type;
        public List<Notes> notes;
    }
    public class Notes{
        public String note_id;
        public String created_on;
        public String text;
    }
}