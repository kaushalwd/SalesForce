import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ModonPayLoader extends LightningModal {
    @api recordId; 

    // Hardcoded URL property for your iframe
    get targetWebpageUrl() {
        return 'https://modon-pay-staging.modon-built-different.com/';
    }

    // Triggered when clicking your HTML button
    handleCloseModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}