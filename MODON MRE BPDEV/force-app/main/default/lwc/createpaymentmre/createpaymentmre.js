/**
 * @description  Controller for createPaymentMRE LWC.
 *
 * Key behaviours
 * ──────────────────────────────────────────────────────────────
 *  • On load:  fetches EOI details (amount from EOI_Amount_AED__c, preferred payment).
 *              Pre-selects Mode of Payment from EOI.Preferred_Payment__c.
 *  • Account:  NOT sent from UI — set server-side from Custom Label.
 *  • Upload:   required for Cheque and POS; validated before save.
 *  • Duplicate / doc-missing banners block the form before save is tried.
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }                          from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo }        from 'lightning/uiObjectInfoApi';
import RECEIPT_OBJECT                              from '@salesforce/schema/Receipt__c';
import BANK_FIELD                                  from '@salesforce/schema/Receipt__c.Bank__c';
import getEOIDetails                               from '@salesforce/apex/PaymentReceiptController.getEOIDetails';
import validateBeforePayment                       from '@salesforce/apex/PaymentReceiptController.validateBeforePayment';
import createPaymentAndSubmit                      from '@salesforce/apex/PaymentReceiptController.createPaymentAndSubmit';

// ─── helpers ─────────────────────────────────────────────────────────────
const todayISO = () => new Date().toISOString().slice(0, 10);
const nowHHMM  = () => {
    const d = new Date();
    return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
};

const EMPTY_FORM = () => ({
    modeOfPayment     : '',
    amount            : null,
    // Cheque
    chequeNumber      : '',
    chequeDate        : '',
    bankValue         : '',        // picklist value — Receipt__c.Bank__c
    // POS / Online / Bank Transfer
    transactionNumber : '',
    transactionDate   : todayISO(),
    transactionTime   : nowHHMM(),
    // POS / Bank Transfer
    last4Digit        : ''
});

export default class CreatePaymentMRE extends LightningElement {

    // ── Public — recordId setter ensures load fires only after ID is set ─────
    //    In Quick Actions, @api props arrive AFTER connectedCallback, so a
    //    plain @api + connectedCallback always fires with recordId = undefined.
    _recordId;

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value) { this._loadEOIAndValidate(); }
    }

    // ── Status flags ─────────────────────────────────────────────────────
    @track isLoading             = true;
    @track isSuccess             = false;
    @track hasError              = false;
    @track isDuplicate           = false;
    @track isDocsMissing         = false;
    @track showFileRequiredError = false;

    // ── Messages ──────────────────────────────────────────────────────────
    @track successMessage     = '';
    @track errorMessage       = '';
    @track duplicateMessage   = '';
    @track docsMissingMessage = '';

    // ── EOI read-only display ─────────────────────────────────────────────
    @track eoiName         = '';
    @track opportunityName = '';

    // ── Amount editability — true only for Allow_Duplicate_Payment_for_EOI ─
    @track canEditAmount   = false;

    // ── Picklist options — wired directly from Receipt__c.Bank__c schema ────
    @track bankOptions = [];

    // Wire: object info needed to get the default record type Id
    @wire(getObjectInfo, { objectApiName: RECEIPT_OBJECT })
    _receiptObjectInfo;

    // Wire: Bank__c picklist values from Receipt__c — no Apex required
    @wire(getPicklistValues, {
        recordTypeId : '$_receiptObjectInfo.data.defaultRecordTypeId',
        fieldApiName : BANK_FIELD
    })
    wiredBankPicklist({ data, error }) {
        if (data) {
            this.bankOptions = [
                { label: '--None--', value: '' },
                ...data.values.map(v => ({ label: v.label, value: v.value }))
            ];
        } else if (error) {
            console.error('Bank picklist wire error:', error);
        }
    }

    // ── Form state ────────────────────────────────────────────────────────
    @track formData = EMPTY_FORM();

    // ── Uploaded file tracking ────────────────────────────────────────────
    _uploadedDocIds = [];

    // ══════════════════════════════════════════════════════════════════════
    // GETTERS
    // ══════════════════════════════════════════════════════════════════════
    get paymentModeOptions() {
        return [
            { label: 'Cheque',        value: 'Cheque'        },
            { label: 'POS',           value: 'POS'           },
            { label: 'Online',        value: 'Online'        },
            { label: 'Bank Transfer', value: 'Bank Transfer' }
        ];
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];
    }

    get isCheque()       { return this.formData.modeOfPayment === 'Cheque';        }
    get isPOS()          { return this.formData.modeOfPayment === 'POS';           }
    get isOnline()       { return this.formData.modeOfPayment === 'Online';        }
    get isBankTransfer() { return this.formData.modeOfPayment === 'Bank Transfer'; }

    /** Amount is editable only for users with Allow_Duplicate_Payment_for_EOI */
    get isAmountReadonly() { return !this.canEditAmount; }

    /** File upload is mandatory for Cheque and POS */
    get isFileRequired() { return this.isCheque || this.isPOS; }

    /** Hide the entire form once a duplicate is confirmed or save succeeded */
    get hideForm() { return this.isDuplicate || this.isSuccess; }

    /** Grey out all form inputs while signed docs are missing */
    get isFormDisabled() { return this.isDocsMissing; }

    /** CSS class for the form grid — adds disabled overlay when docs missing */
    get formGridClass() {
        return this.isDocsMissing
            ? 'mre-form-grid mre-form-grid--disabled'
            : 'mre-form-grid';
    }

    get isSaveDisabled()   { return this.isLoading || !this.formData.modeOfPayment || this.isFormDisabled; }
    get hasUploadedFiles() { return this._uploadedDocIds.length > 0;                }
    get uploadedFileCount(){ return this._uploadedDocIds.length;                    }

    // ══════════════════════════════════════════════════════════════════════
    // DATA LOADING
    // ══════════════════════════════════════════════════════════════════════
    async _loadEOIAndValidate() {
        this.isLoading = true;
        this._clearAlerts();

        try {
            // Load EOI header — Amount (EOI_Amount_AED__c) and Preferred_Payment__c
            // Bank options are populated automatically via @wire(getPicklistValues)
            const eoi = await getEOIDetails({ eoiId: this.recordId });

            this.eoiName         = eoi.eoiName;
            this.opportunityName = eoi.opportunityName;
            this.canEditAmount   = eoi.hasAllowDuplicatePermission === true;

            // Pre-select mode of payment from EOI.Preferred_Payment__c
            // Amount is read-only, sourced exclusively from EOI.EOI_Amount_AED__c
            this.formData = {
                ...EMPTY_FORM(),
                amount        : eoi.amount,          // EOI_Amount_AED__c
                modeOfPayment : eoi.preferredPayment || ''
            };

            // Server-side validation (docs missing / duplicate)
            const v = await validateBeforePayment({ eoiId: this.recordId });
            if (!v.isValid) { this._applyValidationResult(v); }

        } catch (err) {
            this.hasError     = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // EVENT HANDLERS
    // ══════════════════════════════════════════════════════════════════════
    handleModeChange(event) {
        this.formData = {
            ...EMPTY_FORM(),
            amount        : this.formData.amount,
            modeOfPayment : event.detail.value
        };
        this.showFileRequiredError = false;
        this._clearAlerts();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData = { ...this.formData, [field]: event.detail.value };
    }

    handleUploadFinished(event) {
        event.detail.files.forEach(f => {
            if (f.documentId && !this._uploadedDocIds.includes(f.documentId)) {
                this._uploadedDocIds.push(f.documentId);
            }
        });
        this._uploadedDocIds = [...this._uploadedDocIds];
        if (this._uploadedDocIds.length > 0) {
            this.showFileRequiredError = false;
        }
    }

    async handleSave() {
        // 1. Client-side field validation
        if (!this._reportValidity()) return;

        this.isLoading = true;
        this._clearAlerts();

        try {
            // 2. Re-run server-side validation just before DML
            const v = await validateBeforePayment({ eoiId: this.recordId });
            if (!v.isValid) {
                this._applyValidationResult(v);
                return;
            }

            // 3. Build payload  (Account__c is NOT sent — set server-side)
            const payload = {
                eoiId             : this.recordId,
                modeOfPayment     : this.formData.modeOfPayment,
                amount            : this.formData.amount,
                // Cheque
                chequeNumber      : this.formData.chequeNumber   || null,
                chequeDate        : this.formData.chequeDate     || null,
                bankValue         : this.formData.bankValue      || null,
                // POS / Bank Transfer / Online
                transactionNumber : this.formData.transactionNumber || null,
                transactionDate   : this.formData.transactionDate   || null,
                // POS / Bank Transfer
                last4Digit        : this.formData.last4Digit     || null
            };

            // 4. Call Apex
            const result = await createPaymentAndSubmit({
                paymentJSON        : JSON.stringify(payload),
                contentDocumentIds : this._uploadedDocIds
            });

            if (result.isSuccess) {
                this.isSuccess     = true;
                this.successMessage = result.message;
                this._fire('paymentsuccess', { receiptId: result.receiptId });
                this._toast('Payment Created', result.message, 'success');
            } else {
                this._applyValidationResult(result);
            }

        } catch (err) {
            this.hasError     = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ══════════════════════════════════════════════════════════════════════
    _reportValidity() {
        // Run HTML5 validation on all inputs and comboboxes
        const inputs = [
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-combobox')
        ];
        const fieldsValid = inputs.reduce((valid, el) => {
            el.reportValidity();
            return valid && el.checkValidity();
        }, true);

        // File upload — required for Cheque and POS
        let fileValid = true;
        if (this.isFileRequired && this._uploadedDocIds.length === 0) {
            this.showFileRequiredError = true;
            fileValid = false;
        } else {
            this.showFileRequiredError = false;
        }

        return fieldsValid && fileValid;
    }

    _applyValidationResult(v) {
        const type = v.errorType || '';
        if (type === 'DUPLICATE') {
            this.isDuplicate      = true;
            this.duplicateMessage = v.message;
        } else if (type === 'DOCS_MISSING') {
            this.isDocsMissing      = true;
            this.docsMissingMessage = v.message;
        } else {
            this.hasError     = true;
            this.errorMessage = v.message;
        }
    }

    _clearAlerts() {
        this.hasError         = false;
        this.errorMessage     = '';
        this.isDocsMissing    = false;
        this.docsMissingMessage = '';
        // isDuplicate intentionally kept once set — cannot un-duplicate
    }

    _extractError(err) {
        return (err && err.body && err.body.message)
            ? err.body.message
            : (err.message || 'An unexpected error occurred.');
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _fire(name, detail = {}) {
        this.dispatchEvent(
            new CustomEvent(name, { detail, bubbles: true, composed: true })
        );
    }
}