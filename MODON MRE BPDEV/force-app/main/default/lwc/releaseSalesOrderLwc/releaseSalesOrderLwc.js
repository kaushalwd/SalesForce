import { LightningElement, api, wire, track } from 'lwc';
import { CloseActionScreenEvent, refreshView } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import cancelSalesOrder from '@salesforce/apex/ReleaseSalesOrdeLwcController.releaseSalesOrder';
//Added by MODON CRM TEAM ON 22-DEC-2025
//Start
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SALESORDER_OBJECT from '@salesforce/schema/SalesOrder__c';
import CANCELLATION_REASON from '@salesforce/schema/SalesOrder__c.CancellationReason__c';
import SALESORDER_STATUS from '@salesforce/schema/SalesOrder__c.Status__c';
import UNIT_SOURCE_ENTITY from '@salesforce/schema/SalesOrder__c.Unit__r.Source_Entity__c';
//END
export default class ReleaseSalesOrderLwc extends LightningElement {
    @api recordId;

    @track initialModal = true;
    @track documentFiles = []; // local list of uploaded files metadata
    showLoading = false;
    initializeCalled = false;
    //Added by MODON CRM TEAM ON 22-DEC-2025
    //Start
    openCancellationReasonModal = false;
    cancellationReason = '';
    comments = '';
    @track reasonOptions = [];

    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [SALESORDER_STATUS, UNIT_SOURCE_ENTITY] 
    })
    salesOrder;
    //END
    connectedCallback() {
    }

    renderedCallback() {
        if (this.recordId !== undefined && !this.initializeCalled) {
            this.initializeCalled = true;
            this.getRecordId();
        }
    }

    getRecordId() {
        this.initializeCalled = true;
    }
    //Added by MODON CRM TEAM ON 22-DEC-2025
    //Start
    @wire(getObjectInfo, { objectApiName: SALESORDER_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: CANCELLATION_REASON
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.reasonOptions = data.values;
        } else if (error) {
            console.error('Picklist error', error);
        }
    }

    showCancelModal() {
        this.initialModal = false;
        this.openCancellationReasonModal = true;
    }

    handleCancelReasonChange(event) {
        const { name, value } = event.target;
        if (name === 'reason') this.cancellationReason = value;
        if (name === 'comments') this.comments = value;
    }

    handleUploadFinished(event) {
    // Get the list of uploaded files
    const uploadedFiles = event.detail.files;

    // Example: Show success toast
    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Success',
            message: uploadedFiles.length + ' file(s) uploaded successfully',
            variant: 'success'
        })
    );
    }
    //END

    releaseSalesOrder() {
    this.showLoading = true;
    if (!this.cancellationReason || !this.comments || this.cancellationReason === 'undefined' || this.comments === 'undefined') {
        this.showLoading = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error!',
                message: 'Please provide both Cancellation Reason and Comments before proceeding.',
                variant: 'error',
                mode: 'dismissable'
            })
        );
        return;
    }
    cancelSalesOrder({ recordId: this.recordId, cancellationReason: this.cancellationReason, comments: this.comments })
        .then(resp => {
            if (resp === 'Success') {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: 'Sales order is successfully released.',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
                setTimeout(() => {
                    window.location.reload();
                }, 1500);
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!',
                        message: resp,
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            }

            this.showLoading = false;
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch(error => {
            console.error('error ==>', error);
            this.showLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!',
                    message: 'An unexpected error occurred while releasing the sales order.',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
        });
    }


    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}