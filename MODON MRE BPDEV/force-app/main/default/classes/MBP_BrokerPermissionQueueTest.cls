@isTest
private class MBP_BrokerPermissionQueueTest {

    @TestSetup
    static void setup(){
        // Create permission sets matching the constants if they don't exist.
        // NOTE: PermissionSets normally already exist in the org; create only
        // if your org allows. If they exist by name, this block can be removed.
        List<PermissionSet> psList = new List<PermissionSet>{
            new PermissionSet(Name = BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                              Label = 'Modon Limited Login'),
            new PermissionSet(Name = BRConstants.MODON_AGENT_ACCESS,
                              Label = 'Modon Agent'),
            new PermissionSet(Name = BRConstants.MODON_AGENCY_OWNER_ACCESS,
                              Label = 'Modon Agency Owner'),
            new PermissionSet(Name = BRConstants.MODON_AGENCY_ADMIN_ACCESS,
                              Label = 'Modon Agency Admin')
        };
        // Only insert ones not already present
        Set<String> existing = new Set<String>();
        for(PermissionSet ps : [SELECT Name FROM PermissionSet
                                 WHERE Name IN (:BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                                                :BRConstants.MODON_AGENT_ACCESS,
                                                :BRConstants.MODON_AGENCY_OWNER_ACCESS,
                                                :BRConstants.MODON_AGENCY_ADMIN_ACCESS)]){
            existing.add(ps.Name);
        }
        List<PermissionSet> toInsert = new List<PermissionSet>();
        for(PermissionSet ps : psList){
            if(!existing.contains(ps.Name)){
                toInsert.add(ps);
            }
        }
        if(!toInsert.isEmpty()){
            insert toInsert;
        }
    }

    // Helper to build an account + broker contact + portal user
    static User createBrokerUser(String agencyStatus, String brokerType,
                                 String agentStatus, String emailSeed){

        Account acc = new Account(
            Name = 'Agency ' + emailSeed,
            Agency_Status__c = agencyStatus
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Broker ' + emailSeed,
            AccountId = acc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = brokerType,
            Agent_Status__c = agentStatus
        );
        insert con;

        Profile p = [SELECT Id FROM Profile
                     WHERE UserType = 'PowerPartner' LIMIT 1];

        User u = new User(
            ContactId = con.Id,
            ProfileId = p.Id,
            FirstName = 'Test',
            LastName = 'User ' + emailSeed,
            Email = emailSeed + '@truestatestest.com',
            Username = emailSeed + System.currentTimeMillis() + '@truestatestest.com',
            Alias = (emailSeed.length() > 5 ? emailSeed.substring(0,5) : emailSeed),
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai',
            IsActive = true
        );
        insert u;

        return u;
    }

    @isTest
    static void testActiveOwner(){
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account acc;
        System.runAs(adminUser){
            acc = buildAgency('Active', 'Owner', 'Active', 'ownerA');
        }
        runQueue(new Set<Id>{ acc.Id });

        // Owner on Active agency should be active with owner access
        User u = [SELECT Id, IsActive FROM User
                  WHERE ContactId IN (SELECT Id FROM Contact WHERE AccountId = :acc.Id)
                  LIMIT 1];
        System.assertEquals(true, u.IsActive, 'Owner should be active');

        List<PermissionSetAssignment> psa = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :u.Id
            AND PermissionSet.Name = :BRConstants.MODON_AGENCY_OWNER_ACCESS
        ];
        System.assert(!psa.isEmpty(), 'Owner access PSA expected');
    }

    @isTest
    static void testActiveAgencyAdmin(){
        Account acc = buildAgency('Active', 'Agency Admin', 'Active', 'adminA');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(true, u.IsActive);
        System.assert(!psaFor(u.Id, BRConstants.MODON_AGENCY_ADMIN_ACCESS).isEmpty());
    }

    @isTest
    static void testActiveAgent(){
        Account acc = buildAgency('Active', 'Agent', 'Active', 'agentA');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(true, u.IsActive);
        System.assert(!psaFor(u.Id, BRConstants.MODON_AGENT_ACCESS).isEmpty());
    }

    @isTest
    static void testActiveAgencyBlockedAgent(){
        Account acc = buildAgency('Active', 'Agent', 'Blocked', 'blockedA');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(false, u.IsActive, 'Blocked agent should be inactive');
    }

    @isTest
    static void testPendingVerificationOwner(){
        Account acc = buildAgency('Pending Verification', 'Owner', 'Active', 'pendOwn');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(true, u.IsActive);
        System.assert(!psaFor(u.Id, BRConstants.MODON_LIMITED_LOGIN_ACCESS).isEmpty(),
                      'Pending owner should get limited login access');
    }

    @isTest
    static void testPendingVerificationAgent(){
        // Plain agent on pending agency -> inactive (falls into else branch)
        Account acc = buildAgency('Pending Verification', 'Agent', 'Active', 'pendAgt');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(false, u.IsActive);
    }

    @isTest
    static void testPendingVerificationBlocked(){
        Account acc = buildAgency('Pending Verification', 'Owner', 'Blocked', 'pendBlk');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        System.assertEquals(false, u.IsActive);
    }

    @isTest
    static void testInactiveAgency(){
        Account acc = buildAgency('In Active', 'Owner', 'Active', 'inactA');
        runQueue(new Set<Id>{ acc.Id });
        System.assertEquals(false, userForAccount(acc.Id).IsActive);
    }

    @isTest
    static void testSuspendedAgency(){
        Account acc = buildAgency('Suspended', 'Owner', 'Active', 'suspA');
        runQueue(new Set<Id>{ acc.Id });
        System.assertEquals(false, userForAccount(acc.Id).IsActive);
    }

    @isTest
    static void testRejectedAgency(){
        Account acc = buildAgency('Rejected', 'Owner', 'Active', 'rejA');
        runQueue(new Set<Id>{ acc.Id });
        System.assertEquals(false, userForAccount(acc.Id).IsActive);
    }

    @isTest
    static void testBlockedAgency(){
        Account acc = buildAgency('Blocked', 'Owner', 'Active', 'blkA');
        runQueue(new Set<Id>{ acc.Id });
        System.assertEquals(false, userForAccount(acc.Id).IsActive);
    }

    @isTest
    static void testContactWithoutUser(){
        // Contact but no portal user -> should be skipped without error
        Account acc = new Account(Name = 'No User Agency', Agency_Status__c = 'Active');
        insert acc;
        Contact con = new Contact(
            LastName = 'Orphan',
            AccountId = acc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Agent',
            Agent_Status__c = 'Active'
        );
        insert con;

        Test.startTest();
        System.enqueueJob(new MBP_BrokerPermissionQueue(new Set<Id>{ acc.Id }));
        Test.stopTest();
        // No exception = pass
        System.assert(true);
    }

    // ---------- helpers ----------

    static Account buildAgency(String agencyStatus, String brokerType,
                               String agentStatus, String seed){
        Account acc = new Account(Name = 'Agency ' + seed, Agency_Status__c = agencyStatus);
        insert acc;

        Contact con = new Contact(
            LastName = 'Broker ' + seed,
            AccountId = acc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = brokerType,
            Agent_Status__c = agentStatus
        );
        insert con;

        Profile p = [SELECT Id FROM Profile WHERE UserType = 'PowerPartner' LIMIT 1];
        User u = new User(
            ContactId = con.Id,
            ProfileId = p.Id,
            FirstName = 'Test',
            LastName = 'User ' + seed,
            Email = seed + '@truestatestest.com',
            Username = seed + System.currentTimeMillis() + '@truestatestest.com',
            Alias = seed.length() > 8 ? seed.substring(0,8) : seed,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai'
        );
        insert u;
        return acc;
    }

    static void runQueue(Set<Id> accountIds){
        Test.startTest();
        System.enqueueJob(new MBP_BrokerPermissionQueue(accountIds));
        Test.stopTest();
    }

    static User userForAccount(Id accId){
        return [SELECT Id, IsActive FROM User
                WHERE ContactId IN (SELECT Id FROM Contact WHERE AccountId = :accId)
                LIMIT 1];
    }

    static List<PermissionSetAssignment> psaFor(Id userId, String psName){
        return [SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :userId AND PermissionSet.Name = :psName];
    }

    // 29 Sep 2026: on an Active agency, an owner waiting for the trade licence keeps the limited login.
    @isTest
    static void testActiveAgencyPendingTradeLicenseOwner(){
        Account acc = buildAgency('Active', 'Owner', MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE, 'ptlOwner');
        runQueue(new Set<Id>{ acc.Id });

        User u = userForAccount(acc.Id);
        Assert.isTrue(u.IsActive, 'The waiting owner should stay active');
        Assert.isFalse(psaFor(u.Id, BRConstants.MODON_LIMITED_LOGIN_ACCESS).isEmpty(), 'The waiting owner should have limited access');
        Assert.isTrue(psaFor(u.Id, BRConstants.MODON_AGENCY_OWNER_ACCESS).isEmpty(), 'The waiting owner must not get full owner access');
    }
}