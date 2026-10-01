import {LightningElement, api} from 'lwc';
export default class customMultiSelectPicklistLwc extends LightningElement {
    @api label = "Default label";
    _disabled = false;
    inputOptions = [];
    value = [];
    inputValue = '';
    @api placeholder = 'Select an Option';
    hasRendered = false;
    comboboxIsRendered = false;
    dropDownInFocus = false;

    @api
    get disabled() {
        return this._disabled;
    }
    set disabled(value) {
        this._disabled = value;
        this.handleDisabled();
    }

    @api
    get options() {
        return this.inputOptions;
    }
    set options(value) {
        this.inputOptions = value;
    }

    @api
    clear() {
        this.value = [];
        this.inputValue = '';
        this.clearSelections();
        this.sendValues();
    }

    renderedCallback() {
        if (!this.hasRendered) {
            this.handleDisabled();
        }
        this.hasRendered = true;
    }

    handleDisabled() {
        let input = this.template.querySelector("input");
        if (input) {
            input.disabled = this.disabled;
        }
    }

    handleClick() {
        let sldsCombobox = this.template.querySelector(".slds-combobox");
        sldsCombobox.classList.toggle("slds-is-open");
    }

    handleSelection(event) {
        let value = event.currentTarget.dataset.value;
        this.handleOption(event, value);
        let input = this.template.querySelector("input");
        input.focus();
        this.sendValues();
    }

    sendValues() {
        let values = this.value.map(valueObject => valueObject.value);
        this.dispatchEvent(new CustomEvent("valuechange", {
            detail: values
        }));
    }

    handleOption(event, value) {
        let listBoxOption = event.currentTarget.firstChild;
        
        if (listBoxOption.classList.contains("slds-is-selected")) {
            this.value = this.value.filter(option => option.value !== value);
        } else {
            let option = this.options.find(option => option.value === value);
            this.value.push(option);
        }

        if (this.value.length > 1) {
            this.inputValue = this.value.length + ' options selected';
        } else if (this.value.length === 1) {
            this.inputValue = this.value[0].label;
        } else {
            this.inputValue = ''; // Empty when no selection
        }

        listBoxOption.classList.toggle("slds-is-selected");
    }

    clearSelections() {
        let listBoxOptions = this.template.querySelectorAll('.slds-is-selected');
        for (let option of listBoxOptions) {
            option.classList.remove("slds-is-selected");
        }
    }

    handleBlur() {
        if (!this.dropDownInFocus) {
            this.closeDropbox();
        }
    }

    handleMouseleave() {
        this.dropDownInFocus = false;
    }

    handleMouseEnter() {
        this.dropDownInFocus = true;
    }

    closeDropbox() {
        let sldsCombobox = this.template.querySelector(".slds-combobox");
        sldsCombobox.classList.remove("slds-is-open");
    }
}