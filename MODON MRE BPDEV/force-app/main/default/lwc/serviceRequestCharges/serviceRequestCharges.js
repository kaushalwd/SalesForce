import { LightningElement, wire, api } from 'lwc';
import getCharges from '@salesforce/apex/ChargeController.getCharges';
import deleteCharge from '@salesforce/apex/ChargeController.deleteCharge';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';


const columns = [
    { label: 'Charge Name', fieldName: 'Name', type: 'text', cellAttributes: { alignment: 'left' } },
    { label: 'Paid Amount', fieldName: 'Paid_Amount__c', type: 'currency' },
    { label: 'Remaining Amount', fieldName: 'Remaining_Amount__c', type: 'currency' },
    { label: 'Payment Status', fieldName: 'PaymentStatus__c', type: 'text' },
    { label: 'Type', fieldName: 'Type__c', type: 'text' },
    {
        type: 'action',
        typeAttributes: { 
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        },
    }
];

export default class ChargeList extends NavigationMixin(LightningElement) {
    @api recordId; // Service Request ID
    charges = [];
    columns = columns;
    error;

    @wire(getCharges, { serviceRequestId: '$recordId' })
    wiredCharges({ data, error }) {
        if (data) {
            this.charges = data;
        } else if (error) {
            this.error = error;
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


    handleViewAll() {
        
        var compDefinition = {
            componentDef: "c:serviceRequestChargesViewAll",
            attributes: {
                recordId: this.recordId
            }
        };
        // Base64 encode the compDefinition JS object
        var encodedCompDef = btoa(JSON.stringify(compDefinition));
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedCompDef
            }
        });

       

        
    }
}