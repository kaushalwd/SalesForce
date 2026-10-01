import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import cloneOpportunity from '@salesforce/apex/CloneOpportunityController.cloneOpportunity';
import getRelatedOpportunities from '@salesforce/apex/CloneOpportunityController.getRelatedOpportunities';
import { CurrentPageReference } from 'lightning/navigation';

export default class CloneOpportunityButton extends NavigationMixin(LightningElement) {
    @track isLoading = false;

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(recId) {
        if (recId) {
            this._recordId = recId;
        }
    }
    @api invoke(){
        this.checkForValidOpportunities(); 
    }
    @wire(CurrentPageReference)
    getPageRefParameters(pageRef) {
        this.accId = pageRef?.state?.recordId || pageRef?.attributes?.recordId;
    }

    checkForValidOpportunities() {
        this.isLoading = true;
        getRelatedOpportunities({ accountId: this.recordId })
            .then(existingOpportunities => {
                this.isLoading = false;

                const invalidOpportunities = existingOpportunities.filter(
                    opp => !opp.Sales_Orders__r 
                );
                if (invalidOpportunities.length > 0) {
                    const invalidOpportunityNames = invalidOpportunities.map(opp => opp.Name).join(', ');
                    this.showToast(
                        'Error',
                        `Cloning cannot proceed as the following Opportunities are open: ${invalidOpportunityNames}`,
                        'error'
                    );
                } else {
                    this.handleCloneOpportunity();
                }
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error fetching opportunities:', error);
                this.showToast('Error', 'An error occurred while fetching opportunities.', 'error');
            });
    }

    handleCloneOpportunity() {
        this.isLoading = true;
        cloneOpportunity({ accountId: this.recordId })
            .then((newOpportunityId) => {
                this.isLoading = false;
                if (newOpportunityId) {
                    this.showToast('Success', 'Clone Opportunity created successfully!', 'success');
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: newOpportunityId,
                            objectApiName: 'Opportunity',
                            actionName: 'view'
                        }
                    });
                } else {
                    this.showToast('Error', 'Cloning cannot proceed due to the absence of valid Sales Orders', 'error');
                }
            })
            .catch((error) => {
                this.isLoading = false;
                const message = error && error.body && error.body.message ? error.body.message : 'An unknown error occurred';
                this.showToast('Error', 'An error occurred during cloning: ' + message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}