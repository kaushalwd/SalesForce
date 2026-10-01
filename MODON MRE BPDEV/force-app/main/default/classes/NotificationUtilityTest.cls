@isTest
private class NotificationUtilityTest {

    @testSetup
    static void setupData() {
        // Create User
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id
        );
        insert testUser;
        
        // reate Opportunity for required lookup
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addYears(2),
            EIDNumber__c = '784-1234-2343244-1',
            Nationality__c = 'India'
        );
        insert opp;

        // Insert Expression of Interest with required fields
        Expressionofinterest__c eoi = new Expressionofinterest__c(
         Opportunity__c = opp.Id
        );
       
        insert eoi;

        // Insert EmailTemplate inside System.runAs to avoid MIXED_DML
        System.runAs(testUser) {
            EmailTemplate dummyTemplate = new EmailTemplate(
                Name = 'DummyTemplate',
                DeveloperName = 'Receipt_Status_Change',
                TemplateType = 'text',
                Subject = 'Test Subject',
                HtmlValue = '<p>Hello World</p>',
                FolderId = UserInfo.getUserId() // Temporary assignment
            );
        insert dummyTemplate;
        }
    }

    @isTest
    static void testSendNotification_EmailOnly() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Test.startTest();
        NotificationUtility.sendNotification(
            'Receipt_Status_Change',
            new List<Id>{ u.Id },
            false, // Bell disabled
            eoi.Id,
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();
    }

    @isTest
    static void testSendNotification_BellAndEmail() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Test.startTest();
        NotificationUtility.sendNotification(
            'Receipt_Status_Change',
            new List<Id>{ u.Id },
            true, // Bell enabled
            eoi.Id,
            null,
            'Bell Title',
            'Bell Body',
            eoi.Id, // Must be valid targetId for bell notification
            'Lead_Notification' // Must match Custom Notification Type in org
        );
        Test.stopTest();
    }

    @isTest
    static void testSendNotification_UnsupportedRecipient() {
        // Simulate unsupported SObject prefix (e.g., Account -> '001')
        Id fakeAccountId = '001000000000001AAA';

        Test.startTest();
        NotificationUtility.sendNotification(
            'Receipt_Status_Change',
            new List<Id>{ fakeAccountId },
            false,
            null,
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();
    }
    @isTest
    static void testBellNotificationOnlyBlock() {
        Test.startTest();
        NotificationUtility.sendNotification(
            null,                           // No email
            new List<Id>{ UserInfo.getUserId() },
            true,                           // trigger bell
            null,                           // no whatId
            null,                           // no whoId
            'Test Bell',                    // bell title
            'Test bell notification body.', // bell body
            UserInfo.getUserId(),           // must be a real targetId
            'Lead_Merge_Notification'       // must exist in Custom Notification Types
        );
        Test.stopTest();
    }
    
    @isTest
	static void testSendNotification_WithAttachment() {
    User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

    Blob dummyPdf = Blob.valueOf('Test PDF content');
    String fileName = 'TestAttachment';

    Test.startTest();
    NotificationUtility.sendNotification(
        'Receipt_Status_Change',
        new List<Id>{ u.Id },
        false,
        eoi.Id,
        null,
        null,
        null,
        null,
        null,
        dummyPdf,
        fileName
    );
    Test.stopTest();
}
    
   @isTest
static void testSendNotification_PersonAccount() {
    // Create Person Account
    Account personAcc = new Account(
        FirstName = 'Test',
        LastName = 'Person',
        RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id
    );
    insert personAcc;

    // Create test user for runAs (required for setup object DML)
    User testUser = new User(
        FirstName = 'RunAs',
        LastName = 'User',
        Email = 'runasuser@example.com',
        Username = 'runasuser' + DateTime.now().getTime() + '@example.com',
        Alias = 'runas',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id
    );
    insert testUser;

    // Insert EmailTemplate inside runAs block
    EmailTemplate template;
    System.runAs(testUser) {
        template = new EmailTemplate(
            Name = 'PersonAccTemplate',
            DeveloperName = 'PersonAccTemplate',
            TemplateType = 'text',
            Subject = 'Test',
            HtmlValue = 'Test',
            FolderId = UserInfo.getUserId() // temp workaround
        );
        insert template;
    }

    Test.startTest();
    NotificationUtility.sendNotification(
        'PersonAccTemplate',
        new List<Id>{ personAcc.Id },
        false,
        null,
        null,
        null,
        null,
        null,
        null
    );
    Test.stopTest();
}




}