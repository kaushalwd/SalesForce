/**********************************************************************************************************************
* Name               : mBPManageBrokerCases
* Description        : This class is used as the Lwc for Broker Portal case Submission.
* Usage              : LWC components for creating and managing Broker cases
* Created By         : Raghu sharma
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date                      Comment
* 1.0         Raghu.chilukuri@activemindsit.com      10 Aug 2025      case creation,updating from the portal.
* 1.1         Raghu.chilukuri@activemindsit.com      15 dec 2025       Mobile view Enhancements Using seperate html
**********************************************************************************************************************/

import { LightningElement, track, wire } from 'lwc';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import { refreshApex } from '@salesforce/apex';
import getCases from '@salesforce/apex/MBP_ManageBrokerCases.getCases';
import upsertCase from '@salesforce/apex/MBP_ManageBrokerCases.upsertCase';
import getCaseSubcategories from '@salesforce/apex/MBP_ManageBrokerCases.getCasecategories';
import getCasesCSVData from '@salesforce/apex/MBP_ManageBrokerCases.getCasesCSVData';
import handleFileOperation from '@salesforce/apex/MBP_ManageBrokerCases.handleFileOperation';

const today = new Date();
const yyyy = today.getFullYear();
const mm = String(today.getMonth() + 1).padStart(2, '0');
const dd = String(today.getDate()).padStart(2, '0');
const todayStr = `${yyyy}-${mm}-${dd}`;
const startOfYearStr = `${yyyy}-01-01`;

export default class MbpCaseManagement extends LightningElement {
    filterIcon = FilterIcon;
    @track isLoading = false;
    @track showCreateCaseModal = false;
    @track cases = [];
    @track casesWireResult;
    @track errors = {};
    @track isEditMode = false;
    @track filteredCases = [];
    @track searchKey = '';
    @track statusFilter = '';
    @track subcategoryOptions = [];
    @track caseFiles = [];
    @track uploadedFile;
    @track newCase = { Id: null, Subject: '', Description: '', CaseSubCategory__c: '' };
    @track isMobile = false;

    // Floating Filter State
    @track showFilterBox = false;
    @track filters = {
        searchKey: '',
        status: '',
        startDate: startOfYearStr,
        endDate: todayStr
    };
    

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }
    toggleFilterBox() {
        this.showFilterBox = !this.showFilterBox;
    }
    resetFilters() {
        this.filters = {
            searchKey: '',
            status: '',
            startDate: startOfYearStr,
            endDate: todayStr
        };
        // Refresh data when resetting filters
        this.refreshCaseData();
    }

    // Picklist Values
    statusOptions = [
        { label: 'All', value: '' },
        { label: 'New', value: 'New' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Closed', value: 'Closed' }
    ];
    closedStatusValues = [
        'Closed with Resolution',
        'Closed without Resolution',
        'Closed with Service Request',
        'Closed as Duplicate'
    ];

    get caseColumns() {
        return [
            { label: 'S.No', fieldName: 'sno', type: 'number', sortable: true, initialWidth: 60 },
            { label: 'Case Number', fieldName: 'CaseNumber', type: 'text', sortable: true, initialWidth: 120 },
            { label: 'Status', fieldName: 'Status', type: 'text', sortable: true, initialWidth: 120 },
            { label: 'Subject', fieldName: 'Subject', type: 'text', sortable: true },
            { label: 'Description', fieldName: 'Description', type: 'text', sortable: true },
            { label: 'Category', fieldName: 'CaseSubCategory__c', type: 'text', sortable: true, initialWidth: 150 },
            { label: 'Resolution Comments', fieldName: 'Resolution_Comments__c', type: 'text', sortable: true, initialWidth: 200 },
            { label: 'Raised By', fieldName: 'raisedBy', type: 'text', sortable: true, initialWidth: 150 },
            {
                type: 'button-icon',
                initialWidth: 42,
                typeAttributes: {
                    iconName: 'utility:edit',
                    title: 'Edit',
                    name: 'edit',
                    variant: 'bare',
                    alternativeText: 'Edit',
                    class: { fieldName: 'editIconClass' }
                }
            }
        ];
    }

    connectedCallback() {
        this.loadSubcategories();
        this.detectMobile();
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Case' : 'New Case';
    }

    // Wire method with date filters
    @wire(getCases, {
        caseExport: false,
        startDateFilter: '$filters.startDate',
        endDateFilter: '$filters.endDate'
    })
    wiredCases(result) {
        this.casesWireResult = result;
        const { data, error } = result;

        // Show spinner when loading
        if (result.loading) {
            this.isLoading = true;
            return;
        }

        // Hide spinner when done
        this.isLoading = false;

        if (data) {
            this.cases = data.map((row, index) => ({
                ...row,
                raisedBy: row.CreatedBy?.Name || '',
                CaseSubCategory__c: row.CaseSubCategory__c || 'Not specified',
                Resolution_Comments__c: row.Resolution_Comments__c || '',
                editIconClass: row.Status !== 'New' ? 'slds-hidden' : '',
                isEditIconEmpty: row.Status === 'New', 
                files: row.ContentDocumentLinks ?
                    row.ContentDocumentLinks.map(link => ({
                        id: link.ContentDocumentId,
                        title: link.ContentDocument.Title,
                        extension: link.ContentDocument.FileExtension
                    })) : [],
                sno: index + 1,
                //isCollapsed: true,
               // bodyClass: 'case-card-body collapsed'  // <-- Add S.No here
            }));
            this.applyLocalFilters();
        } else if (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        }
    }

    loadSubcategories() {
        // Show spinner when loading subcategories
        this.isLoading = true;
        getCaseSubcategories()
            .then(result => {
                this.subcategoryOptions = result.map(item => ({
                    label: item,
                    value: item
                }));
            })
            .catch(error => {
                this.showToast(this.getErrorMsg(error), 'error');
            })
            .finally(() => {
                // Hide spinner when done
                this.isLoading = false;
            });
    }

    // Floating filter handlers
    handleFilterChange(event) {
        const field = event.target.dataset.id;
        this.filters[field] = event.target.value;
    }

    applyFilters() {
        // For date filters, the wire method will automatically refresh
        // We just need to apply local filters (search and status)
        this.applyLocalFilters();
        this.showFilterBox = false;
    }

    applyLocalFilters() {
        this.filteredCases = this.cases.filter(caseRec => {
            const search = this.filters.searchKey?.toLowerCase() || '';

            // Search filter
            const matchesSearch =
                !search ||
                (caseRec.CaseNumber && caseRec.CaseNumber.toLowerCase().includes(search)) ||
                (caseRec.Subject && caseRec.Subject.toLowerCase().includes(search)) ||
                (caseRec.CaseSubCategory__c && caseRec.CaseSubCategory__c.toLowerCase().includes(search)) ||
                (caseRec.raisedBy && caseRec.raisedBy.toLowerCase().includes(search));

            // Status filter
            let matchesStatus = true;
            if (this.filters.status === 'Closed') {
                matchesStatus = this.closedStatusValues.includes(caseRec.Status);
            } else if (this.filters.status) {
                matchesStatus = caseRec.Status === this.filters.status;
            }

            return matchesSearch && matchesStatus;
        });
    }

    openCreateCaseModal() {
        this.errors = {};
        this.isEditMode = false;
        this.resetNewCase();
        this.uploadedFile = null;
        this.caseFiles = [];
        this.showCreateCaseModal = true;
    }

    closeCreateCaseModal() {
        this.showCreateCaseModal = false;
        this.errors = {};
        this.resetNewCase();
        this.uploadedFile = null;
        this.caseFiles = [];
    }

    resetNewCase() {
        this.newCase = { Id: null, Subject: '', Description: '', CaseSubCategory__c: '' };
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.isEditMode = true;
            this.newCase = {
                Id: row.Id,
                Subject: row.Subject,
                Description: row.Description,
                CaseSubCategory__c: row.CaseSubCategory__c
            };
            this.caseFiles = row.files || [];
            this.showCreateCaseModal = true;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        this.newCase = { ...this.newCase, [field]: event.target.value };
        if (this.errors[field]) {
            this.errors[field] = undefined;
        }
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        if (file) {
            const validTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
            if (validTypes.includes(file.type)) {
                this.uploadedFile = file;
            } else {
                this.showToast('Please upload PDF, JPG, or PNG files only', 'error');
                event.target.value = '';
            }
        }
    }

    previewFile() {
        if (this.uploadedFile) {
            const fileUrl = URL.createObjectURL(this.uploadedFile);
            window.open(fileUrl, '_blank');
        }
    }

    handleDeleteFile() {
        this.uploadedFile = null;
    }

    validateForm() {
        let isValid = true;
        this.errors = {};
        if (!this.newCase.Subject?.trim()) {
            this.errors.Subject = 'Subject is required';
            isValid = false;
        }
        if (!this.newCase.Description?.trim()) {
            this.errors.Description = 'Description is required';
            isValid = false;
        }
        if (!this.newCase.CaseSubCategory__c?.trim()) {
            this.errors.CaseSubCategory__c = 'Please select category';
            isValid = false;
        }
        return isValid;
    }

    async refreshCaseData() {
        try {
            // Show spinner when refreshing data
            this.isLoading = true;
            await refreshApex(this.casesWireResult);
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            // Hide spinner when done (handled in wiredCases)
        }
    }

    async submitCase() {
        if (!this.validateForm()) return;
        this.isLoading = true;
        try {
            const resultCase = await upsertCase({
                caseRecord: this.newCase,
                isUpdate: this.isEditMode
            });
            const message = this.isEditMode ? 'Case updated successfully' : 'Case created successfully';
            this.showToast(message, 'success');
            if (this.uploadedFile) {
                await this.uploadFile(resultCase.Id);
            }
            if (!this.isEditMode) {
                this.resetNewCase();
            }
            await this.refreshCaseData();
            this.closeCreateCaseModal();
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async uploadFile(caseId) {
        const reader = new FileReader();
        return new Promise((resolve, reject) => {
            reader.onload = async () => {
                const base64 = reader.result.split(',')[1];
                try {
                    await handleFileOperation({
                        operation: 'upload',
                        base64Data: base64,
                        fileName: this.uploadedFile.name,
                        caseId: caseId,
                        contentDocumentId: null
                    });
                    resolve();
                } catch (error) {
                    this.showToast(this.getErrorMsg(error), 'error');
                    reject(error);
                }
            };
            reader.readAsDataURL(this.uploadedFile);
        });
    }

    async handlePreviewExistingFile(event) {
        const fileId = event.currentTarget.dataset.id;
        try {
            const fileData = await handleFileOperation({
                operation: 'download',
                base64Data: null,
                fileName: null,
                caseId: null,
                contentDocumentId: fileId
            });
            const byteCharacters = atob(fileData.base64Data);
            const byteNumbers = new Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
            }
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: fileData.fileType });
            const blobUrl = URL.createObjectURL(blob);
            window.open(blobUrl, '_blank');
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        }
    }

    async handleDeleteExistingFile(event) {
        const fileId = event.currentTarget.dataset.id;
        if (confirm('Are you sure you want to delete this file?')) {
            try {
                await handleFileOperation({
                    operation: 'delete',
                    base64Data: null,
                    fileName: null,
                    caseId: null,
                    contentDocumentId: fileId
                });
                this.showToast('File deleted successfully', 'success');
                this.caseFiles = this.caseFiles.filter(file => file.id !== fileId);
                await this.refreshCaseData();
            } catch (error) {
                this.showToast(this.getErrorMsg(error), 'error');
            }
        }
    }

    async handleExport() {
        try {
            // Show spinner during export
            this.isLoading = true;
            const csvData = await getCasesCSVData({
                startDateFilter: this.filters.startDate,
                endDateFilter: this.filters.endDate
            });
            if (!csvData) {
                this.showToast('No cases available to export', 'info');
                return;
            }
            const hiddenElement = document.createElement('a');
            hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvData);
            hiddenElement.target = '_self';
            hiddenElement.download = 'cases_export_' + new Date().toISOString().slice(0, 10) + '.csv';
            document.body.appendChild(hiddenElement);
            hiddenElement.click();
            document.body.removeChild(hiddenElement);
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            // Hide spinner when export is complete
            this.isLoading = false;
        }
    }

    showToast(message, variant) {
        const toastElement = this.template.querySelector('c-mbp_customshowtoast');
        if (toastElement) {
            toastElement.show(message, variant);
        }
    }

    getErrorMsg(error) {
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        if (typeof error === 'string') return error;
        return 'An unexpected error occurred';
    }

    //New
        renderedCallback() {
        if (!this._outsideClickHandlerAdded) {
            this._outsideClickHandler = this.handleOutsideClick.bind(this);
            document.addEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = true;
        }
    }

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-icon');

        const path = event.composedPath ? event.composedPath() : [];
        const clickedInside =
            (filterWrapper && path.includes(filterWrapper)) ||
            (filterIcon && path.includes(filterIcon));

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

closeModal() {
    this.isEditModalOpen = false;
    this.isCreateModalOpen = false;
}

    
    // Mobile detection methods
    detectMobile() {
        this.isMobile = window.innerWidth <= 768;
    }

    handleResize() {
        this.detectMobile();
    }

    // Handle card edit in mobile view
    handleCardEdit(event) {
        const caseId = event.currentTarget.dataset.id;
        const caseRecord = this.cases.find(caseRec => caseRec.Id === caseId);
        
        if (caseRecord) {
            this.isEditMode = true;
            this.newCase = {
                Id: caseRecord.Id,
                Subject: caseRecord.Subject,
                Description: caseRecord.Description,
                CaseSubCategory__c: caseRecord.CaseSubCategory__c
            };
            this.caseFiles = caseRecord.files || [];
            this.showCreateCaseModal = true;
        }
    }

    get isEditIconEmpty() {
    return this.case.editIconClass === '';
}
get noFilteredCases() {
    return this.filteredCases && this.filteredCases.length === 0;
}


/*toggleCardCollapse(event) {
    const cardId = event.currentTarget.dataset.id;
    this.filteredCases = this.filteredCases.map(card => {
        if (card.Id === cardId) {
            const isCollapsed = !card.isCollapsed;
            return { ...card, isCollapsed, bodyClass: `case-card-body ${isCollapsed ? 'collapsed' : ''}` };
        }
        return card;
    });
}*/


/*getCaseBodyClass(caseItem) {
    return caseItem.isCollapsed ? 'case-card-body collapsed' : 'case-card-body';
}*/


}