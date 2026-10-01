public without sharing class ClearCasesInQueues 
{
    public static void ClearCases(List<SObject> newList)
    {
        List<Case> newCaseList = (List<Case>)newList;
        system.debug('start');
        if(newCaseList.size() == 0)
        {
            newCaseList = [select id,casenumber,ownerid,createddate,New_owner__c,status,ParentId,CaseType__c,Origin,casecategory__c,casesubcategory__c,Language_Preference__c from case 
                           where status = 'New' and casecategory__c  IN
                           ('Contact Center', 'Contact Center / Front Liners', 'Contact Details Update', 'Default & Collections', 'Department Action'
                            , 'Finance', 'Finance / Front Liners', 'General Enquiry', 'Handover', 'KYC Update', 'Operations'
                            , 'Post Sales', 'Real Estate Services', 'Service Request') 
                           AND ownerid not IN (SELECT id FROM User)  order by casesubcategory__c ];
        }
        system.debug('newCaseList.size() :' + newCaseList.size());
        if(newCaseList.size() > 0)
        {
            CaseTriggerHelper.assignToQueueOwner_Updated(newCaseList);
            update newCaseList;
        }
        system.debug('completed');
    }
}