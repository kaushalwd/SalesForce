/**
 * "Who is this booking for?" - the customer step of the booking journey.
 *
 * Version  Author      Date         Detail
 * 2.43     Aurelix Dev 30 Sep 2026  A lead with a Company converts to an organisation (as in the Sales App), so the
 *                                   qualify panel always opens for it and states "Customer type" first (R2-01).
 * 2.42     Aurelix Dev 28 Sep 2026  SCW-205. The chooser offers "Continue With New Details" only while
 *                                   ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on (read from getLeadQualifyOptions,
 *                                   key newCustomerDespiteMatch; off, or not yet loaded, hides it). The Sales
 *                                   App lets no rep create a new account while existing ones match
 *                                   (business confirmed, 28 Sep 2026). Cancel and Continue stay; Continue
 *                                   still needs a row. The server refuses the same answer on its own
 *                                   (SalesConsoleLeadController 1.31).
 * 2.41     Aurelix Dev 22 Sep 2026  Two getters were both called signatoryChoices. A class keeps only the
 *                                   last one, so the "who signs for this company" chooser listed Yes and
 *                                   No instead of the company's contacts. The create form's Yes/No list
 *                                   (MSC-139) is now authorisedSignatoryChoices; signatoryChoices is the
 *                                   contacts again. Previous version: _backup/2026-09-22_105910 (WL-023).
 * 2.40     Aurelix Dev 21 Sep 2026  Markup only (WL-014): the eight selects are c/mscPicklist again, now
 *                                   drawn in the browser's top layer (mscFloat 1.2), so the booking
 *                                   pop-up no longer cuts the list off. Verified as a rep on 22 Sep.
 * 2.39     Aurelix Dev 21 Sep 2026  Native selects again (21 Sep). 2.38 had made the eight
 *                                   selects c/mscPicklist to avoid the empty grey pop-up Chrome shows
 *                                   for a select's list on a Linux desktop. Inside the booking pop-up
 *                                   the drawn list was cut off, and the reps work on Windows and Mac,
 *                                   where the native list paints normally (SCW-137).
 * 2.37     Aurelix Dev 02 Sep 2026  MSC-224. The qualify form's standing note is removed
 *                                   ("These are required by Modon before a lead can be
 *                                   qualified..."). Template and stylesheet only; the gap it
 *                                   left under the fields moves onto field-grid--spaced. The
 *                                   signatory and identity notes are untouched.
 * 2.36     Aurelix Dev 02 Sep 2026  MSC-214. The seeded panel is a confirmation, not a form:
 *                                   no lede, and the nationality/residency the lead already
 *                                   holds arrive locked (the server writes them fill-only, so
 *                                   an edit here was a lie). Back off the seeded panel raises
 *                                   `seedcancel` so the page restores the plain picker.
 * 2.35     Aurelix Dev 02 Sep 2026  MSC-212. seed-lead: the lead "Book a unit" was pressed on
 *                                   arrives as a row and the qualify panel opens on it directly -
 *                                   no re-search. Applied once, never over a face the rep is on;
 *                                   Back falls out to the normal search. The lede says where the
 *                                   lead came from.
 * 2.34     Aurelix Dev 25 Aug 2026  MSC-167. A passport search that found nobody opens the form on Non-Resident.
 * 2.33     Aurelix Dev 24 Aug 2026  MSC-160. Residency fact label from c/mscLabels.
 * 2.32     Aurelix Dev 24 Aug 2026  MSC-159. Only the documents the residency asks for are sent.
 * 2.31     Aurelix Dev 24 Aug 2026  MSC-158. The searched document reaches the form (searchedKey).
 * 2.30     Aurelix Dev 23 Aug 2026  MSC-152. Buyer type arrives as @api buyerType.
 * 2.29     Aurelix Dev 23 Aug 2026  MSC-144. Two rows: Find customer inside the search control.
 * 2.28     Aurelix Dev 23 Aug 2026  MSC-143. Search control has no fill of its own. CSS only.
 * 2.27     Aurelix Dev 23 Aug 2026  MSC-142. Search control restyled. CSS only.
 * 2.26     Aurelix Dev 22 Aug 2026  MSC-140. The company row says three things and stops.
 * 2.25     Aurelix Dev 22 Aug 2026  MSC-139. Is Authorised Signatory Contact; email and mobile required.
 * 2.24     Aurelix Dev 22 Aug 2026  MSC-136. Trade licence number required.
 * 2.23     Aurelix Dev 22 Aug 2026  MSC-135. Spacing. CSS only.
 * 2.22     Aurelix Dev 22 Aug 2026  MSC-134. The search key is declared on a segmented control, not guessed.
 * 2.21     Aurelix Dev 22 Aug 2026  MSC-132. The residency question leaves the search screen.
 * 2.20     Aurelix Dev 22 Aug 2026  MSC-128. Identity step note gone on the person branch.
 * 2.19     Aurelix Dev 22 Aug 2026  MSC-120. openForm reads the buyer type when there is no row.
 * 2.18     Aurelix Dev 22 Aug 2026  MSC-119. A company is found by trade licence only; residency stamped Resident.
 * 2.17     Aurelix Dev 22 Aug 2026  MSC-118. One search key at a time; contact key offered on a miss.
 * 2.16     Aurelix Dev 22 Aug 2026  MSC-117. One Find customer button.
 * 2.15     Aurelix Dev 22 Aug 2026  MSC-115. Corporate verification sentence from c/mscLabels.
 * 2.14     Aurelix Dev 22 Aug 2026  MSC-114. The address gap said before the choice.
 * 2.13     Aurelix Dev 22 Aug 2026  MSC-111. Contact search, what-matched chips, candidates chooser.
 * 2.12     Aurelix Dev 22 Aug 2026  MSC-110. The identity a booking must carry; identity step; demo autofill deleted.
 * 2.11     Aurelix Dev 21 Aug 2026  MSC-108. A company hit reads as a company and attaches to a real person.
 * 2.10     Aurelix Dev 17 Aug 2026  Find customer waits for a complete Emirates ID; email and mobile checked via Loqate.
 * 2.9      Aurelix Dev 17 Aug 2026  One-line no-match message; create form stays up under the dialog.
 * 2.8      Aurelix Dev 16 Aug 2026  A new customer is flagged on the way out.
 * 2.7      Aurelix IT  12 Aug 2026  autocomplete="off" on every field.
 * 2.6      Aurelix IT  12 Aug 2026  Keyboard follows the document.
 * 2.5      Aurelix IT  12 Aug 2026  Backend waits raise c-msc-loader.
 * 2.4      Aurelix IT  11 Aug 2026  Create-form lede dropped.
 * 2.3      Aurelix IT  10 Aug 2026  Both opening questions on one row.
 * 2.2      Aurelix IT  10 Aug 2026  Type asked first; non-UAE companies stopped with an explanation.
 * 2.1      Aurelix IT  10 Aug 2026  Individual / Organisation; customerType sent to Apex.
 * 2.0      Aurelix IT  09 Aug 2026  Rebuilt as a straight line.
 * 1.4      Aurelix IT  09 Aug 2026  Create a customer here and carry on booking.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api, wire } from "lwc";
import getProjectOptions from "@salesforce/apex/SalesConsoleLeadController.getProjectOptions";
import getLeadQualifyOptions from "@salesforce/apex/SalesConsoleLeadController.getLeadQualifyOptions";
import findByIdentity from "@salesforce/apex/SalesConsoleLeadController.findByIdentity";
import findByContact from "@salesforce/apex/SalesConsoleLeadController.findByContact";
import createCustomer from "@salesforce/apex/SalesConsoleLeadController.createCustomer";
import convertLeadToCustomer from "@salesforce/apex/SalesConsoleLeadController.convertLeadToCustomer";
import bookForExistingCustomer from "@salesforce/apex/SalesConsoleLeadController.bookForExistingCustomer";
/* what MODON already holds for a chosen customer, asked before booking an existing one */
import identityFor from "@salesforce/apex/SalesConsoleLeadController.identityFor";
/* the two Loqate checks, through the same facade the EOI journey uses */
import checkEmail from "@salesforce/apex/SalesConsoleEoiJourneyController.checkEmail";
import checkPhone from "@salesforce/apex/SalesConsoleEoiJourneyController.checkPhone";
import { reduceError } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
/* one rule for a complete Emirates ID, a valid email and a valid mobile, shared with the EOI journey */
import {
  EMIRATES_ID_REGEX,
  isValidEmailShape,
  isValidPhone,
  /* the caret-aware mask, the name-rule mirror, and the identity set definitions */
  applyEmiratesIdMask,
  isPlainName,
  identityNeedsFor,
  identitySetComplete,
  /* matches a picklist value to its meaning */
  normalizeResidentStatus,
  localISODate
} from "c/mscEoiUtils";

/* the exact string SalesConsoleLeadController tests with equalsIgnoreCase */
const INDIVIDUAL = "Individual";
const ORGANISATION = "Organisation";
/* the search keys: three for a person (two documents, contact), one for a company (licence) */
const KEY_EID = "eid";
const KEY_PASSPORT = "passport";
const KEY_CONTACT = "contact";
/* everything that is not the contact key searches the document field */
const KEY_DOCUMENT = "document";

/* looksLikeEmiratesId is gone; the segmented control asks instead */
/* the "Someone else" sentinel on the signatory picker; not an id shape */
const SIG_OTHER = "__other";

/* the contact-check record and its view */
function idleContact() {
  return { status: "idle", value: "", message: "", retry: false };
}
function contactView(c) {
  const status = (c && c.status) || "idle";
  return {
    isChecking: status === "checking",
    isOk: status === "ok",
    isBad: status === "bad",
    message: (c && c.message) || "",
    inputClass: `field__input${status === "bad" ? " field__input--error" : ""}`
  };
}

/* the Emirates ID mask moved verbatim to c/mscEoiUtils.applyEmiratesIdMask */


/**
 * One line, four stops: buyer type, document -> Find customer, matches listed (or create a new
 * customer), either route raises `opportunityselect`. The document is the question.
 */
export default class MscConsole extends LightningElement {
  labels = LABELS;

  @api backgroundImage;
  @api accentColor;
  /** The project this booking is in (ProjectInterest__c is required on Lead). */
  @api projectInterest;

  /**
   * Who the booking is for, set from outside (the switch lives in the card's heading row).
   * The setter is idempotent: a parent re-render must not wipe what the rep half-typed.
   */
  @api
  get buyerType() {
    return this.identity.customerType;
  }
  set buyerType(value) {
    const next = value === ORGANISATION ? ORGANISATION : INDIVIDUAL;
    if (next === this.identity.customerType) {
      return;
    }
    this.applyCustomerType(next);
  }

  /**
   * MSC-212. The lead this journey was opened from ("Book a unit" on the lead drawer), as the
   * CustomerDTO row leadRowById built. The qualify panel opens on it directly - same face, same
   * conversion, no re-search. A row with no leadId (or an adopted opportunity) seeds nothing.
   */
  @api
  get seedLead() {
    return this._seedLead;
  }
  set seedLead(row) {
    this._seedLead = row;
    this.applySeed(row);
  }
  _seedLead;
  /** One shot: cancelling out of the seeded panel must not re-open it on the next render. */
  _seedApplied = false;

  /** The seeded lead walks the exact road a clicked lead row walks - straight to the panel. */
  applySeed(row) {
    if (!row || !row.leadId || row.id || this._seedApplied) {
      return;
    }
    /* never over a face the rep is already on */
    if (this.lead || this.creating || this.signatory || this.identityStep || this.candidateCtx) {
      return;
    }
    this._seedApplied = true;
    this.lead = {
      leadId: row.leadId,
      name: row.name,
      email: row.email,
      phone: row.phone,
      projectInterest: row.projectInterest,
      nationality: row.nationality || "",
      /* a company is never asked residency - the same 'Resident' stamp the org switch writes */
      residentStatus: row.residentStatus || (row.isOrganisation === true ? "Resident" : ""),
      /* 2.36: what the lead already answers is locked - the server writes both fill-only, so
         a change here would never land; the org's Resident stamp on a company is locked too */
      natLocked: !!row.nationality,
      resLocked: !!(row.residentStatus || row.isOrganisation === true),
      idValues: this.leadIdentitySeed(row),
      idLocked: this.leadIdentityLock(row),
      /* 2.43: conversion makes an organisation whenever the lead has a Company, as in the Sales App */
      companyName: row.companyName || "",
      seeded: true
    };
    this.qualifyError = undefined;
  }

  /** The panel's opening line; the seeded panel is a confirmation and carries none (2.36). */
  get qualifyLede() {
    return this.lead && this.lead.seeded ? "" : "Qualify this lead to book for them.";
  }

  /* 2.36: locked only on the seeded panel, and only where the lead supplied the value */
  get qualifyNatDisabled() {
    return !!(this.lead && this.lead.seeded && this.lead.natLocked);
  }
  get qualifyResDisabled() {
    return !!(this.lead && this.lead.seeded && this.lead.resLocked);
  }

  /** Picklists that gate lead conversion: { nationality: [], residentStatus: [] }. */
  options = {};
  projects = [];

  // stops 1 and 2: who, and which document
  /** customerType starts at Individual; residentStatus stays blank. */
  identity = { residentStatus: "", customerType: INDIVIDUAL, documentNumber: "" };
  matches = [];
  /** True only after a search has run. */
  searched = false;
  looking = false;
  identityError;

  // stop 3a: qualifying a matched lead
  lead;
  qualifyError;

  /** Stop 3c: who signs for a matched company. Set only for a company with more than one contact. */
  signatory;

  /** Stop 3d: the identity step. Opened only when identityFor says the record cannot carry the booking. */
  identityStep;

  /** The contact search's own input; separate from identity.documentNumber. */
  contactTerm = "";
  /* which key the field is asking for: KEY_EID, KEY_PASSPORT or KEY_CONTACT for a person,
     KEY_DOCUMENT for a company */
  searchKey = KEY_EID;
  /* which key the last search actually ran on (the field may have flipped since) */
  searchedKey;

  /** Stop 3e: the candidates chooser. Opened only when the server found more than one match with no DML; nothing preselected. */
  candidateCtx;
  busy = false;

  // stop 3b: creating a new customer
  creating = false;
  saving = false;
  formError;
  /* set when this form is completing a company the org already holds */
  formAccountId;
  formContactId;
  /* email and mobile, checked as entered: idle | checking | ok | bad, with the value the status is about */
  contact = { email: idleContact(), phone: idleContact() };
  /* the in-flight check per field */
  _contactPending = {};
  form = {
    firstName: "",
    lastName: "",
    phone: "",
    email: "",
    projectInterest: "",
    nationality: "",
    residentStatus: "",
    /* MSC-139. "Yes" | "No" | "" - organisation only */
    isAuthorisedSignatory: "",
    /* the organisation's document; an individual's moved to formIdentity */
    documentNumber: "",
    customerType: "",
    companyName: ""
  };
  /* the identity document set on the create form; fields follow form.residentStatus */
  formIdentity = {};

  @wire(getProjectOptions)
  wiredProjects({ data }) {
    if (data) this.projects = data;
  }

  /** Static per org, so cacheable is right. */
  @wire(getLeadQualifyOptions)
  wiredQualifyOptions({ data }) {
    if (data) this.options = data;
  }

  /* the cursor lands in the document field, one shot (flag cleared before focus) */
  focusSearchNext = false;

  /* whichever key the field is asking for */
  renderedCallback() {
    if (!this.focusSearchNext || !this.showDocument) {
      return;
    }
    const input = this.template.querySelector('[data-search="input"]');
    if (!input) {
      return;
    }
    this.focusSearchNext = false;
    input.focus();
  }

  /* six mutually exclusive faces */
  get showFind() {
    /* not while the signatory step, identity step or chooser is up */
    return (
      !this.creating &&
      !this.lead &&
      !this.signatory &&
      !this.identityStep &&
      !this.candidateCtx
    );
  }
  /* the fifth face: the documents a chosen customer still owes */
  get showIdentityStep() {
    return !!this.identityStep;
  }
  get showQualify() {
    /* hidden, not cleared, while the chooser is up */
    return !!this.lead && !this.candidateCtx;
  }
  /* the fourth face: who signs for a matched company */
  get showSignatory() {
    return !!this.signatory;
  }
  /* the sixth face: the candidates chooser */
  get showCandidates() {
    return !!this.candidateCtx;
  }
  /* same hidden-not-cleared rule */
  get showCreate() {
    return this.creating && !this.candidateCtx;
  }

  // stop 1

  /* residencyPills left with the question */

  /* isResident is gone with the question */

  /* handleResidency is gone with the pills */

  // stop 1: individual or company

  /* customerTypePills moved to c/mscBookingPage */

  get isOrganisation() {
    return this.identity.customerType === ORGANISATION;
  }

  /** Was the click handler for this pane's own buttons; the body is unchanged, called by the buyerType setter. */
  applyCustomerType(customerType) {
    const isOrg = customerType === ORGANISATION;
    /* a company is never asked residency; 'Resident' is stamped (the only value this step could
       produce), and three things downstream read it */
    this.identity = {
      residentStatus: isOrg ? "Resident" : "",
      customerType,
      documentNumber: ""
    };
    /* and the contact term */
    this.contactTerm = "";
    /* a company has one key and no segments; a person opens on the Emirates ID */
    this.searchKey = isOrg ? KEY_DOCUMENT : KEY_EID;
    this.resetSearch();
    /* the field is on screen the moment the pill is pressed, so the cursor goes there */
    this.focusSearchNext = true;
  }

  // stop 2

  /** One answer, not two: residency never reached the search. */
  get showDocument() {
    return !!this.identity.customerType;
  }

  get documentWord() {
    if (this.isOrganisation) return "trade licence";
    /* the key the rep declared */
    return this.onPassportKey ? LABELS.FIND_PASSPORT_WORD : LABELS.FIND_EID_WORD;
  }

  /* one key at a time: the document, or the contact detail, never both */

  /* a document key is anything that is not the contact key */
  get onDocumentKey() {
    return this.searchKey !== KEY_CONTACT;
  }

  get onContactKey() {
    return this.searchKey === KEY_CONTACT;
  }

  get onEidKey() {
    return this.searchKey === KEY_EID;
  }

  get onPassportKey() {
    return this.searchKey === KEY_PASSPORT;
  }

  /** Mid-sentence, lower case. */
  get contactWord() {
    return this.isOrganisation
      ? LABELS.FIND_CONTACT_WORD_COMPANY
      : LABELS.FIND_CONTACT_WORD;
  }

  get contactLabel() {
    return this.isOrganisation
      ? LABELS.FIND_CONTACT_LABEL_COMPANY
      : LABELS.FIND_CONTACT_LABEL;
  }

  get contactPlaceholder() {
    return this.isOrganisation
      ? LABELS.FIND_CONTACT_PLACEHOLDER_COMPANY
      : LABELS.FIND_CONTACT_PLACEHOLDER;
  }

  /** The input's accessible name; the active segment is the visual label. */
  get searchLabel() {
    if (this.onContactKey) return this.contactLabel;
    return this.documentLabel;
  }

  /* a company is searched by trade licence and nothing else */
  get showKeySegments() {
    return !this.isOrganisation;
  }

  /** The three keys, as the control renders them. */
  get keySegments() {
    return [
      { key: KEY_EID, label: LABELS.FIND_KEY_EID },
      { key: KEY_PASSPORT, label: LABELS.FIND_KEY_PASSPORT },
      { key: KEY_CONTACT, label: LABELS.FIND_KEY_CONTACT_SEG }
    ].map((s) => ({
      ...s,
      cls: this.searchKey === s.key ? "ident__key ident__key--on" : "ident__key",
      pressed: this.searchKey === s.key ? "true" : "false"
    }));
  }

  /** Every value stays typed; only the results reset. */
  handleSearchKey(event) {
    const key = event.currentTarget.dataset.key;
    if (!key || key === this.searchKey) return;
    this.searchKey = key;
    this.resetSearch();
    this.focusSearchNext = true;
  }

  /* what the miss sentence names: the key that ran */
  get searchedWord() {
    if (this.searchedKey === KEY_CONTACT) return this.contactWord;
    if (this.searchedKey === KEY_PASSPORT) return LABELS.FIND_PASSPORT_WORD;
    if (this.searchedKey === KEY_EID) return LABELS.FIND_EID_WORD;
    return this.documentWord;
  }
  /* "Emirates ID", not "Emirates ID number" */
  get documentLabel() {
    if (this.isOrganisation) return "Trade licence number";
    return this.onPassportKey ? LABELS.FIND_KEY_PASSPORT : LABELS.FIND_KEY_EID;
  }
  get documentPlaceholder() {
    /* the label already says it; not an example value either */
    if (this.isOrganisation) return LABELS.ORG_LICENCE_PLACEHOLDER;
    /* the Emirates ID shape is fixed; a passport has none */
    return this.onPassportKey
      ? LABELS.FIND_PASSPORT_PLACEHOLDER
      : LABELS.FIND_EID_PLACEHOLDER;
  }

  /** The on-screen keyboard follows the document. A hint only; not type="number". */
  /* the keypad follows the declared key */
  get documentInputMode() {
    return this.onEidKey ? "numeric" : "text";
  }

  /** A search by Emirates ID waits for the whole number (fifteen digits). */
  get emiratesIdComplete() {
    return EMIRATES_ID_REGEX.test(this.identity.documentNumber.trim());
  }

  /* each key answers for itself */
  get documentUsable() {
    if (!this.identity.documentNumber.trim()) return false;
    return !(this.searchingByEmiratesId && !this.emiratesIdComplete);
  }

  /* an email searches as soon as it has a shape; a number needs enough digits */
  get contactUsable() {
    const t = this.contactTerm.trim();
    if (!t) return false;
    if (t.includes("@")) return isValidEmailShape(t);
    return t.replace(/\D/g, "").length >= 7;
  }

  get lookupBlocked() {
    if (this.looking) return true;
    return this.onDocumentKey ? !this.documentUsable : !this.contactUsable;
  }

  /* said under the row, only while something is typed and incomplete */
  get documentHint() {
    /* the field may not be asking for a document */
    if (!this.onDocumentKey || !this.searchingByEmiratesId) return null;
    const doc = this.identity.documentNumber.trim();
    if (!doc || this.emiratesIdComplete) return null;
    return LABELS.EID_INCOMPLETE;
  }
  get lookupLabel() {
    return this.looking ? "Checking…" : "Find customer";
  }

  /** The mask and the complete-ID gate apply on the Emirates ID key only. */
  get searchingByEmiratesId() {
    return this.onEidKey;
  }

  handleDocument(event) {
    this.identity = {
      ...this.identity,
      documentNumber: this.applyDocumentMask(event.target, this.onEidKey)
    };
    this.resetSearch();
  }

  /** Reformats in place and returns what to store; passport and licence pass through. */
  applyDocumentMask(input, isEmiratesId) {
    if (!isEmiratesId) {
      return input.value;
    }
    return applyEmiratesIdMask(input);
  }

  handleDocumentKey(event) {
    if (event.key === "Enter" && !this.lookupBlocked) this.findCustomer();
  }

  resetSearch() {
    this.matches = [];
    this.searched = false;
    this.identityError = undefined;
    /* a changed question must not come back to the previous company's signatory panel */
    this.signatory = undefined;
    /* nor the previous customer's identity step */
    this.identityStep = undefined;
    /* nor a chooser about the previous question */
    this.candidateCtx = undefined;
    /* nor a miss sentence naming the previous key */
    this.searchedKey = undefined;
  }

  /* the second key: email or mobile, offered second, not alongside */

  handleContactTerm(event) {
    this.contactTerm = event.target.value;
    /* results, not text */
    this.resetSearch();
  }

  handleContactKey(event) {
    if (event.key === "Enter" && !this.lookupBlocked) this.findCustomer();
  }

  /** The one search, on the one key the field is asking for. Explicit, no debounce. */
  async findCustomer() {
    if (this.lookupBlocked) return;
    const key = this.searchKey;
    this.looking = true;
    this.identityError = undefined;
    this.matches = [];
    this.searched = false;
    try {
      /* every document key sends the same query; the segment names the key for the rep only */
      const rows =
        key !== KEY_CONTACT
          ? await findByIdentity({
              // so Apex matches companies by trade licence
              customerType: this.identity.customerType || null,
              residentStatus: this.identity.residentStatus,
              idNumber: this.identity.documentNumber.trim()
            })
          : await findByContact({
              customerType: this.identity.customerType || null,
              term: this.contactTerm.trim()
            });
      this.matches = rows || [];
      this.searchedKey = key;
      this.searched = true;
      this.offerContactKey();
    } catch (e) {
      this.identityError = reduceError(e);
    } finally {
      this.looking = false;
    }
  }

  /**
   * The safety net: the document found nobody, so offer the contact key. Only document ->
   * contact, and only when the contact key is untried.
   */
  offerContactKey() {
    /* never for a company */
    if (this.isOrganisation) return;
    if (this.matches.length > 0) return;
    if (this.searchedKey === KEY_CONTACT) return;
    if (this.contactTerm.trim()) return;
    this.searchKey = KEY_CONTACT;
    this.focusSearchNext = true;
  }

  // stop 3a: the results

  get hasMatches() {
    return this.matches.length > 0;
  }

  /** Only after a search that found nobody. */
  get noMatches() {
    return this.searched && this.matches.length === 0;
  }

  get matchRows() {
    return this.matches.map((m, i) => {
      const isLead = m.kind === "Lead";
      const isOrg = this.isOrgMatch(m);
      /* an organisation row names the company (on a lead m.name is the person) */
      const title = isOrg ? m.companyName || m.name : m.name;
      /* MSC-140: the company row names the company and its licence, and stops there */
      const lines = isOrg
        ? [this.licenceLine(m)]
        : [
            /* MSC-140: the mobile leaves the row */
            m.projectInterest || "",
            /* the record's own residency and nationality, said before the click */
            this.personFactsLine(m)
          ];
      return {
        ...m,
        /* index: a row carries either an accountId or a leadId */
        key: `m-${i}`,
        index: String(i),
        isLead,
        isOrg,
        title,
        /* chips: the record kind and what matched, from matchedOn */
        chips: [this.matchChip(isOrg, isLead), this.matchedOnChip(m)]
          .filter(Boolean)
          .map((text, n) => ({ key: `m-${i}-c-${n}`, text })),
        /* a company carries two facts a person does not */
        lines: lines
          .filter(Boolean)
          .map((text, n) => ({ key: `m-${i}-l-${n}`, text })),
        /* the address gap, on account rows only */
        /* MSC-140: a company row carries no address warning */
        warn: m.needsAddress && !isOrg ? LABELS.MATCH_ROW_ADDRESS : null,
        /* what the click does, per row */
        action: isLead ? LABELS.MATCH_IS_LEAD : LABELS.MATCH_IS_CUSTOMER
      };
    });
  }

  /** Residency and nationality as the record holds them. */
  personFactsLine(m) {
    return [m && m.residentStatus, m && m.nationality].filter(Boolean).join(" · ");
  }

  /* the row's answer, not the search form's */
  isOrgMatch(m) {
    return !!m && (m.isOrganisation === true || (this.isOrganisation && !!m.companyName));
  }

  /** The signatories the server sent, always an array. */
  signatoriesOf(m) {
    return m && Array.isArray(m.signatories) ? m.signatories.filter(Boolean) : [];
  }

  matchChip(isOrg, isLead) {
    if (isOrg) {
      return isLead ? LABELS.MATCH_CHIP_COMPANY_LEAD : LABELS.MATCH_CHIP_COMPANY;
    }
    return isLead ? LABELS.MATCH_CHIP_LEAD : null;
  }

  /* the server's matchedOn code, rendered; unknown codes draw nothing */
  matchedOnChip(m) {
    const map = {
      eid: LABELS.MATCHED_EID,
      passport: LABELS.MATCHED_PASSPORT,
      licence: LABELS.MATCHED_LICENCE,
      /* 'unified' draws nothing: the licence is already printed on the line above */
      email: LABELS.MATCHED_EMAIL,
      mobile: LABELS.MATCHED_MOBILE
    };
    return (m && m.matchedOn && map[m.matchedOn]) || null;
  }

  /* the licence the server matched on, falling back to what was typed */
  licenceLine(m) {
    const licence = (m.tradeLicence || this.doc || "").trim();
    return licence ? LABELS.MATCH_ORG_LICENCE.replace("{0}", licence) : null;
  }

  /* signatoryLine retired; signatoryName stays for the chooser */

  signatoryName(s) {
    if (!s) return "";
    return s.name || [s.firstName, s.lastName].filter(Boolean).join(" ") || "";
  }

  /* people, not records; and a company is not a person, read off the rows */
  get matchesLabel() {
    const n = this.matches.length;
    const allOrg = n > 0 && this.matches.every((m) => this.isOrgMatch(m));
    if (allOrg) {
      return n === 1
        ? LABELS.MATCH_ONE_COMPANY
        : LABELS.MATCH_MANY_COMPANY.replace("{0}", String(n));
    }
    return n === 1 ? LABELS.MATCH_ONE : LABELS.MATCH_MANY.replace("{0}", String(n));
  }

  /* both sentences, as one */
  get noMatchMessage() {
    /* a company is not a "one"; the caution says which form to type */
    const org = this.isOrganisation;
    const none = org ? LABELS.MATCH_NONE_COMPANY : LABELS.MATCH_NONE;
    return `${none.replace("{0}", this.searchedWord)} ${this.noMatchAdvice}`;
  }

  /** Three things to say: the field was switched for them, the contact key ran, or the document caution. */
  get noMatchAdvice() {
    const org = this.isOrganisation;
    if (this.searchedKey !== KEY_CONTACT && this.onContactKey) {
      return (
        org ? LABELS.MATCH_NONE_TRY_CONTACT_COMPANY : LABELS.MATCH_NONE_TRY_CONTACT
      ).replace("{0}", this.contactWord);
    }
    if (this.searchedKey === KEY_CONTACT) {
      return org
        ? LABELS.MATCH_NONE_WARN_CONTACT_COMPANY
        : LABELS.MATCH_NONE_WARN_CONTACT;
    }
    return org ? LABELS.MATCH_NONE_WARN_COMPANY : LABELS.MATCH_NONE_WARN;
  }

  /** The word on the only button the miss state offers. */
  get newCustomerLabel() {
    return this.isOrganisation ? LABELS.CTA_NEW_COMPANY : LABELS.CTA_NEW_CUSTOMER;
  }

  /**
   * The rep picked somebody: a customer is booked (lead raised and converted into their
   * account); a lead is qualified, silently if it already has Nationality and Resident Status.
   */
  async chooseMatch(event) {
    if (this.busy) return;
    const m = this.matches[Number(event.currentTarget.dataset.index)];
    if (!m) return;

    if (m.leadId) {
      /* 2.43 - R2-01: a lead with a Company becomes an organisation on conversion, so the panel
         always opens first and says so, even when nothing is missing */
      if (m.needsQualifyDetails || m.companyName) {
        this.lead = {
          leadId: m.leadId,
          name: m.name,
          email: m.email,
          phone: m.phone,
          projectInterest: m.projectInterest,
          nationality: m.nationality || "",
          /* answered at the top of this screen */
          residentStatus: m.residentStatus || this.identity.residentStatus || "",
          /* the lead's own identity, prefilled and locked where populated */
          idValues: this.leadIdentitySeed(m),
          idLocked: this.leadIdentityLock(m),
          companyName: m.companyName || ""
        };
        this.qualifyError = undefined;
        return;
      }
      await this.qualifyLead(m.leadId, m.nationality, m.residentStatus, m);
      return;
    }

    /* a company books against a person: one contact -> use them; several -> ask; none -> the create form */
    if (this.isOrgMatch(m)) {
      const sigs = this.signatoriesOf(m);
      if (sigs.length > 1) {
        this.openSignatory(m, sigs);
        return;
      }
      await this.bookForCompany(m, sigs.length === 1 ? sigs[0] : null);
      return;
    }

    await this.bookForPerson(m);
  }

  /** An individual: what MODON holds is read first, and only a gap opens the identity step. */
  async bookForPerson(m) {
    if (this.busy) return;
    if (m.needsQualifyDetails) {
      this.busy = true;
      this.identityError = undefined;
      try {
        const state = await identityFor({
          /* the record's own answer; no fallback invented here */
          accountId: m.accountId,
          signatoryContactId: null,
          residentStatus: m.residentStatus || null
        });
        if (state && !state.complete) {
          this.openIdentityStep(m, null, state);
          return;
        }
      } catch (e) {
        /* a failed read must not strand the booking */
      } finally {
        this.busy = false;
      }
    }
    await this.bookPersonNow(m, {});
  }

  /** The booking itself. `docs` is what the identity step collected. */
  /** chosenResidency is the identity step's answer for a record that holds none. */
  /**
   * MSC-159. Send only the documents the residency asks for: a Resident's held passport fields
   * were still being sent and could trip Passport_Number_Format_Check on the Lead. A blank
   * residency is not filtered.
   */
  identityToSend(docs, residentStatus) {
    const d = docs || {};
    const all = {
      eidNumber: d.eidNumber || (this.docIsEmiratesId ? this.doc : null),
      eidExpiry: d.eidExpiry || null,
      passportNumber: d.passportNumber || (this.docIsPassport ? this.doc : null),
      passportIssueDate: d.passportIssueDate || null,
      passportExpiryDate: d.passportExpiryDate || null
    };
    if (!residentStatus) return all;
    const needs = identityNeedsFor(residentStatus);
    return {
      eidNumber: needs.eidNumber ? all.eidNumber : null,
      eidExpiry: needs.eidExpiry ? all.eidExpiry : null,
      passportNumber: needs.passportNumber ? all.passportNumber : null,
      passportIssueDate: needs.passportIssueDate ? all.passportIssueDate : null,
      passportExpiryDate: needs.passportExpiryDate ? all.passportExpiryDate : null
    };
  }

  async bookPersonNow(m, docs, chosenResidency) {
    this.busy = true;
    this.identityError = undefined;
    /* the residency that is sent is the one the documents are filtered by */
    const residency = m.residentStatus || chosenResidency || null;
    const send = this.identityToSend(docs, residency);
    try {
      const res = await bookForExistingCustomer({
        accountId: m.accountId,
        ...this.nameParts(m.name),
        phone: m.phone,
        email: m.email,
        projectInterest: m.projectInterest || this.projectInterest,
        nationality: m.nationality,
        residentStatus: residency,
        /* a company's document is its licence; which personal field the value belongs in is
           read off the declared key */
        eidNumber: send.eidNumber,
        passportNumber: send.passportNumber,
        customerType: this.identity.customerType || null,
        companyName: null,
        /* no longer hard-coded null; these fill only what the account could not supply */
        passportIssueDate: send.passportIssueDate,
        tradeLicence: null,
        /* a Person Account cannot carry a separate Contact */
        signatoryContactId: null,
        eidExpiry: send.eidExpiry,
        passportExpiry: send.passportExpiryDate
      });
      if (res && res.opportunityId) {
        this.handoff(res.opportunityId);
        return;
      }
      throw new Error("no opportunity");
    } catch (e) {
      /* land the rep on the form, which asks for exactly what is missing */
      this.identityError = reduceError(e);
      this.openForm(m);
    } finally {
      this.busy = false;
    }
  }

  /**
   * Book for a matched company, signed by a named person. The call used to send nameParts of
   * the company name, so conversion invented a Contact that became the SPA signer. sig null
   * means the company has nobody on file.
   */
  async bookForCompany(m, sig) {
    if (this.busy) return;
    /* the signatory's documents are what the lead carries; only a gap opens the identity step */
    if (sig && sig.contactId) {
      this.busy = true;
      this.identityError = undefined;
      try {
        const state = await identityFor({
          /* the Contact's own answer wins on the server */
          accountId: m.accountId,
          signatoryContactId: sig.contactId,
          residentStatus: m.residentStatus || null
        });
        if (state && !state.complete) {
          this.openIdentityStep(m, sig, state);
          return;
        }
      } catch (e) {
        /* same recovery as bookForPerson */
      } finally {
        this.busy = false;
      }
    }
    await this.bookCompanyNow(m, sig, {});
  }

  /** The booking itself; `docs` is the signatory identity the step collected. */
  /** chosenResidency: the identity step's answer for a signatory with no residency on file. */
  async bookCompanyNow(m, sig, docs, chosenResidency) {
    this.busy = true;
    this.identityError = undefined;
    /* the signatory's documents, filtered by the residency sent with them; the trade licence
       stays out of the personal fields */
    const residency =
      m.residentStatus || chosenResidency || this.identity.residentStatus || null;
    const send = this.identityToSend(docs, residency);
    try {
      const res = await bookForExistingCustomer({
        accountId: m.accountId,
        ...this.signatoryNameParts(sig, m),
        phone: (sig && sig.phone) || m.phone,
        email: (sig && sig.email) || m.email,
        projectInterest: m.projectInterest || this.projectInterest,
        nationality: m.nationality,
        /* the record, then the identity step's answer, then the company stamp */
        residentStatus: residency,
        /* the signatory's documents, no longer hard-coded null */
        eidNumber: send.eidNumber,
        passportNumber: send.passportNumber,
        customerType: ORGANISATION,
        companyName: m.companyName || m.name,
        passportIssueDate: send.passportIssueDate,
        tradeLicence: m.tradeLicence || this.doc,
        signatoryContactId: (sig && sig.contactId) || null,
        eidExpiry: send.eidExpiry,
        passportExpiry: send.passportExpiryDate
      });
      if (res && res.opportunityId) {
        this.handoff(res.opportunityId);
        return;
      }
      throw new Error("no opportunity");
    } catch (e) {
      /* land on the form with the signatory's details, never the company's */
      this.identityError = reduceError(e);
      this.openForm(m, sig);
    } finally {
      this.busy = false;
    }
  }

  /* a Contact has a first and last name; nameParts is the fallback */
  signatoryNameParts(sig, m) {
    const first = ((sig && sig.firstName) || "").trim();
    const last = ((sig && sig.lastName) || "").trim();
    if (first || last) {
      return { firstName: first || last, lastName: last || first };
    }
    if (sig) {
      return this.nameParts(this.signatoryName(sig));
    }
    /* no contact on file: the create form collects a person */
    return { firstName: "", lastName: "" };
  }

  // stop 3c: who signs for the company

  /** The "Someone else" option. Not an id. */
  get sigOther() {
    return SIG_OTHER;
  }

  openSignatory(m, sigs) {
    this.signatory = {
      match: m,
      companyName: m.companyName || m.name,
      tradeLicence: m.tradeLicence || this.doc,
      options: sigs,
      /* the first on file leads the list (the server returns oldest first) */
      chosen: sigs[0].contactId
    };
    this.identityError = undefined;
  }

  cancelSignatory() {
    this.signatory = undefined;
    this.identityError = undefined;
  }

  handleSignatoryChoice(event) {
    this.signatory = { ...this.signatory, chosen: event.target.value };
  }

  get signatoryFacts() {
    const s = this.signatory || {};
    return [
      { key: "licence", label: LABELS.SIG_FACT_LICENCE, value: s.tradeLicence },
      {
        key: "count",
        label: LABELS.SIG_FACT_CONTACTS,
        value: LABELS.SIG_FACT_ON_FILE.replace("{0}", String((s.options || []).length))
      }
    ].filter((f) => f.value);
  }

  get signatoryChoices() {
    const s = this.signatory || { options: [] };
    /* name, then the address that tells two colleagues apart, then the tag */
    const rows = (s.options || []).map((o, i) => ({
      value: o.contactId,
      text: [
        this.signatoryName(o),
        o.email || o.phone,
        i === 0 ? LABELS.SIG_PRIMARY_TAG : null
      ]
        .filter(Boolean)
        .join(" · "),
      selected: o.contactId === s.chosen
    }));
    rows.push({
      value: SIG_OTHER,
      text: LABELS.SIG_OPTION_OTHER,
      selected: s.chosen === SIG_OTHER
    });
    return rows;
  }

  get signatoryCtaLabel() {
    return this.busy ? LABELS.SIG_CTA_BUSY : LABELS.SIG_CTA;
  }

  async confirmSignatory() {
    if (this.busy || !this.signatory) return;
    const { match, chosen, options } = this.signatory;
    const sig = (options || []).find((o) => o.contactId === chosen);
    this.signatory = undefined;
    if (!sig) {
      /* "Someone else": the same form, bound to the existing company */
      this.openForm(match);
      return;
    }
    await this.bookForCompany(match, sig);
  }

  // stop 3d: the documents a chosen customer still owes

  /** Built from identityFor's answer: usable values arrive locked; gaps arrive empty with the reason code. */
  openIdentityStep(m, sig, state) {
    const values = {};
    const locked = {};
    const reasons = {};
    const place = (field, stored, reasonCode) => {
      if (stored && !reasonCode) {
        values[field] = String(stored);
        locked[field] = true;
      } else {
        values[field] = "";
        if (reasonCode) {
          reasons[field] = { code: reasonCode, date: stored || null };
        }
      }
    };
    place("eidNumber", state.eidNumber, null);
    place("passportNumber", state.passportNumber, null);
    place("eidExpiry", state.eidExpiry, state.eidExpiryReason);
    place("passportIssueDate", state.passportIssueDate, state.passportIssueReason);
    place("passportExpiryDate", state.passportExpiryDate, state.passportExpiryReason);
    this.identityStep = {
      m,
      sig,
      kind: sig ? "company" : "person",
      /* the company leads a company step */
      name: sig ? m.companyName || m.name : m.name,
      /* the record's answer, or none */
      residentStatus: state.residentStatus || "",
      values,
      locked,
      reasons
    };
    this.identityError = undefined;
  }

  cancelIdentityStep() {
    this.identityStep = undefined;
    this.identityError = undefined;
  }

  handleIdentityStepChange(event) {
    const { field, value } = event.detail;
    this.identityStep = {
      ...this.identityStep,
      values: { ...this.identityStep.values, [field]: value }
    };
  }

  /* residency, asked where it cannot be read (the record holds none) */

  get identityStepNeedsResidency() {
    return !!this.identityStep && !this.identityStep.residentStatus;
  }

  get identityStepResidencyChoices() {
    const opts = this.options.residentStatus || ["Resident", "Non-Resident"];
    return opts.map((v) => ({
      value: v,
      selected: !!this.identityStep && this.identityStep.residentStatus === v
    }));
  }

  handleIdentityStepResidency(event) {
    /* documents already typed are kept */
    this.identityStep = {
      ...this.identityStep,
      residentStatus: event.target.value
    };
  }

  get identityStepFacts() {
    const s = this.identityStep || {};
    return [
      s.sig
        ? {
            key: "sig",
            label: LABELS.IDST_FACT_SIGNATORY,
            value: this.signatoryName(s.sig)
          }
        : null,
      s.residentStatus
        ? { key: "res", label: LABELS.IDST_FACT_RESIDENCY, value: s.residentStatus }
        : null
    ].filter(Boolean);
  }

  get identityStepNote() {
    const s = this.identityStep || {};
    /* null on the person branch, so the paragraph does not render */
    return s.kind === "company" ? LABELS.IDST_SIG_NOTE : null;
  }

  get identityStepBlocked() {
    const s = this.identityStep;
    if (!s || this.busy) return true;
    /* blank residency asks for nothing, so the step must not read as complete */
    if (!s.residentStatus) return true;
    return !identitySetComplete(s.residentStatus, s.values, s.locked);
  }

  get identityStepCta() {
    return this.busy ? LABELS.IDST_CTA_BUSY : LABELS.IDST_CTA;
  }

  async confirmIdentityStep() {
    if (this.identityStepBlocked) return;
    const s = this.identityStep;
    this.identityStep = undefined;
    if (s.kind === "company") {
      await this.bookCompanyNow(s.m, s.sig, s.values, s.residentStatus);
      return;
    }
    /* the step's residency travels with its documents */
    await this.bookPersonNow(s.m, s.values, s.residentStatus);
  }

  // stop 3e: the candidates chooser

  /** Opened only by a server answer that performed no DML; the choice books through the existing paths. */
  openCandidates(source, candidates, extra) {
    this.candidateCtx = {
      source,
      rows: candidates || [],
      /* undefined, not the first row: no safe default among strangers sharing a mailbox */
      chosenIndex: undefined,
      ...(extra || {})
    };
    this.identityError = undefined;
  }

  cancelCandidates() {
    /* the face underneath was hidden, never cleared */
    this.candidateCtx = undefined;
  }

  handleCandidatePick(event) {
    if (!this.candidateCtx || this.busy || this.saving) return;
    this.candidateCtx = {
      ...this.candidateCtx,
      chosenIndex: Number(event.currentTarget.dataset.index)
    };
  }

  get candidateRows() {
    const ctx = this.candidateCtx || { rows: [] };
    return (ctx.rows || []).map((m, i) => ({
      key: `c-${i}`,
      index: String(i),
      title: m.name,
      chips: [this.matchedOnChip(m)]
        .filter(Boolean)
        .map((text, n) => ({ key: `c-${i}-${n}`, text })),
      sub: [m.email, m.phone].filter(Boolean).join(" · "),
      meta: [m.residentStatus, m.nationality].filter(Boolean).join(" · "),
      /* the amber treatment the result list uses */
      warn: m.needsQualifyDetails ? LABELS.CAND_ROW_DOCS : null,
      /* the address gap as a second line */
      // a company row carries no address warning
      warn2: m.needsAddress && !m.isOrganisation ? LABELS.MATCH_ROW_ADDRESS : null,
      cls: ctx.chosenIndex === i ? "glass row row--chosen" : "glass row"
    }));
  }

  get candidateLede() {
    const n = (this.candidateCtx && this.candidateCtx.rows.length) || 0;
    return LABELS.CAND_FOUND.replace("{0}", String(n));
  }

  get candidateContinueBlocked() {
    const ctx = this.candidateCtx;
    return this.busy || this.saving || !ctx || ctx.chosenIndex === undefined;
  }

  get candidateActionsBlocked() {
    return this.busy || this.saving;
  }

  get candidateCta() {
    return this.busy || this.saving ? LABELS.SIG_CTA_BUSY : LABELS.SIG_CTA;
  }

  /* 2.42: "Continue With New Details" only while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on */
  get showCandidateNone() {
    const flag = this.options && this.options.newCustomerDespiteMatch;
    return Array.isArray(flag) && flag[0] === "true";
  }

  async confirmCandidates() {
    /* its own guard, before any await: no double booking */
    if (this.candidateContinueBlocked) return;
    const ctx = this.candidateCtx;
    const chosen = ctx.rows[ctx.chosenIndex];
    this.candidateCtx = undefined;
    if (!chosen) return;
    if (ctx.source === "create") {
      this.saving = true;
      this.formError = undefined;
      try {
        /* the matched-customer path with the form's own docs */
        await this.bookPersonNow(
          { ...chosen, projectInterest: this.form.projectInterest || chosen.projectInterest },
          ctx.formDocs || {}
        );
      } finally {
        this.saving = false;
      }
      return;
    }
    await this.qualifyChosen(ctx, chosen);
  }

  /** The qualify route's second call: same args, plus the rep's choice. */
  async qualifyChosen(ctx, chosen) {
    this.busy = true;
    this.qualifyError = undefined;
    try {
      const res = await convertLeadToCustomer({
        ...ctx.qualifyArgs,
        targetAccountId: chosen.accountId
      });
      if (res && res.opportunityId) {
        this.handoff(res.opportunityId);
        return;
      }
      throw new Error("no opportunity");
    } catch (e) {
      /* land back on the qualify panel */
      if (!this.lead) {
        const r = ctx.row || {};
        this.lead = {
          leadId: ctx.qualifyArgs.leadId,
          name: r.name || ctx.name,
          email: r.email,
          phone: r.phone,
          projectInterest: r.projectInterest,
          nationality: ctx.qualifyArgs.nationality || "",
          residentStatus:
            ctx.qualifyArgs.residentStatus || this.identity.residentStatus || "",
          idValues: this.leadIdentitySeed(r),
          idLocked: this.leadIdentityLock(r),
          companyName: r.companyName || ""
        };
      }
      this.qualifyError = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  /** "None of these": the server creates standalone (forceCreate / forceStandalone). */
  async candidateNone() {
    /* 2.42: not offered with the switch off */
    if (!this.showCandidateNone) return;
    if (this.candidateActionsBlocked || !this.candidateCtx) return;
    const ctx = this.candidateCtx;
    this.candidateCtx = undefined;
    if (ctx.source === "create") {
      this.saving = true;
      this.formError = undefined;
      try {
        await this.submitNewCustomer(ctx.formDocs || {}, true);
      } catch (e) {
        this.formError = reduceError(e);
      } finally {
        this.saving = false;
      }
      return;
    }
    this.busy = true;
    this.qualifyError = undefined;
    try {
      const res = await convertLeadToCustomer({
        ...ctx.qualifyArgs,
        forceStandalone: true
      });
      if (res && res.opportunityId) {
        this.handoff(res.opportunityId);
        return;
      }
      throw new Error("no opportunity");
    } catch (e) {
      this.qualifyError = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  /**
   * MSC-158 / MSC-167. The search key answers the residency question: Emirates ID -> Resident,
   * passport -> Non-Resident (a default, not a finding). Without a residency the form renders no
   * document field. Read off this.options, so a renamed option still matches.
   */
  get residentFromSearchKey() {
    const wanted =
      this.searchedDocKey === KEY_EID
        ? "Resident"
        : this.searchedDocKey === KEY_PASSPORT
          ? "Non-Resident"
          : "";
    if (!wanted) return "";
    const options = this.options.residentStatus || [];
    return options.find((v) => normalizeResidentStatus(v) === wanted) || "";
  }

  get doc() {
    return this.identity.documentNumber.trim();
  }

  /** Which personal field the searched value belongs in; a company's licence is neither. */
  /* searchedKey, not searchKey: offerContactKey flips the live key on every miss */
  get searchedDocKey() {
    return this.searchedKey || this.searchKey;
  }

  get docIsEmiratesId() {
    return this.searchedDocKey === KEY_EID && !!this.doc;
  }

  get docIsPassport() {
    return this.searchedDocKey === KEY_PASSPORT && !!this.doc;
  }

  /* First_Name_Mandatory_Check: a single-word name fills both halves */
  nameParts(full) {
    const parts = (full || "").trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return { firstName: "", lastName: "" };
    if (parts.length === 1) return { firstName: parts[0], lastName: parts[0] };
    return {
      firstName: parts.slice(0, -1).join(" "),
      lastName: parts[parts.length - 1]
    };
  }

  /* identity plumbing shared by the qualify panel and the step */

  /** The lead's own identity, as strings for the date inputs. */
  leadIdentitySeed(m) {
    const r = m || {};
    return {
      eidNumber: r.eidNumber || "",
      eidExpiry: r.eidExpiry ? String(r.eidExpiry) : "",
      passportNumber: r.passportNumber || "",
      passportIssueDate: r.passportIssueDate ? String(r.passportIssueDate) : "",
      passportExpiryDate: r.passportExpiryDate ? String(r.passportExpiryDate) : ""
    };
  }

  /** Locked = populated. */
  leadIdentityLock(m) {
    const r = m || {};
    return {
      eidNumber: !!r.eidNumber,
      eidExpiry: !!r.eidExpiry,
      passportNumber: !!r.passportNumber,
      passportIssueDate: !!r.passportIssueDate,
      passportExpiryDate: !!r.passportExpiryDate
    };
  }

  /** A stored date, kept only when the org would still accept it as an expiry. */
  futureOr(d) {
    return d && String(d) > localISODate(0) ? String(d) : "";
  }
  /** A stored date, kept only when the org would still accept it as an issue date. */
  pastOr(d) {
    return d && String(d) <= localISODate(0) ? String(d) : "";
  }

  // qualifying a lead

  async qualifyLead(leadId, nationality, residentStatus, row) {
    this.busy = true;
    try {
      const args = { leadId, nationality, residentStatus };
      const res = await convertLeadToCustomer(args);
      /* before the opportunityId check: candidates back means nothing was converted */
      if (res && res.candidates && res.candidates.length) {
        this.openCandidates("qualify", res.candidates, {
          name: (row && row.name) || "",
          row: row || null,
          qualifyArgs: args
        });
        return;
      }
      if (res && res.opportunityId) {
        this.handoff(res.opportunityId);
        return;
      }
      throw new Error("no opportunity");
    } catch (e) {
      /* an unanticipated validation rule must leave the rep somewhere they can act */
      const r = row || {};
      this.lead = {
        leadId,
        name: r.name,
        email: r.email,
        phone: r.phone,
        projectInterest: r.projectInterest,
        nationality: nationality || "",
        residentStatus: residentStatus || this.identity.residentStatus || "",
        /* same seeding as the direct route into the panel */
        idValues: this.leadIdentitySeed(r),
        idLocked: this.leadIdentityLock(r),
        companyName: r.companyName || ""
      };
      this.qualifyError = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  handleQualifyField(event) {
    this.lead = { ...this.lead, [event.target.dataset.field]: event.target.value };
  }

  /* the panel's identity fields */
  handleQualifyIdentity(event) {
    const { field, value } = event.detail;
    this.lead = {
      ...this.lead,
      idValues: { ...(this.lead.idValues || {}), [field]: value }
    };
  }

  cancelQualify() {
    /* 2.36: leaving the seeded panel abandons the seed - the page restores the plain picker
       (buyer-type switch included) */
    if (this.lead && this.lead.seeded) {
      this.dispatchEvent(new CustomEvent("seedcancel"));
    }
    this.lead = undefined;
    this.qualifyError = undefined;
  }

  get qualifyReady() {
    /* and the derived identity set, complete and in shape */
    return !!(
      this.lead &&
      this.lead.nationality &&
      this.lead.residentStatus &&
      identitySetComplete(this.lead.residentStatus, this.lead.idValues, this.lead.idLocked)
    );
  }
  get qualifyBlocked() {
    return !this.qualifyReady || this.busy;
  }
  get qualifyLabel() {
    return this.busy ? "Adding…" : "Add as customer";
  }

  get nationalityChoices() {
    return (this.options.nationality || []).map((v) => ({
      value: v,
      selected: !!this.lead && this.lead.nationality === v
    }));
  }
  get residentChoices() {
    return (this.options.residentStatus || []).map((v) => ({
      value: v,
      selected: !!this.lead && this.lead.residentStatus === v
    }));
  }

  /**
   * 2.43 - R2-01: what "Add as customer" will make, before it is made. The Sales App decides the same
   * way (ConvertLeadProcessMRE: a lead with a Company converts to an organisation account).
   */
  get leadCustomerType() {
    const l = this.lead || {};
    return l.companyName ? `${ORGANISATION} · ${l.companyName}` : INDIVIDUAL;
  }

  /** The lead's own details, read-only. */
  get leadFacts() {
    const l = this.lead || {};
    return [
      { key: "type", label: "Customer type", value: this.leadCustomerType },
      { key: "email", label: "Email", value: l.email },
      { key: "phone", label: "Phone", value: l.phone },
      { key: "project", label: "Project of interest", value: l.projectInterest }
    ].filter((r) => r.value);
  }

  async confirmQualify() {
    if (this.qualifyBlocked) return;
    this.busy = true;
    this.qualifyError = undefined;
    try {
      /* only the set this residency needs is sent */
      const needs = identityNeedsFor(this.lead.residentStatus);
      const v = this.lead.idValues || {};
      const args = {
        leadId: this.lead.leadId,
        nationality: this.lead.nationality,
        residentStatus: this.lead.residentStatus,
        eidNumber: needs.eidNumber ? v.eidNumber || null : null,
        eidExpiry: needs.eidExpiry ? v.eidExpiry || null : null,
        passportNumber: needs.passportNumber ? v.passportNumber || null : null,
        passportIssueDate: needs.passportIssueDate ? v.passportIssueDate || null : null,
        passportExpiry: needs.passportExpiryDate ? v.passportExpiryDate || null : null
      };
      const res = await convertLeadToCustomer(args);
      /* more than one account holds this lead's details: the rep chooses */
      if (res && res.candidates && res.candidates.length) {
        this.openCandidates("qualify", res.candidates, {
          name: this.lead.name || "",
          row: null,
          qualifyArgs: args
        });
        return;
      }
      if (!res || !res.opportunityId) {
        this.qualifyError = "That lead was qualified but the booking could not be started.";
        return;
      }
      this.handoff(res.opportunityId);
    } catch (e) {
      this.qualifyError = reduceError(e);
    } finally {
      this.busy = false;
    }
  }

  // stop 3b: creating a new customer

  /** Reachable from a search that found nobody, or from a match that needs more than its record holds. */
  openForm(known, sig) {
    const m = known || {};
    /* for a company the person on this form is the authorised contact, never the company itself */
    /* isOrgMatch reads a matched row; with none, the buyer type answers */
    const org = known ? this.isOrgMatch(m) : this.isOrganisation;
    const sigs = this.signatoriesOf(m);
    const person = sig || (sigs.length === 1 ? sigs[0] : null);
    this.form = {
      ...(org ? this.signatoryNameParts(person, m) : this.nameParts(m.name)),
      phone: (person && person.phone) || m.phone || "",
      email: (person && person.email) || m.email || "",
      projectInterest: m.projectInterest || this.projectInterest || "",
      nationality: m.nationality || "",
      /* on a company's form this residency is the authorised contact's; the company's is never used */
      residentStatus: org
        ? m.residentStatus || ""
        : m.residentStatus ||
          this.identity.residentStatus ||
          this.residentFromSearchKey,
      documentNumber: this.doc,
      customerType: this.identity.customerType || INDIVIDUAL,
      companyName: org ? m.companyName || m.name || "" : m.companyName || "",
      /* blank on purpose: "not asked" */
      isAuthorisedSignatory: ""
    };
    /* the identity set: an individual's searched document lands in its field, anything a matched
       record knows is carried in except a date the org would refuse; an organisation's set starts empty */
    /* which field the searched document belongs in is read off the declared key */
    this.formIdentity = org
      ? {}
      : {
          eidNumber: m.eidNumber || (this.docIsEmiratesId ? this.doc : ""),
          eidExpiry: this.futureOr(m.eidExpiry),
          passportNumber: m.passportNumber || (this.docIsPassport ? this.doc : ""),
          passportIssueDate: this.pastOr(m.passportIssueDate),
          passportExpiryDate: this.futureOr(m.passportExpiryDate)
        };
    /* the company this form completes, when the org already holds it */
    this.formAccountId = org ? m.accountId || null : null;
    this.formContactId = (org && person && person.contactId) || null;
    /* what came off the matched record is accepted as it stands */
    this.acceptContact("email", this.form.email);
    this.acceptContact("phone", this.form.phone);
    this.formError = undefined;
    this.creating = true;
  }

  /* the demo autofill block that stood here is deleted (it wrote @example.com onto real accounts) */

  handleCreateNew() {
    this.openForm();
  }

  closeForm() {
    this.creating = false;
    this.formError = undefined;
    this.contact = { email: idleContact(), phone: idleContact() };
    this._contactPending = {};
    /* cleared with the form */
    this.formAccountId = undefined;
    this.formContactId = undefined;
    /* and the identity set */
    this.formIdentity = {};
    /* and the chooser */
    this.candidateCtx = undefined;
  }

  /* the create form's identity fields */
  handleFormIdentity(event) {
    const { field, value } = event.detail;
    this.formIdentity = { ...this.formIdentity, [field]: value };
  }

  handleField(event) {
    const field = event.currentTarget.dataset.f;
    /* no mask here: documentNumber renders for an organisation only */
    const value = event.target.value;
    this.form = { ...this.form, [field]: value };
    /* a tick or an error is about the value it was given */
    if ((field === "email" || field === "phone") && this.contact[field].value !== value.trim()) {
      this.resetContact(field);
    }
  }

  /* email and mobile checked as entered: shape locally, then Loqate; blank passes */

  handleContactBlur(event) {
    const field = event.currentTarget.dataset.f;
    if (field !== "email" && field !== "phone") return;
    this.validateContact(field, event.target.value);
  }

  /** Resolves true when the value may be saved. */
  async validateContact(field, rawValue) {
    const kind = field === "email" ? "email" : "phone";
    const value = (rawValue || "").trim();
    const current = this.contact[field];
    if (!value) {
      this.resetContact(field);
      return true;
    }
    if (kind === "email" && !isValidEmailShape(value)) {
      this.setContact(field, { status: "bad", value, message: LABELS.CONTACT_EMAIL_INVALID });
      return false;
    }
    if (kind === "phone" && !isValidPhone(value)) {
      this.setContact(field, { status: "bad", value, message: LABELS.CONTACT_PHONE_SHAPE });
      return false;
    }
    /* already answered for this value, or being answered; an unreachable Loqate is asked again */
    if (current.value === value) {
      if (current.status === "ok") return true;
      if (current.status === "bad" && !current.retry) return false;
      if (current.status === "checking" && this._contactPending[field]) {
        return this._contactPending[field];
      }
    }
    this.setContact(field, { status: "checking", value, message: "" });
    const pending = this.runContactCheck(field, kind, value);
    this._contactPending[field] = pending;
    const ok = await pending;
    if (this._contactPending[field] === pending) delete this._contactPending[field];
    return ok;
  }

  async runContactCheck(field, kind, value) {
    let ok = false;
    let message = "";
    let retry = false;
    try {
      const res =
        kind === "email" ? await checkEmail({ email: value }) : await checkPhone({ phone: value });
      ok = !!(res && res.isValid);
      message = ok
        ? ""
        : (res && res.message) ||
          (kind === "email" ? LABELS.CONTACT_EMAIL_INVALID : LABELS.CONTACT_PHONE_INVALID);
    } catch (e) {
      ok = false;
      retry = true;
      message = kind === "email" ? LABELS.CONTACT_EMAIL_UNCHECKED : LABELS.CONTACT_PHONE_UNCHECKED;
    }
    /* only if the rep has not moved on */
    const now = this.contact[field];
    if (now.status === "checking" && now.value === value) {
      this.setContact(field, { status: ok ? "ok" : "bad", value, message, retry });
    }
    return ok;
  }

  setContact(field, patch) {
    this.contact = { ...this.contact, [field]: { ...this.contact[field], ...patch } };
  }

  resetContact(field) {
    this.setContact(field, idleContact());
  }

  /** A value that came off an existing record is taken as it is. */
  acceptContact(field, value) {
    const v = (value || "").trim();
    this.setContact(field, v ? { status: "ok", value: v, message: "", retry: false } : idleContact());
  }

  /** Before the round trip: both fields. */
  async ensureContactsValid() {
    const results = await Promise.all([
      this.validateContact("email", this.form.email),
      this.validateContact("phone", this.form.phone)
    ]);
    return results.every(Boolean);
  }

  get emailState() {
    return contactView(this.contact.email);
  }
  get phoneState() {
    return contactView(this.contact.phone);
  }
  get contactChecking() {
    return this.contact.email.status === "checking" || this.contact.phone.status === "checking";
  }
  get contactRefused() {
    return this.contact.email.status === "bad" || this.contact.phone.status === "bad";
  }

  get projectChoices() {
    return (this.projects || []).map((p) => ({
      label: p,
      value: p,
      selected: p === this.form.projectInterest
    }));
  }

  get formResidentChoices() {
    return (this.options.residentStatus || []).map((v) => ({
      value: v,
      selected: this.form.residentStatus === v
    }));
  }
  get formNationalityChoices() {
    return (this.options.nationality || []).map((v) => ({
      value: v,
      selected: this.form.nationality === v
    }));
  }

  /** Block_Special_Characters_In_Name, mirrored at the field: an AND of two failures. */
  get nameRuleError() {
    const first = this.form.firstName.trim();
    const last = this.form.lastName.trim();
    if (!first || !last) return null;
    return !isPlainName(first) && !isPlainName(last) ? LABELS.CREATE_NAME_INVALID : null;
  }

  /** Mirrors what the org enforces. */
  get saveDisabled() {
    if (this.saving) return true;
    if (!this.form.firstName.trim()) return true; // First_Name_Mandatory_Check
    if (!this.form.lastName.trim()) return true;
    // Block_Special_Characters_In_Name
    if (this.nameRuleError) return true;
    if (!this.form.projectInterest) return true;
    // Nationality_and_UAE_Resident_are_mandato
    if (!this.form.nationality || !this.form.residentStatus) return true;
    /* the derived identity set, complete and in shape (c/mscEoiUtils.identitySetComplete) */
    if (!identitySetComplete(this.form.residentStatus, this.formIdentity, null)) return true;
    /* a blank Company converts the lead to a Person Account */
    if (this.formIsOrganisation && !this.form.companyName.trim()) return true;
    /* the licence is required: stampCompanyLicence writes it to UnifiedNumber__c, which
       checkBookingEligibility blocks on, and it is the only key a company is searched by */
    if (this.formIsOrganisation && !(this.form.documentNumber || "").trim()) return true;
    /* MSC-139: email and mobile are required; sendKYCForm refuses without them */
    if (!this.form.phone.trim() || !this.form.email.trim()) return true;
    /* a refused email or mobile; not while a check is running */
    if (this.contactRefused) return true;
    return false;
  }

  /* MSC-139. Yes / No, and a blank that stays blank. 2.41: its own name; it shared
     signatoryChoices with the company chooser above and replaced it */
  get authorisedSignatoryChoices() {
    return ["Yes", "No"].map((v) => ({
      value: v,
      label: v,
      selected: this.form.isAuthorisedSignatory === v
    }));
  }

  /* the form's own answer, not the search's */
  get formIsOrganisation() {
    return this.form.customerType === ORGANISATION;
  }

  /* true when this form is completing a company the org already holds */
  get formCompletesCompany() {
    return this.formIsOrganisation && !!this.formAccountId;
  }

  /** The person named on an organisation lead becomes its primary contact. */
  get personLegend() {
    /* the legend says the form is adding a contact */
    if (this.formCompletesCompany) return LABELS.SIG_NEW_LEGEND;
    return this.formIsOrganisation ? LABELS.ORG_CONTACT_LEGEND_CONSOLE : "Customer";
  }

  /** Said under the locked Company name. */
  get companyNameHint() {
    return this.formCompletesCompany ? LABELS.SIG_NEW_NOTE : null;
  }

  get saveLabel() {
    if (this.saving) return this.contactChecking ? "Checking…" : "Creating…";
    return "Create and continue";
  }

  async handleCreate() {
    if (this.saveDisabled) return;
    this.saving = true;
    this.formError = undefined;
    /* the email and mobile as they stand, before anything is written */
    const contactsOk = await this.ensureContactsValid();
    if (!contactsOk) {
      this.saving = false;
      this.formError = this.contactFormError;
      return;
    }
    try {
      const doc = (this.form.documentNumber || "").trim();
      const org = this.formIsOrganisation;
      /* the identity set, filtered by what this residency needs */
      const needs = identityNeedsFor(this.form.residentStatus);
      const idv = this.formIdentity || {};
      const docs = {
        eidNumber: needs.eidNumber ? (idv.eidNumber || "").trim() || null : null,
        eidExpiry: needs.eidExpiry ? idv.eidExpiry || null : null,
        passportNumber: needs.passportNumber ? (idv.passportNumber || "").trim() || null : null,
        passportIssueDate: needs.passportIssueDate ? idv.passportIssueDate || null : null,
        passportExpiry: needs.passportExpiryDate ? idv.passportExpiryDate || null : null
      };
      /* an existing company with a new contact: not createCustomer, which would raise a second Account */
      if (this.formCompletesCompany) {
        const booked = await bookForExistingCustomer({
          accountId: this.formAccountId,
          firstName: this.form.firstName.trim(),
          lastName: this.form.lastName.trim(),
          phone: this.form.phone.trim(),
          email: this.form.email.trim(),
          projectInterest: this.form.projectInterest,
          nationality: this.form.nationality,
          residentStatus: this.form.residentStatus,
          /* the contact's documents; the server reads the chosen Contact first */
          eidNumber: docs.eidNumber,
          passportNumber: docs.passportNumber,
          customerType: ORGANISATION,
          companyName: this.form.companyName.trim(),
          passportIssueDate: docs.passportIssueDate,
          tradeLicence: doc,
          /* null unless the rep chose an existing contact */
          signatoryContactId: this.formContactId || null,
          eidExpiry: docs.eidExpiry,
          passportExpiry: docs.passportExpiry,
          // MSC-139; the same answer on the existing-company path
          isAuthorisedSignatory: this.form.isAuthorisedSignatory || null
        });
        if (!booked || !booked.opportunityId) {
          throw new Error("no opportunity");
        }
        /* no verification flag: a company's identity checks belong to Sales Operations */
        this.handoff(booked.opportunityId);
        return;
      }
      await this.submitNewCustomer(docs, false);
    } catch (e) {
      // the Apex message names where the record went
      this.formError = reduceError(e);
    } finally {
      this.saving = false;
    }
  }

  /** The createCustomer round trip, shared by Create and continue and by "None of these". */
  async submitNewCustomer(docs, forceCreate) {
    const doc = (this.form.documentNumber || "").trim();
    const org = this.formIsOrganisation;
    const res = await createCustomer({
      firstName: this.form.firstName.trim(),
      lastName: this.form.lastName.trim(),
      phone: this.form.phone.trim(),
      email: this.form.email.trim(),
      projectInterest: this.form.projectInterest,
      nationality: this.form.nationality,
      residentStatus: this.form.residentStatus,
      /* each document in the field its kind belongs to */
      eidNumber: docs.eidNumber,
      passportNumber: docs.passportNumber,
      customerType: this.form.customerType || null,
      companyName: org ? this.form.companyName.trim() : null,
      passportIssueDate: docs.passportIssueDate,
      tradeLicence: org ? doc : null,
      eidExpiry: docs.eidExpiry,
      passportExpiry: docs.passportExpiry,
      /* true only from the chooser's "None of these" */
      forceCreate: forceCreate === true,
      // MSC-139; the server writes nothing unless "Yes"
      isAuthorisedSignatory: org ? this.form.isAuthorisedSignatory || null : null
    });
    /* before the opportunityId check: the server may have created nothing */
    if (res && res.candidates && res.candidates.length) {
      this.openCandidates("create", res.candidates, {
        name: this.verifyCustomerName || "",
        /* carried under both keys */
        formDocs: { ...docs, passportExpiryDate: docs.passportExpiry }
      });
      return;
    }
    if (!res || !res.opportunityId) {
      // a silent handoff of undefined would claim a customer we have not got
      this.formError = "The customer was created but the booking could not be started.";
      return;
    }
    /* the form stays up: the verification dialog opens over it */
    /* a new customer is flagged so the page can ask how to verify; matched routes pass no flag */
    this.handoff(res.opportunityId, {
      isNewCustomer: true,
      customerName: this.verifyCustomerName,
      canSendVerification: this.verifyCanSend,
      verificationBlockedReason: this.verifyBlockedReason
    });
  }

  /* the banner by the button says which field to look at */
  get contactFormError() {
    const bad = [];
    if (this.contact.email.status === "bad") bad.push("email address");
    if (this.contact.phone.status === "bad") bad.push("mobile number");
    if (!bad.length) return undefined;
    return LABELS.CONTACT_FIX_ABOVE.replace("{0}", bad.join(" and "));
  }

  /* the verification choice */

  get verifyCustomerName() {
    return `${this.form.firstName || ""} ${this.form.lastName || ""}`.trim() || null;
  }

  /**
   * Whether the link can be sent, answered from the form just submitted. A hint; the server
   * re-checks against the saved account.
   */
  get verifyCanSend() {
    if (this.formIsOrganisation) {
      return false;
    }
    return !!(
      (this.form.email || "").trim() &&
      (this.form.phone || "").trim() &&
      this.form.nationality &&
      this.form.residentStatus
    );
  }

  get verifyBlockedReason() {
    if (this.formIsOrganisation) {
      /* one sentence for one fact, from c/mscLabels */
      return LABELS.KYC_CORPORATE;
    }
    const missing = [];
    if (!(this.form.email || "").trim()) missing.push("email address");
    if (!(this.form.phone || "").trim()) missing.push("mobile number");
    if (!this.form.nationality) missing.push("nationality");
    if (!this.form.residentStatus) missing.push("residency");
    return missing.length
      ? `Add the customer's ${missing.join(", ")} before sending the verification link.`
      : null;
  }

  handoff(opportunityId, extra) {
    this.dispatchEvent(
      new CustomEvent("opportunityselect", {
        detail: { opportunityId, ...(extra || {}) },
        bubbles: true,
        composed: true
      })
    );
  }

  /** Identity lookups, lead qualification and customer creation all block. */
  get isBusy() {
    return !!(this.busy || this.saving);
  }
}