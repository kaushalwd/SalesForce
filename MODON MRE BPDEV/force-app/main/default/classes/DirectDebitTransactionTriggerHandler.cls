/**********************************************************************************************************************
* Name               : DirectDebitTransactionTriggerHandler                                                        
* Description        : This class is used as a handler for DirectDebitRequest Transaction trigger
* Usage              : Called from DirectDebitTransactionTrigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22 Mar 2025     Initial Draft       
******************************************************************************************************************/
public with sharing class DirectDebitTransactionTriggerHandler extends TriggerHandler {
    
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }

    //*** After Insert Action***//
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        DirectDebitTransactionHelper.sendTranactionToFABGateway(newList);
        DirectDebitTransactionHelper.updateDirectDebitStatus(newList);
    }
    
    //*** After Update Action***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        //DirectDebitTransactionHelper.sendTranactionToFABGateway(newList);
        DirectDebitTransactionHelper.createPayment(newList, oldMap);
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(newList);        
    }

}