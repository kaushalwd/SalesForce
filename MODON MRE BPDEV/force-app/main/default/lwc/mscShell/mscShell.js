/**
 * Modon Sales Console - app shell.
 *
 * Version  Author      Date         Detail
 * 2.x      Aurelix Dev 18 Sep 2026  MSC-182 (B10). The journey's record is addressed as ?ref= in
 *                                   the URL; ?opp= is still read as an alias for saved links but
 *                                   never written again. A representative's address bar no longer
 *                                   names the engine's object.
 * 1.3      Aurelix Dev 02 Sep 2026  MSC-211. A lead write refreshes the bell badge
 *                                   (`leadschanged` from the leads pane -> c-msc-app-bar.refresh).
 * 1.2      Aurelix IT  31 Aug 2026  MSC-184. Gradient background; the hero render import is gone.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-092. Returning to the hub drops the opportunity too.
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonSalesConsole; tokens from c/mscTokens.
 */

import { LightningElement, api, wire } from "lwc";
import MODON_FAVICON from "@salesforce/resourceUrl/modonFavicon";
import { hostStyle, applyTokens } from "c/mscTokens";
import getMyThemePreference from "@salesforce/apex/SalesConsoleDashboardController.getMyThemePreference";
import saveThemePreference from "@salesforce/apex/SalesConsoleDashboardController.saveThemePreference";
import getMyName from "@salesforce/apex/SalesConsoleDashboardController.getMyName";

/** The hub cards. */
const CARDS = ["units", "leads", "learning", "revenue", "eoi", "alerts"];

/** Pre-redesign routes, kept working. */
const LEGACY_VIEWS = {
  dashboard: "units",
  lead: "leads",
  eoi: "eoi",
  "eoi-payment": "eoi",
  booking: "revenue",
  "payment-confirm": "revenue",
  learning: "learning"
};

/** Renders the background, top bar and footer once; owns the theme, the backdrop and the URL. */
export default class MscShell extends LightningElement {
  @api accentColor = "#a8a8a8";
  @api userName = "Modon";
  @api brandLabel = "Sales";
  @api startScreen = "home";
  @api backgroundImage = "";

  screen = "home";
  // where the rep is, carried in the URL; a null card means the hub
  card = null;
  bookingId = null;
  leadId = null;
  /* the opportunity a journey is open on, so a refresh survives */
  opportunityId = null;
  step = null;
  contextLabel = "";
  theme = "dark";
  _onPopState;

  // the real logged-in user, not the design attribute
  resolvedName;

  @wire(getMyName)
  wiredName({ data }) {
    if (data) {
      this.resolvedName = data;
    }
  }

  get displayName() {
    return this.resolvedName || this.userName;
  }

  @wire(getMyThemePreference)
  wiredTheme({ data }) {
    if (data) {
      this.theme = data === "Light" ? "light" : "dark";
      this.cacheTheme(this.theme);
      this.paintDocument();
    }
  }

  handleThemeToggle() {
    this.theme = this.theme === "dark" ? "light" : "dark";
    this.cacheTheme(this.theme);
    this.paintDocument();
    // optimistic: a failed save costs a preference, not a session
    saveThemePreference({
      theme: this.theme === "light" ? "Light" : "Dark"
    }).catch(() => {});
  }

  /**
   * 1.3: lead work changed what the bell counts (an overdue call dispositioned, a lead handed
   * on), so the badge is re-read here. The bar is a sibling of the workspace, which is why the
   * signal travels up rather than across. One round trip per write; nothing polls, and the
   * alerts panel itself already reads live on every open (MSC-207).
   */
  handleLeadsChanged() {
    const bar = this.template.querySelector("c-msc-app-bar");
    if (bar) {
      bar.refresh();
    }
  }

  /** Paint the tokens onto documentElement too, so platform chrome inherits the palette. */
  paintDocument() {
    try {
      applyTokens(document.documentElement, this.theme, this.accentColor);
    } catch {
      // non-fatal
    }
  }

  // cache locally so a returning user paints the right theme on the first frame
  cacheTheme(theme) {
    try {
      window.localStorage.setItem("msc-theme", theme);
    } catch {
      // private mode
    }
  }
  readCachedTheme() {
    try {
      const t = window.localStorage.getItem("msc-theme");
      return t === "light" || t === "dark" ? t : null;
    } catch {
      return null;
    }
  }

  connectedCallback() {
    // LWR exposes no Site Icon field, so the favicon is set here
    this.applyFavicon();
    const cached = this.readCachedTheme();
    if (cached) {
      this.theme = cached;
    }
    this.paintDocument();
    this.readUrl();
    this._onPopState = this.syncFromUrl.bind(this);
    window.addEventListener("popstate", this._onPopState);
    // replace, not push
    this.updateUrl(true);
  }

  disconnectedCallback() {
    if (this._onPopState) {
      window.removeEventListener("popstate", this._onPopState);
    }
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

  syncFromUrl() {
    this.readUrl();
  }

  /** Read the location out of the URL, translating legacy ?view= values. */
  readUrl() {
    let params;
    try {
      params = new URLSearchParams(window.location.search);
    } catch {
      // progressive enhancement
      this.screen = this.startScreen === "login" ? "login" : "home";
      return;
    }

    const view = params.get("view");
    const legacyCard = LEGACY_VIEWS[view];

    if (view === "login") {
      this.screen = "login";
    } else if (view === "home" || legacyCard) {
      this.screen = "home";
    } else {
      this.screen = this.startScreen === "login" ? "login" : "home";
    }

    const card = params.get("card") || legacyCard;
    this.card = CARDS.indexOf(card) !== -1 ? card : null;

    this.bookingId = params.get("booking") || null;
    this.leadId = params.get("lead") || null;
    /* B10: ref= is written; opp= is read for links saved before 18 Sep 2026 */
    this.opportunityId = params.get("ref") || params.get("opp") || null;
    this.step = params.get("step") || null;

    const legacyId = params.get("id");
    if (legacyId && !this.bookingId && !this.leadId) {
      if (legacyCard === "leads") {
        this.leadId = legacyId;
      } else if (legacyCard === "revenue") {
        this.bookingId = legacyId;
      }
    }
  }

  /** Write the location to the URL; a card change pushes, a step move replaces. */
  updateUrl(replace) {
    if (this.screen === "login") {
      return;
    }
    try {
      const url = new URL(window.location.href);
      const p = url.searchParams;
      p.set("view", "home");
      p.delete("id"); // legacy - never written back
      const setOrDelete = (key, value) => {
        if (value) {
          p.set(key, value);
        } else {
          p.delete(key);
        }
      };
      setOrDelete("card", this.card);
      setOrDelete("booking", this.bookingId);
      setOrDelete("lead", this.leadId);
      setOrDelete("ref", this.opportunityId);
      p.delete("opp"); // legacy alias - read, never written back
      setOrDelete("step", this.step);

      const state = {
        view: "home",
        card: this.card,
        booking: this.bookingId,
        lead: this.leadId,
        ref: this.opportunityId,
        step: this.step
      };
      if (replace) {
        window.history.replaceState(state, "", url.toString());
      } else {
        window.history.pushState(state, "", url.toString());
      }
    } catch {
      // progressive enhancement
    }
  }

  get showNav() {
    return this.screen !== "login";
  }
  get isLogin() {
    return this.screen === "login";
  }
  /** Login scrolls; the console is a fixed shell. */
  get bodyClass() {
    return this.screen === "login" ? "body body--scroll" : "body";
  }

  get rootStyle() {
    return hostStyle(this.theme, this.accentColor);
  }

  /* the gradient lives in the CSS; a configured image still paints over it */
  get bgStyle() {
    return this.backgroundImage
      ? `background-image: url('${this.backgroundImage}');`
      : "";
  }

  /** The workspace reports its location. detail: { card, bookingId, leadId, step, label } */
  handleContextChange(e) {
    const d = e.detail || {};
    // returning to the hub is itself a card change and must push
    const next = d.card || null;
    const cardChanged = next !== this.card;
    this.card = next;
    this.bookingId = d.bookingId || null;
    this.leadId = d.leadId || null;
    /* opening a booking is not navigation: replace */
    this.opportunityId = d.opportunityId || null;
    this.step = d.step || null;
    this.contextLabel = d.label || "";
    this.updateUrl(!cardChanged);
  }

  handleNavigate(e) {
    const d = e.detail;
    const screen = d && typeof d === "object" ? d.screen : d;
    if (screen === "login") {
      // a real logout, relative to the site prefix
      this.logout();
      return;
    }
    this.screen = "home";
    if (screen === "home") {
      // the logo returns to the hub
      this.card = null;
      this.bookingId = null;
      this.leadId = null;
      this.step = null;
      /* MSC-092: and the opportunity, or a refresh from the hub restored another customer's booking */
      this.opportunityId = null;
      this.contextLabel = "";
    } else if (screen === "learning") {
      this.card = "learning";
    } else if (screen === "alerts") {
      // the bell opens the alerts panel
      this.card = "alerts";
    }
    this.updateUrl(false);
  }

  /** Site prefix read from the current path, not hardcoded. */
  logout() {
    try {
      const first = window.location.pathname.split("/").filter(Boolean)[0];
      const prefix = first ? `/${first}` : "";
      window.location.href = `${prefix}/secur/logout.jsp`;
    } catch {
      window.location.href = "/secur/logout.jsp";
    }
  }
}