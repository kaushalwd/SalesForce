trigger RegistrationTrigger on Registration__c (before insert, before update, after insert, after update) {
    
    if(Trigger.isAfter && (Trigger.isUpdate)){
        MBP_RegistrationTriggerHandler.createServiceRequest(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && (Trigger.isInsert)){
        MBP_RegistrationTriggerHandler.createDocumentRecords(Trigger.new);
    }
}