import { LightningElement,api,wire } from 'lwc';
import generatePDFMethod from '@salesforce/apex/CommissionStatementHelper.generatePDF';
import { CloseActionScreenEvent } from 'lightning/actions';
import {CurrentPageReference} from 'lightning/navigation';

export default class SaveInvoiceSOAPDF extends LightningElement {
    @api recordId;
    isLoading = true;
     @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            if (currentPageReference) {
                this.recordId = currentPageReference.state.recordId;
            }
        }
    connectedCallback() {
       // alert('Generating PDF for record ID: ' + this.recordId);
        generatePDFMethod({
                bundleId: this.recordId
            }).then(response => {
                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());

            }).catch(error => {
                console.error('Error generating PDF:', error);
                this.isLoading = false;
                this.dispatchEvent(new CloseActionScreenEvent());

            });     
    }
}