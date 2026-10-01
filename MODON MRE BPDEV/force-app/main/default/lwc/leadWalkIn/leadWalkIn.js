import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAdNameOptions from '@salesforce/apex/LeadWalkInController.getAdNameOptions';
import getSalesExecutiveOptions from '@salesforce/apex/LeadWalkInController.getSalesExecutiveOptions';
import createLead from '@salesforce/apex/LeadWalkInController.createLead';

export default class LeadWalkinForm extends NavigationMixin(LightningElement) {
    @track visitorType = '';
    @track firstName = '';
    @track lastName = '';
    @track mobileNumber = '';
    @track emailAddress = '';
    @track adName = '';
    @track salesExecutive = '';
    @track description = '';
    @track adNameOptions = [];
    @track isLoading = false; // New variable for loading spinner

    visitorTypeOptions = [
        { label: 'Direct', value: 'Direct' },
        { label: 'Broker', value: 'Broker' }
    ];

    @track adNameOptions = [];

    connectedCallback() {
        this.fetchAdNameOptions();
    }

    fetchAdNameOptions() {
        getAdNameOptions()
            .then((data) => {
                this.adNameOptions = data.map((label) => {
                    return { label: label, value: label };
                });
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading Ad Names',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }



    salesExecutiveOptions = [];

    @wire(getSalesExecutiveOptions)
    wiredSalesExecs({ error, data }) {
        if (data) {
            this.salesExecutiveOptions = [
                { label: 'Other', value: 'Other' }, // Default option
                ...data.map(user => ({ label: user.Name, value: user.Name }))
            ];
        } else if (error) {
            this.showToast('Error', 'Failed to load Sales Executives', 'error');
        }
    }

    handleChange(event) {
        this[event.target.name] = event.target.value;
    }

    handleSubmit() {
        this.isLoading = true; // Show spinner
        if (this.validateForm()) {
            const leadData = {
                VisitorType__c: this.visitorType,
                FirstName: this.firstName,
                LastName: this.lastName,
                MobilePhone: this.mobileNumber,
                Email: this.emailAddress,
                AdName__c: this.adName,
                SubSource__c: this.adName,
                Sales_Executive__c: this.salesExecutive,
                Description: this.description,
                LeadSource: 'Walk-in',
                AdSetName__c: 'Hudayriyat Island Sales Centre Visitors',
                UTMSource__c: 'Hudayriyat Island Sales Centre Visitors',
                UTMCampaign__c: 'Salesforce'
            };

            createLead({ lead: leadData })
                .then((result) => {
                    this.showToast('Success', 'Lead created successfully', 'success');
                    this.navigateToRecordPage(result.Id);
                })
                .catch(error => {
                    this.isLoading = false; 
                    
                    //this.showToast('Error', 'Failed to create lead', 'error');
                    const errorMessage = error.body ? error.body.message : error.message;

                    // Print the error to the console for debugging
                    console.error('Error:', errorMessage);

                    // Display error message in toast
                    this.showToast('Error', `Failed to create lead: ${errorMessage}`, 'error');
                });
        } else {
            this.isLoading = false; // Show spinner
            this.showToast('Error', 'Please fill in all required fields correctly', 'error');
        }
    }

    validateForm() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox');
        return [...inputs].reduce((valid, input) => input.checkValidity() && valid, true);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }

    navigateToRecordPage(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Lead',
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        this.isLoading = true; // Show spinner
        // Navigate back to the lead list view
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Lead',
                actionName: 'list',
            },
        });
    }

}