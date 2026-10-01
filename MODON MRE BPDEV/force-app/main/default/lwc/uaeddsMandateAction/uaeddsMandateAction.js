/**********************************************************************************************************************
* Name               : uaeddsMandateAction
* Description        : Quick action on a UAEDDS mandate: fetch the unsigned or signed form, refresh the bank
*                      status, and discard or cancel. Offers only what is legal right now.
* Usage              : Quick action on DirectDebitRequest__c, UAEDDS record type
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek Bansal              23 Aug 2026     Initial version
* 1.1           Prateek Bansal              24 Aug 2026     Console palette
* 1.2           Prateek Bansal              26 Aug 2026     A form already on file is not fetched a second time
* 1.3           Prateek Bansal              27 Aug 2026     Signed cancellation form; cancellation buttons in their own group
* 1.4           Prateek Bansal              01 Sep 2026     Submit to bank, for a mandate that never reached it
* 1.5           Karunakar                   15 Sep 2026     Reject Mandate, beside Approve, for one that never reached the bank
* 1.6           Karunakar                   15 Sep 2026     Reject asks for a reason first and will not go without one
******************************************************************************************************************/
import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import getMandate from '@salesforce/apex/UAEDDS_LWCController.getMandate';
import createMandate from '@salesforce/apex/UAEDDS_LWCController.createMandate';
import rejectMandate from '@salesforce/apex/UAEDDS_LWCController.rejectMandate';
import fetchDocument from '@salesforce/apex/UAEDDS_LWCController.fetchDocument';
import refreshStatus from '@salesforce/apex/UAEDDS_LWCController.refreshStatus';
import discard from '@salesforce/apex/UAEDDS_LWCController.discard';
import cancelMandate from '@salesforce/apex/UAEDDS_LWCController.cancelMandate';
import fetchCancellationForm from '@salesforce/apex/UAEDDS_LWCController.fetchCancellationForm';

export default class UaeddsMandateAction extends LightningElement {
    @api recordId;

    mandate;
    message;
    loading = false;
    wiredMandate;

    /** Open once Reject is pressed, and the reason typed into it. Nothing is written until Confirm. */
    askingReason = false;
    rejectionReason = '';

    @wire(getMandate, { mandateId: '$recordId' })
    wired(result) {
        this.wiredMandate = result;
        if (result.data) {
            this.mandate = result.data;
        } else if (result.error) {
            this.message = this.readError(result.error);
        }
    }

    get isFab() {
        return this.mandate && !this.mandate.isUaedds;
    }

    // Discard and cancel are mutually exclusive, so the ending section shows for either.
    get showEnding() {
        return this.mandate && (this.mandate.canDiscard || this.mandate.canCancel);
    }

    get unsignedDisabled() {
        return this.loading || (this.mandate && this.mandate.hasUnsignedForm);
    }

    get signedDisabled() {
        return this.loading || (this.mandate && this.mandate.hasSignedForm);
    }

    /**
     * Says which form is already filed, so a greyed out button is not a dead end. Fetching the same
     * form a second time files a second identical copy, which is what the greying out stops.
     */
    get filedNote() {
        if (!this.mandate) {
            return undefined;
        }
        const filed = [];
        if (this.mandate.hasUnsignedForm) {
            filed.push('unsigned');
        }
        if (this.mandate.hasSignedForm) {
            filed.push('signed');
        }
        if (filed.length === 0) {
            return undefined;
        }
        return filed.length === 2
            ? 'The unsigned and signed forms are already filed against this mandate. Delete one from the Documents record to fetch it again.'
            : `The ${filed[0]} form is already filed against this mandate. Delete it from the Documents record to fetch it again.`;
    }

    /**
     * The reason box, and the two buttons that close it.
     *
     * Reject asks rather than acts, so the reason is collected before anything is written - the
     * record cannot be refused first and explained afterwards. Confirm stays greyed out until
     * something has actually been typed, and the service refuses a blank one as well, because a
     * disabled button is a courtesy rather than a control.
     */
    get showRejectButton() {
        return !this.askingReason;
    }

    get approveDisabled() {
        // Approve is withdrawn while the reason box is open, so the panel poses one question at a
        // time. Cancel puts it back.
        return this.loading || this.askingReason;
    }

    get confirmRejectDisabled() {
        return this.loading || !this.rejectionReason || this.rejectionReason.trim().length === 0;
    }

    handleReject() {
        this.askingReason = true;
        this.message = undefined;
    }

    handleReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    handleCancelReject() {
        this.askingReason = false;
        this.rejectionReason = '';
    }

    get cancelUnsignedDisabled() {
        return this.loading || (this.mandate && this.mandate.hasUnsignedCancellationForm);
    }

    get cancelSignedDisabled() {
        return this.loading || (this.mandate && this.mandate.hasSignedCancellationForm);
    }

    /** The same note as filedNote, for the cancellation paperwork rather than the mandate's. */
    get cancelFiledNote() {
        if (!this.mandate) {
            return undefined;
        }
        const filed = [];
        if (this.mandate.hasUnsignedCancellationForm) {
            filed.push('unsigned');
        }
        if (this.mandate.hasSignedCancellationForm) {
            filed.push('signed');
        }
        if (filed.length === 0) {
            return undefined;
        }
        return filed.length === 2
            ? 'Both cancellation forms are already filed. Delete one from the Documents record to fetch it again.'
            : `The ${filed[0]} cancellation form is already filed. Delete it from the Documents record to fetch it again.`;
    }

    handleAction(event) {
        const action = event.target.dataset.action;
        this.loading = true;
        this.message = undefined;

        this.run(action)
            .then((result) => {
                // Closed only once the rejection is saved. A failed one leaves the box open with
                // what was typed still in it, so the sentence does not have to be written twice.
                this.askingReason = false;
                this.rejectionReason = '';
                this.toast('Done', result, 'success');
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                return refreshApex(this.wiredMandate);
            })
            .catch((error) => {
                const text = this.readError(error);
                this.message = text;
                this.toast('Not done', text, 'error', 'sticky');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    run(action) {
        switch (action) {
            case 'submit':
                return createMandate({ mandateId: this.recordId });
            case 'reject':
                return rejectMandate({
                    mandateId: this.recordId,
                    reason: this.rejectionReason.trim()
                });
            case 'unsigned':
                return fetchDocument({ mandateId: this.recordId, signed: false });
            case 'signed':
                return fetchDocument({ mandateId: this.recordId, signed: true });
            case 'refresh':
                return refreshStatus({ mandateId: this.recordId });
            case 'discard':
                return discard({ mandateId: this.recordId });
            case 'cancel':
                return cancelMandate({ mandateId: this.recordId });
            case 'cancelform':
                return fetchCancellationForm({ mandateId: this.recordId, signed: false });
            case 'cancelformsigned':
                return fetchCancellationForm({ mandateId: this.recordId, signed: true });
            default:
                return Promise.reject(new Error('Unknown action ' + action));
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // The services refuse with a sentence that says what to do instead, so it is worth surfacing
    // rather than replacing with a generic failure message.
    readError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Something went wrong. The call is in the Direct Debit logs.';
    }

    toast(title, message, variant, mode) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: mode || 'dismissable' }));
    }
}