/**********************************************************************************************************************
* Name               : BrokerRegistrationTriggerHandler                                                        
* Description        : This class is used as a handler for BrokerRegistration trigger
* Usage              : Called from BrokerRegistrationTrigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				15 May 2025     Initial Draft       
******************************************************************************************************************/
public with sharing class BrokerRegistrationTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }

    //*** After Insert Action***//DirectDebitRequestTriggerHelper
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        BrokerRegistrationTriggerHelper.brokerRegistrationFromSamaaro(newList);
    }
    
    //*** After Update Action***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }
}