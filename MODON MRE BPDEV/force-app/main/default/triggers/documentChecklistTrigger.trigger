trigger documentChecklistTrigger on Document_Checklist__c (before insert,before update,after insert,after update) {
     //new DocumentChecklistTriggerHandler().run('Document_Checklist__c');
    if(Trigger.isInsert && Trigger.isAfter){
        SalesOrderStatusAutomationHelper.handleStsUpdateFromDocuChecklist(trigger.new, trigger.oldMap);
    }
    if(Trigger.isupdate && Trigger.isAfter){
        SalesOrderStatusAutomationHelper.handleStsUpdateFromDocuChecklist(trigger.new, trigger.oldMap);
    }
}