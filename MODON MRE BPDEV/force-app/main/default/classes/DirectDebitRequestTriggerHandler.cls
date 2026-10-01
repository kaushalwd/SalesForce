/**********************************************************************************************************************
* Name               : DirectDebitRequestTriggerHandler                                                        
* Description        : This class is used as a handler for DirectDebitRequest trigger
* Usage              : Called from DirectDebitRequestTrigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22 Mar 2025     Initial Draft
* 1.1           Karunakar                  13 Sep 2026     Approve__c on a UAEDDS mandate queues the
*                                                          create call to the bank
* 1.2           Karunakar                  14 Sep 2026     Cancellation_Approved__c queues the
*                                                          cancelDDA call to the bank
******************************************************************************************************************/
public with sharing class DirectDebitRequestTriggerHandler extends TriggerHandler {
    
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        DirectDebitRequestTriggerHelper.validateDirectDebitRequestUniqueValidation(newList);
        DirectDebitRequestTriggerHelper.populateCommenceAndExpireDates(newList);
        DirectDebitRequestTriggerHelper.updateDirectDebitRequest(newList);        
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
       	DocumentValidationHelper.directDebitDocumentValidation(newList, oldMap, true);
        DirectDebitRequestTriggerHelper.updateDDRequestOwner(newList);
    }

    //*** After Insert Action***//DirectDebitRequestTriggerHelper
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        DocumentValidationHelper.directDebitDocGenerator(newList);
        SalesOrderStatusAutomationHelper.updateDDPaymentMethod(newList,null);
        //DirectDebitRequestTriggerHelper.sendCreateNotifications(newList);
    }
    
    //*** After Update Action***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        DirectDebitRequestTriggerHelper.createDirectDebitTransaction(newList, newMap, oldList, oldMap);
        DirectDebitRequestTriggerHelper.sendStatusChangeNotifications(newList, oldMap);
        //1.1 Finance approval sends a UAEDDS mandate to the bank
        //DirectDebitRequestTriggerHelper.submitApprovedUAEDDSMandates(newList, oldMap);
        //1.2 Finance approving a cancellation sends cancelDDA to the bank
        //DirectDebitRequestTriggerHelper.submitApprovedUAEDDSCancellations(newList, oldMap);
    }

}