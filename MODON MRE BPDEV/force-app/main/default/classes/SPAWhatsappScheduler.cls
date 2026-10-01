/**********************************************************************************************************************
* Name               : SPAWhatsappScheduler                                                        
* Description        : This class is used to get the status from DocuSign
* Usage              : Scheduler class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global class SPAWhatsappScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
           	Id jobId = Database.executeBatch(new SPAWhatsappBatchJob(), 25);
			System.debug('SPAWhatsappScheduler >>>>>>>> ' + jobId);
        } else {
            SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse obj_Env = new SPAWhatsappBatchJobQueueable.DocuSignEnvelopeResponse();
            obj_Env.status = '';
            obj_Env.envelopeId = '';
        }
        
    }
}