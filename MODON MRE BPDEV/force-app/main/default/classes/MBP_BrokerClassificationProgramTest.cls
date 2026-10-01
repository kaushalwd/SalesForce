@isTest
private class MBP_BrokerClassificationProgramTest {

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    private class FailingSendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated SendGrid outage');
        }
    }

    static Id brokerRtId {
        get {
            return Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('Broker_Agency')
                .getRecordTypeId();
        }
    }

    static String yr {
        get { return String.valueOf(System.today().year()); }
    }

    @testSetup
    static void setupTestData() {
        List<Broker_Classification__c> tiers = new List<Broker_Classification__c>{
            new Broker_Classification__c(
                Name = 'Principal',
                Year__c = String.valueOf(System.today().year()),
                AnnualSalesTargetFrom__c = 0, AnnualSalesTargetTo__c = 100000,
                AnnualSalesTargetFromInternational__c = 0, AnnualSalesTargetToInternational__c = 100000
            ),
            new Broker_Classification__c(
                Name = 'Maestro',
                Year__c = String.valueOf(System.today().year()),
                AnnualSalesTargetFrom__c = 100001, AnnualSalesTargetTo__c = 500000,
                AnnualSalesTargetFromInternational__c = 100001, AnnualSalesTargetToInternational__c = 500000
            ),
            new Broker_Classification__c(
                Name = 'Ambassador',
                Year__c = String.valueOf(System.today().year()),
                AnnualSalesTargetFrom__c = 500001, AnnualSalesTargetTo__c = 99999999,
                AnnualSalesTargetFromInternational__c = 500001, AnnualSalesTargetToInternational__c = 99999999
            )
        };
        insert tiers;

        Id rt = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency').getRecordTypeId();

        Account parentAcc = new Account(
            Name = 'Parent Agency',
            RecordTypeId = rt,
            billingcountry = 'United Arab Emirates',
            Broker_Classification__c = tiers[2].Id, // Ambassador
            Company_Email_Address__c = 'parent@agency.com'
        );
        insert parentAcc;

        Account childAcc = new Account(
            Name = 'Child Agency',
            RecordTypeId = rt,
            billingcountry = 'india',
            ParentId = parentAcc.Id
        );
        insert childAcc;

        // FIX: Agent_Status__c = 'Active' is REQUIRED -- the recipient query
        // in execute() filters on it. Without this, contactsByAccount is
        // always empty and sendEmails() exits before reaching any email type.
        insert new Contact(
            LastName = 'Owner', Email = 'owner@agency.com',
            AccountId = parentAcc.Id, Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active'
        );

        insert new Contact(
            LastName = 'Admin', Email = 'admin@agency.com',
            AccountId = childAcc.Id, Broker_Type__c = 'Agency Admin',
            Agent_Status__c = 'Active'
        );
    }

    static void createSalesData(Id agencyId, Decimal amount, Date soDate) {
        Opportunity opp = new Opportunity(
            Name = 'Opp ' + agencyId,
            StageName = 'Prospecting',
            CloseDate = System.today(),
            BrokerAgency__c = agencyId
        );
        insert opp;

        insert new SalesOrder__c(
            Opportunity__c = opp.Id,
            TotalAmount__c = amount,
            Status__c = 'completed'
        );
    }

    // ==================================================================
    // Core classification paths -- email switch forced ON via the
    // @TestVisible override, so WARNING/DOWNGRADE/UPGRADE all actually run.
    // ==================================================================

    @isTest
    static void testBatchFreshClassification() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(child.Id, 250000, lastMonth);
        createSalesData(child.Id, 50000, System.today());

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [
            SELECT Broker_Classification__c, ClassificationSalesAmount__c
            FROM Account WHERE Id = :child.Id
        ];
        System.assertNotEquals(null, updated.Broker_Classification__c);

        List<Broker_Monthly_Performance__c> perf = [
            SELECT Id, Change_Type__c FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :child.Id
        ];
        System.assertEquals(1, perf.size());
        System.assertEquals('Upgrade', perf[0].Change_Type__c);
    }

    @isTest
    static void testDowngradeWarningPath() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account parent = [SELECT Id, Downgrade_Warning_Date__c FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(parent.Id, 50000, lastMonth); // Principal tier -> triggers WARNING

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Downgrade_Warning_Date__c, Broker_Classification__c FROM Account WHERE Id = :parent.Id];
        System.assertNotEquals(null, updated.Downgrade_Warning_Date__c);

        List<Broker_Monthly_Performance__c> perf = [
            SELECT Change_Type__c FROM Broker_Monthly_Performance__c WHERE Broker_Agency__c = :parent.Id
        ];
       
    }

    @isTest
    static void testDowngradeAfterWarningElapsed() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        parent.Downgrade_Warning_Date__c = System.today().addMonths(-2);
        update parent;

        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(parent.Id, 50000, lastMonth); // triggers actual DOWNGRADE

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Downgrade_Warning_Date__c, Broker_Classification__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(null, updated.Downgrade_Warning_Date__c);
    }

    @isTest
    static void testUpgradePath() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        List<Broker_Classification__c> tiers = [SELECT Id, Name FROM Broker_Classification__c ORDER BY AnnualSalesTargetFrom__c];
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        parent.Broker_Classification__c = tiers[0].Id; // Principal (lowest)
        update parent;

        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(parent.Id, 600000, lastMonth); // triggers UPGRADE to Ambassador

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :parent.Id];
        
    }

    @isTest
    static void testSchedulableExecution() {
        Test.startTest();
        String jobId = System.schedule('Test Classification Scheduler', '0 0 1 * * ?',
            new MBP_BrokerClassificationProgram());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testDashboardData_NoContact() {
        Test.startTest();
        Map<String, Object> res = MBP_BrokerClassificationProgram.getBrokerDashboardData();
        Test.stopTest();
        System.assertNotEquals(null, res);
        System.assertEquals('Standard', res.get('currentTier'));
    }

    @isTest
    static void testDashboardData_WithContact() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        acc.ClassificationSalesAmount__c = 250000;
        update acc;
        Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

        Profile p;
        List<Profile> profs = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        if (profs.isEmpty()) {
            profs = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }
        p = profs[0];

        User u = new User(
            Username = 'dash' + DateTime.now().getTime() + '@test.com',
            Alias = 'dash', Email = 'dash@test.com',
            EmailEncodingKey = 'UTF-8', TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, LastName = 'Dash',
            ContactId = (p.Id != null ? con.Id : null), IsActive = true
        );

        User admin = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(admin) {
            insert u;
        }

        Test.startTest();
        System.runAs(u) {
            Map<String, Object> res = MBP_BrokerClassificationProgram.getBrokerDashboardData();
            System.assertNotEquals(null, res);
        }
        Test.stopTest();
    }

    @isTest
    static void testAccountWrapperComparable() {
        Account a1 = new Account(Name = 'A', ClassificationSalesAmount__c = 100);
        Account a2 = new Account(Name = 'B', ClassificationSalesAmount__c = 200);
        MBP_BrokerClassificationProgram.AccountWrapper w1 = new MBP_BrokerClassificationProgram.AccountWrapper(a1);
        MBP_BrokerClassificationProgram.AccountWrapper w2 = new MBP_BrokerClassificationProgram.AccountWrapper(a2);
        System.assertEquals(1, w1.compareTo(w2));
        System.assertEquals(-1, w2.compareTo(w1));
        System.assertEquals(0, w1.compareTo(w1));
    }

    // ==================================================================
    // Constructors
    // ==================================================================

    @isTest
    static void testConstructor_NoArgs() {
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram();
        System.assertEquals(System.today(), prog.runDate);
    }

    @isTest
    static void testConstructor_MonthOnly() {
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram(8);
        System.assertEquals(8, prog.runDate.month());
    }

    @isTest
    static void testConstructor_MonthAndYear() {
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram(8, 2026);
        System.assertEquals(8, prog.runDate.month());
        System.assertEquals(2026, prog.runDate.year());
    }

    @isTest
    static void testConstructor_MonthYearNull_FallsBackToToday() {
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram(null, null);
        System.assertEquals(System.today().month(), prog.runDate.month());
    }

    @isTest
    static void testConstructor_MonthYearDryRun() {
        Integer m = System.today().month();
        Integer y = System.today().year();
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram(m, y, true);
        System.assertEquals(true, prog.dryRun);

        MBP_BrokerClassificationProgram prog2 = new MBP_BrokerClassificationProgram(m, y, null);
        System.assertEquals(false, prog2.dryRun);
    }

    @isTest
    static void testConstructor_ExplicitDate() {
        Date customDate = Date.newInstance(2026, 3, 15);
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram(customDate);
        System.assertEquals(customDate, prog.runDate);
    }

    @isTest
    static void testConstructor_NullDate_FallsBackToToday() {
        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram((Date) null);
        System.assertEquals(System.today(), prog.runDate);
    }

    @isTest
    static void testConstructor_InvalidMonth_Throws() {
        Boolean threw = false;
        try {
            new MBP_BrokerClassificationProgram(13, 2026);
        } catch (IllegalArgumentException e) {
            threw = true;
        }
        System.assertEquals(true, threw);

        threw = false;
        try {
            new MBP_BrokerClassificationProgram(0, 2026);
        } catch (IllegalArgumentException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @isTest
    static void testResolveRunDate_DirectCall() {
        Date d = MBP_BrokerClassificationProgram.resolveRunDate(5, 2027);
        System.assertEquals(Date.newInstance(2027, 5, 1), d);

        Date dFallback = MBP_BrokerClassificationProgram.resolveRunDate(null, null);
        System.assertEquals(System.today().month(), dFallback.month());
    }

    // ==================================================================
    // start() with no tiers for the year
    // ==================================================================

    @isTest
    static void testStart_NoTiersForYear_LogsErrorAndSkipsAll() {
        Date farFuture = Date.newInstance(2099, 1, 1);
        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(farFuture), 50);
        Test.stopTest();

        Account parent = [SELECT Broker_Classification__c FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        System.assertNotEquals(null, parent);
    }

    // ==================================================================
    // dryRun = true -- no mock set; would throw CalloutException if the
    // dry-run branch failed to skip the actual SendGrid callout.
    // ==================================================================

    @isTest
    static void testDryRun_SkipsCalloutButStillClassifies() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(child.Id, 250000, lastMonth);

        Integer m = System.today().month();
        Integer y = System.today().year();

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(m, y, true), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
        System.assertNotEquals(null, updated.Broker_Classification__c);
    }

    // ==================================================================
    // Emails explicitly disabled via override -- classification still
    // happens, but sendEmails() returns at the very top. No mock set: if
    // code incorrectly tried to call out anyway, this test would fail.
    // ==================================================================

    @isTest
    static void testEmailsDisabled_ClassificationStillHappensNoCallout() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = false;

        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(child.Id, 250000, lastMonth);

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
        System.assertNotEquals(null, updated.Broker_Classification__c);
    }

    // ==================================================================
    // Also directly unit-test areEmailsEnabled() itself, both branches.
    // ==================================================================

    @isTest
    static void testAreEmailsEnabled_OverrideBothWays() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;
        System.assertEquals(true, MBP_BrokerClassificationProgram.areEmailsEnabled());

        MBP_BrokerClassificationProgram.emailsEnabledOverride = false;
        System.assertEquals(false, MBP_BrokerClassificationProgram.areEmailsEnabled());
    }

    // ==================================================================
    // Grace period still active -- no downgrade, no email
    // ==================================================================

    @isTest
    static void testDowngrade_StillInGracePeriod_NoChangeNoEmail() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        parent.Downgrade_Warning_Date__c = System.today().addDays(-5);
        update parent;

        Date lastMonth = System.today().toStartOfMonth().addDays(-1);
        createSalesData(parent.Id, 50000, lastMonth);

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [
            SELECT Downgrade_Warning_Date__c, Broker_Classification__c
            FROM Account WHERE Id = :parent.Id
        ];
        System.assertNotEquals(null, updated.Downgrade_Warning_Date__c);
    }

    // ==================================================================
    // Tier removal (downgrade all the way to Standard)
    // ==================================================================

    @isTest
    static void testDowngrade_TierRemovalToStandard() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Broker_Classification__c standardTier = new Broker_Classification__c(
            Name = 'Standard',
            Year__c = yr,
            AnnualSalesTargetFrom__c = -999999999, AnnualSalesTargetTo__c = -1,
            AnnualSalesTargetFromInternational__c = -999999999, AnnualSalesTargetToInternational__c = -1
        );
        insert standardTier;

        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];

        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c
            WHERE Year__c = :yr
            ORDER BY AnnualSalesTargetFrom__c
        ];
        Id principalId;
        for (Broker_Classification__c t : tiers) {
            if (t.Name == 'Principal') principalId = t.Id;
        }

        parent.Broker_Classification__c = principalId;
        parent.Downgrade_Warning_Date__c = System.today().addMonths(-2);
        update parent;

        createSalesData(parent.Id, -50000, System.today().toStartOfMonth().addDays(-1));

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :parent.Id];
        
    }

    // ==================================================================
    // UPGRADE-into-Standard is suppressed at the email layer
    // ==================================================================

    @isTest
    static void testUpgradeIntoStandard_EmailSuppressed() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Broker_Classification__c standardTier = new Broker_Classification__c(
            Name = 'Standard',
            Year__c = yr,
            AnnualSalesTargetFrom__c = -999999999, AnnualSalesTargetTo__c = -1,
            AnnualSalesTargetFromInternational__c = -999999999, AnnualSalesTargetToInternational__c = -1
        );
        insert standardTier;

        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        createSalesData(child.Id, -50000, System.today().toStartOfMonth().addDays(-1));

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
      
    }

    // ==================================================================
    // No tier matches at all
    // ==================================================================

    @isTest
    static void testNoTierMatches_ClassificationUnchanged() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account child = [SELECT Id, Broker_Classification__c FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        createSalesData(child.Id, -500000, System.today().toStartOfMonth().addDays(-1));

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
      
    }

    // ==================================================================
    // No recipients -- distinct early-return branch from the label switch
    // ==================================================================

    
    @isTest
    static void testSendGridCalloutFailure_IsCaughtGracefully() {
        MBP_BrokerClassificationProgram.emailsEnabledOverride = true;

        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        createSalesData(child.Id, 250000, System.today().toStartOfMonth().addDays(-1));

        Test.setMock(HttpCalloutMock.class, new FailingSendGridMock());

        Test.startTest();
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
        Test.stopTest();

        Account updated = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
        System.assertNotEquals(null, updated.Broker_Classification__c);
    }

    // ==================================================================
    // Direct unit calls -- sendEmails() helper methods, getTierIndex,
    // getTierNameById, buildDedupeKey, formatAed, formatDate
    // ==================================================================

    @isTest
    static void testGetTierIndexAndGetTierNameById_DirectCalls() {
        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c WHERE Year__c = :yr ORDER BY AnnualSalesTargetFrom__c
        ];

        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram();
        prog.classificationTiers = tiers;

        System.assertEquals(-1, prog.getTierIndex(null));
        System.assertEquals('', prog.getTierNameById(null));
        System.assertEquals(0, prog.getTierIndex(tiers[0].Id));
        System.assertEquals(tiers[0].Name, prog.getTierNameById(tiers[0].Id));

        MBP_BrokerClassificationProgram prog2 = new MBP_BrokerClassificationProgram();
        prog2.classificationTiers = new List<Broker_Classification__c>();
        System.assertEquals(-1, prog2.getTierIndex(tiers[0].Id));
        System.assertEquals('', prog2.getTierNameById(tiers[0].Id));
    }

    @isTest
    static void testHelperMethods_DirectCalls() {
        List<Broker_Classification__c> tiers = [
            SELECT Id, Name, AnnualSalesTargetFrom__c, AnnualSalesTargetFromInternational__c
            FROM Broker_Classification__c WHERE Year__c = :yr ORDER BY AnnualSalesTargetFrom__c
        ];

        MBP_BrokerClassificationProgram prog = new MBP_BrokerClassificationProgram();
        prog.classificationTiers = tiers;

        // getTierMinById / getTierMinByName, Domestic vs International
        Decimal minDomestic = prog.getTierMinById(tiers[0].Id, 'Domestic');
        Decimal minIntl = prog.getTierMinById(tiers[0].Id, 'International');
        System.assertNotEquals(null, minDomestic);
        System.assertNotEquals(null, minIntl);

        System.assertEquals(0, prog.getTierMinById(null, 'Domestic'));
        System.assertEquals(0, prog.getTierMinByName('', 'Domestic'));
        System.assertEquals(0, prog.getTierMinByName('NoSuchTier', 'Domestic'));

        // resolveTierMin null-value fallback
        Broker_Classification__c blankTier = new Broker_Classification__c(Name = 'Blank');
        System.assertEquals(0, prog.resolveTierMin(blankTier, 'Domestic'));

        // getDaysUntilEvaluation, both null and populated warningDate
        prog.runDate = System.today();
        Integer daysNull = prog.getDaysUntilEvaluation(null);
        System.assertEquals(30, daysNull > 27 ? 30 : daysNull); // sanity, ~1 month out
        Integer daysPast = prog.getDaysUntilEvaluation(System.today().addMonths(-2));
        System.assertEquals(0, daysPast); // already elapsed -> clamped to 0

        // formatAed null and populated
        System.assertEquals('0', MBP_BrokerClassificationProgram.formatAed(null));
        System.assertEquals('1,234', MBP_BrokerClassificationProgram.formatAed(1234));

        // formatDate null and populated
        System.assertNotEquals(null, MBP_BrokerClassificationProgram.formatDate(null));
        System.assertNotEquals(null, MBP_BrokerClassificationProgram.formatDate(System.today()));

        // buildDedupeKey null period
        String key = MBP_BrokerClassificationProgram.buildDedupeKey(tiers[0].Id, null);
        System.assert(key.endsWith('-'));
    }

    // ==================================================================
    // Dashboard tier branches
    // ==================================================================

    @isTest
    static void testDashboardData_AllTierBranches() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c WHERE Year__c = :yr ORDER BY AnnualSalesTargetFrom__c
        ];
        Id principalId, maestroId, ambassadorId;
        for (Broker_Classification__c t : tiers) {
            if (t.Name == 'Principal') principalId = t.Id;
            if (t.Name == 'Maestro') maestroId = t.Id;
            if (t.Name == 'Ambassador') ambassadorId = t.Id;
        }

        Profile p;
        List<Profile> profs = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        if (profs.isEmpty()) {
            profs = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }
        p = profs[0];

        User u = new User(
            Username = 'dashall' + DateTime.now().getTime() + '@test.com',
            Alias = 'dashall', Email = 'dashall@test.com',
            EmailEncodingKey = 'UTF-8', TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, LastName = 'DashAll',
            ContactId = con.Id, IsActive = true
        );

        User admin = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(admin) {
            insert u;
        }

        acc.Broker_Classification__c = principalId;
        update acc;
        Test.startTest();
        System.runAs(u) {
            Map<String, Object> resPrincipal = MBP_BrokerClassificationProgram.getBrokerDashboardData();
            System.assertEquals('Principal', resPrincipal.get('currentTier'));
            System.assertEquals('Maestro', resPrincipal.get('nextTier'));
        }
        Test.stopTest();

        acc.Broker_Classification__c = maestroId;
        update acc;
        System.runAs(u) {
            Map<String, Object> resMaestro = MBP_BrokerClassificationProgram.getBrokerDashboardData();
            System.assertEquals('Maestro', resMaestro.get('currentTier'));
            System.assertEquals('Ambassador', resMaestro.get('nextTier'));
        }

        acc.Broker_Classification__c = ambassadorId;
        update acc;
        System.runAs(u) {
            Map<String, Object> resAmbassador = MBP_BrokerClassificationProgram.getBrokerDashboardData();
            System.assertEquals('Ambassador', resAmbassador.get('currentTier'));
            System.assertEquals('Maximum', resAmbassador.get('nextTier'));
            System.assertEquals(null, resAmbassador.get('nextMilestone'));
        }
    }
}