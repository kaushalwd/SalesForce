/**
 * The step-2 verification dialog.
 *
 * Version  Author              Date         Detail
 * 1.0      Aurelix Developer   16 Aug 2026  Initial - the two-option choice.
 * 1.1      Aurelix Developer   16 Aug 2026  IT STAYS OPEN AFTER SENDING.
 *
 *                                           Sending used to close this and drop the
 *                                           rep into the booking with a strip
 *                                           explaining why they could not move. That
 *                                           is a worse place to wait: the rep is
 *                                           released onto a screen full of controls
 *                                           they cannot use, and has to work out
 *                                           which one is disabled and why. The
 *                                           dialog now holds them where the decision
 *                                           was made, and the journey opens only
 *                                           once there is something to do in it.
 *
 * TWO PHASES, ONE DIALOG:
 *
 *   choose    the two options
 *   waiting   sent, with Check again and the way out
 *
 * Which one shows is derived from the SERVER's verificationStatus, never from a
 * local "I pressed send" flag - a reload mid-wait has to land the rep back in the
 * waiting phase, and only the account can tell us that.
 *
 * Lives in mscBookingPage rather than mscConsole because everything it needs is
 * there: the unit that gets stamped onto the account, the compliance state, and the
 * poll. mscConsole knows the customer and nothing else.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

export default class MscVerifyChoice extends LightningElement {
  labels = LABELS;

  /** Who the booking is for. Used by the waiting phase's strip, not the heading. */
  @api customerName;
  /** From ComplianceStateDTO - the server's verdict, not a local guess. */
  @api canSend = false;
  /** The server's own wording for why not. Shown verbatim. */
  @api blockedReason;
  /** True while a send or a release is in flight. */
  @api busy = false;
  /** True while the status poll is in flight, so Check again can say so. */
  @api refreshing = false;
  /** ComplianceStateDTO. Its verificationStatus decides the phase. */
  @api state;

  get status() {
    return (this.state || {}).verificationStatus;
  }

  /**
   * SENDING covers the gap between enqueueing the job and MODON's Flow stamping
   * KYC_Send_Date_Time__c. Without it the dialog would flick back to the choice for
   * a second or two and invite a second press.
   */
  get isWaiting() {
    const s = this.status;
    return s === "SENDING" || s === "SENT" || s === "EXPIRED";
  }

  get showChoice() {
    return !this.isWaiting;
  }

  get sendDisabled() {
    return this.busy || !this.canSend;
  }

  /**
   * Only when it says something the buttons do not. `blockedReason` is populated on
   * the happy path too, so gating on canSend keeps a reason from appearing under a
   * button that works.
   */
  get showBlockedReason() {
    return this.showChoice && !this.canSend && !!this.blockedReason;
  }

  get sendLabel() {
    return this.busy ? LABELS.VERIFY_SENDING : LABELS.VERIFY_SEND_CTA;
  }

  handleSend() {
    if (this.sendDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("choose", { detail: { send: true } }));
  }

  handleLater() {
    if (this.busy) {
      return;
    }
    this.dispatchEvent(new CustomEvent("choose", { detail: { send: false } }));
  }

  /* Re-raised so mscBookingPage handles them with the same methods the inline
     strip uses. The dialog routes; it does not decide. */
  handleRefresh() {
    this.dispatchEvent(new CustomEvent("refresh"));
  }
  handleResend() {
    this.dispatchEvent(new CustomEvent("resend"));
  }
  handleInBranch() {
    this.dispatchEvent(new CustomEvent("inbranch"));
  }

  /**
   * Escape means "continue without sending" while there is still a choice to make,
   * and NOTHING once a link is out.
   *
   * The customer already exists by the time this opens, so a dismissal that
   * reported nothing would strand the rep. But once a link has gone, leaving by
   * Escape would be an unlabelled way past a gate whose only intended exits are
   * "they verified" and "verify in branch instead".
   */
  handleKeydown(event) {
    if (event.key !== "Escape") {
      return;
    }
    /* Stop it reaching modonSheet's window listener either way, which would close
       the whole booking journey on the same keypress. */
    event.stopPropagation();
    if (this.busy || this.isWaiting) {
      return;
    }
    this.dispatchEvent(new CustomEvent("choose", { detail: { send: false } }));
  }

  /** Focus the primary action on open so Escape and Enter both mean something. */
  renderedCallback() {
    if (this._focused || this.isWaiting) {
      return;
    }
    const target =
      this.template.querySelector(".choice__cta--send:not([disabled])") ||
      this.template.querySelector(".choice__cta--later");
    if (target) {
      this._focused = true;
      target.focus();
    }
  }
}