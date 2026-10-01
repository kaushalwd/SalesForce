/**
* @description       : lwc modal used in modonEgyptManageInventory component to perform inventory actions like Release, UnRelease, Assign, Un-Assign, Back to Draft and Bucket Transfer
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   20-01-2026   Milin Kapatel      Initial Version
* 1.1   03-03-2026   Milin Kapatel      Used Constants and Utilities from common constants and utilities files
* 2.0   16-04-2026   Mirza Baig         Sort User list alphabetically
**/
import { api, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import LightningModal from 'lightning/modal';
import updateInventory from '@salesforce/apex/Modon_Egypt_ManageInventoryController.updateInventory';
import { CONSTANTS } from 'c/modonEgyptConstants';
import { showErrorToast } from 'c/modonEgyptUtilities';

export default class ModonEgyptManageInventoryModal extends LightningModal {
    @api jsonString;

    //************* filter values lists *************//
    timer;
    debouncers = {};

    action;
    selectedUnitIds;
    users;
    currentBucket;
    hoursToBlock;
    buckets;
    releaseStatuses;

    recordId;
    objectAPIName;
    recordFieldList;

    //====== To fetch all users ======//
    userAfterCursor;
    isUserReset = true;

    //====== input variables ======//
    selectedNewBucket;
    selectedReleaseStatus;
    selectedUser;
    selectedHoursToBlock;
    inputBlockComments;

    connectedCallback() {
        this.parseJSONString();
    }

    disconnectedCallback() {
        clearTimeout(this.timer);
    }

    parseJSONString() {
        try {
            if (this.jsonString) {
                this.resetUsers();
                const obj = JSON.parse(this.jsonString);
                this.action = obj.action || null;
                this.selectedUnitIds = obj.selectedUnitIds || null;
                this.users = obj.users || null;
                this.currentBucket = obj.selectedBucketName || null;
                this.hoursToBlock = obj.hoursToBlock || null;
                this.buckets = obj.buckets || null;
                this.releaseStatuses = obj.releaseStatuses || null;

                this.recordId = obj.recordId || null;
                this.objectAPIName = obj.objectAPIName || null;
                this.recordFieldList = obj.recordFieldList || null;
            }
        } catch (e) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_PARSING_JSON_TITLE,
                CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_PARSING_JSON_MSG
            );
        }
    }

    get selectedUnitsCount() {
        return Array.isArray(this.selectedUnitIds) && this.selectedUnitIds.length ? this.selectedUnitIds.length : 0;
    }

    get showReleaseSection() {
        return this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_RELEASE;
    }

    get isReleasedStatusAssigned() {
        return this.selectedReleaseStatus === CONSTANTS.MANAGE_INVENTORY_MODAL_RELEASE_STATUSES_ASSIGNED;
    }

    get showUserCombobox() {
        return this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN;
    }

    get showBucketCombobox() {
        return this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_BUCKET_TRANSFER;
    }

    get modalHeader() {
        if (this.isAction) return CONSTANTS.MANAGE_INVENTORY_MODAL_UI_MODAL_HEADER_SELECT_OPTION;
        if (this.isRecordEdit) return CONSTANTS.MANAGE_INVENTORY_MODAL_UI_MODAL_HEADER_UPDATE_UNIT_RECORD;
    }

    get isAction() {
        if (this.action) return true;
        return false;
    }

    get isRecordEdit() {
        if (this.recordId) return true;
        return false;
    }

    //2.0
    get userSortedOptions() {
        return [...this.users]?.sort((a, b) =>
            (a?.label || '')?.toLowerCase()?.localeCompare((b?.label || '')?.toLowerCase())
        );
    }

    get userVariables() {

        const vars = {};
        if (this.userAfterCursor) {
            vars.after = this.userAfterCursor;
        }
        if (Array.isArray(this.buckets) && this.buckets.length && this.action && ((this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN && this.selectedNewBucket) || (this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_RELEASE && this.currentBucket))) {
            vars.bucketName =
                this.action === CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN
                    ? this.buckets.filter(bucket => bucket.value == this.currentBucket.value)[0]?.label
                    : this.buckets.filter(bucket => bucket.value == this.selectedNewBucket)[0]?.label;
        }
        else {
            vars.bucketName = CONSTANTS.MANAGE_INVENTORY_MODAL_EMPTY_STRING;
        }
        return vars;
    }

    @wire(graphql, {
        query: gql`
                query userList($after: String, $bucketName: String) {
                    uiapi {
                        query{
                            GroupMember(
                                first: 200
                                after: $after
                                where: {
                                    Group: { 
                                        Name: { eq: $bucketName } 
                                    }
                                }
                                orderBy: {
                                    UserOrGroupId: { order: ASC }
                                }
                            ) {
                                edges {
                                    node {
                                        UserOrGroup {
                                           ... on User {
                                            Id
                                            Name { value }
                                            }
                                        }
                                    }
                                }
                                pageInfo {
                                    endCursor
                                    hasNextPage
                                }
                            }
                        }
                    }
                }
            `,
        variables: '$userVariables'
    })
    wiredUserValues({ data, errors }) {
        try {

            if (errors) {
                showErrorToast(
                    CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_TITLE,
                    CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_MSG
                );
                return;
            }

            if (!data) return;

            if (!this.users || this.isUserReset) {
                const tempUsers = data.uiapi.query.GroupMember.edges.map(edge => ({
                    label: edge.node?.UserOrGroup?.Name?.value || CONSTANTS.MANAGE_INVENTORY_MODAL_EMPTY_STRING,
                    value: edge.node?.UserOrGroup?.Id || CONSTANTS.MANAGE_INVENTORY_MODAL_EMPTY_STRING
                }));
                this.users = tempUsers?.filter(user => user.value?.startsWith("005", 0));
            }
            else {
                const tempUses = data.uiapi.query.GroupMember.edges.map(edge => ({
                    label: edge.node?.UserOrGroup?.Name?.value || CONSTANTS.MANAGE_INVENTORY_MODAL_EMPTY_STRING,
                    value: edge.node?.UserOrGroup?.Id || CONSTANTS.MANAGE_INVENTORY_MODAL_EMPTY_STRING
                }));
                this.users = [...this.users, ...tempUses?.filter(user => user.value?.startsWith("005", 0))];
            }
            this.isUserReset = false;

            if (data.uiapi.query.GroupMember.pageInfo.endCursor) {
                this.userAfterCursor = data.uiapi.query.GroupMember.pageInfo.endCursor;
            }
        } catch (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_TITLE,
                error.message || error.body?.message || CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_MSG
            );
        }
    }

    resetUsers() {
        this.users = [];
        this.userAfterCursor = null;
        this.isUserReset = true;
    }

    handleConfirm() {

        const params = {};
        switch (this.action) {
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_BACK_TO_DRAFT:
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_DRAFT;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_UNRELEASE:
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_UNRELEASE;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_RELEASE:
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_RELEASE;
                if (
                    !this.selectedNewBucket ||
                    !this.selectedReleaseStatus ||
                    (this.selectedReleaseStatus === CONSTANTS.MANAGE_INVENTORY_MODAL_RELEASE_STATUSES_ASSIGNED &&
                        (!this.selectedUser || !this.selectedHoursToBlock || !this.inputBlockComments))
                ) {
                    showErrorToast(
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_TITLE,
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_MSG
                    );
                    return;
                }
                params.bucketId = this.selectedNewBucket;
                if (this.selectedReleaseStatus === CONSTANTS.MANAGE_INVENTORY_MODAL_RELEASE_STATUSES_ASSIGNED) {
                    params.userId = this.selectedUser;
                    params.hoursToBlock = this.selectedHoursToBlock;
                    params.blockComments = this.inputBlockComments;
                }
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN:
                if (!this.selectedUser || !this.selectedHoursToBlock || !this.inputBlockComments) {
                    showErrorToast(
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_TITLE,
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_MSG
                    );
                    return;
                }
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN;
                params.userId = this.selectedUser;
                params.hoursToBlock = this.selectedHoursToBlock;
                params.blockComments = this.inputBlockComments;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_UN_ASSIGN:
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_UN_ASSIGN;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_BUCKET_TRANSFER:
                if (!this.selectedNewBucket) {
                    showErrorToast(
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_SELECT_BUCKET_TITLE,
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_SELECT_BUCKET_MSG
                    );
                    return;
                } else if (this.selectedNewBucket == this.currentBucket.value) {
                    showErrorToast(
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_BUCKET_SAME_TITLE,
                        CONSTANTS.MANAGE_INVENTORY_MODAL_TOAST_ERROR_BUCKET_SAME_MSG
                    );
                    return;
                }
                params.action = CONSTANTS.MANAGE_INVENTORY_MODAL_ACTIONS_BUCKET;
                params.bucketId = this.selectedNewBucket;
                break;
            default:
                break;
        }
        params.unitIds = this.selectedUnitIds;
        const jsonString = JSON.stringify(params);

        updateInventory({ jsonString })
            .then(result => {
                if (result == CONSTANTS.SUCCESS_UPPER) {
                    this.close(CONSTANTS.SUCCESS_LOWER);
                } else {
                    this.close(CONSTANTS.ERROR_LOWER);
                }
            })
            .catch(error => {
                this.close(CONSTANTS.ERROR_LOWER);
            });

    }
    handleInputChange(event) {
        const dataId = event.currentTarget.dataset.id;
        const value = event.target.value;

        switch (dataId) {
            case CONSTANTS.MANAGE_INVENTORY_MODAL_FILTER_IDS_NEW_BUCKET_COMBOBOX:
                this.selectedNewBucket = value;
                this.resetUsers();
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_FILTER_IDS_RELEASE_STATUS:
                this.selectedReleaseStatus = value;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_FILTER_IDS_USER_COMBOBOX:
                this.selectedUser = value;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_FILTER_IDS_HOURS_COMBOBOX:
                this.selectedHoursToBlock = value;
                break;
            case CONSTANTS.MANAGE_INVENTORY_MODAL_FILTER_IDS_BLOCK_COMMENTS_TEXTAREA:
                this.inputBlockComments = value;
                break;

            default:
                break;
        }
    }
    handleRecordUpdateSuccess() {

        this.close(CONSTANTS.SUCCESS_LOWER);
    }

    handleRecordUpdateFailure() {
        this.close(CONSTANTS.ERROR_LOWER);
    }
    handleCancel() {
        this.close(CONSTANTS.CANCEL_LOWER);
    }
}