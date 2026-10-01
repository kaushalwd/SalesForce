/**
 * The waiting strip, shown in step 2 while the verification gate holds.
 *
 * Version  Author              Date         Detail
 * 1.0      Aurelix Developer   16 Aug 2026  Initial.
 * 1.1      Aurelix Developer   16 Aug 2026  Stacked, and sized by its container.
 *
 *                                           It was built as a full-width strip
 *                                           and then reused inside the 430px
 *                                           verification dialog, where the text
 *                                           column collapsed to a word per line
 *                                           beside two buttons that did not.
 *                                           See the CSS for why the fix is a
 *                                           container query and not a media one.
 *
 * The forward button being disabled says the journey cannot move. This says WHY, WHO
 * it is waiting on, HOW LONG the link has left, and - the part that matters most -
 * offers the way out. Without a visible exit an expired link strands a live booking
 * with a buyer sitting in front of the rep.
 *
 * It owns no state. The parent holds ComplianceStateDTO and does the polling; this
 * renders it and reports the two things a rep can ask for.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

export default class MscVerifyGate extends LightningElement {
  labels = LABELS;

  /** ComplianceStateDTO. verificationStatus / linkExpiresAt / linkActive are read. */
  @api state;
  @api customerName;
  @api busy = false;
  @api refreshing = false;

  get status() {
    return (this.state || {}).verificationStatus;
  }

  get isExpired() {
    return this.status === "EXPIRED";
  }

  get isSending() {
    return this.status === "SENDING";
  }

  get who() {
    return this.customerName || "the customer";
  }

  get title() {
    if (this.isSending) {
      return LABELS.VERIFY_SENDING;
    }
    return this.isExpired
      ? LABELS.VERIFY_EXPIRED_TITLE
      : LABELS.VERIFY_WAITING_TITLE.replace("{0}", this.who);
  }

  get body() {
    if (this.isSending) {
      return LABELS.VERIFY_SENDING_BODY;
    }
    return this.isExpired
      ? LABELS.VERIFY_EXPIRED_BODY.replace("{0}", this.who)
      : LABELS.VERIFY_WAITING_BODY;
  }

  /** The tracked word above the title. Its colour and the dot come from the CSS. */
  get statusWord() {
    if (this.isSending) {
      return LABELS.VERIFY_STATUS_SENDING;
    }
    return this.isExpired
      ? LABELS.VERIFY_STATUS_EXPIRED
      : LABELS.VERIFY_STATUS_WAITING;
  }

  /**
   * A countdown, not a timestamp. "Expires in 24 minutes" is something a rep can
   * act on in front of a customer; "expires at 14:07" makes them do arithmetic.
   *
   * Recomputed on render rather than ticked by its own timer - the parent already
   * polls every 20 seconds while this is on screen, and a second interval here
   * would be two clocks to stop when the gate lifts.
   */
  get expiresIn() {
    const at = (this.state || {}).linkExpiresAt;
    if (!at || this.isExpired || this.isSending) {
      return null;
    }
    const ms = new Date(at).getTime() - Date.now();
    if (!isFinite(ms) || ms <= 0) {
      return null;
    }
    const mins = Math.round(ms / 60000);
    if (mins < 1) {
      return LABELS.VERIFY_EXPIRES_IN.replace("{0}", "less than a minute");
    }
    if (mins < 60) {
      return LABELS.VERIFY_EXPIRES_IN.replace(
        "{0}",
        `${mins} minute${mins === 1 ? "" : "s"}`
      );
    }
    const hours = Math.round(mins / 60);
    return LABELS.VERIFY_EXPIRES_IN.replace(
      "{0}",
      `${hours} hour${hours === 1 ? "" : "s"}`
    );
  }

  get showExpiresIn() {
    return !!this.expiresIn;
  }

  get rootClass() {
    return this.isExpired ? "gate gate--expired" : "gate";
  }

  /** Re-sending an expired link is the same call as sending the first one. */
  get refreshLabel() {
    return this.isExpired ? LABELS.VERIFY_RESEND : LABELS.VERIFY_REFRESH;
  }

  get actionsDisabled() {
    return this.busy || this.refreshing;
  }

  handlePrimary() {
    if (this.actionsDisabled) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent(this.isExpired ? "resend" : "refresh")
    );
  }

  handleInBranch() {
    if (this.actionsDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("inbranch"));
  }
}