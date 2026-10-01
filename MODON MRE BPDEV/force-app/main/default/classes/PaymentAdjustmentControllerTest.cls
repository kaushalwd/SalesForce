@isTest
private class PaymentAdjustmentControllerTest {

    // Shared base data lives in its own governor-limit window (testSetup), separate from
    // each test method's pre-startTest code and from the Test.startTest()/stopTest() window.
    // Splitting the cascade-heavy inserts across these windows avoids "Too many SOQL queries: 101"
    // caused by SalesOrder__c automation firing repeatedly as Receipt/Allocation records are inserted.
    @testSetup static void setupData() {
        Account acc = new Account(FirstName = 'First', LastName = 'Last', PersonEmail = 'test@person.com');
        insert acc;

        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;

        Unit__c unit = new Unit__c(Name = 'Unit A', Phase__c = phase.Id, PlotNo__c = '101', UnitClassification__c = 'Villa', Type__c = 'G+1', Number_of_Bedrooms__c = '2');
        insert unit;
    }

    @isTest static void testReceiptPathFull() {
        TriggerControl.bypassReceiptTrigger = true;
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Unit__c unit = [SELECT Id, Phase__r.Project__r.Name FROM Unit__c LIMIT 1];
        System.debug('Unit Project Name: ' + unit.Phase__r.Project__r.Name);

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Down payment collected', TotalAmount__c = 50000, Unit__c = unit.Id);
        insert so;

        // Re-query SalesOrder to verify formula field is populated
        so = [SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id = :so.Id];
        System.debug('SalesOrder ProjectName__c: ' + so.ProjectName__c);

        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1,
                                                                       PaymentStatus__c = 'Partially Paid', InstallmentAmount__c = 10000);
        insert soi1;

        SalesOrderInstallments__c soi2 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 2,
                                                                       PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000);
        insert soi2;

        Invoice__c inv = new Invoice__c(Sales_Order__c = so.Id, SalesOrderInstallment__c = soi1.Id,
                                        InvoiceAmount__c = 5000, Account__c = acc.Id);
        insert inv;

        Receipt__c rec = new Receipt__c(Account__c = acc.Id, SalesOrder__c = so.Id, SalesOrderInstallment__c = soi1.Id,
                                        Modeofpayment__c = 'Payment Adjustment', Status__c = 'Approved', TotalAmount__c = 5000);
        insert rec;

        Allocation__c alloc = new Allocation__c(Receipt__c = rec.Id, Status__c = 'Applied',
                                                AllocationAmount__c = 5000, ApprovedReceiptAmount__c = 5000, Invoice__c = inv.Id);
        insert alloc;

        // Only the methods under test run inside startTest/stopTest, so they get a fresh
        // governor-limit window instead of sharing one with the setup cascade above.
        Test.startTest();
        PaymentAdjustmentController.createPayment(rec.Id, soi2.Id, 500);
        List<PaymentAdjustmentController.salesOrderOptions> receiptResult = PaymentAdjustmentController.getRelatedSalesOrder(rec.Id);
        System.debug('getRelatedSalesOrder result (Receipt): ' + receiptResult);
        PaymentAdjustmentController.getRelatedSOInstallments(rec.Id, null);
        PaymentAdjustmentController.getSOInstallmentsDetails(rec.Id, so.Id);
        Test.stopTest();
    }

    @isTest static void testInvoicePathFull() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Unit__c unit = [SELECT Id, Phase__r.Project__r.Name FROM Unit__c LIMIT 1];
        System.debug('Unit Project Name: ' + unit.Phase__r.Project__r.Name);

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Down payment collected', TotalAmount__c = 50000, Unit__c = unit.Id);
        insert so;

        // Re-query SalesOrder
        so = [SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id = :so.Id];
        System.debug('SalesOrder ProjectName__c: ' + so.ProjectName__c);

        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1, PaymentStatus__c = 'Partially Paid', InstallmentAmount__c = 10000);
        insert soi1;

        Invoice__c inv = new Invoice__c(Sales_Order__c = so.Id, SalesOrderInstallment__c = soi1.Id, InvoiceAmount__c = 5000, Account__c = acc.Id);
        insert inv;

        Test.startTest();
        PaymentAdjustmentController.createPayment(inv.Id, soi1.Id, 500);
        List<PaymentAdjustmentController.salesOrderOptions> invoiceResult = PaymentAdjustmentController.getRelatedSalesOrder(inv.Id);
        System.debug('getRelatedSalesOrder result (Invoice): ' + invoiceResult);
        PaymentAdjustmentController.getRelatedSOInstallments(inv.Id, null);
        PaymentAdjustmentController.getSOInstallmentsDetails(inv.Id, so.Id);
        Test.stopTest();
    }
}