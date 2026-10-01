import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getCurrentSalesOrderStatus from '@salesforce/apex/ADMWaiverController.admWaiverUpdate';
import saveWaiver from '@salesforce/apex/ADMWaiverController.saveWaiver';
import getAdmPaymentStatus from '@salesforce/apex/ADMWaiverController.getAdmPaymentStatus';

import DARI_AMOUNT from '@salesforce/schema/SalesOrder__c.Daricharges__c';
import TOTAL_AMOUNT_FIELD from '@salesforce/schema/SalesOrder__c.TotalAmount__c';
import checkRelatedCharges from '@salesforce/apex/ADMWaiverController.checkRelatedCharges';
const FIELDS = [TOTAL_AMOUNT_FIELD, DARI_AMOUNT];
const MAX_FILE_SIZE = 15000000;

export default class Admwaiverupdate extends LightningElement {
    @api recordId;

    showDialog = false;
    @track waiverpercent = '';
    @track waiverMemo = '';
    @track uploadedFiles = [];
    @track isSaving = false;
    @track isReadingFiles = false;
    @track waiverMemoNumber = '';
    @track admPaymentStatus = '';
    @track applyDariWaiver = '';
    @track totalAmount = 0;
    @track calculationReady = true;
    @track DARI_WAIVER_FIXED_AMOUNT = 499;

    /** 5.0 Arvind Kesharwani 10/05/2026 - Track selected waiver type: 'ADM' or 'OnlyDari' **/
    @track waiverType = '';

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        if (reccId) {
            this.recordId = reccId;
        }

        /** 4.0 NEW: Initial check for required Charges before proceeding **/
        this.validateChargesAndStatus();
    }

    /** 4.0 NEW: Combined validation logic **/
    async validateChargesAndStatus() {
        try {
            const hasRequiredCharges = await checkRelatedCharges({ salesOrderId: this.recordId });
            
            if (!hasRequiredCharges) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Requirement Missing',
                        message: 'No related Charges of type ADM and Dari Fee found. Please ensure these charges exist before creating an Offer.',
                        variant: 'error'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
                return;
            }

            // If charges exist, proceed with original status check
            this.handleWaiverUpdate();
            this.fetchAdmPaymentStatus();

        } catch (error) {
            console.error('Validation Error:', error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredSalesOrder({ data, error }) {
        if (data) {
            this.totalAmount = data.fields.TotalAmount__c?.value || 0;
            this.DARI_WAIVER_FIXED_AMOUNT = data.fields.Daricharges__c?.value || 0;
        } else if (error) {
            console.error('Error fetching SalesOrder fields:', error);
            this.totalAmount = 0;
            this.DARI_WAIVER_FIXED_AMOUNT = 0;
        }
    }

    handleWaiverUpdate() {
        getCurrentSalesOrderStatus({ salesOrderId: this.recordId })
            .then((result) => {
                if (result === 'Waiver') {
                    this.showDialog = true;
                } else if (result === 'No Waiver') {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Info',
                            message: 'Sales Order is not in Waiver status.',
                            variant: 'info'
                        })
                    );
                } else if (result === 'Error') {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'An error occurred please recheck your Invoice and get in touch with System Admin.',
                            variant: 'error'
                        })
                    );
                }
            })
            .catch((error) => {
                console.error('Error fetching Sales Order status: ', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'An error occurred while fetching the Sales Order status.',
                        variant: 'error'
                    })
                );
            });
    }

    fetchAdmPaymentStatus() {
        getAdmPaymentStatus({ salesOrderId: this.recordId })
            .then(result => {
                this.admPaymentStatus = result || '';
            })
            .catch(error => {
                console.error('Error fetching ADM Payment Status:', error);
            });
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.xls', '.xlsx'];
    }

    get acceptedFormatsString() {
        return this.acceptedFormats.join(',');
    }

    get dariWaiverOptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Waiver type options: ADM Fee Waiver or Only Dari Fee **/
    get waiverTypeOptions() {
        return [
            { label: 'Select Waiver Type', value: '' },
            { label: 'ADM Fee Waiver', value: 'ADM' },
            { label: 'Only Dari Fee', value: 'OnlyDari' }
        ];
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Show ADM fields only when waiver type is ADM **/
    get showADMFields() {
        return this.waiverType === 'ADM';
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Show Only Dari Fee info block when waiver type is OnlyDari **/
    get showOnlyDariFields() {
        return this.waiverType === 'OnlyDari';
    }

    get showDariWaiverField() {
        return this.waiverType === 'ADM' && Number(this.waiverpercent) === 2;
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Formatted Dari Fee amount for read-only display in Only Dari Fee mode **/
    get formattedDariChargesAmount() {
        return this.formatCurrency(this.DARI_WAIVER_FIXED_AMOUNT);
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Handle waiver type selection change; reset dependent fields **/
    handleWaiverTypeChange(e) {
        this.waiverType = e.detail.value;
        this.waiverpercent = '';
        this.applyDariWaiver = '';
    }

    waiverpercentChange(e) {
        this.waiverpercent = e.target.value ? String(e.target.value).trim() : '';

        if (!this.showDariWaiverField) {
            this.applyDariWaiver = '';
        }

        this.calculationReady = !(this.waiverpercent && Number(this.waiverpercent) > 2);
    }

    handleDariWaiverChange(e) {
        this.applyDariWaiver = e.detail.value;
    }

    handleMemoChange(e) {
        this.waiverMemo = e.target.value?.trim() || '';
    }

    handleWaiverMemoNumberChange(e) {
        this.waiverMemoNumber = e.target.value?.trim() || '';
    }

    async handleFileChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            this.uploadedFiles = [];
            return;
        }

        this.isReadingFiles = true;

        try {
            const uploadedFileData = await Promise.all(
                Array.from(files).map(file => this.readFileAsBase64(file))
            );

            this.uploadedFiles = [...uploadedFileData];
        } catch (error) {
            console.error('File read error:', error);
            this.uploadedFiles = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'File Upload Error',
                    message: error.message || 'Unable to process selected file(s).',
                    variant: 'error'
                })
            );
        } finally {
            this.isReadingFiles = false;
        }
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const fileExtension = '.' + file.name.split('.').pop().toLowerCase();

            if (!this.acceptedFormats.includes(fileExtension)) {
                reject(new Error(`File type not allowed: ${file.name}`));
                return;
            }

            if (file.size > MAX_FILE_SIZE) {
                reject(new Error(`File too large: ${file.name}. Maximum allowed size is 15 MB.`));
                return;
            }

            const reader = new FileReader();

            reader.onload = () => {
                const result = reader.result;
                if (!result || !result.includes(',')) {
                    reject(new Error(`Failed to process file: ${file.name}`));
                    return;
                }

                const base64 = result.split(',')[1];

                resolve({
                    fileName: file.name,
                    base64Data: base64,
                    contentType: file.type || 'application/octet-stream'
                });
            };

            reader.onerror = () => {
                reject(new Error(`Failed to read file: ${file.name}`));
            };

            reader.readAsDataURL(file);
        });
    }

    get admDiscountAmount() {
        /** 5.0 Arvind Kesharwani 10/05/2026 - No ADM discount for Only Dari Fee type **/
        if (this.waiverType === 'OnlyDari') return 0;
        const total = Number(this.totalAmount) || 0;
        const percent = Number(this.waiverpercent) || 0;
        return (total * percent) / 100;
    }

    get dariWaiverAmount() {
        /** 5.0 Arvind Kesharwani 10/05/2026 - For Only Dari Fee, always return full Daricharges__c amount **/
        if (this.waiverType === 'OnlyDari') {
            return Number(this.DARI_WAIVER_FIXED_AMOUNT || 0);
        }
        return this.showDariWaiverField && this.applyDariWaiver === 'Yes'
            ? Number(this.DARI_WAIVER_FIXED_AMOUNT || 0)
            : 0;
    }

    get totalWaiverAmount() {
        return this.admDiscountAmount + this.dariWaiverAmount;
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Calculation panel ready when:
     *       OnlyDari type (always ready), or ADM type with a valid % (1–2) **/
    get calculationReady() {
        if (this.waiverType === 'OnlyDari') return true;
        if (!this.waiverpercent) return false;
        return Number(this.waiverpercent) >= 1 && Number(this.waiverpercent) <= 2;
    }

    get formattedTotalAmount() {
        return this.formatCurrency(this.totalAmount);
    }

    get formattedAdmDiscount() {
        return this.formatCurrency(this.admDiscountAmount);
    }

    get formattedDariWaiverAmount() {
        return this.formatCurrency(this.dariWaiverAmount);
    }

    get formattedTotalWaiverAmount() {
        return this.formatCurrency(this.totalWaiverAmount);
    }

    get displayWaiverPercent() {
        return this.waiverpercent ? `${this.waiverpercent}%` : '0%';
    }

    formatCurrency(value) {
        const amount = Number(value) || 0;
        return new Intl.NumberFormat('en-AE', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(amount) + ' AED';
    }

    /** 5.0 Arvind Kesharwani 10/05/2026 - Save is disabled until a waiver type is chosen;
     *       ADM type also requires waiverpercent; Only Dari Fee does not **/
    get saveDisabled() {
        if (!this.waiverType || !this.waiverMemo || !this.recordId) return true;
        if (this.waiverType === 'ADM' && !this.waiverpercent) return true;
        return this.isSaving || this.isReadingFiles;
    }

    async handleSave() {
        if (this.isReadingFiles) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Please wait',
                    message: 'Files are still being processed.',
                    variant: 'warning'
                })
            );
            return;
        }

        if (this.saveDisabled) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing required info',
                    message: 'Please select a Waiver Type, provide a Waiver Reason' +
                             (this.waiverType === 'ADM' ? ', and enter a Waiver Percentage.' : '.'),
                    variant: 'error'
                })
            );
            return;
        }

        this.isSaving = true;

        try {
            const payload = this.uploadedFiles.map(file => ({
                fileName: file.fileName,
                base64Data: file.base64Data,
                contentType: file.contentType
            }));

            /** 5.0 Arvind Kesharwani 10/05/2026 - Derive params for Only Dari Fee:
             *       waiverpercent = 0, applyDariWaiver = 'Yes', onlyDariFee = true **/
            const isOnlyDari = this.waiverType === 'OnlyDari';

            const result = await saveWaiver({
                parentRecordId    : this.recordId,
                waiverpercent     : isOnlyDari ? 0 : this.waiverpercent,
                waiverMemo        : this.waiverMemo,
                waiverMemoNumber  : this.waiverMemoNumber,
                applyDariWaiver   : isOnlyDari ? 'Yes' : this.applyDariWaiver,
                dariWaiverAmount  : this.dariWaiverAmount,
                admDiscountAmount : this.admDiscountAmount,
                totalWaiverAmount : this.totalWaiverAmount,
                filesDataJson     : JSON.stringify(payload),
                onlyDariFee       : isOnlyDari   /** 5.0 Arvind Kesharwani 10/05/2026 **/
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: result?.message || 'Waiver saved successfully.',
                    variant: 'success'
                })
            );

            this.waiverType       = '';
            this.waiverpercent    = '';
            this.waiverMemo       = '';
            this.waiverMemoNumber = '';
            this.applyDariWaiver  = '';
            this.uploadedFiles    = [];

            const fileInput = this.template.querySelector('lightning-input[type="file"]');
            if (fileInput) {
                fileInput.value = null;
            }

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            let msg = 'An unexpected error occurred.';
            if (err?.body?.message) {
                msg = err.body.message;
            } else if (err?.message) {
                msg = err.message;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error saving waiver',
                    message: msg,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }
}