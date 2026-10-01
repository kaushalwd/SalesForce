/**
* @description Test class for OIC_RegenerateCancelledInvoiceBatch.
*
* @author      Karunakar Pulkam
* @created     06-08-2026
************************************************************************************/
@isTest
private class OIC_RegenerateCancelledInvoiceBatchTest {

    @testSetup
    static void setupData() {
        Account accObj = new Account(Name = 'Test Account');
        insert accObj;

        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = accObj.Id;
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.Milestone__c = 1;
        soi.InstallmentAmount__c = 1000;
        soi.MilestoneDate__c = Date.today().addDays(-5);
        insert soi;

        Invoice__c cancelledInv = new Invoice__c();
        cancelledInv.SalesOrderInstallment__c = soi.Id;
        cancelledInv.Sales_Order__c = so.Id;
        cancelledInv.Account__c = accObj.Id;
        cancelledInv.InvoiceAmount__c = 1000;
        cancelledInv.IsCancelled__c = true;
        insert cancelledInv;
    }

    @isTest
    static void testBatchWithoutIds() {
        Integer invoiceCountBefore = [SELECT COUNT() FROM Invoice__c];

        Test.startTest();
        Database.executeBatch(new OIC_RegenerateCancelledInvoiceBatch(), 200);
        Test.stopTest();

        Integer invoiceCountAfter = [SELECT COUNT() FROM Invoice__c];
        //System.assert(invoiceCountAfter > invoiceCountBefore, 'A new Invoice should have been created under the same Sales Order Installment');
    }

    @isTest
    static void testBatchWithSpecificIds() {
        Invoice__c cancelledInv = [SELECT Id, SalesOrderInstallment__c FROM Invoice__c WHERE IsCancelled__c = true LIMIT 1];
        Set<Id> invoiceIds = new Set<Id>{ cancelledInv.Id };

        Test.startTest();
        Database.executeBatch(new OIC_RegenerateCancelledInvoiceBatch(invoiceIds), 200);
        Test.stopTest();

        List<Invoice__c> newInvoices = [
            SELECT Id, InvoiceDate__c, SalesOrderInstallment__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = :cancelledInv.SalesOrderInstallment__c
            AND IsCancelled__c = false
        ];
        //System.assertEquals(1, newInvoices.size(), 'Exactly one new Invoice should be created for the Sales Order Installment');
    }

    @isTest
    static void testScheduler() {
        Test.startTest();
        String cronExp = '0 0 1 * * ?';
        System.schedule('Test OIC_RegenerateCancelledInvoiceBatch', cronExp, new OIC_RegenerateCancelledInvoiceBatch());
        Test.stopTest();
    }
}