/**********************************************************************************************************************
* Name               : SPAReminderBatchScheduler                                                        
* Description        : This class is used for SPA Reminders
* Usage              : Scheduler class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global class SPAReminderBatchScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
           	Id jobId = Database.executeBatch(new SPAReminderBatchJob(), 25);
			System.debug('SPAReminderBatchScheduler >>>>>>>> ' + jobId);
        } else {
            SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse obj_Env = new SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse();
            obj_Env.status = '';
            obj_Env.envelopeId = '';
        }        
    }
}