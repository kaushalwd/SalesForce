import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import { loadStyle } from 'lightning/platformResourceLoader';
import THEME_ALIGNMENT from '@salesforce/resourceUrl/mbprThemeAlignment';
import privacypol from '@salesforce/label/c.MBP_privacypol';
import Termsandcondtions from '@salesforce/label/c.MBP_TermsandConditions';

import startResume from '@salesforce/apex/MBP_RegistrationGatewayController.startResume';
import verifyResumeOtp from '@salesforce/apex/MBP_RegistrationGatewayController.verifyResumeOtp';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';

const STEP_DEFINITIONS = [
    { stepNumber: '1', label: 'Company Information' },
    { stepNumber: '2', label: 'Trade License Information' },
    { stepNumber: '3', label: 'Owner Information' },
    { stepNumber: '4', label: 'Agency Admin Information' },
    { stepNumber: '5', label: 'Bank Information' }
];

export default class MbprRegistrationWorkspace extends LightningElement {
    /** 'guest' renders the landing; 'continuation' auto-loads the logged-in
     *  limited user's draft. */
    @api mode = 'guest';

    isInitializing = false;
    isLoading = false;
    loadError = '';

    currentStep = 'initial';
    email = '';
    recordId = null;
    // The registration's key, held for this tab only and passed down to every step.
    sessionId = null;
    registrationRecordId = null;
    registrationObj = {};
    registrationStatus = '';

    showOTPInput = false;
    enteredOTP = '';

    /* 'choice' shows the two actions, 'resume' reveals the Trade License
       lookup. Register goes straight to step 1, so it can never overwrite a
       saved draft and Resume can never start a blank one. */
    landingView = 'choice';

    showStatusMessage = false;
    statusMessage = '';

    showInProgressPopup = false;
    taskComment = '';

    registrationAgentrecordId = null;

    objectApiName = 'Registration__c';
    regiAgentObjectApiName = 'Registration_Agent__c';

    _otpOpener = null;

    termsUrl = Termsandcondtions;
    privacyUrl = privacypol;
    currentYear = new Date().getFullYear();

    _prevRootBg = '';
    _prevBodyBg = '';
    _prevRootScrollbar = '';

    connectedCallback() {
        loadStyle(this, THEME_ALIGNMENT).catch(() => {});
        this.paintDocumentCanvas(true);
        this.applyResumeDeepLink();
        if (this.isContinuation) {
            this.loadContinuation();
        }
    }

    /* The login page's Resume action appends ?resume=1. Any failure falls
       through to the choice screen. */
    applyResumeDeepLink() {
        try {
            const search = window.location && window.location.search;
            if (search && new URLSearchParams(search).get('resume') === '1') {
                this.landingView = 'resume';
            }
        } catch (error) {
            // Default landing stands.
        }
    }

    disconnectedCallback() {
        this.paintDocumentCanvas(false);
    }

    /* Windows leaves a white hairline along the viewport's bottom edge: the
       site canvas shows through this fixed dark shell at fractional scaling,
       and the document scrollbar tracks render light. Done in JS because the
:has CSS version is dropped on Firefox <121. Restored on disconnect
       so no other site page keeps it. */
    paintDocumentCanvas(active) {
        try {
            const root = document.documentElement;
            const body = document.body;
            if (active) {
                this._prevRootBg = root.style.backgroundColor;
                this._prevBodyBg = body.style.backgroundColor;
                this._prevRootScrollbar = root.style.getPropertyValue('scrollbar-color');
                root.style.backgroundColor = '#08090b';
                body.style.backgroundColor = '#08090b';
                root.style.setProperty('scrollbar-color', 'rgba(255, 255, 255, 0.28) transparent');
            } else {
                root.style.backgroundColor = this._prevRootBg || '';
                body.style.backgroundColor = this._prevBodyBg || '';
                if (this._prevRootScrollbar) {
                    root.style.setProperty('scrollbar-color', this._prevRootScrollbar);
                } else {
                    root.style.removeProperty('scrollbar-color');
                }
            }
        } catch (error) {
            // Best effort - the stylesheet fallbacks still apply.
        }
    }


    get isContinuation() {
        return this.mode === 'continuation';
    }

    get isGuest() {
        return !this.isContinuation;
    }

    // ------------------------------------------------------------------
    // Continuation mode (legacy autoFetchForLimitedUser contract)
    // ------------------------------------------------------------------

    async loadContinuation() {
        this.isInitializing = true;
        this.loadError = '';
        try {
            const wrapper = await findRegistrationWithReviewComment();
            const registration = wrapper ? wrapper.registration : null;
            this.taskComment = (wrapper && wrapper.taskComment) || '';
            if (registration) {
                this.registrationObj = registration;
                this.registrationStatus = registration.Status__c || '';
                this.recordId = registration.Id;
                this.registrationRecordId = registration.Id;
                if (registration.Status__c === 'Submitted') {
                    this.showInProgressPopup = true;
                }
            } else {
                this.registrationObj = {};
                this.registrationStatus = '';
                this.recordId = null;
                this.registrationRecordId = null;
            }
            this.currentStep = '1';
        } catch (error) {
            this.loadError =
                this.reduceError(error) || 'Unable to load your registration. Please try again later.';
        } finally {
            this.isInitializing = false;
        }
    }

    handleRetryLoad() {
        this.loadContinuation();
    }

    // ------------------------------------------------------------------
    // Guest landing (search / OTP / create)
    // ------------------------------------------------------------------

    get showLanding() {
        return this.isGuest && this.currentStep === 'initial';
    }

    get showSteps() {
        return this.currentStep !== 'initial' && !this.isInitializing && !this.loadError;
    }

    get isChoiceView() {
        return this.landingView === 'choice';
    }

    get isResumeView() {
        return this.landingView === 'resume';
    }

    handleChooseResume() {
        this.landingView = 'resume';
        this.showStatusMessage = false;
        this.statusMessage = '';
    }

    handleBackToChoice() {
        this.landingView = 'choice';
        this.email = '';
        this.showStatusMessage = false;
        this.statusMessage = '';
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            // Legacy let Enter skip the OTP gate; the search action is the
            // same either way, so Enter follows the Search button path.
            this.handleSendOtp();
        }
    }

    async handleSendOtp() {
        const tradeLicenseNumber = (this.email || '').trim();

        // email lookup is removed. Reject it here rather than letting
        // the Apex OR-clause match a company email and post an OTP.
        if (!tradeLicenseNumber) {
            this.showToast('Please enter your Trade License Number.', 'warning');
            return;
        }
        if (tradeLicenseNumber.includes('@')) {
            this.showToast(
                'Registrations are resumed with the Trade License Number, not an email address.',
                'warning'
            );
            return;
        }

        this.email = tradeLicenseNumber;
        this.isLoading = true;
        try {
            const result = await startResume({ value: tradeLicenseNumber });

            if (!result || result.status === 'NOT_FOUND') {
                this.showToast('No saved registration was found for that Trade License Number.', 'warning');
                return;
            }
            if (result.status === 'NOT_DRAFT') {
                this.showToast(
                    'The registration associated with this Trade License Number has already been submitted.',
                    'info'
                );
                return;
            }

            this.registrationRecordId = result.registrationId;
            this._otpOpener = this.template.activeElement || null;
            this.showOTPInput = true;
            this.showToast('An OTP has been sent to your Company email address.', 'success');
        } catch (error) {
            this.showToast(this.reduceError(error) || 'Error sending OTP', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOtpChange(event) {
        this.enteredOTP = event.target.value;
    }

    async handleVerifyOtp() {
        this.isLoading = true;
        try {
            const opened = await verifyResumeOtp({
                registrationId: this.registrationRecordId,
                code: this.enteredOTP
            });
            if (opened) {
                this.sessionId = opened.sessionId;
                this.showToast('OTP verified successfully. Please proceed to update the existing record.', 'success');
                await this.handleSearch(opened.registration);
            } else {
                this.showToast('The OTP you entered is incorrect. Please try again.', 'error');
            }
        } catch (error) {
            this.showToast(this.reduceError(error) || 'Error verifying OTP', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeOtpModal() {
        this.showOTPInput = false;
        this.enteredOTP = '';
        if (this._otpOpener && this._otpOpener.isConnected) {
            this._otpOpener.focus();
        }
        this._otpOpener = null;
    }

    handleOtpKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeOtpModal();
        }
    }

    // Called once the OTP is verified; the record comes from that call, not from a fresh lookup by email.
    async handleSearch(registration) {
        this.isLoading = true;
        this.showOTPInput = false;
        if (!this.email) {
            this.showToast('Please enter your Trade License Number.', 'error');
            this.isLoading = false;
            return;
        }
        this.showStatusMessage = false;
        try {
            const result = registration;
            if (result) {
                this.registrationObj = result;
                this.registrationStatus = result.Status__c || '';
                if (result.Status__c !== 'Draft') {
                    this.showStatusMessage = true;
                    this.statusMessage = `Your application is currently at ${result.Status__c}. Please wait while we complete your request.`;
                    this.email = '';
                    this.recordId = null;
                    this.registrationRecordId = null;
                    return;
                }
                this.recordId = result.Id;
                this.registrationRecordId = result.Id;
                this.currentStep = '1';
            } else if (this.isResumeView) {
                // "Resume does not start a new blank application."
                this.showToast(
                    'We could not reopen that registration. Please try again or contact support.',
                    'error'
                );
            } else {
                this.recordId = null;
                this.registrationRecordId = null;
                this.registrationObj = {};
                this.registrationStatus = '';
                this.currentStep = '1';
                this.showToast('No existing record found. Proceed to create a new request.', 'info');
            }
        } catch (error) {
            this.showToast(
                this.reduceError(error) || 'Unable to search for the record. Please try again later.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleClear() {
        this.email = '';
        this.recordId = null;
        this.sessionId = null;
        this.registrationRecordId = null;
        this.registrationObj = {};
        this.registrationStatus = '';
        this.currentStep = 'initial';
        this.landingView = 'choice';
        // Legacy left a stale status banner behind after Clear.
        this.showStatusMessage = false;
        this.statusMessage = '';
    }

    handleCreateNew() {
        this.recordId = null;
        this.sessionId = null;
        this.registrationRecordId = null;
        this.registrationObj = {};
        this.registrationStatus = '';
        this.email = '';
        this.showStatusMessage = false;
        this.currentStep = '1';
    }

    handleClosePopup() {
        this.showInProgressPopup = false;
    }

    // ------------------------------------------------------------------
    // Stepper
    // ------------------------------------------------------------------

    get steps() {
        const currentIndex = parseInt(this.currentStep, 10) || 0;
        return STEP_DEFINITIONS.map((step) => {
            const stepIndex = parseInt(step.stepNumber, 10);
            const isCurrent = step.stepNumber === this.currentStep;
            const isDone = stepIndex < currentIndex;
            let className = 'stepper__item';
            if (isCurrent) className += ' stepper__item--current';
            if (isDone) className += ' stepper__item--done';
            return { ...step, isCurrent, isDone, className };
        });
    }

    get showStep1() {
        return this.currentStep === '1';
    }
    get showStep2() {
        return this.currentStep === '2';
    }
    get showStep3() {
        return this.currentStep === '3';
    }
    get showStep4() {
        return this.currentStep === '4';
    }
    get showStep5() {
        return this.currentStep === '5';
    }

    get workspaceLayerClass() {
        return this.isGuest ? 'reg-workspace-layer' : 'reg-workspace-layer reg-workspace-layer--inline';
    }

    get workspaceRole() {
        return this.isGuest ? 'dialog' : null;
    }

    get workspaceAriaModal() {
        return this.isGuest ? 'true' : null;
    }

    handleCloseWorkspace() {
        // Guests return to the landing card; progress already saved by each
        // completed step remains resumable through the search flow.
        this.currentStep = 'initial';
        // Back to the two choices rather than whichever half-finished lookup
        // the user happened to arrive through.
        this.landingView = 'choice';
        this.email = '';
    }

    handleWorkspaceKeydown(event) {
        if (event.key === 'Escape' && this.isGuest && !this.showOTPInput && !this.showInProgressPopup) {
            event.stopPropagation();
            this.handleCloseWorkspace();
        }
    }

    get nextButtonLabel() {
        return this.currentStep === '5' ? 'Submit' : 'Next';
    }

    get previousButtonLabel() {
        // Step 1's back action returns to the landing, so it reads as Cancel.
        return this.currentStep === '1' ? 'Cancel' : 'Previous';
    }

    // BP-036: set by the bank step's 'submitted' event; the footer goes away
    // with the form so nothing can be pressed behind the success screen.
    isRegistrationSubmitted = false;

    get shouldShowPreviousButton() {
        if (this.isRegistrationSubmitted) return false;
        // Legacy rule: the limited-login continuation hides Previous on step 1
        // only (there is no landing to go back to inside My Agency); steps 2-5
        // keep it so the broker can review earlier steps (client, 2026-09-08).
        return this.isGuest || this.currentStep !== '1';
    }

    /* BP-038: one lock for the whole continuation. Anything but Draft (Submitted,
       under review) is view only: Next is hidden on every step, the steps
       receive `locked` and refuse to save, Previous stays so the broker can look
       back. A new "Require more information" sets Draft again and unlocks. */
    get isLocked() {
        return !this.isGuest && Boolean(this.registrationStatus) && this.registrationStatus !== 'Draft';
    }

    get shouldShowNextButton() {
        if (this.isRegistrationSubmitted || this.isLocked) return false;
        return !(this.currentStep === '5' && this.registrationObj && this.registrationObj.Status__c === 'Submitted');
    }

    handleRegistrationSubmitted(event) {
        const detail = event.detail || {};
        if (detail.sessionId) {
            this.sessionId = detail.sessionId;
        }
        if (detail.id) {
            this.recordId = detail.id;
            this.registrationRecordId = detail.id;
        }
        this.registrationStatus = 'Submitted';
        this.registrationObj = { ...(this.registrationObj || {}), Status__c: 'Submitted' };
        this.isRegistrationSubmitted = true;
        this.isLoading = false;
    }

    get shouldShowLeftPanel() {
        return Boolean(this.taskComment && this.taskComment.trim() !== '');
    }

    get childMode() {
        // Children compute delete-icon visibility from mode === 'draft'.
        return 'draft';
    }

    handlePrevious() {
        if (this.currentStep === '1') {
            this.currentStep = 'initial';
            this.showStatusMessage = false;
        } else {
            const current = parseInt(this.currentStep, 10);
            if (current > 1) {
                this.currentStep = String(current - 1);
            }
        }
    }

    async handleNext() {
        this.isLoading = true;
        let childForm;
        if (this.currentStep === '1') {
            childForm = this.template.querySelector('c-mbpr_reg-step-company');
        } else if (this.currentStep === '2') {
            childForm = this.template.querySelector('c-mbpr_reg-step-trade-license');
        } else if (this.currentStep === '3') {
            childForm = this.template.querySelector('c-mbpr_reg-step-owners');
        } else if (this.currentStep === '4') {
            childForm = this.template.querySelector('c-mbpr_reg-step-admins');
        } else if (this.currentStep === '5') {
            childForm = this.template.querySelector('c-mbpr_reg-step-bank');
        }

        if (childForm) {
            try {
                await childForm.submitForm();
            } catch (error) {
                this.showToast(
                    (error && error.message) || 'Unable to submit the form. Please try again.',
                    'error'
                );
            } finally {
                this.isLoading = false;
            }
        } else {
            this.isLoading = false;
            this.showToast('Form not found. Please try again or contact support.', 'error');
        }
    }

    handleFormSuccess(event) {
        const detail = event.detail || {};
        // Steps 1/2/5 emit {id}; steps 3/4 emit {ids:[...]} - accept both.
        const detailId = detail.id != null ? detail.id : Array.isArray(detail.ids) ? detail.ids[0] : undefined;
        const current = parseInt(this.currentStep, 10);

        if (detail.sessionId) {
            this.sessionId = detail.sessionId;
        }

        if (this.currentStep === '3' || this.currentStep === '4') {
            if (detailId != null) {
                this.registrationAgentrecordId = detailId;
            }
        } else if (detailId != null) {
            this.recordId = detailId;
            this.registrationRecordId = detailId;
        }
        this.moveToNextStep(current);
        this.isLoading = false;
    }

    moveToNextStep(current) {
        if (current === 5) {
            this.showStatusMessage = false;
            this.showToast('Registration process completed!', 'success');
            if (this.isGuest) {
                this.currentStep = 'initial';
                this.recordId = null;
                this.sessionId = null;
                this.registrationRecordId = null;
                this.registrationObj = {};
                this.registrationStatus = '';
                this.email = '';
            }
            this.dispatchEvent(new CustomEvent('registrationcomplete'));
        } else if (current < 5) {
            this.currentStep = String(current + 1);
        }
    }

    handleFormError(event) {
        this.showToast(
            (event.detail && event.detail.message) ||
                'Unable to load or save the record. Please verify your input and try again.',
            'error'
        );
        this.isLoading = false;
    }

    handleChildToast(event) {
        const { message, variant } = event.detail || {};
        if (message) {
            this.showToast(message, variant || 'info');
        }
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    reduceError(error) {
        if (!error) return '';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (typeof error.body.message === 'string') return error.body.message;
            if (Array.isArray(error.body) && error.body.length && error.body[0].message) {
                return error.body[0].message;
            }
        }
        return error.message || '';
    }

    showToast(message, variant) {
        try {
            Toast.show({ label: message, mode: 'dismissible', variant }, this);
        } catch (toastError) {
            this.dispatchEvent(new ShowToastEvent({ title: '', message, mode: 'dismissible', variant }));
        }
    }
}