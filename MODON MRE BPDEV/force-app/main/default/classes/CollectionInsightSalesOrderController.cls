/*
@description       : Collection Insight sales order controller for customer360. The test class for this class is CollectionInsightSOControllerTest
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class CollectionInsightSalesOrderController {   

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getSalesOrderData(
        Id salesOrderId,
        Date startDate,
        Date endDate,
        String projectName,
        String unitName
    ) {
        Account acc = [
            SELECT Id, RecordType.DeveloperName, IsPersonAccount
            FROM Account
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        Id effectiveAccountId = salesOrderId;

        if (!acc.IsPersonAccount && acc.RecordType.DeveloperName == 'OrganizationAccount') {
            List<Contact> primaryContacts = [
                SELECT Id, AccountId, Primary_Owner__c
                FROM Contact
                WHERE AccountId = :salesOrderId
                AND Primary_Owner__c = TRUE
                LIMIT 1
            ];
            if (!primaryContacts.isEmpty()) {
                effectiveAccountId = primaryContacts[0].AccountId;
            }
        }

        Date effectiveStart = (startDate != null) ? startDate : Date.newInstance(System.today().year() - 1, 1, 1);
        Date effectiveEnd   = (endDate != null) ? endDate   : Date.newInstance(System.today().year(), 12, 31);

        Datetime startDT = DateTime.newInstance(effectiveStart, Time.newInstance(0,0,0,0));
        Datetime endDTExclusive = DateTime.newInstance(effectiveEnd.addDays(1), Time.newInstance(0,0,0,0));

        List<SalesOrder__c> orders = new List<SalesOrder__c>();

        // SOQL injection fix: optional LWC filters bound via queryWithBinds (no string concat of values).
        Map<String, Object> soBinds = new Map<String, Object>{
            'effectiveAccountId' => effectiveAccountId,
            'startDT' => startDT,
            'endDTExclusive' => endDTExclusive
        };

        String directQuery =
            'SELECT Id, Status__c ' +
            'FROM SalesOrder__c ' +
            'WHERE CustomerAccount__c = :effectiveAccountId ' +
            'AND ProjectName__c != NULL ' +
            'AND CreatedDate >= :startDT ' +
            'AND CreatedDate < :endDTExclusive ' +
            'AND Status__c NOT IN (' +
            '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
            '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
            '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
            '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
            ')';

        if (String.isNotBlank(projectName)) {
            directQuery += ' AND ProjectName__c = :projectName';
            soBinds.put('projectName', projectName);
        }
        if (String.isNotBlank(unitName)) {
            directQuery += ' AND Unit_Name__c = :unitName';
            soBinds.put('unitName', unitName);
        }

        orders.addAll((List<SalesOrder__c>) Database.queryWithBinds(
            directQuery, soBinds, AccessLevel.SYSTEM_MODE
        ));

        String jointQuery =
            'SELECT Id, Status__c ' +
            'FROM SalesOrder__c ' +
            'WHERE Id IN (SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c = :effectiveAccountId) ' +
            'AND ProjectName__c != NULL ' +
            'AND CreatedDate >= :startDT ' +
            'AND CreatedDate < :endDTExclusive ' +
            'AND Status__c NOT IN (' +
            '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
            '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
            '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
            '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
            ')';

        if (String.isNotBlank(projectName)) jointQuery += ' AND ProjectName__c = :projectName';
        if (String.isNotBlank(unitName))    jointQuery += ' AND Unit_Name__c = :unitName';

        orders.addAll((List<SalesOrder__c>) Database.queryWithBinds(
            jointQuery, soBinds, AccessLevel.SYSTEM_MODE
        ));

        if (orders.isEmpty()) {
            return new Map<String, Decimal>{
                'totalAmount' => 0,              // Amount Billed (yellow)
                'totalPaidAmount' => 0,          // Collected (green)
                'outstandingAmount' => 0,        // Outstanding (red)
                'futureCollectionAmount' => 0    // Future (violet)
            };
        }

        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : orders) soIds.add(so.Id);

        //  Installments
        List<SalesOrderInstallments__c> installments = [
            SELECT Id,
                   SalesOrder__c,
                   InstallmentAmount__c,
                   PaymentStatus__c,
                   MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :soIds
        ];

        if (installments.isEmpty()) {
            return new Map<String, Decimal>{
                'totalAmount' => 0,
                'totalPaidAmount' => 0,
                'outstandingAmount' => 0,
                'futureCollectionAmount' => 0
            };
        }

        Date today = System.today();

        Decimal billedAmt = 0;
        Decimal futureAmt = 0;
        Set<Id> billedInstallmentIds = new Set<Id>();

        Set<Id> futureInstallmentIds = new Set<Id>();
        Map<Id, Decimal> installmentAmtById = new Map<Id, Decimal>();

        for (SalesOrderInstallments__c inst : installments) {
            Decimal instAmt = (inst.InstallmentAmount__c == null) ? 0 : inst.InstallmentAmount__c;

            // Null milestone date → treat as future (safe)
            if (inst.MilestoneDate__c == null) {
                futureAmt += instAmt;
                futureInstallmentIds.add(inst.Id);
                installmentAmtById.put(inst.Id, instAmt);
                continue;
            }

            if (inst.MilestoneDate__c <= today) {
                billedAmt += instAmt;
                billedInstallmentIds.add(inst.Id);
            } else {
                futureAmt += instAmt;
                futureInstallmentIds.add(inst.Id);
                installmentAmtById.put(inst.Id, instAmt);
            }
        }
        // NEW: If future installments have PAID/PARTIALLY PAID invoices, include their paid amount in billed
    if (!futureInstallmentIds.isEmpty()) {
        List<Invoice__c> invs = [
            SELECT Id, SalesOrderInstallment__c, InvoiceStatus__c, InvoiceAmount__c, TotalPaidAmount__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c IN :futureInstallmentIds
            AND InvoiceStatus__c IN ('Paid', 'Partially Paid')
        ];
    
        Map<Id, Decimal> paidByInstallment = new Map<Id, Decimal>();
    
        for (Invoice__c inv : invs) {
            if (inv.SalesOrderInstallment__c == null) continue;
    
            Decimal paid = (inv.TotalPaidAmount__c == null) ? 0 : inv.TotalPaidAmount__c;
            if (paid <= 0) continue;
    
            paidByInstallment.put(
                inv.SalesOrderInstallment__c,
                (paidByInstallment.containsKey(inv.SalesOrderInstallment__c) ? paidByInstallment.get(inv.SalesOrderInstallment__c) : 0) + paid
            );
        }
    
        for (Id instId : paidByInstallment.keySet()) {
            if (billedInstallmentIds.contains(instId)) continue;
    
            Decimal paid = paidByInstallment.get(instId);
    
            //  don't exceed installment amount
            if (installmentAmtById.containsKey(instId)) {
                paid = Math.min(paid, installmentAmtById.get(instId));
            }
    
            billedAmt += paid;
    
            // IMPORTANT: add this installment into billedInstallmentIds
            // so receipts query can also consider it (if you want receipts from this installment too)
            billedInstallmentIds.add(instId);
    
            futureAmt -= paid;
            if (futureAmt < 0) futureAmt = 0;
        }
    }


        // Receipts → collected (only cleared)
        Decimal collectedAmt = 0;
        if (!billedInstallmentIds.isEmpty()) {
            List<Receipt__c> receipts = [
                SELECT Id, TotalAmount__c, EBS_Clearing_Date__c,Status__c, SalesOrderInstallment__c
                FROM Receipt__c
                WHERE SalesOrderInstallment__c IN :billedInstallmentIds
            ];

            for (Receipt__c r : receipts) {
                if (r.TotalAmount__c == null) continue;

                // count only cleared as collected
                if (r.EBS_Clearing_Date__c != null || r.Status__c == 'Cleared') {
                    collectedAmt += r.TotalAmount__c;
                }
            }
        }

        Decimal outstandingAmt = billedAmt - collectedAmt;
        if (outstandingAmt < 0) outstandingAmt = 0;

        return new Map<String, Decimal>{
            'totalAmount' => billedAmt,              // Amount Billed (yellow)
            'totalPaidAmount' => collectedAmt,       // Collected (green)
            'outstandingAmount' => outstandingAmt,   // Outstanding (red)
            'futureCollectionAmount' => futureAmt    // Future (violet)
        };
    }
}