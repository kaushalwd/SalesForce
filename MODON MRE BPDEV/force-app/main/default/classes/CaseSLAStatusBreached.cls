public with sharing class CaseSLAStatusBreached implements Schedulable{
    public void execute(SchedulableContext sc) {
        List<CaseSLA__c> CaseSLAs = [SELECT Id, Name, CompletionDate__c, CaseOwner__c, EndTime__c, ExtentionTime__c, StartTime__c, DueTime__c 
            FROM CaseSLA__c 
            WHERE CompletionDate__c = NULL AND status__c != :ServiceConstants.CASESLA_STATUS_BREACHED];

        Datetime currentTime = System.now();
        List<CaseSLA__c> updateList = new List<CaseSLA__c>();

        for (CaseSLA__c csSLA : CaseSLAs) {
            if (csSLA.DueTime__c < currentTime) {
                csSLA.status__c = ServiceConstants.CASESLA_STATUS_BREACHED;
                csSLA.IsViolated__c = true;
                updateList.add(csSLA);
            }
        }

        if(updateList.size() > 0)
        {
            update updateList;
        }
    }
}