trigger EOIJourneyEventTrigger on EOI_Journey_Event__e (after insert) {
    EoiJourneyLog.fromEvents(Trigger.new);
}