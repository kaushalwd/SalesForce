import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import SALES_ORDER_FIELDS from '@salesforce/schema/SalesOrder__c.Status__c';
import SALES_ORDERCREATED from '@salesforce/schema/SalesOrder__c.CreatedDate';
import SALES_ORDER_ENDTIMER from '@salesforce/schema/SalesOrder__c.AutoEndDate__c';
import SALES_ORDER_AUTO from '@salesforce/schema/SalesOrder__c.AutoUpdateDate__c';

export default class Timer extends LightningElement {
    @api recordId;
    @track remainingTime = 0;
    @track formattedTime = '00:00:00';
    @track showTimer = true;
    timerInterval;
    status;
    EndTimer;
    startTime;
    autoUpdateTime;
    
    @wire(getRecord, { recordId: '$recordId', fields: [SALES_ORDER_FIELDS, SALES_ORDER_ENDTIMER, SALES_ORDERCREATED, SALES_ORDER_AUTO] })
    wiredSalesOrder({ error, data }) {
        if (data) {
            this.status = data.fields.Status__c.value;
            this.EndTimer = new Date(data.fields.AutoEndDate__c.value);
            this.startTime = new Date(data.fields.CreatedDate.value);
            this.autoUpdateTime = new Date(data.fields.AutoUpdateDate__c.value);
            this.startCountdown();
        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }

    startCountdown() {
        if (!this.EndTimer) {
            return;
        }
        
        this.updateRemainingTime();
        this.timerInterval = setInterval(() => {
            this.updateRemainingTime();
        }, 1000);
    }

    updateRemainingTime() {
        const now = new Date().getTime();
        const endTime = this.EndTimer.getTime();
        const startTime = this.startTime.getTime();
        const autoUpdateTime = this.autoUpdateTime ? this.autoUpdateTime.getTime() : null;

        if (autoUpdateTime && autoUpdateTime > startTime && autoUpdateTime < endTime) {
            const difference = autoUpdateTime - startTime;
            this.formattedTime = this.formatTime(difference);
            clearInterval(this.timerInterval);
            return;
        }

        const difference = endTime - now;
        if (difference <= 0) {
            clearInterval(this.timerInterval);
            this.formattedTime = '00:00:00';
            this.showTimer = false;
            return;
        }

        this.remainingTime = difference;
        this.formattedTime = this.formatTime(difference);
    }

    formatTime(ms) {
        let totalSeconds = Math.floor(ms / 1000);
        let hours = Math.floor(totalSeconds / 3600);
        let minutes = Math.floor((totalSeconds % 3600) / 60);
        let seconds = totalSeconds % 60;

        return `${this.padZero(hours)}:${this.padZero(minutes)}:${this.padZero(seconds)}`;
    }

    padZero(num) {
        return num < 10 ? '0' + num : num;
    }
}