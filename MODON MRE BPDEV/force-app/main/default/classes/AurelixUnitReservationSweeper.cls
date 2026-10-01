/**
 * AurelixUnitReservationSweeper - gives back lapsed unit reservations every few minutes.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  29 Sep 2026  Runs AurelixUnitReservation.sweep on a schedule, because MODON's
 *                                    BookingFeeTimerScheduler fails in DEV.
 *
 * Reschedules itself like MODON's CheckoutPaymentPoller: next run first, then the fired trigger is aborted,
 * so one job waits. Start once from anonymous Apex with start(); stop() removes it.
 */
public without sharing class AurelixUnitReservationSweeper implements Schedulable {

    public static final String JOB_PREFIX = 'Aurelix Unit Reservation Sweep';
    @TestVisible private static final Integer INTERVAL_MINUTES = 5;

    public void execute(SchedulableContext sc) {
        if (!Test.isRunningTest()) {
            scheduleNext();
        }
        if (sc != null && sc.getTriggerId() != null) {
            try {
                System.abortJob(sc.getTriggerId());
            } catch (Exception e) {
                // already gone: nothing to retire
            }
        }
        try {
            AurelixUnitReservation.sweep();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AurelixUnitReservationSweeper: ' + e.getMessage());
        }
    }

    /** Removes any waiting sweep and schedules one. Returns the new job's id. */
    public static Id start() {
        stop();
        return scheduleNext();
    }

    /** Removes every waiting sweep. */
    public static void stop() {
        String prefix = JOB_PREFIX + '%';
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :prefix]) {
            try {
                System.abortJob(ct.Id);
            } catch (Exception e) {
                // finished in the meantime
            }
        }
    }

    private static Id scheduleNext() {
        Datetime next = System.now().addMinutes(INTERVAL_MINUTES);
        return System.schedule(
            JOB_PREFIX + ' ' + next.getTime(),
            /* the running user's time zone, which is the one a cron expression is read in */
            next.format('ss mm HH dd MM ? yyyy'),
            new AurelixUnitReservationSweeper()
        );
    }
}