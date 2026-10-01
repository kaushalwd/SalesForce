import { LightningElement,api,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import getSignzyStatus from '@salesforce/apex/CustomerKYCHandler.getSignzyJourney';

export default class Getsignzystatus extends LightningElement {
    isLoading = false;
    @api recordId;
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        this.isLoading = true;
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }
    connectedCallback() {
        this.isLoading = true;
        getSignzyStatus({ kycId: this.recordId })
            .then(result => {
                this.isLoading = false;
                if (result === null || result === undefined) {
                    const errorEvent = new ShowToastEvent({     
                        title: 'Error!',        
                        message: 'Please check with your administrator!',
                        variant: 'error',
                        mode: 'dismissable'     
                    });
                    this.dispatchEvent(errorEvent);
                } else {
                    const successEvent = new ShowToastEvent({   
                        title: 'Success!',       
                        message: result,
                        variant: 'success',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(successEvent);
                }
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.isLoading = false;
                const errorEvent = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Please check with your administrator!',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(errorEvent);
                console.error('Error fetching KYC status:', error);
            });
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Additional methods can be added here if needed
}