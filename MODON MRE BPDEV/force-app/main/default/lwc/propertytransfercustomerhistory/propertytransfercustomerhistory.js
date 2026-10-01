/**
 * @description       : 
 * @author            : Manoj
 * @group             : 
 * @last modified on  : 02-25-2026
 * @last modified by  : Manoj
**/
import { LightningElement, api, wire } from 'lwc';
import getAccountHistory from '@salesforce/apex/PropertyTransferCustomerHistory.getAccountHistory';

export default class propertytransfercustomerhistory extends LightningElement {

    @api recordId; // SalesOrder Id

    historyData;
    error;

    @wire(getAccountHistory, { salesOrderId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.historyData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.historyData = undefined;
        }
    }

    columns = [
        { label: 'Old Account', fieldName: 'oldValue' },
        { label: 'New Account', fieldName: 'newValue' },
        { label: 'Changed Date', fieldName: 'changedDate', type: 'date' },
        { label: 'Changed By', fieldName: 'changedBy' }
    ];
}