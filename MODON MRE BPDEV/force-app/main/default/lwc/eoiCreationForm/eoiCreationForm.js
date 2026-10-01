import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue }           from 'lightning/uiRecordApi';
import { CloseActionScreenEvent }             from 'lightning/actions';
import { NavigationMixin }                    from 'lightning/navigation';

import getProjects  from '@salesforce/apex/SubmitEOIController.getProjects';
import getPhases    from '@salesforce/apex/SubmitEOIController.getPhases';
import getUnitTypes from '@salesforce/apex/SubmitEOIController.getUnitTypes';
import getBedrooms  from '@salesforce/apex/SubmitEOIController.getBedrooms';
import getEOIRange  from '@salesforce/apex/SubmitEOIController.getEOIRange';
import validateEOI  from '@salesforce/apex/SubmitEOIController.validateEOI';
import createEOI    from '@salesforce/apex/SubmitEOIController.createEOI';

import OPP_NAME from '@salesforce/schema/Opportunity.Name';
const OPP_FIELDS = [OPP_NAME];

export default class EoiCreationForm extends NavigationMixin(LightningElement) {

    @api recordId;

    @track opportunityName   = '';
    @track opportunityNumber = '';

    @wire(getRecord, { recordId: '$recordId', fields: OPP_FIELDS })
    wiredOpp({ data }) {
        if (data) {
            this.opportunityName   = getFieldValue(data, OPP_NAME) || '';
            this.opportunityNumber = this.recordId ? this.recordId.substring(0, 15) : '';
            this._runValidation();
        }
    }

    @track projectOptions  = [];
    @track phaseOptions    = [];
    @track unitTypeOptions = [];
    @track bedroomOptions  = [];

    @track selectedProjectId   = '';
    @track selectedProjectName = '';
    @track selectedPhaseId     = '';
    @track selectedUnitType    = '';
    @track selectedBedrooms    = '';
    @track numberOfUnits       = '';
    @track remarks             = '';      // ← NEW: maps to EOIComments__c

    @track matchedRangeId = null;
    @track matchedAmount  = null;

    @track showQuota      = false;
    @track quotaLimit     = 0;
    @track quotaUsed      = 0;
    @track quotaRemaining = 0;

    @track isDuplicate    = false;
    @track existingEOIRef = '';
    @track showOppStatus  = false;
    @track errorMessage   = '';

    @track isLoading      = false;
    @track showSuccess    = false;
    @track createdEOIRef  = '';
    @track showQuotaModal = false;

    connectedCallback() {
        this._loadProjects();
    }

    async _loadProjects() {
        try {
            this.projectOptions = await getProjects();
        } catch (e) {
            this.errorMessage = 'Failed to load projects: ' + this._err(e);
        }
    }

    async _runValidation() {
        if (!this.recordId) return;
        try {
            const res = await validateEOI({
                opportunityId: this.recordId,
                projectId: this.selectedProjectId || null
            });
            this.isDuplicate    = res.isDuplicate;
            this.existingEOIRef = res.existingEOIRef || '';
            this.showOppStatus  = true;
            if (this.selectedProjectId) {
                this.quotaLimit     = res.quotaLimit;
                this.quotaUsed      = res.quotaUsed;
                this.quotaRemaining = res.quotaRemaining;
                this.showQuota      = true;
            }
        } catch (e) {
            console.error('Validation error', e);
        }
    }

    async handleProjectChange(e) {
        this.selectedProjectId   = e.target.value;
        const found              = this.projectOptions.find(o => o.value === this.selectedProjectId);
        this.selectedProjectName = found ? found.label : '';
        this.selectedPhaseId     = '';
        this.selectedUnitType    = '';
        this.selectedBedrooms    = '';
        this.phaseOptions        = [];
        this.unitTypeOptions     = [];
        this.bedroomOptions      = [];
        this.matchedRangeId      = null;
        this.matchedAmount       = null;
        this.errorMessage        = '';
        this.showQuotaModal      = false;

        if (!this.selectedProjectId) { this.showQuota = false; return; }
        try {
            this.phaseOptions = await getPhases({ projectId: this.selectedProjectId });
            await this._runValidation();
            if (this.quotaRemaining <= 0) this.showQuotaModal = true;
        } catch (err) {
            this.errorMessage = 'Failed to load phases: ' + this._err(err);
        }
    }

    async handlePhaseChange(e) {
        this.selectedPhaseId  = e.target.value;
        this.selectedUnitType = '';
        this.selectedBedrooms = '';
        this.unitTypeOptions  = [];
        this.bedroomOptions   = [];
        this.matchedRangeId   = null;
        this.matchedAmount    = null;

        if (!this.selectedPhaseId) return;
        try {
            this.unitTypeOptions = await getUnitTypes({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId
            });
        } catch (err) {
            this.errorMessage = 'Failed to load unit types: ' + this._err(err);
        }
    }

    async handleUnitTypeChange(e) {
        this.selectedUnitType = e.target.value;
        this.selectedBedrooms = '';
        this.bedroomOptions   = [];
        this.matchedRangeId   = null;
        this.matchedAmount    = null;

        if (!this.selectedUnitType) return;
        try {
            this.bedroomOptions = await getBedrooms({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId,
                unitType:  this.selectedUnitType
            });
        } catch (err) {
            this.errorMessage = 'Failed to load bedrooms: ' + this._err(err);
        }
    }

    async handleBedroomsChange(e) {
        this.selectedBedrooms = e.target.value;
        this.matchedRangeId   = null;
        this.matchedAmount    = null;

        if (!this.selectedBedrooms) return;
        try {
            const res = await getEOIRange({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId,
                unitType:  this.selectedUnitType,
                bedrooms:  this.selectedBedrooms
            });
            if (res) {
                this.matchedRangeId = res.rangeId;
                this.matchedAmount  = res.amount;
            } else {
                this.errorMessage = 'No active EOI Range found for this selection.';
            }
        } catch (err) {
            this.errorMessage = 'Failed to fetch EOI Range: ' + this._err(err);
        }
    }

    handleUnitsChange(e) {
        this.numberOfUnits = e.target.value;
    }

    handleRemarksChange(e) {           // ← NEW
        this.remarks = e.target.value;
    }

    async handleCreate() {
        this.isLoading    = true;
        this.errorMessage = '';
        try {
            const units = parseInt(this.numberOfUnits, 10);
            const total = (units > 0 && this.matchedAmount) ? units * this.matchedAmount : this.matchedAmount;
            const eoiId = await createEOI({
                opportunityId: this.recordId,
                projectId:     this.selectedProjectId,
                phaseId:       this.selectedPhaseId,
                unitType:      this.selectedUnitType,
                bedrooms:      this.selectedBedrooms,
                numberOfUnits: units,
                eoiRangeId:    this.matchedRangeId,
                eoiAmount:     total,
                remarks:       this.remarks
            });
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: eoiId, objectApiName: 'Expressionofinterest__c', actionName: 'view' }
            });
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            this.errorMessage = this._err(err);
            await this._runValidation();
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    closeQuotaModal()          { this.showQuotaModal = false; }
    handleModalBackdropClick() { this.showQuotaModal = false; }
    stopPropagation(e)         { e.stopPropagation(); }

    get isFormDisabled()     { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0); }
    get isPhaseDisabled()    { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedProjectId; }
    get isUnitTypeDisabled() { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedPhaseId; }
    get isBedroomsDisabled() { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedUnitType; }

    get isCreateDisabled() {
        return (
            this.isLoading                                  ||
            this.isDuplicate                                ||
            (this.showQuota && this.quotaRemaining <= 0)    ||
            !this.selectedProjectId                         ||
            !this.selectedPhaseId                           ||
            !this.selectedUnitType                          ||
            !this.selectedBedrooms                          ||
            !this.numberOfUnits                             ||
            parseInt(this.numberOfUnits, 10) < 1            ||
            !this.matchedRangeId                            ||
            !this.remarks.trim()
        );
    }

    get displayAmount() {
        if (!this.matchedAmount) return '\u2014';
        const units = parseInt(this.numberOfUnits, 10);
        const total = (units > 0) ? units * this.matchedAmount : this.matchedAmount;
        return 'AED ' + Number(total).toLocaleString('en-AE');
    }
    get amountSourceLabel() { return this.matchedAmount ? 'from EOI Range' : 'EOI_Amount_AED__c'; }
    get amountBoxClass()    { return this.matchedAmount ? 'amount-box filled' : 'amount-box'; }
    get oppStatusClass()    { return this.isDuplicate ? 'opp-status-bar error' : 'opp-status-bar ok'; }

    get progressBarStyle() {
        const pct   = this.quotaLimit > 0 ? Math.min((this.quotaUsed / this.quotaLimit) * 100, 100) : 0;
        const color = this.quotaRemaining < 50 ? '#c0392b' : '#0a0a0a';
        return 'width:' + pct + '%; background:' + color;
    }
    get quotaNumClass()   { return this.quotaRemaining < 50 ? 'quota-num warn' : 'quota-num'; }
    get quotaBadgeClass() { return 'quota-badge'; }
    get selectedProject() { return this.selectedProjectName; }

    _err(e) { return (e && e.body && e.body.message) ? e.body.message : (e.message || 'Unknown error'); }
}