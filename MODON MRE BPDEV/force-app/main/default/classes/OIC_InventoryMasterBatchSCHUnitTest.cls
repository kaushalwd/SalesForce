/**********************************************************************************************************************
* Name               : OIC_InventoryMasterBatchSCHUnitTest
* Description        : Batch class to resend unsuccessful Inventory Master Schedule for Unit
* Created By         : Active minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj				05 May 2026       Initial Draft
***********************************************************************************************************************/
@isTest
public class OIC_InventoryMasterBatchSCHUnitTest {

    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_InventoryMasterBatchSCHUnit invUnitsch= new OIC_InventoryMasterBatchSCHUnit();
        System.schedule('OIC_InventoryMasterBatch',CRON_EXP, invUnitsch);
    }
}