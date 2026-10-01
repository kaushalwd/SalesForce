/**
* Description: LWC for Customer 360 dashboard
* Author: Chaitanya N
* Name: Customer360Dashboard
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import HTML2CANVAS from '@salesforce/resourceUrl/html2canvas';

import getRecordTypeName from '@salesforce/apex/Customer360Controller.getRecordTypeName';
import getEmailCommunications from '@salesforce/apex/CommunicationsController.getEmailCommunications';
import getProjectAndUnitNames from '@salesforce/apex/Investmentsummerycontroller.getProjectAndUnitNames';
import getServiceRequestList from '@salesforce/apex/ServiceRequestHistoryController.getServiceRequestList';
import getCaseList from '@salesforce/apex/CaseHistoryController.getCaseList';
import getAccountDocuments from '@salesforce/apex/CommunicationsController.getAccountDocuments';
import getVoiceCalls from '@salesforce/apex/CommunicationsController.getVoiceCalls';

import Customer360Emailimage from '@salesforce/resourceUrl/Customer360Emailimage';
import Customer360Documnetsimage from '@salesforce/resourceUrl/Customer360Documnetsimage';
import Customer360chatimage from '@salesforce/resourceUrl/Customer360chatimage';
import Customer360voicecallsimage from '@salesforce/resourceUrl/Customer360voicecallsimage';
import Modon_Logo from '@salesforce/resourceUrl/Customer360modonlogo';
import Customer360Profileicon from '@salesforce/resourceUrl/Customer360Profileicon';
import Calendaricon from '@salesforce/resourceUrl/Calendar_White';
import Arrowdownicon from '@salesforce/resourceUrl/arrowdownicon';
import Unitarrowdownicon from '@salesforce/resourceUrl/unitarrowdownicon';
import Applyfiltericon from '@salesforce/resourceUrl/applyfiltericon';
// import Checkmarkicon from '@salesforce/resourceUrl/checkmarkicon';
// import Resetallicon from '@salesforce/resourceUrl/resetallicon';
import getPersonalInformationData from '@salesforce/apex/PersonalInformationController.getPersonalInformationData';
import updatePersonalInformation from '@salesforce/apex/PersonalInformationController.updatePersonalInformation';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import Customer360warningicon from '@salesforce/resourceUrl/Customer360warningicon';
import Customer360tickicon from '@salesforce/resourceUrl/Customer360tickicon';
import Customer360updateicon from '@salesforce/resourceUrl/Customer360updateicon';
import Customer360Downlodaicon from '@salesforce/resourceUrl/Customer360Downlodaicon';
import Customer360Previewicon from '@salesforce/resourceUrl/Customer360Previewicon';
import customer360coinicon from '@salesforce/resourceUrl/customer360coinicon';
import Customer360Mobileicon from '@salesforce/resourceUrl/Customer360Mobileicon';

import getAccountOwnerPhotoUrl from '@salesforce/apex/Customer360Controller.getAccountOwnerPhotoUrl';
import getAccountOwnerName from '@salesforce/apex/Customer360Controller.getAccountOwnerName';

import getTotalInvestmentValue from '@salesforce/apex/Investmentsummerycontroller.getTotalInvestmentValue';
import getTotalUnitsPurchased from '@salesforce/apex/Investmentsummerycontroller.getTotalUnitsPurchased';
import getAccountSegmentation from '@salesforce/apex/Customer360Controller.getAccountSegmentation';
import { loadStyle } from 'lightning/platformResourceLoader';
import DP_OVERRIDES from '@salesforce/resourceUrl/DatePickerColor';


export default class Customer360Dashboard extends NavigationMixin(LightningElement) {
    html2canvasInitialized = false;

    @track isCapturing = false;
    @track eidFrontFile;
    @track eidBackFile;
    @track passportFile;

    @track eidFrontUrl;
    @track eidBackUrl;
    @track passportUrl;

    @track showSrDrawer = false;
    @track srFilterType;
    @track srDrawerTitle = 'Service Requests';
    @track serviceRequests = [];

    @track showCaseDrawer = false;
    @track cases = [];
    @track isCaseLoading = false;

    @track projectToUnits = [];
    @track unitOptions = [];

    @track userPhotoUrl;
    @track headerOwnerName = '';
    @track headerSegmentation = '';

    totalInvestmentValue;
    _lastPersonalInfoData;

    isLoading = false; // spinner state

    @track projectOptions = [];
    @track unitOptions = [];

    selectedProject = '';
    selectedUnit = '';

    @track appliedProject = '';
    @track appliedUnit = '';

    // Resources
    mobileiocn = Customer360Mobileicon;
    emailImage = Customer360Emailimage;
    documentImage = Customer360Documnetsimage;
    chatImage = Customer360chatimage;
    voiceCallImage = Customer360voicecallsimage;

    modonLogo = Modon_Logo;
    profileicon = Customer360Profileicon;
    downoldicon = Customer360Downlodaicon;
    previewicon = Customer360Previewicon;
    calendaricon = Calendaricon;
    arrowdownicon = Arrowdownicon;
    unitarrowdownicon = Unitarrowdownicon;
    applyfiltericon = Applyfiltericon;
    // checkmarkicon = Checkmarkicon;
    // resetallicon = Resetallicon;

    coinicon = customer360coinicon;
    warningicon = Customer360warningicon;
    updateiocn = Customer360updateicon;
    customertickicon = Customer360tickicon;

    @track groupedFields = [];
    @track showExpiryWarning = false;
    @track expiryWarningText = '';

    @track showModal = false;
    @track modalType = '';
    @track modalNumber = '';
    @track modalExpiryDate = '';

    eidNumber;
    eidExpiry;
    passportExpiry;

    @api recordId;
    recordTypeName;
    isLoaded = false;

    @track voiceCalls = [];
    @track voiceCallCount = 0;
    @track showVoiceCallModal = false;

    @track startDate;
    @track endDate;
    @track appliedStartDate;
    @track appliedEndDate;
    @track filtersApplied = false;

    @track documents = [];
    @track documentCount = 0;
    @track showDocumentModal = false;

    @track emiratesId;
    @track passportNumber;

    @track emails = [];
    @track emailCount = 0;
    @track showEmailDrawer = false;

    @track showChatModal = false;
    @track chatCount = 0; // for UI consistency, can later wire from Apex

    emiratesDocuments = [];
    passportDocuments = [];
    totalUnitsPurchased = 0;
    selectedYear = String(new Date().getFullYear());
    yearOptions = [];
    isSignaturePremier = false;

     calendarStyle = `background-image:url(${Calendaricon}); 
                     background-repeat:no-repeat;
                     background-position:right 3px center;
                     background-size:27px;`;

    dropdownStyle = `background-image:url(${Arrowdownicon}); 
                     background-repeat:no-repeat;
                     background-position:right 3px center;
                     background-size:27px;`;

    unitdropdownStyle = `background-image:url(${Unitarrowdownicon}); 
                     background-repeat:no-repeat;
                     background-position:right 3px center;
                     background-size:27px;`;

    applyfilterStyle = `background-image:url(${Applyfiltericon}); 
                     background-repeat:no-repeat;
                     background-position: right 2px center;
                     background-size: 25px;
                     padding-right: 44px;`;


    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const rid = currentPageReference.state.c__recordId;

            // If recordId not already set by record page, use the one from URL
            if (rid && !this.recordId) {
                this.recordId = rid;
            }
        }
    }

    connectedCallback() {
        this.loadSignaturePremier();
        this.setDefaultDates();
        this.applyDefaultFilters();
        this.initYearOptions();
    }

    async loadSignaturePremier() {
        try {
            const acc = await getAccountSegmentation({ accountId: this.recordId });
            const seg = (acc?.Customer_Segmentation__c || '').trim().toLowerCase();
            const grp = (acc?.Customer_Segemnt_Group__c || '').trim().toLowerCase();
            this.isSignaturePremier = (seg === 'premier' && grp === 'signature');
        } catch (e) {
            this.isSignaturePremier = false;
            // optional: console.error(e);
        }
    }

    initYearOptions() {
        const currentYear = new Date().getFullYear();
        this.yearOptions = [];
        for (let i = 0; i < 5; i++) {
            const y = currentYear - i;
            this.yearOptions.push({ label: String(y), value: String(y) });
        }
    }

    get yearStartDate() {
        return `${this.selectedYear}-01-01`;
    }
    get yearEndDate() {
        return `${this.selectedYear}-12-31`;
    }

    get displayedEmails() {
        return (this.emails || []).slice(0, 5);
    }

    get showViewMore() {
        return (this.emails || []).length > 5;
    }

    handleYearChange(event) {
        this.selectedYear = event.target.value;
    }

   

    setDefaultDates() {
        const now = new Date();

        const toYMD = (d) => {
            const yyyy = d.getFullYear();
            const mm = String(d.getMonth() + 1).padStart(2, '0');
            const dd = String(d.getDate()).padStart(2, '0');
            return `${yyyy}-${mm}-${dd}`;
        };

        // Fixed start date: Jan 1, 2025
        this.startDate = '2025-01-01';

        // End date: today (ex: 2026-01-02)
        this.endDate = toYMD(now);

    }


    @wire(getProjectAndUnitNames, { accountId: '$recordId' })
    wiredNames({ error, data }) {
        if (data) {
            this.projectOptions = (data.projects || []).map((p) => ({ label: p, value: p }));
            this.projectToUnits = data.projectToUnits || [];
            this.unitOptions = [];
        } else if (error) {
            console.error('Error loading project/unit names:', error);
        }
    }

    @wire(getAccountOwnerPhotoUrl, { accountId: '$recordId' })
    wiredOwnerPhoto({ error, data }) {
        if (data) {
            this.userPhotoUrl = data;
        } else if (error) {
            console.error('Error fetching owner photo:', error);
            this.userPhotoUrl = null;
        }
    }

    get profileImageToShow() {
        return this.userPhotoUrl || this.profileicon;
    }

    @wire(getAccountOwnerName, { accountId: '$recordId' })
    wiredOwnerName({ error, data }) {
        if (data) {
            this.headerOwnerName = data;
        } else if (error) {
            console.error('Error fetching owner name:', error);
            this.headerOwnerName = '';
        }
    }


    @wire(getTotalInvestmentValue, {
        accountId: '$recordId',
        startDate: '$appliedStartDate',
        endDate: '$appliedEndDate',
        projectName: '$appliedProject',
        unitName: '$appliedUnit'
    })
    wiredTotalInvestment({ error, data }) {
        if (data !== undefined && data !== null) {
            this.totalInvestmentValue = data;

            if (this._lastPersonalInfoData) {
                this.prepareFields(this._lastPersonalInfoData);
            }
        } else if (error) {
            console.error('Error fetching Total Investment Value:', error);
            this.totalInvestmentValue = null;
        }
    }

    @wire(getTotalUnitsPurchased, {
        accountId: '$recordId',
        startDate: '$appliedStartDate',
        endDate: '$appliedEndDate',
        projectName: '$appliedProject',
        unitName: '$appliedUnit'
    })
    wiredUnitsPurchased({ error, data }) {
        if (data !== undefined && data !== null) {
            this.totalUnitsPurchased = data;

            if (this._lastPersonalInfoData) {
                this.prepareFields(this._lastPersonalInfoData);
            }
        } else if (error) {
            console.error('Error fetching Total Units Purchased:', error);
            this.totalUnitsPurchased = 0;
        }
    }


    handleProjectChange(event) {
        this.selectedProject = event.target.value || '';
        this.appliedProject = this.selectedProject;

        this.selectedUnit = '';
        this.appliedUnit = '';
        this.unitOptions = [];

        if (!this.selectedProject) return;

        // Filter units for selected project
        const units = new Set();
        this.projectToUnits.forEach((pair) => {
            const [proj, unit] = pair.split('|');
            if (proj === this.selectedProject && unit) {
                units.add(unit);
            }
        });

        this.unitOptions = Array.from(units).map((u) => ({ label: u, value: u }));
    }

    handleUnitChange(event) {
        this.selectedUnit = event.target.value || '';
        this.appliedUnit = this.selectedUnit;
    }

    handleUploadFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            const base64Data = e.target.result.split(',')[1];
            const fileType = event.target.dataset.type;

            if (fileType === 'front') {
                this.eidFrontFile = { name: file.name, base64: base64Data, type: file.type };
                this.eidFrontUrl = `data:${file.type};base64,${base64Data}`;
            } else if (fileType === 'back') {
                this.eidBackFile = { name: file.name, base64: base64Data, type: file.type };
                this.eidBackUrl = `data:${file.type};base64,${base64Data}`;
            } else if (fileType === 'passport') {
                this.passportFile = { name: file.name, base64: base64Data, type: file.type };
                this.passportUrl = `data:${file.type};base64,${base64Data}`;
            }
        };

        reader.readAsDataURL(file);
    }

    handleDeleteFile(event) {
        const type = event.target.dataset.type;

        if (type === 'front') {
            this.eidFrontFile = null;
            this.eidFrontUrl = null;
        } else if (type === 'back') {
            this.eidBackFile = null;
            this.eidBackUrl = null;
        } else if (type === 'passport') {
            this.passportFile = null;
            this.passportUrl = null;
        }
    }

    renderedCallback() {
        if (this._dpCssLoaded) return;
        this._dpCssLoaded = true;

        loadStyle(this, DP_OVERRIDES).catch(console.error);
        if (this.html2canvasPromise) return;

        

        this.html2canvasPromise = loadScript(this, HTML2CANVAS)
            .catch((err) => {
                console.error('❌ Failed to load html2canvas', err);
            });

        if (this.emails?.length) {
            this.emails.forEach((email) => {
                const element = this.template.querySelector(`.email-content[data-id="${email.Id}"]`);
                if (element && !element.classList.contains('hidden') && email.Content) {
                    element.innerHTML = email.Content;
                }
            });
        }
    }

    async handleScreenCaptureNative() {
        const stream = await navigator.mediaDevices.getDisplayMedia({ video: true });
        const video = document.createElement('video');
        video.srcObject = stream;
        await video.play();

        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        canvas.getContext('2d').drawImage(video, 0, 0);

        stream.getTracks().forEach(t => t.stop());

        const dataUrl = canvas.toDataURL('image/png');
        const w = window.open('', '_blank');
        w.document.write(`<img src="${dataUrl}" style="width:100%;height:auto;" />`);
        w.document.close();
    }


    async handleScreenCapture() {
        

        // store current UI states
        const prevState = {
            showEmailDrawer: this.showEmailDrawer,
            showDocumentModal: this.showDocumentModal,
            showVoiceCallModal: this.showVoiceCallModal,
            showChatModal: this.showChatModal,
            showModal: this.showModal,
            showSrDrawer: this.showSrDrawer,
            showCaseDrawer: this.showCaseDrawer
        };

        try {
            this.isCapturing = true;

            // Close drawers/modals BEFORE capture (very important)
            this.showEmailDrawer = false;
            this.showDocumentModal = false;
            this.showVoiceCallModal = false;
            this.showChatModal = false;
            this.showModal = false;
            this.showSrDrawer = false;
            this.showCaseDrawer = false;

            // wait for DOM to update
            await Promise.resolve();
            await new Promise((r) => requestAnimationFrame(r));
            await new Promise((r) => setTimeout(r, 50));

            await this.html2canvasPromise;

            const target = this.template.querySelector('.dashboard-container');

            if (!target || !window.html2canvas) return;

            const canvas = await window.html2canvas(target, {
                backgroundColor: '#ffffff',
                scale: 2,
                useCORS: true,
                allowTaint: false,
                logging: true,

                //  Skip iframe/embed/object
                ignoreElements: (el) => {
                    const tag = (el.tagName || '').toLowerCase();
                    return tag === 'iframe' || tag === 'embed' || tag === 'object';
                },

                // Remove ALL iframes from cloned document (global)
                onclone: (clonedDoc) => {
                    clonedDoc.querySelectorAll('iframe, embed, object').forEach((n) => n.remove());
                }
            });

            const dataUrl = canvas.toDataURL('image/png');

            //  SHOW in new tab (most reliable in Salesforce)
            const w = window.open('', '_blank');
            w.document.write(`<title>Customer360 Capture</title><img src="${dataUrl}" style="width:100%;height:auto;" />`);
            w.document.close();

            
        } catch (e) {
            console.error(' Screen capture failed', e);
        } finally {
            //  restore previous UI states
            this.showEmailDrawer = prevState.showEmailDrawer;
            this.showDocumentModal = prevState.showDocumentModal;
            this.showVoiceCallModal = prevState.showVoiceCallModal;
            this.showChatModal = prevState.showChatModal;
            this.showModal = prevState.showModal;
            this.showSrDrawer = prevState.showSrDrawer;
            this.showCaseDrawer = prevState.showCaseDrawer;

            this.isCapturing = false;
        }
    }




    applyDefaultFilters() {
        this.appliedStartDate = this.startDate;
        this.appliedEndDate = this.endDate;
        this.filtersApplied = true;

        
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    handleStartChange(event) {
        this.startDate = event.target.value;
        
    }

    handleEndChange(event) {
        this.endDate = event.target.value;
        
    }

    handleReset() {
        this.setDefaultDates();

        this.selectedProject = '';
        this.selectedUnit = '';

        this.appliedProject = '';
        this.appliedUnit = '';

        this.applyDefaultFilters();

        

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Filters Reset',
                message: 'Your filters have been successfully reset!',
                variant: 'success',
                mode: 'dismissable'
            })
        );
    }

    applyFilters() {
        // simulate delay for filter processing
        setTimeout(() => {
            this.appliedStartDate = this.startDate;
            this.appliedEndDate = this.endDate;
            this.appliedProject = this.selectedProject;
            this.appliedUnit = this.selectedUnit;
            this.filtersApplied = true;

            

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Filters Applied',
                    message: 'Your filters have been successfully applied!',
                    variant: 'success',
                    mode: 'dismissable'
                })
            );
        });
    }

    //  Fetch Record Type
    @wire(getRecordTypeName, { recordId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordTypeName = data;
            this.isLoaded = true;
            
        } else if (error) {
            console.error('🔴 Error fetching record type:', error);
        }
    }

    get individualTabClass() {
        return this.recordTypeName === 'Person Account' ? 'tab selected' : 'tab';
    }

    get organizationTabClass() {
        return this.recordTypeName === 'Organization Account' ? 'tab selected' : 'tab';
    }

    @wire(getEmailCommunications, {
        recordId: '$recordId',
        startDate: '$yearStartDate',
        endDate: '$yearEndDate'
    })
    wiredEmails({ error, data }) {
        if (data) {
            this.emails = data.map((email) => ({
                ...email,
                CreatedDate: new Date(email.CreatedDate).toLocaleString(),
                link: '/lightning/r/Communication_Matrix__c/' + email.Id + '/view'
            }));
            this.emailCount = data.length;
            
        } else if (error) {
            console.error('🔴 Error fetching emails:', error);
            this.emails = [];
            this.emailCount = 0;
        }
    }

    handleViewMore() {
        const year = this.selectedYear || '2026';
        const filterName = `Emails_${year}`;

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Communication_Matrix__c',
                actionName: 'list'
            },
            state: {
                filterName: filterName
            }
        }).then((url) => {
            window.open(url, '_blank');
        });
    }


    // Expand / Collapse handled in JS (no template if:true)
    toggleEmailContent(event) {
        event.stopPropagation();

        const emailId = event.currentTarget.dataset.id;
        const content = this.template.querySelector(`.email-content[data-id="${emailId}"]`);
        const btn = event.currentTarget; // button itself

        if (!content || !btn) return;

        const isHidden = content.classList.contains('hidden');

        if (isHidden) {
            content.classList.remove('hidden');
            content.classList.add('visible');

            // rotate chevron via CSS class
            btn.classList.add('is-open');

            // smooth expand animation
            content.style.maxHeight = content.scrollHeight + 'px';
        } else {
            btn.classList.remove('is-open');

            // smooth collapse animation
            content.style.maxHeight = content.scrollHeight + 'px';
            requestAnimationFrame(() => {
                content.style.maxHeight = '0px';
            });

            // after animation ends, hide
            setTimeout(() => {
                content.classList.add('hidden');
                content.classList.remove('visible');
            }, 200);
        }
    }


    openEmailDrawer() {
        this.showEmailDrawer = true;
        
    }

    closeEmailDrawer() {
        this.showEmailDrawer = false;
        
    }

    // Fetch Voice Calls (with start & end date)
    @wire(getVoiceCalls, { recordId: '$recordId', startDate: '$appliedStartDate', endDate: '$appliedEndDate' })
    wiredVoiceCalls({ error, data }) {
        if (data) {
            

            this.voiceCalls = data.map((call) => ({
                ...call,
                CallStartDateTime: new Date(call.CallStartDateTime).toLocaleString(),
                CallEndDateTime: new Date(call.CallEndDateTime).toLocaleString()
            }));

            this.voiceCallCount = data.length;
        } else if (error) {
            console.error('🔴 Error fetching voice calls:', error);
        }
    }

    // ✅ Modal controls for Voice Calls
    openVoiceCallModal() {
        this.showVoiceCallModal = true;
        
    }

    closeVoiceCallModal() {
        this.showVoiceCallModal = false;
        
    }

    // ✅ Fetch Documents (with start & end date)
    @wire(getAccountDocuments, { recordId: '$recordId', startDate: '$appliedStartDate', endDate: '$appliedEndDate' })
    wiredDocuments({ error, data }) {
        if (data) {

            this.documents = data.documents;
            this.documentCount = this.documents.length;

            this.emiratesId = data.emiratesId;
            this.passportNumber = data.passportNumber;

            this.emiratesDocuments = this.documents.filter(
                (doc) =>
                    doc.Name === 'Emirates/National ID' ||
                    doc.Name === 'Emirates/National ID Front' ||
                    doc.Name === 'Emirates/National ID Back'
            );

            this.passportDocuments = this.documents.filter((doc) => doc.Name === 'Passport');
        } else if (error) {
            console.error('🔴 Error fetching documents:', error);
        }
    }

    openDocumentModal() {
        this.showDocumentModal = true;
        
    }

    closeDocumentModal() {
        this.showDocumentModal = false;
       
    }

    openChatModal() {
        this.showChatModal = true;
       
    }

    closeChatModal() {
        this.showChatModal = false;
       
    }

    @wire(getPersonalInformationData, { recordId: '$recordId', startDate: '$startDate', endDate: '$endDate' })
    wiredData({ error, data }) {
        if (data) {
            this._lastPersonalInfoData = data;

            this.headerName = data['Account Name'] || data['Name'] || '';
            this.headerSegmentation = data['Customer Segmentation'] || '';

            this.prepareFields(data);
        } else if (error) {
            console.error('Error fetching data:', error);
        }
    }

    prepareFields(data) {
        this.groupedFields = [];
        this.showExpiryWarning = false;
        this.expiryWarningText = '';
        this.modalType = ''; // reset modal type
        if (this.isOrganizationAccount) {
            const orgFieldOrder = [
                'Account Name',
                'Trade_License_Number__c',
                'Trade_License_Issue_Date__c',
                'TradeLicenseExpiryDate__c',
                'Company_Name_as_per_Trade_License__c',
                'Total Investment Value',
                'Total Units Purchased',
            ];
            const labelMap = {
                'Account Name': 'Account Name',
                'Trade_License_Number__c': 'Trade License Number',
                'Trade_License_Issue_Date__c': 'Trade License Issue Date',
                'TradeLicenseExpiryDate__c': 'Trade License Expiry Date',
                'Company_Name_as_per_Trade_License__c': 'Company Name as per Trade License',
                'Total Investment Value': 'Total Investment Value',
                'Total Units Purchased': 'Total Units Purchased'
            };

            const getVal = (key) => {
                if (key === 'Total Investment Value') return this.formatCurrencyFullAED(this.totalInvestmentValue);
                if (key === 'Total Units Purchased') return String(this.totalUnitsPurchased ?? 0);

                const raw = data?.[key];
                return raw ? raw : 'N/A';
            };

            this.groupedFields = orgFieldOrder.map((key) => ({
                label: labelMap[key] || key,
                value: getVal(key),
                cssClass: 'value'
            }));

            // ensure modal never appears for org
            this.showModal = false;
            this.modalType = '';
            return;
        }

        const today = new Date();
        const warningMessages = [];
        let eidExpiring = false;
        let passportExpiring = false;

        for (let key in data) {
            const rawValue = data[key];
            const value = rawValue ? rawValue : 'N/A';
            let cssClass = 'value';

            // Emirates ID logic
            if (key.includes('Emirates ID')) {
                if (key.includes('Number')) {
                    this.eidNumber = value;
                }

                if (key.includes('Expiry') && value !== 'N/A') {
                    this.eidExpiry = new Date(value);
                    const diff = this.daysLeft(this.eidExpiry, today);

                    if (diff <= 30) {
                        eidExpiring = true;
                        cssClass = 'value highlight';
                        warningMessages.push(`Emirates ID expires in ${diff} day(s)`);
                    }
                }
            }

            // Passport logic
            if (key.includes('Passport')) {
                if (key.includes('Number')) {
                    this.passportNumber = value;
                }

                if (key.includes('Expiry') && value !== 'N/A') {
                    this.passportExpiry = new Date(value);
                    const diff = this.daysLeft(this.passportExpiry, today);

                    if (diff <= 30) {
                        passportExpiring = true;
                        cssClass = 'value highlight';
                        warningMessages.push(`Passport expires in ${diff} day(s)`);
                    }
                }
            }

            this.groupedFields.push({ label: key, value, cssClass });
        }

        this.groupedFields.push({
            label: 'Total Investment Value',
            value: this.formatCurrencyFullAED(this.totalInvestmentValue),
            cssClass: 'value'
        });
        this.groupedFields.push({
            label: 'Total Units Purchased',
            value: String(this.totalUnitsPurchased ?? 0),
            cssClass: 'value'
        });

        // Handle Expiry Warning and Button Label Dynamically
        if (warningMessages.length > 0) {
            this.showExpiryWarning = true;
            this.expiryWarningText = warningMessages.join(' | ');

            if (eidExpiring && passportExpiring) {
                this.modalType = 'Emirates ID & Passport';
            } else if (eidExpiring) {
                this.modalType = 'Emirates ID';
            } else if (passportExpiring) {
                this.modalType = 'Passport';
            }
        } else {
            this.showExpiryWarning = false;
        }
    }

    daysLeft(expiryDate, today) {
        // Convert both dates to midnight to compare by calendar days only
        const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const end = new Date(expiryDate.getFullYear(), expiryDate.getMonth(), expiryDate.getDate());

        const diffTime = end.getTime() - start.getTime();
        const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

        return diffDays;
    }

    handleUpdateClick() {
        if (this.eidExpiry && this.daysLeft(this.eidExpiry, new Date()) <= 30) {
            this.modalType = 'Emirates ID';
            this.modalNumber = this.eidNumber === 'N/A' ? '' : this.eidNumber;
            this.modalExpiryDate = this.formatDate(this.eidExpiry);
        } else if (this.passportExpiry && this.daysLeft(this.passportExpiry, new Date()) <= 30) {
            this.modalType = 'Passport';
            this.modalNumber = this.passportNumber === 'N/A' ? '' : this.passportNumber;
            this.modalExpiryDate = this.formatDate(this.passportExpiry);
        } else {
            return;
        }

        this.showModal = true;
    }

    handleNumberChange(event) {
        this.modalNumber = event.target.value;
    }

    handleExpiryChange(event) {
        this.modalExpiryDate = event.target.value;
    }

    async handleSave() {
       

        this.isLoading = true; // Start spinner

        try {
            // Prepare base64 data if available
            const eidFrontBase64 = this.eidFrontFile ? this.eidFrontFile.base64 : null;
            const eidBackBase64 = this.eidBackFile ? this.eidBackFile.base64 : null;
            const passportBase64 = this.passportFile ? this.passportFile.base64 : null;

            
            await updatePersonalInformation({
                recordId: this.recordId,
                type: this.modalType,
                number1: this.modalNumber,
                expiryDate: this.modalExpiryDate,
                eidFrontBase64: eidFrontBase64,
                eidBackBase64: eidBackBase64,
                passportBase64: passportBase64
            });

             // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `${this.modalType} details updated successfully!`,
                    variant: 'success'
                })
            );

            // Reset after short delay
            setTimeout(() => {
                this.showModal = false;
                this.isLoading = false;
                window.location.reload();
            }, 800);
        } catch (error) {
            this.isLoading = false;
            console.error('%c❌ Apex update failed:', 'color: red; font-weight: bold;', error);

            //  Show error toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating record',
                    message: error?.body?.message || 'Something went wrong while updating.',
                    variant: 'error'
                })
            );
        }
    }

    handleCloseModal() {
        this.showModal = false;
    }

    get modalNumberLabel() {
        return `${this.modalType} Number`;
    }

    get modalExpiryLabel() {
        return `${this.modalType} Expiry Date`;
    }

    get isEmiratesId() {
        return this.modalType === 'Emirates ID';
    }

    get isPassport() {
        return this.modalType === 'Passport';
    }

    get cardClass() {
        return this.showExpiryWarning ? 'executive-summary-card card-warning' : 'executive-summary-card';
    }

    handleOpenSrDrawer(event) {
        const filterType = event.detail.filterType;
        this.srFilterType = filterType;

        const labelMap = {
            total: 'Total SRs',
            open: 'Open SRs',
            closed: 'Closed SRs',
            breached: 'SR Breached Cases'
        };

        this.srDrawerTitle = labelMap[filterType] || 'Service Requests';

        getServiceRequestList({
            recordId: this.recordId,
            startDate: this.appliedStartDate,
            endDate: this.appliedEndDate,
            filterType: filterType
        })
            .then((result) => {
                this.serviceRequests = (result || []).map((sr) => ({
                    ...sr,
                    CreatedDateFormatted: new Date(sr.CreatedDate).toLocaleString(),
                    OwnerName: sr.Owner != null ? sr.Owner.Name : '',
                    RecordTypeName: sr.RecordType != null ? sr.RecordType.Name : '',
                    link: '/lightning/r/ServiceRequest__c/' + sr.Id + '/view'
                }));

                this.showSrDrawer = true;
            })
            .catch((error) => {
                console.error('Error fetching SR list:', error);
                this.serviceRequests = [];
                this.showSrDrawer = true;
            });
    }

    closeSrDrawer() {
        this.showSrDrawer = false;
    }

    handleOpenCaseDrawer(event) {
        const filterType = event.detail.filterType;
        
        this.isCaseLoading = true;
        this.cases = [];
        this.showCaseDrawer = true;

        getCaseList({
            recordId: this.recordId,
            startDate: this.appliedStartDate,
            endDate: this.appliedEndDate,
            filterType: filterType
        })
            .then((result) => {
                const data = result || [];

                this.cases = data.map((cs) => ({
                    ...cs,
                    CreatedDate: cs.CreatedDate ? new Date(cs.CreatedDate).toLocaleString() : '',
                    OwnerName: cs.Owner ? cs.Owner.Name : '',
                    link: '/lightning/r/Case/' + cs.Id + '/view'
                }));

                this.isCaseLoading = false;
            })
            .catch((error) => {
                console.error('Error fetching cases:', error);
                this.cases = [];
                this.isCaseLoading = false;
            });
    }

    closeCaseDrawer() {
        this.showCaseDrawer = false;
    }

    get isUnitDisabled() {
        return !this.selectedProject;
    }

    formatCurrencyAED(val) {
        const num = Number(val);
        if (Number.isNaN(num)) return 'N/A';
        return `${num.toFixed(2)} AED`;
    }

    formatCurrencyCompactAED(value) {
        const num = Number(value);
        if (Number.isNaN(num)) return 'N/A';

        if (num >= 1_000_000_000) {
            return `${(num / 1_000_000_000).toFixed(2)}B AED`;
        }
        if (num >= 1_000_000) {
            return `${(num / 1_000_000).toFixed(2)}M AED`;
        }
        if (num >= 1_000) {
            return `${(num / 1_000).toFixed(2)}K AED`;
        }

        return `${num.toFixed(2)} AED`;
    }
    
    handleExportPdf() {
        const cleanup = () => {
            document.body.classList.remove('c360-print-mode');

            // IMPORTANT: reflow charts back to normal view
            this.resizeAllCharts?.();
            window.removeEventListener('afterprint', cleanup);
        };

        document.body.classList.add('c360-print-mode');
        window.addEventListener('afterprint', cleanup);

        // Let CSS apply and layout settle
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                // Force chart libraries to recalc sizes (you must implement this)
                this.resizeAllCharts?.();

                // Small delay is ok after explicit resize
                setTimeout(() => window.print(), 200);
            });
        });
    }

    handleDownloadSOA() {

        //const vfUrl = `/apex/SOA3?id=${this.recordId}`;
        const vfUrl = `/apex/SOAAccount?id=${this.recordId}`;
        window.open(vfUrl, '_blank');
    }
    formatCurrencyFullAED(value) {
        const num = Number(value);
        if (Number.isNaN(num)) return 'N/A';

        // 12,000,000.00 AED
        return `${num.toLocaleString(undefined, {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })} AED`;
    }
    get isOrganizationAccount() {
        // Primary source: your existing recordTypeName wire
        if (this.recordTypeName === 'Organization Account') return true;

        // Fallback: if your Apex map includes RecordTypeLabel
        const rtLabel = this._lastPersonalInfoData?.RecordTypeLabel;
        return rtLabel === 'Organization';
    }

    get executiveSummaryTitle() {
        return this.isOrganizationAccount ? 'Organization Summary' : 'Executive Summary';
    }

    get hasEmiratesDocuments() {
        return this.emiratesDocuments && this.emiratesDocuments.length > 0;
    }

    get hasPassportDocuments() {
        return this.passportDocuments && this.passportDocuments.length > 0;
    }

    get hasNoDocuments() {
        return !this.documents || this.documents.length === 0;
    }

}