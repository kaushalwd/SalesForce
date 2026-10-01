import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import retrievePaymentStatus from '@salesforce/apex/PaymentGatewayUtility.retrievePaymentStatus';

export default class FetchPaymentURLLwc extends NavigationMixin(LightningElement) {

    @api recordId;
    @track respWrap={};

    respResult;
    showLoading = false;

    connectedCallback(){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        this.retrievePaymentStatusCallout();
    }

    retrievePaymentStatusCallout(){
        this.showLoading = true;

        retrievePaymentStatus({recordID:this.recordId}).then(result => {
            this.respResult = result

            if(this.respResult == 'Success'){
                this.showSuccessToast();
                this.showLoading = false;
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else {
                this.showErrorToast(this.respResult);
                this.showLoading = false;
            }
    
        }).catch(() => {}).finally(() => {
            this.showLoading = false;
        });
    }

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Payment Status fetched successfully.',
            variant: 'success',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
        // Location.reload();
    }

    showErrorToast(errorMessage) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: errorMessage,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    navigateToRecordPage(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}