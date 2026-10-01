import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Case.Contact.Name',
    'Case.Contact.Title',
    'Case.Contact.Masked_Email__c',
    'Case.Contact.Masked_Phone__c',
    'Case.Contact.Account.Name',
    'Case.Contact.AccountId'
];

export default class RelatedRecordContactDetails extends LightningElement {
    @api recordId; 
    contact; 

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ error, data }) {
        if (data) {
            this.contact = data.fields.Contact.value
                ? {
                      Name: data.fields.Contact.value.fields.Name.value,
                      Title: data.fields.Contact.value.fields.Title.value || 'N/A',
                      Email: data.fields.Contact.value.fields.Masked_Email__c.value || 'N/A',
                      Phone: data.fields.Contact.value.fields.Masked_Phone__c.value || 'N/A',
                      Account: {
                          Name:
                              data.fields.Contact.value.fields.Account.value?.fields.Name
                                  .value || 'N/A',
                          AccountId: data.fields.Contact.value.fields.AccountId.value
                      }
                  }
                : null;
        } else if (error) {
            console.error('Error fetching Contact Details:', error);
        }
    }
}