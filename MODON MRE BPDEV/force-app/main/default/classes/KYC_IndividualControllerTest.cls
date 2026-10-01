@isTest
private class KYC_IndividualControllerTest {
    
    // Utility method to create a Person Account
    private static Account createTestPersonAccount() {
        // Get the Person Account record type
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1];
        
        Account pa = new Account(
            RecordTypeId = rt.Id,
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = 'john.doe@test.com',
            PersonMobilePhone = '971500000001',
            Nationality__pc = 'United Arab Emirates',
            PersonBirthdate = Date.newInstance(1985, 12, 8),
            UAE_Resident_Status__pc = 'Resident',
            EIDNumber__pc = '784-1985-1234567-1',
            PassportNumber__pc = 'P1234567',
            EmployerBusinessName__pc = 'Test Employer',
            Employment_Status__c = 'Employed',
            Occupation__pc = 'Software Engineer',
            OtherSourceOfIncome__pc = 'Investments',
            Do_you_hold_dual_nationality__pc = 'No',
            SourceOfIncome__pc = 'Salary'
        );
        insert pa;
        
        return pa;
    }
    
    @isTest
    static void testControllerWithAccountId() {
        Account pa = createTestPersonAccount();
        
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/dummyPage');
        pageRef.getParameters().put('id', pa.Id);
        Test.setCurrentPage(pageRef);
        
        KYC_IndividualController ctrl = new KYC_IndividualController();
        Test.stopTest();
    }
    
    @isTest
    static void testControllerWithoutAccountId() {
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/dummyPage');
        Test.setCurrentPage(pageRef);
        
        KYC_IndividualController ctrl = new KYC_IndividualController();
        Test.stopTest();
    }
    
    @isTest
    static void testControllerWithInvalidId() {
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/dummyPage');
        pageRef.getParameters().put('id', '001000000000000'); // fake Account Id
        Test.setCurrentPage(pageRef);
        
        KYC_IndividualController ctrl = new KYC_IndividualController();
        Test.stopTest();
    }
}