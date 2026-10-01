import { LightningElement, api, track } from 'lwc';
import searchActiveUsers from '@salesforce/apex/CommissionPreReviewController.searchActiveUsers';

export default class CommissionOwnerLookup extends LightningElement {
    @api context;
    @api value;
    @api displayValue;

    @track results = [];
    @track searchKey = '';
    @track showDropdown = false;

    debounceTimeout;
    hasSearched = false;

    connectedCallback() {
        this.searchKey = this.displayValue || '';
    }

    get showNoResults() {
        return this.showDropdown && this.hasSearched && this.results.length === 0;
    }

    handleKeyUp(event) {
        this.searchKey = event.target.value;
        this.hasSearched = false;

        window.clearTimeout(this.debounceTimeout);

        if (!this.searchKey || this.searchKey.trim().length < 2) {
            this.results = [];
            this.showDropdown = false;
            return;
        }

        this.debounceTimeout = window.setTimeout(async () => {
            try {
                const response = await searchActiveUsers({ searchKey: this.searchKey.trim() });
                this.results = response || [];
                this.hasSearched = true;
                this.showDropdown = true;
            } catch (error) {
                this.results = [];
                this.hasSearched = true;
                this.showDropdown = false;
            }
        }, 300);
    }

    handleBlur() {
        window.setTimeout(() => {
            this.showDropdown = false;
        }, 200);
    }

    handleSelect(event) {
        event.preventDefault();

        const ownerId = event.currentTarget.dataset.id;
        const ownerName = event.currentTarget.dataset.name;

        this.value = ownerId;
        this.displayValue = ownerName;
        this.searchKey = ownerName;
        this.showDropdown = false;

        this.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: {
                    draftValues: [
                        {
                            recordId: this.context,
                            ownerId: ownerId,
                            ownerName: ownerName
                        }
                    ]
                },
                bubbles: true,
                composed: true
            })
        );
    }
    @api focus() {
        this.template.querySelector('lightning-input')?.focus();
    }

    @api get validity() {
        return this.template.querySelector('lightning-input')?.validity || { valid: true };
    }

    @api showHelpMessageIfInvalid() {
        this.template.querySelector('lightning-input')?.showHelpMessageIfInvalid();
    }
}