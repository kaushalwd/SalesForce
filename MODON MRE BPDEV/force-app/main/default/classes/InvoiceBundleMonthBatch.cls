public class InvoiceBundleMonthBatch implements Database.Batchable<SObject>, Database.Stateful,Schedulable {
  public void execute(SchedulableContext sc) {
        InvoiceBundleMonthBatch batchJob = new InvoiceBundleMonthBatch(null,null);
        Database.executeBatch(batchJob, 1);
  }
  public date dateValue;
  public InvoiceBundleMonthBatch(integer year, integer month){
      if(year <> null && month <> null){
        	dateValue = Date.newInstance(year, month, 1);
      }else{
            dateValue = Date.today();
      }
  }
  public Database.QueryLocator start(Database.BatchableContext bc) {
        // SOQL hardening: static SOQL (no dynamic string assembly).
        return Database.getQueryLocator([
            SELECT Id, User__c, On_Hold_Pending_Commission_Reason__c, On_Hold_Previous_Pending_Commission__c
            FROM Commission_POT__c
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
       CommissionLogicHandler.monthlyInvoiceBundle((List<Commission_POT__c>)scope,dateValue);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('InvoiceBundleMonthBatch completed.');
    }
}