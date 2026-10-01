/**********************************************************************************************************************
* Name               : OIC_ManageRevenueRecognitionSch
* Description        : Batch class to resend unsuccessful Revenue Recognition Schedule 
* Created By         : Active minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj				05 May 2026       Initial Draft
***********************************************************************************************************************/
@isTest
public class OIC_ManageRevenueRecognitionSchTest {

    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageRevenueRecognitionSch RRsch= new OIC_ManageRevenueRecognitionSch();
        System.schedule('OIC_ManageRevenueRecognitionSch',CRON_EXP, RRsch);
    }
}