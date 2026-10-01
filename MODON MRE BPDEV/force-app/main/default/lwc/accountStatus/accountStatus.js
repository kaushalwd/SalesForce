import { LightningElement, api, track, wire } from 'lwc';
import getAccountStatusData from '@salesforce/apex/AccountStatusController.getAccountStatusData';

export default class AccountStatus extends LightningElement {
    @api recordId;

    apexResponse;
    loadUI = false;
    @track groupedFields = [];
    @track additionalFields = [];

    connectedCallback() {
        this.additionalFields = [
            { label: 'Payment Extension', value: '0' },
            { label: 'Consolidation', value: '0' },
            { label: 'Unit Upgrade', value: '0' },
            { label: 'Unit Swap', value: '0' },
            { label: 'Payment Plan Swap', value: '0' },
            { label: 'Equity Transfer', value: '0' }
        ];
    }

    @wire(getAccountStatusData, { recordId: "$recordId" })
    wiredData({ error, data }) {
        if (error) {
            console.error('Error fetching account status info:', error);
            this.loadUI = true;
        } else if (data) {
            this.apexResponse = Object.assign({}, data);
            this.groupedFields = Object.keys(this.apexResponse).map(key => ({
                title: key,
                label: key,
                value: this.apexResponse[key] || 'Data Not Available'
            }));

            this.loadUI = true;
        }
    }

    get isEmpty() {
        return this.groupedFields.length === 0;
    }
}