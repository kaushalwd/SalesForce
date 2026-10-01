/**
* Name              : AccountMergeQueueable                                            
* Description       : Handles account merging with dynamic metadata-driven custom object reparenting.
* Created By        : Arvind Kesharwani
* Date              : 04/29/2026
*/
public class AccountMergeQueueable implements Queueable {
    
    private final Id masterAccountId;
    private final List<Id> victimAccountIds;
    
    public AccountMergeQueueable(Id masterId, List<Id> victimIds) {
        this.masterAccountId  = masterId;
        this.victimAccountIds = victimIds;
    }
    
    public void execute(QueueableContext ctx) {
        if (victimAccountIds == null || victimAccountIds.isEmpty()) return;
        
        try {
            reparentStandardObjects();
            reparentCustomObjects();      // Dynamic via Merge_Config__mdt
            reparentSpecialObjects();     // SalesOrder__c & Contact
            
            // Mark victims as merged
            List<Account> toMark = new List<Account>();
            for (Id vid : victimAccountIds) {
                toMark.add(new Account(
                    Id = vid,
                    Is_Merged__c = true,
                    Master_Account__c = masterAccountId,
                    Eligible_For_Merge__c = false,
                    Merge_Status__c = 'Merged',
                    Merge_Error__c = null
                ));
            }
            update toMark;
            
            // Mark master as merged
            update new Account(Id = masterAccountId, Merge_Status__c = 'Merged', Merge_Error__c = null);
            
        } catch (Exception e) {
            handleError(e);
            throw e;
        }
    }
    
    // Standard objects handled manually for performance and specific field naming
    private void reparentStandardObjects() {
        List<SObject> standardRecords = new List<SObject>();
        
        // Opportunity
        List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE AccountId IN :victimAccountIds];
        for (Opportunity o : opps) { o.AccountId = masterAccountId; standardRecords.add(o); }
        
        // Case
        List<Case> cases = [SELECT Id, AccountId FROM Case WHERE AccountId IN :victimAccountIds];
        for (Case c : cases) { c.AccountId = masterAccountId; standardRecords.add(c); }
        
        // Activities
        List<Task> tasks = [SELECT Id, WhatId FROM Task WHERE WhatId IN :victimAccountIds];
        for (Task t : tasks) { t.WhatId = masterAccountId; standardRecords.add(t); }
        
        List<Event> events = [SELECT Id, WhatId FROM Event WHERE WhatId IN :victimAccountIds];
        for (Event e : events) { e.WhatId = masterAccountId; standardRecords.add(e); }
        
        if (!standardRecords.isEmpty()) Database.update(standardRecords, false);
    }
    
    // Dynamic processing of custom objects via Merge_Config__mdt
    private void reparentCustomObjects() {
        Map<String, Merge_Config__mdt> configs = Merge_Config__mdt.getAll();
        
        for (Merge_Config__mdt config : configs.values()) {
            String query = 'SELECT Id, ' + config.Lookup_Field_Name__c + 
                ' FROM ' + config.Object_API_Name__c + 
                ' WHERE ' + config.Lookup_Field_Name__c + ' IN :victimAccountIds';
            
            List<SObject> records = Database.query(query);
            if (!records.isEmpty()) {
                for (SObject obj : records) {
                    obj.put(config.Lookup_Field_Name__c, masterAccountId);
                }
                Database.update(records, false);
            }
        }
    }
    
    // Special handling for Sales Orders and Contacts
    private void reparentSpecialObjects() {
        // 1. Sales Order
        List<SalesOrder__c> orders = [SELECT Id, CustomerAccount__c, PrimaryContact__c FROM SalesOrder__c WHERE CustomerAccount__c IN :victimAccountIds];
        Account masterAcc = [SELECT Id, PersonContactId FROM Account WHERE Id = :masterAccountId LIMIT 1];
        for(SalesOrder__c so : orders) {
            so.CustomerAccount__c = masterAccountId;
            if(masterAcc.PersonContactId != null) so.PrimaryContact__c = masterAcc.PersonContactId;
        }
        if(!orders.isEmpty()) Database.update(orders, false);
        
        // ── 2. Contact ────────────────────────────────────────────────
        List<Contact> cons = [
            SELECT Id, AccountId, Prospect_Account__c
            FROM   Contact
            WHERE  AccountId           IN :victimAccountIds
            OR     Prospect_Account__c IN :victimAccountIds
        ];
        
        for (Contact con : cons) {
            // List.contains(null) = false → safe, but explicit null check is clearer
            if (con.AccountId != null
                && victimAccountIds.contains(con.AccountId)) {
                    con.AccountId = masterAccountId;
                }
            if (con.Prospect_Account__c != null
                && victimAccountIds.contains(con.Prospect_Account__c)) {
                    con.Prospect_Account__c = masterAccountId;
                }
        }
        
        if (!cons.isEmpty()) Database.update(cons, false);  // guard added
    }
    
    private void handleError(Exception e) {
        String errDetail = 'Message: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString();
        try {
            update new Account(Id = masterAccountId, Merge_Status__c = 'Error', Merge_Error__c = errDetail.left(32000));
        } catch (Exception suppressedEx) {
            System.debug('Critical logging failure: ' + suppressedEx.getMessage());
        }
    }
}