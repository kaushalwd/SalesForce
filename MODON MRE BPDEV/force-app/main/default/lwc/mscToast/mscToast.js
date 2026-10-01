/**
 * A confirmation, briefly.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 22 Aug 2026  MSC-131. Top centre, docked under the brand row -
 *                                   where Salesforce puts a toast, and where a rep who
 *                                   uses Salesforce all day looks for one. CSS only.
 * 1.0      Aurelix Dev 22 Aug 2026  MSC-126. Saving the address and saving the
 *                                   customer's missing details both returned in
 *                                   silence: the fields simply turned to facts and
 *                                   the button retired itself, which is correct but
 *                                   reads as nothing having happened. This says so,
 *                                   for four seconds.
 *
 *                                   NOT lightning/platformShowToastEvent - an LWR
 *                                   site has no toast container to catch it, so the
 *                                   event is dispatched and swallowed. NOT
 *                                   c/customToast either: that one belongs to
 *                                   Modon's own screens, carries its own palette
 *                                   and dismisses at three seconds. This one is the
 *                                   console's - themed from c/mscStyles' tokens,
 *                                   so it follows the theme the rep chose.
 */

import { LightningElement, api } from "lwc";

const LIFETIME_MS = 4000;
/* Matches the CSS exit transition. The node stays mounted while it fades so the
   toast leaves the way it arrived rather than vanishing mid-animation. */
const EXIT_MS = 200;

export default class MscToast extends LightningElement {
  message;
  variant = "ok";
  shown = false;

  _hideTimer;
  _dropTimer;

  /**
   * @param {string} message  what happened, in the rep's words
   * @param {string} variant  'ok' (default) | 'error'
   *
   * Calling again while one is up replaces it and restarts the clock, rather
   * than stacking: two saves in quick succession are one piece of news.
   */
  @api
  show(message, variant) {
    if (!message) return;
    this.clearTimers();
    this.message = message;
    this.variant = variant === "error" ? "error" : "ok";
    this.shown = true;
    this._hideTimer = setTimeout(() => this.hide(), LIFETIME_MS);
  }

  @api
  hide() {
    this.clearTimers();
    this.shown = false;
    this._dropTimer = setTimeout(() => {
      this.message = undefined;
    }, EXIT_MS);
  }

  handleDismiss() {
    this.hide();
  }

  /* A timer that outlives the component fires into a torn-down template. */
  disconnectedCallback() {
    this.clearTimers();
  }

  clearTimers() {
    if (this._hideTimer) clearTimeout(this._hideTimer);
    if (this._dropTimer) clearTimeout(this._dropTimer);
    this._hideTimer = undefined;
    this._dropTimer = undefined;
  }

  get hasMessage() {
    return !!this.message;
  }

  get toastClass() {
    return `toast toast--${this.variant}${this.shown ? " toast--in" : ""}`;
  }

  get iconName() {
    return this.variant === "error" ? "alert-triangle" : "check";
  }

  get iconColour() {
    return this.variant === "error"
      ? "var(--chip-red, #f87171)"
      : "var(--chip-green, #4ade80)";
  }
}