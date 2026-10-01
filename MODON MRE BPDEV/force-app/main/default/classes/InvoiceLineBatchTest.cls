@isTest
public class InvoiceLineBatchTest {
    
    @isTest
    static void testBatchWithMonthParam() {
        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'Completed'
        );
        insert so;

        Commission_Line__c cl = new Commission_Line__c(
            Sales_Order__c = so.Id,
            External_Total_Commission_Amount__c = 1000
        );
        insert cl;

        List<Commission_Line_Item__c> cliList = new List<Commission_Line_Item__c>();
        for (Integer i = 0; i < 3; i++) {
            cliList.add(new Commission_Line_Item__c(
                Commission_Line__c = cl.Id,
                Commission_Type__c = 'External',
                Commission_Payout_Amount__c = 0,
                Commission_Month__c = 'September'
            ));
        }
        insert cliList;

        Test.startTest();
        InvoiceLineBatch batchWithMonth = new InvoiceLineBatch('September');
        Database.executeBatch(batchWithMonth);

        InvoiceLineBatch batchWithoutMonth = new InvoiceLineBatch(null);
        Database.executeBatch(batchWithoutMonth);
        Test.stopTest();
    }
    @isTest public static void schedulableTestClass(){
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('InvoiceLineBatch', cronExp, new InvoiceLineBatch(null));
        Test.stopTest();
    }
}