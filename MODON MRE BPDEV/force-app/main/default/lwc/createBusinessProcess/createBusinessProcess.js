import { LightningElement, api, track, wire } from 'lwc';
import createPreRegistration from '@salesforce/apex/CreateBusinessProcess.createPreRegistration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CreateBusinessProcess extends LightningElement {
    
    @api recordId;
    error;
    isLoading = false;
    processFlows = [];
    selectedProcessFlowId;
    selectedProcessFlowName;

    closeAction(){
        this.dispatchEvent(new CloseActionScreenEvent());
      }

      connectedCallback() {
    } 
    
      handleProcessFlowSelection(event) {
        this.selectedProcessFlowId = event.detail;
    }
    handleProcessFlowSelectionName(event) {
        this.selectedProcessFlowName = event.detail;
    }
    handleProcessFlowClear() {
        this.selectedProcessFlowId = null; // Reset selected PRocess ID
        this.selectedProcessFlowName = null; // Reset Selected PRocess Name
    }

   handleClick(event) {
    this.isLoading = true;
    createPreRegistration({ bookingId: this.recordId, processId: this.selectedProcessFlowId }) //, bpValuesToPopulate: null
        .then(result => {
            if (result === 'Selected Process Already Created..!') {
                const toastEvent = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Selected Business process already created',
                    variant: 'error'
                });
                this.dispatchEvent(toastEvent);
            } else {
                const recordUrl = `${window.location.origin}/${result}`;

                // Open the newly created record in a new tab
                window.open(recordUrl, '_blank');

                // Optional: also show a success toast
                const toastEvent = new ShowToastEvent({
                    title: 'Success!',
                    message: 'Business process record created successfully.',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(toastEvent);
            }

            this.closeAction();
        })
        .catch(error => {
            this.error = error.body.message;
            this.isLoading = false;
            const event = new ShowToastEvent({
                title: 'Error..!',
                message: error.body.pageErrors[0].message,
                variant: 'error',
                mode: 'sticky'
            });
            this.dispatchEvent(event);
        });
}

}