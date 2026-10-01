import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllAllocations from '@salesforce/apex/ManageReceiptAllocationController.getAllAllocations';
import unapplyAllocationRecord from '@salesforce/apex/ManageReceiptAllocationController.unapplyAllocationRecord';
import getAvailableReceiptsInvoices from '@salesforce/apex/ManageReceiptAllocationController.getAvailableReceiptsInvoices';
import saveAllocationRecord from '@salesforce/apex/ManageReceiptAllocationController.saveAllocationRecord';
export default class ManageReceiptAllocationLwC extends LightningElement {
    
    @api recordId;

    showLoading = false;
    initializeCalled = false;
    showReceiptAllocationSection = false;
    showAllocationButton = true;
    receiptOptions = {};
    invoiceOptions = {};

    allocationLst = [];
    availableReceiptInvoices = {};

    selectedReceiptRcrd = {};
    selectedInvoiceRcrd = {};
    selectedReceipt = '';
    selectedInvoice = '';

    get maxAllocationAmount(){
        if(this.selectedInvoiceRcrd.InvoiceBalance__c > this.selectedReceiptRcrd.RemainingAmount__c){
            this.amountToAllocate = this.selectedReceiptRcrd.RemainingAmount__c;
            return this.selectedReceiptRcrd.RemainingAmount__c;
        }
        this.amountToAllocate = this.selectedInvoiceRcrd.InvoiceBalance__c;
        return this.selectedInvoiceRcrd.InvoiceBalance__c;
    }

    get patterMismatchMsg(){
        if(this.selectedInvoiceRcrd.InvoiceBalance__c > this.selectedReceiptRcrd.RemainingAmount__c){
            return 'Allocation amount cannot be more than receipt amount';
        }

        return 'Allocation amount cannot be more than invoice amount';
    }

    connectedCallback(){
    }

    renderedCallback(){
        if(this.recordId !== undefined && !this.initializeCalled){
            this.initializeCalled = true;
            this.loadAccountAllocations();
        }
    }

    unapplyAllocation(event){
        this.showLoading = true;
        unapplyAllocationRecord({allId : event.currentTarget.dataset.allid})
        .then(resp =>{
            if(resp.isSuccess){
                this.loadAccountAllocations();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!', 
                        message: 'Allocation successfully removed.', 
                        variant: 'Success', 
                        mode: 'dismissable'
                    })
                );
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: resp.messageVariant, 
                        message: resp.errorMsg,
                        variant: resp.messageVariant, 
                        mode: 'dismissable'
                    })
                );
            }
        })
        .catch(error =>{
            console.error(error);
        })
        this.showLoading = false;
        
    }

    loadAccountAllocations(){
        this.showLoading = true;
        getAllAllocations({recordId : this.recordId})
        .then(resp => {
            if(resp.isSuccess){
                if(resp.allLst !== null){
                    this.showReceiptAllocationSection = true;
                    this.allocationLst = resp.allLst;
                }
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: resp.messageVariant, 
                        message: resp.errorMsg, 
                        variant: resp.messageVariant, 
                        mode: 'dismissable'
                    })
                );
            }
            this.showLoading = false;
        })
        .catch(error => {
            console.error('error==>', error);
        });
    }

    showAllocationForm(event){
        this.showLoading = true;
        getAvailableReceiptsInvoices({recordId : this.recordId})
        .then(resp => {
            this.availableReceiptInvoices = resp;

            if(resp.recLstMap.length > 0){
                this.receiptOptions = resp.recLstMap;
                this.selectedReceipt = resp.recLstMap[0].value;
                this.getReceiptDetails();
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error', 
                        message: 'No receipts are available for allocation.', 
                        variant: 'Error', 
                        mode: 'dismissable'
                    })
                );
                this.showLoading = false;
                return;
            }

            if(resp.invLstMap.length > 0){
                this.invoiceOptions = resp.invLstMap;
                this.selectedInvoice = resp.invLstMap[0].value;
                this.getInvoiceDetails();
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error', 
                        message: 'No invoices are available for allocation.', 
                        variant: 'Error', 
                        mode: 'dismissable'
                    })
                );
                this.showLoading = false;
                return;
            }

            this.showAllocationButton = false;
            this.showLoading = false;
        })
        .catch(error => {
            console.error('error==>', error);
        });
    }

    getReceiptDetails(){
        this.selectedReceiptRcrd = this.availableReceiptInvoices.receiptMap[this.selectedReceipt];
    }

    getInvoiceDetails(){
        this.selectedInvoiceRcrd = this.availableReceiptInvoices.invoiceMap[this.selectedInvoice];
    }

    updateAmountToAllocate(event){
        this.amountToAllocate = event.detail.value;
    }

    manageInvoiceChange(event){
        this.selectedInvoice = event.detail.value;
        this.getInvoiceDetails();
    }

    manageReceiptChange(event){
        this.selectedReceipt = event.detail.value;
        this.getReceiptDetails();
    }

    cancelAllocationForm(){
        this.showAllocationButton = true;
    }

    saveAllocationForm(){
        this.showLoading = true;
        saveAllocationRecord({invoiceId : this.selectedInvoiceRcrd.Id, receiptId : this.selectedReceiptRcrd.Id, allocateAmnt : this.amountToAllocate})
        .then(resp => {
            if(resp.isSuccess){
                this.loadAccountAllocations();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success', 
                        message: 'Allocation is successfully created.', 
                        variant: 'Success', 
                        mode: 'dismissable'
                    })
                );
                this.showAllocationButton = true;
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: resp.messageVariant, 
                        message: resp.errorMsg, 
                        variant: resp.messageVariant, 
                        mode: 'dismissable'
                    })
                );
            }
            this.showLoading = false;
        })
        .catch(error => {
            console.error('error==>', error);
        });
    }
}