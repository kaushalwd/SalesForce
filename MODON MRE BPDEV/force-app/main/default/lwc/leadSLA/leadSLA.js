import { LightningElement, api, wire, track } from 'lwc';
import getActiveTask from '@salesforce/apex/LeadSLAController.getActiveTask';
import { getRecord } from 'lightning/uiRecordApi';

export default class LeadSLA extends LightningElement {
    @api recordId; // Lead Id
    @track remainingTime;
    @track isOverdue = false;
    intervalId;

    targetDateTime;

    @wire(getActiveTask, { leadId: '$recordId' })
    wiredTask({ error, data }) {
        if (data) {
            this.targetDateTime = data.CurrentTaskSLA__c;
            this.startCountdown();
        } else if (error) {
            console.error('Error:', error);
        }
    }

    startCountdown() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }

        this.intervalId = setInterval(() => {
            const now = new Date();
            const target = new Date(this.targetDateTime);

            const diffMs = target - now;

            if (diffMs <= 0) {
                this.remainingTime = '00:00:00';
                this.isOverdue = true;
                clearInterval(this.intervalId);
            } else {
                const hours = String(Math.floor(diffMs / (1000 * 60 * 60))).padStart(2, '0');
                const minutes = String(Math.floor((diffMs / (1000 * 60)) % 60)).padStart(2, '0');
                const seconds = String(Math.floor((diffMs / 1000) % 60)).padStart(2, '0');
                this.remainingTime = `${hours}:${minutes}:${seconds}`;
            }
        }, 1000);
    }
}