import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference }        from 'lightning/navigation';
import { NavigationMixin }            from 'lightning/navigation';
import { encodeDefaultFieldValues }   from 'lightning/pageReferenceUtils';
import isApiEnabled  from '@salesforce/apex/LeadVerificationController.isApiEnabled';
import validateEmail from '@salesforce/apex/LeadVerificationController.validateEmail';
import validatePhone from '@salesforce/apex/LeadVerificationController.validatePhone';

const DEBOUNCE = 600;

export default class LeadVerification extends NavigationMixin(LightningElement) {

    @track phone          = '';
    @track email          = '';
    @track phoneVerifying = false;
    @track emailVerifying = false;
    @track phoneResult    = null;
    @track emailResult    = null;
    @track apiActive      = true;

    _phoneTimer;
    _emailTimer;

    @wire(isApiEnabled)
    wiredApi({ data, error }) {
        if (data !== undefined) this.apiActive = data;
        if (error)              this.apiActive = false;
    }

    // Fires every time user opens the popup — even from cache
    // This is the correct Salesforce way to detect re-navigation
    @wire(CurrentPageReference)
    pageRefChanged(pageRef) {
        if (pageRef) {
            this.resetFields();
        }
    }

    // Reset all fields every time the component opens
    connectedCallback() {
        this.resetFields();
    }

    // Public method — called by Aura wrapper on every open
    @api
    resetFields() {
        // Reset tracked properties
        this.phone          = '';
        this.email          = '';
        this.phoneResult    = null;
        this.emailResult    = null;
        this.phoneVerifying = false;
        this.emailVerifying = false;
        clearTimeout(this._phoneTimer);
        clearTimeout(this._emailTimer);

        // Also imperatively clear the lightning-input elements
        // because they cache displayed values independently
        const inputs = this.template.querySelectorAll('lightning-input');
        if (inputs) {
            inputs.forEach(input => {
                input.value = '';
            });
        }
    }

   onPhoneChange(e) {
    // Remove all whitespace and non-digit/non-plus characters immediately
    const clean = (e.detail.value || '').replace(/\s/g, '').replace(/[^+\d]/g, '');
    
    // Update the tracked property and the input value manually to sync the UI
    this.phone = clean;
    e.target.value = clean; 

    this.phoneResult = null;
    clearTimeout(this._phoneTimer);

    if (this.phone) {
        this._phoneTimer = setTimeout(() => this.runPhoneVerify(), DEBOUNCE);
    }
}

    onPhoneKeyPress(e) {
        if (!/[0-9+\s\-()]/.test(e.key) && e.key.length === 1) {
            e.preventDefault();
        }
    }

    onEmailChange(e) {
        this.email       = e.detail.value;
        this.emailResult = null;
        clearTimeout(this._emailTimer);
        if (this.email) {
            this._emailTimer = setTimeout(() => this.runEmailVerify(), DEBOUNCE);
        }
    }

    runPhoneVerify() {
        if (!this.phone) return;
        if (!this.phone.startsWith('+')) {
            this.phoneResult = { isValid: false, formatError: true };
            return;
        }
        if (!this.apiActive) {
            this.phoneResult = { isValid: true, apiSkipped: true };
            return;
        }
        this.phoneVerifying = true;
        validatePhone({ phone: this.phone })
            .then(r => {
                this.phoneResult = r.apiSkipped ? { isValid: false, apiError: true } : r;
            })
            .catch(() => { this.phoneResult = { isValid: false, apiError: true }; })
            .finally(() => { this.phoneVerifying = false; });
    }

    runEmailVerify() {
        if (!this.email) return;
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.email)) {
            this.emailResult = { isValid: false, formatError: true };
            return;
        }
        if (!this.apiActive) {
            this.emailResult = { isValid: true, apiSkipped: true };
            return;
        }
        this.emailVerifying = true;
        validateEmail({ email: this.email })
            .then(r => {
                this.emailResult = r.apiSkipped ? { isValid: false, apiError: true } : r;
            })
            .catch(() => { this.emailResult = { isValid: false, apiError: true }; })
            .finally(() => { this.emailVerifying = false; });
    }

    // Cancel — navigate back to Lead list view
    // CloseActionScreenEvent does not work in Aura action override
    // NavigationMixin to Lead home is the reliable approach
    onCancel() {
        this[NavigationMixin.Navigate]({
            type      : 'standard__objectPage',
            attributes: {
                objectApiName: 'Lead',
                actionName   : 'home'
            }
        });
    }

    // Continue button — navigates to standard Lead new page with pre-filled values
    onContinue() {
        if (this.continueDisabled) return;

        this[NavigationMixin.Navigate]({
            type      : 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'new' },
            state     : {
                defaultFieldValues: encodeDefaultFieldValues({
                    Email            : this.email.trim(),
                    MobilePhone      : this.phone.trim(),
                    En_Email__c      : this.email.trim(),
                    En_MobilePhone__c: this.phone.trim()
                }),
                nooverride: '1'
            }
        }, true); // replace:true prevents back-button loading cached LWC state

    }

    get progressPercent() {
        let p = 0;
        if (this.emailResult?.isValid) p += 50;
        if (this.phoneResult?.isValid) p += 50;
        return p;
    }
    get progressStyle()  { return 'width:' + this.progressPercent + '%'; }
    get progressLabel() {
        if (this.progressPercent === 100) return '100% — ready to continue!';
        if (this.progressPercent === 0)   return '0% — fill in your details';
        return this.progressPercent + '% verified';
    }
    get progressLabelClass() {
        return this.progressPercent === 100
            ? 'lv-progress-label lv-progress-label--done'
            : 'lv-progress-label';
    }
    get allVerified()      { return !!(this.phoneResult?.isValid && this.emailResult?.isValid); }
    get continueDisabled() { return !this.allVerified; }
    get phoneDone()        { return !!this.phoneResult; }
    get emailDone()        { return !!this.emailResult; }
    get phoneInputClass() {
        const r = this.phoneResult;
        if (r?.isValid && !r.formatError) return 'lv-input-outer is-valid';
        if (r && !r.isValid)              return 'lv-input-outer is-invalid';
        return 'lv-input-outer';
    }
    get emailInputClass() {
        const r = this.emailResult;
        if (r?.isValid)      return 'lv-input-outer is-valid';
        if (r && !r.isValid) return 'lv-input-outer is-invalid';
        return 'lv-input-outer';
    }
    get phoneCheckClass() {
        return this.phoneResult && !this.phoneResult.isValid
            ? 'lv-check lv-check--invalid' : 'lv-check lv-check--valid';
    }
    get emailCheckClass() {
        return this.emailResult && !this.emailResult.isValid
            ? 'lv-check lv-check--invalid' : 'lv-check lv-check--valid';
    }
    get phoneStatusClass() {
        const r = this.phoneResult;
        if (!r) return '';
        if (r.formatError || r.apiError || !r.isValid) return 'lv-status lv-status--fail';
        if (r.apiSkipped)                              return 'lv-status lv-status--skip';
        return 'lv-status lv-status--ok';
    }
    get emailStatusClass() {
        const r = this.emailResult;
        if (!r) return '';
        if (r.formatError || r.apiError || !r.isValid) return 'lv-status lv-status--fail';
        if (r.apiSkipped)                              return 'lv-status lv-status--skip';
        return 'lv-status lv-status--ok';
    }
    get phoneStatusText() {
        const r = this.phoneResult;
        if (!r) return '';
        if (r.formatError) return 'Must start with + and country code (e.g. +971*********)';
        if (r.apiError)    return 'Could not reach validation service — please try again';
        if (r.apiSkipped)  return 'Validation skipped — you can still proceed';
        return r.isValid ? 'Mobile number verified successfully' : 'Invalid mobile number — please check and try again';
    }
    get emailStatusText() {
        const r = this.emailResult;
        if (!r) return '';
        if (r.formatError) return 'Please enter a valid email address (e.g. name@domain.com)';
        if (r.apiError)    return 'Could not reach validation service — please try again';
        if (r.apiSkipped)  return 'Validation skipped — you can still proceed';
        return r.isValid ? 'Email address verified successfully' : 'Invalid email address — please check and try again';
    }
    get continueBtnClass() {
        return this.allVerified
            ? 'lv-btn-continue lv-btn-continue--ready'
            : 'lv-btn-continue';
    }
}