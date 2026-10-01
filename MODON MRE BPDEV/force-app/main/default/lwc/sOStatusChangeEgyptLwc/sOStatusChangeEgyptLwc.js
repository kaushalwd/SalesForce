import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentSalesOrderStatus from '@salesforce/apex/SOStatusChangeController.getCurrentSalesOrderStatus';
import checkReservationFormGenerated from '@salesforce/apex/SOStatusChangeController.checkReservationFormGenerated';
import checkDownPaymentCollected from '@salesforce/apex/SOStatusChangeController.checkDownPaymentCollected';
import checkReservationFormSigned from '@salesforce/apex/SOStatusChangeController.checkReservationFormSigned';
import checkInstallementPaymentCollectedEgypt from '@salesforce/apex/SOStatusChangeController.checkInstallementPaymentCollectedEgypt';
import checkSPAGenerated from '@salesforce/apex/SOStatusChangeController.checkSPAGenerated';
import checkSignedSPACustomer from '@salesforce/apex/SOStatusChangeController.checkSignedSPACustomer';
import checkSignedSPAModon from '@salesforce/apex/SOStatusChangeController.checkSignedSPAModon';
import checkDpPaymentConfirmed from '@salesforce/apex/SOStatusChangeController.checkDpPaymentConfirmed';

export default class SOStatusChangeEgyptLwc extends NavigationMixin(LightningElement) {
    @api recordId;
    @track respWrap={};
    currentSalesOrderStatus;
    nextSalesOrderStatus;

    connectedCallback(){
        if(this.recordId == undefined || this.recordId == null || this.recordId == ''){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        }
        this.getCurrentSalesOrderStatusCallout();
    }

    getCurrentSalesOrderStatusCallout(){
    
        getCurrentSalesOrderStatus({salesOrderId:this.recordId}).then(result => {
    
            this.currentSalesOrderStatus = result;

            if(this.currentSalesOrderStatus == 'New' || this.currentSalesOrderStatus == 'In Progress' || this.currentSalesOrderStatus == 'Blocking Fees Collected'){
                this.nextSalesOrderStatus = 'Please upload the document under Reservation form generated';
                this.checkReservationFormGeneratedCallout();
            }

            if(this.currentSalesOrderStatus == 'Reservation form generated'){
                this.nextSalesOrderStatus = 'Please ensure to collect the complete payment under Milestone Number 1';
                this.checkDownPaymentCollectedCallout();
            }

            if(this.currentSalesOrderStatus == 'Down payment collected'){
                this.nextSalesOrderStatus = 'Please upload the document under Reservation form signed';
                this.checkReservationFormSignedCallout();
            }

            if(this.currentSalesOrderStatus == 'Reservation form signed'){
                this.nextSalesOrderStatus = 'Please create payments under Installment Payment Collected';
                this.checkInstallementPaymentCollectedEgyptCallout();
            }

            if(this.currentSalesOrderStatus == 'Installment Payment Collected'){
                this.nextSalesOrderStatus = 'Please create payments under DP Payment Confirmed';
                this.checkDpPaymentConfirmedCallout();
            }

            if(this.currentSalesOrderStatus == 'DP Payment Confirmed'){
                this.nextSalesOrderStatus = 'Please upload the document under SPA';
                this.checkSPAGeneratedCallout();
            }

            //new added
            if(this.currentSalesOrderStatus == 'Downpayment Payments Cleared'){
                this.nextSalesOrderStatus = 'Please upload the document under SPA';
                this.checkSPAGeneratedCallout();
            }

            if(this.currentSalesOrderStatus == 'SPA Generated'){
                this.nextSalesOrderStatus = 'Please upload the document under SPA Signed (Customer)';
                this.checkSignedSPACustomerCallout();
            }

            if(this.currentSalesOrderStatus == 'SPA Signed (Customer)'){
                this.nextSalesOrderStatus = 'Please upload the document under SPA Signed (Modon)';
                this.checkSignedSPAModonCallout();
            }

            if(this.currentSalesOrderStatus == 'SPA Signed (Modon)'){
                // this.checkSignedSPAModonCallout();
                this.nextSalesOrderStatus = 'Please create payments under Installment Payment Collected';
                this.checkInstallementPaymentCollectedEgyptCallout();
            }
    
        }).catch(error => {
        });
    }

    checkReservationFormGeneratedCallout(){
    
        checkReservationFormGenerated({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkDownPaymentCollectedCallout(){
    
        checkDownPaymentCollected({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkReservationFormSignedCallout(){
    
        checkReservationFormSigned({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkInstallementPaymentCollectedEgyptCallout(){
    
        checkInstallementPaymentCollectedEgypt({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkDpPaymentConfirmedCallout(){
    
        checkDpPaymentConfirmed({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkSPAGeneratedCallout(){
    
        checkSPAGenerated({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            } else if (result == 'Failed Egypt') {
                //Overwrite error message for Modon Egypt
                this.nextSalesOrderStatus = 'Please upload/generate the document under any of these documents: \'Egyptian Company SPA\', \'Egyptian Natural Person Abroad SPA\', \'Foreign Company SPA\', \'Foreign Individual SPA\', \'Egyptian Natural Person in Egypt SPA\'';
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkSignedSPACustomerCallout(){
    
        checkSignedSPACustomer({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    checkSignedSPAModonCallout(){
    
        checkSignedSPAModon({salesOrderId:this.recordId}).then(result => {
    
            if(result == 'Success'){
                this.showSuccessToast();
                setTimeout(function() {
                    window.location.reload();
                }, 1000);
            } else if(result == 'Failed'){
                this.showErrorToast();
            }
    
        }).catch(error => {
        });
    }

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Sales Order status updated successfully.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    showErrorToast() {
        const event = new ShowToastEvent({
            title: 'Error',
            message: this.nextSalesOrderStatus,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    navigateToRecordPage(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}