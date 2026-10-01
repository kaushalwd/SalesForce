/**
 * The cheque sheet - the milestone list as the cheque input table.
 *
 * Version  Author            Date         Detail
 * 1.9      Aurelix Dev       22 Sep 2026  The rep can correct the amount while automatic reading is on.
 *                                         A read fills it until the rep types; after that, a read that disagrees
 *                                         is reported, not written. Cheque number and date stay read-only.
 * 1.8      Aurelix Dev       21 Sep 2026  Native controls again (21 Sep). Withdrawn: the same
 *                                         day's changes that made the bank c/mscPicklist and the cheque
 *                                         date c/mscDatePicker to avoid a grey pop-up that only a Linux
 *                                         desktop shows (SCW-137).
 * 1.7      Aurelix Dev       01 Sep 2026  MSC-205. The same four flags the payment form shows,
 *                                   per row: stale date / typo year (red, refused on submit),
 *                                   words-vs-figures and payee (amber). Bank compares against
 *                                   the sheet's one Customer Bank, live.
 * 1.6      Aurelix Dev       01 Sep 2026  MSC-203. A refusal stops describing a row the rep has
 *                                   since changed: swapping or removing the image, editing a
 *                                   box (switched-off mode) or removing the row dismisses that
 *                                   row's red line and the banner under the table. A fresh
 *                                   submit's answer always shows in full.
 * 1.5b     Aurelix Dev       01 Sep 2026  MSC-200b. The "Also on the image" line is gone.
 * 1.5a     Aurelix Dev       01 Sep 2026  MSC-200b. No x on the image while it is being read.
 * 1.5      Aurelix Dev       01 Sep 2026  MSC-200. The image is the only source: nothing is
 *                                   prefilled, the number/date/amount are read-only text filled
 *                                   by the read, and the first-cheque-number sequence is gone.
 *                                   With automatic reading switched OFF the boxes stay typeable -
 *                                   the switch must not make a cheque impossible to record.
 * 1.4      Aurelix Dev       01 Sep 2026  MSC-199. The read may fill a date, and may fill the
 *                                   amount on an added cheque: the milestone's default date and
 *                                   the amount seeded by "add another cheque" are the sheet's own
 *                                   guesses, and were being defended as if the rep had typed them.
 * 1.3      Aurelix Dev       01 Sep 2026  MSC-198. The table holds its shape: fixed columns, so
 *                                   attaching an image no longer pushes +/x out of view, and the
 *                                   cell says "Attached" instead of a phone's file name. The read
 *                                   moves out of the paragraph under the table and onto a line
 *                                   beneath its OWN row, and the boxes it filled are marked for a
 *                                   few seconds so the rep sees what changed.
 * 1.2      Aurelix Dev       01 Sep 2026  MSC-196. The read is allowed to win: an amount the sheet
 *                                   seeded from the balance is no longer treated as the rep's own,
 *                                   so OCR fills it instead of reporting a difference against it.
 *                                   A read that fails now says so and offers Read again, and what
 *                                   else the image held (payee, IBAN, bank) shows as context.
 * 1.1      Aurelix Dev       21 Aug 2026  MSC-107. Attach image opens the file dialog on a fine pointer.
 * 1.0      Aurelix Developer 18 Aug 2026  Initial. One row per milestone after the down payment; a milestone may
 *                                   take several cheques; recording is the page's job.
 */
import { LightningElement, api, track, wire } from "lwc";
import { formatAED, formatDate, reduceError } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import stageChequeImage from "@salesforce/apex/SalesConsoleController.stageChequeImage";
import readChequeImage from "@salesforce/apex/SalesConsoleController.readChequeImage";
import isChequeReadOn from "@salesforce/apex/SalesConsoleController.isChequeReadOn";
import discardChequeImage from "@salesforce/apex/SalesConsoleController.discardChequeImage";

const ORDINALS = ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th"];
/* MSC-205: words that say nothing about WHICH bank it is (same list as c/mscPaymentBlock) */
const BANK_NOISE = new Set(["bank", "the", "of", "uae", "llc", "pjsc", "psc", "co", "company", "al"]);
function bankTokens(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/[^a-z ]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !BANK_NOISE.has(t));
}
function banksAlike(a, b) {
  const ta = bankTokens(a);
  const tb = bankTokens(b);
  if (!ta.length || !tb.length) return true;
  return ta.some((t) => tb.indexOf(t) >= 0);
}
/** MSC-205: what a bank would question on one read; bank is the sheet's single choice. */
function chequeFlags(read, chosenBank, labels) {
  const flags = [];
  if (read.chequeDate) {
    const d = new Date(read.chequeDate + "T00:00:00");
    const stale = new Date();
    stale.setMonth(stale.getMonth() - 6);
    const far = new Date();
    far.setFullYear(far.getFullYear() + 10);
    if (d < stale) flags.push({ key: "stale", text: labels.CHQ_STALE, cls: "flag flag--bad" });
    else if (d > far) flags.push({ key: "far", text: labels.CHQ_FAR, cls: "flag flag--bad" });
  }
  if (
    read.wordsAmount !== null &&
    read.wordsAmount !== undefined &&
    read.amount !== null &&
    read.amount !== undefined &&
    Math.round(Number(read.wordsAmount) * 100) !== Math.round(Number(read.amount) * 100)
  ) {
    flags.push({ key: "words", text: labels.CHQ_WORDS, cls: "flag flag--warn" });
  }
  if (read.payee && !/modon/i.test(read.payee)) {
    flags.push({ key: "payee", text: labels.CHQ_PAYEE, cls: "flag flag--warn" });
  }
  if (read.bankName && chosenBank && !banksAlike(read.bankName, chosenBank)) {
    flags.push({ key: "bank", text: labels.CHQ_BANK, cls: "flag flag--warn" });
  }
  return flags;
}

function ordinal(n) {
  return ORDINALS[n] || `${n}th`;
}

/** Money to the fil. */
function money(v) {
  const n = Number(v);
  return Number.isNaN(n) ? 0 : Math.round(n * 100) / 100;
}

/* MSC-200: sequence() and renumber() are gone with the first-cheque-number control - nothing is
   numbered for the rep any more; the number comes off the cheque itself. */

let seq = 0;

/** The same query c/mscPaymentBlock and c/mscCapture read; the three must stay identical. */
const COARSE_POINTER = "(pointer: coarse)";

/** c/mscCapture's own backstop, repeated for the route that does not go through the widget. */
const MAX_PICK_BYTES = 4 * 1024 * 1024;

export default class MscChequeSheet extends LightningElement {
  @api salesOrderId;
  /** Receipt__c.Bank__c options. */
  @api bankOptions = [];
  /** The page is recording the batch. */
  @api busy = false;
  /** ChequeBatchResultDTO after a refusal. MSC-203: a NEW answer always shows in full. */
  @api
  get results() {
    return this._results;
  }
  set results(value) {
    this._results = value;
    this._dismissed = new Set();
    this._bannerDismissed = false;
  }
  _results;
  /** A refusal the page wants shown under the table; dismissed the same way. */
  @api
  get errorMessage() {
    return this._errorMessage;
  }
  set errorMessage(value) {
    this._errorMessage = value;
    this._bannerDismissed = false;
  }
  _errorMessage;
  /** MSC-203: rows the rep has changed since the last answer - it no longer describes them. */
  _dismissed = new Set();
  @track _bannerDismissed = false;

  /** The last answer stops speaking for a row the rep just changed. */
  noteRowActivity(key) {
    if (!key) return;
    if (this._dismissed.has(key) && this._bannerDismissed) return;
    this._dismissed = new Set([...this._dismissed, key]);
    this._bannerDismissed = true;
  }

  /** BatchLineDTO[]. The setter merges, so a reload does not lose typed cheques. */
  @api
  get lines() {
    return this._lines;
  }
  set lines(value) {
    this._lines = value || [];
    this.merge();
  }
  _lines = [];

  labels = LABELS;

  @track state = { bank: "" };
  /* MSC-200: null until the org answers; the boxes are read-only only when reading is ON */
  @wire(isChequeReadOn)
  wiredReadOn({ data }) {
    if (data !== undefined) this.readOn = data === true;
  }
  readOn = false;
  /** The sheet's rows; `key` is the sheet's own id and the batch's clientKey. */
  @track rows = [];
  /** The row whose image is being captured (camera route only). */
  capturingKey;
  /** The row a straight-to-the-file-dialog press belongs to. */
  _pickKey;
  /** Read-from-image notes, keyed by row. */
  @track notes = [];
  /** MSC-205: the last successful read per row, for the flags. */
  @track reads = {};

  /* rows */

  merge() {
    const byInstallment = new Map();
    this.rows.forEach((r) => {
      if (!byInstallment.has(r.installmentId)) byInstallment.set(r.installmentId, []);
      byInstallment.get(r.installmentId).push(r);
    });
    const next = [];
    this._lines.forEach((l) => {
      const existing = byInstallment.get(l.installmentId);
      if (existing && existing.length) {
        existing.forEach((r) =>
          next.push({
            ...r,
            label: l.label,
            milestoneNumber: l.milestoneNumber,
            dueDate: l.dueDate,
            overdue: l.overdue === true,
            open: money(l.openAmount),
            chequeDateDefault: l.chequeDateDefault
          })
        );
      } else {
        next.push(this.newRow(l, 1));
      }
    });
    this.rows = next;
  }

  newRow(l, sub) {
    seq += 1;
    return {
      key: `c${seq}`,
      installmentId: l.installmentId,
      milestoneNumber: l.milestoneNumber,
      label: l.label,
      dueDate: l.dueDate,
      overdue: l.overdue === true,
      open: money(l.openAmount),
      chequeDateDefault: l.chequeDateDefault,
      sub,
      ticked: false,
      /* MSC-200: nothing is proposed - every value on this row comes from the cheque image */
      chequeNumber: "",
      chequeDate: "",
      amount: "",
      image: undefined,
      staging: false,
      reading: false
    };
  }

  rowsOf(installmentId) {
    return this.rows.filter((r) => r.installmentId === installmentId);
  }

  /** What earlier rows of the same milestone already take up. */
  takenBefore(row) {
    let sum = 0;
    for (const r of this.rows) {
      if (r === row || r.key === row.key) break;
      if (r.installmentId === row.installmentId && r.ticked) sum += money(r.amount);
    }
    return money(sum);
  }

  update(key, patch) {
    this.rows = this.rows.map((r) => (r.key === key ? { ...r, ...patch } : r));
  }

  find(key) {
    return this.rows.find((r) => r.key === key);
  }

  /* handlers: header */

  handleBank(event) {
    this.state = { ...this.state, bank: event.target.value };
  }

  /* handlers: rows */

  handleTick(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.find(key);
    if (!row) return;
    const ticked = !row.ticked;
    /* MSC-200: ticking a row proposes nothing; the image fills it */
    this.update(key, { ticked });
  }

  handleField(event) {
    const key = event.currentTarget.dataset.key;
    const field = event.currentTarget.dataset.field;
    const value = event.target.value;
    /* MSC-200: number and date are read-only text while automatic reading is on; the amount is
       always typed here (1.9), and a typed amount is kept when a later read disagrees */
    this.noteRowActivity(key);
    const patch = { [field]: value };
    if (field === "amount") patch.amountByRep = value !== "";
    if (field === "amount" && value !== "") {
      // typing an amount is ticking the row
      const row = this.find(key);
      if (row && !row.ticked) patch.ticked = true;
    }
    this.update(key, patch);
  }

  handleAddRow(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.find(key);
    if (!row) return;
    const siblings = this.rowsOf(row.installmentId);
    const last = siblings[siblings.length - 1];
    const line = this._lines.find((l) => l.installmentId === row.installmentId) || row;
    const added = this.newRow(
      {
        installmentId: row.installmentId,
        milestoneNumber: row.milestoneNumber,
        label: row.label,
        dueDate: row.dueDate,
        overdue: row.overdue,
        openAmount: row.open,
        chequeDateDefault: line.chequeDateDefault || row.chequeDateDefault
      },
      siblings.length + 1
    );
    added.ticked = true;
    const idx = this.rows.findIndex((r) => r.key === last.key);
    const rows = this.rows.slice();
    rows.splice(idx + 1, 0, added);
    this.rows = rows;
    /* MSC-200: an added cheque is as blank as any other; its image fills it */
  }

  handleRemoveRow(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.find(key);
    if (!row || row.sub <= 1) return;
    if (row.image && row.image.contentDocumentId) {
      discardChequeImage({ contentDocumentId: row.image.contentDocumentId }).catch(() => {});
    }
    this.noteRowActivity(key);
    const remainingReads = { ...this.reads };
    delete remainingReads[key];
    this.reads = remainingReads;
    this.rows = this.rows.filter((r) => r.key !== key);
    if (this.capturingKey === key) this.capturingKey = undefined;
    this.notes = this.notes.filter((n) => n.key !== key);
  }

  /* handlers: the image */

  /** Two routes: the panel on a coarse pointer, the file dialog on a fine one. */
  handleAttach(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    if (this.offersCamera) {
      this.capturingKey = key;
      return;
    }
    this._pickKey = key;
    const input = this.template.querySelector("input.sheet__file");
    if (input) {
      input.value = null;
      input.click();
    }
  }

  /** Is there a camera here that can see a cheque? Coarse pointer is the signal available before the press. */
  get offersCamera() {
    return (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia(COARSE_POINTER).matches
    );
  }

  /** The file dialog's result, handed to the same handler the camera uses. */
  handlePickedFile(event) {
    const input = event.target;
    const file = input.files && input.files[0];
    // reset so picking the same file twice fires a change
    input.value = null;
    const key = this._pickKey;
    this._pickKey = undefined;
    if (!file || !key || !this.find(key)) return;

    if (file.size > MAX_PICK_BYTES) {
      this.update(key, { error: LABELS.SHEET_FILE_TOO_LARGE.replace("{0}", file.name) });
      return;
    }
    this.update(key, { error: undefined });

    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result);
      this.applyCapturedImage(key, {
        base64: dataUrl.split(",")[1],
        fileName: file.name,
        dataUrl
      });
    };
    reader.onerror = () => {
      this.update(key, { error: LABELS.SHEET_FILE_UNREADABLE });
    };
    reader.readAsDataURL(file);
  }

  handleCaptureClose() {
    this.capturingKey = undefined;
  }

  handleCaptured(event) {
    /* the guard runs before the key is cleared */
    const key = this.capturingKey;
    const d = (event && event.detail) || {};
    if (!this.find(key) || !d.base64) return;
    this.capturingKey = undefined;
    this.applyCapturedImage(key, d);
  }

  /** Both routes end here: staging, the thumbnail, and the read that fills the row. */
  async applyCapturedImage(key, d) {
    const row = this.find(key);
    if (!row || !d || !d.base64) return;
    this.update(key, { staging: true, error: undefined });
    let staged;
    try {
      staged = await stageChequeImage({
        installmentId: row.installmentId,
        base64Data: d.base64,
        fileName: d.fileName
      });
    } catch (e) {
      this.update(key, { staging: false, error: reduceError(e) });
      return;
    }
    this.noteRowActivity(key);
    const isImage = !/\.pdf$/i.test(d.fileName || "");
    this.update(key, {
      staging: false,
      ticked: true,
      image: {
        contentDocumentId: staged.contentDocumentId,
        contentVersionId: staged.contentVersionId,
        fileName: staged.fileName || d.fileName,
        dataUrl: isImage ? d.dataUrl : undefined
      }
    });
    /* MSC-200: no amount is proposed here either - the read that follows is what fills the row */
    this.readImage(key, staged.contentDocumentId);
  }

  /** Best effort, never blocking. MSC-196: and never silent when it does not land. */
  async readImage(key, contentDocumentId) {
    this.update(key, { reading: true });
    this.notes = this.notes.filter((n) => n.key !== key);
    let read = null;
    try {
      read = await readChequeImage({ contentDocumentId });
    } catch (e) {
      read = null;
    }
    const row = this.find(key);
    this.update(key, { reading: false });
    if (!row) return;
    /* null means one thing: the org has automatic reading switched off */
    if (!read) return;
    if (read.status && read.status !== "read") {
      this.sayReadFailed(key, row, read.status);
      return;
    }
    const parts = [];
    const patch = {};
    let filled = false;
    let differs = false;
    if (read.chequeNumber) {
      parts.push(read.chequeNumber);
      /* MSC-200: with the boxes read-only nothing but a previous read can be here, so the newest
         read wins; while reading is OFF a number the rep typed is left alone and reported. */
      if (!row.chequeNumber || this.readOn) {
        patch.chequeNumber = read.chequeNumber;
        filled = true;
      } else if (String(row.chequeNumber).trim() !== String(read.chequeNumber).trim()) {
        differs = true;
      }
    }
    if (read.chequeDate) {
      parts.push(formatDate(read.chequeDate));
      if (!row.chequeDate || this.readOn) {
        patch.chequeDate = read.chequeDate;
        filled = true;
      } else if (row.chequeDate !== read.chequeDate) {
        differs = true;
      }
    }
    if (read.amount !== null && read.amount !== undefined) {
      parts.push(formatAED(read.amount).replace("AED ", ""));
      const typed = row.amount !== "" && row.amount !== undefined && row.amount !== null;
      /* 1.9: a read no longer overwrites an amount the rep typed */
      if (!typed || (this.readOn && !row.amountByRep)) {
        patch.amount = money(read.amount);
        filled = true;
      } else if (money(row.amount) !== money(read.amount)) {
        differs = true;
      }
    }
    if (!parts.length) {
      /* the service answered, but with nothing usable on it */
      this.sayReadFailed(key, row, "unreadable");
      return;
    }
    if (Object.keys(patch).length) this.update(key, patch);
    const tpl = differs
      ? LABELS.SHEET_READ_DIFF
      : filled
        ? LABELS.SHEET_READ_FILLED
        : LABELS.SHEET_READ_MATCH;
    const text = tpl.replace("{0}", this.rowName(row)).replace("{1}", parts.join(" · "));
    this.notes = [
      ...this.notes.filter((n) => n.key !== key),
      { key, text, bad: false, canRetry: false }
    ];
    this.reads = { ...this.reads, [key]: read };
  }

  /**
   * MSC-196: the read did not land. 'failed' is worth another go (a timeout, a 503); an image
   * that is unclear or is not a cheque reads the same way twice, so those only say so.
   */
  sayReadFailed(key, row, status) {
    const name = this.rowName(row);
    const tpl =
      status === "notcheque"
        ? LABELS.SHEET_READ_NOT_CHEQUE
        : status === "unreadable"
          ? LABELS.SHEET_READ_UNCLEAR
          : LABELS.SHEET_READ_FAILED;
    this.notes = [
      ...this.notes.filter((n) => n.key !== key),
      {
        key,
        text: tpl.replace("{0}", name),
        context: "",
        bad: true,
        canRetry: status === "failed"
      }
    ];
  }

  /** The rep asks for one more attempt on the image already staged. */
  handleReadAgain(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.find(key);
    if (!row || !row.image || !row.image.contentDocumentId || row.reading) return;
    this.readImage(key, row.image.contentDocumentId);
  }

  handleRemoveImage(event) {
    const key = event.currentTarget.dataset.key;
    const row = this.find(key);
    if (!row || !row.image) return;
    if (row.image.contentDocumentId) {
      discardChequeImage({ contentDocumentId: row.image.contentDocumentId }).catch(() => {});
    }
    this.noteRowActivity(key);
    this.update(key, { image: undefined });
    this.notes = this.notes.filter((n) => n.key !== key);
    const keptReads = { ...this.reads };
    delete keptReads[key];
    this.reads = keptReads;
  }

  /* handlers: footer */

  handleCancel() {
    // abandoned images come off the milestone
    this.rows.forEach((r) => {
      if (r.image && r.image.contentDocumentId) {
        discardChequeImage({ contentDocumentId: r.image.contentDocumentId }).catch(() => {});
      }
    });
    this.dispatchEvent(new CustomEvent("chequecancel"));
  }

  handleSubmit() {
    if (this.submitDisabled) return;
    const lines = this.ticked.map((r) => ({
      clientKey: r.key,
      installmentId: r.installmentId,
      chequeNumber: String(r.chequeNumber || "").trim(),
      chequeDate: r.chequeDate,
      amount: money(r.amount),
      contentDocumentId: r.image ? r.image.contentDocumentId : null
    }));
    this.dispatchEvent(
      new CustomEvent("chequesubmit", {
        detail: { salesOrderId: this.salesOrderId, bank: this.state.bank, lines }
      })
    );
  }

  /* derived */

  get ticked() {
    return this.rows.filter((r) => r.ticked);
  }

  rowName(row) {
    const base = row.label || `Milestone ${row.milestoneNumber}`;
    return row.sub > 1 ? `${base}, ${ordinal(row.sub)} cheque` : base;
  }

  get bankChoices() {
    return (this.bankOptions || []).map((o) => ({
      value: o.value,
      label: o.label,
      selected: o.value === this.state.bank
    }));
  }

  get bankLabel() {
    const hit = (this.bankOptions || []).find((o) => o.value === this.state.bank);
    return hit ? hit.label : "";
  }

  get range() {
    const nums = this._lines.map((l) => l.milestoneNumber).filter((n) => n !== null && n !== undefined);
    if (!nums.length) return null;
    return { first: Math.min(...nums), last: Math.max(...nums) };
  }

  get title() {
    const r = this.range;
    if (!r) return LABELS.SHEET_TITLE.replace("{0}", "").replace("{1}", "");
    if (r.first === r.last) return LABELS.SHEET_TITLE_ONE.replace("{0}", r.first);
    return LABELS.SHEET_TITLE.replace("{0}", r.first).replace("{1}", r.last);
  }

  /** Every check the server will make, made here first. */
  get problems() {
    const out = { missingImage: [], over: [], twice: [], incomplete: [] };
    const seen = new Set();
    const sumBy = new Map();
    this.ticked.forEach((r) => {
      if (!r.image) out.missingImage.push(r);
      const num = String(r.chequeNumber || "").trim().toUpperCase();
      if (!num || !r.chequeDate || !(money(r.amount) > 0)) out.incomplete.push(r);
      if (num) {
        if (seen.has(num)) out.twice.push(num);
        seen.add(num);
      }
      sumBy.set(r.installmentId, money((sumBy.get(r.installmentId) || 0) + money(r.amount)));
    });
    sumBy.forEach((sum, installmentId) => {
      const row = this.rows.find((r) => r.installmentId === installmentId);
      if (row && sum > row.open + 0.005) out.over.push(row);
    });
    return out;
  }

  get warning() {
    const p = this.problems;
    if (p.over.length) return LABELS.SHEET_OVER.replace("{0}", p.over[0].label);
    if (p.twice.length) return LABELS.SHEET_NUMBER_TWICE.replace("{0}", p.twice[0]);
    if (p.missingImage.length === 1) return LABELS.SHEET_IMAGE_NEEDED.replace("{0}", this.rowName(p.missingImage[0]));
    if (p.missingImage.length > 1) return LABELS.SHEET_IMAGES_NEEDED.replace("{0}", p.missingImage.length);
    return null;
  }

  get submitDisabled() {
    const p = this.problems;
    return (
      this.busy ||
      !this.state.bank ||
      this.ticked.length === 0 ||
      p.missingImage.length > 0 ||
      p.over.length > 0 ||
      p.twice.length > 0 ||
      p.incomplete.length > 0 ||
      /* MSC-206: a row mid-read may still show its previous read's numbers */
      this.rows.some((r) => r.staging || r.reading)
    );
  }

  get submitLabel() {
    if (this.busy) return LABELS.CTA_RECORDING_CHEQUES;
    const n = this.ticked.length;
    return n === 1 ? LABELS.CTA_RECORD_CHEQUE : LABELS.CTA_RECORD_CHEQUES.replace("{0}", n || 0);
  }

  get summary() {
    const t = this.ticked;
    if (!t.length) return LABELS.SHEET_SUM_NONE;
    const total = t.reduce((s, r) => s + money(r.amount), 0);
    const bank = this.bankLabel || LABELS.SHEET_SUM_NO_BANK;
    let text =
      t.length === 1
        ? LABELS.SHEET_SUM_ONE.replace("{0}", formatAED(total)).replace("{1}", bank)
        : LABELS.SHEET_SUM.replace("{0}", t.length).replace("{1}", formatAED(total)).replace("{2}", bank);
    const missing = this.problems.missingImage.length;
    if (missing === 1) text += ` · ${LABELS.SHEET_SUM_MISSING.replace("{0}", 1)}`;
    if (missing > 1) text += ` · ${LABELS.SHEET_SUM_MISSING_MANY.replace("{0}", missing)}`;
    return text;
  }

  get capturing() {
    return !!this.capturingKey && !!this.find(this.capturingKey);
  }

  get capturingLabel() {
    const row = this.find(this.capturingKey);
    return row ? LABELS.SHEET_ATTACHING.replace("{0}", this.rowName(row)) : "";
  }

  /* MSC-198: readNotes retired - each note now rides its own row (see viewRows.note) */

  get resultByKey() {
    const map = {};
    const list = (this.results && this.results.lines) || [];
    list.forEach((l) => {
      /* MSC-203: not for a row that has changed since */
      if (l && l.clientKey && !this._dismissed.has(l.clientKey)) map[l.clientKey] = l;
    });
    return map;
  }

  /** MSC-203: the banner under the table, unless the rep has already acted on it. */
  get shownErrorMessage() {
    return this._bannerDismissed ? "" : this.errorMessage;
  }

  get viewRows() {
    const results = this.resultByKey;
    /* MSC-198: the read belongs to its row, not to a paragraph under the table */
    const noteByKey = {};
    this.notes.forEach((n) => {
      noteByKey[n.key] = {
        ...n,
        cls: n.bad ? "sheet__note sheet__note--bad" : "sheet__note",
        contextKey: n.key + "-x",
        flags: this.reads[n.key]
          ? chequeFlags(this.reads[n.key], this.state.bank, LABELS)
          : []
      };
    });
    const p = this.problems;
    const overIds = new Set(p.over.map((r) => r.installmentId));
    return this.rows.map((r) => {
      const covered = r.open <= 0 && r.sub === 1;
      const siblings = this.rowsOf(r.installmentId);
      const isLast = siblings[siblings.length - 1].key === r.key;
      const taken = this.takenBefore(r);
      const leftForRow = Math.max(0, money(r.open - taken));
      const res = results[r.key];
      const resultText = res && res.message ? res.message : null;
      const disabled = this.busy || covered;
      const numberBlank = r.ticked && !String(r.chequeNumber || "").trim();
      const amountBad = r.ticked && !(money(r.amount) > 0);
      const over = r.ticked && overIds.has(r.installmentId);
      return {
        ...r,
        rowClass: [
          "sheet__row",
          r.ticked ? "sheet__row--on" : "sheet__row--off",
          covered ? "sheet__row--covered" : "",
          r.sub > 1 ? "sheet__row--sub" : ""
        ].join(" "),
        tickDisabled: disabled,
        inputsDisabled: disabled || !r.ticked,
        msLabel: r.sub > 1 ? LABELS.SHEET_ANOTHER_ROW.replace("{0}", ordinal(r.sub)) : r.label,
        msClass: r.sub > 1 ? "sheet__ms sheet__ms--sub" : "sheet__ms",
        dueLabel: r.sub > 1 ? "" : r.dueDate ? formatDate(r.dueDate) : "",
        overdue: r.sub === 1 && r.overdue,
        leftLabel: covered
          ? LABELS.SHEET_COVERED
          : r.sub > 1
            ? formatAED(leftForRow).replace("AED ", "")
            : formatAED(r.open).replace("AED ", ""),
        attachClass: r.ticked ? "img img--need" : "img img--need img--dim",
        /* MSC-200: read-only text when the image is the source; the input classes below are for
           the fallback the switch-off leaves behind */
        locked: this.readOn,
        showAmountInput: true,
        numberText: r.chequeNumber || LABELS.SHEET_AWAIT,
        dateText: r.chequeDate ? formatDate(r.chequeDate) : LABELS.SHEET_AWAIT,
        amountText:
          r.amount === "" || r.amount === undefined || r.amount === null
            ? LABELS.SHEET_AWAIT
            : formatAED(money(r.amount)).replace("AED ", ""),
        numberTextClass: r.ticked && !String(r.chequeNumber || "").trim()
          ? "sheet__val sheet__val--wait"
          : "sheet__val",
        dateTextClass: r.ticked && !r.chequeDate ? "sheet__val sheet__val--wait" : "sheet__val",
        amountTextClass:
          r.ticked && !(money(r.amount) > 0)
            ? "sheet__val sheet__val--num sheet__val--wait"
            : "sheet__val sheet__val--num",
        numberClass: numberBlank ? "sheet__in sheet__in--bad" : "sheet__in",
        dateClass: r.ticked && !r.chequeDate ? "sheet__in sheet__in--bad" : "sheet__in",
        amountClass:
          amountBad || over ? "sheet__in sheet__in--num sheet__in--bad" : "sheet__in sheet__in--num",
        showAdd: isLast && r.ticked && !covered && r.open > 0,
        showRemove: r.sub > 1,
        note: noteByKey[r.key] || null,
        noteKey: `${r.key}-n`,
        groupKey: `${r.key}-g`,
        result: resultText,
        resultKey: `${r.key}-r`,
        resultClass: res && res.ok ? "sheet__result sheet__result--ok" : "sheet__result sheet__result--bad",
        readingText: r.reading ? LABELS.SHEET_READING : null,
        /* MSC-200b: the x steps aside while the image is being read */
        canRemoveImage: !r.reading
      };
    });
  }
}