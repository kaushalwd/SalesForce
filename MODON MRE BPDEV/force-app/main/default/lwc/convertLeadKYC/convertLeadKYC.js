// convertLeadKYC.js  — wire-based version (pre-payload refactor)
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }          from 'lightning/platformShowToastEvent';
import { NavigationMixin }         from 'lightning/navigation';
import { CloseActionScreenEvent }  from 'lightning/actions';
import { refreshApex }             from '@salesforce/apex';

import getLeadKYCState            from '@salesforce/apex/ConvertLeadProcessMRE.getLeadKYCState';
import findMatchingPersonAccounts  from '@salesforce/apex/ConvertLeadProcessMRE.findMatchingPersonAccounts';
import findMatchingOrgAccount      from '@salesforce/apex/ConvertLeadProcessMRE.findMatchingOrgAccount';
import submitException             from '@salesforce/apex/ConvertLeadProcessMRE.submitException';
import convertLead                 from '@salesforce/apex/ConvertLeadProcessMRE.convertLead';

export default class ConvertLeadKYC extends NavigationMixin(LightningElement) {

    @api recordId;

    @track isLoading          = true;
    @track isConverting       = false;
    @track isSaving           = false;
    @track state              = {};
    @track accounts           = [];
    @track orgMatch           = null;
    @track selectedAccountId  = null;
    @track showSelectionError = false;
    @track showExceptionForm  = false;
    @track exceptionReason    = '';

    _stateWire;
    _matchesWire;

    // ── Wire ─────────────────────────────────────────────────────────────────

    @wire(getLeadKYCState, { leadId: '$recordId' })
    wiredState(result) {
        this._stateWire = result;
        if (result.data) {
            this.state             = result.data;
            this.selectedAccountId = result.data.existingAccountId || null;
            this.isLoading         = false;
        } else if (result.error) {
            this._toast('Error', result.error?.body?.message || 'Failed to load lead.', 'error');
            this.isLoading = false;
        }
    }

    @wire(findMatchingPersonAccounts, { leadId: '$recordId' })
    wiredMatches(result) {
        this._matchesWire = result;
        if (result.data) {
            this.accounts  = result.data;
            this.isLoading = false;
        }
    }

    @wire(findMatchingOrgAccount, { leadId: '$recordId' })
    wiredOrgMatch(result) {
        if (result.data) {
            this.orgMatch = result.data;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get isPendingApproval()   { return this.state.exceptionStatus === 'Pending Approval'; }
    get isRejected()          { return this.state.exceptionStatus === 'Rejected'; }
    get isExceptionApproved() { return this.state.exceptionStatus === 'Approved'; }

    get alreadyMapped() {
        // Person leads only — org account scenarios are fully handled by Case 3 (isOrgAccount)
        if (!this.state.isOrgAccount
            && !!this.state.existingAccountId
            && this.state.exceptionStatus !== 'Approved') return true;
        return false;
    }

    get showMainPanel() {
        return !this.isLoading
            && !this.state.isConverted
            && !this.isPendingApproval
            && !this.isRejected;
    }

    get hasMatches() {
        return !this.state.isOrgAccount
            && !this.isExceptionApproved
            && !this.alreadyMapped
            && this.accounts
            && this.accounts.length > 0;
    }

    get noMatches() {
        return !this.state.isOrgAccount
            && !this.isExceptionApproved
            && !this.alreadyMapped
            && (!this.accounts || this.accounts.length === 0);
    }

    get matchCountLabel() {
        const n = this.accounts ? this.accounts.length : 0;
        return `${n} matching account${n === 1 ? '' : 's'} found`;
    }

    get orgSummaryClass() {
        return this.orgMatch ? 'cvt-summary cvt-summary--ok' : 'cvt-summary cvt-summary--neutral';
    }

    get orgIconClass() {
        return this.orgMatch
            ? 'cvt-summary-icon cvt-summary-icon--ok'
            : 'cvt-summary-icon cvt-summary-icon--neutral';
    }

    get willReuseAccount() {
        return this.alreadyMapped || (this.state.isOrgAccount && !!this.orgMatch);
    }

    get summaryTitle() {
        if (this.state.isOrgAccount && this.orgMatch) return 'Existing organisation account found';
        if (this.state.isOrgAccount) return 'Organisation account lead — no match found';
        if (this.willReuseAccount)   return 'Existing account will be reused';
        return 'New account will be created';
    }

    get summarySub() {
        if (this.state.isOrgAccount && this.orgMatch)
            return `Matched on Unified Number: ${this.orgMatch.unifiedNumber}. This account will be reused — no duplicate created.`;
        if (this.state.isOrgAccount)
            return 'No matching organisation account found. A new account will be created on conversion.';
        if (this.alreadyMapped)
            return 'The mapped account will be used on conversion. No duplicate account will be created.';
        if (this.state.exceptionStatus === 'Approved')
            return 'Exception approved — a new person account will be created on conversion.';
        return 'No matching account was found. A new person account will be created automatically.';
    }

    get orgTradeLicenseDisplay() {
        return (this.orgMatch && this.orgMatch.tradeLicenseNumber) || '—';
    }

    get orgMobileDisplay() {
        return this._maskMobile(this.orgMatch && this.orgMatch.mobile);
    }

    get orgEmailDisplay() {
        return this._maskEmail(this.orgMatch && this.orgMatch.email);
    }

    get enrichedAccounts() {
        return (this.accounts || []).map((acc, idx) => {
            const isSelected = acc.accountId === this.selectedAccountId;
            return {
                ...acc,
                radioId:              `cvt-radio-${idx}`,
                isSelected,
                cardClass:            `cvt-acc-card${isSelected ? ' cvt-acc-card--sel' : ''}`,
                eidDisplay:           acc.eidNumber      || '—',
                passportDisplay:      acc.passportNumber || '—',
                emailDisplay:         this._maskEmail(acc.email),
                mobileDisplay:        this._maskMobile(acc.mobile),
                createdDateFormatted: acc.createdDate
                    ? new Date(acc.createdDate).toLocaleDateString('en-GB',
                        { day: '2-digit', month: 'short', year: 'numeric' })
                    : '—'
            };
        });
    }

    // ── Masking helpers — display only, never affects matching logic ──────────

    _maskEmail(email) {
        if (!email) return '—';
        const atIndex = email.indexOf('@');
        if (atIndex <= 0) return email;
        const local  = email.substring(0, atIndex);
        const domain = email.substring(atIndex); // includes '@'
        if (local.length <= 2) {
            return local.charAt(0) + '*'.repeat(Math.max(local.length - 1, 1)) + domain;
        }
        return local.substring(0, 2) + '*'.repeat(local.length - 2) + domain;
    }

    _maskMobile(mobile) {
        if (!mobile) return '—';
        const str     = String(mobile);
        const hasPlus = str.startsWith('+');
        const digits  = hasPlus ? str.substring(1) : str;
        if (digits.length <= 3) return (hasPlus ? '+' : '') + '*'.repeat(digits.length);
        const visible = digits.slice(-3);
        const masked  = '*'.repeat(digits.length - 3);
        return (hasPlus ? '+' : '') + masked + visible;
    }

    get isConvertDisabled() {
        return this.isConverting || this.showExceptionForm;
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleRadioChange(event) {
        this.selectedAccountId  = event.target.value;
        this.showSelectionError = false;
        this.showExceptionForm  = false;
    }

    toggleException() {
        this.showExceptionForm = !this.showExceptionForm;
        if (this.showExceptionForm) {
            this.selectedAccountId  = null;
            this.showSelectionError = false;
        }
    }

    handleReasonChange(event) {
        this.exceptionReason = event.target.value;
    }

    handleSubmitException() {
        if (!this.exceptionReason || this.exceptionReason.trim().length < 10) {
            this._toast('Reason required', 'Please enter at least 10 characters.', 'error');
            return;
        }
        this.isSaving = true;
        submitException({ leadId: this.recordId, reason: this.exceptionReason })
            .then(() => {
                this._toast('Submitted for approval',
                    'Your exception request has been sent for approval.',
                    'info');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(err => this._err('Submit failed', err))
            .finally(() => { this.isSaving = false; });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleConvert() {
        if (this.hasMatches && !this.selectedAccountId) {
            this.showSelectionError = true;
            this._toast('Account selection required',
                'Matching accounts were found. Please select one before converting.',
                'error');
            return;
        }

        this.isConverting = true;

        // For org leads: use orgMatch if found, whether or not existingAccountId
        // is already set — Apex always needs the accountId explicitly passed via
        // setAccountId() for org leads since Company is not blank.
        const orgAccountToSave = this.state.isOrgAccount && this.orgMatch
            ? this.orgMatch.accountId
            : null;

        // Only pass an override when this is a FRESH selection that differs
        // from what's already saved on the lead — avoids an unnecessary
        // Lead update when the account was already mapped beforehand.
        // This is passed straight into convertLead() in ONE Apex call —
        // no separate saveAccountSelection round trip needed anymore.
        const accountIdOverride = orgAccountToSave
            || ((!this.alreadyMapped
                && this.selectedAccountId
                && this.selectedAccountId !== this.state.existingAccountId)
                ? this.selectedAccountId
                : null);

        convertLead({
            leadId:            this.recordId,
            convertedStatus:   'Qualified',
            createOpportunity: true,
            opportunityName:   null,
            accountIdOverride
        })
            .then(result => {
                if (!result.success) {
                    this._toast('Conversion failed', result.errorMessage, 'error');
                    return;
                }
                const msg = result.createdNewAccount
                    ? 'Lead converted — new account created.'
                    : 'Lead converted — existing account reused, no duplicate created.';
                this._toast('Lead converted', msg, 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
                const targetId = result.opportunityId || result.accountId;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: targetId, actionName: 'view' }
                });
            })
            .catch(err => this._err('Conversion failed', err))
            .finally(() => { this.isConverting = false; });
    }

    @api invoke() { this.handleConvert(); }

    // ── Helpers ───────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    _err(title, err) {
        const msg = err?.body?.message || err?.message || 'Unexpected error.';
        this._toast(title, msg, 'error');
    }
}