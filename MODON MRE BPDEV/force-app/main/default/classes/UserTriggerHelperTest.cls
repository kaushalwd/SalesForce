@IsTest
private class UserTriggerHelperTest {

    private static final String PARTNER_COMMUNITY_PROFILE = 'Modon - Partner Community User';
    private static final String ABU_DHABI_CITY = 'Abu Dhabi';
    private static final String DUBAI_CITY = 'Dubai';
    private static final String ABU_DHABI_BUCKET = 'Abu Dhabi Brokers';
    private static final String DUBAI_BUCKET = 'Dubai Brokers';

    // Helper: create a User on a given profile
    private static User createUserOnProfile(String profileName, String aliasPrefix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = String.valueOf(DateTime.now().getTime()) + '_' + Math.abs(Crypto.getRandomInteger());
        User u = new User(
            Alias = (aliasPrefix + 'usr').substring(0, Math.min(8, (aliasPrefix + 'usr').length())),
            Email = aliasPrefix + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = aliasPrefix + 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            UserName = aliasPrefix + uniq + '@example.com'
        );
        insert u;
        return u;
    }

    @testSetup
    static void setupTestData() {
        // Create 2 buckets (non-setup DML only here)
        insert new Bucket__c(Name = ABU_DHABI_BUCKET);
        insert new Bucket__c(Name = DUBAI_BUCKET);
    }

    @isTest
    static void testDubaiAndAbuDhabiBrokerBucketAssignments() {
        // Fetch buckets
        Map<String, Bucket__c> nameToBucket = new Map<String, Bucket__c>();
        for (Bucket__c b : [
            SELECT Id, Name, Bucket_Group_Id__c
            FROM Bucket__c
            WHERE Name IN :new Set<String>{ABU_DHABI_BUCKET, DUBAI_BUCKET}
        ]) {
            nameToBucket.put(b.Name, b);
        }

        Bucket__c abuDhabiBucket = nameToBucket.get(ABU_DHABI_BUCKET);
        Bucket__c dubaiBucket    = nameToBucket.get(DUBAI_BUCKET);

        // Create an admin user to create Groups
        User adminUser = createUserOnProfile('System Administrator', 'sys');

        // Create groups under admin context (setup objects)
        Group abuDhabiGroup;
        Group dubaiGroup;
        System.runAs(adminUser) {
            abuDhabiGroup = new Group(
                Name = 'AbuDhabi_Brokers_Group',
                DeveloperName = 'AbuDhabi_Brokers_' + DateTime.now().getTime(),
                Type = 'Regular'
            );
            dubaiGroup = new Group(
                Name = 'Dubai_Brokers_Group',
                DeveloperName = 'Dubai_Brokers_' + DateTime.now().getTime(),
                Type = 'Regular'
            );
            insert new List<Group>{ abuDhabiGroup, dubaiGroup };
        }

        // Link groups to buckets (non-setup DML)
        abuDhabiBucket.Bucket_Group_Id__c = abuDhabiGroup.Id;
        dubaiBucket.Bucket_Group_Id__c    = dubaiGroup.Id;
        update new List<Bucket__c>{ abuDhabiBucket, dubaiBucket };

        // Create Accounts, Contacts, and Partner Users
        Id brokerAgencyRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByName()
            .get('Broker Agency')
            .getRecordTypeId();

        Account abuDhabiAccount = new Account(
            Name = 'Abu Dhabi Broker Agency',
            BillingCity = ABU_DHABI_CITY,
            RecordTypeId = brokerAgencyRtId
        );
        Account dubaiAccount = new Account(
            Name = 'Dubai Broker Agency',
            BillingCity = DUBAI_CITY,
            RecordTypeId = brokerAgencyRtId
        );
        insert new List<Account>{ abuDhabiAccount, dubaiAccount };

        Contact abuDhabiContact = new Contact(
            FirstName = 'Abu',
            LastName = 'Broker',
            Email = 'abu.broker@example.com',
            AccountId = abuDhabiAccount.Id
        );
        Contact dubaiContact = new Contact(
            FirstName = 'Dubai',
            LastName = 'Broker',
            Email = 'dubai.broker@example.com',
            AccountId = dubaiAccount.Id
        );
        insert new List<Contact>{ abuDhabiContact, dubaiContact };

        Profile partnerProfile = [
            SELECT Id FROM Profile WHERE Name = :PARTNER_COMMUNITY_PROFILE LIMIT 1
        ];

        User abuDhabiUser = new User(
            Username = 'abu.broker' + System.currentTimeMillis() + '@example.com',
            Alias = 'abroker',
            Email = abuDhabiContact.Email,
            EmailEncodingKey = 'UTF-8',
            FirstName = abuDhabiContact.FirstName,
            LastName = abuDhabiContact.LastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai',
            ProfileId = partnerProfile.Id,
            ContactId = abuDhabiContact.Id
        );
        User dubaiUser = new User(
            Username = 'dubai.broker' + System.currentTimeMillis() + '@example.com',
            Alias = 'dbroker',
            Email = dubaiContact.Email,
            EmailEncodingKey = 'UTF-8',
            FirstName = dubaiContact.FirstName,
            LastName = dubaiContact.LastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai',
            ProfileId = partnerProfile.Id,
            ContactId = dubaiContact.Id
        );

        // Insert Partner Users and trigger @future logic
        Test.startTest();
        insert new List<User>{ abuDhabiUser, dubaiUser };
        Test.stopTest();

        // Validate GroupMember assignments
        Integer abuCount = [
            SELECT COUNT()
            FROM GroupMember
            WHERE GroupId = :abuDhabiGroup.Id
              AND UserOrGroupId = :abuDhabiUser.Id
        ];
        System.assertEquals(1, abuCount, 'Abu Dhabi broker should be added to Abu Dhabi group');

        Integer dubaiCount = [
            SELECT COUNT()
            FROM GroupMember
            WHERE GroupId = :dubaiGroup.Id
              AND UserOrGroupId = :dubaiUser.Id
        ];
        System.assertEquals(1, dubaiCount, 'Dubai broker should be added to Dubai group');
        
    }

    @isTest
    static void testRemoveDeactiveUserFromBucket() {
        // Admin to create groups
        User adminUser = createUserOnProfile('System Administrator', 'sys');

        // Standard user (to remove from group)
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(DateTime.now().getTime());
        User u = new User(
            Username = 'test.remove' + uniq + '@example.com',
            Alias = 'rmuser',
            Email = 'remove' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Remove',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai',
            ProfileId = stdProfile.Id
        );
        insert u;

        // Create group + membership under admin
        Group g;
        System.runAs(adminUser) {
            g = new Group(
                Name = 'Tmp_Remove_Group',
                DeveloperName = 'Tmp_Remove_' + uniq,
                Type = 'Regular'
            );
            insert g;

            insert new GroupMember(GroupId = g.Id, UserOrGroupId = u.Id);
        }

        // Call the future removal method
        Test.startTest();
        UserTriggerHelper.removeDeactiveUserFromBucket(new Set<Id>{ u.Id });
        Test.stopTest();

        Integer cnt = [
            SELECT COUNT()
            FROM GroupMember
            WHERE GroupId = :g.Id
              AND UserOrGroupId = :u.Id
        ];
        System.assertEquals(0, cnt, 'User should be removed from group members by future');
    }
}