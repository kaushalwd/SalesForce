import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getStatusToRecordTypeMap from '@salesforce/apex/ObjectFieldMetadataController.getStatusToRecordTypeMap';
import getRelatedSalesOrders from '@salesforce/apex/ObjectFieldMetadataController.getRelatedSalesOrders';
import deleteUploadedFile from '@salesforce/apex/ObjectFieldMetadataController.deleteUploadedFile';
import getReceiptAmounts from '@salesforce/apex/ObjectFieldMetadataController.getReceiptAmounts';

import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import STATUS_FIELD from '@salesforce/schema/SalesOrder__c.Status__c';
import UNIT_FIELD from '@salesforce/schema/SalesOrder__c.Unit__c';
import ACCOUNT_FIELD from '@salesforce/schema/SalesOrder__c.CustomerAccount__c';
import ADM_STATUS_FIELD from '@salesforce/schema/SalesOrder__c.ADM_Fees_and_Dari__c';
import DOWN_PAYMENT_FIELD from '@salesforce/schema/SalesOrder__c.Down_Payment_Status__c';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/SalesOrder__c.CustomerAccount__r.Name';
import UNIT_NAME_FIELD from '@salesforce/schema/SalesOrder__c.Unit__r.Name';
import SALES_ORDER_FIELD from '@salesforce/schema/SalesOrder__c.Name';

import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import BANK_COUNTRY_FIELD from '@salesforce/schema/Account.Bank_Country__c';

import ALLOWED_SO_STATUSES_LABEL from '@salesforce/label/c.Allowed_SalesOrder_Status_For_Cancellation';

const FIELDS = [
    STATUS_FIELD,
    ACCOUNT_FIELD,
    UNIT_FIELD,
    ADM_STATUS_FIELD,
    DOWN_PAYMENT_FIELD,
     ACCOUNT_NAME_FIELD,
     UNIT_NAME_FIELD,
     SALES_ORDER_FIELD
];

export default class CancellationBusinessProcess extends LightningElement {

    @api recordId;
    @api processId;

    /*
     * Parent can pass the Business Process type/sub-category.
     */
    @api processType;

    showLoading = true;
    showForm = false;

    unitId = '';
    accountId = '';
    unitName = '';

    admStatus = '';
    downPaymentStatus = '';

    admPaidAmount = 0;
    downPaymentAmount = 0;

    showAdmRefundField = true;
    showConsolidationTable = false;

    cancellationType = '';
    cancellationReason = '';
    managementJustification = '';
    admRefundValue = '';

    /*
     * Bank details — only relevant for "Cancellation with Refund". Optional:
     * the user can supply them now (closing the "Customer Bank Details Upload"
     * step immediately), or leave the checkbox unchecked so that step opens
     * assigned to them to complete later.
     */
    bankDetailsAvailable = false;
    bankName = '';
    beneficiaryName = '';
    bankAccountNumber = '';
    ibanNumber = '';
    bankBranchName = '';
    swiftCode = '';
    bankCountry = '';

    @track ibanDocument = null;

    bankCountryOptions = [];

    modalHeader = '';

    isPostCancellation = false;

    salesOrderStatus = '';
    salesOrderName='';
    unitName='';
    accountName='';

    get cancellationTypeOptions() {
    return [
        {
            label: 'Cancellation without Refund',
            value: 'Cancellation without Refund'
        },
        {
            label: 'Cancellation with Refund',
            value: 'Cancellation with Refund'
        },
        {
            label: 'Consolidation Cancellation',
            value: 'Consolidation Cancellation'
        }
    ];
}


get admRefundOptions() {
    return [
        {
            label: 'ADM',
            value: 'ADM'
        },
        {
            label: 'Down Payment',
            value: 'Down Payment'
        },
        {
            label: 'Both',
            value: 'Both'
        }
    ];
}

    @track salesOrders = [];
    @track uploadedFiles = [];
    @track draftValues = [];

    @track totalRefundAmount = 0;

    statusRTMap = {};

    _soReady = false;
    _mapReady = false;
    _amountsLoaded = false;

    columns = [
        {
            label: 'Unit',
            fieldName: 'Unit_Name__c',
            type: 'text'
        },
        {
            label: 'Sales Order',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Fund Transfer',
            fieldName: 'Fund_Transfer__c',
            type: 'boolean',
            editable: true
        },
        {
            label: 'Transfer Amount',
            fieldName: 'Transfer_Amount__c',
            type: 'currency',
            editable: true,
            typeAttributes: {
                currencyCode: 'AED',
                step: '0.01'
            }
        }
    ];

    hasConsolidationChanges = false;

    /* ============================================================
     * LIFECYCLE
     * ============================================================ */

    connectedCallback() {

        getStatusToRecordTypeMap({
            objName: 'ServiceRequest__c'
        })
        .then(result => {

            this.statusRTMap = result || {};
            this._mapReady = true;

            this._tryInitialize();

        })
        .catch(error => {

            console.error(
                'getStatusToRecordTypeMap error:',
                error
            );

            this._showError(
                'Error loading cancellation configuration.'
            );

            this.showLoading = false;
        });
    }

    /* ============================================================
     * SALES ORDER
     * ============================================================ */

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    wiredSalesOrder({ data, error }) {

        if (data) {

            this.salesOrderStatus =
                data.fields.Status__c?.value || '';

            this.unitId =
                data.fields.Unit__c?.value || '';

            this.accountId =
                data.fields.CustomerAccount__c?.value || '';

            this.admStatus =
                data.fields.ADM_Fees_and_Dari__c?.value || '';

            this.downPaymentStatus =
                data.fields.Down_Payment_Status__c?.value || '';
            this.salesOrderName=data.fields.Name?.value || ''; 
            this.accountName= data.fields.CustomerAccount__r?.value?.fields?.Name?.value || '';
            this.unitName= data.fields.Unit__r?.value?.fields?.Name?.value || '';


            this._soReady = true;

            this._tryInitialize();

            this._loadReceiptAmounts();

        } else if (error) {

            console.error(
                'getRecord error:',
                error
            );

            this.showLoading = false;

            this._showError(
                'Error loading Sales Order.'
            );
        }
    }

    /* ============================================================
     * BANK COUNTRY PICKLIST (Account.Bank_Country__c)
     * ============================================================ */

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId',
        fieldApiName: BANK_COUNTRY_FIELD
    })
    wiredBankCountryValues({ data, error }) {

        if (data) {

            this.bankCountryOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));

        } else if (error) {

            console.error(
                'getPicklistValues (Bank_Country__c) error:',
                error
            );

            this.bankCountryOptions = [];
        }
    }

    /* ============================================================
     * INITIALIZATION
     *
     * We retain the old status -> SR record type configuration
     * because it determines whether this is Pre or Post Cancellation.
     *
     * NO Service Request is created.
     * ============================================================ */

    async _tryInitialize() {

        if (
            !this._soReady ||
            !this._mapReady ||
            !this.salesOrderStatus
        ) {
            return;
        }

        this.showLoading = true;

        try {

            const allowedStatuses = (ALLOWED_SO_STATUSES_LABEL || '')
                .split(',')
                .map(status => status.trim())
                .filter(status => status);

            if (!allowedStatuses.includes(this.salesOrderStatus)) {

                this._showError(
                    'Cancellation cannot be initiated for Sales Orders with status: ' +
                    this.salesOrderStatus
                );

                return;
            }

            const expectedRTName =
                this.statusRTMap[this.salesOrderStatus];

            if (!expectedRTName) {

                this._showError(
                    'No cancellation configuration found for status: ' +
                    this.salesOrderStatus
                );

                return;
            }

            this.modalHeader = expectedRTName;

            this.isPostCancellation =
                expectedRTName
                    .toLowerCase()
                    .includes('post');

            this.isPostCancellation=false;        

            this.showForm = true;

        } catch (error) {

            console.error(
                '_tryInitialize error:',
                error
            );

            this._showError(
                error.body?.message ||
                error.message ||
                'Error initializing cancellation form.'
            );

        } finally {

            this.showLoading = false;
        }
    }

    /* ============================================================
     * RECEIPT AMOUNTS
     * ============================================================ */

    async _loadReceiptAmounts() {

        try {

            const result = await getReceiptAmounts({
                salesOrderId: this.recordId
            });

            this.admPaidAmount =
                result?.admAmount || 0;

            this.downPaymentAmount =
                result?.downPaymentAmount || 0;

            this._amountsLoaded = true;

            this._computeTotalRefund();

        } catch (error) {

            console.error(
                'getReceiptAmounts error:',
                error
            );

            this._amountsLoaded = true;

            this.admPaidAmount = 0;
            this.downPaymentAmount = 0;

            this._computeTotalRefund();
        }
    }

    /* ============================================================
     * REFUND CALCULATION
     * ============================================================ */

    _computeTotalRefund() {

        if (this.admRefundValue === 'ADM') {

            this.totalRefundAmount =
                this.admPaidAmount || 0;

        } else if (
            this.admRefundValue === 'Down Payment'
        ) {

            this.totalRefundAmount =
                this.downPaymentAmount || 0;

        } else if (
            this.admRefundValue === 'Both'
        ) {

            this.totalRefundAmount =
                (this.admPaidAmount || 0) +
                (this.downPaymentAmount || 0);

        } else {

            this.totalRefundAmount = 0;
        }
    }

    /* ============================================================
     * CANCELLATION TYPE
     * ============================================================ */

    handleCancellationReasonChange(event) {

        this.cancellationReason =
            event.target.value;
    }

    handleManagementJustificationChange(event) {

        this.managementJustification =
            event.detail.value;
    }

    /* ============================================================
     * BANK DETAILS
     * ============================================================ */

    get showBankDetailsSection() {
        return this.cancellationType === 'Cancellation with Refund';
    }

    handleBankDetailsAvailableChange(event) {
        this.bankDetailsAvailable = event.target.checked;
    }

    handleBankNameChange(event) {
        this.bankName = event.target.value;
    }

    handleBeneficiaryNameChange(event) {
        this.beneficiaryName = event.target.value;
    }

    handleBankAccountNumberChange(event) {
        this.bankAccountNumber = event.target.value;
    }

    handleIbanNumberChange(event) {
        this.ibanNumber = event.target.value;
    }

    handleBankBranchNameChange(event) {
        this.bankBranchName = event.target.value;
    }

    handleSwiftCodeChange(event) {
        this.swiftCode = event.target.value;
    }

    handleBankCountryChange(event) {
        this.bankCountry = event.detail.value;
    }

    handleIbanUploadFinished(event) {

        const files = event.detail.files || [];

        if (files.length) {
            this.ibanDocument = files[0];

            this._showToast(
                'IBAN document uploaded',
                'success'
            );
        }
    }

    async removeIbanDocument() {

        if (!this.ibanDocument) {
            return;
        }

        this.showLoading = true;

        try {

            await deleteUploadedFile({
                contentDocumentId: this.ibanDocument.documentId
            });

            this.ibanDocument = null;

            this._showToast(
                'IBAN document removed',
                'success'
            );

        } catch (error) {

            console.error(
                'deleteUploadedFile (IBAN document) error:',
                error
            );

            this._showError(
                error.body?.message ||
                error.message
            );

        } finally {

            this.showLoading = false;
        }
    }

    handleCancellationTypeChange(event) {

        this.cancellationType =
            event.detail.value;

        this.showAdmRefundField =
            this.cancellationType !==
            'Cancellation without Refund';

        if (
            this.cancellationType ===
            'Consolidation Cancellation'
        ) {

            this.showConsolidationTable = true;

            if (!this.salesOrders.length) {
                this._loadSalesOrders();
            }

        } else {

            this.showConsolidationTable = false;
        }
    }

    /* ============================================================
     * RELATED SALES ORDERS
     * ============================================================ */

    async _loadSalesOrders() {

        this.showLoading = true;

        try {

            const data =
                await getRelatedSalesOrders({
                    salesOrderId: this.recordId
                });

            this.salesOrders =
                (data || []).map(row => ({
                    ...row,

                    IsConsolidated__c:
                        row.Id === this.recordId,

                    Fund_Transfer__c:
                        row.Fund_Transfer__c || false,

                    Transfer_Amount__c:
                        row.Transfer_Amount__c || 0
                }));

        } catch (error) {

            console.error(
                'getRelatedSalesOrders error:',
                error
            );

            this._showError(
                'Error loading related Sales Orders.'
            );

        } finally {

            this.showLoading = false;
        }
    }

    /* ============================================================
     * DATATABLE SAVE
     * ============================================================ */

    handleDatatableSave(event) {

        const drafts =
            event.detail.draftValues || [];

        this.salesOrders =
            this.salesOrders.map(row => {

                const draft =
                    drafts.find(
                        d => d.Id === row.Id
                    );

                return draft
                    ? {
                        ...row,
                        ...draft
                    }
                    : row;
            });

        this.draftValues = [];

        this.hasConsolidationChanges = true;

        this._showToast(
            'Changes captured',
            'success'
        );
    }

    /* ============================================================
     * REFUND TYPE
     * ============================================================ */

    handleAdmRefundChange(event) {

        this.admRefundValue =
            event.detail.value;

        this._computeTotalRefund();
    }

    /* ============================================================
     * COMPUTED VALUES
     * ============================================================ */

    get consolidationTotalAmount() {
        return this.totalRefundAmount;
    }

    get showTotalRefundBanner() {

        return (
            this.cancellationType ===
            'Consolidation Cancellation' &&
            this.showConsolidationTable &&
            !!this.admRefundValue
        );
    }

    get showPayableAmount() {

        return !!this.admRefundValue;
    }

    /*
     * Parent is now responsible for final creation.
     *
     * Therefore this button only becomes enabled when
     * all required information is valid.
     */
    get disableCreateButton() {

        if (this.showLoading) {
            return true;
        }

        if (!this.cancellationType) {
            return true;
        }

        if (!this.cancellationReason) {
            return true;
        }

        if (!this.managementJustification) {
            return true;
        }

        if (!this.uploadedFiles.length) {
            return true;
        }

        if (
            this.cancellationType ===
            'Cancellation with Refund'
        ) {
            return this.bankDetailsAvailable && !this._hasCompleteBankDetails();
        }

        if (
            this.cancellationType ===
            'Consolidation Cancellation'
        ) {

            return !this.salesOrders.some(
                row =>
                    row.Fund_Transfer__c === true &&
                    Number(row.Transfer_Amount__c) > 0
            );
        }

        return false;
    }

    /*
     * Bank details are optional overall, but once "Bank Details Available" is
     * checked, all 7 fields plus the IBAN document become required.
     */
    _hasCompleteBankDetails() {
        return (
            !!this.bankName &&
            !!this.beneficiaryName &&
            !!this.bankAccountNumber &&
            !!this.ibanNumber &&
            !!this.bankBranchName &&
            !!this.swiftCode &&
            !!this.bankCountry &&
            !!this.ibanDocument
        );
    }

    /* ============================================================
     * MAIN SUBMIT
     *
     * IMPORTANT:
     * This does NOT create ServiceRequest__c.
     *
     * It validates and sends all data to parent.
     * ============================================================ */

    async handleSave() {

        const errors = [];

        /* --------------------------------------------------------
         * REASON / JUSTIFICATION VALIDATION
         * -------------------------------------------------------- */

        if (!this.cancellationReason) {
            errors.push('Reason for Cancellation is required');
        }

        if (!this.managementJustification) {
            errors.push('Management Justification is required');
        }

        /* --------------------------------------------------------
         * BANK DETAILS VALIDATION
         * -------------------------------------------------------- */

        if (
            this.showBankDetailsSection &&
            this.bankDetailsAvailable &&
            !this._hasCompleteBankDetails()
        ) {
            errors.push(
                'All bank details fields and the IBAN document are required when Bank Details Available is checked'
            );
        }

        /* --------------------------------------------------------
         * PAYMENT STATUS VALIDATION
         * -------------------------------------------------------- */

        if (
            this.cancellationType !==
            'Cancellation without Refund'
        ) {

            if (
                this.admRefundValue === 'ADM' ||
                this.admRefundValue === 'Both'
            ) {

                if (
                    this.admStatus !== 'Paid' &&
                    this.admStatus !== 'Partially Paid'
                ) {

                    errors.push(
                        'ADM Payment Status must be Paid or Partially Paid'
                    );
                }
            }

            if (
                this.admRefundValue === 'Down Payment' ||
                this.admRefundValue === 'Both'
            ) {

                if (
                    this.downPaymentStatus !== 'Paid' &&
                    this.downPaymentStatus !== 'Partially Paid'
                ) {

                    errors.push(
                        'Down Payment Status must be Paid or Partially Paid'
                    );
                }
            }
        }

        if (errors.length) {

            this._showError(
                errors.join(' | ')
            );

            return;
        }

        /* --------------------------------------------------------
         * CONSOLIDATION VALIDATION
         * -------------------------------------------------------- */

        if (
            this.cancellationType ===
            'Consolidation Cancellation'
        ) {

            /*
             * Fund Transfer + Amount must be supplied together.
             */
            const invalidRows =
                this.salesOrders.filter(row =>

                    (
                        Number(row.Transfer_Amount__c) > 0 &&
                        row.Fund_Transfer__c !== true
                    )

                    ||

                    (
                        row.Fund_Transfer__c === true &&
                        (
                            !row.Transfer_Amount__c ||
                            Number(row.Transfer_Amount__c) <= 0
                        )
                    )
                );

            if (invalidRows.length) {

                this._showError(
                    'Fund Transfer and Transfer Amount must both be populated together'
                );

                return;
            }

            /* ----------------------------------------------------
             * AMOUNT MATCH VALIDATION
             * ---------------------------------------------------- */

            if (this.totalRefundAmount > 0) {

                const selectedRows =
                    this.salesOrders.filter(
                        row =>
                            row.Fund_Transfer__c === true &&
                            Number(row.Transfer_Amount__c) > 0
                    );

                if (!selectedRows.length) {

                    this._showError(
                        'Please select at least one row with Fund Transfer and enter a Transfer Amount'
                    );

                    return;
                }

                const sumOfSelected =
                    selectedRows.reduce(
                        (acc, row) =>
                            acc +
                            (Number(row.Transfer_Amount__c) || 0),
                        0
                    );

                const sumRounded =
                    Math.round(
                        sumOfSelected * 100
                    ) / 100;

                const totalRounded =
                    Math.round(
                        this.totalRefundAmount * 100
                    ) / 100;

                if (
                    sumRounded !==
                    totalRounded
                ) {

                    this._showError(
                        `Total Transfer Amount of selected rows (AED ${sumRounded.toFixed(2)}) ` +
                        `must equal the expected refund amount (AED ${totalRounded.toFixed(2)}). ` +
                        `Please adjust the Transfer Amounts.`
                    );

                    return;
                }
            }
        }

        /* --------------------------------------------------------
         * FILE VALIDATION
         * -------------------------------------------------------- */

        if (!this.uploadedFiles.length) {

            this._showError(
                'Please upload at least one file before submitting'
            );

            return;
        }

        /*
         * Build the complete payload for parent.
         */
        const payload = this._buildPayload();

        console.log(
            'Cancellation Business Process Payload:',
            JSON.stringify(payload)
        );

        /*
         * Send child -> parent.
         */
        this.dispatchEvent(
            new CustomEvent(
                'processsubmit',
                {
                    detail: payload,
                    bubbles: true,
                    composed: true
                }
            )
        );
    }

    /* ============================================================
     * BUILD PAYLOAD
     * ============================================================ */

    _buildPayload() {

        const consolidationRecords =
            this.salesOrders
                .filter(
                    row =>
                        row.Fund_Transfer__c === true
                )
                .map(row => ({
                    salesOrderId: row.Id,

                    isConsolidated:
                        row.IsConsolidated__c || false,

                    fundTransfer:
                        true,

                    transferAmount:
                        Number(
                            row.Transfer_Amount__c
                        ) || 0
                }));

        return {

            /* -----------------------------------------------
             * Main Sales Order
             * ----------------------------------------------- */

            salesOrderId:
                this.recordId,
            processId: this.processId,    

            unitId:
                this.unitId,

            accountId:
                this.accountId,

            salesOrderStatus:
                this.salesOrderStatus,

            unitName:
                this.unitName,

            /* -----------------------------------------------
             * Cancellation
             * ----------------------------------------------- */

            cancellationType:
                this.cancellationType,

            cancellationReason:
                this.cancellationReason,

            managementJustification:
                this.managementJustification,

            isPostCancellation:
                this.isPostCancellation,

            processType:
                this.processType,

            modalHeader:
                this.modalHeader,

            /* -----------------------------------------------
             * Financials
             * ----------------------------------------------- */

            admStatus:
                this.admStatus,

            downPaymentStatus:
                this.downPaymentStatus,

            admPaidAmount:
                Number(this.admPaidAmount) || 0,

            downPaymentAmount:
                Number(this.downPaymentAmount) || 0,

            admRefundValue:
                this.admRefundValue,

            totalRefundAmount:
                Number(this.totalRefundAmount) || 0,

            /* -----------------------------------------------
             * Bank Details (Account level) — only meaningful when
             * showBankDetailsSection && bankDetailsAvailable.
             * ----------------------------------------------- */

            bankDetailsAvailable:
                this.bankDetailsAvailable,

            bankName:
                this.bankName,

            beneficiaryName:
                this.beneficiaryName,

            bankAccountNumber:
                this.bankAccountNumber,

            ibanNumber:
                this.ibanNumber,

            bankBranchName:
                this.bankBranchName,

            swiftCode:
                this.swiftCode,

            bankCountry:
                this.bankCountry,

            ibanDocument:
                this.ibanDocument
                    ? {
                        name: this.ibanDocument.name,
                        documentId: this.ibanDocument.documentId,
                        contentVersionId:
                            this.ibanDocument.contentVersionId
                    }
                    : null,

            /* -----------------------------------------------
             * Consolidation
             * ----------------------------------------------- */

            showConsolidationTable:
                this.showConsolidationTable,

            hasConsolidationChanges:
                this.hasConsolidationChanges,

            consolidationRecords:
                consolidationRecords,

            salesOrders:
                this.salesOrders,

            /* -----------------------------------------------
             * Uploaded files
             *
             * lightning-file-upload gives us documentId.
             * Parent can use these after BP creation.
             * ----------------------------------------------- */

            uploadedFiles:
                this.uploadedFiles.map(file => ({
                    name: file.name,
                    documentId: file.documentId,
                    contentVersionId:
                        file.contentVersionId
                }))
        };
    }

    /* ============================================================
     * FILE UPLOAD
     * ============================================================ */

    handleUploadFinished(event) {

        const files =
            event.detail.files || [];

        this.uploadedFiles = [
            ...this.uploadedFiles,
            ...files
        ];

        this._showToast(
            files.length +
            ' file(s) uploaded',
            'success'
        );
    }

    async removeFile(event) {

        const fileId =
            event.currentTarget.dataset.id;

        this.showLoading = true;

        try {

            await deleteUploadedFile({
                contentDocumentId: fileId
            });

            this.uploadedFiles =
                this.uploadedFiles.filter(
                    file =>
                        file.documentId !== fileId
                );

            this._showToast(
                'File removed',
                'success'
            );

        } catch (error) {

            console.error(
                'deleteUploadedFile error:',
                error
            );

            this._showError(
                error.body?.message ||
                error.message
            );

        } finally {

            this.showLoading = false;
        }
    }

    /* ============================================================
     * CANCEL
     * ============================================================ */

    handleCancel() {

        this.dispatchEvent(
            new CustomEvent(
                'processcancel',
                {
                    bubbles: true,
                    composed: true
                }
            )
        );
    }

    /* ============================================================
     * PUBLIC METHOD
     *
     * Parent can reset child after a failed/cancelled operation.
     * ============================================================ */

    @api
    resetComponent() {

        this.cancellationType = '';
        this.cancellationReason = '';
        this.managementJustification = '';
        this.admRefundValue = '';

        this.bankDetailsAvailable = false;
        this.bankName = '';
        this.beneficiaryName = '';
        this.bankAccountNumber = '';
        this.ibanNumber = '';
        this.bankBranchName = '';
        this.swiftCode = '';
        this.bankCountry = '';
        this.ibanDocument = null;

        this.totalRefundAmount = 0;

        this.salesOrders = [];
        this.uploadedFiles = [];
        this.draftValues = [];

        this.showConsolidationTable = false;
        this.hasConsolidationChanges = false;

        this.showAdmRefundField = true;
    }

    /* ============================================================
     * TOAST
     * ============================================================ */

    _showToast(message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title:
                    variant.charAt(0).toUpperCase() +
                    variant.slice(1),

                message: message,

                variant: variant
            })
        );
    }

    _showError(message) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
}