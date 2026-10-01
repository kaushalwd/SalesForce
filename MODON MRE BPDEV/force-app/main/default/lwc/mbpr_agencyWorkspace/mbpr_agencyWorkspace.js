import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import VAT_UNDERTAKING_TEMPLATE from '@salesforce/resourceUrl/MBP_VatUndertakingCertificate';

import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';
import getSectionDocs from '@salesforce/apex/MBP_BrokerAgencyInformationController.getSectionDocs';
import getRejectionComments from '@salesforce/apex/MBP_BrokerAgencyInformationController.getRejectionComments';
import submitSectionWithDocs from '@salesforce/apex/MBP_BrokerAgencyInformationController.submitSectionWithDocs';
import sendOtpToAgencyAdmin from '@salesforce/apex/MBP_BrokerAgencyInformationController.sendOtpToAgencyAdmin';
import verifyAgencyBankOtp from '@salesforce/apex/MBP_BrokerAgencyInformationController.verifyAgencyBankOtp';
import shouldShowBrokerContent from '@salesforce/apex/MBP_BrokerAgencyInformationController.shouldShowBrokerContent';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';
import getPicklist from '@salesforce/apex/MBP_BrokerLeadcontroller.getPicklist';

const VAT_TYPE_OPTIONS = [
    { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
    { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
];

const BANK_BRANCH_TYPE_OPTIONS = [
    { label: 'SWIFT', value: 'SWIFT' },
    { label: 'CHIPS', value: 'CHIPS' },
    { label: 'ABA', value: 'ABA' },
    { label: 'Other', value: 'Other' }
];

const APPROVAL_IN_PROGRESS_MESSAGE =
    'Another approval (VAT, Trade License or Bank) is already in process. Please wait until it completes.';

export default class MbprAgencyWorkspace extends LightningElement {
    @api brokerType = '';

    isInitializing = true;
    isActionPending = false;
    accessError = '';

    // Wrapper gate results
    isLimitedOnly = false;
    isBrokerAgencyBlocked = false;
    isEidExpiredForContact = false;
    isAwaitingTradeLicence = false;

    // Account context
    account = null;
    effectiveBrokerType = '';
    primaryOwnerContact = null;
    brokerContentAllowed = true;

    showVatSection = false;
    showTradeSection = false;
    showBankSection = false;

    /* Trade License, Bank and (BP-037) VAT start collapsed at every size. */
    tradeSectionExpanded = false;
    bankSectionExpanded = false;
    vatSectionExpanded = false;

    get vatAriaExpanded() {
        return this.vatSectionExpanded ? 'true' : 'false';
    }

    toggleVatSection() {
        this.vatSectionExpanded = !this.vatSectionExpanded;
    }

    get tradeAriaExpanded() {
        return this.tradeSectionExpanded ? 'true' : 'false';
    }

    get bankAriaExpanded() {
        return this.bankSectionExpanded ? 'true' : 'false';
    }

    toggleTradeSection() {
        this.tradeSectionExpanded = !this.tradeSectionExpanded;
    }

    toggleBankSection() {
        this.bankSectionExpanded = !this.bankSectionExpanded;
    }

    vatSubmitted = false;
    tradeSubmitted = false;
    bankSubmitted = false;

    vatDownloadUrl = null;
    tradeDownloadUrl = null;
    bankDownloadUrl = null;

    vatRejectionComment = '';
    tradeRejectionComment = '';
    bankRejectionComment = '';

    bankCountryOptions = [];

    activeSubview = 'info';

    // ---- Section modal state ----
    isModalOpen = false;
    isVatModal = false;
    isTradeModal = false;
    isBankModal = false;
    modalTitle = '';

    vatTypeSelection = '';
    vatNumberTemp = '';
    vatStartDateTemp = '';
    vatExpiryDateTemp = '';

    tradeNumberTemp = '';
    tradeExpiryDateTemp = '';
    tradeIssuanceDateTemp = '';
    licensingAuthorityTemp = '';
    companyNameTradeLicenseTemp = '';

    bankNameTemp = '';
    accountNumberTemp = '';
    bankCountryTemp = '';
    beneficiaryNameTemp = '';
    bankBranchNameTemp = '';
    bankBranchTypeTemp = '';
    ibanNumberTemp = '';
    swiftCodeTemp = '';

    stagedFileName = null;
    stagedFileBase64 = null;
    stagedFilePreviewUrl = null;
    stagedFileSection = null;

    // ---- OTP + consent state (Bank only) ----
    showOtpModal = false;
    enteredOtp = '';
    showConsentModal = false;
    bankConsentGiven = false;

    _loadSequence = 0;
    _modalOpener = null;

    connectedCallback() {
        this.initializeWorkspace();
    }

    async initializeWorkspace() {
        this.isInitializing = true;
        this.accessError = '';
        try {
            const [wrapper, editable, brokerContentAllowed] = await Promise.all([
                findRegistrationWithReviewComment(),
                getEditableAccount(),
                shouldShowBrokerContent()
            ]);

            this.isLimitedOnly = Boolean(wrapper && wrapper.isLimitedOnly);
            this.isBrokerAgencyBlocked = Boolean(wrapper && wrapper.isBrokerAgencyBlocked);
            this.isEidExpiredForContact = Boolean(wrapper && wrapper.isEidExpiredForContact);
            this.isAwaitingTradeLicence = Boolean(wrapper && wrapper.isAwaitingTradeLicence);
            this.brokerContentAllowed = brokerContentAllowed === true;

            if (this.showOnboardingContinuation) {
                // Limited login without a blocked agency: the whole surface is the
                // onboarding continuation; no agency data is loaded (legacy rule).
                return;
            }

            if (editable && editable.account) {
                this.account = editable.account;
                this.effectiveBrokerType = editable.brokerType || '';
                this.primaryOwnerContact = editable.contact || null;

                const brokerType = this.effectiveBrokerType;
                if (brokerType === 'Owner' || brokerType === 'Agency Admin') {
                    this.showTradeSection = true;
                    this.showBankSection = true;
                    this.showVatSection = this.account.Type_of_Registration__c === 'UAE Broker';
                } else {
                    this.showVatSection = false;
                    this.showTradeSection = false;
                    this.showBankSection = false;
                }

                this.vatSubmitted = this.account.VAT_Status__c === 'Submitted';
                this.tradeSubmitted = this.account.Trade_License_Status__c === 'Submitted';
                this.bankSubmitted = this.account.Bank_Status__c === 'Submitted';

                await Promise.all([this.loadDocumentLinks(), this.loadRejectionComments()]);
                this.loadBankCountryOptions();
            } else {
                this.account = null;
            }
        } catch (error) {
            this.accessError =
                this.reduceError(error) || 'Unable to load your agency information right now. Please try again.';
        } finally {
            this.isInitializing = false;
        }
    }

    async refreshAgencyData() {
        const sequence = ++this._loadSequence;
        try {
            const editable = await getEditableAccount();
            if (sequence !== this._loadSequence) return;
            if (editable && editable.account) {
                this.account = editable.account;
                this.vatSubmitted = this.account.VAT_Status__c === 'Submitted';
                this.tradeSubmitted = this.account.Trade_License_Status__c === 'Submitted';
                this.bankSubmitted = this.account.Bank_Status__c === 'Submitted';
                await Promise.all([this.loadDocumentLinks(), this.loadRejectionComments()]);
            }
        } catch (error) {
            // Keep the current view; the submit toast already reported the outcome.
        }
    }

    loadBankCountryOptions() {
        getPicklist({ objectName: 'Account', fieldName: 'Bank_Country__c' })
            .then((result) => {
                const values = (result && result.values) || [];
                this.bankCountryOptions = values.map((value) => ({ label: value, value }));
            })
            .catch(() => {
                this.bankCountryOptions = [];
            });
    }

    async loadDocumentLinks() {
        if (!this.account) return;
        const accountId = this.account.Id;
        // One call per visible section per refresh: every call creates a public
        // link server-side, so the URLs are cached in state and never re-fetched
        // on tab switches.
        const tasks = [];
        if (this.showVatSection) {
            tasks.push(
                getSectionDocs({ accountId, section: 'VAT' })
                    .then((url) => {
                        this.vatDownloadUrl = url;
                    })
                    .catch(() => {
                        this.vatDownloadUrl = null;
                    })
            );
        }
        if (this.showTradeSection) {
            tasks.push(
                getSectionDocs({ accountId, section: 'TRADE' })
                    .then((url) => {
                        this.tradeDownloadUrl = url;
                    })
                    .catch(() => {
                        this.tradeDownloadUrl = null;
                    })
            );
        }
        if (this.showBankSection) {
            tasks.push(
                getSectionDocs({ accountId, section: 'BANK' })
                    .then((url) => {
                        this.bankDownloadUrl = url;
                    })
                    .catch(() => {
                        this.bankDownloadUrl = null;
                    })
            );
        }
        await Promise.all(tasks);
    }

    async loadRejectionComments() {
        if (!this.account) return;
        const accountId = this.account.Id;
        const tasks = [];
        if (this.account.VAT_Status__c === 'Rejected') {
            tasks.push(
                getRejectionComments({ accountId, section: 'VAT' })
                    .then((comment) => {
                        this.vatRejectionComment = comment || '';
                    })
                    .catch(() => {
                        this.vatRejectionComment = '';
                    })
            );
        } else {
            this.vatRejectionComment = '';
        }
        if (this.account.Trade_License_Status__c === 'Rejected') {
            tasks.push(
                getRejectionComments({ accountId, section: 'TRADE' })
                    .then((comment) => {
                        this.tradeRejectionComment = comment || '';
                    })
                    .catch(() => {
                        this.tradeRejectionComment = '';
                    })
            );
        } else {
            this.tradeRejectionComment = '';
        }
        if (this.account.Bank_Status__c === 'Rejected') {
            tasks.push(
                getRejectionComments({ accountId, section: 'BANK' })
                    .then((comment) => {
                        this.bankRejectionComment = comment || '';
                    })
                    .catch(() => {
                        this.bankRejectionComment = '';
                    })
            );
        } else {
            this.bankRejectionComment = '';
        }
        await Promise.all(tasks);
    }

    handleRetryLoad() {
        this.initializeWorkspace();
    }

    // ------------------------------------------------------------------
    // Gates
    // ------------------------------------------------------------------

    get showOnboardingContinuation() {
        // An owner waiting for the agency's trade licence (Pending Trade License) has no registration to
        // continue: they upload the trade licence and bank details in Agency Info.
        return this.isLimitedOnly && !this.isBrokerAgencyBlocked && !this.isAwaitingTradeLicence;
    }

    get showAgentsTab() {
        const brokerType = this.effectiveBrokerType || this.brokerType;
        return (!this.isLimitedOnly || this.isEidExpiredForContact) && brokerType !== 'Agent';
    }

    get hasAccount() {
        return Boolean(this.account);
    }

    get isInfoSubview() {
        return this.activeSubview === 'info';
    }

    get isAgentsSubview() {
        return this.activeSubview === 'agents';
    }

    get infoTabClass() {
        return this.isInfoSubview ? 'subview-tab subview-tab--active' : 'subview-tab';
    }

    get agentsTabClass() {
        return this.isAgentsSubview ? 'subview-tab subview-tab--active' : 'subview-tab';
    }

    handleShowInfoTab() {
        this.activeSubview = 'info';
    }

    handleShowAgentsTab() {
        this.activeSubview = 'agents';
    }

    // ------------------------------------------------------------------
    // Display getters (legacy field bindings)
    // ------------------------------------------------------------------

    get accountName() {
        return this.account ? this.account.Name : '';
    }
    get accountPhone() {
        return this.account ? this.account.Phone : '';
    }
    get accountEmail() {
        return this.account ? this.account.Company_Email_Address__c : '';
    }
    get accountCity() {
        return this.account ? this.account.BillingCity : '';
    }
    get accountCountry() {
        return this.account ? this.account.BillingCountry : '';
    }
    get accountPoBox() {
        return this.account ? this.account.BillingPostalCode : '';
    }
    get accountRegion() {
        return this.account ? this.account.Agency_Region__c : '';
    }

    get vatCertificateType() {
        return this.account ? this.account.VAT_Certificate_Type__c : '';
    }
    get vatRegistrationNumber() {
        return this.account ? this.account.UAEVATRegisterNumber__c : '';
    }
    /* Portal date format is DD MMM YYYY. UTC is pinned so a date-only value
       never shifts a day by timezone. */
    formatPortalDate(value) {
        if (!value) return '';
        const parsed = new Date(`${value}T00:00:00.000Z`);
        if (Number.isNaN(parsed.getTime())) return value;
        return new Intl.DateTimeFormat('en-AE', {
            day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC'
        }).format(parsed);
    }

    get vatStartDate() {
        return this.account ? this.formatPortalDate(this.account.UAE_VAT_Start_Date__c) : '';
    }
    get vatExpiryDate() {
        return this.account ? this.formatPortalDate(this.account.UAE_VAT_Expiry_Date__c) : '';
    }
    get vatDocumentLabel() {
        return this.vatCertificateType === 'VAT Undertaking Certificate'
            ? 'View VAT Undertaking Certificate'
            : 'View VAT Registration Certificate';
    }

    get tradeCompanyName() {
        return this.account ? this.account.Company_Name_as_per_Trade_License__c : '';
    }
    get tradeLicenseNumber() {
        return this.account ? this.account.Trade_License_Number__c : '';
    }
    get licensingAuthority() {
        return this.account ? this.account.Licensing_Authority__c : '';
    }
    get issuanceDate() {
        return this.account ? this.formatPortalDate(this.account.Issuance_Date__c) : '';
    }
    get tradeExpiryDate() {
        return this.account ? this.formatPortalDate(this.account.TradeLicenseExpiryDate__c) : '';
    }

    get bankName() {
        return this.account ? this.account.Bank_Name__c : '';
    }
    get beneficiaryName() {
        return this.account ? this.account.Beneficiary_Name__c : '';
    }
    get bankAccountNumber() {
        return this.account ? this.account.Bank_Account_Number__c : '';
    }
    get bankCountry() {
        return this.account ? this.account.Bank_Country__c : '';
    }
    get ibanNumber() {
        return this.account ? this.account.IBAN_Number__c : '';
    }
    get swiftCode() {
        return this.account ? this.account.Swift_Code__c : '';
    }

    get primaryOwnerEmail() {
        return this.primaryOwnerContact ? this.primaryOwnerContact.Email : '';
    }

    get vatTypeOptions() {
        return VAT_TYPE_OPTIONS;
    }

    get bankBranchTypeOptions() {
        return BANK_BRANCH_TYPE_OPTIONS;
    }

    get isVatUndertakingSelected() {
        return this.vatTypeSelection === 'VAT Undertaking Certificate';
    }

    // One-approval-at-a-time (legacy rule, now explained instead of silent)
    get anySectionSubmitted() {
        return this.vatSubmitted || this.tradeSubmitted || this.bankSubmitted;
    }

    get canShowVatButton() {
        return !this.vatSubmitted && !this.anySectionSubmitted;
    }

    get canShowTradeButton() {
        return !this.tradeSubmitted && !this.anySectionSubmitted;
    }

    get canShowBankButton() {
        return !this.bankSubmitted && !this.anySectionSubmitted;
    }

    get approvalLockMessage() {
        return APPROVAL_IN_PROGRESS_MESSAGE;
    }

    get showVatLockNote() {
        return !this.vatSubmitted && this.anySectionSubmitted;
    }

    get showTradeLockNote() {
        return !this.tradeSubmitted && this.anySectionSubmitted;
    }

    get showBankLockNote() {
        return !this.bankSubmitted && this.anySectionSubmitted;
    }

    get hasStagedFile() {
        return Boolean(this.stagedFileName);
    }

    // ------------------------------------------------------------------
    // Section modals
    // ------------------------------------------------------------------

    openVatModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.modalTitle = 'Update VAT Info';
        this.isVatModal = true;
        this.isTradeModal = false;
        this.isBankModal = false;
        this.vatTypeSelection = this.vatCertificateType || '';
        this.vatNumberTemp = this.vatRegistrationNumber || '';
        this.vatStartDateTemp = this.vatStartDate || '';
        /* VAT Expiry Date is hidden from the portal (business request,
           2026-09-04) but still submitted unchanged: the VAT approval process
           copies Proposed_VAT_Expiry_Date__c into UAE_VAT_Expiry_Date__c on
           final approval, so dropping it would blank the stored date. Seeded
           from the raw account value - vatExpiryDate is display-formatted. */
        this.vatExpiryDateTemp = (this.account && this.account.UAE_VAT_Expiry_Date__c) || '';
        this.clearStagedFile();
        this.isModalOpen = true;
    }

    openTradeModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.modalTitle = 'Update Trade License';
        this.isTradeModal = true;
        this.isVatModal = false;
        this.isBankModal = false;
        this.tradeNumberTemp = this.tradeLicenseNumber || '';
        this.tradeExpiryDateTemp = this.tradeExpiryDate || '';
        this.tradeIssuanceDateTemp = this.issuanceDate || '';
        this.licensingAuthorityTemp = this.licensingAuthority || '';
        this.companyNameTradeLicenseTemp = this.tradeCompanyName || '';
        this.clearStagedFile();
        this.isModalOpen = true;
    }

    async openBankModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.isActionPending = true;
        try {
            const result = await sendOtpToAgencyAdmin({ accountId: this.account.Id });
            if (typeof result === 'string' && result.startsWith('ERROR_')) {
                // Legacy resolved these sentinels straight into the success path
                // and opened an unpassable OTP modal.
                this.showToast('Failed to send OTP to Primary Owner.', 'error');
                return;
            }
            this.enteredOtp = '';
            this.showOtpModal = true;
            this.showToast(
                'OTP has been sent to the Primary Owner. Please verify the OTP to proceed with updating bank details.',
                'success'
            );
        } catch (error) {
            this.showToast('Failed to send OTP to Primary Owner.', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    handleOtpChange(event) {
        this.enteredOtp = event.target.value;
    }

    async validateOtpAndOpenBankForm() {
        const code = (this.enteredOtp || '').trim();
        let verified = false;
        this.isActionPending = true;
        try {
            verified = (await verifyAgencyBankOtp({ accountId: this.account.Id, code })) === true;
        } catch (error) {
            verified = false;
        } finally {
            this.isActionPending = false;
        }

        if (verified) {
            this.showOtpModal = false;
            this.showToast('OTP has been verified successfully. You may now update bank details.', 'success');
            this.modalTitle = 'Update Bank Info';
            this.isBankModal = true;
            this.isVatModal = false;
            this.isTradeModal = false;
            this.bankNameTemp = this.bankName || '';
            this.accountNumberTemp = this.bankAccountNumber || '';
            this.bankCountryTemp = this.bankCountry || '';
            this.beneficiaryNameTemp = this.beneficiaryName || '';
            this.bankBranchNameTemp = (this.account && this.account.Bank_Branch_Name__c) || '';
            this.bankBranchTypeTemp = (this.account && this.account.Bank_Branch_Type__c) || '';
            this.ibanNumberTemp = this.ibanNumber || '';
            this.swiftCodeTemp = this.swiftCode || '';
            this.bankConsentGiven = false;
            this.clearStagedFile();
            this.isModalOpen = true;
        } else {
            this.showToast('The OTP entered is incorrect. Please try again.', 'error');
        }
    }

    closeOtpModal() {
        this.showOtpModal = false;
        this.enteredOtp = '';
        this.restoreFocus(this._modalOpener);
    }

    handleOtpKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeOtpModal();
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.isVatModal = false;
        this.isTradeModal = false;
        this.isBankModal = false;
        this.bankConsentGiven = false;
        this.clearStagedFile();
        this.restoreFocus(this._modalOpener);
        this._modalOpener = null;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeModal();
        }
    }

    // ---- Modal field handlers ----

    handleVatTypeSelection(event) {
        this.vatTypeSelection = event.detail.value;
    }

    handleVatFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (field === 'vatNumberTemp') {
            this.vatNumberTemp = value;
        } else if (field === 'vatStartDateTemp') {
            this.vatStartDateTemp = value;
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (value && new Date(value) > today) {
                event.target.setCustomValidity('VAT Start Date cannot be in the future.');
            } else {
                event.target.setCustomValidity('');
            }
            event.target.reportValidity();
        }
    }

    handleTradeFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (field === 'tradeIssuanceDateTemp') {
            this.tradeIssuanceDateTemp = value;
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (value && new Date(value) > today) {
                event.target.setCustomValidity('Issuance Date cannot be in the future.');
            } else {
                event.target.setCustomValidity('');
            }
            event.target.reportValidity();
        } else if (field === 'tradeExpiryDateTemp') {
            this.tradeExpiryDateTemp = value;
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (value && new Date(value) <= today) {
                event.target.setCustomValidity('Trade Expiry Date must be a future date.');
            } else {
                event.target.setCustomValidity('');
            }
            event.target.reportValidity();
        }
    }

    handleBankFieldChange(event) {
        const field = event.target.dataset.field;
        let value = event.detail ? event.detail.value : event.target.value;
        switch (field) {
            case 'bankNameTemp':
                this.bankNameTemp = value;
                break;
            case 'accountNumberTemp':
                this.accountNumberTemp = value;
                break;
            case 'bankCountryTemp':
                this.bankCountryTemp = value;
                break;
            case 'beneficiaryNameTemp':
                this.beneficiaryNameTemp = (value || '').replace(/[^a-zA-Z0-9\s\-\.\,\&\(\)]/g, '');
                break;
            case 'bankBranchNameTemp':
                this.bankBranchNameTemp = value;
                break;
            case 'bankBranchTypeTemp':
                this.bankBranchTypeTemp = value;
                break;
            case 'ibanNumberTemp':
                this.ibanNumberTemp = value;
                break;
            case 'swiftCodeTemp':
                this.swiftCodeTemp = value;
                break;
            default:
                break;
        }
    }

    downloadVAT() {
        const link = document.createElement('a');
        link.href = VAT_UNDERTAKING_TEMPLATE;
        link.download = 'VAT_Undertaking_Certificate.docx';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    // ---- Staged file handling ----

    handleFileChange(event) {
        const section = event.target.dataset.section;
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        const extension = file.name.split('.').pop();
        let renamed;
        if (section === 'VAT') {
            renamed = `VAT_Registration_Certificate.${extension}`;
        } else if (section === 'TRADE') {
            renamed = `TradeLicense.${extension}`;
        } else {
            renamed = `IBAN.${extension}`;
        }
        const reader = new FileReader();
        reader.onload = () => {
            this.stagedFileBase64 = reader.result.split(',')[1];
            this.stagedFileName = renamed;
            this.stagedFileSection = section;
            const blob = new Blob([file], { type: file.type });
            this.stagedFilePreviewUrl = URL.createObjectURL(blob);
        };
        reader.readAsDataURL(file);
        event.target.value = null;
    }

    handleDeleteStagedFile() {
        this.clearStagedFile();
    }

    clearStagedFile() {
        if (this.stagedFilePreviewUrl) {
            URL.revokeObjectURL(this.stagedFilePreviewUrl);
        }
        this.stagedFileName = null;
        this.stagedFileBase64 = null;
        this.stagedFilePreviewUrl = null;
        this.stagedFileSection = null;
    }

    // ------------------------------------------------------------------
    // Validation (reads component state so consent re-entry stays honest)
    // ------------------------------------------------------------------

    setFieldValidity(fieldName, message) {
        const target = this.template.querySelector(`[data-field="${fieldName}"]`);
        if (target) {
            target.setCustomValidity(message);
            target.reportValidity();
        }
    }

    validateVatForm() {
        let valid = true;
        if (!this.vatTypeSelection) {
            valid = false;
            this.setFieldValidity('vatTypeSelection', 'Select VAT Certificate Type is required.');
        } else {
            this.setFieldValidity('vatTypeSelection', '');
        }

        if (!this.isVatUndertakingSelected) {
            if (!this.vatNumberTemp) {
                valid = false;
                this.setFieldValidity('vatNumberTemp', 'VAT Registration Number is required.');
            } else {
                this.setFieldValidity('vatNumberTemp', '');
            }
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (!this.vatStartDateTemp) {
                valid = false;
                this.setFieldValidity('vatStartDateTemp', 'VAT Start Date is required.');
            } else if (new Date(this.vatStartDateTemp) > today) {
                valid = false;
                this.setFieldValidity('vatStartDateTemp', 'VAT Start Date cannot be in the future.');
            } else {
                this.setFieldValidity('vatStartDateTemp', '');
            }
        }

        if (!this.stagedFileBase64) {
            valid = false;
            this.showToast('Please delete the existing VAT file and upload a new, updated copy.', 'error');
        }
        return valid;
    }

    validateTradeForm() {
        let valid = true;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (!this.tradeIssuanceDateTemp) {
            valid = false;
            this.setFieldValidity('tradeIssuanceDateTemp', 'Issuance Date is required.');
        } else if (new Date(this.tradeIssuanceDateTemp) > today) {
            valid = false;
            this.setFieldValidity('tradeIssuanceDateTemp', 'Issuance Date cannot be in the future.');
        } else {
            this.setFieldValidity('tradeIssuanceDateTemp', '');
        }
        if (!this.tradeExpiryDateTemp) {
            valid = false;
            this.setFieldValidity('tradeExpiryDateTemp', 'Trade Expiry Date is required.');
        } else if (new Date(this.tradeExpiryDateTemp) <= today) {
            valid = false;
            this.setFieldValidity('tradeExpiryDateTemp', 'Trade Expiry Date must be a future date.');
        } else {
            this.setFieldValidity('tradeExpiryDateTemp', '');
        }
        if (!this.stagedFileBase64) {
            valid = false;
            this.showToast('Please delete the existing trade license file and upload a new, updated copy.', 'error');
        }
        return valid;
    }

    validateBankForm() {
        let valid = true;
        const requiredFields = [
            ['bankNameTemp', 'Bank Name'],
            ['accountNumberTemp', 'Account Number'],
            ['bankCountryTemp', 'Bank Country'],
            ['beneficiaryNameTemp', 'Beneficiary Name'],
            ['bankBranchNameTemp', 'Bank Branch Name'],
            ['bankBranchTypeTemp', 'Bank Branch Type'],
            ['ibanNumberTemp', 'IBAN Number'],
            ['swiftCodeTemp', 'SWIFT Code']
        ];
        for (const [fieldName, label] of requiredFields) {
            if (!this[fieldName]) {
                valid = false;
                this.setFieldValidity(fieldName, `${label} is required.`);
            } else {
                this.setFieldValidity(fieldName, '');
            }
        }

        const iban = (this.ibanNumberTemp || '').replace(/\s+/g, '');
        if (this.ibanNumberTemp && !/^AE\d{21}$/i.test(this.ibanNumberTemp.trim())) {
            valid = false;
            this.setFieldValidity('ibanNumberTemp', "Invalid IBAN format. It must start with 'AE' followed by 21 digits.");
        }
        if (this.accountNumberTemp && !/^\d+$/.test(this.accountNumberTemp)) {
            valid = false;
            this.setFieldValidity('accountNumberTemp', 'Account Number must contain only digits.');
        }
        if (this.swiftCodeTemp && !/^[A-Za-z0-9]{8}([A-Za-z0-9]{3})?$/.test(this.swiftCodeTemp)) {
            valid = false;
            this.setFieldValidity('swiftCodeTemp', 'SWIFT Code must be 8 or 11 characters (letters/digits).');
        }

        const accountNumber = (this.accountNumberTemp || '').trim();
        if (iban && accountNumber) {
            const ibanTail = iban.slice(-13);
            if (ibanTail !== accountNumber) {
                const accountSub = accountNumber.slice(-5);
                if (!iban.includes(accountSub)) {
                    valid = false;
                    this.setFieldValidity(
                        'accountNumberTemp',
                        'Account Number must exactly match at least 5 consecutive digits within the IBAN.'
                    );
                }
            }
        }

        if (!this.stagedFileBase64) {
            valid = false;
            this.showToast('Please delete the existing bank copy and re-upload the updated bank document.', 'error');
        }
        return valid;
    }

    // ------------------------------------------------------------------
    // Consent (Bank only)
    // ------------------------------------------------------------------

    closeConsentModal() {
        this.showConsentModal = false;
        this.isModalOpen = true;
    }

    handleConsentKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeConsentModal();
        }
    }

    confirmConsentAndSubmitBank() {
        this.showConsentModal = false;
        this.bankConsentGiven = true;
        this.isModalOpen = true;
        this.submitModal();
    }

    // ------------------------------------------------------------------
    // Submit
    // ------------------------------------------------------------------

    async submitModal() {
        if (this.anySectionSubmitted) {
            this.showToast(APPROVAL_IN_PROGRESS_MESSAGE, 'error');
            return;
        }

        let section;
        let payload;

        if (this.isVatModal) {
            if (!this.validateVatForm()) return;
            section = 'VAT';
            payload = this.isVatUndertakingSelected
                ? { VAT_Certificate_Type__c: this.vatTypeSelection }
                : {
                      Proposed_VAT_Registration_Number__c: this.vatNumberTemp,
                      Proposed_VAT_Start_Date__c: this.vatStartDateTemp,
                      /* Hidden in the UI, resubmitted unchanged - see openVatModal. */
                      Proposed_VAT_Expiry_Date__c: this.vatExpiryDateTemp,
                      VAT_Certificate_Type__c: this.vatTypeSelection
                  };
        } else if (this.isTradeModal) {
            if (!this.validateTradeForm()) return;
            section = 'TRADE';
            payload = {
                Proposed_Trade_License_Number__c: this.tradeNumberTemp,
                Proposed_Trade_License_Expiry_Date__c: this.tradeExpiryDateTemp,
                Proposed_Trade_issuance_date__c: this.tradeIssuanceDateTemp,
                Licensing_Authority__c: this.licensingAuthorityTemp,
                Company_Name_as_per_Trade_License__c: this.companyNameTradeLicenseTemp
            };
        } else if (this.isBankModal) {
            if (!this.validateBankForm()) return;
            if (!this.bankConsentGiven) {
                this.isModalOpen = false;
                this.showConsentModal = true;
                return;
            }
            section = 'BANK';
            payload = {
                Proposed_Bank_Name__c: this.bankNameTemp,
                Proposed_Beneficiary_Name__c: this.beneficiaryNameTemp,
                Proposed_Bank_Account_Number__c: this.accountNumberTemp,
                Proposed_Bank_Country__c: this.bankCountryTemp,
                Proposed_IBAN_Number__c: this.ibanNumberTemp,
                Proposed_Bank_Branch_Name__c: this.bankBranchNameTemp,
                Proposed_Bank_Branch_Type__c: this.bankBranchTypeTemp,
                Proposed_SWIFT_Code__c: this.swiftCodeTemp
            };
        } else {
            return;
        }

        this.isActionPending = true;
        try {
            await submitSectionWithDocs({
                section,
                accountId: this.account.Id,
                payload,
                base64File: this.stagedFileBase64,
                fileName: this.stagedFileName
            });
            if (section === 'VAT') this.vatSubmitted = true;
            if (section === 'TRADE') this.tradeSubmitted = true;
            if (section === 'BANK') {
                this.bankSubmitted = true;
                this.bankConsentGiven = false;
            }
            this.showToast(`${section} details submitted successfully.`, 'success');
            this.closeModal();
            await this.refreshAgencyData();
        } catch (error) {
            this.showToast(`Failed to submit ${section} details.`, 'error');
            // The approval may already have fired server-side before the file
            // step failed, so re-read the true state instead of trusting ours.
            await this.refreshAgencyData();
        } finally {
            this.isActionPending = false;
        }
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    restoreFocus(element) {
        if (element && element.isConnected) {
            element.focus();
        }
    }

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