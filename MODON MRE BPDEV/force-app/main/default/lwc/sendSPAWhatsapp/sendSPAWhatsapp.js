import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateDocusignURL from '@salesforce/apex/OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURL';

export default class SendSPAWhatsapp extends NavigationMixin(LightningElement) {

    @api recordId;
    @track isLoading = true;
    connectedCallback(){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        this.sendSPAWhatsappAPI();
    }

    sendSPAWhatsappAPI(){    
        generateDocusignURL({SalesOrderId:this.recordId}).then(result => {
            this.isLoading = false;
            this.showSuccessToast();    
        }).catch(() => {});
    }

   

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'SPA Sent successfully.',
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