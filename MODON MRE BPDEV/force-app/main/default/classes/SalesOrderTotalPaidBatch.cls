global with sharing class SalesOrderTotalPaidBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private Set<Id> salesOrderIds;
    private String salesOrderQuery;
    private Boolean overwriteTotal; // if true => set to sum; if false => add to existing

    global Integer updatedCount = 0;
    global Integer failedCount = 0;

    // 1) Run by SalesOrder Ids (soToUpdate.keySet())
    global SalesOrderTotalPaidBatch(Set<Id> soIds) {
        this.salesOrderIds = (soIds == null) ? new Set<Id>() : soIds;
        this.overwriteTotal = false;
    }

    // 2) Run by a dynamic query (must return SalesOrder__c records and include Id)
    global SalesOrderTotalPaidBatch(String soqlQuery) {
        this.salesOrderQuery = soqlQuery;
        this.overwriteTotal = false;
    }

    // Optional: choose overwrite vs increment
    global SalesOrderTotalPaidBatch(Set<Id> soIds, Boolean overwriteTotal) {
        this.salesOrderIds = (soIds == null) ? new Set<Id>() : soIds;
        this.overwriteTotal = overwriteTotal == true;
    }

    global SalesOrderTotalPaidBatch(String soqlQuery, Boolean overwriteTotal) {
        this.salesOrderQuery = soqlQuery;
        this.overwriteTotal = overwriteTotal == true;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // If a dynamic query is provided, use it as-is.
        if (!String.isBlank(salesOrderQuery)) {
            return Database.getQueryLocator(salesOrderQuery);
        }

        // Else use Ids set
        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            // Return empty locator (safe no-op)
            return Database.getQueryLocator('SELECT Id FROM SalesOrder__c WHERE Id = null');
        }

        // Make sure Totalpaidamount__c is queried so we can increment safely.
        return Database.getQueryLocator([
            SELECT Id, Totalpaidamount__c
            FROM SalesOrder__c
            WHERE Id IN :salesOrderIds
        ]);
    }

    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        if (scope == null || scope.isEmpty()) return;

        Set<Id> soIdsInScope = new Set<Id>();
        for (SalesOrder__c so : scope) {
            if (so.Id != null) soIdsInScope.add(so.Id);
        }
        if (soIdsInScope.isEmpty()) return;

        // Aggregate allocations by SalesOrder
        Map<Id, Decimal> soIdToPaidSum = new Map<Id, Decimal>();

        for (AggregateResult ar : [
            SELECT
                Invoice__r.SalesOrderInstallment__r.SalesOrder__c soId,
                SUM(ApprovedReceiptAmount__c) paidSum
            FROM Allocation__c
            WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN :soIdsInScope
              AND Receipt__r.Status__c IN ('Cleared')
              AND Status__c = 'Applied'
              AND ApprovedReceiptAmount__c != null
            GROUP BY Invoice__r.SalesOrderInstallment__r.SalesOrder__c
        ]) {
            Id soId = (Id) ar.get('soId');
            Decimal paidSum = (Decimal) ar.get('paidSum');
            if (soId != null && paidSum != null) {
                soIdToPaidSum.put(soId, paidSum);
            }
        }

        List<SalesOrder__c> toUpdate = new List<SalesOrder__c>();

        for (SalesOrder__c so : scope) {
            Decimal addAmt = soIdToPaidSum.get(so.Id);
            if (addAmt == null) continue;

            Decimal current = (so.Totalpaidamount__c == null) ? 0 : so.Totalpaidamount__c;

            // If overwriteTotal=true => set to sum
            // else => increment like your current code
            Decimal newValue = overwriteTotal ? addAmt : (current + addAmt);

            // Only add to update if changed
            if (so.Totalpaidamount__c != newValue) {
                toUpdate.add(new SalesOrder__c(
                    Id = so.Id,
                    Totalpaidamount__c = newValue
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] srList = Database.update(toUpdate, false);
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) updatedCount++;
                else failedCount++;
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Optional: add logging / platform event / email here
        // System.debug('Updated: ' + updatedCount + ', Failed: ' + failedCount);
    }
}