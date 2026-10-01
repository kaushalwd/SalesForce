@isTest
private class KYC_CorporateControllerTest {

    private static Contact createTestData() {
        Account acc = new Account(
            Name = 'Test Company',
            TradeLicenseNumber__c = 'LIC12345',
            Company_Address__c = '123 Business Street',
            Company_Country_Of_Origin__c = 'UAE',
            Nature_Of_Business__c = 'Technology'
        );
        insert acc;
        
        Contact con = new Contact(
            LastName = 'Test Contact',
            Email = 'test@test.com',
            MobilePhone = '971500000000',
            Nationality__c = 'United Arab Emirates',
            Birthdate = Date.newInstance(1990, 5, 15),
            UAE_Resident_Status__c = 'Resident',
            EIDNumber__c = '784-1990-1234567-1',
            PassportNumber__c = 'A1234567',
            Do_you_hold_dual_nationality__c = 'No',
            AccountId = acc.Id
        );
        insert con;
        
        return con;
    }

    @isTest
    static void testControllerWithValidContactId() {
        Contact con = createTestData();
        PageReference pageRef = new PageReference('/apex/dummyPage');
        pageRef.getParameters().put('id', con.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        KYC_CorporateController ctrl = new KYC_CorporateController();
        ctrl.employmentStatus = 'Test Employment';
        ctrl.employerName = 'Test Employer';
        ctrl.otherInfo = 'Test Other';
        ctrl.positionField = 'Test Position';
        ctrl.sourceOfFunds = 'Test Source';
        ctrl.signatureName = 'Test Sign';
        ctrl.dateValue = Date.today().format();
        ctrl.signatureDate = '01 Jan 2025';
        Test.stopTest();
    }

    @isTest
    static void testControllerWithoutContactId() {
        PageReference pageRef = new PageReference('/apex/dummyPage');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        KYC_CorporateController ctrl = new KYC_CorporateController();
        ctrl.employmentStatus = 'Demo Employment';
        ctrl.employerName = 'Demo Employer';
        ctrl.otherInfo = 'Demo Info';
        ctrl.positionField = 'Demo Position';
        ctrl.sourceOfFunds = 'Demo Source';
        ctrl.signatureName = 'Demo Sign';
        ctrl.dateValue = Date.today().format();
        ctrl.signatureDate = Date.today().format();
        Test.stopTest();
    }

    @isTest
    static void testControllerWithInvalidContactId() {
        PageReference pageRef = new PageReference('/apex/dummyPage');
        pageRef.getParameters().put('id', '003000000000000AAA');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        KYC_CorporateController ctrl = new KYC_CorporateController();
        ctrl.employmentStatus = 'Invalid Employment';
        ctrl.employerName = 'Invalid Employer';
        ctrl.otherInfo = 'Invalid Info';
        ctrl.positionField = 'Invalid Position';
        ctrl.sourceOfFunds = 'Invalid Source';
        ctrl.signatureName = 'Invalid Sign';
        ctrl.dateValue = Date.today().format();
        ctrl.signatureDate = Date.today().format();
        Test.stopTest();
    }
}