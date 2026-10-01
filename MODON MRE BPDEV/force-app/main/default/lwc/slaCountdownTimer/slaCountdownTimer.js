import { LightningElement, api, track } from 'lwc';
import getSLAConfig from '@salesforce/apex/SalesOrderSLAHelper.getSLAConfig';
import getBusinessTimeDiff from '@salesforce/apex/SalesOrderSLAHelper.getBusinessTimeDiff';

export default class SlaCountdownTimer extends LightningElement {
    /* SLA Completed/Cancelled/Voided Overdue
    Resident / Non Resident 5 Days
    list of comps */
    @api recordId;

    @track countdown;
    @track timeStatus;
    @track team;
    @track formattedSlaStart;
    @track formattedSlaEnd;

    slaStart;
    slaEnd;
    holidays = [];
    bhStart = 9;
    bhEnd = 21; 
    intervalId;
    isOverdue = false;

    get timerClass() {
        return this.isOverdue ? 'slds-text-color_error' : 'slds-text-color_success';
    }

    async connectedCallback() {
        await this.loadSLAConfig();
        this.startCountdown();
    }

    async loadSLAConfig() {
        try {
            const data = await getSLAConfig({ salesOrderId: this.recordId });
            this.team = data.Team;
            this.slaStart = data.SLA_Start ? new Date(data.SLA_Start) : null;
            this.slaEnd = data.SLA_End ? new Date(data.SLA_End) : null;
            this.holidays = data.Holidays || [];

            if (data.BusinessHours && data.BusinessHours.StartTime && data.BusinessHours.EndTime) {
                
                this.bhStart = data.BusinessHours.StartTime / (1000 * 60 * 60);
                this.bhEnd = data.BusinessHours.EndTime / (1000 * 60 * 60);
            }

            this.formattedSlaStart = this.formatDate(this.slaStart);
            this.formattedSlaEnd = this.formatDate(this.slaEnd);
        } catch (err) {
            console.error('Error fetching SLA config:', err);
        }
    }

    async connectedCallback() {
    await this.loadSLAConfig();
    await this.initializeCountdown();  
}

async initializeCountdown() {
    try {
        const diffMillis = await getBusinessTimeDiff({ salesOrderId: this.recordId });
        if (diffMillis === null) return;

        this.remainingMillis = Math.abs(diffMillis);
        this.isOverdue = diffMillis < 0;

        this.updateCountdownDisplay();
        this.intervalId = setInterval(() => this.tick(), 1000);
    } catch (error) {
        console.error('Error initializing countdown:', error);
    }
}

tick() {
    this.remainingMillis -= 1000;
    if (this.remainingMillis <= 0) {
        this.isOverdue = true;
    }
    this.updateCountdownDisplay();
}

updateCountdownDisplay() {
    const absDiff = Math.abs(this.remainingMillis);
    const h = Math.floor(absDiff / 3600000);
    const m = Math.floor((absDiff % 3600000) / 60000);
    const s = Math.floor((absDiff % 60000) / 1000);

    this.timeStatus = this.isOverdue ? 'Overdue' : this.isWorkingTime(new Date()) ? 'Left' : '(Off Hours)';
    this.countdown = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s
        .toString()
        .padStart(2, '0')}`;
}


    isWorkingTime(date) {
        const day = date.getDay();
        if (day === 0 || day === 6) return false;

        const localHours = date.getHours() + date.getMinutes() / 60;
        if (localHours < this.bhStart || localHours >= this.bhEnd) return false;

        const localDate = date.toISOString().split('T')[0];
        if (this.holidays.includes(localDate)) return false;

        return true;
    }

    formatDate(dateObj) {
        if (!dateObj) return '';
        return dateObj.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        });
    }

    disconnectedCallback() {
        if (this.intervalId) clearInterval(this.intervalId);
    }
}