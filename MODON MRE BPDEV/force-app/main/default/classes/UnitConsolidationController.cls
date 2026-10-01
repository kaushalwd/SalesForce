/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-29-2025
 * @last modified by  : Krishna Chaitanya
**/
public without sharing class UnitConsolidationController {

    @AuraEnabled
    public static String processConsolidationFinancials(Id serviceRequestId) {
        Savepoint sp;
        try {
            sp = Database.setSavepoint();

            List<Unit_Consolidation__c> unitConsList = [
                SELECT Id, Sales_Order__c, IsConsolidated__c, Fund_Transfer__c, Transfer_Amount__c
                FROM Unit_Consolidation__c
                WHERE Service_Request__c = :serviceRequestId
            ];

            if (unitConsList.isEmpty()) {
                return 'No Unit Consolidation records found';
            }

            Set<Id> consolidatedSOIds = new Set<Id>();
            Set<Id> fundTransferSOIds = new Set<Id>();

            for (Unit_Consolidation__c uc : unitConsList) {
                if (uc.IsConsolidated__c && uc.Sales_Order__c != null) {
                    consolidatedSOIds.add(uc.Sales_Order__c);
                }
                if (uc.Fund_Transfer__c && uc.Sales_Order__c != null) {
                    fundTransferSOIds.add(uc.Sales_Order__c);
                }
            }

            if (consolidatedSOIds.isEmpty()) {
                return 'No consolidated Sales Orders found';
            }

            Map<Id, Decimal> debitMemoMap = createConsolidatedDebitNotes(consolidatedSOIds);
            createCreditNotes(consolidatedSOIds, true);
            createCreditNotes(consolidatedSOIds, false);
            unapplyAllocations(consolidatedSOIds);
            createFundTransferReceiptsAndAllocate(serviceRequestId, fundTransferSOIds, debitMemoMap);
            cancelOldSalesOrderHierarchy(consolidatedSOIds);

            return 'Unit consolidation financials processed successfully';

        } catch (Exception e) {
            if (sp != null) Database.rollback(sp);
            throw new AuraHandledException('Error processing consolidation: ' + e.getMessage());
        }
    }
	@testVisible
    private static void cancelOldSalesOrderHierarchy(Set<Id> salesOrderIds) {
        List<SalesOrder__c> soToCancel = [
            SELECT Id,Unit__c FROM SalesOrder__c WHERE Id IN :salesOrderIds
        ];
        List<Unit__c> units= new List<Unit__c>();
       
        for (SalesOrder__c so : soToCancel) {
            so.Status__c = 'Unit Consolidation Cancelled - SR';
            Unit__c unitList = new Unit__c();
            unitList.id = so.Unit__c;
            unitList.Status__c = 'Available';
            units.add(unitList);
        }

        List<SalesOrderInstallments__c> soiToCancel = [
            SELECT Id FROM SalesOrderInstallments__c WHERE SalesOrder__c IN :salesOrderIds
        ];
        for (SalesOrderInstallments__c soi : soiToCancel) {
            soi.PaymentStatus__c = 'Cancelled';
        }

        List<Invoice__c> invToCancel = [
            SELECT Id FROM Invoice__c
            WHERE (Sales_Order__c IN :salesOrderIds OR SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds) And RecordTypeId != :getRecordTypeId('Invoice__c','Debit_Memo')
            AND IsCancelled__c = false
        ];
        for (Invoice__c inv : invToCancel) {
            inv.IsCancelled__c = true;
        }

        if (!soToCancel.isEmpty()) update soToCancel;
        if (!soiToCancel.isEmpty()) update soiToCancel;
        if (!invToCancel.isEmpty()) update invToCancel;
         if (!units.isEmpty()) update units;
    }

    private static void createCreditNotes(Set<Id> salesOrderIds, Boolean isSynced) {
        List<Invoice__c> invoices = [
            SELECT Id, InvoiceAmount__c, AppliedAmount__c, OICIntegrationStatus__c,
                   Sales_Order__c, SalesOrderInstallment__r.SalesOrder__c,
                   SalesOrderInstallment__r.PaymentStatus__c
            FROM Invoice__c
            WHERE (Sales_Order__c IN :salesOrderIds OR SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds)
            AND RecordType.DeveloperName = 'Tax_Invoice'
            AND IsCancelled__c = false
        ];

        List<CreditNote__c> creditNotes = new List<CreditNote__c>();

        for (Invoice__c inv : invoices) {
            Boolean isMatch = (isSynced && inv.OICIntegrationStatus__c == 'S') || (!isSynced && inv.OICIntegrationStatus__c != 'S');
            Boolean isPaidOrPartial = inv.SalesOrderInstallment__r.PaymentStatus__c == 'Paid' || inv.SalesOrderInstallment__r.PaymentStatus__c == 'Partially Paid';
            Decimal appliedAmount = inv.AppliedAmount__c != null ? inv.AppliedAmount__c : 0;

            if (isMatch && isPaidOrPartial && appliedAmount > 0) {
                Id targetSOId = inv.Sales_Order__c != null ? inv.Sales_Order__c : inv.SalesOrderInstallment__r.SalesOrder__c;
                creditNotes.add(new CreditNote__c(
                    Invoice__c = inv.Id,
                    Amount__c = appliedAmount,
                    Source__c = 'Property Sales Invoice',
                    Sales_Order__c = targetSOId,
                    Approval_Status__c = 'Approved',
                    ApprovalDate__c = Date.today(),
                    IntegrationStatus__c = 'Success'
                ));
            }
        }

        if (!creditNotes.isEmpty()) insert creditNotes;
    }

    private static void unapplyAllocations(Set<Id> salesOrderIds) {
        List<Allocation__c> allocations = [
            SELECT Id, AllocationAmount__c
            FROM Allocation__c
            WHERE (Invoice__r.Sales_Order__c IN :salesOrderIds OR Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds)
            AND AllocationAmount__c > 0
        ];
        for (Allocation__c alloc : allocations) {
            alloc.AllocationAmount__c = 0;
        }
        if (!allocations.isEmpty()) update allocations;
    }

    private static Map<Id, Decimal> createConsolidatedDebitNotes(Set<Id> consolidatedSOIds) {
        Map<Id, Decimal> debitMemoMap = new Map<Id, Decimal>();
        List<Invoice__c> debitMemosToInsert = new List<Invoice__c>();

        for (Id soId : consolidatedSOIds) {
            AggregateResult ar = [
                SELECT SUM(AppliedAmount__c) totalPaid
                FROM Invoice__c
                WHERE (Sales_Order__c = :soId OR SalesOrderInstallment__r.SalesOrder__c = :soId)
                AND RecordType.DeveloperName = 'Tax_Invoice'
                AND IsCancelled__c = false
                AND (SalesOrderInstallment__r.PaymentStatus__c = 'Paid' OR SalesOrderInstallment__r.PaymentStatus__c = 'Partially Paid')
            ];

            Decimal totalPaidAmount = (Decimal) ar.get('totalPaid');
            if (totalPaidAmount > 0) {
                SalesOrder__c so = [
                    SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id = :soId LIMIT 1
                ];

                debitMemosToInsert.add(new Invoice__c(
                    RecordTypeId = getRecordTypeId('Invoice__c', 'Debit_Memo'),
                    Sales_Order__c = so.Id,
                    Account__c = so.CustomerAccount__c,
                    InvoiceAmount__c = totalPaidAmount,
                    InvoiceDate__c = Date.today(),
                    OICIntegrationStatus__c = 'S'
                ));
                debitMemoMap.put(so.Id, totalPaidAmount);
            }
        }

        if (!debitMemosToInsert.isEmpty()) insert debitMemosToInsert;
        return debitMemoMap;
    }

    private static void createFundTransferReceiptsAndAllocate(Id serviceRequestId, Set<Id> fundTransferSOIds, Map<Id, Decimal> consolidatedDebitMemoMap) {
        List<Invoice__c> debitMemos = [
            SELECT Id, InvoiceAmount__c, InvoiceBalance__c
            FROM Invoice__c
            WHERE Sales_Order__c IN :consolidatedDebitMemoMap.keySet()
            AND RecordType.DeveloperName = 'Debit_Memo'
            AND IsCancelled__c = false
        ];

        Decimal totalAvailableDebit = 0;
        for (Invoice__c dm : debitMemos) {
            totalAvailableDebit += dm.InvoiceBalance__c != null ? dm.InvoiceBalance__c : dm.InvoiceAmount__c;
        }

        List<Unit_Consolidation__c> fundTransfers = [
            SELECT Id, Sales_Order__c, Transfer_Amount__c, Sales_Order__r.CustomerAccount__c
            FROM Unit_Consolidation__c
            WHERE Service_Request__c = :serviceRequestId
            AND Sales_Order__c IN :fundTransferSOIds
            AND Fund_Transfer__c = true
        ];

        Decimal totalPlannedTransfer = 0;
        for (Unit_Consolidation__c uc : fundTransfers) {
            if (uc.Transfer_Amount__c != null && uc.Transfer_Amount__c > 0) {
                totalPlannedTransfer += uc.Transfer_Amount__c;
            }
        }

        if (totalPlannedTransfer > totalAvailableDebit) {
            throw new AuraHandledException('Total Fund Transfer Amount exceeds available Debit Memo balance.');
        }

        List<Receipt__c> receiptsToInsert = new List<Receipt__c>();
        for (Unit_Consolidation__c uc : fundTransfers) {
            Decimal amount = uc.Transfer_Amount__c != null ? uc.Transfer_Amount__c : 0;
            if (amount > 0) {
                receiptsToInsert.add(
                    ReceiptService.createLogicalReceipt('', uc.Sales_Order__c, amount, uc.Sales_Order__r.CustomerAccount__c, 'Equity Transfer')
                );
            }
        }

        if (!receiptsToInsert.isEmpty()) insert receiptsToInsert;

        List<Allocation__c> allocationsToInsert = new List<Allocation__c>();
        for (Receipt__c receipt : receiptsToInsert) {
            List<Allocation__c> allocs = ReceiptAllocationService.createLogicalReceiptAllocations(
                receipt.Id,
                receipt.TotalAmount__c,
                receipt.SalesOrder__c
            );
            if (allocs.isEmpty()) {
                throw new AuraHandledException('Receipt could not be allocated to any Debit Memo.');
            }
            allocationsToInsert.addAll(allocs);
        }

        if (!allocationsToInsert.isEmpty()) insert allocationsToInsert;

    }
	@testVisible
    Private static Id getRecordTypeId(String sObjectName, String devName) {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(sObjectName);
        if (sObjType != null) {
            return sObjType.getDescribe().getRecordTypeInfosByDeveloperName().get(devName).getRecordTypeId();
        }
        return null;
    }
}