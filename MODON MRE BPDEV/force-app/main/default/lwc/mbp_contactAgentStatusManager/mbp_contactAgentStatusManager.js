/**********************************************************************************************************************
* Name               : mbp_contactAgentStatusManager
* Description        : This lwc is used as agent status shower for the Broker Portal .
* Usage              : LWC components for Broker Agency updates
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com          16 jun 2026      Initial Draft – Handles agent status
*                                                             
**********************************************************************************************************************/

import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import updateAgentStatus
    from '@salesforce/apex/MBP_BrokerAgencyLevelController.updateAgentStatus';

export default class ContactAgentStatusManager extends LightningElement {

    @api recordId;

    selectedStatus = '';
    reason = '';
    isLoading = false;

    statusOptions = [
        { label: 'Active', value: 'Active' },
        { label: 'In Active', value: 'In Active' },
        { label: 'Pending Verification', value: 'Pending Verification' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Suspended', value: 'Suspended' },
        { label: 'Blocked', value: 'Blocked' }
    ];

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    handleReasonChange(event) {
        this.reason = event.detail.value;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSubmit() {

        const plainText = this.reason
            ? this.reason.replace(/<[^>]*>/g, '').trim()
            : '';

        if (!this.selectedStatus) {
            this.showToast(
                'Validation Error',
                'Please select Agent Status',
                'error'
            );
            return;
        }

        if (!plainText) {
            this.showToast(
                'Validation Error',
                'Status Reason is mandatory',
                'error'
            );
            return;
        }

        this.isLoading = true;

        updateAgentStatus({
            contactId: this.recordId,
            status: this.selectedStatus,
            reason: this.reason
        })
        .then(() => {

            this.showToast(
                'Success',
                'Agent status updated successfully',
                'success'
            );

            this.isLoading = false;

            this.dispatchEvent(new CloseActionScreenEvent());

            setTimeout(() => {
                window.location.reload();
            }, 500);

        })
        .catch(error => {

            let message = 'Something went wrong';

            if (error?.body?.message) {
                message = error.body.message;
            }

            this.showToast(
                'Error',
                message,
                'error'
            );

            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}