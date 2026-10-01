import { LightningElement, api, wire, track } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent }           from 'lightning/platformShowToastEvent';
import ACCOUNT_OBJECT                  from '@salesforce/schema/Account';
import RT_NAME_FIELD                        from '@salesforce/schema/Account.RecordType.Name';
import PHONE_FIELD                 from '@salesforce/schema/Account.Phone';
import PERSON_MOBILE_PHONE_FIELD from '@salesforce/schema/Account.PersonMobilePhone';


export default class MaskedPhone extends LightningElement {
    @api recordId; 
    @track phoneNumber;
    @wire(getRecord, { recordId: '$recordId', fields: [PERSON_MOBILE_PHONE_FIELD, PHONE_FIELD] })
    account;
    
 
    @wire(getRecord, { recordId: '$recordId', fields: [RT_NAME_FIELD] })
    record;


    get cleanDigits() {
        const recordTypeName = getFieldValue(this.record.data, RT_NAME_FIELD);
        if (recordTypeName ==='Organizaion Account' || recordTypeName === 'Broker Agency') {
            const phone = getFieldValue(this.account.data, PHONE_FIELD);
            this.phoneNumber= phone? phone.replace(/[^0-9+]/g, '') : null;
            return this.phoneNumber;
        }
        
        const raw = getFieldValue(this.account.data, PERSON_MOBILE_PHONE_FIELD);
       
        this.phoneNumber = raw ? raw.replace(/[^0-9+]/g, '') : null;
        return this.phoneNumber;
    }   
    
   onCallButtonClick() {

        
        if (!this.phoneNumber) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Failed',
                    message: 'Phone number is not available on this Account.',
                    variant: 'warning',
                    mode: 'dismissable'
                })
            );
            return;
        }
        const ctiCmp = this.template.querySelector('[data-id="ctiDial"]');
        if (ctiCmp) {
            ctiCmp.click();
            console.clear();
            // You can optionally show a toast or do UI feedback here
        }
}
   }