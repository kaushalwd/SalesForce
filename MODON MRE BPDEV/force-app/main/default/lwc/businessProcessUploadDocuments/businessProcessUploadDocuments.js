import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getBusinessProcessDocuments from '@salesforce/apex/DocumentUploadedFormController.getBusinessProcessDocuments';
import createBussinessProcessDocument from '@salesforce/apex/DocumentUploadedFormController.createBussinessProcessDocument';
import updateBussinessProcessDocumentss from '@salesforce/apex/DocumentUploadedFormController.updateBussinessProcessDocumentss';
import deleteBusinessProcessDocument from '@salesforce/apex/DocumentUploadedFormController.deleteBusinessProcessDocument';
import getBusinessProcessHeader from '@salesforce/apex/DocumentUploadedFormController.getBusinessProcessHeader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class BusinessProcessUploadDocuments extends LightningElement {
    @api recordId;
    @track bussinessProcessDocuments = [];
    @track selectedRows = [];
    @track newDocName = '';
    @track isLoading = false;
    @track showConfirmation = false;
    currentRecordId;
    @track hasOutstanding = false;
    @track confirmationMessage = 'Are you sure you want to proceed?';


    columns = [
        { label: 'Document Name', fieldName: 'Name', wrapText: true },
        { 
            label: 'Available to Customer', 
            fieldName: 'Available_to_Customer__c', 
            type: 'boolean',
            cellAttributes: { alignment: 'center' }
        },
        {
            type: 'button-icon',
            fixedWidth: 50,
            typeAttributes: {
                iconName: 'utility:delete',
                name: 'delete',
                title: 'Delete',
                variant: 'bare',
                alternativeText: 'Delete'
            }
        }
    ];

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.currentRecordId = currentPageReference.state?.recordId;
            
            if (!this.currentRecordId) {
                this.currentRecordId = currentPageReference.attributes?.recordId;
            }
            
            
            if (!this.currentRecordId) {
                this.currentRecordId = this.recordId;
            }

            if (this.currentRecordId) {
                this.loadDocuments();
            }
        }
    }

    connectedCallback() {
        if (this.recordId && !this.currentRecordId) {
            this.currentRecordId = this.recordId;
            this.loadDocuments();
        }
    }

    loadDocuments() {
        if (!this.currentRecordId) {
            console.error('Cannot load documents - recordId is null');
            this.showToast('Error', 'Business Process ID is required', 'error');
            return;
        }

        this.isLoading = true;
        
        getBusinessProcessDocuments({ bussinessProcessId: this.currentRecordId })
            .then(result => {
                this.bussinessProcessDocuments = result;
            })
            .catch(error => {
                console.error('Error fetching BP Docs:', error);
                this.showToast(
                    'Error',
                    'Failed to fetch documents: ' + (error.body?.message || error.message),
                    'error'
                );
        })
        .catch(error => {
            console.error('Header fetch error', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows;
    this.selectedRowIds = this.selectedRows.map(row => row.Id);
}

    handleInputChange(event) {
        this.newDocName = event.target.value;
    }

    handleAdd() {
        if (!this.newDocName.trim()) {
            this.showToast('Warning', 'Please enter a document name', 'warning');
            return;
        }

        if (!this.currentRecordId) {
            this.showToast('Error', 'Business Process ID is required', 'error');
            return;
        }

        this.isLoading = true;
        createBussinessProcessDocument({ bussinessProcessId: this.currentRecordId, docName: this.newDocName })
            .then(result => {
                this.bussinessProcessDocuments = [...this.bussinessProcessDocuments, result];
                this.newDocName = '';
                this.showToast('Success', 'Document added successfully', 'success');
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed to add document', 'error');
            })
            .finally(() => this.isLoading = false);
    }

    handleNext() {
        if (this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one document to send to customer', 'warning');
            return;
        }
        //this.showConfirmation = true;
        getBusinessProcessHeader({ bussinessProcessId: this.currentRecordId })
        .then(bp => {
            if (bp?.Booking__r?.Outstanding_Amount__c > 0) {
                this.hasOutstanding = true;
                this.confirmationMessage =
                    'Unit has an outstanding amount. Do you want to proceed?';
            } else {
                this.hasOutstanding = false;
                this.confirmationMessage =
                    'Are you sure you want to proceed?';
            }

            // OPEN MODAL ONLY AFTER DATA IS READY
            this.showConfirmation = true;
        })
        .catch(error => {
            console.error('Outstanding check failed', error);
            this.showToast('Error', 'Unable to validate outstanding amount', 'error');
        });
    }

    handleCancelConfirmation() {
        this.showConfirmation = false;
    }

    // handleConfirmSend() {
    //     this.showConfirmation = false;

    //     if (!this.currentRecordId) {
    //         this.showToast('Error', 'Business Process ID is required', 'error');
    //         return;
    //     }

    //     if (this.selectedRows.length === 0) {
    //         this.showToast('Warning', 'Please select at least one document', 'warning');
    //         return;
    //     }

    //     this.isLoading = true;

    //     // Call updateBussinessProcessDocumentss which will mark selected docs as Available_to_Customer = true
    //     // and then send email
    //     updateBussinessProcessDocumentss({ 
    //         docs: this.selectedRows, 
    //         bussinessProcessId: this.currentRecordId 
    //     })
    //         .then(() => {
    //             this.showToast('Success', 'Selected documents marked as available and email sent to customer', 'success');
    //             this.dispatchEvent(new CloseActionScreenEvent());
    //         })
    //         .catch(error => {
    //             console.error('Error:', error);
    //             this.showToast('Error', 'Failed to send: ' + (error.body?.message || error.message), 'error');
    //         })
    //         .finally(() => this.isLoading = false);
    // }
selectedRows = [];
selectedRowIds = [];

handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows;
    this.selectedRowIds = this.selectedRows.map(row => row.Id);
}

handleConfirmSend() {
        this.showConfirmation = false;

        if (!this.currentRecordId) {
            this.showToast('Error', 'Business Process ID is required', 'error');
            return;
        }
        
        if (this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one document', 'warning');
            return;
        }
        
        this.isLoading = true;
        
        updateBussinessProcessDocumentss({ 
            docIds: this.selectedRowIds,
            bussinessProcessId: this.currentRecordId,skipOutstanding: this.hasOutstanding 
        })
        .then(() => {
            this.showToast('Success', 'Selected documents sent to customer successfully', 'success');
            
            this.loadDocuments();
            
            this.selectedRows = [];
            this.selectedRowIds = [];
            
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch(error => {
            console.error('Error:', error);
            this.showToast('Error', 'Failed to send: ' + (error.body?.message || error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.deleteDocument(row.Id);
        }
    }

    deleteDocument(docId) {
        this.isLoading = true;
        deleteBusinessProcessDocument({ docId })
            .then(() => {
                this.bussinessProcessDocuments = this.bussinessProcessDocuments.filter(doc => doc.Id !== docId);
                this.showToast('Success', 'Document deleted successfully', 'success');
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed to delete document', 'error');
            })
            .finally(() => this.isLoading = false);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}