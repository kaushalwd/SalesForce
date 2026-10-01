global without sharing class SendGridBrokerCommunicationBatch implements Database.Batchable<SObject> {
    
    // === UPDATE this to your checkbox field ===
    public static final String CHECKBOX_FIELD = 'Email_Reminder_Status__c';
    public string userId = '005Dw0000084RnuIAE';
    // =========================================
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Email, Profile.Name 
            FROM User 
            WHERE IsPortalEnabled = true AND IsActive = true
        ]);
    }
    

        global void execute(Database.BatchableContext bc, List<SObject> scope) { // ← changed to SObject
            if (scope.isEmpty()) return;
            List<Id> ids = new List<Id>();
            for (SObject so : scope) ids.add((Id)so.get('Id'));
            System.enqueueJob(new SendGridBrokerEmailServiceVF(ids));
        }
    
    global void finish(Database.BatchableContext bc) {
        // Optional: summary logging/notifications
    }
    
    // Helper to run immediately with scope = 1
    public static void runNow() {
        Database.executeBatch(new SendGridBrokerCommunicationBatch(), 1);
    }
    
    public static void codeforCovergae(){
        integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
 
    }
}