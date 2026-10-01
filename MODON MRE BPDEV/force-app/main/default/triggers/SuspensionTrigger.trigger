trigger SuspensionTrigger on Suspension_Warning__c (before insert, before update, after insert, after update) {
    
    if(Trigger.isAfter && (Trigger.isInsert)){
        MBP_SuspensionTriggerHandler.createDocumentRecords(Trigger.new);
    }
    if(Trigger.isAfter && (Trigger.isUpdate)){
        MBP_SuspensionTriggerHandler.stampAccountOnApproval(Trigger.new, Trigger.OldMap);
    }
}