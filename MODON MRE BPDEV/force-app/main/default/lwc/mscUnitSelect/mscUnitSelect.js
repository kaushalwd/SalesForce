/**
 * Section 1 - Unit Selection.
 *
 * Version  Author      Date         Detail
 * 1.11     Aurelix Dev 30 Sep 2026  show-facts: a selected unit's card lists GSA, plot area and phase (price, bedrooms
 *                                   and typology are already on it) wherever the tour is not beside the list.
 * 1.10     Aurelix Dev 03 Sep 2026  MSC-231. eoi-preset: the EOI's typology/bedrooms preference
 *                                   arrives through this grid's own filters - applied once, only
 *                                   for values this stock actually has, never after the rep has
 *                                   touched the filters themselves. Nothing new is drawn.
 * 1.9      Aurelix IT  15 Aug 2026  Clear works end to end (both copies reset; select DOM value written).
 * 1.8      Aurelix IT  15 Aug 2026  The Broker Portal's smart filter, ported. Fixed-positioned popover;
 *                                   Project and Phase re-query and commit on change.
 * 1.7      Aurelix IT  12 Aug 2026  The empty state names its real cause.
 * 1.6      Aurelix IT  12 Aug 2026  Inline "Loading units..." removed.
 * 1.5      Aurelix IT  11 Aug 2026  Search box on the 44px control height.
 * 1.4      Aurelix IT  11 Aug 2026  Project and phase selects honour `busy`.
 * 1.3      Aurelix IT  09 Aug 2026  A list rather than a card grid.
 * 1.2      Aurelix IT  09 Aug 2026  Search, filters and a render cap.
 * 1.1      Aurelix IT  07 Aug 2026  Multi-select.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api } from "lwc";
import { formatAED } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";

/**
 * Search and a filter panel over the phase's stock. Filtering is client-side: getUnitDetails'
 * filter parameters are only read in the Modon Egypt branch. Filter fields checked against the
 * org: bedrooms, price, typology, plot area (UnitClassification__c is not in the SELECT).
 * Selection is a set, no cap.
 */

/** Rendered at once. */
const RENDER_CAP = 60;

const DEFAULT_SORT = "name";

/** Fixed price bands, not quantiles; empty bands are never rendered. */
const PRICE_BANDS = [
  { key: "p1", label: "Under AED 5M", min: 0, max: 5000000 },
  { key: "p2", label: "AED 5M – 10M", min: 5000000, max: 10000000 },
  { key: "p3", label: "AED 10M – 15M", min: 10000000, max: 15000000 },
  { key: "p4", label: "AED 15M – 20M", min: 15000000, max: 20000000 },
  { key: "p5", label: "AED 20M and above", min: 20000000, max: Infinity }
];

const PLOT_BANDS = [
  { key: "a1", label: "Under 500 sqm", min: 0, max: 500 },
  { key: "a2", label: "500 – 750 sqm", min: 500, max: 750 },
  { key: "a3", label: "750 – 1,000 sqm", min: 750, max: 1000 },
  { key: "a4", label: "1,000 – 1,500 sqm", min: 1000, max: 1500 },
  { key: "a5", label: "1,500 sqm and above", min: 1500, max: Infinity }
];

const SORT_OPTIONS = [
  { value: "name", label: "Unit number" },
  { value: "priceAsc", label: "Price, low to high" },
  { value: "priceDesc", label: "Price, high to low" },
  { value: "bedsDesc", label: "Bedrooms, high to low" }
];

/** Panel geometry, shared by the positioner and the stylesheet. */
const POP_WIDTH = 348;
const POP_MIN_HEIGHT = 260;
const POP_MAX_HEIGHT = 440;
const POP_GAP = 8;
const POP_EDGE = 12;

function bandKey(value, bands) {
  if (value === null || value === undefined || value === "") return "";
  const n = Number(value);
  if (!isFinite(n)) return "";
  const hit = bands.find((b) => n >= b.min && n < b.max);
  return hit ? hit.key : "";
}

export default class MscUnitSelect extends LightningElement {
  @api projectOptions = [];
  @api phaseOptions = [];
  @api units = [];
  @api selectedProjectId;
  @api selectedPhaseId;
  @api busy = false;

  /** Set by the journey when the walkthrough panel is on screen. */
  @api tourAvailable = false;
  /** 1.11: list the unit's remaining facts on its card once selected (the page passes true without the rail tour). */
  @api showFacts = false;

  /** The selection, as a list. */
  @api selectedUnitIds = [];

  labels = LABELS;

  /* applied filter state: what the list is filtered by */
  term = "";
  beds = "";
  typology = "";
  price = "";
  plot = "";
  sort = DEFAULT_SORT;

  /* pending filter state: what the panel is showing. Two copies, as in the source; Apply closes
     the gap. `term` is outside that scheme: search is incremental. */
  panelOpen = false;
  pendingBeds = "";
  pendingTypology = "";
  pendingPrice = "";
  pendingPlot = "";
  pendingSort = DEFAULT_SORT;

  /** Inline style for the fixed popover. */
  popStyle = "";
  popUp = false;

  _reposition;

  disconnectedCallback() {
    this.detachReposition();
  }

  /* the panel and the DOM agree */

  renderedCallback() {
    this.applyEoiPreset();
    this.syncSelectDom();
    // also covers the panel changing size
    if (this.panelOpen) {
      this.positionPanel();
    }
  }

  /* ── MSC-231: the EOI preference as a pre-set filter ──────────────────────
   * {typology, bedrooms, source} from the booking page. Applied exactly once, and only
   * values present in this stock (a preset must narrow, never blank the grid); a rep
   * who has already worked the filters is never overridden. */
  @api eoiPreset;
  _eoiPresetApplied = false;
  _filtersTouched = false;
  applyEoiPreset() {
    const p = this.eoiPreset;
    if (!p || this._eoiPresetApplied || this._filtersTouched) {
      return;
    }
    if (!(this.units || []).length) {
      return; // stock not in yet; renderedCallback tries again when it is
    }
    const d = this.decorated;
    const typOk = p.typology && d.some((x) => x.typKey === p.typology);
    const bedOk = p.bedrooms && d.some((x) => x.bedKey === p.bedrooms);
    this._eoiPresetApplied = true; // one attempt per mount, hit or miss
    if (!typOk && !bedOk) {
      return;
    }
    if (typOk) {
      this.typology = p.typology;
      this.pendingTypology = p.typology;
    }
    if (bedOk) {
      this.beds = p.bedrooms;
      this.pendingBeds = p.bedrooms;
    }
  }

  /** A touched <select> ignores the `selected` attribute, so .value is written after every render. */
  syncSelectDom() {
    const set = (selector, value) => {
      const el = this.template.querySelector(selector);
      if (!el) return;
      const next = value === null || value === undefined ? "" : String(value);
      if (el.value !== next) {
        el.value = next;
      }
    };
    set('select[data-f="beds"]', this.pendingBeds);
    set('select[data-f="price"]', this.pendingPrice);
    set('select[data-f="plot"]', this.pendingPlot);
    set('select[data-f="sort"]', this.pendingSort || DEFAULT_SORT);
    set("#fproj", this.selectedProjectId);
    set("#fphase", this.selectedPhaseId);
  }

  get selectedSet() {
    return new Set(this.selectedUnitIds || []);
  }

  /* UI-02: a row with no label or no id reached the list and drew an empty line under
     "Select a project…". The template already renders the placeholder, so drop them. */
  static named(rows) {
    return (rows || [])
      .map((p) => ({
        label: (p.label || p.Name || p.name || "").trim(),
        value: p.value || p.Id || p.id
      }))
      .filter((p) => p.label && p.value);
  }

  get projectChoices() {
    return MscUnitSelect.named(this.projectOptions).map((p) => ({
      ...p,
      selected: p.value === this.selectedProjectId
    }));
  }

  get phaseChoices() {
    return MscUnitSelect.named(this.phaseOptions).map((p) => ({
      ...p,
      selected: p.value === this.selectedPhaseId
    }));
  }

  /* the ported smart filter */

  /** Every unit reduced to the keys the filters compare on, once per render. */
  get decorated() {
    return (this.units || []).map((u) => ({
      u,
      id: u.Id,
      bedKey: u.Number_of_Bedrooms__c == null || u.Number_of_Bedrooms__c === ""
        ? ""
        : String(u.Number_of_Bedrooms__c),
      bedLabel: u.Number_of_Bedrooms__c ? `${u.Number_of_Bedrooms__c} bed` : "Not specified",
      bedValue: Number(u.Number_of_Bedrooms__c) || 0,
      typKey: u.Typology__c || "",
      typLabel: u.Typology__c || "Not specified",
      priceKey: bandKey(u.TotalPrice__c, PRICE_BANDS),
      plotKey: bandKey(u.PlotAreasqm__c, PLOT_BANDS),
      name: String(u.Name || "")
    }));
  }

  /** The cascade: every option list is built from the units that survive the other pending filters. */
  matchesCore(d, f) {
    if (f.beds && d.bedKey !== f.beds) return false;
    if (f.typology && d.typKey !== f.typology) return false;
    if (f.price && d.priceKey !== f.price) return false;
    if (f.plot && d.plotKey !== f.plot) return false;
    return true;
  }

  coreFiltered(f) {
    return this.decorated.filter((d) => this.matchesCore(d, f));
  }

  /** Counted options: an "any" row with the total, then one row per value with its count. */
  buildOptions(items, keyProp, labelProp, anyLabel, selected, order) {
    const counts = {};
    items.forEach((d) => {
      const key = d[keyProp];
      if (!key) return;
      if (!counts[key]) {
        counts[key] = { key, label: d[labelProp], count: 0, sortValue: d.bedValue };
      }
      counts[key].count += 1;
    });

    let rows = Object.keys(counts).map((k) => counts[k]);
    if (order === "numeric") {
      rows.sort((a, b) => a.sortValue - b.sortValue);
    } else if (Array.isArray(order)) {
      const rank = {};
      order.forEach((b, i) => {
        rank[b.key] = i;
      });
      rows.sort((a, b) => rank[a.key] - rank[b.key]);
    } else {
      rows.sort((a, b) => a.label.localeCompare(b.label));
    }

    return [{ key: "", label: anyLabel, count: items.length }, ...rows].map((o) => ({
      ...o,
      value: o.key,
      selected: o.key === (selected || "")
    }));
  }

  bandOptions(items, keyProp, bands, anyLabel, selected) {
    const counts = {};
    items.forEach((d) => {
      const key = d[keyProp];
      if (!key) return;
      counts[key] = (counts[key] || 0) + 1;
    });
    const rows = bands
      .filter((b) => counts[b.key])
      .map((b) => ({ key: b.key, label: b.label, count: counts[b.key] }));
    return [{ key: "", label: anyLabel, count: items.length }, ...rows].map((o) => ({
      ...o,
      value: o.key,
      selected: o.key === (selected || "")
    }));
  }

  get bedOptions() {
    return this.buildOptions(
      this.coreFiltered({
        typology: this.pendingTypology,
        price: this.pendingPrice,
        plot: this.pendingPlot
      }),
      "bedKey",
      "bedLabel",
      "All bedrooms",
      this.pendingBeds,
      "numeric"
    );
  }

  get priceOptions() {
    return this.bandOptions(
      this.coreFiltered({
        beds: this.pendingBeds,
        typology: this.pendingTypology,
        plot: this.pendingPlot
      }),
      "priceKey",
      PRICE_BANDS,
      "Any price",
      this.pendingPrice
    );
  }

  get plotOptions() {
    return this.bandOptions(
      this.coreFiltered({
        beds: this.pendingBeds,
        typology: this.pendingTypology,
        price: this.pendingPrice
      }),
      "plotKey",
      PLOT_BANDS,
      "Any plot size",
      this.pendingPlot
    );
  }

  /** The counted choice grid. */
  get typeOptions() {
    return this.buildOptions(
      this.coreFiltered({
        beds: this.pendingBeds,
        price: this.pendingPrice,
        plot: this.pendingPlot
      }),
      "typKey",
      "typLabel",
      "All unit types",
      this.pendingTypology
    ).map((o) => ({
      ...o,
      cls: o.selected ? "type-choice type-choice--on" : "type-choice"
    }));
  }

  get sortOptions() {
    return SORT_OPTIONS.map((o) => ({ ...o, selected: o.value === this.pendingSort }));
  }

  /** A pending value the cascade removed is reset. */
  reconcilePending() {
    const drop = (field, options) => {
      const v = this[field];
      if (v && !options.some((o) => o.key === v)) {
        this[field] = "";
      }
    };
    drop("pendingBeds", this.bedOptions);
    drop("pendingPrice", this.priceOptions);
    drop("pendingPlot", this.plotOptions);
    drop("pendingTypology", this.typeOptions);
  }

  // panel open / close

  togglePanel() {
    if (this.panelOpen) {
      this.closePanel();
      return;
    }
    // open onto what is applied
    this.syncPending();
    this.panelOpen = true;
    this.attachReposition();
    /* renderedCallback places it */
  }

  closePanel() {
    this.panelOpen = false;
    this.detachReposition();
  }

  syncPending() {
    this.pendingBeds = this.beds;
    this.pendingTypology = this.typology;
    this.pendingPrice = this.price;
    this.pendingPlot = this.plot;
    this.pendingSort = this.sort;
  }

  /** Escape closes the panel and goes no further (modonSheet listens on the window). */
  handlePanelKeydown(event) {
    if (event.key !== "Escape" || !this.panelOpen) return;
    event.stopPropagation();
    this.closePanel();
    const btn = this.template.querySelector(".filter-btn");
    if (btn) btn.focus();
  }

  // fixed positioning, because .body is a scrollport

  attachReposition() {
    if (this._reposition) return;
    this._reposition = () => this.positionPanel();
    // capture: the scroll happens on an ancestor scroller
    window.addEventListener("scroll", this._reposition, true);
    window.addEventListener("resize", this._reposition);
  }

  detachReposition() {
    if (!this._reposition) return;
    window.removeEventListener("scroll", this._reposition, true);
    window.removeEventListener("resize", this._reposition);
    this._reposition = undefined;
  }

  /**
   * Solved in viewport space, then translated: modonSheet's backdrop-filter and transform make it
   * the containing block for position:fixed. `.pop-probe` reports that offset.
   */
  positionPanel() {
    const btn = this.template.querySelector(".filter-btn");
    const pop = this.template.querySelector(".filter-pop");
    const probe = this.template.querySelector(".pop-probe");
    if (!btn || !pop || !probe) return;

    const r = btn.getBoundingClientRect();
    const origin = probe.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const width = Math.min(POP_WIDTH, vw - POP_EDGE * 2);

    // right-aligned to the trigger, clamped inside the viewport
    let vLeft = r.right - width;
    vLeft = Math.max(POP_EDGE, Math.min(vLeft, vw - width - POP_EDGE));

    const roomBelow = vh - r.bottom - POP_GAP - POP_EDGE;
    const roomAbove = r.top - POP_GAP - POP_EDGE;
    const openUp = roomBelow < POP_MIN_HEIGHT && roomAbove > roomBelow;

    const maxHeight = Math.max(
      POP_MIN_HEIGHT,
      Math.min(POP_MAX_HEIGHT, openUp ? roomAbove : roomBelow)
    );
    const vTop = openUp
      ? Math.max(POP_EDGE, r.top - POP_GAP - maxHeight)
      : r.bottom + POP_GAP;

    // the arrow tracks the trigger after the clamp
    const arrowX = Math.max(16, Math.min(r.left + r.width / 2 - vLeft, width - 16));

    const style =
      `left:${Math.round(vLeft - origin.left)}px;top:${Math.round(vTop - origin.top)}px;` +
      `width:${Math.round(width)}px;max-height:${Math.round(maxHeight)}px;` +
      `--arrow-x:${Math.round(arrowX)}px`;

    /* assign only on a real change, or renderedCallback loops */
    if (this.popUp !== openUp) {
      this.popUp = openUp;
    }
    if (this.popStyle !== style) {
      this.popStyle = style;
    }
  }

  get popClass() {
    return this.popUp ? "filter-pop filter-pop--up" : "filter-pop";
  }

  // handlers

  handleTerm(event) {
    this.term = event.target.value || "";
  }

  handleTermClear() {
    this.term = "";
    const input = this.template.querySelector(".search__input");
    if (input) input.focus();
  }

  get showTermClear() {
    return !!this.term;
  }

  handlePendingSelect(event) {
    const key = event.currentTarget.dataset.f;
    const value = event.target.value || "";
    if (key === "beds") this.pendingBeds = value;
    else if (key === "price") this.pendingPrice = value;
    else if (key === "plot") this.pendingPlot = value;
    else if (key === "sort") {
      this.pendingSort = value || DEFAULT_SORT;
      // sort narrows nothing
      return;
    }
    this.reconcilePending();
  }

  handlePendingType(event) {
    this.pendingTypology = event.currentTarget.dataset.type || "";
    this.reconcilePending();
  }

  applyFilters() {
    this._filtersTouched = true; // MSC-231: the rep's own filtering outranks the EOI preset
    this.reconcilePending();
    this.beds = this.pendingBeds;
    this.typology = this.pendingTypology;
    this.price = this.pendingPrice;
    this.plot = this.pendingPlot;
    this.sort = this.pendingSort || DEFAULT_SORT;
    this.closePanel();
  }

  /** Clears both copies and the search box. */
  clearFilters() {
    this._filtersTouched = true; // MSC-231: a deliberate clear must stay cleared
    this.term = "";
    this.beds = "";
    this.typology = "";
    this.price = "";
    this.plot = "";
    this.sort = DEFAULT_SORT;
    this.pendingBeds = "";
    this.pendingTypology = "";
    this.pendingPrice = "";
    this.pendingPlot = "";
    this.pendingSort = DEFAULT_SORT;
  }

  /** Footer Clear: empties the panel and the list, leaves the panel open, keeps the search term. */
  resetPanel() {
    this.pendingBeds = "";
    this.pendingTypology = "";
    this.pendingPrice = "";
    this.pendingPlot = "";
    this.pendingSort = DEFAULT_SORT;
    this.beds = "";
    this.typology = "";
    this.price = "";
    this.plot = "";
    this.sort = DEFAULT_SORT;
  }

  /** The chip row's Clear: wipes everything and closes. */
  clearAll() {
    this.clearFilters();
    this.closePanel();
  }

  // trigger badge and chips

  /** The badge counts sort too, matching the source. */
  get filterCount() {
    return (
      (this.beds ? 1 : 0) +
      (this.typology ? 1 : 0) +
      (this.price ? 1 : 0) +
      (this.plot ? 1 : 0) +
      (this.sort !== DEFAULT_SORT ? 1 : 0)
    );
  }

  get showFilterCount() {
    return this.filterCount > 0;
  }

  /** Narrowing only. */
  get hasFilters() {
    return !!(this.term || this.beds || this.typology || this.price || this.plot);
  }

  get filterBtnClass() {
    const on = this.panelOpen || this.showFilterCount;
    return on ? "btn btn-ghost filter-btn filter-btn--on" : "btn btn-ghost filter-btn";
  }

  labelFor(options, value) {
    const hit = (options || []).find((o) => o.key === value);
    return hit ? hit.label : null;
  }

  /** What is applied, in words, under the tools; resolved from an unfiltered option set. */
  get activeChips() {
    const all = this.decorated;
    const chips = [];
    if (this.term.trim()) {
      chips.push({ key: "term", label: `Search: ${this.term.trim()}` });
    }
    if (this.typology) {
      chips.push({ key: "typology", label: `Type: ${this.typology}` });
    }
    if (this.beds) {
      const l = this.labelFor(
        this.buildOptions(all, "bedKey", "bedLabel", "", this.beds, "numeric"),
        this.beds
      );
      if (l) chips.push({ key: "beds", label: `Bedrooms: ${l}` });
    }
    if (this.price) {
      const l = this.labelFor(this.bandOptions(all, "priceKey", PRICE_BANDS, "", this.price), this.price);
      if (l) chips.push({ key: "price", label: `Price: ${l}` });
    }
    if (this.plot) {
      const l = this.labelFor(this.bandOptions(all, "plotKey", PLOT_BANDS, "", this.plot), this.plot);
      if (l) chips.push({ key: "plot", label: `Plot: ${l}` });
    }
    if (this.sort !== DEFAULT_SORT) {
      const o = SORT_OPTIONS.find((s) => s.value === this.sort);
      if (o) chips.push({ key: "sort", label: `Sort: ${o.label}` });
    }
    return chips;
  }

  get showActiveChips() {
    return this.activeChips.length > 0;
  }

  /** Each chip removes only itself. */
  handleChipRemove(event) {
    const key = event.currentTarget.dataset.chip;
    if (key === "term") this.term = "";
    else if (key === "beds") this.beds = "";
    else if (key === "typology") this.typology = "";
    else if (key === "price") this.price = "";
    else if (key === "plot") this.plot = "";
    else if (key === "sort") this.sort = DEFAULT_SORT;
    this.syncPending();
  }

  /** Says what Apply will do. */
  get applyLabel() {
    const n = this.pendingMatches.length;
    return n === 1 ? "Show 1 unit" : `Show ${n} units`;
  }

  /** True when the panel is narrowing anything. */
  get hasPendingNarrowing() {
    return !!(
      this.pendingBeds ||
      this.pendingTypology ||
      this.pendingPrice ||
      this.pendingPlot
    );
  }

  /** Guarded on the panel having filters: pendingMatches counts the search term too. */
  get applyDisabled() {
    return this.hasPendingNarrowing && this.pendingMatches.length === 0;
  }

  /** Everything matching the applied filters, not capped. */
  get matches() {
    return this.filterBy(
      { beds: this.beds, typology: this.typology, price: this.price, plot: this.plot },
      this.sort
    );
  }

  /** The same, against what the panel is showing. */
  get pendingMatches() {
    return this.filterBy(
      {
        beds: this.pendingBeds,
        typology: this.pendingTypology,
        price: this.pendingPrice,
        plot: this.pendingPlot
      },
      this.pendingSort
    );
  }

  filterBy(f, sort) {
    const t = this.term.trim().toLowerCase();
    let list = this.decorated.filter((d) => {
      if (t && d.name.toLowerCase().indexOf(t) === -1) return false;
      return this.matchesCore(d, f);
    });

    if (sort === "priceAsc" || sort === "priceDesc") {
      const dir = sort === "priceAsc" ? 1 : -1;
      list = [...list].sort((a, b) => {
        // units with no price sort last
        const av = a.u.TotalPrice__c == null ? Infinity : a.u.TotalPrice__c;
        const bv = b.u.TotalPrice__c == null ? Infinity : b.u.TotalPrice__c;
        if (av === bv) return 0;
        if (av === Infinity) return 1;
        if (bv === Infinity) return -1;
        return (av - bv) * dir;
      });
    } else if (sort === "bedsDesc") {
      list = [...list].sort((a, b) => b.bedValue - a.bedValue);
    }
    return list.map((d) => d.u);
  }

  /** A selected unit always renders, even outside the current filter. */
  get unitCards() {
    const chosen = this.selectedSet;
    const matched = this.matches;
    const shown = matched.slice(0, RENDER_CAP);
    const shownIds = new Set(shown.map((u) => u.Id));
    for (const u of this.units || []) {
      if (chosen.has(u.Id) && !shownIds.has(u.Id)) {
        shown.push(u);
      }
    }
    return shown.map((u) => {
      const selected = chosen.has(u.Id);
      const facts = selected && this.showFacts ? this.factsLine(u) : null;
      return {
        id: u.Id,
        name: u.Name,
        priceDisplay: formatAED(u.TotalPrice__c),
        // Typology, not UnitClassification__c (not in the query)
        typology: u.Typology__c,
        /* area is dropped: TotalArea__c and GrossFloorAreaGFA__c are almost never populated */
        meta: u.Number_of_Bedrooms__c ? `${u.Number_of_Bedrooms__c} BR` : null,
        facts,
        selected,
        cls: selected
          ? `glass unit-row unit-row--on${facts ? " unit-row--facts" : ""}`
          : "glass unit-row"
      };
    });
  }

  /** 1.11: "GSA 312 sqm · Plot 450 sqm · Phase 5", leaving out what the unit does not carry. */
  factsLine(u) {
    const sqm = (v) =>
      v == null || v === ""
        ? null
        : `${Number(v).toLocaleString("en-AE", { maximumFractionDigits: 2 })} sqm`;
    const gsa = sqm(u.TotalGrossSellableAreaGSA__c);
    const plot = sqm(u.PlotAreasqm__c);
    const phase = u.Phase__r && u.Phase__r.Name ? u.Phase__r.Name : null;
    const parts = [
      gsa ? `GSA ${gsa}` : null,
      plot ? `Plot ${plot}` : null,
      phase
    ].filter(Boolean);
    return parts.length ? parts.join(" · ") : null;
  }

  get resultLabel() {
    const total = (this.units || []).length;
    const n = this.matches.length;
    if (!total) {
      return "";
    }
    if (n === total) {
      return `${total} units`;
    }
    return `${n} of ${total} units`;
  }

  /** Says so plainly. */
  get cappedNote() {
    const n = this.matches.length;
    /* the cap has to be stated */
    return n > RENDER_CAP ? `showing first ${RENDER_CAP}` : "";
  }

  get showCapped() {
    return this.matches.length > RENDER_CAP;
  }

  get hasUnits() {
    return this.unitCards.length > 0;
  }

  get showEmpty() {
    return !this.busy && !this.hasUnits;
  }

  /** An empty phase usually means nothing allocated to this agent, not sold out. */
  get emptyMessage() {
    if (!this.selectedPhaseId) return "Choose a project and phase to see available units.";
    if (this.hasFilters) {
      return "No unit matches these filters. Only units assigned to you are shown.";
    }
    return (
      "No units in this phase are assigned to you. Ask your administrator to " +
      "allocate them to your sales bucket."
    );
  }

  // selection summary

  get selectedCount() {
    return (this.selectedUnitIds || []).length;
  }

  /** Shown only once a basket exists. */
  get showBasket() {
    return this.selectedCount > 1;
  }

  /** Said at the moment the second unit is ticked, not at Confirm. */
  get basketNote() {
    return LABELS.UNITS_SELECTED_MULTI.replace("{0}", String(this.selectedCount));
  }

  /** Project and phase re-query; both clear the refinements and keep the panel open. */
  handleProject(event) {
    this.clearFilters();
    this.dispatchEvent(
      new CustomEvent("projectchange", { detail: { value: event.target.value } })
    );
  }

  handlePhase(event) {
    this.clearFilters();
    this.dispatchEvent(
      new CustomEvent("phasechange", { detail: { value: event.target.value } })
    );
  }

  handleSelect(event) {
    const unitId = event.currentTarget.dataset.id;
    // report the intent, not the resulting list
    this.dispatchEvent(
      new CustomEvent("unitselect", {
        detail: { unitId, selected: !this.selectedSet.has(unitId) }
      })
    );
  }
}