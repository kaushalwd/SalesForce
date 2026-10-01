/*
@description       : Case History controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class CaseHistoryController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseHistoryData(Id recordId, Date startDate, Date endDate) {
        Map<String, String> fieldToValueMap = new Map<String, String>();

        // Default date filters (current year start → today)
        Date startDt = (startDate != null) ? startDate : Date.newInstance(System.today().year(), 1, 1);
        Date endDt = (endDate != null) ? endDate : System.today();

        //Datetime startDT = DateTime.newInstance(startDt, Time.newInstance(0, 0, 0, 0));
        Datetime endDTExclusive = DateTime.newInstance(endDt.addDays(1), Time.newInstance(0, 0, 0, 0));

        // Identify Account Record Type
        String recordTypeName = [
            SELECT RecordType.DeveloperName 
            FROM Account 
            WHERE Id = :recordId 
            LIMIT 1
        ].RecordType.DeveloperName;

        // Determine which account(s) to query
        List<Id> accountIds = new List<Id>();

        if (recordTypeName == 'OrganizationAccount') {
            accountIds.add(recordId);
        } else {
            accountIds.add(recordId);
        }

        // Fetch metadata
        List<Customer360_Field_Config__mdt> metadataList = [
            SELECT MasterLabel, Component_Name__c, Field_Name_In_Object__c, Order__c
            FROM Customer360_Field_Config__mdt
            WHERE Component_Name__c = 'Case History' AND Active__c = TRUE
            ORDER BY Order__c
        ];

        // Fetch counts (apply date filters)
        Integer totalLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE ConvertedAccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
        ];

        Integer openLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE ConvertedAccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
            AND Status != 'Closed'
        ];

        Integer totalCases = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
        ];

        Integer openCases = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
            AND Status IN ('New', 'In Progress')
        ];

        Integer closedCases = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
            AND Status IN ('Closed with Resolution', 'Closed without Resolution', 'Closed with Service Request', 'Closed as Duplicate','Closed')
        ];

        Integer breachedSlaCount = [
            SELECT COUNT()
            FROM CaseSLA__c
            WHERE Status__c = 'Breached'
            AND CaseId__r.AccountId IN :accountIds
            AND CreatedDate >= :startDt
            AND CreatedDate <= :endDTExclusive
        ];

        // Map values based on metadata
        for (Customer360_Field_Config__mdt meta : metadataList) {
            Decimal fieldValue = getFieldValue(
                meta.Field_Name_In_Object__c,
                totalLeads, openLeads, totalCases, openCases, closedCases, breachedSlaCount
            );
            fieldToValueMap.put(meta.MasterLabel, String.valueOf(fieldValue));
        }

        // Tooltip breakdown for latest 10 cases
        if (totalCases > 0) {
            List<Case> caseList = [
                SELECT Id, CaseNumber, Status, CaseCategory__c
                FROM Case
                WHERE AccountId IN :accountIds
                AND CreatedDate >= :startDt
                AND CreatedDate <= :endDTExclusive
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            List<String> tooltipData = new List<String>();
            for (Case c : caseList) {
                tooltipData.add(c.CaseNumber + '##' + c.Id + '##' + c.Status + '##' + String.valueOf(c.CaseCategory__c));
            }

            fieldToValueMap.put('Total Cases Tooltip', String.join(tooltipData, '||'));
        }

        return fieldToValueMap;
    }
    
     @AuraEnabled(cacheable=true)
    public static List<Case> getCaseList(
        Id recordId,
        Date startDate,
        Date endDate,
        String filterType
    ) {
        if (recordId == null) {
            return new List<Case>();
        }
        
        Date startDt = (startDate != null) ? startDate : Date.newInstance(System.today().year(), 1, 1);
        Date endDt   = (endDate != null) ? endDate : System.today();
        Datetime endDTExclusive = DateTime.newInstance(endDt.addDays(1), Time.newInstance(0, 0, 0, 0));

      
        Account acc = [
            SELECT RecordType.DeveloperName
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];
        String recordTypeName = acc.RecordType.DeveloperName;

        List<Id> accountIds = new List<Id>{ recordId };

        if (filterType == 'breached') {
            List<Case> breachedCases = new List<Case>();

            for (CaseSLA__c csla : [
                SELECT CaseId__r.Id,
                       CaseId__r.CaseNumber,
                       CaseId__r.Status,
                       CaseId__r.Subject,
                       CaseId__r.CreatedDate,
                       CaseId__r.Owner.Name,
                       CaseId__r.RecordType.Name
                FROM CaseSLA__c
                WHERE Status__c = 'Breached'
                AND CaseId__r.AccountId IN :accountIds
                AND CreatedDate >= :startDt
                AND CreatedDate <= :endDTExclusive
                ORDER BY CreatedDate DESC
            ]) {
                if (csla.CaseId__r != null) {
                    breachedCases.add(csla.CaseId__r);
                }
            }

            return breachedCases;
        }

        // SOQL injection fix: status filter branches are hardcoded; bind account/date values via queryWithBinds.
        String soql =
            'SELECT Id, CaseNumber, Status, Subject, CreatedDate, Owner.Name, RecordType.Name, CaseCategory__c ' +
            'FROM Case ' +
            'WHERE AccountId IN :accountIds ' +
            'AND CreatedDate >= :startDt ' +
            'AND CreatedDate <= :endDTExclusive ';

        if (filterType == 'open') {
            soql += 'AND Status IN (\'New\', \'In Progress\') ';
        } else if (filterType == 'closed') {
            soql +=
                'AND Status IN (' +
                '\'Closed with Resolution\', ' +
                '\'Closed without Resolution\', ' +
                '\'Closed with Service Request\', ' +
                '\'Closed as Duplicate\', ' +
                '\'Closed\'' +
                ') ';
        }
        // filterType == 'total' → no extra status condition

        soql += 'ORDER BY CreatedDate DESC';

        return Database.queryWithBinds(
            soql,
            new Map<String, Object>{
                'accountIds' => accountIds,
                'startDt' => startDt,
                'endDTExclusive' => endDTExclusive
            },
            AccessLevel.SYSTEM_MODE
        );
    }


    private static Decimal getFieldValue(
        String fieldName,
        Integer totalLeads,
        Integer openLeads,
        Integer totalCases,
        Integer openCases,
        Integer closedCases,
        Integer breachedSlaCount
    ) {
        if (fieldName == 'Total_Leads__c') return totalLeads;
        if (fieldName == 'Open_Leads__c') return openLeads;
        if (fieldName == 'Total_Cases__c') return totalCases;
        if (fieldName == 'Open_Cases__c') return openCases;
        if (fieldName == 'ClosedCases__c') return closedCases;
        if (fieldName == 'SlaBreached__c') return breachedSlaCount;
        return null;
    }
}