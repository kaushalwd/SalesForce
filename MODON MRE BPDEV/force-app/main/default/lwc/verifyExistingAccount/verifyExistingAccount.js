// verifyExistingAccount.js
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }         from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex }            from '@salesforce/apex';

import getLeadKYCState           from '@salesforce/apex/ConvertLeadProcessMRE.getLeadKYCState';
import findMatchingPersonAccounts from '@salesforce/apex/ConvertLeadProcessMRE.findMatchingPersonAccounts';
import saveAccountSelection       from '@salesforce/apex/ConvertLeadProcessMRE.saveAccountSelection';
import submitException            from '@salesforce/apex/ConvertLeadProcessMRE.submitException';

export default class VerifyExistingAccount extends LightningElement {

    @api recordId;

    @track isLoading         = true;
    @track isSaving          = false;
    @track state             = {};
    @track accounts          = [];
    @track selectedAccountId = null;
    @track showExceptionForm = false;
    @track exceptionReason   = '';

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
            this._toast('Error', result.error?.body?.message || 'Failed to load.', 'error');
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

    // ── Computed ──────────────────────────────────────────────────────────────

    get alreadyMapped() {
        return !this.state.isOrgAccount
            && !!this.state.existingAccountId
            && this.state.exceptionStatus !== 'Approved';
    }

    get hasMatches() {
        return !this.state.isOrgAccount
            && !this.alreadyMapped
            && this.accounts
            && this.accounts.length > 0;
    }

    get noMatches() {
        return !this.state.isOrgAccount
            && !this.alreadyMapped
            && (!this.accounts || this.accounts.length === 0);
    }

    get matchCountLabel() {
        const n = this.accounts ? this.accounts.length : 0;
        return `${n} matching account${n === 1 ? '' : 's'} found`;
    }

    get enrichedAccounts() {
        return (this.accounts || []).map((acc, idx) => {
            const isSelected = acc.accountId === this.selectedAccountId;
            return {
                ...acc,
                radioId:             `kyc-radio-${idx}`,
                isSelected,
                cardClass:           `kyc-acc-card${isSelected ? ' kyc-acc-card--sel' : ''}`,
                eidDisplay:          acc.eidNumber      || '—',
                passportDisplay:     acc.passportNumber || '—',
                mobileDisplay:       acc.mobile         || '—',
                createdDateFormatted: acc.createdDate
                    ? new Date(acc.createdDate).toLocaleDateString('en-GB',
                        { day: '2-digit', month: 'short', year: 'numeric' })
                    : '—'
            };
        });
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleRadioChange(event) {
        this.selectedAccountId = event.target.value;
        this.showExceptionForm = false;
    }

    toggleException() {
        this.showExceptionForm = !this.showExceptionForm;
        if (this.showExceptionForm) {
            this.selectedAccountId = null;
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
                this._toast('Submitted', 'Exception request sent for approval.', 'info');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(err => this._err('Submit failed', err))
            .finally(() => { this.isSaving = false; });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        // Org account or no matches — nothing to save, just close
        if (this.state.isOrgAccount || this.noMatches) {
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        if (!this.selectedAccountId) {
            this._toast('Selection required', 'Please select an account.', 'error');
            return;
        }

        this.isSaving = true;
        saveAccountSelection({ leadId: this.recordId, accountId: this.selectedAccountId })
            .then(() => {
                this._toast('Account mapped',
                    'Existing account confirmed. Convert Lead will reuse this account.',
                    'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(err => this._err('Save failed', err))
            .finally(() => { this.isSaving = false; });
    }

    // Quick Action Save button (platform header button)
    @api invoke() { this.handleSave(); }

    // ── Helpers ───────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    _err(title, err) {
        const msg = err?.body?.message || err?.message || 'Unexpected error.';
        this._toast(title, msg, 'error');
    }
}