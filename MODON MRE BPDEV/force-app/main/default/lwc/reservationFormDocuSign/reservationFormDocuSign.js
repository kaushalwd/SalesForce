import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateDocusignURLReservationForm from '@salesforce/apex/ReservationFormDocuSignController.generateDocusignURLReservationForm';

export default class ReservationFormDocuSign extends LightningElement {
    @api recordId; // This will be automatically passed from action button

    connectedCallback() {
        // recordId is automatically passed by action button (the Document__c record ID)
        this.sendReservationFormForSignature();
    }

    sendReservationFormForSignature() {
        if (!this.recordId) {
            this.showToast('Error', 'Document ID is required', 'error');
            this.closeModal();
            return;
        }

        generateDocusignURLReservationForm({ DocumentId: this.recordId })
            .then((result) => {
                if (result === 'sent') {
                    this.showToast(
                        'Success',
                        'Reservation Form sent for signature successfully!',
                        'success'
                    );
                    // Close modal after 2 seconds
                    setTimeout(() => {
                        this.closeModal();
                    }, 2000);
                } else {
                    this.showToast('Error', result, 'error');
                    this.closeModal();
                }
            })
            .catch((error) => {
                console.error('Error:', error);
                this.showToast(
                    'Error',
                    'An error occurred while sending the document. Please try again.',
                    'error'
                );
                this.closeModal();
            });
    }

    closeModal() {
        // Dispatch event to close modal in parent component
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);

        // If this is in a modal context, try to close it
        const modal = this.closest('[role="dialog"]');
        if (modal) {
            const closeButton = modal.querySelector('[aria-label="Close"]');
            if (closeButton) {
                closeButton.click();
            }
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
}