/**
 * Expressions of Interest pane.
 *
 * Version  Author      Date         Detail
 * 2.1      Aurelix Dev 30 Sep 2026  The search hint reads Ctrl K off a Mac and the Command sign on a Mac, as
 *                                   c/mscBookings does.
 * 2.0      Aurelix Dev 18 Sep 2026  MSC-181 (B9). The EOI number (EOIId__c, e.g. EOI-VYN4B9) is
 *                                   shown under the reference and is searchable. The Book unit
 *                                   door already seeds the journey with the EOI (1.8).
 * 1.9      MODON Dev   10 Sep 2026  Authorize-and-capture: the check action treats the EOI
 *                                   existing as the result, not the payment being captured. A held
 *                                   payment births the EOI too, and gating on isCaptured left the
 *                                   rep with no toast while the row silently left the list.
 * 1.8      Aurelix Dev 03 Sep 2026  MSC-231 (W5). The Book unit door: rows the org booking engine
 *                                   itself lists as eligible (getBookableEoiIds, per visible page)
 *                                   carry a Book unit action; the workspace opens the booking
 *                                   journey seeded with that opportunity and EOI.
 * 1.7      Aurelix Dev 02 Sep 2026  MSC-229. Pay-first leaves paid-nothing-yet links invisible,
 *                                   so Awaiting payment joins the segments: its own full-height
 *                                   paged view of the rep's open links (full payment reference,
 *                                   stored status chips, expiry, Resend link + a check that
 *                                   polls Checkout on the spot). A capture found by the manual
 *                                   check toasts the born EOI's name and re-reads the list.
 *                                   Both tables move to the sales order pane's anatomy: one
 *                                   continuous surface, hairline dividers, centred headings,
 *                                   hover as a wash. Blanks stay blank (the em-dash is gone).
 * 1.6      Aurelix Dev 31 Aug 2026  MSC-183. New EOI restored: toolbar button and empty-state CTA
 *                                   back on startCreate. Markup and one CSS track only.
 * 1.5      Aurelix IT  19 Aug 2026  New EOI hidden for now (business ask); the journey stays wired.
 * 1.4      Aurelix IT  18 Aug 2026  Initials avatar dropped.
 * 1.3      Aurelix IT  18 Aug 2026  Redesigned as a data grid (MSC-055).
 * 1.2      Aurelix IT  17 Aug 2026  The full journey (c/mscEoiJourney) inside this sheet; Pay-now return.
 * 1.1      Aurelix IT  13 Aug 2026  Raise one, not just read them.
 * 1.0      Aurelix IT  09 Aug 2026  Ports modonEoiCreation / modonEoiPayment onto real records.
 */

import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyEois from "@salesforce/apex/SalesConsoleEoiController.getMyEois";
import getAwaitingPayments from "@salesforce/apex/SalesConsoleEoiJourneyController.getAwaitingPayments";
import resendPaymentLink from "@salesforce/apex/SalesConsoleEoiJourneyController.resendPaymentLink";
import confirmPayment from "@salesforce/apex/SalesConsoleEoiJourneyController.confirmPayment";
import getBookableEoiIds from "@salesforce/apex/SalesConsoleEoiJourneyController.getBookableEoiIds";
import { reduceError } from "c/modonSalesFormat";
import {
  fitPageSize,
  pageCount,
  clampPage,
  pageInfo,
  pageItems,
  PAGE_DEFAULT
} from "c/mscPaging";

/** The org's EOI statuses in lifecycle order; drives the segment order and the Status sort. */
const STATUS_ORDER = [
  "New",
  "In Progress",
  "Submitted",
  "Pending With Finance",
  "Approved",
  "EOI Confirmed",
  "Completed",
  "Voided",
  "Expired",
  "Rejected",
  "Cancelled"
];

/** Chip colour by status. */
const STATUS_CHIP = {
  New: "chip chip--new",
  "In Progress": "chip chip--progress",
  Submitted: "chip chip--progress",
  "Pending With Finance": "chip chip--progress",
  Approved: "chip chip--ok",
  "EOI Confirmed": "chip chip--ok",
  Completed: "chip chip--ok",
  Voided: "chip chip--warn",
  Expired: "chip chip--warn",
  Rejected: "chip chip--warn",
  Cancelled: "chip chip--warn"
};

const HOUR_MS = 3600 * 1000;
const MIN_MS = 60 * 1000;
const BLANK = "";

/** Stored payment-link statuses only. */
const AWAIT_CHIP = {
  "Link Created": "chip chip--progress",
  Authorized: "chip chip--progress",
  Expired: "chip chip--warn"
};

/* 2.1: the search shortcut as this keyboard writes it (as c/mscBookings 1.17) */
function isApplePlatform() {
  try {
    const nav = typeof navigator !== "undefined" ? navigator : null;
    const p = (nav && ((nav.userAgentData && nav.userAgentData.platform) || nav.platform)) || "";
    return /mac|iphone|ipad|ipod/i.test(p);
  } catch (e) {
    return false;
  }
}

export default class MscEoi extends LightningElement {
  eois = [];
  loading = true;
  errorMsg = "";
  search = "";
  filter = "all";
  sort = "recent";

  /* the journey lives here: `creating` swaps the list for c/mscEoiJourney; a Pay-now return
   * carries paymentResult + ref in the URL */
  creating = false;
  paymentReturnResult;
  paymentReturnRef;
  _wiredEois;
  _keyHandler;

  /* MSC-229: the rep's open payment links (no EOI exists for these yet) */
  awaiting = [];
  awaitingLoaded = false;
  busyResendId = null;
  sentResendId = null;
  busyCheckId = null;
  toast = null; // { eoiName }
  _toastTimer;
  _sentTimer;

  connectedCallback() {
    this.readPaymentReturn();
    this.loadAwaiting();
    // Cmd/Ctrl+K focuses search
    this._keyHandler = (e) => this.handleDocumentKey(e);
    document.addEventListener("keydown", this._keyHandler);
    this.startPaging();
  }

  disconnectedCallback() {
    document.removeEventListener("keydown", this._keyHandler);
    this.stopPaging();
    window.clearTimeout(this._toastTimer);
    window.clearTimeout(this._sentTimer);
  }

  /* MSC-229: the open links are re-read wherever the list itself is */
  async loadAwaiting() {
    try {
      this.awaiting = (await getAwaitingPayments()) || [];
    } catch (e) {
      // the records view stands on its own; the segment simply shows what loaded
      this.awaiting = [];
    } finally {
      this.awaitingLoaded = true;
    }
  }

  handleDocumentKey(e) {
    if (this.creating) {
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

  readPaymentReturn() {
    let params;
    try {
      params = new URLSearchParams(window.location.search);
    } catch {
      return;
    }
    const result = params.get("paymentResult");
    if (!result) return;
    this.paymentReturnResult = result;
    this.paymentReturnRef = params.get("ref") || "";
    this.creating = true;
    try {
      const url = new URL(window.location.href);
      url.searchParams.delete("paymentResult");
      url.searchParams.delete("ref");
      window.history.replaceState(window.history.state, "", url.toString());
    } catch {
      // a stale param is harmless
    }
  }

  @wire(getMyEois)
  wired(result) {
    this._wiredEois = result;
    if (result.data) {
      this.eois = result.data;
      this.loading = false;
    } else if (result.error) {
      this.errorMsg = reduceError(result.error);
      this.loading = false;
    }
  }

  startCreate() {
    this.creating = true;
  }

  cancelCreate() {
    this.creating = false;
    this.paymentReturnResult = undefined;
    this.paymentReturnRef = undefined;
    this.loadAwaiting();
  }

  /** The new EOI belongs in the list, so the list is re-read. */
  handleCreated(event) {
    if (this._wiredEois) {
      refreshApex(this._wiredEois);
    }
    this.loadAwaiting();
    // the new one is newest
    this.page = 1;
    // let the workspace refresh its caption
    this.dispatchEvent(
      new CustomEvent("eoicreated", {
        bubbles: true,
        composed: true,
        detail: event?.detail || {}
      })
    );
  }

  // status helpers
  statusRank(status) {
    const i = STATUS_ORDER.indexOf(status);
    return i === -1 ? STATUS_ORDER.length : i;
  }
  /** The statuses present in the loaded list. */
  get statusesSeen() {
    const seen = [];
    this.eois.forEach((e) => {
      if (e.status && seen.indexOf(e.status) === -1) {
        seen.push(e.status);
      }
    });
    return seen.sort((a, b) => this.statusRank(a) - this.statusRank(b));
  }

  // toolbar
  get searchClass() {
    return this.search ? "search has" : "search";
  }
  get hasSearch() {
    return !!this.search;
  }

  /** Status segments with counts. */
  get segments() {
    const all = [{ key: "all", label: "All", count: this.eois.length }];
    this.statusesSeen.forEach((s) => {
      all.push({
        key: s,
        label: s,
        count: this.eois.filter((e) => e.status === s).length
      });
    });
    all.push({ key: "awaiting", label: "Awaiting payment", count: this.awaiting.length });
    return all.map((f) => ({
      ...f,
      pressed: f.key === this.filter ? "true" : "false"
    }));
  }

  get isAwaiting() {
    return this.filter === "awaiting";
  }
  /** 2.1: Cmd on a Mac, Ctrl elsewhere. */
  get kbdMod() {
    return isApplePlatform() ? "\u2318" : "Ctrl";
  }

  get searchPlaceholder() {
    return this.isAwaiting ? "Search payment reference or customer" : "Search reference, customer or project";
  }

  get sortOptions() {
    return [
      { value: "recent", label: "Newest" },
      { value: "oldest", label: "Oldest" },
      { value: "amount", label: "Amount high–low" },
      { value: "status", label: "Status" }
    ].map((o) => ({ ...o, selected: o.value === this.sort }));
  }
  setSort(e) {
    this.sort = e.target.value;
    this.page = 1;
  }

  // filtering
  get filtered() {
    const term = this.search.trim().toLowerCase();
    return this.eois.filter((e) => {
      if (this.filter !== "all" && e.status !== this.filter) {
        return false;
      }
      if (!term) {
        return true;
      }
      // the whole list is loaded (200 cap), so search is client-side
      return (
        (e.name || "").toLowerCase().indexOf(term) !== -1 ||
        (e.customerName || "").toLowerCase().indexOf(term) !== -1 ||
        (e.eoiNumber || "").toLowerCase().indexOf(term) !== -1 ||
        (e.projectName || "").toLowerCase().indexOf(term) !== -1
      );
    });
  }

  // sorting
  get sorted() {
    const list = this.filtered;
    if (this.sort === "amount") {
      return [...list].sort(
        (a, b) =>
          (Number(b.amount) || 0) - (Number(a.amount) || 0) ||
          this.createdMs(b) - this.createdMs(a)
      );
    }
    if (this.sort === "status") {
      return [...list].sort(
        (a, b) =>
          this.statusRank(a.status) - this.statusRank(b.status) ||
          this.createdMs(b) - this.createdMs(a)
      );
    }
    if (this.sort === "oldest") {
      return [...list].sort((a, b) => this.createdMs(a) - this.createdMs(b));
    }
    return list; // 'recent' - the query already returns newest-first
  }

  // rows
  createdMs(e) {
    const t = e.createdDate ? new Date(e.createdDate).getTime() : 0;
    return isNaN(t) ? 0 : t;
  }
  /** "just now", "6h ago", "2d ago". */
  ageLabel(ms) {
    const h = Math.floor(ms / HOUR_MS);
    if (h < 1) {
      return "just now";
    }
    if (h < 24) {
      return h + "h ago";
    }
    return Math.floor(h / 24) + "d ago";
  }
  dateOf(ms) {
    return new Date(ms).toLocaleDateString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric"
    });
  }
  /** "AED 10,000"; fractions keep two places. */
  aed(v) {
    if (v == null || v === "") {
      return BLANK;
    }
    const n = Number(v);
    if (isNaN(n)) {
      return BLANK;
    }
    return (
      "AED " +
      n.toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 })
    );
  }
  dash(v) {
    return v && String(v).trim() ? v : BLANK;
  }

  get rows() {
    const now = Date.now();
    return this.sorted.map((e) => {
      const created = this.createdMs(e);
      const hasCreated = created > 0;
      return {
        id: e.id,
        name: this.dash(e.name),
        /* 2.0 - the customer-facing number; blank stays blank */
        eoiNumber: e.eoiNumber || "",
        customerName: this.dash(e.customerName),
        projectText: this.dash(e.projectName),
        amountText: this.aed(e.amount),
        statusText: this.dash(e.status),
        chipClass: STATUS_CHIP[e.status] || "chip chip--muted",
        createdText: hasCreated ? this.dateOf(created) : BLANK,
        ageText: hasCreated ? this.ageLabel(now - created) : "",
        /* MSC-231: the org booking engine's own answer, fetched per visible page */
        canBook: this.bookable[e.id] === true,
        opportunityId: e.opportunityId
      };
    });
  }

  /* ── MSC-231: the Book unit door ─────────────────────────────────────────
   * Bookability is the org engine's verdict (getCompletedEOIs via getBookableEoiIds),
   * asked for the rows on screen only. The fetch is keyed by the visible id set, so
   * paging, sorting and searching each refresh it exactly once; a failed read simply
   * shows no buttons - the journey and the engine remain the authority either way. */
  bookable = {};
  _bookableKey = "";
  /* called from the component's one renderedCallback (paging owns it) */
  async refreshBookable() {
    if (this.isAwaiting || this.creating) {
      return;
    }
    const ids = this.paged.map((r) => r.id).filter(Boolean);
    const key = ids.join(",");
    if (!key || key === this._bookableKey) {
      return;
    }
    this._bookableKey = key;
    try {
      const bookableIds = (await getBookableEoiIds({ eoiIds: ids })) || [];
      /* stale response guard: only the answer to the current page applies */
      if (this._bookableKey !== key) {
        return;
      }
      const map = {};
      bookableIds.forEach((id) => {
        map[id] = true;
      });
      this.bookable = map;
    } catch (e) {
      if (this._bookableKey === key) {
        this.bookable = {};
      }
    }
  }

  /** The door: hand the workspace this row's opportunity and EOI; it opens the journey. */
  handleBook(event) {
    const id = event.currentTarget?.dataset?.id;
    const row = (this.eois || []).find((e) => e.id === id);
    if (!row || !row.opportunityId) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("bookunit", {
        detail: { opportunityId: row.opportunityId, eoiId: row.id }
      })
    );
  }

  /** "in 31 min" / "25 min ago" beside the stored expiry time. */
  relativeTo(ms, now) {
    const d = ms - now;
    const abs = Math.abs(d);
    let span;
    if (abs < HOUR_MS) {
      span = Math.max(1, Math.round(abs / MIN_MS)) + " min";
    } else if (abs < 24 * HOUR_MS) {
      const h = Math.floor(abs / HOUR_MS);
      const m = Math.round((abs % HOUR_MS) / MIN_MS);
      span = m ? h + " h " + m + " min" : h + " h";
    } else {
      span = Math.floor(abs / (24 * HOUR_MS)) + " d";
    }
    return d >= 0 ? "in " + span : span + " ago";
  }
  timeOf(ms) {
    return new Date(ms).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
  }

  get awaitingFiltered() {
    const term = this.search.trim().toLowerCase();
    if (!term) {
      return this.awaiting;
    }
    return this.awaiting.filter(
      (a) =>
        (a.reference || "").toLowerCase().indexOf(term) !== -1 ||
        (a.customerName || "").toLowerCase().indexOf(term) !== -1 ||
        (a.projectName || "").toLowerCase().indexOf(term) !== -1
    );
  }

  /** The same Sort control drives this view; Status follows the link lifecycle. */
  awaitStatusRank(status) {
    const order = ["Link Created", "Authorized", "Expired"];
    const i = order.indexOf(status);
    return i === -1 ? order.length : i;
  }
  get awaitingSorted() {
    const list = this.awaitingFiltered;
    const created = (a) => (a.createdDate ? new Date(a.createdDate).getTime() : 0);
    if (this.sort === "amount") {
      return [...list].sort((a, b) => (Number(b.amount) || 0) - (Number(a.amount) || 0) || created(b) - created(a));
    }
    if (this.sort === "status") {
      return [...list].sort((a, b) => this.awaitStatusRank(a.status) - this.awaitStatusRank(b.status) || created(b) - created(a));
    }
    if (this.sort === "oldest") {
      return [...list].sort((a, b) => created(a) - created(b));
    }
    return list; // 'recent' - the query returns newest-first
  }

  get awaitingRows() {
    const now = Date.now();
    return this.awaitingSorted.map((a) => {
      const exp = a.expiresOn ? new Date(a.expiresOn).getTime() : 0;
      const resent = a.id === this.sentResendId;
      return {
        id: a.id,
        reference: this.dash(a.reference),
        customerName: this.dash(a.customerName),
        projectText: this.dash(a.projectName),
        amountText: this.aed(a.amount),
        statusText: this.dash(a.status),
        chipClass: AWAIT_CHIP[a.status] || "chip chip--muted",
        expiresText: exp ? this.timeOf(exp) : BLANK,
        expiresAgeText: exp ? this.relativeTo(exp, now) : "",
        canResend: a.canResend === true && !resent,
        resent,
        resendBusy: a.id === this.busyResendId,
        checkBusy: a.id === this.busyCheckId,
        checkClass: a.id === this.busyCheckId ? "btn-check spin" : "btn-check"
      };
    });
  }

  /** "Checked 18:52" - the newest stored poll stamp across the open links. */
  get checkedLabel() {
    let max = 0;
    this.awaiting.forEach((a) => {
      const t = a.lastPolled ? new Date(a.lastPolled).getTime() : 0;
      if (t > max) max = t;
    });
    return max ? "Checked " + this.timeOf(max) : "";
  }

  get awaitingEmpty() {
    return this.isAwaiting && this.awaitingLoaded && this.awaiting.length === 0;
  }
  get awaitingNoMatch() {
    return this.isAwaiting && this.awaiting.length > 0 && this.awaitingRows.length === 0;
  }

  /** Resend: the same stored link goes again by email and SMS. Nothing else moves. */
  async handleResend(e) {
    const id = e.currentTarget.dataset.id;
    if (!id || this.busyResendId) return;
    this.errorMsg = "";
    this.busyResendId = id;
    try {
      await resendPaymentLink({ paymentId: id });
      this.sentResendId = id; // the button reads "Sent" for a moment
      window.clearTimeout(this._sentTimer);
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._sentTimer = window.setTimeout(() => {
        this.sentResendId = null;
      }, 1600);
    } catch (err) {
      this.errorMsg = reduceError(err);
    } finally {
      this.busyResendId = null;
    }
  }

  /** Check now: poll Checkout for this one link. A hold or a capture births the EOI right here. */
  async handleCheck(e) {
    const id = e.currentTarget.dataset.id;
    const row = this.awaiting.find((a) => a.id === id);
    if (!row || this.busyCheckId) return;
    this.errorMsg = "";
    this.busyCheckId = id;
    try {
      const res = await confirmPayment({ reference: row.reference });
      if (res && res.eoiId) {
        this.showToast(res.eoiName || "EOI");
        if (this._wiredEois) {
          refreshApex(this._wiredEois);
        }
        this.dispatchEvent(
          new CustomEvent("eoicreated", { bubbles: true, composed: true, detail: { eoiIds: [res.eoiId] } })
        );
      } else if (res && !res.isSuccess && res.message) {
        this.errorMsg = res.message;
      }
    } catch (err) {
      this.errorMsg = reduceError(err);
    } finally {
      this.busyCheckId = null;
      this.loadAwaiting(); // statuses and poll stamps re-read either way
    }
  }

  showToast(eoiName) {
    this.toast = { eoiName };
    window.clearTimeout(this._toastTimer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._toastTimer = window.setTimeout(() => {
      this.toast = null;
    }, 4200);
  }

  get hasRows() {
    return this.rows.length > 0;
  }
  get showHead() {
    return !this.isAwaiting && !this.loading && this.hasRows;
  }
  get showAwaitHead() {
    return this.isAwaiting && this.awaitingRows.length > 0;
  }
  get isEmpty() {
    return !this.isAwaiting && !this.loading && this.eois.length === 0;
  }
  get noMatch() {
    return !this.isAwaiting && !this.loading && this.eois.length > 0 && !this.hasRows;
  }

  /** Whichever view is open feeds the one pager. */
  get tableRows() {
    return this.isAwaiting ? this.awaitingRows : this.rows;
  }
  get gridScrollClass() {
    return this.isAwaiting ? "grid-scroll grid-scroll--await" : "grid-scroll";
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
    /* MSC-231: the visible page's bookability (guarded by its id-set key) */
    this.refreshBookable();
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
    if (!(!this.creating)) {
      return;
    }
    const n = fitPageSize(this.template, this.template.host);
    if (n && n !== this.pageSize) {
      const first = (this.currentPage - 1) * this.pageSize;
      this.pageSize = n;
      this.page = Math.floor(first / n) + 1;
    }
  }
  get pageTotal() {
    return this.tableRows.length;
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
    return this.tableRows.slice(start, start + this.pageSize);
  }
  get showPager() {
    return this.showHead || this.showAwaitHead;
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
  setFilter(e) {
    this.filter = e.currentTarget.dataset.key;
    this.page = 1;
  }
  clearFilters(e) {
    if (e) {
      e.preventDefault();
    }
    this.filter = "all";
    this.search = "";
    this.page = 1;
  }
}