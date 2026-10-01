/**
 * EOI journey - step 2, Verify.
 *
 * Version  Author      Date         Detail
 * 1.x+1    Aurelix Dev 20 Sep 2026  The verification channel cannot be changed while the resend
 *                                   countdown runs: a second code silently invalidates
 *                                   the one the customer already has, and switching tiles was a
 *                                   way around the cooldown the resend link enforces.
 * 1.0      Aurelix IT  17 Aug 2026  Initial. Channel choice + six-box OTP entry.
 *
 * Owns only the six input boxes (focus, auto-advance, backspace, paste). Everything that
 * matters - which request is live, whether it verified, cooldowns - is the orchestrator's,
 * passed in as props. The boxes clear when `resetToken` changes, which is how a resend or
 * a channel switch empties them without this component keeping any state of its own.
 */

import { LightningElement, api } from "lwc";
import { OTP_LENGTH, maskEmail, maskPhone } from "c/mscEoiUtils";

export default class MscEoiVerify extends LightningElement {
  @api method = "";
  @api emailTarget = "";
  @api phoneTarget = "";
  @api requestId;
  @api isVerified = false;
  @api message = "";
  @api sending = false;
  @api cooldownSeconds = 0;
  @api maxResendReached = false;
  @api busy = false;
  @api nextDisabled = false;

  _resetToken = 0;
  @api
  get resetToken() {
    return this._resetToken;
  }
  set resetToken(value) {
    if (value !== this._resetToken) {
      this._resetToken = value;
      this.digits = Array.from({ length: OTP_LENGTH }, () => "");
      this._focusIndex = 0;
    }
  }

  digits = Array.from({ length: OTP_LENGTH }, () => "");
  _focusIndex = null;

  renderedCallback() {
    if (this._focusIndex === null || this._focusIndex === undefined) return;
    const input = this.template.querySelector(`input[data-index="${this._focusIndex}"]`);
    this._focusIndex = null;
    if (input) input.focus();
  }

  // ── Derived ──────────────────────────────────────────────────────────────

  /**
   * 1.x+1 - the channel is settled once a code is out.
   * While the resend countdown runs, the tiles are locked. Switching channel mid-wait
   * sends a SECOND code, which silently invalidates the one the customer is already reading -
   * and it side-steps the cooldown the resend link enforces two lines below. The wait is the
   * decision point for both, so the same timer governs both. The chosen tile stays legible;
   * only the alternatives dim, because it is a lock, not an outage.
   */
  get channelsLocked() {
    return Number(this.cooldownSeconds) > 0;
  }

  get channels() {
    const emailOk = Boolean(this.emailTarget);
    const smsOk = Boolean(this.phoneTarget);
    const locked = this.channelsLocked;
    return [
      {
        key: "email",
        icon: "mail",
        title: "Email",
        sub: emailOk ? maskEmail(this.emailTarget) : "No email on file",
        disabled: !emailOk || this.sending || this.busy || locked,
        cls: this.tileClass("email", !emailOk),
        loading: this.sending && this.method === "email",
        selected: this.method === "email"
      },
      {
        key: "sms",
        icon: "phone",
        title: "SMS",
        sub: smsOk ? `•••• ${maskPhone(this.phoneTarget)}` : "No phone on file",
        disabled: !smsOk || this.sending || this.busy || locked,
        cls: this.tileClass("sms", !smsOk),
        loading: this.sending && this.method === "sms",
        selected: this.method === "sms"
      },
      {
        key: "whatsapp",
        icon: "send",
        title: "WhatsApp",
        sub: "Coming soon",
        disabled: true,
        cls: "tile tile--off",
        loading: false,
        selected: false
      }
    ];
  }
  tileClass(key, unavailable) {
    return `tile${this.method === key ? " tile--on" : ""}${unavailable ? " tile--off" : ""}`;
  }

  get showCode() {
    return Boolean(this.method) && this.method !== "whatsapp";
  }
  get boxes() {
    return this.digits.map((value, index) => ({
      key: `otp-${index}`,
      index,
      value,
      cls: `otp__box${value ? " otp__box--filled" : ""}${this.isVerified ? " otp__box--ok" : ""}`
    }));
  }
  get destinationText() {
    if (this.method === "sms") return `A 6-digit code was sent to the customer's mobile ending in ${maskPhone(this.phoneTarget)}.`;
    return `A 6-digit code was sent to ${maskEmail(this.emailTarget)}.`;
  }
  get resendDisabled() {
    return this.sending || this.busy || this.cooldownSeconds > 0;
  }
  get resendLabel() {
    return this.cooldownSeconds > 0 ? `Resend in ${this.cooldownSeconds}s` : "Resend code";
  }
  get showResend() {
    return !this.maxResendReached && !this.isVerified;
  }
  get nextLabel() {
    return this.isVerified ? "Continue" : "Verify & continue";
  }
  get inputsDisabled() {
    return this.busy || this.isVerified || !this.requestId;
  }

  // ── Events ───────────────────────────────────────────────────────────────

  emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail }));
  }

  handleChannel(e) {
    const method = e.currentTarget.dataset.method;
    if (!method) return;
    this.emit("sendcode", { method });
  }
  handleResend() {
    this.emit("resend");
  }
  handleBack() {
    this.emit("back");
  }
  handleNext() {
    this.emit("next");
  }

  handleInput(e) {
    const index = Number(e.target.dataset.index);
    const raw = (e.target.value || "").replace(/\D/g, "");
    if (raw.length > 1) {
      // A paste (or an autofill) into one box: spread across the row.
      this.fill(raw, index);
      return;
    }
    const value = raw.slice(-1);
    e.target.value = value;
    this.digits = this.digits.map((d, i) => (i === index ? value : d));
    if (value && index < OTP_LENGTH - 1) this._focusIndex = index + 1;
    this.publish();
  }

  handleKeydown(e) {
    const index = Number(e.target.dataset.index);
    if (e.key === "Backspace" && !e.target.value && index > 0) {
      e.preventDefault();
      this.digits = this.digits.map((d, i) => (i === index - 1 ? "" : d));
      this._focusIndex = index - 1;
      this.publish();
    } else if (e.key === "ArrowLeft" && index > 0) {
      e.preventDefault();
      this._focusIndex = index - 1;
    } else if (e.key === "ArrowRight" && index < OTP_LENGTH - 1) {
      e.preventDefault();
      this._focusIndex = index + 1;
    } else if (e.key === "Enter" && !this.nextDisabled) {
      e.preventDefault();
      this.emit("next");
    }
  }

  handlePaste(e) {
    const text = (e.clipboardData || window.clipboardData)?.getData("text") || "";
    const digits = text.replace(/\D/g, "");
    if (!digits) return;
    e.preventDefault();
    this.fill(digits, Number(e.target.dataset.index));
  }

  fill(digits, from) {
    const next = [...this.digits];
    let cursor = from;
    for (const ch of digits) {
      if (cursor >= OTP_LENGTH) break;
      next[cursor] = ch;
      cursor += 1;
    }
    this.digits = next;
    this._focusIndex = Math.min(cursor, OTP_LENGTH - 1);
    this.publish();
  }

  publish() {
    this.emit("otpchange", { code: this.digits.join("") });
  }
}