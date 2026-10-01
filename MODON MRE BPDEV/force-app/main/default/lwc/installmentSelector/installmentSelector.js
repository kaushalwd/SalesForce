import {
    LightningElement,
    api,
    track,
    wire
} from 'lwc';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import getInstallments
    from '@salesforce/apex/ApprovalModalController.getInstallments';

import processInstallments
    from '@salesforce/apex/ApprovalModalController.processInstallments';

import deleteUploadedFile
    from '@salesforce/apex/ObjectFieldMetadataController.deleteUploadedFile';

import BUSINESS_PROCESS_OBJECT
    from '@salesforce/schema/Business_Process__c';

import TYPE_OF_REQUEST_FIELD
    from '@salesforce/schema/Business_Process__c.Type_of_Request__c';

export default class InstallmentSelector extends LightningElement {
    @api recordId;

    installments = [];
    selectedRows = [];

    isLoading = false;
    selectedInstallmentId;
    selectedRecord;
    extensionOption;
    extensionDate;
    dateValidationMessage;

    extensionOptions = [
        { label: '15 Days', value: '15_days' },
        { label: 'One Month', value: 'one_month' },
        { label: 'Two Months', value: 'two_months' },
        { label: 'Three Months', value: 'three_months' },
        { label: 'Custom', value: 'custom' }
    ];

    typeOfRequest;
    paymentExtensionReason;
    approvalJustification;

    @track uploadedFiles = [];

    businessProcessRecordTypeId;
    typeOfRequestOptions = [];

    columns = [
        {
            label: 'Installment Name',
            fieldName: 'Name',
            type: 'text',
            initialWidth: 150
        },
        {
            label: 'Milestone %',
            fieldName: 'Milestone__c',
            type: 'number',
            typeAttributes: {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            },
            initialWidth: 115
        },
        {
            label: 'Milestone No.',
            fieldName: 'MilestoneNumber__c',
            type: 'number',
            initialWidth: 115
        },
        {
            label: 'Milestone Date',
            fieldName: 'MilestoneDate__c',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                timeZone: 'UTC'
            },
            initialWidth: 150
        },
        {
            label: 'Existing Extension Date',
            fieldName: 'ExtensionDate__c',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                timeZone: 'UTC'
            },
            initialWidth: 165
        },
        {
            label: 'Payment Status',
            fieldName: 'PaymentStatus__c',
            type: 'text',
            initialWidth: 130
        },
        {
            label: 'Installment Amount',
            fieldName: 'InstallmentAmount__c',
            type: 'currency',
            typeAttributes: {
                currencyCode: 'AED',
                minimumFractionDigits: 2
            },
            initialWidth: 160
        },
        {
            label: 'Milestone Description',
            fieldName: 'MilestoneDescription__c',
            type: 'text',
            wrapText: true,
            initialWidth: 340
        }
    ];

    @wire(getObjectInfo, { objectApiName: BUSINESS_PROCESS_OBJECT })
    wiredBusinessProcessInfo({ data }) {
        if (data) {
            this.businessProcessRecordTypeId =
                data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$businessProcessRecordTypeId',
        fieldApiName: TYPE_OF_REQUEST_FIELD
    })
    wiredTypeOfRequestValues({ data, error }) {
        if (data) {
            this.typeOfRequestOptions = data.values.map(
                (item) => ({
                    label: item.label,
                    value: item.value
                })
            );
        } else if (error) {
            this.typeOfRequestOptions = [];
        }
    }

    @wire(getInstallments, {
        recordId: '$recordId'
    })
    wiredData({ data, error }) {
        if (data) {
            this.prepareInstallments(data);
        } else if (error) {
            this.installments = [];

            this.dispatchProcessError(
                this.getErrorMessage(error)
            );
        }
    }

    prepareInstallments(data) {
        const sortedData = [...data].sort((first, second) => {
            const firstNumber =
                first.MilestoneNumber__c ?? Number.MAX_SAFE_INTEGER;

            const secondNumber =
                second.MilestoneNumber__c ?? Number.MAX_SAFE_INTEGER;

            if (firstNumber !== secondNumber) {
                return firstNumber - secondNumber;
            }

            const firstDate = first.MilestoneDate__c
                ? new Date(first.MilestoneDate__c).getTime()
                : Number.MAX_SAFE_INTEGER;

            const secondDate = second.MilestoneDate__c
                ? new Date(second.MilestoneDate__c).getTime()
                : Number.MAX_SAFE_INTEGER;

            return firstDate - secondDate;
        });

        this.installments = sortedData.map((row, index) => {
            const nextInstallment = sortedData[index + 1];

            return {
                ...row,
                salesOrderName: row.SalesOrder__r?.Name,
                NextInstallmentDate:
                    nextInstallment?.MilestoneDate__c || null
            };
        });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;

        this.extensionOption = null;
        this.extensionDate = null;
        this.dateValidationMessage = null;
        this.typeOfRequest = null;
        this.paymentExtensionReason = null;
        this.approvalJustification = null;

        if (!selectedRows || selectedRows.length === 0) {
            this.selectedInstallmentId = null;
            this.selectedRecord = null;
            this.selectedRows = [];
            return;
        }

        const selectedRow = selectedRows[0];

        this.selectedInstallmentId = selectedRow.Id;
        this.selectedRows = [selectedRow.Id];

        this.selectedRecord = this.installments.find(
            (installment) =>
                installment.Id === this.selectedInstallmentId
        );
    }

    handleExtensionOptionChange(event) {
        this.extensionOption = event.detail.value;
        this.dateValidationMessage = null;

        if (this.extensionOption === 'custom') {
            this.extensionDate = null;
            return;
        }

        this.extensionDate = this.computeExtensionDateForOption(
            this.extensionOption
        );

        this.validateExtensionDate();
    }

    computeExtensionDateForOption(option) {
        if (!this.selectedRecord?.MilestoneDate__c) {
            return null;
        }

        const milestoneDate = this.selectedRecord.MilestoneDate__c;

        switch (option) {
            case '15_days':
                return this.addDays(milestoneDate, 15);
            case 'one_month':
                return this.addMonths(milestoneDate, 1);
            case 'two_months':
                return this.addMonths(milestoneDate, 2);
            case 'three_months':
                return this.addMonths(milestoneDate, 3);
            default:
                return null;
        }
    }

    handleExtensionDateChange(event) {
    this.extensionDate = event.target.value;

    const isValid = this.validateExtensionDate();

    event.target.setCustomValidity(
        isValid
            ? ''
            : this.dateValidationMessage
    );

    event.target.reportValidity();
}

    handleTypeOfRequestChange(event) {
        this.typeOfRequest = event.detail.value;
    }

    handlePaymentExtensionReasonChange(event) {
        this.paymentExtensionReason = event.detail.value;
    }

    handleApprovalJustificationChange(event) {
        this.approvalJustification = event.detail.value;
    }

    handleUploadFinished(event) {
        const files = event.detail.files || [];

        this.uploadedFiles = [
            ...this.uploadedFiles,
            ...files
        ];
    }

    async removeFile(event) {
        const fileId = event.currentTarget.dataset.id;

        try {
            await deleteUploadedFile({ contentDocumentId: fileId });

            this.uploadedFiles = this.uploadedFiles.filter(
                file => file.documentId !== fileId
            );
        } catch (error) {
            console.error('deleteUploadedFile error:', error);

            this.dispatchProcessError(
                this.getErrorMessage(error)
            );
        }
    }

   validateExtensionDate() {
    this.dateValidationMessage = '';

    if (!this.selectedRecord) {
        this.dateValidationMessage =
            'Please select an installment.';
        return false;
    }

    if (!this.extensionDate) {
        this.dateValidationMessage =
            'Please select an extension date.';
        return false;
    }

    if (!this.selectedRecord.MilestoneDate__c) {
        this.dateValidationMessage =
            'Milestone Date is not available for the selected installment.';
        return false;
    }

    const extensionDate = this.toComparableDate(
        this.extensionDate
    );

    const milestoneDate = this.toComparableDate(
        this.selectedRecord.MilestoneDate__c
    );

    if (extensionDate <= milestoneDate) {
        this.dateValidationMessage =
            'Extension Date must be later than the selected installment Milestone Date.';
        return false;
    }

    if (this.selectedRecord.NextInstallmentDate) {
        const nextInstallmentDate =
            this.toComparableDate(
                this.selectedRecord.NextInstallmentDate
            );

        if (extensionDate >= nextInstallmentDate) {
            this.dateValidationMessage =
                'Extension Date must be earlier than the next installment date.';
            return false;
        }
    }

    return true;
}

    toComparableDate(dateValue) {
        return new Date(`${dateValue}T00:00:00Z`).getTime();
    }

    async handleSubmit() {
        if (!this.selectedInstallmentId) {
            this.dispatchProcessError(
                'Please select an installment.',
                'Validation Error',
                'warning'
            );
            return;
        }

        if (!this.validateExtensionDate()) {
            this.reportDateValidity();

            this.dispatchProcessError(
                this.dateValidationMessage,
                'Validation Error',
                'warning'
            );
            return;
        }

        if (!this.typeOfRequest) {
            this.dispatchProcessError(
                'Please select a Type of Request.',
                'Validation Error',
                'warning'
            );
            return;
        }

        if (!this.paymentExtensionReason) {
            this.dispatchProcessError(
                'Please provide a Payment Extension Reason.',
                'Validation Error',
                'warning'
            );
            return;
        }

        if (!this.uploadedFiles.length) {
            this.dispatchProcessError(
                'Please upload the Proof of Request document before submitting.',
                'Validation Error',
                'warning'
            );
            return;
        }

        this.isLoading = true;

        try {
            const attachmentWarning = await processInstallments({
                installmentId: this.selectedInstallmentId,
                extensionDate: this.extensionDate,
                typeOfRequest: this.typeOfRequest,
                paymentExtensionReason: this.paymentExtensionReason,
                approvalJustification: this.approvalJustification,
                uploadedFiles: this.uploadedFiles.map(file => ({
                    name: file.name,
                    documentId: file.documentId,
                    contentVersionId: file.contentVersionId
                }))
            });

            this.dispatchEvent(
                new CustomEvent('processsuccess', {
                    detail: {
                        installmentId:
                            this.selectedInstallmentId,
                        extensionDate:
                            this.extensionDate,
                        message:
                            'Payment Extension process has been initiated successfully.',
                        warning: attachmentWarning || null
                    },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            console.error(
                'Payment Extension error:',
                error
            );

            this.dispatchProcessError(
                this.getErrorMessage(error)
            );
        } finally {
            this.isLoading = false;
        }
    }

    reportDateValidity() {
        const dateInput = this.template.querySelector(
            'lightning-input[name="extensionDate"]'
        );

        if (dateInput) {
            dateInput.setCustomValidity(
                this.dateValidationMessage || ''
            );

            dateInput.reportValidity();
        }
    }

    dispatchProcessError(
        message,
        title = 'Error',
        variant = 'error'
    ) {
        this.dispatchEvent(
            new CustomEvent('processerror', {
                detail: {
                    title,
                    message,
                    variant
                },
                bubbles: true,
                composed: true
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item.message)
                .join(', ');
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred while initiating the Payment Extension process.';
    }

    get minimumExtensionDate() {
        if (!this.selectedRecord?.MilestoneDate__c) {
            return null;
        }

        return this.addDays(
            this.selectedRecord.MilestoneDate__c,
            1
        );
    }

    get maximumExtensionDate() {
        if (!this.selectedRecord?.NextInstallmentDate) {
            return null;
        }

        return this.addDays(
            this.selectedRecord.NextInstallmentDate,
            -1
        );
    }

    addDays(dateValue, numberOfDays) {
        const date = new Date(`${dateValue}T00:00:00Z`);

        date.setUTCDate(
            date.getUTCDate() + numberOfDays
        );

        return date.toISOString().split('T')[0];
    }

    addMonths(dateValue, numberOfMonths) {
        const date = new Date(`${dateValue}T00:00:00Z`);

        date.setUTCMonth(
            date.getUTCMonth() + numberOfMonths
        );

        return date.toISOString().split('T')[0];
    }

    get isCustomExtension() {
        return this.extensionOption === 'custom';
    }

    get hasInstallments() {
        return this.installments.length > 0;
    }

    get noOfDays() {
        if (
            !this.selectedRecord?.MilestoneDate__c ||
            !this.extensionDate
        ) {
            return null;
        }

        const milestoneDate = this.toComparableDate(
            this.selectedRecord.MilestoneDate__c
        );

        const extensionDate = this.toComparableDate(
            this.extensionDate
        );

        return Math.round(
            (extensionDate - milestoneDate) /
                (1000 * 60 * 60 * 24)
        );
    }

   get isSubmitDisabled() {
    return (
        !this.selectedInstallmentId ||
        !this.extensionDate ||
        !this.typeOfRequest ||
        !this.paymentExtensionReason ||
        !this.uploadedFiles.length ||
        this.isLoading
    );
}
}