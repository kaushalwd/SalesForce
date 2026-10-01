/**
 * Turns an immediately-published journey event into the Task it could not write itself. Runs in its
 * own transaction, which is the whole point: the one that published it was rolled back.
 */
trigger ADHA_JourneyEventTrigger on ADHA_Journey_Event__e (after insert) {
    ADHA_JourneyLog.fromEvents(Trigger.new);
}