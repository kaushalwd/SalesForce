import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import MOBILE_PHONE_FIELD from '@salesforce/schema/Lead.MobilePhone';
import { CloseActionScreenEvent }     from 'lightning/actions';


export default class MaskedPhone extends LightningElement {
    @api recordId; 
    
    @wire(getRecord, { recordId: '$recordId', fields: [MOBILE_PHONE_FIELD] })
    lead;
    
    get cleanDigits() {
        const raw = getFieldValue(this.lead.data, MOBILE_PHONE_FIELD);
        return raw ? raw.replace(/[^0-9+]/g, '') : null;
    }   
    
   onCallButtonClick() {
        
        const raw = getFieldValue(this.lead.data, MOBILE_PHONE_FIELD);
        if (!raw) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Failed',
                    message: 'Phone number is not available on this Lead.',
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
           
        }
}
   }