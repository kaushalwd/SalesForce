import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = ['SalesOrder__c.Is_Refund__c'];

export default class SoRefundindicator extends LightningElement {
 @api recordId;
    refundStatus;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.refundStatus = data.fields.Is_Refund__c.value;
        } else if (error) {
            console.error('Error fetching SalesOrder:', error);
        }
    }

    get showBanner() {
        return this.refundStatus === 'In Progress' || this.refundStatus === 'Successful';
    }

    get bannerMessage() {
        if (this.refundStatus === 'In Progress') {
            return 'Refund Process is in Progress';
        }
        if (this.refundStatus === 'Successful') {
            return 'Refund Successful';
        }
        return '';
    }

    get bannerClass() {
        if (this.refundStatus === 'In Progress') {
            return 'banner warning';
        }
        if (this.refundStatus === 'Successful') {
            return 'banner success';
        }
        return 'banner';
    }
}