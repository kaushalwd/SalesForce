import { LightningElement, track, wire } from 'lwc';
import getInventoryUnits from '@salesforce/apex/UAE_EgyptInventoryManagementController.getInventoryUnits';
import getFilterOptions  from '@salesforce/apex/UAE_EgyptInventoryManagementController.getFilterOptions';
import getTotalCount     from '@salesforce/apex/UAE_EgyptInventoryManagementController.getTotalCount';
import getGrandTotalCount from '@salesforce/apex/UAE_EgyptInventoryManagementController.getGrandTotalCount';
import updateUnitsStatus from '@salesforce/apex/UAE_EgyptInventoryManagementController.updateUnitsStatus';

import { EGYPT_MANAGE_INVENTORY_CONSTANTS, CONSTANTS } from 'c/modonEgyptConstants';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Flattens relationship fields onto plain keys so lightning-datatable
 * can bind to them (fieldName only supports flat keys, not dotted paths).
 */
function flattenUnit(unit) {
    return {
        ...unit,
        PhaseName:  unit.Phase__r  ? unit.Phase__r.Name  : '',
        BucketName: unit.Bucket__r ? unit.Bucket__r.Name : ''
    };
}

/**
 * Resolves a GFA range label string (e.g. "200 – 400 sqm") to its
 * { min, max } Decimal bounds for the Apex InventoryFilters DTO.
 * Returns { min: null, max: null } when the label is not recognised
 * (i.e. "-- All --" or blank), meaning no GFA filter is applied.
 */
function resolveGfaRange(label) {
    if (!label) return { min: null, max: null };
    const range = EGYPT_MANAGE_INVENTORY_CONSTANTS.GFA_RANGES.find(r => r.label === label);
    return range ? { min: range.min, max: range.max } : { min: null, max: null };
}

export default class UAE_EgyptInventoryManagement extends LightningElement {

    // ── Data state ────────────────────────────────────────────────────────
    @track inventoryUnits = [];
    selectedRowKeys       = [];     // IDs of checked rows
    selectedRows          = [];     // full row objects of checked rows
    blockComments         = '';
    isLoading             = false;
    isLoadingMore         = false;
    hasMoreRecords        = true;
    currentOffset         = 0;

    // ── Stats bar ─────────────────────────────────────────────────────────
    grandTotal    = 0;   // total UAE + Egypt units (no user filters)
    filteredTotal = 0;   // total matching current filters

    // ── Responsive / mobile state ─────────────────────────────────────────
    viewportWidth  = window.innerWidth;
    mobileColumnMode = 'compact'; // 'compact' | 'scroll'
    detailRecord   = null;        // row currently shown in the detail panel

    // ── Modal state ───────────────────────────────────────────────────────
    showConfirmModal = false;

    // ── Filter state ──────────────────────────────────────────────────────
    // gfaRange stores the human-readable label; resolved to min/max in buildApexFilters().
    @track filters = {
        project:            '',
        phase:              '',
        zone:               '',
        bucket:             '',
        unitClassification: '',
        bedrooms:           '',
        unitQuality:        '',
        gfaRange:           '',   // e.g. "200 – 400 sqm"
        floor:              '',
        searchKey:          ''
    };

    // ── Filter dropdown options (loaded once from Apex) ───────────────────
    @track filterOptions = {
        project:               [],
        phase:                 [],
        zone:                  [],
        bucket:                [],
        unitClassification:    [],
        bedrooms:              [],
        unitQuality:           [],
        grossFloorAreaRanges:  [],   // range labels returned by Apex
        floor:                 []
    };

    searchDebounceTimer;
    resizeHandler;

    // ── Wire: grand total (cached – no user filters) ──────────────────────
    @wire(getGrandTotalCount)
    wiredGrandTotal({ data, error }) {
        if (data != null) { this.grandTotal = data; }
        if (error)        { console.error('Grand total error:', error); }
    }

    // ─────────────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadFilterOptions();
        this.loadInventory(true);

        this.resizeHandler = () => { this.viewportWidth = window.innerWidth; };
        window.addEventListener('resize', this.resizeHandler);
    }

    disconnectedCallback() {
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Filter option loading
    // ─────────────────────────────────────────────────────────────────────
    loadFilterOptions() {
        getFilterOptions()
            .then(result => {
                const toOptions = (values) =>
                    [{ label: '-- All --', value: '' }].concat(
                        (values || []).map(v => ({ label: v, value: v }))
                    );

                this.filterOptions = {
                    project:              toOptions(result.project),
                    phase:                toOptions(result.phase),
                    zone:                 toOptions(result.zone),
                    bucket:               toOptions(result.bucket),
                    unitClassification:   toOptions(result.unitClassification),
                    bedrooms:             toOptions(result.bedrooms),
                    unitQuality:          toOptions(result.unitQuality),
                    // GFA: labels returned by Apex become the option values so
                    // resolveGfaRange() can look them up in EGYPT_MANAGE_INVENTORY_CONSTANTS.GFA_RANGES by label.
                    grossFloorAreaRanges: toOptions(result.grossFloorAreaRanges),
                    floor:                toOptions(result.floor),
                    status: EGYPT_MANAGE_INVENTORY_CONSTANTS.UNIT_STATUS
                };
            })
            .catch(error => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Main data loading  (initial / filter-change loads only)
    // Infinite-scroll loads are handled separately in handleLoadMore so
    // the datatable's own spinner can be controlled via event.target.
    // ─────────────────────────────────────────────────────────────────────
    loadInventory() {
        // Reset state for a fresh load.
        this.isLoading       = true;
        this.currentOffset   = 0;
        this.hasMoreRecords  = true;
        this.inventoryUnits  = [];
        this.selectedRowKeys = [];
        this.selectedRows    = [];

        // Re-enable infinite loading on the datatable in case it was disabled
        // after the previous result set reached its end.
        const dt = this.template.querySelector('lightning-datatable');
        if (dt) { dt.enableInfiniteLoading = true; }

        // Fetch the filtered total count for the stats bar in parallel.
        this.loadFilteredTotal();

        const apexFilters = this.buildApexFilters();

        getInventoryUnits({
            whereClauseFilters: JSON.parse(JSON.stringify(apexFilters)),
            offsetSize: this.currentOffset,   // always 0 for initial load
            pageSize:   EGYPT_MANAGE_INVENTORY_CONSTANTS.PAGE_SIZE
        })
            .then(result => {
                this.inventoryUnits = result.map(flattenUnit);
                this.currentOffset  = result.length;
                this.hasMoreRecords = result.length === EGYPT_MANAGE_INVENTORY_CONSTANTS.PAGE_SIZE;
            })
            .catch(error => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** Fetches the total count matching current filters (for the stats bar). */
    loadFilteredTotal() {
        const apexFilters = this.buildApexFilters();
        getTotalCount({ filters: apexFilters })
            .then(count => { this.filteredTotal = count; })
            .catch(error => { console.error('Filtered total error:', error); });
    }

    /**
     * Builds the InventoryFilters object for Apex from the current JS filter state.
     *
     * IMPORTANT: Do NOT convert blank strings to null here.
     * When LWC passes a JS object as an Apex inner-class parameter, the Apex
     * deserialiser only sets properties that are present and non-null in the JSON.
     * Sending null causes those fields to silently remain null on the Apex side,
     * which makes String.isNotBlank() always return false → filters are ignored.
     * Sending an empty string '' works correctly because String.isNotBlank('')
     * returns false, so Apex skips the condition as intended.
     *
     * gfaMin / gfaMax are Decimal fields — null IS correct for "no bound" because
     * Apex checks `filters.gfaMin != null` rather than isNotBlank.
     */
    buildApexFilters() {
        const { min: gfaMin, max: gfaMax } = resolveGfaRange(this.filters.gfaRange);
        return {
            project:            this.filters.project            || '',
            phase:              this.filters.phase              || '',
            zone:               this.filters.zone               || '',
            bucket:             this.filters.bucket             || '',
            unitClassification: this.filters.unitClassification || '',
            bedrooms:           this.filters.bedrooms           || '',
            unitQuality:        this.filters.unitQuality        || '',
            gfaMin:             gfaMin,   // null = no lower bound (Decimal, not String)
            gfaMax:             gfaMax,   // null = no upper bound (Decimal, not String)
            floor:              this.filters.floor              || '',
            status:             this.filters.status             || '',
            searchKey:          this.filters.searchKey          || ''
        };
    }

    // ─────────────────────────────────────────────────────────────────────
    // Infinite loading
    // ─────────────────────────────────────────────────────────────────────
    handleLoadMore(event) {
        // Always turn off the datatable's own built-in spinner when we're done
        // (or when there's nothing more to load). We must capture the reference
        // here because by the time the Promise resolves, event.target may be stale.
        const datatableEl = event && event.target ? event.target : null;

        if (!this.hasMoreRecords || this.isLoadingMore || this.isLoading) {
            // Nothing more to load — make sure the datatable spinner is off.
            if (datatableEl) { datatableEl.isLoading = false; }
            return;
        }

        // Turn the datatable's own spinner on while we fetch.
        if (datatableEl) { datatableEl.isLoading = true; }

        this.isLoadingMore = true;
        const apexFilters  = this.buildApexFilters();

        getInventoryUnits({
            whereClauseFilters: JSON.parse(JSON.stringify(apexFilters)),
            offsetSize: this.currentOffset,
            pageSize:   EGYPT_MANAGE_INVENTORY_CONSTANTS.PAGE_SIZE
        })
            .then(result => {
                const flat          = result.map(flattenUnit);
                this.inventoryUnits = [...this.inventoryUnits, ...flat];
                this.currentOffset += result.length;
                this.hasMoreRecords = result.length === EGYPT_MANAGE_INVENTORY_CONSTANTS.PAGE_SIZE;
            })
            .catch(error => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoadingMore = false;
                // Always turn the datatable spinner off here, regardless of outcome.
                if (datatableEl) { datatableEl.isLoading = false; }
                // If we've now loaded everything, disable future loadmore events.
                if (!this.hasMoreRecords && datatableEl) {
                    datatableEl.enableInfiniteLoading = false;
                }
            });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Filter & search handlers
    // ─────────────────────────────────────────────────────────────────────
    handleFilterChange(event) {
        const filterName = event.target.dataset.filter;
        this.filters = { ...this.filters, [filterName]: event.detail.value };
        this.loadInventory(true);
    }

    handleSearchChange(event) {
        const searchValue = event.target.value;
        clearTimeout(this.searchDebounceTimer);
        this.searchDebounceTimer = setTimeout(() => {
            this.filters = { ...this.filters, searchKey: searchValue };
            this.loadInventory(true);
        }, EGYPT_MANAGE_INVENTORY_CONSTANTS.SEARCH_DELAY);
    }

    handleClearFilters() {
        this.filters = {
            project:            '',
            phase:              '',
            zone:               '',
            bucket:             '',
            unitClassification: '',
            bedrooms:           '',
            unitQuality:        '',
            gfaRange:           '',
            floor:              '',
            status:             '',
            searchKey:          ''
        };
        const searchInput = this.template.querySelector('[data-id="search-input"]');
        if (searchInput) { searchInput.value = ''; }
        this.loadInventory(true);
    }

    handleRefresh() {
        this.loadInventory(true);
    }

    handleBlockChanges(event) {
        this[event.target.name] = event.target.value;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Row selection
    // ─────────────────────────────────────────────────────────────────────
    handleRowSelection(event) {
        this.selectedRows    = event.detail.selectedRows;
        this.selectedRowKeys = this.selectedRows.map(r => r.Id);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Mobile: column mode toggle & row-detail panel
    // ─────────────────────────────────────────────────────────────────────
    handleColumnModeChange(event) {
        this.mobileColumnMode = event.currentTarget.dataset.mode;
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'view_details') {
            this.detailRecord = event.detail.row;
        }
    }

    handleCloseDetail() {
        this.detailRecord = null;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Bulk update to CCMD
    // ─────────────────────────────────────────────────────────────────────
    handleUpdateStatusClick() {
        if (this.selectedRowKeys.length === 0) {
            this.showToast('No Records Selected', 'Please select at least one unit to update.', 'warning');
            return;
        }

        // Client-side pre-check: if every selected unit is already CCMD, surface
        // an informative error immediately without hitting Apex unnecessarily.
        const hasAvailable = this.selectedRows.some(r => r.Status__c === 'Available');
        if (!hasAvailable) {
            this.showToast(
                'No Update Needed',
                'All selected units already have CCMD status. Please select at least one Available unit.',
                'error'
            );
            return;
        }

        this.showConfirmModal = true;
    }

    handleCancelConfirm() {
        this.showConfirmModal = false;
    }

    handleConfirmUpdate() {
        if (!this.blockComments) {
            this.showToast('Error', `Block Comment cannot be empty.`, 'error');
            return;
        }

        this.showConfirmModal = false;
        this.isLoading = true;

        // Only pass the IDs of Available units; Apex also guards server-side.
        const availableIds = this.selectedRows
            .filter(r => r.Status__c === 'Available')
            .map(r => r.Id);

        updateUnitsStatus({ recordIds: availableIds, blockComments: this.blockComments })
            .then(updatedCount => {
                const skipped = this.selectedRowKeys.length - availableIds.length;
                let msg = `${updatedCount} unit(s) updated to CCMD.`;
                if (skipped > 0) {
                    msg += ` ${skipped} unit(s) were already CCMD and skipped.`;
                }
                this.showToast('Success', msg, 'success');
                this.selectedRowKeys = [];
                this.selectedRows    = [];

                this.blockComments = '';
                // Clear visual selection on the datatable.
                const dt = this.template.querySelector('lightning-datatable');
                if (dt) { dt.selectedRows = []; }

                this.handleClearFilters();
                this.loadInventory();
            })
            .catch(error => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) { return error.body.message; }
        if (error && error.message)                    { return error.message; }
        return 'An unknown error occurred.';
    }

    // ─────────────────────────────────────────────────────────────────────
    // Template getters
    // ─────────────────────────────────────────────────────────────────────
    get selectedCount()      { return this.selectedRowKeys.length; }
    get hasSelection()       { return this.selectedRowKeys.length > 0; }
    get showNoRecords()      { return !this.isLoading && this.inventoryUnits.length === 0; }
    get hasRecords()         { return this.inventoryUnits.length > 0; }
    get loadedCount()        { return this.inventoryUnits.length; }

    /**
     * Disables the "Update Status to CCMD" button when no rows are selected
     * OR when a load / update is in progress.
     */
    get isUpdateDisabled() {
        return this.selectedRowKeys.length === 0 || this.isLoading;
    }

    /**
     * Returns the IDs of all CCMD rows currently loaded.
     * Passed to lightning-datatable's `disabled-rows` attribute so CCMD
     * row checkboxes cannot be checked.
     */
    get ccmdRowIds() {
        return this.inventoryUnits
            .filter(u => u.Status__c === 'CCMD')
            .map(u => u.Id);
    }

    get selectedCountLabel() {
        return this.selectedCount > 0
            ? `${this.selectedCount} unit(s) selected`
            : 'No units selected';
    }

    get isMobile()     { return this.viewportWidth <= EGYPT_MANAGE_INVENTORY_CONSTANTS.MOBILE_BREAKPOINT; }
    get isCompactMode(){ return this.isMobile && this.mobileColumnMode === 'compact'; }

    get columns() {
        return this.isCompactMode ? EGYPT_MANAGE_INVENTORY_CONSTANTS.COMPACT_COLUMNS : EGYPT_MANAGE_INVENTORY_CONSTANTS.FULL_COLUMNS;
    }

    get compactButtonVariant() { return this.mobileColumnMode === 'compact' ? 'brand' : 'neutral'; }
    get scrollButtonVariant()  { return this.mobileColumnMode === 'scroll'  ? 'brand' : 'neutral'; }

    get detailFields() {
        if (!this.detailRecord) { return []; }
        return EGYPT_MANAGE_INVENTORY_CONSTANTS.DETAIL_FIELDS.map(f => ({
            key:   f.fieldName,
            label: f.label,
            value: this.detailRecord[f.fieldName] || '—'
        }));
    }

    get confirmMessage() {
        const available = this.selectedRows.filter(r => r.Status__c === 'Available').length;
        const ccmd      = this.selectedCount - available;
        let msg = `Update ${available} Available unit(s) to CCMD status?`;
        if (ccmd > 0) {
            msg += ` (${ccmd} already-CCMD unit(s) in your selection will be skipped.)`;
        }
        return msg;
    }

    /** True when all loaded records are available and no more pages. */
    get allRecordsLoaded() { return !this.hasMoreRecords; }
}