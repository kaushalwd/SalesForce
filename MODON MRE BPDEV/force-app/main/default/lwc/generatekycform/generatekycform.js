import { LightningElement, api, wire } from 'lwc';
import Validatekycform from '@salesforce/apex/CustomerKYCHandler.validateGenerateKYCDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class Generatekycform extends LightningElement {
    @api recordId;
    isLoading = false;
    hasExecuted = false;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        if (!ref) return;

        this.recordId ??= ref.attributes?.recordId
            ?? ref.state?.recordId
            ?? ref.state?.c__recordId;

        this.runValidation();
    }

    connectedCallback() {
        this.runValidation();
    }

    runValidation() {
        if (!this.recordId || this.hasExecuted) {
            return;
        }

        this.hasExecuted = true;
        this.isLoading = true;

        Validatekycform({ docId: this.recordId })
            .then((result) => {
                if (result && result.startsWith('Error')) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result,
                            variant: 'error',
                            mode: 'sticky'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'We have initiated your request. Please come back after a while.',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );
                }

                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                console.error('Error during KYC Form Validation:', error);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error?.body?.message || 'Something went wrong. Please contact admin.',
                        variant: 'error',
                        mode: 'sticky'
                    })
                );

                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }
}