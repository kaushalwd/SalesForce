/**
 * description       :
 * author            : Kumaravel Mathivanan
 * Created modified on  : 10-20-2025
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Kumaravel Mathivanan        10-02-2025     Initial Draft
 * 2.0           Manoj                       15-01-2026     Removed receipt polling; use Batch progress + final failure check
 * 3.0           Kc                          19-01-2026     Removed receipt polling; use Batch progress + final failure check
**/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Keep your edit save method (existing)
import updateReceipts from '@salesforce/apex/paymentApprovedController.updateReceipts';

// NEW: Approve + Start batch, Progress, and Failure check
import approveAndStartBatch from '@salesforce/apex/paymentApprovedController.approveAndStartBatch';
import getBatchProgress from '@salesforce/apex/paymentApprovedController.getBatchProgress';
import getOicFailures from '@salesforce/apex/paymentApprovedController.getOicFailures';

export default class PaymentApprovedReceiptDataTable extends NavigationMixin(LightningElement) {

    @api records;

    @track selectedRows = [];
    @track draftValues = [];
    @track selectedRowIds = [];

    // Editing guard (same logic as you had)
    _isEditing = false;
    _hasStartedDraftPolling = false;
    _draftPolling;

    //3.0 UI states
    isLoading = false;

    //3.0 Batch progress UI
    showProgress = false;
    progressValue = 0;
    progressStatusText = '';
    jobId;
    jobPollTimer;

    //3.0 Poll cadence for AsyncApexJob
    jobPollIntervalMs = 2000;

    columns = [
        {
            label: 'Receipt Name',
            fieldName: 'receiptLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'RecptNo' },
                target: '_blank'
            }
        },
        { label: 'Receipt Amount', fieldName: 'RecptAmount', type: 'currency', editable: true },
        { label: 'Receipt Date', fieldName: 'ReceiptDate', type: 'date', editable: true },
        { label: 'Cheque / Transaction No', fieldName: 'ChequeNo', editable: true },
        { label: 'Cheque Date', fieldName: 'ChequeDate', type: 'date', editable: true },
        { label: 'Transaction Date', fieldName: 'TransactionDate', type: 'date', editable: true },
        { label: 'Unit', fieldName: 'Unit' },
        { label: 'Customer Name', fieldName: 'CustName' },
        { label: 'Milestone', fieldName: 'MilestoneNo' },
        {
            type: 'button-icon',
            fixedWidth: 100,
            typeAttributes: {
                iconName: 'utility:preview',
                name: 'filePreview',
                label: 'View Receipt',
                title: 'View Receipt',
                variant: 'border-filled',
                enabled: { fieldName: 'FileId', negative: false },
                alternativeText: 'View Receipt'
            }
        }
    ];

    // --------------------
    // GETTERS
    // --------------------
    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get isButtonDisabled() {
        return this.isLoading || this._isEditing || this.selectedRowIds.length === 0;
    }

    // --------------------
    // ROW SELECTION
    // --------------------
    handleRowSelection(event) {
        if (this._isEditing) return;

        const selectedRows = event.detail.selectedRows || [];
        this.selectedRows = selectedRows;
        this.selectedRowIds = selectedRows.map(r => r.Id);

        this.dispatchEvent(new CustomEvent('selectedrows', {
            detail: { selectedRows: this.selectedRows },
            bubbles: true,
            composed: true
        }));
    }

    // --------------------
    //3.0 DRAFT POLLING (to block selection while inline edit)
    // --------------------
    renderedCallback() {
        if (this._hasStartedDraftPolling) return;
        this._hasStartedDraftPolling = true;

        this._draftPolling = setInterval(() => {
            const datatable = this.template.querySelector('lightning-datatable');
            if (!datatable) return;

            const drafts = datatable.draftValues || [];

            // Editing started
            if (drafts.length > 0 && !this._isEditing) {
                this._isEditing = true;
                this.selectedRowIds = [];
                datatable.selectedRows = [];
            }

            // Editing ended
            if (drafts.length === 0 && this._isEditing) {
                this._isEditing = false;
            }
        }, 300);
    }

    disconnectedCallback() {
        if (this._draftPolling) clearInterval(this._draftPolling);
        this.stopJobPolling();
    }

    // --------------------
    // BULK APPROVE -> START BATCH -> SHOW PROGRESS -> CHECK FAILURES
    // --------------------
    async handleBulkUpdate() {
        this.isLoading = true;
        this.showProgress = true;
        this.progressValue = 0;
        this.progressStatusText = 'Starting...';

        const receiptIds = [...this.selectedRowIds];

        try {
            // Clear UI selection right away
            this.selectedRows = [];
            this.selectedRowIds = [];

            const datatable = this.template.querySelector('lightning-datatable');
            if (datatable) datatable.selectedRows = [];

            //3.0 Approve + start batch (Apex returns AsyncApexJob Id)
            const res = await approveAndStartBatch({ receiptIds });
            this.jobId = res?.jobId;

            if (!this.jobId) {
                throw new Error('Batch job was not started (missing jobId).');
            }

            // 3.0 Poll AsyncApexJob for progress
            this.startJobPolling(receiptIds);

        } catch (e) {
            this.isLoading = false;
            this.showProgress = false;
            this.stopJobPolling();
            this.showToast('Error', this.getErrorMsg(e), 'error');
        }
    }
    //3.0 Started
    startJobPolling(receiptIds) {
        this.stopJobPolling();

        this.progressStatusText = 'Queued...';
        this.jobPollTimer = setInterval(async () => {
            try {
                const p = await getBatchProgress({ jobId: this.jobId });

                this.progressValue = p?.percent ?? 0;
                const processed = p?.processed ?? 0;
                const total = p?.total ?? 0;
                this.progressStatusText = `${p?.status || 'Processing'} (${processed}/${total})`;

                if (p?.status === 'Completed') {
                    this.stopJobPolling();
                    await this.afterJobDone(receiptIds);
                } else if (p?.status === 'Failed' || p?.status === 'Aborted') {
                    this.stopJobPolling();
                    this.isLoading = false;
                    this.showProgress = false;
                    this.dispatchEvent(new CustomEvent('refreshdata'));
                    this.showToast('Batch Failed', p?.extendedStatus || 'Batch failed/aborted.', 'error');
                }

            } catch (e) {
                this.stopJobPolling();
                this.isLoading = false;
                this.showProgress = false;
                this.showToast('Error', this.getErrorMsg(e), 'error');
            }
        }, this.jobPollIntervalMs);
    }

    stopJobPolling() {
        if (this.jobPollTimer) clearInterval(this.jobPollTimer);
        this.jobPollTimer = null;
    }

    async afterJobDone(receiptIds) {
        // Refresh grid first
        this.dispatchEvent(new CustomEvent('refreshdata'));

        try {
            const failures = await getOicFailures({ receiptIds });

            this.isLoading = false;
            this.showProgress = false;

            if (failures && failures.length > 0) {
                const msg = failures
                    .slice(0, 5)
                    .map(f => `${f.receiptName}: ${f.message}`)
                    .join(' | ') + (failures.length > 5 ? ` (+${failures.length - 5} more)` : '');

                this.showToast('Integration Error', msg, 'error');
            } else {
                this.showToast('Success', 'Approved & sent to Oracle successfully.', 'success');
            }
        } catch (e) {
            this.isLoading = false;
            this.showProgress = false;
            this.showToast('Error', this.getErrorMsg(e), 'error');
        }
    }

    // --------------------
    // INLINE EDIT SAVE (your existing logic kept)
    // --------------------
    async handleSave(event) {
        const draftValues = event.detail.draftValues || [];

        const sanitizedReceipts = draftValues.map(row => ({
            Id: row.Id,
            Receipt_Amount__c: row.RecptAmount,
            ReceiptDate__c: row.ReceiptDate,
            TransactionDate__c: row.TransactionDate,
            ChequeNo__c: row.ChequeNo,
            ChequeDate__c: row.ChequeDate
        }));

        try {
            await updateReceipts({ receiptList: sanitizedReceipts });

            this.draftValues = [];
            const datatable = this.template.querySelector('lightning-datatable');
            if (datatable) datatable.draftValues = [];

            this.dispatchEvent(new CustomEvent('refreshdata'));
            this.showToast('Success', 'Receipts updated successfully', 'success');

        } catch (error) {
            this.showToast('Error', 'Failed to update receipts: ' + this.getErrorMsg(error), 'error');
        }
    } //3.0 End

    // --------------------
    // ROW ACTION: FILE PREVIEW
    // --------------------
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'filePreview') {
            this.previewFile(row?.FileId);
        }
    }

    previewFile(contentDocumentId) {
        if (!contentDocumentId) {
            this.showToast('No File Found', 'This record has no file to preview.', 'warning');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: contentDocumentId }
        });
    }

    // --------------------
    // HELPERS
    // --------------------
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    //3.0 Error 
    getErrorMsg(error) {
        if (!error) return 'Unknown error';
        const e = Array.isArray(error) ? error[0] : error;

        if (e.body) {
            if (typeof e.body.message === 'string') return e.body.message;
            if (Array.isArray(e.body) && e.body[0]?.message) return e.body[0].message;
            if (e.body.pageErrors?.length) return e.body.pageErrors.map(pe => pe.message).join(', ');
            if (e.body.fieldErrors) {
                return Object.values(e.body.fieldErrors).flat().map(fe => fe.message).join(', ');
            }
        }
        return e.message || 'Unknown error';
    }
}