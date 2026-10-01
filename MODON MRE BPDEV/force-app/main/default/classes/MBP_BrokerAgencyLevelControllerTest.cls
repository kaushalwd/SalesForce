@isTest
private class MBP_BrokerAgencyLevelControllerTest {

    @testSetup
    static void createTestData() {

        Account acc = new Account(
            Name = 'Test Agency'
        );
        insert acc;

        Contact ownerCon = new Contact(
            LastName = 'Primary Owner',
            AccountId = acc.Id,
            Broker_Type__c = 'Owner',
            Primary_Owner__c = true,
            Email = 'owner@test.com',
            Phone = '+918897664052'
        );
        insert ownerCon;

        Contact agentCon = new Contact(
            LastName = 'Test Agent',
            AccountId = acc.Id,
            Email = 'agent@test.com'
        );
        insert agentCon;
    }

    @isTest
    static void testUpdateAgencyStatus() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        MBP_BrokerAgencyLevelController.updateAgencyStatus(
            acc.Id,
            'Active',
            'All documents verified'
        );

        Test.stopTest();

        Account updatedAcc = [
            SELECT Agency_Status__c,
                   Agency_Status_Reason__c
            FROM Account
            WHERE Id = :acc.Id
        ];

       
    }

    @isTest
    static void testUpdateAgentStatus() {

        Contact con = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'Test Agent'
            LIMIT 1
        ];

        Test.startTest();

        MBP_BrokerAgencyLevelController.updateAgentStatus(
            con.Id,
            'Active',
            'License Valid'
        );

        Test.stopTest();

        Contact updatedCon = [
            SELECT Agent_Status__c,
                   Agent_Status_Reason__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.assertEquals(
            'Active',
            updatedCon.Agent_Status__c
        );
        System.assertEquals(
            'License Valid',
            updatedCon.Agent_Status_Reason__c
        );
    }

    @isTest
    static void testGetAgencyDetails() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        Account result =
            MBP_BrokerAgencyLevelController.getAgencyDetails(acc.Id);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(acc.Id, result.Id);
    }

    @isTest
    static void testGetAgentDetails() {

        Contact con = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'Test Agent'
            LIMIT 1
        ];

        Test.startTest();

        Contact result =
            MBP_BrokerAgencyLevelController.getAgentDetails(con.Id);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(con.Id, result.Id);
    }

    @isTest
    static void testGetPrimaryOwner_Found() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        MBP_BrokerAgencyLevelController.OwnerWrapper result =
            MBP_BrokerAgencyLevelController.getPrimaryOwner(acc.Id);

        Test.stopTest();

       
    }

    @isTest
    static void testGetPrimaryOwner_NotFound() {

        Account acc = new Account(Name = 'No Owner Agency');
        insert acc;

        Test.startTest();

        MBP_BrokerAgencyLevelController.OwnerWrapper result =
            MBP_BrokerAgencyLevelController.getPrimaryOwner(acc.Id);

        Test.stopTest();

        System.assertEquals(false, result.hasPrimaryOwner);
    }
    
    
    @isTest
static void testActivateAgency_Active() {

    Account acc = new Account(
        Name='Agency Active',
        RecordTypeId = BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c = 'Active'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent1',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Pending Verification'
    );
    insert con;

    Account oldAcc = acc.clone(false, true, false, false);
    oldAcc.Agency_Status__c = 'Pending Verification';

    Map<Id,SObject> oldMap = new Map<Id,SObject>{
        acc.Id => oldAcc
    };

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue = true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        oldMap
    );

    Test.stopTest();

    Contact updatedCon = [
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

    System.assertEquals(
        'Active',
        updatedCon.Agent_Status__c
    );
}
    
    @isTest
static void testActivateAgency_InActive() {

    Account acc = new Account(
        Name='Agency Inactive',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='In Active'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent2',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Active'
    );
    insert con;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue=true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    Contact updatedCon=[
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

    System.assertEquals('In Active',updatedCon.Agent_Status__c);
}
    
    @isTest
static void testActivateAgency_Suspended() {

    Account acc = new Account(
        Name='Agency Suspended',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='Suspended'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent3',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Active'
    );
    insert con;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue=true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    Contact updatedCon=[
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

   
}
    
    @isTest
static void testActivateAgency_Rejected() {

    Account acc = new Account(
        Name='Agency Rejected',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='Rejected'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent4',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Active'
    );
    insert con;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue=true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    Contact updatedCon=[
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

}
    
    @isTest
static void testActivateAgency_Blocked() {

    Account acc = new Account(
        Name='Agency Blocked',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='Blocked'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent5',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Active'
    );
    insert con;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue=true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    Contact updatedCon=[
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

    System.assertEquals('Blocked',updatedCon.Agent_Status__c);
}
    
    @isTest
static void testActivateAgency_PendingVerification() {

    Account acc = new Account(
        Name='Agency Pending',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='Pending Verification'
    );
    insert acc;

    Contact con = new Contact(
        LastName='Agent6',
        AccountId=acc.Id,
        RecordTypeId=BRConstants.BROKER_AGENT_RT,
        Agent_Status__c='Active'
    );
    insert con;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue=true;

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    Contact updatedCon=[
        SELECT Agent_Status__c
        FROM Contact
        WHERE Id=:con.Id
    ];

    System.assertEquals(
        'Pending Verification',
        updatedCon.Agent_Status__c
    );
}
    
    @isTest
static void testActivateAgency_NoStatusChange() {

    Account acc = new Account(
        Name='Agency No Change',
        RecordTypeId=BRConstants.BROKER_AGENCY_RT,
        Agency_Status__c='Active'
    );
    insert acc;

    Account oldAcc = acc.clone(false,true,false,false);
    oldAcc.Agency_Status__c='Active';

    Test.startTest();

    MBP_BrokerAgencyLevelController.activateInActivateAgencies(
        new List<Account>{acc},
        new Map<Id,SObject>{acc.Id=>oldAcc}
    );

    Test.stopTest();

    System.assert(true);
}
    // Add these methods to the END of MBP_BrokerAgencyLevelControllerTest,
// after testActivateAgency_NoStatusChange(). Nothing above changes.

    /* ---------------------------------------------------------------------
     * submitForApproval
     * --------------------------------------------------------------------- */

    @isTest
    static void testSubmitForApproval_SubmitsWhenCriteriaMatch() {

        Account agencyAcc = new Account(
            Name = 'Submit Approval Agency',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Owner Pending',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Pending Verification',
            Email = 'owner.pending@test.com',
            OwnerId = UserInfo.getUserId()
        );
        insert con;

        Test.startTest();

        MBP_BrokerAgencyLevelController.submitForApproval(new List<Contact>{ con });

        Test.stopTest();

        List<ProcessInstance> instances = [
            SELECT Id, Status, TargetObjectId
            FROM ProcessInstance
            WHERE TargetObjectId = :con.Id
        ];

        System.assertEquals(1, instances.size(), 'Expected exactly one approval process instance to be submitted');
    }

    @isTest
    static void testSubmitForApproval_SkipsWhenNotOwnerType() {

        Account agencyAcc = new Account(
            Name = 'Submit Approval Agency 2',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Agent Pending Not Owner',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Agent',
            Agent_Status__c = 'Pending Verification',
            Email = 'agent.pending@test.com'
        );
        insert con;

        Test.startTest();

        MBP_BrokerAgencyLevelController.submitForApproval(new List<Contact>{ con });

        Test.stopTest();

        List<ProcessInstance> instances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :con.Id
        ];

        System.assertEquals(0, instances.size(), 'Non-Owner Broker_Type__c should not be submitted for approval');
    }

    @isTest
    static void testSubmitForApproval_SkipsWhenAccountNotBrokerAgency() {

        Account plainAcc = new Account(Name = 'Not A Broker Agency');
        insert plainAcc;

        Contact con = new Contact(
            LastName = 'Owner Wrong Account',
            AccountId = plainAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Pending Verification',
            Email = 'owner.wrongacc@test.com'
        );
        insert con;

        Test.startTest();

        MBP_BrokerAgencyLevelController.submitForApproval(new List<Contact>{ con });

        Test.stopTest();

        List<ProcessInstance> instances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :con.Id
        ];

        System.assertEquals(0, instances.size(), 'Contact whose Account is not Broker Agency record type should not be submitted');
    }

    @isTest
    static void testSubmitForApproval_SkipsWhenStatusNotPending() {

        Account agencyAcc = new Account(
            Name = 'Submit Approval Agency 3',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Owner Already Active',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active',
            Email = 'owner.active@test.com'
        );
        insert con;

        Test.startTest();

        MBP_BrokerAgencyLevelController.submitForApproval(new List<Contact>{ con });

        Test.stopTest();

        List<ProcessInstance> instances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :con.Id
        ];

        System.assertEquals(0, instances.size(), 'Contact not at Pending Verification should not be submitted');
    }

    /* ---------------------------------------------------------------------
     * createPortalUserOnApproval
     * --------------------------------------------------------------------- */

    @isTest
    static void testCreatePortalUserOnApproval_EnqueuesForApprovedContact() {

        Account agencyAcc = new Account(
            Name = 'Approval Provisioning Agency',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Newly Approved',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active',
            Email = 'newlyapproved.provtest@test.com'
        );
        insert con;

        Contact oldCon = con.clone(false, true, false, false);
        oldCon.Agent_Status__c = 'Pending Verification';

        Test.startTest();

        MBP_BrokerAgencyLevelController.createPortalUserOnApproval(
            new List<Contact>{ con },
            new Map<Id, SObject>{ con.Id => oldCon }
        );

        Test.stopTest();

        List<User> createdUsers = [SELECT Id FROM User WHERE ContactId = :con.Id];
        System.assertEquals(1, createdUsers.size(), 'Expected a portal User to be created for the approved contact');
    }

    @isTest
    static void testCreatePortalUserOnApproval_SkipsWhenUserAlreadyExists() {

        Account agencyAcc = new Account(
            Name = 'Approval Provisioning Agency Existing',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Reapproved',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active',
            Email = 'reapproved.provtest@test.com'
        );
        insert con;

        // Simulate a User already created for this Contact from a first approval.
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community User' LIMIT 1];
        System.assert(!profiles.isEmpty(), 'Test org must have the Modon - Partner Community User profile configured');

        User existingUser = new User(
            Alias = 'reappr',
            Email = con.Email,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Reapproved',
            FirstName = 'Existing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_GB',
            ProfileId = profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai',
            isActive = true,
            UserName = con.Email + '.existing' + Datetime.now().getTime(),
            ContactId = con.Id
        );
        insert existingUser;

        Contact oldCon = con.clone(false, true, false, false);
        oldCon.Agent_Status__c = 'Pending Verification';

        Test.startTest();

        MBP_BrokerAgencyLevelController.createPortalUserOnApproval(
            new List<Contact>{ con },
            new Map<Id, SObject>{ con.Id => oldCon }
        );

        Test.stopTest();

        List<User> usersForContact = [SELECT Id FROM User WHERE ContactId = :con.Id];
        System.assertEquals(1, usersForContact.size(), 'Should not create a second User when one already exists for the Contact');
    }

    @isTest
    static void testCreatePortalUserOnApproval_SkipsWhenStatusTransitionNotPendingToActive() {

        Account agencyAcc = new Account(
            Name = 'Approval Provisioning Agency NoOp',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Suspended Reactivated',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active',
            Email = 'suspreact.provtest@test.com'
        );
        insert con;

        Contact oldCon = con.clone(false, true, false, false);
        oldCon.Agent_Status__c = 'Suspended'; // not Pending Verification -> should be ignored

        Test.startTest();

        MBP_BrokerAgencyLevelController.createPortalUserOnApproval(
            new List<Contact>{ con },
            new Map<Id, SObject>{ con.Id => oldCon }
        );

        Test.stopTest();

        List<User> usersForContact = [SELECT Id FROM User WHERE ContactId = :con.Id];
        System.assertEquals(0, usersForContact.size(), 'A Suspended -> Active transition should not trigger provisioning');
    }

    // ------------------------------------------------------------------------------------------------------------
    // v1.3 (29 Sep 2026): owners of agencies migrated from Oracle Fusion. An owner loaded for an Active agency
    // without an uploaded trade licence gets Pending Trade License and a limited login; uploading the licence
    // later submits Agent_Approval. Loads run as an internal loader user, as in production.
    // ------------------------------------------------------------------------------------------------------------

    private static final String MIGRATION_DOMAIN = '@ownerrouting.test';
    private static final String LOADER_PREFIX = 'owner.routing.loader';
    private static final String TRADE_LICENCE = 'TradeLicense';
    private static final List<String> AGENCY_DOCUMENTS = new List<String>{ 'TradeLicense', 'IBANLetter', 'VAT' };

    @IsTest
    static void ownerOfAgencyWithUploadedLicenceGoesToApproval() {
        User loader = createLoader();
        Contact owner;
        System.runAs(loader) {
            Account agency = insertAgency('Licensed Agency', 'Active');
            markTradeLicenceUploaded(agency.Id);
            owner = buildOwner(agency.Id, 'licensed.owner');
            Test.startTest();
            insert owner;
            Test.stopTest();
        }
        Assert.areEqual('Pending Verification', statusOf(owner.Id), 'With a licence on file the owner stays Pending Verification');
        Assert.areEqual(1, pendingApprovals(owner.Id), 'The owner should be in Agent_Approval');
        Assert.areEqual(0, [SELECT COUNT() FROM User WHERE ContactId = :owner.Id WITH SYSTEM_MODE], 'No login before approval');
    }

    @IsTest
    static void ownerOfAgencyWithoutLicenceGetsLimitedLogin() {
        User loader = createLoader();
        Contact owner;
        Account agency;
        System.runAs(loader) {
            agency = insertAgency('Unlicensed Agency', 'Active');
            owner = buildOwner(agency.Id, 'unlicensed.owner');
            Test.startTest();
            insert owner;
            Test.stopTest();
        }
        Assert.areEqual(MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE, statusOf(owner.Id), 'Without a licence the owner waits for it');
        Assert.areEqual(0, pendingApprovals(owner.Id), 'No approval until the licence is uploaded');
        Assert.areEqual(AGENCY_DOCUMENTS.size(),
            [SELECT COUNT() FROM Documents__c WHERE Account__c = :agency.Id AND Name IN :AGENCY_DOCUMENTS WITH SYSTEM_MODE],
            'The agency should have the documents My Agency uploads to');
        User login = [SELECT Id, IsActive, Profile.Name FROM User WHERE ContactId = :owner.Id WITH SYSTEM_MODE];
        Assert.isTrue(login.IsActive, 'The limited login should be active');
        Assert.areEqual(BRConstants.MODON_PARTNER_COMMUNITY_PROFILE, login.Profile.Name, 'The limited login uses the Login licence profile');
        Assert.areEqual(1,
            [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :login.Id AND PermissionSet.Name = :BRConstants.MODON_LIMITED_LOGIN_ACCESS WITH SYSTEM_MODE],
            'The login should have Modon_Limited_Login_Access');
    }

    @IsTest
    static void ownerOfAgencyThatIsNotActiveKeepsTodaysBehaviour() {
        User loader = createLoader();
        Contact owner;
        System.runAs(loader) {
            Account agency = insertAgency('Registering Agency', 'Pending Verification');
            owner = buildOwner(agency.Id, 'registering.owner');
            Test.startTest();
            insert owner;
            Test.stopTest();
        }
        Assert.areEqual('Pending Verification', statusOf(owner.Id), 'Registration agencies are not routed');
        Assert.areEqual(1, pendingApprovals(owner.Id), 'The existing approval still applies');
    }

    @IsTest
    static void uploadingTheLicenceSendsWaitingOwnerToApproval() {
        User loader = createLoader();
        Contact owner;
        System.runAs(loader) {
            Account agency = insertAgency('Uploading Agency', 'Active');
            owner = buildOwner(agency.Id, 'uploading.owner');
            insert owner;
            Test.startTest();
            markTradeLicenceUploaded(agency.Id);
            Test.stopTest();
        }
        Assert.areEqual(1, pendingApprovals(owner.Id), 'The upload should send the owner to Agent_Approval');
        Assert.areEqual(MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE, statusOf(owner.Id),
            'The owner keeps the limited status until the approval decides');
    }

    @IsTest
    static void uploadWithoutWaitingOwnersSubmitsNothing() {
        User loader = createLoader();
        Account agency;
        System.runAs(loader) {
            agency = insertAgency('Agency Without Owners', 'Active');
            Test.startTest();
            markTradeLicenceUploaded(agency.Id);
            Test.stopTest();
        }
        Set<Id> agencyContactIds = new Map<Id, Contact>([SELECT Id FROM Contact WHERE AccountId = :agency.Id WITH SYSTEM_MODE]).keySet();
        Assert.areEqual(0, [SELECT COUNT() FROM ProcessInstance WHERE TargetObjectId IN :agencyContactIds WITH SYSTEM_MODE],
            'Nothing should be sent for approval');
    }

    @IsTest
    static void approvalThatIsNotTakenIsLogged() {
        User loader = createLoader();
        System.runAs(loader) {
            Account agency = insertAgency('Resubmitted Agency', 'Active');
            markTradeLicenceUploaded(agency.Id);
            Contact owner = buildOwner(agency.Id, 'resubmitted.owner');
            insert owner;
            Contact reloaded = [
                SELECT Id, AccountId, OwnerId, RecordTypeId, Broker_Type__c, Agent_Status__c
                FROM Contact WHERE Id = :owner.Id WITH SYSTEM_MODE
            ];
            Test.startTest();
            MBP_BrokerAgencyLevelController.submitForApproval(new List<Contact>{ reloaded });
            Test.stopTest();
        }
        Assert.isTrue(
            [SELECT COUNT() FROM Logger__c WHERE ClassName__c = 'MBP_BrokerAgencyLevelController' AND MethodName__c = 'submitForApproval' WITH SYSTEM_MODE] > 0,
            'A second submission of the same owner should be logged');
    }

    @IsTest
    static void routesTwoHundredOwnersInOneLoad() {
        User loader = createLoader();
        List<Contact> owners = new List<Contact>();
        Account agency;
        System.runAs(loader) {
            agency = insertAgency('Bulk Agency', 'Active');
            for (Integer index = 0; index < 200; index++) {
                owners.add(buildOwner(agency.Id, 'bulk.owner' + index));
            }
            insert owners;
        }
        Assert.areEqual(200,
            [SELECT COUNT() FROM Contact WHERE Id IN :owners AND Agent_Status__c = :MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE WITH SYSTEM_MODE],
            'Every owner should wait for the licence');
        Assert.areEqual(AGENCY_DOCUMENTS.size(),
            [SELECT COUNT() FROM Documents__c WHERE Account__c = :agency.Id AND Name IN :AGENCY_DOCUMENTS WITH SYSTEM_MODE],
            'Placeholders should be created once per agency');
    }

    private static User createLoader() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' WITH SYSTEM_MODE LIMIT 1];
        User loader = new User(
            Username = LOADER_PREFIX + Math.abs(Crypto.getRandomInteger()) + MIGRATION_DOMAIN,
            Alias = 'orloadr',
            Email = LOADER_PREFIX + MIGRATION_DOMAIN,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai',
            LastName = 'Owner Loader',
            ProfileId = adminProfile.Id
        );
        insert loader;
        return loader;
    }

    private static Account insertAgency(String name, String agencyStatus) {
        Account agency = new Account(
            Name = name,
            RecordTypeId = BRConstants.BROKER_AGENCY_RT,
            Agency_Status__c = agencyStatus,
            Company_Email_Address__c = name.replace(' ', '.').toLowerCase() + MIGRATION_DOMAIN,
            Country__c = 'United Arab Emirates',
            City__c = 'Abu Dhabi'
        );
        insert agency;
        // Start every agency without documents, as a migrated agency usually is.
        delete [SELECT Id FROM Documents__c WHERE Account__c = :agency.Id WITH SYSTEM_MODE];
        return agency;
    }

    private static void markTradeLicenceUploaded(Id accountId) {
        List<Documents__c> documents = [
            SELECT Id FROM Documents__c WHERE Account__c = :accountId AND Name = :TRADE_LICENCE WITH SYSTEM_MODE LIMIT 1
        ];
        Documents__c tradeLicence;
        if (documents.isEmpty()) {
            tradeLicence = new Documents__c(Name = TRADE_LICENCE, Account__c = accountId, Status__c = 'Pending Upload');
            insert tradeLicence;
        } else {
            tradeLicence = documents[0];
        }
        // A real upload is its own transaction; TriggerHandler would otherwise skip a record this test already
        // inserted or updated.
        TriggerHandler.processedIds.clear();
        update new Documents__c(Id = tradeLicence.Id, Status__c = 'Uploaded');
    }

    private static Contact buildOwner(Id accountId, String emailName) {
        return new Contact(
            FirstName = 'Loaded',
            LastName = 'Owner ' + emailName,
            AccountId = accountId,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Pending Verification',
            Email = emailName + MIGRATION_DOMAIN
        );
    }

    private static String statusOf(Id contactId) {
        return [SELECT Agent_Status__c FROM Contact WHERE Id = :contactId WITH SYSTEM_MODE].Agent_Status__c;
    }

    private static Integer pendingApprovals(Id contactId) {
        return [SELECT COUNT() FROM ProcessInstance WHERE TargetObjectId = :contactId AND Status = 'Pending' WITH SYSTEM_MODE];
    }
}