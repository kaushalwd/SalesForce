/**
 * mscKycCapture - Update KYC, after a manual KYC has been approved.
 *
 * Version  Author      Date         Detail
 * 2.15     Aurelix Dev 30 Sep 2026  "Manual KYC approved" said once (UI-05). After a regeneration the earlier signed
 *                                   form stays linked and the new one reads as awaited, not required (R2-13, R2-18).
 * 2.14     Aurelix Dev 29 Sep 2026  Refresh clears the last action's notice and error, so an old "form generated"
 *                                   line no longer stays under a signed form.
 * 2.13     Aurelix Dev 29 Sep 2026  Regenerate: once a form exists (generated or signed) the control reads
 *                                   "Regenerate" and asks first. Allowed when no request is in flight
 *                                   (AurelixKycGenerationGate 2.3); "Form requested" now means generationInFlight.
 * 2.12     Aurelix Dev 28 Sep 2026  party-account-id: the same panel for one joint owner, in the Add Joint Owner
 *                                   drawer (c/mscPartyKyc). The outcome and Generate are the party's
 *                                   (AurelixManualKycService getPartyManualOutcome, requestPartyKycFormGeneration);
 *                                   Update KYC raises the same `openkyc` with the party's Account, and the drawer
 *                                   hosts the dialog. A party's form is not sent for signature from the console
 *                                   (AurelixKycFormGenerator 1.5), so its two form sentences say so instead of
 *                                   "sent for signature". The buyer's panel is unchanged.
 * 2.11     Aurelix Dev 27 Sep 2026  A company is offered Generate as well (AurelixManualKycService 4.13, as in
 *                                   MODON's Sales App), so its approved sentence names the form too, keyed
 *                                   on customerType rather than on Generate being hidden.
 * 2.10     Aurelix Dev 24 Sep 2026  A FAILED FORM COULD BE SEEN BUT NOT RETRIED. 2.9 gave the Error state
 *                                   its own words and left the representative with nothing to press, so
 *                                   the only way back was somebody with Salesforce access.
 *                                   The Error state now offers the attempt again, and only the Error state:
 *                                     1 the SAME control, worded KYCC_RETRY / KYCC_RETRYING_BTN, shown
 *                                       when the server says the failed attempt may be re-run
 *                                       (outcome.formRetryable, AurelixManualKycService 4.10). No second
 *                                       button, no alert, no colour: the quiet grey control it already was.
 *                                     2 the failure stays on the screen. The status word is still "Form
 *                                       not generated" and the sentence beneath it still says the last
 *                                       attempt did not succeed, before, during and after the retry.
 *                                     3 one attempt at a time. handleGenerate returns at once if one is
 *                                       already running: the disabled state only reaches the button on the
 *                                       next render, so a double click could otherwise start two Nintex
 *                                       renders.
 *                                     4 formUnderway no longer counts a FAILED attempt as underway, so
 *                                       where a retry is refused because a field or a file is still
 *                                       missing, that list comes back and names the route forward. 2.8
 *                                       hid the lists for a form asked for, produced or signed back; a
 *                                       failed attempt is none of the three.
 *                                   Every other state is untouched: pending, approved, rejected, requested,
 *                                   generated, sent and signed read and behave exactly as in 2.9.
 * 2.9      Aurelix Dev 24 Sep 2026  TWO RESIDUALS FROM 2.8.
 *                                   (a) The panel read the form state from one exact word, 'Generated',
 *                                   so a "KYC Form" row that already held its PDF still said "Form
 *                                   requested". The server now classifies the row instead
 *                                   (AurelixManualKycService 4.9): a file on the row, or Generated or
 *                                   Sent, means the form exists; Error is reported as a failed attempt in
 *                                   its own words; and a value outside MODON's four is named rather than
 *                                   read as a request. Every value the picklist allows now has wording
 *                                   that is true of it, and so does one it does not allow yet.
 *                                   (b) Where the required documents checklist is rendered above this
 *                                   panel, its three file names appeared again under "Files to upload:".
 *                                   c/mscKycGate passes documents-listed and the file LIST is suppressed
 *                                   when it is true. Only the rendering: hasMissingFiles still reports
 *                                   that files are missing, so the heading still travels with its own
 *                                   list and generateNote still stays quiet rather than naming the same
 *                                   files in a sentence. The fields list is untouched, and with no
 *                                   checklist above (a verified or awaiting view) the file list is shown
 *                                   exactly as before.
 * 2.8      Aurelix Dev 24 Sep 2026  "COMPLETE THESE BEFORE GENERATING" WAS PRINTED AFTER GENERATING. The
 *                                   lists showed whenever Generate was unavailable, so a buyer whose form
 *                                   was generated and signed still carried a list of gaps beneath a
 *                                   correctly disabled button, and it read as a defect.
 *                                   Once the form is requested, generated or signed back, neither list
 *                                   nor heading appears and the gate's sentence is not repeated: the
 *                                   status word and the one line above are the true reason. Nothing
 *                                   changes before the form is asked for. The three states are told
 *                                   apart on the record, not guessed: generationRequested is the ask,
 *                                   formGenerated is the PDF (AurelixManualKycService 4.8), and
 *                                   signedReceived is the signed copy.
 * 2.7      Aurelix Dev 24 Sep 2026  THE MISSING LIST TOLD THE REP TO DO THE IMPOSSIBLE. Under "Complete
 *                                   these in Update KYC" it listed the passport and the Emirates ID
 *                                   scans, which are not on MODON's Update KYC form at all, so the rep
 *                                   was sent to the wrong place. The gate now reports
 *                                   the two kinds apart (AurelixKycGenerationGate 1.3), and this panel
 *                                   shows fields under the heading they had and files under one of
 *                                   their own, worded as an upload. Either heading appears only when
 *                                   its own list has something in it, so a buyer who is only short of a
 *                                   file is never told to go to Update KYC. No string matching on
 *                                   "(file)" here: the server says which is which.
 * 2.6      Aurelix Dev 21 Sep 2026  Hidden while the request is pending: the box above says it once, from
 *                                   the request itself (c/mscKycGate 3.8), so this panel no longer
 *                                   repeats "Manual KYC pending" with a second Refresh. A
 *                                   rejection now says when and by whom, with the approver's comment
 *                                   when there is one (AurelixManualKycService 4.3; SCW-139).
 * 2.5      Aurelix Dev 21 Sep 2026  While Sales Operations holds the manual KYC, the panel shows only its
 *                                   status word. Its sentence ("The manual submission is with Sales
 *                                   Operations.") repeated the gate's own line just above ("Manual
 *                                   verification is with Sales Operations."). The
 *                                   server's `pending` and the gate's MANUAL_PENDING are the same two
 *                                   values, so the gate's line is always there when this one is not.
 * 2.4      Aurelix Dev 18 Sep 2026  Seen in testing: Generate takes twenty-odd seconds (Nintex) and
 *                                   the panel gave no sign of it - the button greyed and Update KYC
 *                                   vanished (canUpdate hid on busy). Generate now reads
 *                                   "Generating…" while it runs, Update KYC stays and is disabled,
 *                                   and a status line says the form is being produced. The
 *                                   missing list now opens with "Complete these in Update KYC
 *                                   before generating": Update KYC is the way to clear
 *                                   it, and Generate enables itself once the form is saved.
 * 2.3      Aurelix Dev 18 Sep 2026  Seen live after a DocuSign signature: one Refresh read "Signed
 *                                   form received" while the checklist and verdict beside it still
 *                                   said 3 of 4 and "KYC required" - the parent re-ran the verdict
 *                                   in parallel with getManualOutcome, which is where the signed
 *                                   copy gets filed (AurelixManualKycService 4.2). load() now
 *                                   returns its promise and `changed` is raised only after the
 *                                   outcome has come back, so the verdict always reads the state
 *                                   the outcome left behind. Same for Generate.
 * 2.2      Aurelix Dev 18 Sep 2026  An approved company read "generate the form for signature";
 *                                   it now reads KYCC_B_APPROVED_ORG (no Generate for companies).
 * 2.1      Aurelix Dev 18 Sep 2026  The dialog moved up to c/mscBookingPage (see
 *                                   c/mscKycCaptureModal 1.1); this panel raises `openkyc` and is
 *                                   told to reload(saved) when it closes. "Details saved" only
 *                                   after a real save.
 * 2.0      Aurelix Dev 18 Sep 2026  MSC-179 / MSC-177 (B4 + B8 + B6).
 *                                   B4 - Update KYC opens c/mscKycCaptureModal, which hosts
 *                                   MODON's own c/accountkycform on the subject the server names
 *                                   (outcome.subjectId: the person's Account, or the POA Contact
 *                                   for a company). The console's own renderer below is RETIRED
 *                                   behind LABELS.KYCC_INLINE_FORM (false) and kept one release;
 *                                   with the modal, no field, rule or option is re-implemented.
 *                                   When the modal closes the outcome is re-read and the parent
 *                                   told, so the gate's missing list and the verdict both move.
 *                                   B8 - Generate follows AurelixKycGenerationGate through the
 *                                   outcome: the button is disabled with the gate's one sentence
 *                                   (generationBlockedReason) while anything is missing, the
 *                                   Nintex template is unconfigured, or the row is absent.
 *                                   B6 - a company never sees Generate (generationOffered false);
 *                                   its subject line names the POA. Also: the signed-form link now
 *                                   carries the site path prefix (a root /sfc link 404s here).
 * 1.2      Aurelix Dev 08 Sep 2026  SC-UI-010 FUNCTIONAL PARITY. Three differences from MODON's
 *                                   form were capable of producing wrong or lost data, so they
 *                                   are closed here; the rest stay UX-only and documented.
 *                                     1 CONDITIONAL VISIBILITY - visibleWhenField/Values/Negate
 *                                       were ignored, so fields that should be hidden were
 *                                       offered and could be filled with contradictory answers.
 *                                     2 DEPENDENT PICKLISTS - the full option list was rendered
 *                                       regardless of the controlling field, so an invalid
 *                                       combination could be chosen and saved.
 *                                     3 VILLA NUMBER - loadForm splits the villa out of the
 *                                       street into section.villaValue and saveForm expects it
 *                                       back as `villaNumber`. It was never rendered, so editing
 *                                       the street silently dropped the villa from the address.
 *                                   Everything still comes from MODON's own definition - no
 *                                   field, rule or option is hardcoded here.
 * 1.1      Aurelix Dev 08 Sep 2026  SC-UI-005 / SC-UI-006. The form opened with all 34 controls
 *                                   EMPTY even where the record held values. Cause: loadForm
 *                                   returns the values alongside the definition, in
 *                                   FormDefinition.accountValues / .contactValues, and this
 *                                   component read only .sections - a response-mapping bug here,
 *                                   not a backend one. The values are now bound to the controls,
 *                                   and MODON's own `required` flag is surfaced as a single `*`.
 *                                   A native <select> ignores a value binding applied before its
 *                                   options exist, so the assignment is re-applied in
 *                                   renderedCallback - see there.
 *
 *                                   SAVE SEMANTICS ARE UNCHANGED AND THIS MATTERS: the loaded
 *                                   values are held separately from the edited ones, and only
 *                                   what the representative actually changed is posted. Opening
 *                                   the form still writes nothing.
 * 1.0      Aurelix Dev 07 Sep 2026  Phase 3B. The step that was missing: an approved manual KYC
 *                                   still has to be captured, generated, signed and re-checked,
 *                                   and none of that existed inside the console.
 *
 * THE FORM IS MODON'S, RENDERED HERE.
 * AccountKycController.loadForm returns the whole field definition - sections, labels, types,
 * picklist options, required flags - and saveForm takes the values back in its own payload
 * shape. This component renders and posts that definition. It does not hold a field list of its
 * own, so a field MODON adds appears here with no deployment and no drift.
 *
 * WHAT GATES GENERATION IS OURS, AND IS OPTION B.
 * The Generate control is offered only when AurelixManualKycService says the configured,
 * RESIDENCY-AWARE requirements are met. MODON's own validator is deliberately not used for that
 * decision because it ignores ResidentType__c and would ask a non-resident for an Emirates ID
 * (Q-H). Their form's own field-level rules still apply on save - those are theirs and are kept.
 *
 * GENERATION AND SIGNATURE ARE NOT REIMPLEMENTED.
 * Generate raises MODON's Documents__c.Auto_Generate_Document__c flag and their chain does the
 * rest: Nintex builds the PDF, the auto-send queueable raises a DocuSign envelope, and the
 * signed file returns to its own Documents__c row. No PDF template, no Signzy document logic and
 * no DocuSign integration is duplicated, and none of those classes is modified.
 *
 * ELIGIBILITY IS NEVER SET BY HAND.
 * When the signed form comes back this component does not mark anybody verified: it asks the
 * parent to re-run AurelixKycEligibilityService. Real KYC state plus real documents remain the
 * only source of truth.
 *
 * SCOPE, STATED HONESTLY. The renderer covers the field types MODON's KYC form actually uses
 * here - text, textarea, picklist, date, number, email, phone, checkbox. Their definition also
 * carries dependent picklists, conditional visibility, auto-set rules and address blocks; those
 * are rendered as their underlying fields rather than with the quick action's full behaviour.
 * A customer needing that behaviour is still completed on the Account quick action, which is
 * untouched.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { reduceError } from "c/modonSalesFormat";
import getManualOutcome from "@salesforce/apex/AurelixManualKycService.getManualOutcome";
import getCaptureForm from "@salesforce/apex/AurelixManualKycService.getCaptureForm";
import saveCaptureForm from "@salesforce/apex/AurelixManualKycService.saveCaptureForm";
import requestKycFormGeneration from "@salesforce/apex/AurelixManualKycService.requestKycFormGeneration";
/* 2.12: the joint owner's route */
import getPartyManualOutcome from "@salesforce/apex/AurelixManualKycService.getPartyManualOutcome";
import requestPartyKycFormGeneration from "@salesforce/apex/AurelixManualKycService.requestPartyKycFormGeneration";
import getSitePathPrefix from "@salesforce/apex/SalesConsoleController.getSitePathPrefix";

/* A Datetime's LOCAL calendar day, "18 Sep 2026". formatDate reads the UTC day - right for a Date,
   a day early for a request sent late in the evening in Abu Dhabi. The month names are the console's
   own: toLocaleDateString gave "Sept" in Chrome. */
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function localDay(v) {
  const d = v ? new Date(v) : null;
  if (!d || isNaN(d.getTime())) return "";
  return `${d.getDate()} ${SHORT_MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

/* 2.0 - the console's own renderer stays reachable for one release; the modal is the route. */
const INLINE_FORM = LABELS.KYCC_INLINE_FORM === true;

/* 2.12: a joint owner's form is filed, not sent; the rep sends it with KYC Manual Sign */
const PARTY_B_GENERATING = "The form is being generated.";
const PARTY_B_GENERATED = "Not sent for signature. Use KYC Manual Sign on the KYC Form document.";

/* 2.13 - regeneration wording */
const REGEN = "Regenerate";
const REGENERATING = "Regenerating…";
const REGEN_ASK = "Generate a new KYC form and send it for signature?";
const PARTY_REGEN_ASK = "Generate a new KYC form?";
const REGEN_OFF = "Regenerate is unavailable: {0}";

const TEXT_TYPES = ["STRING", "TEXTAREA", "EMAIL", "PHONE", "URL", "DOUBLE", "INTEGER", "CURRENCY", "PERCENT"];

export default class MscKycCapture extends LightningElement {
  labels = LABELS;

  _opportunityId;

  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(value) {
    this._opportunityId = value;
    this.scheduleLoad();
  }

  /** 2.12 - a joint owner's Account; null means the buyer. */
  _partyAccountId;
  @api
  get partyAccountId() {
    return this._partyAccountId;
  }
  set partyAccountId(value) {
    this._partyAccountId = value;
    this.scheduleLoad();
  }

  get isParty() {
    return !!this._partyAccountId;
  }

  /* 2.12 - both ids are set one after the other; load once, after both */
  _loadQueued = false;
  loadSeq = 0;
  scheduleLoad() {
    if (this._loadQueued) {
      return;
    }
    this._loadQueued = true;
    Promise.resolve().then(() => {
      this._loadQueued = false;
      this.load();
    });
  }

  /**
   * 2.9 - true when c/mscKycGate is already showing the required documents checklist above this
   * panel. The checklist names the same rows and carries an Upload button on each, so this panel
   * does not print the names a second time. It still KNOWS they are missing: see showMissingFiles.
   */
  @api documentsListed = false;

  /** 2.15 - true when c/mscKycGate's own status already reads "Manual KYC approved". */
  @api approvedShown = false;

  outcome;
  sections = [];
  /** MODON's definition as returned, kept so visibility can be recomputed on every change. */
  rawSections = [];
  /* What the record holds now - shown in the controls. Never posted on its own. */
  loadedAccount = {};
  loadedContact = {};
  /* What the representative actually changed. ONLY this is posted. */
  accountValues = {};
  contactValues = {};
  formOpen = false;
  /** 2.0 - the modal hosting MODON's form. */
  modalOpen = false;
  busy = false;
  problem;
  notice;

  /* ── state ───────────────────────────────────────────────────────────────── */

  /** Resolves once the outcome is in (or has failed); callers that tell the parent wait for it. */
  load() {
    const seq = ++this.loadSeq;
    if (!this._opportunityId) {
      this.outcome = undefined;
      return Promise.resolve();
    }
    const call = this.isParty
      ? getPartyManualOutcome({ opportunityId: this._opportunityId, accountId: this._partyAccountId })
      : getManualOutcome({ opportunityId: this._opportunityId });
    return call
      .then((o) => {
        if (seq === this.loadSeq) this.outcome = o;
      })
      .catch(() => {
        if (seq === this.loadSeq) this.outcome = undefined;
      });
  }

  /* 2.6 - not while pending: c/mscKycGate says that, once */
  get show() {
    return !!this.outcome && !!this.outcome.approvalStatus && !this.outcome.pending;
  }

  get statusWord() {
    const o = this.outcome || {};
    /* 2.13 - a request on its way outranks last round's form */
    if (o.generationInFlight) return this.labels.KYCC_S_GENERATING;
    if (o.signedReceived) return this.labels.KYCC_S_SIGNED;
    /* 2.8 - the PDF exists: no longer "being generated" */
    if (o.formGenerated) return this.labels.KYCC_S_GENERATED;
    /* 2.9 - before the request flag, which is never cleared and would mask both of these */
    if (o.formFailed) return this.labels.KYCC_S_FAILED;
    if (o.formStatusUnknown) return this.labels.KYCC_S_UNCLEAR;
    if (o.approved) return this.labels.KYCC_S_APPROVED;
    if (o.rejected) return this.labels.KYCC_S_REJECTED;
    if (o.pending) return this.labels.KYCC_S_PENDING;
    return this.labels.KYCC_S_PENDING;
  }

  /** 2.15 - UI-05: "Manual KYC approved" is said once, by the box above when it says it. */
  get showStatus() {
    return !(this.approvedShown === true && this.statusWord === this.labels.KYCC_S_APPROVED);
  }

  /** 2.15 - a signed form from an earlier round is on file, none yet for this one. */
  get earlierSignedOnFile() {
    const o = this.outcome || {};
    return !o.signedReceived && !!o.earlierSignedFileId;
  }

  get body() {
    const o = this.outcome || {};
    /* 2.13 - same order as statusWord */
    if (o.generationInFlight) {
      return this.isParty ? PARTY_B_GENERATING : this.labels.KYCC_B_GENERATING;
    }
    if (o.signedReceived) return this.labels.KYCC_B_SIGNED;
    /* 2.12 - a joint owner's form is filed, not sent */
    if (o.formGenerated && this.isParty) return PARTY_B_GENERATED;
    /* 2.15 - R2-18: MODON's booking check still accepts the earlier signed form, so the new one
       is awaited for information only */
    if (o.formGenerated && this.earlierSignedOnFile) return this.labels.KYCC_B_GENERATED_EARLIER;
    if (o.formGenerated) return this.labels.KYCC_B_GENERATED;
    /* 2.9 - same order as statusWord, so the word and the sentence can never disagree */
    if (o.formFailed) return this.labels.KYCC_B_FAILED;
    if (o.formStatusUnknown) {
      return this.labels.KYCC_B_UNCLEAR.replace("{0}", o.documentStatus || "");
    }
    if (o.approved) {
      /* 2.11 - a company's sentence names the signatory and the company */
      return o.customerType === "Organisation"
        ? this.labels.KYCC_B_APPROVED_ORG
        : this.labels.KYCC_B_APPROVED;
    }
    if (o.rejected) return this.rejectedLine;
    /* 2.5 - the gate above already says Sales Operations has it */
    if (o.pending) return "";
    return this.labels.KYCC_B_PENDING;
  }

  /** 2.6 - "Rejected 19 Sep 2026 by <reviewer>. “Passport copy unreadable”" */
  get rejectedLine() {
    const o = this.outcome || {};
    if (!o.rejectedAt) {
      return this.labels.KYCC_B_REJECTED;
    }
    const line = this.labels.KYCC_B_REJECTED_ON
      .replace("{0}", localDay(o.rejectedAt))
      .replace("{1}", o.rejectedBy || "");
    return o.rejectionComment ? `${line} “${o.rejectionComment}”` : line;
  }

  /** Update KYC belongs to an approved manual route only (2.4: shown while busy, just disabled). */
  get canUpdate() {
    return !!this.outcome && this.outcome.canUpdateKyc === true;
  }

  get updateDisabled() {
    return this.busy;
  }

  /**
   * 2.10 - true when the control on screen is a second attempt at a form that failed. The server
   * decides (formRetryable = it failed AND the gate would let it run), so the retry wording never
   * appears on a control that could not do anything.
   */
  get isRetry() {
    return (this.outcome || {}).formRetryable === true;
  }

  /**
   * 2.13 - a form already exists for this customer (generated this round, or signed), so the control
   * makes a new one and asks first. A failed attempt keeps its own "Try again" (2.10).
   */
  get isRegenerate() {
    const o = this.outcome || {};
    return !this.isRetry && (o.formGenerated === true || o.signedReceived === true);
  }

  /** 2.4 - the Generate control's own words while Nintex renders. 2.10 - or while it tries again. */
  get generateLabel() {
    if (this.generating) {
      if (this.isRetry) return this.labels.KYCC_RETRYING_BTN;
      return this.isRegenerate ? REGENERATING : this.labels.KYCC_GENERATING_BTN;
    }
    if (this.isRetry) return this.labels.KYCC_RETRY;
    return this.isRegenerate ? REGEN : this.labels.KYCC_GENERATE;
  }

  generating = false;

  /** 2.13 - the one question before a regeneration is open. */
  confirming = false;
  /** 2.13 - where focus goes after the next render: "confirm" or "generate". */
  focusNext = null;

  get regenAsk() {
    return this.isParty ? PARTY_REGEN_ASK : REGEN_ASK;
  }

  get regenYes() {
    return REGEN;
  }

  /** 2.13 - the control steps aside while its question is open. */
  get showGenerateButton() {
    return this.showGenerate && !this.confirming;
  }

  get showConfirm() {
    return this.confirming && this.showGenerate;
  }

  /** 2.0 - what the form opens on: the person's Account, or the POA Contact. */
  get subjectId() {
    const o = this.outcome || {};
    return o.subjectId || o.accountId || null;
  }

  get subjectName() {
    return (this.outcome && this.outcome.subjectName) || null;
  }

  /** 2.0 - B6: Generate is offered where the server says so (2.11: companies too). */
  get showGenerate() {
    const o = this.outcome || {};
    return o.canUpdateKyc === true && o.generationOffered === true;
  }

  get canGenerate() {
    const o = this.outcome || {};
    return this.showGenerate && o.canGenerate === true && !this.busy;
  }

  get generateDisabled() {
    return !this.canGenerate;
  }

  /** 2.0 - B8: the gate's one sentence, shown only while Generate is offered but off. */
  get generateNote() {
    const o = this.outcome || {};
    /* 2.13 - a request in flight: the status line above says so */
    if (!this.showGenerate || o.canGenerate === true || o.generationInFlight === true) {
      return null;
    }
    const why = o.generationBlockedReason;
    if (!why) {
      return null;
    }
    if (this.formUnderway) {
      /* 2.13 - a form exists and cannot be made again: say why */
      return this.isRegenerate
        ? REGEN_OFF.replace("{0}", why)
        : this.labels.KYCC_GENERATE_OFF.replace("{0}", why);
    }
    if (this.hasMissing || this.hasMissingFiles) {
      /* 2.7 - either list below already says it, files included */
      return null;
    }
    return this.labels.KYCC_GENERATE_OFF.replace("{0}", why);
  }

  /**
   * 2.8 - the form is out of the rep's hands: asked for, produced, or signed back. Nothing left
   * here is "before generating", so neither list belongs on the screen.
   */
  get formUnderway() {
    const o = this.outcome || {};
    /* 2.10 - an attempt that FAILED is not underway. The request flag is never cleared, so without
       this a failed row read as "asked for" and the lists that name the route forward stayed hidden.
       2.13 - "asked for" is a request in flight now, not that flag */
    if (o.formFailed === true) {
      return false;
    }
    return o.generationInFlight === true || o.formGenerated === true || o.signedReceived === true;
  }

  /** 2.8 - the lists answer one question only: what is left BEFORE the form is generated. */
  get listsApply() {
    const o = this.outcome || {};
    return o.canUpdateKyc === true && o.canGenerate !== true && !this.formUnderway;
  }

  /** Fields the rep fills in Update KYC. 2.7 - fields only; the files are listed separately. */
  get missing() {
    const o = this.outcome || {};
    return this.listsApply ? o.missingFields || [] : [];
  }

  get hasMissing() {
    return this.missing.length > 0;
  }

  /** 2.7 - identity documents with no file yet. Uploaded on the documents list, not typed. */
  get missingFiles() {
    const o = this.outcome || {};
    return this.listsApply ? o.missingFiles || [] : [];
  }

  get hasMissingFiles() {
    return this.missingFiles.length > 0;
  }

  /**
   * 2.9 - whether to PRINT the file list. Separate from hasMissingFiles on purpose: the checklist
   * above already names these rows and offers an Upload on each, so repeating them here is noise,
   * but generateNote must still know they are missing or it would name them all over again in a
   * sentence. The heading lives inside the same template block as the list, so the two appear and
   * disappear together, as 2.7 intended.
   */
  get showMissingFiles() {
    return this.hasMissingFiles && this.documentsListed !== true;
  }

  /* ── 2.0 - the modal ─────────────────────────────────────────────────────── */

  /**
   * 2.1 - the dialog is hosted by c/mscBookingPage (a child of its .page), because inside this
   * panel it was trapped in the customer card. The request travels up as a composed event.
   */
  handleOpenModal() {
    if (!this.subjectId) {
      return;
    }
    this.problem = null;
    this.notice = null;
    this.confirming = false;
    this.dispatchEvent(
      new CustomEvent("openkyc", {
        bubbles: true,
        composed: true,
        detail: { subjectId: this.subjectId, subjectName: this.subjectName }
      })
    );
  }

  /**
   * The page tells this panel the dialog closed. `saved` is true only when MODON's form raised
   * its success toast, so a Cancel never reads "Details saved". The outcome is re-read (the
   * gate may have moved) and focus returns to the Update KYC control.
   */
  @api
  reload(saved) {
    this.modalOpen = false;
    this.notice = saved === true ? this.labels.KYCC_SAVED : null;
    this.load();
    const btn = this.template.querySelector(".kycc__btn--update");
    if (btn) {
      btn.focus();
    }
  }

  get useInlineForm() {
    return INLINE_FORM;
  }

  /* ── the signed form ─────────────────────────────────────────────────────
     Option B. loadsignedkycform is NOT embedded: it reads its id from
     CurrentPageReference.state.id and has no @api recordId, so as a child it resolves nothing,
     and its Apex is not granted to the console permission set. Instead the console links to the
     Salesforce file it already knows about. No DocuSign logic is duplicated.                  */

  /** 2.0 - the site's own path prefix (/sales); a root /sfc link 404s on the site domain. */
  sitePrefix = "";

  connectedCallback() {
    getSitePathPrefix()
      .then((p) => {
        this.sitePrefix = p || "";
      })
      .catch(() => {
        this.sitePrefix = "";
      });
  }

  get signedFileUrl() {
    const o = this.outcome || {};
    /* 2.15 - R2-13: the earlier signed form stays reachable after a regeneration */
    const id = o.signedFileId || o.earlierSignedFileId;
    return id ? `${this.sitePrefix}/sfc/servlet.shepherd/document/download/${id}` : null;
  }

  /* ── the form ────────────────────────────────────────────────────────────── */

  handleOpenForm() {
    /* 2.12 - a party always uses MODON's form in the dialog; the inline renderer is buyer-only */
    if (!INLINE_FORM || this.isParty) {
      this.handleOpenModal();
      return;
    }
    if (this.formOpen) {
      this.formOpen = false;
      return;
    }
    this.busy = true;
    this.problem = null;
    getCaptureForm({ opportunityId: this._opportunityId })
      .then((payload) => {
        const form = (payload && payload.form) || {};
        /* SC-UI-005: loadForm hands back the current values with the definition. Keep them
           apart from the edit buffer so opening the form stays non-destructive. */
        this.loadedAccount = form.accountValues || {};
        this.loadedContact = form.contactValues || {};
        this.accountValues = {};
        this.contactValues = {};
        this.rawSections = (form.sections || []);
        this.sections = this.toSections(payload);
        this.formOpen = true;
      })
      .catch((e) => {
        this.problem = reduceError(e);
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /** MODON's definition, flattened only as far as a template can iterate it. */
  toSections(payload) {
    const form = (payload && payload.form) || {};
    const sections = form.sections || [];
    return this.buildSections(sections);
  }

  /**
   * Rebuilt whenever a value changes, so conditional visibility and dependent picklists follow
   * the current answers rather than the answers the form opened with.
   */
  buildSections(sections) {
    return sections.map((s, si) => ({
      key: s.key || `s-${si}`,
      label: s.label,
      target: s.targetObject,
      /* the villa input MODON splits out of the street line; rendered only where it exists */
      villaLabel: s.villaLabel,
      villaValue: this.villaFor(s),
      showVilla: !!(s.isAddress && s.villaLabel),
      villaMarker: s.villaRequired === true ? "*" : "",
      fields: (s.fields || [])
        .filter((f) => this.isVisible(f, s.targetObject))
        .map((f) => this.toField(f, s.targetObject))
    }));
  }

  /** The villa number: what the rep has typed this session, else what loadForm split out. */
  villaFor(s) {
    if (!s || !s.isAddress) {
      return "";
    }
    const edited = this.accountValues.villaNumber;
    return edited === undefined ? this.asText(s.villaValue) : this.asText(edited);
  }

  handleVilla(event) {
    /* saveForm already understands `villaNumber` and recombines it with the street itself -
       see AccountKycController.applyVilla. We post the key; the recombining stays theirs. */
    this.accountValues.villaNumber = event.target.value;
  }

  /**
   * MODON's conditional-visibility rule, applied. A field is shown unless it names a controlling
   * field whose current value is (or, when negated, is not) one of the listed values.
   */
  isVisible(f, target) {
    if (!f || !f.visibleWhenField) {
      return true;
    }
    const current = this.asText(this.storedValue(target, f.visibleWhenField)).trim();
    const wanted = (f.visibleWhenValues || []).map((v) => String(v).trim());
    const matches = wanted.some((v) => v.toLowerCase() === current.toLowerCase());
    return f.visibleWhenNegate === true ? !matches : matches;
  }

  /**
   * MODON's dependent-picklist rule, applied. Where a field's options are controlled by another,
   * only the set for the controlling field's CURRENT value is offered - otherwise a rep can pick
   * a combination the record will not accept.
   */
  optionsFor(f, target) {
    const sets = f.dependentOptions;
    if (!sets || !sets.length || !f.optionsControlledBy) {
      return f.options || [];
    }
    const current = this.asText(this.storedValue(target, f.optionsControlledBy)).trim();
    for (const set of sets) {
      if (String(set.controllingValue || "").trim().toLowerCase() === current.toLowerCase()) {
        return set.options || [];
      }
    }
    /* no set for this controlling value: offer nothing rather than everything */
    return [];
  }

  toField(f, target) {
    const type = (f.type || "STRING").toUpperCase();
    const stored = this.storedValue(target, f.apiName);
    const isCheckbox = type === "BOOLEAN";
    return {
      key: `${target}.${f.apiName}`,
      apiName: f.apiName,
      label: f.label,
      target: target,
      required: f.required === true,
      /* SC-UI-006: MODON's own flag, shown as one character rather than a sentence per field. */
      marker: f.required === true ? "*" : "",
      readOnly: f.readOnly === true,
      options: this.optionsFor(f, target),
      /* SC-UI-005: what the record holds now. A checkbox needs a boolean, everything else a
         string; null/undefined becomes "" so a genuinely empty field still renders empty. */
      value: isCheckbox ? false : this.asText(stored),
      checked: isCheckbox ? stored === true || stored === "true" : false,
      isPicklist: type === "PICKLIST" || (f.options && f.options.length > 0),
      controls: !!f.optionsControlledBy,
      isDate: type === "DATE",
      isCheckbox: isCheckbox,
      isTextarea: type === "TEXTAREA",
      isText:
        TEXT_TYPES.indexOf(type) >= 0 && type !== "TEXTAREA" && !(f.options && f.options.length)
    };
  }

  /**
   * SC-UI-005, second half. A native <select> ignores a `value` binding applied before its
   * <option> children exist, so the picklists rendered empty even though the value was there -
   * text inputs were fine. Applying it after render is the smallest fix that works for both.
   *
   * Setting a DOM property does not re-render, so this cannot loop. The user's own edit always
   * wins: handleValue writes the edit into `loaded` too, so what is re-applied here is whatever
   * is currently correct.
   */
  renderedCallback() {
    /* 2.13 - focus to Regenerate when the question opens, back to the control when it closes */
    if (this.focusNext) {
      const next = this.focusNext;
      this.focusNext = null;
      const el =
        next === "confirm"
          ? this.template.querySelector(".kycc__confirm .kycc__btn[data-yes]")
          : this.template.querySelector(".kycc__btn[data-generate]");
      if (el) {
        el.focus();
      }
    }
    if (!this.formOpen) {
      return;
    }
    const controls = this.template.querySelectorAll("select[data-api], input[data-api], textarea[data-api]");
    controls.forEach((el) => {
      const target = el.dataset.target;
      const apiName = el.dataset.api;
      const stored = this.storedValue(target, apiName);
      if (el.type === "checkbox") {
        el.checked = stored === true || stored === "true";
        return;
      }
      const wanted = this.asText(stored);
      if (el.value !== wanted) {
        el.value = wanted;
      }
    });
  }

  /** The stored value for one field, from whichever object owns it. */
  storedValue(target, apiName) {
    const bucket = target === "contact" ? this.loadedContact : this.loadedAccount;
    return bucket ? bucket[apiName] : undefined;
  }

  /**
   * A date arrives as an ISO string and an <input type="date"> wants exactly yyyy-mm-dd, so a
   * datetime is trimmed at the T. Everything else is rendered as-is.
   */
  asText(v) {
    if (v === null || v === undefined) {
      return "";
    }
    const s = String(v);
    return /^\d{4}-\d{2}-\d{2}T/.test(s) ? s.slice(0, 10) : s;
  }

  handleValue(event) {
    const target = event.target.dataset.target;
    const api = event.target.dataset.api;
    const value =
      event.target.type === "checkbox" ? event.target.checked : event.target.value;
    /* the edit buffer - this, and only this, is what gets posted */
    const bucket = target === "contact" ? this.contactValues : this.accountValues;
    bucket[api] = value;
    /* keep the displayed value in step so a re-render does not discard the typing */
    const loaded = target === "contact" ? this.loadedContact : this.loadedAccount;
    loaded[api] = value;
    /* a changed value can hide a field or narrow another's options - recompute both */
    if (this.rawSections && this.rawSections.length) {
      this.sections = this.buildSections(this.rawSections);
    }
  }

  handleSave() {
    this.busy = true;
    this.problem = null;
    this.notice = null;
    saveCaptureForm({
      opportunityId: this._opportunityId,
      accountValuesJson: JSON.stringify(this.accountValues),
      contactValuesJson: JSON.stringify(this.contactValues)
    })
      .then(() => {
        this.notice = this.labels.KYCC_SAVED;
        this.formOpen = false;
        /* the Option B verdict may have moved - re-ask, never assume (2.3: outcome first) */
        return this.load().then(() => this.dispatchEvent(new CustomEvent("changed")));
      })
      .catch((e) => {
        this.problem = reduceError(e);
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /* ── generation ──────────────────────────────────────────────────────────── */

  handleGenerate() {
    /* 2.10 - one attempt at a time, decided here and now. generateDisabled only reaches the button
       on the next render, so a double click could otherwise start two Nintex renders. */
    if (this.busy || this.generating) {
      return;
    }
    /* 2.13 - a form exists: ask first; Regenerate in the question runs it */
    if (this.isRegenerate) {
      this.problem = null;
      this.notice = null;
      this.confirming = true;
      this.focusNext = "confirm";
      return;
    }
    this.runGenerate();
  }

  /** 2.13 - Regenerate, in the question. */
  handleRegenerateYes() {
    if (this.busy || this.generating) {
      return;
    }
    this.confirming = false;
    this.focusNext = "generate";
    this.runGenerate();
  }

  /** 2.13 - Cancel, or Escape: the question closes and focus returns to the control. */
  handleRegenerateNo() {
    this.confirming = false;
    this.focusNext = "generate";
  }

  handleConfirmKey(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      event.stopPropagation();
      this.handleRegenerateNo();
    }
  }

  /** The request itself (2.13: moved out of handleGenerate so the question can run it). */
  runGenerate() {
    if (this.busy || this.generating) {
      return;
    }
    this.busy = true;
    this.generating = true;
    this.problem = null;
    /* 2.4 - say what is happening; Nintex takes a while */
    this.notice = this.labels.KYCC_GENERATING_NOTE;
    const call = this.isParty
      ? requestPartyKycFormGeneration({
          opportunityId: this._opportunityId,
          accountId: this._partyAccountId
        })
      : requestKycFormGeneration({ opportunityId: this._opportunityId });
    call
      .then((message) => {
        this.notice = message || this.labels.KYCC_REQUESTED;
        /* 2.3 - the verdict is re-read only after the outcome has settled */
        return this.load().then(() => this.dispatchEvent(new CustomEvent("changed")));
      })
      .catch((e) => {
        this.notice = null;
        this.problem = reduceError(e);
      })
      .finally(() => {
        this.busy = false;
        this.generating = false;
      });
  }

  /** Re-reads state, then the parent re-runs the eligibility verdict (2.3: in that order). */
  handleRefresh() {
    this.confirming = false;
    /* 2.14 - clear the last action's line */
    this.notice = null;
    this.problem = null;
    this.busy = true;
    this.load()
      .then(() => this.dispatchEvent(new CustomEvent("changed")))
      .finally(() => {
        this.busy = false;
      });
  }

  get formToggleLabel() {
    return this.formOpen ? this.labels.KYCC_CLOSE : this.labels.KYCC_UPDATE;
  }
}