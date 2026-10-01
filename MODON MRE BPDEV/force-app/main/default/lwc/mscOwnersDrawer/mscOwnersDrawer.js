/**
 * Add or edit one joint owner on a booking.
 *
 * Version  Author      Date         Detail
 * 1.8      Aurelix Dev 30 Sep 2026  A person made with Create person reads "New account", not "Existing account"
 *                                   (UI-30). The ownership sentence says joint owners hold less than 100% (R2-12, labels).
 * 1.7      Aurelix Dev 29 Sep 2026  Nationality uses the buyer's native select (field__select, as in c/mscCustomerInfo
 *                                   3.4) in Create person and the edit's contact details; c/mscPicklist is gone.
 * 1.6      Aurelix Dev 29 Sep 2026  Nationality is a list, not a free box: Account.Nationality__pc is a restricted
 *                                   picklist, so a typed value failed on insert. The list comes from
 *                                   SalesConsoleLeadController.getLeadQualifyOptions, as for the buyer.
 * 1.5      Aurelix Dev 28 Sep 2026  Two things the business asked for on 28 Sep.
 *                                   (1) MANUAL KYC FOR THE PERSON BEING ADDED. MODON's Sales App has a manual
 *                                   KYC route for a person (their Account's Submit for Manual KYC and Update
 *                                   KYC), and MODON's joint owner check accepts its approval. The KYC box of a
 *                                   found person whose KYC is not complete now carries the buyer's route:
 *                                   a quiet "Manual KYC" button beside Send KYC link and Check again, as in
 *                                   c/mscKycGate, and c/mscPartyKyc under it (request, waiting, approved:
 *                                   documents, Update KYC, Generate; rejected with the comment). Update KYC
 *                                   opens MODON's form in c/mscKycCaptureModal, hosted here above the drawer.
 *                                   Anything that moves re-runs MODON's check (Check again). Send KYC link
 *                                   is dropped once the manual route is approved, as for the buyer.
 *                                   (2) THE BUYER'S MATCH BEFORE CREATE PERSON. When the details match
 *                                   existing customers, createPerson writes nothing and returns them; the
 *                                   drawer shows a chooser like the buyer's and Continue uses the chosen
 *                                   customer (checkPerson, then shown as found). Create anyway only while
 *                                   ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on.
 * 1.4      Aurelix Dev 22 Sep 2026  MODON now refuses a joint owner whose KYC is not complete
 *                                   (JointOwnerTriggerHelper 2.0). A found person shows the result
 *                                   of that same check, with Send KYC link and Check again. Add stays
 *                                   off until it passes. A new person is created first (Create
 *                                   person), not added, so they can do KYC; the host is told through
 *                                   a "personfound" event.
 * 1.x+1    Aurelix Dev 20 Sep 2026  Required fields carry the console's one required mark
 *                                   (.field__req), a red asterisk before the label, as Modon's
 *                                   own Update KYC form does.
 * 1.3      Aurelix Dev 30 Aug 2026  MSC-180. A COMPANY CAN BE THE PARTY. An
 *                                   Individual/Company toggle heads the identity step;
 *                                   company mode searches by trade licence (no mask, no
 *                                   residency - both are person ideas), creates with a
 *                                   name and that licence, and offers only the two
 *                                   commercial relationship types the server accepts.
 *                                   Edit mode asks the ROW what it is: a company edit
 *                                   is share, relationship and units - the contact
 *                                   section never renders for one. The panel itself is
 *                                   now the WIDE drawer (960px, c/mscDrawer's own
 *                                   size, no shell change): mscStyles' auto-fit field
 *                                   grid flows to two and three columns on its own,
 *                                   so the form breathes without new layout CSS.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-081, phase 2 of the joint owner module.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-082. Edit mode gains Contact Details - email,
 *                                   mobile, nationality and Resident Status - because
 *                                   without them a joint owner cannot be sent an
 *                                   identity verification link, and phase 1 asks for
 *                                   none of them. It appears ONLY while something is
 *                                   blank, and a detail already on the account shows
 *                                   disabled: the server fills blanks and never
 *                                   overwrites, so an editable box would be a box that
 *                                   silently discards what was typed into it.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-087. The Emirates ID is shaped as it is typed,
 *                                   784-XXXX-XXXXXXX-X, capped at fifteen digits, and
 *                                   the search waits for all of them - the same three
 *                                   rules the booking journey's identity step applies.
 *                                   Not cosmetic: findPerson matches EIDNumber__pc
 *                                   exactly, so "784199277100429" and
 *                                   "784-1992-7710042-9" are two different customers
 *                                   to it. Unmasked, this form searched in one format
 *                                   and created accounts in another - the duplicate the
 *                                   search-before-create rule above exists to prevent.
 *                                   A passport is untouched: it has no fixed shape and
 *                                   imposing one would corrupt a real reference.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHERE THIS IS MOUNTED. At mscBookingPage's `.page`, beside c-msc-compliance-check
 * and NEVER inside the Verification card. The card carries backdrop-filter, which
 * makes it the containing block for position: fixed, so a drawer rendered inside it
 * becomes a pane inside one card. c/mscDrawer's header records the day that was
 * learned; this component simply obeys it.
 *
 * IDENTITY FIRST, AND IT CANNOT BE SKIPPED. A co-owner is very often already an
 * Account - as the buyer of another unit, or as somebody else's joint owner. 2,230
 * of 2,236 joint owners in the org point at an existing Person Account, and Modon
 * runs a whole merge module because of duplicates. So the drawer opens on a search
 * and the create form is only reachable through a search that found nothing.
 *
 * IT DECIDES NOTHING. Every rule - the six-owner ceiling, the 100% total, the SPA
 * cut-off, who may be added at all - belongs to SalesConsoleJointOwnerService and
 * runs again on save whatever this form allowed. What is checked here is checked
 * only so the rep is not sent round the loop for something we already knew.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { LightningElement, api, wire } from "lwc";
import { LABELS } from "c/mscLabels";
import { formatEmiratesId, isValidEmiratesId } from "c/mscEoiUtils";
import { reduceError } from "c/modonSalesFormat";
/* 1.4: joint owner KYC, asked of the server so it is MODON's own check */
import checkPerson from "@salesforce/apex/SalesConsoleJointOwnerService.checkPerson";
import sendCandidateVerification from "@salesforce/apex/SalesConsoleJointOwnerService.sendCandidateVerification";
import createPerson from "@salesforce/apex/SalesConsoleJointOwnerService.createPerson";
/* 1.6: the buyer's nationality list, from the schema */
import getLeadQualifyOptions from "@salesforce/apex/SalesConsoleLeadController.getLeadQualifyOptions";

const SEGMENTS = ["dw__seg--1", "dw__seg--2", "dw__seg--3"];

/* 1.5: this drawer's own words (c/mscLabels is shared and not changed here) */
const MATCH_FOUND_ONE = "1 existing customer holds these details. Choose the right one.";
const MATCH_BACK = "Back";
const MATCHED_ON = {
  eid: LABELS.MATCHED_EID,
  passport: LABELS.MATCHED_PASSPORT,
  email: LABELS.MATCHED_EMAIL,
  mobile: LABELS.MATCHED_MOBILE
};

/* 784-XXXX-XXXXXXX-X: fifteen digits and three dashes. */
const EID_LENGTH = 18;

/**
 * Where the caret belongs after reformatting, counted in DIGITS rather than
 * characters. Without this the caret jumps to the end on every keystroke, which makes
 * correcting a digit in the middle impossible - the one thing a rep does when the
 * customer says "no, it's a 7".
 */
function caretAfterDigits(formatted, digitCount) {
  if (digitCount <= 0) return 0;
  let seen = 0;
  for (let i = 0; i < formatted.length; i += 1) {
    if (formatted[i] >= "0" && formatted[i] <= "9") {
      seen += 1;
      if (seen === digitCount) return i + 1;
    }
  }
  return formatted.length;
}

function digitsBeforeCaret(value, caret) {
  return String(value || "")
    .slice(0, caret === null || caret === undefined ? 0 : caret)
    .replace(/\D/g, "").length;
}
const RESIDENT = "Resident";
/* 1.3 - MSC-180. The two relationship types that can describe a company - the same
   pair SalesConsoleJointOwnerService.COMPANY_REL_TYPES enforces, so the list never
   offers what the save would refuse. */
const COMPANY_REL_TYPES = ["Partner", "Third Party"];

function pct(value) {
  if (value === null || value === undefined || value === "") return "";
  const n = Number(value);
  if (Number.isNaN(n)) return "";
  return String(Math.round(n * 100) / 100);
}

/* 1.4: "22 Sep, 15:40" for the KYC link line */
function sentOn(value) {
  const d = new Date(value);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

export default class MscOwnersDrawer extends LightningElement {
  @api mode = "add";
  /** The same OwnersDTO the panel renders. Read only. */
  @api state;
  /** The PersonDTO the identity search returned, or null. */
  @api person;
  /** 'idle' | 'searching' | 'found' | 'notfound' */
  @api searchStatus = "idle";
  @api saving = false;
  /** The server's own sentence. Rendered verbatim, never paraphrased. */
  @api errorMessage;
  /** Which units to tick on open - the coverage line's one-press correction. */
  @api preselectedOrderIds;
  /** Edit mode: whose row was pressed. */
  @api editAccountId;

  labels = LABELS;

  // ── form state ────────────────────────────────────────────────────────
  /* 1.3 - MSC-180. Which kind of party the rep is adding. Add mode only: in edit
     mode the row already knows what it is (editParty.isCompany), and the toggle is
     not rendered. */
  partyKind = "person";
  companyName = "";
  residentStatus = RESIDENT;
  idNumber = "";
  firstName = "";
  lastName = "";
  email = "";
  mobile = "";
  nationality = "";
  relationshipType = "";
  relationshipSubType = "";
  share = "";
  selected = [];
  _open = false;
  /* 1.4: the latest KYC answer for the found person, from this drawer's own calls */
  kycOverride;
  /* 1.4: "send" | "check" | "create" while a call is running. 1.5: and "pick" */
  kycBusy;
  kycError;
  /* 1.5: the existing customers createPerson stopped on, the one the rep picked, and the
     details the create was asked with (for Create anyway) */
  matchChoice;
  chosenMatchId;
  lastCreateDetail;
  /* 1.5: the found person's manual KYC route */
  manualOpen = false;
  partyManual = { offer: false, approved: false };
  kycModalOpen = false;
  kycModalSubjectId;
  kycModalSubjectName;
  /* 1.6: Nationality__pc's active values (the "Countries" value set) */
  nationalityValues = [];

  _needsReset = false;

  /* 1.6: the same list the buyer's forms offer; cacheable, so one call per page */
  @wire(getLeadQualifyOptions)
  wiredQualifyOptions({ data, error }) {
    if (data) this.nationalityValues = data.nationality || [];
    /* a missing list must not take the drawer down: the field then offers nothing */
    else if (error) this.nationalityValues = [];
  }

  get nationalityChoices() {
    return (this.nationalityValues || []).map((v) => ({
      value: v,
      label: v,
      selected: v === this.nationality
    }));
  }

  /**
   * Every open is a clean form. Reset on the way IN rather than the way out: a
   * drawer that clears itself as it leaves does it while the exit is still
   * playing, and the rep watches the fields they just filled empty themselves.
   *
   * FLAGGED HERE, PERFORMED IN renderedCallback. @api properties are assigned in
   * the order they appear in the parent's template, and `open` is the first
   * attribute on this tag - so resetting inside this setter would run against a
   * `state` and an `editAccountId` that have not arrived yet, and every open would
   * find no units to tick and no existing values to edit. renderedCallback is the
   * first moment all of them are certainly in.
   */
  @api
  get open() {
    return this._open;
  }
  set open(value) {
    const next = !!value;
    if (next && !this._open) this._needsReset = true;
    this._open = next;
  }

  renderedCallback() {
    if (!this._needsReset) return;
    this._needsReset = false;
    this.reset();
  }

  reset() {
    this.kycOverride = undefined;
    this.kycBusy = undefined;
    this.kycError = undefined;
    this.clearMatches();
    this.resetManual();
    this.partyKind = "person";
    this.companyName = "";
    this.idNumber = "";
    this.firstName = "";
    this.lastName = "";
    this.email = "";
    this.mobile = "";
    this.nationality = "";
    this.share = "";
    if (this.isEdit && this.editParty) {
      const p = this.editParty;
      this.relationshipType = p.relationshipType || "";
      this.relationshipSubType = p.relationshipSubType || "";
      this.share = p.share === null || p.share === undefined ? "" : String(pct(p.share));
      this.residentStatus = p.residentStatus || RESIDENT;
      /* 1.1 - what is already on the account, so a locked field can SHOW its value
         rather than an empty disabled box. What is blank stays blank and is the
         only thing this drawer can send back. */
      this.email = p.email || "";
      this.mobile = p.mobile || "";
      this.nationality = p.nationality || "";
    } else {
      this.relationshipType = "";
      this.relationshipSubType = "";
      this.residentStatus = RESIDENT;
    }
    this.selected = this.defaultSelection();
  }

  /**
   * Every open unit, ticked - unless the caller named a set.
   *
   * One co-owner across the whole basket is the median in the data, so the common
   * case costs no decision and the per-unit case stays deliberate. In edit mode
   * the units they already hold are always in, because they cannot be taken out.
   */
  defaultSelection() {
    const pre = this.preselectedOrderIds || [];
    if (this.isEdit) {
      const held = this.heldOrderIds;
      const extra = pre.filter((id) => !held.includes(id));
      return [...held, ...extra];
    }
    if (pre.length) return [...pre];
    return this.openUnits.map((u) => u.salesOrderId);
  }

  // ── the state, defensively ────────────────────────────────────────────
  get s() {
    return this.state || {};
  }
  get isAdd() {
    return this.mode !== "edit";
  }
  get isEdit() {
    return this.mode === "edit";
  }
  get units() {
    return this.s.units || [];
  }
  get openUnits() {
    return this.units.filter((u) => u.open);
  }
  get parties() {
    return this.s.parties || [];
  }
  get primaryParty() {
    return this.parties.find((p) => p.isPrimary);
  }
  get editParty() {
    return this.parties.find((p) => p.accountId === this.editAccountId);
  }
  get heldOrderIds() {
    const p = this.editParty;
    if (!p) return [];
    return (p.holdings || []).map((h) => h.salesOrderId);
  }

  // ── head ──────────────────────────────────────────────────────────────
  get title() {
    return this.isEdit ? LABELS.JO_DRAWER_EDIT : LABELS.JO_DRAWER_ADD;
  }

  /** Context the title should not carry. A rep with two tabs open needs it. */
  get subtitle() {
    if (this.isEdit) {
      const p = this.editParty;
      if (!p) return null;
      const held = this.heldOrderIds.length;
      return this.units.length > 1
        ? `${p.name} · ${fill(LABELS.JO_ON_UNITS, `${held}/${this.units.length}`)}`
        : p.name;
    }
    const primary = this.primaryParty;
    const focused = this.units.find(
      (u) => u.salesOrderId === this.s.focusedSalesOrderId
    );
    return [primary && primary.name, focused && focused.unitName]
      .filter(Boolean)
      .join(" · ");
  }

  // ── identity ──────────────────────────────────────────────────────────
  get found() {
    return this.searchStatus === "found" && !!this.person && !!this.person.accountId;
  }
  get showIdSearch() {
    return !this.found;
  }
  get showFound() {
    return this.found;
  }
  get showCreate() {
    /* 1.5: the chooser takes the form's place while it is open */
    return this.searchStatus === "notfound" && !this.showMatches;
  }

  // ── 1.5 · existing customers that match a new person ─────────────────
  get showMatches() {
    const m = this.matchChoice;
    return this.isAdd && !this.found && !!m && Array.isArray(m.matches) && m.matches.length > 0;
  }
  get matchLede() {
    const n = this.showMatches ? this.matchChoice.matches.length : 0;
    return n === 1 ? MATCH_FOUND_ONE : fill(LABELS.CAND_FOUND, n);
  }
  get matchRows() {
    if (!this.showMatches) return [];
    return this.matchChoice.matches.map((m) => {
      const chosen = m.accountId === this.chosenMatchId;
      const blocked = !!m.blockedReason;
      return {
        key: m.accountId,
        accountId: m.accountId,
        name: m.name,
        chip: MATCHED_ON[m.matchedOn] || null,
        sub: [m.email, m.mobile].filter(Boolean).join(" · "),
        meta: [m.residentStatus, m.nationality].filter(Boolean).join(" · "),
        blockedReason: m.blockedReason,
        chosen: chosen ? "true" : "false",
        disabled: blocked || !!this.kycBusy,
        cls: `dw__match${chosen ? " dw__match--on" : ""}${blocked ? " dw__match--off" : ""}`
      };
    });
  }
  get matchBack() {
    return MATCH_BACK;
  }
  get showCreateAnyway() {
    return this.showMatches && this.matchChoice.createDespiteMatchAllowed === true;
  }
  get matchContinueDisabled() {
    return !this.chosenMatchId || !!this.kycBusy;
  }
  get matchContinueText() {
    return this.kycBusy === "pick" ? LABELS.SIG_CTA_BUSY : LABELS.SIG_CTA;
  }
  get matchBusy() {
    return !!this.kycBusy;
  }
  clearMatches() {
    this.matchChoice = undefined;
    this.chosenMatchId = undefined;
    this.lastCreateDetail = undefined;
  }

  // ── 1.5 · manual KYC of the found person ─────────────────────────────
  resetManual() {
    this.manualOpen = false;
    this.partyManual = { offer: false, approved: false };
    this.kycModalOpen = false;
  }
  /** A person (not a company) whose KYC MODON has not passed yet. */
  get showPartyKyc() {
    return this.showKyc && !this.kycReady && !!this.card && !!this.card.accountId
      && this.card.isCompany !== true;
  }
  get partyAccountId() {
    return this.card ? this.card.accountId : null;
  }
  get showManualToggle() {
    return this.showPartyKyc && this.partyManual.offer === true;
  }
  get manualToggleText() {
    return this.manualOpen ? LABELS.KYCG_MANUAL_CLOSE : LABELS.KYCG_MANUAL_OPEN;
  }

  // ── 1.4 · KYC of the found person ────────────────────────────────────
  /** The found person, with this drawer's latest KYC answer when it is about them. */
  get card() {
    const p = this.person;
    const o = this.kycOverride;
    return o && p && o.accountId === p.accountId ? o : p;
  }
  get showKyc() {
    return this.isAdd && this.found && !!this.card && !this.card.blockedReason;
  }
  get kycReady() {
    return !!this.card && this.card.kycReady === true;
  }
  get kycClass() {
    return this.kycReady ? "dw__kyc dw__kyc--ok" : "dw__kyc dw__kyc--wait";
  }
  get kycText() {
    return this.kycReady ? LABELS.JO_KYC_OK : this.card.kycIssue || "";
  }
  /** Where the KYC link stands. Null when there is nothing to say. */
  get kycLinkLine() {
    if (this.kycReady || !this.card) return null;
    const c = this.card;
    if (c.kycStatus === "SENDING") return LABELS.JO_KYC_SENDING;
    if (c.kycStatus === "EXPIRED") return LABELS.JO_KYC_EXPIRED;
    if (c.kycStatus === "SENT" && c.kycSentOn) {
      return fill(LABELS.JO_KYC_SENT, sentOn(c.kycSentOn));
    }
    return null;
  }
  /** Why a link cannot be sent, e.g. missing email or mobile, or a company. */
  get kycBlockedNote() {
    if (this.kycReady || !this.card) return null;
    const c = this.card;
    if (c.canSendKyc || c.kycStatus === "SENDING") return null;
    return c.kycBlockedReason || null;
  }
  get showKycSend() {
    /* 1.5: not once the manual route is approved, as c/mscKycGate 3.5 */
    return !this.kycReady && !!this.card && this.card.canSendKyc === true
      && !(this.showPartyKyc && this.partyManual.approved === true);
  }
  get showKycActions() {
    return !this.kycReady;
  }
  get kycSendText() {
    if (this.kycBusy === "send") return LABELS.JO_KYC_BUSY;
    const st = this.card && this.card.kycStatus;
    return st === "SENT" || st === "EXPIRED" ? LABELS.JO_KYC_RESEND : LABELS.JO_KYC_SEND;
  }
  get kycCheckText() {
    return this.kycBusy === "check" ? LABELS.JO_KYC_BUSY : LABELS.JO_KYC_CHECK;
  }
  get kycActionsDisabled() {
    return !!this.kycBusy || this.saving;
  }
  /** Add only, not found: the button creates the person, it does not add them. */
  get isCreating() {
    return this.isAdd && !this.found;
  }
  get searching() {
    return this.searchStatus === "searching";
  }
  get isResident() {
    return this.residentStatus === RESIDENT;
  }

  /* ── 1.3 - MSC-180. the kind of party ─────────────────────────────────── */
  /** Company, settled once: the rep's toggle on an add, the record on an edit. */
  get isCompanyKind() {
    return this.isEdit
      ? !!this.editParty && this.editParty.isCompany === true
      : this.partyKind === "company";
  }
  /** The toggle renders only while identity is still the question. */
  get showKindToggle() {
    return this.isAdd && this.showIdSearch;
  }
  get kindPersonClass() {
    return this.isCompanyKind ? "pill dw__kind" : "pill dw__kind dw__kind--on";
  }
  /** Templates cannot negate, so the person button's pressed state is a getter. */
  get isPersonPressed() {
    return !this.isCompanyKind;
  }
  get kindCompanyClass() {
    return this.isCompanyKind ? "pill dw__kind dw__kind--on" : "pill dw__kind";
  }
  /** Residency belongs to a person; a company's residency is nobody's field. */
  get showResidency() {
    return !this.isCompanyKind;
  }
  get foundIsCompany() {
    return !!this.person && this.person.isCompany === true;
  }

  /** One field, labelled for the document the rep is holding. */
  get idLabel() {
    if (this.isCompanyKind) return LABELS.JO_F_TRADE_LICENCE;
    return this.isResident ? LABELS.JO_F_EID : LABELS.JO_F_PASSPORT;
  }
  get idPlaceholder() {
    return !this.isCompanyKind && this.isResident ? "784-XXXX-XXXXXXX-X" : "";
  }
  /**
   * 1.2 - the browser refuses the nineteenth character rather than the mask
   * swallowing it. formatEmiratesId already caps at fifteen digits, so this changes
   * no stored value; it stops a keystroke that would do nothing from looking as
   * though it did. A passport has no fixed length and gets no limit.
   */
  get idMaxLength() {
    return !this.isCompanyKind && this.isResident ? EID_LENGTH : null;
  }
  /* A hint only - it never changes what is typed, which is why the field is not
     type="number": that would refuse the dashes. */
  get idInputMode() {
    return !this.isCompanyKind && this.isResident ? "numeric" : "text";
  }
  get eidComplete() {
    return isValidEmiratesId(String(this.idNumber || "").trim());
  }
  /**
   * One line under the field, always saying the most useful thing it can. The
   * standing sentence explains why there is a search at all; while a resident's
   * number is half-typed it gives way to what is missing, because that is when the
   * Search button is refusing to light and the rep is owed the reason.
   */
  get idHint() {
    if (this.isCompanyKind) {
      return LABELS.JO_F_TL_HINT;
    }
    if (this.isResident && String(this.idNumber || "").trim() && !this.eidComplete) {
      return LABELS.EID_INCOMPLETE;
    }
    return LABELS.JO_F_ID_HINT;
  }
  get searchText() {
    return this.searching ? LABELS.JO_SEARCHING : LABELS.JO_SEARCH;
  }
  /**
   * 1.2 - a resident's search waits for the WHOLE number.
   *
   * findPerson matches EIDNumber__pc exactly, so a partial number can only ever come
   * back "no account found" - and the button that follows that answer opens the form
   * that creates one. Searching early was the duplicate path with extra steps.
   */
  get searchDisabled() {
    if (this.searching || this.saving) {
      return true;
    }
    if (!String(this.idNumber || "").trim()) {
      return true;
    }
    /* A trade licence has no fixed shape, exactly like a passport. */
    return !this.isCompanyKind && this.isResident && !this.eidComplete;
  }
  get notFoundText() {
    return fill(
      this.isCompanyKind ? LABELS.JO_NOT_FOUND_COMPANY : LABELS.JO_NOT_FOUND,
      String(this.idNumber || "").trim()
    );
  }
  /* the required mark is markup now (.field__req in c/mscStyles), not punctuation glued to
     the label text, so it matches Modon's own forms - a red asterisk before the words. */
  get personFacts() {
    const p = this.person || {};
    return [p.residentStatus, p.nationality].filter(Boolean).join(" · ");
  }

  // ── ownership ─────────────────────────────────────────────────────────
  /* Relationship and Ownership % are meaningless until we know who this is, so
     they do not exist until identity is settled one way or the other. */
  get showOwnership() {
    return this.isEdit || this.found || this.showCreate;
  }
  get choosePlaceholder() {
    return LABELS.JO_CHOOSE;
  }

  /* Options come down on the DTO, read from the field's own describe. Never a
     hardcoded list: a value added in the org appears here without a deploy. */
  get relTypeOptions() {
    let options = this.s.relationshipTypes || [];
    /* 1.3 - MSC-180. A company's relationship is commercial. The server refuses
       anything else (checkCompanyRelationship), so the list must not offer it. */
    if (this.isCompanyKind) {
      options = options.filter((o) => COMPANY_REL_TYPES.includes(o.value));
    }
    return options.map((o) => ({
      label: o.label,
      value: o.value,
      selected: o.value === this.relationshipType
    }));
  }
  get relSubOptions() {
    return (this.s.relationshipSubTypes || []).map((o) => ({
      label: o.label,
      value: o.value,
      selected: o.value === this.relationshipSubType
    }));
  }

  get ownershipLabel() {
    return this.isEdit && this.heldOrderIds.length > 1
      ? LABELS.JO_F_OWNERSHIP_ALL
      : LABELS.JO_F_OWNERSHIP;
  }

  get shareNumber() {
    const n = Number(this.share);
    return Number.isNaN(n) ? null : n;
  }

  /**
   * What the primary owner would be left holding.
   *
   * In edit mode this person's current holding returns to the pool first,
   * otherwise raising their own 30% to 35% would read as if it cost the primary
   * owner another 35.
   */
  get previewPrimary() {
    const base = Number(this.s.primaryShare || 0);
    const returned = this.isEdit && this.editParty ? Number(this.editParty.share || 0) : 0;
    const asked = this.shareNumber || 0;
    return Math.round((base + returned - asked) * 100) / 100;
  }

  get showPreview() {
    return this.shareNumber !== null && this.shareNumber > 0;
  }

  get preview() {
    const parts = [];
    const primary = this.previewPrimary;
    if (primary > 0) {
      parts.push({
        key: "primary",
        cls: "dw__seg dw__seg--primary",
        value: primary
      });
    }
    const others = this.parties.filter(
      (p) => !p.isPrimary && p.accountId !== this.editAccountId
    );
    others.forEach((p, i) => {
      const v = Number(p.share || 0);
      if (v <= 0) return;
      parts.push({
        key: p.accountId || `o-${i}`,
        cls: `dw__seg ${SEGMENTS[Math.min(i, SEGMENTS.length - 1)]}`,
        value: v
      });
    });
    parts.push({
      key: "new",
      cls: "dw__seg dw__seg--new",
      value: this.shareNumber
    });

    /* Scaled when the total runs over 100 - the same reason c/mscOwners scales its
       own meter. Here it also matters while the rep is still typing: a stray 900 in
       the Ownership % box would otherwise push every settled segment off the bar,
       and the one thing this preview exists to show is what the entry does to the
       primary owner. The refusal underneath is what states the problem. */
    const total = parts.reduce((sum, x) => sum + x.value, 0);
    const scale = total > 100 ? 100 / total : 1;
    return parts.map((x) => ({
      key: x.key,
      cls: x.cls,
      style: `flex:0 0 ${x.value * scale}%`
    }));
  }

  get previewLabel() {
    const primary = this.primaryParty;
    return fill(
      LABELS.JO_OWNERSHIP_HINT,
      primary ? primary.name : "",
      pct(this.previewPrimary)
    );
  }

  get ownershipOver() {
    return this.shareNumber !== null && this.shareNumber > 0 && this.previewPrimary <= 0;
  }
  get ownershipError() {
    return this.ownershipOver ? LABELS.JO_OWNERSHIP_OVER : null;
  }
  get ownershipInputClass() {
    return this.ownershipOver ? "field__input field__input--error" : "field__input";
  }
  get ownershipHint() {
    if (this.shareNumber === null || this.shareNumber <= 0) {
      return this.isEdit && this.heldOrderIds.length > 1
        ? fill(LABELS.JO_OWNERSHIP_APPLIES, this.heldUnitNames.join(", "))
        : null;
    }
    const primary = this.primaryParty;
    return fill(
      LABELS.JO_OWNERSHIP_HINT,
      primary ? primary.name : "",
      pct(this.previewPrimary)
    );
  }
  get heldUnitNames() {
    const p = this.editParty;
    return p ? p.unitNames || [] : [];
  }

  // ── contact details (edit only) ───────────────────────────────────────
  /**
   * 1.1 - THE FIELDS AN IDENTITY VERIFICATION LINK NEEDS, AND PHASE 1 DOES NOT ASK FOR.
   *
   * Adding a joint owner needs a last name, a Resident Status and one document. That
   * bar is deliberately low - a correct booking must not be harder to enter than a
   * careless one - but MODON's sendKYCForm wants four more things, so in DEV_1 94.8%
   * of joint owners cannot be sent anything at all. This is where that is repaired,
   * and it is the reason the panel offers "Add details" rather than a dead Send.
   *
   * SHOWN ONLY WHILE SOMETHING IS BLANK. Once all four are on the account there is
   * nothing here to do, and four disabled boxes above the Ownership % the rep
   * actually came to change is noise.
   */
  get contactBlanks() {
    const p = this.editParty || {};
    return {
      email: !p.email,
      mobile: !p.mobile,
      nationality: !p.nationality,
      residentStatus: !p.residentStatus
    };
  }

  get showContact() {
    if (!this.isEdit || !this.editParty) return false;
    /* 1.3 - MSC-180. A company has no personal contact detail to collect - every
       field this section repairs is a Person Account field, and fillBlankContactDetails
       is a server-side no-op for a company anyway. Its edit is share, relationship
       and units. */
    if (this.isCompanyKind) return false;
    const b = this.contactBlanks;
    return b.email || b.mobile || b.nationality || b.residentStatus;
  }

  /**
   * A populated field renders disabled WITH its value, not hidden. "Why can I not
   * change this?" is a question the screen should answer before it is asked, and a
   * field that simply is not there reads as one the console forgot.
   */
  get contactRows() {
    const b = this.contactBlanks;
    return [
      { key: "email", id: "cem", label: LABELS.JO_F_EMAIL, type: "email", value: this.email, locked: !b.email },
      { key: "mobile", id: "cmo", label: LABELS.JO_F_MOBILE, type: "tel", value: this.mobile, locked: !b.mobile }
    ].map((f) => ({
      ...f,
      disabled: f.locked || this.saving,
      hint: f.locked ? LABELS.JO_V_CONTACT_LOCKED : null
    }));
  }

  /** 1.6: Nationality is a list, not a box, so it is carried separately too. */
  get contactNationalityLocked() {
    return !this.contactBlanks.nationality;
  }

  /** Resident Status is a toggle, not a box, so it is carried separately. */
  get contactResidencyLocked() {
    return !this.contactBlanks.residentStatus;
  }
  get contactResidencyDisabled() {
    return this.contactResidencyLocked || this.saving;
  }

  // ── units ─────────────────────────────────────────────────────────────
  /* 87% of bookings with a joint owner are one unit and never see this block. */
  get showUnits() {
    return this.showOwnership && this.units.length > 1;
  }
  get showShortcuts() {
    return this.isAdd;
  }
  get hasUncovered() {
    return (this.s.unitsWithNoJointOwner || []).length > 0;
  }

  get unitRows() {
    return this.units.map((u) => {
      const held = this.isEdit && this.heldOrderIds.includes(u.salesOrderId);
      const selected = held || this.selected.includes(u.salesOrderId);
      /* Locked, not hidden. Taking somebody off a unit is a removal, which is a
         service request - so the tick is shown, and shown to be immovable. */
      const disabled = held || !u.open || this.saving;

      let meta = "";
      let metaCls = "dw__pick-meta";
      let lockIcon = false;
      if (held) {
        lockIcon = true;
        meta = "";
      } else if (!u.open) {
        lockIcon = true;
        meta = LABELS.JO_UNIT_LOCKED;
      } else if (!u.ownerCount) {
        meta = this.isEdit ? LABELS.JO_UNIT_CAN_ADD : LABELS.JO_UNIT_NONE;
        metaCls = "dw__pick-meta dw__pick-meta--amber";
      } else if (u.ownerCount === 1) {
        meta = fill(LABELS.JO_UNIT_ONE, pct(u.allocatedShare));
      } else {
        meta = fill(LABELS.JO_UNIT_MANY, u.ownerCount, pct(u.allocatedShare));
      }

      return {
        key: u.salesOrderId,
        name: u.unitName,
        selected,
        disabled,
        meta,
        metaCls,
        lockIcon,
        boxCls: selected ? "dw__box dw__box--on" : "dw__box"
      };
    });
  }

  get unitsFootnote() {
    return this.isEdit ? LABELS.JO_UNITS_LOCKED_HINT : LABELS.JO_UNITS_SAME_PCT;
  }

  // ── submit ────────────────────────────────────────────────────────────
  get selectedCount() {
    return this.unitRows.filter((u) => u.selected).length;
  }

  get showSubmit() {
    return this.showOwnership;
  }

  /** The label states the size of the write, so a 6-record insert is never a slip. */
  get submitText() {
    if (this.saving || this.kycBusy === "create") return LABELS.JO_SAVING;
    if (this.isEdit) return LABELS.JO_SAVE;
    /* 1.4: a new person is created first, then added once KYC is done */
    if (this.isCreating) {
      return this.isCompanyKind ? LABELS.JO_CREATE_COMPANY : LABELS.JO_CREATE_PERSON;
    }
    const n = this.selectedCount;
    return this.units.length > 1 && n > 1
      ? fill(LABELS.JO_SUBMIT_MANY, n)
      : LABELS.JO_SUBMIT_ONE;
  }

  get submitDisabled() {
    if (this.saving || this.kycBusy) return true;
    /* 1.4: creating asks only for the person; relationship and share come with the add */
    if (this.isCreating) {
      if (!this.showCreate) return true;
      if (this.isCompanyKind) return !String(this.companyName || "").trim();
      return !String(this.lastName || "").trim() || !this.residentStatus;
    }
    if (!this.relationshipType || !this.relationshipSubType) return true;
    const n = this.shareNumber;
    if (n === null || n < 1 || n > 99) return true;
    if (this.ownershipOver) return true;
    if (this.units.length > 1 && this.selectedCount === 0) return true;
    if (this.isAdd && !this.found) {
      if (!this.showCreate) return true;
      if (this.isCompanyKind) {
        if (!String(this.companyName || "").trim()) return true;
      } else {
        if (!String(this.lastName || "").trim()) return true;
        if (!this.residentStatus) return true;
      }
    }
    if (this.found && this.person && this.person.blockedReason) return true;
    /* 1.4: MODON refuses the add until KYC is complete */
    if (this.isAdd && this.found && !this.kycReady) return true;
    return false;
  }

  // ── handlers ──────────────────────────────────────────────────────────
  handleClose() {
    this.dispatchEvent(new CustomEvent("closedrawer"));
  }

  handleResidency(event) {
    this.residentStatus = event.detail.value;
  }

  /* 1.3 - MSC-180. Switching kind restarts identity: the number, the create fields
     and the host's search answer all describe the other kind of party. */
  handleKind(event) {
    const kind = event.currentTarget.dataset.kind;
    if (!kind || kind === this.partyKind || this.saving || this.searching) {
      return;
    }
    this.partyKind = kind;
    this.idNumber = "";
    this.companyName = "";
    this.firstName = "";
    this.lastName = "";
    this.clearMatches();
    this.resetManual();
    this.dispatchEvent(new CustomEvent("resetsearch"));
  }

  /**
   * 1.2 - reformats the field in place and returns what to store.
   *
   * The DOM write is NOT redundant. If the rep types something the mask strips - a
   * letter, a second dash, a sixteenth digit - the stored value does not change, so
   * LWC re-renders nothing and the rejected character would sit on screen. Writing
   * the element's value here is what keeps the field and the state agreeing.
   *
   * A passport passes straight through, as it does in the journey.
   */
  handleIdInput(event) {
    const input = event.target;
    /* A trade licence, like a passport, has no mask to apply. */
    if (this.isCompanyKind || !this.isResident) {
      this.idNumber = input.value;
      return;
    }
    const wanted = digitsBeforeCaret(input.value, input.selectionStart);
    const formatted = formatEmiratesId(input.value);
    input.value = formatted;
    const caret = caretAfterDigits(formatted, wanted);
    /* Guarded: setSelectionRange throws on input types that do not support
       selection. The value is the part that matters; the caret is a nicety. */
    try {
      input.setSelectionRange(caret, caret);
    } catch (e) {
      /* ignored */
    }
    this.idNumber = formatted;
  }

  handleIdKey(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      if (!this.searchDisabled) this.handleSearch();
    }
  }

  handleSearch() {
    this.dispatchEvent(
      new CustomEvent("findperson", {
        detail: {
          residentStatus: this.residentStatus,
          idNumber: String(this.idNumber || "").trim()
        }
      })
    );
  }

  handleSearchAgain() {
    this.idNumber = "";
    this.clearMatches();
    this.resetManual();
    this.dispatchEvent(new CustomEvent("resetsearch"));
  }

  handleField(event) {
    const field = event.currentTarget.dataset.f;
    if (!field) return;
    this[field] = event.target.value;
  }

  handleSelectAll() {
    this.selected = this.openUnits.map((u) => u.salesOrderId);
  }

  /** The one-press correction the coverage line asks for. */
  handleSelectUncovered() {
    this.selected = this.openUnits
      .filter((u) => !u.ownerCount)
      .map((u) => u.salesOrderId);
  }

  handleClearUnits() {
    this.selected = this.isEdit ? [...this.heldOrderIds] : [];
  }

  handleToggleUnit(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    this.selected = this.selected.includes(id)
      ? this.selected.filter((x) => x !== id)
      : [...this.selected, id];
  }

  handleSubmit() {
    const targets = this.unitRows.filter((u) => u.selected).map((u) => u.key);
    const detail = {
      mode: this.mode,
      accountId: this.isEdit
        ? this.editAccountId
        : (this.person && this.person.accountId) || null,
      share: this.shareNumber,
      relationshipType: this.relationshipType,
      relationshipSubType: this.relationshipSubType,
      targetOrderIds: targets
    };
    /* 1.1 - EDIT MODE\'S ONE EXCEPTION TO THE RULE BELOW.
       Only fields that are BLANK on the account today are sent, and the server
       checks that again against the record rather than trusting this. Nothing that
       already has a value is transmitted at all, so there is nothing here that
       could overwrite it. Everything else about an existing account is still left
       exactly as it stands. */
    if (this.isEdit) {
      const b = this.contactBlanks;
      const put = (key, value) => {
        const v = String(value || "").trim();
        if (v) detail[key] = v;
      };
      if (b.email) put("email", this.email);
      if (b.mobile) put("mobile", this.mobile);
      if (b.nationality) put("nationality", this.nationality);
      if (b.residentStatus) put("residentStatus", this.residentStatus);
    }
    /* Only when we are creating somebody. An existing account is used as it
       stands - we never write over a record the search just matched, and the one
       narrow exception to that is the block immediately above. */
    if (this.isAdd && !this.found) {
      if (this.isCompanyKind) {
        /* 1.3 - MSC-180. A company is a name and its licence - the licence is the
           number the search just failed to match, so it is the anchor the server
           re-matches before it creates anything. */
        detail.isCompany = true;
        detail.companyName = String(this.companyName || "").trim();
        detail.tradeLicence = String(this.idNumber || "").trim();
      } else {
        detail.firstName = String(this.firstName || "").trim();
        detail.lastName = String(this.lastName || "").trim();
        detail.email = String(this.email || "").trim();
        detail.mobile = String(this.mobile || "").trim();
        detail.nationality = String(this.nationality || "").trim();
        detail.residentStatus = this.residentStatus;
        const id = String(this.idNumber || "").trim();
        /* Passed as BOTH, and the server takes the one that fits. The rep typed the
           number in front of them; they should never have to be right about which
           box it belongs in. */
        detail.eidNumber = id;
        detail.passportNumber = id;
      }
    }
    /* 1.4: creating is its own call; the add comes later, once KYC is done */
    if (this.isCreating) {
      this.create(detail);
      return;
    }
    this.dispatchEvent(new CustomEvent("saveowner", { detail }));
  }

  // ── 1.4 · KYC actions ────────────────────────────────────────────────
  get ctx() {
    return {
      opportunityId: this.s.opportunityId,
      salesOrderId: this.s.focusedSalesOrderId || null
    };
  }

  async create(detail) {
    this.kycBusy = "create";
    this.kycError = undefined;
    try {
      const person = await createPerson({
        input: {
          ...this.ctx,
          firstName: detail.firstName,
          lastName: detail.lastName,
          email: detail.email,
          mobile: detail.mobile,
          nationality: detail.nationality,
          residentStatus: detail.residentStatus,
          eidNumber: detail.eidNumber,
          passportNumber: detail.passportNumber,
          isCompany: detail.isCompany === true,
          companyName: detail.companyName,
          tradeLicence: detail.tradeLicence,
          /* 1.5: only after the rep saw the matches, and only while the switch allows it */
          createDespiteMatch: detail.createDespiteMatch === true
        }
      });
      /* 1.5: existing customers match; nothing was created, the rep chooses */
      if (person && !person.accountId && Array.isArray(person.matches) && person.matches.length) {
        this.matchChoice = person;
        this.chosenMatchId = undefined;
        this.lastCreateDetail = detail;
        return;
      }
      this.clearMatches();
      this.resetManual();
      this.kycOverride = person;
      /* 1.8 - UI-30: made here, so its card says "New account" */
      this.createdAccountId = (person && person.accountId) || null;
      /* the host shows them as found, so the drawer continues with this person */
      this.dispatchEvent(new CustomEvent("personfound", { detail: { person } }));
    } catch (e) {
      this.kycError = reduceError(e);
    } finally {
      this.kycBusy = undefined;
    }
  }

  /** 1.8 - the account this drawer created, if the card is showing it. */
  createdAccountId = null;

  /** 1.8 - UI-30: "New account" for the person created in this drawer, else "Existing account". */
  get foundChipLabel() {
    const p = this.person || {};
    return this.createdAccountId && p.accountId === this.createdAccountId
      ? this.labels.JO_NEW_CHIP
      : this.labels.JO_FOUND_CHIP;
  }

  // ── 1.5 · the chooser ────────────────────────────────────────────────
  handleMatchPick(event) {
    const id = event.currentTarget.dataset.id;
    if (!id || this.kycBusy) return;
    this.chosenMatchId = id;
  }

  handleMatchBack() {
    this.clearMatches();
    this.kycError = undefined;
  }

  /** The chosen customer is the joint owner: read their card (MODON's KYC check included). */
  async handleMatchContinue() {
    if (!this.chosenMatchId || this.kycBusy) return;
    this.kycBusy = "pick";
    this.kycError = undefined;
    try {
      const person = await checkPerson({ ...this.ctx, accountId: this.chosenMatchId });
      this.clearMatches();
      this.resetManual();
      this.kycOverride = person;
      this.dispatchEvent(new CustomEvent("personfound", { detail: { person } }));
    } catch (e) {
      this.kycError = reduceError(e);
    } finally {
      this.kycBusy = undefined;
    }
  }

  /** Only offered while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on; the server checks it again. */
  handleCreateAnyway() {
    if (!this.lastCreateDetail || this.kycBusy) return;
    this.create({ ...this.lastCreateDetail, createDespiteMatch: true });
  }

  // ── 1.5 · the manual KYC route ───────────────────────────────────────
  toggleManual() {
    this.manualOpen = !this.manualOpen;
  }

  handlePartyState(event) {
    const d = event.detail || {};
    this.partyManual = { offer: d.offer === true, approved: d.approved === true };
    if (!this.partyManual.offer) {
      this.manualOpen = false;
    }
  }

  /** Something on the manual route moved: ask MODON's check again. */
  handlePartyChanged() {
    this.handleKycCheck();
  }

  /** c/mscKycCapture's Update KYC, through c/mscPartyKyc: the dialog is hosted here, above the drawer. */
  handleOpenKyc(event) {
    event.stopPropagation();
    const d = event.detail || {};
    if (!d.subjectId) return;
    this.kycModalSubjectId = d.subjectId;
    this.kycModalSubjectName = d.subjectName || (this.card && this.card.name) || null;
    this.kycModalOpen = true;
  }

  handleKycModalClose(event) {
    this.kycModalOpen = false;
    const saved = !!(event && event.detail && event.detail.saved);
    const party = this.template.querySelector("c-msc-party-kyc");
    if (party && typeof party.refresh === "function") {
      party.refresh(saved);
    }
    this.handleKycCheck();
  }

  async handleKycSend() {
    if (this.kycBusy || !this.card) return;
    this.kycBusy = "send";
    this.kycError = undefined;
    try {
      this.kycOverride = await sendCandidateVerification({
        ...this.ctx,
        accountId: this.card.accountId
      });
    } catch (e) {
      this.kycError = reduceError(e);
    } finally {
      this.kycBusy = undefined;
    }
  }

  async handleKycCheck() {
    if (this.kycBusy || !this.card) return;
    this.kycBusy = "check";
    this.kycError = undefined;
    try {
      this.kycOverride = await checkPerson({
        ...this.ctx,
        accountId: this.card.accountId
      });
    } catch (e) {
      this.kycError = reduceError(e);
    } finally {
      this.kycBusy = undefined;
    }
  }
}