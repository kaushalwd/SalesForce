import { LightningElement,api,wire } from 'lwc';
import copyfiles from '@salesforce/apex/SalesOrderStatusAutomationHelper.copyDocumentfromPrimaryContactLWC';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CopydocumentfromCustomer extends LightningElement {
    isLoading = true;
    @api recordId;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        if (!ref) return;
        // Prefer the @api values; fill them only if missing
        this.recordId ??= ref.attributes?.recordId
                    ?? ref.state?.recordId
                    ?? ref.state?.c__recordId;     // in case you passed it as a custom param
    }
    connectedCallback() {
        console.log('Copy Document from Customer Component Loaded');
        copyfiles({ recordId: this.recordId })
            .then((result) => {
                console.log('Copy Document Result:', result);
                if(result.includes('Error')){
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result,
                            variant: 'error',
                            mode: 'sticky'
                        })
                    );
                console.log('Copy Document Successful');
                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());

                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: result,
                            variant: 'success',     // success | error | warning | info
                            mode: 'dismissable'     // dismissable | sticky | pester
                        })
                    );
                    this.isLoading = false;
                    this.dispatchEvent(new CloseActionScreenEvent());
             }
            })
            .catch((error) => {
                console.error('Error during Copy Document:', error);
                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());

            });
    }
}