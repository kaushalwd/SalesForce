/**
 * What a payment IS - derived once, read everywhere.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 21 Aug 2026  MSC-099. Extracted from c/mscObligations when the
 *                                   expanded row became a modal of its own
 *                                   (c/mscPaymentModal). The row's status, the row's
 *                                   Recorded column, the row's button label and the
 *                                   modal's lines are all answers to the same four
 *                                   questions; asked in two components they could drift,
 *                                   and a rep would read "Record payment" on a row whose
 *                                   modal says nothing is due. Asked here, they cannot.
 *
 * Pure functions over one PaymentBucketDTO. No state, no service calls, no DOM.
 * Every figure is the SERVER's: remainingAmount, openAmount, paidAmount and the
 * instruments - never arithmetic invented on the client.
 */
import { LABELS } from "c/mscLabels";

const BUCKET_ADM = "ADM_REGISTRATION_FEE";
const BUCKET_DOWN = "DOWN_PAYMENT";
const BUCKET_MILESTONE = "MILESTONE";

/* The four states a payment can be in, as the settlement legs name them. Moved
   from c/mscObligations 2.9 unchanged - CHIP is the filled pill, TONE the dot, and
   they are keyed identically so a state that gains one gains the other. */
const CHIP = {
  NOT_STARTED: { cls: "chip chip--pending", text: LABELS.SETTLE_NOT_STARTED },
  PARTLY_PAID: { cls: "chip chip--due", text: LABELS.SETTLE_PARTLY },
  AWAITING_CLEARANCE: { cls: "chip chip--partial", text: LABELS.SETTLE_CLEARING },
  SETTLED: { cls: "chip chip--paid", text: LABELS.SETTLE_DONE },
  NOTHING_DUE: { cls: "chip chip--pending", text: LABELS.SETTLE_LEG_NONE }
};

const TONE = {
  NOT_STARTED: "dot",
  PARTLY_PAID: "dot dot--part",
  AWAITING_CLEARANCE: "dot dot--part",
  SETTLED: "dot dot--done",
  NOTHING_DUE: "dot"
};

/**
 * Does this row belong BEHIND "Manage milestone payments"?
 *
 * 1.1 - the test lived in two places, written twice as `MILESTONE && number > 1`:
 * c/mscObligations decided which rows the box folds, and c/mscBookingPage decided
 * which rows the modal lists. Two copies of one rule is how a card comes to offer a
 * button over an empty modal, so it is asked here now and answered once.
 *
 * A milestone is scheduled when it is not the payment that closes the sale. The
 * number is how that is usually known - milestone 1 IS the down payment - but the
 * number is not always there: GolfEstate-GV-140's plan is a single 1% installment due
 * six weeks after the booking, and its MilestoneNumber__c is null. `Number(null) > 1`
 * is false, so that row was neither boxed nor closing: it fell between the two tiers,
 * and its unit card drew no scheduled tier and no way to manage it at all.
 *
 * An UNNUMBERED milestone is therefore scheduled. It cannot be the down payment -
 * that row says so itself, with closesSale - and a payment due after the booking with
 * nowhere to be managed is the worse answer of the two.
 *
 * This asks ONLY about the number, deliberately. The two callers differ on closesSale
 * and both are right to: c/mscObligations reaches this from `scheduledRows`, which is
 * `closesSale !== true` already, while c/mscBookingPage filters the whole ledger and
 * states the test itself. Folding closesSale in here would have changed the ledger's
 * answer for a closing milestone numbered above 1 - a row this org does not raise, and
 * not a row this change is about. A differential over 180 row shapes holds the two
 * callers to exactly their old answers, plus the unnumbered case.
 */
export function isScheduledMilestone(row) {
  if (!row || row.key !== BUCKET_MILESTONE) {
    return false;
  }
  const n = row.milestoneNumber;
  if (n === null || n === undefined || n === "") {
    return true;
  }
  const num = Number(n);
  return Number.isNaN(num) ? true : num > 1;
}

/**
 * What is left to collect.
 *
 * remainingAmount is computed server-side precisely so this never has to fall back
 * to Balance_Amount__c, which is null on records its roll-up has not run against.
 * The || is for a stale client during a deploy, not for normal use.
 */
export function remainingOf(row) {
  if (!row) {
    return 0;
  }
  const r = Number(row.remainingAmount);
  if (!Number.isNaN(r) && row.remainingAmount !== undefined && row.remainingAmount !== null) {
    return r;
  }
  return Math.max(0, Number(row.requiredAmount || 0) - Number(row.paidAmount || 0));
}

/** The payments standing against this row that Finance has not allocated yet. */
export function liveInstrumentsOf(row) {
  return ((row && row.instruments) || []).filter((i) => i && i.live === true);
}

/** The sum of those - what is with Finance right now. */
export function withFinanceOf(row) {
  return liveInstrumentsOf(row).reduce((sum, i) => sum + Number(i.amount || 0), 0);
}

/**
 * Everything handed over, in any form: allocated money PLUS what is with Finance.
 * The Recorded column and the modal's lines both sum this, so the column can never
 * disagree with the lines beneath it.
 */
export function recordedOf(row) {
  return Number((row && row.paidAmount) || 0) + withFinanceOf(row);
}

/**
 * What a NEW payment may still be recorded for.
 *
 * The server's openAmount when a live payment stands - it already subtracts what is
 * with Finance, so money is never asked for twice - and remainingAmount otherwise.
 * Never client arithmetic. A row whose openAmount is missing (a stale client mid
 * deploy) falls back to remaining: asking for too much is recoverable, telling a rep
 * nothing is due when money is owed is not.
 */
export function stillDueOf(row) {
  const remaining = remainingOf(row);
  if (!liveInstrumentsOf(row).length) {
    return remaining;
  }
  const open = row.openAmount;
  if (open === undefined || open === null || Number.isNaN(Number(open))) {
    return remaining;
  }
  return Number(open);
}

/** The state key alone - the settlement leg's answer where there is one. */
export function statusKeyOf(row, settlement) {
  if (!row) {
    return "NOT_STARTED";
  }
  if (settlement) {
    if (row.key === BUCKET_ADM && settlement.admLeg) {
      return settlement.admLeg.consoleStatus;
    }
    if (row.key === BUCKET_DOWN && settlement.downPaymentLeg) {
      return settlement.downPaymentLeg.consoleStatus;
    }
  }
  const required = Number(row.requiredAmount || 0);
  const paid = Number(row.paidAmount || 0);
  if (required === 0) {
    return "NOTHING_DUE";
  }
  if (remainingOf(row) <= 0) {
    return "SETTLED";
  }
  return paid > 0 ? "PARTLY_PAID" : "NOT_STARTED";
}

/**
 * The state as it is DRAWN: the leg's status, unless a payment is sitting with
 * Finance against money still open - then the row says so, in the blue everything
 * awaiting Finance wears.
 *
 * A settled row with live instruments is NOT overridden: nothing is open on it, so
 * "Settled" is the true answer and the cheques behind it are history.
 */
export function statusOf(row, settlement) {
  const key = statusKeyOf(row, settlement);
  const live = liveInstrumentsOf(row);
  if (live.length && remainingOf(row) > 0) {
    const allCheques = live.every((i) => i.mode === "Cheque");
    return {
      key,
      text: allCheques ? LABELS.ROW_CHEQUE_CHIP : LABELS.ROW_PAY_CHIP,
      chipClass: "chip chip--partial",
      dotClass: "dot dot--rec"
    };
  }
  const chip = CHIP[key] || CHIP.NOT_STARTED;
  return {
    key,
    text: chip.text,
    chipClass: chip.cls,
    dotClass: TONE[key] || TONE.NOT_STARTED
  };
}

/** Past its date with money still on it. Date-only, so "today" is never late. */
export function isOverdue(row) {
  if (!row || !row.dueDate || remainingOf(row) <= 0) {
    return false;
  }
  const due = new Date(row.dueDate);
  if (isNaN(due.getTime())) {
    return false;
  }
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  due.setHours(0, 0, 0, 0);
  return due.getTime() < today.getTime();
}