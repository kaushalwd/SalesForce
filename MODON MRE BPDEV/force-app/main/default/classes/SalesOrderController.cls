/*
@description       : Salesorder controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class SalesOrderController {

   @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSalesOrderCount(Id brokerAgencyId) {
        List<Map<String, Object>> countList = new List<Map<String, Object>>();
    
        if (brokerAgencyId == null) return countList; // ← safety check
    
        List<AggregateResult> results = [
            SELECT Status__c status, COUNT(Id) cnt
            FROM SalesOrder__c
            WHERE Opportunity__r.BrokerAgency__r.Id = :brokerAgencyId
            AND Opportunity__r.BrokerAgency__r.Id != null
            AND CustomerAccount__r.Name != null
            AND Status__c IN ('Completed', 'New', 'In Progress')
            GROUP BY Status__c
        ];
    
        for (AggregateResult ar : results) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('status', (String) ar.get('status'));
            row.put('count',  (Integer) ar.get('cnt'));
            countList.add(row);
        }
    
        return countList;
    }
       
       
       
        @AuraEnabled(cacheable=true)
        public static List<Map<String, Object>> getSalesOrders(
            Id accountId,
            Date startDateOptional,
            Date endDateOptional,
            String projectNameOptional,
            String unitNameOptional
        ) {
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            if (accountId == null) return results;
    
            // Determine Account Type
            Account acc = [
                SELECT Id, RecordType.DeveloperName
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
    
            //Date filters
            Date startDate;
            Date endDate;
            if (startDateOptional != null && endDateOptional != null) {
                startDate = startDateOptional;
                endDate = endDateOptional;
            } else {
                startDate = Date.newInstance(System.now().year(), 1, 1);
                endDate = Date.newInstance(System.now().year(), 12, 31);
            }
            Datetime startDT = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            Datetime endDTExclusive = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
    
            //Collect account IDs related to this account
            Set<Id> targetAccountIds = new Set<Id>{accountId};
    
            if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
                List<Contact> primaryContacts = [
                    SELECT Id, AccountId
                    FROM Contact
                    WHERE AccountId = :accountId
                    AND Primary_Owner__c = TRUE
                ];
            }
    
            List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
    
            List<String> excludeStatuses = new List<String>{
                'Cancelled', 'System cancelled', 'Cancelled SR', 'Voided',
                'Property Transfer Cancelled - SR', 'Unit Swap Cancelled - SR',
                'Unit Upgrade Cancelled - SR', 'Unit Cancellation Cancelled - SR',
                'Unit Consolidation Cancelled - SR', 'Property Transfer Title Deed Cancelled - SR'
            };

            // Fetch direct Sales Orders
            String baseSOQL =
                'SELECT Id, Name, Opportunity__c, Opportunity__r.Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
                ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
                ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c, Unit__c,' +
                ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
                ' Number_of_JointOwners__c, CreatedDate' +
                ' FROM SalesOrder__c WHERE CustomerAccount__c IN :targetAccountIds' +
                ' AND ProjectName__c != NULL' +
                ' AND CreatedDate >= :startDate AND CreatedDate <= :endDTExclusive' +
                ' AND Status__c NOT IN :excludeStatuses';
            Map<String, Object> directBinds = new Map<String, Object>{
                'targetAccountIds' => targetAccountIds,
                'startDate' => startDate,
                'endDTExclusive' => endDTExclusive,
                'excludeStatuses' => excludeStatuses
            };
            if (String.isNotBlank(projectNameOptional)) {
                baseSOQL += ' AND ProjectName__c = :projectNameOptional';
                directBinds.put('projectNameOptional', projectNameOptional);
            }
            if (String.isNotBlank(unitNameOptional)) {
                baseSOQL += ' AND Unit_Name__c = :unitNameOptional';
                directBinds.put('unitNameOptional', unitNameOptional);
            }
    
            List<SalesOrder__c> directOrders = (List<SalesOrder__c>) Database.queryWithBinds(
                baseSOQL,
                directBinds,
                AccessLevel.SYSTEM_MODE
            );

            // Fetch via Joint Owners
            String jointSOQL =
                'SELECT Id, Name,Opportunity__c, Opportunity__r.Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
                ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
                ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c, Unit__c,' +
                ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
                ' Number_of_JointOwners__c, CreatedDate' +
                ' FROM SalesOrder__c WHERE Id IN (' +
                ' SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c IN :targetAccountIds)' +
                ' AND ProjectName__c != NULL' +
                ' AND CreatedDate >= :startDate AND CreatedDate <= :endDTExclusive' +
                ' AND Status__c NOT IN :excludeStatuses';
    
            Map<String, Object> jointBinds = new Map<String, Object>{
                'targetAccountIds' => targetAccountIds,
                'startDate' => startDate,
                'endDTExclusive' => endDTExclusive,
                'excludeStatuses' => excludeStatuses
            };
            if (String.isNotBlank(projectNameOptional)) {
                jointSOQL += ' AND ProjectName__c = :projectNameOptional';
                jointBinds.put('projectNameOptional', projectNameOptional);
            }
            if (String.isNotBlank(unitNameOptional)) {
                jointSOQL += ' AND Unit_Name__c = :unitNameOptional';
                jointBinds.put('unitNameOptional', unitNameOptional);
            }
    
            List<SalesOrder__c> jointOrders = (List<SalesOrder__c>) Database.queryWithBinds(
                jointSOQL,
                jointBinds,
                AccessLevel.SYSTEM_MODE
            );
    
            allOrders.addAll(directOrders);
            allOrders.addAll(jointOrders);
    
            // Fetch Joint Owners and pre-build response map (eliminating nested loops)
            Map<Id, List<Map<String, Object>>> jointOwnerDataMap = new Map<Id, List<Map<String, Object>>>();
            if (!allOrders.isEmpty()) {
                List<JointOwner__c> jointOwners = [
                    SELECT Id, JointOwnerAccount__c, OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c,
                           JointOwnerAccount__r.Name, Opportunity__r.Name, SalesOrder__c
                    FROM JointOwner__c
                    WHERE SalesOrder__c IN :allOrders
                ];
                for (JointOwner__c jo : jointOwners) {
                    if (!jointOwnerDataMap.containsKey(jo.SalesOrder__c)) {
                        jointOwnerDataMap.put(jo.SalesOrder__c, new List<Map<String, Object>>());
                    }
                    jointOwnerDataMap.get(jo.SalesOrder__c).add(new Map<String, Object>{
                        'OwnershipPercentage__c' => jo.OwnershipPercentage__c,
                        'RelationshipType__c' => jo.RelationshipType__c,
                        'RelationshipSubType__c' => jo.RelationshipSubType__c,
                        'JointOwnerAccount__c' => jo.JointOwnerAccount__c,
                        'JointOwnerAccount__r' => new Map<String, Object>{
                            'Name' => jo.JointOwnerAccount__r != null ? jo.JointOwnerAccount__r.Name : null
                        },
                        'Opportunity__r' => new Map<String, Object>{
                            'Name' => jo.Opportunity__r != null ? jo.Opportunity__r.Name : null
                        },
                        'SalesOrder__c' => jo.SalesOrder__c
                    });
                }
            }
    
            // Fetch "Exterior" document images
            Map<Id, String> unitToImageMap = new Map<Id, String>();
            Set<Id> unitIds = new Set<Id>();
            for (SalesOrder__c so : allOrders) {
                if (so.Unit__c != null) unitIds.add(so.Unit__c);
            }
            if (!unitIds.isEmpty()) {
                List<Documents__c> exteriorDocs = [
                    SELECT Id, Name, Unit__c,
                           (SELECT ContentDocument.LatestPublishedVersionId
                            FROM ContentDocumentLinks
                            WHERE ContentDocument.FileType IN ('PNG', 'JPG', 'JPEG', 'GIF')
                            LIMIT 1)
                    FROM Documents__c
                    WHERE Name = 'Exterior' AND Unit__c IN :unitIds
                ];
                for (Documents__c doc : exteriorDocs) {
                    if (!doc.ContentDocumentLinks.isEmpty()) {
                        String versionId = doc.ContentDocumentLinks[0].ContentDocument.LatestPublishedVersionId;
                        if (versionId != null) {
                            unitToImageMap.put(
                                doc.Unit__c,
                                '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + versionId
                            );
                        }
                    }
                }
            }
    
            //  Get Aging Summary (Pending / Paid / Outstanding)
            Map<Id, Map<String, Decimal>> agingSummaryMap = getAgingSummary(allOrders);
    
            // Build Response
            for (SalesOrder__c so : allOrders) {
                Boolean hasJointOwners = jointOwnerDataMap.containsKey(so.Id);
                List<Map<String, Object>> jointOwnerData = hasJointOwners 
                    ? jointOwnerDataMap.get(so.Id) 
                    : new List<Map<String, Object>>();
    
                Map<String, Decimal> aging = agingSummaryMap.containsKey(so.Id)
                    ? agingSummaryMap.get(so.Id)
                    : new Map<String, Decimal>();
    
                results.add(new Map<String, Object>{
                    'Id' => so.Id,
                    'Name' => so.Name,
                    'Opportunity__c' => so.Opportunity__c,
                    'Opportunity__r' => new Map<String, Object>{
                        'Name' => so.Opportunity__r != null ? so.Opportunity__r.Name : null
                    },
                    'ProjectName__c' => so.ProjectName__c,
                    'TotalAmount__c' => so.TotalAmount__c,
                    'Totalpaidamount__c' => so.Totalpaidamount__c,
                    'PendingAmount__c' => aging.get('Pending'),
                    'PaidAmount__c' => aging.get('Paid'),
                    'OutstandingAmount__c' => aging.get('Outstanding'),
                    'FutureAmount__c' => aging.get('Future'),
                    'PaymentPlan__r' => new Map<String, Object>{ 'Name' => so.PaymentPlan__r != null ? so.PaymentPlan__r.Name : null },
                    'Phase_Name__c' => so.Phase_Name__c,
                    
                    'CustomerAccount__c' => so.CustomerAccount__c,
                    'Unit__c' => so.Unit__c,
    
                    'Unit_Name__c' => so.Unit_Name__c,
                    'Unit__r' => new Map<String, Object>{
                        'Status__c' => so.Unit__r != null ? so.Unit__r.Status__c : null,
                        'UnitClassification__c' => so.Unit__r != null ? so.Unit__r.UnitClassification__c : null,
                        'Unit_Sold_Date__c' => so.Unit__r != null ? so.Unit__r.Unit_Sold_Date__c : null,
                        'ImageURL' => (so.Unit__c != null && unitToImageMap.containsKey(so.Unit__c)) ? unitToImageMap.get(so.Unit__c) : null
                    },
                    'CustomerAccount__r' => new Map<String, Object>{ 'Name' => so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null },
                    'Number_of_JointOwners__c' => so.Number_of_JointOwners__c,
                    'HasJointOwners' => hasJointOwners,
                    'JointOwners' => jointOwnerData
                });
            }
            return results;
        }
    
        // Updated Aging Summary — follows CollectionInsight logic
        // Updated Aging Summary — aligned with CollectionInsight milestone logic
    private static Map<Id, Map<String, Decimal>> getAgingSummary(List<SalesOrder__c> salesOrders) {
        Map<Id, Map<String, Decimal>> summaryMap = new Map<Id, Map<String, Decimal>>();
        if (salesOrders.isEmpty()) return summaryMap;
    
        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : salesOrders) soIds.add(so.Id);
    
        Date today = Date.today();
    
        // 1) Fetch installments WITH MilestoneDate
        List<SalesOrderInstallments__c> installments = [
            SELECT Id, SalesOrder__c, InstallmentAmount__c, MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :soIds
        ];
    
        // init aggregates
        Map<Id, Decimal> billedBySO = new Map<Id, Decimal>();
        Map<Id, Decimal> futureBySO = new Map<Id, Decimal>();
    
        Set<Id> billedInstIds = new Set<Id>();
        Set<Id> futureInstIds = new Set<Id>();
        Map<Id, Id> instToSO = new Map<Id, Id>();
    
        for (SalesOrderInstallments__c inst : installments) {
            instToSO.put(inst.Id, inst.SalesOrder__c);
    
            Decimal instAmt = inst.InstallmentAmount__c == null ? 0 : inst.InstallmentAmount__c;
    
            // null milestone -> treat as future
            if (inst.MilestoneDate__c == null || inst.MilestoneDate__c > today) {
                futureInstIds.add(inst.Id);
                futureBySO.put(inst.SalesOrder__c, (futureBySO.get(inst.SalesOrder__c) == null ? 0 : futureBySO.get(inst.SalesOrder__c)) + instAmt);
            } else {
                billedInstIds.add(inst.Id);
                billedBySO.put(inst.SalesOrder__c, (billedBySO.get(inst.SalesOrder__c) == null ? 0 : billedBySO.get(inst.SalesOrder__c)) + instAmt);
            }
        }
    
        // 2) Fetch receipts for all installments
        Map<Id, Decimal> paidTotalBySO = new Map<Id, Decimal>();
        Map<Id, Decimal> paidBilledBySO = new Map<Id, Decimal>();
        Map<Id, Decimal> paidFutureBySO = new Map<Id, Decimal>();
    
        if (!instToSO.isEmpty()) {
            List<Receipt__c> receipts = [
                SELECT Id, TotalAmount__c, EBS_Clearing_Date__c, SalesOrderInstallment__c
                FROM Receipt__c
                WHERE SalesOrderInstallment__c IN :instToSO.keySet()
            ];
    
            for (Receipt__c r : receipts) {
                if (r.TotalAmount__c == null) continue;
                if (r.EBS_Clearing_Date__c == null) continue; // only cleared counts as collected
    
                Id instId = r.SalesOrderInstallment__c;
                Id soId = instToSO.get(instId);
                if (soId == null) continue;
    
                Decimal amt = r.TotalAmount__c;
    
                // total collected (for the card "Paid Amount")
                paidTotalBySO.put(soId, (paidTotalBySO.get(soId) == null ? 0 : paidTotalBySO.get(soId)) + amt);
    
                // split paid into billed vs future buckets
                if (billedInstIds.contains(instId)) {
                    paidBilledBySO.put(soId, (paidBilledBySO.get(soId) == null ? 0 : paidBilledBySO.get(soId)) + amt);
                } else if (futureInstIds.contains(instId)) {
                    paidFutureBySO.put(soId, (paidFutureBySO.get(soId) == null ? 0 : paidFutureBySO.get(soId)) + amt);
                }
            }
        }
    
        // 3) Build final SO summary
        for (SalesOrder__c so : salesOrders) {
            Decimal billed = billedBySO.get(so.Id) == null ? 0 : billedBySO.get(so.Id);
            Decimal future = futureBySO.get(so.Id) == null ? 0 : futureBySO.get(so.Id);
    
            Decimal paidTotal = paidTotalBySO.get(so.Id) == null ? 0 : paidTotalBySO.get(so.Id);
            Decimal paidBilled = paidBilledBySO.get(so.Id) == null ? 0 : paidBilledBySO.get(so.Id);
            Decimal paidFuture = paidFutureBySO.get(so.Id) == null ? 0 : paidFutureBySO.get(so.Id);
    
            // Outstanding is only for billed bucket
            Decimal outstanding = billed - paidBilled;
            if (outstanding < 0) outstanding = 0;
    
            // Reduce future if money already collected for future
            Decimal futureRemaining = future - paidFuture;
            if (futureRemaining < 0) futureRemaining = 0;
    
            summaryMap.put(so.Id, new Map<String, Decimal>{
                'Paid' => paidTotal,                 // this will become 7.20M in your example
                'Outstanding' => outstanding,        // billed - paidAgainstBilled
                'Future' => futureRemaining          // future - paidAgainstFuture
            });
        }
    
        return summaryMap;
    }


}