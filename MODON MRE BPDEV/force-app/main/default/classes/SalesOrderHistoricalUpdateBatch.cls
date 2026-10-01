public class SalesOrderHistoricalUpdateBatch implements Database.Batchable<sObject>,Database.Stateful {
    public String queryString;
    public SalesOrderHistoricalUpdateBatch(String queryString){
        this.queryString = queryString;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if(String.isNotBlank(queryString)){
            return Database.getQueryLocator(queryString);
        }
        if(Test.isRunningTest()){
            return Database.getQueryLocator([SELECT Id FROM SalesOrder__c LIMIT 1]);
        }
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};
        return Database.getQueryLocator([
            SELECT Id 
            FROM SalesOrder__c 
            WHERE (NOT (Status__c IN :cancellStatus)) 
            AND Resale__c = false 
            AND Source_Entity__c != 'Modon - Egypt'
        ]);
    }
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        for(SalesOrder__c so:(List<SalesOrder__c>) scope){
           SalesOrderHistoricalUpdateHelper.checkADMStatus(new Set<Id>{so.Id});
           SalesOrderHistoricalUpdateHelper.checkDownPaymentStatus(new Set<Id>{so.Id});
           SalesOrderHistoricalUpdateHelper.checkSPAStatus(new Set<Id>{so.Id});
           SalesOrderHistoricalUpdateHelper.updatePDCStatus(new Set<Id>{so.Id});
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('SalesOrderHistoricalUpdateBatch completed.');
    }
}