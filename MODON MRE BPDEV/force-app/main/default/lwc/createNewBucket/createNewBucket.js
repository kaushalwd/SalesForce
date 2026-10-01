import { LightningElement, track, api } from 'lwc';

import getBucketUsers from '@salesforce/apex/ManageBucketLwcController.getBucketUsers';

import { showErrorToast, isArrayEmpty, isStringEmpty, isStringEqual, processBucketRecords } from 'c/utils';
import { BUCKET_MANAGEMENT_CONSTANTS, LIGHTNING_INPUT_TAG } from 'c/constants';

export default class CreateNewBucket extends LightningElement {
    @api bucketName = '';
    @api bucketDescription = '';
    @api isActive = false;
    @api isEditMode = false;
    @api selectedUserIds = [];

    @track selectedOptions = [];
    @track multiSelectCombobox = [];
    @track selectedUsers = [];
    @track selectedUserOptions = [];

    selectedUserType = 'All';

    isLoading = false;
    parsedUserOptions = [];

    userTypeOptions = BUCKET_MANAGEMENT_CONSTANTS.USER_TYPE_OPTIONS;

    get isBrokerUserType() {
        return isStringEqual(this.selectedUserType, 'Broker');
    }

    get sectionTitle() {
        return this.isEditMode ? 'Edit Bucket' : 'Create New Bucket';
    }

    async connectedCallback() {
        this.selectedUsers = JSON.parse(JSON.stringify(this.selectedUserIds));
        await this.loadUsers();
    }

    // ------------------------ HANDLER EVENTS --------------------------
    async handleChangeEvent(event) {
        const field = event.target.name;
        this[field] = event.target.value;

        if (isStringEqual(field, 'selectedUserType')) {
            await this.loadUsers();
        }
    }

    handleCheckboxChange(event) {
        this.isActive = event.target.checked;
    }

    handleSave() {
        let isValid = true;
        // Check validity of all fields in the form
        let fields = this.template.querySelectorAll(LIGHTNING_INPUT_TAG);
        fields.forEach(field => {
            if (!field.checkValidity()) {
                field.reportValidity();
                isValid = false;
            }
        });

        if (!isValid) {
            showErrorToast('Error', 'Field cannot be empty or contain special characters!');
            return;
        }

        if (isArrayEmpty(this.selectedUsers)) {
            showErrorToast('Error', 'Please select at least one user');
            return;
        }

        // Pass data back to the parent
        const dataChangeEvent = new CustomEvent(BUCKET_MANAGEMENT_CONSTANTS.CREATE_BUCKET_SAVE, {
            detail: {
                selectedRows: this.selectedUsers,
                bucketName: this.bucketName,
                bucketDescription: this.bucketDescription,
                isActive: this.isActive,
                isEditMode: this.isEditMode
            }
        });
        this.dispatchEvent(dataChangeEvent);
    }

    handleCancel() {
        // Pass data back to the parent
        const dataChangeEvent = new CustomEvent(BUCKET_MANAGEMENT_CONSTANTS.CREATE_BUCKET_CANCEL);
        this.dispatchEvent(dataChangeEvent);
    }

    // -------------------- HELPER METHODS ---------------------

    async loadUsers() {
        try {
            this.isLoading = true;
            const data = await getBucketUsers({
                userType: this.selectedUserType
            });

            const processedData = processBucketRecords(data);

            this.userOptions = processedData?.map(user => ({
                ...user,
                // profileName: user?.Profile?.Name,
                // agency: user?.Account?.Name,
                label: isStringEmpty(user?.Account?.Name) ? user.Name : user.Name + ` (Agency: ${user?.Account?.Name})`
            }));

            if (isArrayEmpty(this.selectedUserOptions) && this.isEditMode) {
                this.selectedUserOptions = this.userOptions?.filter(u => this.selectedUsers.includes(u.Id));
                this.selectedOptions = this.selectedUserOptions?.map(user => {
                    return { label: user?.label, value: user.Id, isSelected: false, liClass: 'slds-listbox__option slds-listbox__option_plain slds-media slds-media_small slds-media_inline ' };
                });
            }

            this.parsedUserOptions = JSON.parse(JSON.stringify(this.userOptions));
            this.userOptions = this.userOptions?.filter(u => !this.selectedUsers.includes(u.Id));

            this.multiSelectCombobox = this.userOptions?.map(user => {
                return { label: user?.label, value: user.Id, isSelected: false, liClass: 'slds-listbox__option slds-listbox__option_plain slds-media slds-media_small slds-media_inline ' };
            });

        } catch (e) {
            showErrorToast('Error', e?.message || e?.body?.message);
        } finally {
            this.isLoading = false;
        }
    }

    handlePicklistUserSelection(event) {
        this.selectedOptions = event.detail?.selectedOptions;
        this.selectedUsers = this.selectedOptions?.map(opt => opt.value);
    }
}