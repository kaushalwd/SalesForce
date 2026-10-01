/**********************************************************************************************************************
* Name               : ChequeDetailsTriggerHandler                                                        
* Description        : This class is used to handle all the Sales Order trigger instances
* Usage              : Called from ChequeDetailsTrigger
* Created By         : Hanmanthu kottala                                                  
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           hanmanthu kottala        28 July 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class ChequeDetailsTriggerHandler extends TriggerHandler {
   //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        ChequeDetailsTriggerHelper.addDefaultLookups(newList, null);
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
       ChequeDetailsTriggerHelper.addDefaultLookups(newList, oldMap); 
    }

}