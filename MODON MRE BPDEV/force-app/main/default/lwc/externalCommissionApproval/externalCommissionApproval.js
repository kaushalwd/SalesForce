import { LightningElement, track,wire } from 'lwc';
import fetchPage from '@salesforce/apex/CommissionLineReviewController.fetchPage';
import approve from '@salesforce/apex/CommissionLineReviewController.approve';
import reject from '@salesforce/apex/CommissionLineReviewController.reject';
import getAllowedStatuses from '@salesforce/apex/CommissionLineReviewController.getAllowedStatuses';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const actions = (row, doneCallback) => {
    const InReview = row?.Status__c === 'Internal Review In-Progress';

    doneCallback(
        InReview
        ? [
            { label: 'Approve', name: 'approve' },
            { label: 'Reject', name: 'reject' },
            { label: 'View SPA', name: 'preview' }
        ] : []
    );
};

export default class CommissionLineReview extends NavigationMixin(LightningElement) {
    @track rows = [];
    @track selectedRowIds = [];
    @track showDataTable = false;
    unitSearch = '';
    statusFilter = 'Internal Review In-Progress';

    statusOptions = [{ label: 'All', value: 'All' }];

    @wire(getAllowedStatuses)
    wiredStatuses({ data, error }) {
    if (data) {
        this.statusOptions = [
            { label: 'All', value: 'All' },
            ...data.map(status => ({
                label: status,
                value: status
            }))
        ];
    } else if (error) {
        console.error('Error loading statuses:', error);
    }
    }
    columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Unit', fieldName: 'Unit__c' },
        { label: 'SPA Status', fieldName: 'SPA_Status__c' },
        { label: 'DP Status', fieldName: 'Down_Payment_Status__c' },
        { label: 'ADM Status', fieldName: 'ADM_Fee_Status__c' },
        { label: 'PDC Status', fieldName: 'Is_PDC_Collected__c' },
        { label: 'Compliance', fieldName: 'Compliance_Status__c' },
        { label: 'Total Amount', fieldName: 'Total_Unit_Price__c' , type: 'currency' },
        { label: 'Commission %', fieldName: 'Commission_Percent_UI',type:'percent' },
        { label: 'Total Commission Amount', fieldName: 'Commission_Amount__c',type:'currency' },
        { label: 'Broker Agency', fieldName: 'BrokerAgencyFRM__c' },
        { label: 'Payment Eligible Date', fieldName: 'Payment_Eligible_Date__c', type: 'date' },
        { type: 'action', typeAttributes: { rowActions: actions } }
    ];

    pageSize = 10;
    pageNumber = 1;
    totalRecords = 0;
    isLoading = true;

    // Reject modal
    showRejectModal = false;
    rejectRowId = null;
    rejectReason = '';

    connectedCallback() {
        this.loadData();
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get disablePrev() {
        return this.pageNumber <= 1 || this.isLoading;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages || this.isLoading;
    }

    get disableBulkApprove() {
    const rejectedFilter = this.statusFilter === 'Rejected';
    return rejectedFilter || !this.selectedRowIds?.length || this.isLoading;
    }


    async loadData() {
        this.isLoading = true;
        //alert('refreshing');
        try {
            const res = await fetchPage({
                pageSize: this.pageSize,
                pageNumber: this.pageNumber,
                status: this.statusFilter,
                unitSearch: this.unitSearch
            });

            this.totalRecords = res.total || 0;
            if (res.total > 0) {
                this.showDataTable = true;
            } else {
                this.showDataTable = false;
            }
           // alert('Total Records: ' + this.totalRecords);
            this.rows = (res.records || []).map(r => ({
                ...r,
                recordUrl: `/${r.Id}`,
                contentDocumentId: r.SPADocumentId__c,
                Commission_Percent_UI: (r.Commission_Percent__c ?? 0) / 100
            }));


            // Clear selections when page changes (simpler + avoids approving off-page rows)
            this.selectedRowIds = [];
            this.isLoading = false;
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
            this.isLoading = false;
        } finally {
            this.isLoading = false;
        }
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

    handleRowSelection(event) {
        const selected = event.detail.selectedRows || [];
        this.selectedRowIds = selected.map(r => r.Id);
    }

    async handleBulkApprove() {
        if (!this.selectedRowIds.length) return;

        this.isLoading = true;
        try {
            await approve({ recordIds: this.selectedRowIds });
            this.toast('Success', 'Selected Record(s) approved successfully.', 'success');
            await this.loadData();
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
            this.isLoading = false;
        } finally {
            this.isLoading = false;
        }
    }

    async handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (row?.Status__c === 'Rejected') {
        this.toast('Info', 'This record is already rejected. Actions are disabled.', 'info');
        return;
    }

    if (actionName === 'approve') {
        await this.approveSingle(row.Id);
    } else if (actionName === 'reject') {
        this.openRejectModal(row.Id);
    }
    if (actionName === 'preview') {
      const contentDocumentId = row.contentDocumentId;
      if (!contentDocumentId) return;

      const url = await this[NavigationMixin.GenerateUrl]({
        type: 'standard__namedPage',
        attributes: { pageName: 'filePreview' },
        state: { selectedRecordId: contentDocumentId }
      });

      window.open(url, '_blank'); // opens in another tab
    }
}


    async approveSingle(recordId) {
        this.isLoading = true;
        try {
            await approve({ recordIds: [recordId] });
            this.toast('Success', 'Record approved.', 'success');
            await this.loadData();
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
            this.isLoading = false;
        } finally {
            this.isLoading = false;
        }
    }

    openRejectModal(recordId) {
        this.rejectRowId = recordId;
        this.rejectReason = '';
        this.showRejectModal = true;
    }

    closeRejectModal() {
        this.showRejectModal = false;
        this.rejectRowId = null;
        this.rejectReason = '';
    }

    handleRejectReasonChange(event) {
        this.rejectReason = event.target.value;
    }

    async confirmReject() {
        if (!this.rejectRowId) return;

        this.isLoading = true;
        if (!this.rejectReason || !this.rejectReason.trim()) {
            this.toast('Error', 'Rejection reason is required.', 'error');
            this.isLoading = false;
            return;
        }
        try {
            await reject({ recordId: this.rejectRowId, reason: this.rejectReason });
            this.toast('Success', 'Record rejected.', 'success');
            this.closeRejectModal();
            await this.loadData();
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
            this.isLoading = false;
        } finally {
            this.isLoading = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(e) {
        // Handles Apex + JS errors cleanly
        if (Array.isArray(e?.body)) return e.body.map(x => x.message).join(', ');
        return e?.body?.message || e?.message || 'Unknown error';
    }
    handleUnitSearchChange(event) {
    this.unitSearch = event.target.value;
    this.pageNumber = 1;
    this.loadData();
}

handleStatusChange(event) {
    this.statusFilter = event.detail.value;
    this.pageNumber = 1;
    this.loadData();
}

}