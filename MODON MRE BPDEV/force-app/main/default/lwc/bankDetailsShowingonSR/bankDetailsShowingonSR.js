import { LightningElement, api, wire } from 'lwc';
import getBankDetails from '@salesforce/apex/ServiceRequestChecker.getBankDetails';

export default class BankDetailsCheck extends LightningElement {

    @api recordId;

    hasData = false;
    isLoaded = false;
    error;

    salesOrderId;
    salesOrderName;

    bankName;
    branchName;
    branchType;
    bankStatus;
    bankCountry;
    beneficiaryName;
    accountNumber;
    ibanNumber;
    ibanCountryCode;
    swiftCode;

    get soUrl() {
        return this.salesOrderId ? '/' + this.salesOrderId : '';
    }

    // GREEN if data exists, RED if not
    get containerClass() {
        return this.hasData
            ? 'slds-box slds-m-around_medium success-box'
            : 'slds-box slds-m-around_medium error-box';
    }

    @wire(getBankDetails, { serviceRequestId: '$recordId' })
    wiredResult({ data, error }) {
        this.isLoaded = true;

        if (data) {
            this.hasData = data.hasData;

            this.salesOrderId = data.salesOrderId;
            this.salesOrderName = data.salesOrderName;

            this.bankName = data.bankName;
            this.branchName = data.branchName;
            this.branchType = data.branchType;
            this.bankStatus = data.bankStatus;
            this.bankCountry = data.bankCountry;

            this.beneficiaryName = data.beneficiaryName;
            this.accountNumber = data.accountNumber;
            this.ibanNumber = data.ibanNumber;
            this.ibanCountryCode = data.ibanCountryCode;
            this.swiftCode = data.swiftCode;

            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }
}