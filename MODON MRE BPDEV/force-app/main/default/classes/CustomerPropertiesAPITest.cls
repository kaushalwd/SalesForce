@isTest
private class CustomerPropertiesAPITest {

    @testSetup
    static void setupData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test1233.pdf@outlook.com';
         accountObj.FirstName = 'Firttt';
         accountObj.LastName = 'Lattt';
         accountObj.OraclePartyId__c ='22215';
         insert accountObj;
        
        // Create Unit/Property data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase120');
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
        
        Contact primaryContact = new Contact(FirstName = 'Primary', LastName = 'Owner', Email = 'primary0001@test.com');
        insert primaryContact;

        Contact jointContact = new Contact(FirstName = 'Joint', LastName = 'Owner', Email = 'joint00001@test.com');
        insert jointContact;
        
        Contact jointContact2 = new Contact(FirstName = 'Joint', LastName = 'Owner', Email = 'joint00002@test.com');
        insert jointContact2;
        
        Contact jointContact3 = new Contact(FirstName = 'Joint', LastName = 'Owner', Email = 'joint00003@test.com');
        insert jointContact3;
        
        // Create Sales Order
        SalesOrder__c testSO = new SalesOrder__c(
           // SOCreationDate__c = System.today(),
            SPACustomerSignedDate__c = System.today().addDays(-30),
            //ProjectName__c = 'Test Project',
            TotalAmount__c = 1000000,
            CustomerAccount__c = accountObj.Id,
            Unit__c = testUnit.Id,
            VirtualAccount__c = testVA.Id,
            PrimaryContact__c = primaryContact.Id,
            JO1__c = jointContact.Id,
            JO2__c = jointContact2.Id,
            JO3__c = jointContact3.Id
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
    }

    @isTest
    static void testGetPropertiesAsPrimaryOwner() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/CustomerPropertiesAPI/';
        request.httpMethod = 'GET';
        request.params.put('CustomerEmail', 'test1233.pdf@outlook.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerPropertiesAPI.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testGetPropertiesAsJointOwner() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/CustomerPropertiesAPI/';
        request.httpMethod = 'GET';
        request.params.put('CustomerEmail', 'test1233.pdf@outlook.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerPropertiesAPI.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testMissingEmail() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        // CustomerEmail is missing
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerPropertiesAPI.findPropertyDetails();
        Test.stopTest();
    }

    @isTest
    static void testNoDataFound() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.params.put('CustomerEmail', 'nonexistent@test.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerPropertiesAPI.findPropertyDetails();
        Test.stopTest();
    }
}