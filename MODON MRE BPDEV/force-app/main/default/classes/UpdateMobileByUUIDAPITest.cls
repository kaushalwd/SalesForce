@isTest
private class UpdateMobileByUUIDAPITest {

   private static Integer userCounter = 0;

   // Mirrors real production data: mobile-app users' Contact belongs to a
   // Person Account, since Contact.AccountId must expose PersonMobilePhone /
   // En_MobilePhone__pc for UpdateMobileByUUIDAPI's Account update to succeed.
   private static User createTestUser(String uuidVal) {

    userCounter++;
    String uniqueSuffix = String.valueOf(System.currentTimeMillis()) + userCounter;

    Id personAccountRTId = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Account' AND IsPersonType = true
        LIMIT 1
    ].Id;

    Account acc = new Account(
        RecordTypeId = personAccountRTId,
        FirstName = 'Test',
        LastName = 'Contact' + uniqueSuffix,
        PersonMobilePhone = '0501111111'
    );
    insert acc;

    Account insertedAcc = [
        SELECT Id, PersonContactId
        FROM Account
        WHERE Id = :acc.Id
    ];

    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Modon Customer Community Plus'
        LIMIT 1
    ];

    User usr = new User(
        Username = 'user' + uniqueSuffix + '@test.com',
        Alias = 'tusr',
        Email = 'user@test.com',
        LastName = 'User',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'Asia/Dubai',
        ProfileId = p.Id,
        ContactId = insertedAcc.PersonContactId,
        UUID__c = uuidVal,
        CommunityNickname = 'nick' + uniqueSuffix
    );
    insert usr;

    return usr;
}

    @isTest
    static void testSuccess() {

        String uuidVal = 'UUID001';
        User usr = createTestUser(uuidVal);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"' + uuidVal + '","mobile_number":"0509999999"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected a successful response: ' + res.responseBody.toString());

        Contact updatedCon = [SELECT MobilePhone FROM Contact WHERE Id = :usr.ContactId];
        System.assertEquals('0509999999', updatedCon.MobilePhone);

        User updatedUsr = [SELECT Phone FROM User WHERE Id = :usr.Id];
        System.assertEquals('0509999999', updatedUsr.Phone);
    }

    @isTest
    static void testEmptyBody() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testMissingUUID() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"mobile_number":"0509999999"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testMissingMobile() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"UUID001"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testUserNotFound() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"INVALIDUUID","mobile_number":"0509999999"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @isTest
    static void testMultipleUsersFound() {

        String uuidVal = 'UUID-DUP-001';
        createTestUser(uuidVal);
        createTestUser(uuidVal);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"' + uuidVal + '","mobile_number":"0509999999"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testUserWithoutContactId() {

        String uuidVal = 'UUID-NO-CONTACT-001';

        User runningUser = new User(
            Id = UserInfo.getUserId(),
            UUID__c = uuidVal
        );
        update runningUser;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"' + uuidVal + '","mobile_number":"0509999999"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testDmlFailureRollsBack() {

        String uuidVal = 'UUID-DML-FAIL-001';
        User usr = createTestUser(uuidVal);

        String tooLongMobile = '1234567890123456789012345678901234567890123456789012345';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"uuid":"' + uuidVal + '","mobile_number":"' + tooLongMobile + '"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(500, res.statusCode);

        Contact unchangedCon = [SELECT MobilePhone FROM Contact WHERE Id = :usr.ContactId];
        System.assertEquals('0501111111', unchangedCon.MobilePhone, 'Contact update should have rolled back');
    }

    @isTest
    static void testMalformedJsonBody() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/updateMobileByUUID';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{invalid-json');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UpdateMobileByUUIDAPI.updateMobileNumber();
        Test.stopTest();

        System.assertEquals(500, res.statusCode);
    }

    @isTest
    static void testUpdateUserPhoneWithNullArgs() {

        Test.startTest();
        UpdateMobileByUUIDAPI.updateUserPhone(null, '0509999999');
        UpdateMobileByUUIDAPI.updateUserPhone(UserInfo.getUserId(), null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateUserPhoneDmlFailure() {

        String tooLongMobile = '1234567890123456789012345678901234567890123456789012345';

        Test.startTest();
        UpdateMobileByUUIDAPI.updateUserPhone(UserInfo.getUserId(), tooLongMobile);
        Test.stopTest();
    }
}