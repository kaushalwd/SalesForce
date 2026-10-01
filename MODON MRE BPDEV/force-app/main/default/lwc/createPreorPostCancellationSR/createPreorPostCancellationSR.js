/**************************************************************************************************
* Name           : CreatePreorPostCancellationSR.js
* Description    : LWC component to create Pre or Post Cancellation SR
* Created Date   : 30/04/2026
* Created By     : Chandu Battu
**************************************************************************************************/

import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';

import getStatusToRecordTypeMap  from '@salesforce/apex/ObjectFieldMetadataController.getStatusToRecordTypeMap';
import checkExistingSR           from '@salesforce/apex/ObjectFieldMetadataController.checkExistingSR';
import getRelatedSalesOrders     from '@salesforce/apex/ObjectFieldMetadataController.getRelatedSalesOrders';
import saveConsolidationRecords  from '@salesforce/apex/ObjectFieldMetadataController.saveConsolidationRecords';
import copyFilesToServiceRequest from '@salesforce/apex/ObjectFieldMetadataController.copyFilesToServiceRequest';
import deleteUploadedFile        from '@salesforce/apex/ObjectFieldMetadataController.deleteUploadedFile';
import getReceiptAmounts         from '@salesforce/apex/ObjectFieldMetadataController.getReceiptAmounts';

import STATUS_FIELD       from '@salesforce/schema/SalesOrder__c.Status__c';
import UNIT_FIELD         from '@salesforce/schema/SalesOrder__c.Unit__c';
import Account_FIELD         from '@salesforce/schema/SalesOrder__c.CustomerAccount__c';
import ADM_STATUS_FIELD   from '@salesforce/schema/SalesOrder__c.ADM_Fees_and_Dari__c';
import DOWN_PAYMENT_FIELD from '@salesforce/schema/SalesOrder__c.Down_Payment_Status__c';

const FIELDS = [STATUS_FIELD, Account_FIELD,UNIT_FIELD, ADM_STATUS_FIELD, DOWN_PAYMENT_FIELD];

export default class CreatePreorPostCancellationSR extends NavigationMixin(LightningElement) {

    @api recordId;

    showLoading = true;

    unitId            = '';
    accountId         = '';
    unitName          = '';
    admStatus         = '';
    downPaymentStatus = '';
    admPaidAmount     = 0;
    downPaymentAmount = 0;

    showForm               = false;
    showAdmRefundField     = true;
    showConsolidationTable = false;

    cancellationType   = '';
    admRefundValue     = '';
    recordTypeId       = '';
    modalHeader        = '';
    isPostCancellation = false;

    salesOrderStatus        = '';
    isExecuted              = false;
    hasConsolidationChanges = false;
    isSavingConsolidation   = false;

    // FIX: receipts may load after refund type is selected — flag tracks whether
    // amounts are ready so _computeTotalRefund() can re-run when they arrive
    _amountsLoaded = false;

    _soReady  = false;
    _rtReady  = false;
    _mapReady = false;

    @track salesOrders        = [];
    @track uploadedFiles      = [];
    @track draftValues        = [];
    @track srRecordTypes      = [];
    @track totalRefundAmount  = 0;

    statusRTMap = {};

    columns = [
        { label: 'Unit',        fieldName: 'Unit_Name__c', type: 'text' },
        { label: 'Sales Order', fieldName: 'Name',         type: 'text' },
        {
            label: 'Fund Transfer',
            fieldName: 'Fund_Transfer__c',
            type: 'boolean',
            editable: true
        },
        {
            label: 'Transfer Amount',
            fieldName: 'Transfer_Amount__c',
            type: 'currency',
            editable: true,
            typeAttributes: { currencyCode: 'AED', step: '0.01' }
        }
    ];

    // ================= LIFECYCLE =================

    connectedCallback() {
        getStatusToRecordTypeMap({ objName: 'ServiceRequest__c' })
            .then(res => {
                this.statusRTMap = res;
                this._mapReady   = true;
                this._tryNavigate();
            })
            .catch(err => {
                console.error('getStatusToRecordTypeMap error:', err);
                this.showLoading = false;
                this._showError('Error loading configuration. Please close and retry.');
            });
    }

    // ================= WIRES =================

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredSalesOrder({ data, error }) {
        if (data) {
            this.salesOrderStatus  = data.fields.Status__c?.value              ?? '';
            this.unitId            = data.fields.Unit__c?.value                ?? '';
            this.accountId            = data.fields.CustomerAccount__c?.value                ?? '';
            this.admStatus         = data.fields.ADM_Fees_and_Dari__c?.value   ?? '';
            this.downPaymentStatus = data.fields.Down_Payment_Status__c?.value ?? '';

            this._soReady = true;
            this._tryNavigate();
            this._loadReceiptAmounts();

        } else if (error) {
            console.error('getRecord error:', error);
            this.showLoading = false;
            this._showError('Error loading Sales Order. Please close and retry.');
        }
    }

    @wire(getObjectInfo, { objectApiName: 'ServiceRequest__c' })
    wiredObjectInfo({ data, error }) {
        if (data) {
            const rts = data.recordTypeInfos;
            this.srRecordTypes = Object.keys(rts)
                .filter(key => !rts[key].master)
                .map(key => ({
                    label: rts[key].name.includes('-')
                        ? rts[key].name.split('-')[1].trim()
                        : rts[key].name,
                    value: rts[key].recordTypeId
                }));
            this._rtReady = true;
            this._tryNavigate();
        } else if (error) {
            console.error('getObjectInfo error:', error);
            this.showLoading = false;
            this._showError('Error loading record type info. Please close and retry.');
        }
    }

    // ================= INITIALISATION =================

    async _tryNavigate() {
        if (
            this.isExecuted   ||
            !this._soReady    ||
            !this._rtReady    ||
            !this._mapReady   ||
            !this.salesOrderStatus
        ) {
            return;
        }

        this.isExecuted  = true;
        this.showLoading = true;

        try {
            const expectedRTName = this.statusRTMap[this.salesOrderStatus];
            if (!expectedRTName) {
                this._showError('No configuration found for status: ' + this.salesOrderStatus);
                return;
            }

            const rt = this.srRecordTypes.find(r => r.label === expectedRTName);
            if (!rt) {
                this._showError('Record type "' + expectedRTName + '" not found on ServiceRequest__c');
                return;
            }

            const existing = await checkExistingSR({
                salesOrderId: this.recordId,
                recordTypeId: rt.value
            });

            if (existing) {
                this._showError('A Service Request already exists for this Sales Order');
                return;
            }

            this.recordTypeId       = rt.value;
            this.modalHeader        = expectedRTName;
            this.isPostCancellation = expectedRTName.toLowerCase().includes('post');
            this.showForm           = true;

        } catch (err) {
            console.error('_tryNavigate error:', err);
            this._showError('Error initialising form: ' + (err.body?.message || err.message));
            this.isExecuted = false;
        } finally {
            this.showLoading = false;
        }
    }

    // FIX 3: after amounts load, re-compute the total in case
    // the user had already selected a refund type before amounts arrived
    async _loadReceiptAmounts() {
        try {
            const result = await getReceiptAmounts({ salesOrderId: this.recordId });
            this.admPaidAmount     = result.admAmount        || 0;
            this.downPaymentAmount = result.downPaymentAmount || 0;
            this._amountsLoaded    = true;
            // Re-compute in case admRefundValue was already selected
            this._computeTotalRefund();
        } catch (err) {
            console.error('getReceiptAmounts error:', err);
            this._amountsLoaded = true; // amounts stay 0 — still allow form use
        }
    }

    // FIX 1 & 3: single private method owns the computation — called from
    // both handleAdmRefundChange AND _loadReceiptAmounts so it's always current
    _computeTotalRefund() {
        if (this.admRefundValue === 'ADM') {
            this.totalRefundAmount = this.admPaidAmount || 0;

        } else if (this.admRefundValue === 'Down Payment') {
            this.totalRefundAmount = this.downPaymentAmount || 0;

        } else if (this.admRefundValue === 'Both') {
            this.totalRefundAmount = (this.admPaidAmount || 0) + (this.downPaymentAmount || 0);

        } else {
            this.totalRefundAmount = 0;
        }
    }

    // ================= CANCELLATION TYPE CHANGE =================

    handleCancellationTypeChange(event) {
        this.cancellationType  = event.detail.value;
        this.showAdmRefundField =
            this.cancellationType !== 'Cancellation without Refund';

        if (this.cancellationType === 'Consolidation Cancellation') {
            this.showConsolidationTable = true;
            if (!this.salesOrders.length) {
                this._loadSalesOrders();
            }
        } else {
            this.showConsolidationTable = false;
        }
    }

    async _loadSalesOrders() {
        this.showLoading = true;
        try {
            const data = await getRelatedSalesOrders({ salesOrderId: this.recordId });
            this.salesOrders = data.map(row => ({
                ...row,
                IsConsolidated__c:  row.Id === this.recordId,
                Fund_Transfer__c:   row.Fund_Transfer__c   || false,
                Transfer_Amount__c: row.Transfer_Amount__c || 0
            }));
        } catch (err) {
            console.error('getRelatedSalesOrders error:', err);
            this._showError('Error loading related Sales Orders');
        } finally {
            this.showLoading = false;
        }
    }

    // ================= INLINE EDIT =================

    handleDatatableSave(event) {
        const drafts = event.detail.draftValues;
        this.salesOrders = this.salesOrders.map(row => {
            const draft = drafts.find(d => d.Id === row.Id);
            return draft ? { ...row, ...draft } : row;
        });
        this.draftValues             = [];
        this.hasConsolidationChanges = true;
        this._showToast('Changes captured', 'success');
    }

    // FIX 1: ONE handleAdmRefundChange — delegates to _computeTotalRefund
    // The duplicate at the bottom of the old file is removed entirely
    handleAdmRefundChange(event) {
        this.admRefundValue = event.detail.value;
        this._computeTotalRefund();
    }

    // ================= COMPUTED GETTERS =================

    get consolidationTotalAmount() {
        return this.totalRefundAmount;
    }

    get showTotalRefundBanner() {
        return (
            this.cancellationType === 'Consolidation Cancellation' &&
            this.showConsolidationTable &&
            !!this.admRefundValue
        );
    }

    get disableCreateButton() {
        if (this.isSavingConsolidation) return true;
        if (this.showLoading)           return true;
        if (!this.cancellationType)     return true;
        if (!this.uploadedFiles.length) return true;

        if (this.cancellationType === 'Cancellation with Refund') {
            return !this.admRefundValue;
        }

        if (this.cancellationType === 'Consolidation Cancellation') {
            if (!this.admRefundValue) return true;
            return !this.salesOrders.some(
                row => row.Fund_Transfer__c === true && row.Transfer_Amount__c > 0
            );
        }

        return false;
    }

    // ================= SAVE SR =================

    async handleSave() {
        const errors = [];

        if (this.cancellationType !== 'Cancellation without Refund') {
            if (this.admRefundValue === 'ADM' || this.admRefundValue === 'Both') {
                if (this.admStatus !== 'Paid' && this.admStatus !== 'Partially Paid') {
                    errors.push('ADM Payment Status must be Paid or Partially Paid');
                }
            }
            if (this.admRefundValue === 'Down Payment' || this.admRefundValue === 'Both') {
                if (this.downPaymentStatus !== 'Paid' && this.downPaymentStatus !== 'Partially Paid') {
                    errors.push('Down Payment Status must be Paid or Partially Paid');
                }
            }
        }

        if (errors.length) {
            this._showError(errors.join(' | '));
            return;
        }

        // FIX 2: single consolidation block — no duplicate
        if (this.cancellationType === 'Consolidation Cancellation') {

            // Pair validation: both fields must be set together
            const invalidRows = this.salesOrders.filter(row =>
                (row.Transfer_Amount__c > 0  && row.Fund_Transfer__c !== true) ||
                (row.Fund_Transfer__c === true &&
                    (!row.Transfer_Amount__c || row.Transfer_Amount__c <= 0))
            );
            if (invalidRows.length) {
                this._showError(
                    'Fund Transfer and Transfer Amount must both be populated together'
                );
                return;
            }

            // Amount match validation
            if (this.totalRefundAmount > 0) {

                const selectedRows = this.salesOrders.filter(
                    row => row.Fund_Transfer__c === true && row.Transfer_Amount__c > 0
                );

                if (!selectedRows.length) {
                    this._showError(
                        'Please select at least one row with Fund Transfer ' +
                        'and enter a Transfer Amount'
                    );
                    return;
                }

                const sumOfSelected = selectedRows.reduce(
                    (acc, row) => acc + (Number(row.Transfer_Amount__c) || 0), 0
                );

                const sumRounded   = Math.round(sumOfSelected         * 100) / 100;
                const totalRounded = Math.round(this.totalRefundAmount * 100) / 100;

                if (sumRounded !== totalRounded) {
                    this._showError(
                        `Total Transfer Amount of selected rows (AED ${sumRounded.toFixed(2)}) ` +
                        `must equal the expected refund amount (AED ${totalRounded.toFixed(2)}). ` +
                        `Please adjust the Transfer Amounts.`
                    );
                    return;
                }
            }
        }

        if (this.showConsolidationTable && this.hasConsolidationChanges) {
            // eslint-disable-next-line no-alert
            if (!confirm(
                'Consolidation changes will be saved after Service Request creation. Continue?'
            )) {
                return;
            }
        }

        if (!this.uploadedFiles.length) {
            this._showError('Please upload at least one file before submitting');
            return;
        }

        this.showLoading = true;

        const fields = {};
        this.template.querySelectorAll('lightning-input-field').forEach(f => {
            fields[f.fieldName] = f.value;
        });
        fields.ADM_Payment_Status__c  = this.admStatus;
        fields.Down_Payment_Status__c = this.downPaymentStatus;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    // ================= RECORD EDIT FORM CALLBACKS =================

    async handleSuccess(event) {
        const srId = event.detail.id;
        try {
            await copyFilesToServiceRequest({
                salesOrderId:     this.recordId,
                serviceRequestId: srId
            });

            if (this.showConsolidationTable && this.salesOrders.length) {
                await this._saveConsolidationWithSR(srId);
            }

            this._showToast('Service Request created successfully', 'success');
            this.showLoading = false;
            setTimeout(() => this.close(), 1000);

        } catch (err) {
            this.showLoading = false;
            this._showError(err.body?.message || err.message);
        }
    }

    handleError(event) {
        this.showLoading = false;
        console.error('Record edit form error:', event.detail);
    }

    // ================= CONSOLIDATION SAVE =================

    async _saveConsolidationWithSR(srId) {
        const recordsToSave = this.salesOrders
            .filter(row => row.Fund_Transfer__c === true)
            .map(row => ({
                Sales_Order__c:     row.Id,
                Service_Request__c: srId,
                IsConsolidated__c:  row.IsConsolidated__c  || false,
                Fund_Transfer__c:   true,
                Transfer_Amount__c: row.Transfer_Amount__c || 0
            }));

        if (!recordsToSave.length) return;

        await saveConsolidationRecords({ records: recordsToSave });
        this._showToast(recordsToSave.length + ' consolidation record(s) saved', 'success');
    }

    // ================= FILE HANDLERS =================

    handleUploadFinished(event) {
        this.uploadedFiles = [...this.uploadedFiles, ...event.detail.files];
        this._showToast(event.detail.files.length + ' file(s) uploaded', 'success');
    }

    async removeFile(event) {
        const fileId = event.currentTarget.dataset.id;
        this.showLoading = true;
        try {
            await deleteUploadedFile({ contentDocumentId: fileId });
            this.uploadedFiles = this.uploadedFiles.filter(f => f.documentId !== fileId);
            this._showToast('File removed', 'success');
        } catch (err) {
            this._showError(err.body?.message || err.message);
        } finally {
            this.showLoading = false;
        }
    }

    // ================= UTILITY =================

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    _showToast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title:   variant.charAt(0).toUpperCase() + variant.slice(1),
            message,
            variant
        }));
    }

    _showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title:   'Error',
            message,
            variant: 'error'
        }));
    }
}