/**
 * The obligation ledger - every payment on one screen, one form open at a time.
 *
 * Version  Author            Date         Detail
 * 3.11     Aurelix Dev       30 Sep 2026  Phone rows stack; due-now rows read "Finalising" while the fee is allocated;
 *                                         settled figures in the text colour with a small mark.
 * 3.10     Aurelix Dev       29 Sep 2026  A booking fee row paid by payment link says so (payByLink,
 *                                         BOOKING_FEE_BY_LINK); the terminal sentence stays for the terminal.
 * 3.9      Aurelix Dev       21 Sep 2026  An active mandate's line names the milestones not yet Paid - the
 *                                   mandate card's own rule - not the box's whole range, which counted a settled one.
 * 3.8      Aurelix Dev       18 Sep 2026  SCW-125. The tier line names the mandate's UAEDDS stage; an ended
 *                                   mandate (rejected / discarded / cancelled) is named, not assumed rejected.
 * 3.7      Aurelix Dev       01 Sep 2026  MSC-197. A recorded cheque says what its image read, and
 *                                   a read that failed can be retried from here - the first
 *                                   screen in the console that shows either.
 * 3.6      Aurelix Dev       25 Aug 2026  MSC-169. No unit card opens by itself.
 * 3.5      Aurelix Dev       21 Aug 2026  MSC-101a. A basket unit card draws one table, not two.
 * 3.4      Aurelix Dev       21 Aug 2026  MSC-100a. The strip above the table: a rule and the count, no title.
 * 3.3      Aurelix Dev       21 Aug 2026  MSC-100. The table row states what is still pending; four columns.
 * 3.2      Aurelix Dev       21 Aug 2026  Due date reads grey either way; OVERDUE pill gone.
 * 3.1      Aurelix Dev       21 Aug 2026  "Paying by cheque" pill gone.
 * 3.0      Aurelix Dev       21 Aug 2026  MSC-099. The table row opens c/mscPaymentModal; the button label follows
 *                                   what is still due; facts moved to c/mscPaymentFacts; openRowOn.
 * 2.9      Aurelix Dev       21 Aug 2026  MSC-098c. Scheduled line's figure comes off post-Confirm.
 * 2.8      Aurelix Dev       21 Aug 2026  MSC-098c. Still due column leaves the row.
 * 2.7      Aurelix Dev       21 Aug 2026  MSC-098b. Percentage width plan, no scroll; Due now draws no strip.
 * 2.6      Aurelix Dev       21 Aug 2026  MSC-098a. Elastic column gaps.
 * 2.5      Aurelix Dev       21 Aug 2026  MSC-098a. Column words once, centred, in a thead.
 * 2.4      Aurelix Dev       21 Aug 2026  MSC-098. One meaning per number: Total / Recorded / Still due.
 * 2.3      Aurelix Dev       21 Aug 2026  MSC-097. The schedule leaves the card for c/mscMilestoneModal.
 * 2.2      Aurelix Dev       21 Aug 2026  MSC-096b. Due now is its own section after booking.
 * 2.1      Aurelix Dev       20 Aug 2026  MSC-096a. One card per unit, one open at a time.
 * 2.0      Aurelix Dev       20 Aug 2026  MSC-096. The ledger is a table and the unit is a column.
 * 1.10     Aurelix Developer 19 Aug 2026  A lead row a payment covers.
 * 1.9      Aurelix Developer 18 Aug 2026  The milestone box.
 * 1.8      Aurelix Developer 17 Aug 2026  "Show settled" is gone.
 * 1.7      Aurelix Developer 17 Aug 2026  The ADM + Dari charge row.
 * 1.6      Aurelix Developer 17 Aug 2026  Grouped by unit.
 * 1.5      Aurelix Developer 17 Aug 2026  Incomplete-first on resume; openRowId.
 * 1.4      Aurelix Developer 17 Aug 2026  The hold as a state; payRoute on the row.
 * 1.2      Aurelix Developer 17 Aug 2026  "of {required}" sub-line dropped when nothing is paid.
 * 1.1      Aurelix Developer 17 Aug 2026  Classes renamed .row* -> .oblig*.
 * 1.0      Aurelix Developer 16 Aug 2026  Initial.
 */
import { LightningElement, api, track } from "lwc";
import basePath from "@salesforce/community/basePath";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
/* MSC-197: one more attempt at a cheque read that failed; the class is on the console permset */
import retryRead from "@salesforce/apex/ChequeFileController.retryRead";
/* what a payment is, answered in c/mscPaymentFacts; aliased so this.remainingOf still reads as before */
import {
  remainingOf as factRemainingOf,
  stillDueOf as factStillDueOf,
  isScheduledMilestone as factIsScheduledMilestone,
  statusOf as factStatusOf,
  isOverdue as factIsOverdue
} from "c/mscPaymentFacts";

/**
 * Every obligation used to render as an open capture form. A ledger shows what is outstanding
 * at a glance and opens exactly one form. Rows are grouped by one question: does paying this
 * close the booking?
 */

/* one vocabulary across the step: the closing rows take their status from the settlement header's legs */
/* CHIP and the row status derivation moved to c/mscPaymentFacts (statusOf). TONE stays: the unit
   card's head status is about a unit. States drawn as a dot, not a filled pill. */
const TONE = {
  NOT_STARTED: "dot",
  PARTLY_PAID: "dot dot--part",
  AWAITING_CLEARANCE: "dot dot--part",
  SETTLED: "dot dot--done",
  NOTHING_DUE: "dot"
};

/* the figure without the currency word */
function bareAED(v) {
  return formatAED(v).replace(/^AED\s/, "");
}

/* BUCKET_ADM / BUCKET_DOWN left with statusKeyFor; MILESTONE stays for isBoxRow */
const BUCKET_MILESTONE = "MILESTONE";

/* "N payments" when a non-milestone row is in the group */
function scheduledLabelFor(rows) {
  const allMilestones = rows.every((r) => r.key === BUCKET_MILESTONE);
  /* the singular */
  if (rows.length === 1) {
    return allMilestones ? LABELS.LEDGER_MILESTONE_ONE : LABELS.LEDGER_ITEM_ONE;
  }
  return (allMilestones ? LABELS.LEDGER_MILESTONES : LABELS.LEDGER_ITEMS).replace(
    "{0}",
    rows.length
  );
}

export default class MscObligations extends LightningElement {
  /** Decorated payment blocks from mscBookingPage.paymentBlocks. */
  @api
  get rows() {
    return this._rows;
  }
  set rows(value) {
    this._rows = value || [];
    this.reconcileOpenRow();
  }
  _rows = [];

  /** SalesConsoleController.SettlementDTO, for the two closing rows' status. */
  @api settlement;
  /** True when the basket holds more than one unit. */
  @api multiUnit = false;
  /* ConsoleState.bookedUnits, so a unit's group can carry its Sales Order reference. Optional. */
  @api bookedUnits = [];
  @api busy = false;

  /* the hold as a state: is this unit still ours (an expired hold with money against it is still reserved) */
  /** Seconds left on the unit hold; undefined means no hold. */
  @api holdSecondsLeft;
  /** Any money at all against the booking fee. */
  @api hasCollected = false;

  /* a booking reopened from Total Sales; drives the closing group's incomplete-first filter only */
  @api resumed = false;

  /** A row the page wants opened (Still to do). Cleared through `rowopened`. */
  @api
  get openRowId() {
    return this._openRowId;
  }
  set openRowId(value) {
    this._openRowId = value;
    if (value) {
      const row = this._rows.find((r) => r.sourceId === value);
      /* the card first: a deep-linked row may sit in a closed unit; openRowOn decides the surface */
      this.focusUnitFor(value);
      if (row) {
        this.openRowOn(row);
      } else {
        /* the row is not in this card's list */
        this.openId = undefined;
      }
      this.dispatchEvent(new CustomEvent("rowopened"));
    }
  }
  _openRowId;

  /* the milestone box: `confirmed` (the Sales Order exists) and `batch` ({ [salesOrderId]: MilestoneBatchDTO }) */
  @api confirmed = false;
  /* true only while the page waits for the booking's records to finish being written */
  @api finalising = false;
  @api
  get batch() {
    return this._batch;
  }
  set batch(value) {
    /* nothing to reconcile: the panels live in c/mscMilestoneModal */
    this._batch = value || {};
  }
  _batch = {};
  /* chequeResult / chequeError left with the sheet */
  /* what the page heard back for the last Create Payment on a lead row */
  @api proofResult;

  /** Which pre-Confirm reference lists are unfolded, keyed by Sales Order id. */
  @track boxOpen = {};

  labels = LABELS;

  /** sourceId of the one open row. */
  openId;
  /** The one open unit card, by unitKeyOf. undefined and null both mean every card shut (MSC-169). */
  _openUnit;
  /* `scheduledOpen` is gone: the per-unit lines are always drawn */
  /** Armed by a proof submission so the next outstanding row opens. */
  _advanceAfterRefresh = false;

  /* grouping */

  /* every closing row, always; the incomplete-first filter and its toggle are gone */
  get closingRows() {
    return this.decorate(this._rows.filter((r) => r.closesSale === true));
  }

  get scheduledRows() {
    return this.decorate(this._rows.filter((r) => r.closesSale !== true));
  }

  /* `hasClosing` and `hasScheduled` are gone; both questions are asked per unit */

  /* grouped by unit: rows sit under the unit they belong to; a single unit is one headless group */
  /* `closingGroups` is gone; the tier is a table and the unit is a column */

  /** One card per unit, one open at a time; a single unit is one headless card. */
  get unitCards() {
    const closing = this.closingRows;
    const sched = this.scheduledUnits;
    if (!this.grouped) {
      const one = sched.length ? sched[0] : null;
      if (!closing.length && !one) {
        return [];
      }
      return [this.buildCard("_", null, null, closing, one, false)];
    }
    const order = [];
    const byKey = new Map();
    const seat = (key, name, ref) => {
      let c = byKey.get(key);
      if (!c) {
        c = { key, name, ref, closing: [], sched: null };
        byKey.set(key, c);
        order.push(c);
      }
      return c;
    };
    /* closing first */
    closing.forEach((r) => {
      const c = seat(
        this.unitKeyOf(r),
        r.unitName || LABELS.LEDGER_UNIT_UNNAMED,
        this.bookingRefFor(r.salesOrderId)
      );
      c.closing.push(r);
    });
    sched.forEach((u) => {
      seat(u.unitKey, u.name || LABELS.LEDGER_UNIT_UNNAMED, u.ref).sched = u;
    });
    return order.map((c) => this.buildCard(c.key, c.name, c.ref, c.closing, c.sched, true));
  }

  /** The Sales Order is the identity. */
  unitKeyOf(row) {
    return row.salesOrderId || row.unitName || "_";
  }

  buildCard(stateKey, name, ref, closingRows, sched, showHead) {
    const open = showHead ? this.openUnitKey === stateKey : true;
    /* the rows this card's table lists, which on a basket is not `closingRows`; the head counts from it */
    const cardRows = this.cardTableRows(closingRows, sched);
    const left = cardRows.reduce((sum, r) => sum + this.remainingOf(r), 0);
    const outstanding = cardRows.filter((r) => this.remainingOf(r) > 0).length;
    const paidSome = cardRows.some((r) => Number(r.paidAmount || 0) > 0);
    const settled = cardRows.length > 0 && outstanding === 0;
    return {
      key: `uc-${stateKey}`,
      stateKey,
      showHead,
      name,
      ref,
      open,
      cardClass: showHead ? (open ? "uc uc--open" : "uc") : "uc uc--flat",
      chevron: open ? "chevron-up" : "chevron-down",
      ariaExpanded: open ? "true" : "false",
      /* a closed card answers one question: is anything left to collect; open, it says neither */
      headStatus: settled || open
        ? null
        : {
            cls: paidSome ? TONE.PARTLY_PAID : TONE.NOT_STARTED,
            text: LABELS.LEDGER_UNIT_OUTSTANDING_OF.replace("{0}", outstanding).replace(
              "{1}",
              cardRows.length
            )
          },
      headFigure: settled ? LABELS.LEDGER_UNIT_SETTLED : formatAED(left),
      headFigureClass: settled ? "uc__fig uc__fig--settled" : "uc__fig",
      /* what is arranged for the milestones, on the closed card */
      chip: sched && !open ? sched.chip : null,
      tables: this.tablesFor(stateKey, closingRows, sched),
      /* the tier draws itself only when it has rows */
      sched: sched && sched.hasTier ? sched : null
    };
  }

  /* the two tables a card can hold: CLOSES THE BOOKING and DUE NOW (the ADM + Dari charge and
   * Milestone 1 with the deposit applied, on a single unit that took a fee) */
  /**
   * One table on a basket: both rows close the sale, and an unnumbered milestone (SO-15442)
   * otherwise landed in dueNowRows and drew a second table. Read by tablesFor and buildCard.
   */
  cardTableRows(closingRows, sched) {
    const dueNow = sched && sched.dueNowRows ? sched.dueNowRows : [];
    if (this.mergesDueNow !== true || !dueNow.length) {
      return closingRows;
    }
    return closingRows.concat(dueNow);
  }

  /** A basket card holds one table; a single unit keeps its two tiers. */
  get mergesDueNow() {
    return this.multiUnit === true;
  }

  tablesFor(stateKey, closingRows, sched) {
    const out = [];
    const merged = this.cardTableRows(closingRows, sched);
    if (merged.length) {
      out.push({
        key: `${stateKey}-close`,
        title: LABELS.LEDGER_CLOSES_TITLE,
        count: this.countText(merged),
        rows: this.closingTable(merged),
        /* the hold is the only thing drawn above this table now */
        hold: true
      });
    }
    const dueNow = sched && sched.dueNowRows ? sched.dueNowRows : [];
    /* on a basket these rows are already in the table above */
    if (dueNow.length && this.mergesDueNow !== true) {
      /* the count is drawn again on the strip; the title stays derived, unrendered */
      out.push({
        key: `${stateKey}-due`,
        title: LABELS.LEDGER_DUE_NOW_TITLE,
        count: this.countText(dueNow),
        rows: this.closingTable(dueNow),
        hold: false
      });
    }
    return out;
  }

  /**
   * "2 payments · 1 pending": the count says what the rows say. Three states; with everything
   * recorded but not allocated, nothing is pending and nothing is settled.
   */
  countText(rows) {
    const items = (rows.length === 1 ? LABELS.LEDGER_ITEM_ONE : LABELS.LEDGER_ITEMS).replace(
      "{0}",
      rows.length
    );
    const pending = rows.filter((r) => factStillDueOf(r) > 0).length;
    if (pending > 0) {
      return `${items} · ${LABELS.LEDGER_PENDING.replace("{0}", pending)}`;
    }
    if (rows.filter((r) => this.remainingOf(r) > 0).length > 0) {
      return `${items} · ${LABELS.LEDGER_NONE_PENDING}`;
    }
    return `${items} · ${LABELS.LEDGER_ALL_SETTLED}`;
  }

  /* the closing tier as a table; the Unit column is gone inside a card that names the unit */
  closingTable(rows) {
    return rows.map((r) => ({
      ...r,
      /* `.oblig` is display: block, which breaks a <tr>; one class, one <tr> per payment */
      rowClass: "led__row"
    }));
  }

  /* one card open at a time: the single assignment below is the rule */

  /**
   * MSC-169. Every card starts shut; `defaultUnitKey` removed. Opening on purpose is untouched
   * (handleUnitToggle, focusUnitFor).
   */
  get openUnitKey() {
    return this._openUnit === undefined ? null : this._openUnit;
  }

  handleUnitToggle(event) {
    const key = event.currentTarget.dataset.u;
    if (!key) {
      return;
    }
    this._openUnit = this.openUnitKey === key ? null : key;
  }

  /** A row opened by id may sit in a closed card; open the card that holds it. */
  focusUnitFor(sourceId) {
    const row = this._rows.find((r) => r.sourceId === sourceId);
    if (row) {
      this._openUnit = this.unitKeyOf(row);
    }
  }

  get scheduledGroups() {
    return this.groupByUnit(this.scheduledRows, "scheduled");
  }

  /* one line per unit: unit, what it covers, what is left, the two arrangements; buildBox still
   * supplies every flag */
  get scheduledUnits() {
    return this.scheduledGroups.map((g) => {
      const box = g.box;
      /* the same key handleBoxToggle uses; only the pre-Confirm reference list still folds */
      const stateKey = g.salesOrderId || "_";
      const expanded = this.boxOpen[stateKey] === true;
      return {
        key: g.key,
        unitKey: g.unitKey,
        salesOrderId: g.salesOrderId,
        showHead: g.showHead,
        name: g.name,
        ref: g.ref,
        figure: g.figure,
        figureClass: g.figureClass,
        /* what the tier is, on its own head */
        count: g.note,
        countClass: g.late ? "grp__count grp__count--late" : "grp__count",
        /* and what covers them; only the box has anything to say */
        summary: box ? box.summary : null,
        summaryClass: g.noteClass,
        chip: box ? box.chip : null,
        /* post-Confirm the schedule lives in c/mscMilestoneModal; the rows here are the pre-Confirm list */
        showManage: !!box,
        showToggle: !box,
        /* the figure comes off the line once the modal owns the schedule */
        showFigure: !box,
        rows: box ? [] : g.rows,
        dueNowRows: g.dueNowRows,
        hasTier: g.hasTier,
        showRows: box ? false : expanded,
        chevron: expanded ? "chevron-up" : "chevron-down",
        ariaExpanded: expanded ? "true" : "false"
      };
    });
  }

  /* `soloScheduled` is gone: a single unit is one headless card */

  /** Grouping is a basket's shape; a single unit is one headless group. */
  get grouped() {
    return this.multiUnit === true;
  }

  bookingRefFor(salesOrderId) {
    const list = this.bookedUnits || [];
    const hit = list.find((b) => b && b.salesOrderId === salesOrderId);
    return hit ? hit.bookingRef : null;
  }

  groupByUnit(rows, tier) {
    const groups = [];
    const byKey = new Map();
    if (!this.grouped) {
      /* one headless group, through the same fold */
      if (!rows.length) return [];
      const g = {
        key: "all",
        unitKey: this.unitKeyOf(rows[0]),
        salesOrderId: rows[0].salesOrderId,
        showHead: false,
        name: null,
        ref: null,
        rows: rows.slice(),
        remaining: 0,
        outstanding: 0,
        overdue: 0,
        dates: []
      };
      rows.forEach((r) => {
        const left = this.remainingOf(r);
        g.remaining += left;
        if (left > 0) g.outstanding += 1;
        if (r.overdue) g.overdue += 1;
      });
      groups.push(g);
    }
    if (this.grouped) rows.forEach((r) => {
      /* the Sales Order is the identity */
      const gk = r.salesOrderId || r.unitName || "_";
      let g = byKey.get(gk);
      if (!g) {
        g = {
          key: `u-${gk}`,
          /* the key the unit card is opened under */
          unitKey: gk,
          salesOrderId: r.salesOrderId,
          showHead: true,
          name: r.unitName || LABELS.LEDGER_UNIT_UNNAMED,
          ref: this.bookingRefFor(r.salesOrderId),
          rows: [],
          remaining: 0,
          outstanding: 0,
          overdue: 0,
          dates: []
        };
        byKey.set(gk, g);
        groups.push(g);
      }
      g.rows.push(r);
      const left = this.remainingOf(r);
      g.remaining += left;
      if (left > 0) g.outstanding += 1;
      if (r.overdue) g.overdue += 1;
      if (r.dueDate) g.dates.push(r.dueDate);
    });

    return groups.map((g) => {
      const gk = g.salesOrderId;

      /* due on booking is not scheduled after it: the ADM + Dari charge and Milestone 1 with the
       * deposit applied come out into `dueNowRows` */
      let dueNowRows = [];
      let tierRows = g.rows;
      let box = null;
      if (tier === "scheduled" && this.confirmed === true) {
        tierRows = g.rows.filter((r) => this.isBoxRow(r));
        dueNowRows = g.rows.filter((r) => !this.isBoxRow(r));
        if (tierRows.length) {
          box = this.buildBox(gk === undefined ? null : gk, tierRows);
        }
      }

      /* counted, totalled and dated from the rows the heading sits above */
      const remaining = tierRows.reduce((sum, r) => sum + this.remainingOf(r), 0);
      const outstanding = tierRows.filter((r) => this.remainingOf(r) > 0).length;
      const overdue = tierRows.filter((r) => r.overdue === true).length;
      const settled = tierRows.length > 0 && outstanding === 0;
      const figure = settled ? LABELS.LEDGER_UNIT_SETTLED : formatAED(remaining);

      /* the `closing` branch is gone; groupByUnit is called once with "scheduled" */
      let noteClass = "sch__note";
      const label = scheduledLabelFor(tierRows);
      let note;
      if (overdue > 0) {
        const word =
          overdue === 1
            ? LABELS.LEDGER_OVERDUE_ONE
            : LABELS.LEDGER_OVERDUE.replace("{0}", overdue);
        note = `${label} · ${word}`;
        noteClass = "sch__note sch__note--late";
      } else {
        const first = tierRows
          .map((r) => r.dueDate)
          .filter((d) => !!d)
          .sort()[0];
        note = first
          ? `${label} · ${LABELS.LEDGER_FIRST_DUE.replace("{0}", formatDate(first))}`
          : label;
      }

      return {
        key: g.key,
        unitKey: g.unitKey,
        /* whether anything the tier lists is already late */
        late: overdue > 0,
        /* carried out of the fold; files against the Sales Order */
        salesOrderId: g.salesOrderId,
        showHead: g.showHead,
        name: g.name,
        ref: g.ref,
        figure,
        /* .sch__*, not .ugrp__* */
        figureClass: settled ? "sch__fig sch__fig--settled" : "sch__fig",
        note,
        noteClass,
        /* what the chevron reveals, and what sits above it */
        rows: tierRows,
        dueNowRows,
        hasTier: tierRows.length > 0,
        box
      };
    });
  }

  /* `closingCount` is gone; each card counts its own unit through countText */

  /* the hold, on the group it protects */

  /** Only where a hold means something: a pay-first booking before the fee is in (payRoute). */
  get showHold() {
    return (
      this.holdSecondsLeft !== undefined &&
      this.holdSecondsLeft !== null &&
      this._rows.some((r) => r.closesSale === true && r.payRoute === "TERMINAL")
    );
  }

  get holdLive() {
    return Number(this.holdSecondsLeft) > 0;
  }

  /** Three situations; a lapsed hold with a payment against it is still reserved (journey 07). */
  get holdText() {
    if (this.holdLive) return LABELS.LEDGER_HOLD_LIVE;
    return this.hasCollected ? LABELS.LEDGER_HOLD_SAFE : LABELS.LEDGER_HOLD_GONE;
  }

  /* the chips the rows already use */
  get holdClass() {
    if (this.holdLive) return "chip chip--due grp__hold";
    return this.hasCollected
      ? "chip chip--paid grp__hold"
      : "chip chip--alert grp__hold";
  }

  /** Said in full, once. */
  get showReservedNote() {
    return this.showHold && !this.holdLive && this.hasCollected;
  }

  /* `scheduledCount` and `scheduledCountClass` are gone; groupByUnit says it per unit.
     An overdue milestone is not a future one (isOverdue). */

  /** Past its date with money still on it. Date-only. Body in c/mscPaymentFacts. */
  isOverdue(row) {
    return factIsOverdue(row);
  }

  /* `scheduledTotal` and `scheduledSummary` are gone; each card states its own figure */

  /* rows */

  /* body in c/mscPaymentFacts; the method stays for its call sites */
  remainingOf(row) {
    return factRemainingOf(row);
  }

  /* statusKeyFor moved to c/mscPaymentFacts (statusKeyOf / statusOf) */

  decorate(list) {
    return list.map((row) => {
      const remaining = this.remainingOf(row);
      const required = Number(row.requiredAmount || 0);
      const paid = Number(row.paidAmount || 0);
      /* the state and what is still due, from the functions the modal reads */
      const status = factStatusOf(row, this.settlement);
      const stillDue = factStillDueOf(row);
      const open = this.openId === row.sourceId;
      // said on the row as well as the heading
      const overdue = this.isOverdue(row);

      /* the hero is the number the agent is about to act on */
      const primary = remaining > 0 ? formatAED(remaining) : formatAED(paid);

      /* one supporting line, only once part of the money has landed */
      let secondary = null;
      if (remaining > 0 && paid > 0) {
        secondary = LABELS.LEDGER_OF_PAID.replace("{0}", formatAED(required)).replace(
          "{1}",
          formatAED(paid)
        );
      } else if (row.dueDate && remaining <= 0) {
        secondary = LABELS.LEDGER_DUE.replace("{0}", formatDate(row.dueDate));
      }

      /* where this row's money comes from; only the pay-first fee needs saying (by link or terminal) */
      const routeNote =
        row.payRoute === "TERMINAL"
          ? row.payByLink === true
            ? LABELS.ROW_ROUTE_LINK
            : LABELS.ROW_ROUTE_TERMINAL
          : null;

      const out = {
        ...row,
        open,
        routeNote,
        rowClass: open ? "oblig oblig--open" : "oblig",
        chipClass: status.chipClass,
        chipText: status.text,
        dotClass: status.dotClass,
        primary,
        primaryClass: remaining > 0 ? "oblig__amt oblig__amt--owed" : "oblig__amt",
        secondary,
        /* the unit is the group heading, not a row label */
        dueLabel: row.dueDate && remaining > 0 ? formatDate(row.dueDate) : null,
        dueClass: overdue ? "oblig__due oblig__due--late" : "oblig__due",
        overdue,
        overdueText: LABELS.LEDGER_ROW_OVERDUE,
        chevron: open ? "chevron-up" : "chevron-down",
        ariaExpanded: open ? "true" : "false",
        showForm: open,
        /* the row's named control; one fact decides its label: is anything still due (stillDueOf
           is the server's openAmount with a live payment, remainingAmount otherwise) */
        actionLabel: stillDue > 0 ? LABELS.CTA_RECORD_PAYMENT : LABELS.CTA_VIEW_PAYMENT,
        actionClass: stillDue > 0 ? "btn btn-ghost btn-sm led__go" : "btn btn-ghost btn-sm",
        result: this.resultFor(row)
      };
      /* a payment with Finance covers (part of) this row */
      this.decorateCovered(out, row, remaining);
      /* the table's money columns, after decorateCovered; stillDue handed over, not re-derived */
      this.decorateColumns(out, row, stillDue);
      return out;
    });
  }

  /** The page's answer to the last Create Payment, if it was about this row. */
  resultFor(row) {
    const r = this.proofResult;
    return r && row && r.sourceId === row.sourceId ? { ok: r.ok === true, message: r.message } : null;
  }

  /** The with-Finance state of a lead row: chip, sub-line, cards, and the form for what is still open. */
  decorateCovered(out, row, remaining) {
    const live = (row.instruments || []).filter((i) => i && i.live === true);
    if (!live.length || remaining <= 0) return;
    const openAmount = Number(row.openAmount || 0);
    /* the chip, the dot and the action label are set in c/mscPaymentFacts.statusOf now; what is
       left here is what the list branch draws */
    const first = live[0];
    if (live.length === 1) {
      out.instrumentSub = first.mode === "Cheque"
        ? LABELS.ROW_CHEQUE_SUB.replace("{0}", first.reference || "").replace(
            "{1}",
            first.instrumentDate ? formatDate(first.instrumentDate) : ""
          )
        : LABELS.ROW_PAY_SUB.replace("{0}", first.mode || "")
            .replace("{1}", first.reference || "")
            .replace("{2}", first.instrumentDate ? formatDate(first.instrumentDate) : "");
    } else {
      out.instrumentSub = LABELS.ROW_PAYS_SUB.replace("{0}", live.length).replace(
        "{1}",
        formatAED(live.reduce((sum, i) => sum + Number(i.amount || 0), 0))
      );
    }
    /* `out.open`, not `row.open`: the raw row has no open flag */
    const open = out.open === true;
    out.showCards = open;
    out.cards = live.map((i) => this.cardFor(i));
    if (openAmount > 0) {
      /* said on the collapsed row too */
      out.instrumentSub = `${out.instrumentSub} · ${LABELS.ROW_PAY_SUB_OPEN.replace("{0}", formatAED(openAmount))}`;
      out.stillOpen = LABELS.ROW_PAY_STILL_OPEN.replace("{0}", formatAED(openAmount));
      out.showForm = open;
    } else {
      out.coveredNote = open ? LABELS.ROW_PAY_COVERED : null;
      out.showForm = false;
    }
  }

  /* the table's dress: Total (requiredAmount) and Pending (the server's figure: openAmount with a
   * live payment, remainingAmount otherwise), figure then keyword. States, in order tested:
   *   stillDue > 0          {figure} pending     amber   Record payment
   *   requiredAmount = 0    Nothing due          grey    View payment
   *   remaining <= 0        Settled              green   View payment
   *   otherwise             No amount pending    grey    View payment
   * Money decides, not the settlement leg. The oblig list rows never read these fields. */
  decorateColumns(out, row, stillDue) {
    const required = Number(row.requiredAmount || 0);
    const remaining = this.remainingOf(row);

    /* the post-Confirm settling window: the closing rows, and 3.11 the due-now rows the fee is being allocated to */
    const settlingRow = row.closesSale === true || (this.confirmed === true && !this.isBoxRow(row));
    if (this.finalising === true && settlingRow && stillDue > 0) {
      out.colTotal = bareAED(required);
      out.pendValue = LABELS.LED_FINALISING;
      out.pendValueClass = "led__pend-amt led__pend-amt--wait";
      out.pendWord = null;
      out.pendClass = "dot dot--pend";
      return;
    }

    /* one font size for every figure; weight and colour carry the difference */
    out.colTotal = bareAED(required);

    if (stillDue > 0) {
      out.pendValue = bareAED(stillDue);
      out.pendValueClass = "led__pend-amt";
      out.pendWord = LABELS.LED_PENDING_WORD;
      out.pendClass = "dot dot--pend";
    } else if (required <= 0) {
      /* nothing was ever charged on this leg (a waived ADM charge) */
      out.pendValue = LABELS.SETTLE_LEG_NONE;
      out.pendValueClass = "led__pend-txt";
      out.pendWord = null;
      out.pendClass = "dot";
    } else if (remaining <= 0) {
      out.pendValue = LABELS.SETTLE_DONE;
      out.pendValueClass = "led__pend-txt";
      out.pendWord = null;
      out.pendClass = "dot dot--done";
    } else {
      out.pendValue = LABELS.LED_NONE_PENDING;
      out.pendValueClass = "led__pend-txt";
      out.pendWord = null;
      out.pendClass = "dot";
    }

    /* the name column: what the payment is and when it is due */
    out.dueLine = row.dueDate
      ? LABELS.LED_ROW_DUE.replace("{0}", formatDate(row.dueDate))
      : null;
    /* dueLineClass retired: the date is grey either way; `overdue` stays */

    /* ilines / paidLine / sdLine / frmClass left with the inline panel */
  }

  /* the milestone box */

  /** A milestone after the down payment. */
  /* the number test moved to c/mscPaymentFacts, which c/mscBookingPage reads too. closesSale is
     composed here exactly as the page composes it, so a closing row is a table row for openRowOn. */
  isBoxRow(row) {
    return !!row && row.closesSale !== true && factIsScheduledMilestone(row);
  }

  batchFor(salesOrderId) {
    const b = this._batch || {};
    return salesOrderId ? b[salesOrderId] : undefined;
  }

  /** A row opened by id may sit inside a collapsed unit; open that unit. Any scheduled row. */
  revealScheduledUnit(sourceId) {
    const row = this._rows.find((r) => r.sourceId === sourceId);
    if (!row || row.closesSale === true || !row.salesOrderId) return;
    this.boxOpen = { ...this.boxOpen, [row.salesOrderId]: true };
  }

  rangeOf(rows) {
    const nums = rows.map((r) => Number(r.milestoneNumber)).filter((n) => !Number.isNaN(n));
    if (!nums.length) return null;
    return { first: Math.min(...nums), last: Math.max(...nums) };
  }

  rangeText(range, many, one) {
    if (!range) return "";
    return range.first === range.last
      ? one.replace("{0}", range.first)
      : many.replace("{0}", range.first).replace("{1}", range.last);
  }

  /** "milestones 5 to 7 still open" / "milestone 5 still open" / "3 milestones still open". */
  stillOpenText(openNums) {
    if (!openNums.length) return LABELS.BOX_ALL_COVERED;
    if (openNums.length === 1) return LABELS.BOX_STILL_OPEN_ONE.replace("{0}", openNums[0]);
    const sorted = openNums.slice().sort((a, b) => a - b);
    const contiguous = sorted[sorted.length - 1] - sorted[0] === sorted.length - 1;
    return contiguous
      ? LABELS.BOX_STILL_OPEN.replace("{0}", sorted[0]).replace("{1}", sorted[sorted.length - 1])
      : LABELS.BOX_STILL_OPEN_SOME.replace("{0}", sorted.length);
  }

  /** The card line's model: what covers this unit's milestones, in one chip and one sentence. */
  buildBox(salesOrderId, boxRows) {
    const batch = this.batchFor(salesOrderId) || null;
    const dd = batch && batch.dd ? batch.dd : null;
    const range = this.rangeOf(boxRows);
    const rangeLabel = this.rangeText(range, LABELS.BOX_RANGE, LABELS.BOX_RANGE_ONE);
    const left = boxRows.reduce((sum, r) => sum + this.remainingOf(r), 0);
    const overdue = boxRows.filter((r) => r.overdue).length;
    const overdueWord =
      overdue === 0
        ? null
        : overdue === 1
          ? LABELS.LEDGER_OVERDUE_ONE
          : LABELS.LEDGER_OVERDUE.replace("{0}", overdue);

    const liveCount = batch ? Number(batch.liveChequeCount || 0) : 0;
    const ddCovering = !!(dd && dd.covering);
    const ddStands = !!(dd && dd.mandateId);
    /* NaN is dropped: a milestone with no number can sit in this box */
    const openNums = boxRows
      .filter((r) => this.remainingOf(r) > 0 && Number(r.openAmount || 0) > 0)
      .map((r) => Number(r.milestoneNumber))
      .filter((n) => !Number.isNaN(n));

    let chip = null;
    let summary;
    if (ddCovering) {
      chip = {
        cls: dd.coversMilestones ? "chip chip--paid" : "chip chip--partial",
        text: LABELS.BOX_DD_STATUS.replace("{0}", dd.mandateStatusLabel || "")
      };
      /* 3.8: the open mandate names its stage (with Finance, awaiting signature, with the bank) */
      const tpl = dd.coversMilestones
        ? LABELS.BOX_DD_LINE_ACTIVE
        : LABELS.BOX_DD_LINE.replace("{2}", dd.mandateStatusLabel || "");
      /* 21 Sep 2026: an active mandate collects the milestones not yet Paid - the very rule the
         mandate card's "Covers milestones 3 to 7" comes from (ddComputedFor: PaymentStatus__c !=
         'Paid'). The box's whole range counted a settled milestone, and "still open" would drop
         one covered by a cheque that has not cleared, so either way the two lines disagreed. */
      const notPaid = boxRows
        .filter((r) => String(r.status || "") !== "Paid")
        .map((r) => Number(r.milestoneNumber))
        .filter((n) => !Number.isNaN(n));
      const collecting =
        dd.coversMilestones && notPaid.length
          ? { first: Math.min(...notPaid), last: Math.max(...notPaid) }
          : range;
      summary = this.rangeText(collecting, tpl, tpl);
    } else if (ddStands) {
      /* 3.8: rejected, discarded or cancelled - the label says which */
      chip = { cls: "chip chip--alert", text: LABELS.BOX_DD_STATUS.replace("{0}", dd.mandateStatusLabel || "") };
      summary = LABELS.BOX_DD_LINE_REJECTED.replace("{0}", dd.mandateStatusLabel || "");
    } else if (liveCount > 0) {
      /* no "Paying by cheque" pill; the sentence already says it */
      const withFinance =
        liveCount === 1
          ? LABELS.BOX_CHEQUE_WITH_FINANCE
          : LABELS.BOX_CHEQUES_WITH_FINANCE.replace("{0}", liveCount);
      summary = `${withFinance} · ${this.stillOpenText(openNums)}`;
    } else if (left <= 0) {
      /* the figure already reads "Settled" */
      summary = rangeLabel;
    } else {
      summary = [rangeLabel, overdueWord, LABELS.BOX_NONE_COVERED]
        .filter((x) => !!x)
        .join(" · ");
    }
    return { chip, summary };
  }

  /* `decorateBoxed` moved to c/mscMilestoneModal */

  /** Lead rows only now. */
  cardFor(i) {
    const date = i.instrumentDate ? formatDate(i.instrumentDate) : "";
    const amount = formatAED(i.amount);
    let text;
    if (i.mode !== "Cheque") {
      /* a bank transfer / POS / online payment: Modon's mode word leads */
      text = LABELS.ROW_PAY_CARD.replace("{0}", i.mode || "")
        .replace("{1}", i.reference || "")
        .replace("{2}", date)
        .replace("{3}", amount)
        .replace("{4}", i.receiptName || "");
    } else {
      text = (i.bank ? LABELS.ROW_PAY_CARD_CHEQUE : LABELS.ROW_CHEQUE_CARD_NOBANK)
        .replace("{0}", i.reference || "")
        .replace("{1}", date)
        .replace("{2}", amount)
        .replace("{3}", i.bank ? i.bank : i.receiptName || "")
        .replace("{4}", i.receiptName || "");
    }
    const meta = [];
    if (i.recordedOn) {
      meta.push(
        LABELS.ROW_CHEQUE_CARD_RECORDED.replace("{0}", formatDate(i.recordedOn)).replace(
          "{1}",
          i.recordedBy || ""
        )
      );
    }
    if (i.status && i.status !== "In Progress") {
      meta.push(LABELS.ROW_CHEQUE_CARD_STATUS.replace("{0}", i.receiptName || "").replace("{1}", i.status));
    }
    if (Number(i.fileCount) > 1) {
      meta.push(LABELS.ROW_PAY_FILES.replace("{0}", i.fileCount));
    } else if (i.fileName) {
      meta.push(i.fileName);
    }
    return {
      key: i.receiptId,
      text,
      meta: meta.join(" · "),
      /* MSC-197: what the image said about this cheque, once somebody has read it */
      ocr: this.ocrLineFor(i),
      thumb: i.contentVersionId
        ? `${basePath}/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB120BY90&versionId=${i.contentVersionId}`
        : null,
      fileName: i.fileName,
      hasImage: !!i.contentDocumentId
      /* a lead row's card is followed by its form or the covered line */
    };
  }

  /**
   * MSC-197: the read that was written onto the cheque record - a line under the card, an amber
   * tone when it disagrees with what was recorded, and Retry when the read itself failed.
   * Silent on anything but a cheque, and on a cheque nobody has read.
   */
  ocrLineFor(i) {
    if (!i || i.mode !== "Cheque" || !i.chequeDetailsId) return null;
    const status = i.ocrStatus;
    if (!status || status === "Not Attempted") return null;
    if (status === "Processing") {
      return { text: LABELS.ROW_PAY_OCR_WAIT, cls: "oblig__ocr", canRetry: false, id: i.chequeDetailsId };
    }
    if (status === "Failed") {
      return {
        text: i.ocrError || LABELS.ROW_PAY_OCR_FAILED,
        cls: "oblig__ocr oblig__ocr--bad",
        canRetry: true,
        id: i.chequeDetailsId
      };
    }
    const parts = [];
    if (i.ocrChequeNumber) parts.push(i.ocrChequeNumber);
    if (i.ocrChequeDate) parts.push(formatDate(i.ocrChequeDate));
    if (i.ocrAmount !== null && i.ocrAmount !== undefined) parts.push(formatAED(i.ocrAmount));
    if (i.ocrBank) parts.push(i.ocrBank);
    if (!parts.length) return null;
    const tpl = i.ocrMismatch ? LABELS.ROW_PAY_OCR_DIFF : LABELS.ROW_PAY_OCR;
    return {
      text: tpl.replace("{0}", parts.join(" · ")),
      cls: i.ocrMismatch ? "oblig__ocr oblig__ocr--warn" : "oblig__ocr",
      canRetry: false,
      id: i.chequeDetailsId
    };
  }

  /** One more attempt at a read that failed; the ledger reloads when it is done. */
  async handleRetryRead(event) {
    const id = event.currentTarget.dataset.id;
    if (!id || this.retrying) return;
    this.retrying = true;
    try {
      await retryRead({ chequeId: id });
      /* the read runs off this transaction: the record is already 'Processing', so a reload of
         the ledger is what turns this line into the answer */
      this.dispatchEvent(new CustomEvent("refreshledger"));
    } catch (e) {
      /* a read is a convenience - a failed retry says nothing louder than the line already does */
    }
    this.retrying = false;
  }

  /** MSC-197: guards a double press on Retry. */
  retrying = false;

  handleThumbError(event) {
    // no rendition yet (or a PDF): the file icon stands in
    event.target.classList.add("oblig__thumb--gone");
  }

  /* of the box handlers only the fold toggle remains; the rest moved to c/mscMilestoneModal */

  handleBoxToggle(event) {
    const so = event.currentTarget.dataset.so || "_";
    this.boxOpen = { ...this.boxOpen, [so]: !this.boxOpen[so] };
  }

  /** The line's one action post-Confirm: the page opens c/mscMilestoneModal on this unit. */
  handleManageMilestones(event) {
    const so = event.currentTarget.dataset.so;
    this.dispatchEvent(new CustomEvent("managemilestones", { detail: { salesOrderId: so } }));
  }

  /* one open at a time */

  /** Which surface a row opens on: a table row opens c/mscPaymentModal; a list row expands in place. */
  isTableRow(row) {
    if (!row) return false;
    if (row.closesSale === true) return true;
    return this.confirmed === true && !this.isBoxRow(row);
  }

  /** Open a row wherever it lives. The one place that decides. */
  openRowOn(row) {
    if (!row) return false;
    if (this.confirmed === true && this.isBoxRow(row)) {
      /* a post-Confirm milestone lives in c/mscMilestoneModal */
      this.dispatchEvent(
        new CustomEvent("openmilestones", {
          detail: { salesOrderId: row.salesOrderId, sourceId: row.sourceId }
        })
      );
      return true;
    }
    if (this.isTableRow(row)) {
      this.dispatchEvent(
        new CustomEvent("openpayment", {
          detail: { sourceId: row.sourceId, salesOrderId: row.salesOrderId }
        })
      );
      return true;
    }
    this.openId = row.sourceId;
    this.revealScheduledUnit(row.sourceId);
    return true;
  }

  handleRowToggle(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    this._advanceAfterRefresh = false;
    const row = this._rows.find((r) => r.sourceId === id);
    if (this.isTableRow(row)) {
      /* a table row is a button that opens a modal; nothing to toggle shut */
      this.openRowOn(row);
      return;
    }
    /* toggling to the same row closes it; the single assignment is the rule */
    this.openId = this.openId === id ? undefined : id;
  }

  /** The open row survives a refresh, unless it is finished (then it hands over to the next). */
  reconcileOpenRow() {
    if (this._advanceAfterRefresh) {
      this._advanceAfterRefresh = false;
      const next = this.nextOutstandingAfter(this.openId);
      /* the advance closes the row it came from, then opens the next one where it lives */
      this.openId = undefined;
      const row = next ? this._rows.find((r) => r.sourceId === next) : undefined;
      if (row) {
        this.focusUnitFor(next);
        this.openRowOn(row);
      }
      return;
    }
    if (this.openId && !this._rows.some((r) => r.sourceId === this.openId)) {
      this.openId = undefined;
    }
  }

  /** Closing rows first, then scheduled; never a post-Confirm boxed milestone. */
  nextOutstandingAfter(currentId) {
    const ordered = [
      ...this._rows.filter((r) => r.closesSale === true),
      ...this._rows.filter((r) => r.closesSale !== true)
    ];
    const outstanding = ordered.filter(
      (r) =>
        this.remainingOf(r) > 0 &&
        r.sourceId !== currentId &&
        !(this.confirmed === true && this.isBoxRow(r))
    );
    return outstanding.length ? outstanding[0].sourceId : undefined;
  }

  /* events: mscPaymentBlock's events do not cross the shadow boundary, so each is re-raised with
     its detail intact */

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
    /* arm the advance before relaying; not when the submit records a payment (the row stays open) */
    const d = (event && event.detail) || {};
    this._advanceAfterRefresh = d.recordsPayment !== true;
    this.relay(event);
  }
  handleSetupDirectDebit(event) {
    this.relay(event);
  }
}