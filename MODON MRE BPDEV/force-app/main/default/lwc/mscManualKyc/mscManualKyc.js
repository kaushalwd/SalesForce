/**
 * mscManualKyc - the manual KYC route, inside the booking journey.
 *
 * Version  Author      Date         Detail
 * 2.3      Aurelix Dev 30 Sep 2026  UI-04: the file control's own "Upload" label is hidden (the field label above
 *                                   names it) and the control takes the form's 11 px type. Template and CSS only.
 * 2.2      Aurelix Dev 28 Sep 2026  party-account-id: the same form for one joint owner, from the Add Joint
 *                                   Owner drawer (c/mscPartyKyc). With it set, the state, the file list and
 *                                   the submission are the party's (AurelixManualKycService evaluateParty,
 *                                   getPartyManualKycFiles, submitPartyManualKyc); the upload lands on their
 *                                   Account. A load waits one tick so both ids are in, and only the newest
 *                                   load may write, so the buyer's state can never flash in a party's form.
 * 2.1      Aurelix Dev 27 Sep 2026  A company's manual KYC approval lands on its Power of Attorney Contact,
 *                                   not the company (AurelixManualKycService 4.11). The
 *                                   server now names the POA Contact as the upload target, so the file
 *                                   sits where the request and MODON's "For Approval" renaming happen, and
 *                                   the company line reads "Company · <name>" (mscLabels 1.106).
 * 2.0      Aurelix Dev 18 Sep 2026  MSC-176 / MSC-178 (B6 + B7).
 *                                   B7 - the supporting file is OPTIONAL: Submit needs a reason and
 *                                   a comment; the upload is labelled so and the server mirrors it
 *                                   (AurelixManualKycService.ATTACHMENT_REQUIRED = false).
 *                                   B6 - a company is no longer "not configured". The server names
 *                                   the subject (the authorised POA Contact) and the approval
 *                                   target (the company); this panel prints "POA · <name>" and
 *                                   "Approval on · <company>", lists what compliance would still
 *                                   find missing, and uploads onto the COMPANY Account, which is
 *                                   where the approval and the "For Approval" file sit. A company
 *                                   with no Power of Attorney is told so (blockedReason) instead
 *                                   of being handed a form.
 * 1.1      Aurelix Dev 17 Sep 2026  MSC-173 (B1). Seen in the browser on 17 Sep under an admin
 *                                   and a Sales Management user alike: the upload itself worked,
 *                                   but (1) once the Upload Files dialog closed the dropdown still
 *                                   read "Choose a file" although documentId had been set, so
 *                                   nothing told the rep it had worked and the natural next move
 *                                   was a second upload or the wrong, older file; (2) the open
 *                                   list was unreadable - the OS paints it white and the options
 *                                   inherited the console's light text. Now the uploaded file is
 *                                   the selected option, one status line names it, and the
 *                                   options carry the theme's own colours (the .field__select
 *                                   rule from c/mscStyles, which this form never used). No Apex
 *                                   changed; the server still re-checks all three on submit.
 * 1.0      Aurelix Dev 07 Sep 2026  Phase 3. The escape route when a customer cannot finish the
 *                                   digital Signzy journey: choose a reason, say why, attach the
 *                                   evidence, submit for approval - without leaving the console.
 *
 * ALL THREE ARE MANDATORY. Reason, comment and attachment, exactly as MODON's existing quick
 * action requires them. Revision 1 proposed relaxing the attachment; that was withdrawn, and
 * whether it should ever relax is a business question (Q-G), not a decision for this screen.
 * The button is disabled until all three are present AND the server re-checks all three, because
 * a disabled button is only a hint.
 *
 * THE SUBMISSION IS MODON'S.
 *   AurelixManualKycService.submitManualKyc -> ManualKYCController.submitForApproval
 *                                           -> approval process Submit_for_Manual_KYC
 * Their controller is called, never modified, and is not granted to the community permission
 * set: the wrapper keeps the console's Apex surface to Aurelix classes only.
 *
 * PERSON ONLY, ON PURPOSE. MODON has configured no organisation rows in
 * Account_KYC_Validation__mdt, so there is nothing to validate a company against and no
 * corporate checklist is invented here. The organisation branch says so and stops. That gap is
 * about MANUAL field capture only - a company's DIGITAL KYC runs through its authorised POA and
 * is offered in c/mscKycGate exactly as it is for a person.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { reduceError } from "c/modonSalesFormat";
import evaluateManual from "@salesforce/apex/AurelixManualKycService.evaluate";
import getManualKycFiles from "@salesforce/apex/AurelixManualKycService.getManualKycFiles";
import nameUploadedFile from "@salesforce/apex/AurelixManualKycService.nameUploadedFile";
import submitManualKyc from "@salesforce/apex/AurelixManualKycService.submitManualKyc";
/* 2.2: the joint owner's route */
import evaluateParty from "@salesforce/apex/AurelixManualKycService.evaluateParty";
import getPartyManualKycFiles from "@salesforce/apex/AurelixManualKycService.getPartyManualKycFiles";
import submitPartyManualKyc from "@salesforce/apex/AurelixManualKycService.submitPartyManualKyc";

export default class MscManualKyc extends LightningElement {
  labels = LABELS;

  _opportunityId;

  /**
   * The booking this submission belongs to. Setting it loads the manual-KYC state - which is
   * AurelixManualKycService's answer, NOT the eligibility verdict c/mscKycGate renders. They
   * are different questions ("is this customer verified" versus "what does a manual submission
   * still need"), so they are two DTOs and this component owns the second one.
   */
  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(value) {
    this._opportunityId = value;
    this.scheduleLoad();
  }

  /** 2.2 - a joint owner's Account; null means the buyer. */
  _partyAccountId;
  @api
  get partyAccountId() {
    return this._partyAccountId;
  }
  set partyAccountId(value) {
    this._partyAccountId = value;
    this.scheduleLoad();
  }

  /* 2.2 - both ids are set one after the other; load once, after both */
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

  get isParty() {
    return !!this._partyAccountId;
  }

  /** 2.2 - the ids every call carries: the booking, and the party when there is one. */
  get partyArgs() {
    return { opportunityId: this._opportunityId, accountId: this._partyAccountId };
  }

  state;
  reason;
  comment;
  documentId;
  /** 1.1 - MODON's title for the file the last upload produced; null until there is one. */
  uploadedName;
  files = [];
  busy = false;
  problem;
  done;

  load() {
    const seq = ++this.loadSeq;
    if (!this._opportunityId) {
      this.state = undefined;
      return;
    }
    const call = this.isParty
      ? evaluateParty(this.partyArgs)
      : evaluateManual({ opportunityId: this._opportunityId });
    call
      .then((result) => {
        if (seq !== this.loadSeq) return;
        this.state = result;
        this.loadFiles();
      })
      .catch((e) => {
        if (seq !== this.loadSeq) return;
        this.state = undefined;
        this.problem = reduceError(e);
      });
  }

  /* ── the configured reasons, MODON's own ─────────────────────────────────── */

  get reasonOptions() {
    return (this.state && this.state.reasonOptions) || [];
  }

  get accountId() {
    return (this.state && this.state.accountId) || null;
  }

  /** A route the server cannot offer: unconfigured (no rules at all) or blocked (no POA). */
  get unconfigured() {
    return !!this.state && (this.state.configured === false || !!this.state.blockedReason);
  }

  get unconfiguredReason() {
    const s = this.state;
    if (!s) {
      return null;
    }
    return s.blockedReason || s.notConfiguredReason || null;
  }

  /* ── 2.0 - who this is about ─────────────────────────────────────────────── */

  get isOrganisation() {
    return !!this.state && this.state.customerType === "Organisation";
  }

  /** "POA · Khalid Rahman" for a company; nothing for a person (the gate already names them). */
  get subjectLine() {
    const s = this.state;
    /* 2.2 - a party: the drawer's card already names them */
    if (!s || this.isParty || !this.isOrganisation || !s.subjectName) {
      return null;
    }
    return `${this.labels.MKYC_SUBJ_POA} · ${s.subjectName}`;
  }

  get companyLine() {
    const s = this.state;
    if (!s || !this.isOrganisation || !s.companyName) {
      return null;
    }
    return `${this.labels.MKYC_SUBJ_COMPANY} · ${s.companyName}`;
  }

  /** What compliance would still find missing. Informative: it does not stop the submission. */
  get missing() {
    const s = this.state;
    return s && s.missingFields ? s.missingFields : [];
  }

  get hasMissing() {
    return this.missing.length > 0;
  }

  /* ── files ───────────────────────────────────────────────────────────────── */

  loadFiles() {
    if (!this._opportunityId) {
      return;
    }
    const call = this.isParty
      ? getPartyManualKycFiles(this.partyArgs)
      : getManualKycFiles({ opportunityId: this._opportunityId });
    call
      .then((rows) => {
        this.files = rows || [];
      })
      .catch(() => {
        /* an empty list is honest: the rep can still upload */
        this.files = [];
      });
  }

  get hasFiles() {
    return this.files.length > 0;
  }

  /**
   * 1.1 - the list with the chosen file marked. A native <select> shows whatever the browser
   * last showed, and a `value` set on the select before its options exist is ignored (the trap
   * c/mscKycCapture documents), so each option carries `selected` itself.
   */
  get fileOptions() {
    const chosen = this.documentId;
    return this.files.map((f) => ({
      value: f.value,
      label: f.label,
      selected: !!chosen && f.value === chosen
    }));
  }

  /** 1.1 - one quiet line naming the file the upload produced; null until there is one. */
  get uploadedLine() {
    if (!this.uploadedName) {
      return null;
    }
    return this.labels.MKYC_UPLOADED.replace("{0}", this.uploadedName);
  }

  get uploadFormats() {
    return [".pdf", ".png", ".jpg", ".jpeg"];
  }

  /**
   * A freshly uploaded file carries the customer's own filename, which is not the convention the
   * approver looks for - MODON's renameUploadedFile applies it, so the upload is only finished
   * once that has run.
   */
  handleUploadFinished(event) {
    const files = (event.detail && event.detail.files) || [];
    if (!files.length) {
      return;
    }
    const uploaded = files[0].documentId;
    this.busy = true;
    this.problem = null;
    nameUploadedFile({ documentId: uploaded })
      .then((renamed) => {
        this.documentId = uploaded;
        /* 1.1 - MODON's title, so the status line and the list agree to the second */
        this.uploadedName = renamed && renamed.label ? renamed.label : null;
        this.loadFiles();
      })
      .catch((e) => {
        this.problem = reduceError(e);
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /* ── the three mandatory answers ─────────────────────────────────────────── */

  handleReason(event) {
    this.reason = event.detail ? event.detail.value : event.target.value;
  }

  handleComment(event) {
    this.comment = event.target.value;
  }

  handleFile(event) {
    this.documentId = event.detail ? event.detail.value : event.target.value;
  }

  /** 2.0 - the file is optional unless the server says otherwise. */
  get fileRequired() {
    return !!this.state && this.state.attachmentRequired === true;
  }

  get canSubmit() {
    return (
      !this.busy &&
      !!this.reason &&
      !!this.comment &&
      (!this.fileRequired || !!this.documentId) &&
      !!this._opportunityId
    );
  }

  get submitDisabled() {
    return !this.canSubmit;
  }

  get submitLabel() {
    return this.busy ? this.labels.MKYC_WORKING : this.labels.MKYC_SUBMIT;
  }

  handleSubmit() {
    if (!this.canSubmit) {
      return;
    }
    this.busy = true;
    this.problem = null;
    const answers = {
      reason: this.reason,
      comment: this.comment,
      documentId: this.documentId || null
    };
    const call = this.isParty
      ? submitPartyManualKyc({ ...this.partyArgs, ...answers })
      : submitManualKyc({ opportunityId: this._opportunityId, ...answers });
    call
      .then((message) => {
        this.done = message || this.labels.MKYC_DONE;
        /* the parent owns the verdict; tell it to re-ask rather than deciding here */
        this.dispatchEvent(new CustomEvent("submitted"));
      })
      .catch((e) => {
        this.problem = reduceError(e);
      })
      .finally(() => {
        this.busy = false;
      });
  }
}