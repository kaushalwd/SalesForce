/**********************************************************************************************************************
* Name               : PassfortTransactionTriggerHandler                                                        
* Description        : This class is used to handle all the Passfort Transaction trigger instances
* Usage              : Called from PassfortTransactionTrigger
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                Date            Comment                                                                       
* 1.0       kishor.sitaram.chaudhari@pwc.com         05 May 2024      Initial Draft       
******************************************************************************************************************/

public without sharing class PassfortTransactionTriggerHandler extends TriggerHandler {

    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        for(PassfortTransaction__c tempRecord : (list<PassfortTransaction__c>) newList){
            tempRecord.transactionId__c= UUID.randomUUID().toString() ;
        }
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
         System.debug('In PassfortTransactionTriggerHandler beforeUpdateMethod');
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
         System.debug('In PassfortTransactionTriggerHandler afterDeleteMethod');
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        //Pass only records where the Parent is blank 
        set<ID> profileIdsToProcess = new set<ID>();
        set<ID> notesToUpdate = new set<ID>();
        set<ID> shareholderLinksToUpdate = new set<ID>();
        for(PassfortTransaction__c tempRecord : (list<PassfortTransaction__c>) newList){
            if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_NOTES){
                notesToUpdate.add(tempRecord.Id); // for notes API callout
            } else if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK){
                shareholderLinksToUpdate.add(tempRecord.Id); // for shareholder link api callout
            }else if(tempRecord.PassfortTransaction__c == null && tempRecord.Document__c == null){
                profileIdsToProcess.add(tempRecord.Id); // for entities(Invididual or Corporate) api callout
            }
        }
        if(!profileIdsToProcess.isEmpty()){
           Database.executeBatch(new PassfortTransactionProcessBatch(profileIdsToProcess), 1);
        }       
        if(!notesToUpdate.isEmpty()){
            ID jobID = System.enqueueJob(new PassfortTransNotesQueueable(notesToUpdate));   
        }      
        if(!shareholderLinksToUpdate.isEmpty()){
           Database.executeBatch(new PassfortTransactionProcessBatch(shareholderLinksToUpdate), 1);  
        }
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        System.debug('In PassfortTransactionTriggerHandler afterUpdateMethod'); 
    }
}