@isTest
private class OIC_SAInvoiceDetailsAPITest {

    @testSetup
    static void setupData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test1231.pdf@outlook.com';
         accountObj.FirstName = 'Firstt';
         accountObj.LastName = 'Lastt';
         accountObj.OraclePartyId__c ='22213';
         insert accountObj;
        
        // Create Unit/Property data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase121');
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

        // 4. Create Invoices (one 'Generated' for primary logic, one 'Partially Paid')
        Invoice__c inv1 = new Invoice__c(
            Account__c = accountObj.Id,
            Sales_Order__c = testSO.Id,
            InvoiceAmount__c = 1000.00,
            InvoiceDate__c = Date.valueOf('2024-02-02'),
            Is_ADM_Fees_and_Dari_charges__c = false
        );
        
        Invoice__c inv2 = new Invoice__c(
            Account__c = accountObj.Id,
            Sales_Order__c = testSO.Id,
            InvoiceDate__c = Date.valueOf('2024-02-02'),
            InvoiceAmount__c = 500.00,
            Is_ADM_Fees_and_Dari_charges__c = true // Tests special milestone naming
        );
        insert new List<Invoice__c>{inv1, inv2};
    }

    @isTest
    static void testGetInvoicesSuccess() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        SalesOrder__c testSO = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];
        request.requestUri = '/services/apexrest/InvoiceDetailsAPI/';
        request.httpMethod = 'GET';
        request.params.put('SalesOrderName', testSO.Name);
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAInvoiceDetailsAPI.findInvoiceDetails();
        Test.stopTest();
    }

    @isTest
    static void testMissingParameter() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        // SalesOrderName parameter is missing
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAInvoiceDetailsAPI.findInvoiceDetails();
        Test.stopTest();
    }

    @isTest
    static void testNoDataFound() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        request.params.put('SalesOrderName', 'NON_EXISTENT_SO');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAInvoiceDetailsAPI.findInvoiceDetails();
        Test.stopTest();
    }
}