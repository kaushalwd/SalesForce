import { LightningElement, api, wire } from 'lwc';
import checkDirectDebitStatus from '@salesforce/apex/ServiceRequestChecker.checkDirectDebitStatus';

export default class DirectDebitStatusCheck extends LightningElement {

    @api recordId;

    hasDirectDebit = false;
    isActive = false;
    ddName;
    ddId;
    isLoaded = false;
    error;

    // URL for record navigation
    get ddUrl() {
        return this.ddId ? '/' + this.ddId : '';
    }

    // Status text color (ACTIVE / INACTIVE)
    get statusClass() {
        return this.isActive 
            ? 'slds-text-color_success' 
            : 'slds-text-color_warning';
    }

    // 🔥 Main container color logic (GREEN / RED)
    get containerClass() {
        return this.hasDirectDebit
            ? 'slds-box slds-m-around_medium success-box'
            : 'slds-box slds-m-around_medium error-box';
    }

    @wire(checkDirectDebitStatus, { serviceRequestId: '$recordId' })
    wiredResult({ data, error }) {
        this.isLoaded = true;

        if (data) {
            this.hasDirectDebit = data.hasDirectDebit;
            this.isActive = data.isActive;
            this.ddName = data.name;
            this.ddId = data.recordId;
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }
}