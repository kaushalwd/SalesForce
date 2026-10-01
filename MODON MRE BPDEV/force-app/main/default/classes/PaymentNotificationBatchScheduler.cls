/**********************************************************************************************************************
* Name               : PaymentNotificationBatchScheduler                                                        
* Description        : This class is used for Payment Notification
* Usage              : Scheduler class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 04 2026     Initial Draft       
******************************************************************************************************************/
global class PaymentNotificationBatchScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
           	Id jobId = Database.executeBatch(new PaymentNotificationBatch(), 1);
			System.debug('PaymentNotificationBatchScheduler >>>>>>>> ' + jobId);
        }         
    }

}