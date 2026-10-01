import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";
import brokerPortalCssFile from "@salesforce/resourceUrl/brokerPortalCssFile";
import doLogin from '@salesforce/apex/MBP_CommunityAuthController.doLogin';
import startLoginWithOTP from '@salesforce/apex/MBP_CommunityAuthController.startLoginWithOTP';
import verifyOTPOnly from '@salesforce/apex/MBP_CommunityAuthController.verifyOTPOnly';
import forgotPassword from '@salesforce/apex/MBP_CommunityAuthController.forgotPassword';

import instagramUrl from '@salesforce/label/c.MBP_Instagramlink';
import youtubeUrl from '@salesforce/label/c.MBP_YoutubeLink';
import facebookUrl from '@salesforce/label/c.MBP_Facebooklink';
import xUrl from '@salesforce/label/c.MBP_Xlink';
import linkedInUrl from '@salesforce/label/c.MBP_LinkedInlink';
import privacypol from '@salesforce/label/c.MBP_privacypol';
import Termsandcondtions from '@salesforce/label/c.MBP_TermsandConditions';
export default class AgencyLoginScreen extends LightningElement {
    termsandcondtions=Termsandcondtions;
    logo = ModonImages + "/modonImages/brand-logo-black.png";
    logowhite = ModonImages + "/modonImages/brand-logo-white.png";
    backgroundImage = ModonImages + "/modonImages/bg-theme-pic.png";
    instagramUrl = instagramUrl;
    youtubeUrl = youtubeUrl;
    facebookUrl = facebookUrl;
    xUrl = xUrl;
    linkedInUrl = linkedInUrl;
    privacyPolicyUrl = privacypol;
    @track showCustomToast = false;
    @track toastMessage = '';
    @track toastVariant = '';

    @track showLoginForm = true;
    @track showResetForm = false;
    @track showEnterOTPForm = false;

    @track resetUsername = '';
    @track username = '';
    @track password = '';
    @track enteredOTP = '';
    @track errorMessage = '';
    @track showSpinner = false;
    @track disableButton = false;
    @track isChecked = false;
    @track selfRegistrationUrl;
    @track resumeRegistrationUrl;
    @track enteredOtp = ''; // This holds the OTP

    get backgroundStyle() {
        return `background-image: url('${this.backgroundImage}'); background-size: cover; background-repeat: no-repeat; background-position: center;`;
    }

    connectedCallback() {
        Promise.all([
            loadStyle(this, Bootstrap + '/css/bootstrap.min.css'),
            loadScript(this, Bootstrap + '/js/bootstrap.bundle.min.js')
        ])
        .catch(error => {
            console.error(' Error loading styles', error);
        });
        const baseUrl = window.location.origin;
        this.selfRegistrationUrl   = `${baseUrl}/Brokers/SelfRegister?action=new`;
        this.resumeRegistrationUrl = `${baseUrl}/Brokers/SelfRegister?action=resume`;
    }

    keyCheck(event) {
        if (event.which === 13) {
            this.handleLogin();
        }
    }

    handleOtpChange(event) {
        this.enteredOtp = event.target.value?.trim();
    }

    handleCheckboxChange(event) {
        this.isChecked = event.target.checked;
    }

    get disableSignInButton() {
        return !this.isChecked; // Disable when not checked
    }

    handleUsernameChange(event) {
        this.username = event.target.value;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    get signInButtonStyle() {
        return `background-color: ${this.isChecked ? 'black' : 'grey'}; color: white; cursor: ${this.isChecked ? 'pointer' : 'not-allowed'};`;
    }

    handleLogin(event) {
        event?.preventDefault();
        this.disableButton = true;

        if (this.handleEmailValidation()) {
            this.showSpinner = true;

            let emailVal = this.template.querySelector('[data-id="txtEmailAddress"]');
            let passwordVal = this.template.querySelector('[data-id="txtPassword"]');

            this.username = emailVal.value.trim();
            this.password = passwordVal.value;

            if (this.username && this.password) {
                startLoginWithOTP({ username: this.username, password: this.password })
                    .then(result => {
                        this.showSpinner = false;

                        if (result.startsWith('SUCCESS:OTP sent to')) {
                            const email = result.replace('SUCCESS:OTP sent to ', '');
                            this.otpSentEmailAddress = email;
                            this.showLoginForm = false;
                            this.showEnterOTPForm = true;
                            this.showToast('success', 'OTP sent to your email.');
                        } else if (result === 'SUCCESS:OTP not required, login allowed') {
                            this.showSpinner = true;
                            return doLogin({ username: this.username, password: this.password, startUrl: '/' })
                                .then(loginUrl => {
                                    window.location.href = loginUrl;
                                })
                                .catch(err => {
                                    this.showSpinner = false;
                                    this.showToast('error', 'Login failed.');
                                });
                        } else if (result.startsWith('ERROR:')) {
                            const errorMsg = result.replace('ERROR:', '');
                            this.showToast('error', errorMsg);
                        } else {
                            this.showToast('error', 'Unexpected response from server.');
                        }
                    })
                    .catch(error => {
                        this.showSpinner = false;
                        this.showToast('error', 'Server error occurred.');
                    });
            }
        }

        this.disableButton = false;
    }

    handleVerifyOTP(event) {
        event?.preventDefault();
        this.disableButton = true;

        if (!this.enteredOtp || this.enteredOtp.length !== 6 || isNaN(this.enteredOtp)) {
            this.showToast('error', 'Please enter a valid 6-digit OTP.');
            this.disableButton = false;
            return;
        }

        this.showSpinner = true;

        verifyOTPOnly({ username: this.username, otp: this.enteredOtp })
            .then(result => {
                if (result === 'OTP Verified') {
                    return doLogin({ username: this.username, password: this.password, startUrl: '/' });
                } else {
                    throw new Error(result);
                }
            })
            .then(loginUrl => {
                this.showSpinner = false;
                window.location.href = loginUrl;
            })
            .catch(error => {
                this.showSpinner = false;
                const msg = error.body?.message || error.message || 'OTP verification or login failed.';
                this.showToast('error', msg);
            });

        this.disableButton = false;
    }

    showHideEnterOTPForm() {
        this.showEnterOTPForm = false;
        this.showLoginForm = true;
        this.enteredOTP = '';
    }

    handleForgotPasswordClick() {
        this.showLoginForm = false;
        this.showResetForm = true;
        this.resetUsername = '';
    }

    handleResetUsernameChange(event) {
        this.resetUsername = event.target.value.trim();
    }

    handleSendResetLink(event) {
        event.preventDefault();

        if (!this.resetUsername) {
            this.showToast('error', 'Please enter your username.');
            return;
        }

        this.showSpinner = true;

        forgotPassword({ userid: this.resetUsername })
            .then(result => {
                if (result === 'LoginResetSuccess') {
                    this.showToast('warning', 'Reset password link sent to your email.');
                } else if (result === 'LoginResetWarning') {
                    this.showToast('warning', 'Username is not a valid community user.');
                } else {
                    this.showToast('error', result);
                }
            })
            .catch(error => {
                this.showToast('error', 'Something went wrong while sending reset link.');
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    handleBackToLogin() {
        this.resetUsername = '';
        this.showResetForm = false;
        this.showLoginForm = true;
    }

    get toastClass() {
        return `modon-toast ${this.toastVariant}`;
    }

    handleEmailValidation() {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        let email = this.template.querySelector('[data-id="txtEmailAddress"]');
        let emailVal = email.value.trim();

        if (emailVal.match(emailRegex)) {
            email.setCustomValidity('');
            email.reportValidity();
            return true;
        } else {
            email.setCustomValidity('Please enter a valid email');
            email.reportValidity();
            return false;
        }
    }

    showToast(variant, message) {
        this.toastMessage = message;
        this.toastVariant = variant; // success, error, warning
        this.showCustomToast = true;

        setTimeout(() => {
            this.showCustomToast = false;
        }, 3000);
    }
}