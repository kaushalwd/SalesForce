/**
* @description       : Lightning Web Component to create/edit new bucket and edit users of that bucket.
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
import getBucketUsers from '@salesforce/apex/Modon_Egypt_ManageBucketLwcController.getBucketUsers';
import { CONSTANTS } from 'c/modonEgyptConstants';
import { showSuccessToast, showErrorToast, isArrayEmpty, isStringEmpty, isStringEqual, processBucketRecords } from 'c/modonEgyptUtilities';

export default class ModonEgyptCreateNewBucket extends LightningElement {

  @api bucketName = CONSTANTS.CREATE_NEW_BUCKET_EMPTY_STRING;
  @api bucketDescription = CONSTANTS.CREATE_NEW_BUCKET_EMPTY_STRING;
  @api isActive = false;
  @api isEditMode = false;
  @api selectedUserIds = [];

  @track selectedOptions = [];
  @track multiSelectCombobox = [];
  @track selectedUsers = [];
  @track selectedUserOptions = [];

  selectedUserType = CONSTANTS.CREATE_NEW_BUCKET_USER_TYPES_INTERNAL;

  isLoading = false;
  parsedUserOptions = [];

  userTypeOptions = CONSTANTS.CREATE_NEW_BUCKET_USER_TYPE_OPTIONS;
  availableUserColumns = CONSTANTS.CREATE_NEW_BUCKET_AVAILABLE_USER_COLUMNS;

  get isBrokerUserType() {
    return isStringEqual(this.selectedUserType, CONSTANTS.CREATE_NEW_BUCKET_USER_TYPES_BROKER);
  }

  get sectionTitle() {
    return this.isEditMode
      ? CONSTANTS.CREATE_NEW_BUCKET_LABELS_EDIT_BUCKET
      : CONSTANTS.CREATE_NEW_BUCKET_LABELS_CREATE_NEW_BUCKET;
  }

  async connectedCallback() {
    this.selectedUsers = JSON.parse(JSON.stringify(this.selectedUserIds));
    await this.loadUsers();
  }

  // ------------------------ HANDLER EVENTS --------------------------
  async handleChangeEvent(event) {
    const field = event.target.name;
    this[field] = event.target.value;

    if (isStringEqual(field, CONSTANTS.CREATE_NEW_BUCKET_LABELS_SELECTED_USER_TYPE)) {
      await this.loadUsers();
    }
  }

  handleCheckboxChange(event) {
    this.isActive = event.target.checked;
  }

  handleSave() {
    let isValid = true;
    let fields = this.template.querySelectorAll(CONSTANTS.CREATE_NEW_BUCKET_LIGHTNING_INPUT_TAG);
    fields.forEach(field => {
      if (!field.checkValidity()) {
        field.reportValidity();
        isValid = false;
      }
    });

    if (!isValid) {
      showErrorToast(
        CONSTANTS.CREATE_NEW_BUCKET_LABELS_ERROR_TITLE,
        CONSTANTS.CREATE_NEW_BUCKET_LABELS_FIELD_INVALID_MSG
      );
      return;
    }

    if (isArrayEmpty(this.selectedUsers)) {
      showErrorToast(
        CONSTANTS.CREATE_NEW_BUCKET_LABELS_ERROR_TITLE,
        CONSTANTS.CREATE_NEW_BUCKET_LABELS_SELECT_ONE_USER_MSG
      );
      return;
    }

    const dataChangeEvent = new CustomEvent(CONSTANTS.CREATE_NEW_BUCKET_EVENTS_SAVE, {
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
    const dataChangeEvent = new CustomEvent(CONSTANTS.CREATE_NEW_BUCKET_EVENTS_CANCEL);
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
        label: isStringEmpty(user?.Account?.Name) ? user.Name : user.Name + ` (Agency: ${user?.Account?.Name})`
      }));


      if (isArrayEmpty(this.selectedUserOptions) && this.isEditMode) {
        this.selectedUserOptions = this.userOptions?.filter(u => this.selectedUsers.includes(u.Id));
        this.selectedOptions = this.selectedUserOptions?.map(user => {
          return {
            label: user?.label,
            value: user.Id,
            isSelected: false,
            liClass: CONSTANTS.CREATE_NEW_BUCKET_LISTBOX_CLASSES_OPTION_BASE
          };
        });
      }

      this.parsedUserOptions = JSON.parse(JSON.stringify(this.userOptions));
      this.userOptions = this.userOptions?.filter(u => !this.selectedUsers.includes(u.Id));

      this.multiSelectCombobox = this.userOptions?.map(user => {
        return {
          label: user?.label,
          value: user.Id,
          isSelected: false,
          liClass: CONSTANTS.CREATE_NEW_BUCKET_LISTBOX_CLASSES_OPTION_BASE
        };
      });

    } catch (e) {
      showErrorToast(
        CONSTANTS.CREATE_NEW_BUCKET_LABELS_ERROR_TITLE,
        e?.message || e?.body?.message
      );
    } finally {
      this.isLoading = false;
    }
  }

  handlePicklistUserSelection(event) {
    this.selectedOptions = event.detail?.selectedOptions;
    this.selectedUsers = this.selectedOptions?.map(opt => opt.value);
  }
}