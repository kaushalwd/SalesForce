import { LightningElement, api, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import getLoggedInUserDetail from '@salesforce/apex/MBP_BrokerAgencyDashboardController.getLoggedInUserDetail';
import getAgencyDashboardDetails from '@salesforce/apex/MBP_BrokerAgencyDashboardController.getAgencyDashboardDetails';
import getTotalSalesAmount from '@salesforce/apex/MBP_manageDashboardcontroller.getTotalSalesAmount';
import getCommissionSummary from '@salesforce/apex/MBP_manageDashboardcontroller.getCommissionSummary';
import getGroupedProjectSalesData from '@salesforce/apex/MBP_manageDashboardcontroller.getGroupedProjectSalesData';
import getScopedUnits from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import getOpportunitiesForAgency from '@salesforce/apex/MBP_BrokerOpportunityController.getOpportunitiesForAgency';

/* BP-039 (client, 10 Sep 2026): the full period list is back - All Time and
   Last 12 Months (BP-002 / BP-033) plus the four presets and the custom range
   the dashboard offered before. Every value is a filterType Apex already
   resolves (appendDateFilter / getCommissionSummary; Custom travels with its
   dates), so no server change is needed. All Time stays the default. */
const FILTER_OPTIONS = [
    { label: 'All Time', value: 'All Time' },
    { label: 'Last 12 Months', value: 'Last 12 Months' },
    { label: 'Current Year', value: 'Current Year' },
    { label: 'Previous Year', value: 'Previous Year' },
    { label: 'Current FY', value: 'Current FY' },
    { label: 'Previous FY', value: 'Previous FY' },
    { label: 'Custom', value: 'Custom' }
];

/* mbpr_homeGateway's Total Sales card must carry the same default so the
   home number and the dashboard number agree on first open.
   BP-033 (client, 9 Sep 2026): All Time is the default. */
const DEFAULT_FILTER = 'All Time';
/* The lead statuses the Leads table shows, in picklist order so this agrees
   with mbpr_leadPerformance. Anything else a record carries is still counted
   and appended after these, so a total can never silently lose rows. */
const LEAD_STATUS_ORDER = ['New', 'Qualified', 'In Progress', 'Lead Qualified', 'Retired'];
/* Palette slots 1-5 in visual order. Tones map straight to slots, so the
   Leads bar reads navy, gold, slate, mauve, gray, and two-segment tiles get
   navy for new/available and gold for converted/sold. */
const LEAD_STATUS_TONES = ['a', 'b', 'c', 'd', 'e'];
/* Tone letter -> palette slot, for the hover tooltip's swatch. */
const PULSE_TONE_SLOT = { a: 1, b: 2, c: 3, d: 4, e: 5 };
const LOAD_ERROR_MESSAGE = "We couldn't load your dashboard right now.";
const COUNT_DURATION_MS = 950;
const DONUT_CIRCUMFERENCE = 100;
const DONUT_START_OFFSET = 25;


/* Lead status 'Qualified' is shown as 'Converted To Opportunity'. Exact
   match on the whole trimmed value, because 'Lead Qualified' is a separate
   status that keeps its own name. Presentation only: the raw value still
   drives counting, filtering and tones. */
function leadStatusLabel(status) {
    const raw = String(status || '').trim();
    return raw.toLowerCase() === 'qualified' ? 'Converted To Opportunity' : raw;
}

export default class Mbpr_dashboardWorkspace extends LightningElement {
    @track isInitializing = true;
    @track isRefreshing = false;
    @track loadError = '';

    @track selectedFilter = DEFAULT_FILTER;

    @track isFilterOpen = false;
    _filterAnchor = null;
    @track draftFilter = DEFAULT_FILTER;
    /* BP-039: the custom range applied to the data (Custom only) and the draft
       dates being edited in the popover. */
    @track customStartDate = null;
    @track customEndDate = null;
    @track draftStartDate = null;
    @track draftEndDate = null;

    // Animated display fields - the count-up engine reassigns these each frame.
    heroSalesDisplay = '0';
    commissionTotalDisplay = '0';
    gaugePctDisplay = '0';
    leadsTotalDisplay = '0';
    oppsTotalDisplay = '0';
    unitsTotalDisplay = '0';
    /* Raw numeric count-up targets - the shared chart formats them, so the
       animation drives the number itself (center-value coerces to Number). */
    salesCenterTotal = 0;
    unitsCenterTotal = 0;

    // Raw stats behind the view-model getters (replaced whole, never mutated).
    _salesAmount = 0;
    _commission = null;
    _leads = null;
    _opps = null;
    _units = null;
    _projSales = [];
    _projUnits = [];

    /* One tooltip state set: the small charts anchor their tip to.dash, the
       enlarge lightbox renders its own inside.dash-xl. */
    tipOn = false;
    tipRow = null;
    tipX = 0;
    tipY = 0;
    tipAnchor = 'dash';

    /* Chart enlarge. */
    openChart = '';
    _lightboxReturnFocusPending = false;
    _lightboxOpenerKey = '';

    accountId = null;
    contactId = null;
    _loadSequence = 0;
    _filterFocusPending = false;
    _filterReturnFocusPending = false;
    _countRafs = {};
    _countState = {};
    _reducedMotion = false;

    /* The parent renders the Filters trigger in the modal header and proxies
       clicks via toggleFilters; the popover still lives here. */
    @api hideFilterTrigger = false;

    @api toggleFilters(anchor) {
        this._filterAnchor = anchor && typeof anchor.bottom === 'number' ? anchor : null;
        this.toggleFilterPanel();
    }

    /* Absolute in the toolbar, positioned by viewport-rect deltas rather than
       fixed: the modal's scroll body is a containing block and would re-base
       fixed coordinates. The chip sits above that body, so the top is clamped
       at the measured scrollport top and the panel sits flush under the
       header without being clipped. */
    get filterPopStyle() {
        const anchor = this._filterAnchor;
        if (!anchor) return '';
        const toolbar = this.template.querySelector('.dash-toolbar');
        if (!toolbar) return '';
        const rect = toolbar.getBoundingClientRect();
        const limit = this.scrollportTop();
        const target =
            limit === null
                ? Math.max(rect.top, anchor.bottom + 8)
                : Math.max(limit, anchor.bottom + 8);
        const top = Math.round(target - rect.top);
        const right = Math.max(0, Math.round(rect.right - anchor.right));
        return `top: ${top}px; right: ${right}px;`;
    }

    /* Top edge of the nearest scrolling ancestor. A panel may sit anywhere down
       to this line, including inside that body's padding, but anything above
       it is clipped. Walks the composed tree so it works under native and
       synthetic shadow DOM. Null when no scroller is found. */
    scrollportTop() {
        try {
            let node = this.template.host;
            while (node && node !== document.body && node !== document.documentElement) {
                const style = window.getComputedStyle(node);
                const overflowY = `${style.overflowY} ${style.overflow}`;
                if (/(auto|scroll|hidden)/.test(overflowY)) {
                    return node.getBoundingClientRect().top;
                }
                node =
                    node.parentElement ||
                    (typeof node.getRootNode === 'function' ? node.getRootNode().host : null);
            }
        } catch (error) {
            // Fall through to the caller's clamp.
        }
        return null;
    }


    get showFilterTrigger() {
        return !this.hideFilterTrigger;
    }

    notifyFilterLabel() {
        this.dispatchEvent(
            new CustomEvent('filterlabelchange', {
                detail: {
                    label: this.activeFilterLabel,
                    isDefault: this.isDefaultPeriod
                }
            })
        );
    }

    connectedCallback() {
        this._reducedMotion =
            typeof window !== 'undefined' && window.matchMedia
                ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
                : false;
        this.initializeWorkspace();
        this.notifyFilterLabel();
    }

    disconnectedCallback() {
        Object.keys(this._countRafs).forEach((key) => cancelAnimationFrame(this._countRafs[key]));
        this._countRafs = {};
    }

    renderedCallback() {
        if (this._filterFocusPending) {
            this._filterFocusPending = false;
            const field = this.template.querySelector('.filter-pop select');
            if (field) {
                field.focus();
            }
        }
        if (this._filterReturnFocusPending) {
            this._filterReturnFocusPending = false;
            const trigger = this.template.querySelector('.dash-filter-trigger');
            if (trigger) {
                trigger.focus();
            }
        }
        if (this._lightboxReturnFocusPending) {
            this._lightboxReturnFocusPending = false;
            const key = this._lightboxOpenerKey;
            this._lightboxOpenerKey = '';
            if (key === 'gauge') {
                const button = this.template.querySelector('.gauge-expand');
                if (button) button.focus();
            } else if (key) {
                const button = this.template.querySelector(
                    `.proj-panel__expand[data-chart="${key}"], .pulse-tile__expand[data-chart="${key}"]`
                );
                if (button) button.focus();
            }
        }
    }

    initializeWorkspace() {
        this.isInitializing = true;
        this.loadError = '';
        const sequence = ++this._loadSequence;
        getLoggedInUserDetail()
            .then((info) => {
                if (sequence !== this._loadSequence) {
                    return null;
                }
                const user = info && info.user ? info.user : {};
                this.accountId = user.AccountId || null;
                this.contactId = user.ContactId || null;
                return this.loadAll(sequence);
            })
            .catch(() => {
                if (sequence === this._loadSequence) {
                    this.loadError = LOAD_ERROR_MESSAGE;
                }
            })
            .finally(() => {
                if (sequence === this._loadSequence) {
                    this.isInitializing = false;
                }
            });
    }

    /* Resolves the period to explicit dates. Every request sends the range,
       because three of the seven sources cannot resolve it themselves:
       getAgencyDashboardDetails only branches on the two FY values, and
       getOpportunitiesForAgency / getFilteredLeads fall back to 1 Jan -> today
       when handed nulls - so "All Time" has to be an explicit wide range,
       never null. The Sales Order and commission sources ignore these dates
       for any non-Custom filterType and apply their own definition, so every
       range here mirrors Apex exactly: the financial year runs 1 Apr -> 31 Mar,
       Last 12 Months = the 12 complete calendar months before this one
       (getLast12MonthsStart / getLast12MonthsEnd), Custom = the applied dates. */
    resolvePeriod() {
        const today = new Date();
        const year = today.getFullYear();
        const iso = (d) =>
            `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        const ymd = (y, m, d) => `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
        // Financial year runs 1 Apr -> 31 Mar, matching the Apex definition.
        const fyYear = today.getMonth() + 1 < 4 ? year - 1 : year;
        switch (this.selectedFilter) {
            case 'Custom':
                return { startDate: this.customStartDate || null, endDate: this.customEndDate || null };
            case 'Current Year':
                return { startDate: ymd(year, 1, 1), endDate: ymd(year, 12, 31) };
            case 'Previous Year':
                return { startDate: ymd(year - 1, 1, 1), endDate: ymd(year - 1, 12, 31) };
            case 'Current FY':
                return { startDate: ymd(fyYear, 4, 1), endDate: ymd(fyYear + 1, 3, 31) };
            case 'Previous FY':
                return { startDate: ymd(fyYear - 1, 4, 1), endDate: ymd(fyYear, 3, 31) };
            case 'Last 12 Months': {
                const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
                const start = new Date(lastMonthEnd.getFullYear(), lastMonthEnd.getMonth() - 11, 1);
                return { startDate: iso(start), endDate: iso(lastMonthEnd) };
            }
            default: {
                // All Time (the default). Tomorrow as the upper bound: two count
                // sources compare a DateTime with "<= :endDate" (midnight), so
                // "today" would drop today's rows.
                const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
                return { startDate: '1900-01-01', endDate: iso(tomorrow) };
            }
        }
    }

    loadAll(sequence) {
        const period = this.resolvePeriod();
        const params = {
            filterType: this.selectedFilter,
            startDate: period.startDate,
            endDate: period.endDate
        };
        const guarded = (promise) => promise.catch(() => null);
        return Promise.all([
            guarded(
                getAgencyDashboardDetails({
                    accountId: this.accountId,
                    filterType: params.filterType,
                    startDate: params.startDate,
                    endDate: params.endDate
                })
            ),
            guarded(getTotalSalesAmount(params)),
            guarded(
                getCommissionSummary({
                    accountId: this.accountId,
                    contactId: this.contactId,
                    filterType: params.filterType,
                    startDate: params.startDate,
                    endDate: params.endDate
                })
            ),
            guarded(
                getFilteredLeads({
                    userId: USER_ID,
                    startDate: params.startDate,
                    endDate: params.endDate,
                    filterType: params.filterType
                })
            ),
            // This method has no filterType parameter (adding one errors); it
            // filters on the explicit range only, which resolvePeriod now
            // always supplies.
            guarded(
                getOpportunitiesForAgency({
                    accountId: this.accountId,
                    startDate: params.startDate,
                    endDate: params.endDate
                })
            ),
            guarded(getGroupedProjectSalesData(params)),
            /* Units tile is broker-scoped (2026-09-01). getUnitRecords() runs an
               unscoped COUNT - its Broker_Type__c/AccountId condition is commented
               out in Apex - so every broker saw the whole catalogue (163/18).
               getRecords() is the same method the Available Units card and Guided
               Offer already use: it filters on the user's Bucket__c public groups
               and Allocate_to_Agency__c, and returns Status='Available' rows only.
               Project_Name__c is a plain text field on Unit__c (populated on 100%
               of broker-sale units); the Phase->Project path cannot be requested
               because isValidFieldPath() only accepts <Relationship>.Name. */
            guarded(
                getScopedUnits({
                    objectName: 'Unit__c',
                    filters: {},
                    fields: ['Project_Name__c', 'Status__c']
                })
            )
        ]).then((results) => {
            if (sequence !== this._loadSequence) {
                return;
            }
            const [kpi, totalSales, commission, leads, opps, projects, unitRows] = results;

            const salesAmount = Number(totalSales) || 0;
            this._salesAmount = salesAmount;
            this.animateCount('heroSalesDisplay', salesAmount, (value) => this.formatShort(value));

            this.applyCommission(commission);
            this.applyPerformance(leads, opps, unitRows, kpi);
            this.applyProjects(projects);

            if (results.every((entry) => entry === null)) {
                throw new Error('dashboard-empty');
            }
        });
    }

    /* ============================= Count-up engine ============================= */

    // Eases a declared display field from its last raw value to `target`,
    // formatting each frame. Reduced motion (or no change) snaps instantly.
    animateCount(key, target, format) {
        const to = Number(target) || 0;
        const from = Number(this._countState[key]) || 0;
        if (this._countRafs[key]) {
            cancelAnimationFrame(this._countRafs[key]);
            delete this._countRafs[key];
        }
        if (this._reducedMotion || from === to) {
            this._countState[key] = to;
            this[key] = format(to);
            return;
        }
        const start = performance.now();
        const tick = (now) => {
            const progress = Math.min((now - start) / COUNT_DURATION_MS, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            const value = progress === 1 ? to : from + (to - from) * eased;
            this._countState[key] = value;
            this[key] = format(value);
            if (progress < 1) {
                this._countRafs[key] = requestAnimationFrame(tick);
            } else {
                delete this._countRafs[key];
            }
        };
        this._countRafs[key] = requestAnimationFrame(tick);
    }

    /* ============================= Builders ============================= */

    applyCommission(summary) {
        const paid = Number(summary && summary.Paid) || 0;
        const pending = Number(summary && summary.Pending) || 0;
        const total = Number(summary && summary.Total) || 0;
        const eligible = Number(summary && summary.eligible) || 0;
        // Share of the real total (the legacy donut divided by a sum that
        // included the total itself - that defect is deliberately not ported).
        const paidPct = total > 0 ? Math.min(100, Math.max(0, Math.round((paid / total) * 100))) : 0;
        const pendingPct = total > 0 ? Math.max(0, 100 - paidPct) : 100;
        this._commission = { paid, pending, total, eligible, paidPct, pendingPct };
        this.animateCount('commissionTotalDisplay', total, (value) => this.formatShort(value));
        this.animateCount('gaugePctDisplay', paidPct, (value) => String(Math.round(value)));
    }

    applyPerformance(leads, opps, unitRows, kpiPayload) {
        const leadRows = Array.isArray(leads) ? leads : [];
        const statusOf = (row) => String(row.Status || '').toLowerCase();
        // A row is one customer, and children holds each of their leads. Counting rows counted
        // customers, so repeat leads and the conversions among them never showed up.
        const leadEntries = leadRows.reduce((all, row) => {
            const group = Array.isArray(row.children) && row.children.length ? row.children : [row];
            return all.concat(group);
        }, []);
        const leadStatusCounts = new Map();
        leadEntries.forEach((row) => {
            const label = String(row.Status || 'New').trim() || 'New';
            leadStatusCounts.set(label, (leadStatusCounts.get(label) || 0) + 1);
        });
        const orderedStatuses = [
            ...LEAD_STATUS_ORDER.filter((label) => leadStatusCounts.has(label)),
            ...[...leadStatusCounts.keys()].filter((label) => !LEAD_STATUS_ORDER.includes(label))
        ];
        this._leads = {
            total: leadEntries.length,
            qualifiedCount: leadStatusCounts.get('Qualified') || 0,
            statuses: orderedStatuses.map((status, index) => ({
                key: status.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
                label: leadStatusLabel(status),
                value: leadStatusCounts.get(status),
                tone: LEAD_STATUS_TONES[index % LEAD_STATUS_TONES.length]
            }))
        };
        this.animateCount('leadsTotalDisplay', this._leads.total, (value) => this.formatFull(Math.round(value)));

        const oppRows = Array.isArray(opps) ? opps : [];
        const stageOf = (row) => String(row.StageName || '').toLowerCase();
        this._opps = {
            total: oppRows.length,
            newCount: oppRows.filter((row) => stageOf(row) === 'new').length,
            wonCount: oppRows.filter((row) => row.IsWon === true || stageOf(row).includes('won')).length
        };
        this.animateCount('oppsTotalDisplay', this._opps.total, (value) => this.formatFull(Math.round(value)));

        /* unitRows is now the scoped record list, not the old count map.
           getRecords() already restricts to Status='Available', so total and
           available are the same figure - the tile counts what this broker can
           actually sell. 'sold' still comes from the Units Sold KPI, which
           getAgencyDashboardDetails already scopes by account. */
        const rows = Array.isArray(unitRows) ? unitRows : [];
        const kpiList = kpiPayload && Array.isArray(kpiPayload.kpiList) ? kpiPayload.kpiList : [];
        const soldKpi = kpiList.find((kpi) => String(kpi.label || '').toLowerCase() === 'units sold');
        const projectNames = new Set(
            rows
                .map((row) => String((row && row.Project_Name__c) || '').trim())
                .filter((name) => name.length > 0)
        );
        this._units = {
            total: rows.length,
            available: rows.length,
            sold: Number(soldKpi && soldKpi.value) || 0,
            projects: projectNames.size
        };
        this.animateCount('unitsTotalDisplay', this._units.total, (value) => this.formatFull(Math.round(value)));
    }

    applyProjects(rawData) {
        const data = rawData && typeof rawData === 'object' ? rawData : {};
        const units = [];
        const sales = [];
        let unitsTotal = 0;
        let salesTotal = 0;
        Object.keys(data).forEach((key) => {
            const entry = data[key] || {};
            const unitCount = Number(entry.unitCount) || 0;
            const totalSales = Number(entry.totalSales) || 0;
            units.push({ label: key, value: unitCount });
            sales.push({ label: key, value: totalSales });
            unitsTotal += unitCount;
            salesTotal += totalSales;
        });
        this._projUnits = units;
        this._projSales = sales;
        this.animateCount('salesCenterTotal', salesTotal, (value) => value);
        this.animateCount('unitsCenterTotal', unitsTotal, (value) => Math.round(value));
    }

    refreshData() {
        const sequence = ++this._loadSequence;
        this.isRefreshing = true;
        this.loadError = '';
        this.loadAll(sequence)
            .catch(() => {
                if (sequence === this._loadSequence) {
                    this.loadError = LOAD_ERROR_MESSAGE;
                }
            })
            .finally(() => {
                if (sequence === this._loadSequence) {
                    this.isRefreshing = false;
                }
            });
    }

    handleRetryLoad() {
        this.initializeWorkspace();
    }

    /* ============================= Hero view-models ============================= */

    // Precise sub-line only when it adds information beyond the short form
    // (below 1M the short and full renders are identical - never duplicate).
    fullLineFor(rawValue) {
        const full = this.formatFull(rawValue);
        return this.formatShort(rawValue) === full ? '' : `AED ${full}`;
    }

    get commissionFullLine() {
        return this.fullLineFor(this._commission ? this._commission.total : 0);
    }

    get gaugeArcStyle() {
        const pct = this._commission ? this._commission.paidPct : 0;
        return `stroke-dasharray: ${pct} ${DONUT_CIRCUMFERENCE - pct}; stroke-dashoffset: ${DONUT_START_OFFSET};`;
    }

    get gaugeAriaLabel() {
        const c = this._commission || { paidPct: 0, total: 0 };
        return `Commission paid ${c.paidPct}% of AED ${this.formatFull(c.total)} total`;
    }

    get commissionChips() {
        if (!this._commission) {
            return [];
        }
        const c = this._commission;
        return [
            {
                key: 'paid',
                label: 'Paid',
                value: `AED ${this.formatFull(c.paid)}`,
                percent: `${c.paidPct}%`,
                dotClass: 'glass-chip__dot glass-chip__dot--paid'
            },
            {
                key: 'pending',
                label: 'Pending',
                value: `AED ${this.formatFull(c.pending)}`,
                percent: `${c.pendingPct}%`,
                dotClass: 'glass-chip__dot glass-chip__dot--pending'
            }
            /* BP-068 (12 Sep 2026): MODON asked for the Eligible row to come off this card.
               HIDDEN, not removed - the chip object below is the whole change and pasting it
               back restores the row exactly. Everything that feeds it is deliberately left in
               place: Apex still returns `eligible`, loadCommission still reads it into
               `this._commission`, and .glass-chip__dot--eligible is still in the stylesheet.
            , {
                key: 'eligible',
                label: 'Eligible',
                value: `AED ${this.formatFull(c.eligible)}`,
                percent: '',
                dotClass: 'glass-chip__dot glass-chip__dot--eligible'
            } */
        ];
    }

    /* ============================= Pulse view-models ============================= */

    buildPulseTile({ key, title, totalDisplay, total, meta, parts, cardParts, showBreakdown = true }) {
        const segments = parts.map((part, index) => {
            const pct = total > 0 ? Math.max(0, Math.min(100, (part.value / total) * 100)) : 0;
            return {
                key: part.key,
                label: part.label,
                display: this.formatFull(part.value),
                pct: `${Math.round(pct)}%`,
                tone: part.tone,
                barClass: `pulse-bar__seg pulse-bar__seg--${part.tone}`,
                barStyle: `width: ${pct.toFixed(2)}%; --seg-delay: ${index * 110}ms;`
            };
        });
        const toStats = (list) =>
            list.map((part) => ({
                key: part.key,
                label: part.label,
                value: this.formatFull(part.value),
                dotClass: `pulse-dot pulse-dot--${part.tone}`
            }));
        const stats = toStats(parts);
        return {
            key,
            title,
            totalDisplay,
            meta,
            segments,
            stats,
            cardStats: cardParts ? toStats(cardParts) : stats,
            /* A tile can opt out of the split bar and stat chips and show its count
               alone, on the card and in the enlarge view, which binds this same
               object. Defaults to true. segments and stats are still computed
               when opted out, so the breakdown is one flag away. */
            showBreakdown,
            tileClass: showBreakdown ? 'pulse-tile' : 'pulse-tile pulse-tile--solo',
            expandKey: `pulse-${key}`,
            expandLabel: `Enlarge ${title}`
        };
    }

    get pulseTiles() {
        const tiles = [];
        if (this._leads) {
            const qualifiedPct =
                this._leads.total > 0 ? Math.round((this._leads.qualifiedCount / this._leads.total) * 100) : 0;
            tiles.push(
                this.buildPulseTile({
                    key: 'leads',
                    title: 'Leads',
                    totalDisplay: this.leadsTotalDisplay,
                    total: this._leads.total,
                    meta: this._leads.total > 0 ? `${qualifiedPct}% converted` : 'None in period',
                    /* The bar covers every status so it fills the total. The
                       card keeps its two largest cells in one row and the
                       enlarge view lists them all. */
                    parts: this._leads.statuses,
                    cardParts: [...this._leads.statuses].sort((a, b) => b.value - a.value).slice(0, 2)
                })
            );
        }
        if (this._opps) {
            const wonPct = this._opps.total > 0 ? Math.round((this._opps.wonCount / this._opps.total) * 100) : 0;
            tiles.push(
                this.buildPulseTile({
                    key: 'opps',
                    title: 'Opportunities',
                    totalDisplay: this.oppsTotalDisplay,
                    total: this._opps.total,
                    meta: this._opps.total > 0 ? `${wonPct}% converted` : 'None in period',
                    parts: [
                        { key: 'new', label: 'New', value: this._opps.newCount, tone: 'a' },
                        { key: 'won', label: 'Converted to sales', value: this._opps.wonCount, tone: 'b' }
                    ]
                })
            );
        }
        if (this._units) {
            tiles.push(
                this.buildPulseTile({
                    key: 'units',
                    title: 'Units',
                    totalDisplay: this.unitsTotalDisplay,
                    total: this._units.total,
                    /* Singular when the broker is scoped to exactly one project:
                       "across 1 project", not "across 1 projects". Zero keeps the
                       plural, which is correct English ("No projects"). */
                    meta:
                        this._units.projects > 0
                            ? `across ${this._units.projects} ${this._units.projects === 1 ? 'project' : 'projects'}`
                            : 'No projects',
                    /* Units shows the count only: the Available/Sold bar and
                       chips are dropped from the card and the enlarge view.
                       The parts stay declared so the split is one flag away. */
                    showBreakdown: false,
                    parts: [
                        { key: 'available', label: 'Available', value: this._units.available, tone: 'a' },
                        { key: 'sold', label: 'Sold', value: this._units.sold, tone: 'b' }
                    ]
                })
            );
        }
        return tiles;
    }

    /* ============================= Project view-models ============================= */

    /* Largest first. There are four named hues plus a gray that is both the
       fifth slot and the "Other" colour, so five rows or fewer render as they
       are and anything longer is capped at four plus one gray "Other".
       Capping at five would put a real category beside "Other" in the same
       gray. The enlarge view binds these same capped getters. */
    projectSegmentsFor(list) {
        return [...list].filter((row) => row.value > 0).sort((a, b) => b.value - a.value);
    }

    cappedSegments(rows) {
        if (rows.length <= 5) return rows;
        const head = rows.slice(0, 4);
        const rest = rows.slice(4).reduce((sum, row) => sum + row.value, 0);
        return [...head, { label: 'Other', value: rest }];
    }

    get salesSegments() {
        return this.cappedSegments(this.projectSegmentsFor(this._projSales));
    }

    get unitsSegments() {
        return this.cappedSegments(this.projectSegmentsFor(this._projUnits));
    }

    get salesHasData() {
        return this._projSales.some((row) => row.value > 0);
    }

    get unitsHasData() {
        return this._projUnits.some((row) => row.value > 0);
    }

    /* ============================= Dashboard tooltip ============================= */

    setDashTipPosition(event) {
        const xl = event.currentTarget.closest('.dash-xl');
        this.tipAnchor = xl ? 'xl' : 'dash';
        const anchor = xl || this.template.querySelector('.dash');
        if (!anchor) return;
        const rect = anchor.getBoundingClientRect();
        let x = event.clientX - rect.left + 14;
        let y = event.clientY - rect.top - 12;
        x = Math.min(Math.max(x, 8), Math.max(rect.width - 190, 8));
        y = Math.min(Math.max(y, 8), Math.max(rect.height - 48, 8));
        this.tipX = Math.round(x);
        this.tipY = Math.round(y);
    }

    showDashTip(event, row) {
        this.tipRow = row;
        this.tipOn = true;
        this.setDashTipPosition(event);
    }

    handleTipMove(event) {
        if (!this.tipOn) return;
        this.setDashTipPosition(event);
    }

    handleTipLeave() {
        this.tipOn = false;
        this.tipRow = null;
    }

    handleGaugeEnter(event) {
        const c = this._commission;
        if (!c) return;
        this.showDashTip(event, {
            label: 'Paid',
            value: `AED ${this.formatFull(c.paid)} of ${this.formatFull(c.total)}`,
            pct: `${c.paidPct}%`,
            swatchStyle: 'background: var(--dash-viz-active);'
        });
    }

    handlePulseEnter(event) {
        const data = event.currentTarget.dataset;
        this.showDashTip(event, {
            label: data.label,
            value: data.value,
            pct: data.pct,
            swatchStyle: `background: var(--dash-c${PULSE_TONE_SLOT[data.tone] || 1});`
        });
    }

    handleRankEnter(event) {
        const data = event.currentTarget.dataset;
        this.showDashTip(event, {
            label: data.label,
            value: data.value,
            pct: data.pct,
            swatchStyle: 'background: var(--dash-viz-active);'
        });
    }

    get dashTipOn() {
        return this.tipOn && this.tipAnchor === 'dash';
    }

    get xlTipOn() {
        return this.tipOn && this.tipAnchor === 'xl';
    }

    get tipClass() {
        return this.tipOn ? 'dash-tip dash-tip--on' : 'dash-tip';
    }

    get tipStyle() {
        return `left: ${this.tipX}px; top: ${this.tipY}px;`;
    }

    /* ============================= Chart enlarge ============================= */

    handleChartExpand(event) {
        this.openChart = event.currentTarget.dataset.chart || '';
    }

    handleLightboxClose() {
        this._lightboxOpenerKey = this.openChart;
        this._lightboxReturnFocusPending = true;
        this.openChart = '';
        this.handleTipLeave();
    }

    get isLightboxOpen() {
        return Boolean(this.openChart);
    }

    get lightboxTitle() {
        const titles = {
            gauge: 'Commission Overview',
            'pulse-leads': 'Leads',
            'pulse-opps': 'Opportunities',
            'pulse-units': 'Units',
            sales: 'Sales by Project',
            spa: 'SPA by Project',
            units: 'Units by Project'
        };
        return titles[this.openChart] || 'Chart';
    }

    get isGaugeExpanded() {
        return this.openChart === 'gauge';
    }

    get isPulseExpanded() {
        return this.openChart.startsWith('pulse-');
    }

    get isSalesExpanded() {
        return this.openChart === 'sales';
    }

    get isSpaExpanded() {
        return this.openChart === 'spa';
    }

    get isUnitsExpanded() {
        return this.openChart === 'units';
    }

    get expandedPulseTile() {
        if (!this.isPulseExpanded) return null;
        const key = this.openChart.slice('pulse-'.length);
        return this.pulseTiles.find((tile) => tile.key === key) || null;
    }

    /* Enlarged gauge: the glass chips as readable rows. */
    get gaugeDetailRows() {
        return this.commissionChips.map((chip) => ({
            key: chip.key,
            label: chip.label,
            value: chip.value,
            pct: chip.percent,
            dotClass: chip.dotClass
        }));
    }

    /* This card shares a grid row with the two donuts, so a long project list
       used to stretch all three. Top 5 with the tail folded into "Other", the
       same rule cappedSegments applies to the donuts. Percentages are still
       computed against the full total, so they sum to 100. */
    buildRankRows(rows) {
        const total = rows.reduce((sum, row) => sum + row.value, 0);
        const max = rows.reduce((peak, row) => Math.max(peak, row.value), 0);
        return rows.map((row, index) => ({
            key: row.label,
            rank: String(index + 1).padStart(2, '0'),
            label: row.label,
            display: this.formatFull(row.value),
            percent: total > 0 ? `${Math.round((row.value / total) * 100)}%` : '0%',
            rowStyle: `--row-i: ${index * 70}ms;`,
            fillStyle: `width: ${max > 0 ? Math.max((row.value / max) * 100, 2).toFixed(2) : 0}%; --seg-delay: ${index * 90}ms;`
        }));
    }

    get spaSorted() {
        return [...this._projUnits].sort((a, b) => b.value - a.value);
    }

    get spaRanked() {
        return this.buildRankRows(this.cappedSegments(this.spaSorted));
    }

    get spaHasData() {
        return this._projUnits.some((row) => row.value > 0);
    }

    get spaTotalDisplay() {
        return this.formatFull(this._projUnits.reduce((sum, row) => sum + row.value, 0));
    }

    /* ============================= Filters ============================= */

    get filterOptions() {
        return FILTER_OPTIONS.map((option) => ({
            ...option,
            selected: option.value === this.draftFilter
        }));
    }

    get activeFilterLabel() {
        if (this.selectedFilter === 'Custom' && this.customStartDate && this.customEndDate) {
            return `${this.customStartDate} - ${this.customEndDate}`;
        }
        const option = FILTER_OPTIONS.find((candidate) => candidate.value === this.selectedFilter);
        return option ? option.label : this.selectedFilter;
    }

    /* BP-039: the default is All Time with no custom range applied. */
    get isDefaultPeriod() {
        return this.selectedFilter === DEFAULT_FILTER && !this.customStartDate && !this.customEndDate;
    }

    get filterTriggerClass() {
        return this.isDefaultPeriod
            ? 'dash-filter-trigger'
            : 'dash-filter-trigger dash-filter-trigger--active';
    }

    get showCustomDates() {
        return this.draftFilter === 'Custom';
    }

    get customRangeIncomplete() {
        return this.draftFilter === 'Custom' && (!this.draftStartDate || !this.draftEndDate);
    }

    get customRangeInverted() {
        return (
            this.draftFilter === 'Custom' &&
            Boolean(this.draftStartDate) &&
            Boolean(this.draftEndDate) &&
            this.draftStartDate > this.draftEndDate
        );
    }

    get customRangeHint() {
        if (this.customRangeInverted) {
            return 'The start date must be on or before the end date.';
        }
        if (this.customRangeIncomplete) {
            return 'Select both dates to apply a custom range.';
        }
        return '';
    }

    get isApplyDisabled() {
        return this.customRangeIncomplete || this.customRangeInverted;
    }

    get filterTriggerExpanded() {
        return this.isFilterOpen ? 'true' : 'false';
    }

    toggleFilterPanel(event) {
        // Inline-trigger clicks (event present) anchor to the toolbar,
        // not to a header chip - drop any stale header anchor first.
        if (event) this._filterAnchor = null;
        if (this.isFilterOpen) {
            this.closeFilterPanel();
            return;
        }
        this.draftFilter = this.selectedFilter;
        this.draftStartDate = this.customStartDate;
        this.draftEndDate = this.customEndDate;
        this.isFilterOpen = true;
        this._filterFocusPending = true;
    }

    closeFilterPanel() {
        this.isFilterOpen = false;
        this._filterReturnFocusPending = true;
    }

    handleFilterKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeFilterPanel();
        }
    }

    handleDraftFilterChange(event) {
        this.draftFilter = event.target.value;
        if (this.draftFilter !== 'Custom') {
            this.draftStartDate = null;
            this.draftEndDate = null;
        }
    }

    handleDraftStartChange(event) {
        this.draftStartDate = event.target.value || null;
    }

    handleDraftEndChange(event) {
        this.draftEndDate = event.target.value || null;
    }

    applyFilters() {
        if (this.isApplyDisabled) {
            return;
        }
        this.selectedFilter = this.draftFilter;
        this.customStartDate = this.draftFilter === 'Custom' ? this.draftStartDate : null;
        this.customEndDate = this.draftFilter === 'Custom' ? this.draftEndDate : null;
        this.closeFilterPanel();
        this.refreshData();
        this.notifyFilterLabel();
    }

    resetFilters() {
        this.draftFilter = DEFAULT_FILTER;
        this.draftStartDate = null;
        this.draftEndDate = null;
        this.selectedFilter = DEFAULT_FILTER;
        this.customStartDate = null;
        this.customEndDate = null;
        this.closeFilterPanel();
        this.refreshData();
        this.notifyFilterLabel();
    }

    /* ============================= Display getters ============================= */

    get showContent() {
        return !this.isInitializing && !this.loadError;
    }

    get contentClass() {
        let className = this.isRefreshing ? 'dash dash--busy' : 'dash';
        if (this.hideFilterTrigger) {
            className += ' dash--chrome-hosted';
        }
        return className;
    }

    formatShort(value) {
        const num = Number(value) || 0;
        if (num >= 1000000000) {
            return `${(num / 1000000000).toFixed(1)}B`;
        }
        if (num >= 1000000) {
            return `${(num / 1000000).toFixed(1)}M`;
        }
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(num);
    }

    formatFull(value) {
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(Number(value) || 0);
    }
}