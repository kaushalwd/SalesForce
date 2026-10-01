import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getInvoiceLines from '@salesforce/apex/InvoiceLineViewerController.getInvoiceLines';
import updateHoldStatus from '@salesforce/apex/InvoiceLineViewerController.updateHoldStatus';
import { NavigationMixin } from 'lightning/navigation';



export default class InvoiceLineViewer extends NavigationMixin(LightningElement) {
    @api bundleId;
    invoiceLines = [];
    paginatedLines = [];
    currentPage = 1;
    pageSize = 15; // Number of records per page
    sortBy = '';
    sortDirection = 'asc';
    isModalOpen = false;
    holdReason = '';
    error = '';
    currentRecordId = null;
    releaseMode = false;
    isLoading = false;
    nextPageDisabled = false;
    prevPageDisabled = false;

    navigateBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.bundleId,
                objectApiName: 'Invoice_Bundle__c',
                actionName: 'view'
            }
        });
    }
    async updateHold(recordId, hold, reason) {
        this.isLoading = true;
        try {
            await updateHoldStatus({ invoiceLineId: recordId, onHold: hold, holdReason: reason });
            await this.loadData();
        } catch (error) {
            console.error('Error updating hold status:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleHoldClick(event) {
        const recordId = event.target.dataset.id;
        const record = this.invoiceLines.find(line => line.Id === recordId);

        if (record.Is_Hold__c) {
            await this.updateHold(recordId, false, '');
        } else {
            this.currentRecordId = recordId;
            this.releaseMode = false;
            this.isModalOpen = true;
        }
    }

    handleReasonChange(event) {
        this.holdReason = event.target.value;
        this.error = '';
    }

    closeModal() {
        this.isModalOpen = false;
        this.holdReason = '';
        this.error = '';
        this.currentRecordId = null;
    }

    async submitHold() {
        if (!this.holdReason.trim()) {
            this.error = 'Need to enter a reason for holding';
            return;
        }

    await this.updateHold(this.currentRecordId, true, this.holdReason);
    this.closeModal();
    }



    @wire(CurrentPageReference)
    getStateParameters(currentPageRef) {
        if (!this.bundleId && currentPageRef?.state?.c__bundleId) {
            this.bundleId = currentPageRef.state.c__bundleId;
            this.loadData();
        }
    }
    formatCurrency(amount) {
        if (!amount) return '';
        return 'AED ' + parseFloat(amount).toLocaleString('en-AE', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        this.sortData(field);
    }

    sortData(field) {
        const cloneData = [...this.invoiceLines];
        const isAsc = this.sortBy === field && this.sortDirection === 'asc';
        this.sortDirection = isAsc ? 'desc' : 'asc';
        this.sortBy = field;
        cloneData.sort((a, b) => {
            const valA = a[field] ?? '';
            const valB = b[field] ?? '';
            return (valA > valB ? 1 : -1) * (isAsc ? -1 : 1);
        });
        this.invoiceLines = cloneData;
        this.paginate();
    }

    async loadData() {
        if (!this.bundleId) return;
        const result = await getInvoiceLines({ bundleId: this.bundleId });
        this.invoiceLines = [...result]; ;
        this.paginate();
    }

    connectedCallback() {
        if (this.bundleId) {
            this.loadData();
        }
    }


    paginate() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.paginatedLines = undefined; 
    this.paginatedLines = [...this.invoiceLines.slice(start, end).map(line => ({
    ...line,
    formattedUnitPrice: this.formatCurrency(line.Total_Unit_Price__c),
    formattedCommission: this.formatCurrency(line.Total_Commission_Amount__c),
    formattedPayout: this.formatCurrency(line.Current_Commission_Payout_Now__c),
    formattedPayoutPending: line.Pending_Commission_Amount__c != null && line.Pending_Commission_Amount__c != '' && line.Pending_Commission_Amount__c != undefined ? this.formatCurrency(line.Pending_Commission_Amount__c):0,
    formattedPayoutPaid: line.Commission_Amount_Already_Paid__c != null && line.Commission_Amount_Already_Paid__c != '' && line.Commission_Amount_Already_Paid__c != undefined ?this.formatCurrency(line.Commission_Amount_Already_Paid__c):0,
    formattedPaymentPercent: line.Commission_Payout_Percent__c ? (line.Commission_Payout_Percent__c).toFixed(2) + '%' : '0%',
    holdButtonLabel: line.Is_Hold__c ? 'Release' : 'Hold',
    holdStatus: line.Is_Hold__c ? 'Yes' : 'No',
    buttonVariant: line.Is_Hold__c ? 'success' : 'brand',
    Hold_Reason__c: line.Hold_Reason__c
}))];

 // Update button disabled states
    this.prevPageDisabled = this.currentPage === 1;
    this.nextPageDisabled = (this.currentPage * this.pageSize) >= this.invoiceLines.length;

}



    handleNext() {
        if ((this.currentPage * this.pageSize) < this.invoiceLines.length) {
            this.currentPage++;
            this.paginate();
        }
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.paginate();
        }
    }
}