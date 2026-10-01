import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import SALES_ORDER_DEFAULT from '@salesforce/schema/SalesOrder__c.Sales_Order_Default__c';
import LEGALLY_FLAGGED from '@salesforce/schema/SalesOrder__c.Legally_Flagged__c';

export default class SalesOrderBanner extends LightningElement {

    @api recordId;

    showDefaultBanner = false;
    showLegalBanner = false;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [SALES_ORDER_DEFAULT, LEGALLY_FLAGGED]
    })
    wiredRecord({ error, data }) {
        if (data) {
            const isDefault = data.fields.Sales_Order_Default__c.value;
            const isLegal = data.fields.Legally_Flagged__c.value;

            this.showDefaultBanner = isDefault;
            this.showLegalBanner = isLegal;
        } else if (error) {
            console.error('Error fetching Sales Order:', error);
        }
    }
}