/**********************************************************************************************************************
* Name               : MBP_manageLeads
* Description        : This class is used as the Apex controller for Broker Portal Lead Submission.
* Usage              : LWC components for creating and managing Broker Leads
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com      27 Oct 2025      Initial Draft – Base implementation for lead submission,
*                                                              KYC document handling, and lead validation.
 
*  1.1        Raghu.chilukuri@activemindsit.com    10 Nov 2025   Generate offer New implemation using offer Screen
*
* 1.2        upendra.asam@activemindsit.com        08 Dec 2025      Updates include:
*                                                              - KYC document upload made mandatory before submission
*                                                              - Enhanced field-level & page-level error handling for better UX
*                                                              - Added descriptive comments for maintainability
* 1.3         Raghu.chilukuri@activemindsit.com   15 dec 2025  Mobile view Enhancements Using seperate html
*
* 1.4        chandu.battu@activemindsit.com        01 feb 2026   Added Individual and organizational Lead Scenarios Into html,js and css
*1.5         raghu.chilukuri@activemindsit.com     31 mar 2026   Added Trade License and Unified Numbers and few Bug Fixes related To them 
**********************************************************************************************************************/




import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import Id from '@salesforce/user/Id';
import getUserDetails from '@salesforce/apex/MBP_BrokerLeadcontroller.getUserDetails';
import convertLeadToOpportunity from '@salesforce/apex/MBP_BrokerLeadcontroller.convertLeadToOpportunity';

import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import createLead from '@salesforce/apex/MBP_BrokerLeadcontroller.createOrUpdateLead';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklist from '@salesforce/apex/MBP_BrokerLeadcontroller.getPicklist';
import getUploadedDocuments from '@salesforce/apex/MBP_BrokerLeadcontroller.getUploadedDocuments';
import getDependentPickListValues from '@salesforce/apex/MBP_BrokerLeadcontroller.getDependentPickListValues';
import validateEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import shouldShowBrokerContent from '@salesforce/apex/MBP_BrokerAgencyInformationController.shouldShowBrokerContent';
import deleteLeadDocuments from '@salesforce/apex/MBP_BrokerLeadcontroller.deleteLeadDocuments';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import KYC_FORM from '@salesforce/resourceUrl/MBP_KYC_Form';
import MBP_EnableEoi from '@salesforce/label/c.MBP_EnableEoi';

import uploadFileToDocumentRecord from '@salesforce/apex/MBP_BrokerLeadcontroller.uploadFileToDocumentRecord';
import emailLeadsExport from '@salesforce/apex/MBP_BrokerLeadcontroller.emailLeadsExport';

import { createRecord } from 'lightning/uiRecordApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import Salutation from '@salesforce/schema/Contact.Salutation';


// New imports
import getOfferData from '@salesforce/apex/MBP_BrokerLeadcontroller.getOfferData';
import generateOfferPDF from '@salesforce/apex/MBP_BrokerLeadcontroller.generateOfferPDF';
import handleOfferAction from '@salesforce/apex/MBP_BrokerLeadcontroller.handleOfferAction';
import getRecords from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';
import makeDPGApiCall from '@salesforce/apex/UnitSearchLwcController.makeDPGApiCall';


import MBP_VatUndertakingCertificate from '@salesforce/resourceUrl/MBP_Leaduntertakingform';//For vat certificate

export default class BrokerLeads extends NavigationMixin(LightningElement) {
      enableEOI = MBP_EnableEoi === 'true';
    kycFormUrl = KYC_FORM;
    uploadedKycFileName;
    kycFile;
    uploadedKycFileName;
    uploadedSourceFundsFileName;
    sourceFundsFile;


    filterIcon = FilterIcon;
    @track isLoading = false;
    @track mobile = '';
    @track editEmailButtonLabel = 'Validate Email';
    @track editEmailValidating = false;
    @track editEmailValidated = true;

    @track editMobileButtonLabel = 'Validate Mobile';
    @track editMobileValidating = false;
    @track editMobileValidated = true;
    @track deletedFileTypes = [];
    @track deleteemiratesfilesbackside;
    @track emiratesIdFileUrl1;
    @track emiratesIdFileNamebackside;
    @track passportCopyFileNamebackside;
    @track passportCopyFileUrl1;
    @track deletepassportfilesbackside;

    tradeLicenseFileName = '';
    uploadedTradeLicenseFileName = '';
    tradeLicenseFile;
    deleteTradeLicenseFile = false;
    tradeLicenseFileUrl = '';

    @track emiratesIdFileName;
    @track isUploading = false;
    @track emiratesIdFileUrl;
    @track passportCopyFileName;
    @track passportCopyFileUrl;
    @track isManageLeadsActive = true;
    @track isManageOppsActive = false;
  @track showEOITab = false;
    @track showModal = false;
    emailValidated = false;
    mobileValidated = false;

@track pendingOpportunityId = null;

    @track showAddLeadButton = false;
    @track isLeadModalOpen = false;


    @track showUaeFields = false;
    @track showPassportFields = false;

    @track titleOptions = [];
    @track isSaving = false;
    @track company = '';

    @track emailValidated = false;
    @track mobileValidated = false;
    @track originalEmail = '';
    @track originalPhone = '';
    @track customToast = { show: false, message: '', variant: 'success' };
    @track mobileButtonLabel = 'Validate Mobile';
    @track emailButtonLabel = 'Validate Email';
    @track emailValidating = false;
    @track mobileValidating = false;
    @track projectName;
    @track numberOfBeds;
    @track unitType;

    @track Projectoptions = [];
    @track numberOfBedsOptions = [];
    @track unitTypeOptions = [];

    projectToBedsMap = {};

    projectToUnitMap = {};
    showeditModal = false;
@track isManageEOIActive = false;

    @track uaeResidentOptions = [];
    @track nationalityOptions = [];
    @track countryOfResidenceOptions = [];
    @track salesOriginOptions = [];
    @track leadOriginOptions = [];
    @track salesTypeOptions = [];
    @track propertyUsageOptions = [];
    @track buyRentOptions = [];


    @track customerBudgetOptions = [];
    @track purposeOfUseOptions = [];
    @track propertyReadinessOptions = [];
    @track financingOptions = [];

    //for vat certificate
    @track vatCertificateType = '';
    @track showVatRegNumber = false;
    @track showDummyVatLink = false;
    @track vatUploadLabel = 'VAT Registration Certificate';
    @track uploadedVatFileName = '';
    @track vatFileName = '';
    @track vatFileUrl = '';
    @track vatFile = null;
    @track deleteVatFile = false;

    // VAT options
    vatCertificateOptions = [
        { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
        { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
    ];

    //Upto above Vat certificate


    @track showUaeFields = false;

    leadTypeOptions = [
        { label: 'Individual', value: 'Individual' },
        { label: 'Organization', value: 'Organization' }
    ];

    title = ''; cc = ''; mobile = ''; firstName = ''; lastName = ''; email = '';
    uaeResidentStatus = ''; nationality = ''; countryOfResidence = ''; city = ''; emiratesId = '';
    leadOrigin = '';
    propertyUsage = ''; buyRent = ''; projectName = ''; unitType = ''; numberOfBeds = '';
    customerBudget = ''; purposeOfUse = ''; propertyReadiness = ''; financing = '';
    emiratesId = '';
    emiratesIdExpiry = '';


    passportNumber = '';
    passportIssuance = '';
    passportExpiry = '';
    @track contactId = '';
    @track accountId = '';

    @track allLeads = [];
    @track treeGridData = [];
    @track selectedLead = {};
    @track showDetails = false;
    @track showList = true;
    @track childLeads = [];
    pageSize = 10;
    @track currentPage = 1;
    @track totalPages = 0;
    @track emiratesIdExpiry = '';
    @track passportNumber = '';
    @track passportExpiry = '';
    @track isSaving = false;
    @track uploadedEmiratesFileName = '';
    @track uploadedEmiratesFileNamebackside = '';
    @track uploadedPassportFileNamebackside = '';
    @track uploadedPassportFileName = '';
    emiratesFile;
    passportFile;
    @track uploadedEmiratesFileName = '';
    @track uploadedPassportFileName = '';
    userId = Id;
    @track showCustomToast = false;
    @track customToastTitle = '';
    @track customToastMessage = '';
    @track customToastVariant = '';

    @track leadType = 'Individual';
    @track orgName = '';
    @track tradeNumber = '';
    @track unifiedNumber = '';
     @track uaevatregisternumber = '';


    // Resource URLs
    kycFormUrl = KYC_FORM;
    filterIcon = FilterIcon;
    toast;

    // User and account properties
    userId = Id;
    @track contactId = '';
    @track accountId = '';
    @track brokerType = '';
    @track brokerAgentName = '';
    @track brokerAgentMobile = '';

    // Loading states
    @track isLoading = false;
    @track isSaving = false;
    @track isUploading = false;
    @track isGeneratingOffer = false;
    @track isStepOneLoading = false;
    @track isStepTwoLoading = false;
    @track isStepThreeLoading = false;

    // Tab management
    @track isManageLeadsActive = true;
    @track isManageOppsActive = false;
    @track showOpportunityTab = false;

    // Modal states
    @track showModal = false;
    @track showeditModal = false;
    @track isLeadModalOpen = false;
    @track showUnitSearchModal = false;
    @track isPreviewOpen = false;

    // Form fields
    title = ''; cc = ''; mobile = ''; firstName = ''; lastName = ''; email = '';
    uaeResidentStatus = ''; nationality = ''; countryOfResidence = ''; city = ''; emiratesId = '';
    leadOrigin = ''; propertyUsage = ''; buyRent = ''; projectName = ''; unitType = ''; numberOfBeds = '';
    customerBudget = ''; purposeOfUse = ''; propertyReadiness = ''; financing = '';
    emiratesIdExpiry = ''; passportNumber = ''; passportIssuance = ''; passportExpiry = '';
    salesOrigin = ''; salesType = '';

    // Validation states
    @track emailValidated = false;
    @track mobileValidated = false;
    @track originalEmail = '';
    @track originalPhone = '';
    @track emailButtonLabel = 'Validate Email';
    @track mobileButtonLabel = 'Validate Mobile';
    @track emailValidating = false;
    @track mobileValidating = false;
    @track editEmailButtonLabel = 'Validate Email';
    @track editMobileButtonLabel = 'Validate Mobile';
    @track editEmailValidating = false;
    @track editMobileValidating = false;
    @track editEmailValidated = true;
    @track editMobileValidated = true;

    // Field visibility
    @track showUaeFields = false;
    @track showPassportFields = false;
    @track showAddLeadButton = false;

    // Picklist options
    @track titleOptions = [];
    @track uaeResidentOptions = [];
    @track nationalityOptions = [];
    @track countryOfResidenceOptions = [];
    @track salesOriginOptions = [];
    @track leadOriginOptions = [];
    @track salesTypeOptions = [];
    @track propertyUsageOptions = [];
    @track buyRentOptions = [];
    @track customerBudgetOptions = [];
    @track purposeOfUseOptions = [];
    @track propertyReadinessOptions = [];
    @track financingOptions = [];
    @track Projectoptions = [];
    @track numberOfBedsOptions = [];
    @track unitTypeOptions = [];

    // Project mappings
    projectToBedsMap = {};
    projectToUnitMap = {};

    // Lead management
    @track allLeads = [];
    @track treeGridData = [];
    @track selectedLead = {};
    @track selectedLeads = [];
    @track childLeads = [];
    @track showDetails = false;
    @track showList = true;

    // Pagination
    pageSize = 10;
    @track currentPage = 1;
    @track totalPages = 0;

    // File uploads
    @track uploadedKycFileName = '';
    @track uploadedSourceFundsFileName = '';
    @track uploadedEmiratesFileName = '';
    @track uploadedEmiratesFileNamebackside = '';
    @track uploadedPassportFileName = '';
    @track uploadedPassportFileNamebackside = '';

    kycFile; sourceFundsFile; emiratesFile; emiratesFilebackside; passportFile; passportFilebackside;

    @track emiratesIdFileUrl; emiratesIdFileUrl1; passportCopyFileUrl; passportCopyFileUrl1;
    @track kycFileUrl; sourceFundsFileUrl;

    @track deletedFileTypes = [];
    @track deleteemiratesfiles = false;
    @track deleteemiratesfilesbackside = false;
    @track deletepassportfiles = false;
    @track deletepassportfilesbackside = false;
    @track deleteKycFile = false;
    @track deleteSourceFundsFile = false;

    // Toast messages
    @track showCustomToast = false;
    @track customToastTitle = '';
    @track customToastMessage = '';
    @track customToastVariant = '';

    // Unit search and selection
    @track showUnitsFilterBox = false;
    @track unitFilters = {
        projectName: '',
        unitType: '',
        bedrooms: '',
        status: ''
    };
    @track filteredUnits = [];
    @track units = [];
    @track selectedUnits = [];
    @track selectedUnitsData = [];
    @track activeUnitIndex = 0;
    @track isUnitSearchDisabled = true;

    // Filter options
    @track projectFilterOptions = [{ label: 'All', value: '' }];
    @track unitTypeFilterOptions = [{ label: 'All', value: '' }];
    @track bedroomsFilterOptions = [{ label: 'All', value: '' }];
    @track statusFilterOptions = [];

    // Payment plans
    @track showPaymentPlan = false;
    @track showPaymentDetails = false;
    @track selectedPaymentPlan = '';
    @track paymentPlanOptions = [];
    @track paymentPlanDetails = null;
    @track installments = [];

    // Offer generation
    @track currentStep = 1;
    @track selectedDesign = '';
    @track alNaseemDesignOptions = [
        { label: "South California", value: "South California" },
        { label: "Contemporary", value: "Contemporary" }
    ];
    @track offerPdfUrl = '';
    @track previewError = '';
    @track offerGenerationResults = [];

    // Progress steps
    @track progressSteps = [
        { label: 'Select Units', value: 1 },
        { label: 'Payment Plan', value: 2 },
        { label: 'Generate Offer', value: 3 }
    ];

    // Preview management
    @track unitPreviewUrls = {};
    @track activePreviewUnitId = '';
    @track activePreviewUnitName = '';
    @track activePreviewUrl = '';
    @track hasActivePreview = false;
    @track disablePreviewActions = true;

    // Preselected units
    @track preselectedUnits = [];
    @track hasPreselectedUnits = false;
    @track pendingUnitData = null;

    // Pagination for units
    @track currentUnitsPage = 1;
    @track unitsPageSize = 5;
    @track totalUnitsPages = 0;
    @track paginatedUnits = [];

    // Validation errors
    @track showUnitValidationError = false;
    @track showFacadeValidationError = false;
    @track showUnavailableUnitsError = false;
    @track unavailableUnitsMessage = '';

    // Lead details
    @track selectedLeadDetails = {};
    @track leadIdBeingEdited = '';

    // Filter management
    @track showFilterBox = false;
    @track filters = {
        searchKey: '',
        status: '',
        startDate: '',
        endDate: ''
    };

    @track isMobileView = false;
    @track mobileLeads = [];
    @track mobileCurrentPage = 1;
    @track mobilePageSize = 5;
    @track mobileTotalPages = 0;
    @track showMobileFilter = false;
    @track showMobileAddModal = false;
    @track showMobileEditModal = false;
    @track showMobileGenerateOfferModal = false;
    @track selectedMobileLeads = [];
    @track mobileSelectedLeadId = '';
    @track isPdfLoading = false;
    @track showMobileLeadDetails = false;


    childColumns = [
        { label: 'Project Name', fieldName: 'ProjectInterest__c', type: 'text' },

        { label: 'Unit Type', fieldName: 'UnitType__c', type: 'text' },


        { label: 'Lead Number', fieldName: 'LeadNumber', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        {
            label: 'Edit',
            type: 'button-icon',
            fieldName: 'editAction', 
            fixedWidth: 40,
            typeAttributes: {
                iconName: 'utility:edit',
                name: 'editChildLead',
                variant: 'bare',
                alternativeText: 'Edit Lead'
            },
            cellAttributes: {
                class: { fieldName: 'editIconClass' } 
            }
        }
    ];




    columns = [
        {
            type: 'checkbox',
            typeAttributes: {
                checked: { fieldName: 'isSelected' }
            }
        },
        { label: 'S.No', fieldName: 'SNo', type: 'number', initialWidth: 70 },
        {
            label: 'Lead Number',
            fieldName: 'LeadNumber',
            type: 'text',
            cellAttributes: { class: { fieldName: 'rowClass' } }
        },
        {
            label: 'Title',
            fieldName: 'Title',
            type: 'text',
            cellAttributes: { class: { fieldName: 'rowClass' } }
        },
        {
            label: 'First Name',
            fieldName: 'FirstName',
            type: 'richText'
        },
        {
            label: 'Last Name',
            fieldName: 'LastName',
            type: 'richText'
        },
        {
            label: 'Email',
            fieldName: 'Email',
            type: 'text',
            cellAttributes: { class: { fieldName: 'rowClass' } }
        },
        {
            label: 'Mobile',
            fieldName: 'Mobile',
            type: 'richText'
        },
        {
            label: 'Description',
            fieldName: 'Description',
            type: 'text',
            wrapText: true
        }
        ,
        {
            label: 'Status',
            fieldName: 'Status',
            type: 'text',
            cellAttributes: { class: { fieldName: 'rowClass' } }
        },
        {
    type: 'button',
    label: '',
    fixedWidth: 140,
    typeAttributes: {
        label: { fieldName: 'bookUnitLabel' },
        name: 'bookUnit',
        iconName: { fieldName: 'bookUnitIcon' },
        iconPosition: 'left',
        variant: 'brand',
        disabled: { fieldName: 'bookUnitDisabled' }
    },
    cellAttributes: {
        class: { fieldName: 'rowClass' }
    }
},
        {
            type: 'button-icon',
            fixedWidth: 40,
            typeAttributes: {
                iconName: { fieldName: 'eyeIcon' },
                name: 'viewDetails',
                variant: 'bare',
                alternativeText: 'View'
            },
            cellAttributes: {
                class: { fieldName: 'rowClass' }
            }
        }
    ];

    prepareTreeGridData(leads) {
        let counter = 1;
        this.treeGridData = leads.map(lead => {
            return {
                ...lead,
                SNo: counter++, 
                isSelected: false 
            };
        });
    }


    get todayDate() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    connectedCallback() {

        const today = new Date();
        const startOfYear = new Date(today.getFullYear(), 0, 1);

        // Helper to format as YYYY-MM-DD
        function formatDate(date) {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0'); // months are 0-based
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        }

        this.filters.startDate = formatDate(startOfYear);
        this.filters.endDate = formatDate(today);

        const shouldOpenModal = sessionStorage.getItem('triggerAddLeadModal');
        if (shouldOpenModal === 'true') {
            this.openleadmodal();
            sessionStorage.removeItem('triggerAddLeadModal');
        }
        this.loadDependencies();
        // this.loadLeads();
        this.checkPermissionAndHide();
        this.loadPicklist('Lead', 'Salutation', 'titleOptions');
        this.loadPicklist('Lead', 'UAEResidentStatus__c', 'uaeResidentOptions');
        this.loadPicklist('Lead', 'Nationality__c', 'nationalityOptions');
        this.loadPicklist('Lead', 'CountryOfResidence__c', 'countryOfResidenceOptions');
        this.loadPicklist('Lead', 'SalesOrigin__c', 'salesOriginOptions');
        this.loadPicklist('Lead', 'LeadOrigin__c', 'leadOriginOptions');
        this.loadPicklist('Lead', 'SalesType__c', 'salesTypeOptions');
        this.loadPicklist('Lead', 'PropertyUsage__c', 'propertyUsageOptions');
        this.loadPicklist('Lead', 'BuyRent__c', 'buyRentOptions');


        this.loadPicklist('Lead', 'CustomerBudget__c', 'customerBudgetOptions');
        this.loadPicklist('Lead', 'PurposeOfUse__c', 'purposeOfUseOptions');
        this.loadPicklist('Lead', 'PropertyReadiness__c', 'propertyReadinessOptions');
        this.loadPicklist('Lead', 'Finance__c', 'financingOptions');

        //this.orgRecordTypeId = '012U7000004EDfpIAG';  // Organisation_Lead
        //this.personRecordTypeId = '012U7000004EDCoIAO'; // Person_Lead



        getUserDetails({ userId: this.userId })
            .then(user => {
                this.brokerType = user?.Contact?.Broker_Type__c;
                this.contactId = user?.Contact?.Id;
                this.accountId = user?.Contact?.AccountId;
                this.brokerAgentName = user?.Contact?.Name;
                this.brokerAgentMobile = user?.Contact?.Phone;

                this.salesType = 'Residential sale';
                this.salesOrigin = 'International';

                if (this.brokerType === 'Owner' || this.brokerType === 'Agent') {
                    this.showAddLeadButton = true;
                } else {
                    this.showAddLeadButton = false;
                }

                this.loadLeads(); 
                this.checkForPreSelectedUnits();
            })
            .catch(() => {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Unable to fetch user details',
                    'error'
                );
            });
        // Mobile
        this.checkMobileView();
        window.addEventListener('resize', () => this.checkMobileView());

    }
    handleKycFileUpload(event) {
        const file = event.target.files[0];
        this.uploadedKycFileName = file ? file.name : '';
        this.kycFile = file;
    }

    handleDeleteKycFile() {
        this.uploadedKycFileName = null;
        this.kycFile = null;
    }

    handleSourceFundsFileUpload(event) {
        const file = event.target.files[0];
        this.uploadedSourceFundsFileName = file ? file.name : '';
        this.sourceFundsFile = file;
    }

    handleDeleteSourceFundsFile() {
        this.uploadedSourceFundsFileName = null;
        this.sourceFundsFile = null;
    }

    handleDeleteEmiratesFile() {
        this.uploadedEmiratesFileName = '';
        this.emiratesFile = null;
    }
    handleDeleteEmiratesFilebackside() {
        this.uploadedEmiratesFileNamebackside = '';
        this.emiratesFile = null;
    }

    handleDeletePassportFile() {
        this.uploadedPassportFileName = '';
        this.passportFile = null;
    }
    handleDeletePassportFilebackside() {
        this.uploadedPassportFileNamebackside = '';
        this.passportFile = null;
    }
    /* Version 1.1  starts*/
    openAddLeadModal() {
        if (!this.brokerAgentMobile) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please update your mobile number in your profile and then try creating a lead.',
                'error'
            );
            return; 
        }

        this.resetFormFields();
        this.showModal = true;
    }

    /* Version 1.1  ends*/
    openleadmodal() {
        this.isLeadModalOpen = true;
    }

    closeleadmodal() {
        this.isLeadModalOpen = false;
    }
    resetFormFields() {
        this.title = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.mobile = '';
        this.uaeResidentStatus = '';
        this.countryOfResidence = '';
        this.nationality = '';
        this.salesOrigin = '';
        this.leadOrigin = '';
        this.salesType = '';
        this.projectName = '';
        this.propertyUsage = '';
        this.numberOfBeds = '';
        this.unitType = '';
        this.buyRent = '';
        this.purposeOfUse = '';
        this.customerBudget = '';
        this.propertyReadiness = '';
        this.financing = '';
        this.company = '';
        this.orgName = '';
        // this.tradeNumber = '';
        this.unifiedNumber = '';
         this.uaevatregisternumber = '',


        // Document fields
        this.emiratesId = '';
        this.emiratesIdExpiry = '';
        this.passportNumber = '';
        this.passportIssuance = '';
        this.passportExpiry = '';

        // Uploaded files
        this.uploadedEmiratesFileName = '';
        this.uploadedEmiratesFileNamebackside = '';
        this.uploadedPassportFileName = '';
        this.uploadedPassportFileNamebackside = '';

        // Validation button states
        this.emailValidating = false;
        this.mobileValidating = false;
        this.emailButtonLabel = 'Validate Email';
        this.mobileButtonLabel = 'Validate Mobile';

        // Visibility
        this.showUaeFields = false;
        this.showPassportFields = false;


        this.vatCertificateType = '';
        this.showVatRegNumber = false;
        this.showDummyVatLink = false;
        this.vatUploadLabel = 'VAT Registration Certificate';
        this.uploadedVatFileName = '';
        this.vatFileName = '';
        this.vatFileUrl = '';
        this.vatFile = null;
        this.deleteVatFile = false;

        //  Reset file input UI fields
        const fileInputs = this.template.querySelectorAll('lightning-input[type="file"]');
        fileInputs.forEach(input => {
            input.value = null;
        });
    }


  async checkPermissionAndHide() {
    try {
        const result = await shouldShowBrokerContent();

        // Existing Opportunity logic
        this.showOpportunityTab = result;

        // NEW: Show EOI tab also for Fast Track SR
        this.showEOITab = result && this.enableEOI;

    } catch (error) {
        console.error(' Error checking permission:', error);

        this.showOpportunityTab = false;
        this.showEOITab = false;
    }
}


    get manageLeadsTabClass() {
        return this.isManageLeadsActive ? 'tab-button active' : 'tab-button';
    }

    get manageOppTabClass() {
        return this.isManageOppsActive ? 'tab-button active' : 'tab-button';
    }

get manageEOITabClass() {

    return this.isManageEOIActive
        ? 'tab-button active'
        : 'tab-button';
}
  // Open the correct tab when navigated here as /Leads?view=opportunities|eoi|leads.
  // The header menu (Manage Leads / Manage Opportunities / EOI) deep-links to this
  // page with a view param, since those are tabs here rather than separate pages.
  @wire(CurrentPageReference)
  handlePageReference(pageRef) {
      if (pageRef) {
          this.applyViewParam(pageRef.state ? pageRef.state.view : null);
      }
  }

  applyViewParam(view) {
      switch ((view || '').toLowerCase()) {
          case 'opportunities':
          case 'opps':
              this.showManageOpps();
              break;
          case 'eoi':
              this.showManageEOI();
              break;
          case 'leads':
          default:
              // No (or unknown) view param -> default to the Manage Leads tab.
              this.showManageLeads();
              break;
      }
  }

 showManageLeads() {
    this.isManageLeadsActive = true;
    this.isManageOppsActive = false;
    this.isManageEOIActive = false;
    this.updateUrlView('leads');
}

showManageOpps() {
    this.isManageLeadsActive = false;
    this.isManageOppsActive = true;
    this.isManageEOIActive = false;
    this.updateUrlView('opportunities');
}

showManageEOI() {
    if (!this.enableEOI) {
        return;
    }
    this.isManageLeadsActive = false;
    this.isManageOppsActive = false;
    this.isManageEOIActive = true;
    this.updateUrlView('eoi');
}

// Keeps the address bar (and any bookmark) in sync with whichever tab is active,
// without forcing a full page reload.
updateUrlView(view) {
    const url = new URL(window.location.href);
    if (url.searchParams.get('view') === view) {
        return; // already correct, avoid pushing a duplicate history entry
    }
    url.searchParams.set('view', view);
    window.history.pushState({ view }, '', url.toString());
}
    loadLeads() {
        this.isLoading = true;

        getFilteredLeads({
            userId: this.userId,
            filterType: this.selectedFilter,
            startDate: null,
            endDate: null
        })

            .then(data => {
                this.allLeads = data;
                this.totalPages = Math.ceil(data.length / this.pageSize);

                //mobile
                this.updateMobileLeads();

                // Update both desktop and mobile views
                this.updateTreeGridData();
            })
            .catch(error => {
                console.error(' Error fetching leads:', error);
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Unable to fetch leads',
                    'error'
                );

            })
            .finally(() => {
                this.isLoading = false; 
            });
    }



    @track showFilterBox = false;

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    toggleFilterBox() {
        this.showFilterBox = !this.showFilterBox;
    }

    @track filters = {
        searchKey: '',
        status: '',
        startDate: '',
        endDate: ''
    };

    resetFilters() {
        // Get today's date and start of year
        const today = new Date();
        const startOfYear = new Date(today.getFullYear(), 0, 1); // January 1st

        // Helper function to format as YYYY-MM-DD
        const formatDate = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        };

        this.filters = {
            searchKey: '',
            status: '',
            stage: '',
            startDate: formatDate(startOfYear),
            endDate: formatDate(today)
        };

        this.loadLeads();
    }

    statusOptions = [
        { label: 'All', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Qualified', value: 'Qualified' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Lead Qualified', value: 'Lead Qualified' },
        { label: 'Retired', value: 'Retired' }
    ];


    handleFilterChange(event) {
        const field = event.target.dataset.id;
        this.filters[field] = event.target.value;
    }


    applyFilters() {
        let filtered = [...this.allLeads];

        // Status filter
        if (this.filters.status) {
            filtered = filtered.filter(l =>
                l.Status?.toLowerCase() === this.filters.status.toLowerCase()
            );
        }

        //  Fuzzy filter for multiple fields
        if (this.filters.searchKey) {
            const key = this.filters.searchKey.toLowerCase();
            filtered = filtered.filter(l =>
                (l.LeadNumber && l.LeadNumber.toLowerCase().includes(key)) ||
                (l.Mobile && l.Mobile.toLowerCase().includes(key)) ||
                (l.Email && l.Email.toLowerCase().includes(key)) ||
                (l.FirstName && l.FirstName.toLowerCase().includes(key)) ||
                (l.LastName && l.LastName.toLowerCase().includes(key))
            );
        }

        if (this.filters.startDate || this.filters.endDate) {
            this.isLoading = true;

            getFilteredLeads({
                userId: this.userId,
                filterType: null, 
                startDate: this.filters.startDate,
                endDate: this.filters.endDate
            })
                .then(data => {
                    this.allLeads = data;
                    filtered = [...data]; 

                    if (this.filters.status) {
                        filtered = filtered.filter(l =>
                            l.Status?.toLowerCase() === this.filters.status.toLowerCase()
                        );
                    }

                    if (this.filters.searchKey) {
                        const key = this.filters.searchKey.toLowerCase();
                        filtered = filtered.filter(l =>
                            (l.LeadNumber && l.LeadNumber.toLowerCase().includes(key)) ||
                            (l.Mobile && l.Mobile.toLowerCase().includes(key)) ||
                            (l.Email && l.Email.toLowerCase().includes(key)) ||
                            (l.FirstName && l.FirstName.toLowerCase().includes(key)) ||
                            (l.LastName && l.LastName.toLowerCase().includes(key))
                        );
                    }

                    this.totalPages = Math.ceil(filtered.length / this.pageSize);
                    this.currentPage = 1;
                    this.treeGridData = filtered.slice(0, this.pageSize);

                    // Mobile
                    this.updateMobileLeads();
                })
                .catch(error => {
                    console.error('Error fetching filtered leads:', error);
                    this.showToast('Unable to filter leads', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });

            return; 
        }

        this.showFilterBox = false;
        this.totalPages = Math.ceil(filtered.length / this.pageSize);
        this.currentPage = 1;
        this.treeGridData = filtered.slice(0, this.pageSize);

        // Mobile
        this.updateMobileLeads();
    }

handleExport() {
    try {
        if (!this.allLeads || this.allLeads.length === 0) {
            console.warn('No data available for export.');
            this._safeToast('No data to export', 'Warning');
            return;
        }

        this._exportViaDownload();

    } catch (e) {
        console.error('❌ handleExport crashed:', e);
        console.error('Stack:', e?.stack);
        this._safeToast('Something went wrong starting the export.', 'error');
    }
}

// ── Safe toast helper — never throws even if the toast component isn't mounted ──
_safeToast(message, variant) {
    try {
        const toast = this.template.querySelector('c-mbp_customshowtoast');
        if (toast) {
            toast.show(message, variant);
        } else {
            console.warn('Toast component not found in DOM. Message was:', message);
        }
    } catch (e) {
        console.error('Toast itself failed:', e);
    }
}

// ── Detect Salesforce Mobile Publisher native app shell ─────────────────────
get isMobilePublisherApp() {
    try {
        const ua = navigator.userAgent || '';
        const looksLikeMobilePublisher = (
            ua.includes('SalesforceMobileSDK') ||
            ua.includes('Mobile Publisher') ||
            ua.includes('MobilePublisher') ||
            typeof window.cordova !== 'undefined' ||
            typeof window.SalesforceMobileSDK !== 'undefined'
        );
        const isStandalone = !!(window.matchMedia &&
            window.matchMedia('(display-mode: standalone)').matches);
        return looksLikeMobilePublisher || isStandalone;
    } catch (e) {
        console.error('isMobilePublisherApp check failed:', e);
        return true; // fail toward email — it degrades gracefully everywhere
    }
}

// ── Path 1: Regular browser / Experience Cloud webview → instant download ───
_exportViaDownload() {
    try {
        const exportData = this._buildExportData();
        const csv = this.convertToCSV(exportData);

        // Avoid Blob entirely — some WebViews reject Blob's MIME type validation.
        // A raw data: URI bypasses that validation path completely.
        const encodedCsv = encodeURIComponent(csv);
        const dataUri = 'data:text/plain;charset=utf-8,' + encodedCsv;

        const link = document.createElement('a');
        link.href = dataUri;
        link.setAttribute('download', 'LeadsExport.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        this._safeToast('Export downloaded', 'success');
        this.updateMobileLeads();
    } catch (e) {
        console.error('_exportViaDownload failed:', e);
        this._safeToast('Download failed: ' + (e?.message || 'Unknown error'), 'error');
    }
}

// ── Path 2: Mobile Publisher native app → email the CSV (no file system access) ──
_exportViaEmail() {
    let exportData;
    try {
        exportData = this._buildExportData();
    } catch (e) {
        console.error('_buildExportData failed:', e);
        this._safeToast('Failed to prepare export data.', 'error');
        return;
    }

    this.isLoading = true;

    emailLeadsExport({ leadsJson: JSON.stringify(exportData) })
        .then(() => {
            this._safeToast('Export emailed to your registered email address', 'success');
        })
        .catch(error => {
            console.error('emailLeadsExport failed:', JSON.stringify(error));
            let errorMsg = 'Export failed. Please try again.';
            if (error?.body?.message) {
                errorMsg = error.body.message;
            } else if (error?.body?.pageErrors?.length > 0) {
                errorMsg = error.body.pageErrors[0].message;
            } else if (error?.message) {
                errorMsg = error.message;
            }
            this._safeToast(errorMsg, 'error');
        })
        .finally(() => {
            this.isLoading = false;
            this.updateMobileLeads();
        });
}

_buildExportData() {
    return this.allLeads.map(lead => ({
        LeadNumber: lead.LeadNumber,
        Title: lead.Title,
        FirstName: lead.FirstName,
        LastName: lead.LastName,
        Email: lead.Email,
        Mobile: lead.Mobile,
        Description: lead.Description,
        Status: lead.Status
    }));
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


    loadPicklist(obj, field, destProp) {
        getPicklist({ objectName: obj, fieldName: field })
            .then(data => {
                this[destProp] = data.values.map(v => ({ label: v, value: v }));
            })
            .catch(error => console.error(field, error));
    }

    openModal() {
        this.showModal = true;
    }
    haldemodal() {
        this.showModal = true;
    }
    closeModal() {
        this.showModal = false;
    }
    closeModal1() {
        this.showeditModal = false;
    }

    handleUaeChange(event) {
        this.uaeResidentStatus = event.detail.value;

        // Always show passport fields for both Resident & Non-Resident
        this.showPassportFields = true;

        if (this.uaeResidentStatus === 'Resident') {
            this.showUaeFields = true;        // Show EID
        } else {
            this.showUaeFields = false;       // Hide EID
        }

        // Reset fields when status changes
        this.emiratesId = '';
        this.emiratesIdExpiry = '';
        this.passportNumber = '';
        this.passportIssuance = '';
        this.passportExpiry = '';
        this.uploadedEmiratesFileName = '';
        this.uploadedEmiratesFileNamebackside = '';
        this.uploadedPassportFileName = '';
        this.uploadedPassportFileNamebackside = '';

    }


    loadDependencies() {
        // Get Project -> Beds mapping
        getDependentPickListValues({
            objectName: 'Lead',
            controllingField: 'ProjectInterest__c',
            dependentField: 'NumberOfBedrooms__c'
        }).then(data => {
            this.projectToBedsMap = data;
            this.Projectoptions = Object.keys(data).map(k => ({ label: k, value: k }));
        });

        // Get Beds -> Unit Type mapping
        getDependentPickListValues({
            objectName: 'Lead',
            controllingField: 'ProjectInterest__c',
            dependentField: 'UnitType__c'
        }).then(data => {
            this.projectToUnitMap = data;
        });
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
    const clickedRow = event.detail.row;

    if (actionName === 'bookUnit') {
        this.handleBookUnit(clickedRow);
        return;
    }


        const fullParent = this.allLeads.find(item => item.Id === clickedRow.Id);

        if (fullParent) {
            // Set selected lead for modal/form if needed
            this.selectedLead = {
                Id: fullParent.Id,
                FirstName: fullParent.FirstName || '',
                LastName: fullParent.LastName || '',
                Salutation: fullParent.Title || '',
                PurposeOfUse__c: fullParent.PurposeOfUse || '',
                Description: fullParent.Description,
                Email: fullParent.Email || '',
                Mobile: fullParent.Mobile || '',
                Status: fullParent.Status || '',
                LeadNumber: fullParent.LeadNumber || '',
                ProjectInterest__c: fullParent.ProjectInterest__c || '',
                PropertyUsage__c: fullParent.PropertyUsage__c || '',
                UnitType__c: fullParent.UnitType__c || '',
                BuyRent__c: fullParent.BuyRent__c || '',
                Finance__c: fullParent.Finance__c || '',
                PassportNumber: fullParent.PassportNumber || '',
                passportIssuance: fullParent.passportIssuance || '',
                PassportExpiryDate: fullParent.PassportExpiryDate || '',
                PassportIssueDate: fullParent.PassportIssueDate || '',
                EIDNumber: fullParent.EIDNumber || '',
                EmiratesIDExpiryDate: fullParent.EmiratesIDExpiryDate || ''
            };

            if (fullParent.children && fullParent.children.length > 0) {
                this.childLeads = fullParent.children.map(child => {

                    const isEditable =
                        child.Status !== 'Qualified' &&
                        child.CreatedById === this.userId &&
                        this.brokerType !== 'Agency Admin';
                    return {
                        Id: child.Id,
                        //Update version 1.5
                        Type: child.LeadType || 'Individual',
                        TradeNumber: child.TradeNumber || '',
                        UnifiedNumber: child.UnifiedNumber || '',
                        uaevatregisternumber :child.uaevatregisternumber ||'',
                        vatCertificateType: child.vatCertificateType || '',   // ADD THIS LINE
                        //Update Version 1.5 Ends Here
                        Title: child.Title || '',
                        ProjectInterest__c: child.ProjectInterest || '',
                        PropertyUsage__c: child.PropertyUsage || '',
                        BuyRent__c: child.BuyRent || '',
                        Finance__c: child.Finance || '',
                        LeadNumber: child.LeadNumber || '',
                        Status: child.Status || '',
                        eyeIcon: 'utility:edit',
                        editIconClass: isEditable ? 'slds-show' : 'slds-hide',
                        CreatedById: child.CreatedById, //  Store for future comparison
                        FirstName: child.FirstName || '',
                        LastName: child.LastName || '',
                        Description: child.Description,
                        Email: child.Email || '',
                        Mobile: child.Mobile || '',
                        PassportNumber__c: child.PassportNumber || '',
                        PassportExpiryDate__c: child.PassportExpiryDate || '',
                        PassportIssueDate__c: child.PassportIssueDate || '',
                        EIDNumber__c: child.EIDNumber || '',
                        EmiratesIDExpiryDate__c: child.EmiratesIDExpiryDate || '',
                        UAEResidentStatus__c: child.UAEResidentStatus || '',
                        MailingCountry: child.MailingCountry || '',
                        Nationality__c: child.Nationality || '',
                        SalesOrigin__c: child.SalesOrigin || '',
                        LeadSource: child.LeadSource || '',
                        SalesType__c: child.SalesType || '',
                        NumberOfBedrooms__c: child.NumberOfBedrooms || '',
                        UnitType__c: child.UnitType || '',
                        PurposeOfUse__c: child.PurposeOfUse || '',
                        CustomerBudget__c: child.CustomerBudget || '',
                        PropertyReadiness__c: child.PropertyReadiness || '',
                        CountryOfResidence__c: child.CountryOfResidence || '',
                        LeadOrigin__c: child.LeadOrigin || ''
                    };
                });
            } else {
                this.childLeads = [{
                    Id: fullParent.Id,
                    //Update version 1.5
                    Type: fullParent.LeadType || 'Individual',
                    TradeNumber: fullParent.TradeNumber || '',
                    UnifiedNumber: fullParent.UnifiedNumber || '',
                    uaevatregisternumber: fullParent.uaevatregisternumber || '',
                    vatCertificateType: fullParent.vatCertificateType || '',   // ADD THIS LINE
                    //update version 1.5
                    ProjectInterest__c: fullParent.ProjectInterest || '',
                    PropertyUsage__c: fullParent.PropertyUsage || '',
                    UnitType__c: fullParent.UnitType || '',
                    BuyRent__c: fullParent.BuyRent || '',
                    Finance__c: fullParent.Finance || '',
                    LeadNumber: fullParent.LeadNumber || '',
                    Status: fullParent.Status || '',
                    eyeIcon: 'utility:edit',
                    editIconClass: isEditable ? 'slds-show' : 'slds-hide',
                    CreatedById: fullParent.CreatedById,
                    FirstName: fullParent.FirstName || '',
                    LastName: fullParent.LastName || '',
                    Salutation: fullParent.Title || '',
                    Email: fullParent.Email || '',
                    Mobile: fullParent.Mobile || '',
                    PassportNumber: fullParent.PassportNumber || '',
                    PassportExpiryDate: fullParent.PassportExpiryDate || '',
                    PassportIssueDate: fullParent.PassportIssueDate || '',
                    EIDNumber: fullParent.EIDNumber || '',
                    EmiratesIDExpiryDate: fullParent.EmiratesIDExpiryDate || '',
                    UAE_Resident_Status__c: fullParent.UAE_Resident_Status__c || '',
                    MailingCountry: fullParent.MailingCountry || '',
                    Nationality__c: fullParent.Nationality__c || '',
                    SalesOrigin__c: fullParent.SalesOrigin || '',
                    LeadSource: fullParent.LeadSource || '',
                    Sales_Type__c: fullParent.Sales_Type__c || '',
                    NumberOfBedrooms__c: fullParent.Number_Of_Beds__c || '',
                    PurposeOfUse__c: fullParent.PurposeOfUse || '',
                    CustomerBudget__c: fullParent.Customer_Budget__c || '',
                    Property_Readiness__c: fullParent.Property_Readiness__c || '',
                    CountryOfResidence__c: fullParent.CountryOfResidence || '',
                    UAEResidentStatus__c: fullParent.UAEResidentStatus || ''
                }];
            }
        } else {
            console.warn(' Full parent lead not found.');
            this.selectedLead = {};
            this.childLeads = [];
        }

        this.showDetails = true;
        this.showList = false;
    }

async handleBookUnit(row) {
    if (!row || !row.Id || row.rowClass !== 'child-row') {
        return; // safety guard — only child (per-unit) rows are bookable
    }

    this.isLoading = true;
    try {
        const opportunityId = await convertLeadToOpportunity({ leadId: row.Id });

        this.template.querySelector('c-mbp_customshowtoast')?.show(
            'Unit booked successfully! Opening opportunity...',
            'success'
        );

        this.pendingOpportunityId = opportunityId;
        this.showManageOpps(); // existing method — switches tab + updates URL
    } catch (error) {
        console.error('Error converting lead to opportunity:', error);
        this.template.querySelector('c-mbp_customshowtoast')?.show(
            this.getErrorMessage(error),
            'error'
        );
    } finally {
        this.isLoading = false;
    }
}



    handleChange(event) {
        const name = event.target.name;
        const value = event.detail?.value ?? event.target.value;
        this[name] = value;

        if (name === 'orgName' && this.leadType === 'Organization') {
            this.company = value;
        }

        if (name === 'leadType') {
            if (value === 'Organization') {
               // this.firstName = 'NA';    
                this.title = '';
                this.company = this.orgName || '';
            } else if (value === 'Individual') {
                // Clear organization fields
                this.orgName = '';
                this.company = '';
                // this.tradeNumber = '';
                this.unifiedNumber = '';
                this.firstName = '';
                 this.uaevatregisternumber = '';
            }
        }

        if (name === 'email') {
            this.emailButtonLabel = 'Validate Email';
            this.emailValidating = false;
            this.emailValidated = false;
        }

        // === Create Mode: Mobile ===
        else if (name === 'mobile') {
            this.mobileButtonLabel = 'Validate Mobile';
            this.mobileValidating = false;
            this.mobileValidated = false;
        }

        // === Edit Mode: Email ===
        else if (name === 'editEmail') {
            this.editEmailButtonLabel = 'Validate Email';
            this.editEmailValidating = false;
            this.editEmailValidated = false;
        }

        // === Edit Mode: Mobile ===
        else if (name === 'editMobile') {
            this.editMobileButtonLabel = 'Validate Mobile';
            this.editMobileValidating = false;
            this.editMobileValidated = false;
        }

        else if (name === 'projectName') {
            const bedOptions = (this.projectToBedsMap && this.projectToBedsMap[value]) || [];
            if (!Array.isArray(bedOptions)) {
                console.error(` bedOptions for '${value}' is not an array:`, bedOptions);
            }

            this.numberOfBedsOptions = bedOptions.map(opt => ({ label: opt, value: opt }));

            const unitOptions = (this.projectToUnitMap && this.projectToUnitMap[value]) || [];
            if (!Array.isArray(unitOptions)) {
                console.error(` unitOptions for '${value}' is not an array:`, unitOptions);
            }

            this.unitTypeOptions = unitOptions.map(opt => ({ label: opt, value: opt }));

            if (!bedOptions.includes(this.numberOfBeds)) {
                this.numberOfBeds = null;
            }
            if (!unitOptions.includes(this.unitType)) {
                this.unitType = null;
            }
        }
    }


    openleadmodal() {
        this.showModal = true;
    }
    updateTreeGridData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const paginated = this.allLeads.slice(start, end);

        let counter = start + 1; 

        this.treeGridData = paginated.map(parent => {
            let children = [];

            if (parent.children && parent.children.length > 0) {
                children = parent.children.map(child => {
    return {
        Id: child.Id,
        LeadNumber: '',
        Title: '',
        FirstName: `PROJECT NAME: ${child.ProjectInterest || ''}`,
        LastName: `UNIT TYPE: ${child.UnitType || ''}`,
        Email: `AGENT NAME: ${child.AgentName || ''}`,
        Mobile: `CREATED DATE: ${child.CreatedDate || ''}`,

        Status: '',
        rowClass: 'child-row',
        FirstNameClass: 'highlight-blue',
        LastNameClass: 'highlight-blue',
        MobileClass: 'highlight-blue',
        eyeIcon: '',
        calendarControl: 'utility:event',
        // Book Unit is active on child rows only
        bookUnitLabel: 'Book Unit',
        bookUnitIcon: 'utility:package',
        bookUnitDisabled: false
    };
});
            }

            const parentRow = {
    Id: parent.Id,
    SNo: counter++,
    LeadNumber: parent.LeadNumber,
    Title: parent.Title,
    FirstName: parent.FirstName,
    LastName: parent.LastName,
    Email: parent.Email,
    Mobile: parent.Mobile,
    Status: parent.Status,
    Description: parent.Description,
    EIDNumber: parent.EIDNumber__c,
    EmiratesIDExpiryDate: parent.EmiratesIDExpiryDate__c,
    PassportNumber: parent.PassportNumber__c,
    PassportExpiryDate: parent.PassportExpiryDate__c,
    PassportIssueDate: parent.PassportIssueDate__c,

    rowClass: 'parent-row',
    eyeIcon: 'utility:preview',
    calendarControl: '',
    // Book Unit is disabled/blank on parent (summary) rows
    bookUnitLabel: '',
    bookUnitIcon: '',
    bookUnitDisabled: true
};

            if (children.length > 0) {
                parentRow._children = children;
            }

            return parentRow;
        });
    }



    handleEmailValidation() {
        if (!this.email) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'No data to export',
                'Warning'
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
                this.editEmailButtonLabel = 'Validated ✅';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Email is valid.',
                    'success'
                );

            })
            .catch(error => {
                this.emailValidated = false;
                this.emailButtonLabel = 'Validate Email';
                this.editEmailButtonLabel = 'Validate Email';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    this.getErrorMessage(error),
                    'error'
                );

            })
            .finally(() => {
                this.emailValidating = false;
            });
    }


    handleMobileValidation() {
        if (!this.mobile) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please enter a mobile number.',
                'error'
            );

            return;
        }

        this.mobileValidating = true;
        this.mobileButtonLabel = 'Validating...';

        validatePhone({ phone: this.mobile })
            .then(result => {
                if (result === true) {
                    this.mobileValidated = true;
                    this.mobileButtonLabel = 'Validated ✅';
                    this.editMobileButtonLabel = 'Validated ✅';
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Mobile number is valid.',
                        'success'
                    );

                } else {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate Mobile';
                    this.editMobileButtonLabel = 'Validate Mobile';
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Entered number is not valid.',
                        'error'
                    );

                }
            })
            .catch(error => {
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
    getErrorMessage(error) {
        return error?.body?.message || 'Unexpected error occurred.';
    }


    handleKycFileUpload1(event) {
        if (event.target.files.length > 0) {
            this.kycFile = event.target.files[0];
            this.kycFileName = this.kycFile.name;
            this.uploadedKycFileName = this.kycFile.name;
            this.deleteKycFile = false; 
        }
    }

    handleDeleteKycFile1() {
        this.kycFile = null;
        this.kycFileName = '';
        this.uploadedKycFileName = '';
        this.kycFileUrl = '';
        this.deleteKycFile = false;
    }
    sourceFundsFile;
    sourceFundsFileName;
    sourceFundsFileUrl;
    uploadedSourceFundsFileName;
    deleteSourceFundsFile = false;

    handleSourceFundsFileUpload1(event) {
        if (event.target.files.length > 0) {
            this.sourceFundsFile = event.target.files[0];
            this.sourceFundsFileName = this.sourceFundsFile.name;
            this.uploadedSourceFundsFileName = this.sourceFundsFile.name;
            this.deleteSourceFundsFile = false;
        }
    }

    handleDeleteSourceFundsFile1() {
        this.sourceFundsFile = null;
        this.sourceFundsFileName = '';
        this.uploadedSourceFundsFileName = '';
        this.sourceFundsFileUrl = '';
        this.deleteSourceFundsFile = false;
    }
    handleDeleteEmiratesFile1() {
        this.emiratesIdFileName = '';
        this.emiratesIdFileUrl = ''; 
        this.deleteemiratesfiles = false;

        if (!this.deletedFileTypes.includes('Emirates ID')) {
            this.deletedFileTypes.push('Emirates ID');
        }
    }

    handleDeleteEmiratesFilebackside1() {
        this.emiratesIdFileNamebackside = '';
        this.emiratesIdFileUrl1 = '';
        this.deleteemiratesfilesbackside = false;

        if (!this.deletedFileTypes.includes('Emirates ID')) {
            this.deletedFileTypes.push('Emirates ID');
        }
    }


    handleDeletePassportFile1() {
        this.passportCopyFileName = '';
        this.passportCopyFileUrl = ''; // or PreviewUrl if applicable
        this.deletepassportfiles = false;

        if (!this.deletedFileTypes.includes('Passport Copy')) {
            this.deletedFileTypes.push('Passport Copy');
        }
    }
    handleDeletePassportFilebackside() {
        this.passportCopyFileNamebackside = '';
        this.passportCopyFileUrl1 = '';
        this.deletepassportfilesbackside = true;

        if (!this.deletedFileTypes.includes('Passport Copy')) {
            this.deletedFileTypes.push('Passport Copy');
        }
    }


    handleChildRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'editChildLead') {
            this.leadIdBeingEdited = row.Id;
            getUploadedDocuments({ leadId: this.leadIdBeingEdited })
                .then(docList => {

                    this.emiratesIdFileName = '';
                    this.emiratesIdFileNamebackside = '';
                    this.passportCopyFileName = '';
                    this.passportCopyFileNamebackside = '';

                    this.emiratesIdFileUrl = '';
                    this.emiratesIdFileUrl1 = '';
                    this.passportCopyFileUrl = '';
                    this.passportCopyFileUrl1 = '';

                    this.deleteemiratesfiles = false;
                    this.deleteemiratesfilesbackside = false;
                    this.deletepassportfiles = false;
                    this.deletepassportfilesbackside = false;

                    if (!docList || docList.length === 0) {
                        console.warn(' No uploaded documents found for lead:', this.leadIdBeingEdited);
                        return;
                    }

                    let emiratesCounter = 0;
                    let passportCounter = 0;
                    let kycCounter = 0;
                    let sourceCounter = 0;
                    let tradeLicenseCounter = 0;//Update version 1.5

                    docList.forEach(doc => {
                        const fileUrl = `/sfc/servlet.shepherd/document/download/${doc.contentDocumentId}`;

                        //  Emirates ID
                        if (doc.documentType === 'Emirates ID') {

                            if (!this.emiratesIdFileName) {
                                // FRONT
                                this.emiratesIdFileName = doc.title;
                                this.emiratesIdFileUrl = fileUrl;
                                this.deleteemiratesfiles = true;
                            } else {
                                // BACK
                                this.emiratesIdFileNamebackside = doc.title;
                                this.emiratesIdFileUrl1 = fileUrl;
                                this.deleteemiratesfilesbackside = true;
                            }
                        }

                        //  Passport
                        else if (doc.documentType === 'Passport Copy') {

                            if (!this.passportCopyFileName) {
                                // FRONT
                                this.passportCopyFileName = doc.title;
                                this.passportCopyFileUrl = fileUrl;
                                this.deletepassportfiles = true;
                            } else {
                                // BACK
                                this.passportCopyFileNamebackside = doc.title;
                                this.passportCopyFileUrl1 = fileUrl;
                                this.deletepassportfilesbackside = true;
                            }
                        }

                        //  KYC
                        else if (doc.documentType === 'Complete KYC form') {
                            this.kycFileName = doc.title;
                            this.kycFileUrl = fileUrl;
                            this.deleteKycFile = true;
                        }

                        //  Source of Funds
                        else if (doc.documentType === '3 month Bank statement/source of funds') {
                            this.sourceFundsFileName = doc.title;
                            this.sourceFundsFileUrl = fileUrl;
                            this.deleteSourceFundsFile = true;
                        }

                        //  Trade License
                        else if (doc.documentType === 'Trade License') {
                            this.tradeLicenseFileName = doc.title;
                            this.tradeLicenseFileUrl = fileUrl;
                            this.deleteTradeLicenseFile = true;
                        }

                        else if (doc.documentType === 'VAT Register' || doc.documentType === 'VAT Undertaking') {
                            this.vatFileName = doc.title;
                            this.vatFileUrl = fileUrl;
                            this.deleteVatFile = true;
                            this.vatCertificateType = doc.documentType === 'VAT Undertaking'
                                ? 'VAT Undertaking Certificate'
                                : 'VAT Registration Certificate';
                            this.showVatRegNumber = this.vatCertificateType === 'VAT Registration Certificate';
                            this.showDummyVatLink = this.vatCertificateType === 'VAT Undertaking Certificate';
                            this.vatUploadLabel = this.vatCertificateType === 'VAT Undertaking Certificate'
                                ? 'VAT Undertaking Certificate'
                                : 'VAT Registration Certificate';
                        }

                    });
                })
                .catch(error => {
                    console.error(' Error fetching uploaded documents:', error);
                });

            //  ADDED: Check if it's an organization lead
            //Update Version 1.5 There is a Small Issue In Recognising Individual and Org leads rectified and resolved It 
            this.leadType = row.Type || 'Individual';

            //  CHANGED: Add organization lead handling
            if (this.leadType === 'Organization') {
                this.orgName = row.LastName || row.Name || '';
                this.company = row.LastName || row.Name || '';
                this.unifiedNumber = row.UnifiedNumber || row.UnifiedNumber__c || '';
                this.uaevatregisternumber = row.uaevatregisternumber || row.UAEVATRegisterNumber__c || '';
                this.vatCertificateType = row.vatCertificateType || '';

                // CRITICAL FIX: Set these flags correctly based on the saved value
                this.showVatRegNumber = this.vatCertificateType === 'VAT Registration Certificate';
                this.showDummyVatLink = this.vatCertificateType === 'VAT Undertaking Certificate';
                this.vatUploadLabel = this.vatCertificateType === 'VAT Undertaking Certificate'
                    ? 'VAT Undertaking Certificate'
                    : 'VAT Registration Certificate';

                // Reset VAT file states
                this.deleteVatFile = false;
                this.uploadedVatFileName = '';
                this.vatFile = null;
            } else {
                // Clear organization fields for individual leads
                this.orgName = '';
                this.company = '';
                this.unifiedNumber = '';
                this.uaevatregisternumber = '';
                this.vatCertificateType = '';
                this.showVatRegNumber = false;
                this.showDummyVatLink = false;
            }

              this.firstName = row.FirstName || '';
                this.lastName = row.LastName || '';

            this.Title = row.Title || '';
            this.email = row.Email || '';
            this.mobile = row.Mobile || '';
            this.editEmailValidated = true;
            this.editEmailValidating = true;
            this.editEmailButtonLabel = 'Validated ✅';
            this.editMobileValidated = true;
            this.editMobileValidating = true;
            this.editMobileButtonLabel = 'Validated ✅';

            //  ADDED: Store original values for validation
            this.originalEmail = this.email;
            this.originalPhone = this.mobile;

            this.uaeResidentStatus = row.UAEResidentStatus__c || '';
            this.countryOfResidence = row.CountryOfResidence__c || '';
            this.nationality = row.Nationality__c || '';

            // Property Details
            this.salesOrigin = row.SalesOrigin__c || '';
            this.leadOrigin = row.LeadOrigin__c || '';
            this.salesType = row.SalesType__c || '';
            this.projectName = row.ProjectInterest__c || '';
            this.propertyUsage = row.PropertyUsage__c || '';
            this.numberOfBeds = row.NumberOfBedrooms__c || '';
            this.unitType = row.UnitType__c || '';

            this.buyRent = row.BuyRent__c || '';
            this.purposeOfUse = row.PurposeOfUse__c || '';
            this.customerBudget = row.CustomerBudget__c || '';
            this.propertyReadiness = row.PropertyReadiness__c || '';
            this.financing = row.Finance__c || '';

            //  ADDED: Load Description field
            this.Description = row.Description || '';

            // Document Fields
            this.passportNumber = row.PassportNumber__c || '';
            this.passportExpiry = row.PassportExpiryDate__c || '';
            this.passportIssuance = row.PassportIssueDate__c || '';
            this.emiratesId = row.EIDNumber__c || '';
            this.emiratesIdExpiry = row.EmiratesIDExpiryDate__c || '';
            this.uaeResidentStatus = row.UAEResidentStatus__c || '';

            // Edit mode logic
            this.showPassportFields = true; // Always show passport

            if (this.uaeResidentStatus === 'Resident') {
                this.showUaeFields = true;
                this.deleteemiratesfiles = true;
                this.deleteemiratesfilesbackside = true;
            } else if (this.uaeResidentStatus === 'Non-Resident') {
                this.showUaeFields = false;
                this.deletepassportfiles = true;
                this.deletepassportfilesbackside = true;
            } else {
                // Fallback case
                this.showUaeFields = false;
                this.deletepassportfiles = false;
            }

            if (this.projectToBedsMap[this.projectName]) {
                this.numberOfBedsOptions = this.projectToBedsMap[this.projectName].map(val => ({ label: val, value: val }));
            }

            if (this.projectToUnitMap && this.projectToUnitMap[this.projectName]) {
                this.unitTypeOptions = this.projectToUnitMap[this.projectName].map(val => ({
                    label: val,
                    value: val
                }));
            } else {
                this.unitTypeOptions = [];
                console.warn(` projectToUnitMap missing or key "${this.projectName}" not found.`);
            }

            // Show modal
            this.showeditModal = true;
        }
    }
    // ===== LEAD SUBMISSION METHODS =====
    handleSubmit() {

        if (this.leadType === 'Organization') {
            this.company = this.orgName;
        }

        const requiredFields = [

            { value: this.email, name: 'Email' },
            { value: this.mobile, name: 'Mobile' },
            { value: this.uaeResidentStatus, name: 'UAE Resident Status' },
            { value: this.countryOfResidence, name: 'Country of Residence' },
            { value: this.nationality, name: 'Nationality' },
            { value: this.salesOrigin, name: 'Sales Origin' },
            { value: this.leadOrigin, name: 'Lead Origin' },
            { value: this.salesType, name: 'Sales Type' },
            { value: this.projectName, name: 'Project Name' },
            { value: this.numberOfBeds, name: 'Number of Bedrooms' },
            { value: this.unitType, name: 'Unit Type' },
            { value: this.purposeOfUse, name: 'Purpose of Use' },
            { value: this.customerBudget, name: 'Customer Budget' },
             { value: this.firstName, name: 'First Name' },
                { value: this.lastName, name: 'Last Name' }
        ];

       /* if (this.leadType === 'Individual') {
            requiredFields.unshift(
                { value: this.firstName, name: 'First Name' },
                { value: this.lastName, name: 'Last Name' }
            );
        } else*/ if (this.leadType === 'Organization') {
            requiredFields.unshift(
                { value: this.orgName, name: 'Organization Name' },
                { value: this.company, name: 'orgName' },
                //  { value: this.tradeNumber, name: 'Trade License Number' },
                { value: this.unifiedNumber, name: 'Unified Number' },
             //   { value: this.uaevatregisternumber, name: 'uae vat register Number' }
            );
               if (this.vatCertificateType === 'VAT Registration Certificate') {
        requiredFields.push({ value: this.uaevatregisternumber, name: 'UAE VAT Registration Number' });
    }

        }

        // Check basic required fields
        for (let field of requiredFields) {
            if (!field.value) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    `Please enter ${field.name}.`,
                    'error'
                );
                return;
            }
        }

        // Email & Mobile validated
        if (!this.emailValidated || !this.mobileValidated) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please validate both Email and Mobile before submitting.',
                'error'
            );

            return;
        }

        const today = new Date();

        if (this.uaeResidentStatus === 'Resident') {
            // Emirates ID Number Required
            if (!this.emiratesId) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please enter Emirates ID number.',
                    'error'
                );

                return;
            }

            // Format Check
            const emiratesIdRegex = /^784-\d{4}-\d{7}-\d{1}$/;
            if (!emiratesIdRegex.test(this.emiratesId)) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Invalid Emirates ID. Format should be: 784-1234-1234567-1',
                    'error'
                );

                return;
            }

            // Expiry Date Required
            if (!this.emiratesIdExpiry) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please enter Emirates ID expiry date.',
                    'error'
                );

                return;
            }

            const eidExpiry = new Date(this.emiratesIdExpiry);
            if (eidExpiry <= today) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Emirates ID expiry date must be a future date.',
                    'error'
                );

                return;
            }

            // Documents Required
            if (!this.emiratesFile || !this.emiratesFilebackside) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please upload both front and back Emirates ID documents.',
                    'error'
                );

                return;
            }
        }

        // === NON-RESIDENT VALIDATION ===
        if (this.uaeResidentStatus === 'Non-Resident') {
            // Passport Number Required
            if (!this.passportNumber) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please enter Passport number.',
                    'error'
                );

                return;
            }

            const issuanceDate = new Date(this.passportIssuance);
            const today = new Date();

            if (issuanceDate > today) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Passport issuance date cannot be a future date.',
                    'error'
                );
                return;
            }
            // Expiry Date Required
            if (!this.passportExpiry) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please enter Passport expiry date.',
                    'error'
                );

                return;
            }

            const passportExpiryDate = new Date(this.passportExpiry);
            if (passportExpiryDate <= today) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Passport expiry date must be a future date.',
                    'error'
                );

                return;
            }

            // Documents Required
            if (!this.passportFile || !this.passportFilebackside) {
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please upload both front and back passport copies.',
                    'error'
                );

                return;
            }
        }

        // === TRADE LICENSE VALIDATION FOR ORGANIZATION ===
        if (this.leadType === 'Organization' && !this.tradeLicenseFile) {
            this.template.querySelector('c-mbp_customshowtoast').show(
                'Please upload Trade License document for Organization leads.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        const fields = {
            Type: this.leadType,
            FirstName: this.firstName,
            LastName: this.lastName,
            Email: this.email,
            Salutation: this.title,
            UAEResidentStatus__c: this.uaeResidentStatus,
            Nationality__c: this.nationality,
            CountryOfResidence__c: this.countryOfResidence,
            SalesOrigin__c: this.salesOrigin,
            LeadOrigin__c: this.leadOrigin,
            SalesType__c: this.salesType,
            PropertyUsage__c: this.propertyUsage,
            BuyRent__c: this.buyRent,
            ProjectInterest__c: this.projectName,
            UnitType__c: this.unitType,
            Description: this.Description,
            NumberOfBedrooms__c: this.numberOfBeds,
            CustomerBudget__c: this.customerBudget,
            PurposeOfUse__c: this.purposeOfUse,
            PropertyReadiness__c: this.propertyReadiness,
            Finance__c: this.financing,
            EIDNumber__c: this.emiratesId,
            PassportNumber__c: this.passportNumber,
            PassportIssueDate__c: this.passportIssuance,
            PassportExpiryDate__c: this.passportExpiry,
            EmiratesIDExpiryDate__c: this.emiratesIdExpiry,
            BrokerAgentName__c: this.brokerAgentName,
            BrokerAgentMobile__c: this.brokerAgentMobile,
            MobilePhone: this.mobile || '',
            Company: this.orgName,
            // Trade_License_Number__c: this.tradeNumber,
            UnifiedNumber__c: this.unifiedNumber,
               UAEVATRegisterNumber__c:this.uaevatregisternumber,
               vatCertificateType: this.vatCertificateType
        };
        if (fields.Type === 'Organization') {
            const org = (this.orgName || '').replace(/[^a-zA-Z\s]/g, '').trim();

            //fields.FirstName = 'NA';     
           // fields.LastName = org || 'Organization';
            fields.Name = org || 'Organization';
            //fields.RecordTypeId = this.orgRecordTypeId;
            //fields.RecordTypeId = this.orgRecordTypeId;


        } else {
            delete fields.Trade_License_Number__c;
            delete fields.UnifiedNumber__c;
            delete fields.UAEVATRegisterNumber__c;
        }

        createLead({
            payload: fields,
            contactId: this.contactId,
            accountId: this.accountId
        })
            .then(result => {
                const leadId = result.Id;

                const uploadPromises = [];

                if (this.kycFile) {
                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.kycFile, 'Complete KYC Form'));
                }
                if (this.sourceFundsFile) {

                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.sourceFundsFile, '3 month Bank statement/source of funds'));
                }
                if (this.passportFile) {
                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.passportFile, 'Passport Copy'));
                }
                if (this.passportFilebackside) {
                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.passportFilebackside, 'Passport Copy'));
                }
                if (this.uaeResidentStatus === 'Resident') {
                    if (this.emiratesFile) {
                        uploadPromises.push(this.uploadDocumentToLead(leadId, this.emiratesFile, 'Emirates ID'));
                    }
                    if (this.emiratesFilebackside) {
                        uploadPromises.push(this.uploadDocumentToLead(leadId, this.emiratesFilebackside, 'Emirates ID'));
                    }
                }

                // === TRADE LICENSE VALIDATION FOR ORGANIZATION ===
                if (this.leadType === 'Organization' && this.tradeLicenseFile) {
                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.tradeLicenseFile, 'Trade License'));
                }

                if (this.vatFile && this.leadType === 'Organization') {
                    const vatDocType = this.vatCertificateType === 'VAT Registration Certificate'
                        ? 'VAT Register'
                        : 'VAT Undertaking';
                    uploadPromises.push(this.uploadDocumentToLead(leadId, this.vatFile, vatDocType));
                }

                return Promise.all(uploadPromises);
            })
            .then(() => {
                try {
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Lead Created successfully!',
                        'success'
                    );

                    this.closeModal();
                    this.resetFormFields();
                    this.loadLeads();
                    window.location.reload();
                    //Mobile
                    this.updateMobileLeads();

                } catch (uiErr) {
                    console.error('⚠ UI error after updating lead:', uiErr);
                    
                }
            })



            .catch(error => {
                console.error(' Lead creation failed:', JSON.stringify(error));
                console.error(' Lead creation failed');
                console.error('RAW ERROR OBJECT ', error);
                console.error('ERROR BODY ', error?.body);
                console.error('OUTPUT ERRORS ', error?.body?.output?.errors);
                console.error('FIELD ERRORS ', error?.body?.output?.fieldErrors);


                this.isSaving = false;

                let errorMsg = 'Something went wrong while creating the lead.';

                // 1) Apex thrown errors (AuraHandledException, throw new Exception)
                if (error?.body?.message) {
                    errorMsg = error.body.message;
                }

                // 2) DML field-level errors (FIELD_CUSTOM_VALIDATION_EXCEPTION, REQUIRED_FIELD_MISSING, etc.)
                else if (error?.body?.pageErrors && error.body.pageErrors.length > 0) {
                    errorMsg = error.body.pageErrors[0].message;
                }

                // 3) Field-specific errors (from schema)
                else if (error?.body?.fieldErrors) {
                    const fields = Object.keys(error.body.fieldErrors);
                    if (fields.length > 0) {
                        errorMsg = error.body.fieldErrors[fields[0]][0].message;
                    }
                }

                // 4) Apex debug errors (sometimes in body.error)
                else if (error?.body?.error) {
                    errorMsg = error.body.error;
                }

                // Prepend "Error creating lead: " to the actual error message
                errorMsg = `Error creating lead: ${errorMsg}`;

                // SHOW REAL ERROR TO USER
                this.template.querySelector('c-mbp_customshowtoast').show(
                    errorMsg,
                    'error'
                );
            })
            .finally(() => {
                this.isSaving = false;
            });
    }


    // Handle Trade License file upload
    handleTradeLicenseFileUpload(event) {
        const file = event.target.files[0];
        if (file) {
            this.tradeLicenseFile = file;
            this.uploadedTradeLicenseFileName = file.name;
            this.tradeLicenseFileName = file.name;
            this.deleteTradeLicenseFile = false; 
        }
    }

    // Handle delete Trade License file
    handleDeleteTradeLicenseFile() {
        this.tradeLicenseFile = null;
        this.uploadedTradeLicenseFileName = '';
        this.deleteTradeLicenseFile = false;
    }

    // For editing existing files
    handleDeleteTradeLicenseFile1() {
        this.deleteTradeLicenseFile = true;
        this.tradeLicenseFile = null;
        this.uploadedTradeLicenseFileName = '';
    }


    handleEmiratesFileUpload(event) {
        const file = event.target.files[0];
        this.uploadedEmiratesFileName = file ? file.name : '';
        this.emiratesFile = file;
    }
    handleEmiratesFileUploadbackside(event) {
        const file = event.target.files[0];
        this.uploadedEmiratesFileNamebackside = file ? file.name : '';
        this.emiratesFilebackside = file;
    }

    handlePassportFileUpload(event) {
        const file = event.target.files[0];
        this.uploadedPassportFileName = file ? file.name : '';
        this.passportFile = file;
    }
    handlePassportFileUploadbackside(event) {
        const file = event.target.files[0];
        this.uploadedPassportFileNamebackside = file ? file.name : '';
        this.passportFilebackside = file;
    }


    uploadDocumentToLead(leadId, file, placeholder) {
        const reader = new FileReader();

        reader.onloadend = () => {
            const base64 = reader.result.split(',')[1];

            uploadFileToDocumentRecord({
                base64Data: base64,
                fileName: file.name,
                leadId: leadId,
                documentTypeLabel: placeholder
            })
                .then(() => {
                    console.log(` ${placeholder} uploaded successfully.`);
                })
                .catch(error => {
                    console.error(` Failed to upload ${placeholder}:`, error);
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        `Failed to upload ${placeholder}`,
                        'error'
                    );
                });
        };

     
        reader.onerror = () => {
            console.error(` Error reading file ${placeholder}:`, reader.error);
        };

        reader.readAsDataURL(file);
    }


    handleeditSubmit() {
        //  ADDED: Organization lead handling
        if (this.leadType === 'Organization') {
         //   this.firstName = 'NA';

            // Validate organization fields
            if (!this.orgName) {
                this.showToast('Please enter Organization Name.', 'error');
                return;
            }
        }

        //  CHANGED: Update required fields validation for organization
        const requiredFields = [];

      /*  if (this.leadType === 'Individual') {
            requiredFields.push(
                { value: this.firstName, name: 'First Name' },
                { value: this.lastName, name: 'Last Name' }
            );
        } else*/ if (this.leadType === 'Organization') {
            requiredFields.push(

                { value: this.orgName, name: 'Organization Name' }
                //Update version 1.5 commented Out This Line as It's causing Issue recognising Org lead
                //  { value: this.company, name: 'Company' }
            );
        }

        // Common required fields for both types
        requiredFields.push(
            { value: this.email, name: 'Email' },
            { value: this.mobile, name: 'Mobile' },
            { value: this.uaeResidentStatus, name: 'UAE Resident Status' },
            { value: this.countryOfResidence, name: 'Country of Residence' },
            { value: this.nationality, name: 'Nationality' },
            { value: this.salesOrigin, name: 'Sales Origin' },
            { value: this.leadOrigin, name: 'Lead Origin' },
            { value: this.salesType, name: 'Sales Type' },
            { value: this.projectName, name: 'Project Name' },
            { value: this.numberOfBeds, name: 'Number of Bedrooms' },
            { value: this.unitType, name: 'Unit Type' },
            { value: this.purposeOfUse, name: 'Purpose of Use' },
            { value: this.customerBudget, name: 'Customer Budget' },
            { value: this.firstName, name: 'First Name' },
                { value: this.lastName, name: 'Last Name' }
        );

        let hasValidationError = false;
        for (let field of requiredFields) {
            if (!field.value) {
                this.showToast(`Please enter ${field.name}.`, 'error');
                hasValidationError = true;
                break;
            }
        }

        if (hasValidationError) {
            return;
        }

        const today = new Date();

        // === UAE RESIDENT VALIDATION ===
        if (this.uaeResidentStatus === 'Resident') {
            // Emirates ID Number Required
            if (!this.emiratesId) {
                this.showToast('Please enter Emirates ID number.', 'error');
                return;
            }

            // Format Check
            const emiratesIdRegex = /^784-\d{4}-\d{7}-\d{1}$/;
            if (!emiratesIdRegex.test(this.emiratesId)) {
                this.showToast('Invalid Emirates ID. Format should be: 784-1234-1234567-1', 'error');
                return;
            }

            // Expiry Date Required
            if (!this.emiratesIdExpiry) {
                this.showToast('Please enter Emirates ID expiry date.', 'error');
                return;
            }

            const eidExpiry = new Date(this.emiratesIdExpiry);
            if (eidExpiry <= today) {
                this.showToast('Emirates ID expiry date must be a future date.', 'error');
                return;
            }
        }

        // === NON-RESIDENT VALIDATION ===
        if (this.uaeResidentStatus === 'Non-Resident') {
            // Passport Number Required
            if (!this.passportNumber) {
                this.showToast('Please enter Passport number.', 'error');
                return;
            }

            //  ADDED: Debug for passport issuance date
            if (this.passportIssuance) {
                const issuanceDate = new Date(this.passportIssuance);
                if (issuanceDate > today) {
                    this.showToast('Passport issuance date cannot be a future date.', 'error');
                    return;
                }
            }

            // Expiry Date Required
            if (!this.passportExpiry) {
                this.showToast('Please enter Passport expiry date.', 'error');
                return;
            }

            const passportExpiryDate = new Date(this.passportExpiry);
            if (passportExpiryDate <= today) {
                this.showToast('Passport expiry date must be a future date.', 'error');
                return;
            }
        }

        this.isSaving = true;

        //  CHANGED: Update lead record to include Description and organization handling
        const leadRecord = {
            Id: this.leadIdBeingEdited,
            Type: this.leadType,
            Name: this.name,
            /*  FirstName: this.firstName,
              LastName: this.lastName,
              Salutation: this.Title,*/

            //Update Version 1.5 Slightly Changed The Individual and Org lead With conditions so That The edit form Will recognise Them Easily
            ...(this.leadType === 'Individual' && {
            /*    FirstName: this.firstName,
                LastName: this.lastName,*/
                Salutation: this.Title
            }),
            //  Only set Org fields for Organization
            ...(this.leadType === 'Organization' && {
                LastName: this.orgName,
                Name: this.orgName,
               // FirstName: 'NA',
                //  Trade_License_Number__c: this.tradeNumber,
                UnifiedNumber__c: this.unifiedNumber,
                UAEVATRegisterNumber__c : this.uaevatregisternumber,
                VAT_Certificate_Type__c: this.vatCertificateType,
            }),
              FirstName: this.firstName,
        LastName: this.lastName,
            Email: this.email,
            MobilePhone: this.mobile,
            UAEResidentStatus__c: this.uaeResidentStatus,
            CountryOfResidence__c: this.countryOfResidence,
            Nationality__c: this.nationality,
            PassportNumber__c: this.passportNumber,
            PassportExpiryDate__c: this.passportExpiry,
            PassportIssueDate__c: this.passportIssuance,
            SalesOrigin__c: this.salesOrigin,
            LeadOrigin__c: this.leadOrigin,
            SalesType__c: this.salesType,
            ProjectInterest__c: this.projectName,
            PropertyUsage__c: this.propertyUsage,
            NumberOfBedrooms__c: this.numberOfBeds,
            UnitType__c: this.unitType,
            BuyRent__c: this.buyRent,
            Description: this.Description, //  ADDED: Include Description field
            PurposeOfUse__c: this.purposeOfUse,
            CustomerBudget__c: this.customerBudget,
            PropertyReadiness__c: this.propertyReadiness,
            Finance__c: this.financing,
            BrokerAgentName__c: this.brokerAgentName,
            BrokerAgentMobile__c: this.brokerAgentMobile,
            Company: this.orgName,
            
            //  Trade_License_Number__c: this.tradeNumber,
          //  UnifiedNumber__c: this.unifiedNumber,
          //  UAEVATRegisterNumber__c :this.uaevatregisternumber

            
        };

        //  Emirates fields ONLY for Resident
        if (this.uaeResidentStatus === 'Resident') {
            leadRecord.EIDNumber__c = this.emiratesId;
            leadRecord.EmiratesIDExpiryDate__c = this.emiratesIdExpiry;
        }

        //  CHANGED: Organization logic with FirstName as 'NA'
        if (leadRecord.Type === 'Organization') {
            const org = (this.orgName || '').replace(/[^a-zA-Z\s]/g, '').trim();
            leadRecord.LastName = org || 'Organization';
            leadRecord.Name = org || 'Organization';
          //  leadRecord.FirstName = 'NA'; //  IMPORTANT: Set FirstName to 'NA'
        } else {
            delete leadRecord.Name;
            delete leadRecord.Trade_License_Number__c;
            delete leadRecord.UnifiedNumber__c;
              delete leadRecord.UAEVATRegisterNumber__c;
        }

        const cleanedRecord = {};
        Object.keys(leadRecord).forEach(key => {
            if (
                leadRecord[key] !== undefined &&
                leadRecord[key] !== null &&
                leadRecord[key] !== ''
            ) {
                cleanedRecord[key] = leadRecord[key];
            }
        });

        createLead({ payload: cleanedRecord, contactId: this.contactId, accountId: this.accountId })
            .then(result => {
                const leadId = result.Id;

                if (this.kycFile) {
                    this.uploadDocumentToLead(leadId, this.kycFile, 'Complete KYC Form');
                }
                if (this.sourceFundsFile) {
                    this.uploadDocumentToLead(leadId, this.sourceFundsFile, '3 month Bank statement/source of funds');
                }

                if (this.uaeResidentStatus === 'Resident' && this.emiratesFile) {
                    this.uploadDocumentToLead(leadId, this.emiratesFile, 'Emirates ID');
                    this.uploadDocumentToLead(leadId, this.emiratesFilebackside, 'Emirates ID');
                } else if (this.uaeResidentStatus === 'Non-Resident' && this.passportFile) {
                    this.uploadDocumentToLead(leadId, this.passportFile, 'Passport Copy');
                    this.uploadDocumentToLead(leadId, this.passportFilebackside, 'Passport Copy');
                }

                // Update version 1.5
                if (this.leadType === 'Organization' && this.tradeLicenseFile) {
                    this.uploadDocumentToLead(leadId, this.tradeLicenseFile, 'Trade License');
                }

                if (this.deletedFileTypes && this.deletedFileTypes.length > 0) {
                    deleteLeadDocuments({ leadId: leadId, documentTypes: this.deletedFileTypes })
                        .catch(err => console.warn(' Document deletion failed:', err));
                }

                if (this.vatFile && this.leadType === 'Organization') {
        const vatDocType = this.vatCertificateType === 'VAT Registration Certificate' 
            ? 'VAT Register' 
            : 'VAT Undertaking';
        this.uploadDocumentToLead(leadId, this.vatFile, vatDocType);
    }

                this.showToast('Lead updated successfully! Reloading page...', 'success');

                
                setTimeout(() => {
                    window.location.reload();
                }, 1500);

            })
            .catch(error => {
                console.error(' Error updating lead:', error);
                this.isSaving = false;
                const errorMsg =
                    error?.body?.pageErrors?.[0]?.message ||
                    Object.values(error?.body?.fieldErrors || {})?.[0]?.[0]?.message ||
                    'Something went wrong while updating the lead.';
                this.showToast(errorMsg, 'error');
            });
    }



    resetAndCloseModal() {
        this.isSaving = false;
        this.showeditModal = false;
        this.deletedFileTypes = [];

        // Reset form fields
        this.firstName = '';
        this.lastName = '';
        this.orgName = '';
        this.company = '';
        //  this.tradeNumber = '';
        this.unifiedNumber = '';
         this.uaevatregisternumber = '',
        this.email = '';
        this.mobile = '';
        this.Description = '';
        this.leadIdBeingEdited = '';

        // Reset document files
        this.uploadedKycFileName = '';
        this.uploadedSourceFundsFileName = '';
        this.uploadedEmiratesFileName = '';
        this.uploadedEmiratesFileNamebackside = '';
        this.uploadedPassportFileName = '';
        this.uploadedPassportFileNamebackside = '';

        this.kycFile = null;
        this.sourceFundsFile = null;
        this.emiratesFile = null;
        this.emiratesFilebackside = null;
        this.passportFile = null;
        this.passportFilebackside = null;

        // Reset existing document previews
        this.deleteemiratesfiles = false;
        this.deleteemiratesfilesbackside = false;
        this.deletepassportfiles = false;
        this.deletepassportfilesbackside = false;
        this.deleteKycFile = false;
        this.deleteSourceFundsFile = false;
    }

    showCenteredToast(title, message, variant) {
        this.customToastTitle = title;
        this.customToastMessage = message;
        this.customToastVariant = variant;
        this.showCustomToast = true;

        setTimeout(() => {
            this.showCustomToast = false;
        }, 5000);
    }


    goBack() {
        this.showDetails = false;
        this.showList = true;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateTreeGridData();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateTreeGridData();
        }
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage === this.totalPages;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    //New

    disconnectedCallback() {
        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

   renderedCallback() {
    if (!this._outsideClickHandlerAdded) {
        this._outsideClickHandler = this.handleOutsideClick.bind(this);
        document.addEventListener('mousedown', this._outsideClickHandler);
        this._outsideClickHandlerAdded = true;
    }

    // If we just converted a lead, open that Opportunity as soon as the
    // Manage Opportunities tab (and its child component) has rendered.
    if (this.isManageOppsActive && this.pendingOpportunityId) {
        const oppCmp = this.template.querySelector('c-mbp_manage-opportunities');
        if (oppCmp) {
            const idToOpen = this.pendingOpportunityId;
            this.pendingOpportunityId = null; // clear first to avoid re-triggering
            oppCmp.focusOpportunityById(idToOpen);
        }
    }
}

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-icon');

        //  Check composed path for shadow DOM elements
        const path = event.composedPath ? event.composedPath() : [];
        const clickedInside =
            (filterWrapper && path.includes(filterWrapper)) ||
            (filterIcon && path.includes(filterIcon));

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    get isIndividual() {
        return this.leadType === 'Individual';
    }

    get isOrganization() {
        return this.leadType === 'Organization';
    }


    //New offer and Mobile 
    // ===== GETTER METHODS =====
    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    get unitsFilterBoxClass() {
        return this.showUnitsFilterBox ? 'units-filter-box visible' : 'units-filter-box';
    }

    closeFilterBox(event) {
        if (event) event.stopPropagation();
        this.showFilterBox = false;
    }

    closeUnitsFilterBox(event) {
        if (event) event.stopPropagation();
        this.showUnitsFilterBox = false;
    }

    get manageLeadsTabClass() {
        return this.isManageLeadsActive ? 'tab-button active' : 'tab-button';
    }

    get manageOppTabClass() {
        return this.isManageOppsActive ? 'tab-button active' : 'tab-button';
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage === this.totalPages;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get isViewPdfDisabled() {
        return !this.offerPdfUrl;
    }

    get disableDownload() {
        return !this.hasActivePreview;
    }

    get isActiveTab() {
        return this.index === this.activeUnitIndex ? 'true' : 'false';
    }

    get tabIndex() {
        return this.index === this.activeUnitIndex ? '0' : '-1';
    }

    get isStepOne() {
        return this.currentStep === 1;
    }

    get isStepTwo() {
        return this.currentStep === 2;
    }

    get isStepThree() {
        return this.currentStep === 3;
    }

    get isFirstStep() {
        return this.currentStep === 1;
    }

    get isNotLastStep() {
        return this.currentStep < 3;
    }

    get isLastStep() {
        return this.currentStep === 3;
    }

    get hasUnits() {
        return this.filteredUnits && this.filteredUnits.length > 0;
    }

    get noUnitsAvailable() {
        return (!this.filteredUnits || this.filteredUnits.length === 0) && !this.isStepOneLoading;
    }

    get areAllUnitsSelected() {
        return this.units.length > 0 && this.units.every(unit => unit.isSelected);
    }

    get isBuildingDisabled() {
        return !this.selectedProject || this.isLoading;
    }

    get generateOfferDisabled() {
        return this.selectedUnits.length === 0 ||
            this.selectedLeads.length === 0 ||
            !this.selectedPaymentPlan ||
            this.isLoading;
    }

    get preselectedUnitsLabel() {
        return `${this.pendingUnitData?.length || 0} unit(s) preselected`;
    }

    get isGenerateOfferDisabled() {
        const hasSelectedLeads = this.selectedLeads.length > 0;
        const hasSelectedUnits = this.selectedUnits.length > 0;
        const hasPaymentPlan = !!this.selectedPaymentPlan;

        return !(hasSelectedLeads && hasSelectedUnits && hasPaymentPlan && !this.isGeneratingOffer);
    }

    get disableUnitsPrev() {
        return this.currentUnitsPage === 1 || this.totalUnitsPages === 0 || this.isStepOneLoading;
    }

    get disableUnitsNext() {
        return this.currentUnitsPage === this.totalUnitsPages || this.totalUnitsPages === 0 || this.isStepOneLoading;
    }

    get activeUnitData() {
        if (this.selectedUnitsData && this.selectedUnitsData.length > 0 && this.activeUnitIndex >= 0) {
            return this.selectedUnitsData[this.activeUnitIndex];
        }
        return null;
    }

    get alNaseemSelected() {
        if (!this.selectedUnitsData || this.selectedUnitsData.length === 0) {
            return false;
        }

        const activeUnit = this.activeUnitData;
        if (!activeUnit) {
            return false;
        }

        const isAlNaseem = activeUnit.projectName && (
            activeUnit.projectName.toLowerCase().includes('al naseem') ||
            activeUnit.projectName.toLowerCase().includes('naseem') ||
            activeUnit.projectName === 'Al Naseem' ||
            activeUnit.projectName === 'Al Naseem C'
        );

        return isAlNaseem;
    }

    get paymentPlanName() {
        // **FIXED: Always use the active unit's saved payment plan**
        const activeUnit = this.activeUnitForSummary;

        if (activeUnit && activeUnit.selectedPaymentPlanName) {
            return activeUnit.selectedPaymentPlanName;
        }

        // Fallback for any edge cases
        if (!this.selectedPaymentPlan) return 'No payment plan selected';

        if (this.paymentPlanDetails) {
            return this.paymentPlanDetails.Name ||
                this.paymentPlanDetails.paymentPlan?.Name ||
                'Payment Plan';
        }

        const selectedOption = this.paymentPlanOptions.find(
            option => option.value === this.selectedPaymentPlan
        );
        return selectedOption ? selectedOption.label : 'Payment Plan';
    }
    get totalBrokerCommission() {
        if (!this.installments.length || !this.activeUnitData) return 0;

        return this.installments.reduce((total, inst) => {
            const installmentAmount = (this.activeUnitData.totalPrice * (inst.Milestone__c || 0)) / 100;
            const brokerCommission = (installmentAmount * (inst.BrokerPayout__c || 0)) / 100;
            return total + brokerCommission;
        }, 0);
    }

    get averageBrokerPayout() {
        if (!this.installments.length) return 0;

        const totalPayout = this.installments.reduce((sum, inst) => sum + (inst.BrokerPayout__c || 0), 0);
        return (totalPayout / this.installments.length).toFixed(2);
    }

    get activeUnitName() {
        return this.activeUnitData ? this.activeUnitData.name : '';
    }

    get activeUnitForSummaryName() {
        return this.activeUnitForSummary ? this.activeUnitForSummary.name : '';
    }


    get paymentPlanStatus() {
        return this.paymentPlanDetails ? 'Loaded' : 'Not Loaded';
    }

    get totalOfferValue() {
        return this.units
            .filter(unit => unit.isSelected)
            .reduce((total, unit) => total + (unit.totalPrice || 0), 0);
    }

    get selectedLeadName() {
        if (this.selectedLeads.length === 0) return 'No lead selected';
        const selectedLeadData = this.allLeads.find(lead => lead.Id === this.selectedLeads[0]);
        return selectedLeadData ?
            `${selectedLeadData.FirstName || ''} ${selectedLeadData.LastName || ''}`.trim() :
            'Lead Name';

    }

    get dynamicOfferSummary() {
        const activeUnit = this.activeUnitForSummary;
        if (!activeUnit) return null;

        let paymentPlanName = 'No payment plan selected';
        if (this.paymentPlanDetails) {
            paymentPlanName = this.paymentPlanDetails.Name || this.paymentPlanDetails.paymentPlan?.Name || paymentPlanName;
        }

        return {
            unitName: activeUnit.name,
            projectName: activeUnit.projectName,
            buildingName: activeUnit.phaseName,
            bedrooms: activeUnit.bedrooms,
            totalPrice: activeUnit.totalPrice,
            selectedLeads: this.selectedLeads.length,
            paymentPlan: paymentPlanName,
            facadeStyle: this.selectedDesign
        };
    }

    get activeUnitForSummary() {
        if (!this.activePreviewUnitId || !this.selectedUnitsData.length) {
            return this.selectedUnitsData[0];
        }
        return this.selectedUnitsData.find(unit => unit.id === this.activePreviewUnitId) || this.selectedUnitsData[0];
    }

    get activePreviewUrl() {
        return this.unitPreviewUrls[this.activePreviewUnitId] || '';
    }

    get showActivePreview() {
        return this.hasActivePreview && !this.isStepThreeLoading;
    }

    get processedSteps() {
        if (!this.progressSteps) return [];
        return this.progressSteps.map(step => {
            let css = 'progress-step';
            if (this.currentStep >= step.value) css += ' active';
            if (this.currentStep > step.value) css += ' completed';
            return { ...step, cssClass: css };
        });
    }

    get progressFillStyle() {
        const progressPercentage = ((this.currentStep - 1) / 2) * 100;
        return `width: ${progressPercentage}%`;
    }

    get stepOneClass() {
        if (this.currentStep >= 1) {
            return this.currentStep > 1 ? 'step-circle completed' : 'step-circle active';
        }
        return 'step-circle';
    }

    get stepTwoClass() {
        if (this.currentStep >= 2) {
            return this.currentStep > 2 ? 'step-circle completed' : 'step-circle active';
        }
        return 'step-circle';
    }

    get stepThreeClass() {
        return this.currentStep >= 3 ? 'step-circle completed' : 'step-circle';
    }

    get previewTabClasses() {
        const classes = {};
        this.selectedUnitsData.forEach(unit => {
            classes[unit.id] = unit.isActivePreview
                ? 'slds-tabs_default__item slds-is-active'
                : 'slds-tabs_default__item';
        });
        return classes;
    }

    getUnitTabClass(index) {
        let className = 'unit-tab';
        if (index === 0) {
            className += ' unit-tab-active';
        }
        return className;
    }




    get isActivePreviewUnitAlNaseem() {
        if (!this.activeUnitForSummary || !this.activeUnitForSummary.projectName) return false;

        const projectName = this.activeUnitForSummary.projectName.toLowerCase();
        return projectName.includes('al naseem') ||
            projectName.includes('naseem') ||
            projectName === 'al naseem' ||
            projectName === 'al naseem c';
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        const grid = this.template.querySelector('lightning-tree-grid');
        const prevId = (this.selectedLeads && this.selectedLeads[0]) || null;

        if (this.selectedLeads.length > 0) {
            this.loadSelectedLeadDetails();
        }

        if (selectedRows.length === 0) {
            this._clearSelection(grid);
            return;
        }

        if (selectedRows.length === 1) {
            const id = selectedRows[0].Id;
            if (prevId === id) {
                this._clearSelection(grid);
            } else {
                this._setSingleSelection(id, grid);
            }
            return;
        }

        const newly = selectedRows.find(r => r.Id !== prevId) || selectedRows[selectedRows.length - 1];
        const newId = newly ? newly.Id : null;
        if (!newId || newId === prevId) {
            this._clearSelection(grid);
        } else {
            this._setSingleSelection(newId, grid);
        }
    }

    _clearSelection(grid) {
        this.selectedLeads = [];
        this.isUnitSearchDisabled = true;
        this._traverseAndSetIsSelected(this.treeGridData, false);
        this.treeGridData = JSON.parse(JSON.stringify(this.treeGridData));

        if (grid) {
            grid.selectedRows = [];
        }
    }

    _setSingleSelection(id, grid) {
        this.selectedLeads = [id];
        this.isUnitSearchDisabled = false;
        this._traverseAndSetIsSelected(this.treeGridData, false);
        this._setIsSelectedById(this.treeGridData, id, true);
        this.treeGridData = JSON.parse(JSON.stringify(this.treeGridData));

        if (grid) {
            grid.selectedRows = this.selectedLeads;
        }
    }

    _traverseAndSetIsSelected(nodes, value) {
        if (!Array.isArray(nodes)) return;
        nodes.forEach(node => {
            node.isSelected = value;
            if (Array.isArray(node._children)) this._traverseAndSetIsSelected(node._children, value);
            if (Array.isArray(node.children)) this._traverseAndSetIsSelected(node.children, value);
        });
    }

    _setIsSelectedById(nodes, id, value) {
        if (!Array.isArray(nodes)) return false;
        for (const node of nodes) {
            if (node.Id === id) {
                node.isSelected = value;
                return true;
            }
            if (Array.isArray(node._children) && this._setIsSelectedById(node._children, id, value)) return true;
            if (Array.isArray(node.children) && this._setIsSelectedById(node.children, id, value)) return true;
        }
        return false;
    }

    handleUnitsPrevPage() {
        if (this.currentUnitsPage > 1) {
            this.currentUnitsPage--;
            this.updateUnitsPagination();
        }
    }

    handleUnitsNextPage() {
        if (this.currentUnitsPage < this.totalUnitsPages) {
            this.currentUnitsPage++;
            this.updateUnitsPagination();
        }
    }

    updateUnitsPagination() {
        if (!this.filteredUnits || this.filteredUnits.length === 0) {
            this.totalUnitsPages = 0;
            this.currentUnitsPage = 1;
            this.paginatedUnits = [];
            return;
        }

        this.totalUnitsPages = Math.ceil(this.filteredUnits.length / this.unitsPageSize);

        if (this.currentUnitsPage > this.totalUnitsPages && this.totalUnitsPages > 0) {
            this.currentUnitsPage = this.totalUnitsPages;
        } else if (this.totalUnitsPages === 0) {
            this.currentUnitsPage = 1;
        }

        const start = (this.currentUnitsPage - 1) * this.unitsPageSize;
        const end = Math.min(start + this.unitsPageSize, this.filteredUnits.length);

        this.paginatedUnits = this.filteredUnits.slice(start, end);
    }

    toggleUnitsFilterBox() {
        this.showUnitsFilterBox = !this.showUnitsFilterBox;
    }

    handleUnitFilterChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail.value;

        this.unitFilters = {
            ...this.unitFilters,
            [field]: value
        };
    }

    resetUnitFilters() {
        this.unitFilters = {
            searchKey: '',
            projectName: '',
            unitType: '',
            bedrooms: '',
            status: ''
        };

        // Reset to show ALL units
        this.filteredUnits = [...this.units];
        this.showUnitsFilterBox = false;
        this.currentUnitsPage = 1;
        this.updateUnitsPagination();

        this.showToast('Filters reset successfully', 'info');
    }


    applyUnitFilters() {
        let filtered = [...this.units]; // Start with ALL units

        // Apply text search across multiple fields
        if (this.unitFilters.searchKey) {
            const searchKey = this.unitFilters.searchKey.toLowerCase().trim();
            filtered = filtered.filter(unit => {
                const unitName = (unit.unitName || '').toLowerCase();
                const projectName = (unit.projectName || '').toLowerCase();
                const unitType = (unit.unitType || '').toLowerCase();
                const bedrooms = (unit.numberOfBedrooms || '').toString().toLowerCase();
                const status = (unit.unitStatus || '').toLowerCase();

                return unitName.includes(searchKey) ||
                    projectName.includes(searchKey) ||
                    unitType.includes(searchKey) ||
                    bedrooms.includes(searchKey) ||
                    status.includes(searchKey);
            });
        }

        // Apply each dropdown filter if they have values
        if (this.unitFilters.projectName) {
            filtered = filtered.filter(unit =>
                unit.projectName === this.unitFilters.projectName
            );
        }

        if (this.unitFilters.unitType) {
            filtered = filtered.filter(unit =>
                unit.unitType === this.unitFilters.unitType
            );
        }

        if (this.unitFilters.bedrooms) {
            filtered = filtered.filter(unit =>
                unit.numberOfBedrooms === this.unitFilters.bedrooms
            );
        }

        if (this.unitFilters.status) {
            filtered = filtered.filter(unit =>
                unit.unitStatus === this.unitFilters.status
            );
        }

        // Update the filtered units
        this.filteredUnits = filtered;
        this.showUnitsFilterBox = false;
        this.currentUnitsPage = 1;
        this.updateUnitsPagination();

        this.showToast(`Found ${this.filteredUnits.length} units matching your filters`, 'success');
    }

    // ===== PRESELECTED UNITS METHODS =====
    async checkForPreSelectedUnits() {
        const storedUnits = sessionStorage.getItem('selectedUnitsForOffer');
        if (storedUnits) {
            try {
                const unitData = JSON.parse(storedUnits);
                const unitIds = unitData.map(unit => unit.unitId);

                const result = await handlePreselectedUnitsFromUnitPage({
                    unitIds: unitIds
                });

                if (result && result.hasPreselectedUnits) {
                    this.preselectedUnits = unitData;
                    sessionStorage.removeItem('selectedUnitsForOffer');

                    this.hasPreselectedUnits = true;
                    this.pendingUnitData = this.preselectedUnits;

                    this.showToast(`${this.preselectedUnits.length} unit(s) preselected from Unit page. Please select leads and click "Continue with Preselected Units" to proceed.`, 'info');
                }
            } catch (error) {
                console.error('Error handling preselected units:', error);
                const unitData = JSON.parse(storedUnits);
                this.preselectedUnits = unitData;
                sessionStorage.removeItem('selectedUnitsForOffer');
                this.hasPreselectedUnits = true;
                this.pendingUnitData = this.preselectedUnits;
                this.showToast(`${this.preselectedUnits.length} unit(s) preselected from Unit page. Please select leads to continue.`, 'info');
            }
        }
    }

    handlePreselectedUnitFlow() {
        if (this.selectedLeads.length === 0) {
            this.showToast('Please select at least one lead first to assign the preselected units.', 'warning');
            return;
        }

        if (this.pendingUnitData && this.pendingUnitData.length > 0) {
            this.showUnitSearchModal = true;
            this.preloadPreselectedUnits();
        }
    }

    async preloadPreselectedUnits() {
        if (!this.preselectedUnits || this.preselectedUnits.length === 0) return;

        const unitIds = this.preselectedUnits.map(unit => unit.unitId);

        try {
            const result = await getPreselectedUnitDetails({ unitIds: unitIds });

            if (result && result.length > 0) {
                this.units = result.map(unit => ({
                    id: unit.Id,
                    name: unit.Name,
                    projectName: unit.ProjectName,
                    phaseName: unit.PhaseName,
                    plotArea: unit.PlotArea,
                    bedrooms: unit.Bedrooms,
                    totalPrice: unit.TotalPrice,
                    isSelected: true
                }));

                this.updateSelectedUnits();

                if (this.preselectedUnits.length > 0) {
                    const firstUnit = this.preselectedUnits[0];
                    this.selectedProject = firstUnit.projectId;
                    await this.loadBuildingsForProject();
                    this.selectedBuilding = firstUnit.phaseId;

                    if (this.selectedUnits.length > 0) {
                        await this.loadPaymentPlans();
                    }
                }
            }
        } catch (error) {
            console.error('Error loading preselected units:', error);
            this.showToast('Error loading preselected units', 'error');
        }
    }

    clearPendingUnits() {
        this.hasPreselectedUnits = false;
        this.pendingUnitData = null;
        this.preselectedUnits = [];
    }


    // ===== LEAD DETAILS METHODS =====
    async loadSelectedLeadDetails() {
        if (this.selectedLeads.length === 0) return;

        try {
            const leadDetails = await getLeadDetails({ leadId: this.selectedLeads[0] });
            this.selectedLeadDetails = leadDetails;
        } catch (error) {
            console.error('Error loading lead details:', error);
        }
    }


    handlePreviewUnitTabClick(event) {
        event.preventDefault();
        const unitId = event.currentTarget.dataset.unitid;
        if (!unitId) return;

        // Find index
        const idx = this.selectedUnitsData.findIndex(u => u.id === unitId);
        this.activeUnitIndex = idx >= 0 ? idx : 0;

        // Set preview id and url for this unit
        this.activePreviewUnitId = unitId;
        this.activePreviewUnitName = this.selectedUnitsData[this.activeUnitIndex]?.name || '';
        this.activePreviewUrl = this.unitPreviewUrls[unitId] || '';
        this.hasActivePreview = !!this.activePreviewUrl;

        // Ensure only clicked tab is active
        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            previewTabClass: index === this.activeUnitIndex
                ? 'slds-tabs_default__item slds-is-active'
                : 'slds-tabs_default__item',
            isActivePreview: index === this.activeUnitIndex
        }));

        this.selectedPaymentPlan = this.selectedUnitsData[this.activeUnitIndex]?.selectedPaymentPlanId || '';
    }

    initializePreviewTabs() {
        if (this.selectedUnitsData.length > 0) {
            this.selectedUnitsData = this.selectedUnitsData.map(unit => ({
                ...unit,
                isActivePreview: false,
                previewTabClass: 'slds-tabs_default__item'
            }));

            const firstUnitId = this.selectedUnitsData[0].id;
            this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => {
                if (index === 0) {
                    return {
                        ...unit,
                        isActivePreview: true,
                        previewTabClass: 'slds-tabs_default__item slds-is-active'
                    };
                }
                return unit;
            });

            const firstUnit = this.selectedUnitsData[0];
            this.activePreviewUnitId = firstUnitId;
            this.activePreviewUnitName = firstUnit.name;
            this.activePreviewUrl = firstUnit.previewUrl;
            this.hasActivePreview = !!this.activePreviewUrl;
        }
    }

    updatePreviewTabClasses() {
        this.selectedUnitsData = this.selectedUnitsData.map(unit => ({
            ...unit,
            previewTabClass: unit.isActivePreview
                ? 'slds-tabs_default__item slds-is-active'
                : 'slds-tabs_default__item'
        }));
    }

    hasPreview(unitId) {
        return this.unitPreviewUrls[unitId] && this.unitPreviewUrls[unitId].startsWith('/apex/');
    }

    downloadPDF(pdfUrl) {
        const link = document.createElement('a');
        link.href = pdfUrl;
        link.target = '_blank';
        link.download = 'Sales_Offer_' + new Date().toISOString().split('T')[0] + '.pdf';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }


    // ===== STEP NAVIGATION METHODS =====
    handleStepClick(event) {
        const targetStep = parseInt(event.currentTarget.dataset.step);

        if (targetStep <= this.currentStep) {
            this.navigateToStep(targetStep);
        }
    }

    async navigateToStep(stepNumber) {
        if (!await this.validateCurrentStep()) {
            return;
        }

        this.currentStep = stepNumber;

        if (this.currentStep === 2) {
            await this.loadPaymentPlans();
        } else if (this.currentStep === 3) {
            await this.generateOfferPreview();
        }
    }

    async validateCurrentStep() {
        if (this.currentStep === 1) {
            const selectedUnits = this.filteredUnits.filter(unit => unit.isSelected);
            if (selectedUnits.length === 0) {
                this.showToast('Please select at least one unit to proceed.', 'error');
                return false;
            }
            return true;
        }

        if (this.currentStep === 2) {
            if (!this.selectedPaymentPlan) {
                this.showToast('Please select a payment plan to proceed.', 'error');
                return false;
            }

            if (this.alNaseemSelected && !this.selectedDesign) {
                this.showToast('Please select a Facade Style for Al Naseem units.', 'error');
                return false;
            }
            return true;
        }

        return true;
    }


    // ===== UNIT SEARCH AND OFFER GENERATION METHODS =====

    // 1. Modal Control Methods
    openUnitSearch() {
        if (this.selectedLeads.length === 0) {
            this.showToast('Please select at least one lead first.', 'error');
            return;
        }

        this.showUnitSearchModal = true;
        this.currentStep = 1;
        this.resetUnitSearch();
        this.loadAllAvailableUnits();
    }

    closeUnitSearch() {
        this.showUnitSearchModal = false;
        this.resetUnitSearch();
    }

    resetUnitSearch() {
        this.currentStep = 1;
        this.selectedProject = '';
        this.selectedBuilding = '';
        this.selectedUnits = [];
        this.units = [];
        this.buildingList = [];
        this.resetPaymentSection();
    }

    resetPaymentSection() {
        this.showPaymentPlan = false;
        this.showPaymentDetails = false;
        this.selectedPaymentPlan = '';
        this.paymentPlanOptions = [];
        this.paymentPlanDetails = null;
    }

    // 2. Step Navigation Methods
    async handleNextStep() {
        // Reset validation messages
        this.showUnitValidationError = false;
        this.showFacadeValidationError = false;
        this.showUnavailableUnitsError = false;

        if (this.currentStep === 1) {
            // Show spinner for step 1 validation
            this.isStepOneLoading = true;

            const selectedUnits = this.filteredUnits.filter(unit => unit.isSelected);

            // Validation 1: Check if any units are selected
            if (selectedUnits.length === 0) {
                this.isStepOneLoading = false;
                this.showUnitValidationError = true;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please select at least one unit to proceed.', 'error'
                );
                return;
            }

            // Validation 2: Check if any selected units are unavailable
            const unavailableUnits = this.getUnavailableUnits();
            if (unavailableUnits.length > 0) {
                this.isStepOneLoading = false;
                this.handleUnavailableUnitsError(unavailableUnits);

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please remove unavailable units before proceeding.', 'error'
                );
                return;
            }

            // Validation 3: Check if all selected units are actually available
            const allUnitsAvailable = selectedUnits.every(unit => this.isUnitAvailable(unit.id));
            if (!allUnitsAvailable) {
                this.isStepOneLoading = false;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Some selected units are no longer available. Please refresh and try again.', 'error'
                );
                return;
            }

            try {
                // Update selected units data
                this.selectedUnits = selectedUnits.map(unit => unit.id);
                this.updateSelectedUnits();

                // Move to step 2
                this.currentStep = 2;

                // Load payment plans for the first unit
                await this.loadPaymentPlansForActiveUnit();

                this.template.querySelector('c-mbp_customshowtoast').show(
                    `Successfully selected ${selectedUnits.length} unit(s)`, 'success'
                );

            } catch (error) {
                console.error(' Error proceeding to step 2:', error);

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Error loading payment plans: ' + this.getErrorMessage(error), 'error'
                );

            } finally {
                this.isStepOneLoading = false;
            }

        } else if (this.currentStep === 2) {
            // Show spinner for step 2 validation
            this.isStepTwoLoading = true;

            // Validation 1: Check if we still have the active unit data
            if (!this.activeUnitData) {
                this.isStepTwoLoading = false;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Unit data is not available. Please go back and reselect units.', 'error'
                );
                return;
            }

            // Validation 2: Check if payment plan is selected for the ACTIVE unit
            const activeUnit = this.selectedUnitsData[this.activeUnitIndex];
            if (!activeUnit || !activeUnit.selectedPaymentPlanId) {
                this.isStepTwoLoading = false;
                this.showUnitValidationError = true;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    `Please select a payment plan for ${activeUnit?.name || 'the selected unit'} to proceed.`, 'error'
                );
                return;
            }

            // Validation 3: Check if payment plan is selected globally (for backward compatibility)
            if (!this.selectedPaymentPlan) {
                this.isStepTwoLoading = false;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please select a payment plan to proceed.', 'error'
                );
                return;
            }

            // Validation 4: Check facade style for Al Naseem units
            const hasAlNaseemUnits = this.selectedUnitsData.some(unit => {
                return unit.projectName && (
                    unit.projectName === 'Al Naseem' ||
                    unit.projectName === 'Al Naseem C' ||
                    unit.projectName.toLowerCase().includes('al naseem') ||
                    unit.projectName.toLowerCase().includes('naseem')
                );
            });

            if (hasAlNaseemUnits && !this.selectedDesign) {
                this.isStepTwoLoading = false;
                this.showFacadeValidationError = true;

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Please select a Facade Style for Al Naseem units.', 'error'
                );
                return;
            }

            // Validation 5: Double-check that selected units are still available
            const unavailableUnits = this.getUnavailableUnits();
            if (unavailableUnits.length > 0) {
                this.isStepTwoLoading = false;
                this.handleUnavailableUnitsError(unavailableUnits);

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Some selected units are no longer available. Please go back and reselect units.', 'error'
                );
                return;
            }

            // Validation 6: Ensure ALL units have payment plans assigned
            const unitsWithoutPlans = this.selectedUnitsData.filter(unit => !unit.selectedPaymentPlanId);
            if (unitsWithoutPlans.length > 0) {
                // Assign payment plans to units without them
                for (const unit of unitsWithoutPlans) {
                    // Copy the active unit's payment plan to other units if they don't have one
                    unit.selectedPaymentPlanId = activeUnit.selectedPaymentPlanId;
                    unit.selectedPaymentPlanName = activeUnit.selectedPaymentPlanName;
                }
            }

            try {
                // **CRITICAL: Ensure payment plan data is saved for all units**
                // Move to step 3
                this.currentStep = 3;

                // Generate previews for all selected units
                await this.generateOfferPreview();

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Payment plan confirmed. Generating offer previews...', 'success'
                );

            } catch (error) {
                console.error(' Error proceeding to step 3:', error);

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Error generating offer previews: ' + this.getErrorMessage(error), 'error'
                );
            } finally {
                this.isStepTwoLoading = false;
            }

        } else if (this.currentStep === 3) {
            // Final validation before generating offers
            this.isGeneratingOffer = true;

            try {
                // Final validation: Check if everything is still valid
                const validationErrors = [];

                if (this.selectedLeads.length === 0) {
                    validationErrors.push('No leads selected');
                }

                if (this.selectedUnits.length === 0) {
                    validationErrors.push('No units selected');
                }

                // Check that ALL units have payment plans
                const unitsWithoutPlans = this.selectedUnitsData.filter(unit => !unit.selectedPaymentPlanId);
                if (unitsWithoutPlans.length > 0) {
                    validationErrors.push(`Payment plan not selected for: ${unitsWithoutPlans.map(u => u.name).join(', ')}`);
                }

                // Check for unavailable units one final time
                const unavailableUnits = this.getUnavailableUnits();
                if (unavailableUnits.length > 0) {
                    validationErrors.push(`Some units are unavailable: ${unavailableUnits.map(u => u.name).join(', ')}`);
                }

                // Check facade style for Al Naseem one final time
                const hasAlNaseemUnits = this.selectedUnitsData.some(unit => {
                    return unit.projectName && (
                        unit.projectName === 'Al Naseem' ||
                        unit.projectName === 'Al Naseem C' ||
                        unit.projectName.toLowerCase().includes('al naseem')
                    );
                });

                if (hasAlNaseemUnits && !this.selectedDesign) {
                    validationErrors.push('Facade style not selected for Al Naseem units');
                }

                if (validationErrors.length > 0) {
                    this.template.querySelector('c-mbp_customshowtoast').show(
                        'Validation errors: ' + validationErrors.join('; '), 'error'
                    );
                    this.isGeneratingOffer = false;
                    return;
                }

                // If all validations pass, generate the offers
                await this.handleGenerateOffer();

            } catch (error) {
                console.error(' Error in final step:', error);

                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Error generating offers: ' + this.getErrorMessage(error), 'error'
                );
            } finally {
                this.isGeneratingOffer = false;
            }
        }
    }

    handleDesignChange(event) {
        this.selectedDesign = event.detail.value;

        // Clear validation error when user selects a facade style
        if (this.selectedDesign && this.showFacadeValidationError) {
            this.showFacadeValidationError = false;
        }
    }

    get currentStepString() {
        return this.currentStep.toString();
    }

    handlePreviousStep() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }

    // 3. Data Loading Methods
    async loadAllAvailableUnits() {
        try {
            this.isStepOneLoading = true;

            // Use getRecords exactly like Units component
            const units = await getRecords({
                objectName: 'Unit__c',
                filters: {},
                fields: [
                    'Id', 'Name', 'BasePrice__c', 'Type__c', 'Status__c',
                    'Number_of_Bedrooms__c', 'Project_Name__c', 'Project__c', 'Phase__c', 'Phase__r.Name', 'Allocate_to_Agent__c',
                    'Allocate_to_Agent__r.Name'
                ]
            });

            if (units && units.length > 0) {
                // Apply broker filtering exactly like Units component
                let filteredUnits = units;

                /*      if (this.brokerType === 'Agent' && this.contactId) {
                          filteredUnits = units.filter(unit =>
                              unit.Allocate_to_Agent__c === this.contactId
                          );
                      }*/

                filteredUnits = filteredUnits.filter(unit => unit.Status__c === 'Available');

                const unitsData = filteredUnits.map(unit => {
                    return {
                        id: unit.Id,
                        name: unit.Name,
                        unitName: unit.Name,
                        projectName: unit.Project_Name__c || unit.Project__r?.Name || 'Project Not Found',
                        projectId: unit.Project__c || unit.ProjectId || null, // important for payment plan filtering
                        unitType: unit.Type__c || 'N/A',
                        numberOfBedrooms: unit.Number_of_Bedrooms__c || 'N/A',
                        basePrice: unit.BasePrice__c || 0,
                        unitStatus: unit.Status__c || 'N/A',
                        phaseName: unit.Phase__r?.Name || '',
                        phaseId: unit.Phase__c || unit.PhaseId || null, // important for payment plan filtering
                        isSelected: false
                    };
                });

                this.units = unitsData;
                this.filteredUnits = [...unitsData]; // Show ALL units by default
                this.populateFilterOptions();

                this.currentUnitsPage = 1;
                this.updateUnitsPagination();
            } else {
                this.units = [];
                this.filteredUnits = [];
                this.paginatedUnits = [];
                this.totalUnitsPages = 0;
                console.warn(' No units returned from server');
                this.showToast('No units found in the system', 'warning');
            }
        } catch (error) {
            console.error(' Error loading units:', error);
            console.error('Error details:', error.body?.message || error.message);
            this.showToast('Error loading units: ' + this.getErrorMessage(error), 'error');
            this.units = [];
            this.filteredUnits = [];
            this.paginatedUnits = [];
            this.totalUnitsPages = 0;
        } finally {
            this.isStepOneLoading = false;
        }
    }

    populateFilterOptions() {
        if (!this.units || this.units.length === 0) {
            console.warn(' No units available to populate filters');
            this.projectFilterOptions = [{ label: 'All', value: '' }];
            this.unitTypeFilterOptions = [{ label: 'All', value: '' }];
            this.bedroomsFilterOptions = [{ label: 'All', value: '' }];
            this.statusFilterOptions = [{ label: 'All', value: '' }];
            return;
        }

        // Get unique project names
        const projects = [...new Set(this.units.map(unit => unit.projectName).filter(name => name && name !== 'Project Not Found'))];
        this.projectFilterOptions = [
            { label: 'All', value: '' },
            ...projects.map(project => ({ label: project, value: project }))
        ];

        // Get unique unit types
        const unitTypes = [...new Set(this.units.map(unit => unit.unitType).filter(type => type && type !== 'N/A'))];
        this.unitTypeFilterOptions = [
            { label: 'All', value: '' },
            ...unitTypes.map(type => ({ label: type, value: type }))
        ];

        // Get unique bedroom counts
        const bedrooms = [...new Set(this.units.map(unit => unit.numberOfBedrooms).filter(bed => bed && bed !== 'N/A'))];
        this.bedroomsFilterOptions = [
            { label: 'All', value: '' },
            ...bedrooms.map(bedroom => ({ label: bedroom, value: bedroom }))
        ];

        // Get unique status values
        const statuses = [...new Set(this.units.map(unit => unit.unitStatus).filter(status => status && status !== 'N/A'))];
        this.statusFilterOptions = [
            { label: 'All', value: '' },
            ...statuses.map(status => ({ label: status, value: status }))
        ];
    }

    async loadProjectsForLead() {
        try {
            this.isLoading = true;
            const result = await getAllProjectsForLead();

            if (result && result.length > 0) {
                this.projectOptions = result.map(project => ({
                    label: project.Name,
                    value: project.Id
                }));
            } else {
                this.projectOptions = [];
                this.showToast('No projects available', 'warning');
            }
        } catch (error) {
            console.error('Error loading projects:', error);
            this.showToast('Error loading projects: ' + this.getErrorMessage(error), 'error');
            this.projectOptions = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadBuildingsForProject() {
        try {
            this.isLoading = true;
            const result = await getAllBuildingsForLead({ projectId: this.selectedProject });

            if (result && result.length > 0) {
                this.buildingList = result;
            } else {
                this.buildingList = [];
                this.showToast('No buildings available for selected project', 'warning');
            }
        } catch (error) {
            console.error('Error loading buildings:', error);
            this.showToast('Error loading buildings: ' + this.getErrorMessage(error), 'error');
            this.buildingList = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadUnitsForBuilding() {
        try {
            this.isLoading = true;
            const result = await getUnitDetailsForLead({
                buildingsId: this.selectedBuilding,
                leadIds: this.selectedLeads
            });

            if (result && result.units && result.units.length > 0) {
                this.units = result.units.map(unit => ({
                    id: unit.Id,
                    name: unit.Name,
                    projectName: unit.ProjectName || 'N/A',
                    phaseName: unit.PhaseName || 'N/A',
                    plotArea: unit.PlotArea || 'N/A',
                    bedrooms: unit.Bedrooms || 'N/A',
                    totalPrice: unit.TotalPrice || 0,
                    isSelected: false
                }));
            } else {
                this.units = [];
                this.showToast('No available units found for the selected building', 'warning');
            }
        } catch (error) {
            console.error('Error loading units:', error);
            this.showToast('Error loading units: ' + this.getErrorMessage(error), 'error');
            this.units = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadPaymentPlans(unitId = null) {
        try {
            const targetUnitId = unitId || (this.selectedUnitsData.length > 0 ? this.selectedUnitsData[this.activeUnitIndex].id : null);

            if (!targetUnitId || this.selectedUnits.length === 0) {
                console.warn(' No units selected for payment plans');
                this.resetPaymentSection();
                return;
            }

            this.isStepTwoLoading = true;

            // Get the active unit data
            const activeUnit = this.selectedUnitsData[this.activeUnitIndex];

            // Use refined getOfferData to get payment plans for ALL selected units
            const result = await getOfferData({
                recordId: this.selectedLeads[0],
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            if (result && result.success && result.paymentPlans) {
                // Filter payment plans for current active unit - check both Unit__c and Phase__c
                const activeUnitPlans = result.paymentPlans.filter(plan => {
                    const matchesUnit = plan.Unit__c === targetUnitId;
                    const matchesPhase = plan.Phase__c === activeUnit.phaseId;
                    return matchesUnit || matchesPhase;
                });

                if (activeUnitPlans.length > 0) {
                    this.paymentPlanOptions = activeUnitPlans.map(plan => ({
                        label: `${plan.Name} (${plan.Unit__r?.Name || plan.Phase__r?.Name || 'Plan'})`,
                        value: plan.Id
                    }));

                    this.showPaymentPlan = true;
                    this.selectedPaymentPlan = this.paymentPlanOptions[0].value;

                    // Load the first payment plan details
                    await this.loadPaymentPlanDetails(activeUnitPlans[0]);
                } else {
                    this.paymentPlanOptions = [];
                    this.showPaymentPlan = false;
                    this.showPaymentDetails = false;
                    console.warn('No payment plans found for unit:', targetUnitId);
                    this.showToast(`No payment plans available for unit ${activeUnit.name}`, 'warning');
                }
            } else {
                this.paymentPlanOptions = [];
                this.showPaymentPlan = false;
                this.showPaymentDetails = false;
                console.warn(' No payment plans in result');
                this.showToast('No payment plans available', 'warning');
            }
        } catch (error) {
            console.error(' Error loading payment plans:', error);
            this.paymentPlanOptions = [];
            this.showPaymentPlan = false;
            this.showPaymentDetails = false;
            this.showToast('Error loading payment plans: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isStepTwoLoading = false;
        }
    }

    async loadPaymentPlansForActiveUnit() {
        if (!this.activeUnitData) {
            console.warn(' No active unit selected');
            return;
        }

        const unitId = this.activeUnitData.id;

        try {
            this.isStepTwoLoading = true;

            // Reset payment plan data
            this.paymentPlanOptions = [];
            this.showPaymentDetails = false;
            this.paymentPlanDetails = null;
            this.installments = [];

            // Get ALL payment plans first
            const result = await getOfferData({
                recordId: this.selectedLeads[0],
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            if (result && result.success && result.paymentPlans) {
                const unitPaymentPlans = result.paymentPlans.filter(plan =>
                    plan.Unit__c === unitId ||
                    plan.Phase__c === this.activeUnitData.phaseId ||
                    plan.Project__c === this.activeUnitData.projectId ||
                    (plan.Unit__r && plan.Unit__r.Name === this.activeUnitData.name)
                );

                if (unitPaymentPlans.length > 0) {
                    this.paymentPlanOptions = unitPaymentPlans.map(plan => ({
                        label: plan.Name,
                        value: plan.Id
                    }));

                   
                    const savedPlanId = this.activeUnitData.selectedPaymentPlanId;
                    const validSavedPlan = savedPlanId && unitPaymentPlans.some(pp => pp.Id === savedPlanId);

                    if (validSavedPlan) {
                        this.selectedPaymentPlan = savedPlanId;
                    } else {
                        this.selectedPaymentPlan = this.paymentPlanOptions[0].value;
                        // Save this as the default for this unit
                        this.activeUnitData.selectedPaymentPlanId = this.selectedPaymentPlan;
                        this.activeUnitData.selectedPaymentPlanName = this.paymentPlanOptions[0].label;
                    }

                    // Load details for selected payment plan
                    const activePlan = unitPaymentPlans.find(pp => pp.Id === this.selectedPaymentPlan);
                    await this.loadPaymentPlanDetails(activePlan);

                } else {
                    console.warn(' No payment plans found for unit:', {
                        unitId: unitId,
                        unitName: this.activeUnitData.name
                    });
                    this.showToast(`No payment plans available for ${this.activeUnitData.name}`, 'warning');
                }
            } else {
                console.warn(' No payment plans in result');
                this.showToast('No payment plans available', 'warning');
            }

        } catch (error) {
            console.error(' Error loading payment plans:', error);
            this.showToast('Error loading payment plans: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isStepTwoLoading = false;
        }
    }

    async loadPaymentPlanDetails(paymentPlanData = null) {
        try {
            if (!paymentPlanData && !this.selectedPaymentPlan) {
                console.warn('No payment plan data provided');
                return;
            }

            this.isStepTwoLoading = true;

            let paymentPlanWithInstallments = paymentPlanData;

            // If no data provided, fetch fresh data
            if (!paymentPlanWithInstallments) {
                const result = await getOfferData({
                    recordId: this.selectedLeads[0],
                    recordType: 'unit',
                    unitIdsJson: JSON.stringify(this.selectedUnits),
                    startDate: null,
                    endDate: null,
                    filterType: null
                });

                if (result && result.paymentPlans) {
                    paymentPlanWithInstallments = result.paymentPlans.find(plan =>
                        plan.Id === this.selectedPaymentPlan
                    );
                }
            }

            if (paymentPlanWithInstallments) {
                this.paymentPlanDetails = paymentPlanWithInstallments;

                
                if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
                    const planName = paymentPlanWithInstallments.Name ||
                        (this.paymentPlanOptions.find(opt => opt.value === this.selectedPaymentPlan)?.label) ||
                        '';
                    const planId = paymentPlanWithInstallments.Id || this.selectedPaymentPlan || '';

                    
                    this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                        if (idx === this.activeUnitIndex) {
                            return {
                                ...u,
                                selectedPaymentPlanName: planName,
                                selectedPaymentPlanId: planId
                            };
                        }
                        return u;
                    });
                }

                // Get installments relationship
                const installmentsData = paymentPlanWithInstallments.Payment_Installments__r || [];

                // Calculate installment amounts using active unit price
                const activeUnit = this.activeUnitData;
                if (activeUnit && activeUnit.totalPrice && installmentsData.length > 0) {
                    this.installments = installmentsData.map(inst => {
                        const milestonePercent = inst.Milestone__c || 0;
                        const amount = (activeUnit.totalPrice * milestonePercent) / 100;

                        return {
                            Id: inst.Id,
                            MilestoneNumber__c: inst.MilestoneNumber__c,
                            MilestoneDescription__c: inst.MilestoneDescription__c,
                            Milestone__c: milestonePercent,
                            amount: amount,
                            BrokerPayout__c: inst.BrokerPayout__c || 0,
                            MilestoneDate__c: inst.MilestoneDate__c,
                            formattedMilestoneDate: inst.MilestoneDate__c ?
                                new Date(inst.MilestoneDate__c).toLocaleDateString('en-IN') : 'N/A'
                        };
                    });
                } else {
                    // default mapping if no unit total price or installments
                    this.installments = installmentsData.map(inst => ({
                        ...inst,
                        amount: 0,
                        formattedMilestoneDate: inst.MilestoneDate__c ?
                            new Date(inst.MilestoneDate__c).toLocaleDateString('en-IN') : 'N/A'
                    }));
                }

                this.showPaymentDetails = true;

            } else {
                // no plan found
                this.installments = [];
                this.showPaymentDetails = false;
                console.warn('No payment plan details found');
            }

        } catch (error) {
            console.error(' Error loading payment plan details:', error);
            this.installments = [];
            this.showPaymentDetails = false;
            this.showToast('Error loading payment details: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isStepTwoLoading = false;
        }
    }

    // 4. Selection Handler Methods
    handleUnitSelection(event) {
        const unitId = event.target.dataset.id;
        const isChecked = event.target.checked;

        // Check if unit is available before allowing selection
        if (isChecked && !this.isUnitAvailable(unitId)) {
            // Show error for unavailable unit
            const unit = this.units.find(u => u.id === unitId);
            if (unit) {
                this.handleUnavailableUnitsError([{ id: unit.id, name: unit.name, status: unit.unitStatus }]);
            }
            // Uncheck the checkbox
            event.target.checked = false;
            return;
        }

        // Clear validation error when user selects available units
        if (isChecked && this.showUnitValidationError) {
            this.showUnitValidationError = false;
        }

        this.updateUnitSelection(unitId, isChecked);
        this.updateSelectedUnits();
    }

    handleSelectAllUnits(event) {
        const isChecked = event.target.checked;

        if (isChecked) {
            // Check only available units
            const availableUnits = this.units.filter(unit => this.isUnitAvailable(unit.id));
            const unavailableUnits = this.units.filter(unit => !this.isUnitAvailable(unit.id));

            // Select all available units
            this.units = this.units.map(unit => ({
                ...unit,
                isSelected: this.isUnitAvailable(unit.id) ? isChecked : false
            }));

            this.filteredUnits = this.filteredUnits.map(unit => ({
                ...unit,
                isSelected: this.isUnitAvailable(unit.id) ? isChecked : false
            }));

            // Show error for unavailable units if user tried to select them
            if (unavailableUnits.length > 0) {
                this.handleUnavailableUnitsError(unavailableUnits);
            }
        } else {
            // Deselect all units
            this.units = this.units.map(unit => ({ ...unit, isSelected: false }));
            this.filteredUnits = this.filteredUnits.map(unit => ({ ...unit, isSelected: false }));
            this.showUnavailableUnitsError = false;
        }

        this.updateUnitsPagination();
        this.updateSelectedUnits();
    }

    // Your existing updateUnitSelection method works fine
    updateUnitSelection(unitId, isChecked) {
        this.units = this.units.map(unit => ({
            ...unit,
            isSelected: unit.id === unitId ? isChecked : unit.isSelected
        }));

        this.filteredUnits = this.filteredUnits.map(unit => ({
            ...unit,
            isSelected: unit.id === unitId ? isChecked : unit.isSelected
        }));

        this.paginatedUnits = this.paginatedUnits.map(unit => ({
            ...unit,
            isSelected: unit.id === unitId ? isChecked : unit.isSelected
        }));
    }


    updateSelectedUnits() {
        // Build selectedUnits from filteredUnits where isSelected === true
        const selectedFilteredUnits = this.filteredUnits.filter(u => u.isSelected);
        this.selectedUnits = selectedFilteredUnits.map(u => u.id);

        // Build selectedUnitsData with payment plan fields
        this.selectedUnitsData = selectedFilteredUnits.map((unit, index) => ({
            ...unit,
            id: unit.id,
            name: unit.name,
            unitName: unit.unitName,
            projectName: unit.projectName,
            phaseName: unit.phaseName,
            totalPrice: unit.totalPrice || unit.basePrice || 0,
            unitType: unit.unitType,
            phaseId: unit.phaseId || unit.Phase__c || unit.phase__c || null,
            projectId: unit.projectId || unit.Project__c || unit.project__c || null,
            unitStatus: unit.unitStatus,
            // UI/tab classes
            tabClass: index === 0 ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item',
            previewTabClass: index === 0 ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item',
            isActivePreview: index === 0,
            isActive: index === 0,
            hasPreview: false,
            previewUrl: '',
            // Initialize empty payment plan fields for each unit
            selectedPaymentPlanName: '',
            selectedPaymentPlanId: '',
            // Track if this unit has payment plan loaded
            paymentPlanLoaded: false
        }));

        // Ensure first unit is active index
        this.activeUnitIndex = 0;

        // If Step 2 is active, load payment plans for the active unit
        if (this.selectedUnitsData.length > 0 && this.currentStep === 2) {
            this.loadPaymentPlansForActiveUnit();
        } else {
            this.resetPaymentSection();
        }
    }

    handleUnitTabClick(event) {
        const idxString = event.currentTarget.dataset.index || event.currentTarget.closest('li')?.dataset.index;
        const clickedIndex = typeof idxString !== 'undefined' ? parseInt(idxString, 10) : 0;

        if (isNaN(clickedIndex)) {
            console.warn('handleUnitTabClick: invalid index', idxString);
            return;
        }

        this.activeUnitIndex = clickedIndex;

        // RETRIEVE: Get the saved payment plan for this unit
        const unit = this.selectedUnitsData[clickedIndex];
        const savedPaymentPlanId = unit.selectedPaymentPlanId || '';

        // Set the selected payment plan from this unit's saved value
        if (savedPaymentPlanId) {
            this.selectedPaymentPlan = savedPaymentPlanId;
        } else {
            this.selectedPaymentPlan = ''; // No saved plan
        }

        // Update tab classes
        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            tabClass: index === clickedIndex ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item',
            isActive: index === clickedIndex
        }));

        // Reload payment plans with the saved value for this unit
        this.loadPaymentPlansForActiveUnit();
    }

    handleUnitTabSelect(event) {
        const clickedIndex = parseInt(event.currentTarget.dataset.index);

        // Update active unit index
        this.activeUnitIndex = clickedIndex;

        // Update tab classes
        this.updateTabClasses();

        // Load payment plans for the selected unit
        this.loadPaymentPlansForActiveUnit();
    }

    updateTabClasses() {
        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            tabClass: index === this.activeUnitIndex ? 'unit-tab active' : 'unit-tab'
        }));
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;
        this.selectedBuilding = '';
        this.units = [];
        this.buildingList = [];
        this.resetPaymentSection();

        if (this.selectedProject) {
            this.loadBuildingsForProject();
        }
    }

    handleBuildingChange(event) {
        this.selectedBuilding = event.detail.value;
        this.units = [];
        this.resetPaymentSection();

        if (this.selectedBuilding && this.selectedLeads.length > 0) {
            this.loadUnitsForBuilding();
        } else if (this.selectedBuilding && this.selectedLeads.length === 0) {
            this.showToast('Please select leads first', 'warning');
        }
    }

    async handlePaymentPlanChange(event) {
        this.selectedPaymentPlan = event.detail.value;

        // STORE: Save the selected plan id for the current active unit
        if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
            // Update payment plan for the active unit
            this.selectedUnitsData[this.activeUnitIndex].selectedPaymentPlanId = this.selectedPaymentPlan;

            // Also store the payment plan name for display
            const selectedOption = this.paymentPlanOptions.find(opt => opt.value === this.selectedPaymentPlan);
            if (selectedOption) {
                this.selectedUnitsData[this.activeUnitIndex].selectedPaymentPlanName = selectedOption.label;
            }
        }

        if (this.selectedPaymentPlan) {
            // Fetch payment plans once and find the selected one
            const result = await getOfferData({
                recordId: this.selectedLeads[0],
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            if (result && result.paymentPlans) {
                const selectedPlan = result.paymentPlans.find(plan => plan.Id === this.selectedPaymentPlan);
                if (selectedPlan) {
                    // Persist the plan name for the active unit
                    if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
                        const planLabel = selectedPlan.Name || (this.paymentPlanOptions.find(opt => opt.value === this.selectedPaymentPlan)?.label) || '';
                        const planId = selectedPlan.Id || '';
                        this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                            if (idx === this.activeUnitIndex) {
                                return {
                                    ...u,
                                    selectedPaymentPlanName: planLabel,
                                    selectedPaymentPlanId: planId
                                };
                            }
                            return u;
                        });
                    }
                    // Load installments and other details
                    await this.loadPaymentPlanDetails(selectedPlan);
                }
            }
        } else {
            // deselected
            this.showPaymentDetails = false;
            this.paymentPlanDetails = null;
            this.installments = [];
        }
    }

    async assignPaymentPlanNamesToSelectedUnits() {
        // This method fetches all payment plans once for the selected lead + units,
        // then assigns the best matching plan name/id to each selected unit entry.
        try {
            if (!this.selectedUnits || this.selectedUnits.length === 0 || !this.selectedLeads || this.selectedLeads.length === 0) {
                return;
            }

            const result = await getOfferData({
                recordId: this.selectedLeads[0],
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            const plans = (result && result.paymentPlans) ? result.paymentPlans : [];

            if (!this.selectedUnitsData || this.selectedUnitsData.length === 0) {
                return;
            }

            // For each selected unit find best matching plan (Unit__c / Phase__c / Project__c / Unit__r.Name)
            this.selectedUnitsData = this.selectedUnitsData.map(unit => {
                let planMatch = plans.find(plan =>
                    plan.Unit__c === unit.id ||
                    plan.Phase__c === unit.phaseId ||
                    plan.Project__c === unit.projectId ||
                    (plan.Unit__r && plan.Unit__r.Name === unit.name)
                );

                // fallback: look for a plan that matches the phase or project if exact unit not found
                if (!planMatch) {
                    planMatch = plans.find(plan => plan.Phase__c === unit.phaseId || plan.Project__c === unit.projectId);
                }

                const planName = planMatch ? (planMatch.Name || planMatch.paymentPlan?.Name || '') : (unit.selectedPaymentPlanName || '');
                const planId = planMatch ? (planMatch.Id || '') : (unit.selectedPaymentPlanId || '');

                return {
                    ...unit,
                    selectedPaymentPlanName: planName,
                    selectedPaymentPlanId: planId
                };
            });
        } catch (err) {
            console.warn(' Failed to assign per-unit payment plan names:', err);
        }
    }

    // 6. Offer Generation Methods
    async generateOfferPreview() {
        try {
            this.isStepThreeLoading = true;
            this.isPdfLoading = true;

            if (!this.selectedUnits || this.selectedUnits.length === 0 || !this.selectedLeads || this.selectedLeads.length === 0) {
                throw new Error('No units or leads selected');
            }

            // **CRITICAL: Double-check all units have payment plans**
            const unitsWithoutPlans = this.selectedUnitsData.filter(u => !u.selectedPaymentPlanId);
            if (unitsWithoutPlans.length > 0) {
                console.warn(' Some units missing payment plans:', unitsWithoutPlans.map(u => u.name));
                await this.assignPaymentPlansToAllUnits();
            }

            const unitNames = this.selectedUnitsData.map(unit => unit.name).filter(name => name);
            let virtualTourUrls = {};

            try {
                virtualTourUrls = await makeDPGApiCall({ unitNames: unitNames });
            } catch (dpgError) {
                console.warn('DPG API call failed, continuing without virtual tours:', dpgError);
               
            }
            

          
            this.unitPreviewUrls = {};

            for (const unitId of this.selectedUnits) {
                try {
                    const unitData = this.selectedUnitsData.find(u => u.id === unitId);
                    const unitPaymentPlanId = unitData?.selectedPaymentPlanId || this.selectedPaymentPlan;

                    if (!unitPaymentPlanId) {
                        console.error(` No payment plan for unit ${unitId}`);
                        continue;
                    }

                    const previewUrl = await generateOfferPDF({
                        leadId: this.selectedLeads[0],
                        unitId: unitId,
                        paymentPlanId: unitPaymentPlanId,  
                        selectedDesign: this.selectedDesign,
                        
                        dpgLink: virtualTourUrls[unitData.name] || ''
                    });

                    if (previewUrl) {
                        this.unitPreviewUrls[unitId] = previewUrl;
                    } else {
                        this.unitPreviewUrls[unitId] = null;
                    }
                } catch (unitError) {
                    console.error(' Failed to generate preview for unit', unitId, ':', unitError);
                    this.unitPreviewUrls[unitId] = null;
                }
            }

            
            this.selectedUnitsData = this.selectedUnitsData.map(unit => ({
                ...unit,
                hasPreview: !!this.unitPreviewUrls[unit.id],
                previewUrl: this.unitPreviewUrls[unit.id] || '',
                
                virtualTourUrl: virtualTourUrls[unit.name] || null
            }));

            
            this.initializePreviewTabs();

            
            setTimeout(() => {
                this.isPdfLoading = false;
            }, 15000);

        } catch (error) {
            console.error('Error generating PDF previews:', error);
            this.showToast('Preview generation failed: ' + (error?.message || error), 'error');
        } finally {
            this.isStepThreeLoading = false;
        }
    }

    async handleGenerateOffer() {
        if (this.selectedUnits.length === 0 || this.selectedLeads.length === 0) {
            this.showToast('Please select at least one lead and one unit.', 'error');
            return;
        }

        if (!this.selectedPaymentPlan) {
            this.showToast('Please select a payment plan.', 'error');
            return;
        }

        // Validate facade style for Al Naseem
        if (this.alNaseemSelected && !this.selectedDesign) {
            this.showToast('Please select a Facade Style for Al Naseem units.', 'error');
            return;
        }

        this.isGeneratingOffer = true;

      
        const unitNames = this.selectedUnitsData.map(unit => unit.name).filter(name => name);
        let virtualTourUrls = {};

        try {
            virtualTourUrls = await makeDPGApiCall({ unitNames: unitNames });
        } catch (dpgError) {
            console.warn('DPG API call failed during offer generation:', dpgError);
            
        }
       

        try {
           
            const unitOptionMap = {};
            const selectedPaymentMap = {};
            const dpgLinkMap = {};


            // Fill maps from selectedUnitsData (if you maintain per-unit selections)
            this.selectedUnits.forEach(unitId => {
                const unitData = this.selectedUnitsData.find(u => u.id === unitId) || {};
                if (unitData.selectedUnitOption) {
                    unitOptionMap[unitId] = unitData.selectedUnitOption;
                }
                if (unitData.paymentDetails && unitData.paymentDetails.selectedPayment) {
                    selectedPaymentMap[unitId] = unitData.paymentDetails.selectedPayment;
                }
                if (unitData.name && this.unitURL && this.unitURL[unitData.name]) {
                    dpgLinkMap[unitId] = this.unitURL[unitData.name];
                }
            });

        
            if ((!selectedPaymentMap || Object.keys(selectedPaymentMap).length === 0) && this.selectedPaymentPlan) {
                selectedPaymentMap['__DEFAULT__'] = this.selectedPaymentPlan;
            }

            
            const globalUnitOption = this.selectedUnitsData[0] && this.selectedUnitsData[0].selectedUnitOption ? this.selectedUnitsData[0].selectedUnitOption : '';
            if (globalUnitOption && Object.keys(unitOptionMap).length === 0) {
                unitOptionMap['__DEFAULT__'] = globalUnitOption;
            }

           
            if (this.selectedUnitsData[0] && this.selectedUnitsData[0].name && this.unitURL && this.unitURL[this.selectedUnitsData[0].name]) {
                if (Object.keys(dpgLinkMap).length === 0) {
                    dpgLinkMap['__DEFAULT__'] = this.unitURL[this.selectedUnitsData[0].name];
                }
            }

            
            const selectedOptionsObj = {
                design: this.selectedDesign || '',
                unitIds: this.selectedUnits,
                unitOptionMap: unitOptionMap,
                selectedPaymentMap: selectedPaymentMap,
               
                dpgLink: virtualTourUrls[this.selectedUnitsData[0]?.name] || ''
            };

           
            const result = await handleOfferAction({
                actionType: 'send',
                unitId: this.selectedUnits[0],              
                leadId: this.selectedLeads[0],
                paymentPlanId: this.selectedPaymentPlan,
                selectedOptions: JSON.stringify(selectedOptionsObj),
                customerName: '' 
            });

            this.showToast(result, 'success');
            this.closeUnitSearch();
            this.refreshLeads();

        } catch (error) {
            console.error('Error generating offers:', error);
            const msg = error?.body?.message || error?.message || 'Unknown error';
            this.showToast('Error generating offers: ' + msg, 'error');
        } finally {
            this.isGeneratingOffer = false;
        }
    }

    async handlePreviewOffer() {
        try {
            this.isLoading = true;
         
            const unitNames = this.selectedUnitsData
                .filter(u => this.selectedUnits.includes(u.id))
                .map(u => u.name)
                .filter(name => name);

            let virtualTourUrls = {};
            try {
                virtualTourUrls = await makeDPGApiCall({ unitNames: unitNames });
            } catch (dpgError) {
                console.warn('DPG API call failed for preview:', dpgError);
            }

            
            const primaryUnit = this.selectedUnitsData.find(u => u.id === this.selectedUnits[0]);
            const dpgLink = primaryUnit && virtualTourUrls[primaryUnit.name] ? virtualTourUrls[primaryUnit.name] : '';
           

            const pdfUrl = await generateSalesOfferPreview({
                leadIds: this.selectedLeads,
                unitIds: this.selectedUnits,
                paymentPlanId: this.selectedPaymentPlan,
                dpgLink: dpgLink
            });

            if (pdfUrl && pdfUrl.startsWith('/apex/')) {
                this.offerPdfUrl = pdfUrl;
                this.showToast('Preview ready', 'success');
               
                this.isPreviewOpen = true;
            } else {
                throw new Error('Invalid PDF URL received');
            }
        } catch (error) {
            console.error(' Error generating preview:', error);
            this.showToast('Error generating preview: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closePreview() {
        this.isPreviewOpen = false;
    }

    viewOfferPdf() {
        
        if (this.alNaseemSelected && !this.selectedDesign) {
            this.showToast('Please select a Facade Style for Al Naseem units before viewing the PDF.', 'error');
            return;
        }

        if (this.offerPdfUrl) {
            window.open(this.offerPdfUrl, '_blank');
        } else {
            this.showToast('No PDF available. Please generate it first.', 'warning');
        }
    }

    
    async handleDownloadPDF() {
        try {
            this.isLoading = true;

            
            if (this.alNaseemSelected && !this.selectedDesign) {
                this.showToast('Please select a Facade Style for Al Naseem units before downloading.', 'error');
                this.isLoading = false;
                return;
            }

            const pdfUrl = await generateSalesOfferPDF({
                leadIds: this.selectedLeads,
                unitIds: this.selectedUnits,
                paymentPlanId: this.selectedPaymentPlan,
                selectedDesign: this.selectedDesign 
            });

            if (pdfUrl) {
                // Create download link
                const link = document.createElement('a');
                link.href = pdfUrl;
                link.target = '_blank';
                link.download = 'Sales_Offer_' + new Date().toISOString().split('T')[0] + '.pdf';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);

                this.showToast('PDF download started', 'success');
            } else {
                throw new Error('No PDF URL received');
            }

        } catch (error) {
            console.error(' Error downloading PDF:', error);
            this.showToast('Error downloading PDF: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // 7. Utility Methods
    updateGenerateOfferButton() {
        const hasSelectedLeads = this.selectedLeads.length > 0;
        const hasSelectedUnits = this.selectedUnits.length > 0;
        const hasPaymentPlan = !!this.selectedPaymentPlan;
    }

    refreshLeads() {
        this.loadLeads();
    }

    // Add this validation method
    validateFacadeSelection() {
        if (this.alNaseemSelected && !this.selectedDesign) {
            this.showToast('Please select a Facade Style for Al Naseem units.', 'error');
            return false;
        }
        return true;
    }

    setOfferGenerationResults(rawResults) {
        this.offerGenerationResults = rawResults.map(res => ({
            ...res,
            resultClass: res.success
                ? 'slds-box slds-theme_success slds-m-bottom_small'
                : 'slds-box slds-theme_error slds-m-bottom_small',
            iconName: res.success ? 'utility:success' : 'utility:error',
            iconClass: res.success ? 'slds-icon-text-success' : 'slds-icon-text-error'
        }));
    }

    // Method to check if unit is available
    isUnitAvailable(unitId) {
        const unit = this.units.find(u => u.id === unitId);
        return unit && unit.unitStatus && unit.unitStatus.toLowerCase() === 'available';
    }

    // Method to get unavailable units from selection
    getUnavailableUnits() {
        const unavailable = [];
        this.selectedUnits.forEach(unitId => {
            if (!this.isUnitAvailable(unitId)) {
                const unit = this.units.find(u => u.id === unitId);
                if (unit) {
                    unavailable.push({
                        id: unit.id,
                        name: unit.name || unit.unitName,
                        status: unit.unitStatus
                    });
                }
            }
        });
        return unavailable;
    }

    // Method to handle unavailable units error
    handleUnavailableUnitsError(unavailableUnits) {
        if (unavailableUnits.length > 0) {
            const unavailableNames = unavailableUnits.map(unit => `${unit.name} (${unit.status})`).join(', ');
            this.unavailableUnitsMessage = unavailableNames;
            this.showUnavailableUnitsError = true;

            // Auto-hide after 5 seconds
            setTimeout(() => {
                this.showUnavailableUnitsError = false;
            }, 5000);
        } else {
            this.showUnavailableUnitsError = false;
        }
    }



    //Mobile code 
    checkMobileView() {
        this.isMobileView = window.innerWidth <= 768;
        if (this.isMobileView) {
            this.loadMobileLeads();
        }
    }

    loadMobileLeads() {
        const start = (this.mobileCurrentPage - 1) * this.mobilePageSize;
        const end = start + this.mobilePageSize;
        this.mobileLeads = this.allLeads.slice(start, end);
        this.mobileTotalPages = Math.ceil(this.allLeads.length / this.mobilePageSize);
    }

    handleMobileLeadSelect(event) {
        const leadId = event.currentTarget.dataset.leadId;
        const isChecked = event.target.checked;

        if (isChecked) {
            this.selectedMobileLeads = [leadId];
            this.mobileLeads.forEach(lead => {
                lead.isSelected = lead.Id === leadId;
            });
        } else {
            this.selectedMobileLeads = [];
        }

        this.isUnitSearchDisabled = this.selectedMobileLeads.length === 0;
    }

    get mobileGenerateOfferBtnClass() {
        return this.isUnitSearchDisabled
            ? 'mobile-action-btn-large primary disabled'
            : 'mobile-action-btn-large primary';
    }
    handleMobileViewLead(event) {
        const leadId = event.currentTarget.dataset.id;
        const clickedRow = this.allLeads.find(lead => lead.Id === leadId);

        if (clickedRow) {
            // Load lead details without changing the main view
            this.loadLeadDetailsForModal(leadId);
            this.showMobileLeadDetails = true;
        }
    }

    //update version 1.5 Changed the logic of Mobile Edit form as per desktop
    handleMobileEditChildLead(event) {
        event.stopPropagation();
        const leadId = event.currentTarget.dataset.id;

        // Find child lead
        const childLead = this.childLeads.find(child => child.Id === leadId);

        if (!childLead) {
            console.error(' Child lead not found for id:', leadId);
            return;
        }

        // Close overview modal
        this.closeMobileLeadDetails();

        this.leadIdBeingEdited = leadId;

        //  STEP 1: Detect lead type
        this.leadType = childLead.Type || 'Individual';

            this.firstName = childLead.FirstName || '';
    this.lastName = childLead.LastName || '';

        //  STEP 2: Set type specific fields
        if (this.leadType === 'Organization') {
            this.orgName = childLead.LastName || '';
            this.company = childLead.LastName || '';
            //   this.tradeNumber = childLead.TradeNumber || '';
            this.unifiedNumber = childLead.UnifiedNumber || '';
            this.uaevatregisternumber = childLead.uaevatregisternumber || '';
            this.vatCertificateType = childLead.vatCertificateType || '';
            this.showVatRegNumber = this.vatCertificateType === 'VAT Registration Certificate';
            //  this.firstName = 'NA';
            //   this.lastName = childLead.LastName || '';
        } else {
            this.title = childLead.Title || '';
            this.orgName = '';
            //   this.tradeNumber = '';
            this.unifiedNumber = '';
            this.uaevatregisternumber = '';
        }

        //  STEP 3: Common fields
        this.email = childLead.Email || '';
        this.mobile = childLead.Mobile || '';
        this.Description = childLead.Description || '';
        this.uaeResidentStatus = childLead.UAEResidentStatus__c || '';
        this.countryOfResidence = childLead.CountryOfResidence__c || '';
        this.nationality = childLead.Nationality__c || '';
        this.salesOrigin = childLead.SalesOrigin__c || '';
        this.leadOrigin = childLead.LeadOrigin__c || '';
        this.salesType = childLead.SalesType__c || '';
        this.projectName = childLead.ProjectInterest__c || '';
        this.propertyUsage = childLead.PropertyUsage__c || '';
        this.numberOfBeds = childLead.NumberOfBedrooms__c || '';
        this.unitType = childLead.UnitType__c || '';
        this.buyRent = childLead.BuyRent__c || '';
        this.purposeOfUse = childLead.PurposeOfUse__c || '';
        this.customerBudget = childLead.CustomerBudget__c || '';
        this.propertyReadiness = childLead.PropertyReadiness__c || '';
        this.financing = childLead.Finance__c || '';
        this.passportNumber = childLead.PassportNumber__c || '';
        this.passportExpiry = childLead.PassportExpiryDate__c || '';
        this.passportIssuance = childLead.PassportIssueDate__c || '';
        this.emiratesId = childLead.EIDNumber__c || '';
        this.emiratesIdExpiry = childLead.EmiratesIDExpiryDate__c || '';

        //  STEP 4: Validation flags
        this.editEmailValidated = true;
        this.editEmailButtonLabel = 'Validated ✅';
        this.editMobileValidated = true;
        this.editMobileButtonLabel = 'Validated ✅';

        //  STEP 5: Field visibility

        this.showPassportFields = true;
        this.showUaeFields = this.uaeResidentStatus === 'Resident';

        //  STEP 6: Picklist options
        if (this.projectToBedsMap && this.projectToBedsMap[this.projectName]) {
            this.numberOfBedsOptions = this.projectToBedsMap[this.projectName]
                .map(val => ({ label: val, value: val }));
        }
        if (this.projectToUnitMap && this.projectToUnitMap[this.projectName]) {
            this.unitTypeOptions = this.projectToUnitMap[this.projectName]
                .map(val => ({ label: val, value: val }));
        } else {
            this.unitTypeOptions = [];
        }

        //  STEP 7: Load documents
        this.loadExistingDocumentsForEdit(leadId);

        //  STEP 8: Open modal
        this.showMobileEditModal = true;
    }

    openMobileFilter() {
        this.showMobileFilter = true;
    }

    closeMobileFilter() {
        this.showMobileFilter = false;
    }



    applyMobileFilters() {
        
        if (this.filters.startDate || this.filters.endDate) {
            
            this.isLoading = true;

            getFilteredLeads({
                userId: this.userId,
                filterType: null,
                startDate: this.filters.startDate,
                endDate: this.filters.endDate
            })
                .then(data => {
                    this.allLeads = data;

                    // Apply local filters (status, search) to the date-filtered data
                    let filtered = [...data];

                    // Apply status filter
                    if (this.filters.status) {
                        filtered = filtered.filter(l =>
                            l.Status?.toLowerCase().includes(this.filters.status.toLowerCase())
                        );
                    }

                    // Apply search filter
                    if (this.filters.searchKey) {
                        const key = this.filters.searchKey.toLowerCase();
                        filtered = filtered.filter(l =>
                            (l.LeadNumber?.toLowerCase().includes(key)) ||
                            (l.Mobile?.toLowerCase().includes(key)) ||
                            (l.Email?.toLowerCase().includes(key)) ||
                            (l.FirstName?.toLowerCase().includes(key)) ||
                            (l.LastName?.toLowerCase().includes(key))
                        );
                    }

                    // Update mobile pagination with filtered data
                    this.mobileTotalPages = Math.ceil(filtered.length / this.mobilePageSize);
                    this.mobileCurrentPage = 1;
                    this.mobileLeads = filtered.slice(0, this.mobilePageSize);

                    this.closeMobileFilter();
                    this.showToast(`Found ${filtered.length} leads`, 'success');
                })
                .catch(error => {
                    console.error('Error fetching filtered leads for mobile:', error);
                    this.showToast('Unable to filter leads', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            // No date filters - apply local filters only

            let filtered = [...this.allLeads];

            // Status filter
            if (this.filters.status) {
                filtered = filtered.filter(l =>
                    l.Status?.toLowerCase().includes(this.filters.status.toLowerCase())
                );
            }

            // Search filter
            if (this.filters.searchKey) {
                const key = this.filters.searchKey.toLowerCase();
                filtered = filtered.filter(l =>
                    (l.LeadNumber?.toLowerCase().includes(key)) ||
                    (l.Mobile?.toLowerCase().includes(key)) ||
                    (l.Email?.toLowerCase().includes(key)) ||
                    (l.FirstName?.toLowerCase().includes(key)) ||
                    (l.LastName?.toLowerCase().includes(key))
                );
            }


            // Update mobile pagination with filtered data
            this.mobileTotalPages = Math.ceil(filtered.length / this.mobilePageSize);
            this.mobileCurrentPage = 1;
            this.mobileLeads = filtered.slice(0, this.mobilePageSize);

            this.closeMobileFilter();
            this.showToast(`Found ${filtered.length} leads`, 'success');
        }
    }


    openMobileAddLead() {
        this.resetFormFields();
        this.showMobileAddModal = true;
    }

    closeMobileAddLead() {
        this.showMobileAddModal = false;
    }

    closeMobileEditLead() {
        this.showMobileEditModal = false;
        this.resetEditModal();
        
        setTimeout(() => {
            this.showMobileLeadDetails = true;
        }, 300);
    }

    openMobileGenerateOffer() {
        if (this.selectedMobileLeads.length === 0) {
            this.showToast('Please select at least one lead', 'error');
            return;
        }

        this.selectedLeads = [...this.selectedMobileLeads];
        this.showMobileGenerateOfferModal = true;
        this.currentStep = 1;

        this.loadAllAvailableUnits();
    }

    closeMobileGenerateOffer() {
        this.showMobileGenerateOfferModal = false;
        this.currentStep = 1;
    }

    handleMobilePrevPage() {
        if (this.mobileCurrentPage > 1) {
            this.mobileCurrentPage--;
            this.loadMobileLeads();
        }
    }

    handleMobileNextPage() {
        if (this.mobileCurrentPage < this.mobileTotalPages) {
            this.mobileCurrentPage++;
            this.loadMobileLeads();
        }
    }

    handleMobileUnitTabClick(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        this.activeUnitIndex = index;
        this.loadPaymentPlansForActiveUnit();
    }

    handleMobilePreviewTabClick(event) {
        const unitId = event.currentTarget.dataset.unitid;
        // Find index
        const idx = this.selectedUnitsData.findIndex(u => u.id === unitId);
        this.activeUnitIndex = idx >= 0 ? idx : 0;

        this.activePreviewUnitId = unitId;
        this.activePreviewUrl = this.unitPreviewUrls[unitId] || '';
        this.hasActivePreview = !!this.activePreviewUrl;

        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            mobilePreviewTabClass: unit.id === unitId
                ? 'mobile-preview-tab-card active'
                : 'mobile-preview-tab-card',
            isActivePreview: unit.id === unitId
        }));

        // Update payment plan for active unit (if you show it on mobile)
        this.selectedPaymentPlan = this.selectedUnitsData[this.activeUnitIndex]?.selectedPaymentPlanId || '';
    }


    handleMobileSelectCurrentLead() {
        if (this.selectedLead?.Id) {
            this.selectedMobileLeads = [this.selectedLead.Id];
            this.isUnitSearchDisabled = false;
            this.showToast('Lead selected for offer', 'success');
        }
    }

    updateMobileLeads() {
        if (this.isMobileView) {
            this.loadMobileLeads();
        }
    }

    get isPrevDisabled() {
        return this.mobileCurrentPage === 1;
    }

    get isNextDisabled() {
        return this.mobileCurrentPage === this.mobileTotalPages;
    }

    handleMobilePreviewTabClickWrapper(event) {
        const unitId = event.currentTarget.dataset.unitid;
        this.handleMobilePreviewTabClick(unitId); // your original method reused
    }

    get actionButtonText() {
        return this.currentStep === 3 ? 'Generate Offer' : 'Next';
    }

    handleActionButtonClick() {
        if (this.currentStep === 3) {
            // Mobile specific: Show who the email is being sent to
            if (this.isMobileView) {
                const leadName = this.selectedLeadName || 'the selected lead';
                // Use the ref directly
                if (this.refs && this.refs.toast) {
                    this.refs.toast.show(
                        `Sending offer email to: ${leadName}`,
                        'info'
                    );
                }
            }
            this.handleGenerateOffer();
        } else {
            this.handleNextStep();
        }
    }
    prepareMobileLeads() {
        this.mobileLeads = this.mobileLeads.map(lead => ({
            ...lead,
            isSelected: this.selectedMobileLeads.includes(lead.Id)
        }));
    }

    get stepCircleClass() {
        let classes = '';
        if (this.currentStep >= 1) classes += ' active';
        if (this.currentStep > 1) classes += ' completed';
        return classes.trim();
    }

    get stepCircleText() {
        return this.currentStep > 1 ? '✓' : '1';
    }

    get step2CircleClass() {
        let classes = '';
        if (this.currentStep >= 2) classes += ' active';
        if (this.currentStep > 2) classes += ' completed';
        return classes.trim();
    }

    get step2CircleText() {
        return this.currentStep > 2 ? '✓' : '2';
    }

    get step3CircleText() {
        return this.currentStep > 3 ? '✓' : '3';
    }
    get step3CircleClass() {
        return this.currentStep >= 3 ? 'active' : '';
    }
    getPaginatedUnitsWithStatusClass() {
        return this.paginatedUnits.map(unit => ({
            ...unit,
            statusClass: unit.unitStatus ? unit.unitStatus.toLowerCase() : ''
        }));
    }

    get formattedInstallments() {
        return this.installments.map(inst => {
            return {
                ...inst,
                formattedAmount: inst.amount ? inst.amount.toLocaleString() : '0'
            };
        });
    }

    get formattedUnits() {
        return this.paginatedUnits.map(unit => ({
            ...unit,
            formattedBasePrice: unit.basePrice ?
                `AED ${unit.basePrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` :
                'N/A'
        }));
    }


    get showPreviousStepButton() {
        return this.currentStep > 1;
    }


    getUnitCardClass(unit) {
        let className = 'mobile-unit-card';
        if (unit.isSelected) {
            className += ' selected';
        }
        if (unit.unitStatus === 'Available') {
            className += ' available';
        } else if (unit.unitStatus === 'Sold') {
            className += ' sold';
        } else if (unit.unitStatus === 'Reserved') {
            className += ' reserved';
        }
        return className;
    }

    getUnitStatusBadgeClass(unit) {
        let className = 'mobile-unit-status-badge';
        if (unit.unitStatus === 'Available') {
            className += ' available';
        } else if (unit.unitStatus === 'Sold') {
            className += ' sold';
        } else if (unit.unitStatus === 'Reserved') {
            className += ' reserved';
        }
        return className;
    }

    getMobileUnitTabCardClass(index) {
        let className = 'mobile-unit-tab-card';
        if (index === this.activeUnitIndex) {
            className += ' active';
        }
        return className;
    }

    getMobilePreviewTabCardClass(unitId) {
        let className = 'mobile-preview-tab-card';
        if (unitId === this.activePreviewUnitId) {
            className += ' active';
        }
        return className;
    }

   
    calculateTotalPayment() {
        if (!this.activeUnitData || !this.installments.length) return '0';

        const total = this.installments.reduce((sum, inst) => {
            return sum + (inst.amount || 0);
        }, 0);

        return total.toLocaleString();
    }

  
    isActiveUnitTab(index) {
        return index === this.activeUnitIndex;
    }

    isActivePreviewTab(unitId) {
        return unitId === this.activePreviewUnitId;
    }

    get processedUnitsForMobile() {
        if (!this.paginatedUnits) return [];

        return this.paginatedUnits.map(unit => {
            let cardClass = 'mobile-unit-card';
            if (unit.isSelected) {
                cardClass += ' selected';
            }
            if (unit.unitStatus === 'Available') {
                cardClass += ' available';
            } else if (unit.unitStatus === 'Sold') {
                cardClass += ' sold';
            } else if (unit.unitStatus === 'Reserved') {
                cardClass += ' reserved';
            }

            let statusBadgeClass = 'mobile-unit-status-badge';
            if (unit.unitStatus === 'Available') {
                statusBadgeClass += ' available';
            } else if (unit.unitStatus === 'Sold') {
                statusBadgeClass += ' sold';
            } else if (unit.unitStatus === 'Reserved') {
                statusBadgeClass += ' reserved';
            }

            return {
                ...unit,
                cardClass: cardClass,
                statusBadgeClass: statusBadgeClass
            };
        });
    }
    get processedMobileUnitTabs() {
        if (!this.selectedUnitsData) return [];

        return this.selectedUnitsData.map((unit, index) => {
            let tabClass = 'mobile-unit-tab-card';
            if (index === this.activeUnitIndex) {
                tabClass += ' active';
            }

            return {
                ...unit,
                index: index,
                mobileTabClass: tabClass,
                isActiveTab: index === this.activeUnitIndex
            };
        });
    }

  
    get calculatedTotalPayment() {
        if (!this.activeUnitData || !this.installments.length) return '0';

        const total = this.installments.reduce((sum, inst) => {
            return sum + (inst.amount || 0);
        }, 0);

        return total.toLocaleString();
    }


  
    processSelectedUnitsForMobile() {
        if (!this.selectedUnitsData) return [];

        return this.selectedUnitsData.map(unit => {
            return {
                ...unit,
                mobilePreviewTabClass: this.getMobilePreviewTabCardClass(unit.id),
                isActivePreview: this.isActivePreviewTab(unit.id)
            };
        });
    }

    
    getMobilePreviewTabCardClass(unitId) {
        let className = 'mobile-preview-tab-card';
        if (unitId === this.activePreviewUnitId) {
            className += ' active';
        }
        return className;
    }

    isActivePreviewTab(unitId) {
        return unitId === this.activePreviewUnitId;
    }

    get processedMobileUnits() {
        if (!this.selectedUnitsData) return [];

        return this.selectedUnitsData.map(unit => ({
            ...unit,
            mobilePreviewTabClass: unit.id === this.activePreviewUnitId
                ? 'mobile-preview-tab-card active'
                : 'mobile-preview-tab-card',
            isActivePreview: unit.id === this.activePreviewUnitId
        }));
    }

    handlePdfLoaded() {
        this.isPdfLoading = false;
    }

    loadLeadDetailsForModal(leadId) {
        const fullParent = this.allLeads.find(item => item.Id === leadId);

        if (fullParent) {
            this.selectedLead = {
                Id: fullParent.Id,
                FirstName: fullParent.FirstName || '',
                LastName: fullParent.LastName || '',
                Salutation: fullParent.Title || '',
                PurposeOfUse__c: fullParent.PurposeOfUse || '',
                Description: fullParent.Description,
                Email: fullParent.Email || '',
                Mobile: fullParent.Mobile || '',
                Status: fullParent.Status || '',
                LeadNumber: fullParent.LeadNumber || '',
                ProjectInterest__c: fullParent.ProjectInterest__c || '',
                PropertyUsage__c: fullParent.PropertyUsage__c || '',
                UnitType__c: fullParent.UnitType__c || '',
                BuyRent__c: fullParent.BuyRent__c || '',
                Finance__c: fullParent.Finance__c || '',
                PassportNumber: fullParent.PassportNumber || '',
                passportIssuance: fullParent.passportIssuance || '',
                PassportExpiryDate: fullParent.PassportExpiryDate || '',
                PassportIssueDate: fullParent.PassportIssueDate || '',
                EIDNumber: fullParent.EIDNumber || '',
                EmiratesIDExpiryDate: fullParent.EmiratesIDExpiryDate || ''
            };

            if (fullParent.children && fullParent.children.length > 0) {
                this.childLeads = fullParent.children.map(child => {
                    const isEditable =
                        child.Status !== 'Qualified' &&
                        child.CreatedById === this.userId &&
                        this.brokerType !== 'Agency Admin';

                    return {
                        Id: child.Id,
                        //  Update version 1.5
                        Type: child.LeadType || 'Individual',
                        TradeNumber: child.TradeNumber || '',
                        UnifiedNumber: child.UnifiedNumber || '',
                         uaevatregisternumber:child.uaevatregisternumber||'',
                        //Update version 1.5
                        Title: child.Title || '',
                        ProjectInterest__c: child.ProjectInterest || '',
                        PropertyUsage__c: child.PropertyUsage || '',
                        BuyRent__c: child.BuyRent || '',
                        Finance__c: child.Finance || '',
                        LeadNumber: child.LeadNumber || '',
                        Status: child.Status || '',
                        eyeIcon: 'utility:edit',
                        editIconClass: isEditable ? 'slds-show' : 'slds-hide',
                        CreatedById: child.CreatedById,
                        FirstName: child.FirstName || '',
                        LastName: child.LastName || '',
                        Description: child.Description,
                        Email: child.Email || '',
                        Mobile: child.Mobile || '',
                        PassportNumber__c: child.PassportNumber || '',
                        PassportExpiryDate__c: child.PassportExpiryDate || '',
                        PassportIssueDate__c: child.PassportIssueDate || '',
                        EIDNumber__c: child.EIDNumber || '',
                        EmiratesIDExpiryDate__c: child.EmiratesIDExpiryDate || '',
                        UAEResidentStatus__c: child.UAEResidentStatus || '',
                        MailingCountry: child.MailingCountry || '',
                        Nationality__c: child.Nationality || '',
                        SalesOrigin__c: child.SalesOrigin || '',
                        LeadSource: child.LeadSource || '',
                        SalesType__c: child.SalesType || '',
                        NumberOfBedrooms__c: child.NumberOfBedrooms || '',
                        UnitType__c: child.UnitType || '',
                        PurposeOfUse__c: child.PurposeOfUse || '',
                        CustomerBudget__c: child.CustomerBudget || '',
                        PropertyReadiness__c: child.PropertyReadiness || '',
                        CountryOfResidence__c: child.CountryOfResidence || '',
                        LeadOrigin__c: child.LeadOrigin || ''
                    };
                });
            } else {
                this.childLeads = [{
                    Id: fullParent.Id,
                    //Update version 1.5
                    Type: fullParent.LeadType || 'Individual',
                    TradeNumber: fullParent.TradeNumber || '',
                    UnifiedNumber: fullParent.UnifiedNumber || '',
                    uaevatregisternumber:fullParent.uaevatregisternumber||'',
                    //Update version 1.5 ends
                    ProjectInterest__c: fullParent.ProjectInterest || '',
                    PropertyUsage__c: fullParent.PropertyUsage || '',
                    UnitType__c: fullParent.UnitType || '',
                    BuyRent__c: fullParent.BuyRent || '',
                    Finance__c: fullParent.Finance || '',
                    LeadNumber: fullParent.LeadNumber || '',
                    Status: fullParent.Status || '',
                    CreatedById: fullParent.CreatedById,
                    FirstName: fullParent.FirstName || '',
                    LastName: fullParent.LastName || '',
                    Salutation: fullParent.Title || '',
                    Email: fullParent.Email || '',
                    Mobile: fullParent.Mobile || '',
                    PassportNumber: fullParent.PassportNumber || '',
                    PassportExpiryDate: fullParent.PassportExpiryDate || '',
                    PassportIssueDate: fullParent.PassportIssueDate || '',
                    EIDNumber: fullParent.EIDNumber || '',
                    EmiratesIDExpiryDate: fullParent.EmiratesIDExpiryDate || '',
                    UAE_Resident_Status__c: fullParent.UAE_Resident_Status__c || '',
                    MailingCountry: fullParent.MailingCountry || '',
                    Nationality__c: fullParent.Nationality__c || '',
                    SalesOrigin__c: fullParent.SalesOrigin || '',
                    LeadSource: fullParent.LeadSource || '',
                    Sales_Type__c: fullParent.Sales_Type__c || '',
                    NumberOfBedrooms__c: fullParent.Number_Of_Beds__c || '',
                    PurposeOfUse__c: fullParent.PurposeOfUse || '',
                    CustomerBudget__c: fullParent.Customer_Budget__c || '',
                    Property_Readiness__c: fullParent.Property_Readiness__c || '',
                    CountryOfResidence__c: fullParent.CountryOfResidence || '',
                    UAEResidentStatus__c: fullParent.UAEResidentStatus || ''
                }];
            }
        }
    }

    // Add close method
    closeMobileLeadDetails() {
        this.showMobileLeadDetails = false;
        // Keep the leads list visible
        this.isManageLeadsActive = true;
        this.showDetails = false;
    }

    handleSelectCurrentLeadForOffer() {
        if (this.selectedLead?.Id) {
            this.selectedMobileLeads = [this.selectedLead.Id];
            this.selectedLeads = [this.selectedLead.Id];
            this.isUnitSearchDisabled = false;
            this.showToast('Lead selected for offer', 'success');
            this.closeMobileLeadDetails();
        }
    }

    formatDate(dateString) {
        if (!dateString) return 'N/A';
        try {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        } catch (error) {
            return dateString;
        }
    }

    loadExistingDocumentsForEdit(leadId) {
        getUploadedDocuments({ leadId: leadId })
            .then(docList => {
                 
                this.emiratesIdFileName = '';
                this.emiratesIdFileNamebackside = '';
                this.passportCopyFileName = '';
                this.passportCopyFileNamebackside = '';

                this.emiratesIdFileUrl = '';
                this.emiratesIdFileUrl1 = '';
                this.passportCopyFileUrl = '';
                this.passportCopyFileUrl1 = '';

                this.deleteemiratesfiles = false;
                this.deleteemiratesfilesbackside = false;
                this.deletepassportfiles = false;
                this.deletepassportfilesbackside = false;

                if (!docList || docList.length === 0) {
                    console.warn(' No uploaded documents found for lead:', leadId);
                    return;
                }

                let emiratesCounter = 0;
                let passportCounter = 0;
                let kycCounter = 0;
                let sourceCounter = 0;
                let tradeLicenseCounter = 0;//Update version 1.5
                let vatCounter = 0; // New for vat

                docList.forEach(doc => {
                    const fileUrl = `/sfc/servlet.shepherd/document/download/${doc.contentDocumentId}`;

                    if (doc.documentType === 'Emirates ID') {
                        if (emiratesCounter === 0) {
                            this.emiratesIdFileName = doc.title;
                            this.emiratesIdFileUrl = fileUrl;
                            this.deleteemiratesfiles = true;
                        } else if (emiratesCounter === 1) {
                            this.emiratesIdFileNamebackside = doc.title;
                            this.emiratesIdFileUrl1 = fileUrl;
                            this.deleteemiratesfilesbackside = true;
                        }
                        emiratesCounter++;
                    }
                    else if (doc.documentType === 'Passport Copy') {
                        if (passportCounter === 0) {
                            this.passportCopyFileName = doc.title;
                            this.passportCopyFileUrl = fileUrl;
                            this.deletepassportfiles = true;
                        } else if (passportCounter === 1) {
                            this.passportCopyFileNamebackside = doc.title;
                            this.passportCopyFileUrl1 = fileUrl;
                            this.deletepassportfilesbackside = true;
                        }
                        passportCounter++;
                    }
                    else if (doc.documentType === 'Complete KYC form') {
                        if (kycCounter === 0) {
                            this.kycFileName = doc.title;
                            this.kycFileUrl = fileUrl;
                            this.deleteKycFile = true;
                        }
                        kycCounter++;
                    }
                    else if (doc.documentType === '3 month Bank statement/source of funds') {
                        if (sourceCounter === 0) {
                            this.sourceFundsFileName = doc.title;
                            this.sourceFundsFileUrl = fileUrl;
                            this.deleteSourceFundsFile = true;
                        }
                        sourceCounter++;
                    }
                    // Update version 1,5
                    else if (doc.documentType === 'Trade License') {
                        if (tradeLicenseCounter === 0) {
                            this.tradeLicenseFileName = doc.title;
                            this.tradeLicenseFileUrl = fileUrl;
                            this.deleteTradeLicenseFile = true;
                        }
                        tradeLicenseCounter++;
                        //Update version 1.5 ends HERE
                    } 
               else if (doc.documentType === 'VAT Register' || doc.documentType === 'VAT Undertaking') {
                    this.vatFileName = doc.title;
                    this.vatFileUrl = `/sfc/servlet.shepherd/document/download/${doc.contentDocumentId}`;
                    this.deleteVatFile = true;
                    
                    // Also set the certificate type based on document type
                    if (doc.documentType === 'VAT Undertaking') {
                        this.vatCertificateType = 'VAT Undertaking Certificate';
                        this.showDummyVatLink = true;
                        this.showVatRegNumber = false;
                    } else {
                        this.vatCertificateType = 'VAT Registration Certificate';
                        this.showVatRegNumber = true;
                        this.showDummyVatLink = false;
                    }
                    vatCounter++;
                }
                    
                    else {
                        console.warn(' Unknown document type received:', doc.documentType);
                    }
                });
            })
            .catch(error => {
                console.error(' Error fetching uploaded documents:', error);
            });
    }

    resetEditModal() {
        this.leadIdBeingEdited = '';
        this.firstName = '';
        this.lastName = '';
        this.title = '';
        this.email = '';
        this.mobile = '';
        this.uaeResidentStatus = '';
        this.countryOfResidence = '';
        this.nationality = '';
        this.salesOrigin = '';
        this.leadOrigin = '';
        this.salesType = '';
        this.projectName = '';
        this.propertyUsage = '';
        this.numberOfBeds = '';
        this.unitType = '';
        this.buyRent = '';
        this.purposeOfUse = '';
        this.customerBudget = '';
        this.propertyReadiness = '';
        this.financing = '';
        this.Description = '';
        this.passportNumber = '';
        this.passportExpiry = '';
        this.passportIssuance = '';
        this.emiratesId = '';
        this.emiratesIdExpiry = '';

        // Reset document files
        this.uploadedKycFileName = '';
        this.uploadedSourceFundsFileName = '';
        this.uploadedEmiratesFileName = '';
        this.uploadedEmiratesFileNamebackside = '';
        this.uploadedPassportFileName = '';
        this.uploadedPassportFileNamebackside = '';

        this.kycFile = null;
        this.sourceFundsFile = null;
        this.emiratesFile = null;
        this.emiratesFilebackside = null;
        this.passportFile = null;
        this.passportFilebackside = null;

        // Reset existing document previews
        this.deleteemiratesfiles = false;
        this.deleteemiratesfilesbackside = false;
        this.deletepassportfiles = false;
        this.deletepassportfilesbackside = false;
        this.deleteKycFile = false;
        this.deleteSourceFundsFile = false;

        // Reset validation
        this.editEmailValidated = false;
        this.editEmailButtonLabel = 'Validate Email';
        this.editMobileValidated = false;
        this.editMobileButtonLabel = 'Validate Mobile';

        this.vatCertificateType = '';
        this.showVatRegNumber = false;
        this.showDummyVatLink = false;
    }


   
    get processedChildLeads() {
        if (!this.childLeads) return [];

        return this.childLeads.map((child, index) => {
            let statusClass = 'mobile-lead-status';
            if (child.Status) {
                const normalizedStatus = child.Status.toLowerCase().replace(/ /g, '-').replace(/_/g, '-');
                statusClass = `mobile-lead-status ${normalizedStatus}`;
            }

            return {
                ...child,
                index: index + 1,
                statusClass: statusClass,
                showEditButton: child.Status === 'New',
                formattedCreatedDate: child.CreatedDate ? this.formatDate(child.CreatedDate) : 'N/A',
                formattedEmail: child.Email || 'N/A',
                formattedMobile: child.Mobile || 'N/A',
                formattedProject: child.ProjectInterest__c || 'N/A',
                formattedUnitType: child.UnitType__c || 'N/A',
                formattedBedrooms: child.NumberOfBedrooms__c || 'N/A',
                formattedDescription: child.Description || 'N/A',
                formattedPurpose: child.PurposeOfUse__c || 'N/A',
                formattedBudget: child.CustomerBudget__c || 'N/A',
                formattedResidentStatus: child.UAEResidentStatus__c || 'N/A',
                formattedSalesType: child.SalesType__c || 'N/A'
            };
        });
    }

    
    openPreviewInNewWindow() {
        if (!this.activePreviewUrl) {
            this.showToast('No preview available to open', 'error');
            return;
        }

        try {
            
            window.open(this.activePreviewUrl, '_blank', 'noopener,noreferrer');

           
            this.showToast('Opening preview in new window...', 'info');
        } catch (error) {
            console.error('Error opening preview:', error);
            this.showToast('Error opening preview: ' + error.message, 'error');
        }
    }

    
    get hasActivePreview() {
        return !!this.activePreviewUrl && this.activePreviewUrl.startsWith('/apex/');
    }

    get isPreviewDisabled() {
        return !this.hasActivePreview;
    }

    async assignPaymentPlansToAllUnits() {
        try {
           
            const result = await getOfferData({
                recordId: this.selectedLeads[0],
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            const allPlans = (result && result.paymentPlans) ? result.paymentPlans : [];

            
            this.selectedUnitsData = this.selectedUnitsData.map(unit => {
               
                if (unit.selectedPaymentPlanId && unit.selectedPaymentPlanName) {
                    return unit;
                }

              
                let bestPlan = allPlans.find(plan =>
                    plan.Unit__c === unit.id ||  
                    plan.Phase__c === unit.phaseId ||  
                    plan.Project__c === unit.projectId  
                );

            
                if (!bestPlan) {
                    bestPlan = allPlans.find(plan => plan.Project__c === unit.projectId);
                }

                if (bestPlan) {
                    return {
                        ...unit,
                        selectedPaymentPlanId: bestPlan.Id,
                        selectedPaymentPlanName: bestPlan.Name
                    };
                } else {
                    console.warn(` No payment plan found for unit: ${unit.name}`);
                    return unit;
                }
            });

        } catch (error) {
            console.error(' Error assigning payment plans to all units:', error);
        }
    }
    //Upto above offer and Mobile


    @track vatCertificateType = '';
@track showVatRegNumber = false;

vatCertificateOptions = [
    { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
    { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
];

handleVatCertificateTypeChange(event) {
    const value = event.detail.value;
    this.vatCertificateType = value;
    
    // Update UI flags
    this.showVatRegNumber = value === 'VAT Registration Certificate';
    this.showDummyVatLink = value === 'VAT Undertaking Certificate';
    this.vatUploadLabel = value === 'VAT Undertaking Certificate' 
        ? 'VAT Undertaking Certificate' 
        : 'VAT Registration Certificate';
}

// Add this method - Download VAT template
downloadVAT() {
    const link = document.createElement('a');
    link.href = MBP_VatUndertakingCertificate;
    link.download = 'VAT_Undertaking_Certificate.docx';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Add VAT file upload handler
handleVatFileUpload(event) {
    const file = event.target.files[0];
    if (file) {
        this.vatFile = file;
        this.uploadedVatFileName = file.name;
        this.vatFileName = file.name;
        this.deleteVatFile = false;
    }
}

// Add VAT file delete handlers
handleDeleteVatFile() {
    this.vatFile = null;
    this.uploadedVatFileName = '';
    this.vatFileName = '';
    this.deleteVatFile = false;
}

handleDeleteVatFile1() {
    this.deleteVatFile = true;
    this.vatFile = null;
    this.uploadedVatFileName = '';
    this.vatFileName = '';
}

}