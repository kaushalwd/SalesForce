@isTest
public class Mbp_BrokerUserFreezeQueueTest {

    @testSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Broker Account');
        insert acc;

        List<Contact> contacts = new List<Contact>{
            // Active + Owner  -> activate + Owner perm set
            new Contact(LastName='Active Owner', AccountId=acc.Id, Agent_Status__c='Active', Broker_Type__c='Owner'),
            // Active + Agency Admin -> activate + Admin perm set
            new Contact(LastName='Active Admin', AccountId=acc.Id, Agent_Status__c='Active', Broker_Type__c='Agency Admin'),
            // Active + Agent -> activate + Agent perm set
            new Contact(LastName='Active Agent', AccountId=acc.Id, Agent_Status__c='Active', Broker_Type__c='Agent'),
            // Pending Verification + Owner -> activate + Limited Login perm set
            new Contact(LastName='Pending Owner', AccountId=acc.Id, Agent_Status__c='Pending Verification', Broker_Type__c='Owner'),
            // Blocked -> freeze, deactivate
            new Contact(LastName='Blocked Con', AccountId=acc.Id, Agent_Status__c='Blocked', Broker_Type__c='Agent')
        };
        insert contacts;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

        List<User> users = new List<User>();

        Integer i = 0;
        for (Contact c : contacts) {
            users.add(new User(
                Alias = 'test' + i,
                Email = 'testuser' + i + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = c.LastName,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'Asia/Dubai',
                ProfileId = p.Id,
                Username = 'tu' + i + DateTime.now().getTime() + '@test.com',
                ContactId = c.Id,
                IsActive = true
            ));
            i++;
        }
        // Isolate setup-object DML from the Contact/Account DML above
        User admin = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(admin) {
            insert users;
        }
    }

    @isTest
    static void testWithContactIds() {
        Set<Id> contactIds = new Map<Id, Contact>([SELECT Id FROM Contact]).keySet();
        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(null, contactIds));
        Test.stopTest();

        // At least the active contacts' users should be active
        System.assert(![SELECT Id FROM User WHERE IsActive = true AND ContactId != null].isEmpty());
    }

    @isTest
    static void testWithAccountIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(new Set<Id>{acc.Id}, null));
        Test.stopTest();
    }

    @isTest
    static void testWithBothAccountAndContactIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Set<Id> contactIds = new Map<Id, Contact>([SELECT Id FROM Contact]).keySet();
        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(new Set<Id>{acc.Id}, contactIds));
        Test.stopTest();
    }

    @isTest
    static void testEmptyInputEarlyReturn() {
        // Empty/null sets -> finalContactIds empty -> early return branch
        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(new Set<Id>(), new Set<Id>()));
        Test.stopTest();
    }

    @isTest
    static void testAccountWithNoContacts() {
        Account empty = new Account(Name = 'No Contacts Agency');
        insert empty;
        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(new Set<Id>{empty.Id}, null));



        Test.stopTest();
    }

    // 29 Sep 2026: an owner waiting for the agency's trade licence keeps an active user with limited access.
    @isTest
    static void testPendingTradeLicenseOwnerKeepsLimitedLogin() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact waiting = new Contact(LastName = 'Waiting Owner', AccountId = acc.Id, Broker_Type__c = 'Owner',
            Agent_Status__c = MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE);
        insert waiting;
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        User login = new User(Alias = 'waitown', Email = 'waiting.owner@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Waiting Owner', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', TimeZoneSidKey = 'Asia/Dubai',
            ProfileId = p.Id, Username = 'waitown' + DateTime.now().getTime() + '@test.com', ContactId = waiting.Id, IsActive = false);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert login;
        }

        Test.startTest();
        System.enqueueJob(new Mbp_BrokerUserFreezeQueue(null, new Set<Id>{ waiting.Id }));
        Test.stopTest();

        Assert.isTrue([SELECT IsActive FROM User WHERE Id = :login.Id].IsActive, 'The waiting owner should be active');
        Assert.areEqual(1, [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :login.Id
            AND PermissionSet.Name = :BRConstants.MODON_LIMITED_LOGIN_ACCESS], 'The waiting owner should have limited access');
    }
}