@isTest
private class EoiJourneyLogTest {

    private static EOI_Site_Visitor__c visitor() {
        EOI_Site_Visitor__c v = new EOI_Site_Visitor__c(
            Identity_Key__c = EoiSiteVisitorService.identityKey('Email', 'log@example.com'),
            Identity_Type__c = 'Email', Verified_Email__c = 'log@example.com',
            First_Source__c = 'Wadeem Microsite', Visit_Count__c = 1, Verified_Count__c = 1
        );
        insert v;
        return v;
    }

    @isTest
    static void oneEventWritesOneTaskWithSitePrefix() {
        EOI_Site_Visitor__c v = visitor();
        Test.startTest();
        EoiJourneyLog.log(v.Id, null, 'Wadeem Microsite', EoiJourneyLog.VERIFIED_EMAIL, 'lo•••@example.com · new visitor');
        Test.stopTest();
        List<Task> rows = [SELECT Subject, Status, Description, EOI_Site_Source__c, RecordType.DeveloperName FROM Task WHERE WhatId = :v.Id];
        System.assertEquals(1, rows.size());
        System.assertEquals('Wadeem: Verified by email', rows[0].Subject);
        System.assertEquals('Completed', rows[0].Status);
        System.assertEquals('Wadeem Microsite', rows[0].EOI_Site_Source__c);
        System.assertEquals('General_Task', rows[0].RecordType.DeveloperName);
        System.assert(rows[0].Description.contains('new visitor'));
    }

    @isTest
    static void adibAndUnknownSourcesGetTheirOwnPrefix() {
        System.assertEquals('ADIB: ', EoiJourneyLog.prefix('ADIB Microsite'));
        System.assertEquals('EOI: ', EoiJourneyLog.prefix('Public Microsite'));
        System.assertEquals('EOI: ', EoiJourneyLog.prefix(null));
    }

    @isTest
    static void fiftyQueuedEntriesCostOneStatement() {
        EOI_Site_Visitor__c v = visitor();
        for (Integer i = 0; i < 50; i++) {
            EoiJourneyLog.queue(v.Id, null, 'Wadeem Microsite', EoiJourneyLog.VISIT_CLOSED, 'row ' + i);
        }
        Test.startTest();
        Integer before = Limits.getDmlStatements();
        EoiJourneyLog.flush();
        Integer used = Limits.getDmlStatements() - before;
        Test.stopTest();
        System.assertEquals(1, used);
        System.assertEquals(50, [SELECT COUNT() FROM Task WHERE WhatId = :v.Id]);
    }

    @isTest
    static void nothingWritableWritesNothingAndNeverThrows() {
        EOI_Site_Visitor__c v = visitor();
        Test.startTest();
        EoiJourneyLog.log(null, null, 'Wadeem Microsite', EoiJourneyLog.VERIFIED_EMAIL, 'orphan');
        EoiJourneyLog.log(v.Id, null, 'Wadeem Microsite', null, 'no subject');
        EoiJourneyLog.write(new List<EoiJourneyLog.Entry>());
        EoiJourneyLog.write(null);
        EoiJourneyLog.log(v.Id, null, 'Wadeem Microsite', 'x'.repeat(400), 'y'.repeat(40000));
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :v.Id], 'only the oversize row, trimmed');
    }

    @isTest
    static void immediateEventLandsAsTaskAfterDelivery() {
        EOI_Site_Visitor__c v = visitor();
        Test.startTest();
        EoiJourneyLog.logImmediate(v.Id, null, 'ADIB Microsite', EoiJourneyLog.PAYMENT_NOT_COMPLETED, 'CKO-1 · Declined');
        Test.getEventBus().deliver();
        Test.stopTest();
        Task row = [SELECT Subject, Description FROM Task WHERE WhatId = :v.Id LIMIT 1];
        System.assertEquals('ADIB: Payment not completed', row.Subject);
        System.assert(row.Description.contains('CKO-1'));
    }

    @isTest
    static void switchedOffWritesNothing() {
        EOI_Site_Visitor__c v = visitor();
        EoiJourneyLog.enabled = false;
        Test.startTest();
        EoiJourneyLog.log(v.Id, null, 'Wadeem Microsite', EoiJourneyLog.VERIFIED_EMAIL, 'off');
        EoiJourneyLog.logImmediate(v.Id, null, 'Wadeem Microsite', EoiJourneyLog.VERIFIED_EMAIL, 'off');
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :v.Id]);
    }
}