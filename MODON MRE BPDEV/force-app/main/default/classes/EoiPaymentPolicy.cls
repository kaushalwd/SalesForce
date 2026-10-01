/**********************************************************************************************
 * Name           : EoiPaymentPolicy
 * Description     : Single source of truth for EOI payment state: which Checkout statuses mean the
 *                   money is ours to rely on, which end the payment with nothing, the EOI status
 *                   that records a held payment, and whether a channel charges on payment or only
 *                   authorizes. Channel-neutral on purpose - the Broker Portal and the EOI
 *                   microsite call these instead of keeping their own copies.
 * Usage           : EoiCheckoutPaymentController, CheckoutEoiMaterializer, CheckoutPaymentTrigger,
 *                   CheckoutMaterializeQueueable, CheckoutPaymentPoller.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.3        Prateek Bansal    21 Sep 2026    CLOSING_LAPSED_STATUSES: the lapses that close an EOI, recovery apart.
 * 1.2        Prateek Bansal    21 Sep 2026    Names Authorization Expired, so a lapsed hold can be recovered not closed.
 * 1.1        Prateek Bansal    12 Sep 2026    LAPSED_STATUSES recognises Authorization Expired, the new
 *                                             status for a hold that ran out. Without it an EOI raised
 *                                             on that hold would stay open with no money behind it.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
public without sharing class EoiPaymentPolicy {

    public static final String CHANNEL_SALESFORCE = 'Salesforce';
    public static final String CHANNEL_BROKER     = 'Broker';
    public static final String CHANNEL_MICROSITE  = 'Microsite';

    // The money is held or taken. Either raises the EOI; only Captured earns a receipt.
    public static final Set<String> PAID_STATUSES = new Set<String>{ 'Authorized', 'Captured' };

    // The payment ended with no money.
    // 'Authorization Expired' is the hold that lapsed on its own; 'Expired' is a link nobody opened.
    public static final Set<String> LAPSED_STATUSES =
        new Set<String>{ 'Expired', 'Authorization Expired', 'Voided', 'Declined' };

    /* The lapses that close the EOI. Authorization Expired is left out on purpose: that hold is
       retried for a couple of days, and if recovery fails the EOI still stays open for business to
       contact the customer. Every close path reads this, not LAPSED_STATUSES - the trigger only runs
       outside batch, so the poller's chain would otherwise cancel what recovery is trying to save. */
    public static final Set<String> CLOSING_LAPSED_STATUSES =
        new Set<String>{ 'Expired', 'Voided', 'Declined' };

    public static final String STATUS_CAPTURED = 'Captured';
    // The hold that ran out on its own. Lapsed, but recoverable for a while, so it is handled apart
    // from the other lapse statuses: those end the EOI, this one starts a recovery.
    public static final String STATUS_AUTHORIZATION_EXPIRED = 'Authorization Expired';
    public static final String STATUS_PAYMENT_AUTHORIZED = 'Payment Authorized';

    // Test seam: the label is org config, so a test that asserts both modes must set it itself.
    @TestVisible private static String captureChannelsOverride;

    /**
     * True when this channel charges the card outright rather than holding it. The label
     * EOI_Checkout_Capture_Mode lists, comma separated, the channels that still capture
     * immediately; a channel not in the list authorizes only, so setting the label to None puts
     * every channel on a hold. That is the switch: turning the hold on or back off is a label edit,
     * never a deploy, so rollback is immediate.
     */
    public static Boolean captureImmediately(String channel) {
        String raw = captureChannelsOverride != null ? captureChannelsOverride : System.Label.EOI_Checkout_Capture_Mode;
        if (String.isBlank(raw) || String.isBlank(channel)) return false;
        for (String entry : raw.split(',')) {
            if (entry.trim().equalsIgnoreCase(channel)) return true;
        }
        return false;
    }
}