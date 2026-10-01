import { LightningElement, api, track } from 'lwc';

export default class CustomToast extends LightningElement {
    @track visible = false;
    @track message = '';
    @track variant = 'success';

    @api
    show(message, variant = 'success') {
        // Set data first
        this.message = message;
        this.variant = variant;
    
        // Defer visibility toggle to next tick so message + class are ready
        setTimeout(() => {
            this.visible = true;
    
            // Auto-dismiss after 3 sec
            setTimeout(() => {
                this.visible = false;
            }, 3000);
        }, 0);
    }
    

    get toastClass() {
        return `toast ${this.variant}`;
    }
}