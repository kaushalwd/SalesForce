import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import upsertRegistrationRecord from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import sendOtpToEmail from '@salesforce/apex/MBP_RegistrationFormController.sendOtpToEmail';

import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import getLatestServiceRequestNumber from '@salesforce/apex/MBP_RegistrationFormController.getLatestServiceRequestNumber';
import { loadScript } from 'lightning/platformResourceLoader';
import CONFETTI from '@salesforce/resourceUrl/canvasConfetti';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';

export default class BankInformationForm2 extends NavigationMixin(LightningElement) {
    @api mode; // 'draft' or 'registration'
isDraftMode = false;
  
    @api registrationStatus;
    @track activeSections = ['Power of Attorney', 'Company Bank Information', 'Tax Registration', 'Document Uploads'];
    @track registrationObj = {};
    @track registrationRec = {};
    @track selectedPOA;
    @track showConfirmationModal = false;
     isLibLoaded = false;
    @track selectedBankAccStatus;
    @track selectedFedTaxAuthReg;
    @api recordId;
    @track isDisabled = false;
    @track isIbanUploaded = false;
    @track ibanFileName;
    @track ibanContentVersionId = '';
    @track ibanContentDocumentId = '';
    @track ibanData = null;
    @track isOtherUploaded = false;
    @track otherFileName;
    @track otherContentVersionId = '';
    @track otherContentDocumentId = '';
    @track otherData = null;   
    @track initialRegistrationRec = {};
    @track isLoading = false;
    @track selectedCountry;
    @track enteredOtp = '';
@track showOtpModal = false;

@track otpSent = '';
otpVerified = false;


showCelebration = false;
 audio;
    get countryOptions (){
        return [
            { label: 'Afghanistan', value: 'Afghanistan' },
            { label: 'Åland Islands', value: 'Åland Islands' },
            { label: 'Albania', value: 'Albania' },
            { label: 'Algeria', value: 'Algeria' },
            { label: 'American Samoa', value: 'American Samoa' },
            { label: 'Andorra', value: 'Andorra' },
            { label: 'Angola', value: 'Angola' },
            { label: 'Anguilla', value: 'Anguilla' },
            { label: 'Antarctica', value: 'Antarctica' },
            { label: 'Antigua and Barbuda', value: 'Antigua and Barbuda' },
            { label: 'Argentina', value: 'Argentina' },
            { label: 'Armenia', value: 'Armenia' },
            { label: 'Aruba', value: 'Aruba' },
            { label: 'Australia', value: 'Australia' },
            { label: 'Austria', value: 'Austria' },
            { label: 'Azerbaijan', value: 'Azerbaijan' },
            { label: 'Bahamas', value: 'Bahamas' },
            { label: 'Bahrain', value: 'Bahrain' },
            { label: 'Bangladesh', value: 'Bangladesh' },
            { label: 'Barbados', value: 'Barbados' },
            { label: 'Belarus', value: 'Belarus' },
            { label: 'Belgium', value: 'Belgium' },
            { label: 'Belize', value: 'Belize' },
            { label: 'Benin', value: 'Benin' },
            { label: 'Bermuda', value: 'Bermuda' },
            { label: 'Bhutan', value: 'Bhutan' },
            { label: 'Bolivia', value: 'Bolivia' },
            { label: 'Bonaire, Sint Eustatius and Saba', value: 'Bonaire, Sint Eustatius and Saba' },
            { label: 'Bosnia and Herzegovina', value: 'Bosnia and Herzegovina' },
            { label: 'Botswana', value: 'Botswana' },
            { label: 'Bouvet Island', value: 'Bouvet Island' },
            { label: 'Brazil', value: 'Brazil' },
            { label: 'British Indian Ocean Territory', value: 'British Indian Ocean Territory' },
            { label: 'Brunei Darussalam', value: 'Brunei Darussalam' },
            { label: 'Bulgaria', value: 'Bulgaria' },
            { label: 'Burkina Faso', value: 'Burkina Faso' },
            { label: 'Burundi', value: 'Burundi' },
            { label: 'Cabo Verde', value: 'Cabo Verde' },
            { label: 'Cambodia', value: 'Cambodia' },
            { label: 'Cameroon', value: 'Cameroon' },
            { label: 'Canada', value: 'Canada' },
            { label: 'Cayman Islands', value: 'Cayman Islands' },
            { label: 'Central African Republic', value: 'Central African Republic' },
            { label: 'Chad', value: 'Chad' },
            { label: 'Chile', value: 'Chile' },
            { label: 'China', value: 'China' },
            { label: 'Christmas Island', value: 'Christmas Island' },
            { label: 'Cocos (Keeling) Islands', value: 'Cocos (Keeling) Islands' },
            { label: 'Colombia', value: 'Colombia' },
            { label: 'Comoros', value: 'Comoros' },
            { label: 'Congo', value: 'Congo' },
            { label: 'Congo, Democratic Republic of the', value: 'Congo, Democratic Republic of the' },
            { label: 'Cook Islands', value: 'Cook Islands' },
            { label: 'Costa Rica', value: 'Costa Rica' },
            { label: 'Côte d\'Ivoire', value: 'Côte d\'Ivoire' },
            { label: 'Croatia', value: 'Croatia' },
            { label: 'Cuba', value: 'Cuba' },
            { label: 'Curaçao', value: 'Curaçao' },
            { label: 'Cyprus', value: 'Cyprus' },
            { label: 'Czechia', value: 'Czechia' },
            { label: 'Denmark', value: 'Denmark' },
            { label: 'Djibouti', value: 'Djibouti' },
            { label: 'Dominica', value: 'Dominica' },
            { label: 'Dominican Republic', value: 'Dominican Republic' },
            { label: 'Ecuador', value: 'Ecuador' },
            { label: 'Egypt', value: 'Egypt' },
            { label: 'El Salvador', value: 'El Salvador' },
            { label: 'Equatorial Guinea', value: 'Equatorial Guinea' },
            { label: 'Eritrea', value: 'Eritrea' },
            { label: 'Estonia', value: 'Estonia' },
            { label: 'Eswatini', value: 'Eswatini' },
            { label: 'Ethiopia', value: 'Ethiopia' },
            { label: 'Falkland Islands (Malvinas)', value: 'Falkland Islands (Malvinas)' },
            { label: 'Faroe Islands', value: 'Faroe Islands' },
            { label: 'Fiji', value: 'Fiji' },
            { label: 'Finland', value: 'Finland' },
            { label: 'France', value: 'France' },
            { label: 'French Guiana', value: 'French Guiana' },
            { label: 'French Polynesia', value: 'French Polynesia' },
            { label: 'French Southern Territories', value: 'French Southern Territories' },
            { label: 'Gabon', value: 'Gabon' },
            { label: 'Gambia', value: 'Gambia' },
            { label: 'Georgia', value: 'Georgia' },
            { label: 'Germany', value: 'Germany' },
            { label: 'Ghana', value: 'Ghana' },
            { label: 'Gibraltar', value: 'Gibraltar' },
            { label: 'Greece', value: 'Greece' },
            { label: 'Greenland', value: 'Greenland' },
            { label: 'Grenada', value: 'Grenada' },
            { label: 'Guadeloupe', value: 'Guadeloupe' },
            { label: 'Guam', value: 'Guam' },
            { label: 'Guatemala', value: 'Guatemala' },
            { label: 'Guernsey', value: 'Guernsey' },
            { label: 'Guinea', value: 'Guinea' },
            { label: 'Guinea-Bissau', value: 'Guinea-Bissau' },
            { label: 'Guyana', value: 'Guyana' },
            { label: 'Haiti', value: 'Haiti' },
            { label: 'Heard Island and McDonald Islands', value: 'Heard Island and McDonald Islands' },
            { label: 'Holy See', value: 'Holy See' },
            { label: 'Honduras', value: 'Honduras' },
            { label: 'Hong Kong', value: 'Hong Kong' },
            { label: 'Hungary', value: 'Hungary' },
            { label: 'Iceland', value: 'Iceland' },
            { label: 'India', value: 'India' },
            { label: 'Indonesia', value: 'Indonesia' },
            { label: 'Iran', value: 'Iran' },
            { label: 'Iraq', value: 'Iraq' },
            { label: 'Ireland', value: 'Ireland' },
            { label: 'Isle of Man', value: 'Isle of Man' },
            { label: 'Israel', value: 'Israel' },
            { label: 'Italy', value: 'Italy' },
            { label: 'Jamaica', value: 'Jamaica' },
            { label: 'Japan', value: 'Japan' },
            { label: 'Jersey', value: 'Jersey' },
            { label: 'Jordan', value: 'Jordan' },
            { label: 'Kazakhstan', value: 'Kazakhstan' },
            { label: 'Kenya', value: 'Kenya' },
            { label: 'Kiribati', value: 'Kiribati' },
            { label: 'Korea, Democratic People\'s Republic of', value: 'Korea, Democratic People\'s Republic of' },
            { label: 'Korea, Republic of', value: 'Korea, Republic of' },
            { label: 'Kuwait', value: 'Kuwait' },
            { label: 'Kyrgyzstan', value: 'Kyrgyzstan' },
            { label: 'Lao People\'s Democratic Republic', value: 'Lao People\'s Democratic Republic' },
            { label: 'Latvia', value: 'Latvia' },
            { label: 'Lebanon', value: 'Lebanon' },
            { label: 'Lesotho', value: 'Lesotho' },
            { label: 'Liberia', value: 'Liberia' },
            { label: 'Libya', value: 'Libya' },
            { label: 'Liechtenstein', value: 'Liechtenstein' },
            { label: 'Lithuania', value: 'Lithuania' },
            { label: 'Luxembourg', value: 'Luxembourg' },
            { label: 'Macao', value: 'Macao' },
            { label: 'Madagascar', value: 'Madagascar' },
            { label: 'Malawi', value: 'Malawi' },
            { label: 'Malaysia', value: 'Malaysia' },
            { label: 'Maldives', value: 'Maldives' },
            { label: 'Mali', value: 'Mali' },
            { label: 'Malta', value: 'Malta' },
            { label: 'Marshall Islands', value: 'Marshall Islands' },
            { label: 'Martinique', value: 'Martinique' },
            { label: 'Mauritania', value: 'Mauritania' },
            { label: 'Mauritius', value: 'Mauritius' },
            { label: 'Mayotte', value: 'Mayotte' },
            { label: 'Mexico', value: 'Mexico' },
            { label: 'Micronesia', value: 'Micronesia' },
            { label: 'Moldova', value: 'Moldova' },
            { label: 'Monaco', value: 'Monaco' },
            { label: 'Mongolia', value: 'Mongolia' },
            { label: 'Montenegro', value: 'Montenegro' },
            { label: 'Montserrat', value: 'Montserrat' },
            { label: 'Morocco', value: 'Morocco' },
            { label: 'Mozambique', value: 'Mozambique' },
            { label: 'Myanmar', value: 'Myanmar' },
            { label: 'Namibia', value: 'Namibia' },
            { label: 'Nauru', value: 'Nauru' },
            { label: 'Nepal', value: 'Nepal' },
            { label: 'Netherlands', value: 'Netherlands' },
            { label: 'New Caledonia', value: 'New Caledonia' },
            { label: 'New Zealand', value: 'New Zealand' },
            { label: 'Nicaragua', value: 'Nicaragua' },
            { label: 'Niger', value: 'Niger' },
            { label: 'Nigeria', value: 'Nigeria' },
            { label: 'Niue', value: 'Niue' },
            { label: 'Norfolk Island', value: 'Norfolk Island' },
            { label: 'North Macedonia', value: 'North Macedonia' },
            { label: 'Northern Mariana Islands', value: 'Northern Mariana Islands' },
            { label: 'Norway', value: 'Norway' },
            { label: 'Oman', value: 'Oman' },
            { label: 'Pakistan', value: 'Pakistan' },
            { label: 'Palau', value: 'Palau' },
            { label: 'Palestine', value: 'Palestine' },
            { label: 'Panama', value: 'Panama' },
            { label: 'Papua New Guinea', value: 'Papua New Guinea' },
            { label: 'Paraguay', value: 'Paraguay' },
            { label: 'Peru', value: 'Peru' },
            { label: 'Philippines', value: 'Philippines' },
            { label: 'Pitcairn', value: 'Pitcairn' },
            { label: 'Poland', value: 'Poland' },
            { label: 'Portugal', value: 'Portugal' },
            { label: 'Puerto Rico', value: 'Puerto Rico' },
            { label: 'Qatar', value: 'Qatar' },
            { label: 'Réunion', value: 'Réunion' },
            { label: 'Romania', value: 'Romania' },
            { label: 'Russian Federation', value: 'Russian Federation' },
            { label: 'Rwanda', value: 'Rwanda' },
            { label: 'Saint Barthélemy', value: 'Saint Barthélemy' },
            { label: 'Saint Helena, Ascension and Tristan da Cunha', value: 'Saint Helena, Ascension and Tristan da Cunha' },
            { label: 'Saint Kitts and Nevis', value: 'Saint Kitts and Nevis' },
            { label: 'Saint Lucia', value: 'Saint Lucia' },
            { label: 'Saint Martin', value: 'Saint Martin' },
            { label: 'Saint Pierre and Miquelon', value: 'Saint Pierre and Miquelon' },
            { label: 'Saint Vincent and the Grenadines', value: 'Saint Vincent and the Grenadines' },
            { label: 'Samoa', value: 'Samoa' },
            { label: 'San Marino', value: 'San Marino' },
            { label: 'Sao Tome and Principe', value: 'Sao Tome and Principe' },
            { label: 'Saudi Arabia', value: 'Saudi Arabia' },
            { label: 'Senegal', value: 'Senegal' },
            { label: 'Serbia', value: 'Serbia' },
            { label: 'Seychelles', value: 'Seychelles' },
            { label: 'Sierra Leone', value: 'Sierra Leone' },
            { label: 'Singapore', value: 'Singapore' },
            { label: 'Sint Maarten', value: 'Sint Maarten' },
            { label: 'Slovakia', value: 'Slovakia' },
            { label: 'Slovenia', value: 'Slovenia' },
            { label: 'Solomon Islands', value: 'Solomon Islands' },
            { label: 'Somalia', value: 'Somalia' },
            { label: 'South Africa', value: 'South Africa' },
            { label: 'South Georgia and the South Sandwich Islands', value: 'South Georgia and the South Sandwich Islands' },
            { label: 'South Sudan', value: 'South Sudan' },
            { label: 'Spain', value: 'Spain' },
            { label: 'Sri Lanka', value: 'Sri Lanka' },
            { label: 'Sudan', value: 'Sudan' },
            { label: 'Suriname', value: 'Suriname' },
            { label: 'Svalbard and Jan Mayen', value: 'Svalbard and Jan Mayen' },
            { label: 'Sweden', value: 'Sweden' },
            { label: 'Switzerland', value: 'Switzerland' },
            { label: 'Syrian Arab Republic', value: 'Syrian Arab Republic' },
            { label: 'Taiwan', value: 'Taiwan' },
            { label: 'Tajikistan', value: 'Tajikistan' },
            { label: 'Tanzania', value: 'Tanzania' },
            { label: 'Thailand', value: 'Thailand' },
            { label: 'Timor-Leste', value: 'Timor-Leste' },
            { label: 'Togo', value: 'Togo' },
            { label: 'Tokelau', value: 'Tokelau' },
            { label: 'Tonga', value: 'Tonga' },
            { label: 'Trinidad and Tobago', value: 'Trinidad and Tobago' },
            { label: 'Tunisia', value: 'Tunisia' },
            { label: 'Turkey', value: 'Turkey' },
            { label: 'Turkmenistan', value: 'Turkmenistan' },
            { label: 'Turks and Caicos Islands', value: 'Turks and Caicos Islands' },
            { label: 'Tuvalu', value: 'Tuvalu' },
            { label: 'Uganda', value: 'Uganda' },
            { label: 'Ukraine', value: 'Ukraine' },
            { label: 'United Arab Emirates', value: 'United Arab Emirates' },
            { label: 'United Kingdom', value: 'United Kingdom' },
            { label: 'United States', value: 'United States' },
            { label: 'United States Minor Outlying Islands', value: 'United States Minor Outlying Islands' },
            { label: 'Uruguay', value: 'Uruguay' },
            { label: 'Uzbekistan', value: 'Uzbekistan' },
            { label: 'Vanuatu', value: 'Vanuatu' },
            { label: 'Venezuela', value: 'Venezuela' },
            { label: 'Viet Nam', value: 'Viet Nam' },
            { label: 'Virgin Islands, British', value: 'Virgin Islands, British' },
            { label: 'Virgin Islands, U.S.', value: 'Virgin Islands, U.S.' },
            { label: 'Wallis and Futuna', value: 'Wallis and Futuna' },
            { label: 'Western Sahara', value: 'Western Sahara' },
            { label: 'Yemen', value: 'Yemen' },
            { label: 'Zambia', value: 'Zambia' },
            { label: 'Zimbabwe', value: 'Zimbabwe' }
        ];
    }

    get yesNoOptions() {
        return [
            { label: '--None--', value: '--None--' },
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get bankAccStatusOptions() {
        return [
            { label: 'None', value: 'None' }
        ];
    }
async connectedCallback() {
        this.isLoading = true;
        try {
            if (!this.recordId) {
                this.registrationRec.Status__c = 'Draft';
            } else {
                this.registrationObj = await getRegistrationById({ recordId: this.recordId });
                if (this.registrationObj.Status__c !== 'Draft') {
                    this.isDisabled = true;
                }
            }
            this.registrationRec = { ...this.registrationRec, ...this.registrationObj };
            this.ibanFileName = `IBAN`;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            await this.loadExistingFiles();
            this.initialRegistrationRec = { ...this.registrationRec };
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load registration data: ' + (error.body?.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
 get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted';
    }



handleFieldChange(event) {
    const fieldName = event.target.name;
    const value = event.detail?.value ?? event.target.value;
    const inputField = event.target;
    const regType = this.registrationRec.Type_of_Registration__c?.toLowerCase();

    // Default update
    this.registrationRec = { ...this.registrationRec, [fieldName]: value };

    // Skip validation if no value
    if (!value) return;

    // Remove all spaces and check against patterns
    const trimmedValue = value.replace(/\s+/g, '');

    // Common: check for special characters (always)
    const specialCharPattern = /[^a-zA-Z0-9]/;
    if (fieldName !== 'Bank_Country__c' && specialCharPattern.test(trimmedValue)) {
        inputField.setCustomValidity("Special characters are not allowed.");
        inputField.reportValidity();
        return;
    }

    
    if (fieldName === 'IBAN_Country_Bank_Code__c') {
        const ibanPattern = /^AE\d{21}$/i;
        if (!ibanPattern.test(trimmedValue)) {
            inputField.setCustomValidity("Invalid IBAN format. It must start with 'AE' followed by 21 digits.");
            inputField.reportValidity();
            return;
        }
    }

    // Account Number format check
  if (fieldName === 'Account_Number__c') {
        const accountPattern = /^\d+$/;
        if (!accountPattern.test(trimmedValue)) {
            inputField.setCustomValidity("Account Number must contain only digits.");
            inputField.reportValidity();
            return;
        }
    }
    // SWIFT Code format check
    if (fieldName === 'SWIFT_Sort_Code__c') {
        const swiftPattern = /^[A-Za-z0-9]{8}([A-Za-z0-9]{3})?$/;
        if (!swiftPattern.test(trimmedValue)) {
            inputField.setCustomValidity("SWIFT Code must be 8 or 11 characters (letters/digits).");
            inputField.reportValidity();
            return;
        }
    }

    // IBAN must include full Account Number
    const iban = this.registrationRec.IBAN_Country_Bank_Code__c?.replace(/\s+/g, '') || '';
    const accountNumber = this.registrationRec.Account_Number__c?.trim() || '';
   


    if (iban && accountNumber) {
    const last13OfIban = iban.slice(-13); // Get last 13 digits

    if (last13OfIban !== accountNumber) {
        if (fieldName === 'IBAN_Country_Bank_Code__c' || fieldName === 'Account_Number__c') {
            inputField.setCustomValidity("Account Number must exactly match the last 13 digits of the IBAN.");
            inputField.reportValidity();
            return;
        }
    }
    }



    // Clear all errors if validation passed
    inputField.setCustomValidity('');
    inputField.reportValidity();

    // If IBAN or account was changed, update in state
    this.registrationRec = { ...this.registrationRec, [fieldName]: value };

    if (fieldName === 'Name') {
        this.ibanFileName = `IBAN`;
        this.otherFileName = `Other_${this.registrationRec.Name}`;
    }
}

    handleConfirmIbanBlur(event) {
        const value = event.target.value;
        if (value && value !== this.registrationRec.IBAN_Country_Bank_Code__c) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Confirm IBAN must match IBAN/Country Bank Code.',
                    variant: 'error'
                })
            );
            this.registrationRec = { ...this.registrationRec, Confirm_IBAN__c: null };
            const inputField = this.template.querySelector(`lightning-input[name="Confirm_IBAN__c"]`);
            if (inputField) {
                inputField.value = null;
            }
        }
    }

handleOtpChange(event) {
    this.enteredOtp = event.target.value;
}

handleNumericInput(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        if (value && !/^[0-9]*$/.test(value)) {
            this.registrationRec = { ...this.registrationRec, [fieldName]: '' };
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.value = '';
                inputField.setCustomValidity('Please enter only numbers');
                inputField.reportValidity();
            }
        } else {
            this.registrationRec = { ...this.registrationRec, [fieldName]: value };
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.setCustomValidity('');
                inputField.reportValidity();
            }
        }
    }
 async loadExistingFiles() {
        this.isLoading = true;
        try {
            const ibanResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'IBAN'
            });

            if (ibanResult && ibanResult.file) {
                this.isIbanUploaded = true;
                this.ibanFileName = ibanResult.file.Title;
                this.ibanContentVersionId = ibanResult.file.Id;
                this.ibanContentDocumentId = ibanResult.file.ContentDocumentId;
            } else {
                this.isIbanUploaded = false;
                this.ibanFileName = `IBAN`;
                this.ibanContentVersionId = '';
                this.ibanContentDocumentId = '';
            }

            const otherResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'Other_'
            });

            if (otherResult && otherResult.file) {
                this.isOtherUploaded = true;
                this.otherFileName = otherResult.file.Title;
                this.otherContentVersionId = otherResult.file.Id;
                this.otherContentDocumentId = otherResult.file.ContentDocumentId;
            } else {
                this.isOtherUploaded = false;
                this.otherFileName = `Other_${this.registrationRec.Name}`;
                this.otherContentVersionId = '';
                this.otherContentDocumentId = '';
            }
        } catch (error) {
            console.error('Error loading existing files:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load existing files: ' + error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }



async handleIbanChange(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        if (!file) {
            this.isLoading = false;
            return;
        }

        const validExtensions = ['pdf', 'jpg', 'jpeg'];
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!validExtensions.includes(fileExtension)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Only .pdf and .jpg files are allowed.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880;
        if (file.size > maxSize) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        this.isIbanUploaded = true;
        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.ibanData = {
                filename: `${this.ibanFileName}.${file.name.split('.').pop()}`,
                base64: base64Data
            };

            if (this.recordId) {
                await uploadFile({
                    recordId: this.recordId,
                    fileName: this.ibanData.filename,
                    base64Data: this.ibanData.base64
                });

                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'IBAN Copy uploaded successfully!',
                        variant: 'success'
                    })
                );
            } else {
                this.registrationRec.Status__c = 'Draft';
                const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
                this.registrationRec.Id = recordId;
                this.recordId = recordId;

                await uploadFile({
                    recordId: this.recordId,
                    fileName: this.ibanData.filename,
                    base64Data: this.ibanData.base64
                });

                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'IBAN Copy uploaded successfully!',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            this.isIbanUploaded = false;
            this.ibanData = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to process IBAN Copy file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleOtherChange(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        if (!file) {
            this.isLoading = false;
            return;
        }

        // Validate file extension and MIME type
        const validExtensions = ['pdf', 'jpg', 'jpeg'];
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!validExtensions.includes(fileExtension)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Only .pdf and .jpg files are allowed.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880; // 5MB
        if (file.size > maxSize) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        this.isOtherUploaded = true;
        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.otherData = {
                filename: `${this.otherFileName}.${file.name.split('.').pop()}`,
                base64: base64Data
            };

            if (this.recordId) {
                const uploadResult = await uploadFile({
                    recordId: this.recordId,
                    fileName: this.otherData.filename,
                    base64Data: this.otherData.base64
                });
                
                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Other Related Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            } else {
                this.registrationRec.Status__c = 'Draft';
                const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
                this.registrationRec.Id = recordId;
                this.recordId = recordId;
                const uploadResult = await uploadFile({
                    recordId: this.recordId,
                    fileName: this.otherData.filename,
                    base64Data: this.otherData.base64
                });
                
                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Other Related Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            this.isOtherUploaded = false;
            this.otherData = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to process Other Related Document file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }
   async handleRemoveIban() {
    this.isLoading = true;
    try {
        if (this.ibanContentDocumentId) {
            await deleteFile({ contentDocumentId: this.ibanContentDocumentId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `File ${this.ibanFileName} deleted`,
                    variant: 'success'
                })
            );
        }
        this.isIbanUploaded = false;
        this.ibanFileName = `IBAN`;
        this.ibanContentDocumentId = '';
    } catch (error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: `Failed to delete ${this.ibanFileName}: ${error.body?.message}`,
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}


    async handleRemoveOther() {
        this.isLoading = true;
        try {
            if (this.otherContentDocumentId) {
                await deleteFile({ contentDocumentId: this.otherContentDocumentId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `File ${this.otherFileName} deleted`,
                        variant: 'success'
                    })
                );
            }
            this.isOtherUploaded = false;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            this.otherContentDocumentId = '';
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `Failed to delete ${this.otherFileName}: ${error.body?.message}`,
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }

async openIbanPreviewPopup() {
    try {
        if (!this.ibanContentVersionId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No IBAN Copy file available to preview.',
                    variant: 'error'
                })
            );
            return;
        }

        const baseUrl = window.location.origin + '/';
        const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.ibanContentVersionId}`;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: fileUrl
            }
        }, false);
    } catch (error) {
        console.error('Error in openIbanPreviewPopup:', JSON.stringify(error));
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to preview IBAN Copy file: ' + (error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    }
}


    async openOtherPreviewPopup() {
        try {
            if (!this.otherContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Other Related Document file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.otherContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in openOtherPreviewPopup:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Other Related Document file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
@api async submitForm() {
        // Step 1: Show confirmation modal
        if (!this.otpVerified && !this.showConfirmationModal && !this.showOtpModal) {
            this.showConfirmationModal = true;
            return;
        }

        // Step 2: Show OTP modal after Accept
        if (!this.otpVerified && this.showOtpModal) {
            return; // Wait for OTP verification
        }

        // Step 3: Final submission if OTP already verified
        this.isLoading = true;
        const iban = this.registrationRec.IBAN_Country_Bank_Code__c?.replace(/\s+/g, '') || '';
        const accountNumber = this.registrationRec.Account_Number__c?.trim() || '';
        const regType = this.registrationRec.Type_of_Registration__c?.toLowerCase();

        try {
            if (regType === 'uae broker' && !iban.includes(accountNumber)) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'The IBAN must include the complete Account Number.',
                    variant: 'error'
                }));
                this.isLoading = false;
                return;
            }

            this.registrationRec.Status__c = 'Submitted';
            const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
            this.registrationRec.Id = recordId;
            this.recordId = recordId;

            const sr = await getLatestServiceRequestNumber({ registrationId: recordId });
            this.srNumber = sr;

            this.showCelebration = true;
this.isDraftMode = (this.mode === 'draft');
            await loadScript(this, CONFETTI);
            if (window.confetti) {
                window.confetti({ particleCount: 250, spread: 100, origin: { y: 0.3 } });
            }

            setTimeout(() => {
                this.navigateToBrokers();
            }, 60000);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to save bank information.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
async handleAcceptTerms() {
        this.showConfirmationModal = false;
        this.isLoading = true;
        try {
            const result = await sendOtpToEmail({ recordId: this.registrationRec.Id });
            this.otpSent = result;
            this.showOtpModal = true;
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to send OTP.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    closeOtpModal() {
        this.showOtpModal = false;
    }

    handleOtpChange(event) {
        this.enteredOtp = event.target.value;
    }
verifyOtp() {
        if (this.enteredOtp === this.otpSent) {
            this.otpVerified = true;
            this.showOtpModal = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'OTP Verified Successfully!',
                variant: 'success'
            }));
            this.submitForm(); // Continue submission
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid OTP',
                message: 'Please enter the correct 6-digit OTP.',
                variant: 'error'
            }));
        }
    }

navigateToBrokers() {
    window.location.href = 'https://modonproperties--srdev.sandbox.my.site.com/Brokers';
}

}