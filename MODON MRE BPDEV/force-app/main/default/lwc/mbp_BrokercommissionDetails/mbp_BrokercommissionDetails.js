import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';
import getCommissionData from '@salesforce/apex/MBP_CommissionTreeCustomController.getCommissionData';
import savePDFtoCommissionLine from '@salesforce/apex/MBP_CommissionInvoicePDFController.savePDFtoCommissionLine';
import getCommissionPDFBase64 from '@salesforce/apex/MBP_CommissionInvoicePDFController.getCommissionPDFBase64';

import rejectCommissionWithComments from '@salesforce/apex/MBP_CommissionInvoicePDFController.rejectCommissionWithComments';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import getPicklistValues from '@salesforce/apex/MBP_CommissionTreeCustomController.getPicklistValues';

import hasBrokerVAT from
'@salesforce/apex/MBP_CommissionInvoicePDFController.hasBrokerVAT';
import isTradeLicenseMandatory
from '@salesforce/apex/MBP_CommissionInvoicePDFController.isTradeLicenseMandatory';
import isSupplierAndBankSynced
from '@salesforce/apex/MBP_CommissionInvoicePDFController.isSupplierAndBankSynced';
const CONTACT_FIELDS = ['Contact.Broker_Type__c'];
import vatCertificate from '@salesforce/resourceUrl/MBP_VatUndertakingCertificate';

// Shown whenever the broker agency's OIC (Fusion) Bank / Supplier sync has
// not completed successfully yet. Until both come back "Success", the
// broker must not be allowed to accept/submit invoices or manage bank
// details.
const OIC_NOT_SYNCED_MESSAGE =
    'Your banking details are currently not synced with the payment system. Please reach out to broker@modon.com for further assistance.';

export default class Commissionspage extends LightningElement {
    @track isLoading = true;
    @track showNoAccess = false;
    @track showModal = false;
    @track selectedCommissionId;
    @track canAcceptCommission = false;
    @track commissions = [];
    @track filteredCommissions = [];
    @track invoiceNumber;
    @track invoiceDate;
    @track showStatusMessageModal = false;
    @track statusMessage = '';
    vatDownloadUrl = vatCertificate;
    invoiceFile;
    @track showTradeLicenseModal = false;

    @track invoiceFileName;

    // Filter properties
    @track showFilterBox = false;
    @track customStartDate;
    @track customEndDate;
    @track unitSearchTerm = '';
    @track projectFilter = '';
    @track unitFilter = '';
    @track statusFilter = '';
    @track downPaymentFilter = '';
    @track spaFilter = '';

    filterIcon = FilterIcon;

    // Picklist options - fetched from Apex
    @track statusOptions = [];
    @track spaOptions = [];
    @track downPaymentOptions = [];

    @track projectOptions = [];
    @track unitOptions = [];

    @track showVatUploadModal = false;

    @track currentPage = 1;
    @track pageSize = 10;

    // Tracks which column positions (1-based, matching header/row child
    // order) the user has manually widened via the resize handle, so the
    // "wrap-enabled" class can be reapplied to newly-rendered rows after
    // pagination/filtering/refresh (renderedCallback re-creates row DOM).
    wrappedColumns = new Set();

    get totalPages() {
        return Math.ceil(this.filteredCommissions.length / this.pageSize) || 1;
    }

    get paginatedCommissions() {
        const startIdx = (this.currentPage - 1) * this.pageSize;
        const endIdx = this.currentPage * this.pageSize;

        // Take only current page records, in the order returned by Apex.
        const pageRecords = this.filteredCommissions.slice(startIdx, endIdx);

        // Add serial number here (computed purely in JS)
        return pageRecords.map((rec, index) => ({
            ...rec,
            serialNumber: (this.currentPage - 1) * this.pageSize + index + 1
        }));
    }

    handleInvoiceFileSelect(event) {
        const file = event.target.files[0];

        if (!file) return;

        const maxSize = 2 * 1024 * 1024;

        if (file.size > maxSize) {
            this.showToast('File size cannot exceed 2 MB', 'error');
            event.target.value = null;
            return;
        }
        if (this.invoiceFileName === file.name) {
            event.target.value = null;
            return;
        }

        this.invoiceFile = file;
        this.invoiceFileName = file.name;

        event.target.value = null;
    }

    handleInvoiceNumber(event) {
        this.invoiceNumber = event.target.value;
    }

    handleInvoiceDate(event) {
        this.invoiceDate = event.target.value;
    }

    convertToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => {
                resolve(reader.result.split(',')[1]);
            };

            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    applyFilters() {
        this.filteredCommissions = this.commissions.filter(cl => {
            const unitNameMatches = !this.unitSearchTerm ||
                (cl.UnitName && cl.UnitName.toLowerCase().includes(this.unitSearchTerm));

            const statusMatches = !this.statusFilter || cl.StatusLabel === this.statusFilter;
            const downPaymentMatches = !this.downPaymentFilter || cl.DownPaymentStatus === this.downPaymentFilter;
            const spaMatches = !this.spaFilter || cl.SpaStatus === this.spaFilter;

            const projectMatches = !this.projectFilter || cl.ProjectName === this.projectFilter;
            const unitFilterMatches = !this.unitFilter || String(cl.TotalUnitPrice) === this.unitFilter;

            let dateMatches = true;
            if (this.customStartDate && this.customEndDate && cl.InvoiceDate) {
                const invoiceDate = new Date(cl.InvoiceDate);
                const start = new Date(this.customStartDate);
                const end = new Date(this.customEndDate);
                dateMatches = invoiceDate >= start && invoiceDate <= end;
            }

            return (
                projectMatches &&
                unitFilterMatches &&
                unitNameMatches &&
                statusMatches &&
                downPaymentMatches &&
                spaMatches &&
                dateMatches
            );
        });

        this.currentPage = 1;
    }

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    handleFilterChange(event) {
        const name = event.target.name;
        const value = event.detail.value;

        if (name === 'statusFilter') {
            this.statusFilter = value;
        } else if (name === 'downPaymentFilter') {
            this.downPaymentFilter = value;
        } else if (name === 'spaFilter') {
            this.spaFilter = value;
        }
    }

    handleStartDateChange(event) {
        this.customStartDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.customEndDate = event.target.value;
    }

    handleUnitSearch(event) {
        this.unitSearchTerm = event.target.value.toLowerCase();
    }

    applyFiltersAndClose() {
        const searchInput = this.template.querySelector('input[type="text"]');
        if (searchInput) {
            this.unitSearchTerm = searchInput.value.toLowerCase();
        }

        // Wait for the fresh data to actually arrive before filtering it -
        // fetchCommissionData is async, so applying filters immediately
        // (without waiting) meant the fetch would resolve moments later
        // and silently overwrite the filtered list with the full,
        // unfiltered one.
        this.fetchCommissionData().then(() => {
            this.applyFilters();
        });

        this.showFilterBox = false;
    }

    resetFilters() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');

        this.customStartDate = `${yyyy}-01-01`;
        this.customEndDate = `${yyyy}-${mm}-${dd}`;
        this.unitSearchTerm = '';
        this.projectFilter = '';
        this.unitFilter = '';
        this.statusFilter = '';
        this.downPaymentFilter = '';
        this.spaFilter = '';

        // Reset combobox values
        const comboboxes = this.template.querySelectorAll('lightning-combobox');
        comboboxes.forEach(combobox => {
            combobox.value = '';
        });

        // Reset search input
        const searchInput = this.template.querySelector('input[type="text"]');
        if (searchInput) {
            searchInput.value = '';
        }

        // Reset filtered data to show all commissions
        this.filteredCommissions = [...this.commissions];
        this.currentPage = 1;
    }

    @wire(getRecord, { recordId: '$contactId', fields: CONTACT_FIELDS })
    wiredContact({ error, data }) {
        if (data) {
            const brokerType = data.fields.Broker_Type__c.value;
            this.isBrokerTypeAgencyAdmin = brokerType === 'Owner';
        } else if (error) {
            console.error('Error fetching contact:', error);
        }
    }

    connectedCallback() {
        this.template.addEventListener('mousedown', this.initResize.bind(this));

        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');

        this.customEndDate = `${yyyy}-${mm}-${dd}`;
        this.customStartDate = `${yyyy}-01-01`;

        getEditableAccount()
            .then(result => {
                this.isLoading = false;
                if (result?.brokerType === 'Agent') {
                    this.showNoAccess = true;
                } else {
                    this.showNoAccess = false;
                    this.fetchPicklistValues();
                    this.fetchCommissionData();
                }
            })
            .catch(error => {
                console.error('Error fetching broker info:', error);
                this.isLoading = false;
                this.showNoAccess = true;
            });
    }

    fetchPicklistValues() {
        getPicklistValues()
            .then(result => {
                this.statusOptions = result.status || [];
                this.spaOptions = result.spaStatus || [];
                this.downPaymentOptions = result.downPaymentStatus || [];
            })
            .catch(error => {
                console.error('Error fetching picklist values:', error);
            });
    }

    // Drag-to-resize a column. The header cell carries a data-col-key
    // (e.g. "unit-number") that maps to the shared --col-unit-number CSS
    // custom property used by BOTH the header and every row's
    // grid-template-columns (see CSS). Updating that variable - rather
    // than the previous behaviour of setting an inline width on just the
    // header cell, which has no effect on a grid track's size - resizes
    // the whole column, header and data rows together. Once a column has
    // been widened this way, its cells are also switched from
    // single-line ellipsis to wrapping (see enableWrapForColumn) so the
    // extra width actually shows the full text instead of leaving it
    // clipped.
    initResize(event) {
        if (!event.target.classList.contains('resize-handle')) return;

        const col = event.target.parentElement;
        const colKey = col.dataset.colKey;
        if (!colKey) return;

        // 1-based position of this header cell among its siblings -
        // header and row cells appear in the same left-to-right order,
        // so this index also locates the matching cell in every data row.
        const colIndex = Array.from(col.parentElement.children).indexOf(col) + 1;

        const startX = event.pageX;
        const startWidth = col.offsetWidth;
        const hostEl = this.template.host;

        const onMouseMove = (e) => {
            const newWidth = Math.max(60, startWidth + (e.pageX - startX));

            // Resize the shared grid track so the header AND every row's
            // cell in this column widen together.
            hostEl.style.setProperty(`--col-${colKey}`, `${newWidth}px`);

            this.wrappedColumns.add(colIndex);
            this.enableWrapForColumn(colIndex);
        };

        const onMouseUp = () => {
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);
        };

        window.addEventListener('mousemove', onMouseMove);
        window.addEventListener('mouseup', onMouseUp);
    }

    // Switches the given column (by 1-based position) from single-line
    // ellipsis to wrapping text, for its header cell and every currently
    // rendered row's matching cell. Skipped for badge/pill cells (Down
    // payment, SPA, Commission status) which are meant to stay one line.
    enableWrapForColumn(colIndex) {
        const headerCell = this.template.querySelector(
            `.commission-header > span:nth-child(${colIndex})`
        );
        if (headerCell) headerCell.classList.add('wrap-enabled');

        this.template.querySelectorAll('.commission-row').forEach(row => {
            const cell = row.children[colIndex - 1];
            if (cell && !cell.querySelector('.cell-badge-wrap')) {
                cell.classList.add('wrap-enabled');
            }
        });
    }

    fetchCommissionData() {
        this.isLoading = true;
        const startDateStr = this.customStartDate; // YYYY-MM-DD
        const endDateStr = this.customEndDate;

        return getCommissionData({ startDateStr, endDateStr })
            .then(data => {
                this.isLoading = false;
                if (data.length > 0) {
                    this.canAcceptCommission = data[0].canAcceptCommission;
                }

                this.commissions = data.map(cl => ({
                    Id: cl.commissionId,
                    ProjectName: cl.project,
                    UnitName: cl.unitNumber,

                    ClearanceDate: cl.clearanceDate
    ? new Date(cl.clearanceDate).toLocaleDateString()
    : '',

                    Agent: cl.brokerAgent,
                    CommissionPercent: cl.commissionPercent,
                    CommissionAmount: this.formatCurrency(cl.totalCommission),
                    TotalCommissionPaid: this.formatCurrency(cl.paidAmount),
                    RemainingPayout: cl.futureEligibleAmount == null
                        ? 'Out Of Scope'
                        : `AED ${this.formatCurrency(cl.futureEligibleAmount)}`,

                    unitprice: this.formatCurrency(cl.totalunitprice),

                    StatusLabel: cl.status,
                    StatusBadgeClass: this.getStatusBadgeClass(cl.status),
                    DownPaymentIcon: this.getIcon(cl.downPaymentStatus),
                    DownPaymentStatus: cl.downPaymentStatus,
                    SpaIcon: this.getIcon(cl.spaStatus),
                    SpaStatus: cl.spaStatus,
                    disabledAttr: cl.status !== 'Ready To Process' ? 'disabled' : null,
                    InvoiceDate: cl.invoiceDate ? new Date(cl.invoiceDate).toLocaleDateString() : '',
                    CustomerName: cl.customerName,
                }));

                this.filteredCommissions = [...this.commissions];
                this.projectOptions = [...new Set(this.commissions.map(c => c.ProjectName))]
                    .map(p => ({ label: p, value: p }));
                this.unitOptions = [...new Set(this.commissions.map(c => c.UnitName))]
                    .map(u => ({ label: u, value: u }));
            })
            .catch(error => {
                console.error('Error fetching commission data:', error);
                this.isLoading = false;
            });
    }

    renderedCallback() {
        if (!this._outsideClickHandlerAdded) {
            this._outsideClickHandler = this.handleOutsideClick.bind(this);
            document.addEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = true;
        }

        // Rows are re-rendered as fresh DOM nodes whenever the page,
        // filters, or underlying data change, so any "wrap-enabled"
        // class applied earlier by enableWrapForColumn is lost on those
        // new nodes. Reapply it for every column the user has already
        // widened, so previously-expanded columns keep wrapping instead
        // of reverting to truncated text.
        if (this.wrappedColumns.size) {
            this.wrappedColumns.forEach(colIndex => this.enableWrapForColumn(colIndex));
        }
    }

    closeVatModal() {
        this.showVatUploadModal = false;

        this.invoiceFile = null;
        this.invoiceFileName = null;
    }

    async submitVatDetails() {
        if (!this.invoiceNumber || !this.invoiceDate) {
            this.showToast('Invoice Number & Date required', 'error');
            return;
        }

        if (!this.invoiceFile) {
            this.showToast('Please upload required files', 'error');
            return;
        }

        this.isLoading = true;

        try {
            // Fusion (OIC) sync must be successful before an invoice can be
            // submitted. Re-checked here in case the sync status changed
            // (or was never verified) between opening the modal and
            // submitting.
            const isSynced = await isSupplierAndBankSynced();

            if (!isSynced) {
                this.closeVatModal();
                this.statusMessage = OIC_NOT_SYNCED_MESSAGE;
                this.showStatusMessageModal = true;
                return;
            }

            const invoiceBase64 = await this.convertToBase64(this.invoiceFile);

            await savePDFtoCommissionLine({
                commissionLineId: this.selectedCommissionId,
                comments: '',
                invoiceNumber: this.invoiceNumber,
                invoiceDate: this.invoiceDate,
                invoiceFileName: this.invoiceFile.name,
                invoiceFileData: invoiceBase64,
                isVatUndertakingFlow: true
            });

            this.showToast('Invoice submitted successfully', 'success');
            this.closeVatModal();
            await this.fetchCommissionData();
        } catch (error) {
            this.showToast(this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-fab');

        // Check composed path for shadow DOM elements
        const path = event.composedPath ? event.composedPath() : [];
        const clickedInside =
            (filterWrapper && path.includes(filterWrapper)) ||
            (filterIcon && path.includes(filterIcon));

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    closeFilterBox(event) {
        if (event) event.stopPropagation();
        this.showFilterBox = false;
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    disconnectedCallback() {
        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

    get selectedCommissionReady() {
        if (!this.selectedCommissionId) return false;
        const selected = this.commissions.find(c => c.Id === this.selectedCommissionId);
        return selected?.StatusLabel === 'Ready To Process';
    }

    formatCurrency(amount) {
        if (amount == null) return '0.00';
        return Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    // Icon/badge class for the Down Payment & SPA status columns
    getIcon(status) {
        if (!status) return 'icon-waiting';
        const s = status.toLowerCase();

        if (['paid', 'completed', 'approved', 'spa signed (modon)'].some(val => s.includes(val))) {
            return 'icon-success';
        }
        if (['pending', 'partially paid', 'generated', 'pending with customer', 'pending for validation', 'pending with modon'].some(val => s.includes(val))) {
            return 'icon-progress';
        }
        if (s.includes('cancelled')) {
            return 'icon-cancelled';
        }
        return 'icon-waiting';
    }

    // Badge class for the Commission Status column
    getStatusBadgeClass(status) {
        if (!status) return 'status-pill neutral';
        const s = status.toLowerCase();

        if (s.includes('completed')) {
            return 'status-pill success';
        }
        if (s.includes('ready to process')) {
            return 'status-pill info';
        }
        if (s.includes('rejected') || s.includes('cancelled')) {
            return 'status-pill danger';
        }
        if (['pending', 'progress', 'review', 're-calculated'].some(val => s.includes(val))) {
            return 'status-pill warning';
        }
        return 'status-pill neutral';
    }

    get invoiceVFPageUrl() {
        if (!this.selectedCommissionId) return '';

        const selected = this.commissions.find(c => c.Id === this.selectedCommissionId);

        return `/apex/CommissionInvoicePDF?commissionId=${this.selectedCommissionId}&status=${selected?.StatusLabel}&renderAs=html`;
    }

    handleDownload() {
        if (!this.selectedCommissionId) return;
        getCommissionPDFBase64({ commissionLineId: this.selectedCommissionId })
            .then(base64Data => {
                const byteArray = new Uint8Array([...atob(base64Data)].map(c => c.charCodeAt(0)));
                const blob = new Blob([byteArray], { type: 'application/pdf' });
                const link = document.createElement('a');
                link.href = URL.createObjectURL(blob);
                link.download = `CommissionInvoice_${this.selectedCommissionId}.pdf`;
                link.click();
            })
            .catch(error => {
                console.error('Download error:', error);
                this.showToast('Download error: ' + this.extractErrorMessage(error), 'error');
            });
    }

    // Accept handler - optional tax invoice number, comments pulled from the VF iframe
    async handleAccept() {
        const iframe = this.template.querySelector('iframe');
        if (!iframe) {
            this.showToast('Invoice form is not loaded yet.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            // Fusion (OIC) Bank / Supplier sync must be successful before an
            // invoice can be accepted. This is re-checked here (not just at
            // modal-open time) since the sync status can change between
            // when the modal was opened and when the broker clicks Accept.
            const isSynced = await isSupplierAndBankSynced();

            if (!isSynced) {
                this.closeModal();
                this.statusMessage = OIC_NOT_SYNCED_MESSAGE;
                this.showStatusMessageModal = true;
                return;
            }

            const comments = iframe.contentWindow.getRejectionComments
                ? iframe.contentWindow.getRejectionComments()
                : '';

            await savePDFtoCommissionLine({
                commissionLineId: this.selectedCommissionId,
                comments: comments
            });

            await this.fetchCommissionData();
            this.showToast('Invoice submitted for approval.', 'success');
            this.closeModal();
        } catch (error) {
            this.showToast(
                'Submission failed: ' + this.extractErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleReject() {
        const iframe = this.template.querySelector('iframe');

        if (iframe && iframe.contentWindow) {
            try {
                const isValid = iframe.contentWindow.validateBeforeReject();

                if (isValid === true) {
                    const comments = iframe.contentWindow.getRejectionComments();

                    const result = await rejectCommissionWithComments({
                        commissionLineId: this.selectedCommissionId,
                        comments: comments
                    });

                    if (result === 'SUCCESS') {
                        this.commissions = this.commissions.map(cl =>
                            cl.Id === this.selectedCommissionId
                                ? { ...cl, invoiceStatus: 'Rejected', comments: comments }
                                : cl
                        );
                        this.applyFilters();
                        this.closeModal();
                        window.location.reload();
                        this.showToast('Commission rejected successfully.', 'success');
                    } else {
                        this.showToast(result, 'error');
                    }
                }
            } catch (e) {
                console.error('Error during rejection process:', e);
                this.showToast('Error rejecting commission: ' + (e.body?.message || e.message), 'error');
            }
        } else {
            this.showToast('Cannot access invoice form.', 'error');
        }
    }

    // Utility function to extract error messages
    extractErrorMessage(error) {
        try {
            if (error && typeof error === 'object') {
                if (error.body && error.body.message) {
                    return error.body.message;
                }
                if (error.message) {
                    return error.message;
                }
                try {
                    const errorString = JSON.stringify(error);
                    const errorObj = JSON.parse(errorString);
                    if (errorObj.body && errorObj.body.message) {
                        return errorObj.body.message;
                    }
                    return errorString;
                } catch (parseError) {
                    return 'Error parsing error message';
                }
            }
            return String(error);
        } catch (e) {
            return 'Unknown error occurred';
        }
    }

    showToast(message, variant) {
        const toast = this.template.querySelector('c-mbp_customshowtoast');
        if (toast) {
            toast.show(message, variant);
        }
    }

    closeTradeLicenseModal() {
        this.showTradeLicenseModal = false;
    }

    // First checks the Fusion (OIC) Bank / Supplier sync status - this is
    // the hard gate: until both OIC_Bank_Response__c and
    // OIC_Supplier_Response__c come back "Success", the broker cannot
    // proceed with invoice acceptance (or bank detail related actions)
    // at all, regardless of their commission/VAT status. Only once that
    // passes do the existing VAT / bank-details / commission-status
    // checks run.
    async openInvoiceModalClick(event) {
        event.stopPropagation();

        this.selectedCommissionId = event.currentTarget.dataset.id;

        const selected = this.commissions.find(
            c => c.Id === this.selectedCommissionId
        );

        if (!selected) return;

        const status = selected.StatusLabel;

        this.isLoading = true;

        try {
            const isSynced = await isSupplierAndBankSynced();

            if (!isSynced) {
                this.statusMessage = OIC_NOT_SYNCED_MESSAGE;
                this.showStatusMessageModal = true;
                return;
            }

            // Existing bank-details / VAT / commission-status logic.
            const hasVat = await hasBrokerVAT();

            // If VAT exists, always open the invoice PDF modal
            if (hasVat) {
                this.showModal = true;
                return;
            }

            // No VAT: follow existing status logic
            if (
                status === 'Not Reviewed' ||
                status === 'Internal Review In-Progress' ||
                status === 'Re-Calculated' ||
                status === 'In Progress'
            ) {
                this.statusMessage =
                    'Your commission information is currently being validated by our Broker Management Team. Please wait until the review is completed.';
                this.showStatusMessageModal = true;
                return;
            }

            if (status === 'Ready To Process') {
                const isMandatory = await isTradeLicenseMandatory();
                if (isMandatory) {
                    this.showTradeLicenseModal = true;
                } else {
                    this.showVatUploadModal = true;
                }
                return;
            }

            if (
                status === 'Pending Invoice Verification' ||
                status === 'Pending Finance Verification'
            ) {
                this.statusMessage =
                    'Your invoice has been submitted successfully and is currently under approval. Our team will review and process it shortly.';
                this.showStatusMessageModal = true;
                return;
            }

            if (status === 'Completed' || status === 'Completed - Partially') {
                this.statusMessage =
                    'Your commission payment has been successfully deposited into your registered bank account.';
                this.showStatusMessageModal = true;
                return;
            }
        } catch (error) {
            this.showToast('Error validating agency', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeStatusModal() {
        this.showStatusMessageModal = false;
    }

    closeModal() {
        this.showModal = false;
        this.selectedCommissionId = null;
    }

    handleIframeLoad(event) {
        this.isLoading = false;

        try {
            const iframe = event.target;
            const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;

            if (iframeDoc && iframeDoc.querySelector) {
                const inputField = iframeDoc.querySelector('.input-field');
                this.showTaxInvoiceInput = !!inputField;
            }
        } catch (e) {
            console.log('Cannot access iframe content due to security restrictions');
        }
    }
}