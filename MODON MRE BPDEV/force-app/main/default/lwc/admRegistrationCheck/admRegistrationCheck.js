import { LightningElement, api, wire } from 'lwc';
import hasADMRegistration from '@salesforce/apex/ServiceRequestChecker.hasADMRegistration';

export default class AdmRegistrationCheck extends LightningElement {

    @api recordId;

    hasADM = false;
    status;
    admId;
    admName;
    isLoaded = false;
    error;

    // URL for navigation
    get admUrl() {
        return this.admId ? '/' + this.admId : '';
    }

    // Status text color
    get statusClass() {
        if (!this.status) return '';

        switch (this.status.toLowerCase()) {
            case 'completed':
                return 'slds-text-color_success';
            case 'in progress':
                return 'slds-text-color_warning';
            case 'new':
                return 'slds-text-color_default';
            default:
                return '';
        }
    }

    // 🔥 Container color logic (RED when ADM exists, GREEN when not)
            get containerClass() {
            return this.hasADM
            ? 'slds-box slds-m-around_medium success-box'   // ADM exists → GREEN
            : 'slds-box slds-m-around_medium error-box';    // No ADM → RED
            }

    @wire(hasADMRegistration, { serviceRequestId: '$recordId' })
    wiredResult({ data, error }) {
        this.isLoaded = true;

        if (data) {
            this.hasADM = data.hasADM;
            this.status = data.status;
            this.admId = data.recordId;
            this.admName = data.name;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.hasADM = false;
        }
    }
}