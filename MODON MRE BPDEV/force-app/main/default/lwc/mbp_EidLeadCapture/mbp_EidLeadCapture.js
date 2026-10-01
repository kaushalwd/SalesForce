// mbpEidLeadCapture.js
// ─────────────────────────────────────────────────────────────────────────────
// Standalone LWC — lives on /Brokers/s/eid-lead-capture
// This page IS the UAE Pass redirect_uri for the lead enrichment flow.
//
// Flow:
//  1. Broker enters EID → clicks button
//  2. Apex builds UAE Pass URL → browser redirects
//  3. Customer approves on UAE Pass app
//  4. UAE Pass redirects back HERE with ?code=xxx
//  5. connectedCallback detects code → Apex exchanges token → Apex fetches profile
//  6. Profile shown read-only. Broker fills remaining lead fields
//  7. Submit → createOrUpdateLead (existing) → uploadFileToDocumentRecord (existing)
// ─────────────────────────────────────────────────────────────────────────────

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent }  from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// ── UAE Pass Apex (only 3 methods needed) ──────────────────────────────────
import getLeadAuthorizeUrl  from '@salesforce/apex/MBP_UAEPassLeadController.getLeadAuthorizeUrl';
import exchangeCodeForToken from '@salesforce/apex/MBP_UAEPassLeadController.exchangeCodeForToken';
import getUserProfile       from '@salesforce/apex/MBP_UAEPassLeadController.getUserProfile';

// ── Existing MBP_BrokerLeadcontroller methods ───────────────────────────────
import getUserDetails           from '@salesforce/apex/MBP_BrokerLeadcontroller.getUserDetails';
import createOrUpdateLead       from '@salesforce/apex/MBP_BrokerLeadcontroller.createOrUpdateLead';
import uploadFileToDocumentRecord from '@salesforce/apex/MBP_BrokerLeadcontroller.uploadFileToDocumentRecord';
import getPicklist              from '@salesforce/apex/MBP_BrokerLeadcontroller.getPicklist';

import Id from '@salesforce/user/Id';

// ── View states ─────────────────────────────────────────────────────────────
const VIEW = {
    ENTRY:   'entry',    // EID input form
    LOADING: 'loading',  // after redirect — fetching profile
    FORM:    'form',     // profile fetched — show read-only + lead form
    SAVING:  'saving',   // submitting lead
    SUCCESS: 'success',  // done
};

export default class MbpEidLeadCapture extends NavigationMixin(LightningElement) {

    // ── Current user ────────────────────────────────────────────────────────
    userId   = Id;
    contactId = null;
    accountId = null;

    // ── View state ──────────────────────────────────────────────────────────
    @track view     = VIEW.ENTRY;
    @track errorMsg = null;

    get isEntry()   { return this.view === VIEW.ENTRY;   }
    get isLoading() { return this.view === VIEW.LOADING || this.view === VIEW.SAVING; }
    get isForm()    { return this.view === VIEW.FORM;    }
    get isSuccess() { return this.view === VIEW.SUCCESS; }
    get loadingLabel() {
        return this.view === VIEW.SAVING
            ? 'Saving Lead…'
            : 'Fetching customer profile from UAE Pass…';
    }

    // ── Step 1 ──────────────────────────────────────────────────────────────
    @track eid = '';
    get eidIsValid() {
        return this.eid && this.eid.replace(/-/g, '').length >= 15;
    }

    // ── UAE Pass profile (read-only, step 2) ────────────────────────────────
    @track profile = {};

    // ── Lead form fields (step 2 — editable by broker) ──────────────────────
    @track leadType           = 'Individual';
    @track title              = '';
    @track uaeResidentStatus  = '';
    @track countryOfResidence = '';
    @track nationality        = '';
    @track description        = '';
    @track salesOrigin        = '';
    @track leadOrigin         = '';
    @track salesType          = '';
    @track projectName        = '';
    @track numberOfBeds       = '';
    @track unitType           = '';
    @track purposeOfUse       = '';
    @track customerBudget     = '';
    // Org only
    @track orgName            = '';
    @track unifiedNumber      = '';
    @track vatCertificateType = '';
    @track vatRegNumber       = '';
    @track showVatRegNumber   = false;
    @track showDummyVatLink   = false;
    // Passport (non-residents)
    @track passportNumber     = '';
    @track passportIssuance   = '';
    @track passportExpiry     = '';

    // ── File state ──────────────────────────────────────────────────────────
    // Each entry: { file, name, b64, docLabel }
    _files = {
        emiratesFront : { file: null, name: null, b64: null, docLabel: 'Emirates ID' },
        emiratesBack  : { file: null, name: null, b64: null, docLabel: 'Emirates ID' },
        passportFront : { file: null, name: null, b64: null, docLabel: 'Passport Copy' },
        passportBack  : { file: null, name: null, b64: null, docLabel: 'Passport Copy' },
        kyc           : { file: null, name: null, b64: null, docLabel: 'Complete KYC form' },
        sourceFunds   : { file: null, name: null, b64: null, docLabel: '3 month Bank statement/source of funds' },
        tradeLicense  : { file: null, name: null, b64: null, docLabel: 'Trade License' },
        vat           : { file: null, name: null, b64: null, docLabel: 'VAT Register' },
    };
    // Reactive file name refs for template
    @track emiratesFrontName = null;
    @track emiratesBackName  = null;
    @track passportFrontName = null;
    @track passportBackName  = null;
    @track kycName           = null;
    @track sourceFundsName   = null;
    @track tradeLicenseName  = null;
    @track vatName           = null;

    // ── Picklist options ─────────────────────────────────────────────────────
    @track titleOptions           = [];
    @track uaeResidentOptions     = [];
    @track countryOptions         = [];
    @track nationalityOptions     = [];
    @track salesOriginOptions     = [];
    @track leadOriginOptions      = [];
    @track salesTypeOptions       = [];
    @track projectOptions         = [];
    @track bedsOptions            = [];
    @track unitTypeOptions        = [];
    @track purposeOptions         = [];
    @track budgetOptions          = [];
    @track vatCertOptions         = [
        { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
        { label: 'VAT Undertaking Certificate',  value: 'VAT Undertaking Certificate'  },
        { label: 'Not Applicable',               value: 'Not Applicable'               },
    ];
    leadTypeOptions = [
        { label: 'Individual',   value: 'Individual'   },
        { label: 'Organization', value: 'Organization' },
    ];

    // ── Computed ─────────────────────────────────────────────────────────────
    get isIndividual()       { return this.leadType === 'Individual';   }
    get isOrganization()     { return this.leadType === 'Organization'; }
    get showUaeFields()      { return this.uaeResidentStatus === 'UAE Resident'; }
    get showPassportFields() { return this.uaeResidentStatus === 'Non-UAE Resident'; }

    _savedLeadId = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._loadUser();
        this._loadPicklists();
        this._checkOAuthCallback();
    }

    // ── Load current user's contactId and accountId ──────────────────────────
    _loadUser() {
        getUserDetails({ userId: this.userId })
            .then(u => {
                this.contactId = u.ContactId;
                this.accountId = u.Contact?.AccountId;
            })
            .catch(e => console.error('getUserDetails error:', e));
    }

    // ── Load all picklists from existing getPicklist Apex ────────────────────
    _loadPicklists() {
        const load = (field, target, obj = 'Lead') =>
            getPicklist({ objectName: obj, fieldName: field })
                .then(r => { this[target] = (r.values || []).map(v => ({ label: v, value: v })); })
                .catch(e => console.error('Picklist error ' + field, e));

        load('Salutation',           'titleOptions');
        load('UAEResidentStatus__c', 'uaeResidentOptions');
        load('CountryOfResidence__c','countryOptions');
        load('Nationality__c',       'nationalityOptions');
        load('SalesOrigin__c',       'salesOriginOptions');
        load('LeadOrigin__c',        'leadOriginOptions');
        load('SalesType__c',         'salesTypeOptions');
        load('Project__c',           'projectOptions');
        load('NumberOfBedrooms__c',  'bedsOptions');
        load('UnitType__c',          'unitTypeOptions');
        load('PurposeofUse__c',      'purposeOptions');
        load('CustomerBudget__c',    'budgetOptions');
    }

    // ── CRITICAL: Detect UAE Pass ?code= on page load ────────────────────────
    _checkOAuthCallback() {
        let code = null;

        const params = new URLSearchParams(window.location.search);
        code = params.get('code');

        // Experience Cloud nests it inside startURL sometimes
        if (!code) {
            const startUrl = params.get('startURL');
            if (startUrl) {
                try {
                    const decoded = decodeURIComponent(startUrl);
                    const inner   = new URLSearchParams(decoded.split('?')[1] || '');
                    code = inner.get('code');
                } catch (e) { /* ignore */ }
            }
        }

        if (!code) return; // Normal load — no callback

        // Clean URL immediately so F5 doesn't retrigger
        window.history.replaceState({}, document.title, window.location.pathname);

        // Restore EID broker entered before redirect
        this.eid = sessionStorage.getItem('mbp_eid_lead_eid') || '';
        sessionStorage.removeItem('mbp_eid_lead_eid');

        // Run the token → profile chain
        this.view = VIEW.LOADING;
        this._handleOAuthCallback(code);
    }

    // ── Step 1: Broker clicks Authenticate ───────────────────────────────────
    handleEidChange(event) {
        this.eid      = event.target.value;
        this.errorMsg = null;
    }

    handleAuthenticate() {
        if (!this.eidIsValid) {
            this.errorMsg = 'Please enter a valid Emirates ID (e.g. 784-XXXX-XXXXXXX-X).';
            return;
        }
        this.errorMsg = null;

        // Persist EID across the redirect
        sessionStorage.setItem('mbp_eid_lead_eid', this.eid);

        getLeadAuthorizeUrl({ eid: this.eid })
            .then(url => { window.location.href = url; })
            .catch(err => {
                this.errorMsg = err.body?.message || 'Failed to connect to UAE Pass.';
            });
    }

    // ── OAuth callback chain: code → token → profile ─────────────────────────
    async _handleOAuthCallback(code) {
        try {
            const tokenJson   = await exchangeCodeForToken({ code });
            const tokenData   = JSON.parse(tokenJson);
            const accessToken = tokenData.access_token;
            if (!accessToken) throw new Error('No access token received.');

            const prof = await getUserProfile({ accessToken });
            this.profile = prof;
            this._preFillFromProfile(prof);
            this.view = VIEW.FORM;

        } catch (err) {
            this.errorMsg = err.body?.message || err.message || 'UAE Pass profile fetch failed.';
            this.view = VIEW.ENTRY;
        }
    }

    // ── Pre-fill editable fields from UAE Pass profile ────────────────────────
    _preFillFromProfile(p) {
        // Pre-fill nationality if it matches a picklist value
        if (p.nationality) {
            const match = this.nationalityOptions.find(
                o => o.label.toLowerCase() === p.nationality.toLowerCase()
            );
            this.nationality = match ? match.value : '';
        }
        // Auto-set UAE Resident if EID is present
        this.uaeResidentStatus = p.idn ? 'UAE Resident' : '';
    }

    // ── Generic form field change handler ────────────────────────────────────
    handleChange(event) {
        const field = event.target.name;
        const value = event.detail?.value ?? event.target.value;
        if (field && this.hasOwnProperty(field)) {
            this[field] = value;
        }
    }

    handleLeadTypeChange(event)     { this.leadType = event.detail.value; }
    handleUaeResidentChange(event)  { this.uaeResidentStatus = event.detail.value; }

    handleVatTypeChange(event) {
        this.vatCertificateType = event.detail.value;
        this.showVatRegNumber   = (event.detail.value === 'VAT Registration Certificate');
        this.showDummyVatLink   = (event.detail.value === 'VAT Undertaking Certificate');
    }

    // ── File handlers — same pattern as existing component ───────────────────
    // data-field on each input matches a key in this._files
    handleFileUpload(event) {
        const field = event.target.dataset.field;
        const file  = event.target.files[0];
        if (!file || !this._files[field]) return;

        this._files[field].file = file;
        this._files[field].name = file.name;

        // Update reactive name prop for template display
        const nameProp = field + 'Name';
        if (nameProp in this) this[nameProp] = file.name;

        // Pre-read as base64 so we have it ready on submit
        const reader = new FileReader();
        reader.onload = () => {
            this._files[field].b64 = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleDeleteFile(event) {
        const field = event.target.dataset.field;
        if (!this._files[field]) return;
        this._files[field] = { ...this._files[field], file: null, name: null, b64: null };
        const nameProp = field + 'Name';
        if (nameProp in this) this[nameProp] = null;
    }

    // ── Submit ────────────────────────────────────────────────────────────────
    async handleSubmit() {
        if (!this._validateForm()) return;

        this.view     = VIEW.SAVING;
        this.errorMsg = null;

        try {
            // Build payload matching createOrUpdateLead expectations exactly
            const payload = {
                // Identity from UAE Pass
                Email:                   this.profile.email,
                MobilePhone:             this.profile.mobile,
                FirstName:               this.profile.firstNameEn,
                LastName:                this.profile.lastNameEn || 'Unknown',
                EIDNumber__c:            this.profile.idn,
                EmiratesIDExpiryDate__c: this.profile.idExpiryDate || '',
                PassportNumber__c:       this.passportNumber  || '',
                PassportIssueDate__c:    this.passportIssuance || '',
                PassportExpiryDate__c:   this.passportExpiry   || '',

                // Broker-entered
                Type:                    this.leadType,
                Salutation:              this.title,
                Name:                    this.isOrganization ? this.orgName : '',
                UnifiedNumber__c:        this.unifiedNumber   || '',
                vatCertificateType:      this.vatCertificateType || '',
                UAEVATRegisterNumber__c: this.vatRegNumber     || '',
                UAEResidentStatus__c:    this.uaeResidentStatus,
                CountryOfResidence__c:   this.countryOfResidence,
                Nationality__c:          this.nationality,
                Description:             this.description,
                SalesOrigin__c:          this.salesOrigin,
                LeadOrigin__c:           this.leadOrigin,
                SalesType__c:            this.salesType,
                Project__c:              this.projectName,
                NumberOfBedrooms__c:     this.numberOfBeds,
                UnitType__c:             this.unitType,
                PurposeofUse__c:         this.purposeOfUse,
                CustomerBudget__c:       this.customerBudget,
            };

            // 1. Create the Lead using existing Apex
            const lead = await createOrUpdateLead({
                payload,
                contactId: this.contactId,
                accountId: this.accountId,
            });

            this._savedLeadId = lead.Id;

            // 2. Upload files using existing uploadFileToDocumentRecord Apex
            await this._uploadFiles(lead.Id);

            this.view = VIEW.SUCCESS;

        } catch (err) {
            this.errorMsg = err.body?.message || err.message || 'Lead submission failed.';
            this.view     = VIEW.FORM;
        }
    }

    // ── Upload all attached files using the existing Apex method ──────────────
    async _uploadFiles(leadId) {
        const uploads = [];

        for (const [key, f] of Object.entries(this._files)) {
            if (!f.b64 || !f.name) continue;

            // Ensure b64 is ready (it's set async on FileReader — wait if needed)
            uploads.push(
                uploadFileToDocumentRecord({
                    base64Data:        f.b64,
                    fileName:          f.name,
                    leadId:            leadId,
                    documentTypeLabel: f.docLabel,
                })
            );
        }

        // Run all uploads in parallel
        if (uploads.length > 0) {
            await Promise.all(uploads);
        }
    }

    _validateForm() {
        const checks = [
            [this.uaeResidentStatus, 'UAE Resident Status'],
            [this.salesOrigin,       'Sales Origin'],
            [this.leadOrigin,        'Lead Origin'],
            [this.salesType,         'Sales Type'],
            [this.projectName,       'Project Name'],
            [this.numberOfBeds,      'Number of Bedrooms'],
            [this.unitType,          'Unit Type'],
            [this.purposeOfUse,      'Purpose of Use'],
            [this.customerBudget,    'Customer Budget'],
        ];
        for (const [val, label] of checks) {
            if (!val) { this.errorMsg = `Please fill in: ${label}`; return false; }
        }
        if (this.isOrganization && !this.orgName) {
            this.errorMsg = 'Please enter Organization Name.';
            return false;
        }
        return true;
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleViewLead() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:      this._savedLeadId,
                objectApiName: 'Lead',
                actionName:    'view',
            },
        });
    }

    handleNewLead() {
        // Reset everything — broker starts fresh for next customer
        this.view             = VIEW.ENTRY;
        this.eid              = '';
        this.profile          = {};
        this.errorMsg         = null;
        this.leadType         = 'Individual';
        this.title            = '';
        this.uaeResidentStatus= '';
        this.countryOfResidence='';
        this.nationality      = '';
        this.description      = '';
        this.salesOrigin      = '';
        this.leadOrigin       = '';
        this.salesType        = '';
        this.projectName      = '';
        this.numberOfBeds     = '';
        this.unitType         = '';
        this.purposeOfUse     = '';
        this.customerBudget   = '';
        this.orgName          = '';
        this.unifiedNumber    = '';
        this.vatCertificateType='';
        this.vatRegNumber     = '';
        this.showVatRegNumber = false;
        this.showDummyVatLink = false;
        this.passportNumber   = '';
        this.passportIssuance = '';
        this.passportExpiry   = '';
        this._savedLeadId     = null;

        // Reset files
        for (const key of Object.keys(this._files)) {
            this._files[key] = { ...this._files[key], file: null, name: null, b64: null };
        }
        this.emiratesFrontName = null;
        this.emiratesBackName  = null;
        this.passportFrontName = null;
        this.passportBackName  = null;
        this.kycName           = null;
        this.sourceFundsName   = null;
        this.tradeLicenseName  = null;
        this.vatName           = null;
    }

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/Brokers/s/manage-leads' },
        });
    }
}