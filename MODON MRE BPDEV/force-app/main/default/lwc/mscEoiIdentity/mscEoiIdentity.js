/**
 * EOI journey, step 1: Identify.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  17 Aug 2026  Initial. Project, customer lookup, matches, details.
 * 1.2      Aurelix Dev 21 Sep 2026  Native controls again (21 Sep). Withdrawn: 1.1
 *                                   (c/mscPicklist for project, nationality and country of residence)
 *                                   and the same day's c/mscDatePicker for the five dates, which
 *                                   avoided a grey pop-up that only a Linux desktop shows (SCW-137).
 *
 * Dumb: props in, events out. c/mscEoiJourney owns the state, rules and Apex.
 */

import { LightningElement, api } from "lwc";
import { CUSTOMER_TYPES, RESIDENT_OPTIONS, normalizeResidentStatus, formatEmiratesId, sanitizePassportNumber } from "c/mscEoiUtils";
import { initials } from "c/modonSalesFormat";

const CONTACT_LABEL = { ok: "Verified", checking: "Checking…", bad: "" };

export default class MscEoiIdentity extends LightningElement {
  @api projectOptions = [];
  @api selectedProjectId = "";
  @api projectClosed = false;
  @api projectClosedText = "";
  @api quotaText = "";

  @api customer = {};
  @api lookup = {};
  @api identityVerified = false;
  @api customerSource = "New";
  @api isCustomerEditable = false;
  @api matches = [];
  @api lockedFields = {};
  @api matchMessage = "";
  @api lookupError = "";
  @api contact = {};
  @api nationalityOptions = [];
  @api countryOptions = [];
  @api busy = false;
  @api nextDisabled = false;

  customerTypes = CUSTOMER_TYPES;
  residentOptions = RESIDENT_OPTIONS;

  // derived

  get isOrganization() {
    return this.customer?.customerType === "Organization";
  }
  get isIndividual() {
    return !this.isOrganization;
  }
  get showEmiratesId() {
    return normalizeResidentStatus(this.customer?.residentStatus) === "Resident";
  }
  get isProjectSelected() {
    return Boolean(this.selectedProjectId);
  }
  get lookupDisabled() {
    return !this.isProjectSelected || this.projectClosed || this.busy;
  }
  get showMatchSelection() {
    return (this.matches || []).length > 1;
  }
  get showDetails() {
    return this.identityVerified && !this.showMatchSelection && !this.projectClosed;
  }
  get showLookupHint() {
    return !this.identityVerified && this.isProjectSelected && !this.projectClosed;
  }

  get projectSelectOptions() {
    return (this.projectOptions || []).map((o) => ({ ...o, selected: o.value === this.selectedProjectId }));
  }
  get customerTypeSegments() {
    return this.customerTypes.map((o) => ({
      ...o,
      cls: `seg__btn${o.value === (this.customer?.customerType || "Individual") ? " seg__btn--on" : ""}`,
      pressed: o.value === (this.customer?.customerType || "Individual")
    }));
  }
  get residentSegments() {
    const current = normalizeResidentStatus(this.customer?.residentStatus);
    return this.residentOptions.map((o) => ({
      ...o,
      cls: `seg__btn${o.value === current ? " seg__btn--on" : ""}`,
      pressed: o.value === current
    }));
  }
  get residentDisabled() {
    return this.fieldLocked("residentStatus");
  }
  get nationalitySelectOptions() {
    return (this.nationalityOptions || []).map((o) => ({ ...o, selected: o.value === this.customer?.nationality }));
  }
  get countrySelectOptions() {
    return (this.countryOptions || []).map((o) => ({ ...o, selected: o.value === this.customer?.countryOfResidence }));
  }

  /** Match cards, with initials. */
  get matchCards() {
    return (this.matches || []).map((m) => ({
      ...m,
      avatar: initials(m.displayName),
      chipClass: m.hasPortalUser ? "chip chip--paid" : "chip chip--pending",
      chipLabel: m.hasPortalUser ? "Portal user" : "Existing account"
    }));
  }

  /** Rail: what we know so far. */
  get statusChip() {
    if (!this.identityVerified) return { cls: "chip chip--pending", label: "Not checked" };
    if (this.showMatchSelection) return { cls: "chip chip--due", label: "Choose a match" };
    if (this.customerSource === "Account") return { cls: "chip chip--paid", label: "Existing account" };
    return { cls: "chip chip--partial", label: "New customer" };
  }
  get statusHint() {
    if (!this.isProjectSelected) return "Choose the project first - identity checks and EOI slots are per project.";
    if (this.projectClosed) return this.projectClosedText;
    if (!this.identityVerified) return "Enter any one identifier and run the check. Existing accounts are pre-filled and locked where already known.";
    if (this.showMatchSelection) return this.matchMessage;
    if (this.customerSource === "Account") return "Fields the account already holds are locked. Complete anything missing, then continue.";
    return "No account matched. Complete the details - a lead is created and converted after the customer verifies.";
  }
  get hasLockedFields() {
    return Object.values(this.lockedFields || {}).some(Boolean);
  }

  // per-field disabled flags; locked = the existing account holds it
  fieldLocked(field) {
    if (!this.identityVerified || this.showMatchSelection) return true;
    return !this.isCustomerEditable && Boolean((this.lockedFields || {})[field]);
  }
  get lock() {
    const keys = [
      "firstName", "lastName", "email", "phone", "residentStatus", "emiratesId", "emiratesIdExpiryDate",
      "passportNumber", "passportExpiryDate", "nationality", "countryOfResidence",
      "companyName", "tradeLicenseNumber", "tradeLicenseExpiryDate", "registeredEmail", "registeredPhone",
      "authorizedFirstName", "authorizedLastName", "authorizedEmail", "authorizedPhone"
    ];
    const out = {};
    keys.forEach((k) => {
      out[k] = this.fieldLocked(k);
    });
    return out;
  }

  // contact validation state per key -> class + message
  contactState(key) {
    const c = (this.contact || {})[key] || { status: "idle", message: "" };
    return {
      status: c.status,
      isOk: c.status === "ok",
      isChecking: c.status === "checking",
      isBad: c.status === "bad",
      message: c.message || "",
      label: CONTACT_LABEL[c.status] || "",
      inputClass: `field__input${c.status === "bad" ? " field__input--error" : ""}`
    };
  }
  get lookupEmailState() {
    return this.contactState("lookupEmail");
  }
  get lookupPhoneState() {
    return this.contactState("lookupPhone");
  }
  get customerEmailState() {
    return this.contactState("customerEmail");
  }
  get customerPhoneState() {
    return this.contactState("customerPhone");
  }

  get eidInputClass() {
    const v = this.customer?.emiratesId || "";
    const bad = v && !/^[0-9]{3}-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(v);
    return `field__input${bad ? " field__input--error" : ""}`;
  }
  get eidInvalid() {
    const v = this.customer?.emiratesId || "";
    return Boolean(v) && !/^[0-9]{3}-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(v);
  }

  get passportMark() {
    return this.showEmiratesId ? "" : "*";
  }

  get findLabel() {
    return this.identityVerified ? "Check again" : "Find customer";
  }

  // events

  emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail }));
  }

  handleProject(e) {
    this.emit("projectchange", { value: e.target.value });
  }
  handleCustomerType(e) {
    const value = e.currentTarget.dataset.value;
    if (value && value !== this.customer?.customerType) this.emit("customertype", { value });
  }
  handleResident(e) {
    const value = e.currentTarget.dataset.value;
    if (value) this.emit("fieldchange", { field: "residentStatus", value });
  }
  /* Emirates ID and passport are normalised as typed; rewritten here too because the parent
     does not re-render when the normalised value equals what it holds */
  normaliseInPlace(e) {
    const field = e.target.dataset.field;
    if (field === "emiratesId") e.target.value = formatEmiratesId(e.target.value);
    else if (field === "passportNumber") e.target.value = sanitizePassportNumber(e.target.value);
    return e.target.value;
  }
  handleLookupInput(e) {
    this.emit("lookupchange", { field: e.target.dataset.field, value: this.normaliseInPlace(e) });
  }
  handleFieldInput(e) {
    this.emit("fieldchange", { field: e.target.dataset.field, value: this.normaliseInPlace(e) });
  }
  handleContactBlur(e) {
    const { key, kind } = e.target.dataset;
    this.emit("contactblur", { key, kind, value: e.target.value });
  }
  handleFind() {
    this.emit("find");
  }
  handleClear() {
    this.emit("clearidentity");
  }
  handleSelectMatch(e) {
    this.emit("selectmatch", { recordId: e.currentTarget.dataset.recordId });
  }
  handleNext() {
    this.emit("next");
  }
  handleLookupKey(e) {
    if (e.key === "Enter" && !this.lookupDisabled) {
      e.preventDefault();
      this.emit("find");
    }
  }
}