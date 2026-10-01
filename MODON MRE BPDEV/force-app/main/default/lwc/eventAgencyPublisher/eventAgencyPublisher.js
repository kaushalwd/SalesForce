import { LightningElement, api, track } from 'lwc';
import { RefreshEvent } from 'lightning/refresh';
import getEventContext from '@salesforce/apex/MBP_ManageEventsandActivities.getEventContext';
import getAgencies from '@salesforce/apex/MBP_ManageEventsandActivities.getAgencies';
import getBankCountries from '@salesforce/apex/MBP_ManageEventsandActivities.getBankCountries';
import getAssignedAgencies from '@salesforce/apex/MBP_ManageEventsandActivities.getAssignedAgencies';
import finalizeEventWizard from '@salesforce/apex/MBP_ManageEventsandActivities.finalizeEventWizard';

import fetchData from '@salesforce/apex/CommunicationController.fetchData';
import mutate from '@salesforce/apex/CommunicationController.mutate';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const STEP_AGENCY = 'agency';
const STEP_COMMS = 'communication';
const STEP_FINAL = 'final';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const MAX_TOTAL_FILES = 10;

export default class EventAgencyPublisher extends LightningElement {
    @api recordId;

    // Card
    @track showWizard = false;
    @track eventStatus;
    @track eventName;
    @track communicationSent = false;
    @track eventStart;
    @track eventEnd;
    @track nowTick = Date.now();
    countdownTimer;

    // Wizard - context
    @track isLoadingContext = true;
    @track isLoadingAgencies = false;
    @track isFinalizing = false;
    @track eventType;
    @track requiresApproval = true;
    @track currentStepKey = STEP_AGENCY;

    // Step 1 - agency mapping
    @track selectedType = 'All';
    @track selectedCountry = 'All';
    @track selectedEmirate = 'All';
    @track searchTerm = '';
    @track agencyOptions = [];
    @track selectedAgencyIds = [];
    @track bankCountryOptions = [];

    // Step 2 - communication
    @track sendCommunication = false;
    @track selectedBrokerTypes = ['All'];
    @track emailSubject = '';
    @track selectedFromAddress = '';
    @track emailCC = '';
    @track emailBCC = '';
    @track emailBody = '';
    @track fromAddressOptions = [];
    @track uploadedFiles = [];
    nextFileId = 1;

    typeOptions = [
        { label: 'All Agencies', value: 'All' },
        { label: 'United Arab Emirates Agencies', value: 'UAE' },
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

    connectedCallback() {
        this.loadStatus();
        this.countdownTimer = setInterval(() => {
            this.nowTick = Date.now();
        }, 30000);
    }

    disconnectedCallback() {
        if (this.countdownTimer) clearInterval(this.countdownTimer);
    }

    // ---------- Card ----------

    async loadStatus() {
        try {
            const ctx = await getEventContext({ eventId: this.recordId });
            this.eventStatus = ctx.status;
            this.eventName = ctx.name;
            this.communicationSent = ctx.communicationSent === 'true' || ctx.communicationSent === true;
            this.eventStart = ctx.startDateTime ? Number(ctx.startDateTime) : null;
            this.eventEnd = ctx.endDateTime ? Number(ctx.endDateTime) : null;
            this.nowTick = Date.now();
        } catch (e) {
            this.eventStatus = undefined;
            this.eventName = undefined;
            this.communicationSent = false;
            this.eventStart = null;
            this.eventEnd = null;
        }
    }

    get isPublished() {
        return this.eventStatus === 'Published';
    }

    get dateRangeLabel() {
        if (!this.eventStart) return '';
        const fmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
        const startLabel = fmt.format(new Date(this.eventStart));
        const endLabel = this.eventEnd ? fmt.format(new Date(this.eventEnd)) : '';
        return endLabel ? `${startLabel} – ${endLabel}` : startLabel;
    }

    get countdownState() {
        if (!this.eventStart) return 'unknown';
        const end = this.eventEnd || this.eventStart;
        if (this.nowTick < this.eventStart) return 'upcoming';
        if (this.nowTick <= end) return 'live';
        return 'ended';
    }

    get countdownLabel() {
        const state = this.countdownState;
        if (state === 'upcoming') return `Starts in ${this.formatDuration(this.eventStart - this.nowTick)}`;
        if (state === 'live') return 'Happening now';
        if (state === 'ended') return 'Event ended';
        return '';
    }

    get timerClass() {
        return `stub-card__timer stub-card__timer_${this.countdownState}`;
    }

    get showProgress() {
        return this.countdownState === 'live';
    }

    get progressStyle() {
        const start = this.eventStart;
        const end = this.eventEnd || start;
        if (!start || end === start) return 'width: 0%';
        const pct = Math.min(100, Math.max(0, ((this.nowTick - start) / (end - start)) * 100));
        return `width: ${pct}%`;
    }

    formatDuration(ms) {
        const totalMinutes = Math.max(0, Math.floor(ms / 60000));
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        if (days > 0) return `${days}d ${hours}h`;
        if (hours > 0) return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    get statusLabel() {
        if (this.eventStatus === 'Published') return 'Published';
        if (this.eventStatus === 'Pending for Approval') return 'Submitted for approval';
        return 'Not yet assigned';
    }

    get subLabel() {
        return this.communicationSent ? `${this.statusLabel} · Email sent` : this.statusLabel;
    }

    get statusPillClass() {
        if (this.eventStatus === 'Published') return 'stub-card__status stub-card__status_published';
        if (this.eventStatus === 'Pending for Approval') return 'stub-card__status stub-card__status_pending';
        return 'stub-card__status stub-card__status_draft';
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.openWizard();
        }
    }

    openWizard() {
        this.showWizard = true;
        this.resetWizardState();
        this.initWizard();
    }

    closeWizard() {
        this.showWizard = false;
        this.loadStatus();
    }

    resetWizardState() {
        this.currentStepKey = STEP_AGENCY;
        this.sendCommunication = false;
        this.emailSubject = '';
        this.emailCC = '';
        this.emailBCC = '';
        this.emailBody = '';
        this.uploadedFiles = [];
    }

    // ---------- Wizard - init ----------

    async initWizard() {
        this.isLoadingContext = true;
        try {
            const [ctx, countries, orgEmails, assignedIds] = await Promise.all([
                getEventContext({ eventId: this.recordId }),
                getBankCountries(),
                fetchData({ action: 'orgWideEmails', params: {} }),
                getAssignedAgencies({ eventId: this.recordId })
            ]);

            this.eventType = ctx.type;
            this.requiresApproval = ctx.requiresApproval === 'true' || ctx.requiresApproval === true;
            this.bankCountryOptions = [{ label: 'All Countries', value: 'All' }, ...countries.map((c) => ({ label: c, value: c }))];
            this.fromAddressOptions = orgEmails || [];
            if (this.fromAddressOptions.length) this.selectedFromAddress = this.fromAddressOptions[0].value;
            this.selectedAgencyIds = assignedIds || [];

            await this.loadAgencies();
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoadingContext = false;
        }
    }

    // ---------- Steps / path ----------

    get steps() {
        const finalLabel = this.requiresApproval ? 'Submit for approval' : 'Publish';
        const definitions = [
            { key: STEP_AGENCY, label: 'Assign agencies' },
            { key: STEP_COMMS, label: 'Communication' },
            { key: STEP_FINAL, label: finalLabel }
        ];
        const currentIndex = definitions.findIndex((d) => d.key === this.currentStepKey);

        return definitions.map((d, index) => {
            let state = 'upcoming';
            if (index < currentIndex) state = 'done';
            else if (index === currentIndex) state = 'current';
            return { ...d, pathClass: `wizard-path__step wizard-path__step_${state}` };
        });
    }

    get isAgencyStep() { return this.currentStepKey === STEP_AGENCY; }
    get isCommunicationStep() { return this.currentStepKey === STEP_COMMS; }
    get isFinalStep() { return this.currentStepKey === STEP_FINAL; }
    get isFirstStep() { return this.currentStepKey === STEP_AGENCY; }

    get eventTypeLabel() { return this.eventType ? `${this.eventType} event` : ''; }

    get finalStepTitle() { return this.requiresApproval ? 'Submit for approval' : 'Ready to publish'; }
    get finalActionLabel() { return this.requiresApproval ? 'Submit for approval' : 'Publish event'; }
    get finalStepHint() {
        return this.requiresApproval
            ? `${this.eventType} events need approval before they go live.`
            : `${this.eventType} events publish immediately — no approval step needed.`;
    }
    get finalizingLabel() {
        return this.requiresApproval ? 'Submitting for approval…' : 'Publishing event…';
    }

    get isNextDisabled() {
        if (this.isAgencyStep) return this.selectedAgencyIds.length === 0;
        if (this.isCommunicationStep && this.sendCommunication) {
            return !this.emailSubject?.trim() || !this.selectedFromAddress;
        }
        return false;
    }

    handleNext() {
        if (this.isAgencyStep) this.currentStepKey = STEP_COMMS;
        else if (this.isCommunicationStep) this.currentStepKey = STEP_FINAL;
    }

    handleBack() {
        if (this.isFinalStep) this.currentStepKey = STEP_COMMS;
        else if (this.isCommunicationStep) this.currentStepKey = STEP_AGENCY;
    }

    // ---------- Step 1: agency mapping ----------

    get showCountryFilter() { return this.selectedType === 'International'; }
    get showEmirateFilter() { return this.selectedType === 'UAE'; }

    async loadAgencies() {
        this.isLoadingAgencies = true;
        try {
            const result = await getAgencies({
                filterType: this.selectedType === 'All' ? null : this.selectedType,
                country: this.selectedCountry === 'All' ? null : this.selectedCountry,
                emirate: this.selectedEmirate === 'All' ? null : this.selectedEmirate,
                eventId: this.recordId
            });

            let filtered = result || [];
            if (this.searchTerm) {
                const term = this.searchTerm.toLowerCase();
                filtered = filtered.filter(
                    (a) =>
                        (a.Name && a.Name.toLowerCase().includes(term)) ||
                        (a.Bank_Country__c && a.Bank_Country__c.toLowerCase().includes(term)) ||
                        (a.BillingCity && a.BillingCity.toLowerCase().includes(term))
                );
            }

            this.agencyOptions = filtered.map((a) => ({
                label: a.Name,
                value: a.Id,
                description: `${a.BillingCity || ''} ${a.BillingCountry || ''}`.trim()
            }));
        } catch (error) {
            this.toast('Error', 'Failed to load agencies', 'error');
        } finally {
            this.isLoadingAgencies = false;
        }
    }

    handleTypeChange(e) {
        this.selectedType = e.detail.value;
        this.selectedCountry = 'All';
        this.selectedEmirate = 'All';
        this.loadAgencies();
    }

    handleCountryChange(e) { this.selectedCountry = e.detail.value; this.loadAgencies(); }
    handleEmirateChange(e) { this.selectedEmirate = e.detail.value; this.loadAgencies(); }
    handleSearchChange(e) { this.searchTerm = e.detail.value; this.loadAgencies(); }
    handleSelectionChange(e) { this.selectedAgencyIds = e.detail.value; }

    // ---------- Step 2: communication ----------

    handleSendToggle(e) { this.sendCommunication = e.detail.checked; }
    handleBrokerTypeChange(e) { this.selectedBrokerTypes = e.detail.value; }
    handleEmailSubjectChange(e) { this.emailSubject = e.target.value; }
    handleFromAddressChange(e) { this.selectedFromAddress = e.detail.value; }
    handleEmailCCChange(e) { this.emailCC = e.target.value; }
    handleEmailBCCChange(e) { this.emailBCC = e.target.value; }
    handleEmailBodyChange(e) { this.emailBody = e.detail.value; }

    handleUploaderClick() {
        this.template.querySelector('.file-input')?.click();
    }

    async handleFileUpload(event) {
        const files = event.target.files;
        if (!files || !files.length) return;

        if (this.uploadedFiles.length + files.length > MAX_TOTAL_FILES) {
            this.toast('Error', `Maximum ${MAX_TOTAL_FILES} files allowed.`, 'error');
            event.target.value = '';
            return;
        }

        for (const file of Array.from(files)) {
            if (file.size > MAX_FILE_SIZE) {
                this.toast('Error', `${file.name} exceeds 10MB.`, 'error');
                continue;
            }
            const fileObj = {
                id: this.nextFileId++,
                name: file.name,
                statusBadgeLabel: 'Uploading',
                statusBadgeClass: 'attachments__status attachments__status_uploading',
                contentDocumentId: null
            };
            this.uploadedFiles = [...this.uploadedFiles, fileObj];

            try {
                const base64 = await this.toBase64(file);
                const result = await mutate({
                    action: 'uploadFiles',
                    params: { files: [{ fileName: file.name, base64Data: base64.split(',')[1] }] }
                });
                this.updateFile(fileObj.id, 'Uploaded', 'attachments__status attachments__status_done', result?.[0]?.contentDocumentId);
            } catch (error) {
                this.updateFile(fileObj.id, 'Error', 'attachments__status attachments__status_error', null);
                this.toast('Error', `Failed to upload ${file.name}`, 'error');
            }
        }
        event.target.value = '';
    }

    updateFile(id, label, cssClass, contentDocumentId) {
        this.uploadedFiles = this.uploadedFiles.map((f) =>
            f.id === id ? { ...f, statusBadgeLabel: label, statusBadgeClass: cssClass, contentDocumentId } : f
        );
    }

    handleRemoveFile(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        this.uploadedFiles = this.uploadedFiles.filter((f) => f.id !== id);
    }

    toBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
        });
    }

    // ---------- Step 3: approval / publish ----------

    async handleFinalize() {
        this.isFinalizing = true;
        try {
            const newStatus = await finalizeEventWizard({
                eventId: this.recordId,
                agencyIds: this.selectedAgencyIds,
                requiresApproval: this.requiresApproval
            });

            if (this.sendCommunication) {
                const attachmentIds = this.uploadedFiles
                    .filter((f) => f.contentDocumentId)
                    .map((f) => f.contentDocumentId);

                await mutate({
                    action: 'processCommunication',
                    params: {
                        context: 'event',
                        eventId: this.recordId,
                        agencyIds: this.selectedAgencyIds,
                        subject: this.emailSubject,
                        htmlBody: this.emailBody,
                        sentOption: 'Send Now',
                        ccAddresses: this.emailCC,
                        bccAddresses: this.emailBCC,
                        attachmentIds,
                        selectedRecipients: this.selectedBrokerTypes,
                        fromAddress: this.selectedFromAddress
                    }
                });
            }

            this.toast('Success', `Event ${newStatus.toLowerCase()}.`, 'success');

            // Update this card immediately, then close and refresh the rest of the page
            // (related lists, record detail, etc.) so everything reflects the new state.
            await this.loadStatus();
            this.showWizard = false;
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.toast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isFinalizing = false;
        }
    }

    // ---------- Utilities ----------

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error occurred';
    }
}