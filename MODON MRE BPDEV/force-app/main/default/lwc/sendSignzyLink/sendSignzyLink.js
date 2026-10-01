import { LightningElement,api,track,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import sendkycformLWC from '@salesforce/apex/CustomerKYCHandler.sendKYCForm';
export default class SendSignzyLink extends LightningElement {
    isLoading = false;
     @api recordId;
     @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            this.isLoading = true;
           if (currentPageReference) {
              this.recordId = currentPageReference.state.recordId;
           }
        }
    connectedCallback(){
        this.isLoading = true;
        sendkycformLWC({accountId:this.recordId}).then(result => {
            this.isLoading = false; 
            if(result === null || result === undefined) {
                const Errorevent = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Please check with your administrator!',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(Errorevent);
                // Fix by Arvind 05-Jun-2026: Removed premature CloseActionScreenEvent from here.
           
            }else{
                if(result.includes('Error')){
                    const Errorevent = new ShowToastEvent({
                        title: 'Error!',
                        message: result,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(Errorevent);
                    // Fix by Arvind 05-Jun-2026: Close screen after showing error toast.
                    this.dispatchEvent(new CloseActionScreenEvent());
                }else{
                const event = new ShowToastEvent({
                        title: 'Success!',
                        message: result,
                        variant: 'success',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(event);
            }
            this.dispatchEvent(new CloseActionScreenEvent());
        }
        })
        .catch(error => {
            if(result === null || result === undefined) {
                const Errorevent = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Please check with your administrator!',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(Errorevent);
            }
            this.isLoading = false;
            console.error('Error fetching KYC link:', error);
        });
      
    }
}