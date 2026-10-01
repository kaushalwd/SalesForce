import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import reassignLeadToSA from '@salesforce/apex/ReAssignToSalesAgent.reassignLeadToSA';
 
export default class ReassignLeadToSALwc extends NavigationMixin(LightningElement) {
 
    @api recordId;
 
    connectedCallback() {
        // Trigger process manually after load
        this.reassignLead();
    }
 
    async reassignLead() {
        try {
            const result = await reassignLeadToSA({ leadId: this.recordId });
            this.showSuccessToast();
        } catch (error) {
            console.error('Error:', error);
            this.showErrorToast(error.body?.message || 'Something went wrong.');
        }
    }
 
    showSuccessToast() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Lead reassigned to Sales Associate successfully.',
                variant: 'success',
                mode: 'sticky'
            })
        );
        this.navigateToRecordPage();
    }
 
    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error',
                mode: 'sticky'
            })
        );
        this.navigateToRecordPage();
    }
 
    navigateToRecordPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Lead',
                actionName: 'view'
            }
        });
    }
}