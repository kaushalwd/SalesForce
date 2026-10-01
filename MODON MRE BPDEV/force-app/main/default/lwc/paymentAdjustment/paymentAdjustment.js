import { LightningElement,track,api, wire} from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRelatedSOInstallments from '@salesforce/apex/PaymentAdjustmentController.getRelatedSOInstallments';
import getSOInstallmentsDetails from '@salesforce/apex/PaymentAdjustmentController.getSOInstallmentsDetails';
import getRelatedSalesOrder from '@salesforce/apex/PaymentAdjustmentController.getRelatedSalesOrder';
import createPayment from '@salesforce/apex/PaymentAdjustmentController.createPayment';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class SalesDocumentUploadLwc extends NavigationMixin(LightningElement) {
    @wire(CurrentPageReference) pageRef;
    @track lstOfSOInstallments=[];
    @track outstandingAmountToApply=0;
    @track actualoutstandingAmountToApply=0;
    @api recordId;
    @track updatedInstallments=[];
    isSpinner=true;
    @track options = [];
    @track selectedValue = '';
    @track isRendered = false;
    @track excessAmount = false;
    connectedCallback(){

    }
    renderedCallback() {
        if(!this.isRendered){
        const urlSearchParams = new URLSearchParams(window.location.search);
        this.recordId = urlSearchParams.get('recordId');
        if (this.recordId ) {
            this.isRendered = true;
            this.handleRecordIdAvailable();
        }
    }
    }
    disconnectedCallback() {
    }
    handleRecordIdAvailable(){
        this.isSpinner = true;  
        getRelatedSalesOrder({ recordId: this.recordId})    
        .then(result => {
            if (Array.isArray(result) && result.length > 0) {                
                this.options = result;
                this.options = Array.from(
                    new Map(result.map(item => [item.value, item])).values()
                );
                this.selectedValue = this.options[0].value;
                this.isSpinner = false;     
                this.error = undefined;
            }
        })                  
        .catch(error => {
            this.isSpinner = false;
            console.error('Error:', error);
            this.error = result.error;
            this.showToastMessage('error', JSON.stringify(this.error),'Error');
        });
    }
    
    handleCloseUploadSection(event){
        this.lstOfSOInstallments=[];
        this.isSpinner = false;
    }

    get buttonDisabled(){
        /*if(this.outstandingAmountToApply < 0){
           return false;
        } else {
            return true;
        }*/
    }
    
    wiredResults;
    @wire(getRelatedSOInstallments, { recordId: '$recordId' })
    wiredDocuments(result) {
        this.isSpinner = false;
        this.wiredResults = result;
        const {data, error} = result;
        
        if (result.data) {
            this.lstOfSOInstallments = result.data.soInstallments;
            this.outstandingAmountToApply = result.data.balanceAmountonPayment;
            this.actualoutstandingAmountToApply = result.data.balanceAmountonPayment;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.showToastMessage('error', 'Error', JSON.stringify(this.error));
        }
    }
    handleUnitChange(event) {
        this.isSpinner = true;
        this.selectedValue = event.detail.value;
        
        if(this.selectedValue != ''){
            this.isSpinner = false;           
            this.getPaymentDetails(this.selectedValue);
        }else{
            this.isSpinner = false;
            this.showToastMessage('Error', 'Please select a Sales Order to adjust payment.', 'error');
        }
    }
    /*getPaymentDetails(soId){
        this.isSpinner = true;
       //  if soId is actually a click event, ignore it
    if (soId && soId.target) {
        soId = null;
    }

    if (!soId) {
        soId = null;
    }
        getSOInstallmentsDetails({ recordId: this.recordId,SOId:soId})
            .then(result => {
            this.lstOfSOInstallments = result.soInstallments;
            this.outstandingAmountToApply = result.balanceAmountonPayment;
            //this.refreshApex(this.wiredResults);
            this.error = undefined;  
            this.isSpinner = false;
            })
            .catch(error => {
            this.isSpinner = false;
            console.error('Error:', error);
            this.error = result.error;
            this.showToastMessage('error', JSON.stringify(this.error),'Error');
            });
    }*/

    getPaymentDetails(soId) {
        this.isSpinner = true;
    
        // Case 1: Button click passed the event, not SO Id
        if (soId && soId.target) {
            soId = null;
        }
    
        // Case 2: If no soId, refresh all options and pick the first one
        if (!soId) {
            getRelatedSalesOrder({ recordId: this.recordId })    
            .then(result => {
                if (Array.isArray(result) && result.length > 0) {                
                    this.options = Array.from(
                        new Map(result.map(item => [item.value, item])).values()
                    );
                    this.selectedValue = this.options[0].value;
    
                    return getSOInstallmentsDetails({ recordId: this.recordId, SOId: this.selectedValue });
                } else {
                    this.isSpinner = false;
                    this.showToastMessage('Error', 'No Sales Orders found.', 'error');
                    return null;
                }
            })
            .then(result => {
                if (result) {
                    this.lstOfSOInstallments = result.soInstallments;
                    this.outstandingAmountToApply = result.balanceAmountonPayment;
                    this.actualoutstandingAmountToApply = result.balanceAmountonPayment;
                    this.error = undefined;  
                }
                this.isSpinner = false;
            })
            .catch(error => {
                this.isSpinner = false;
                console.error('Error in getPaymentDetails:', error);
                this.showToastMessage('error', 'Error', JSON.stringify(error));
            });
        } else {
            // Case 3: soId passed manually (e.g., from dropdown change)
            getSOInstallmentsDetails({ recordId: this.recordId, SOId: soId })
                .then(result => {
                    this.lstOfSOInstallments = result.soInstallments;
                    this.outstandingAmountToApply = result.balanceAmountonPayment;
                    this.actualoutstandingAmountToApply = result.balanceAmountonPayment;
                    this.error = undefined;  
                    this.isSpinner = false;
                })
                .catch(error => {
                    this.isSpinner = false;
                    console.error('Error:', error);
                    this.showToastMessage('error', 'Error', JSON.stringify(error));
                });
        }
    
    }
            

    applyBalanceAmount(event){
        this.isSpinner = true;
            
        let soInstallmentId = event.target.getAttribute("data-row");
        // Find the related installment from the list
const selectedInstallment = this.lstOfSOInstallments.find(
    installment => installment.SOInstallmentId == soInstallmentId
);
let adjustmentAmount = 0;
if (selectedInstallment) {
 adjustmentAmount = selectedInstallment.adjustmentAmount;
}
        try{
           
        // Now you can use adjustmentAmount however you want
        // like calling an Apex method to create payment or whatever
     //  dataJSON : JSON.stringify(this.lstOfSOInstallments),
     // remainingAmount: this.outstandingAmountToApply
            createPayment({ recordId: this.recordId,
                            SOInstallmentId: soInstallmentId,
                            adjustmentAmount: adjustmentAmount
                          
                         })
            .then(result => {
                this.isSpinner = false;
                this.lstOfSOInstallments = result.soInstallments;
                this.outstandingAmountToApply = result.balanceAmountonPayment;
                this.error = undefined;  
                //refreshApex(this.wiredDocuments);
                this.showToastMessage('Success', 'Payment created successfully.', 'success');
                /*setTimeout(() => {
                    window.location.reload();
                }, 2300); 
                this.dispatchEvent(new CloseActionScreenEvent()); */                           
            })
            .catch(error => {
                this.isSpinner = false;
                console.error('Error:', error);
                this.error = result.error;
                this.showToastMessage('error', JSON.stringify(this.error),'Error');
            });
        }catch(e){
            this.isSpinner = false;
        }   
    }
    handleFocusOut(event) {
       /*  
        if(event.target.name == 'adjustedAmount' && event.detail.value != '' && event.detail.value != null && event.detail.value != undefined){
            //this.outstandingAmountToApply -= event.detail.value;
        } */
    } 
    handleChange(event) {
        this.excessAmount = false;
        this.isSpinner = true; 
        this.selectedValue = event.detail.value;
        if(this.selectedValue != '' || event.target.label == 'adjustedAmount'){
            this.isSpinner = false; 
          if(event.target.label == 'adjustedAmount'){  
            const index = event.target.name;
            let newValue = parseFloat(0);
        if(event.detail.value != '' && event.detail.value != null && event.detail.value != undefined){
            newValue = parseFloat(event.target.value);
        }else{
            newValue = parseFloat(0);
        }
      /*      let appliedAmountOverAll = 0;
        this.lstOfSOInstallments = this.lstOfSOInstallments.map(installment => {
            appliedAmountOverAll += installment.adjustmentAmount;
            if (installment.SOInstallmentId === index) {
                return {
                    ...installment,
                    adjustmentAmount: newValue,
                    adjustPayment: !(newValue > 0) // disable = true when 0, enable when >0
                };
            }
            return installment;
        });
        this.outstandingAmountToApply = this.outstandingAmountToApply - appliedAmountOverAll;
   */       let freezeAmount = 0;
   const installmentId = event.target.name;
   const newAmount = event.target.value ? parseFloat(event.target.value) : 0;
   let tempOutstanding = this.outstandingAmountToApply; // This is negative, e.g., -3778
   
   this.lstOfSOInstallments = this.lstOfSOInstallments.map(installment => {
       let updatedInstallment = { ...installment };
   
       if (updatedInstallment.SOInstallmentId === installmentId) {
           const previousAmount = updatedInstallment.adjustmentAmount != null && updatedInstallment.adjustmentAmount !== 'undefined'
               ? parseFloat(updatedInstallment.adjustmentAmount)
               : 0;
   
           const difference = newAmount - previousAmount; // simple difference
   
           tempOutstanding -= difference; // Add difference because outstanding is negative
   
   
           if (tempOutstanding < 0) { // Outstanding should not become positive
               this.excessAmount = true;
               this.showToastMessage('Error', 'Amount Over Apply than the outstanding amount!', 'error');
               updatedInstallment.adjustmentAmount = previousAmount; // reset to previous value
               updatedInstallment.adjustPayment = true;
               return updatedInstallment;
           }
   
           this.outstandingAmountToApply = tempOutstanding;
   
   
           updatedInstallment.adjustmentAmount = newAmount;
           updatedInstallment.adjustPayment = (newAmount < 0);
       }
       return updatedInstallment;
   });
   
        }
        
        }else{
            this.isSpinner = false;
            this.showToastMessage('Error', 'Please select a Sales Order to adjust payment.', 'error');
        }
    }
    showToastMessage(title,message,variant){
        const evt = new ShowToastEvent({
            title:title,
            message:message,
            variant:variant,
            mode:'dismissal'
        });
        this.dispatchEvent(evt);
    }   
    closeModel() {  
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}