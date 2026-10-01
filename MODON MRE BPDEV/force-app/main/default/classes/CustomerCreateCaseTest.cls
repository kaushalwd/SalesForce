@isTest
private class CustomerCreateCaseTest {

    @testSetup
    static void setupData() {
        // Create an Account  and Contact to link to the case
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id, Email = 'test@example.com');
        insert con;
        
    }

    @isTest
    static void testCreateCaseSuccess() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;

        phase__c phase = new phase__c(name='Test Phase',EscrowAccount__c=escAccount.id);
        insert phase;

        Unit__c unit = new Unit__c(name='Test Unit',Phase__c=phase.id,PlotNo__c='123',Number_of_bedrooms__c='2',UnitClassification__c='Apartment');
        insert unit;
        
        // 1. Prepare Request Body
        CustomerCreateCase.CreateCaseRequest reqBody = new CustomerCreateCase.CreateCaseRequest();
        reqBody.AccountId = acc.Id;
        reqBody.ContactId = con.Id;
        reqBody.FirstName = 'Suresh';
        reqBody.LastName = 'Kumar';
        reqBody.Email = 'suresh@test.com';
        reqBody.Phone = '971501234567';
        reqBody.Category = 'Payment';
        reqBody.SubCategory = 'Bank transfer details';
        reqBody.Subject = 'Water Leak';
        reqBody.Description = 'Leaking pipe in kitchen';
        reqBody.Language = 'English';
        reqBody.UnitId = unit.Id;

        // 2. Setup RestContext
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/CustomerCreateCaseAPI/';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
        
        RestContext.request = request;
        RestContext.response = response;

        // 3. Execute
        Test.startTest();
        CustomerCreateCase.createCase();
        Test.stopTest();
    }

    @isTest
    static void testMissingMandatoryFields() {
        // Prepare request missing mandatory fields (e.g., missing Category)
        CustomerCreateCase.CreateCaseRequest reqBody = new CustomerCreateCase.CreateCaseRequest();
        reqBody.FirstName = 'Suresh';
        reqBody.LastName = 'Kumar';
        // Category is missing
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerCreateCase.createCase();
        Test.stopTest();
    }

    @isTest
    static void testHandleException() {
        // Prepare valid data but force a database failure (e.g., using a malformed ID)
        CustomerCreateCase.CreateCaseRequest reqBody = new CustomerCreateCase.CreateCaseRequest();
        reqBody.AccountId = 'INVALID_ID_FORMAT'; 
        reqBody.FirstName = 'Test';
        reqBody.LastName = 'Test';
        reqBody.Email = 'test@test.com';
        reqBody.Phone = '123';
        reqBody.Category = 'General';
        reqBody.Description = 'Desc';

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerCreateCase.createCase();
        Test.stopTest();
    }
}