global without sharing class SendGridEmailReminderBatch implements Database.Batchable<SObject> {
    
    // === UPDATE this to your checkbox field ===
    public static final String CHECKBOX_FIELD = 'Construction_Email__c';
    // =========================================
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        String q = 'SELECT Id FROM SalesOrder__c WHERE ' + CHECKBOX_FIELD + ' = true';
        return Database.getQueryLocator(q);
    }
    

        global void execute(Database.BatchableContext bc, List<SObject> scope) { // ← changed to SObject
            if (scope.isEmpty()) return;
            List<Id> ids = new List<Id>();
            for (SObject so : scope) ids.add((Id)so.get('Id'));
            System.enqueueJob(new SendGridEmailServiceVF(ids));
        }
    
    global void finish(Database.BatchableContext bc) {
        // Optional: summary logging/notifications
    }
    
    // Helper to run immediately with scope = 1
    public static void runNow() {
        Database.executeBatch(new SendGridEmailReminderBatch(), 1);
    }
}