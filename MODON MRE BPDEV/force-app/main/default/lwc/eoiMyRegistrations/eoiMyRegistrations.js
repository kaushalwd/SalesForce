/**
 * eoiMyRegistrations — returning-customer view: every payment this verified
 * customer has made on the site, with its registration status, plus a refund
 * request action. The request only flags the payment for the operations team;
 * money movement and record closure run through the Checkout refund pipeline
 * and the site sweeper. Composed by eoiIdentityChooser.
 * @author Aurelix
 *
 * v1.1  MEOI-04/05/06/10  8 Sep 2026
 *   - Refund is gated by Custom Label EOI_Site_Refund_Enabled. Shipping 'false'
 *     hides the control everywhere until the WhatsApp/Case work lands. The server
 *     is unchanged and stays authoritative; this only stops the ask being offered.
 *   - The "Refund requested" chip and the removal of the request link carry the state.
 *     A separate confirmation banner was added and then REMOVED at MODON's request on
 *     9 Sep - it promised a WhatsApp follow-up that does not exist yet, and the chip
 *     already says what happened.
 *   - The payment reference is no longer displayed; only the EOI number is. The
 *     reference remains in data-reference because it is what the refund call keys
 *     on - removing it from the DOM would break the action.
 *   - "Keep registration" reads as "Cancel" per MODON.
 *   Separator flags are computed here rather than in the template so removing the
 *   reference cannot leave a dangling middot when a card has no EOI number yet.
 * v1.2  MEOI-CANCEL  11 Sep 2026
 *   - "Cancel" on every row whose payment is still a hold (server flag canCancel). A modal
 *     asks first; "Yes, cancel registration" raises `cancelregistration` and the chooser
 *     calls the server, which voids the hold at Checkout (the console's Void) and closes the
 *     records. The row then reads Cancelled with the hold-released note.
 * v1.4  MEOI-CARD  13 Sep 2026
 *   - The EOI number is the card title (the typology name only until the EOI exists); the
 *     separate EOI-number line under the meta is gone.
 * v1.3  MEOI-STATUS  13 Sep 2026
 *   - Closed rows read exactly what the Checkout Payment Console shows (Dashboard_Status__c, via the
 *     server's displayStatus) and carry no note; the Refunded/Cancelled fallback notes are gone.
 */
import { LightningElement, api, track } from 'lwc';

/* MEOI-STATUS (13 Sep 2026, Mridul): a closed payment shows the same word as the Checkout
   Payment Console's status column (Checkout_Payment__c.Dashboard_Status__c - e.g. "Refunded" for a
   voided hold), and no explanatory line under it. The server sends displayStatus/displayNote;
   the only note added here is the one for a pending refund request. */
const CHIP_CLASS = {
    Registered: 'm-chip m-chip--ok',
    Paid: 'm-chip m-chip--ok',
    Processing: 'm-chip m-chip--proc',
    'Pending Payment': 'm-chip m-chip--proc',
    'Refund requested': 'm-chip m-chip--warn',
    Refunded: 'm-chip m-chip--mut',
    Cancelled: 'm-chip m-chip--mut',
    Voided: 'm-chip m-chip--mut',
    Expired: 'm-chip m-chip--mut',
    Declined: 'm-chip m-chip--mut'
};
const MUTED = new Set(['Refunded', 'Cancelled', 'Voided', 'Expired', 'Declined']);

const SUB_NOTE = {
    'Refund requested': 'Our team is processing this refund.'
};

export default class EoiMyRegistrations extends LightningElement {
    @api cards = [];
    /* MEOI-05/CFG. Supplied by eoiIdentityChooser from the runtime site config rather
       than imported as a label here, so a Setup edit reaches this component without
       republishing the sites. Defaults false: refund stays hidden if nothing sets it. */
    @api refundEnabled = false;
    @api isBusy = false;
    @api errorMessage = '';

    @track confirmingRef = null;
    /* MEOI-CANCEL: reference of the row whose cancel modal is open */
    @track cancellingRef = null;

    get viewCards() {
        return (this.cards || []).map((c) => {
            const bn = parseInt(c.bedrooms, 10);
            const qty = c.quantity || 1;
            const meta = [];
            if (!isNaN(bn)) {
                meta.push(`${bn} BR`);
            }
            meta.push(`${qty} unit${qty === 1 ? '' : 's'}`);
            const paidDate = this.fmtDate(c.paidAt);
            if (paidDate) {
                meta.push(`Paid ${paidDate}`);
            }
            /* MEOI-05a. With refund switched off the feature must be invisible, not
               half-visible. Previously the control was hidden but the server-side status
               still surfaced - a customer saw "Refund requested" and a message promising
               a WhatsApp follow-up, with no way to have asked for it and no follow-up
               coming. A request already on the record is presented as what it would be
               without that request: the payment is still captured, so "Registered".
               'Refunded' is deliberately NOT suppressed - money genuinely returned is a
               fact about the payment, not a pending request, and hiding it would
               misrepresent the account. */
            const hideRefundState =
                !this.refundEnabled && c.displayStatus === 'Refund requested';
            const status = hideRefundState ? 'Registered' : c.displayStatus;
            const note = hideRefundState ? '' : (c.displayNote || SUB_NOTE[c.displayStatus] || '');
            const showRefundLink = this.refundEnabled && !!c.canRequestRefund;
            const hasEoi = !!(c.eoiNumbers && c.eoiNumbers.length);

            const typologyName = c.unitTypology || 'Villa';
            return {
                reference: c.reference,
                name: typologyName,
                /* MEOI-CARD: the EOI number is the title once the EOI exists; before that, the typology */
                title: hasEoi ? c.eoiNumbers.join(' \u00B7 ') : typologyName,
                hasSub: showRefundLink || !!note,
                meta: meta.join(' · '),
                formattedAmount: this.fmt(c.amount),
                displayRef: this.shortRef(c.reference),
                eoiLabel: hasEoi ? c.eoiNumbers.join(' · ') : '',
                chipLabel: status,
                chipClass: CHIP_CLASS[status] || 'm-chip m-chip--proc',
                isRegistered: status === 'Registered',
                subNote: note,
                rowClass: MUTED.has(status) ? 'm-wrow m-wrow--muted' : 'm-wrow',
                canRequestRefund: showRefundLink,
                canCancel: !!c.canCancel,
                showEoiSep: false,
                showNoteSep: showRefundLink && !!note,
                confirming: this.confirmingRef === c.reference
            };
        });
    }
    get ledgerCap() {
        const n = (this.cards || []).length;
        return `Your registrations \u00B7 ${n} payment${n === 1 ? '' : 's'}`;
    }

    get hasCards() {
        return (this.cards || []).length > 0;
    }

    askRefund(event) {
        this.confirmingRef = event.currentTarget.dataset.reference;
    }

    // ---------- MEOI-CANCEL ----------
    get cancelling() {
        return !!this.cancellingRef;
    }
    get cancelCard() {
        return this.viewCards.find((c) => c.reference === this.cancellingRef) || null;
    }
    get cancelText() {
        const c = this.cancelCard;
        if (!c) {
            return '';
        }
        const what = c.eoiLabel || c.name;
        return `${what} will be cancelled and the AED ${c.formattedAmount} will be refunded.`;
    }
    askCancel(event) {
        this.confirmingRef = null;
        this.cancellingRef = event.currentTarget.dataset.reference;
    }
    keepRegistration() {
        if (!this.isBusy) {
            this.cancellingRef = null;
        }
    }
    confirmCancel() {
        const reference = this.cancellingRef;
        this.cancellingRef = null;
        this.dispatchEvent(new CustomEvent('cancelregistration', { detail: { reference } }));
    }

    cancelConfirm() {
        this.confirmingRef = null;
    }

    confirmRefund(event) {
        const reference = event.currentTarget.dataset.reference;
        this.confirmingRef = null;
        this.dispatchEvent(new CustomEvent('requestrefund', { detail: { reference } }));
    }

    registerAnother() {
        this.dispatchEvent(new CustomEvent('registeranother'));
    }

    fmt(amount) {
        try {
            return new Intl.NumberFormat('en-AE').format(amount || 0);
        } catch (e) {
            return String(amount || 0);
        }
    }

    fmtDate(value) {
        if (!value) {
            return '';
        }
        try {
            return new Date(value).toLocaleDateString('en-AE', {
                day: 'numeric', month: 'short', year: 'numeric'
            });
        } catch (e) {
            return '';
        }
    }

    shortRef(reference) {
        const r = reference || '';
        return r.length > 12 ? `${r.slice(0, 7)}…${r.slice(-3)}` : r;
    }
}