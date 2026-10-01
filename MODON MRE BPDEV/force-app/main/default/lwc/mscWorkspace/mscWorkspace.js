/**
 * The console hub - greeting, date and the four metric cards.
 *
 * Version  Author      Date         Detail
 * 1.16     Aurelix Dev 29 Sep 2026  The hub's numbers are re-read whenever a sheet closes. The refresh at Confirm
 *                                   ran before MODON's flow closed the sale and marked the unit Sold.
 * 1.15     Aurelix Dev 03 Sep 2026  MSC-231. Book unit on an EOI row opens the journey seeded
 *                                   with that opportunity and EOI (eoi-id -> c/mscBookingPage).
 * 1.14     Aurelix Dev 02 Sep 2026  MSC-222. The Revenue (Total Sales) sheet is size="immersive",
 *                                   the same room Available Units already had: seven columns of
 *                                   booking data need the width. Template only, and only that
 *                                   one sheet - Leads, EOI, Learning and Alerts are unchanged.
 * 1.13     Aurelix Dev 02 Sep 2026  MSC-216. The four card workspaces (Units, Leads, Revenue,
 *                                   EOI) are explicit-close: only their close button closes
 *                                   them - backdrop clicks and Escape do nothing. Learning and
 *                                   Alerts drawers keep light dismiss. Template only.
 * 1.12     Aurelix Dev 02 Sep 2026  MSC-215. The hub cards move when the JOURNEY writes, not
 *                                   only the leads pane: a picked customer (= a conversion)
 *                                   refreshes the metrics and raises `leadschanged` for the
 *                                   bell; a newly created order refreshes them again.
 * 1.11     Aurelix Dev 02 Sep 2026  MSC-212. "Book a unit" on a lead with no opportunity opens
 *                                   the journey seeded with it (openJourneyForLead -> lead-id);
 *                                   the `lead` URL param finally carries it, so a refresh
 *                                   re-seeds. The seed clears when the customer step converts
 *                                   (opportunitychange) and on every existing reset path.
 * 1.10     Aurelix Dev 02 Sep 2026  MSC-211. A lead write refreshes the hub's own metrics
 *                                   (`leadschanged` -> refreshMetrics); the event is left to
 *                                   bubble on to the shell for the bell badge.
 * 1.9      Aurelix Dev 31 Aug 2026  MSC-189 fix. An alerts booking task lands on the Bookings
 *                                   pane's detail (Verification tab) - the screen the follow-up
 *                                   is about - via open-sales-order-id/initial-tab seeds; the
 *                                   journey stays the fallback for an opportunity with no order.
 * 1.8      Aurelix Dev 31 Aug 2026  MSC-189. An alerts booking task resumes that booking's
 *                                   journey (`openbooking` -> openJourney), like Resume does.
 * 1.7      Aurelix Dev 31 Aug 2026  MSC-189. An alerts card routes to the leads pane: `openleads`
 *                                   carries a starting filter (overdue/today) or a lead to open;
 *                                   the seeds clear on any other navigation.
 * 1.6      Aurelix IT  20 Aug 2026  MSC-092. Pressing a card always starts fresh.
 * 1.5      Aurelix Developer 17 Aug 2026  One Sales Order is one booking: booking-id passed through; sibling remount.
 * 1.4      Aurelix IT  13 Aug 2026  The open opportunity is reported to the shell.
 * 1.3      Aurelix IT  09 Aug 2026  Available Units opens the journey in an immersive sheet.
 * 1.2      Aurelix IT  09 Aug 2026  Sheet wiring rebuilt against modonSalesWorkspace.
 * 1.1      Aurelix IT  09 Aug 2026  Lead and booking handoffs open the journey.
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonSalesWorkspace.
 */

import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getDashboardMetrics from "@salesforce/apex/SalesConsoleDashboardController.getDashboardMetrics";
import { formatAEDShort } from "c/modonSalesFormat";

/**
 * The one page, in two states: hub (card == null) and section (card set). Owns which card is
 * active, reports location upward via `contextchange`.
 */
const CARDS = [
  {
    key: "units",
    label: "Available Units",
    icon: "home",
    metric: "availableUnits",
    // units this agent can book, not the org's whole stock
    caption: "assigned to you"
  },
  {
    key: "leads",
    label: "My Leads",
    icon: "user-square",
    metric: "newLeads",
    caption: "open leads"
  },
  {
    key: "revenue",
    label: "Total Sales",
    icon: "trending-up",
    // sold this month, from SalesOrder__c.TotalAmount__c; not commission
    metric: "totalSalesMTD",
    money: true,
    caption: "this month"
  },
  {
    key: "eoi",
    label: "EOI",
    icon: "file-text",
    // a real count now
    metric: "activeEoi",
    caption: "active"
  }
];

const CARD_LABELS = {
  units: "Available Units",
  leads: "My Leads",
  learning: "Learning",
  revenue: "Total Sales",
  eoi: "Expressions of Interest",
  alerts: "Alerts"
};

export default class MscWorkspace extends LightningElement {
  @api userName = "Modon";

  /** Passed through to the booking journey, which is also mountable standalone. */
  @api theme;

  /** Location, pushed down from the shell. */
  @api
  get card() {
    return this._card;
  }
  set card(v) {
    const next = v && CARD_LABELS[v] ? v : null;
    this._card = next;
    this.sheetOpen = !!next;
  }
  _card = null;

  /** Tracked separately from the active card: closing outlives the state change. */
  sheetOpen = false;

  // mirrored into private state
  @api
  get bookingId() {
    return this._bookingId;
  }
  set bookingId(v) {
    this._bookingId = v;
  }
  _bookingId;

  @api
  get leadId() {
    return this._leadId;
  }
  set leadId(v) {
    this._leadId = v;
  }
  _leadId;

  /** MSC-231: the EOI a Book unit door carried in; seeds the journey's deposit and
   *  typology preference. Set only by handleBookFromEoi, cleared by every other entry. */
  get eoiId() {
    return this._eoiId;
  }
  _eoiId = null;

  /** The opportunity, carried in the URL so a refresh survives. */
  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(v) {
    if (v && v !== this._opportunityId) {
      this._opportunityId = v;
      this.sheetOpen = true;
    } else if (!v) {
      this._opportunityId = v;
    }
  }

  @api
  get step() {
    return this._step;
  }
  set step(v) {
    this._step = v;
  }
  _step;

  metrics;
  _wiredMetrics;
  journeyLabel = "";

  @wire(getDashboardMetrics)
  wiredMetrics(result) {
    // held so a completed booking can refreshApex
    this._wiredMetrics = result;
    if (result.data) {
      this.metrics = result.data;
    }
  }

  connectedCallback() {
    this.reportContext();
  }

  // cards
  get cards() {
    const m = this.metrics;
    return CARDS.map((c) => {
      let value = "-";
      if (m && m[c.metric] != null) {
        value = c.money ? formatAEDShort(m[c.metric]) : String(m[c.metric]);
      }
      const active = c.key === this._card;
      return {
        ...c,
        value,
        active,
        cls: active ? "glass card card--active" : "glass card",
        iconColor: active ? "var(--gold, #a8a8a8)" : "currentColor"
      };
    });
  }

  /** The hub recedes while a sheet is over it. */
  get hubClass() {
    return this.sheetOpen ? "hub hub--covered" : "hub";
  }

  get activeCardLabel() {
    return CARD_LABELS[this._card] || "";
  }

  /** The one metric relevant here. */
  get activeCardCaption() {
    const c = CARDS.find((x) => x.key === this._card);
    if (!c) {
      return "";
    }
    const m = this.metrics;
    let value = null;
    if (m && m[c.metric] != null) {
      value = c.money ? formatAEDShort(m[c.metric]) : String(m[c.metric]);
    }
    return value ? `${value} ${c.caption}` : "";
  }

  /** Every card has a pane behind it. */
  get showSheet() {
    return (
      this.sheetOpen &&
      (this.isUnits ||
        this.isLeads ||
        this.isRevenue ||
        this.isEoi ||
        this.isLearning ||
        this.isAlerts)
    );
  }

  /* journey handoff */
  /** "Book a unit" on a lead: with an opportunity it resumes as that booking; without one the
      journey opens seeded with the lead and the customer step converts it in place (MSC-212). */
  handleStartFromLead(e) {
    const d = e.detail || {};
    if (d.opportunityId) {
      this.openJourney(d.opportunityId);
      return;
    }
    if (d.leadId) {
      this.openJourneyForLead(d.leadId, d.name);
    }
  }

  /** MSC-212. The lead-seeded journey: no opportunity yet, so openJourney's guard cannot serve. */
  openJourneyForLead(leadId, leadName) {
    this._opportunityId = null;
    this._bookingId = null;
    this._resumeContext = null;
    this._leadId = leadId;
    this._leadName = leadName || "";
    this._journeyMounted = true;
    this._card = "units";
    this.sheetOpen = true;
    this.reportContext(true);
  }

  /** For the sheet header only; never sent anywhere. */
  _leadName = "";

  /** MSC-231: Book unit on an EOI row - the journey opens on that opportunity with the
   *  EOI carried in; the booking page applies its deposit and typology preference. */
  handleBookFromEoi(e) {
    const d = e.detail || {};
    if (!d.opportunityId) {
      return;
    }
    this.openJourney(d.opportunityId);
    /* after openJourney: it resets the seed like every other entry */
    this._eoiId = d.eoiId || null;
  }

  /** Resume an unfinished booking, with the Sales Order (`booking-id`). */
  handleResumeBooking(e) {
    const d = e.detail || {};
    this.openJourney(d.opportunityId, d.bookingId, {
      bookingRef: d.bookingRef,
      unitName: d.unitName,
      customerName: d.customerName
    });
  }

  /** The page asks to open another order of the same booking; it is remounted on the new order. */
  handleOpenSibling(e) {
    const d = e.detail || {};
    if (!d.salesOrderId || d.salesOrderId === this._bookingId) {
      return;
    }
    if (d.opportunityId && d.opportunityId !== this._opportunityId) {
      this._opportunityId = d.opportunityId;
    }
    this._journeyMounted = false;
    this._resumeContext = null;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this._bookingId = d.salesOrderId;
      this._journeyMounted = true;
      this.reportContext(false);
    }, 0);
  }

  /** The page says which order the server actually opened; null drops the `booking` URL param. */
  handleBookingOpened(e) {
    const d = e.detail || {};
    const opened = d.salesOrderId || null;
    const changed = opened !== (this._bookingId || null);
    this._bookingId = opened;
    if (opened) {
      this._resumeContext = {
        bookingRef: d.bookingRef,
        unitName: d.unitName,
        customerName: d.customerName
      };
    } else {
      this._resumeContext = null;
    }
    if (changed) {
      /* MSC-215: a new order exists (Confirm Booking) - Available Units and the month's total
         move; a plain resume re-open reports the same order and costs nothing */
      this.refreshMetrics();
      this.reportContext(false);
    }
  }

  /** False only for the tick between two orders of one booking. */
  _journeyMounted = true;
  get journeyMounted() {
    return this._journeyMounted;
  }

  /** What Total Sales knew about the pressed row, for the sheet header. */
  _resumeContext = null;

  /** The journey opens in place, inside the Units sheet (as modonJourney does). The Book route stays live. */
  openJourney(opportunityId, salesOrderId, resumeContext) {
    if (!opportunityId) {
      // defensive: better to stay put than open an empty journey
      return;
    }
    this._opportunityId = opportunityId;
    /* the order, when the caller has one; a lead handoff must not inherit one */
    this._bookingId = salesOrderId || null;
    this._resumeContext = salesOrderId && resumeContext ? resumeContext : null;
    /* MSC-212: nor does an opportunity journey inherit a pending lead seed */
    this._leadId = null;
    this._leadName = "";
    /* MSC-231: nor a pending EOI seed - only the door sets it, after this call */
    this._eoiId = null;
    this._journeyMounted = true;
    this._card = "units";
    this.sheetOpen = true;
    this.reportContext(true);
  }

  // the getter lives with the @api setter above
  _opportunityId;

  /** A journey started from the Units card chooses its own customer; report it so the URL learns it. */
  handleOpportunityChange(e) {
    const id = (e.detail || {}).opportunityId;
    if (!id || id === this._opportunityId) {
      return;
    }
    this._opportunityId = id;
    /* MSC-212: a seeded lead is now a customer - the URL swaps `lead` for `opp` */
    this._leadId = null;
    this._leadName = "";
    /* MSC-215: picking a customer converts a lead (every route through the picker raises or
       converts one), so the hub's open-leads count and the bell badge move with it - the same
       one-signal-per-write pattern as MSC-211, from the journey's side. The event bubbles to
       the shell; the workspace's own listener sits on the leads pane, so no loop. */
    this.refreshMetrics();
    this.dispatchEvent(
      new CustomEvent("leadschanged", {
        detail: { rosterChanged: true },
        bubbles: true,
        composed: true
      })
    );
    // replace, not push
    this.reportContext(false);
  }

  /** The picker gives way to the journey. */
  get hasJourneyOpportunity() {
    return !!this._opportunityId;
  }

  /** The sheet header carries the step the rep is on. */
  get unitsSheetTitle() {
    /* a resumed order is named */
    return this._bookingId ? "Resume booking" : "Start a booking";
  }

  get unitsSheetSubtitle() {
    if (this._bookingId) {
      const c = this._resumeContext || {};
      const bits = [c.bookingRef, c.unitName, c.customerName].filter(Boolean);
      return bits.length ? bits.join(" · ") : "Opening the booking you chose";
    }
    /* MSC-212: a lead-seeded journey names who it is for */
    if (this._leadId && this._leadName) {
      return `For ${this._leadName} · choose a unit, then confirm the customer`;
    }
    return "Choose a unit, then the customer it is for";
  }

  /** The sheet asks to close; c-modon-sheet fires `closed` when the exit finishes, which clears the card. */
  requestSheetClose() {
    this.sheetOpen = false;
  }

  handleSheetClosed() {
    this._card = null;
    /* 1.7/1.9: an alerts seed dies with its pane */
    this.leadsSeedFilter = null;
    this.leadsSeedLeadId = null;
    this.bookingsSeedOrderId = null;
    this.bookingsSeedTab = null;
    this._bookingId = null;
    this._resumeContext = null;
    this._journeyMounted = true;
    this._leadId = null;
    this._leadName = "";
    this._step = null;
    // cleared with the rest, so reopening lands on the picker
    this._opportunityId = null;
    this.journeyLabel = "";
    this.reportContext(true);
    /* 1.16 - back on the hub: the cards show what is true now */
    this.refreshMetrics();
  }

  /**
   * MSC-092: pressing a card always starts fresh; the journey seed is cleared every time. No
   * history entry: the shell replaces when the card did not change.
   */
  /* 1.7: seeds the alerts panel hands the leads pane; null for a normal My Leads open */
  leadsSeedFilter = null;
  leadsSeedLeadId = null;

  /* 1.9: seeds the alerts panel hands the bookings pane */
  bookingsSeedOrderId = null;
  bookingsSeedTab = null;

  /** An alerts booking task opens that booking's detail on its Verification tab;
      an opportunity with no order yet falls back to resuming the journey. */
  handleOpenBookingAlert(e) {
    const d = e.detail || {};
    if (d.salesOrderId) {
      this.bookingsSeedOrderId = d.salesOrderId;
      this.bookingsSeedTab = "verify";
      this._card = "revenue";
      this.sheetOpen = true;
      this.reportContext(true);
      return;
    }
    this.openJourney(d.opportunityId, null, null);
  }

  /** An alerts card asked for the leads pane - filtered, or straight onto one lead. */
  handleOpenLeads(e) {
    const d = e.detail || {};
    this.leadsSeedFilter = d.filter || null;
    this.leadsSeedLeadId = d.leadId || null;
    /* MSC-212: a pending journey seed dies with the pane swap, like handleCardSelect */
    this._leadId = null;
    this._leadName = "";
    this._card = "leads";
    this.sheetOpen = true;
    this.reportContext(true);
  }

  handleCardSelect(e) {
    const key = e.currentTarget.dataset.card;
    if (!key) {
      return;
    }
    this._card = key;
    this.sheetOpen = true;
    // 1.7/1.9: a hub open is never pre-filtered or pre-opened
    this.leadsSeedFilter = null;
    this.leadsSeedLeadId = null;
    this.bookingsSeedOrderId = null;
    this.bookingsSeedTab = null;
    // switching cards abandons a journey seed, never a booking
    this._leadId = null;
    this._leadName = "";
    this._step = null;
    this._bookingId = null;
    this._resumeContext = null;
    this._journeyMounted = true;
    this._opportunityId = null;
    this.journeyLabel = "";
    this.reportContext(true);
  }

  // panes
  get isUnits() {
    return this._card === "units";
  }
  get isLeads() {
    return this._card === "leads";
  }
  get isLearning() {
    return this._card === "learning";
  }
  get isRevenue() {
    return this._card === "revenue";
  }
  get isEoi() {
    return this._card === "eoi";
  }
  get isAlerts() {
    return this._card === "alerts";
  }

  // greeting
  get greeting() {
    const first = (this.userName || "").trim().split(" ")[0] || "there";
    const h = new Date().getHours();
    const part =
      h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    return `${part}, ${first}`;
  }

  get todayLabel() {
    const d = new Date();
    const days = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday"
    ];
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return `${days[d.getDay()]}, ${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()} · Abu Dhabi, UAE`;
  }

  /**
   * 1.10: a lead write landed. The hub's open-leads count only moves when the rep's book
   * itself changed, so a routine call log costs no extra query here. Deliberately not stopped:
   * the event carries on to the shell, which re-reads the bell badge every time (any
   * disposition can change what is overdue).
   */
  handleLeadsChanged(e) {
    if (e && e.detail && e.detail.rosterChanged) {
      this.refreshMetrics();
    }
  }

  /** Available units and the month's total move when a booking completes. */
  refreshMetrics() {
    if (this._wiredMetrics) {
      refreshApex(this._wiredMetrics);
    }
  }

  /** Tell the shell where we are; `push` marks a real view change. */
  reportContext(push) {
    this.dispatchEvent(
      new CustomEvent("contextchange", {
        detail: {
          card: this._card,
          bookingId: this._bookingId,
          leadId: this._leadId,
          // so the shell can put it in the URL
          opportunityId: this._opportunityId,
          step: this._step,
          label: this.journeyLabel || this.activeCardLabel,
          push: !!push
        },
        bubbles: true,
        composed: true
      })
    );
  }
}