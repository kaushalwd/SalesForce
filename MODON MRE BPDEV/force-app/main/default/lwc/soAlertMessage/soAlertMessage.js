import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ALERT_FIELD from '@salesforce/schema/SalesOrder__c.AlertMessage__c';

const FIELDS = [ALERT_FIELD];

export default class SoAlertMessage extends LightningElement {
     @api recordId;

  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  record;

  get message() {
    return getFieldValue(this.record.data, ALERT_FIELD) || '';
  }

  get hasMessage() {
    return this.message && this.message.trim().length > 0;
  }
}