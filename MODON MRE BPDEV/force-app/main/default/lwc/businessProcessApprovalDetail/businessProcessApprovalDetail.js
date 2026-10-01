import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getApprovalDetail from '@salesforce/apex/BusinessProcessApprovalController.getApprovalDetail';
import submitApprovalAction from '@salesforce/apex/BusinessProcessApprovalController.submitApprovalAction';
import getSteps from '@salesforce/apex/LwcApproveRejectBpstepController.getSteps';
import getNextQueueMembers from '@salesforce/apex/LwcApproveRejectBpstepController.getnextqueueMembers';

const ACTION_APPROVE = 'Approve';
const ACTION_REJECT = 'Reject';
const ACTION_MORE_INFO = 'RequireMoreInfo';

export default class BusinessProcessApprovalDetail extends NavigationMixin(LightningElement) {
    @api stepId;

    detail;
    isLoading = true;
    loadError;

    selectedAction;
    comments = '';
    reopenStepId;
    nextOwnerId;
    reopenOptions = [];
    nextOwnerOptions = [];
    isSubmitting = false;
    validationMessage;

    @wire(getApprovalDetail, { stepId: '$stepId' })
    wiredDetail({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.detail = data;
            this.loadError = undefined;
            this.resetActionForm();
        } else if (error) {
            this.loadError = this.extractErrorMessage(error);
            this.detail = undefined;
        }
    }

    resetActionForm() {
        this.selectedAction = undefined;
        this.comments = '';
        this.reopenStepId = undefined;
        this.nextOwnerId = undefined;
        this.reopenOptions = [];
        this.nextOwnerOptions = [];
        this.validationMessage = undefined;
        this.isSubmitting = false;
    }

    // ---- computed getters ----

    get card() {
        return this.detail ? this.detail.card : {};
    }

    get currencyCode() {
        return this.card.currencyCode || 'AED';
    }

    get actionOptions() {
        const opts = [];
        if (this.card.isApproveAllowed) {
            opts.push({ label: 'Approve', value: ACTION_APPROVE });
        }
        if (this.card.isRejectAllowed) {
            opts.push({ label: 'Reject', value: ACTION_REJECT });
        }
        if (this.card.isRequireMoreInfoAllowed) {
            opts.push({ label: 'Require More Information', value: ACTION_MORE_INFO });
        }
        return opts;
    }

    get hasActionOptions() {
        return this.actionOptions.length > 0;
    }

    get isReject() {
        return this.selectedAction === ACTION_REJECT;
    }

    get isMoreInfo() {
        return this.selectedAction === ACTION_MORE_INFO;
    }

    get isApprove() {
        return this.selectedAction === ACTION_APPROVE;
    }

    get commentsRequired() {
        return this.isReject || this.isMoreInfo || !!this.card.isReviewCommentsRequired;
    }

    get showNextOwnerField() {
        return this.isApprove && !!this.card.isChooseNextOwner;
    }

    get showReopenField() {
        return this.isMoreInfo;
    }

    get isReopenLoading() {
        return this.isMoreInfo && this.reopenOptions.length === 0;
    }

    get hasSalesOrder() {
        return !!(this.detail && this.detail.salesOrderId);
    }

    get hasAccount() {
        return !!(this.detail && this.detail.accountId);
    }

    get hasUnit() {
        return !!(this.detail && this.detail.unitId);
    }

    get hasProject() {
        return !!(this.detail && this.detail.projectId);
    }

    get hasInstallment() {
        return !!(this.detail && this.detail.installmentId);
    }

    get canSubmit() {
        if (!this.selectedAction || this.isSubmitting) {
            return false;
        }
        if (this.commentsRequired && !this.comments) {
            return false;
        }
        if (this.isMoreInfo && !this.reopenStepId) {
            return false;
        }
        return true;
    }

    get submitDisabled() {
        return !this.canSubmit;
    }

    // ---- event handlers ----

    handleActionChange(event) {
        this.selectedAction = event.detail.value;
        this.validationMessage = undefined;

        if (this.isMoreInfo && this.reopenOptions.length === 0) {
            this.loadReopenOptions();
        }
        if (this.showNextOwnerField && this.nextOwnerOptions.length === 0) {
            this.loadNextOwnerOptions();
        }
    }

    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    handleReopenStepChange(event) {
        this.reopenStepId = event.detail.value;
    }

    handleNextOwnerChange(event) {
        this.nextOwnerId = event.detail.value;
    }

    loadReopenOptions() {
        getSteps({ bpsId: this.stepId })
            .then((rows) => {
                this.reopenOptions = (rows || []).map((r) => ({ label: r.Name, value: r.Id }));
            })
            .catch((error) => {
                this.notifyError(error);
            });
    }

    loadNextOwnerOptions() {
        getNextQueueMembers({ bpsId: this.stepId })
            .then((rows) => {
                this.nextOwnerOptions = (rows || []).map((r) => ({ label: r.label, value: r.value }));
            })
            .catch((error) => {
                this.notifyError(error);
            });
    }

    handleSubmit() {
        if (!this.canSubmit) {
            this.validationMessage = 'Choose an action and fill in the required fields before submitting.';
            return;
        }
        this.validationMessage = undefined;
        this.isSubmitting = true;

        submitApprovalAction({
            stepId: this.stepId,
            actionName: this.selectedAction,
            comments: this.comments,
            reopenStepId: this.isMoreInfo ? this.reopenStepId : null,
            nextStepOwnerId: this.showNextOwnerField ? this.nextOwnerId : null
        })
            .then((result) => {
                this.dispatchEvent(
                    new CustomEvent('actioncomplete', {
                        detail: { stepId: this.stepId, message: result.message }
                    })
                );
            })
            .catch((error) => {
                this.notifyError(error);
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('closedetail'));
    }

    handleNavigate(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    notifyError(error) {
        this.dispatchEvent(
            new CustomEvent('actionerror', {
                detail: { message: this.extractErrorMessage(error) }
            })
        );
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }
}