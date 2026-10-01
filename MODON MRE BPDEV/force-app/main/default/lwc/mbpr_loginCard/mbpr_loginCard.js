import { LightningElement, api } from 'lwc';

export default class MbprLoginCard extends LightningElement {
    @api view = 'login';
    @api username = '';
    @api password = '';
    @api resetUsername = '';
    @api otpCode = '';
    @api otpSentEmailAddress = '';
    @api otpCounter = 0;
    @api canResendOtp = false;
    @api privacyAccepted = false;
    @api privacyUrl = '';
    @api registrationUrl = '';
    /* Both entry points hit the same page; ?resume=1 opens the Trade License
       lookup instead of the choice screen. */
    @api resumeUrl = '';
    @api loading = false;
    @api feedbackMessage = '';
    @api feedbackVariant = 'info';

    showPassword = false;

    get isLoginView() {
        return this.view === 'login';
    }

    get isResetView() {
        return this.view === 'reset';
    }

    get isOtpView() {
        return this.view === 'otp';
    }

    get viewEyebrow() {
        if (this.isLoginView) {
            return '';
        }
        if (this.isResetView) {
            return 'Account recovery';
        }
        if (this.isOtpView) {
            return 'Secure verification';
        }
        return 'Welcome back';
    }

    get viewTitle() {
        if (this.isResetView) {
            return 'Reset password';
        }
        if (this.isOtpView) {
            return 'Enter OTP';
        }
        return 'Sign in';
    }

    get viewDescription() {
        if (this.isLoginView) {
            return '';
        }
        if (this.isResetView) {
            return '';
        }
        if (this.isOtpView) {
            return 'Complete the second step to access your workspace.';
        }
        return 'Use your registered username and password to continue.';
    }

    get hasViewEyebrow() {
        return Boolean(this.viewEyebrow);
    }

    get hasViewDescription() {
        return Boolean(this.viewDescription);
    }

    get hasFeedback() {
        return Boolean(this.feedbackMessage);
    }

    get feedbackClass() {
        return `feedback feedback--${this.feedbackVariant || 'info'}`;
    }

    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }

    get passwordToggleIcon() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }

    get passwordToggleLabel() {
        return this.showPassword ? 'Hide password' : 'Show password';
    }

    get signInDisabled() {
        return this.loading || !this.privacyAccepted;
    }

    get signInLabel() {
        return this.loading ? 'Checking access…' : 'Sign In';
    }

    get resetLabel() {
        return this.loading ? 'Sending…' : 'Send reset link';
    }

    get verifyLabel() {
        return this.loading ? 'Verifying…' : 'Verify and sign in';
    }

    get otpHelpText() {
        if (this.otpSentEmailAddress) {
            return `A 6-digit code was sent to ${this.otpSentEmailAddress}.`;
        }
        return 'A 6-digit code was sent to your registered email.';
    }

    get otpCooldownText() {
        if (this.otpCounter > 0) {
            return `You can request a new code in ${this.otpCounter} second(s).`;
        }
        return 'Did not receive it? Request a new secure code.';
    }

    get resendDisabled() {
        return this.loading || !this.canResendOtp;
    }

    get resendLabel() {
        return this.otpCounter > 0 ? `Resend in ${this.otpCounter}s` : 'Resend code';
    }

    handleInput(event) {
        this.dispatchFieldChange(event.target.dataset.field, event.target.value);
    }

    handleCheckbox(event) {
        this.dispatchFieldChange(event.target.dataset.field, event.target.checked);
    }

    handleOtpInput(event) {
        const value = event.target.value.replace(/\D/g, '').slice(0, 6);
        event.target.value = value;
        this.dispatchFieldChange(event.target.dataset.field, value);
    }

    togglePassword() {
        this.showPassword = !this.showPassword;
    }

    showReset(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('showreset'));
    }

    backToLogin(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('backlogin'));
    }

    submitLogin(event) {
        event.preventDefault();
        this.dispatchEvent(
            new CustomEvent('login', {
                detail: {
                    username: this.username,
                    password: this.password,
                    privacyAccepted: this.privacyAccepted
                }
            })
        );
    }

    submitReset(event) {
        event.preventDefault();
        this.dispatchEvent(
            new CustomEvent('resetrequest', {
                detail: {
                    resetUsername: this.resetUsername
                }
            })
        );
    }

    submitOtp(event) {
        event.preventDefault();
        this.dispatchEvent(
            new CustomEvent('verifyotp', {
                detail: {
                    otpCode: this.otpCode
                }
            })
        );
    }

    resendOtp(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('resendotp'));
    }

    dispatchFieldChange(field, value) {
        this.dispatchEvent(
            new CustomEvent('fieldchange', {
                detail: {
                    field,
                    value
                }
            })
        );
    }
}