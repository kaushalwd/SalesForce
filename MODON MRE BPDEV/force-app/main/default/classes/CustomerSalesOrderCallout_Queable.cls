public class CustomerSalesOrderCallout_Queable implements Queueable, Database.AllowsCallouts {
    private set<string> soIds;

    public CustomerSalesOrderCallout_Queable(set<string> salesOrderIds) {
        this.soIds = salesOrderIds;
    }

    public void execute(QueueableContext context) {

        // First make account callout   
        set<string> accIds = new set<string>();
        list<SalesOrder__c> soListCurrent = [Select Id, CustomerAccount__c from SalesOrder__c where Id in: soIds];
        if(soListCurrent <> null && !soListCurrent.isEmpty()){
            for(SalesOrder__c so: soListCurrent){
                accIds.add(so.CustomerAccount__c);
            }
        }

        if(!accIds.isEmpty()){
            OIC_ManageSalesforceDataController.createAccount(accIds);
            if(!Test.isRunningTest())
            // Then Chain the next job for Salesorder callout
            System.enqueueJob(new SalesOrderCallout_Queable(soIds));
        }
    }
}