trigger registrationagent on Registration_Agent__c (after insert) {
if(trigger.isinsert && trigger.isafter){
Registrationagentstriggerhandler.createDocumentRecords(trigger.new);
}
}