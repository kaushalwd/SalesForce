@isTest
private class EoiSiteActivityServiceTest {

    private static Id visitorId;
    private static Id registrationId;
    private static final String SESSION = 'tok-activity-1';

    private static void fixture() {
        EOI_Site_Visitor__c v = new EOI_Site_Visitor__c(Identity_Key__c = 'email:nora@example.com', Verified_Email__c = 'nora@example.com');
        insert v;
        visitorId = v.Id;
        EOI_Public_Registration__c r = new EOI_Public_Registration__c(
            Status__c = 'Verified', Source__c = 'Wadeem Microsite', Email__c = 'nora@example.com',
            VerifiedChannel__c = 'Email', VerifiedAt__c = Datetime.now(), Session_Id__c = SESSION, Visitor__c = v.Id);
        insert r;
        registrationId = r.Id;
        EoiSiteActivityService.enabledOverride = true;
    }

    private static String batch() {
        return JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 't' => 1789000000000L, 'seq' => 1, 'step' => 'Identity', 'type' => 'field', 'field' => 'firstName', 'oldValue' => 'Nora', 'newValue' => 'Noora' },
            new Map<String, Object>{ 't' => 1789000001000L, 'seq' => 2, 'step' => 'Identity', 'type' => 'choice', 'field' => 'residency', 'oldValue' => 'Resident', 'newValue' => 'Non-Resident' },
            new Map<String, Object>{ 't' => 1789000002000L, 'seq' => 3, 'step' => 'EOI Selection', 'type' => 'line', 'detail' => '5 BR added (qty 2)' },
            new Map<String, Object>{ 't' => 1789000003000L, 'seq' => 4, 'step' => 'Payment', 'type' => 'step', 'oldValue' => 'EOI Selection', 'newValue' => 'Payment' },
            new Map<String, Object>{ 't' => 1789000004000L, 'seq' => 5, 'step' => 'Payment', 'type' => 'terms' },
            new Map<String, Object>{ 't' => 1789000005000L, 'seq' => 6, 'step' => 'Payment', 'type' => 'bogus' }
        });
    }

    @isTest
    static void writesOneTaskPerBatchWithValuesAsTyped() {
        fixture();
        Test.startTest();
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', batch(), 'Wadeem Microsite');
        Test.stopTest();
        List<Task> rows = [SELECT Subject, Description, WhatId, EOI_Site_Registration__c, EOI_Site_Activity_Key__c, Status FROM Task WHERE EOI_Site_Activity_Key__c != null];
        System.assertEquals(1, rows.size(), 'one Task per batch, never one per event');
        Task t = rows[0];
        System.assertEquals(visitorId, t.WhatId);
        System.assertEquals(registrationId, t.EOI_Site_Registration__c);
        System.assertEquals('Wadeem: Activity: Payment (5 changes)', t.Subject, 'unknown event types are dropped from the count');
        System.assert(t.Description.contains('First name: Nora → Noora'), 'values stored as typed (MODON decision): ' + t.Description);
        System.assert(t.Description.contains('Residency: Resident → Non-Resident'));
        System.assert(t.Description.contains('Residence 5 BR added (qty 2)'));
        System.assert(t.Description.contains('Step: EOI Selection → Payment'));
        System.assert(t.Description.contains('Terms & Conditions accepted'));
        System.assert(!t.Description.contains('---') && !t.Description.contains('"events"'), 'MEOI-ACT4: no JSON copy in the description: ' + t.Description);
        System.assertEquals(String.valueOf(registrationId) + ':1-6', t.EOI_Site_Activity_Key__c);
    }

    @isTest
    static void retriedBatchUpdatesTheSameTask() {
        fixture();
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', batch(), 'Wadeem Microsite');
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', batch(), 'Wadeem Microsite');
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'same batch key = same Task');
        EoiSiteActivityService.record(registrationId, SESSION, '7-9', batch(), 'Wadeem Microsite');
        System.assertEquals(2, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'a new key is a new Task');
    }

    @isTest
    static void killSwitchBadSessionAndOversizeWriteNothing() {
        fixture();
        EoiSiteActivityService.record(registrationId, 'wrong-session', '1-6', batch(), 'Wadeem Microsite');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'session must match the registration');
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', 'not json', 'Wadeem Microsite');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'garbage is dropped silently');
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', batch().rightPad(EoiSiteActivityService.MAX_JSON_CHARS + 10), 'Wadeem Microsite');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'oversize batch is dropped');
        EoiSiteActivityService.enabledOverride = false;
        EoiSiteActivityService.record(registrationId, SESSION, '1-6', batch(), 'Wadeem Microsite');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c != null], 'kill switch off = nothing written');
    }

    @isTest
    static void capsEventsPerBatch() {
        fixture();
        List<Map<String, Object>> many = new List<Map<String, Object>>();
        for (Integer i = 0; i < EoiSiteActivityService.MAX_EVENTS + 50; i++) {
            // minimal events so 250 of them stay under the 16 KB guard - the event cap is what is under test
            many.add(new Map<String, Object>{ 'seq' => i, 'type' => 'field', 'field' => 'f' });
        }
        EoiSiteActivityService.record(registrationId, SESSION, 'big', JSON.serialize(many), 'Wadeem Microsite');
        Task t = [SELECT Subject FROM Task WHERE EOI_Site_Activity_Key__c != null LIMIT 1];
        System.assert(t.Subject.contains('(' + EoiSiteActivityService.MAX_EVENTS + ' changes)'), t.Subject);
    }

    @isTest
    static void configDefaultsAndClamps() {
        EoiSiteActivityService.flushSecondsOverride = null;
        EoiSiteActivityService.retentionDaysOverride = null;
        System.assert(EoiSiteActivityService.flushSeconds() >= 15 && EoiSiteActivityService.flushSeconds() <= 900);
        System.assert(EoiSiteActivityService.retentionDays() >= 1);
        EoiSiteActivityService.flushSecondsOverride = 120;
        System.assertEquals(120, EoiSiteActivityService.flushSeconds());
    }

    @isTest
    static void purgeDeletesOnlyOldActivityTasks() {
        fixture();
        EoiSiteActivityService.retentionDaysOverride = 30;
        EoiSiteActivityService.record(registrationId, SESSION, 'old', batch(), 'Wadeem Microsite');
        EoiSiteActivityService.record(registrationId, SESSION, 'new', batch(), 'Wadeem Microsite');
        Task old = [SELECT Id FROM Task WHERE EOI_Site_Activity_Key__c LIKE '%:old'];
        Test.setCreatedDate(old.Id, Datetime.now().addDays(-45));
        Task milestone = new Task(WhatId = visitorId, Subject = 'Wadeem: Verified by email', Status = 'Completed', Priority = 'Normal');
        insert milestone;
        Test.setCreatedDate(milestone.Id, Datetime.now().addDays(-45));
        Test.startTest();
        Database.executeBatch(new EoiSiteActivityPurge(), 200);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Id = :old.Id], 'old activity Task purged');
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c LIKE '%:new'], 'recent activity kept');
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Id = :milestone.Id], 'milestone Tasks are never touched');
    }

    /** MEOI-CANCEL: the customer's cancellation is a diary line of its own. */
    @isTest
    static void cancelLineReadsAsCancelled() {
        fixture();
        String ev = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 't' => 1789000000000L, 'seq' => 1, 'step' => 'My registrations', 'type' => 'cancel', 'detail' => 'EOI-1 · Select Villas · AED 10,000 (hold released)' }
        });
        EoiSiteActivityService.record(registrationId, SESSION, 'c.1-1', ev, 'Wadeem Microsite');
        Task t = [SELECT Description FROM Task WHERE EOI_Site_Activity_Key__c != null LIMIT 1];
        System.assert(t.Description.contains('Registration cancelled: EOI-1'), t.Description);
    }

    /** MEOI-TEST (11 Sep 2026): the schedulable entry point starts the purge batch. */
    @isTest
    static void scheduledEntryPointRunsThePurge() {
        fixture();
        EoiSiteActivityService.retentionDaysOverride = 30;
        EoiSiteActivityService.record(registrationId, SESSION, 'old', batch(), 'Wadeem Microsite');
        Task old = [SELECT Id FROM Task WHERE EOI_Site_Activity_Key__c LIKE '%:old'];
        Test.setCreatedDate(old.Id, Datetime.now().addDays(-45));
        Test.startTest();
        new EoiSiteActivityPurge().execute((SchedulableContext) null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Id = :old.Id], 'the scheduled run purged the old batch');
    }
}