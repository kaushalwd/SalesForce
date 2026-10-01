/**
 * The console's one overlay primitive.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-216. explicit-close: a sheet that closes only through
 *                                   its own close control - backdrop clicks and Escape do
 *                                   nothing. Opt-in per instance; default behaviour unchanged.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api } from "lwc";

/**
 * The console's one overlay primitive - the hub is the only page, everything else is
 * a sheet above it.
 *
 * Must be a SIBLING of the hub, not a child. The hub scales and blurs as this opens,
 * and both transform and filter create a containing block for position:fixed - as a
 * descendant this would size itself to the hub instead of the viewport.
 *
 * Closing is a request, not an action: `closerequest` fires and the parent decides,
 * which is what lets the journey interrupt with "discard this booking?".
 */
export default class ModonSheet extends LightningElement {
  @api title = "";
  @api subtitle = "";
  /** Opt in to the sticky action bar. See the note in the template. */
  @api hasFooter = false;
  /**
   * 'default'   - centred 1180x780. Lists and tables.
   * 'immersive' - inset 40px, capped 1600x1000. For the booking journey, where
   *               the virtual tour is the canvas and needs real size.
   */
  @api size = "default";
  /**
   * 'dialog' - the default overlay (centred dialog / inset card / bottom sheet).
   * 'drawer' - docks to the RIGHT and slides in from the right on ≥768; on phone
   *            it falls back to the same full-screen bottom sheet as 'dialog'.
   */
  @api variant = "dialog";

  /**
   * MSC-216. True: the sheet closes only through its own close control - a backdrop click or
   * Escape raises nothing, so a stray click cannot lose half-done work. The parent's own
   * `open` and playClose() are untouched. Default false: today's light-dismiss behaviour.
   */
  @api explicitClose = false;

  @api
  get open() {
    return this._open;
  }
  set open(v) {
    const next = !!v;
    if (next === this._open) {
      return;
    }
    if (next) {
      this._open = true;
      this.closing = false;
      this._focused = false;
    } else if (this._open) {
      // Don't drop it yet - play the exit first. animationend finishes the job.
      this.closing = true;
    }
  }
  _open = false;

  closing = false;
  _focused = false;

  connectedCallback() {
    this._onKey = this.handleKeydown.bind(this);
    window.addEventListener("keydown", this._onKey);
  }

  disconnectedCallback() {
    if (this._onKey) {
      window.removeEventListener("keydown", this._onKey);
    }
  }

  renderedCallback() {
    if (this._open && !this.closing && !this._focused) {
      const panel = this.template.querySelector(".panel");
      if (panel) {
        panel.focus();
        this._focused = true;
      }
    }
  }

  get isRendered() {
    return this._open;
  }
  get backdropClass() {
    return this.closing ? "backdrop backdrop--closing" : "backdrop";
  }
  get panelClass() {
    let c = this.size === "immersive" ? "panel panel--immersive" : "panel";
    if (this.variant === "drawer") {
      c += " panel--drawer";
    }
    if (this.closing) {
      c += " panel--closing";
    }
    return c;
  }
  get hasSubtitle() {
    return !!this.subtitle;
  }

  /**
   * Exit animation finished. Guarded on the panel itself - descendants animate too
   * and their animationend bubbles through here.
   */
  handleAnimationEnd(e) {
    if (!this.closing || !e.target.classList.contains("panel")) {
      return;
    }
    this._open = false;
    this.closing = false;
    this.dispatchEvent(new CustomEvent("closed"));
  }

  handleKeydown(e) {
    /* MSC-216: an explicit-close sheet ignores Escape; only its close control asks */
    if (this.explicitClose) {
      return;
    }
    if (e.key === "Escape" && this._open && !this.closing) {
      this.requestClose();
    }
  }

  /** Backdrop clicks only count on the backdrop itself, never bubbling up
      from inside the panel. */
  handleBackdrop(e) {
    /* MSC-216: and ignores the backdrop */
    if (this.explicitClose) {
      return;
    }
    if (e.target === e.currentTarget) {
      this.requestClose();
    }
  }

  requestClose() {
    this.dispatchEvent(new CustomEvent("closerequest"));
  }

  /** Escape hatch for a parent that wants the exit motion without waiting for
      its own `open` round trip. */
  @api
  playClose() {
    if (this._open) {
      this.closing = true;
    }
  }
}