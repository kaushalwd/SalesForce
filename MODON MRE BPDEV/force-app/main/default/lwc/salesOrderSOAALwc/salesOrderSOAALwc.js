import { LightningElement, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';

import getInit from '@salesforce/apex/SalesOrderSOAAController.getInit';
import updateRows from '@salesforce/apex/SalesOrderSOAAController.updateRows';
import createRow from '@salesforce/apex/SalesOrderSOAAController.createRow';
import deleteRow from '@salesforce/apex/SalesOrderSOAAController.deleteRow';
import updateRow from '@salesforce/apex/SalesOrderSOAAController.updateRow';

export default class SalesOrderSOAALwc extends LightningElement {
    @track rows = [];
    allRows = [];
    excludedUserIds = [];
    @track draftValues = [];
    @track isLoading = false;
    @track errorMessage = '';

    @track isAddOpen = false;
    @track addError = '';
    @track add_salesAssociateId = null;
    @track add_salesOpsId = null;
    @track add_expiryDate = null;
    @track add_isActive = true;

    @track isEditOpen = false;
    @track editError = '';
    @track edit_rowId = null;
    @track edit_salesAssociateName = '';
    @track edit_salesOpsId = null;
    @track edit_expiryDate = null;
    @track edit_isActive = true;

    @track isDeleteOpen = false;
    @track deleteError = '';
    @track delete_rowId = null;

    @track sortedBy = 'salesAssociateName';
    @track sortedDirection = 'asc';

    @track searchText = '';

    currentUserId = USER_ID;

    access = {
        add: { all: true, emails: new Set() },
        inlineExpiry: { all: true, self: true, emails: new Set() },
        inlineActive: { all: true, self: true, emails: new Set() },
        salesOpsEdit: { all: true, self: true, emails: new Set() },
        del: { all: true, self: true, emails: new Set() }
    };

    columns = [
        { label: 'Sales User', fieldName: 'salesAssociateName', type: 'text', sortable: true },
        { label: 'Sales Operations User', fieldName: 'salesOpsName', type: 'text', sortable: true },
        /* { label: 'Expiry Date', fieldName: 'expiryDate', type: 'date', editable: true, sortable: true }, */
        { label: 'Active', fieldName: 'isActive', type: 'boolean', sortable: true },
/*         { label: 'Pending Sales Orders', fieldName: 'pendingSalesOrders', type: 'number', sortable: true, cellAttributes: { alignment: 'left' } },
 */        {
            type: 'button-icon',
            initialWidth: 44,
            typeAttributes: {
                iconName: 'utility:edit',
                title: 'Edit Assignment',
                variant: 'bare',
                alternativeText: 'Edit',
                disabled: { fieldName: 'editDisabled' },
                name: 'edit'
            }
        },
        {
            type: 'button-icon',
            initialWidth: 44,
            typeAttributes: {
                iconName: 'utility:delete',
                title: 'Delete',
                variant: 'bare',
                alternativeText: 'Delete',
                disabled: { fieldName: 'deleteDisabled' },
                name: 'delete'
            }
        }
    ];


    connectedCallback() {
        this.load();
    }

    log(...args) {
    }

    get isAddDisabled() {
        return !this.canAdd();
    }

    async load(cacheBust = false) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const cacheKey = cacheBust ? String(Date.now()) : '0';
            const init = await getInit({ cacheKey });

            this.applyAccessFromInit(init);

            this.excludedUserIds = init?.excludedUserIds || []; // NEW

            this.allRows = (init?.rows || []).map(r => this.decorateRow(r));
            this.applySearchAndSort();
        } catch (e) {
            console.error('[SOAA] load error', e);
            this.errorMessage = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    get userFilter() {
        const criteria = [
            { fieldPath: 'IsActive', operator: 'eq', value: true }
        ];

        if (this.excludedUserIds?.length) {
            criteria.push({
                fieldPath: 'Id',
                operator: 'nin',
                value: this.excludedUserIds
            });
        }

        return { criteria };
    }

    applyAccessFromInit(init) {
        const perms = init?.perms;
        const emailToUserId = init?.emailToUserId || {};

        const safeTokens = (v) => Array.isArray(v) ? v : [];
        const tokensToEmailUserIds = (tokens) => {
            const out = new Set();
            for (const t of safeTokens(tokens)) {
                if (typeof t === 'string' && t.includes('@') && emailToUserId[t]) out.add(emailToUserId[t]);
            }
            return out;
        };

        const parseRule = (tokens, allowSelfDefault = true) => {
            const t = safeTokens(tokens);
            const all = t.includes('All');
            const self = allowSelfDefault ? t.includes('Self') : false;
            const emails = tokensToEmailUserIds(t);
            return { all, self, emails };
        };

        if (!perms) {
            this.access = {
                add: { all: true, emails: new Set() },
                inlineExpiry: { all: true, self: true, emails: new Set() },
                inlineActive: { all: true, self: true, emails: new Set() },
                salesOpsEdit: { all: true, self: true, emails: new Set() },
                del: { all: true, self: true, emails: new Set() }
            };
            return;
        }

        const addTokens = perms?.button?.addSalesUser;
        const expTokens = perms?.inline?.expiryDate;
        const actTokens = perms?.inline?.isActive;
        const editTokens = perms?.salesOpsUser?.edit;
        const delTokens = perms?.delete?.row;

        const add = parseRule(addTokens, false);
        const inlineExpiry = parseRule(expTokens, true);
        const inlineActive = parseRule(actTokens, true);
        const salesOpsEdit = parseRule(editTokens, true);
        const del = parseRule(delTokens, true);

        const anyBlank = (addTokens == null && expTokens == null && actTokens == null && editTokens == null && delTokens == null);
        if (anyBlank) {
            this.access = {
                add: { all: true, emails: new Set() },
                inlineExpiry: { all: true, self: true, emails: new Set() },
                inlineActive: { all: true, self: true, emails: new Set() },
                salesOpsEdit: { all: true, self: true, emails: new Set() },
                del: { all: true, self: true, emails: new Set() }
            };
            return;
        }

        this.access = { add, inlineExpiry, inlineActive, salesOpsEdit, del };
        this.log('access computed', {
            add: { all: add.all, emails: [...add.emails] },
            inlineExpiry: { all: inlineExpiry.all, self: inlineExpiry.self, emails: [...inlineExpiry.emails] },
            inlineActive: { all: inlineActive.all, self: inlineActive.self, emails: [...inlineActive.emails] },
            salesOpsEdit: { all: salesOpsEdit.all, self: salesOpsEdit.self, emails: [...salesOpsEdit.emails] },
            del: { all: del.all, self: del.self, emails: [...del.emails] }
        });
    }

    decorateRow(r) {
        const canEditSalesOps = this.canSalesOpsEdit(r);
        const canDelete = this.canDelete(r);
        return {
            ...r,
            editDisabled: !canEditSalesOps,
            deleteDisabled: !canDelete
        };
    }

    onSearchChange(e) {
        this.searchText = e.detail.value || '';
        this.applySearchAndSort();
    }

    applySearchAndSort() {
        const q = (this.searchText || '').trim().toLowerCase();
        let data = [...this.allRows];

        if (q) {
            data = data.filter(r => {
                const a = (r.salesAssociateName || '').toLowerCase();
                const o = (r.salesOpsName || '').toLowerCase();
                return a.includes(q) || o.includes(q);
            });
        }

        this.rows = data;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
        this.sortData(sortedBy, sortDirection);
    }

    sortData(field, direction) {
        const isAsc = direction === 'asc';
        const data = [...this.rows];

        data.sort((a, b) => {
            let v1 = a[field];
            let v2 = b[field];
            v1 = (v1 === null || v1 === undefined) ? '' : v1;
            v2 = (v2 === null || v2 === undefined) ? '' : v2;

            if (typeof v1 === 'string') v1 = v1.toLowerCase();
            if (typeof v2 === 'string') v2 = v2.toLowerCase();

            if (v1 > v2) return isAsc ? 1 : -1;
            if (v1 < v2) return isAsc ? -1 : 1;
            return 0;
        });

        this.rows = data;
    }

    canAdd() {
        const a = this.access.add;
        if (a.all) return true;
        if (a.emails?.has(this.currentUserId)) return true;
        return false;
    }

    isSelfRow(row) {
        return row?.salesAssociateId === this.currentUserId || row?.salesOpsId === this.currentUserId;
    }

    canInlineExpiry(row) {
        const a = this.access.inlineExpiry;
        if (a.all) return true;
        if (a.emails?.has(this.currentUserId)) return true;
        if (a.self && this.isSelfRow(row)) return true;
        return false;
    }

    canInlineActive(row) {
        const a = this.access.inlineActive;
        if (a.all) return true;
        if (a.emails?.has(this.currentUserId)) return true;
        if (a.self && this.isSelfRow(row)) return true;
        return false;
    }

    canSalesOpsEdit(row) {
        const a = this.access.salesOpsEdit;
        if (a.all) return true;
        if (a.emails?.has(this.currentUserId)) return true;
        if (a.self && this.isSelfRow(row)) return true;
        return false;
    }

    canDelete(row) {
        const a = this.access.del;
        if (a.all) return true;
        if (a.emails?.has(this.currentUserId)) return true;
        if (a.self && this.isSelfRow(row)) return true;
        return false;
    }

    getPickerValue(dataId) {
        const el = this.template.querySelector(`lightning-record-picker[data-id="${dataId}"]`);
        this.log('getPickerValue', dataId, 'found=', !!el, 'value=', el?.value);
        return el?.value || null;
    }

    openAddModal() {
        this.isAddOpen = true;
        this.addError = '';
        this.add_salesAssociateId = null;
        this.add_salesOpsId = null;
        this.add_expiryDate = null;
        this.add_isActive = true;
        this.log('openAddModal');
    }

    closeAddModal() {
        this.isAddOpen = false;
    }

    onSalesAssociatePick(event) {
        
        this.add_salesAssociateId = event?.detail?.recordId || event?.detail?.value || event?.detail?.id || null;
        
    }

    onSalesOpsPick(event) {
        
        this.add_salesOpsId = event?.detail?.recordId || event?.detail?.value || event?.detail?.id || null;
        
    }

    onAddExpiry(event) {
        this.add_expiryDate = event.detail.value;
    }

    onAddActive(event) {
        this.add_isActive = event.detail.checked;
    }

    async submitAdd() {
        this.addError = '';

        if (!this.canAdd()) {
            this.addError = 'You do not have access to add Sales Users.';
            return;
        }

        const salesUserId = this.getPickerValue('salesUserPicker') || this.add_salesAssociateId;
        const salesOpsId = this.getPickerValue('salesOpsPicker') || this.add_salesOpsId;

        

        if (!salesUserId) {
            this.addError = 'Sales User is required.';
            return;
        }
        if (!salesOpsId) {
            this.addError = 'Sales Operations User is required.';
            return;
        }

        const existsActiveOnly = this.allRows.some(r => r.salesAssociateId === salesUserId && r.salesAssociateIsActive === true);
        if (existsActiveOnly) {
            this.addError = 'Duplicate Sales User: this Sales Associate already exists in the matrix.';
            return;
        }

        this.isLoading = true;
        try {
            

            await createRow({
                salesAssociateId: salesUserId,
                salesOpsId: salesOpsId,
                isActive: this.add_isActive,
                expiryDate: this.add_expiryDate || null
            });

            this.isAddOpen = false;
            await this.load(true);
        } catch (e) {
            
            console.error('[SOAA] createRow error=', e);
            this.addError = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave(event) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const drafts = event.detail.draftValues || [];
            this.log('handleSave drafts', JSON.stringify(drafts));

            const blocked = [];
            const allowedPayload = [];

            for (const d of drafts) {
                const row = this.allRows.find(r => r.id === d.id);
                if (!row) continue;

                const changingExpiry = Object.prototype.hasOwnProperty.call(d, 'expiryDate');
                const changingActive = Object.prototype.hasOwnProperty.call(d, 'isActive');

                let ok = true;
                if (changingExpiry && !this.canInlineExpiry(row)) ok = false;
                if (changingActive && !this.canInlineActive(row)) ok = false;

                if (!ok) {
                    blocked.push(row.salesAssociateName || row.id);
                    continue;
                }

                allowedPayload.push({
                    id: d.id,
                    salesOpsId: null,
                    isActive: changingActive ? d.isActive : row.isActive,
                    expiryDate: changingExpiry ? d.expiryDate : row.expiryDate
                });
            }

            if (blocked.length) {
                this.errorMessage = `Inline edit blocked for: ${blocked.join(', ')}`;
            }

            if (allowedPayload.length) {
                await updateRows({ reqs: allowedPayload });
            }

            this.draftValues = [];
            await this.load();
        } catch (e) {
            
            console.error('[SOAA] handleSave error', e);
            this.errorMessage = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    /* renderedCallback() {
        const dt = this.template.querySelector('lightning-datatable');
        if (dt && !dt._soaaBound) {
            dt._soaaBound = true;
            dt.addEventListener('rowaction', this.handleRowAction.bind(this));
            this.log('rowaction bound');
        }
    } */

    handleRowAction(event) {
        const action = event.detail.action?.name;
        const row = event.detail.row;
        this.log('rowaction', action, row?.id);

        if (action === 'edit') {
            if (!this.canSalesOpsEdit(row)) {
                this.errorMessage = 'You do not have access to edit Sales Operations User for this row.';
                return;
            }
            this.openEditModal(row);
        }

        if (action === 'delete') {
            if (!this.canDelete(row)) {
                this.errorMessage = 'You do not have access to delete this row.';
                return;
            }
            this.openDeleteModal(row);
        }
    }

    openEditModal(row) {
        this.isEditOpen = true;
        this.editError = '';
        this.edit_rowId = row.id;
        this.edit_salesAssociateName = row.salesAssociateName || '';
        this.edit_salesOpsId = row.salesOpsId || null;
        this.edit_expiryDate = row.expiryDate || null;
        this.edit_isActive = !!row.isActive;
        this.log('openEditModal', this.edit_rowId);
    }

    closeEditModal() {
        this.isEditOpen = false;
        this.editError = '';
        this.edit_rowId = null;
    }

    onEditSalesOpsPick(event) {
        
        this.edit_salesOpsId = event?.detail?.recordId || event?.detail?.value || event?.detail?.id || null;
        
    }

    onEditExpiry(event) {
        this.edit_expiryDate = event.detail.value;
    }

    onEditActive(event) {
        this.edit_isActive = event.detail.checked;
    }

    async submitEdit() {
    this.editError = '';

    const row = this.allRows.find(r => r.id === this.edit_rowId);
    if (!row) {
        this.editError = 'Row not found.';
        return;
    }

    if (!this.canSalesOpsEdit(row)) {
        this.editError = 'You do not have access to edit Sales Operations User for this row.';
        return;
    }

    const salesOpsId = this.getPickerValue('editSalesOpsPicker') || this.edit_salesOpsId;
    if (!salesOpsId) {
        this.editError = 'Sales Operations User is required.';
        return;
    }

    this.isLoading = true;
    try {
        const updated = await updateRow({
            rowId: this.edit_rowId,
            salesOpsId,
            isActive: this.edit_isActive,
            expiryDate: this.edit_expiryDate || null
        });

        this.allRows = this.allRows.map(r => r.id === updated.id ? this.decorateRow(updated) : r);
        this.applySearchAndSort();

        this.isEditOpen = false;
    } catch (e) {
        console.error('[SOAA] submitEdit error', e);
        this.editError = this.normalizeError(e);
    } finally {
        this.isLoading = false;
    }
}

    openDeleteModal(row) {
        this.isDeleteOpen = true;
        this.deleteError = '';
        this.delete_rowId = row.id;
        this.log('openDeleteModal', this.delete_rowId);
    }

    closeDeleteModal() {
        this.isDeleteOpen = false;
        this.deleteError = '';
        this.delete_rowId = null;
    }

    async confirmDelete() {
        this.deleteError = '';
        const row = this.allRows.find(r => r.id === this.delete_rowId);
        if (!row) {
            this.deleteError = 'Row not found.';
            return;
        }

        if (!this.canDelete(row)) {
            this.deleteError = 'You do not have access to delete this row.';
            return;
        }

        this.isLoading = true;
        try {
            this.log('confirmDelete deleteRow', this.delete_rowId);
            await deleteRow({ rowId: this.delete_rowId });
            this.isDeleteOpen = false;
            await this.load();
        } catch (e) {
            
            console.error('[SOAA] delete error', e);
            this.deleteError = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    normalizeError(e) {
        if (Array.isArray(e?.body)) return e.body.map(x => x.message).join(', ');
        return e?.body?.message || e?.message || 'Unknown error';
    }
}