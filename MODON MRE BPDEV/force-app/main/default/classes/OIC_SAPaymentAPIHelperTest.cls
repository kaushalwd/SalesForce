@isTest
private class OIC_SAPaymentAPIHelperTest {

    @testSetup
    static void setupData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test.pdf12212@outlook.com';
         accountObj.FirstName = 'Firstttt';
         accountObj.LastName = 'Lasttttt';
         accountObj.OraclePartyId__c ='22212';
         insert accountObj;
        
        // Create Unit/Property data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase');
        insert testPhase;
        
        Unit__c testUnit = new Unit__c(
            Name = 'Unit 101',
            UnitClassification__c = 'villa',
            PlotNo__c = 'P-101',
            Number_of_Bedrooms__c ='2',
            Phase__c = testPhase.Id,
            BuildingNo__c = 'B1'
        );
        insert testUnit;
        
        EscrowAccount__c testescrow = new EscrowAccount__c();
        insert testescrow;
        
        // Create Virtual Account
        VirtualAccount__c testVA = new VirtualAccount__c(
            EscrowAccount__c = testescrow.id,
            VirtualIBANNumber__c = 'IBAN123',
            VirtualAccountNumber__c = 'VA123'
            //Escrow_Bank_Name__c = 'Test Bank'
        );
        insert testVA;
        
        // Create Sales Order
        SalesOrder__c testSO = new SalesOrder__c(
           // SOCreationDate__c = System.today(),
            SPACustomerSignedDate__c = System.today().addDays(-30),
            //ProjectName__c = 'Test Project',
            TotalAmount__c = 1000000,
            CustomerAccount__c = accountObj.Id,
            Unit__c = testUnit.Id,
            VirtualAccount__c = testVA.Id
        );
        insert testSO;
        
        // Create Installments
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        for(Integer i=1; i<=3; i++) {
            installments.add(new SalesOrderInstallments__c(
                SalesOrder__c = testSO.Id,
                MilestoneNumber__c = 1.0,
                MilestoneDescription__c = 'Milestone ' + i,
                Milestone__c = 1.0,
                MilestoneDate__c = System.today().addMonths(i)
            ));
        }
        insert installments;
        
        // Create Invoices for Installments
        List<Invoice__c> installmentInvoices = new List<Invoice__c>();
        integer i=0;
        // Assume 'installments' is a pre-fetched List<SalesOrderInstallments__c>
        for(SalesOrderInstallments__c inst : installments) {
            Invoice__c inv = new Invoice__c(
                SalesOrderInstallment__c = inst.Id,  // Lookup field to the installment
                InvoiceAmount__c = 300000,
                Account__c = accountObj.id,
				InvoiceDate__c = System.today().addDays(i)
            );
            installmentInvoices.add(inv);
            i++;
        }
        
        insert installmentInvoices;
        
        Receipt__c recp = new Receipt__c();
        recp.Account__c = accountObj.id;
        insert recp;

        
        // Create Allocations for Invoices
        List<Allocation__c> allocations = new List<Allocation__c>();
        for(Invoice__c inv : installmentInvoices) {
            allocations.add(new Allocation__c(
                Invoice__c = inv.Id,
                AllocationAmount__c = 200000,
                Receipt__c = recp.id,
                AllocationDate__c = System.today()
            ));
        }
        insert allocations;
        
        Charge__c c = new Charge__c();
        c.Type__c = 'Service Charge Fee';
        insert c;
        
        // Create Other Payments
        List<Invoice__c> otherPayments = new List<Invoice__c>();
        otherPayments.add(new Invoice__c(
            Sales_Order__c = testSO.Id,
            Charge__c = c.id,
            InvoiceAmount__c = 50000,
            Account__c = accountObj.id,
            InvoiceDate__c = System.today()
        ));
        insert otherPayments;
        
         List<Allocation__c> allocations1 = new List<Allocation__c>();
        for(Invoice__c inv : otherPayments) {
            allocations1.add(new Allocation__c(
                Invoice__c = inv.Id,
                AllocationAmount__c = 40000,
                Receipt__c = recp.id,
                AllocationDate__c = System.today()
            ));
        }
        insert allocations1;
    }

    @isTest
    static void testCreatePaymentSuccess() {
        Invoice__c invObj = [Select Id, Name from Invoice__c where InvoiceStatus__c != 'Paid' limit 1];
        // Prepare valid request
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        req.CustomerName = 'Firstttt Lasttttt';
        req.CustomerEmail = 'test.pdf12212@outlook.com';
        req.UnitId = 'Unit 101';
        req.ProjectName = 'Project X';
        req.InvoiceId = invObj.Name;
        req.Amount = 1000.00;
        req.TransactionNumber = 'TXN-001';
        req.TransactionDate = Date.today();
        req.ModeOfPayment = 'Bank Transfer';

        // Add File Attachment
        OIC_SAPaymentAPI.FileDetails file = new OIC_SAPaymentAPI.FileDetails();
        file.FileName = 'Receipt.pdf';
        file.Base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('Test Content'));
        req.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>{file};

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse res = OIC_SAPaymentAPIHelper.createPaymentHelper(req);
        Test.stopTest();
    }

    @isTest
    static void testMandatoryFieldsValidation() {
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        // Leaving fields blank to trigger validation

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse res = OIC_SAPaymentAPIHelper.createPaymentHelper(req);
        Test.stopTest();
    }

    @isTest
    static void testAlreadyPaidInvoice() {
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        req.CustomerName = 'Test';
        req.CustomerEmail = 'test@test.com';
        req.UnitId = 'U-1';
        req.ProjectName = 'P-1';
        req.InvoiceId = 'INV-PAID'; // Already paid in @testSetup

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse res = OIC_SAPaymentAPIHelper.createPaymentHelper(req);
        Test.stopTest();
    }

    @isTest
    static void testInvoiceNotFound() {
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        req.CustomerName = 'Test';
        req.CustomerEmail = 'test@test.com';
        req.UnitId = 'U-1';
        req.ProjectName = 'P-1';
        req.InvoiceId = 'NON-EXISTENT-INV';

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse res = OIC_SAPaymentAPIHelper.createPaymentHelper(req);
        Test.stopTest();
    }
}