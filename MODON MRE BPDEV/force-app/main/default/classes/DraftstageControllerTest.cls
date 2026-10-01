@isTest
private class DraftstageControllerTest {

    @testSetup
    static void setupData() {
        // Account (Broker Agency) - not blocked
        Account acc = new Account(
            Name = 'Test Broker Agency',
            Is_Broker_Agency_Blocked__c = false
        );
        insert acc;

        // Contact linked to Account
        Contact con = new Contact(
            FirstName = 'John',
            MiddleName = 'M',
            LastName = 'Doe',
            Email = 'test@broker.com',
            AccountId = acc.Id
        );
        insert con;

        // Registration
        Registration__c reg = new Registration__c(
            Status__c = 'Draft',
            Broker_Agency__c = acc.Id,
            Company_Email_Address__c = 'test@example.com',
            Trade_License_Number__c = 'TL12345'
        );
        insert reg;

        // Service Request with Fast Track
        ServiceRequest__c sr = new ServiceRequest__c(
            Fast_Track__c = true,
            Status__c = 'New',
            Registration__c = reg.Id
        );
        insert sr;

        // Task linked to Service Request
        Task t = new Task(
            Subject = 'Review',
            Description = 'Please update your documents',
            Comments__c = 'Some comment',
            Status = 'Open',
            WhatId = sr.Id
        );
        insert t;

        // Create the portal user in setup (isolated from non-setup DML automatically in @testSetup)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        User u = new User(
            Username = 'testuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            LastName = 'lastname',
            ContactId = con.Id,
            IsActive = true
        );
        insert u;
    }

    // Helper: build a portal user with a given contact, isolated in System.runAs to avoid MIXED_DML
    static User createPortalUser(Id contactId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        User u = new User(
            Username = 'puser' + DateTime.now().getTime() + Math.round(Math.random()*10000) + '@test.com',
            Alias = 'puser',
            Email = 'puser@test.com',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            LastName = 'lastname',
            ContactId = contactId,
            IsActive = true
        );
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            insert u;
        }
        return u;
    }

    static void assignLimitedPermSet(Id userId) {
        List<PermissionSet> psList = [
            SELECT Id FROM PermissionSet WHERE Name = 'Modon_Limited_Login_Access' LIMIT 1
        ];
        if (!psList.isEmpty()) {
            User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
            System.runAs(adminUser) {
                insert new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = psList[0].Id
                );
            }
        }
    }

    // The setup user has a contact but NO limited-access perm set -> hasAccess true, isLimitedOnly false
    @isTest
    static void testNoLimitedAccess() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];

        Test.startTest();
        System.runAs(u) {
            DraftstageController.RegistrationWrapper result =
                DraftstageController.findRegistrationWithReviewComment();
            System.assertNotEquals(null, result);
            System.assertEquals(true, result.hasAccess);
            System.assertEquals(false, result.isLimitedOnly);
        }
        Test.stopTest();
    }

    // Limited access, contact exists but has NO account
    @isTest
    static void testLimitedAccessContactNoAccount() {
         // Name must not repeat the @testSetup account ('Test Broker Agency'): an org duplicate
         // rule on Account rejects the insert with DUPLICATES_DETECTED. The other tests in this
         // class already use their own distinct agency names for the same reason.
         Account acc = new Account(
            Name = 'No Account Agency',
            Is_Broker_Agency_Blocked__c = false
        );
        insert acc;
        Contact con = new Contact(FirstName = 'No', LastName = 'Account',accountid=acc.id);
        insert con;
        User u = createPortalUser(con.Id);
        assignLimitedPermSet(u.Id);

        Test.startTest();
        System.runAs(u) {
            DraftstageController.RegistrationWrapper result =
                DraftstageController.findRegistrationWithReviewComment();
            System.assertNotEquals(null, result);
            System.assertEquals(true, result.isLimitedOnly);
        }
        Test.stopTest();
    }

    // Limited access, contact + account but NO registration for that account
    @isTest
    static void testLimitedAccessNoRegistration() {
        Account acc = new Account(Name = 'Empty Agency', Is_Broker_Agency_Blocked__c = false);
        insert acc;
        Contact con = new Contact(FirstName = 'Empty', LastName = 'Reg', AccountId = acc.Id);
        insert con;
        User u = createPortalUser(con.Id);
        assignLimitedPermSet(u.Id);

        Test.startTest();
        System.runAs(u) {
            DraftstageController.RegistrationWrapper result =
                DraftstageController.findRegistrationWithReviewComment();
            System.assertNotEquals(null, result);
            System.assertEquals(true, result.isLimitedOnly);
        }
        Test.stopTest();
    }

    // Blocked broker agency branch
    @isTest
    static void testBlockedBrokerAgency() {
        Account acc = new Account(Name = 'Blocked Agency', Is_Broker_Agency_Blocked__c = true);
        insert acc;
        Contact con = new Contact(FirstName = 'Blk', LastName = 'Agency', AccountId = acc.Id);
        insert con;
        Registration__c reg = new Registration__c(
            Status__c = 'Draft',
            Broker_Agency__c = acc.Id,
            Company_Email_Address__c = 'blk@example.com',
            Trade_License_Number__c = 'TL999'
        );
        insert reg;
        // SR without fast track and no qualifying task -> covers false branches
        ServiceRequest__c sr = new ServiceRequest__c(
            Fast_Track__c = false,
            Status__c = 'New',
            Registration__c = reg.Id
        );
        insert sr;

        User u = createPortalUser(con.Id);
        assignLimitedPermSet(u.Id);

        Test.startTest();
        System.runAs(u) {
            DraftstageController.RegistrationWrapper result =
                DraftstageController.findRegistrationWithReviewComment();
            System.assertNotEquals(null, result);
            System.assertEquals(true, result.isBrokerAgencyBlocked);
            System.assertEquals(false, result.showSales);
        }
        Test.stopTest();
    }

    @isTest
    static void testWrapperConstructor() {
        DraftstageController.RegistrationWrapper w =
            new DraftstageController.RegistrationWrapper(
                null, 'comment', true, true, true, true, true, 'F', 'M', 'L'
            );
        System.assertEquals('comment', w.taskComment);
        System.assertEquals('F', w.firstName);
        System.assertEquals(true, w.isBrokerAgencyBlocked);
    }

    // ---------------------------------------------------------------------
    // shouldShowAspireLogo() - every branch. The method had no test at all.
    // ---------------------------------------------------------------------

    // Internal user: no ContactId -> plain Modon logo.
    @isTest
    static void testAspireLogoInternalUserHasNoContact() {
        Test.startTest();
        Boolean show = DraftstageController.shouldShowAspireLogo();
        Test.stopTest();
        System.assertEquals(false, show, 'An internal user has no contact, so no Aspire logo.');
    }

    // Portal user whose contact carries no Broker_Type__c -> plain logo.
    @isTest
    static void testAspireLogoBlankBrokerType() {
        Account acc = new Account(Name = 'Aspire Blank Type Agency', Is_Broker_Agency_Blocked__c = false);
        insert acc;
        Contact con = new Contact(FirstName = 'Blank', LastName = 'Type', AccountId = acc.Id);
        insert con;
        User u = createPortalUser(con.Id);

        Test.startTest();
        Boolean show;
        System.runAs(u) {
            show = DraftstageController.shouldShowAspireLogo();
        }
        Test.stopTest();
        System.assertEquals(false, show, 'No broker type means no Aspire logo.');
    }

    // Agent at any agency -> plain logo, even if the agency qualifies on tier.
    @isTest
    static void testAspireLogoAgentIsNotEligible() {
        Broker_Classification__c tier = new Broker_Classification__c(Name = 'Principal');
        insert tier;
        Account acc = new Account(
            Name = 'Aspire Agent Agency',
            Is_Broker_Agency_Blocked__c = false,
            Broker_Classification__c = tier.Id
        );
        insert acc;
        Contact con = new Contact(FirstName = 'Reg', LastName = 'Agent', AccountId = acc.Id, Broker_Type__c = 'Agent');
        insert con;
        User u = createPortalUser(con.Id);

        Test.startTest();
        Boolean show;
        System.runAs(u) {
            show = DraftstageController.shouldShowAspireLogo();
        }
        Test.stopTest();
        System.assertEquals(false, show, 'Only Owner and Agency Admin unlock the Aspire logo.');
    }

    // Owner at an agency with no classification -> effectively Standard -> plain logo.
    @isTest
    static void testAspireLogoOwnerWithoutClassification() {
        Account acc = new Account(Name = 'Aspire Unclassified Agency', Is_Broker_Agency_Blocked__c = false);
        insert acc;
        Contact con = new Contact(FirstName = 'Plain', LastName = 'Owner', AccountId = acc.Id, Broker_Type__c = 'Owner');
        insert con;
        User u = createPortalUser(con.Id);

        Test.startTest();
        Boolean show;
        System.runAs(u) {
            show = DraftstageController.shouldShowAspireLogo();
        }
        Test.stopTest();
        System.assertEquals(false, show, 'No classification means no Aspire logo.');
    }

    // Owner at a Principal agency -> Aspire logo.
    @isTest
    static void testAspireLogoOwnerAtPrincipalAgency() {
        Broker_Classification__c tier = new Broker_Classification__c(Name = 'Principal');
        insert tier;
        Account acc = new Account(
            Name = 'Aspire Principal Agency',
            Is_Broker_Agency_Blocked__c = false,
            Broker_Classification__c = tier.Id
        );
        insert acc;
        Contact con = new Contact(FirstName = 'Top', LastName = 'Owner', AccountId = acc.Id, Broker_Type__c = 'Owner');
        insert con;
        User u = createPortalUser(con.Id);

        Test.startTest();
        Boolean show;
        System.runAs(u) {
            show = DraftstageController.shouldShowAspireLogo();
        }
        Test.stopTest();
        System.assertEquals(true, show, 'An Owner at a Principal agency sees the Aspire logo.');
    }

    // ---------------------------------------------------------------------
    // findRegistrationWithReviewComment() branches with no test.
    // ---------------------------------------------------------------------

    // Internal user (no ContactId): the wrapper comes back with access and the
    // limited-only flags set, and no registration.
    @isTest
    static void testInternalUserGetsWrapperWithoutRegistration() {
        Test.startTest();
        DraftstageController.RegistrationWrapper result =
            DraftstageController.findRegistrationWithReviewComment();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.hasAccess);
        System.assertEquals(null, result.registration, 'An internal user has no broker registration.');
    }

    // 29 Sep 2026: an owner waiting for the agency's trade licence is flagged so My Agency shows Agency Info.
    @isTest
    static void testOwnerAwaitingTradeLicenceIsFlagged() {
        Account acc = new Account(Name = 'Migrated Agency', Is_Broker_Agency_Blocked__c = false);
        insert acc;
        Contact con = new Contact(FirstName = 'Waiting', LastName = 'Owner', AccountId = acc.Id, Broker_Type__c = 'Owner',
            Agent_Status__c = MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE);
        insert con;
        User u = createPortalUser(con.Id);
        assignLimitedPermSet(u.Id);

        Test.startTest();
        System.runAs(u) {
            DraftstageController.RegistrationWrapper result = DraftstageController.findRegistrationWithReviewComment();
            Assert.isTrue(result.isLimitedOnly, 'The waiting owner has limited access');
            Assert.isTrue(result.isAwaitingTradeLicence, 'The waiting owner should be flagged for Agency Info');
        }
        Test.stopTest();
    }
}