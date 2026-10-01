/**
 * The settlement header - one figure, and the two legs that close the sale.
 *
 * Version  Author            Date         Detail
 * 2.3      Aurelix Dev       30 Sep 2026  "Booking fee collected" before and after Confirm, no finance wait line while
 *                                         finalising or closed, "Link sent" legs, figures in the text colour.
 * 2.2      Aurelix Dev       27 Sep 2026  noFee: before Confirm, a unit that takes no booking fee (its phase
 *                                         takes none, or its EOI covers it) read "Payable to confirm this
 *                                         booking" with two "Not started" legs, beside a Confirm button that
 *                                         needed no payment. The figures were the booking-fee preview, which
 *                                         such a unit never pays. It now says "No booking fee", with no
 *                                         figure and no legs, until money or a Sales Order exists.
 * 2.1      Aurelix Dev       03 Sep 2026  MSC-231. EOI deposit rows under the legs; Change hands
 *                                         the unit back up (depositchange).
 * 2.0      Aurelix Dev       20 Aug 2026  MSC-096. collectedText gone; one segment per closing payment.
 * 1.10     Aurelix Dev       21 Aug 2026  MSC-098b. Continue to Verification beside the figure (`advance`).
 * 1.9      Aurelix Dev       20 Aug 2026  MSC-095. A zero leg on a draft basket reads "After booking".
 * 1.9      Aurelix Developer 18 Aug 2026  Post-Confirm the two legs come off.
 * 1.8      Aurelix Developer 17 Aug 2026  The fee-formula footnote is gone.
 * 1.7      Aurelix Developer 17 Aug 2026  The footnote follows the booking's size (bookingUnitCount).
 * 1.6      Aurelix Developer 17 Aug 2026  The multi-unit no-fee rule, as a footnote from the DTO's order count.
 * 1.5      Aurelix Developer 17 Aug 2026  The confirmed strip: which booking and how far.
 * 1.4      Aurelix Developer 17 Aug 2026  Money in, booking not yet made, is a state.
 * 1.3      Aurelix Developer 17 Aug 2026  After Confirm is its own state; the confirmation moves to the top.
 * 1.2      Aurelix Developer 17 Aug 2026  The booking fee is labelled as one.
 * 1.1      Aurelix Developer 17 Aug 2026  "of {total}" dropped when nothing is collected.
 * 1.0      Aurelix Developer 16 Aug 2026  Initial.
 */
import { LightningElement, api } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";

/**
 * One figure: what is outstanding on the obligations that close the booking (the two legs of
 * SalesTeamVoidCheck__c). Four states, not three: captured here and recognised by the org differ
 * for hours, and AWAITING_CLEARANCE names that gap.
 */
const STATE = {
  NOT_STARTED: { chip: "chip chip--pending", label: LABELS.SETTLE_NOT_STARTED },
  PARTLY_PAID: { chip: "chip chip--due", label: LABELS.SETTLE_PARTLY },
  AWAITING_CLEARANCE: { chip: "chip chip--partial", label: LABELS.SETTLE_CLEARING },
  SETTLED: { chip: "chip chip--paid", label: LABELS.SETTLE_DONE }
};

/* 2.3: a leg with a live payment link and nothing paid on it yet */
const LINK_SENT = { chip: "chip chip--pending", label: LABELS.SETTLE_LINK_SENT };

export default class MscSettlementHeader extends LightningElement {
  /** SalesConsoleController.SettlementDTO. Null until the first load. */
  @api settlement;
  /** MSC-231: EOI deposit rows, composed by the page ({key, unitId?, label, sub, figure,
   *  chipLabel, chipClass, canChange}); Change hands the unit back up (`depositchange`). */
  @api deposits = [];
  handleDepositChange(event) {
    this.dispatchEvent(
      new CustomEvent("depositchange", {
        detail: { unitId: event.currentTarget?.dataset?.unit }
      })
    );
  }
  /* the booking is confirmed, so Continue to Verification rides beside the figure */
  @api advance = false;
  /* the confirmation, at the top of the card */
  @api bookingReference;
  /** MSC-095: units in the draft basket, before any Sales Order exists. See isDraftBasket. */
  @api draftUnitCount = 0;

  /** MSC-096: the payments that close this booking, for the progress strip only. Money only. */
  @api closingRows = [];

  /** 2.2: the page's answer that this unit takes no booking fee (single unit, before Confirm). */
  @api noFee = false;

  /** 2.3: a payment link the customer can still pay (legs read "Link sent", not "Not started"). */
  @api linkLive = false;
  /** 2.3: MODON has closed the sale (the summary's saleClosed). */
  @api saleClosed = false;
  /** 2.3: the page is still reading the booking's records after Confirm. */
  @api finalising = false;

  /* nothing collected and no Sales Order: the preview is a fee this unit does not pay */
  get noFeeView() {
    return (
      this.noFee === true &&
      !this.bookingConfirmed &&
      Number(this.s.totalCollected || 0) === 0
    );
  }

  labels = LABELS;

  /* the forward action */
  get showAdvance() {
    return this.advance === true;
  }

  handleAdvance() {
    this.dispatchEvent(new CustomEvent("advance"));
  }

  get s() {
    return this.settlement || {};
  }

  get hasSettlement() {
    return !!this.settlement;
  }

  /* the headline: nothing known yet, something owed, nothing owed */

  get nothingToCollect() {
    return this.hasSettlement && Number(this.s.totalRequired || 0) === 0;
  }

  get hasOutstanding() {
    return Number(this.s.totalRemaining || 0) > 0;
  }

  /** True while these figures are the booking-fee deposit. */
  get isBookingFee() {
    return this.s.isBookingFee === true;
  }

  /** The Sales Order exists. */
  get bookingConfirmed() {
    return this.s.bookingConfirmed === true;
  }

  /** The reference and the date must name the same order; the DTO carries both from one row. */
  get reference() {
    return this.s.bookingReference || this.bookingReference;
  }

  /**
   * MSC-096: with more than one order the strip says the count; each unit names its own reference
   * in the ledger. unitCount, not bookingUnitCount: the orders in view.
   */
  get orderCount() {
    return Number(this.s.unitCount || 0);
  }

  get referenceText() {
    return this.orderCount > 1
      ? LABELS.LEDGER_SO_COUNT.replace("{0}", String(this.orderCount))
      : this.reference;
  }

  get showConfirmedStrip() {
    return this.bookingConfirmed && !!this.referenceText;
  }

  /* the resume statement: when it happened, and how much is in */

  /** SettlementDTO.confirmedOn. */
  get confirmedOn() {
    return this.s.confirmedOn || null;
  }

  get confirmedOnText() {
    return this.confirmedOn
      ? LABELS.RESUME_CONFIRMED_ON.replace("{0}", formatDate(this.confirmedOn))
      : null;
  }

  /* MSC-096: how far the closing money has got. One segment per payment, about money only
   * (remainingAmount / paidAmount), never the four-state console status. */

  get closingList() {
    return Array.isArray(this.closingRows) ? this.closingRows : [];
  }

  /** Empty until a Sales Order exists. */
  get showProgress() {
    return this.bookingConfirmed && this.closingList.length > 0;
  }

  get progressTicks() {
    return this.closingList.map((row, i) => ({
      key: row.sourceId || `t-${i}`,
      cls: `settle__tick settle__tick--${this.tickFor(row)}`
    }));
  }

  tickFor(row) {
    const remaining = Number(row.remainingAmount || 0);
    const paid = Number(row.paidAmount || 0);
    if (remaining <= 0) {
      return "in";
    }
    return paid > 0 ? "part" : "open";
  }

  /** "4 payments · nothing collected yet" / "2 payments · AED 326,316.82 collected". */
  get progressText() {
    const n = this.closingList.length;
    const count =
      n === 1 ? LABELS.LEDGER_ITEM_ONE : LABELS.LEDGER_ITEMS.replace("{0}", String(n));
    const collected = Number(this.s.totalCollected || 0);
    return collected > 0
      ? LABELS.SETTLE_PROGRESS_SOME.replace("{0}", count).replace(
          "{1}",
          formatAED(collected)
        )
      : LABELS.SETTLE_PROGRESS_NONE.replace("{0}", count);
  }

  /** The strip is decorative; the sentence carries the fact. */
  get progressLabel() {
    return this.progressText;
  }

  /** The completion truth: gateSatisfied is SalesTeamVoidCheck__c across every order, or MODON closed the sale. */
  get bookingClosed() {
    return (this.s.gateKnown === true && this.s.gateSatisfied === true) || this.saleClosed === true;
  }

  /** 2.3: nothing left to wait for on the closing legs. */
  get closedOrSettled() {
    return (this.s.fullySettled === true && this.s.gateSatisfied === true) || this.saleClosed === true;
  }

  get resumeLead() {
    return this.bookingClosed ? LABELS.RESUME_CLOSED : "Booking confirmed";
  }

  /* the explanatory second line under "This booking is closed" was removed by request */

  /* green for a closed booking */
  get resumeIcon() {
    return this.bookingClosed ? "check-circle" : "check";
  }

  get headlineLabel() {
    if (this.noFeeView) {
      return LABELS.SETTLE_HEAD_NO_FEE;
    }
    if (this.nothingToCollect) {
      return LABELS.SETTLE_HEAD_NONE;
    }
    if (this.hasOutstanding) {
      /* the deposit is not the closing amount */
      if (!this.isBookingFee) {
        return LABELS.SETTLE_HEAD_OUTSTANDING;
      }
      /* after Confirm the fee holds the reservation rather than unlocking the button */
      return this.bookingConfirmed
        ? LABELS.SETTLE_HEAD_FEE_AFTER
        : LABELS.SETTLE_HEAD_BOOKING_FEE;
    }
    /* nothing owed and the booking not yet made: no Sales Order for finance to allocate against */
    if (!this.bookingConfirmed) {
      return LABELS.SETTLE_HEAD_FEE_IN;
    }
    /* 2.3: the fee is what was collected, before and after Confirm; "settled" is the status chip's word */
    if (this.isBookingFee) {
      return LABELS.SETTLE_HEAD_FEE_IN;
    }
    return this.closedOrSettled || this.finalising === true
      ? LABELS.SETTLE_HEAD_SETTLED
      : LABELS.SETTLE_HEAD_CLEARING;
  }

  /** The one number. */
  get headlineFigure() {
    if (this.nothingToCollect || this.noFeeView) {
      return null;
    }
    return this.hasOutstanding
      ? formatAED(this.s.totalRemaining)
      : formatAED(this.s.totalCollected);
  }

  /** The supporting line. */
  get headlineSub() {
    if (this.nothingToCollect || this.noFeeView) {
      return LABELS.SETTLE_SUB_NONE;
    }
    if (this.hasOutstanding) {
      const collected = Number(this.s.totalCollected || 0);
      /* nothing collected: the outstanding figure is the total, so no "of X" echo */
      if (collected <= 0) {
        /* a booking fee still needs saying what it is */
        if (!this.isBookingFee) {
          return null;
        }
        /* the pre-Confirm line promises something already delivered */
        return this.bookingConfirmed
          ? LABELS.SETTLE_SUB_FEE_AFTER
          : LABELS.SETTLE_SUB_BOOKING_FEE;
      }
      return LABELS.SETTLE_SUB_OF_WITH_PAID.replace(
        "{0}",
        formatAED(this.s.totalRequired)
      ).replace("{1}", formatAED(collected));
    }
    if (!this.bookingConfirmed) {
      return LABELS.SETTLE_SUB_FEE_IN;
    }
    /* 2.3: nothing to add once closed; no "waiting for finance" while the page is still reading */
    if (this.closedOrSettled || this.finalising === true) {
      return null;
    }
    return LABELS.SETTLE_SUB_CLEARING;
  }

  /* 2.3: the figure keeps the text colour; the small mark beside the label carries the state */
  get figureClass() {
    return "settle__fig";
  }

  get markClass() {
    if (this.nothingToCollect || this.noFeeView || this.hasOutstanding) {
      return null;
    }
    const waiting = this.bookingConfirmed && !this.closedOrSettled && this.finalising !== true;
    return waiting ? "settle__mark settle__mark--wait" : "settle__mark settle__mark--done";
  }

  /** The formula, said once at the bottom. */
  /* from the DTO, not an @api prop: the page's own count is 1 on every resume */
  get isMultiUnit() {
    return Number(this.s.unitCount || 1) > 1;
  }

  /* the booking is multi-unit whatever this view covers (SettlementDTO.bookingUnitCount) */
  get bookingIsMultiUnit() {
    return Number(this.s.bookingUnitCount || this.s.unitCount || 1) > 1;
  }

  /** One order of a multi-unit booking, viewed alone. */
  get isBasketMemberView() {
    return this.bookingIsMultiUnit && !this.isMultiUnit;
  }

  /**
   * MSC-095: a basket still being assembled, which the DTO cannot see. Used only to word a zero leg.
   */
  get isDraftBasket() {
    return !this.bookingConfirmed && Number(this.draftUnitCount || 0) > 1;
  }

  /** The only footnote left is the multi-unit one. */
  get showFootnote() {
    return this.hasSettlement && !this.isBookingFee && this.bookingIsMultiUnit;
  }

  get footnote() {
    /* the journey-07 rule, stated where the legs are read */
    if (this.isBasketMemberView) {
      return LABELS.SETTLE_MULTI_NO_FEE_ONE.replace(
        "{0}",
        String(this.s.bookingUnitCount)
      );
    }
    return LABELS.SETTLE_MULTI_NO_FEE;
  }

  /* the two legs: always both, always in this order */

  get legs() {
    if (!this.hasSettlement) {
      return [];
    }
    /* post-Confirm the deposit is stated inside the Scheduled rows */
    if (this.bookingConfirmed || this.noFeeView) {
      return [];
    }
    return [this.s.admLeg, this.s.downPaymentLeg]
      .filter((l) => !!l)
      .map((l) => this.decorate(l));
  }

  decorate(leg) {
    let state = STATE[leg.consoleStatus] || STATE.NOT_STARTED;
    /* 2.3: nothing paid yet, but the customer has a live link for it */
    if (this.linkLive === true && state === STATE.NOT_STARTED) {
      state = LINK_SENT;
    }
    const required = Number(leg.requiredAmount || 0);
    const paid = Number(leg.paidAmount || 0);
    const remaining = Number(leg.remainingAmount || 0);

    /* the number on the right is whichever is actionable */
    let figure;
    if (required === 0) {
      figure = this.isDraftBasket ? LABELS.SETTLE_LEG_AFTER : LABELS.SETTLE_LEG_NONE;
    } else if (remaining > 0) {
      /* "due" until something has been paid, "left" after */
      figure = (paid > 0 ? LABELS.SETTLE_LEG_LEFT : LABELS.SETTLE_LEG_DUE).replace(
        "{0}",
        formatAED(remaining)
      );
    } else {
      figure = formatAED(paid);
    }

    /* a hairline, only for part paid */
    const showBar = required > 0 && paid > 0 && remaining > 0;
    const pct = showBar ? Math.min(100, Math.round((paid / required) * 100)) : 0;

    return {
      key: leg.key,
      label: leg.label,
      chipClass: state.chip,
      chipLabel: state.label,
      figure,
      figureClass:
        remaining > 0 && required > 0
          ? "leg__fig leg__fig--owed"
          : "leg__fig",
      showBar,
      barStyle: `width:${pct}%`,
      /* only where money is in and the org has not caught up */
      note:
        leg.consoleStatus === "AWAITING_CLEARANCE" ? LABELS.SETTLE_LEG_CLEARING : null
    };
  }
}