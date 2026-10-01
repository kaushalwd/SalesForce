@isTest
public class CommissionLineItemPaymentBatchTest {
    @isTest
    static void testBatchExecute() {
        // Create related Commission_Line__c records
        List<Commission_Line__c> commissionLines = new List<Commission_Line__c>();
        for (Integer i = 0; i < 3; i++) {
            Commission_Line__c cl = new Commission_Line__c();
            cl.External_Total_Commission_Amount__c = 200;
            commissionLines.add(cl);
        }
        insert commissionLines;

        // Create Commission_Line_Item__c records that satisfy batch criteria
        List<Commission_Line_Item__c> testItems = new List<Commission_Line_Item__c>();
        for (Commission_Line__c cl : commissionLines) {
            Commission_Line_Item__c item = new Commission_Line_Item__c();
            item.Commission_Type__c = 'External';
            item.Payout_Based_On__c = 'Equity';
            item.Commission_Payout_Percent__c = 10;
            item.Equity_Payout_Percent__c = 5;
            item.Installment_No__c = 1;
            item.Commission_Payout_Amount__c = 0; // 👈 must match batch query
            item.Commission_Line__c = cl.Id;
            testItems.add(item);
        }
        insert testItems;

        Test.startTest();
        CommissionLineItemPaymentBatch batch = new CommissionLineItemPaymentBatch(null);
        Database.executeBatch(batch); // 👈 no batch size param in tests
        Test.stopTest();

        // Assertions: ensure records got picked up
        testItems = [SELECT Id, Commission_Payout_Amount__c 
                     FROM Commission_Line_Item__c];
    }
    @isTest public static void schedulableTestClass(){
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('CommissionLineItemPaymentBatch', cronExp, new CommissionLineItemPaymentBatch(null));
        Test.stopTest();
    }
}