/**********************************************************************************************************************
* Name               : AllocationTriggerHandler                                                        
* Description        : This class is used to handle all the Allocation trigger instances
* Usage              : Called from AllocationTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         15 Jan 2024     Initial Draft  
* 2.0			Manoj							 22 Jan 2026	 Update handle UnApplied process and Sync
* 3.0           Dinesh                           15 Jan 2026     Handle Total Received Amount Logic
* 4.0           Shahil Sinha (Horizontal)        27 Nov 2025     Modon Egypt: Added manageCurrencyISOCode in beforeInsert to set currency ISO code for Egypt allocations with multi-currency support
* 5.0           Dinesh                           07 Apr 2026     handle Credit Note Allocation Type
* 5.1           Dinesh                           13 Apr 2026     Added to handle Buffer Amount Clearance Logic to Re-calc ADM & DP
******************************************************************************************************************/
public without sharing class AllocationTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        AllocationTriggerHelper.manageReceiptAmount(newList);
        AllocationTriggerHelper.manageCurrencyISOCode(newList); //v4.0
        ADMWaiverController.handleWaiverAllocation(newList); /**5.0 handle Credit Note Allocation Type **/
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        AllocationTriggerHelper.manageReceiptAmount(newList);
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        ReceiptTriggerHelper.handleAlloccalculateTotalPaid(newList,newMap); /** 3.0 Handle "Total Received Amount" Logic **/
        AllocationTriggerHelper.handleAppliedAmountUpdate(newList,null);/** 5.1 Added to handle Buffer Amount Clearance Logic to Re-calc ADM & DP **/
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        SalesOrderStatusAutomationHelper.handlePDCStatusAllocation(newList,oldMap);
        SalesOrderStatusAutomationHelper.updateMOPfromAllocation(newList,oldMap); 
        AllocationTriggerHelper.handleUnAppliedAmountUpdate(newList, oldMap); // 2.0 handleing UnApplied logic and sync
        ReceiptTriggerHelper.handleAlloccalculateTotalPaid(newList,newMap); /** 3.0 Handle "Total Received Amount" Logic **/
        AllocationTriggerHelper.handleAppliedAmountUpdate(newList, oldMap); /** 5.1 Added to handle Buffer Amount Clearance Logic to Re-calc ADM & DP **/
    }
}