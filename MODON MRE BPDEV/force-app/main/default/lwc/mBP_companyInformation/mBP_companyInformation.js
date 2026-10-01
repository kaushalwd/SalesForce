import {
    LightningElement,
    api,
    track
} from 'lwc';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
    NavigationMixin
} from 'lightning/navigation';
import upsertRegistrationRecord from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import checkDuplicateValue from '@salesforce/apex/MBP_RegistrationFormController.checkDuplicateValue';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';

import {
    countryOptions,
    stateMap,
} from './countries';

export default class mbp_companyInformation extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isValidatingEmail = true;
    @track isEmailLoqateValid = true;

    @track isValidatingPhone = true;
    @track isPhoneLoqateValid = true;

    @track activeSections = ['Type of Registration', 'Company Information', 'Document Uploads'];
    @track registrationRec = {};
    @track selectedTypeOfRegistration;
    @track selectedAgentType;
    @track selectedCountry;
    @track selectedState;
    @track selectedMobCountry;
    @track mobileNum;
    @track userEmail;
    @track officeNum;
    @track isDisabled = false;
    @track registrationObj = {};
    @track uploadedFileName;
    @track isFileUploaded = false;
    @track files = [];
    @track contentVersionId = '';
    @track contentDocumentId = '';
    @track isInternational = false;
    @track initialRegistrationRec = {};
    countryOptions = countryOptions;
    @track stateOptions = [];
    @track countryOptionsList = [];
    @track stateMap = stateMap;
    @api mode;
    @api registrationStatus;

    get typeOfRegistrationOptions() {
        return [{
                label: 'UAE Broker',
                value: 'UAE Broker'
            },
            {
                label: 'International Broker',
                value: 'International Broker'
            }
        ];

    }

    get agencyTypeOptions() {
        return [{
            label: 'None',
            value: 'None'
        }, ];
    }
    get mobCountryOptions() {
        return [{
                label: '1',
                value: '1'
            },
            {
                label: '20',
                value: '20'
            },
            {
                label: '27',
                value: '27'
            },
            {
                label: '30',
                value: '30'
            },
            {
                label: '31',
                value: '31'
            },
            {
                label: '32',
                value: '32'
            },
            {
                label: '33',
                value: '33'
            },
            {
                label: '34',
                value: '34'
            },
            {
                label: '36',
                value: '36'
            },
            {
                label: '39',
                value: '39'
            },
            {
                label: '40',
                value: '40'
            },
            {
                label: '41',
                value: '41'
            },
            {
                label: '43',
                value: '43'
            },
            {
                label: '44',
                value: '44'
            },
            {
                label: '45',
                value: '45'
            },
            {
                label: '46',
                value: '46'
            },
            {
                label: '47',
                value: '47'
            },
            {
                label: '48',
                value: '48'
            },
            {
                label: '49',
                value: '49'
            },
            {
                label: '51',
                value: '51'
            },
            {
                label: '52',
                value: '52'
            },
            {
                label: '53',
                value: '53'
            },
            {
                label: '54',
                value: '54'
            },
            {
                label: '55',
                value: '55'
            },
            {
                label: '56',
                value: '56'
            },
            {
                label: '57',
                value: '57'
            },
            {
                label: '58',
                value: '58'
            },
            {
                label: '60',
                value: '60'
            },
            {
                label: '61',
                value: '61'
            },
            {
                label: '62',
                value: '62'
            },
            {
                label: '63',
                value: '63'
            },
            {
                label: '64',
                value: '64'
            },
            {
                label: '65',
                value: '65'
            },
            {
                label: '66',
                value: '66'
            },
            {
                label: '81',
                value: '81'
            },
            {
                label: '82',
                value: '82'
            },
            {
                label: '84',
                value: '84'
            },
            {
                label: '86',
                value: '86'
            },
            {
                label: '90',
                value: '90'
            },
            {
                label: '91',
                value: '91'
            },
            {
                label: '92',
                value: '92'
            },
            {
                label: '93',
                value: '93'
            },
            {
                label: '94',
                value: '94'
            },
            {
                label: '95',
                value: '95'
            },
            {
                label: '98',
                value: '98'
            },
            {
                label: '211',
                value: '211'
            },
            {
                label: '212',
                value: '212'
            },
            {
                label: '213',
                value: '213'
            },
            {
                label: '216',
                value: '216'
            },
            {
                label: '218',
                value: '218'
            },
            {
                label: '220',
                value: '220'
            },
            {
                label: '221',
                value: '221'
            },
            {
                label: '222',
                value: '222'
            },
            {
                label: '223',
                value: '223'
            },
            {
                label: '224',
                value: '224'
            },
            {
                label: '225',
                value: '225'
            },
            {
                label: '226',
                value: '226'
            },
            {
                label: '227',
                value: '227'
            },
            {
                label: '228',
                value: '228'
            },
            {
                label: '229',
                value: '229'
            },
            {
                label: '230',
                value: '230'
            },
            {
                label: '231',
                value: '231'
            },
            {
                label: '232',
                value: '232'
            },
            {
                label: '233',
                value: '233'
            },
            {
                label: '234',
                value: '234'
            },
            {
                label: '235',
                value: '235'
            },
            {
                label: '236',
                value: '236'
            },
            {
                label: '237',
                value: '237'
            },
            {
                label: '238',
                value: '238'
            },
            {
                label: '239',
                value: '239'
            },
            {
                label: '240',
                value: '240'
            },
            {
                label: '241',
                value: '241'
            },
            {
                label: '242',
                value: '242'
            },
            {
                label: '243',
                value: '243'
            },
            {
                label: '244',
                value: '244'
            },
            {
                label: '245',
                value: '245'
            },
            {
                label: '246',
                value: '246'
            },
            {
                label: '248',
                value: '248'
            },
            {
                label: '249',
                value: '249'
            },
            {
                label: '250',
                value: '250'
            },
            {
                label: '251',
                value: '251'
            },
            {
                label: '252',
                value: '252'
            },
            {
                label: '253',
                value: '253'
            },
            {
                label: '254',
                value: '254'
            },
            {
                label: '255',
                value: '255'
            },
            {
                label: '256',
                value: '256'
            },
            {
                label: '257',
                value: '257'
            },
            {
                label: '258',
                value: '258'
            },
            {
                label: '260',
                value: '260'
            },
            {
                label: '261',
                value: '261'
            },
            {
                label: '262',
                value: '262'
            },
            {
                label: '263',
                value: '263'
            },
            {
                label: '264',
                value: '264'
            },
            {
                label: '265',
                value: '265'
            },
            {
                label: '266',
                value: '266'
            },
            {
                label: '267',
                value: '267'
            },
            {
                label: '268',
                value: '268'
            },
            {
                label: '269',
                value: '269'
            },
            {
                label: '290',
                value: '290'
            },
            {
                label: '291',
                value: '291'
            },
            {
                label: '297',
                value: '297'
            },
            {
                label: '298',
                value: '298'
            },
            {
                label: '299',
                value: '299'
            },
            {
                label: '350',
                value: '350'
            },
            {
                label: '351',
                value: '351'
            },
            {
                label: '352',
                value: '352'
            },
            {
                label: '353',
                value: '353'
            },
            {
                label: '354',
                value: '354'
            },
            {
                label: '355',
                value: '355'
            },
            {
                label: '356',
                value: '356'
            },
            {
                label: '357',
                value: '357'
            },
            {
                label: '358',
                value: '358'
            },
            {
                label: '359',
                value: '359'
            },
            {
                label: '370',
                value: '370'
            },
            {
                label: '371',
                value: '371'
            },
            {
                label: '372',
                value: '372'
            },
            {
                label: '373',
                value: '373'
            },
            {
                label: '374',
                value: '374'
            },
            {
                label: '375',
                value: '375'
            },
            {
                label: '376',
                value: '376'
            },
            {
                label: '377',
                value: '377'
            },
            {
                label: '378',
                value: '378'
            },
            {
                label: '380',
                value: '380'
            },
            {
                label: '381',
                value: '381'
            },
            {
                label: '382',
                value: '382'
            },
            {
                label: '385',
                value: '385'
            },
            {
                label: '386',
                value: '386'
            },
            {
                label: '387',
                value: '387'
            },
            {
                label: '389',
                value: '389'
            },
            {
                label: '420',
                value: '420'
            },
            {
                label: '421',
                value: '421'
            },
            {
                label: '423',
                value: '423'
            },
            {
                label: '500',
                value: '500'
            },
            {
                label: '501',
                value: '501'
            },
            {
                label: '502',
                value: '502'
            },
            {
                label: '503',
                value: '503'
            },
            {
                label: '504',
                value: '504'
            },
            {
                label: '505',
                value: '505'
            },
            {
                label: '506',
                value: '506'
            },
            {
                label: '507',
                value: '507'
            },
            {
                label: '508',
                value: '508'
            },
            {
                label: '509',
                value: '509'
            },
            {
                label: '590',
                value: '590'
            },
            {
                label: '591',
                value: '591'
            },
            {
                label: '592',
                value: '592'
            },
            {
                label: '593',
                value: '593'
            },
            {
                label: '594',
                value: '594'
            },
            {
                label: '595',
                value: '595'
            },
            {
                label: '596',
                value: '596'
            },
            {
                label: '597',
                value: '597'
            },
            {
                label: '598',
                value: '598'
            },
            {
                label: '599',
                value: '599'
            },
            {
                label: '670',
                value: '670'
            },
            {
                label: '672',
                value: '672'
            },
            {
                label: '673',
                value: '673'
            },
            {
                label: '674',
                value: '674'
            },
            {
                label: '675',
                value: '675'
            },
            {
                label: '676',
                value: '676'
            },
            {
                label: '677',
                value: '677'
            },
            {
                label: '678',
                value: '678'
            },
            {
                label: '679',
                value: '679'
            },
            {
                label: '680',
                value: '680'
            },
            {
                label: '681',
                value: '681'
            },
            {
                label: '682',
                value: '682'
            },
            {
                label: '683',
                value: '683'
            },
            {
                label: '685',
                value: '685'
            },
            {
                label: '686',
                value: '686'
            },
            {
                label: '687',
                value: '687'
            },
            {
                label: '688',
                value: '688'
            },
            {
                label: '689',
                value: '689'
            },
            {
                label: '690',
                value: '690'
            },
            {
                label: '691',
                value: '691'
            },
            {
                label: '692',
                value: '692'
            },
            {
                label: '850',
                value: '850'
            },
            {
                label: '852',
                value: '852'
            },
            {
                label: '853',
                value: '853'
            },
            {
                label: '855',
                value: '855'
            },
            {
                label: '856',
                value: '856'
            },
            {
                label: '870',
                value: '870'
            },
            {
                label: '880',
                value: '880'
            },
            {
                label: '881',
                value: '881'
            },
            {
                label: '882',
                value: '882'
            },
            {
                label: '883',
                value: '883'
            },
            {
                label: '886',
                value: '886'
            },
            {
                label: '960',
                value: '960'
            },
            {
                label: '961',
                value: '961'
            },
            {
                label: '962',
                value: '962'
            },
            {
                label: '963',
                value: '963'
            },
            {
                label: '964',
                value: '964'
            },
            {
                label: '965',
                value: '965'
            },
            {
                label: '966',
                value: '966'
            },
            {
                label: '967',
                value: '967'
            },
            {
                label: '968',
                value: '968'
            },
            {
                label: '970',
                value: '970'
            },
            {
                label: '971',
                value: '971'
            },
            {
                label: '972',
                value: '972'
            },
            {
                label: '973',
                value: '973'
            },
            {
                label: '974',
                value: '974'
            },
            {
                label: '975',
                value: '975'
            },
            {
                label: '976',
                value: '976'
            },
            {
                label: '977',
                value: '977'
            },
            {
                label: '992',
                value: '992'
            },
            {
                label: '993',
                value: '993'
            },
            {
                label: '994',
                value: '994'
            },
            {
                label: '995',
                value: '995'
            },
            {
                label: '996',
                value: '996'
            },
            {
                label: '998',
                value: '998'
            }
        ];
    }
    async connectedCallback() {

        this.countryOptionsList = countryOptions;

        if (!this.recordId) {
            // New Record Defaults
            this.registrationRec = {
                Status__c: 'Draft',
                Agency_Type__c: 'None',
                Country__c: '',
                Mobile_Country_Code__c: '',
            };
            this.stateOptions = [];
            this.mobileNum = '';
            this.isInternational = false;
            this.isDisabled = false;
        } else {
            // Existing record - Fetch details
            this.registrationObj = await getRegistrationById({
                recordId: this.recordId
            });
            this.registrationRec = {
                ...this.registrationObj
            };

            // Disable fields if not in Draft
            this.isDisabled = this.registrationRec.Status__c !== 'Draft';

            // Initialize based on Type_of_Registration__c
            const typeOfReg = this.registrationRec.Type_of_Registration__c;

            if (typeOfReg === 'International Broker') {
                this.isInternational = true;
                this.stateOptions = this.stateMap[this.registrationRec.Country__c] || [];
            } else if (typeOfReg === 'UAE Broker') {
                this.isInternational = false;
                this.registrationRec.Country__c = 'United Arab Emirates';
                this.registrationRec.Mobile_Country_Code__c = '971';
                this.mobileNum = '971';
                this.stateOptions = this.stateMap['United Arab Emirates'] || [];
            }

            // Assign mobileNum in both cases
            this.mobileNum = this.registrationRec.Mobile_Country_Code__c || '';

            if(this.registrationRec.Company_Email_Address__c != null){
                this.isEmailLoqateValid = true;
            }
            if(this.mobileNum != null && this.registrationRec.Mobile_Number__c != null){
                this.isPhoneLoqateValid = true;
            }
            // Load any attached files
            await this.loadExistingFiles();
        }

        // Keep initial copy for reset if needed
        this.initialRegistrationRec = {
            ...this.registrationRec
        };
    }

get showDeleteIcon() {
    const modeLower = this.mode?.toLowerCase();

    const isDraft = modeLower === 'draft';
    const isNotSubmitted = this.registrationStatus !== 'Submitted';


    return isDraft && isNotSubmitted;
}

    handleFieldChange1(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value;

        this.registrationRec = {
            ...this.registrationRec,
            [fieldName]: value
        };

        // ===== EMAIL VALIDATION =====
        if (fieldName === 'Company_Email_Address__c') {
            this.isEmailLoqateValid = false;
            const emailInput = this.template.querySelector('[data-id="Company_Email_Address__c"]');

            if (emailInput && value) {
                const personalEmailRegex = /@(gmail\.com|hotmail\.com|yahoo\.com|yopmail\.com|aol\.com|outlook\.com|rediffmail\.com)$/i;

                if (personalEmailRegex.test(value)) {
                    emailInput.setCustomValidity('Please enter a company-specific email address (e.g., yourname@company.com).');
                    emailInput.reportValidity();
                    return;
                }

                checkDuplicateValue({
                        value: value,
                        type: 'email'
                    })
                    .then(result => {
                        let message = '';

                        if (result === 'REGISTRATION_AND_ACCOUNT') {
                            message = 'There is already a Registration and an Account with this Company Email Address.';
                        } else if (result === 'REGISTRATION') {
                            message = 'There is already a Registration with this Company Email Address.';
                        } else if (result === 'ACCOUNT') {
                            message = 'There is already an Account with this Company Email Address.';
                        }

                        emailInput.setCustomValidity(message);
                        emailInput.reportValidity();
                    })
                    .catch(error => {
                        console.error('Error checking duplicate email:', error);
                        emailInput.setCustomValidity('Error validating email. Please try again.');
                        emailInput.reportValidity();
                    });
            }
        }

        // ===== MOBILE NUMBER VALIDATION =====
        if (fieldName === 'Mobile_Number__c') {
            this.isPhoneLoqateValid = false;
            const mobileInput = this.template.querySelector('[data-id="Mobile_Number__c"]');

            if (mobileInput && value) {
                checkDuplicateValue({
                        value: value,
                        type: 'mobile'
                    })
                    .then(result => {
                        let message = '';

                        if (result === 'REGISTRATION_AND_ACCOUNT') {
                            message = 'There is already a Registration and an Account with this Mobile Number.';
                        } else if (result === 'REGISTRATION') {
                            message = 'There is already a Registration with this Mobile Number.';
                        } else if (result === 'ACCOUNT') {
                            message = 'There is already an Account with this Mobile Number.';
                        }

                        mobileInput.setCustomValidity(message);
                        mobileInput.reportValidity();
                    })
                    .catch(error => {
                        console.error('Error checking duplicate mobile number:', error);
                        mobileInput.setCustomValidity('Error validating mobile number. Please try again.');
                        mobileInput.reportValidity();
                    });
            }
        }
    }
    handleNumericInput(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        // Allow only digits
        if (value && !/^[0-9]*$/.test(value)) {
            // Reset the field value
            this.registrationRec = {
                ...this.registrationRec,
                [fieldName]: ''
            };
            // Update the UI
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.value = '';
                inputField.setCustomValidity('Please enter only numbers');
                inputField.reportValidity();
            }
        } else {
            this.registrationRec = {
                ...this.registrationRec,
                [fieldName]: value
            };
            // Clear any custom validity error
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.setCustomValidity('');
                inputField.reportValidity();
            }
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value;

        this.registrationRec = {
            ...this.registrationRec,
            [fieldName]: value
        };

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
                this.stateOptions = this.stateMap['United Arab Emirates'] || [];
            }
        } else if (fieldName === 'Country__c') {
            this.stateOptions = this.stateMap[value] || [];
            this.registrationRec.State__c = '';
        }
    }


    async loadExistingFiles() {
        try {
            const result = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'ApplicationForm'
            });
            if (result && result.file) {
                this.isFileUploaded = true;
                this.uploadedFileName = result.file.Title;
                this.contentVersionId = result.file.Id;
                this.contentDocumentId = result.file.ContentDocumentId;
            } else {
                this.isFileUploaded = false;
                this.uploadedFileName = `ApplicationForm${this.registrationRec.Name}`;
                this.filePreviewUrl = '';
                this.contentVersionId = '';
                this.contentDocumentId = '';
            }
        } catch (error) {
            console.error('Error loading existing file:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load existing file: ' + error.message,
                    variant: 'error'
                })
            );
        }
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) {
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
            return;
        }

        this.isFileUploaded = true;

        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.fileData = {
                filename: `ApplicationForm.${fileExtension}`,
                base64: base64Data
            };
            if (this.recordId) {
                // Upload file immediately if recordId exists
                const uploadResult = await uploadFile({
                    recordId: this.recordId,
                    fileName: this.fileData.filename,
                    base64Data: this.fileData.base64
                });
                await this.loadExistingFiles();

                //await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Application Form uploaded successfully!',
                        variant: 'success'
                    })
                );
            } else {
                // Store file data and trigger form submission to create record
                const recordId = await upsertRegistrationRecord({
                    registrationRec: this.registrationRec
                });
                this.registrationRec.Id = recordId;
                this.recordId = recordId;
                // Upload file immediately if recordId exists
                const uploadResult = await uploadFile({
                    recordId: this.registrationRec.Id,
                    fileName: this.fileData.filename,
                    base64Data: this.fileData.base64
                });
                await this.loadExistingFiles();

                //await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Application Form uploaded successfully!',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            this.isFileUploaded = false;
            this.fileData = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to process file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }

    async handleRemoveFile() {
        try {
            if (this.contentDocumentId) {
                await deleteFile({
                    contentDocumentId: this.contentDocumentId
                });
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Success',
                        message: `File ${this.uploadedFileName} deleted`,
                        variant: 'success'
                    },
                    bubbles: true,
                    composed: true
                }));
            }
            this.files = [];
            this.isFileUploaded = false;
            this.uploadedFileName = `ApplicationForm${this.registrationRec.Name}`;
            this.contentVersionId = '';
            this.contentDocumentId = '';
        } catch (error) {
            this.dispatchEvent(new CustomEvent('toast', {
                detail: {
                    title: 'Error',
                    message: `Failed to delete ${this.uploadedFileName}: ${error.body?.message}`,
                    variant: 'error'
                },
                bubbles: true,
                composed: true
            }));
        }
    }

    async handlePreviewFile() {
        try {
            if (!this.contentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.contentVersionId}`;


            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handlePreviewFile:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }

    get validateButtonLabel() {
        return this.isEmailLoqateValid ? 'Validated' : (this.isValidatingEmail ? 'Validating...' : 'Validate Email');
    }

    get validatePhoneButtonLabel() {
        return this.isPhoneLoqateValid ? 'Validated' : (this.isValidatingPhone ? 'Validating...' : 'Validate Phone');
    }

    async validateEmail() {
        const email = this.registrationRec.Company_Email_Address__c;

        if (!email) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please enter an email address to validate.',
                variant: 'error'
            }));
            return;
        }

        this.isValidatingEmail = true;

        try {
            await validateCompanyEmail({
                email
            });
            this.isEmailLoqateValid = true;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Valid Email',
                message: 'The email address is valid.',
                variant: 'success'
            }));
        } catch (error) {
            this.isEmailLoqateValid = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Email',
                message: error.body?.message || 'The email address is invalid.',
                variant: 'error'
            }));
        } finally {
            this.isValidatingEmail = false;
        }
    }
    async validatePhone() {
        const countryCodeElem = this.template.querySelector('[data-id="Mobile_Country_Code__c"]');
        const mobileNumberElem = this.template.querySelector('[data-id="Mobile_Number__c"]');

        const countryCode = countryCodeElem?.value?.trim();
        const mobileNumber = mobileNumberElem?.value?.trim();

        if (!countryCode || !mobileNumber) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select country code and enter mobile number.',
                variant: 'error'
            }));
            return;
        }


        const fullPhoneNumber = `+${countryCode}${mobileNumber}`;
        this.isValidatingPhone = true;
        try {
            const isValid = await validatePhone({
                phone: fullPhoneNumber
            });

            this.isPhoneLoqateValid = isValid;

            this.dispatchEvent(new ShowToastEvent({
                title: isValid ? 'Phone Validated' : 'Invalid Phone Number',
                message: isValid ? 'Phone number is valid.' : 'Phone number is invalid.',
                variant: isValid ? 'success' : 'error'
            }));
        } catch (error) {
            this.isPhoneLoqateValid = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: error.body?.message || 'Unable to validate phone number.',
                variant: 'error'
            }));
        } finally {
            this.isValidatingPhone = false;
        }
    }




    @api async submitForm() {
        try {
            // 1. Check all input fields' validity (email, phone, etc.)
            const allInputs = this.template.querySelectorAll('lightning-input');
            let isValid = true;

            allInputs.forEach(input => {
                input.reportValidity();
                if (!input.checkValidity()) {
                    isValid = false;
                }
            });

            if (!isValid) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fix the errors before proceeding.',
                    variant: 'error'
                }));
                return;
            }
            if (!this.isPhoneLoqateValid || !this.isEmailLoqateValid) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Required',
                    message: 'Please validate both email and phone number before submitting.',
                    variant: 'error'
                }));
                return;
            }

            // 2. Define required fields with their labels
            const requiredFields = [{
                    field: 'Type_of_Registration__c',
                    label: 'Type of Registration'
                },
                {
                    field: 'Country__c',
                    label: 'Country'
                },
                {
                    field: 'Mobile_Number__c',
                    label: 'Mobile Number'
                },
                {
                    field: 'Company_Email_Address__c',
                    label: 'Company Email Address'
                },
                {
                    field: 'Agency_Name__c',
                    label: 'Agency Name'
                },
                {
                    field: 'Address_Line_1__c',
                    label: 'Address Line 1'
                },
                {
                    field: 'State__c',
                    label: 'State'
                },
                {
                    field: 'Mobile_Country_Code__c',
                    label: 'Mobile Country Code'
                }
            ];

            if (!this.isInternational) {
                requiredFields.push({
                    field: 'PO_Box_Emirate__c',
                    label: 'PO box'
                });
            }

            // 3. Validate required fields manually
            const missingFields = [];
            requiredFields.forEach(({
                field,
                label
            }) => {
                if (!this.registrationRec[field]) {
                    missingFields.push(label);
                    const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                    if (inputField) {
                        inputField.setCustomValidity('This field is required');
                        inputField.reportValidity();
                    }
                }
            });

            if (missingFields.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Missing Fields',
                    message: `Please fill in the following required fields: ${missingFields.join(', ')}`,
                    variant: 'error'
                }));
                return;
            }

            // 4. Detect if any data was changed
            let hasFieldChanges = false;
            for (const key in this.registrationRec) {
                if (this.registrationRec[key] !== this.initialRegistrationRec[key]) {
                    hasFieldChanges = true;
                    break;
                }
            }

            // 5. Save record or just dispatch success if unchanged
            if (!hasFieldChanges) {
                this.dispatchEvent(new CustomEvent('success', {
                    detail: {
                        id: this.registrationRec.Id
                    },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Info',
                        message: 'No changes were made to the Company information.',
                        variant: 'info'
                    },
                    bubbles: true,
                    composed: true
                }));
            } else {
                const recordId = await upsertRegistrationRecord({
                    registrationRec: this.registrationRec
                });
                this.registrationRec.Id = recordId;
                this.dispatchEvent(new CustomEvent('success', {
                    detail: {
                        id: recordId
                    },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Success',
                        message: 'Company information saved.',
                        variant: 'success'
                    },
                    bubbles: true,
                    composed: true
                }));
                return recordId;
            }
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: error.body?.message || 'Failed to save company information.'
                },
                bubbles: true,
                composed: true
            }));

        }

    }

}