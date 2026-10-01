import { LightningElement, track } from 'lwc';
import searchByLeadNumber from '@salesforce/apex/LeadSearchAssignByNumberController.searchByLeadNumber';
import USER_ID from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadSearchAssignByNumberHome extends LightningElement {
    term = '';
    @track rows = [];
    isLoading = false;
    hasSearched = false;

    get selectedLead() {
        return (this.rows && this.rows.length === 1) ? this.rows[0] : null;
    }

    get selectedLeadNumber() {
        return this.selectedLead ? this.selectedLead.leadNumber : '';
    }

    get hasResult() {
        return !this.isLoading && !!this.selectedLead;
    }

    get isSearchDisabled() {
        return this.isLoading || !this.term || !this.term.trim();
    }

    get noResults() {
        return !this.isLoading && this.hasSearched && !this.selectedLead;
    }

    // ---- Status display logic (exactly as requested) ----
    get statusMessage() {
        const lead = this.selectedLead;
        if (!lead) return '';

        if (lead.isConverted) {
            return 'Lead is already converted';
        }
        if (lead.ownerId === USER_ID) {
            return 'You already own the lead';
        }
        return `Owner of the current lead: ${lead.ownerName || 'Unknown'}`;
    }

    get statusIcon() {
        const lead = this.selectedLead;
        if (!lead) return 'utility:info';

        if (lead.isConverted) return 'utility:check';
        if (lead.ownerId === USER_ID) return 'utility:user';
        return 'utility:people';
    }

    handleChange(e) {
        this.term = e.target.value;
    }

    handleKeyUp(e) {
        if (e.key === 'Enter') this.handleSearch();
    }

    handleClear() {
        this.term = '';
        this.rows = [];
        this.hasSearched = false;
    }

    async handleSearch() {
        if (this.isSearchDisabled) return;

        this.isLoading = true;
        this.hasSearched = true;

        try {
            const res = await searchByLeadNumber({
                leadNumberTerm: this.term.trim(),
                maxRows: 1
            });
            this.rows = Array.isArray(res) ? res : [];
        } catch (e) {
            this.rows = [];
            this.toast('Error', this.errMsg(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(e) {
        return e?.body?.message || e?.message || 'Unexpected error';
    }
}