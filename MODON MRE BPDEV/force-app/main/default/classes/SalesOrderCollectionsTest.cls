@isTest
public class SalesOrderCollectionsTest {
 @isTest
    static void testRecalcForSalesOrders() {

        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 10000
        );
        insert so;
        
         Account acc = new Account();
        acc.name = 'test account';
        insert acc;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id
        );
        insert soi;

        Invoice__c inv = new Invoice__c(
            SalesOrderInstallment__c = soi.Id,
            InvoiceAmount__c = 5000,
            Account__c = acc.id
        );
        insert inv;

        Test.startTest();
        SalesOrderCollectionsServiceController.recalcForSalesOrders(
            new Set<Id>{so.Id}
        );
        Test.stopTest();

    }


    @isTest
    static void testRecalcFromInstallments() {

        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 8000
        );
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id
        );
        insert soi;
  Account acc = new Account();
        acc.name = 'test account';
        insert acc;

        Invoice__c inv = new Invoice__c(
            SalesOrderInstallment__c = soi.Id,
            InvoiceAmount__c = 4000,
            Account__c = acc.id
        );
        insert inv;

        Test.startTest();
        SalesOrderCollectionsServiceController.recalcFromInstallments(
            new Set<Id>{soi.Id}
        );
        Test.stopTest();
    }


  /*  @isTest
    static void testRecalcFromFlow() {

        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 15000
        );
        insert so;

        SalesOrderCollectionsServiceController.SalesOrderInput inp =
            new SalesOrderCollectionsServiceController.SalesOrderInput();
        inp.salesOrderId = so.Id;

        Test.startTest();
        SalesOrderCollectionsServiceController.recalcFromFlow(
            new List<SalesOrderCollectionsServiceController.SalesOrderInput>{inp}
        );
        Test.stopTest();
    }*/
}