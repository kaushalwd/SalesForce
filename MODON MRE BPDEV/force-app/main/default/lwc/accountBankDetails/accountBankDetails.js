import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import ACCOUNT_FIELD from '@salesforce/schema/Business_Process__c.Account__c';

const FIELDS = [ACCOUNT_FIELD];

export default class AccountBankDetails extends LightningElement {

    @api recordId;

    accountId;

    // Read-only by default
    isReadOnly = true;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    wiredBusinessProcess({ data, error }) {

        if (data) {

            this.accountId = getFieldValue(
                data,
                ACCOUNT_FIELD
            );

        } else if (error) {

            console.error(
                'Error loading Business Process:',
                error
            );

            this.showToast(
                'Error',
                'Unable to retrieve Account from Business Process.',
                'error'
            );
        }
    }

    /**
     * Pencil button clicked
     */
    handleEdit() {

        this.isReadOnly = false;
    }

    /**
     * Cancel editing
     */
    handleCancel() {

        this.isReadOnly = true;

        // Reset fields to their original values
        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );

        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
    }

    /**
     * Account successfully updated
     */
    handleSuccess(event) {

        this.isReadOnly = true;

        this.showToast(
            'Success',
            'Bank details updated successfully.',
            'success'
        );
    }

    /**
     * Error while updating Account
     */
    handleError(event) {

        console.error(
            'Error updating Account:',
            event.detail
        );

        this.showToast(
            'Error',
            event.detail?.message ||
            'Failed to update bank details.',
            'error'
        );
    }

    /**
     * Show Toast
     */
    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}