import { LightningElement, api, track } from 'lwc';
import getSimpleChecklistItems from '@salesforce/apex/DisplayProcessChecklistItemController.getSimpleChecklistItems';
import createSimpleChecklistItem from '@salesforce/apex/DisplayProcessChecklistItemController.createSimpleChecklistItem';
import updateSimpleChecklistItem from '@salesforce/apex/DisplayProcessChecklistItemController.updateSimpleChecklistItem';
import deleteSimpleChecklistItem from '@salesforce/apex/DisplayProcessChecklistItemController.deleteSimpleChecklistItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ChecklistItemDisplay extends LightningElement {

    //@api recordId;

    @track items = [];
    @track isLoading = false;
    @track showModal = false;
    @track modalTitle = '';
    @track editedName = '';
    @track editedComments = '';
    @track editingItemId = null;
    @track isAddMode = false;
    @track userCanAdd = false;
    @track userCanEdit = false;

    //My Code
    towerId;
    towerName;
    towerUrl;
    
    projectId;
    projectName;
    projectUrl
    //

        // bookingId;
        // bookingName;
        // bookingUrl;

        // unitId;
        // unitName;
        // unitUrl;

    checkListName;
    processChecklistId;

    /*connectedCallback() {
        this.loadItems();
    }*/

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadItems();
        }
    }

    loadItems() {
        this.isLoading = true;

        getSimpleChecklistItems({ recordId: this.recordId })
            .then(result => {
                this.items = result.checklistItems.map((item, i) => {
                    return { 
                        ...item, 
                        serialNo: i + 1,
                        Checklist_Name__c: this.stripHtml(item.Checklist_Name__c),
                        Maker_Comments__c: this.stripHtml(item.Maker_Comments__c)
                    };
                });

                this.towerName = result.towerName;
                this.towerId = result.towerId;
                this.towerUrl  = this.towerId ? `/${this.towerId}` : null;
                this.projectId = result.projectId;
                this.projectName = result.projectName;
                this.projectUrl = this.projectId ? `/${this.projectId}` : null;

                this.checkListName = result.checkListName;
                // this.bookingId = result.bookingId;
                // this.bookingName = result.bookingName;
                // this.bookingUrl = this.bookingId ? `/${this.bookingId}` : null;
                // this.unitId = result.unitId;
                // this.unitName = result.unitName;
                // this.unitUrl = this.unitId ? `/${this.unitId}` : null;
                this.processChecklistId = result.processChecklistId;
                this.userCanAdd = result.userCanAdd;
                this.userCanEdit = result.userCanEdit;
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed loading items', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    stripHtml(html) {
        if (!html) return '';
        const doc = new DOMParser().parseFromString(html, 'text/html');
        return doc.body.textContent || '';
    }

    handleAddItem() {
        this.isAddMode = true;
        this.modalTitle = 'Add New Item';
        this.editedName = '';
        this.editedComments = '';
        this.editingItemId = null;
        this.showModal = true;
    }

    handleEdit(event) {
        const itemId = event.target.dataset.id;
        const item = this.items.find(i => i.Id === itemId);
        
        if (item) {
            this.isAddMode = false;
            this.modalTitle = 'Edit Item';
            this.editingItemId = itemId;
            this.editedName = item.Checklist_Name__c || '';
            this.editedComments = item.Maker_Comments__c || '';
            this.showModal = true;
        }
    }

    handleNameChange(event) {
        this.editedName = event.target.value;
    }

    handleCommentsChange(event) {
        this.editedComments = event.target.value;
    }

    closeModal() {
        this.showModal = false;
        this.editingItemId = null;
        this.editedName = '';
        this.editedComments = '';
        this.isAddMode = false;
    }

    handleSave() {
        // Validate Name field
        if (!this.editedName || this.editedName.trim() === '') {
            this.showToast('Error', 'Please enter a Checklist Name', 'error');
            return;
        }

        this.isLoading = true;

        if (this.isAddMode) {
            // CREATE NEW ITEM
            createSimpleChecklistItem({
                processChecklistId: this.processChecklistId,
                checkListName: this.editedName,
                makerComments: this.editedComments
            })
                .then(() => {
                    this.showToast('Success', 'Item Added', 'success');
                    this.closeModal();
                    this.loadItems();
                })
                .catch(error => {
                    console.error(error);
                    this.showToast('Error', 'Failed to add item', 'error');
                    this.isLoading = false;
                });
        } else {
            // UPDATE EXISTING ITEM
            updateSimpleChecklistItem({
                itemId: this.editingItemId,
                checkListName: this.editedName,
                makerComments: this.editedComments
            })
                .then(() => {
                    this.showToast('Success', 'Item Updated', 'success');
                    this.closeModal();
                    this.loadItems();
                })
                .catch(error => {
                    console.error(error);
                    this.showToast('Error', 'Failed to update item', 'error');
                    this.isLoading = false;
                });
        }
    }

    handleDelete(event) {
        const itemId = event.target.dataset.id;
        
        if (!confirm('Are you sure you want to delete this item?')) {
            return;
        }

        this.isLoading = true;

        deleteSimpleChecklistItem({ itemId })
            .then(() => {
                this.showToast('Deleted', 'Item removed', 'success');
                this.loadItems();
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed to delete', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}