import { LightningElement, api, wire, track } from 'lwc';
import getInvoicesByBundle from '@salesforce/apex/CommissionLogicHandler.getInvoicesByBundle';
import processSelectedInvoices from '@salesforce/apex/CommissionLogicHandler.processSelectedInvoices';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class InvoiceBundleDatatable extends LightningElement {
    @track modelCancel = false;
    @track modelSave = false;
    @api recordId;
    @track fullData = [];
    @track pagedData = [];
    @track selectedRows = []; // All selected rows globally
    @track pageSelectedRows = []; // Only for this page
    @track disableApprovalButton = true; // Disable button until rows are selected
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalPages = 1;
    @track commissionMonth;
    @track showModal = false;
    @track richTextValue = '';

    @track isLoading = false; // Track loading state
    wiredResult; // Store @wire result for refreshApex

    get isPreviousDisabled() {
        return this.pageNumber === 1;
    }

    get isNextDisabled() {
        return this.pageNumber === this.totalPages;
    }

    columns = [
        { 
            label: 'Invoice Name', 
            fieldName: 'recordLink', 
            type: 'url', 
            typeAttributes: { 
                label: { fieldName: 'invoiceBundleName' }, 
                target: '_blank' 
            } 
        },
        { label: 'Name', fieldName: 'memberName' },
        { label: 'Type', fieldName: 'type' },
        { label: 'Split Type', fieldName: 'splitType' },
        { 
            label: 'Split Percentage', 
            fieldName: 'splitPercent'
        },
        { label: 'Month', fieldName: 'month' },
        { 
            label: 'Total Commission Amount', 
            fieldName: 'totalCommissionAmount',
            type: 'currency',
            typeAttributes: { currencyCode: 'AED', minimumFractionDigits: 2 }
        },
        { label: 'Approval Status', fieldName: 'approvalSts' },
        { label: 'Hold Status', fieldName: 'holdSts' }
    ];

    @wire(getInvoicesByBundle, { bundleId: '$recordId' })
    wiredInvoices(result) {
        this.isLoading = true; // Set loading state to tru
        this.wiredResult = result; // ✅ Correct: store the wire object
        const { data, error } = result;
        if (data) {
            this.fullData = data.map(record => ({
                ...record,
                recordLink: '/' + record.Id,
                bundleLink: record.Id ? '/' + record.Id : null
            }));
            if (data.length > 0) {
                const currentYear = new Date().getFullYear();
                this.commissionMonth = data[0].month;
                this.commissionMonth = this.formatCommissionMonth(this.commissionMonth)+' ' + currentYear;
            }
            this.totalPages = Math.ceil(this.fullData.length / this.pageSize);
            this.updatePagedData();
             this.isLoading = false;
        } else if (error) {
            console.error(error);
             this.isLoading = false;
        }
    }

    updatePagedData() {
        const startIdx = (this.pageNumber - 1) * this.pageSize;
        const endIdx = startIdx + this.pageSize;
        this.pagedData = this.fullData.slice(startIdx, endIdx);

        this.pageSelectedRows = this.pagedData
            .filter(row => this.selectedRows.includes(row.Id))
            .map(row => row.Id);

        this.disableApprovalButton = this.selectedRows.length === 0;
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.updatePagedData();
        }
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.updatePagedData();
        }
    }
    openModal() {
        if (this.selectedRows.length === 0) {
            this.showToast('Error', 'Please select at least one invoice bundle to proceed.', 'error');
            return;
        }
        this.showModal = true;
    }   
    handleCancel(){
        this.modelCancel = true;
        this.showModal = false;
    }
    handleSave(){   
        this.modelSave = true;
        this.showModal = false;
        this.processSelected();
    }
    handleRowSelection(event) {
    const selectedRows = event.detail.selectedRows;
    const currentPageIds = this.pagedData.map(row => row.Id);

    let validSelectedIds = [];
    let invalidRows = [];

    selectedRows.forEach(row => {
        if (row.holdSts && row.holdSts.toLowerCase() === 'hold') {
            invalidRows.push(row);
        } else {
            validSelectedIds.push(row.Id);
        }
    });

    if (invalidRows.length > 0) {
        this.showToast('Error', 'Invoice Bundle with Hold Status cannot be selected. Please release before send for an approval.', 'error');
    }

    // Remove all selections from this page
    this.selectedRows = this.selectedRows.filter(id => !currentPageIds.includes(id));

    // Merge valid selections only
    this.selectedRows = [...new Set([...this.selectedRows, ...validSelectedIds])];

    // Update visual selection on this page
    this.pageSelectedRows = validSelectedIds;
    this.disableApprovalButton = this.selectedRows.length === 0;
}


    processSelected() {
        if(this.modelSave == true){
          this.isLoading = true;
        if (this.selectedRows.length > 0) {
            processSelectedInvoices({ selectedInvoiceIds: this.selectedRows, notes: this.richTextValue })
                .then(() => {
                    this.showToast('Success', 'Invoice Bundle - Send for Approval', 'success');
                    return this.refreshTable();
                })
                .then(() => {
                    this.selectedRows = [];
                    this.pageSelectedRows = [];
                    this.pageNumber = 1;
                    this.updatePagedData();
                    this.isLoading = false;
                })
                .catch(error => {
                    console.error(error);
                    this.showToast('Error', 'Error! Please contact System Admin', 'error');
                    this.isLoading = false;
                });
        } else {
            this.showToast('Error', 'No rows selected to process', 'error');
        }
    }
    }

    refreshTable() {
        return refreshApex(this.wiredResult);
    }

    exportTable() {
    }

    showToast(title, message, variant = 'success', mode = 'dismissable') {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(evt);
    }
    formatCommissionMonth(monthStr) {
    if (!monthStr) return '';
    return monthStr.charAt(0).toUpperCase() + monthStr.slice(1).toLowerCase();
}
handleInputChange(event) {
        this.richTextValue = event.target.value;
}

}