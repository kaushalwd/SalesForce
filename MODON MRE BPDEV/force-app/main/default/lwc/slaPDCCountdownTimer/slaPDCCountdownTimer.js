import { LightningElement, api, track } from 'lwc';
import getPDCSLAConfig from '@salesforce/apex/SalesOrderPDCSLAHelper.getPDCSLAConfig';
import updatePDCSLAExtensionFlag from '@salesforce/apex/SalesOrderPDCSLAHelper.updatePDCSLAExtensionFlag';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SlaPDCCountdownTimer extends LightningElement {
    @api recordId;
    @track timeDisplay;
    @api dueTime;

    @track countdown;
    @track formattedSlaStart;
    @track formattedSlaEnd;
    @track isIsPDCSLAExtensionRequired;
    
    slaStart;
    slaEnd;
    intervalId;
    isOverdue = false;
    @track countdown;
    @track timeStatus;
    @track timerClass;
    
    @track isModalOpen = false;
    comments = '';
    slaInterval;


disconnectedCallback() {
    clearInterval(this.slaInterval);
}

closeModal() {
        this.isModalOpen = false;
        this.comments = '';
}

submitRequest(){

    const textarea = this.template.querySelector('lightning-textarea');

    // Salesforce-native validation
    if (!textarea.checkValidity()) {
        textarea.reportValidity();
        return;
    }
     this.isModalOpen = false;
     updatePDCSLAExtensionFlag({ salesOrderId: this.recordId, comments: this.comments})
            .then(result => {
                this.isIsPDCSLAExtensionRequired = true;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'SLA Approval Request sent successfully',
                        variant: 'success'
                    })
                );
                 window.location.reload();
            })
            .catch(error => {
                console.error('Error:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || 'Something went wrong',
                        variant: 'error'
                    })
                );
            });
}

 handleCommentChange(event) {       
        this.comments = event.target.value;        
    }

handlePDCClick() {
    this.isModalOpen = true;        
}


startSlaTimer() {
    if (!this.slaStart || !this.slaEnd) {
        console.error('Missing SLA start or end times');
        return;
    }

    this.updateCountdown(this.slaStart, this.slaEnd);

    this.slaInterval = setInterval(() => {
        this.updateCountdown(this.slaStart, this.slaEnd);
    }, 1000);
}


updateCountdown(slaStart, slaEnd) {
    const now = new Date();
    let diff = slaEnd - now;
    
    if (diff < 0) {
        const formatted = `00:00:00`;
        this.countdown = formatted;
        this.isIsPDCSLAExtensionRequired = true;
    } else {
        const hours = Math.floor(diff / 1000 / 60 / 60);
        const minutes = Math.floor((diff / 1000 / 60) % 60);
        const seconds = Math.floor((diff / 1000) % 60);

        const formatted = `${this.pad(hours)}:${this.pad(minutes)}:${this.pad(seconds)}`;
        this.countdown = formatted;
    }    
}

pad(num) {
        return num.toString().padStart(2, '0');
}

getTimeDisplay(dueTime) {
    const now = new Date().getTime();
    const due = new Date(dueTime).getTime();

    // Difference in milliseconds
    const diff = due - now;

    const absDiff = Math.abs(diff);
    const seconds = Math.floor(absDiff / 1000) % 60;
    const minutes = Math.floor(absDiff / (1000 * 60)) % 60;
    const hours = Math.floor(absDiff / (1000 * 60 * 60)) % 24;
    const days = Math.floor(absDiff / (1000 * 60 * 60 * 24));

    const formatted = [
        days ? `${days}d` : '',
        hours ? `${hours}h` : '',
        minutes ? `${minutes}m` : '',
        seconds ? `${seconds}s` : ''
    ].filter(Boolean).join(' ');

    if (diff > 0) {
        return `${formatted}`;
    } else {
        return `00:00:00`;
    }
}
async connectedCallback() {
    await this.loadSLAConfig();
    this.startSlaTimer(); // ← use correct variable-based timer
}

updateTimer() {
    if (!this.dueTime) return;
    this.timeDisplay = this.getTimeDisplay(this.dueTime);
}

async loadSLAConfig() {
        try {
            const data = await getPDCSLAConfig({ salesOrderId: this.recordId });
            this.slaStart = data.SLA_Start ? new Date(data.SLA_Start) : null;
            this.slaEnd = data.SLA_End ? new Date(data.SLA_End) : null;
            this.formattedSlaStart = this.formatDate(this.slaStart);
            this.formattedSlaEnd = this.formatDate(this.slaEnd);
            this.isIsPDCSLAExtensionRequired = data.IsPDCSLAExtensionRequired;
        } catch (err) {
            console.error('Error fetching SLA config:', err);
        }
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

}