/**
*Name               : LeadLoqateValidationQueueable                                                        
* Description        : This class is used  call the API from the Leadtriggerhandler 
* Usage              :This class is used  call the API from the Leadtriggerhandle                                                 
* Created By         :Arvind Kesharwani
 *Version       Author                          Date            Comment   
 1.0            Arvind Kesharwani             04/20/2026       Intial Dreaft


 * LeadLoqateValidationQueueable
 * Queued from LeadTriggerHandler.afterInsertMethod for Self Generated
 * and 800-Modon leads.
 * Starts LoqateVerificationBatch with size 1 so each lead is processed
 * individually — avoids callout limits and isolates failures per record.
 */
public class LeadLoqateValidationQueueable implements Queueable {

    private List<Id> leadIds;

    public LeadLoqateValidationQueueable(List<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext ctx) {
        if (leadIds == null || leadIds.isEmpty()) return;

        // SOQL injection fix: pass Id set to batch (no SOQL fragment assembly).
        Database.executeBatch(new LoqateVerificationBatch('Lead', new Set<Id>(leadIds)), 1);
    }
}