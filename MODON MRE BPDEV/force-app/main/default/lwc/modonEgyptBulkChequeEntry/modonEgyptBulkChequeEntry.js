/**
* @description       : Lightning Web Component to Create Bulk Cheque Receipts for Sales Order
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 05-02-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2026   Milin Kapatel      Initial Version
* 1.1   11-02-2026  Milin Kapatel       Made Customer Bank Dynamic and Added validation to approval action - only those rows can be approved/rejected which have data populated in all required fields
* 1.2   18-02-2026  Milin Kapatel       Added feature to apply initial cheque number with incremental numbering and leading zero preservation and spinner in starting while fetching data
**/
import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import loadActiveCurrency from '@salesforce/apex/Modon_Egypt_BulkChequeEntryController.loadActiveCurrency';
import getBulkChequeEntries from '@salesforce/apex/Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries';
import updateChequeEntries from '@salesforce/apex/Modon_Egypt_BulkChequeEntryController.updateChequeEntries';
import insertReceipts from '@salesforce/apex/Modon_Egypt_BulkChequeEntryController.insertReceipts';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CHEQUE_ENTRY_OBJECT from '@salesforce/schema/Cheque_Entry__c';
import MIRE_BANK from '@salesforce/schema/Cheque_Entry__c.MIRE_Bank__c';
import CUSTOMER_BANK from '@salesforce/schema/Cheque_Entry__c.Customer_Bank__c';
import hasBulkChequeChecker from '@salesforce/customPermission/Modon_Egypt_Bulk_Cheque_Checker_Permission';
import hasBulkChequeMaker from '@salesforce/customPermission/Modon_Egypt_Bulk_Cheque_Maker_Permission';


const APPROVAL_ACTION_OPTIONS = [
    { label: 'Approved', value: 'Approved' },
    { label: 'Rejected', value: 'Rejected' }
];
const STATUSES_TO_ALLOW_EDITING = ['Rejected'];
const STATUSES_TO_ALLOW_APPROVAL_ACTION = ['Approval Pending', 'Re-submitted'];

export default class ModonEgyptBulkChequeEntry extends LightningElement {
    @api recordId;

    loadingScreen = true;
    salesOrderName;
    accountId;
    allReceiptsCreated;

    currencyOptions = [];
    customerBankOptions = [];
    mireBankOptions = []

    disabledSaveButton = true;

    selectedCustomerBank = '';
    selectedCurrency = '';
    selectedMIREBank = '';
    inputInitialChequeNumber = '';
    inputTillRow = '';

    get isApplyInitialChequeBtnDisabled() {
        return !(this.inputInitialChequeNumber && this.inputTillRow);
    }

    debouncers = {};

    selectedRecordId = null;
    selectedUniqueKey = null;

    isSubmitionScreen = false;

    columns = [
        { label: 'Milestone Description', fieldName: 'milestoneDescription', type: 'text', sortable: false, initialWidth: 150 },
        { label: 'Name', fieldName: 'Name', type: 'text', sortable: false, initialWidth: 150 },
        { label: 'Cheque Amount', fieldName: 'chequeAmount', type: 'currency', cellAttributes: { alignment: 'left' }, typeAttributes: { currencyCode: { fieldName: 'currency' }, step: '0.01' }, sortable: false, initialWidth: 150 },
        { label: 'Receipt Type', fieldName: 'receiptType', type: 'text', sortable: false, initialWidth: 150 },
        {
            label: 'Cheque Number', fieldName: 'chequeNumber', type: 'text', editable: { fieldName: 'allowEditing' }, cellAttributes: {
                editable: { fieldName: 'allowEditing' }
            }, initialWidth: 150
        },
        {
            label: 'Cheque Due Date', fieldName: 'chequeDueDate', type: 'date-local', editable: { fieldName: 'allowEditing' }, cellAttributes: {
                editable: { fieldName: 'allowEditing' }
            }, initialWidth: 150
        },
        //v1.1 Dynamic Customer Bank Picklist
        {
            label: 'Customer Bank', fieldName: 'customerBank', type: 'picklist', typeAttributes: {
                placeholder: 'Select Customer Bank',
                field: "customerBank",
                editable: { fieldName: 'allowEditing' },
                options: this.customerBankOptions,
                value: { fieldName: 'customerBank' },
                context: { fieldName: 'Id' },
            },
            editable: { fieldName: 'allowEditing' },
            initialWidth: 350
        },
        {
            label: 'MIRE Bank', fieldName: 'mireBank', type: 'text', initialWidth: 150
        },
        {
            label: 'Files', fieldName: 'files', type: 'fileupload', initialWidth: 300, typeAttributes: {
                formats: ".pdf,.png,.jpeg,.jpg,.bmp,.gif,.webp,.tiff,.txt,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.csv",
                recordId: { fieldName: 'Id' },
            }
        },
        {
            label: 'Approval Status', fieldName: 'approvalStatus', type: 'picklist', typeAttributes: {
                placeholder: 'Select Action',
                field: "approvalStatus",
                editable: { fieldName: 'approvalFieldsEditable' },
                options: APPROVAL_ACTION_OPTIONS,
                value: { fieldName: 'approvalStatus' },
                context: { fieldName: 'Id' },
            },
            editable: { fieldName: 'approvalFieldsEditable' },
            initialWidth: 200
        },
        {
            label: 'Rejection Comments', fieldName: 'rejectionComments', type: 'textArea',
            editable: { fieldName: 'approvalFieldsEditable' }, initialWidth: 300
        }
    ];

    rows = [];
    rowIds = [];
    rowsToSubmit = [];
    wiredError;
    notAllApproved = true;

    // wiredChequeEntriesResult;
    chequeEntries;
    chequeEntryRefresh;
    chequeEntryData;

    sortedBy = 'Name';
    sortedDirection = 'asc';
    draftValues = [];

    get isScreenLoading() {
        return this.loadingScreen;
    }

    set isScreenLoading(value) {
        this.loadingScreen = value;
    }

    get isUserChecker() {
        return hasBulkChequeChecker;
    }
    get isUserMaker() {
        return hasBulkChequeMaker;
    }

    get submitForApprovalBtnVisibility() {
        return (this.isUserChecker || this.isUserMaker) && this.notAllApproved;
    }

    get approveAllBtnVisibility() {
        return this.isUserChecker && this.notAllApproved;
    }

    get createReceiptRecordsBtnVisibility() {
        return !this.notAllApproved && !this.allReceiptsCreated;
    }

    get rowsToDisplay() {

        if (this.rows && this.rows.length) {
            return this.rows;
        }
        return [];
    }

    get BulkChequeEntryModalheader() {
        return 'Create Bulk Cheque Entry (' + this.salesOrderName + ')';
    }

    connectedCallback() {
        this.loadChequeEntries();
    }

    loadChequeEntries() {
        getBulkChequeEntries({ soId: this.recordId })
            .then(result => {

                const data = result;
                const tempRows = [];
                if (data && data.length) {
                    this.selectedCurrency = data[0].CurrencyIsoCode ? data[0].CurrencyIsoCode : this.selectedCurrency;
                    this.salesOrderName = data[0].Sales_Order__r?.Name ? data[0].Sales_Order__r.Name : undefined;
                    this.selectedMIREBank = data[0].MIRE_Bank__c ? data[0].MIRE_Bank__c : '';
                    this.accountId = data[0].Sales_Order__r?.Opportunity__r?.AccountId ? data[0].Sales_Order__r?.Opportunity__r?.AccountId : '';
                    data.forEach(ce => {
                        tempRows.push({
                            allowEditing: ce.Cheque_Amount__c > 0 && (this.isUserChecker || this.isUserMaker),
                            //v1.1 approval action only allowed when all required fields have values
                            approvalFieldsEditable: this.isUserChecker && ce.Cheque_Amount__c > 0 && ce.Cheque_Number__c && ce.Cheque_Due_Date__c && ce.Customer_Bank__c && ce.MIRE_Bank__c,
                            approvalStatus: ce.Approval_Status__c || '',
                            rejectionComments: ce.Rejection_Comments__c || '',
                            Id: ce.Id,
                            soId: ce.Sales_Order_Installment__c,
                            Name: ce.Sales_Order_Installment__r.Name,
                            milestoneDescription: ce.Sales_Order_Installment__r.MilestoneDescription__c,
                            chequeAmount: ce.Cheque_Amount__c,
                            receiptType: ce.Receipt_Type__c,
                            chequeNumber: ce.Cheque_Number__c,
                            chequeDueDate: ce.Cheque_Due_Date__c,
                            customerBank: ce.Customer_Bank__c,
                            mireBank: ce.MIRE_Bank__c,
                            uniqueKey: ce.Id + '_' + ce.Receipt_Type__c,
                            invoiceId: ce.Invoice__c,
                            currency: ce.CurrencyIsoCode,
                            receiptCreated: ce.Receipt_Created__c,
                            fileNames: ce.ContentDocumentLinks && ce.ContentDocumentLinks.length ? ce.ContentDocumentLinks.map(link => link.ContentDocument.Title).join(', ') : null,
                            filesActionLabel: ce.ContentDocumentLinks && ce.ContentDocumentLinks.length ? ce.ContentDocumentLinks.map(link => link.ContentDocument.Title).join(', ') : 'Upload Files',
                            filesActionVariant: ce.ContentDocumentLinks && ce.ContentDocumentLinks.length ? 'base' : 'outline-brand',
                            filesActionTitle: ce.ContentDocumentLinks && ce.ContentDocumentLinks.length ? ce.ContentDocumentLinks.map(link => link.ContentDocument.Title).join(', ') : 'Upload Files',
                            filesActionDisabled: ce.ContentDocumentLinks && ce.ContentDocumentLinks.length ? true : false,
                            isInitialScreen: true // all rows editable on initial screen
                        });
                    });
                    if (tempRows.length) {
                        this.rows = [...tempRows];
                    }
                    this.rowIds = this.rows.map(r => r.Id);

                    this.notAllApproved = this.rows.some(row => row.approvalStatus != 'Approved' && row.chequeAmount > 0);
                    this.allReceiptsCreated = !this.rows.some(row => !row.receiptCreated);

                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load existing Cheque Entries', variant: 'error', mode: 'sticky' }));
            });
    }

    @wire(loadActiveCurrency)
    wiredCurrencyList({ data, error }) {
        if (data) {
            this.currencyOptions = data;
            this.selectedCurrency = !this.selectedCurrency && data && data.length ? data[0].value : this.selectedCurrency;

        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load Currency ISO Codes', variant: 'error', mode: 'sticky' }));
        }
    }

    @wire(getObjectInfo, { objectApiName: CHEQUE_ENTRY_OBJECT })
    chequeEntryObject;

    @wire(getPicklistValues, { recordTypeId: '$chequeEntryObject.data.defaultRecordTypeId', fieldApiName: CUSTOMER_BANK })
    wiredCustomerBankPicklistValues({ data, error }) {
        if (data) {

            this.customerBankOptions = data.values;
            this.selectedCustomerBank = '';
            //v1.1 Set picklist options in datatable column definition
            this.columns.find(col => col.fieldName === 'customerBank').typeAttributes.options = this.customerBankOptions;
            this.isScreenLoading = false;
        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error fetching picklist values', message: 'Not able to fetch Customer Bank picklist values', variant: 'error', mode: 'sticky' }));
        }
    };

    @wire(getPicklistValues, { recordTypeId: '$chequeEntryObject.data.defaultRecordTypeId', fieldApiName: MIRE_BANK })
    wiredMIREBankPicklistValues({ data, error }) {
        if (data) {

            this.mireBankOptions = data.values;
            this.selectedMIREBank = '';
        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error fetching picklist values', message: 'Not able to fetch MIRE Bank picklist values', variant: 'error', mode: 'sticky' }));
        }
    };

    // Helpers

    handleInputChange(event) {
        const inputName = event.target.name;
        if (inputName === 'currency') {
            this.selectedCurrency = event.target.value;
            const tempRows = [...this.rows];
            tempRows.forEach(r => {
                r.currency = event.target.value;
            });
            this.rows = tempRows;
        } else if (inputName === 'mireBank') {
            //v1.1 made Customer Bank dynamic picklist
            const differentBankName = this.rows.some(r => r.mireBank && r.mireBank !== event.target.value && (r.approvalStatus === 'Approved' && (r.allowEditing || r.approvalFieldsEditable)));
            if (differentBankName) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Please ensure that all Cheque Entries have the same MIRE Bank.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                return;
            }
            this.selectedMIREBank = event.target.value;
            const notApprovedRowIds = [];
            this.rows.forEach(row => {
                if (row.approvalStatus !== 'Approved' && (row.allowEditing || row.approvalFieldsEditable)) {
                    notApprovedRowIds.push(row.Id);
                }
            })
            if (!notApprovedRowIds.length) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Info',
                    message: 'All Cheque Entries are approved.',
                    variant: 'info'
                }));
                return;
            }
            this.debounce(inputName, () => {
                this.updateDraftValues(notApprovedRowIds, inputName, this.selectedMIREBank || '');
            }, 400);
        } else if (inputName === 'initialChequeNumber') {
            this.inputInitialChequeNumber = event.target.value;
        } else if (inputName === 'tillRow') {
            this.inputTillRow = Number(event.target.value);
        } else if (inputName === 'applyInitialCheque') {
            //v1.2 apply initial cheque number with incremental numbering and leading zero preservation
            if (this.inputTillRow > this.rows.length || this.inputTillRow <= 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Till Row not valid',
                    message: 'Enter till row greater than 0 and less or equal ' + this.rows.length,
                    variant: 'error',
                    mode: 'sticky'
                }));
                return;
            }

            if (isNaN(this.inputInitialChequeNumber)) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Initial Cheque Number not valid',
                    message: 'Only numbers are allowed for initial cheque number.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                return;
            }

            const upperBound = Number(this.inputTillRow);
            const range = (this.rows || []).slice(0, upperBound);

            const firstNonApprovedIdx = range.findIndex(r => r.approvalStatus !== 'Approved' && (r.allowEditing || r.approvalFieldsEditable));

            if (firstNonApprovedIdx === -1) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Info',
                    message: 'All Cheque Entries are already approved within the given range.',
                    variant: 'info'
                }));
                return;
            }

            const hasApprovedAfterStart = range.some((r, idx) => idx > firstNonApprovedIdx && (r.approvalStatus === 'Approved' || (!r.allowEditing && !r.approvalFieldsEditable)));
            if (hasApprovedAfterStart) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Some rows are approved in the given range, Can\'t apply initial cheque number.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                return;
            }

            const notApprovedRowIds = [];
            for (let i = firstNonApprovedIdx; i < upperBound; i++) {
                const row = this.rows[i];
                if (row && row.approvalStatus !== 'Approved' && (row.allowEditing || row.approvalFieldsEditable)) {
                    notApprovedRowIds.push(row.Id);
                }
            }

            if (!notApprovedRowIds.length) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Info',
                    message: 'All Cheque Entries are either approved or not editable in given range.',
                    variant: 'info'
                }));
                return;
            }

            const initialChequeNumber = this.inputInitialChequeNumber;
            this.debounce('initialChequeNumberInput', () => {
                this.updateDraftValues(notApprovedRowIds, 'chequeNumber', initialChequeNumber || '');
            }, 400);

            this.inputInitialChequeNumber = '';
            this.inputTillRow = '';
        }
    }

    updateDraftValues(rowIds, fieldName, value) {

        const draftMap = new Map();
        this.draftValues.forEach(d => {
            draftMap.set(d.Id, { ...d });
        });

        //v1.2 apply initial cheque number with incremental numbering and leading zero preservation
        const generateIncrementalValues = (startValue, count) => {
            const startStr = String(startValue ?? '');
            const width = startStr.length || 0;

            const baseNum = Number(startStr);
            if (isNaN(baseNum)) {
                return Array(count).fill(startStr);
            }

            const vals = [];
            for (let i = 0; i < count; i++) {
                const nextNum = baseNum + i;
                let nextStr = String(nextNum);
                if (width > 0) {
                    nextStr = nextStr.padStart(width, '0');
                }
                vals.push(nextStr);
            }
            
            return vals;
        };

        let incrementalValues = [];
        if (fieldName === 'chequeNumber') {
            incrementalValues = generateIncrementalValues(value, rowIds.length);
        } 
        rowIds.forEach((rowId, idx) => {
            if (!draftMap.has(rowId)) {
                draftMap.set(rowId, { Id: rowId });
            }
            draftMap.get(rowId)[fieldName] = fieldName === 'chequeNumber' ? incrementalValues[idx] : value;
        });

        // Convert back to array
        this.draftValues = Array.from(draftMap.values());


    }


    handleCancel() {
        this.draftValues = [];
        this.rows = [];
        this.dispatchEvent(new CloseActionScreenEvent());
        this.loadChequeEntries();
    }


    handleCellChange(event) {

        const newDrafts = event.detail.draftValues;
        newDrafts.forEach(newDraft => {
            const index = this.draftValues.findIndex(
                d => d.Id === newDraft.Id
            );

            if (index !== -1) {
                // merge with existing draft
                this.draftValues[index] = {
                    ...this.draftValues[index],
                    ...newDraft
                };
            } else {
                // new row edit
                this.draftValues.push(newDraft);
            }
        });

        // trigger reactivity
        this.draftValues = [...this.draftValues];
    }

    handleDraftValuesSave(event) {
        // Convert datatable draft values into record objects

        const recordsToUpdate = [];
        const draftRecords = event.detail.draftValues.slice().map((draftValue) => {
            const fields = Object.assign({}, draftValue);
            return { fields };
        });

        // Clear all datatable draft values
        this.draftValues = [];

        if (draftRecords && draftRecords.length > 0) {

            const isAnyDateInPast = draftRecords.some(rec => new Date(rec.fields?.chequeDueDate) < new Date());
            if (isAnyDateInPast) {
                this.draftValues = [];
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Cheque Due Date cannot be in past.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                this.handleCancel();
                return;
            }
            draftRecords.forEach(rec => {

                if (this.isUserChecker && rec.fields?.approvalStatus === 'Rejected' && (rec.fields?.rejectionComments === '' || (rec.fields?.rejectionComments === undefined && !this.rows.find(row => row.Id === rec.fields?.Id).rejectionComments))) {

                    this.draftValues = [];
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'Rejection Comments are mandatory for Rejected Cheque Entries',
                        variant: 'error',
                        mode: 'sticky'
                    }));
                    this.handleCancel();
                    return;
                }
                recordsToUpdate.push({
                    id: rec.fields?.Id,
                    currencyIsoCode: this.selectedCurrency,
                    customerBankName: rec.fields?.customerBank != null ? rec.fields.customerBank === '' ? '' : rec.fields.customerBank : 'not updated',
                    mireBankName: rec.fields?.mireBank != null ? rec.fields.mireBank === '' ? '' : rec.fields.mireBank : 'not updated',
                    chequeNumber: rec.fields?.chequeNumber != null ? rec.fields.chequeNumber === '' ? '' : rec.fields.chequeNumber : 'not updated',
                    chequeDueDate: rec.fields?.chequeDueDate != null ? rec.fields.chequeDueDate === '' ? '' : rec.fields.chequeDueDate : 'not updated',
                    approvalStatus: rec.fields?.approvalStatus != null ? rec.fields.approvalStatus : 'not updated',
                    rejectionComments: rec.fields?.rejectionComments != null ? rec.fields.rejectionComments === '' ? '' : rec.fields.rejectionComments : 'not updated',
                });
            });
        }
        if (recordsToUpdate && recordsToUpdate.length > 0) {
            updateChequeEntries({ jsonString: JSON.stringify(recordsToUpdate) })
                .then(result => {
                    if (result === 'Success') {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Success',
                            message: 'Cheque Entries updated successfully.',
                            variant: 'success'
                        }));
                        this.loadChequeEntries();
                    } else if (result === 'Failure') {
                        this.draftValues = [];
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Error',
                            message: 'Failed to update Cheque Entries.',
                            variant: 'error',
                            mode: 'sticky'
                        }));
                        this.handleCancel();
                    }
                });
        }
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortData();
    }

    sortData() {

        const data = [...this.rows];

        data.sort((a, b) => {

            const valA = a[this.sortedBy] ?? '';
            const valB = b[this.sortedBy] ?? '';

            return this.sortedDirection === 'asc'
                ? (valA.localeCompare(valB) ? 1 : -1)
                : (valA.localeCompare(valB) ? -1 : 1);
        });

        this.rows = data;
    }


    debounce(key, fn, delay = 400) {
        clearTimeout(this.debouncers[key]);
        this.debouncers[key] = setTimeout(fn, delay);
    }

    handleSubmitForApproval() {
        const tempRows = this.rows;

        if (this.draftValues.length) {

            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please save the changes before submitting for approval.',
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }
        const hasSomeDataMissing = tempRows.some(row => row.allowEditing && row.approvalStatus != 'Approved' && (!row.chequeNumber || !row.chequeDueDate || !row.customerBank || !row.mireBank));
        if (hasSomeDataMissing) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please ensure that for each row, Cheque Number, Cheque Date, Customer Bank and MIRE Bank is filled.',
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }

        const alreadySubmitted = tempRows.some(row => STATUSES_TO_ALLOW_APPROVAL_ACTION.some(status => status === row.approvalStatus));
        if (alreadySubmitted) {
            this.dispatchEvent(new ShowToastEvent({
                title: '',
                message: 'Already submitted for approval.',
                variant: 'Success',
                mode: 'sticky'
            }));
            return;
        }

        const recordsToUpdate = [];
        this.rows.forEach(row => {
            if (row.approvalStatus != 'Approved' && row.allowEditing) {
                const approvalStatus = row.approvalStatus != '' ? 'Re-submitted' : 'Approval Pending';
                recordsToUpdate.push({
                    id: row.Id,
                    approvalStatus: approvalStatus,
                    customerBankName: 'not updated',
                    mireBankName: 'not updated',
                    chequeNumber: 'not updated',
                    chequeDueDate: 'not updated',
                    rejectionComments: 'not updated',
                });
            }
        });
        if (recordsToUpdate && recordsToUpdate.length > 0) {
            updateChequeEntries({ jsonString: JSON.stringify(recordsToUpdate) })
                .then(result => {
                    if (result === 'Success') {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Success',
                            message: 'Submitted for approval successfully.',
                            variant: 'success'
                        }));
                        this.loadChequeEntries();
                    } else if (result === 'Failure') {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Error',
                            message: 'Failed to submit for approval.',
                            variant: 'error',
                            mode: 'sticky'
                        }));
                    }
                });
        }
    }

    handleApproveAll() {
        // Approve all rows currently in an approval-pending state and stage changes in draftValues
        const rows = Array.isArray(this.rows) ? [...this.rows] : [];
        const idsToApprove = [];

        //v1.1 approval action only allowed when all required fields have values
        rows.forEach((row, idx) => {
            if (row && row.approvalFieldsEditable && row.approvalStatus !== 'Approved') {
                // update UI row value
                const updated = { ...row, approvalStatus: 'Approved' };
                rows.splice(idx, 1, updated);
                // collect id to write draft value for saving later
                idsToApprove.push(row.Id);
            }
        });

        // commit UI changes
        this.rows = rows;

        // persist to draft values so Save will include the change
        if (idsToApprove.length) {
            this.updateDraftValues(idsToApprove, 'approvalStatus', 'Approved');
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Info',
                message: 'No Cheque Entries found eligible for approval.',
                variant: 'info'
            }));
        }
    }

    //v1.1 made Customer Bank dynamic picklist
    handleCustomerBankChange(event) {
        const customerBank = event.target.value;
        const rows = Array.isArray(this.rows) ? [...this.rows] : [];
        const idsToUpdateCustomerBank = [];

        rows.forEach((row, idx) => {
            if (row && row.allowEditing && row.approvalStatus !== 'Approved') {
                // update UI row value
                const updated = { ...row, customerBank: customerBank };
                rows.splice(idx, 1, updated);
                // collect id to write draft value for saving later
                idsToUpdateCustomerBank.push(row.Id);
            }
        });

        // commit UI changes
        this.rows = rows;

        // persist to draft values so Save will include the change
        if (idsToUpdateCustomerBank.length) {
            this.updateDraftValues(idsToUpdateCustomerBank, 'customerBank', customerBank);
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Info',
                message: 'No Cheque Entries found eligible for customer bank update.',
                variant: 'info'
            }));
        }
    }

    async handleCreateReceipts() {
        try {
            // Build payload only for Approved rows
            const approvedRows = (this.rows || []).filter(r => r.approvalStatus === 'Approved' && r.chequeAmount > 0);

            if (!approvedRows.length) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Info',
                    message: 'No approved Cheque Entries found to create receipts.',
                    variant: 'info'
                }));
                return;
            }

            // Validate required fields for receipt creation
            const invalid = approvedRows.some(r =>
                !r.chequeNumber || !r.chequeDueDate || !r.mireBank || !r.currency
            );

            if (invalid) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Missing data for some Cheque Entries. Cheque Number, Cheque Date, MIRE Bank and Currency.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                return;
            }

            const payload = approvedRows.map(r => ({
                accountId: this.accountId,
                soId: this.recordId,
                soiId: r.soId, // SalesOrderInstallmentId mapped from row.Id per current data shape
                chequeEntryId: r.Id,
                chequeAmount: r.chequeAmount,
                chequeNumber: r.chequeNumber,
                chequeDueDate: r.chequeDueDate,
                customerBank: r.customerBank,
                mireBank: r.mireBank,
                currencyIsoCode: r.currency,
                modeOfPayment: 'Cheque',
                receiptType: r.receiptType + ' Receipt'
            }));

            const result = await insertReceipts({ jsonString: JSON.stringify(payload) });
            if (result === 'Success') {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Receipt records created successfully.',
                    variant: 'success'
                }));
                // Refresh data
                this.loadChequeEntries();
            } else if (result === 'Duplicate') {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Receipt records have already been created for Cheque Entries.',
                    variant: 'error',
                    mode: 'sticky'
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to create Receipt records.',
                    variant: 'error',
                    mode: 'sticky'
                }));
            }
        } catch (e) {
            // Surface error to user
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: e?.body?.message || e?.message || 'An unexpected error occurred while creating receipts.',
                variant: 'error',
                mode: 'sticky'
            }));
        }
    }

    handlePicklistChange(event) {
        event.stopPropagation();
        let { context, value, fieldName } = event.detail.data;
        const idList = [];
        idList.push(context);
        this.updateDraftValues(idList, fieldName, value);

    }

    handleRefresh() {
        this.handleCancel();
    }
}