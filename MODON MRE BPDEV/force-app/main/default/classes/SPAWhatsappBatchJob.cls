/**********************************************************************************************************************
* Name               : SPAWhatsappBatchJob                                                        
* Description        : This class is used to get the status from DocuSign
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global without sharing class SPAWhatsappBatchJob implements Database.Batchable<sObject>,Database.AllowsCallouts {
	
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, Name, EnvelopeId__c, Status__c from SPAWhatsapp__c 
                                                     where Status__c IN ('sent', 'delivered')]);
    }    
   		
    global void execute(Database.BatchableContext BC, List<SPAWhatsapp__c> scope) {
       	Set<String> set_Envelope = new Set<String>();
        for(SPAWhatsapp__c obj_SPAWhatsapp : scope){
        	  set_Envelope.add(obj_SPAWhatsapp.EnvelopeId__c);  
        }
        if(set_Envelope.size() > 0){
        	SPAWhatsappBatchJobQueueable obj_Queueable = new SPAWhatsappBatchJobQueueable(set_Envelope);  
            ID jobId = System.enqueueJob(obj_Queueable);
            System.debug('SPAWhatsappBatchJob >>>>>  jobId  >>>> '+jobId);
        }
        
    }
    global void finish(Database.BatchableContext BC) {}
}