/**********************************************************************************************************************
* Name               : SPAReminderQueueableCallout                                                        
* Description        : This class is used to send the whatsapp communication
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
public class SPAReminderQueueableCallout implements Queueable, Database.AllowsCallouts {
	
    private List<SPAReminders__c> lst_SPAWhatsapp;

    public SPAReminderQueueableCallout(List<SPAReminders__c> lst_SPAWhatsapp) {
        this.lst_SPAWhatsapp = lst_SPAWhatsapp;
    }

    public void execute(QueueableContext qc) {
        SPARemindersTriggerHelper.sendWhatsappMessageOICAPINoBatch(lst_SPAWhatsapp);
    }
}