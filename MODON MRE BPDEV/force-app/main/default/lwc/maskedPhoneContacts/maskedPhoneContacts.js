import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent }           from 'lightning/platformShowToastEvent';
import MOBILE_PHONE_FIELD from '@salesforce/schema/Contact.MobilePhone';


export default class MaskedPhone extends LightningElement {
    @api recordId; 
    
    @wire(getRecord, { recordId: '$recordId', fields: [MOBILE_PHONE_FIELD] })
    contact;
    
 



    get cleanDigits() {
        const raw = getFieldValue(this.contact.data, MOBILE_PHONE_FIELD);
       
        return raw ? raw.replace(/[^0-9+]/g, '') : null;
    }   
    
   onCallButtonClick() {

        
        const raw = getFieldValue(this.contact.data, MOBILE_PHONE_FIELD);
        if (!raw) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Failed',
                    message: 'Phone number is not available on this Contact.',
                    variant: 'warning',
                    mode: 'dismissable'
                })
            );
            return;
        }
        const ctiCmp = this.template.querySelector('[data-id="ctiDial"]');
        if (ctiCmp) {
            ctiCmp.click();
            //console.clear();
            // You can optionally show a toast or do UI feedback here
        }
}
   }