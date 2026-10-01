/**
 * Component Name : MBP_bankinformationform
 * Description    : Handles Agency Information
 * Author         : Upendra
 *
 * CHANGE HISTORY
 * ---------------------------------------------------------------------------
 * Version | Date & Time        | Author  | Description
 * ---------------------------------------------------------------------------
 * 1.0     | 2025-08-04 12:00   | Upendra | Initial creation.
 * 1.1      |2026-12-15 01:05|    |Ashok|   Worked on mobile View css
 * 1.2      |2026-02-16 01:05|    |Upendra|   Included bank branch and branch type
 * 1.3      |2026-08-05         |         |   Made all bank fields mandatory + IBAN file check
 * ---------------------------------------------------------------------------
 */
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import upsertRegistrationRecord from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import sendOtpToEmail from '@salesforce/apex/MBP_RegistrationFormController.sendOtpToEmail';
import verifyRegistrationOtp from '@salesforce/apex/MBP_RegistrationFormController.verifyRegistrationOtp';
import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import getLatestServiceRequestNumber from '@salesforce/apex/MBP_RegistrationFormController.getLatestServiceRequestNumber';
import { loadScript } from 'lightning/platformResourceLoader';
import CONFETTI from '@salesforce/resourceUrl/canvasConfetti';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';

export default class BankInformationForm2 extends NavigationMixin(LightningElement) {
    @api mode; // 'draft' or 'registration'
    isDraftMode = false;
    @track sentToEmail;

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
    @track showDeleteIcon = false;
    @track otpSent = '';
    otpVerified = false;

    // version 1.2 starts
    bankBranchTypeOptions = [
        { label: 'SWIFT', value: 'SWIFT' },
        { label: 'CHIPS', value: 'CHIPS' },
        { label: 'ABA', value: 'ABA' },
        { label: 'Other', value: 'Other' }
    ];
    // version 1.2 ends

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

            this.registrationStatus = this.registrationRec.Status__c;

            const modeLower = this.mode?.toLowerCase();
            const isDraft = modeLower === 'draft';
            const isNotSubmitted = this.registrationStatus !== 'Submitted';
            this.showDeleteIcon = isDraft && isNotSubmitted;

            this.ibanFileName = `IBAN`;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            await this.loadExistingFiles();
            this.initialRegistrationRec = { ...this.registrationRec };
        } catch (error) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to load registration data: ' + (error.body?.message || 'Unknown error'),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value;
        const inputField = event.target;
        const regType = this.registrationRec.Type_of_Registration__c?.toLowerCase();

        this.registrationRec = { ...this.registrationRec, [fieldName]: value };

        if (!value) return;

        const trimmedValue = value.replace(/\s+/g, '');

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

        if (fieldName === 'Account_Number__c') {
            const accountPattern = /^\d+$/;
            if (!accountPattern.test(trimmedValue)) {
                inputField.setCustomValidity("Account Number must contain only digits.");
                inputField.reportValidity();
                return;
            }
        }

        if (fieldName === 'SWIFT_Sort_Code__c') {
            const swiftPattern = /^[A-Za-z0-9]{8}([A-Za-z0-9]{3})?$/;
            if (!swiftPattern.test(trimmedValue)) {
                inputField.setCustomValidity("SWIFT Code must be 8 or 11 characters (letters/digits).");
                inputField.reportValidity();
                return;
            }
        }

        const iban = this.ibanNumberTemp?.replace(/\s+/g, '') || '';
        const accountNumber = this.accountNumberTemp?.trim() || '';

        if (iban && accountNumber) {
            if (fieldName === 'IBAN_Country_Bank_Code__c' || fieldName === 'Account_Number__c') {
                let matchFound = false;

                if (iban.includes(accountNumber)) {
                    matchFound = true;
                } else {
                    for (let i = 5; i <= accountNumber.length; i++) {
                        if (iban.includes(accountNumber.slice(-i))) {
                            matchFound = true;
                            break;
                        }
                    }
                }

                if (!matchFound) {
                    inputField.setCustomValidity(
                        "Account Number must exactly match at least 5 consecutive digits within the IBAN."
                    );
                    inputField.reportValidity();
                    this.isLoading = false;
                    return;
                }
            }
        }

        inputField.setCustomValidity("");
        inputField.reportValidity();

        this.registrationRec = { ...this.registrationRec, [fieldName]: value };

        if (fieldName === 'Name') {
            this.ibanFileName = `IBAN`;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
        }
    }

    handleConfirmIbanBlur(event) {
        const value = event.target.value;
        if (value && value !== this.registrationRec.IBAN_Country_Bank_Code__c) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Confirm IBAN must match IBAN/Country Bank Code.',
                'error'
            );

            this.registrationRec = { ...this.registrationRec, Confirm_IBAN__c: null };
            const inputField = this.template.querySelector(`lightning-input[name="Confirm_IBAN__c"]`);
            if (inputField) {
                inputField.value = null;
            }
        }
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to load existing files: ' + error.message,
                'error'
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Only .pdf and .jpg files are allowed.',
                'error'
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880;
        if (file.size > maxSize) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'File size exceeds 5MB limit. Please upload a smaller file.',
                'error'
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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'IBAN Copy uploaded successfully!',
                    'success'
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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'IBAN Copy uploaded successfully!',
                    'success'
                );
            }
        } catch (error) {
            this.isIbanUploaded = false;
            this.ibanData = null;
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to process IBAN Copy file: ' + (error.message || 'Unknown error'),
                'error'
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

        const validExtensions = ['pdf', 'jpg', 'jpeg'];
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!validExtensions.includes(fileExtension)) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Only .pdf and .jpg files are allowed.',
                'error'
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880; // 5MB
        if (file.size > maxSize) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'File size exceeds 5MB limit. Please upload a smaller file.',
                'error'
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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'Other Related Document uploaded successfully!',
                    'success'
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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'Other Related Document uploaded successfully!',
                    'success'
                );
            }
        } catch (error) {
            this.isOtherUploaded = false;
            this.otherData = null;
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to process Other Related Document file: ' + (error.message || 'Unknown error'),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemoveIban() {
        this.isLoading = true;
        try {
            if (this.ibanContentDocumentId) {
                await deleteFile({ contentDocumentId: this.ibanContentDocumentId });
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    `File ${this.ibanFileName} deleted`,
                    'success'
                );
            }
            this.isIbanUploaded = false;
            this.ibanFileName = `IBAN`;
            this.ibanContentDocumentId = '';
        } catch (error) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                `Failed to delete ${this.ibanFileName}: ${error.body?.message}`,
                'error'
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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    `File ${this.otherFileName} deleted`,
                    'success'
                );
            }
            this.isOtherUploaded = false;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            this.otherContentDocumentId = '';
        } catch (error) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                `Failed to delete ${this.otherFileName}: ${error.body?.message}`,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async openIbanPreviewPopup() {
        try {
            if (!this.ibanContentVersionId) {
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'No IBAN Copy file available to preview.',
                    'error'
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to preview IBAN Copy file: ' + (error.message || 'Unknown error'),
                'error'
            );
        }
    }

    async openOtherPreviewPopup() {
        try {
            if (!this.otherContentVersionId) {
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'No Other Related Document file available to preview.',
                    'error'
                );
                return;
            }

            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.otherContentVersionId}`;

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in openOtherPreviewPopup:', JSON.stringify(error));
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Failed to preview Other Related Document file: ' + (error.message || 'Unknown error'),
                'error'
            );
        }
    }

    @api async submitForm() {
        const allInputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');

        let isFormValid = true;
        allInputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isFormValid = false;
            }
        });

        if (!isFormValid) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Please correct the highlighted errors before submitting.',
                'error'
            );
            return; // Stop here if validation fails
        }

        // IBAN Copy file is mandatory
        if (!this.isIbanUploaded) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Please upload the IBAN Copy before submitting.',
                'error'
            );
            return;
        }

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
                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'The IBAN must include the complete Account Number.',
                    'error'
                );
                this.isLoading = false;
                return;
            }

            const wasDraftMode = (this.mode === 'draft');
            this.registrationRec.Status__c = 'Submitted';

            const recordId = await upsertRegistrationRecord({
                registrationRec: this.registrationRec
            });

            this.registrationRec.Id = recordId;
            this.recordId = recordId;

            this.registrationStatus = this.registrationRec.Status__c;

            const sr = await getLatestServiceRequestNumber({ registrationId: recordId });
            this.srNumber = sr;

            this.isDraftMode = false;
            this.showCelebration = true;

            await loadScript(this, CONFETTI);
            if (window.confetti) {
                window.confetti({ particleCount: 250, spread: 100, origin: { y: 0.3 } });
            }

            setTimeout(() => {
                this.navigateToBrokers();
            }, 30000);

        } catch (error) {
            console.error('Error during form submission:', error);
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                error.body?.message || 'Failed to save bank information.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleAcceptTerms() {
        this.showConfirmationModal = false;
        this.isLoading = true;

        try {
            const result = await sendOtpToEmail({ recordId: this.registrationRec.Id });
            this.sentToEmail = result.email; // BP-036: the code stays on the server
            this.showOtpModal = true;
        } catch (error) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                error.body?.message || 'Failed to send OTP.',
                'error'
            );
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

    async verifyOtp() {
        // BP-036: verified on the server, never against a value held in the browser
        let verified = false;
        try {
            verified = (await verifyRegistrationOtp({ recordId: this.registrationRec.Id, otp: (this.enteredOtp || '').trim() })) === true;
        } catch (error) {
            verified = false;
        }
        if (verified) {
            this.otpVerified = true;
            this.showOtpModal = false;
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'OTP Verified Successfully!',
                'success'
            );
            this.submitForm();
        } else {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Please enter the correct 6-digit OTP.',
                'error',
                'Invalid OTP'
            );
        }
    }

    navigateToBrokers() {
        window.location.href = 'https://modonproperties.my.site.com/Brokers';
    }
}