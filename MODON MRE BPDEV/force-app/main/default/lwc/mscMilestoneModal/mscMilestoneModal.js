/**
 * The milestone modal - the schedule, both arrangements and every panel, off the card.
 *
 * Version  Author      Date         Detail
 * 1.12     Aurelix Dev 30 Sep 2026  A milestone with no number shows an empty badge, not a dash.
 * 1.11     Aurelix Dev 18 Sep 2026  SCW-125. The mandate is drawn by c/mscMandateCard behind View
 *                                   mandate (the form component lost its view mode); the foot names
 *                                   the mandate's UAEDDS stage, or says why Direct Debit is not
 *                                   offered (batch.directDebitReason); ddchanged from the card is
 *                                   re-raised with the Sales Order so the page reloads the box;
 *                                   ddsetup (Set up again after a discarded / rejected / cancelled
 *                                   mandate) opens the form.
 * 1.10     Aurelix Dev 21 Aug 2026  MSC-103. The pending column aligns. Its word sat in
 *                                   a FIXED 52px slot, left-aligned inside it, which is
 *                                   why a row reading "No amount pending" ended about
 *                                   16px right of a row reading "816,465.18 pending":
 *                                   the wordless states had no slot to sit in front of.
 *                                   The slot was inherited from the column this
 *                                   replaced, which carried TWO words of different
 *                                   widths ("recorded" / "paid") and needed one edge
 *                                   holding them. There is one word now, so its width
 *                                   is constant and the slot is not only unnecessary -
 *                                   it was the misalignment. Removed: every figure
 *                                   shares a right edge because the suffix is always
 *                                   the same word, and every line ends on the column
 *                                   edge, level with the year captions above them. The
 *                                   figure also takes the total column size and weight
 *                                   so the two money columns read as one system, as
 *                                   they do on the ledger outside.
 * 1.9      Aurelix Dev 21 Aug 2026  MSC-101b. The number badge binds `num`: a
 *                                   milestone can reach this list with no number at all
 *                                   (a single-installment plan whose MilestoneNumber__c
 *                                   is null), and an en dash keeps the badge shape
 *                                   where an empty span would leave a hole in the grid.
 * 1.8      Aurelix Dev 21 Aug 2026  MSC-101. The row states what is still PENDING on
 *                                   the milestone instead of what has been recorded,
 *                                   the shape the ledger row outside took in MSC-100.
 *                                   Inside a twelve-row schedule the swap does what it
 *                                   could not do outside: the work was the BLANK cells
 *                                   (a plan with nothing collected showed nothing at
 *                                   all), and it is the amber ones now. The due date
 *                                   folds under the name and the AED prefix goes, so
 *                                   six columns become five and the figures line up.
 *                                   The figure is c/mscPaymentFacts stillDueOf - this
 *                                   modal was the last surface deriving these facts
 *                                   itself, so a milestone could disagree with its own
 *                                   panel; it cannot now. A mandate-covered row still
 *                                   draws NOTHING in the column and keeps its green
 *                                   badge: the bank collects when due, so a figure
 *                                   there would read as a rep's work. The row wrapper,
 *                                   its key, data-exp and handleRowToggle are NOT
 *                                   touched - that is the 1.6 fix.
 * 1.7      Aurelix Dev 21 Aug 2026  No pill on the row, by request: what stands against a
 *                                   milestone is said by the recorded figure beside it
 *                                   and by the number badge's tone, and the pill was a
 *                                   third telling of the same fact. `tag` reduces to the
 *                                   one thing still read from it - that tone - so no dead
 *                                   text or class strings are built. In the expanded
 *                                   panel the two figures swap roles: a payment's amount
 *                                   is money HANDED OVER and wears the with-Finance blue,
 *                                   the remainder below it is the work left and takes the
 *                                   white weight the row's own total has.
 * 1.6      Aurelix Dev 21 Aug 2026  MSC-099b. TWO PANELS ON SCREEN, ONE OF THEM SHOWING
 *                                   ANOTHER ROW'S PAYMENTS - and the server was innocent
 *                                   (audited: Milestone 2 carried R-113966 alone,
 *                                   Milestone 3 R-113967 alone, no receipt on two rows).
 *                                   The row and its panel were two SIBLINGS inside the
 *                                   same for:each, so expanding a row INSERTED a node
 *                                   into the body's child list and collapsing it removed
 *                                   one; the list changed shape on every click and a
 *                                   panel could be left behind or patched with the next
 *                                   row's content. The panel now lives INSIDE the row's
 *                                   own keyed node: the list's shape no longer changes
 *                                   when a row opens, and a panel cannot outlive the row
 *                                   that owns it. One keyed node per row, one panel
 *                                   possible, by structure. Visually identical - a plain
 *                                   block wrapper around a full-width row.
 * 1.5      Aurelix Dev 21 Aug 2026  MSC-099a. THE WRONG ROW OPENED - and the cause is
 *                                   property ORDER, not rendering. `open` is the first
 *                                   attribute on the host's tag and focus-row-id the
 *                                   last; LWC assigns properties in template order, so
 *                                   applyFocusTarget(), called from the `open` setter,
 *                                   always read the PREVIOUS deep link. The modal
 *                                   opened expanded on the row asked for LAST time, the
 *                                   row asked for this time was neither expanded nor
 *                                   scrolled to, and "Manage milestone payments" -
 *                                   which clears the focus row - inherited a stale one
 *                                   the same way. It also returned early on a missing
 *                                   id WITHOUT clearing, so an expansion outlived the
 *                                   open that made it.
 *
 *                                   Now: the focus props are accessors that apply the
 *                                   target themselves, so the host's LAST write wins
 *                                   whatever order it assigns in; applyFocusTarget
 *                                   states the expansion on every path (including "no
 *                                   focus row" and "row not found"); a fresh open
 *                                   starts with nothing expanded; `rows` is an accessor
 *                                   that retires an expansion the new data no longer
 *                                   supports (a cheque Finance has allocated leaves its
 *                                   milestone with nothing to open onto); one shared
 *                                   expandableRow() decides what "opens onto something"
 *                                   means for the chevron, the deep link and that
 *                                   reconcile alike; and yearGroups takes the open row
 *                                   through a LATCH, so a repeated sourceId can no
 *                                   longer draw two panels of the same content. Line
 *                                   keys carry their index for the same reason.
 *                                   No UI, no copy and no styling changed.
 * 1.4      Aurelix Dev 21 Aug 2026  One quiet word after the recorded figure -
 *                                   "recorded" (blue, with Finance) or "paid"
 *                                   (green, allocated) - in small dim type. The
 *                                   blue is a brand colour and carries less
 *                                   meaning than the amber it replaced; the word
 *                                   names the number where the question arises.
 * 1.3      Aurelix Dev 21 Aug 2026  The line is the PAYMENT: "Payment R-113964",
 *                                   the submitted date, the status chip, the
 *                                   amount. Nothing else, by request.
 * 1.2      Aurelix Dev 21 Aug 2026  The instrument line's identity run stops at the
 *                                   date - bank · cheque date, nothing after. The
 *                                   Payment reference, recorded-when/by and the file
 *                                   count live on the Payment where Finance reads
 *                                   them; here they were noise beside the number.
 * 1.1      Aurelix Dev 21 Aug 2026  MSC-097a. THE COVERED ROW, SAID IN NUMBERS. The
 *                                   collapsed row is one line, always: the cheque
 *                                   identity sub-line and the Direct Debit sub-line
 *                                   come off, and a RECORDED column joins the grid -
 *                                   the sum of the instruments standing against the
 *                                   row in amber, the paid figure in green, empty
 *                                   when nothing does (the gap IS the information).
 *                                   The total holds the right edge, constant. The
 *                                   expanded view drops the card, the image and the
 *                                   prose for a LEDGER FRAGMENT: one line per
 *                                   instrument (id · status chip · one dim identity
 *                                   run · amount) and a still-open line in the amber
 *                                   of the recorded figure it completes. Every fact
 *                                   from the old paragraph survives as a shorter
 *                                   part; the "no form here" disclaimer does not - a
 *                                   panel that asks for nothing shows nothing.
 * 1.0      Aurelix Dev 21 Aug 2026  Initial. MSC-097. Milestones 2..n are money due in
 *                                   future years - a schedule to ARRANGE, not a queue to
 *                                   work - and they occupied more of Payment & Confirm
 *                                   than the payments due today did. The card keeps one
 *                                   line and one button; this modal holds the schedule
 *                                   (grouped by year, folding past twelve milestones),
 *                                   the two arrangements, and the three panels exactly
 *                                   as the card hosted them: c/mscChequeSheet and
 *                                   c/mscDirectDebit are rehosted UNCHANGED.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHERE THIS MUST BE MOUNTED. At mscBookingPage's `.page`, beside
 * c-msc-owners-drawer, and NEVER inside a card: every card carries
 * backdrop-filter, which makes it the containing block for position: fixed, so a
 * modal rendered inside one becomes a pane inside that card. c/mscDrawer's header
 * records the day that was learned; this component simply obeys it.
 *
 * A GUEST ON ANY SCREEN. Nothing here knows about the booking journey: every fact
 * arrives through @api and every act leaves as an event, so the Sales Order screen
 * (or any other host) can mount this with the same contract -
 *   in:  rows (scheduled milestone PaymentBucketDTOs, milestoneNumber > 1),
 *        batch ({salesOrderId: MilestoneBatchDTO}), bookedUnits
 *        ([{salesOrderId, bookingRef}]), multiUnit, busy, chequeResult/chequeError,
 *        open, focusSalesOrderId, focusRowId
 *   out: close · chequesubmit · ddcreate (details carry salesOrderId)
 *   api: closePanels(salesOrderId) after a recorded batch
 * The host owns the Apex calls; this draws and asks, nothing more.
 *
 * WHAT IT KNOWS AND WHAT IT DOES NOT. It is handed the raw scheduled milestone
 * buckets, the milestone batch per Sales Order, and the booked units - and it
 * derives everything it draws from those. It decides NOTHING about what may be
 * offered: chequesAllowed / directDebitAllowed / dd.covering are the server's
 * answers, read as-is. It re-raises chequesubmit and ddcreate with the exact
 * detail shapes the page already handles, so nothing behind a submit moved.
 *
 * NO FIGURE IN THE HEAD, NO SUBTOTALS ON THE YEARS - by request. The card's line
 * is the only place the schedule's total is stated; the head carries a STATE
 * (nothing arranged / cheques x of n / the mandate's status), and a folded year
 * says its coverage in words. Folding is a reading device, not a performance one:
 * nothing is paged, nothing is virtualised, and every row of an opened year
 * renders.
 * ─────────────────────────────────────────────────────────────────────────────
 */
import { LightningElement, api, track } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
/* 1.8 - the ledger row and the payment popup have read these since MSC-099; this
   modal derived its own answers until now, which is how a milestone could say one
   thing in the list and another in the panel under it. */
import { stillDueOf as factStillDueOf } from "c/mscPaymentFacts";

/* 1.8 - the figure without the currency word, as c/mscObligations 2.5 draws it. The
   modal head names the money once; AED on both figures of twelve rows was two thirds
   of the schedule's ink and stopped the columns lining up. */
function bareAED(v) {
  return formatAED(v).replace(/^AED\s/, "");
}

/** How long the modal stays in the DOM after close, so the exit can play.
    MUST match the exit durations in the CSS (.layer--closing). */
const EXIT_MS = 200;

/** Past this many milestones the years fold to one line each. Under it a plan
    never asks for a click - a six-row schedule should simply be on screen. */
const FOLD_AT = 12;

const MODES = { ROWS: "rows", CHEQUES: "cheques", DD: "dd", VIEW: "view" };

export default class MscMilestoneModal extends LightningElement {
  /* ── inputs ─────────────────────────────────────────────────────────────── */

  /** Raw scheduled milestone buckets (milestoneNumber > 1), every unit's. */
  /* 1.4 - an accessor, so a reload can retire an expansion the new data no longer
     supports: a cheque that Finance allocated leaves its milestone with nothing to
     expand, and an id left pointing at it is a row that opens onto nothing. */
  @api
  get rows() {
    return this._rows;
  }
  set rows(value) {
    this._rows = value || [];
    this.reconcileExpanded();
  }
  _rows = [];
  /** { [salesOrderId]: SalesConsoleController.MilestoneBatchDTO } */
  @api
  get batch() {
    return this._batch;
  }
  set batch(value) {
    this._batch = value || {};
    this.reconcile();
  }
  _batch = {};
  /** ConsoleState.bookedUnits - the Sales Order reference beside the unit name. */
  @api bookedUnits = [];
  /** True on a basket; draws the unit rail. */
  @api multiUnit = false;
  @api busy = false;
  /** The page's answers to the last cheque batch, handed straight to the sheet. */
  @api chequeResult;
  @api chequeError;
  /** Which unit to land on when opened, and (deep link) which row to reveal. */
  /* 1.4 - ROOT CAUSE OF THE WRONG ROW OPENING (MSC-099a).
     These were plain fields, and `open` - the FIRST attribute on the host's tag -
     called applyFocusTarget() in its setter. LWC assigns properties in template
     order, so at that moment focusRowId still held the PREVIOUS deep link's value:
     the modal opened expanded on the row asked for last time, and the row asked for
     this time was neither expanded nor scrolled to. Pressing "Manage milestone
     payments" (which clears the focus row) opened it on a stale row for the same
     reason. Applying the target from these setters as well means the last write
     wins, whatever order the host assigns in. */
  @api
  get focusSalesOrderId() {
    return this._focusSalesOrderId;
  }
  set focusSalesOrderId(value) {
    this._focusSalesOrderId = value || undefined;
    this.applyFocusTarget();
  }
  _focusSalesOrderId;

  @api
  get focusRowId() {
    return this._focusRowId;
  }
  set focusRowId(value) {
    this._focusRowId = value || undefined;
    this.applyFocusTarget();
  }
  _focusRowId;

  /**
   * Open lags closed by EXIT_MS so the exit can animate - the same accessor
   * c/mscDrawer uses, for the same reason: `open` alone unmounts the markup on
   * the frame it goes false, which gives the exit nothing to play.
   */
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
      /* 1.4 - a fresh open starts with NOTHING expanded, then the focus target (if
         the host set one) says what should be. applyFocusTarget runs after _open is
         true because it refuses to act on a closed modal, and it runs again from
         each focus setter - whichever the host assigns last wins, which is the
         whole fix: `open` is the first attribute on the tag and focus-row-id the
         last, so this setter alone always read the PREVIOUS deep link. */
      this.expandedRow = undefined;
      this._scrollTo = undefined;
      this.applyFocusTarget();
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
      /* A fresh open starts on the schedule, not on a half-abandoned panel, and
         with the fold state re-derived - "reopening returns to the schedule". */
      this.modeBySo = {};
      this.openYearsBySo = {};
      this.filterBySo = {};
      this.expandedRow = undefined;
    }, EXIT_MS);
  }

  /**
   * The page calls this once a cheque batch has been recorded: the sheet gives
   * way to the schedule IN THE MODAL, so the rep watches the tags land.
   */
  @api
  closePanels(salesOrderId) {
    const keys = salesOrderId ? [salesOrderId] : Object.keys(this.modeBySo);
    keys.forEach((k) => {
      this.modeBySo = { ...this.modeBySo, [k]: MODES.ROWS };
    });
  }

  labels = LABELS;

  /* ── state, all keyed by Sales Order id ─────────────────────────────────── */

  /** rows | cheques | dd | view - what the body is showing for that unit. */
  @track modeBySo = {};
  /** { [so]: { [yearKey]: true } }. Absent = the default: the first year with an
      uncovered milestone open, the rest folded. */
  @track openYearsBySo = {};
  /** all | open | covered. Only read when the plan is long enough to fold. */
  @track filterBySo = {};
  /** The selected unit on a basket. Resolved against the live list in unitKey. */
  _selectedSo;
  /** The one expanded covered row - its cheque cards, one at a time. */
  expandedRow;
  /** Row to scroll to after a deep-linked open, cleared once done. */
  _scrollTo;
  _focusedOnOpen = false;
  _previousFocus = null;

  /* ── the fold: units ────────────────────────────────────────────────────── */

  get unitList() {
    const bySo = new Map();
    (this.rows || []).forEach((r) => {
      const so = r.salesOrderId || "_";
      let u = bySo.get(so);
      if (!u) {
        u = { soId: so, name: r.unitName || LABELS.LEDGER_UNIT_UNNAMED, rows: [] };
        bySo.set(so, u);
      }
      u.rows.push(r);
    });
    return Array.from(bySo.values()).map((u) => {
      const batch = this._batch[u.soId] || null;
      const dd = batch && batch.dd ? batch.dd : null;
      const derived = u.rows.map((r) => this.deriveRow(r, dd));
      const covered = derived.filter((d) => d.isCovered).length;
      const open = derived.filter((d) => d.isOpen).length;
      const left = derived.reduce((s, d) => s + d.remaining, 0);
      return { ...u, batch, dd, derived, covered, open, left, ref: this.refFor(u.soId) };
    });
  }

  refFor(salesOrderId) {
    const hit = (this.bookedUnits || []).find((b) => b && b.salesOrderId === salesOrderId);
    return hit ? hit.bookingRef : null;
  }

  /** The selected unit - the focused one, else whatever still exists. */
  get unit() {
    const list = this.unitList;
    if (!list.length) {
      return null;
    }
    const want = this._selectedSo || this.focusSalesOrderId;
    return list.find((u) => u.soId === want) || list[0];
  }

  get unitKey() {
    const u = this.unit;
    return u ? u.soId : "_";
  }

  /* ── one row, derived once ──────────────────────────────────────────────────
     The same facts c/mscObligations 2.2 derived in decorateBoxed, moved here with
     the rows they describe. A cheque with Finance covers the row and opens to the
     cheque's card; a covering mandate tags it; a settled row asks for nothing. */

  deriveRow(row, dd) {
    const remaining = this.remainingOf(row);
    const live = (row.instruments || []).filter((i) => i && i.live === true);
    /* 1.4 - the same test the deep link and the reconcile use (expandableRow), so a
       row's chevron, its panel and what the modal will open can never disagree. */
    const chequeCovered = this.expandableRow(row);
    const ddCovered = !!(dd && dd.covering) && remaining > 0 && !chequeCovered;
    const settled = remaining <= 0;
    const overdue = this.isOverdue(row);
    /* 1.1 - the row is ONE LINE. What identifies an instrument lives in its own
       line inside the expanded fragment; what the collapsed row carries is the
       figure. */
    /* 1.7 - the row carries no pill any more, so what survives of the old `tag` is
       the one thing still read from it: the TONE the number badge takes.
       1.8 - the tone is deliberately UNCHANGED. Now that a row with nothing recorded
       and a row with a cheque behind it both read amber, the badge is the only thing
       left that tells them apart. */
    let tone = null;
    if (chequeCovered) {
      tone = "rec";
    } else if (ddCovered || settled) {
      tone = "done";
    }

    /* 1.8 - what the row still OWES. stillDueOf is the server's openAmount while a
       live payment stands (it already subtracts what is with Finance) and
       remainingAmount otherwise - never client arithmetic, and the same figure the
       payment popup prefills its form with.

       The order below is tested, not incidental:

         a mandate covers it  (nothing drawn)      the bank collects when due
         stillDue > 0         {figure} pending     amber
         requiredAmount = 0   Nothing due          grey
         remaining <= 0       Settled              green
         otherwise            No amount pending    grey - all of it is with Finance

       The mandate case comes FIRST and draws nothing, exactly as the recorded column
       did before it: there is nothing for a rep to record on that row, and a figure
       here would read as work that is theirs. Its badge stays green.

       "Otherwise" is a row whose cheques cover it entirely and Finance has not
       allocated them yet: it is expandable, it has lines to show, and it asks for
       nothing. It is also why chequeCovered cannot decide this column - a covered row
       may have money open on it or none at all. */
    const stillDue = factStillDueOf(row);
    const required = Number(row.requiredAmount || 0);
    let pendValue = null;
    let pendWord = null;
    let pendCls = "mm__pend";
    if (ddCovered) {
      /* nothing drawn - the arrangement answers for this row */
    } else if (stillDue > 0) {
      pendValue = bareAED(stillDue);
      pendWord = LABELS.LED_PENDING_WORD;
      pendCls = "mm__pend mm__pend--due";
    } else if (required <= 0) {
      pendValue = LABELS.SETTLE_LEG_NONE;
      pendCls = "mm__pend mm__pend--clear";
    } else if (settled) {
      pendValue = LABELS.SETTLE_DONE;
      pendCls = "mm__pend mm__pend--done";
    } else {
      pendValue = LABELS.LED_NONE_PENDING;
      pendCls = "mm__pend mm__pend--clear";
    }

    return {
      ...row,
      remaining,
      live,
      overdue,
      tone,
      pendValue,
      pendWord,
      pendCls,
      isCovered: chequeCovered || ddCovered || settled,
      isOpen: remaining > 0 && !chequeCovered && !ddCovered,
      /* Only a cheque-covered row has anything more to show - its lines. */
      expandable: chequeCovered
    };
  }

  /**
   * 1.4 - the ONE test for "this row opens onto something", used by deriveRow's
   * `expandable`, by the deep link and by the reconcile below. Three copies of this
   * condition is how a row comes to carry a chevron that opens nothing.
   */
  expandableRow(row) {
    if (!row) {
      return false;
    }
    const live = (row.instruments || []).filter((i) => i && i.live === true);
    return live.length > 0 && this.remainingOf(row) > 0;
  }

  /**
   * 1.4 - the expanded row survives a reload only while the reload still supports
   * it. Every recorded cheque replaces `rows` wholesale; without this, an id left
   * over from before points at a milestone that no longer has anything to show (its
   * cheque was allocated), and the row draws an empty panel under itself.
   */
  reconcileExpanded() {
    const id = this.expandedRow;
    if (!id) {
      return;
    }
    const row = (this._rows || []).find((r) => r.sourceId === id);
    if (!row || !this.expandableRow(row)) {
      this.expandedRow = undefined;
    }
  }

  remainingOf(row) {
    const r = Number(row.remainingAmount);
    if (!Number.isNaN(r) && row.remainingAmount !== undefined && row.remainingAmount !== null) {
      return r;
    }
    return Math.max(0, Number(row.requiredAmount || 0) - Number(row.paidAmount || 0));
  }

  /** Past its date with money still on it. Date-only, so "today" is never late. */
  isOverdue(row) {
    if (!row || !row.dueDate || this.remainingOf(row) <= 0) {
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

  /* ── the head ───────────────────────────────────────────────────────────── */

  get headTitle() {
    const m = this.mode;
    if (m === MODES.CHEQUES) return LABELS.CTA_ADD_CHEQUES;
    if (m === MODES.DD) return LABELS.CTA_SETUP_DD;
    if (m === MODES.VIEW) return LABELS.MM_HEAD_DD_VIEW;
    return LABELS.MM_TITLE;
  }

  get headSub() {
    const u = this.unit;
    if (!u) return "";
    if (this.multiUnit && this.mode === MODES.ROWS) {
      return LABELS.MM_UNITS_SUB.replace("{0}", this.unitList.length);
    }
    return u.ref ? `${u.name} · ${u.ref}` : u.name;
  }

  /** One line for the whole schedule - a state, never a figure. */
  get headState() {
    const u = this.unit;
    if (!u || this.mode !== MODES.ROWS) {
      return null;
    }
    return this.stateFor(u);
  }

  stateFor(u) {
    const dd = u.dd;
    if (dd && dd.covering) {
      return {
        dot: dd.coversMilestones ? "mm__dot mm__dot--done" : "mm__dot mm__dot--on",
        text: LABELS.BOX_DD_STATUS.replace("{0}", dd.mandateStatusLabel || "")
      };
    }
    if (dd && dd.mandateId) {
      return {
        dot: "mm__dot mm__dot--on",
        text: LABELS.BOX_DD_STATUS.replace("{0}", dd.mandateStatusLabel || "")
      };
    }
    const liveCount = u.batch ? Number(u.batch.liveChequeCount || 0) : 0;
    if (liveCount > 0) {
      const all = u.covered >= u.rows.length;
      return {
        dot: all ? "mm__dot mm__dot--done" : "mm__dot mm__dot--on",
        text: LABELS.MM_STATE_CHEQUES.replace("{0}", u.covered).replace("{1}", u.rows.length)
      };
    }
    if (u.left <= 0 && u.rows.length) {
      return { dot: "mm__dot mm__dot--done", text: LABELS.MM_YEAR_ALL };
    }
    return { dot: "mm__dot", text: LABELS.MM_STATE_NONE };
  }

  /* ── the rail ───────────────────────────────────────────────────────────── */

  get showRail() {
    return this.multiUnit === true && this.unitList.length > 1;
  }

  get railUnits() {
    const current = this.unitKey;
    return this.unitList.map((u) => {
      const state = this.stateFor(u);
      let words;
      if (u.dd && u.dd.covering) {
        words = LABELS.CTA_DIRECT_DEBIT;
      } else if (u.covered > 0) {
        words = LABELS.MM_COVERED_OF.replace("{0}", u.covered).replace("{1}", u.rows.length);
      } else {
        words = LABELS.MM_RAIL_NONE;
      }
      return {
        soId: u.soId,
        name: u.name,
        sub: u.ref ? `${u.ref} · ${words}` : words,
        dot: state.dot,
        cls: u.soId === current ? "mm__rail-u mm__rail-u--on" : "mm__rail-u"
      };
    });
  }

  handleUnitSelect(event) {
    const so = event.currentTarget.dataset.so;
    if (!so || so === this.unitKey) {
      return;
    }
    /* Switching submits nothing - the mode of the unit being left stays as it is,
       and c/mscChequeSheet keeps its own half-filled state exactly as it does when
       a card collapses over it today. */
    this._selectedSo = so;
    this.expandedRow = undefined;
  }

  /* ── the body: years, folding, filter ───────────────────────────────────── */

  get mode() {
    return this.modeBySo[this.unitKey] || MODES.ROWS;
  }

  get showSchedule() {
    return this.mode === MODES.ROWS;
  }

  /** A plan long enough to fold is a plan long enough to need finding things in. */
  get folded() {
    const u = this.unit;
    return !!u && u.rows.length > FOLD_AT;
  }

  get filter() {
    return this.filterBySo[this.unitKey] || "all";
  }

  get showTools() {
    return this.showSchedule && this.folded;
  }

  get filterCounts() {
    const u = this.unit;
    if (!u) return { all: 0, open: 0, covered: 0 };
    return {
      all: u.derived.length,
      open: u.derived.filter((d) => d.isOpen).length,
      covered: u.derived.filter((d) => d.isCovered).length
    };
  }

  get filterAllText() {
    return LABELS.MM_FILTER_ALL.replace("{0}", this.filterCounts.all);
  }
  get filterOpenText() {
    return LABELS.MM_FILTER_OPEN.replace("{0}", this.filterCounts.open);
  }
  get filterCoveredText() {
    return LABELS.MM_FILTER_COVERED.replace("{0}", this.filterCounts.covered);
  }
  get filterAllCls() {
    return this.filter === "all" ? "mm__seg-b mm__seg-b--on" : "mm__seg-b";
  }
  get filterOpenCls() {
    return this.filter === "open" ? "mm__seg-b mm__seg-b--on" : "mm__seg-b";
  }
  get filterCoveredCls() {
    return this.filter === "covered" ? "mm__seg-b mm__seg-b--on" : "mm__seg-b";
  }

  handleFilter(event) {
    const f = event.currentTarget.dataset.f;
    if (!f) return;
    this.filterBySo = { ...this.filterBySo, [this.unitKey]: f };
  }

  /**
   * The schedule as year groups.
   *
   * ≤ FOLD_AT rows: every row on screen under sticky year labels - no folding, no
   * filter, no click asked of a six-row plan. Past it, each year is one line and
   * the first year with anything still open opens by itself, because that is
   * where the work is. A filter other than "all" is a search: everything that
   * matches is simply shown, unfolded.
   */
  get yearGroups() {
    const u = this.unit;
    if (!u) return [];
    const filter = this.filter;
    const filtering = this.folded && filter !== "all";
    let rows = u.derived;
    if (filtering) {
      rows = rows.filter((d) => (filter === "open" ? d.isOpen : d.isCovered));
    }
    const byYear = new Map();
    rows.forEach((d) => {
      const key = d.dueDate ? String(new Date(d.dueDate).getFullYear()) : "_";
      if (!byYear.has(key)) byYear.set(key, []);
      byYear.get(key).push(d);
    });
    const keys = Array.from(byYear.keys()).sort((a, b) => {
      if (a === "_") return 1;
      if (b === "_") return -1;
      return Number(a) - Number(b);
    });
    const foldable = this.folded && !filtering;
    const openMap = foldable ? this.effectiveOpenYears(u, keys, byYear) : null;
    const expanded = this.expandedRow;
    /* 1.4 - ONE row open at a time, guaranteed HERE rather than trusted from the
       identity. `expanded === d.sourceId` opens every row that answers to that id,
       so a repeated sourceId - a server that ever emits one, a row listed twice -
       drew two panels with the same content and read as "this row is showing
       another row's data". The latch cannot draw a second one whatever the ids do. */
    let openTaken = false;
    const takeOpen = (d) => {
      if (openTaken || !d.expandable || expanded !== d.sourceId) {
        return false;
      }
      openTaken = true;
      return true;
    };
    return keys.map((key) => {
      const list = byYear.get(key);
      const covered = list.filter((d) => d.isCovered).length;
      const count =
        list.length === 1
          ? LABELS.MM_YEAR_ONE
          : LABELS.LEDGER_MILESTONES.replace("{0}", list.length);
      let coverage;
      if (covered === 0) coverage = LABELS.BOX_NONE_COVERED;
      else if (covered === list.length) coverage = LABELS.MM_YEAR_ALL;
      else coverage = LABELS.MM_COVERED_OF.replace("{0}", covered).replace("{1}", list.length);
      const open = foldable ? openMap[key] === true : true;
      return {
        key,
        label: key === "_" ? LABELS.MM_YEAR_UNDATED : key,
        count,
        sentence: `${count} · ${coverage}`,
        foldable,
        open,
        chevron: open ? "chevron-up" : "chevron-down",
        ariaExpanded: open ? "true" : "false",
        foldCls: open ? "mm__yfold mm__yfold--open" : "mm__yfold",
        rows: open
          ? list.map((d) => {
              /* Resolved ONCE per row, then read three times: the panel, the
                 chevron and the aria state are the same answer by construction -
                 they used to be three separate comparisons that could disagree. */
              const rowOpen = takeOpen(d);
              return {
              ...d,
              rowOpen,
              chevron: rowOpen ? "chevron-up" : "chevron-down",
              ariaExpanded: rowOpen ? "true" : "false",
              /* 1.6 - cardKey retired: the panel is no longer a keyed sibling, it
                 lives inside the row's own keyed node. */
              rowCls: this.rowClsFor(d),
              /* 1.9 - the badge is an INDEX, and a milestone can reach this list with
                 no number: a single-installment plan whose MilestoneNumber__c is null
                 (GV-140). 1.12: the badge is then empty; its fixed 24px box keeps the
                 row's grid. */
              num:
                d.milestoneNumber === null ||
                d.milestoneNumber === undefined ||
                d.milestoneNumber === ""
                  ? LABELS.MM_ROW_UNNUMBERED
                  : d.milestoneNumber,
              /* 1.8 - under the name now, and it says what it is. The RED stays here
                 though the ledger row outside went grey: outside, the tier heading
                 above the table counts what is late once for the whole list, and this
                 schedule has no such heading - twelve rows under year captions, where
                 this is the only mark a passed date gets. */
              dueLabel: d.dueDate
                ? LABELS.LED_ROW_DUE.replace("{0}", formatDate(d.dueDate))
                : null,
              dueCls: d.overdue ? "mm__dt mm__dt--late" : "mm__dt",
              /* The TOTAL is the bold figure - the milestone's own amount,
                 constant whatever stands against it, so the column always sums to
                 the schedule. What is pending sits in its own column. */
              amount: bareAED(Number(d.requiredAmount || 0)),
              lines: rowOpen ? this.fragmentFor(d) : null
              };
            })
          : []
      };
    });
  }

  rowClsFor(d) {
    /* --live is the cursor and the hover: only a row with something more to show
       reads as pressable. */
    const live = d.expandable ? " mm__row--live" : "";
    if (d.tone === "rec") return `mm__row mm__row--rec${live}`;
    if (d.tone) return `mm__row mm__row--done${live}`;
    return `mm__row${live}`;
  }

  /** The user's fold choices where they exist; the default where they do not. */
  effectiveOpenYears(u, keys, byYear) {
    const chosen = this.openYearsBySo[u.soId];
    if (chosen) {
      return chosen;
    }
    const firstOpen = keys.find((k) => byYear.get(k).some((d) => d.isOpen));
    const map = {};
    if (firstOpen) map[firstOpen] = true;
    return map;
  }

  handleYearToggle(event) {
    const year = event.currentTarget.dataset.year;
    if (!year) return;
    const u = this.unit;
    if (!u) return;
    /* Materialise the default before toggling, so folding the auto-opened year
       does not silently re-derive it open on the next render. */
    const filterKeys = this.yearGroups.map((y) => y.key);
    const byYear = new Map();
    u.derived.forEach((d) => {
      const key = d.dueDate ? String(new Date(d.dueDate).getFullYear()) : "_";
      if (!byYear.has(key)) byYear.set(key, []);
      byYear.get(key).push(d);
    });
    const current = { ...this.effectiveOpenYears(u, filterKeys, byYear) };
    current[year] = current[year] !== true;
    this.openYearsBySo = { ...this.openYearsBySo, [u.soId]: current };
  }

  /* ── the expanded row: the cheque's card ────────────────────────────────── */

  handleRowToggle(event) {
    const id = event.currentTarget.dataset.id;
    /* A boolean bound to data-* arrives as the string "true"/"false". */
    const expandable = event.currentTarget.dataset.exp === "true";
    if (!id || !expandable) return;
    this.expandedRow = this.expandedRow === id ? undefined : id;
  }

  /**
   * The expanded row's LEDGER FRAGMENT - one line per instrument, one still-open
   * line. Everything that identifies but does not decide (bank, date, the Payment
   * reference, recorded-when, recorded-by, the file count) goes into one dim run
   * that truncates first on a narrow screen; the amount never does. The old
   * paragraph's status sentence is the chip; its "no form here" disclaimer is
   * nothing, which is what a panel that asks for nothing should show.
   */
  fragmentFor(d) {
    const lines = d.live.map((i, idx) => {
      /* 1.3 - the line is the PAYMENT, by request: its reference, the day it was
         submitted, its status, its amount - nothing else. The cheque's own number,
         bank and date live on the Payment where Finance reads them (and on the
         cheque sheet where they were typed). Falls back to the instrument's own
         name only when no Payment reference exists, so the line is never blank. */
      const id = i.receiptName
        ? LABELS.MM_IL_PAYMENT.replace("{0}", i.receiptName)
        : `${i.mode || ""} ${i.reference || ""}`.trim();
      return {
        /* 1.4 - the index guarantees uniqueness even if the same receipt were ever
           listed twice against one milestone; a repeated key in a for:each is what
           makes a panel draw the same line twice. The id keeps the identity. */
        key: `${i.receiptId}-${idx}`,
        id,
        /* In Progress is the resting state and reads with Finance; any other
           status is the news and reads alone. */
        chip:
          i.status && i.status !== "In Progress" ? i.status : LABELS.MM_IL_CHIP,
        meta: i.recordedOn
          ? LABELS.MM_IL_SUBMITTED.replace("{0}", formatDate(i.recordedOn))
          : "",
        amount: formatAED(i.amount)
      };
    });
    const open = Number(d.openAmount || 0);
    return {
      lines,
      /* Absent when nothing is - a fully covered milestone opens to its
         instrument lines and nothing more. */
      still: open > 0 ? formatAED(open) : null
    };
  }
  /* ── the foot: the decision ─────────────────────────────────────────────────
     Rows mode only. The three panels carry their own Cancel and Submit -
     c/mscChequeSheet and c/mscDirectDebit are rehosted unchanged - so while one
     is open the modal's foot would be a second set of controls for the same task. */

  get foot() {
    const u = this.unit;
    if (!u || this.mode !== MODES.ROWS) {
      return null;
    }
    const batch = u.batch;
    const dd = u.dd;
    const chequesAllowed = !!(batch && batch.chequesAllowed);
    const ddAllowed = !!(batch && batch.directDebitAllowed);
    const anyOpen = u.derived.some((d) => d.remaining > 0 && Number(d.openAmount || 0) > 0);
    const showCheques = chequesAllowed && anyOpen && u.left > 0;
    const showDd = ddAllowed && u.left > 0;
    const ddStands = !!(dd && dd.mandateId);
    const liveCount = batch ? Number(batch.liveChequeCount || 0) : 0;

    let text;
    if (ddStands) {
      /* 1.11: the mandate and its stage, whatever the stage */
      const parts = [LABELS.MM_FOOT_MANDATE.replace("{0}", dd.requestName || "")];
      if (dd.mandateStatusLabel) parts.push(dd.mandateStatusLabel);
      if (dd.bank) parts.push(dd.bank);
      text = parts.join(" · ");
    } else if (liveCount > 0) {
      text =
        u.open === 1
          ? LABELS.MM_FOOT_OPEN_ONE
          : LABELS.BOX_STILL_OPEN_SOME.replace("{0}", u.open);
    } else if (showCheques || showDd) {
      text = LABELS.MM_FOOT_HOW;
    } else if (batch && batch.directDebitReason && u.left > 0) {
      /* 1.11: why Direct Debit is not on offer, in the server's words */
      text = batch.directDebitReason;
    } else {
      text = null;
    }

    const showView = ddStands;
    if (!text && !showCheques && !showDd && !showView) {
      return null;
    }
    return {
      text,
      showDd,
      showCheques,
      showView,
      chequesLabel: liveCount > 0 ? LABELS.CTA_ADD_CHEQUES : LABELS.CTA_CHEQUES,
      disabled: this.busy
    };
  }

  /* ── panels ─────────────────────────────────────────────────────────────── */

  get panel() {
    const u = this.unit;
    if (!u || !u.batch) {
      return null;
    }
    const m = this.mode;
    const b = u.batch;
    return {
      soId: u.soId,
      showSheet: m === MODES.CHEQUES,
      showDdForm: m === MODES.DD,
      showDdView: m === MODES.VIEW,
      lines: b.lines || [],
      bankOptions: b.bankOptions || [],
      ddBankOptions: b.ddBankOptions || [],
      ddAccountTypes: b.ddAccountTypes || [],
      ddIdTypes: b.ddIdTypes || [],
      prefill: b.prefill,
      computed: b.computed,
      dd: b.dd,
      /* 1.11 */
      card: b.dd ? b.dd.card : null
    };
  }

  setMode(mode) {
    this.modeBySo = { ...this.modeBySo, [this.unitKey]: mode };
  }

  handleCheques() {
    this.setMode(MODES.CHEQUES);
  }

  handleDd() {
    this.setMode(MODES.DD);
  }

  handleView() {
    this.setMode(this.mode === MODES.VIEW ? MODES.ROWS : MODES.VIEW);
  }

  handleSheetCancel() {
    this.setMode(MODES.ROWS);
  }

  handleSheetSubmit(event) {
    const so = event.currentTarget.dataset.so;
    this.dispatchEvent(
      new CustomEvent("chequesubmit", {
        detail: {
          ...(event.detail || {}),
          salesOrderId: (event.detail && event.detail.salesOrderId) || so
        }
      })
    );
  }

  handleDdCancel() {
    this.setMode(MODES.ROWS);
  }

  handleDdCreate(event) {
    const so = event.currentTarget.dataset.so;
    this.dispatchEvent(
      new CustomEvent("ddcreate", { detail: { ...(event.detail || {}), salesOrderId: so } })
    );
  }

  /** 1.11: the card acted on the mandate; the page reloads the box. */
  handleDdChanged(event) {
    const so = event.currentTarget.dataset.so;
    this.dispatchEvent(
      new CustomEvent("ddchanged", { detail: { ...(event.detail || {}), salesOrderId: so } })
    );
  }

  /** 1.11: Set up again, after a mandate that no longer stands. */
  handleDdSetup() {
    this.setMode(MODES.DD);
  }

  /**
   * A panel the server no longer allows gives way to the rows - the mandate form
   * once a mandate stands, the sheet once a mandate covers the schedule. The same
   * reconcile the card ran (mscObligations 1.9), moved here with the panels.
   */
  reconcile() {
    Object.keys(this.modeBySo).forEach((so) => {
      const mode = this.modeBySo[so];
      const b = this._batch[so];
      if (!b) return;
      if (mode === MODES.DD && b.dd && b.dd.canRequest !== true) {
        this.modeBySo = { ...this.modeBySo, [so]: MODES.ROWS };
      }
      if (mode === MODES.CHEQUES && b.chequesAllowed !== true) {
        this.modeBySo = { ...this.modeBySo, [so]: MODES.ROWS };
      }
    });
  }

  /* ── deep link ──────────────────────────────────────────────────────────── */

  /** Land on the named unit with the named row's year unfolded and the row
      expanded - a deep-linked row inside a folded year is a row nobody can see. */
  applyFocusTarget() {
    /* Only while the modal is open (or opening). A focus prop that changes behind a
       closed modal must not reach in and expand a row; the next open re-applies. */
    if (!this._open) {
      return;
    }
    if (this._focusSalesOrderId) {
      this._selectedSo = this._focusSalesOrderId;
    }
    const id = this._focusRowId;
    /* 1.4 - AUTHORITATIVE, both ways. It used to return early on a missing id and
       leave whatever was expanded still expanded, so an open with no focus row
       inherited the last one's. Every path through here now states the expansion. */
    if (!id) {
      this.expandedRow = undefined;
      this._scrollTo = undefined;
      return;
    }
    const row = (this._rows || []).find((r) => r.sourceId === id);
    if (!row) {
      this.expandedRow = undefined;
      this._scrollTo = undefined;
      return;
    }
    const so = row.salesOrderId || "_";
    this._selectedSo = so;
    const year = row.dueDate ? String(new Date(row.dueDate).getFullYear()) : "_";
    const current = { ...(this.openYearsBySo[so] || {}) };
    current[year] = true;
    this.openYearsBySo = { ...this.openYearsBySo, [so]: current };
    /* Expanded only where there IS something to expand onto - and cleared where
       there is not, so the focus row never leaves an older row open behind it. */
    this.expandedRow = this.expandableRow(row) ? id : undefined;
    this._scrollTo = id;
  }

  /* ── focus, escape, exit - c/mscDrawer's pattern ────────────────────────── */

  renderedCallback() {
    if (!this.mounted || this.closing) {
      return;
    }
    if (!this._focusedOnOpen) {
      const close = this.template.querySelector(".mm__x");
      if (close) {
        this._previousFocus = document.activeElement;
        close.focus({ preventScroll: true });
        this._focusedOnOpen = true;
      }
    }
    if (this._scrollTo) {
      const row = this.template.querySelector(`[data-id="${this._scrollTo}"]`);
      if (row) {
        row.scrollIntoView({ block: "center" });
      }
      this._scrollTo = undefined;
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
      /* The opener can be gone - losing focus to the body is correct then. */
    }
  }

  get layerClass() {
    return this.closing ? "layer layer--closing" : "layer";
  }

  get panelClass() {
    return this.showRail ? "mm mm--wide" : "mm";
  }

  handleClose() {
    if (this.closing) {
      return;
    }
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleScrim() {
    /* The scrim never abandons a half-filled panel silently: with one open it
       behaves like Escape and returns to the schedule instead of closing. */
    if (this.mode !== MODES.ROWS) {
      this.setMode(MODES.ROWS);
      return;
    }
    this.handleClose();
  }

  stop(event) {
    event.stopPropagation();
  }

  /**
   * Escape steps OUT, one surface at a time: a panel returns to the schedule,
   * the schedule closes the modal. stopPropagation because modonSheet listens on
   * the window, and one keypress must not close the whole booking journey too.
   */
  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      if (this.mode !== MODES.ROWS) {
        this.setMode(MODES.ROWS);
        return;
      }
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
    const root = this.template.querySelector(".mm");
    if (!root) {
      return [];
    }
    const sel =
      'button, [href], input, select, textarea, iframe, [tabindex]:not([tabindex="-1"])';
    return Array.from(root.querySelectorAll(sel)).filter(
      (el) => !el.disabled && el.getAttribute("aria-hidden") !== "true"
    );
  }
}