import { LightningElement,api,track,wire } from 'lwc';
import getCommissionLineDetails from "@salesforce/apex/CommissionLogicHandler.holdCommissionFromCommissionLine";
import initiateTheBatch from "@salesforce/apex/CommissionLogicHandler.runTheHoldReasonBatch";
import { CloseActionScreenEvent } from 'lightning/actions';
import {CurrentPageReference} from 'lightning/navigation';

export default class HoldCommissionLineLWC extends LightningElement {
    isLoading = false;
        @api recordId;
        @track isShowModal = false;
        @track message = 'test';
        reason = '';
        @track btnLabel = 'Hold';
        @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            if (currentPageReference) {
                this.recordId = currentPageReference.state.recordId;
            }
        }
        connectedCallback() {
               this.isLoading = true;
                    getCommissionLineDetails({ recordId: this.recordId })
                    .then(result => {
                        if(result.Is_Hold__c === true) {
                            this.message = 'Commission Line is on hold for the reason "' + result.Hold_Reason__c + '". Do you want to release it?';
                            this.btnLabel = 'Release';
                        } else {
                            this.message = 'Do you want to hold this commission line?';
                            this.btnLabel = 'Hold';
                        }
                       // this.showModalBox();
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        this.message = 'An error occurred while fetching commission line details.';
                       // this.showModalBox();
                    });
                // Reset loading state after the operation
                this.isLoading = false;
        }
        handleSubmit() {
            this.isLoading = true;
            if(this.reason == '' || this.reason == null || this.reason == undefined) {
                 this.isLoading = false;
               alert('Please enter a reason for hold / release the commission line.');
                return;

            }
            initiateTheBatch({ recordId: this.recordId, reason: this.reason,IsOnhold : this.btnLabel === 'Hold' })
                .then(() => {
                    this.isLoading = false;
                    this.hideModalBox();
                    // Optionally, you can dispatch a success event or show a toast message here
                })
                .catch(error => {
                    console.error('Error:', error);
                    this.isLoading = false;
                    this.message = 'An error occurred while holding or releasing the commission line.';
                    // Optionally, you can dispatch an error event or show a toast message here
                });
            // Close the modal box after submission
           this.handleCancel();
        }
        showModalBox() {  
            this.isShowModal = true;
        }
    
        hideModalBox() {  
            this.isShowModal = false;
            this.handleCancel();
        }
        handleReasonChange(event) {
            this.reason = event.target.value;
        }
        handleCancel() {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
}