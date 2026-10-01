import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin }                     from 'lightning/navigation';
import { ShowToastEvent }                      from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue }            from 'lightning/uiRecordApi';

import MERGE_STATUS from '@salesforce/schema/Account.Merge_Status__c';
import MERGE_ERROR  from '@salesforce/schema/Account.Merge_Error__c';
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';

import getAccountDuplicates   from '@salesforce/apex/AccountMergeController.getAccountDuplicates';
import getComparisonFields    from '@salesforce/apex/AccountMergeController.getComparisonFields';
import saveFieldOverrides     from '@salesforce/apex/AccountMergeController.saveFieldOverrides';
import submitMergeRequest     from '@salesforce/apex/AccountMergeController.submitMergeRequest';
import clearMergeError        from '@salesforce/apex/AccountMergeController.clearMergeError';
import getPendingMergeDetails from '@salesforce/apex/AccountMergeController.getPendingMergeDetails';

import canSubmit from '@salesforce/customPermission/Can_Submit_Account_Merge';

// Person Account labels
const FILTER_DEFS_PERSON = [
    { key: 'ALL',         label: 'All Duplicates', icon: '⊞', field: null },
    { key: 'PASSPORT',    label: 'Passport',        icon: '🛂', field: 'matchPassport' },
    { key: 'MOBILE',      label: 'Mobile',          icon: '📱', field: 'matchMobile' },
    { key: 'EMIRATES_ID', label: 'Emirates ID',     icon: '🪪', field: 'matchEid' },
    { key: 'EMAIL',       label: 'Email',           icon: '✉',  field: 'matchEmail' },
];

// Organisation Account labels — UAE business registration fields
const FILTER_DEFS_ORG = [
    { key: 'ALL',         label: 'All Duplicates',  icon: '⊞', field: null },
    { key: 'PASSPORT',    label: 'Unified Number',  icon: '🏢', field: 'matchPassport' },
    { key: 'MOBILE',      label: 'VAT Number',      icon: '🧾', field: 'matchMobile' },
    { key: 'EMIRATES_ID', label: 'Emirates ID',     icon: '🪪', field: 'matchEid' },
    { key: 'EMAIL',       label: 'Trade Licence',   icon: '📋', field: 'matchEmail' },
];

// Resolved at runtime based on source account type
const FILTER_DEFS = FILTER_DEFS_PERSON; // default — overridden by filterOptions getter

export default class AccountMergeFinder extends NavigationMixin(LightningElement) {

    @api recordId;

    get canSubmit() { return canSubmit; }

    // ── Core state ─────────────────────────────────────────────────────────
    @track _data              = null;
    @track _activeFilter      = 'ALL';
    @track _masterId          = null;
    @track _submittedMasterId = null;
    @track isLoading          = true;
    @track loadError          = '';
    @track validationError    = '';
    @track isSubmitting       = false;
    @track isClearingError    = false;
    @track isSavingOverrides  = false;

    // table | compare | submitted | recalled | mergeError | merged
    @track _phase = 'table';

    // ── Compare screen ─────────────────────────────────────────────────────
    @track _comparisonData = null;
    @track _compLoading    = false;
    @track _compError      = '';
    @track _overrides      = {};
    @track _mergeComment   = '';

    // ── Submitted screen ───────────────────────────────────────────────────
    // Snapshot of master + victims. Survives the dup query filtering them out.
    @track _submittedRows    = [];

    // Only true when user submits in THIS session.
    // Prevents wiredMasterAccount reacting to stale LDS cache on page load.
    @track _hasJustSubmitted = false;

    // ── Error ──────────────────────────────────────────────────────────────
    @track _mergeErrorDetail = '';

    // ─────────────────────────────────────────────────────────────────────
    // Wire 1 — live post-submit monitoring.
    // Only active after _hasJustSubmitted = true.
    // ─────────────────────────────────────────────────────────────────────
    @wire(getRecord, {
        recordId: '$_submittedMasterId',
        fields:   [MERGE_STATUS, MERGE_ERROR, ACCOUNT_NAME]
    })
    wiredMasterAccount(result) {
        try {
            const data = result && result.data;
            if (!data || !this._hasJustSubmitted) return;
            const status = getFieldValue(data, MERGE_STATUS) || null;
            const error  = getFieldValue(data, MERGE_ERROR)  || null;
            if (status === 'Error' && error) {
                this._mergeErrorDetail = error;
                this._phase            = 'mergeError';
            } else if (status === 'Merged' && this._phase === 'submitted') {
                // Show success toast then reload table so user sees remaining matches
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Merge Complete',
                    message: 'All records have been moved to the master account. Checking for remaining duplicates…',
                    variant: 'success',
                    mode:    'sticky',
                }));
                this.resetForm();
            }
        } catch (e) {
            console.warn('wiredMasterAccount skipped:', e && e.message);
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Wire 2 — page-load / refresh detection.
    // Sole authority for initial phase on page open or refresh.
    // Full try/catch prevents partially-provisioned wire data crashing LWC.
    // ─────────────────────────────────────────────────────────────────────
    @wire(getRecord, {
        recordId: '$recordId',
        fields:   [MERGE_STATUS, MERGE_ERROR, ACCOUNT_NAME]
    })
    wiredSourceAccount(result) {
        try {
            const data = result && result.data;
            if (!data) return;
            if ((this._phase || 'table') !== 'table') return;

            const status     = getFieldValue(data, MERGE_STATUS) || null;
            const mergeError = getFieldValue(data, MERGE_ERROR)  || null;
            const noRows     = !Array.isArray(this._submittedRows)
                               || this._submittedRows.length === 0;

            if (status === 'Pending' || status === 'Approved') {
                this._submittedMasterId = this.recordId;
                this._phase             = 'submitted';
                if (noRows) {
                    getPendingMergeDetails({ masterAccountId: this.recordId })
                        .then(rows => { this._submittedRows = Array.isArray(rows) ? rows : []; })
                        .catch(()  => { this._submittedRows = []; });
                }
            } else if (status === 'Error' && mergeError) {
                this._mergeErrorDetail  = mergeError;
                this._submittedMasterId = this.recordId;
                this._phase             = 'mergeError';
            } else if (status === 'Merged') {
                // Account was already merged — show toast and reload table
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Merge Already Complete',
                    message: 'This account was previously merged. Loading duplicate check…',
                    variant: 'success',
                }));
                this.resetForm();
            }
        } catch (e) {
            console.warn('wiredSourceAccount skipped:', e && e.message);
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────
    connectedCallback() {
        if (canSubmit) this._loadDuplicates();
    }

    _loadDuplicates() {
        this.isLoading = true;
        this.loadError = '';
        getAccountDuplicates({ accountId: this.recordId })
            .then(r => {
                this._data     = r;
                this.isLoading = false;
                if (r.suggestedMasterId) this._masterId = r.suggestedMasterId;
            })
            .catch(e => {
                this.loadError = e?.body?.message || 'Unable to load duplicates.';
                this.isLoading = false;
            });
    }

    // ── Phase flags ─────────────────────────────────────────────────────────
    get showTable()    { return this._phase === 'table'; }
    get showCompare()  { return this._phase === 'compare'; }
    get isSubmitted()  { return this._phase === 'submitted'; }
    get isRecalled()   { return this._phase === 'recalled'; }
    get isMergeError() { return this._phase === 'mergeError'; }
    get hasError()     { return !!this.loadError; }

    get noDuplicates() {
        return this._phase === 'table'
            && this._data
            && Array.isArray(this._data.accounts)
            && this._data.accounts.length === 0;
    }

    // ── Master rule ─────────────────────────────────────────────────────────
    get isPortalRule() { return this._data?.masterSelectionRule === 'PORTAL'; }

    get masterRuleBanner() {
        const rule = this._data?.masterSelectionRule;
        if (rule === 'PORTAL') return { show: true, msg: 'A portal account is present — it is automatically set as the Master.' };
        if (rule === 'ERP')    return { show: true, msg: 'One or more accounts have an ERP ID — only ERP accounts can be Master.' };
        return { show: true, msg: 'No accounts have an ERP ID — any account can be selected as Master.' };
    }

    get masterRuleWarning() {
        const rule = this._data?.masterSelectionRule;
        if (rule === 'PORTAL') return 'Portal account is automatically the Master and must always have an ERP ID.';
        if (rule === 'ERP')    return 'Only accounts with a valid ERP ID can be selected as the Master Account.';
        return 'No ERP ID found — select any account as Master.';
    }

    // ── Filter cards ────────────────────────────────────────────────────────
    get filterOptions() {
        const c         = this._data?.counts || {};
        const totalRows = (this._allRows || []).length;
        const isOrg     = this._data?.sourceAccount && !this._data.sourceAccount.isPersonAccount;
        const defs      = isOrg ? FILTER_DEFS_ORG : FILTER_DEFS_PERSON;
        return defs.map(f => {
            let count, unit, unitPlural;
            if (f.key === 'ALL') {
                count = totalRows; unit = 'account'; unitPlural = 'accounts';
            } else {
                count      = f.key === 'PASSPORT'    ? (c.passport || 0)
                           : f.key === 'MOBILE'      ? (c.mobile   || 0)
                           : f.key === 'EMIRATES_ID' ? (c.eid      || 0)
                           :                           (c.email    || 0);
                unit = 'duplicate'; unitPlural = 'duplicates';
            }
            const isActive   = this._activeFilter === f.key;
            const countLabel = count === 1 ? unit : unitPlural;
            return {
                ...f, count, countLabel,
                plural:    count !== 1 ? 's' : '',
                isActive,
                cardClass: `filter-card${isActive ? ' filter-card--active' : ''}`,
            };
        });
    }

    get showFilterBanner()  { return this._activeFilter !== 'ALL'; }
    get activeFilterLabel() {
        const isOrg = this._data?.sourceAccount && !this._data.sourceAccount.isPersonAccount;
        const defs  = isOrg ? FILTER_DEFS_ORG : FILTER_DEFS_PERSON;
        return defs.find(f => f.key === this._activeFilter)?.label || '';
    }
    get activeFilterCount() { return (this.visibleRows || []).length; }
    get noFilterResults()   { return this._activeFilter !== 'ALL' && (this.visibleRows || []).length === 0; }

    // ── Table rows ──────────────────────────────────────────────────────────
    get _allRows() {
        if (!this._data) return [];
        return [this._data.sourceAccount, ...(this._data.accounts || [])];
    }

    get visibleRows() {
        const filter   = this._activeFilter;
        const isOrg    = this._data?.sourceAccount && !this._data.sourceAccount.isPersonAccount;
        const defs     = isOrg ? FILTER_DEFS_ORG : FILTER_DEFS_PERSON;
        const fieldKey = defs.find(f => f.key === filter)?.field;
        const isPortal = this.isPortalRule;
        const rows     = filter === 'ALL'
            ? this._allRows
            : (this._data?.accounts || []).filter(r => fieldKey && r[fieldKey]);

        return rows.map(r => ({
            ...r,
            isMasterRow:       r.id === this._masterId,
            isChildRow:        !!this._masterId && r.id !== this._masterId,
            rowClass:          this._rowClass(r),
            radioClass:        `radio-circle${r.id === this._masterId ? ' radio-circle--selected' : ''}${isPortal && r.id !== this._masterId ? ' radio-circle--locked' : ''}`,
            showNoCanBeMaster: !r.canBeMaster && !isPortal,
            showPortalLocked:  isPortal && r.id !== this._masterId,
            soPlural:          r.salesOrderCount !== 1 ? 's' : '',
            portalBadge:       r.isPortalUser,
        }));
    }

    _rowClass(r) {
        const base = 'slds-hint-parent merge-row';
        if (r.id === this._masterId) return `${base} merge-row--master`;
        if (!r.canBeMaster)          return `${base} merge-row--disabled`;
        return base;
    }

    get footerText() {
        if (!this._masterId) return 'Click an account to set it as Master';
        const m  = this._allRows.find(r => r.id === this._masterId);
        const cc = this._allRows.length - 1;
        return `${m?.name} is Master · ${cc} child account${cc !== 1 ? 's' : ''} will be merged on approval`;
    }

    get isSubmitDisabled() { return !this._masterId || this.isSubmitting; }

    // ── Compare getters ─────────────────────────────────────────────────────
    get comparisonRows() {
        return (this._comparisonData?.rows || []).map(row => ({
            ...row,
            uniqueKey:      row.fieldApiName,
            masterDisplay:  this._overrides[row.fieldApiName] !== undefined
                                ? this._overrides[row.fieldApiName]
                                : (row.masterValue || '—'),
            isOverridden:   this._overrides[row.fieldApiName] !== undefined,
            masterValClass: this._overrides[row.fieldApiName] !== undefined ? 'overridden-val' : '',
            rowHighlight:   row.hasDifference ? 'compare-row--diff' : '',
            childCols: (row.childValues || []).map((v, ci) => ({
                uniqueKey:   `${row.fieldApiName}-${ci}`,
                value:       v || '—',
                isDifferent: v !== row.masterValue,
                isEditable:  row.isEditable,
                childIndex:  ci,
                fieldName:   row.fieldApiName,
                cellClass:   v !== row.masterValue ? 'diff-cell' : '',
            })),
        }));
    }

    get compChildNames()       { return this._comparisonData?.childNames || []; }
    get compChildIds()         { return this._comparisonData?.childIds   || []; }
    get hasOverrides()         { return Object.keys(this._overrides).length > 0; }
    get compareButtonVariant() { return this.hasOverrides ? 'success' : 'brand'; }

    get compareButtonLabel() {
        if (this.isSubmitting || this.isSavingOverrides) return 'Submitting…';
        return this.hasOverrides ? 'Save Changes & Submit' : 'Submit for Approval →';
    }

    get overridesText() {
        const count = Object.keys(this._overrides).length;
        return count ? `${count} field${count !== 1 ? 's' : ''} updated from child — will be saved to master` : '';
    }

    // ── Submitted rows ──────────────────────────────────────────────────────
    get submittedRows() {
        const snapshot = Array.isArray(this._submittedRows) ? this._submittedRows : [];
        const allRows  = Array.isArray(this._allRows)       ? this._allRows       : [];
        const masterId = this._submittedMasterId || this._masterId;

        const source = snapshot.length > 0
            ? snapshot
            : allRows.map(r => ({
                id: r.id, name: r.name, accountNumber: r.accountNumber,
                isMaster: r.id === masterId,
              }));

        return source.map(r => ({
            ...r,
            isMaster:          r.isMaster !== undefined ? r.isMaster : r.id === masterId,
            submittedRowClass: (r.isMaster || r.id === masterId)
                                ? 'slds-hint-parent submitted-master-row' : 'slds-hint-parent',
        }));
    }

    get clearErrorLabel() { return this.isClearingError ? 'Clearing…' : 'Clear Error & Retry'; }

    // ── Event handlers — Table ──────────────────────────────────────────────
    handleFilterClick(event) {
        this._activeFilter = event.currentTarget.dataset.key;
        this.validationError = '';
    }

    clearFilter() {
        this._activeFilter   = 'ALL';
        this.validationError = '';
    }

    handleRowClick(event) {
        if (this.isPortalRule) {
            this.validationError = 'The portal account is automatically the Master and cannot be changed.';
            return;
        }
        const id  = event.currentTarget.dataset.id;
        const acc = this._allRows.find(r => r.id === id);
        if (!acc?.canBeMaster) {
            this.validationError = this._data?.masterSelectionRule === 'ERP'
                ? `"${acc?.name}" has no ERP ID — cannot be selected as Master.`
                : `"${acc?.name}" cannot be selected as Master.`;
            return;
        }
        this._masterId       = id;
        this.validationError = '';
    }

    handleNameClick(event) {
        event.stopPropagation();
        this[NavigationMixin.Navigate]({
            type:       'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' },
        });
    }

    // ── Next → compare ──────────────────────────────────────────────────────
    handleNext() {
        if (!this._masterId) {
            this.validationError = 'Please select a Master Account first.';
            return;
        }
        this.validationError = '';
        this._compLoading    = true;
        this._overrides      = {};
        this._mergeComment   = '';
        this._phase          = 'compare';

        const victimIds = this._allRows.filter(r => r.id !== this._masterId).map(r => r.id);
        getComparisonFields({ masterAccountId: this._masterId, victimAccountIds: victimIds })
            .then(r  => { this._comparisonData = r; this._compLoading = false; })
            .catch(e => { this._compError = e?.body?.message || 'Error loading comparison.'; this._compLoading = false; });
    }

    // ── Compare handlers ────────────────────────────────────────────────────
    handleCopyToMaster(event) {
        const field      = event.currentTarget.dataset.field;
        const childIndex = parseInt(event.currentTarget.dataset.childidx, 10);
        const row        = this._comparisonData?.rows?.find(r => r.fieldApiName === field);
        const childValue = row?.childValues?.[childIndex] || '';
        this._overrides  = { ...this._overrides, [field]: childValue };
        this._regenerateComment();
    }

    _regenerateComment() {
        const userName = this._data?.currentUserName || 'Submitter';
        const entries  = Object.keys(this._overrides).map(field => {
            const row   = this._comparisonData?.rows?.find(r => r.fieldApiName === field);
            const label = row?.fieldLabel || field;
            const val   = this._overrides[field] || '(blank)';
            return `${label} = ${val}`;
        });
        this._mergeComment = entries.length === 0
            ? ''
            : `Updated by: ${userName} | ` + entries.join(', ');
    }

    handleClearOverride(event) {
        const copy = { ...this._overrides };
        delete copy[event.currentTarget.dataset.field];
        this._overrides = copy;
        this._regenerateComment();
    }

    handleSaveAndSubmit() {
        this.isSavingOverrides = true;
        saveFieldOverrides({
            masterAccountId: this._masterId,
            fieldOverrides:  this._overrides,
            mergeComment:    this._mergeComment || '',
        })
            .then(()  => { this.isSavingOverrides = false; this._submitApproval(); })
            .catch(e  => { this.isSavingOverrides = false; this.validationError = e?.body?.message || 'Save failed.'; });
    }

    _submitApproval() {
        const victimIds = this._allRows.filter(r => r.id !== this._masterId).map(r => r.id);
        this.isSubmitting    = true;
        this.validationError = '';

        submitMergeRequest({ masterAccountId: this._masterId, victimAccountIds: victimIds })
            .then(() => {
                this._submittedMasterId = this._masterId;
                this._hasJustSubmitted  = true;
                this.isSubmitting       = false;
                this._submittedRows     = this._allRows.map(r => ({
                    id: r.id, name: r.name, accountNumber: r.accountNumber,
                    isMaster: r.id === this._masterId,
                }));
                this._phase = 'submitted';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submitted', message: 'Merge request sent to approvers.', variant: 'success',
                }));
            })
            .catch(e => { this.isSubmitting = false; this.validationError = e?.body?.message || 'Submission failed.'; });
    }

    // ── Back ────────────────────────────────────────────────────────────────
    handleBackToTable()   { this._phase = 'table';   this.validationError = ''; }
    handleBackToCompare() { this._phase = 'compare'; this.validationError = ''; }

    // ── Clear error ─────────────────────────────────────────────────────────
    handleClearMergeError() {
        this.isClearingError = true;
        clearMergeError({ masterAccountId: this._submittedMasterId || this.recordId })
            .then(() => {
                this.isClearingError   = false;
                this._mergeErrorDetail = '';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Cleared', message: 'Merge error cleared. You can resubmit when ready.', variant: 'success',
                }));
                this.resetForm();
            })
            .catch(e => { this.isClearingError = false; this.validationError = e?.body?.message || 'Failed to clear error.'; });
    }

    // ── Reset ───────────────────────────────────────────────────────────────
    resetForm() {
        this._masterId          = null;
        this._submittedMasterId = null;
        this._phase             = 'table';
        this.validationError    = '';
        this._activeFilter      = 'ALL';
        this._overrides         = {};
        this._comparisonData    = null;
        this._mergeComment      = '';
        this._mergeErrorDetail  = '';
        this._submittedRows     = [];
        this._hasJustSubmitted  = false;
        this._loadDuplicates();
    }
}