import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChecklistItems from '@salesforce/apex/SPAMCStepActivato.getChecklistItems';
import getPicklistValuesForChecklist from '@salesforce/apex/SPAMCStepActivato.getPicklistValuesForChecklist';
import updateChecklistItems from '@salesforce/apex/SPAMCStepActivato.updateChecklistItems';

export default class MakerCheckerChecklist extends LightningElement {


    @api recordId;
    @track checklistItems = [];
    @track picklistOptions = {
        maker: [],
        checker: [],
        rejectionReasons: []
    };
    @track isLoading = false;
get businessProcessId() {
        return this.parentId;
    }

    connectedCallback() {
        this.loadData();
    }

     @api parentId;

    bookingId;
    bookingName;
    unitId;
    unitName;
    bookingUrl;
    unitUrl;
    checkListName;


//    getPlainText(htmlString) {
//     if (!htmlString) return '';
    
//     // Replace paragraph and <br> tags with newline before stripping the rest
//     const formatted = htmlString
//         .replace(/<p>/gi, '')                  // remove opening <p>
//         .replace(/<\/p>/gi, '\n')              // replace closing </p> with newline
//         .replace(/<br\s*\/?>/gi, '\n');        // replace <br> with newline
//         //.replace(/^(\s*<br\s*\/?>)+/gi, '');           // replace <br> with blank

//     const div = document.createElement('div');
//     div.innerHTML = formatted;
//     return div.textContent || div.innerText || '';
// }

     

    loadData() {
        this.isLoading = true;

        Promise.all([
            getChecklistItems({recordId:this.parentId}),
            getPicklistValuesForChecklist()
        ])
            .then(([checklistData, picklistData]) => {

                this.bookingId = checklistData.bookingId;
                this.bookingName = checklistData.bookingName;
                this.unitId = checklistData.unitId;
                this.unitName = checklistData.unitName;
                this.checkListName=checklistData.checkListName;

                //this.bookingUrl = `/${this.parentId}`;
                //this.unitUrl = `/${this.parentId}`; // Adjust this based on your data model
                

                this.bookingUrl = `/${this.bookingId}`;
                this.unitUrl = `/${this.unitId}`; // Adjust this based on your data model
                


                this.checklistItems = checklistData.checklistItems.map(item => {
                    const isMakerCompleted = item.Process_Checklist__r?.Is_Maker_Review_Completed__c || false;
                    return {
                        id: item.Id,
                        name: `<strong>${item.Checklist_Name__c || ''}</strong>`,
                        makerStatus: item.Maker_Action__c,
                        checkerStatus: item.Checker_Action__c,
                        checkerRejectionReason: item.Checker_Rejection_Reasons__c,
                        makerRejectionReason: item.Maker_Rejection_Reasons__c,
                        makerComments: item.Maker_Comments__c,
                        checkerComments: item.Checker_Comments__c,
                        isMakerDisabled: isMakerCompleted,
                        isCheckerDisabled: !isMakerCompleted,
                        showChekerRejectionReason: item.Checker_Action__c === 'Rejected',
                        showMakerMakerRejectionReason: item.Maker_Action__c === 'Rejected'
                    };
                    
                });

                this.picklistOptions = {
                    maker: picklistData.makerStatusOptions,
                    checker: picklistData.checkerStatusOptions,
                    rejectionReasons: picklistData.rejectionReasonOptions
                };
            })
            .catch(error => {
                console.error('Error loading checklist data:', error);
                this.showToast('Error', 'Failed to load checklist data', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleMakerStatusChange(event) {
        this.updateItem(event, 'makerStatus');
    }

    handleCheckerStatusChange(event) {
        this.updateItem(event, 'checkerStatus');
    }

    handleCheckerRejectionReasonChange(event) {
        this.updateItem(event, 'checkerRejectionReason');
    }

    handleMakerRejectionReasonChange(event) {
        this.updateItem(event, 'makerRejectionReason');
    }

    handleMakerCommentChange(event) {
        this.updateItem(event, 'makerComments');
    }

    handleCheckerCommentChange(event) {
        this.updateItem(event, 'checkerComments');
    }

    updateItem(event, field) {
        const itemId = event.target.dataset.id;
        const value = event.target.value;

        this.checklistItems = this.checklistItems.map(item => {
            if (item.id === itemId) {
                const updatedItem = { ...item, [field]: value };
                if (field === 'checkerStatus') {
                    updatedItem.showChekerRejectionReason = value === 'Rejected';
                    if (value !== 'Rejected') {
                        updatedItem.checkerRejectionReason = ''; // clear if no longer rejected
                    }
                } if (field === 'makerStatus') {
                    updatedItem.showMakerRejectionReason = value === 'Rejected';
                    if (value !== 'Rejected') {
                        updatedItem.makerRejectionReason = ''; // clear if no longer rejected
                    }
                }
                return updatedItem;
            }
            return item;
        });
    }

    handleSave() {
        this.isLoading = true;

        // Validate rejection reason when status is "Rejected"
        const invalidItem = this.checklistItems.find(item =>
            item.checkerStatus === 'Rejected' && (!item.checkerRejectionReason || item.checkerRejectionReason.trim() === '')
        );

        if (invalidItem) {
            this.showToast('Validation Error', 'Rejection reason is required for all rejected items.', 'error');
            this.isLoading = false;
            return;
        }

        const itemsToSave = this.checklistItems.map(item => ({
            Id: item.id,
            Maker_Action__c: item.makerStatus,
            Checker_Action__c: item.checkerStatus,
            Checker_Rejection_Reasons__c: item.checkerRejectionReason,
            Maker_Rejection_Reasons__c: item.makerRejectionReason,
            Maker_Comments__c: item.makerComments,
            Checker_Comments__c: item.checkerComments
        }));

        updateChecklistItems({ items: itemsToSave })
            .then(() => {
                this.showToast('Success', 'Checklist items saved successfully', 'success');
                setTimeout(() => {
                    this.loadData();
                }, 200);
            })
            .catch(error => {
                console.error('Error saving checklist items:', error);
                this.showToast('Error', 'Failed to save checklist items', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }


    // Add navigation methods
    navigateToBooking() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.bookingId,
                actionName: 'view'
            }
        });
    }

    navigateToUnit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.unitId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}