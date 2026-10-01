import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import getProcessNames from '@salesforce/apex/CreateProcessItemsController.getChecklistProcessNames';
import getChecklistNames from '@salesforce/apex/CreateProcessItemsController.getChecklistNamesByProcess';
import createChecklist from '@salesforce/apex/CreateProcessItemsController.createProcessChecklist';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
//import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class CustomAction extends NavigationMixin(LightningElement) {
    @api recordId;

    @track processNameOptions = [];
    @track checklistNameOptions = [];
    
    selectedProcessName = '';
    selectedChecklistName = '';
    isLoading = false;
    isSaving = false;
    showEmptyState = false;

    get checklistDisabled(){
        return this.isSaving || this.selectedChecklistName;
    }

    connectedCallback() {
        this.isLoading = true;
        getProcessNames()
            .then(data => {
                this.processNameOptions = data.map(name => ({ label: name, value: name }));
                if (data.length === 0) {
                    this.showToast('Information', 'No checklist processes available', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load process names', 'error');
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleProcessNameChange(event) {
        this.selectedProcessName = event.detail.value;
        this.selectedChecklistName = '';
        this.showEmptyState = false;
        this.isLoading = true;

        getChecklistNames({ processName: this.selectedProcessName })
            .then(data => {
                this.checklistNameOptions = data.map(name => ({ label: name, value: name }));
                this.showEmptyState = data.length === 0;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load checklist names', 'error');
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleChecklistNameChange(event) {
        this.selectedChecklistName = event.detail;
    }

    handleProcessFlowClear = () => {
        this.selectedChecklistName = '';
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        if (!this.selectedChecklistName) {
            this.showToast('Error', 'Please select a Checklist Name.', 'error');
            
            // Add visual indication of required field
            const lookupElem = this.template.querySelector('.checklist-lookup');
            if (lookupElem) {
                lookupElem.classList.add('slds-has-error');
                setTimeout(() => {
                    lookupElem.classList.remove('slds-has-error');
                }, 2000);
            }
            
            return;
        }

        this.isSaving = true;
        
        createChecklist({
            checklistName: this.selectedChecklistName,
            businessProcessId: this.recordId
        })
            .then(() => {
                this.showToast('Success', 'Checklist created successfully.', 'success');
                //getRecordNotifyChange([{ recordId: this.recordId }]); // this is deprecated replaced this with notifyRecordUpdateAvailable.
                notifyRecordUpdateAvailable([{recordId: this.recordId}]);

                /*// Reload the current record page
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Business_Process__c', // Change to your actual object API name
                        actionName: 'view'
                    }
                });
                */
                
                // Close the action after a brief delay to show success message
                setTimeout(() => {
                    this.dispatchEvent(new CloseActionScreenEvent());
                }, 1500);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to create checklist.', 'error');
                console.error(error);
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant,
            mode: variant === 'error' ? 'sticky' : 'dismissible'
        }));
    }
}