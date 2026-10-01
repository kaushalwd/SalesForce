/**
 * Identity document fields - the set a buyer's residency requires, drawn once.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 22 Aug 2026  MSC-110. Four screens now capture identity - the
 *                                   console's create form, its qualify panel, its
 *                                   identity step, and My Leads' New lead - and Shadow
 *                                   DOM means they cannot share markup any other way.
 *                                   Three hand-copies of a masked Emirates ID input is
 *                                   how two screens end up storing the same number in
 *                                   two shapes, which is the duplicate this whole
 *                                   workstream exists to stop.
 * 1.1      Aurelix Dev 22 Aug 2026  MSC-111. Layout only: :host and the wrapper are
 *                                   display:contents, so the five .field blocks join
 *                                   the PARENT's grid instead of opening a second
 *                                   auto-fit grid whose column count disagreed with
 *                                   the form around it at most widths. Behaviour,
 *                                   events and validation untouched.
 * 1.4      Aurelix Dev 27 Sep 2026  MODON's Lead rules (Sales App parity). The asterisk follows
 *                                   what is owed (identityNeedsFor's *Required flags: a Non-Resident's passport
 *                                   number only), and an expiry of today is accepted, as MODON's "< TODAY()"
 *                                   rules accept it (min and the check are today, were tomorrow).
 * 1.2      Aurelix Dev 21 Sep 2026  Native date inputs again. Withdrawn: the same
 *                                   day's c/mscDatePicker for the three dates. Inside the booking pop-
 *                                   up its calendar was cut off, month and year header included, and
 *                                   the grey calendar it avoided only shows on a Linux desktop
 *                                   (SCW-137).
 *
 * Dumb by design, like c/mscEoiIdentity: every value is an @api prop, every change is
 * an event, and the parent owns the state, the Apex and the save. Which fields exist,
 * what shape each must hold, and when the set is complete all come from ONE place -
 * identityNeedsFor / identitySetComplete in c/mscEoiUtils, the client mirror of
 * SalesConsoleLeadController's own gate - so this file only knows how to draw them.
 *
 * WHAT THE FIELD RULES MIRROR, and why refusing here is the point:
 *   Emirates_Id_Number_Format          784-XXXX-XXXXXXX-X, enforced on En_EIDNumber__c
 *   Passport_Number_Format_Check       letters and digits only
 *   EID_ExpiryDate_Cannot_be_Past      expiry today or later (min = today; 1.4)
 *   Passport_Expir_Date_Should_not_be_Past   same
 *   Passport_Issue_Date_Should_not_be_Future issue on or before today (max = today)
 * A value this component accepts is a value the org accepts; the alternative is a
 * raw rule dump after the round trip.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { formatDate } from "c/modonSalesFormat";
import {
  EMIRATES_ID_REGEX,
  PASSPORT_REGEX,
  applyEmiratesIdMask,
  identityNeedsFor,
  identitySetComplete,
  localISODate
} from "c/mscEoiUtils";

export default class MscIdentityFields extends LightningElement {
  /** The residency whose rules decide which fields exist. Blank draws nothing -
   *  the parent asks residency first and this set appears when it is answered. */
  @api residentStatus = "";
  /** { eidNumber, eidExpiry, passportNumber, passportIssueDate, passportExpiryDate } */
  @api values = {};
  /** Per-field reason a stored value could not be used: { eidExpiry: { code, date } }.
   *  Codes are the server's - 'missing' | 'expired' | 'future' - and every sentence
   *  they become lives in c/mscLabels. */
  @api reasons = {};
  /** Per-field lock: true renders the field readonly. A locked value came off a
   *  record the org already holds and is taken AS IT IS - same rule the console
   *  applies to a matched account's email - so shape checks skip it: a legacy
   *  Emirates ID stored without dashes must not block the booking it identifies. */
  @api locked = {};
  @api disabled = false;

  labels = LABELS;

  /* ── which fields exist ─────────────────────────────────────────────────── */

  get needs() {
    return identityNeedsFor(this.residentStatus);
  }
  get showEid() {
    return this.needs.eidNumber;
  }
  get showEidExpiry() {
    return this.needs.eidExpiry;
  }
  get showPassport() {
    return this.needs.passportNumber;
  }
  get showPassportIssue() {
    return this.needs.passportIssueDate;
  }
  get showPassportExpiry() {
    return this.needs.passportExpiryDate;
  }
  get showAny() {
    const n = this.needs;
    return n.eidNumber || n.passportNumber;
  }

  /* ── values, always strings ─────────────────────────────────────────────── */

  val(field) {
    const v = (this.values || {})[field];
    return v === null || v === undefined ? "" : String(v);
  }
  get eidValue() {
    return this.val("eidNumber");
  }
  get eidExpiryValue() {
    return this.val("eidExpiry");
  }
  get passportValue() {
    return this.val("passportNumber");
  }
  get passportIssueValue() {
    return this.val("passportIssueDate");
  }
  get passportExpiryValue() {
    return this.val("passportExpiryDate");
  }

  isLocked(field) {
    return !!(this.locked && this.locked[field]);
  }
  get eidLocked() {
    return this.isLocked("eidNumber");
  }
  get eidExpiryLocked() {
    return this.isLocked("eidExpiry");
  }
  get passportLocked() {
    return this.isLocked("passportNumber");
  }
  get passportIssueLocked() {
    return this.isLocked("passportIssueDate");
  }
  get passportExpiryLocked() {
    return this.isLocked("passportExpiryDate");
  }

  /* ── date bounds, straight from the rules ───────────────────────────────── */

  get todayISO() {
    return localISODate(0);
  }
  get tomorrowISO() {
    return localISODate(1);
  }

  /* 1.4 - the asterisk marks what MODON's rules owe, not what is shown */
  get eidLabel() {
    return this.needs.eidNumberRequired ? `${LABELS.IDF_EID_LABEL} *` : LABELS.IDF_EID_LABEL;
  }
  get eidExpiryLabel() {
    return this.needs.eidExpiryRequired ? `${LABELS.IDF_EID_EXPIRY_LABEL} *` : LABELS.IDF_EID_EXPIRY_LABEL;
  }
  get passportLabel() {
    return this.needs.passportNumberRequired ? `${LABELS.IDF_PASSPORT_LABEL} *` : LABELS.IDF_PASSPORT_LABEL;
  }
  get passportIssueLabel() {
    return this.needs.passportIssueDateRequired
      ? `${LABELS.IDF_PASSPORT_ISSUE_LABEL} *`
      : LABELS.IDF_PASSPORT_ISSUE_LABEL;
  }
  get passportExpiryLabel() {
    return this.needs.passportExpiryDateRequired
      ? `${LABELS.IDF_PASSPORT_EXPIRY_LABEL} *`
      : LABELS.IDF_PASSPORT_EXPIRY_LABEL;
  }

  /* ── per-field errors: only about what the rep typed ────────────────────── */

  get eidError() {
    const v = this.eidValue.trim();
    if (!v || this.eidLocked) return null;
    return EMIRATES_ID_REGEX.test(v) ? null : LABELS.IDF_EID_SHAPE;
  }
  get passportError() {
    const v = this.passportValue.trim();
    if (!v || this.passportLocked) return null;
    return PASSPORT_REGEX.test(v) ? null : LABELS.IDF_PASSPORT_SHAPE;
  }
  get eidExpiryError() {
    const v = this.eidExpiryValue;
    if (!v || this.eidExpiryLocked) return null;
    return v >= this.todayISO ? null : LABELS.IDF_EXPIRY_PAST;
  }
  get passportIssueError() {
    const v = this.passportIssueValue;
    if (!v || this.passportIssueLocked) return null;
    return v <= this.todayISO ? null : LABELS.IDF_ISSUE_FUTURE;
  }
  get passportExpiryError() {
    const v = this.passportExpiryValue;
    if (!v || this.passportExpiryLocked) return null;
    return v >= this.todayISO ? null : LABELS.IDF_EXPIRY_PAST;
  }

  fieldClass(error) {
    return `field__input${error ? " field__input--error" : ""}`;
  }
  get eidClass() {
    return this.fieldClass(this.eidError);
  }
  get passportClass() {
    return this.fieldClass(this.passportError);
  }
  get eidExpiryClass() {
    return this.fieldClass(this.eidExpiryError);
  }
  get passportIssueClass() {
    return this.fieldClass(this.passportIssueError);
  }
  get passportExpiryClass() {
    return this.fieldClass(this.passportExpiryError);
  }

  /* ── why a stored value was not enough, said under the field ────────────── */

  reasonText(field, expiredLabel, futureLabel) {
    const r = (this.reasons || {})[field];
    if (!r || !r.code) return null;
    if (r.code === "expired" && expiredLabel) {
      return expiredLabel.replace("{0}", formatDate(r.date));
    }
    if (r.code === "future") {
      return futureLabel || null;
    }
    /* 'missing' draws no extra line - the empty required field already says it,
       and a sentence under every blank would read as five faults. */
    return null;
  }
  get eidExpiryReason() {
    return this.reasonText("eidExpiry", LABELS.IDF_REASON_EID_EXPIRED, null);
  }
  get passportIssueReason() {
    return this.reasonText("passportIssueDate", null, LABELS.IDF_REASON_ISSUE_FUTURE);
  }
  get passportExpiryReason() {
    return this.reasonText("passportExpiryDate", LABELS.IDF_REASON_PASSPORT_EXPIRED, null);
  }

  /* ── the one answer a save button needs, for imperative callers ─────────── */

  @api
  get valid() {
    return identitySetComplete(this.residentStatus, this.values, this.locked);
  }

  /* ── events ─────────────────────────────────────────────────────────────── */

  emit(field, value) {
    this.dispatchEvent(
      new CustomEvent("identitychange", { detail: { field, value } })
    );
  }

  handleEid(event) {
    /* The mask writes the element in place and returns what to store - see
       c/mscEoiUtils. Applied here so every screen stores the same shape. */
    this.emit("eidNumber", applyEmiratesIdMask(event.target));
  }
  handleField(event) {
    this.emit(event.currentTarget.dataset.f, event.target.value);
  }
}