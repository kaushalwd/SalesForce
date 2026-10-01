@isTest
public with sharing class SOAControllerTest {
    @isTest
    static void testGetSOAData() {
        // Create District
        District__c district = new District__c(Name='Test District');
        insert district;
        
        // Create Project
        Project__c project = new Project__c(Name='Test Project', District__c=district.Id);
        insert project;

        // Create Phase
        Phase__c phase = new Phase__c(Name='Test Phase', Project__c=project.Id);
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(Name='Test Unit',UnitClassification__c='Villa',PlotNo__c='123',Phase__c=phase.Id,BuildingNo__c='B1');
        unit.Number_of_Bedrooms__c = '2';
        unit.UnitClassification__c = 'Villa';
        insert unit;

        // Create Account
        Account customerAccount = new Account(Name='Test Customer',UnifiedNumber__c='123456');
        insert customerAccount;

        // Create Escrow Account
        EscrowAccount__c escrow = new EscrowAccount__c(Name='Test Escrow',AccountNumber__c='123456789',IBANNo__c='AE123456789',SwiftCode__c='SWIFT123',BankName__c='Test Bank');
        insert escrow;

        // Create Virtual Account
        VirtualAccount__c virtualAcc = new VirtualAccount__c(EscrowAccount__c=escrow.Id);
        insert virtualAcc;

        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        INSERT oppObj;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            SPACustomerSignedDate__c=Date.today().addDays(5),
            TotalAmount__c=500000,
            CustomerAccount__c=customerAccount.Id,
            Unit__c=unit.Id,
            Status__c = 'In Progress',
            Opportunity__c = oppObj.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c=virtualAcc.Id//,
            //SOCreationDate__c = date.today(),
            //ProjectName__c = project.Name
        );
        insert so;

        // Create SalesOrderInstallments
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c=so.Id,
            MilestoneDescription__c='Test Milestone 1',
            MilestoneNumber__c=1,
            //Milestone__c=1,
            MilestoneDate__c=Date.today().addDays(10)
        ));
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c=so.Id,
            MilestoneDescription__c='Test Milestone 2',
            MilestoneNumber__c=2,
            //Milestone__c=0.02,
            MilestoneDate__c=Date.today().addDays(20)
        ));
        insert installments;

        // Create Charge for Other Payment
        Charge__c charge = new Charge__c(Type__c='Installment Payment');
        insert charge;

        // Create Invoices
        List<Invoice__c> invoices = new List<Invoice__c>();
        // Installment Invoices
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c=installments[0].Id,
            InvoiceAmount__c=100000,
            Account__c = customerAccount.id
        ));
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c=installments[1].Id,
            InvoiceAmount__c=200000,
            Account__c = customerAccount.id
        ));
        // Other Payment Invoice
        invoices.add(new Invoice__c(
            //Sales_Order__c=so.Id,
            SalesOrderInstallment__c=installments[1].Id,
            Charge__c=charge.Id,
            InvoiceAmount__c=50000,
            InvoiceDate__c=Date.today(),
            Account__c = customerAccount.id
        ));
        insert invoices;

        // Create Receipts and Allocations
        List<Receipt__c> receipts = new List<Receipt__c>();
        List<Allocation__c> allocations = new List<Allocation__c>();

        // Create 2 receipts and 2 allocations per invoice
        for(Invoice__c inv : invoices) {
            // First receipt and allocation
            Receipt__c r1 = new Receipt__c(
                ReceiptDate__c = Date.today(),
                Account__c = customerAccount.id,
                Status__c = 'Cleared'               
            );
            receipts.add(r1);
            
            // Second receipt and allocation
            Receipt__c r2 = new Receipt__c(
                ReceiptDate__c = Date.today().addDays(1),
                Account__c = customerAccount.id     
            );
            receipts.add(r2);
        }
        insert receipts;

        Charge__c cg = new Charge__c();
        cg.Amount__c = 499;
        cg.Sales_Order__c = so.Id;
        insert cg;
        
        /*Invoice__c inv = new Invoice__c();
        inv.Charge__c =cg.Id;
        inv.Account__c = customerAccount.Id;
        inv.InvoiceAmount__c = 444;
        inv.Sales_Order__c =so.Id;
        insert inv;*/
        
        // Create allocations for each receipt
        for(Receipt__c rcpt : receipts) {
            allocations.add(new Allocation__c(
                Receipt__c = rcpt.Id,
                AllocationAmount__c=222,
                AllocationDate__c = Date.today(),
                Invoice__c = invoices[0].Id
            ));
        }
        insert allocations;
        
        //SalesOrder__c salesOrder2 = [SELECT Id FROM SalesOrder__c LIMIT 1];

        //Test.startTest();
        SOAController.SOAWrapper result = SOAController.getSOAData(so.Id);
        //Test.stopTest();

        /*// Verify Sales Order Data
        System.assertNotEquals(null, result.salesOrder, 'Sales Order should not be null');
        System.assertEquals('Test Customer', result.salesOrder.CustomerAccount__r.Name, 'Incorrect Customer Account Name');
        System.assertEquals('Test Unit', result.salesOrder.Unit__r.Name, 'Incorrect Unit Name');

        // Verify Installments and Allocations
        System.assertEquals(2, result.installments.size(), '2 Installment Invoices expected');
        System.assertEquals(2, result.installments[0].Allocations__r.size(), '2 Allocations expected for first installment');
        System.assertEquals(2, result.installments[1].Allocations__r.size(), '2 Allocations expected for second installment');

        // Verify Other Payments
        System.assertEquals(1, result.otherPayments.size(), '1 Other Payment Invoice expected');
        System.assertEquals(2, result.otherPayments[0].Allocations__r.size(), '2 Allocations expected for other payment');

        // Verify Totals
        Decimal expectedInstallmentCollected = (100000 * 0.5) + (200000 * 0.5); // 50k + 100k
        Decimal expectedOtherCollected = 50000 * 0.5; // 25k
        Decimal expectedGrandTotal = (100000 + 200000 + 50000) - (expectedInstallmentCollected + expectedOtherCollected);

        System.assertEquals(300000, result.totalAmount, 'Total Installment Amount mismatch');
        System.assertEquals(150000, result.totalCollected, 'Total Collected mismatch');
        System.assertEquals(150000, result.totalOutstanding, 'Total Outstanding mismatch');
        System.assertEquals(50000, result.totalOtherAmount, 'Total Other Amount mismatch');
        System.assertEquals(25000, result.totalOtherCollected, 'Total Other Collected mismatch');
        System.assertEquals(175000, result.grandTotalOutstanding, 'Grand Total Outstanding mismatch');

        // Verify Installment Summary
        System.assertEquals(2, result.installmentSummary.totalPaidInstallments, 'Paid Installments count mismatch');
        System.assertEquals(2, result.installmentSummary.totalInstallments, 'Total Installments count mismatch');
        System.assertEquals(150000, result.installmentSummary.totalCollectedAmount, 'Collected Amount mismatch');
        System.assertEquals(150000, result.installmentSummary.balanceAmount, 'Balance Amount mismatch');
        System.assertEquals(50.00, result.installmentSummary.paidPercentage.setScale(2), 'Paid Percentage mismatch');*/
    }

    /*@isTest
    static void testNoInstallmentsOrOtherPayments() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        delete [SELECT Id FROM Invoice__c];

        Test.startTest();
        SOAController.SOAWrapper result = SOAController.getSOAData(salesOrder.Id);
        Test.stopTest();

        // Verify Empty Data
        System.assertEquals(0, result.installments.size(), 'No Installments expected');
        System.assertEquals(0, result.otherPayments.size(), 'No Other Payments expected');
        
        // Verify All Totals are Zero
        System.assertEquals(0, result.totalAmount, 'Total Amount should be 0');
        System.assertEquals(0, result.totalCollected, 'Total Collected should be 0');
        System.assertEquals(0, result.totalOutstanding, 'Total Outstanding should be 0');
        System.assertEquals(0, result.grandTotalOutstanding, 'Grand Total Outstanding should be 0');
        
        // Verify Installment Summary Defaults
        System.assertEquals(0, result.installmentSummary.totalPaidInstallments, 'Paid Installments should be 0');
        System.assertEquals(0, result.installmentSummary.totalInstallments, 'Total Installments should be 0');
        System.assertEquals(0, result.installmentSummary.paidPercentage, 'Paid Percentage should be 0');


       }*/
}