import { LightningElement, api, wire } from 'lwc';
import getCaseDetails from '@salesforce/apex/CaseSLAController.getCaseDetails';

export default class CaseSla extends LightningElement {
    @api recordId;

    caseData;
    remainingTime = 0;
    interval;
    slaProgress = 100;
    slaExpired = false;
    caseClosed = false;

    @wire(getCaseDetails, { caseId: '$recordId' })
    wiredCaseData({ error, data }) {

        if (data) {
            this.caseData = data;
            this.setupSla();
        }
        if (error) {
            console.error(error);
        }
    }

    setupSla() {
        if (!this.caseData) return;

        const sla = this.caseData;

        //if (['Resolved', 'Breached', 'Reassigned'].includes(sla.Status__c)) {
            if (sla.CaseId__r?.IsClosed) {
            this.caseClosed = true;
            this.remainingTime = 0;
            return;
        }

        this.startTimer(sla);
    }

    startTimer(sla) {
        this.calculateRemainingTime(sla);

        if (this.interval) clearInterval(this.interval);

        this.interval = setInterval(() => {
            this.calculateRemainingTime(sla);
        }, 1000);
    }

    calculateRemainingTime(sla) {
        const now = new Date();
        const start = new Date(sla.StartTime__c);
        const end = new Date(sla.DueTime__c);

        const total = end - start;
        const remaining = end - now;

        this.remainingTime = remaining > 0 ? remaining : 0;

        // PROGRESS (100 → 0)
        let pct = (remaining / total) * 100;
        this.slaProgress = pct > 0 ? pct : 0;

        // SLA expired
        if (remaining <= 0) {
            this.slaExpired = true;
            clearInterval(this.interval);
        }
    }

    // ---- FORMATTED FIELDS ----
    get formattedStartTime() {
        return this.caseData?.StartTime__c
            ? new Date(this.caseData.StartTime__c).toLocaleString()
            : "—";
    }

    get formattedDueTime() {
        return this.caseData?.DueTime__c
            ? new Date(this.caseData.DueTime__c).toLocaleString()
            : "—";
    }

    get formattedRespondBefore() {
        return this.caseData?.Response_SLA__c
            ? new Date(this.caseData.Response_SLA__c).toLocaleString()
            : "—";
    }

    // ---- TIMER FORMAT ----
    get formattedRemainingTime() {
        if (this.caseClosed) return "Case Closed";
        if (this.slaExpired) return "00:00:00";
        if (!this.remainingTime) return "Loading...";

        const totalSec = Math.floor(this.remainingTime / 1000);
        const h = String(Math.floor(totalSec / 3600)).padStart(2, '0');
        const m = String(Math.floor((totalSec % 3600) / 60)).padStart(2, '0');
        const s = String(totalSec % 60).padStart(2, '0');

        return `${h}:${m}:${s}`;
    }

    // ---- PROGRESS BAR COLOR RULES ----
    get progressColor() {
        if (this.slaProgress <= 10) return "red";
        if (this.slaProgress <= 40) return "orange";
        return "green";
    }

    get progressStyle() {
        return `
            width:${this.slaProgress}%;
            background:${this.progressColor};
        `;
    }
}