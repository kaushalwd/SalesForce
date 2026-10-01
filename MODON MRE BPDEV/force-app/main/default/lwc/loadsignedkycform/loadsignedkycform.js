import { LightningElement,wire } from 'lwc';
import getSignedKYCDocument from '@salesforce/apex/CustomerKYCHandler.getSignedKYCDocument';
import { CurrentPageReference } from 'lightning/navigation';
export default class Loadsignedkycform extends LightningElement {
    @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            this.isLoading = true;
            if (currentPageReference) {
                this.recordId = currentPageReference.state.id;
            }
            // this.isLoading = false;
        }
    connectedCallback() {
        getSignedKYCDocument({ docId: this.recordId })
            .catch(() => {});     
    }
}