/**
* @description       : Lightning Web Component to handle Unit Search functionality and Book/Block Units.
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 23-01-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author               Modification
* 1.0                Monali Dixit         Initial Version
* 2.0   23-01-2026   Milin Kapatel        Added logic of populating Total Amount in 3 currencies EGP, USD and AED for PowerBI reports.
* 3.0   09-02-2026   Milin Kapatel        Added logic to have maintenance fees always calculated based on 8 year payment plan price for MIRE team as per the requirement shared by client.
* 4.0   16-02-2026   Milin Kapatel        Added logic to populate 8 years pp price in the selected currency in Unit_Selling_Price__c to the sales order.
* 5.0   24-02-2026   Mirza Baig           Added logic to populate 8 years pp price of EGP and AED to the sales order.
* 5.1   25-02-2026   Mirza Baig           Removed logic to populate 8 years pp price of AED to the sales order.
* 6.0   28-02-2026   Mirza Baig           Giving the option to select the exact booking date while creating new sales order. Sales order isntallment milestone dates will start from the selected exact booking date.
* 7.0   03-03-2026   Mirza Baig           Added filter to show exact booking date only to sales operation profile
* 8.0   24-03-2026   Milin Kapatel        Code clean up - removed unwanted comments
* 8.1   27-03-2026   Milin Kapatel        Implementation of Flexible payment plan
* 8.2   20-04-2026   Milin Kapatel        Bug fixes
* 8.3   25-05-2026   Milin Kapatel        Capture flexiblePaymentPlanName from flexplanready event and pass it to salesOrder constructor
* 8.4   04-06-2026   Milin Kapatel        Code optimization.
**/
import { LightningElement, track, api, wire } from 'lwc';
import getAllProjects from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getAllProjects';
import getAllPhases from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getAllPhases';
import getUnitDetails from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getUnitDetails';
import saveSalesOrder from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.saveSalesOrder';
import saveSalesOrderWithBlockRequest from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.saveSalesOrderWithBlockRequest';
import checkUnitStatus from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.checkUnitStatus';
import saveBlockedUnits from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.saveBlockedUnits';
import isDocumentValidEgypt from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.isDocumentValidEgypt';
import getUnitTypes from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getUnitTypes';
import getNumberofBedrooms from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getNumberofBedrooms';
import getQualityType from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getQualityType';
import getGFARange from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getGFARange';
import getFloorValues from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getFloorValues';
import getCurrencyIsoCodes from '@salesforce/apex/Modon_Egypt_UnitSearchLwcController.getCurrencyIsoCodes';
import USER_CURRENCY from '@salesforce/i18n/currency';
import { showErrorToast, showSuccessToast } from 'c/modonEgyptUtilities';

//7.0
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id'; // Import current user's ID
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name'; // Import the Profile Name field API name
import { CONSTANTS } from './modonEgyptUnitSearchLwcConstants';
import { MODON_EGYPT_OPERATION_PROFILE } from 'c/modonEgyptConstants';
//end

export default class modonEgyptUnitSearchLwc extends LightningElement {

    @api recordId;

    egyptConstants = CONSTANTS;

    pageNumber = 1;
    isLoading = false;

    //Applied Filter values
    selectedProject = CONSTANTS.EMPTY_STRING;
    selectedPhase = CONSTANTS.EMPTY_STRING;
    selectedUnitType = CONSTANTS.EMPTY_STRING;
    selectQuality = CONSTANTS.EMPTY_STRING;
    selectedNoOfBedrooms = CONSTANTS.EMPTY_STRING;
    selectedFloorArea = CONSTANTS.EMPTY_STRING;
    selectedFloor = CONSTANTS.EMPTY_STRING;
    unitCode = CONSTANTS.EMPTY_STRING;
    filterCurrencyIsoCode = USER_CURRENCY;

    //Filter Lists
    projectList = [];
    phaseList = [];
    unitInventoryDetails = [];
    unitLst = [];
    unitDetails = {};
    bedroomsList = [];
    unitTypeList = [];
    areaList = [];
    floorList = [];
    qualityTypeList = [];
    currencyIsoCodeList = [];


    selectedAction = CONSTANTS.EMPTY_STRING;
    showButton = false;
    blockingHourOptions = [];
    confirmation = false;

    paymentTypeName = CONSTANTS.EMPTY_STRING;
    paymentPlanDiscountPercent = CONSTANTS.EMPTY_STRING;
    MaintenanceFee = CONSTANTS.EMPTY_STRING;
    unitBasePrice = CONSTANTS.EMPTY_STRING;
    @track NumberOfMaintenanceFee = CONSTANTS.EMPTY_STRING;
    paymentInstallments = [];
    selectedCurrencyIsoCode = CONSTANTS.EMPTY_STRING;
    @track currencyCode = CONSTANTS.EMPTY_STRING;

    unitListColumns = [...CONSTANTS.UNIT_SEARCH_UNIT_LIST_COLUMNS];

    paymentInstallmentsColumns = [...CONSTANTS.UNIT_SEARCH_PAYMENT_INSTALLMENTS_COLUMNS];

    selectedBlockingHours = CONSTANTS.EMPTY_STRING;
    showBlockRequestModal = false;
    showBlockRequestEgyptModal = false;
    customerName = CONSTANTS.EMPTY_STRING;
    lastPageName = CONSTANTS.EMPTY_STRING;
    showRequestBlockWithFeesButton = true;

    @track selectedUnits = {};

    unitRollbackConfirmation = false;
    currentUserProfile;
    showRequestBlock = true;
    disableRequestBlock = false;
    blockMessage = CONSTANTS.EMPTY_STRING;
    nationality = CONSTANTS.EMPTY_STRING;

    todayDate = new Date().toISOString().split('T')[0]; //v6.0

    //v7.0
    profileName;

    @track flexiblePlanStatusMap = {};

    // ==================== GETTERS AND SETTERS ================== //
    get isScreenLoading() {
        return this.isLoading;
    }

    //v7.0
    get isModonOperationProfile() {
        return this.profileName === MODON_EGYPT_OPERATION_PROFILE;
    }
    //v9.0
    get planTypeOptions() {
        return [
            { label: CONSTANTS.UNIT_SEARCH_PLAN_LABEL_STANDARD, value: CONSTANTS.UNIT_SEARCH_PLAN_VALUE_STANDARD },
            { label: CONSTANTS.UNIT_SEARCH_PLAN_LABEL_FLEXIBLE, value: CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE }
        ];
    }

    get disableProceed() {
        let isFlexibleSelected = false;
        let allFlexibleValid = true;

        // Iterate through selected units to check their plan types and statuses
        if (this.selectedUnits) {
            for (let key in this.selectedUnits) {
                let unit = this.selectedUnits[key];

                if (unit.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE) {
                    isFlexibleSelected = true;

                    // If the plan is NOT true in our tracking map, it's invalid
                    if (!this.flexiblePlanStatusMap[unit.unitId]) {
                        allFlexibleValid = false;
                        break; // Stop checking further, we know we can't proceed
                    }
                }
            }
        }

        // If at least one flexible plan is selected AND not all of them are valid
        if (isFlexibleSelected && !allFlexibleValid) {
            return true; // Disable the button
        }

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

    get hasNoSelectedUnits() {
        return (this.totalSelectedUnits < 1);
    }

    get selectedUnitList() {
        let unitsToReturn = [];
        for (var key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus) {
                unitsToReturn.push(this.selectedUnits[key]);
            }
        }
        return unitsToReturn;
    }

    get selectedUnitIds() {
        let selectedIds = [];
        for (var key in this.selectedUnits) {
            if (this.selectedUnits[key].selectionStatus) {
                selectedIds.push(key);
            }
        }
        return selectedIds;
    }

    get showBlockingHours() {
        return this.selectedBlockingHours && this.selectedBlockingHours?.length > 0;
    }

    connectedCallback() {
        try {
            this.populateProjects();
            this.populateBedroomsNumberFilter();
            this.populateUnitTypeFilter();
            this.populateFloorAreaFilter();
            this.populateFloorValueFilter();
            this.populateQualityTypeFilter();
            this.populateCurrencyIsoCodeFilter();
        } catch (error) {
            console.error('Error in connectedCallback:', error);
        }
    }

    handleRefresh() {
        this.unitCode = CONSTANTS.EMPTY_STRING;
        this.selectedUnitType = CONSTANTS.EMPTY_STRING;
        this.selectQuality = CONSTANTS.EMPTY_STRING;
        this.selectedNoOfBedrooms = CONSTANTS.EMPTY_STRING;
        this.selectedFloorArea = CONSTANTS.EMPTY_STRING;
        this.selectedFloor = CONSTANTS.EMPTY_STRING;
        this.unitName = CONSTANTS.EMPTY_STRING;
        this.selectedUnits = {};
        this.populateUnitData();
    }

    //v7.0
    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.profileName = data?.fields?.Profile?.value?.fields?.Name?.value;
        } else if (error) {
            this.profileName = undefined;
        }
    }

    // page 1
    // ================= METHODS TO POPULATE FILTER LIST ================ //
    populateProjects() {
        this.isLoading = true;
        getAllProjects({ oppId: this.recordId })
            .then(data => {
                this.projectList = data;
                this.selectedProject = data[0].value;
                if (this.selectedProject) {
                    this.populatePhases();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.projectList = undefined;
                this.isLoading = false;
            });
    }

    populatePhases() {
        getAllPhases({ projectId: this.selectedProject })
            .then(data => {
                this.phaseList = data;
                this.selectedPhase = (data && data[0] && data[0].value) ? data[0].value : CONSTANTS.EMPTY_STRING;
                this.populateUnitData();
                this.isLoading = false;
            })
            .catch(error => {
                this.phaseList = undefined;
                this.isLoading = false;
            });
    }

    async populateUnitData() {
        this.isLoading = true;
        this.unitLst = undefined;

        // Base parameters
        const params = {
            phaseId: this.selectedPhase,
            oppId: this.recordId
        };

        // Removing profile check for filters
        params.unitType = this.selectedUnitType;
        params.qualityType = this.selectQuality;
        params.numberOfBedrooms = this.selectedNoOfBedrooms;
        params.gfaRange = this.selectedFloorArea;
        params.floor = this.selectedFloor;
        params.unitNumber = this.unitCode;
        params.currencyIsoCode = this.filterCurrencyIsoCode;

        await getUnitDetails(params)
            .then(data => {

                let unitInventoryDetails = [];
                let unitLst = [];
                let unitDetails = {};

                data.forEach(item => {
                    item.unitObj.basePriceInCurrency = item.basePrice || 0;
                    item.unitObj.basePriceCurrencyIsoCode = item.basePriceCurrencyIsoCode;
                    unitInventoryDetails.push(item.unitObj);
                });


                this.unitInventoryDetails = [...unitInventoryDetails];


                if (unitInventoryDetails.length == 0) {
                    this.unitLst = undefined;
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_UNITS, CONSTANTS.UNIT_SEARCH_TOAST_MSG_NO_UNITS_FILTER);
                } else {
                    unitLst = (unitInventoryDetails || []).map(unit => {
                        return {
                            ...unit,
                            isSelected: (this.selectedUnits[unit.Id] ? this.selectedUnits[unit.Id].selectionStatus : false)
                        }
                    });

                    this.unitLst = [...unitLst];

                    if (unitLst.length) {
                        for (let i = 0; i < unitLst?.length; i++) {
                            unitDetails[unitLst[i].Id] = unitLst[i];
                        }

                        this.unitDetails = { ...unitDetails };
                    }
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
            });
    }

    populateFloorAreaFilter() {
        getGFARange()
            .then(data => {
                this.areaList = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.areaList = undefined;
                this.isLoading = false;
            });
    }

    populateFloorValueFilter() {
        getFloorValues()
            .then(data => {
                this.floorList = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.floorList = undefined;
                this.isLoading = false;
            });
    }

    populateUnitTypeFilter() {
        getUnitTypes()
            .then(data => {
                this.unitTypeList = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.unitTypeList = undefined;
                this.isLoading = false;
            });
    }

    populateQualityTypeFilter() {
        getQualityType()
            .then(data => {
                this.qualityTypeList = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.qualityTypeList = undefined;
                this.isLoading = false;
            });
    }

    populateBedroomsNumberFilter() {
        getNumberofBedrooms()
            .then(data => {
                this.bedroomsList = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.bedroomsList = undefined;
                this.isLoading = false;
            });
    }

    populateCurrencyIsoCodeFilter() {
        getCurrencyIsoCodes()
            .then(data => {
                this.currencyIsoCodeList = data;
                this.filterCurrencyIsoCode = USER_CURRENCY;
                this.isLoading = false;

            })
            .catch(error => {
                this.currencyIsoCodeList = undefined;
                this.isLoading = false;
            });
    }

    // ==================== FIlTER HANDLERS ================ //
    handleProjectChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedProject = event.detail.value;
        this.populatePhases();
    }

    handlePhaseChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.selectedPhase = event.detail.value;
        this.populateUnitData();
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

    handleCurrencyChange(event) {
        this.unitLst = undefined;
        this.isLoading = true;
        this.filterCurrencyIsoCode = event.detail.value;
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


    handleRowSelect(event) {
        this.isLoading = true;
        // Capture selected rows
        let selectedRows = event.detail.selectedRows;
        let selectedUnits = {};

        if (selectedRows.length > 0) {
            for (let i = 0; i < selectedRows.length; i++) {
                selectedUnits[selectedRows[i].Id] = {
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_SELECTION_STATUS]: true,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_UNIT_ID]: selectedRows[i].Id,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_UNIT_NAME]: selectedRows[i].Name,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PROJECT_ID]: selectedRows[i].Phase__r.Project__c,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PROJECT_NAME]: selectedRows[i].Phase__r.Project__r.Name,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PRICE]: selectedRows[i].basePriceInCurrency,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PHASE_NAME]: selectedRows[i].Phase__r.Name,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PHASE_ID]: selectedRows[i].Phase__c,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_PAYMENT_PLAN_TYPE]: CONSTANTS.UNIT_SEARCH_PLAN_VALUE_STANDARD,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_IS_STANDARD_PLAN]: true,
                    [CONSTANTS.UNIT_SEARCH_SELECTED_UNIT_KEY_IS_FLEXIBLE_PLAN]: false
                };
            }
        }
        this.selectedUnits = { ...selectedUnits };
        this.isLoading = false;
    }


    async handleMenuAction(event) {

        if (event.target.name == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_BACK) {
            this.pageNumber = this.pageNumber - 1;
            this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                return {
                    ...unit,
                    isSelected: (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false)
                }
            });
        } else if (event.target.name == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_FORWARD) {

            this.isLoading = true;
            for (var key in this.selectedUnits) {
                if (this.selectedUnits[key].paymentDetails === undefined && this.selectedUnits[key].selectionStatus) {
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR_BANG, CONSTANTS.UNIT_SEARCH_TOAST_MSG_PAYMENT_PLAN_NOT_SELECTED_PREFIX + this.selectedUnits[key].unitName);
                    this.isLoading = false;
                    return;
                }

            }

            checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                .then(data => {

                    if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {
                        this.pageNumber = this.pageNumber + 1;
                        this.isLoading = false;
                    } else {
                        showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR_BANG, data);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                });


        } else if (event.target.name == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_BOOKING) {


            let showError = false;
            this.selectedUnitIds.forEach(objId => {
                if (this.selectedUnits[objId].price == 0) {
                    showError = true;
                }
            });

            if (showError) {
                showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_UNIT_NO_VALUE, CONSTANTS.UNIT_SEARCH_TOAST_MSG_UNIT_PRICE_ZERO);
                return;
            }

            checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                .then(data => {
                    if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {

                    } else {
                        showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR_BANG, data);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                });

            this.lastPageName = CONSTANTS.UNIT_SEARCH_LAST_PAGE_NAME_BOOKING;
            this.selectedAction = event.target.name;
            this.steps = [];
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_UNIT_SELECTION, value: 1 });
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_PAYMENT_SELECTION, value: 2 });
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_BOOK_UNITS, value: 3 });
            this.pageNumber = this.pageNumber + 1;

            this.isLoading = false;
        }

        else if (event.target.name == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_BLOCK_REQUEST_EGYPT) {
            let showError = false;
            this.selectedUnitIds.forEach(objId => {
                if (this.selectedUnits[objId].price == 0) {
                    showError = true;
                }
            });

            if (showError) {
                showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_UNIT_NO_VALUE, CONSTANTS.UNIT_SEARCH_TOAST_MSG_UNIT_PRICE_ZERO);
                return;
            }
            this.showBlockRequestEgyptModal = true;
        } else if (event.target.name == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_BLOCK_REQUEST_WITH_FEES) {


            let showError = false;
            this.selectedUnitIds.forEach(objId => {
                if (this.selectedUnits[objId].price == 0) {
                    showError = true;
                }
            });

            if (showError) {
                showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_UNIT_NO_VALUE, CONSTANTS.UNIT_SEARCH_TOAST_MSG_UNIT_PRICE_ZERO);
                return;
            }
            checkUnitStatus({ selectedUnits: this.selectedUnitIds })
                .then(data => {
                    if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {

                    } else {
                        showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR_BANG, data);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                });

            this.lastPageName = CONSTANTS.UNIT_SEARCH_LAST_PAGE_NAME_BOOKING;
            this.selectedAction = event.target.name;
            this.steps = [];
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_UNIT_SELECTION, value: 1 });
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_PAYMENT_SELECTION, value: 2 });
            this.steps.push({ label: CONSTANTS.UNIT_SEARCH_STEP_LABEL_BOOK_UNITS, value: 3 });
            this.pageNumber = this.pageNumber + 1;

            this.isLoading = false;
        }
    }

    // page 2


    // Handles the fully generated standard plan data bubbled up from the child
    handleStandardPlanReady(event) {
        const data = event.detail;
        const unitId = data.unitId;

        if (this.selectedUnits[unitId]) {
            // Map all the child's calculations back into the parent's unit tracking object
            this.selectedUnits[unitId] = {
                ...this.selectedUnits[unitId],
                paymentDetails: data.paymentDetails,
                unitPaymentPlanOptions: data.unitPaymentPlanOptions,

                // --- THE MISSING LINE: Save the installments to memory ---
                paymentInstallments: data.paymentInstallments,
                // --------------------------------------------------------

                paymentTypeName: data.paymentTypeName,
                selectedPPCurrency: data.selectedPPCurrency,
                basePrice8YearsEGP: data.basePrice8YearsEGP,
                basePrice8YearsAED: data.basePrice8YearsAED, //v8.4
                basePriceFromMapping: data.basePriceFromMapping,
                basePrice8YearPlan: data.basePrice8YearPlan,
                totalMaintenanceFees: data.totalMaintenanceFees,
                maintenanceCurrency: data.maintenanceCurrency,
                totalEGPPrice: data.totalEGPPrice,
                totalUSDPrice: data.totalUSDPrice,
                totalAEDPrice: data.totalAEDPrice,
                exactBookingDate: data.exactBookingDate
            };

            // Force reactivity so the HTML getters (like selectedUnitList) update
            this.selectedUnits = { ...this.selectedUnits };

            // Update the immediate UI states if this is the active tab
            if (this.currentUnit === unitId) {
                this.paymentInstallments = data.paymentInstallments;
                this.paymentTypeName = data.paymentTypeName;
                this.currencyCode = data.selectedPPCurrency;
            }
        }
    }

    // UPDATED: Handle switching between unit  tabs on 2nd page
    handlePaymentUnitSelect(event) {
        this.currentUnit = event.target.value;
        const unitData = this.selectedUnits[this.currentUnit];

        if (unitData.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE && unitData.customInstallments) {
            this.paymentInstallments = unitData.customInstallments;
            this.currencyCode = unitData.selectedPPCurrency;
            this.paymentTypeName = CONSTANTS.UNIT_SEARCH_PLAN_DISPLAY_FLEXIBLE_PAYMENT;
        } else if (unitData.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_STANDARD && unitData.paymentDetails) {
            // Standard tab switching is now handled by standardplanready event firing on render,
            // or we can just populate the UI from the saved state.
            this.paymentTypeName = unitData.paymentTypeName;
            this.currencyCode = unitData.selectedPPCurrency;
            // Note: The child component will re-fire the 'standardplanready' event when it renders, 
            // naturally updating this.paymentInstallments.
        } else {
            this.paymentInstallments = [];
            this.paymentTypeName = CONSTANTS.EMPTY_STRING;
        }
    }

    // UPDATED: Handle toggling between Standard and Flexible plans
    handlePlanTypeToggle(event) {
        const { unitId, planType } = event.detail;
        this.currentUnit = unitId;

        if (this.selectedUnits[unitId]) {
            this.selectedUnits[unitId].paymentPlanType = planType;
            this.selectedUnits[unitId].isStandardPlan = planType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_STANDARD;
            this.selectedUnits[unitId].isFlexiblePlan = planType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE;

            this.paymentInstallments = [];
            this.paymentTypeName = CONSTANTS.EMPTY_STRING;
            if (planType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_STANDARD) {

                // If we already have saved data from a previous standard selection, restore it immediately.
                if (this.selectedUnits[unitId]?.paymentInstallments) {
                    this.paymentInstallments = this.selectedUnits[unitId].paymentInstallments;
                    this.paymentTypeName = this.selectedUnits[unitId].paymentTypeName;
                    this.currencyCode = this.selectedUnits[unitId].selectedPPCurrency;
                }
            }
            else if (planType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE) {

                // Restore saved flexible data if it exists
                if (this.selectedUnits[unitId].customInstallments) {
                    this.paymentInstallments = this.selectedUnits[unitId].customInstallments;
                    this.paymentTypeName = CONSTANTS.UNIT_SEARCH_PLAN_DISPLAY_FLEXIBLE_PAYMENT;
                    this.currencyCode = this.selectedUnits[unitId].selectedPPCurrency;
                }
            }

            // Trigger reactivity to re-render the UI
            this.selectedUnits = { ...this.selectedUnits };
        }
    }

    //v3.0 calculate maintenance fee based on 8 year plan price
    // UPDATED: Replaces the old 'selectPaymentPlan(event)'

    // Handle the event bubbled up from the child
    handleDisableProceedBtn(event) {
        const unitId = event.detail.unitId;

        if (unitId) {
            this.flexiblePlanStatusMap[unitId] = false;
            this.flexiblePlanStatusMap = { ...this.flexiblePlanStatusMap };
        }

    }

    // NEW: Handle the final flexible plan data from the child component
    // UPDATED: Handle toggling between Standard and Flexible plans
    handleFlexiblePlanReady(event) {
        const { unitId, installments, summaryData, flexiblePaymentPlanName } = event.detail; // v8.3

        if (this.selectedUnits[unitId]) {
            this.selectedUnits[unitId].customInstallments = installments;
            this.selectedUnits[unitId].flexiblePaymentPlanName = flexiblePaymentPlanName || ''; // v8.3
            this.selectedUnits[unitId].paymentTypeName = flexiblePaymentPlanName || CONSTANTS.UNIT_SEARCH_PLAN_DISPLAY_FLEXIBLE_PAYMENT;
            this.selectedUnits[unitId].totalPayableAmount = summaryData.totalPayableAmount;
            this.selectedUnits[unitId].discountAmount = summaryData.discountAmount;
            this.selectedUnits[unitId].pvValue = summaryData.pvValue;
            this.selectedUnits[unitId].selectedPPCurrency = summaryData.currency;
            this.selectedUnits[unitId].isFlexiblePlanValid = true;

            // --- ADD THESE 3 LINES ---
            // Overwrite standard mapping prices so Page 3 HTML displays the Flexible totals
            this.selectedUnits[unitId].basePriceFromMapping = summaryData.totalPayableAmount;
            this.selectedUnits[unitId].totalMaintenanceFees = summaryData.totalMaintenanceFees; // Update this if your Apex calculates a flexible maintenance fee
            this.selectedUnits[unitId].maintenanceCurrency = summaryData.currency;
            this.selectedUnits[unitId].exactBookingDate = summaryData.exactBookingDate;
            // -------------------------


            this.paymentInstallments = installments;
            this.currencyCode = summaryData.currency;
            this.paymentTypeName = CONSTANTS.UNIT_SEARCH_PLAN_DISPLAY_FLEXIBLE_PAYMENT; // Ensure the title updates immediately

            const amount = summaryData.totalPayableAmount;
            if (summaryData.currency === CONSTANTS.UNIT_SEARCH_CURRENCY_AED) this.selectedUnits[unitId].totalAEDPrice = amount;
            if (summaryData.currency === CONSTANTS.UNIT_SEARCH_CURRENCY_USD) this.selectedUnits[unitId].totalUSDPrice = amount;
            if (summaryData.currency === CONSTANTS.UNIT_SEARCH_CURRENCY_EGP) this.selectedUnits[unitId].totalEGPPrice = amount;

            this.selectedUnits = { ...this.selectedUnits };
            this.flexiblePlanStatusMap[unitId] = true;
        }
    }

    // page 3

    // UPDATED: Handle tab switching on Page 3 (Sales Order Summary)
    handleBookingUnitActive(event) {
        this.isLoading = true;
        this.currentUnit = event.target.value;

        const unitData = this.selectedUnits[this.currentUnit];

        this.paymentInstallments = [];
        this.paymentTypeName = CONSTANTS.EMPTY_STRING;
        this.currencyCode = CONSTANTS.EMPTY_STRING;

        // Check if the user validated a Flexible Plan for this unit
        if (unitData.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE && unitData.customInstallments) {
            this.paymentInstallments = unitData.customInstallments;
            this.paymentTypeName = unitData.paymentTypeName;
            this.currencyCode = unitData.selectedPPCurrency;
        } else if (unitData.paymentDetails && unitData.paymentInstallments) {
            this.paymentInstallments = unitData.paymentInstallments;
            this.paymentTypeName = unitData.paymentTypeName;
            this.currencyCode = unitData.selectedPPCurrency;
        }

        this.isLoading = false;
    }

    updateConfirmation(event) {
        this.confirmation = event.target.checked;
        this.isLoading = false;
    }

    generateSalesOrder() {
        this.isLoading = true;
        if (this.validateForm()) {
            this.isLoading = false;
            return;
        }

        checkUnitStatus({ selectedUnits: this.selectedUnitIds })
            .then(data => {
                if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {
                } else {
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR_BANG, data);
                    this.isLoading = false;
                    return;
                }
            })
            .catch(error => {
                this.isLoading = false;
            });

        let salesOrderLst = [];
        for (let i = 0; i < this.selectedUnitList.length; i++) {

            let priceValue = (this.selectedUnitList[i].basePriceFromMapping && this.selectedUnitList[i].basePriceFromMapping > 0) ? this.selectedUnitList[i].basePriceFromMapping : this.selectedUnitList[i].price;
            let totalEGPPrice = this.selectedUnitList[i].totalEGPPrice > 0 ? this.selectedUnitList[i].totalEGPPrice : 0;
            let totalUSDPrice = this.selectedUnitList[i].totalUSDPrice > 0 ? this.selectedUnitList[i].totalUSDPrice : 0;
            let totalAEDPrice = this.selectedUnitList[i].totalAEDPrice > 0 ? this.selectedUnitList[i].totalAEDPrice : 0;

            //v5.0
            //const basePrice8YearsAED = this.selectedUnitList[i].basePrice8YearsAED > 0 ? this.selectedUnitList[i].basePrice8YearsAED : 0; v5.1
            const basePrice8YearsEGP = this.selectedUnitList[i].basePrice8YearsEGP > 0 ? this.selectedUnitList[i].basePrice8YearsEGP : 0;

            const exactBookingDate = this.selectedUnitList[i]?.exactBookingDate || null; //v6.0

            //v4.0 added unit selling price in selected currency to the sales order
            let unitSellingPrice = this.selectedUnitList[i].basePrice8YearPlan > 0 ? this.selectedUnitList[i].basePrice8YearPlan : 0;

            const currentUnitId = this.selectedUnitList[i].unitId;
            const currentUnitData = this.selectedUnits[currentUnitId];

            // --- NEW: LOGIC TO HANDLE STANDARD VS FLEXIBLE PLAN DATA ---
            let paymentPlanId = null;
            let currencyCode = null;
            let customInstallmentsArray = null;

            if (currentUnitData.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE) {
                // If Flexible: Do NOT pass a standard Payment_Plan__c ID. Pass the generated installments instead.
                paymentPlanId = null;
                currencyCode = currentUnitData.selectedPPCurrency;
                customInstallmentsArray = currentUnitData.customInstallments;
            } else {
                // If Standard: Get the selected combobox ID and ignore custom installments
                paymentPlanId = currentUnitData.paymentDetails.selectedPayment;
                currencyCode = currentUnitData?.paymentDetails?.paymentLst?.find(
                    p => p.paymentObj.Id === paymentPlanId
                )?.paymentObj.CurrencyIsoCode || null;
                customInstallmentsArray = null;
            }


            //v4.0 added unit selling price in selected currency to the sales order
            //v5.0
            //v5.1 removed parameter basePrice8YearsAED
            //v6.0 new paramter exactBookingDate
            //v8.3 flexiblePaymentPlanName — only populated for Flexible plans
            const flexiblePaymentPlanName = currentUnitData.paymentPlanType === CONSTANTS.UNIT_SEARCH_PLAN_VALUE_FLEXIBLE
                ? (currentUnitData.flexiblePaymentPlanName || null)
                : null;
            let salesOrderObj = new salesOrder(paymentPlanId, null, this.selectedUnitList[i].unitId, null, priceValue, totalEGPPrice, totalUSDPrice, totalAEDPrice, unitSellingPrice, currencyCode, basePrice8YearsEGP, exactBookingDate, customInstallmentsArray, flexiblePaymentPlanName);
            salesOrderLst.push(salesOrderObj);
        }

        if (this.selectedAction == CONSTANTS.UNIT_SEARCH_BUTTON_NAME_BLOCK_REQUEST_WITH_FEES) {
            saveSalesOrderWithBlockRequest({ salesOrderPayloads: salesOrderLst, oppId: this.recordId })
                .then(data => {
                    if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {
                        showSuccessToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_SUCCESS, CONSTANTS.UNIT_SEARCH_TOAST_MSG_SALES_ORDER_CREATED);
                        window.location.reload();
                    } else {
                        showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR, data);
                    }

                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                });
        } else {
            saveSalesOrder({ salesOrderPayloads: salesOrderLst, oppId: this.recordId })
                .then(data => {
                    if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {
                        showSuccessToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_SUCCESS, CONSTANTS.UNIT_SEARCH_TOAST_MSG_SALES_ORDER_CREATED);
                        window.location.reload();
                    } else {
                        showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR, data);
                    }

                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                });
        }

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


        if (isInvalid) {
            showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR, CONSTANTS.UNIT_SEARCH_TOAST_MSG_REVIEW_ERRORS);
            return true;
        }
        return isInvalid;
    }

    // Block unit

    saveBlockUnitsEgypt() {
        this.isLoading = true;
        
        //Now Blocking Hours will be 24 for both Egypt and Non Egypt Customers.
        this.selectedBlockingHours = CONSTANTS.UNIT_SEARCH_BLOCKING_HOURS_24;
        
        saveBlockedUnits({ selectedUnits: this.selectedUnitIds, opportunityId: this.recordId, commentValue: this.commentValue, blockingHours: this.selectedBlockingHours })
            .then(data => {

                if (data == CONSTANTS.UNIT_SEARCH_APEX_RESPONSE_SUCCESS) {
                    this.showBlockRequestEgyptModal = false;
                    showSuccessToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_SUCCESS, CONSTANTS.UNIT_SEARCH_TOAST_MSG_BLOCK_SUBMITTED);
                } else {
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR, data);
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
            })
    }

    updateCommentValue(event) {
        this.commentValue = event.target.value;
    }

    closeConfirmationModal() {
        this.unitRollbackConfirmation = false;
    }

    hideModalBox() {
        this.showBlockRequestModal = false;
        this.showBlockRequestEgyptModal = false;
    }

    validDocumentUploaded() {
        isDocumentValidEgypt({ opportunityId: this.recordId })
            .then(data => {

                // Check for nationality missing message
                const nationalityError = data.requiredDoc?.find(msg =>
                    msg.includes(CONSTANTS.UNIT_SEARCH_DOC_CHECK_NATIONALITY_REQUIRED_PHRASE)
                );

                if (nationalityError) {
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_MISSING_NATIONALITY, nationalityError);
                    return;
                }

                if (!data.isValid) {
                    showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_MISSING_DOCUMENTS, data.requiredDoc.join(', ') + CONSTANTS.UNIT_SEARCH_TOAST_MSG_DOCS_REQUIRED_SUFFIX);
                } else {
                    this.nationality = data.nationality;
                    this.saveBlockUnitsEgypt();
                }
            })
            .catch((error) => {
                showErrorToast(CONSTANTS.UNIT_SEARCH_TOAST_TITLE_ERROR, CONSTANTS.UNIT_SEARCH_TOAST_MSG_DOC_CHECK_ERROR);
            });
    }

    manageBlockingHours(event) {
        this.selectedBlockingHours = event.target.value;
    }

}


//v4.0 added unit selling price in selected currency to the sales order
//v5.0
//v5.1 removed parameter basePrice8YearsAED
//v6.0 new paramter exactBookingDate
//v8.3 new parameter flexiblePaymentPlanName
class salesOrder {
    constructor(paymentPlan, primaryContact, unitId, customerAccount, price, totalEGPPrice, totalUSDPrice, totalAEDPrice, unitSellingPrice, currencyCode, basePrice8YearsEGP, exactBookingDate, customInstallments, flexiblePaymentPlanName) {
        this.paymentPlan = paymentPlan;
        this.primaryContact = primaryContact;
        this.unit = unitId;
        this.totalAmount = price;
        this.customerAccount = customerAccount;
        this.currencyIsoCode = currencyCode;
        this.totalAmountInEGP = totalEGPPrice;
        this.totalAmountInUSD = totalUSDPrice;
        this.totalAmountInAED = totalAEDPrice;
        this.unitSellingPrice = unitSellingPrice;
        this.basePrice8YEGP = basePrice8YearsEGP;
        this.exactBookingDateEgypt = exactBookingDate;
        this.customInstallments = customInstallments;
        this.flexiblePaymentPlanName = flexiblePaymentPlanName || null; // v8.3
    }
}