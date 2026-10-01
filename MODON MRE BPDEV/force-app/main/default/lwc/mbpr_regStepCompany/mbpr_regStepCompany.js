/**********************************************************************************************************************
 * Name        : mbpr_regStepCompany
 * Description : Step 1, Company Information, of the Create Broker Request wizard.
 * Created By  : Aurelix IT
 **********************************************************************************************************************/
import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.createRegistration';
import saveRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.saveRegistration';
import getRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.getRegistration';
import uploadFile from '@salesforce/apex/MBP_RegistrationGatewayController.uploadFile';
import getExistingFile from '@salesforce/apex/MBP_RegistrationGatewayController.getExistingFile';
import checkDuplicateValue from '@salesforce/apex/MBP_RegistrationGatewayController.checkDuplicateValue';
import validateDuplicateTradeLicenseNumber from '@salesforce/apex/MBP_RegistrationGatewayController.validateDuplicateTradeLicenseNumber';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhoneNumber from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import deleteFile from '@salesforce/apex/MBP_RegistrationGatewayController.deleteFile';
import regFormStyles from 'c/mbpr_regFormStyles';
import { countryOptions, stateMap } from './countries';

const FILE_FIELD = 'CompanyProfileFile';
const FILE_NAME_PREFIX = 'Company Profile';
const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2MB
const VALID_FILE_EXTENSIONS = ['pdf', 'jpg', 'jpeg'];
const PERSONAL_EMAIL_REGEX = /@(gmail\.com|hotmail\.com|yahoo\.com|yopmail\.com|aol\.com|outlook\.com|rediffmail\.com)$/i;
const NUMERIC_ONLY_REGEX = /^[0-9]*$/;
const ALNUM_PATTERN = /^[a-zA-Z0-9]*$/;
const TRADE_LICENSE_FIELD = 'Trade_License_Number__c';
const TRADE_LICENSE_DUPLICATE_MESSAGES = {
    REGISTRATION_AND_ACCOUNT: 'There is already a Registration and an Account with this Trade License Number.',
    REGISTRATION: 'There is already a Registration with this Trade License Number.',
    ACCOUNT: 'There is already an Account with this Trade License Number.'
};

// Same values, same order as the legacy mobCountryOptions getter (207 dial codes).
const MOBILE_COUNTRY_CODES = [
    '1', '20', '27', '30', '31', '32', '33', '34', '36', '39', '40', '41', '43', '44', '45', '46', '47', '48', '49',
    '51', '52', '53', '54', '55', '56', '57', '58', '60', '61', '62', '63', '64', '65', '66', '81', '82', '84', '86',
    '90', '91', '92', '93', '94', '95', '98', '211', '212', '213', '216', '218', '220', '221', '222', '223', '224',
    '225', '226', '227', '228', '229', '230', '231', '232', '233', '234', '235', '236', '237', '238', '239', '240',
    '241', '242', '243', '244', '245', '246', '248', '249', '250', '251', '252', '253', '254', '255', '256', '257',
    '258', '260', '261', '262', '263', '264', '265', '266', '267', '268', '269', '290', '291', '297', '298', '299',
    '350', '351', '352', '353', '354', '355', '356', '357', '358', '359', '370', '371', '372', '373', '374', '375',
    '376', '377', '378', '380', '381', '382', '385', '386', '387', '389', '420', '421', '423', '500', '501', '502',
    '503', '504', '505', '506', '507', '508', '509', '590', '591', '592', '593', '594', '595', '596', '597', '598',
    '599', '670', '672', '673', '674', '675', '676', '677', '678', '679', '680', '681', '682', '683', '685', '686',
    '687', '688', '689', '690', '691', '692', '850', '852', '853', '855', '856', '870', '880', '881', '882', '883',
    '886', '960', '961', '962', '963', '964', '965', '966', '967', '968', '970', '971', '972', '973', '974', '975',
    '976', '977', '992', '993', '994', '995', '996', '998'
];

// DOM order. `missing` strings are the legacy message-when-value-missing values, verbatim
// (including the trailing space on "Please enter PO box "). Address Line 2 and Website are
// optional (the legacy `required` prop set - their aria-required was a legacy bug, not ported).
const FIELD_DEFS = [
    { name: 'Type_of_Registration__c', required: true, missing: 'Please select Type of Registration' },
    { name: 'Agency_Name__c', required: true, missing: 'Please enter Agency Name' },
    // Moved here from Step 2 (Trade License Information), which now shows it read-only.
    { name: 'Trade_License_Number__c', required: true, missing: 'Please enter Trade License Number' },
    { name: 'Company_Email_Address__c', required: true, missing: 'Please enter Company Email Address' },
    { name: 'Address_Line_1__c', required: true, missing: 'Please enter Address Line 1' },
    { name: 'Address_Line_2__c', required: false },
    { name: 'City__c', required: true, missing: 'Please enter city' },
    { name: 'PO_Box_Emirate__c', required: true, missing: 'Please enter PO box ' },
    { name: 'Country__c', required: true, missing: 'Please select Country' },
    { name: 'State__c', required: true, missing: 'Please select State' },
    { name: 'Mobile_Country_Code__c', required: true, missing: 'Please select Mobile Country Code', extra: 'regf-field--code' },
    { name: 'Mobile_Number__c', required: true, missing: 'Please enter Mobile Number' },
    { name: 'Website__c', required: false }
];

export default class MbprRegStepCompany extends NavigationMixin(LightningElement) {
    static stylesheets = [regFormStyles];

    @api objectApiName;
    @api recordId;
    @api sessionId;
    // Set when this step is the one that created the record, so its own later calls are covered.
    _ownSessionId;

    get session() {
        return this._ownSessionId || this.sessionId;
    }

    // One place that creates or saves, so the key is always dealt with the same way.
    async saveRecord() {
        if (this.registrationRec.Id) {
            return await saveRegistration({ registrationRec: this.registrationRec, sessionId: this.session });
        }
        const opened = await createRegistration({ registrationRec: this.registrationRec });
        this._ownSessionId = opened.sessionId;
        return opened.registrationId;
    }
    @api registrationStatus;
    @api mode;

    @track registrationRec = {};
    @track fieldErrors = {};
    @track stateOptions = [];

    /* BP-038 - the workspace's lock (status not Draft) or this step's own
       status check; templates keep binding disabled={isDisabled}. */
    @api locked = false;
    statusLocked = false;

    get isDisabled() {
        return Boolean(this.locked) || this.statusLocked;
    }

    get emailValidateDisabled() {
        return this.isDisabled || this.isValidatingEmail;
    }

    get phoneValidateDisabled() {
        return this.isDisabled || this.isValidatingPhone;
    }
    @track isInternational = false;
    @track mobileNum;
    @track isBusy = false;

    @track isValidatingEmail = false;
    @track isEmailLoqateValid = false;
    @track isValidatingPhone = false;
    @track isPhoneLoqateValid = false;

    @track isFileUploaded = false;
    @track uploadedFileName;
    @track contentVersionId = '';
    @track contentDocumentId = '';

    initialRegistrationRec = {};
    fileData = null;
    _focusErrorPending = false;
    _dupeCheckSeq = 0;

    // ------------------------------------------------------------------
    // Lifecycle / prefill
    // ------------------------------------------------------------------

    async connectedCallback() {
        if (!this.recordId) {
            // New record defaults (legacy parity)
            this.registrationRec = this.withDisplayDefaults({
                Status__c: 'Draft',
                Agency_Type__c: 'None',
                Country__c: '',
                Mobile_Country_Code__c: ''
            });
            this.stateOptions = [];
            this.mobileNum = '';
            this.isInternational = false;
            this.statusLocked = false;
        } else {
            this.isBusy = true;
            try {
                const registrationObj = await getRegistration({ registrationId: this.recordId, sessionId: this.session });
                this.registrationRec = this.withDisplayDefaults({ ...registrationObj });

                // Disable fields if not in Draft
                this.statusLocked = this.registrationRec.Status__c !== 'Draft';

                const typeOfReg = this.registrationRec.Type_of_Registration__c;
                if (typeOfReg === 'International Broker') {
                    this.isInternational = true;
                    this.stateOptions = stateMap[this.registrationRec.Country__c] || [];
                } else if (typeOfReg === 'UAE Broker') {
                    this.isInternational = false;
                    this.registrationRec.Country__c = 'United Arab Emirates';
                    this.registrationRec.Mobile_Country_Code__c = '971';
                    this.stateOptions = stateMap['United Arab Emirates'] || [];
                }
                this.mobileNum = this.registrationRec.Mobile_Country_Code__c || '';

                // Legacy parity: previously saved contact points count as Loqate-validated.
                if (this.registrationRec.Company_Email_Address__c != null) {
                    this.isEmailLoqateValid = true;
                }
                if (this.mobileNum != null && this.registrationRec.Mobile_Number__c != null) {
                    this.isPhoneLoqateValid = true;
                }

                await this.loadExistingFiles();
            } catch (error) {
                this.dispatchEvent(new CustomEvent('error', {
                    detail: { message: this.extractApexMessage(error, 'Unable to load the registration record.') },
                    bubbles: true,
                    composed: true
                }));
            } finally {
                this.isBusy = false;
            }
        }

        // Keep initial copy for the no-changes short-circuit on submit
        this.initialRegistrationRec = { ...this.registrationRec };
    }

    // Native inputs stringify undefined/null bindings to the literal text
    // "undefined", so every template-bound scalar must exist as ''.
    withDisplayDefaults(record) {
        const out = { ...record };
        [
            'Agency_Name__c',
            'Trade_License_Number__c',
            'Company_Email_Address__c',
            'Address_Line_1__c',
            'Address_Line_2__c',
            'City__c',
            'PO_Box_Emirate__c',
            'Mobile_Number__c',
            'Website__c'
        ].forEach((key) => {
            if (out[key] == null) {
                out[key] = '';
            }
        });
        return out;
    }

    renderedCallback() {
        // Keep native selects in lockstep with tracked state: the `selected` attribute
        // only sets defaultSelected, which cannot move a select the user has already
        // touched (e.g. "UAE Broker" force-setting Country and Country Code).
        this.template.querySelectorAll('select[data-field]').forEach((sel) => {
            const expected = this.registrationRec[sel.dataset.field];
            const target = expected == null ? '' : String(expected);
            if (sel.value !== target) {
                sel.value = target;
            }
        });

        if (!this._focusErrorPending) {
            return;
        }
        this._focusErrorPending = false;
        const controls = this.template.querySelectorAll('[data-field]');
        for (const control of controls) {
            if (this.fieldErrors[control.dataset.field]) {
                control.focus();
                break;
            }
        }
    }

    // ------------------------------------------------------------------
    // Derived view state
    // ------------------------------------------------------------------

    get typeOfRegistrationOptions() {
        return [
            { label: 'UAE Broker', value: 'UAE Broker' },
            { label: 'International Broker', value: 'International Broker' }
        ];
    }

    get typeOfRegistrationSelectOptions() {
        return this.buildSelectOptions(this.typeOfRegistrationOptions, this.registrationRec.Type_of_Registration__c);
    }

    get countrySelectOptions() {
        return this.buildSelectOptions(countryOptions, this.registrationRec.Country__c);
    }

    get stateSelectOptions() {
        return this.buildSelectOptions(this.stateOptions, this.registrationRec.State__c);
    }

    get mobCountrySelectOptions() {
        return this.buildSelectOptions(
            MOBILE_COUNTRY_CODES.map((code) => ({ label: code, value: code })),
            this.registrationRec.Mobile_Country_Code__c
        );
    }

    buildSelectOptions(options, currentValue) {
        const current = currentValue || '';
        return [
            { key: '--placeholder--', label: '--Select--', value: '', selected: current === '' },
            ...options.map((option) => ({
                key: option.value,
                label: option.label,
                value: option.value,
                selected: option.value === current
            }))
        ];
    }

    get fieldClasses() {
        const classes = {};
        FIELD_DEFS.forEach((def) => {
            let cls = 'regf-field';
            if (def.required) {
                cls += ' regf-field--required';
            }
            if (def.extra) {
                cls += ' ' + def.extra;
            }
            if (this.fieldErrors[def.name]) {
                cls += ' regf-field--error';
            }
            classes[def.name] = cls;
        });
        return classes;
    }

    get uploadClasses() {
        return 'regf-upload regf-upload--required' + (this.isDisabled ? ' regf-upload--disabled' : '');
    }

    get validateButtonLabel() {
        return this.isEmailLoqateValid ? 'Validated' : (this.isValidatingEmail ? 'Validating...' : 'Validate Email');
    }

    get validatePhoneButtonLabel() {
        return this.isPhoneLoqateValid ? 'Validated' : (this.isValidatingPhone ? 'Validating...' : 'Validate Phone');
    }

    get showDeleteIcon() {
        const modeLower = this.mode ? this.mode.toLowerCase() : undefined;
        return modeLower === 'draft' && this.registrationStatus !== 'Submitted' && !this.isDisabled;
    }

    // ------------------------------------------------------------------
    // Field change handlers
    // ------------------------------------------------------------------

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        this.registrationRec = { ...this.registrationRec, [fieldName]: value };
        this.clearFieldError(fieldName);

        if (fieldName === 'Type_of_Registration__c') {
            if (value === 'International Broker') {
                this.isInternational = true;
                this.registrationRec.Country__c = '';
                this.registrationRec.Mobile_Country_Code__c = '';
                this.mobileNum = '';
            } else if (value === 'UAE Broker') {
                this.isInternational = false;
                this.registrationRec.Country__c = 'United Arab Emirates';
                this.registrationRec.Mobile_Country_Code__c = '971';
                this.mobileNum = '971';
                this.stateOptions = stateMap['United Arab Emirates'] || [];
                this.clearFieldError('Country__c');
                this.clearFieldError('Mobile_Country_Code__c');
            }
        } else if (fieldName === 'Country__c') {
            this.stateOptions = stateMap[value] || [];
            this.registrationRec.State__c = '';
            this.clearFieldError('State__c');
        } else if (fieldName === 'Mobile_Country_Code__c') {
            this.mobileNum = value;
        }
    }

    handleEmailInput(event) {
        this.registrationRec = { ...this.registrationRec, Company_Email_Address__c: event.target.value };
        this.isEmailLoqateValid = false;
        this.clearFieldError('Company_Email_Address__c');
    }

    handleEmailChange(event) {
        const value = event.target.value;
        if (!value) {
            return;
        }

        if (PERSONAL_EMAIL_REGEX.test(value)) {
            this.setFieldError('Company_Email_Address__c', 'Please enter a company-specific email address (e.g., yourname@company.com).');
            return;
        }

        checkDuplicateValue({ value, type: 'email' })
            .then((result) => {
                if (this.registrationRec.Company_Email_Address__c !== value) {
                    return; // stale response - the user kept typing
                }
                let message = '';
                if (result === 'REGISTRATION_AND_ACCOUNT') {
                    message = 'There is already a Registration and an Account with this Company Email Address.';
                } else if (result === 'REGISTRATION') {
                    message = 'There is already a Registration with this Company Email Address.';
                } else if (result === 'ACCOUNT') {
                    message = 'There is already an Account with this Company Email Address.';
                }
                if (message) {
                    this.setFieldError('Company_Email_Address__c', message);
                } else {
                    this.clearFieldError('Company_Email_Address__c');
                }
            })
            .catch(() => {
                if (this.registrationRec.Company_Email_Address__c !== value) {
                    return;
                }
                this.setFieldError('Company_Email_Address__c', 'Error validating email. Please try again.');
            });
    }

    // Trade License Number: same checks as it had on Step 2. Only the latest duplicate check counts.
    handleTradeLicenseNumberInput(event) {
        const value = event.target.value;
        this.registrationRec = { ...this.registrationRec, [TRADE_LICENSE_FIELD]: value };

        const licenseNumber = value ? value.trim() : '';
        if (!licenseNumber) {
            this.clearFieldError(TRADE_LICENSE_FIELD);
            return;
        }
        const requestId = ++this._dupeCheckSeq;
        validateDuplicateTradeLicenseNumber({ licenseNumber })
            .then((result) => {
                if (requestId !== this._dupeCheckSeq) {
                    return;
                }
                const message = TRADE_LICENSE_DUPLICATE_MESSAGES[result];
                if (message) {
                    this.setFieldError(TRADE_LICENSE_FIELD, message);
                } else {
                    this.clearFieldError(TRADE_LICENSE_FIELD);
                }
            })
            .catch(() => {
                if (requestId !== this._dupeCheckSeq) {
                    return;
                }
                this.setFieldError(TRADE_LICENSE_FIELD, 'Error checking Trade License. Try again.');
            });
    }

    handleTradeLicenseNumberBlur(event) {
        const value = event.target.value;
        if (value && !ALNUM_PATTERN.test(value)) {
            this.registrationRec = { ...this.registrationRec, [TRADE_LICENSE_FIELD]: '' };
            event.target.value = '';
            this.setFieldError(TRADE_LICENSE_FIELD, 'Please enter only letters and numbers');
        } else {
            this.registrationRec = { ...this.registrationRec, [TRADE_LICENSE_FIELD]: value };
            // Kept from Step 2 (developer's decision, 24 Sep 2026): leaving the field clears the duplicate message.
            this.clearFieldError(TRADE_LICENSE_FIELD);
        }
    }

    handleMobileInput(event) {
        this.registrationRec = { ...this.registrationRec, Mobile_Number__c: event.target.value };
        this.isPhoneLoqateValid = false;
        this.clearFieldError('Mobile_Number__c');
    }

    handleMobileChange(event) {
        const value = event.target.value;
        if (!value) {
            return;
        }

        checkDuplicateValue({ value, type: 'mobile' })
            .then((result) => {
                if (this.registrationRec.Mobile_Number__c !== value) {
                    return; // stale response
                }
                let message = '';
                if (result === 'REGISTRATION_AND_ACCOUNT') {
                    message = 'There is already a Registration and an Account with this Mobile Number.';
                } else if (result === 'REGISTRATION') {
                    message = 'There is already a Registration with this Mobile Number.';
                } else if (result === 'ACCOUNT') {
                    message = 'There is already an Account with this Mobile Number.';
                }
                if (message) {
                    this.setFieldError('Mobile_Number__c', message);
                } else {
                    this.clearFieldError('Mobile_Number__c');
                }
            })
            .catch(() => {
                if (this.registrationRec.Mobile_Number__c !== value) {
                    return;
                }
                this.setFieldError('Mobile_Number__c', 'Error validating mobile number. Please try again.');
            });
    }

    handleMobileBlur(event) {
        const value = event.target.value;
        if (value && !NUMERIC_ONLY_REGEX.test(value)) {
            // Legacy parity: reject the whole value on blur, not just the offending characters.
            this.registrationRec = { ...this.registrationRec, Mobile_Number__c: '' };
            event.target.value = '';
            this.setFieldError('Mobile_Number__c', 'Please enter only numbers');
        } else {
            this.registrationRec = { ...this.registrationRec, Mobile_Number__c: value };
        }
    }

    // ------------------------------------------------------------------
    // Loqate validations
    // ------------------------------------------------------------------

    async handleValidateEmail() {
        const email = this.registrationRec.Company_Email_Address__c;
        if (!email) {
            this.dispatchToast('Please enter an email address to validate.', 'error');
            return;
        }

        this.isValidatingEmail = true;
        try {
            await validateCompanyEmail({ email });
            this.isEmailLoqateValid = true;
            this.dispatchToast('The email address is valid.', 'success');
        } catch (error) {
            this.isEmailLoqateValid = false;
            this.dispatchToast(this.extractApexMessage(error, 'The email address is invalid.'), 'error');
        } finally {
            this.isValidatingEmail = false;
        }
    }

    async handleValidatePhone() {
        const countryCode = (this.registrationRec.Mobile_Country_Code__c || '').trim();
        const mobileNumber = (this.registrationRec.Mobile_Number__c || '').trim();

        if (!countryCode || !mobileNumber) {
            this.dispatchToast('Please select country code and enter mobile number.', 'error');
            return;
        }

        const fullPhoneNumber = `+${countryCode}${mobileNumber}`;
        this.isValidatingPhone = true;
        try {
            const isValid = await validatePhoneNumber({ phone: fullPhoneNumber });
            this.isPhoneLoqateValid = isValid;
            this.dispatchToast(
                isValid ? 'Phone number is valid.' : 'Phone number is invalid.',
                isValid ? 'success' : 'error'
            );
        } catch (error) {
            this.isPhoneLoqateValid = false;
            this.dispatchToast(this.extractApexMessage(error, 'Unable to validate phone number.'), 'error');
        } finally {
            this.isValidatingPhone = false;
        }
    }

    // ------------------------------------------------------------------
    // File upload / preview / delete
    // ------------------------------------------------------------------

    async loadExistingFiles() {
        try {
            const result = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: FILE_NAME_PREFIX,
                registrationId: this.recordId,
                sessionId: this.session
            });

            if (result && result.file) {
                this.isFileUploaded = true;
                this.uploadedFileName = result.file.Title;
                this.contentVersionId = result.file.Id;
                this.contentDocumentId = result.file.ContentDocumentId;
            } else {
                this.isFileUploaded = false;
                this.uploadedFileName = FILE_NAME_PREFIX + (this.registrationRec.Name || '');
                this.contentVersionId = '';
                this.contentDocumentId = '';
            }
        } catch (error) {
            this.dispatchToast('Failed to load existing file: ' + ((error && error.message) || 'Unknown error'), 'error');
        }
    }

    async handleFileChange(event) {
        const input = event.target;
        const file = input.files && input.files[0];
        // Reset so re-selecting the same file after a failure re-fires the change event.
        input.value = '';
        if (!file) {
            return;
        }

        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!VALID_FILE_EXTENSIONS.includes(fileExtension)) {
            this.dispatchToast('Only .pdf and .jpg files are allowed.', 'error');
            return;
        }

        if (file.size > MAX_FILE_SIZE) {
            this.dispatchToast('File size exceeds 2MB limit. Please upload a smaller file.', 'error');
            return;
        }

        this.clearFieldError(FILE_FIELD);
        this.isBusy = true;
        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.fileData = {
                filename: `${FILE_NAME_PREFIX}.${fileExtension}`,
                base64: base64Data
            };

            if (!this.recordId) {
                // Legacy parity: create the draft record first so the file has a parent.
                const recordId = await this.saveRecord();
                this.registrationRec.Id = recordId;
                this.recordId = recordId;
            }

            await uploadFile({
                recordId: this.recordId,
                fileName: this.fileData.filename,
                base64Data: this.fileData.base64,
                registrationId: this.recordId,
                sessionId: this.session
            });
            this.isFileUploaded = true;
            await this.loadExistingFiles();
            this.dispatchToast('Company Profile Form uploaded successfully!', 'success');
        } catch (error) {
            this.isFileUploaded = false;
            this.fileData = null;
            this.dispatchToast('Failed to process file: ' + ((error && error.message) || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleRemoveFile() {
        this.isBusy = true;
        const fileName = this.uploadedFileName;
        try {
            if (this.contentDocumentId) {
                await deleteFile({ contentDocumentId: this.contentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.dispatchToast(`File ${fileName} deleted`, 'success');
            } else {
                this.dispatchToast('No file available to delete.', 'error');
            }

            this.isFileUploaded = false;
            this.uploadedFileName = FILE_NAME_PREFIX + ((this.registrationRec && this.registrationRec.Name) || '');
            this.contentVersionId = '';
            this.contentDocumentId = '';
            this.fileData = null;
        } catch (error) {
            this.dispatchToast(`Failed to delete ${fileName}: ${this.extractApexMessage(error, 'Unknown error')}`, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handlePreviewFile() {
        try {
            if (!this.contentVersionId) {
                this.dispatchToast('No file available to preview.', 'error');
                return;
            }

            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.contentVersionId}`;

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: fileUrl }
            }, false);
        } catch (error) {
            this.dispatchToast('Failed to preview file: ' + ((error && error.message) || 'Unknown error'), 'error');
        }
    }

    // ------------------------------------------------------------------
    // Submit (called by the shell's Next button)
    // ------------------------------------------------------------------

    @api async submitForm() {
        if (this.isDisabled) return; // BP-038 - view only: nothing is written
        try {
            // 1. Validate every field with the legacy rules and message strings.
            if (!this.validateAll()) {
                this._focusErrorPending = true;
                this.dispatchToast('Please fix the errors before proceeding.', 'error');
                return;
            }

            // 2. Both Loqate validations must have passed.
            if (!this.isPhoneLoqateValid || !this.isEmailLoqateValid) {
                this.dispatchToast('Please validate both email and phone number before submitting.', 'warning');
                return;
            }

            // 3. Detect whether anything actually changed.
            let hasFieldChanges = false;
            for (const key in this.registrationRec) {
                if (this.registrationRec[key] !== this.initialRegistrationRec[key]) {
                    hasFieldChanges = true;
                    break;
                }
            }

            // 4. Save, or short-circuit with success when unchanged.
            if (!hasFieldChanges) {
                this.dispatchEvent(new CustomEvent('success', {
                    detail: { id: this.registrationRec.Id },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchToast('No changes were made to the Company information.', 'info', 'Info');
                return;
            }

            const recordId = await this.saveRecord();
            this.registrationRec.Id = recordId;
            this.recordId = recordId;
            this.dispatchEvent(new CustomEvent('success', {
                detail: { id: recordId, sessionId: this._ownSessionId },
                bubbles: true,
                composed: true
            }));
            this.dispatchToast('Company information saved.', 'success', 'Success');
            return recordId;
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: this.extractApexMessage(error, 'Failed to save company information.') },
                bubbles: true,
                composed: true
            }));
        }
    }

    validateAll() {
        const rec = this.registrationRec;
        const errors = {};

        // Required fields (legacy `required` props / message-when-value-missing strings).
        FIELD_DEFS.forEach((def) => {
            if (def.required && !rec[def.name]) {
                errors[def.name] = def.missing;
            }
        });

        // Email format (legacy lightning-input type=email default type-mismatch message).
        if (!errors.Company_Email_Address__c) {
            const emailControl = this.template.querySelector('[data-field="Company_Email_Address__c"]');
            if (emailControl && emailControl.validity && emailControl.validity.typeMismatch) {
                errors.Company_Email_Address__c = 'You have entered an invalid format.';
            }
        }

        // Company-specific email rule (legacy custom validity).
        if (!errors.Company_Email_Address__c && rec.Company_Email_Address__c
            && PERSONAL_EMAIL_REGEX.test(rec.Company_Email_Address__c)) {
            errors.Company_Email_Address__c = 'Please enter a company-specific email address (e.g., yourname@company.com).';
        }

        // Digits only (legacy pattern="[0-9]*" / message-when-pattern-mismatch).
        if (!errors.Mobile_Number__c && rec.Mobile_Number__c && !NUMERIC_ONLY_REGEX.test(rec.Mobile_Number__c)) {
            errors.Mobile_Number__c = 'Please enter only numbers';
        }

        // Letters and numbers only, as on Step 2 before the field moved here.
        if (!errors[TRADE_LICENSE_FIELD] && rec[TRADE_LICENSE_FIELD] && !ALNUM_PATTERN.test(rec[TRADE_LICENSE_FIELD])) {
            errors[TRADE_LICENSE_FIELD] = 'Please enter only letters and numbers';
        }

        // Standing async duplicate-check errors still block submission (legacy custom validity).
        ['Company_Email_Address__c', 'Mobile_Number__c', TRADE_LICENSE_FIELD].forEach((name) => {
            if (!errors[name] && rec[name] && this.fieldErrors[name]) {
                errors[name] = this.fieldErrors[name];
            }
        });

        // Company Brochure/Profile is required (legacy required file input; lightning default message).
        if (!this.isFileUploaded) {
            errors[FILE_FIELD] = 'Complete this field.';
        }

        this.fieldErrors = errors;
        return Object.keys(errors).length === 0;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    setFieldError(fieldName, message) {
        this.fieldErrors = { ...this.fieldErrors, [fieldName]: message };
    }

    clearFieldError(fieldName) {
        if (this.fieldErrors[fieldName]) {
            const next = { ...this.fieldErrors };
            delete next[fieldName];
            this.fieldErrors = next;
        }
    }

    extractApexMessage(error, fallback) {
        return (error && error.body && error.body.message) || fallback;
    }

    dispatchToast(message, variant, title) {
        const detail = title ? { title, message, variant } : { message, variant };
        this.dispatchEvent(new CustomEvent('toast', {
            detail,
            bubbles: true,
            composed: true
        }));
    }
}