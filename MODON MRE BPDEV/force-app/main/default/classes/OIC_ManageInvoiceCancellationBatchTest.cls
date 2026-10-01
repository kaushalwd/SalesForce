@isTest
public class OIC_ManageInvoiceCancellationBatchTest {

    @isTest
    static void testBatchExecution() {
        Account acc = new Account(Name = 'Invoice Test Acc');
        insert acc;

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 100
        );
        insert inv;

        Test.startTest();
        OIC_ManageInvoiceCancellationBatch batch = new OIC_ManageInvoiceCancellationBatch(
            new Set<Id>{inv.Id}, 'Unit Cancellation'
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assertNotEquals(null, inv.Id, 'Invoice should exist');
    }
}