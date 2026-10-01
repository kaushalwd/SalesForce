public class InvoiceLineBatch implements Database.Batchable<SObject>, Database.Stateful,Schedulable {
    public String Month;
    public void execute(SchedulableContext sc) {
        InvoiceLineBatch batchJob = new InvoiceLineBatch(null);
        Database.executeBatch(batchJob, 1);
    }
    public InvoiceLineBatch(String Month){
        this.Month = Month;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
      if(Month == null || Month ==''){
        	Month = CommissionLogicHandler.getMonthNameFromDate(Date.today());
        }
        // SOQL hardening: static SOQL with :Month bind (no dynamic string assembly).
        return Database.getQueryLocator([
            SELECT Id, Commission_Line__c, Commission_Line__r.Sales_Order__c, Commission_Type__c,
                   Commission_Line__r.Commission_POT__c, Commission_Line__r.Current_Commission_Payout_Now__c,
                   Commission_Line__r.Total_Commission_Amount_Paid__c, Commission_Line__r.Total_Commission_Amount_Pending__c,
                   Commission_Line__r.Broker_Agency__c, Commission_Line__r.Broker_Agent__c,
                   Commission_Payout_Amount__c, Commission_Line__r.Commission_Amount__c,
                   Commission_Line__r.Team_Commission_Amount__c
            FROM Commission_Line_Item__c
            WHERE Commission_Month__c = :Month
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
       CommissionLogicHandler.invoiceLineCreation((List<Commission_Line_Item__c>)scope,Month);
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('InvoiceBundleMonthBatch completed.');
    }
}