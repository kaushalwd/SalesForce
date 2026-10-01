@IsTest
public class CustomerPortalSOAAPITest {
    
    
    @TestSetup
    static void setupTestData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test.pdf@outlook.com';
         accountObj.FirstName = 'First';
         accountObj.LastName = 'Last';
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
        
        // Assume 'installments' is a pre-fetched List<SalesOrderInstallments__c>
        for(SalesOrderInstallments__c inst : installments) {
            Invoice__c inv = new Invoice__c(
                SalesOrderInstallment__c = inst.Id,  // Lookup field to the installment
                InvoiceAmount__c = 300000,
                Account__c = accountObj.id,
                InvoiceDate__c = System.today()
            );
            installmentInvoices.add(inv);
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
    }
    
    // Test SOAControllerV1 methods
    @IsTest
    static void testGetSOAData() {
        SalesOrder__c testSO = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        SOAControllerV1.SOAWrapper result = SOAControllerV1.getSOAData(testSO.Id);
        Test.stopTest();
        
      
    }
    
    // Test CustomerPortalSOAAPI
    @IsTest
    static void testFindSOADetailsSuccess() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
        
        // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', testSO.Name);
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'), 'Status should be success');
    }
    
    @IsTest
    static void testFindSOADetailsMissingParameter() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.TokenFailureMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAAPI/';
        req.httpMethod = 'GET';
        // No parameters
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
    }
    
    @IsTest
    static void testFindSOADetailsNotFound() {
        
        // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', 'NONEXISTENT');
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();
        

    }
    
    @IsTest
    static void testFindSOADetailsException() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Force an exception by passing invalid SO ID format
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', 'INVALID_ID_FORMAT');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();

    }
// Test SOAPdfController methods
    @IsTest
    static void testGetSOAPdfData() {
        SalesOrder__c testSO = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        SOAPdfController.SOAWrapper result = SOAPdfController.getSOAData(testSO.Id);
        Test.stopTest();
        
      
    }
    
    // Test CustomerPortalSOAPDFAPI
    @IsTest
    static void testFindSOAPDFDetailsSuccess() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', testSO.Name);
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        req.addParameter('userName','test.pdf@outlook.com');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'), 'Status should be success');
    }
    
    @IsTest
    static void testFindSOAPDFDetailsMissingParameter() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.TokenFailureMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        // No parameters
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
    }
    
    @IsTest
    static void testFindSOAPDFDetailsNotFound() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', 'NONEXISTENT');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        

    }
    
    @IsTest
    static void testFindSOAPDFDetailsException() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Force an exception by passing invalid SO ID format
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', 'INVALID_ID_FORMAT');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();

    }
    
    // Test CustomerPortalSOAPDFAPI
    @IsTest
    static void testFindSOAPDF_Error() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', testSO.Name);
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        req.addParameter('userName','testpdf@outlook.com');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'No data found');
    }
// Test CustomerPortalSOAPDFAPI
    @IsTest
    static void testFindSOAPDF_Error1() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SOId', testSO.Name);
        req.addParameter('token','');
        req.addParameter('userName','testpdf@outlook.com');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'Token validation failed. Please log in again.');
    }
    @IsTest
    static void testFindSOAPDF_Error2() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'POST';
        req.addParameter('SOId', testSO.Name);
        req.addParameter('token','');
        req.addParameter('userName','testpdf@outlook.com');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'Token validation failed. Please log in again.');
    }
    @IsTest
    static void testFindSOAPDF_Error3() {
        SalesOrder__c testSO = [SELECT Name FROM SalesOrder__c LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CustomerPortalSOAPDFAPI/';
        req.httpMethod = 'GET';
        req.addParameter('SO-Id', testSO.Name);
        req.addParameter('token','');
        req.addParameter('userName','testpdf@outlook.com');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAPDFAPI.findSOADetails();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'Token validation failed. Please log in again.');
    }
}