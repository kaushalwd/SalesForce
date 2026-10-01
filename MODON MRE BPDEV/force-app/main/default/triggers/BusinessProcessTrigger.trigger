trigger BusinessProcessTrigger on Business_Process__c (before update,after Insert,before Insert, after update) {
        new BusinessProcessHandler().run('BusinessProcess');
}