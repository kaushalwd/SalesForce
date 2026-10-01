import { LightningElement, api, wire } from 'lwc';
import getSalesOrderCount from '@salesforce/apex/SalesOrderController.getSalesOrderCount';

export default class SalesOrderCount extends LightningElement {
    @api recordId;

    totalCount      = 0;
    completedCount  = 0;
    newCount        = 0;
    inProgressCount = 0;
    error;

    @wire(getSalesOrderCount, { brokerAgencyId: '$recordId' })
    wiredCount(result) {
        const { data, error } = result;

        if (data && Array.isArray(data)) {
            this.totalCount      = 0;
            this.completedCount  = 0;
            this.newCount        = 0;
            this.inProgressCount = 0;

            data.forEach(item => {
                this.totalCount += item.count;
                if (item.status === 'Completed')  this.completedCount  = item.count;
                if (item.status === 'New')         this.newCount        = item.count;
                if (item.status === 'In Progress') this.inProgressCount = item.count;
            });

            this.error = undefined;

        } else if (error) {
            this.error = error;
            console.error('SalesOrderCount error:', JSON.stringify(error));
        }
    }
}