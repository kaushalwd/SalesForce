import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';

import modalStyles from '@salesforce/resourceUrl/associatePaymentInstallmentsModal';
import getMilestoneInstallments from '@salesforce/apex/MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments';
import createExportFile from '@salesforce/apex/FileExportUtility.createExportFile';

const EXPORT_HEADERS = [
    '#',
    'Sales Order',
    'Unit',
    'Project',
    'Phase',
    'Milestone Date',
    'Payment Status',
    'Sales Order Status',
    'Amount',
    'Currency'
];

function escapeHtml(value) {
    const str = value === null || value === undefined ? '' : String(value);
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function toBase64Utf8(str) {
    const bytes = new TextEncoder().encode(str);
    let binary = '';
    bytes.forEach((byte) => {
        binary += String.fromCharCode(byte);
    });
    return window.btoa(binary);
}

export default class MilestoneInstallmentsSummary extends LightningElement {

    _recordId;
    hasLoaded = false;
    stylesLoaded = false;
    modalContainer;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value && !this.hasLoaded) {
            this.hasLoaded = true;
            this.loadInstallments();
        }
    }

    rows = [];
    totals = [];
    totalCount = 0;
    isFullScreen = false;
    isLoading = true;
    isExporting = false;
    errorMessage;

    renderedCallback() {

        if (!this.stylesLoaded) {
            this.stylesLoaded = true;
            loadStyle(this, modalStyles).catch(() => {
                /* Sizing is a visual enhancement only; safe to ignore a load failure. */
            });
        }

        if (!this.modalContainer) {
            const host = this.template.host;
            const container = (host && typeof host.closest === 'function')
                ? host.closest('.slds-modal__container')
                : null;

            if (container) {
                // Unique marker so the loaded stylesheet (injected globally into
                // document.head) only ever matches THIS modal instance, never any
                // other modal (e.g. the Approval Modal) open elsewhere in the app.
                container.classList.add('pi-modal-scope');
                this.modalContainer = container;
            }
        }
    }

    async loadInstallments() {

        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const result = await getMilestoneInstallments({
                businessProcessId: this.recordId
            });
            this.rows = result.rows;
            this.totals = result.totals;
            this.totalCount = result.totalCount;
        }
        catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
        }
        finally {
            this.isLoading = false;
        }
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasNoRows() {
        return !this.hasError && !this.isLoading && this.rows.length === 0;
    }

    get displayRows() {
        return this.rows.map((row, index) => ({
            ...row,
            serialNumber: index + 1,
            paymentStatusClass: this.getPaymentStatusClass(row.paymentStatus)
        }));
    }

    getPaymentStatusClass(status) {
        if (status === 'Paid') {
            return 'slds-badge slds-theme_success';
        }
        if (status === 'Partially Paid') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge slds-theme_error';
    }

    get isDownloadDisabled() {
        return this.hasNoRows || this.isExporting;
    }

    get fullScreenIcon() {
        return this.isFullScreen ? 'utility:contract' : 'utility:expand';
    }

    get fullScreenLabel() {
        return this.isFullScreen ? 'Exit Full Screen' : 'Full Screen';
    }

    handleToggleFullScreen() {

        this.isFullScreen = !this.isFullScreen;

        if (this.modalContainer) {
            this.modalContainer.classList.toggle('pi-fullscreen-modal', this.isFullScreen);
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleDownload() {

        const rows = this.displayRows;

        if (!rows.length) {
            return;
        }

        this.isExporting = true;

        try {
            const headerCells = EXPORT_HEADERS.map((h) => `<th>${escapeHtml(h)}</th>`).join('');

            const bodyRows = rows
                .map((row) => {
                    const cells = [
                        row.serialNumber,
                        row.salesOrderName,
                        row.unitName,
                        row.projectName,
                        row.phaseName,
                        row.milestoneDate,
                        row.paymentStatus,
                        row.salesOrderStatus,
                        row.installmentAmount,
                        row.currencyCode
                    ]
                        .map((value) => `<td>${escapeHtml(value)}</td>`)
                        .join('');
                    return `<tr>${cells}</tr>`;
                })
                .join('');

            const htmlContent =
                '<html xmlns:o="urn:schemas-microsoft-com:office:office" ' +
                'xmlns:x="urn:schemas-microsoft-com:office:excel">' +
                '<head><meta charset="UTF-8"></head>' +
                '<body><table border="1">' +
                `<thead><tr>${headerCells}</tr></thead>` +
                `<tbody>${bodyRows}</tbody>` +
                '</table></body></html>';

            const fileName = 'MilestoneInstallments_' + Date.now() + '.xls';

            const downloadUrl = await createExportFile({
                base64Content: toBase64Utf8(htmlContent),
                fileName
            });

            window.open(downloadUrl, '_blank');
        }
        catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
        finally {
            this.isExporting = false;
        }
    }

    extractErrorMessage(error) {
        return (error && error.body && error.body.message) || 'Unknown error';
    }
}