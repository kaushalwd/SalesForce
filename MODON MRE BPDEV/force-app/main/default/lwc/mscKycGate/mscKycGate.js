/**
 * mscKycGate - the console's pre-booking KYC workspace.
 *
 * Version  Author      Date         Detail
 * 3.15     Aurelix Dev 30 Sep 2026  Refresh adds no "Status checked." line (R2-12); "needed before payment" only while
 *                                   the gate is on (R2-18); Manual KYC looks like a button, refusals in muted text (R2-15).
 * 3.14     Aurelix Dev 29 Sep 2026  MODON's KYC refusal is shown as checkKYCEligibility returns it (no debrand;
 *                                   cannotSendReason still is). A company whose primary contact is KYC Active or
 *                                   manually approved no longer shows why the link cannot be sent.
 * 3.13     Aurelix Dev 29 Sep 2026  Comments only. AurelixKycEligibilityService 2.9 treats the primary contact as
 *                                   the POA, so hasAuthorisedPoa is true once a company has a primary contact.
 * 3.12     Aurelix Dev 24 Sep 2026  THE FLAG 3.11 ADDED WAS NOT HONEST. documents-listed was wired to
 *                                   showDocuments, which says the checklist is MOUNTED, not that it drew
 *                                   a list of names. c/mscKycDocuments renders a short blocked line and no
 *                                   rows when its own checklist DTO comes back unavailable, and a header
 *                                   with no rows when there are none, so the flag said "the names are
 *                                   listed above" while nothing named them: the capture panel suppressed
 *                                   its "Files to upload:" list and the missing file names appeared in NO
 *                                   place at all. The checklist now reports what it actually drew
 *                                   (`liststate`, c/mscKycDocuments 1.2) and THAT is what travels down.
 *                                   TIMING. With no checklist mounted the flag is false at once - there is
 *                                   nothing to wait for. With one mounted but not yet answered the flag is
 *                                   held TRUE, so the only movement the rep can ever see is the names
 *                                   ARRIVING, one round trip late, in the rare case the checklist fails.
 *                                   The panel can never print them and then take them away, which would
 *                                   read as a fault. Nothing else moved, and this still gates nothing.
 * 3.11     Aurelix Dev 24 Sep 2026  html only: documents-listed passed down to c/mscKycCapture, wired to
 *                                   showDocuments. The capture panel had no way to know whether the
 *                                   required documents checklist was rendered above it, so where it was,
 *                                   the same three file names appeared twice - once with Upload buttons in
 *                                   the checklist and once as plain text under the panel's "Files to
 *                                   upload:". The panel now suppresses its own list when
 *                                   the checklist is showing and keeps it when it is not, which happens
 *                                   whenever showDocuments is false: a verified or awaiting view, and a
 *                                   view becomes verified once a manually approved buyer has the four
 *                                   files on record. No logic moved out of this component.
 * 3.10     Aurelix Dev 21 Sep 2026  The manual states (pending, withdrawn) show only their sentence,
 *                                   the actions and the digital link row. No status word, no "Buyer" line,
 *                                   no "Sent ... to ..." line. Refresh is always offered there, because it
 *                                   is how the rep sees an approval land. With no digital journey to poll,
 *                                   it re-reads the verdict and the request here without calling
 *                                   refreshComplianceState (SCW-142).
 * 3.9      Aurelix Dev 21 Sep 2026  Pending reads "Waiting for manual KYC approval." with "Sent
 *                                   <day> to <approvers>" beneath it. In the two manual states (pending,
 *                                   withdrawn) the digital link's Send / Resend leave the shared action row
 *                                   for a row of their own, labelled "Digital KYC link" with the link's
 *                                   state, so Resend is not read as re-sending the approval. Other states
 *                                   are about the link already and keep one row (SCW-141).
 * 3.8      Aurelix Dev 21 Sep 2026  The manual request reads from the request itself
 *                                   (AurelixManualKycService.getApprovalTrail), not from the account
 *                                   field alone. Pending: "Pending approval - Sent for approval <day> -
 *                                   <approvers>" (it said "With compliance", which is a different, later
 *                                   step). WITHDRAWN, a new view: the field still says Submitted but no
 *                                   request is waiting - MODON's approval process has no recall action -
 *                                   so the box says so and offers the manual request again, where it
 *                                   used to show "pending" for ever with no way forward (test test2).
 *                                   Resend reads "Resend link". Refresh and Resend also re-read the
 *                                   request and the manual panel below (SCW-139).
 * 3.7      Aurelix Dev 20 Sep 2026  The manual route read as an accident beside Send KYC -
 *                                   11px against 12px, the only underline on the panel, and no
 *                                   padding to aim at. It is now a button of the same family on the
 *                                   same row, carrying its lesser weight in the border and the
 *                                   colour rather than in the type size. hasActionRow keeps the row
 *                                   when the manual route is the only thing offered; showManualForm
 *                                   holds the request form below, where it was.
 * 3.6      Aurelix Dev 18 Sep 2026  Seen in testing: after the last upload, Generate stayed off until
 *                                   Refresh. An upload now re-reads the post-approval panel as well
 *                                   as the verdict (handleDocumentsChanged → capture.reload).
 * 3.5      Aurelix Dev 18 Sep 2026  Send KYC / Resend are no longer offered once the manual route is
 *                                   approved - the Signzy link has no purpose on that route (seen
 *                                   in a testing screenshot beside the approved checklist).
 * 3.4      Aurelix Dev 18 Sep 2026  Seen in testing: after the approval, Refresh flashed the manual
 *                                   request form (reason picklist) before the approved panel. Two
 *                                   causes: the form stayed flagged open after Submit, and an
 *                                   approved route still counted as one that may be requested.
 *                                   Submit now closes the request; an approved (or approved-and-
 *                                   generated) route offers no request at all.
 * 3.3      Aurelix Dev 18 Sep 2026  The manual route is approval FIRST - reason and comment
 *                                   are submitted, Sales Operations approve, and only then is the
 *                                   manual KYC (documents, details, form) allowed. The checklist
 *                                   therefore appears only once the manual approval is Approved,
 *                                   or on the in-branch / files-missing cases - never while the
 *                                   request is being written or is with compliance.
 * 3.2      Aurelix Dev 18 Sep 2026  Seen in testing: the documents checklist showed for every
 *                                   unverified customer, but on the DIGITAL route the rep uploads
 *                                   nothing - MODON's Signzy callback (CustomerKYCHandler) files
 *                                   the Emirates ID images, the passport and the signed form onto
 *                                   the rows itself. The list is now shown only where a rep is the
 *                                   one collecting: the manual route is open or on record, the
 *                                   link was released to the branch, or the digital check finished
 *                                   with files still missing. Not started / waiting / link expired
 *                                   show the verdict alone. The server's file check is unchanged.
 * 3.1      Aurelix Dev 18 Sep 2026  refresh(saved) for c/mscBookingPage, which now hosts the Update
 *                                   KYC dialog (the `openkyc` event passes through here composed).
 * 3.0      Aurelix Dev 18 Sep 2026  MSC-175 / MSC-180 (B5 + B10).
 *                                   B5 - the required-documents checklist (c/mscKycDocuments) is
 *                                   mounted under the verdict for every customer who is not yet
 *                                   verified or awaiting compliance: the rows the gate tests, with
 *                                   a tick per file and Upload on each. Its `changed` event
 *                                   re-runs the verdict here, so an upload moves the missing list
 *                                   and, with the gate on, the Continue control.
 *                                   B10 - the Opportunity is never exposed to a representative:
 *                                   MODON's own blocker sentences that say "Opportunity" are
 *                                   re-worded in this layer to "booking" before display
 *                                   (debrand). The server's meaning is kept; only the word goes.
 * 2.1      Aurelix Dev 08 Sep 2026  SC-UI-007 / SC-UI-008, both found in the browser.
 *                                   SC-UI-007: a company with NO Power of Attorney was labelled
 *                                   "POA - <contact>" directly above a sentence saying no
 *                                   authorised signatory exists. The role line is now shown only
 *                                   when MODON actually resolved a signatory; otherwise it is
 *                                   omitted rather than guessed at.
 *                                   SC-UI-008: an APPROVED manual KYC headlined "Not started",
 *                                   because the headline read the digital link state alone, while
 *                                   the panel below it said "Signed form received". The manual
 *                                   route now outranks the digital state - it is the route this
 *                                   customer is actually on. Eligibility is unchanged: this
 *                                   reorders what is SAID, never what is decided.
 * 1.0      Aurelix Dev 07 Sep 2026  Phase 2. Read-only. Rendered the verdict from
 *                                   AurelixKycEligibilityService and offered no action.
 * 2.0      Aurelix Dev 07 Sep 2026  Phase 3. THE ACTIVE KYC SURFACE MOVES HERE. Primary-buyer
 *                                   and POA identity verification is now DONE in step 2, where
 *                                   the rep and the customer are still together, instead of
 *                                   after the booking. Verification keeps a read-only track of
 *                                   the same subject; joint owners stay actionable there.
 *                                   STILL BLOCKS NOTHING - both hard gates are false.
 *
 * THE INTERACTION MOVED, THE ENGINE DID NOT.
 * Every action below calls a method the console ALREADY had, on the same backend the
 * Verification step drives:
 *
 *   Send / Resend   SalesConsoleController.sendCustomerVerification(oppId, primaryUnitId)
 *                     -> SalesConsoleVerificationService.stampUnitContext  (names the unit
 *                        on the customer's form BEFORE the send - ordering is load-bearing)
 *                     -> SalesConsoleVerificationService.enqueueSend(Account Id)
 *                     -> SendKycLinkJob -> CustomerKYCHandler.sendKYCForm(Account Id)
 *   Refresh         SalesConsoleController.refreshComplianceState(oppId)
 *   State           SalesConsoleController.getComplianceState(oppId)
 *
 * There is no second KYC implementation in here, no new Apex, and no local KYC arithmetic.
 *
 * WHY ONE ACCOUNT ID SERVES BOTH BUYER TYPES.
 * The console passes Opportunity.AccountId and MODON's sendKYCForm decides the subject:
 * for a person it uses Account.PersonContactId; for an 'Organization Account' it reads
 * Power_of_Attorney__c where Organization_Account__c = that account and verifies
 * poa.Contact__c. So a company's KYC subject is ALWAYS the authorised POA Contact, resolved
 * by MODON, not by us. getComplianceState returns that person's own link state as the
 * `signatory` track. This panel therefore names the POA and shows the POA's state, and the
 * button it offers targets exactly the contact MODON would have chosen.
 *
 * THE BROWSER NEVER DECIDES ELIGIBILITY.
 * The verdict is still AurelixKycEligibilityService's alone. What this component adds is the
 * digital journey's state and the controls - never a second opinion about whether the
 * customer is verified.
 *
 * FAILURE STAYS SILENT, ON PURPOSE.
 * If the verdict call fails the panel renders nothing and the journey continues, exactly as
 * in Phase 2. If only the compliance call fails, the verdict still renders and the actions
 * are simply absent: a booking must never be lost to a status panel.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";
import { formatDate, formatTime, reduceError } from "c/modonSalesFormat";
import evaluate from "@salesforce/apex/AurelixKycEligibilityService.evaluate";
import getComplianceState from "@salesforce/apex/SalesConsoleController.getComplianceState";
import sendCustomerVerification from "@salesforce/apex/SalesConsoleController.sendCustomerVerification";
import refreshComplianceState from "@salesforce/apex/SalesConsoleController.refreshComplianceState";
import getApprovalTrail from "@salesforce/apex/AurelixManualKycService.getApprovalTrail";

/* A Datetime's LOCAL calendar day, "18 Sep 2026". formatDate reads the UTC day - right for a Date,
   a day early for a request sent late in the evening in Abu Dhabi. The month names are the console's
   own: toLocaleDateString gave "Sept" in Chrome. */
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function localDay(v) {
  const d = v ? new Date(v) : null;
  if (!d || isNaN(d.getTime())) return "";
  return `${d.getDate()} ${SHORT_MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

/* Manual routes that are still with Sales Operations rather than decided. */
const MANUAL_PENDING = ["Submitted", "Pending Approval"];

/* 3.0 - B10: the engine's vocabulary, never the representative's. 3.14: the link's refusal only; MODON's
   KYC verdict is shown in its own words. */
const debrand = (text) =>
  typeof text === "string"
    ? text
        .replace(/\bthis Opportunity\b/g, "this booking")
        .replace(/\bthe Opportunity\b/g, "the booking")
        .replace(/\bOpportunity\b/g, "booking")
    : text;

/* SalesConsoleVerificationService's own vocabulary. Mirrored, not invented. */
const NOT_SENT = "NOT_SENT";
const SENDING = "SENDING";
const SENT = "SENT";
const EXPIRED = "EXPIRED";
const IN_BRANCH = "IN_BRANCH";

export default class MscKycGate extends LightningElement {
  labels = LABELS;

  dto;
  compliance;
  /** 3.8 - the manual request's own record: sent when, waiting on whom, or withdrawn. */
  trail;
  failed = false;
  busy = false;
  notice;
  problem;

  _opportunityId;

  /** Re-evaluates whenever the journey changes which Opportunity it is on. */
  @api
  get opportunityId() {
    return this._opportunityId;
  }
  set opportunityId(value) {
    this._opportunityId = value;
    this.load();
  }

  /**
   * The unit the customer is verifying against. Passed straight through to
   * sendCustomerVerification, which stamps it on the customer's form before the send so the
   * email names the unit instead of arriving blank. Optional: a missing unit costs the
   * context, never the send.
   */
  @api primaryUnitId;

  /* ── loading ─────────────────────────────────────────────────────────────── */

  load() {
    const oppId = this._opportunityId;
    if (!oppId) {
      this.dto = undefined;
      this.compliance = undefined;
      this.trail = undefined;
      return;
    }
    evaluate({ opportunityId: oppId })
      .then((result) => {
        this.dto = result;
        this.failed = false;
        this.announce();
      })
      .catch(() => {
        /* See the header: advisory panels do not get to break the journey. Phase 4 note: this
           silence is a UI convenience only. The server refuses independently, and it fails
           CLOSED - so a panel that could not load never lets money through. */
        this.dto = undefined;
        this.failed = true;
        this.announce();
      });
    this.loadCompliance(oppId);
    this.loadTrail(oppId);
  }

  /* 3.8 - silent on failure like the compliance call: the box then falls back to the field */
  loadTrail(oppId) {
    getApprovalTrail({ opportunityId: oppId })
      .then((trail) => {
        this.trail = trail;
      })
      .catch(() => {
        this.trail = undefined;
      });
  }

  loadCompliance(oppId) {
    getComplianceState({ opportunityId: oppId })
      .then((state) => {
        this.compliance = state;
      })
      .catch(() => {
        /* The verdict still renders; the actions simply are not offered. */
        this.compliance = undefined;
      });
  }

  /* ── who is being verified ───────────────────────────────────────────────── */

  get isOrganisation() {
    return this.dto && this.dto.customerType === "Organisation";
  }

  /**
   * The POA's name comes from getComplianceState's signatory track, because that is read from
   * the very contact MODON's send targets. The Phase 1 verdict's name is the fallback.
   */
  /**
   * Does this company booking have its Power of Attorney?
   *
   * This asks the ELIGIBILITY service, not getComplianceState. 3.13: since the service's 2.9 the
   * answer is "a primary contact is set", so the `signatory` track (that contact) is the right name.
   */
  get hasAuthorisedPoa() {
    return !!(this.dto && this.dto.hasAuthorisedPoa === true);
  }

  /**
   * The two calls land independently - the verdict can arrive before getComplianceState has
   * returned - so the signatory name is read defensively. Reading it unguarded threw
   * "Cannot read properties of undefined" on first paint for a company WITH a POA.
   */
  get subjectName() {
    const track =
      this.compliance && this.compliance.signatory ? this.compliance.signatory : null;
    const signatory = this.hasAuthorisedPoa && track ? track.name : null;
    if (this.isOrganisation) {
      return signatory;
    }
    return (this.dto && this.dto.primaryContactName) || null;
  }

  /**
   * SC-UI-007. For a company the role word is only shown when the server says the booking has its
   * POA (3.13: a primary contact is set). With none the line is omitted entirely - the body already
   * says exactly what is missing.
   */
  get subjectLine() {
    if (this.manualState) return null;
    const name = this.subjectName;
    if (!name) {
      return null;
    }
    const role = this.isOrganisation
      ? this.labels.KYCG_SUBJ_POA
      : this.labels.KYCG_SUBJ_BUYER;
    return `${role} · ${name}`;
  }

  /* ── the digital journey, as the server reports it ───────────────────────── */

  /** The link state for whoever this panel is about: the POA's own track for a company. */
  get track() {
    const c = this.compliance;
    if (!c) {
      return null;
    }
    if (this.isOrganisation && c.signatory) {
      return {
        sentAt: c.signatory.linkSentAt,
        active: c.signatory.linkActive === true,
        completed: !!c.signatory.kycCompletedDate
      };
    }
    return {
      sentAt: c.linkSentAt,
      active: c.linkActive === true,
      completed: c.kycComplete === true
    };
  }

  /**
   * NOT_SENT / SENT / EXPIRED, derived for a company from the POA's own track and for a
   * person taken from the server's verificationStatus verbatim. The two agree by
   * construction: both read KYC_Send_Date_Time__c then Is_KYC_Link_Active__c, in that order.
   */
  get linkState() {
    const c = this.compliance;
    if (!c) {
      return null;
    }
    if (c.releasedToBranch === true) {
      return IN_BRANCH;
    }
    if (!this.isOrganisation) {
      return c.verificationStatus || NOT_SENT;
    }
    const t = this.track;
    if (!t || !t.sentAt) {
      return NOT_SENT;
    }
    return t.active ? SENT : EXPIRED;
  }

  /* ── what state are we in ────────────────────────────────────────────────
     One ordered decision, so the panel can never show two states at once.
     Manual-pending outranks everything because the customer has already been
     handed to Sales Operations and nothing the rep does changes that. The
     digital states sit between "verified" and the document list, because once a
     link is out the journey's own progress is the thing to report.            */

  get view() {
    const d = this.dto;
    if (!d) return null;

    if (MANUAL_PENDING.includes(d.manualApprovalStatus)) {
      /* 3.8 - the field outlives a recalled request; the request's own record decides */
      return this.trail && this.trail.withdrawn ? "withdrawn" : "awaiting";
    }
    if (d.eligible) return "verified";

    /* SC-UI-008. An approved manual KYC is the route this customer is actually on, so it
       outranks the digital link state - otherwise the headline reads "Not started" while the
       panel below reports a signed form. It does NOT imply eligibility: `eligible` is tested
       first and stays the server's alone. */
    if (this.isManualApproved) return "manualApproved";

    const link = this.linkState;
    if (link === IN_BRANCH) return "inBranch";
    if (link === SENT || link === SENDING) return "waiting";
    if (link === EXPIRED) return "linkExpired";

    if (d.missingDocuments && d.missingDocuments.length) return "documents";
    if (d.kycStatus === "KYC Expired") return "expired";
    return "notStarted";
  }

  get show() {
    return !this.failed && !!this.view;
  }

  /** 3.0 - the plain name list is superseded by the checklist, which shows the same rows with ticks. */
  get isDocuments() {
    return this.view === "documents" && !this.showDocuments;
  }

  get isManualApproved() {
    const s = this.dto && this.dto.manualApprovalStatus;
    return !!s && s.trim().toLowerCase() === "approved";
  }

  /* ── actions ─────────────────────────────────────────────────────────────
     Offered only where the server says they are possible. canSendLink already
     mirrors sendKYCForm's own refusals - for a company that is
     SalesConsoleOrgController.missingForLink, which is why a company with no POA
     is told to add one rather than being handed a button that fails.           */

  get canSend() {
    const c = this.compliance;
    return (
      !!c && c.canSendLink === true && this.linkState === NOT_SENT && !this.busy &&
      !this.isManualApproved
    );
  }

  get canResend() {
    const c = this.compliance;
    const link = this.linkState;
    return (
      !!c &&
      c.canSendLink === true &&
      (link === SENT || link === EXPIRED) &&
      !this.busy &&
      !this.isManualApproved
    );
  }

  get canRefresh() {
    if (this.busy) return false;
    /* 3.10 - in the manual states Refresh is how the rep sees an approval land */
    if (this.manualState) return true;
    const c = this.compliance;
    return !!c && c.canRefresh === true;
  }

  get hasActions() {
    return this.canSend || this.canResend || this.canRefresh;
  }

  /* 3.9 - in the manual states the link's own buttons sit in their own row */
  get linkSeparate() {
    return this.manualState;
  }
  /* 3.10 - pending or withdrawn: the box carries one sentence, the actions and the link row */
  get manualState() {
    return this.view === "awaiting" || this.view === "withdrawn";
  }
  get mainSend() {
    return this.canSend && !this.linkSeparate;
  }
  get mainResend() {
    return this.canResend && !this.linkSeparate;
  }
  get showLinkRow() {
    return this.linkSeparate && (this.canSend || this.canResend);
  }
  get linkStateWord() {
    switch (this.linkState) {
      case SENT: {
        const t = this.track;
        return t && t.sentAt
          ? this.fill(this.labels.KYCG_LINK_SENT, [localDay(t.sentAt)])
          : this.fill(this.labels.KYCG_LINK_SENT, [""]).trim();
      }
      case EXPIRED:
        return this.labels.KYCG_LINK_EXPIRED;
      case SENDING:
        return this.labels.KYCG_LINK_SENDING;
      case NOT_SENT:
        return this.labels.KYCG_LINK_NOT_SENT;
      default:
        return null;
    }
  }
  get linkButtonLabel() {
    if (this.busy) return this.labels.KYCG_A_WORKING;
    return this.canSend ? this.labels.KYCG_A_SEND_LINK : this.labels.KYCG_A_RESEND;
  }

  /** 3.7: the row exists for the manual route alone, when it is the only thing on offer. */
  get hasActionRow() {
    return this.mainSend || this.mainResend || this.canRefresh || this.canOfferManual;
  }

  /** 3.7: the request form, now that its toggle lives in the action row above it. */
  get showManualForm() {
    return this.canOfferManual && this.manualOpen;
  }

  /** MODON's own refusal, verbatim where there is one. */
  get cannotSendReason() {
    const c = this.compliance;
    if (!c || c.canSendLink === true) {
      return null;
    }
    if (this.view === "verified" || this.view === "awaiting") {
      return null;
    }
    /* 3.14 - no link to send, so no Power of Attorney row to ask for */
    if (this.isOrganisation && this.primaryContactSettled) {
      return null;
    }
    return debrand(c.blockedReason) || this.labels.KYCG_CANNOT_SEND;
  }

  /**
   * 3.14 - the company's primary contact passes checkKYCEligibility's two tests: KYC_Status__c is
   * "KYC Active", or manually approved (the verdict's fields, read off the contact).
   */
  get primaryContactSettled() {
    const d = this.dto;
    return !!d && (d.kycStatus === "KYC Active" || this.isManualApproved);
  }

  /* ── 3.0 - the required-documents checklist ──────────────────────────────── */

  /**
   * 3.3 - listed only where the representative may collect the files: the manual route once it is
   * APPROVED (approval comes first; nothing is collected while the request is being written or is
   * with compliance), the in-branch route, or a digital check that finished with files missing.
   * Never while a Signzy link is the route in play.
   */
  get showDocuments() {
    const d = this.dto;
    if (!d) {
      return false;
    }
    const v = this.view;
    if (v === "verified" || v === "awaiting") {
      return false;
    }
    if (this.isManualApproved) {
      return true;
    }
    return v === "inBranch" || v === "documents";
  }

  /**
   * 3.12 - what c/mscKycDocuments last reported it had DRAWN. `undefined` means it has not answered
   * yet, and documentsListed reads that as "it will" on purpose.
   */
  docsListed;

  handleDocumentsList(event) {
    this.docsListed = !!(event.detail && event.detail.listed === true);
  }

  /**
   * 3.12 - handed to c/mscKycCapture so it knows whether the missing names are already on the screen
   * above it. Two parts, and the order is the whole point:
   *   no checklist mounted -> false immediately; there is nothing to wait for and nothing to flicker
   *   checklist mounted    -> what it reported, and TRUE until it reports
   * The optimism while waiting is deliberate. A wrong TRUE costs one round trip of silence; a wrong
   * FALSE would print the names and then retract them, which reads as a bug rather than as loading.
   */
  get documentsListed() {
    return this.showDocuments && this.docsListed !== false;
  }

  /** An upload changed the rows: re-ask the server for the verdict AND the post-approval panel (3.6). */
  handleDocumentsChanged() {
    this.load();
    const capture = this.template.querySelector("c-msc-kyc-capture");
    if (capture && typeof capture.reload === "function") {
      capture.reload(false);
    }
  }

  /** 3.1 - the page's Update KYC dialog closed: verdict, checklist and outcome all re-read. */
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

  /** Something on the manual route changed: the verdict AND the checklist re-read. */
  handleManualChanged() {
    this.load();
    const docs = this.template.querySelector("c-msc-kyc-documents");
    if (docs && typeof docs.refresh === "function") {
      docs.refresh();
    }
  }

  handleSend() {
    this.run(
      sendCustomerVerification({
        opportunityId: this._opportunityId,
        primaryUnitId: this.primaryUnitId || null
      }),
      this.labels.KYCG_SENT_OK
    );
  }

  handleRefresh() {
    /* 3.10 - with no digital journey there is nothing to poll: re-read the verdict and the request */
    const c = this.compliance;
    const poll = !!c && c.canRefresh === true;
    /* 3.15 - R2-12: the panel re-renders with the answer; no "Status checked." line */
    this.run(
      poll ? refreshComplianceState({ opportunityId: this._opportunityId }) : Promise.resolve(c),
      null
    );
  }

  /** 3.15 - UI-05: the capture panel below leaves out its own "Manual KYC approved" when this says it. */
  get approvedShown() {
    return this.view === "manualApproved";
  }

  /**
   * 3.15 - R2-18: the documents list says "needed before payment" only while the booking check
   * really holds the payment (the gate for this buyer type is on).
   */
  get docsNeededFor() {
    return this.dto && this.dto.enforcementActive === true ? "payment" : "";
  }

  /**
   * One path for both controls. The server returns the fresh ComplianceStateDTO, so the panel
   * re-renders from the server's answer rather than guessing at the new state; the verdict is
   * re-read too, because a refresh can complete a KYC and change it.
   */
  run(promise, okMessage) {
    this.busy = true;
    this.notice = null;
    this.problem = null;
    promise
      .then((state) => {
        this.compliance = state;
        this.notice = okMessage;
        /* the verdict can have moved - re-ask the one thing that owns it */
        return evaluate({ opportunityId: this._opportunityId });
      })
      .then((result) => {
        if (result) {
          this.dto = result;
        }
        this.announce();
        /* 3.8 - an approval can have landed: the request and the manual panel re-read too */
        this.loadTrail(this._opportunityId);
        const capture = this.template.querySelector("c-msc-kyc-capture");
        if (capture && typeof capture.reload === "function") {
          capture.reload(false);
        }
      })
      .catch((error) => {
        /* the console's shared reducer, so a KYC failure reads like every other one */
        this.problem = this.fill(this.labels.KYCG_SEND_FAILED, [
          reduceError(error)
        ]);
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /* ── presentation ───────────────────────────────────────────────────────── */

  get rootClass() {
    /* Grey base throughout; the left rule is the only thing that carries status,
       and it is a muted --edge-* token, never a saturated chip colour. */
    const v = this.view;
    const tone =
      v === "verified"
        ? "kycg--ok"
        : v === "notStarted" || v === "waiting" || v === "manualApproved"
          ? "kycg--idle"
          : "kycg--warn";
    return `kycg ${tone}`;
  }

  get statusWord() {
    switch (this.view) {
      case "verified":
        return this.labels.KYCG_S_VERIFIED;
      case "expired":
        return this.labels.KYCG_S_EXPIRED;
      case "documents":
        return this.labels.KYCG_S_DOCUMENTS;
      case "awaiting":
      case "withdrawn":
        /* 3.10 - the sentence says it; no status word */
        return null;
      case "manualApproved":
        return this.labels.KYCG_S_MANUAL_APPROVED;
      case "waiting":
        return this.labels.KYCG_S_WAITING;
      case "linkExpired":
        return this.labels.KYCG_S_LINK_EXPIRED;
      case "inBranch":
        return this.labels.KYCG_S_IN_BRANCH;
      default:
        return this.labels.KYCG_S_NOT_STARTED;
    }
  }

  get body() {
    const d = this.dto || {};
    switch (this.view) {
      case "verified":
        return d.validUntil
          ? this.fill(this.labels.KYCG_B_VERIFIED, [
              formatDate(d.completedDate),
              formatDate(d.validUntil)
            ])
          : this.labels.KYCG_B_VERIFIED_MANUAL;
      case "expired":
        return this.fill(this.labels.KYCG_B_EXPIRED, [
          formatDate(d.completedDate),
          formatDate(d.validUntil)
        ]);
      case "documents":
        return this.labels.KYCG_B_DOCUMENTS;
      case "awaiting":
        return this.labels.KYCG_B_AWAITING;
      case "withdrawn": {
        const t = this.trail || {};
        return t.decidedAt
          ? this.fill(this.labels.KYCG_B_WITHDRAWN, [localDay(t.decidedAt)])
          : this.labels.KYCG_B_WITHDRAWN_NONE;
      }
      case "manualApproved":
        return this.labels.KYCG_B_MANUAL_APPROVED;
      case "waiting":
        return this.labels.KYCG_B_WAITING;
      case "linkExpired":
        return this.labels.KYCG_B_LINK_EXPIRED;
      case "inBranch":
        return this.labels.KYCG_B_IN_BRANCH;
      default:
        /* The server's own words where it gave them; never our paraphrase. 3.14: exactly as
           MODON wrote them, "Opportunity" included. */
        return d.blockedReason || this.labels.KYCG_B_NOT_STARTED;
    }
  }

  /** When the link went out. Shown only while it is the thing that matters. */
  get sentLine() {
    const t = this.track;
    if (!t || !t.sentAt) {
      return null;
    }
    if (this.view !== "waiting" && this.view !== "linkExpired") {
      return null;
    }
    /* "07 Sep 2026 · 14:22" - the same shape the Verification track uses. */
    const when = `${formatDate(t.sentAt)} · ${formatTime(t.sentAt)}`;
    return this.fill(this.labels.KYCG_SENT_ON, [when]);
  }

  get documents() {
    return (this.dto && this.dto.missingDocuments) || [];
  }

  get sendLabel() {
    return this.busy ? this.labels.KYCG_A_WORKING : this.labels.KYCG_A_SEND;
  }

  get resendLabel() {
    return this.busy ? this.labels.KYCG_A_WORKING : this.labels.KYCG_A_RESEND;
  }

  /* ── the manual route ────────────────────────────────────────────────────
     Offered UNDER the digital one, never beside it: Signzy is the route, and manual
     KYC is what happens when that route cannot be finished. It stays closed until the
     rep asks for it, so the common case shows one status and up to three buttons.     */

  manualOpen = false;

  /**
   * Nothing to submit manually for a customer who is already verified, already waiting, or
   * already approved (3.4) - the approved route continues in c/mscKycCapture, not here.
   */
  get canOfferManual() {
    const v = this.view;
    return !!this.dto && v !== "verified" && v !== "awaiting" && v !== "manualApproved";
  }

  get manualToggleLabel() {
    return this.manualOpen
      ? this.labels.KYCG_MANUAL_CLOSE
      : this.labels.KYCG_MANUAL_OPEN;
  }

  toggleManual() {
    this.manualOpen = !this.manualOpen;
  }

  /** The submission changed the customer's state: close the request and re-ask the server. */
  handleManualSubmitted() {
    this.manualOpen = false;
    this.load();
  }

  /**
   * Phase 3B. The post-approval route renders itself only once a manual KYC actually exists -
   * an ordinary digital booking never sees it. c/mscKycCapture decides its own visibility from
   * the approval status; this only keeps it off a customer who is already fully verified with
   * no manual route in play.
   */
  get showCapture() {
    const d = this.dto;
    if (!d) {
      return false;
    }
    return !!d.manualApprovalStatus;
  }

  /**
   * PHASE 4. Does this customer's KYC hold up the step?
   *
   * Only when the gate for their buyer type is actually ON - enforcementActive is the server's
   * answer, read from Sales_Console_Config__mdt for a person or a company. With the gate off
   * this stays false and the journey behaves exactly as it did in Phase 3.
   *
   * This is a CONVENIENCE, not the enforcement. SalesConsoleController refuses the money
   * itself, so a stale tab or a direct call is refused whatever this getter says.
   */
  get blocksContinue() {
    const d = this.dto;
    return !!d && d.enforcementActive === true && d.eligible !== true;
  }

  /** The short line beside the disabled control. One phrase, no paragraph. */
  get blockNote() {
    return this.blocksContinue ? this.labels.KYCG_BLOCKS_CONTINUE : null;
  }

  /** Tells the host whether to hold Continue. The host owns the button; this owns the answer. */
  announce() {
    this.dispatchEvent(
      new CustomEvent("kycstate", {
        detail: { blocks: this.blocksContinue }
      })
    );
  }

  /** Phase 3 tells the truth about itself: this panel is not stopping anything. */
  get advisory() {
    return this.dto && this.dto.enforcementActive
      ? null
      : this.labels.KYCG_ADVISORY;
  }

  fill(template, values) {
    return values.reduce(
      (text, value, i) => text.replace(`{${i}}`, value || ""),
      template
    );
  }
}