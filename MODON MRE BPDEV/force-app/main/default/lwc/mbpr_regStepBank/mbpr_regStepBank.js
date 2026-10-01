/**
 * Component Name: mbpr_regStepBank
 * Description: Step 5, Bank Information, with the consent and OTP modals
 *                  and the submission celebration.
 * Author: Aurelix IT
 *
 * Every bank field is mandatory and the IBAN Copy is required, matching UAT.
 * submitForm resolves as soon as the consent modal opens. BP-036: Accept sends
 * the OTP, Verify checks it on the server (verifyBankOtp), and the final
 * upsert runs under the step veil straight after; the success screen then
 * replaces the form and a 'submitted' event tells the workspace to drop its
 * footer. Errors are toasted rather than thrown; no 'success' event is sent.
 */
import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import { loadScript } from 'lightning/platformResourceLoader';
import CONFETTI from '@salesforce/resourceUrl/canvasConfetti';
import createRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.createRegistration';
import saveRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.saveRegistration';
import getRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.getRegistration';
import uploadFile from '@salesforce/apex/MBP_RegistrationGatewayController.uploadFile';
import sendBankOtp from '@salesforce/apex/MBP_RegistrationGatewayController.sendBankOtp';
import verifyBankOtp from '@salesforce/apex/MBP_RegistrationGatewayController.verifyBankOtp';
import getExistingFile from '@salesforce/apex/MBP_RegistrationGatewayController.getExistingFile';
import getLatestServiceRequestNumber from '@salesforce/apex/MBP_RegistrationGatewayController.getLatestServiceRequestNumber';
import deleteFile from '@salesforce/apex/MBP_RegistrationGatewayController.deleteFile';
import regFormStyles from 'c/mbpr_regFormStyles';

const BANK_BRANCH_TYPES = ['SWIFT', 'CHIPS', 'ABA', 'Other'];

/* Every bank field is mandatory. Order matters: it is the grid's visual
   order, so "focus the first error" lands on the topmost one. */
const REQUIRED_FIELDS = [
    'Bank_Name__c',
    'IBAN_Country_Bank_Code__c',
    'Account_Number__c',
    'SWIFT_Sort_Code__c',
    'Beneficiary_Name__c',
    'Bank_Branch_Name__c',
    'Bank_Branch_Type__c',
    'Bank_Country__c'
];

const REQUIRED_MESSAGE = 'Complete this field.';

const COUNTRIES = [
    'Afghanistan',
    'Åland Islands',
    'Albania',
    'Algeria',
    'American Samoa',
    'Andorra',
    'Angola',
    'Anguilla',
    'Antarctica',
    'Antigua and Barbuda',
    'Argentina',
    'Armenia',
    'Aruba',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bermuda',
    'Bhutan',
    'Bolivia',
    'Bonaire, Sint Eustatius and Saba',
    'Bosnia and Herzegovina',
    'Botswana',
    'Bouvet Island',
    'Brazil',
    'British Indian Ocean Territory',
    'Brunei Darussalam',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cabo Verde',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Cayman Islands',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Christmas Island',
    'Cocos (Keeling) Islands',
    'Colombia',
    'Comoros',
    'Congo',
    'Congo, Democratic Republic of the',
    'Cook Islands',
    'Costa Rica',
    'Côte d\'Ivoire',
    'Croatia',
    'Cuba',
    'Curaçao',
    'Cyprus',
    'Czechia',
    'Denmark',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Falkland Islands (Malvinas)',
    'Faroe Islands',
    'Fiji',
    'Finland',
    'France',
    'French Guiana',
    'French Polynesia',
    'French Southern Territories',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Gibraltar',
    'Greece',
    'Greenland',
    'Grenada',
    'Guadeloupe',
    'Guam',
    'Guatemala',
    'Guernsey',
    'Guinea',
    'Guinea-Bissau',
    'Guyana',
    'Haiti',
    'Heard Island and McDonald Islands',
    'Holy See',
    'Honduras',
    'Hong Kong',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Isle of Man',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jersey',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kiribati',
    'Korea, Democratic People\'s Republic of',
    'Korea, Republic of',
    'Kuwait',
    'Kyrgyzstan',
    'Lao People\'s Democratic Republic',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Liechtenstein',
    'Lithuania',
    'Luxembourg',
    'Macao',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Marshall Islands',
    'Martinique',
    'Mauritania',
    'Mauritius',
    'Mayotte',
    'Mexico',
    'Micronesia',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Montenegro',
    'Montserrat',
    'Morocco',
    'Mozambique',
    'Myanmar',
    'Namibia',
    'Nauru',
    'Nepal',
    'Netherlands',
    'New Caledonia',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'Niue',
    'Norfolk Island',
    'North Macedonia',
    'Northern Mariana Islands',
    'Norway',
    'Oman',
    'Pakistan',
    'Palau',
    'Palestine',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Pitcairn',
    'Poland',
    'Portugal',
    'Puerto Rico',
    'Qatar',
    'Réunion',
    'Romania',
    'Russian Federation',
    'Rwanda',
    'Saint Barthélemy',
    'Saint Helena, Ascension and Tristan da Cunha',
    'Saint Kitts and Nevis',
    'Saint Lucia',
    'Saint Martin',
    'Saint Pierre and Miquelon',
    'Saint Vincent and the Grenadines',
    'Samoa',
    'San Marino',
    'Sao Tome and Principe',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Seychelles',
    'Sierra Leone',
    'Singapore',
    'Sint Maarten',
    'Slovakia',
    'Slovenia',
    'Solomon Islands',
    'Somalia',
    'South Africa',
    'South Georgia and the South Sandwich Islands',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Svalbard and Jan Mayen',
    'Sweden',
    'Switzerland',
    'Syrian Arab Republic',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Timor-Leste',
    'Togo',
    'Tokelau',
    'Tonga',
    'Trinidad and Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Turks and Caicos Islands',
    'Tuvalu',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'United States Minor Outlying Islands',
    'Uruguay',
    'Uzbekistan',
    'Vanuatu',
    'Venezuela',
    'Viet Nam',
    'Virgin Islands, British',
    'Virgin Islands, U.S.',
    'Wallis and Futuna',
    'Western Sahara',
    'Yemen',
    'Zambia',
    'Zimbabwe',
];

export default class MbprRegStepBank extends NavigationMixin(LightningElement) {
    static stylesheets = [regFormStyles];

    @api objectApiName = 'Registration__c';
    @api recordId;
    @api sessionId;
    _ownSessionId;

    get session() {
        return this._ownSessionId || this.sessionId;
    }

    async saveRecord() {
        if (this.registrationRec.Id) {
            return await saveRegistration({ registrationRec: this.registrationRec, sessionId: this.session });
        }
        const opened = await createRegistration({ registrationRec: this.registrationRec });
        this._ownSessionId = opened.sessionId;
        return opened.registrationId;
    }
    @api registrationStatus;
    @api mode; // 'draft' or 'registration' (workspace passes 'draft')

    @track registrationRec = {};
    @track errors = {};

    registrationObj = {};

    /* BP-038 - the workspace's lock (status not Draft) or this step's own
       status check; templates keep binding disabled={isDisabled}. */
    @api locked = false;
    statusLocked = false;

    get isDisabled() {
        return Boolean(this.locked) || this.statusLocked;
    }
    isLoading = false;

    isIbanUploaded = false;
    ibanFileName;
    ibanContentVersionId = '';
    ibanContentDocumentId = '';
    ibanData = null;

    isOtherUploaded = false;
    otherFileName;
    otherContentVersionId = '';
    otherContentDocumentId = '';

    showDeleteIcon = false;

    showConfirmationModal = false;
    showOtpModal = false;
    sentToEmail;
    enteredOtp = '';
    otpVerified = false;
    // BP-036
    isVerifyingOtp = false;
    otpError = '';
    isSubmitting = false;
    showSuccess = false;

    showCelebration = false;
    isDraftMode = false;
    srNumber;

    _focusOtpOnRender = false;
    _focusErrorPending = false;

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    async connectedCallback() {
        this.isLoading = true;
        try {
            if (!this.recordId) {
                this.registrationRec.Status__c = 'Draft';
            } else {
                this.registrationObj = await getRegistration({ registrationId: this.recordId, sessionId: this.session });
                if (this.registrationObj.Status__c !== 'Draft') {
                    this.statusLocked = true;
                }
            }

            this.registrationRec = { ...this.registrationRec, ...this.registrationObj };
            this.registrationStatus = this.registrationRec.Status__c;

            const modeLower = this.mode?.toLowerCase();
            const isDraft = modeLower === 'draft';
            const isNotSubmitted = this.registrationStatus !== 'Submitted';
            this.showDeleteIcon = isDraft && isNotSubmitted;

            this.ibanFileName = 'IBAN';
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            await this.loadExistingFiles();
        } catch (error) {
            this.dispatchToast(
                'Failed to load registration data: ' + (error.body?.message || 'Unknown error'),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        if (this._focusOtpOnRender) {
            this._focusOtpOnRender = false;
            const otpInput = this.refs.otpInput;
            if (otpInput) {
                otpInput.focus();
            }
        }

        // Same pattern the company step uses: send the user to the first
        // field that failed rather than leaving them to hunt for the toast's
        // cause. Runs after the error classes have rendered.
        if (this._focusErrorPending) {
            this._focusErrorPending = false;
            const controls = this.template.querySelectorAll('[data-field]');
            for (const control of controls) {
                if (this.errors[control.dataset.field]) {
                    control.focus();
                    const target = control.closest('label') || control;
                    if (typeof target.scrollIntoView === 'function') {
                        target.scrollIntoView({ block: 'center' });
                    }
                    break;
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Options / display getters
    // ------------------------------------------------------------------

    get bankBranchTypeOptions() {
        const current = this.registrationRec.Bank_Branch_Type__c;
        return BANK_BRANCH_TYPES.map((value) => ({
            label: value,
            value,
            selected: value === current
        }));
    }

    get countryOptions() {
        const current = this.registrationRec.Bank_Country__c;
        return COUNTRIES.map((value) => ({
            label: value,
            value,
            selected: value === current
        }));
    }

    get bankNameValue() {
        return this.registrationRec.Bank_Name__c ?? '';
    }

    get ibanNumberValue() {
        return this.registrationRec.IBAN_Country_Bank_Code__c ?? '';
    }

    get accountNumberValue() {
        return this.registrationRec.Account_Number__c ?? '';
    }

    get swiftValue() {
        return this.registrationRec.SWIFT_Sort_Code__c ?? '';
    }

    get beneficiaryNameValue() {
        return this.registrationRec.Beneficiary_Name__c ?? '';
    }

    get bankBranchNameValue() {
        return this.registrationRec.Bank_Branch_Name__c ?? '';
    }

    get bankCountryValue() {
        return this.registrationRec.Bank_Country__c ?? '';
    }

    fieldClass(fieldName) {
        let cls = 'regf-field';
        if (REQUIRED_FIELDS.includes(fieldName)) {
            cls += ' regf-field--required';
        }
        if (this.errors[fieldName]) {
            cls += ' regf-field--error';
        }
        return cls;
    }

    get bankNameFieldClass() {
        return this.fieldClass('Bank_Name__c');
    }

    get bankNameError() {
        return this.errors.Bank_Name__c;
    }

    get ibanNumberFieldClass() {
        return this.fieldClass('IBAN_Country_Bank_Code__c');
    }

    get ibanNumberError() {
        return this.errors.IBAN_Country_Bank_Code__c;
    }

    get accountNumberFieldClass() {
        return this.fieldClass('Account_Number__c');
    }

    get accountNumberError() {
        return this.errors.Account_Number__c;
    }

    get swiftFieldClass() {
        return this.fieldClass('SWIFT_Sort_Code__c');
    }

    get swiftError() {
        return this.errors.SWIFT_Sort_Code__c;
    }

    get beneficiaryNameFieldClass() {
        return this.fieldClass('Beneficiary_Name__c');
    }

    get beneficiaryNameError() {
        return this.errors.Beneficiary_Name__c;
    }

    get bankBranchNameFieldClass() {
        return this.fieldClass('Bank_Branch_Name__c');
    }

    get bankBranchNameError() {
        return this.errors.Bank_Branch_Name__c;
    }

    get bankBranchTypeFieldClass() {
        return this.fieldClass('Bank_Branch_Type__c');
    }

    get bankBranchTypeError() {
        return this.errors.Bank_Branch_Type__c;
    }

    get bankCountryFieldClass() {
        return this.fieldClass('Bank_Country__c');
    }

    get bankCountryError() {
        return this.errors.Bank_Country__c;
    }

    get showIbanUpload() {
        return !this.isIbanUploaded;
    }

    get ibanUploadClass() {
        let cls = 'regf-upload regf-upload--required';
        if (this.errors.IBAN_Copy) {
            cls += ' regf-upload--error';
        }
        if (this.isDisabled) {
            cls += ' regf-upload--disabled';
        }
        return cls;
    }

    get ibanUploadError() {
        return this.errors.IBAN_Copy;
    }

    // ------------------------------------------------------------------
    // Field handling (legacy validation semantics, error-map rendering)
    // ------------------------------------------------------------------

    setFieldError(fieldName, message) {
        this.errors = { ...this.errors, [fieldName]: message };
    }

    clearFieldError(fieldName) {
        if (this.errors[fieldName]) {
            const next = { ...this.errors };
            delete next[fieldName];
            this.errors = next;
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        this.registrationRec = { ...this.registrationRec, [fieldName]: value };

        // the legacy quirk here was "emptying a field skips validation
        // and leaves any previously-set error in place". With mandatory fields
        // that reads as a stale format error on an empty box, so clearing a
        // required field now raises the required message instead.
        if (!value) {
            if (REQUIRED_FIELDS.includes(fieldName)) {
                this.setFieldError(fieldName, REQUIRED_MESSAGE);
            } else {
                this.clearFieldError(fieldName);
            }
            return;
        }

        const trimmedValue = value.replace(/\s+/g, '');

        const specialCharPattern = /[^a-zA-Z0-9]/;
        if (fieldName !== 'Bank_Country__c' && specialCharPattern.test(trimmedValue)) {
            this.setFieldError(fieldName, 'Special characters are not allowed.');
            return;
        }

        if (fieldName === 'IBAN_Country_Bank_Code__c') {
            const ibanPattern = /^AE\d{21}$/i;
            if (!ibanPattern.test(trimmedValue)) {
                this.setFieldError(
                    fieldName,
                    "Invalid IBAN format. It must start with 'AE' followed by 21 digits."
                );
                return;
            }
        }

        if (fieldName === 'Account_Number__c') {
            const accountPattern = /^\d+$/;
            if (!accountPattern.test(trimmedValue)) {
                this.setFieldError(fieldName, 'Account Number must contain only digits.');
                return;
            }
        }

        if (fieldName === 'SWIFT_Sort_Code__c') {
            const swiftPattern = /^[A-Za-z0-9]{8}([A-Za-z0-9]{3})?$/;
            if (!swiftPattern.test(trimmedValue)) {
                this.setFieldError(fieldName, 'SWIFT Code must be 8 or 11 characters (letters/digits).');
                return;
            }
        }

        this.clearFieldError(fieldName);
    }

    handleNumericInput(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        if (value && !/^[0-9]*$/.test(value)) {
            this.registrationRec = { ...this.registrationRec, [fieldName]: '' };
            event.target.value = '';
            this.setFieldError(fieldName, 'Please enter only numbers');
        } else if (!value && REQUIRED_FIELDS.includes(fieldName)) {
            this.registrationRec = { ...this.registrationRec, [fieldName]: value };
            this.setFieldError(fieldName, REQUIRED_MESSAGE);
        } else {
            this.registrationRec = { ...this.registrationRec, [fieldName]: value };
            this.clearFieldError(fieldName);
        }
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------

    async loadExistingFiles() {
        this.isLoading = true;
        try {
            const ibanResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'IBAN',
                registrationId: this.recordId,
                sessionId: this.session
            });

            if (ibanResult && ibanResult.file) {
                this.isIbanUploaded = true;
                this.ibanFileName = ibanResult.file.Title;
                this.ibanContentVersionId = ibanResult.file.Id;
                this.ibanContentDocumentId = ibanResult.file.ContentDocumentId;
            } else {
                this.isIbanUploaded = false;
                this.ibanFileName = 'IBAN';
                this.ibanContentVersionId = '';
                this.ibanContentDocumentId = '';
            }

            const otherResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'Other_',
                registrationId: this.recordId,
                sessionId: this.session
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
            this.dispatchToast('Failed to load existing files: ' + error.message, 'error');
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
            this.dispatchToast('Only .pdf and .jpg files are allowed.', 'error');
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880; // 5MB
        if (file.size > maxSize) {
            this.dispatchToast('File size exceeds 5MB limit. Please upload a smaller file.', 'error');
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

            if (!this.recordId) {
                this.registrationRec.Status__c = 'Draft';
                const recordId = await this.saveRecord();
                this.registrationRec.Id = recordId;
                this.recordId = recordId;
            }

            await uploadFile({
                recordId: this.recordId,
                fileName: this.ibanData.filename,
                base64Data: this.ibanData.base64,
                registrationId: this.recordId,
                sessionId: this.session
            });

            await this.loadExistingFiles();
            this.clearFieldError('IBAN_Copy');
            this.dispatchToast('IBAN Copy uploaded successfully!', 'success');
        } catch (error) {
            this.isIbanUploaded = false;
            this.ibanData = null;
            this.dispatchToast(
                'Failed to process IBAN Copy file: ' + (error.message || 'Unknown error'),
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
                await deleteFile({ contentDocumentId: this.ibanContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.dispatchToast(`File ${this.ibanFileName} deleted`, 'success');
            }
            this.isIbanUploaded = false;
            this.ibanFileName = 'IBAN';
            this.ibanContentDocumentId = '';
        } catch (error) {
            this.dispatchToast(`Failed to delete ${this.ibanFileName}: ${error.body?.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemoveOther() {
        this.isLoading = true;
        try {
            if (this.otherContentDocumentId) {
                await deleteFile({ contentDocumentId: this.otherContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.dispatchToast(`File ${this.otherFileName} deleted`, 'success');
            }
            this.isOtherUploaded = false;
            this.otherFileName = `Other_${this.registrationRec.Name}`;
            this.otherContentDocumentId = '';
        } catch (error) {
            this.dispatchToast(`Failed to delete ${this.otherFileName}: ${error.body?.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    openIbanPreviewPopup() {
        try {
            if (!this.ibanContentVersionId) {
                this.dispatchToast('No IBAN Copy file available to preview.', 'error');
                return;
            }

            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.ibanContentVersionId}`;

            this[NavigationMixin.Navigate](
                {
                    type: 'standard__webPage',
                    attributes: { url: fileUrl }
                },
                false
            );
        } catch (error) {
            this.dispatchToast(
                'Failed to preview IBAN Copy file: ' + (error.message || 'Unknown error'),
                'error'
            );
        }
    }

    openOtherPreviewPopup() {
        try {
            if (!this.otherContentVersionId) {
                this.dispatchToast('No Other Related Document file available to preview.', 'error');
                return;
            }

            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.otherContentVersionId}`;

            this[NavigationMixin.Navigate](
                {
                    type: 'standard__webPage',
                    attributes: { url: fileUrl }
                },
                false
            );
        } catch (error) {
            this.dispatchToast(
                'Failed to preview Other Related Document file: ' + (error.message || 'Unknown error'),
                'error'
            );
        }
    }

    // ------------------------------------------------------------------
    // Submit flow: validate -> consent -> OTP -> final upsert -> celebrate
    // ------------------------------------------------------------------

    /* Keeps any standing format error and adds a required error for every empty
       field, so both surface in one pass. Skipped while the form is disabled:
       a non-Draft registration is read-only, and a disabled control is barred
       from constraint validation anyway. */
    validateRequired() {
        if (this.isDisabled) {
            return true;
        }
        const errors = { ...this.errors };
        delete errors.IBAN_Copy;
        REQUIRED_FIELDS.forEach((fieldName) => {
            const value = this.registrationRec[fieldName];
            if (value === undefined || value === null || String(value).trim() === '') {
                errors[fieldName] = REQUIRED_MESSAGE;
            }
        });
        this.errors = errors;
        return Object.keys(errors).length === 0;
    }

    @api async submitForm() {
        if (this.isDisabled) return; // BP-038 - view only: nothing is written
        // Already submitted, or a save / verification is in flight: nothing to do.
        if (this.showSuccess || this.isSubmitting || this.isVerifyingOtp || this.showOtpModal) {
            return;
        }

        // Stage 1: every bank field is mandatory.
        if (!this.validateRequired()) {
            this._focusErrorPending = true;
            this.dispatchToast('Please correct the highlighted errors before submitting.', 'error');
            return;
        }

        // Stage 2: IBAN Copy, carrying UAT's dedicated message rather than
        // being folded into the field toast above.
        if (!this.isDisabled && !this.isIbanUploaded) {
            this.setFieldError('IBAN_Copy', 'Upload the IBAN Copy to continue.');
            this._focusErrorPending = true;
            this.dispatchToast('Please upload the IBAN Copy before submitting.', 'error');
            return;
        }
        this.clearFieldError('IBAN_Copy');

        // IBAN must carry the account number (UAE brokers) - checked before the
        // consent/OTP round trip so a bad IBAN never burns a code (BP-036).
        const iban = this.registrationRec.IBAN_Country_Bank_Code__c?.replace(/\s+/g, '') || '';
        const accountNumber = this.registrationRec.Account_Number__c?.trim() || '';
        const regType = this.registrationRec.Type_of_Registration__c?.toLowerCase();
        if (!this.isDisabled && regType === 'uae broker' && !iban.includes(accountNumber)) {
            this.dispatchToast('The IBAN must include the complete Account Number.', 'error');
            return;
        }

        // First entry opens the consent modal and resolves. Accept -> OTP ->
        // verifyOtp -> finalizeSubmission carries on from there.
        this.showConfirmationModal = true;
    }

    // OTP verified on the server: save under the step veil, then show success.
    async finalizeSubmission() {
        if (this.isSubmitting || this.showSuccess) return;
        this.isSubmitting = true;
        this.isLoading = true;
        let saved = false;
        try {
            this.registrationRec.Status__c = 'Submitted';
            const recordId = await this.saveRecord();
            saved = true;
            this.registrationRec.Id = recordId;
            this.recordId = recordId;
            this.registrationStatus = 'Submitted';
            this.statusLocked = true;
            this.isDraftMode = false;
            this.showSuccess = true;
            this.dispatchEvent(new CustomEvent('submitted', { detail: { id: recordId, sessionId: this._ownSessionId } }));
        } catch (error) {
            // Nothing was saved: let the broker fix and submit again. The code was
            // consumed server-side, so the next Submit sends a fresh one.
            this.registrationRec.Status__c = 'Draft';
            this.otpVerified = false;
            this.dispatchToast(error.body?.message || 'Failed to save bank information.', 'error');
        } finally {
            this.isLoading = false;
            this.isSubmitting = false;
        }
        if (!saved) return;

        // Post-save extras never turn a saved registration into an error.
        try {
            this.srNumber = await getLatestServiceRequestNumber({ registrationId: this.recordId, sessionId: this.session });
        } catch (error) {
            this.srNumber = '';
        }
        try {
            const prefersReducedMotion =
                window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
            if (!prefersReducedMotion) {
                await loadScript(this, CONFETTI);
                if (window.confetti) {
                    window.confetti({ particleCount: 250, spread: 100, origin: { y: 0.3 } });
                }
            }
        } catch (error) {
            // confetti is decoration only
        }
        this._redirectTimer = setTimeout(() => {
            this.navigateToBrokers();
        }, 30000);
    }

    get hasSrNumber() {
        return Boolean(this.srNumber);
    }

    handleDone() {
        if (this._redirectTimer) clearTimeout(this._redirectTimer);
        this.navigateToBrokers();
    }

    async handleAcceptTerms() {
        this.showConfirmationModal = false;
        this.isLoading = true;

        try {
            const result = await sendBankOtp({ registrationId: this.registrationRec.Id, sessionId: this.session });
            this.sentToEmail = result;
            this.enteredOtp = '';
            this.otpError = '';
            this.showOtpModal = true;
            this._focusOtpOnRender = true;
        } catch (error) {
            this.dispatchToast(error.body?.message || 'Failed to send OTP.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeOtpModal() {
        if (this.isVerifyingOtp) return;
        this.showOtpModal = false;
        this.otpError = '';
    }

    handleOtpChange(event) {
        this.enteredOtp = event.target.value;
        this.otpError = '';
    }

    handleOtpKeydown(event) {
        if (event.key === 'Enter' && !this.isVerifyDisabled) {
            event.preventDefault();
            this.verifyOtp();
        }
    }

    get isVerifyDisabled() {
        return this.isVerifyingOtp || !/^\d{6}$/.test((this.enteredOtp || '').trim());
    }

    get verifyOtpLabel() {
        return this.isVerifyingOtp ? 'Verifying' : 'Verify OTP';
    }

    // BP-036: the code is checked on the server; a wrong code stays in the modal.
    async verifyOtp() {
        const code = (this.enteredOtp || '').trim();
        if (this.isVerifyingOtp || !/^\d{6}$/.test(code)) return;
        this.isVerifyingOtp = true;
        this.otpError = '';
        let verified = false;
        try {
            verified = (await verifyBankOtp({ registrationId: this.registrationRec.Id, code, sessionId: this.session })) === true;
            if (!verified) {
                this.otpError = 'The code is incorrect. Check the email and try again.';
                return;
            }
            this.otpVerified = true;
            this.showOtpModal = false;
            this.enteredOtp = '';
        } catch (error) {
            this.otpError = error.body?.message || 'The code could not be verified. Try again.';
            return;
        } finally {
            this.isVerifyingOtp = false;
        }
        await this.finalizeSubmission();
    }

    disconnectedCallback() {
        if (this._redirectTimer) clearTimeout(this._redirectTimer);
    }

    navigateToBrokers() {
        // Was hardcoded to the PRODUCTION site, inherited verbatim from legacy
        // mbp_bankInformationform. That sent a broker who had just registered
        // in a sandbox to the production portal 30s after the celebration.
        // basePath resolves the site prefix per environment - the same fix
        // mbpr_homeGateway uses for its sign-out URL.
        window.location.href = basePath || '/';
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    dispatchToast(message, variant) {
        this.dispatchEvent(new CustomEvent('toast', { detail: { message, variant } }));
    }
}