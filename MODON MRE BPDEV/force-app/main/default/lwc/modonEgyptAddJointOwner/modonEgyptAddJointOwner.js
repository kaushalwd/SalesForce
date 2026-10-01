/**
 * -----------------------------------------------------------------------------
 * Component Name : ModonEgyptAddJointOwner
 * Description    : 
 * This component allows users to:
 *  - Fetch available joint owners from Opportunity
 *  - Select and assign ownership percentages
 *  - Validate ownership rules (total <= 100%, primary > 0)
 *  - Create Sales Order Joint Owner records
 *
 * Key Features:
 *  - Dynamic ownership calculation
 *  - Validation for ownership limits
 *  - Inline editing support
 *  - Toast notifications for success/error
 *
 * Ver   Date         Author             Modification
 * 1.0   02-05-2026   Mirza Baig      Initial Version
 * -----------------------------------------------------------------------------
 */

import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

import getJointOwners from '@salesforce/apex/ModonEgyptAddJointOwnerController.getJointOwners';
import createSalesOrderJointOwners from '@salesforce/apex/ModonEgyptAddJointOwnerController.createSalesOrderJointOwners';

import { ADD_JOINT_OWNERS_COLUMNS, CONSTANTS, ERROR_TOTAL_EXCEED } from 'c/modonEgyptConstants';
import { showErrorToast, showSuccessToast } from 'c/modonEgyptUtilities';

export default class ModonEgyptAddJointOwner extends LightningElement {
    _recordId;

    /** Track fields */
    @track data = [];
    @track selectedRows = [];
    @track totalOwnership = 0;
    @track isLoading = false;

    /** Common fields */
    columns = ADD_JOINT_OWNERS_COLUMNS;
    totalExistingOwnership = 0;
    totalAvailableOwnership = 100;
    isRecordFound = true;

    /**
     * Setter for recordId (Sales Order Id)
     * Automatically triggers data load when value is set
     */
    @api
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadData();
        }
    }

    /** Getter for recordId */
    get recordId() {
        return this._recordId;
    }

    /**
     * Determines if Save button should be disabled
     * Disabled when:
     *  - No rows selected
     *  - Ownership exceeds or equals available limit
     */
    get isSaveDisabled() {
        return this.totalOwnership >= this.totalAvailableOwnership || this.selectedRows.length === 0;
    }

    /** Checks if ownership exceeds allowed limit */
    get isOwnershipExceed() {
        return this.totalOwnership >= this.totalAvailableOwnership;
    }

    /**
     * Calculates remaining ownership for primary owner
     * Formula:
     * 100 - selected ownership - existing ownership
     */
    get primaryOwnership() {
        return 100 - (this.totalOwnership || 0) - (this.totalExistingOwnership || 0);
    }

    /**
     * Returns warning message based on ownership validation
     */
    get warningMsg() {
        return this.primaryOwnership <= 0 
            ? 'Primary owner ownership must be greater than 0%' 
            : ERROR_TOTAL_EXCEED;
    }

    /**
     * Calls Apex to fetch:
     *  - Opportunity joint owners
     *  - Existing sales order joint owners
     * Also calculates existing ownership
     */
    loadData() {
        this.isLoading = true;

        getJointOwners({ salesOrderId: this.recordId })
            .then(result => {
                const oppJointOwners = result.oppJointOwners;

                // Map data for datatable
                this.data = oppJointOwners?.map(item => ({
                    Id: item.Id,
                    name: item?.JointOwnerAccount__r?.Name,
                    ownership: item?.OwnershipPercentage__c || 0
                }));

                // Calculate already assigned ownership
                this.totalExistingOwnership = result?.existingJointOwners 
                    ? result?.existingJointOwners?.reduce((sum, item) => {
                        return sum + (parseFloat(item?.OwnershipPercentage__c) || 0);
                    }, 0)
                    : 0;

                // Adjust available ownership
                this.totalAvailableOwnership -= this.totalExistingOwnership;
            })
            .finally(() => {
                this.isLoading = false;
                this.isRecordFound = this.data?.length > 0;
            });
    }

    /**
     * Handles row selection event from datatable
     * Updates selected rows and recalculates total ownership
     */
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
        this.calculateTotal();
    }

    /**
     * Handles inline cell edit changes
     * Updates ownership values in local data
     */
    handleCellChange(event) {
        const draftValues = event.detail.draftValues;

        draftValues.forEach(draft => {
            const index = this.data.findIndex(d => d.Id === draft.Id);
            if (index !== -1) {
                this.data[index].ownership = draft.ownership;
            }
        });

        this.calculateTotal();
    }

    /**
     * Calculates total ownership of selected rows
     */
    calculateTotal() {
        this.totalOwnership = this.selectedRows.reduce((sum, row) => {
            const record = this.data.find(d => d.Id === row.Id);
            return sum + (parseFloat(record?.ownership) || 0);
        }, 0);
    }

    /**
     * Handles Save action:
     *  - Validates selection and ownership rules
     *  - Calls Apex to create joint owners
     *  - Shows success/error toast
     */
    async handleSave() {
        try {
            this.isLoading = true;

            // Validation: no selection
            if (this.selectedRows.length === 0) {
                showErrorToast(CONSTANTS.ERROR_NORMAL, 'Please select at least one joint owner');
                return;
            }

            // Validation: ownership exceeds
            if (this.totalOwnership >= this.totalAvailableOwnership) {
                showErrorToast(CONSTANTS.ERROR_NORMAL, ERROR_TOTAL_EXCEED);
                return;
            }

            // Prepare payload for Apex
            const selectedJointOwnerMap = {};
            this.selectedRows.forEach(row => {
                selectedJointOwnerMap[row.Id] = parseFloat(row.ownership);
            });

            // Call Apex method
            await createSalesOrderJointOwners({
                selectedJointOwnerMap,
                salesOrderId: this.recordId
            });

            showSuccessToast('Joint Owner linked to sales order successfully!');

            this.closeAction();

            setTimeout(() => {
                window.location.reload();
            }, 1000); // 1 seconds
        } catch (e) {
            showErrorToast(CONSTANTS.ERROR_NORMAL, e?.message || e?.body?.message);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Closes the quick action modal
     */
    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}