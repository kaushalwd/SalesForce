/**
 * eoiReviewSubmit — per-type payment checklist. Each selected residence type is a
 * separate card payment: unpaid lines carry their own Pay button, paid lines show
 * the payment reference. The journey is pay-first: a type's registration rows are
 * written only after its payment captures.
 * @author Aurelix
 */
import { LightningElement, api, track } from 'lwc';
import TERMS_URL from '@salesforce/resourceUrl/EOI_Terms';

export default class EoiReviewSubmit extends LightningElement {
    @api lines = [];
    @api paid = {};        // rangeId -> PaymentLineState from the server
    @api isBusy = false;
    @api errorMessage = '';
    /* MEOI-TC (10 Sep). Terms & Conditions live in the EOI_Terms static resource (a plain
       .txt, one paragraph per blank line) so MODON can replace the text without a deploy of
       this component. Acceptance is held by the parent for the session and gates every Pay
       button; the checkbox inside the modal is what turns it on. */
    /* MEOI-TC2 (11 Sep). The checkbox is on the page and the modal is read-only: a customer
       may tick without opening the text. `termsaccepted` now carries { accepted } so an
       untick reaches the chooser too (Pay is disabled again). */
    @api termsAccepted = false;
    @track termsOpen = false;
    @track termsLoading = false;
    @track termsParas = [];

    get payDisabled() {
        return this.isBusy || !this.termsAccepted;
    }
    openTerms() {
        this.termsOpen = true;
        if (!this.termsParas.length) {
            this.loadTerms();
        }
    }
    closeTerms() {
        this.termsOpen = false;
    }
    handleTermsToggle(event) {
        this.dispatchEvent(new CustomEvent('termsaccepted', { detail: { accepted: !!event.target.checked } }));
    }
    acceptTerms() {
        if (!this.termsAccepted) {
            return;
        }
        this.termsOpen = false;
        this.dispatchEvent(new CustomEvent('termsaccepted'));
    }
    loadTerms() {
        this.termsLoading = true;
        fetch(TERMS_URL, { cache: 'no-store' })
            .then((r) => (r.ok ? r.text() : Promise.reject(new Error(String(r.status)))))
            .then((text) => {
                const paras = String(text || '').replace(/\r/g, '').split(/\n\s*\n/)
                    .map((t) => t.trim()).filter(Boolean);
                this.termsParas = paras.map((t, i) => ({ key: `p${i}`, text: t }));
            })
            .catch(() => {
                this.termsParas = [{ key: 'p0', text: 'The Terms & Conditions could not be loaded right now. Please try again in a moment.' }];
            })
            .finally(() => {
                this.termsLoading = false;
            });
    }

    get viewLines() {
        const paidMap = this.paid || {};
        return (this.lines || []).map((l) => {
            // MEOI-A10b: per-unit lines are keyed rangeId#n - the paid map uses the same key
            const p = paidMap[l.lineKey || l.rangeId];
            const qty = (p && p.quantity) || l.quantity || 1;
            const unit = p && p.unitAmount != null ? p.unitAmount
                : (l.quantity ? (l.lineTotal || 0) / l.quantity : 0);
            const amount = p && p.amount != null ? p.amount : l.lineTotal || 0;
            // MEOI-TILE: the card is titled by bedrooms only, like the residence tile
            const meta = [];
            const brTitle = l.bedrooms || l.unitTypology || (p && p.unitTypology) || 'Villa';
            // MEOI-PAY2: no quantity-times-price here - the amount row says it once
            return {
                rangeId: l.rangeId,
                lineKey: l.lineKey || l.rangeId,
                name: brTitle,
                meta: meta.join(' · '),
                formattedAmount: this.fmt(amount),
                unitsLabel: `${qty} unit${qty === 1 ? '' : 's'}`,
                paid: !!p,
                notPaid: !p,
                displayRef: p ? this.shortRef(p.reference) : '',
                eoiLabel: (p && p.eoiNumbers && p.eoiNumbers.length) ? p.eoiNumbers.join(' · ') : '',
                lineClass: p ? 'm-card m-card--settled' : 'm-card',
                headClass: p ? 'm-card__head m-card__head--paid' : 'm-card__head m-card__head--open',
                chipClass: p ? 'm-chip m-chip--ok' : 'm-chip m-chip--open',
                chipLabel: p ? 'Paid' : 'Unpaid'
            };
        });
    }

    keyOf(l) {
        return l.lineKey || l.rangeId;
    }
    get paidCount() {
        return (this.lines || []).filter((l) => (this.paid || {})[this.keyOf(l)]).length;
    }
    get totalCount() {
        return (this.lines || []).length;
    }
    get unpaidCount() {
        return this.totalCount - this.paidCount;
    }
    get receivedAmount() {
        return (this.lines || []).reduce((sum, l) => {
            const p = (this.paid || {})[this.keyOf(l)];
            return sum + (p && p.amount != null ? Number(p.amount) : 0);
        }, 0);
    }
    /* what is still to pay: unpaid lines only */
    get unpaidAmount() {
        return (this.lines || []).reduce((sum, l) => {
            const p = (this.paid || {})[this.keyOf(l)];
            return sum + (p ? 0 : (l.lineTotal || 0));
        }, 0);
    }
    /* MEOI-A10b. Paid units of this visit are back on the list, so the header counts only
       what is left: "1 payment remaining · AED 10,000 to pay" while a Paid card sits above. */
    get progressLabel() {
        const n = this.unpaidCount;
        return `${n} payment${n === 1 ? '' : 's'} remaining`;
    }
    get amountLabel() {
        return `AED ${this.fmt(this.unpaidAmount)} to pay`;
    }

    /* MEOI-PAY2. Lines are addressed by lineKey, which equals rangeId until per-unit
       payments split one typology into several lines (then rangeId#n). The parent maps
       the key back to what the server needs. */
    confirmLineKey = null;

    lineByKey(key) {
        return this.viewLines.find((v) => v.lineKey === key) || null;
    }
    get confirmLine() {
        return this.confirmLineKey ? this.lineByKey(this.confirmLineKey) : null;
    }

    payLine(event) {
        const key = event.currentTarget.dataset.lineKey;
        const v = this.lineByKey(key);
        this.dispatchEvent(new CustomEvent('payline', {
            detail: { lineKey: key, rangeId: v ? v.rangeId : key }
        }));
    }

    askRemove(event) {
        if (this.isBusy) {
            return;
        }
        this.confirmLineKey = event.currentTarget.dataset.lineKey;
    }
    cancelRemove() {
        this.confirmLineKey = null;
    }
    proceedRemove() {
        const key = this.confirmLineKey;
        const v = this.lineByKey(key);
        this.confirmLineKey = null;
        if (!key) {
            return;
        }
        this.dispatchEvent(new CustomEvent('removeline', {
            detail: { lineKey: key, rangeId: v ? v.rangeId : key }
        }));
    }

    goBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    fmt(amount) {
        try {
            return new Intl.NumberFormat('en-AE').format(amount || 0);
        } catch (e) {
            return String(amount || 0);
        }
    }

    shortRef(reference) {
        const r = reference || '';
        return r.length > 12 ? `${r.slice(0, 7)}…${r.slice(-3)}` : r;
    }
}