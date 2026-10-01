import { LightningElement, api, wire, track } from 'lwc';
import getContacts from '@salesforce/apex/MilestoneUpdateTracker.getChildRecords';
import updateContacts from '@salesforce/apex/MilestoneUpdateTracker.updateChildRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class MilestoneUpdateDates extends LightningElement {
    @api recordId; // Parent Account Id
    @track contacts;
    wiredrecords;
    @track error;
    draftValues = [];
    isLoading = false;

    columns = [
        { label: 'Milestone', fieldName: 'MilestoneRec__c', editable: false },
        { label: 'Actual Milestone Due Date', fieldName: 'Actual_Milestone_Due_Date__c', type: 'date', editable: false },
        { label: 'Confirmed Milestone Due Date', fieldName: 'Confirmed_Milestone_Date__c', type: 'date', editable: true },        
        { label: 'Reschedule Milestone Date', fieldName: 'Reschedule_Milestone_Date__c', type: 'date', editable: true }
    ];

    @wire(getContacts, { parentId: '$recordId'})
    wiredContacts({ data, error }) {
        this.wiredrecords =data;
        if (data) {
            this.contacts = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.contacts = undefined;
        }
    }

    loadMilestoneData() {
        getContacts({ parentId: this.recordId })
            .then(result => {
                this.contacts = result;
            })
            .catch(error => {
                this.contacts = undefined;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating records',
                        message: error.body.message,
                        variant: 'error',
                         mode: 'dismissable'
                    })
                );
            });
    }

    handleSave(event) {
        const updatedFields = event.detail.draftValues;
        // Convert draft values into record input objects
        this.isLoading = true;
        updateContacts({ updatedRecords: updatedFields,srId : this.recordId}) 
            .then(result => {
                if(result =='Success'){
                  
                    this.loadMilestoneData();
                    //this.draftValues = [];
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Milestone Tracker updated',
                            variant: 'success',
                             mode: 'dismissable'
                        })
                    );
                    this.isLoading = false;
                    // Clear draft values
                    //this.isLoading = false;
                    // Refresh data

                   // window.location.reload();
                    //return refreshApex(this.wiredrecords);
                   // return refreshApex(this.contacts);
                }else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result,
                            variant: 'error',
                             mode: 'dismissable'
                        })
                    );
                    // Clear draft values
                    //this.draftValues = [];
                    this.isLoading = false;
                    // Refresh data
                }
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating records',
                        message: error.body.message,
                        variant: 'error',
                         mode: 'dismissable'
                    })
                );
                this.isLoading = false;
            });
    }
}