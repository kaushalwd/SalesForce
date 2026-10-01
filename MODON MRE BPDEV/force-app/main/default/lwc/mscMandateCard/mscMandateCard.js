/**
 * The direct-debit mandate card: where a UAEDDS mandate stands, what the bank said, the forms,
 * and the few things a rep may do about it.
 *
 * Version  Author      Date         Detail
 * 1.4      Aurelix Dev 21 Sep 2026  The footer said "Finance sends the draft to the bank.
 *                                   Collections start once the bank approves" on every mandate,
 *                                   including one the bank had already approved (DD-00435, seen
 *                                   21 Sep). It is a description of what happens next, so it is
 *                                   shown only while that is still ahead.
 * 1.3      Aurelix Dev 21 Sep 2026  Discard is never offered: MODON's action matrix keeps it with
 *                                   Finance. The card says where it is done instead.
 * 1.2      Aurelix Dev 20 Sep 2026  The "taken in Modon's app" note no longer counts refresh, so
 *                                   it cannot appear beside a Refresh button that works.
 * 1.1      Aurelix Dev 20 Sep 2026  A plain Refresh, always offered. 1.0 put every action behind
 *                                   DIRECT_DEBIT_ACTIONS because they all call the bank - but
 *                                   re-reading what Salesforce already holds is not a callout and
 *                                   needs no credential, and without it a rep could only see a
 *                                   mandate move by reloading the page. The bank call is
 *                                   still behind the switch and now says "Ask the bank now", so
 *                                   the two are never confused.
 * 1.0      Aurelix Dev 18 Sep 2026  SCW-125. Replaces c/mscDirectDebit's read-only "view" mode.
 *                                   Four steps (Raised · Finance · Customer signature · Bank),
 *                                   the stage line, the facts, the four PDFs as links, and the
 *                                   actions AurelixDirectDebitService says are legal now -
 *                                   drawn but disabled while DIRECT_DEBIT_ACTIONS is off. The
 *                                   card calls the service itself and raises `ddchanged` so the
 *                                   box reloads; `ddsetup` asks the host for the form again after
 *                                   a discarded / rejected / cancelled mandate; `ddcancel` hides.
 */
import { LightningElement, api, track } from "lwc";
import { formatAED, formatDate, reduceError } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";
import getSitePathPrefix from "@salesforce/apex/SalesConsoleController.getSitePathPrefix";
import refreshMandate from "@salesforce/apex/AurelixDirectDebitService.refresh";
import discardMandate from "@salesforce/apex/AurelixDirectDebitService.discard";
import fetchForm from "@salesforce/apex/AurelixDirectDebitService.fetchForm";
import requestCancellation from "@salesforce/apex/AurelixDirectDebitService.requestCancellation";
import getCard from "@salesforce/apex/AurelixDirectDebitService.getCard";
import cancellationReasons from "@salesforce/apex/AurelixDirectDebitService.cancellationReasons";

const STAGE_LABEL = {
  legacy: "DDC_STAGE_LEGACY",
  draft: "DDC_STAGE_DRAFT",
  financeRejected: "DDC_STAGE_FINANCE_REJECTED",
  pending: "DDC_STAGE_PENDING",
  sent: "DDC_STAGE_SENT",
  active: "DDC_STAGE_ACTIVE",
  bankRejected: "DDC_STAGE_BANK_REJECTED",
  discarded: "DDC_STAGE_DISCARDED",
  cancelPending: "DDC_STAGE_CANCEL_PENDING",
  cancelRequested: "DDC_STAGE_CANCEL_REQUESTED",
  cancelled: "DDC_STAGE_CANCELLED"
};

/* one muted colour per stage, only where it carries meaning */
const STAGE_TONE = {
  legacy: "chip--partial",
  draft: "chip--partial",
  financeRejected: "chip--alert",
  pending: "chip--pending",
  sent: "chip--pending",
  active: "chip--paid",
  bankRejected: "chip--alert",
  discarded: "chip--due",
  cancelPending: "chip--partial",
  cancelRequested: "chip--partial",
  cancelled: "chip--due"
};

const STEP_LABEL = {
  raised: "DDC_STEP_RAISED",
  finance: "DDC_STEP_FINANCE",
  signature: "DDC_STEP_SIGNATURE",
  bank: "DDC_STEP_BANK"
};

const DOC_LABEL = {
  unsigned: "DDC_DOC_UNSIGNED",
  signed: "DDC_DOC_SIGNED",
  cancelUnsigned: "DDC_DOC_CANCEL_UNSIGNED",
  cancelSigned: "DDC_DOC_CANCEL_SIGNED"
};

export default class MscMandateCard extends LightningElement {
  /** AurelixDirectDebitService.CardDTO */
  @api card;
  @api salesOrderId;
  /** SalesConsoleController.DdComputedDTO - today's milestone range for the covers line. */
  @api computed;
  @api busy = false;

  @track local;
  @track working = false;
  @track error;
  @track message;
  @track confirm = null; // 'discard' | 'cancel'
  @track readAt;
  @track cancelReason = "";
  @track cancelComment = "";
  reasons = [];
  sitePrefix = "";
  labels = LABELS;

  connectedCallback() {
    getSitePathPrefix()
      .then((p) => {
        this.sitePrefix = p || "";
      })
      .catch(() => {
        this.sitePrefix = "";
      });
    cancellationReasons()
      .then((r) => {
        this.reasons = r || [];
      })
      .catch(() => {
        this.reasons = [];
      });
  }

  /** The card the host passed, or the one an action just returned. */
  get c() {
    return this.local || this.card || {};
  }

  get hasMandate() {
    return !!this.c.mandateId;
  }

  get title() {
    return LABELS.DDC_TITLE.replace("{0}", this.c.name || "");
  }

  get requested() {
    return this.c.requestedOn ? LABELS.DD_VIEW_REQUESTED.replace("{0}", formatDate(this.c.requestedOn)) : null;
  }

  get chipClass() {
    return `chip ${STAGE_TONE[this.c.stage] || "chip--partial"}`;
  }

  get chipText() {
    const key = STAGE_LABEL[this.c.stage];
    return key ? LABELS[key] : this.c.stageLabel || "";
  }

  /** The one sentence under the chip. */
  get note() {
    const c = this.c;
    switch (c.stage) {
      case "legacy":
        return LABELS.DDC_NOTE_LEGACY;
      case "draft":
        return LABELS.DDC_NOTE_DRAFT;
      case "financeRejected":
        return c.rejectionReason || null;
      case "pending":
        return LABELS.DDC_NOTE_PENDING.replace("{0}", formatDate(c.sentToBankOn || c.approvedOn));
      case "sent":
        return LABELS.DDC_NOTE_SENT.replace("{0}", formatDate(c.signedOn));
      case "active":
        return c.cbReference
          ? LABELS.DDC_NOTE_ACTIVE.replace("{0}", c.cbReference)
          : LABELS.DDC_NOTE_ACTIVE.replace("Bank reference {0}. ", "");
      case "bankRejected":
        return c.bankStatusDescription || null;
      case "discarded":
        return LABELS.DDC_NOTE_DISCARDED.replace("{0}", formatDate(c.discardedOn || c.lastSyncOn));
      case "cancelPending":
        return LABELS.DDC_NOTE_CANCEL_PENDING.replace("{0}", c.cancellationReasonLabel || c.cancellationReasonCode || "");
      case "cancelRequested":
        return LABELS.DDC_NOTE_CANCEL_REQUESTED.replace("{0}", c.cancellationReasonLabel || c.cancellationReasonCode || "");
      case "cancelled":
        return LABELS.DDC_NOTE_CANCELLED;
      default:
        return null;
    }
  }

  get steps() {
    return (this.c.steps || []).map((s) => ({
      key: s.key,
      label: LABELS[STEP_LABEL[s.key]] || s.key,
      cls: `mc__st is-${s.state}`,
      markCls: `mc__st-mark is-${s.state}`,
      barCls: `mc__st-bar is-${s.state}`,
      fact: s.factOn ? formatDate(s.factOn) : "",
      done: s.state === "done"
    }));
  }

  get facts() {
    const c = this.c;
    const rows = [
      { k: "holder", label: LABELS.DD_FIELD_HOLDER, value: c.holderName },
      { k: "bank", label: LABELS.DD_FIELD_BANK, value: c.bank },
      { k: "type", label: LABELS.DD_FIELD_TYPE, value: c.accountType },
      { k: "iban", label: LABELS.DD_FIELD_IBAN, value: c.ibanMasked },
      { k: "idt", label: LABELS.DD_FIELD_ID_TYPE, value: c.idType },
      { k: "idn", label: LABELS.DD_FIELD_ID_NUMBER, value: c.idNumber },
      { k: "mob", label: LABELS.DD_FIELD_MOBILE, value: c.mobile },
      { k: "email", label: LABELS.DDC_FACT_EMAIL, value: c.email },
      { k: "city", label: LABELS.DDC_FACT_CITY, value: c.city },
      { k: "ref", label: LABELS.DDC_FACT_REFERENCE, value: c.cbReference },
      {
        k: "bs",
        label: LABELS.DDC_FACT_BANK_STATUS,
        value: c.bankStatusCode
          ? `${c.bankStatusCode}${c.bankStatusDescription ? " · " + c.bankStatusDescription : ""}`
          : null
      },
      { k: "sync", label: LABELS.DDC_FACT_SYNC, value: c.lastSyncOn ? formatDate(c.lastSyncOn) : null }
    ];
    return rows.filter((r) => !!r.value);
  }

  get covers() {
    const c = this.c;
    const r = this.computed;
    if (!r || !r.milestoneCount || !c.commencesOn) return null;
    return LABELS.DD_VIEW_COVERS.replace("{0}", r.firstMilestone)
      .replace("{1}", r.lastMilestone)
      .replace("{2}", formatAED(c.maximumAmount))
      .replace("{3}", formatDate(c.commencesOn))
      .replace("{4}", formatDate(c.expiresOn));
  }

  /**
   * 1.4 - DD_FOOT describes the road ahead: Finance sends the draft, then the bank approves, then
   * collections begin. Once the mandate is live, rejected, discarded or cancelled that road is
   * behind it, and the stage line above already says where it ended. The footer keeps carrying
   * "Last read" in every state.
   */
  get showFoot() {
    return ["none", "legacy", "draft", "pending", "sent"].includes(this.c.stage);
  }

  get problems() {
    return this.c.problems || [];
  }

  get hasProblems() {
    return this.problems.length > 0;
  }

  /* ── forms ─────────────────────────────────────────────────────────────── */

  get documents() {
    const c = this.c;
    const onFile = {};
    (c.documents || []).forEach((d) => {
      onFile[d.key] = d;
    });
    const a = c.actions || {};
    const rows = [
      { key: "unsigned", fetch: a.fetchUnsigned, signed: false },
      { key: "signed", fetch: a.fetchSigned, signed: true }
    ];
    if (onFile.cancelUnsigned || onFile.cancelSigned) {
      rows.push({ key: "cancelUnsigned", fetch: false }, { key: "cancelSigned", fetch: false });
    }
    return rows
      .map((r) => {
        const d = onFile[r.key];
        return {
          key: r.key,
          label: LABELS[DOC_LABEL[r.key]],
          url: d ? `${this.sitePrefix}/sfc/servlet.shepherd/document/download/${d.contentDocumentId}` : null,
          on: d ? formatDate(d.uploadedOn) : null,
          canFetch: !d && !!r.fetch && this.actionsEnabled,
          signed: r.signed === true
        };
      })
      .filter((r) => r.url || r.canFetch || r.key === "unsigned" || r.key === "signed");
  }

  /* ── actions ───────────────────────────────────────────────────────────── */

  get actionsEnabled() {
    const a = this.c.actions || {};
    return a.enabled === true;
  }

  /**
   * 1.2 - refresh is NOT in this list. Re-reading the record is always offered (handleReread),
   * so a note saying it happens somewhere else would contradict the button beside it. This asks
   * only about the actions that reach the bank and therefore need the credential.
   */
  get anyActionLegal() {
    const a = this.c.actions || {};
    return !!(a.requestCancellation || a.fetchUnsigned || a.fetchSigned);
  }

  /** Legal but switched off: say so once, quietly. */
  get actionsOffNote() {
    return this.anyActionLegal && !this.actionsEnabled ? LABELS.DDC_ACTIONS_OFF : null;
  }

  get showRefresh() {
    return this.actionsEnabled && !!(this.c.actions || {}).refresh;
  }
  /**
   * 1.3 - always false. MODON reserve discard for Finance (their action matrix, 20 Sep), so the
   * card names where it happens instead of drawing a button. Left as a getter rather than deleted
   * because the service still carries the capability if that decision changes.
   */
  get showDiscard() {
    return this.actionsEnabled && !!(this.c.actions || {}).discard;
  }

  /** 1.3 - a pending mandate Finance could withdraw; said once, not offered. */
  get discardIsFinances() {
    return !!(this.c.actions || {}).financeOnlyDiscard;
  }
  get showCancel() {
    return this.actionsEnabled && !!(this.c.actions || {}).requestCancellation;
  }
  get showSetupAgain() {
    return !!(this.c.actions || {}).setUpAgain;
  }

  get disabled() {
    return this.busy || this.working;
  }

  /** 1.1 - when Salesforce last told us, so "nothing changed" is distinguishable from "stale". */
  get lastRead() {
    return this.readAt ? LABELS.DDC_REREAD_HINT.replace("{0}", this.readAt) : null;
  }

  get confirmingDiscard() {
    return this.confirm === "discard";
  }
  get confirmingCancel() {
    return this.confirm === "cancel";
  }

  get reasonChoices() {
    return (this.reasons || []).map((o) => ({ ...o, selected: o.value === this.cancelReason }));
  }

  get cancelDisabled() {
    return this.disabled || !this.cancelReason;
  }

  handleReason(event) {
    this.cancelReason = event.target.value;
  }
  handleComment(event) {
    this.cancelComment = event.target.value;
  }

  handleHide() {
    this.dispatchEvent(new CustomEvent("ddcancel"));
  }

  handleSetupAgain() {
    this.dispatchEvent(new CustomEvent("ddsetup"));
  }

  /**
   * 1.1 - re-read, not re-ask. This fetches what Salesforce already holds: whatever Finance did
   * in Modon's app, and whatever the nightly poll brought back from the bank. It makes no
   * callout and needs no credential, so it is offered to everyone, always - without it the only
   * way to see a mandate move was to reload the whole page, which is how testing found it.
   */
  handleReread() {
    this.run(() => getCard({ salesOrderId: this.salesOrderId }));
  }

  /** The callout: asks UAEDDS for a status newer than the one Salesforce holds. */
  handleRefresh() {
    this.run(() => refreshMandate({ mandateId: this.c.mandateId }));
  }

  handleFetch(event) {
    const signed = event.currentTarget.dataset.signed === "true";
    this.run(() => fetchForm({ mandateId: this.c.mandateId, signed }));
  }

  handleAskDiscard() {
    this.confirm = "discard";
    this.error = undefined;
  }
  handleAskCancel() {
    this.confirm = "cancel";
    this.error = undefined;
  }
  handleBack() {
    this.confirm = null;
  }

  handleDiscard() {
    this.run(() => discardMandate({ mandateId: this.c.mandateId }));
  }

  handleCancel() {
    if (!this.cancelReason) return;
    this.run(() =>
      requestCancellation({
        mandateId: this.c.mandateId,
        reasonCode: this.cancelReason,
        comment: this.cancelComment
      })
    );
  }

  async run(call) {
    this.working = true;
    this.error = undefined;
    this.message = undefined;
    try {
      const card = await call();
      this.local = card;
      this.readAt = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      this.confirm = null;
      this.message = card && card.message;
      this.dispatchEvent(
        new CustomEvent("ddchanged", { detail: { salesOrderId: this.salesOrderId, card } })
      );
    } catch (e) {
      this.error = reduceError(e);
    } finally {
      this.working = false;
    }
  }
}