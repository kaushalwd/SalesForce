import { LightningElement, track } from 'lwc';
import searchLeadsByNumber    from '@salesforce/apex/leadSearchController.searchLeadsByNumber';
import assignLeadToCurrentUser from '@salesforce/apex/leadSearchController.assignLeadToCurrentUser';
import searchEOIApex          from '@salesforce/apex/leadSearchController.searchEOI';
import assignEOIToCurrentUser  from '@salesforce/apex/leadSearchController.assignEOIToCurrentUser';
import { NavigationMixin }    from 'lightning/navigation';
import { ShowToastEvent }     from 'lightning/platformShowToastEvent';

// import convertLeadToOpportunity from '@salesforce/apex/leadSearchController.convertLeadToOpportunity';

export default class LeadSearch extends NavigationMixin(LightningElement) {

    // ═══════════════════════════════════════════════════════
    // SHARED STATE
    // ═══════════════════════════════════════════════════════
    @track activeTab = 'lead';   // 'lead' | 'eoi'

    // ═══════════════════════════════════════════════════════
    // LEAD SEARCH STATE  (v1.0 - unchanged)
    // ═══════════════════════════════════════════════════════
    @track searchKey          = '';
    @track leads              = null;
    @track noRecords          = false;
    @track showInitialMessage = true;

    // ═══════════════════════════════════════════════════════
    // EOI SEARCH STATE  (v2.0 - new)
    // ═══════════════════════════════════════════════════════
    @track eoiSearchKey          = '';
    @track eoiResult             = null;
    @track eoiNotFound           = false;
    @track showEOIInitialMessage = true;
    @track lastAccessedEOI       = null;   // persists for component lifetime

    // ═══════════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════════
    connectedCallback() {
        this.showInitialMessage  = true;
        this.showEOIInitialMessage = true;
    }

    // ═══════════════════════════════════════════════════════
    // TAB GETTERS
    // ═══════════════════════════════════════════════════════
    get isLeadTab() { return this.activeTab === 'lead'; }
    get isEOITab()  { return this.activeTab === 'eoi';  }

    get leadTabClass() {
        return 'lsc-tab-btn' + (this.isLeadTab ? ' lsc-tab-btn--active' : '');
    }
    get eoiTabClass() {
        return 'lsc-tab-btn' + (this.isEOITab ? ' lsc-tab-btn--active' : '');
    }

    // ═══════════════════════════════════════════════════════
    // TAB HANDLERS
    // ═══════════════════════════════════════════════════════
    handleLeadTab() { this.activeTab = 'lead'; }
    handleEOITab()  { this.activeTab = 'eoi';  }

    // ═══════════════════════════════════════════════════════
    // LEAD SEARCH  (v1.0 - unchanged)
    // ═══════════════════════════════════════════════════════
    handleInput(event) {
        this.searchKey = event.target.value;
    }

    searchLeads() {
        this.showInitialMessage = false;
        this.noRecords          = false;

        searchLeadsByNumber({ leadNumber: this.searchKey })
            .then(result => {
                this.leads = result;
                if (result.length === 0) {
                    this.noRecords = true;
                    this.leads     = null;
                }
            })
            .catch(() => {
                this.leads     = null;
                this.noRecords = true;
            });
    }

    assignToMe(event) {
        const leadId = event.target.dataset.id;

        assignLeadToCurrentUser({ leadId })
            .then(() => {
                this.showToast('Success', 'Lead assigned to you', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: leadId, objectApiName: 'Lead', actionName: 'view' }
                });
            })
            .catch(error => {
                this.showToast('Assignment Failed', error.body?.message || 'Unexpected error', 'error');
            });
    }

    convertLead(event) {
        /*const leadId = event.target.dataset.id;
        convertLeadToOpportunity({ leadId })
            .then(opptyId => {
                this.showToast('Success', 'Lead converted successfully', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: opptyId, objectApiName: 'Opportunity', actionName: 'view' }
                });
            })
            .catch(error => {
                this.showToast('Conversion Failed', error.body.message, 'error');
            });*/
    }

    handleCancel() {
        this.leads              = null;
        this.searchKey          = '';
        this.noRecords          = false;
        this.showInitialMessage = true;
    }

    // ═══════════════════════════════════════════════════════
    // EOI SEARCH  (v2.0 - new)
    // ═══════════════════════════════════════════════════════
    handleEOIInput(event) {
        this.eoiSearchKey = event.target.value;
    }

    searchEOI() {
        this.showEOIInitialMessage = false;
        this.eoiNotFound           = false;
        this.eoiResult             = null;

        searchEOIApex({ searchKey: this.eoiSearchKey })
            .then(result => {
                this.eoiResult   = result;
                this.eoiNotFound = false;
            })
            .catch(error => {
                this.eoiResult   = null;
                this.eoiNotFound = true;
                const msg = error?.body?.message;
                if (msg && !msg.includes('No EOI found')) {
                    // Surface unexpected errors as toast; "not found" is shown inline
                    this.showToast('Search Error', msg, 'error');
                }
            });
    }

    assignEOI(event) {
        const eoiId = event.target.dataset.id;

        assignEOIToCurrentUser({ eoiId })
            .then(opportunityId => {
                this.showToast('Success', 'EOI assigned to you successfully', 'success');

                // Store last accessed EOI for display
                this.lastAccessedEOI = {
                    eoiCustomId:     this.eoiResult.eoiCustomId || this.eoiResult.eoiName,
                    opportunityName: this.eoiResult.opportunityName || '—'
                };

                // Clear result
                this.eoiResult             = null;
                this.eoiSearchKey          = '';
                this.showEOIInitialMessage = true;

                // Navigate to Opportunity if available
                if (opportunityId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId:      opportunityId,
                            objectApiName: 'Opportunity',
                            actionName:    'view'
                        }
                    });
                }
            })
            .catch(error => {
                this.showToast('Assignment Failed', error.body?.message || 'Unexpected error', 'error');
            });
    }

    handleEOICancel() {
        this.eoiResult             = null;
        this.eoiSearchKey          = '';
        this.eoiNotFound           = false;
        this.showEOIInitialMessage = true;
    }

    // ─── EOI card getters ──────────────────────────────────
    get isAssignedOther() {
        return this.eoiResult && this.eoiResult.assignmentState === 'assigned_other';
    }
    get isAlreadyMine() {
        return this.eoiResult && this.eoiResult.assignmentState === 'already_mine';
    }
    get isAvailable() {
        return this.eoiResult && this.eoiResult.assignmentState === 'available';
    }
    get isNoOpportunity() {
        return this.eoiResult && this.eoiResult.assignmentState === 'no_opportunity';
    }

    // Show assign button ONLY when:
    //   - state is 'available' (Opportunity.OwnerId = Custom Label)
    //   - AND no Sales Order on Opportunity
    //   - AND an Opportunity is linked
    get showAssignButton() {
        return this.isAvailable
            && !this.eoiResult.hasSalesOrder
            && !this.isNoOpportunity;
    }

    // Card border colour class
    get eoiCardClass() {
        if (!this.eoiResult) return 'lsc-result-card';
        if (this.eoiResult.hasSalesOrder)                            return 'lsc-result-card lsc-card--warning';
        if (this.eoiResult.assignmentState === 'assigned_other')     return 'lsc-result-card lsc-card--error';
        if (this.eoiResult.assignmentState === 'already_mine')       return 'lsc-result-card lsc-card--info';
        if (this.eoiResult.assignmentState === 'available')          return 'lsc-result-card lsc-card--success';
        return 'lsc-result-card';
    }

    // ═══════════════════════════════════════════════════════
    // SHARED UTILS
    // ═══════════════════════════════════════════════════════
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}