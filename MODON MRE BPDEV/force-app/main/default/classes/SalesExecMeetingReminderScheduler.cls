/**********************************************************************************************************************
* Name               : SalesExecMeetingReminderScheduler                                                        
* Description        : Schedulable class to execute SalesExecMeetingReminderBatch daily
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 04 Sep 2026     Initial draft 
******************************************************************************************************************/
public class SalesExecMeetingReminderScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        SalesExecMeetingReminderBatch batchJob = new SalesExecMeetingReminderBatch();
        Database.executeBatch(batchJob, 200);
    }
}