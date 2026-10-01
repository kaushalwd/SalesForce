/**********************************************************************************************************************
* Name               : ADHA_HoldSweeper
* Description        : Returns villas whose 10-minute soft hold lapsed unsigned. Not scheduled: it runs hourly on
*                      ADHA_ReservationSweeper's chain, a backstop behind the release flow and hold()'s inline release.
* Usage              : Chained from ADHA_ReservationSweeper.finish(). ADHA_HoldSweeper.run() to force a pass.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     17 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_HoldSweeper implements Schedulable, Database.Batchable<SObject> {
    @TestVisible private static final Integer SCOPE = 50;
    /** The six jobs this class used to register, so unschedule() can find them by name. */
    @TestVisible private static final String LEGACY_JOB_PREFIX = 'ADHA Hold Sweeper';

    /** One pass. Started by ADHA_ReservationSweeper's chain, or by hand to force a sweep. */
    public static Id run() {
        return Database.executeBatch(new ADHA_HoldSweeper(), SCOPE);
    }

    /** Clears the six ten-minute registrations still live in orgs that ran the old scheduler;
     *  returns how many it aborted so a migration can be checked. */
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
                // Already finished or already aborted. Not a reason to stop clearing the rest.
                System.debug(LoggingLevel.WARN, 'Could not abort ' + job.Id + ': ' + e.getMessage());
            }
        }
        return aborted;
    }

    /** Schedulable stays although nothing schedules this: dropping it while an org still holds
     *  the old jobs fails the deploy with "jobs pending or in progress". */
    public void execute(SchedulableContext context) {
        run();
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Unit_Lock_Key__c != null is the definition of live, matching the service and the other
        // sweeper. Signed rows are excluded: their clock is SLA_End__c, not this one.
        return Database.getQueryLocator([
            SELECT Id, Applicant__c, Status__c, Unit__c, Released_On__c, Journey_Log__c,
                   Hold_Expires_At__c
            FROM ADHA_Reservation__c
            WHERE Unit_Lock_Key__c != NULL
              AND Undertaking_Accepted__c = false
              AND Hold_Expires_At__c != NULL
              AND Hold_Expires_At__c < :System.now()
        ]);
    }

    public void execute(Database.BatchableContext context, List<ADHA_Reservation__c> scope) {
        // The re-read, the lock and the skip conditions all live in releaseLapsedHold now, because
        // the scheduled-path flow needs exactly the same decision and two copies would drift.
        for (ADHA_Reservation__c res : scope) {
            ADHA_ReservationService.releaseLapsedHold(res.Id);
        }
        ADHA_JourneyLog.flush();
    }

    public void finish(Database.BatchableContext context) {
        // The signing reconciler rides here so a signature from a customer who never returned is
        // still noticed.
        if (!Test.isRunningTest()) {
            ADHA_SignedCopyBatch.run();
        }
    }
}