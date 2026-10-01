/**
 * Inline lucide-style icon.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api } from "lwc";

/**
 * Inline lucide-style icon. Usage:
 *   <c-modon-icon name="dollar-sign" size="13" color="#a8a8a8"></c-modon-icon>
 * `name` matches the lucide kebab-case id. Only the glyphs used by the
 * Modon Sales Console are included.
 */
export default class ModonIcon extends LightningElement {
  @api name;
  @api size = 16;
  @api color = "currentColor";
  @api strokeWidth = 2;

  get f() {
    const n = this.name;
    return {
      user: n === "user",
      phone: n === "phone",
      mail: n === "mail",
      mapPin: n === "map-pin",
      clock: n === "clock",
      fileText: n === "file-text",
      chevronRight: n === "chevron-right",
      chevronDown: n === "chevron-down",
      search: n === "search",
      logOut: n === "log-out",
      bell: n === "bell",
      arrowRight: n === "arrow-right",
      plus: n === "plus",
      check: n === "check",
      home: n === "home",
      dollarSign: n === "dollar-sign",
      users: n === "users",
      trendingUp: n === "trending-up",
      creditCard: n === "credit-card",
      download: n === "download",
      refreshCw: n === "refresh-cw",
      hash: n === "hash",
      building: n === "building",
      x: n === "x",
      alertCircle: n === "alert-circle",
      layoutDashboard: n === "layout-dashboard",
      userSquare: n === "user-square",
      clipboardList: n === "clipboard-list",
      bookOpen: n === "book-open",
      wallet: n === "wallet",
      eye: n === "eye",
      eyeOff: n === "eye-off",
      lock: n === "lock",
      atSign: n === "at-sign",
      link: n === "link",
      graduationCap: n === "graduation-cap",
      award: n === "award",
      playCircle: n === "play-circle",
      checkCircle: n === "check-circle",
      sun: n === "sun",
      moon: n === "moon",
      // Added for the Commercial Console.
      map: n === "map",
      folder: n === "folder",
      upload: n === "upload",
      alertTriangle: n === "alert-triangle",
      chevronLeft: n === "chevron-left",
      send: n === "send",
      xCircle: n === "x-circle",
      info: n === "info",
      circle: n === "circle",
      // Added for the one-page booking journey (stepper, KYC, compliance, tour).
      shieldCheck: n === "shield-check",
      maximize: n === "maximize",
      chevronUp: n === "chevron-up",
      calendar: n === "calendar",
      // Added for the Modon Sales Console: per-payment-type proof uploads,
      // direct debit mandates and the required-documents indicator.
      fileCheck: n === "file-check",
      banknote: n === "banknote",
      landmark: n === "landmark",
      repeat: n === "repeat",
      paperclip: n === "paperclip",
      trash: n === "trash"
    };
  }
}