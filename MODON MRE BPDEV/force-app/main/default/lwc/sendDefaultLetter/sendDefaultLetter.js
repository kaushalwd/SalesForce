import { LightningElement, api, wire } from 'lwc';

import processLetters from '@salesforce/apex/SendDefaultLetterFromBp.processLetters';
import DEFAULT1 from '@salesforce/schema/Business_Process__c.Default_Letter1_Sent_Date__c';
import DEFAULT2 from '@salesforce/schema/Business_Process__c.Default_Letter2_Sent_Date__c';
import TERMINATION from '@salesforce/schema/Business_Process__c.Termination_letter_Sent_Date__c';
import { getRecord } from 'lightning/uiRecordApi';
const FIELDS = [
    DEFAULT1,
    DEFAULT2,
    TERMINATION
];

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendDefaultLetter extends LightningElement {

    @api recordId;
    @wire(getRecord, {
    recordId: '$recordId',
    fields: FIELDS
})
bpRecord;

get isSendDisabled() {

    if (!this.selectedType || !this.bpRecord.data) {
        return false;
    }

    const fields = this.bpRecord.data.fields;

    if (this.selectedType === 'Default Notice 1') {
        return fields.Default_Letter1_Sent_Date__c.value != null;
    }

    if (this.selectedType === 'Default Notice 2') {
        return fields.Default_Letter2_Sent_Date__c.value != null;
    }

    if (this.selectedType === 'Termination Letter') {
        return fields.Termination_letter_Sent_Date__c.value != null;
    }

    return false;
}

    selectedType;

    options = [
        {
            label: 'Default Notice 1',
            value: 'Default Notice 1'
        },
        {
            label: 'Default Notice 2',
            value: 'Default Notice 2'
        },
        {
            label: 'Termination Letter',
            value: 'Termination Letter'
        }
    ];

    handleChange(event) {

        this.selectedType = event.detail.value;
        const fields = this.bpRecord.data.fields;
        if (
        (this.selectedType === 'Default Notice 1' && fields.Default_Letter1_Sent_Date__c.value) ||
        (this.selectedType === 'Default Notice 2' && fields.Default_Letter2_Sent_Date__c.value) ||
        (this.selectedType === 'Termination Letter' && fields.Termination_letter_Sent_Date__c.value)
    ) {
        this.showToast(
            'Error',
            `${this.selectedType} has already been sent.`,
            'error'
        );
        return;
    }
    }

    async sendLetter() {

        if (!this.selectedType) {

            this.showToast(
                'Error',
                'Please select a letter type',
                'error'
            );

            return;
        }

     const fields = this.bpRecord.data.fields;

    if (
        (this.selectedType === 'Default Notice 1' && fields.Default_Letter1_Sent_Date__c.value) ||
        (this.selectedType === 'Default Notice 2' && fields.Default_Letter2_Sent_Date__c.value) ||
        (this.selectedType === 'Termination Letter' && fields.Termination_letter_Sent_Date__c.value)
    ) {
        this.showToast(
            'Error',
            `${this.selectedType} has already been sent.`,
            'error'
        );
        return;
    }
        try {

            const result = await processLetters({
                recId: this.recordId,
                type: this.selectedType
            });

            this.showToast(
                'Success',
                result,
                'success'
            );

        }
        catch(error) {

            let message = 'Unknown error';

            if (error.body && error.body.message) {
                message = error.body.message;
            }

            this.showToast(
                'Error',
                message,
                'error'
            );
        }
    }

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}