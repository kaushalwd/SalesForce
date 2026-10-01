/**********************************************************************************************************************
* Name               : SPAReminderCaseBatchScheduler                                                        
* Description        : This class is used to create a case
* Usage              : Scheduler class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global class SPAReminderCaseBatchScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
           	Id jobId = Database.executeBatch(new SPAReminderCaseBatchJob(), 1);
			System.debug('SPAReminderCaseBatchScheduler >>>>>>>> ' + jobId);
        } else {
            SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse obj_Env = new SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse();
            obj_Env.status = '';
            obj_Env.envelopeId = '';
        }
        
    }
}