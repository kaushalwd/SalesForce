/**
 * One payment bucket - required, paid, proof upload.
 *
 * Version  Author      Date         Detail
 * 1.24     Aurelix Dev 22 Sep 2026  The rep can correct a cheque's amount while automatic reading is on.
 *                                   A typed amount is kept when a read disagrees, as before.
 * 1.23     Aurelix Dev 21 Sep 2026  Native date input again (21 Sep). Withdrawn: the same day's
 *                                   c/mscDatePicker for the paid date, which avoided a grey calendar
 *                                   pop-up that only a Linux desktop shows (SCW-137).
 * 1.22     Aurelix Dev 01 Sep 2026  MSC-205. Four quiet flags on the read - stale date / typo
 *                                   year (red: the server now refuses both), words-vs-figures,
 *                                   payee and bank (amber: look once). Computed live, so picking
 *                                   the right bank clears its flag.
 * 1.21     Aurelix Dev 01 Sep 2026  MSC-204. A programmatic form reset moves the two selects
 *                                   too. Options carry `selected` only at render, so after a
 *                                   recorded payment the state said "" while the control still
 *                                   displayed Cheque - generic fields under a Cheque mode.
 * 1.20     Aurelix Dev 01 Sep 2026  MSC-203. A newly attached proof clears "attach the proof
 *                                   first" - the note asked for exactly this.
 * 1.19     Aurelix Dev 01 Sep 2026  MSC-202. A payment only ever uses the file attached for THIS
 *                                   attempt: slots already sitting on the row when the modal
 *                                   opens are neither shown, nor read, nor bundled into submit.
 * 1.18     Aurelix Dev 01 Sep 2026  MSC-201. reset(): the form, the read and the notices go back
 *                                   to how they open. The modal calls it whenever it shows a
 *                                   payment, so nothing from the last one can survive.
 * 1.17     Aurelix Dev 01 Sep 2026  MSC-200c. Both standing sentences under the form are gone:
 *                                   "Also on the image" and "Attach the cheque image ...". 
 * 1.16     Aurelix Dev 01 Sep 2026  MSC-200. For a cheque the image is the only source: the
 *                                   number, date and amount clear, lock and are filled by the
 *                                   read alone. Every other method is untouched, and with
 *                                   automatic reading switched off a cheque still types.
 * 1.15     Aurelix Dev 01 Sep 2026  MSC-197. A cheque proof is read while the rep is still on the
 *                                   form: number, date and amount are proposed into boxes the rep
 *                                   has not made their own, the read says so when it fails, and
 *                                   the read travels with Create Payment so the same image is not
 *                                   sent to the model again after the save.
 * 1.14     Aurelix Dev 01 Sep 2026  MSC-194. No file attach on a coarse pointer; the camera is the way in.
 * 1.13     Aurelix Dev 21 Aug 2026  MSC-106. Use camera only on a coarse pointer.
 * 1.12     Aurelix Dev 21 Aug 2026  MSC-105. Use camera opens a camera (autostart).
 * 1.11     Aurelix Dev 21 Aug 2026  The amount hint is gone.
 * 1.10     Aurelix Dev 21 Aug 2026  MSC-098. `flat` inside the ledger's opened-row panel.
 * 1.9      Aurelix Dev 20 Aug 2026  MSC-096a. The recorded-payment pill is gone; failures still show.
 * 1.8      Aurelix Dev 19 Aug 2026  The form records a Payment (`recordsPayment`); the console's own attach control.
 * 1.7      Aurelix Dev 18 Aug 2026  Compact, like the cheque table.
 * 1.6      Aurelix Dev 18 Aug 2026  Per-row Set up Direct Debit gone.
 * 1.5      Aurelix Dev 17 Aug 2026  The ADM + Dari charge row takes the ADM caption.
 * 1.4      Aurelix Dev 17 Aug 2026  Empty proof slots are not files (ContentDocumentId).
 * 1.3      Aurelix Dev 17 Aug 2026  The capture form, de-nested.
 * 1.2      Aurelix Dev 16 Aug 2026  Embedded mode; Amount defaults to the remaining balance.
 * 1.1      Aurelix IT  13 Aug 2026  Photograph the proof.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api, track, wire } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import getReceiptBankOptions from "@salesforce/apex/SalesConsoleController.getReceiptBankOptions";
import readChequeImage from "@salesforce/apex/SalesConsoleController.readChequeImage";
import isChequeReadOn from "@salesforce/apex/SalesConsoleController.isChequeReadOn";

const MOP_CHEQUE = "Cheque";
/* MSC-205: words that say nothing about WHICH bank it is */
const BANK_NOISE = new Set(["bank", "the", "of", "uae", "llc", "pjsc", "psc", "co", "company", "al"]);
function bankTokens(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/[^a-z ]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !BANK_NOISE.has(t));
}
/** True when the two names share one meaningful word - or when either is too bare to judge. */
function banksAlike(a, b) {
  const ta = bankTokens(a);
  const tb = bankTokens(b);
  if (!ta.length || !tb.length) return true;
  return ta.some((t) => tb.indexOf(t) >= 0);
}
const ACCEPT = [".pdf", ".png", ".jpg", ".jpeg"];
const MAX_BYTES = 4 * 1024 * 1024;
/* images above this are resampled before upload */
const RESAMPLE_ABOVE = 1024 * 1024;
const MAX_EDGE = 1600;
const JPEG_QUALITY = 0.85;

/* Receipt__c.Bank__c, fetched once per page */
let bankOptionsPromise = null;

function readAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("read"));
    reader.readAsDataURL(file);
  });
}

function downscale(dataUrl) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, MAX_EDGE / Math.max(img.width || 1, img.height || 1));
      if (scale >= 1) {
        resolve({ dataUrl, changed: false });
        return;
      }
      try {
        const canvas = document.createElement("canvas");
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);
        canvas.getContext("2d").drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve({ dataUrl: canvas.toDataURL("image/jpeg", JPEG_QUALITY), changed: true });
      } catch (e) {
        resolve({ dataUrl, changed: false });
      }
    };
    img.onerror = () => resolve({ dataUrl, changed: false });
    img.src = dataUrl;
  });
}

function todayIso() {
  const d = new Date();
  const mm = `${d.getMonth() + 1}`.padStart(2, "0");
  const dd = `${d.getDate()}`.padStart(2, "0");
  return `${d.getFullYear()}-${mm}-${dd}`;
}

/**
 * One payment obligation with its own proof upload: one instance per obligation, so proofs
 * are never combined. The parent owns every Apex call (`captureproof`, `submitproof`).
 */
/** The same query c/mscCapture reads for isLikelyMobile; the two must stay identical. */
const COARSE_POINTER = "(pointer: coarse)";

export default class MscPaymentBlock extends LightningElement {
  /** 'DOWN_PAYMENT' | 'ADM_REGISTRATION_FEE' | 'MILESTONE' | 'ADM_DARI_CHARGE' */
  @api paymentType;
  @api label;
  @api requiredAmount;
  @api paidAmount = 0;
  @api dueDate;
  @api status;
  /* what is left to collect */
  @api remainingAmount;
  /* what is still open to a new payment (PaymentBucketDTO.openAmount); seeds and caps the amount */
  @api openAmount;
  @api withFinanceAmount;
  /* this row's Submit records a Payment */
  @api recordsPayment = false;
  /* rendered inside a ledger row */
  @api embedded = false;
  /* MSC-098: rendered inside the opened row's panel; flat sheds the box */
  @api flat = false;
  @api relatedRecordId;
  /** Documents__c id created by the parent. */
  @api proofSlotId;
  @api salesOrderId;
  @api hasSlot = false;
  @api methodOptions = [];
  @api allowDirectDebit = false;
  @api position;
  @api total;
  @api busy = false;
  /* MSC-197: a setter, so a cheque image that lands can be read straight away */
  @api
  get proofs() {
    return this._proofs;
  }
  set proofs(value) {
    this._proofs = value || [];
    /* MSC-203: the note said "attach the proof first"; it has been */
    if (this.submitNote && this.attachedProofs.length > 0) {
      this.submitNote = undefined;
    }
    this.syncChequeRead();
  }
  _proofs = [];
  /* the parent's answer to this row's last Create Payment: { ok, message }; a success resets the form */
  @api
  get result() {
    return this._result;
  }
  set result(value) {
    const wasOk = !!(this._result && this._result.ok);
    this._result = value;
    if (value && value.ok === true && !wasOk) {
      this._syncSelects = true;
      this.form = { method: "", reference: "", paidDate: todayIso(), amount: "", bank: "" };
      this.touched = {};
      this._amountSeeded = false;
      this.submitNote = undefined;
      /* MSC-197: a recorded payment closes the read with it */
      this._seededDate = this.form.paidDate;
      this._readDocId = undefined;
      this._chequeRead = undefined;
      this.readNote = undefined;
    }
  }
  _result;

  /**
   * MSC-201: everything this block holds about ONE attempt, cleared. The modal keeps its markup
   * alive for 200ms after a close (the exit animation) and reuses the same instance when a row is
   * swapped underneath it, so a fresh mount cannot be relied on. Files already attached to the
   * slot are the page's, not ours, and are untouched - they are real, and the rep came back for
   * them.
   */
  /**
   * MSC-202: slots that were already on the row when this attempt began. An abandoned upload
   * from last time must not become this payment's proof, must not be re-read into the locked
   * cheque fields, and must not ride along on submit. Empty unless reset() runs (the modal
   * calls it on every open), so the embedded ledger blocks behave exactly as before.
   */
  _staleDocIds = new Set();

  @api
  reset() {
    this._syncSelects = true;
    this._staleDocIds = new Set(
      (this._proofs || [])
        .filter((p) => p.documentId && p.contentDocumentId && !p.receiptId)
        .map((p) => p.documentId)
    );
    this.form = { method: "", reference: "", paidDate: todayIso(), amount: "", bank: "" };
    this._seededDate = this.form.paidDate;
    this.touched = {};
    this._amountSeeded = false;
    this._seededWith = undefined;
    this.submitNote = undefined;
    this.staging = [];
    this.removing = {};
    this.removeErrors = {};
    this.showCamera = false;
    this._readDocId = undefined;
    this._chequeRead = undefined;
    this.readNote = undefined;
    this.reading = false;
  }

  @track form = { method: "", reference: "", paidDate: "", amount: "", bank: "" };
  _amountSeeded = false;
  @track touched = {};
  /* files on their way to the slot: [{ key, name, state, message }] */
  @track staging = [];
  /* slots being removed, and what a failed removal said */
  @track removing = {};
  @track removeErrors = {};
  /* the "attach the proof first" line */
  submitNote;
  bankOptions = [];
  bankLoading = false;
  showCamera = false;
  /* MSC-200: is automatic reading on? Only then are a cheque's three boxes read-only. */
  @wire(isChequeReadOn)
  wiredReadOn({ data }) {
    if (data !== undefined) this.readOn = data === true;
  }
  readOn = false;

  /* MSC-197: the cheque read - which file it belongs to, what it said, what to show */
  _readDocId;
  _chequeRead;
  @track readNote;
  reading = false;

  labels = LABELS;

  connectedCallback() {
    if (!this.form.paidDate) {
      this.form = { ...this.form, paidDate: todayIso() };
      /* MSC-197: today's date is the form's guess, not the rep's answer */
      this._seededDate = this.form.paidDate;
    }
  }

  // display

  get requiredDisplay() {
    return formatAED(this.requiredAmount);
  }

  get remainingValue() {
    if (this.remainingAmount !== undefined && this.remainingAmount !== null) {
      return Math.max(0, Number(this.remainingAmount) || 0);
    }
    return Math.max(0, (Number(this.requiredAmount) || 0) - (Number(this.paidAmount) || 0));
  }

  /* the ceiling: open when the row records payments, remaining otherwise */
  get ceilingValue() {
    if (this.recordsPayment && this.openAmount !== undefined && this.openAmount !== null) {
      return Math.max(0, Number(this.openAmount) || 0);
    }
    return this.remainingValue;
  }

  get ceilingDisplay() {
    return formatAED(this.ceilingValue);
  }

  get amountMax() {
    return this.ceilingValue > 0 ? this.ceilingValue : null;
  }

  /* amountHint retired */

  /**
   * MSC-204: a <select> only obeys `selected` on first render - a programmatic reset must move
   * the control by hand or the screen shows one mode with another mode's fields.
   */
  _syncSelects = false;

  syncSelectsToForm() {
    if (!this._syncSelects) return;
    this._syncSelects = false;
    const method = this.template.querySelector('select[data-field="method"]');
    if (method && method.value !== this.form.method) method.value = this.form.method;
    const bank = this.template.querySelector('select[data-field="bank"]');
    if (bank && bank.value !== this.form.bank) bank.value = this.form.bank;
  }

  /** Seeds the amount with the ceiling once, and re-seeds when the ceiling moves under an untouched field. */
  renderedCallback() {
    this.syncSelectsToForm();

    /* MSC-200: a locked cheque is filled by its image, never seeded from the balance */
    if (this.chequeLocked) return;
    const ceiling = this.ceilingValue;
    if (ceiling <= 0) return;
    if (!this._amountSeeded) {
      this._amountSeeded = true;
      this._seededWith = ceiling;
      this.form = { ...this.form, amount: String(ceiling) };
      return;
    }
    if (!this.touched.amount && this._seededWith !== ceiling && String(this.form.amount) === String(this._seededWith)) {
      this._seededWith = ceiling;
      this.form = { ...this.form, amount: String(ceiling) };
    }
  }

  get showHeader() {
    return this.embedded !== true;
  }

  get blockClass() {
    if (this.embedded === true) {
      return this.flat === true
        ? "payment-block payment-block--embedded payment-block--flat"
        : "payment-block payment-block--embedded";
    }
    return "glass payment-block";
  }

  get dueDisplay() {
    return this.dueDate ? formatDate(this.dueDate) : null;
  }

  get positionLabel() {
    if (!this.position || !this.total) return "";
    return `Payment ${this.position} of ${this.total}`;
  }

  get caption() {
    const parts = [];
    if (this.paymentType === "DOWN_PAYMENT") {
      parts.push("Required to confirm the booking");
    } else if (this.paymentType === "ADM_REGISTRATION_FEE" || this.paymentType === "ADM_DARI_CHARGE") {
      parts.push("Government registration fee");
    } else if (this.dueDisplay) {
      parts.push(`Due ${this.dueDisplay}`);
    }
    return parts.join(" · ");
  }

  get statusChipClass() {
    const paid = Number(this.paidAmount || 0);
    const required = Number(this.requiredAmount || 0);
    if (required > 0 && paid >= required) return "chip chip--paid";
    if (paid > 0) return "chip chip--partial";
    if (this.hasProof) return "chip chip--partial";
    return "chip chip--due";
  }

  get statusText() {
    const paid = Number(this.paidAmount || 0);
    const required = Number(this.requiredAmount || 0);
    if (required > 0 && paid >= required) return "Paid";
    if (paid > 0) return "Partially paid";
    if (this.hasProof) return "Proof submitted";
    return this.status || "Not paid";
  }

  get methodChoices() {
    return (this.methodOptions || []).map((m) => ({
      label: m,
      value: m,
      selected: m === this.form.method
    }));
  }

  /* Modon's Create Receipt flow switches its fields on the mode */
  get isCheque() {
    return this.form.method === MOP_CHEQUE;
  }

  get referenceLabel() {
    return this.isCheque ? LABELS.BLOCK_REFERENCE_CHEQUE : LABELS.TRANSACTION_NUMBER;
  }

  get referencePlaceholder() {
    return this.isCheque ? "e.g. 000123" : "e.g. TXN-88213";
  }

  get dateLabel() {
    return this.isCheque ? LABELS.BLOCK_DATE_CHEQUE : LABELS.BLOCK_DATE;
  }

  /* a transfer cannot be dated tomorrow; a cheque can */
  get dateMax() {
    return this.isCheque ? null : todayIso();
  }

  get bankChoices() {
    return (this.bankOptions || []).map((o) => ({
      label: o.label,
      value: o.value,
      selected: o.value === this.form.bank
    }));
  }

  get bankPlaceholder() {
    return this.bankLoading ? "Loading…" : "Select…";
  }

  ensureBankOptions() {
    if (this.bankOptions.length || this.bankLoading) return;
    this.bankLoading = true;
    if (!bankOptionsPromise) {
      bankOptionsPromise = getReceiptBankOptions().catch(() => {
        bankOptionsPromise = null;
        return [];
      });
    }
    bankOptionsPromise.then((opts) => {
      this.bankOptions = opts || [];
      this.bankLoading = false;
    });
  }

  // proofs

  /** Files on a slot, not yet on a Payment - this attempt's only (MSC-202). */
  get attachedProofs() {
    return (this.proofs || []).filter(
      (p) => !!p.contentDocumentId && !p.receiptId && !this._staleDocIds.has(p.documentId)
    );
  }

  get hasProof() {
    return this.attachedProofs.length > 0;
  }

  /* MSC-197: reading the cheque */

  /** The one image a read would be about: the newest cheque proof not yet on a Payment. */
  get readableProof() {
    const list = this.attachedProofs.filter((p) => !!p.contentDocumentId);
    return list.length ? list[list.length - 1] : null;
  }

  /**
   * Starts a read when there is a cheque image and the rep has said this is a cheque - a bank
   * transfer receipt is never sent to the model. Runs once per file.
   */
  syncChequeRead() {
    const proof = this.readableProof;
    if (!proof) {
      /* the file was removed: the read goes with it */
      this._readDocId = undefined;
      this._chequeRead = undefined;
      this.readNote = undefined;
      return;
    }
    if (this.form.method !== MOP_CHEQUE) return;
    if (this._readDocId === proof.contentDocumentId) return;
    this._readDocId = proof.contentDocumentId;
    this._chequeRead = undefined;
    this.readCheque(proof.contentDocumentId);
  }

  /** Best effort, never blocking, and never silent when it does not land. */
  async readCheque(contentDocumentId) {
    this.reading = true;
    this.readNote = undefined;
    let read = null;
    try {
      read = await readChequeImage({ contentDocumentId });
    } catch (e) {
      read = null;
    }
    /* the rep may have swapped or removed the file while this was in flight. A swap has its
       own newer read owning the spinner; a removal has nobody left to clear it - clear it here
       or attach/submit/mode stay locked forever (MSC-206). */
    if (this._readDocId !== contentDocumentId) {
      if (!this._readDocId) this.reading = false;
      return;
    }
    this.reading = false;
    /* null means one thing: the org has automatic reading switched off */
    if (!read) return;
    if (read.status !== "read") {
      this.readNote = {
        text:
          read.status === "notcheque"
            ? LABELS.PROOF_READ_NOT_CHEQUE
            : read.status === "unreadable"
              ? LABELS.PROOF_READ_UNCLEAR
              : LABELS.PROOF_READ_FAILED,
        context: "",
        bad: true,
        canRetry: read.status === "failed"
      };
      return;
    }
    this.applyChequeRead(read);
  }

  /** Fills only what the form itself guessed, never what the rep made their own. */
  applyChequeRead(read) {
    const parts = [];
    const next = { ...this.form };
    let filled = false;
    let differs = false;

    if (read.chequeNumber) {
      parts.push(read.chequeNumber);
      const mine = String(this.form.reference || "").trim() === "";
      if (mine) {
        next.reference = read.chequeNumber;
        filled = true;
      } else if (String(this.form.reference).trim() !== String(read.chequeNumber).trim()) {
        differs = true;
      }
    }
    if (read.chequeDate) {
      parts.push(formatDate(read.chequeDate));
      /* the form seeds today's date; that is a guess and the paper beats it */
      const mine = !this.touched.paidDate && this.form.paidDate === this._seededDate;
      if (mine || !this.form.paidDate) {
        next.paidDate = read.chequeDate;
        filled = true;
      } else if (this.form.paidDate !== read.chequeDate) {
        differs = true;
      }
    }
    if (read.amount !== null && read.amount !== undefined) {
      parts.push(formatAED(read.amount).replace("AED ", ""));
      /* the form seeds the balance; also a guess */
      const seeded = String(this.form.amount) === String(this._seededWith);
      const mine = !this.touched.amount && (seeded || String(this.form.amount || "").trim() === "");
      if (mine) {
        next.amount = String(read.amount);
        this._seededWith = read.amount;
        filled = true;
      } else if (Number(this.form.amount) !== Number(read.amount)) {
        differs = true;
      }
    }
    if (!parts.length) {
      this.readNote = {
        text: LABELS.PROOF_READ_UNCLEAR,
        context: "",
        bad: true,
        canRetry: false
      };
      return;
    }
    this.form = next;
    this._chequeRead = read;
    const tpl = differs
      ? LABELS.PROOF_READ_PLAIN
      : filled
        ? LABELS.PROOF_READ_FILLED
        : LABELS.PROOF_READ_MATCH;
    this.readNote = {
      text: tpl.replace("{0}", parts.join(" \u00b7 ")),
      bad: false,
      canRetry: false
    };
  }

  handleReadAgain() {
    if (this.reading || !this._readDocId) return;
    this.readCheque(this._readDocId);
  }

  /**
   * MSC-200: a cheque's three boxes are the image's to fill. Off for every other method, and off
   * while automatic reading is switched off - the switch must not make a cheque unrecordable.
   */
  get chequeLocked() {
    return this.readOn && this.isCheque;
  }
  /* 1.24: the amount is always typed-in, read or not */
  get showAmountInput() {
    return true;
  }
  get referenceText() {
    return this.form.reference || LABELS.SHEET_AWAIT;
  }
  get paidDateText() {
    return this.form.paidDate ? formatDate(this.form.paidDate) : LABELS.SHEET_AWAIT;
  }
  get amountText() {
    const raw = String(this.form.amount || "").trim();
    return raw === "" ? LABELS.SHEET_AWAIT : formatAED(Number(raw));
  }
  get referenceTextClass() {
    return this.form.reference ? "locked" : "locked locked--wait";
  }
  get paidDateTextClass() {
    return this.form.paidDate ? "locked" : "locked locked--wait";
  }
  get amountTextClass() {
    return String(this.form.amount || "").trim() ? "locked locked--num" : "locked locked--num locked--wait";
  }
  /**
   * MSC-205: what a bank would question, as flags. Red mirrors the server's refusals exactly
   * (stale six months back, a year ten ahead); amber is judgement the rep should apply. A getter,
   * so choosing the right Customer Bank clears the bank flag by itself.
   */
  get chequeIssues() {
    const read = this._chequeRead;
    if (!this.chequeLocked || !read) return [];
    const issues = [];
    if (read.chequeDate) {
      const d = new Date(read.chequeDate + "T00:00:00");
      const stale = new Date();
      stale.setMonth(stale.getMonth() - 6);
      const far = new Date();
      far.setFullYear(far.getFullYear() + 10);
      if (d < stale) issues.push({ key: "stale", text: LABELS.CHQ_STALE, cls: "flag flag--bad" });
      else if (d > far) issues.push({ key: "far", text: LABELS.CHQ_FAR, cls: "flag flag--bad" });
    }
    if (
      read.wordsAmount !== null &&
      read.wordsAmount !== undefined &&
      read.amount !== null &&
      read.amount !== undefined &&
      Math.round(Number(read.wordsAmount) * 100) !== Math.round(Number(read.amount) * 100)
    ) {
      issues.push({ key: "words", text: LABELS.CHQ_WORDS, cls: "flag flag--warn" });
    }
    if (read.payee && !/modon/i.test(read.payee)) {
      issues.push({ key: "payee", text: LABELS.CHQ_PAYEE, cls: "flag flag--warn" });
    }
    if (read.bankName && this.form.bank && !banksAlike(read.bankName, this.form.bank)) {
      issues.push({ key: "bank", text: LABELS.CHQ_BANK, cls: "flag flag--warn" });
    }
    return issues;
  }
  get showChequeIssues() {
    return this.chequeIssues.length > 0;
  }

  get showReadNote() {
    return !!this.readNote;
  }
  get readNoteClass() {
    return this.readNote && this.readNote.bad ? "read read--bad" : "read";
  }
  get readingText() {
    return this.reading ? LABELS.PROOF_READING : null;
  }

  /** The slots this submit will record. */
  get pendingDocumentIds() {
    const ids = [];
    this.attachedProofs.forEach((p) => {
      if (p.documentId && ids.indexOf(p.documentId) < 0) ids.push(p.documentId);
    });
    return ids;
  }

  get proofRows() {
    return this.attachedProofs.map((p) => {
      const removing = this.removing[p.documentId] === true;
      const removeError = this.removeErrors[p.documentId];
      return {
        ...p,
        key: `${p.documentId}-${p.contentDocumentId}`,
        fileLabel: p.fileName || "Attached file",
        /* local calendar day */
        uploadedDisplay: p.uploadedDate ? this.localDate(p.uploadedDate) : null,
        hint: this.recordsPayment ? LABELS.PROOF_PENDING_HINT : null,
        removing,
        removeError,
        cls: removeError
          ? "upload-item proof__file proof__file--failed"
          : removing
            ? "upload-item proof__file proof__file--busy"
            : "upload-item proof__file",
        removeDisabled: this.busy || removing
      };
    });
  }

  get isRemoving() {
    return Object.keys(this.removing || {}).some((k) => this.removing[k] === true);
  }

  localDate(v) {
    const d = new Date(v);
    if (isNaN(d.getTime())) return null;
    const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
  }

  get stagingRows() {
    return (this.staging || []).map((s) => ({
      ...s,
      failed: s.state === "failed",
      text: s.state === "failed" ? s.message : LABELS.PROOF_ATTACHING.replace("{0}", s.name),
      cls: s.state === "failed" ? "upload-item proof__file proof__file--failed" : "upload-item proof__file proof__file--busy"
    }));
  }

  get hasChips() {
    return this.hasProof || (this.staging && this.staging.length > 0);
  }

  /**
   * MSC-194: the sentence names the control the device actually has. On a coarse pointer
   * Attach proof is not drawn, so telling the rep to attach one points at nothing.
   */
  get proofRequiredText() {
    return this.showAttachButton ? LABELS.PROOF_REQUIRED : LABELS.PROOF_REQUIRED_CAMERA;
  }

  get proofEmptyText() {
    return this.recordsPayment ? this.proofRequiredText : LABELS.PROOF_NONE;
  }

  get isAttaching() {
    return (this.staging || []).some((s) => s.state === "attaching");
  }

  get attachDisabled() {
    /* MSC-206: one read at a time - a second file mid-read races the answer in flight */
    return this.busy || this.isAttaching || this.reading;
  }

  get acceptedFormats() {
    return ACCEPT.join(",");
  }

  /**
   * MSC-106: is there a camera that can point at paper? Coarse pointer is the one signal
   * available before the press (the same one c/mscCapture trusts). A touchscreen laptop
   * loses a button it could have used and lands on Attach proof.
   */
  get showCameraButton() {
    return (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia(COARSE_POINTER).matches
    );
  }

  /**
   * MSC-194: one way in per device. A coarse pointer gets the camera and nothing else - the
   * file picker and its input both leave the DOM, so there is no attach path on phone or
   * tablet. A mouse keeps Attach proof exactly as before.
   */
  get showAttachButton() {
    return !this.showCameraButton;
  }

  /** The panel cannot outlive the button that opens it. */
  get showCameraPanel() {
    return this.showCamera === true && this.showCameraButton === true;
  }

  get cameraLabel() {
    return this.showCamera ? "Close camera" : "Use camera";
  }

  /** Always true: the press has already happened. A getter because a bare boolean attribute is "". */
  get cameraAutostart() {
    return true;
  }

  toggleCamera() {
    this.showCamera = !this.showCamera;
  }

  /** The widget's Cancel; the same close the toggle performs. */
  handleCameraCancel() {
    this.showCamera = false;
  }

  // validation

  get errors() {
    return {
      method: this.form.method ? "" : "Required.",
      reference: this.form.reference.trim() ? "" : "Required.",
      paidDate: this.dateError,
      amount: this.amountError,
      bank: this.recordsPayment && this.isCheque && !this.form.bank ? "Required." : ""
    };
  }

  get dateError() {
    if (!this.recordsPayment) return "";
    const raw = String(this.form.paidDate || "").trim();
    if (!raw) return "Required.";
    if (!this.isCheque && raw > todayIso()) return LABELS.BLOCK_DATE_FUTURE;
    return "";
  }

  get amountError() {
    const ceiling = this.ceilingValue;
    if (ceiling <= 0) {
      return "";
    }
    const raw = String(this.form.amount || "").trim();
    if (!raw) {
      return "Required.";
    }
    const value = Number(raw);
    if (Number.isNaN(value) || value <= 0) {
      return "Enter an amount.";
    }
    /* rounded to the fil before comparing */
    if (Math.round(value * 100) > Math.round(ceiling * 100)) {
      return LABELS.BLOCK_AMOUNT_OVER.replace("{0}", this.ceilingDisplay);
    }
    return "";
  }

  get captureAmount() {
    const value = Number(String(this.form.amount || "").trim());
    if (!Number.isNaN(value) && value > 0) {
      return Math.round(value * 100) / 100;
    }
    return this.ceilingValue > 0 ? this.ceilingValue : this.requiredAmount;
  }

  /** Errors show on blur. */
  get fields() {
    const errs = this.errors;
    const show = (f) => (this.touched[f] ? errs[f] : "");
    return {
      method: { error: show("method"), cls: this.cls(show("method"), "field__select") },
      reference: { error: show("reference"), cls: this.cls(show("reference"), "field__input") },
      paidDate: { error: show("paidDate"), cls: this.cls(show("paidDate"), "field__input") },
      amount: { error: show("amount"), cls: this.cls(show("amount"), "field__input") },
      bank: { error: show("bank"), cls: this.cls(show("bank"), "field__select") }
    };
  }

  cls(err, base) {
    return err ? `${base} field__input--error` : base;
  }

  get fieldsValid() {
    const e = this.errors;
    return !e.method && !e.reference && !e.paidDate && !e.amount && !e.bank;
  }

  get canSubmit() {
    /* every field valid, at least one proof attached, nothing in flight */
    /* MSC-206: not while a read is in flight - the boxes may still hold the previous read */
    return this.fieldsValid && this.hasProof && !this.busy && !this.isAttaching && !this.isRemoving && !this.reading;
  }

  get modeDisabled() {
    /* MSC-206: switching method mid-read would abandon the answer silently */
    return this.reading;
  }

  get submitDisabled() {
    return !this.canSubmit;
  }

  get submitLabel() {
    return this.recordsPayment ? LABELS.CTA_CREATE_PAYMENT : `Submit ${this.label} proof`;
  }

  get resultClass() {
    return this.result && this.result.ok ? "proof__result proof__result--ok" : "proof__result proof__result--bad";
  }

  /* only when something went wrong */
  get showResult() {
    return !!(this.result && this.result.message && this.result.ok !== true);
  }

  // handlers

  handleField(event) {
    const field = event.target.dataset.field;
    this.form = { ...this.form, [field]: event.target.value };
    if (field === "method") {
      if (event.target.value === MOP_CHEQUE) {
        this.ensureBankOptions();
        /* MSC-200: a cheque's three values come off the image; nothing carries over. The read
           is re-run from scratch - switching away and back must not leave the boxes empty with
           no way to fill them. */
        if (this.readOn) {
          this.form = { ...this.form, reference: "", paidDate: "", amount: "" };
          this.touched = { ...this.touched, reference: false, paidDate: false, amount: false };
          this._readDocId = undefined;
          this._chequeRead = undefined;
          this.readNote = undefined;
        }
        /* MSC-197: the file may already be attached - read it now that we know it is a cheque */
        this.syncChequeRead();
      } else if (this.readOn) {
        /* back to a method that is typed: the form's own defaults return */
        this.form = { ...this.form, paidDate: this.form.paidDate || todayIso() };
        this._amountSeeded = false;
        this.readNote = undefined;
      }
    }
    this.submitNote = undefined;
  }

  handleBlur(event) {
    const field = event.target.dataset.field;
    this.touched = { ...this.touched, [field]: true };
  }

  /* the console's own attach control */

  openPicker() {
    const input = this.template.querySelector("input[type='file']");
    if (input) input.click();
  }

  async handleFilesPicked(event) {
    const files = Array.from((event.target && event.target.files) || []);
    // reset so picking the same file twice fires a change
    event.target.value = null;
    this.submitNote = undefined;
    for (const file of files) {
      // eslint-disable-next-line no-await-in-loop
      await this.stageFile(file);
    }
  }

  async stageFile(file) {
    const key = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const name = file.name || "file";
    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";
    this.staging = [...this.staging, { key, name, state: "attaching" }];
    if (ACCEPT.indexOf(`.${ext}`) < 0) {
      this.failStaging(key, LABELS.PROOF_TYPE);
      return;
    }
    let dataUrl;
    let fileName = name;
    try {
      dataUrl = await readAsDataUrl(file);
      const isImage = ext !== "pdf";
      if (isImage && file.size > RESAMPLE_ABOVE) {
        const out = await downscale(dataUrl);
        dataUrl = out.dataUrl;
        if (out.changed) fileName = `${name.replace(/\.[^.]+$/, "")}.jpg`;
      }
    } catch (e) {
      this.failStaging(key, LABELS.PROOF_FAILED.replace("{0}", name));
      return;
    }
    const base64 = String(dataUrl).split(",")[1] || "";
    // base64 is 4/3 of the bytes; the server refuses above 4 MB
    if (Math.floor((base64.length * 3) / 4) > MAX_BYTES) {
      this.failStaging(key, LABELS.PROOF_TOO_LARGE.replace("{0}", name));
      return;
    }
    this.emitCapture(base64, fileName, dataUrl, key);
  }

  failStaging(key, message) {
    this.staging = this.staging.map((s) => (s.key === key ? { ...s, state: "failed", message } : s));
  }

  clearStaging(key) {
    this.staging = this.staging.filter((s) => s.key !== key);
  }

  handleDismissStaging(event) {
    this.clearStaging(event.currentTarget.dataset.key);
  }

  /** The camera's capture lands as a picked file does. */
  handleCaptured(event) {
    const d = (event && event.detail) || {};
    this.showCamera = false;
    if (!d.base64) return;
    const key = `${Date.now()}-cam`;
    this.staging = [...this.staging, { key, name: d.fileName || "photo.jpg", state: "attaching" }];
    this.emitCapture(d.base64, d.fileName, d.dataUrl, key);
  }

  /** One file up to the parent, which makes the slot, uploads, reloads and calls `done`. */
  emitCapture(base64, fileName, dataUrl, key) {
    const done = (ok, message) => {
      if (ok) {
        this.clearStaging(key);
      } else {
        this.failStaging(key, message || LABELS.PROOF_FAILED.replace("{0}", fileName || "The file"));
      }
    };
    /* neither bubbling nor composed: c/mscObligations re-raises every event by name */
    this.dispatchEvent(
      new CustomEvent("captureproof", {
        detail: {
          paymentType: this.paymentType,
          relatedRecordId: this.relatedRecordId,
          salesOrderId: this.salesOrderId,
          proofSlotId: this.proofSlotId,
          amount: this.captureAmount,
          reference: this.form.reference,
          base64,
          fileName,
          dataUrl,
          done
        }
      })
    );
  }

  /** The "x" on an attached-not-yet-recorded chip. */
  handleRemoveProof(event) {
    const documentId = event.currentTarget.dataset.id;
    if (!documentId || this.removing[documentId]) return;
    this.removing = { ...this.removing, [documentId]: true };
    const errs = { ...this.removeErrors };
    delete errs[documentId];
    this.removeErrors = errs;
    const done = (ok, message) => {
      const next = { ...this.removing };
      delete next[documentId];
      this.removing = next;
      if (!ok) {
        this.removeErrors = { ...this.removeErrors, [documentId]: message || LABELS.PROOF_FAILED.replace("{0}", "The file") };
      }
    };
    this.dispatchEvent(
      new CustomEvent("proofremoved", {
        detail: { documentId, done }
      })
    );
  }

  handleSubmit() {
    // touch everything so all outstanding errors appear at once
    this.touched = { method: true, reference: true, paidDate: true, amount: true, bank: true };
    if (!this.hasProof) {
      this.submitNote = this.proofRequiredText;
    }
    if (!this.canSubmit) return;
    this.submitNote = undefined;
    this.dispatchEvent(
      new CustomEvent("submitproof", {
        detail: {
          paymentType: this.paymentType,
          relatedRecordId: this.relatedRecordId,
          salesOrderId: this.salesOrderId,
          recordsPayment: this.recordsPayment === true,
          documentId: this.proofSlotId,
          documentIds: this.pendingDocumentIds,
          method: this.form.method,
          transactionNumber: this.form.reference.trim(),
          paidDate: this.form.paidDate,
          amount: this.captureAmount,
          bank: this.isCheque ? this.form.bank : null,
          /* MSC-197: what the console already read off this image, so the server does not pay
             for the same read a second time. Null on anything but a cheque that read cleanly. */
          chequeRead: this.isCheque ? this._chequeRead || null : null
        }
      })
    );
  }

  handleDirectDebit() {
    this.dispatchEvent(
      new CustomEvent("setupdirectdebit", {
        detail: { relatedRecordId: this.relatedRecordId }
      })
    );
  }
}