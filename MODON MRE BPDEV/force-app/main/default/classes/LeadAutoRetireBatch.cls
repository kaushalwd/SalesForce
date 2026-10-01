/**********************************************************************************************************************
* Name               : LeadAutoRetireBatch                                                        
* Description        : Batch class to auto-retire Leads that have not been modified
        *              in MORE THAN N days (configured via Custom Label).
        *              Sets Status = 'Retired' on qualifying records.
* Usage              :                                                   
* Created By         : Modon IT
* Schedule			 : Schedule example (run daily at 2 AM): System.schedule('Lead Auto-Retire Daily', '0 0 2 * * ?', new LeadAutoRetireBatch());
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           										      Initial Draft   
******************************************************************************************************************/
public with sharing class LeadAutoRetireBatch
implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    // ─── Constants ────────────────────────────────────────────────────────────
    @TestVisible private static final String  RETIRED_STATUS     = 'Retired';
    @TestVisible private static final Integer DEFAULT_BATCH_SIZE = 200;
    @TestVisible private static DateTime cutoffDateOverride = null;
    private static final String EXCLUDED_SOURCE_ENTITY = 'Modon - Egypt';
    
    // ─── Custom Label Reader ──────────────────────────────────────────────────
    @TestVisible private static Integer getDaysThreshold() {
        try {
            Integer days = Integer.valueOf(Label.Lead_Auto_Retire_Days);
            if (days == null || days <= 0) {
                throw new LeadAutoRetireBatchException(
                    'Custom Label Lead_Auto_Retire_Days must be a positive integer.'
                );
            }
            return days;
        } catch (Exception e) {
            throw new LeadAutoRetireBatchException(
                'Invalid value in Custom Label Lead_Auto_Retire_Days: '
                + e.getMessage()
            );
        }
    }
    
    // ─── Custom Exception ─────────────────────────────────────────────────────
    public class LeadAutoRetireBatchException extends Exception {}
    
    // ─── State (Database.Stateful) ────────────────────────────────────────────
    @TestVisible private Integer      recordsProcessed = 0;
    @TestVisible private Integer      recordsFailed    = 0;
    @TestVisible private List<String> errorMessages    = new List<String>();
    
    // ─── Schedulable ──────────────────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeadAutoRetireBatch(), DEFAULT_BATCH_SIZE);
    }
    
    // ─── Batchable: start ─────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        Integer getDays = getDaysThreshold();
        
        DateTime cutoffDate = cutoffDateOverride != null
            ? cutoffDateOverride
            : DateTime.now().addDays(-getDays);
        
        return Database.getQueryLocator([
            SELECT Id, Status, LastModifiedDate, Source_Entity__c
            FROM   Lead
            WHERE  IsConverted        = FALSE
            AND    Status             != :RETIRED_STATUS
            AND    LastModifiedDate   <  :cutoffDate
            AND    Source_Entity__c   != :EXCLUDED_SOURCE_ENTITY
        ]);
    }
    
    // ─── Batchable: execute ───────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        List<Lead> leadsToUpdate = new List<Lead>();
        Integer getDays = getDaysThreshold();
        system.debug('scope--'+scope);
        
        for (Lead ld : scope) {
            leadsToUpdate.add(new Lead(
                Id     = ld.Id,
                Status = RETIRED_STATUS,
                RetiredReason__c=Constants.LEAD_RETIRED_REASON_RETIRED,
                RetirementComments__c = 'Lead automatically retired by the system due to ' + getDays + ' days inactivity'
            ));
        }
        
        if (leadsToUpdate.isEmpty()) {
            return;
        }
        
        Database.SaveResult[] results = Database.update(leadsToUpdate, false);
        
        system.debug('results--'+results);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                recordsProcessed++;
            } else {
                recordsFailed++;
                for (Database.Error err : results[i].getErrors()) {
                    errorMessages.add(
                        'Lead Id: ' + leadsToUpdate[i].Id +
                        ' | Error: ' + err.getMessage()
                    );
                }
            }
        }
    }
    
    // ─── Batchable: finish ────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        String subject = recordsFailed > 0
            ? '[WARNING] Lead Auto-Retire Batch Completed with Errors'
            : '[SUCCESS] Lead Auto-Retire Batch Completed';
        
        String body =
            'Batch Job Id    : ' + bc.getJobId()    + '\n' +
            'Days Threshold  : ' + getDaysThreshold() + '\n' +
            'Records Updated : ' + recordsProcessed + '\n' +
            'Records Failed  : ' + recordsFailed    + '\n';
        
        if (!errorMessages.isEmpty()) {
            body += '\nError Details:\n' + String.join(errorMessages, '\n');
        }
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{'prateek.bansal@modon.com'});
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
    }
}