import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import ServiceRequestPopupModal from 'c/prospectRecordManager';

export default class ServiceRequestPopupLauncher extends LightningElement {
    @api recordId;

    async connectedCallback() {
        try {
            // Open modal large; it’s responsive and centered automatically
            await ServiceRequestPopupModal.open({
                size: 'large',     // large on desktop; gracefully scales on phone
                recordId: this.recordId
            });
        } finally {
            // Close the small Quick Action panel behind the modal
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}