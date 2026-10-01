import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyApprovalSteps from '@salesforce/apex/BusinessProcessApprovalController.getMyApprovalSteps';

const PAGE_SIZE = 50;

export default class BusinessProcessApprovalDashboard extends LightningElement {
    steps = [];
    wiredStepsResult;
    isLoading = true;
    error;
    selectedStepId;

    @wire(getMyApprovalSteps, { limitCount: PAGE_SIZE, offsetCount: 0 })
    wiredSteps(result) {
        this.wiredStepsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.steps = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.extractErrorMessage(result.error);
            this.steps = [];
        }
    }

    get decoratedSteps() {
        return (this.steps || []).map((step) => ({
            ...step,
            isSelected: step.stepId === this.selectedStepId
        }));
    }

    get hasSteps() {
        return this.steps && this.steps.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && !this.hasSteps;
    }

    get pendingCount() {
        return this.steps ? this.steps.length : 0;
    }

    get pendingCountLabel() {
        return this.pendingCount === 1 ? '1 pending approval' : `${this.pendingCount} pending approvals`;
    }

    get hasSelection() {
        return !!this.selectedStepId;
    }

    get bodyClass() {
        return this.hasSelection ? 'dashboard-body has-selection' : 'dashboard-body';
    }

    get isRefreshDisabled() {
        return this.isLoading;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredStepsResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleSelect(event) {
        this.selectedStepId = event.detail.stepId;
    }

    handleCloseDetail() {
        this.selectedStepId = undefined;
    }

    handleActionComplete(event) {
        const { stepId, message } = event.detail;
        this.showToast('Success', message, 'success');
        this.steps = this.steps.filter((s) => s.stepId !== stepId);
        this.selectedStepId = undefined;
        refreshApex(this.wiredStepsResult);
    }

    handleActionError(event) {
        this.showToast('Something went wrong', event.detail.message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred while loading your approvals.';
    }
}