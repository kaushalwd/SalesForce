import { LightningElement, track, wire } from 'lwc';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import { refreshApex } from '@salesforce/apex';
import getRequests from '@salesforce/apex/mbpBrokerRequestController.getRequests';
import getPicklistValues from '@salesforce/apex/mbpBrokerRequestController.getPicklistValues';
import createRequest from '@salesforce/apex/mbpBrokerRequestController.createRequest';
import updateRequest from '@salesforce/apex/mbpBrokerRequestController.updateRequest';
import getRequestsCSVData from '@salesforce/apex/mbpBrokerRequestController.getRequestsCSVData';

const today = new Date();
const yyyy = today.getFullYear();
const mm = String(today.getMonth() + 1).padStart(2, '0');
const dd = String(today.getDate()).padStart(2, '0');
const todayStr = `${yyyy}-${mm}-${dd}`;
const startOfYearStr = `${yyyy}-01-01`;

export default class MbpBrokerRequests extends LightningElement {
    filterIcon = FilterIcon;

    @track isLoading = false;
    @track showCreateRequestModal = false;
    @track requests = [];
    @track requestsWireResult;
    @track errors = {};
    @track filteredRequests = [];
    @track typeOptions = [];
    @track priorityOptions = [];
    @track statusOptions = [];
    @track dependentSubTypes = {};
    @track requestFiles = [];
    @track uploadedFile;
    @track isEditMode = false;
    @track deletedExistingFileIds = [];
    @track newRequest = {
        Id: null,
        Request_Type__c: '',
        Request_SubType__c: '',
        Description__c: '',
        Priority__c: ''
    };
    @track isMobile = false;
    @track showFilterBox = false;
    @track filters = {
        searchKey: '',
        status: '',
        type: '',
        subType: '',
        startDate: startOfYearStr,
        endDate: todayStr
    };

    resizeHandler;

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    get filteredSubTypeOptions() {
        const selectedType = this.filters.type;
        if (selectedType && this.dependentSubTypes[selectedType]) {
            return [{ label: 'All', value: '' }, ...this.dependentSubTypes[selectedType]];
        }
        return [{ label: 'All', value: '' }];
    }

    get requestSubTypeOptions() {
        const selectedType = this.newRequest.Request_Type__c;
        if (selectedType && this.dependentSubTypes[selectedType]) {
            return [{ label: 'Select Sub Type', value: '' }, ...this.dependentSubTypes[selectedType]];
        }
        return [{ label: 'Select Sub Type', value: '' }];
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Request' : 'New Request';
    }

    get submitButtonLabel() {
        return this.isEditMode ? 'Update' : 'Submit';
    }

    get requestColumns() {
        return [
            { label: 'S.No', fieldName: 'sno', type: 'number', sortable: true, initialWidth: 60 },
            { label: 'Request Number', fieldName: 'Name', type: 'text', sortable: true, initialWidth: 140 },
            { label: 'Type', fieldName: 'Request_Type__c', type: 'text', sortable: true, initialWidth: 120 },
            { label: 'Sub Type', fieldName: 'Request_SubType__c', type: 'text', sortable: true, initialWidth: 120 },
            { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true, initialWidth: 120 },
            {
                label: 'Priority',
                fieldName: 'Priority__c',
                type: 'text',
                sortable: true,
                initialWidth: 100,
                cellAttributes: {
                    class: { fieldName: 'priorityClass' }
                }
            },
            { label: 'Description', fieldName: 'Description__c', type: 'text', sortable: true },
            { label: 'Created Date', fieldName: 'formattedCreatedDate', type: 'text', sortable: true, initialWidth: 120 },
            { label: 'Created By', fieldName: 'createdBy', type: 'text', sortable: true, initialWidth: 150 },
            {
                type: 'button-icon',
                fixedWidth: 70,
                typeAttributes: {
                    iconName: 'utility:edit',
                    name: 'edit',
                    title: 'Edit',
                    alternativeText: 'Edit',
                    variant: 'bare',
                    disabled: { fieldName: 'disableEdit' }
                }
            }
        ];
    }

    get noFilteredRequests() {
        return this.filteredRequests && this.filteredRequests.length === 0;
    }

    get isSubTypeDisabled() {
        return !this.newRequest.Request_Type__c;
    }

    connectedCallback() {
        this.loadPicklistValues();
        this.detectMobile();
        this.resizeHandler = this.handleResize.bind(this);
        window.addEventListener('resize', this.resizeHandler);
    }

    disconnectedCallback() {
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

    renderedCallback() {
        if (!this._outsideClickHandlerAdded) {
            this._outsideClickHandler = this.handleOutsideClick.bind(this);
            document.addEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = true;
        }
    }

    async loadPicklistValues() {
        this.isLoading = true;
        try {
            const [types, priorities, statuses, subtypes] = await Promise.all([
                getPicklistValues({ picklistType: 'requestTypes' }),
                getPicklistValues({ picklistType: 'priorityOptions' }),
                getPicklistValues({ picklistType: 'statusOptions' }),
                getPicklistValues({ picklistType: 'dependentSubTypes' })
            ]);

            this.typeOptions = [{ label: 'Select Type', value: '' }, ...types];
            this.priorityOptions = [{ label: 'Select Priority', value: '' }, ...priorities];
            this.statusOptions = [{ label: 'All', value: '' }, ...statuses];
            this.dependentSubTypes = subtypes || {};
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    @wire(getRequests, { params: '$filters' })
    wiredRequests(result) {
        this.requestsWireResult = result;
        const { data, error } = result;

        if (data) {
            this.requests = data.map((row, index) => {
                const files = row.ContentDocumentLinks
                    ? row.ContentDocumentLinks.map(l => ({
                          id: l.ContentDocumentId,
                          title: l.ContentDocument.Title,
                          extension: l.ContentDocument.FileExtension
                      }))
                    : [];

                return {
                    ...row,
                    sno: index + 1,
                    createdBy: row.CreatedBy ? row.CreatedBy.Name : '',
                    formattedCreatedDate: row.CreatedDate ? this.formattedDate(row.CreatedDate) : '',
                    priorityClass: row.Priority__c ? 'request-priority ' + row.Priority__c.toLowerCase() : '',
                    files: files,
                    isDraft: row.Status__c === 'Draft',
                    disableEdit: row.Status__c !== 'Draft',
                    StatusClass: this.getStatusClass(row.Status__c)
                };
            });

            this.applyLocalFilters();
        } else if (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        }
    }

    detectMobile() {
        this.isMobile = window.innerWidth <= 768;
    }

    handleResize() {
        this.detectMobile();
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    handleFilterChange(event) {
        const field = event.target.dataset.id;
        const value = event.target.value;

        if (field === 'type') {
            this.filters = {
                ...this.filters,
                type: value,
                subType: ''
            };
        } else {
            this.filters = {
                ...this.filters,
                [field]: value
            };
        }
    }

    applyFilters() {
        this.applyLocalFilters();
        this.showFilterBox = false;
    }

    resetFilters() {
        this.filters = {
            searchKey: '',
            status: '',
            type: '',
            subType: '',
            startDate: startOfYearStr,
            endDate: todayStr
        };
        this.refreshRequestData();
    }

    applyLocalFilters() {
        this.filteredRequests = this.requests.filter(request => {
            const search = (this.filters.searchKey || '').toLowerCase();

            const matchesSearch =
                !search ||
                (request.Name && request.Name.toLowerCase().includes(search)) ||
                (request.Request_Type__c && request.Request_Type__c.toLowerCase().includes(search)) ||
                (request.Request_SubType__c && request.Request_SubType__c.toLowerCase().includes(search)) ||
                (request.Status__c && request.Status__c.toLowerCase().includes(search));

            const matchesStatus = !this.filters.status || request.Status__c === this.filters.status;
            const matchesType = !this.filters.type || request.Request_Type__c === this.filters.type;
            const matchesSubType = !this.filters.subType || request.Request_SubType__c === this.filters.subType;

            return matchesSearch && matchesStatus && matchesType && matchesSubType;
        });
    }

    async refreshRequestData() {
        try {
            this.isLoading = true;
            await refreshApex(this.requestsWireResult);
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    openCreateRequestModal() {
        this.errors = {};
        this.isEditMode = false;
        this.deletedExistingFileIds = [];
        this.newRequest = {
            Id: null,
            Request_Type__c: '',
            Request_SubType__c: '',
            Description__c: '',
            Priority__c: ''
        };
        this.uploadedFile = null;
        this.requestFiles = [];
        this.showCreateRequestModal = true;
    }

    closeCreateRequestModal() {
        this.showCreateRequestModal = false;
        this.errors = {};
        this.isEditMode = false;
        this.deletedExistingFileIds = [];
        this.newRequest = {
            Id: null,
            Request_Type__c: '',
            Request_SubType__c: '',
            Description__c: '',
            Priority__c: ''
        };
        this.uploadedFile = null;
        this.requestFiles = [];
    }

    handleEditClick(event) {
        const requestId = event.currentTarget.dataset.id;
        this.openEditRequestModal(requestId);
    }

    handleRowAction(event) {
        const actionName = event.detail && event.detail.action ? event.detail.action.name : null;
        const row = event.detail ? event.detail.row : null;

        if (actionName === 'edit' && row && row.Status__c === 'Draft') {
            this.openEditRequestModal(row.Id);
        }
    }

    openEditRequestModal(requestId) {
        const selectedRequest = this.requests.find(req => req.Id === requestId);

        if (!selectedRequest) {
            this.showToast('Request record not found', 'error');
            return;
        }

        if (selectedRequest.Status__c !== 'Draft') {
            this.showToast('Only Draft requests can be edited', 'error');
            return;
        }

        this.errors = {};
        this.isEditMode = true;
        this.deletedExistingFileIds = [];
        this.newRequest = {
            Id: selectedRequest.Id,
            Request_Type__c: selectedRequest.Request_Type__c || '',
            Request_SubType__c: selectedRequest.Request_SubType__c || '',
            Description__c: selectedRequest.Description__c || '',
            Priority__c: selectedRequest.Priority__c || ''
        };
        this.requestFiles = selectedRequest.files ? [...selectedRequest.files] : [];
        this.uploadedFile = null;
        this.showCreateRequestModal = true;
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.value;

        if (field === 'Request_Type__c') {
            this.newRequest = {
                ...this.newRequest,
                Request_Type__c: value,
                Request_SubType__c: ''
            };
        } else {
            this.newRequest = {
                ...this.newRequest,
                [field]: value
            };
        }

        if (this.errors[field]) {
            this.errors = {
                ...this.errors,
                [field]: undefined
            };
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
        const fileInput = this.template.querySelector('lightning-input[type="file"]');
        if (fileInput) {
            fileInput.value = null;
        }
    }

    handlePreviewExistingFile(event) {
        const docId = event.currentTarget.dataset.id;
        if (docId) {
            window.open(`/sfc/servlet.shepherd/document/download/${docId}`, '_blank');
        }
    }

    handleDeleteExistingFile(event) {
        const docId = event.currentTarget.dataset.id;
        if (!docId) {
            return;
        }

        if (!this.deletedExistingFileIds.includes(docId)) {
            this.deletedExistingFileIds = [...this.deletedExistingFileIds, docId];
        }

        this.requestFiles = this.requestFiles.filter(file => file.id !== docId);
    }

    validateForm() {
        let isValid = true;
        this.errors = {};

        if (!this.newRequest.Request_Type__c) {
            this.errors.Request_Type__c = 'Type is required';
            isValid = false;
        }
        if (!this.newRequest.Request_SubType__c) {
            this.errors.Request_SubType__c = 'Sub Type is required';
            isValid = false;
        }
        if (!this.newRequest.Description__c) {
            this.errors.Description__c = 'Description is required';
            isValid = false;
        }
        if (!this.newRequest.Priority__c) {
            this.errors.Priority__c = 'Priority is required';
            isValid = false;
        }

        return isValid;
    }

    async submitRequest() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        try {
            let fileData;
            let fileName;

            if (this.uploadedFile) {
                fileName = this.uploadedFile.name;
                fileData = await new Promise(resolve => {
                    const reader = new FileReader();
                    reader.onload = () => resolve(reader.result.split(',')[1]);
                    reader.readAsDataURL(this.uploadedFile);
                });
            }

            if (this.isEditMode) {
                await updateRequest({
                    requestData: this.newRequest,
                    fileData: fileData,
                    fileName: fileName,
                    deleteFileIds: this.deletedExistingFileIds
                });

                this.showToast('Request updated successfully', 'success');
            } else {
                await createRequest({
                    requestData: this.newRequest,
                    fileData: fileData,
                    fileName: fileName
                });

                this.showToast('Request created successfully', 'success');
            }

            await refreshApex(this.requestsWireResult);
            this.closeCreateRequestModal();
        } catch (error) {
            this.showToast(this.getErrorMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-icon');
        const path = event.composedPath ? event.composedPath() : [];

        let clickedInside = false;

        if (filterWrapper && path.includes(filterWrapper)) {
            clickedInside = true;
        }
        if (filterIcon && path.includes(filterIcon)) {
            clickedInside = true;
        }

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    showToast(message, variant) {
        const toastElement = this.template.querySelector('c-mbp_customshowtoast');
        if (toastElement) {
            toastElement.show(message, variant);
        }
    }

    getErrorMsg(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        return 'An unexpected error occurred';
    }

    formattedDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    getStatusClass(status) {
        if (!status) {
            return 'case-status';
        }

        const normalized = status.toLowerCase().replace(/\s+/g, '-');
        return `case-status ${normalized}`;
    }

async handleExport() {
    try {
        this.isLoading = true;

        const csvData = await getRequestsCSVData({
            startDateFilter: this.filters.startDate,
            endDateFilter: this.filters.endDate
        });

        if (!csvData) {
            this.showToast('No requests available to export', 'info');
            return;
        }

        const hiddenElement = document.createElement('a');
        hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvData);
        hiddenElement.target = '_self';
        hiddenElement.download = 'broker_requests_export_' + new Date().toISOString().slice(0, 10) + '.csv';
        document.body.appendChild(hiddenElement);
        hiddenElement.click();
        document.body.removeChild(hiddenElement);

    } catch (error) {
        this.showToast(this.getErrorMsg(error), 'error');
    } finally {
        this.isLoading = false;
    }
}
}