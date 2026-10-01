public class UnitCancellationReleaseAutomator implements BusinessProcessAutomation {

    public void executeAutomation(BusinessProcessAutomationInput input) {

        Set<Id> businessProcessIds = new Set<Id>();

        for (Business_Process_Step__c step : input.steps) {

            switch on step.Name {

                when 'CCO Approval' {
                    if (step.Status__c == 'Completed' && step.Business_Process__c != null) {
                        businessProcessIds.add(step.Business_Process__c);
                    }
                }
            }
        }

        if (!businessProcessIds.isEmpty()) {
            releaseUnitsAndSalesOrders(businessProcessIds);
        }
    }

    // Cancels the Sales Order and releases the Unit back to Draft for every Business
    // Process whose CCO Approval step just completed, using the same
    // CancellationSharedServices.SalesOrderCancellationService logic BPCancellationExecutor
    // relies on.
    private void releaseUnitsAndSalesOrders(Set<Id> businessProcessIds) {

        CancellationSharedServices.SalesOrderCancellationService soSvc =
            new CancellationSharedServices.SalesOrderCancellationService();

        for (Business_Process__c bp : [
            SELECT Id, Sales_Order__c, Sales_Order__r.Unit__c, Cancellation_Type__c
            FROM Business_Process__c
            WHERE Id IN :businessProcessIds
        ]) {
            if (bp.Sales_Order__c != null) {
                soSvc.cancel(bp.Sales_Order__c, bp.Sales_Order__r.Unit__c, bp.Cancellation_Type__c);
            }
        }
    }
}