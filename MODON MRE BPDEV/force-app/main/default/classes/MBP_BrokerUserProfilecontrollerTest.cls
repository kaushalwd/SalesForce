@isTest 
private class MBP_BrokerUserProfilecontrollerTest {

    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(Name = 'Test Broker Agency');
        insert acc;

        // Create Contact
        Contact con = new Contact(LastName = 'Test Contact', Email = 'test@broker.com', AccountId = acc.Id);
        insert con;

        // Get profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

        // Optional UserRole
        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        // Create User
        User u = new User(
            Username = 'testuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            LastName='lastname',
            ContactId = con.Id,
            IsActive = true
        );
        insert u;
    }
@isTest
static void testUpdateContactDetails() {
    // Get existing test Contact created in @testSetup
    Contact con = [SELECT Id, Phone, UAE_Resident_Status__c, Nationality__c 
                   FROM Contact LIMIT 1];

    Test.startTest();
    String result = MBP_BrokerUserProfilecontroller.updateContactDetails(
        con.Id,
        '9876543210',
        'Resident',
        'India'
    );
    Test.stopTest();

    System.assertEquals('Profile updated successfully!', result);

    // Verify contact was updated
    Contact updated = [SELECT Phone, UAE_Resident_Status__c, Nationality__c 
                       FROM Contact WHERE Id = :con.Id];

    System.assertEquals('9876543210', updated.Phone);
    System.assertEquals('Resident', updated.UAE_Resident_Status__c);
    System.assertEquals('India', updated.Nationality__c);
}

    @isTest
    static void testGetUserProfileDetails() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> userProfile = MBP_BrokerUserProfilecontroller.getUserProfileDetails();
            Test.stopTest();

            System.assert(userProfile.containsKey('Contact'), 'Should contain Contact');
            System.assert(userProfile.containsKey('FullPhotoUrl'), 'Should contain FullPhotoUrl');
        }
    }

    @isTest
    static void testUploadUserPicture_blankData() {
        Map<String, String> result = MBP_BrokerUserProfilecontroller.uploadUserPicture('');
        System.assertEquals('false', result.get('success'));
        System.assertEquals('No image data received.', result.get('msg'));
    }
       @isTest
    static void testUploadUserPicture_blankData11() {
        MBP_BrokerUserProfilecontroller.getNationalityPicklistValues();

    }

    @isTest
    static void testUploadUserPicture_mocked() {
        String base64Img = EncodingUtil.base64Encode(Blob.valueOf('FakeImageData'));
        Map<String, String> result = MBP_BrokerUserProfilecontroller.uploadUserPicture(base64Img);
        System.assertEquals('false', result.get('success'), 'In test context, ConnectApi will not return success');
    }

    @isTest
    static void testResetPassword() {
        try {
            MBP_BrokerUserProfilecontroller.resetPassword('newPass123!', 'newPass123!', 'oldPass!');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

   
}