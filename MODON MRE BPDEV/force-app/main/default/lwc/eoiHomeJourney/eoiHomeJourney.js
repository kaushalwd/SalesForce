import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import { wire } from 'lwc';
import LEAD_OBJECT from '@salesforce/schema/Lead';

import searchCustomer from '@salesforce/apex/EoiHomeJourneyController.searchCustomer';
import prepareOpportunity from '@salesforce/apex/EoiHomeJourneyController.prepareOpportunity';
import createEoiAndOptionalReceipt from '@salesforce/apex/EoiHomeJourneyController.createEoiAndOptionalReceipt';
import sendPaymentLink from '@salesforce/apex/EoiCheckoutPaymentController.sendPaymentLink';
import payNowHosted from '@salesforce/apex/EoiCheckoutPaymentController.payNowHosted';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';

import getProjects from '@salesforce/apex/EoiHomeJourneyController.getProjects';
import getEoiRangeMatrix from '@salesforce/apex/EoiHomeJourneyController.getEoiRangeMatrix';
import validateEOI from '@salesforce/apex/EoiHomeJourneyController.validateEOI';
import startVerification from '@salesforce/apex/VerificationService.startVerification';
import resendVerification from '@salesforce/apex/VerificationService.resendVerification';
import verifyCode from '@salesforce/apex/VerificationService.verifyCode';

export default class EoiHomeJourney extends NavigationMixin(LightningElement) {
    isMaintenanceMode = false;
    _recordId;
    _objectApiName;

    @track showModal = false;
    @track isOpportunityActionMode = false;
    @track step = 1;
    @track isLoading = false;
    @track isValidatingEmail = false;
    @track isValidatingPhone = false;
    @track validatingContactKey = '';
    @track errorMessage = '';
    @track lookupIdentifierError = '';
    @track matchMessage = '';
    @track createdEoiId = null;
    @track createdEoiReference = '';
    @track createdEoiReferences = [];
    @track createdAccountName = '';

    @track customer = {
        accountId: null,
        leadId: null,
        contactId: null,
        customerType: 'Individual',
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        residentStatus: 'Resident',
        nationality: '',
        countryOfResidence: '',
        emiratesId: '',
        emiratesIdExpiryDate: '',
        passportNumber: '',
        passportExpiryDate: '',
        companyName: '',
        tradeLicenseNumber: '',
        tradeLicenseExpiryDate: '',
        registeredEmail: '',
        registeredPhone: '',
        authorizedFirstName: '',
        authorizedLastName: '',
        authorizedEmail: '',
        authorizedPhone: ''
    };

    @track lookupCriteria = {
        emiratesId: '',
        passportNumber: '',
        phone: '',
        email: '',
        companyName: '',
        tradeLicenseNumber: '',
        registeredEmail: '',
        registeredPhone: ''
    };

    @track customerSource = 'New';
    @track isCustomerEditable = true;
    @track identityVerified = false;
    @track customerMatches = [];
    @track opportunityId = null;
    @track accountId = null;
    @track contactId = null;

    @track projectOptions = [];
    @track nationalityOptions = [];
    @track countryOfResidenceOptions = [];
    @track phaseOptions = [];
    @track unitTypeOptions = [];
    @track bedroomOptions = [];
    @track eoiRangeMatrix = [];
    @track selectedProjectId = '';
    @track selectedProjectName = '';
    @track eoiSelections = [];
    @track showQuota = false;
    @track quotaLimit = 0;
    @track quotaUsed = 0;
    @track quotaRemaining = 0;
    @track quotaExceeded = false;
    @track projectAvailabilityError = '';
    @track activeEoiSelectionKey = '';
    @track verificationMethod = '';
    @track verificationDigits = [];
    @track verificationMessage = '';
    @track verificationCompleted = false;
    @track verificationRequestId = null;
    @track isSendingVerification = false;
    @track resendCooldownSeconds = 0;
    @track resendAvailableAt = null;
    @track maxResendReached = false;
    @track selectedPaymentMethod = 'Online';
    accountLockedFields = {};

    contactValidation = {
        lookupEmail: false,
        lookupPhone: false,
        customerEmail: false,
        customerPhone: false
    };
    contactValidationValues = {
        lookupEmail: '',
        lookupPhone: '',
        customerEmail: '',
        customerPhone: ''
    };
    eoiSelectionCounter = 0;
    pendingOtpFocusIndex = null;
    resendCooldownTimer = null;
    hasInitializedOpportunityAction = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.initializeOpportunityActionMode();
    }

    @api
    get objectApiName() {
        return this._objectApiName;
    }

    set objectApiName(value) {
        this._objectApiName = value;
        this.initializeOpportunityActionMode();
    }

    residentOptions = [
        { label: 'Resident', value: 'Resident' },
        { label: 'Non-Resident', value: 'Non-Resident' }
    ];

    customerTypeOptions = [
        { label: 'Individual', value: 'Individual' },
        { label: 'Organization', value: 'Organization' }
    ];

    // Online routes through Checkout (pay first, EOI on capture); the offline types
    // create the EOI immediately (original behaviour) - branched in the action area.
    paymentTypeOptions = [
        //{ label: 'Cheque', value: 'Cheque' },
        //{ label: 'POS', value: 'POS' },
        { label: 'Online', value: 'Online' },
        //{ label: 'Bank Transfer', value: 'Bank Transfer' }
    ];

    // ── Checkout payment (pay first, EOI on capture) ──────────────────────────
    @track paymentOutcome = '';         // '', 'link-sent'
    @track checkoutMethod = 'send';     // Online: always send link

    connectedCallback() {
        this.loadProjects();
        if (!this.hasInitializedOpportunityAction) {
            this.resetEoiSelections();
            this.resetVerification();
        }
        this.initializeOpportunityActionMode();
        this.handlePaymentReturn();
    }

    // On return from the Checkout hosted page (Pay-now redirect), show the outcome and clean the URL.
    handlePaymentReturn() {
        const params = new URLSearchParams(window.location.search);
        const result = params.get('paymentResult');
        if (!result) return;
        const map = {
            success:   { title: 'Payment Received', message: 'Your EOI will be created shortly.', variant: 'success' },
            failed:    { title: 'Payment Not Completed', message: 'The payment was not completed. Please try again.', variant: 'warning' },
            cancelled: { title: 'Payment Cancelled', message: 'No charge was made.', variant: 'info' }
        };
        const t = map[result];
        if (t) this.dispatchEvent(new ShowToastEvent({ title: t.title, message: t.message, variant: t.variant }));
        window.history.replaceState({}, '', window.location.pathname);
    }

    renderedCallback() {
        if (this.pendingOtpFocusIndex === null || this.pendingOtpFocusIndex === undefined) return;
        const input = this.template.querySelector(`input[data-otp-index="${this.pendingOtpFocusIndex}"]`);
        this.pendingOtpFocusIndex = null;
        if (input) input.focus();
    }

    handleOpenJourney() {
        this.resetJourneyForNewSession();
        this.showModal = true;
    }

    @api
    invoke() {
        this.initializeOpportunityActionMode(true);
    }

    handleCloseJourney() {
        this.showModal = false;
        if (this.isOpportunityActionMode) {
            this.isOpportunityActionMode = false;
            this.dispatchEvent(new CloseActionScreenEvent());
        }
        this.clearResendCooldownTimer();
    }

    resetJourneyForNewSession() {
        this.isOpportunityActionMode = false;
        this.hasInitializedOpportunityAction = false;
        this.step = 1;
        this.isLoading = false;
        this.isValidatingEmail = false;
        this.isValidatingPhone = false;
        this.validatingContactKey = '';
        this.customer = { ...this.customer, customerType: 'Individual' };
        this.handleClearIdentity();
    }

    initializeOpportunityActionMode(forceOpen = false) {
        if (!this.isOpportunityContext || (this.hasInitializedOpportunityAction && !forceOpen)) return;

        this.resetJourneyForNewSession();
        this.isOpportunityActionMode = true;
        this.hasInitializedOpportunityAction = true;
        this.showModal = true;
        this.step = 3;
        this.opportunityId = this.recordId;
        this.identityVerified = true;
        this.verificationCompleted = true;
        this.customerSource = 'Account';
        this.isCustomerEditable = false;
    }

    async loadProjects() {
        try {
            this.projectOptions = await getProjects();
            await this.autoSelectSingleProject();
        } catch (error) {
            this.errorMessage = 'Failed to load projects: ' + this.reduceError(error);
        }
    }

    /**
     * When the org exposes exactly one project there is nothing to choose, so preselect it and
     * lock the field — the same rule the Phase/Unit Type/Bedrooms cascade follows.
     */
    async autoSelectSingleProject() {
        if (!this.isSingleProject || this.selectedProjectId) return;
        await this.selectProject(this.projectOptions[0].value);
    }

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    leadObjectInfo;

    @wire(getPicklistValuesByRecordType, {
        objectApiName: LEAD_OBJECT,
        recordTypeId: '$leadRecordTypeId'
    })
    wiredLeadPicklists({ data }) {
        if (!data) return;
        this.nationalityOptions = data.picklistFieldValues?.Nationality__c?.values || [];
        this.countryOfResidenceOptions = data.picklistFieldValues?.CountryOfResidence__c?.values || [];
    }

    get leadRecordTypeId() {
        return this.leadObjectInfo?.data?.defaultRecordTypeId;
    }

    handleCustomerChange(event) {
        const field = event.target.dataset.field;
        const rawValue = this.getInputValue(event);
        const value = field === 'residentStatus'
            ? this.normalizeResidentStatus(rawValue)
            : field === 'emiratesId'
                ? this.formatEmiratesId(rawValue)
                : field === 'passportNumber'
                    ? this.sanitizePassportNumber(rawValue)
                    : this.isDateField(field)
                        ? this.normalizeDateValue(rawValue)
                : rawValue;
        const previousValue = this.customer[field] || '';
        const hasChanged = previousValue !== value;
        if (field === 'emiratesId') event.target.value = value;
        if (field === 'passportNumber') event.target.value = value;
        if (!hasChanged) return;
        this.customer = { ...this.customer, [field]: value };
        if (field === 'email' || field === 'authorizedEmail') this.clearInputValidation('customerEmail');
        if (field === 'phone' || field === 'authorizedPhone') this.clearInputValidation('customerPhone');
        if (field === 'residentStatus') {
            this.customer = value === 'Resident'
                ? { ...this.customer }
                : { ...this.customer, emiratesId: '', emiratesIdExpiryDate: '' };
        }
        this.clearPreparedOpportunity();
    }

    handleCustomerTypeChange(event) {
        const customerType = this.getInputValue(event) || 'Individual';
        this.customer = {
            ...this.customer,
            customerType,
            accountId: null,
            leadId: null,
            contactId: null
        };
        this.clearIdentityResult();
    }

    handleLookupChange(event) {
        const field = event.target.dataset.lookupField;
        const rawValue = this.getInputValue(event);
        const value = field === 'emiratesId'
            ? this.formatEmiratesId(rawValue)
            : field === 'passportNumber'
                ? this.sanitizePassportNumber(rawValue)
                : rawValue;
        const previousValue = this.lookupCriteria[field] || '';
        const hasChanged = previousValue !== value;
        if (field === 'emiratesId') event.target.value = value;
        if (field === 'passportNumber') event.target.value = value;
        if (!hasChanged) return;
        this.lookupCriteria = { ...this.lookupCriteria, [field]: value };
        if (field === 'email' || field === 'registeredEmail') this.clearInputValidation('lookupEmail');
        if (field === 'phone' || field === 'registeredPhone') this.clearInputValidation('lookupPhone');
        this.lookupIdentifierError = '';
        this.clearIdentityResult();
    }

    async handleFindCustomer() {
        this.errorMessage = '';
        this.lookupIdentifierError = '';
        this.matchMessage = '';
        this.customerMatches = [];
        this.clearPreparedOpportunity();
        try {
            if (!this.hasLookupIdentifier()) {
                this.lookupIdentifierError = 'Enter at least one identifier: Emirates ID, Passport Number, Phone Number, or Email Address.';
                return;
            }
            if (!this.areContactInputsAlreadyValid(['lookupEmail', 'lookupPhone'], true)) return;
            this.isLoading = true;
            const request = this.buildCustomerSearchRequest();
            const result = await searchCustomer({ request });
            this.identityVerified = true;
            this.applyCustomerSearchResult(result);
        } catch (error) {
            console.error('[eoiHomeJourney] Verify Identity error', JSON.parse(JSON.stringify(error)));
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    buildCustomerSearchRequest() {
        this.syncLookupInputsFromDom();
        const request = this.isOrganizationCustomer ? {
            ...this.customer,
            companyName: this.lookupCriteria.companyName,
            tradeLicenseNumber: this.lookupCriteria.tradeLicenseNumber,
            registeredEmail: this.lookupCriteria.registeredEmail,
            registeredPhone: this.lookupCriteria.registeredPhone,
            email: this.lookupCriteria.registeredEmail,
            phone: this.lookupCriteria.registeredPhone,
            requestId: String(Date.now())
        } : {
            ...this.customer,
            email: this.lookupCriteria.email,
            phone: this.lookupCriteria.phone,
            emiratesId: this.formatEmiratesId(this.lookupCriteria.emiratesId),
            passportNumber: this.sanitizePassportNumber(this.lookupCriteria.passportNumber),
            requestId: String(Date.now())
        };
        request.email = (request.email || '').trim();
        request.phone = (request.phone || '').trim();
        request.passportNumber = this.sanitizePassportNumber(request.passportNumber);
        request.emiratesId = this.formatEmiratesId(request.emiratesId || '').trim();
        request.companyName = (request.companyName || '').trim();
        request.tradeLicenseNumber = (request.tradeLicenseNumber || '').trim();
        request.tradeLicenseExpiryDate = this.normalizeDateValue(request.tradeLicenseExpiryDate);
        request.emiratesIdExpiryDate = this.isOrganizationCustomer ? null : this.normalizeDateValue(request.emiratesIdExpiryDate);
        request.passportExpiryDate = this.isOrganizationCustomer ? null : this.normalizeDateValue(request.passportExpiryDate);
        request.registeredEmail = (request.registeredEmail || '').trim();
        request.registeredPhone = (request.registeredPhone || '').trim();
        return request;
    }

    hasLookupIdentifier() {
        this.syncLookupInputsFromDom();
        return Boolean(
            this.isOrganizationCustomer
                ? ((this.lookupCriteria.companyName || '').trim()
                    || (this.lookupCriteria.tradeLicenseNumber || '').trim()
                    || (this.lookupCriteria.registeredPhone || '').trim()
                    || (this.lookupCriteria.registeredEmail || '').trim())
                : ((this.lookupCriteria.emiratesId || '').trim()
                    || (this.lookupCriteria.passportNumber || '').trim()
                    || (this.lookupCriteria.phone || '').trim()
                    || (this.lookupCriteria.email || '').trim())
        );
    }

    syncLookupInputsFromDom() {
        const emiratesIdInput = this.template.querySelector('[data-lookup-emirates-id]');
        const passportInput = this.template.querySelector('[data-lookup-passport]');
        const phoneInput = this.template.querySelector('[data-lookup-phone]');
        const emailInput = this.template.querySelector('[data-lookup-email]');
        const companyInput = this.template.querySelector('[data-lookup-company]');
        const tradeLicenseInput = this.template.querySelector('[data-lookup-trade-license]');
        const registeredPhoneInput = this.template.querySelector('[data-lookup-registered-phone]');
        const registeredEmailInput = this.template.querySelector('[data-lookup-registered-email]');

        const emiratesIdValue = emiratesIdInput?.value;
        const passportValue = passportInput?.value;
        const phoneValue = phoneInput?.value;
        const emailValue = emailInput?.value;

        if (emiratesIdValue !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, emiratesId: this.formatEmiratesId(emiratesIdValue) };
        }
        if (passportValue !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, passportNumber: this.sanitizePassportNumber(passportValue) };
        }
        if (phoneValue !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, phone: phoneValue };
        }
        if (emailValue !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, email: emailValue };
        }
        if (companyInput?.value !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, companyName: companyInput.value };
        }
        if (tradeLicenseInput?.value !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, tradeLicenseNumber: tradeLicenseInput.value };
        }
        if (registeredPhoneInput?.value !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, registeredPhone: registeredPhoneInput.value };
        }
        if (registeredEmailInput?.value !== undefined) {
            this.lookupCriteria = { ...this.lookupCriteria, registeredEmail: registeredEmailInput.value };
        }
    }

    applyCustomerSearchResult(result) {
        const accountMatches = (result?.matches || [])
            .filter((match) => match.sourceType === 'Account')
            .map((match) => this.toDisplayMatch(match));

        if (accountMatches.length > 1) {
            this.customerMatches = accountMatches;
            this.customerSource = 'Multiple';
            this.isCustomerEditable = false;
            this.customer = {
                ...this.customer,
                accountId: null,
                leadId: null,
                contactId: null,
                firstName: '',
                lastName: '',
                email: '',
                phone: '',
                residentStatus: 'Resident',
                nationality: '',
                countryOfResidence: '',
                emiratesId: '',
                emiratesIdExpiryDate: '',
                passportNumber: '',
                passportExpiryDate: ''
            };
            this.matchMessage = `${accountMatches.length} matching accounts found. Select the correct customer before continuing.`;
            return;
        }

        this.customerSource = result?.sourceType || 'New';
        this.isCustomerEditable = result?.isEditable !== false;

        if (result?.selected) {
            this.applySelectedCustomerMatch(result.selected);
        } else {
            this.customer = this.isOrganizationCustomer ? {
                ...this.customer,
                accountId: null,
                leadId: null,
                contactId: null,
                companyName: this.lookupCriteria.companyName || this.customer.companyName || '',
                tradeLicenseNumber: this.lookupCriteria.tradeLicenseNumber || this.customer.tradeLicenseNumber || '',
                registeredEmail: this.lookupCriteria.registeredEmail || this.customer.registeredEmail || '',
                registeredPhone: this.lookupCriteria.registeredPhone || this.customer.registeredPhone || ''
            } : {
                ...this.customer,
                accountId: null,
                leadId: null,
                contactId: null,
                email: this.lookupCriteria.email || this.customer.email || '',
                phone: this.lookupCriteria.phone || this.customer.phone || '',
                nationality: this.customer.nationality || '',
                countryOfResidence: this.customer.countryOfResidence || '',
                emiratesId: this.lookupCriteria.emiratesId || this.customer.emiratesId || '',
                emiratesIdExpiryDate: this.customer.emiratesIdExpiryDate || '',
                passportNumber: this.sanitizePassportNumber(this.lookupCriteria.passportNumber || this.customer.passportNumber || ''),
                passportExpiryDate: this.customer.passportExpiryDate || ''
            };
            this.syncCustomerValidationFromLookup();
            this.matchMessage = 'No existing lead or account found. A new lead will be created and converted.';
        }
    }

    handleSelectCustomerMatch(event) {
        const recordId = event.currentTarget.dataset.recordId;
        const selected = this.customerMatches.find((match) => match.recordId === recordId);
        if (!selected) return;

        this.customerMatches = [];
        this.customerSource = selected.sourceType;
        this.isCustomerEditable = selected.sourceType === 'Lead';
        this.applySelectedCustomerMatch(selected);
    }

    applySelectedCustomerMatch(selected) {
        const selectedIsOrganization = selected.accountType === 'Organization';
        const nextCustomerType = selectedIsOrganization ? 'Organization' : 'Individual';
        this.customer = selectedIsOrganization ? {
            ...this.customer,
            customerType: nextCustomerType,
            accountId: selected.accountId || null,
            leadId: selected.leadId || null,
            contactId: selected.contactId || null,
            companyName: selected.companyName || selected.name || this.customer.companyName || '',
            tradeLicenseNumber: selected.tradeLicenseNumber || this.customer.tradeLicenseNumber || '',
            registeredEmail: selected.email === '-' ? '' : selected.email || this.customer.registeredEmail || '',
            registeredPhone: selected.phone === '-' ? '' : selected.phone || this.customer.registeredPhone || '',
            authorizedFirstName: selected.firstName || this.customer.authorizedFirstName || '',
            authorizedLastName: selected.lastName || this.customer.authorizedLastName || '',
            authorizedEmail: selected.email === '-' ? this.customer.authorizedEmail || '' : selected.email || this.customer.authorizedEmail || '',
            authorizedPhone: selected.phone === '-' ? this.customer.authorizedPhone || '' : selected.phone || this.customer.authorizedPhone || '',
            email: selected.email === '-' ? this.customer.authorizedEmail || this.customer.email || '' : selected.email || this.customer.authorizedEmail || this.customer.email || '',
            phone: selected.phone === '-' ? this.customer.authorizedPhone || this.customer.phone || '' : selected.phone || this.customer.authorizedPhone || this.customer.phone || ''
        } : {
            accountId: selected.accountId || null,
            leadId: selected.leadId || null,
            contactId: selected.contactId || null,
            customerType: nextCustomerType,
            firstName: selected.firstName || '',
            lastName: selected.lastName || '',
            email: selected.email || '',
            phone: selected.phone || '',
            residentStatus: this.normalizeResidentStatus(selected.residentStatus || this.customer.residentStatus || 'Resident'),
            nationality: selected.nationality || '',
            countryOfResidence: selected.countryOfResidence || '',
            emiratesId: selected.emiratesId || '',
            emiratesIdExpiryDate: selected.emiratesIdExpiryDate || '',
            passportNumber: selected.passportNumber || '',
            passportExpiryDate: selected.passportExpiryDate || ''
        };
        this.accountLockedFields = selected.sourceType === 'Account'
            ? this.buildAccountLockedFields(selected, selectedIsOrganization)
            : {};
        this.matchMessage = selected.sourceType === 'Account'
            ? (selected.hasPortalUser ? 'Existing portal customer selected.' : 'Existing account selected.')
            : 'Existing lead found. Details can be updated before conversion.';
    }

    toDisplayMatch(match) {
        const isOrganization = match.accountType === 'Organization';
        const displayFields = isOrganization
            ? [
                { key: 'company', label: 'Company', value: match.companyName || match.name || '-' },
                { key: 'tradeLicense', label: 'Trade License', value: match.tradeLicenseNumber || '-' },
                { key: 'email', label: 'Email', value: match.email || '-' },
                { key: 'phone', label: 'Phone', value: match.phone || '-' }
            ]
            : [
                { key: 'email', label: 'Email', value: match.email || '-' },
                { key: 'phone', label: 'Phone', value: match.phone || '-' },
                { key: 'passport', label: 'Passport', value: match.passportNumber || '-' },
                { key: 'emiratesId', label: 'Emirates ID', value: match.emiratesId || '-' },
                { key: 'residentStatus', label: 'Resident Status', value: match.residentStatus ? this.normalizeResidentStatus(match.residentStatus) : '-' }
            ];
        return {
            ...match,
            displayName: match.name || [match.firstName, match.lastName].filter(Boolean).join(' ') || match.recordId,
            accountTypeLabel: isOrganization ? 'Organization Account' : 'Person Account',
            portalLabel: match.hasPortalUser ? 'Portal User' : 'No Portal User',
            displayFields,
            residentStatus: match.residentStatus ? this.normalizeResidentStatus(match.residentStatus) : '-',
            nationality: match.nationality || '',
            countryOfResidence: match.countryOfResidence || '',
            email: match.email || '-',
            phone: match.phone || '-',
            emiratesId: match.emiratesId || '-',
            emiratesIdExpiryDate: match.emiratesIdExpiryDate || '',
            passportNumber: match.passportNumber || '-',
            passportExpiryDate: match.passportExpiryDate || '',
            companyName: isOrganization ? (match.companyName || match.name || '-') : '-',
            tradeLicenseNumber: match.tradeLicenseNumber || '-'
        };
    }

    syncCustomerValidationFromLookup() {
        const lookupEmail = (this.lookupCriteria.email || '').trim();
        const lookupPhone = (this.lookupCriteria.phone || '').trim();
        const customerEmail = (this.customer.email || '').trim();
        const customerPhone = (this.customer.phone || '').trim();
        if (lookupEmail && lookupEmail === customerEmail && this.contactValidation.lookupEmail) {
            this.contactValidation = { ...this.contactValidation, customerEmail: true };
            this.contactValidationValues = { ...this.contactValidationValues, customerEmail };
        }
        if (lookupPhone && lookupPhone === customerPhone && this.contactValidation.lookupPhone) {
            this.contactValidation = { ...this.contactValidation, customerPhone: true };
            this.contactValidationValues = { ...this.contactValidationValues, customerPhone };
        }
    }

    async handleCustomerNext() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            await this.runEoiValidation();
            if (this.isProjectClosed) return;
            const duplicateFound = await this.recheckCustomerBeforeVerification();
            if (duplicateFound) return;
            this.resetVerification();
            this.step = 2;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async recheckCustomerBeforeVerification() {
        if (this.customer.accountId || this.customerSource === 'Account' || this.customerSource === 'Multiple') {
            return false;
        }
        const request = this.buildPrepareCustomerRequest();
        const hasIdentifier = Boolean(
            this.isOrganizationCustomer
                ? ((request.companyName || '').trim()
                    || (request.tradeLicenseNumber || '').trim()
                    || (request.registeredEmail || '').trim()
                    || (request.registeredPhone || '').trim()
                    || (request.authorizedEmail || '').trim()
                    || (request.authorizedPhone || '').trim())
                : ((request.email || '').trim()
                    || (request.phone || '').trim()
                    || (request.emiratesId || '').trim()
                    || (request.passportNumber || '').trim())
        );
        if (!hasIdentifier) return false;

        const result = await searchCustomer({ request });
        const accountMatches = (result?.matches || [])
            .filter((match) => match.sourceType === 'Account')
            .map((match) => this.toDisplayMatch(match));
        if (accountMatches.length === 0) return false;

        if (accountMatches.length > 1) {
            this.customerMatches = accountMatches;
            this.customerSource = 'Multiple';
            this.isCustomerEditable = false;
            this.matchMessage = `${accountMatches.length} matching accounts found from the final details. Select the correct customer before continuing.`;
            this.errorMessage = 'Existing customer accounts were found using the entered details. Please select the correct account.';
            this.clearPreparedOpportunity();
            return true;
        }

        this.customerMatches = [];
        this.customerSource = 'Account';
        this.isCustomerEditable = false;
        this.applySelectedCustomerMatch(accountMatches[0]);
        this.errorMessage = 'An existing customer account was found using the entered details. The journey has been switched to the existing account.';
        this.clearPreparedOpportunity();
        return true;
    }

    buildPrepareCustomerRequest() {
        const request = {
            ...this.customer,
            projectId: this.selectedProjectId || null,
            projectInterest: this.selectedProjectName || ''
        };
        if (this.isOrganizationCustomer) {
            request.email = this.customer.authorizedEmail || this.customer.email || '';
            request.phone = this.customer.authorizedPhone || this.customer.phone || '';
            request.firstName = this.customer.authorizedFirstName || this.customer.firstName || '';
            request.lastName = this.customer.authorizedLastName || this.customer.lastName || '';
        }
        request.passportNumber = this.sanitizePassportNumber(request.passportNumber);
        if (this.isIndividualCustomer || this.isOrganizationCustomer) {
            request.passportExpiryDate = this.normalizeDateValue(request.passportExpiryDate);
            request.emiratesIdExpiryDate = this.showEmiratesId
                ? this.normalizeDateValue(request.emiratesIdExpiryDate)
                : null;
            if (!this.showEmiratesId) request.emiratesId = '';
        }
        request.tradeLicenseExpiryDate = this.normalizeDateValue(request.tradeLicenseExpiryDate);
        return request;
    }

    clearPreparedOpportunity() {
        this.opportunityId = null;
        this.accountId = null;
        this.contactId = null;
    }

    handleClearIdentity() {
        this.errorMessage = '';
        this.lookupIdentifierError = '';
        this.selectedProjectId = '';
        this.selectedProjectName = '';
        this.phaseOptions = [];
        this.unitTypeOptions = [];
        this.bedroomOptions = [];
        this.eoiRangeMatrix = [];
        this.resetEoiSelections();
        this.showQuota = false;
        this.quotaLimit = 0;
        this.quotaUsed = 0;
        this.quotaRemaining = 0;
        this.quotaExceeded = false;
        this.projectAvailabilityError = '';
        this.lookupCriteria = {
            emiratesId: '',
            passportNumber: '',
            phone: '',
            email: '',
            companyName: '',
            tradeLicenseNumber: '',
            registeredEmail: '',
            registeredPhone: ''
        };
        this.contactValidation = {
            lookupEmail: false,
            lookupPhone: false,
            customerEmail: false,
            customerPhone: false
        };
        this.contactValidationValues = {
            lookupEmail: '',
            lookupPhone: '',
            customerEmail: '',
            customerPhone: ''
        };
        this.validatingContactKey = '';
        this.createdEoiId = null;
        this.createdEoiReference = '';
        this.createdEoiReferences = [];
        this.createdAccountName = '';
        this.selectedPaymentMethod = 'Online';
        this.resetVerification();
        this.clearIdentityResult();
        this.autoSelectSingleProject();
    }

    clearIdentityResult() {
        this.identityVerified = false;
        this.matchMessage = '';
        this.customerMatches = [];
        this.customerSource = 'New';
        this.isCustomerEditable = true;
        this.accountLockedFields = {};
        this.customer = {
            accountId: null,
            leadId: null,
            contactId: null,
            customerType: this.customer.customerType || 'Individual',
            firstName: '',
            lastName: '',
            email: '',
            phone: '',
            residentStatus: 'Resident',
            nationality: '',
            countryOfResidence: '',
            emiratesId: '',
            emiratesIdExpiryDate: '',
            passportNumber: '',
            passportExpiryDate: '',
            companyName: '',
            tradeLicenseNumber: '',
            tradeLicenseExpiryDate: '',
            registeredEmail: '',
            registeredPhone: '',
            authorizedFirstName: '',
            authorizedLastName: '',
            authorizedEmail: '',
            authorizedPhone: ''
        };
        this.clearPreparedOpportunity();
    }

    async handleProjectChange(event) {
        await this.selectProject(event.target.value);
    }

    async selectProject(projectId) {
        this.selectedProjectId = projectId;
        const selected = this.projectOptions.find((option) => option.value === this.selectedProjectId);
        this.selectedProjectName = selected ? selected.label : '';
        this.phaseOptions = [];
        this.unitTypeOptions = [];
        this.bedroomOptions = [];
        this.eoiRangeMatrix = [];
        this.resetEoiSelections();
        this.showQuota = false;
        this.quotaExceeded = false;
        this.projectAvailabilityError = '';
        if (!this.isOpportunityActionMode) {
            this.clearIdentityResult();
        }

        if (!this.selectedProjectId) return;

        this.isLoading = true;
        try {
            this.eoiRangeMatrix = await getEoiRangeMatrix({ projectId: this.selectedProjectId });
            this.phaseOptions = this.getPhaseOptionsFromMatrix();
            this.recascadeEoiSelections();
            await this.runEoiValidation();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    createEmptyEoiSelection() {
        this.eoiSelectionCounter += 1;
        return {
            key: `eoi-${Date.now()}-${this.eoiSelectionCounter}`,
            label: `EOI ${this.eoiSelectionCounter}`,
            phaseId: '',
            phaseName: '',
            unitType: '',
            unitTypeLabel: '',
            bedrooms: '',
            bedroomsLabel: '',
            unitTypology: '',
            unitTypologyLabel: '',
            unitTypeOptions: [],
            bedroomOptions: [],
            unitTypologyOptions: [],
            loadingBedroomOptions: false,
            showPhase: false,
            phaseDisabled: false,
            showUnitType: false,
            unitTypeDisabled: false,
            showBedrooms: false,
            bedroomsDisabled: false,
            showTypology: false,
            typologyDisabled: false,
            eoiRangeId: null,
            eoiAmount: null,
            displayAmount: 'AED 0',
            summaryTitle: 'Pending Selection',
            summarySubtitle: 'Complete unit details',
            summaryClass: 'selection-summary-item'
        };
    }

    resetEoiSelections() {
        this.eoiSelectionCounter = 0;
        const selection = this.createEmptyEoiSelection();
        this.activeEoiSelectionKey = selection.key;
        this.eoiSelections = [this.enrichEoiSelection(this.cascadeSelection(selection))];
    }

    updateEoiSelection(key, changes) {
        this.eoiSelections = this.eoiSelections.map((selection) => (
            selection.key === key ? this.enrichEoiSelection({ ...selection, ...changes }) : selection
        ));
    }

    /** Applies a user picklist change, then lets the cascade re-derive every level below it. */
    applySelectionChange(key, changes) {
        if (!key) return;
        this.eoiSelections = this.eoiSelections.map((selection) => (
            selection.key === key
                ? this.enrichEoiSelection(this.cascadeSelection({ ...selection, ...changes }))
                : selection
        ));
    }

    /** Re-runs the cascade on every EOI card, e.g. after a new project's matrix arrives. */
    recascadeEoiSelections() {
        this.eoiSelections = this.eoiSelections.map((selection) => (
            this.enrichEoiSelection(this.cascadeSelection(selection))
        ));
    }

    enrichEoiSelection(selection) {
        const titleParts = [this.selectedProjectName, selection.phaseName].filter(Boolean);
        const subtitleParts = [
            selection.unitTypologyLabel || selection.unitTypology,
            selection.bedroomsLabel || selection.bedrooms,
            selection.unitTypeLabel || selection.unitType
        ]
            .filter(Boolean);
        return {
            ...selection,
            summaryTitle: titleParts.length ? titleParts.join(' - ') : 'Pending Selection',
            summarySubtitle: subtitleParts.length ? subtitleParts.join(' ') : 'Complete unit details',
            summaryClass: selection.key === this.activeEoiSelectionKey
                ? 'selection-summary-item active'
                : 'selection-summary-item'
        };
    }

    getOptionLabel(options, value) {
        return (options || []).find((option) => option.value === value)?.label || value || '';
    }

    toUniqueOptions(values) {
        const seen = new Set();
        return (values || [])
            .filter((value) => value !== null && value !== undefined && String(value).trim())
            .filter((value) => {
                if (seen.has(value)) return false;
                seen.add(value);
                return true;
            })
            .map((value) => ({ label: value, value }));
    }

    getPhaseOptionsFromMatrix() {
        const seen = new Set();
        const options = [];
        (this.eoiRangeMatrix || []).forEach((row) => {
            if (!row.phaseId || seen.has(row.phaseId)) return;
            seen.add(row.phaseId);
            options.push({ label: row.phaseName || row.phaseId, value: row.phaseId });
        });
        return options;
    }

    getRowsForSelection(selection, overrides = {}) {
        const pick = (field) => (overrides[field] !== undefined ? overrides[field] : selection?.[field]);
        const phaseId = pick('phaseId');
        const unitType = pick('unitType');
        const bedrooms = pick('bedrooms');
        const unitTypology = pick('unitTypology');
        return (this.eoiRangeMatrix || []).filter((row) => (
            (!phaseId || row.phaseId === phaseId)
            && (!unitType || row.unitType === unitType)
            && (!bedrooms || row.bedrooms === bedrooms)
            && (!unitTypology || row.unitTypology === unitTypology)
        ));
    }

    /**
     * Decides how one cascading picklist renders for the options the EOI Ranges leave it:
     *  - no options at all  -> hide it, the level does not apply to this project
     *  - exactly one option -> preselect that value and lock the field, there is nothing to choose
     *  - several options    -> show it, keeping the current value only while it is still valid
     * While an upstream level is still unanswered the field stays visible but disabled, so the
     * card does not reflow as the user works down it.
     */
    resolveCascadeLevel(options, currentValue, upstreamPending) {
        if (upstreamPending) return { show: true, disabled: true, value: '', options: [] };
        if (!options.length) return { show: false, disabled: false, value: '', options: [] };
        if (options.length === 1) return { show: true, disabled: true, value: options[0].value, options };
        const isStillValid = options.some((option) => option.value === currentValue);
        return { show: true, disabled: false, value: isStillValid ? currentValue : '', options };
    }

    cascadeSelection(selection) {
        const next = { ...selection, loadingBedroomOptions: false };

        const phase = this.resolveCascadeLevel(this.phaseOptions, next.phaseId, false);
        next.showPhase = phase.show;
        next.phaseDisabled = phase.disabled;
        next.phaseId = phase.value;
        next.phaseName = phase.value ? this.getOptionLabel(this.phaseOptions, phase.value) : '';
        let pending = phase.show && !phase.value;

        const unitTypeRows = pending ? [] : this.getRowsForSelection(null, { phaseId: next.phaseId });
        const unitType = this.resolveCascadeLevel(
            this.toUniqueOptions(unitTypeRows.map((row) => row.unitType)),
            next.unitType,
            pending
        );
        next.showUnitType = unitType.show;
        next.unitTypeDisabled = unitType.disabled;
        next.unitTypeOptions = unitType.options;
        next.unitType = unitType.value;
        next.unitTypeLabel = unitType.value;
        pending = pending || (unitType.show && !unitType.value);

        const bedroomRows = pending
            ? []
            : this.getRowsForSelection(null, { phaseId: next.phaseId, unitType: next.unitType });
        const bedrooms = this.resolveCascadeLevel(
            this.toUniqueOptions(bedroomRows.map((row) => row.bedrooms)),
            next.bedrooms,
            pending
        );
        next.showBedrooms = bedrooms.show;
        next.bedroomsDisabled = bedrooms.disabled;
        next.bedroomOptions = bedrooms.options;
        next.bedrooms = bedrooms.value;
        next.bedroomsLabel = bedrooms.value;
        pending = pending || (bedrooms.show && !bedrooms.value);

        const typologyRows = pending
            ? []
            : this.getRowsForSelection(null, {
                phaseId: next.phaseId,
                unitType: next.unitType,
                bedrooms: next.bedrooms
            });
        const typology = this.resolveCascadeLevel(
            this.toUniqueOptions(typologyRows.map((row) => row.unitTypology)),
            next.unitTypology,
            false
        );
        next.showTypology = typology.show;
        next.typologyDisabled = typology.disabled;
        next.unitTypologyOptions = typology.options;
        next.unitTypology = typology.value;
        next.unitTypologyLabel = typology.value;
        pending = pending || (typology.show && !typology.value);

        return this.resolveRangeForSelection(next, pending);
    }

    resolveRangeForSelection(selection, pending) {
        const next = { ...selection, eoiRangeId: null, eoiAmount: null, displayAmount: 'AED 0' };
        if (pending || !this.eoiRangeMatrix?.length) return next;

        const rows = this.getRowsForSelection(null, {
            phaseId: next.phaseId,
            unitType: next.unitType,
            bedrooms: next.bedrooms,
            unitTypology: next.unitTypology
        });
        const range = next.showTypology
            ? rows.find((row) => row.unitTypology === next.unitTypology)
            : rows.find((row) => !row.unitTypology) || rows[0];
        if (!range) return next;

        next.eoiRangeId = range.rangeId;
        next.eoiAmount = range.amount;
        next.displayAmount = this.formatCurrency(range.amount);
        return next;
    }

    handleSelectionPhaseChange(event) {
        this.applySelectionChange(event.target.dataset.selectionKey, { phaseId: event.target.value });
    }

    handleSelectionUnitTypeChange(event) {
        this.applySelectionChange(event.target.dataset.selectionKey, { unitType: event.target.value });
    }

    handleSelectionBedroomsChange(event) {
        this.applySelectionChange(event.target.dataset.selectionKey, { bedrooms: event.target.value });
    }

    handleSelectionTypologyChange(event) {
        this.applySelectionChange(event.target.dataset.selectionKey, { unitTypology: event.target.value });
    }

    handleAddEoiSelection() {
        if (this.isAddEoiDisabled) return;
        const selection = this.cascadeSelection(this.createEmptyEoiSelection());
        this.activeEoiSelectionKey = selection.key;
        this.eoiSelections = [...this.eoiSelections, selection]
            .map((item) => this.enrichEoiSelection(item));
    }

    handleRemoveEoiSelection(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.selectionKey;
        if (this.eoiSelections.length === 1) return;
        const remainingSelections = this.eoiSelections.filter((selection) => selection.key !== key);
        if (this.activeEoiSelectionKey === key) {
            this.activeEoiSelectionKey = remainingSelections[0]?.key || '';
        }
        this.eoiSelections = remainingSelections.map((selection) => this.enrichEoiSelection(selection));
    }

    handleSelectEoiSelection(event) {
        const key = event.currentTarget.dataset.selectionKey;
        if (!key) return;
        this.activeEoiSelectionKey = key;
        this.eoiSelections = this.eoiSelections.map((selection) => this.enrichEoiSelection(selection));
    }

    resetVerification() {
        this.clearResendCooldownTimer();
        this.verificationMethod = '';
        this.verificationMessage = '';
        this.verificationCompleted = false;
        this.verificationRequestId = null;
        this.isSendingVerification = false;
        this.resendCooldownSeconds = 0;
        this.resendAvailableAt = null;
        this.maxResendReached = false;
        this.verificationDigits = Array.from({ length: 6 }, (_value, index) => ({
            key: `otp-${index}`,
            index,
            value: ''
        }));
    }

    async handleVerificationMethod(event) {
        const method = event.currentTarget.dataset.method;
        if (method === 'whatsapp') {
            this.errorMessage = 'WhatsApp verification is not configured yet. Please use Email or SMS Verification.';
            return;
        }
        await this.sendVerificationCode(method, false);
    }

    handleVerificationCodeInput(event) {
        const index = Number(event.currentTarget.dataset.otpIndex);
        const value = (event.target.value || '').replace(/\D/g, '').slice(-1);
        event.target.value = value;
        this.verificationDigits = this.verificationDigits.map((digit) => (
            digit.index === index ? { ...digit, value } : digit
        ));

        if (value && index < 5) {
            this.pendingOtpFocusIndex = index + 1;
            requestAnimationFrame(() => {
                const nextInput = this.template.querySelector(`input[data-otp-index="${index + 1}"]`);
                if (nextInput) nextInput.focus();
            });
        }
    }

    async handleVerificationResend() {
        if (!this.verificationRequestId) {
            await this.sendVerificationCode(this.verificationMethod || 'email', false);
            return;
        }
        this.errorMessage = '';
        this.isSendingVerification = true;
        try {
            const result = await resendVerification({ verificationRequestId: this.verificationRequestId });
            this.verificationMessage = result.message || `A new 6-digit code has been sent to your ${this.verificationDestinationName}.`;
            this.startResendCooldown(result.resendAvailableAt);
            this.maxResendReached = false;
            this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
            this.pendingOtpFocusIndex = 0;
        } catch (error) {
            const message = this.reduceError(error);
            this.errorMessage = message;
            if (message && message.toLowerCase().includes('maximum resend count reached')) {
                this.maxResendReached = true;
                this.verificationMessage = 'Maximum resend attempts reached. Please use the latest code received or restart verification.';
            }
        } finally {
            this.isSendingVerification = false;
        }
    }

    async handleVerificationNext() {
        this.errorMessage = '';
        if (this.opportunityId) {
            this.step = 3;
            return;
        }
        this.isLoading = true;
        try {
            await this.verifySelectedVerificationCode();
            await this.runEoiValidation();
            if (this.isProjectClosed) return;
            const result = await prepareOpportunity({ request: this.buildPrepareCustomerRequest() });
            this.opportunityId = result.opportunityId;
            this.accountId = result.accountId;
            this.contactId = result.contactId;
            this.verificationCompleted = true;
            this.step = 3;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async sendVerificationCode(method, isResend) {
        this.errorMessage = '';
        const normalizedMethod = method === 'sms' ? 'sms' : 'email';
        const channel = normalizedMethod === 'sms' ? 'SMS' : 'Email';
        const target = normalizedMethod === 'sms' ? this.verificationPhoneTarget : this.verificationEmailTarget;
        if (normalizedMethod === 'email' && !target) {
            this.errorMessage = 'Customer email is required for email verification.';
            return;
        }
        if (normalizedMethod === 'sms' && !target) {
            this.errorMessage = 'Customer phone number is required for SMS verification.';
            return;
        }

        this.verificationMethod = normalizedMethod;
        this.verificationMessage = isResend
            ? 'Sending a new verification code...'
            : 'Sending verification code...';
        this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
        this.isSendingVerification = true;
        try {
            const request = {
                channel,
                target,
                context: 'EOI_HOME',
                contextKey: this.selectedProjectId || null
            };
            const result = await startVerification({ request });
            this.verificationRequestId = result.verificationRequestId;
            this.maxResendReached = false;
            const destination = normalizedMethod === 'sms' ? 'mobile number' : 'email';
            this.verificationMessage = isResend
                ? `A new 6-digit code has been sent to your ${destination}.`
                : (result.message || `A 6-digit code has been sent to your ${destination}.`);
            this.startResendCooldown(result.resendAvailableAt);
            this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
            this.pendingOtpFocusIndex = 0;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSendingVerification = false;
        }
    }

    async verifySelectedVerificationCode() {
        if (!this.verificationRequestId) {
            throw new Error('Please send a verification code before continuing.');
        }
        const code = this.verificationDigits.map((digit) => digit.value).join('');
        if (code.length !== 6) {
            throw new Error('Please enter the 6-digit verification code.');
        }
        const result = await verifyCode({
            verificationRequestId: this.verificationRequestId,
            code
        });
        if (!result || result.status !== 'Verified') {
            throw new Error(result?.message || 'Verification was not completed.');
        }
        this.verificationCompleted = true;
        this.clearResendCooldownTimer();
    }

    startResendCooldown(resendAvailableAt) {
        this.clearResendCooldownTimer();
        this.resendAvailableAt = resendAvailableAt;
        this.updateResendCooldown();
        if (this.resendCooldownSeconds <= 0) return;
        this.resendCooldownTimer = window.setInterval(() => {
            this.updateResendCooldown();
            if (this.resendCooldownSeconds <= 0) {
                this.clearResendCooldownTimer();
            }
        }, 1000);
    }

    updateResendCooldown() {
        if (!this.resendAvailableAt) {
            this.resendCooldownSeconds = 0;
            return;
        }
        const availableTime = new Date(this.resendAvailableAt).getTime();
        if (Number.isNaN(availableTime)) {
            this.resendCooldownSeconds = 0;
            return;
        }
        this.resendCooldownSeconds = Math.max(0, Math.ceil((availableTime - Date.now()) / 1000));
    }

    clearResendCooldownTimer() {
        if (this.resendCooldownTimer) {
            window.clearInterval(this.resendCooldownTimer);
            this.resendCooldownTimer = null;
        }
    }

    async runEoiValidation() {
        if (!this.selectedProjectId) return;
        const result = await validateEOI({
            opportunityId: null,
            projectId: this.selectedProjectId
        });
        this.quotaLimit = result.quotaLimit;
        this.quotaUsed = result.quotaUsed;
        this.quotaRemaining = result.quotaRemaining;
        this.quotaExceeded = result.quotaExceeded;
        this.projectAvailabilityError = result.quotaExceeded
            ? `Expression of Interest (EOI) for this project is currently closed. We are no longer accepting new submissions for ${this.selectedProjectName}.`
            : '';
        this.showQuota = true;
    }

    handleEoiInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = this.getInputValue(event);
    }

    async validateEmailInput(event) {
        const key = event.target.dataset.validationKey;
        await this.validateEmailElement(event.target, key, true);
    }

    async validatePhoneInput(event) {
        const key = event.target.dataset.validationKey;
        await this.validatePhoneElement(event.target, key, true);
    }

    async handleEoiDetailsNext() {
        await this.handleFinish();
    }

    async handleFinish() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            await this.runEoiValidation();
            if (this.isProjectClosed) return;
            if (this.hasQuotaCountError) {
                this.errorMessage = `Only ${this.quotaRemaining} EOI submission(s) are remaining for this project.`;
                return;
            }
            const result = await createEoiAndOptionalReceipt({
                request: this.buildEoiRequest()
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: result.eoiReferences?.length > 1 ? 'EOIs created successfully.' : 'EOI created successfully.',
                variant: 'success'
            }));
            this.createdEoiId = result.eoiId;
            this.createdEoiReference = result.eoiReference || '';
            this.createdEoiReferences = result.eoiReferences || [];
            this.createdAccountName = result.accountName || '';
            this.accountId = result.accountId || this.accountId;
            this.step = 4;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    buildEoiRequest() {
        return {
            opportunityId: this.opportunityId,
            projectId: this.selectedProjectId,
            paymentType: this.paymentTypeLabel,
            remarks: '',
            selections: this.eoiSelections.map((selection) => ({
                phaseId: selection.phaseId,
                unitType: selection.unitType,
                bedrooms: selection.bedrooms,
                unitTypology: selection.unitTypology,
                eoiRangeId: selection.eoiRangeId,
                eoiAmount: selection.eoiAmount
            }))
        };
    }

    // ── Checkout payment (Online) ─────────────────────────────────────────────
    _buildSelectionPayload(selection) {
        return JSON.stringify({
            opportunityId: this.opportunityId,
            projectId:     this.selectedProjectId,
            phaseId:       selection.phaseId,
            unitType:      selection.unitType,
            bedrooms:      selection.bedrooms,
            unitTypology:  selection.unitTypology,
            numberOfUnits: 1,
            eoiRangeId:    selection.eoiRangeId,
            eoiAmount:     selection.eoiAmount,
            remarks:       '',
            paymentType:   'Online'
        });
    }

    async _preFlightPassed() {
        await this.runEoiValidation();
        if (this.isProjectClosed) return false;
        if (this.hasQuotaCountError) {
            this.errorMessage = `Only ${this.quotaRemaining} EOI submission(s) are remaining for this project.`;
            return false;
        }
        return true;
    }

    // Send link: one payment link per selection (N links). EOIs created on capture.
    async handleSendLinkWizard() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            if (!(await this._preFlightPassed())) return;
            let anyFailure = false;
            for (const selection of this.eoiSelections) {
                const res = await sendPaymentLink({ eoiPayloadJson: this._buildSelectionPayload(selection) });
                if (!res || !res.isSuccess) anyFailure = true;
                console.log(res);
            }
            if (anyFailure) {
                this.errorMessage = 'Some payment links could not be created. Please try again.';
                return;
            }
            this.createdEoiId = null;
            this.createdEoiReferences = [];
            this.paymentOutcome = 'link-sent';
            this.step = 4;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // Pay now (single selection): Hosted Payments Page - same-tab redirect to Checkout.
    // On return, the CheckoutReturn VF page confirms the payment and creates the EOI on the spot;
    // the background poller is the fallback. Return URLs are built server-side (carry the reference).
    async handlePayNowWizard() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            if (!(await this._preFlightPassed())) return;
            const selection = this.eoiSelections[0];
            const res = await payNowHosted({
                eoiPayloadJson: this._buildSelectionPayload(selection)
            });
            if (res && res.isSuccess && res.paymentLinkUrl) {
                window.location.href = res.paymentLinkUrl; // same-tab redirect to the hosted page
            } else {
                this.errorMessage = (res && res.message) ? res.message : 'Could not start the payment.';
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    handleBack() {
        this.errorMessage = '';
        if (this.isOpportunityActionMode && this.step === 3) return;
        if (this.verificationCompleted && this.step === 3) return;
        this.step = Math.max(1, this.step - 1);
    }

    handleReturnHome() {
        this.showModal = false;
        this.step = 1;
        this.errorMessage = '';
        this.matchMessage = '';
        if (this.isOpportunityActionMode) {
            this.isOpportunityActionMode = false;
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    handleViewEoi() {
        if (this.createdEoiId) {
            this.navigateToRecord(this.createdEoiId, 'Expressionofinterest__c');
        }
    }

    get isStepCustomer() {
        return this.step === 1;
    }

    get isStepVerification() {
        return this.step === 2;
    }

    get isStepEoi() {
        return this.step === 3;
    }

    get isStepSuccess() {
        return this.step === 4;
    }

    get isOpportunityContext() {
        return Boolean(this.recordId)
            && (this.objectApiName === 'Opportunity' || String(this.recordId).startsWith('006'));
    }

    get showLauncher() {
        return !this.isOpportunityActionMode;
    }

    get showJourney() {
        return this.showModal || this.isOpportunityActionMode;
    }

    get customerStepClass() {
        if (this.isOpportunityActionMode) return 'done';
        if (this.step > 1) return 'done';
        return this.isStepCustomer ? 'active' : '';
    }

    get verificationStepClass() {
        if (this.isOpportunityActionMode) return 'done';
        if (this.step > 2) return 'done';
        return this.isStepVerification ? 'active' : '';
    }

    get eoiStepClass() {
        if (this.step > 3) return 'done';
        return this.isStepEoi ? 'active' : '';
    }

    get receiptStepClass() {
        return this.isStepSuccess ? 'active' : '';
    }

    get eoiNextLabel() {
        return 'Create EOI';
    }

    // Online routes through Checkout; the offline types create the EOI immediately (Create EOI).
    get isOnlinePayment() { return this.selectedPaymentMethod === 'Online'; }
    get isPaymentDisabled() { return this.isEoiNextDisabled; }

    // Below the summary (Online): a radio to choose the Checkout method, and one toggling action button.
    // Pay now is offered only for a single selection (a redirect covers one payment).
    get checkoutMethodOptions() {
        // Single selection: Pay now first (primary/default), then Send link. Multi: Send links only.
        if (!this.isSingleEoiSelection) return [{ label: 'Send links', value: 'send' }];
        return [{ label: 'Pay now', value: 'pay' }, { label: 'Send link', value: 'send' }];
    }

    // Card-style tiles (icon + label) for the Checkout method selection.
    get checkoutMethodTiles() {
        return this.checkoutMethodOptions.map((option) => ({
            value: option.value,
            label: option.label,
            iconName: option.value === 'pay' ? 'utility:payment_gateway' : 'utility:link',
            cardClass: option.value === this.effectiveCheckoutMethod
                ? 'checkout-method-tile selected'
                : 'checkout-method-tile'
        }));
    }

    get effectiveCheckoutMethod() {
        return 'send';
    }

    get checkoutActionLabel() {
        if (this.effectiveCheckoutMethod === 'pay') return this.isLoading ? 'Processing…' : 'Pay now';
        return this.isLoading ? 'Sending…' : (this.isSingleEoiSelection ? 'Send link' : 'Send links');
    }

    handleCheckoutMethodSelect(event) {
        this.checkoutMethod = event.currentTarget.dataset.method;
    }

    handleCheckoutAction() {
        if (this.effectiveCheckoutMethod === 'pay') {
            this.handlePayNowWizard();
        } else {
            this.handleSendLinkWizard();
        }
    }

    get hasCreatedEoi() {
        return Boolean(this.createdEoiId) || (this.createdEoiReferences && this.createdEoiReferences.length > 0);
    }

    get successTitle() {
        return this.paymentOutcome === 'link-sent' ? 'Payment Link Sent' : 'EOI Successfully Created';
    }

    get successSubtitle() {
        return this.paymentOutcome === 'link-sent'
            ? 'The EOI will be created once the customer completes payment.'
            : 'The customer, opportunity, and EOI records are ready for the next step.';
    }

    get showEmiratesId() {
        return this.normalizeResidentStatus(this.customer.residentStatus) === 'Resident';
    }

    get showPassportFields() {
        return !this.showEmiratesId;
    }

    get isPassportRequired() {
        return !this.showEmiratesId;
    }

    get isOrganizationCustomer() {
        return this.customer.customerType === 'Organization';
    }

    get isIndividualCustomer() {
        return !this.isOrganizationCustomer;
    }

    get verificationEmailTarget() {
        return this.isOrganizationCustomer ? this.customer.authorizedEmail : this.customer.email;
    }

    get verificationPhoneTarget() {
        return this.isOrganizationCustomer ? this.customer.authorizedPhone : this.customer.phone;
    }

    get customerFieldsDisabled() {
        return !this.identityVerified || this.showMatchSelection || !this.isCustomerEditable;
    }

    get authorizedContactFieldsDisabled() {
        return !this.identityVerified || this.showMatchSelection;
    }

    get companyNameDisabled() {
        return this.isAccountFieldLocked('companyName');
    }

    get tradeLicenseNumberDisabled() {
        return this.isAccountFieldLocked('tradeLicenseNumber');
    }

    get tradeLicenseExpiryDateDisabled() {
        return this.isAccountFieldLocked('tradeLicenseExpiryDate');
    }

    get registeredEmailDisabled() {
        return this.isAccountFieldLocked('registeredEmail');
    }

    get registeredPhoneDisabled() {
        return this.isAccountFieldLocked('registeredPhone');
    }

    get authorizedFirstNameDisabled() {
        return this.isAccountFieldLocked('authorizedFirstName');
    }

    get authorizedLastNameDisabled() {
        return this.isAccountFieldLocked('authorizedLastName');
    }

    get authorizedEmailDisabled() {
        return this.isAccountFieldLocked('authorizedEmail');
    }

    get authorizedPhoneDisabled() {
        return this.isAccountFieldLocked('authorizedPhone');
    }

    get firstNameDisabled() {
        return this.isAccountFieldLocked('firstName');
    }

    get lastNameDisabled() {
        return this.isAccountFieldLocked('lastName');
    }

    get emailDisabled() {
        return this.isAccountFieldLocked('email');
    }

    get phoneDisabled() {
        return this.isAccountFieldLocked('phone');
    }

    get emiratesIdDisabled() {
        return this.isAccountFieldLocked('emiratesId');
    }

    get passportNumberDisabled() {
        return this.isAccountFieldLocked('passportNumber');
    }

    get nationalityDisabled() {
        return this.isAccountFieldLocked('nationality');
    }

    get countryOfResidenceDisabled() {
        return this.isAccountFieldLocked('countryOfResidence');
    }

    get customerBadgeLabel() {
        if (this.customerSource === 'Multiple') return 'Select Account';
        if (this.customerSource === 'Account') return 'Existing Account';
        if (this.customerSource === 'Lead') return 'Existing Lead';
        return 'New Customer';
    }

    get hasMissingRequiredCustomerFields() {
        if (this.isOrganizationCustomer) {
            return !this.customer.companyName
                || !this.customer.tradeLicenseNumber
                || (this.showEmiratesId && !this.customer.emiratesId)
                || (this.isPassportRequired && !this.customer.passportNumber)
                || !this.customer.authorizedFirstName
                || !this.customer.authorizedLastName
                || !this.customer.authorizedEmail
                || !this.customer.authorizedPhone;
        }

        return !this.customer.firstName
            || !this.customer.lastName
            || !this.customer.email
            || !this.customer.phone
            || !this.customer.nationality
            || !this.customer.countryOfResidence
            || (this.showEmiratesId && !this.customer.emiratesId)
            || (this.isPassportRequired && !this.customer.passportNumber);
    }

    get identityNoticeTitle() {
        if (!this.identityVerified) return 'Identity verification required.';
        if (this.customerSource === 'Multiple') return 'Multiple accounts found.';
        if (this.customerSource === 'Account') return 'Record found as Account.';
        if (this.customerSource === 'Lead') return 'Record found as Lead.';
        return 'New customer record.';
    }

    get identityNoticeText() {
        if (!this.identityVerified) return 'Verify identity from the left panel before entering personal details.';
        if (this.customerSource === 'Multiple') return 'Select the correct account from the matching customer list before continuing.';
        if (this.customerSource === 'Account') return 'Existing values are locked. Complete any required fields that are still blank.';
        if (this.customerSource === 'Lead') return 'Fields are editable to update the latest information before conversion.';
        return this.isOrganizationCustomer
            ? 'Complete company and authorized contact details to create and convert a lead.'
            : 'Complete the details below to create and convert a lead.';
    }

    isAccountFieldLocked(fieldName) {
        if (!this.identityVerified || this.showMatchSelection) return true;
        return !this.isCustomerEditable && Boolean(this.accountLockedFields[fieldName]);
    }

    buildAccountLockedFields(selected, selectedIsOrganization) {
        const hasValue = (value) => Boolean(value && value !== '-');
        if (selectedIsOrganization) {
            return {
                companyName: hasValue(selected.companyName || selected.name),
                tradeLicenseNumber: hasValue(selected.tradeLicenseNumber),
                registeredEmail: hasValue(selected.email),
                registeredPhone: hasValue(selected.phone),
                emiratesId: hasValue(selected.emiratesId),
                passportNumber: hasValue(selected.passportNumber),
                authorizedFirstName: hasValue(selected.firstName),
                authorizedLastName: hasValue(selected.lastName),
                authorizedEmail: hasValue(selected.email),
                authorizedPhone: hasValue(selected.phone)
            };
        }
        return {
            firstName: hasValue(selected.firstName),
            lastName: hasValue(selected.lastName),
            email: hasValue(selected.email),
            phone: hasValue(selected.phone),
            emiratesId: hasValue(selected.emiratesId),
            passportNumber: hasValue(selected.passportNumber),
            nationality: hasValue(selected.nationality),
            countryOfResidence: hasValue(selected.countryOfResidence)
        };
    }

    get showMatchSelection() {
        return this.customerMatches.length > 1;
    }

    get isProjectSelected() {
        return Boolean(this.selectedProjectId);
    }

    get isProjectClosed() {
        return this.showQuota && this.quotaExceeded;
    }

    get identityInputsDisabled() {
        return !this.isProjectSelected || this.isProjectClosed || this.isLoading;
    }

    get isSingleProject() {
        return this.projectOptions.length === 1;
    }

    /** Step 1 "Project Interest" — only locked when there is a single project to pick. */
    get projectInterestDisabled() {
        return this.isSingleProject;
    }

    /** Step 3 "Project Selection" — locked outside the Opportunity action, or when there is only one project. */
    get projectSelectionDisabled() {
        return !this.isOpportunityActionMode || this.isSingleProject;
    }

    get showProjectGate() {
        return !this.isProjectSelected || this.isProjectClosed;
    }

    get projectGateTitle() {
        return this.isProjectClosed ? 'EOI Submission Closed' : 'No Project Selected';
    }

    get projectGateText() {
        if (this.isProjectClosed) {
            return this.projectAvailabilityError;
        }
        return 'Please select a project from the left panel to begin. Project selection is required to check inventory availability and verify customer eligibility for this specific development.';
    }

    get projectGateHint() {
        return this.isProjectClosed ? 'Select another project to continue' : 'Start by choosing a project';
    }

    get identityStepStatus() {
        if (!this.isProjectSelected) return 'Pending Project Selection';
        if (this.isProjectClosed) return 'EOI Submission Closed';
        if (!this.identityVerified) return 'Pending Identity Verification';
        return 'Identity Verification Completed';
    }

    get isVerifyIdentityDisabled() {
        const hasEmail = Boolean(((this.isOrganizationCustomer ? this.lookupCriteria.registeredEmail : this.lookupCriteria.email) || '').trim());
        const hasPhone = Boolean(((this.isOrganizationCustomer ? this.lookupCriteria.registeredPhone : this.lookupCriteria.phone) || '').trim());
        return this.isLoading
            || this.isValidatingEmail
            || this.isValidatingPhone
            || !this.selectedProjectId
            || this.isProjectClosed
            || (hasEmail && !this.contactValidation.lookupEmail)
            || (hasPhone && !this.contactValidation.lookupPhone);
    }

    get isCustomerNextDisabled() {
        const requiresPersonalDetails = this.customerSource !== 'Account';
        if (this.isOrganizationCustomer) {
            const hasOrganizationErrors = (
                !this.contactValidation.customerEmail
                || !this.contactValidation.customerPhone
                || (this.showEmiratesId && !this.isValidEmiratesId(this.customer.emiratesId))
            );
            const missingResidentDocument = this.showEmiratesId
                && !this.customer.emiratesId;
            const missingPassportDocument = this.isPassportRequired
                && !this.customer.passportNumber;
            return this.isLoading
                || this.isValidatingEmail
                || this.isValidatingPhone
                || !this.identityVerified
                || this.showMatchSelection
                || !this.selectedProjectId
                || this.isProjectClosed
                || (requiresPersonalDetails && !this.customer.companyName)
                || (requiresPersonalDetails && !this.customer.tradeLicenseNumber)
                || missingResidentDocument
                || missingPassportDocument
                || !this.customer.authorizedFirstName
                || !this.customer.authorizedLastName
                || !this.customer.authorizedEmail
                || !this.customer.authorizedPhone
                || hasOrganizationErrors;
        }
        const hasDetailErrors = requiresPersonalDetails && (
            !this.contactValidation.customerEmail
            || !this.contactValidation.customerPhone
            || (this.showEmiratesId && !this.isValidEmiratesId(this.customer.emiratesId))
        );
        const missingResidentDocument = requiresPersonalDetails
            && this.showEmiratesId
            && !this.customer.emiratesId;
        const missingPassportDocument = requiresPersonalDetails
            && this.isPassportRequired
            && !this.customer.passportNumber;
        return this.isLoading
            || this.isValidatingEmail
            || this.isValidatingPhone
            || !this.identityVerified
            || this.showMatchSelection
            || !this.selectedProjectId
            || this.isProjectClosed
            || (requiresPersonalDetails && !this.customer.firstName)
            || (requiresPersonalDetails && !this.customer.lastName)
            || (requiresPersonalDetails && !this.customer.email)
            || (requiresPersonalDetails && !this.customer.phone)
            || (requiresPersonalDetails && !this.customer.nationality)
            || (requiresPersonalDetails && !this.customer.countryOfResidence)
            || missingResidentDocument
            || missingPassportDocument
            || hasDetailErrors
            || this.isProjectClosed;
    }

    get eoiReferenceLabel() {
        return this.createdEoiReference || (this.createdEoiId ? String(this.createdEoiId).substring(0, 15) : 'Pending');
    }

    get hasMultipleCreatedEois() {
        return this.createdEoiReferences.length > 1;
    }

    get isSingleEoiSelection() {
        return this.eoiSelections.length === 1;
    }

    get activeEoiSelection() {
        return this.eoiSelections.find((selection) => selection.key === this.activeEoiSelectionKey)
            || this.eoiSelections[0];
    }

    get hasActiveEoiSelection() {
        return Boolean(this.activeEoiSelection);
    }

    get accountSummaryLabel() {
        if (this.isOrganizationCustomer) {
            return this.createdAccountName || this.customer.companyName || this.accountId || 'Pending';
        }
        const customerName = [this.customer.firstName, this.customer.lastName].filter(Boolean).join(' ').trim();
        return this.createdAccountName || customerName || this.accountId || 'Pending';
    }

    get calculatedAmount() {
        return this.eoiSelections.reduce((total, selection) => total + (Number(selection.eoiAmount) || 0), 0);
    }

    get displayAmount() {
        return this.formatCurrency(this.calculatedAmount);
    }

    get selectionCountLabel() {
        const count = this.eoiSelections.length;
        return count === 1 ? '1 Item' : `${count} Items`;
    }

    get isEoiNextDisabled() {
        return this.isLoading
            || !this.opportunityId
            || !this.selectedProjectId
            || !this.selectedPaymentMethod
            || this.eoiSelections.some((selection) => (selection.showPhase && !selection.phaseId)
                || (selection.showUnitType && !selection.unitType)
                || (selection.showBedrooms && !selection.bedrooms)
                || (selection.showTypology && !selection.unitTypology)
                || !selection.eoiRangeId)
            || this.hasQuotaCountError
            || this.isProjectClosed;
    }

    get isAddEoiDisabled() {
        return this.isLoading
            || this.isProjectClosed
            || this.hasQuotaCountError
            || (this.showQuota && this.quotaLimit > 0 && this.eoiSelections.length >= this.quotaRemaining);
    }

    get hasQuotaCountError() {
        return this.showQuota
            && this.quotaLimit > 0
            && this.eoiSelections.length > this.quotaRemaining;
    }

    get whatsappVerificationClass() {
        return this.verificationMethod === 'whatsapp'
            ? 'verification-option selected'
            : 'verification-option';
    }

    get emailVerificationClass() {
        return this.verificationMethod === 'email'
            ? 'verification-option selected'
            : 'verification-option';
    }

    get smsVerificationClass() {
        return this.verificationMethod === 'sms'
            ? 'verification-option selected'
            : 'verification-option';
    }

    get paymentTypeLabel() {
        return this.selectedPaymentMethod || '';
    }

    handlePaymentMethod(event) {
        this.selectedPaymentMethod = event.detail?.value || event.target?.value || event.currentTarget?.dataset?.method;
    }

    get showVerificationCode() {
        return Boolean(this.verificationMethod);
    }

    get isWhatsappVerificationSelected() {
        return this.verificationMethod === 'whatsapp';
    }

    get isWhatsappDisabled() {
        return true;
    }

    get isEmailVerificationSelected() {
        return this.verificationMethod === 'email';
    }

    get isSmsVerificationSelected() {
        return this.verificationMethod === 'sms';
    }

    get showEmailVerificationLoader() {
        return this.isSendingVerification && this.verificationMethod === 'email';
    }

    get showSmsVerificationLoader() {
        return this.isSendingVerification && this.verificationMethod === 'sms';
    }

    get verificationMethodLabel() {
        if (this.verificationMethod === 'email') return 'Email Verification';
        if (this.verificationMethod === 'sms') return 'SMS Verification';
        return 'WhatsApp Verification';
    }

    get verificationDestinationName() {
        if (this.verificationMethod === 'sms') return 'mobile number';
        if (this.verificationMethod === 'whatsapp') return 'WhatsApp number';
        return 'email';
    }

    get verificationDestinationText() {
        if (this.verificationMethod === 'email') {
            return `A 6-digit code has been sent to your email ${this.maskEmail(this.verificationEmailTarget)}.`;
        }
        if (this.verificationMethod === 'sms') {
            return `A 6-digit code has been sent to your mobile number ending in ${this.maskPhone(this.verificationPhoneTarget)}.`;
        }
        return `A 6-digit code has been sent to your WhatsApp number ending in ${this.maskPhone(this.verificationPhoneTarget)}.`;
    }

    get isVerificationNextDisabled() {
        return this.isLoading
            || this.isSendingVerification
            || !this.verificationRequestId
            || !this.verificationMethod
            || this.verificationDigits.some((digit) => !digit.value);
    }

    get isResendDisabled() {
        return this.isSendingVerification || this.resendCooldownSeconds > 0;
    }

    get showResendAction() {
        return !this.maxResendReached;
    }

    get resendButtonLabel() {
        return this.resendCooldownSeconds > 0
            ? `Resend available in ${this.resendCooldownSeconds}s`
            : 'Resend Code';
    }

    get isBackDisabled() {
        return this.isLoading || (this.verificationCompleted && this.step === 3);
    }

    maskPhone(value) {
        const digits = (value || '').replace(/\D/g, '');
        return digits ? `****${digits.slice(-4)}` : '****';
    }

    maskEmail(value) {
        const email = value || '';
        const [name, domain] = email.split('@');
        if (!name || !domain) return 'your registered email';
        return `${name.substring(0, 2)}***@${domain}`;
    }

    formatCurrency(value) {
        const amount = Number(value);
        if (!Number.isFinite(amount) || amount === 0) return 'AED 0';
        return 'AED ' + amount.toLocaleString('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        });
    }

    get quotaStyle() {
        const percent = this.quotaLimit > 0 ? Math.min((this.quotaUsed / this.quotaLimit) * 100, 100) : 0;
        return `width: ${percent}%;`;
    }

    reduceError(error) {
        const messages = [];
        const addMessage = (value) => {
            if (!value) return;
            if (Array.isArray(value)) {
                value.forEach((item) => addMessage(item));
                return;
            }
            if (typeof value === 'string') {
                if (value.trim()) messages.push(value.trim());
                return;
            }
            if (value.message) addMessage(value.message);
            if (value.pageErrors) addMessage(value.pageErrors);
            if (value.errors) addMessage(value.errors);
            if (value.fieldErrors) {
                Object.values(value.fieldErrors).forEach((fieldMessages) => addMessage(fieldMessages));
            }
            if (value.output) addMessage(value.output);
        };

        addMessage(error?.body);
        addMessage(error);

        const uniqueMessages = [...new Set(messages)];
        if (uniqueMessages.length) return uniqueMessages.join('; ');

        try {
            return JSON.stringify(error);
        } catch (jsonError) {
            return 'Unable to read error details.';
        }
    }

    getInputValue(event) {
        return event?.detail?.value ?? event?.target?.value ?? '';
    }

    isDateField(field) {
        return field === 'tradeLicenseExpiryDate'
            || field === 'emiratesIdExpiryDate'
            || field === 'passportExpiryDate';
    }

    normalizeDateValue(value) {
        if (!value) return null;
        const normalized = String(value).trim();
        return /^\d{4}-\d{2}-\d{2}$/.test(normalized) ? normalized : null;
    }

    clearInputValidation(key) {
        if (!key) return;
        this.contactValidation = { ...this.contactValidation, [key]: false };
        this.contactValidationValues = { ...this.contactValidationValues, [key]: '' };
        if (this.validatingContactKey === key) this.validatingContactKey = '';
        const input = this.template.querySelector(`[data-validation-key="${key}"]`);
        if (input) {
            input.setCustomValidity('');
            input.reportValidity();
        }
    }

    async validateContactInputs(keys, allowBlank) {
        let isValid = true;
        for (const key of keys) {
            const input = this.template.querySelector(`[data-validation-key="${key}"]`);
            if (!input) continue;
            const fieldValid = key.toLowerCase().includes('email')
                ? await this.validateEmailElement(input, key, allowBlank)
                : await this.validatePhoneElement(input, key, allowBlank);
            isValid = fieldValid && isValid;
        }
        return isValid;
    }

    areContactInputsAlreadyValid(keys, allowBlank) {
        let isValid = true;
        for (const key of keys) {
            const input = this.template.querySelector(`[data-validation-key="${key}"]`);
            if (!input) continue;
            const value = input.value || '';
            if (!value.trim()) {
                if (!allowBlank) {
                    input.setCustomValidity(key.toLowerCase().includes('email')
                        ? 'Please enter an email address.'
                        : 'Please enter a phone number.');
                    input.reportValidity();
                    isValid = false;
                }
                continue;
            }
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
                continue;
            }
            if (!this.contactValidation[key]) {
                input.setCustomValidity(key.toLowerCase().includes('email')
                    ? 'Please validate email before continuing.'
                    : 'Please validate phone number before continuing.');
                input.reportValidity();
                isValid = false;
            }
        }
        return isValid;
    }

    async validateEmailElement(input, key, allowBlank) {
        const email = input?.value || '';
        if (!input) return true;
        if (!email.trim()) {
            input.setCustomValidity(allowBlank ? '' : 'Please enter an email address.');
            input.reportValidity();
            this.contactValidation = { ...this.contactValidation, [key]: false };
            return allowBlank;
        }
        if (!input.checkValidity()) {
            input.reportValidity();
            this.contactValidation = { ...this.contactValidation, [key]: false };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: email };
            return false;
        }
        if (this.contactValidationValues[key] === email) {
            input.reportValidity();
            return this.contactValidation[key];
        }
        if (this.isValidatingEmail) return false;
        this.isValidatingEmail = true;
        this.validatingContactKey = key;
        try {
            await validateCompanyEmail({ email });
            input.setCustomValidity('');
            this.contactValidation = { ...this.contactValidation, [key]: true };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: email };
            return true;
        } catch (error) {
            input.setCustomValidity('Please enter a valid email address.');
            this.contactValidation = { ...this.contactValidation, [key]: false };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: email };
            return false;
        } finally {
            input.reportValidity();
            this.isValidatingEmail = false;
            if (this.validatingContactKey === key) this.validatingContactKey = '';
        }
    }

    async validatePhoneElement(input, key, allowBlank) {
        const phone = input?.value || '';
        if (!input) return true;
        if (!phone.trim()) {
            input.setCustomValidity(allowBlank ? '' : 'Please enter a phone number.');
            input.reportValidity();
            this.contactValidation = { ...this.contactValidation, [key]: false };
            return allowBlank;
        }
        const phoneRegex = /^\+[0-9]{6,15}$/;
        if (!phoneRegex.test(phone)) {
            input.setCustomValidity('Phone number must start with + and contain digits only (e.g. +971501234567)');
            input.reportValidity();
            this.contactValidation = { ...this.contactValidation, [key]: false };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: phone };
            return false;
        }
        if (this.contactValidationValues[key] === phone) {
            input.reportValidity();
            return this.contactValidation[key];
        }
        if (this.isValidatingPhone) return false;
        this.isValidatingPhone = true;
        this.validatingContactKey = key;
        try {
            const isValid = await validatePhone({ phone });
            input.setCustomValidity(isValid ? '' : 'Please enter a valid mobile number');
            this.contactValidation = { ...this.contactValidation, [key]: isValid };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: phone };
            return isValid;
        } catch (error) {
            input.setCustomValidity('Unable to validate phone number');
            this.contactValidation = { ...this.contactValidation, [key]: false };
            this.contactValidationValues = { ...this.contactValidationValues, [key]: phone };
            return false;
        } finally {
            input.reportValidity();
            this.isValidatingPhone = false;
            if (this.validatingContactKey === key) this.validatingContactKey = '';
        }
    }

    get showLookupEmailLoader() {
        return this.validatingContactKey === 'lookupEmail';
    }

    get showLookupPhoneLoader() {
        return this.validatingContactKey === 'lookupPhone';
    }

    get showCustomerEmailLoader() {
        return this.validatingContactKey === 'customerEmail';
    }

    get showCustomerPhoneLoader() {
        return this.validatingContactKey === 'customerPhone';
    }


    normalizeResidentStatus(value) {
        const normalized = (value || '').trim().toLowerCase().replace(/[\s_]+/g, '-');
        if (normalized === 'non-resident' || normalized === 'nonresident') {
            return 'Non-Resident';
        }
        if (normalized === 'resident') {
            return 'Resident';
        }
        return value || 'Resident';
    }

    formatEmiratesId(value) {
        const digits = (value || '').replace(/\D/g, '').substring(0, 15);
        const parts = [];
        if (digits.length > 0) parts.push(digits.substring(0, 3));
        if (digits.length > 3) parts.push(digits.substring(3, 7));
        if (digits.length > 7) parts.push(digits.substring(7, 14));
        if (digits.length > 14) parts.push(digits.substring(14, 15));
        return parts.join('-');
    }

    sanitizePassportNumber(value) {
        return (value || '').replace(/[^a-zA-Z0-9]/g, '');
    }

    isValidEmiratesId(value) {
        return /^[0-9]{3}-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(value || '');
    }
}