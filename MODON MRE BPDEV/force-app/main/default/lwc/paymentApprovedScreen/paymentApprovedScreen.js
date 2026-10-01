/**
 * description       : 
 * author            : Kumaravel Mathivanan
 * group             : 
 * Created modified on  : 10-20-2025 * 
 * * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Kumaravel Mathivanan        10-02-2025     Initial Draft 
* 2.0 			Manoj						12-16-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name)
**/
import { LightningElement, track } from 'lwc';
import getReceipts from '@salesforce/apex/paymentApprovedController.getReceipts';

export default class PaymentApprovedScreen extends LightningElement {
    @track filteredReceipts = [];
    @track allReceipts = [];
    @track searchCustomerName = '';
    @track searchUnit = '';

    @track searchreceiptNo = '';
    @track searchreceiptAmt = '';
    @track searchmaturityDate = '';
    @track searchchequeTransNo = '';

    @track selectedPdfId;
    @track showPdfModal = false;

    @track projectId;
    @track phaseId;
    @track startDate;
    @track endDate;
    @track startDateTrans;
    @track endDateTrans;    
    @track receiptName; //2.0 Add the ReceiptNmae


    async handleFilterChange(event) { //2.0 Add the ReceiptNmae
        const { projectId, phaseId,startDate,endDate,startDateTrans,endDateTrans,receiptName  } = event.detail;
        try {
            this.projectId = projectId;
            this.phaseId = phaseId;
            this.startDate = startDate;
            this.endDate = endDate;
            this.startDateTrans = startDateTrans;
            this.endDateTrans = endDateTrans;
            this.receiptName = receiptName; //2.0 Add the ReceiptNmae
            //2.0 Add the ReceiptNmae
            const result = await getReceipts({ projectId, phaseId, startDate, endDate, startDateTrans, endDateTrans,receiptName});
            this.allReceipts = result;
            this.applyFilters();
        } catch (error) {
            console.error('Error fetching receipts:', error);
        }        
    }

    handleSearchChange(event) {
        this.searchCustomerName = event.detail.customerName?.toLowerCase() || '';
        this.searchUnit = event.detail.unit?.toLowerCase() || '';
        this.searchreceiptNo = event.detail.receiptNo?.toLowerCase() || '';
        this.searchreceiptAmt = event.detail.receiptAmt?.toString() || '';
        this.searchmaturityDate = event.detail.maturityDate?.toString() || '';
        this.searchchequeTransNo = event.detail.chequeTransNo?.toLowerCase() || '';	        
        this.applyFilters(); 
    }
    
    applyFilters() {
        this.filteredReceipts = this.allReceipts
        .map(receipt => ({
        ...receipt,
        receiptLink: `/lightning/r/Receipt__c/${receipt.Id}/view`
    }))
        .filter(receipt => {
            
            const customerMatch = !this.searchCustomerName || receipt.CustName?.toLowerCase().includes(this.searchCustomerName);
            const unitMatch = !this.searchUnit || receipt.Unit?.toLowerCase().includes(this.searchUnit);
            const receiptNoMatch = !this.searchreceiptNo || receipt.RecptNo?.toLowerCase().includes(this.searchreceiptNo);
            const receiptAmtMatch = !this.searchreceiptAmt || receipt.RecptAmount?.toString().includes(this.searchreceiptAmt);
            const maturityDateMatch = !this.searchmaturityDate || receipt.ChequeDate?.toString().includes(this.searchmaturityDate);
            //const maturityDateMatch = receipt.ChequeDate? receipt.ChequeDate.toString().toLowerCase().includes(this.searchmaturityDate.toLowerCase()) : false;            
            const chequeTransNoMatch = !this.searchchequeTransNo || receipt.ChequeNo?.toLowerCase().includes(this.searchchequeTransNo);

            return customerMatch && unitMatch && receiptNoMatch && receiptAmtMatch && maturityDateMatch && chequeTransNoMatch;
        });
    }

    handleRefreshData() {
            getReceipts({ projectId:this.projectId, phaseId:this.phaseId, startDate:this.startDate, endDate:this.endDate, startDateTrans:this.startDateTrans, endDateTrans:this.endDateTrans })
            .then(result => {
                this.allReceipts = result;
                this.applyFilters();
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.allReceipts = [];
            });
            
    }    

    /*handleViewPdf(event) {
        this.selectedPdfId = event.detail.fileId;
        this.showPdfModal = true;
    }*/

    handleModalClose() {
        this.selectedPdfId = null;
        this.showPdfModal = false;
    } 
    
    handleSelectedRows(event) {
        const selectedRows = event.detail.selectedRows;

        // Optional: store or use these as needed
        this.selectedReceipts = selectedRows;
    }
    

}