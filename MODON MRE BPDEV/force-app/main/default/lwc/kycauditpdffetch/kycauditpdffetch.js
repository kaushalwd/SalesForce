import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getProfilesForDocument from '@salesforce/apex/MaxsightAuditReportService.getProfilesForDocument';
import triggerKycFetch        from '@salesforce/apex/MaxsightAuditReportService.triggerKycFetch';

import NAME_FIELD    from '@salesforce/schema/Documents__c.Name';
import SO_FIELD      from '@salesforce/schema/Documents__c.SalesOrder__c';
import SO_NAME_FIELD from '@salesforce/schema/Documents__c.SalesOrder__r.Name';

// No hardcoded document name — always read from Apex (Custom Label)
// So renaming the label in Setup → Custom Labels → MaxsightKycDocumentName
// automatically applies here with no JS/deployment change needed

export default class KycAuditPdfFetch extends LightningElement {

    @api recordId;

    @track isLoading        = false;  // false until wire loads — no spinner on non-KYC records
    @track isServiceActive  = true;
    @track profilesLoaded   = false;
    @track profileList      = [];
    @track errorMessage     = null;
    @track successMessage   = null;
    @track loadingMessage   = '';

    recordName      = null;
    salesOrderName  = null;
    kycDocName      = null;   // always read from Apex Custom Label — never hardcoded
    kycNameLoaded   = false;  // true once Apex has confirmed the label value
    hasSalesOrder   = false;  // set from wire — used in loadProfiles
    wiredDocResult;

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD, SO_FIELD, SO_NAME_FIELD] })
    wiredDoc(result) {
        this.wiredDocResult = result;
        if (result.data) {
            this.recordName     = getFieldValue(result.data, NAME_FIELD);
            this.salesOrderName = getFieldValue(result.data, SO_NAME_FIELD);
            this.hasSalesOrder  = !!getFieldValue(result.data, SO_FIELD);
            // Always call Apex to get the label value — Apex is the single source of truth
            // kycDocName is read from Custom Label server-side so label changes apply instantly
            this.loadProfiles();
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    /**
     * isKycRecord — compares record Name against kycDocName from Custom Label (via Apex).
     * Returns false until Apex has loaded (kycNameLoaded = false) — keeps component hidden.
     * Once Apex loads: only shows if Name === label value.
     * Changing Custom Label in Setup → no deployment needed, change takes effect immediately.
     */
    get isKycRecord() {
        if (!this.kycNameLoaded) return false;  // hide until label confirmed
        if (!this.recordName || !this.kycDocName) return false;
        return this.recordName === this.kycDocName;
    }

    loadProfiles() {
        this.isLoading      = true;
        this.loadingMessage = 'Checking approval status...';
        this.errorMessage   = null;

        getProfilesForDocument({ documentId: this.recordId })
            .then(result => {
                // kycDocName comes from Custom Label on server — always up to date
                this.kycDocName    = result.kycDocName;
                this.kycNameLoaded = true;  // now isKycRecord can evaluate correctly

                // If this is not the KYC document — stop here, component stays hidden
                if (!this.isKycRecord) {
                    this.isLoading = false;
                    return;
                }

                // Is a KYC record — proceed
                if (!this.hasSalesOrder) {
                    this.errorMessage = 'No Sales Order linked to this record.';
                    this.isLoading    = false;
                    return;
                }

                this.isServiceActive = result.isActive;
                this.salesOrderName  = result.soName || this.salesOrderName;

                this.profileList = (result.profiles || []).map(p => ({
                    ...p,
                    statusLabel   : p.isApproved ? 'Approved — will fetch PDF' : 'Not Approved — will skip',
                    statusIcon    : p.isApproved ? 'utility:check' : 'utility:close',
                    statusVariant : p.isApproved ? 'success' : 'error'
                }));

                // When service is inactive — just disable the button silently
                // No error message shown to user

                this.profilesLoaded = true;
                this.isLoading      = false;
            })
            .catch(error => {
                this.kycNameLoaded = true;
                this.errorMessage  = 'Error: ' + this.reduceError(error);
                this.isLoading     = false;
            });
    }

    // ALL profiles must be approved before button is enabled
    // If joint owners exist — every single person must be Approved
    get allApproved() {
        if (!this.profileList || this.profileList.length === 0) return false;
        return this.profileList.every(p => p.isApproved);
    }

    get hasJointOwners() {
        return this.profileList && this.profileList.some(p => p.role === 'Joint Owner');
    }

    get pendingProfiles() {
        return this.profileList ? this.profileList.filter(p => !p.isApproved) : [];
    }

    get allApprovalMessage() {
        if (!this.profilesLoaded) return null;
        if (this.allApproved) return null;
        if (this.hasJointOwners) {
            const names = this.pendingProfiles.map(p => p.name + ' (' + p.role + ')').join(', ');
            return 'All owners must be Approved before PDF can be fetched. Pending: ' + names;
        }
        return 'Primary owner must be Approved before PDF can be fetched.';
    }

    get buttonDisabled() {
        // Only disabled if loading or not all approved
        // isServiceActive (label) only blocks auto trigger — not the manual button
        return this.isLoading || !this.allApproved;
    }

    // Fires when user clicks the disabled button wrapper — shows toast explaining why
    handleDisabledClick() {
        if (!this.buttonDisabled) return; // button is active — let handleFetch take over

        const pending = this.pendingProfiles;
        if (pending && pending.length > 0) {
            const names = pending.map(p => p.name + ' (' + p.role + ')').join(', ');
            this.dispatchEvent(new ShowToastEvent({
                title:   'Cannot Fetch PDF',
                message: 'All owners must be Approved. Pending: ' + names,
                variant: 'warning',
                mode:    'sticky'
            }));
        }
    }

    handleFetch() {
        this.isLoading      = true;
        this.loadingMessage = 'Queuing fetch for approved profiles...';
        this.errorMessage   = null;
        this.successMessage = null;

        triggerKycFetch({ documentId: this.recordId })
            .then(result => {
                this.isLoading      = false;
                this.successMessage = result;
                this.dispatchEvent(new ShowToastEvent({
                    title:   'KYC Fetch Queued',
                    message: result,
                    variant: 'success'
                }));
                setTimeout(() => {
                    this.loadProfiles();
                    refreshApex(this.wiredDocResult);
                }, 4000);
            })
            .catch(error => {
                this.isLoading    = false;
                this.errorMessage = this.reduceError(error);
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Error',
                    message: this.reduceError(error),
                    variant: 'error'
                }));
            });
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}