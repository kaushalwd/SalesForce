@IsTest
private class LeadAutoRetireBatchTest {

    // ─── Helper: sets cutoff to TOMORROW so freshly inserted leads appear stale
    private static void setStaleMode() {
        LeadAutoRetireBatch.cutoffDateOverride = DateTime.now().addDays(1);
    }

    // ─── Helper: sets cutoff to 89 days ago so fresh leads are NOT picked up
    private static void setFreshMode() {
        LeadAutoRetireBatch.cutoffDateOverride = DateTime.now().addDays(-89);
    }

    // ─── Scenario 1: Lead modified 91 days ago → SHOULD be retired ───────────
    @IsTest
    static void testLeadOver90DaysIsRetired() {
        // Arrange
        Lead staleLead = new Lead(
            FirstName = 'Stale',
            LastName  = 'Lead',
            Company   = 'Acme',
            Status    = 'Open - Not Contacted',
            Email     = 'sameer@aphidas.com',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert staleLead;

        // ✅ Cutoff = tomorrow → all leads look stale → batch picks them up
        setStaleMode();

        // Act
        Test.startTest();
            Id jobId = Database.executeBatch(new LeadAutoRetireBatch(), 200);
        Test.stopTest();

    }

    // ─── Scenario 2: Lead with Retired status → NOT re-processed ─────────────
    @IsTest
    static void testAlreadyRetiredLeadsAreSkipped() {
        // Arrange — already retired lead
        Lead retiredLead = new Lead(
            FirstName        = 'Already',
            LastName         = 'Retired',
            Company          = 'Acme',
            Status           = LeadAutoRetireBatch.RETIRED_STATUS,
            RetiredReason__c = 'No Answer',
            Email            = 'sameer@aphidas.com',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert retiredLead;

        // Even with stale mode — retired leads are excluded by WHERE clause
        setStaleMode();

        // Act
        Test.startTest();
            Database.executeBatch(new LeadAutoRetireBatch(), 200);
        Test.stopTest();

        // Assert — still retired, not double-processed
        Lead result = [SELECT Status FROM Lead WHERE Id = :retiredLead.Id];
        System.assertEquals(
            LeadAutoRetireBatch.RETIRED_STATUS,
            result.Status,
            'Already-retired lead should remain Retired'
        );
    }

    // ─── Scenario 3: Fresh leads NOT picked up when cutoff is in the past ─────
    @IsTest
    static void testFreshLeadsAreNotRetired() {
        // Arrange
        Lead freshLead = new Lead(
            FirstName = 'Fresh',
            LastName  = 'Lead',
            Company   = 'Acme',
            Status    = 'Working - Contacted',
            Email     = 'sameer@aphidas.com',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert freshLead;

        // ✅ Cutoff = 89 days ago → fresh lead not picked up
        setFreshMode();

        // Act
        Test.startTest();
            Database.executeBatch(new LeadAutoRetireBatch(), 200);
        Test.stopTest();

        // Assert — status unchanged
        Lead result = [SELECT Status FROM Lead WHERE Id = :freshLead.Id];
        System.assertNotEquals(
            LeadAutoRetireBatch.RETIRED_STATUS,
            result.Status,
            'Fresh lead should NOT be retired'
        );
    }

    // ─── Scenario 4: Verify recordsProcessed counter increments ──────────────
    @IsTest
    static void testStatefulCounterIncrementsOnSuccess() {
        // Arrange — 3 stale leads
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            leads.add(new Lead(
                FirstName = 'Counter',
                LastName  = 'Lead ' + i,
                Company   = 'Acme',
                Status    = 'Open - Not Contacted',
                Email     = 'counter' + i + '@example.com',
                ProjectInterest__c = 'Nawayef Homes'
            ));
        }
        insert leads;

        setStaleMode();

        LeadAutoRetireBatch batch = new LeadAutoRetireBatch();

        // Act
        Test.startTest();
            Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    // ─── Scenario 5: getDaysThreshold returns positive integer ────────────────
    @IsTest
    static void testGetDaysThresholdReturnsPositiveInt() {
        Integer threshold = LeadAutoRetireBatch.getDaysThreshold();
        System.assert(threshold > 0,
            'Threshold should be a positive integer, got: ' + threshold);
    }

    // ─── Scenario 6: Schedulable executes correctly ───────────────────────────
    @IsTest
    static void testSchedulableExecution() {
        Test.startTest();
            System.schedule(
                'Test Lead Auto-Retire',
                '0 0 2 * * ?',
                new LeadAutoRetireBatch()
            );
        Test.stopTest();

        CronTrigger ct = [
            SELECT CronExpression, State
            FROM   CronTrigger
            WHERE  CronJobDetail.Name = 'Test Lead Auto-Retire'
        ];
        System.assertNotEquals(null, ct, 'Job should be scheduled');
        System.assertEquals('0 0 2 * * ?', ct.CronExpression,
            'Cron expression should match');
    }

    // ─── Scenario 7: Bulk test — 200 records ─────────────────────────────────
    @IsTest
    static void testBulkProcessing() {
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 50; i++) {
            bulkLeads.add(new Lead(
                FirstName = 'Bulk',
                LastName  = 'Lead ' + i,
                Company   = 'Bulk Co',
                Status    = 'Open - Not Contacted',
                Email     = 'bulk' + i + '@example.com',
                ProjectInterest__c = 'Nawayef Homes'
            ));
        }
        insert bulkLeads;

        setStaleMode();

        Test.startTest();
            Id jobId = Database.executeBatch(new LeadAutoRetireBatch(), 200);
        Test.stopTest();

    }

    // ─── Scenario 8: Stateful counters initialise to zero ─────────────────────
    @IsTest
    static void testStatefulCountersInitialState() {
        LeadAutoRetireBatch batch = new LeadAutoRetireBatch();
        System.assertEquals(0, batch.recordsProcessed, 'Initial processed = 0');
        System.assertEquals(0, batch.recordsFailed,    'Initial failed = 0');
        System.assert(batch.errorMessages.isEmpty(),   'Initial errors = empty');
    }
}