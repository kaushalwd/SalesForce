import { LightningElement, api, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import getPicklist from '@salesforce/apex/MBP_BrokerLeadcontroller.getPicklist';
import getContactsUserInfo from '@salesforce/apex/MBP_BrokerAgentsController.getContactsUserInfo';

/* BP-039 (client, 10 Sep 2026): the full period list, the same as the dashboard -
   All Time and Last 12 Months (BP-033) plus the four presets and the custom range
   this tab offered before. All Time stays the default. */
const FILTER_OPTIONS = [
    { label: 'All Time', value: 'All Time' },
    { label: 'Last 12 Months', value: 'Last 12 Months' },
    { label: 'Current Year', value: 'Current Year' },
    { label: 'Previous Year', value: 'Previous Year' },
    { label: 'Current FY', value: 'Current FY' },
    { label: 'Previous FY', value: 'Previous FY' },
    { label: 'Custom', value: 'Custom' }
];

/* Must match the Manage Leads tab's default (All Time): both counts render on
   the same screen and have to agree on first open. */
const DEFAULT_FILTER = 'All Time';
const LOAD_ERROR_MESSAGE = "We couldn't load your lead performance right now.";
const COUNT_DURATION_MS = 950;
const MAX_TREND_MONTHS = 36;
/* Named hues: navy, gold, slate, mauve. Gray closes the sequence and also
   colours the overflow, so it is not counted here. See donutSegmentsFor. */
const MAX_DONUT_SEGMENTS = 4;
const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/* 'Qualified' reads as 'Converted To Opportunity' across the portal. Keyed
   on the exact picklist value, so the separate 'Lead Qualified' keeps its own
   name. The tone is pinned to what the heuristic already returned, so colours
   do not shift. Every consumer reads bucket.label, so this one entry covers
   the ring, its rows, the chips, the legend and the agent board. */
const STATUS_DISPLAY = {
    Qualified: { label: 'Converted To Opportunity', tone: 'success' }
};

/* Same status heuristic as the sales workspace record chips
   (mbpr_salesWorkspace.getStatusTone) so both surfaces agree on tones. */
function statusToneOf(status) {
    const value = String(status || '').toLowerCase();
    if (value.includes('void') || value.includes('reject') || value.includes('cancel') || value.includes('expired') || value.includes('lost') || value.includes('retired')) {
        return 'error';
    }
    if (value.includes('complete') || value.includes('confirm') || value.includes('approve') || value.includes('qualified') || value.includes('converted') || value.includes('won')) {
        return 'success';
    }
    if (value.includes('pending') || value.includes('progress') || value.includes('finance') || value.includes('working') || value.includes('contact')) {
        return 'warning';
    }
    if (value.includes('new') || value.includes('open') || value.includes('buyer')) {
        return 'active';
    }
    return 'muted';
}

export default class Mbpr_leadPerformance extends LightningElement {
    @api brokerType = '';
    @api accountId = '';
    @api contactId = '';
    /* The modal header renders the agent picker and Filters chip, so at 1200
       and up the inline toolbar collapses to a popover anchor. CSS-gated, so
       touch keeps it inline. */
    @api chromeHosted = false;

    @track isInitializing = true;
    @track isRefreshing = false;
    @track loadError = '';

    @track selectedFilter = DEFAULT_FILTER;

    @track isFilterOpen = false;
    @track draftFilter = DEFAULT_FILTER;
    /* BP-039: the custom range applied to the data (Custom only) and the draft
       dates being edited in the popover. */
    @track customStartDate = null;
    @track customEndDate = null;
    @track draftStartDate = null;
    @track draftEndDate = null;

    /* Agency drill scope: CreatedById of the focused agent ('' = everyone). */
    @track scopeKey = '';
    /* Searchable combobox replacing the native select, same model as the guided
       offer's selectors. Blur closes after a beat so option mousedown lands. */
    @track isAgentPickerOpen = false;
    @track agentSearch = '';
    agentActiveIndex = 0;
    _agentBlurTimeout;
    @track scopeLabel = '';

    /* Status-ring hover tooltip (same pattern as c-mbpr_chart). */
    @track ringIndex = -1;
    @track ringTipOn = false;
    @track ringTipRow = null;
    /* Which surface owns the tip: 'hero' on the dashboard, 'xl' in the enlarge
       lightbox. Each renders only its own, so hovering the enlarged chart
       never animates a pill behind it. */
    ringTipAnchor = 'hero';
    ringTipX = 0;
    ringTipY = 0;

    // Animated display fields - the count-up engine reassigns these each frame.
    heroTotalDisplay = '0';
    gaugePctDisplay = '0';

    _leads = [];
    _roster = [];
    _rosterLoaded = false;
    _statusOrder = [];
    _loadSequence = 0;
    _filterFocusPending = false;
    _filterReturnFocusPending = false;
    /* Viewport rect of the header Filters chip, null when the inline trigger
       owns the anchor. */
    _filterAnchor = null;

    /* Chart enlarge: which visual is open in the lightbox. */
    openChart = '';
    _lightboxReturnFocusPending = false;
    _lightboxOpenerKey = '';
    _countRafs = {};
    _countState = {};
    _reducedMotion = false;

    connectedCallback() {
        this._reducedMotion =
            typeof window !== 'undefined' && window.matchMedia
                ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
                : false;
        this.loadData(false);
    }

    disconnectedCallback() {
        Object.keys(this._countRafs).forEach((key) => cancelAnimationFrame(this._countRafs[key]));
        this._countRafs = {};
    }

    renderedCallback() {
        if (this._filterFocusPending) {
            this._filterFocusPending = false;
            const field = this.template.querySelector('.perf-pop select');
            if (field) field.focus();
        }
        if (this._filterReturnFocusPending) {
            this._filterReturnFocusPending = false;
            const trigger = this.template.querySelector('.perf-filter-trigger');
            if (trigger) trigger.focus();
        }
        if (this._lightboxReturnFocusPending) {
            this._lightboxReturnFocusPending = false;
            const key = this._lightboxOpenerKey;
            this._lightboxOpenerKey = '';
            if (key === 'ring') {
                const button = this.template.querySelector('.perf-gauge-expand');
                if (button) button.focus();
            } else if (key === 'board') {
                const button = this.template.querySelector('.perf-board__expand');
                if (button) button.focus();
            } else if (key) {
                const chart = this.template.querySelector(`c-mbpr_chart[data-chart="${key}"]`);
                if (chart && typeof chart.focusExpand === 'function') chart.focusExpand();
            }
        }
    }

    /* ============================= Chart enlarge ============================= */

    handleChartExpand(event) {
        this.openChart = event.target.dataset.chart || '';
    }

    handleRingExpand() {
        this.openChart = 'ring';
    }

    handleBoardExpand() {
        this.openChart = 'board';
    }

    handleLightboxClose() {
        this._lightboxOpenerKey = this.openChart;
        this._lightboxReturnFocusPending = true;
        this.openChart = '';
        // Never leave a stale tip behind when the lightbox goes away.
        this.handleRingLeave();
    }

    get isLightboxOpen() {
        return Boolean(this.openChart);
    }

    get lightboxTitle() {
        const titles = {
            ring: 'Lead Status Distribution',
            board: 'Leads per Agent',
            trend: 'Leads by Month',
            project: 'Leads by Project',
            origin: 'Leads by Origin'
        };
        return titles[this.openChart] || 'Chart';
    }

    get isRingExpanded() {
        return this.openChart === 'ring';
    }

    get isBoardExpanded() {
        return this.openChart === 'board';
    }

    get isTrendExpanded() {
        return this.openChart === 'trend';
    }

    get isProjectExpanded() {
        return this.openChart === 'project';
    }

    get isOriginExpanded() {
        return this.openChart === 'origin';
    }

    /* Enlarged status ring: the same buckets as the hero ring, laid out as
       readable rows (label, count, share) beside the big ring. */
    get ringDetailRows() {
        const total = this.scopedLeads.length;
        return this.statusBuckets
            .filter((bucket) => bucket.count > 0)
            .map((bucket) => ({
                key: bucket.status,
                label: bucket.label,
                value: this.formatFull(bucket.count),
                pct: total > 0 ? `${Math.round((bucket.count / total) * 100)}%` : '0%',
                swatchStyle: `background: var(${this.toneVar(bucket.tone)});`
            }));
    }

    @api
    refresh() {
        this.loadData(true);
    }

    /* Header-chrome proxies: the gateway's Filters chip and
       agent select drive the dashboard through these. */
    @api
    toggleFilters(anchor) {
        this._filterAnchor = anchor && typeof anchor.bottom === 'number' ? anchor : null;
        this.toggleFilterPanel();
    }

    @api
    setAgentScope(value) {
        this.applyAgentScope(value || '');
    }

    /* With a header anchor the popover sits directly under the chip. Not
       position:fixed: the modal's scroll body is a containing block and
       re-bases fixed coordinates. The panel stays absolute in its toolbar and
       the offsets are the delta between the chip's and the toolbar's viewport
       rects, so any ancestor trap cancels out. The chip sits above this
       component's scroll body, so the ideal top is negative and the clamp is
       the measured scrollport top. Without an anchor the stylesheet's toolbar
       anchoring applies. */
    get filterPopStyle() {
        const anchor = this._filterAnchor;
        if (!anchor) return '';
        const toolbar = this.template.querySelector('.perf-toolbar');
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


    /* ============================= Loading ============================= */

    get isAgencyView() {
        return this.brokerType === 'Owner' || this.brokerType === 'Agency Admin';
    }

    /* Explicit dates for every period, the same definitions as mbpr_dashboardWorkspace
       so the Performance counts and the dashboard agree. All Time is a wide
       range (getFilteredLeads falls back to 1 Jan -> today when handed nulls);
       Last 12 Months = the 12 complete calendar months before this one; the
       financial year runs 1 Apr -> 31 Mar; Custom = the applied dates. */
    buildRange() {
        const today = new Date();
        const year = today.getFullYear();
        const iso = (d) =>
            `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        const ymd = (y, m, d) => `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
        const fyYear = today.getMonth() >= 3 ? year : year - 1;
        switch (this.selectedFilter) {
            case 'Custom':
                if (this.customStartDate && this.customEndDate) {
                    return { start: this.customStartDate, end: this.customEndDate };
                }
                break;
            case 'Current Year':
                return { start: ymd(year, 1, 1), end: ymd(year, 12, 31) };
            case 'Previous Year':
                return { start: ymd(year - 1, 1, 1), end: ymd(year - 1, 12, 31) };
            case 'Current FY':
                return { start: ymd(fyYear, 4, 1), end: ymd(fyYear + 1, 3, 31) };
            case 'Previous FY':
                return { start: ymd(fyYear - 1, 4, 1), end: ymd(fyYear, 3, 31) };
            case 'Last 12 Months': {
                const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
                const start = new Date(lastMonthEnd.getFullYear(), lastMonthEnd.getMonth() - 11, 1);
                return { start: iso(start), end: iso(lastMonthEnd) };
            }
            default:
                break;
        }
        // All Time (the default), and a Custom selection that carries no dates.
        const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
        return { start: '1900-01-01', end: iso(tomorrow) };
    }

    async loadData(isRefresh) {
        const sequence = ++this._loadSequence;
        if (isRefresh) {
            this.isRefreshing = true;
        } else {
            this.isInitializing = true;
        }
        this.loadError = '';
        const range = this.buildRange();
        // Explicit dates always accompany the filterType so leads land in the
        // exact same window the trend/momentum math assumes client-side.
        const [leads, roster, statuses] = await Promise.all([
            getFilteredLeads({
                userId: USER_ID,
                filterType: this.selectedFilter,
                startDate: range.start,
                endDate: range.end
            }).catch(() => null),
            this.isAgencyView && !this._rosterLoaded
                ? getContactsUserInfo().catch(() => undefined)
                : Promise.resolve(undefined),
            this._statusOrder.length
                ? Promise.resolve(undefined)
                : getPicklist({ objectName: 'Lead', fieldName: 'Status' }).catch(() => undefined)
        ]);
        if (sequence !== this._loadSequence) return;
        if (leads === null) {
            this.loadError = LOAD_ERROR_MESSAGE;
            this.isInitializing = false;
            this.isRefreshing = false;
            return;
        }
        // A row is one customer, and children holds each of their leads. Counting rows counted
        // customers, so repeat leads and the conversions among them never showed up.
        this._leads = (Array.isArray(leads) ? leads : []).reduce((all, row) => {
            const group = Array.isArray(row.children) && row.children.length ? row.children : [row];
            return all.concat(group);
        }, []);
        if (roster !== undefined) {
            this._roster = (roster || [])
                .filter((row) => row && row.user && row.user.Id)
                .map((row) => ({
                    userId: row.user.Id,
                    name: (row.contact && row.contact.Name) || 'Agent',
                    role: (row.contact && row.contact.Broker_Type__c) || 'Agent',
                    active: ((row.contact && row.contact.Agent_Status__c) || '') === 'Active'
                }));
            this._rosterLoaded = true;
        }
        if (statuses !== undefined && statuses && Array.isArray(statuses.values)) {
            this._statusOrder = statuses.values;
        }
        // Keep the focus only while its agent still exists somewhere - in the
        // roster (picker choices stay valid even with zero leads this period)
        // or in the period's data (former agents / unattributed creators).
        if (
            this.scopeKey &&
            !this._roster.some((row) => row.userId === this.scopeKey) &&
            !this._leads.some((lead) => lead.CreatedById === this.scopeKey)
        ) {
            this.scopeKey = '';
            this.scopeLabel = '';
        }
        this.isInitializing = false;
        this.isRefreshing = false;
        this.runCountUps();
        this.publishChromeState();
    }

    runCountUps() {
        this.animateCount('heroTotalDisplay', this.scopedLeads.length, (value) =>
            this.formatFull(Math.round(value))
        );
        this.animateCount('gaugePctDisplay', this.convertedPct, (value) => String(Math.round(value)));
    }

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

    /* ============================= Scope ============================= */

    get scopedLeads() {
        if (!this.scopeKey || !this.isAgencyView) return this._leads;
        return this._leads.filter((lead) => lead.CreatedById === this.scopeKey);
    }

    get isScoped() {
        return Boolean(this.scopeKey) && this.isAgencyView;
    }

    agentNameFor(lead) {
        const match = this._roster.find((row) => row.userId === lead.CreatedById);
        if (match) return match.name;
        return lead.AgentName || 'Unattributed';
    }

    clearScope() {
        this.scopeKey = '';
        this.scopeLabel = '';
        this.runCountUps();
        this.publishChromeState();
    }

    get showAgentPicker() {
        return this.isAgencyView;
    }

    /* Roster members first, alphabetical and selectable even with zero leads,
       then named creators no longer on the roster. Blank-name creators stay
       reachable through their leaderboard row. */
    get agentPickerOptions() {
        const options = [{ key: 'all', value: '', label: 'All agents', selected: !this.scopeKey }];
        const seen = new Set();
        [...this._roster]
            .sort((a, b) => a.name.localeCompare(b.name))
            .forEach((row) => {
                seen.add(row.userId);
                options.push({
                    key: row.userId,
                    value: row.userId,
                    label: row.name,
                    selected: this.scopeKey === row.userId
                });
            });
        const extras = [];
        this._leads.forEach((lead) => {
            if (seen.has(lead.CreatedById)) return;
            const name = (lead.AgentName || '').trim();
            if (!name) return;
            seen.add(lead.CreatedById);
            extras.push({
                key: lead.CreatedById,
                value: lead.CreatedById,
                label: name,
                selected: this.scopeKey === lead.CreatedById
            });
        });
        extras.sort((a, b) => a.label.localeCompare(b.label));
        return [...options, ...extras];
    }

    /* ---- Smart agent picker ---- */

    get selectedAgentLabel() {
        const selected = this.agentPickerOptions.find((option) => option.selected);
        return selected ? selected.label : 'All agents';
    }

    get agentInputValue() {
        return this.isAgentPickerOpen ? this.agentSearch : this.selectedAgentLabel;
    }

    get filteredAgentOptions() {
        const query = String(this.agentSearch || '')
            .trim()
            .toLowerCase();
        const tokens = query ? query.split(/\s+/).filter(Boolean) : [];
        return this.agentPickerOptions
            .filter((option) => {
                if (!tokens.length) return true;
                const haystack = String(option.label || '').toLowerCase();
                return tokens.every((token) => haystack.includes(token));
            })
            .map((option, index) => {
                const classes = ['perf-agent-option'];
                if (option.selected) classes.push('perf-agent-option--selected');
                if (index === this.agentActiveIndex) classes.push('perf-agent-option--active');
                return {
                    ...option,
                    index,
                    // '' (All agents) would be falsy in the dataset guard, so
                    // every option carries a non-empty pick token.
                    pickValue: option.value || '__all__',
                    className: classes.join(' ')
                };
            });
    }

    get hasAgentOptions() {
        return this.filteredAgentOptions.length > 0;
    }

    get agentPickerExpanded() {
        return this.isAgentPickerOpen ? 'true' : 'false';
    }

    handleAgentFocus(event) {
        window.clearTimeout(this._agentBlurTimeout);
        this.isAgentPickerOpen = true;
        this.agentSearch = '';
        this.agentActiveIndex = 0;
        const input = event.currentTarget;
        window.requestAnimationFrame(() => {
            if (input && typeof input.select === 'function') input.select();
        });
    }

    handleAgentInput(event) {
        this.isAgentPickerOpen = true;
        this.agentSearch = event.target.value || '';
        this.agentActiveIndex = 0;
    }

    handleAgentKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            // Never let Escape reach the workspace modal behind this picker.
            event.stopPropagation();
            this.closeAgentPicker();
            event.currentTarget.blur();
            return;
        }
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp' && event.key !== 'Enter') return;
        const options = this.filteredAgentOptions;
        if (!options.length) return;
        if (event.key === 'Enter') {
            event.preventDefault();
            const option = options[this.agentActiveIndex] || options[0];
            this.pickAgentOption(option.value);
            event.currentTarget.blur();
            return;
        }
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        const next = (this.agentActiveIndex + step + options.length) % options.length;
        this.agentActiveIndex = next;
    }

    handleAgentBlur() {
        window.clearTimeout(this._agentBlurTimeout);
        this._agentBlurTimeout = window.setTimeout(() => {
            this.closeAgentPicker();
        }, 120);
    }

    handleAgentOptionMouseDown(event) {
        // mousedown + preventDefault so the input never blurs first.
        event.preventDefault();
        const picked = event.currentTarget.dataset.value;
        if (!picked) return;
        this.pickAgentOption(picked === '__all__' ? '' : picked);
    }

    pickAgentOption(value) {
        this.closeAgentPicker();
        this.applyAgentScope(value || '');
    }

    closeAgentPicker() {
        window.clearTimeout(this._agentBlurTimeout);
        this.isAgentPickerOpen = false;
        this.agentSearch = '';
        this.agentActiveIndex = 0;
    }

    applyAgentScope(value) {
        if (!value) {
            this.clearScope();
            return;
        }
        const option = this.agentPickerOptions.find((candidate) => candidate.value === value);
        this.scopeKey = value;
        this.scopeLabel = option ? option.label : 'Agent';
        this.runCountUps();
        this.publishChromeState();
    }

    /* Keeps the header's mirrored agent picker and Filters chip in sync.
       Signature-deduped so a re-render cannot churn an open select. */
    _lastChromeSignature = '';

    publishChromeState() {
        const detail = {
            showAgentPicker: this.showAgentPicker,
            agentOptions: this.agentPickerOptions,
            filterLabel: this.activeFilterLabel,
            filterIsDefault: this.isDefaultPeriod
        };
        const signature = JSON.stringify(detail);
        if (signature === this._lastChromeSignature) return;
        this._lastChromeSignature = signature;
        this.dispatchEvent(new CustomEvent('chromestate', { detail }));
    }

    /* ============================= Aggregations ============================= */

    get statusBuckets() {
        const counts = new Map();
        this.scopedLeads.forEach((lead) => {
            const status = lead.Status || 'New';
            counts.set(status, (counts.get(status) || 0) + 1);
        });
        const known = this._statusOrder.filter((status) => counts.has(status));
        const unknown = [...counts.keys()]
            .filter((status) => !this._statusOrder.includes(status))
            .sort((a, b) => counts.get(b) - counts.get(a));
        return [...known, ...unknown].map((status) => {
            const alias = STATUS_DISPLAY[status];
            return {
                status,
                label: alias ? alias.label : status,
                count: counts.get(status),
                tone: alias ? alias.tone : statusToneOf(status)
            };
        });
    }

    get toneBuckets() {
        const totals = { active: 0, warning: 0, success: 0, error: 0, muted: 0, info: 0 };
        this.statusBuckets.forEach((bucket) => {
            totals[bucket.tone] += bucket.count;
        });
        return totals;
    }

    get convertedPct() {
        const total = this.scopedLeads.length;
        if (!total) return 0;
        return Math.min(100, Math.max(0, Math.round((this.toneBuckets.success / total) * 100)));
    }

    /* Month buckets across the active range, oldest first, future months
       trimmed. BP-033: All Time starts at the earliest loaded lead (never
       1900) and the range is tail-sliced to the latest MAX_TREND_MONTHS, so
       the newest months are always on the chart. */
    get monthBuckets() {
        const range = this.buildRange();
        let startDate = new Date(`${range.start}T00:00:00`);
        const endDate = new Date(`${range.end}T00:00:00`);
        const today = new Date();
        if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) return [];
        const stop = endDate < today ? endDate : today;
        if (this.selectedFilter === 'All Time') {
            let earliest = null;
            this.scopedLeads.forEach((lead) => {
                const created = new Date(lead.CreatedDate);
                if (!Number.isNaN(created.getTime()) && (!earliest || created < earliest)) earliest = created;
            });
            startDate = earliest || stop;
        }
        const floor = new Date(stop.getFullYear(), stop.getMonth() - (MAX_TREND_MONTHS - 1), 1);
        if (startDate < floor) startDate = floor;
        const buckets = [];
        const cursor = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
        while (cursor <= stop && buckets.length < MAX_TREND_MONTHS) {
            buckets.push({
                key: `${cursor.getFullYear()}-${cursor.getMonth()}`,
                label:
                    cursor.getMonth() === 0 || buckets.length === 0
                        ? `${MONTH_SHORT[cursor.getMonth()]} ${String(cursor.getFullYear()).slice(2)}`
                        : MONTH_SHORT[cursor.getMonth()],
                value: 0
            });
            cursor.setMonth(cursor.getMonth() + 1);
        }
        const index = new Map(buckets.map((bucket, i) => [bucket.key, i]));
        this.scopedLeads.forEach((lead) => {
            const created = new Date(lead.CreatedDate);
            if (Number.isNaN(created.getTime())) return;
            const key = `${created.getFullYear()}-${created.getMonth()}`;
            if (index.has(key)) {
                buckets[index.get(key)].value += 1;
            }
        });
        return buckets;
    }

    /* ============================= Hero ============================= */

    /* Real status names (picklist order), not tone-group labels - the ring
       and the chips must say what the data actually says. */
    get heroChips() {
        return this.statusBuckets
            .filter((bucket) => bucket.count > 0)
            .slice(0, 4)
            .map((bucket) => ({
                key: bucket.status,
                label: bucket.label,
                value: this.formatFull(bucket.count),
                dotClass: `perf-chip__dot perf-chip__dot--${bucket.tone}`
            }));
    }

    get heroScopeLine() {
        let who = 'Your leads';
        if (this.isScoped) {
            who = `${this.scopeLabel}'s leads`;
        } else if (this.isAgencyView) {
            who = 'Agency-wide leads';
        }
        return `${who} · ${this.activeFilterLabel}`;
    }

    /* Every status paints its share of the circle: pathLength-normalised,
       12 o'clock start, 2.4 gap between slices. Colours follow the tones. */
    get statusRing() {
        const total = this.scopedLeads.length;
        const visible = this.statusBuckets.filter((bucket) => bucket.count > 0);
        if (!total || !visible.length) return [];
        const gap = visible.length > 1 ? 2.4 : 0;
        const usable = 100 - gap * visible.length;
        const anyHover = this.ringIndex > -1;
        let consumed = 0;
        return visible.map((bucket, index) => {
            const length = Math.max((bucket.count / total) * usable, 0.4);
            const offset = 25 - consumed;
            consumed += length + gap;
            const classes = ['perf-gauge__seg', `perf-gauge__seg--${bucket.tone}`];
            if (anyHover) {
                classes.push(index === this.ringIndex ? 'perf-gauge__seg--hot' : 'perf-gauge__seg--dim');
            }
            return {
                key: bucket.status,
                index,
                label: bucket.label,
                count: bucket.count,
                percent: Math.round((bucket.count / total) * 100),
                tone: bucket.tone,
                className: classes.join(' '),
                style: `stroke-dasharray: ${length.toFixed(2)} ${(100 - length).toFixed(2)}; stroke-dashoffset: ${offset.toFixed(2)}; --seg-delay: ${index * 90}ms;`
            };
        });
    }

    toneVar(tone) {
        const map = {
            active: '--perf-viz-active',
            warning: '--perf-viz-warning',
            success: '--perf-viz-success',
            error: '--perf-viz-error',
            muted: '--perf-viz-muted',
            info: '--perf-viz-info'
        };
        return map[tone] || '--perf-viz-active';
    }

    handleRingEnter(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index)) return;
        const seg = this.statusRing[index];
        if (!seg) return;
        this.ringIndex = index;
        this.ringTipRow = {
            label: seg.label,
            value: this.formatFull(seg.count),
            pct: `${seg.percent}%`,
            swatchStyle: `background: var(${this.toneVar(seg.tone)});`
        };
        this.ringTipOn = true;
        this.setRingTipPosition(event);
    }

    handleRingMove(event) {
        if (!this.ringTipOn) return;
        this.setRingTipPosition(event);
    }

    /* The board lives inside.perf-hero, so the segments share the hero tooltip
       and its clamped positioning. pct is the status's share of that agent's
       leads. Move and leave reuse the ring handlers, with ringIndex left at
       -1 so no ring dimming kicks in. */
    handleBarEnter(event) {
        const data = event.currentTarget.dataset;
        this.ringTipRow = {
            label: data.label,
            value: this.formatFull(Number(data.value) || 0),
            pct: `${data.pct}%`,
            swatchStyle: `background: var(${this.toneVar(data.tone)});`
        };
        this.ringTipOn = true;
        this.setRingTipPosition(event);
    }

    handleRingLeave() {
        this.ringIndex = -1;
        this.ringTipOn = false;
        this.ringTipRow = null;
    }

    setRingTipPosition(event) {
        /* Anchor to whichever surface hosts the hovered mark: the hero on
           the dashboard, or the enlarged wrapper inside the lightbox. */
        const xl = event.currentTarget.closest('.perf-xl');
        this.ringTipAnchor = xl ? 'xl' : 'hero';
        const card = xl || this.template.querySelector('.perf-hero');
        if (!card) return;
        const rect = card.getBoundingClientRect();
        let x = event.clientX - rect.left + 14;
        let y = event.clientY - rect.top - 12;
        x = Math.min(Math.max(x, 8), Math.max(rect.width - 190, 8));
        y = Math.min(Math.max(y, 8), Math.max(rect.height - 48, 8));
        this.ringTipX = Math.round(x);
        this.ringTipY = Math.round(y);
    }

    get ringTipClass() {
        return this.ringTipOn ? 'perf-tip perf-tip--on' : 'perf-tip';
    }

    get heroTipRow() {
        return this.ringTipAnchor === 'hero' ? this.ringTipRow : null;
    }

    get xlTipRow() {
        return this.ringTipAnchor === 'xl' ? this.ringTipRow : null;
    }

    get ringTipStyle() {
        return `left: ${this.ringTipX}px; top: ${this.ringTipY}px;`;
    }

    get gaugeAriaLabel() {
        const parts = this.statusBuckets
            .filter((bucket) => bucket.count > 0)
            .map((bucket) => `${bucket.label} ${bucket.count}`);
        return `Lead statuses: ${parts.join(', ') || 'none'}. Converted to opportunity share ${this.convertedPct} percent.`;
    }

    bucketBy(labelOf) {
        const counts = new Map();
        this.scopedLeads.forEach((lead) => {
            const label = labelOf(lead);
            counts.set(label, (counts.get(label) || 0) + 1);
        });
        return [...counts.entries()]
            .map(([label, value]) => ({ label, value }))
            .sort((a, b) => b.value - a.value);
    }

    /* ============================= Trend chart ============================= */

    /* Single series on purpose (numbers audit): every monthly column sums
       exactly to the hero total - no split figures to reconcile on hover. */
    get trendColumns() {
        return this.monthBuckets.map((bucket) => ({
            label: bucket.label,
            stacks: [{ name: 'Leads', value: bucket.value }]
        }));
    }

    /* ============================= Leaderboard ============================= */

    /* Whole-agency view only - the card is comparative, so it hides while
       one agent is focused (the picker is the single scoping control). */
    get showLeaderboard() {
        return this.isAgencyView && !this.isScoped;
    }

    /* Deliberately minimal (user rule): rank, name, share bar, lead count -
       one number per row. Deeper detail lives in the focused view. */
    get leaderboardRows() {
        const counts = new Map();
        this._leads.forEach((lead) => {
            const key = lead.CreatedById || 'unknown';
            const entry = counts.get(key) || { count: 0, sample: lead, statuses: new Map() };
            entry.count += 1;
            // Same normalization as statusBuckets, so every lead lands in a segment.
            const status = lead.Status || 'New';
            entry.statuses.set(status, (entry.statuses.get(status) || 0) + 1);
            counts.set(key, entry);
        });
        const rows = [...counts.entries()]
            .map(([key, entry]) => {
                const roster = this._roster.find((row) => row.userId === key);
                return {
                    key,
                    name: roster ? roster.name : entry.sample.AgentName || 'Unattributed',
                    inactive: roster ? !roster.active : false,
                    count: entry.count,
                    statuses: entry.statuses
                };
            })
            .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
        const max = rows.length ? rows[0].count : 0;
        // Status distribution per agent: each bar is stacked in the hero
        // ring's tones (picklist order, aliased labels), lengths still
        // proportional to the top agent so ranks stay comparable.
        const statusOrder = this.statusBuckets;
        return rows.map((row, index) => ({
            ...row,
            rank: String(index + 1).padStart(2, '0'),
            countDisplay: this.formatFull(row.count),
            statusDotClass: row.inactive ? 'perf-row__state perf-row__state--off' : 'perf-row__state',
            rowStyle: `--row-i: ${Math.min(index, 12) * 60}ms;`,
            segments: statusOrder
                .filter((bucket) => (row.statuses.get(bucket.status) || 0) > 0)
                .map((bucket, segIndex) => {
                    const segCount = row.statuses.get(bucket.status);
                    return {
                        key: bucket.status,
                        label: bucket.label,
                        count: segCount,
                        pct: row.count > 0 ? Math.round((segCount / row.count) * 100) : 0,
                        tone: bucket.tone,
                        style:
                            `width: ${max > 0 ? ((segCount / max) * 100).toFixed(2) : 0}%; ` +
                            `background: var(${this.toneVar(bucket.tone)}); ` +
                            `--seg-delay: ${Math.min(index, 12) * 70 + segIndex * 45}ms;`
                    };
                })
        }));
    }

    /* Colour key for the stacked rows - every status present this period,
       in the same aliased labels and tones as the hero ring. */
    get boardLegend() {
        return this.statusBuckets
            .filter((bucket) => bucket.count > 0)
            .map((bucket) => ({
                key: bucket.status,
                label: bucket.label,
                dotClass: `perf-chip__dot perf-chip__dot--${bucket.tone}`
            }));
    }

    get hasLeaderboardRows() {
        return this.leaderboardRows.length > 0;
    }

    /* ============================= Donuts ============================= */

    donutSegmentsFor(labelOf) {
        const buckets = this.bucketBy(labelOf);
        /* Five buckets or fewer render as they are, the fifth taking gray.
           Longer lists fold ranks 5 and up into one gray "Other", since a
           real category beside "Other" in the same gray is unreadable. */
        if (buckets.length <= MAX_DONUT_SEGMENTS + 1) return buckets;
        const head = buckets.slice(0, MAX_DONUT_SEGMENTS);
        const rest = buckets.slice(MAX_DONUT_SEGMENTS).reduce((sum, bucket) => sum + bucket.value, 0);
        return [...head, { label: 'Other', value: rest }];
    }

    get projectDonutSegments() {
        return this.donutSegmentsFor((lead) => lead.ProjectInterest || lead.Project || 'Not specified');
    }

    get originDonutSegments() {
        return this.donutSegmentsFor((lead) => lead.LeadOrigin || lead.SalesOrigin || 'Not specified');
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
        return this.isDefaultPeriod ? 'perf-filter-trigger' : 'perf-filter-trigger perf-filter-trigger--active';
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
        // Only a listed value can be applied; anything else falls back to the default.
        const next = FILTER_OPTIONS.some((option) => option.value === this.draftFilter) ? this.draftFilter : DEFAULT_FILTER;
        this.selectedFilter = next;
        this.draftFilter = next;
        this.customStartDate = next === 'Custom' ? this.draftStartDate : null;
        this.customEndDate = next === 'Custom' ? this.draftEndDate : null;
        this.closeFilterPanel();
        this.publishChromeState();
        this.loadData(true);
    }

    resetFilters() {
        this.draftFilter = DEFAULT_FILTER;
        this.draftStartDate = null;
        this.draftEndDate = null;
        this.selectedFilter = DEFAULT_FILTER;
        this.customStartDate = null;
        this.customEndDate = null;
        this.closeFilterPanel();
        this.publishChromeState();
        this.loadData(true);
    }

    retryLoad() {
        this.loadData(false);
    }

    /* ============================= Display ============================= */

    get showContent() {
        return !this.isInitializing && !this.loadError;
    }

    get showLoadError() {
        return !this.isInitializing && Boolean(this.loadError);
    }

    get contentClass() {
        let className = this.isRefreshing ? 'perf perf--busy' : 'perf';
        if (this.chromeHosted) className += ' perf--chrome-hosted';
        return className;
    }

    get hasAnyLeads() {
        return this.scopedLeads.length > 0;
    }

    formatFull(value) {
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(Number(value) || 0);
    }
}