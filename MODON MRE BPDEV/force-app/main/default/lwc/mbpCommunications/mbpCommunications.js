import { LightningElement, track } from 'lwc';
import fetchData from '@salesforce/apex/CommunicationController.fetchData';
import mutate from '@salesforce/apex/CommunicationController.mutate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ACTIONS = {
    COMMUNICATION_TYPES: 'communicationTypes',
    REGIONS: 'regions',
    COUNTRIES: 'countries',
    STATES: 'states',
    INTERNAL_ROLES: 'internalRoles',
    AGENCIES: 'agencies',
    ORG_WIDE_EMAILS: 'orgWideEmails',
    AGENCY_CONTACTS: 'agencyContacts',
    USERS_BY_ROLES: 'usersByRoles',
    DRAFTS: 'drafts',
    UPLOAD_FILES: 'uploadFiles',
    BANNER_URL: 'bannerUrl',
    PREVIEW_HTML: 'previewHtml',
    SEND_TEST_EMAIL: 'sendTestEmail',
    PROCESS_COMMUNICATION: 'processCommunication',
    PUBLISH_DRAFTS: 'publishDrafts',
    SEND_WHATSAPP: 'sendWhatsApp'
};

const COMMUNICATION_TYPES = {
    INTERNAL: 'Internal',
    EXTERNAL: 'External'
};

const REGIONS = {
    ALL: 'ALL',
    DOMESTIC: 'Domestic',
    INTERNATIONAL: 'International'
};

const COUNTRIES = {
    UAE: 'United Arab Emirates'
};

const RECIPIENT_TYPES = {
    AGENCY_ADMIN: 'Agency Admin',
    OWNER: 'Owner',
    ALL: 'All'
};

const FILE_CONFIG = {
    MAX_FILE_SIZE: 10 * 1024 * 1024,
    BANNER_PREFIX: 'Banner_'
};

export default class CommunicationWizard extends LightningElement {
    @track currentMode = 'selection';
    @track communicationType = '';
    @track region = '';
    @track selectedCountries = [];
    @track selectedStates = [];
    @track selectedRoles = [];
    @track selectedAgencies = [];
    @track selectedRecipients = [];
    @track selectedUsers = [];

    @track emailSubject = '';
    @track selectedFromAddress = '';
    @track emailCC = '';
    @track emailBCC = '';
    @track emailContent = '';
    @track emailSmallBanner = '';

    @track draftCommunications = [];
    @track draftOptions = [];
    @track selectedDrafts = [];

    @track showPreviewScreen = false;
    @track isPreviewLoading = false;
    @track previewHtml = '';
    @track showEmailTestModal = false;
    @track testEmailRecipients = '';

    @track commTypeOptions = [];
    @track regionOptions = [];
    @track countryOptions = [];
    @track stateOptions = [];
    @track roleOptions = [];
    @track userOptions = [];
    @track agencyOptions = [];
    @track fromAddressOptions = [];

    @track users = [];
    @track contacts = [];

    @track isLoading = false;
    @track agenciesDisabled = true;

    @track uploadedFilesPrimary = [];
    @track uploadedFilesAdditional = [];
    primaryFileId = 1;
    additionalFileId = 1;
    MAX_FILE_SIZE = FILE_CONFIG.MAX_FILE_SIZE;

    @track showEmailModal = false;
    @track bannerPreviewUrl = '';

    @track showWhatsAppModal = false;
    @track whatsappMessage = '';

    recipientOptions = [
        { label: RECIPIENT_TYPES.AGENCY_ADMIN, value: RECIPIENT_TYPES.AGENCY_ADMIN },
        { label: RECIPIENT_TYPES.OWNER, value: RECIPIENT_TYPES.OWNER },
        { label: 'All Recipients', value: RECIPIENT_TYPES.ALL }
    ];

    get showCountryPicklist() {
        return this.region === REGIONS.INTERNATIONAL || this.region === REGIONS.ALL;
    }

    get showStatePicklist() {
        return this.region === REGIONS.DOMESTIC ||
            (this.region === REGIONS.ALL && this.selectedCountries.includes(COUNTRIES.UAE));
    }

    get selectedBrokerTypesArray() {
        return Array.isArray(this.selectedRecipients)
            ? this.selectedRecipients
            : (this.selectedRecipients ? this.selectedRecipients.split(',').map(recipient => recipient.trim()) : []);
    }

    get isInternal() {
        return this.communicationType === COMMUNICATION_TYPES.INTERNAL;
    }

    get isExternal() {
        return this.communicationType === COMMUNICATION_TYPES.EXTERNAL;
    }

    get isUsersDisabled() {
        return !this.selectedRoles || this.selectedRoles.length === 0;
    }

    get isEmailDisabled() {
        return !this.isReadyForEmail;
    }

    get isDomesticRegion() {
        return this.region === REGIONS.DOMESTIC;
    }

    get isAllRegion() {
        return this.region === REGIONS.ALL;
    }

    get isInternationalRegion() {
        return this.region === REGIONS.INTERNATIONAL;
    }

    get isSelectionMode() {
        return this.currentMode === 'selection';
    }

    get isNewMode() {
        return this.currentMode === 'new';
    }

    get isPublishMode() {
        return this.currentMode === 'publish';
    }

    get hasSelectedDrafts() {
        return this.selectedDrafts.length > 0;
    }

    get totalDraftsCount() {
        return this.draftCommunications.length;
    }

    get hasNoDrafts() {
        return this.draftCommunications.length === 0;
    }

    get selectedCountriesDisplay() {
        return !this.selectedCountries?.length ? 'None selected' : this.selectedCountries.join(', ');
    }

    get selectedStatesDisplay() {
        return !this.selectedStates?.length ? 'None selected' : this.selectedStates.join(', ');
    }

    get isReadyForEmail() {
        if (this.isInternal) {
            return this.selectedRoles.length > 0 && this.selectedUsers.length > 0;
        }
        if (this.isExternal) {
            return this.region && this.selectedAgencies.length > 0 && this.selectedRecipients.length > 0;
        }
        return false;
    }

    connectedCallback() {
        this.loadInitialData();
    }

    handleNewCommunication() {
        this.currentMode = 'new';
        this.resetForm();
    }

    async handlePublishDrafted() {
        this.currentMode = 'publish';
        this.isLoading = true;

        try {
            this.draftCommunications = await fetchData({ action: ACTIONS.DRAFTS, params: {} });
            this.draftOptions = this.draftCommunications.map(draftRecord => ({
                label: `${draftRecord.subject} (${draftRecord.communicationType} • ${draftRecord.region} • ${draftRecord.country})`,
                value: draftRecord.id
            }));

            if (!this.draftCommunications.length) {
                this.showToast('Info', 'No draft communications found.', 'info');
                this.currentMode = 'selection';
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load draft communications: ' + this.getErrorMessage(error), 'error');
            this.currentMode = 'selection';
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToSelection() {
        this.currentMode = 'selection';
        this.selectedDrafts = [];
    }

    handleDraftSelectionChange(event) {
        this.selectedDrafts = event.detail.value;
    }

    openEmailModal() {
        if (!this.validateConfiguration()) {
            return;
        }
        this.showEmailModal = true;
    }

    closeEmailModal() {
        this.showEmailModal = false;
    }

    async handleProceedToPreview() {
        if (!this.validateEmailForm()) {
            return;
        }
        if (!this.validateConfiguration()) {
            return;
        }

        this.showEmailModal = false;
        this.showPreviewScreen = true;
        await this.generatePreviewForScreen();
    }

    returnToComposeFromPreview() {
        this.showPreviewScreen = false;
        this.showEmailModal = true;
    }

    async generatePreviewForScreen() {
        this.isPreviewLoading = true;

        try {
            let bannerUrl = null;

            if (this.uploadedFilesAdditional.length > 0) {
                const bannerFile = this.uploadedFilesAdditional[0];
                if (bannerFile?.contentDocumentId) {
                    bannerUrl = await mutate({
                        action: ACTIONS.BANNER_URL,
                        params: { contentDocumentId: bannerFile.contentDocumentId }
                    });
                }
            }

            this.previewHtml = await mutate({
                action: ACTIONS.PREVIEW_HTML,
                params: {
                    subject: this.emailSubject,
                    htmlBody: this.emailContent,
                    hasBanner: this.uploadedFilesAdditional.length > 0,
                    bannerUrl: bannerUrl
                }
            });

            requestAnimationFrame(() => {
                const previewContainer = this.template.querySelector('.email-preview-screen');
                if (previewContainer) {
                    previewContainer.innerHTML = '';
                    previewContainer.appendChild(document.createRange().createContextualFragment(this.previewHtml || ''));
                }
            });
        } catch (error) {
            this.showToast('Error', 'Failed to generate preview: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isPreviewLoading = false;
        }
    }

    openTestFromPreviewScreen() {
        this.showEmailTestModal = true;
    }

    closeEmailTestModal() {
        this.showEmailTestModal = false;
        this.testEmailRecipients = '';
    }

    handleTestEmailRecipientsChange(event) {
        this.testEmailRecipients = event.target.value;
    }

    async sendTestEmail() {
        if (!this.testEmailRecipients?.trim()) {
            this.showToast('Error', 'Please enter at least one email address for testing', 'error');
            return;
        }

        const candidateEmails = this.testEmailRecipients.split(/[,;]/).map(email => email.trim()).filter(Boolean);
        const invalidEmails = candidateEmails.filter(email => !this.isValidEmail(email));

        if (invalidEmails.length) {
            this.showToast('Error', 'Invalid email format: ' + invalidEmails.join(', '), 'error');
            return;
        }

        this.isLoading = true;

        try {
            const primaryDocumentIds = this.uploadedFilesPrimary
                .filter(fileRecord => fileRecord.contentDocumentId)
                .map(fileRecord => fileRecord.contentDocumentId);

            const bannerDocumentIds = this.uploadedFilesAdditional
                .filter(fileRecord => fileRecord.contentDocumentId)
                .map(fileRecord => fileRecord.contentDocumentId);

            const attachmentIds = [...primaryDocumentIds, ...bannerDocumentIds];

            const result = await mutate({
                action: ACTIONS.SEND_TEST_EMAIL,
                params: {
                    subject: this.emailSubject,
                    htmlBody: this.emailContent,
                    ccAddresses: this.emailCC,
                    bccAddresses: this.emailBCC,
                    recipientEmails: candidateEmails,
                    attachmentIds: attachmentIds,
                    fromAddress: this.selectedFromAddress
                }
            });

            this.showToast('Success', result, 'success');
            this.showEmailTestModal = false;
            this.testEmailRecipients = '';
        } catch (error) {
            this.showToast('Error', 'Failed to send test email: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    openPrimaryUploader() {
        this.template.querySelector('.file-input-primary')?.click();
    }

    openAdditionalUploader() {
        this.template.querySelector('.file-input-additional')?.click();
    }

    async handlePrimaryUpload(event) {
        const files = [...(event.target.files || [])];
        event.target.value = '';

        for (const fileObject of files) {
            if (fileObject.size > this.MAX_FILE_SIZE) {
                this.showToast('Error', `${fileObject.name} exceeds 10MB`, 'error');
                continue;
            }

            const base64Value = await this.toBase64(fileObject);

            const result = await mutate({
                action: ACTIONS.UPLOAD_FILES,
                params: { files: [{ fileName: fileObject.name, base64Data: base64Value.split(',')[1] }] }
            });

            const contentDocumentId = result?.[0]?.contentDocumentId;

            this.uploadedFilesPrimary = [
                ...this.uploadedFilesPrimary,
                { id: this.primaryFileId++, name: fileObject.name, contentDocumentId: contentDocumentId }
            ];
        }
    }

    async handleAdditionalUpload(event) {
        const fileObject = event.target.files?.[0];
        event.target.value = '';

        if (!fileObject) {
            return;
        }

        if (this.uploadedFilesAdditional.length >= 1) {
            this.showToast('Error', 'Only one banner image allowed', 'error');
            return;
        }

        const allowedImageTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/svg+xml'];
        if (!allowedImageTypes.includes((fileObject.type || '').toLowerCase())) {
            this.showToast('Error', 'Only image files allowed for banner (JPEG, PNG, GIF, BMP, SVG)', 'error');
            return;
        }

        if (fileObject.size > this.MAX_FILE_SIZE) {
            this.showToast('Error', `${fileObject.name} exceeds 10MB limit`, 'error');
            return;
        }

        try {
            this.bannerPreviewUrl = URL.createObjectURL(fileObject);
            const prefixedFileName = `${FILE_CONFIG.BANNER_PREFIX}${fileObject.name}`;
            const base64Value = await this.toBase64(fileObject);

            const result = await mutate({
                action: ACTIONS.UPLOAD_FILES,
                params: { files: [{ fileName: prefixedFileName, base64Data: base64Value.split(',')[1] }] }
            });

            const contentDocumentId = result?.[0]?.contentDocumentId;

            this.uploadedFilesAdditional = [
                { id: this.additionalFileId++, name: prefixedFileName, contentDocumentId: contentDocumentId }
            ];

            this.showToast('Success', 'Banner uploaded successfully', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to upload banner: ' + this.getErrorMessage(error), 'error');
        }
    }

    async handlePreviewAction(event) {
        const previewAction = event.currentTarget.dataset.action;

        if (previewAction === 'test') {
            this.openTestFromPreviewScreen();
        }
        if (previewAction === 'draft') {
            await this.processCommunicationAction('Save As Draft');
        }
        if (previewAction === 'send') {
            await this.processCommunicationAction('Send Now');
        }
        if (previewAction === 'cancel') {
            this.closePreviewScreen();
        }
    }

    async processCommunicationAction(sentOption) {
        if (!this.validateConfiguration() || !this.validateEmailForm()) {
            return;
        }

        this.isLoading = true;

        try {
            const primaryDocumentIds = this.uploadedFilesPrimary
                .filter(fileRecord => fileRecord.contentDocumentId)
                .map(fileRecord => fileRecord.contentDocumentId);

            const bannerDocumentIds = this.uploadedFilesAdditional
                .filter(fileRecord => fileRecord.contentDocumentId)
                .map(fileRecord => fileRecord.contentDocumentId);

            const attachmentIds = [...primaryDocumentIds, ...bannerDocumentIds];

            const payload = {
                context: 'general',
                communicationType: this.communicationType,
                region: this.region,
                selectedCountries: this.selectedCountries,
                selectedStates: this.selectedStates,
                subject: this.emailSubject,
                fromAddress: this.selectedFromAddress,
                ccAddresses: this.emailCC,
                bccAddresses: this.emailBCC,
                htmlBody: this.emailContent,
                smallBanner: this.emailSmallBanner,
                sentOption: sentOption,
                selectedAgencies: this.selectedAgencies,
                brokerType: this.selectedBrokerTypesArray?.[0],
                attachmentIds: attachmentIds,
                selectedRecipients: this.selectedRecipients
            };

            if (this.isExternal && this.contacts?.length) {
                payload.selectedContacts = this.contacts.map(contactRecord => contactRecord.id);
            }

            if (this.isInternal && this.selectedUsers?.length) {
                payload.selectedUsers = this.selectedUsers;
            }

            const result = await mutate({ action: ACTIONS.PROCESS_COMMUNICATION, params: payload });
            this.showToast('Success', result, 'success');

            this.closePreviewScreen();
            this.resetForm();
            this.currentMode = 'selection';
        } catch (error) {
            this.showToast('Error', 'Failed to process communication: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closePreviewScreen() {
        this.showPreviewScreen = false;
        this.previewHtml = '';
        const previewContainer = this.template.querySelector('.email-preview-screen');
        if (previewContainer) {
            previewContainer.innerHTML = '';
        }
    }

    async loadInitialData() {
        this.isLoading = true;

        try {
            const [communicationTypes, regions, orgWideEmails] = await Promise.all([
                fetchData({ action: ACTIONS.COMMUNICATION_TYPES, params: {} }),
                fetchData({ action: ACTIONS.REGIONS, params: {} }),
                fetchData({ action: ACTIONS.ORG_WIDE_EMAILS, params: {} })
            ]);

            this.commTypeOptions = (communicationTypes || []).map(typeValue => ({ label: typeValue, value: typeValue }));
            this.regionOptions = (regions || []).map(regionValue => ({ label: regionValue, value: regionValue }));
            this.fromAddressOptions = orgWideEmails || [];

            if (this.fromAddressOptions.length > 0) {
                this.selectedFromAddress = this.fromAddressOptions[0].value;
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load initial data: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadCountries() {
        const countries = await fetchData({ action: ACTIONS.COUNTRIES, params: { region: this.region } });
        this.countryOptions = (countries || []).map(countryValue => ({ label: countryValue, value: countryValue }));
    }

    async loadStates() {
        const states = await fetchData({
            action: ACTIONS.STATES,
            params: { country: COUNTRIES.UAE, region: this.region }
        });
        this.stateOptions = (states || []).map(stateValue => ({ label: stateValue.label, value: stateValue.value }));
    }

    async loadRoles() {
        this.isLoading = true;

        try {
            this.roleOptions = await fetchData({ action: ACTIONS.INTERNAL_ROLES, params: {} });
        } catch (error) {
            this.showToast('Error', 'Failed to load roles: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadAgencies() {
        if (!this.region) {
            this.agenciesDisabled = true;
            this.agencyOptions = [];
            return;
        }

        if (this.region === REGIONS.DOMESTIC && !this.selectedStates?.length) {
            this.agenciesDisabled = true;
            this.agencyOptions = [];
            return;
        }

        if ((this.region === REGIONS.ALL || this.region === REGIONS.INTERNATIONAL) && !this.selectedCountries?.length) {
            this.agenciesDisabled = true;
            this.agencyOptions = [];
            return;
        }

        this.isLoading = true;

        try {
            this.agencyOptions = await fetchData({
                action: ACTIONS.AGENCIES,
                params: {
                    region: this.region,
                    selectedCountries: this.selectedCountries,
                    selectedStates: this.selectedStates
                }
            });
            this.agenciesDisabled = false;
        } catch (error) {
            this.showToast('Error', 'Failed to load agencies: ' + this.getErrorMessage(error), 'error');
            this.agenciesDisabled = true;
        } finally {
            this.isLoading = false;
        }
    }

    async loadUsersByRoles() {
        if (!this.selectedRoles?.length) {
            this.userOptions = [];
            return;
        }

        this.isLoading = true;

        try {
            const usersData = await fetchData({
                action: ACTIONS.USERS_BY_ROLES,
                params: { roleIds: this.selectedRoles }
            });

            this.userOptions = (usersData || []).map(userRecord => ({
                label: `${userRecord.name} - ${userRecord.email}`,
                value: userRecord.id,
                group: userRecord.roleName
            }));
            this.users = usersData || [];
        } catch (error) {
            this.showToast('Error', 'Failed to load users: ' + this.getErrorMessage(error), 'error');
            this.userOptions = [];
            this.users = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadExternalContacts() {
        if (!this.selectedAgencies?.length || !this.selectedBrokerTypesArray?.length) {
            this.contacts = [];
            return;
        }

        this.isLoading = true;

        try {
            this.contacts = await fetchData({
                action: ACTIONS.AGENCY_CONTACTS,
                params: {
                    agencyIds: this.selectedAgencies,
                    brokerTypes: this.selectedBrokerTypesArray
                }
            });
        } catch (error) {
            this.showToast('Error', 'Failed to load contacts: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCommTypeChange(event) {
        this.communicationType = event.detail.value;
        this.clearRecipients();

        if (this.isInternal) {
            this.region = '';
            this.selectedCountries = [];
            this.selectedStates = [];
            this.countryOptions = [];
            this.stateOptions = [];
            this.agencyOptions = [];
            this.selectedAgencies = [];
            this.selectedRecipients = [RECIPIENT_TYPES.ALL];
            this.contacts = [];
            this.loadRoles();
        } else {
            this.roleOptions = [];
            this.userOptions = [];
            this.selectedRoles = [];
            this.selectedUsers = [];
            this.users = [];
            this.agenciesDisabled = true;
        }
    }

    handleRegionChange(event) {
        this.region = event.detail.value;
        this.selectedCountries = [];
        this.selectedStates = [];
        this.selectedAgencies = [];
        this.agencyOptions = [];
        this.countryOptions = [];
        this.stateOptions = [];
        this.clearRecipients();
        this.agenciesDisabled = true;

        if (this.region === REGIONS.DOMESTIC) {
            this.selectedCountries = [COUNTRIES.UAE];
            this.loadStates();
        } else if (this.region === REGIONS.ALL || this.region === REGIONS.INTERNATIONAL) {
            this.loadCountries();
        }
    }

    handleCountriesChange(event) {
        this.selectedCountries = event.detail.value;
        this.selectedStates = [];
        this.stateOptions = [];
        this.agenciesDisabled = true;
        this.selectedAgencies = [];
        this.agencyOptions = [];

        if (this.selectedCountries?.length) {
            if (this.region === REGIONS.ALL && this.selectedCountries.includes(COUNTRIES.UAE)) {
                this.loadStates();
            }
            if (this.isExternal) {
                this.loadAgencies();
            }
        }
    }

    handleStatesChange(event) {
        this.selectedStates = event.detail.value;
        this.selectedAgencies = [];
        this.agencyOptions = [];
        this.contacts = [];

        if (this.isExternal) {
            this.loadAgencies();
        }
    }

    handleRoleToggle(event) {
        this.selectedRoles = event.detail.value;
        this.selectedUsers = [];
        this.userOptions = [];

        if (this.selectedRoles?.length) {
            this.loadUsersByRoles();
        }
    }

    handleUserSelectionChange(event) {
        this.selectedUsers = event.detail.value;
    }

    handleAgencyChange(event) {
        this.selectedAgencies = event.detail.value;

        if (this.selectedAgencies?.length && this.selectedBrokerTypesArray?.length) {
            this.loadExternalContacts();
        } else {
            this.contacts = [];
        }
    }

    handleRecipientChange(event) {
        const newValue = event.detail.value;

        if (newValue.includes(RECIPIENT_TYPES.ALL) && newValue.length > 1) {
            this.selectedRecipients = newValue.filter(value => value !== RECIPIENT_TYPES.ALL);
        } else {
            this.selectedRecipients = newValue;
        }

        if (this.selectedAgencies?.length && this.selectedRecipients?.length) {
            this.loadExternalContacts();
        } else {
            this.contacts = [];
        }
    }

    handleEmailContentChange(event) {
        this.emailContent = this.sanitizeHTML(event.detail.value);
    }

    handleEmailSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleFromAddressChange(event) {
        this.selectedFromAddress = event.detail.value;
    }

    handleEmailCCChange(event) {
        this.emailCC = event.target.value;
    }

    handleEmailBCCChange(event) {
        this.emailBCC = event.target.value;
    }

    async handlePublishDrafts() {
        if (!this.selectedDrafts.length) {
            this.showToast('Error', 'Please select at least one draft to publish.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await mutate({
                action: ACTIONS.PUBLISH_DRAFTS,
                params: { draftIds: this.selectedDrafts }
            });

            this.showToast('Success', result, 'success');
            await this.refreshDraftList();
            this.selectedDrafts = [];
        } catch (error) {
            this.showToast('Error', 'Failed to publish drafts: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshDraftList() {
        this.draftCommunications = await fetchData({ action: ACTIONS.DRAFTS, params: {} });
        this.draftOptions = this.draftCommunications.map(draftRecord => ({
            label: `${draftRecord.subject} (${draftRecord.communicationType} • ${draftRecord.region} • ${draftRecord.country})`,
            value: draftRecord.id
        }));
    }

    removePrimaryFile(event) {
        const fileId = parseInt(event.currentTarget.dataset.id, 10);
        this.uploadedFilesPrimary = this.uploadedFilesPrimary.filter(fileRecord => fileRecord.id !== fileId);
    }

    async removeAdditionalFile() {
        if (this.bannerPreviewUrl) {
            URL.revokeObjectURL(this.bannerPreviewUrl);
        }

        this.bannerPreviewUrl = '';
        this.uploadedFilesAdditional = [];

        const fileInput = this.template.querySelector('.file-input-additional');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    validateConfiguration() {
        if (!this.communicationType) {
            this.showToast('Error', 'Select communication type', 'error');
            return false;
        }

        if (this.isExternal) {
            if (!this.region) {
                this.showToast('Error', 'Select region for external communication', 'error');
                return false;
            }
            if ((this.region === REGIONS.INTERNATIONAL || this.region === REGIONS.ALL) && !this.selectedCountries?.length) {
                this.showToast('Error', 'Select at least one country', 'error');
                return false;
            }
            if (this.region === REGIONS.DOMESTIC && !this.selectedStates?.length) {
                this.showToast('Error', 'Select at least one emirate', 'error');
                return false;
            }
            if (!this.selectedAgencies?.length) {
                this.showToast('Error', 'Select at least one agency', 'error');
                return false;
            }
            if (!this.selectedBrokerTypesArray?.length) {
                this.showToast('Error', 'Select at least one recipient type', 'error');
                return false;
            }
            if (!this.contacts?.length) {
                this.showToast('Warning', 'No active contacts found for selected criteria. The communication will be saved but no emails will be sent.', 'warning');
            }
        }

        if (this.isInternal) {
            if (!this.selectedRoles?.length) {
                this.showToast('Error', 'Select at least one role for internal communication', 'error');
                return false;
            }
            if (!this.selectedUsers?.length) {
                this.showToast('Warning', 'Select users to send the communication.', 'warning');
                return false;
            }
        }

        return true;
    }

    validateEmailForm() {
        if (!this.emailSubject?.trim()) {
            this.showToast('Error', 'Enter email subject', 'error');
            return false;
        }
        if (!this.emailContent?.trim()) {
            this.showToast('Error', 'Enter email content', 'error');
            return false;
        }
        if (this.emailCC && !this.validateEmailField(this.emailCC)) {
            this.showToast('Error', 'Please enter valid CC email addresses separated by commas', 'error');
            return false;
        }
        if (this.emailBCC && !this.validateEmailField(this.emailBCC)) {
            this.showToast('Error', 'Please enter valid BCC email addresses separated by commas', 'error');
            return false;
        }
        return true;
    }

    clearRecipients() {
        this.users = [];
        this.userOptions = [];
        this.contacts = [];
        this.selectedRoles = [];
        this.selectedUsers = [];
        this.selectedAgencies = [];
        this.selectedRecipients = [];
    }

    resetForm() {
        this.communicationType = '';
        this.region = '';
        this.selectedCountries = [];
        this.selectedStates = [];
        this.selectedRoles = [];
        this.selectedUsers = [];
        this.selectedAgencies = [];
        this.selectedRecipients = [];
        this.emailSubject = '';
        this.selectedFromAddress = '';
        this.emailCC = '';
        this.emailBCC = '';
        this.emailContent = '';
        this.emailSmallBanner = '';
        this.users = [];
        this.userOptions = [];
        this.contacts = [];
        this.countryOptions = [];
        this.stateOptions = [];
        this.roleOptions = [];
        this.agencyOptions = [];
        this.agenciesDisabled = true;
        this.uploadedFilesPrimary = [];
        this.uploadedFilesAdditional = [];
        this.primaryFileId = 1;
        this.additionalFileId = 1;

        if (this.bannerPreviewUrl) {
            URL.revokeObjectURL(this.bannerPreviewUrl);
        }
        this.bannerPreviewUrl = '';
    }

    toBase64(fileObject) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(fileObject);
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
        });
    }

    sanitizeHTML(htmlValue) {
        if (!htmlValue) {
            return '';
        }

        try {
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = htmlValue;

            const allowedTags = ['p', 'br', 'strong', 'em', 'u', 'b', 'i', 'ul', 'ol', 'li', 'span', 'div', 'img', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'tr', 'td', 'th', 'thead', 'tbody'];
            const allowedAttributes = ['style', 'class', 'align', 'src', 'alt', 'width', 'height', 'border', 'cellpadding', 'cellspacing', 'color', 'background'];

            tempDiv.querySelectorAll('script,style,head').forEach(elementNode => elementNode.remove());

            tempDiv.querySelectorAll('*').forEach(elementNode => {
                [...elementNode.attributes].forEach(attributeNode => {
                    if (attributeNode.name.startsWith('on') || (!allowedAttributes.includes(attributeNode.name) && !attributeNode.name.startsWith('data-'))) {
                        elementNode.removeAttribute(attributeNode.name);
                    }
                });

                if (!allowedTags.includes(elementNode.tagName.toLowerCase())) {
                    const fragment = document.createDocumentFragment();
                    while (elementNode.firstChild) {
                        fragment.appendChild(elementNode.firstChild);
                    }
                    elementNode.parentNode.replaceChild(frag, elementNode);
                }
            });

            return tempDiv.innerHTML;
        } catch (error) {
            return htmlValue || '';
        }
    }

    isValidEmail(emailAddress) {
        if (!emailAddress) {
            return false;
        }
        const emailPattern = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/;
        return emailPattern.test(emailAddress.trim());
    }

    validateEmailField(emailString) {
        if (!emailString?.trim()) {
            return true;
        }

        const emailValues = emailString.split(/[,;]/).map(email => email.trim()).filter(Boolean);
        return emailValues.every(email => this.isValidEmail(email));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error occurred';
    }

    handleWhatsAppClick() {
        if (!this.contacts || this.contacts.length === 0) {
            this.showToast('Error', 'No contacts available', 'error');
            return;
        }

        this.showWhatsAppModal = true;
    }

    handleWhatsAppMessage(event) {
        this.whatsappMessage = event.target.value;
    }

    closeWhatsAppModal() {
        this.showWhatsAppModal = false;
    }

    async sendWhatsApp() {
        if (!this.whatsappMessage) {
            this.showToast('Error', 'Enter message', 'error');
            return;
        }

        try {
            const contactIds = this.contacts.map(contactRecord => contactRecord.id);

            const result = await mutate({
                action: ACTIONS.SEND_WHATSAPP,
                params: {
                    contactIds: contactIds,
                    message: this.whatsappMessage
                }
            });

            this.showToast('Success', result, 'success');
            this.showWhatsAppModal = false;
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }
}