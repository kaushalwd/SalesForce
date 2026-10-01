/**
 * My Leads pane.
 *
 * Version  Author      Date         Detail
 * 1.22     Aurelix Dev 30 Sep 2026  Cards, not the 950px grid, on a phone on its side (UI-20); no dash as a blank:
 *                                   empty grid cells, "Not set" in the drawer's facts (UI-21); Ctrl K off a Mac (R2-04).
 * 1.21     Aurelix Dev 29 Sep 2026  Template only: the handover tooltip and the empty-state sentence no
 *                                   longer use an em dash.
 * 1.20     Aurelix Dev 02 Sep 2026  MSC-223. The Total Sales table treatment, applied here: the
 *                                   rows stop being cards (no border, radius or gap - one
 *                                   surface parted by a --divider hairline), the five tracks
 *                                   are evened onto one 20px gap, and the headings and cells
 *                                   centre in their tracks. Lead stays anchored left: its
 *                                   40px avatar is a mark the eye reads down, and centring the
 *                                   pair would slide it about as names change length. CSS,
 *                                   plus fitPageSize told the gap is 0.
 * 1.19     Aurelix Dev 02 Sep 2026  MSC-215. Creating a lead raises `leadschanged` too - the
 *                                   hub count moved only for drawer writes before.
 * 1.18     Aurelix Dev 02 Sep 2026  MSC-212. The dead startBooking handler removed: the drawer
 *                                   emits `startbooking` itself (composed, through this list to
 *                                   the workspace), and the old opportunityId guard could never
 *                                   pass against this list's unconverted-only rows.
 * 1.17     Aurelix Dev 02 Sep 2026  MSC-211. What a rep sees after a write is what the org
 *                                   holds: the refresh keeps their page, the open drawer is
 *                                   rebuilt from the raw rows (not the filtered cut, which
 *                                   left it frozen on pre-save data), a lead that has left the
 *                                   rep's book closes the drawer and says why, and the pane
 *                                   raises `leadschanged` so the hub count and the bell badge
 *                                   refresh with it. toCard extracted from the cards getter.
 * 1.16     Aurelix Dev 02 Sep 2026  MSC-210. A qualified lead queued for round-robin handover
 *                                   carries a quiet 'handover' marker beside its status. Marker
 *                                   only: the row stays listed and workable, because the org
 *                                   clears ReAssignRRToSalesAssociate__c unreliably.
 * 1.15     Aurelix Dev 31 Aug 2026  MSC-189. The alerts panel can seed this pane: `initial-filter`
 *                                   preselects an obligation cut (over/today), `open-lead-id`
 *                                   opens that lead's drawer once the list has loaded. Both are
 *                                   additive and null on a normal open.
 * 1.14     Aurelix Dev 31 Aug 2026  MSC-186 fix. Next Call renders from epoch millis
 *                                   (SummaryDTO.dueAtMs), never Datetime strings - parsing
 *                                   those is ambiguous about UTC.
 * 1.13     Aurelix Dev 31 Aug 2026  MSC-186. Column header 'Call due' -> 'Next Call', sort
 *                                   label to match (business choice). Labels only.
 * 1.12     Aurelix Dev 31 Aug 2026  MSC-186 fix. Rows and their activity columns land in one
 *                                   paint (summaries fetched before assignment); skeletons only
 *                                   when there is nothing to show, so a reload never stacks
 *                                   loading bars above real rows.
 * 1.11     Aurelix Dev 31 Aug 2026  MSC-186. Lead activities: the grid becomes Lead - Status -
 *                                   Source - Last outcome - Call due, sorted by the open call
 *                                   task's due; obligation filters (Overdue/Today/Call open/No
 *                                   call); a row opens c/mscLeadDrawer, which dispositions the
 *                                   task. Columns read SalesConsoleActivityController.getSummaries.
 * 1.10     Aurelix Dev 31 Aug 2026  MSC-185. New lead hidden for now (business ask): toolbar button
 *                                   and empty-state CTA off. Markup and one CSS track only.
 * 1.9      Aurelix Dev 22 Aug 2026  MSC-114. Phone shape gate; a routed lead is said; closed hits tell the truth.
 * 1.8      Aurelix Dev 22 Aug 2026  MSC-111. Layout and theme only.
 * 1.7      Aurelix Dev 22 Aug 2026  MSC-110. The New lead form asks residency, nationality and the identity set.
 * 1.6      Aurelix Dev 21 Aug 2026  MSC-109. A Company column.
 * 1.5      Aurelix IT  19 Aug 2026  New-lead slide-over header tidied.
 * 1.4      Aurelix IT  18 Aug 2026  The expanded row is off; phone card carries the fields.
 * 1.3      Aurelix IT  18 Aug 2026  Redesigned as a data grid (MSC-054).
 * 1.2      Aurelix IT  12 Aug 2026  Backend waits raise c-msc-loader.
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonLeadList onto the standard Lead.
 */

import { LightningElement, api, wire } from "lwc";
import getRecentLeads from "@salesforce/apex/SalesConsoleLeadController.getRecentLeads";
import searchLeads from "@salesforce/apex/SalesConsoleLeadController.searchLeads";
/* createLeadDetailed, not the five-argument createLead */
import createLeadDetailed from "@salesforce/apex/SalesConsoleLeadController.createLeadDetailed";
import getProjectOptions from "@salesforce/apex/SalesConsoleLeadController.getProjectOptions";
/* the same picklists the console's qualify panel reads; static per org */
import getLeadQualifyOptions from "@salesforce/apex/SalesConsoleLeadController.getLeadQualifyOptions";
/* 1.11: the Last outcome / Call due columns, one round trip for the loaded page of leads */
import getSummaries from "@salesforce/apex/SalesConsoleActivityController.getSummaries";
import { LABELS } from "c/mscLabels";
import { identityNeedsFor, identitySetComplete, isValidPhone } from "c/mscEoiUtils";
import { initials, reduceError } from "c/modonSalesFormat";
import {
  fitPageSize,
  pageCount,
  clampPage,
  pageInfo,
  pageItems,
  PAGE_DEFAULT
} from "c/mscPaging";

/** Search is server-side past this length. */
const SEARCH_MIN = 2;
const SEARCH_DEBOUNCE_MS = 300;
/** The duplicate hint asks the server once the phone is long enough. */
const DUP_MIN = 4;
/** Matches the slide-over's transform transition. */
const SLIDE_MS = 300;

/* 1.11: the obligation cuts that replaced the status segments. The predicate reads the row's
   activity summary; `s` may be undefined for a lead with no tasks at all. */
const FILTERS = [
  { key: "all", label: "All", test: () => true },
  { key: "over", label: "Overdue", test: (s) => !!s && !!s.taskId && s.overdue },
  { key: "today", label: "Today", test: (s) => !!s && !!s.taskId && !s.overdue && isToday(s.dueAtMs) },
  { key: "open", label: "Call open", test: (s) => !!s && !!s.taskId },
  { key: "none", label: "No call", test: (s) => !s || !s.taskId }
];

function isToday(ms) {
  const t = Number(ms);
  if (!t) {
    return false;
  }
  const d = new Date(t);
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
}

const MIN_MS = 60 * 1000;
const HOUR_MS = 3600 * 1000;
const DAY_MS = 24 * HOUR_MS;
/** Leads with nothing booked sort after every real due. */
const NO_DUE = Number.MAX_SAFE_INTEGER;
/* 1.22 - UI-21: no dash as a blank. A grid cell stays empty; a named fact says "Not set". */
const DASH = "";
const NOT_SET = "Not set";

/* 1.22 - R2-04: the search shortcut as this keyboard writes it (as c/mscBookings 1.17) */
function isApplePlatform() {
  try {
    const nav = typeof navigator !== "undefined" ? navigator : null;
    const p = (nav && ((nav.userAgentData && nav.userAgentData.platform) || nav.platform)) || "";
    return /mac|iphone|ipad|ipod/i.test(p);
  } catch (e) {
    return false;
  }
}

export default class MscLeadList extends LightningElement {
  leads = [];
  loading = true;
  errorMsg = "";
  /* where a routed lead went; cleared by dismiss or the next New lead */
  queuedNotice = "";
  /* the phone error shows on blur */
  phoneTouched = false;
  search = "";
  filter = "all";
  /* 1.11: the open call task's due orders the day */
  sort = "due";
  /** leadId -> SummaryDTO (taskId, dueAt, overdue, lastOutcome). */
  summaries = {};
  /* 1.11: the work drawer */
  drawerOpen = false;
  activeLead = null;

  /* 1.15: seeds from the alerts panel; harmless nulls on a normal open */
  @api
  get initialFilter() {
    return this._seedFilter;
  }
  set initialFilter(v) {
    this._seedFilter = v;
    if (v && FILTERS.some((f) => f.key === v)) {
      this.filter = v;
    }
  }
  _seedFilter = null;

  @api
  get openLeadId() {
    return this._openLeadId;
  }
  set openLeadId(v) {
    this._openLeadId = v;
    this._pendingOpen = v || null;
    this.tryPendingOpen();
  }
  _openLeadId = null;
  _pendingOpen = null;

  /** Open the seeded lead's drawer as soon as its row exists; a stale id just does nothing. */
  tryPendingOpen() {
    if (!this._pendingOpen || !this.leads.length) {
      return;
    }
    const card = this.cards.find((c) => c.id === this._pendingOpen);
    if (card) {
      this.activeLead = card;
      this.drawerOpen = true;
    }
    this._pendingOpen = null;
  }

  showNewForm = false;
  saving = false;
  projects = [];
  form = {
    firstName: "",
    lastName: "",
    phone: "",
    email: "",
    interest: "",
    /* what conversion demands */
    residentStatus: "",
    nationality: ""
  };
  /* the identity set, held apart from form so c/msc-identity-fields can own its shape */
  formIdentity = {};
  /** Picklists behind residency and nationality. */
  qualifyOptions = {};
  labels = LABELS;
  /** {id, name} of the rep's own open lead that already carries the typed phone. */
  duplicate = null;

  _searchTimer;
  _keyHandler;
  _focusTimer;

  /** The project list is a real picklist read; it is required on Lead. */
  @wire(getProjectOptions)
  wiredProjects({ data }) {
    if (data) {
      this.projects = data;
      if (!this.form.interest && data.length) {
        this.form = { ...this.form, interest: data[0] };
      }
    }
  }

  /** Static per org. */
  @wire(getLeadQualifyOptions)
  wiredQualifyOptions({ data }) {
    if (data) {
      this.qualifyOptions = data;
    }
  }

  get residentChoices() {
    return (this.qualifyOptions.residentStatus || []).map((v) => ({
      value: v,
      selected: this.form.residentStatus === v
    }));
  }
  get nationalityChoices() {
    return (this.qualifyOptions.nationality || []).map((v) => ({
      value: v,
      selected: this.form.nationality === v
    }));
  }

  /* the identity fields' changes land here */
  handleIdentity(event) {
    const { field, value } = event.detail;
    this.formIdentity = { ...this.formIdentity, [field]: value };
  }

  connectedCallback() {
    // Cmd/Ctrl+K focuses search; Escape closes the slide-over
    this._keyHandler = (e) => this.handleDocumentKey(e);
    document.addEventListener("keydown", this._keyHandler);
    this.startPaging();
    this.load();
  }

  disconnectedCallback() {
    document.removeEventListener("keydown", this._keyHandler);
    this.stopPaging();
    window.clearTimeout(this._searchTimer);
    window.clearTimeout(this._focusTimer);
  }

  handleDocumentKey(e) {
    if ((e.metaKey || e.ctrlKey) && (e.key === "k" || e.key === "K")) {
      const input = this.template.querySelector(".search input");
      if (input) {
        e.preventDefault();
        input.focus();
      }
      return;
    }
    if (e.key === "Escape" && this.showNewForm) {
      // consumed here: modonSheet listens for Escape on window
      e.stopPropagation();
      this.cancelNewForm();
    }
  }

  /**
   * @param {boolean} keepPage 1.17: true only for a refresh AFTER a write - the rep stays on
   * the page they were working. Every other caller (open, search, filter, create) still starts
   * at page 1, where the row they are looking for will be.
   */
  async load(keepPage) {
    this.loading = true;
    this.errorMsg = "";
    if (!keepPage) {
      this.page = 1;
    }
    try {
      const term = this.search.trim();
      const rows =
        term.length >= SEARCH_MIN
          ? await searchLeads({ term })
          : await getRecentLeads();
      /* 1.12: fetched BEFORE the rows are shown - leads and their activity columns land in one
         paint, so no skeleton ever sits above real rows */
      const summaries = await this.fetchSummaries(rows);
      this.leads = rows;
      this.summaries = summaries;
      /* 1.15: an alerts card may have asked for one lead's drawer */
      this.tryPendingOpen();
    } catch (e) {
      this.errorMsg = reduceError(e);
    }
    this.loading = false;
  }

  /** The activity columns; a failure leaves the columns dashed, never the list broken. */
  async fetchSummaries(rows) {
    const ids = (rows || []).map((l) => l.id);
    if (!ids.length) {
      return {};
    }
    try {
      const out = await getSummaries({ leadIds: ids });
      const map = {};
      (out || []).forEach((s) => {
        map[s.leadId] = s;
      });
      return map;
    } catch (ignore) {
      return {};
    }
  }

  // status helpers
  shortStatus(status) {
    const s = status || "";
    return s.indexOf(" - ") !== -1 ? s.split(" - ")[1] : s;
  }

  // toolbar
  /** 1.22 - R2-04: Cmd on a Mac, Ctrl elsewhere. */
  get kbdMod() {
    return isApplePlatform() ? "⌘" : "Ctrl";
  }
  get searchClass() {
    return this.search ? "search has" : "search";
  }
  get hasSearch() {
    return !!this.search;
  }

  /** 1.11: obligation segments with counts - the same cuts, without breaking the page apart. */
  get segments() {
    return FILTERS.map((f) => ({
      key: f.key,
      label: f.label,
      count: this.leads.filter((l) => f.test(this.summaries[l.id])).length,
      pressed: f.key === this.filter ? "true" : "false"
    }));
  }

  get sortOptions() {
    return [
      { value: "due", label: "Next Call" },
      { value: "recent", label: "Newest" },
      { value: "name", label: "Name A to Z" }
    ].map((o) => ({ ...o, selected: o.value === this.sort }));
  }
  setSort(e) {
    this.sort = e.target.value;
    this.page = 1;
  }

  // filtering
  get filtered() {
    const term = this.search.trim().toLowerCase();
    const cut = FILTERS.find((f) => f.key === this.filter) || FILTERS[0];
    return this.leads.filter((l) => {
      if (!cut.test(this.summaries[l.id])) {
        return false;
      }
      if (!term) {
        return true;
      }
      // the server has already matched; this only narrows what came back
      return (
        (l.name || "").toLowerCase().indexOf(term) !== -1 ||
        (l.email || "").toLowerCase().indexOf(term) !== -1 ||
        (l.phone || "").toLowerCase().indexOf(term) !== -1 ||
        (l.mobile || "").toLowerCase().indexOf(term) !== -1 ||
        (l.company || "").toLowerCase().indexOf(term) !== -1
      );
    });
  }

  // sorting
  /** The open call task's due, as a number; nothing booked sorts last. */
  dueMs(l) {
    const s = this.summaries[l.id];
    const t = s ? Number(s.dueAtMs) : 0;
    return t || NO_DUE;
  }
  get sorted() {
    const list = this.filtered;
    if (this.sort === "name") {
      return [...list].sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    }
    if (this.sort === "recent") {
      return list; // the query already returns newest-first
    }
    /* 'due' - overdue first, then today, then scheduled, then nothing booked */
    return [...list].sort(
      (a, b) => this.dueMs(a) - this.dueMs(b) || this.createdMs(b) - this.createdMs(a)
    );
  }

  // rows
  createdMs(l) {
    const t = l.createdDate ? new Date(l.createdDate).getTime() : 0;
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
  dash(v) {
    return v && String(v).trim() ? v : NOT_SET;
  }

  /** 1.11: "2d overdue" / "in 3 h" / "in 12 min". */
  dueLabel(ms, overdue) {
    const t = Number(ms);
    if (!t) {
      return DASH;
    }
    const abs = Math.abs(t - Date.now());
    let span;
    if (abs < HOUR_MS) {
      span = Math.max(1, Math.round(abs / MIN_MS)) + " min";
    } else if (abs < DAY_MS) {
      span = Math.round(abs / HOUR_MS) + " h";
    } else {
      span = Math.round(abs / DAY_MS) + "d";
    }
    return overdue ? span + " overdue" : "in " + span;
  }

  /**
   * 1.17: one row, shaped for the grid and for the drawer's header. Extracted from the cards
   * getter unchanged, so a lead the current cut filters out can still be rebuilt for the open
   * drawer.
   */
  toCard(l) {
    const short = this.shortStatus(l.status);
    const s = this.summaries[l.id];
    const overdue = !!s && !!s.taskId && !!s.overdue;
    return {
        id: l.id,
        name: l.name || DASH,
        initials: initials(l.name),
        statusText: this.dash(short),
        /* 1.16: qualified and queued for handover - said, never hidden (the org clears the
           flag unreliably; a row filtered on it could vanish for days) */
        pendingReassign: l.pendingReassign === true,
        /* the drawer's header facts; mobile falls back to phone */
        mobileText: this.dash(l.mobile || l.phone),
        emailText: this.dash(l.email),
        projectText: this.dash(l.projectInterest),
        sourceText: this.dash(l.leadSource),
        /* 1.11: the activity columns */
        lastOutcomeText: s && s.lastOutcome ? s.lastOutcome : DASH,
        dueText: s && s.taskId ? this.dueLabel(s.dueAtMs, overdue) : DASH,
        dueClass: overdue ? "cell mono due due--warn" : s && s.taskId ? "cell mono due" : "cell mono due due--none",
      rowClass: overdue ? "row-main row-main--attn" : "row-main"
    };
  }

  get cards() {
    return this.sorted.map((l) => this.toCard(l));
  }

  /* 1.11: the work drawer */
  openDrawer(e) {
    const id = e.currentTarget.dataset.id;
    const card = this.cards.find((c) => c.id === id);
    if (!card) {
      return;
    }
    this.activeLead = card;
    this.drawerOpen = true;
  }
  rowKey(e) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      this.openDrawer(e);
    }
  }
  closeDrawer() {
    this.drawerOpen = false;
  }
  /**
   * A write landed. 1.17: reload the rows and their activity columns, keep the rep on the page
   * they were working, and rebuild the open drawer from the RAW rows - a lead the current cut
   * no longer matches (dispositioned out of "Overdue", say) is still the lead being worked, and
   * the old code left it frozen on pre-save data. The drawer closes only when the lead has left
   * the rep's book entirely - a qualified lead handed to another associate - and says so once.
   * Ancestors are told either way (`leadschanged`), so the hub count and the bell badge stop
   * showing a number the rep has already changed.
   */
  async handleDrawerChanged() {
    const active = this.activeLead;
    /* both queries return newest-first, and a disposition cannot change what a search matches,
       so this is a stable identity of the rep's book - it differs only when a lead really
       joined or left it */
    const before = this.leads.map((l) => l.id).join(",");
    await this.load(true);
    const rosterChanged = before !== this.leads.map((l) => l.id).join(",");
    if (active) {
      const row = this.leads.find((l) => l.id === active.id);
      if (row) {
        this.activeLead = this.toCard(row);
      } else {
        this.queuedNotice = LABELS.LEAD_HANDED_OVER.replace("{0}", active.name);
        this.drawerOpen = false;
        this.activeLead = null;
      }
    }
    /* the bell always re-reads (any disposition can change what is overdue); the hub's counts
       only when the book itself changed, so a routine call log costs no extra query there */
    this.dispatchEvent(
      new CustomEvent("leadschanged", {
        detail: { rosterChanged },
        bubbles: true,
        composed: true
      })
    );
  }

  get hasLeads() {
    return this.cards.length > 0;
  }
  /* 1.12: rows shown = header shown; a reload keeps the old rows (and header) in place
     instead of flashing skeletons over them */
  get showHead() {
    return this.hasLeads;
  }
  get showSkeleton() {
    return this.loading && this.leads.length === 0;
  }
  get isEmpty() {
    return !this.loading && this.leads.length === 0;
  }
  get noMatch() {
    return !this.loading && this.leads.length > 0 && this.cards.length === 0;
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
    // the list is always the pane's content here
    /* MSC-223: the rows sit flush now, so the pitch is the row height with no gap added.
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
    return this.cards.length;
  }
  get pageCountValue() {
    return pageCount(this.pageTotal, this.pageSize);
  }
  get currentPage() {
    return clampPage(this.page, this.pageCountValue);
  }
  /** The cards on the current page. */
  get paged() {
    const start = (this.currentPage - 1) * this.pageSize;
    return this.cards.slice(start, start + this.pageSize);
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
    // debounced: every keystroke past two characters is a round trip
    window.clearTimeout(this._searchTimer);
    this._searchTimer = window.setTimeout(() => this.load(), SEARCH_DEBOUNCE_MS);
  }
  clearSearch() {
    this.search = "";
    this.load();
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
    this.load();
  }

  /* 1.18 (MSC-212): the dead startBooking handler is gone. The drawer emits `startbooking`
     itself (composed, so it crosses this component on its way to the workspace) - and its old
     opportunityId guard could never pass here: this list queries unconverted leads only. */

  // new lead
  get projectOptions() {
    return this.projects.map((p) => ({
      label: p,
      value: p,
      selected: p === this.form.interest
    }));
  }
  get slideClass() {
    return this.showNewForm ? "slide slide--open" : "slide";
  }
  get scrimClass() {
    return this.showNewForm ? "scrim scrim--open" : "scrim";
  }
  get slideHidden() {
    return this.showNewForm ? "false" : "true";
  }

  openNewForm() {
    this.showNewForm = true;
    this.errorMsg = "";
    this.queuedNotice = "";
    window.clearTimeout(this._focusTimer);
    this._focusTimer = window.setTimeout(() => {
      const first = this.template.querySelector(".slide input");
      if (first) {
        first.focus();
      }
    }, SLIDE_MS);
  }
  cancelNewForm() {
    this.showNewForm = false;
    this.duplicate = null;
    this.phoneTouched = false;
    this.form = {
      firstName: "",
      lastName: "",
      phone: "",
      email: "",
      interest: this.projects.length ? this.projects[0] : "",
      residentStatus: "",
      nationality: ""
    };
    this.formIdentity = {};
  }
  handleField(e) {
    this.form = { ...this.form, [e.target.dataset.field]: e.target.value };
  }

  /** "You already have this lead": advisory only, never blocks. */
  async checkDuplicate(e) {
    this.phoneTouched = true;
    const term = (e.target.value || "").trim();
    if (term.length < DUP_MIN) {
      this.duplicate = null;
      return;
    }
    try {
      const hits = await searchLeads({ term });
      const hit = (hits || []).find(
        (l) =>
          (l.phone && l.phone.indexOf(term) !== -1) ||
          (l.mobile && l.mobile.indexOf(term) !== -1)
      );
      // only if the phone is still the one we checked
      if ((this.form.phone || "").trim() === term) {
        /* status travels too */
        this.duplicate = hit ? { id: hit.id, name: hit.name, status: hit.status } : null;
      }
    } catch (ignore) {
      this.duplicate = null;
    }
  }
  get hasDuplicate() {
    return !!this.duplicate;
  }
  get duplicateName() {
    return this.duplicate ? this.duplicate.name : "";
  }
  /** The truth about a closed hit; {0} = status. */
  get duplicateClosedNote() {
    const st = this.duplicate && this.duplicate.status;
    return st === "Retired" || st === "Duplicate"
      ? LABELS.LEAD_DUP_CLOSED.replace("{0}", st)
      : "";
  }

  /* the phone shape gate: blank is fine; a non-blank value must be the shape Mobile_Phone_Mandatory_Check demands */
  get phoneShapeOk() {
    const raw = (this.form.phone || "").trim();
    return !raw || isValidPhone(raw.replace(/\s/g, ""));
  }
  get phoneError() {
    return this.phoneTouched && !this.phoneShapeOk ? LABELS.LEAD_PHONE_SHAPE : "";
  }
  /** Close the slide-over and show the existing lead. */
  openDuplicate(e) {
    e.preventDefault();
    const term = (this.form.phone || "").trim();
    this.cancelNewForm();
    this.filter = "all";
    this.search = term;
    this.load();
  }

  get canSave() {
    /* residency, nationality and the identity set (c/mscEoiUtils.identitySetComplete) */
    return (
      !!this.form.lastName.trim() &&
      !!this.form.interest &&
      !!this.form.residentStatus &&
      !!this.form.nationality &&
      identitySetComplete(this.form.residentStatus, this.formIdentity, null) &&
      /* a shape the org would refuse never leaves */
      this.phoneShapeOk &&
      !this.saving
    );
  }
  get saveDisabled() {
    return !this.canSave;
  }
  get saveLabel() {
    return this.saving ? "Saving…" : "Save lead";
  }

  async saveLead() {
    if (!this.canSave) {
      return;
    }
    this.saving = true;
    this.errorMsg = "";
    try {
      /* only the set this residency needs is sent */
      const needs = identityNeedsFor(this.form.residentStatus);
      const v = this.formIdentity || {};
      const res = await createLeadDetailed({
        firstName: this.form.firstName,
        lastName: this.form.lastName,
        phone: this.form.phone,
        email: this.form.email,
        projectInterest: this.form.interest,
        nationality: this.form.nationality,
        residentStatus: this.form.residentStatus,
        eidNumber: needs.eidNumber ? (v.eidNumber || "").trim() || null : null,
        passportNumber: needs.passportNumber ? (v.passportNumber || "").trim() || null : null,
        eidExpiry: needs.eidExpiry ? v.eidExpiry || null : null,
        passportIssueDate: needs.passportIssueDate ? v.passportIssueDate || null : null,
        passportExpiry: needs.passportExpiryDate ? v.passportExpiryDate || null : null
      });
      this.cancelNewForm();
      /* say where the lead actually went; the owner is named verbatim off the record */
      this.queuedNotice =
        res && res.queued
          ? LABELS.LEAD_QUEUED.replace("{0}", res.ownerName || "")
          : "";
      // the saved lead appears at the top
      this.filter = "all";
      this.search = "";
      this.sort = "recent";
      await this.load();
      /* MSC-215: a created-and-kept lead moves the hub's open-leads count; one routed away by
         the assignment engine does not change this rep's book (the bell re-reads either way) */
      this.dispatchEvent(
        new CustomEvent("leadschanged", {
          detail: { rosterChanged: !(res && res.queued) },
          bubbles: true,
          composed: true
        })
      );
    } catch (e) {
      this.errorMsg = reduceError(e);
    }
    this.saving = false;
  }

  dismissQueuedNotice() {
    this.queuedNotice = "";
  }

  /** The save is shown and blocked; the list load shows skeleton rows. */
  get isBusy() {
    return !!this.saving;
  }
}