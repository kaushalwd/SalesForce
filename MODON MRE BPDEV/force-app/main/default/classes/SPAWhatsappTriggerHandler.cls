/**********************************************************************************************************************
* Name               : SPAWhatsappTriggerHandler                                                        
* Description        : This class is used as a handler for SPAWhatsapp Transaction trigger
* Usage              : Called from SPAWhatsappTrigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				05 10 2025     Initial Draft
******************************************************************************************************************/
public with sharing class SPAWhatsappTriggerHandler extends TriggerHandler {

    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        
    }
    
    //*** After Insert Action***//
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
       SPAWhatsappTriggerHelper.sendWhatsappMessage(newList);       
    }
    
    //*** After Update Action***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
 		SPAWhatsappTriggerHelper.downloadSPA(newList, oldMap);
        //SPAWhatsappTriggerHelper.sendEmailMessage(newList, oldMap); 
        SPAWhatsappTriggerHelper.sendJOSPA(newList, oldMap);
    }
}