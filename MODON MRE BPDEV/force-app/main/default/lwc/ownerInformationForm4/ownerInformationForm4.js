import {
    LightningElement,
    track,
    api
} from 'lwc';
import getRegistrationAgents from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationAgents';
import upsertRegistrationAgentRecords from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationAgentRecords';
import deleteRegistrationAgentRecord from '@salesforce/apex/MBP_RegistrationFormController.deleteRegistrationAgentRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import checkDuplicateEmailOrMobile from '@salesforce/apex/MBP_RegistrationFormController.checkDuplicateEmailOrMobile';

import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';
import saveAgentsWithFiles from '@salesforce/apex/MBP_RegistrationFormController.saveAgentsWithFiles';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
    NavigationMixin
} from 'lightning/navigation';

export default class ownerInformationForm4 extends NavigationMixin(LightningElement) {
    @api registrationId;
    @track activeSections = ['Owner Details', 'Document Uploads'];
    @track isAddButtonDisabled = false;
    @track staffMembers = [];
    @track isDisabled = false;
    @api registrationTypeFromParent;
    @track initialStaffMembers = [];
    @track isLoading = false;
    @track registrationAgentRec = {};
    @track mobileNum;
    @track registrationObj = {};
    @track isPassportFirstPageUploaded = false;
    @track passportFirstPageFileName;
    @track passportFirstPageContentVersionId = '';
    @track passportFirstPageContentDocumentId = '';
    @track passportFirstPageData = null;
    @track isPassportSignaturePageUploaded = false;
    @track passportSignaturePageFileName;
    @track passportSignaturePageContentVersionId = '';
    @track passportSignaturePageContentDocumentId = '';
    @track passportSignaturePageData = null;
    @track isEmiratesIdFrontUploaded = false;
    @track emiratesIdFrontFileName;
    @track emiratesIdFrontContentVersionId = '';
    @track emiratesIdFrontContentDocumentId = '';
    @track emiratesIdFrontData = null;
    @track isEmiratesIdBackUploaded = false;
    @track emiratesIdBackFileName;
    @track emiratesIdBackContentVersionId = '';
    @track emiratesIdBackContentDocumentId = '';
    @track emiratesIdBackData = null;
    @track isVisaPageUploaded = false;
    @track visaPageFileName;
    @track visaPageContentVersionId = '';
    @track visaPageContentDocumentId = '';
    @track visaPageData = null;
    @track isDisabled = false;
    isPhoneLoqateValid = false;
    isEmailLoqateValid = false;
    @track isInternational = false;
    @track initialAgentRec = {};
    @track isLoading = false;
 @api mode;
    @api registrationStatus;
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
        this.isLoading = true;
        try {
            if (this.registrationId) {
                const registrationObj = await getRegistrationById({
                    recordId: this.registrationId
                });
                this.registrationTypeFromParent = registrationObj.Type_of_Registration__c?.trim()?.toLowerCase();

                if (registrationObj.Status__c !== 'Draft') {
                    this.isDisabled = true;
                }
                await this.loadRegistrationAgents();
                this.initialStaffMembers = JSON.parse(JSON.stringify(this.staffMembers));
            }
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: 'Unable to load registration data: ' + (error.body?.message || 'Unknown error')
                },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.isLoading = false;
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

    async loadRegistrationAgents() {
        this.isLoading = true;
        try {
            const agents = await getRegistrationAgents({
                registrationId: this.registrationId
            });
            let regType = '';

            if (agents.length > 0 && agents[0].registrationType) {
                regType = agents[0].registrationType?.trim()?.toLowerCase() || '';
            } else if (this.registrationTypeFromParent) {
                regType = this.registrationTypeFromParent?.trim()?.toLowerCase() || '';
            } else {
                console.warn('⚠️ No registrationType found in agents or parent');
            }

            this.showEIDFields = regType === 'uae broker';
            const staffAgents = agents.filter(agent => agent.Brokertype === 'Owner');
            if (staffAgents.length > 0) {
                this.staffMembers = staffAgents.map((agent, index) => ({
                    ...agent,
                    id: agent.sfId != null ? agent.sfId :  Date.now().toString(),
                    label: `Owner Details ${index + 1}`,
                    showRemoveIcon: staffAgents.length > 1,
                    firstname: agent.firstname,
                    lastname: agent.lastname,
                    mobileNum: agent.mobileNum,
                    email: agent.email,
                    mobile: agent.mobile,
                    passportNumber: agent.passportNumber,
                    passportExpiryDate: agent.passportExpiryDate,
                    eidNumber: agent.eidNumber,
                    eidExpiryDate: agent.eidExpiryDate,
                    Brokertype: agent.Brokertype,
                    registrationId: this.registrationId,
                    sfId: agent.sfId,
                    passportFrontbase64File: agent.passportFrontbase64File,
                    passportPreviewUrl: agent.passportFrontbase64File ? `data:application/pdf;base64,${agent.passportFrontbase64File}` : null,
                    isPassportFirstPageUploaded: !!agent.passportFrontbase64File,
                    passportFrontfileName: agent.passportFrontfileName,

                    passportFinalbase64File: agent.passportFinalbase64File,
                    passportFinalPreviewUrl: agent.passportFinalbase64File ? `data:application/pdf;base64,${agent.passportFinalbase64File}` : null,
                    isPassportSignaturePageUploaded: !!agent.passportFinalbase64File,
                    passportFinalfileName: agent.passportFinalfileName,

                    eidFrontbase64File: agent.eidFrontbase64File,
                    eidFrontPreviewUrl: agent.eidFrontbase64File ? `data:application/pdf;base64,${agent.eidFrontbase64File}` : null,
                    isEmiratesIdFrontUploaded: !!agent.eidFrontbase64File,
                    eidFrontfileName: agent.eidFrontfileName,

                    eidBackbase64File: agent.eidBackbase64File,
                    eidBackPreviewUrl: agent.eidBackbase64File ? `data:application/pdf;base64,${agent.eidBackbase64File}` : null,
                    isEmiratesIdBackUploaded: !!agent.eidBackbase64File,
                    eidBackfileName: agent.eidBackfileName,

                    visabase64File: agent.visabase64File,
                    visaPreviewUrl: agent.visabase64File ? `data:application/pdf;base64,${agent.visabase64File}` : null,
                    isVisaPageUploaded: !!agent.visabase64File,
                    visabasefileName: agent.visabasefileName,

                    tempId: agent.id,
                    isPhoneLoqateValid:(agent.mobileNum != null && agent.mobile != null) ? true :false,
                    isEmailLoqateValid: agent.email != null ? true : false,
                    validateEmail : (agent.mobileNum != null && agent.mobile != null) ? 'Validated' : 'Validate Email',
                    validatePhone : agent.email != null ? 'Validated' : 'Validate Phone'


                }));
            } else {
                const newAgent = {
                    id: Date.now().toString(), // temp ID
                    firstname: '',
                    lastname: '',
                    mobileNum: '',
                    email: '',
                    mobileCountryCode: '',
                    mobile: '',
                    passportNumber: '',
                    passportExpiryDate: '',
                    eidNumber: '',
                    eidExpiryDate: '',
                    shareholdingPercentage: '',
                    isPrimaryOwner: false,
                    passportFrontbase64File: null,
                    passportFinalbase64File: null,
                    eidFrontbase64File: null,
                    eidBackbase64File: null,
                    visabase64File: null,
                    label: `Owner Details 1`,
                    validateEmail : 'Validate Email',
                    validatePhone : 'Validate Phone'
                };
                this.staffMembers = [...this.staffMembers, newAgent];
            }
            this.updateAddButtonState();
        } catch (error) {
            console.error('Error loading Registration_Agent__c records:', JSON.stringify(error));
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: 'Unable to load Registration Agents: ' + (error.body?.message || error.message)
                },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.isLoading = false;
        }
    }
    handleValidateEmailClick(event) {
        const button = event.target;
        const ownerId = button.dataset.id;

        button.innerText = 'Validating...';
        
        button.disabled = true;

        this.validateEmail(ownerId, button);
    }

    async validateEmail(ownerId, button) {
        const selectedOwner = this.staffMembers.find(member => member.id === ownerId);

        if (!selectedOwner || !selectedOwner.email) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please enter an email address to validate.',
                variant: 'error'
            }));
            button.innerText = 'Validate Email';
            button.disabled = false;
            selectedOwner.isEmailLoqateValid = true; // or false in catch
            selectedOwner.validateEmail =  'Validate Email';
            return;
        }

        try {
            await validateCompanyEmail({
                email: selectedOwner.email
            });

            // Email is valid
            selectedOwner.isEmailLoqateValid = true;
            button.innerText = 'Validated';
            selectedOwner.validateEmail = 'Validated';

            this.dispatchEvent(new ShowToastEvent({
                title: 'Valid Email',
                message: 'The email address is valid.',
                variant: 'success'
            }));
        } catch (error) {
            // Email is invalid
            selectedOwner.isEmailLoqateValid = false;
            button.innerText = 'Validate Email';
            selectedOwner.validateEmail = 'Validate Email';

            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Email',
                message: error.body?.message || 'The email address is invalid.',
                variant: 'error'
            }));
        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers]; // Force reactivity
        }
    }
    handleValidatePhoneClick(event) {
        const button = event.target;
        const ownerId = button.dataset.id;

        button.innerText = 'Validating...';
        button.disabled = true;

        this.validatePhone(ownerId, button);
    }

    async validatePhone(ownerId, button) {
        const selectedOwner = this.staffMembers.find(member => member.id === ownerId);
        const countryCode = selectedOwner?.mobileNum?.trim();
        const mobileNumber = selectedOwner?.mobile?.trim();

        if (!countryCode || !mobileNumber) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select country code and enter mobile number.',
                variant: 'error'
            }));
            button.innerText = 'Validate Phone';
            button.disabled = false;
            selectedOwner.isPhoneLoqateValid = isValid;
            selectedOwner.validatePhone = 'Validate Phone';

            return;
        }

        const fullPhoneNumber = `+${countryCode}${mobileNumber}`;

        try {
            const isValid = await validatePhone({
                phone: fullPhoneNumber
            });

            selectedOwner.isPhoneLoqateValid = isValid;
            button.innerText = isValid ? 'Validated' : 'Validate Phone';
            selectedOwner.validatePhone = isValid ? 'Validated' : 'Validate Phone';
            this.dispatchEvent(new ShowToastEvent({
                title: isValid ? 'Phone Validated' : 'Invalid Phone Number',
                message: isValid ? 'Phone number is valid.' : 'Phone number is invalid.',
                variant: isValid ? 'success' : 'error'
            }));
        } catch (error) {
            selectedOwner.isPhoneLoqateValid = false;
            button.innerText = 'Validate Phone';
            selectedOwner.validatePhone = 'Validate Phone';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: error.body?.message || 'Unable to validate phone number.',
                variant: 'error'
            }));
        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers]; // Force re-render if needed
        }
    }



    handleFieldChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const inputField = event.target;

        if (field === 'eidNumber') {
            const isOnlyDigits = /^\d+$/.test(value); // Only digits
            const startsWith784 = value.startsWith('784');
            const isValidLength = value.length === 15;

            if (!isOnlyDigits) {
                inputField.setCustomValidity("Emirates ID must contain only numbers. No special characters or letters allowed.");
            } else if (!startsWith784 || !isValidLength) {
                inputField.setCustomValidity("Emirates ID must start with 784 and be exactly 15 digits.");
            } else {
                inputField.setCustomValidity('');
            }

            inputField.reportValidity();
        }

        if (field === 'email') {
            const duplicate = this.staffMembers.find(
                member => member.email === value && member.id !== id
            );

            if (duplicate) {
                inputField.setCustomValidity("You have already added an owner with this email.");
                inputField.reportValidity();
                return;
            }
            this.staffMembers = this.staffMembers.map(member => {
                if (member.id === id) {
                    return {
                        ...member,
                        isEmailLoqateValid: false,
                        validateEmail : 'Validate Email'
                    };
                }
                return member;
            });

            checkDuplicateEmailOrMobile({
                    value: value,
                    type: 'email'
                })
                .then(result => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Email already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Email already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Email already exists in Contact.';
                    }

                    inputField.setCustomValidity(message);
                    inputField.reportValidity();
                })
                .catch(error => {
                    console.error('Email validation error:', error);
                    inputField.setCustomValidity('Error validating email. Try again.');
                    inputField.reportValidity();
                });
        }

        if (field === 'mobile') {
            const duplicate = this.staffMembers.find(
                member => member.mobile === value && member.id !== id
            );

            if (duplicate) {
                inputField.setCustomValidity("You have already added an owner with this mobile number.");
                inputField.reportValidity();
                return;
            }

            this.staffMembers = this.staffMembers.map(member => {
                if (member.id === id) {
                    return {
                        ...member,
                        isPhoneLoqateValid: false,
                        validatePhone : 'Validate Phone'
                    };
                }
                return member;
            });
            checkDuplicateEmailOrMobile({
                    value: value,
                    type: 'mobile'
                })
                .then(result => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Mobile number already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Mobile number already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Mobile number already exists in Contact.';
                    }

                    inputField.setCustomValidity(message);
                    inputField.reportValidity();
                })
                .catch(error => {
                    console.error('Mobile validation error:', error);
                    inputField.setCustomValidity('Error validating mobile number. Try again.');
                    inputField.reportValidity();
                });
        }


        if (field === 'isPrimaryOwner') {
            const isChecked = event.target.checked;
           
            if (isChecked) {

                const alreadyPrimary = this.staffMembers.find(
                    member => member.isPrimaryOwner && member.id !== id
                );
               
                if (alreadyPrimary) {
                    inputField.checked = false;
                    inputField.setCustomValidity("Only one Primary Owner can be selected.");
                    inputField.reportValidity();
                    console.warn('Another primary already selected:', alreadyPrimary.id);
                    return;
                }
            }

            // Update state: set current one to value, all others to false
            this.staffMembers = this.staffMembers.map(member => {
                const updated = {
                    ...member,
                    isPrimaryOwner: member.id === id ? isChecked : false
                };
                return updated;
                /**if (member.id === id) {
                    return { ...member, isPrimaryOwner: value };
                }
                return member;*/
            });

            inputField.setCustomValidity('');
            inputField.reportValidity();
            //return;
        } else {
            // For other fields, update normally
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ? {
                    ...member,
                    [field]: value
                } : member
            );
        }
    }
 get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted';
    }
    handleFieldChange1(event) {
        const id = event.target.dataset.id;
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const inputField = event.target;


        if (field === 'eidNumber') {
            const isOnlyDigits = /^\d+$/.test(value); // Only digits
            const startsWith784 = value.startsWith('784');
            const isValidLength = value.length === 15;

            if (!isOnlyDigits) {
                inputField.setCustomValidity("Emirates ID must contain only numbers. No special characters or letters allowed.");
            } else if (!startsWith784 || !isValidLength) {
                inputField.setCustomValidity("Emirates ID must start with 784 and be exactly 15 digits.");
            } else {
                inputField.setCustomValidity('');
            }

            inputField.reportValidity();
        }
        if (field === 'email') {
            const duplicate = this.staffMembers.find(
                member => member.email === value && member.id !== id
            );

            if (duplicate) {
                inputField.setCustomValidity("You have already added an owner with this email.");
                inputField.reportValidity();
                return;
            }

            checkDuplicateEmailOrMobile({
                    value: value,
                    type: 'email'
                })
                .then(result => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Email already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Email already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Email already exists in Contact.';
                    }

                    inputField.setCustomValidity(message);
                    inputField.reportValidity();
                })
                .catch(error => {
                    console.error('Email validation error:', error);
                    inputField.setCustomValidity('Error validating email. Try again.');
                    inputField.reportValidity();
                });
        }

        if (field === 'mobile') {
            const duplicate = this.staffMembers.find(
                member => member.mobile === value && member.id !== id
            );

            if (duplicate) {
                inputField.setCustomValidity("You have already added an owner with this mobile number.");
                inputField.reportValidity();
                return;
            }

            checkDuplicateEmailOrMobile({
                    value: value,
                    type: 'mobile'
                })
                .then(result => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Mobile number already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Mobile number already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Mobile number already exists in Contact.';
                    }

                    inputField.setCustomValidity(message);
                    inputField.reportValidity();
                })
                .catch(error => {
                    console.error('Mobile validation error:', error);
                    inputField.setCustomValidity('Error validating mobile number. Try again.');
                    inputField.reportValidity();
                });
        }

        // Primary Owner Checkbox Logic
        if (field === 'isPrimaryOwner') {
            if (value === true) {
                const alreadyPrimary = this.staffMembers.find(
                    member => member.isPrimaryOwner && member.id !== id
                );

                if (alreadyPrimary) {
                    inputField.checked = false;
                    inputField.setCustomValidity("Only one Primary Owner can be selected.");
                    inputField.reportValidity();
                    return;
                }
            }

            // Update only the selected member's isPrimaryOwner = true, rest to false
            this.staffMembers = this.staffMembers.map(member => {
                return {
                    ...member,
                    isPrimaryOwner: member.id === id ? value : false
                };
            });

            inputField.setCustomValidity('');
            inputField.reportValidity();
            return;
        }


        this.staffMembers = this.staffMembers.map(member => {
            if (member.id === id) {
                return {
                    ...member,
                    [field]: value
                };
            }
            return member;
        });
    }

    handleAddAgent() {

        /* if (this.staffMembers.length < 5) {
             this.staffMembers = [
                 ...this.staffMembers,
                 {
                     is_Owner__c: false,
                     Registration_Name__c: this.registrationId,
                     id: this.generateUniqueId(),
                     label: `Owner Details ${this.staffMembers.length + 1}`,
                     showRemoveIcon: true,
                     Type__c :'Owner'
                 }
             ];
             this.staffMembers = this.staffMembers.map((staff, index) => ({
                 ...staff,
                 showRemoveIcon: index > 0 || this.staffMembers.length > 1
             }));
             this.updateAddButtonState();
         } else {
             this.updateAddButtonState();
             this.dispatchEvent(new CustomEvent('toast', {
                 detail: { title: 'Limit Reached', message: 'Maximum of 5 staff members allowed.', variant: 'warning' },
                 bubbles: true,
                 composed: true
             }));
         } */
        if (this.staffMembers.length < 3) {
            const uniqueId = `temp_${Date.now()}_${Math.random().toString(36).substring(2, 5)}`;
            //const uniqueId = `${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;

            const newAgent = {
                id: uniqueId,
                tempId: Date.now().toString(), // temp ID
                firstname: '',
                lastname: '',
                mobileNum: '',
                email: '',
                mobileCountryCode: '',
                mobile: '',
                passportNumber: '',
                passportExpiryDate: '',
                eidNumber: '',
                eidExpiryDate: '',
                shareholdingPercentage: '',
                isPrimaryOwner: false,
                passportFrontbase64File: null,
                passportFinalbase64File: null,
                eidFrontbase64File: null,
                eidBackbase64File: null,
                visabase64File: null,
                label: `Owner Details ${this.staffMembers.length + 1}`,
                showRemoveIcon: true,
                validateEmail : 'Validate Email',
                validatePhone : 'Validate Phone'
            };
            this.staffMembers = [...this.staffMembers, newAgent];
            this.updateAddButtonState();
        } else {
            this.updateAddButtonState();
            this.dispatchEvent(new CustomEvent('toast', {
                detail: {
                    title: 'Limit Reached',
                    message: 'Maximum of 3 Owners allowed.',
                    variant: 'warning'
                },
                bubbles: true,
                composed: true
            }));
        }
    }
    async handleRemoveAgent(event) {
        this.isLoading = true;
        const targetId = event.currentTarget.dataset.id;

        // Find the index of the staff member using the unique `id`
        const index = this.staffMembers.findIndex(member => member.id === targetId);
        if (index === -1) return;
        const member = this.staffMembers[index];
        if (member.sfId || member.Id) {
            this.isLoading = true;
            deleteRegistrationAgentRecord({
                    recordId: member.sfId || member.Id
                })
                .then(() => {
                    this.staffMembers.splice(index, 1);
                    this.staffMembers = [...this.staffMembers]; // trigger reactivity
                    this.dispatchEvent(new CustomEvent('toast', {
                        detail: {
                            title: 'Success',
                            message: 'Owner deleted successfully from database.',
                            variant: 'success'
                        },
                        bubbles: true,
                        composed: true
                    }));
                })
                .catch(error => {
                    this.isLoading = false;
                    console.error('Deletion error:', error);
                    this.dispatchEvent(new CustomEvent('toast', {
                        detail: {
                            title: 'Error',
                            message: error.body?.message || 'Failed to delete owner from database.',
                            variant: 'error'
                        },
                        bubbles: true,
                        composed: true
                    }));
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            this.staffMembers.splice(index, 1);
            this.staffMembers = [...this.staffMembers];
            this.isLoading = false;
        }
        /*try {
            const staffToRemove = this.staffMembers.find(staff => staff.id === staffId);
            if (staffToRemove && staffToRemove.Id) {
                await deleteRegistrationAgentRecord({ recordId: staffToRemove.Id });
            }

            // Remove the staff member and update labels/icons
            let updatedStaffMembers = this.staffMembers
                .filter(staff => staff.id !== staffId)
                .map((staff, index) => ({
                    ...staff,
                    label: `Staff Information ${index + 1}`,
                    showRemoveIcon: index > 0 || this.staffMembers.length > 1
                }));

            // If no staff members remain, initialize with a new form
            if (updatedStaffMembers.length === 0) {
                updatedStaffMembers = [{
                    is_Owner__c: false,
                    Registration_Name__c: this.registrationId,
                    id: this.generateUniqueId(),
                    label: 'Staff Information 1',
                    showRemoveIcon: false
                }];
            }

            this.staffMembers = updatedStaffMembers;
            this.updateAddButtonState();

            // Show success toast
            this.dispatchEvent(new CustomEvent('toast', {
                detail: { title: 'Success', message: 'Staff member removed.', variant: 'success' },
                bubbles: true,
                composed: true
            }));
        } catch (error) {
            console.error('Error removing staff member:', JSON.stringify(error));
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: error.body?.message || 'Failed to remove staff member.' },
                bubbles: true,
                composed: true
            }));
        }finally {
            this.isLoading = false;
        } */
    }

    /*   handleRemoveAgent(event) {
           const memberId = event.currentTarget.dataset.id;
           this.staffMembers = this.staffMembers.filter(member => member.id !== memberId);
       } */

    @api async handleSubmit() {
        this.isLoading = true;
        try {
           const dataToSend = this.staffMembers.map(member => ({
    firstname: member.firstname,
    lastname: member.lastname,
    mobileNum: member.mobileNum,
    email: member.email,
    mobile: member.mobile,
    passportNumber: member.passportNumber,
    passportExpiryDate: member.passportExpiryDate,
    eidNumber: member.eidNumber || null,
    eidExpiryDate: member.eidExpiryDate || null,
    Brokertype: 'Owner',
    registrationId: this.registrationId,

    // Only include file data if it has meaningful content
    passportFrontbase64File: member.passportFrontbase64File?.trim() ? member.passportFrontbase64File : null,
    passportFrontfileName: member.passportFrontfileName?.trim() ? member.passportFrontfileName : null,

    passportFinalbase64File: member.passportFinalbase64File?.trim() ? member.passportFinalbase64File : null,
    passportFinalfileName: member.passportFinalfileName?.trim() ? member.passportFinalfileName : null,

    eidFrontbase64File: member.eidFrontbase64File?.trim() ? member.eidFrontbase64File : null,
    eidFrontfileName: member.eidFrontfileName?.trim() ? member.eidFrontfileName : null,

    eidBackbase64File: member.eidBackbase64File?.trim() ? member.eidBackbase64File : null,
    eidBackfileName: member.eidBackfileName?.trim() ? member.eidBackfileName : null,

    visabase64File: member.visabase64File?.trim() ? member.visabase64File : null,
    visabasefileName: member.visabasefileName?.trim() ? member.visabasefileName : null,

    sfId: member.sfId,
    tempId: member.tempId,
    shareholdingPercentage: member.shareholdingPercentage,
    isPrimaryOwner: member.isPrimaryOwner,
}));

            const result = await saveAgentsWithFiles({
                agentDataList: dataToSend
            });
            JSON.stringify('result::' + result);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `Saved ${result.length} agent(s) successfully.`,
                    variant: 'success'
                })
            );
            this.staffMembers = []; // clear form
        } catch (error) {
            console.error('Error occurred:', error);
            console.error('Error stringified:', JSON.stringify(error));
            let message = 'Unknown error';
            if (error?.body?.message) {
                message = error.body.message;
            } else if (error?.message) {
                message = error.message;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Something went wrong',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }

        /* try {
             const records = this.staffMembers.map(staff => {
                 // Create a copy of the staff object and remove non-schema fields
                 const record = { ...staff };
                 delete record.id;
                 delete record.label;
                 delete record.showRemoveIcon;
                 // Ensure Id is only included for existing records
                 if (!record.Id) {
                     delete record.Id;
                 }
                 return record;
             });

             // Check for field changes
             let hasChanges = false;

             // Check if the number of staff members has changed
             if (this.staffMembers.length !== this.initialStaffMembers.length) {
                 hasChanges = true;
             } else {
                 // Compare each staff member with its initial state
                 for (let i = 0; i < this.staffMembers.length; i++) {
                     const current = this.staffMembers[i];
                     const initial = this.initialStaffMembers.find(init => init.id === current.id);
                     if (!initial) {
                         // New staff member added
                         hasChanges = true;
                         break;
                     }
                     // Compare fields
                     for (const key in current) {
                         if (key !== 'id' && key !== 'label' && key !== 'showRemoveIcon') {
                             if (current[key] !== initial[key]) {
                                 hasChanges = true;
                                 break;
                             }
                         }
                     }
                     if (hasChanges) break;
                 }
             }

             if (!hasChanges) {
                 const recordIds = this.staffMembers.map(staff => staff.Id).filter(id => id);
                 this.dispatchEvent(new CustomEvent('success', {
                     detail: { ids: recordIds },
                     bubbles: true,
                     composed: true
                 }));
                 this.dispatchEvent(new CustomEvent('toast', {
                     detail: { title: 'Info', message: 'No changes were made to the Staff information.', variant: 'info' },
                     bubbles: true,
                     composed: true
                 }));
                 return recordIds;
             } else {
                 const recordIds = await upsertRegistrationAgentRecords({ registrationAgentRecs: records });
                 this.staffMembers = this.staffMembers.map((staff, index) => ({
                     ...staff,
                     Id: recordIds[index]
                 }));
                 this.dispatchEvent(new CustomEvent('success', {
                     detail: { ids: recordIds },
                     bubbles: true,
                     composed: true
                 }));
                 this.dispatchEvent(new CustomEvent('toast', {
                     detail: { title: 'Success', message: 'Staff information saved.', variant: 'success' },
                     bubbles: true,
                     composed: true
                 }));
                 return recordIds;
             }
         } catch (error) {
             console.error('Error in submitForm:', JSON.stringify(error));
             this.dispatchEvent(new CustomEvent('error', {
                 detail: { message: error.body?.message || 'Failed to save staff information.' },
                 bubbles: true,
                 composed: true
             }));
             throw error;
         }finally {
             this.isLoading = false;
         } */
    }

    @api async submitForm() {
        this.isLoading = true;
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
            const invalidStaff = this.staffMembers.filter(
                member => !member.isPhoneLoqateValid || !member.isEmailLoqateValid
            );

            if (invalidStaff.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Required',
                    message: 'Please validate both Email and Mobile Number.',
                    variant: 'error'
                }));
                this.isLoading = false;
                return;
            }
            const requiredFields = [

                {
                    field: 'firstname',
                    label: 'First Name'
                },
                {
                    field: 'lastname',
                    label: 'Last Name'
                },
                {
                    field: 'mobile',
                    label: 'Mobile'
                },
                {
                    field: 'mobileNum',
                    label: 'Mobile country Code'
                },
                {
                    field: 'email',
                    label: 'Email'
                },
                {
                    field: 'passportNumber',
                    label: 'Passport Number'
                },
                {
                    field: 'passportExpiryDate',
                    label: 'Passport Expiry Date'
                },
                //{ field: 'eidNumber', label: 'Emirates ID Number' },
                //{ field: 'eidExpiryDate', label: 'EID Expiry Date' },
                {
                    field: 'shareholdingPercentage',
                    label: 'Share holding percentage'
                },
            ];

            if (this.showEIDFields) {
                requiredFields.push({
                    field: 'eidNumber',
                    label: 'Emirates ID Number'
                }, {
                    field: 'eidExpiryDate',
                    label: 'EID Expiry Date'
                });
            }
            const missingFields = [];
            this.staffMembers.forEach((member, idx) => {
                const ownerLabel = `Owner ${idx + 1}`;

                requiredFields.forEach(({
                    field,
                    label
                }) => {
                    if (!member[field]) {
                        missingFields.push(label);
                        const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                        if (inputField) {
                            inputField.setCustomValidity('This field is required');
                            inputField.reportValidity();
                        }
                    }

                    if (field == 'eidNumber') {
                        const eid = member[field];
                        const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                        if (eid.length != 15 && !eid.startsWith('784')) {
                            const errorMessage = `EID must be 15 digits and must starts with 784`;

                            if (inputField) {
                                inputField.setCustomValidity(errorMessage);
                                inputField.reportValidity();
                            }
                        }
                    }
                });
             if (!member.isPassportFirstPageUploaded) {
                    missingFields.push('Passport First Page ' + ownerLabel);
                }

                if (!member.isPassportSignaturePageUploaded) {
                    missingFields.push('Passport Signature Page ' + ownerLabel);
                }
                if (this.showEIDFields) {
                    if (!member.isEmiratesIdFrontUploaded) {
                        missingFields.push('Emirates ID Front ' + ownerLabel);
                    }
                    if (!member.isEmiratesIdBackUploaded) {
                        missingFields.push('Emirates ID Back ' + ownerLabel);
                    }
                }

            });

            if (missingFields.length > 0) {
                const errorMessage = `Please fill in the following required fields: ${missingFields.join(', ')}`;
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Error',
                        message: errorMessage,
                        variant: 'error'
                    },
                    bubbles: true,
                    composed: true
                }));
                this.isLoading = false;
                return;
            }
            const hasPrimaryOwner = this.staffMembers.some(member => member.isPrimaryOwner === true);

            if (!hasPrimaryOwner) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select at least one Primary Owner.',
                    variant: 'error'
                }));
                this.isLoading = false;
                return;
            }

            const invalidShareholders = this.staffMembers.filter(member => {
                const share = parseFloat(member.shareholdingPercentage);
                return isNaN(share) || share <= 0;
            });

            if (invalidShareholders.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Each owner’s Shareholding must be greater than 0.',
                    variant: 'error'
                }));
                this.isLoading = false;
                return;
            }

            // 🔄 Rule: Total shareholding must be exactly 100%
            const totalShare = this.staffMembers.reduce((sum, m) => {
                return sum + (parseFloat(m.shareholdingPercentage) || 0);
            }, 0);

            if (totalShare !== 100) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: `The total Shareholding percentage must equal 100%. Currently it's ${totalShare.toFixed(2)}%.`,
                    variant: 'error'
                }));
                this.isLoading = false;
                return;
            }

            const records = this.staffMembers.map(staff => {
                // Create a copy of the staff object and remove non-schema fields
                const record = {
                    ...staff
                };
                delete record.id;
                delete record.label;
                delete record.showRemoveIcon;
                // Ensure Id is only included for existing records
                if (!record.Id) {
                    delete record.Id;
                }
                return record;
            });

            // Check for field changes
            let hasChanges = false;

            // Check if the number of staff members has changed
            if (this.staffMembers.length !== this.initialStaffMembers.length) {
                hasChanges = true;
            } else {
                // Compare each staff member with its initial state
                for (let i = 0; i < this.staffMembers.length; i++) {
                    const current = this.staffMembers[i];
                    const initial = this.initialStaffMembers.find(init => init.id === current.id);
                    if (!initial) {
                        // New staff member added
                        hasChanges = true;
                        break;
                    }
                    // Compare fields
                    for (const key in current) {
                        if (key !== 'id' && key !== 'label' && key !== 'showRemoveIcon') {
                            if (current[key] !== initial[key]) {
                                hasChanges = true;
                                break;
                            }
                        }
                    }
                    if (hasChanges) break;
                }
            }

            if (!hasChanges) {
                const recordIds = this.staffMembers.map(staff => staff.Id).filter(id => id);
                this.dispatchEvent(new CustomEvent('success', {
                    detail: {
                        ids: recordIds
                    },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Info',
                        message: 'No changes were made to the Owner information.',
                        variant: 'info'
                    },
                    bubbles: true,
                    composed: true
                }));
                return recordIds;
            } else {
                const dataToSend = this.staffMembers.map(member => ({
    firstname: member.firstname,
    lastname: member.lastname,
    mobileNum: member.mobileNum,
    email: member.email,
    mobile: member.mobile,
    passportNumber: member.passportNumber,
    passportExpiryDate: member.passportExpiryDate,
    eidNumber: member.eidNumber || null,
    eidExpiryDate: member.eidExpiryDate || null,
    Brokertype: 'Owner',
    registrationId: this.registrationId,

    // Only include file data if it has meaningful content
    passportFrontbase64File: member.passportFrontbase64File?.trim() ? member.passportFrontbase64File : null,
    passportFrontfileName: member.passportFrontfileName?.trim() ? member.passportFrontfileName : null,

    passportFinalbase64File: member.passportFinalbase64File?.trim() ? member.passportFinalbase64File : null,
    passportFinalfileName: member.passportFinalfileName?.trim() ? member.passportFinalfileName : null,

    eidFrontbase64File: member.eidFrontbase64File?.trim() ? member.eidFrontbase64File : null,
    eidFrontfileName: member.eidFrontfileName?.trim() ? member.eidFrontfileName : null,

    eidBackbase64File: member.eidBackbase64File?.trim() ? member.eidBackbase64File : null,
    eidBackfileName: member.eidBackfileName?.trim() ? member.eidBackfileName : null,

    visabase64File: member.visabase64File?.trim() ? member.visabase64File : null,
    visabasefileName: member.visabasefileName?.trim() ? member.visabasefileName : null,

    sfId: member.sfId,
    tempId: member.tempId,
    shareholdingPercentage: member.shareholdingPercentage,
    isPrimaryOwner: member.isPrimaryOwner,
}));

                const recordIds = await saveAgentsWithFiles({
                    agentDataList: dataToSend
                });;
                this.staffMembers = this.staffMembers.map(m => {
                    const realId = recordIds[m.tempId];
                    return {
                        ...m,
                        sfId: realId || m.sfId,
                        Id: realId || m.Id
                    };
                });
                this.dispatchEvent(new CustomEvent('success', {
                    detail: {
                        ids: recordIds
                    },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: {
                        title: 'Success',
                        message: 'Owner details saved.',
                        variant: 'success'
                    },
                    bubbles: true,
                    composed: true
                }));
                return recordIds;
            }
        } catch (error) {
            console.error('Error in submitForm:', JSON.stringify(error));
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: error.body?.message || 'Failed to save owner information.'
                },
                bubbles: true,
                composed: true
            }));
            throw error;
        } finally {
            this.isLoading = false;
        }
    }

    updateAddButtonState() {
        this.isAddButtonDisabled = this.staffMembers.length >= 3;
    }

    generateUniqueId() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0,
                v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }
    handlePassportFrontFileChange(event) {
        const id = event.target.dataset.id;
        const file = event.target.files[0];
        const labelName = event.target.dataset.label;

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

        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];

                const mimeType = file.type || 'application/pdf';
                //const previewUrl = reader.result;
                const previewUrl = `data:application/pdf;base64,${base64}`;

                if (labelName == 'Passport_First_Page') {
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            passportFrontbase64File: base64,
                            passportPreviewUrl: previewUrl,
                            isPassportFirstPageUploaded: true,
                            passportFrontfileName: `Passport_First_Page.${fileExtension}`
                        } : member
                    );
                };
                reader.readAsDataURL(file);
            }
        }
    }
    handleFileChange(event) {
        const id = event.target.dataset.id;
        const file = event.target.files[0];
        const labelName = event.target.dataset.label;



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
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];

                //const mimeType = file.type || 'application/pdf'; 
                //const previewUrl = reader.result;
                //const previewUrl = `data:application/pdf;base64,${base64}`;
                //const mimeType = file.type || (fileExtension === 'pdf' ? 'application/pdf' : `image/${fileExtension}`);
                //const previewUrl = `data:${mimeType};base64,${base64}`;
                let mimeType;
if (fileExtension === 'pdf') {
    mimeType = 'application/pdf';
} else if (fileExtension === 'jpg' || fileExtension === 'jpeg') {
    mimeType = 'image/jpeg';
} else {
    mimeType = file.type || `application/octet-stream`;
}

                const byteCharacters = atob(reader.result.split(',')[1]);
                const byteNumbers = new Array(byteCharacters.length);
                for (let i = 0; i < byteCharacters.length; i++) {
                    byteNumbers[i] = byteCharacters.charCodeAt(i);
                }
                const byteArray = new Uint8Array(byteNumbers);
                const blob = new Blob([byteArray], {
                    type: mimeType
                });
                const previewUrl = URL.createObjectURL(blob);
                if (labelName == 'Passport_First_Page') {
                    //this.passportFirstPageContentVersionId = file.Id;
             
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            passportFrontbase64File: base64,
                            passportPreviewUrl: previewUrl,
                            isPassportFirstPageUploaded: true,
                            passportFrontfileName: file.name
                        } : member
                    );
                } else if (labelName == 'Passport_Signature_Page') {
             
                    //this.passportSignaturePageContentVersionId = file.contentVersionId;
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            passportFinalbase64File: base64,
                            passportFinalPreviewUrl: previewUrl,
                            isPassportSignaturePageUploaded: true,
                            passportFinalfileName: file.name
                        } : member
                    );
                } else if (labelName == 'Emirates_ID_Front') {
                    //this.emiratesIdFrontContentVersionId = file.contentVersionId;
             
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            eidFrontbase64File: base64,
                            eidFrontPreviewUrl: previewUrl,
                            isEmiratesIdFrontUploaded: true,
                            eidFrontfileName:file.name
                        } : member
                    );
                } else if (labelName == 'Emirates_ID_Back') {
                    //this.emiratesIdBackContentVersionId = file.contentVersionId;
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            eidBackbase64File: base64,
                            eidBackPreviewUrl: previewUrl,
                            isEmiratesIdBackUploaded: true,
                            eidBackfileName: file.name
                        } : member
                    );
                } else if (labelName == 'Visa_Page') {
                    //this.visaPageContentVersionId = file.contentVersionId;
                    this.staffMembers = this.staffMembers.map(member =>
                        member.id === id ? {
                            ...member,
                            visabase64File: base64,
                            visaPreviewUrl: previewUrl,
                            isVisaPageUploaded: true,
                            visabasefileName: file.name
                        } : member
                    );
                }
            };
            reader.readAsDataURL(file);
        }
    }
handlePreview(event) {
    const id = event.currentTarget.dataset.id;
    const labelName = event.target.dataset.label;


    const member = this.staffMembers.find(m => m.id === id);

    let base64Data = '';

    if (member) {

        if (labelName === 'Passport_First_Page') {
            base64Data = member.passportPreviewUrl;
        } else if (labelName === 'Passport_Signature_Page') {
            base64Data = member.passportFinalPreviewUrl;
        } else if (labelName === 'Emirates_ID_Front') {
            base64Data = member.eidFrontPreviewUrl;
        } else if (labelName === 'Emirates_ID_Back') {
            base64Data = member.eidBackPreviewUrl;
        } else if (labelName === 'Visa_Page') {
            base64Data = member.visaPreviewUrl;
        } else if (labelName === 'POA_Document') {
            base64Data = member.poaPreviewUrl;
        } else {
            console.warn('❌ Unknown label:', labelName);
        }
    } else {
        console.warn('❌ No member found with ID:', id);
    }

    if (base64Data && base64Data.startsWith('data:')) {
        const base64Body = base64Data.split(',')[1];

        // MIME type detection based on base64 content
        const getRealMimeType = (data) => {
            const header = data.substring(0, 20);
            if (header.startsWith('/9j/')) return 'image/jpeg';
            if (header.startsWith('iVBOR')) return 'image/png';
            if (header.startsWith('JVBER')) return 'application/pdf';
            return 'application/octet-stream';
        };

        const realMimeType = getRealMimeType(base64Body);


        try {
            const byteCharacters = atob(base64Body);
            const byteNumbers = Array.from(byteCharacters, c => c.charCodeAt(0));
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: realMimeType });
            const blobUrl = URL.createObjectURL(blob);

            window.open(blobUrl, '_blank');
        } catch (error) {
            console.error('❌ Failed to decode and preview file:', error);
        }
    } else {
        console.warn('❌ Invalid or missing base64 data for:', labelName);
    }
}

    /**async loadExistingFiles() {
    this.isLoading = true;
    try {
        // Load Passport First Page file
        const passportFirstPageResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'Passport_First_Page'
        });

        if (passportFirstPageResult && passportFirstPageResult.file) {
            this.isPassportFirstPageUploaded = true;
            this.passportFirstPageFileName = passportFirstPageResult.file.Title;
            this.passportFirstPageContentVersionId = passportFirstPageResult.file.Id;
            this.passportFirstPageContentDocumentId = passportFirstPageResult.file.ContentDocumentId;
        } else {
            this.isPassportFirstPageUploaded = false;
            this.passportFirstPageFileName = `Passport_First_Page${this.registrationAgentRec.Name}`;
            this.passportFirstPageContentVersionId = '';
            this.passportFirstPageContentDocumentId = '';
        }


        /** 
        // Load MOA file
        const moaResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'MOA_'
        });

        if (moaResult && moaResult.file) {
            this.isMoaUploaded = true;
            this.moaFileName = moaResult.file.Title;
            this.moaContentVersionId = moaResult.file.Id;
            this.moaContentDocumentId = moaResult.file.ContentDocumentId;
        } else {
            this.isMoaUploaded = false;
            this.moaFileName = `MOA_${this.registrationRec.Name}`;
            this.moaContentVersionId = '';
            this.moaContentDocumentId = '';
        }

        // Load ADM/RERA file
        const admResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'ADM_RERA_'
        });

        if (admResult && admResult.file) {
            this.isAdmReraUploaded = true;
            this.admReraFileName = admResult.file.Title;
            this.admReraContentVersionId = admResult.file.Id;
            this.admReraContentDocumentId = admResult.file.ContentDocumentId;
        } else {
            this.isAdmReraUploaded = false;
            this.admReraFileName = `ADM_RERA_${this.registrationRec.Name}`;
            this.admReraContentVersionId = '';
            this.admReraContentDocumentId = '';
        }

        // Load VAT Certificate file
        const vatResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'VAT_'
        });

        if (vatResult && vatResult.file) {
            this.isVatUploaded = true;
            this.vatFileName = vatResult.file.Title;
            this.vatContentVersionId = vatResult.file.Id;
            this.vatContentDocumentId = vatResult.file.ContentDocumentId;
            this.showVatFileUpload = true;
        } else {
            this.isVatUploaded = false;
            this.vatFileName = `VAT_${this.registrationRec.Name}`;
            this.vatContentVersionId = '';
            this.vatContentDocumentId = '';
            this.showVatFileUpload = false;
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
}*/

    /** async openpassportFirstPagePreviewPopup() {
        try {
            //await this.loadExistingFiles();
            //loadExistingFiles();
            if (!this.passportFirstPageContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Passport First Page file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.passportFirstPageContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handlePassportFirstPagePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Passport First Page file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }*/

    /**async openpassportSignaturePagePreviewPopup() {
        try {
            if (!this.passportSignaturePageContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Passport Signature Page file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.passportSignaturePageContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handlePassportSignaturePagePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Passport Signature Page file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }*/

    /**async openEmiratesIDFrontPagePreviewPopup() {
        try {
            if (!this.emiratesIdFrontContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Emirates ID Front Page file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.emiratesIdFrontContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handleEmiratesIDFrontPagePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Emirates ID Front Page file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }*/

    /**async openEmiratesIDBackPagePreviewPopup() {
        try {
            if (!this.emiratesIdBackContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Emirates ID Back Page file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.emiratesIdBackContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handleEmiratesIDBackPagePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Emirates ID Back Page file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }*/

    /**async openVisaPagePreviewPopup() {
        try {
            if (!this.visaPageContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Visa Page file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.visaPageContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handleVisaPagePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Visa Page file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }*/
    handleRemoveFile(event) {
        const id = event.currentTarget.dataset.id;
        const labelName = event.target.dataset.label;


        if (labelName == 'Passport_First_Page') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    passportFrontbase64File: null,
                    passportPreviewUrl: null,
                    isPassportFirstPageUploaded: false
                } :
                member
            );
        } else if (labelName == 'Passport_Signature_Page') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    passportFinalbase64File: null,
                    passportFinalPreviewUrl: null,
                    isPassportSignaturePageUploaded: false
                } :
                member
            );
        } else if (labelName == 'Emirates_ID_Front') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    eidFrontbase64File: null,
                    eidFrontPreviewUrl: null,
                    isEmiratesIdFrontUploaded: false,
                } :
                member
            );
        } else if (labelName == 'Emirates_ID_Back') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    eidBackbase64File: null,
                    eidBackPreviewUrl: null,
                    isEmiratesIdBackUploaded: false,
                } :
                member
            );
        } else if (labelName == 'Visa_Page') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    visabase64File: null,
                    visaPreviewUrl: null,
                    isVisaPageUploaded: false,
                } :
                member
            );
        }
    }
}