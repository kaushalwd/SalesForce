@isTest
private class OIC_SAUploadDocumentAPITest {

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
        // 2. Create the parent Document record
        Documents__c doc = new Documents__c(
            Name = 'Passport Copy',
            SalesOrder__c = testSO.Id,
            Status__c = 'Pending Upload'
        );
        insert doc;
    }

    @isTest
    static void testUploadDocumentSuccess() {
        Documents__c doc = [SELECT Id FROM Documents__c LIMIT 1];
        
        // 1. Prepare Request Body
        OIC_SAUploadDocumentAPI.UploadDocumentRequest reqBody = new OIC_SAUploadDocumentAPI.UploadDocumentRequest();
        reqBody.FileName = 'Passport';
        reqBody.FileType = '.pdf';
        reqBody.FileBase64Content = EncodingUtil.base64Encode(Blob.valueOf('Test File Content'));
        reqBody.DocumentId = doc.Id;

        // 2. Setup RestContext
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/customer/uploaddocument';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
        
        RestContext.request = request;
        RestContext.response = response;

        // 3. Execute
        Test.startTest();
        OIC_SAUploadDocumentAPI.getCustomerDocuments();
        Test.stopTest();
    }

    @isTest
    static void testUploadDocumentFailure() {
        // Prepare invalid request (Empty FileName)
        OIC_SAUploadDocumentAPI.UploadDocumentRequest reqBody = new OIC_SAUploadDocumentAPI.UploadDocumentRequest();
        reqBody.FileName = ''; 

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAUploadDocumentAPI.getCustomerDocuments();
        Test.stopTest();
    }

    @isTest
    static void testServerError() {
        // Force an exception by sending malformed JSON that cannot be deserialized
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"FileName": }'); // Malformed JSON
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAUploadDocumentAPI.getCustomerDocuments();
        Test.stopTest();
    }
}