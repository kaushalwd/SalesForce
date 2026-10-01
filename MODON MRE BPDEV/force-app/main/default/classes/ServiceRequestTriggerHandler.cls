/**********************************************************************************************************************
* Name               : ServiceRequestTriggerHandler                                                        
* Description        : This class is used to handle all the Service Request trigger instances
* Usage              : Called from SalesOrderTrigger
* Created By         : Active Minds                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Manoj         13 Dec 2024     Initial Draft     
* 1.0           Raghu Gajjela 23 OCT 2025     Initial Draft		beforeinsertunitcancellation method for UnitCancellation
*1.1  			Raghu Gajjela 					03 Apr 2026		 Added method to trigger  caculation.
* 1.2           Chandu                          14/04/2026       Added methods to calculate the installment and ADM amount on Pre and Post Sr Creation                         
******************************************************************************************************************/

public without sharing class ServiceRequestTriggerHandler  implements ITriggerHandler{
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return isTriggerDisabled;
    }
    
    public void beforeInsert(List<sObject> newList) {
        ServiceRequestTriggerHelper.beforeInsert(newList);
        ServiceRequestTriggerHelper.assignToQueue((List<ServiceRequest__c>) newList); //1.2
        ServiceRequestTriggerHelper.populateTotalPaidAmount((List<ServiceRequest__c>) newList); //1.2
        ServiceRequestTriggerHelper.populateADMPaidAmount((List<ServiceRequest__c>) newList); //1.2
        //  ServiceRequestTriggerHelper.beforeinsertunitcancellation(newList);
        //  
        MBP_DocusignController.populateBrokerOwnerEmail(newList);
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
        List<ServiceRequest__c> srList = (List<ServiceRequest__c>) newList; //1.2
        ServiceRequestTriggerHelper.afterInsert(newList);
        //1.2 start
        Set<Id> srIds = new Set<Id>();
        for (ServiceRequest__c sr : srList) {
            
            srIds.add(sr.Id);
        }
        if (!srIds.isEmpty()) {
            //ServiceRequestTriggerHelper.updateRefundFlagAsync(srIds);
        }
        ServiceRequestTriggerHelper.createDocumentPlaceholders(srList);
        
         Set<Id> salesOrderIds = new Set<Id>();
        for (ServiceRequest__c sr : srList) {
            if (sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
            }
        }
        if (!salesOrderIds.isEmpty()) {
            ServiceRequestTriggerHelper.markCancelUnitOnConsolidationAsync(salesOrderIds);
        }//1.2 end
    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        ServiceRequestTriggerHelper.beforeUpdate(newList,oldList,oldMap);
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) {
        /*  if(isTriggerDisabled){
return;
}*/
        //isTriggerDisabled=true;
        
        ServiceRequestTriggerHelper.afterUpdate(newList,oldMap);
        CDL_SignedSPAFileLinker.runForSRUpdate( (List<ServiceRequest__c>)newList, (Map<Id, ServiceRequest__c>)oldMap);
        ServiceRequestTriggerHelper.recalculateADMChargeOnSellingPriceUpdate((List<ServiceRequest__c>) newList,(Map<Id, ServiceRequest__c>) oldMap);
        ServiceRequestTriggerHelper.autoCloseStep4OnCEOApproval((List<ServiceRequest__c>) newList,(Map<Id, ServiceRequest__c>) oldMap); //1.2
        ServiceRequestTriggerHelper.generatePDFOnApproval((List<ServiceRequest__c>) newList,(Map<Id, ServiceRequest__c>) oldMap);  //1.2

    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        
    }
}