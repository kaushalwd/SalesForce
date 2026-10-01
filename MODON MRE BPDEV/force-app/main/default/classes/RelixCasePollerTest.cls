/**
 * RelixCasePollerTest - what one poller run selects, and the single-chain guard (SCW-181).
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  26 Sep 2026  Review fixes: a failed run is logged and does not escape execute() (L-02); a
 *                                    1,000-row peak across the stages fills exactly RELIX_READ_JOBS jobs of
 *                                    RELIX_POLL_MAX_READS rows and logs the rest (C-09); the poller run as a standard
 *                                    user holding Relix_Integration (C-09).
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 C-2, C-3, R-a, R-s). The request count of the
 *                                    first test counts case reads only. New: stage priority, chunking into several
 *                                    ReadJobs with the leftover logged, passed rows with writes due, the failure
 *                                    slow-down, the session and expired-link stages, detail-pending rows.
 */
@IsTest
private class RelixCasePollerTest {

    private static final String EXPAT = 'INDIVIDUAL_EXPAT';

    @IsTest
    static void runReadsWhatIsDueAndLetsAFreshAnswerExpireALink() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c expired = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        expired.Link_Expires_At__c = System.now().addHours(-1);
        Relix_KYC_Case__c due = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        Relix_KYC_Case__c fresh = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        fresh.Last_Read_At__c = System.now().addMinutes(-1);
        Relix_KYC_Case__c review = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        review.Decision__c = RelixPassRule.NEEDS_REVIEW;
        review.Relix_Status__c = 'COMPLETED';
        review.Last_Read_At__c = System.now().addDays(-1);
        Relix_KYC_Case__c reviewRecent = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        reviewRecent.Decision__c = RelixPassRule.NEEDS_REVIEW;
        reviewRecent.Relix_Status__c = 'COMPLETED';
        reviewRecent.Last_Read_At__c = System.now().addHours(-1);
        Relix_KYC_Case__c reviewFlagged = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        reviewFlagged.Decision__c = RelixPassRule.NEEDS_REVIEW;
        reviewFlagged.Relix_Status__c = 'REQUIRES_ATTENTION';
        reviewFlagged.Last_Read_At__c = System.now().addMinutes(-2);
        reviewFlagged.Read_Due__c = true;
        Relix_KYC_Case__c notSent = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        notSent.Send_State__c = RelixKycService.SEND_UNCERTAIN;
        notSent.Case_Id__c = null;
        insert new List<Relix_KYC_Case__c>{ expired, due, fresh, review, reviewRecent, reviewFlagged, notSent };

        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(expired.Case_Id__c, RelixTestData.response(200, RelixTestData.caseStartedExpired()))
            .route(reviewFlagged.Case_Id__c, RelixTestData.response(200, RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T12:00:00.000Z')))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('IN_PROGRESS')));
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixCasePoller.run();
        Test.stopTest();

        Map<Id, Relix_KYC_Case__c> after = new Map<Id, Relix_KYC_Case__c>([
            SELECT Id, Decision__c, Relix_Status__c, Read_Attempts__c, Read_Due__c FROM Relix_KYC_Case__c
        ]);
        System.assertEquals(RelixPassRule.EXPIRED, after.get(expired.Id).Decision__c, 'Relix still says STARTED past expiry');
        System.assertEquals(1, after.get(expired.Id).Read_Attempts__c.intValue(), 'an expired link is read once, never decided from the cache');
        System.assertEquals(1, after.get(due.Id).Read_Attempts__c.intValue());
        System.assertEquals('IN_PROGRESS', after.get(due.Id).Relix_Status__c);
        System.assertEquals(null, after.get(fresh.Id).Read_Attempts__c, 'read a minute ago: not again yet');
        System.assertEquals(1, after.get(review.Id).Read_Attempts__c.intValue(), 'needs review rows are re-read slowly');
        System.assertEquals(null, after.get(reviewRecent.Id).Read_Attempts__c);
        System.assertEquals(1, after.get(reviewFlagged.Id).Read_Attempts__c.intValue(), 'a callback-flagged review row is read at once');
        System.assertEquals(RelixPassRule.PASSED, after.get(reviewFlagged.Id).Decision__c, 'the reviewer cleared it in the Relix Console');
        System.assertEquals(false, after.get(reviewFlagged.Id).Read_Due__c);
        System.assertEquals(null, after.get(notSent.Id).Read_Attempts__c);
        // R-s (1.1): count the case reads only; the passed row also reads its details.
        System.assertEquals(4, RelixMocks.caseReads(m));
    }

    @IsTest
    static void aLinkThatExpiredWhileTheBuyerWasInsideIsNotLost() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Link_Expires_At__c = System.now().addMinutes(-5);   // cached STARTED, link just expired
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock()
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('IN_PROGRESS'))));
        RelixCasePoller.run();
        Test.stopTest();
        Relix_KYC_Case__c after = RelixKycService.loadRow(r.Id);
        System.assertEquals(RelixPassRule.OPEN, after.Decision__c, 'the buyer is mid-journey: not expired');
        System.assertEquals('IN_PROGRESS', after.Relix_Status__c);
    }

    @IsTest
    static void runDoesNothingWhileSwitchedOff() {
        RelixConfig.activeOverride.put('RELIX_KYC', false);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c expired = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        expired.Link_Expires_At__c = System.now().addHours(-1);
        insert expired;
        Test.startTest();
        RelixCasePoller.run();
        Test.stopTest();
        System.assertEquals(RelixPassRule.OPEN, [SELECT Decision__c FROM Relix_KYC_Case__c WHERE Id = :expired.Id].Decision__c);
    }

    @IsTest
    static void startSchedulesOneChainAndNeverASecond() {
        // Independent of the org: if a real poller chain is already waiting, start() must refuse and the
        // test must not abort it. Otherwise it schedules one job and clears only that one.
        Boolean already = RelixCasePoller.isScheduled(null);
        Test.startTest();
        Id first = RelixCasePoller.start();
        if (already) {
            System.assertEquals(null, first, 'a chain exists: no second chain');
        } else {
            System.assertNotEquals(null, first);
            System.assertEquals(null, RelixCasePoller.start(), 'a second start does not add a chain');
            System.assert(RelixCasePoller.isScheduled(null));
            RelixCasePoller.stop();
            System.assert(!RelixCasePoller.isScheduled(null));
        }
        Test.stopTest();
    }

    @IsTest
    static void executeRunsTheSweepInTests() {
        RelixTestData.enable();
        Test.startTest();
        new RelixCasePoller().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);
    }

    // ================================================================ 1.1: stages, capacity, writes due (C-2, C-3, R-a)

    private static Relix_KYC_Case__c openRow(Id accountId, String status, Datetime lastRead) {
        Relix_KYC_Case__c r = RelixTestData.sentRow(accountId, null, 'Person', EXPAT);
        r.Relix_Status__c = status;
        r.Last_Read_At__c = lastRead;
        return r;
    }

    private static Map<Id, Relix_KYC_Case__c> reread() {
        return new Map<Id, Relix_KYC_Case__c>([
            SELECT Id, Read_Attempts__c, Kyc_Date_Written__c, Decision__c FROM Relix_KYC_Case__c WITH SYSTEM_MODE
        ]);
    }

    private static Integer attempts(Map<Id, Relix_KYC_Case__c> rows, Relix_KYC_Case__c r) {
        Decimal n = rows.get(r.Id).Read_Attempts__c;
        return n == null ? 0 : n.intValue();
    }

    private static RelixTestData.Mock inProgressMock() {
        return new RelixTestData.Mock()
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('IN_PROGRESS')));
    }

    @IsTest
    static void stagesAreReadInOrderInSeveralJobsAndTheRestIsLogged() {
        RelixTestData.enable();
        RelixConfig.valueOverride.put('RELIX_POLL_MAX_READS', '1');
        RelixConfig.valueOverride.put('RELIX_READ_JOBS', '2');
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Datetime now = System.now();
        Relix_KYC_Case__c slow = openRow(a.Id, 'STARTED', null);
        Relix_KYC_Case__c checking = openRow(a.Id, 'SUBMITTED', now.addMinutes(-10));
        Relix_KYC_Case__c callback = openRow(a.Id, 'IN_PROGRESS', now.addMinutes(-1));
        callback.Read_Due__c = true;
        insert new List<Relix_KYC_Case__c>{ slow, checking, callback };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, inProgressMock());
        RelixCasePoller.run();
        Assert.areEqual(2, Limits.getQueueableJobs(), 'capacity 1 x 2: two ReadJobs of one row each');
        Test.stopTest();

        Map<Id, Relix_KYC_Case__c> after = reread();
        Assert.areEqual(1, attempts(after, callback), 'stage 1: callback-flagged, even though read a minute ago');
        Assert.areEqual(1, attempts(after, checking), 'stage 2: a case Relix is checking');
        Assert.areEqual(0, attempts(after, slow), 'the never-read STARTED row waits for the next run');
        List<Logger__c> leftover = [
            SELECT Message__c FROM Logger__c WHERE MethodName__c = 'poller' WITH SYSTEM_MODE
        ];
        Assert.areEqual(1, leftover.size(), 'the capacity shortfall is logged');
        Assert.isTrue(leftover[0].Message__c.startsWith('1 due case row(s) left'), leftover[0].Message__c);
    }

    @IsTest
    static void passedRowsWithWritesDueAreReadAndWritten() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Datetime tenMinutesAgo = System.now().addMinutes(-10);
        Relix_KYC_Case__c writeDue = openRow(a.Id, 'COMPLETED', tenMinutesAgo);
        writeDue.Decision__c = RelixPassRule.PASSED;
        Relix_KYC_Case__c resting = openRow(a.Id, 'COMPLETED', System.now().addHours(-1));
        resting.Decision__c = RelixPassRule.PASSED;
        resting.Consecutive_Failures__c = 5;
        Relix_KYC_Case__c rested = openRow(a.Id, 'COMPLETED', System.now().addHours(-7));
        rested.Decision__c = RelixPassRule.PASSED;
        rested.Consecutive_Failures__c = 5;
        Relix_KYC_Case__c written = openRow(a.Id, 'COMPLETED', tenMinutesAgo);
        written.Decision__c = RelixPassRule.PASSED;
        written.Kyc_Date_Written__c = Date.newInstance(2026, 9, 25);
        Relix_KYC_Case__c company = RelixTestData.sentRow(a.Id, null, 'Company', 'CORPORATE_ENTITY');
        company.Decision__c = RelixPassRule.PASSED;
        company.Last_Read_At__c = tenMinutesAgo;
        insert new List<Relix_KYC_Case__c>{ writeDue, resting, rested, written, company };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock().route('/cases/',
            RelixTestData.response(200, RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z'))));
        RelixCasePoller.run();
        Test.stopTest();

        Map<Id, Relix_KYC_Case__c> after = reread();
        Assert.areEqual(1, attempts(after, writeDue), 'a pass whose KYC date is due is read (R-a)');
        Assert.areEqual(Date.newInstance(2026, 9, 25), after.get(writeDue.Id).Kyc_Date_Written__c, 'and its date is written');
        Assert.areEqual(Date.newInstance(2026, 9, 25),
            [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :a.Id WITH SYSTEM_MODE].KYC_Completed_Date__c, 'on the Account');
        Assert.areEqual(0, attempts(after, resting), 'five failed writes rest for six hours');
        Assert.areEqual(1, attempts(after, rested), 'then the write is retried (R-u: an approval lock may have been released)');
        Assert.areEqual(Date.newInstance(2026, 9, 25), after.get(rested.Id).Kyc_Date_Written__c, 'and lands');
        Assert.areEqual(0, attempts(after, written), 'nothing left to write: not read');
        Assert.areEqual(0, attempts(after, company), 'a company row never writes, so it is never picked for writes');
    }

    @IsTest
    static void passedRowsAreNotPickedWhileTheWritesAreOff() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c passed = openRow(a.Id, 'COMPLETED', System.now().addMinutes(-10));
        passed.Decision__c = RelixPassRule.PASSED;
        insert passed;
        RelixTestData.Mock m = inProgressMock();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixCasePoller.run();
        Test.stopTest();

        Assert.areEqual(0, m.requests.size(), 'with both write switches off a pass is not read again');
    }

    @IsTest
    static void aPassWithIdentityWritesDueIsReadWhileThatSwitchIsOn() {
        RelixTestData.enable();
        RelixTestData.writeIdentity(true);
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c passed = openRow(a.Id, 'COMPLETED', System.now().addMinutes(-10));
        passed.Decision__c = RelixPassRule.PASSED;
        passed.Kyc_Date_Written__c = Date.newInstance(2026, 9, 25);
        insert passed;
        RelixTestData.Mock m = inProgressMock();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixCasePoller.run();
        Test.stopTest();

        Assert.areEqual(1, RelixMocks.caseReads(m), 'identity fields still due: the pass is read again (R-a)');
        Assert.areEqual(RelixPassRule.PASSED, reread().get(passed.Id).Decision__c, 'and stays PASSED');
    }

    @IsTest
    static void rowsThatKeepFailingAreReadEverySixHours() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Datetime now = System.now();
        Relix_KYC_Case__c resting = openRow(a.Id, 'SUBMITTED', now.addHours(-1));
        resting.Consecutive_Failures__c = 5;
        Relix_KYC_Case__c rested = openRow(a.Id, 'SUBMITTED', now.addHours(-7));
        rested.Consecutive_Failures__c = 5;
        Relix_KYC_Case__c fourFailures = openRow(a.Id, 'SUBMITTED', now.addMinutes(-10));
        fourFailures.Consecutive_Failures__c = 4;
        insert new List<Relix_KYC_Case__c>{ resting, rested, fourFailures };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, inProgressMock());
        RelixCasePoller.run();
        Test.stopTest();

        Map<Id, Relix_KYC_Case__c> after = reread();
        Assert.areEqual(0, attempts(after, resting), 'five failures and read an hour ago: it rests');
        Assert.areEqual(1, attempts(after, rested), 'five failures but last read over six hours ago: read');
        Assert.areEqual(1, attempts(after, fourFailures), 'under five failures: read as usual');
    }

    @IsTest
    static void aFailedRunIsLoggedAndDoesNotEscapeExecute() {
        RelixTestData.enable();
        RelixCasePoller.simulateRunFault = true;

        Test.startTest();
        new RelixCasePoller().execute(null);
        Test.stopTest();

        List<Logger__c> logged = [
            SELECT Message__c FROM Logger__c WHERE MethodName__c = 'poller' WITH SYSTEM_MODE
        ];
        Assert.areEqual(1, logged.size(), 'the failed run is logged once');
        Assert.isTrue(logged[0].Message__c.contains('Poller run failed'), logged[0].Message__c);
        Assert.isTrue(logged[0].Message__c.contains('PollerException'), 'by exception type: ' + logged[0].Message__c);
    }

    @IsTest
    static void aThousandDueRowsFillTheReadJobsAndTheRestIsLogged() {
        RelixTestData.enable();
        // Small jobs keep the test fast; the 40-row read job itself is proven in RelixKycServiceTest.
        RelixConfig.valueOverride.put('RELIX_POLL_MAX_READS', '10');
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Datetime now = System.now();
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 0; i < 1000; i++) {
            Integer stage = Math.mod(i, 3);
            Relix_KYC_Case__c r = openRow(a.Id, stage == 0 ? 'SUBMITTED' : (stage == 1 ? 'IN_PROGRESS' : 'STARTED'),
                stage == 2 ? null : now.addMinutes(-10));
            r.Started_At__c = now.addMinutes(-30);
            rows.add(r);
        }
        Database.insert(rows, AccessLevel.SYSTEM_MODE);
        Integer perJob = RelixConfig.pollMaxReads();
        Integer jobs = RelixConfig.readJobsPerRun();
        Integer queued;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, inProgressMock());
        RelixCasePoller.run();
        queued = Limits.getQueueableJobs();
        Test.stopTest();

        Assert.areEqual(jobs, queued, 'one ReadJob per RELIX_POLL_MAX_READS rows, RELIX_READ_JOBS of them');
        Integer read = [SELECT COUNT() FROM Relix_KYC_Case__c WHERE Read_Attempts__c = 1 WITH SYSTEM_MODE];
        Assert.areEqual(perJob * jobs, read, 'the capacity is used in full, each job reading its own rows');
        Assert.areEqual(perJob * jobs, [
            SELECT COUNT() FROM Relix_KYC_Case__c WHERE Read_Attempts__c = 1 AND Relix_Status__c = 'IN_PROGRESS' WITH SYSTEM_MODE
        ], 'every row read was saved');
        List<Logger__c> leftover = [SELECT Message__c FROM Logger__c WHERE MethodName__c = 'poller' WITH SYSTEM_MODE];
        Assert.areEqual(1, leftover.size(), 'the rows left over are logged once');
        Assert.isTrue(leftover[0].Message__c.startsWith(String.valueOf(1000 - perJob * jobs) + ' due case row(s) left'),
            leftover[0].Message__c);
    }

    @IsTest
    static void thePollerRunsForAStandardUserHoldingTheIntegrationSet() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c due = openRow(a.Id, 'SUBMITTED', System.now().addMinutes(-10));
        insert due;
        User integrationUser = RelixTestData.integrationUser();
        RelixTestData.Mock m = inProgressMock();

        System.runAs(integrationUser) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, m);
            RelixCasePoller.run();
            Test.stopTest();
        }

        Map<Id, Relix_KYC_Case__c> after = reread();
        Assert.areEqual(1, attempts(after, due), 'the integration user\'s poller reads a Private row it does not own');
        Assert.areEqual(1, RelixMocks.caseReads(m), 'one case read');
    }

    @IsTest
    static void sessionStaleAndExpiredStagesPickTheRightRows() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Datetime now = System.now();
        Relix_KYC_Case__c inSession = openRow(a.Id, 'IN_PROGRESS', now.addMinutes(-10));
        inSession.Started_At__c = now.addHours(-1);
        Relix_KYC_Case__c staleRecent = openRow(a.Id, 'IN_PROGRESS', now.addHours(-1));
        staleRecent.Started_At__c = now.addHours(-5);
        Relix_KYC_Case__c staleOld = openRow(a.Id, 'IN_PROGRESS', now.addHours(-7));
        staleOld.Started_At__c = now.addHours(-9);
        Relix_KYC_Case__c expiredSinceRead = openRow(a.Id, 'STARTED', now.addHours(-1));
        expiredSinceRead.Link_Expires_At__c = now.addMinutes(-30);
        Relix_KYC_Case__c readAfterExpiry = openRow(a.Id, 'IN_PROGRESS', now.addHours(-1));
        readAfterExpiry.Started_At__c = now.addHours(-5);
        readAfterExpiry.Link_Expires_At__c = now.addHours(-2);
        Relix_KYC_Case__c detailsPending = openRow(a.Id, 'IN_PROGRESS', now.addMinutes(-10));
        detailsPending.Started_At__c = now.addHours(-5);
        detailsPending.Details_State__c = 'PENDING';
        insert new List<Relix_KYC_Case__c>{ inSession, staleRecent, staleOld, expiredSinceRead, readAfterExpiry, detailsPending };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, inProgressMock());
        RelixCasePoller.run();
        Test.stopTest();

        Map<Id, Relix_KYC_Case__c> after = reread();
        Assert.areEqual(1, attempts(after, inSession), 'a buyer in the journey is read every run');
        Assert.areEqual(0, attempts(after, staleRecent), 'a stale journey read an hour ago waits');
        Assert.areEqual(1, attempts(after, staleOld), 'a stale journey is read every six hours');
        Assert.areEqual(1, attempts(after, expiredSinceRead), 'a link that expired after its last read is read once');
        Assert.areEqual(0, attempts(after, readAfterExpiry), 'a link already read after its expiry waits');
        Assert.areEqual(1, attempts(after, detailsPending), 'detail reads PENDING are read first');
    }
}