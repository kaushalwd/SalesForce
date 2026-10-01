/**********************************************************************************************************************
* Name               : CommissionLineItemBatch                                                        
* Description        : This class is used to handle all the Commission Line Item (Both External & Internal) Creation Logic
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             05/10/2025      Initial Draft
**********************************************************************************************************************/
public class CommissionLineItemBatch implements Database.Batchable<SObject>, Database.Stateful,Schedulable  {
  public void execute(SchedulableContext sc) {
        CommissionLineItemBatch batchJob = new CommissionLineItemBatch();
        Database.executeBatch(batchJob, 1);
  }
  public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        Date startOfMonth = Date.newInstance(today.year(), today.month(), 1);
        Integer periodMonths = Integer.valueOf(1);
		Date endOfMonth = startOfMonth.addMonths(periodMonths).addDays(-1);
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};

        // SOQL injection fix: static locator with bind on cancel statuses (same filters as before).
        return Database.getQueryLocator([
            SELECT Id, Commission_Rules__c, Commission_Line_Type__c, Direct_Commission_Amount__c,
                   Commission_Amount__c, Equity__c, Indirect_Commission_Amount__c, Referral_Type__c,
                   Commission_Type__c, Payout_Equity__c, POT_Type__c
            FROM Commission_Line__c
            WHERE Commission_Line_Item_Is_Created__c = false
            AND HistoricalData__c = false
            AND (NOT (Sales_Order__r.Status__c IN :cancellStatus))
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) { 
       CommissionLogicHandler.createCommissionLineItem((List<Commission_Line__c>)scope);
    }

    public void finish(Database.BatchableContext bc) {
    }
}