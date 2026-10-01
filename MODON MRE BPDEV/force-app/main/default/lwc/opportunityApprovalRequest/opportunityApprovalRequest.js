import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import LightningModal from 'lightning/modal';
import checkCondsAndSubmitApproval from '@salesforce/apex/OpportunityApprovalRequestController.checkCondsAndSubmitApproval';
import submitForApproval from '@salesforce/apex/OpportunityApprovalRequestController.submitForApproval';

export default class opportunityApprovalRequest extends NavigationMixin(LightningElement) {

    @api oppId;
    // @track respWrap={};
    showPopup = true;
    comments;

    connectedCallback(){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.oppId = reccId;
        // this.checkCondsAndSubmitApprovalCallout();
        this.checkCallout();
    }

    checkCondsAndSubmitApprovalCallout(){

        var requestWrap = {
            oppId: this.oppId,
            comments: this.comments
        };

        submitForApproval({requestWrapParam:JSON.stringify(requestWrap)}).then(result => {

            if(result.resultMessage == 'Approval request submitted successfully.'){
                this.showSuccessToast(result.resultMessage);
            } else {
                this.showErrorToast(result.resultMessage);
            }
            

        }).catch(error => {
            this.showErrorToast('This opportunity is currently in an approval process');
        });
    }

    checkCallout(){

        var requestWrap = {
            oppId: this.oppId,
            comments: this.comments
        };

        checkCondsAndSubmitApproval({requestWrapParam:JSON.stringify(requestWrap)}).then(result => {

            if(result.resultMessage == 'Approval request submitted successfully.'){
                // this.showSuccessToast(result.resultMessage);
                this.showPopup = true;
            } else {
                this.showErrorToast(result.resultMessage);
            }
            

        }).catch(error => {
            this.showErrorToast('This opportunity is currently in an approval process');
        });
    }

    showSuccessToast(message) {
        const event = new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    showErrorToast(message) {
        const event = new ShowToastEvent({
            title: 'Failed',
            message: message,
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
                recordId: this.oppId,
                actionName: 'view'
            }
        });
    }

    handleComments(){
        this.comments = this.template.querySelector('lightning-textarea').value;
    }
}