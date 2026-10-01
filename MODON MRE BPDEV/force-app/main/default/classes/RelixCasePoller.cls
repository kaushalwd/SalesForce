/**
 * RelixCasePoller - reads open Relix cases on a timer, so a lost callback loses nothing.
 *
 * Version  Author       Date         Detail
 * 1.4      MODON Dev  26 Sep 2026  Review fix (signzy-impact C-05, 07 R-u). Passed rows whose writes are due use the
 *                                    same failure gate as every other stage: after 5 failures they are retried every
 *                                    6 hours instead of never, so a write blocked by an approval lock lands once the
 *                                    lock is released (it used to need an admin to reset Consecutive_Failures__c).
 * 1.3      MODON Dev  26 Sep 2026  Review fix (L-02). execute() catches and logs (by type only) any catchable fault
 *                                    of run(), so a failed run can no longer roll back the successor schedule and end
 *                                    the chain. Uncatchable limits still roll it back: check daily that a WAITING
 *                                    CronTrigger named 'Relix Case Poller%' exists.
 * 1.2      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 C-2, C-3, R-a, R-t). Reads by stage instead
 *                                    of "every open case every run": callback-flagged rows; finished or
 *                                    detail-pending cases; passed rows whose writes are still due; buyers in
 *                                    the journey; then slow re-reads of started, stale and expired links and
 *                                    of Needs review / Superseded rows. Capacity is RELIX_POLL_MAX_READS x
 *                                    RELIX_READ_JOBS, split into one ReadJob per RELIX_POLL_MAX_READS rows.
 *                                    Rows read in the last 3 minutes wait (callback-flagged rows excepted);
 *                                    rows that failed 5 times in a row are read at most every 6 hours. The
 *                                    rows left over are logged, then the document download batch is started
 *                                    when its switches allow.
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. Review fixes: an expired link is no longer marked from
 *                                    the cached status (a buyer mid-journey lost their completed KYC);
 *                                    it is read and RelixPassRule decides. Callback-flagged rows
 *                                    are read first whatever their decision, EXPIRED included.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Self-rescheduling every RELIX_POLL_MINUTES (default
 *                                    15), following EOISitePaymentSweeper, with one guard that class
 *                                    lacks: it never schedules a successor while another poller job
 *                                    is already waiting, so a repeated start() or a refreshed sandbox
 *                                    cannot run two chains.
 *
 * WHAT ONE RUN DOES (no callouts here: the reads run in RelixKycService.ReadJob)
 *   Only SENT rows with a Relix case id. Stages, in order, until the capacity is used:
 *   1. Callback-flagged (Read_Due__c), whatever the decision, even if read a moment ago: the callback came later.
 *   2. OPEN cases Relix has finished or is checking (SUBMITTED, PREPARING_RESULT, COMPLETED,
 *      REQUIRES_ATTENTION), or whose detail reads are PENDING.
 *   3. PASSED rows whose KYC date or identity writes are still due (R-a).
 *   4. OPEN cases IN_PROGRESS that started within the last 2 hours (the buyer is in the journey).
 *   5. OPEN cases STARTED, blank or IN_PROGRESS for longer, every 6 hours, and once after the link expired
 *      (RelixPassRule marks EXPIRED only if Relix still says STARTED).
 *   6. NEEDS_REVIEW rows every 6 hours (a reviewer may decide in the Relix Console) and SUPERSEDED links still
 *      in date (the buyer may finish the old link).
 *   Every stage skips rows read in the last 3 minutes (stage 1 excepted) and rows with Consecutive_Failures__c
 *   of 5 or more unless their last read is over 6 hours old.
 *
 * WHO RUNS IT. Scheduled Apex runs as the user who scheduled it, and that user needs the
 * Relix_Cred principal (permission set Relix_Integration). Start with
 * RelixCasePoller.start() from that user; stop() aborts every waiting poller job.
 *
 * OWNERSHIP. Owner: MODON.
 */
public without sharing class RelixCasePoller implements Schedulable {

    public static final String JOB_PREFIX = 'Relix Case Poller';
    private static final List<String> LIVE_STATES = new List<String>{ 'WAITING', 'ACQUIRED', 'EXECUTING' };
    @TestVisible private static final Integer STALE_OPEN_MINUTES = 3;
    @TestVisible private static final Integer STALE_REVIEW_HOURS = 6;
    @TestVisible private static final Integer SESSION_HOURS = 2;
    @TestVisible private static final Integer FAILURE_LIMIT = 5;
    /** The most leftover rows one stage counts for the log. */
    private static final Integer LEFTOVER_SCAN = 2000;

    private static final String STATUS_STARTED = 'STARTED';
    private static final String STATUS_IN_PROGRESS = 'IN_PROGRESS';
    private static final List<String> CHECKING_STATUSES = new List<String>{
        'SUBMITTED', 'PREPARING_RESULT', 'COMPLETED', 'REQUIRES_ATTENTION'
    };
    private static final String LOG_METHOD = 'poller';

    /** Test hook: run() throws, so the chain-keeping catch in execute() can be tested. */
    @TestVisible private static Boolean simulateRunFault = false;

    // ---------------------------------------------------------------- stage filters (binds are set in Selection)
    private static final String BASE =
        'Send_State__c = :sent AND Case_Id__c != null AND Id NOT IN :taken';
    private static final String FAILURE_GATE =
        ' AND (Consecutive_Failures__c = null OR Consecutive_Failures__c < :failureLimit OR Last_Read_At__c < :slow)';
    private static final String NOT_RECENT =
        ' AND (Last_Read_At__c = null OR Last_Read_At__c < :recent)';
    private static final String STALE_STATUS =
        ' AND (Relix_Status__c = null OR Relix_Status__c = :started'
        + ' OR (Relix_Status__c = :inProgress AND (Started_At__c = null OR Started_At__c < :sessionStart)))';
    private static final String STAGE_CALLBACK = BASE + FAILURE_GATE + ' AND Read_Due__c = true';
    private static final String STAGE_CHECKING = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c = :open AND (Relix_Status__c IN :checking OR Details_State__c = :detailsPending)';
    private static final String STAGE_WRITES = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c = :passed AND Role__c != :company';
    private static final String STAGE_IN_SESSION = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c = :open AND Relix_Status__c = :inProgress AND Started_At__c >= :sessionStart';
    private static final String STAGE_SLOW = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c = :open' + STALE_STATUS + ' AND (Last_Read_At__c = null OR Last_Read_At__c < :slow)';
    private static final String STAGE_EXPIRED = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c = :open' + STALE_STATUS + ' AND Link_Expires_At__c < :now';
    private static final String STAGE_REVIEW = BASE + FAILURE_GATE + NOT_RECENT
        + ' AND Decision__c IN :reviewDecisions AND (Last_Read_At__c = null OR Last_Read_At__c < :slow)'
        + ' AND (Decision__c = :needsReview OR Link_Expires_At__c = null OR Link_Expires_At__c > :now)';
    private static final String ORDER_OLDEST_READ = ' ORDER BY Read_Due__c DESC, Last_Read_At__c ASC NULLS FIRST, Id ASC';
    private static final String ORDER_NEWEST_EXPIRY = ' ORDER BY Link_Expires_At__c DESC, Id ASC';

    /** Schedules the chain unless one is already waiting. Returns the job id, or null when not needed. */
    public static Id start() {
        if (isScheduled(null)) { return null; }
        return scheduleNext(RelixConfig.pollMinutes());
    }

    public static void stop() {
        for (CronTrigger ct : waiting(null)) { System.abortJob(ct.Id); }
    }

    public static Boolean isScheduled(Id except) { return !waiting(except).isEmpty(); }

    private static List<CronTrigger> waiting(Id except) {
        String pattern = JOB_PREFIX + '%';
        return [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :pattern AND State IN :LIVE_STATES AND Id != :except
            WITH SYSTEM_MODE
        ];
    }

    private static Id scheduleNext(Integer minutes) {
        Datetime next = System.now().addMinutes(minutes);
        return System.schedule(JOB_PREFIX + ' ' + next.getTime(),
            next.format('ss mm HH dd MM ? yyyy'), new RelixCasePoller());
    }

    /**
     * Schedules the successor first, then runs one pass. A catchable fault of the pass is logged (type only) and
     * swallowed, because an exception leaving execute() would roll back the successor and end the chain.
     * @param sc the schedulable context
     */
    public void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
            Id self = sc == null ? null : sc.getTriggerId();
            if (!isScheduled(self)) { scheduleNext(RelixConfig.pollMinutes()); }
            if (self != null) { System.abortJob(self); }
        }
        try {
            run();
        } catch (Exception e) {
            RelixLogger.failure(LOG_METHOD, 'Poller run failed: ' + e.getTypeName(), null);
        }
    }

    /** One pass. Public so an admin can run it by hand: RelixCasePoller.run(); */
    public static void run() {
        if (simulateRunFault) {
            throw new PollerException('Simulated poller fault');
        }
        if (!RelixConfig.isEnabled()) {
            return;
        }
        Integer perJob = RelixConfig.pollMaxReads();
        Selection s = new Selection(perJob * RelixConfig.readJobsPerRun());
        s.take(STAGE_CALLBACK, false);
        s.take(STAGE_CHECKING, false);
        s.take(writesStage(), false);
        s.take(STAGE_IN_SESSION, false);
        s.take(STAGE_SLOW, false);
        s.take(STAGE_EXPIRED, true);
        s.take(STAGE_REVIEW, false);
        enqueueReads(s.ids, perJob);
        if (!s.leftover.isEmpty()) {
            RelixLogger.failure(LOG_METHOD, s.leftover.size() + (s.leftoverCapped ? '+' : '')
                + ' due case row(s) left for the next run; this run took ' + s.ids.size() + ' (capacity ' + s.capacity + ').', null);
        }
        RelixDocumentBatch.startIfNeeded();
    }

    /** Thrown only by the test hook simulateRunFault. */
    @TestVisible
    private class PollerException extends Exception {}

    /** R-a: passed rows whose KYC date or identity writes are still due; null when both switches are off. */
    private static String writesStage() {
        List<String> due = new List<String>();
        if (RelixConfig.writesKycDate()) {
            due.add('Kyc_Date_Written__c = null');
        }
        if (RelixConfig.writesIdentity()) {
            due.add('Fields_Written_At__c = null');
        }
        return due.isEmpty() ? null : STAGE_WRITES + ' AND (' + String.join(due, ' OR ') + ')';
    }

    /** One ReadJob per pollMaxReads() rows; the capacity already keeps it within readJobsPerRun() jobs. */
    @SuppressWarnings('PMD.OperationWithLimitsInLoop')
    private static void enqueueReads(List<Id> ids, Integer perJob) {
        for (Integer i = 0; i < ids.size(); i += perJob) {
            List<Id> chunk = new List<Id>();
            for (Integer j = i; j < Math.min(i + perJob, ids.size()); j++) {
                chunk.add(ids[j]);
            }
            System.enqueueJob(new RelixKycService.ReadJob(chunk));
        }
    }

    /**
     * The rows one run reads, in stage order, and the due rows left for the next run. without sharing, like the
     * poller itself: the case rows are Private and the poller must see every one whoever created it.
     */
    private without sharing class Selection {
        final Integer capacity;
        final List<Id> ids = new List<Id>();
        final Set<Id> taken = new Set<Id>();
        final Set<Id> leftover = new Set<Id>();
        Boolean leftoverCapped = false;
        final Map<String, Object> binds;

        Selection(Integer capacity) {
            this.capacity = capacity;
            Datetime now = System.now();
            binds = new Map<String, Object>{
                'sent' => RelixKycService.SEND_SENT,
                'taken' => taken,
                'failureLimit' => FAILURE_LIMIT,
                'slow' => now.addHours(-STALE_REVIEW_HOURS),
                'recent' => now.addMinutes(-STALE_OPEN_MINUTES),
                'sessionStart' => now.addHours(-SESSION_HOURS),
                'now' => now,
                'open' => RelixPassRule.OPEN,
                'passed' => RelixPassRule.PASSED,
                'needsReview' => RelixPassRule.NEEDS_REVIEW,
                'reviewDecisions' => new List<String>{ RelixPassRule.NEEDS_REVIEW, RelixKycService.SUPERSEDED },
                'company' => RelixKycService.ROLE_COMPANY,
                'checking' => CHECKING_STATUSES,
                'detailsPending' => RelixResultService.STATE_PENDING,
                'started' => STATUS_STARTED,
                'inProgress' => STATUS_IN_PROGRESS
            };
        }

        Integer room() {
            return capacity - ids.size();
        }

        /** Takes the stage's rows while there is room; once full, notes the stage's due rows as left over. */
        void take(String filter, Boolean expiredSinceRead) {
            if (filter == null) {
                return;
            }
            if (room() > 0) {
                for (Relix_KYC_Case__c r : query(filter, expiredSinceRead, room())) {
                    ids.add(r.Id);
                    taken.add(r.Id);
                }
            }
            if (room() <= 0) {
                List<Relix_KYC_Case__c> rest = query(filter, expiredSinceRead, LEFTOVER_SCAN);
                leftoverCapped = leftoverCapped || rest.size() >= LEFTOVER_SCAN;
                for (Relix_KYC_Case__c r : rest) {
                    leftover.add(r.Id);
                }
            }
        }

        /** The stage's rows, at most max; an expired-link stage keeps only links that expired after their last read. */
        List<Relix_KYC_Case__c> query(String filter, Boolean expiredSinceRead, Integer max) {
            binds.put('rowLimit', expiredSinceRead ? LEFTOVER_SCAN : max);
            String soql = 'SELECT Id, Last_Read_At__c, Link_Expires_At__c FROM Relix_KYC_Case__c WHERE ' + filter
                + (expiredSinceRead ? ORDER_NEWEST_EXPIRY : ORDER_OLDEST_READ) + ' LIMIT :rowLimit';
            // Constant filters and binds only; system mode, because the poller must see every Private row.
            List<Relix_KYC_Case__c> rows = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
            if (!expiredSinceRead) {
                return rows;
            }
            List<Relix_KYC_Case__c> out = new List<Relix_KYC_Case__c>();
            for (Relix_KYC_Case__c r : rows) {
                if (out.size() < max && (r.Last_Read_At__c == null || r.Last_Read_At__c < r.Link_Expires_At__c)) {
                    out.add(r);
                }
            }
            return out;
        }
    }
}