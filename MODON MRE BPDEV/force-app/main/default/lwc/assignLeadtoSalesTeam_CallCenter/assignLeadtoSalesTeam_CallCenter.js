// @description JavaScript controller for the leadAssignmentAction LWC.
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import assignSingleLead from '@salesforce/apex/assignLeadtoSalesTeam_CallCenter.assignLeadsFromLWC';
import getLeadRecord from '@salesforce/apex/assignLeadtoSalesTeam_CallCenter.getLeadRecord';
import Id from '@salesforce/user/Id';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LeadAssignmentAction extends LightningElement {
    @api recordId;
    @track isLoading = false;

    /**
     * Handles the button click event to assign the lead.
     * It sets the loading state, calls the Apex method, and handles the result.
     */

    connectedCallback() {
        setTimeout(() => {
            getLeadRecord({ leadId: this.recordId }).then(result => {
                if (result && result.OwnerId && result.OwnerId == Id) {
                    // Wait briefly to ensure recordId is populated

                    if (this.recordId) {
                        this.handleClick();
                    } else {
                        console.warn('recordId is still undefined in connectedCallback.');
                    }

                }
                else {
                    this.handleUnwantedClick();
                }
            })
        }, 0); // You can increase delay if needed (e.g., 100ms)
    }

    handleUnwantedClick() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Lead is already assigned to Sales Team, You cannot assign it again',
                variant: 'error',
            })
        );
        this.closeAction();
        this.isLoading = false;
    }
    handleClick() {
        // Set isLoading to true to show the spinner.
        this.isLoading = true;

        // Call the Apex method with the current recordId.
        assignSingleLead({ leadId: this.recordId })
            .then(() => {
                // On success, dispatch a toast event.
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Lead has been successfully assigned!',
                        variant: 'success',
                    })
                );
                // getRecordNotifyChange([{ recordId: this.recordId }]);
                // Close the action screen.
                this.closeAction();
            })
            .catch(error => {
                // On error, dispatch an error toast event.

                let errorMessage = 'An unknown error occurred.';
                if (error && error.message) {
                    errorMessage = error.message;
                }
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: errorMessage,
                        variant: 'error',
                    })
                );
            })
            .finally(() => {
                // Always set isLoading to false after the call completes.
                this.isLoading = false;
                this.handleReloadPage();
            });
    }

    /**
     * Dispatches an event to close the quick action modal.
     */
    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleReloadPage() {
        window.location.reload();
    }
}