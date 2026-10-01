import { LightningElement, api, track } from 'lwc';
import getBookingSLAConfig from '@salesforce/apex/ModonPayOppHelper.getBookingSLAConfig';
import updateBookingSLA from '@salesforce/apex/ModonPayOppHelper.updateBookingSLA';
import userId from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, empApi } from 'lightning/empApi';

import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi'; 

export default class BookingFeeCountdownTimer extends LightningElement {
    @api recordId;
    @api dueTime;

    @track countdown;
    @track formattedSlaStart;
    @track formattedSlaEnd;
    @track bookingStatus;
    @track paymentStatusCheck = false;
    @track isLoading = false;

    @track admDariTotalAmount = 0;
    @track admDariPaidAmount = 0;
    @track admDariBalanceAmount = 0;
    @track admDariFeeStatus = '';

    @track downPaymentTotalAmount = 0;
    @track downPaymentPaidAmount = 0;
    @track downPaymentBalanceAmount = 0;
    @track downPaymentFeeStatus = '';

    currentUserId = userId;
    slaStart;
    slaEnd;
    isOverdue = false;
    @track timeStatus;
    @track timerClass;
    
    slaInterval;

    channelName = '/event/Modon_Pay_SLA_Event__e';
    subscription = {};

    disconnectedCallback() {
        this.clearActiveIntervals();
        this.handleEventStreamUnsubscription();
    }

    async connectedCallback() {
        this.handleEventStreamSubscription();
        this.checkForPendingTerminalLaunch();
        this.initSlaConfig(); 
    }

     async initSlaConfig() {
        await this.loadSLAConfig();
        this.startSlaTimer();
    }

    async loadSLAConfig() {
        try {
            const data = await getBookingSLAConfig({ oppId: this.recordId });
            this.slaStart = data.SLA_Start ? new Date(data.SLA_Start) : null;
            this.slaEnd = data.SLA_End ? new Date(data.SLA_End) : null;
            
            this.formattedSlaStart = this.formatDate(this.slaStart);
            this.formattedSlaEnd = this.formatDate(this.slaEnd);
            this.bookingStatus = data.Booking_Status;    
            this.paymentStatusCheck = data.PaymentStatusCheck; 
            
            this.admDariTotalAmount = data.ADMDariTotalAmount;
            this.admDariPaidAmount = data.ADMDariPaidAmount;
            this.admDariBalanceAmount = data.ADMDariBalanceAmount;
            this.admDariFeeStatus = data.ADMDariFeeStatus;

            this.downPaymentTotalAmount = data.DownPaymentTotalAmount;
            this.downPaymentPaidAmount = data.DownPaymentPaidAmount;
            this.downPaymentBalanceAmount = data.DownPaymentBalanceAmount;
            this.downPaymentFeeStatus = data.DownPaymentFeeStatus;

        } catch (err) {
            console.error('Error fetching SLA config:', err);
        }
    }

    startSlaTimer() {
        if (!this.slaStart || !this.slaEnd) {
            console.error('Missing SLA start or end times');
            return;
        }
        if(this.bookingStatus === 'Available'){
            return;
        }
        this.clearActiveIntervals(); 
        this.updateCountdown(this.slaStart, this.slaEnd);

        this.slaInterval = setInterval(() => {
            this.updateCountdown(this.slaStart, this.slaEnd);
        }, 1000);
    }

    updateCountdown(slaStart, slaEnd) {
        const now = new Date();
        let diff = slaEnd - now;
        
        if (diff < 0) {
            this.countdown = `00:00:00`;
            this.isOverdue = true;
            this.clearActiveIntervals();
        } else {
            const hours = Math.floor(diff / 1000 / 60 / 60);
            const minutes = Math.floor((diff / 1000 / 60) % 60);
            const seconds = Math.floor((diff / 1000) % 60);

            this.countdown = `${this.pad(hours)}:${this.pad(minutes)}:${this.pad(seconds)}`;
        }    
    }

    pad(num) {
        return num.toString().padStart(2, '0');
    }

    formatDate(dateObj) {
        if (!dateObj) return '';
        return dateObj.toLocaleString('en-US', {
            month: 'short', day: 'numeric', year: 'numeric',
            hour: 'numeric', minute: '2-digit', second: '2-digit',
            hour12: true
        });
    }

    async handleModonPay() {
        this.isLoading = true;
        
        const checkoutUrl = 'https://modon-pay-staging.modon-built-different.com/terminal?op='+this.recordId;

        try {
            const result = await updateBookingSLA({ oppId: this.recordId, currentUserId: this.currentUserId });
            
            if (result === 'Unavailable') {
                this.showToast('Notice', 'This Unit is currently unavailable for booking.', 'warning');
                return;                    
            } 

            if (result === 'UnitNotFound') {
                this.showToast('Notice', 'The unit has not been selected.', 'warning');
                return;
            }
            
            if (result !== 'Reserved' && result !== 'MatchUser') {
                this.showToast('Notice', `This Unit is currently unavailable for booking. Assigned to ${result}`, 'warning');
                return;
            }            

            if (result === 'MatchUser') {
                this.showToast('Success', 'Payment initiated. Click the MODON Pay tab to complete the payment.', 'success');
                window.open(checkoutUrl, '_blank');
                return;
            }    
            this.showToast('Success', 'Payment initiated. Click the MODON Pay tab to complete the payment.', 'success');

            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

            await this.loadSLAConfig();
            this.startSlaTimer();

            window.open(checkoutUrl, '_blank');

        } catch (error) {
            console.error('Error processing updateBookingSLA:', error);
            this.showToast('Error', error.body?.message || 'Something went wrong during reservation.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleEventStreamSubscription() {
        const messageCallback = async (response) => {
            
            const eventRecordId = response.data.payload.RecordId__c;
            if (eventRecordId === this.recordId) {
                this.processRealtimeSlaUpdate();
            }
        };

        subscribe(this.channelName, -1, messageCallback).then((res) => {
            this.subscription = res;
        }).catch((err) => {
            console.error('Streaming subscription context failure: ', err);
        });
    }

    async processRealtimeSlaUpdate() {
        
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        
        try {
            const data = await getBookingSLAConfig({ oppId: this.recordId });
            
            this.slaStart = data.SLA_Start ? new Date(data.SLA_Start) : null;
            this.slaEnd = data.SLA_End ? new Date(data.SLA_End) : null;
            
            this.formattedSlaStart = this.formatDate(this.slaStart);
            this.formattedSlaEnd = this.formatDate(this.slaEnd);
            this.bookingStatus = data.Booking_Status;    
            this.paymentStatusCheck = data.PaymentStatusCheck;  
            
            this.admDariTotalAmount = data.ADMDariTotalAmount;
            this.admDariPaidAmount = data.ADMDariPaidAmount;
            this.admDariBalanceAmount = data.ADMDariBalanceAmount;
            this.admDariFeeStatus = data.ADMDariFeeStatus;

            this.downPaymentTotalAmount = data.DownPaymentTotalAmount;
            this.downPaymentPaidAmount = data.DownPaymentPaidAmount;
            this.downPaymentBalanceAmount = data.DownPaymentBalanceAmount;
            this.downPaymentFeeStatus = data.DownPaymentFeeStatus;
        } catch (err) {
            console.error('>>>> Apex execution layer failure caught inside processing wrapper:', err);
        }
        
        this.startSlaTimer();
    }

    handleEventStreamUnsubscription() {
        if (this.subscription && Object.keys(this.subscription).length > 0) {
            unsubscribe(this.subscription, (res) => {
            });
        }
    }
    
    checkForPendingTerminalLaunch() {
        const pendingUrl = sessionStorage.getItem('pendingModonPayUrl');
        if (pendingUrl) {
            sessionStorage.removeItem('pendingModonPayUrl');
            window.open(pendingUrl, '_blank');
        }
    }

    clearActiveIntervals() {
        if (this.slaInterval) {
            clearInterval(this.slaInterval);
            this.slaInterval = null;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}