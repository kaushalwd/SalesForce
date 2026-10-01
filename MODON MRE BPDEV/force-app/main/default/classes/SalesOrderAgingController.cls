/*
@description       : Salesorder aging controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class SalesOrderAgingController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getAgingSummary(Id accountId, Date startDate, Date endDate, String projectName, String unitName) {
    
        Map<String, Decimal> agingMap = new Map<String, Decimal>{
            '< 30 Days' => 0,
            '30-60 Days' => 0,
            '60-90 Days' => 0,
            '> 90 Days' => 0
        };
    
        if (accountId == null) {
            return agingMap;
        }
    
        // --- Get Account Record ---
        Account acc = [
            SELECT Id, RecordType.DeveloperName, IsPersonAccount
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        String recordTypeName = acc.RecordType.DeveloperName;

    
        // --- Default Date Range ---
        DateTime now = System.now();
        if (startDate == null) startDate = Date.newInstance(now.year(), 1, 1);
        if (endDate == null) endDate = Date.newInstance(now.year(), 12, 31);

    
        Datetime startDT = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)); // start of day
        Datetime endDTExclusive = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0)); // next day start
        
    
        // --- Collect Sales Orders ---
        List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
        List<Id> targetAccountIds = new List<Id>{ accountId };
    
        if (!targetAccountIds.isEmpty()) {
            List<String> excludeStatuses = new List<String>{
                'Cancelled', 'System cancelled', 'Cancelled SR', 'Voided',
                'Property Transfer Cancelled - SR', 'Unit Swap Cancelled - SR',
                'Unit Upgrade Cancelled - SR', 'Unit Cancellation Cancelled - SR',
                'Unit Consolidation Cancelled - SR', 'Property Transfer Title Deed Cancelled - SR'
            };

            // Fetch direct Sales Orders
            String directQuery = 
                'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
                ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
                ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c,' +
                ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
                ' Number_of_JointOwners__c, CreatedDate ' +
                'FROM SalesOrder__c ' +
                'WHERE CustomerAccount__c IN :targetAccountIds ' +
                'AND ProjectName__c != NULL ' +
                'AND CreatedDate >= :startDT ' +
                'AND CreatedDate <= :endDTExclusive ' +
                'AND Status__c NOT IN :excludeStatuses';
    
            Map<String, Object> directBinds = new Map<String, Object>{
                'targetAccountIds' => targetAccountIds,
                'startDT' => startDT,
                'endDTExclusive' => endDTExclusive,
                'excludeStatuses' => excludeStatuses
            };
            if (String.isNotBlank(projectName)) {
                directQuery += ' AND ProjectName__c = :projectName';
                directBinds.put('projectName', projectName);
            }
            if (String.isNotBlank(unitName)) {
                directQuery += ' AND Unit_Name__c = :unitName';
                directBinds.put('unitName', unitName);
            }
    
            List<SalesOrder__c> directOrders = (List<SalesOrder__c>) Database.queryWithBinds(
                directQuery,
                directBinds,
                AccessLevel.SYSTEM_MODE
            );

            // Fetch via Joint Owners
            String jointQuery = 
                'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
                ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
                ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c,' +
                ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
                ' Number_of_JointOwners__c, CreatedDate ' +
                'FROM SalesOrder__c ' +
                'WHERE Id IN (SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c IN :targetAccountIds) ' +
                'AND ProjectName__c != NULL ' +
                'AND CreatedDate >= :startDT ' +
                'AND CreatedDate <= :endDTExclusive ' +
                'AND Status__c NOT IN :excludeStatuses';
    
            Map<String, Object> jointBinds = new Map<String, Object>{
                'targetAccountIds' => targetAccountIds,
                'startDT' => startDT,
                'endDTExclusive' => endDTExclusive,
                'excludeStatuses' => excludeStatuses
            };
            if (String.isNotBlank(projectName)) {
                jointQuery += ' AND ProjectName__c = :projectName';
                jointBinds.put('projectName', projectName);
            }
            if (String.isNotBlank(unitName)) {
                jointQuery += ' AND Unit_Name__c = :unitName';
                jointBinds.put('unitName', unitName);
            }
    
            List<SalesOrder__c> jointOrders = (List<SalesOrder__c>) Database.queryWithBinds(
                jointQuery,
                jointBinds,
                AccessLevel.SYSTEM_MODE
            );
    
            allOrders.addAll(directOrders);
            allOrders.addAll(jointOrders);
    
            // Fetch Joint Owners for all related SalesOrders
            Map<Id, List<JointOwner__c>> jointOwnerMap = new Map<Id, List<JointOwner__c>>();
            if (!allOrders.isEmpty()) {
                List<JointOwner__c> jointOwners = [
                    SELECT Id, OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c,
                           JointOwnerAccount__r.Name, Opportunity__r.Name, SalesOrder__c
                    FROM JointOwner__c
                    WHERE SalesOrder__c IN :allOrders
                ];
                for (JointOwner__c jo : jointOwners) {
                    if (!jointOwnerMap.containsKey(jo.SalesOrder__c)) {
                        jointOwnerMap.put(jo.SalesOrder__c, new List<JointOwner__c>());
                    }
                    jointOwnerMap.get(jo.SalesOrder__c).add(jo);
                }
            }
        }
    
        if (allOrders.isEmpty()) return agingMap;
    
        // --- Get Installments (Unpaid Only) ---
        List<Id> orderIds = new List<Id>();
        for (SalesOrder__c so : allOrders) orderIds.add(so.Id);
    
        List<SalesOrderInstallments__c> installments = [
            SELECT Id, SalesOrder__c, InstallmentAmount__c,Balance_Amount__c, CreatedDate, PaymentStatus__c,MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :orderIds
            AND (PaymentStatus__c = NULL OR PaymentStatus__c != 'Paid')
        ];
    
        if (installments.isEmpty()) return agingMap;
    
        // --- Get Receipts (Pending Only) ---
        List<Id> installmentIds = new List<Id>();
        for (SalesOrderInstallments__c inst : installments) installmentIds.add(inst.Id);
    
        List<Receipt__c> receipts = [
            SELECT Id, TotalAmount__c, EBS_Clearing_Date__c, SalesOrderInstallment__c
            FROM Receipt__c
            WHERE SalesOrderInstallment__c IN :installmentIds
            AND (EBS_Clearing_Date__c = NULL)
        ];
    
        
    
        // --- Group Receipts by Installment ---
        Map<Id, List<Receipt__c>> receiptsByInstallment = new Map<Id, List<Receipt__c>>();
        for (Receipt__c rec : receipts) {
            if (!receiptsByInstallment.containsKey(rec.SalesOrderInstallment__c)) {
                receiptsByInstallment.put(rec.SalesOrderInstallment__c, new List<Receipt__c>());
            }
            receiptsByInstallment.get(rec.SalesOrderInstallment__c).add(rec);
        }
    
        // --- Calculate Aging (Outstanding per SalesOrder, bucketed by next unpaid milestone) ---
        // --- Calculate Aging (ONLY overdue unpaid installments) ---
        Date today = Date.today();
       
    
        
        // Bucket overdue amounts per installment (NOT per SalesOrder)
    	for (SalesOrderInstallments__c inst : installments) {
    
        Date dueDate = (inst.MilestoneDate__c != null)
            ? inst.MilestoneDate__c
            : inst.CreatedDate.date();
    
        // only overdue
        if (dueDate > today) continue;
    
        Decimal installmentAmt = (inst.Balance_Amount__c != null)
            ? inst.Balance_Amount__c
            : (inst.InstallmentAmount__c != null ? inst.InstallmentAmount__c : 0);
    
        if (installmentAmt <= 0) continue;
    
        Integer age = dueDate.daysBetween(today); // days overdue
    
        if (age < 30)
            agingMap.put('< 30 Days', agingMap.get('< 30 Days') + installmentAmt);
        else if (age < 60)
            agingMap.put('30-60 Days', agingMap.get('30-60 Days') + installmentAmt);
        else if (age < 90)
            agingMap.put('60-90 Days', agingMap.get('60-90 Days') + installmentAmt);
        else
            agingMap.put('> 90 Days', agingMap.get('> 90 Days') + installmentAmt);
    }
    
    
        return agingMap;
    
    
    }
    
        @AuraEnabled(cacheable=true)
        public static Map<String, Integer> getServiceRequestSummary(
            Id accountId,
            Date startDate,
            Date endDate
        ) {
            Map<String, Integer> resultMap = new Map<String, Integer>();
    
            // Default current year filters
            DateTime now = System.now();
            if (startDate == null) startDate = Date.newInstance(now.year(), 1, 1);
            if (endDate == null) endDate = Date.newInstance(now.year(), 12, 31);
    
            Datetime startDT = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            Datetime endDTExclusive = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
    
            if (accountId == null) return resultMap;
    
            // GLOBAL summary (not based on accountId) for ALL record types
            List<AggregateResult> groupedResults = [
                SELECT RecordType.Name recordTypeName, COUNT(Id) cnt
                FROM ServiceRequest__c
                WHERE  AccountId__c = :accountId
                AND CreatedDate >= :startDT
                AND CreatedDate < :endDTExclusive
                GROUP BY RecordType.Name
            ];
    
            for (AggregateResult ar : groupedResults) {
                String rtName = (String) ar.get('recordTypeName');
                Integer count = (Integer) ar.get('cnt');
                resultMap.put(rtName, count);
            }
    
            return resultMap;
        }
}