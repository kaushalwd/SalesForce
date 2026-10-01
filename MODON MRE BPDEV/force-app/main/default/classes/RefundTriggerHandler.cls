/**********************************************************************************************************************
* Name               : RefundTriggerHandler                                                        
* Description        : This class is used to handle all the Refund trigger instances
* Usage              : Called from RefundTrigger
* Created By         : Gautam Sah(Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Gautam Sah(Horizontal)           02 April 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class RefundTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){

    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){

    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

    }

    //*** After Delete Action ***//
    public override void beforeDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
    
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        RefundTriggerHelper.createDocumentRecords(newList);

    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
      
    }
}