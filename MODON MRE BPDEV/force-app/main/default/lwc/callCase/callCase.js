import { LightningElement, api, wire, track } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent }           from 'lightning/platformShowToastEvent';
import VISITOR_SEARCH_PHONE from '@salesforce/schema/Case.Visitor_Phone_Search__c';
import CUSTOMER_PHONE       from '@salesforce/schema/Case.Customer_Phone__c';

export default class MaskedPhoneCase extends LightningElement {
    @api recordId;
    @track phoneNumber;

    @wire(getRecord, { recordId: '$recordId', fields: [VISITOR_SEARCH_PHONE, CUSTOMER_PHONE] })
    caseRecord;

    get cleanDigits() {

        const visitorPhone  = getFieldValue(this.caseRecord.data, VISITOR_SEARCH_PHONE);
        const customerPhone = getFieldValue(this.caseRecord.data, CUSTOMER_PHONE);


        const raw = visitorPhone || customerPhone || null;

        this.phoneNumber = raw ? raw.replace(/[^0-9+]/g, '') : null;
        return this.phoneNumber;
    }

    onCallButtonClick() {

        if (!this.phoneNumber) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Failed',
                    message: 'Neither Visitor Search Phone nor Customer Phone is available on this Case.',
                    variant: 'warning',
                    mode: 'dismissable'
                })
            );
            return;
        }

        const ctiCmp = this.template.querySelector('[data-id="ctiDial"]');
        if (ctiCmp) {
            ctiCmp.click();
        }
    }
}