import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import printChequeStatus from '@salesforce/apex/PrintChequeController.printChequeStatus';

export default class PrintCheque extends NavigationMixin(LightningElement) {

    @api recordId;
    
    connectedCallback(){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        this.printChequeCallout();
    }

    printChequeCallout(){    
        printChequeStatus({salesOrderId:this.recordId}).then(result => {
            this.showSuccessToast();    
        }).catch(() => {});
    }

   

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Printed successfully.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    showErrorToast() {
        const event = new ShowToastEvent({
            title: 'Error',
            message: 'Error: Please check with Admin',
            variant: 'error',
            mode: 'dismissable'
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