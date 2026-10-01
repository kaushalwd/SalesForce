/**
 * Unit virtual tour.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonUnitTour in the PoC org. The URL
 *                                   now comes from the unit record rather than being
 *                                   built from a hardcoded viewer path.
 */

import { LightningElement, api } from "lwc";

/**
 * The world.modon.com walkthrough, in two presentations:
 *
 *   inline    - fills its container, beside the booking form
 *   accordion - a collapsible band for phones, where a permanent 3D frame would
 *               leave no room for the form
 *
 * The PoC built this URL with unitTourUrl(), which pointed every unit at one
 * hardcoded floorplan viewer. That worked when the org had a single project and is
 * wrong here, so the console dropped the helper and reads the unit's own
 * Masterplan_URL__c instead - written by MBP_MasterplanSyncBatch from Oracle.
 *
 * Requires the World_Modon CSP Trusted Site with isApplicableToFrameSrc. Without it
 * the browser blocks the frame and nothing renders.
 */
export default class MscUnitTour extends LightningElement {
  @api unitName;
  /** The unit's own tour URL. Blank on units the batch has not reached. */
  @api tourUrl;
  /** 'inline' | 'accordion' */
  @api mode = "inline";

  @api
  get open() {
    return this._open;
  }
  set open(v) {
    this._open = !!v;
  }
  _open = false;

  connectedCallback() {
    // Inline is always open; the accordion starts closed so the form beneath it
    // has room on a phone.
    if (this.mode !== "accordion") {
      this._open = true;
    }
  }

  get isAccordion() {
    return this.mode === "accordion";
  }

  /**
   * Only build the frame when it is actually visible and there is somewhere to
   * point it. Never mount a hidden iframe - it is a full 3D scene load.
   */
  get showFrame() {
    return this._open && !!this.tourUrl;
  }

  get frameSrc() {
    return this.showFrame ? this.tourUrl : "";
  }

  get frameTitle() {
    return `Virtual tour of unit ${this.unitName || ""}`;
  }

  /** A unit with no tour is normal, not broken - the batch has not reached it. */
  get hasTour() {
    return !!this.tourUrl;
  }

  get emptyText() {
    return this.unitName
      ? "No virtual tour is available for this unit yet."
      : "Select a unit to preview its tour";
  }

  get toggleLabel() {
    return this._open ? "Hide unit tour" : "View unit tour";
  }
  get toggleIcon() {
    return this._open ? "chevron-up" : "chevron-down";
  }
  get frameClass() {
    return this.mode === "accordion"
      ? "tour-frame tour-frame--compact"
      : "tour-frame";
  }

  toggle() {
    this._open = !this._open;
  }
}