/**
 * The EOI creation journey, inside the console's EOI sheet.
 *
 * Version  Author      Date         Detail
 * 1.4      Aurelix Dev 29 Sep 2026  Send link only, as the Sales App's eoiHomeJourney: Details always
 *                                   runs sendLinks; payNow and its Apex import are gone (the server
 *                                   refuses it too). Done card and refusal use the Sales App's words.
 * 1.3      MODON Dev   10 Sep 2026  Authorize-and-capture: the return confirm treats the EOI
 *                                   existing as the result, not the payment being captured. A held
 *                                   payment births the EOI too, so gating on isCaptured left the
 *                                   rep looping on "Check again" for an EOI that already existed.
 *                                   The Done card says whether the money is held or taken.
 * 1.2      Aurelix Dev 02 Sep 2026  MSC-228. Client reversal of MSC-227, same day: EOI deposits
 *                                   are card-only through Checkout, pay-first. The submit routes
 *                                   Online back to payNow (single selection, hosted page) /
 *                                   sendLinks (one link per selection) - no record exists until
 *                                   the payment captures and the materialiser raises the EOI +
 *                                   receipt. Payment type is fixed to Online (cheque, POS and
 *                                   bank transfer are out of the EOI journey), so the details
 *                                   step draws no type segment. createViaModonPay and
 *                                   createOffline stay wired but unreachable, exactly as the
 *                                   Checkout branches were under MSC-227.
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-227. Online now collects through ModonPay: the submit
 *                                   creates the EOI(s) at once (exactly as the offline types
 *                                   do) and the Done card hands over - the reference, the
 *                                   terminal link the org's own MODON_Pay webLink builds, and
 *                                   a Check payment read of the stored receipts. The console
 *                                   reflects what the org holds; it never claims a payment.
 *                                   payNow/sendLinks (Checkout) are no longer reachable from
 *                                   the submit but stay wired, like the legacy hosted-page
 *                                   return (handlePaymentReturn) which still lands here.
 * 1.0      Aurelix IT  17 Aug 2026  Initial. Identify -> Verify -> Details -> Done, the same
 *                                   four steps and the same engine as c/eoiHomeJourney,
 *                                   re-skinned for the console. Replaces mscEoiCreate, which
 *                                   could only raise an offline EOI on an opportunity the
 *                                   rep already had - and could not reach that list anyway.
 *
 * ONE OWNER OF STATE. The three step components are dumb: props in, events out. Every
 * rule, every Apex call and every piece of state is here, so the sequence that guards the
 * commercial side (quota re-check before each write, identity re-check before OTP, OTP
 * before any Lead is created, range/amount from the matrix and never typed) reads top to
 * bottom in one file.
 *
 * FIXES CARRIED IN, relative to the home journey:
 *   - a search hit's "-" placeholders never land in a field (mscEoiUtils.applyMatchToCustomer);
 *   - a verified code is not re-verified on retry, so a failed prepareOpportunity can be
 *     retried without a new OTP;
 *   - Send links remembers which selections already have a link, so a partial failure
 *     retries only the failed ones.
 */

import { LightningElement, api, track, wire } from "lwc";
import { getObjectInfo, getPicklistValuesByRecordType } from "lightning/uiObjectInfoApi";
import LEAD_OBJECT from "@salesforce/schema/Lead";
import { formatAED } from "c/modonSalesFormat";
import {
  OTP_LENGTH,
  VERIFICATION_CONTEXT,
  PAYMENT_TYPES,
  emptyCustomer,
  emptyLookup,
  formatEmiratesId,
  sanitizePassportNumber,
  isValidEmiratesId,
  isValidPhone,
  isValidEmailShape,
  normalizeResidentStatus,
  isDateField,
  normalizeDateValue,
  hasLookupIdentifier,
  buildSearchRequest,
  buildPrepareRequest,
  hasPrepareIdentifier,
  toDisplayMatch,
  buildLockedFields,
  applyMatchToCustomer,
  createEmptySelection,
  resetSelectionCounter,
  phaseOptionsFrom,
  applySelectionChange,
  isSelectionComplete,
  buildEoiRequest,
  buildSelectionPayload,
  reduceError
} from "c/mscEoiUtils";

import getProjects from "@salesforce/apex/SalesConsoleEoiJourneyController.getProjects";
import getEoiRangeMatrix from "@salesforce/apex/SalesConsoleEoiJourneyController.getEoiRangeMatrix";
import validateEoi from "@salesforce/apex/SalesConsoleEoiJourneyController.validateEoi";
import searchCustomer from "@salesforce/apex/SalesConsoleEoiJourneyController.searchCustomer";
import prepareOpportunity from "@salesforce/apex/SalesConsoleEoiJourneyController.prepareOpportunity";
import checkEmail from "@salesforce/apex/SalesConsoleEoiJourneyController.checkEmail";
import checkPhone from "@salesforce/apex/SalesConsoleEoiJourneyController.checkPhone";
import startVerification from "@salesforce/apex/SalesConsoleEoiJourneyController.startVerification";
import resendVerification from "@salesforce/apex/SalesConsoleEoiJourneyController.resendVerification";
import verifyCode from "@salesforce/apex/SalesConsoleEoiJourneyController.verifyCode";
import createEoi from "@salesforce/apex/SalesConsoleEoiJourneyController.createEoi";
import sendPaymentLink from "@salesforce/apex/SalesConsoleEoiJourneyController.sendPaymentLink";
import confirmPayment from "@salesforce/apex/SalesConsoleEoiJourneyController.confirmPayment";
import getModonPayInfo from "@salesforce/apex/SalesConsoleEoiJourneyController.getModonPayInfo";
import getEoiPaymentState from "@salesforce/apex/SalesConsoleEoiJourneyController.getEoiPaymentState";

const STEPS = [
  { n: 1, key: "identify", label: "Identify" },
  { n: 2, key: "verify", label: "Verify" },
  { n: 3, key: "details", label: "Details" },
  { n: 4, key: "done", label: "Done" }
];

const CONTACT_KEYS = ["lookupEmail", "lookupPhone", "customerEmail", "customerPhone"];

function idleContact() {
  return { status: "idle", value: "", message: "" };
}

export default class MscEoiJourney extends LightningElement {
  /** Set by mscEoi when the console is re-entered from the Checkout hosted page. */
  @api paymentReturnResult;
  @api paymentReturnRef;

  // ── Frame ────────────────────────────────────────────────────────────────
  step = 1;
  busy = false;
  busyLabel = "";
  errorMsg = "";
  @track notice = null; // { kind: 'ok'|'warn'|'info', text }
  discardPrompt = false;

  // ── Project + quota ──────────────────────────────────────────────────────
  projectOptions = [];
  selectedProjectId = "";
  selectedProjectName = "";
  matrix = [];
  phaseOptions = [];
  @track quota = { loaded: false, limit: 0, used: 0, remaining: 0, exceeded: false };

  // ── Identity ─────────────────────────────────────────────────────────────
  @track customer = emptyCustomer();
  @track lookup = emptyLookup();
  identityVerified = false;
  customerSource = "New"; // New | Account | Multiple
  isCustomerEditable = true;
  @track matches = [];
  @track lockedFields = {};
  matchMessage = "";
  lookupError = "";
  @track contact = {
    lookupEmail: idleContact(),
    lookupPhone: idleContact(),
    customerEmail: idleContact(),
    customerPhone: idleContact()
  };
  nationalityOptions = [];
  countryOptions = [];

  // ── Prepared records ─────────────────────────────────────────────────────
  opportunityId = null;
  accountId = null;
  contactId = null;

  // ── Verification ─────────────────────────────────────────────────────────
  verificationMethod = "";
  verificationRequestId = null;
  verifiedRequestId = null;
  otpCode = "";
  otpResetToken = 0;
  verificationMessage = "";
  isSendingVerification = false;
  resendCooldownSeconds = 0;
  resendAvailableAt = null;
  maxResendReached = false;
  _cooldownTimer = null;

  // ── Details ──────────────────────────────────────────────────────────────
  @track selections = [];
  activeSelectionKey = "";
  paymentType = "Online"; // MSC-228: card only - the journey never offers another type
  /* 1.4: always a link, as in the Sales App */
  checkoutMethod = "send";
  @track sentLinks = {};
  @track linkErrors = {};

  // ── Done ─────────────────────────────────────────────────────────────────
  @track done = null; // { mode: 'created'|'links'|'pending'|'paid'|'modonpay', eoiId, eoiIds[], references[], accountName, total, paymentType, ref }

  /* MSC-227: the ModonPay handoff. `modonPay` = one row per created EOI (reference +
   * terminal link); `payState` = the stored receipts/statuses read back on demand. */
  @track modonPay = [];
  @track payState = null;
  busyPayCheck = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  connectedCallback() {
    resetSelectionCounter();
    this.selections = [createEmptySelection()];
    this.activeSelectionKey = this.selections[0].key;
    this.loadProjects();
    if (this.paymentReturnResult) {
      this.handlePaymentReturn();
    }
  }

  disconnectedCallback() {
    this.clearCooldownTimer();
  }

  @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
  leadInfo;

  get leadRecordTypeId() {
    return this.leadInfo?.data?.defaultRecordTypeId;
  }

  @wire(getPicklistValuesByRecordType, { objectApiName: LEAD_OBJECT, recordTypeId: "$leadRecordTypeId" })
  wiredLeadPicklists({ data }) {
    if (!data) return;
    this.nationalityOptions = (data.picklistFieldValues?.Nationality__c?.values || []).map((v) => ({ label: v.label, value: v.value }));
    this.countryOptions = (data.picklistFieldValues?.CountryOfResidence__c?.values || []).map((v) => ({ label: v.label, value: v.value }));
  }

  async loadProjects() {
    try {
      this.projectOptions = (await getProjects()) || [];
    } catch (e) {
      this.errorMsg = "Failed to load projects: " + reduceError(e);
    }
  }

  // ── Derived: frame ───────────────────────────────────────────────────────

  get steps() {
    return STEPS.map((s) => {
      const state = s.n < this.step ? "done" : s.n === this.step ? "active" : "future";
      return {
        ...s,
        cls: `stp stp--${state}`,
        isDone: state === "done",
        isActive: state === "active"
      };
    });
  }

  get isIdentify() {
    return this.step === 1;
  }
  get isVerify() {
    return this.step === 2;
  }
  get isDetails() {
    return this.step === 3;
  }
  get isDone() {
    return this.step === 4;
  }
  get stepTitle() {
    return STEPS[this.step - 1]?.label || "";
  }

  get noticeClass() {
    const kind = this.notice?.kind || "info";
    return `banner banner--${kind === "info" ? "warn" : kind} jn__banner`;
  }
  get noticeIcon() {
    const kind = this.notice?.kind;
    return kind === "ok" ? "check-circle" : kind === "warn" ? "alert-triangle" : "info";
  }

  get isOrganization() {
    return this.customer.customerType === "Organization";
  }
  get showEmiratesId() {
    return normalizeResidentStatus(this.customer.residentStatus) === "Resident";
  }
  get isProjectSelected() {
    return Boolean(this.selectedProjectId);
  }
  get isProjectClosed() {
    return this.quota.loaded && this.quota.exceeded;
  }
  get quotaText() {
    if (!this.quota.loaded || !this.quota.limit) return "";
    return `${Math.max(0, this.quota.remaining)} of ${this.quota.limit} EOI slots remaining`;
  }
  get projectClosedText() {
    return `EOI submissions are closed for ${this.selectedProjectName || "this project"}. No new EOIs are being accepted.`;
  }
  get showMatchSelection() {
    return this.matches.length > 1;
  }

  /** Back is meaningful only on Verify (before it completes) and Details before it is prepared. */
  get canGoBack() {
    if (this.busy) return false;
    if (this.step === 2) return true;
    return false;
  }

  /** Discard guard: anything past the first, untouched screen is worth a prompt. */
  get hasProgress() {
    return this.step > 1 || this.identityVerified || Boolean(this.selectedProjectId);
  }

  // ── Derived: identify gating (mirrors eoiHomeJourney.isCustomerNextDisabled) ─

  get identityNextDisabled() {
    if (this.busy || !this.identityVerified || this.showMatchSelection || !this.selectedProjectId || this.isProjectClosed) return true;
    if (this.isCheckingContact) return true;
    const c = this.customer;
    const eidMissing = this.showEmiratesId && !c.emiratesId;
    const eidInvalid = this.showEmiratesId && Boolean(c.emiratesId) && !isValidEmiratesId(c.emiratesId);
    const passportMissing = !this.showEmiratesId && !c.passportNumber;
    // Loqate: an account's own email/phone are marked accepted when applied; anything the rep
    // types (or edits) has to pass. So the same rule serves new and existing customers.
    const contactsOk = this.contact.customerEmail.status === "ok" && this.contact.customerPhone.status === "ok";
    if (this.isOrganization) {
      return (
        !c.companyName ||
        !c.tradeLicenseNumber ||
        eidMissing ||
        eidInvalid ||
        passportMissing ||
        !c.authorizedFirstName ||
        !c.authorizedLastName ||
        !c.authorizedEmail ||
        !c.authorizedPhone ||
        !contactsOk
      );
    }
    return (
      !c.firstName ||
      !c.lastName ||
      !c.email ||
      !c.phone ||
      !c.nationality ||
      !c.countryOfResidence ||
      eidMissing ||
      eidInvalid ||
      passportMissing ||
      !contactsOk
    );
  }

  get isCheckingContact() {
    return CONTACT_KEYS.some((k) => this.contact[k].status === "checking");
  }

  // ── Derived: verify ──────────────────────────────────────────────────────

  get verificationEmailTarget() {
    return this.isOrganization ? this.customer.authorizedEmail : this.customer.email;
  }
  get verificationPhoneTarget() {
    return this.isOrganization ? this.customer.authorizedPhone : this.customer.phone;
  }
  get verifyNextDisabled() {
    return this.busy || this.isSendingVerification || !this.verificationRequestId || !this.verificationMethod || this.otpCode.length !== OTP_LENGTH;
  }
  get isVerified() {
    return Boolean(this.verifiedRequestId) && this.verifiedRequestId === this.verificationRequestId;
  }

  // ── Derived: details ─────────────────────────────────────────────────────

  get paymentTypeOptions() {
    /* MSC-228: card only. One option means the details step draws no type segment at all;
     * the offline types stay in PAYMENT_TYPES for the dormant createOffline branch. */
    return PAYMENT_TYPES.filter((t) => t.value === "Online");
  }
  get isOnline() {
    return this.paymentType === "Online";
  }
  get isSingleSelection() {
    return this.selections.length === 1;
  }
  /* 1.4: eoiHomeJourney's effectiveCheckoutMethod is always 'send' */
  get effectiveCheckoutMethod() {
    return "send";
  }
  get selectionsComplete() {
    return this.selections.length > 0 && this.selections.every(isSelectionComplete);
  }
  get totalAmount() {
    return this.selections.reduce((sum, s) => sum + (Number(s.eoiAmount) || 0), 0);
  }
  get totalAmountLabel() {
    return formatAED(this.totalAmount);
  }
  get hasQuotaCountError() {
    return this.quota.loaded && this.quota.limit > 0 && this.selections.length > this.quota.remaining;
  }
  get quotaCountErrorText() {
    return `Only ${Math.max(0, this.quota.remaining)} EOI submission(s) remaining for this project.`;
  }
  get addSelectionDisabled() {
    return this.busy || this.isProjectClosed || this.hasQuotaCountError || (this.quota.loaded && this.quota.limit > 0 && this.selections.length >= this.quota.remaining);
  }
  get detailsSubmitDisabled() {
    return this.busy || !this.opportunityId || !this.selectedProjectId || !this.paymentType || !this.selectionsComplete || this.hasQuotaCountError || this.isProjectClosed;
  }
  get pendingLinkSelections() {
    return this.selections.filter((s) => !this.sentLinks[s.key]);
  }

  // ── Frame events ─────────────────────────────────────────────────────────

  handleExitRequest() {
    if (this.hasProgress && this.step < 4) {
      this.discardPrompt = true;
      return;
    }
    this.exit();
  }
  handleDiscardCancel() {
    this.discardPrompt = false;
  }
  handleDiscardConfirm() {
    this.discardPrompt = false;
    this.exit();
  }
  exit() {
    this.clearCooldownTimer();
    this.dispatchEvent(new CustomEvent("exit"));
  }

  handleBack() {
    if (!this.canGoBack) return;
    this.errorMsg = "";
    this.step = Math.max(1, this.step - 1);
  }

  handleDismissNotice() {
    this.notice = null;
  }

  // ── Project ──────────────────────────────────────────────────────────────

  async handleProjectChange(event) {
    const projectId = event.detail?.value || "";
    this.selectedProjectId = projectId;
    this.selectedProjectName = this.projectOptions.find((o) => o.value === projectId)?.label || "";
    this.matrix = [];
    this.phaseOptions = [];
    this.resetSelections();
    this.quota = { loaded: false, limit: 0, used: 0, remaining: 0, exceeded: false };
    this.clearIdentityResult();
    if (!projectId) return;
    this.busy = true;
    this.busyLabel = "Loading project";
    try {
      this.matrix = (await getEoiRangeMatrix({ projectId })) || [];
      this.phaseOptions = phaseOptionsFrom(this.matrix);
      await this.runQuotaCheck();
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  async runQuotaCheck() {
    if (!this.selectedProjectId) return;
    const r = await validateEoi({ projectId: this.selectedProjectId });
    this.quota = {
      loaded: true,
      limit: r?.quotaLimit || 0,
      used: r?.quotaUsed || 0,
      remaining: r?.quotaRemaining || 0,
      exceeded: Boolean(r?.quotaExceeded)
    };
  }

  // ── Identify events ──────────────────────────────────────────────────────

  handleCustomerType(event) {
    const customerType = event.detail?.value || "Individual";
    this.customer = { ...emptyCustomer(customerType) };
    this.lookup = emptyLookup();
    this.clearIdentityResult();
    this.resetAllContact();
  }

  handleLookupChange(event) {
    const { field, value: raw } = event.detail || {};
    if (!field) return;
    const value = field === "emiratesId" ? formatEmiratesId(raw) : field === "passportNumber" ? sanitizePassportNumber(raw) : raw || "";
    if ((this.lookup[field] || "") === value) return;
    this.lookup = { ...this.lookup, [field]: value };
    if (field === "email" || field === "registeredEmail") this.resetContact("lookupEmail");
    if (field === "phone" || field === "registeredPhone") this.resetContact("lookupPhone");
    this.lookupError = "";
    this.clearIdentityResult();
  }

  handleFieldChange(event) {
    const { field, value: raw } = event.detail || {};
    if (!field) return;
    let value = raw || "";
    if (field === "residentStatus") value = normalizeResidentStatus(raw);
    else if (field === "emiratesId") value = formatEmiratesId(raw);
    else if (field === "passportNumber") value = sanitizePassportNumber(raw);
    else if (isDateField(field)) value = normalizeDateValue(raw) || "";
    if ((this.customer[field] || "") === value) return;
    let next = { ...this.customer, [field]: value };
    if (field === "residentStatus" && value !== "Resident") {
      next = { ...next, emiratesId: "", emiratesIdExpiryDate: "" };
    }
    this.customer = next;
    if (field === "email" || field === "authorizedEmail") this.resetContact("customerEmail");
    if (field === "phone" || field === "authorizedPhone") this.resetContact("customerPhone");
    this.clearPreparedOpportunity();
  }

  /** On blur of any email/phone input: shape check locally, then Loqate through the facade. */
  async handleContactBlur(event) {
    const { key, kind, value } = event.detail || {};
    if (!key || !kind) return;
    const required = key === "customerEmail" || key === "customerPhone";
    await this.validateContact(key, kind, value, !required);
  }

  async validateContact(key, kind, rawValue, allowBlank) {
    const value = (rawValue || "").trim();
    const current = this.contact[key];
    if (!value) {
      this.setContact(key, { status: allowBlank ? "idle" : "bad", value: "", message: allowBlank ? "" : kind === "email" ? "Please enter an email address." : "Please enter a phone number." });
      return allowBlank;
    }
    if (kind === "email" && !isValidEmailShape(value)) {
      this.setContact(key, { status: "bad", value, message: "Please enter a valid email address." });
      return false;
    }
    if (kind === "phone" && !isValidPhone(value)) {
      this.setContact(key, { status: "bad", value, message: "Phone must start with + and contain digits only (e.g. +971501234567)." });
      return false;
    }
    if (current.value === value && (current.status === "ok" || current.status === "bad")) {
      return current.status === "ok";
    }
    this.setContact(key, { status: "checking", value, message: "" });
    try {
      const res = kind === "email" ? await checkEmail({ email: value }) : await checkPhone({ phone: value });
      const ok = Boolean(res?.isValid);
      this.setContact(key, { status: ok ? "ok" : "bad", value, message: ok ? "" : res?.message || (kind === "email" ? "Please enter a valid email address." : "Please enter a valid mobile number.") });
      return ok;
    } catch (e) {
      this.setContact(key, { status: "bad", value, message: kind === "email" ? "Unable to validate the email address." : "Unable to validate the phone number." });
      return false;
    }
  }

  setContact(key, patch) {
    this.contact = { ...this.contact, [key]: { ...this.contact[key], ...patch } };
  }
  resetContact(key) {
    this.setContact(key, idleContact());
  }
  resetAllContact() {
    CONTACT_KEYS.forEach((k) => this.resetContact(k));
  }

  /** Before a search / next: make sure the given contact keys are validated for their current values. */
  async ensureContactsValid(keys, allowBlank) {
    for (const key of keys) {
      const kind = key.endsWith("Email") ? "email" : "phone";
      const value = this.contactValueFor(key);
      // eslint-disable-next-line no-await-in-loop
      const ok = await this.validateContact(key, kind, value, allowBlank);
      if (!ok) return false;
    }
    return true;
  }

  contactValueFor(key) {
    const org = this.isOrganization;
    if (key === "lookupEmail") return org ? this.lookup.registeredEmail : this.lookup.email;
    if (key === "lookupPhone") return org ? this.lookup.registeredPhone : this.lookup.phone;
    if (key === "customerEmail") return org ? this.customer.authorizedEmail : this.customer.email;
    if (key === "customerPhone") return org ? this.customer.authorizedPhone : this.customer.phone;
    return "";
  }

  async handleFind() {
    this.errorMsg = "";
    this.lookupError = "";
    this.matchMessage = "";
    this.matches = [];
    this.clearPreparedOpportunity();
    if (!hasLookupIdentifier(this.lookup, this.isOrganization)) {
      this.lookupError = this.isOrganization
        ? "Enter at least one identifier: company name, trade licence, registered phone or registered email."
        : "Enter at least one identifier: Emirates ID, passport number, phone number or email address.";
      return;
    }
    if (!(await this.ensureContactsValid(["lookupEmail", "lookupPhone"], true))) return;
    this.busy = true;
    this.busyLabel = "Checking identity";
    try {
      const request = buildSearchRequest(this.customer, this.lookup, this.isOrganization);
      const result = await searchCustomer({ request });
      this.identityVerified = true;
      this.applySearchResult(result);
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  applySearchResult(result) {
    const accountMatches = (result?.matches || []).filter((m) => m.sourceType === "Account").map(toDisplayMatch);
    if (accountMatches.length > 1) {
      this.matches = accountMatches;
      this.customerSource = "Multiple";
      this.isCustomerEditable = false;
      this.customer = emptyCustomer(this.customer.customerType);
      this.lockedFields = {};
      this.matchMessage = `${accountMatches.length} matching accounts found. Select the correct customer to continue.`;
      return;
    }
    this.customerSource = result?.sourceType || "New";
    this.isCustomerEditable = result?.isEditable !== false;
    if (result?.selected) {
      this.applyMatch(result.selected);
      return;
    }
    // New customer: seed the form from what the rep looked up.
    const l = this.lookup;
    this.customer = this.isOrganization
      ? { ...this.customer, accountId: null, leadId: null, contactId: null, companyName: l.companyName || this.customer.companyName, tradeLicenseNumber: l.tradeLicenseNumber || this.customer.tradeLicenseNumber, registeredEmail: l.registeredEmail || this.customer.registeredEmail, registeredPhone: l.registeredPhone || this.customer.registeredPhone }
      : { ...this.customer, accountId: null, leadId: null, contactId: null, email: l.email || this.customer.email, phone: l.phone || this.customer.phone, emiratesId: l.emiratesId || this.customer.emiratesId, passportNumber: sanitizePassportNumber(l.passportNumber || this.customer.passportNumber) };
    this.lockedFields = {};
    this.syncCustomerContactFromLookup();
    this.matchMessage = "No existing account found. A new customer record will be created and converted.";
  }

  /** A lookup email/phone that Loqate already accepted does not need checking again as the customer's. */
  syncCustomerContactFromLookup() {
    if (this.isOrganization) return;
    const le = (this.lookup.email || "").trim();
    const lp = (this.lookup.phone || "").trim();
    if (le && le === (this.customer.email || "").trim() && this.contact.lookupEmail.status === "ok") {
      this.setContact("customerEmail", { status: "ok", value: le, message: "" });
    }
    if (lp && lp === (this.customer.phone || "").trim() && this.contact.lookupPhone.status === "ok") {
      this.setContact("customerPhone", { status: "ok", value: lp, message: "" });
    }
  }

  handleSelectMatch(event) {
    const recordId = event.detail?.recordId;
    const selected = this.matches.find((m) => m.recordId === recordId);
    if (!selected) return;
    this.matches = [];
    this.customerSource = selected.sourceType;
    this.isCustomerEditable = selected.sourceType === "Lead";
    this.applyMatch(selected.raw);
  }

  applyMatch(rawMatch) {
    const isOrg = rawMatch.accountType === "Organization";
    this.customer = applyMatchToCustomer(this.customer, rawMatch);
    this.lockedFields = rawMatch.sourceType === "Account" ? buildLockedFields(rawMatch, isOrg) : {};
    this.matchMessage =
      rawMatch.sourceType === "Account"
        ? rawMatch.hasPortalUser
          ? "Existing portal customer selected."
          : "Existing account selected. Fill in anything that is missing."
        : "Existing lead found. Details can be updated before conversion.";
    // The account's own email/phone were not typed by the rep; treat them as accepted.
    const email = this.isOrganization ? this.customer.authorizedEmail : this.customer.email;
    const phone = this.isOrganization ? this.customer.authorizedPhone : this.customer.phone;
    if (email) this.setContact("customerEmail", { status: "ok", value: email, message: "" });
    if (phone && isValidPhone(phone)) this.setContact("customerPhone", { status: "ok", value: phone, message: "" });
  }

  handleClearIdentity() {
    this.errorMsg = "";
    this.lookupError = "";
    this.lookup = emptyLookup();
    this.customer = emptyCustomer(this.customer.customerType);
    this.clearIdentityResult();
    this.resetAllContact();
  }

  clearIdentityResult() {
    this.identityVerified = false;
    this.matchMessage = "";
    this.matches = [];
    this.customerSource = "New";
    this.isCustomerEditable = true;
    this.lockedFields = {};
    this.customer = emptyCustomer(this.customer.customerType);
    this.resetContact("customerEmail");
    this.resetContact("customerPhone");
    this.clearPreparedOpportunity();
  }

  clearPreparedOpportunity() {
    this.opportunityId = null;
    this.accountId = null;
    this.contactId = null;
  }

  async handleIdentityNext() {
    this.errorMsg = "";
    if (this.identityNextDisabled) return;
    if (!(await this.ensureContactsValid(["customerEmail", "customerPhone"], false))) return;
    this.busy = true;
    this.busyLabel = "Checking details";
    try {
      await this.runQuotaCheck();
      if (this.isProjectClosed) return;
      if (await this.recheckBeforeVerification()) return;
      this.resetVerification();
      this.step = 2;
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  /** The final details may now match an account the first lookup did not - re-check before any OTP is sent. */
  async recheckBeforeVerification() {
    if (this.customer.accountId || this.customerSource === "Account" || this.customerSource === "Multiple") return false;
    const request = buildPrepareRequest(this.customer, this.selectedProjectId, this.selectedProjectName, this.isOrganization, this.showEmiratesId);
    if (!hasPrepareIdentifier(request, this.isOrganization)) return false;
    const result = await searchCustomer({ request });
    const accountMatches = (result?.matches || []).filter((m) => m.sourceType === "Account").map(toDisplayMatch);
    if (!accountMatches.length) return false;
    this.clearPreparedOpportunity();
    if (accountMatches.length > 1) {
      this.matches = accountMatches;
      this.customerSource = "Multiple";
      this.isCustomerEditable = false;
      this.matchMessage = `${accountMatches.length} matching accounts found from the final details. Select the correct customer to continue.`;
      this.notice = { kind: "warn", text: "Existing customer accounts match the entered details. Please select the correct account." };
      return true;
    }
    this.matches = [];
    this.customerSource = "Account";
    this.isCustomerEditable = false;
    this.applyMatch(accountMatches[0].raw);
    this.notice = { kind: "warn", text: "An existing customer account matches the entered details. The journey has switched to that account." };
    return true;
  }

  // ── Verify ───────────────────────────────────────────────────────────────

  resetVerification() {
    this.clearCooldownTimer();
    this.verificationMethod = "";
    this.verificationRequestId = null;
    this.verifiedRequestId = null;
    this.otpCode = "";
    this.otpResetToken += 1;
    this.verificationMessage = "";
    this.isSendingVerification = false;
    this.resendCooldownSeconds = 0;
    this.resendAvailableAt = null;
    this.maxResendReached = false;
  }

  async handleSendCode(event) {
    const method = event.detail?.method;
    if (method === "whatsapp") {
      this.errorMsg = "WhatsApp verification is not configured yet. Please use Email or SMS.";
      return;
    }
    await this.sendVerificationCode(method, false);
  }

  async sendVerificationCode(method, isResend) {
    this.errorMsg = "";
    const normalized = method === "sms" ? "sms" : "email";
    const channel = normalized === "sms" ? "SMS" : "Email";
    const target = normalized === "sms" ? this.verificationPhoneTarget : this.verificationEmailTarget;
    if (!target) {
      this.errorMsg = normalized === "sms" ? "A customer phone number is required for SMS verification." : "A customer email is required for email verification.";
      return;
    }
    this.verificationMethod = normalized;
    this.verifiedRequestId = null;
    this.otpCode = "";
    this.otpResetToken += 1;
    this.verificationMessage = isResend ? "Sending a new verification code…" : "Sending verification code…";
    this.isSendingVerification = true;
    try {
      const request = { channel, target, context: VERIFICATION_CONTEXT, contextKey: this.selectedProjectId || null };
      const result = await startVerification({ request });
      this.verificationRequestId = result?.verificationRequestId || null;
      this.maxResendReached = false;
      const destination = normalized === "sms" ? "mobile number" : "email";
      this.verificationMessage = isResend ? `A new 6-digit code has been sent to the customer's ${destination}.` : result?.message || `A 6-digit code has been sent to the customer's ${destination}.`;
      this.startCooldown(result?.resendAvailableAt);
    } catch (e) {
      this.errorMsg = reduceError(e);
      this.verificationMessage = "";
    } finally {
      this.isSendingVerification = false;
    }
  }

  async handleResend() {
    if (!this.verificationRequestId) {
      await this.sendVerificationCode(this.verificationMethod || "email", false);
      return;
    }
    this.errorMsg = "";
    this.isSendingVerification = true;
    try {
      const result = await resendVerification({ verificationRequestId: this.verificationRequestId });
      this.verifiedRequestId = null;
      this.otpCode = "";
      this.otpResetToken += 1;
      this.verificationMessage = result?.message || "A new 6-digit code has been sent.";
      this.startCooldown(result?.resendAvailableAt);
      this.maxResendReached = false;
    } catch (e) {
      const message = reduceError(e);
      this.errorMsg = message;
      if (message && message.toLowerCase().includes("maximum resend count reached")) {
        this.maxResendReached = true;
        this.verificationMessage = "Maximum resend attempts reached. Use the latest code received, or choose a channel again to restart.";
      }
    } finally {
      this.isSendingVerification = false;
    }
  }

  handleOtpChange(event) {
    this.otpCode = (event.detail?.code || "").replace(/\D/g, "").slice(0, OTP_LENGTH);
    if (this.errorMsg) this.errorMsg = "";
  }

  async handleVerifyNext() {
    this.errorMsg = "";
    if (this.opportunityId) {
      this.step = 3;
      return;
    }
    if (this.verifyNextDisabled) return;
    this.busy = true;
    this.busyLabel = this.isVerified ? "Preparing customer" : "Verifying code";
    try {
      if (!this.isVerified) {
        const result = await verifyCode({ verificationRequestId: this.verificationRequestId, code: this.otpCode });
        if (!result || result.status !== "Verified") {
          throw new Error(result?.message || "Verification was not completed.");
        }
        this.verifiedRequestId = this.verificationRequestId;
        this.clearCooldownTimer();
      }
      this.busyLabel = "Preparing customer";
      await this.runQuotaCheck();
      if (this.isProjectClosed) return;
      const request = buildPrepareRequest(this.customer, this.selectedProjectId, this.selectedProjectName, this.isOrganization, this.showEmiratesId);
      const result = await prepareOpportunity({ request });
      this.opportunityId = result?.opportunityId || null;
      this.accountId = result?.accountId || null;
      this.contactId = result?.contactId || null;
      if (!this.opportunityId) throw new Error("The opportunity could not be prepared.");
      this.step = 3;
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  startCooldown(resendAvailableAt) {
    this.clearCooldownTimer();
    this.resendAvailableAt = resendAvailableAt || null;
    this.updateCooldown();
    if (this.resendCooldownSeconds <= 0) return;
    this._cooldownTimer = window.setInterval(() => {
      this.updateCooldown();
      if (this.resendCooldownSeconds <= 0) this.clearCooldownTimer();
    }, 1000);
  }
  updateCooldown() {
    if (!this.resendAvailableAt) {
      this.resendCooldownSeconds = 0;
      return;
    }
    const at = new Date(this.resendAvailableAt).getTime();
    this.resendCooldownSeconds = Number.isNaN(at) ? 0 : Math.max(0, Math.ceil((at - Date.now()) / 1000));
  }
  clearCooldownTimer() {
    if (this._cooldownTimer) {
      window.clearInterval(this._cooldownTimer);
      this._cooldownTimer = null;
    }
  }

  // ── Details ──────────────────────────────────────────────────────────────

  resetSelections() {
    resetSelectionCounter();
    const first = createEmptySelection();
    this.selections = [first];
    this.activeSelectionKey = first.key;
    this.sentLinks = {};
    this.linkErrors = {};
  }

  handleSelectionChange(event) {
    const { key, field, value } = event.detail || {};
    if (!key || !field) return;
    this.errorMsg = "";
    this.selections = this.selections.map((s) => (s.key === key ? applySelectionChange(s, field, value, this.matrix, this.phaseOptions) : s));
  }
  handleAddSelection() {
    if (this.addSelectionDisabled) return;
    const next = createEmptySelection();
    this.selections = [...this.selections, next];
    this.activeSelectionKey = next.key;
  }
  handleRemoveSelection(event) {
    const key = event.detail?.key;
    if (!key || this.selections.length === 1) return;
    const remaining = this.selections.filter((s) => s.key !== key);
    if (this.activeSelectionKey === key) this.activeSelectionKey = remaining[0]?.key || "";
    this.selections = remaining;
    const { [key]: _drop, ...restSent } = this.sentLinks;
    this.sentLinks = restSent;
  }
  handleActivateSelection(event) {
    const key = event.detail?.key;
    if (key) this.activeSelectionKey = key;
  }
  handlePaymentChange(event) {
    this.paymentType = event.detail?.value || "";
    this.errorMsg = "";
  }
  /* 1.4: no choice left; kept so an old event cannot break the page */
  handleCheckoutMethod() {
    this.checkoutMethod = "send";
  }

  async preflight() {
    await this.runQuotaCheck();
    if (this.isProjectClosed) return false;
    if (this.hasQuotaCountError) {
      this.errorMsg = this.quotaCountErrorText;
      return false;
    }
    return true;
  }

  handleDetailsSubmit() {
    if (this.detailsSubmitDisabled) return;
    /* MSC-228: pay-first through Checkout. No EOI exists until the payment captures; the
     * materialiser then raises the EOI + receipt from the payload stashed on the payment.
     * 1.4: always one link per selection, as in the Sales App; Pay now is gone.
     * createViaModonPay (MSC-227) and createOffline stay wired but unreachable while every EOI
     * deposit is a card payment. */
    if (!this.isOnline) {
      this.createOffline();
    } else {
      this.sendLinks();
    }
  }

  /**
   * MSC-227. Online = ModonPay: the EOI(s) are created NOW, exactly like the offline types
   * (same quota preflight, same engine call), and the money is collected by the payments
   * team on their ModonPay screen - the EOI appears there as a line item the moment it
   * exists. The Done card then carries the handoff: reference(s), the same terminal link
   * the org's MODON_Pay webLink opens, and a read-back of whatever receipts have landed.
   */
  async createViaModonPay() {
    this.errorMsg = "";
    this.busy = true;
    this.busyLabel = this.isSingleSelection ? "Creating EOI" : "Creating EOIs";
    try {
      if (!(await this.preflight())) return;
      const result = await createEoi({ request: buildEoiRequest(this.opportunityId, this.selectedProjectId, this.paymentType, this.selections) });
      const eoiIds = result?.eoiIds || [];
      this.done = {
        mode: "modonpay",
        eoiId: result?.eoiId || null,
        eoiIds,
        references: result?.eoiReferences || [],
        accountName: result?.accountName || "",
        total: this.totalAmountLabel,
        paymentType: this.paymentType,
        count: this.selections.length
      };
      this.accountId = result?.accountId || this.accountId;
      this.modonPay = [];
      this.payState = null;
      this.step = 4;
      // the list pane re-reads and the hub's "N active" caption moves, as for every create
      this.dispatchEvent(new CustomEvent("created", { detail: { eoiIds } }));
      await this.loadModonPayInfo(eoiIds);
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  /** The terminal links, after the create. Non-fatal: the references alone still hand over. */
  async loadModonPayInfo(eoiIds) {
    if (!eoiIds || !eoiIds.length) return;
    try {
      const rows = (await getModonPayInfo({ eoiIds })) || [];
      this.modonPay = rows.map((r) => ({
        key: r.eoiId,
        name: r.eoiName || r.reference || "",
        reference: r.reference || "",
        terminalUrl: r.terminalUrl || "",
        hasLink: Boolean(r.terminalUrl)
      }));
    } catch (e) {
      // the created EOIs are real either way; the Done card still shows their references
      this.modonPay = [];
    }
  }

  /** Read back the stored receipts and statuses. A report, never a verdict. */
  async handleCheckPayment() {
    const eoiIds = this.done?.eoiIds || [];
    if (!eoiIds.length || this.busyPayCheck) return;
    this.busyPayCheck = true;
    this.errorMsg = "";
    try {
      const states = (await getEoiPaymentState({ eoiIds })) || [];
      this.payState = {
        checkedAt: new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }),
        rows: states.map((s) => ({
          key: s.eoiId,
          name: s.eoiName || "",
          status: s.status || "",
          paymentStatus: s.paymentStatus || "",
          receipts: (s.receipts || []).map((r) => ({
            key: r.id,
            name: r.name || "",
            status: r.status || "",
            amountText: r.amount != null ? formatAED(r.amount) : "",
            mode: r.modeOfPayment || ""
          })),
          hasReceipts: (s.receipts || []).length > 0
        }))
      };
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyPayCheck = false;
    }
  }

  async createOffline() {
    this.errorMsg = "";
    this.busy = true;
    this.busyLabel = this.isSingleSelection ? "Creating EOI" : "Creating EOIs";
    try {
      if (!(await this.preflight())) return;
      const result = await createEoi({ request: buildEoiRequest(this.opportunityId, this.selectedProjectId, this.paymentType, this.selections) });
      this.done = {
        mode: "created",
        eoiId: result?.eoiId || null,
        references: result?.eoiReferences || [],
        accountName: result?.accountName || "",
        total: this.totalAmountLabel,
        paymentType: this.paymentType,
        count: this.selections.length
      };
      this.accountId = result?.accountId || this.accountId;
      this.step = 4;
      this.dispatchEvent(new CustomEvent("created", { detail: { eoiIds: result?.eoiIds || [] } }));
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  /** One link per selection. Idempotent across retries: a key already sent is skipped. */
  async sendLinks() {
    this.errorMsg = "";
    this.busy = true;
    this.busyLabel = "Sending…";
    try {
      if (!(await this.preflight())) return;
      const errors = {};
      for (const selection of this.pendingLinkSelections) {
        try {
          // eslint-disable-next-line no-await-in-loop
          const res = await sendPaymentLink({ eoiPayloadJson: buildSelectionPayload(this.opportunityId, this.selectedProjectId, selection) });
          if (res && res.isSuccess) {
            this.sentLinks = { ...this.sentLinks, [selection.key]: true };
          } else {
            errors[selection.key] = (res && res.message) || "The payment link could not be created.";
          }
        } catch (e) {
          errors[selection.key] = reduceError(e);
        }
      }
      this.linkErrors = errors;
      const failed = Object.keys(errors).length;
      if (failed) {
        /* 1.4: the Sales App's sentence; a retry sends only the links that failed */
        this.errorMsg = "Some payment links could not be created. Please try again.";
        return;
      }
      this.done = {
        mode: "links",
        eoiId: null,
        references: [],
        accountName: "",
        total: this.totalAmountLabel,
        paymentType: "Online",
        count: this.selections.length
      };
      this.step = 4;
      this.dispatchEvent(new CustomEvent("created", { detail: { eoiIds: [] } }));
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  // ── Payment return ───────────────────────────────────────────────────────

  async handlePaymentReturn() {
    const result = (this.paymentReturnResult || "").toLowerCase();
    const ref = this.paymentReturnRef || "";
    if (result === "cancelled") {
      this.notice = { kind: "warn", text: "Payment cancelled - no charge was made and no EOI was created. You can start again below." };
      return;
    }
    if (result === "failed") {
      this.notice = { kind: "warn", text: "Payment not completed - no EOI was created. You can start again below." };
      return;
    }
    if (result !== "success") return;
    this.step = 4;
    this.done = { mode: "pending", eoiId: null, references: [], accountName: "", total: "", paymentType: "Online", count: 1, ref };
    if (!ref) return;
    await this.confirmReturn();
  }

  async confirmReturn() {
    if (!this.done?.ref) return;
    this.busy = true;
    this.busyLabel = "Confirming payment";
    this.errorMsg = "";
    try {
      const res = await confirmPayment({ reference: this.done.ref });
      // The EOI existing is the result. A hold creates it just as a capture does; only the receipt
      // waits for capture, so the card reports which of the two happened rather than staying pending.
      if (res && res.eoiId) {
        this.done = {
          ...this.done,
          mode: "paid",
          held: !res.isCaptured,
          eoiId: res.eoiId,
          references: [res.eoiName || res.eoiId]
        };
        this.dispatchEvent(new CustomEvent("created", { detail: { eoiIds: [res.eoiId] } }));
      } else if (res && res.isSuccess) {
        this.done = { ...this.done, mode: "pending", statusText: res.status || "" };
      } else {
        this.errorMsg = (res && res.message) || "Payment could not be confirmed yet.";
      }
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  handleCheckAgain() {
    this.confirmReturn();
  }

  // ── Done ─────────────────────────────────────────────────────────────────

  get doneTitle() {
    const m = this.done?.mode;
    if (m === "modonpay") return this.done.count > 1 ? "EOIs sent to ModonPay" : "EOI sent to ModonPay";
    /* 1.4: the Sales App's title, in the console's sentence case */
    if (m === "links") return "Payment link sent";
    if (m === "pending") return "Payment received";
    if (m === "paid") return "EOI created";
    return this.done?.count > 1 ? "EOIs created" : "EOI created";
  }
  get doneSubtitle() {
    const m = this.done?.mode;
    if (m === "modonpay")
      return this.done.count > 1
        ? "The payments team collects in ModonPay; each receipt lands on its EOI automatically."
        : "The payments team collects in ModonPay; the receipt lands on this EOI automatically.";
    if (m === "links") return "The EOI will be created once the customer completes payment.";
    if (m === "pending") return "The EOI is being created and will appear in the list shortly.";
    if (m === "paid")
      return this.done.held
        ? "The amount is held on the customer's card. The EOI is in place; its receipt follows when the payment is captured."
        : "The payment was captured and the EOI and its receipt are in place.";
    return "The customer, opportunity and EOI records are ready for the next step.";
  }
  get doneIsPending() {
    return this.done?.mode === "pending";
  }
  /* MSC-227: the ModonPay handoff card */
  get doneIsModonPay() {
    return this.done?.mode === "modonpay";
  }
  get modonPayRows() {
    return this.modonPay;
  }
  get hasModonPayLinks() {
    return this.modonPay.some((m) => m.hasLink);
  }
  get payStateRows() {
    return this.payState ? this.payState.rows : [];
  }
  get payCheckedLabel() {
    return this.payState ? `Checked ${this.payState.checkedAt}` : "";
  }
  get checkPaymentLabel() {
    return this.payState ? "Check again" : "Check payment";
  }
  get doneHasReferences() {
    return (this.done?.references || []).length > 0;
  }
  get doneReferences() {
    return (this.done?.references || []).map((r, i) => ({ key: `${r}-${i}`, label: r }));
  }
  get doneCustomerName() {
    if (this.done?.accountName) return this.done.accountName;
    const c = this.customer;
    return this.isOrganization ? c.companyName : [c.firstName, c.lastName].filter(Boolean).join(" ");
  }
  get doneShowTotal() {
    return Boolean(this.done?.total);
  }
  get doneIcon() {
    if (this.doneIsModonPay) return "send";
    return this.doneIsPending ? "clock" : "check-circle";
  }

  handleViewList() {
    this.dispatchEvent(new CustomEvent("exit"));
  }

  handleRaiseAnother() {
    // Keep the project (and its matrix/quota); start the customer over.
    this.errorMsg = "";
    this.notice = null;
    this.done = null;
    /* MSC-227: and the handoff card's own state */
    this.modonPay = [];
    this.payState = null;
    this.paymentType = "Online"; // MSC-228: card only
    this.checkoutMethod = "send";
    this.resetSelections();
    this.resetVerification();
    this.lookup = emptyLookup();
    this.customer = emptyCustomer(this.customer.customerType);
    this.clearIdentityResult();
    this.resetAllContact();
    this.step = 1;
  }
}