/**********************************************************************************************************************
* Name               : OIC_ManageRevenueRecognitionSch
* Description        : Batch class to resend unsuccessful Revenue Recognition Schedule 
* Created By         : Active minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj				05 May 2026       Initial Draft
***********************************************************************************************************************/
global class OIC_ManageRevenueRecognitionSch implements Schedulable{    
       
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendRevenueRecognition');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageRevenueRecognitionBatch(null,null,null), Integer.valueOf(scopeStr));
    } 

}