/**
 * Branded sign-in screen for the Modon Sales Console.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonSiteLogin; authentication stays with the platform.
 * 1.1      Aurelix IT  09 Aug 2026  Stopped covering the platform's sign-in form.
 * 1.2      Aurelix IT  09 Aug 2026  One card: the fields come back here and post to Site.login.
 * 1.3      Aurelix IT  09 Aug 2026  Pinned to the viewport (see the CSS).
 * 1.5      Aurelix IT  31 Aug 2026  MSC-184. Gradient background; the hero render import is gone.
 */

import { LightningElement, api } from "lwc";
import MODON_FAVICON from "@salesforce/resourceUrl/modonFavicon";
import { hostStyle } from "c/mscTokens";
import login from "@salesforce/apex/SalesConsoleAuthController.login";

/**
 * The approved login screen: one glass card over the hero render.
 *
 * The fields are here (1.2) because the platform form looked nothing like the card. Safe because
 * SalesConsoleAuthController only calls Site.login; lockout, MFA and the rest stay with the
 * platform, and the password is cleared on failure. The PoC's loginAs(persona) stays refused.
 * Continue skips the password for anyone who already holds a session.
 */
export default class MscSiteLogin extends LightningElement {
  @api brandLabel = "Sales";
  @api accentColor = "#a8a8a8";

  username = "";
  password = "";
  errorMsg;
  busy = false;
  showPassword = false;

  connectedCallback() {
    // the login route renders instead of the shell, so the favicon is set here too
    this.applyFavicon();
  }

  applyFavicon() {
    try {
      const head = document.head;
      if (!head) {
        return;
      }
      let link = head.querySelector("link[rel~='icon']");
      if (!link) {
        link = document.createElement("link");
        link.rel = "icon";
        head.appendChild(link);
      }
      link.type = "image/png";
      link.href = MODON_FAVICON;
    } catch {
      // non-fatal
    }
  }

  get rootStyle() {
    // login is always dark: guest context, no saved preference
    return hostStyle("dark", this.accentColor);
  }

  // form

  handleUsername(e) {
    this.username = e.target.value;
    this.errorMsg = undefined;
  }

  handlePassword(e) {
    this.password = e.target.value;
    this.errorMsg = undefined;
  }

  /** Enter submits from either field. */
  handleKey(e) {
    if (e.key === "Enter") {
      this.handleLogin();
    }
  }

  get passwordType() {
    return this.showPassword ? "text" : "password";
  }
  get toggleIcon() {
    return this.showPassword ? "eye-off" : "eye";
  }
  get toggleLabel() {
    return this.showPassword ? "Hide password" : "Show password";
  }
  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  get signInLabel() {
    return this.busy ? "Signing in…" : "Sign in";
  }

  /** Site prefix read from the current path, not hardcoded. */
  get sitePrefix() {
    try {
      const first = window.location.pathname.split("/").filter(Boolean)[0];
      return first && first !== "login" ? `/${first}` : "";
    } catch {
      return "";
    }
  }

  async handleLogin() {
    if (this.busy) {
      return;
    }
    if (!this.username || !this.password) {
      this.errorMsg = "Enter your username and password.";
      return;
    }
    this.busy = true;
    this.errorMsg = undefined;
    try {
      const url = await login({
        username: this.username.trim(),
        password: this.password,
        startUrl: `${this.sitePrefix}/?view=home`
      });
      if (url) {
        // never clear the password before navigating: the browser needs it for its save prompt
        window.location.href = url;
        return;
      }
      // one message for every failure; the controller does not say which
      this.errorMsg = "That username and password did not match. Please try again.";
      this.password = "";
    } catch {
      this.errorMsg = "Sign-in is unavailable right now. Please try again.";
      this.password = "";
    } finally {
      this.busy = false;
    }
  }

  /** The platform's own reset flow. */
  handleForgot() {
    window.location.href = `${this.sitePrefix}/ForgotPassword`;
  }

  /** Hand off to the console for someone who already holds a session. */
  handleContinue() {
    window.location.href = `${this.sitePrefix}/?view=home`;
  }
}