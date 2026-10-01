import { LightningElement, track } from 'lwc';
import getCommissionRows from '@salesforce/apex/CommissionPreReviewController.getCommissionRows';
import updateCommissionRows from '@salesforce/apex/CommissionPreReviewController.updateCommissionRows';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CommissionPreReviewTable extends LightningElement {
    @track rows = [];
    @track draftValues = [];


    leadSourceOptions = [];
    salesTypeOptions = [];
    saleCategoryOptions = [];
    ownerOptions = [];
    projectOptions = [{ label: 'All Projects', value: '' }];
    hasDateFilter = false;
    totalCount = 0;
    pageNumber = 1;
    pageSize = '10';
    isLoading = false;

    @track dateFilterType = '';
    @track selectedMonth = '';
    @track selectedYear = '';
    @track fromDate;
    @track toDate;
    @track selectedProject = '';
    @track unitFilter = '';

    connectedCallback() {
        this.loadData();
    }

    initializeDefaultDateFilters() {
        const today = new Date();
        this.selectedMonth = String(today.getMonth() + 1).padStart(2, '0');
        this.selectedYear = String(today.getFullYear());
    }

    get pageSizeOptions() {
        return [
            { label: '10', value: '10' },
            { label: '20', value: '20' },
            { label: '50', value: '50' }
        ];
    }

    get dateFilterTypeOptions() {
        return [
            { label: 'Month', value: 'month' },
            { label: 'Year', value: 'year' },
            { label: 'Custom', value: 'custom' }
        ];
    }

    get monthOptions() {
        return [
            { label: 'January', value: '01' },
            { label: 'February', value: '02' },
            { label: 'March', value: '03' },
            { label: 'April', value: '04' },
            { label: 'May', value: '05' },
            { label: 'June', value: '06' },
            { label: 'July', value: '07' },
            { label: 'August', value: '08' },
            { label: 'September', value: '09' },
            { label: 'October', value: '10' },
            { label: 'November', value: '11' },
            { label: 'December', value: '12' }
        ];
    }

    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const options = [];
        for (let year = currentYear - 5; year <= currentYear + 5; year++) {
            options.push({ label: String(year), value: String(year) });
        }
        return options;
    }

    get showMonthFilter() {
        return this.dateFilterType === 'month';
    }

    get showYearFilter() {
        return this.dateFilterType === 'year';
    }

    get showCustomFilter() {
        return this.dateFilterType === 'custom';
    }

    get totalPages() {
        const ps = Number(this.pageSize);
        const pages = ps > 0 ? Math.ceil(this.totalCount / ps) : 1;
        return pages > 0 ? pages : 1;
    }

    get isPrevDisabled() {
        return this.pageNumber <= 1 || this.isLoading;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages || this.isLoading;
    }

    get hasPendingChanges() {
        return (this.draftValues?.length || 0) > 0;
    }

    get isActionDisabled() {
        return this.isLoading || !this.hasPendingChanges;
    }

    get columns() {
        return [
            { label: 'Commission Line', fieldName: 'commissionLineName', type: 'text' },
            { label: 'Project Name', fieldName: 'projectName', type: 'text' },
            { label: 'Unit Name', fieldName: 'unitName', type: 'text' },

            {
                label: 'Unit Sold Date',
                fieldName: 'unitSoldDate',
                type: 'date',
                editable: true,
                typeAttributes: {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric'
                }
            },
            {
                label: 'Launch Date',
                fieldName: 'launchDate',
                type: 'date',
                editable: true,
                typeAttributes: {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric'
                }
            },

            {
                label: 'Lead Source',
                fieldName: 'leadSource',
                type: 'picklist',
                editable: true,
                typeAttributes: {
                    placeholder: 'Select',
                    options: this.leadSourceOptions,
                    value: { fieldName: 'leadSource' },
                    displayValue: { fieldName: 'leadSource' },
                    context: { fieldName: 'recordId' },
                    fieldName: 'leadSource'
                }
            },

            {
                label: 'Total Sales Value',
                fieldName: 'totalSalesValue',
                type: 'currency',
                typeAttributes: {
                    currencyCode: 'AED',
                    minimumFractionDigits: 2
                }
            },
            {
                label: 'Sales Type',
                fieldName: 'salesType',
                type: 'text'
            },

            {
                label: 'Category of Sale',
                fieldName: 'saleCategory',
                type: 'text'
            },

            /* {
                label: 'Sales Type',
                fieldName: 'salesType',
                type: 'picklist',
                editable: true,
                typeAttributes: {
                    placeholder: 'Select',
                    options: this.salesTypeOptions,
                    value: { fieldName: 'salesType' },
                    context: { fieldName: 'recordId' },
                    fieldName: 'salesType'
                }
            },

            {
                label: 'Category of Sale',
                fieldName: 'saleCategory',
                type: 'picklist',
                editable: true,
                typeAttributes: {
                    placeholder: 'Select',
                    options: this.saleCategoryOptions,
                    value: { fieldName: 'saleCategory' },
                    context: { fieldName: 'recordId' },
                    fieldName: 'saleCategory'
                }
            }, */

            {
                label: 'Commission %',
                fieldName: 'commissionPercent',
                type: 'number',
                editable: true,
                typeAttributes: {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                }
            },

            {
                label: 'Commission Amount',
                fieldName: 'commissionAmount',
                type: 'currency',
                typeAttributes: {
                    currencyCode: 'AED',
                    minimumFractionDigits: 2
                }
            },

            {
            label: 'Owner Name',
            fieldName: 'ownerId',
            type: 'ownerlookup',
            editable: true,
            typeAttributes: {
                value: { fieldName: 'ownerId' },
                displayValue: { fieldName: 'ownerName' },
                context: { fieldName: 'recordId' }
            }
        }
        ];
    }

    async loadData() {
        this.isLoading = true;
        try {
            const res = await getCommissionRows({
                pageSize: Number(this.pageSize),
                pageNumber: Number(this.pageNumber),
                dateFilterType: this.hasDateFilter ? this.dateFilterType : null,
                monthValue: this.hasDateFilter && this.showMonthFilter ? Number(this.selectedMonth) : null,
                yearValue: this.hasDateFilter && (this.showMonthFilter || this.showYearFilter) ? Number(this.selectedYear) : null,
                fromDate: this.hasDateFilter && this.showCustomFilter ? this.fromDate : null,
                toDate: this.hasDateFilter && this.showCustomFilter ? this.toDate : null,
                projectName: this.selectedProject || null,
                unitName: this.unitFilter?.trim() || null
            });

            this.totalCount = res.totalCount || 0;

            this.leadSourceOptions = (res.leadSourceOptions || []).map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            this.salesTypeOptions = (res.salesTypeOptions || []).map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            this.saleCategoryOptions = (res.saleCategoryOptions || []).map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            this.projectOptions = [
                { label: 'All Projects', value: '' },
                ...(res.projectOptions || []).map(opt => ({
                    label: opt.label,
                    value: opt.value
                }))
            ];
            this.ownerOptions = (res.ownerOptions || []).map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            this.rows = (res.rows || []).map(row => this.normalizeRow(row));

            this.draftValues = [];
            this.picklistDrafts = [];
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    normalizeRow(row) {
        return {
            ...row,
            leadSource: row.leadSource ? String(row.leadSource).trim() : '',
            salesType: row.salesType ? String(row.salesType).trim() : '',
            saleCategory: row.saleCategory ? String(row.saleCategory).trim() : '',
            ownerId: row.ownerId || '',
            ownerName: row.ownerName || '',
            commissionAmount: this.calculateCommissionAmount(row.totalSalesValue, row.commissionPercent)
        };
    }

    calculateCommissionAmount(totalSalesValue, commissionPercent) {
        const total = Number(totalSalesValue);
        const percent = Number(commissionPercent);

        if (isNaN(total) || isNaN(percent)) {
            return null;
        }

        return Number(((total * percent) / 100).toFixed(2));
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value;
        this.pageNumber = 1;
        this.loadData();
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
            this.loadData();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
            this.loadData();
        }
    }

    handleDateFilterTypeChange(event) {
        this.dateFilterType = event.detail.value;

        if (!this.dateFilterType) {
            this.selectedMonth = '';
            this.selectedYear = '';
            this.fromDate = null;
            this.toDate = null;
            this.hasDateFilter = false;
        } else if (this.dateFilterType === 'month') {
            this.initializeDefaultDateFilters();
            this.hasDateFilter = true;
        } else if (this.dateFilterType === 'year') {
            this.selectedMonth = '';
            this.selectedYear = String(new Date().getFullYear());
            this.fromDate = null;
            this.toDate = null;
            this.hasDateFilter = true;
        } else if (this.dateFilterType === 'custom') {
            this.selectedMonth = '';
            this.selectedYear = '';
            this.fromDate = null;
            this.toDate = null;
            this.hasDateFilter = true;
        }

        this.pageNumber = 1;
        this.loadData();
    }

    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
        this.hasDateFilter = true;
        this.pageNumber = 1;
        this.loadData();
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
        this.hasDateFilter = true;
        this.pageNumber = 1;
        this.loadData();
    }

    handleFromDateChange(event) {
        this.fromDate = event.detail.value;
        this.hasDateFilter = true;
        this.pageNumber = 1;
        this.loadData();
    }

    handleToDateChange(event) {
        this.toDate = event.detail.value;
        this.hasDateFilter = true;
        this.pageNumber = 1;
        this.loadData();
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;
        this.pageNumber = 1;
        this.loadData();
    }

    handleUnitChange(event) {
        this.unitFilter = event.detail.value;
        this.pageNumber = 1;
        this.loadData();
    }

    handleResetFilters() {
        this.dateFilterType = '';
        this.selectedMonth = '';
        this.selectedYear = '';
        this.selectedProject = '';
        this.unitFilter = '';
        this.fromDate = null;
        this.toDate = null;
        this.hasDateFilter = false;
        this.pageNumber = 1;
        this.loadData();
    }

    handleCellChange(event) {
        const changedDrafts = event.detail.draftValues || [];
        if (!changedDrafts.length) return;

        const enrichedDrafts = changedDrafts.map(draft => {
            const updatedDraft = { ...draft };

            if (draft.commissionPercent !== undefined) {
                const existingRow = this.rows.find(row => row.recordId === draft.recordId);
                const totalSalesValue = existingRow?.totalSalesValue;
                updatedDraft.commissionAmount = this.calculateCommissionAmount(
                    totalSalesValue,
                    draft.commissionPercent
                );
            }
            if (draft.ownerId !== undefined) {
                const selectedOwner = this.ownerOptions.find(opt => opt.value === draft.ownerId);
                updatedDraft.ownerName = selectedOwner ? selectedOwner.label : '';
            }

            return updatedDraft;
        });

        this.rows = this.rows.map(row => {
            const draft = enrichedDrafts.find(d => d.recordId === row.recordId);
            return draft ? { ...row, ...draft } : row;
        });

        this.draftValues = this.mergeDrafts(this.draftValues, enrichedDrafts);
    }

    /*handlePicklistChanged(event) {
        const { context, fieldName, value } = event.detail;
        const draft = { recordId: context, [fieldName]: value };

        this.picklistDrafts = this.mergeDrafts(this.picklistDrafts, [draft]);
        this.draftValues = this.mergeDrafts(this.draftValues, [draft]);

        Promise.resolve().then(() => {
            this.rows = this.rows.map(row => {
                if (row.recordId === context) {
                    return { ...row, [fieldName]: value };
                }
                return row;
            });
        });
    }*/

    handleTopCancel() {
        this.draftValues = [];
        this.loadData();
    }

    async handleTopSave() {
        if (!this.draftValues.length) {
            return;
        }

        this.isLoading = true;
        try {
            await updateCommissionRows({ updates: this.draftValues });

            this.draftValues = [];
            await this.loadData();

            this.toast('Success', 'Commission rows updated.', 'success');
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    mergeDrafts(baseDrafts, incomingDrafts) {
        const merged = [...(baseDrafts || []).map(item => ({ ...item }))];

        (incomingDrafts || []).forEach(extra => {
            const index = merged.findIndex(item => item.recordId === extra.recordId);
            if (index === -1) {
                merged.push({ ...extra });
            } else {
                merged[index] = { ...merged[index], ...extra };
            }
        });

        return merged;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map(item => item.message).join(', ');
        if (typeof error.body?.message === 'string') return error.body.message;
        return error.message || 'Unknown error';
    }
}