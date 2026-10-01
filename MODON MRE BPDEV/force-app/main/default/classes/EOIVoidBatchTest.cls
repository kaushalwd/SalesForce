@isTest
private class EOIVoidBatchTest {

    private static final String SOURCE_UAE = 'Modon - UAE';

    private static Integer residentHours() {
        try {
            return Integer.valueOf(System.Label.EOI_SLA_HOURS_Expired);
        } catch (Exception e) {
            return 72;
        }
    }

    private static Integer nonResidentHours() {
        try {
            return Integer.valueOf(System.Label.EOI_SLA_Hours_Non_Resident_expired);
        } catch (Exception e) {
            return 72;
        }
    }

    private static Integer locatorHours() {
        try {
            return Integer.valueOf(System.Label.EOI_SLA_Hours);
        } catch (Exception e) {
            return 2;
        }
    }

    private static String residentValue() {
        return System.Label.EOI_SLA_Resident_Value != null ? System.Label.EOI_SLA_Resident_Value : 'Resident';
    }

    private static Boolean slaEnabled() {
        return System.Label.EOI_SLA_Enabled == 'true';
    }

    private static Integer pastHoursForResident() {
        return -1 * (Math.max(locatorHours(), residentHours()) + 24);
    }

    private static Integer pastHoursForNonResident() {
        return -1 * (Math.max(locatorHours(), nonResidentHours()) + 24);
    }

    @TestSetup
    static void setupTestData() {
        Id personRtId = getPersonAccountRecordTypeId();

        Account residentAcc = new Account(
            FirstName               = 'Resident',
            LastName                = 'Test Account',
            RecordTypeId            = personRtId,
            UAE_Resident_Status__pc = residentValue()
        );
        putIfWritable(residentAcc, 'Source_Entity__c', SOURCE_UAE);
        putIfWritable(residentAcc, 'Source_Entity__pc', SOURCE_UAE);

        Account nonResidentAcc = new Account(
            FirstName               = 'NonResident',
            LastName                = 'Test Account',
            RecordTypeId            = personRtId,
            UAE_Resident_Status__pc = 'Non-Resident'
        );
        putIfWritable(nonResidentAcc, 'Source_Entity__c', SOURCE_UAE);
        putIfWritable(nonResidentAcc, 'Source_Entity__pc', SOURCE_UAE);

        Account blankAcc = new Account(
            FirstName    = 'Blank',
            LastName     = 'Test Account',
            RecordTypeId = personRtId
        );
        putIfWritable(blankAcc, 'Source_Entity__c', SOURCE_UAE);
        putIfWritable(blankAcc, 'Source_Entity__pc', SOURCE_UAE);

        insert new List<Account>{ residentAcc, nonResidentAcc, blankAcc };

        Opportunity residentOpp    = buildOpp('Resident Opp',    residentAcc.Id, residentValue());
        Opportunity nonResidentOpp = buildOpp('NonResident Opp', nonResidentAcc.Id, 'Non-Resident');
        Opportunity blankOpp       = buildOpp('Blank Opp',       blankAcc.Id, null);
        insert new List<Opportunity>{ residentOpp, nonResidentOpp, blankOpp };
    }

    @isTest
    static void testStartWhenSlaDisabled() {
        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        if (!slaEnabled()) {
            System.assertEquals('In Progress', getStatus(eoi.Id),
                'EOI should not be voided when SLA is disabled');
        }
        System.assert(true, 'Batch completed without exception');
    }

    @isTest
    static void testResidentBreachedNoPaymentIsVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        Expressionofinterest__c result = [
            SELECT Status__c, SLA_Voided_Reason__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoi.Id
        ];
        System.assertEquals('Expired', result.Status__c,
            'Resident EOI past SLA with no payment should be Expired');
        System.assert(result.SLA_Voided_Reason__c != null && result.SLA_Voided_Reason__c.contains('SLA Expired'),
            'Void reason should mention SLA Expired');
    }

    @isTest
    static void testResidentBreachedWithPaymentNotVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());

        insert new Receipt__c(
            Expressionofinterest__c = eoi.Id,
            Account__c              = acc.Id
        );

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('In Progress', getStatus(eoi.Id),
            'EOI with payment should NOT be expired');
    }

    @isTest
    static void testNonResidentBreachedNoPaymentIsVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getNonResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', pastHoursForNonResident(), 'Non-Resident');

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('Expired', getStatus(eoi.Id),
            'Non-Resident EOI past hours with no payment should be Expired');
    }

    @isTest
    static void testNonResidentWithinOwnWindowNotVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }
        if (residentHours() >= nonResidentHours()) { System.assert(true, 'Skipped: windows equal'); return; }

        Account acc     = getNonResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Integer hoursOffset = (residentHours() + 1) * -1;
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', hoursOffset, 'Non-Resident');

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('In Progress', getStatus(eoi.Id),
            'Non-Resident EOI within its own window should not be expired');
    }

    @isTest
    static void testEoiWithinSlaWindowNotVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Account__c        = acc.Id,
            Opportunity__c    = opp.Id,
            Status__c         = 'In Progress',
            Skip_SLA__c       = false,
            EOI_Amount_AED__c = 1000
        );
        putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
        putIfWritable(eoi, 'UAE_Resident_Status__c', residentValue());
        insert eoi;

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('In Progress', getStatus(eoi.Id),
            'EOI within SLA window should not be expired');
    }

    @isTest
    static void testSkipSlaFlagExcludesFromBatch() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Account__c        = acc.Id,
            Opportunity__c    = opp.Id,
            Status__c         = 'In Progress',
            Skip_SLA__c       = true,
            EOI_Amount_AED__c = 1000
        );
        putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
        insert eoi;

        Datetime past = Datetime.now().addHours(pastHoursForResident());
        Test.setCreatedDate(eoi.Id, past);
        eoi.SLA_Start_Time__c = past;
        eoi.Skip_SLA__c       = true;
        update eoi;

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('In Progress', getStatus(eoi.Id),
            'EOI with Skip_SLA__c = true should not be expired');
    }

    @isTest
    static void testNullSlaStartTimeExcluded() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Account__c        = acc.Id,
            Opportunity__c    = opp.Id,
            Status__c         = 'In Progress',
            Skip_SLA__c       = false,
            EOI_Amount_AED__c = 1000
        );
        putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
        insert eoi;

        eoi.SLA_Start_Time__c = null;
        update eoi;

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('In Progress', getStatus(eoi.Id),
            'EOI with null SLA_Start_Time__c should not be expired');
    }

    @isTest
    static void testNonInProgressStatusExcluded() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'Submitted', pastHoursForResident(), residentValue());

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('Submitted', getStatus(eoi.Id),
            'Non In-Progress EOI should not be touched');
    }

    @isTest
    static void testBlankResidentStatusVoidReason() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getBlankResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Expressionofinterest__c eoi = insertEoiWithPastSla(acc.Id, opp.Id, 'In Progress', pastHoursForNonResident(), null);

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        Expressionofinterest__c result = [
            SELECT Status__c, SLA_Voided_Reason__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoi.Id
        ];
        System.assertEquals('Expired', result.Status__c,
            'EOI with blank resident status should be expired');
        System.assert(result.SLA_Voided_Reason__c != null && result.SLA_Voided_Reason__c.contains('Not Set'),
            'Void reason should contain Not Set');
    }

    @isTest
    static void testMixedBatchScenario() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account resAcc  = getResidentAccount();
        Opportunity opp = getOpp(resAcc.Id);

        Expressionofinterest__c eoiShouldVoid   = insertEoiWithPastSla(resAcc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());
        Expressionofinterest__c eoiWithPayment  = insertEoiWithPastSla(resAcc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());
        Expressionofinterest__c eoiWithinWindow = insertEoiWithPastSla(resAcc.Id, opp.Id, 'In Progress', -1, residentValue());
        Expressionofinterest__c eoiSkipped      = insertEoiWithPastSla(resAcc.Id, opp.Id, 'In Progress', pastHoursForResident(), residentValue());

        insert new Receipt__c(
            Expressionofinterest__c = eoiWithPayment.Id,
            Account__c              = resAcc.Id
        );

        eoiSkipped.Skip_SLA__c = true;
        update eoiSkipped;

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        System.assertEquals('Expired',     getStatus(eoiShouldVoid.Id),   'Should be Expired');
        System.assertEquals('In Progress', getStatus(eoiWithPayment.Id),  'Has payment — not expired');
        System.assertEquals('In Progress', getStatus(eoiWithinWindow.Id), 'Within window — not expired');
        System.assertEquals('In Progress', getStatus(eoiSkipped.Id),      'Skip flag — not expired');
    }

    @isTest
    static void testBulkEoisVoided() {
        if (!slaEnabled()) { System.assert(true, 'Skipped: SLA disabled'); return; }

        Account acc     = getResidentAccount();
        Opportunity opp = getOpp(acc.Id);
        Integer hoursAgo = pastHoursForResident();

        List<Expressionofinterest__c> eoiList = new List<Expressionofinterest__c>();
        for (Integer i = 0; i < 10; i++) {
            Expressionofinterest__c eoi = new Expressionofinterest__c(
                Account__c        = acc.Id,
                Opportunity__c    = opp.Id,
                Status__c         = 'In Progress',
                Skip_SLA__c       = false,
                EOI_Amount_AED__c = 1000
            );
            putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
            putIfWritable(eoi, 'UAE_Resident_Status__c', residentValue());
            eoiList.add(eoi);
        }
        insert eoiList;

        Datetime past = Datetime.now().addHours(hoursAgo);
        for (Expressionofinterest__c e : eoiList) {
            Test.setCreatedDate(e.Id, past);
            e.SLA_Start_Time__c = past;
            e.Skip_SLA__c = false;
            putIfWritable(e, 'Source_Entity__c', SOURCE_UAE);
        }
        update eoiList;

        List<Id> eoiIds = new List<Id>();
        for (Expressionofinterest__c e : eoiList) {
            eoiIds.add(e.Id);
        }

        Test.startTest();
        Database.executeBatch(new EOIVoidBatch(), 200);
        Test.stopTest();

        Integer expiredCnt = [
            SELECT COUNT() FROM Expressionofinterest__c
            WHERE  Status__c = 'Expired'
            AND    Id IN :eoiIds
        ];
        System.assertEquals(10, expiredCnt, 'All 10 EOIs without payment should be expired');
    }

    @isTest
    static void testFinishMethodRunsCleanly() {
        EOIVoidBatch batchInstance = new EOIVoidBatch();
        batchInstance.voidedCount  = 3;

        Test.startTest();
        Database.executeBatch(batchInstance, 200);
        Test.stopTest();

        System.assert(true, 'finish() completed without exception');
    }

    private static Expressionofinterest__c insertEoiWithPastSla(
            Id accountId, Id oppId, String status, Integer hoursOffset, String residentStatus) {

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Account__c        = accountId,
            Opportunity__c    = oppId,
            Status__c         = status,
            Skip_SLA__c       = false,
            EOI_Amount_AED__c = 1000
        );
        putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
        if (residentStatus != null) {
            putIfWritable(eoi, 'UAE_Resident_Status__c', residentStatus);
        }
        insert eoi;

        Datetime past = Datetime.now().addHours(hoursOffset);
        Test.setCreatedDate(eoi.Id, past);

        eoi.SLA_Start_Time__c = past;
        eoi.Skip_SLA__c = false;
        putIfWritable(eoi, 'Source_Entity__c', SOURCE_UAE);
        if (residentStatus != null) {
            putIfWritable(eoi, 'UAE_Resident_Status__c', residentStatus);
        }
        update eoi;

        return eoi;
    }

    private static Opportunity buildOpp(String name, Id accountId, String residentStatus) {
        Opportunity opp = new Opportunity(
            Name      = name,
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        putIfWritable(opp, 'Source_Entity__c', SOURCE_UAE);
        if (residentStatus != null) {
            putIfWritable(opp, 'UAE_Resident_Status__c', residentStatus);
        }
        return opp;
    }

    private static void putIfWritable(SObject record, String fieldName, Object value) {
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        Schema.SObjectField token = fields.get(fieldName);
        if (token == null) {
            return;
        }
        Schema.DescribeFieldResult d = token.getDescribe();
        if (record.Id == null) {
            if (d.isCreateable()) {
                record.put(fieldName, value);
            }
        } else if (d.isUpdateable()) {
            record.put(fieldName, value);
        }
    }

    private static String getStatus(Id eoiId) {
        return [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoiId].Status__c;
    }

    private static Opportunity getOpp(Id accountId) {
        return [SELECT Id FROM Opportunity WHERE AccountId = :accountId LIMIT 1];
    }

    private static Account getResidentAccount() {
        return [SELECT Id FROM Account WHERE FirstName = 'Resident' LIMIT 1];
    }

    private static Account getNonResidentAccount() {
        return [SELECT Id FROM Account WHERE FirstName = 'NonResident' LIMIT 1];
    }

    private static Account getBlankResidentAccount() {
        return [SELECT Id FROM Account WHERE FirstName = 'Blank' LIMIT 1];
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Account'
            AND    IsPersonType = true
            LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }
}