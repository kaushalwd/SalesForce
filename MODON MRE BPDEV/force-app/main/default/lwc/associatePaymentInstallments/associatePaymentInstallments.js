import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';

import modalStyles from '@salesforce/resourceUrl/associatePaymentInstallmentsModal';
import getEligiblePaymentInstallments from '@salesforce/apex/AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments';
import associatePaymentInstallments from '@salesforce/apex/AssociatePaymentInstallmentsFromBp.associatePaymentInstallments';
import removePaymentInstallments from '@salesforce/apex/AssociatePaymentInstallmentsFromBp.removePaymentInstallments';
import createExportFile from '@salesforce/apex/FileExportUtility.createExportFile';

const EXPORT_HEADERS = [
    '#',
    'Name',
    'Milestone Number',
    'Milestone Description',
    'Milestone Date',
    'Project',
    'Phase',
    'Already Associated'
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

export default class AssociatePaymentInstallments extends LightningElement {

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

    installments = [];
    selectedIds = [];
    descriptionFilter = '';
    fromDateFilter = '';
    toDateFilter = '';
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
            this.installments = await getEligiblePaymentInstallments({
                businessProcessId: this.recordId
            });
            this.selectedIds = this.installments
                .filter((item) => item.alreadyAssociated)
                .map((item) => item.id);
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

    get originallyAssociatedIds() {
        return this.installments
            .filter((item) => item.alreadyAssociated)
            .map((item) => item.id);
    }

    get idsToAssociate() {
        const original = this.originallyAssociatedIds;
        return this.selectedIds.filter((id) => !original.includes(id));
    }

    get idsToRemove() {
        return this.originallyAssociatedIds.filter((id) => !this.selectedIds.includes(id));
    }

    get hasPendingChanges() {
        return this.idsToAssociate.length > 0 || this.idsToRemove.length > 0;
    }

    get displayRows() {

        const filter = (this.descriptionFilter || '').trim().toLowerCase();
        const fromDate = this.fromDateFilter;
        const toDate = this.toDateFilter;

        return this.installments
            .filter((item) => !filter || (item.milestoneDescription || '').toLowerCase().includes(filter))
            .filter((item) => !fromDate || (item.milestoneDate && item.milestoneDate >= fromDate))
            .filter((item) => !toDate || (item.milestoneDate && item.milestoneDate <= toDate))
            // Already-associated installments come first; stable sort keeps everything
            // else in its existing relative order.
            .sort((a, b) => Number(b.alreadyAssociated) - Number(a.alreadyAssociated))
            .map((item, index) => {

                const isSelected = this.selectedIds.includes(item.id);
                const pendingRemoval = item.alreadyAssociated && !isSelected;
                const pendingAddition = !item.alreadyAssociated && isSelected;

                let rowClass = 'slds-hint-parent';
                if (pendingRemoval) {
                    rowClass += ' pending-removal-row';
                }
                else if (item.alreadyAssociated) {
                    rowClass += ' already-associated-row';
                }

                return {
                    ...item,
                    serialNumber: index + 1,
                    isSelected,
                    pendingRemoval,
                    pendingAddition,
                    rowClass
                };
            });
    }

    get hasNoMatches() {
        return !this.hasError && !this.isLoading && this.displayRows.length === 0;
    }

    get isDownloadDisabled() {
        return this.hasNoMatches || this.isExporting;
    }

    get hasNoActiveFilters() {
        return !(this.descriptionFilter || this.fromDateFilter || this.toDateFilter);
    }

    get selectedCountLabel() {
        const count = this.selectedIds.length;
        return count === 1 ? '1 selected' : `${count} selected`;
    }

    get matchCountLabel() {
        const count = this.displayRows.length;
        return count === 1 ? '1 match' : `${count} matches`;
    }

    get isAllSelected() {
        const rows = this.displayRows;
        return rows.length > 0 && rows.every((row) => this.selectedIds.includes(row.id));
    }

    get isSaveDisabled() {
        return this.isLoading || !this.hasPendingChanges;
    }

    get fullScreenIcon() {
        return this.isFullScreen ? 'utility:contract' : 'utility:expand';
    }

    get fullScreenLabel() {
        return this.isFullScreen ? 'Exit Full Screen' : 'Full Screen';
    }

    handleFilterChange(event) {
        this.descriptionFilter = event.target.value;
    }

    handleFromDateChange(event) {
        this.fromDateFilter = event.target.value;
    }

    handleToDateChange(event) {
        this.toDateFilter = event.target.value;
    }

    handleClearFilters() {
        this.descriptionFilter = '';
        this.fromDateFilter = '';
        this.toDateFilter = '';
    }

    handleRowCheckboxChange(event) {

        const rowId = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            if (!this.selectedIds.includes(rowId)) {
                this.selectedIds = [...this.selectedIds, rowId];
            }
        }
        else {
            this.selectedIds = this.selectedIds.filter((id) => id !== rowId);
        }
    }

    handleSelectAllChange(event) {

        const checked = event.target.checked;
        const rowIds = this.displayRows.map((row) => row.id);

        if (checked) {
            this.selectedIds = Array.from(new Set([...this.selectedIds, ...rowIds]));
        }
        else {
            const toDeselect = new Set(rowIds);
            this.selectedIds = this.selectedIds.filter((id) => !toDeselect.has(id));
        }
    }

    handleToggleFullScreen() {

        this.isFullScreen = !this.isFullScreen;

        if (this.modalContainer) {
            this.modalContainer.classList.toggle('pi-fullscreen-modal', this.isFullScreen);
        }
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
                        row.name,
                        row.milestoneNumber,
                        row.milestoneDescription,
                        row.milestoneDate,
                        row.projectName,
                        row.phaseName,
                        row.alreadyAssociated ? 'Yes' : 'No'
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

            const fileName = 'PaymentInstallments_' + Date.now() + '.xls';

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

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {

        const idsToAssociate = this.idsToAssociate;
        const idsToRemove = this.idsToRemove;

        if (!idsToAssociate.length && !idsToRemove.length) {
            return;
        }

        this.isLoading = true;

        try {
            const calls = [];

            if (idsToAssociate.length) {
                calls.push(associatePaymentInstallments({
                    businessProcessId: this.recordId,
                    paymentInstallmentIds: idsToAssociate
                }));
            }

            if (idsToRemove.length) {
                calls.push(removePaymentInstallments({
                    businessProcessId: this.recordId,
                    paymentInstallmentIds: idsToRemove
                }));
            }

            await Promise.all(calls);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Payment Installment associations updated.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
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
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        return (error && error.body && error.body.message) || 'Unknown error';
    }
}