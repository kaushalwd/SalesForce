/**********************************************************************************************
 * Name           : CheckoutReturnController
 * Description     : Landing page after the Checkout Hosted Payments Page redirect (staff Pay-now).
 *                   Confirms the payment on the spot (creates the EOI immediately via
 *                   EoiCheckoutPaymentController.confirmPayment) and shows the outcome with a link
 *                   to the created EOI. Served as a Visualforce page so the return query params
 *                   survive (internal Lightning strips them off standard pages).
 * Usage           : CheckoutReturn Visualforce page.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.1        Prateek Bansal    10 Sep 2026    Success is now the EOI existing, not the payment being
 *                                             captured: a held payment creates the EOI too, and
 *                                             gating on isCaptured left those customers on the
 *                                             "being created shortly" message forever.
 * 1.0        Prateek Bansal    05 Jul 2026    Initial version.
 **********************************************************************************************/
public with sharing class CheckoutReturnController {

    public Boolean isSuccess { get; private set; }
    public Boolean isPending { get; private set; }
    public Boolean isFailed  { get; private set; }
    public String headline   { get; private set; }
    public String detail     { get; private set; }
    public String eoiName    { get; private set; }
    public String eoiUrl     { get; private set; }
    public String homeUrl    { get; private set; }

    public CheckoutReturnController() {
        isSuccess = false;
        isPending = false;
        isFailed = false;
        homeUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/page/home';
    }

    // Runs on page load (apex:page action). confirmPayment does callout-then-DML internally.
    public PageReference process() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        String result = params.get('paymentResult');
        String reference = params.get('ref');

        if (result == 'cancelled') {
            isFailed = true;
            headline = 'Payment cancelled';
            detail = 'The payment was cancelled and no EOI was created. You can start again from the EOI wizard.';
            return null;
        }
        if (result == 'failed') {
            isFailed = true;
            headline = 'Payment not completed';
            detail = 'The payment did not go through and no EOI was created. Please try again.';
            return null;
        }
        if (String.isBlank(reference)) {
            isPending = true;
            headline = 'Payment received';
            detail = 'Your EOI will be created shortly.';
            return null;
        }

        EoiCheckoutPaymentController.ConfirmResult cr = EoiCheckoutPaymentController.confirmPayment(reference);
        // The EOI existing is what success means. A held payment creates it just as a captured one
        // does; only the receipt waits for capture, so the wording differs but the outcome does not.
        if (cr != null && cr.eoiId != null) {
            isSuccess = true;
            eoiUrl = URL.getOrgDomainUrl().toExternalForm() + '/' + cr.eoiId;
            List<Expressionofinterest__c> eois = [SELECT Name FROM Expressionofinterest__c WHERE Id = :cr.eoiId LIMIT 1];
            eoiName = eois.isEmpty() ? String.valueOf(cr.eoiId) : eois[0].Name;
            headline = 'Payment received';
            detail = cr.isCaptured
                ? 'Your Expression of Interest and receipt have been created.'
                : 'Your Expression of Interest has been created. The amount is held on your card and will be collected once your application is processed.';
        } else {
            // Confirmed slightly later, or still processing - the background poller will finish it.
            isPending = true;
            headline = 'Payment received';
            detail = 'Your EOI is being created and will appear shortly.';
        }
        return null;
    }
}