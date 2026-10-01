import { LightningElement, track } from 'lwc';
import searchUnits from '@salesforce/apex/SalesOperationUnitSearch.searchUnits';
import { NavigationMixin } from 'lightning/navigation';

export default class salesOperationUnitSearch extends NavigationMixin(LightningElement) {
    @track searchKey = '';
    @track results = [];
    @track noResult = false;

    handleChange(event) {
        this.searchKey = event.target.value;
    }

    handleSearch() {
        if (!this.searchKey) {
            this.results = [];
            this.noResult = true;
            return;
        }

        searchUnits({ searchKey: this.searchKey })
            .then(data => {
                this.results = data;
                this.noResult = data.length === 0;
            })
            .catch(error => {
                console.error(error);
            });
    }

    navigateToRecord(event) {
        const recordId = event.target.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Unit__c',
                actionName: 'view'
            }
        });
    }    
}