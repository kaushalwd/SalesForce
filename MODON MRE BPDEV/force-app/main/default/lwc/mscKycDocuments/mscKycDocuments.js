/**
 * mscKycDocuments - the required-documents checklist, with upload.
 *
 * Version  Author      Date         Detail
 * 1.6      Aurelix Dev 30 Sep 2026  "View" is "Download" and downloads in place: the file servlet cannot preview on the
 *                                   site (UI-27). needed-for picks the sentence under the list, or none (UI-28, R2-18).
 * 1.5      Aurelix Dev 29 Sep 2026  Files lock on the signed form, not the generated one: once the "KYC Form -
 *                                   Signed" row holds a file, or KYC is Active (AurelixKycDocumentService 1.5).
 *                                   Lock code FORM_SIGNED replaces FORM_GENERATED.
 * 1.4      Aurelix Dev 29 Sep 2026  Upload on a row holding the rep's own file (`replaceable`) asks "Replace the
 *                                   current file?" first, then goes through AurelixKycDocumentService.replaceFile.
 *                                   A locked row that holds a file shows no Upload; one line says why.
 * 1.3      Aurelix Dev 28 Sep 2026  Upload state is per row. One shared `busy` flag drove every row, so
 *                                   choosing a file on one row turned EVERY Upload button into a disabled
 *                                   "Uploading..." (found in testing, 28 Sep). The flag is now `uploading`,
 *                                   a map keyed by the Documents__c row Id: only the row being posted reads
 *                                   "Uploading..." and is disabled, the others keep "Upload" and stay
 *                                   usable, and a finished upload clears only its own row. Two more guards
 *                                   so rows cannot tread on each other: a re-read that comes back after a
 *                                   newer one is dropped (it would un-tick a row that just landed), and an
 *                                   upload's error belongs to its row, so another row's success no longer
 *                                   wipes it; it goes when that row is tried again or succeeds. The row
 *                                   now stays "Uploading..." until the re-read has landed, so it does not
 *                                   flash back to "Upload" before its tick appears. Look unchanged.
 * 1.2      Aurelix Dev 24 Sep 2026  Says out loud whether it is actually listing anything. c/mscKycGate
 *                                   tells c/mscKycCapture to stand its own "Files to upload:" list down
 *                                   while this checklist is on screen, but "on screen" was read from the
 *                                   gate's own showDocuments, which is true whenever this component is
 *                                   MOUNTED - including when it draws nothing but the short blocked line
 *                                   (an unavailable checklist DTO), or a header with no rows under it. The
 *                                   missing file names then appeared in neither place and the rep was told
 *                                   nothing about what to collect (found 24 Sep). Every settle of load()
 *                                   now raises `liststate` carrying listed, computed from the same two
 *                                   things the template branches on - `show`, and a row inside `groups` -
 *                                   so the flag can never disagree with what is drawn. This still gates
 *                                   nothing; it only reports what it put on the screen.
 * 1.1      Aurelix Dev 18 Sep 2026  Seen in the browser: lightning-file-upload's drop zone
 *                                   ("Upload Files / Or drop files") outweighed every row and
 *                                   squeezed the names. Upload is now a ghost button over a hidden
 *                                   file input; the file goes through
 *                                   AurelixKycDocumentService.uploadFile (base64, 4 MB ceiling,
 *                                   KYC rows only), the route the console's proof capture uses.
 * 1.0      Aurelix Dev 18 Sep 2026  MSC-175 (B5). One grey list per subject - the buyer, a joint
 *                                   owner, or for a company its signatory and the company itself -
 *                                   showing exactly the Documents__c rows the booking gate and
 *                                   Option 2 test, by exact name. A muted tick means the row has a
 *                                   FILE (the same without-sharing presence test the gate makes,
 *                                   so the tick can never disagree with the verdict); a hollow
 *                                   circle means it does not. Upload lands the file on that row
 *                                   (lightning-file-upload with record-id = the row), MODON's
 *                                   ContentDocumentLink trigger marks it Uploaded, and the list
 *                                   re-reads the server. View opens the newest file. No Remove.
 *
 * ROWS COME FROM MODON. AurelixKycDocumentService.getChecklist ensures the placeholders first,
 * through the same MODON code the internal app's "Generate Documents" action runs, so a
 * console-created customer has rows to upload onto before this list is drawn.
 *
 * THIS LIST GATES NOTHING. It reports; the server decides. After every change it raises
 * `changed` so the host re-reads the KYC verdict.
 */
import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { formatDate, reduceError } from "c/modonSalesFormat";
import getChecklist from "@salesforce/apex/AurelixKycDocumentService.getChecklist";
import uploadFile from "@salesforce/apex/AurelixKycDocumentService.uploadFile";
import replaceFile from "@salesforce/apex/AurelixKycDocumentService.replaceFile";
import getSitePathPrefix from "@salesforce/apex/SalesConsoleController.getSitePathPrefix";

const SIGNED = "KYC Form - Signed";
/* the server's ceiling, checked here first so a large scan is refused before it is read */
const MAX_BYTES = 4 * 1024 * 1024;
const ACCEPT = ".pdf,.png,.jpg,.jpeg";
/* 1.4 - this component's own wording, kept out of c/mscLabels */
const TEXT = {
  REPLACE_ASK: "Replace the current file?",
  REPLACE_YES: "Replace",
  LOCKED: {
    /* 1.5 - FORM_SIGNED replaces FORM_GENERATED */
    FORM_SIGNED: "Files locked: signed KYC form on file.",
    KYC_ACTIVE: "Files locked: KYC complete.",
    MANUAL_APPROVED: "Files locked: manual KYC approved."
  }
};

export default class MscKycDocuments extends LightningElement {
  labels = LABELS;

  /** Read-only rendering: no Upload controls (the manual-KYC panel's view). */
  @api readOnly = false;
  /** Compact: no title row (inside a party card on Verification). */
  @api compact = false;
  /**
   * 1.6 - what the files are needed for, said under the list only where it is true: "payment"
   * (the buyer, while the booking gate is on) or "adding" (a person in the Add Joint Owner drawer,
   * whom MODON's joint owner check refuses without them). Anything else: no sentence.
   */
  @api neededFor = "";

  _opportunityId;
  _partyAccountId;
  dto;
  /* 1.3 - a list that could not load; cleared by the next good load */
  listProblem;
  /* 1.3 - the last upload error and the row it belongs to: { id, text } */
  uploadError = null;
  /* 1.3 - Documents__c Id -> true while that row's file is being posted. Replaced, never mutated,
     so every change re-renders. */
  uploading = {};
  /* 1.3 - only the newest load() may write the list */
  loadSeq = 0;
  sitePrefix = "";
  /* 1.4 - the row whose "Replace the current file?" is open (a Documents__c Id), one at a time */
  confirmFor = null;
  /* 1.4 - rows whose next chosen file replaces rather than adds; set by Replace, spent by the pick */
  replaceArmed = {};
  /* 1.4 - where focus goes after the next render: "confirm" or "upload:<documentId>" */
  focusNext = null;

  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(value) {
    this._opportunityId = value;
    this.load();
  }

  /** A joint owner's Account; null means the buyer. */
  @api
  get partyAccountId() {
    return this._partyAccountId;
  }
  set partyAccountId(value) {
    this._partyAccountId = value;
    this.load();
  }

  /** Public so the host can re-read after its own actions (a closed modal, a refresh). */
  @api
  refresh() {
    this.load();
  }

  connectedCallback() {
    getSitePathPrefix()
      .then((p) => {
        this.sitePrefix = p || "";
      })
      .catch(() => {
        this.sitePrefix = "";
      });
  }

  load() {
    const seq = ++this.loadSeq;
    if (!this._opportunityId) {
      this.dto = undefined;
      this.report();
      return Promise.resolve();
    }
    /* 1.3 - returned so an upload can hold its row until the re-read lands */
    return getChecklist({
      opportunityId: this._opportunityId,
      partyAccountId: this._partyAccountId || null
    })
      .then((result) => {
        if (seq !== this.loadSeq) {
          return;
        }
        this.dto = result;
        this.listProblem = null;
      })
      .catch((e) => {
        if (seq !== this.loadSeq) {
          return;
        }
        /* a list that could not load is absent, never a banner; the server still gates */
        this.dto = undefined;
        this.listProblem = reduceError(e);
      })
      /* 1.2 - the host is told either way, and only once the answer is real */
      .finally(() => {
        if (seq === this.loadSeq) {
          this.report();
        }
      });
  }

  /** 1.3 - the one line under the list: an upload's own error first, else why the list failed. */
  get problem() {
    return (this.uploadError && this.uploadError.text) || this.listProblem || null;
  }

  /**
   * 1.2 - what is ACTUALLY on the screen. Read from the two things the template itself branches on:
   * the section (`show`) and a row inside `groups`. A blocked line is not a list, and neither is a
   * heading with a counter and nothing under it.
   */
  get listsNames() {
    return this.show && this.groups.some((g) => g.rows.length > 0);
  }

  /**
   * 1.2 - tell the host what was drawn, so it does not have to guess from whether it mounted us.
   * Raised on every settle of load(), which is the only thing that can change the answer.
   */
  report() {
    this.dispatchEvent(new CustomEvent("liststate", { detail: { listed: this.listsNames } }));
  }

  get show() {
    return !!this.dto && this.dto.available === true;
  }

  get blocked() {
    return this.dto && this.dto.available !== true ? this.dto.blockedReason : null;
  }

  get counter() {
    const d = this.dto;
    return d ? this.fill(this.labels.KYCD_COUNTER, [d.done, d.total]) : "";
  }

  get complete() {
    const d = this.dto;
    return !!d && d.total > 0 && d.done >= d.total;
  }

  get rootClass() {
    return `kycd${this.compact ? " kycd--compact" : ""}${this.complete ? " kycd--done" : ""}`;
  }

  /** Every group with its rows dressed for the template. */
  get groups() {
    const d = this.dto;
    if (!d) {
      return [];
    }
    const many = d.groups.length > 1;
    return d.groups.map((g) => ({
      key: g.key,
      /* "Signatory · Khalid Rahman · Resident"; only when there is more than one subject */
      heading: many ? this.headingFor(g) : null,
      rows: g.rows.map((r, i) => this.rowFor(r, i, g))
    }));
  }

  headingFor(g) {
    const role = this.roleLabel(g.role);
    const parts = [role, g.subjectName];
    if (!g.isCompany && g.residency) {
      parts.push(g.residency);
    }
    return parts.filter(Boolean).join(" · ");
  }

  roleLabel(role) {
    const map = {
      Buyer: this.labels.KYCD_ROLE_BUYER,
      "Joint owner": this.labels.KYCD_ROLE_OWNER,
      Signatory: this.labels.KYCD_ROLE_SIGNATORY,
      Company: this.labels.KYCD_ROLE_COMPANY
    };
    return map[role] || role;
  }

  rowFor(r, i, g) {
    const has = r.hasFile === true;
    const busy = !!r.documentId && this.uploading[r.documentId] === true;
    let fact;
    if (has) {
      fact = r.uploadedOn
        ? this.fill(this.labels.KYCD_UPLOADED, [formatDate(r.uploadedOn)])
        : this.labels.KYCD_UPLOADED_NODATE;
    } else if (r.name === SIGNED) {
      fact = this.labels.KYCD_FROM_SIGNING;
    } else if (!r.canUpload) {
      fact = this.labels.KYCD_NO_ROW;
    } else {
      fact = this.labels.KYCD_MISSING;
    }
    return {
      key: `${g.key}-${i}`,
      name: r.alternative ? `${this.labels.KYCD_OR} ${r.name}` : r.name,
      alternative: r.alternative === true,
      hasFile: has,
      markClass: has ? "kycd__mark kycd__mark--ok" : "kycd__mark",
      rowClass: r.alternative ? "kycd__row kycd__row--alt" : "kycd__row",
      fact: fact,
      factClass: has ? "kycd__fact kycd__fact--ok" : "kycd__fact",
      documentId: r.documentId,
      canUpload: !this.readOnly && r.canUpload === true,
      /* 1.4 - Upload replaces the rep's own file here, after asking */
      replaceable: !this.readOnly && r.canUpload === true && r.replaceable === true,
      /* a data-* attribute drops a false boolean, so the button carries a word */
      replaceAttr: !this.readOnly && r.canUpload === true && r.replaceable === true ? "true" : "false",
      confirming:
        !this.readOnly && r.canUpload === true && r.replaceable === true && !busy &&
        !!r.documentId && this.confirmFor === r.documentId,
      /* 1.3 - this row's own state, not the list's */
      uploading: busy,
      uploadLabel: busy ? this.labels.KYCD_UPLOADING : this.labels.KYCD_UPLOAD,
      viewUrl: r.fileId ? `${this.sitePrefix}/sfc/servlet.shepherd/document/download/${r.fileId}` : null
    };
  }

  get note() {
    const d = this.dto;
    if (!d || this.readOnly) {
      return null;
    }
    if (this.complete) {
      return this.labels.KYCD_ALL_PRESENT;
    }
    /* 1.6 - UI-28, R2-18 */
    if (this.neededFor === "payment") {
      return this.fill(this.labels.KYCD_NEEDED_BEFORE_PAYMENT, [d.total]);
    }
    if (this.neededFor === "adding") {
      return this.fill(this.labels.KYCD_NEEDED_BEFORE_ADDING, [d.total]);
    }
    return null;
  }

  get accept() {
    return ACCEPT;
  }

  get text() {
    return TEXT;
  }

  /** 1.4 - one quiet line when the files are locked and a row is actually held by it. */
  get lockNote() {
    const d = this.dto;
    if (!d || this.readOnly || !d.lockCode) {
      return null;
    }
    const held = (d.groups || []).some((g) => (g.rows || []).some((r) => r.locked === true));
    return held ? TEXT.LOCKED[d.lockCode] || d.lockReason || null : null;
  }

  /** 1.4 - focus to Replace when the question opens, back to Upload when it closes. */
  renderedCallback() {
    const next = this.focusNext;
    if (!next) {
      return;
    }
    this.focusNext = null;
    let el = null;
    if (next === "confirm") {
      el = this.template.querySelector(".kycd__confirm .kycd__btn[data-yes]");
    } else if (next.startsWith("upload:")) {
      const id = next.slice(7);
      el = this.template.querySelector(`.kycd__btn[data-upload][data-document="${id}"]`);
    }
    if (el) {
      el.focus();
    }
  }

  /**
   * The ghost button opens the hidden input for its row. 1.4: on a row holding the rep's own file it
   * asks first; the picker opens from Replace.
   */
  handleUploadClick(event) {
    const { key, document: documentId, replace } = event.currentTarget.dataset;
    if (documentId) {
      this.disarm(documentId);
    }
    if (replace === "true" && documentId) {
      this.confirmFor = documentId;
      this.focusNext = "confirm";
      return;
    }
    this.openPicker(key);
  }

  /** 1.4 - Replace: the next file chosen on this row replaces the rep's earlier one. */
  handleReplaceYes(event) {
    const { key, document: documentId } = event.currentTarget.dataset;
    this.confirmFor = null;
    if (!documentId) {
      return;
    }
    this.replaceArmed = { ...this.replaceArmed, [documentId]: true };
    /* still inside the click, so the browser lets the picker open */
    this.openPicker(key);
  }

  /** 1.4 - Cancel, or Escape: close the question and hand focus back to Upload. */
  handleReplaceNo(event) {
    const documentId = event.currentTarget.dataset.document;
    this.confirmFor = null;
    if (documentId) {
      this.focusNext = `upload:${documentId}`;
    }
  }

  handleConfirmKey(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      event.stopPropagation();
      this.handleReplaceNo(event);
    }
  }

  openPicker(key) {
    const input = this.template.querySelector(`input[type="file"][data-key="${key}"]`);
    if (input) {
      input.value = "";
      input.click();
    }
  }

  /** 1.4 - forget a Replace that was never followed by a file (the picker was closed). */
  disarm(documentId) {
    if (this.replaceArmed[documentId]) {
      const next = { ...this.replaceArmed };
      delete next[documentId];
      this.replaceArmed = next;
    }
  }

  /** Read the chosen file, post it onto the row, then re-read so tick, date and verdict move. */
  handleFileChosen(event) {
    const input = event.target;
    const documentId = input.dataset.document;
    const file = input.files && input.files[0];
    if (!file || !documentId || this.uploading[documentId] === true) {
      return;
    }
    /* 1.4 - Replace armed this pick; spend it now either way */
    const replace = this.replaceArmed[documentId] === true;
    this.disarm(documentId);
    /* 1.3 - a fresh try on this row retires this row's old error, never another row's */
    this.clearUploadError(documentId);
    if (file.size > MAX_BYTES) {
      this.uploadError = { id: documentId, text: this.labels.KYCD_TOO_LARGE };
      return;
    }
    this.setUploading(documentId, true);
    const reader = new FileReader();
    reader.onerror = () => {
      this.setUploading(documentId, false);
      this.uploadError = { id: documentId, text: this.labels.KYCD_READ_FAILED };
    };
    reader.onload = () => {
      const base64 = String(reader.result || "").split(",")[1] || "";
      const post = replace ? replaceFile : uploadFile;
      post({ documentId, base64Data: base64, fileName: file.name })
        .then(() => {
          this.clearUploadError(documentId);
          return this.load();
        })
        .catch((e) => {
          this.uploadError = { id: documentId, text: reduceError(e) };
        })
        .finally(() => {
          this.setUploading(documentId, false);
          this.dispatchEvent(new CustomEvent("changed"));
        });
    };
    reader.readAsDataURL(file);
  }

  /** 1.3 - mark or clear ONE row; a new map each time so the template re-renders. */
  setUploading(documentId, on) {
    const next = { ...this.uploading };
    if (on) {
      next[documentId] = true;
    } else {
      delete next[documentId];
    }
    this.uploading = next;
  }

  /** 1.3 - drop the upload error only if it belongs to this row. */
  clearUploadError(documentId) {
    if (this.uploadError && this.uploadError.id === documentId) {
      this.uploadError = null;
    }
  }

  fill(template, values) {
    return values.reduce((text, value, i) => text.replace(`{${i}}`, value === undefined ? "" : value), template);
  }
}