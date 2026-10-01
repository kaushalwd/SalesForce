/**
 * Console top bar: logo, context label, profile menu, theme toggle.
 *
 * Version  Author      Date         Detail
 * 1.2      Aurelix Dev 02 Sep 2026  MSC-211. The badge can be re-read: the wired result is
 *                                   held and `refresh()` (public) calls refreshApex, so work
 *                                   that changes the count updates the bell without a page
 *                                   reload. Event-driven; nothing polls.
 * 1.1      Aurelix Dev 31 Aug 2026  MSC-189. The bell wears its badge: pending approvals +
 *                                   overdue calls (SalesConsoleNotificationController.getAlertCount,
 *                                   an Apex formula that existed unwired since 1.0). No badge at zero.
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonAppBar.
 */

import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getAlertCount from "@salesforce/apex/SalesConsoleNotificationController.getAlertCount";

/**
 * The nav tabs went with the one-page redesign; the bar carries `contextLabel` instead.
 */
export default class MscAppBar extends LightningElement {
  @api showNav = false;
  @api userName = "Aurelix Admin";
  @api brandLabel = "Sales";
  @api theme = "dark";
  /** Current location; hidden below 768px. */
  @api contextLabel = "";

  /** Whether the profile menu is open. */
  menuOpen = false;

  /** Pending approvals + overdue calls; 0 (no badge) until the wire lands. */
  alertCount = 0;

  /** 1.2: the wired result is held so refresh() can re-read it (getAlertCount is cacheable). */
  _wiredCount;

  @wire(getAlertCount)
  wiredCount(result) {
    this._wiredCount = result;
    /* a failed count is a silent bell, never an error state */
    this.alertCount = typeof result.data === "number" ? result.data : 0;
  }

  /**
   * 1.2: re-read the badge after work that changes it - dispositioning an overdue call, say.
   * Event-driven only: no polling, one round trip per write, and a failure leaves the badge
   * exactly as it was.
   */
  @api
  refresh() {
    if (this._wiredCount) {
      refreshApex(this._wiredCount).catch(() => {
        /* a stale badge is better than an error state on the bell */
      });
    }
  }

  get showBadge() {
    return this.alertCount > 0;
  }
  get badgeText() {
    return this.alertCount > 99 ? "99+" : String(this.alertCount);
  }

  get hasContext() {
    return this.showNav && !!this.contextLabel;
  }

  get avatarInitial() {
    return (this.userName || "A").trim().charAt(0).toUpperCase();
  }

  // show the icon for the theme you would switch to
  get themeIcon() {
    return this.theme === "light" ? "moon" : "sun";
  }
  get themeTitle() {
    return this.theme === "light" ? "Switch to dark" : "Switch to light";
  }

  handleNav(e) {
    const screen = e.currentTarget.dataset.screen;
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: screen,
        bubbles: true,
        composed: true
      })
    );
  }

  handleThemeToggle() {
    // leave the menu open so the rep sees the reskin
    this.dispatchEvent(
      new CustomEvent("themetoggle", { bubbles: true, composed: true })
    );
  }

  // profile menu
  toggleMenu() {
    this.menuOpen = !this.menuOpen;
  }
  closeMenu() {
    this.menuOpen = false;
  }
  handleMenuKey(e) {
    if (e.key === "Escape") {
      this.menuOpen = false;
    }
  }
  handleLogout(e) {
    this.closeMenu();
    this.handleNav(e);
  }
}