/**
 * Resident / Non-Resident toggle.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/**
 * Resident / Non-Resident selection (Modon comment 6).
 *
 * Two cards rather than a picklist: this is a routing decision - it changes payment
 * methods, required documents, the KYC path and the validation rules - so each card
 * states what choosing it means. A combobox among fifteen fields hides that.
 *
 * The values are exact and load-bearing: DocumentChecklistController compares raw
 * strings and silently returns an UNFILTERED checklist otherwise. Never pass a
 * KYC_Response__c value here - that object uses 'Resident' / 'International'.
 */
const RESIDENT = "Resident";
const NON_RESIDENT = "Non-Resident";

export default class MscResidencyToggle extends LightningElement {
  @api value;
  @api disabled = false;

  labels = LABELS;

  get options() {
    return [
      {
        key: RESIDENT,
        title: LABELS.RESIDENT,
        hint: LABELS.RESIDENT_HINT,
        selected: this.value === RESIDENT,
        cls: this.value === RESIDENT ? "glass res-card res-card--on" : "glass res-card"
      },
      {
        key: NON_RESIDENT,
        title: LABELS.NON_RESIDENT,
        hint: LABELS.NON_RESIDENT_HINT,
        selected: this.value === NON_RESIDENT,
        cls: this.value === NON_RESIDENT ? "glass res-card res-card--on" : "glass res-card"
      }
    ];
  }

  handleSelect(event) {
    if (this.disabled) return;
    const next = event.currentTarget.dataset.key;
    if (next === this.value) return;
    this.dispatchEvent(new CustomEvent("change", { detail: { value: next } }));
  }
}