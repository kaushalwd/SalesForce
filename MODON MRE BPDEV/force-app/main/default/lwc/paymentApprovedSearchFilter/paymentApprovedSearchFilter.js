import { LightningElement, track } from 'lwc';

export default class PaymentApprovedSearchFilter extends LightningElement {

  //@track receiptNo = '';
  @track customerName = '';
  @track unit = '';
  @track receiptNo = '';
  @track receiptAmt = '';
  @track maturityDate = '';
  @track chequeTransNo = '';


  /*handleReceiptNoChange(event) {
    this.receiptNo = event.target.value;
    this.dispatchSearchChange();
  }*/

  handleCustomerNameChange(event) {
    this.customerName = event.target.value;
    this.dispatchSearchChange();
  }

  handleUnitChange(event) {
    this.unit = event.target.value;
    this.dispatchSearchChange();
  }

  // additional search
  handleReceiptNoChange(event) {
    this.receiptNo = event.target.value;
    this.dispatchSearchChange();
  }
  
  handleReceiptAmtChange(event) {
    this.receiptAmt = event.target.value;
    this.dispatchSearchChange();
  }

  handleMaturityDateChange(event) {
    this.maturityDate = event.target.value;
    this.dispatchSearchChange();
  }
  
  handleChequeTransNoChange(event) {
    this.chequeTransNo = event.target.value;
    this.dispatchSearchChange();
  }  


  /*dispatchSearchChange() {
    this.dispatchEvent(new CustomEvent('searchchange', {
      detail: {
        receiptNo: this.receiptNo.trim(),
        customerName: this.customerName.trim(),
        unit: this.unit.trim()
      }
    }));
  }*/  

  dispatchSearchChange() {
    this.dispatchEvent(new CustomEvent('searchchange', {
      detail: {
        customerName: this.customerName.trim(),
        unit: this.unit.trim(),
        receiptNo: this.receiptNo.trim(),
        receiptAmt: this.receiptAmt.trim(),
        maturityDate: this.maturityDate.trim(),
        chequeTransNo: this.chequeTransNo.trim()
      }
    }));
  }    
}