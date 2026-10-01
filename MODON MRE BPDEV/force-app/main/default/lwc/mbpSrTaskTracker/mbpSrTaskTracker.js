import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTasks from '@salesforce/apex/MBP_SrTaskTrackerController.getTasks';

const SEARCH_DEBOUNCE_MS = 400;

const FILTER_ALL = 'ALL';
const FILTER_RESUBMITTED = 'RESUBMITTED';

// Subject filters - values must match Task.Subject exactly
const SUBJECT_FILTERS = [
    { value: FILTER_ALL, label: 'All Tasks', tone: 'all' },
    { value: 'Assignment of Broker Manager', label: 'Assignment of Broker Manager', tone: 'abm' },
    { value: 'Require more information', label: 'Require More Information', tone: 'rmi' },
    { value: 'Validation by Compliance Team', label: 'Compliance Validation', tone: 'compliance' },
    { value: 'Send for Signature', label: 'Send for Signature', tone: 'signature' },
    { value: 'Validation by Broker Sales Admin', label: 'Sales Admin Validation', tone: 'admin' },
    { value: FILTER_RESUBMITTED, label: 'Resubmitted', tone: 'resub' }
];

const COLUMNS = [
    { key: 'sr', label: 'Service Request' },
    { key: 'srStatus', label: 'SR Status' },
    { key: 'registration', label: 'Registration' },
    { key: 'subject', label: 'Task', sortField: 'Subject' },
    { key: 'taskStatus', label: 'Task Status', sortField: 'Status' },
    { key: 'assignedTo', label: 'Assigned To' },
    { key: 'updatedBy', label: 'Updated By', sortField: 'LastModifiedDate' },
    { key: 'dueDate', label: 'Due Date', sortField: 'ActivityDate' }
];

const TASK_STATUS_OPTIONS = [
    { label: 'All task statuses', value: FILTER_ALL },
    { label: 'Open', value: 'OPEN' },
    { label: 'Completed', value: 'COMPLETED' }
];

const PAGE_SIZE_OPTIONS = [10, 25, 50, 100];

const DEFAULTS = {
    subjectFilter: FILTER_ALL,
    searchTerm: '',
    taskStatus: FILTER_ALL,
    srStatus: FILTER_ALL,
    pageNumber: 1,
    pageSize: 10,
    sortBy: 'LastModifiedDate',
    sortDir: 'DESC'
};

export default class MbpSrTaskTracker extends NavigationMixin(LightningElement) {
    // Filter state
    subjectFilter = DEFAULTS.subjectFilter;
    searchTerm = DEFAULTS.searchTerm;
    taskStatus = DEFAULTS.taskStatus;
    srStatus = DEFAULTS.srStatus;
    pageNumber = DEFAULTS.pageNumber;
    pageSize = DEFAULTS.pageSize;
    sortBy = DEFAULTS.sortBy;
    sortDir = DEFAULTS.sortDir;

    // Data state
    rows = [];
    counts = {};
    totalRecords = 0;
    totalPages = 1;
    offsetCapped = false;
    srStatusValues = [];
    isLoading = true;
    errorMessage;

    taskStatusOptions = TASK_STATUS_OPTIONS;
    skeletonRows = Array.from({ length: 6 }, (_, i) => ({ key: `sk-${i}` }));

    _searchTimer;
    _requestSeq = 0;

    connectedCallback() {
        this.loadData();
    }

    disconnectedCallback() {
        clearTimeout(this._searchTimer);
    }

    // ---------------------------------------------------------------- Data

    async loadData() {
        const seq = ++this._requestSeq;
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const res = await getTasks({
                requestJson: JSON.stringify({
                    subjectFilter: this.subjectFilter,
                    searchTerm: this.searchTerm,
                    taskStatus: this.taskStatus,
                    srStatus: this.srStatus,
                    pageNumber: this.pageNumber,
                    pageSize: this.pageSize,
                    sortBy: this.sortBy,
                    sortDir: this.sortDir
                })
            });

            // Ignore stale responses (fast typing / clicking)
            if (seq !== this._requestSeq) {
                return;
            }

            this.rows = (res.rows || []).map((r) => this.decorateRow(r));
            this.counts = res.counts || {};
            this.totalRecords = res.totalRecords || 0;
            this.totalPages = res.totalPages || 1;
            this.pageNumber = res.pageNumber || 1;
            this.offsetCapped = res.offsetCapped;
            this.srStatusValues = res.srStatusOptions || [];
        } catch (error) {
            if (seq !== this._requestSeq) {
                return;
            }
            this.rows = [];
            this.totalRecords = 0;
            this.errorMessage = this.reduceError(error);
        } finally {
            if (seq === this._requestSeq) {
                this.isLoading = false;
            }
        }
    }

    decorateRow(r) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const due = r.dueDate ? new Date(`${r.dueDate}T00:00:00`) : null;
        const isOverdue = !r.isClosed && due && due < today;

        return {
            ...r,
            srHref: r.srId ? `/${r.srId}` : null,
            registrationHref: r.registrationId ? `/${r.registrationId}` : null,
            srStatusClass: `badge ${this.srStatusTone(r.srStatus)}`,
            taskStatusClass: `status ${this.taskStatusTone(r.taskStatus, r.isClosed)}`,
            subjectDotClass: `subject-dot subject-dot--${this.subjectTone(r.subject)}`,
            rowClass: r.isResubmission ? 'grid__row grid__row--resub' : 'grid__row',
            initials: this.initials(r.assignedTo),
            updatedInitials: this.initials(r.updatedBy),
            dueClass: isOverdue ? 'due due--overdue' : 'due',
            isOverdue
        };
    }

    // ---------------------------------------------------------------- Getters

    get subjectPills() {
        return SUBJECT_FILTERS.map((f) => {
            const selected = f.value === this.subjectFilter;
            return {
                ...f,
                count: this.counts[f.value] ?? 0,
                selected: String(selected),
                cssClass: `pill pill--${f.tone}${selected ? ' pill--active' : ''}`
            };
        });
    }

    get columnHeaders() {
        return COLUMNS.map((c) => {
            const sortable = !!c.sortField;
            const active = sortable && c.sortField === this.sortBy;
            let sortIcon = '';
            if (sortable) {
                sortIcon = active ? (this.sortDir === 'ASC' ? '▲' : '▼') : '↕';
            }
            return {
                ...c,
                sortIcon,
                ariaSort: active ? (this.sortDir === 'ASC' ? 'ascending' : 'descending') : 'none',
                cssClass: `grid__th${sortable ? ' grid__th--sortable' : ''}${active ? ' grid__th--active' : ''}`
            };
        });
    }

    get srStatusOptions() {
        return [
            { label: 'All SR statuses', value: FILTER_ALL },
            ...this.srStatusValues.map((s) => ({ label: s, value: s }))
        ];
    }

    get pageSizeOptions() {
        return PAGE_SIZE_OPTIONS.map((size) => ({
            value: String(size),
            label: `${size} / page`,
            selected: size === this.pageSize
        }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get isResubmittedView() {
        return this.subjectFilter === FILTER_RESUBMITTED;
    }

    get activeFilterLabel() {
        const f = SUBJECT_FILTERS.find((x) => x.value === this.subjectFilter);
        return f ? f.label : 'All Tasks';
    }

    get isDefaultState() {
        return (
            this.subjectFilter === DEFAULTS.subjectFilter &&
            !this.searchTerm &&
            this.taskStatus === DEFAULTS.taskStatus &&
            this.srStatus === DEFAULTS.srStatus
        );
    }

    get rangeStart() {
        return this.totalRecords === 0 ? 0 : (this.pageNumber - 1) * this.pageSize + 1;
    }

    get rangeEnd() {
        return Math.min(this.pageNumber * this.pageSize, this.totalRecords);
    }

    get isFirstPage() {
        return this.pageNumber <= 1 || this.isLoading;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.isLoading;
    }

    get pageButtons() {
        const total = this.totalPages;
        const current = this.pageNumber;
        const windowSize = 5;
        const pages = [];

        let start = Math.max(1, current - Math.floor(windowSize / 2));
        let end = Math.min(total, start + windowSize - 1);
        start = Math.max(1, end - windowSize + 1);

        const push = (page, label, isEllipsis = false) => {
            pages.push({
                key: isEllipsis ? `el-${label}-${pages.length}` : `p-${page}`,
                page,
                label,
                disabled: isEllipsis || this.isLoading,
                cssClass: `pager__btn${page === current && !isEllipsis ? ' pager__btn--active' : ''}${
                    isEllipsis ? ' pager__btn--ellipsis' : ''
                }`
            });
        };

        if (start > 1) {
            push(1, '1');
            if (start > 2) push(null, '…', true);
        }
        for (let p = start; p <= end; p++) {
            push(p, String(p));
        }
        if (end < total) {
            if (end < total - 1) push(null, '…', true);
            push(total, String(total));
        }
        return pages;
    }

    // ---------------------------------------------------------------- Handlers

    handleSubjectFilter(event) {
        const value = event.currentTarget.dataset.value;
        if (value === this.subjectFilter) return;
        this.subjectFilter = value;
        this.pageNumber = 1;
        this.loadData();
    }

    handleSearch(event) {
        const value = (event.target.value || '').trim();
        clearTimeout(this._searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            if (value === this.searchTerm) return;
            this.searchTerm = value;
            this.pageNumber = 1;
            this.loadData();
        }, SEARCH_DEBOUNCE_MS);
    }

    handleTaskStatusChange(event) {
        this.taskStatus = event.detail.value;
        this.pageNumber = 1;
        this.loadData();
    }

    handleSrStatusChange(event) {
        this.srStatus = event.detail.value;
        this.pageNumber = 1;
        this.loadData();
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        if (this.sortBy === field) {
            this.sortDir = this.sortDir === 'ASC' ? 'DESC' : 'ASC';
        } else {
            this.sortBy = field;
            this.sortDir = 'ASC';
        }
        this.pageNumber = 1;
        this.loadData();
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.pageNumber = 1;
        this.loadData();
    }

    handleFirst() {
        this.goToPage(1);
    }

    handlePrevious() {
        this.goToPage(this.pageNumber - 1);
    }

    handleNext() {
        this.goToPage(this.pageNumber + 1);
    }

    handleLast() {
        this.goToPage(this.totalPages);
    }

    handlePageClick(event) {
        this.goToPage(parseInt(event.currentTarget.dataset.page, 10));
    }

    goToPage(page) {
        if (!page || page < 1 || page > this.totalPages || page === this.pageNumber) return;
        this.pageNumber = page;
        this.loadData();
        const top = this.template.querySelector('.tracker');
        if (top && top.scrollIntoView) {
            top.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    handleRefresh() {
        this.loadData();
    }

    handleClearFilters() {
        clearTimeout(this._searchTimer);
        this.subjectFilter = DEFAULTS.subjectFilter;
        this.searchTerm = DEFAULTS.searchTerm;
        this.taskStatus = DEFAULTS.taskStatus;
        this.srStatus = DEFAULTS.srStatus;
        this.pageNumber = 1;
        const search = this.template.querySelector('.toolbar__search');
        if (search) search.value = '';
        this.loadData();
    }

    handleNavigate(event) {
        // Allow ctrl/cmd/middle click to open in a new tab via the href
        if (event.ctrlKey || event.metaKey || event.shiftKey || event.button === 1) return;
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    // ---------------------------------------------------------------- Utils

    srStatusTone(status) {
        const s = (status || '').toLowerCase();
        if (s === 'closed' || s === 'approved' || s === 'completed') return 'badge--success';
        if (s.includes('progress') || s === 'submitted' || s === 'open') return 'badge--info';
        if (s.includes('reject') || s.includes('cancel') || s.includes('void')) return 'badge--danger';
        if (s.includes('draft') || s.includes('pending') || s.includes('hold')) return 'badge--warning';
        return 'badge--neutral';
    }

    taskStatusTone(status, isClosed) {
        const s = (status || '').toLowerCase();
        if (isClosed || s === 'completed') return 'status--done';
        if (s.includes('progress')) return 'status--progress';
        if (s.includes('waiting') || s.includes('deferred')) return 'status--waiting';
        return 'status--open';
    }

    subjectTone(subject) {
        const f = SUBJECT_FILTERS.find((x) => x.value === subject);
        return f ? f.tone : 'all';
    }

    initials(name) {
        if (!name) return '–';
        const parts = name.trim().split(/\s+/);
        return ((parts[0] || '')[0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Something went wrong while loading tasks.';
    }
}