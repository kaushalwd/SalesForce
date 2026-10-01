@isTest
public class CommissionLineItemBatchTest {
    @isTest
    static void testBatchExecute() {
        List<Commission_Line__c> testLines = new List<Commission_Line__c>();
        for (Integer i = 0; i < 3; i++) {
            Commission_Line__c line = new Commission_Line__c();
            line.Commission_Line_Item_Is_Created__c = false; 
            line.Commission_Line_Type__c = 'Internal';       
            line.Direct_Commission_Amount__c = 100;
            line.Commission_Amount__c = 100;
            line.Indirect_Commission_Amount__c = 0;
            line.Commission_Type__c = 'Indirect';
            testLines.add(line);
        }
        insert testLines;

        Test.startTest();
        CommissionLineItemBatch batch = new CommissionLineItemBatch();
        Database.executeBatch(batch); 
        Test.stopTest();

        List<Commission_Line__c> result = [
            SELECT Id, Commission_Line_Item_Is_Created__c, Commission_Line_Type__c
            FROM Commission_Line__c
            WHERE Commission_Line_Type__c = 'Internal'
        ];
        System.assertEquals(3, result.size());
    }
    @isTest public static void schedulableTestClass(){
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('CommissionLineItemBatch', cronExp, new CommissionLineItemBatch());
        Test.stopTest();
    }
}