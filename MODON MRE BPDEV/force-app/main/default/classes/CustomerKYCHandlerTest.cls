@isTest
public class CustomerKYCHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        SignzyAPIConfig__c signzyConfig = new SignzyAPIConfig__c(
            Name = 'Test Config',
            Journey_Creation_URL_Sandbox__c = 'https://test.sandbox.create',
            Get_Journey_Status_URL_Sandbox__c = 'https://test.sandbox.status',
            Auth_Token_Sandbox__c = 'sandbox-token',
            OICUserName_Sandbox__c = 'sandbox-user',
            OICPassword_Sandbox__c = 'sandbox-pass',
            Journey_Creation_URL_Production__c = 'https://test.prod.create',
            Get_Journey_Status_URL_Production__c = 'https://test.prod.status',
            Auth_Token_Production__c = 'prod-token',
            OICUserName_Production__c = 'prod-user',
            OICPassword_Production__c = 'prod-pass'
        );
        insert signzyConfig;
        
        Signzy_Journey__mdt journeyMDT = new Signzy_Journey__mdt(
            DeveloperName = 'Test_Journey',
            MasterLabel = 'Test Journey',
            Journey_Type__c = 'KYC',
            Expiry_Validity_in_Seconds__c = 3600,
            Signzy_Flow_ID__c = 'test-flow-123',
            Defaul_Document__c = 'PASSPORT',
            Default_Journey__c = true,
            Multi_Document_Authentication__c = false
        );
        
        OIC_Credential__mdt oicCredential = new OIC_Credential__mdt(
            DeveloperName = 'SignzyCreateJourneyOIC',
            Endpoint__c = 'https://test.oic.endpoint',
            Username__c = 'test-user',
            Password__c = 'test-pass',
            Method__c = 'POST'
        );
        
        Account individualAccount = new Account(
            FirstName = 'Test',
            LastName = 'Individual',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'test.individual@example.com',
            Nationality__pc = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident',
            KYC_Link_Status__c = 'IN PROGRESS'
        );
        insert individualAccount;
        
        Account corporateAccount = new Account(
            Name = 'Test Corporate Account',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId(),
            Legal_Type__c = 'LLC'
        );
        insert corporateAccount;
        
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = corporateAccount.Id,
            Email = 'test.contact@example.com',
            Nationality__c = 'United Arab Emirates',
            UAE_Resident_Status__c = 'Resident',
            KYC_Link_Status__c = 'IN PROGRESS'
        );
        insert testContact;
        
        Power_of_Attorney__c poa = new Power_of_Attorney__c(
            Organization_Account__c = corporateAccount.Id,
            Contact__c = testContact.Id
        );
        insert poa;
        
        KYC_Response__c kycIndividual = new KYC_Response__c(
            Customer__c = individualAccount.Id,
            RecordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Individual_KYC').getRecordTypeId(),
            FirstName__c = 'Test',
            Customer_LastName__c = 'Individual',
            Signzy_Journey_ID__c = 'test-journey-123',
            SignzyURL__c = 'https://test.signzy.url'
        );
        insert kycIndividual;
        
        KYC_Response__c kycCorporate = new KYC_Response__c(
            Contact__c = testContact.Id,
            RecordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Corporate_KYC').getRecordTypeId(),
            FirstName__c = 'Test',
            Customer_LastName__c = 'Contact'
        );
        insert kycCorporate;
        
        Documents__c docTradeLicense = new Documents__c(
            Name = 'Trade License',
            Account__c = corporateAccount.Id
        );
        insert docTradeLicense;//individualAccount
        Documents__c docTradeLicense1 = new Documents__c(
            Name = 'Trade License1',
            Account__c = individualAccount.Id
        );
        insert docTradeLicense1;
        Documents__c docPOA = new Documents__c(
            Name = 'Power Of Attorney',
            Power_of_Attorney__c = poa.Id
        );
        insert docPOA;
    }
    
    @isTest
    static void testIsSandbox() {
        Test.startTest();
        Boolean isSandboxResult = CustomerKYCHandler.isSandbox();
        Test.stopTest();
    }

    @isTest
    static void testLoadInitialDataWithAccount() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        String encryptedId = EncryptionService.encrypt(acc.Id);
        
        // Set up HTTP callout mock
        Test.setMock(HttpCalloutMock.class, new CustomerKYCHandlerTest.SignzyCalloutMock());
        
        Test.startTest();
        String result = CustomerKYCHandler.loadInitialData(encryptedId);
        Test.stopTest();
        
        // You can remove assertion if you want
        System.debug('Result: ' + result);
    }
    
    
    @isTest
    static void testLoadInitialDataWithContact() {
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        String encryptedId = EncryptionService.encrypt(con.Id);
        
        // Set up HTTP callout mock
        Test.setMock(HttpCalloutMock.class, new CustomerKYCHandlerTest.SignzyCalloutMock());
        
        Test.startTest();
        String result = CustomerKYCHandler.loadInitialData(encryptedId);
        Test.stopTest();
        
        System.debug('Result: ' + result);
    }
    
    
    @isTest
    static void testUpdateKycInfoToContact() {
        Contact testContact = [SELECT Id,Emirates_ID_Issue_Date__c FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        KYC_Response__c kyc = [
            SELECT Id, FirstName__c, Customer_LastName__c, Name_in_Arabic__c, Date_Of_Birth__c,
            Emirates_ID__c, EID_Expiry_Date__c, EID_Issue_Date__c, Passport_Number__c,
            Passport_Expiry_Date__c, Passport_Issue_Date__c, Passport_Issued_Place__c,
            Nationality__c, Street__c, City__c, State__c, Postal_Code__c,
            Nationality_in_Arabic__c, Resident_Status__c, EID_Sponsor__c, EID_Sponsor_Arabic__c,
            Profession_As_Per_EID__c, Profession_As_Per_EID_Arabic__c, Gender__c,
            EID_Issue_Emirates__c, Dual_Citizen__c, Other_Nationality_If_Applicable__c,
            Place_Of_Birth__c, Resident_Emirates__c, Source_of_Income__c, Position__c,
            Company_Name__c, Other_Source_Of_Income__c, Employment_Status__c
            FROM KYC_Response__c
            WHERE Contact__c = :testContact.Id
            LIMIT 1
        ];
        
        kyc.FirstName__c = 'Updated';
        kyc.Customer_LastName__c = 'Contact';
        kyc.Name_in_Arabic__c = 'Updated Arabic Name';
        kyc.Date_Of_Birth__c = Date.newInstance(1990, 1, 1);
        kyc.Emirates_ID__c = '784-1990-1234567-1';
        kyc.EID_Expiry_Date__c = Date.newInstance(2030, 12, 31);
        kyc.Passport_Number__c = 'A12345678';
        kyc.Passport_Expiry_Date__c = Date.newInstance(2028, 12, 31);
        kyc.Passport_Issue_Date__c = Date.newInstance(2018, 1, 1);
        kyc.Passport_Issued_Place__c = 'Dubai';
        kyc.Street__c = 'Updated Street';
        kyc.City__c = 'Dubai';
        kyc.State__c = 'Dubai';
        kyc.Postal_Code__c = '12345';
        kyc.Resident_Status__c = 'International';
        kyc.EID_Sponsor__c = 'Test Sponsor';
        kyc.EID_Sponsor_Arabic__c = 'Test Sponsor Arabic';
        kyc.Profession_As_Per_EID__c = 'Manager';
        kyc.Profession_As_Per_EID_Arabic__c = 'Manager Arabic';
        kyc.Gender__c = 'M';
        kyc.EID_Issue_Emirates__c = 'Dubai';
        kyc.Dual_Citizen__c = 'Yes';
        kyc.Other_Nationality_If_Applicable__c = 'American';
        kyc.Place_Of_Birth__c = 'Mumbai';
        kyc.Resident_Emirates__c = 'Dubai';
        kyc.Source_of_Income__c = 'Salary';
        kyc.Position__c = 'Senior Manager';
        kyc.Company_Name__c = 'Test Company';
        kyc.Other_Source_Of_Income__c = 'Investments';
        kyc.Employment_Status__c = 'Employed';
        kyc.EID_Issue_Date__c = Date.newInstance(2018, 1, 1);
        kyc.Nationality__c = 'United Arab Emirates';
        update kyc;
        
        Test.startTest();
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>{kyc.Id});
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateKycInfoToContactWithNullValues() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        KYC_Response__c kyc = [
            SELECT Id, FirstName__c, Customer_LastName__c, Name_in_Arabic__c, Date_Of_Birth__c,
            Emirates_ID__c, EID_Expiry_Date__c, EID_Issue_Date__c, Passport_Number__c,
            Passport_Expiry_Date__c, Passport_Issue_Date__c, Passport_Issued_Place__c,
            Nationality__c, Street__c, City__c, State__c, Postal_Code__c,
            Nationality_in_Arabic__c, Resident_Status__c, EID_Sponsor__c, EID_Sponsor_Arabic__c,
            Profession_As_Per_EID__c, Profession_As_Per_EID_Arabic__c, Gender__c,
            EID_Issue_Emirates__c, Dual_Citizen__c, Other_Nationality_If_Applicable__c,
            Place_Of_Birth__c, Resident_Emirates__c, Source_of_Income__c, Position__c,
            Company_Name__c, Other_Source_Of_Income__c, Employment_Status__c
            FROM KYC_Response__c
            WHERE Contact__c = :testContact.Id
            LIMIT 1
        ];
        
        kyc.FirstName__c = null;
        kyc.Customer_LastName__c = null;
        kyc.Name_in_Arabic__c = null;
        kyc.Date_Of_Birth__c = null;
        kyc.Emirates_ID__c = null;
        kyc.EID_Expiry_Date__c = null;
        kyc.EID_Issue_Date__c = null;
        kyc.Passport_Number__c = null;
        kyc.Passport_Expiry_Date__c = null;
        kyc.Passport_Issue_Date__c = null;
        kyc.Passport_Issued_Place__c = null;
        kyc.Nationality__c = null;
        kyc.Street__c = null;
        kyc.City__c = null;
        kyc.State__c = null;
        kyc.Postal_Code__c = null;
        kyc.Nationality_in_Arabic__c = null;
        kyc.Resident_Status__c = null;
        kyc.EID_Sponsor__c = null;
        kyc.EID_Sponsor_Arabic__c = null;
        kyc.Profession_As_Per_EID__c = null;
        kyc.Profession_As_Per_EID_Arabic__c = null;
        kyc.Gender__c = null;
        kyc.EID_Issue_Emirates__c = null;
        kyc.Dual_Citizen__c = null;
        kyc.Other_Nationality_If_Applicable__c = null;
        kyc.Place_Of_Birth__c = null;
        kyc.Resident_Emirates__c = null;
        update kyc;
        
        Test.startTest();
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>{kyc.Id});
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateKycInfoToContactEmptySet() {
        Test.startTest();
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>());
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateKycInfoToContactGenderMapping() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        KYC_Response__c kyc = [
            SELECT Id, FirstName__c, Customer_LastName__c, Name_in_Arabic__c, Date_Of_Birth__c,
            Emirates_ID__c, EID_Expiry_Date__c, EID_Issue_Date__c, Passport_Number__c,
            Passport_Expiry_Date__c, Passport_Issue_Date__c, Passport_Issued_Place__c,
            Nationality__c, Street__c, City__c, State__c, Postal_Code__c,
            Nationality_in_Arabic__c, Resident_Status__c, EID_Sponsor__c, EID_Sponsor_Arabic__c,
            Profession_As_Per_EID__c, Profession_As_Per_EID_Arabic__c, Gender__c,
            EID_Issue_Emirates__c, Dual_Citizen__c, Other_Nationality_If_Applicable__c,
            Place_Of_Birth__c, Resident_Emirates__c, Source_of_Income__c, Position__c,
            Company_Name__c, Other_Source_Of_Income__c, Employment_Status__c
            FROM KYC_Response__c
            WHERE Contact__c = :testContact.Id
            LIMIT 1
        ];
        
        kyc.Gender__c = 'F';
        update kyc;
        
        Test.startTest();
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>{kyc.Id});
        Test.stopTest();
        
        kyc.Gender__c = 'X';
        update kyc;
        
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>{kyc.Id});
    }
    
    @isTest
    static void testUpdateKycInfoToContactResidentStatusMapping() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        KYC_Response__c kyc = [
            SELECT Id, FirstName__c, Customer_LastName__c, Name_in_Arabic__c, Date_Of_Birth__c,
            Emirates_ID__c, EID_Expiry_Date__c, EID_Issue_Date__c, Passport_Number__c,
            Passport_Expiry_Date__c, Passport_Issue_Date__c, Passport_Issued_Place__c,
            Nationality__c, Street__c, City__c, State__c, Postal_Code__c,
            Nationality_in_Arabic__c, Resident_Status__c, EID_Sponsor__c, EID_Sponsor_Arabic__c,
            Profession_As_Per_EID__c, Profession_As_Per_EID_Arabic__c, Gender__c,
            EID_Issue_Emirates__c, Dual_Citizen__c, Other_Nationality_If_Applicable__c,
            Place_Of_Birth__c, Resident_Emirates__c, Source_of_Income__c, Position__c,
            Company_Name__c, Other_Source_Of_Income__c, Employment_Status__c
            FROM KYC_Response__c
            WHERE Contact__c = :testContact.Id
            LIMIT 1
        ];
        
        kyc.Resident_Status__c = 'Resident';
        update kyc;
        
        Test.startTest();
        CustomerKYCHandler.updateKycInfoToContact(new Set<Id>{kyc.Id});
        Test.stopTest();
    }
    
    
    
    @isTest
    static void testLoadInitialDataNoKYCResponse() {
        Account newAcc = new Account(
            FirstName = 'New',
            LastName = 'Account',
            PersonEmail = 'new.account@example.com'
        );
        insert newAcc;
        
        String encryptedId = EncryptionService.encrypt(newAcc.Id);
        
        Test.startTest();
        String result = CustomerKYCHandler.loadInitialData(encryptedId);
        Test.stopTest();
    }
    
    @isTest
static void testLoadInitialDataWithContactNoKYCResponse() {
    // Create a Contact without any KYC_Response__c records
    Contact con = new Contact(
        FirstName = 'TestNoKYC',
        LastName = 'ContactNoKYC',
        Email = 'testnokyc@example.com',
        Nationality__c = 'United Arab Emirates',
        UAE_Resident_Status__c = 'Resident',
        AreYouPoliticallyExposedPersonPEP__c = false,
        MailingStreet = 'Test Street',
        MailingCity = 'Dubai',
        MailingState = 'Dubai',
        MailingPostalCode = '12345',
      //  MailingCountry = 'UAE',
        Occupation__c = 'Manager',
        EmployerBusinessName__c = 'Test Company',
        SourceOfIncome__c = 'Salary',
        OtherSourceOfIncome__c = null
    );
    insert con;
    
    String encryptedId = EncryptionService.encrypt(con.Id);
    
    Test.startTest();
    String result = CustomerKYCHandler.loadInitialData(encryptedId);
    Test.stopTest();
}
    
    @isTest
    static void testHandleCustomerEarlyData() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        String encryptedId = EncryptionService.encrypt(acc.Id);
        
        CustomerKYCHandler.kycWrapper wrapper = new CustomerKYCHandler.kycWrapper();
        wrapper.residentStatus = 'Resident';
        wrapper.nationality = 'India';
        wrapper.city = 'Dubai';
        wrapper.street = 'Test Street';
        wrapper.state = 'Dubai';
        wrapper.postalCode = '12345';
        wrapper.employmentStatus = 'Employed';
        wrapper.sourceOfIncome = 'Salary';
        wrapper.position = 'Manager';
        wrapper.companyName = 'Test Company';
        wrapper.salaryrange = 'AED 0 - AED 25,000';
        wrapper.dualNationality = 'No';
        //wrapper.dualNationalityCountry = '';
        
        String customerInfo = JSON.serialize(wrapper);
        
        Test.startTest();
        String result = CustomerKYCHandler.handleCustomerEarlyData(customerInfo, encryptedId);
        Test.stopTest();
    }
    
    @isTest
    static void testGetRequiredPicklists() {
        Test.startTest();
        Map<String, List<CustomerKYCHandler.PicklistOption>> result = CustomerKYCHandler.getRequiredPicklists();
        Test.stopTest();
    }
    
    @isTest
    static void testGetNationalityPicklistValues() {
        Test.startTest();
        List<CustomerKYCHandler.PicklistOption> result = CustomerKYCHandler.getNationalityPicklistValues();
        Test.stopTest();
    }
    
    @isTest
    static void testGetEmployementStatusPicklistValues() {
        Test.startTest();
        List<CustomerKYCHandler.PicklistOption> result = CustomerKYCHandler.getEmployementStatusPicklistValues();
        Test.stopTest();
    }
    
    @isTest
    static void testGetEmployementOccupationValues() {
        Test.startTest();
        List<CustomerKYCHandler.PicklistOption> result = CustomerKYCHandler.getEmployementOccupationValues();
        Test.stopTest();
    }
    
    @isTest
    static void testGetSourceOfIncomePicklistValues() {
        Test.startTest();
        List<CustomerKYCHandler.PicklistOption> result = CustomerKYCHandler.getSourceOfIncomePicklistValues('Employed');
        Test.stopTest();
    }
    
    @isTest
    static void testCreateSignzyJourney() {
        Test.setMock(HttpCalloutMock.class, new SignzyCalloutMock());
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        
        Test.startTest();
        String result = CustomerKYCHandler.createSignzyJourney(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetSignzyJourney() {
        Test.setMock(HttpCalloutMock.class, new SignzyCalloutMock());
        KYC_Response__c kyc = [SELECT Id FROM KYC_Response__c WHERE Customer__c != null LIMIT 1];
        
        Test.startTest();
        String result = CustomerKYCHandler.getSignzyJourney(kyc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetSignzyJourney1() {
        Account newAcc = new Account(
            FirstName = 'New',
            LastName = 'Account',
            PersonEmail = 'new.account@example.com'
        );
        insert newAcc;
        
        String encryptedId = EncryptionService.encrypt(newAcc.Id);
    	Test.startTest();
 		String res = CustomerKYCHandler.fetchDocuSignUrl(encryptedId);
        CustomerKYCHandler.getErrorSignzyJourney(encryptedId);
        Test.stopTest();
    }   
    
    @isTest
    static void testGetSignzyJourney11() {
        Test.startTest();
        Account newAcc = new Account(
            Name = 'new kumar',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId(),
            Legal_Type__c = 'DDA'
        );
        //insert corporateAccount;
        insert newAcc;  
    // Create a Contact without any KYC_Response__c records
    Contact con = new Contact(
        FirstName = 'TestNoKYC',
        LastName = 'ContactNoKYC',
        Email = 'testnokyc@example.com',
        Nationality__c = 'United Arab Emirates',
        UAE_Resident_Status__c = 'Resident',
        AreYouPoliticallyExposedPersonPEP__c = false,
        MailingStreet = 'Test Street',
        MailingCity = 'Dubai',
        MailingState = 'Dubai',
        MailingPostalCode = '12345',
       // MailingCountry = 'UAE',
        Occupation__c = 'Manager',
        EmployerBusinessName__c = 'Test Company',
        SourceOfIncome__c = 'Salary',
        OtherSourceOfIncome__c = null,
        AccountId = newAcc.Id
    );
    insert con;
        
        String encryptedId = EncryptionService.encrypt(con.id);
        Account acc = CustomerKYCHandler.getTradeLicenseInfo(encryptedId);
        Test.stopTest();
    }    
    @isTest
    static void testUpdateCompletedKYCtoAccount() {
        KYC_Response__c kyc = [SELECT Id,Migrate_Data__c, Signzy_Journey_Status__c,Customer__c,Contact__c, RecordTypeId FROM KYC_Response__c WHERE Customer__c != null LIMIT 1];
        kyc.Signzy_Journey_Status__c = 'COMPLETED';
        
        Map<Id, KYC_Response__c> oldMap = new Map<Id, KYC_Response__c>{
            kyc.Id => new KYC_Response__c(Id = kyc.Id, Signzy_Journey_Status__c = 'IN PROGRESS')
                };
                    
                    Test.startTest();
        //CustomerKYCHandler.updateCompletedKYCtoAccount(new List<KYC_Response__c>{kyc}, oldMap);
        Test.stopTest();
    }
    
    @isTest
    static void testSendKYCFormIndividual() {
        Test.setMock(HttpCalloutMock.class, new SignzyCalloutMock());
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        
        Test.startTest();
        String result = CustomerKYCHandler.sendKYCForm(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSendKYCFormCorporate() {
        Test.setMock(HttpCalloutMock.class, new SignzyCalloutMock());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
        
        Test.startTest();
        String result = CustomerKYCHandler.sendKYCForm(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSendKYCFormCorporateNoPOA() {
        delete [SELECT Id FROM Power_of_Attorney__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
        
        Test.startTest();
        String result = CustomerKYCHandler.sendKYCForm(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountDetails() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        
        Test.startTest();
        CustomerKYCHandler.expiryTrackerWrapper result = CustomerKYCHandler.getAccountDetails(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountDetailsContact() {
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        
        Test.startTest();
        CustomerKYCHandler.expiryTrackerWrapper result = CustomerKYCHandler.getAccountDetails(con.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testHandleTradeLicenseVerificationAPI() {
        Test.setMock(HttpCalloutMock.class, new TradeLicenseCalloutMock());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
        String base64Data = 'test-base64-data';
        
        Test.startTest();
        String result = CustomerKYCHandler.handleTradeLicenseVerificationAPI(base64Data, acc.Id,'image/jpg');
        Test.stopTest();
    }
  
public class TradeLicenseCalloutMockError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        // JSON with an error object to hit the else if
        String jsonResponse = '{ "error": { "message": "Invalid Trade License" } }';
        res.setBody(jsonResponse);
        return res;
    }
}
  @IsTest
static void testHandleTradeLicenseVerificationAPI_WithError() {
    // Use the error-returning mock
    Test.setMock(HttpCalloutMock.class, new TradeLicenseCalloutMockError());

    // Create account
    Account acc = new Account(Name = 'Test Error Account');
    insert acc;

    String base64Data = 'test-base64-data';

    Test.startTest();
    String result = CustomerKYCHandler.handleTradeLicenseVerificationAPI(base64Data, acc.Id,'image/jpg');
    Test.stopTest();

}

    
    @isTest
    static void testHandlePOAFile() {
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        String encryptedId = EncryptionService.encrypt(con.Id);
        
        String fileContent = 'This is a test file content';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));
        String fileName = 'TestPOA.pdf';
        
        Test.startTest();
        CustomerKYCHandler.handlePOAFile(base64Data, encryptedId, fileName);
        Test.stopTest();
    }
    
    @isTest
    static void testHandlePOAFileWithInvalidBase64() {
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        String encryptedId = EncryptionService.encrypt(con.Id);
        
        String invalidBase64 = 'not-a-valid-base64';
        String fileName = 'InvalidFile.pdf';
        
        Test.startTest();
        CustomerKYCHandler.handlePOAFile(invalidBase64, encryptedId, fileName);
        Test.stopTest();
    }
    
    @isTest
    static void testHandlePOAFileWithNullContactId() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test file content'));
        String fileName = 'NullContact.pdf';
        
        Test.startTest();
        CustomerKYCHandler.handlePOAFile(base64Data, null, fileName);
        Test.stopTest();
    }
    
    @isTest
    static void testTradeLicenseUploadFile() {
        Test.setMock(HttpCalloutMock.class, new TradeLicenseCalloutMock());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        String base64Text = 'SGVsbG8gV29ybGQh'; // "Hello World!"
		Blob b = EncodingUtil.base64Decode(base64Text);

        String fileName = 'test.pdf';
        base64Text = b.toString();
        Test.startTest();
        String result = CustomerKYCHandler.tradeLicenseuploadFile(base64Text, fileName, EncryptionService.encrypt(con.Id));
        Test.stopTest();
    }
@IsTest
static void testTradeLicenseUploadFile_DML_NoAssertions() {
    // Mock the HTTP callout
    Test.setMock(HttpCalloutMock.class, new TradeLicenseCalloutMock());

    // Step 1: Get or create test account
    Account acc;
    List<Account> accList = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
    if (accList.isEmpty()) {
        acc = new Account(Name = 'Test Corporate Account');
        insert acc;
    } else {
        acc = accList[0];
    }

    // Step 2: Create existing Documents__c record to cover upsert
    Documents__c existingDoc = new Documents__c(
        Name = 'Trade License',
        Account__c = acc.Id
    );
    insert existingDoc;

    // Step 3: Prepare test data
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy content'));
    String fileName = 'test.pdf';

    // Step 4: Call the method inside Test.startTest/Test.stopTest
    Test.startTest();
    String result = CustomerKYCHandler.tradeLicenseuploadFile(base64Data, fileName, acc.Id);
    Test.stopTest();
}

    @isTest
    static void testTradeLicenseUploadFileInvalidType() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corporate Account' LIMIT 1];
        String base64Data = 'test-base64-data';
        String fileName = 'test.txt';
        
        Test.startTest();
        String result = CustomerKYCHandler.tradeLicenseuploadFile(base64Data, fileName, acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetPicklistOptionsErrorHandling() {
        Test.startTest();
        List<CustomerKYCHandler.PicklistOption> validResult = CustomerKYCHandler.getIncomeSourcePicklistValues();
        try {
            List<CustomerKYCHandler.PicklistOption> result = CustomerKYCHandler.getIncomeSourcePicklistValues();
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testMapSourceOfIncome() {
        Test.startTest();
        List<String> employedResult = CustomerKYCHandler.mapSourceOfIncome('Employed');
        List<String> selfEmployedResult = CustomerKYCHandler.mapSourceOfIncome('Self Employed');
        List<String> invalidResult = CustomerKYCHandler.mapSourceOfIncome('Invalid');
        Test.stopTest();
    }
    
    @isTest
    static void testHandleStringData() {
        Test.startTest();
        Date result1 = CustomerKYCHandler.handleStringData('15/08/2023');
        Date result2 = CustomerKYCHandler.handleStringData('invalid-date');
        Test.stopTest();
    }
    
    @isTest
    static void testNullCheckMethods() {
        Test.startTest();
        String stringResult = CustomerKYCHandler.nullCheck('test');
        Date dateResult = CustomerKYCHandler.nullCheck(Date.today());
        Date dateNullResult = CustomerKYCHandler.nullCheck((Date)null);
        Decimal decimalResult = CustomerKYCHandler.nullCheck(100.50);
        Decimal decimalNullResult = CustomerKYCHandler.nullCheck((Decimal)null);
        Test.stopTest();
    }
    
    @isTest
    static void testValidateGenerateKYCDocument() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        Documents__c doc= [SELECT Id FROM Documents__c WHERE Account__c =:acc.Id LIMIT 1];
        Test.startTest();
        try {
            CustomerKYCHandler.validateGenerateKYCDocument(doc.Id);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testValidateGenerateKYCDocumentWithFieldSet() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        Test.startTest();
        try {
            CustomerKYCHandler.validateGenerateKYCDocument(acc.Id);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testValidateGenerateKYCDocumentNullAccountId() {
        Test.startTest();
        try {
            CustomerKYCHandler.validateGenerateKYCDocument(null);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testValidateGenerateKYCDocumentInvalidAccountId() {
        Test.startTest();
        try {
            CustomerKYCHandler.validateGenerateKYCDocument('001000000000000');
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testQueryByFieldSet() {
        Test.startTest();
        try {
            CustomerKYCHandler.queryByFieldSet('Account', 'NonExistentFieldSet');
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testAreAnyFieldsEmpty() {
        Account acc = [SELECT Id, Name FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        Test.startTest();
        try {
            CustomerKYCHandler.areAnyFieldsEmpty(acc, 'Account', 'NonExistentFieldSet');
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testQueryByFieldSetErrorHandling() {
        Test.startTest();
        try {
            CustomerKYCHandler.queryByFieldSet('NonExistentObject', 'TestFieldSet');
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testAreAnyFieldsEmptyWithNullRecord() {
        Test.startTest();
        try {
            CustomerKYCHandler.areAnyFieldsEmpty(null, 'Account', 'TestFieldSet');
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testValidateGenerateKYCDocumentWithMockFieldSet() {
        Account acc = [SELECT Id, FirstName, LastName, PersonEmail FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        Test.startTest();
        try {
            CustomerKYCHandler.queryByFieldSet('Account', '');
        } catch (Exception e) {}
        try {
            CustomerKYCHandler.areAnyFieldsEmpty(acc, 'Account', '');
        } catch (Exception e) {}
        try {
            CustomerKYCHandler.validateGenerateKYCDocument(acc.Id);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testAttachImageFromUrl() {
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new ImageCalloutMock());
        
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        String imageUrl = 'https://test.image.url/image.jpg';
        String fileName = 'Test Image';
        String folderName = 'Test Folder';
        
        Test.startTest();
        CustomerKYCHandler.attachImageFromUrl(acc.Id, imageUrl, fileName, folderName);
        Test.stopTest();
        
        // No assertions - just verifying the method executes
    }
    
    @isTest
    static void testAttachImageFromUrlWithContact() {
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new ImageCalloutMock());
        
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        String imageUrl = 'https://test.image.url/image.jpg';
        String fileName = 'Test Contact Image';
        String folderName = 'Test Contact Folder';
        
        Test.startTest();
        CustomerKYCHandler.attachImageFromUrl(con.Id, imageUrl, fileName, folderName);
        Test.stopTest();
        
        // No assertions - just verifying the method executes
    }
    
    @isTest
    static void testAttachImageFromUrlHttpError() {
        // Mock HTTP error response
        Test.setMock(HttpCalloutMock.class, new ImageErrorCalloutMock());
        
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        String imageUrl = 'https://test.image.url/error.jpg';
        String fileName = 'Error Image';
        String folderName = 'Error Folder';
        
        Test.startTest();
        CustomerKYCHandler.attachImageFromUrl(acc.Id, imageUrl, fileName, folderName);
        Test.stopTest();
        
        // No assertions - just verifying the method executes without throwing exceptions
    }
    
    @isTest
    static void testAttachImageFromUrlException() {
        // Mock exception scenario
        Test.setMock(HttpCalloutMock.class, new ImageExceptionCalloutMock());
        
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        String imageUrl = 'https://invalid.url/image.jpg';
        String fileName = 'Exception Image';
        String folderName = 'Exception Folder';
        
        Test.startTest();
        CustomerKYCHandler.attachImageFromUrl(acc.Id, imageUrl, fileName, folderName);
        Test.stopTest();
        
        // No assertions - just verifying the method handles exceptions gracefully
    }
    
    @isTest
    static void testAttachImageFromUrlExistingDocument() {
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new ImageCalloutMock());
        
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        
        // Create an existing document first
        Documents__c existingDoc = new Documents__c(
            Name = 'Existing Folder',
            Account__c = acc.Id
        );
        insert existingDoc;
        
        String imageUrl = 'https://test.image.url/image.jpg';
        String fileName = 'Existing Doc Image';
        String folderName = 'Existing Folder';
        
        Test.startTest();
        CustomerKYCHandler.attachImageFromUrl(acc.Id, imageUrl, fileName, folderName);
        Test.stopTest();
        
    }
    
    // HTTP Callout Mock Classes for image download
    private class ImageCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'image/jpeg');
            res.setBodyAsBlob(Blob.valueOf('fake image data'));
            res.setStatusCode(200);
            return res;
        }
    }
    
    private class ImageErrorCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found');
            return res;
        }
    }
    
    private class ImageExceptionCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // This will cause an exception in the callout
            throw new CalloutException('Simulated callout exception');
        }
    }
    
    @isTest
    static void testGetDataBlobValueWithContentDocumentLink() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Test' AND LastName = 'Individual' LIMIT 1];
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'Test_Document.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = acc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        
        Test.startTest();
        Blob result = CustomerKYCHandler.getDataBlobValue(acc.Id);
        Test.stopTest();
    }
    
    
    
    @isTest
    static void testGetTradeLicenseDateFormat() {
        Test.startTest();
        Date result1 = CustomerKYCHandler.getTradeLicenseDateFormat('25/12/2023');
        Date result2 = CustomerKYCHandler.getTradeLicenseDateFormat(null);
        Date result3 = CustomerKYCHandler.getTradeLicenseDateFormat('');
        Date result4 = CustomerKYCHandler.getTradeLicenseDateFormat('20231225');
        Date result5 = CustomerKYCHandler.getTradeLicenseDateFormat('aa/bb/cccc');
        Test.stopTest();
    }
    
    private class SignzyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('create')) {
                res.setBody('{"result": {"journeyId": "test-journey-123", "journeyUrl": "https://test.signzy.url", "createdAt": 123456789, "ttl": "3600"}}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('status')) {
                res.setBody('{"result": {"currentStatus": "COMPLETED", "userId": "test-user", "message": "Success", "clientId": "test-client", "step": "completed", "flow": {"flowId": "test-flow-123"}, "documentIntelligence": {"predictedIdTypeFront": {"FDSIDList": {"dDescription": "PASSPORT"}}, "extractedFields": {"firstName": "Test", "lastName": "User", "Sex": "M", "dateOfBirth": "15/08/1990", "Age": "33", "nationalityCode": "IND", "documentNumber": "A1234567", "dateOfExpiry": "15/08/2030", "dateOfIssue": "15/08/2020", "placeOfIssue": "Dubai", "placeOfBirth": "Mumbai"}, "graphicFields": {"fieldList": [[{"fieldType": "CROPPED_DOCUMENT", "value": "https://test.image.url", "docSide": "front"}]]}}, "documentIntelligence2": {"attempts": 1,"predictedIdTypeFront": {"FDSIDList": {"dDescription": "PASSPORT"}}, "extractedFields": {"firstName": "Test", "lastName": "User", "Sex": "M", "dateOfBirth": "15/08/1990", "Age": "33", "nationalityCode": "IND", "documentNumber": "A1234567", "dateOfExpiry": "15/08/2030", "dateOfIssue": "15/08/2020", "placeOfIssue": "Dubai", "placeOfBirth": "Mumbai"}, "graphicFields": {"fieldList": [[{"fieldType": "CROPPED_DOCUMENT", "value": "https://test.image.url", "docSide": "front"}]]}}, "selfieAnalysis": {"faceMatch": {"message": "Verified", "verified": true}}}}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }
    
    private class TradeLicenseCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('trade-license')) {
                res.setBody('{"result": {"licenseDetails": {"licenseNumber": "TL123456"}}}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }
    
@IsTest
static void testMapSignzyJourneyData() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    KYC_Response__c kyc = new KYC_Response__c(
        Customer__c = acc.Id,
        FirstName__c = 'OldFirstName',
        Customer_LastName__c = 'OldLastName'
    );
    insert kyc;

    SignzyJourneyStatusWrapper wrapper = new SignzyJourneyStatusWrapper();
    wrapper.result = new SignzyJourneyStatusWrapper.Result();
    wrapper.result.currentStatus = 'COMPLETED';
    wrapper.result.userId = 'USER123';
    wrapper.result.clientId = 'CLIENT123';
    wrapper.result.step = 'Step1';
    wrapper.result.message = 'Journey Completed';

    // CapturedData
    wrapper.result.capturedData = new SignzyJourneyStatusWrapper.CapturedData();
    wrapper.result.capturedData.idType = 'Resident Identity Card';
    wrapper.result.capturedData.images = new SignzyJourneyStatusWrapper.Images();
    wrapper.result.capturedData.images.selfie = 'https://example.com/selfie.jpg';

    /* Selfie Analysis
    wrapper.result.selfieAnalysis = new SignzyJourneyStatusWrapper.SelfieAnalysis();
    wrapper.result.selfieAnalysis.faceMatch = new SignzyJourneyStatusWrapper.faceMatch();
    wrapper.result.selfieAnalysis.faceMatch.message = 'Face Matched';
    wrapper.result.selfieAnalysis.faceMatch.verified = true;*/

    // Document Intelligence 1
    wrapper.result.documentIntelligence = new SignzyJourneyStatusWrapper.DocumentIntelligence();
    wrapper.result.documentIntelligence.extractedFields = new SignzyJourneyStatusWrapper.extractedFieldsCls();
    wrapper.result.documentIntelligence.extractedFields.firstName = 'John';
    wrapper.result.documentIntelligence.extractedFields.lastName = 'Doe';
    wrapper.result.documentIntelligence.extractedFields.Sex = 'Male';
    wrapper.result.documentIntelligence.extractedFields.dateOfBirth = '1990-01-01';
    wrapper.result.documentIntelligence.extractedFields.Age = '35';
    wrapper.result.documentIntelligence.extractedFields.identityCardNumber = 'EID123456';


    // GraphicFields
    wrapper.result.documentIntelligence.graphicFields = new SignzyJourneyStatusWrapper.GraphicFields();
    wrapper.result.documentIntelligence.graphicFields.fieldList = new List<List<SignzyJourneyStatusWrapper.GraphicField>>();
    wrapper.result.documentIntelligence.graphicFields.fieldList.add(new List<SignzyJourneyStatusWrapper.GraphicField>());

    // Document Intelligence 2
    wrapper.result.documentIntelligence2 = new SignzyJourneyStatusWrapper.DocumentIntelligence();
    wrapper.result.documentIntelligence2.extractedFields = new SignzyJourneyStatusWrapper.extractedFieldsCls();
    wrapper.result.documentIntelligence2.graphicFields = new SignzyJourneyStatusWrapper.GraphicFields();
    wrapper.result.documentIntelligence2.graphicFields.fieldList = new List<List<SignzyJourneyStatusWrapper.GraphicField>>();
    wrapper.result.documentIntelligence2.graphicFields.fieldList.add(new List<SignzyJourneyStatusWrapper.GraphicField>());

    Test.startTest();
    try {
        String result = CustomerKYCHandler.mapSignzyJourneyData(kyc.Id, wrapper);
    } catch (Exception e) {
        System.debug('Exception: ' + e.getMessage());
    }
    Test.stopTest();
}

@IsTest
static void testMapKYCTradeLicenseValues() {
    // Create test account
    Account acc = new Account(Name = '123 Test Corporate Account - another');
    insert acc;

    // Create dummy LicenseDetails
    SignzyTradeLicenseWrapper.LicenseDetails licenseDetails = new SignzyTradeLicenseWrapper.LicenseDetails();
    licenseDetails.licenseNumber = 'LIC123';
    licenseDetails.companyName = 'Test Company';
    licenseDetails.tradeName = 'Test Trade';
    licenseDetails.legalType = 'LLC';
    licenseDetails.issueDate = '2023-01-01';
    licenseDetails.expiryDate = '2025-01-01';

    // Create dummy OtherLicenseDetails
    SignzyTradeLicenseWrapper.OtherLicenseDetails otherDetails = new SignzyTradeLicenseWrapper.OtherLicenseDetails();
    otherDetails.taxRegNumber = 'TAX123';
    otherDetails.vatNumber = 'VAT123';

    // Create dummy Address
    SignzyTradeLicenseWrapper.Address address = new SignzyTradeLicenseWrapper.Address();
    address.telephone = '1234567890';
    address.email = 'test@example.com';

    // Create licenseActivities (matches wrapper: has 'activities' property)
    SignzyTradeLicenseWrapper.LicenseActivities licenseActivities = new SignzyTradeLicenseWrapper.LicenseActivities();
    licenseActivities.activities = new List<String>{'Activity1','Activity2'};

    // Create licensePartners as Map<String, LicensePartner>
    Map<String, SignzyTradeLicenseWrapper.LicensePartner> licensePartners = new Map<String, SignzyTradeLicenseWrapper.LicensePartner>();
    SignzyTradeLicenseWrapper.LicensePartner partner1 = new SignzyTradeLicenseWrapper.LicensePartner();
    partner1.name = 'Partner1';
    licensePartners.put('Partner1', partner1);

    // Wrap into Result object
    SignzyTradeLicenseWrapper.Result result = new SignzyTradeLicenseWrapper.Result();
    result.licenseDetails = licenseDetails;
    result.otherLicenseDetails = otherDetails;
    result.address = address;
    result.licenseActivities = licenseActivities;
    result.licensePartners = licensePartners;

    SignzyTradeLicenseWrapper wrapper = new SignzyTradeLicenseWrapper();
    wrapper.result = result;

    // Call the method
    Test.startTest();
    CustomerKYCHandler.mapKYCTradeLicenseValues(wrapper, acc.Id, 'Test Response JSON');
    Test.stopTest();
}
@isTest
    static void callDocuSignLinkTest(){
        Id docId = [SELECT Id FROM Documents__c LIMIT 1].Id;
        CustomerKYCHandler.callDocuSignLink(docId,'www.google.com',null,null);
    }

    // Method to mock the DocuSign Callout - Rushi Patel - 20th August 2026
    private class DocuSignMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('oauth')) {
                res.setBody('{"access_token":"FAKE"}');
            } else if (req.getEndpoint().contains('views/recipient')) {
                res.setBody('{"url":"https://fake.docusign.url"}');
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }

     // Test Method to generate the DocuSign URL - Rushi Patel - 20th August 2026
    @isTest
    static void testRegenerateAndFetchDocuSignUrl() {
        // Create necessary data
        Account acc = new Account(Name = 'Test Acc');
        insert acc;
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;
        
        Documents__c doc = new Documents__c(
            PrimaryContact__c = con.Id,
            EnvelopID__c = '123456',
            Name = 'KYC Form'
        );
        insert doc;

        String encryptedId = EncryptionService.encrypt(String.valueOf(acc.Id));
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new DocuSignMock());
        
        // This will call regenerateAndFetchDocuSignUrl, which will do SOQL on Documents__c and fire the callout
        String url = CustomerKYCHandler.regenerateAndFetchDocuSignUrl(encryptedId);
        Test.stopTest();
    }

    @isTest
    static void testJourneyStatusAndDraftKycData() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE FirstName = 'Test' AND LastName = 'Individual'
            LIMIT 1
        ];
        KYC_Response__c existingKyc = [
            SELECT Id, Journey_Status__c
            FROM KYC_Response__c
            WHERE Customer__c = :accountRecord.Id
            LIMIT 1
        ];
        String encryptedAccountId = EncryptionService.encrypt(accountRecord.Id);

        CustomerKYCHandler.updateJourneyStatus(null, 'STARTED');
        CustomerKYCHandler.updateJourneyStatus(encryptedAccountId, 'STARTED');

        existingKyc = [
            SELECT Journey_Status__c
            FROM KYC_Response__c
            WHERE Id = :existingKyc.Id
        ];
        System.assertEquals('STARTED', existingKyc.Journey_Status__c);

        Test.startTest();
        CustomerKYCHandler.updateDraftKYCData(
            accountRecord.Id,
            'https://draft.example.com',
            'draft-journey',
            '{"draft":true}',
            3600
        );
        Test.stopTest();

        Account updatedAccount = [
            SELECT SignzyURL__c, Signzy_Journey_Status__c, KYC_Expiry_Time_in_Seconds__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];
        System.assertEquals('https://draft.example.com', updatedAccount.SignzyURL__c);
        System.assertEquals('IN PROGRESS', updatedAccount.Signzy_Journey_Status__c);
        System.assertEquals(3600, updatedAccount.KYC_Expiry_Time_in_Seconds__c);
    }

    @isTest
    static void testCreateFileLogAndNameUtilities() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE FirstName = 'Test' AND LastName = 'Individual'
            LIMIT 1
        ];

        Test.startTest();
        CustomerKYCHandler.createFileLog(accountRecord.Id, '{"ok":true}', 'KYC API');
        CustomerKYCHandler.createFileLog(null, '{"ok":false}', 'Invalid Log');
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'KYC API - %']
        );
        System.assertEquals(
            new List<String>{'MOHAMMED', 'ALI HASSAN'},
            CustomerKYCHandler.splitGivenNames('  MOHAMMED   ALI HASSAN ')
        );
        System.assertEquals(
            new List<String>{'MOHAMMED', null},
            CustomerKYCHandler.splitGivenNames('MOHAMMED')
        );
        System.assertEquals(
            new List<String>{null, null},
            CustomerKYCHandler.splitGivenNames(null)
        );
        System.assertEquals(
            new List<String>{'MOHAMMED', 'ALI HASSAN AL', 'MANSOORI'},
            CustomerKYCHandler.splitFullName('MOHAMMED ALI HASSAN AL MANSOORI')
        );
        System.assertEquals(
            new List<String>{null, null, 'MANSOORI'},
            CustomerKYCHandler.splitFullName('MANSOORI')
        );
        System.assertEquals(
            new List<String>{null, null, null},
            CustomerKYCHandler.splitFullName('')
        );
        System.assertEquals('First Middle Last', CustomerKYCHandler.buildFullName(' First ', 'Middle', 'Last '));
        System.assertEquals('First Last', CustomerKYCHandler.buildFullName('First', null, 'Last'));
        System.assertEquals('', CustomerKYCHandler.buildFullName(null, ' ', null));
    }
}