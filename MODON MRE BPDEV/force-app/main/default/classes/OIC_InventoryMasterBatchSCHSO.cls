/**********************************************************************************************************************
* Name               : OIC_InventoryMasterBatchSCH
* Description        : Batch class to resend unsuccessful Inventory Master Batch Schedule 
* Created By         : Active minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj				05 May 2026       Initial Draft
***********************************************************************************************************************/
global class OIC_InventoryMasterBatchSCHSO implements Schedulable{    
       
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendInventoryMaster');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_InventoryMasterBatch('SalesOrder',null,null,null), Integer.valueOf(scopeStr));
    } 

}