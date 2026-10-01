/**********************************************************************************************************************
* Name               : OIC_InventoryMasterBatchSCHSOTest
* Description        : Batch class to resend unsuccessful Inventory Master Schedule for Sales order
* Created By         : Active minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj				05 May 2026       Initial Draft
***********************************************************************************************************************/
@isTest
public class OIC_InventoryMasterBatchSCHSOTest {

    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_InventoryMasterBatchSCHSO invUnitsch= new OIC_InventoryMasterBatchSCHSO();
        System.schedule('OIC_InventoryMasterBatch',CRON_EXP, invUnitsch);
    }
}