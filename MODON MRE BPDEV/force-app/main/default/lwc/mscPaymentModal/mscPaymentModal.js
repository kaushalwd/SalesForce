/**
 * One payment, on a surface of its own.
 *
 * Version  Author      Date         Detail
 * 1.5      Aurelix Dev 30 Sep 2026  With-Finance and allocated amounts in the text colour, no blue or green (CSS only).
 * 1.4      Aurelix Dev 29 Sep 2026  A booking fee paid by payment link (row.payByLink) says so, not the terminal.
 * 1.3      Aurelix Dev 21 Aug 2026  MSC-102. "Already paid" reads "Allocated"; paidWord retires.
 * 1.2      Aurelix Dev 21 Aug 2026  MSC-099. The state comes off the head.
 * 1.1      Aurelix Dev 21 Aug 2026  MSC-099. A deeper scrim (0.93).
 * 1.0      Aurelix Dev 21 Aug 2026  MSC-099. The ledger row's expanded panel becomes a modal.
 *
 * Mount at page level, never inside a card.
 *   in    open, row (one PaymentBucketDTO), bookedUnits, busy, proofResult
 *   out   close, and the six c/mscPaymentBlock events re-raised
 * Money facts come from c/mscPaymentFacts, the same functions the ledger row reads.
 */
import { LightningElement, api } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import { stillDueOf, liveInstrumentsOf, isOverdue } from "c/mscPaymentFacts";

/* must match the exit durations in the CSS (.layer--closing) */
const EXIT_MS = 200;

export default class MscPaymentModal extends LightningElement {
  /** The one payment this modal is about. */
  @api row;
  /* `settlement` retired with the head state */
  /** ConsoleState.bookedUnits, for the booking reference. */
  @api bookedUnits = [];
  /** The page is talking to the server. */
  @api busy = false;
  /** The page's answer to the last Create Payment. */
  @api proofResult;

  /** Open lags closed by EXIT_MS so the exit can animate. */
  _open = false;
  mounted = false;
  closing = false;
  _exitTimer = null;

  @api
  get open() {
    return this._open;
  }
  set open(value) {
    const next = !!value;
    if (next === this._open) {
      return;
    }
    this._open = next;
    if (next) {
      this.clearExit();
      this.closing = false;
      this._focusedOnOpen = false;
      /* MSC-201: a reopen must start clean, even the one that lands inside the 200ms exit and
         reuses the instance that is still on screen */
      this._resetOnOpen = true;
      this.mounted = true;
      return;
    }
    if (!this.mounted) {
      return;
    }
    this.closing = true;
    this.restoreFocus();
    this._exitTimer = setTimeout(() => {
      this._exitTimer = null;
      this.closing = false;
      this.mounted = false;
    }, EXIT_MS);
  }

  labels = LABELS;
  /** MSC-201: set on every open; cleared once the form has been put back. */
  _resetOnOpen = false;
  _focusedOnOpen = false;
  _previousFocus = null;

  /* the payment, as it is read */

  get hasRow() {
    return !!this.row;
  }

  /** The payment's name is the title. */
  get title() {
    return this.row ? this.row.label : "";
  }

  /** Which booking, and when it is due. */
  get subline() {
    const row = this.row;
    if (!row) {
      return "";
    }
    return [row.unitName, this.bookingRef, this.dueText].filter(Boolean).join(" · ");
  }

  get bookingRef() {
    const list = this.bookedUnits || [];
    const hit = list.find((b) => b && b.salesOrderId === (this.row && this.row.salesOrderId));
    return hit ? hit.bookingRef : null;
  }

  get dueText() {
    const row = this.row;
    return row && row.dueDate ? LABELS.LED_ROW_DUE.replace("{0}", formatDate(row.dueDate)) : null;
  }

  get overdue() {
    return isOverdue(this.row);
  }

  get sublineClass() {
    return this.overdue ? "pm__sub pm__sub--late" : "pm__sub";
  }

  /* the head state is gone; the payment line carries the status */

  /* the lines */

  /** The total, as the body's first line. */
  get totalValue() {
    return this.row ? formatAED(this.row.requiredAmount) : null;
  }

  /** The payments with Finance, one line each, in the milestone modal's words. */
  get instrumentLines() {
    return liveInstrumentsOf(this.row).map((i) => {
      const modeRef = `${i.mode || ""} ${i.reference || ""}`.trim();
      const id = i.receiptName ? LABELS.MM_IL_PAYMENT.replace("{0}", i.receiptName) : modeRef;
      const meta = [
        i.receiptName ? modeRef : null,
        i.recordedOn ? LABELS.MM_IL_SUBMITTED.replace("{0}", formatDate(i.recordedOn)) : null
      ]
        .filter(Boolean)
        .join(" · ");
      return {
        key: i.receiptId,
        id,
        chip: i.status && i.status !== "In Progress" ? i.status : LABELS.MM_IL_CHIP,
        meta,
        amount: formatAED(i.amount),
        word: LABELS.MM_REC_WORD
      };
    });
  }

  /** Money Finance has allocated. */
  get paidLine() {
    const paid = Number((this.row && this.row.paidAmount) || 0);
    return paid > 0 ? formatAED(paid) : null;
  }

  /** The handoff into the form: only where lines stand above it. Gated on showForm. */
  get stillDueLine() {
    const row = this.row;
    if (!row || !this.showForm) {
      return null;
    }
    const paid = Number(row.paidAmount || 0);
    if (!liveInstrumentsOf(row).length && paid <= 0) {
      return null;
    }
    return { text: LABELS.LED_STILL_DUE_LINE, value: formatAED(stillDueOf(row)) };
  }

  /** Nothing further to record. */
  get coveredNote() {
    const row = this.row;
    if (!row) {
      return null;
    }
    const live = liveInstrumentsOf(row);
    return live.length && stillDueOf(row) <= 0 ? LABELS.ROW_PAY_COVERED : null;
  }

  /** Where a pay-first fee row's money comes from: the payment link or the terminal. */
  get routeNote() {
    if (!this.row || this.row.payRoute !== "TERMINAL") {
      return null;
    }
    return this.row.payByLink === true ? LABELS.ROW_ROUTE_LINK : LABELS.ROW_ROUTE_TERMINAL;
  }

  /**
   * The form appears when there is something still to record (stillDueOf), the same fact the
   * row's button reads. Not gated on recordsPayment: the block decides what its submit does.
   */
  get showForm() {
    return !!this.row && stillDueOf(this.row) > 0;
  }

  /** The rule above the form. */
  get formClass() {
    const above =
      this.instrumentLines.length > 0 || !!this.paidLine || !!this.stillDueLine || !!this.routeNote;
    return above ? "pm__frm pm__frm--rule" : "pm__frm";
  }

  /** A payment with no form ends on a footer. */
  get showFoot() {
    return !this.showForm;
  }

  /** The page's answer, if it was about this payment. */
  get formResult() {
    const r = this.proofResult;
    const row = this.row;
    return r && row && r.sourceId === row.sourceId
      ? { ok: r.ok === true, message: r.message }
      : null;
  }

  /* focus, escape, exit */

  renderedCallback() {
    if (!this.mounted || this.closing) {
      return;
    }
    if (this._resetOnOpen) {
      const form = this.template.querySelector("c-msc-payment-block");
      if (form) {
        this._resetOnOpen = false;
        form.reset();
      }
    }
    if (!this._focusedOnOpen) {
      const close = this.template.querySelector(".pm__x");
      if (close) {
        this._previousFocus = document.activeElement;
        close.focus({ preventScroll: true });
        this._focusedOnOpen = true;
      }
    }
  }

  disconnectedCallback() {
    this.clearExit();
    this.restoreFocus();
  }

  clearExit() {
    if (this._exitTimer) {
      clearTimeout(this._exitTimer);
      this._exitTimer = null;
    }
  }

  restoreFocus() {
    const prev = this._previousFocus;
    this._previousFocus = null;
    if (!prev || typeof prev.focus !== "function") {
      return;
    }
    try {
      prev.focus({ preventScroll: true });
    } catch (e) {
      /* the opener can be gone */
    }
  }

  get layerClass() {
    return this.closing ? "layer layer--closing" : "layer";
  }

  handleClose() {
    if (this.closing) {
      return;
    }
    this.dispatchEvent(new CustomEvent("close"));
  }

  stop(event) {
    event.stopPropagation();
  }

  /** Escape closes; stopPropagation so modonSheet does not close too. */
  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.handleClose();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const focusable = this.focusable();
    if (focusable.length < 2) {
      return;
    }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = this.template.activeElement;
    if (event.shiftKey && active === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  }

  focusable() {
    const root = this.template.querySelector(".pm");
    if (!root) {
      return [];
    }
    const sel =
      'button, [href], input, select, textarea, iframe, [tabindex]:not([tabindex="-1"])';
    return Array.from(root.querySelectorAll(sel)).filter(
      (el) => !el.disabled && el.getAttribute("aria-hidden") !== "true"
    );
  }

  /* events: c/mscPaymentBlock's events are re-raised with their detail intact */

  relay(event) {
    this.dispatchEvent(new CustomEvent(event.type, { detail: event.detail }));
  }

  handleRequestSlot(event) {
    this.relay(event);
  }
  handleProofUploaded(event) {
    this.relay(event);
  }
  handleCaptureProof(event) {
    this.relay(event);
  }
  handleProofRemoved(event) {
    this.relay(event);
  }
  handleSubmitProof(event) {
    /* no advance-after-refresh: a recorded payment stays on screen */
    this.relay(event);
  }
  handleSetupDirectDebit(event) {
    this.relay(event);
  }
}