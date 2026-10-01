import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent, refreshView } from 'lightning/actions';
import getSalesOrderAccDetails from '@salesforce/apex/CreateDirectDebitRequestController.getSalesOrderAccDetails';

export default class CreateDirectDebitRequest extends NavigationMixin(LightningElement) {
    @api recordId;  
    showLoading = false;
    isLoading = false;

    @track errorCustomerAccMessage = '';
    @track errorCustomerIBANMessage = '';
    @track isCustBankAccNameValid = true;
    @track isCustIBANValid = true;
    @track displayUI = false;
    @track customerIdType;
    @track customerInfo;
    submitFromObject;
    accountId = '';
    customerAccountName = '';
    @track customerIDNumber = '';
    customerIdType = '';
    customerIBANNumber = '';
    customerBankAccountType = null;
    customerBankName = '';
    salesOrderId = '';
    defaultPayerAccount = '';
    payerAccount;
    mapOfAccountDetailsByIDMap = [];
    customername = [];
    directdebitrequestId;
    customerMobile = '';
    
    connectedCallback() {
        let salesOrderIdURL = this.recordId && this.recordId != null ? this.recordId : new URL(window.location.href).searchParams.get("recordId");
        let dVal = {};
        if (salesOrderIdURL != null) {
            getSalesOrderAccDetails({ salesOrderId: salesOrderIdURL })
                .then(result => {
                    if(result && result.salesOrderRecord){
                        this.customerInfo = result.salesOrderRecord;
                        this.submitFromObject = 'SalesOrder';
                        let mapOfAccountDetailsByID = [];
                        let accountsWithRelationships = [];
                        this.customerIdType = result.salesOrderRecord.CustomerAccount__r.IsPersonAccount == true ? 'UAE Emirates Identity Card' : 'Trade Licence Number';
                        this.customerIDNumber = result.salesOrderRecord.CustomerAccount__r.EIDNumber__pc;
                        this.customerAccountName = result.salesOrderRecord.CustomerAccount__r.Name;
                        this.customerMobile = result.salesOrderRecord.CustomerAccount__r.PersonMobilePhone;
                        this.accountId = result.salesOrderRecord.CustomerAccount__c;
                        this.salesOrderId = result.salesOrderRecord.Id;
                        this.payerAccount = result.salesOrderRecord.CustomerAccount__c;
                        this.customername = [{ label: result.salesOrderRecord.CustomerAccount__r.Name, value: result.salesOrderRecord.CustomerAccount__c }];
                        this.defaultPayerAccount = result.salesOrderRecord.CustomerAccount__c;                        
                        this.customerBankAccountType = null;
                        this.customerIBANNumber = '';
                        this.mapOfAccountDetailsByIDMap = mapOfAccountDetailsByID;
                        this.displayUI = true;
                    } else {
                        this.handleCloseClick();
                        const evt = new ShowToastEvent({
                            title: 'Error',
                            message: 'Direct Debit Request is in progress',
                            variant: 'error',
                            mode: 'sticky'
                        });
                        this.dispatchEvent(evt);                        
                    }
                    
                }).catch(error => {
                    this.error = error;
                    const evt = new ShowToastEvent({
                        title: 'Error',
                        message: 'Error while fetching data ' + error,
                        variant: 'error',
                        mode: 'sticky'
                    });
                    this.dispatchEvent(evt);
                });
        }
    }

    handleCustomerIBANChange(event){
        const fieldValue = event.target.value;
        const regex = /^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/;
        
        if (!regex.test(fieldValue)) {
            this.errorCustomerIBANMessage = 'Customer IBAN must contain only numbers';
            this.isCustIBANValid = false;
        } else {
            this.errorCustomerIBANMessage = '';
            this.isCustIBANValid = true;
        }
    }

    handleCustomerAccChange(event){
        const fieldValue = event.target.value;
        const regex = /^[A-Za-z\s]{3,50}$/; // Allows only letters and spaces, min 3 max 50 chars
        
        if (!regex.test(fieldValue)) {
            this.errorCustomerAccMessage = 'Bank Account Name must contain only letters and spaces (3-50 characters).';
            this.isCustBankAccNameValid = false;
        } else {
            this.errorCustomerAccMessage = '';
            this.isCustBankAccNameValid = true;
        }
    }

    onCustIdTypeChange(event) {
        this.customerIdType = event.detail.value;
        this.customerIDNumber = '';
        if( this.customerInfo != null &&  this.customerInfo !='undefined'){
            if(this.customerIdType == 'UAE Emirates Identity Card'){
                if(this.customerInfo.CustomerAccount__r.EIDNumber__pc  != null && this.customerInfo.CustomerAccount__r.EIDNumber__pc  != 'undefined'){
                    this.customerIDNumber = this.customerInfo.CustomerAccount__r.EIDNumber__pc;
                }
               
            }else if(this.customerIdType == 'Trade Licence Number'){
                if(this.customerInfo.CustomerAccount__r.TradeLicenseNumber__c != null && this.customerInfo.CustomerAccount__r.TradeLicenseNumber__c != 'undefined'){
                 this.customerIDNumber = this.customerInfo.CustomerAccount__r.TradeLicenseNumber__c;
                }
            }
    }
    /*
        let mapOfAccountDetailsByIDMap = this.mapOfAccountDetailsByIDMap;
        for (let i in mapOfAccountDetailsByIDMap) {
            if (mapOfAccountDetailsByIDMap[i]['key'] == this.payerAccount) {
                if (this.customerIdType == 'Passport') {
                    this.customerIDNumber = (this.mapOfAccountDetailsByIDMap[i]['value'].PassportNumber__pc != null 
                                             && this.mapOfAccountDetailsByIDMap[i]['value'].PassportNumber__pc != '' 
                                             && this.mapOfAccountDetailsByIDMap[i]['value'].PassportNumber__pc != undefined) 
                                             ? this.mapOfAccountDetailsByIDMap[i]['value'].PassportNumber__pc : '';
                } 
            }
        } */
    }

    resetFormAction() {
        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );
        if (inputFields) {
            inputFields.forEach(element => {
                if (element.fieldName === "Customer_Bank_Account_Type__c" || element.fieldName === "Customer_Bank_Name__c" || element.fieldName === "Customer_IBAN_Number__c") {
                    element.reset();
                }
            });
        }
    }

    handlePayerAccountChange(event) {
        this.resetFormAction();
        let selectedPayerAccountId = event.detail.value;
        let mapOfAccountDetailsByIDMap = this.mapOfAccountDetailsByIDMap;
        let customerIDNumber = '';
        let customerAccountName = '';
        let customerIdType = '';
        this.customerIdType = null;
        this.customerBankAccountType = null;
        this.customerIBANNumber = null;
        this.payerAccount = selectedPayerAccountId;
        
        
        this.customerAccountName = customerAccountName;
        this.customerIdType = customerIdType;
    }

    get AccountList() {
        return this.customername;
    }

    @track customerBankNamePickListValues = [
        { label: 'Abu Dhabi Commercial Bank', value: 'Abu Dhabi Commercial Bank' },
        { label: 'Abu Dhabi Islamic Bank', value: 'Abu Dhabi Islamic Bank' },
        { label: 'Ajman Bank', value: 'Ajman Bank' },
        { label: 'Al Hilal Bank', value: 'Al Hilal Bank' },
        { label: 'Al Maryah Community Bank', value: 'Al Maryah Community Bank' },
        { label: 'Bank of Sharjah', value: 'Bank of Sharjah' },
        { label: 'Commercial Bank International', value: 'Commercial Bank International' },
        { label: 'Commercial Bank of Dubai', value: 'Commercial Bank of Dubai' },
        { label: 'Dubai Islamic Bank', value: 'Dubai Islamic Bank' },
        { label: 'Emirates Investment Bank', value: 'Emirates Investment Bank' },
        { label: 'Emirates Islamic', value: 'Emirates Islamic' },
        { label: 'Emirates NBD', value: 'Emirates NBD' },
        { label: 'First Abu Dhabi Bank', value: 'First Abu Dhabi Bank' },
        { label: 'Invest Bank', value: 'Invest Bank' },
        { label: 'Mashreq', value: 'Mashreq' },
        { label: 'National Bank of Fujairah', value: 'National Bank of Fujairah' },
        { label: 'National Bank of Ras Al-Khaimah PJSC (RAKBANK)', value: 'National Bank of Ras Al-Khaimah PJSC (RAKBANK)' },
        { label: 'National Bank of Umm Al-Qaiwain', value: 'National Bank of Umm Al-Qaiwain' },
        { label: 'Ruya Community Islamic Bank', value: 'Ruya Community Islamic Bank' },
        { label: 'Sharjah Islamic Bank', value: 'Sharjah Islamic Bank' },
        { label: 'United Arab Bank', value: 'United Arab Bank' },
        { label: 'Wio Bank', value: 'Wio Bank' },
        { label: 'Zand Bank', value: 'Zand Bank' },
        { label: 'National Bank of Bahrain', value: 'National Bank of Bahrain' },
        { label: 'Rafidain Bank', value: 'Rafidain Bank' },
        { label: 'Arab Bank', value: 'Arab Bank' },
        { label: 'Banque Misr', value: 'Banque Misr' },
        { label: 'El Nilein Bank', value: 'El Nilein Bank' },
        { label: 'National Bank of Oman', value: 'National Bank of Oman' },
        { label: 'Credit Agricole', value: 'Credit Agricole' },
        { label: 'Bank of Baroda', value: 'Bank of Baroda' },
        { label: 'BNP Paribas', value: 'BNP Paribas' },
        { label: 'Janata Bank Limited', value: 'Janata Bank Limited' },
        { label: 'HSBC Bank Middle East Limited', value: 'HSBC Bank Middle East Limited' },
        { label: 'Arab African International Bank', value: 'Arab African International Bank' },
        { label: 'Al Khaliji', value: 'Al Khaliji' },
        { label: 'Al Ahli Bank of Kuwait', value: 'Al Ahli Bank of Kuwait' },
        { label: 'Habib Bank Ltd.', value: 'Habib Bank Ltd.' },
        { label: 'Habib Bank A.G Zurich', value: 'Habib Bank A.G Zurich' },
        { label: 'Standard Chartered Bank', value: 'Standard Chartered Bank' },
        { label: 'Citibank N. A.', value: 'Citibank N. A.' },
        { label: 'Bank Saderat Iran', value: 'Bank Saderat Iran' },
        { label: 'Bank Melli Iran', value: 'Bank Melli Iran' },
        { label: 'Banque Banorient France', value: 'Banque Banorient France' },
        { label: 'NatWest Markets Plc', value: 'NatWest Markets Plc' },
        { label: 'United Bank Ltd.', value: 'United Bank Ltd.' },
        { label: 'Doha Bank', value: 'Doha Bank' },
        { label: 'Saudi National Bank', value: 'Saudi National Bank' },
        { label: 'National Bank of Kuwait', value: 'National Bank of Kuwait' },
        { label: 'BOK International Bank', value: 'BOK International Bank' },
        { label: 'American Express Bank', value: 'American Express Bank' },
        { label: 'Deutsche Bank AG', value: 'Deutsche Bank AG' },
        { label: 'KEB Hana Bank', value: 'KEB Hana Bank' },
        { label: 'Barclays Bank PLC', value: 'Barclays Bank PLC' },
        { label: 'Bank of China Limited', value: 'Bank of China Limited' },
        { label: 'Gulf International Bank', value: 'Gulf International Bank' },
        { label: 'MCB Bank Limited', value: 'MCB Bank Limited' },
        { label: 'Intesa Sanpaolo S.P.A', value: 'Intesa Sanpaolo S.P.A' },
        { label: 'Agricultural Bank of China Ltd.', value: 'Agricultural Bank of China Ltd.' },
        { label: 'Bank Alfalah Limited', value: 'Bank Alfalah Limited' }
    ];

    handleCustomerBankNameChange(event) {
        this.customerBankName = event.detail.value;
    }

    handleSuccess(event) {
        this.showLoading = false;
        let recordId = event.detail.id;
        this.handleNavigation(recordId);
    }

    handleNavigation(recordId) {
        this.showLoading = false;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'DirectDebitRequest__c',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'DirectDebitRequest__c',
                    actionName: 'home'
                }
            });
        }
    }

    handleError(event) {
       this.showLoading = false;
       const evt = new ShowToastEvent({
            title: 'Error',
            message: event.detail.detail,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(evt);
    }

    handleSubmit(event) {
        this.showLoading = true;
        if (!this.isCustBankAccNameValid || !this.isCustIBANValid) {
            event.preventDefault(); 
            this.showToast('Error', 'Please correct the errors before submitting.', 'error');
            this.showLoading = false;
        }
        if(this.customerIDNumber == null || this.customerIDNumber == '' || this.customerIDNumber == 'undefined'){
            event.preventDefault(); 
            this.showToast('Error', 'Please enter valid customer ID Number.', 'error');
            this.showLoading = false;
        }
        if(this.customerAccountName == null || this.customerAccountName == '' || this.customerAccountName == 'undefined'){
            event.preventDefault(); 
            this.showToast('Error', 'Please enter valid customer name.', 'error');
            this.showLoading = false;
        }
        if(this.customerBankName == null || this.customerBankName == '' || this.customerBankName == 'undefined'){
            event.preventDefault(); 
            this.showToast('Error', 'Please select valid customer bank name.', 'error');
            this.showLoading = false;
        }
    }

    handleCloseClick() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}