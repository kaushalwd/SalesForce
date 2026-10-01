import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import reassignLead from '@salesforce/apex/SOStatusChangeController.reassignLead';
import checkButtonVisibility from '@salesforce/apex/SOStatusChangeController.checkSubmitButtonVisibility';

export default class ReassignLeadLwc extends LightningElement {
    @api recordId;
    isLoading = false;
    showButton = false;
    initializeCalled = false;
    connectedCallback(){
        
    }

    renderedCallback(){
        if(this.recordId !== undefined && !this.initializeCalled && this.recordId.startsWith('00Q')){
            this.initializeCalled = true;
            this.isLoading = true;
            checkButtonVisibility({leadId: this.recordId}).then(result => {
                this.showButton = result;
                this.isLoading = false;
            }).catch(() => {});
        }
    }

    onSubmitLead(){
        this.isLoading = true;

        reassignLead({leadId: this.recordId}).then(result => {
            if(result == 'Success'){
                this.showSuccessToast();
            }else {
                this.showErrorToast(result);
            }
        }).catch(() => {});

        // reassignLeadToSA({leadId: this.recordId}).then(result => {
            

        //     if(result == 'Success'){
        //         this.showSuccessToast();
        //     } else {
        //         this.showErrorToast(result);
        //     }

        // }).catch(error => {
        // });
    }

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Lead submitted successfully.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.isLoading = false;
        window.location.assign("/s/recordlist/Lead");
    }

    showErrorToast(errorMessage) {
        const event = new ShowToastEvent({
            title: 'Failed',
            message: errorMessage,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.isLoading = false;
        //window.location.assign("/modonportal/s/recordlist/Lead");
    }

    navigateToRecordPage(){
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Lead',
                recordId: this.recordId,
                actionName: 'list'
            }, state: {
                filterName: 'Recent'
            }
        });
    }
}