/**********************************************************************************************************************
* Name               : agencyStatusManager
* Description        : LWC to update Agency Status, or schedule an Agency suspension.
* Usage              : Quick Action / Screen Flow component on Account (Broker Agency)
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com          16 jun 2026      Initial Draft
* 2.0         upendra.asam@modon.com          30 aug 2026      Suspension now writes to Broker_Status_Log__c
*                                                                (no approval step) — updated copy accordingly.
* 3.0         upendra.asam@modon.com          30 aug 2026      Clearer suspension UI — dedicated panel, duration
*                                                                readout, explicit explanation of effects.
**********************************************************************************************************************/

import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import updateAgencyStatus
    from '@salesforce/apex/MBP_BrokerAgencyLevelController.updateAgencyStatus';
import submitSuspension
    from '@salesforce/apex/MBP_BrokerAgencyLevelController.submitSuspension';

export default class AgencyStatusManager extends LightningElement {

    @api recordId;

    selectedStatus = '';
    reason = '';
    startDate = '';
    endDate = '';
    isLoading = false;

    statusOptions = [
        { label: 'Active', value: 'Active' },
        { label: 'In Active', value: 'In Active' },
        { label: 'Pending Verification', value: 'Pending Verification' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Suspended', value: 'Suspended' },
        { label: 'Blocked', value: 'Blocked' }
    ];

    get isSuspension() {
        return this.selectedStatus === 'Suspended';
    }

    get submitLabel() {
        return this.isSuspension ? 'Schedule Suspension' : 'Update Status';
    }

    // Tomorrow — Start Date must be strictly after today
    get minStartDate() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        return d.toISOString().split('T')[0];
    }

    // End Date must be after Start Date (fallback to minStartDate if not set)
    get minEndDate() {
        if (this.startDate) {
            const d = new Date(this.startDate);
            d.setDate(d.getDate() + 1);
            return d.toISOString().split('T')[0];
        }
        return this.minStartDate;
    }

    // Human-readable duration summary shown under the date pickers
    get durationSummary() {
        if (!this.startDate || !this.endDate) {
            return '';
        }
        const start = new Date(this.startDate);
        const end = new Date(this.endDate);
        const diffDays = Math.round((end - start) / (1000 * 60 * 60 * 24));
        if (diffDays <= 0) {
            return '';
        }
        const dayLabel = diffDays === 1 ? 'day' : 'days';
        return `This agency will be suspended for ${diffDays} ${dayLabel} — from ${this.formatDate(this.startDate)} to ${this.formatDate(this.endDate)}.`;
    }

    get hasDurationSummary() {
        return this.durationSummary !== '';
    }

    formatDate(isoDate) {
        const d = new Date(isoDate);
        return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        if (!this.isSuspension) {
            this.startDate = '';
            this.endDate = '';
        }
    }

    handleReasonChange(event) {
        this.reason = event.detail.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.detail.value;
        // Reset end date if it's no longer valid against the new start date
        if (this.endDate && this.endDate <= this.startDate) {
            this.endDate = '';
        }
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSubmit() {

        const plainText = this.reason
            ? this.reason.replace(/<[^>]*>/g, '').trim()
            : '';

        if (!this.selectedStatus) {
            this.showToast('Validation Error', 'Please select Agency Status', 'error');
            return;
        }
        if (!plainText) {
            this.showToast('Validation Error', 'Status Reason is mandatory', 'error');
            return;
        }

        if (this.isSuspension) {
            this.submitSuspensionFlow();
        } else {
            this.updateStatusFlow();
        }
    }

    submitSuspensionFlow() {

        const today = new Date().toISOString().split('T')[0];

        if (!this.startDate || !this.endDate) {
            this.showToast('Validation Error', 'Start Date and End Date are required', 'error');
            return;
        }
        if (this.startDate <= today) {
            this.showToast('Validation Error', 'Start Date must be after today', 'error');
            return;
        }
        if (this.endDate <= this.startDate) {
            this.showToast('Validation Error', 'End Date must be after Start Date', 'error');
            return;
        }

        this.isLoading = true;

        submitSuspension({
            accountId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate,
            reason: this.reason
        })
        .then(() => {
            this.showToast('Success', 'Suspension scheduled successfully', 'success');
            this.finishAndClose();
        })
        .catch(error => this.handleError(error));
    }

    updateStatusFlow() {

        this.isLoading = true;

        updateAgencyStatus({
            accountId: this.recordId,
            status: this.selectedStatus,
            reason: this.reason
        })
        .then(() => {
            this.showToast('Success', 'Agency status updated successfully', 'success');
            this.finishAndClose();
        })
        .catch(error => this.handleError(error));
    }

    finishAndClose() {
        this.isLoading = false;
        this.dispatchEvent(new CloseActionScreenEvent());
        setTimeout(() => { window.location.reload(); }, 500);
    }

    handleError(error) {
        let message = 'Something went wrong';
        if (error?.body?.message) {
            message = error.body.message;
        }
        this.showToast('Error', message, 'error');
        this.isLoading = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}