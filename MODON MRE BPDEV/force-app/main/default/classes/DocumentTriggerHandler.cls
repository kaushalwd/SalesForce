/**********************************************************************************************************************
* Name               : DocumentTriggerHandler                                                        
* Description        : This class is used to handle all the Document trigger instances
* Usage              : Called from DocumentTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         9 May 2024     Initial Draft 
* 2.0           DineshSelvam                     13 Apr 2026    External Commission Review - Copy MODON SPA Document ID
* 3.0           Rushi Patel                      01 Sep 2026    Call DocumentTriggerHelper.autoSendDocuSign in afterUpdate
* 4.0           Naman Mittal                     29 Sep 2026    Agency TradeLicense uploaded: submit Pending Trade License owners to Agent_Approval
******************************************************************************************************************/
public without sharing class DocumentTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        //SalesOrderStatusAutomationHelper.soDocCreation(newList);
        //CustomerKYCHandler.mapKYCDocuments(newList,null);
     DocumentTriggerHelper.autoGenerateAndSendDocument(newList);

    }
    
    //*** After Update Action ***// 
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        DocumentTriggerHelper.updateSalesOrder(newMap, oldMap);
        // Added by Rushi Patel: Automatically publish Platform Event for DocuSign sending when document is Generated
        DocumentTriggerHelper.autoSendDocuSign(newMap, oldMap);
		SalesOrderStatusAutomationHelper.handleDocumentUploadAccount(newList, oldMap);
        CommissionLineReviewController.updateSPADocId(newList, oldMap); /** 2.0 External Commission Review - Copy MODON SPA Document ID **/
        MBP_BrokerAgencyLevelController.submitOwnersOnTradeLicenceUpload(newList, oldMap); /** 4.0 Broker owner onboarding **/
       // SalesOrderStatusAutomationHelper.updateRelavantDocumentsinSO(newList, oldMap);
       // CustomerKYCHandler.mapKYCDocuments(newList,oldMap);
    }
}