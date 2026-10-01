import { LightningElement, api, track } from 'lwc';
import { isArrayNotEmpty, isStringContainsIgnoreCase, debounce } from 'c/utils';

export default class MultiSelectPicklistComponent extends LightningElement {
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


    searchValue = '';
    oldSearchValue = '';

    connectedCallback() {
        this.debouncedHandleSearch = debounce(this.handleSearch, 500);
    }

    handleSelectionLi(event) {
        const optionVal = event.currentTarget.dataset.id;
        let standardsOptions = JSON.parse(JSON.stringify(this.standardsOptions));
        this.standardsOptions = standardsOptions?.map((opt) => {
            if (opt.value === optionVal && !opt.isSelected) {
                opt.liClass += ' slds-is-selected';
                opt.isSelected = true;
            } else if (opt.value === optionVal && opt.isSelected) {
                opt.liClass.replace('slds-is-selected', '');
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
                opt.liClass += ' slds-is-selected';
                opt.isSelected = true;
            } else if (opt.value === optionVal && opt.isSelected) {
                opt.liClass.replace('slds-is-selected', '');
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
        this.debouncedHandleSearch();
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
        }, 500);
    }

    sendToParent() {
        const customEvent = new CustomEvent('userselection', {
            detail: {
                selectedOptions: this.selectedOptions
            }
        });
        // Dispatch the custom event
        this.dispatchEvent(customEvent);
    }
}