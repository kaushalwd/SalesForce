/**********************************************************************************************************************
* Name               : CommissionLineItemPaymentBatch                                                        
* Description        : This class is used to handle all the Payment Calculation Logic (Both External & Internal) from Commission Line
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             05/10/2025      Initial Draft
* 2.0           Dselvam                             20/04/2026      Fixed SOQL Query issue
**********************************************************************************************************************/
public class CommissionLineItemPaymentBatch implements Database.Batchable<SObject>, Database.Stateful,Schedulable {
  public String queryStr; // retained for API compatibility; not executed as SOQL
  public void execute(SchedulableContext sc) {
        CommissionLineItemPaymentBatch batchJob = new CommissionLineItemPaymentBatch(null);
        Database.executeBatch(batchJob, 1);
  }
  public CommissionLineItemPaymentBatch(String q){
        // SOQL injection fix: ignore caller-supplied SOQL; always use fixed server query below.
        this.queryStr = q; 
  }
  public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};
        // Fixed SELECT/WHERE only (binds cancellStatus); do not run queryStr.
        return Database.getQueryLocator([
            SELECT Id, Commission_Payout_Percent__c, Direct_Commission_Amount__c, Payout_Based_On__c,
                   Equity_Payout_Percent__c, Sales_Order_Equity__c, Indirect_Commission_Amount__c,
                   Installment_No__c, Last_Paid_Installment_Number__c, Commission_Type__c,
                   Commission_Line__r.Total_Unit_Price__c, Sub_Type__c, Total_Commission_Amount__c,
                   Commission_Line__r.External_Total_Commission_Amount__c,
                   Commission_Line__r.Down_Payment_Status__c, Commission_Line__r.Is_SPA_Signed_By_Modon__c,
                   Commission_Line__r.ADM_Fee_Status__c, Commission_Line__r.Is_PDC_Collected__c,
                   Commission_Line__r.Compliance_Status__c
            FROM Commission_Line_Item__c
            WHERE Commission_Payout_Amount__c = 0
            AND Commission_Line__r.HistoricalData__c = false
            AND (NOT (Commission_Line__r.Sales_Order_Status__c IN :cancellStatus))
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
      CommissionLogicHandler.cliPayoutAmountCalculation((List<Commission_Line_Item__c>)scope,false);
    }

    public void finish(Database.BatchableContext bc) {
    }
}