/**********************************************************************************************************************
* Name               : CaseSLAController                                                        
* Description        : Provides SLA details related to a Case. Used by Lightning components (LWC/Aura) to fetch latest CaseSLA__c record.
* Usage              : Called from LWC page
* Created By         : Active Minds Global Solutions Pvt Ltd                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      				Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com		04 Mar 2025     Initial Draft     
* 2.0			ravikumar.pasumarthi@activemindsit.com		12 Nov 2025		Added Response_SLA__c in the SOQL
* 3.0			ravikumar.pasumarthi@activemindsit.com		08 May 2025		Added CaseId__r.IsClosed in the SOQL
******************************************************************************************************************/
public class CaseSLAController {
    @AuraEnabled(cacheable=true)
    public static CaseSLA__c getCaseDetails(Id caseId) {
        CaseSLA__c returnObject = null;
        List<CaseSLA__c> caseSLAList = [
            SELECT Id, CaseId__c,CaseId__r.Status, CaseOwner__c,EndTime__c,Status__c,StartTime__c,DueTime__c,Response_SLA__c,CaseId__r.IsClosed //3.0
            FROM CaseSLA__C
            WHERE CaseId__c = :caseId ORDER BY CreatedDate DESC];
            System.debug('Fetched Case SLA Records: ' + caseSLAList);
        if(caseSLAList.size() > 0)
        {
            returnObject = caseSLAList[0];
        }
        return returnObject;
    }
    //Replaced the below code with above to avoid 'List has no rows for assignment to SObject' exception when there are no records returned by the query with LIMIT option
    /*public static CaseSLA__c getCaseDetails(Id caseId) {
        return [
            SELECT Id, CaseId__c,CaseId__r.Status, CaseOwner__c,DueTime__C,EndTime__c,StartTime__c,Status__c
            FROM CaseSLA__C
            WHERE CaseId__c = :caseId
            LIMIT 1
        ];
    }*/
}