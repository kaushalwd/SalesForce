import { LightningElement, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllProjects from '@salesforce/apex/UnitSearchLwcController.getAllProjects';
import getAllBuildings from '@salesforce/apex/UnitSearchLwcController.getAllBuildings';
import getUnitDetails from '@salesforce/apex/UnitSearchLwcController.getUnitDetails';
import generateSalesOffer from '@salesforce/apex/UnitSearchLwcController.generateSalesOffer';
import sendSalesOfferPDF from '@salesforce/apex/UnitSearchLwcController.sendSalesOfferPDF';
// Arvind v17.0 (23 Sep 2026) - offer email with Facade Style (passes selectedDesign to the PDF)
import sendSalesOfferPDFWithFacade from '@salesforce/apex/UnitSearchLwcController.sendSalesOfferPDFWithFacade';
import saveSalesOrder from '@salesforce/apex/UnitSearchLwcController.saveSalesOrder';
// Arvind changes for EOI v2.0 - Commented out: replaced by getCompletedEOIs, availableEOI logic no longer needed
// import getEOIDetails from '@salesforce/apex/UnitSearchLwcController.getEOIDetails';
import checkExistingSalesOrder from '@salesforce/apex/UnitSearchLwcController.checkExistingSalesOrder';
// Arvind v13.0 (14/07/2026) - Booking eligibility check (missing fields / Opp-Account mismatch)
// Arvind v15.0 (02/09/2026) - Commented out: the v13.0 Unit Search screen block is retired.
// All Nationality / UAE Resident Status / Address enforcement now happens on the
// "Book Unit/s" button via the v14.0 KYC gate, so the search screen is never blocked.
// Uncomment this import together with the v15.0 blocks below to restore the old behaviour.
// import checkBookingEligibility from '@salesforce/apex/UnitSearchLwcController.checkBookingEligibility';
// Arvind v14.0 (28/08/2026) - KYC gate. Used ONLY by the BOOKING ("Book Unit/s") branch.
// Never called from the Generate Offer or Block Request flows.
import checkKYCEligibility from '@salesforce/apex/UnitSearchLwcController.checkKYCEligibility';
import updateUnitsAsBlocked from '@salesforce/apex/UnitSearchLwcController.updateUnitsAsBlocked';
import unblockSelectedUnits from '@salesforce/apex/UnitSearchLwcController.unblockSelectedUnits';
import checkUnitStatus from '@salesforce/apex/UnitSearchLwcController.checkUnitStatus';
import getBlockingHours from '@salesforce/apex/UnitSearchLwcController.getBlockingHours';
import saveBlockedUnits from '@salesforce/apex/UnitSearchLwcController.saveBlockedUnits';
import makeDPGApiCall from '@salesforce/apex/UnitSearchLwcController.makeDPGApiCall';
import orgUrl from '@salesforce/label/c.OrgURL';
// Arvind v10.0 (08/06/2026) - Feature flag labels (set in Setup > Custom Labels, no deployment needed)
import EOI_ENFORCE_TYPOLOGY from '@salesforce/label/c.EOI_Enforce_Typology_Check';

//import checkComplianceSubmitted from '@salesforce/apex/UnitSearchLwcController.checkComplianceSubmitted';

import saveSalesOrderWithBlockRequest from '@salesforce/apex/UnitSearchLwcController.saveSalesOrderWithBlockRequest';
import isDocumentValidEgypt from '@salesforce/apex/UnitSearchLwcController.isDocumentValidEgypt';
import getUserProfileName from '@salesforce/apex/UnitSearchLwcController.getUserProfileName';
import getUnitTypes from '@salesforce/apex/UnitSearchLwcController.getUnitTypes';
import getNumberofBedrooms from '@salesforce/apex/UnitSearchLwcController.getNumberofBedrooms';
import getQualityType from '@salesforce/apex/UnitSearchLwcController.getQualityType';
import getGFARange from '@salesforce/apex/UnitSearchLwcController.getGFARange';
import getFloorValues from '@salesforce/apex/UnitSearchLwcController.getFloorValues';

// Arvind changes for EOI v2.0 - START
// Import Apex method that returns only Completed EOIs for the opportunity.
// Only called for non-Modon Egypt. Modon Egypt path is never affected.
import getCompletedEOIs from '@salesforce/apex/UnitSearchLwcController.getCompletedEOIs';
// Arvind changes for EOI v2.0 - END


export default class UnitSearchLwc extends LightningElement {

    selectedProject = '';
    selectedBuilding = '';
    selectedUnitType = '';
    selectQuality = '';
    selectedNoOfBedrooms = '';
    selectedFloorArea = '';
    selectedFloor = '';
    unitCode = '';
    searchText = '';
    selectedAction = '';
    showOfferDetails = false;
    showBtnGroup = true;
    showButton = false;


    projectList = [];
    unitInventoryDetails = [];
    unitLst = [];
    isActiveTab = false;
    blockingHourOptions = [];

    showButton = false;
    unitDetails = {};

    pageNumber = 1;
    isLoading = false;

    confirmation = false;

    paymentTypeName = '';
    paymentPlanDiscountPercent = '';
    MaintenanceFee = '';
    unitBasePrice = '';
    @track NumberOfMaintenanceFee = '';
    paymentInstallments = [];
    selectedCurrencyIsoCode = '';
    @track currencyCode = '';

    selectedBlockingHours = '';

    unitOptionPrice = 0;

    fullUrl = '';

    showBlockRequestModal = false;
    showBlockRequestEgyptModal = false;

    // before deployment -  change it into false
    showRequestBlockWithFeesButton = false;

    salesOrderExist = false;

    // Arvind v13.0 (14/07/2026) - Booking eligibility block state
    // Arvind v15.0 (02/09/2026) - bookingBlocked is now never set to true (the only writer,
    // checkBookingEligibility, is commented out). Properties and getters are deliberately
    // left in place so showMainUnitSearchUi stays true and the screen always renders.
    @track bookingBlocked = false;
    @track bookingBlockedMessage = '';

    // Arvind v13.0 (14/07/2026) - Explicit mutually-exclusive getters for the three
    // top-level template states. Using if:true getters here (rather than lwc:if/elseif/else)
    // matches the dominant pattern already used throughout this file, and avoids a reactivity
    // gap where lwc:elseif branches did not reliably re-render after an async Apex response
    // resolved (message stayed blank until a manual page refresh).
    get showBookingBlockedCard() {
        return !this.salesOrderExist && this.bookingBlocked;
    }

    get showMainUnitSearchUi() {
        return !this.salesOrderExist && !this.bookingBlocked;
    }

    // Arvind changes for EOI v2.0 - Commented out: availableEOI no longer used
    // availableEOI = 0;

    customerName = '';

    lastPageName = '';

    @track
    selectedUnits = {};

    @api recordId;
    @track offerDetailsLst = [];
    unitRollbackConfirmation = false;
    currentUserProfile;
    showRequestBlock = false;
    disableRequestBlock = false;
    blockMessage = '';
    nationality = '';
    @track isModonEgyptProfile = false;
    unitTypeList = [];
    bedroomsList = [];
    qualityTypeList = [];
    areaList = [];
    floorList = [];
    selectedDesign = '';
    @track unitURL = {};
    alNaseemDesignOptions = [{ label: "South California", value: "South California" },
    { label: "Contemporary", value: "Contemporary" }];

    // Arvind changes for EOI v2.0 - START
    // Tracks the list of Completed EOIs retrieved from Apex on component load.
    // Stays empty for Modon Egypt (isModonEgyptProfile=true); Apex is never called in that case.
    @track completedEOIs = [];
    // When true (Bypass_EOI_Typology_Check__c = true on Opportunity), typology + bedroom
    // matching is skipped -- all Completed+Cleared EOIs are available for any unit.
    // Used for VIP/exception cases and can drive approval process criteria.
    bypassEOITypologyCheck = false;
    // Arvind EOI v2.1 - true when Opp.Allow_EOI_Any_Status__c = true (VIP/Management).
    // VIP: EOI any status, no receipt -> allow; cleared receipt -> allow; non-cleared receipt -> block.
    allowEOIAnyStatus = false;
    // Stores the business error from Apex when Completed EOIs exist but no Cleared Receipt.
    // Null = no issue. Non-null = booking must be blocked when user clicks Book Unit/s.
    // Error is stored silently on load -- NOT shown until booking is attempted.
    eoiValidationError = null;
    // Arvind v8.0 - true if ANY EOIs exist on the opp (any status).
    // false = no EOIs at all -> allow booking when EOI_Strict_Required__c = false.
    hasAnyEOI = false;
    // Arvind EOI v2.1 - true if ANY selected unit's Phase has EOI_Required__c = true.
    // Controls whether EOI dropdown shows + EOI validation runs at booking time.
    // Arvind EOI v2.1 - Computed dynamically from selectedUnits in isEOIRequiredPhase getter.
    // Arvind changes for EOI v2.0 - END

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // Auto-refresh interval reference for the unit list on page 1 (unit
    // selection screen). Stored so it can be cleared in disconnectedCallback
    // and avoid memory leaks / stray polling after the component is removed.
    // ------------------------------------------------------------------
    _autoRefreshInterval = null;

    get showOriginalPrice() {
        console.log('==>', this.selectedUnits[this.currentUnit].unitOptionPrice);
        console.log('==>', this.selectedUnits[this.currentUnit].price);
        return (this.selectedUnits[this.currentUnit].unitOptionPrice == 0 || this.selectedUnits[this.currentUnit].unitOptionPrice === undefined)
    }

    get alNaseemSelected() {
        console.log('this.selectedProject ==>', this.selectedProject);
        console.log('this.projectList ==>', this.projectList);

        if (!Array.isArray(this.projectList)) {
            return false;
        }

        for (let i = 0; i < this.projectList.length; i++) {
            if (
                this.projectList[i].value === this.selectedProject &&
                this.projectList[i].label === 'Al Naseem'
            ) {
                return true;
            }
        }
        return false;
    }

    // Arvind changes for EOI v2.0 - START
    // True when at least one Completed EOI exists for the opportunity.
    get hasCompletedEOIs() {
        return this.completedEOIs && this.completedEOIs.length > 0;
    }

    // Arvind EOI v2.1 - True if ANY selected unit's Phase has EOI_Required__c = true.
    // Only those units/phases enforce EOI requirement -- all other projects unaffected.
    // Arvind EOI v2.1
    get isEOIRequiredPhase() {
        for (let key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus && this.selectedUnits[key].eoiRequired) {
                return true;
            }
        }
        return false;
    }

    // True when: BOOKING + completed EOIs loaded + non-Egypt + phase requires EOI.
    // Used by HTML to show/hide EOI combobox on page 2 and by JS for EOI validation.
    // Arvind EOI v2.1: added isEOIRequiredPhase gate so non-EOI-required phases are never affected.
    get isBookingSelectedWithEOI() {
        return this.selectedAction === 'BOOKING'
            && this.hasCompletedEOIs
            && !this.isModonEgyptProfile
            && this.isEOIRequiredPhase;
    }
    // Arvind changes for EOI v2.0 - END

    connectedCallback() {
        console.log('opportunityId==>', this.recordId);
        console.log('this.blockingHoursOptions==>', this.blockingHoursOptions);
        this.checkExistingSalesOrder();
        this.populateBedroomsNumberFilter();
        this.populateUnitTypeFilter();
        this.populateFloorAreaFilter();
        this.populateFloorValueFilter();
        this.populateQualityTypeFilter();
        this.fetchUserProfile();
        // Arvind changes for EOI v2.0 - Fetch completed EOIs on load (non-Modon Egypt; empty result = no EOI dropdown shown)
        this.fetchCompletedEOIs();
        // Arvind changes for EOI v2.0 - END

        // ------------------------------------------------------------------
        // 2.3 - Arvind - 30 Jun 2026
        // Start auto-refresh polling so the unit list on page 1 stays current.
        // Reserved/Sold units (made unavailable by another agent) will drop
        // out of the list automatically on the next 10-second poll because
        // getUnitDetails already excludes units that are not
        // Available+Un-Assigned (or blocked-for-current-user).
        // ------------------------------------------------------------------
        this.startAutoRefresh();
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // Lifecycle hook to clear the polling interval when this component is
    // removed from the DOM, preventing the timer from firing against a
    // destroyed component (memory leak / console errors).
    // ------------------------------------------------------------------
    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // Starts a 10-second polling interval that silently re-fetches the unit
    // list (populateUnitData) while the user is on page 1 (unit selection).
    // Guarded so it never fires while:
    //   - the user has moved past page 1 (payment/booking pages), or
    //   - a request is already in flight (isLoading = true)
    // This keeps Reserved/Sold units from lingering on screen and prevents
    // an agent from selecting a unit that another agent just booked.
    // ------------------------------------------------------------------
    startAutoRefresh() {
        this._autoRefreshInterval = setInterval(() => {
            if (this.pageNumber === 1 && !this.isLoading) {
                // 2.3 - Arvind - 30 Jun 2026 - pass true so this background poll
                // does not show the spinner or blank the table (see populateUnitData).
                this.populateUnitData(true);
            }
        }, 10000); // 10000 ms = 10 seconds
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // Safely clears the auto-refresh interval.
    // ------------------------------------------------------------------
    stopAutoRefresh() {
        if (this._autoRefreshInterval) {
            clearInterval(this._autoRefreshInterval);
            this._autoRefreshInterval = null;
        }
    }

    handleRefresh() {
        this.unitCode = '';
        this.selectedUnitType = '';
        this.selectQuality = '';
        this.selectedNoOfBedrooms = '';
        this.selectedFloorArea = '';
        this.selectedFloor = '';
        this.populateUnitData();
    }
    renderedCallback() {
        this.handleGetOffersData(this.currentUnit);
    }

    fetchUserProfile() {
        getUserProfileName()
            .then((result) => {
                this.currentUserProfile = result;
                this.isModonEgyptProfile = result.includes('Modon Egypt');

                this.showRequestBlock = this.isModonEgyptProfile;

                if (this.isModonEgyptProfile || result.startsWith('System Administrator')) {
                    this.showRequestBlockWithFeesButton = true;
                }
                console.log('isModonEgyptProfile:', this.isModonEgyptProfile);
                console.log('showRequestBlock:', this.showRequestBlock);
            })
            .catch((error) => {
                console.error('Error fetching user profile:', error);
            });
    }

    // Arvind changes for EOI v2.0 - START
    // Calls Apex to get Completed EOIs for this opportunity.
    // If result is empty (no completed EOIs), the EOI combobox is never rendered -- existing flow unchanged.
    // Modon Egypt: isModonEgyptProfile is set by fetchUserProfile. Even if called, the EOI combobox
    // is hidden because isBookingSelectedWithEOI checks !isModonEgyptProfile.
    fetchCompletedEOIs() {
        // Arvind changes for EOI v2.0 - Apex returns a list where index 0 is a meta entry
        // { type:'meta', bypass:'true'/'false' } carrying the Opportunity bypass flag.
        // We extract it, set bypassEOITypologyCheck, then store the remaining EOIs.
        // Each EOI map includes: label, value, unitTypology, bedrooms.
        getCompletedEOIs({ oppId: this.recordId })
            .then(data => {
                const rawData = data || [];
                if (rawData.length > 0 && rawData[0].type === 'meta') {
                    // Arvind EOI v2.1 - Extract bypass + allowAnyStatus flags from meta entry, then discard it
                    // Arvind v10.0 - bypassEOITypologyCheck = true when EITHER:
                    //   a) Opp.Bypass_EOI_Typology_Check__c = true (per-opp override)
                    //   b) EOI_Enforce_Typology_Check label = 'false' (org-wide, default)
                    //   Set label to 'true' to restore original typology+bedroom check.
                    const oppBypass   = rawData[0].bypass === 'true';
                    const labelBypass = EOI_ENFORCE_TYPOLOGY !== 'true'; // label 'false' = bypass typology
                    this.bypassEOITypologyCheck = oppBypass || labelBypass;
                    this.allowEOIAnyStatus       = rawData[0].allowAnyStatus === 'true'; // Arvind EOI v2.1
                    this.hasAnyEOI               = rawData[0].hasAnyEOI === 'true';      // Arvind v8.0
                    this.completedEOIs = rawData.slice(1);
                } else {
                    this.bypassEOITypologyCheck = false;
                    this.allowEOIAnyStatus       = false;
                    this.completedEOIs = rawData;
                }
                console.log('Arvind EOI v2.1 - completedEOIs count:', this.completedEOIs.length,
                            '| bypass:', this.bypassEOITypologyCheck,
                            '| allowAnyStatus:', this.allowEOIAnyStatus);
            })
            .catch(error => {
                console.error('Arvind changes for EOI v2.0 - Error fetching completed EOIs:', error);
                this.completedEOIs = [];
                this.bypassEOITypologyCheck = false;
                // Store error silently -- do NOT show toast here.
                // The error is surfaced only when the user clicks "Book Unit/s"
                // so they are not confused by a message before selecting any unit.
                this.eoiValidationError = (error && error.body && error.body.message)
                    ? error.body.message
                    : 'Booking cannot proceed. The EOI must be Completed and at least one Receipt must have a Cleared status.';
                console.warn('Arvind changes for EOI v2.0 - EOI validation error stored:', this.eoiValidationError);
            });
    }

    // Handles EOI dropdown change per unit tab on page 2.
    // Stores the selected EOI Id on the unit in selectedUnits map.
    // Spread forces LWC reactivity so the badge and border update immediately.
    handleEOISelection(event) {
        const unitId = event.target.dataset.recordId;
        const eoiId = event.detail.value;
        if (this.selectedUnits[unitId]) {
            this.selectedUnits[unitId].selectedEOIId = eoiId;
            this.selectedUnits = { ...this.selectedUnits };
            // Arvind v18.0 (23 Sep 2026) - EOI decides normal vs pre-approval payment plans
            // Arvind v19.0 (24 Sep 2026) - EOI with number -> pre-approval plan selected by default
            this.applyPaymentPlanFilter(unitId, true);
        }
        console.log('Arvind changes for EOI v2.0 - EOI selected for unit', unitId, ':', eoiId);
    }
    // Arvind changes for EOI v2.0 - END

    // ==================================================================
    // Arvind v17.0 (23 Sep 2026) - FACADE STYLE (Phase.Facade_Style__c)
    // ------------------------------------------------------------------
    // Options come from Apex generateSalesOffer (Facade_Style_c__mdt,
    // Active__c = true, exact Phase + Project name match).
    //   - Phase flag false -> nothing changes (unit FacadeStyle__c used as before).
    //   - Phase flag true  -> style is mandatory on Offer + Booking.
    //       1 option  -> auto-selected
    //       2+ options -> agent must pick one
    //       0 options -> booking blocked
    // ==================================================================
    // Stores Apex facade data on the unit. One option -> auto-selected.
    applyFacadeStyleData(unitId, data) {
        const unit = this.selectedUnits[unitId];
        if (!unit) {
            return;
        }
        const required = data && data.facadeStyleRequired === true;
        const options  = required ? (data.facadeStyleOptions || []) : [];
        unit.facadeStyleRequired = required;
        unit.facadeStyleOptions  = options;
        if (!required) {
            unit.selectedFacadeStyle = '';
        } else if (options.length === 1) {
            unit.selectedFacadeStyle = options[0].value;
        } else if (!options.some(o => o.value === unit.selectedFacadeStyle)) {
            unit.selectedFacadeStyle = '';
        }
        this.selectedUnits = { ...this.selectedUnits };
        console.log('Arvind v17.0 - Facade Style for unit', unitId,
                    '| required:', required, '| options:', options.length,
                    '| selected:', unit.selectedFacadeStyle);
    }

    handleFacadeStyleSelection(event) {
        const unitId = event.target.dataset.recordId;
        if (this.selectedUnits[unitId]) {
            this.selectedUnits[unitId].selectedFacadeStyle = event.detail.value;
            this.selectedUnits = { ...this.selectedUnits };
        }
        console.log('Arvind v17.0 - Facade Style selected for unit', unitId, ':', event.detail.value);
    }

    // Returns an error message, or null when every selected unit is OK.
    validateFacadeStyles() {
        for (let key in this.selectedUnits) {
            const u = this.selectedUnits[key];
            if (!u.selectionStatus || !u.facadeStyleRequired) {
                continue;
            }
            if (!u.facadeStyleOptions || u.facadeStyleOptions.length === 0) {
                return 'No Facade Style is configured for phase ' + u.buildingName
                     + ' / project ' + u.projectName + ' (unit ' + u.unitName
                     + '). Please contact your administrator.';
            }
            if (!u.selectedFacadeStyle) {
                return 'Facade Style is not selected for ' + u.unitName + ' unit.';
            }
        }
        return null;
    }

    // null = phase flag off (use existing behaviour); string = selected phase-driven style.
    getFacadeStyleForUnit(unitId) {
        const u = this.selectedUnits[unitId];
        return (u && u.facadeStyleRequired) ? (u.selectedFacadeStyle || '') : null;
    }
    // Arvind v17.0 - END

    // ==================================================================
    // Arvind v18.0 (23 Sep 2026) - PRE-APPROVAL PAYMENT PLANS
    // ------------------------------------------------------------------
    // Book Unit/s only (non-Modon Egypt). Generate Offer / Egypt unchanged.
    //   EOI with Pre_Approval_Number__c -> only PaymentPlan.Pre_Approval__c = true
    //   No EOI / EOI without number      -> Pre_Approval__c plans hidden
    //   One plan left -> auto-selected. None left -> error, booking blocked.
    // unit.fullPaymentDetails keeps the unfiltered Apex list so the filter
    // can be re-applied when the EOI or the action changes.
    // ------------------------------------------------------------------
    // Arvind v19.0 (24 Sep 2026) - RULE CHANGED (v18.0 filtering removed):
    //   - ALL payment plans are always shown.
    //   - EOI with Pre-Approval Number -> pre-approval plan selected by DEFAULT,
    //     EOI number shown read-only and always saved on the Sales Order.
    //   - Pre-approval plan without EOI number -> "Pre-Approval Number" text box
    //     shown and required; switching to a normal plan hides / clears it.
    // ==================================================================
    getPreApprovalNumberForUnit(unitId) {
        if (!this.isBookingSelectedWithEOI) {
            return '';
        }
        const eoiId = this.selectedUnits[unitId] ? this.selectedUnits[unitId].selectedEOIId : '';
        if (!eoiId) {
            return '';
        }
        const eoi = (this.completedEOIs || []).find(e => e.value === eoiId);
        return (eoi && eoi.preApprovalNumber) ? eoi.preApprovalNumber : '';
    }

    // Arvind v19.0 (24 Sep 2026) - no filtering any more; forceDefault = true
    // pre-selects a pre-approval plan when the EOI has a Pre-Approval Number.
    applyPaymentPlanFilter(unitId, forceDefault = false) {
        const unit = this.selectedUnits[unitId];
        if (!unit || !unit.fullPaymentDetails) {
            return;
        }
        const full    = unit.fullPaymentDetails;
        const fullLst = full.paymentLst || [];
        const bookingMode = this.selectedAction === 'BOOKING' && !this.isModonEgyptProfile;
        const preApprovalNumber = bookingMode ? this.getPreApprovalNumberForUnit(unitId) : '';

        const ids = new Set(fullLst.map(p => p.paymentObj.Id));
        const current = unit.paymentDetails ? unit.paymentDetails.selectedPayment : full.selectedPayment;
        let selected = ids.has(current) ? current : (fullLst.length > 0 ? fullLst[0].paymentObj.Id : '');

        if (forceDefault && preApprovalNumber) {
            const currentPlan = fullLst.find(p => p.paymentObj.Id === selected);
            if (!currentPlan || currentPlan.paymentObj.Pre_Approval__c !== true) {
                const firstPreApproval = fullLst.find(p => p.paymentObj.Pre_Approval__c === true);
                if (firstPreApproval) {
                    selected = firstPreApproval.paymentObj.Id;
                }
            }
        }

        unit.paymentDetails = {
            ...full,
            paymentLst: fullLst,
            availablePaymentPlans: full.availablePaymentPlans || [],
            selectedPayment: selected
        };
        unit.preApprovalNumber = preApprovalNumber;
        unit.paymentPlanError = '';
        this.updatePreApprovalState(unitId);
        if (unitId === this.currentUnit) {
            this.refreshPaymentDisplay(unitId);
        }
        this.selectedUnits = { ...this.selectedUnits };
        console.log('Arvind v19.0 - unit', unitId, '| EOI Pre-Approval:', preApprovalNumber,
                    '| selected plan:', selected, '| manual box:', unit.showManualPreApproval);
    }

    // Arvind v19.0 (24 Sep 2026) - flags for the Pre-Approval Number fields.
    updatePreApprovalState(unitId) {
        const unit = this.selectedUnits[unitId];
        if (!unit) {
            return;
        }
        const bookingMode = this.selectedAction === 'BOOKING' && !this.isModonEgyptProfile;
        const pdt  = unit.paymentDetails;
        const plan = pdt ? (pdt.paymentLst || []).find(p => p.paymentObj.Id === pdt.selectedPayment) : null;
        unit.selectedPlanIsPreApproval = bookingMode && !!plan && plan.paymentObj.Pre_Approval__c === true;
        unit.showEoiPreApproval    = unit.selectedPlanIsPreApproval && !!unit.preApprovalNumber;
        unit.showManualPreApproval = unit.selectedPlanIsPreApproval && !unit.preApprovalNumber;
        if (!unit.showManualPreApproval) {
            unit.manualPreApprovalNumber = '';     // box hidden -> value cleared, not required
        }
    }

    handleManualPreApprovalChange(event) {
        const unitId = event.target.dataset.recordId;
        if (this.selectedUnits[unitId]) {
            this.selectedUnits[unitId].manualPreApprovalNumber = event.detail.value;
            this.selectedUnits = { ...this.selectedUnits };
        }
    }

    // Number saved on the Sales Order: EOI number wins, else the typed number
    // (only while a pre-approval plan is selected), else blank.
    getPreApprovalNumberForSO(unitId) {
        const unit = this.selectedUnits[unitId];
        if (!unit || this.selectedAction !== 'BOOKING' || this.isModonEgyptProfile) {
            return '';
        }
        if (unit.preApprovalNumber) {
            return unit.preApprovalNumber;
        }
        if (unit.selectedPlanIsPreApproval && unit.manualPreApprovalNumber) {
            return unit.manualPreApprovalNumber.trim();
        }
        return '';
    }

    applyPaymentPlanFilterAll(forceDefault = false) {
        for (let key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus) {
                this.applyPaymentPlanFilter(key, forceDefault);
            }
        }
    }

    // Re-draws the installment table for the active tab after the plan list changed.
    refreshPaymentDisplay(unitId) {
        const unit = this.selectedUnits[unitId];
        const pdt  = unit ? unit.paymentDetails : null;
        const plan = pdt ? (pdt.paymentLst || []).find(p => p.paymentObj.Id === pdt.selectedPayment) : null;
        if (!plan) {
            this.paymentInstallments = [];
            this.paymentTypeName = '';
            return;
        }
        const obj = plan.paymentObj;
        this.paymentInstallments        = obj.Payment_Installments__r || [];
        this.paymentPlanDiscountPercent = obj.Discount_Percent__c || 0;
        this.MaintenanceFee             = obj.Maintenance_Fee__c || 0;
        this.NumberOfMaintenanceFee     = obj.Number_of_Maintenance_Fee__c || 0;
        this.selectedCurrencyIsoCode    = obj.CurrencyIsoCode || null;
        unit.selectedPPCurrency         = obj.CurrencyIsoCode || null;
        this.paymentTypeName            = obj.Name;
        const mappings = (unit.unitPaymentPlanOptions || []).filter(
            m => m.CurrencyIsoCode === obj.CurrencyIsoCode && m.Payment_Plan__c === obj.Id
        );
        const basePrice = mappings.length > 0 ? (mappings[0].Base_Price__c || 0) : 0;
        unit.basePriceFromMapping = basePrice;
        this.unitBasePrice = basePrice;
        this.calculatePaymentAmount();
    }
    // Arvind v18.0 - END

    handleGetOffersData(currentTab) {
        if (this.isActiveTab) {


            // Select the child component from the active tab
            const offerDetailsComp = this.template.querySelector(
                'c-offers-line-details-l-w-c[data-unitid="' + currentTab + '"]'
            );

            console.log('currentTab:' + currentTab);
            console.log('offerDetailsComp:' + JSON.stringify(offerDetailsComp));



            if (offerDetailsComp) {
                const data = offerDetailsComp.invokeOfferDetails(this.selectedProject, this.recordId, this.currentUnit, this.selectedUnitIds); // Call method from child

                console.log('Data from current tab:', data);
            } else {
                console.error('Offer Details component not found for active tab');
            }
            this.isActiveTab = false;
        }
    }

    checkExistingSalesOrder() {
        console.log('checking existence');
        this.isLoading = true;
        checkExistingSalesOrder({ oppId: this.recordId })
            .then(data => {
                console.log('data==>', data);
                this.salesOrderExist = data;
                if (!data) {
                    // Arvind v13.0 (14/07/2026) - Only proceed to Unit Selection if the
                    // opportunity/account also pass the booking eligibility check.
                    // Arvind v15.0 (02/09/2026) - Commented out: eligibility no longer gates the
                    // screen. Go straight to populateProjects() so Unit Search always renders.
                    // this.checkBookingEligibility();
                    this.isLoading = false;
                    this.populateProjects();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            });

    }

    // Arvind v13.0 (14/07/2026) - Booking eligibility check (missing fields / Opp-Account
    // mismatch). Runs only after checkExistingSalesOrder confirms no existing Sales Order.
    // Mirrors the same blocking pattern as salesOrderExist above - when true, the entire
    // Unit Search UI is replaced by a single blocking message (see HTML).
    // Arvind v15.0 (02/09/2026) - Method commented out in full. Kept for reference so the
    // v13.0 gate can be switched back on by uncommenting this block, the import above and
    // the caller in checkExistingSalesOrder. The Apex method checkBookingEligibility on
    // UnitSearchLwcController is left in place and untouched; it is simply no longer called.
    // checkBookingEligibility() {
    //     checkBookingEligibility({ oppId: this.recordId })
    //         .then(result => {
    //             this.bookingBlocked = result.blocked;
    //             this.bookingBlockedMessage = result.message;
    //             this.isLoading = false;
    //             if (!result.blocked) {
    //                 this.populateProjects();
    //                 // Arvind changes for EOI v2.0 - Commented out: availableEOI no longer needed
    //                 // this.getOpportunityEOIs();
    //             }
    //         })
    //         .catch(error => {
    //             console.log(error);
    //             this.isLoading = false;
    //         });
    // }
    // Arvind v13.0 - END

    // ==================================================================
    // Arvind v14.0 (28/08/2026) - KYC GATE - "Book Unit/s" FLOW ONLY
    // ------------------------------------------------------------------
    // Called from exactly ONE place: the BOOKING branch of handleMenuAction.
    // It is NOT called from OFFER (Generate Offer), BLOCKREQUEST,
    // BLOCKREQUESTEGYPT, BLOCKREQUESTWITHFEES, FORWARD or BACK, so those
    // flows are completely unaffected by this gate.
    //
    // Returns a Promise<boolean>:
    //   true  -> KYC passed (or profile out of scope), booking may proceed
    //   false -> blocked; a WARNING toast has already been shown and the
    //            caller must return immediately.
    // ==================================================================
    validateKYCForBooking() {
        // Modon Egypt is out of scope for this gate, consistent with the
        // existing EOI gates which are all guarded by !isModonEgyptProfile.
        if (this.isModonEgyptProfile) {
            return Promise.resolve(true);
        }

        this.isLoading = true;
        return checkKYCEligibility({ oppId: this.recordId })
            .then(result => {
                this.isLoading = false;
                if (result && result.blocked) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'KYC Required',
                        message: result.message,
                        variant: 'warning',
                        mode: 'dismissable'
                    }));
                    return false;
                }
                return true;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Arvind v14.0 - KYC check failed:', error);
                // Fail closed: a compliance gate that errors must not silently
                // let the booking through. Change to `return true;` if the
                // business prefers the opposite on a technical failure.
                this.dispatchEvent(new ShowToastEvent({
                    title: 'KYC Check Failed',
                    message: 'Unable to verify KYC status. Please try again or contact your administrator.',
                    variant: 'warning',
                    mode: 'dismissable'
                }));
                return false;
            });
    }
    // Arvind v14.0 - END

    // Arvind changes for EOI v2.0 - Commented out: getOpportunityEOIs and availableEOI are no longer needed.
    // EOI count logic is now handled by getCompletedEOIs / hasCompletedEOIs / isBookingSelectedWithEOI.
    // getOpportunityEOIs() {
    //     this.isLoading = true;
    //     getEOIDetails({ oppId: this.recordId })
    //         .then(data => {
    //             console.log('data==>', data);
    //             this.availableEOI = data;
    //             this.isLoading = false;
    //         })
    //         .catch(error => {
    //             console.log(error);
    //             this.isLoading = false;
    //         });
    // }

    get isOfferSelected() {
        if (this.selectedAction == 'OFFER') return true;

        return false;
    }

    get isBookingSelected() {
        if (this.selectedAction == 'BOOKING') {
            return true;
        } else if (this.selectedAction == 'BLOCKREQUESTWITHFEES') {
            return true;
        }

        return false;
    }

    get isBookingSection() {

    }

    get disableProceed() {
        return (this.pageNumber == 3);
    }

    get disablePath() {
        return (this.pageNumber == 1 || this.steps == []);
    }

    get showPage1() {
        return this.pageNumber == 1;
    }
    get showPage2() {
        return this.pageNumber == 2
    }
    get showPage3() {
        return this.pageNumber == 3
    }

    get totalSelectedUnits() {
        var selectedCountToReturn = 0;
        if (this.selectedUnits) {
            for (var key in this.selectedUnits) {
                if (this.selectedUnits[key].selectionStatus) {
                    selectedCountToReturn++;
                }
            }
        }
        return selectedCountToReturn;
    }

    validDocumentUploaded() {
        isDocumentValidEgypt({ opportunityId: this.recordId })
            .then(data => {
                console.log('Is Valid:', data.isValid);
                console.log('Nationality:', data.nationality);
                console.log('RequiredDoc:', data.requiredDoc);

                // Check for nationality missing message
                const nationalityError = data.requiredDoc?.find(msg =>
                    msg.includes('Nationality is required for Account.')
                );

                if (nationalityError) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Nationality',
                        message: nationalityError,
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                    return;
                }

                if (!data.isValid) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Documents',
                        message: data.requiredDoc.join(', ') + ' are required to be uploaded before blocking the unit.',
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                } else {
                    this.nationality = data.nationality;
                    console.log('Nationality:', this.nationality);
                    this.saveBlockUnitsEgypt();
                }
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'An error occurred while checking documents.',
                    variant: 'error',
                    mode: 'dismissable'
                }));
                console.error(error);
            });
    }


    isResidentCustomer = false;
    get isWadeemProject() {
        return this.getProjectName == 'Wadeem';
    }

    get getProjectName() {
        return this.projectList?.find(pro => pro.value === this.selectedProject)?.label;
    }

    get disableOffer1() {
        console.log('this.totalSelectedUnits==>', this.totalSelectedUnits);
        return (this.totalSelectedUnits < 1);
    }

    get disableOffer() {
        console.log('this.totalSelectedUnits==>', this.totalSelectedUnits);
        return (this.totalSelectedUnits < 1);
    }

    get selectedUnitList() {
        let unitsToReturn = [];
        for (var key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus) {
                console.log('this.selectedUnits[key]==>', key, '==>', this.selectedUnits[key]);
                // Arvind changes for EOI v2.0 - START
                // Spread unit data so LWC treats it as a new object (reactivity).
                // Inject availableEOIs filtered by this unit's typology + bedrooms (unless bypass = true).
                let unitData = { ...this.selectedUnits[key] };
                if (this.isBookingSelectedWithEOI) {
                    let matchingEOIs;
                    if (this.bypassEOITypologyCheck) {
                        // Bypass on: all Completed+Cleared EOIs available regardless of typology
                        matchingEOIs = this.completedEOIs;
                    } else {
                        // Normal: filter EOIs to only those matching this unit's Typology__c + Number_of_Bedrooms__c
                        const unitTypology = unitData.typology || '';
                        const unitBedrooms = unitData.bedrooms || '';
                        matchingEOIs = this.completedEOIs.filter(eoi =>
                            eoi.unitTypology === unitTypology && eoi.bedrooms === unitBedrooms
                        );
                    }
                    unitData.availableEOIs = [{ label: '--Select EOI--', value: '' }, ...matchingEOIs];
                }
                // Arvind changes for EOI v2.0 - END
                // Arvind v17.0 (23 Sep 2026) - Facade Style display helpers
                unitData.facadeStyleHasOptions = unitData.facadeStyleRequired === true
                                                 && (unitData.facadeStyleOptions || []).length > 0;
                unitData.facadeStyleNoOptions  = unitData.facadeStyleRequired === true
                                                 && !unitData.facadeStyleHasOptions;
                // Arvind v19.0 (24 Sep 2026) - number that will be saved on the Sales Order
                unitData.soPreApprovalNumber = this.getPreApprovalNumberForSO(key);
                unitsToReturn.push(unitData);
            }
        }
        console.log('unitsToReturn==>', unitsToReturn);
        return unitsToReturn;
    }

    get selectedUnitIds() {
        let selectedIds = [];
        for (var key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus) {
                selectedIds.push(key);
            }
        }
        console.log('selectedIds==>', selectedIds);
        return selectedIds;
    }

    populateProjects() {
        console.log('getAllProjects');
        this.isLoading = true;
        getAllProjects({ oppId: this.recordId })
            .then(data => {
                const rawData = data || [];
                // Arvind v11.0 (24/06/2026) - Extract meta entry (index 0) to get Opp.ProjectInterest__c
                let projectList = rawData;
                let oppProjectInterest = '';
                if (rawData.length > 0 && rawData[0].type === 'meta') {
                    oppProjectInterest = rawData[0].projectInterest || '';
                    projectList = rawData.slice(1);
                }
                this.projectList = projectList;
                
                // Default: first project in list (existing behaviour)
                let defaultProject = projectList.length > 0 ? projectList[0].value : '';
                
                // Arvind v11.0 (24/06/2026) - Auto-select project matching Opp.ProjectInterest__c
                if (oppProjectInterest) {
                    const matched = projectList.find(
                        p => p.label === oppProjectInterest
                    );
                    if (matched) {
                        defaultProject = matched.value;
                        console.log('Arvind v11.0 - Auto-selected project from Opp.ProjectInterest__c:', oppProjectInterest);
                    } else {
                        console.log('Arvind v11.0 - ProjectInterest__c not found in list, using default:', oppProjectInterest);
                    }
                }
                
                this.selectedProject = defaultProject;
                if (this.selectedProject) {
                    this.populateBuildings();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.projectList = undefined;
                this.isLoading = false;
            });
    }

    get showBlockingHours() {
        if (this.selectedBlockingHours !== undefined && this.selectedBlockingHours.length > 0) {
            return true;
        }
        return false;
    }

    manageBlockingHours(event) {
        this.selectedBlockingHours = event.target.value;
    }

    updateCommentValue(event) {
        this.commentValue = event.target.value;
        console.log('this.commentValue==>', this.commentValue);
    }

    get blockingHoursOptions() {
        getBlockingHours()
            .then(data => {
                console.log('data==>', data);
                this.blockingHourOptions = data;
                this.selectedBlockingHours = (data && data[0] && data[0].value) ? data[0].value : '';
                console.log('this.blockingHourOptions==>', this.blockingHourOptions);
                console.log('this.selectedBlockingHours==>', this.selectedBlockingHours);
                return data;
            })
            .catch(error => {
                // this.isLoading=false;
                return null;
            });
    }

    populateBuildings() {
        console.log('getAllBuildings');
        getAllBuildings({ projectId: this.selectedProject })
            .then(data => {
                this.buildingList = data;
                console.log('data+' + data);
                this.selectedBuilding = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.buildingList = undefined;
                this.isLoading = false;
            });
    }

    populateUnitTypeFilter() {
        console.log('get Unit Types');
        getUnitTypes()
            .then(data => {
                this.unitTypeList = data;
                console.log('data+' + data);
                //this.selectedUnitType = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.unitTypeList = undefined;
                this.isLoading = false;
            });
    }

    populateBedroomsNumberFilter() {
        console.log('get Number of Bedrooms');
        getNumberofBedrooms()
            .then(data => {
                this.bedroomsList = data;
                console.log('data+' + data);
                //this.selectedNoOfBedrooms = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.bedroomsList = undefined;
                this.isLoading = false;
            });
    }

    populateQualityTypeFilter() {
        console.log('get Unit Types');
        getQualityType()
            .then(data => {
                this.qualityTypeList = data;
                console.log('data+' + data);
                //this.selectedUnitType = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.qualityTypeList = undefined;
                this.isLoading = false;
            });
    }

    populateFloorAreaFilter() {
        console.log('get Unit Types');
        getGFARange()
            .then(data => {
                this.areaList = data;
                console.log('data+' + data);
                //this.selectedUnitType = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.areaList = undefined;
                this.isLoading = false;
            });
    }

    populateFloorValueFilter() {
        console.log('get Unit Types');
        getFloorValues()
            .then(data => {
                this.floorList = data;
                console.log('data+' + data);
                //this.selectedUnitType = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.floorList = undefined;
                this.isLoading = false;
            });
    }

    populateUnitTypeFilter() {
        console.log('get Unit Types');
        getUnitTypes()
            .then(data => {
                this.unitTypeList = data;
                console.log('data+' + data);
                //this.selectedUnitType = (data && data[0] && data[0].value) ? data[0].value : '';
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.unitTypeList = undefined;
                this.isLoading = false;
            });
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // Added optional isSilentRefresh param (default false) so the 10-second
    // auto-refresh poll can call this same method WITHOUT showing the
    // full-screen spinner or blanking the unit table while data loads.
    //
    // PROBLEM BEFORE THIS CHANGE:
    //   - isLoading = true at the top always showed the spinner overlay,
    //     even for a silent background poll.
    //   - unitLst = undefined at the top always blanked the table
    //     immediately, causing a visible "whole screen reload" flash
    //     every 10 seconds even when nothing on screen needed to change.
    //
    // FIX:
    //   - When isSilentRefresh = true: isLoading is left untouched (no
    //     spinner) and unitLst is NOT cleared upfront -- the existing rows
    //     stay visible until the new data arrives, then unitLst is swapped
    //     in one assignment. No empty/blank frame is ever shown to the user.
    //   - When isSilentRefresh = false (default): behaviour is 100%
    //     unchanged from before -- spinner shows and table clears
    //     immediately, exactly as it did for every existing caller
    //     (filter changes, handleRefresh, etc.)
    //
    // No other callers of populateUnitData() were changed -- they all
    // continue to call it with no argument, so isSilentRefresh defaults to
    // false and their behaviour is identical to before this fix.
    // ------------------------------------------------------------------
    populateUnitData(isSilentRefresh = false) {
        if (!isSilentRefresh) {
            this.isLoading = true;
            this.unitLst = undefined;
        }

        // Base parameters
        const params = {
            buildingsId: this.selectedBuilding,
            oppId: this.recordId,
            isModonProfile: this.isModonEgyptProfile
        };

        // Add extra filters only for Modon Egypt profile
        if (this.isModonEgyptProfile) {
            params.unitType = this.selectedUnitType;
            params.qualityType = this.selectQuality;
            params.numberOfBedrooms = this.selectedNoOfBedrooms;
            params.gfaRange = this.selectedFloorArea;
            params.floor = this.selectedFloor;
            params.unitNumber = this.unitCode;
            params.isModonProfile = this.isModonEgyptProfile;
        }
        getUnitDetails(params)
            .then(data => {
                console.log('data==>', data);
                this.isResidentCustomer = data.isResidentCustomer || false;
                this.unitInventoryDetails = data?.units || [];
                // console.log('this.unitInventoryDetails==>', this.unitInventoryDetails);
                // console.log('this.unitInventoryDetails==>', this.unitInventoryDetails.length);

                if (this.unitInventoryDetails.length == 0) {
                    // 2.3 - Arvind - 30 Jun 2026 - suppress the "no units" toast and
                    // avoid blanking the table during a silent background poll; only
                    // show this feedback for an explicit user-triggered search/filter.
                    if (!isSilentRefresh) {
                        const evt = new ShowToastEvent({
                            title: 'Units',
                            message: 'No unit available for selected filter criteria ',
                            variant: 'error',
                        });
                        this.dispatchEvent(evt);
                        this.unitLst = undefined;
                        //this.selectedUnits={};
                    }
                } else {

                    this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                        return {
                            ...unit,
                            TotalPrice__c: this.isWadeemProject && this.isResidentCustomer ? unit.UAE_Citizen_Price__c : unit.TotalPrice__c,
                            totalArea: unit.TotalGrossSellableAreaGSA__c || unit.TotalArea__c || unit.GrossFloorAreaGFA__c,
                            isSelected: (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false),
                            // Arvind fix - null-safe display fields for Bucket/Blocked For lookups.
                            // Bucket__r / BlockedFor__r are often null (unit not blocked), and
                            // dotting into .Name directly in the template throws
                            // "Cannot read properties of undefined (reading 'Name')" for those rows.
                            bucketName: unit.Bucket__r ? unit.Bucket__r.Name : '',
                            blockedForName: unit.BlockedFor__r ? unit.BlockedFor__r.Name : ''
                        }
                    });
                }

                for (let i = 0; i < this.unitLst.length; i++) {
                    this.unitDetails[this.unitLst[i].Id] = this.unitLst[i];
                }
                console.log('this.unitDetails==>', this.unitDetails);
                if (!isSilentRefresh) {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                if (!isSilentRefresh) {
                    this.isLoading = false;
                }
            });
    }



    handleRowSelect(event) {
        this.isLoading = true;
        if (event.target.checked) {
            const checkedUnitId = event.target.dataset.id;
            this.selectedUnits[checkedUnitId] = {
                'selectionStatus': event.target.checked,
                'unitId': checkedUnitId,
                'unitName': event.target.dataset.unitName,
                'projectId': this.unitDetails[checkedUnitId].Phase__r.Project__c,
                'projectName': this.unitDetails[checkedUnitId].Phase__r.Project__r.Name,
                'price': this.unitDetails[checkedUnitId].TotalPrice__c,
                'buildingName': this.unitDetails[checkedUnitId].Phase__r.Name,
                'buildingId': this.unitDetails[checkedUnitId].Phase__c,
                'interior': this.unitDetails[checkedUnitId].Interior__c,
                'facadeStyle': this.unitDetails[checkedUnitId].FacadeStyle__c,
                // Arvind changes for EOI v2.0 - Initialise selectedEOIId for each newly selected unit
                'selectedEOIId': '',
                // Store Typology__c + Number_of_Bedrooms__c for per-unit EOI matching in BOOKING handler
                // and selectedUnitList getter. Bypass checkbox skips these checks when = true.
                'typology': this.unitDetails[checkedUnitId].Typology__c || '',
                'bedrooms': this.unitDetails[checkedUnitId].Number_of_Bedrooms__c || '',
                // Arvind EOI v2.1 - Phase-level EOI gate: true = this unit's phase requires EOI
                'eoiRequired': this.unitDetails[checkedUnitId].Phase__r?.EOI_Required__c || false,
                // Arvind v8.0 - true = ALWAYS require EOI even if no EOIs on opp
                'eoiStrictRequired': this.unitDetails[checkedUnitId].Phase__r?.EOI_Strict_Required__c || false,
                // Arvind changes for EOI v2.0 - END
                // Arvind v17.0 (23 Sep 2026) - Facade Style (filled by generateOffer from Apex)
                'facadeStyleRequired': false,
                'facadeStyleOptions': [],
                'selectedFacadeStyle': ''
            };
            // Pre-fetch payment plan in the background as soon as the unit is ticked.
            // By the time the user reaches page 2 and clicks the tab, data is already cached
            // in selectedUnits[unitId].paymentDetails -- no spinner, no "No payment plan" flash.
            this.generateOffer(checkedUnitId);

        } else {
            const checkedUnitId = event.target.dataset.id;
            this.selectedUnits[checkedUnitId].selectionStatus = false;
            this.selectedUnits[checkedUnitId].paymentDetails = undefined;
        }
        this.showBtnGroup = false;
        this.showBtnGroup = true;
        this.isLoading = false;
    }

    handleBookingUnitActive(event) {
        this.isLoading = true;
        this.currentUnit = event.target.value;
        this.isActiveTab = true;
        let paymentData = this.selectedUnits[this.currentUnit].paymentDetails;
        for (let i = 0; i < paymentData.paymentLst.length; i++) {
            if (paymentData.paymentLst[i].paymentObj.Id == paymentData.selectedPayment) {
                this.paymentInstallments = paymentData.paymentLst[i].paymentObj.Payment_Installments__r;
                this.calculatePaymentAmount();
                this.paymentTypeName = paymentData.paymentLst[i].paymentObj.Name;
                break;
            }
        }
        this.isLoading = false;

    }

    validateBlockForm() {
        let isInvalid = false;
        let inputFields = this.template.querySelectorAll('.blockDetails');
        inputFields.forEach(inputField => {

            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isInvalid = true;
            }
        });
        console.log('isInvalid==>', isInvalid);
        if (isInvalid) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable' }));
            return true;
        }
        return isInvalid;
    }

    saveBlockUnitsEgypt() {
        this.isLoading = true;
        if (this.nationality === 'Egypt') {
            this.selectedBlockingHours = '120';
        } else {
            this.selectedBlockingHours = '24';
        }
        saveBlockedUnits({ selectedUnits: this.selectedUnitIds, opportunityId: this.recordId, commentValue: this.commentValue, blockingHours: this.selectedBlockingHours })
            .then(data => {
                console.log('data==>', data);
                let message = '';
                let type = 'Success';

                if (data == 'Success') {
                    this.showBlockRequestEgyptModal = false;
                    message = 'Block on the selected units are submitted for approval.';
                } else {
                    message = data;
                    type = 'error';
                }
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: message,
                        variant: type,
                        mode: 'dismissable'
                    })
                );
                this.isLoading = false;
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            })
        console.log('valid form');
    }

    saveBlockUnits() {
        this.isLoading = true;

        if (this.validateBlockForm()) {
            this.isLoading = false;
            return;
        }

        saveBlockedUnits({ selectedUnits: this.selectedUnitIds, opportunityId: this.recordId, commentValue: this.commentValue, blockingHours: this.selectedBlockingHours })
            .then(data => {
                console.log('data==>', data);
                let message = '';
                let type = 'Success';

                if (data == 'Success') {
                    this.showBlockRequestModal = false;
                    message = 'Block on the selected units are submitted for approval.';
                } else {
                    message = data;
                    type = 'error';
                }
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: message,
                        variant: type,
                        mode: 'dismissable'
                    })
                );
                this.isLoading = false;
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            })
        console.log('valid form');
    }

    validateForm() {

        let isInvalid = false;
        let inputFields = this.template.querySelectorAll('.confirmationCheckbox');
        inputFields.forEach(inputField => {

            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isInvalid = true;
            }
        });


        console.log('isInvalid==>', isInvalid);
        if (isInvalid) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable' }));
            return true;
        }
        return isInvalid;
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // BUG FIX: checkUnitStatus() below was previously called WITHOUT being
    // awaited / chained. The error branch inside its .then() only returned
    // out of that callback (not out of generateSalesOrder), so execution
    // always fell through immediately to building salesOrderLst and calling
    // saveSalesOrder/saveSalesOrderWithBlockRequest -- regardless of whether
    // checkUnitStatus found the unit already Reserved/Sold by someone else.
    // This was the root cause of the double-booking shown in Unit History
    // (unit moved Available -> Reserved -> Sold within minutes by race).
    //
    // FIX: All logic that used to run unconditionally right after the
    // checkUnitStatus call has been moved into a new private helper method
    // _continueGenerateSalesOrder(). It is now only invoked from inside the
    // checkUnitStatus().then() success branch, so the Sales Order is never
    // created unless Apex confirms (at click-time) the unit is still
    // available. No business logic inside that block was changed -- it is
    // an exact copy/paste of the original code.
    // ------------------------------------------------------------------
    generateSalesOrder() {
        /*
                const complianceStatus = await checkComplianceSubmitted({ oppId: this.recordId, projectName: this.getProjectName });
                if (!this.isModonEgyptProfile) {
                    if (complianceStatus) {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Compliance Error', message: complianceStatus, variant: 'error', mode: 'dismissable' }));
                        return;
                    }
                }
        */
        console.log('==>', this.confirmation);
        this.isLoading = true;
        if (this.validateForm()) {
            this.isLoading = false;
            return;
        }

        // 2.3 - Arvind - 30 Jun 2026 - now properly awaited via .then()
        checkUnitStatus({ selectedUnits: this.selectedUnitIds })
            .then(data => {
                console.log('data==>', data);
                if (data != 'Success') {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: data,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }
                // 2.3 - Arvind - 30 Jun 2026 - only proceed to build/save the Sales Order
                // after Apex has confirmed the unit(s) are still available.
                console.log('this.selectedUnitList==>', this.selectedUnitList);
                this._continueGenerateSalesOrder();
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            });
    }

    // ------------------------------------------------------------------
    // 2.3 - Arvind - 30 Jun 2026
    // New private helper. Body below is an exact copy of the code that used
    // to sit directly inside generateSalesOrder() right after the
    // (previously non-awaited) checkUnitStatus call. No logic changed.
    // ------------------------------------------------------------------
    _continueGenerateSalesOrder() {

        // Arvind v17.0 (23 Sep 2026) - Facade Style re-check before the Sales Order is built
        const facadeErr = this.validateFacadeStyles();
        if (facadeErr) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Facade Style Required',
                message: facadeErr,
                variant: 'error',
                mode: 'dismissable'
            }));
            this.isLoading = false;
            return;
        }
        // Arvind v17.0 - END

        // Arvind changes for EOI v2.0 - START
        // Validate that each selected unit has a unique Completed EOI linked before creating SOs.
        // Only applies when isBookingSelectedWithEOI is true (non-Modon Egypt + BOOKING + completed EOIs exist).
        // When isBookingSelectedWithEOI is false, eoiMappingStr stays null and Apex skips EOI linking entirely.
        let eoiMappingStr = null;
        if (this.isBookingSelectedWithEOI) {
            let eoiMapping = {};
            let selectedEOIIds = [];
            for (let i = 0; i < this.selectedUnitList.length; i++) {
                const unitId = this.selectedUnitList[i].unitId;
                const unitName = this.selectedUnitList[i].unitName;
                const eoiId = this.selectedUnits[unitId] ? this.selectedUnits[unitId].selectedEOIId : '';
                if (!eoiId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'EOI Required',
                        message: 'Please select an EOI for unit ' + unitName + ' before proceeding.',
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                    this.isLoading = false;
                    return;
                }
                if (selectedEOIIds.indexOf(eoiId) !== -1) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Duplicate EOI',
                        message: 'The same EOI cannot be assigned to multiple units. Please select a unique EOI for each unit.',
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                    this.isLoading = false;
                    return;
                }
                selectedEOIIds.push(eoiId);
                eoiMapping[unitId] = eoiId;
            }
            eoiMappingStr = JSON.stringify(eoiMapping);
            console.log('Arvind changes for EOI v2.0 - eoiMappingStr:', eoiMappingStr);
        }
        // Arvind changes for EOI v2.0 - END

        let salesOrderLst = [];
        for (let i = 0; i < this.selectedUnitList.length; i++) {

            let priceValue = 0;
            if (this.selectedUnitList[i].unitOptionPrice == 0 || this.selectedUnitList[i].unitOptionPrice === undefined) {
                priceValue = this.selectedUnitList[i].basePriceFromMapping > 0 ? this.selectedUnitList[i].basePriceFromMapping : this.selectedUnitList[i].price
                // priceValue = this.selectedUnitList[i].price;
            } else {
                priceValue = this.selectedUnitList[i].unitOptionPrice;
            }

            const currentUnitId = this.selectedUnitList[i].unitId;
            const currentUnitData = this.selectedUnits[currentUnitId];

            const currencyCode = currentUnitData?.paymentDetails?.paymentLst?.find(
                p => p.paymentObj.Id === currentUnitData.paymentDetails.selectedPayment
            )?.paymentObj.CurrencyIsoCode || null;

            // Arvind v17.0 (23 Sep 2026) - phase-driven Facade Style overrides the unit value;
            // when the phase flag is off the existing unit FacadeStyle__c is sent as before.
            const facadeValue = this.selectedUnitList[i].facadeStyleRequired
                ? this.selectedUnitList[i].selectedFacadeStyle
                : this.selectedUnitList[i].facadeStyle;
            // Previous: new salesOrder(..., this.selectedUnitList[i].interior, this.selectedUnitList[i].facadeStyle);
            let salesOrderObj = new salesOrder(this.selectedUnitList[i].paymentDetails.selectedPayment, null, this.selectedUnitList[i].unitId, null, priceValue, currencyCode, this.selectedUnitList[i].interior, facadeValue);
            // Arvind v19.0 (24 Sep 2026) - Pre-Approval Number on the Sales Order
            // (EOI number wins; else the typed number for a pre-approval plan). Apex re-validates.
            const soPreApprovalNo = this.getPreApprovalNumberForSO(this.selectedUnitList[i].unitId);
            if (soPreApprovalNo) {
                salesOrderObj.Pre_Approval_Number__c = soPreApprovalNo;
            }
            console.log('=====>', salesOrderObj);

            if (this.selectedUnitList[i].unitOptionDetails !== undefined && this.selectedUnitList[i].unitOptionDetails.selectedUnitOption != null && this.selectedUnitList[i].unitOptionDetails.selectedUnitOption != '') {
                salesOrderObj.UnitOption__c = this.selectedUnitList[i].unitOptionDetails.selectedUnitOption;
            }
            if (this.selectedUnitList[i].allUnitOptions !== undefined && this.selectedUnitList[i].allUnitOptions.length > 0) {
                for (let j = 0; j < this.selectedUnitList[i].allUnitOptions.length; j++) {
                    salesOrderObj[this.selectedUnitList[i].allUnitOptions[j].fieldApiName] = this.selectedUnitList[i].allUnitOptions[j].selectedValue;
                }
            }
            console.log('salesOrderObj==>', JSON.stringify(salesOrderObj));
            salesOrderLst.push(salesOrderObj);
        }
        // console.log('salesOrderLst==>', salesOrderLst);

        /***** Offer Lines Info **/
        this.offerDetailsLst = [];
        const offerDetails = this.template.querySelectorAll('c-offers-line-details-l-w-c');
        console.log(':offerDetails:' + offerDetails.length);
        if (offerDetails.length > 0) {
            offerDetails.forEach(child => {
                var offerLinesData = child.getTableData();
                console.log('offerLinesData:' + JSON.stringify(offerLinesData));
                for (var i = 0; i < offerLinesData.length; i++) {
                    this.offerDetailsLst.push({
                        unitId: offerLinesData[i].unitId,
                        offerLinesLst: offerLinesData[i].offerLinesList
                    });
                }
            });
            console.log(JSON.stringify(this.offerDetailsLst));
        }
        /****************** Offer Lines */

        if (this.selectedAction == 'BLOCKREQUESTWITHFEES') {
            saveSalesOrderWithBlockRequest({ salesOrderList: salesOrderLst, oppId: this.recordId })
                .then(data => {
                    console.log('data======>', data);
                    if (data == 'Success') {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Sales order created successfully.', variant: 'success', mode: 'dismissable' }));
                        window.location.reload();
                    } else {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: data, variant: 'Error', mode: 'dismissable' }));
                    }

                    this.isLoading = false;
                })
                .catch(error => {
                    console.log(error);
                    this.isLoading = false;
                });
        } else {
            // Arvind changes for EOI v2.0 - Pass eoiMappingStr as 4th param.
            // null when no completed EOIs or Modon Egypt -- Apex skips EOI linking, existing behaviour unchanged.
            saveSalesOrder({ salesOrderList: salesOrderLst, oppId: this.recordId, offerLinesListStr: JSON.stringify(this.offerDetailsLst), eoiMappingStr: eoiMappingStr })
            // Arvind changes for EOI v2.0 - END
                .then(data => {
                    console.log('data===>', data);
                    if (data == 'Success') {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Sales order created successfully.', variant: 'success', mode: 'dismissable' }));
                        window.location.reload();
                    } else {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: data, variant: 'Error', mode: 'dismissable' }));
                    }

                    this.isLoading = false;
                })
                .catch(error => {
                    console.log(error);
                    this.isLoading = false;
                });
        }

    }

    updateConfirmation(event) {
        console.log(event.target.checked);
        this.confirmation = event.target.checked;
        this.isLoading = false;
    }

    handlePaymentUnitSelect(event) {

        this.isLoading = true;

        this.currentUnit = event.target.value;
        console.log('this.currentUnit==>', this.currentUnit);

        if (!this.selectedUnits[this.currentUnit].paymentDetails) {

            this.paymentInstallments = [];
            this.paymentTypeName = '';
            this.generateOffer();
            this.isLoading = false;
        } else {

            console.log(this.selectedUnits[this.currentUnit].paymentDetails);
            let paymentData = this.selectedUnits[this.currentUnit].paymentDetails;
            // Arvind v18.0 (23 Sep 2026) - clear stale table when the filtered plan list is empty
            this.paymentInstallments = [];
            this.paymentTypeName = '';
            for (let i = 0; i < paymentData.paymentLst.length; i++) {
                if (paymentData.paymentLst[i].paymentObj.Id == paymentData.selectedPayment) {
                    this.paymentInstallments = paymentData.paymentLst[i].paymentObj.Payment_Installments__r;
                    this.calculatePaymentAmount();
                    this.paymentTypeName = paymentData.paymentLst[i].paymentObj.Name;
                    break;
                }
            }
            this.isLoading = false;
        }
    }

    handleUnitOptionSelection(event) {
        console.log(event.target.dataset.index);
        console.log(event.target.value);
        let index = event.target.dataset.index;
        this.selectedUnits[this.currentUnit].allUnitOptions[index].selectedValue = event.target.value;
    }

    // Arvind changes for EOI v2.0 - unitId param added so pre-fetch calls from handleRowSelect write into the correct
    // selectedUnits slot without touching this.currentUnit.
    // Called from two places:
    //   Arvind EOI v2.0 - 1. handleRowSelect(checkedUnitId)  -- background pre-fetch on checkbox tick (page 1)
    //   2. handlePaymentUnitSelect()       -- on-demand fallback if data not yet cached (page 2)
    generateOffer(unitId) {
        // Arvind changes for EOI v2.0 - Use the passed unitId for background pre-fetches; fall back to this.currentUnit
        // for the existing on-demand call from handlePaymentUnitSelect (no arg passed there).
        const targetUnitId = unitId || this.currentUnit;
        console.log('generateSalesOffer==> targetUnitId:', targetUnitId);
        generateSalesOffer({ selectedUnitId: targetUnitId, isModonEgyptProfile: this.isModonEgyptProfile })
            .then(data => {
                console.log('data==>', data);
                console.log('data.unitPaymentDetailObj==>', data.unitPaymentDetailObj);
                console.log('data.unitOptiontDetailObj==>', data.unitOptiontDetailObj);
                console.log('data.unitOptiontDetailObj.unitOptionLst==>', data.unitOptiontDetailObj.unitOptionLst);
                if (data != null) {
                    // Arvind v17.0 (23 Sep 2026) - Facade Style options for this unit
                    this.applyFacadeStyleData(targetUnitId, data);

                    if (data.unitPaymentDetailObj.paymentLst !== undefined) {

                        let paymentDetailWrapper = data.unitPaymentDetailObj;
                        // Arvind changes for EOI v2.0 - Always write into targetUnitId slot (safe for both pre-fetch and active-tab calls)
                        this.selectedUnits[targetUnitId].paymentDetails = paymentDetailWrapper;
                        // Arvind v18.0 (23 Sep 2026) - keep the unfiltered list for pre-approval filtering
                        this.selectedUnits[targetUnitId].fullPaymentDetails = paymentDetailWrapper;
                        this.selectedUnits[targetUnitId].unitPaymentPlanOptions = data.unitPaymentPlanOptions || [];

                        console.log(this.selectedUnits[targetUnitId]);

                        for (let i = 0; i < paymentDetailWrapper.paymentLst.length; i++) {
                            if (paymentDetailWrapper.paymentLst[i].paymentObj.Id == paymentDetailWrapper.selectedPayment) {
                                // Arvind changes for EOI v2.0 - Only update UI display state when this is the currently active tab.
                                // Arvind changes for EOI v2.0 - Pre-fetched background units must not overwrite the visible installment table.
                                const isActiveTab = (targetUnitId === this.currentUnit);
                                if (isActiveTab) {
                                    this.paymentInstallments = paymentDetailWrapper.paymentLst[i].paymentObj.Payment_Installments__r;
                                    this.paymentPlanDiscountPercent = paymentDetailWrapper?.paymentLst?.[i]?.paymentObj?.Discount_Percent__c || 0;
                                    this.MaintenanceFee = paymentDetailWrapper?.paymentLst?.[i]?.paymentObj?.Maintenance_Fee__c || 0;
                                    this.NumberOfMaintenanceFee = paymentDetailWrapper?.paymentLst?.[i]?.paymentObj?.Number_of_Maintenance_Fee__c || 0;
                                    this.selectedCurrencyIsoCode = paymentDetailWrapper?.paymentLst?.[i]?.paymentObj?.CurrencyIsoCode || null;
                                    this.paymentTypeName = paymentDetailWrapper.paymentLst[i].paymentObj.Name;
                                }
                                this.selectedUnits[targetUnitId].selectedPPCurrency = paymentDetailWrapper?.paymentLst?.[i]?.paymentObj?.CurrencyIsoCode || null;
                                if (isActiveTab) { this.calculatePaymentAmount(); }
                                //break;
                            }
                            //Filter UnitPaymentPlanMapping__c records based on selected payment plan and currency
                            const allMappings = data.unitPaymentPlanOptions || [];
                            const filteredMappings = allMappings.filter(mapping => {
                                return (mapping.CurrencyIsoCode === this.selectedUnits[targetUnitId].selectedPPCurrency && mapping.Payment_Plan__c === paymentDetailWrapper.selectedPayment);
                            });

                            // Store Base_Price__c from junction object
                            if (filteredMappings.length > 0) {
                                const basePrice = filteredMappings[0].Base_Price__c || 0;
                                this.selectedUnits[targetUnitId].basePriceFromMapping = basePrice;
                                if (targetUnitId === this.currentUnit) {
                                    this.unitBasePrice = basePrice;
                                }
                                console.log('Base Price from Mapping:', basePrice);
                            } else {
                                this.selectedUnits[targetUnitId].basePriceFromMapping = 0;
                                if (targetUnitId === this.currentUnit) {
                                    this.unitBasePrice = 0;
                                }
                                console.warn('No matching UnitPaymentPlanMapping__c found for selected payment plan and currency.');
                            }
                            if (targetUnitId === this.currentUnit) { this.calculatePaymentAmount(); }
                            break;
                        }
                        console.log('this.paymentInstallments==>', this.paymentInstallments);
                        console.log('this.paymentTypeName==>', this.paymentTypeName);
                    }

                    if (data.unitOptiontDetailObj.unitOptionLst !== undefined) {
                        let unitOptionWrapper = data.unitOptiontDetailObj;
                        if (this.isWadeemProject) {
                            const availableUnitOptions = this.isResidentCustomer ? unitOptionWrapper.availableUnitOptions?.filter(opt => (opt?.label?.includes('Option 1') || opt?.label?.includes('Type 1')) && opt?.value)
                                : unitOptionWrapper.availableUnitOptions?.filter(opt => (opt?.label?.includes('Option 2') || opt?.label?.includes('Type 2')) && opt?.value);

                            unitOptionWrapper.availableUnitOptions = availableUnitOptions;
                            unitOptionWrapper.selectedUnitOption = availableUnitOptions?.[0]?.value;
                        }

                        this.selectedUnits[targetUnitId].unitOptionDetails = unitOptionWrapper;

                    }

                    if (data.unitOptionsList.length > 0) {
                        this.selectedUnits[targetUnitId].allUnitOptions = data.unitOptionsList;
                    }

                    // Arvind v18.0 (23 Sep 2026) - apply booking pre-approval rule (no-op for Offer / Egypt)
                    this.applyPaymentPlanFilter(targetUnitId, true);   // v19.0 default selection
                }

                this.isLoading = false;
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            });
    }

    //update for launch to handle the discount percent on payment plan (27-09-2025)

    // calculatePaymentAmount() {
    //     console.log('this.selectedUnits[this.currentUnit].unitOptionPrice==>', this.selectedUnits[this.currentUnit].unitOptionPrice);
    //     console.log('this.selectedUnits[].price==>', this.selectedUnits[this.currentUnit].price);
    //     if (this.selectedUnits[this.currentUnit].unitOptionPrice == 0 || this.selectedUnits[this.currentUnit].unitOptionPrice === undefined) {

    //         this.paymentInstallments = this.paymentInstallments.map(row => ({
    //             ...row,
    //             amount: (row.Milestone__c / 100) * this.selectedUnits[this.currentUnit].price
    //             }));
    //     } else {
    //         this.paymentInstallments = this.paymentInstallments.map(row => ({
    //         ...row,
    //             amount: (row.Milestone__c / 100) * this.selectedUnits[this.currentUnit].unitOptionPrice
    //         }));
    //     }

    // }

    calculatePaymentAmount() {
        console.log('this.selectedUnits[this.currentUnit].unitOptionPrice==>', this.selectedUnits[this.currentUnit].unitOptionPrice);
        console.log('this.selectedUnits[].price==>', this.selectedUnits[this.currentUnit].price);
        console.log('this.paymentPlanDiscountPercent==>', this.paymentPlanDiscountPercent);
        if (this.selectedUnits[this.currentUnit].unitOptionPrice == 0 || this.selectedUnits[this.currentUnit].unitOptionPrice === undefined) {
            const unitPrice = this.selectedUnits[this.currentUnit].basePriceFromMapping > 0 ? (this.selectedUnits[this.currentUnit].basePriceFromMapping) : this.selectedUnits[this.currentUnit].price;
            console.log('this.unitPrice==>', unitPrice);
            this.paymentInstallments = this.paymentInstallments.map(row => ({
                ...row,
                maintainancefee: row.Is_Maintenance_Installment__c ? (((this.MaintenanceFee / 100) * unitPrice) / this.NumberOfMaintenanceFee) : 0,
                //amount: (row.Milestone__c / 100) * unitPrice,
                amount: ((row.Milestone_Egypt_Percent__c ?? row.Milestone__c) / 100) * unitPrice,
                currency: this.selectedUnits[this.currentUnit].selectedPPCurrency
            }));
        } else {
            const unitDiscountedPrice = this.selectedUnits[this.currentUnit].unitOptionPrice > 0 ? (this.selectedUnits[this.currentUnit].unitOptionPrice) : 0
            this.paymentInstallments = this.paymentInstallments.map(row => ({
                ...row,
                maintainancefee: row.Is_Maintenance_Installment__c ? (((this.MaintenanceFee / 100) * this.selectedUnits[this.currentUnit].unitOptionPrice) / this.NumberOfMaintenanceFee) : 0,
                //amount: (row.Milestone__c / 100) * unitDiscountedPrice
                amount: ((row.Milestone_Egypt_Percent__c ?? row.Milestone__c) / 100) * unitDiscountedPrice
            }));
        }

    }

    selectUnitOption(event) {
        this.isLoading = true;
        let pd = JSON.parse(JSON.stringify(this.selectedUnits[this.currentUnit]));
        console.log('pd==>', pd);
        if (event.detail.value != '') {
            this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption = event.detail.value;

            console.log('this.selectedUnits[this.currentUnit]==>', this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst);

            for (let i = 0; i < this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst.length; i++) {
                if (this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Id == event.detail.value) {
                    console.log('selectedUitOption==>', this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj);
                    console.log('total Price==>', this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.TotalPrice__c);
                    this.unitOptionPrice = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.TotalPrice__c;
                    this.selectedUnits[this.currentUnit].unitOptionPrice = this.unitOptionPrice;
                    this.selectedUnits[this.currentUnit].selectedUnitOptionName = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Name;
                    this.selectedUnits[this.currentUnit].selectedUnitOptionId = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Id;
                }
            }
        } else {
            this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption = '';
            this.unitOptionPrice = 0;
            this.selectedUnits[this.currentUnit].unitOptionPrice = 0;
        }
        this.calculatePaymentAmount();

        this.isLoading = false;
    }

    selectPaymentPlan(event) {
        this.isLoading = true;
        let pd = JSON.parse(JSON.stringify(this.selectedUnits[this.currentUnit]));
        console.log('pd==>', pd);
        console.log('event.detail.value==>', event.detail.value);
        for (let i = 0; i < pd.paymentDetails.paymentLst.length; i++) {
            if (pd.paymentDetails.paymentLst[i].paymentObj.Id == event.detail.value) {
                this.paymentInstallments = pd.paymentDetails.paymentLst[i].paymentObj.Payment_Installments__r;
                this.paymentPlanDiscountPercent = pd.paymentDetails.paymentLst[i].paymentObj.Discount_Percent__c;
                this.MaintenanceFee = pd.paymentDetails.paymentLst[i].paymentObj.Maintenance_Fee__c;
                this.NumberOfMaintenanceFee = pd.paymentDetails.paymentLst[i].paymentObj.Number_of_Maintenance_Fee__c;
                this.selectedCurrencyIsoCode = pd.paymentDetails.paymentLst[i].paymentObj.CurrencyIsoCode;
                this.selectedUnits[this.currentUnit].selectedPPCurrency = pd.paymentDetails.paymentLst[i].paymentObj.CurrencyIsoCode;
                this.currencyCode = this.selectedCurrencyIsoCode;
                this.calculatePaymentAmount();
                this.paymentTypeName = pd.paymentDetails.paymentLst[i].paymentObj.Name;

                const allMappings = this.selectedUnits[this.currentUnit].unitPaymentPlanOptions || [];
                console.log('allMappings==>', allMappings);
                const filteredMappings = allMappings.filter(mapping => {
                    return (mapping.CurrencyIsoCode === this.selectedCurrencyIsoCode && mapping.Payment_Plan__c === event.detail.value);
                });

                if (filteredMappings.length > 0) {
                    const basePrice = filteredMappings[0].Base_Price__c || 0;
                    this.unitBasePrice = basePrice;
                    this.selectedUnits[this.currentUnit].basePriceFromMapping = basePrice;
                    console.log('[OK] Updated Base Price from Mapping:', basePrice);
                } else {
                    this.unitBasePrice = 0;
                    this.selectedUnits[this.currentUnit].basePriceFromMapping = 0;
                    console.warn('[!] No matching mapping found for selected payment plan and currency.');
                }

                this.calculatePaymentAmount();
                break;
            }
        }
        console.log('this.paymentInstallments==>', this.paymentInstallments);
        console.log('this.paymentTypeName==>', this.paymentTypeName);

        this.selectedUnits[this.currentUnit].paymentDetails.selectedPayment = event.detail.value;
        // Arvind v19.0 (24 Sep 2026) - show / hide the Pre-Approval Number box for the new plan
        this.updatePreApprovalState(this.currentUnit);
        this.selectedUnits = { ...this.selectedUnits };
        this.isLoading = false;
    }

    handleBuildingChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedBuilding = event.detail.value;
        this.populateUnitData();
    }

    handleProjectChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedProject = event.detail.value;
        this.populateBuildings();
    }

    handleUnitChange(event) {
        console.log(event.target.value);
    }

    async handleMenuAction(event) {
        console.log('handle menu action');
        console.log('selectedUnit==>', this.selectedUnits);
        console.log('selectedUnitIds==>', JSON.stringify(this.selectedUnitIds));
        this.showOfferDetails = false;
        if (event.target.name == 'OFFER') {
            try {
                let unitNames = this.selectedUnitList.map(unit => unit.unitName);
                // let unitNames = this.selectedUnitList.map(unit => {
                //     let name = unit.unitName || '';
                //     // Remove "bashayer-" prefix (case-insensitive)
                //     return name.replace(/^bashayer-/i, '');
                // });
                
                console.log('unitNames==>', unitNames);

                this.isLoading = true;
                const urlMap = await makeDPGApiCall({ unitNames });
                console.log('API Response:', urlMap);
                this.unitURL = urlMap;
                this.isLoading = false;
            } catch (err) {
                console.log(err);
            }
            // Arvind changes for EOI v2.0 - Commented out: availableEOI check removed, no longer needed
            // if (this.availableEOI < this.totalSelectedUnits && this.availableEOI != 0) {
            //     const evt = new ShowToastEvent({
            //         title: 'Error!',
            //         message: 'Number of units selected are more than EOI available for this opportunity.',
            //         variant: 'error',
            //     });
            //     this.dispatchEvent(evt);
            //     return;
            // }
            this.selectedAction = 'OFFER';
            // Arvind v18.0 (23 Sep 2026) - Offer shows the full payment plan list (as before)
            this.applyPaymentPlanFilterAll();
            this.steps = []
            this.steps.push({ label: 'Unit Selection', value: 1 });
            this.steps.push({ label: 'Payment Selection', value: 2 });
            this.steps.push({ label: 'Offer generation', value: 3 });
            this.pageNumber = this.pageNumber + 1;
        } else if (event.target.name == 'BACK') {
            console.log('this.lastPageName==>', this.lastPageName);
            // if(this.lastPageName == 'Booking selected'){
            // this.unitRollbackConfirmation = true;

            // return;
            // unblockSelectedUnits({selectedUnits : this.selectedUnitIds})
            // .then(data => {
            //     console.log('data==>', data);
            //     this.isLoading=false;
            //     this.lastPageName = 'Booking';
            // })
            // .catch(error => {
            //     console.log(error);
            //     this.isLoading=false;
            // });
            // this.isLoading = false;
            // }
            //this.lastPageName = 'Booking';
            this.pageNumber = this.pageNumber - 1;
            this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                return {
                    ...unit,
                    totalArea: unit.TotalGrossSellableAreaGSA__c || unit.TotalArea__c,
                    isSelected: (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false),
                    // Arvind fix - keep null-safe fields in sync with populateUnitData()
                    bucketName: unit.Bucket__r ? unit.Bucket__r.Name : '',
                    blockedForName: unit.BlockedFor__r ? unit.BlockedFor__r.Name : ''
                }
            });
        } else if (event.target.name == 'FORWARD') {
            this.isLoading = true;
            for (var key in this.selectedUnits) {
                if (this.selectedUnits[key].paymentDetails === undefined && this.selectedUnits[key].selectionStatus) {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: 'Payment plan is not selected for ' + this.selectedUnits[key].unitName + ' unit.',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }

                if (this.selectedUnits[key].unitOptionDetails !== undefined && this.selectedUnits[key].unitOptionDetails.selectedUnitOption == '' && this.selectedUnits[key].selectionStatus) {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: 'Unit option is not selected for ' + this.selectedUnits[key].unitName + ' unit.',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }
                // Arvind v17.0 (23 Sep 2026) - skip legacy Al Naseem design check when the phase drives Facade Style
                if (this.selectedUnits[key].projectName == 'Al Naseem' && this.selectedDesign == '' && this.isOfferSelected
                    && !this.selectedUnits[key].facadeStyleRequired) {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: 'Design is not selected for ' + this.selectedUnits[key].unitName + ' unit.',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }
            }

            // Arvind v17.0 (23 Sep 2026) - Facade Style mandatory when Phase.Facade_Style__c = true
            const facadeError = this.validateFacadeStyles();
            if (facadeError) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Facade Style Required',
                    message: facadeError,
                    variant: 'error',
                    mode: 'dismissable'
                }));
                this.isLoading = false;
                return;
            }
            // Arvind v17.0 - END

            // Arvind v19.0 (24 Sep 2026) - payment plan + Pre-Approval Number (Book Unit/s, non-Egypt)
            // Replaces the v18.0 filtering check.
            if (this.selectedAction === 'BOOKING' && !this.isModonEgyptProfile) {
                for (let key in this.selectedUnits) {
                    const u = this.selectedUnits[key];
                    if (!u.selectionStatus) {
                        continue;
                    }
                    this.applyPaymentPlanFilter(key);
                    let planError = '';
                    if (!u.paymentDetails || !u.paymentDetails.selectedPayment) {
                        planError = 'Payment plan is not selected.';
                    } else if (u.showManualPreApproval && !(u.manualPreApprovalNumber || '').trim()) {
                        planError = 'Pre-Approval Number is required for the selected pre-approval payment plan.';
                    }
                    if (planError) {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Payment Plan',
                            message: u.unitName + ': ' + planError,
                            variant: 'error',
                            mode: 'dismissable'
                        }));
                        this.isLoading = false;
                        return;
                    }
                }
            }
            // Arvind v19.0 - END

            let isInvalid = false;
            let inputFields = this.template.querySelectorAll('.picklistUnitOption');
            inputFields.forEach(inputField => {

                if (!inputField.checkValidity()) {
                    inputField.reportValidity();
                    isInvalid = true;
                }
            });


            console.log('isInvalid==>', isInvalid);
            if (isInvalid) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable' }));
                this.isLoading = false;
                return;
            }

            // Arvind changes for EOI v2.0 - START
            // Before moving to page 3, validate each selected unit has a unique EOI.
            // Only fires when isBookingSelectedWithEOI is true (non-Modon Egypt + BOOKING + completed EOIs).
            // Modon Egypt users are never affected because isBookingSelectedWithEOI = false for them.
            if (this.isBookingSelectedWithEOI) {
                let selectedEOISet = new Set();
                for (let key in this.selectedUnits) {
                    if (this.selectedUnits[key].selectionStatus) {
                        if (!this.selectedUnits[key].selectedEOIId) {
                            this.dispatchEvent(new ShowToastEvent({
                                title: 'Error!',
                                message: 'Please select an EOI for unit: ' + this.selectedUnits[key].unitName,
                                variant: 'error',
                                mode: 'dismissable'
                            }));
                            this.isLoading = false;
                            return;
                        }
                        if (selectedEOISet.has(this.selectedUnits[key].selectedEOIId)) {
                            this.dispatchEvent(new ShowToastEvent({
                                title: 'Error!',
                                message: 'The same EOI cannot be linked to multiple units. Please select a unique EOI for each unit.',
                                variant: 'error',
                                mode: 'dismissable'
                            }));
                            this.isLoading = false;
                            return;
                        }
                        selectedEOISet.add(this.selectedUnits[key].selectedEOIId);
                    }
                }
            }
            // Arvind changes for EOI v2.0 - END

            if (this.isBookingSelected) {
                checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                    .then(data => {
                        console.log('data==>', data);
                        if (data == 'Success') {
                            this.pageNumber = this.pageNumber + 1;
                            console.log(this.pageNumber);
                            this.isLoading = false;
                            this.showOfferDetails = true;

                        } else {
                            const evt = new ShowToastEvent({
                                title: 'Error!',
                                message: data,
                                variant: 'error',
                                mode: 'dismissable'
                            });
                            this.dispatchEvent(evt);
                            this.isLoading = false;
                            return;
                        }
                    })
                    .catch(error => {
                        console.log(error);
                        this.isLoading = false;
                    });
            } else if (this.isOfferSelected) {
                this.pageNumber = this.pageNumber + 1;
                console.log(this.pageNumber);
                this.isLoading = false;
            }



            // if(this.lastPageName == 'Booking'){
            //     updateUnitsAsBlocked({selectedUnits : this.selectedUnitIds, oppId : this.recordId})
            //         .then(data => {
            //             console.log('data==>', data);
            //             if(data == 'Success'){
            //             this.isLoading=false;
            //             this.lastPageName = 'Booking selected';
            //         }else{
            //             const evt = new ShowToastEvent({
            //                 title: 'Error!',
            //                 message: data,
            //                 variant: 'error',
            //                 mode: 'dismissable'
            //             });
            //             this.dispatchEvent(evt);
            //         }

            //     })
            //     .catch(error => {
            //         console.log(error);
            //         this.isLoading=false;
            //     });
            // }


        } else if (event.target.name == 'BOOKING') {
            // Arvind v14.1 - Capture the action name BEFORE the first await.
            // selectedAction is now assigned inside the checkUnitStatus callback,
            // so it must not depend on the event object surviving that far.
            const bookingActionName = event.target.name;

            // Arvind v14.0 (28/08/2026) - KYC GATE - START
            // Runs FIRST, before any EOI gate and before the page advances.
            // This is the ONLY call site for validateKYCForBooking(); the
            // OFFER / BLOCKREQUEST / BLOCKREQUESTEGYPT / BLOCKREQUESTWITHFEES
            // branches are untouched, so Generate Offer is unaffected.
            const kycPassed = await this.validateKYCForBooking();
            if (!kycPassed) {
                this.isLoading = false;
                return;
            }
            // Arvind v14.0 - KYC GATE - END
            // Arvind changes for EOI v2.0 - START
            // Non-Modon Egypt only: validate EOI availability for each selected unit.
            // Modon Egypt is completely unaffected -- this block never runs for them.

            // -- Arvind EOI v2.1 - BOOKING validation gates ------------------------------
            // All gates are guarded by isModonEgyptProfile = false, so Modon Egypt is untouched.
            // Arvind EOI v2.1 - Gates only fire when the selected unit's Phase has EOI_Required__c = true.
            // Arvind EOI v2.1 - If Phase.EOI_Required__c = false -> isEOIRequiredPhase = false -> all gates skip.

            // Gate 0: Apex reported an error at load (e.g., all receipts non-cleared for VIP).
            // Stored silently on load, shown only when booking is attempted.
            if (!this.isModonEgyptProfile && this.isEOIRequiredPhase && this.eoiValidationError) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'EOI Validation',
                    message: this.eoiValidationError,
                    variant: 'error',
                    mode: 'dismissable'
                }));
                return;
            }

            // Gate 1: Phase requires EOI but no valid EOIs available.
            // Standard: No Completed EOI -> "Only a Completed EOI is allowed to book."
            // VIP: No EOI of any status -> same message.
            // Arvind v8.0 - Exception: if no EOIs exist on opp at all (hasAnyEOI=false)
            //   AND the unit's phase is NOT strict (EOI_Strict_Required__c=false),
            //   allow booking without an EOI (eoiMappingStr stays null).
            if (!this.isModonEgyptProfile && this.isEOIRequiredPhase && this.completedEOIs.length === 0) {
                const isAnyUnitStrictRequired = Object.values(this.selectedUnits)
                    .some(u => u.selectionStatus && u.eoiStrictRequired);
                if (isAnyUnitStrictRequired || this.hasAnyEOI) {
                    // Block: either strict EOI required, or EOIs exist on opp but none are valid
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'EOI Required',
                        message: 'Only a Completed EOI is allowed to book this unit.',
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                    return;
                }
                // Allow: no EOIs on opp + not strict -> fall through to booking without EOI
                console.log('Arvind v8.0 - No EOIs on opp, EOI_Strict_Required__c=false -> allow booking without EOI');
            }

            if (!this.isModonEgyptProfile && this.isEOIRequiredPhase && this.hasCompletedEOIs) {

                // -- Gate 2: Typology + Bedroom match per unit ---------------------------------
                // Each selected unit must match at least one EOI typology + bedrooms.
                // Skipped when Bypass_EOI_Typology_Check__c = true (handles both standard + VIP).
                if (!this.bypassEOITypologyCheck) {
                    for (let key in this.selectedUnits) {
                        if (this.selectedUnits[key].selectionStatus) {
                            const unitTypology = this.selectedUnits[key].typology || '';
                            const unitBedrooms = this.selectedUnits[key].bedrooms || '';
                            const matchingEOIs = this.completedEOIs.filter(eoi =>
                                eoi.unitTypology === unitTypology && eoi.bedrooms === unitBedrooms
                            );
                            if (matchingEOIs.length === 0) {
                                this.dispatchEvent(new ShowToastEvent({
                                    title: 'EOI Typology Mismatch',
                                    message: 'Cannot proceed. Unit "' + this.selectedUnits[key].unitName
                                           + '" (Typology: ' + (unitTypology || 'N/A')
                                           + ', Bedrooms: ' + (unitBedrooms || 'N/A')
                                           + ') does not match any available EOI. '
                                           + 'Please select a unit that matches your EOI typology and bedrooms.',
                                    variant: 'error',
                                    mode: 'dismissable'
                                }));
                                return;
                            }
                        }
                    }
                }

                // -- Gate 3: Total selected units must not exceed available EOIs ----------------
                if (this.completedEOIs.length < this.totalSelectedUnits) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error!',
                        message: 'Number of units selected (' + this.totalSelectedUnits
                               + ') cannot exceed the number of available EOIs ('
                               + this.completedEOIs.length + ').',
                        variant: 'error',
                        mode: 'dismissable'
                    }));
                    return;
                }
            }
            // Arvind EOI v2.1 - END

            // Arvind v14.1 (28/08/2026) - RACE FIX - START
            // BEFORE: checkUnitStatus was fire-and-forget. The `return` in its
            // else-branch only exited the callback, so the block below (steps +
            // pageNumber++) always ran. A unit already Reserved/Sold by another
            // agent showed the toast AND still advanced the user to page 2.
            // AFTER: the page-advance block is moved verbatim inside the
            // `data == 'Success'` branch, so the wizard only moves forward once
            // Apex confirms the unit is still available at click time.
            // Mirrors the identical fix applied to generateSalesOrder() in 2.3.
            // No business logic changed - the moved lines are byte-identical.
            checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                .then(data => {
                    console.log('data==>', data);
                    if (data == 'Success') {
                        // -- moved verbatim from below (was outside the .then) --
                        this.lastPageName = 'Booking';
                        this.selectedAction = bookingActionName;
                        // Arvind v18.0 (23 Sep 2026) - booking: hide / show pre-approval plans per EOI
                        this.applyPaymentPlanFilterAll(true);   // v19.0 default selection
                        this.steps = [];
                        this.steps.push({ label: 'Unit Selection', value: 1 });
                        this.steps.push({ label: 'Payment Selection', value: 2 });
                        this.steps.push({ label: 'Book Unit(s)', value: 3 });
                        this.pageNumber = this.pageNumber + 1;

                        this.isLoading = false;
                        console.log('event.target.name', bookingActionName);
                        // -- end moved block --
                    } else {
                        const evt = new ShowToastEvent({
                            title: 'Error!',
                            message: data,
                            variant: 'error',
                            mode: 'dismissable'
                        });
                        this.dispatchEvent(evt);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    console.log(error);
                    this.isLoading = false;
                });
            // Arvind v14.1 - RACE FIX - END
        } else if (event.target.name == 'BLOCKREQUEST') {
            this.showBlockRequestModal = true;
            this.loadblockingHoursOptions();
        } else if (event.target.name == 'BLOCKREQUESTEGYPT') {
            this.showBlockRequestEgyptModal = true;
            //this.validDocumentUploaded();
        } else if (event.target.name == 'BLOCKREQUESTWITHFEES') {
            // Arvind changes for EOI v2.0 - Commented out: availableEOI check removed, no longer needed
            // if (this.availableEOI < this.totalSelectedUnits && this.availableEOI != 0 && !this.isModonEgyptProfile) {
            //     const evt = new ShowToastEvent({
            //         title: 'Error!',
            //         message: 'Number of units selected are more than EOI available for this opportunity.',
            //         variant: 'error',
            //     });
            //     this.dispatchEvent(evt);
            //     return;
            // }

            checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                .then(data => {
                    console.log('data==>', data);
                    if (data == 'Success') {

                    } else {
                        const evt = new ShowToastEvent({
                            title: 'Error!',
                            message: data,
                            variant: 'error',
                            mode: 'dismissable'
                        });
                        this.dispatchEvent(evt);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                });

            this.lastPageName = 'Booking';
            this.selectedAction = event.target.name;
            // Arvind v18.0 (23 Sep 2026) - restore full plan list (no pre-approval filtering here)
            this.applyPaymentPlanFilterAll();
            this.steps = [];
            this.steps.push({ label: 'Unit Selection', value: 1 });
            this.steps.push({ label: 'Payment Selection', value: 2 });
            this.steps.push({ label: 'Book Unit(s)', value: 3 });
            this.pageNumber = this.pageNumber + 1;

            this.isLoading = false;
        }
    }

    rollbackSelectedUnits() {
        this.isLoading = true;
        unblockSelectedUnits({ selectedUnits: this.selectedUnitIds })
            .then(data => {
                console.log('data==>', data);
                this.unitRollbackConfirmation = false;
                this.isLoading = false;
                this.lastPageName = 'Booking';
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            });
        this.pageNumber = this.pageNumber - 1;
        this.unitLst = (this.unitInventoryDetails || []).map(unit => {
            return {
                ...unit,
                totalArea: unit.TotalGrossSellableAreaGSA__c || unit.TotalArea__c,
                isSelected: (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false),
                // Arvind fix - keep null-safe fields in sync with populateUnitData()
                bucketName: unit.Bucket__r ? unit.Bucket__r.Name : '',
                blockedForName: unit.BlockedFor__r ? unit.BlockedFor__r.Name : ''
            }
        });
        //this.isLoading = false;
    }

    closeConfirmationModal() {
        this.unitRollbackConfirmation = false;
    }

    hideModalBox() {
        this.showBlockRequestModal = false;
        this.showBlockRequestEgyptModal = false;
    }

    async handlePDFActive(event) {
        var currentUnit = '';
        currentUnit = event.target.dataset.unitId;
        console.log('this.selectedUnits ==>', this.selectedUnits);
        let currentUnitName = this.selectedUnits[currentUnit].unitName;
        //currentUnitName = currentUnitName.replace(/^bashayer-/i, '');
        let currentProjectName = this.selectedUnits[currentUnit].projectName;
        let unitDPGLink = this.unitURL[currentUnitName];
        console.log('unitUrl for currentUnit', currentUnit, '=>', unitDPGLink);
        var selectedPayment = this.selectedUnits[currentUnit].paymentDetails.selectedPayment;
        var selectedUnitOption = '';
        if (this.selectedUnits[currentUnit].unitOptionDetails !== undefined) {
            selectedUnitOption = this.selectedUnits[currentUnit].unitOptionDetails.selectedUnitOption;
        }
        if (event.target.dataset.targetType == 'input') {
            this.customerName = event.target.value;
        }
        // var mainUrl = 'https://modonproperties--staguat.sandbox.lightning.force.com/';
        // var mainUrl = 'https://modonproperties--nfidorg.sandbox.lightning.force.com/';
        // var mainUrl = 'https://modonproperties--uat--c.sandbox.vf.force.com';
        var mainUrl = orgUrl;
        // Arvind v17.0 (23 Sep 2026) - phase-driven Facade Style wins over the Al Naseem design picker
        const unitFacade  = this.getFacadeStyleForUnit(currentUnit);
        const designParam = unitFacade !== null ? unitFacade : this.selectedDesign;
        if (currentProjectName != 'YAMM' && currentProjectName != 'Ras El Hekma, Egypt' && currentProjectName != 'Ras El Hekma, Egypt(Egypt Only)') {//adding condition for YAMM project and Ras El Hekma project
            // Previous: ... + '&selectedDesign=' + this.selectedDesign + ...
            this.fullUrl = mainUrl + '/apex/OfferDetailsPDF_v1?id=' + this.recordId + '&currentUnit=' + currentUnit + '&selectedPayment=' + selectedPayment + '&customerName=' + this.customerName + '&unitOption=' + selectedUnitOption + '&selectedDesign=' + encodeURIComponent(designParam || '') + '&dpgLink=' + encodeURIComponent(unitDPGLink);
        } else {
            this.fullUrl = mainUrl + '/apex/OfferDetailsPDF?id=' + this.recordId + '&currentUnit=' + currentUnit + '&selectedPayment=' + selectedPayment + '&customerName=' + this.customerName + '&unitOption=' + selectedUnitOption
                         + (unitFacade ? '&selectedDesign=' + encodeURIComponent(unitFacade) : '');
        }
        // Arvind v17.0 - END

        // if (!this.alNaseemSelected) {
        //     // this.fullUrl = mainUrl + '/apex/OfferDetailsPDF?id=' + this.recordId + '&currentUnit=' + currentUnit + '&selectedPayment=' + selectedPayment + '&customerName=' + this.customerName + '&unitOption=' + selectedUnitOption;
        // } else {
        //     // this.fullUrl = mainUrl + '/apex/OfferDetailsPDF_v1?id=' + this.recordId + '&currentUnit=' + currentUnit + '&selectedPayment=' + selectedPayment + '&customerName=' + this.customerName + '&unitOption=' + selectedUnitOption + '&selectedDesign=' + this.selectedDesign + '&dpgLink=' + encodeURIComponent(unitDPGLink);
        // }
        console.log('this.fullUrl', this.fullUrl);
    }

    sendSalesOfferEmail(event) {
        this.isLoading = true;
        var unitId = event.target.dataset.unitId;
        var selectedPayment = this.selectedUnits[unitId].paymentDetails.selectedPayment;
        var selectedUnitOption = '';
        if (this.selectedUnits[this.currentUnit].unitOptionDetails !== undefined) {
            selectedUnitOption = this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption;
        }
        var custName = this.customerName;

        // Arvind v17.0 (23 Sep 2026) - new Apex method passes Facade Style to the PDF.
        // Previous: sendSalesOfferPDF({ ...same params without facadeStyle })
        sendSalesOfferPDFWithFacade({
            unitId: unitId,
            unitName: this.selectedUnits[unitId].unitName,
            opportunityId: this.recordId,
            customerName: custName,
            selectedPymnt: selectedPayment,
            unitOption: selectedUnitOption,
            facadeStyle: this.getFacadeStyleForUnit(unitId) || ''
        })
            .then(data => {

                this.isLoading = false;
                const evt = new ShowToastEvent({
                    title: 'Email Confirmation',
                    message: 'Email have been sent successfully.',
                    variant: 'success',
                });
                this.dispatchEvent(evt);
            })
            .catch(error => {
                console.error(error);
                this.isLoading = false;
                const evt = new ShowToastEvent({
                    title: 'Email Confirmation',
                    message: 'Sending email failed.',
                    variant: 'error',
                });
                this.dispatchEvent(evt);

            });
    }

    handleUnitTypeChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedUnitType = event.detail.value;
        this.populateUnitData();
    }

    handleQualityTypeChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectQuality = event.detail.value;
        this.populateUnitData();
    }

    handleBedroomChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedNoOfBedrooms = event.detail.value;
        this.populateUnitData();
    }

    handleAreaChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedFloorArea = event.detail.value;
        this.populateUnitData();
    }

    handleFloorChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedFloor = event.detail.value;
        this.populateUnitData();
    }
    handleUnitCodeChange(event) {
        this.unitCode = event.target.value?.trim(); // trim spaces
        this.unitLst = undefined;
        this.isLoading = true;

        if (!this.unitCode) {
            // If unit name is cleared, allow optional filters
            this.unitCode = null; // or empty string, as expected by Apex
        }

        this.populateUnitData();
    }
    handleAlNaseemDesignChange(event) {
        this.selectedDesign = event.target.value;
    }
}
class salesOrder {
    constructor(paymentPlan, primaryContact, unitId, customerAccount, price, currencyCode, interior, facadeStyle) {
        this.sobjectType = 'SalesOrder__c';
        this.PaymentPlan__c = paymentPlan;
        this.PrimaryContact__c = primaryContact;
        this.Unit__c = unitId;
        this.TotalAmount__c = price;
        this.CustomerAccount__c = customerAccount;
        this.CurrencyIsoCode = currencyCode;
        this.FitoutPalete__c = interior;
        this.FacadeStyle__c = facadeStyle;
    }
}