/**********************************************************************************************
 * Name           : CheckoutPaymentActions
 * Description     : Flow entry point (@InvocableMethod) to capture, void, or refund a Checkout.com
 *                   payment. Separate class because Apex allows only one @InvocableMethod per class.
 *                   Delegates to CheckoutPaymentLinkService.capture/void/refundPayment.
 * Usage           : Flow / Process Builder.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
public with sharing class CheckoutPaymentActions {

    public class ActionRequest {
        @InvocableVariable(label='Action (Capture/Void/Refund)' required=true) public String action;
        @InvocableVariable(label='Payment Id (pay_...)' required=true) public String paymentId;
        @InvocableVariable(label='Amount') public Decimal amount;
        @InvocableVariable(label='Currency Code (ISO)') public String currencyCode;
    }

    public class ActionResult {
        @InvocableVariable(label='Success') public Boolean isSuccess;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(label='Manage Checkout Payment' description='Capture, void, or refund a Checkout.com payment.' category='Checkout')
    public static List<ActionResult> manage(List<ActionRequest> requests) {
        List<ActionResult> results = new List<ActionResult>();
        for (ActionRequest r : requests) {
            String a = r.action != null ? r.action.toLowerCase() : '';
            CheckoutPaymentLinkService.Result res;
            if (a == 'capture')      res = CheckoutPaymentLinkService.capturePayment(r.paymentId, r.amount, r.currencyCode);
            else if (a == 'void')    res = CheckoutPaymentLinkService.voidPayment(r.paymentId);
            else if (a == 'refund')  res = CheckoutPaymentLinkService.refundPayment(r.paymentId, r.amount, r.currencyCode);
            else { res = new CheckoutPaymentLinkService.Result(); res.isSuccess = false; res.message = 'Unknown action: ' + r.action; }

            ActionResult ar = new ActionResult();
            ar.isSuccess = res.isSuccess;
            ar.message = res.message;
            results.add(ar);
        }
        return results;
    }
}