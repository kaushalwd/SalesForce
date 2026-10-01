import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class InvoiceBundleDetailButton extends NavigationMixin(LightningElement) {
    @api recordId;

      @api invoke(){
    this[NavigationMixin.Navigate]({
        type: 'standard__component',
        attributes: {
            componentName: 'c__invoiceLineViewerWrapper'
        },
        state: {
            c__bundleId: this.recordId
        }
    });
}

}