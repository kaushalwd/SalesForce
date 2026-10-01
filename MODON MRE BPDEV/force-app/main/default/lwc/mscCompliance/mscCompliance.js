/**
 * Identity verification and compliance, rendered as a chain.
 *
 * Version  Author      Date         Detail
 * 1.5      Aurelix Dev 30 Sep 2026  No dash as a blank step line (UI-21).
 * 1.4      Aurelix Dev 22 Aug 2026  MSC-115. The headline chip stays quiet for a
 *                                   company: the compliance answer now carries a
 *                                   company's verdict, and this card hides its body
 *                                   for one - a verdict over no body is a headline
 *                                   with no story. c/mscVerifyList tells it instead.
 * 1.0      Aurelix IT  06 Aug 2026  Initial.
 * 1.1      Aurelix Dev 19 Aug 2026  A SENT LINK IS THE REP'S PART DONE. While the link
 *                                   is out (verificationStatus SENT) the panel reads
 *                                   green - chip "KYC link sent", a check, KYC_SENT_DONE -
 *                                   instead of the amber "not verified / waiting" it
 *                                   showed; expired, verified and compliance states are
 *                                   untouched, and Resend stays available.
 * 1.2      Aurelix IT  19 Aug 2026  Redesigned to the approved artifact (MSC-061). The
 *                                   chain is four SEGMENTS, edge to edge - icon tile +
 *                                   label, a segment bar (green done, amber in play,
 *                                   blue with compliance, red on a problem, dim ahead),
 *                                   and the fact under each: when the link went out
 *                                   and when it expires, where the customer got to or
 *                                   when they verified, when it was submitted, the
 *                                   verdict and risk. The head keeps the chip and adds
 *                                   "Checked hh:mm" beside Refresh. The explanation
 *                                   sentence, the floating "Customer last seen at"
 *                                   line and the last-attempt note are gone - the
 *                                   facts under the segments carry them. Copy link
 *                                   (linkUrl, client-side) beside Resend. Same
 *                                   ComplianceStateDTO, same events (sendlink,
 *                                   refreshcompliance); nothing decided differently -
 *                                   done / in-play / chip / send rules are unchanged.
 * 1.3      Aurelix IT  19 Aug 2026  MSC-069. One action added: once the customer has
 *                                   verified and nothing has been submitted, the card
 *                                   offers "Check & submit to compliance", which opens
 *                                   the check rather than submitting anything itself.
 *                                   Send/Resend steps aside while it is showing - a
 *                                   completed verification is not resent, and the rep's
 *                                   move is now the check. Segments, chip, refresh, copy
 *                                   and every existing rule are untouched.
 */

import { LightningElement, api } from "lwc";
import { LABELS, complianceLabel, KYC_STATUS_LABELS } from "c/mscLabels";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const HOUR_MS = 3600 * 1000;
/* 1.5 - UI-21: a step with nothing to say shows nothing, not a dash */
const DASH = "";
const COPIED_MS = 1200;

/** One icon per segment: link out · customer · compliance · verdict (c/modonIcon names). */
const STEP_ICONS = ["send", "user", "shield-check", "check-circle"];

/**
 * Identity verification and compliance, as a chain rather than a checklist.
 *
 * The agent sends a link, the customer verifies, compliance submits itself, a
 * decision lands days later. A checklist implies items to tick and reads as the
 * agent's fault; a chain shows whose move it is.
 *
 * Does not enumerate missing fields before the customer has verified - Signzy fills
 * most of them, so an early list is noise that trains agents to ignore the panel.
 */
export default class MscCompliance extends LightningElement {
  /** SalesConsoleController.ComplianceStateDTO */
  @api state;
  @api busy = false;
  @api refreshing = false;

  labels = LABELS;
  /* 1.2 - "Copied" for a moment after Copy link. */
  copied = false;
  _copyTimer;

  disconnectedCallback() {
    window.clearTimeout(this._copyTimer);
  }

  get s() {
    return this.state || {};
  }

  // --- small formatters ---------------------------------------------------

  ms(v) {
    if (!v) {
      return 0;
    }
    const t = new Date(v).getTime();
    return isNaN(t) ? 0 : t;
  }
  /** "19 Aug" */
  day(v) {
    const t = this.ms(v);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }
  /** "07:48" */
  clock(v) {
    const t = this.ms(v);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }
  /** "under an hour", "6h", "2d" */
  span(msDelta) {
    const a = Math.abs(msDelta);
    const h = Math.floor(a / HOUR_MS);
    if (h < 1) {
      return "under an hour";
    }
    if (h < 24) {
      return h + "h";
    }
    return Math.floor(h / 24) + "d";
  }

  // --- the states the rest of the panel reads -----------------------------

  get approved() {
    return this.s.approvalStatus === "Approved";
  }
  get rejected() {
    return this.s.approvalStatus === "Rejected" || this.s.approvalStatus === "Canceled";
  }
  get resubmit() {
    return this.s.approvalStatus === "Requires Resubmission";
  }
  /* 1.1 - the link is out and live, the customer has not finished, no compliance
     verdict yet: the rep's part is done. */
  get linkOutDone() {
    const s = this.s;
    return s.verificationStatus === "SENT" && s.kycComplete !== true && !s.approvalStatus;
  }
  get expired() {
    return this.s.kycStatus === "KYC Expired" && this.s.kycComplete !== true;
  }
  get isCorporate() {
    return this.s.isPersonAccount === false;
  }
  get showChain() {
    return !this.isCorporate;
  }

  // --- the four segments --------------------------------------------------

  get steps() {
    const s = this.s;
    const now = Date.now();
    const done = [
      s.kycLinkSent === true,
      s.kycComplete === true,
      s.submitted === true,
      this.approved
    ];
    // The first not-done link is the one currently in play. Everything after it
    // is genuinely untouched, so it must not read as pending-on-us.
    const activeIdx = done.indexOf(false);

    return [
      LABELS.KYC_STEP_SENT,
      LABELS.KYC_STEP_DONE,
      LABELS.KYC_STEP_SUBMITTED,
      LABELS.KYC_STEP_APPROVED
    ].map((label, i) => {
      let tone = done[i] ? "done" : i === activeIdx ? "active" : "";
      // The fact under the segment: lead text, then an emphasised part.
      let lead = "";
      let strong = "";
      let strongTone = "";
      let metaTone = "";

      if (i === 0) {
        if (s.kycLinkSent && s.linkSentAt) {
          lead = `${this.day(s.linkSentAt)} · ${this.clock(s.linkSentAt)}`;
          if (s.linkExpiresAt && !s.kycComplete) {
            const exp = this.ms(s.linkExpiresAt);
            if (s.linkActive) {
              lead += ` · expires in ${this.span(exp - now)}`;
            } else {
              lead += " · ";
              strong = `expired ${this.span(now - exp)} ago`;
              strongTone = "x";
              tone = "warn";
            }
          }
        } else {
          lead = s.kycLinkSent ? "Sent" : "Not sent";
        }
      } else if (i === 1) {
        if (s.kycComplete) {
          lead = s.kycCompletedDate ? `Verified ${this.day(s.kycCompletedDate)}` : "Verified";
        } else if (this.expired) {
          lead = "Needs to be done again";
          tone = "warn";
        } else if (s.journeyStatus) {
          // Where the customer actually got to. Without this, a half-finished
          // verification is indistinguishable from one never started.
          lead = "Customer is at: ";
          strong = s.journeyStatus;
        } else {
          lead = s.kycLinkSent ? "Waiting for the customer" : DASH;
        }
      } else if (i === 2) {
        if (s.submitted) {
          lead = s.lastAttemptOn ? `Submitted ${this.day(s.lastAttemptOn)}` : "Submitted";
        } else {
          lead = DASH;
        }
      } else if (s.approvalStatus) {
        lead = complianceLabel(s.approvalStatus);
        if (this.approved) {
          if (s.riskStatus) {
            lead += ` · risk ${String(s.riskStatus).toLowerCase()}`;
          }
          metaTone = "ok";
        } else if (this.rejected || this.resubmit) {
          metaTone = "bad";
          tone = "warn";
        } else {
          tone = "info";
        }
      } else {
        lead = DASH;
      }

      return {
        key: label,
        label,
        done: done[i],
        icon: STEP_ICONS[i],
        cls: tone ? "step step--" + tone : "step",
        metaCls: metaTone ? "meta meta--" + metaTone : "meta",
        lead,
        strong,
        hasStrong: !!strong,
        strongCls: strongTone ? "strong strong--" + strongTone : "strong"
      };
    });
  }

  // --- headline chip ------------------------------------------------------

  get statusText() {
    const s = this.s;
    /* 1.4 - MSC-115. The compliance answer now carries a COMPANY's verdict, and
       this card hides its whole body for a company (showChain). A verdict chip
       standing over nothing would be a headline with no story under it, so the
       chip stays quiet here; c/mscVerifyList is where a company's two tracks are
       told properly. */
    if (this.isCorporate) return "";
    if (s.approvalStatus) return complianceLabel(s.approvalStatus);
    if (this.linkOutDone) return LABELS.VERIFY_TAPE_SENT;
    if (s.kycStatus) return KYC_STATUS_LABELS[s.kycStatus] || s.kycStatus;
    return "";
  }

  get statusChipClass() {
    const s = this.s;
    if (this.isCorporate) return "vchip vchip--muted";
    if (this.approved) return "vchip vchip--ok";
    if (this.rejected || this.resubmit) return "vchip vchip--warn";
    if (s.approvalStatus) return "vchip vchip--info";
    if (this.linkOutDone) return "vchip vchip--ok";
    if (s.kycStatus === "KYC Active") return "vchip vchip--ok";
    if (s.kycStatus === "KYC Expired") return "vchip vchip--warn";
    return "vchip vchip--muted";
  }

  // --- send / resend / copy ---------------------------------------------

  get canSend() {
    return this.s.canSendLink === true && !this.busy;
  }

  /** Templates cannot negate, so the disabled state is computed here. */
  get canSendDisabled() {
    return !this.canSend;
  }

  get sendLabel() {
    return this.s.kycLinkSent ? LABELS.KYC_RESEND : LABELS.KYC_SEND;
  }

  /** Primary while it is the rep's move (nothing out, or expired); ghost once a link is out. */
  get sendClass() {
    return !this.s.kycLinkSent || this.expired ? "btn btn-primary btn-sm" : "btn btn-ghost btn-sm";
  }

  /* 1.3 - the rep's move once the customer has verified: open the check. Not a submit
     button - nothing leaves this card, and what the check finds decides whether a
     submission is even possible. */
  get showCheck() {
    const s = this.s;
    return (
      s.isPersonAccount !== false &&
      s.kycComplete === true &&
      s.submitted !== true &&
      !s.approvalStatus
    );
  }

  get showSend() {
    // Nothing to send once compliance has cleared, and a company account never
    // goes through this route at all.
    // 1.3 - nor while the check is on offer: a completed verification is not resent.
    return (
      this.s.isPersonAccount !== false &&
      this.s.approvalStatus !== "Approved" &&
      !this.showCheck
    );
  }

  /** The row itself, so it renders for either action. */
  get showActs() {
    return this.showSend || this.showCheck;
  }

  /** "Link active until 25 Aug" / "Link expired 17 Aug" beside the actions. */
  get linkHint() {
    const s = this.s;
    if (!s.kycLinkSent || !s.linkExpiresAt || s.kycComplete) {
      return "";
    }
    return (s.linkActive ? "Link active until " : "Link expired ") + this.day(s.linkExpiresAt);
  }

  get showCopy() {
    const s = this.s;
    return !!s.linkUrl && s.linkActive === true && s.kycComplete !== true;
  }
  get copyLabel() {
    return this.copied ? "Copied" : "Copy link";
  }

  get blockedReason() {
    return this.s.blockedReason;
  }

  get showBlocked() {
    return !!this.s.blockedReason && this.s.isPersonAccount !== false;
  }

  get comment() {
    return this.s.passfortComment;
  }

  get showComment() {
    return !!this.s.passfortComment;
  }

  // --- refresh -------------------------------------------------------------

  /**
   * A button rather than an auto-poll: the chain moves on a scale of hours and days,
   * so a timer would be almost entirely wasted calls and a never-ending spinner
   * reads as broken. On-demand also leaves in-progress form edits alone.
   */
  get showRefresh() {
    return this.s.isPersonAccount !== false && this.s.approvalStatus !== "Approved";
  }

  get refreshDisabled() {
    return this.refreshing || this.busy;
  }

  get refreshIconClass() {
    return this.refreshing ? "cmp__refresh cmp__refresh--spin" : "cmp__refresh";
  }

  get refreshTitle() {
    return this.refreshing ? LABELS.KYC_REFRESHING : LABELS.KYC_REFRESH;
  }

  /** "Checked 09:39" - when the last poll ran, so the rep knows if pressing is worth it. */
  get checkedText() {
    const t = this.clock(this.s.refreshedOn);
    return t ? "Checked " + t : "";
  }

  get refreshMessage() {
    return this.s.refreshMessage;
  }

  get showRefreshMessage() {
    return !!this.s.refreshMessage;
  }

  handleRefresh() {
    this.dispatchEvent(new CustomEvent("refreshcompliance"));
  }

  handleSend() {
    this.dispatchEvent(new CustomEvent("sendlink"));
  }

  /* 1.3 - asks the page to open the check. The card knows nothing about what
     compliance needs, and must not start guessing. */
  handleCheck() {
    this.dispatchEvent(new CustomEvent("checkcompliance"));
  }

  /** Client-side only: the URL is already on the DTO (linkUrl). */
  handleCopy() {
    const url = this.s.linkUrl;
    if (!url) {
      return;
    }
    const flash = () => {
      this.copied = true;
      window.clearTimeout(this._copyTimer);
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._copyTimer = window.setTimeout(() => {
        this.copied = false;
      }, COPIED_MS);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(flash, () => {});
    }
  }
}