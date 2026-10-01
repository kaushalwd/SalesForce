/*
@description       : ServiceRequestHistory Controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class ServiceRequestHistoryController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getServiceRequestData(Id recordId, Date startDate, Date endDate) {
        Map<String, String> srDataMap = new Map<String, String>();

        // Default date range = current year start to now
        Date startDt = (startDate != null) ? startDate : Date.newInstance(System.today().year(), 1, 1);
        Date endDt   = (endDate != null) ? endDate : System.today();

        //Datetime startDT = Datetime.newInstance(startDt, Time.newInstance(0,0,0,0));
        Datetime endDTExclusive = Datetime.newInstance(endDt.addDays(1), Time.newInstance(0,0,0,0));


        //Identify Account record type
        String recordTypeName = [
            SELECT RecordType.DeveloperName 
            FROM Account 
            WHERE Id = :recordId 
            LIMIT 1
        ].RecordType.DeveloperName;

        List<Id> relatedAccountIds = new List<Id>{ recordId };

        // Fetch metadata config
        List<Customer360_Field_Config__mdt> metadataList = [
            SELECT MasterLabel, Component_Name__c, Field_Name_In_Object__c, Order__c
            FROM Customer360_Field_Config__mdt
            WHERE Component_Name__c = 'Service Request History' AND Active__c = TRUE
            ORDER BY Order__c
        ];

        // Fetch Service Request counts (filtered by date)
        Integer totalSRs = [
            SELECT COUNT() 
            FROM ServiceRequest__c 
            WHERE AccountId__c IN :relatedAccountIds
            AND CreatedDate >= :startDt 
            AND CreatedDate <= :endDTExclusive
        ];

        Integer openSRs = [
            SELECT COUNT()
            FROM ServiceRequest__c
            WHERE AccountId__c IN :relatedAccountIds
            AND CreatedDate >= :startDt 
            AND CreatedDate <= :endDTExclusive
            AND Status__c IN ('New', 'In-progress')
        ];

        Integer closedSRs = [
            SELECT COUNT()
            FROM ServiceRequest__c
            WHERE AccountId__c IN :relatedAccountIds
            AND CreatedDate >= :startDt 
            AND CreatedDate <= :endDTExclusive
            AND Status__c IN (
                'Closed',
                'Closed (Paid)',
                'Cancelled',
                'Property Transfer Cancelled - SR',
                'Unit Swap Cancelled - SR',
                'Unit Upgrade Cancelled - SR',
                'Unit Cancellation Cancelled - SR'
            )
        ];

        Integer breachedSRs = [
            SELECT COUNT()
            FROM CaseSLA__c
            WHERE Status__c = 'Breached'
            AND Service_Request__r.AccountId__c IN :relatedAccountIds
            AND CreatedDate >= :startDt 
            AND CreatedDate <= :endDTExclusive
        ];

        // Add data to map dynamically using metadata
        for (Customer360_Field_Config__mdt meta : metadataList) {
            Decimal fieldValue = getFieldValue(meta.Field_Name_In_Object__c, totalSRs, openSRs, closedSRs, breachedSRs);
            srDataMap.put(meta.MasterLabel, String.valueOf(fieldValue));
        }
        // Stable keys for LWC
        srDataMap.put('Total SR', String.valueOf(totalSRs));
        srDataMap.put('Open SR', String.valueOf(openSRs));
        srDataMap.put('Closed SR', String.valueOf(closedSRs));
        srDataMap.put('SR Breached Cases', String.valueOf(breachedSRs));

        // Tooltip for Total SRs (latest 10)
        if (totalSRs > 0) {
            List<ServiceRequest__c> srList = [
                SELECT Id, Name, Status__c, CreatedDate
                FROM ServiceRequest__c
                WHERE AccountId__c IN :relatedAccountIds
                AND CreatedDate >= :startDt 
                AND CreatedDate <= :endDTExclusive
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            List<String> tooltipData = new List<String>();
            for (ServiceRequest__c sr : srList) {
                tooltipData.add(sr.Name + '##' + sr.Id + '##' + sr.Status__c);
            }

            srDataMap.put('Total SRs Tooltip', String.join(tooltipData, '||'));
        }

        return srDataMap;
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceRequest__c> getServiceRequestList(
        Id recordId,
        Date startDate,
        Date endDate,
        String filterType
    ) {
        if (recordId == null) {
            return new List<ServiceRequest__c>();
        }
    
        
        Date startDt = (startDate != null) ? startDate : Date.newInstance(System.today().year(), 1, 1);
        Date endDt   = (endDate != null) ? endDate : System.today();
    
        //Datetime startDT = Datetime.newInstance(startDt, Time.newInstance(0,0,0,0));
        Datetime endDTExclusive = Datetime.newInstance(endDt.addDays(1), Time.newInstance(0,0,0,0));
    
    
        
        Account acc = [
            SELECT RecordType.DeveloperName
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];
    
        List<Id> relatedAccountIds = new List<Id>{ recordId };
    
    
        List<String> openStatuses = new List<String>{'New', 'In-progress'};
        List<String> closedStatuses = new List<String>{
            'Closed', 'Closed (Paid)', 'Cancelled',
            'Property Transfer Cancelled - SR', 'Unit Swap Cancelled - SR',
            'Unit Upgrade Cancelled - SR', 'Unit Cancellation Cancelled - SR'
        };

        if (filterType == 'open') {
            return [
                SELECT Id, Name, Status__c, CreatedDate, Owner.Name, RecordType.Name 
                FROM ServiceRequest__c 
                WHERE AccountId__c IN :relatedAccountIds 
                AND CreatedDate >= :startDt 
                AND CreatedDate <= :endDTExclusive 
                AND Status__c IN :openStatuses
                ORDER BY CreatedDate DESC
            ];
        } else if (filterType == 'closed') {
            return [
                SELECT Id, Name, Status__c, CreatedDate, Owner.Name, RecordType.Name 
                FROM ServiceRequest__c 
                WHERE AccountId__c IN :relatedAccountIds 
                AND CreatedDate >= :startDt 
                AND CreatedDate <= :endDTExclusive 
                AND Status__c IN :closedStatuses
                ORDER BY CreatedDate DESC
            ];
        } else if (filterType == 'breached') {
            List<ServiceRequest__c> breachedList = new List<ServiceRequest__c>();
            for (CaseSLA__c csla : [
                SELECT Service_Request__r.Id,
                       Service_Request__r.Name,
                       Service_Request__r.Status__c,
                       Service_Request__r.CreatedDate,
                       Service_Request__r.Owner.Name,
                       Service_Request__r.RecordType.Name
                FROM CaseSLA__c
                WHERE Status__c = 'Breached'
                AND Service_Request__r.AccountId__c IN :relatedAccountIds
                AND CreatedDate >= :startDt
                AND CreatedDate <= :endDTExclusive
                ORDER BY CreatedDate DESC
            ]) {
                if (csla.Service_Request__r != null) {
                    breachedList.add(csla.Service_Request__r);
                }
            }
            return breachedList;
        } else {
            return [
                SELECT Id, Name, Status__c, CreatedDate, Owner.Name, RecordType.Name 
                FROM ServiceRequest__c 
                WHERE AccountId__c IN :relatedAccountIds 
                AND CreatedDate >= :startDt 
                AND CreatedDate <= :endDTExclusive 
                ORDER BY CreatedDate DESC
            ];
        }
    }


    private static Decimal getFieldValue(String fieldName, Integer totalSRs, Integer openSRs, Integer closedSRs, Integer breachedSRs) {
        if (fieldName == 'Total_ServiceRequests__c') return totalSRs;
        if (fieldName == 'Open_ServiceRequests__c') return openSRs;
        if (fieldName == 'Closed_ServiceRequests__c') return closedSRs;
        if (fieldName == 'Breached_ServiceRequests__c') return breachedSRs;
        return null;
    }
}