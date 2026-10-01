/**
 * Component Name : MBP_manageagencyinformationform
 * Description    : Handles Agency Information
 * Author         : Upendra
 *
 * CHANGE HISTORY
 * ---------------------------------------------------------------------------
 * Version | Date & Time        | Author  | Description
 * ---------------------------------------------------------------------------
 * 1.0     | 2025-08-04 12:00   | Upendra | Initial creation.

 * 
 *  * 1.2      |2026-02-16 01:05|    |Upendra|   Included bank branch and branch type
 *  * 1.3      |2026-08-30      |    |Assistant| VAT Expiry Date field removed entirely — no longer captured or displayed
 * ---------------------------------------------------------------------------
  */

import { LightningElement, track, wire } from 'lwc';
import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';
import getSectionDocs from '@salesforce/apex/MBP_BrokerAgencyInformationController.getSectionDocs';
import submitSectionWithDocs from '@salesforce/apex/MBP_BrokerAgencyInformationController.submitSectionWithDocs';
import sendOtpToAgencyAdmin from '@salesforce/apex/MBP_BrokerAgencyInformationController.sendOtpToAgencyAdmin';
import getPicklist from '@salesforce/apex/MBP_BrokerLeadcontroller.getPicklist';
import getRejectionComments from '@salesforce/apex/MBP_BrokerAgencyInformationController.getRejectionComments';
import GuidelinesIcon from '@salesforce/resourceUrl/GuidelinesforMBP';
import MBP_VatUndertakingCertificate from '@salesforce/resourceUrl/MBP_VatUndertakingCertificate';

export default class BrokerAgencyDetails extends LightningElement {
    guidelinesIcon = GuidelinesIcon;
    @track isLoading = false;
    @track account = {};
    @track accountId;
    @track contact = {};
     @track uploadedBankFileName = ''; 
    @track showSpinner = false;
    @track vatUndertakingSubmitted = false;
@track fileName = '';
@track base64File = '';
@track fileSection = '';
@track previewUrl = ''; // for image preview
@track showVatSection=true;
@track tradeIssuanceDate; tradeIssuanceDateTemp;
@track licensingAuthority; licensingAuthorityTemp;
@track companyNameTradeLicense; companyNameTradeLicenseTemp;
@track fileName;
@track filePreviewUrl;
@track isImageFile = false;
@track isPdfFile = false;
@track previewUrl;
@track isImagePreview = false;
@track isPdfPreview = false;
 @track isMobile = false; //New

 @track beneficiaryName;//New By Raghu sharma
@track beneficiaryNameTemp;//New By Raghu Sharma


//* 1.2  starts
@track bankBranchName; 
bankBranchNameTemp;

@track bankBranchType;
bankBranchTypeTemp;
bankBranchTypeOptions = [
    { label: 'SWIFT', value: 'SWIFT' },
    { label: 'CHIPS', value: 'CHIPS' },
    { label: 'ABA', value: 'ABA' },
    { label: 'Other', value: 'Other' }
];
//* 1.2  ends

    @track selectedVatOption = 'Certificate';
   vatOptions = [
      { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
    { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
  
];
@track showConsentModal = false;

@track vatCertificateType; // For display in VAT Info section
@track vatTypeSelection = ''; // For modal picklist selection
@track isVatUndertakingSelected = false;
    @track vatNumber; vatNumberTemp;
    @track vatStartDate; vatStartDateTemp;

    @track tradeNumber; tradeNumberTemp;
    @track tradeExpiryDate; tradeExpiryDateTemp;

    @track bankName; bankNameTemp;
    @track accountNumber; accountNumberTemp;
    @track bankCountry; bankCountryTemp;
    @track ibanNumber; ibanNumberTemp;
    @track swiftCode; swiftCodeTemp;

    @track vatSubmitted = false;
    @track tradeSubmitted = false;
    @track bankSubmitted = false;


@track bankConsentGiven = false;
@track showVatSection = false;
@track showTradeSection = false;
@track showBankSection = false;
@track showAgencyInfoSection = false;

    @track vatDownloadUrl;
    @track tradeDownloadUrl;
    @track bankDownloadUrl;
// For VAT
vatFileName = null;
vatPreviewUrl = null;

// For Trade
tradeFileName = null;
tradePreviewUrl = null;

// For Bank
bankFileName = null;
bankPreviewUrl = null;

    @track fileName;
    @track base64File;
    @track fileSection;

    @track isModalOpen = false;
    @track isVatModal = false;
    @track isTradeModal = false;
    @track isBankModal = false;
    @track modalTitle = '';

    @track showOtpModal = false;
    @track generatedOtp;
    @track enteredOtp = '';
vatMarkedForDelete = false;
tradeMarkedForDelete = false;
bankMarkedForDelete = false;


    @track showCustomToast = false;
    @track customToastTitle = '';
    @track customToastMessage = '';
    @track customToastVariant = '';

    get showVatCertificate() {
        return this.selectedVatOption === 'Certificate';
    }

    get showVatUndertaking() {
        return this.selectedVatOption === 'Undertaking';
    }

    showCenteredToast(title, message, variant) {
        this.customToastTitle = title;
        this.customToastMessage = message;
        this.customToastVariant = variant;
        this.showCustomToast = true;

        setTimeout(() => {
            this.showCustomToast = false;
        }, 3000);
    }

    handleVatOptionChange(event) {
        this.selectedVatOption = event.detail.value;
    }

    handleVatUndertakingFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            this.vatUndertakingBase64 = base64;
            this.vatUndertakingFileName = file.name;
        };
        reader.readAsDataURL(file);
    }



    connectedCallback() {

             this.detectMobile(); // Set initial value
        window.addEventListener('resize', this.handleResize);
        
    getPicklist({ objectName: 'Account', fieldName: 'Bank_Country__c' })
        .then(result => {
            this.bankCountryOptions = result.values.map(country => {
                return { label: country, value: country };
            });
        })
        .catch(error => {
            console.error('Error fetching bank country picklist:', error);
        });

     
}

  disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize);
    }

      handleResize = () => {
        this.detectMobile();
    }

    detectMobile() {
        // You can adjust the breakpoint (here 768 matches common mobile/tablet)
        this.isMobile = window.innerWidth <= 768;
    }
    submitVatUndertaking() {
        submitSectionWithDocs({
            section: 'VAT_UNDERTAKING',
            accountId: this.account.Id,
            payload: {},
            base64File: this.vatUndertakingBase64,
            fileName: this.vatUndertakingFileName
        })
            .then(() => {
                this.vatUndertakingSubmitted = true;
                this.template.querySelector('c-mbp_customshowtoast').show(
    'VAT Undertaking submitted for approval.',
    'success'
);

            })
            .catch(error => {
                console.error(error);
               this.template.querySelector('c-mbp_customshowtoast').show(
    'Failed to submit VAT Undertaking.',
    'error'
);

            });
    }

    @wire(getEditableAccount)
wiredAccount({ error, data }) {
    this.isLoading = true;
    if (data) {
        const acc = data.account;
        const brokerType = data.brokerType;
        const contact = data.contact;

        // ✅ Dispatch brokerType to parent
        this.dispatchEvent(new CustomEvent('brokerupdate', {
            detail: { brokerType }
        }));

        this.account = acc;
        this.accountId = acc.Id;
        this.contact = contact;
        this.showAgencyInfoSection = true;


        // Broker Type logic
        if (brokerType === 'Owner' || brokerType === 'Agency Admin') {
            this.showTradeSection = true;
            this.showBankSection = true;

            // Only show VAT if UAE Broker
            if (acc.Type_of_Registration__c === 'UAE Broker') {
                this.showVatSection = true;
            } else {
                this.showVatSection = false;
            }
        } else if (brokerType === 'Agent') {
            this.showVatSection = false;
            this.showTradeSection = false;
            this.showBankSection = false;
        }

        // Use acc instead of data here
        this.vatCertificateType = acc.VAT_Certificate_Type__c;
this.vatTypeSelection = acc.VAT_Certificate_Type__c || 'VAT Registration Certificate'; // Set default
this.isVatUndertakingSelected = this.vatTypeSelection === 'VAT Undertaking Certificate';

        this.vatNumber = acc.UAEVATRegisterNumber__c;
        this.vatStartDate = acc.UAE_VAT_Start_Date__c;
        this.vatSubmitted = acc.VAT_Status__c === 'Submitted';
        this.vatCertificateType = acc.VAT_Certificate_Type__c;

        this.tradeNumber = acc.Trade_License_Number__c;
        this.tradeExpiryDate = acc.TradeLicenseExpiryDate__c;
        this.tradeSubmitted = acc.Trade_License_Status__c === 'Submitted';
        this.tradeIssuanceDate = acc.Issuance_Date__c;
        this.licensingAuthority = acc.Licensing_Authority__c;
        this.companyNameTradeLicense = acc.Company_Name_as_per_Trade_License__c;

          //Newly added By raghu sharma
        this.beneficiaryName = acc.Beneficiary_Name__c;  // For display
        this.beneficiaryNameTemp = acc.Beneficiary_Name__c;  // For edit modal

        //* 1.2  starts
this.bankBranchName = acc.Bank_Branch_Name__c;
this.bankBranchType = acc.Bank_Branch_Type__c;
//* 1.2  ends
        this.bankName = acc.Bank_Name__c;
         this.beneficiaryName = acc.Beneficiary_Name__c; //New By Raghu Sharma
        this.accountNumber = acc.Bank_Account_Number__c;
        this.bankCountry = acc.Bank_Country__c;
        this.ibanNumber = acc.IBAN_Number__c;
        this.swiftCode = acc.Swift_Code__c;
        this.accountcountry = acc.BillingCountry;
        this.agencyname = acc.Name;
        this.bankSubmitted = acc.Bank_Status__c === 'Submitted';

        this.loadDocumentLinks();

         if (acc.VAT_Status__c === 'Rejected') {
            getRejectionComments({ accountId: this.accountId, section: 'VAT' })
                .then(comment => this.vatRejectionComment = comment)
                .catch(err => console.error('Error fetching VAT rejection comment:', err));
        }
        if (acc.Trade_License_Status__c === 'Rejected') {
            getRejectionComments({ accountId: this.accountId, section: 'TRADE' })
                .then(comment => this.tradeRejectionComment = comment)
                .catch(err => console.error('Error fetching TRADE rejection comment:', err));
        }
        if (acc.Bank_Status__c === 'Rejected') {
            getRejectionComments({ accountId: this.accountId, section: 'BANK' })
                .then(comment => this.bankRejectionComment = comment)
                .catch(err => console.error('Error fetching BANK rejection comment:', err));
        }
    } else if (error) {
        
        console.error('❌ Error fetching account:', error);
    }
    this.isLoading = false;
}

handleVatTypeSelection(event) {
    this.vatTypeSelection = event.detail.value;
    this.isVatUndertakingSelected = this.vatTypeSelection === 'VAT Undertaking Certificate';
}

handleDeleteFile(event) {
    const section = event.currentTarget.dataset.section;

    // Clear the uploaded file based on the section
    if (section === 'VAT') {
        this.fileName = null;
    } else if (section === 'TRADE') {
        this.fileName = null;
    } else if (section === 'BANK') {
        this.fileName = null;
    }
this.fileName=null;
}

handleDeleteDocument(event) {
    const section = event.currentTarget.dataset.section;

    if (section === 'VAT') {
        this.vatDownloadUrl = null;
        
    } else if (section === 'TRADE') {
        this.tradeDownloadUrl = null;
       
    } else if (section === 'BANK') {
        this.bankDownloadUrl = null;
       
    }

}



downloadVAT() {
    // Create an invisible anchor element
    const link = document.createElement('a');
    link.href = MBP_VatUndertakingCertificate; // Static Resource URL
    link.download = 'VAT_Undertaking_Certificate.docx'; // Custom download name
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

  loadDocumentLinks() {

   getSectionDocs({ accountId: this.accountId, section: 'VAT' })
    .then(url => {
        if (url) {
            this.vatDownloadUrl = url;
        } else {
            this.vatDownloadUrl = null;  // Force re-render if not available
        }
    })
    .catch(error => {
        console.error('Error fetching VAT doc:', error);
        this.vatDownloadUrl = null;
    });

    getSectionDocs({ accountId: this.accountId, section: 'TRADE' })
        .then(url => {
            this.tradeDownloadUrl = url;
        })
        .catch(error => {
            console.error('Error fetching TRADE doc:', error);
        });

    getSectionDocs({ accountId: this.accountId, section: 'BANK' })
        .then(url => {
            this.bankDownloadUrl = url;
        })
        .catch(error => {
            console.error('Error fetching BANK doc:', error);
        });
}


    openBankModal() {
    this.isLoading = true; // ⏳ Start spinner

    sendOtpToAgencyAdmin({ accountId: this.accountId })
        .then(otp => {
            this.generatedOtp = otp;
            this.enteredOtp = '';
            this.showOtpModal = true;

           this.template.querySelector('c-mbp_customshowtoast').show(
    'OTP has been sent to the Primary Owner. Please verify the OTP to proceed with updating bank details.',
    'success'
);

        })
        .catch(error => {
            console.error('Error sending OTP:', error);
            this.template.querySelector('c-mbp_customshowtoast').show(
    'Failed to send OTP to Primary Owner.',
    'error'
);

        })
        .finally(() => {
            this.isLoading = false; // ✅ Stop spinner after success or failure
        });
}




    handleOtpChange(event) {
        this.enteredOtp = event.target.value;
    }

    openVatModal() {
        this.modalTitle = 'Update VAT Info';
        this.isVatModal = true;
        this.isTradeModal = false;
        this.isBankModal = false;
        this.isModalOpen = true;
        this.vatNumberTemp = this.vatNumber;
        this.vatStartDateTemp = this.vatStartDate;
    }

    openTradeModal() {
        this.modalTitle = 'Update Trade License';
        this.isVatModal = false;
        this.isTradeModal = true;
        this.isBankModal = false;
        this.isModalOpen = true;
        this.tradeNumberTemp = this.tradeNumber;
        this.tradeExpiryDateTemp = this.tradeExpiryDate;
        this.tradeIssuanceDateTemp = this.tradeIssuanceDate;
this.licensingAuthorityTemp = this.licensingAuthority;
this.companyNameTradeLicenseTemp = this.companyNameTradeLicense;

    }

  validateOtpAndOpenBankForm() {
    this.isLoading = true;

    setTimeout(() => {
        if (this.enteredOtp === this.generatedOtp) {
            this.showOtpModal = false;

            this.template.querySelector('c-mbp_customshowtoast').show(
    'OTP has been verified successfully. You may now update bank details.',
    'success'
);


            this.isBankModal = true;
            this.modalTitle = 'Update Bank Info';
            this.isVatModal = false;
            this.isTradeModal = false;
            this.isModalOpen = true;

            //* 1.2  starts
this.bankBranchNameTemp = this.bankBranchName;
this.bankBranchTypeTemp = this.bankBranchType;
//* 1.2  ends
            this.bankNameTemp = this.bankName;
            this.beneficiaryNameTemp = this.beneficiaryName; // New By Raghu sharma
            this.accountNumberTemp = this.accountNumber;
            this.bankCountryTemp = this.bankCountry;
            this.ibanNumberTemp = this.ibanNumber;
            this.swiftCodeTemp = this.swiftCode;
        } else {
            this.template.querySelector('c-mbp_customshowtoast').show(
    'The OTP entered is incorrect. Please try again.',
    'error'
);
        }

        this.isLoading = false;
    }, 500); // ⏱ Delay to simulate processing
}



    closeOtpModal() {
        this.showOtpModal = false;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isVatModal = false;
        this.isTradeModal = false;
        this.isBankModal = false;
        this.base64File = null;
        this.fileName = null;
        this.fileSection = null;
    }



    handleChange(event) {
        const { label, value } = event.target;
        if (label.includes('VAT Registration')) this.vatNumberTemp = value;
        if (label.includes('VAT Start')) this.vatStartDateTemp = value;
        if (label.includes('Trade License')) this.tradeNumberTemp = value;
        if (label.includes('Trade Expiry')) this.tradeExpiryDateTemp = value;
        if (label.includes('Bank Name')) this.bankNameTemp = value;
        if (label.includes('Account Number')) this.accountNumberTemp = value;
        if (label.includes('Beneficiary Name')) this.beneficiaryNameTemp = value.replace(/[^a-zA-Z0-9\s\-\.\,\&\(\)]/g, '');
        if (event.target.name === 'bankCountry') {
    this.bankCountryTemp = event.detail.value;
}

        if (label.includes('IBAN Number')) this.ibanNumberTemp = value;
                if (label.includes('Bank Branch Name')) this.bankBranchNameTemp = value;

if (event.target.name === 'bankBranchType') {
    this.bankBranchTypeTemp = event.detail.value;
}


        if (label.includes('SWIFT Code')) this.swiftCodeTemp = value;
        if (label.includes('Issuance Date')) this.tradeIssuanceDateTemp = value;
if (label.includes('Licensing Authority')) this.licensingAuthorityTemp = value;

if (label.includes('Company Name')) this.companyNameTradeLicenseTemp = value;

    }
    handleFileChange(event) {
    const file = event.target.files[0];
    if (!file) return;

    const section = event.target.dataset.section;
    this.fileSection = section;

    const extension = file.name.split('.').pop().toLowerCase();

    if (section === 'VAT') {
        this.fileName = `VAT_Registration_Certificate.${extension}`;
    } else if (section === 'TRADE') {
        this.fileName = `TradeLicense.${extension}`;
    } else if (section === 'BANK') {
        this.fileName = `IBAN.${extension}`;
    } else {
        this.fileName = file.name;
    }

    const reader = new FileReader();

    reader.onload = () => {
        const base64Result = reader.result.split(',')[1];
        this.base64File = base64Result;

        // Create a Blob and generate an object URL
        const byteCharacters = atob(base64Result);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: file.type });

        this.previewUrl = URL.createObjectURL(blob);
    };

    reader.readAsDataURL(file);
}

openPdfPreview() {
    if (this.previewUrl) {
        window.open(this.previewUrl, '_blank');
    }
}


get vatDocumentLabel() {
    if (this.vatCertificateType === 'VAT Undertaking Certificate') {
        return 'View VAT Undertaking Certificate';
    }
    return 'View VAT Registration Certificate';
}
closeConsentModal() {
    this.showConsentModal = false;
    this.isModalOpen = true; // reopen the original modal
}
confirmConsentAndSubmitBank() {
    this.showConsentModal = false;
    this.bankConsentGiven = true;

    // Small delay to ensure modal closes before submit triggers
    setTimeout(() => {
        this.submitModal();
    }, 100);
}

submitModal() { 
    let section = '';
    let payload = {};
    this.isLoading = true;

    try {

    // Approval in progress check
    if (
        (this.isVatModal && (this.tradeSubmitted || this.bankSubmitted)) ||
        (this.isTradeModal && (this.vatSubmitted || this.bankSubmitted)) ||
        (this.isBankModal && (this.vatSubmitted || this.tradeSubmitted))
    ) {
        this.isLoading = false;
        this.template.querySelector('c-mbp_customshowtoast').show(
    'Another approval (VAT, Trade License or Bank) is already in process. Please wait until it completes.',
    'error'
);

        return;
    }

    // 🔍 BANK VALIDATIONS
    if (this.isBankModal) {
        const allInputs = this.template.querySelectorAll("lightning-input, lightning-combobox");
        for (let inputField of allInputs) {
            const fieldName = inputField.dataset.field;
            const value = inputField.value?.trim() || "";

            if (!value) {
    let fieldLabel = inputField.label || 'This field';
    
    // For file field on bank modal — show high-level message
    if (this.isBankModal && inputField.type === 'file') {
        inputField.setCustomValidity("Please delete the existing bank copy and re-upload the updated bank document.");
    } else {
        inputField.setCustomValidity(`${fieldLabel} is required.`);
    }

    inputField.reportValidity();
    this.isLoading = false;
    return;
}

           
            // IBAN format check
            if (fieldName === 'IBAN_Country_Bank_Code__c') {
                const ibanPattern = /^AE\d{21}$/i;
                if (!ibanPattern.test(value)) {
                    inputField.setCustomValidity("Invalid IBAN format. It must start with 'AE' followed by 21 digits.");
                    inputField.reportValidity();
                    this.isLoading = false;
                    return;
                }
            }

            // Account Number must be digits only
            if (fieldName === 'Account_Number__c') {
                const accountPattern = /^\d+$/;
                if (!accountPattern.test(value)) {
                    inputField.setCustomValidity("Account Number must contain only digits.");
                    inputField.reportValidity();
                    this.isLoading = false;
                    return;
                }
            }

            // SWIFT Code format check
            if (fieldName === 'SWIFT_Sort_Code__c') {
                const swiftPattern = /^[A-Za-z0-9]{8}([A-Za-z0-9]{3})?$/;
                if (!swiftPattern.test(value)) {
                    inputField.setCustomValidity("SWIFT Code must be 8 or 11 characters (letters/digits).");
                    inputField.reportValidity();
                    this.isLoading = false;
                    return;
                }
            }

       const iban = this.ibanNumberTemp?.replace(/\s+/g, '') || '';
const accountNumber = this.accountNumberTemp?.trim() || '';

if (iban && accountNumber) {
    const ibanTail = iban.slice(-13);
    if (
        (fieldName === 'IBAN_Country_Bank_Code__c' || fieldName === 'Account_Number__c') &&
        ibanTail !== accountNumber
    ) {
        // ✅ New logic: check if at least 5 consecutive digits from account number exist anywhere in IBAN
        const accountSub = accountNumber.slice(-5); // take last 5 characters of account number
        if (!iban.includes(accountSub)) {
            inputField.setCustomValidity("Account Number must exactly match at least 5 consecutive digits within the IBAN.");
            inputField.reportValidity();
            this.isLoading = false;
            return;
        }
    }
}

inputField.setCustomValidity(""); // Clear old error
inputField.reportValidity();
        }

        // ✅ Consent check AFTER validation
        if (!this.bankConsentGiven) {
            this.isModalOpen = false;
            this.showConsentModal = true;
            this.isLoading = false;
            return;
        }
    }

    // Prepare section and payload
    if (this.isVatModal) {
        section = 'VAT';
        if (this.vatTypeSelection === 'VAT Undertaking Certificate') {
        payload = {};
        }
        else {
         const allInputs = this.template.querySelectorAll("lightning-input, lightning-combobox");

    for (let inputField of allInputs) {
        const label = inputField.label || '';
        const value = inputField.value?.trim() || '';
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Required check
        if (!value) {
            if (inputField.type === 'file') {
                inputField.setCustomValidity("Please delete the existing VAT file and upload a new, updated copy.");
            } else {
                inputField.setCustomValidity(`${label} is required.`);
            }
            inputField.reportValidity();
            this.isLoading = false;
            return;
        }

        // VAT Start Date should NOT be in the future
        if (label === 'VAT Start Date') {
            const startDate = new Date(value);
            if (startDate > today) {
                inputField.setCustomValidity("VAT Start Date cannot be in the future.");
                inputField.reportValidity();
                this.isLoading = false;
                return;
            }
        }

        inputField.setCustomValidity('');
        inputField.reportValidity();
    }
        payload = {
            Proposed_VAT_Registration_Number__c: this.vatNumberTemp,
            Proposed_VAT_Start_Date__c: this.vatStartDateTemp,
            VAT_Certificate_Type__c: this.vatTypeSelection
        };
    } 
}
else if (this.isTradeModal) {
    section = 'TRADE';
    const allInputs = this.template.querySelectorAll("lightning-input, lightning-combobox");

    const today = new Date();
    today.setHours(0, 0, 0, 0); // Remove time

    for (let inputField of allInputs) {
        const fieldLabel = inputField.label || '';
        const value = inputField.value?.trim() || '';

        // Required field check
        if (!value) {
            if (inputField.type === 'file') {
                inputField.setCustomValidity("Please delete the existing trade license file and upload a new, updated copy.");
            } else {
                inputField.setCustomValidity(`${fieldLabel} is required.`);
            }
            inputField.reportValidity();
            this.isLoading = false; // 🛑 Stop spinner on error
            return;
        }

        // Issuance Date should NOT be in the future
        if (fieldLabel === 'Issuance Date') {
            const issuanceDate = new Date(value);
            if (issuanceDate > today) {
                inputField.setCustomValidity("Issuance Date cannot be in the future.");
                inputField.reportValidity();
                this.isLoading = false;
                return;
            }
        }

        // Trade Expiry Date should be in the future
        if (fieldLabel === 'Trade Expiry Date') {
            const expiryDate = new Date(value);
            if (expiryDate <= today) {
                inputField.setCustomValidity("Trade Expiry Date must be a future date.");
                inputField.reportValidity();
                this.isLoading = false;
                return;
            }
        }

        inputField.setCustomValidity('');
        inputField.reportValidity();
    }

    payload = {
        Proposed_Trade_License_Number__c: this.tradeNumberTemp,
        Proposed_Trade_License_Expiry_Date__c: this.tradeExpiryDateTemp,
        Proposed_Trade_issuance_date__c: this.tradeIssuanceDateTemp,
        Licensing_Authority__c: this.licensingAuthorityTemp,
        Company_Name_as_per_Trade_License__c: this.companyNameTradeLicenseTemp
    };
}
 else if (this.isBankModal) {
        section = 'BANK';
        payload = {
            Proposed_Bank_Name__c: this.bankNameTemp,
            Proposed_Beneficiary_Name__c: this.beneficiaryNameTemp,//Newly added By Raghu Sharma
            Proposed_Bank_Account_Number__c: this.accountNumberTemp,
            Proposed_Bank_Country__c: this.bankCountryTemp,
            Proposed_IBAN_Number__c: this.ibanNumberTemp,

            //* 1.2  starts
             Proposed_Bank_Branch_Name__c: this.bankBranchNameTemp,

        Proposed_Bank_Branch_Type__c: this.bankBranchTypeTemp,

        //* 1.2  ends
            Proposed_SWIFT_Code__c: this.swiftCodeTemp
        };
    }

    // Log submission details

    submitSectionWithDocs({
        section,
        accountId: this.accountId,
        payload,
        base64File: this.base64File,
        fileName: this.fileName
    })
    .then((documentUrl) => {

         

        if (section === 'VAT') this.vatSubmitted = true;
        if (section === 'TRADE') this.tradeSubmitted = true;
        if (section === 'BANK') {
            this.bankSubmitted = true;
            this.bankConsentGiven = false; // Reset after success
        }

       this.template.querySelector('c-mbp_customshowtoast').show(
    `${section} details submitted successfully.`,
    'success'
);

        this.closeModal();
        this.loadDocumentLinks();
    })
    .catch(error => {
        console.error(`❌ Error submitting ${section}:`, error);
        this.template.querySelector('c-mbp_customshowtoast').show(
    `Failed to submit ${section} details.`,
    'error'
);

    })
    .finally(() => {
        this.isLoading = false;
    });

    } catch (e) {
        console.error('Unexpected error in submitModal:', e);
        this.isLoading = false;
        this.template.querySelector('c-mbp_customshowtoast').show(
            'An unexpected error occurred while submitting. Please try again.',
            'error'
        );
    }
}




get anySectionSubmitted() {
    const result = this.vatSubmitted || this.tradeSubmitted || this.bankSubmitted;
    return result;
}

get canShowVatButton() {
    const result = !this.vatSubmitted && !this.anySectionSubmitted;
    return result;
}

get canShowTradeButton() {
    const result = !this.tradeSubmitted && !this.anySectionSubmitted;
    return result;
}

get canShowBankButton() {
    const result = !this.bankSubmitted && !this.anySectionSubmitted;
    return result;
}


}