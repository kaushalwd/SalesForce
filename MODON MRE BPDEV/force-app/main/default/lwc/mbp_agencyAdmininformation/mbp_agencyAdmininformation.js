/**
 * Component Name : MBP_agencyAdminInfomration
 * Description    : Handles Agency Information
 * Author         : Upendra
 *
 * CHANGE HISTORY
 * ---------------------------------------------------------------------------
 * Version | Date & Time        | Author  | Description
 * ---------------------------------------------------------------------------
 * 1.0     | 2025-08-04 12:00   | Upendra | Initial creation.

 * 1.1    | 2025-12-03 01:05   | Upendra | Fixed Heapsize issue.
 * 
 *   1.2    | 2025-12-17 01:05   | Upendra | Fixed Agent data list issue
 * 
 * 1.3      |2026-12-15 01:05|    |Ashok|   Worked on mobile View css
 * ---------------------------------------------------------------------------
 */

import {
    LightningElement,
    track,
    api
} from 'lwc';
import getRegistrationAgents from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationAgents';
import upsertRegistrationAgentRecords from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationAgentRecords';
import deleteRegistrationAgentRecord from '@salesforce/apex/MBP_RegistrationFormController.deleteRegistrationAgentRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';
import saveAgentsWithFiles from '@salesforce/apex/MBP_RegistrationFormController.saveAgentsWithFiles';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import checkDuplicateEmailOrMobile from '@salesforce/apex/MBP_RegistrationFormController.checkDuplicateEmailOrMobile';
import {
    countryOptions
    
} from './countries';
export default class ownerInformationForm4 extends LightningElement {
    @api registrationId;
       countryOptions = countryOptions;
@track countryOptionsList = [];

    isPhoneLoqateValid = false;
    isEmailLoqateValid = false;
    @track activeSections = ['Agency Admin/POA Details', 'Document Uploads'];
    @track isAddButtonDisabled = false;
    @track staffMembers = [];
    @track isDisabled = false;
    @track initialStaffMembers = [];
    @track isLoading = false;
    @track registrationAgentRec = {};
    @track mobileNum;
     @api mode;
    @api registrationStatus;
    @track registrationObj = {};
    @track isPassportFirstPageUploaded = false;
    @track isPoaDocumentUploaded = false;
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
    @track isInternational = false;
    @track initialAgentRec = {};
    @track isLoading = false;
    rendered = false;
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
        this.countryOptionsList = countryOptions;
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
            const staffAgents = agents.filter(agent => agent.Brokertype === 'Agency Admin');
            if (staffAgents.length > 0) {
                this.staffMembers = staffAgents.map((agent, index) => ({
                    ...agent,
                    id: agent.tempId || Date.now().toString(),
                    label: `Agency Admin/POA Details ${index + 1}`,
                    showRemoveIcon: staffAgents.length > 1,
                    firstname: agent.firstname,
                       passportIssueDate: agent.passportIssueDate,
eidIssueDate: agent.eidIssueDate,
nationality: agent.nationality,
                    POA: agent.POA,
                    POAemail: agent.POAemail,
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
                   isPrimaryagencyadmin: !!agent.isPrimaryagencyadmin,

                    passportFrontbase64File: agent.passportFrontbase64File,
                    passportPreviewUrl: agent.passportFrontbase64File ? `data:application/pdf;base64,${agent.passportFrontbase64File}` : null,
                    isPassportFirstPageUploaded: !!agent.passportFrontbase64File,
                    passportFrontfileName: agent.passportFrontfileName,
                    isPrimaryOwner: agent.isPrimaryOwner,
                    
                    passportFinalbase64File: agent.passportFinalbase64File,
                    passportFinalPreviewUrl: agent.passportFinalbase64File ? `data:application/pdf;base64,${agent.passportFinalbase64File}` : null,
                    isPassportSignaturePageUploaded: !!agent.passportFinalbase64File,
                    passportFinalfileName: agent.passportFinalfileName,

                    poabase64File: agent.poabase64File,
                    poaPreviewUrl: agent.poabase64File ? `data:application/pdf;base64,${agent.poabase64File}` : null,
                    isPoaDocumentUploaded: !!agent.poabase64File,
                    poafileName: agent.poafileName,

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
                    isPhoneLoqateValid: (agent.mobileNum != null  && agent.mobile != null) ? true : false,
                    isEmailLoqateValid: agent.email != null ? true : false,
                     validateEmail : (agent.mobileNum != null && agent.mobile != null) ? 'Validated' : 'Validate Email',
                    validatePhone : agent.email != null ? 'Validated' : 'Validate Phone'

                }));
            } else {
                const newAgent = {
                    id: Date.now().toString(), // temp ID
                    firstname: '',
                    POA: '',
                    POAemail: '',
                    lastname: '',
                         passportIssueDate: '',
eidIssueDate: '',
nationality: '',
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
                    isPrimaryagencyadmin:false,
                    passportFrontbase64File: null,
                    poabase64File: null,
                    passportFinalbase64File: null,
                    eidFrontbase64File: null,
                    eidBackbase64File: null,
                    visabase64File: null,
                    label: `Agency Admin`,
                     validateEmail: 'Validate Email',
    validatePhone: 'Validate Phone',
    isEmailLoqateValid: false,
    isPhoneLoqateValid: false
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
    handleFieldChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const field = event.target.name;
        const inputField = event.target;

  const today = new Date().toISOString().split('T')[0]; // Format YYYY-MM-DD

    // --- DATE VALIDATION LOGIC ---
    const issueDateFields = ['passportIssueDate', 'eidIssueDate'];
    const expiryDateFields = ['passportExpiryDate', 'eidExpiryDate'];

    if (issueDateFields.includes(field)) {
        if (value && value > today) {
            inputField.setCustomValidity('Issue Date cannot be in the future.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }

    if (expiryDateFields.includes(field)) {
        if (value && value < today) {
            inputField.setCustomValidity('Expiry Date cannot be in the past.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }
        // Update staffMembers array
        this.staffMembers = this.staffMembers.map(member =>
            member.id === id ? {
                ...member,
                [field]: value
            } : member
        );

        // ✅ Email validation
        if (field === 'email') {
            this.isEmailLoqateValid = false;
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
                        message = 'This email has already been added for an owner on the previous page, and a matching record exists in the salesforce.';
                    } else if (result === 'AGENT') {
                        message = 'This email has already been added for an owner on the previous page, and a matching record exists in the salesforce.';
                    } else if (result === 'CONTACT') {
                        message = 'This email has already been added for an owner on the previous page, and a matching record exists in the salesforce.';
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
            this.isPhoneLoqateValid = false;
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

    }

    handleFieldChange1(event) {
    const id = event.target.dataset.id;
    const field = event.target.name;
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    const inputField = event.target;

    // 🟩 Log key field details

      /*  if (field === 'eidNumber') {
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
        }*/

          if (field === 'eidNumber') {
            // Match format: 784-XXXX-XXXXXXX-X (i.e., 3 digits - 4 digits - 7 digits - 1 digit)
            const eidRegex = /^784-\d{4}-\d{7}-\d{1}$/;

            if (!eidRegex.test(value)) {
                inputField.setCustomValidity("Emirates ID must be in the format: 784-XXXX-XXXXXXX-X. Only digits and dashes allowed in correct positions.");
            } else {
                inputField.setCustomValidity('');
            }

            inputField.reportValidity();
        }

        // Update staffMembers list with new value
        this.staffMembers = this.staffMembers.map(member =>
            member.id === id ? {
                ...member,
                [field]: value
            } : member
        );
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
    'Please enter an email address to validate.',
    'error'
);

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

            // Email is vali
            selectedOwner.isEmailLoqateValid = true;
            button.innerText = 'Validated';
            selectedOwner.validateEmail = 'Validated';

           this.template.querySelector('c-mbp_customshowtoast')?.show(
    'The email address is valid.',
    'success'
);

        } catch (error) {
            // Email is invalid
            selectedOwner.isEmailLoqateValid = false;
            button.innerText = 'Validate Email';
            selectedOwner.validateEmail = 'Validate Email';

           this.template.querySelector('c-mbp_customshowtoast')?.show(
    error.body?.message || 'The email address is invalid.',
    'error'
);

        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers]; // Force reactivity
        }
    }


     get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted';
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
    'Please select country code and enter mobile number.',
    'error'
);

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
           this.template.querySelector('c-mbp_customshowtoast')?.show(
    isValid ? 'Phone number is valid.' : 'Phone number is invalid.',
    isValid ? 'success' : 'error'
);

        } catch (error) {
            selectedOwner.isPhoneLoqateValid = false;
            button.innerText = 'Validate Phone';
            selectedOwner.validatePhone = 'Validate Phone';
           this.template.querySelector('c-mbp_customshowtoast')?.show(
    error.body?.message || 'Unable to validate phone number.',
    'error'
);

        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers]; // Force re-render if needed
        }
    }

    @api async handleSubmit() {
        this.isLoading = true;
        try {
            const dataToSend = this.staffMembers.map(member => ({
                firstname: member.firstname,
                POA: member.POA || null,
                POAemail: member.POAemail || null,
                lastname: member.lastname,
                mobileNum: member.mobileNum,
                email: member.email,
                mobile: member.mobile,
                isPrimaryagencyadmin: member.isPrimaryagencyadmin === true || member.isPrimaryagencyadmin === 'true',

    passportIssueDate: member.passportIssueDate,

    eidIssueDate: member.eidIssueDate,
    nationality: member.nationality,
                passportNumber: member.passportNumber,
                passportExpiryDate: member.passportExpiryDate,
                eidNumber: member.eidNumber || null,
                eidExpiryDate: member.eidExpiryDate || null,
                Brokertype: 'Agency Admin',
                isPrimaryOwner: member.isPrimaryOwner,
                registrationId: this.registrationId,
                passportFrontbase64File: member.passportFrontbase64File,
                poabase64File: member.poabase64File,
                passportFinalbase64File: member.passportFinalbase64File,
                eidFrontbase64File: member.eidFrontbase64File ,
                eidBackbase64File: member.eidBackbase64File,
                visabase64File: member.visabase64File,

                sfId: member.sfId,
                tempId: member.tempId

            }));
            const result = await saveAgentsWithFiles({
                agentDataList: dataToSend
            });
            JSON.stringify('result::' + result);
            this.template.querySelector('c-mbp_customshowtoast')?.show(
    `Saved ${result.length} agent(s) successfully.`,
    'success'
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
    error.body?.message || 'Something went wrong',
    'error'
);

        } finally {
            this.isLoading = false;
        }
    }

    //  * 1.2  start
safeDate(v) {
  
    return (v === undefined || v === null || v === '') ? null : v;
}

safeBool(v) {
 
    return v === true;
}

   //  * 1.2  end
@api 
async submitForm() {
    this.isLoading = true;
    try {
        // 1) Validate all lightning-inputs
        const allInputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;
        allInputs.forEach(input => {
            input.reportValidity();
            if (!input.checkValidity()) isValid = false;
        });
        if (!isValid) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Please fix the errors before proceeding.',
                'error'
            );
            return;
        }

        // 2) Loqate validations
        const invalidStaff = this.staffMembers.filter(
            member => !member.isPhoneLoqateValid || !member.isEmailLoqateValid
        );
        if (invalidStaff.length > 0) {
            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Please validate both Email and Mobile Number.',
                'error'
            );
            this.isLoading = false;
            return;
        }

        // 3) Required fields
        const requiredFields = [
            { field: 'firstname', label: 'First Name' },
            { field: 'lastname', label: 'Last Name' },
            { field: 'mobile', label: 'Mobile' },
            { field: 'mobileNum', label: 'Mobile country Code' },
            { field: 'email', label: 'Email' },
            { field: 'passportNumber', label: 'Passport Number' },
            { field: 'passportExpiryDate', label: 'Passport Expiry Date' },
        ];
        if (this.showEIDFields) {
            requiredFields.push(
                { field: 'eidNumber', label: 'Emirates ID Number' },
                { field: 'eidExpiryDate', label: 'EID Expiry Date' }
            );
        }

        const missingFields = [];
        this.staffMembers.forEach((member, idx) => {
            const ownerLabel = `Agency Admin/POA Details ${idx + 1}`;

            requiredFields.forEach(({ field, label }) => {
                if (!member[field]) {
                    missingFields.push(label);
                    const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                    if (inputField) {
                        inputField.setCustomValidity('This field is required');
                        inputField.reportValidity();
                    }
                }
               /* if (field === 'eidNumber') {
                    const eid = member[field];
                    const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                    if (eid && (eid.length !== 15 || !eid.startsWith('784'))) {
                        const errorMessage = `EID must be 15 digits and must starts with 784`;
                        if (inputField) {
                            inputField.setCustomValidity(errorMessage);
                            inputField.reportValidity();
                        }
                    }
                }*/

                if (field === 'eidNumber') {
                    const eid = member[field];
                    const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);

                    // Regex: 784-XXXX-XXXXXXX-X (e.g., 784-1234-5678901-2)
                    const eidRegex = /^784-\d{4}-\d{7}-\d{1}$/;

                    if (eid && !eidRegex.test(eid)) {
                        const errorMessage = `EID must be in the format: 784-XXXX-XXXXXXX-X`;
                        if (inputField) {
                            inputField.setCustomValidity(errorMessage);
                            inputField.reportValidity();
                        }
                    } else {
                        if (inputField) {
                            inputField.setCustomValidity('');
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
                detail: { title: 'Error', message: errorMessage, variant: 'error' },
                bubbles: true,
                composed: true
            }));
            this.isLoading = false;
            return;
        }

        // 4) Detect changes vs initial snapshot
        let hasChanges = false;
        if (this.staffMembers.length !== this.initialStaffMembers.length) {
            hasChanges = true;
        } else {
            for (let i = 0; i < this.staffMembers.length; i++) {
                const current = this.staffMembers[i];
                const initial = this.initialStaffMembers.find(init => init.id === current.id);
                if (!initial) { hasChanges = true; break; }
                for (const key in current) {
                    if (key !== 'id' && key !== 'label' && key !== 'showRemoveIcon') {
                        if (current[key] !== initial[key]) { hasChanges = true; break; }
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
                detail: {
                    title: 'Info',
                    message: 'No changes were made to the Agency Admin/POA  information.',
                    variant: 'info'
                },
                bubbles: true,
                composed: true
            }));
            return recordIds;
        }

     // ============================================
// 5) Build payload (ONLY changed files) + logs
// ============================================


const validExtensions = ['pdf', 'jpg', 'jpeg'];
const hasValidExt = (name) =>
    !!name && name.includes('.') &&
    validExtensions.includes(name.split('.').pop().toLowerCase());

const ensureTempId = (m) => {
    if (!m.tempId) {
        m.tempId = (window.crypto && window.crypto.randomUUID)
            ? window.crypto.randomUUID()
            : `${Date.now()}_${Math.random()}`;
    }
    return m;
};

const addFileIfPresent = (src, dst, base64Key, nameKey) => {
    if (src[base64Key] && src[nameKey] && hasValidExt(src[nameKey])) {
        dst[base64Key] = src[base64Key];
        dst[nameKey]   = src[nameKey];
    }
};
//  * 1.1  start

const logPayloadCheck = (obj, index) => {

    const apexFields = [
        "firstname","lastname","email","mobile","mobileNum",
        "passportNumber","passportExpiryDate","eidNumber","eidExpiryDate",
        "passportFrontbase64File","passportFrontfileName",
        "passportFinalbase64File","passportFinalfileName",
        "eidFrontbase64File","eidFrontfileName",
        "eidBackbase64File","eidBackfileName",
        "visabase64File","visabasefileName",
        "poabase64File","poafileName",
        "registrationId","tempId","sfId","Brokertype",
        "isPrimaryOwner","isPrimaryagencyadmin","POA","POAemail"
    ];

    Object.keys(obj).forEach(key => {
        if (!apexFields.includes(key)) {
            console.warn(`❌ INVALID FIELD SENT TO APEX: "${key}" VALUE=`, obj[key]);
        }
    });//  * 1.1  end
};

const normalizedMembers = this.staffMembers.map(m => ensureTempId({ ...m }));
//  * 1.2  start
const dataToSend = normalizedMembers.map((member, idx) => {

    // Log BEFORE BUILD

   const payload = {
  firstname: member.firstname ?? null,
  POA: member.POA ?? null,
  POAemail: member.POAemail ?? null,
  lastname: member.lastname ?? null,
  email: member.email ?? null,
  mobileNum: member.mobileNum ?? null,

  passportIssueDate: this.safeDate(member.passportIssueDate),
  eidIssueDate: this.safeDate(member.eidIssueDate),

  nationality: member.nationality ?? null,
  mobile: member.mobile ?? null,
  passportNumber: member.passportNumber ?? null,

  passportExpiryDate: this.safeDate(member.passportExpiryDate),

  eidNumber: member.eidNumber ?? null,
  eidExpiryDate: this.safeDate(member.eidExpiryDate),

  Brokertype: 'Agency Admin',

  isPrimaryOwner: this.safeBool(member.isPrimaryOwner),
  isPrimaryagencyadmin: this.safeBool(member.isPrimaryagencyadmin),

  registrationId: this.registrationId,
  tempId: member.tempId,
  sfId: member.sfId ?? null
};
//  * 1.2  end

    // FILES
    [
        ['passportFrontbase64File',  'passportFrontfileName',  'isPassportFirstPageUploaded'],
        ['passportFinalbase64File',  'passportFinalfileName',  'isPassportSignaturePageUploaded'],
        ['eidFrontbase64File',       'eidFrontfileName',       'isEmiratesIdFrontUploaded'],
        ['eidBackbase64File',        'eidBackfileName',        'isEmiratesIdBackUploaded'],
        ['visabase64File',           'visabasefileName',       'isVisaPageUploaded'],
        ['poabase64File',            'poafileName',            'isPoaDocumentUploaded']
    ].forEach(([bKey, nKey, flag]) => {
        if (member[flag] && member[bKey] && hasValidExt(member[nKey])) {
            addFileIfPresent(member, payload, bKey, nKey);
        }
    });


    // Validate against wrapper
    logPayloadCheck(payload, idx);

    return payload;
});


//  * 1.1  end

        // 6) Call Apex
        const recordIds = await saveAgentsWithFiles({ agentDataList: dataToSend });

        // 7) Map back IDs (NOTE: your Apex returns List<Id>, so this part will only work if you change Apex to return a Map tempId->Id)
        this.staffMembers = normalizedMembers.map(m => {
            const realId = recordIds[m.tempId]; // undefined unless Apex returns map
            return {
                ...m,
                sfId: realId || m.sfId,
                Id: realId || m.Id
            };
        });

        // 8) Success
        this.dispatchEvent(new CustomEvent('success', {
            detail: { ids: recordIds },
            bubbles: true,
            composed: true
        }));
        this.dispatchEvent(new CustomEvent('toast', {
            detail: {
                title: 'Success',
                message: 'Agency Admin/POA Details saved.',
                variant: 'success'
            },
            bubbles: true,
            composed: true
        }));
        return recordIds;

    } catch (error) {
        console.error('Error in submitForm:', error, JSON.stringify(error));
        this.dispatchEvent(new CustomEvent('error', {
            detail: {
                message: (error && error.body && error.body.message) ? error.body.message : 'Failed to save Agency Admin/POA information.'
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
            this.template.querySelector('c-mbp_customshowtoast')?.show(
    'Only .pdf and .jpg files are allowed.',
    'error'
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
    const id        = event.target.dataset.id;      // staffMember.id from template
    const labelName = event.target.dataset.label;   // e.g. 'Passport_First_Page'
    const file      = event.target.files && event.target.files[0];


    if (!file) {
        console.warn('handleFileChange ▶ No file selected');
        return;
    }

    const validExtensions = ['pdf', 'jpg', 'jpeg'];
    const fileExtension = (file.name || '').split('.').pop().toLowerCase();

    if (!validExtensions.includes(fileExtension)) {
        this.template.querySelector('c-mbp_customshowtoast')?.show(
            'Only .pdf and .jpg files are allowed.',
            'error'
        );
        this.isLoading = false;
        return;
    }

    // ✅ 2MB file size limit check (added)
    const MAX_SIZE = 2 * 1024 * 1024; // 2MB in bytes
    if (file.size > MAX_SIZE) {
        this.template.querySelector('c-mbp_customshowtoast')?.show(
            'File size must be less than 2 MB.',
            'error'
        );
        this.isLoading = false;
        return;
    }

    const reader = new FileReader();
    reader.onload = () => {
        try {
            const dataUrl = reader.result;
            const base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);

            // Mime type
            let mimeType;
            if (fileExtension === 'pdf') {
                mimeType = 'application/pdf';
            } else if (fileExtension === 'jpg' || fileExtension === 'jpeg') {
                mimeType = 'image/jpeg';
            } else {
                mimeType = file.type || 'application/octet-stream';
            }

            // Build preview url
            const byteCharacters = atob(base64);
            const byteNumbers = new Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
            }
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: mimeType });
            const previewUrl = URL.createObjectURL(blob);

            // Prepare the specific update depending on the label
            let patch = null;

            switch (labelName) {
                case 'Passport_First_Page':
                    patch = {
                        passportFrontbase64File: base64,
                        passportFrontfileName: file.name,
                        passportPreviewUrl: previewUrl,
                        isPassportFirstPageUploaded: true
                    };
                    break;

                case 'Passport_Signature_Page':
                    patch = {
                        passportFinalbase64File: base64,
                        passportFinalfileName: file.name,
                        passportFinalPreviewUrl: previewUrl,
                        isPassportSignaturePageUploaded: true
                    };
                    break;

                case 'Emirates_ID_Front':
                    patch = {
                        eidFrontbase64File: base64,
                        eidFrontfileName: file.name,
                        eidFrontPreviewUrl: previewUrl,
                        isEmiratesIdFrontUploaded: true
                    };
                    break;

                case 'Emirates_ID_Back':
                    patch = {
                        eidBackbase64File: base64,
                        eidBackfileName: file.name,
                        eidBackPreviewUrl: previewUrl,
                        isEmiratesIdBackUploaded: true
                    };
                    break;

                case 'Visa_Page':
                    patch = {
                        visabase64File: base64,
                        visabasefileName: file.name,
                        visaPreviewUrl: previewUrl,
                        isVisaPageUploaded: true
                    };
                    break;

                case 'POA_Document':
                    patch = {
                        poabase64File: base64,
                        poafileName: file.name,
                        poaPreviewUrl: previewUrl,
                        isPoaDocumentUploaded: true
                    };
                    break;

                default:
                    console.warn('handleFileChange ▶ Unknown labelName:', labelName);
            }

            if (patch) {
                this.staffMembers = this.staffMembers.map(member =>
                    member.id === id ? { ...member, ...patch } : member
                );

                const updated = this.staffMembers.find(m => m.id === id);
            }
        } catch (e) {
            console.error('handleFileChange ▶ Error while processing file:', e);
            this.template.querySelector('c-mbp_customshowtoast')?.show('Something went wrong while reading the file.', 'error');
        }
    };

    reader.readAsDataURL(file);

    // Log full list after each change (optional – comment out if noisy)
}



   handlePreview(event) {
    const id = event.currentTarget.dataset.id;
    const labelName = event.target.dataset.label;


    const member = this.staffMembers.find(m => m.id === id);
    if (!member) {
        console.warn('❌ No matching member found for ID:', id);
        return;
    }


    let previewUrl = '';
    switch (labelName) {
        case 'Passport_First_Page':
            previewUrl = member.passportPreviewUrl;
            break;
        case 'Passport_Signature_Page':
            previewUrl = member.passportFinalPreviewUrl;
            break;
        case 'Emirates_ID_Front':
            previewUrl = member.eidFrontPreviewUrl;
            break;
        case 'Emirates_ID_Back':
            previewUrl = member.eidBackPreviewUrl;
            break;
        case 'Visa_Page':
            previewUrl = member.visaPreviewUrl;
            break;
        case 'POA_Document':
            previewUrl = member.poaPreviewUrl;
            break;
        default:
            console.warn('⚠️ Unknown label name:', labelName);
            return;
    }


    if (previewUrl && previewUrl.startsWith('data:')) {
        const base64 = previewUrl.split(',')[1];

        // 🔍 Detect actual MIME type based on base64 content (not relying on label alone)
        const detectMimeType = (base64Data) => {
            const header = base64Data.substring(0, 20);
            if (header.startsWith('/9j/')) return 'image/jpeg';
            if (header.startsWith('iVBOR')) return 'image/png';
            if (header.startsWith('JVBER')) return 'application/pdf';
            return 'application/octet-stream';
        };

        const detectedMimeType = detectMimeType(base64);

        try {
            const byteCharacters = atob(base64);
            const byteArrays = new Uint8Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
                byteArrays[i] = byteCharacters.charCodeAt(i);
            }

            const blob = new Blob([byteArrays], { type: detectedMimeType });
            const blobUrl = URL.createObjectURL(blob);

            window.open(blobUrl, '_blank');
        } catch (error) {
            console.error('❌ Failed to generate preview:', error);
        }
    } else {
        console.warn('❌ Invalid or missing preview URL for:', labelName);
    }
}


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
        } else if (labelName == 'POA_Document') {
            this.staffMembers = this.staffMembers.map(member =>
                member.id === id ?
                {
                    ...member,
                    file: null,
                    poabase64File: null,
                    poaPreviewUrl: null,
                    isPoaDocumentUploaded: false
                } :
                member
            );
        }
    }
}