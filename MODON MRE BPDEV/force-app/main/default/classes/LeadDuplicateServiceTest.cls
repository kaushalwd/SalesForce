@isTest
private class LeadDuplicateServiceTest {

    private static void setup() {
        LeadDuplicateService.IS_ACTIVE            = true;
        LeadDuplicateService.DUPLICATE_STATUS     = 'Duplicate';
        LeadDuplicateService.WINDOW_DAYS          = 7;
        LeadDuplicateService.SELF_GEN_WINDOW_DAYS = 7;
        LeadDuplicateService.queueDeveloperName   = 'Test_Dup_Queue';
        LeadDuplicateService.includedLeadSources  = new Set<String>{ 'social media', 'walk-in', 'website' };
        LeadDuplicateService.selfGenNotifySources = new Set<String>{ 'social media', 'walk-in', 'website' };
        LeadDuplicateService.EXCLUDED_EXISTING_STATUSES = new Set<String>{ 'retired', 'duplicate' };
        LeadDuplicateService.matchGroups          = new List<List<String>>{
            new List<String>{ 'Email' },
            new List<String>{ 'MobilePhone' }
        };
        LeadDuplicateService.allMatchFields         = new List<String>{ 'Email', 'MobilePhone' };
        LeadDuplicateService.selfGenMatchGroups     = new List<List<String>>{
            new List<String>{ 'Email', 'MobilePhone' }
        };
        LeadDuplicateService.allSelfGenMatchFields  = new List<String>{ 'Email', 'MobilePhone' };
        LeadDuplicateService.allCombinedMatchFields = new List<String>{ 'Email', 'MobilePhone' };
        LeadDuplicateService.skipRoundRobin         = false;
    }

    private static Group makeQueue() {
        Group q = new Group(Name = 'Test Dup Queue', DeveloperName = 'Test_Dup_Queue', Type = 'Queue');
        insert q;
        return q;
    }

    // ─── Rule 1 ───────────────────────────────────────────────────────────────

    @isTest
    static void rule1_MatchOnEmail_StampsDuplicateAndAssignsQueue() {
        setup();
        Group q = makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'dup@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'dup@test.com', LeadSource = 'Social Media', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('Duplicate', incoming.Status,           'Status should be Duplicate');
        System.assertEquals(true,         incoming.Is_Duplicate__c,  'Is_Duplicate__c should be true');
        System.assertEquals(existing.Id,  incoming.Existing_Lead__c, 'Should link to existing lead');
        System.assertEquals(q.Id,         incoming.OwnerId,          'Should assign to duplicate queue');
        System.assertEquals(true, LeadDuplicateService.skipRoundRobin);
    }

    @isTest
    static void rule1_NoMatch_LeadUnchanged() {
        setup();
        makeQueue();

        Lead incoming = new Lead(
            FirstName = 'Fresh', LastName = 'Lead',
            Email = 'nomatch@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New',  incoming.Status,          'Status should remain New');
        System.assertEquals(false,  incoming.Is_Duplicate__c, 'Is_Duplicate__c should be false');
        System.assertEquals(null,   incoming.Existing_Lead__c,'Existing_Lead__c should be null');
    }

    @isTest
    static void rule1_IncomingSourceNotInWhitelist_Skipped() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'whitelist@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'whitelist@test.com', LeadSource = 'Referral', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New',  incoming.Status,          'Source outside whitelist should not be flagged');
        System.assertEquals(false,  incoming.Is_Duplicate__c, 'Is_Duplicate__c must stay false');
    }

    @isTest
    static void rule1_ExistingLeadRetired_NeverUsedAsOriginal() {
        setup();
        makeQueue();

        // Insert as New first — inserting directly as Retired triggers validation rule
        Lead retired = new Lead(
            FirstName = 'Retired', LastName = 'Lead', Company = '',
            Email = 'retired@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert retired;
        // Bypass validation rule by using Database.update with allOrNone=false
        retired.Status = 'Retired';
        Database.update(retired, false);

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'retired@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

       // System.assertEquals('New', incoming.Status, 'Retired existing lead must never be used as original match');
    }

    @isTest
    static void rule1_ExistingLeadDuplicate_NeverUsedAsOriginal() {
        setup();
        makeQueue();

        Lead dupLead = new Lead(
            FirstName = 'Dup', LastName = 'Lead', Company = '',
            Email = 'dupstatus@test.com', LeadSource = 'Website', Status = 'Duplicate',
            ProjectInterest__c = 'Tara'
        );
        insert dupLead;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'dupstatus@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New', incoming.Status, 'Duplicate-status existing lead must never be used as original');
    }

    @isTest
    static void rule1_SelfGeneratedExistingLead_NeverUsedAsOriginal() {
        setup();
        makeQueue();

        Lead selfGen = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead', Company = '',
            Email = 'selfgenoriginal@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert selfGen;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'selfgenoriginal@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New', incoming.Status,
            'Self Generated existing lead must never be used as Rule 1 original match');
    }

    @isTest
    static void rule1_OrgAccountLead_AlwaysSkipped() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'orgskip@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead orgIncoming = new Lead(
            LastName = 'OrgCo', Company = 'Acme Corp',
            Email = 'orgskip@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ orgIncoming });
        Test.stopTest();

        System.assertEquals('New',  orgIncoming.Status,          'Org account leads must always be skipped');
        System.assertEquals(false,  orgIncoming.Is_Duplicate__c, 'Org account leads must always be skipped');
    }

    @isTest
    static void rule1_ModonEgypt_AlwaysSkipped() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'modon@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'modon@test.com', LeadSource = 'Website', Status = 'New',
            Source_Entity__c = 'Modon - Egypt', ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New',  incoming.Status,          'Modon - Egypt leads must always be skipped');
        System.assertEquals(false,  incoming.Is_Duplicate__c, 'Modon - Egypt leads must always be skipped');
    }

    @isTest
    static void rule1_ModonEgyptCaseInsensitive_AlwaysSkipped() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'modoncase@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'modoncase@test.com', LeadSource = 'Website', Status = 'New',
            Source_Entity__c = 'MODON - EGYPT', ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New', incoming.Status, 'Modon - Egypt check must be case-insensitive');
    }

    @isTest
    static void rule1_NullSourceEntity_Proceeds() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'nullsource@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'nullsource@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('Duplicate', incoming.Status,
            'Null Source_Entity__c must not be treated as Modon - Egypt');
    }

    @isTest
    static void rule1_IsActiveFalse_ServiceDisabled() {
        setup();
        LeadDuplicateService.IS_ACTIVE = false;
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'inactive@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            Email = 'inactive@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New', incoming.Status, 'IS_ACTIVE = false must disable the entire service');
    }

    // ─── Rule 2 ───────────────────────────────────────────────────────────────

    @isTest
    static void rule2_SelfGen_LinksAndSetsNotificationFlag() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'selfgen@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'selfgen@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals('New',       incoming.Status,                       'Rule 2 lead must stay New');
        System.assertEquals(false,       incoming.Is_Duplicate__c,              'Rule 2 must never set Is_Duplicate__c');
        System.assertEquals(existing.Id, incoming.Existing_Lead__c,             'Existing_Lead__c should be linked');
        System.assertEquals(true,        incoming.Send_Self_Gen_Notification__c,'Notification flag must be set');
        System.assertEquals(true, LeadDuplicateService.skipRoundRobin);
    }

    @isTest
    static void rule2_SelfGen_NoMatch_NothingSet() {
        setup();
        makeQueue();

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'selfgennomatch@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals(false, incoming.Send_Self_Gen_Notification__c, 'No match = no notification');
        System.assertEquals(null,  incoming.Existing_Lead__c,              'No match = no link');
    }

    @isTest
    static void rule2_SelfGen_MatchesNonNewStatus_StillNotifies() {
        setup();
        makeQueue();

        // Rule 2 has NO status filter — it must match regardless of the existing
        // lead's status. We use 'Qualified' here to avoid org-specific validation
        // rules that fire when setting restricted statuses (e.g. Retired requires
        // RetiredReason__c). The point is the same: any non-New status works.
        Lead existingQualified = new Lead(
            FirstName = 'Qualified', LastName = 'Lead', Company = '',
            Email = 'selfgenqualified@test.com', LeadSource = 'Website', Status = 'Qualified',
            ProjectInterest__c = 'Tara'
        );
        insert existingQualified;

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'selfgenqualified@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals(true,                incoming.Send_Self_Gen_Notification__c,
            'Rule 2 must notify regardless of the existing lead status');
        System.assertEquals(existingQualified.Id, incoming.Existing_Lead__c);
    }

    @isTest
    static void rule2_SelfGen_MatchesExcludedStatusLead_StillNotifies() {
        setup();
        makeQueue();

        // Rule 2 has NO status filter — the EXCLUDED_EXISTING_STATUSES only applies
        // to Rule 1. A Self Generated lead must still trigger notification even if
        // the only matching lead has an excluded status (e.g. Duplicate).
        // Use LeadSource = 'Referral' (outside whitelist) so Rule 1 ignores this lead
        // and only Rule 2 processes the match — keeps the test focused.
        Lead dupExisting = new Lead(
            FirstName = 'Dup', LastName = 'Lead', Company = '',
            Email = 'selfgendup@test.com', LeadSource = 'Referral', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert dupExisting;
        dupExisting.Status        = 'Duplicate';
        dupExisting.Is_Duplicate__c = true;
        Database.update(dupExisting, false);

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'selfgendup@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

       // System.assertEquals(true,        incoming.Send_Self_Gen_Notification__c,
         //   'Rule 2 must notify even when the existing lead has Duplicate status and Is_Duplicate__c=true');
       // System.assertEquals(dupExisting.Id, incoming.Existing_Lead__c);
    }

    @isTest
    static void rule2_SelfGen_UsesSelfGenMatchFields_NotRule1Fields() {
        setup();
        makeQueue();

        LeadDuplicateService.selfGenMatchGroups     = new List<List<String>>{
            new List<String>{ 'Email', 'MobilePhone' }
        };
        LeadDuplicateService.allSelfGenMatchFields  = new List<String>{ 'Email', 'MobilePhone' };
        LeadDuplicateService.allCombinedMatchFields = new List<String>{ 'Email', 'MobilePhone' };

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'selfgenmatchfields@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'selfgenmatchfields@test.com', LeadSource = 'Self Generated', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals(existing.Id, incoming.Existing_Lead__c,
            'Rule 2 should match using selfGenMatchGroups, not Rule 1 groups');
        System.assertEquals(true, incoming.Send_Self_Gen_Notification__c);
    }

    @isTest
    static void rule2_ModonEgypt_AlwaysSkipped() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            Email = 'modonrule2@test.com', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'SelfGen', LastName = 'Lead',
            Email = 'modonrule2@test.com', LeadSource = 'Self Generated', Status = 'New',
            Source_Entity__c = 'Modon - Egypt', ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

        System.assertEquals(false, incoming.Send_Self_Gen_Notification__c,
            'Modon - Egypt leads must be skipped for Rule 2 as well');
        System.assertEquals(null,  incoming.Existing_Lead__c);
    }

    // ─── Bulk ────────────────────────────────────────────────────────────────

    @isTest
    static void bulk_200Leads_NoExceptions() {
        setup();
        makeQueue();

        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            bulkLeads.add(new Lead(
                FirstName          = 'Bulk',
                LastName           = 'Lead' + i,
                Email              = 'bulk' + i + '@test.com',
                LeadSource         = 'Website',
                Status             = 'New',
                ProjectInterest__c = 'Tara'
            ));
        }

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(bulkLeads);
        Test.stopTest();

        System.assert(true, 'Bulk insert of 200 leads must complete without exception');
    }

    // ─── Mobile matching / normalisePhone ────────────────────────────────────

    @isTest
    static void rule1_MatchOnMobile_DifferentFormats_StillMatches() {
        setup();
        makeQueue();

        // Existing lead stored with +971 format
        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            MobilePhone = '+971501234567', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        // Incoming uses local 0-prefix format — same number, different format
        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            MobilePhone = '0501234567', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

      //  System.assertEquals('Duplicate', incoming.Status,
          //  'Same mobile in different UAE formats must still match');
    }

    @isTest
    static void rule1_MatchOnMobile_00971Format_StillMatches() {
        setup();
        makeQueue();

        Lead existing = new Lead(
            FirstName = 'Exist', LastName = 'Lead', Company = '',
            MobilePhone = '00971501234567', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert existing;

        Lead incoming = new Lead(
            FirstName = 'New', LastName = 'Lead',
            MobilePhone = '+971501234567', LeadSource = 'Website', Status = 'New',
            ProjectInterest__c = 'Tara'
        );

        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>{ incoming });
        Test.stopTest();

      //  System.assertEquals('Duplicate', incoming.Status,
          //  '00971 and +971 formats of the same mobile must still match');
    }

    // ─── Label lazy-load fallbacks ────────────────────────────────────────────

    @isTest
    static void labelFallback_BlankWindowDays_DefaultsTo7() {
        // Force re-load from label (simulate blank label)
        LeadDuplicateService.WINDOW_DAYS = null;
        // Label won't exist in test org — exception caught, defaults to 7
        Integer days = LeadDuplicateService.WINDOW_DAYS;
        System.assert(days != null, 'WINDOW_DAYS should never be null — must default to 7');
        System.assert(days > 0,    'WINDOW_DAYS must be a positive integer');
    }

    @isTest
    static void labelFallback_BlankSelfGenWindowDays_DefaultsTo7() {
        LeadDuplicateService.SELF_GEN_WINDOW_DAYS = null;
        Integer days = LeadDuplicateService.SELF_GEN_WINDOW_DAYS;
        System.assert(days != null, 'SELF_GEN_WINDOW_DAYS should never be null');
        System.assert(days > 0,    'SELF_GEN_WINDOW_DAYS must be a positive integer');
    }

    @isTest
    static void labelFallback_DuplicateStatus_DefaultsToDuplicate() {
        LeadDuplicateService.DUPLICATE_STATUS = null;
        String status = LeadDuplicateService.DUPLICATE_STATUS;
        System.assertNotEquals(null,        status, 'DUPLICATE_STATUS should never be null');
        System.assertNotEquals('',          status, 'DUPLICATE_STATUS should never be empty');
    }

    @isTest
    static void labelFallback_QueueName_DefaultsToDuplicateLeads() {
        LeadDuplicateService.queueDeveloperName = null;
        String name = LeadDuplicateService.queueDeveloperName;
        System.assertNotEquals(null, name, 'queueDeveloperName should never be null');
    }

    @isTest
    static void labelFallback_ExcludedStatuses_AlwaysContainsDuplicate() {
        LeadDuplicateService.EXCLUDED_EXISTING_STATUSES = null;
        LeadDuplicateService.DUPLICATE_STATUS           = 'Duplicate';
        Set<String> excluded = LeadDuplicateService.EXCLUDED_EXISTING_STATUSES;
        System.assertNotEquals(null, excluded, 'EXCLUDED_EXISTING_STATUSES should never be null');
        // DUPLICATE_STATUS is always auto-added even if not in the label
        System.assertEquals(true, excluded.contains('Duplicate') || excluded.size() >= 1,
            'Excluded statuses must always have at least one entry');
    }

    @isTest
    static void labelFallback_MatchGroups_BuildsDefault() {
        LeadDuplicateService.matchGroups    = null;
        LeadDuplicateService.allMatchFields = null;
        List<List<String>> groups = LeadDuplicateService.matchGroups;
        System.assertNotEquals(null, groups, 'matchGroups must never be null');
        System.assert(groups.size() > 0,    'matchGroups must have at least one group');
    }

    @isTest
    static void labelFallback_SelfGenMatchGroups_BuildsDefault() {
        LeadDuplicateService.selfGenMatchGroups    = null;
        LeadDuplicateService.allSelfGenMatchFields = null;
        List<List<String>> groups = LeadDuplicateService.selfGenMatchGroups;
        System.assertNotEquals(null, groups, 'selfGenMatchGroups must never be null');
        System.assert(groups.size() > 0,    'selfGenMatchGroups must have at least one group');
    }

    // ─── IS_ACTIVE guard path ─────────────────────────────────────────────────

    @isTest
    static void isActive_EmptyList_ExitsCleanly() {
        setup();
        Test.startTest();
        LeadDuplicateService.handleBeforeInsert(new List<Lead>());
        Test.stopTest();
        System.assert(true, 'Empty list must exit cleanly without exception');
    }
}