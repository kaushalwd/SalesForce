/**
 * The next step on a corporate booking: one line, one button.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 23 Aug 2026  MSC-151. Initial.
 *
 * It decides nothing: every word, the button and the state are SalesConsoleOrgController.nextStep's
 * answer. No fallback copy; with no answer the bar does not render.
 *   in    step, busy
 *   out   nextaction { action }
 */
import { LightningElement, api } from "lwc";

export default class MscVerifyNext extends LightningElement {
  /** SalesConsoleOrgController.OrgNextStepDTO, or null on an individual booking. */
  @api step;
  @api busy = false;

  get s() {
    return this.step || {};
  }

  /** Null means an individual booking or a failed read: nothing. */
  get show() {
    return !!this.s.headline;
  }

  get barClass() {
    const tone = this.s.tone;
    return tone === "wait" || tone === "go" || tone === "rest"
      ? `vn vn--${tone}`
      : "vn";
  }

  get hasButton() {
    return !!this.s.buttonLabel && !!this.s.action;
  }

  get disabled() {
    return this.busy === true;
  }

  handleAct() {
    if (this.disabled || !this.hasButton) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("nextaction", { detail: { action: this.s.action } })
    );
  }
}