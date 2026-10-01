/**********************************************************************************************************************
* Name               : KycMultiStepForm (LWC)
* Description        : Multi-step KYC form component - handles step navigation, address search,
*                       employment details, trade license/POA upload, and KYC signing session polling
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 2.9          Arvind                              28 July 2026    Journey_Status__c tracking added for customer
*                                                                    step drop-off visibility (Steps 2/3/4, Trade
*                                                                    License upload, POA upload, Sign KYC Form click,
*                                                                    submit success/failure)
**********************************************************************************************************************/
import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import modonLogo from '@salesforce/resourceUrl/Modon_Portal_Logo';
import kycexpiry from '@salesforce/resourceUrl/kycexpired';
import kyccompleted from '@salesforce/resourceUrl/kyccompleted';
import submitData from '@salesforce/apex/CustomerKYCHandler.handleCustomerEarlyData';
import { CurrentPageReference } from 'lightning/navigation';
import getKycRecord from '@salesforce/apex/CustomerKYCHandler.loadInitialData';
import getRequiredPicklists from '@salesforce/apex/CustomerKYCHandler.getRequiredPicklists';
import getSourceofIncome from '@salesforce/apex/CustomerKYCHandler.getSourceOfIncomePicklistValues';
import fetchDocuSignUrl from '@salesforce/apex/CustomerKYCHandler.fetchDocuSignUrl';
import regenerateAndFetchDocuSignUrl from '@salesforce/apex/CustomerKYCHandler.regenerateAndFetchDocuSignUrl'; // Calling method to regenerate the DocuSign URL - Rushi Patel - 20th August 2026
import getTradeLicenseInfo from '@salesforce/apex/CustomerKYCHandler.getTradeLicenseInfo';
import searchLocation from '@salesforce/apex/GeoapifyLocationController.searchLocation';
import getAddressFromLatLong from '@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong';
import updateJourneyStatus from '@salesforce/apex/CustomerKYCHandler.updateJourneyStatus'; // 2.9 Arvind 28 July 2026


export default class KycMultiStepForm extends LightningElement {
    message = 'Almost done! We need few addional details to complete your KYC.';
    subMessage = 'We are preparing your signing session...';
    @track isLoading = true;
    @track sourceOfIncomeDisabled = false;
    @api recordId;
    @track holdDualNationality = false;
    @track isCorporateCustomer = false;
    @track fileUploaded = false;
    @track IsTradeLicenseNotUploaded = false;
    @track eidSponsorName = '';
    @track initialDataLoaded = false;

    // geo search state for address step
    @track addressSearchText = '';
    @track addressSearchResults = [];
    @track showAddressSearchResults = false;
    @track isAddressSearching = false;
    @track addressFieldsUnlocked = false;
    @track streetWithoutVilla = '';
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        this.isLoading = true;
        if (currentPageReference) {
            this.recordId = currentPageReference.state.kycId;
        }
        // this.isLoading = false;
    }
     @track iskycexpired = false;
     @track isKycCompleted = false;
     get showSelectDualNationality() {
        return this.formData.nationality !== 'United Arab Emirates';
    }

    connectedCallback() {
        this.initialDataLoaded = false;
        this.isLoading = true;
        this.loadKycRecord();
    }

    async loadKycRecord() {
        // guard: nothing to do if recordId missing
        if (!this.recordId) {
            
            const url = window.location.origin + '/customerkyc/error';
            window.open(url, '_self');
            this.isLoading = false;
            return;
        }        
        try {
            const result = await getKycRecord({ kycId: this.recordId });
            // your @wire returned JSON (string) — handle both string and object cases
            
            if(result === 'COMPLETED'){
                const url = window.location.origin + '/customerkyc/thankyou';
                window.open(url, '_self');
                this.isLoading = false;
                return;
            }

            // Checking the current status of the KYC Response and redirecting the user - Rushi Patel - 20th August 2026
            if (result === 'DOCUSIGN_PENDING') {
                const url = await regenerateAndFetchDocuSignUrl({ kycId: this.recordId });
                if (url) {
                    window.open(url, '_self');
                } else {
                    const fallbackUrl = window.location.origin + '/customerkyc/signpage';
                    window.open(fallbackUrl, '_self');
                }
                this.isLoading = false;
                return;
            }
            if(result === 'ERROR'){
                const url = window.location.origin + '/customerkyc/error';
                window.open(url, '_self');
                this.isLoading = false;
                return;
            }
            const preloadedData = (typeof result === 'string') ? JSON.parse(result) : result;

            if (preloadedData) {
                this.initialDataLoaded = true;
                // preserve exact logic from your wired handler
              //  this.iskycexpired = !preloadedData.isKycExpired;

                //this.isKycCompleted = preloadedData.kycCompleted;
                this.isCorporateCustomer = preloadedData.isCorporateAccount;

                this.IsTradeLicenseNotUploaded = !preloadedData.IsTradeLicenseUploaded;
                this.eidSponsorName = preloadedData.eidSponsorName;
                // merge into formData
               
                if(preloadedData.dualNationality === 'Yes'){
                    this.holdDualNationality = true;
                    this.formData.dualNationalityCountry = preloadedData.dualNationalityCountry;
                    this.formData = { ...this.formData, dualNationalityCountry: preloadedData.dualNationalityCountry };

                }else{
                    this.holdDualNationality = false;
                }
                this.formData = { ...this.formData, ...preloadedData };

                // 3.2 Arvind 31 July 2026 - Default Employment Status from EID "Profession"
                // value (ASSUMED field name: preloadedData.eidProfession - CONFIRM with
                // actual Apex payload property name before deploying). Runs before the
                // existing Company Name check below; does not alter that block.
                // NOTE: exact employmentStatus picklist label spellings below are assumed
                // (e.g. "House Wife" vs "Housewife", "Self Employed" spacing) - confirm
                // against getRequiredPicklists() values before deploying.
                const eidProfession = (preloadedData.profession || '').trim();
                const eidProfessionLower = eidProfession.toLowerCase();

                if (!this.formData.employmentStatus && eidProfession) {
                    if (eidProfessionLower === 'house wife' || eidProfessionLower === 'housewife') {
                        this.formData = { ...this.formData, employmentStatus: 'House Wife' };
                    } else if (eidProfessionLower === 'not employed' || eidProfessionLower === 'unemployed') {
                        this.formData = { ...this.formData, employmentStatus: 'Unemployed' };
                    } else if (eidProfessionLower === 'student') {
                        this.formData = { ...this.formData, employmentStatus: 'Student' };
                    } else if (eidProfessionLower === 'retired') {
                        this.formData = { ...this.formData, employmentStatus: 'Retired' };
                    } else if (eidProfessionLower === 'self employed') {
                        this.formData = { ...this.formData, employmentStatus: 'Self Employed' };
                    } else {
                        // Any other occupation value (e.g. "Computer Engineer",
                        // "Software Engineer") defaults to Employed.
                        this.formData = { ...this.formData, employmentStatus: 'Employed' };
                    }

                    // 3.4 Arvind 31 July 2026 - when Employment Status resolves to 'Employed'
                    // via the Profession logic above, also pre-fill Company Name from the EID
                    // sponsor name (same pairing handleChange() already does when the user
                    // manually picks 'Employed'), so the customer doesn't have to retype it.
                    if (this.formData.employmentStatus === 'Employed' && this.eidSponsorName) {
                        this.formData = { ...this.formData, companyName: this.eidSponsorName };
                    }
                }

                // 3.0 Arvind 31 July 2026 - REMOVED per instruction (Arvind, 31 July 2026).
                // Previously defaulted Employment Status to 'Employed' whenever Company Name
                // (eidSponsorName) was present. Employment Status is now driven solely by the
                // EID Profession logic (3.2) above.

                // Best-effort split of previously saved "villa, street" combined value
                const split = this.splitVillaFromStreet(this.formData.street);
                this.formData = { ...this.formData, villaNumber: split.villa };
                this.streetWithoutVilla = split.street;
                if (split.street) {
                    this.addressFieldsUnlocked = true;
                }
                this.trackJourneyStep(1);
                 this.isLoading = false;
            } else {
                // optional: clear fields or handle empty response
                this.isLoading = false;
            }
             
        } catch (error) {
           //  this.handleToast('Error loading KYC record:'+JSON.stringify(error),'error'); //**** REMOVE DEBUG */

            
        }
        
    }
    @track currentStep = 1;
    
    @track formData = {
        firstName: '',
        lastName: '',
        residentStatus: null,
        dualNationality: null,
        pepStatus: null,
        nationality: '',
        villaNumber: '',
        street: '',
        city: '',
        state: '',
        country: '',
        emirate: '',
        postalCode: '',
        useAsPermanentAddress: false,
        employmentStatus: '',
        position: '',
        companyName: '',
        salaryrange: '',
        sourceOfIncome: '',
        otherSourceOfIncome: '',
        dualNationalityCountry: '',
        eidSponsorName: '',
        tradeLicenseNumber : '',
        tradeLicenseExpiryDate : '',
        bussinessAddr: '',
        countryAddr: '',
        natureBusiness: '',
        OrgcompanyName : '',
        LegalStructure : ''
    };

    // --- 2. Add properties to hold the dynamic picklist options ---
    @track nationalityOptions = [];
    @track clonenationalityOptions = [];
    @track occupationOptions = [];
    @track employmentStatusOptions = [];
    @track incomeSourceOptions = [];
    @track legalTypeOptions = [];
    @track error;


    logoUrl = modonLogo;
    kycexpired = kycexpiry;
    kyccompleted = kyccompleted;
    steps = [
        //{ label: 'Personal', value: '1' },
        { label: 'Additional Status', value: '1' },
        { label: 'Resident Address', value: '2' },
        { label: 'Employment', value: '3' },
        { label: 'Review', value: '4' },
    ];

    // --- 3. Wire the Apex method to a function to process the results ---
    @wire(getRequiredPicklists)
    wiredPicklistValues({ error, data }) {
        debugger;
        this.isLoading = true;
        if (data) {
            // Assign the options from the returned map
            this.nationalityOptions = data.nationalityOptions;
            this.employmentStatusOptions = data.employmentOptions;
            this.incomeSourceOptions = data.incomeSourceOptions;
            this.salaryrangeOptions = data.salaryRangeOptions;
            this.clonenationalityOptions = data.nationalityOptions;
            this.dualNationalityOptions = data.nationalityOptions;
            this.occupationOptions = data.occupationOptions;
            this.legalTypeOptions = data.legalTypeOptions;
            this.error = undefined;
            if(this.initialDataLoaded === true){
                this.isLoading = false;
            }
        } else if (error) {
            this.isLoading = false;
            this.error = error;
            //this.handleToast('Error loading picklists:'+JSON.stringify(error),'error'); //**** REMOVE DEBUG */

        }
    }


    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    //get isStep5() { return this.currentStep === 5; }

    get isTradeLicenseUploadEnabled() { return this.isCorporateCustomer && this.currentStep === 4 && this.IsTradeLicenseNotUploaded; }

    get isFirstStep() { return this.currentStep === 1; }
    get nextButtonLabel() { return this.currentStep === 4 ? 'Sign KYC Form' : 'Next'; }
    get previousButtonClass() {
        return `nav-button previous-button ${this.isFirstStep ? 'disabled' : ''}`;
    }
    get nextButtonClass() {
          if (this.currentStep === 3 && this.isCorporateCustomer === true && this.fileUploaded === false && this.IsTradeLicenseNotUploaded === true) {
            return `nav-button next-button disabled`;
          }
        return `nav-button next-button`;
     } // --- Conditional Visibility Getters ---
    get isResident() { return this.formData.residentStatus === 'Resident'; }
    get addressFieldsLocked() { return !this.addressFieldsUnlocked; }
    get isEmployed() { return this.formData.employmentStatus === 'Employed'; }
    get isSelfEmployed() { return this.formData.employmentStatus === 'Self Employed'; }
    get isOtherSource() { return this.formData.sourceOfIncome === 'Others (please specify)'; }
    get isBusinessOwner() { return this.formData.sourceOfIncome === 'Business owner'; }

    get computedSteps() {
        return this.steps.map(step => {
            const stepNum = parseInt(step.value, 10);
            return {
                ...step,
                stepClass: `progress-step ${stepNum < this.currentStep ? 'completed' : ''} ${stepNum === this.currentStep ? 'active' : ''}`,
                isCompleted: stepNum < this.currentStep
            };
        });
    }

    // --- Custom Radio Button Logic ---
    get residentStatusClassResident() { return `custom-radio-button ${this.formData.residentStatus === 'Resident' ? 'selected' : ''}`; }
    get residentStatusClassIntl() { return `custom-radio-button ${this.formData.residentStatus === 'International' ? 'selected' : ''}`; }
    get dualNationalityClassYes() { return `custom-radio-button ${this.formData.dualNationality === 'Yes' ? 'selected' : ''}`; }
    get dualNationalityClassNo() { return `custom-radio-button ${this.formData.dualNationality === 'No' ? 'selected' : ''}`; }
    get pepStatusClassYes() { return `custom-radio-button ${this.formData.pepStatus === 'Yes' ? 'selected' : ''}`; }
    get pepStatusClassNo() { return `custom-radio-button ${this.formData.pepStatus === 'No' ? 'selected' : ''}`; }

    handleCustomRadioClick(event) {
        const { name, value } = event.target.dataset;
        if (name === 'dualNationality' && value === 'Yes') {
            this.holdDualNationality = true;
        }else if (name === 'dualNationality' && value === 'No'){
            this.holdDualNationality = false;
        }
        this.formData = { ...this.formData, [name]: value };
    }
    // --- End Custom Radio Button Logic ---

    // --- 4. REMOVE the old hardcoded getters for picklists ---
    // get countryOptions() { ... } // Removed
    get emirateOptions() { return [ { label: 'Abu Dhabi', value: 'Abu Dhabi' }, { label: 'Dubai', value: 'Dubai' }, { label: 'Sharjah', value: 'Sharjah' },{ label: 'Ajman', value: 'Ajman' },{ label: 'Umm Al Quwain', value: 'Umm Al Quwain' },{ label: 'Ras Al Khaimah', value: 'Ras Al Khaimah' },{ label: 'Fujairah', value: 'Fujairah' }]; }
    // get employmentStatusOptions() { ... } // Removed
    // get incomeSourceOptions() { ... } // Removed

    // ---------- villa / street helpers ----------

    handleVillaNumberChange(event) {
        this.formData = { ...this.formData, villaNumber: event.target.value };
    }

    handleStreetChange(event) {
        this.streetWithoutVilla = event.target.value;
    }

    get streetDisplayValue() {
        return this.streetWithoutVilla || '';
    }

    buildMergedStreet() {
        const villa = (this.formData.villaNumber || '').trim();
        const baseStreet = (this.streetWithoutVilla || '').trim();
        return villa ? villa + (baseStreet ? ', ' + baseStreet : '') : baseStreet;
    }

    get reviewStreetValue() {
        return this.buildMergedStreet();
    }

    splitVillaFromStreet(savedStreet) {
        const raw = (savedStreet || '').trim();
        if (!raw) {
            return { villa: '', street: '' };
        }
        const commaIndex = raw.indexOf(',');
        if (commaIndex === -1) {
            return { villa: '', street: raw };
        }
        const firstPart = raw.substring(0, commaIndex).trim();
        const rest = raw.substring(commaIndex + 1).trim();
        const looksLikeVilla = firstPart.length > 0 && firstPart.length <= 20;
        if (looksLikeVilla && rest) {
            return { villa: firstPart, street: rest };
        }
        return { villa: '', street: raw };
    }

    // ---------- geo location search ----------

    handleAddressSearchChange(event) {
        const value = event.target.value;
        this.addressSearchText = value;

        if (!value || value.length < 3) {
            this.addressSearchResults = [];
            this.showAddressSearchResults = false;
            return;
        }

        // Debounce - multiple events (input/change/keyup) can fire for one keystroke
        // on some mobile browsers, so we only act on the latest one after a short pause.
        clearTimeout(this._addressSearchDebounce);
        this._addressSearchDebounce = setTimeout(() => {
            if (this.addressSearchText !== value) {
                return;
            }
            this.isAddressSearching = true;
            searchLocation({ searchText: value })
                .then(result => {
                    this.addressSearchResults = result || [];
                    this.showAddressSearchResults = this.addressSearchResults.length > 0;
                })
                .catch(error => {
                    console.error('Address search failed:', error);
                })
                .finally(() => {
                    this.isAddressSearching = false;
                });
        }, 300);
    }

    async handleAddressLocationSelect(event) {
        const lat = parseFloat(event.currentTarget.dataset.lat);
        const lon = parseFloat(event.currentTarget.dataset.lon);
        const label = event.currentTarget.dataset.label;

        this.addressSearchText = label;
        this.addressSearchResults = [];
        this.showAddressSearchResults = false;
        this.isAddressSearching = true;

        const searchInput = this.template.querySelector('.geo-search-wrap lightning-input');
        if (searchInput) {
            searchInput.value = label;
        }

        try {
            const geo = await getAddressFromLatLong({ latitude: lat, longitude: lon });
            const isUae = (geo.countryCode || '').toLowerCase() === 'ae';

            this.streetWithoutVilla = geo.street || geo.addressLine1 || '';
            this.formData = {
                ...this.formData,
                city: isUae ? this.stripEmirateSuffix(geo.city) : (geo.city || ''),
                state: isUae ? this.stripEmirateSuffix(geo.state) : (geo.state || ''),
                country: geo.country || '',
                postalCode: geo.postcode || ''
            };
            this.addressFieldsUnlocked = true;

            this.handleToast('Address filled from location. You can still edit it.', 'success');
        } catch (error) {
            console.error('Reverse geocode failed:', error);
            this.handleToast('Could not fetch address details for that location.', 'error');
        } finally {
            this.isAddressSearching = false;
        }
    }

    stripEmirateSuffix(value) {
        if (!value) return '';
        return value.replace(/\s+emirate$/i, '').trim();
    }

    handleChange(event) {
        const { name, value, type, checked } = event.target;
        if(name === 'employmentStatus') {
            this.sourceOfIncomeDisabled = true;
            this.loadOtherSourceOfIncome(value);
            this.formData = { ...this.formData, sourceOfIncome: '' };
            this.formData = { ...this.formData, companyName: '' };
            this.formData = { ...this.formData, salaryrange: '' };
            this.formData = { ...this.formData, position: '' };
            if(value === 'Employed') {
                this.formData.sourceOfIncome = 'Salary';
                this.companyName = this.eidSponsorName;
                this.formData = { ...this.formData, sourceOfIncome: 'Salary', companyName: this.eidSponsorName };
            }else{
                this.formData = { ...this.formData, sourceOfIncome: '' };
                this.formData = { ...this.formData, companyName: '' };
                this.formData = { ...this.formData, salaryrange: '' };
                this.formData = { ...this.formData, position: '' };
                this.formData = { ...this.formData, sourceOfIncome: '', companyName: '' };

            }
        }
        if(name === 'sourceOfIncome') {
                this.formData = { ...this.formData, companyName: '' };
                this.formData = { ...this.formData, salaryrange: '' };
                this.formData = { ...this.formData, position: '' };
                this.formData = { ...this.formData, companyName: '' };
        }
        if (type === 'checkbox') {
            this.formData = { ...this.formData, [name]: checked };
        } else {
            this.formData = { ...this.formData, [name]: value };
        }
    }
    loadOtherSourceOfIncome(value) {
        getSourceofIncome({employmentSts:value})
            .then(data => {
                this.incomeSourceOptions = data;
                //this.isLoading = false;
                this.sourceOfIncomeDisabled = false;
            })
            .catch(error => {
                console.error('Error loading source of income:', error);
              //  this.isLoading = false;
            
            });
    }
    handleCheckboxChange(event) {
        const { name, checked } = event.target;
        this.formData = { ...this.formData, [name]: checked };
    }

    handlePrevious() {
        if (this.currentStep > 1) this.currentStep--;
    }

    handleNext() {
          // IMPORTANT: The first thing to do is check if the button is disabled
        
       
        if (this.validateStep()) {
            if (this.currentStep < 4) {
                this.currentStep++;
                this.trackJourneyStep(this.currentStep); // 2.9 Arvind 28 July 2026 - fire and forget, non-blocking
                /*if (this.currentStep === 3 && this.formData.residentStatus === 'Resident') {
                   this.nationalityOptions = [ { label: 'United Arab Emirates', value: 'United Arab Emirates' }];
               }else if (this.currentStep === 3 && this.formData.residentStatus === 'International') {
                   this.nationalityOptions = this.clonenationalityOptions;
               }*/
            } else {
                this.submitForm();
            }
        }
        
    }

    // 2.9 Arvind 28 July 2026 - helper for step tracking, fire-and-forget, never blocks UI or throws to the user
    trackJourneyStep(stepNumber) {
        const stepLabelMap = {
            1: 'Reached Step 1 - Additional Status',
            2: 'Reached Step 2 - Resident Address',
            3: 'Reached Step 3 - Employment',
            4: 'Reached Step 4 - Review'
        };
        const label = stepLabelMap[stepNumber];
        if (!label || !this.recordId) return;

        updateJourneyStatus({ kycId: this.recordId, status: label })
            .catch(() => {});
    }

    validateStep() {
        let isValid = true;
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        for(let input of inputs) {
            if (input.required && !input.value) {
                input.reportValidity();
                isValid = false;
            }
        }

        // Custom validation for radio buttons
      if (this.isStep1 && !this.formData.dualNationality && this.showSelectDualNationality) {
            this.handleToast('Please answer: “Do you hold citizenship in more than one country?”','error');
            return false;
        }else if (this.isStep1 && !this.formData.pepStatus) {
            this.handleToast('Please answer: "Are you a Politically Exposed Person (PEP)?"','error');
            return false;
        }
         if (this.currentStep === 3 && this.isCorporateCustomer === true && this.fileUploaded === false) {
            this.handleToast('Please upload the Trade License document to proceed.','error');
            return false;
        }
        return isValid;
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: message, variant: 'error' }));
    }
    handleToast(message,variant) {
        this.template.querySelector('c-custom-toast').show(message, variant);

    }
    submitForm() {
      this.message = 'Almost ready! We’re setting up your KYC form for signing.';
      this.subMessage = 'We are preparing your signing session...';
      this.isLoading = true;

        // 2.9 Arvind 28 July 2026 - fire and forget, tracks that he clicked "Sign KYC Form"
        updateJourneyStatus({ kycId: this.recordId, status: 'Clicked Sign KYC Form' })
            .catch(() => {});

        // Villa number is combined into the street value only at save time,
        // never reactively - the Street field always reflects only what
        // geo-search or manual typing puts there.
        const payload = { ...this.formData, street: this.buildMergedStreet() };

        submitData({ customerInfo: JSON.stringify(payload), recordId: this.recordId })
    
    .then(url => {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'KYC Journey Started Successfully!',
                variant: 'success'
            })
        );
        /*this.isLoading = false;
        if (url) {
            window.open(url, '_self');
        }*/

        // 2.9 Arvind 28 July 2026 - fire and forget, tracks that submitData succeeded
        updateJourneyStatus({ kycId: this.recordId, status: 'KYC Data Submitted - Signing Session Starting' })
            .catch(() => {});

       this.startPolling();
    })
    .catch(error => {
        this.isLoading = false;
        this.handleToast('Failed to submit KYC data. Please contact support team!','error');
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to submit KYC data. Please try again later.',
                variant: 'error'
            })
        );

        // 2.9 Arvind 28 July 2026 - fire and forget, tracks that submitData failed
        updateJourneyStatus({ kycId: this.recordId, status: 'KYC Submission Failed' })
            .catch(() => {});
    });
    
    }

    
    handleTradeLicenseUploadSuccess(event) {
        const status = event.detail.status;
        const message = event.detail.message;
        
        if (status === 'success') {
          this.message = 'Almost done! We are uploading your file...';
          this.subMessage = 'Almost there, please wait a moment.';
          this.isLoading = true;

          getTradeLicenseInfo({ contactIdStr: this.recordId })
            .then(data => {
                if(data){
                    if(data !== null){
                        this.formData.tradeLicenseNumber = data.TradeLicenseNumber__c || '';
                        this.formData.tradeLicenseExpiryDate = data.TradeLicenseExpiryDate__c || '';
                        this.formData.bussinessAddr = data.Company_Address__c || '';
                        this.formData.countryAddr = data.Company_Country_Of_Origin__c || '';
                        this.formData.natureBusiness = data.Nature_Of_Business__c || '';
                        this.formData.OrgcompanyName = data.Company_Name_as_per_Trade_License__c || '';
                    }
                    this.fileUploaded = true; // Enable the "Next" button
                    this.handleToast('Trade License uploaded successfully. You can now proceed with the KYC journey.','success');
                }else{
                    this.fileUploaded = true; // Keep the "Next" button disabled
                }
                this.isLoading = false;

                // 2.9 Arvind 28 July 2026 - fire and forget, tracks Trade License upload success
                updateJourneyStatus({ kycId: this.recordId, status: 'Trade License Uploaded' })
                    .catch(() => {});
            })
            .catch(error => {
                console.error('Error fetching trade license info:', error);
                this.isLoading = false;
                this.fileUploaded = true; // Keep the "Next" button disabled
                this.handleToast('Upload failed.','error');
            });
         

        } else {
            this.handleToast('Upload failed.','error');
            this.fileUploaded = true; // Keep the "Next" button disabled
            console.error('Upload failed. Parent component received message:', message);
            // You can also show the error in the parent component's UI if needed
        }
      
        // Optionally, you can refresh the component or perform other actions here
    }
    handlePOAUploadSuccess(event) {
        const status = event.detail.status;
        const message = event.detail.message;
        
        if (status === 'success') {
            this.handleToast('Power of Attorney Uploaded successfully.','success');

            // 2.9 Arvind 28 July 2026 - fire and forget, tracks POA upload success
            updateJourneyStatus({ kycId: this.recordId, status: 'POA Uploaded' })
                .catch(() => {});
        } else {
            this.handleToast('Upload failed.','error');
            //console.error('Upload failed. Parent component received message:', message);
            // You can also show the error in the parent component's UI if needed
        }
      
        // Optionally, you can start polling here if needed
        // this.startPolling();
    }

    // Polling to check KYC sign URL
    pollingInterval = 3000; // 3 seconds
    maxDuration = 30000; // 15 seconds
    intervalId = null;
    startTime = null;
    docuSignUrl = null;

    disconnectedCallback() {
        this.stopPolling();
        this.isLoading = false;
    }

    startPolling() {
        this.startTime = Date.now();
        // check immediately, then every interval
        this.checkUrl();
        this.intervalId = setInterval(() => {
            this.checkUrl();
        }, this.pollingInterval);
    }

    stopPolling() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
            this.isLoading = false;
        }
    }
 
    async checkUrl() {
        const elapsed = Date.now() - this.startTime;
        if (elapsed > this.maxDuration) {
            // timeout reached
            this.isLoading = false;
            this.stopPolling();
            const url = window.location.origin + '/customerkyc/signpage';
            window.open(url, '_self');
            this.isLoading = false;
            return;
        }

        try {
            const url = await fetchDocuSignUrl({ kycId: this.recordId });
            if (url !== null && url !== '') {
                this.stopPolling();
                this.docuSignUrl = url;
               if (url) {
                    window.open(url, '_self');
                }
                this.isLoading = false;
            }
            // else keep polling until timeout
        } catch (err) {
            // stop on unexpected error and inform admin
            this.stopPolling();
            const msg = (err && err.body && err.body.message) ? err.body.message : (err.message || JSON.stringify(err));
            this.isLoading = false;
        }
    }
}