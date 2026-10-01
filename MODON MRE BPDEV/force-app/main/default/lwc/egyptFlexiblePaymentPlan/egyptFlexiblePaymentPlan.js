/**
* @description       : Lightning Web Component flexible payment plan
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 11-05-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author               Modification
* 1.0   14-04-2026   Milin Kapatel        Initial Version
* 1.1   20-04-2026   Milin Kapatel        Bug fixes + Code optimization
* 1.2   24-04-2026   Milin Kapatel        Exact Booking Date validation
* 1.5   11-05-2026   Milin Kapatel        Standard downpayment benchmarks by currency; DP min/max on inputs
* 1.6   11-05-2026   Milin Kapatel        Pass standard plan context to calculatePaymentPlan (avoids duplicate SOQL)
* 1.7   13-05-2026   Milin Kapatel        Opened up Downpayment % range from 1% to 100% and bug fix for Downpayment Amount lower limit validation
* 1.8   25-05-2026   Milin Kapatel        Pass flexiblePaymentPlanName (computed by Apex) in the flexplanready event detail
* 1.9   02-06-2026   Milin Kapatel        Added isModonOperationProfile to handle exact booking date read only.
* 1.10  04-06-2026   Milin Kapatel        Importing apex from Egypt_FlexiblePaymentPlanController class
* 1.11  09-06-2026   Milin Kapatel        Keeping minimun downpayment amount as it is without adding tolerance (0.01)
**/

import { LightningElement, api } from 'lwc';
import calculatePaymentPlan from '@salesforce/apex/Egypt_FlexiblePaymentPlanController.calculatePaymentPlan';
import getActiveCurrencyIsoCodes from '@salesforce/apex/Egypt_FlexiblePaymentPlanController.getActiveCurrencyIsoCodes';
import getStandardDownpaymentBenchmarksByCurrency from '@salesforce/apex/Egypt_FlexiblePaymentPlanController.getStandardDownpaymentBenchmarksByCurrency';
import { showErrorToast } from 'c/modonEgyptUtilities';
import { CONSTANTS } from './egyptFlexiblePaymentPlanConstants';
import USER_CURRENCY from '@salesforce/i18n/currency';

export default class EgyptFlexiblePaymentPlan extends LightningElement {
  @api unitId;
  @api isModonOperationProfile;
  @api exactBookingDate;

  standardDownpaymentByCurrency = {};

  isLoading = false;
  hasCalculatedPlanDetails = false;

  calculatedPlanDetails = null;

  activeCurrencyIsoCodeList = [];

  flexiblePlanColumns = CONSTANTS.FLEX_PLAN_COLUMNS;

  calculationMethod = CONSTANTS.FLEX_PLAN_METHOD_VALUE_AMOUNT;
  selectedCurrency = USER_CURRENCY;
  selectedFrequency = CONSTANTS.FLEX_PLAN_FREQUENCY_QUARTERLY;
  todayDate = new Date().toISOString().split('T')[0];
  maintenanceStartingInstallmentNumber = 1;
  totalMaintenanceInstallmentCount = 1;
  selectedMaintenancePercentage = CONSTANTS.FLEX_PLAN_NUMBER_10;

  downPaymentMode = CONSTANTS.FLEX_PLAN_DOWN_PAYMENT_MODE_AMOUNT;
  downPaymentPercent;
  downPaymentAmount;
  installmentAmount;
  yearsNumber;
  InstallmentsNumber;

  standardPlanYears = CONSTANTS.FLEX_PLAN_NUMBER_8;
  minStandardInstallmentAmount;
  maxInstallmentsAllowed = CONSTANTS.FLEX_PLAN_NUMBER_32;
  baselineConstraintKey;

  egyptConstants = CONSTANTS;

  get exactBookingDateValue() {
    return this.exactBookingDate || this.todayDate;
  }

  get isExactBookingDateReadOnly() {
    return !this.isModonOperationProfile;
  }

  get methodOptions() {
    return [
      { label: CONSTANTS.FLEX_PLAN_METHOD_LABEL_BY_AMOUNT, value: CONSTANTS.FLEX_PLAN_METHOD_VALUE_AMOUNT },
      { label: CONSTANTS.FLEX_PLAN_METHOD_LABEL_BY_YEARS, value: CONSTANTS.FLEX_PLAN_METHOD_VALUE_YEARS },
      { label: CONSTANTS.FLEX_PLAN_METHOD_LABEL_BY_INSTALLMENTS, value: CONSTANTS.FLEX_PLAN_METHOD_VALUE_INSTALLMENTS },
    ];
  }

  get currencyOptions() {
    return this.activeCurrencyIsoCodeList;
  }

  get frequencyOptions() {
    return CONSTANTS.FLEX_PLAN_FREQUENCY_OPTIONS;
  }

  get maxMaintenanceStartingInstallment() {
    const byFreq = CONSTANTS.FLEX_PLAN_MAINTENANCE_MAX_STARTING_INSTALLMENT_BY_FREQ;
    return byFreq[this.selectedFrequency] ?? 32;
  }

  get maxMaintenanceInstallmentCount() {
    const maxStart = this.maxMaintenanceStartingInstallment;
    const start = Number(this.maintenanceStartingInstallmentNumber);
    if (!Number.isInteger(start) || start < 1 || start > maxStart) {
      return Math.max(1, maxStart);
    }
    return maxStart - start + 1;
  }

  get isDownPaymentPercentMode() {
    return this.downPaymentMode === CONSTANTS.FLEX_PLAN_DOWN_PAYMENT_MODE_PERCENT;
  }

  get isDownPaymentAmountMode() {
    return this.downPaymentMode === CONSTANTS.FLEX_PLAN_DOWN_PAYMENT_MODE_AMOUNT;
  }

  get selectedCurrencyDownpaymentBenchmark() {
    return this.standardDownpaymentByCurrency[this.selectedCurrency];
  }

  get minDownPaymentPercent() {
    const b = this.selectedCurrencyDownpaymentBenchmark;
    if (!b || b.standardDownpaymentPercent == null) {
      return 1;
    }
    const n = Number(b.standardDownpaymentPercent);
    return Number.isFinite(n) ? n : 1;
  }

  get maxDownPaymentPercent() {
    return 100;
  }

  get minDownPaymentAmount() {
    const b = this.selectedCurrencyDownpaymentBenchmark;
    if (!b || b.standardDownpaymentAmount == null) {
      return undefined;
    }
    const n = (Number(b.standardDownpaymentAmount)).toFixed(2);
    return Number.isFinite(n) ? n : undefined;
  }

  get downPaymentAmountLabel() {
    return CONSTANTS.FLEX_PLAN_LABEL_DOWN_PAYMENT_AMOUNT + ' (' + this.selectedCurrency + ')';
  }

  get isAmountMethod() {
    return this.calculationMethod === CONSTANTS.FLEX_PLAN_METHOD_VALUE_AMOUNT;
  }

  get isYearsMethod() {
    return this.calculationMethod === CONSTANTS.FLEX_PLAN_METHOD_VALUE_YEARS;
  }

  get isInstallmentsMethod() {
    return this.calculationMethod === CONSTANTS.FLEX_PLAN_METHOD_VALUE_INSTALLMENTS;
  }

  get unitBasePrice() {
    return this.calculatedPlanDetails?.unitBasePrice;
  }

  get totalPayableAmount() {
    return this.calculatedPlanDetails?.totalPayableAmount;
  }

  get discountAmount() {
    return this.calculatedPlanDetails?.discount;
  }

  get pvValue() {
    return this.calculatedPlanDetails?.pvValue;
  }

  get generatedInstallments() {
    return this.calculatedPlanDetails?.lineItems || [];
  }

  get eachInstallmentAmountLabel() {
    return CONSTANTS.FLEX_PLAN_LABEL_EACH_INSTALLMENT_AMOUNT + ' (' + this.selectedCurrency + ')';
  }

  connectedCallback() {
    getActiveCurrencyIsoCodes()
      .then(data => {
        this.activeCurrencyIsoCodeList = data;
      })
      .catch(error => {
        showErrorToast(
          CONSTANTS.FLEX_PLAN_ERROR_GET_ACTIVE_CURRENCIES_TITLE,
          error.detail?.message || error.message || error || CONSTANTS.FLEX_PLAN_ERROR_FALLBACK_MSG
        );
      });
    this.loadStandardDownpaymentBenchmarks();
  }

  loadStandardDownpaymentBenchmarks() {
    if (!this.unitId) {
      this.standardDownpaymentByCurrency = {};
      return;
    }
    getStandardDownpaymentBenchmarksByCurrency({ unitId: this.unitId })
      .then(rows => {
        const map = {};
        (rows || []).forEach(row => {
          map[row.currencyIsoCode] = row;
        });
        this.standardDownpaymentByCurrency = map;
        this.applyDownpaymentDefaultsFromStandard();
      })
      .catch(error => {
        this.standardDownpaymentByCurrency = {};
        showErrorToast(
          CONSTANTS.FLEX_PLAN_ERROR_LOAD_DP_BENCHMARKS_TITLE,
          error.body?.message || error.message || error || CONSTANTS.FLEX_PLAN_ERROR_FALLBACK_MSG
        );
      });
  }

  applyDownpaymentDefaultsFromStandard() {
    const benchmark = this.selectedCurrencyDownpaymentBenchmark;
    if (!benchmark) {
      if (this.isDownPaymentPercentMode) {
        this.downPaymentPercent = 0;
      } else if (this.isDownPaymentAmountMode) {
        this.downPaymentAmount = 0;
      }
      return;
    }
    if (this.isDownPaymentPercentMode) {
      const val = Number(benchmark.standardDownpaymentPercent);
      if (Number.isFinite(val)) {
        this.downPaymentPercent = String(val);
      }
    } else {
      const val = Number(benchmark.standardDownpaymentAmount);
      if (Number.isFinite(val)) {
        this.downPaymentAmount = val.toFixed(2);
      }
    }
  }

  handleInputChange(event) {
    const field = event.target.name;
    this[field] = event.target.value;
    if (field === 'selectedCurrency' || field === 'downPaymentMode') {
      this.applyDownpaymentDefaultsFromStandard();
    }
    this.hasCalculatedPlanDetails = false;
    this.dispatchDisableProceedBtnEvent();
  }

  async handleGeneratePlan() {
    //v1.2
    if (!this.exactBookingDate) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_MESSAGE);
      return;
    } else if (this.exactBookingDate > this.todayDate) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_MESSAGE);
      return;
    } else if (!this.selectedCurrency) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_CURRENCY_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_CURRENCY_INPUT_MESSAGE);
      return;
    } else if (!this.selectedFrequency) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_FREQUENCY_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_FREQUENCY_INPUT_MESSAGE);
      return;
    } 

    const maxMaintStart = this.maxMaintenanceStartingInstallment;
    const maintStartNum = Number(this.maintenanceStartingInstallmentNumber);
    const isMaintStartValid =
      this.isStrictPositiveInteger(this.maintenanceStartingInstallmentNumber) &&
      maintStartNum >= 1 &&
      maintStartNum <= maxMaintStart;
    if (!isMaintStartValid) {
      showErrorToast(
        CONSTANTS.FLEX_PLAN_ERROR_INVALID_MAINT_START_TITLE,
        CONSTANTS.FLEX_PLAN_ERROR_INVALID_MAINT_START_MESSAGE.replace('{0}', String(maxMaintStart))
      );
      return;
    }

    const maxMaintCountAllowed = maxMaintStart - maintStartNum + 1;
    const maintCountNum = Number(this.totalMaintenanceInstallmentCount);
    const isMaintCountValid =
      this.isStrictPositiveInteger(this.totalMaintenanceInstallmentCount) &&
      maintCountNum >= 1 &&
      maintCountNum <= maxMaintCountAllowed;
    if (!isMaintCountValid) {
      showErrorToast(
        CONSTANTS.FLEX_PLAN_ERROR_INVALID_MAINT_COUNT_TITLE,
        CONSTANTS.FLEX_PLAN_ERROR_INVALID_MAINT_COUNT_MESSAGE.replace('{0}', String(maxMaintCountAllowed))
      );
      return;
    }

    if (this.isDownPaymentPercentMode) {
      const dpPct = parseFloat(this.downPaymentPercent);
      const minPct = 1;
      const maxPct = this.maxDownPaymentPercent;
      if (!this.downPaymentPercent || Number.isNaN(dpPct) || dpPct < minPct || dpPct > maxPct) {
        const msg = this.selectedCurrencyDownpaymentBenchmark
          ? CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_INPUT_RANGE_MESSAGE.replace('{0}', String(minPct)).replace('{1}', String(maxPct))
          : CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_INPUT_MESSAGE;
        showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_INPUT_TITLE, msg);
        return;
      }
    } else if (this.isDownPaymentAmountMode) {
      const dpAmt = parseFloat(this.downPaymentAmount);
      const minAmt = this.minDownPaymentAmount;

      if (!this.downPaymentAmount || Number.isNaN(dpAmt)) {
        showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_MESSAGE);
        return;
      }
      /* Commented as requested by @Anshul for testing of Change payment plan
      if (minAmt != null && Number.isFinite(Number(minAmt)) && dpAmt < Number(minAmt)) {
        showErrorToast(
          CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_TITLE,
          CONSTANTS.FLEX_PLAN_ERROR_INVALID_MIN_DP_AMOUNT_INPUT_MESSAGE.replace('{0}', Number(minAmt).toFixed(2))
            .replace('{1}', this.selectedCurrency)
        );
        return;
      }
      */
      if ((minAmt != null || Number.isFinite(Number(minAmt))) && dpAmt <= 0) {
        showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_MESSAGE);
        return;
      }
    }

    if (this.isAmountMethod && (!this.installmentAmount || this.installmentAmount <= 0)) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_AMOUNT_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_AMOUNT_INPUT_MESSAGE);
      return;
    }
    if (this.isYearsMethod && (!this.yearsNumber || this.yearsNumber <= 0)) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_NUM_OF_YEARS_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_NUM_OF_YEARS_INPUT_MESSAGE);
      return;
    }
    if (this.isInstallmentsMethod && (!this.InstallmentsNumber || this.InstallmentsNumber <= 0)) {
      showErrorToast(CONSTANTS.FLEX_PLAN_ERROR_INVALID_NUM_OF_INSTALL_INPUT_TITLE, CONSTANTS.FLEX_PLAN_ERROR_INVALID_NUM_OF_INSTALL_INPUT_MESSAGE);
      return;
    }

    this.isLoading = true;
    this.hasCalculatedPlanDetails = false;

    try {
      let paymentPlanMode = CONSTANTS.EMPTY_STRING;
      let modeNumValue = 0;

      if (this.isAmountMethod) {
        paymentPlanMode = CONSTANTS.FLEX_PLAN_METHOD_VALUE_AMOUNT;
        modeNumValue = parseFloat(this.installmentAmount);
      } else if (this.isYearsMethod) {
        paymentPlanMode = CONSTANTS.FLEX_PLAN_METHOD_VALUE_YEARS;
        modeNumValue = parseInt(this.yearsNumber, 10);
      } else if (this.isInstallmentsMethod) {
        paymentPlanMode = CONSTANTS.FLEX_PLAN_METHOD_VALUE_INSTALLMENTS;
        modeNumValue = parseInt(this.InstallmentsNumber, 10);
      }

      const downpaymentPctForApex = this.isDownPaymentPercentMode
        ? parseFloat(this.downPaymentPercent)
        : null;
      const downpaymentAmountForApex = this.isDownPaymentAmountMode
        ? parseFloat(this.downPaymentAmount)
        : null;

      const result = await calculatePaymentPlan({
        unitId: this.unitId,
        planType: CONSTANTS.FLEX_PLAN_PLAN_TYPE_FLEXIBLE,
        currencyIsoCode: this.selectedCurrency,
        mode: paymentPlanMode,
        frequency: this.selectedFrequency,
        downpaymentPct: downpaymentPctForApex,
        downpaymentMode: this.downPaymentMode,
        modeValue: modeNumValue,
        exactBookingDate: this.exactBookingDate,
        noOfMaintenanceYears: null,
        maintenancePercentage: parseFloat(this.selectedMaintenancePercentage),
        downpaymentAmount: downpaymentAmountForApex,
        maintenanceStartingInstallmentNumber: maintStartNum,
        totalMaintenanceInstallmentCount: maintCountNum,
        standardPlanContext: this.selectedCurrencyDownpaymentBenchmark || null
      });

      const enrichedLineItems = (result.lineItems || []).map(item => ({
        ...item,
        currency: result.currencyIsoCode,
        pvFactor: Number(Number(item.pvFactor).toFixed(4))
      }));

      // Assign calculatedPlanDetails as one new plain object
      this.calculatedPlanDetails = {
        ...result,
        lineItems: enrichedLineItems
      };

      this.hasCalculatedPlanDetails = true;

      this.dispatchEvent(new CustomEvent(CONSTANTS.FLEX_PLAN_EVENT_FLEX_PLAN_READY, {
        detail: {
          unitId: this.unitId,
          installments: this.calculatedPlanDetails.lineItems,
          flexiblePaymentPlanName: this.calculatedPlanDetails.flexiblePaymentPlanName || '', // v1.8
          summaryData: {
            totalPayableAmount: this.calculatedPlanDetails.totalPayableAmount,
            discountAmount: this.calculatedPlanDetails.discount,
            pvValue: this.calculatedPlanDetails.pvValue,
            currency: this.calculatedPlanDetails.currencyIsoCode,
            exactBookingDate: this.exactBookingDate,
            totalMaintenanceFees: this.calculatedPlanDetails.totalMaintenanceAmount
          }
        }
      }));

    } catch (error) {
      showErrorToast(
        CONSTANTS.FLEX_PLAN_ERROR_TITLE_GENERATE,
        error.body?.message || error.message || error || CONSTANTS.FLEX_PLAN_ERROR_FALLBACK_MSG
      );
      this.dispatchEvent(new CustomEvent(CONSTANTS.FLEX_PLAN_EVENT_PLAN_VALIDATION, {
        detail: { isValid: false, unitId: this.unitId }
      }));
    } finally {
      this.isLoading = false;
    }
  }

  dispatchDisableProceedBtnEvent() {
    this.dispatchEvent(new CustomEvent(CONSTANTS.FLEX_PLAN_EVENT_PROCEED_BUTTON_DISABLE, {
      detail: { unitId: this.unitId }
    }));
  }

  isStrictPositiveInteger(value) {
    if (value === undefined || value === null || value === '') {
      return false;
    }
    const n = Number(value);
    return Number.isFinite(n) && Number.isInteger(n) && n >= 1;
  }
}