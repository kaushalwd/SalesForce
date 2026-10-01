import { LightningElement, api, wire } from 'lwc';
import mutate from '@salesforce/apex/CommunicationController.mutate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';

const APPROVAL_FIELD = 'Communication__c.Communication_Approval__c';
const EMAIL_SENT_FIELD = 'Communication__c.Email_Sent__c';

export default class CommunicationSendEmail extends LightningElement {
    @api recordId;
    isLoading = false;
    approvalStatus;
    emailSent;

    @wire(getRecord, { recordId: '$recordId', fields: [APPROVAL_FIELD, EMAIL_SENT_FIELD] })
    wiredRecord({ data }) {
        if (data) {
            this.approvalStatus = data.fields.Communication_Approval__c.value;
            this.emailSent = data.fields.Email_Sent__c.value;
        }
    }

    get canSend() {
        return this.approvalStatus === 'Approved' && !this.emailSent;
    }

    get isSendDisabled() {
        return !this.canSend;
    }

    get emailSentLabel() {
        return this.emailSent ? 'Yes' : 'No';
    }

    async handleSend() {
        if (!this.canSend) {
            this.showToast('Cannot Send', `Communication must be approved and not already sent. Current: ${this.approvalStatus}, Sent: ${this.emailSent}`, 'error');
            return;
        }

        if (!confirm('Send this communication email to all recipients?')) return;

        this.isLoading = true;
        try {
            const result = await mutate({ action: 'sendEmailAfterApproval', params: { communicationId: this.recordId } });
            this.showToast('Email Sent', result, 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
            setTimeout(() => { eval("$A.get('e.force:refreshView').fire();"); }, 1000);
        } catch (e) {
            this.showToast('Error', e?.body?.message || e?.message || 'Unknown error', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}