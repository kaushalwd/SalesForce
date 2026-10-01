/**
 * @description Test class for AccountMergeQueueable.
 *
 * Coverage targets:
 *   execute            — empty victims (early return), happy path, error path
 *   reparentStandardObjects — Opportunity, Case, Task, Event reparented
 *   reparentSpecialObjects  — SalesOrder__c reparented, Contact reparented
 *   reparentCustomObjects   — dynamic CMT-driven reparenting (no crash when CMT empty)
 *   handleError             — writes Merge_Status__c = Error + Merge_Error__c to master
 *
 * Error path: we delete the victim account after flagging it, so the
 * victim update inside execute() throws a DmlException. execute() catches it,
 * calls handleError(), then re-throws. We wrap Test.stopTest() in try/catch
 * so the test does not fail on the re-thrown exception.
 */
@IsTest
private class AccountMergeQueueableTest {

    // ─────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────

    private static Id orgRtId {
        get {
            if (orgRtId == null) {
                List<RecordType> rts = [
                    SELECT Id FROM RecordType
                    WHERE  SObjectType = 'Account'
                    AND    IsPersonType = false AND IsActive = true LIMIT 1
                ];
                orgRtId = rts.isEmpty() ? null : rts[0].Id;
            }
            return orgRtId;
        }
        set;
    }

    private static Account makeOrg(String name) {
        Account a = new Account(Name = name);
        if (orgRtId != null) a.RecordTypeId = orgRtId;
        return a;
    }

    // ─────────────────────────────────────────────────────────────────────
    // 1. Empty victims — execute() returns immediately, no DML
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testEmptyVictims_noOp() {
        Account master = makeOrg('Empty Master');
        insert master;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>()));
        Test.stopTest();

        Account after = [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id];
        Assert.isNull(after.Merge_Status__c, 'Status must remain null when no victims');
    }

    @IsTest
    static void testNullVictims_noOp() {
        Account master = makeOrg('Null Victim Master');
        insert master;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, null));
        Test.stopTest();

        Account after = [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id];
        Assert.isNull(after.Merge_Status__c, 'Status must remain null when victims is null');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2. Happy path — standard objects reparented, master + victim marked Merged
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHappyPath_masterAndVictimMarkedMerged() {
        Account master = makeOrg('Happy Master');
        Account victim = makeOrg('Happy Victim');
        insert new List<Account>{ master, victim };

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Account masterAfter = [
            SELECT Merge_Status__c, Merge_Error__c FROM Account WHERE Id = :master.Id
        ];
        Account victimAfter = [
            SELECT Merge_Status__c, Is_Merged__c, Eligible_For_Merge__c, Master_Account__c
            FROM Account WHERE Id = :victim.Id
        ];

        Assert.areEqual('Merged', masterAfter.Merge_Status__c, 'Master must be Merged');
        Assert.isNull(masterAfter.Merge_Error__c,              'Master error must be null');
        Assert.areEqual('Merged', victimAfter.Merge_Status__c, 'Victim must be Merged');
        Assert.isTrue(victimAfter.Is_Merged__c,                'Victim Is_Merged__c must be true');
        Assert.isFalse(victimAfter.Eligible_For_Merge__c,      'Victim eligible flag must be false');
        Assert.areEqual(master.Id, victimAfter.Master_Account__c, 'Victim master link preserved');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 3. Standard objects — Opportunity reparented
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testReparent_opportunity() {
        Account master = makeOrg('Opp Master');
        Account victim = makeOrg('Opp Victim');
        insert new List<Account>{ master, victim };

        Opportunity opp = new Opportunity(
            Name      = 'Reparent Opp',
            AccountId = victim.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Assert.areEqual(master.Id,
            [SELECT AccountId FROM Opportunity WHERE Id = :opp.Id].AccountId,
            'Opportunity must be reparented to master');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 4. Standard objects — Case reparented
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testReparent_case() {
        Account master = makeOrg('Case Master');
        Account victim = makeOrg('Case Victim');
        insert new List<Account>{ master, victim };

        Case c = new Case(AccountId = victim.Id, Description = 'Test Case');
        insert c;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Assert.areEqual(master.Id,
            [SELECT AccountId FROM Case WHERE Id = :c.Id].AccountId,
            'Case must be reparented to master');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 5. Special objects — SalesOrder__c reparented
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testReparent_salesOrder() {
        Account master = makeOrg('SO Master');
        Account victim = makeOrg('SO Victim');
        insert new List<Account>{ master, victim };

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = victim.Id);
        insert so;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Assert.areEqual(master.Id,
            [SELECT CustomerAccount__c FROM SalesOrder__c WHERE Id = :so.Id].CustomerAccount__c,
            'SalesOrder must be reparented to master');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 6. Special objects — Contact reparented via AccountId
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testReparent_contact() {
        Account master = makeOrg('Contact Master');
        Account victim = makeOrg('Contact Victim');
        insert new List<Account>{ master, victim };

        Contact con = new Contact(LastName = 'ReparentMe', AccountId = victim.Id);
        insert con;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Assert.areEqual(master.Id,
            [SELECT AccountId FROM Contact WHERE Id = :con.Id].AccountId,
            'Contact AccountId must be reparented to master');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 7. Multiple victims — all marked Merged
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testMultipleVictims_allMerged() {
        Account master  = makeOrg('Multi Master');
        Account victim1 = makeOrg('Multi Victim 1');
        Account victim2 = makeOrg('Multi Victim 2');
        insert new List<Account>{ master, victim1, victim2 };

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(
            master.Id, new List<Id>{ victim1.Id, victim2.Id }
        ));
        Test.stopTest();

        for (Account v : [
            SELECT Merge_Status__c, Is_Merged__c
            FROM Account WHERE Id IN (:victim1.Id, :victim2.Id)
        ]) {
            Assert.areEqual('Merged', v.Merge_Status__c,
                'All victims must be Merged');
            Assert.isTrue(v.Is_Merged__c,
                'All victims must have Is_Merged__c = true');
        }

        Assert.areEqual('Merged',
            [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id].Merge_Status__c,
            'Master must be Merged');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 8. Error path — victim deleted before job runs → DML error →
    //    handleError() writes Error status, execute() re-throws.
    //    We wrap Test.stopTest() in try/catch to absorb the re-throw.
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testErrorHandling_writesErrorToMaster() {
        Account master = makeOrg('Error Master');
        Account victim = makeOrg('Error Victim');
        insert new List<Account>{ master, victim };

        // Capture victim Id before deleting it
        Id victimId = victim.Id;
        delete victim; // deleting causes the victim update inside execute() to fail

        Boolean threw = false;
        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victimId }));
        try {
            Test.stopTest(); // runs job synchronously; re-throw from execute() surfaces here
        } catch (Exception e) {
            threw = true; // expected — execute() re-throws after handleError()
        }
       // Test.stopTest();

        Account masterAfter = [
            SELECT Merge_Status__c, Merge_Error__c FROM Account WHERE Id = :master.Id
        ];

        // handleError() should have written Error status before the re-throw
        Assert.areEqual('Error', masterAfter.Merge_Status__c,
            'Merge_Status__c must be Error after job failure');
        Assert.isNotNull(masterAfter.Merge_Error__c,
            'Merge_Error__c must be populated with exception details');
        Assert.isTrue(masterAfter.Merge_Error__c.length() > 0,
            'Error detail must not be empty');
    }

    // ─────────────────────────────────────────────────────────────────────
    // 9. CMT-driven reparenting — no crash when CMT has no records
    //    (reparentCustomObjects loops over Merge_Config__mdt.getAll())
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testReparentCustomObjects_noCmtRecords_noError() {
        // Even if no Merge_Config__mdt records exist in the test org,
        // the method should complete without throwing
        Account master = makeOrg('CMT Master');
        Account victim = makeOrg('CMT Victim');
        insert new List<Account>{ master, victim };

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        // If we reach here without exception, CMT dynamic loop handled gracefully
        Assert.areEqual('Merged',
            [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id].Merge_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────────
    // 10. Opportunity + Case + SalesOrder in a single merge
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testFullMerge_multipleObjectTypes() {
        Account master = makeOrg('Full Master');
        Account victim = makeOrg('Full Victim');
        insert new List<Account>{ master, victim };

        Opportunity opp = new Opportunity(
            Name = 'Full Opp', AccountId = victim.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        Case c = new Case(AccountId = victim.Id, Description = 'Full Case');
        insert new List<SObject>{ opp, c };

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = victim.Id);
        insert so;

        Test.startTest();
        System.enqueueJob(new AccountMergeQueueable(master.Id, new List<Id>{ victim.Id }));
        Test.stopTest();

        Assert.areEqual(master.Id,
            [SELECT AccountId FROM Opportunity WHERE Id = :opp.Id].AccountId,
            'Opportunity reparented');
        Assert.areEqual(master.Id,
            [SELECT AccountId FROM Case WHERE Id = :c.Id].AccountId,
            'Case reparented');
        Assert.areEqual(master.Id,
            [SELECT CustomerAccount__c FROM SalesOrder__c WHERE Id = :so.Id].CustomerAccount__c,
            'SalesOrder reparented');
        Assert.areEqual('Merged',
            [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id].Merge_Status__c);
    }
}