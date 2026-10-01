/**
 * Renderless - paints tokens on :root.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api } from "lwc";
import { applyTokens, DEFAULT_ACCENT } from "c/mscTokens";

/**
 * Renderless theme host. Two jobs, both outside our own shadow tree:
 *
 * 1. Paint tokens onto documentElement, so the .comm-* wrappers Experience Cloud
 *    renders outside every shadow root use our palette if they ever paint.
 * 2. Inject the wrapper-neutralising CSS at runtime.
 *
 * (2) is a safety net, not the primary mechanism - styles.css in the site bundle is.
 * The bundle stylesheet lags a save inside the Builder preview iframe, and the
 * platform occasionally renames a wrapper class. Idempotent, and a no-op when the
 * bundle CSS already did the job. Precedent: portalTheme.injectGlobalLayoutFix().
 */

const STYLE_ID = "msc-global-layout-fix";

const GLOBAL_CSS = `
  .comm-section,
  .comm-section-container,
  .comm-layout-column {
    margin: 0 !important;
    padding: 0 !important;
    max-width: none !important;
    width: 100% !important;
    background: transparent !important;
  }
  body,
  .siteforceContentArea,
  .cCenterPanel,
  .forceCommunityThemeLayout {
    background: var(--msc-page-bg, #000) !important;
  }
`;

export default class MscTokenHost extends LightningElement {
  /** 'dark' | 'light'. Dark is the default and the hero experience. */
  @api theme = "dark";
  /** Accent colour; defaults to the restrained platinum-grey, not a literal gold. */
  @api accentColor = DEFAULT_ACCENT;

  _applied = false;

  connectedCallback() {
    this.paint();
    this.injectGlobalFix();
  }

  renderedCallback() {
    // The theme can change after mount (user toggles), and @api setters fire
    // before connectedCallback on first render, so repaint rather than trusting
    // a single pass.
    this.paint();
  }

  disconnectedCallback() {
    // Deliberately leaves the injected <style> in place: other console pages in
    // the same SPA session rely on it, and removing it would flash the stock
    // white wrappers during navigation.
    this._applied = false;
  }

  paint() {
    if (typeof document === "undefined") return;
    applyTokens(document.documentElement, this.theme, this.accentColor);
  }

  injectGlobalFix() {
    if (typeof document === "undefined") return;
    if (this._applied || document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = GLOBAL_CSS;
    document.head.appendChild(style);
    this._applied = true;
  }
}