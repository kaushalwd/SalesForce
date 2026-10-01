import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class BusinessProcessApprovalDocuments extends NavigationMixin(LightningElement) {
    @api documents = [];

    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }

    handleView(event) {
        const contentDocumentId = event.currentTarget.dataset.id;
        if (!contentDocumentId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: contentDocumentId
            }
        });
    }
}