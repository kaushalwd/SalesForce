import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningConfirm from 'lightning/confirm';

import getServiceRequestContext from '@salesforce/apex/SRPaymentReadinessController.getServiceRequestContext';
import getInstallmentsByMilestone from '@salesforce/apex/SRPaymentReadinessController.getInstallmentsByMilestone';
import saveReadiness from '@salesforce/apex/SRPaymentReadinessController.saveReadiness';
import initiateInstallmentPaymentConfirmation from '@salesforce/apex/SRPaymentReadinessController.initiateInstallmentPaymentConfirmation';
import XLSX_LIB from '@salesforce/resourceUrl/xlsx';
import modalStyles from '@salesforce/resourceUrl/paymentMilestoneSRModal';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';

export default class PaymentMilestoneSR extends LightningElement {
    _recordId;
    initialized = false;
    xlsxInitialized = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;

        // Quick Action inject timing fix
        if (!this.initialized && value) {
            this.initialized = true;
            this.load();
        }
    }

    @track rows = [];
    milestoneId;
    milestoneName = '';

    isLoading = false;
    isFullScreen = false;
    stylesLoaded = false;
    modalContainer;
    businessProcessMessage = '';
    isProjectMilestoneConfirmation = false;

    // store only changes: soiId -> { soiId, soiName, readiness, comment }
    draftById = new Map();

constructor() {
    super();
}
   connectedCallback() {


    if (this.xlsxInitialized) {
        return;
    }

    this.xlsxInitialized = true;

    loadScript(this, XLSX_LIB + '/xlsx.full.min.js')
        .catch(error => {
            console.error('Error loading XLSX', error);
        });
}

    renderedCallback() {

        if (!this.stylesLoaded) {
            this.stylesLoaded = true;
            loadStyle(this, modalStyles).catch(() => {
                /* Sizing is a visual enhancement only; safe to ignore a load failure. */
            });
        }

        if (!this.modalContainer) {
            const host = this.template.host;
            const container = host && host.closest('.slds-modal__container');

            if (container) {
                // Unique marker so the loaded stylesheet (which is injected globally
                // into document.head) only ever matches THIS modal instance, never
                // any other modal (e.g. the Approval Modal) open elsewhere in the app.
                container.classList.add('pmsr-modal-scope');
                this.modalContainer = container;
            }
        }
    }

    get fullScreenIcon() {
        return this.isFullScreen ? 'utility:contract' : 'utility:expand';
    }

    get fullScreenLabel() {
        return this.isFullScreen ? 'Exit Full Screen' : 'Full Screen';
    }

    get tableWrapperClass() {
        return this.isFullScreen
            ? 'pmsr-table-wrapper pmsr-fullscreen'
            : 'pmsr-table-wrapper';
    }

    handleToggleFullScreen() {

        this.isFullScreen = !this.isFullScreen;

        if (this.modalContainer) {
            this.modalContainer.classList.toggle('pmsr-fullscreen-modal', this.isFullScreen);
        }
    }

    async load() {
        try {
            this.isLoading = true;
            if (!this.recordId) return;

            const ctx = await getServiceRequestContext({ serviceRequestId: this.recordId });
            this.milestoneId = ctx ? ctx.milestoneId : null;
            this.isProjectMilestoneConfirmation = !!ctx && ctx.businessProcessType === 'Project Milestone Confirmation';

            if (!this.milestoneId) {
                this.toast('No Milestone', 'This Service Request has no Milestone selected.', 'warning');
                this.rows = [];
                return;
            }

            // businessProcessId lets Apex limit installments to the Business Process's Phase
            const data = await getInstallmentsByMilestone({
                milestoneId: this.milestoneId,
                businessProcessId: this.recordId
            });

            this.rows = (data || []).map((r, index) => {
                return {
                    ...r,
                    sno: index + 1,
                     soiUrl: '/' + r.soiId,
                    yesChecked: r.readiness === 'Yes',
                    noChecked: r.readiness === 'No',
                    hasBusinessProcess: !!r.hasBusinessProcess,
                    businessProcessUrl: r.businessProcessId ? '/' + r.businessProcessId : null,
                    __origReadiness: r.readiness || null,
                    __origComment: r.comment || ''
                };
            });
            this.businessProcessMessage = '';

            this.milestoneName = this.rows.length ? (this.rows[0].milestoneName || '') : '';
            this.draftById.clear();
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get hasRows() {
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    get totalInstallmentCount() {
        return this.rows.length;
    }

    get totalInstallmentAmount() {
        return this.rows.reduce((sum, r) => sum + (r.amount || 0), 0);
    }

    get totalCollectedAmount() {
        return this.rows.reduce((sum, r) => sum + (r.appliedAmount || 0), 0);
    }

    get totalOutstandingAmount() {
        return this.rows.reduce((sum, r) => sum + ((r.amount || 0) - (r.appliedAmount || 0)), 0);
    }

    get yesSelectedCount() {
        return this.rows.filter(r => r.yesChecked).length;
    }

    get noSelectedCount() {
        return this.rows.filter(r => r.noChecked).length;
    }

    get notSelectedCount() {
        return this.rows.filter(r => !r.yesChecked && !r.noChecked).length;
    }

    get changedCount() {
        return this.draftById.size;
    }

    get saveDisabled() {
        return this.isLoading || this.draftById.size === 0;
    }

    // --- handlers

    handleYesChange(event) {
        const soiId = event.target.dataset.id;
        const checked = event.target.checked;

        this.rows = this.rows.map(r => {
            if (r.soiId !== soiId) return r;

            const yesChecked = checked;
            const noChecked = checked ? false : r.noChecked;

            const readiness = yesChecked ? 'Yes' : (noChecked ? 'No' : null);

            const updated = { ...r, yesChecked, noChecked, readiness };
            this.upsertDraft(updated);
            return updated;
        });
    }

    handleNoChange(event) {
        const soiId = event.target.dataset.id;
        const checked = event.target.checked;

        this.rows = this.rows.map(r => {
            if (r.soiId !== soiId) return r;

            const noChecked = checked;
            const yesChecked = checked ? false : r.yesChecked;

            const readiness = noChecked ? 'No' : (yesChecked ? 'Yes' : null);

            const updated = { ...r, yesChecked, noChecked, readiness };
            this.upsertDraft(updated);
            return updated;
        });
    }

    handleCommentChange(event) {
        const soiId = event.target.dataset.id;
        const comment = event.target.value;

        this.rows = this.rows.map(r => {
            if (r.soiId !== soiId) return r;
            const updated = { ...r, comment };
            this.upsertDraft(updated);
            return updated;
        });
    }

    upsertDraft(row) {
        const original = this.getOriginalRow(row.soiId);
        if (!original) return;

        const origReadiness = original.readiness;
        const origComment = original.comment;

        const newReadiness = row.readiness || null;
        const newComment = row.comment || '';

        const isSame = (origReadiness === newReadiness) && (origComment === newComment);

        if (isSame) {
            this.draftById.delete(row.soiId);
        } else {
            this.draftById.set(row.soiId, {
                soiId: row.soiId,
                soiName: row.soiName,
                readiness: newReadiness,
                comment: newComment
            });
        }
    }

    getOriginalRow(soiId) {
        const r = this.rows.find(x => x.soiId === soiId);
        if (!r) return null;
        return {
            readiness: r.__origReadiness,
            comment: r.__origComment
        };
    }

    get rowsMissingNoComment() {
        return this.rows.filter(r => r.noChecked && !(r.comment || '').trim());
    }

    async handleSave() {
        if (this.draftById.size === 0) return;

        const missingComment = this.rowsMissingNoComment;
        if (missingComment.length > 0) {
            this.toast('Comment Required', `Comment is mandatory for installment(s) marked "No": ${missingComment.map(r => r.soiName).join(', ')}`, 'error');
            return;
        }

        try {
            this.isLoading = true;

            const payload = Array.from(this.draftById.values()).map(d => ({
                soiId: d.soiId,
                soiName: d.soiName,
                readiness: d.readiness,
                comment: d.comment
            }));

            await saveReadiness({ serviceRequestId: this.recordId, updates: payload });

            // Baseline the saved values so Save is disabled again until the next edit.
            this.rows = this.rows.map(r => ({
                ...r,
                __origReadiness: r.readiness || null,
                __origComment: r.comment || ''
            }));
            this.draftById.clear();

            this.toast('Saved', `Updated ${payload.length} installment(s).`, 'success');
        } catch (e) {
            this.toast('Save failed', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Only rows whose "No" is actually saved (matches __origReadiness) are eligible —
    // an unsaved "No" checked on screen doesn't count until Save persists it.
    get noRowIds() {
        return this.rows
            .filter(r => r.noChecked && r.__origReadiness === 'No' && !r.hasBusinessProcess)
            .map(r => r.soiId);
    }

    get noRowsPayload() {
        return this.rows
            .filter(r => r.noChecked && r.__origReadiness === 'No' && !r.hasBusinessProcess)
            .map(r => ({ soiId: r.soiId, comment: r.comment || '' }));
    }

    get hasEligibleNoRows() {
        return this.isProjectMilestoneConfirmation && this.noRowIds.length > 0;
    }

    async handleInitiateProcess() {
        const installments = this.noRowsPayload;
        if (installments.length === 0 || !this.isProjectMilestoneConfirmation) return;

        const missingComment = installments.filter(i => !(i.comment || '').trim());
        if (missingComment.length > 0) {
            this.toast('Comment Required', 'Comment is mandatory for all installment(s) marked "No" before initiating the process.', 'error');
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Initiate Installment Payment Confirmation Process',
            message: `Once confirmed, you will not be able to change these ${installments.length} installment(s) anymore, and a Business Process will be created for them. Do you want to continue?`,
            theme: 'warning'
        });
        if (!confirmed) return;

        try {
            this.isLoading = true;
            const processedCount = await initiateInstallmentPaymentConfirmation({
                installments,
                parentBusinessProcessId: this.recordId
            });

            const processedIds = new Set(installments.map(i => i.soiId));
            this.rows = this.rows.map(r =>
                processedIds.has(r.soiId) ? { ...r, hasBusinessProcess: true } : r
            );
            processedIds.forEach(id => this.draftById.delete(id));

            this.businessProcessMessage = `Business Process created for ${processedCount} installment(s).`;
            this.toast('Process Started', this.businessProcessMessage, 'success');
        } catch (e) {
            this.toast('Failed to Initiate', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // --- utils

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(e) {
        if (!e) return 'Unknown error';
        if (Array.isArray(e.body)) return e.body.map(x => x.message).join(', ');
        if (typeof e.body?.message === 'string') return e.body.message;
        if (typeof e.message === 'string') return e.message;
        return JSON.stringify(e);
    }

    handleFileChange(event) {

    const file = event.target.files[0];

    if (!file) return;

    const fileName = file.name.toLowerCase();

    if (fileName.endsWith('.csv')) {
        this.readCSV(file);
    }
    else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        this.readExcel(file);
    }
    else {
        this.toast('Invalid File','Please upload CSV or Excel file','error');
    }
}
readCSV(file) {

    const reader = new FileReader();

    reader.onload = () => {

        const text = reader.result;

        const rows = this.parseCSV(text);

        this.applyFileUpdates(rows);
    };

    reader.readAsText(file);
}
readExcel(file) {


    const reader = new FileReader();

    reader.onload = (event) => {

        try {

            const data = new Uint8Array(event.target.result);


            const workbook = window.XLSX.read(data, { type: 'array' });


            const sheetName = workbook.SheetNames[0];


            const worksheet = workbook.Sheets[sheetName];

            const rows = window.XLSX.utils.sheet_to_json(worksheet);


            this.applyFileUpdates(rows);

        } catch (error) {

            console.error('Excel parsing error:', error);

        }

    };

    reader.readAsArrayBuffer(file);
}
parseCSV(csv) {

    const lines = csv.split('\n').map(l => l.trim()).filter(l => l);

    const headers = lines[0].split(',').map(h => h.trim());

    const records = [];

    for (let i = 1; i < lines.length; i++) {

        const values = lines[i].split(',').map(v => v.trim());

        let record = {};

        headers.forEach((header, index) => {
            record[header] = values[index] || '';
        });

        records.push(record);
    }

    return records;
}
applyFileUpdates(fileRows) {


    let updateCount = 0;

    const updatedRows = this.rows.map(row => {


        // Find matching Excel row
        const match = fileRows.find(r => {

            if (!r.SOI) {
                return false;
            }

            const excelSOI = r.SOI.toString().trim().toLowerCase();
            const tableSOI = row.soiName ? row.soiName.toString().trim().toLowerCase() : '';


            return excelSOI === tableSOI;
        });

        if (!match || row.hasBusinessProcess) {
            return row;
        }

        let readinessValue = '';

        if (match.Readiness) {
            readinessValue = match.Readiness.toString().trim().toLowerCase();
        }


        let yesChecked = false;
        let noChecked = false;

        if (readinessValue === 'yes') {
            yesChecked = true;
        }
        else if (readinessValue === 'no') {
            noChecked = true;
        }

        const comment = match.Comments ? match.Comments.toString() : '';


        const updatedRow = {
            ...row,
            yesChecked: yesChecked,
            noChecked: noChecked,
            readiness: yesChecked ? 'Yes' : (noChecked ? 'No' : null),
            comment: comment
        };


        this.upsertDraft(updatedRow);

        updateCount++;

        return updatedRow;
    });

    // Important: reassign array to refresh UI
    this.rows = [...updatedRows];


    if (updateCount === 0) {
        this.toast(
            'No Match',
            'No SOI values matched the uploaded file',
            'warning'
        );
    } else {
        this.toast(
            'Success',
            updateCount + ' rows updated from Excel',
            'success'
        );
    }
}
handleDownloadExcel() {

    if (!this.rows || this.rows.length === 0) {

        this.toast(
            'No Data',
            'No installments available to download',
            'warning'
        );

        return;

    }

    try {


        const data = this.rows.map(row => {

            return {

                SOI: row.soiName,
                'Sales Order': row.salesOrderName,
                'Unit Name': row.unitName,
                'Customer': row.customerName,
                'Nationality': row.nationality,
                'Resident Status': row.uaeresidentstatus,   
                'Due Date': row.dueDate,
                'Amount': row.amount,
                'Applied Amount': row.appliedAmount,
                'Mode of Payment': row.modeOfPayment,

                Readiness:
                    row.yesChecked
                        ? 'Yes'
                        : row.noChecked
                            ? 'No'
                            : '',

                Comments:
                    row.comment || ''

            };

        });


        const worksheet =
            window.XLSX.utils.json_to_sheet(data);

        const workbook =
            window.XLSX.utils.book_new();

        window.XLSX.utils.book_append_sheet(
            workbook,
            worksheet,
            'Payment Readiness'
        );

        const fileName =
            'Payment_Readiness_Template.xlsx';

        window.XLSX.writeFile(
            workbook,
            fileName
        );

        this.toast(
            'Success',
            'Excel file downloaded',
            'success'
        );

    }
    catch (error) {

        console.error(
            'Download Excel error',
            error
        );

        this.toast(
            'Error',
            'Failed to generate Excel file',
            'error'
        );

    }

}
handleUploadClick() {
   const fileInput = this.template.querySelector('.fileInput');
if(fileInput){
    fileInput.click();
}
}
}