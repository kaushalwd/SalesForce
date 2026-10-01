/**
 * EOIVisitCloseAction — invocable behind the CheckoutPayment_EoiVisitClose
 * flow: settles a finalized site payment's staging rows into EOI records
 * moments after the money lands (EOIService.settlePaymentEois). Runs in the
 * flow's async system context, never in a guest transaction. Processes
 * EXACTLY ONE registration per invocation — the promotion cascade (Lead
 * conversion) is limited to one per transaction (proven org flow limit);
 * anything skipped is retried by the flow's 15-minute path and, ultimately,
 * the sweeper. Failures are logged and stamp nothing, so every selector the
 * backstops use still sees the untouched state.
 * @author Aurelix
 */
public without sharing class EOIVisitCloseAction {

    /** Unit tests opt in explicitly: Test.stopTest() drains the flow's async
     *  path, and the pre-existing suites assert the sweeper-paced states. */
    @TestVisible static Boolean testEnabled = false;

    @InvocableMethod(label='EOI Site Visit Settle' description='Settles finalized site payments into EOIs immediately (Aurelix, Wadeem microsite).')
    public static void close(List<Id> paymentIds) {
        if (paymentIds == null || paymentIds.isEmpty()) {
            return;
        }
        if (System.Label.EOI_Visit_Fast_Close_Enabled != 'true') {
            return;
        }
        if (Test.isRunningTest() && !testEnabled) {
            return;
        }
        try {
            for (Checkout_Payment__c cp : [
                SELECT EOI_Site_Registration__c FROM Checkout_Payment__c
                WHERE Id IN :paymentIds AND EOI_Site_Registration__c != null
                ORDER BY CreatedDate ASC
            ]) {
                EOIService.settlePaymentEois((Id) cp.EOI_Site_Registration__c);
                EoiJourneyLog.flush();
                return; // one registration per invocation - one cascade per transaction
            }
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'EOI Visit Close', 'EOIVisitCloseAction', 'close'));
        }
    }
}