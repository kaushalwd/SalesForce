import { LightningElement,api,wire,track } from 'lwc';
import fetchRecords from '@salesforce/apex/LookupController.lookUpSearch';

export default class GenericLookupLwc extends LightningElement {
    @api objname;
    @api iconname;
    @api filter = '';
    @api searchPlaceholder='Search';
    @api selectedName;
    @track records;
    @api isValueSelected = false;
    @track blurTimeout;
    message;
    searchTerm;

    @track boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
    @track inputClass = '';

    @api displayField = 'Name';// Default to Name if not specified

    @api clearRequested = false;

    get fieldsToQuery() {
        return this.displayField !== 'Name' ? 'Id, Name, '+this.displayField : 'Id, Name ';
    }
    
    fetchData() {
        fetchRecords({
            displayField : this.displayField,
            searchTerm : this.searchTerm,
            myObject : this.objname,
            filter : this.filter,
            fieldsToQuery : this.fieldsToQuery
        })
        .then(result => {
            if(result && result.length > 0) {
                // Add a displayValue property to each record based on the displayField
                this.records = result.map(record => {
                    return {
                        ...record,
                        displayValue: this.displayField !== 'Name' ? 
                                      record[this.displayField] || record.Name : 
                                      record.Name
                    };
                });
                //this.records = result;
            } else {
                this.message = "No Records Found for '" + this.searchTerm + "'";
            }
        }).catch(error => {
            this.message = error.message;
        })
    }

    
        handleClick() {
            this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus slds-is-open';
        }
        
        handleBlur() {
            setTimeout(() => { // Timeout to allow item selection before hiding
                this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
            }, 200);
        }
    
    onSelect(event) {
        let selectedId = event.currentTarget.dataset.id;
        this.bookingIdVar = selectedId;
        let selectedName = event.currentTarget.dataset.name;
        const valueSelectedEvent = new CustomEvent('lookupselected', {detail:  selectedId });
        this.dispatchEvent(valueSelectedEvent);
        this.isValueSelected = true;
        this.selectedName = selectedName;
        if(this.objname == 'Process_Flow__c' || this.objname == 'Process_Flow_Step__c' || this.objname=='Checklist_Metadata__c') {
            const valueSelectedNameEvent = new CustomEvent('lookupselectedname', {detail:  selectedName });
            this.dispatchEvent(valueSelectedNameEvent);
        }
        this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
    }

    handleRemovePill() { 
        this.isValueSelected = false;
        this.searchTerm = '';
        this.selectedName = ''; // Reset selected name
        this.bookingIdVar = null; // Reset selected ID
        this.records = []; // Clear previous search results
        this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        
        this.dispatchEvent(new CustomEvent('clearlookup', { detail: true }));
    }
        

    onChange(event) {
        this.searchTerm = event.target.value;
        if(this.searchTerm){
            this.fetchData();
        }
    }

    @api
    clearLookup() { 
        this.isValueSelected = false;
        this.searchTerm = '';
        this.selectedName = ''; // Reset selected name
        this.bookingIdVar = null; // Reset selected ID
        this.records = []; // Clear previous search results
        this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';

        // Reset the input field value
        const inputField = this.template.querySelector('input');
        if (inputField) {
            inputField.value = '';
        }
        
        //this.dispatchEvent(new CustomEvent('clearlookup', { detail: true }));
    }

}