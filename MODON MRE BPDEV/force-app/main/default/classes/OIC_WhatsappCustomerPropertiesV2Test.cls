@isTest
private class OIC_WhatsappCustomerPropertiesV2Test {

    @testSetup
    static void setupTestData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test.pdf@outlook.com';
         accountObj.FirstName = 'First';
         accountObj.LastName = 'Last';
         accountObj.OraclePartyId__c ='22212';
         accountObj.PersonMobilePhone = '+971501234567';
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
        
        Invoice__c inv2 = new Invoice__c(
                Sales_Order__c = testSO.Id,  // Lookup field to the installment
                InvoiceAmount__c = 300000,
                Account__c = accountObj.id,
                Is_ADM_Fees_and_Dari_charges__c = true,
				InvoiceDate__c = System.today()
            );
        insert inv2;
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
        
        // 3. Create Documents__c
        Documents__c doc = new Documents__c(
            SalesOrder__c = testSO.Id,
            Status__c = 'Uploaded',
            Name = 'Signed SPA (Modon)'
        );
        insert doc;
    }

    @isTest
    static void testFindPropertyDetails_Success() {
        // Setup RestContext
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPIV2';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971501234567'); // Testing '+' auto-append

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerPropertiesV2.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_MissingParam() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPIV2';
        req.httpMethod = 'GET'; // Intentionally missing params

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerPropertiesV2.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_NoData() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WhatsappCustomerPropertiesAPIV2';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '+971000000000'); // Unused Number

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerPropertiesV2.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testFindPropertyDetails_Exception() {
        // Passing null for RestContext to simulate a null pointer exception in the try block
        RestContext.request = null; 
        RestContext.response = new RestResponse();

        Test.startTest();
        OIC_WhatsappCustomerPropertiesV2.findPropertyDetails();
        Test.stopTest();
    }
}