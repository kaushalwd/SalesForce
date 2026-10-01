@isTest
private class MBP_PermissionSetAssignmentJobTest {

    @testSetup
    static void setupTestData() {
        // Create a test Account
        Account acc = new Account(Name = 'Test Agency');
        insert acc;

        // Create a Contact linked to the account
        Contact con = new Contact(
            LastName = 'Test Contact',
            Broker_Type__c = 'Agent', // Match expected logic in your class
            Primary_Owner__c = false,
            AccountId = acc.Id
        );
        insert con;

        // Query Profile
        //Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        //Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        List<Profile> partnerProfiles = [
    SELECT Id FROM Profile 
    WHERE Name = 'Modon - Partner Community Login User' 
    LIMIT 1
];
System.assert(!partnerProfiles.isEmpty(), 'Partner Community profile is missing.');
Profile p = partnerProfiles[0];
        

    Id userRoleId;
    try {
        userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
    } catch (Exception e) {
        userRoleId = null;
    }

        // Create a User linked to the Contact
        User u = new User(
            Username = 'testuserasdf@example.com',
            Alias = 'tuser',
            Email = 'testuserasdf@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = p.Id,
            UserRoleId = userRoleId,
            ContactId = con.Id
        );
        insert u;
    }

    @isTest
    static void testPermissionSetAssignmentQueueable() {
        // Fetch test data
        //User user = [SELECT Id, ContactId FROM User LIMIT 1];
        User user = [SELECT Id, Name, Email,ContactId FROM User WHERE Email = 'testuserasdf@example.com' LIMIT 1];
        Contact contact = [SELECT Id, Broker_Type__c, Primary_Owner__c FROM Contact WHERE Id = :user.ContactId];

        // Build input parameters
        Set<Id> userIds = new Set<Id>{ user.Id };
        Map<Id, Contact> contactsMap = new Map<Id, Contact>{ contact.Id => contact };
        Boolean isLimitedLogin = false;

        // Register mock if your actual implementation calls out (not shown in provided code)
        // Test.setMock(HttpCalloutMock.class, new YourMockClass());

        Test.startTest();
        System.enqueueJob(new MBP_PermissionSetAssignmentJob(userIds, contactsMap, isLimitedLogin));
        Test.stopTest();

        // Assert that a PermissionSetAssignment was created
        List<PermissionSetAssignment> psaList = [
            SELECT Id, AssigneeId 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :user.Id
        ];
        System.assertEquals(2, psaList.size(), 'PermissionSetAssignment should have been created.');
    }
}