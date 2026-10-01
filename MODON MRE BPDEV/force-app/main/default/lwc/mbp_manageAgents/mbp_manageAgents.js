/**********************************************************************************************************************
* Name               : mbp_manageagents
* Description        : This class is used as the Apex controller for Broker Portal Agent Creation.
* Usage              : LWC components for creating and managing Broker Agents
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com      27 Oct 2025     broker Agent creation,Updating,Assigning Agent types.

* 1.1         Raghu.chilukuri@activemindsit.com   15 dec 2025      Mobile view Enhancements Using seperate html
**********************************************************************************************************************/
import { LightningElement, track, wire } from 'lwc';
import getContactsUserInfo from '@salesforce/apex/MBP_BrokerAgentsController.getContactsUserInfo';
import updateAgent from '@salesforce/apex/MBP_BrokerAgentsController.updateAgent';
import createAgent from '@salesforce/apex/MBP_BrokerAgentsController.createAgent';
import getUserInformation from '@salesforce/apex/MBP_BrokerAgentsController.getUserInformation';
import checkDuplicateEmailOrMobile from '@salesforce/apex/MBP_BrokerLeadcontroller.checkDuplicateEmailOrMobile';
import updateAgentStatus
from '@salesforce/apex/MBP_BrokerAgencyLevelController.updateAgentStatus';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';
import {
    getPicklistValues
} from 'lightning/uiObjectInfoApi';
import Contact_OBJECT from '@salesforce/schema/Contact';
import Title_FIELD from '@salesforce/schema/Contact.Salutation';
import BrokerType_FIELD from '@salesforce/schema/Contact.Broker_Type__c';
import {
    getObjectInfo
} from 'lightning/uiObjectInfoApi';
import getNationlityPicklistValues from '@salesforce/apex/MBP_BrokerAgentsController.getPicklistValuesGeneric';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import createBrokerAgent from '@salesforce/apex/MBP_BrokerAgentsController.createBrokerAgent';
import checkExistingPrimary from '@salesforce/apex/MBP_BrokerAgentsController.checkExistingPrimary';
import updateContactAgentStatus from '@salesforce/apex/MBP_BrokerAgentsController.updateContactAgentStatus';
import updateUserAgentStatus from '@salesforce/apex/MBP_BrokerAgentsController.updateUserAgentStatus';

import createUserFromContact from '@salesforce/apex/MBP_BrokerAgentsController.createUserFromContact';
import PERSONA_SILHOUETTE from '@salesforce/resourceUrl/personaSilhouette';
import uploadFile from '@salesforce/apex/MBP_BrokerAgentsController.uploadFile';
import validateEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import resetPassword from '@salesforce/apex/MBP_BrokerAgentsController.resetPassword';

import { CurrentPageReference } from 'lightning/navigation';
const DELAY = 3000;

export default class Myagency extends LightningElement {

    @track brokerCertificateNumber;
    @track brokerCertificateIssueDate;
    @track brokerCertificateExpiryDate;
    @track issuingAuthority;


    @track showSpinner = false;
    @track showCustomToast = false;
    @track customToastTitle = '';
    @track customToastMessage = '';
    @track customToastVariant = '';
    @track emailValidated = false;
    @track mobileValidated = false;
    @track originalEmail = '';
    @track originalPhone = '';
    @track email = '';
    @track phone = '';
    @track countryCode = '';
    @track showAgency = true;
    @track showAgents = false;
    @track hideMyAgentsTab = false;
    @track showmobilecontent = true;//New

    @track mobileButtonLabel = 'Validate Mobile';
    @track emailButtonLabel = 'Validate Email';
    @track emailValidating = false;
    @track mobileValidating = false;


    @track agents = [];
    @track paginatedAgents = [];
    @track isLimitedOnly = false;
    @track isLoading = false;
    @track showModal = false;
    @track showModal = false;
    @track showAddModal = false;
    @track isLoading = false;

    @track selectedContact = {};
    @track gridData = [];
    @track agentsList = [];
    currentPage = 1;
    pageSize = 10;
    nationalityOptions = [];
    nationality;
    @track isPrimaryOwner = false;
    @track isPrimaryAgencyAdmin = false;
    @track disabledRole = false;
    @track showPrimaryOwner = false;
    @track showPrimaryAdmin = false;
    @track disablePrimaryOwner = false;
    @track disablePrimaryAdmin = false;


    @track showPrimaryOwner = false;
    @track showPrimaryAdmin = false;
    @track isPrimaryOwner = false;
    @track isPrimaryAgencyAdmin = false;
    @track isBroker = false;

    @track files = [];
    @track emiratesFiles = [];
    @track passportFiles = [];
    @track otherFiles = [];
    @track profilePicPreview;
@track isEidExpiredForContact = false;
    @track email = '';

    @track emailValidated = false;

    @track firstName;
    @track lastName;


    @track role;
    @track emiratesID;
    @track expiryDate;
    @track componentTitle = 'Add Agent';
    @track newData = false;
    @track title;
    @track errorDetails;
    @track errorDialog;
    @track additionalWhereClauseForUser = 'RecordType.Name = \'Broker Agency\'';
    @track user;
    @track accountsOption = [];
    @track showEmirates = false;
    @track birthdate;
    @track passportIssueDate;//New
    @track eidIssueDate;//New

@track showAgentStatusModal = false;

@track selectedAgentId;
@track selectedStatus = '';
@track reason = '';

statusOptions = [
    { label: 'Active', value: 'Active' },
    { label: 'In Active', value: 'In Active' },
    { label: 'Pending Verification', value: 'Pending Verification' },
    { label: 'Rejected', value: 'Rejected' },
    { label: 'Suspended', value: 'Suspended' },
    { label: 'Blocked', value: 'Blocked' }
];

    @track mobileNumberToCheck = '';
    @track showSpinner = false;
    @track readOnlyEmail = false;
    @track disableButton = false;
    @track isDubaiBroker = false;
    @track brokerRegion;
    @track passportNumber;
    @track passportExpiryDate;
    @track currentDate;
    @track rowData2 = [];
    @track rowData = [];
    action;
    isSMSVerified = false;
    isEmailVerified = false;
    @track files = [];
    profilePicPreview;
    personaSilhouetteUrl = PERSONA_SILHOUETTE;
    modalHeader = 'Add Agent';
    disableForm = false;
    isRERA_ADM_toShow = false;
    currentUser;
    region;
	
	    // mobile
    @track isMobile = false;
    @track mobileIcons = {
        edit: 'utility:edit',
        reset: 'utility:lock',
        toggle: 'utility:user'
    };
//Mobile Upto above

    triggerFileInput() {
        this.template.querySelector('input[type="file"]').click();
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
    @track newAgent = {
        Name: '',
        Email: '',
        Phone: ''
    };

    connectedCallback() {
       
	   this.detectMobile();
    window.addEventListener('resize', this.handleResize.bind(this));
        this.loadAgents();
        this.loadData();
        this.loadLoggedInUser();
		    // NEW: Check URL parameters for sub-tab selection
    this.checkUrlParameters();
    }
handleBrokerUpdate(event) {
    const brokerType = event.detail.brokerType;

    this.hideMyAgentsTab = brokerType === 'Agent';
    
    // If user is an agent and currently on agents tab, redirect to agency info
    if (brokerType === 'Agent' && this.showAgents) {
        this.showAgencyTab();
    }

    // If Agent → hide content, show label
    this.showmobilecontent = brokerType !== 'Agent';
}



    loadLoggedInUser() {

        this.isLoading = true; // start loading before Apex call



        getUserInformation()

            .then(result => {

                this.currentUser = result;



                const contact = this.currentUser?.Contact;

                const account = contact?.Account;



                // safely set agencyId

                this.agencyId = contact?.AccountId || null;






                // ✅ Emirates logic with safe checks

                if (account?.Agency_Region__c === 'Domestic') {

                    this.showEmirates = true;

                    if (account.BillingState === 'Dubai') {

                        this.isDubaiBroker = true;

                    } else if (account.BillingState === 'Abu Dhabi') {

                        this.isAbuDhabiBroker = true;

                    }

                }



                this.isLoading = false;

            })

            .catch(error => {

                this.isLoading = false;

                console.error('❌ Error loading user:', error?.body?.message || error);

            });

    }







    columns = [

        {

            type: 'text',

            fieldName: 'sno',

            label: 'S.No',

            initialWidth: 70,

            cellAttributes: { alignment: 'left' }

        },
        {
            type: 'text',
            fieldName: 'fullName',
            label: 'Name',
            initialWidth: 100,
            cellAttributes: {
                class: 'last-name-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'username',
            label: 'Username',
            initialWidth: 250,
            cellAttributes: {
                class: 'email-id-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'emailId',
            label: 'Email ID',
            initialWidth: 250,
            cellAttributes: {
                class: 'email-id-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'agentId',
            label: 'Agent ID',
            initialWidth: 100,
            cellAttributes: {
                class: 'agent-id-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'role',
            label: 'Role',
            initialWidth: 120,
            cellAttributes: {
                class: 'role-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'region',
            label: 'Region',
            initialWidth: 130,
            cellAttributes: {
                class: 'region-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'country',
            label: 'Country',
            initialWidth: 130,
            cellAttributes: {
                class: 'country-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'phoneNumber',
            label: 'Phone Number',
            initialWidth: 140,
            cellAttributes: {
                class: 'phone-number-cell'
            }
        },
        {
            type: 'text',
            fieldName: 'active',
            label: 'Status',
            initialWidth: 130,
            cellAttributes: {
                class: 'active-cell'
            }
        },
        {
            label: '',
            fieldName: 'edit',
            type: 'button-icon',
            initialWidth: 40,
            typeAttributes: {
                iconName: 'action:edit',
                name: 'Edit',
                title: 'Edit',
                variant: 'bare', // ✅ no background
                alternativeText: 'Edit'
            },
            cellAttributes: {
                class: 'custom-table-icon edit-icon',
                alignment: 'left'
            }
        },
        {
            label: '',
            fieldName: 'agentStatus',
            type: 'button-icon',
            initialWidth: 40,
            typeAttributes: {
                iconName: 'action:user',
                name: 'agentStatus',
                title: 'Enable/Disable Agent',
                variant: 'bare',
                alternativeText: 'Enable/Disable Agent'
            },
            cellAttributes: {
                class: 'custom-table-icon logout',
                alignment: 'left'
            }
        },
        {
            label: '',
            fieldName: 'reset',
            type: 'button-icon',
            initialWidth: 40,
            typeAttributes: {
                iconName: 'action:password_unlock',
                name: 'reset',
                title: 'Reset Password',
                variant: 'bare',
                alternativeText: 'Reset Password'
            },
            cellAttributes: {
                class: 'custom-table-icon reset-password-icon',
                alignment: 'left'
            }
        }
    ];

    @wire(getObjectInfo, {
        objectApiName: Contact_OBJECT
    })
    contactMetadata;
    @wire(getPicklistValues, {
        recordTypeId: '$contactMetadata.data.defaultRecordTypeId',
        fieldApiName: Title_FIELD
    })
    titlePicklist;
    @wire(getPicklistValues, {
        recordTypeId: '$contactMetadata.data.defaultRecordTypeId',
        fieldApiName: BrokerType_FIELD
    })
    brokerTypePicklist;

    @wire(getNationlityPicklistValues, {
        sObjectName: 'Contact',
        fieldName: 'Nationality__c'
    })
    wiredNationlityPicklist({
        data,
        error
    }) {
        if (data) {
            this.nationalityOptions = data;
        } else if (error) {
            this.nationalityOptions = [];
        }
    }
 async loadData() {
    try {
        const result = await findRegistrationWithReviewComment();
        this.registration = result.registration;
        this.hasAccess = result.hasAccess;
        this.isBrokerAgencyBlocked = result.isBrokerAgencyBlocked;
        this.showSales = result.showSales;
        this.showMyAgency = result.showMyAgency;
        this.isLimitedOnly = result.isLimitedOnly;

        // v1.1: capture whether limited access is due to THIS contact's own
        // EID expiry (vs. a whole-agency block like trade license expiry).
        this.isEidExpiredForContact = result.isEidExpiredForContact;

        this.setTabs();

        // v1.1: if limited access is purely because of the EID expiring for
        // this individual contact, land on "My Agents" by default so they
        // can fix their own record — don't force them onto Agency Info the
        // way a whole-agency block (trade license expiry) correctly does.
        // Skip this if a tab was already explicitly requested via URL param.
        const urlParams = new URLSearchParams(window.location.search);
        const requestedTab = urlParams.get('tab');

        if (this.isEidExpiredForContact && !requestedTab) {
            this.showAgentTab();
        }

    } catch (error) {
        console.error('Error fetching data:', error);
    }
}

get showMyAgentsTab() {
    // Normally hidden whenever isLimitedOnly is true (agency blocked, e.g.
    // trade license expired). EXCEPTION: if the reason this contact has
    // limited access is their own EID expiring, they still need to reach
    // My Agents to fix their own record, so show the tab in that case too.
    return (!this.isLimitedOnly || this.isEidExpiredForContact) && !this.hideMyAgentsTab;
}
    // 👇 Add these methods to your class
    get agencyTabClass() {
        return this.showAgency ? 'active-tab' : '';
    }
    get agentTabClass() {
        return this.showAgents ? 'active-tab' : '';
    }
   showAgencyTab() {
    this.showAgency = true;
    this.showAgents = false;
    
    // Update URL without page reload
    const newUrl = `${window.location.pathname}?tab=info`;
    window.history.replaceState({}, '', newUrl);
}
showAgentTab() {
    this.showAgents = true;
    this.showAgency = false;
    
    // Update URL without page reload
    const newUrl = `${window.location.pathname}?tab=agent`;
    window.history.replaceState({}, '', newUrl);
}

    loadAgents() {
        this.isLoading = true;
        getContactsUserInfo()
            .then(result => {
                this.agentsList = result;
                this.gridData = [];
                this.agentsList.forEach(element => {
                    var status = element.contact.Agent_Status__c;
                    const statusClass = (status === 'Active') ? 'status-badge' : 'status-badge inactive';

                    this.gridData.push({
                        title: element.contact.Salutation,
                        agencyName: element.contact.Account.Name,
                        agencyId: element.contact.AccountId,
                        firstName: element.contact.FirstName,
                      //  lastName: element.contact.Name,
                      lastName: element.contact.LastName,
                      fullName: element.contact.Name, //New Line
                        emailId: element.email,
                        role: element.contact.Broker_Type__c,
                        birthdate: element.contact.Birthdate,
                        region: element.contact.Account.BillingState,
                        country: element.contact.Account.BillingCountry,
                        brokerCertificateNumber: element.contact.Broker_Certificate_Number__c,
                        brokerCertificateIssueDate: element.contact.Broker_Certificate_Issue_Date__c,
                        brokerCertificateExpiryDate: element.contact.Broker_Certificate_Expiry_Date__c,
                        issuingAuthority: element.contact.Issuing_Authority__c,
                          agentId: element.contact.Broker_Certificate_Number__c || 'N/A', //new 


                        phoneNumber: (element.contact.Mobile_Country_COde__c || '') + (element.mobile || ''),
                        phoneNumberWithoutCountryCode: element.contact.Phone,
                        countryCode: element.contact.Mobile_Country_COde__c,

                        active: status,

                        statusClass: statusClass,
                        profilePicPreview: element.user?.FullPhotoUrl,
                        edit: '',
                        generatePassword: '',
                        agentStatus: '',
                        contactId: element.contact.Id,
                        userId: element.user != null ? element.user.Id : '',
                        realEmail: element.email,
                        realMobile: element.mobile,
                        username: element.user != null ? element.user.Username : '',
                        isPrimaryOwner: element.contact.Primary_Owner__c,
                        isPrimaryAgencyAdmin: element.contact.Primary_Agency_Admin__c,
                        isBroker: element.contact.IsBroker__c,
                        passportNumber: element.contact.PassportNumber__c,
                        passportExpiryDate: element.contact.PassportExpiryDate__c,
                        passportIssueDate: element.contact.PassportIssueDate__c, // NEW
                        profilePicPreview: element.user.FullPhotoUrl,
                        emiratesID: element.contact.EIDNumber__c,
                        expiryDate: element.contact.EID_Expiry_Date__c,
                        eidIssueDate: element.contact.Emirates_ID_Issue_Date__c, // NEW
                        nationality: element.contact.Nationality__c,
                        files: element.files == undefined ? [] : element.files,
                        region: element.contact.Account.Agency_Region__c,
                    });
                });

                this.filteredData = [...this.gridData];
                this.paginatedAgents = [...this.gridData];
                this.newData = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
            });
    }


    handleExport() {

        if (!this.gridData || this.gridData.length === 0) {

            this.template.querySelector('c-mbp_customshowtoast').show(
                'No data to export',
                'Warning'
            );
            return;

        }



        // Prepare data to export with correct mapping

        const exportData = this.gridData.map(agent => ({

            Name: agent.lastName || '',
            Username: agent.username || '',
            'Email ID': agent.emailId || '',
            'Agent ID': agent.agentId || '',
            Role: agent.role || '',
            Region: agent.region || '',
            Country: agent.country || '',
            'Phone Number': agent.phoneNumber || '',
            Status: agent.active || ''

        }));



        const csv = this.convertToCSV(exportData);

        // Encode CSV and create a data URI
        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);

        // Create a temporary anchor to trigger download
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'AgentsExport.csv');
        document.body.appendChild(link); // Required for Firefox
        link.click();
        document.body.removeChild(link);
    }

    convertToCSV(data) {
        if (!data || !data.length) return '';

        const header = Object.keys(data[0]).join(',');
        const rows = data.map(row =>
            Object.values(row)
                .map(value => `"${value !== undefined && value !== null ? value : ''}"`)
                .join(',')
        );

        return [header, ...rows].join('\n');
    }




    async enableandrestpasswordagent(event) {
        const row = event.detail.row;
        const actionName = event.detail.action.name;
        if (actionName === 'agentStatus') {

    this.selectedAgentId = row.contactId;
    this.selectedStatus = row.active;
    this.reason = '';

            // ✅ Check if the status is "Pending Verification"
            if (row.active === 'Pending Verification') {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Cannot change status while verification is pending.',
                    'error'
                );

                return; // 🚫 Stop further execution
            }

            this.ids = row.contactId;
            this.userEmail = row.userEmail;
            this.active = row.active;

            this.isLoading = true;

            try {
                await updateUserAgentStatus({
                    userId: row.userId,
                    checkboxVal: this.active
                });

                await updateContactAgentStatus({
                    userId: this.ids,
                    checkboxVal: this.active
                });

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Change Status request submitted successfully. If the status is not changed immediately, it might take several minutes.',
                    'success'
                );
                this.loadAgents();

            } catch (error) {
                console.error('Agent Status Update Error:', JSON.stringify(error));

                const pageError = error?.body?.pageErrors?.[0]?.message;
                const fieldError = error?.body?.fieldErrors?.IsActive?.[0]?.message;

                if (pageError) {
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        pageError,
                        'error'
                    );

                } else if (fieldError) {
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        fieldError,
                        'error'
                    );

                } else {
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Unknown error occurred.',
                        'error'
                    );

                }

            } finally {
                this.isLoading = false;
            }
        }



        if (actionName === 'reset') {

            this.isLoading = true;

            try {
                await resetPassword({
                    userId: row.userId
                });
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Reset Password Email sent to the user.',
                    'success'
                );


            } catch (error) {
                console.error('Reset Password Error:', error);
                const errorMessage = error?.body?.pageErrors?.[0]?.message || 'Reset password failed.';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    errorMessage,
                    'error'
                );


            } finally {
                this.isLoading = false;
            }
        }
    }


    updatePaginatedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedAgents = [...this.gridData.slice(start, end)];
    }

    get totalPages() {
        const pages = Math.ceil(this.gridData.length / this.pageSize);
        return pages > 0 ? pages : 1;
    }
    get isFirstPage() {
        return this.currentPage === 1;
    }
    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }
    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }
    handleEdit(event) {
        const id = event.target.dataset.id;
        const selected = this.gridData.find(agent => agent.id === id);
        this.selectedContact = {
            ...selected.contact
        };
        this.showModal = true;
    }
    /* handleInputChange(event) {
         const field = event.target.dataset.field;
         const value = event.target.value;
         this.selectedContact = { ...this.selectedContact, [field]: value };
     } */

    closeModal() {
        this.showModal = false;
        this.selectedContact = {};
        this.emailValidated = false;
        this.emailValidating = false;
        this.mobileValidated = false;
        this.mobileValidating = false;
        this.emailButtonLabel = 'Validate Email';
        this.mobileButtonLabel = 'Validate Mobile';
    }
	

async submitEdit() {

        // ADDED: Name validation at the beginning
    if (!this.firstName || !this.lastName) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            'Please enter both first name and last name.',
            'error'
        );
        this.isLoading = false;
        return;
    }
    
    // ADDED: Check for duplicate concatenation in lastName
    if (this.lastName.includes(this.firstName)) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            'Last name appears to contain first name. Please enter only the last name.',
            'error'
        );
        this.isLoading = false;
        return;
    }

    // NEW LINES: Broker certificate validation - Add these 25 lines at the beginning
    if (this.isBroker) {
        if (!this.brokerCertificateNumber || !this.brokerCertificateIssueDate || !this.brokerCertificateExpiryDate || !this.issuingAuthority) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please fill all broker certificate fields: Certificate Number, Issue Date, Expiry Date, and Issuing Authority.',
                'error'
            );
            this.isLoading = false;
            return;
        }
        
        // Validate broker certificate dates
        if (!this.validateBrokerCertificateDates()) {
            this.isLoading = false;
            return;
        }
    }

       // NEW VALIDATION FOR ISSUE DATES 
    if (!this.validateIssueDate(this.eidIssueDate, 'eidIssueDate', 'EID Issue Date') ||
        !this.validateIssueDate(this.passportIssueDate, 'passportIssueDate', 'Passport Issue Date')) {
        this.isLoading = false;
        return;
    }
    // END NEW LINES

    if (!this.emailValidated || !this.mobileValidated) {
        this.template.querySelector('c-mbp_customshowtoast').show(
    'Please validate both Email and Mobile before submitting.',
    'error'
);

        return;
    }

    this.isLoading = true;
    this.errorDialog = false;
    this.errorDetails = [];
    this.rowData2 = [];

    const isInputsCorrect = [...this.template.querySelectorAll('lightning-input'), ...this.template.querySelectorAll('lightning-combobox')]
        .reduce((validSoFar, inputField) => {
            inputField.reportValidity();
            return validSoFar && inputField.checkValidity();
        }, true);

    if (!isInputsCorrect) {
        this.isLoading = false;
        this.errorDetails.push('Complete Mandatory Fields.');
       this.template.querySelector('c-mbp_customshowtoast').show(
    'Complete Mandatory Fields.',
    'error'
);

    }
    else {
        let showError = false;
        this.disableButton = false;

        if (this.showEmirates === true) {
            let hasRERABrokerCard = false;
            let hasResidentVisa = false;
            let hasEmiratesId = false;
            let hasPassort = false;
            let hasADMCard = false;

            this.files.forEach(element => {
                if (!hasEmiratesId && element.filename.includes('Emirates ID Copy')) hasEmiratesId = true;
                if (!hasResidentVisa && element.filename.includes('Residence Visa')) hasResidentVisa = true;
                if (!hasPassort && element.filename.includes('Passport Copy')) hasPassort = true;
                if (!hasRERABrokerCard && element.filename.includes('RERA Broker Card')) hasRERABrokerCard = true;
                if (!hasADMCard && element.filename.includes('ADM Card')) hasADMCard = true;
            });

            if (!hasEmiratesId) {
                this.isLoading = false;
                this.errorDetails.push('Upload the Emirates ID / Residence Visa.');
            this.template.querySelector('c-mbp_customshowtoast').show(
    'Upload the Emirates ID / Residence Visa.',
    'error'
);

                showError = true;
                this.disableButton = false;
            } else if (!hasPassort) {
                this.isLoading = false;
                this.errorDetails.push('Upload the Passport Page.');
                this.template.querySelector('c-mbp_customshowtoast').show(
    'Upload the Passport Page.',
    'error'
);

                showError = true;
                this.disableButton = false;
            } else if (!hasRERABrokerCard && this.isDubaiBroker && this.isRERA_ADM_toShow) {
                this.isLoading = false;
                this.errorDetails.push('Upload the RERA Broker Card.');
                this.template.querySelector('c-mbp_customshowtoast').show(
    'Upload the RERA Broker Card.',
    'error'
);

                showError = true;
                this.disableButton = false;
            } else if (!hasADMCard && this.isAbuDhabiBroker && this.isRERA_ADM_toShow) {
                this.isLoading = false;
                this.errorDetails.push('Upload the ADM Card.');
                this.template.querySelector('c-mbp_customshowtoast').show(
    'Upload the ADM Card.',
    'error'
);

                showError = true;
                this.disableButton = false;
            }
        } else {
            let hasPassportId = false;
            this.files.forEach(element => {
                if (!hasPassportId && element.filename.includes('Passport Copy')) hasPassportId = true;
            });
            if (!hasPassportId) {
                this.isLoading = false;
                this.errorDetails.push('Upload the Passport Page.');
                this.template.querySelector('c-mbp_customshowtoast').show(
    'Upload the Passport Page.',
    'error'
);

                showError = true;
                this.disableButton = false;
            }
        }

        if (showError === true) {
            this.isLoading = false;
            return;
        } else {
            this.rowData2.push({
                agencyName: this.agencyName,
                title: this.title,
                firstName: this.firstName,
                lastName: this.lastName,
                emailId: this.email,
                role: this.role,
                country: this.rowData != null && this.action == 'edit' ? this.rowData.country : '',
                phoneNumber: this.phone,
                countryCode: this.countryCode,
                contactId: this.action == 'Edit' ? this.contactId : '',
                userId: this.action == 'Edit' ? this.userId : '',
                realEmail: this.rowData != null && this.action == 'edit' ? this.rowData.realEmail : '',
                realMobile: this.rowData != null && this.action == 'edit' ? this.rowData.realMobile : '',
                birthdate: this.birthdate,
                emiratesID: this.emiratesID != null ? this.emiratesID : '',
                expiryDate: this.expiryDate != null ? this.expiryDate : '',
                eidIssueDate: this.eidIssueDate != null ? this.eidIssueDate : '',

                isPrimaryOwner: this.isPrimaryOwner,
                isPrimaryAgencyAdmin: this.isPrimaryAgencyAdmin,
                nationality: this.nationality,
                brokerCertificateNumber: this.brokerCertificateNumber,
                brokerCertificateIssueDate: this.brokerCertificateIssueDate,
                brokerCertificateExpiryDate: this.brokerCertificateExpiryDate,
                issuingAuthority: this.issuingAuthority,
                // END NEW LINES
                isBroker: this.isBroker, 
                passportNumber: this.passportNumber,
                passportExpiryDate: this.passportExpiryDate,
                 passportIssueDate: this.passportIssueDate != null ? this.passportIssueDate : '', // NEW
            });

            await createBrokerAgent({
                agentInfo: this.rowData2[0]
            })
            .then(result => {
                var permissionSetName;
                if (this.role == 'Agency Admin') {
                    permissionSetName = 'Modon_Agency_Admin_Access';
                } else if (this.role == 'Agent') {
                    permissionSetName = 'Modon_Agent_Access';
                } else if (this.role == 'Owner') {
                    permissionSetName = 'Modon_Agency_Owner_Access';
                }

                if (result != 'Duplicate') {
                    var contactId = result;

                   if (this.action != 'edit') {
    createUserFromContact({
        contactId: result,
        isActive: false,
        permissionSetName: permissionSetName
    })
    .then(result1 => {
        this.isLoading = false;
       this.template.querySelector('c-mbp_customshowtoast').show(
    this.action === 'Edit' ? 'Agent updated successfully.' : 'Agent created successfully.',
    'success'
);

        this.closeModal();
        this.loadAgents();
    })
    .catch(error => {
        this.handleApexError(error);
    });
} else {
    this.isLoading = false;
    this.template.querySelector('c-mbp_customshowtoast').show(
    this.action === 'Edit' ? 'Agent Updated successfully.' : 'Agent created successfully.',
    'success'
);

    this.closeModal();
    this.loadAgents();
}


                    if (this.files != null) {
                        const existingFilenames = this.files.map(file => file.filename);
                        this.upload(this.files, contactId, existingFilenames);
                    }

                } else if (result == 'Duplicate') {
                    this.errorDetails.push('There is already a User with this Email in the System.');
                    this.template.querySelector('c-mbp_customshowtoast').show(
    'There is already a User with this Email in the System.',
    'error'
);
   this.isLoading = false;
                    return; // ✅ Prevent modal from closing on error
                } else {
                    this.errorDetails.push('Some error occured. Please contact Admin.');
                    this.template.querySelector('c-mbp_customshowtoast').show(
    'Some error occured. Please contact Admin.',
    'error'
);

                    this.isLoading = false;
                    return;
                }

            })
            .catch(error => {
                this.handleApexError(error);
            });
        }
    }

 
}

    handleApexError(error) {
        let msg = 'Unknown error';
        if (error?.body?.message) {
            msg = error.body.message.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')
                ? 'FIELD_CUSTOM_VALIDATION_EXCEPTION: Please check the User/Contact Record'
                : error.body.message;
        } else if (error?.body?.fieldErrors?.Username?.[0]?.message) {
            msg = error.body.fieldErrors.Username[0].message;
        } else if (error?.body?.pageErrors?.[0]?.message) {
            msg = error.body.pageErrors[0].message;
        }

        this.errorDetails.push(JSON.stringify(error));
        this.template.querySelector('c-mbp_customshowtoast').show(
            msg,
            'error'
        );

        this.isLoading = false; // ✅ Moved here for consistent handling
    }


    async upload(fileData, recordId, existingFilenames) {

        const DELAY = 100;
        const isNew = recordId === 'NEW';
        for (const file of fileData) {
            const {
                base64,
                filename,
                type
            } = file;
            if (base64) {
                this.isLoading = true;
                try {
                    await new Promise(resolve => setTimeout(resolve, DELAY)); // simulate delay if needed
                    const result = await uploadFile({
                        base64,
                        filename,
                        type,
                        recordId,
                        isNew,
                        existingFilenames
                    });

                } catch (error) {
                    this.errorDetails.push(JSON.stringify(error.body?.message || error));

                } finally {
                    this.isLoading = false;
                }
            }
        }
    }

    handleNewAgentInput(event) {
        const field = event.target.dataset.field;
        this.newAgent[field] = event.target.value;
    }

    submitNewAgent() {
        this.isLoading = true;
        createAgent({
            name: this.newAgent.Name,
            email: this.newAgent.Email,
            phone: this.newAgent.Phone
        })
            .then(result => {
                this.isLoading = false;
                this.showAddModal = false;
                this.newAgent = {
                    Name: '',
                    Email: '',
                    Phone: ''
                };
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Agent created successfully',
                    'success'
                );

            })
            .catch(error => {
                this.isLoading = false;
                console.error(error);
                this.template.querySelector('c-mbp_customshowtoast').show(
                    error.body.message,
                    'error'
                );

            });
    }

    handleMobileValidation() {
        const countryCode = this.countryCode ? (this.countryCode.startsWith('+') ? this.countryCode : '+' + this.countryCode) : '';
        const phone = this.phone || '';
        const fullMobile = countryCode + phone;


        if (!countryCode || !phone) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please enter country code and mobile number.',
                'error'
            );
            return;
        }

        this.mobileValidating = true;
        this.mobileButtonLabel = 'Validating...';

        validatePhone({ phone: fullMobile })
            .then(result => {
                if (result === true) {
                    this.mobileValidated = true;
                    this.originalPhone = this.phone;
                    this.mobileButtonLabel = 'Validated ✅';
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Mobile number is valid.',
                        'success'
                    );

                } else {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate Mobile';
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Entered number is not valid.',
                        'error'
                    );

                }
            })
            .catch(error => {
                console.error('Validation Error:', error);
                this.mobileValidated = false;
                this.mobileButtonLabel = 'Validate Mobile';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    this.getErrorMessage(error),
                    'error'
                );

            })
            .finally(() => {
                this.mobileValidating = false;
            });
    }


    handleEmailValidation() {
        if (!this.email) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please enter an email address.',
                'error'
            );

            return;
        }

        this.emailValidating = true;
        this.emailButtonLabel = 'Validating...';

        validateEmail({ email: this.email })
            .then(() => {
                this.emailValidated = true;
                this.originalEmail = this.email;
                this.emailButtonLabel = 'Validated ✅';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Email is valid.',
                    'success'
                );

            })
            .catch(error => {
                this.emailValidated = false;
                this.emailButtonLabel = 'Validate Email';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    this.getErrorMessage(error),
                    'error'
                );

            })
            .finally(() => {
                this.emailValidating = false;
            });
    }


    getErrorMessage(error) {
        return error?.body?.message || 'Unexpected error occurred.';
    }

    closeModal() {
        this.showModal = false;
    }
    openAddModal() {
        this.showModal = true;
    }

    closeAddModal() {
        this.showModal = false;
    }
    handleAddAgent() {
        this.action = 'Add';
        this.modalHeader = 'Add Agent';
        this.agencyName = '';
        this.title = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.role = '';
        this.countryCode = '';
        this.phone = '';
        this.birthdate = '';
        this.country = '';
        this.userId = '';
        this.realEmail = '';
        this.realMobile = '';
        this.emiratesID = '';
        this.expiryDate = '';

        this.nationality = '';
        this.passportNumber = '';
        this.passportExpiryDate = '';
        this.profilePicPreview = '';
        this.files = [];
        this.region = '';
        this.isBroker = false;
        this.isPrimaryOwner = false;
        this.isPrimaryAgencyAdmin = false;

        // NEW LINES: Reset broker certificate fields - Add these 4 lines
        this.brokerCertificateNumber = '';
        this.brokerCertificateIssueDate = '';
        this.brokerCertificateExpiryDate = '';
        this.issuingAuthority = '';
        this.passportIssueDate = '';
        this.eidIssueDate = '';
    
        // END NEW LINES

        this.showPrimaryOwner = false;
        this.showPrimaryAdmin = false;
        this.isRERA_ADM_toShow = false;

        this.emailValidated = false;
        this.emailValidating = false;
        this.emailButtonLabel = 'Validate Email';

        this.mobileValidated = false;
        this.mobileValidating = false;
        this.mobileButtonLabel = 'Validate Mobile';

        this.originalEmail = '';
        this.originalPhone = '';
        this.originalCountryCode = '';
        this.openAddModal();
    }

    handleInputChange1(event) {
        const dataId = event.target.dataset.id;
        const checked = event.target.checked;

        if (dataId === 'isBroker') {
            this.isBroker = checked;

            if (this.role === 'Owner' || this.role === 'Agency Admin') {
                this.isRERA_ADM_toShow = this.isBroker;
            }

        }

    }
    handleInputChange(event) {
        var value = event.target.value;
        const name = event.target.name;
        const dataId = event.target.dataset.id;

        if (name === 'email') {
            this.email = value;
            if (this.email !== this.originalEmail) {
                this.emailButtonLabel = 'Validate Email';
                this.emailValidating = false;
                this.emailValidated = false;
            } else {
                this.emailValidated = true;
                this.emailButtonLabel = 'Validated ✅';
            }
        }

        else if (event.target.dataset.id === 'isBroker') {
            this.isBroker = event.target.checked;

            // Optional: If you want to hide RERA fields when unchecked
            if (!this.isBroker) {
                this.brokerCertificateNumber = '';
                this.brokerCertificateIssueDate = '';
                this.brokerCertificateExpiryDate = '';
                this.issuingAuthority = '';
            }
        }

        else if (name === 'phone') {
            this.phone = value;
            if (this.phone !== this.originalPhone) {
                this.mobileButtonLabel = 'Validate Mobile';
                this.mobileValidating = false;
                this.mobileValidated = false;
            } else {
                this.mobileValidated = true;
                this.mobileButtonLabel = 'Validated ✅';
            }
        } else if (name === 'countryCode') {
            this.countryCode = value;
            const fullCurrent = this.countryCode + this.phone;
            const fullOriginal = (this.originalCountryCode || '') + (this.originalPhone || '');

            if (fullCurrent !== fullOriginal) {
                this.mobileButtonLabel = 'Validate Mobile';
                this.mobileValidating = false;
                this.mobileValidated = false;
            } else {
                this.mobileValidated = true;
                this.mobileButtonLabel = 'Validated ✅';
            }
        }

        else if (event.target.dataset.id === 'role') {
            this.role = value;
            this.isRERA_ADM_toShow = (value === 'Owner' || value === 'Agency Admin') ? false : true;

            if (value === 'Owner') {
                this.showPrimaryOwner = true;
                this.showPrimaryAdmin = false;
                this.isPrimaryAgencyAdmin = false;

                // Show RERA if isBroker is checked
                this.isRERA_ADM_toShow = this.isBroker;

            } else if (value === 'Agency Admin') {
                this.showPrimaryAdmin = true;
                this.showPrimaryOwner = false;
                this.isPrimaryOwner = false;

                // Show RERA copy for Admins only if isBroker is true (optional, depending on your logic)
                this.isRERA_ADM_toShow = this.isBroker;

            } else {
                this.showPrimaryOwner = false;
                this.showPrimaryAdmin = false;
                this.isPrimaryOwner = false;
                this.isPrimaryAgencyAdmin = false;

                // Show RERA for Agents
                this.isRERA_ADM_toShow = true;
            }
        }


        




        if (event.target.dataset.id === 'title') {
            this.title = value;
        } else if (event.target.dataset.id === 'firstName') {
            this.firstName = value;
        } else if (event.target.dataset.id === 'lastName') {
            this.lastName = value;
        } else if (event.target.dataset.id === 'email') {
            this.email = value.toLowerCase();
            this.type = 'EMAIL';
            this.value = value.toLowerCase();
            this.isEmailVerified = false;
        } else if (event.target.dataset.id === 'dateOfBirth') {
            this.birthdate = value;
            let age = this.getAge(value);
            let target = this.template.querySelector('[data-id="dateOfBirth"]');
            if (age < 18) {
                target.setCustomValidity("Age should be at least 18 years");
            } else {
                target.setCustomValidity("");
            }
            target.reportValidity();
        } else if (event.target.dataset.id === 'role') {
            this.role = value;
            this.isRERA_ADM_toShow = (this.role === 'Owner' || this.role === 'Agency Admin') ? false : true;
        }/* else if (event.target.dataset.id === 'emiratesID') {
        this.emiratesID = value;
        let target = this.template.querySelector('[data-id="emiratesID"]');
        const emiratesPattern = /^784\d{12}$/;
        if (!emiratesPattern.test(value)) {
            target.setCustomValidity("Emirates ID must start with 784 and be 15 digits.");
        } else {
            target.setCustomValidity("");
        }
        target.reportValidity();
    } */

        else if (event.target.dataset.id === 'emiratesID') {
            this.emiratesID = value;
            let target = this.template.querySelector('[data-id="emiratesID"]');

            // New format: 784-XXXX-XXXXXXX-X
            const emiratesPattern = /^784-\d{4}-\d{7}-\d{1}$/;

            if (!emiratesPattern.test(value)) {
                target.setCustomValidity("Emirates ID must be in the format: 784-XXXX-XXXXXXX-X");
            } else {
                target.setCustomValidity("");
            }

            target.reportValidity();
        }


        else if (event.target.dataset.id === 'expiryDate') {
            this.expiryDate = value;
            let target = this.template.querySelector('[data-id="expiryDate"]');
            const today = new Date();
            const selectedDate = new Date(value);
            if (selectedDate <= today) {
                target.setCustomValidity("Expiry date must be in the future.");
            } else {
                target.setCustomValidity("");
            }
            target.reportValidity();
        } else if (event.target.dataset.id === 'phone') {
            this.phone = value;
            this.isSMSVerified = false;
            let target = this.template.querySelector('[data-id="phone"]');
            if (/^[0-9]*$/.test(value)) {
                this.phone = value;
                target.setCustomValidity("");
                this.type = 'SMS';
            } else {
                target.setCustomValidity("Enter Numbers only.");
            }
            target.reportValidity();
        } else if (event.target.dataset.id === 'countryCode') {
            this.countryCode = value;
            this.isSMSVerified = false;
            if (this.phone) {
                this.mobileNumberToCheck = this.countryCode + this.phone;
                this.delayTimeout = setTimeout(async () => {
                    let target = await this.template.querySelector('[data-id="phone"]');
                    if (!this.mobileResponse.data) {
                        target.setCustomValidity("Enter Valid Mobile Number.");
                    } else {
                        target.setCustomValidity("");
                    }
                    target.reportValidity();
                }, DELAY);
            }
        } else if (event.target.dataset.id === 'isPrimaryOwner') {
            if (event.target.checked) {
                this.isPrimaryAgencyAdmin = false;
                this.isPrimaryOwner = true;
                this.role = 'Owner';
            } else {
                this.isPrimaryOwner = false;
            }
        } else if (event.target.dataset.id === 'isPrimaryAgencyAdmin') {
            if (event.target.checked) {
                this.isPrimaryAgencyAdmin = true;
                this.isPrimaryOwner = false;
                this.role = 'Agency Admin';
            } else {
                this.isPrimaryAgencyAdmin = false;
            }
        } else if (event.target.dataset.id === 'nationality') {
            this.nationality = value;
        } else if (event.target.dataset.id === 'passportNumber') {
            this.passportNumber = value;
        } else if (event.target.dataset.id === 'passportExpiryDate') {
            this.passportExpiryDate = value;
            let target = this.template.querySelector('[data-id="passportExpiryDate"]');
            const today = new Date();
            const selectedDate = new Date(value);
            if (selectedDate <= today) {
                target.setCustomValidity("Passport expiry date must be in the future.");
            } else {
                target.setCustomValidity("");
            }
            target.reportValidity();
        }


        //  NEW: Broker Certificate Field Handling
        else if (event.target.dataset.id === 'brokerCertificateNumber') {
            this.brokerCertificateNumber = value;
        } else if (event.target.dataset.id === 'brokerCertificateIssueDate') {
            this.brokerCertificateIssueDate = value;
            this.validateBrokerCertificateDates();
        } else if (event.target.dataset.id === 'brokerCertificateExpiryDate') {
            this.brokerCertificateExpiryDate = value;
            this.validateBrokerCertificateDates();
        } else if (event.target.dataset.id === 'issuingAuthority') {
            this.issuingAuthority = value;
        }


        // New
        else if (event.target.dataset.id === 'passportIssueDate') {
            this.passportIssueDate = value;
        } else if (event.target.dataset.id === 'eidIssueDate') {
            this.eidIssueDate = value;
        }



            // NEW VALIDATIONS FOR PASSPORT AND EID ISSUE DATES
    else if (event.target.dataset.id === 'eidIssueDate') {
        this.eidIssueDate = value;
        // Validate that issue date is in past
        this.validateIssueDate(value, 'eidIssueDate', 'EID Issue Date');
        
        // Also validate sequence with expiry date
        if (this.expiryDate) {
            this.validateDateSequence(value, this.expiryDate, 'eidIssueDate', 'expiryDate', 'EID');
        }
    } 
    else if (event.target.dataset.id === 'passportIssueDate') {
        this.passportIssueDate = value;
        // Validate that issue date is in past
        this.validateIssueDate(value, 'passportIssueDate', 'Passport Issue Date');
        
        // Also validate sequence with expiry date
        if (this.passportExpiryDate) {
            this.validateDateSequence(value, this.passportExpiryDate, 'passportIssueDate', 'passportExpiryDate', 'Passport');
        }
    }


        if (dataId === 'email' && this.email) {
            checkDuplicateEmailOrMobile({ value: this.email, type: 'email' })

                .then(result => {
                    const target = this.template.querySelector('[data-id="email"]');
                    if (result !== 'NONE') {
                        this.showDuplicateToast('Email', result);
                        this.emailValidated = false;
                        this.emailButtonLabel = 'Validate Email';
                        target.setCustomValidity('There is already an agent with this email.');
                    } else {
                        target.setCustomValidity('');
                    }
                    target.reportValidity();
                })
                .catch(error => {
                    console.error('❌ Error checking email duplicate:', error);
                });
        }

        if ((dataId === 'phone' || dataId === 'countryCode') && this.phone && this.countryCode) {
            // Combine and remove non-digits (like +, spaces, etc.)
            let fullMobile = (this.countryCode + this.phone).replace(/\D/g, '');

            // Optional: Use only last 10 digits if needed
            // fullMobile = fullMobile.slice(-10);

            checkDuplicateEmailOrMobile({ value: fullMobile, type: 'mobile' })

                .then(result => {
                    const target = this.template.querySelector('[data-id="phone"]');
                    if (result !== 'NONE') {
                        this.showDuplicateToast('Mobile number', result);
                        this.mobileValidated = false;
                        this.mobileButtonLabel = 'Validate Mobile';
                        target.setCustomValidity('There is already an agent with this mobile number.');
                    } else {
                        target.setCustomValidity('');
                    }
                    target.reportValidity();
                })
                .catch(error => {
                    console.error('❌ Error checking mobile duplicate:', error);
                });
        }


        else if (event.target.dataset.id === 'isPrimaryOwner') {
            const checkbox = this.template.querySelector('[data-id="isPrimaryOwner"]');

            if (event.target.checked) {

                checkExistingPrimary({ accountId: this.agencyId, type: 'Owner' })
                    .then(result => {
                        if (result) {


                            checkbox.setCustomValidity('A Primary Owner already exists. Please disable it on the existing agent before assigning to a new one.');
                            checkbox.reportValidity();

                            this.showDuplicateToast(
                                'Primary Owner',
                                'A Primary Owner already exists. Please disable it on the existing agent before assigning to a new one.'
                            );
                        } else {
                            this.isPrimaryOwner = true;
                            this.isPrimaryAgencyAdmin = false;
                            this.role = 'Owner';

                            checkbox.setCustomValidity('');
                            checkbox.reportValidity();

                        }
                    })
                    .catch(error => {
                        console.error('❌ Error checking Primary Owner:', error);
                        checkbox.setCustomValidity('Unexpected error occurred during Primary Owner check.');
                        checkbox.reportValidity();
                    });
            } else {
                this.isPrimaryOwner = false;
                checkbox.setCustomValidity('');
                checkbox.reportValidity();
            }
        }

        else if (event.target.dataset.id === 'isPrimaryAgencyAdmin') {
            const checkbox = this.template.querySelector('[data-id="isPrimaryAgencyAdmin"]');

            if (event.target.checked) {

                checkExistingPrimary({ accountId: this.agencyId, type: 'Agency Admin' })
                    .then(result => {
                        if (result) {


                            checkbox.setCustomValidity('A Primary Agency Admin already exists. Please disable it on the existing agent before assigning to a new one.');
                            checkbox.reportValidity();

                            this.showDuplicateToast(
                                'Primary Agency Admin',
                                'A Primary Agency Admin already exists. Please disable it on the existing agent before assigning to a new one.'
                            );
                        } else {
                            this.isPrimaryAgencyAdmin = true;
                            this.isPrimaryOwner = false;
                            this.role = 'Agency Admin';

                            checkbox.setCustomValidity('');
                            checkbox.reportValidity();

                        }
                    })
                    .catch(error => {
                        console.error('❌ Error checking Primary Agency Admin:', error);
                        checkbox.setCustomValidity('Unexpected error occurred during Primary Agency Admin check.');
                        checkbox.reportValidity();
                    });
            } else {
                this.isPrimaryAgencyAdmin = false;
                checkbox.setCustomValidity('');
                checkbox.reportValidity();
            }
        }


           // ADDED: Special handling for lastName field to prevent duplication
    else if (event.target.dataset.id === 'lastName') {
        // Remove any first name that might have been accidentally included in last name
        const trimmedValue = value.trim();
        if (this.firstName && trimmedValue.includes(this.firstName)) {
            // Auto-clean: remove first name from last name
            this.lastName = trimmedValue.replace(this.firstName, '').trim();
            // Update the input field
            event.target.value = this.lastName;
        } else {
            this.lastName = trimmedValue;
        }
    } 
    else if (event.target.dataset.id === 'firstName') {
        this.firstName = value;
        // Also check if lastName contains this firstName and clean it
        if (this.lastName && this.lastName.includes(value)) {
            this.lastName = this.lastName.replace(value, '').trim();
            // Update the lastName field if it exists in DOM
            const lastNameField = this.template.querySelector('[data-id="lastName"]');
            if (lastNameField) {
                lastNameField.value = this.lastName;
            }
        }
    }

    }


    showDuplicateToast(label, source) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            `${label} already exists in ${source.replaceAll('_', ' & ')}.`,
            'error'
        );

    }

    getAge(dateString) {
        var today = new Date();
        var birthDate = new Date(dateString);
        var age = today.getFullYear() - birthDate.getFullYear();
        var m = today.getMonth() - birthDate.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
            age--;
        }
        return age;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }
    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }
    async openfileUpload(event) {
        const date = new Date().toLocaleString();
        let fileEventeName = event.target.name;
        let type = '';

        if (fileEventeName === 'emirate') {
            type = 'Emirates ID Copy';
        } else if (fileEventeName === 'residence') {
            type = 'Residence Visa';
        } else if (fileEventeName === 'rera') {
            type = 'RERA Broker Card';
        } else if (fileEventeName === 'passport') {
            type = 'Passport Copy';
        } else if (fileEventeName === 'adm') {
            type = 'ADM Card';
        } else if (fileEventeName === 'profileImage') {
            type = 'Profile Image';
            const file = event.target.files[0];
            if (file && file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = () => {
                    this.profilePicPreview = reader.result;
                };
                reader.readAsDataURL(file);
            }
            return;
        }

        function getBase64(file) {
            return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.readAsDataURL(file);
                reader.onload = () => resolve(reader.result);
                reader.onerror = error => reject(error);
            });
        }

        // Loop through files
        for (const file of Array.from(event.target.files)) {
            let base64 = await getBase64(file).then(data => data.split(',')[1]);
            let fileSize = file.size;
            let extension = file.name.split('.').pop();

            // ❌ Check file size limits
            if (fileSize > 2500000) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'File size is More Than 2 MB.',
                    'error'
                );

                this.errorDetails.push('File size is More Than 2 MB.');
                return;
            } else if ((fileSize + new Blob([JSON.stringify(this.files)]).size) > 2500000) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Total File size is More Than 2 MB.',
                    'error'
                );

                this.errorDetails.push('Total File size is More Than 2 MB.');
                return;
            }

            // ❌ Check duplicate file name
            const isDuplicate = this.files.some(f => f.filename === file.name);
            if (isDuplicate) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'File already exists',
                    'error'
                );

                this.errorDetails.push('File already exists');
                return;
            }

            // ✅ Create formatted file object
            const formattedFile = {
                'filename': type + ' - ' + date + '.' + extension,
                'base64': base64,
                'fileSize': fileSize,
                'type': type,
                'isNew': true
            };

            // ✅ Emirates ID & Passport: auto-remove oldest if already 2
            if (fileEventeName === 'emirate' || fileEventeName === 'passport') {
                const typeCount = this.files.filter(f => f.type === type);
                if (typeCount.length >= 2) {
                    // Remove first uploaded file of this type
                    const firstIndex = this.files.findIndex(f => f.type === type);
                    const removed = this.files.splice(firstIndex, 1)[0];
                }
            }

            // ✅ Push file to list
            this.files.push(formattedFile);
        }
    }

    /* removeFile(event) {
         let listName = event.currentTarget.dataset.listname;
         let fileName = event.currentTarget.dataset.id;
         this.files = this.files.filter(function (obj) {
             alert('obj.filename:::'+obj.filename);
             alert('fileName::'+fileName);
             return obj.filename != fileName;

         });

         this.files = [...this.files];
     } */
    removeFile(event) {

        const fileName = event.currentTarget.dataset.id;
        const listName = event.currentTarget.dataset.listname;


        if (!fileName || !this.files || !Array.isArray(this.files)) {
            console.warn('No file name or files list found.');
            return;
        }
        const originalLength = this.files.length;
        const updatedFiles = this.files.filter(file => file.filename !== fileName);

        if (updatedFiles.length === originalLength) {
            console.warn('No file matched the filename for deletion.');
        }

        this.files = [...updatedFiles];
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        this.action = action.name;

        switch (action.name) {
            case 'Edit':
                this.handleEdit(row);
                break;
            case 'generatePassword':
                this.handleGeneratePassword(row);
                break;
            case 'agentStatus':
            case 'reset':
                this.enableandrestpasswordagent(event);
                break;
            default:
                break;
        }
    }

    handleEdit(row) {
        this.openAddModal();
        this.modalHeader = 'EDIT AGENT';
        this.selectedContact = row;

        if (row.active === 'Pending Verification') {
            this.disableForm = true;
        } else {
            this.disableForm = false;
        }

        this.email = row.emailId;
        this.originalEmail = row.emailId;
        this.emailValidated = true;
        this.emailButtonLabel = 'Validated ✅';

        if (row.phoneNumber && row.countryCode && row.phoneNumber.startsWith(row.countryCode)) {
            this.phone = row.phoneNumber.replace(row.countryCode, '');
        } else if (row.phoneNumber && row.countryCode && row.phoneNumber.startsWith('+' + row.countryCode)) {
            this.phone = row.phoneNumber.replace('+' + row.countryCode, '');
        } else {
            this.phone = row.phoneNumber || '';
        }

        this.originalPhone = row.phoneNumber;
        this.mobileValidated = true;
        this.mobileButtonLabel = 'Validated ✅';

        this.contactId = row.contactId;
        this.agencyName = row.agencyName;
        this.title = row.title;
        this.firstName = row.firstName;
        this.lastName = row.lastName;

        this.role = row.role;
        this.countryCode = row.countryCode;

        this.birthdate = row.birthdate;
        this.country = row.country;
        this.userId = row.userId;
        this.realEmail = row.realEmail;
        this.realMobile = row.realMobile;
        this.emiratesID = row.emiratesID;
        this.expiryDate = row.expiryDate;
        this.isPrimaryOwner = row.isPrimaryOwner ? true : false;
        this.isPrimaryAgencyAdmin = row.isPrimaryAgencyAdmin ? true : false;
        this.nationality = row.nationality;
        this.passportNumber = row.passportNumber;
        this.passportExpiryDate = row.passportExpiryDate;
        this.profilePicPreview = row.profilePicPreview;
        this.files = row.files;
        this.region = row.region;
        this.isBroker = row.isBroker;

        //  NEW: Add broker certificate fields
        this.brokerCertificateNumber = row.brokerCertificateNumber;
        this.brokerCertificateIssueDate = row.brokerCertificateIssueDate;
        this.brokerCertificateExpiryDate = row.brokerCertificateExpiryDate;
        this.issuingAuthority = row.issuingAuthority;
        this.passportIssueDate = row.passportIssueDate;
        this.eidIssueDate = row.eidIssueDate;



        // ✅ FIX: Set visibility based on role (ADD THIS SECTION)
        if (this.role === 'Owner') {
            this.showPrimaryOwner = true;
            this.showPrimaryAdmin = false;
            this.isRERA_ADM_toShow = this.isBroker;
        } else if (this.role === 'Agency Admin') {
            this.showPrimaryAdmin = true;
            this.showPrimaryOwner = false;
            this.isRERA_ADM_toShow = this.isBroker;
        } else {
            this.showPrimaryOwner = false;
            this.showPrimaryAdmin = false;
            this.isRERA_ADM_toShow = true;
        }
    }


    handleGeneratePassword(row) { }

    showCenteredToast(title, message, variant) {
        if (this.toastTimeout) clearTimeout(this.toastTimeout); // Clear previous timeout

        this.customToastTitle = title;
        this.customToastMessage = message;
        this.customToastVariant = variant;
        this.showCustomToast = true;

        this.toastTimeout = setTimeout(() => {
            this.showCustomToast = false;
        }, 4000);
    }


    handleProfilePictureChange(event) {
        const file = event.target.files[0];
        if (file && file.type.startsWith('image/')) {
            const reader = new FileReader();
            reader.onload = () => {
                this.profilePicPreview = reader.result;
            };
            reader.readAsDataURL(file);
        }
    }



    //New Validate Method
    validateBrokerCertificateDates() {
        let isValid = true;

        // Broker Certificate Issue Date validation - should not be in future
        if (this.brokerCertificateIssueDate) {
            const issueDate = new Date(this.brokerCertificateIssueDate);
            const today = new Date();
            today.setHours(0, 0, 0, 0); // Reset time part for accurate comparison

            if (issueDate > today) {
                this.template.querySelector('[data-id="brokerCertificateIssueDate"]').setCustomValidity("Broker certificate issue date cannot be in the future.");
                isValid = false;
            } else {
                this.template.querySelector('[data-id="brokerCertificateIssueDate"]').setCustomValidity("");
            }
            this.template.querySelector('[data-id="brokerCertificateIssueDate"]').reportValidity();
        }

        // Broker Certificate Expiry Date validation - should not be in past
        if (this.brokerCertificateExpiryDate) {
            const expiryDate = new Date(this.brokerCertificateExpiryDate);
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            if (expiryDate < today) {
                this.template.querySelector('[data-id="brokerCertificateExpiryDate"]').setCustomValidity("Broker certificate expiry date cannot be in the past.");
                isValid = false;
            } else {
                this.template.querySelector('[data-id="brokerCertificateExpiryDate"]').setCustomValidity("");
            }
            this.template.querySelector('[data-id="brokerCertificateExpiryDate"]').reportValidity();
        }

        // Validate that expiry date is after issue date
        if (this.brokerCertificateIssueDate && this.brokerCertificateExpiryDate) {
            const issueDate = new Date(this.brokerCertificateIssueDate);
            const expiryDate = new Date(this.brokerCertificateExpiryDate);

            if (expiryDate <= issueDate) {
                this.template.querySelector('[data-id="brokerCertificateExpiryDate"]').setCustomValidity("Broker certificate expiry date must be after the issue date.");
                isValid = false;
                this.template.querySelector('[data-id="brokerCertificateExpiryDate"]').reportValidity();
            }
        }

        return isValid;
    }

    //to validate issue dates (should be in past)
validateIssueDate(dateValue, fieldName, fieldLabel) {
    if (!dateValue) return true;
    
    const issueDate = new Date(dateValue);
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Reset time part for accurate comparison
    
    if (issueDate > today) {
        const target = this.template.querySelector(`[data-id="${fieldName}"]`);
        target.setCustomValidity(`${fieldLabel} cannot be in the future.`);
        target.reportValidity();
        return false;
    }
    
    // Clear validity if valid
    const target = this.template.querySelector(`[data-id="${fieldName}"]`);
    target.setCustomValidity("");
    target.reportValidity();
    return true;
}

//  to validate that expiry date is after issue date
validateDateSequence(issueDateValue, expiryDateValue, issueFieldName, expiryFieldName, entityLabel) {
    if (!issueDateValue || !expiryDateValue) return true;
    
    const issueDate = new Date(issueDateValue);
    const expiryDate = new Date(expiryDateValue);
    
    if (expiryDate <= issueDate) {
        const target = this.template.querySelector(`[data-id="${expiryFieldName}"]`);
        target.setCustomValidity(`${entityLabel} expiry date must be after the issue date.`);
        target.reportValidity();
        return false;
    }
    
    // Clear validity if valid
    const target = this.template.querySelector(`[data-id="${expiryFieldName}"]`);
    target.setCustomValidity("");
    target.reportValidity();
    return true;
}

//mobile
    resetFormFields() {
    this.agencyName = '';
    this.title = '';
    this.firstName = '';
    this.lastName = '';
    this.email = '';
    this.role = '';
    this.countryCode = '';
    this.phone = '';
    this.birthdate = '';
    this.country = '';
    this.userId = '';
    this.realEmail = '';
    this.realMobile = '';
    this.emiratesID = '';
    this.expiryDate = '';
    this.nationality = '';
    this.passportNumber = '';
    this.passportExpiryDate = '';
    this.profilePicPreview = '';
    this.files = [];
    this.region = '';
    this.isBroker = false;
    this.isPrimaryOwner = false;
    this.isPrimaryAgencyAdmin = false;
    this.brokerCertificateNumber = '';
    this.brokerCertificateIssueDate = '';
    this.brokerCertificateExpiryDate = '';
    this.issuingAuthority = '';
    this.passportIssueDate = '';
    this.eidIssueDate = '';
    this.showPrimaryOwner = false;
    this.showPrimaryAdmin = false;
    this.isRERA_ADM_toShow = false;
    this.emailValidated = false;
    this.emailValidating = false;
    this.emailButtonLabel = 'Validate Email';
    this.mobileValidated = false;
    this.mobileValidating = false;
    this.mobileButtonLabel = 'Validate Mobile';
    this.originalEmail = '';
    this.originalPhone = '';
    this.originalCountryCode = '';
}
disconnectedCallback() {
    window.removeEventListener('resize', this.handleResize.bind(this));
}

// Reactively respond to sub-tab navigation (?tab=agent/info) while the
// component stays mounted — connectedCallback only fires once, so in-page
// sidebar switches would otherwise leave the tab state stuck.
@wire(CurrentPageReference)
handlePageReference(pageRef) {
    if (!pageRef || !pageRef.state) return;
    const tab = pageRef.state.tab;
    if (tab === 'agent') {
        if (!this.showAgents) this.showAgentTab();
    } else if (tab === 'info') {
        if (!this.showAgency) this.showAgencyTab();
    }
}

checkUrlParameters() {
    const urlParams = new URLSearchParams(window.location.search);
    const tab = urlParams.get('tab');
    
    if (tab === 'agent') {
        this.showAgentTab();
    } else if (tab === 'info') {
        this.showAgencyTab();
    }
}


normalizeAgents(list) {
    return list.map(a => {
        const first = a.firstName ? a.firstName.charAt(0) : '';
        const last = a.lastName ? a.lastName.charAt(0) : '';

        return {
            ...a,
            initials: `${first}${last}`,
            toggleLabel: a.active === 'Active' ? 'Disable' : 'Enable'
        };
    });
}



detectMobile() {
    this.isMobile = window.innerWidth <= 768;
}

handleResize() {
    this.detectMobile();
}

get mobileAgents() {
    return this.gridData.map(agent => ({
        ...agent,
        displayName: `${agent.firstName} ${agent.lastName}`, // FIXED: Proper concatenation of first and last names
        statusClass: agent.active === 'Active' ? 'status-badge' : 'status-badge inactive',
        toggleIcon: agent.active === 'Active' ? 'utility:user' : 'utility:user',
        toggleTooltip: agent.active === 'Active' ? 'Disable Agent' : 'Enable Agent'
    }));
}

// ADD this getter for paginated mobile agents
get paginatedMobileAgents() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.mobileAgents.slice(start, end);
}

// Your existing pagination getters remain the same
get showPagination() {
    return this.gridData.length > this.pageSize;
}

get disablePrev() {
    return this.currentPage === 1;
}

get disableNext() {
    return this.currentPage >= this.totalPages;
}

/*handleIconClick(event) {
    const action = event.currentTarget.dataset.action;
    const contactId = event.currentTarget.dataset.id;
    const row = this.gridData.find(agent => agent.contactId === contactId);
    
    switch(action) {
        case 'edit':
            this.handleEdit(row);
            break;
        case 'toggle':
            const toggleEvent = {
                detail: {
                    action: { name: 'agentStatus' },
                    row: row
                }
            };
            this.enableandrestpasswordagent(toggleEvent);
            break;
        case 'reset':
            const resetEvent = {
                detail: {
                    action: { name: 'reset' },
                    row: row
                }
            };
            this.enableandrestpasswordagent(resetEvent);
            break;
    }
}*/

handleIconClick(event) {
    const action = event.currentTarget.dataset.action;
    const contactId = event.currentTarget.dataset.id;
    const row = this.gridData.find(agent => agent.contactId === contactId);
    
    switch(action) {
        case 'edit':
            this.action = 'Edit'; // ✅ CRITICAL: Set action for mobile edit
            this.handleEdit(row);
            break;
        case 'toggle':
            const toggleEvent = {
                detail: {
                    action: { name: 'agentStatus' },
                    row: row
                }
            };
            this.enableandrestpasswordagent(toggleEvent);
            break;
        case 'reset':
            const resetEvent = {
                detail: {
                    action: { name: 'reset' },
                    row: row
                }
            };
            this.enableandrestpasswordagent(resetEvent);
            break;
    }
}

handleStatusChange(event){
    this.selectedStatus = event.detail.value;
}

handleReasonChange(event){
    this.reason = event.detail.value;
}

closeAgentStatusModal(){

    this.showAgentStatusModal = false;

    this.selectedStatus = '';

    this.reason = '';

    this.selectedAgentId = null;
}

handleAgentStatusSubmit(){

    if(!this.selectedStatus){

        this.template.querySelector('c-mbp_customshowtoast')
            .show(
                'Please select Agent Status',
                'error'
            );

        return;
    }

    if(!this.reason){

        this.template.querySelector('c-mbp_customshowtoast')
            .show(
                'Status Reason is mandatory',
                'error'
            );

        return;
    }

    this.isLoading = true;

    updateAgentStatus({
        contactId: this.selectedAgentId,
        status: this.selectedStatus,
        reason: this.reason
    })
    .then(() => {

        this.template.querySelector('c-mbp_customshowtoast')
            .show(
                'Agent status updated successfully',
                'success'
            );

        this.closeAgentStatusModal();

        this.loadAgents();
    })
    .catch(error => {

        this.template.querySelector('c-mbp_customshowtoast')
            .show(
                error?.body?.message || 'Error occurred',
                'error'
            );
    })
    .finally(() => {

        this.isLoading = false;
    });
}
//upto above

}