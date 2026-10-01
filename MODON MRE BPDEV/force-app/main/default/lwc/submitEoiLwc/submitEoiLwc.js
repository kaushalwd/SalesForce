import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import eoiSubmissionCheck from '@salesforce/apex/SubmitEOIController.eoiSubmissionCheck';
import submitEoi from '@salesforce/apex/SubmitEOIController.submitEoi';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SubmitEoiLwc extends NavigationMixin(LightningElement) {

    @api recordId;
    @track respWrap = {};
    showPopup    = false;
    isLoading    = false;
    isSubmitting = false;
    comments;

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        this.eoiSubmissionCheckCallout();
    }

    eoiSubmissionCheckCallout() {
        this.isLoading = true;

        var requestWrap = {
            eoiId: this.recordId,
            comments: this.comments
        };

        eoiSubmissionCheck({ requestWrapParam: JSON.stringify(requestWrap) })
            .then(result => {

                if (result.result == 'Success') {
                    this.showPopup = true;
                } else {
                    this.showWarningToast(result.result);
                }
            })
            .catch(error => {
                this.showErrorToast('Something went wrong. Please try again.');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    submitEoiCallout() {
        this.isSubmitting = true;

        var requestWrap = {
            eoiId: this.recordId,
            comments: this.comments
        };

        submitEoi({ requestWrapParam: JSON.stringify(requestWrap) })
            .then(result => {
                this.showSuccessToast();
            })
            .catch(error => {
                this.showErrorToast('This EOI is currently in an approval process.');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    // ── Toast helpers ─────────────────────────────────────────────────────────

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Submitted Successfully',
            message: 'EOI has been submitted and sent for approval.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.dispatchEvent(new CloseActionScreenEvent());
        let url = '/' + this.recordId;
        window.location.assign(url);
    }
    // Validation failures → warning (yellow) — not a system error
    showWarningToast(message) {
        const event = new ShowToastEvent({
            title: 'Action Required',
            message: message,
            variant: 'warning',
            mode: 'sticky'        // stays until user dismisses
        });
        this.dispatchEvent(event);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // System / unexpected failures → error (red)
    showErrorToast(message) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    navigateToRecordPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }

    handleComments(event) {
        this.comments = event.target.value;
    }
}