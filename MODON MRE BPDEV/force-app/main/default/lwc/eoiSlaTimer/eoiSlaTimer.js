import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue }           from 'lightning/uiRecordApi';

// ── Moved to PaymentReceiptController ─────────────────────────────────────────
import getSLAConfig    from '@salesforce/apex/PaymentReceiptController.getSLAConfig';
import checkHasPayment from '@salesforce/apex/PaymentReceiptController.checkHasPayment';

import SLA_START       from '@salesforce/schema/Expressionofinterest__c.SLA_Start_Time__c';
import SKIP_SLA        from '@salesforce/schema/Expressionofinterest__c.Skip_SLA__c';
import STATUS          from '@salesforce/schema/Expressionofinterest__c.Status__c';
import VOID_REASON     from '@salesforce/schema/Expressionofinterest__c.SLA_Voided_Reason__c';
import RESIDENT_STATUS from '@salesforce/schema/Expressionofinterest__c.UAE_Resident_Status__c';
import CREATED_DATE    from '@salesforce/schema/Expressionofinterest__c.CreatedDate';

import SLA_ENABLED_LABEL from '@salesforce/label/c.EOI_SLA_Enabled';



const EOI_FIELDS = [SLA_START, SKIP_SLA, STATUS, VOID_REASON, RESIDENT_STATUS, CREATED_DATE];


export default class EoiSlaTimer extends LightningElement {

    @api recordId;

    @track residentHours    = 24;
    @track nonResidentHours = 48;
    @track residentValue    = 'Resident';
    slaEnabledLabel         = SLA_ENABLED_LABEL;






    @track slaStartTime     = null;
    @track skipSla          = false;
    @track status           = '';
    @track voidedReason     = '';
    @track hasPayment       = false;
    @track residentStatus   = '';
    @track secondsRemaining = 0;
    @track _wiredLoaded     = false;
    @track _timerExpired    = false;

    _intervalId   = null;
    _configLoaded = false;

    connectedCallback() {
        this._loadSLAConfig();
    }

    disconnectedCallback() {
        this._clearTimer();
    }

    _loadSLAConfig() {
        getSLAConfig()
            .then(config => {
                this.residentHours    = config.residentHours    || 24;
                this.nonResidentHours = config.nonResidentHours || 48;
                this.residentValue    = config.residentValue    || 'Resident';
                this._configLoaded    = true;
                this._startTimer();
            })
            .catch(err => {
                console.error('getSLAConfig error', err);
                this._configLoaded = true;
                this._startTimer();
            });
    }

    @wire(getRecord, { recordId: '$recordId', fields: EOI_FIELDS })
    wiredEOI({ data, error }) {
        if (data) {
            this._wiredLoaded = true;
            const start   = getFieldValue(data, SLA_START);
            const created = getFieldValue(data, CREATED_DATE);
            this.slaStartTime   = start   ? new Date(start)
                                : created ? new Date(created)
                                : null;
            this.skipSla        = getFieldValue(data, SKIP_SLA)        || false;
            this.status         = getFieldValue(data, STATUS)          || '';
            this.voidedReason   = getFieldValue(data, VOID_REASON)     || '';
            this.residentStatus = getFieldValue(data, RESIDENT_STATUS) || '';
            this._loadPaymentStatus();
            if (this._configLoaded) this._startTimer();
        }
        if (error) {
            this._wiredLoaded = true;
            console.error('EOI SLA Timer wire error', error);
        }
    }

    _loadPaymentStatus() {
        if (!this.recordId) return;
        checkHasPayment({ eoiId: this.recordId })
            .then(result => {
                this.hasPayment = result;
                if (this.hasPayment) this._clearTimer();
            })
            .catch(err => console.error('checkHasPayment error', err));
    }


    get slaHours() {
        return this.residentStatus === this.residentValue
            ? this.residentHours
            : this.nonResidentHours;
    }


    get slaWindowLabel() {
        return this.residentStatus === this.residentValue
            ? this.residentHours    + 'h (Resident)'
            : this.nonResidentHours + 'h (Non-Resident)';
    }

    _startTimer() {
        this._clearTimer();
        if (!this.isActive) return;
        this._tick();
        this._intervalId = setInterval(() => { this._tick(); }, 1000);
    }

    _tick() {
        if (!this.slaStartTime) return;
        const deadlineMs      = this.slaStartTime.getTime() + (this.slaHours * 3600 * 1000);
        const remainingMs     = deadlineMs - Date.now();
        this.secondsRemaining = Math.max(0, Math.floor(remainingMs / 1000));
        if (this.secondsRemaining === 0) {
            this._timerExpired = true;
            this._clearTimer();
        }
    }

    _clearTimer() {
        if (this._intervalId) { clearInterval(this._intervalId); this._intervalId = null; }
    }

    get isLoading()     { return !this._wiredLoaded; }
    get isSlaDisabled() { return this.slaEnabledLabel !== 'true'; }
    get isSlaSkipped()  { return !this.isSlaDisabled && this.skipSla; }
    get isVoided()      { return !this.isSlaDisabled && !this.skipSla && this.status === 'Expired'; } // ← CHANGED: 'Voided' → 'Expired'
    get isMet()         { return !this.isSlaDisabled && !this.skipSla && !this.isVoided && this.hasPayment; }
    get isBreached()    { return !this.isSlaDisabled && !this.skipSla && !this.isVoided && !this.isMet && !!this.slaStartTime && this._timerExpired; }
    get isActive()      { return !this.isSlaDisabled && !this.skipSla && !this.isVoided && !this.isMet && !!this.slaStartTime && !this._timerExpired; }

    get hoursDisplay()   { return this._pad(Math.floor(this.secondsRemaining / 3600)); }
    get minutesDisplay() { return this._pad(Math.floor((this.secondsRemaining % 3600) / 60)); }
    get secondsDisplay() { return this._pad(this.secondsRemaining % 60); }
    _pad(n) { return String(n).padStart(2, '0'); }

    get _pctRemaining() {
        return this.slaHours > 0 ? (this.secondsRemaining / (this.slaHours * 3600)) * 100 : 0;
    }

    get urgencyLevel() {
        const p = this._pctRemaining;
        if (p > 33) return 'safe';
        if (p > 16) return 'warning';
        if (p > 4)  return 'danger';
        return 'critical';
    }

    get urgencyLabel() {
        return { safe:'On Track', warning:'Due Soon', danger:'Urgent', critical:'Critical' }[this.urgencyLevel];
    }








    get timerCardClass()     { return 'timer-card urgency-'  + this.urgencyLevel; }
    get timerIconWrapClass() { return 'sla-icon-wrap icon-'  + this.urgencyLevel; }
    get urgencyBadgeClass()  { return 'urgency-badge badge-' + this.urgencyLevel; }
    get digitClass()         { return 'digit digit-'         + this.urgencyLevel; }
    get separatorClass()     { return 'separator sep-'       + this.urgencyLevel; }
    get progressFillClass()  { return 'progress-fill fill-'  + this.urgencyLevel; }

    get progressBarStyle() {
        const totalSecs = this.slaHours * 3600;
        const elapsed   = totalSecs - this.secondsRemaining;
        const pct       = Math.min((elapsed / totalSecs) * 100, 100);
        return 'width:' + pct + '%';
    }

    get slaStartFormatted() {
        return this.slaStartTime ? this.slaStartTime.toLocaleString() : '\u2014';
    }

    get slaDeadlineFormatted() {
        if (!this.slaStartTime) return '\u2014';
        return new Date(this.slaStartTime.getTime() + this.slaHours * 3600 * 1000).toLocaleString();
    }
}