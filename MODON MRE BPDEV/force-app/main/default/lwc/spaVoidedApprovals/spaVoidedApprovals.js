import { LightningElement, track, wire } from 'lwc';
import getPendingSPAApprovals from '@salesforce/apex/SalesOrderSPAApprovalController.getPendingSPAApprovals';
import approveSPA from '@salesforce/apex/SalesOrderSPAApprovalController.approveSPA';
import rejectSPA from '@salesforce/apex/SalesOrderSPAApprovalController.rejectSPA';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class SpaVoidedApprovals extends LightningElement {
    @track salesOrders = [];
    @track isLoading = false;
    @track showModal = false;
    @track selectedRecordId;
    @track comments = '';
    wiredResult;

    @wire(getPendingSPAApprovals)
    wiredOrders(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.salesOrders = data.map(so => ({
                Id: so.Id,
                Name: so.Name,
                recordLink: '/' + so.Id,
                UnitName: so.Unit__r ? so.Unit__r.Name : '',
                VoidReason: so.SPA_Voided_Reason__c || '',
                CustomerName: so.SPA_Void_Requested_By__r
                    ? so.SPA_Void_Requested_By__r.Name
                    : '-'
            }));
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }

    }

    get hasRecords() {
        return this.salesOrders && this.salesOrders.length > 0;
    }

    async handleApprove(event) {
        const recordId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await approveSPA({ salesOrderId: recordId });
            this.showToast('Success', 'SPA Voided approved successfully.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleReject(event) {
        this.selectedRecordId = event.target.dataset.id;
        this.comments = '';
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    async submitRejection() {
        if (!this.comments.trim()) {
            this.showToast('Validation', 'Please enter rejection comments.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            await rejectSPA({ salesOrderId: this.selectedRecordId, comments: this.comments });
            this.showToast('Success', 'SPA Voided rejected successfully.', 'success');
            this.closeModal();
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}