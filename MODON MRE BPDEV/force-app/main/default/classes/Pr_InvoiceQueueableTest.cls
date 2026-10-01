@isTest
public class Pr_InvoiceQueueableTest {

   @TestSetup
   static void makeData(){

        // Person Account
        Schema.RecordTypeInfo recordTypeInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');

        String recordTypeId = recordTypeInfo.getRecordTypeId();

        Account accountObj = new Account(
            RecordTypeId = recordTypeId,
            FirstName = 'First',
            LastName = 'Last',
            PersonEmail = 'test@test.com'
        );
        insert accountObj;

        // Unit
        Unit__c unitObj = new Unit__c(
            Name = 'Test Unit',
            BasePrice__c = 1000,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unitObj;

        // Sales Order
        SalesOrder__c salesOrderObj = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = unitObj.Id,
            CustomerAccount__c = accountObj.Id,
            TotalAmount__c = 20000
        );
        insert salesOrderObj;

        SalesOrderInstallments__c soInstallmentObj =
            new SalesOrderInstallments__c(
                SalesOrder__c = salesOrderObj.Id,
                Milestone__c = 1,
                MilestoneNumber__c = 1
            );
        insert soInstallmentObj;

        Charge__c admCharge = new Charge__c(
            Name = 'ADM Charge',
            Type__c = 'ADM & Dari Fee'
        );

        Charge__c modonCharge = new Charge__c(
            Name = 'Modon Charge',
            Type__c = 'Modon Fee'
        );

        insert new List<Charge__c>{ admCharge, modonCharge };

        Invoice__c invoiceObj1 = new Invoice__c(
            Sales_Order__c = salesOrderObj.Id,
            InvoiceAmount__c = 1000,
            Account__c = accountObj.Id,
            Is_ADM_Fees_and_Dari_charges__c = true,
            Charge__c = admCharge.Id
        );
        insert invoiceObj1;

        Invoice__c invoiceObj2 = new Invoice__c(
            SalesOrderInstallment__c = soInstallmentObj.Id,
            InvoiceAmount__c = 1000,
            Account__c = accountObj.Id,
            Charge__c = modonCharge.Id
        );
        insert invoiceObj2;
   }

   @isTest
   static void testPrInvoiceQueueable() {

        SalesOrder__c soObj = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Set<String> soIdSet = new Set<String>{ soObj.Id };

        Test.startTest();

        System.enqueueJob(new Pr_InvoiceQueueable(soIdSet));

        Test.stopTest();

}
}