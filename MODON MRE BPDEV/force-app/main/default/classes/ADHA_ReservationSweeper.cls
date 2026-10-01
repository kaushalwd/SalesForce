/**********************************************************************************************************************
* Name               : ADHA_ReservationSweeper
* Description        : Hourly sweep of the 7-day selection window; expires lapsed applicants and releases their
*                      reservations through ADHA_ReservationService.release so villas return to the map.
* Usage              : ADHA_ReservationSweeper.scheduleHourly() once per org; the only scheduled job here, and its
*                      finish() chains ADHA_ReservationPaymentBatch, ADHA_HoldSweeper and ADHA_SignedCopyBatch.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_ReservationSweeper implements Schedulable, Database.Batchable<SObject> {
    @TestVisible private static final Integer SCOPE = 50;
    @TestVisible private static final String JOB_NAME = 'ADHA Reservation Sweeper';
    /** Minute 20 keeps this clear of EOIVoidScheduler, which registers 24 hourly jobs of its own. */
    @TestVisible private static final String CRON = '0 20 * * * ?';
    @TestVisible private static final String LEGACY_JOB_PREFIX = 'ADHA Reservation Sweeper';

    /** One job, not 24: '*' in the hours field already means every hour, so a single cron
     *  expression covers the whole hourly schedule. */
    public static Id scheduleHourly() {
        unschedule();
        return System.schedule(JOB_NAME, CRON, new ADHA_ReservationSweeper());
    }

    /** Clears this job and the 24 the old loop created. Returns how many it aborted. */
    /** CronTrigger is not isolated inside a test: a test that clears by the real prefix would be
     *  reaching for the org's live jobs. Tests point this at a name nothing real uses. */
    @TestVisible private static String prefixOverride;

    public static Integer unschedule() {
        String pattern = (prefixOverride == null ? LEGACY_JOB_PREFIX : prefixOverride) + '%';
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :pattern
        ];
        Integer aborted = 0;
        for (CronTrigger job : jobs) {
            try {
                System.abortJob(job.Id);
                aborted++;
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not abort ' + job.Id + ': ' + e.getMessage());
            }
        }
        return aborted;
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new ADHA_ReservationSweeper(), SCOPE);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Unit_Lock_Key__c != null IS the definition of live - a released row has null keys. Same
        // predicate the service uses, so the job and the service cannot drift apart.
        return Database.getQueryLocator([
            SELECT Id, Current_Attempt__c, SLA_End__c, Journey_Stage__c,
                   (SELECT Id, Status__c, Unit__c, Released_On__c
                    FROM Reservations__r
                    WHERE Unit_Lock_Key__c != NULL)
            FROM ADHA_Applicant__c
            WHERE First_Verified_Login__c != NULL
              AND SLA_End__c != NULL
              AND SLA_End__c < :System.now()
              AND Journey_Stage__c NOT IN ('Completed', 'Expired')
        ]);
    }

    public void execute(Database.BatchableContext context, List<ADHA_Applicant__c> scope) {
        Integer maxAttempts = maxAttemptsSetting();
        Integer slaDays = ADHA_JourneyController.slaDays();
        List<ADHA_Applicant__c> toUpdate = new List<ADHA_Applicant__c>();
        Set<Id> expiredIds = new Set<Id>();

        // One query for the whole chunk: Submitted_On__c marks a real selection, and a dropped
        // ten-minute hold never sets it, so browsing does not count as an attempt.
        Set<Id> alreadySelected = new Set<Id>();
        for (AggregateResult row : [
            SELECT Applicant__c applicantId
            FROM ADHA_Reservation__c
            WHERE Applicant__c IN :scope AND Submitted_On__c != NULL
            GROUP BY Applicant__c
        ]) {
            alreadySelected.add((Id) row.get('applicantId'));
        }

        for (ADHA_Applicant__c applicant : scope) {
            // The QueryLocator snapshot can be stale; re-read under a lock or this releases a
            // villa the customer confirmed seconds ago.
            List<ADHA_Applicant__c> locked = [
                SELECT Id, Current_Attempt__c, SLA_Start__c, SLA_End__c, Journey_Stage__c
                FROM ADHA_Applicant__c
                WHERE Id = :applicant.Id
                LIMIT 1
                FOR UPDATE
            ];
            if (locked.isEmpty()) {
                continue;
            }
            ADHA_Applicant__c fresh = locked[0];
            if (fresh.SLA_End__c == null || fresh.SLA_End__c >= System.now()) {
                continue;
            }
            if (fresh.Journey_Stage__c == 'Completed' || fresh.Journey_Stage__c == 'Expired') {
                continue;
            }

            Boolean confirmedInTime = false;
            for (ADHA_Reservation__c stale : applicant.Reservations__r) {
                ADHA_Reservation__c live = reload(stale.Id);
                if (live == null || ADHA_ReservationService.isReleased(live)) {
                    continue;
                }
                // Completed only: a signature finishes the window. Counting Submitted too let an
                // accepted but never signed row hold a villa forever.
                if (live.Status__c == 'Completed') {
                    confirmedInTime = true;
                    continue;
                }
                // Any envelope is voided by ADHA_SignedCopyBatch, not here: voiding is a callout,
                // this loop has already written, and Apex forbids that order.
                ADHA_ReservationService.release(live, 'SLA Expiry');
            }
            if (confirmedInTime) {
                continue;
            }

            Integer attempt = fresh.Current_Attempt__c == null ? 1 : Integer.valueOf(fresh.Current_Attempt__c);
            // Since 25 Aug 2026 a second window goes only to someone who never chose; picking a
            // villa and letting it lapse unsigned used up the opportunity.
            Boolean secondWindow = attempt < maxAttempts && !alreadySelected.contains(fresh.Id);
            if (secondWindow) {
                // Written directly: isEarlierStage refuses to move a stage backwards, which would
                // leave "Unit Selected" showing through the whole second window.
                fresh.Current_Attempt__c = attempt + 1;
                fresh.SLA_Start__c = System.now();
                fresh.SLA_End__c = System.now().addDays(slaDays);
                fresh.Journey_Stage__c = 'Logged In';
            } else {
                fresh.Journey_Stage__c = 'Expired';
                expiredIds.add(fresh.Id);
            }
            toUpdate.add(fresh);
        }

        // Partial success: one bad row must not abort the chunk and have it retried against rows
        // this run has already released.
        Database.update(toUpdate, false);

        // Expiry also frees any villa still set aside for them.
        if (!expiredIds.isEmpty()) {
            List<ADHA_Unit__c> pinned = [
                SELECT Id, Plot_UID__c, Pinned_Applicant__c
                FROM ADHA_Unit__c WHERE Pinned_Applicant__c IN :expiredIds
            ];
            for (ADHA_Unit__c u : pinned) {
                ADHA_JourneyLog.queue(u.Pinned_Applicant__c, null, u.Id, 'Pin cleared',
                    'Pin on ' + u.Plot_UID__c + ' cleared: applicant expired');
                u.Pinned_Applicant__c = null;
                u.Pinned_On__c = null;
            }
            Database.update(pinned, false);
        }

        // One statement for the whole chunk's audit trail, however many villas went back.
        ADHA_JourneyLog.flush();
    }

    public void finish(Database.BatchableContext context) {
        startChain();
    }

    /** What the hourly job pulls along behind it. Recorded before it runs so a test can assert on
     *  the chain without starting four batches inside Test.stopTest. */
    @TestVisible private static List<String> chained = new List<String>();

    @TestVisible
    private static void startChain() {
        chained.add('ADHA_ReservationPaymentBatch');
        chained.add('ADHA_HoldSweeper');
        if (Test.isRunningTest()) {
            return;
        }
        // Each start is wrapped so one failure does not cost the others; the next hourly fire
        // retries anything missed.
        try {
            Database.executeBatch(new ADHA_ReservationPaymentBatch(), SCOPE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Payment batch did not start: ' + e.getMessage());
        }
        try {
            // Backstop for holds the flow stranded. It chains ADHA_SignedCopyBatch from its own
            // finish, which is what puts the DocuSign reconciliation on the hourly cadence.
            ADHA_HoldSweeper.run();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Hold sweeper did not start: ' + e.getMessage());
        }
    }

    /* ---------- helpers ---------- */

    public static ADHA_Reservation__c reload(Id reservationId) {
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Name, Applicant__c, Status__c, Unit__c, Released_On__c, Journey_Log__c,
                   Additional_Payment_Due__c, Additional_Payment_Received_On__c
            FROM ADHA_Reservation__c
            WHERE Id = :reservationId
            LIMIT 1
            FOR UPDATE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Integer maxAttemptsSetting() {
        Decimal value = ADHA_JourneyController.settings().Max_Attempts__c;
        return value == null ? 2 : Integer.valueOf(value);
    }
}