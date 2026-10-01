/**
* @description       : LWC used in Create Bucket component to manage available and selected users of bucket.
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2025   Milin Kapatel      Initial Version
* 1.1   03-03-2026   Milin Kapatel      Used Constants and Utilities from common constants and utilities files
* 1.2   05-03-2026   Milin Kapatel      Bug fix: in Search User
**/
import { LightningElement, api, track } from 'lwc';
import { CONSTANTS } from 'c/modonEgyptConstants';
import { isArrayNotEmpty, isStringContainsIgnoreCase, debounce } from 'c/modonEgyptUtilities';

export default class ModonEgyptMultiSelectPicklistComponent extends LightningElement {

    @api parsedUserOptions = [];
    @api selectedOptions = [];

    get standardsOptionList() {
        return this._standardsOptionList || [];
    }

    @api
    set standardsOptionList(value) {
        if (value?.length > 0) {
            this._standardsOptionList = value || [];
            this.standardsOptions = JSON.parse(JSON.stringify(value || []));
            this.standardsOptions = this.standardsOptions?.filter(opt => !opt?.isSelected);
        }
    }

    @track
    standardsOptions = [];

    searchValue = CONSTANTS.MULTI_SELECT_EMPTY_STRING;
    oldSearchValue = CONSTANTS.MULTI_SELECT_EMPTY_STRING;
    
    //v1.2 removed connected callback as it was no needed

    handleSelectionLi(event) {
        const optionVal = event.currentTarget.dataset.id;
        let standardsOptions = JSON.parse(JSON.stringify(this.standardsOptions));
        this.standardsOptions = standardsOptions?.map((opt) => {
            if (opt.value === optionVal && !opt.isSelected) {
                opt.liClass += CONSTANTS.MULTI_SELECT_LISTBOX_CLASSES_SELECTED_SUFFIX;
                opt.isSelected = true;
            } else if (opt.value === optionVal && opt.isSelected) {
                opt.liClass = opt.liClass.replace(
                    CONSTANTS.MULTI_SELECT_LISTBOX_CLASSES_SELECTED_SUFFIX,
                    CONSTANTS.MULTI_SELECT_EMPTY_STRING
                );
                opt.isSelected = false;
            }
            return opt;
        });
    }

    handleUnSelectionLi(event) {
        const optionVal = event.currentTarget.dataset.id;
        let selectedOptions = JSON.parse(JSON.stringify(this.selectedOptions));
        this.selectedOptions = selectedOptions?.map((opt) => {
            if (opt.value === optionVal && !opt.isSelected) {
                opt.liClass += CONSTANTS.MULTI_SELECT_LISTBOX_CLASSES_SELECTED_SUFFIX;
                opt.isSelected = true;
            } else if (opt.value === optionVal && opt.isSelected) {
                opt.liClass = opt.liClass.replace(
                    CONSTANTS.MULTI_SELECT_LISTBOX_CLASSES_SELECTED_SUFFIX,
                    CONSTANTS.MULTI_SELECT_EMPTY_STRING
                );
                opt.isSelected = false;
            }
            return opt;
        });
    }

    handleSelection() {
        let selectedOpt = JSON.parse(JSON.stringify(this.standardsOptions?.filter(opt => opt?.isSelected)));
        if (selectedOpt?.length === 0) {
            return;
        }
        selectedOpt = selectedOpt?.map((opt) => {
            opt.isSelected = false;
            return opt;
        });

        let selectedOptions = JSON.parse(JSON.stringify(this.selectedOptions));
        this.selectedOptions = selectedOptions.concat(selectedOpt);
        this.standardsOptions = this.standardsOptions?.filter(opt => !opt?.isSelected);

        this.sendToParent();
    }

    handleUnSelection() {
        let selectedOpt = JSON.parse(JSON.stringify(this.selectedOptions?.filter(opt => opt?.isSelected)));
        if (selectedOpt?.length === 0) {
            return;
        }

        const availableUserIds = this.parsedUserOptions?.map(opt => opt.Id);
        if (isArrayNotEmpty(availableUserIds)) {
            selectedOpt = selectedOpt?.filter(opt => availableUserIds.includes(opt.value))?.map((opt) => {
                opt.isSelected = false;
                return opt;
            });
        }

        if (isArrayNotEmpty(selectedOpt))
            this.standardsOptions = this.standardsOptions.concat(selectedOpt);
        let selectedOptions = JSON.parse(JSON.stringify(this.selectedOptions));
        this.selectedOptions = selectedOptions?.filter(opt => !opt?.isSelected);

        this.sendToParent();
    }

    handleSearchChange(event) {
        this.searchValue = event.target.value;
        //v1.2 - Debouncing search input to avoid excessive filtering while user is typing
        debounce(
            CONSTANTS.MULTI_SELECT_DEBOUCE_SEARCH_KEY,
            this.handleSearch.bind(this),
            CONSTANTS.MULTI_SELECT_SEARCH_DEBOUNCE_MS
        );
    }

    handleSearch() {
        this.isLoading = true;
        const searchedList = this.searchValue?.length > this.oldSearchValue?.length ? this.standardsOptions : this.standardsOptionList;
        let searchedActivities = [];
        if (this.searchValue) {
            searchedActivities = searchedList?.filter(item => isStringContainsIgnoreCase(item?.label?.toLocaleLowerCase(), this.searchValue?.toLocaleLowerCase()));
        }

        setTimeout(() => {
            const selectedOptions = this.selectedOptions?.map(opt => opt.value);
            this.standardsOptions = !this.searchValue ? JSON.parse(JSON.stringify(this.standardsOptionList?.filter(opt => !selectedOptions.includes(opt.value)))) : JSON.parse(JSON.stringify(searchedActivities));
            this.oldSearchValue = JSON.parse(JSON.stringify(this.searchValue));
            this.isLoading = false;
        }, CONSTANTS.MULTI_SELECT_SEARCH_DEBOUNCE_MS);
    }

    sendToParent() {
        const customEvent = new CustomEvent(CONSTANTS.MULTI_SELECT_EVENTS_USER_SELECTION, {
            detail: {
                selectedOptions: this.selectedOptions
            }
        });
        // Dispatch the custom event
        this.dispatchEvent(customEvent);
    }
}