/**
* @description       : Lightning Web Component to manage Buckets of Modon Egypt team and their respective bucket users.
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   20-01-2026   Milin Kapatel      Initial Version
* 1.1   03-03-2026   Milin Kapatel      Used Constants and Utilities from common constants and utilities files
**/
import { LightningElement, track, api } from 'lwc';
import getBuckets from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.getBuckets';
import getInternalUsers from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.getInternalUsers';
import addUsersToBucket from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.addUsersToBucket';
import getUsers from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.getUsers';
import createNewBucket from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.createNewBucket';
import updateBucket from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.updateBucket';
import { CONSTANTS } from 'c/modonEgyptConstants';
import { showSuccessToast, showErrorToast, debounce, processBucketRecords } from 'c/modonEgyptUtilities';


export default class ModonEgyptManageBucket extends LightningElement {

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
    @track selectedUserType = CONSTANTS.MANAGE_BUCKET_USER_TYPES_INTERNAL;
    userTypeOptions = CONSTANTS.MANAGE_BUCKET_USER_TYPE_OPTIONS;

    searchKey = CONSTANTS.MANAGE_BUCKET_EMPTY_STRING;
    _searchDebounce;

    selectedBuckerUserIds = [];
    parsedSelectedBuckerUserIds = [];

    get toggleManageInventoryBtnLabel() {
        return this.directSaveBucket ? CONSTANTS.MANAGE_BUCKET_LABELS_SAVE : CONSTANTS.MANAGE_BUCKET_LABELS_NEXT;
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value;
        clearTimeout(this._searchDebounce);
        this._searchDebounce = setTimeout(() => this.loadUsers(), 300);
    }

    loadUsers() {
        const assignedUserIds = (this.selectedAssignments || []).map(a => a.userId);

        getUsers({
            userCategory: this.selectedUserType,
            searchKey: CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
            limitSize: 100,
            assignedUsers: assignedUserIds
        })
            .then(result => {
                const rows = (result || []).map(u => ({
                    Id: u.Id,
                    name: u.Name,
                    profileName: (u.Profile && u.Profile.Name) || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING
                }));
                this.allUsersMaster = rows;
                this.applySearchFilter();
            })
            .catch(e => showErrorToast(CONSTANTS.MANAGE_BUCKET_TOAST_TITLE_ERROR_LOADING_USERS, e?.body?.message || e?.message || e || CONSTANTS.MANAGE_BUCKET_TOAST_MESSAGE_ERROR_LOADING_USERS));
    }

    applySearchFilter() {
        const term = (this.searchKey || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING).trim().toLowerCase();
        if (!term) {
            this.allUsers = this.allUsersMaster;
            return;
        }
        this.allUsers = this.allUsersMaster.filter(u =>
            (u.name || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING).toLowerCase().includes(term) ||
            (u.profileName || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING).toLowerCase().includes(term)
        );
    }



    handleSearchKeyup(event) {
        this.searchKey = event.target.value;
        this.applySearchFilter();
    }



    isEditModalOpen = false;
    isEditStep1 = false;
    isEditStep2 = false;

    get disableAddSelected() {
        return !this.selectedBucketId || this.selectedUserIds.size === 0;
    }

    openEditModal() {
        this.isEditModalOpen = true;
        this.isEditStep1 = true;
        this.isEditStep2 = false;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
    }

    goToNextStep = () => {
        this.isEditStep1 = false;
        this.isEditStep2 = true;
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



    async handleSaveEditWizard() {
        if (!this.selectedBucketId) return;

        const ids = Array.from(this.selectedUserIds || []);
        if (ids.length > 0) {
            await addUsersToBucket({ bucketId: this.selectedBucketId, userIds: ids });
        }

        await this.loadBuckets();
        this.selectedUserIds = new Set();
        this.closeEditModal();
        this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    }

    isLoading = false;
    viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    selectedBucketId = null;
    selectedBucket = null;
    selectedAssignments = [];
    formData = {
        name: CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
        description: CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
        active: true
    };

    connectedCallback() {
        this.loadBuckets();
    }

    loadInternalUsers() {
        const assignments = this.selectedAssignments || [];
        const assignedUserIds = assignments.map(a => a.userId);

        getInternalUsers({
            userCategory: this.selectedUserType,
            limitSize: 200,
            assignedUsers: assignedUserIds
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
            .catch(e => {
                showErrorToast(CONSTANTS.MANAGE_BUCKET_TOAST_TITLE_ERROR_LOADING_USERS, e?.body?.message || e?.message || e || CONSTANTS.MANAGE_BUCKET_TOAST_MESSAGE_ERROR_LOADING_USERS);
            });
    }

    handleUserTypeChange(event) {
        this.selectedUserType = event.detail.value;
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
            showErrorToast(CONSTANTS.MANAGE_BUCKET_TOAST_TITLE_ERROR_LOADING_BUCKETS, e?.body?.message || e?.message || e || CONSTANTS.MANAGE_BUCKET_TOAST_MESSAGE_ERROR_LOADING_BUCKETS);
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
        return this.viewState === CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    }

    get showNewEditBtnSection() {
        return this.viewState === CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    }

    get isViewMode() {
        return this.viewState === CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    }

    get isCreateMode() {
        return this.viewState === CONSTANTS.MANAGE_BUCKET_VIEW_STATES_CREATE;
    }

    get isEditMode() {
        return this.viewState === CONSTANTS.MANAGE_BUCKET_VIEW_STATES_EDIT;
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
        return this.hasAssignments ? CONSTANTS.MANAGE_BUCKET_LABELS_HIDE_USERS : CONSTANTS.MANAGE_BUCKET_LABELS_SHOW_USERS;
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
            const selectedEvent = new CustomEvent(CONSTANTS.MANAGE_BUCKET_CUSTOM_EVENT_BUCKET_SELECT, {
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
            case CONSTANTS.MANAGE_BUCKET_BUTTONS_CREATE_BUCKET:
                this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_CREATE;
                this.formData = { name: CONSTANTS.MANAGE_BUCKET_EMPTY_STRING, description: CONSTANTS.MANAGE_BUCKET_EMPTY_STRING, active: true };
                break;

            case CONSTANTS.MANAGE_BUCKET_BUTTONS_EDIT_BUCKET:
                if (!this.selectedBucketId) {
                    showErrorToast(CONSTANTS.MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_TITLE, CONSTANTS.MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_MSG);
                    return;
                }

                this.formData = {
                    name: this.selectedBucket?.name || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
                    description: this.selectedBucket?.description || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
                    active: this.selectedBucket?.isActive || CONSTANTS.MANAGE_BUCKET_EMPTY_STRING,
                };
                this.selectedAssignments = this.selectedBucket?.assignments || [];
                this.selectedUserIds = new Set();

                this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_EDIT;
                this.openEditModal();
                break;

            case CONSTANTS.MANAGE_BUCKET_BUTTONS_CANCEL_NEW_BUCKET:
            case CONSTANTS.MANAGE_BUCKET_BUTTONS_CANCEL_EDIT_BUCKET:
                this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
                break;

            case CONSTANTS.MANAGE_BUCKET_BUTTONS_SAVE_NEW_BUCKET:

                this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
                break;

            case CONSTANTS.MANAGE_BUCKET_BUTTONS_SAVE_UPDATED_BUCKET:
                if (!this.selectedBucketId) {
                    showErrorToast(CONSTANTS.MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_TITLE, CONSTANTS.MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_MSG);
                    return;
                }
                const idsToAdd = Array.from(this.selectedUserIds);
                if (idsToAdd.length === 0) {
                    showErrorToast(CONSTANTS.MANAGE_BUCKET_LABELS_NO_USERS_SELECTED_TITLE, CONSTANTS.MANAGE_BUCKET_LABELS_NO_USERS_SELECTED_MSG);
                    return;
                }

                this.isLoading = true;
                try {
                    await addUsersToBucket({ bucketId: this.selectedBucketId, userIds: idsToAdd });
                    await this.loadBuckets();
                    this.selectedUserIds = new Set();

                    showSuccessToast(CONSTANTS.MANAGE_BUCKET_LABELS_SUCCESS_TITLE, CONSTANTS.MANAGE_BUCKET_LABELS_USERS_ADDED_MSG);
                    this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
                } catch (e) {
                    showErrorToast(CONSTANTS.MANAGE_BUCKET_LABELS_ERROR_TITLE, CONSTANTS.MANAGE_BUCKET_LABELS_FAILED_TO_ADD_USERS_MSG);
                } finally {
                    this.isLoading = false;
                }
                break;
        }
    }

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

            // Use shared toast utilities instead of instance methods removed earlier
            if (isEditMode) {
                showSuccessToast(CONSTANTS.MANAGE_BUCKET_LABELS_SUCCESS_TITLE, CONSTANTS.MANAGE_BUCKET_TOAST_MESSAGE_SUCCESS_UPDATE);
            } else {
                showSuccessToast(CONSTANTS.MANAGE_BUCKET_LABELS_SUCCESS_TITLE, CONSTANTS.MANAGE_BUCKET_TOAST_MESSAGE_SUCCESS_CREATE);
            }
            this.handleCancelNewBucket();
        } catch (e) {
            showErrorToast(CONSTANTS.MANAGE_BUCKET_TOAST_TITLE_ERROR, e?.message || e?.body?.message);
        } finally {
            this.isLoading = false;
        }

    }

    handleCancelNewBucket() {
        this.viewState = CONSTANTS.MANAGE_BUCKET_VIEW_STATES_VIEW;
    }

}