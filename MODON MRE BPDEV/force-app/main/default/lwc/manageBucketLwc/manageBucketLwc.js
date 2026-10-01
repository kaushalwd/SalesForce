import { LightningElement, track, api } from 'lwc';
import getBuckets from '@salesforce/apex/ManageBucketLwcController.getBuckets';
import getInternalUsers from '@salesforce/apex/ManageBucketLwcController.getInternalUsers';
import addUsersToBucket from '@salesforce/apex/ManageBucketLwcController.addUsersToBucket';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUsers from '@salesforce/apex/ManageBucketLwcController.getUsers';
import createNewBucket from '@salesforce/apex/ManageBucketLwcController.createNewBucket';
import updateBucket from '@salesforce/apex/ManageBucketLwcController.updateBucket';

import { showErrorToast, showSuccessToast, processBucketRecords } from 'c/utils';

const VIEW_STATES = {
    VIEW: 'view',
    CREATE: 'create',
    EDIT: 'edit'
};

export default class ManageBucketLwc extends LightningElement {
    @track buckets = [];
    @api previousBucketSelection = null;
    @api directSaveBucket = false;

    @api get toggleManageInventory() {
        return this._toggleManageInventory;
    }

    set toggleManageInventory(value) {
        this._toggleManageInventory = value;
        if (value) {
            this.hideUserTable = true;
        }
    }

    @track selectedUserIds = new Set();
    @track allUsers = [];
    allUsersMaster = [];
    @track selectedUserType = 'Internal';
    userTypeOptions = [
        { label: 'Internal Users', value: 'Internal' },
        { label: 'Brokers', value: 'Broker' }
    ];

    searchKey = '';
    _searchDebounce;

    selectedBuckerUserIds = [];
    parsedSelectedBuckerUserIds = [];

    get toggleManageInventoryBtnLabel() {
        return this.directSaveBucket ? 'Save' : 'Next>>';
    }

    // keep search debounced → already calls loadUsers()
    handleSearchInput(event) {
        this.searchKey = event.target.value;
        clearTimeout(this._searchDebounce);
        this._searchDebounce = setTimeout(() => this.loadUsers(), 300);
    }

    loadUsers() {
        const assignedUserIds = (this.selectedAssignments || []).map(a => a.userId);
        // remove: this.isLoading = true;  // don't block the whole page

        getUsers({
            userCategory: this.selectedUserType,
            searchKey: '',           // fetch base list; search is local
            limitSize: 100,
            assignedUsers: assignedUserIds
        })
            .then(result => {
                const rows = (result || []).map(u => ({
                    Id: u.Id,
                    name: u.Name,
                    profileName: (u.Profile && u.Profile.Name) || ''
                }));
                this.allUsersMaster = rows;
                this.applySearchFilter(); // sets allUsers from master using current searchKey
            })
            .catch(e => console.error('getUsers error', e?.body?.message || e))
            .finally(() => { /* no global spinner here */ });
    }

    applySearchFilter() {
        const term = (this.searchKey || '').trim().toLowerCase();
        if (!term) {
            this.allUsers = this.allUsersMaster;
            return;
        }
        this.allUsers = this.allUsersMaster.filter(u =>
            (u.name || '').toLowerCase().includes(term) ||
            (u.profileName || '').toLowerCase().includes(term)
        );
    }


    /*
      loadUsers() {
        const assignedUserIds = (this.selectedAssignments || []).map(a => a.userId);
        this.isLoading = true;
        getUsers({
          userCategory: this.selectedUserType,
          searchKey: this.searchKey,
          limitSize: 100,
          assignedUsers: assignedUserIds
        })
        .then(result => {
          this.allUsers = (result || []).map(u => ({
            Id: u.Id,
            name: u.Name,
            profileName: u.Profile?.Name
          }));
        })
        .catch(e => {
          console.error('getUsers error', e?.body?.message || e);
          this.dispatchEvent(new ShowToastEvent({
            title: 'Search failed',
            message: e?.body?.message || 'Unknown error',
            variant: 'error'
          }));
        })
        .finally(() => { this.isLoading = false; });
      }
      */


    handleSearchKeyup(event) {
        this.searchKey = event.target.value;
        this.applySearchFilter(); // no server, no spinner
    }



    // ADD new state
    isEditModalOpen = false;
    isEditStep1 = false;
    isEditStep2 = false;

    // Optional: computed
    get disableAddSelected() {
        return !this.selectedBucketId || this.selectedUserIds.size === 0;
    }

    // OPEN/CLOSE
    openEditModal() {
        this.isEditModalOpen = true;
        this.isEditStep1 = true;
        this.isEditStep2 = false;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
    }
    // STEP NAV
    goToNextStep = () => {
        this.isEditStep1 = false;
        this.isEditStep2 = true;
        // ensure users visible in step 2
        this.loadUsers();
    };

    goToPrevStep = () => {
        this.isEditStep2 = false;
        this.isEditStep1 = true;
    };

    get userRows() {
        return (this.allUsers || []).map(u => ({
            ...u,
            isSelected: this.selectedUserIds.has(u.Id)
        }));
    }



    // SAVE in modal (bulk add + close)
    async handleSaveEditWizard() {
        if (!this.selectedBucketId) return;

        // 1) Persist selected users
        const ids = Array.from(this.selectedUserIds || []);
        if (ids.length > 0) {
            await addUsersToBucket({ bucketId: this.selectedBucketId, userIds: ids });
        }

        // 2) Optionally persist name/type changes here (call your Apex update method if needed)

        // 3) Refresh and close
        await this.loadBuckets();
        this.selectedUserIds = new Set();
        this.closeEditModal();
        this.viewState = VIEW_STATES.VIEW;
    }

x

    isLoading = false;
    viewState = VIEW_STATES.VIEW;
    selectedBucketId = null;
    selectedBucket = null;
    selectedAssignments = [];
    formData = {
        name: '',
        description: '',
        active: true
    };

    connectedCallback() {
        this.loadBuckets();
    }

    loadInternalUsers() {
        const assignments = this.selectedAssignments || [];
        const assignedUserIds = assignments.map(a => a.userId); // ✅ use array

        getInternalUsers({
            userCategory: this.selectedUserType,
            limitSize: 200,
            assignedUsers: assignedUserIds // ✅ proper array
        })
            .then(result => {
                this.allUsers = result.map(u => ({
                    Id: u.Id,
                    name: u.Name,
                    profileName: u.Profile?.Name,
                    isSelected: false
                }));

                this.selectedUserIds = new Set();
            })
            .catch(error => {
                console.error('Error loading users:', error);
            });
    }

    handleUserTypeChange(event) {
        this.selectedUserType = event.detail.value;
        //this.loadInternalUsers();
        this.loadUsers();
    }


    async loadBuckets() {
        this.isLoading = true;
        try {
            const data = await getBuckets();
            this.buckets = (data || []).map(w => ({
                id: w.bucketObj?.Id,
                name: w.bucketObj?.Name,
                description: w.bucketObj?.Description__c,
                isActive: w.bucketObj?.Active__c,
                nou: w.bucketObj?.Number_of_units__c > 0 ? w.bucketObj?.Number_of_units__c : 0,
                numberOfUser: w.baLst?.length > 0 ? w.baLst?.length : 0,
                assignments: (w.baLst || []).map(ba => ({
                    ...ba.UserOrGroup,
                    userId: ba.UserOrGroupId,
                    profileName: ba.UserOrGroup?.Profile?.Name,
                }))
            }));

            if (this.buckets.length > 0) {
                if (this.previousBucketSelection) {
                    this.selectedBucketId = this.previousBucketSelection;
                } else {
                    this.selectedBucketId = this.buckets[0].id;
                }

                this.refreshAssignment();
            }

        } catch (e) {
            console.error('[Buckets Load Error]', e);
        } finally {
            this.isLoading = false;
        }
    }

    get rows() {
        return this.buckets.map(b => ({
            ...b,
            isSelected: b.id === this.selectedBucketId
        }));
    }

    get showRadioOptions() {
        return this.viewState === VIEW_STATES.VIEW;
    }

    get showNewEditBtnSection() {
        return this.viewState === VIEW_STATES.VIEW;
    }

    get isViewMode() {
        return this.viewState === VIEW_STATES.VIEW;
    }

    get isCreateMode() {
        return this.viewState === VIEW_STATES.CREATE;
    }

    get isEditMode() {
        return this.viewState === VIEW_STATES.EDIT;
    }

    get disableEditButton() {
        return !this.selectedBucketId;
    }

    get hasBuckets() {
        return this.rows.length > 0;
    }

    get hasAssignments() {
        return this.selectedAssignments.length > 0 && (!this.toggleManageInventory || !this.hideUserTable);
    }

    get userVisibilityLabel() {
        return this.hasAssignments ? 'Hide Users' : 'Show Users';
    }

    hideUserTable = false;
    userVisibilityTable() {
        this.hideUserTable = !this.hideUserTable;
    }

    handleRadioChange(event) {
        this.selectedBucketId = event.target.value;
        this.refreshAssignment();
    }

    refreshAssignment() {
        this.selectedBucket = this.buckets.find(b => b.id === this.selectedBucketId);
        
        const data = this.selectedBucket ? this.selectedBucket.assignments : [];
        this.selectedAssignments = processBucketRecords(data);
        this.selectedBuckerUserIds = this.selectedBucket.assignments?.map(user => user?.userId);
        this.parsedSelectedBuckerUserIds = JSON.parse(JSON.stringify(this.selectedBuckerUserIds));
    }

    handleUserSelection(event) {
        const userId = event.target.value;
        const checked = event.target.checked;
        this.selectedUserIds = new Set(
            checked
                ? [...this.selectedUserIds, userId]
                : [...this.selectedUserIds].filter(id => id !== userId)
        );
    }

    handleSelectBucket() {
        const selected = this.buckets.find(b => b.id === this.selectedBucketId);
        if (selected) {
            const selectedEvent = new CustomEvent('bucketselect', {
                detail: {
                    bucketId: selected.id,
                    bucketName: selected.name,
                    selectedAssignment: this.selectedAssignments
                }
            });
            this.dispatchEvent(selectedEvent);
        }
    }

    async handleButtonAction(event) {
        const actionName = event.target.name;

        switch (actionName) {
            case 'CreateBucket':
                this.viewState = VIEW_STATES.CREATE;
                this.formData = { name: '', description: '', active: true };
                break;

            case 'EditBucket':
                if (!this.selectedBucketId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No bucket selected',
                        message: 'Please select a bucket first.',
                        variant: 'warning'
                    }));
                    return;
                }

                this.formData = {
                    name: this.selectedBucket?.name || '',
                    description: this.selectedBucket?.description || '',
                    active: this.selectedBucket?.isActive || '',
                };
                this.selectedAssignments = this.selectedBucket?.assignments || [];
                this.selectedUserIds = new Set();

                this.viewState = VIEW_STATES.EDIT;     // ensure isEditMode becomes true
                this.openEditModal();                  // show modal
                break;
            /*
            this.viewState = VIEW_STATES.EDIT;
            if (this.selectedBucket) {
                this.formData = {
                    name: this.selectedBucket.name,
                    description: this.selectedBucket.description
                };
                this.selectedAssignments = this.selectedBucket.assignments || [];
                this.loadInternalUsers();
            }
            // if you need to (re)load users for the table:
            // this.loadUsers();
            break;
            */

            case 'cancelNewBucket':
            case 'cancelEditBucket':
                this.viewState = VIEW_STATES.VIEW;
                break;

            case 'saveNewBucket':
                // TODO: create new bucket via Apex, then:
                this.viewState = VIEW_STATES.VIEW;
                break;

            case 'saveUpdatedBucket':
                if (!this.selectedBucketId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No bucket selected',
                        message: 'Please select a bucket first.',
                        variant: 'warning'
                    }));
                    return;
                }
                const idsToAdd = Array.from(this.selectedUserIds);
                if (idsToAdd.length === 0) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No users selected',
                        message: 'Select at least one user to add.',
                        variant: 'warning'
                    }));
                    return;
                }

                this.isLoading = true;
                try {
                    await addUsersToBucket({ bucketId: this.selectedBucketId, userIds: idsToAdd });
                    await this.loadBuckets(); // refresh assignments
                    this.selectedUserIds = new Set(); // clear selection

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Users added to the bucket.',
                        variant: 'success'
                    }));
                    this.viewState = VIEW_STATES.VIEW;
                } catch (e) {
                    // eslint-disable-next-line no-console
                    console.error('Bulk add failed', e);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to add users to the bucket.',
                        variant: 'error'
                    }));
                } finally {
                    this.isLoading = false;
                }
                break;
        }
    }
    /*
    handleButtonAction(event) {
        const actionName = event.target.name;
        getInternalUsers()
            .then(result => {
                // Map fields to lowercase for template convenience
                this.allUsers = result.map(u => ({
                    Id: u.Id,
                    name: u.Name,
                    profileName: u.Profile?.Name
                }));
            })
            .catch(error => {
                console.error('Error fetching users: ', error);
            });
   

        switch (actionName) {
            case 'CreateBucket':
                this.viewState = VIEW_STATES.CREATE;
                this.formData = { name: '', description: '' };
                break;

            case 'EditBucket':
                this.viewState = VIEW_STATES.EDIT;
                if (this.selectedBucket) {
                    this.formData = {
                        name: this.selectedBucket.name,
                        description: this.selectedBucket.description
                    };
                }
                break;

            case 'cancelNewBucket':
            case 'cancelEditBucket':
                this.viewState = VIEW_STATES.VIEW;
                break;

            case 'saveNewBucket':
                // TODO: Call Apex to save new bucket
                this.viewState = VIEW_STATES.VIEW;
                break;

            case 'saveUpdatedBucket':
                // TODO: Call Apex to update selected bucket
                this.viewState = VIEW_STATES.VIEW;
                break;
        }
    }
*/
    handleInputChange(event) {
        const field = event.target.name;
        this.formData = {
            ...this.formData,
            [field]: event.target.value
        };
    }

    async handleSaveBucket(event) {
        try {
            this.isLoading = true;
            const { selectedRows, bucketName, bucketDescription, isActive, isEditMode } = event.detail;

            const bucketObj = {
                Name: bucketName,
                Description__c: bucketDescription,
                Active__c: isActive
            };

            const data = this.selectedBucket ? this.selectedBucket.assignments : [];
            const selectedUsers = JSON.parse(JSON.stringify(processBucketRecords(data)));

            const previousSelectedUsers = selectedUsers.map(user => user.Id);

            const removedUserIds = previousSelectedUsers.filter(id => !selectedRows.includes(id));
            const newUserIds = selectedRows.filter(id => !previousSelectedUsers.includes(id));

            if (isEditMode) {
                bucketObj.Id = this.selectedBucket.id;
                await updateBucket({ bucketObj, newUserIds, removedUserIds });
            } else {
                await createNewBucket({ newBucket: bucketObj, userIds: selectedRows });
            }

            await this.loadBuckets();

            showSuccessToast('Success', `Bucket ${isEditMode ? 'updated' : 'created'} successfully`);
            this.handleCancelNewBucket();
        } catch (e) {
            showErrorToast('Error', e?.message || e?.body?.message);
        } finally {
            this.isLoading = false;
        }

    }

    handleCancelNewBucket() {
        this.viewState = VIEW_STATES.VIEW;
    }
}