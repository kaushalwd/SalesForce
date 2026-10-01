/**
 * My Bookings pane - list, detail, payment schedule, documents.
 *
 * Version  Author      Date         Detail
 * 1.17     Aurelix Dev 30 Sep 2026  Blank cells stay empty (no dash); a missing value on the detail reads "Not set".
 *                                   The search hint is Ctrl K on Windows. A closed sale shows no "New" stage.
 * 1.16     Aurelix Dev 29 Sep 2026  A sale MODON has closed shows "Settled" and offers no Resume
 *                                   (saleClosed from SalesConsoleBookingListController 1.8). MODON's
 *                                   flow leaves Status__c at New when it closes a sale.
 * 1.15     Aurelix Dev 02 Sep 2026  MSC-226. Payment plan table fitted to the immersive sheet
 *                                   (css only): five tracks share the width instead of
 *                                   Milestone taking it all. Documents untouched.
 * 1.14     Aurelix Dev 02 Sep 2026  MSC-222. Column alignment. The gap was always uniform; the
 *                                   tracks were not (100px beside 176px, everything pinned
 *                                   left), so the space read between two columns swung from
 *                                   ~40px to ~240px on one row. Seven tracks brought within
 *                                   130-180px of each other on one 20px gap, and every heading
 *                                   and cell centred in its track. CSS only. The phone card
 *                                   keeps its left-aligned labelled fields.
 * 1.13     Aurelix Dev 02 Sep 2026  MSC-221. The rows stop being cards: no per-row border, no
 *                                   radius, no gap - one surface parted by a --divider hairline,
 *                                   and hover moves from the border lighting up to the fill
 *                                   washing in. The status tabs move onto the search row, in
 *                                   place of the standing figures, which are withdrawn.
 *                                   fitPageSize is told the gap is 0 or it fits a row fewer.
 * 1.12     Aurelix Dev 02 Sep 2026  MSC-220. The list, kept plain. Status tabs carrying their own
 *                                   counts replace the status dropdown; the Status column shows
 *                                   the value stored on the record and nothing invented; a cell
 *                                   with nothing in it is left blank instead of holding a dash;
 *                                   the Sort dropdown became click-to-sort column headers; and
 *                                   the toolbar carries the book's standing in two figures.
 *                                   One field to a column - the second lines under Amount and
 *                                   Created are gone, and so is every explanatory sentence on
 *                                   the screen. The "Booking not started" rows are withdrawn
 *                                   with the Apex list behind them.
 * 1.11     Aurelix Dev 02 Sep 2026  MSC-218 / MSC-219. The pane says what is true and defaults to
 *                                   what is live: an awaiting row whose unit went to somebody
 *                                   else reads "Unit no longer available" and offers no Resume;
 *                                   a blank expiry says "No hold" instead of "Held until -";
 *                                   converted customers with no booking get their own row
 *                                   ("Booking not started" -> Start booking); and the status
 *                                   filter opens on Active, with All still one click away.
 * 1.10     Aurelix Dev 31 Aug 2026  MSC-189. The alerts panel can seed this pane: `open-sales-order-id`
 *                                   opens that booking's detail once the list has loaded, and
 *                                   `initial-tab` picks its tab (e.g. Verification). Additive,
 *                                   null on a normal open.
 * 1.9      Aurelix Dev 25 Aug 2026  MSC-170. The sort runs across the whole list.
 * 1.8      Aurelix IT  20 Aug 2026  MSC-089. Documents hidden on the detail (SHOW_DOCUMENTS_TAB).
 * 1.7      Aurelix IT  20 Aug 2026  MSC-088. A fourth tab: Verification.
 * 1.6      Aurelix IT  20 Aug 2026  MSC-086. Documents tab reads Status__c and the arrival date.
 * 1.5      Aurelix IT  20 Aug 2026  MSC-084. An Owners tab (c/mscOwnersPane).
 * 1.4      Aurelix IT  18 Aug 2026  Initials avatar dropped.
 * 1.3      Aurelix IT  18 Aug 2026  "Total contract value" line removed.
 * 1.2      Aurelix IT  18 Aug 2026  Redesigned as a data grid (MSC-056).
 * 1.1      Aurelix IT  12 Aug 2026  An "Awaiting payment" group.
 * 1.0      Aurelix IT  09 Aug 2026  Ports modonRevenuePane and modonBookingWorkspace as one component.
 */

import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyBookings from "@salesforce/apex/SalesConsoleBookingListController.getMyBookings";
import getBooking from "@salesforce/apex/SalesConsoleBookingListController.getBooking";
import {
  formatAED,
  formatDate,
  formatTime,
  reduceError
} from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import {
  fitPageSize,
  pageCount,
  clampPage,
  pageInfo,
  pageItems,
  PAGE_DEFAULT
} from "c/mscPaging";

/** Detail sections. */
/* Documents on the booking detail; set to true to bring the tab back */
const SHOW_DOCUMENTS = false;

const TABS = [
  { key: "plan", label: "Payment plan" },
  { key: "documents", label: "Documents" },
  /* the label is c/mscLabels' */
  { key: "owners", label: LABELS.JO_B_TAB },
  { key: "verify", label: LABELS.JO_B_TAB_VERIFY }
];

/** A booking that has not reached a Sales Order status the rep can act on is resumable. */
const RESUMABLE = ["New", "In Progress"];

/**
 * 1.16: shown for a sale MODON has closed (saleClosed) while Status__c still reads New.
 */
const SETTLED_TEXT = LABELS.SETTLE_DONE;

/** MSC-220: the one tab that is not a stored status. */
const TAB_ALL = "all";

/**
 * MSC-218 / MSC-220: why an outstanding fee has no Resume behind it. Two words, in the slot the
 * button would have taken - business asked for no prose on this screen.
 */
const BLOCKED_TEXT = "Unit sold";

/** MSC-220: which way a column sorts the first time it is clicked. */
const SORT_FIRST_DIR = { name: "asc", value: "desc", date: "desc" };

/** Chip colour by stored milestone / document status. */
const PAY_CHIP = {
  Paid: "chip chip--ok",
  "Partially Paid": "chip chip--progress",
  "Not Paid": "chip chip--muted",
  Cancelled: "chip chip--warn"
};
/* Documents__c.Status__c, the four values MODON's picklist holds */
const DOC_CHIP = {
  Uploaded: "chip chip--ok",
  Signed: "chip chip--ok",
  Generated: "chip chip--new",
  "Pending Upload": "chip chip--muted"
};

/* 1.17: an empty cell, not a dash; "Not set" where a blank would read as missing data */
const BLANK = "";
const NOT_SET = "Not set";

/* 1.17: the stages a closed sale may still carry, which would contradict its "Settled" status */
const OPEN_STAGES = ["new", "in progress"];

/* 1.17: the search shortcut as this keyboard writes it */
function isApplePlatform() {
  try {
    const nav = typeof navigator !== "undefined" ? navigator : null;
    const p = (nav && ((nav.userAgentData && nav.userAgentData.platform) || nav.platform)) || "";
    return /mac|iphone|ipad|ipod/i.test(p);
  } catch (e) {
    return false;
  }
}

export default class MscBookings extends LightningElement {
  bookings = [];
  awaiting = [];
  loading = true;
  errorMsg = "";
  search = "";
  /* MSC-220: a stored status, or TAB_ALL. Not `tab` - the detail's section tabs own that. */
  statusTab = TAB_ALL;
  sortKey = "date";
  sortDir = "desc";

  bookingId = null;
  booking = null;
  detailLoading = false;
  tab = "plan";
  /** How many people own the open booking; getBooking sends it, c/mscOwnersPane re-sends after a write. */
  ownersCount = null;
  /* and the two the Verification tab is labelled with */
  verifiedCount = null;
  verifiableCount = null;

  _wired;
  _keyHandler;
  /** The list row that was opened. */
  _openRow = null;

  connectedCallback() {
    // Cmd/Ctrl+K focuses search
    this._keyHandler = (e) => this.handleDocumentKey(e);
    document.addEventListener("keydown", this._keyHandler);
    this.startPaging();
  }

  disconnectedCallback() {
    document.removeEventListener("keydown", this._keyHandler);
    this.stopPaging();
  }

  handleDocumentKey(e) {
    if (this.bookingId) {
      return;
    }
    if ((e.metaKey || e.ctrlKey) && (e.key === "k" || e.key === "K")) {
      const input = this.template.querySelector(".search input");
      if (input) {
        e.preventDefault();
        input.focus();
      }
    }
  }

  /* 1.10: seeds from the alerts panel; harmless nulls on a normal open */
  @api
  get openSalesOrderId() {
    return this._seedSo;
  }
  set openSalesOrderId(v) {
    this._seedSo = v;
    this._pendingSo = v || null;
    this.tryPendingOpen();
  }
  _seedSo = null;
  _pendingSo = null;

  /** Tab the seeded detail opens on: plan | owners | verify. */
  @api initialTab;

  /** Open the seeded booking as soon as the list holds it; a stale id just does nothing. */
  tryPendingOpen() {
    if (!this._pendingSo || !this.bookings.length) {
      return;
    }
    const id = this._pendingSo;
    this._pendingSo = null;
    if (this.bookings.some((x) => x.id === id)) {
      const tab = ["plan", "owners", "verify"].indexOf(this.initialTab) !== -1
        ? this.initialTab
        : "plan";
      this.openBookingById(id, tab);
    }
  }

  @wire(getMyBookings)
  wiredBookings(result) {
    this._wired = result;
    if (result.data) {
      this.bookings = result.data.bookings || [];
      this.awaiting = result.data.awaiting || [];
      this.loading = false;
      this.tryPendingOpen();
    } else if (result.error) {
      this.errorMsg = reduceError(result.error);
      this.loading = false;
    }
  }

  // formatting helpers
  /** The figure without its currency. */
  numberOf(v) {
    const n = Number(v);
    if (v == null || isNaN(n)) {
      return BLANK;
    }
    return n.toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }
  createdMs(b) {
    const t = b.createdDate ? new Date(b.createdDate).getTime() : 0;
    return isNaN(t) ? 0 : t;
  }
  /** 1.17: the value, or an empty cell. */
  dash(v) {
    return v && String(v).trim() ? v : BLANK;
  }
  /** 1.17: the value, or "Not set" where an empty field would read as a fault. */
  orNotSet(v) {
    return v && String(v).trim() ? v : NOT_SET;
  }
  /**
   * 1.16: the stored status, or "Settled" once MODON has closed the sale.
   */
  shownStatus(b) {
    if (!b) {
      return "";
    }
    return b.saleClosed === true ? SETTLED_TEXT : b.status;
  }
  /**
   * 1.16: Resume only on an unfinished order with an opportunity, never on a closed sale.
   */
  resumable(b) {
    return (
      !!b &&
      b.saleClosed !== true &&
      RESUMABLE.indexOf(b.status) !== -1 &&
      !!b.opportunityId
    );
  }
  /** Chip colour by stored Sales Order status. */
  statusChipClass(status) {
    const v = String(status || "").toLowerCase();
    if (!v) {
      return "chip chip--muted";
    }
    /* 1.16: a closed sale uses the Completed chip */
    if (status === SETTLED_TEXT) {
      return "chip chip--ok";
    }
    if (v === "new") {
      return "chip chip--new";
    }
    if (v === "sold" || v === "completed") {
      return "chip chip--ok";
    }
    if (
      v.indexOf("cancel") !== -1 ||
      v.indexOf("void") !== -1 ||
      v.slice(-4) === "- sr"
    ) {
      return "chip chip--warn";
    }
    return "chip chip--progress";
  }

  // toolbar
  /** R2-04: the shortcut hint as this keyboard writes it (Cmd on a Mac, Ctrl elsewhere). */
  get kbdMod() {
    return isApplePlatform() ? "\u2318" : "Ctrl";
  }
  get searchClass() {
    return this.search ? "search has" : "search";
  }
  get hasSearch() {
    return !!this.search;
  }
  /** Every row the pane holds: the orders, then the ones still waiting for money. */
  get allRows() {
    return this.bookings.concat(this.awaiting);
  }

  /**
   * MSC-220. The statuses actually present, live ones before cancelled ones, each in the order
   * it was first met. That ordering is the only opinion the pane holds about MODON's
   * vocabulary - it never renames a status and never hides one.
   */
  get statusesSeen() {
    const live = [];
    const dead = [];
    this.allRows.forEach((b) => {
      /* 1.16: a closed sale counts under Settled, not under its stored New */
      const s = this.shownStatus(b);
      if (!s || live.indexOf(s) !== -1 || dead.indexOf(s) !== -1) {
        return;
      }
      if (b.dead === true) {
        dead.push(s);
      } else {
        live.push(s);
      }
    });
    return live.concat(dead);
  }

  /** MSC-220: All, then one tab per stored status, each carrying its own count. */
  get statusTabs() {
    const all = this.allRows;
    const tabs = [{ value: TAB_ALL, label: "All", count: all.length }];
    this.statusesSeen.forEach((s) => {
      tabs.push({
        value: s,
        label: s,
        count: all.filter((b) => this.shownStatus(b) === s).length
      });
    });
    return tabs.map((t) => ({
      ...t,
      key: t.value,
      cls: t.value === this.statusTab ? "tab tab--on" : "tab",
      selected: t.value === this.statusTab ? "true" : "false"
    }));
  }

  /**
   * MSC-220. One field per column, in the order the pane has always had them. Customer, Value
   * and Date sort on a click; the rest are plain headings and the last is the action slot.
   */
  get headColumns() {
    return [
      { key: "ref", label: "Booking", sortable: false, num: false },
      { key: "unit", label: "Unit", sortable: false, num: false },
      { key: "name", label: "Customer", sortable: true, num: false },
      { key: "value", label: "Value", sortable: true, num: true },
      { key: "status", label: "Status", sortable: false, num: false },
      { key: "date", label: "Date", sortable: true, num: false },
      { key: "act", label: "", sortable: false, num: false }
    ].map((c) => {
      const on = c.sortable && this.sortKey === c.key;
      const asc = this.sortDir === "asc";
      return {
        ...c,
        /* h-sortable is what the phone layout keeps: the head collapses to its sort controls */
        cls: (c.num ? "h-amt " : "") + (c.sortable ? "h-sortable" : ""),
        btnClass: on ? "hsort hsort--on" : "hsort",
        arrow: on ? (asc ? "▲" : "▼") : "",
        showArrow: on,
        sortLabel: "Sort by " + c.label
      };
    });
  }

  // filtering + sorting
  keep(b) {
    /* MSC-220: two kinds of cut - every row, or one exact stored status */
    if (this.statusTab !== TAB_ALL && this.shownStatus(b) !== this.statusTab) {
      return false;
    }
    const term = this.search.trim().toLowerCase();
    if (!term) {
      return true;
    }
    return (
      [b.bookingRef, b.unitName, b.customerName]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .indexOf(term) !== -1
    );
  }
  /**
   * MSC-218. What the hold is doing, in priority order: the unit is gone (nothing else
   * matters), the hold ran out, no hold was ever stamped, or the countdown.
   * MSC-220: this is the status chip's tooltip now, not a second line in the cell.
   */
  holdLine(a) {
    if (a.unitAvailable === false) {
      return "Unit no longer available";
    }
    if (a.holdExpired) {
      return "Hold expired";
    }
    /* "Held until -" said nothing; a blank expiry means there is no hold to report */
    if (!a.holdExpiry) {
      return "No hold";
    }
    return "Held until " + formatTime(a.holdExpiry);
  }

  /**
   * MSC-170: the sort runs across the whole list, so awaiting and booked rows interleave.
   * MSC-220: the column header drives it. `dir` is +1 ascending, -1 descending, and every
   * comparator is written ascending so the one multiplication turns all three around.
   */
  sortRows(list) {
    const dir = this.sortDir === "asc" ? 1 : -1;
    const key = this.sortKey;
    return [...list].sort((a, b) => {
      if (key === "name") {
        return (
          (a.customerName || "").localeCompare(b.customerName || "") * dir ||
          b.sortMs - a.sortMs
        );
      }
      if (key === "value") {
        return (a.sortAmount - b.sortAmount) * dir || b.sortMs - a.sortMs;
      }
      /* date: a bigger timestamp is newer, so descending is newest first */
      return (a.sortMs - b.sortMs) * dir;
    });
  }

  // rows
  /**
   * MSC-220. Both row shapes fill the same seven columns, one field to a column, and a column
   * with nothing to put in it is left blank: a dash reads as a value, and columns of them was
   * what made the old grid unreadable. A fee request carries no booking reference, so that cell
   * is simply empty on those rows.
   */
  get rows() {
    /* waiting for money: a fee line, no Sales Order behind it */
    const awaiting = this.awaiting
      .filter((a) => this.keep(a))
      .map((a) => {
        const created = this.createdMs(a);
        return {
          key: "aw-" + a.id,
          isAwait: true,
          opportunityId: a.opportunityId,
          bookingRef: "",
          unitText: a.unitName || "",
          customerName: a.customerName || "",
          amountText: a.balance == null ? "" : formatAED(a.balance),
          statusText: a.status || "",
          hasStatus: !!a.status,
          chipClass: this.statusChipClass(a.status),
          /* MSC-218 kept as the chip's tooltip: the hold state still matters, but it is not
             worth a second line in a table business asked to keep plain */
          holdTitle: this.holdLine(a),
          /* resuming into a unit that is no longer for sale walks into "already booked" */
          canResume: a.unitAvailable !== false,
          blockedText: BLOCKED_TEXT,
          createdText: created ? formatDate(a.createdDate) : "",
          /* the sort keys, so one comparator serves both row shapes */
          sortMs: created,
          sortAmount: Number(a.balance) || 0
        };
      });
    const booked = this.bookings.filter((b) => this.keep(b)).map((b) => {
      const created = this.createdMs(b);
      /* 1.16: "Settled" for a sale MODON has closed, else the stored status */
      const shown = this.shownStatus(b);
      return {
        key: b.id,
        id: b.id,
        isAwait: false,
        bookingRef: b.bookingRef || "",
        openLabel: "Open " + (b.bookingRef || "booking"),
        unitText: b.unitName || "",
        customerName: b.customerName || "",
        amountText: b.totalAmount == null ? "" : formatAED(b.totalAmount),
        statusText: shown || "",
        hasStatus: !!shown,
        chipClass: this.statusChipClass(shown),
        holdTitle: "",
        createdText: created ? formatDate(b.createdDate) : "",
        // Resume needs an Opportunity, and never on a closed sale (1.16)
        canResume: this.resumable(b),
        sortMs: created,
        sortAmount: Number(b.totalAmount) || 0
      };
    });
    /* MSC-170: sorted as one list */
    return this.sortRows(awaiting.concat(booked));
  }

  get hasRows() {
    return this.rows.length > 0;
  }
  get showHead() {
    return !this.loading && this.hasRows;
  }
  get isEmpty() {
    return (
      !this.loading && this.bookings.length === 0 && this.awaiting.length === 0
    );
  }
  get showToolbar() {
    return !this.isEmpty;
  }
  /** MSC-220: counted tabs only once there is something to count - "All 0" over a skeleton lies. */
  get showTabs() {
    return !this.loading && !this.isEmpty;
  }
  get noMatch() {
    return !this.loading && !this.isEmpty && !this.hasRows;
  }
  get isList() {
    return !this.bookingId;
  }
  get isDetail() {
    return !!this.bookingId;
  }


  /* paging: client-side, page size measured against the pane's visible height (c/mscPaging.fitPageSize) */
  page = 1;
  pageSize = PAGE_DEFAULT;
  _resizeObserver;
  _onResize;
  _fitRaf = 0;
  _fitTimer;

  startPaging() {
    this._onResize = () => this.scheduleFit();
    if (typeof ResizeObserver !== "undefined") {
      this._resizeObserver = new ResizeObserver(this._onResize);
      this._resizeObserver.observe(this.template.host);
    } else {
      window.addEventListener("resize", this._onResize);
    }
    // measure once more after the sheet's open animation
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._fitTimer = window.setTimeout(() => this.scheduleFit(), 400);
  }
  stopPaging() {
    if (this._resizeObserver) {
      this._resizeObserver.disconnect();
      this._resizeObserver = null;
    } else if (this._onResize) {
      window.removeEventListener("resize", this._onResize);
    }
    if (this._fitRaf) {
      window.cancelAnimationFrame(this._fitRaf);
      this._fitRaf = 0;
    }
    window.clearTimeout(this._fitTimer);
  }
  renderedCallback() {
    this.fitNow();
  }
  scheduleFit() {
    if (this._fitRaf) {
      return;
    }
    this._fitRaf = window.requestAnimationFrame(() => {
      this._fitRaf = 0;
      this.fitNow();
    });
  }
  fitNow() {
    if (!(this.isList)) {
      return;
    }
    /* MSC-221: the rows sit flush now, so the pitch is the row height with no gap added.
       Leaving the helper's default of 8 would reserve a gap that no longer exists and fit
       one row fewer than the pane can actually hold. */
    const n = fitPageSize(this.template, this.template.host, 0);
    if (n && n !== this.pageSize) {
      const first = (this.currentPage - 1) * this.pageSize;
      this.pageSize = n;
      this.page = Math.floor(first / n) + 1;
    }
  }
  get pageTotal() {
    return this.rows.length;
  }
  get pageCountValue() {
    return pageCount(this.pageTotal, this.pageSize);
  }
  get currentPage() {
    return clampPage(this.page, this.pageCountValue);
  }
  /** The rows on the current page. */
  get paged() {
    const start = (this.currentPage - 1) * this.pageSize;
    return this.rows.slice(start, start + this.pageSize);
  }
  get showPager() {
    return this.showHead;
  }
  get pageInfoText() {
    return pageInfo(this.currentPage, this.pageSize, this.pageTotal);
  }
  get pageItems() {
    return pageItems(this.currentPage, this.pageCountValue);
  }
  get pageCompact() {
    return this.currentPage + " / " + this.pageCountValue;
  }
  get isFirstPage() {
    return this.currentPage <= 1;
  }
  get isLastPage() {
    return this.currentPage >= this.pageCountValue;
  }
  goPage(e) {
    const v = e.currentTarget.dataset.page;
    const cur = this.currentPage;
    const next = v === "prev" ? cur - 1 : v === "next" ? cur + 1 : Number(v);
    this.page = clampPage(next, this.pageCountValue);
    // a new page starts at the top
    this.template.host.scrollTop = 0;
  }

  handleSearch(e) {
    this.search = e.target.value;
    this.page = 1;
  }
  clearSearch() {
    this.search = "";
    this.page = 1;
  }
  /** MSC-220: the status tabs above the grid. Named apart from the detail's own setTab. */
  setStatusTab(e) {
    const v = e.currentTarget.dataset.tab;
    if (!v) {
      return;
    }
    this.statusTab = v;
    this.page = 1;
  }
  /**
   * MSC-220: click-to-sort column headers, in place of the Sort dropdown. The same column
   * again turns it around; a new one opens the way that column reads best.
   */
  sortBy(e) {
    const key = e.currentTarget.dataset.key;
    if (!key) {
      return;
    }
    if (this.sortKey === key) {
      this.sortDir = this.sortDir === "asc" ? "desc" : "asc";
    } else {
      this.sortKey = key;
      this.sortDir = SORT_FIRST_DIR[key] || "desc";
    }
    this.page = 1;
  }
  clearFilters(e) {
    if (e) {
      e.preventDefault();
    }
    this.statusTab = TAB_ALL;
    this.search = "";
    this.page = 1;
  }

  // detail
  handleRowKey(e) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      this.openBooking(e);
    }
  }
  openBooking(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) {
      return;
    }
    this.openBookingById(id, "plan");
  }
  /* 1.10: split from openBooking so a seed can open a detail without a row event */
  async openBookingById(id, tab) {
    this._openRow = this.bookings.find((x) => x.id === id) || null;
    this.bookingId = id;
    this.tab = tab || "plan";
    this.booking = null;
    // a new booking: the previous one's counts must not label its tabs
    this.ownersCount = null;
    this.verifiedCount = null;
    this.verifiableCount = null;
    this.detailLoading = true;
    this.errorMsg = "";
    try {
      this.booking = await getBooking({ salesOrderId: id });
    } catch (err) {
      this.errorMsg = reduceError(err);
    }
    this.detailLoading = false;
    this.report(id);
  }

  /** Back to the list, unless the owners pane has a question first (a unit left without a joint owner). */
  backToList() {
    const pane = this.template.querySelector("c-msc-owners-pane");
    if (pane && pane.holdsLeave) {
      pane.askBeforeLeaving();
      return;
    }
    this.leaveDetail();
  }

  /** They answered it. */
  handleLeaveConfirmed() {
    this.leaveDetail();
  }

  leaveDetail() {
    this.bookingId = null;
    this.booking = null;
    this._openRow = null;
    this.ownersCount = null;
    this.verifiedCount = null;
    this.verifiableCount = null;
    this.report(null);
  }

  /* three figures, all the panel's own */
  handleOwnersCount(e) {
    const d = e.detail || {};
    this.ownersCount = d.count || 0;
    this.verifiedCount = d.verified || 0;
    this.verifiableCount = d.verifiable || 0;
  }

  /** The summary behind the header. */
  get summary() {
    if (this.booking && this.booking.summary) {
      return this.booking.summary;
    }
    return this._openRow;
  }
  get headerRef() {
    const s = this.summary;
    return s ? this.dash(s.bookingRef) : "";
  }
  get headerStatus() {
    const s = this.summary;
    return s ? this.dash(this.shownStatus(s)) : "";
  }
  get headerChipClass() {
    const s = this.summary;
    return this.statusChipClass(s ? this.shownStatus(s) : "");
  }
  get headerSub() {
    const s = this.summary;
    if (!s) {
      return "";
    }
    return [s.unitName, s.customerName].filter(Boolean).join(" · ");
  }
  get headerCanResume() {
    return this.resumable(this.summary);
  }

  /** The facts card. */
  get facts() {
    const s = this.summary;
    if (!s) {
      return [];
    }
    /* R2-14: a sale MODON closed reads Settled; a "New" stage beside it would contradict it */
    const staleStage =
      s.saleClosed === true && OPEN_STAGES.indexOf(String(s.subStatus || "").trim().toLowerCase()) !== -1;
    return [
      { key: "unit", label: "Unit", value: this.orNotSet(s.unitName), cls: "" },
      { key: "cust", label: "Customer", value: this.orNotSet(s.customerName), cls: "" },
      { key: "total", label: "Total price", value: formatAED(s.totalAmount), cls: "" },
      { key: "status", label: "Status", value: this.orNotSet(this.shownStatus(s)), cls: "wrap" },
      { key: "stage", label: "Stage", value: this.orNotSet(s.subStatus), cls: "wrap" },
      { key: "created", label: "Created", value: formatDate(s.createdDate), cls: "" }
    ].filter((f) => !(staleStage && f.key === "stage"));
  }

  /** The badge, from the pane once it has spoken and from getBooking until then. */
  get partyCount() {
    if (this.ownersCount !== null && this.ownersCount !== undefined) {
      return this.ownersCount;
    }
    return (this.booking && this.booking.partyCount) || 0;
  }

  /** Verification's badge is a fraction; the denominator is the server's verifiableCount. */
  get verifyBadge() {
    const total =
      this.verifiableCount !== null && this.verifiableCount !== undefined
        ? this.verifiableCount
        : (this.booking && this.booking.verifiableCount) || 0;
    if (!total) {
      return "";
    }
    const done =
      this.verifiedCount !== null && this.verifiedCount !== undefined
        ? this.verifiedCount
        : (this.booking && this.booking.verifiedCount) || 0;
    return `${done}/${total}`;
  }

  get tabs() {
    return TABS.filter(
      (t) => t.key !== "documents" || SHOW_DOCUMENTS
    ).map((t) => {
      const count =
        t.key === "plan"
          ? this.paymentRows.length
          : t.key === "documents"
            ? this.documentRows.length
            : t.key === "verify"
              ? this.verifyBadge
              : this.partyCount;
      return {
        ...t,
        count,
        /* an empty badge reads as a bug; the tab carries its name alone */
        showCount: count !== "" && count !== null && count !== undefined,
        pressed: t.key === this.tab ? "true" : "false"
      };
    });
  }
  setTab(e) {
    this.tab = e.currentTarget.dataset.key;
  }
  get isPlan() {
    return this.tab === "plan";
  }
  get isDocuments() {
    return this.tab === "documents";
  }
  get isOwners() {
    return this.tab === "owners";
  }
  get isVerify() {
    return this.tab === "verify";
  }
  /** One pane behind two tabs. */
  get isOwnersPane() {
    return this.isOwners || this.isVerify;
  }
  get paneView() {
    return this.isVerify ? "verify" : "owners";
  }

  get paymentRows() {
    if (!this.booking) {
      return [];
    }
    return (this.booking.installments || []).map((i) => ({
      ...i,
      key: i.id,
      number: i.milestoneNumber == null ? BLANK : i.milestoneNumber,
      amountLabel: formatAED(i.amount),
      dueLabel: formatDate(i.dueDate),
      statusText: this.orNotSet(i.paymentStatus),
      chipClass: PAY_CHIP[i.paymentStatus] || "chip chip--muted",
      title: i.description || `Milestone ${i.milestoneNumber}`
    }));
  }
  get hasPaymentRows() {
    return this.paymentRows.length > 0;
  }
  get paidNumber() {
    return this.numberOf(this.booking ? this.booking.paidTotal : null);
  }
  get scheduledLabel() {
    return this.booking ? formatAED(this.booking.scheduledTotal) : BLANK;
  }
  get paidCount() {
    return this.paymentRows.filter((r) => r.paymentStatus === "Paid").length;
  }
  get planCount() {
    return this.paymentRows.length;
  }
  get paidPct() {
    const b = this.booking;
    if (!b || !b.scheduledTotal || Number(b.scheduledTotal) <= 0) {
      return 0;
    }
    const pct = Math.round((Number(b.paidTotal) / Number(b.scheduledTotal)) * 100);
    return Math.max(0, Math.min(100, pct));
  }
  get barStyle() {
    return "width:" + this.paidPct + "%";
  }

  /* the server decides what counts as received and the order */
  get documentRows() {
    if (!this.booking) {
      return [];
    }
    return (this.booking.documents || []).map((d) => ({
      key: d.id,
      name: d.name,
      statusText: this.orNotSet(d.status),
      receivedLabel: d.received ? formatDate(d.receivedOn) : BLANK,
      chipClass: DOC_CHIP[d.status] || "chip chip--muted"
    }));
  }
  get hasDocuments() {
    return this.documentRows.length > 0;
  }
  get docsReceived() {
    return this.booking ? this.booking.documentsReceived || 0 : 0;
  }
  get docsTotal() {
    return this.booking ? this.booking.documentsTotal || 0 : 0;
  }
  get docsPct() {
    const total = this.docsTotal;
    if (!total) {
      return 0;
    }
    const pct = Math.round((this.docsReceived / total) * 100);
    return Math.max(0, Math.min(100, pct));
  }
  get docsBarStyle() {
    return "width:" + this.docsPct + "%";
  }
  /* what is left to chase */
  get docsOutstandingLabel() {
    const left = Math.max(0, this.docsTotal - this.docsReceived);
    if (left === 0) {
      return "Nothing outstanding";
    }
    return left === 1 ? "1 still outstanding" : left + " still outstanding";
  }

  /** Hand an unfinished booking back to the journey. */
  resumeBooking(e) {
    e.stopPropagation();
    const id = e.currentTarget.dataset.id;
    const b = this.bookings.find((x) => x.id === id);
    /* 1.16: a closed sale is never handed back to the journey */
    if (!b || !b.opportunityId || b.saleClosed === true) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("resumebooking", {
        /* bookingId: the journey opens on this order; the names let the sheet header say which */
        detail: {
          bookingId: id,
          opportunityId: b.opportunityId,
          bookingRef: b.bookingRef,
          unitName: b.unitName,
          customerName: b.customerName
        },
        bubbles: true,
        composed: true
      })
    );
  }

  /** The same handover from a row with no Sales Order; the journey reopens on the payment step. */
  resumeAwaiting(e) {
    e.stopPropagation();
    const opportunityId = e.currentTarget.dataset.opp;
    if (!opportunityId) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("resumebooking", {
        detail: { bookingId: null, opportunityId },
        bubbles: true,
        composed: true
      })
    );
  }

  /** A completed booking moves the hub's numbers. */
  refresh() {
    if (this._wired) {
      refreshApex(this._wired);
    }
  }

  report(bookingId) {
    this.dispatchEvent(
      new CustomEvent("bookingchange", {
        detail: { bookingId },
        bubbles: true,
        composed: true
      })
    );
  }
}