import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getEligibleProjects from '@salesforce/apex/EOIRefundController.getEligibleProjects';
import getEligibleEOIs from '@salesforce/apex/EOIRefundController.getEligibleEOIs';
import submitRefundRequest from '@salesforce/apex/EOIRefundController.submitRefundRequest';
import USER_ID from '@salesforce/user/Id';
import EOI_FIELDS_LABEL from '@salesforce/label/c.EOI_Refund_EOI_Fields';
import RECEIPT_FIELDS_LABEL from '@salesforce/label/c.EOI_Refund_Receipt_Fields';

// Master Field Definitions for EOI List View (Configured via Custom Label EOI_Refund_EOI_Fields)
const ALL_EOI_FIELDS = [
    {
        key: 'account',
        matchTokens: ['account', 'account__c', 'account__r.name', 'account name', 'accountname'],
        label: 'Account',
        getValue: (eoi) => eoi.accountName,
        valueClass: 'meta-value font-weight-semibold'
    },
    {
        key: 'opportunity',
        matchTokens: ['opportunity', 'opportunity__c', 'opportunity__r.name', 'opportunity name', 'opportunityname'],
        label: 'Opportunity',
        getValue: (eoi) => eoi.opportunityName,
        valueClass: 'meta-value'
    },
    {
        key: 'status',
        matchTokens: ['status', 'status__c'],
        label: 'Status',
        getValue: (eoi) => eoi.status,
        valueClass: 'meta-value'
    },
    {
        key: 'project',
        matchTokens: ['project', 'project__c', 'project__r.name', 'project name', 'projectname'],
        label: 'Project',
        getValue: (eoi) => eoi.projectName,
        valueClass: 'meta-value'
    }
];

// Master Field Definitions for Receipt Tables (Configured via Custom Label EOI_Refund_Receipt_Fields)
const ALL_RECEIPT_COLUMNS = [
    {
        key: 'name',
        matchTokens: ['name', 'receipt no', 'receipt number', 'receipt_no', 'receipt_number'],
        label: 'Receipt No',
        getValue: (rec) => rec.receiptNumber,
        cellClass: 'font-weight-bold',
        isBadge: false
    },
    {
        key: 'totalamount__c',
        matchTokens: ['totalamount__c', 'total amount', 'total_amount', 'amount', 'receipt amount', 'totalamount'],
        label: 'Total Amount',
        getValue: (rec) => rec.formattedAmount,
        cellClass: 'font-weight-semibold text-success',
        isBadge: false
    },
    {
        key: 'status__c',
        matchTokens: ['status__c', 'status', 'receipt status'],
        label: 'Status',
        getValue: (rec) => rec.status,
        cellClass: '',
        isBadge: true,
        badgeClass: 'slds-badge slds-theme_success'
    },
    {
        key: 'salesorder__c',
        matchTokens: ['salesorder__c', 'sales order', 'sales_order', 'sales order no', 'sales order number', 'salesordernumber'],
        label: 'Sales Order',
        getValue: (rec) => rec.salesOrderNumber,
        cellClass: '',
        isBadge: false
    },
    {
        key: 'salesorder__r.status__c',
        matchTokens: ['salesorder__r.status__c', 'sales order status', 'sales_order_status', 'salesorderstatus', 'so status'],
        label: 'Sales Order Status',
        getValue: (rec) => rec.salesOrderStatus,
        cellClass: '',
        isBadge: true,
        badgeClass: 'slds-badge slds-theme_warning'
    },
    {
        key: 'account__c',
        matchTokens: ['account__c', 'receipt account', 'account', 'account__r.name', 'account name'],
        label: 'Receipt Account',
        getValue: (rec) => rec.accountName,
        cellClass: '',
        isBadge: false
    }
];

export default class EoiRefund extends LightningElement {
    @track projectOptions = [];
    @track eoiList = [];
    selectedProjectId = null;

    // Pagination & Page Size Controls
    @track pageSize = 10;
    @track pageSizeStr = '10';
    @track isCustomPageSize = false;
    @track customPageSize = 10;
    @track currentPage = 1;

    pageSizeOptions = [
        { label: '5', value: '5' },
        { label: '10', value: '10' },
        { label: '15', value: '15' },
        { label: '20', value: '20' },
        { label: '50', value: '50' },
        { label: '100', value: '100' },
        { label: 'Custom...', value: 'custom' }
    ];

    // Step Navigation (1 = Project, 2 = EOIs, 3 = Document Upload)
    @track currentStep = 2;

    // Management MEMO Document Upload
    @track uploadedMemoFile = null;
    acceptedFormats = '.pdf,.doc,.docx,.png,.jpg,.jpeg';
    currentUserId = USER_ID;

    // Selection Tracking
    @track selectedEoiIds = [];
    @track selectedReceiptIds = [];

    // Submission & State
    isLoading = false;
    isCaseCreated = false;
    createdBusinessProcessId = null;
    @track createdBusinessProcessName = '';
    errorMessage = null;
    submittedCasesCount = 0;
    submittedReceiptsCount = 0;
    submittedTotalAmount = 0;

    wiredProjectsResult;

    @wire(getEligibleProjects)
    wiredProjects(result) {
        this.wiredProjectsResult = result;
        const { data, error } = result;
        if (data) {
            this.projectOptions = data.map(item => ({
                label: item.label,
                value: item.value
            }));
            this.errorMessage = null;
        } else if (error) {
            this.errorMessage = this.extractErrorMessage(error);
            this.projectOptions = [];
        }
    }

    // Dynamic Field Definitions from Custom Labels
    get activeEoiFieldDefs() {
        const raw = EOI_FIELDS_LABEL || 'Account__c, Opportunity__c';
        const tokens = raw.split(',').map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
        const matched = ALL_EOI_FIELDS.filter(fDef =>
            tokens.some(t => fDef.matchTokens.includes(t))
        );
        return matched.length > 0 ? matched : ALL_EOI_FIELDS.slice(0, 2);
    }

    get activeReceiptColumnDefs() {
        const raw = RECEIPT_FIELDS_LABEL || 'Name, TotalAmount__c, Status__c, SalesOrder__c, SalesOrder__r.Status__c, Account__c';
        const tokens = raw.split(',').map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
        const matched = ALL_RECEIPT_COLUMNS.filter(cDef =>
            tokens.some(t => cDef.matchTokens.includes(t))
        );
        return matched.length > 0 ? matched : ALL_RECEIPT_COLUMNS;
    }

    get displayedReceiptColumns() {
        return this.activeReceiptColumnDefs.map(c => ({
            key: c.key,
            label: c.label
        }));
    }

    // Computed Getters
    get hasProjectOptions() {
        return this.projectOptions && this.projectOptions.length > 0;
    }

    get isProjectSelected() {
        return !!this.selectedProjectId;
    }

    get hasEOIs() {
        return this.eoiList && this.eoiList.length > 0;
    }

    get totalEOIsCount() {
        return this.eoiList ? this.eoiList.length : 0;
    }

    get selectedEoisCount() {
        return this.selectedEoiIds ? this.selectedEoiIds.length : 0;
    }

    get hasSelectedEOIs() {
        return this.selectedEoisCount > 0;
    }

    get selectedReceiptsCount() {
        return this.selectedReceiptIds ? this.selectedReceiptIds.length : 0;
    }

    get selectedTotalAmount() {
        let total = 0;
        this.eoiList.forEach(eoi => {
            if (eoi.isSelected) {
                total += (Number(eoi.totalEligibleAmount) || 0);
            }
        });
        return total;
    }

    get formattedSelectedTotalAmount() {
        return this.formatCurrency(this.selectedTotalAmount);
    }

    get formattedSubmittedAmount() {
        return this.formatCurrency(this.submittedTotalAmount);
    }

    get totalPages() {
        if (!this.eoiList || this.eoiList.length === 0) return 1;
        return Math.ceil(this.eoiList.length / this.pageSize);
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get isSelectAllPageChecked() {
        const pageItems = this.paginatedEOIs;
        if (!pageItems || pageItems.length === 0) return false;
        return pageItems.every(item => item.isSelected);
    }

    get paginatedEOIs() {
        if (!this.eoiList || this.eoiList.length === 0) return [];
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.eoiList.slice(start, end);
    }

    get isStep2() {
        return this.isProjectSelected && this.currentStep === 2;
    }

    get isStep3() {
        return this.isProjectSelected && this.currentStep === 3;
    }

    get step1Class() {
        return 'step-item active';
    }

    get step2Class() {
        let baseClass = 'step-item';
        if (this.isProjectSelected && this.currentStep >= 2) {
            baseClass += ' active';
        }
        return baseClass;
    }

    get step3Class() {
        let baseClass = 'step-item';
        if (this.currentStep === 3) {
            baseClass += ' active';
        }
        return baseClass;
    }

    get isProceedDisabled() {
        return this.selectedEoisCount === 0;
    }

    get isMemoUploaded() {
        return !!this.uploadedMemoFile;
    }

    get isSubmitDisabled() {
        return this.isLoading || this.selectedEoisCount === 0;
    }

    get submitButtonLabel() {
        if (this.selectedEoisCount > 1) {
            return `Submit for Approval (${this.selectedEoisCount} EOIs)`;
        }
        return 'Submit for Approval (1 EOI)';
    }

    get submitButtonTitle() {
        return 'Submit for Business Process approval';
    }

    get selectedProjectName() {
        const proj = this.projectOptions.find(p => p.value === this.selectedProjectId);
        return proj ? proj.label : '';
    }

    get selectedEOIsList() {
        return this.eoiList.filter(e => e.isSelected);
    }

    // Handlers
    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        this.eoiList = [];
        this.selectedEoiIds = [];
        this.selectedReceiptIds = [];
        this.currentPage = 1;
        this.currentStep = 2;
        this.uploadedMemoFile = null;
        this.errorMessage = null;

        if (this.selectedProjectId) {
            this.loadEOIs(this.selectedProjectId);
        }
    }

    async loadEOIs(projectId) {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const data = await getEligibleEOIs({ projectId });
            const activeEoiFields = this.activeEoiFieldDefs;
            const activeReceiptCols = this.activeReceiptColumnDefs;

            this.eoiList = (data || []).map((eoi) => {
                const formattedEligibleAmount = this.formatCurrency(eoi.totalEligibleAmount || 0);
                const hasEligible = eoi.eligibleReceipts && eoi.eligibleReceipts.length > 0;
                const hasUneligible = eoi.uneligibleReceipts && eoi.uneligibleReceipts.length > 0;

                // Dynamic EOI fields based on Custom Label
                const displayFields = activeEoiFields.map(fDef => ({
                    label: fDef.label,
                    value: fDef.getValue(eoi) || '-',
                    valueClass: fDef.valueClass
                }));

                // Dynamic Receipt columns based on Custom Label
                const eligibleReceipts = (eoi.eligibleReceipts || []).map(r => {
                    const formattedAmount = this.formatCurrency(r.totalAmount);
                    const recWithFormatted = { ...r, formattedAmount };
                    const cells = activeReceiptCols.map(cDef => ({
                        key: cDef.key,
                        value: cDef.getValue(recWithFormatted) || '-',
                        cellClass: cDef.cellClass,
                        isBadge: cDef.isBadge,
                        badgeClass: cDef.badgeClass
                    }));

                    return {
                        ...recWithFormatted,
                        cells
                    };
                });

                const uneligibleReceipts = (eoi.uneligibleReceipts || []).map(r => {
                    const formattedAmount = this.formatCurrency(r.totalAmount);
                    const recWithFormatted = { ...r, formattedAmount };
                    const cells = activeReceiptCols.map(cDef => ({
                        key: cDef.key,
                        value: cDef.getValue(recWithFormatted) || '-',
                        cellClass: '',
                        isBadge: cDef.isBadge
                    }));

                    return {
                        ...recWithFormatted,
                        cells
                    };
                });

                return {
                    ...eoi,
                    isExpanded: false,
                    isEligibleOpen: true,
                    isUneligibleOpen: false,
                    isSelected: false,
                    hasEligible,
                    hasUneligible,
                    formattedEligibleAmount,
                    displayFields,
                    eligibleReceipts,
                    uneligibleReceipts,
                    rowClass: 'eoi-accordion-item slds-m-bottom_x-small',
                    chevronIcon: 'utility:chevronright',
                    chevronTitle: 'Expand EOI',
                    eligibleChevronIcon: 'utility:chevrondown',
                    uneligibleChevronIcon: 'utility:chevronright'
                };
            });
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
            this.eoiList = [];
            this.showToast('Error Loading EOIs', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Accordion Toggles
    handleToggleEoi(event) {
        const eoiId = event.currentTarget.dataset.eoiId;
        const eoi = this.eoiList.find(item => item.id === eoiId);
        if (eoi) {
            eoi.isExpanded = !eoi.isExpanded;
            eoi.chevronIcon = eoi.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
            eoi.chevronTitle = eoi.isExpanded ? 'Collapse EOI' : 'Expand EOI';
            eoi.rowClass = eoi.isExpanded ? 'eoi-accordion-item expanded slds-m-bottom_x-small' : 'eoi-accordion-item slds-m-bottom_x-small';
        }
    }

    handleToggleEligible(event) {
        const eoiId = event.currentTarget.dataset.eoiId;
        const eoi = this.eoiList.find(item => item.id === eoiId);
        if (eoi) {
            eoi.isEligibleOpen = !eoi.isEligibleOpen;
            eoi.eligibleChevronIcon = eoi.isEligibleOpen ? 'utility:chevrondown' : 'utility:chevronright';
        }
    }

    handleToggleUneligible(event) {
        const eoiId = event.currentTarget.dataset.eoiId;
        const eoi = this.eoiList.find(item => item.id === eoiId);
        if (eoi) {
            eoi.isUneligibleOpen = !eoi.isUneligibleOpen;
            eoi.uneligibleChevronIcon = eoi.isUneligibleOpen ? 'utility:chevrondown' : 'utility:chevronright';
        }
    }

    handleExpandAll() {
        this.paginatedEOIs.forEach(eoi => {
            eoi.isExpanded = true;
            eoi.chevronIcon = 'utility:chevrondown';
            eoi.chevronTitle = 'Collapse EOI';
            eoi.rowClass = 'eoi-accordion-item expanded slds-m-bottom_x-small';
        });
    }

    handleCollapseAll() {
        this.paginatedEOIs.forEach(eoi => {
            eoi.isExpanded = false;
            eoi.chevronIcon = 'utility:chevronright';
            eoi.chevronTitle = 'Expand EOI';
            eoi.rowClass = 'eoi-accordion-item slds-m-bottom_x-small';
        });
    }

    // Checkbox Selections (EOI level - automatically includes all eligible receipts)
    handleEoiCheckboxChange(event) {
        const eoiId = event.target.dataset.eoiId;
        const isChecked = event.target.checked;
        const eoi = this.eoiList.find(item => item.id === eoiId);

        if (eoi) {
            eoi.isSelected = isChecked;
            if (isChecked && !eoi.isExpanded) {
                eoi.isExpanded = true;
                eoi.chevronIcon = 'utility:chevrondown';
                eoi.rowClass = 'eoi-accordion-item expanded slds-m-bottom_x-small';
            }
            this.recalculateSelections();
        }
    }

    handleSelectAllPage(event) {
        const isChecked = event.target.checked;
        this.paginatedEOIs.forEach(eoi => {
            eoi.isSelected = isChecked;
        });
        this.recalculateSelections();
    }

    recalculateSelections() {
        const eoiIds = [];
        const receiptIds = [];

        this.eoiList.forEach(eoi => {
            if (eoi.isSelected) {
                eoiIds.push(eoi.id);
                if (eoi.eligibleReceipts) {
                    eoi.eligibleReceipts.forEach(rec => {
                        receiptIds.push(rec.id);
                    });
                }
            }
        });

        this.selectedEoiIds = eoiIds;
        this.selectedReceiptIds = receiptIds;
    }

    // Pagination Controls
    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    // Page Size Controls (Highlighted Area in Toolbar)
    handlePageSizeChange(event) {
        const val = event.detail.value;
        this.pageSizeStr = val;
        if (val === 'custom') {
            this.isCustomPageSize = true;
        } else {
            this.isCustomPageSize = false;
            const parsed = parseInt(val, 10);
            if (parsed && parsed > 0) {
                this.pageSize = parsed;
                this.currentPage = 1;
            }
        }
    }

    handleCustomPageSizeChange(event) {
        const val = parseInt(event.target.value, 10);
        if (val && val > 0) {
            this.customPageSize = val;
            this.pageSize = val;
            this.currentPage = 1;
        }
    }

    // Step Navigation Handlers
    handleProceedToUpload() {
        if (this.selectedEoisCount === 0) {
            this.showToast('Validation Error', 'Please select at least one EOI before proceeding.', 'warning');
            return;
        }
        this.currentStep = 3;
    }

    handleBackToSelection() {
        this.currentStep = 2;
    }

    // Document Upload Handlers
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            const file = uploadedFiles[0];
            this.uploadedMemoFile = {
                name: file.name,
                documentId: file.documentId,
                contentVersionId: file.contentVersionId
            };
            this.showToast('Document Uploaded', `Management MEMO (${file.name}) uploaded successfully.`, 'success');
        }
    }

    handleRemoveUploadedFile() {
        this.uploadedMemoFile = null;
        this.showToast('Document Removed', 'Management MEMO removed.', 'info');
    }

    // Submission
    async handleSubmitRefund() {
        if (this.selectedEoiIds.length === 0) {
            this.showToast('Validation Error', 'Please select at least one EOI.', 'warning');
            return;
        }

        this.isLoading = true;
        this.errorMessage = null;

        const countEois = this.selectedEoiIds.length;
        const countReceipts = this.selectedReceiptIds.length;
        const totalAmount = this.selectedTotalAmount;

        try {
            const result = await submitRefundRequest({
                eoiIds: this.selectedEoiIds,
                selectedReceiptIds: this.selectedReceiptIds,
                contentDocumentId: this.uploadedMemoFile ? this.uploadedMemoFile.documentId : null
            });

            if (result && result.isSuccess) {
                this.submittedCasesCount = countEois;
                this.submittedReceiptsCount = countReceipts;
                this.submittedTotalAmount = totalAmount;
                this.createdBusinessProcessId = result.businessProcessId;
                this.createdBusinessProcessName = result.businessProcessName || 'New Business Process';
                this.isCaseCreated = true;

                this.showToast(
                    'Success',
                    `Business Process ${this.createdBusinessProcessName} created with ${countEois} EOI(s) tagged. Refund cases will be created upon approval.`,
                    'success'
                );
            } else {
                throw new Error(result ? result.message : 'Submission failed.');
            }
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
            this.showToast('Error Submitting Refund', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.isCaseCreated = false;
        this.createdBusinessProcessId = null;
        this.createdBusinessProcessName = '';
        this.selectedProjectId = null;
        this.eoiList = [];
        this.selectedEoiIds = [];
        this.selectedReceiptIds = [];
        this.currentPage = 1;
        this.currentStep = 2;
        this.uploadedMemoFile = null;
        this.errorMessage = null;
        this.handleRefresh();
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredProjectsResult);
            if (this.selectedProjectId) {
                await this.loadEOIs(this.selectedProjectId);
            }
        } catch (error) {
            this.showToast('Error Refreshing Data', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-AE', {
            style: 'currency',
            currency: 'AED'
        }).format(amount || 0);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}