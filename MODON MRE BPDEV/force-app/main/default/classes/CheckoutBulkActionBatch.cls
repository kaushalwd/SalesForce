/**********************************************************************************************************************
* Name               : CheckoutBulkActionBatch
* Description        : Batch job to process bulk capture/void actions on Checkout_Payment__c records
* Usage              : Executed manually
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Rushi Patel                 10 Sep 2026     Initial draft
******************************************************************************************************************/
public class CheckoutBulkActionBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    // Track IDs of successfully captured payments so we can materialize their EOI/Receipt records later
    private Set<Id> capturedIds = new Set<Id>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Query all Authorized checkout payment records where a bulk action (Capture/Void) is specified
        return Database.getQueryLocator([
            SELECT Id, Payment_Id__c, Currency_Code__c, Amount__c, Bulk_Action__c
            FROM Checkout_Payment__c
            WHERE Status__c = 'Authorized'
              AND Bulk_Action__c IN ('Capture', 'Void')
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Checkout_Payment__c> scope) {
        // Iterate through each record in the current batch chunk
        for (Checkout_Payment__c cp : scope) {
            // Check the desired action and call the respective Checkout API service
            if (cp.Bulk_Action__c == 'Capture') {
                // Passing amount as null to capture the full authorized amount
                CheckoutPaymentLinkService.Result res = CheckoutPaymentLinkService.capturePayment(cp.Payment_Id__c, null, cp.Currency_Code__c);
                
                if (res != null && res.isSuccess) {
                    capturedIds.add(cp.Id);
                }
            } else if (cp.Bulk_Action__c == 'Void') {
                CheckoutPaymentLinkService.Result res = CheckoutPaymentLinkService.voidPayment(cp.Payment_Id__c);
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        // In a batch context, the trigger explicitly skips materialization (creating the EOI/Receipt records)
        // to avoid enqueueing limits. We must handle materialization in the finish() transaction just like the poller.
        if (!capturedIds.isEmpty()) {
            List<Checkout_Payment__c> toMaterialize = [
                SELECT Id, EOI_Creation_Payload__c, Payment_Id__c, Reference__c, Currency_Code__c
                FROM Checkout_Payment__c
                WHERE Id IN :capturedIds
                  AND Expression_of_Interest__c = null
            ];
            if (!toMaterialize.isEmpty()) {
                CheckoutEoiMaterializer.materialize(toMaterialize);
            }
        }
    }
}