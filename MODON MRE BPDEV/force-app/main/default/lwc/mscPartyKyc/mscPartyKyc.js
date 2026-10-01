/**
 * mscPartyKyc - the manual KYC route for one joint owner, inside the Add Joint Owner drawer.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 30 Sep 2026  The documents list says its files are needed before the person can be added
 *                                   (needed-for "adding", UI-28). Template only.
 * 1.0      Aurelix Dev 28 Sep 2026  New (MODON's Sales App has a manual KYC route for a
 *                                   person who is or will be a joint owner, so the console drawer gets the
 *                                   buyer's route too). MODON's JointOwnerTriggerHelper refuses a joint
 *                                   owner whose KYC is not complete and accepts a manual approval on the
 *                                   person's Account, exactly as the booking gate does for a buyer.
 *
 * NOTHING HERE IS A SECOND IMPLEMENTATION. It hosts the buyer's own pieces with the joint owner's
 * Account on them (party-account-id), in the order c/mscKycGate shows them:
 *   request     c/mscManualKyc      reason, comment, optional file -> MODON's submitForApproval
 *   waiting     KYCG_B_AWAITING     the request's own record (getPartyApprovalTrail) decides
 *   withdrawn   KYCG_B_WITHDRAWN    and the request is offered again
 *   approved    c/mscKycDocuments   the checklist with Upload on each row
 *               c/mscKycCapture     Update KYC (MODON's form, in the dialog the drawer hosts) and Generate
 *   rejected    c/mscKycCapture     who rejected it, when, and their comment; the request is offered again
 * Whether the person may be added is still MODON's check alone; the drawer's "Check again" asks it.
 *
 * EVENTS. `manualstate` {offer, approved} after every read, so the drawer can show its Manual KYC
 * button and drop Send KYC link once the manual route is approved (as c/mscKycGate 3.5 does).
 * `changed` whenever something on the route moved, so the drawer re-runs MODON's check. `openkyc`
 * from c/mscKycCapture passes through untouched (composed) for the drawer to host the dialog.
 */
import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { reduceError } from "c/modonSalesFormat";
import getPartyManualOutcome from "@salesforce/apex/AurelixManualKycService.getPartyManualOutcome";
import getPartyApprovalTrail from "@salesforce/apex/AurelixManualKycService.getPartyApprovalTrail";

const MANUAL_PENDING = ["submitted", "pending approval"];

/* the console's month names, as c/mscKycGate prints a withdrawal day */
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function localDay(v) {
  const d = v ? new Date(v) : null;
  if (!d || isNaN(d.getTime())) return "";
  return `${d.getDate()} ${SHORT_MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

export default class MscPartyKyc extends LightningElement {
  labels = LABELS;

  _opportunityId;
  _accountId;
  outcome;
  trail;
  busy = false;
  problem;
  docsListed;
  loadSeq = 0;
  _loadQueued = false;

  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(value) {
    this._opportunityId = value;
    this.scheduleLoad();
  }

  /** The joint owner's person Account. */
  @api
  get accountId() {
    return this._accountId;
  }
  set accountId(value) {
    if (value !== this._accountId) {
      this.outcome = undefined;
      this.trail = undefined;
      this.docsListed = undefined;
    }
    this._accountId = value;
    this.scheduleLoad();
  }

  /** The drawer's Manual KYC toggle: the request form shows only while it is open. */
  @api manualOpen = false;

  /** The drawer re-reads everything after the Update KYC dialog closes. */
  @api
  refresh(saved) {
    this.load();
    const docs = this.template.querySelector("c-msc-kyc-documents");
    if (docs && typeof docs.refresh === "function") {
      docs.refresh();
    }
    const capture = this.template.querySelector("c-msc-kyc-capture");
    if (capture && typeof capture.reload === "function") {
      capture.reload(saved === true);
    }
  }

  scheduleLoad() {
    if (this._loadQueued) return;
    this._loadQueued = true;
    Promise.resolve().then(() => {
      this._loadQueued = false;
      this.load();
    });
  }

  /** The outcome and the request's own record, together; only the newest read may write. */
  load() {
    const seq = ++this.loadSeq;
    if (!this._opportunityId || !this._accountId) {
      this.outcome = undefined;
      this.trail = undefined;
      return Promise.resolve();
    }
    const args = { opportunityId: this._opportunityId, accountId: this._accountId };
    const trail = getPartyApprovalTrail(args).catch(() => undefined);
    return Promise.all([getPartyManualOutcome(args), trail])
      .then(([outcome, t]) => {
        if (seq !== this.loadSeq) return;
        this.outcome = outcome;
        this.trail = t;
        this.problem = null;
        this.announce();
      })
      .catch((e) => {
        if (seq !== this.loadSeq) return;
        this.outcome = undefined;
        this.problem = reduceError(e);
        this.announce();
      });
  }

  /* ── where the manual route stands ─────────────────────────────────────── */

  get status() {
    const s = this.outcome && this.outcome.approvalStatus;
    return s ? String(s).trim().toLowerCase() : "";
  }

  /** none | awaiting | withdrawn | approved | rejected, one answer, as c/mscKycGate orders it. */
  get view() {
    if (!this.outcome) return null;
    if (MANUAL_PENDING.includes(this.status)) {
      return this.trail && this.trail.withdrawn ? "withdrawn" : "awaiting";
    }
    if (this.status === "approved") return "approved";
    if (this.status === "rejected") return "rejected";
    return "none";
  }

  /** A request may be written: nothing is waiting and nothing is approved. */
  get offer() {
    const v = this.view;
    return v === "none" || v === "rejected" || v === "withdrawn";
  }

  announce() {
    this.dispatchEvent(
      new CustomEvent("manualstate", {
        detail: { offer: this.offer === true, approved: this.view === "approved" }
      })
    );
  }

  get isAwaiting() {
    return this.view === "awaiting";
  }
  get isWithdrawn() {
    return this.view === "withdrawn";
  }
  get withdrawnLine() {
    const t = this.trail || {};
    return t.decidedAt
      ? this.labels.KYCG_B_WITHDRAWN.replace("{0}", localDay(t.decidedAt))
      : this.labels.KYCG_B_WITHDRAWN_NONE;
  }

  get showForm() {
    return this.manualOpen === true && this.offer;
  }

  /** The checklist once the manual route is approved, as for the buyer (c/mscKycGate 3.3). */
  get showDocuments() {
    return this.view === "approved";
  }

  /** The post-approval panel whenever a decision exists; it hides itself while one is pending. */
  get showCapture() {
    const v = this.view;
    return v === "approved" || v === "rejected";
  }

  /** Mounted checklist: what it drew, and TRUE until it answers (c/mscKycGate 3.12). */
  get documentsListed() {
    return this.showDocuments && this.docsListed !== false;
  }

  get show() {
    return !!this.view && (this.isAwaiting || this.isWithdrawn || this.showForm
      || this.showDocuments || this.showCapture || !!this.problem);
  }

  get refreshLabel() {
    return this.busy ? this.labels.KYCG_A_WORKING : this.labels.KYCG_A_REFRESH;
  }

  /* ── handlers ──────────────────────────────────────────────────────────── */

  handleRefresh() {
    if (this.busy) return;
    this.busy = true;
    this.load()
      .then(() => this.changed())
      .finally(() => {
        this.busy = false;
      });
  }

  handleSubmitted() {
    this.load().then(() => this.changed());
  }

  handleDocumentsList(event) {
    this.docsListed = !!(event.detail && event.detail.listed === true);
  }

  /** An upload: the post-approval panel re-reads (Generate may now be on), then the drawer's check. */
  handleDocumentsChanged() {
    const capture = this.template.querySelector("c-msc-kyc-capture");
    if (capture && typeof capture.reload === "function") {
      capture.reload(false);
    }
    this.changed();
  }

  /** Something in the capture panel moved (a save, a generation, a refresh). */
  handleCaptureChanged() {
    this.load();
    const docs = this.template.querySelector("c-msc-kyc-documents");
    if (docs && typeof docs.refresh === "function") {
      docs.refresh();
    }
    this.changed();
  }

  changed() {
    this.dispatchEvent(new CustomEvent("changed"));
  }
}