import { LightningElement, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import THEME_ALIGNMENT from '@salesforce/resourceUrl/mbprThemeAlignment';

import doLogin from '@salesforce/apex/MBP_CommunityAuthController.doLogin';
import startLoginWithOTP from '@salesforce/apex/MBP_CommunityAuthController.startLoginWithOTP';
import verifyOTPOnly from '@salesforce/apex/MBP_CommunityAuthController.verifyOTPOnly';
import forgotPassword from '@salesforce/apex/MBP_CommunityAuthController.forgotPassword';

import privacypol from '@salesforce/label/c.MBP_privacypol';
import Termsandcondtions from '@salesforce/label/c.MBP_TermsandConditions';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_COOLDOWN_SECONDS = 60;

export default class MbprLoginFlow extends LightningElement {
    @api brandLabel = 'Broker Portal';
    @api startUrl = '/';
    @api registrationPath = '/Brokers/SelfRegister';

    termsandcondtions = Termsandcondtions;
    privacyPolicyUrl = privacypol;
    currentYear = new Date().getFullYear();

    view = 'login';
    username = '';
    password = '';
    resetUsername = '';
    otpCode = '';
    otpSentEmailAddress = '';
    otpCounter = 0;
    privacyAccepted = false;
    loading = false;
    feedbackMessage = '';
    feedbackVariant = 'info';
    otpTimer;

    get registrationUrl() {
        return this.resolveUrl(this.registrationPath || '/Brokers/SelfRegister');
    }

    /* Same registration page, opened on the resume lookup. Appends correctly
       whether or not the path already has a query string. */
    get resumeUrl() {
        const base = this.registrationUrl;
        return `${base}${base.includes('?') ? '&' : '?'}resume=1`;
    }

    get canResendOtp() {
        return !this.loading && this.otpCounter <= 0;
    }

    _prevRootBg = '';
    _prevBodyBg = '';
    _prevRootScrollbar = '';

    connectedCallback() {
        loadStyle(this, THEME_ALIGNMENT).catch(() => {});
        this.paintDocumentCanvas(true);
    }

    disconnectedCallback() {
        this.clearOtpTimer();
        this.paintDocumentCanvas(false);
    }

    /* Windows leaves a white hairline along the viewport's bottom edge: the
       site canvas shows through this fixed dark shell at fractional scaling,
       and the document scrollbar tracks render light. Done in JS because the
       :has() CSS version is dropped on Firefox <121. Restored on disconnect
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
            // Best effort; the stylesheet fallbacks still apply.
        }
    }


    handleFieldChange(event) {
        const { field, value } = event.detail || {};
        if (!field) {
            return;
        }

        if (field === 'username') {
            this.username = value;
        } else if (field === 'password') {
            this.password = value;
        } else if (field === 'resetUsername') {
            this.resetUsername = value;
        } else if (field === 'otpCode') {
            this.otpCode = value;
        } else if (field === 'privacyAccepted') {
            this.privacyAccepted = Boolean(value);
        }
    }

    handleShowReset() {
        if (this.loading) {
            return;
        }
        this.view = 'reset';
        this.resetUsername = this.username;
        this.clearFeedback();
        this.clearOtpState();
    }

    handleBackToLogin() {
        if (this.loading) {
            return;
        }
        this.view = 'login';
        this.resetUsername = '';
        this.otpCode = '';
        this.clearFeedback();
        this.clearOtpState();
    }

    async handleLogin(event) {
        event?.preventDefault();
        const detail = event.detail || {};
        this.username = (detail.username ?? this.username).trim();
        this.password = detail.password ?? this.password;
        this.privacyAccepted = Boolean(detail.privacyAccepted ?? this.privacyAccepted);

        if (this.loading) {
            return;
        }
        if (!this.validateLoginInput()) {
            return;
        }

        this.loading = true;
        this.clearFeedback();

        try {
            const result = await startLoginWithOTP({
                username: this.username,
                password: this.password
            });

            if (result?.startsWith('SUCCESS:OTP sent to')) {
                this.otpSentEmailAddress = result.replace('SUCCESS:OTP sent to ', '').trim();
                this.otpCode = '';
                this.view = 'otp';
                this.startOtpCooldown();
                this.setFeedback('success', 'A secure code has been sent to your registered email.');
                this.loading = false;
                return;
            }

            if (result === 'SUCCESS:OTP not required, login allowed') {
                await this.completeLogin();
                return;
            }

            this.loading = false;
            this.setFeedback('error', this.getSafeLoginMessage(result));
        } catch {
            this.loading = false;
            this.setFeedback('error', 'We could not sign you in right now. Please try again.');
        }
    }

    async handleVerifyOtp(event) {
        event?.preventDefault();
        const detail = event.detail || {};
        this.otpCode = (detail.otpCode ?? this.otpCode).trim();

        if (this.loading) {
            return;
        }
        if (!/^\d{6}$/.test(this.otpCode)) {
            this.setFeedback('error', 'Enter the 6-digit code sent to your registered email.');
            return;
        }

        this.loading = true;
        this.clearFeedback();

        try {
            const result = await verifyOTPOnly({
                username: this.username,
                otp: this.otpCode
            });

            if (result === 'OTP Verified') {
                await this.completeLogin();
                return;
            }

            this.loading = false;
            this.setFeedback('error', 'The code could not be verified. Check the code and try again.');
        } catch {
            this.loading = false;
            this.setFeedback('error', 'OTP verification failed. Please try again.');
        }
    }

    async handleResendOtp() {
        if (this.loading || this.otpCounter > 0) {
            return;
        }
        if (!this.username || !this.password) {
            this.view = 'login';
            this.setFeedback('error', 'Please sign in again to request a new code.');
            return;
        }

        this.loading = true;
        this.clearFeedback();

        try {
            const result = await startLoginWithOTP({
                username: this.username,
                password: this.password
            });

            if (result?.startsWith('SUCCESS:OTP sent to')) {
                this.otpSentEmailAddress = result.replace('SUCCESS:OTP sent to ', '').trim();
                this.otpCode = '';
                this.startOtpCooldown();
                this.setFeedback('success', 'A new secure code has been sent.');
                this.loading = false;
                return;
            }

            if (result === 'SUCCESS:OTP not required, login allowed') {
                await this.completeLogin();
                return;
            }

            this.loading = false;
            this.setFeedback('error', this.getSafeLoginMessage(result));
        } catch {
            this.loading = false;
            this.setFeedback('error', 'We could not send a new code right now. Please try again.');
        }
    }

    async handleResetRequest(event) {
        event?.preventDefault();
        const detail = event.detail || {};
        this.resetUsername = (detail.resetUsername ?? this.resetUsername).trim();

        if (this.loading) {
            return;
        }
        if (!this.resetUsername) {
            this.setFeedback('error', 'Enter your username to request reset instructions.');
            return;
        }

        this.loading = true;
        this.clearFeedback();

        try {
            await forgotPassword({ userid: this.resetUsername });
            this.setFeedback(
                'success',
                'If the username is eligible, password reset instructions will be sent to the registered email.'
            );
        } catch {
            this.setFeedback('error', 'We could not process the reset request right now. Please try again.');
        } finally {
            this.loading = false;
        }
    }

    validateLoginInput() {
        if (!this.username || !EMAIL_PATTERN.test(this.username)) {
            this.setFeedback('error', 'Enter a valid email-format username.');
            return false;
        }
        if (!this.password) {
            this.setFeedback('error', 'Enter your password.');
            return false;
        }
        if (!this.privacyAccepted) {
            this.setFeedback('error', 'Accept the privacy policy before signing in.');
            return false;
        }
        return true;
    }

    async completeLogin() {
        try {
            const loginUrl = await doLogin({
                username: this.username,
                password: this.password,
                startUrl: this.startUrl || '/'
            });

            if (loginUrl) {
                window.location.href = loginUrl;
                return;
            }

            this.loading = false;
            this.setFeedback('error', 'We could not complete sign in. Please try again.');
        } catch (error) {
            this.loading = false;
            const message = error?.body?.message || error?.message || '';
            if (message.toLowerCase().includes('frozen')) {
                this.setFeedback('error', 'This account is temporarily unavailable. Contact Modon support.');
                return;
            }
            this.setFeedback('error', 'We could not sign you in. Check your username and password, then try again.');
        }
    }

    getSafeLoginMessage(result) {
        const message = String(result || '').replace(/^ERROR:/, '').trim().toLowerCase();
        if (message.includes('frozen')) {
            return 'This account is temporarily unavailable. Contact Modon support.';
        }
        return 'We could not sign you in. Check your username and password, then try again.';
    }

    startOtpCooldown() {
        this.clearOtpTimer();
        this.otpCounter = OTP_COOLDOWN_SECONDS;
        this.otpTimer = window.setInterval(() => {
            this.otpCounter -= 1;
            if (this.otpCounter <= 0) {
                this.clearOtpTimer();
            }
        }, 1000);
    }

    clearOtpState() {
        this.clearOtpTimer();
        this.otpCounter = 0;
        this.otpSentEmailAddress = '';
    }

    clearOtpTimer() {
        if (this.otpTimer) {
            window.clearInterval(this.otpTimer);
            this.otpTimer = undefined;
        }
    }

    setFeedback(variant, message) {
        this.feedbackVariant = variant;
        this.feedbackMessage = message;
    }

    clearFeedback() {
        this.feedbackMessage = '';
        this.feedbackVariant = 'info';
    }

    resolveUrl(value) {
        if (!value) {
            return '';
        }
        try {
            return new URL(value, window.location.origin).href;
        } catch {
            return value;
        }
    }
}