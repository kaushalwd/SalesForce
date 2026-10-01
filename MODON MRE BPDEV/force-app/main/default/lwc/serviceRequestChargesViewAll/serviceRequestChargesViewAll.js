import { LightningElement, wire, api } from 'lwc';
import getChargesByServiceRequest from '@salesforce/apex/ChargeController.getCharges';
import deleteCharge from '@salesforce/apex/ChargeController.deleteCharge';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ServiceRequestChargesViewAll extends LightningElement {
    @api recordId;
    charges;
    error;

    columns = [
        { label: 'Charge Name', fieldName: 'Name', type: 'text' },
        { label: 'Paid Amount', fieldName: 'Paid_Amount__c', type: 'currency' },
        { label: 'Remaining Amount', fieldName: 'Remaining_Amount__c', type: 'currency' },
        { label: 'Payment Status', fieldName: 'PaymentStatus__c', type: 'text' }, {
            type: 'action',
            typeAttributes: { 
                rowActions: [
                    { label: 'Edit', name: 'edit' },
                    { label: 'Delete', name: 'delete' }
                ]
            },
        }
    ];

    @wire(getChargesByServiceRequest, { serviceRequestId: '$recordId' })
    wiredCharges({ error, data }) {
        if (data) {
            this.charges = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.charges = undefined;
        }
    }


    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            
            case 'edit':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        actionName: 'edit'
                    }
                });
                break;

                case 'delete':
                this.deleteCharge(row.Id);
                break;
        }
    }

    deleteCharge(chargeId) {
        if (!confirm('Are you sure you want to delete this charge?')) {
            return;
        }

        deleteCharge({ chargeId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Charge deleted successfully',
                        variant: 'success'
                    })
                );
                return refreshApex(this.wiredData);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Error deleting charge: ' + error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}