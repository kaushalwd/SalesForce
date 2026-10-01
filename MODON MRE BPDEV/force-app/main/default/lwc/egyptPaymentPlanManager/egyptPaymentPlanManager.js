/**
* @description       : Lightning Web Component to handle payment plan type of unit (standard/ flexible)
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 14-04-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author               Modification
* 1.0   14-04-2026   Milin Kapatel        Initial Version
* 1.1   20-04-2026   Milin Kapatel        Bug fixes + Code optimization
* 1.2   25-05-2026   Milin Kapatel        Capture flexiblePaymentPlanName from flexplanready event and pass it to salesOrder constructor
* 1.3   02-06-2026   Milin Kapatel        Code optimized and Pass isModonOperationProfile to flexible payment plan component.
* 1.4   24-06-2026   Milin Kapatel        Commented Flexible Payment Plan code for PROD deployment
**/
import { LightningElement, api } from 'lwc';
import { CONSTANTS } from './egyptPaymentPlanManagerConstants';

export default class EgyptPaymentPlanManager extends LightningElement {
  @api unit; // The full unit object from selectedUnits
  @api isModonOperationProfile;
  @api exactBookingDate;
  @api paymentInstallments;

  egyptConstants = CONSTANTS;

  /* v1.4
  get planTypeOptions() {
    return [
      { label: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_LABEL_STANDARD, value: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_STANDARD },
      { label: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_LABEL_FLEXIBLE, value: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_FLEXIBLE }
    ];
  }
  */

  //v1.4
  get planTypeOptions() {
    return [
      { label: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_LABEL_STANDARD, value: CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_STANDARD }
    ];
  }

  get currentPlanType() {
    return this.unit.paymentPlanType ? this.unit.paymentPlanType : CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_STANDARD;
  }

  get isStandardPlan() {
    return this.currentPlanType === CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_STANDARD;
  }

  get isFlexiblePlan() {
    return this.currentPlanType === CONSTANTS.PAYMENT_PLAN_MANAGER_PLAN_VALUE_FLEXIBLE;
  }

  // Handle Radio Toggle (Standard vs Flexible)
  handlePlanTypeChange(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_TYPE_CHANGE, {
      detail: {
        unitId: this.unit.unitId,
        planType: event.detail.value
      }
    }));
  }

  // --- Events from Standard Component ---
  handlePlanChangeBubble(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_PLAN_CHANGE, { detail: event.detail }));
  }

  handleDateChangeBubble(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_DATE_CHANGE, { detail: event.detail }));
  }

  handleStandardPlanReady(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_STD_PLAN_READY, { detail: event.detail }));
  }

  // --- NEW: Event from Flexible Component ---
  // This catches the 'flexibleplanready' event from Tier 3 and passes it to Tier 1
  handleFlexiblePlanReady(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_FLEX_PLAN_READY, {
      detail: {
        unitId: event.detail.unitId,
        installments: event.detail.installments,
        summaryData: event.detail.summaryData,
        flexiblePaymentPlanName: event.detail.flexiblePaymentPlanName
      }
    }));
  }

  handleDisableProceedBtn(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_PROCEED_BUTTON_DISABLE, {
      detail: event.detail
    }));
  }

  handleFlexibleBookingDateChange(event) {
    this.dispatchEvent(new CustomEvent(CONSTANTS.PAYMENT_PLAN_MANAGER_EVENT_FLEX_BOOKING_DATE_CHANGE, {
      detail: event.detail
    }));
  }
}