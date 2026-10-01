/**
 * Direct debit mandate - the form.
 *
 * Version  Author            Date         Detail
 * 3.4      Aurelix Dev       30 Sep 2026  Every failing MODON check shows under its field (two on one field both
 *                                         show), and the count above says how many messages are on screen.
 * 3.3      Aurelix Dev       29 Sep 2026  A failing MODON check shows under its field even when the rep has not
 *                                         touched it (e.g. the prefilled account name). The console's own
 *                                         "required" lines still wait for a touch.
 * 3.2      Aurelix Dev       22 Sep 2026  The bank is UAEDDSBankName__c, the field MODON's capture and payload read
 *                                         since UAEDDS_LWCController 2.2: the list comes from that picklist
 *                                         (SalesConsoleController 1.73), the live check sends it under that
 *                                         name, and a rule about it lands on the bank line. A company paying
 *                                         from the Sales Order's Primary Contact (prefill.payerIsContact,
 *                                         MODON's answer to D7) is asked for an Emirates ID, not a trade
 *                                         licence. Previous version: _backup/2026-09-22_081155 (WL-019).
 * 3.1      Aurelix Dev       21 Sep 2026  Native selects again (21 Sep). Withdrawn: the same
 *                                         day's change that made bank, account type and ID type
 *                                         c/mscPicklist to avoid a grey pop-up that only a Linux
 *                                         desktop shows (SCW-137).
 * 3.0      Aurelix Dev       18 Sep 2026  SCW-125. Re-based on MODON's UAEDDS capture. Two more
 *                                   fields (e-mail, city) because the mandate carries them to the
 *                                   bank; the id type is fixed by the customer type (Emirates ID
 *                                   for a person, trade licence for a company) rather than chosen;
 *                                   the mobile is shown normalised to 05XXXXXXXX on blur (MODON's
 *                                   rule); MODON's own 13 vendor rules run live through
 *                                   AurelixDirectDebitService.checkDraft and a failing rule is
 *                                   shown under the field it names. The read-only "view" mode is
 *                                   gone - c/mscMandateCard draws the mandate now. The submit
 *                                   raises a Draft for Finance (SalesConsoleController 1.68).
 * 2.0      Aurelix Developer 18 Aug 2026  Re-cut for the milestone box (c/mscObligations 1.9).
 * 1.1      Aurelix IT        12 Aug 2026  autocomplete="off".
 * 1.0      Aurelix IT        05 Aug 2026  Initial.
 */

import { LightningElement, api, track } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import checkDraft from "@salesforce/apex/AurelixDirectDebitService.checkDraft";

const IBAN = /^AE\d{21}$/i;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UAE_MOBILE = /^05\d{8}$/;
const ID_TYPE_EID = "UAE Emirates Identity Card";
const ID_TYPE_LICENCE = "Trade Licence Number";
const CHECK_DELAY = 500;

/** MODON's rule: +971… and 971… become 05…; a bare 5XXXXXXXX gains its 0. */
function normaliseMobile(raw) {
  let v = String(raw || "").replace(/[\s\-().]/g, "");
  if (!v) return "";
  if (v.startsWith("+971")) v = "0" + v.slice(4);
  else if (v.startsWith("00971")) v = "0" + v.slice(5);
  else if (v.startsWith("971") && v.length >= 12) v = "0" + v.slice(3);
  else if (v.length === 9 && v.startsWith("5")) v = "0" + v;
  return v;
}

/* the form field each of MODON's rules is about (Rule.field is the API name) */
const FIELD_OF = {
  Customer_Mobile__c: "mobile",
  Customer_IBAN_Number__c: "iban",
  Customer_Email__c: "email",
  Customer_City__c: "city",
  Customer_Bank_Account_Name__c: "accountName",
  CustomerAccountName__c: "accountName",
  Customer_Bank_Name__c: "bankName",
  UAEDDSBankName__c: "bankName",
  Customer_Bank_Account_Type__c: "accountType",
  Customer_Id_Type__c: "idType",
  Customer_ID_Number__c: "idNumber"
};

export default class MscDirectDebit extends LightningElement {
  /** SalesConsoleController.DirectDebitStateDTO (unused by the form; kept for the host) */
  @api state;
  @api salesOrderId;
  /** SalesConsoleController.OptionDTO[] - DirectDebitRequest__c.UAEDDSBankName__c */
  @api bankOptions = [];
  /** OptionDTO[] - Customer_Bank_Account_Type__c */
  @api accountTypes = [];
  /** OptionDTO[] - Customer_Id_Type__c (only the one for this customer type is offered) */
  @api idTypes = [];
  /** SalesConsoleController.DdPrefillDTO */
  @api prefill;
  /** SalesConsoleController.DdComputedDTO - what the saved mandate will carry. */
  @api computed;
  @api busy = false;
  /** kept for the host; the form is the only mode now */
  @api mode = "form";

  @track form = {
    accountName: "",
    bankName: "",
    accountType: "",
    iban: "",
    idType: "",
    idNumber: "",
    mobile: "",
    email: "",
    city: ""
  };
  @track touched = {};
  /** MODON's rules, last answer */
  @track rules = null;
  @track checking = false;
  @track checkFailed = false;
  seeded = false;
  _timer;
  _seq = 0;

  labels = LABELS;

  connectedCallback() {
    this.seed();
  }

  renderedCallback() {
    this.seed();
  }

  /** Once, from the Account - the rep edits from there. */
  seed() {
    if (this.seeded || !this.prefill) return;
    const p = this.prefill;
    this.form = {
      ...this.form,
      accountName: p.holderName || "",
      bankName: p.bankName || "",
      iban: p.iban || "",
      idType: p.idType || (this.paysWithEid ? ID_TYPE_EID : ID_TYPE_LICENCE),
      idNumber: p.idNumber || "",
      mobile: normaliseMobile(p.mobile) || "",
      email: p.email || "",
      city: p.city || ""
    };
    this.seeded = true;
    this.scheduleCheck();
  }

  get isPerson() {
    return !this.prefill || this.prefill.isPersonAccount !== false;
  }

  /** 3.2: a person, or a company paying from its Primary Contact, pays with an Emirates ID. */
  get paysWithEid() {
    return this.isPerson || !!(this.prefill && this.prefill.payerIsContact);
  }

  /* ── the computed line ─────────────────────────────────────────────────── */

  get range() {
    const c = this.computed;
    if (!c || !c.milestoneCount) return null;
    return { first: c.firstMilestone, last: c.lastMilestone };
  }

  get title() {
    const r = this.range;
    if (!r) return LABELS.DD_TITLE.replace("{0}", "").replace("{1}", "");
    if (r.first === r.last) return LABELS.DD_TITLE_ONE.replace("{0}", r.first);
    return LABELS.DD_TITLE.replace("{0}", r.first).replace("{1}", r.last);
  }

  get computedLine() {
    const c = this.computed;
    const r = this.range;
    if (!c || !r) return null;
    if (r.first === r.last) {
      return LABELS.DD_COMPUTED_ONE.replace("{0}", r.first)
        .replace("{1}", formatAED(c.maximumAmount))
        .replace("{2}", formatDate(c.commencesOn))
        .replace("{3}", formatDate(c.expiresOn));
    }
    return LABELS.DD_COMPUTED.replace("{0}", r.first)
      .replace("{1}", r.last)
      .replace("{2}", formatAED(c.maximumAmount))
      .replace("{3}", formatDate(c.commencesOn))
      .replace("{4}", formatDate(c.expiresOn));
  }

  /* ── the form ──────────────────────────────────────────────────────────── */

  get bankChoices() {
    return (this.bankOptions || []).map((o) => ({ ...o, selected: o.value === this.form.bankName }));
  }
  get typeChoices() {
    return (this.accountTypes || []).map((o) => ({ ...o, selected: o.value === this.form.accountType }));
  }
  /** One id type per payer: an Emirates ID for a person or a company's Primary Contact, else the licence. */
  get idTypeChoices() {
    const want = this.paysWithEid ? ID_TYPE_EID : ID_TYPE_LICENCE;
    const all = this.idTypes || [];
    const only = all.filter((o) => o.value === want);
    return (only.length ? only : all).map((o) => ({ ...o, selected: o.value === this.form.idType }));
  }

  get idNumberLabel() {
    return this.paysWithEid ? LABELS.DD_FIELD_ID_NUMBER + " (Emirates ID)" : LABELS.DD_FIELD_ID_NUMBER;
  }

  /** The console's own checks; MODON's run beside them. */
  get errors() {
    const f = this.form;
    const req = (v) => (String(v || "").trim() ? "" : LABELS.DD_REQUIRED);
    const mobile = normaliseMobile(f.mobile);
    return {
      accountName: req(f.accountName),
      bankName: req(f.bankName),
      accountType: req(f.accountType),
      // A UAE IBAN is AE + 21 digits. Checked here because a malformed mandate is
      // rejected by the bank days later, long after the rep has moved on.
      iban: !String(f.iban || "").trim()
        ? LABELS.DD_REQUIRED
        : IBAN.test(String(f.iban).replace(/\s/g, ""))
          ? ""
          : LABELS.DD_IBAN_INVALID,
      idType: req(f.idType),
      idNumber: req(f.idNumber),
      mobile: !mobile ? LABELS.DD_REQUIRED : UAE_MOBILE.test(mobile) ? "" : LABELS.DD_MOBILE_HINT,
      email: !String(f.email || "").trim()
        ? LABELS.DD_REQUIRED
        : EMAIL.test(String(f.email).trim())
          ? ""
          : LABELS.DD_EMAIL_INVALID,
      city: req(f.city)
    };
  }

  /** MODON's failing rules, keyed by the form field they name. 3.4: every distinct message, not the first. */
  get ruleErrors() {
    const out = {};
    (this.rules || []).forEach((r) => {
      if (r.passed) return;
      const f = FIELD_OF[r.field];
      if (!f) return;
      const text = (r.problems && r.problems.length ? r.problems.join(" ") : r.detail) || r.label;
      if (!text) return;
      out[f] = out[f] || [];
      if (out[f].indexOf(text) === -1) out[f].push(text);
    });
    return out;
  }

  /** 3.4: the field's own error when it shows one, else MODON's messages for it. */
  fieldMessage(f) {
    const own = this.touched[f] ? this.errors[f] : "";
    if (own) return { text: own, modon: 0 };
    const list = this.ruleErrors[f] || [];
    return { text: list.join(" "), modon: list.length };
  }

  /** 3.4: how many of MODON's messages are on screen: under the fields and in the list below. */
  get shownRuleCount() {
    const fieldCount = Object.keys(FIELD_OF)
      .map((k) => FIELD_OF[k])
      .filter((f, i, all) => all.indexOf(f) === i)
      .reduce((n, f) => n + this.fieldMessage(f).modon, 0);
    return fieldCount + this.otherRuleErrors.length;
  }

  /** Failing rules that name no field, or one this form does not hold. */
  get otherRuleErrors() {
    return (this.rules || [])
      .filter((r) => !r.passed && !FIELD_OF[r.field])
      .map((r) => ({
        key: r.label,
        text: `${r.label}${r.detail ? " · " + r.detail : ""}${
          r.problems && r.problems.length ? " · " + r.problems.join(" ") : ""
        }`
      }));
  }

  get failingRuleCount() {
    return (this.rules || []).filter((r) => !r.passed).length;
  }

  get rulesLine() {
    if (this.checking) return LABELS.DD_RULES_CHECKING;
    if (this.checkFailed) return LABELS.DD_RULES_UNAVAILABLE;
    if (!this.rules) return null;
    if (!this.failingRuleCount) return LABELS.DD_RULES_OK;
    /* 3.4: counted from what is shown, so the number matches the messages on screen; none shown
       means the field's own error is in the way and says enough */
    const n = this.shownRuleCount;
    if (!n) return null;
    /* the ones a field can show are shown there; the rest are listed under this line */
    return (this.otherRuleErrors.length ? LABELS.DD_RULES_FAILING_OTHER : LABELS.DD_RULES_FAILING).replace("{0}", n);
  }

  get rulesLineClass() {
    return this.rules && !this.checking && !this.checkFailed && this.failingRuleCount === 0
      ? "dd__rules dd__rules--ok"
      : "dd__rules";
  }

  get fields() {
    /* 3.3 - MODON's failing checks show at once, even on an untouched prefilled field */
    const show = (f) => this.fieldMessage(f).text;
    const mk = (f, kind) => ({
      error: show(f),
      cls: `${kind === "select" ? "dd__sel" : "dd__in"}${show(f) ? " dd__in--bad" : ""}`
    });
    return {
      accountName: mk("accountName"),
      bankName: mk("bankName", "select"),
      accountType: mk("accountType", "select"),
      iban: mk("iban"),
      idType: mk("idType", "select"),
      idNumber: mk("idNumber"),
      mobile: mk("mobile"),
      email: mk("email"),
      city: mk("city")
    };
  }

  get submitDisabled() {
    const e = this.errors;
    return this.busy || this.checking || Object.keys(e).some((k) => !!e[k]) || this.failingRuleCount > 0;
  }

  get submitLabel() {
    return this.busy ? LABELS.CTA_SUBMITTING_MANDATE : LABELS.CTA_SUBMIT_MANDATE;
  }

  handleField(event) {
    this.form = { ...this.form, [event.target.dataset.field]: event.target.value };
    this.scheduleCheck();
  }

  handleBlur(event) {
    const f = event.target.dataset.field;
    this.touched = { ...this.touched, [f]: true };
    if (f === "mobile") {
      const v = normaliseMobile(this.form.mobile);
      if (v && v !== this.form.mobile) {
        this.form = { ...this.form, mobile: v };
        this.scheduleCheck();
      }
    }
  }

  /** MODON's rules, debounced, latest answer wins. */
  scheduleCheck() {
    if (!this.salesOrderId) return;
    clearTimeout(this._timer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._timer = setTimeout(() => this.check(), CHECK_DELAY);
  }

  async check() {
    const seq = ++this._seq;
    const f = this.form;
    const draft = {
      Customer_Bank_Account_Name__c: f.accountName,
      CustomerAccountName__c: f.accountName,
      UAEDDSBankName__c: f.bankName,
      Customer_Bank_Account_Type__c: f.accountType,
      Customer_IBAN_Number__c: String(f.iban || "").replace(/\s/g, "").toUpperCase(),
      Customer_Id_Type__c: f.idType,
      Customer_ID_Number__c: f.idNumber,
      Customer_Mobile__c: normaliseMobile(f.mobile),
      Customer_Email__c: f.email,
      Customer_City__c: f.city
    };
    this.checking = true;
    try {
      const rules = await checkDraft({ salesOrderId: this.salesOrderId, draftJson: JSON.stringify(draft) });
      if (seq !== this._seq) return;
      this.rules = rules || [];
      this.checkFailed = false;
    } catch (e) {
      if (seq !== this._seq) return;
      this.rules = null;
      this.checkFailed = true;
    } finally {
      if (seq === this._seq) this.checking = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("ddcancel"));
  }

  handleSubmit() {
    this.touched = {
      accountName: true, bankName: true, accountType: true, iban: true,
      idType: true, idNumber: true, mobile: true, email: true, city: true
    };
    if (this.submitDisabled) return;
    this.dispatchEvent(
      new CustomEvent("ddcreate", {
        detail: {
          accountName: this.form.accountName.trim(),
          bankName: this.form.bankName,
          accountType: this.form.accountType,
          iban: String(this.form.iban).replace(/\s/g, "").toUpperCase(),
          idType: this.form.idType,
          idNumber: this.form.idNumber.trim(),
          mobile: normaliseMobile(this.form.mobile),
          email: this.form.email.trim(),
          city: this.form.city.trim()
        }
      })
    );
  }
}