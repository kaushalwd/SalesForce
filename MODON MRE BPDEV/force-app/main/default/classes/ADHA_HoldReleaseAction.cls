/**********************************************************************************************************************
* Name               : ADHA_HoldReleaseAction
* Description        : Lets the scheduled-path flow free a lapsed hold the moment it expires. Thin on purpose: every
*                      release rule lives in ADHA_ReservationService.releaseLapsedHold, which re-reads under a lock.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     24 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_HoldReleaseAction {

    @InvocableMethod(
        label='Release Lapsed ADHA Hold'
        description='Frees the villa if this hold has expired and the undertaking was never accepted. Does nothing otherwise.'
        category='ADHA Baniyas'
    )
    public static void run(List<Id> reservationIds) {
        if (reservationIds == null || reservationIds.isEmpty()) {
            return;
        }
        for (Id reservationId : reservationIds) {
            try {
                ADHA_ReservationService.releaseLapsedHold(reservationId);
            } catch (Exception e) {
                // One stuck row must not fail the whole invocation and lose the others. The sweeper
                // will pick this one up within ten minutes, which is exactly what it is there for.
                System.debug(LoggingLevel.ERROR,
                    'Scheduled hold release failed for ' + reservationId + ': ' + e.getMessage());
            }
        }
        ADHA_JourneyLog.flush();
    }
}