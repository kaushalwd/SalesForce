/**********************************************************************************************************************
* Name               : MBP_ManageExpressionOfIntrests
* Usage              : LWC components for creating and managing eois
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com     15-05-2026     Initial Draft – to fetch Eois and create eois
**********************************************************************************************************************/

import { LightningElement, track ,wire,api} from 'lwc';

import { ShowToastEvent }
from 'lightning/platformShowToastEvent';

import createLead
from '@salesforce/apex/MBP_ExpressionOfInterestsController.createLead';
//import validateOtp from '@salesforce/apex/MBP_ExpressionOfInterestsController.validateOtp';

import getPicklistValues
from '@salesforce/apex/MBP_ExpressionOfInterestsController.getPicklistValues';
import MBP_BrokerAllocationHours
from '@salesforce/label/c.MBP_BrokerAllocationHours';
import voidEOI
from '@salesforce/apex/MBP_ExpressionOfInterestsController.voidEOI';

import getProjects  from '@salesforce/apex/MBP_ExpressionOfInterestsController.getProjects';
import getPhases    from '@salesforce/apex/MBP_ExpressionOfInterestsController.getPhases';
import getUnitTypes from '@salesforce/apex/MBP_ExpressionOfInterestsController.getUnitTypes';
import getUnitTypologies
from '@salesforce/apex/MBP_ExpressionOfInterestsController.getUnitTypologies';
import getUserDetails from '@salesforce/apex/MBP_ExpressionOfInterestsController.getUserDetails';
import getBedrooms  from '@salesforce/apex/MBP_ExpressionOfInterestsController.getBedrooms';

import getEOIRange  from '@salesforce/apex/MBP_ExpressionOfInterestsController.getEOIRange';

import convertLeadAndCreateEOIs  from '@salesforce/apex/MBP_ExpressionOfInterestsController.convertLeadAndCreateEOIs';
import getEOIRecords
from '@salesforce/apex/MBP_ExpressionOfInterestsController.getEOIRecords';

import { getRecord, getFieldValue }           from 'lightning/uiRecordApi';
import updateBrokerAllocationTimer
from '@salesforce/apex/MBP_ExpressionOfInterestsController.updateBrokerAllocationTimer';
import { CloseActionScreenEvent }             from 'lightning/actions';
import OPP_NAME from '@salesforce/schema/Opportunity.Name';
import startVerification from '@salesforce/apex/VerificationService.startVerification';
import resendVerification from '@salesforce/apex/VerificationService.resendVerification';
import verifyCode from '@salesforce/apex/VerificationService.verifyCode';
import MBP_EOISubmitCompanyName from '@salesforce/label/c.MBP_EOISubmitCompanyName';
import MBP_EoiSubmitMessage from '@salesforce/label/c.MBP_EoiSubmitMessage';
const OPP_FIELDS = [OPP_NAME];


export default class MbpManageExpressionOfInterests
extends LightningElement {
    @track createdEOIIds = [];
    @track unitTypologyMasterOptions = [];
    @track eoiRecords = [];
    @track sortDirection = 'asc';

@track showEOIDetailModal = false;

@track selectedEOI = {};

@track showVoidModal = false;
@track paymentTypeOptions = [];

@track paymentType = '';
@track voidReason = '';
    @track canCreateEOI = true;
    @track verificationMethod = '';
    @track verificationDigits = [];
    @track verificationMessage = '';
    @track verificationCompleted = false;
    @track verificationRequestId = null;
    @track isSendingVerification = false;
    @track resendCooldownSeconds = 0;
    @track resendAvailableAt = null;
    @track maxResendReached = false;
    @track leadRecord;
    companyName = MBP_EOISubmitCompanyName;
    @track isMobileView = false;

@track showAddEOIButton = true;
    @track currentPage = 1;

@track pageSize = 6;

@track totalPages = 1;

@track paginatedRecords = [];

eoiSubmitMessage = MBP_EoiSubmitMessage;


@track sortBy = 'Name';
@track eoiList = [
    {
        key: 1,
        selectedProjectId: '',
        selectedProjectName: '',
        selectedUnitTypology: '',
unitTypologyOptions: [],
        selectedPhaseId: '',
        selectedUnitType: '',
        selectedBedrooms: '',
        numberOfUnits: 1,
        remarks: '',
        eoiAmount: '',
        matchedRangeId: '',
        phaseOptions: [],
        unitTypeOptions: [],
        
        bedroomOptions: []
    }
];


get eoiColumns() {

    return [
        { label: 'S.No', fieldName: 'serialNumber',type: 'number', fixedWidth: 90 },

        {
            label: 'EOI Number',
            fieldName: 'EOIId__c',
            sortable: true
        },
{
            label: 'Customer Name',
            fieldName: 'CustomerName',
            sortable: true
        },
       
       
        {
            label: 'Opportunity',
            fieldName: 'OpportunityName',
            sortable: true
        },

        {
            label: 'Project',
            fieldName: 'ProjectName',
            sortable: true
        },

      

        {
            label: 'Unit Type',
            fieldName: 'UnitType__c',
            sortable: true
        },

        {
            label: 'Bedrooms',
            fieldName: 'NumberofBedrooms__c',
            sortable: true
        },
    
         {
            label: 'Status',
            fieldName: 'Status__c',
            type: 'text',
            sortable: true,
            cellAttributes: {
                class: {
                    fieldName: 'statusClass'
                }
            }
        },

        {
            label: 'Broker Allocation Timer',
            fieldName: 'BrokerTimer',
            sortable: true,
            cellAttributes: {
                class: {
                    fieldName: 'timerClass'
                }
            }
        }
    ];
}



@track isEditMode = false;

@track editingEOIId = '';

@track completedStep = '1';
@track isLoading = false;
    @track opportunityId;
    @track opportunityName   = '';
  
@track createdEOIId = '';
    @track opportunityNumber = '';

  @wire(getRecord, {
        recordId: '$opportunityId',
        fields: OPP_FIELDS
    })
    wiredOpp({ data, error }) {

        if (data) {

            this.opportunityName =
                getFieldValue(data, OPP_NAME) || '';

            this.opportunityNumber =
                this.opportunityId
                    ? this.opportunityId.substring(0, 15)
                    : '';

          
        }

        else if (error) {

            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Unable to fetch user details',
                'error'
            );
        }
    }

handlePaymentChange(event) {

    this.paymentType =
        event.target.value;
}


checkMobileView() {
        this.isMobileView = window.innerWidth <= 768;
    }
@track brokerType;
    @track projectOptions  = [];
    @track phaseOptions    = [];
    @track unitTypeOptions = [];
    @track bedroomOptions  = [];

    @track selectedProjectId   = '';
    @track selectedProjectName = '';
    @track selectedPhaseId     = '';
    @track selectedUnitType    = '';
    @track selectedBedrooms    = '';
    @track numberOfUnits       = 1;
    @track remarks             = '';      // ← NEW: maps to EOIComments__c

    @track matchedRangeId = null;
    @track matchedAmount  = null;

    @track showQuota      = false;
    @track quotaLimit     = 0;
    @track quotaUsed      = 0;
    @track quotaRemaining = 0;

    @track isDuplicate    = false;
    @track existingEOIRef = '';
    @track showOppStatus  = false;
    @track errorMessage   = '';

    @track isLoading      = false;
    @track showSuccess    = false;
    @track createdEOIRef  = '';
    @track showQuotaModal = false;

   

    @track showModal = false;

    @track currentStep = '1';

    @track records = [];

    leadId;


@track generatedOtp = '';

@track enteredOtp = '';

@track residentOptions = [];

@track countryOptions = [];

@track nationalityOptions = [];

@track titleOptions = [];


    @track leadType = '';

    @track title = '';

    @track firstName = '';

    @track lastName = '';

    @track email = '';

    @track mobile = '';

    @track residentStatus = '';

    @track country = '';

    @track nationality = '';

    @track emiratesId = '';

    @track emiratesExpiry = '';

    @track passportNumber = '';

    @track passportIssueDate = '';

    @track passportExpiryDate = '';

    @track company = '';

    @track tradeLicenseNumber = '';

    @track tradeLicenseExpiryDate = '';

    @track vatCertificateType = '';

    @track uaeVatRegisterNumber = '';


async connectedCallback() {

    /*
        IMPORTANT
        INITIALIZE TRUE
        TO AVOID MOBILE RENDER ISSUE
    */

    this.showAddEOIButton = true;

    /*
        INITIAL LOADS
    */

    this.loadPicklists();

    this._loadProjects();

    this.loadEOIRecords();

    this.resetVerification();

    /*
        MOBILE VIEW
    */

    this.checkMobileView();

    requestAnimationFrame(() => {

        window.dispatchEvent(
            new Event('resize')
        );

    });

    /*
        RESIZE LISTENER
    */

    window.addEventListener(
        'resize',
        this.handleResize
    );

    /*
        USER DETAILS
    */

    try {

        const user =
            await getUserDetails();

        this.brokerType =
            user?.Contact?.Broker_Type__c;

        /*
            BUTTON ACCESS
        */

        this.showAddEOIButton =
            this.brokerType === 'Owner' ||
            this.brokerType === 'Agent';

    }

    catch(error) {

        /*
            HIDE BUTTONS
            ONLY IF API FAILS
        */

        this.showAddEOIButton = false;

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'Unable to fetch user details',
                'error'
            );
    }

    /*
        TIMER REFRESH
    */

    this.timerInterval =
        setInterval(() => {

            this.refreshTimers();

        }, 1000);
}



resetVerification() {
       // this.clearResendCooldownTimer();
        this.verificationMethod = '';
        this.verificationMessage = '';
        this.verificationCompleted = false;
        this.verificationRequestId = null;
        this.isSendingVerification = false;
        this.resendCooldownSeconds = 0;
        this.resendAvailableAt = null;
        this.maxResendReached = false;
        this.verificationDigits = Array.from({ length: 6 }, (_value, index) => ({
            key: `otp-${index}`,
            index,
            value: ''
        }));
    }
async loadEOIRecords() {

    this.isLoading = true;

    try {

        /*
            GET LATEST DATA
        */

        const result =
            await getEOIRecords();

        /*
            NULL SAFETY
        */

        const records =
            Array.isArray(result)
                ? result
                : [];

        /*
            IMPORTANT
            CLEAR OLD REFERENCES
        */

        this.eoiRecords = [];

        this.paginatedRecords = [];

        /*
            FORCE EMPTY DOM RENDER
        */

        await Promise.resolve();

        /*
            MAP NEW DATA
        */

        this.eoiRecords =
            records.map((item, index) => {

                /*
                    TIMER
                */

                const timerText =
                    this.calculateRemainingTime(
                        item.Broker_Allocation_Timer__c,
                        item.Status__c
                    );

                /*
                    TIMER BADGE
                */

                let timerBadgeClass =
                    'timerGreen';

                if (
                    timerText === '0h 0m 0s'
                ) {

                    timerBadgeClass =
                        'timerExpired';
                }

                else {

                    const hourMatch =
                        timerText.match(/(\d+)h/);

                    const hours =
                        hourMatch
                            ? parseInt(
                                hourMatch[1],
                                10
                              )
                            : 0;

                    /*
                        CRITICAL
                    */

                    if (hours <= 4) {

                        timerBadgeClass =
                            'timerCritical';
                    }

                    /*
                        WARNING
                    */

                    else if (hours <= 12) {

                        timerBadgeClass =
                            'timerWarning';
                    }
                }

                /*
                    STATUS BADGE
                */

                let statusBadgeClass =
                    'statusDefault';

                switch(item.Status__c) {

                    case 'New':

                        statusBadgeClass =
                            'statusNew';

                        break;

                    case 'In Progress':

                        statusBadgeClass =
                            'statusProgress';

                        break;

                    case 'Completed':

                        statusBadgeClass =
                            'statusCompleted';

                        break;

                    case 'EOI Confirmed':

                        statusBadgeClass =
                            'statusConfirmed';

                        break;

                    case 'Submitted':

                        statusBadgeClass =
                            'statusSubmitted';

                        break;

                    case 'Approved':

                        statusBadgeClass =
                            'statusApproved';

                        break;

                    case 'Rejected':

                        statusBadgeClass =
                            'statusRejected';

                        break;

                    case 'Cancelled':

                        statusBadgeClass =
                            'statusCancelled';

                        break;

                    case 'Voided':

                        statusBadgeClass =
                            'statusVoided';

                        break;

                    case 'Pending With Finance':

                        statusBadgeClass =
                            'statusFinance';

                        break;

                    case 'Expired':

                        statusBadgeClass =
                            'statusExpired';

                        break;

                    default:

                        statusBadgeClass =
                            'statusDefault';
                }

                /*
                    VOID BUTTON
                */

                const isVoidDisabled =
                    item.Status__c === 'Voided';

                const voidButtonClass =
                    isVoidDisabled
                        ? 'floatingVoidBtn disabledVoidBtn'
                        : 'floatingVoidBtn';

                /*
                    RETURN
                */

                return {

                    ...item,

                    serialNumber:
                        index + 1,

                    OpportunityName:
                        item.Opportunity__r
                            ? item.Opportunity__r.Name
                            : '',

                    ProjectName:
                        item.Project__r
                            ? item.Project__r.Name
                            : '',

                 CustomerName:
    item.Account__r?.Name
        ? item.Account__r.Name
        : '',

                    CustomerPhone:
                        item.Account__r?.PersonMobilePhone
                            ? item.Account__r.PersonMobilePhone
                            : '',

                    CustomerEmail:
                        item.Account__r?.Email__c
                            ? item.Account__r.Email__c
                            : '',

                    PhaseName:
                        item.Phase__r
                            ? item.Phase__r.Name
                            : '',

                    BrokerTimer:
                        timerText,

                    timerBadgeClass:
                        timerBadgeClass,

                    statusBadgeClass:
                        statusBadgeClass,

                    isVoidDisabled:
                        isVoidDisabled,

                    voidButtonClass:
                        voidButtonClass
                };
            });

        /*
            RESET PAGE
        */

        this.currentPage = 1;

        /*
            TOTAL PAGES
        */

        this.totalPages =
            Math.ceil(
                this.eoiRecords.length /
                this.pageSize
            ) || 1;

        /*
            FORCE NEW PAGINATION ARRAY
        */

        const start =
            (
                this.currentPage - 1
            ) * this.pageSize;

        const end =
            start + this.pageSize;

        this.paginatedRecords = [

            ...this.eoiRecords.slice(
                start,
                end
            )
        ];

        /*
            FINAL DOM REFRESH
        */

        await Promise.resolve();
    }

    catch(error) {


        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this._err(error),
                'error'
            );
    }

    finally {

        this.isLoading = false;
    }
}
updatePaginatedRecords() {

    const start =
        (
            this.currentPage - 1
        ) * this.pageSize;

    const end =
        start + this.pageSize;

  this.paginatedRecords = [
    ...this.eoiRecords.slice(
        start,
        end
    )
];
}

handlePreviousPage() {

    if (this.currentPage > 1) {

        this.currentPage--;

        this.updatePaginatedRecords();
    }
}

handleNextPage() {

    if (
        this.currentPage <
        this.totalPages
    ) {

        this.currentPage++;

        this.updatePaginatedRecords();
    }
}

get disablePrevious() {

    return this.currentPage === 1;
}

get disableNext() {

    return (
        this.currentPage ===
        this.totalPages
    );
}


handleSort(event) {

    this.sortBy =
        event.detail.fieldName;

    this.sortDirection =
        event.detail.sortDirection;

    let cloneData =
        [...this.eoiRecords];

    cloneData.sort((a, b) => {

        let valueA =
            a[this.sortBy]
                ? a[this.sortBy]
                : '';

        let valueB =
            b[this.sortBy]
                ? b[this.sortBy]
                : '';

        return this.sortDirection === 'asc'
            ? valueA > valueB ? 1 : -1
            : valueA < valueB ? 1 : -1;
    });

    this.eoiRecords = cloneData;
}
    async loadPicklists() {

        this.isLoading = true;

        try {

            const result = await getPicklistValues();

            this.residentOptions =
                result.residentStatus.map(item => {

                    return {
                        label: item,
                        value: item
                    };
                });

            this.countryOptions =
                result.country.map(item => {

                    return {
                        label: item,
                        value: item
                    };
                });

this.paymentTypeOptions =
    result.paymentType.map(item => {

        return {
            label: item,
            value: item
        };
    });

            this.nationalityOptions =
                result.nationality.map(item => {

                    return {
                        label: item,
                        value: item
                    };
                });

            this.titleOptions =
                result.salutation.map(item => {

                    return {
                        label: item,
                        value: item
                    };
                });
        }

        catch (error) {

            console.error(error);

            this.template.querySelector('c-mbp_customshowtoast')?.show(
                'Unable to fetch user details',
                'error'
            );
        }

        finally {

            this.isLoading = false;
        }
    }


calculateRemainingTime(timerValue, status) {

    /*
        STATUSES THAT SHOULD SHOW ZERO TIMER
    */

    const zeroTimerStatuses = [
       
        'Completed',
        'Approved',
        'Rejected',
        'Cancelled',
        'Voided',
        'Expired'
    ];

    /*
        RETURN ZERO TIMER
    */

    if (zeroTimerStatuses.includes(status)) {

        return '0h 0m 0s';
    }

    /*
        EMPTY TIMER
    */

    if (!timerValue) {

        return '0h 0m 0s';
    }

    const expiryTime =
        new Date(timerValue).getTime();

    const now =
        new Date().getTime();

    let difference =
        expiryTime - now;

    /*
        EXPIRED
    */

    if (difference <= 0) {

        difference = 0;
    }

    const hours =
        Math.floor(
            difference /
            (1000 * 60 * 60)
        );

    const minutes =
        Math.floor(
            (
                difference %
                (1000 * 60 * 60)
            ) /
            (1000 * 60)
        );

    const seconds =
        Math.floor(
            (
                difference %
                (1000 * 60)
            ) / 1000
        );

    return `${hours}h ${minutes}m ${seconds}s`;
}
refreshTimers() {

    /*
        UPDATE MAIN RECORDS
    */

    this.eoiRecords =
        this.eoiRecords.map(item => {

            const timerText =
               this.calculateRemainingTime(
    item.Broker_Allocation_Timer__c,
    item.Status__c
);

            let timerBadgeClass =
                'timerGreen';

            if (timerText === '0h 0m 0s') {

                timerBadgeClass =
                    'timerExpired';
            }

            else {

                const hourMatch =
                    timerText.match(/(\d+)h/);

                const hours =
                    hourMatch
                        ? parseInt(
                            hourMatch[1],
                            10
                          )
                        : 0;

                if (hours <= 4) {

                    timerBadgeClass =
                        'timerCritical';
                }

                else if (hours <= 12) {

                    timerBadgeClass =
                        'timerWarning';
                }
            }

            return {

                ...item,

                BrokerTimer:
                    timerText,

                timerBadgeClass:
                    timerBadgeClass
            };
        });

    /*
        IMPORTANT
        REFRESH PAGINATION DATA
    */

    this.updatePaginatedRecords();
}

disconnectedCallback() {

       window.removeEventListener(
        'resize',
        this.handleResize
    );

    if (this.timerInterval) {

        clearInterval(this.timerInterval);
    }
    this.clearResendCooldownTimer();
}

  handleOtpChange(event) {

    this.enteredOtp =
        event.target.value;

 

  
}
   openModal() {

    this.isEditMode = false;

    this.resetFields();

    this.currentStep = '1';

    this.showModal = true;
}
    closeModal() {

        this.showModal = false;
    }
handleChange(event) {

    const field =
        event.target.dataset.field;

    this[field] =
        event.target.value;

    /*
        CLEAR FIELD ERROR
    */

    event.target.setCustomValidity('');

    event.target.reportValidity();
}

 handleResidentChange(event) {

    this.residentStatus =
        event.detail.value;

   

    if (this.residentStatus === 'Resident') {

        this.passportNumber = '';
        this.passportIssueDate = '';
        this.passportExpiryDate = '';
    }

    if (this.residentStatus === 'Non-Resident') {

        this.emiratesId = '';
        this.emiratesExpiry = '';
    } 
}

handleRemoveEOI(event) {

    const index =
        parseInt(
            event.target.dataset.index,
            10
        );

    this.eoiList =
        this.eoiList.filter(
            (item, idx) => idx !== index
        );
}

handleRowAction(event) {

    const actionName =
        event.detail.action.name;

    const row =
        event.detail.row;

    if (actionName === 'edit') {

        this.openEditModal(row);
    }
}

async openEditModal(row) {

    try {

        this.isLoading = true;

        this.resetFields();

        this.showSuccess = false;

        this.isEditMode = true;

        this.showModal = true;

        /*
            IDS
        */

        this.editingEOIId =
            row.Id;

        this.createdEOIId =
            row.Id;

        this.opportunityId =
            row.Opportunity__c;

        /*
            PREFILL STEP 1
            FROM LEAD
        */

        this.firstName =
            row.LeadFirstName || '';

        this.lastName =
            row.LeadLastName || '';

        this.email =
            row.LeadEmail || '';

        this.mobile =
            row.LeadMobile || '';

        this.residentStatus =
            row.LeadResidentStatus || '';

        this.country =
            row.LeadCountry || '';

        this.nationality =
            row.LeadNationality || '';

        this.emiratesId =
            row.LeadEmiratesId || '';

        this.passportNumber =
            row.LeadPassportNumber || '';

        this.passportIssueDate =
            row.LeadPassportIssueDate || '';

        this.passportExpiryDate =
            row.LeadPassportExpiryDate || '';

        this.tradeLicenseNumber =
            row.LeadTradeLicense || '';

        this.tradeLicenseExpiryDate =
            row.LeadTradeLicenseExpiry || '';

        this.vatCertificateType =
            row.LeadVatType || '';

        this.uaeVatRegisterNumber =
            row.LeadVatNumber || '';

        /*
            OTP
        */

        this.generatedOtp =
            row.LeadOtp || '';

        this.enteredOtp =
            row.LeadOtp || '';

        /*
            DETERMINE TYPE
        */

        if (this.tradeLicenseNumber) {

            this.leadType =
                'Organization';
        }

        else {

            this.leadType =
                'Individual';
        }

        /*
            LOAD OPTIONS
        */

        let phaseOptions = [];
        let unitTypeOptions = [];
        let bedroomOptions = [];

        /*
            PHASES
        */

        if (row.Project__c) {

            phaseOptions =
                await getPhases({

                    projectId:
                        row.Project__c
                });
        }

        /*
            UNIT TYPES
        */

        if (
            row.Project__c &&
            row.Phase__c
        ) {

            unitTypeOptions =
                await getUnitTypes({

                    projectId:
                        row.Project__c,

                    phaseId:
                        row.Phase__c
                });
        }

        /*
            BEDROOMS
        */

        if (
            row.Project__c &&
            row.Phase__c &&
            row.UnitType__c
        ) {

            bedroomOptions =
                await getBedrooms({

                    projectId:
                        row.Project__c,

                    phaseId:
                        row.Phase__c,

                    unitType:
                        row.UnitType__c
                });
        }

        /*
            PREFILL EOI LIST
        */

        this.eoiList = [

            {

                key: 1,

                eoiId:
                    row.Id,

                selectedProjectId:
                    row.Project__c || '',

                selectedProjectName:
                    row.ProjectName || '',

                selectedPhaseId:
                    row.Phase__c || '',

                selectedUnitType:
                    row.UnitType__c || '',

                selectedBedrooms:
                    row.NumberofBedrooms__c || '',

                numberOfUnits:
                    row.Number_of_Units__c || '',

                remarks:
                    row.EOIComments__c || '',

                matchedAmount:
                    row.EOI_Amount_AED__c || '',

                eoiAmount:
                    row.EOI_Amount_AED__c
                        ? 'AED ' +
                          row.EOI_Amount_AED__c
                        : '',

                matchedRangeId:
                    row.EOI_Range__c || '',

                phaseOptions:
                    phaseOptions,

                unitTypeOptions:
                    unitTypeOptions,

                bedroomOptions:
                    bedroomOptions
            }
        ];

        /*
            MOVE TO STEP 3
        */

        this.currentStep = '3';

        /*
            SAVE DRAFT
        */

       

        /*
            VALIDATION
        */

       
    }

    catch(error) {

        console.error(error);

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this._err(error),
                'error'
            );
    }

    finally {

        this.isLoading = false;
    }
}
    async handleSubmit() {
       if (this.currentStep === '1') {
        const allValid = [...this.template.querySelectorAll(
            'lightning-input, lightning-combobox'
        )]
        .filter(element => {
            return (element.offsetParent !== null);
        })
        .reduce((validSoFar, inputField) => {
            inputField.reportValidity();
            return ( validSoFar && inputField.checkValidity()
            );
        }, true);

    if (!allValid) {
        this.template.querySelector('c-mbp_customshowtoast' ) ?.show( 'Please complete all mandatory fields','error');
        return;
    }
    await this.createLeadBackend();
}
else if (this.currentStep === '2') {
    try {
        await this.verifySelectedVerificationCode();
        this.template.querySelector('c-mbp_customshowtoast')?.show(
            'OTP Verified Successfully',
            'success'
        );
        this.currentStep = '3';
    }
    catch (error) {
        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this.reduceError(error),
                'error'
            );
    }
}
else if (this.currentStep === '3') {

    /*
        BLOCK EOI CREATION
    */

  

    this.resetVerification();

    if (this.isCreateDisabled) {

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'Please complete all EOI details before proceeding',
                'error'
            );

        return;
    }

    const created =
        await this.handleCreate();

    if (created) {

        this.currentStep = '4';

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'EOI Created Successfully',
                'success'
            );
    }
}
else if (this.currentStep === '4') {

    this.isLoading = true;

    try {

        /*
            UPDATE TIMER
        */

        if (
            this.createdEOIIds &&
            this.createdEOIIds.length > 0
        ) {

            await Promise.all(

                this.createdEOIIds.map(recId => {

                    return updateBrokerAllocationTimer({

                        eoiId: recId
                    });

                })
            );
        }

        /*
            FORCE TABLE REFRESH
        */

        await this.loadEOIRecords();

        /*
            RESET TO FIRST PAGE
        */

        this.currentPage = 1;

        /*
            FORCE NEW ARRAY REFERENCE
        */

        this.eoiRecords = [
            ...this.eoiRecords
        ];

        /*
            REFRESH PAGINATION
        */

        this.updatePaginatedRecords();

        /*
            FORCE UI RERENDER
        */

        await Promise.resolve();

        /*
            SUCCESS
        */

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'Thank you for your submission. Please visit Modon Office and complete the payment .',
                'success'
            );

        /*
            CLOSE MODAL AFTER REFRESH
        */

        this.showModal = false;

    }

    catch(error) {


        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this._err(error),
                'error'
            );
    }

    finally {

        this.isLoading = false;
    }
}
    }
async createLeadBackend() {
    this.isLoading = true;
    try {
    
        const result =
            await createLead({
                firstName:this.firstName,
                lastName:this.lastName,
                email:this.email,
                mobile:this.mobile,
                residentStatus:this.residentStatus,
                country:this.country,
                nationality:this.nationality,
                emiratesId:this.emiratesId,
              
                passportNumber: this.passportNumber,
               
                company: this.company,
                tradeLicenseNumber: this.tradeLicenseNumber
              
            });
        if (!result.success) {
            if (
                result.pageErrors &&
                result.pageErrors.length
            ) {
                this.template.querySelector(
                    'c-mbp_customshowtoast'
                )?.show(
                    result.pageErrors.join(', '),
                    'error'
                );
            } if (result.fieldErrors) {
                Object.keys(
                    result.fieldErrors
                ).forEach(fieldName => {
                    const inputCmp =
                        this.template.querySelector( `[data-field="${fieldName}"]`);
                    if (inputCmp) {
                        inputCmp.setCustomValidity(result.fieldErrors[fieldName]);
                        inputCmp.reportValidity();
                    }
                });
            }
            return;
        } 
        this.leadId = result.leadId;
        this.leadRecord = result.leadRecord;
        this.generatedOtp = result.otp;
        this.template.querySelector(
            'c-mbp_customshowtoast'
        )?.show(
            'Lead created successfully',
            'success'
        );
        this.currentStep = '2';
    }

    catch (error) {
        console.error(error);
        this.template.querySelector(
            'c-mbp_customshowtoast'
        )?.show(
            this._err(error),
            'error'
        );
    }
    finally {
        this.isLoading = false;
    }
}

handleOtpInput(event) {

    let value = event.target.value;
    const index =
        parseInt(
            event.target.dataset.id,
            10
        );

    /*
        ONLY NUMBERS
    */

    value =
        value.replace(
            /[^0-9]/g,
            ''
        );

    event.target.value =
        value;

    let otpArray =
        this.enteredOtp
            ? this.enteredOtp.split('')
            : ['', '', '', '', '', ''];

    otpArray[index] =
        value;

    this.enteredOtp =
        otpArray.join('');

    const inputs =
        this.template.querySelectorAll(
            '.otpBox'
        );

    /*
        AUTO NEXT
    */

    if (
        value &&
        index < inputs.length - 1
    ) {

        inputs[index + 1].focus();
    }

    /*
        BACKSPACE
    */

    if (
        event.key === 'Backspace' &&
        !value &&
        index > 0
    ) {

        inputs[index - 1].focus();
    }

    /*
        SAVE DRAFT
    */


}
   /* async validateOtpBackend() {

        this.isLoading = true;

        try {

            const result =
                await validateOtp({

                    leadId:
                        this.leadId,

                    enteredOtp:
                        this.enteredOtp
                });

            if (result) {

                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'OTP Verified Successfully',
                    'success'
                );

                this.currentStep = '3';
              


            }

            else {

                this.template.querySelector('c-mbp_customshowtoast')?.show(
                    'Invalid OTP',
                    'error'
                );
            }
        }

        catch (error) {

            console.error(error);

            this.template.querySelector('c-mbp_customshowtoast')?.show(
                this._err(error),
                'error'
            );
        }

        finally {

            this.isLoading = false;
        }
    } */

 resetFields() {

    /*
        OTP
    */

    this.generatedOtp = '';
    this.enteredOtp = '';

    /*
        GLOBAL FIELDS
    */

    this.selectedProjectId = '';
    this.selectedProjectName = '';
    this.selectedPhaseId = '';
    this.selectedUnitType = '';
    this.selectedBedrooms = '';
    this.numberOfUnits = '';
    this.remarks = '';
    this.eoiAmount = '';
    this.paymentType = '';

    this.phaseOptions = [];
    this.unitTypeOptions = [];
    this.bedroomOptions = [];

    this.matchedRangeId = null;
    this.matchedAmount = null;

    /*
        RESET EOI LIST
        IMPORTANT FIX
    */

    this.eoiList = [
        {
            key: 1,

            selectedProjectId: '',
            selectedProjectName: '',

            selectedPhaseId: '',

            selectedUnitType: '',

            selectedBedrooms: '',

            selectedUnitTypology: '',

            unitTypologyOptions: [],

            numberOfUnits: 1,

            remarks: '',

            eoiAmount: '',

            matchedAmount: '',

            matchedRangeId: '',

            phaseOptions: [],

            unitTypeOptions: [],

            bedroomOptions: []
        }
    ];

    /*
        CUSTOMER DETAILS
    */

    this.leadType = '';
    this.title = '';
    this.firstName = '';
    this.lastName = '';
    this.email = '';
    this.mobile = '';
    this.residentStatus = '';
    this.country = '';
    this.nationality = '';

    /*
        RESIDENT
    */

    this.emiratesId = '';
    this.emiratesExpiry = '';

    /*
        NON RESIDENT
    */

    this.passportNumber = '';
    this.passportIssueDate = '';
    this.passportExpiryDate = '';

    /*
        ORGANIZATION
    */

    this.company = '';
    this.tradeLicenseNumber = '';
    this.tradeLicenseExpiryDate = '';

    /*
        VAT
    */

    this.vatCertificateType = '';
    this.uaeVatRegisterNumber = '';
}

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    get typeOptions() {

        return [

            {
                label: 'Individual',
                value: 'Individual'
            },

            {
                label: 'Organization',
                value: 'Organization'
            }
        ];
    }

    get vatOptions() {

        return [

            {
                label: 'VAT Registration Certificate',
                value: 'VAT Registration Certificate'
            },

            {
                label: 'VAT Undertaking Certificate',
                value: 'VAT Undertaking Certificate'
            }
        ];
    }

    get isResident() {

        return this.residentStatus === 'Resident';
    }

    get isNonResident() {

        return this.residentStatus === 'Non-Resident';
    }

    get isOrganization() {

        return this.leadType === 'Organization';
    }

    get showVatNumber() {

        return this.vatCertificateType
            === 'VAT Registration Certificate';
    }

    get isStep1() {

        return this.currentStep === '1';
    }

    get isStep2() {

        return this.currentStep === '2';
    }

    get isStep3() {

        return this.currentStep === '3';
    }

    get isStep4() {

        return this.currentStep === '4';
    }
    get isFirstStep() {

    return this.currentStep === '1';
}

 get buttonLabel() {

    return this.currentStep === '4'
        ? 'Finish'
        : 'Next';
}
async handlePrevious() {


    /*
        SAVE CURRENT STEP DATA
    */

 

    /*
        MOVE STEP
    */

    let targetStep = '1';

    if (this.currentStep === '4') {

        targetStep = '3';
    }

    else if (this.currentStep === '3') {

        targetStep = '2';
    }

    else if (this.currentStep === '2') {

        targetStep = '1';
    }

    /*
        LOAD DRAFT VALUES
        WITHOUT OVERRIDING STEP
    */

  

  this.currentStep =
    targetStep;


}

    async _loadProjects() {
        try {
            this.projectOptions = await getProjects();
        } catch (e) {
            this.errorMessage = 'Failed to load projects: ' + this._err(e);
        }
    }

  

    async handleProjectChange(e) {
        this.selectedProjectId   = e.target.value;
        const found              = this.projectOptions.find(o => o.value === this.selectedProjectId);
        this.selectedProjectName = found ? found.label : '';
      
        this.selectedPhaseId     = '';
        this.selectedUnitType    = '';
        this.selectedBedrooms    = '';
        this.phaseOptions        = [];
        this.unitTypeOptions     = [];
        this.bedroomOptions      = [];
        this.matchedRangeId      = null;
        this.matchedAmount       = null;
        this.errorMessage        = '';
        this.showQuotaModal      = false;

        if (!this.selectedProjectId) { this.showQuota = false; return; }
        try {
            this.phaseOptions = await getPhases({ projectId: this.selectedProjectId });
           
            if (this.quotaRemaining <= 0) this.showQuotaModal = true;
        } catch (err) {
            this.errorMessage = 'Failed to load phases: ' + this._err(err);
        }
    }
handleAddMoreEOI() {

  

    const nextKey =
        this.eoiList.length + 1;

    this.eoiList = [

        ...this.eoiList,

        {
            key: nextKey,
selectedUnitTypology: '',
unitTypologyOptions: [],
            selectedProjectId: '',
            selectedProjectName: '',
            selectedPhaseId: '',
            selectedUnitType: '',
            selectedBedrooms: '',
            numberOfUnits: '1',
            remarks: '',
            eoiAmount: '',
            matchedRangeId: '',

            phaseOptions: [],
            unitTypeOptions: [],
            bedroomOptions: []
        }
    ];
}

async handleEOIFieldChange(event) {

    const index =
        parseInt(
            event.target.dataset.index,
            10
        );

    const field =
        event.target.dataset.field;

    const value =
        event.target.value;

    let tempList =
        [...this.eoiList];

    /*
        SET VALUE
    */

    tempList[index][field] =
        value;

    /*
        PROJECT CHANGE
    */

    if (field === 'selectedProjectId') {

    tempList[index].selectedPhaseId = '';
    tempList[index].selectedUnitType = '';
    tempList[index].selectedBedrooms = '';
    

    tempList[index].unitTypeOptions = [];
    
    tempList[index].bedroomOptions = [];
    tempList[index].selectedUnitTypology = '';

tempList[index].unitTypologyOptions = [];

    try {

        /*
            LOAD PHASES
        */

        tempList[index].phaseOptions =
            await getPhases({

                projectId: value
            });

        /*
            LOAD EOI AVAILABILITY
        */

     
    }

    catch(error) {

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this._err(error),
                'error'
            );
    }
}

    /*
        PHASE CHANGE
    */

    if (field === 'selectedPhaseId') {

        tempList[index].selectedUnitType = '';
        tempList[index].selectedBedrooms = '';

        tempList[index].bedroomOptions = [];
        tempList[index].selectedUnitTypology = '';

tempList[index].unitTypologyOptions = [];

        try {

            tempList[index].unitTypeOptions =
                await getUnitTypes({

                    projectId:
                        tempList[index].selectedProjectId,

                    phaseId:
                        value
                });

        }

        catch(error) {

            this.template
                .querySelector('c-mbp_customshowtoast')
                .show(
                    this._err(error),
                    'error'
                );
        }
    }

    /*
        UNIT TYPE CHANGE
    */

   if (field === 'selectedUnitType') {

    tempList[index].selectedBedrooms = '';

    tempList[index].selectedUnitTypology = '';

    tempList[index].unitTypologyOptions = [];

    try {

        tempList[index].bedroomOptions =
            await getBedrooms({

                projectId:
                    tempList[index].selectedProjectId,

                phaseId:
                    tempList[index].selectedPhaseId,

                unitType:
                    value
            });

    }

    catch(error) {

        this.template
            .querySelector('c-mbp_customshowtoast')
            .show(
                this._err(error),
                'error'
            );
    }
}

    /*
        BEDROOM CHANGE
    */

if (field === 'selectedBedrooms') {

    try {

        /*
            LOAD TYPOLOGIES
        */

        const typologyResult =
            await getUnitTypologies({

                projectId:
                    tempList[index].selectedProjectId,

                phaseId:
                    tempList[index].selectedPhaseId,

                unitType:
                    tempList[index].selectedUnitType,

                bedrooms:
                    value
            });

        tempList[index].unitTypologyOptions =
            typologyResult.map(item => {

                return {

                    label: item,
                    value: item
                };
            });

    }

    catch(error) {

        this.template
            .querySelector('c-mbp_customshowtoast')
            .show(
                this._err(error),
                'error'
            );
    }
}
/*
    UNIT TYPOLOGY CHANGE
*/

if (field === 'selectedUnitTypology') {

    try {

        const result =
            await getEOIRange({

                projectId:
                    tempList[index].selectedProjectId,

                phaseId:
                    tempList[index].selectedPhaseId,

                unitType:
                    tempList[index].selectedUnitType,

                bedrooms:
                    tempList[index].selectedBedrooms,

                unitTypology:
                    value
            });

        if (result) {

            tempList[index].matchedRangeId =
                result.rangeId;

            tempList[index].matchedAmount =
                result.amount;

            tempList[index].eoiAmount =
                'AED ' +
                result.amount;
        }
    }

    catch(error) {

        this.template
            .querySelector('c-mbp_customshowtoast')
            .show(
                this._err(error),
                'error'
            );
    }
}
/*
    AUTO CALCULATE EOI AMOUNT
*/

if (
    field === 'numberOfUnits'
) {

    const units =
        parseInt(value, 10);

    const baseAmount =
        parseFloat(
            tempList[index].matchedAmount
        );

    if (
        units > 0 &&
        baseAmount
    ) {

        const total =
            units * baseAmount;

        tempList[index].eoiAmount =
            'AED ' +
            total.toLocaleString(
                'en-AE'
            );
    }

    else if (baseAmount) {

        tempList[index].eoiAmount =
            'AED ' +
            baseAmount.toLocaleString(
                'en-AE'
            );
    }
}
    /*
        DUPLICATE VALIDATION
    */

  
    this.eoiList =
        [...tempList];
}
    async handlePhaseChange(e) {
        this.selectedPhaseId  = e.target.value;
        this.selectedUnitType = '';
        this.selectedBedrooms = '';
        this.unitTypeOptions  = [];
        this.bedroomOptions   = [];
        this.matchedRangeId   = null;
        this.matchedAmount    = null;

        if (!this.selectedPhaseId) return;
        try {
            this.unitTypeOptions = await getUnitTypes({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId
            });
        } catch (err) {
            this.errorMessage = 'Failed to load unit types: ' + this._err(err);
        }
    }

    async handleUnitTypeChange(e) {
        this.selectedUnitType = e.target.value;
        this.selectedBedrooms = '';
        this.bedroomOptions   = [];
        this.matchedRangeId   = null;
        this.matchedAmount    = null;

        if (!this.selectedUnitType) return;
        try {
            this.bedroomOptions = await getBedrooms({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId,
                unitType:  this.selectedUnitType
            });
        } catch (err) {
            this.errorMessage = 'Failed to load bedrooms: ' + this._err(err);
        }
    }

    async handleBedroomsChange(e) {
        this.selectedBedrooms = e.target.value;
        this.matchedRangeId   = null;
        this.matchedAmount    = null;
        if (!this.selectedBedrooms) return;
        try {
            const res = await getEOIRange({
                projectId: this.selectedProjectId,
                phaseId:   this.selectedPhaseId,
                unitType:  this.selectedUnitType,
                bedrooms:  this.selectedBedrooms
            });
            if (res) {
                this.matchedRangeId = res.rangeId;
                this.matchedAmount  = res.amount;
            } else {
                this.errorMessage = 'No active EOI Range found for this selection.';
            }
        } catch (err) {
            this.errorMessage = 'Failed to fetch EOI Range: ' + this._err(err);
        }
    }

    handleUnitsChange(e) {
        this.numberOfUnits = e.target.value;
    }
    handleRemarksChange(e) {
        this.remarks = e.target.value;
    }
   async handleCreate() {
    this.isLoading = true;
    this.errorMessage = '';
    try {
        if (!this.eoiList || this.eoiList.length === 0) {
            this.template
                .querySelector('c-mbp_customshowtoast')
                .show(
                    'Please add atleast one EOI',
                    'error'
                );

            return false;
        }
        
        /*
    VALIDATE ALL EOI ROWS
*/

for (let i = 0; i < this.eoiList.length; i++) {

    const item = this.eoiList[i];

    if (
        !item.selectedProjectId ||
        !item.selectedPhaseId ||
        !item.selectedUnitType ||
        !item.selectedBedrooms ||
        !item.selectedUnitTypology ||
        !item.numberOfUnits ||
        parseInt(item.numberOfUnits, 10) < 1 ||
        !item.matchedRangeId
    ) {

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                `Please complete all fields for EOI ${i + 1}`,
                'error'
            );

        return false;
    }
}

/*
    PAYMENT TYPE VALIDATION
*/

if (!this.paymentType) {

    this.template
        .querySelector(
            'c-mbp_customshowtoast'
        )
        ?.show(
            'Please select payment type',
            'error'
        );

    return false;
}
        const payload = this.eoiList.map(item => {

            const units =
                parseInt(item.numberOfUnits, 10);

            const total =
                (units > 0 && item.matchedAmount)
                    ? units * item.matchedAmount
                    : item.matchedAmount;

            return {

                eoiId:
                    item.eoiId
                        ? item.eoiId
                        : null,

                projectId:
                    item.selectedProjectId,

                phaseId:
                    item.selectedPhaseId,

                unitType:
                    item.selectedUnitType,
                    unitTypology:
    item.selectedUnitTypology,
    paymentType:
    this.paymentType,

                bedrooms:
                    item.selectedBedrooms,
                    

                numberOfUnits:
                    units,

                eoiRangeId:
                    item.matchedRangeId,

                eoiAmount:
                    total,

                remarks:
                    item.remarks
            };

        });
      const result = await convertLeadAndCreateEOIs({
        leadId:this.leadId,
        eoiJson:JSON.stringify(payload)
    });

    if (!result) {
        this.template.querySelector('c-mbp_customshowtoast')?.show(
            'No response from server',
            'error'
        );
        return false;
    }
    if (!result.success) {
    if (result.pageErrors && result.pageErrors.length) {
        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                result.pageErrors.join(', '),
                'error'
            );
    }

    if (result.fieldErrors) {
        Object.keys(
            result.fieldErrors
        ).forEach(fieldName => {

            const inputCmp =
                this.template.querySelector(

                    `[data-field="${fieldName}"]`
                );

            if (inputCmp) {

                inputCmp.setCustomValidity(

                    result.fieldErrors[fieldName]
                );

                inputCmp.reportValidity();
            }
        });
    }

    return false;
}
       this.createdEOIIds = result.createdEOIIds;
        this.showSuccess = true;
        this.template
            .querySelector('c-mbp_customshowtoast')
            .show(
                'EOIs Created Successfully',
                'success'
            );

        return true;

    }catch (err) {
        this.errorMessage = this._err(err);

        this.template
            .querySelector('c-mbp_customshowtoast')
            .show(
                this.errorMessage,
                'error'
            );

       

        return false;
    }
    finally {
        this.isLoading = false;
    }
}

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    closeQuotaModal()          { this.showQuotaModal = false; }
    handleModalBackdropClick() { this.showQuotaModal = false; }
    stopPropagation(e)         { e.stopPropagation(); }

    get isFormDisabled()     { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0); }
    get isPhaseDisabled()    { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedProjectId; }
    get isUnitTypeDisabled() { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedPhaseId; }
    get isBedroomsDisabled() { return this.isDuplicate || (this.showQuota && this.quotaRemaining <= 0) || !this.selectedUnitType; }
get isCreateDisabled() {

    if (
        this.isLoading ||
        this.isDuplicate
    ) {

        return true;
    }

    for (let item of this.eoiList) {

        if (

            !item.selectedProjectId ||
            !item.selectedPhaseId ||
            !item.selectedUnitType ||
            !item.selectedBedrooms ||
            !item.numberOfUnits ||

            parseInt(
                item.numberOfUnits,
                10
            ) < 1 ||

            !item.matchedRangeId
        ) {

            return true;
        }
    }

    return false;
}
    get displayAmount() {
        if (!this.matchedAmount) return '\u2014';
        const units = parseInt(this.numberOfUnits, 10);
        const total = (units > 0) ? units * this.matchedAmount : this.matchedAmount;
        return 'AED ' + Number(total).toLocaleString('en-AE');
    }
    get amountSourceLabel() { return this.matchedAmount ? 'from EOI Range' : 'EOI_Amount_AED__c'; }
    get amountBoxClass()    { return this.matchedAmount ? 'amount-box filled' : 'amount-box'; }
    get oppStatusClass()    { return this.isDuplicate ? 'opp-status-bar error' : 'opp-status-bar ok'; }

    get progressBarStyle() {
        const pct   = this.quotaLimit > 0 ? Math.min((this.quotaUsed / this.quotaLimit) * 100, 100) : 0;
        const color = this.quotaRemaining < 50 ? '#c0392b' : '#0a0a0a';
        return 'width:' + pct + '%; background:' + color;
    }
    get quotaNumClass()   { return this.quotaRemaining < 50 ? 'quota-num warn' : 'quota-num'; }
    get quotaBadgeClass() { return 'quota-badge'; }
    get selectedProject() { return this.selectedProjectName; }

    _err(e) { return (e && e.body && e.body.message) ? e.body.message : (e.message || 'Unknown error'); }


    get step1Class() {

    return this.currentStep === '1'
        ? 'stepCard activeStep'
        : 'stepCard completedStep';
}

get step2Class() {

    if(this.currentStep === '2') {

        return 'stepCard activeStep';
    }

    return this.currentStep > '2'
        ? 'stepCard completedStep'
        : 'stepCard';
}

get step3Class() {

    if(this.currentStep === '3') {

        return 'stepCard activeStep';
    }

    return this.currentStep > '3'
        ? 'stepCard completedStep'
        : 'stepCard';
}

get step4Class() {

    return this.currentStep === '4'
        ? 'stepCard activeStep'
        : 'stepCard';
}

get line1Class() {

    return 'stepConnector';
}

get line2Class() {

    return 'stepConnector';
}

get line3Class() {

    return 'stepConnector';
}

    handleExport() {
        if (!this.eoiRecords || this.eoiRecords.length === 0) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'No data to export',
                'Warning'
            );
            return;
        }
        
        const exportData = this.eoiRecords.map(eoi => ({
            EOINumber: eoi.EOIId__c,
            Opportunity: eoi.Opportunity__r?.Name || '',
            Project: eoi.Project__r?.Name || '',
            Phase: eoi.Phase__r?.Name || '',
            UnitType: eoi.UnitType__c,
            BedRoom: eoi.NumberofBedrooms__c,
            NumberOfUnits: eoi.Number_of_Units__c,
            EOIAmount: eoi.EOI_Amount_AED__c,
            Status:eoi.Status__c
        }));

        const csv = this.convertToCSV(exportData);
        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'EOIReport.csv');
        document.body.appendChild(link); 
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

    async handleVerificationMethod(event) {
        const method = event.currentTarget.dataset.method;
        if (method === 'whatsapp') {
            this.errorMessage = 'WhatsApp verification is not configured yet. Please use Email or SMS Verification.';
            return;
        }
        await this.sendVerificationCode(method, false);
    }
    async sendVerificationCode(method, isResend) {
        this.errorMessage = '';
        const normalizedMethod = method === 'sms' ? 'sms' : 'email';
        const channel = normalizedMethod === 'sms' ? 'SMS' : 'Email';
        const target = normalizedMethod === 'sms' ? this.verificationPhoneTarget : this.verificationEmailTarget;
        
        

        if (normalizedMethod === 'email' && !target) {
            this.errorMessage = 'Customer email is required for email verification.';
            return;
        }
        if (normalizedMethod === 'sms' && !target) {
            this.errorMessage = 'Customer phone number is required for SMS verification.';
            return;
        }
        this.verificationMethod = normalizedMethod;
        this.verificationMessage = isResend
            ? 'Sending a new verification code...'
            : 'Sending verification code...';
        this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
        this.isSendingVerification = true;
        try {
            const request = {
                channel,
                target,
                context: 'EOI_HOME',
                contextKey: this.selectedProjectId || null
            };
            const result = await startVerification({ request });
            this.verificationRequestId = result.verificationRequestId;
            this.maxResendReached = false;
            const destination = normalizedMethod === 'sms' ? 'mobile number' : 'email';
            this.verificationMessage = isResend
                ? `A new 6-digit code has been sent to your ${destination}.`
                : (result.message || `A 6-digit code has been sent to your ${destination}.`);
            this.startResendCooldown(result.resendAvailableAt);
            this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
            this.pendingOtpFocusIndex = 0;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSendingVerification = false;
        }
    }

    handleVerificationCodeInput(event) {
        const index = Number(event.currentTarget.dataset.otpIndex);
        const value = (event.target.value || '').replace(/\D/g, '').slice(-1);
        event.target.value = value;
        this.verificationDigits = this.verificationDigits.map((digit) => (
            digit.index === index ? { ...digit, value } : digit
        ));
        this.enteredOtp = this.verificationDigits.map((digit) => digit.value).join('');

        if (value && index < 5) {
            requestAnimationFrame(() => {
                const nextInput = this.template.querySelector(`input[data-otp-index="${index + 1}"]`);
                if (nextInput) nextInput.focus();
            });
        }
    }

    async verifySelectedVerificationCode() {
        if (!this.verificationRequestId) {
            throw new Error('Please send a verification code before continuing.');
        }
        const code = this.verificationDigits.map((digit) => digit.value).join('');
        if (code.length !== 6) {
            throw new Error('Please enter the 6-digit verification code.');
        }
        const result = await verifyCode({
            verificationRequestId: this.verificationRequestId,
            code
        });
        if (!result || result.status !== 'Verified') {
            throw new Error(result?.message || 'Verification was not completed.');
        }
        this.verificationCompleted = true;
        this.clearResendCooldownTimer();
    }

    startResendCooldown(resendAvailableAt) {
        this.clearResendCooldownTimer();
        this.resendAvailableAt = resendAvailableAt;
        const updateCooldown = () => {
            const availableAt = this.resendAvailableAt ? new Date(this.resendAvailableAt).getTime() : 0;
            const seconds = Math.max(0, Math.ceil((availableAt - Date.now()) / 1000));
            this.resendCooldownSeconds = seconds;
            if (seconds === 0) this.clearResendCooldownTimer();
        };
        updateCooldown();
        if (this.resendCooldownSeconds > 0) {
            this.resendCooldownTimer = setInterval(updateCooldown, 1000);
        }
    }

    clearResendCooldownTimer() {
        if (this.resendCooldownTimer) {
            clearInterval(this.resendCooldownTimer);
            this.resendCooldownTimer = null;
        }
        if (!this.resendAvailableAt || new Date(this.resendAvailableAt).getTime() <= Date.now()) {
            this.resendCooldownSeconds = 0;
        }
    }

    reduceError(error) {
        return this._err(error);
    }

     get showVerificationCode() {
        return Boolean(this.verificationMethod);
    }

    get isWhatsappVerificationSelected() {
        return this.verificationMethod === 'whatsapp';
    }

    get isWhatsappDisabled() {
        return true;
    }

    get isEmailVerificationSelected() {
        return this.verificationMethod === 'email';
    }

    get isSmsVerificationSelected() {
        return this.verificationMethod === 'sms';
    }

    get showEmailVerificationLoader() {
        return this.isSendingVerification && this.verificationMethod === 'email';
    }

    get showSmsVerificationLoader() {
        return this.isSendingVerification && this.verificationMethod === 'sms';
    }

    get verificationMethodLabel() {
        if (this.verificationMethod === 'email') return 'Email Verification';
        if (this.verificationMethod === 'sms') return 'SMS Verification';
        return 'WhatsApp Verification';
    }

    get verificationDestinationName() {
        if (this.verificationMethod === 'sms') return 'mobile number';
        if (this.verificationMethod === 'whatsapp') return 'WhatsApp number';
        return 'email';
    }

    get verificationDestinationText() {
        if (this.verificationMethod === 'email') {
            return `A 6-digit code has been sent to your email ${this.maskEmail(this.verificationEmailTarget)}.`;
        }
        if (this.verificationMethod === 'sms') {
            return `A 6-digit code has been sent to your mobile number ending in ${this.maskPhone(this.verificationPhoneTarget)}.`;
        }
        return `A 6-digit code has been sent to your WhatsApp number ending in ${this.maskPhone(this.verificationPhoneTarget)}.`;
    }

    get isVerificationNextDisabled() {
        return this.isLoading
            || this.isSendingVerification
            || !this.verificationRequestId
            || !this.verificationMethod
            || this.verificationDigits.some((digit) => !digit.value);
    }

    get isResendDisabled() {
        return this.isSendingVerification || this.resendCooldownSeconds > 0;
    }

    get showResendAction() {
        return !this.maxResendReached;
    }

    get resendButtonLabel() {
        return this.resendCooldownSeconds > 0
            ? `Resend available in ${this.resendCooldownSeconds}s`
            : 'Resend Code';
    }

    get isBackDisabled() {
        return this.isLoading || (this.verificationCompleted && this.step === 3);
    }
    maskPhone(value) {
        const digits = (value || '').replace(/\D/g, '');
        return digits ? `****${digits.slice(-4)}` : '****';
    }

    maskEmail(value) {
        const email = value || '';
        const [name, domain] = email.split('@');
        if (!name || !domain) return 'your registered email';
        return `${name.substring(0, 2)}***@${domain}`;
    }

    async handleVerificationResend() {
        if (!this.verificationRequestId) {
            await this.sendVerificationCode(this.verificationMethod || 'email', false);
            return;
        }
        this.errorMessage = '';
        this.isSendingVerification = true;
        try {
            const result = await resendVerification({ verificationRequestId: this.verificationRequestId });
            this.verificationMessage = result.message || `A new 6-digit code has been sent to your ${this.verificationDestinationName}.`;
            this.startResendCooldown(result.resendAvailableAt);
            this.maxResendReached = false;
            this.verificationDigits = this.verificationDigits.map((digit) => ({ ...digit, value: '' }));
            this.pendingOtpFocusIndex = 0;
        } catch (error) {
            const message = this.reduceError(error);
            this.errorMessage = message;
            if (message && message.toLowerCase().includes('maximum resend count reached')) {
                this.maxResendReached = true;
                this.verificationMessage = 'Maximum resend attempts reached. Please use the latest code received or restart verification.';
            }
        } finally {
            this.isSendingVerification = false;
        }
    }
get whatsappVerificationClass() {
        return this.verificationMethod === 'whatsapp'
            ? 'verification-option selected'
            : 'verification-option';
    }

    get emailVerificationClass() {
        return this.verificationMethod === 'email'
            ? 'verification-option selected'
            : 'verification-option';
    }

    get smsVerificationClass() {
        return this.verificationMethod === 'sms'
            ? 'verification-option selected'
            : 'verification-option';
    }
    get verificationEmailTarget() {
        return this.leadRecord?.Email || this.email;
    }

    get verificationPhoneTarget() {
        return this.leadRecord?.MobilePhone || this.mobile;
    }

get mobileStep1Class() {

    return this.currentStep === '1'
        ? 'mobileStep activeMobileStep'
        : parseInt(this.currentStep,10) > 1
            ? 'mobileStep completedMobileStep'
            : 'mobileStep';
}

get mobileStep2Class() {

    return this.currentStep === '2'
        ? 'mobileStep activeMobileStep'
        : parseInt(this.currentStep,10) > 2
            ? 'mobileStep completedMobileStep'
            : 'mobileStep';
}

get mobileStep3Class() {

    return this.currentStep === '3'
        ? 'mobileStep activeMobileStep'
        : parseInt(this.currentStep,10) > 3
            ? 'mobileStep completedMobileStep'
            : 'mobileStep';
}

get mobileStep4Class() {

    return this.currentStep === '4'
        ? 'mobileStep activeMobileStep'
        : 'mobileStep';
}
 

handleResize = () => {

    this.checkMobileView();
}

checkMobileView() {

    this.isMobileView =
        window.innerWidth <= 768;
}


handleViewEOI(event) {

    const recId =
        event.currentTarget.dataset.id;

    const foundRecord =
        this.eoiRecords.find(
            item => item.Id === recId
        );

    if(foundRecord) {

        this.selectedEOI =
            foundRecord;

        this.showEOIDetailModal =
            true;
    }
}

closeEOIDetailModal() {

    this.showEOIDetailModal = false;

    this.selectedEOI = {};
}

openVoidModal(event) {

    const recId =
        event.currentTarget.dataset.id;

    /*
        FROM TABLE
    */

    if(recId) {

        const foundRecord =
            this.eoiRecords.find(
                item => item.Id === recId
            );

        if(foundRecord) {

            this.selectedEOI =
                foundRecord;
        }
    }

    /*
        SHOW MODAL
    */

    this.showVoidModal = true;
       this.showEOIDetailModal = false;
}

closeVoidModal() {

    this.showVoidModal = false;
}

handleVoidReason(event) {

    this.voidReason =
        event.target.value;
}
async handleVoidEOI() {

    if (!this.voidReason) {

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'Please enter void reason',
                'error'
            );

        return;
    }

    this.isLoading = true;

    try {

        /*
            VOID RECORD
        */

        await voidEOI({

            eoiId:
                this.selectedEOI.Id,

            reason:
                this.voidReason
        });

        /*
            CLOSE MODAL
        */

        this.showVoidModal = false;

        /*
            IMPORTANT
            FORCE COMPLETE REFRESH
        */

        this.eoiRecords = [];

        this.paginatedRecords = [];

        await Promise.resolve();

        /*
            RELOAD FROM SERVER
        */

        await this.loadEOIRecords();

        /*
            FORCE PAGINATION
        */

        this.updatePaginatedRecords();

        /*
            FORCE LWC REACTIVITY
        */

        this.eoiRecords = [
            ...this.eoiRecords
        ];

        this.paginatedRecords = [
            ...this.paginatedRecords
        ];

        /*
            UPDATE DETAIL MODAL
        */

        if (this.showEOIDetailModal) {

            const refreshed =
                this.eoiRecords.find(
                    item =>
                        item.Id ===
                        this.selectedEOI.Id
                );

            if (refreshed) {

                this.selectedEOI =
                    {
                        ...refreshed
                    };
            }
        }

        /*
            SUCCESS
        */

        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                'EOI Voided Successfully',
                'success'
            );

        /*
            RESET
        */

        this.voidReason = '';
    }

    catch(error) {


        this.template
            .querySelector(
                'c-mbp_customshowtoast'
            )
            ?.show(
                this._err(error),
                'error'
            );
    }

    finally {

        this.isLoading = false;
    }
}
get leadProgressClass() {

    return `sfStep ${
        this.currentStep === '1'
            ? 'currentProgress'
            : this.currentStep > '1'
            ? 'completedProgress'
            : 'upcomingProgress'
    }`;
}

get otpProgressClass() {

    return `sfStep ${
        this.currentStep === '2'
            ? 'currentProgress'
            : this.currentStep > '2'
            ? 'completedProgress'
            : 'upcomingProgress'
    }`;
}

get eoiProgressClass() {

    return `sfStep ${
        this.currentStep === '3'
            ? 'currentProgress'
            : this.currentStep > '3'
            ? 'completedProgress'
            : 'upcomingProgress'
    }`;
}

get paymentProgressClass() {

    return `sfStep ${
        this.currentStep === '4'
            ? 'currentProgress'
            : 'upcomingProgress'
    }`;
}


}