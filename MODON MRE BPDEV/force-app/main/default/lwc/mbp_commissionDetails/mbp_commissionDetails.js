import { LightningElement, track } from 'lwc';
import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';

export default class Commissionspage extends LightningElement {
    @track isLoading = true;
    @track showNoAccess = false;
    @track showComingSoon = false;

    connectedCallback() {
        getEditableAccount()
            .then(result => {
                this.isLoading = false;

                if (result && result.brokerType) {
                    const brokerType = result.brokerType;

                    if (brokerType === 'Agent') {
                        this.showNoAccess = true;
                        this.showComingSoon = false;
                    } else {
                        this.showComingSoon = true;
                        this.showNoAccess = false;
                    }
                } else {
                    console.warn('No broker type returned. Showing Coming Soon by default.');
                    this.showComingSoon = true;
                }
            })
            .catch(error => {
                console.error('Error fetching broker info:', error);
                this.isLoading = false;
                this.showNoAccess = true;
            });
    }
}