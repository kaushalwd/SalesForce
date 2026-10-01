import { LightningElement, api, track } from 'lwc';
import showChequeDetails from '@salesforce/apex/ManageChequesController.showChequeDetails'; 
import { loadStyle } from 'lightning/platformResourceLoader';
import CUSTOM_MODAL_WIDTH from '@salesforce/resourceUrl/CustomModalWidth';

export default class ManageChequefromSO extends LightningElement {
    @api recordId; // Record ID of the current record;
    @track showChequeDetails = false; // Flag to control visibility of cheque details component     
    connectedCallback(){
        if(this.recordId) {
            // Call the Apex method to check if cheque details should be shown
            this.getChequeDetails();
        } else {
            console.error('No record ID provided.');
        }
        loadStyle(this, CUSTOM_MODAL_WIDTH)
        .catch(error => {
            console.error('Error loading CSS:', error);
        }); 

    }
}