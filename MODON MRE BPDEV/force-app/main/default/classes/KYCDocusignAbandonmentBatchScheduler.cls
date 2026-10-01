/**********************************************************************************************************************
* Name               : KYCDocusignAbandonmentBatchScheduler                                                        
* Description        : Scheduler class for KYCDocusignAbandonmentBatchJob
* Usage              : Executed via Scheduled Jobs in Salesforce
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 14 Aug 2026     Initial draft 
******************************************************************************************************************/
public class KYCDocusignAbandonmentBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        Database.executeBatch(batch, 50); // Batch size 50 to avoid any callout limits per execution
    }
}