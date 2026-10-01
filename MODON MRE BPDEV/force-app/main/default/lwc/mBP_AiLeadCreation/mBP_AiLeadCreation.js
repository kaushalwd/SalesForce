import { LightningElement, track } from 'lwc';
import createLeadFromAI from '@salesforce/apex/GeminiDocumentValidator.createLeadFromAI';

export default class AiLead3D extends LightningElement {

    // 🔹 STATE
    @track userInput = '';
    @track isLoading = false;
    @track isModalOpen = false;
    @track showToast = false;
    @track toastMessage = '';
    @track toastType = ''; // success / error

    // ============================
    // 🔥 MODAL CONTROL
    // ============================

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    // ============================
    // 🔥 INPUT CHANGE
    // ============================

    handleChange(event) {
        this.userInput = event.target.value;
    }

    // ============================
    // 🔥 SEND REQUEST
    // ============================

    handleSend() {


        if (!this.userInput || this.userInput.trim() === '') {
            this.showCustomToast('Please enter input', 'error');
            return;
        }

        this.isLoading = true;


        createLeadFromAI({ userInput: this.userInput })
            .then(result => {


                this.isLoading = false;

                if (result === 'SUCCESS') {

                    this.userInput = '';
                    this.isModalOpen = false;

                    this.showCustomToast('Lead Created Successfully 🚀', 'success');

                } else {

                    this.showCustomToast(result, 'error');
                }
            })
            .catch(error => {

                console.error('Apex Error:', JSON.stringify(error));

                this.isLoading = false;

                let msg = 'Something went wrong';

                if (error?.body?.message) {
                    msg = error.body.message;
                }

                this.showCustomToast(msg, 'error');
            });
    }

    // ============================
    // 🔥 CUSTOM TOAST (PREMIUM)
    // ============================

    showCustomToast(message, type) {

        this.toastMessage = message;
        this.toastType = type;
        this.showToast = true;


        // Auto close
        setTimeout(() => {
            this.showToast = false;
        }, 3000);
    }
}