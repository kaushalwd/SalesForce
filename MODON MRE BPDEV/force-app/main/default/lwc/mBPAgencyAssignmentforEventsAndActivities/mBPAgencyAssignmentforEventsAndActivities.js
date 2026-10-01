import { LightningElement, api, track } from 'lwc';
import getAgencies from '@salesforce/apex/MBP_ManageEventsandActivities.getAgencies';
import getBankCountries from '@salesforce/apex/MBP_ManageEventsandActivities.getBankCountries';
import getAssignedAgencies from '@salesforce/apex/MBP_ManageEventsandActivities.getAssignedAgencies';
import assignAgenciesToEvent from '@salesforce/apex/MBP_ManageEventsandActivities.assignAgenciesToEvent';

import fetchData from '@salesforce/apex/CommunicationController.fetchData';
import mutate from '@salesforce/apex/CommunicationController.mutate';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class MbpAgencyAssignmentforEventsAndActivities extends LightningElement {
    @api recordId;

    @track selectedType = 'All';
    @track selectedCountry = 'All';
    @track selectedEmirate = 'All';
    @track searchTerm = '';
    @track agencyOptions = [];
    @track selectedAgencyIds = [];
    @track previousAssignedIds = [];
    @track bankCountryOptions = [];
    @track isLoading = false;

    // Communication properties
    @track showCommunicationSection = false;
    @track agencyContacts = [];
    @track selectedBrokerTypes = ['All'];
    @track emailSubject = '';
    @track selectedFromAddress = '';
    @track emailCC = '';
    @track emailBCC = '';
    @track emailBody = '';
    @track scheduledDateTime = '';
    @track fromAddressOptions = [];
    @track showScheduleDateTime = false;
    @track showPreviewScreen = false;
    @track isPreviewLoading = false;
    @track previewHtml = '';
    @track showEmailTestModal = false;
    @track testEmailRecipients = '';

    // Attachment properties
    @track uploadedFiles = [];
    @track nextFileId = 1;
    MAX_FILE_SIZE = 10 * 1024 * 1024;
    MAX_TOTAL_FILES = 10;
    @track isUploading = false;
    @track uploadProgress = 0;

    // Banner Upload properties
    @track bannerPreviewUrl = '';
    @track uploadedBannerFile = null;
    @track isUploadingBanner = false;

    typeOptions = [
        { label: 'All Agencies', value: 'All' },
        { label: 'United Arab Emiarates Agencies', value: 'United Arab Emiarates' },
        { label: 'International Agencies', value: 'International' }
    ];

    emirateOptions = [
        { label: 'All Emirates', value: 'All' },
        { label: 'Dubai', value: 'Dubai' },
        { label: 'Abu Dhabi', value: 'Abu Dhabi' },
        { label: 'Sharjah', value: 'Sharjah' },
        { label: 'Ajman', value: 'Ajman' },
        { label: 'Umm Al Quwain', value: 'Umm Al Quwain' },
        { label: 'Ras Al Khaimah', value: 'Ras Al Khaimah' },
        { label: 'Fujairah', value: 'Fujairah' }
    ];

    brokerTypeOptions = [
        { label: 'All', value: 'All' },
        { label: 'Agency Admin', value: 'Agency Admin' },
        { label: 'Owner', value: 'Owner' }
    ];

    get showCountryFilter() { return this.selectedType === 'International'; }
    get showEmirateFilter() { return this.selectedType === 'United Arab Emiarates'; }
    get hasSelectedAgencies() { return this.selectedAgencyIds && this.selectedAgencyIds.length > 0; }
    get totalContacts() { return this.agencyContacts ? this.agencyContacts.length : 0; }
    get isSaveOnlyDisabled() { return !this.hasSelectedAgencies || this.isLoading; }
    get isSaveAndSendDisabled() { return !this.hasSelectedAgencies || this.isLoading; }
    get isPreviewDisabled() { return !this.emailSubject?.trim() || !this.emailBody?.trim(); }

    get hasAttachments() {
        return this.uploadedFiles.length > 0;
    }

    connectedCallback() {
        this.loadBankCountries();
        this.loadAgencies();
        this.loadOrgWideEmailAddresses();
    }

    async loadBankCountries() {
        try {
            const countries = await getBankCountries();
            this.bankCountryOptions = [{ label: 'All Countries', value: 'All' }, ...countries.map(c => ({ label: c, value: c }))];
        } catch (error) {
            this.showToast('Error', 'Failed to load countries', 'error');
        }
    }

    async loadOrgWideEmailAddresses() {
        try {
            const result = await fetchData({
                action: 'orgWideEmails',
                params: {}
            });

            this.fromAddressOptions = result || [];
            if (this.fromAddressOptions.length > 0) {
                this.selectedFromAddress = this.fromAddressOptions[0].value;
            }
        } catch (error) {
            console.error('Error loading org-wide email addresses:', error);
        }
    }

    async loadAgencies() {
        try {
            this.isLoading = true;
            const result = await getAgencies({
                filterType: this.selectedType === 'All' ? null : this.selectedType,
                country: this.selectedCountry === 'All' ? null : this.selectedCountry,
                emirate: this.selectedEmirate === 'All' ? null : this.selectedEmirate,
                eventId: this.recordId
            });

            const agencies = result || [];
            this.previousAssignedIds = await getAssignedAgencies({ eventId: this.recordId });
            this.selectedAgencyIds = [...this.previousAssignedIds];

            let filtered = agencies;
            if (this.searchTerm) {
                const term = this.searchTerm.toLowerCase();
                filtered = filtered.filter(a =>
                    (a.Name && a.Name.toLowerCase().includes(term)) ||
                    (a.Bank_Country__c && a.Bank_Country__c.toLowerCase().includes(term)) ||
                    (a.BillingCity && a.BillingCity.toLowerCase().includes(term))
                );
            }

            this.agencyOptions = filtered.map(a => ({
                label: `${a.Name} (${this.previousAssignedIds.includes(a.Id) ? 'Previously Assigned' : 'Available'})`,
                value: a.Id,
                description: `${a.BillingCity || ''} ${a.BillingCountry || ''}`.trim()
            }));

        } catch (error) {
            this.showToast('Error', 'Failed to load agencies', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadAgencyContacts() {
        if (!this.hasSelectedAgencies) {
            this.agencyContacts = [];
            return;
        }

        try {
            this.isLoading = true;

            const result = await fetchData({
                action: 'agencyContacts',
                params: {
                    agencyIds: this.selectedAgencyIds,
                    brokerTypes: this.selectedBrokerTypes
                }
            });

            this.agencyContacts = (result || []).map(contact => ({
                id: contact.id,
                name: contact.name,
                email: contact.email,
                accountName: contact.accountName,
                brokerType: contact.brokerType
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load contacts: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleTypeChange(e) {
        this.selectedType = e.detail.value;
        this.selectedCountry = 'All';
        this.selectedEmirate = 'All';
        this.loadAgencies();
    }

    handleCountryChange(e) {
        this.selectedCountry = e.detail.value;
        this.loadAgencies();
    }

    handleEmirateChange(e) {
        this.selectedEmirate = e.detail.value;
        this.loadAgencies();
    }

    handleSearchChange(e) {
        this.searchTerm = e.detail.value;
        this.loadAgencies();
    }

    handleSelectionChange(e) {
        this.selectedAgencyIds = e.detail.value;
        if (this.showCommunicationSection && this.hasSelectedAgencies) {
            this.loadAgencyContacts();
        } else if (!this.hasSelectedAgencies) {
            this.agencyContacts = [];
        }
    }

    handleBrokerTypeChange(e) {
        this.selectedBrokerTypes = e.detail.value;
        if (this.showCommunicationSection && this.hasSelectedAgencies) {
            this.loadAgencyContacts();
        }
    }

    handleEmailSubjectChange(e) { this.emailSubject = e.target.value; }
    handleFromAddressChange(e) { this.selectedFromAddress = e.detail.value; }
    handleEmailCCChange(e) { this.emailCC = e.target.value; }
    handleEmailBCCChange(e) { this.emailBCC = e.target.value; }
    handleEmailBodyChange(e) { this.emailBody = e.detail.value; }

    handleScheduleDateTimeChange(e) {
        let value = e.target.value;
        if (value) {
            if (value.includes('T') && value.split(':').length === 2) {
                value = value + ':00';
            }
            this.scheduledDateTime = value.replace('T', ' ');
        }
    }

    openBannerUploader() {
        this.template.querySelector('.file-input-banner')?.click();
    }

    async handleBannerUpload(event) {
        const file = event.target.files[0];
        event.target.value = '';

        if (!file) return;

        const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/svg+xml'];
        if (!allowedTypes.includes((file.type || '').toLowerCase())) {
            this.showToast('Error', 'Only image files allowed for banner (JPEG, PNG, GIF, BMP, SVG)', 'error');
            return;
        }

        if (file.size > this.MAX_FILE_SIZE) {
            this.showToast('Error', `${file.name} exceeds 10MB limit`, 'error');
            return;
        }

        this.isUploadingBanner = true;

        try {
            this.bannerPreviewUrl = URL.createObjectURL(file);
            const prefixedFileName = `Banner_${file.name}`;
            const base64 = await this.toBase64(file);

            const result = await mutate({
                action: 'uploadFiles',
                params: {
                    files: [{ fileName: prefixedFileName, base64Data: base64.split(',')[1] }]
                }
            });

            const cdId = result?.[0]?.contentDocumentId;

            this.uploadedBannerFile = {
                id: Date.now(),
                name: prefixedFileName,
                contentDocumentId: cdId
            };

            this.showToast('Success', 'Banner uploaded successfully', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to upload banner: ' + this.getErrorMessage(error), 'error');
            this.bannerPreviewUrl = '';
            this.uploadedBannerFile = null;
        } finally {
            this.isUploadingBanner = false;
        }
    }

    removeBannerFile() {
        if (this.bannerPreviewUrl) {
            URL.revokeObjectURL(this.bannerPreviewUrl);
            this.bannerPreviewUrl = '';
        }
        this.uploadedBannerFile = null;

        const fileInput = this.template.querySelector('.file-input-banner');
        if (fileInput) fileInput.value = '';
    }

    handleUploaderClick() {
        const fileInput = this.template.querySelector('input.file-input');
        if (fileInput) fileInput.click();
    }

    async handleFileUpload(event) {
        const files = event.target.files;
        if (!files || files.length === 0) return;

        if (this.uploadedFiles.length + files.length > this.MAX_TOTAL_FILES) {
            this.showToast('Error', `Maximum ${this.MAX_TOTAL_FILES} files allowed.`, 'error');
            event.target.value = '';
            return;
        }

        this.isUploading = true;
        const newFiles = [];

        Array.from(files).forEach(file => {
            if (file.size > this.MAX_FILE_SIZE) {
                this.showToast('Error', `File "${file.name}" exceeds 10MB limit.`, 'error');
                return;
            }

            if (!this.validateFileType(file)) {
                this.showToast('Error', `File "${file.name}" has an unsupported file type.`, 'error');
                return;
            }

            const invalidChars = /[<>:"/\\|?*]/;
            if (invalidChars.test(file.name)) {
                this.showToast('Error', `File "${file.name}" contains invalid characters.`, 'error');
                return;
            }

            const existingFile = this.uploadedFiles.find(f => f.name === file.name);
            if (existingFile) {
                this.showToast('Error', `File "${file.name}" is already uploaded.`, 'error');
                return;
            }

            const fileObj = {
                id: this.nextFileId++,
                name: file.name,
                size: this.formatFileSize(file.size),
                type: file.type || 'application/octet-stream',
                iconName: this.getFileIcon(file.type),
                file: file,
                status: 'pending',
                progress: 0,
                contentDocumentId: null,
                errorMessage: null,
                statusBadgeLabel: 'Pending',
                statusBadgeClass: 'status-pending',
                isUploading: false,
                isError: false,
                progressStyle: 'width: 0%'
            };

            newFiles.push(fileObj);
            this.uploadedFiles = [...this.uploadedFiles, fileObj];
        });

        if (newFiles.length > 0) {
            for (const fileObj of newFiles) {
                await this.uploadSingleFile(fileObj);
            }
        }

        this.isUploading = false;
        event.target.value = '';
    }

    async uploadSingleFile(fileObj) {
        try {
            this.updateFileStatus(fileObj.id, 'uploading', 0);

            const base64 = await this.toBase64(fileObj.file);
            const base64Data = base64.split(',')[1];

            const fileData = {
                fileName: fileObj.name,
                base64Data: base64Data
            };

            for (let i = 10; i <= 90; i += 20) {
                setTimeout(() => {
                    this.updateFileStatus(fileObj.id, 'uploading', i);
                }, i * 10);
            }

            const result = await mutate({
                action: 'uploadFiles',
                params: { files: [fileData] }
            });

            const cdId = result?.[0]?.contentDocumentId;

            if (cdId) {
                this.updateFileStatus(fileObj.id, 'uploaded', 100, cdId);
                this.showToast('Success', `${fileObj.name} uploaded successfully`, 'success');
                return cdId;
            }

            throw new Error('Upload failed - no document ID returned');
        } catch (error) {
            console.error('Error uploading file:', error);
            this.updateFileStatus(fileObj.id, 'error', 0, null, this.getErrorMessage(error));
            this.showToast('Error', `Failed to upload ${fileObj.name}: ${this.getErrorMessage(error)}`, 'error');
            throw error;
        }
    }

    updateFileStatus(fileId, status, progress, contentDocumentId = null, errorMessage = null) {
        this.uploadedFiles = this.uploadedFiles.map(file => {
            if (file.id === fileId) {
                let statusBadgeLabel = 'Pending';
                let statusBadgeClass = 'status-pending';

                if (status === 'uploading') {
                    statusBadgeLabel = 'Uploading';
                    statusBadgeClass = 'status-uploading';
                } else if (status === 'uploaded') {
                    statusBadgeLabel = 'Uploaded';
                    statusBadgeClass = 'status-uploaded';
                } else if (status === 'error') {
                    statusBadgeLabel = 'Error';
                    statusBadgeClass = 'status-error';
                }

                return {
                    ...file,
                    status,
                    progress,
                    contentDocumentId,
                    errorMessage,
                    statusBadgeLabel,
                    statusBadgeClass,
                    isUploading: status === 'uploading',
                    isError: status === 'error',
                    progressStyle: `width: ${progress}%`
                };
            }
            return file;
        });
    }

    handleRemoveFile(event) {
        const button = event.currentTarget.closest('button.remove-attachment-btn');
        if (!button) return;

        const fileId = parseInt(button.dataset.id, 10);
        const fileToRemove = this.uploadedFiles.find(file => file.id === fileId);

        if (fileToRemove) {
            this.uploadedFiles = this.uploadedFiles.filter(file => file.id !== fileId);
            const fileInput = this.template.querySelector('input.file-input');
            if (fileInput) fileInput.value = '';
            this.showToast('Success', `Removed ${fileToRemove.name}`, 'success');
        }
    }

    toBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
        });
    }

    validateFileType(file) {
        const allowedTypes = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-powerpoint',
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'text/plain',
            'text/csv',
            'image/jpeg',
            'image/jpg',
            'image/png',
            'image/gif'
        ];

        if (!file.type) return true;
        return allowedTypes.includes(file.type.toLowerCase());
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    getFileIcon(fileType) {
        if (!fileType) return 'doctype:generic';
        const type = fileType.toLowerCase();
        if (type.includes('pdf')) return 'doctype:pdf';
        if (type.includes('word') || type.includes('doc')) return 'doctype:word';
        if (type.includes('excel') || type.includes('sheet')) return 'doctype:excel';
        if (type.includes('powerpoint') || type.includes('presentation')) return 'doctype:ppt';
        if (type.includes('image')) return 'doctype:image';
        if (type.includes('text') || type.includes('plain')) return 'doctype:txt';
        if (type.includes('csv')) return 'doctype:csv';
        return 'doctype:generic';
    }

    async handleSaveAssignmentsOnly() {
        if (!this.hasSelectedAgencies) {
            this.showToast('Warning', 'Please select at least one agency', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            await assignAgenciesToEvent({ eventId: this.recordId, agencyIds: this.selectedAgencyIds });
            await this.loadAgencies();
            this.showToast('Success', 'Agency assignments saved successfully', 'success');
            setTimeout(() => this.dispatchEvent(new CloseActionScreenEvent()), 1000);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to save assignments', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveAndCommunicate() {
        if (!this.hasSelectedAgencies) {
            this.showToast('Warning', 'Please select at least one agency', 'warning');
            return;
        }
        this.showCommunicationSection = true;
        await this.loadAgencyContacts();
    }

    handleProceedToPreview() {
        if (!this.validateCommunicationForm()) return;
        this.showCommunicationSection = false;
        this.showPreviewScreen = true;
        this.generatePreviewForScreen();
    }

    async generatePreviewForScreen() {
        this.isPreviewLoading = true;
        try {
            let bannerUrl = null;

            if (this.uploadedBannerFile?.contentDocumentId) {
                bannerUrl = await mutate({
                    action: 'bannerUrl',
                    params: { contentDocumentId: this.uploadedBannerFile.contentDocumentId }
                });
            }

            this.previewHtml = await mutate({
                action: 'previewHtml',
                params: {
                    subject: this.emailSubject,
                    htmlBody: this.emailBody,
                    hasBanner: !!this.uploadedBannerFile,
                    bannerUrl: bannerUrl
                }
            });

            requestAnimationFrame(() => {
                const container = this.template.querySelector('.email-preview-screen');
                if (container) {
                    container.innerHTML = '';
                    const fragment = document.createRange().createContextualFragment(this.previewHtml || '');
                    container.appendChild(fragment);
                }
            });
        } catch (error) {
            this.showToast('Error', 'Failed to generate preview: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isPreviewLoading = false;
        }
    }

    async handlePreviewAction(event) {
        const action = event.currentTarget.dataset.action;
        switch (action) {
            case 'send':
                await this.processCommunicationAction('Send Now');
                break;
            case 'draft':
                await this.processCommunicationAction('Save As Draft');
                break;
            case 'test':
                this.openTestFromPreviewScreen();
                break;
            case 'cancel':
                this.closePreviewScreen();
                break;
            default:
                break;
        }
    }

    async processCommunicationAction(sentOption) {
        if (!this.validateCommunicationForm()) return;
        this.isLoading = true;

        try {
            await assignAgenciesToEvent({
                eventId: this.recordId,
                agencyIds: this.selectedAgencyIds
            });

            const allContactIds = (this.agencyContacts || []).map(c => c.id);

            const regularDocIds = this.uploadedFiles
                .filter(f => f.status === 'uploaded' && f.contentDocumentId)
                .map(f => f.contentDocumentId);

            const allAttachmentIds = [
                ...(this.uploadedBannerFile?.contentDocumentId ? [this.uploadedBannerFile.contentDocumentId] : []),
                ...regularDocIds
            ];

            const communicationData = {
                context: 'event',
                eventId: this.recordId,
                agencyIds: this.selectedAgencyIds,
                contactIds: allContactIds,
                subject: this.emailSubject,
                htmlBody: this.emailBody,
                smallBanner: '',
                sentOption: sentOption,
                ccAddresses: this.emailCC,
                bccAddresses: this.emailBCC,
                attachmentIds: allAttachmentIds,
                selectedRecipients: this.selectedBrokerTypes,
                fromAddress: this.selectedFromAddress
            };

            if (sentOption === 'Send Later' && this.scheduledDateTime) {
                communicationData.scheduledDateTime = this.scheduledDateTime;
            }

            const result = await mutate({
                action: 'processCommunication',
                params: communicationData
            });

            this.showToast('Success', result, 'success');
            this.closePreviewScreen();
            this.resetCommunicationForm();
            this.showCommunicationSection = false;
            this.uploadedFiles = [];
            this.removeBannerFile();

            setTimeout(() => this.dispatchEvent(new CloseActionScreenEvent()), 2000);
        } catch (error) {
            console.error('Error details:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    openTestFromPreviewScreen() {
        this.showEmailTestModal = true;
    }

    closeEmailTestModal() {
        this.showEmailTestModal = false;
        this.testEmailRecipients = '';
    }

    handleTestEmailRecipientsChange(e) {
        this.testEmailRecipients = e.target.value;
    }

    async sendTestEmail() {
        if (!this.testEmailRecipients || this.testEmailRecipients.trim() === '') {
            this.showToast('Error', 'Please enter at least one email address for testing', 'error');
            return;
        }

        const recipientArray = this.testEmailRecipients.split(/[,;]/).map(e => e.trim()).filter(Boolean);
        const validEmails = [];
        const invalidEmails = [];

        recipientArray.forEach(email => this.isValidEmail(email) ? validEmails.push(email) : invalidEmails.push(email));

        if (invalidEmails.length > 0) {
            this.showToast('Error', 'Invalid email format: ' + invalidEmails.join(', '), 'error');
            return;
        }

        if (validEmails.length === 0) {
            this.showToast('Error', 'Please enter at least one valid email address', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const regularDocIds = this.uploadedFiles
                .filter(f => f.status === 'uploaded' && f.contentDocumentId)
                .map(f => f.contentDocumentId);

            const allAttachmentIds = [
                ...(this.uploadedBannerFile?.contentDocumentId ? [this.uploadedBannerFile.contentDocumentId] : []),
                ...regularDocIds
            ];

            const result = await mutate({
                action: 'sendTestEmail',
                params: {
                    subject: this.emailSubject,
                    htmlBody: this.emailBody,
                    ccAddresses: this.emailCC,
                    bccAddresses: this.emailBCC,
                    recipientEmails: validEmails,
                    attachmentIds: allAttachmentIds,
                    selectedRecipients: this.selectedBrokerTypes,
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

    closePreviewScreen() {
        this.showPreviewScreen = false;
        this.previewHtml = '';
        const container = this.template.querySelector('.email-preview-screen');
        if (container) container.innerHTML = '';
    }

    returnToComposeFromPreview() {
        this.showPreviewScreen = false;
        this.showCommunicationSection = true;
    }

    handleCancelCombinedAction() {
        this.showCommunicationSection = false;
        this.resetCommunicationForm();
    }

    resetCommunicationForm() {
        this.emailSubject = '';
        this.emailCC = '';
        this.emailBCC = '';
        this.emailBody = '';
        this.scheduledDateTime = '';
        this.showScheduleDateTime = false;
        this.uploadedFiles = [];
        this.removeBannerFile();
    }

    validateCommunicationForm() {
        if (!this.emailSubject?.trim()) {
            this.showToast('Error', 'Please enter email subject', 'error');
            return false;
        }
        if (!this.emailBody?.trim()) {
            this.showToast('Error', 'Please enter email body', 'error');
            return false;
        }
        if (!this.selectedFromAddress?.trim()) {
            this.showToast('Error', 'Please select From Address', 'error');
            return false;
        }
        return true;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    isValidEmail(email) {
        if (!email) return false;
        const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/;
        return emailRegex.test(email.trim());
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error occurred';
    }
}