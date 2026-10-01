public class SalesOrderCallout_Queable implements Queueable, Database.AllowsCallouts {
    private set<string> soIds;

    public SalesOrderCallout_Queable(set<string> salesOrderIds) {
        this.soIds = salesOrderIds;
    }

    public void execute(QueueableContext context) {
        // Sales Order Callout  
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(soIds);


    }
}