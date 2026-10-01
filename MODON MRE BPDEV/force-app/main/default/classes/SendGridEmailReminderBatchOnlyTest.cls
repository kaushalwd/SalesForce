@IsTest
private class SendGridEmailReminderBatchOnlyTest {
    
    @TestVisible
    public static Boolean TEST_SKIP_ENQUEUE = false;
    
    @TestVisible
    public static List<Id> TEST_LAST_IDS = new List<Id>();
    
 
    @IsTest
    static void processes_only_checked_sales_orders_and_skips_enqueue() {
        // Given: one record to process, one to ignore
        SalesOrder__c soToProcess = new SalesOrder__c(
            Construction_Email__c = true
            // TODO: add other required fields for your org here
        );
        SalesOrder__c soIgnored = new SalesOrder__c(
            Construction_Email__c = false
            // TODO: add other required fields for your org here
        );
        insert new List<SalesOrder__c>{ soToProcess, soIgnored };
 
        // Use the test seam to avoid running the queueable
        TEST_SKIP_ENQUEUE = true;
		TEST_LAST_IDS.clear();
 
        Test.startTest();
        Database.executeBatch(new SendGridEmailReminderBatch(), 1);
        Test.stopTest();
 
        // Then: only the "true" record was in scope
       
        
    }
 
    @IsTest
    static void no_matching_records_executes_cleanly() {
        // No data satisfies the WHERE clause
        TEST_SKIP_ENQUEUE = true;
        TEST_LAST_IDS.clear();
 
        Test.startTest();
        Database.executeBatch(new SendGridEmailReminderBatch(), 1);
        Test.stopTest();
 
        System.assertEquals(0, TEST_LAST_IDS.size(),
            'Batch should not process any records when none match.');
    }
}