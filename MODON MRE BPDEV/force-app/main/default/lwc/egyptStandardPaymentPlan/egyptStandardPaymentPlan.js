/**
* @description       : Lightning Web Component standard payment plan
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 14-04-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author               Modification
* 1.0   14-04-2026   Milin Kapatel        Initial Version
* 1.1   20-04-2026   Milin Kapatel        Bug fixes + Code optimization
* 1.2   24-04-2026   Milin Kapatel        Exact Booking Date validation
* 1.3   24-04-2026   Milin Kapatel        Bug fixes
* 1.4   26-05-2026   Milin Kapatel        Adjusting last installment amount to make it equal to the price mentioned in Unit Payment Plan Mapping.
* 1.5   29-05-2026   Milin Kapatel        import buildSalesOrderInstance from ModonEgypt_StandardPaymentPlanController.
* 1.6   02-06-2026   Milin Kapatel        Added isModonOperationProfile to handle exact booking date read only.
* 1.7   04-06-2026   Milin Kapatel        Importing apex from Egypt_StandardPaymentPlanController class.
**/

import { LightningElement, api, track } from 'lwc';
import { CONSTANTS } from './egyptStandardPaymentPlanConstants';
import buildSalesOrderInstance from '@salesforce/apex/Egypt_StandardPaymentPlanController.buildSalesOrderInstance'; //v1.5
import { showErrorToast } from 'c/modonEgyptUtilities';

export default class EgyptStandardPaymentPlan extends LightningElement {
  @api unitData;
  @api isModonOperationProfile;
  
  egyptConstants = CONSTANTS;
  isLoading = false;
  
  todayDate = new Date().toISOString().split('T')[0];

  standardPlanColumns = CONSTANTS.STANDARD_PLAN_COLUMNS;

  paymentDetails;
  paymentInstallments = [];
  unitPaymentPlanOptions = [];
  paymentTypeName = CONSTANTS.EMPTY_STRING;

  // These are now read directly from the Apex wrapper — no local math needed
  selectedCurrencyIsoCode = CONSTANTS.EMPTY_STRING;
  basePriceFromMapping = 0;
  basePrice8YearPlan = 0;
  basePrice8YearsEGP = 0;
  basePrice8YearsAED = 0; //v1.4
  totalMaintenanceFees = 0;
  totalEGPPrice = 0;
  totalUSDPrice = 0;
  totalAEDPrice = 0;
  exactBookingDate;

  get isExactBookingDateReadOnly() {
    return !this.isModonOperationProfile;
  }

  get isPaymentDetailsAvailable() {
    return this.paymentDetails && this.paymentDetails.availablePaymentPlans;
  }

  connectedCallback() {
    this.exactBookingDate = this.unitData?.exactBookingDate || this.todayDate;

    if (this.unitData && !this.unitData.paymentDetails) {
      this.fetchSalesOrderInstance();
    } else if (this.unitData && this.unitData.paymentDetails) {
      this.restoreState();
    }
  }

  // ── Apex Call ──────────────────────────────────────────────────────────────
  async fetchSalesOrderInstance() {
    this.isLoading = true;
    try {
      const data = await buildSalesOrderInstance({
        selectedUnitId: this.unitData.unitId,
        exactBookingDateStr: this.exactBookingDate
      });

      if (data != null && data.unitPaymentDetailObj?.paymentLst !== undefined) {
        let previousPaymentPlan = this.paymentDetails?.selectedPayment || '';
        this.paymentDetails = data.unitPaymentDetailObj;
        this.unitPaymentPlanOptions = data.unitPaymentPlanOptions || [];

        let selectedPayment = previousPaymentPlan ? previousPaymentPlan : this.paymentDetails.selectedPayment
        this.processPlanSelection(selectedPayment);
      }
    } catch (error) {
      showErrorToast(
        CONSTANTS.STANDARD_PLAN_ERROR_TITLE_GENERATE,
        error.body?.message || error.message || error || CONSTANTS.STANDARD_PLAN_ERROR_FALLBACK_MSG
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ── Restore state when user navigates back ─────────────────────────────────
  restoreState() {
    this.paymentDetails = this.unitData.paymentDetails;
    this.unitPaymentPlanOptions = this.unitData.unitPaymentPlanOptions || [];
    this.processPlanSelection(this.paymentDetails.selectedPayment);
  }

  handlePlanChange(event) {
    this.isLoading = true;
    this.processPlanSelection(event.detail.value);
    this.isLoading = false;
  }

  async handleDateChange(event) {
    //v1.2
    if (event.target.value > this.todayDate) {
      showErrorToast(CONSTANTS.STANDARD_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_TITLE, CONSTANTS.STANDARD_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_MESSAGE);
      return;
    }
    this.exactBookingDate = event.target.value || this.todayDate;
    await this.fetchSalesOrderInstance();
  }

  processPlanSelection(selectedPlanValue) {
    this.paymentDetails = {
      ...this.paymentDetails,
      selectedPayment: selectedPlanValue
    };

    this.paymentTypeName = this.paymentDetails.availablePaymentPlans
      .find(pp => pp.value === selectedPlanValue)?.label || CONSTANTS.EMPTY_STRING;

    const planObj = this.paymentDetails.paymentLst
      .find(p => p.paymentPlanId === selectedPlanValue);

    if (!planObj) return;

    this.selectedCurrencyIsoCode = planObj.paymentPlanCurrency;
    this.basePriceFromMapping = planObj.basePriceFromMapping || 0;
    this.basePrice8YearPlan = planObj.basePrice8YearPlan || 0;
    this.totalMaintenanceFees = planObj.totalMaintenanceFees || 0;
    this.totalEGPPrice = planObj.totalEGPPrice || 0;
    this.totalUSDPrice = planObj.totalUSDPrice || 0;
    this.totalAEDPrice = planObj.totalAEDPrice || 0;

    //v1.4
    this.basePrice8YearsEGP = planObj.basePrice8YearPlanEGP || 0; //v1.4
    this.basePrice8YearsAED = planObj.basePrice8YearPlanAED || 0;

    this.paymentInstallments = (planObj.paymentInstallmentWrappers || []).map(row => ({
      ...row,
      milestoneEgyptPercentText: (row.milestonePercent || 0) + '%',
      currency: row.currencyCode,
    }));

    this.exactBookingDate = this.paymentInstallments[0]?.milestoneDate || this.exactBookingDate;

    this.dispatchUpdate();
  }

  // ── Event to parent ────────────────────────────────────────────────────────
  dispatchUpdate() {
    this.dispatchEvent(new CustomEvent(CONSTANTS.STANDARD_PLAN_EVENT_STD_PLAN_READY, {
      detail: {
        unitId: this.unitData.unitId,
        paymentDetails: this.paymentDetails,
        unitPaymentPlanOptions: this.unitPaymentPlanOptions,
        paymentInstallments: this.paymentInstallments,
        paymentTypeName: this.paymentTypeName,
        selectedPPCurrency: this.selectedCurrencyIsoCode,
        basePrice8YearsEGP: this.basePrice8YearsEGP,
        basePrice8YearsAED: this.basePrice8YearsAED, //v1.4
        basePriceFromMapping: this.basePriceFromMapping,
        basePrice8YearPlan: this.basePrice8YearPlan,
        totalMaintenanceFees: this.totalMaintenanceFees,
        maintenanceCurrency: this.selectedCurrencyIsoCode,
        totalEGPPrice: this.totalEGPPrice,
        totalUSDPrice: this.totalUSDPrice,
        totalAEDPrice: this.totalAEDPrice,
        exactBookingDate: this.exactBookingDate
      }
    }));
  }
}