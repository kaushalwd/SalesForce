import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import { refreshApex } from '@salesforce/apex';

import getTeamUsers from '@salesforce/apex/MBP_UserTeamController.getTeamUsers';
import getCases from '@salesforce/apex/MBP_ManageBrokerCases.getCases';
import upsertCase from '@salesforce/apex/MBP_ManageBrokerCases.upsertCase';
/* Category is the broker-facing selector, written to CaseCategory__c.

   Reverted from CaseCategory__c (MBPR-UI-248) because that field is a
   RESTRICTED picklist dependent on CaseCategory__c, and the Apex hardcoded
   CaseCategory__c = 'Broker' - a value that does not exist on the picklist.
   With no valid parent, every sub-category value was invalid and no case
   could be saved at all. MBP_ManageBrokerCases is now MODON_UAT's version
   verbatim, which writes CaseCategory__c with values that do exist
   ('Broker Enquiry', 'Broker Commission Enquiries') and never touches the
   sub-category. Apex serialises the field with this exact casing. */
import getCasecategories from '@salesforce/apex/MBP_ManageBrokerCases.getCasecategories';
import getCasesCSVData from '@salesforce/apex/MBP_ManageBrokerCases.getCasesCSVData';
import handleFileOperation from '@salesforce/apex/MBP_ManageBrokerCases.handleFileOperation';

const PAGE_SIZE = 10;
const WHATSAPP_URL = 'https://wa.me/971502155629';
const ALLOWED_FILE_TYPES = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
// Closed expands to the full closed-status family (ServiceConstants values).
const CLOSED_STATUS_VALUES = [
    'Closed with Resolution',
    'Closed without Resolution',
    'Closed with Service Request',
    'Closed as Duplicate'
];
const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'New', value: 'New' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Closed', value: 'Closed' }
];

export default class MbprHelpWorkspace extends LightningElement {
    activeTab = 'contact';

    // ---- Contact Us ----
    isContactLoading = true;
    contactError = '';
    contactCard = null;

    // ---- Cases ----
    serverStartDate = `${new Date().getFullYear()}-01-01`;
    serverEndDate = new Date().toISOString().slice(0, 10);
    isCasesLoading = true;
    casesError = '';
    allCases = [];
    _wiredCasesResult;

    searchKey = '';
    statusFilter = '';
    draftStartDate = `${new Date().getFullYear()}-01-01`;
    draftEndDate = new Date().toISOString().slice(0, 10);
    filterOpen = false;

    currentPage = 1;
    expandedCaseIds = [];

    // ---- Raise/Edit modal ----
    showModal = false;
    isEditMode = false;
    caseDraft = { Id: null, Subject: '', Description: '', CaseCategory__c: '' };
    fieldErrors = { subject: '', description: '', category: '' };
    categoryOptions = [];
    caseFiles = [];
    uploadedFile = null;
    isActionPending = false;

    // ---- File delete confirmation ----
    confirmationOpen = false;
    pendingDeleteDocumentId = null;

    _modalOpener = null;
    _confirmationOpener = null;
    _confirmationFocusPending = false;
    _objectUrls = [];

    connectedCallback() {
        this.loadContact();
        this.loadCategories();
    }

    disconnectedCallback() {
        this._objectUrls.forEach((url) => URL.revokeObjectURL(url));
        this._objectUrls = [];
    }

    renderedCallback() {
        if (this.confirmationOpen && this._confirmationFocusPending) {
            const primaryButton = this.template.querySelector('.confirmation__action--primary');
            if (primaryButton) {
                primaryButton.focus();
                this._confirmationFocusPending = false;
            }
        }
    }

    // ------------------------------------------------------------------
    // Tabs
    // ------------------------------------------------------------------

    get isContactTab() {
        return this.activeTab === 'contact';
    }

    get isCasesTab() {
        return this.activeTab === 'cases';
    }

    get contactTabClass() {
        return this.isContactTab ? 'subview-tab subview-tab--active' : 'subview-tab';
    }

    get casesTabClass() {
        return this.isCasesTab ? 'subview-tab subview-tab--active' : 'subview-tab';
    }

    handleShowContactTab() {
        this.activeTab = 'contact';
    }

    handleShowCasesTab() {
        this.activeTab = 'cases';
    }

    // ------------------------------------------------------------------
    // Contact Us
    // ------------------------------------------------------------------

    get whatsappUrl() {
        return WHATSAPP_URL;
    }

    async loadContact() {
        this.isContactLoading = true;
        this.contactError = '';
        try {
            const result = await getTeamUsers();
            const team = (result && result.BrokerManagementTeam) || [];
            const member = team.length ? team[0] : null;
            this.contactCard = member
                ? {
                      phone: member.phone || '',
                      email: member.email || '',
                      phoneHref: member.phone ? `tel:${member.phone.replace(/\s+/g, '')}` : '',
                      emailHref: member.email ? `mailto:${member.email}` : ''
                  }
                : null;
        } catch (error) {
            this.contactError =
                this.reduceError(error) || 'Unable to load contact details right now. Please try again.';
        } finally {
            this.isContactLoading = false;
        }
    }

    handleRetryContact() {
        this.loadContact();
    }

    // ------------------------------------------------------------------
    // Cases: wired and cacheable, so refreshApex is the only reliable refresh.
    // ------------------------------------------------------------------

    @wire(getCases, {
        caseExport: false,
        startDateFilter: '$serverStartDate',
        endDateFilter: '$serverEndDate'
    })
    wiredCases(result) {
        this._wiredCasesResult = result;
        const { data, error } = result;
        if (data) {
            this.allCases = data.map((row, index) => this.toCaseRow(row, index));
            this.casesError = '';
            this.isCasesLoading = false;
        } else if (error) {
            this.casesError =
                this.reduceError(error) || 'Unable to load cases right now. Please try again.';
            this.isCasesLoading = false;
        }
    }

    toCaseRow(row, index) {
        const status = row.Status || '';
        const links = (row.ContentDocumentLinks || []).map((link) => ({
            id: link.ContentDocumentId,
            title: link.ContentDocument ? link.ContentDocument.Title : '',
            extension: link.ContentDocument ? link.ContentDocument.FileExtension : ''
        }));
        let statusTone = 'neutral';
        if (status === 'New') statusTone = 'info';
        else if (status === 'In Progress') statusTone = 'warning';
        else if (CLOSED_STATUS_VALUES.includes(status)) statusTone = 'positive';
        return {
            id: row.Id,
            caseNumber: row.CaseNumber || '',
            status,
            statusTone,
            subject: row.Subject || '',
            description: row.Description || '',
            category: row.CaseCategory__c || 'Not specified',
            rawCategory: row.CaseCategory__c || '',
            resolutionComments: row.Resolution_Comments__c || '',
            raisedBy: row.CreatedBy ? row.CreatedBy.Name || '' : '',
            files: links,
            isEditable: status === 'New',
            sno: index + 1
        };
    }

    get statusOptions() {
        return STATUS_OPTIONS;
    }

    get filteredCases() {
        let rows = this.allCases;
        const search = (this.searchKey || '').trim().toLowerCase();
        if (search) {
            rows = rows.filter(
                (row) =>
                    row.caseNumber.toLowerCase().includes(search) ||
                    row.subject.toLowerCase().includes(search) ||
                    row.rawCategory.toLowerCase().includes(search) ||
                    row.raisedBy.toLowerCase().includes(search)
            );
        }
        if (this.statusFilter) {
            if (this.statusFilter === 'Closed') {
                rows = rows.filter((row) => CLOSED_STATUS_VALUES.includes(row.status));
            } else {
                rows = rows.filter((row) => row.status === this.statusFilter);
            }
        }
        return rows;
    }

    get pagedCases() {
        const rows = this.filteredCases;
        const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
        const safePage = Math.min(this.currentPage, totalPages);
        const start = (safePage - 1) * PAGE_SIZE;
        const expanded = new Set(this.expandedCaseIds);
        return rows.slice(start, start + PAGE_SIZE).map((row, index) => ({
            ...row,
            sno: start + index + 1,
            isExpanded: expanded.has(row.id),
            cardClass: expanded.has(row.id) ? 'case-card case-card--expanded' : 'case-card',
            expandIcon: expanded.has(row.id) ? 'utility:chevronup' : 'utility:chevrondown',
            expandLabel: expanded.has(row.id) ? 'Collapse details' : 'Expand details'
        }));
    }

    get hasFilteredCases() {
        return this.filteredCases.length > 0;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredCases.length / PAGE_SIZE));
    }

    get pageLabel() {
        return `Page ${Math.min(this.currentPage, this.totalPages)} of ${this.totalPages}`;
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get showPagination() {
        return this.filteredCases.length > PAGE_SIZE;
    }

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage -= 1;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage += 1;
    }

    handleToggleExpand(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.expandedCaseIds = this.expandedCaseIds.includes(id)
            ? this.expandedCaseIds.filter((existing) => existing !== id)
            : [...this.expandedCaseIds, id];
    }

    // ---- Filters (legacy model: dates refetch immediately; Apply re-runs
    // client search/status and closes the panel) ----

    toggleFilterPanel() {
        this.filterOpen = !this.filterOpen;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.currentPage = 1;
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
        this.currentPage = 1;
    }

    handleStartDateChange(event) {
        this.draftStartDate = event.target.value;
        this.isCasesLoading = true;
        this.serverStartDate = event.target.value;
        this.currentPage = 1;
    }

    handleEndDateChange(event) {
        this.draftEndDate = event.target.value;
        this.isCasesLoading = true;
        this.serverEndDate = event.target.value;
        this.currentPage = 1;
    }

    handleApplyFilters() {
        this.currentPage = 1;
        this.filterOpen = false;
    }

    handleResetFilters() {
        this.searchKey = '';
        this.statusFilter = '';
        const defaults = {
            start: `${new Date().getFullYear()}-01-01`,
            end: new Date().toISOString().slice(0, 10)
        };
        this.draftStartDate = defaults.start;
        this.draftEndDate = defaults.end;
        if (this.serverStartDate !== defaults.start || this.serverEndDate !== defaults.end) {
            this.isCasesLoading = true;
            this.serverStartDate = defaults.start;
            this.serverEndDate = defaults.end;
        }
        this.currentPage = 1;
    }

    handleRetryCases() {
        this.casesError = '';
        this.isCasesLoading = true;
        refreshApex(this._wiredCasesResult).finally(() => {
            this.isCasesLoading = false;
        });
    }

    // ------------------------------------------------------------------
    // Raise / Edit modal
    // ------------------------------------------------------------------

    loadCategories() {
        getCasecategories()
            .then((result) => {
                this.categoryOptions = (result || []).map((item) => ({ label: item, value: item }));
            })
            .catch(() => {
                this.categoryOptions = [];
            });
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Case' : 'New Case';
    }

    get hasCaseFiles() {
        return this.caseFiles.length > 0;
    }

    handleOpenCreateModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.isEditMode = false;
        this.caseDraft = { Id: null, Subject: '', Description: '', CaseCategory__c: '' };
        this.fieldErrors = { subject: '', description: '', category: '' };
        this.caseFiles = [];
        this.uploadedFile = null;
        this.showModal = true;
    }

    handleEditCase(event) {
        const row = this.allCases.find((existing) => existing.id === event.currentTarget.dataset.id);
        if (!row || !row.isEditable) return;
        this._modalOpener = event.currentTarget;
        this.isEditMode = true;
        this.caseDraft = {
            Id: row.id,
            Subject: row.subject,
            Description: row.description,
            CaseCategory__c: row.rawCategory
        };
        this.fieldErrors = { subject: '', description: '', category: '' };
        this.caseFiles = [...row.files];
        this.uploadedFile = null;
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.caseDraft = { Id: null, Subject: '', Description: '', CaseCategory__c: '' };
        this.fieldErrors = { subject: '', description: '', category: '' };
        this.caseFiles = [];
        this.uploadedFile = null;
        if (this._modalOpener && this._modalOpener.isConnected) {
            this._modalOpener.focus();
        }
        this._modalOpener = null;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeModal();
        }
    }

    handleDraftChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;
        if (field === 'CaseCategory__c') {
            this.caseDraft = { ...this.caseDraft, CaseCategory__c: value };
            this.fieldErrors = { ...this.fieldErrors, category: '' };
        } else if (field === 'Subject') {
            this.caseDraft = { ...this.caseDraft, Subject: value };
            this.fieldErrors = { ...this.fieldErrors, subject: '' };
        } else if (field === 'Description') {
            this.caseDraft = { ...this.caseDraft, Description: value };
            this.fieldErrors = { ...this.fieldErrors, description: '' };
        }
    }

    validateForm() {
        const errors = { subject: '', description: '', category: '' };
        let valid = true;
        if (!this.caseDraft.Subject || !this.caseDraft.Subject.trim()) {
            errors.subject = 'Subject is required';
            valid = false;
        }
        if (!this.caseDraft.Description || !this.caseDraft.Description.trim()) {
            errors.description = 'Description is required';
            valid = false;
        }
        if (!this.caseDraft.CaseCategory__c) {
            errors.category = 'Please select category';
            valid = false;
        }
        this.fieldErrors = errors;
        return valid;
    }

    // ---- Files ----

    handleFileSelected(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        if (!ALLOWED_FILE_TYPES.includes(file.type)) {
            this.showToast('Please upload PDF, JPG, or PNG files only', 'error');
            event.target.value = '';
            return;
        }
        this.uploadedFile = file;
    }

    handleRemovePendingFile() {
        this.uploadedFile = null;
        const input = this.template.querySelector('[data-id="caseFileInput"]');
        if (input) input.value = '';
    }

    handlePreviewPendingFile() {
        if (!this.uploadedFile) return;
        const url = URL.createObjectURL(this.uploadedFile);
        this._objectUrls.push(url);
        window.open(url, '_blank');
    }

    async handlePreviewExistingFile(event) {
        const documentId = event.currentTarget.dataset.id;
        if (!documentId) return;
        this.isActionPending = true;
        try {
            const fileData = await handleFileOperation({
                operation: 'download',
                base64Data: null,
                fileName: null,
                caseId: null,
                contentDocumentId: documentId
            });
            const byteString = atob(fileData.base64Data);
            const bytes = new Uint8Array(byteString.length);
            for (let i = 0; i < byteString.length; i += 1) {
                bytes[i] = byteString.charCodeAt(i);
            }
            const blob = new Blob([bytes], { type: fileData.fileType });
            const url = URL.createObjectURL(blob);
            this._objectUrls.push(url);
            window.open(url, '_blank');
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    handleRequestDeleteFile(event) {
        this.pendingDeleteDocumentId = event.currentTarget.dataset.id;
        this._confirmationOpener = event.currentTarget;
        this.confirmationOpen = true;
        this._confirmationFocusPending = true;
    }

    closeConfirmation() {
        this.confirmationOpen = false;
        this.pendingDeleteDocumentId = null;
        if (this._confirmationOpener && this._confirmationOpener.isConnected) {
            this._confirmationOpener.focus();
        }
        this._confirmationOpener = null;
    }

    handleConfirmationKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeConfirmation();
        }
    }

    stopEventPropagation(event) {
        event.stopPropagation();
    }

    async handleConfirmDeleteFile() {
        const documentId = this.pendingDeleteDocumentId;
        this.closeConfirmation();
        if (!documentId) return;
        this.isActionPending = true;
        try {
            await handleFileOperation({
                operation: 'delete',
                base64Data: null,
                fileName: null,
                caseId: null,
                contentDocumentId: documentId
            });
            this.showToast('File deleted successfully', 'success');
            this.caseFiles = this.caseFiles.filter((file) => file.id !== documentId);
            await refreshApex(this._wiredCasesResult);
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    uploadPendingFile(caseId) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64Data = reader.result.split(',')[1];
                handleFileOperation({
                    operation: 'upload',
                    base64Data,
                    fileName: this.uploadedFile.name,
                    caseId,
                    contentDocumentId: null
                })
                    .then(resolve)
                    .catch(reject);
            };
            reader.onerror = reject;
            reader.readAsDataURL(this.uploadedFile);
        });
    }

    // ---- Submit (upload completes BEFORE the success toast) ----

    async handleSubmitCase() {
        if (!this.validateForm()) return;
        this.isActionPending = true;
        try {
            const caseRecord = {
                Id: this.caseDraft.Id || undefined,
                Subject: this.caseDraft.Subject,
                Description: this.caseDraft.Description,
                CaseCategory__c: this.caseDraft.CaseCategory__c
            };
            const resultCase = await upsertCase({ caseRecord, isUpdate: this.isEditMode });
            if (this.uploadedFile && resultCase && resultCase.Id) {
                await this.uploadPendingFile(resultCase.Id);
            }
            this.showToast(this.isEditMode ? 'Case updated successfully' : 'Case created successfully', 'success');
            this.closeModal();
            await refreshApex(this._wiredCasesResult);
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    // ---- Export (date-range contract; ignores client search/status) ----

    async handleExport() {
        this.isActionPending = true;
        try {
            const csvData = await getCasesCSVData({
                startDateFilter: this.serverStartDate,
                endDateFilter: this.serverEndDate
            });
            if (!csvData) {
                this.showToast('No cases available to export', 'info');
                return;
            }
            const link = document.createElement('a');
            link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvData);
            link.download = `cases_export_${new Date().toISOString().slice(0, 10)}.csv`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

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