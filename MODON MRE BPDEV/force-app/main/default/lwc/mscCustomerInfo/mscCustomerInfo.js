/**
 * Section 2 - Customer Information.
 *
 * Version  Author      Date         Detail
 * 3.5      Aurelix Dev 27 Sep 2026  An expiry of today is accepted (errors and isRenewable), as MODON's "< TODAY()"
 *                                   rules accept it (Sales App parity).
 * 3.4      Aurelix Dev 21 Sep 2026  Native selects again. 3.3's c/mscPicklist for
 *                                   nationality and residency is withdrawn: inside the booking pop-up
 *                                   the drawn list was cut off, search box and all, and the grey pop-up
 *                                   it avoided only shows on a Linux desktop, not on the reps' Windows
 *                                   and Mac machines (SCW-137).
 * 3.2      Aurelix Dev 17 Sep 2026  MSC-174 (B2). A resident carries a passport too now
 *                                   (decision of 17 Sep; the table is
 *                                   AurelixIdentityRuleService.needsFor, mirrored in
 *                                   c/mscEoiUtils). The facts summary shows the passport
 *                                   for both residencies and its date sanity runs for
 *                                   both; the Emirates ID pair stays resident-only, the
 *                                   country of residence non-resident-only. No input,
 *                                   gate key or template changed - the identity inputs
 *                                   live in the identity step, not on this card.
 * 3.0      Aurelix Dev 22 Aug 2026  MSC-137. ONE CARD, ONE JOB. The card asks for
 *                                   what THIS BOOKING needs and states everything
 *                                   else. Three regions, in the order the rep meets
 *                                   them: the FACTS the record already holds, said
 *                                   in a line instead of drawn as a column of
 *                                   readonly boxes; the GATE, which is exactly the
 *                                   fields UnitSearchLwcController
 *                                   .checkBookingEligibility blocks on - nationality
 *                                   and resident status for a person account, the
 *                                   licence number and billing address for an
 *                                   organisation; and VERIFICATION, everything the
 *                                   KYC link and compliance need, behind one closed
 *                                   row carrying the count of what is still missing.
 *                                   A company's card went from thirteen inputs to
 *                                   one address, an individual's from nine to two.
 *                                   ONLY THE GATE BLOCKS. Every starred field used
 *                                   to be required, including fields no gate in the
 *                                   org reads. That was survivable while they were
 *                                   all on screen and is not survivable behind a
 *                                   fold: a required field folded away is an error
 *                                   the rep is refused for and cannot see. Required
 *                                   now means one thing - the booking is blocked
 *                                   without it - and everything else keeps only its
 *                                   FORMAT rule. Date of establishment is the
 *                                   consequence worth naming: Passfort still errors
 *                                   a company transaction without it, so it is
 *                                   counted as a verification gap and asked for in
 *                                   the block, but it no longer holds up a booking.
 *                                   THE 1.9 WHOLE-CARD FOLD IS GONE with the problem
 *                                   it solved. There is no wall of confirmed boxes
 *                                   left to hide, and a card that folded into a
 *                                   summary and then unfolded into a second fold
 *                                   would be two doors to one room. collapsedOnArrival
 *                                   stays DECLARED - c/mscBookingPage still binds it.
 *                                   NOTHING LEAVES THE CONSOLE. Every field is still
 *                                   rendered, still written and still saved by the
 *                                   same payload; the fold is a move, not a delete,
 *                                   so the verification popup can lift this block
 *                                   wholesale when it ships.
 * 2.11     Aurelix Dev 22 Aug 2026  MSC-136. THE CARD STOPS ASKING FOR WHAT SIGNZY
 *                                   READS OFF THE LICENCE. Four fields leave the
 *                                   organisation branch - licence expiry, legal
 *                                   structure, business activity and VAT number -
 *                                   because the trade-licence check fills every one
 *                                   of them from the document itself:
 *                                   CustomerKYCHandler writes TradeLicenseExpiryDate__c
 *                                   and LegalStructure__c on the early-data callback,
 *                                   and UAEVATRegisterNumber__c, Nature_Of_Business__c
 *                                   and the rest off SignzyTradeLicenseWrapper. The rep
 *                                   was copying, by hand and from the same piece of
 *                                   paper, data the journey was about to overwrite -
 *                                   four boxes between a company and its booking, none
 *                                   of which any gate reads. businessActivity is the
 *                                   plainest case: it wrote Account.Description, which
 *                                   nothing in the org consumes at all.
 *                                   WHAT STAYS, AND WHY. Company name and licence
 *                                   number are the account's identity - the licence
 *                                   number is copied to UnifiedNumber__c, the field
 *                                   checkBookingEligibility blocks an organisation on.
 *                                   Date of establishment stays REQUIRED: it is the one
 *                                   company field with a hard downstream dependency -
 *                                   PassfortTransactionProcessHelper errors the company
 *                                   transaction outright when incorporation_date is
 *                                   null - and compliance is not this change's to move.
 *                                   The four keys leave the save payload with their
 *                                   inputs. companyUpdate keeps its properties
 *                                   DECLARED and skips a null, exactly as the billing
 *                                   arm has since 1.47, so no Apex changes and nothing
 *                                   already on a record is touched.
 *                                   THE INDIVIDUAL BRANCH IS NOT TOUCHED. Every field
 *                                   removed sits inside lwc:if={isOrganisation}; the
 *                                   person block, its identity sets and every rule in
 *                                   `errors` are byte-identical.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.1      Aurelix IT  06 Aug 2026  Hosts the identity-verification panel below the form.
 * 1.2      Aurelix IT  10 Aug 2026  Individual / Organisation after residency, and the
 *                                   company fields Passfort needs for a corporate buyer.
 * 1.3      Aurelix IT  10 Aug 2026  Type asked BEFORE residency; company wording moved to
 *                                   c/mscLabels in plain words; non-UAE companies blocked
 *                                   with an explanation rather than a passport-rule error.
 * 1.6      Aurelix IT  11 Aug 2026  Billing postal code - checkBookingEligibility requires
 *                                   it for an organisation and the form never asked.
 * 1.5      Aurelix IT  11 Aug 2026  An existing customer is read-only: every field
 *                                   disabled, email and mobile shown masked, and the Save
 *                                   button gone. The sales team cannot alter a customer
 *                                   record from the console.
 * 1.4      Aurelix IT  10 Aug 2026  Both questions on one row. Residency swapped from
 *                                   c-msc-residency-toggle to pills so the pair fits; its
 *                                   card hint survives as one line below, for the answer
 *                                   actually chosen.
 * 1.7      Aurelix IT  12 Aug 2026  autocomplete="off" on every input. Chrome infers one
 *                                   form per page, so the name and email in its "Save
 *                                   address?" prompt came from this card.
 * 1.8      Aurelix IT  12 Aug 2026  Last name no longer falls back to the full name.
 * 1.9      Aurelix IT  12 Aug 2026  On-screen keyboard hints: numeric for Emirates ID, VAT
 *                                   and postal code, uppercase for passport and licence, word
 *                                   caps for names. Hints only - nothing submitted changes.
 * 2.10     Aurelix Dev 22 Aug 2026  MSC-133. The "Also recorded as the company's
 *                                   Unified Number" hint is gone from under Licence
 *                                   number. It named an internal field, not anything
 *                                   printed on the licence in the rep's hand. The
 *                                   wording stays in c/mscLabels - eligibility still
 *                                   uses the alias in its own sentence.
 * 2.9      Aurelix Dev 22 Aug 2026  MSC-130. The on-file note appears only when
 *                                   something is missing. It was keyed on whether any
 *                                   value was ON FILE - true of every established
 *                                   customer - so a card with nothing to do carried an
 *                                   instruction to do something. It is keyed on the
 *                                   GAP now: at least one field the rep can write that
 *                                   the record does not hold, and at least one value
 *                                   that is on file for the sentence to be true about.
 * 2.8      Aurelix Dev 22 Aug 2026  MSC-129. NO AMBER UNDER A FORM FIELD. Each
 *                                   read-only field carried a sentence saying why it
 *                                   could not be edited. That was proportionate when
 *                                   two or three fields were locked; since the card
 *                                   became fill-only most of them are, and a card of
 *                                   facts wore a column of warnings. The reason is
 *                                   said once, at the top, by the on-file note - which
 *                                   is what 2.0 already decided for the ON_FILE code
 *                                   and is now true of every code. mk stops computing
 *                                   `why`: nothing read it.
 *                                   TWO AMBER LINES SURVIVE, and neither is a lock
 *                                   reason - both tell the rep to DO something: the
 *                                   address line (checkBookingEligibility blocks the
 *                                   booking on postal code and country) and the
 *                                   no-signatory line under the AML pills, without
 *                                   which those pills are dead and silent.
 * 2.7      Aurelix Dev 22 Aug 2026  MSC-127. A DATE IS EXEMPT ONLY WHILE IT IS
 *                                   UNUSABLE. 2.3 exempted every date from fill-only
 *                                   so a renewal could be typed - but that left a
 *                                   date the rep had just filled and saved sitting
 *                                   editable, the one field on a completed card that
 *                                   never turned into a fact. The reason for the
 *                                   exemption was never "it is a date": it was that
 *                                   an expiry can lapse with nobody touching it, and
 *                                   a lapsed one is what blocks the booking. So the
 *                                   exemption is that condition, tested - blank, or
 *                                   an expiry not in the future, or an issue date in
 *                                   the future. A valid stored date is a fact like
 *                                   any other, and dateOfEstablishment - which cannot
 *                                   go stale - stops being exempt at all.
 * 2.6      Aurelix Dev 22 Aug 2026  MSC-125. A SAVE BUTTON THAT DID NOTHING, twice
 *                                   over.
 *                                   (a) On a complete customer the only editable key
 *                                       left was an exempt DATE - populated, correct
 *                                       and untouched. Save was offered, the click ran
 *                                       a save that wrote the value it already held,
 *                                       and the screen did not move. showSave now asks
 *                                       whether there is anything to COMMIT: a blank
 *                                       the rep can fill, or a value they have actually
 *                                       changed. Stateless - form against record - so
 *                                       it needs no flag and cannot go stale, and it
 *                                       is what retires the button after a save.
 *                                   (b) errors cleared itself for SERVER-locked fields
 *                                       only, so a fill-only-locked field carrying a
 *                                       value the org would reject could fail isValid
 *                                       while mk suppressed its sentence - a silent
 *                                       dead button. A field that is not the rep's to
 *                                       fix from here can never block Save; that is
 *                                       what 2.0 said and it now reads lockFor.
 * 2.5      Aurelix Dev 22 Aug 2026  MSC-124. The fill-only rule reads the RECORD, not
 *                                   the form. 2.3 asked whether the form field held a
 *                                   value, which is true from the rep's FIRST
 *                                   KEYSTROKE - so a blank field turned readonly as
 *                                   soon as they began filling it, blocking the one
 *                                   thing fill-only exists to allow. It is the stored
 *                                   value that decides whether a write would be an
 *                                   amendment, and reading it is also what completes
 *                                   the cycle the card is meant to have: fill the
 *                                   blanks, save, the parent hands back the saved
 *                                   customer, every filled field turns to a fact and
 *                                   Save retires itself because there is nothing
 *                                   editable left to commit.
 * 2.4      Aurelix Dev 22 Aug 2026  MSC-123. The amber sentence under UAE Resident
 *                                   Status is gone. Since 2.3 a readonly residency
 *                                   sits among readonly neighbours, and the card's
 *                                   on-file note already says saved values cannot be
 *                                   changed here - the line explained a rule the
 *                                   whole card now follows. Rendering only: the
 *                                   server still sends RESIDENCY_SAVED and the
 *                                   wording stays in c/mscLabels.
 * 2.3      Aurelix Dev 22 Aug 2026  MSC-122. FILL-ONLY. This card writes to the
 *                                   Account and the Contact - the customer MASTER,
 *                                   shared by every booking that customer has ever
 *                                   had. A rep amending an email here was amending it
 *                                   on all of them: Passfort correspondence, EOI
 *                                   links, SPA delivery, every future notice, on ten
 *                                   live bookings as readily as on one, with nothing
 *                                   on screen saying so. A populated value is a FACT
 *                                   now; a blank is the rep's to fill. That is MODON's
 *                                   own posture - Sales_user_cant_change_Passport_and_
 *                                   EID guards POPULATED fields, and the lead qualify
 *                                   panel can only fill blanks - and it is what the
 *                                   card's own note has promised since 2.0.
 *                                   THE EXCEPTION IS DATES. A saved date goes stale
 *                                   with nobody touching it, and a lapsed expiry is
 *                                   precisely what blocks the booking, so the renewal
 *                                   can still be typed. Read-only comes from the same
 *                                   ON_FILE code the server sends, so it renders
 *                                   exactly as an on-file lock always has: quiet, and
 *                                   covered by the note rather than a wall of amber.
 * 2.2      Aurelix Dev 22 Aug 2026  MSC-121. THE TWO QUESTIONS AT THE TOP OF THE CARD
 *                                   ARE GONE. Buying as and Residency were answered on
 *                                   the step before this one and arrived here locked -
 *                                   two label-and-pill blocks, one dead option each,
 *                                   re-asking what the rep had just told us. Buyer type
 *                                   leaves entirely (the server locks it whenever an
 *                                   account exists - changing it means a different
 *                                   account, not an edit, and the folded summary still
 *                                   states it). Residency MOVES down among the
 *                                   customer's other details as a normal field, named
 *                                   the way the record names it - Account's
 *                                   UAE_Resident_Status__pc, "UAE Resident Status",
 *                                   with MODON's own values. It keeps everything it
 *                                   had: the lock and its reason, the blank-is-an-error
 *                                   rule, and the residencychange event the booking
 *                                   page listens to in order to re-run
 *                                   getRequiredDocuments.
 * 2.1      Aurelix IT  22 Aug 2026  MSC-113. THE SIGNATORY'S DECLARATION, AND A CARD
 *                                   THAT CAN BE WALKED TO. realBeneficiary: a Yes/No
 *                                   pill pair on the organisation branch - the AML
 *                                   question Passfort answers 'no' for by default
 *                                   because nobody was asking it. Unanswered until
 *                                   the rep actually taps; a stored false renders
 *                                   unanswered too (the checkbox cannot say "never
 *                                   asked"), and only an explicit answer travels.
 *                                   focusFirstGap(): the same contract mscAddress
 *                                   has - the parent's held Continue now walks to
 *                                   the first gap this card owns (licence number,
 *                                   establishment date, nationality...), which is
 *                                   how an organisation's block sentence points at
 *                                   its fix. ORG_LICENCE_NO_HINT names the licence
 *                                   number's official alias (Unified Number) under
 *                                   the one field that edits it.
 * 2.0      Aurelix IT  22 Aug 2026  MSC-112. THE CARD STOPS BEING BLANKET-LOCKED. The
 *                                   server now ships lockReasons on the customer - the
 *                                   per-field edit policy - and each field is editable
 *                                   or READONLY with a reason: amber where an org rule
 *                                   is why, one quiet note for plain on-file values.
 *                                   The @api locked boolean is gone with the disabled=
 *                                   inputs it drove. Identity gains its dates, country
 *                                   of residence becomes a picklist seeded from the
 *                                   record, First Name is marked required (the org
 *                                   demands it everywhere else), locked email / mobile /
 *                                   documents render only masked values, the billing
 *                                   block is a read-only line with Edit address
 *                                   (c/mscAddress is the one writer - GAP 41), the
 *                                   folded summary formats dates and speaks c/mscLabels,
 *                                   and Save sends editable fields only - a locked key
 *                                   travels as null, so a masked value can never
 *                                   round-trip into a record.
 */

import { LightningElement, api, track } from "lwc";
import { LABELS } from "c/mscLabels";
import { formatDate } from "c/modonSalesFormat";

/**
 * Section 2 - Customer Information.
 *
 * Residency sits at the top because it decides which fields below are required
 * (Modon comment 6): Emirates ID for a Resident, passport plus country of residence
 * for a Non-Resident.
 *
 * Errors show on blur rather than keystroke, and every field is touched on submit so
 * all outstanding problems appear at once - the modonSpRegistration pattern.
 */
/* 1.2 - the exact strings the Apex tests with equalsIgnoreCase. */
const INDIVIDUAL = "Individual";
const ORGANISATION = "Organisation";
/* 1.4 - load-bearing: DocumentChecklistController compares these raw and returns an
   UNFILTERED checklist for anything else. */
const RESIDENT = "Resident";
const NON_RESIDENT = "Non-Resident";

/* 2.0 - the reason codes the server puts in lockReasons, and the sentence each one
   earns. ON_FILE is deliberately quiet: the card-level note covers it, and an existing
   customer's card must not be a wall of amber.
   2.8 - which is now true of ALL of them under a form field: the note covers the lot,
   and only NO_SIGNATORY is still drawn, under the AML pills, because it is the one
   that asks the rep to do something. The table is kept whole - it maps a server
   contract, not this template. */
const WHY = {
  IDENTITY_SAVED: () => LABELS.CUST_WHY_IDENTITY,
  RESIDENCY_SAVED: () => LABELS.CUST_WHY_RESIDENCY,
  NAME_RULE: () => LABELS.CUST_WHY_NAME,
  NO_SIGNATORY: () => LABELS.CUST_WHY_NO_SIGNATORY,
  ON_FILE: () => ""
};

/* 2.0 - an empty date input is "", which Apex cannot deserialise into Date. */
const DATE_KEYS = [
  "dateOfEstablishment",
  "emiratesIdExpiry",
  "passportIssueDate",
  "passportExpiry"
];

/* 2.1 - the card's visual order, for focusFirstGap(). Every key here has a
   [data-field] control in the template; residency is deliberately absent - 2.2 not
   because it is no longer an input (it is one now), but for the half of that reason
   which still holds: a blank residency is the parent's no-customer state, said by
   the bar rather than walked to. */
/* 2.3 - every key this card can write. Used by the fill-only rule and the on-file
   note. 3.0 - which of them the BOOKING reads is GATE_ORG / GATE_PERSON above. */
const OWNED_KEYS = [
  "firstName", "lastName", "email", "mobile", "nationality", "residentStatus",
  "emiratesId", "emiratesIdExpiry",
  "passportNumber", "passportIssueDate", "passportExpiry", "countryOfResidence",
  "companyName", "tradeLicenceNumber", "dateOfEstablishment"
];

/* 2.3 / 2.7 - the fill-only exemption, as the condition it always meant. A date is
   the one kind of saved value that becomes wrong with nobody touching it: it simply
   passes. An expired Emirates ID is what BLOCKS the booking, so a renewal has to be
   typeable here or the card shows the rep a dead end.
   But only while it is unusable. A valid expiry is a fact like any other value on
   this card, and dateOfEstablishment cannot go stale at all - a company's founding
   date does not lapse - so it is not on either list. */
const EXPIRY_KEYS = ["emiratesIdExpiry", "passportExpiry"];
const ISSUE_KEYS = ["passportIssueDate"];

/* 3.0 - THE GATE, field for field, from UnitSearchLwcController
   .checkBookingEligibility. A PERSON account is blocked on nationality and
   resident status. An ORGANISATION is not - its copies live on the Opportunity,
   written at conversion - and is blocked on UnifiedNumber__c instead, which is
   what the licence number is copied into by stampCompanyLicence. The address is
   on neither list HERE: c/mscAddress owns it, and this card only reads it back.

   Everything not on these two lists is verification's, and lives behind the
   disclosure. That is the whole rule; nothing else in this file re-decides it. */
const GATE_ORG = ["companyName", "tradeLicenceNumber"];
const GATE_PERSON = ["nationality", "residentStatus"];

const FOCUS_ORDER = [
  "companyName", "tradeLicenceNumber", "dateOfEstablishment",
  "firstName", "lastName", "email", "mobile", "nationality",
  "emiratesId", "emiratesIdExpiry",
  "passportNumber", "passportIssueDate", "passportExpiry", "countryOfResidence"
];

export default class MscCustomerInfo extends LightningElement {
  @api nationalityOptions = [];
  /** 1.2 - Account.LegalStructure__c values, read from the schema by Apex.
      2.11 - nothing on the card reads them any more: the Legal structure select
      left with the rest of the licence block. The property STAYS DECLARED because
      c/mscBookingPage still binds legal-structure-options=, and an attribute bound
      to a non-@api property is set on nothing. Retiring the binding is that
      component's change to make, not this one's. */
  @api legalStructureOptions = [];
  /** 2.0 - Contact.CountryOfResidence__c values, a restricted picklist: the free
      text this used to be could type a value the record refuses at save. */
  @api countryOptions = [];
  @api saving = false;
  /**
   * 1.9 - START FOLDED, SO THE ADDRESS IS WHAT THE REP SEES.
   *
   * Set only on the NEW-customer journey, where every field on this block was
   * typed into the create form thirty seconds ago and read back unchanged. Fifteen
   * boxes of confirmed data were pushing the one thing still outstanding - the
   * mailing address, which blocks the booking - below the fold of a card the rep
   * had no reason to scroll.
   *
   * NOT set on the existing-customer journey: there the details came out of the
   * org rather than out of the rep, and the point of showing them is that somebody
   * checks them against the person standing at the desk.
   */
  @api collapsedOnArrival = false;
  /* 2.0 - @api locked removed. The blanket boolean said "a customer exists" and
     disabled everything; the per-field policy arrives inside customer.lockReasons,
     computed on the server where the records and the org's rules are. */

  @track form = {
    firstName: "",
    lastName: "",
    email: "",
    mobile: "",
    nationality: "",
    residentStatus: "",
    emiratesId: "",
    emiratesIdExpiry: "",
    passportNumber: "",
    passportIssueDate: "",
    passportExpiry: "",
    countryOfResidence: "",
    // 1.2 - the company, when the buyer is one.
    customerType: "",
    companyName: "",
    tradeLicenceNumber: "",
    dateOfEstablishment: "",
    /* 2.1 - "Yes" | "No" | "". A string like every form key, folded to a real
       Boolean (or null for unanswered) only at save. */
    realBeneficiary: ""
    /* 2.0 - the five billing keys are gone. The address renders as a read-only
       line here and is edited in c/mscAddress - one form, one writer (GAP 41). */
  };
  @track touched = {};

  labels = LABELS;

  /**
   * Seed from the server without clobbering edits already in progress - except
   * for a LOCKED key, where the server's value wins outright (2.0): after a
   * fill-only save the returning state flips the field to locked, and the stale
   * editable text must flip with it, not shadow it.
   */
  @api
  set customer(value) {
    if (!value) return;
    this._customer = value;
    const locks = value.lockReasons || {};
    const seed = (k, fallback) =>
      locks[k] ? value[k] || "" : this.form[k] || value[k] || fallback || "";
    this.form = {
      ...this.form,
      firstName: seed("firstName"),
      /* 1.8 - no `|| value.name` fallback. CustomerBlock carried only the full name
         until SalesConsoleController 1.15, so this put "testfour testfour" in Last
         name and left First name empty - and would have written it back that way on
         save. The block now supplies both halves; an unsplittable name is better
         shown as a blank field than as a wrong one. */
      lastName: seed("lastName"),
      email: seed("email"),
      mobile: seed("mobile"),
      nationality: seed("nationality"),
      residentStatus: seed("residentStatus"),
      /* 1.2 - the documents were never seeded. 2.0 - a locked document seeds the
         (nulled) server value, i.e. empty: the input never holds clear PII the
         server withheld, and the masked twin is what renders. */
      emiratesId: seed("emiratesId"),
      emiratesIdExpiry: seed("emiratesIdExpiry"),
      passportNumber: seed("passportNumber"),
      passportIssueDate: seed("passportIssueDate"),
      passportExpiry: seed("passportExpiry"),
      countryOfResidence: seed("countryOfResidence"),
      // 1.2
      customerType: seed("customerType", INDIVIDUAL),
      companyName: seed("companyName"),
      tradeLicenceNumber: seed("tradeLicenceNumber"),
      dateOfEstablishment: seed("dateOfEstablishment"),
      /* 2.1 - stored truth only: the server sends true or null, never false,
         so an unanswered question is never rendered as a "No". The rep's own
         in-progress answer survives a refresh like every other key. */
      realBeneficiary: locks.realBeneficiary
        ? ""
        : this.form.realBeneficiary || (value.realBeneficiary === true ? "Yes" : "")
    };
  }
  get customer() {
    return this._customer;
  }
  _customer;

  /** 2.0 - the server's per-field edit policy. Absent key = editable. */
  get locks() {
    return (this._customer && this._customer.lockReasons) || {};
  }



  /*** 3.0  Start: the facts, the gate and the verification block ************/

  /**
   * WHAT IS KNOWN IS STATED, NOT ASKED.
   *
   * Every value here was a readonly input box until 3.0. A field the rep cannot
   * write is not a question, and drawing it as one cost the card six boxes and
   * the rep a scroll past them to reach the address that was actually blocking.
   */
  get factsMain() {
    const f = this.form;
    if (this.isOrganisation) return (f.companyName || "").trim();
    return `${f.firstName || ""} ${f.lastName || ""}`.trim();
  }

  get factsSub() {
    const f = this.form;
    const bits = [];
    if (this.isOrganisation) {
      if ((f.tradeLicenceNumber || "").trim()) {
        bits.push(`${LABELS.CUST_FACT_LICENCE} ${f.tradeLicenceNumber.trim()}`);
      }
      const who = `${f.firstName || ""} ${f.lastName || ""}`.trim();
      if (who) bits.push(`${LABELS.CUST_FACT_SIGNATORY} ${who}`);
    } else {
      /* the masked-aware getters, so a locked value shows as the server sent it
         and the clear one never reaches the browser. */
      if (this.emailValue) bits.push(this.emailValue);
      if (this.mobileValue) bits.push(this.mobileValue);
    }
    return bits.join(" · ");
  }

  /**
   * 3.2 - AN INDIVIDUAL READS BACK AS THE SMALL SUMMARY they had before 3.0: one
   * compact label/value grid, read-only, said in the order a person says them.
   * A company keeps the one-line facts instead - its identity is a name and a
   * licence number, not a person's details.
   *
   * Blank values drop out rather than printing a dash: an empty field is not
   * information, and whatever is genuinely missing is either a gate input below
   * or the verification popup's to collect.
   */
  get summaryRows() {
    if (this.isOrganisation) return [];
    const f = this.form;
    const rows = [];
    const push = (label, value) => {
      if (value) rows.push({ key: label, label, value });
    };
    push(LABELS.CUST_F_NAME, `${f.firstName || ""} ${f.lastName || ""}`.trim());
    push(LABELS.RESIDENCY, f.residentStatus);
    push(LABELS.CUST_NATIONALITY, f.nationality);
    push(LABELS.CUST_EMAIL, this.emailValue);
    push(LABELS.CUST_MOBILE, this.mobileValue);
    /* MSC-174 (B2) - a resident carries a passport too now, so the facts show it for
       both residencies; the Emirates ID pair stays resident-only and the country of
       residence non-resident-only. Facts only: which documents are REQUIRED is
       c/mscEoiUtils.identityNeedsFor, asked by the identity step, never here. */
    if (this.isResident) {
      push(LABELS.CUST_EID, this.eidValue);
      push(LABELS.CUST_EID_EXPIRY, f.emiratesIdExpiry ? formatDate(f.emiratesIdExpiry) : "");
    }
    if (this.isResident || this.isNonResident) {
      push(LABELS.CUST_F_PASSPORT, this.passportValue);
      push(LABELS.CUST_PASSPORT_EXPIRY, f.passportExpiry ? formatDate(f.passportExpiry) : "");
    }
    if (this.isNonResident) {
      push(LABELS.CUST_COUNTRY_RES, f.countryOfResidence);
    }
    return rows;
  }

  get hasSummary() {
    return this.summaryRows.length > 0;
  }

  /* The person gate, asked only where it is actually missing - the same rule the
     company block follows. A value on file is in the summary above instead. */
  get showNationalityField() {
    return !this.isOrganisation && !(this.form.nationality || "").trim();
  }

  get showResidencyField() {
    return !this.isOrganisation && !(this.form.residentStatus || "").trim();
  }

  get showPersonGate() {
    return this.showNationalityField || this.showResidencyField;
  }

  get hasFacts() {
    return this.isOrganisation && (!!this.factsMain || !!this.factsSub);
  }

  /* The company's identity is normally on file from the create form, where the
     licence number is required. It is asked for here only when the record arrived
     without one - which a company matched from search can. */
  get showCompanyNameField() {
    return !(this.form.companyName || "").trim();
  }

  get showLicenceField() {
    return !(this.form.tradeLicenceNumber || "").trim();
  }

  get showCompanyGate() {
    return this.showCompanyNameField || this.showLicenceField;
  }

  /* checkBookingEligibility blocks an organisation on all five billing parts. */
  get addressIsGap() {
    return this.isOrganisation && (!this.hasBillingAddress || this.billingIncomplete);
  }

  /*** 3.0  End ***************************************************************/

  /** The five billing parts as one line, the way an address is actually read.
      2.0 - off the customer record, not the form: the card no longer edits them. */
  get billingAddressLine() {
    const c = this._customer || {};
    return [c.billingStreet, c.billingCity, c.billingState, c.billingPostalCode, c.billingCountry]
      .map((p) => (p || "").trim())
      .filter(Boolean)
      .join(", ");
  }

  get hasBillingAddress() {
    return !!this.billingAddressLine;
  }

  /* 2.0 - eligibility blocks an organisation on postal code and country. Said
     here, on the step that used to ask for them, rather than at Review. */
  get billingIncomplete() {
    const c = this._customer || {};
    return this.isOrganisation
      && this.hasBillingAddress
      && (!(c.billingPostalCode || "").trim() || !(c.billingCountry || "").trim());
  }

  /** 2.0 - the way to the one form that edits the address (c/mscAddress). */
  handleEditAddress() {
    this.dispatchEvent(new CustomEvent("editaddress"));
  }

  /**
   * 2.1 - the same contract c/mscAddress.focusFirstGap has: take the rep to the
   * first gap THIS card owns, or return false so the caller tries elsewhere.
   * The parent's held Continue calls the address form first, then this card -
   * which is how "This customer still needs its licence number." lands on the
   * licence field instead of the top of the card.
   */
  @api
  focusFirstGap() {
    const errs = this.errors;
    const key = FOCUS_ORDER.find((k) => errs[k]);
    if (!key) return false;
    /* 3.1 - every field this card still draws is a gate field and is always on
       screen, so there is nothing to open first. Mark it touched so its sentence
       is showing when the scroll arrives, and wait a frame for the DOM. */
    this.touched = { ...this.touched, [key]: true };
    requestAnimationFrame(() => {
      const el = this.template.querySelector(`[data-field="${key}"]`);
      if (el) {
        el.scrollIntoView({ block: "center", behavior: "smooth" });
        if (el.focus) el.focus();
      }
    });
    return true;
  }


  get isResident() {
    return this.form.residentStatus === "Resident";
  }
  get isNonResident() {
    return this.form.residentStatus === "Non-Resident";
  }
  get hasResidency() {
    return !!this.form.residentStatus;
  }

  // ---- 1.2 individual / organisation -------------------------------------

  get isOrganisation() {
    return this.form.customerType === ORGANISATION;
  }

  /* 2.2 - the buyer-type pills and their lock getter left with the block that
     held them. The server locks buyer type whenever an account exists - changing
     it means a DIFFERENT ACCOUNT, not an edit - so the control was never live on a
     booking, and the folded summary already states the answer. */

  get residencyLocked() {
    return !!this.lockFor("residentStatus");
  }

  /**
   * 2.3 - the ONE place that answers "can the rep write this field?".
   *
   * The server's own lock wins and keeps its reason. Otherwise the fill-only rule:
   * a populated value is read-only, under the same quiet ON_FILE code the server
   * uses for an on-file value, because that is exactly what it is. Dates are exempt
   * - see isRenewable.
   */
  lockFor(key) {
    const code = this.locks[key];
    if (code) return code;
    /* 2.5 - the RECORD's value, never the form's. Two reasons, and both matter:
       the form holds what the rep is typing RIGHT NOW, so reading it would lock a
       blank field on its first keystroke; and it is what MODON already stores that
       decides whether a write would be an amendment rather than a fill.
       It is also what closes the loop - after Save the parent returns the saved
       customer, these fields become stored values, and the button retires itself
       because editableKeys has nothing left in it. */
    const stored = (this._customer || {})[key];
    if (stored === undefined || stored === null) return null;
    const value = String(stored).trim();
    if (value === "") return null;
    return this.isRenewable(key, value) ? null : "ON_FILE";
  }

  /**
   * 2.7 - is this stored date one the org would refuse today? Those stay the rep's
   * to fix, because the booking is blocked until they do and nobody else is standing
   * in front of the customer. The same tests errors() applies, so a field can never
   * carry a sentence it is not allowed to act on.
   */
  isRenewable(key, stored) {
    const today = this.todayIso;
    /* 3.5 - today is still usable, as MODON's "< TODAY()" rules accept it */
    if (EXPIRY_KEYS.includes(key)) return stored < today;
    if (ISSUE_KEYS.includes(key)) return stored > today;
    return false;
  }

  /* 2.1 - the AML declaration (GAP 5), organisation only. */
  get showRealBeneficiary() {
    return this.isOrganisation;
  }

  get realBenLocked() {
    return !!this.locks.realBeneficiary;
  }

  /** Why the pills are dead, when they are - NO_SIGNATORY is the only reason. */
  get realBenWhy() {
    const code = this.locks.realBeneficiary;
    return code && WHY[code] ? WHY[code]() : "";
  }

  get realBenPills() {
    return [
      { key: "Yes", label: LABELS.CUST_REAL_BEN_YES },
      { key: "No", label: LABELS.CUST_REAL_BEN_NO }
    ].map((o) => ({
      ...o,
      cls: this.form.realBeneficiary === o.key ? "pill active" : "pill"
    }));
  }

  handleRealBeneficiary(event) {
    if (this.realBenLocked) return;
    this.form = { ...this.form, realBeneficiary: event.currentTarget.dataset.value };
    this.dispatchEvent(new CustomEvent("dirty"));
  }

  /* 2.0 - one quiet line instead of amber under every on-file field. */
  /**
   * 2.9 - is there a gap: a field the rep can write that the record does not hold?
   * This is what the note is FOR, and what makes its first sentence true.
   */
  get hasGap() {
    const c = this._customer || {};
    return this.editableKeys.some((k) => {
      const stored = c[k];
      return stored === undefined || stored === null || String(stored).trim() === "";
    });
  }

  /**
   * 2.9 - both halves, because the sentence makes both claims: something is
   * missing, and the rest is already on file. Keyed on the on-file half alone it
   * was true of every established customer, so a complete card carried an
   * instruction with nothing to act on. A card with no gap now says nothing at
   * all - the read-only fields speak for themselves.
   */
  get showOnFileNote() {
    if (!this.hasGap) return false;
    const locks = this.locks;
    if (Object.keys(locks).some((k) => k !== "customerType" && locks[k] === "ON_FILE")) {
      return true;
    }
    return OWNED_KEYS.some((k) => this.lockFor(k) === "ON_FILE");
  }

  /**
   * 1.3 - a company based outside the UAE cannot be booked here.
   *
   * Passport_Number_Mandatory_Validation and Passport_IssueDate_Mandatory_Validation
   * are active, fire for any Non-Resident Self Generated lead, and mention companies
   * nowhere - so the insert fails asking a company for a passport. Said here, before
   * anything is typed, rather than surfaced as that error afterwards.
   */
  get showNonResidentOrgBlock() {
    return this.isOrganisation && this.form.residentStatus === "Non-Resident";
  }

  /** The person block is the signatory once a company is buying. */
  get personLegend() {
    return this.isOrganisation
      ? LABELS.ORG_CONTACT_LEGEND
      : LABELS.ORG_PERSON_LEGEND;
  }

  get nationalityChoices() {
    return (this.nationalityOptions || []).map((n) => {
      const value = n.value || n;
      return { label: n.label || n, value, selected: value === this.form.nationality };
    });
  }

  /* 2.0 - the restricted picklist's own values, same shape as nationality. */
  get countryChoices() {
    return (this.countryOptions || []).map((n) => {
      const value = n.value || n;
      return { label: n.label || n, value, selected: value === this.form.countryOfResidence };
    });
  }

  // ---- validation -------------------------------------------------------

  /** Today as the date inputs spell it, for ISO string comparison. */
  get todayIso() {
    const d = new Date();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    return `${d.getFullYear()}-${mm}-${dd}`;
  }

  /**
   * 3.0 - ONLY THE GATE BLOCKS.
   *
   * Until now every starred field on the card was required, including fields no
   * gate in the org reads. That was tolerable while they were all on screen; it
   * cannot survive the verification block, because a required field folded away
   * is an error the rep is refused for and cannot see. So "required" now means
   * exactly one thing - the booking is blocked without it - and everything else
   * keeps only its FORMAT rule, which is about the value being usable rather than
   * about it being there.
   */
  isGate(key) {
    return (this.isOrganisation ? GATE_ORG : GATE_PERSON).includes(key);
  }

  get errors() {
    const f = this.form;
    const today = this.todayIso;
    /* blank + the booking reads it -> the sentence; blank + it does not -> nothing. */
    const req = (key, value, message) =>
      this.isGate(key) && !value ? message || LABELS.CUST_E_REQUIRED : "";
    const e = {
      /* 2.0 - First_Name_Mandatory_Check refuses a blank one at lead creation.
         3.0 - it is still checked there, on the create form, where a blank can
         actually be produced; this card never invents a booking block for it. */
      firstName: req("firstName", f.firstName.trim()),
      lastName: req("lastName", f.lastName.trim()),
      /* the shape is always checked - a malformed address is unusable wherever it
         is asked for - but its absence only matters where the gate reads it. */
      email: !f.email.trim()
        ? req("email", "")
        : /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email.trim())
          ? ""
          : LABELS.CUST_E_EMAIL,
      mobile: req("mobile", f.mobile.trim()),
      nationality: req("nationality", f.nationality),
      residentStatus: req("residentStatus", f.residentStatus, LABELS.CUST_E_RESIDENCY)
    };
    // Residency decides which identity document is mandatory. The dates are
    // optional; when supplied they must make sense (the org has no rule on the
    // record side - the Opportunity's date rules never see these fields).
    /* MSC-174 (B2) - the passport belongs to both residencies now, so its date sanity runs
       for a resident as well; the Emirates ID pair stays resident-only and the country of
       residence non-resident-only. (The identity keys are not on GATE_PERSON, so `req`
       says nothing for them here; the identity step owns what is required.) */
    if (this.isResident) {
      e.emiratesId = req("emiratesId", f.emiratesId.trim(), LABELS.CUST_E_EID);
      e.emiratesIdExpiry =
        f.emiratesIdExpiry && f.emiratesIdExpiry < today ? LABELS.IDF_EXPIRY_PAST : "";
    }
    if (this.isResident || this.isNonResident) {
      e.passportNumber = req("passportNumber", f.passportNumber.trim(), LABELS.CUST_E_REQUIRED);
      e.passportIssueDate =
        f.passportIssueDate && f.passportIssueDate > today ? LABELS.IDF_ISSUE_FUTURE : "";
      e.passportExpiry =
        f.passportExpiry && f.passportExpiry < today ? LABELS.IDF_EXPIRY_PAST : "";
    }
    if (this.isNonResident) {
      e.countryOfResidence = req("countryOfResidence", f.countryOfResidence.trim(), LABELS.CUST_E_PASSPORT);
    }
    /* 1.2 - exactly what Passfort rejects a company for. Date of establishment
       is the hard one: PassfortTransactionProcessHelper errors the transaction
       outright when incorporation_date is null. 2.0 - the billing checks left
       with the billing inputs; the address line carries its own incomplete cue. */
    if (this.isOrganisation) {
      e.companyName = req("companyName", f.companyName.trim());
      e.tradeLicenceNumber = req("tradeLicenceNumber", f.tradeLicenceNumber.trim());
      /* 3.0 - no longer a booking block. Passfort still errors a company
         transaction without incorporation_date, which is why it is counted as a
         verification gap and named in the block below - but that is compliance's
         gate, at compliance's step, not this booking's. */
      e.dateOfEstablishment = req("dateOfEstablishment", f.dateOfEstablishment, LABELS.CUST_E_DOE);
    }
    /* 2.0 - a locked field can never block Save or hold the fold open. It is
       not the rep's to fix from here, and the reason is on the field.
       2.6 - through lockFor, so fill-only counts as locked here too. It did not,
       and a read-only field carrying a value the org would reject could fail
       isValid with its sentence suppressed - Save simply did nothing, and nothing
       on screen said why. */
    Object.keys(e).forEach((k) => {
      if (this.lockFor(k)) e[k] = "";
    });
    return e;
  }

  get fields() {
    const errs = this.errors;
    const f = this.form;
    const show = (k) => (this.touched[k] ? errs[k] || "" : "");
    const mk = (k, base) => {
      /* 2.3 - through lockFor, so a populated value is read-only whether the server
         said so or the fill-only rule did. */
      const code = this.lockFor(k);
      const locked = !!code;
      const err = locked ? "" : show(k);
      return {
        locked,
        /* 2.8 - `why` is gone: no field draws one, and a computed string nothing
           reads is an invitation to put the column of amber back. */
        error: err,
        cls: this.cls(err, base),
        /* Readonly dates render as text - a formatted value in a type="date"
           box is cleared by the browser. formatDate says "-" for blank. */
        display: DATE_KEYS.includes(k) ? formatDate(f[k] || null) : f[k]
      };
    };
    return {
      firstName: mk("firstName", "field__input"),
      lastName: mk("lastName", "field__input"),
      email: mk("email", "field__input"),
      mobile: mk("mobile", "field__input"),
      nationality: mk("nationality", "field__select"),
      /* 2.2 - a field on the card now, so it earns a row here: the same lock, the
         same reason sentence and the same blank-is-an-error rule as its neighbours. */
      residentStatus: mk("residentStatus", "field__select"),
      emiratesId: mk("emiratesId", "field__input"),
      emiratesIdExpiry: mk("emiratesIdExpiry", "field__input"),
      passportNumber: mk("passportNumber", "field__input"),
      passportIssueDate: mk("passportIssueDate", "field__input"),
      passportExpiry: mk("passportExpiry", "field__input"),
      countryOfResidence: mk("countryOfResidence", "field__select"),
      // 1.2
      companyName: mk("companyName", "field__input"),
      tradeLicenceNumber: mk("tradeLicenceNumber", "field__input"),
      dateOfEstablishment: mk("dateOfEstablishment", "field__input")
    };
  }

  cls(err, base) {
    return err ? `${base} field__input--error` : base;
  }

  get isValid() {
    const e = this.errors;
    return !Object.keys(e).some((k) => e[k]);
  }

  get saveDisabled() {
    // 1.3 - saving a non-UAE company only produces a passport-rule error.
    return this.saving || this.showNonResidentOrgBlock;
  }

  /* 2.0 - the fields that matter on THIS card in THIS state, minus the locked
     ones. Save renders only when there is something it could commit. */
  get editableKeys() {
    /* 3.1 - THE CARD OFFERS TO SAVE ONLY WHAT IT SHOWS. The verification fields
       are no longer drawn here, so a Save button that counted them would appear
       with nothing on screen to act on - and could write a field the rep never
       saw. The gate is what the card draws and the gate is what it commits. */
    const keys = (this.isOrganisation ? GATE_ORG : GATE_PERSON).slice();
    /* 2.3 - fill-only: Save can commit a blank, never an amendment. This is also
       what makes the button disappear on a customer whose record is complete. */
    return keys.filter((k) => !this.lockFor(k));
  }

  /**
   * 2.6 - is there anything to COMMIT? An editable key is not enough: the exempt
   * dates stay editable for a renewal that may never be needed, so a complete
   * customer offered a button whose click wrote the value it already held.
   *
   * A blank on the record is a gap - the button belongs there even before the rep
   * types, because it is what tells them the card can be saved. A value that
   * differs from the record is an edit. Everything else is the record as it stands.
   *
   * Stateless, form against record: no dirty flag to go stale, and after a save the
   * returning customer makes both halves false by itself.
   */
  get hasSomethingToSave() {
    const c = this._customer || {};
    const norm = (v) => (v === undefined || v === null ? "" : String(v).trim());
    return this.editableKeys.some((k) => {
      const stored = norm(c[k]);
      return stored === "" || norm(this.form[k]) !== stored;
    });
  }

  /* 1.5 / 2.0 - a live button that cannot do anything is worse than no button:
     a fully on-file customer shows no Save at all, and every locked field says
     why instead. */
  get showSave() {
    return this.hasResidency && this.editableKeys.length > 0 && this.hasSomethingToSave;
  }

  /**
   * 1.5 - an existing customer's contact details, masked.
   *
   * 2.0 - keyed per field off the lock map rather than the card-wide boolean.
   * The server nulls the clear twin of every locked field, so these masked
   * strings are the only value the browser ever holds for one - display-only
   * text that never seeds an input and is sent as null on save.
   */
  get emailValue() {
    if (!this.locks.email) return this.form.email;
    const c = this._customer || {};
    return c.maskedEmail || "";
  }

  get mobileValue() {
    if (!this.locks.mobile) return this.form.mobile;
    const c = this._customer || {};
    return c.maskedMobile || "";
  }

  get eidValue() {
    if (!this.locks.emiratesId) return this.form.emiratesId;
    const c = this._customer || {};
    return c.maskedEmiratesId || "";
  }

  get passportValue() {
    if (!this.locks.passportNumber) return this.form.passportNumber;
    const c = this._customer || {};
    return c.maskedPassport || "";
  }

  /* 2.3 - "Save customer details" claimed the card could amend a customer. It fills
     what is missing, and nothing else, so that is what the button says. */
  get saveLabel() {
    return this.saving ? LABELS.BUSY_SAVING : LABELS.CTA_SAVE_MISSING;
  }

  // ---- handlers ---------------------------------------------------------

  handleField(event) {
    const field = event.target.dataset.field;
    this.form = { ...this.form, [field]: event.target.value };
    this.dispatchEvent(new CustomEvent("dirty"));
  }

  handleBlur(event) {
    const field = event.target.dataset.field;
    this.touched = { ...this.touched, [field]: true };
  }

  /**
   * Changing residency recomputes the required documents and never deletes an upload -
   * the parent re-runs getRequiredDocuments and existing files stay attached.
   */
  handleResidency(event) {
    this.form = { ...this.form, residentStatus: event.detail.value };
    this.dispatchEvent(
      new CustomEvent("residencychange", { detail: { value: event.detail.value } })
    );
  }

  /* 2.2 - MODON's own values, straight off Account.UAE_Resident_Status__pc. The
     pills relabelled 'Resident' as "UAE Resident"; a field named after the record
     shows what the record stores. */
  get residencyChoices() {
    return [RESIDENT, NON_RESIDENT].map((v) => ({
      value: v,
      label: v,
      selected: this.form.residentStatus === v
    }));
  }

  /**
   * 2.2 - the select, where the pills were. It routes through handleResidency and
   * NOT through handleField, because that is what keeps the residencychange event
   * flowing: c/mscBookingPage listens for it and re-runs getRequiredDocuments, and
   * a residency change that did not reach it would leave the document list asking
   * for the wrong papers. Same guards the pills had - locked does nothing, and a
   * re-selection of the current value is not a change.
   */
  handleResidencySelect(event) {
    if (this.residencyLocked) return;
    const value = event.target.value;
    if (value === this.form.residentStatus) return;
    this.handleResidency({ detail: { value } });
  }

  /* 2.2 - residencyHint left with the block it sat under. The wording lives on in
     c/mscResidencyToggle, which still explains both answers where they are asked
     for the first time. */

  handleSave() {
    const all = {};
    Object.keys(this.errors).forEach((k) => {
      all[k] = true;
    });
    this.touched = all;
    if (!this.isValid) return;
    /* 2.0 - editable fields only. A locked key travels as null - the server
       skips nulls, and the masked display can never round-trip into a record.
       An empty date input is "", which Apex cannot deserialise into Date:
       null it, or the whole save fails on a field left blank on purpose. */
    const locks = this.locks;
    const detail = {};
    Object.keys(this.form).forEach((k) => {
      /* 2.3 - lockFor, so a populated value travels as null too. The server skips
         nulls, which is what makes fill-only a guarantee rather than a UI habit:
         even a stale form value cannot reach a record it did not come from. */
      detail[k] = this.lockFor(k) ? null : this.form[k];
    });
    DATE_KEYS.forEach((k) => {
      if (!detail[k]) detail[k] = null;
    });
    /* 2.1 - the declaration travels as a real Boolean, and only when the rep
       actually answered: null = not asked, and the server writes nothing. */
    detail.realBeneficiary =
      locks.realBeneficiary || !this.form.realBeneficiary
        ? null
        : this.form.realBeneficiary === "Yes";
    this.dispatchEvent(new CustomEvent("save", { detail }));
  }
}