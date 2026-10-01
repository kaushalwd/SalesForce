public with sharing class ManagerBoardCaseController {
    

    @AuraEnabled(cacheable=true)
    public static List<CaseWrapper> getCases() {
        List<Case> cases = [
            SELECT
                Id,
                CaseNumber,
                Status,
                CaseType__c,
                Breached__c,
                CaseCategory__c,
                CaseSubCategory__c,
                Owner.Name,
                Primary_Assignee__r.Name,
                SR_Number__c,
                Requestor_Name__c,
                CreatedDate
            FROM Case
            WHERE status IN ('New', 'In Progress')
            AND RecordType.name = '800 Modon Cases' 
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        List<CaseWrapper> wrapped = new List<CaseWrapper>();
        for (Case c : cases) {
            wrapped.add(new CaseWrapper(c));
        }
        return wrapped;
    }

    public class CaseWrapper {
        @AuraEnabled public Id     caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String caseUrl;
        @AuraEnabled public String status;
        @AuraEnabled public String caseType;
        @AuraEnabled public Boolean breached;
        @AuraEnabled public String caseCategory;
        @AuraEnabled public String caseSubCategory;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String primaryAssignee;
        @AuraEnabled public String srNumber;
        @AuraEnabled public String requestorName;
        @AuraEnabled public DateTime createdDate;

        public CaseWrapper(Case c) {
            this.caseId          = c.Id;
            this.caseNumber      = c.CaseNumber;
            this.caseUrl         = '/' + c.Id;
            this.status          = c.Status;
            this.caseType        = c.CaseType__c;
            this.breached        = c.Breached__c;
            this.caseCategory    = c.CaseCategory__c;
            this.caseSubCategory = c.CaseSubCategory__c;
            this.ownerName       = c.Owner.Name;
            this.primaryAssignee = c.Primary_Assignee__r != null ? c.Primary_Assignee__r.Name : null;
            this.srNumber        = c.SR_Number__c;
            this.requestorName   = c.Requestor_Name__c;
            this.createdDate     = c.CreatedDate;
        }
    }
}