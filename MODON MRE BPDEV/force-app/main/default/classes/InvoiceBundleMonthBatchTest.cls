@isTest
public class InvoiceBundleMonthBatchTest {
    
    @isTest
    static void testBatchWithDateParam() {
        // Prepare test Commission_POT__c records
        List<Commission_POT__c> testRecords = new List<Commission_POT__c>();
        for (Integer i = 0; i < 3; i++) {
           Commission_POT__c pot = new Commission_POT__c(
                User__c = UserInfo.getUserId(), 
                POT_Type__c = 'CCO',
                Commission_Percent__c = 5, 
                Split_Type__c = 'Total Gross Sales Value'
            );
            testRecords.add(pot);
        }
        insert testRecords;
        
        Test.startTest();
        InvoiceBundleMonthBatch batchWithDate = new InvoiceBundleMonthBatch(2025, 9);
        Database.executeBatch(batchWithDate);

        InvoiceBundleMonthBatch batchWithoutDate = new InvoiceBundleMonthBatch(null, null);
        Database.executeBatch(batchWithoutDate);
        Test.stopTest();
    }
    @isTest public static void schedulableTestClass(){
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('InvoiceBundleMonthBatch', cronExp, new InvoiceBundleMonthBatch(null,null));
        Test.stopTest();
    }
}