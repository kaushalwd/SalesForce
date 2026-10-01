/**********************************************************************************************************************
* Name               : UpdateAccountTotalSoldWithJOSBatch                                                        
* Description        : This class is used to handle all the SalesOrderInstallment trigger instances
* Usage              : Called from SalesOrderInstallmentTrigger
* Created By         : AMGS                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.1 			Srikrishna.chaitanya.com		 27 Nov 2025	 	Total Amount Calc on Salesorder
******************************************************************************************************************/
public class UpdateAccountTotalSoldWithJOSBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    // Running totals across the whole batch
    private Map<Id, Decimal> accountTotals = new Map<Id, Decimal>();
    //  statuses to Include
    private static final Set<String> STATUSES = new Set<String>{'Completed'};
        public Database.QueryLocator start(Database.BatchableContext bc) {

            return Database.getQueryLocator([SELECT Id, CustomerAccount__c,Unit__r.Source_Entity__c, TotalAmount__c,Source_Entity__c FROM SalesOrder__c WHERE CustomerAccount__c != NULL
                                             AND Status__c IN : STATUSES AND Unit__r.Source_Entity__c != 'Modon - Egypt' ]);
        }
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
         if (Label.Account_JOS_Batch != 'true') {
            System.debug('SO Collections recalculation skipped (Label = false)');
            return;
         }
        List<SalesOrder__c> sos = (List<SalesOrder__c>)scope;
        system.debug('sos======='+ sos);
        //  Collect SalesOrder Ids
        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : sos) {
            soIds.add(so.Id);
        }
        if (soIds.isEmpty()) return;
        // JointOwner__c fields assumed: SalesOrder__c, Account__c, Ownership_Percentage__c (0–100)
        Map<Id, List<JointOwner__c>> bySO = new Map<Id, List<JointOwner__c>>();
        for (JointOwner__c jo : [
            SELECT Id, SalesOrder__c, JointOwnerAccount__c,JointOwnerAccount__r.Name, OwnershipPercentage__c FROM JointOwner__c WHERE SalesOrder__c IN :soIds]) {
                if (!bySO.containsKey(jo.SalesOrder__c)) bySO.put(jo.SalesOrder__c, new List<JointOwner__c>());
                bySO.get(jo.SalesOrder__c).add(jo);
            }
        // Allocate amounts per SalesOrder
        for (SalesOrder__c so : sos) {
            Decimal soTotal = (so.TotalAmount__c == null) ? 0 : so.TotalAmount__c;
            system.debug('soTotal================'+ soTotal);
            if (soTotal == 0) continue; // nothing to allocate
            Id primaryAcc = so.CustomerAccount__c;
            List<JointOwner__c> jos = bySO.get(so.Id);
            if (jos == null || jos.isEmpty()) {
                // No JO => 100% to primary
                addAmount(primaryAcc, soTotal);
                continue;
            }
            // Sum JO % per Account (handles duplicates to same Account)
            Map<Id, Decimal> joPctByAccount = new Map<Id, Decimal>();
            Decimal totalPct = 0;
            for (JointOwner__c jo : jos) {
                if (jo.JointOwnerAccount__c == null) continue;
                Decimal pct = (jo.OwnershipPercentage__c == null) ? 0 : jo.OwnershipPercentage__c;
                if (pct <= 0) continue;
                joPctByAccount.put(jo.JointOwnerAccount__c,(joPctByAccount.containsKey(jo.JointOwnerAccount__c) ? joPctByAccount.get(jo.JointOwnerAccount__c) : 0) + pct);
                totalPct += pct;
            }
            // If no valid pct entries, treat as no JOs
            if (joPctByAccount.isEmpty()) {
                addAmount(primaryAcc, soTotal);
                continue;
            }
            // Cap/normalize > 100% to avoid over-allocating
            Decimal effectiveTotalPct = totalPct;
            if (effectiveTotalPct <= 0) {
                // Defensive: zero or negative total => 100% primary
                addAmount(primaryAcc, soTotal);
                continue;
            }
            //  Allocate to JO accounts, proportionally if > 100%
            Boolean over100 = (effectiveTotalPct > 100);
            for (Id accId : joPctByAccount.keySet()) {
                Decimal pct = joPctByAccount.get(accId);
                Decimal usePct = over100 ? (pct / effectiveTotalPct) * 100 : pct; // normalize down if >100
                Decimal portion = soTotal * (usePct / 100);
                addAmount(accId, portion);
            }
            //  If total % < 100 and primary not included above, give remainder to primary
            if (effectiveTotalPct < 100) {
                Decimal remainderPct = 100 - effectiveTotalPct;
                if (remainderPct > 0) {
                    // Only add to primary if the primary wasn't already allocated via JO records
                    if (!joPctByAccount.containsKey(primaryAcc)) {
                        addAmount(primaryAcc, soTotal * (remainderPct / 100));
                    } else {
                        
                        // Do nothing;
                    }
                }
            }
            
        }
    }
    private void addAmount(Id accountId, Decimal amt) {
        if (accountId == null || amt == null) return;
        accountTotals.put(accountId, (accountTotals.containsKey(accountId) ? accountTotals.get(accountId) : 0) + amt.setScale(2));
    }
    public void finish(Database.BatchableContext bc) {
        if (accountTotals.isEmpty()) return;
        // Build updates
        List<Account> updates = new List<Account>();
        system.debug('accountTotals==========='+ accountTotals);
        for (Id accId : accountTotals.keySet()) {
            updates.add(new Account(Id = accId,Total_Sold_Value__c = accountTotals.get(accId)));
        }
        // Partial success, collect errors in debug
        Database.SaveResult[] sr = Database.update(updates, false);
        for (Integer i = 0; i < sr.size(); i++) {
            if (!sr[i].isSuccess()) {
                for (Database.Error e : sr[i].getErrors()) {
                    System.debug('Account update failed: ' + updates[i].Id + ' | ' + e.getMessage());
                }
            }
        }
    }
    public void execute(SchedulableContext SC){
        
        Database.executeBatch(new UpdateAccountTotalSoldWithJOSBatch(),1);
    }
}