import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, updateRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';

import ID_FIELD from '@salesforce/schema/Account.Id';
import AGENCY_STATUS_FIELD from '@salesforce/schema/Account.Agency_Status__c';
import RECORD_TYPE_FIELD from '@salesforce/schema/Account.RecordType.DeveloperName';


function reduceErrors(error) {
    if (!error) return 'Unknown error';

    // UI API errors
    if (Array.isArray(error.body?.output?.errors) && error.body.output.errors.length) {
        return error.body.output.errors.map(e => e.message).join(', ');
    }

    // Field-level errors from UI API
    const fieldErrors = error.body?.output?.fieldErrors;
    if (fieldErrors && Object.keys(fieldErrors).length) {
        const msgs = [];
        for (const field of Object.keys(fieldErrors)) {
            msgs.push(...fieldErrors[field].map(e => `${field}: ${e.message}`));
        }
        return msgs.join(', ');
    }

    // Page-level errors
    if (Array.isArray(error.body?.pageErrors) && error.body.pageErrors.length) {
        return error.body.pageErrors.map(e => e.message).join(', ');
    }

    // Array of errors
    if (Array.isArray(error.body) && error.body.length) {
        return error.body.map(e => e.message).join(', ');
    }

    // Standard message
    if (typeof error.body?.message === 'string') return error.body.message;
    if (typeof error.message === 'string') return error.message;

    return JSON.stringify(error);
}


export default class UnblockAccountAction extends LightningElement {
    @api recordId;
    currentStatus;
    recordTypeDevName;
    isLoading = false;

    @wire(getRecord, { recordId: '$recordId', fields: [AGENCY_STATUS_FIELD, RECORD_TYPE_FIELD] })
    wiredAccount({ data, error }) {
        if (data) {
            this.currentStatus = data.fields.Agency_Status__c.value;
            this.recordTypeDevName = data.fields.RecordType.value?.fields?.DeveloperName?.value;
        } else if (error) {
            this.toast('Error', 'Could not load account.', 'error');
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConfirm() {
        if (this.recordTypeDevName !== 'Broker_Agency') {
            this.toast('Not allowed', 'This action is only for Broker Agency accounts.', 'warning');
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        if (this.currentStatus === 'Active') {
            this.toast('Already active', 'Account is already Active.', 'info');
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        this.isLoading = true;
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[AGENCY_STATUS_FIELD.fieldApiName] = 'Active';

            await updateRecord({ fields });

            this.toast(
                'Success',
                'Account unblocked. Related agents and users will be reactivated.',
                'success'
            );
            getRecordNotifyChange([{ recordId: this.recordId }]);
        } catch (error) {
            console.error('updateRecord failed', JSON.stringify(error));
            this.toast('Error', reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }


}