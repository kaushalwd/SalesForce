/**
 * A side drawer for the Sales Console.
 *
 * Version  Author              Date         Detail
 * 1.0      Aurelix Developer   16 Aug 2026  Initial.
 * 2.0      Aurelix Developer   16 Aug 2026  REBUILT. It is positioned by WHERE IT IS
 *                                           MOUNTED, and nothing else.
 * 2.1      Aurelix Developer   16 Aug 2026  The motion. A longer, decelerating entry;
 *                                           an animated exit; the scrim split onto its
 *                                           own element and its backdrop blur dropped,
 *                                           so the journey behind holds perfectly still
 *                                           while the panel travels. See the CSS.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHERE THIS MUST BE MOUNTED, AND WHY IT IS NOT NEGOTIABLE.
 *
 * A DIRECT CHILD OF mscBookingPage's `.page` - beside c-msc-verify-choice, which
 * is there for the same reason. Never inside a card.
 *
 * `position: fixed` escapes to the viewport only while no ancestor establishes a
 * containing block, and this journey is full of them:
 *
 *   .section          backdrop-filter: blur(22px)  - EVERY card in the journey
 *   .section__body    overflow-y: auto             - the step-2 pair
 *   modonSheet .panel transform + overflow: hidden - the sheet itself
 *
 * Version 1.0 was mounted inside the Payment Plan card and hit the first two at
 * once: the card became the containing block, the scrolling body clipped it, and
 * the drawer rendered as a pane inside one column of step 2. A measuring probe
 * was added to correct the offset and could not help - an offset is not a clip.
 *
 * Mounted at `.page`, the nearest containing block is the sheet's own panel. The
 * drawer covers the whole booking and stops at its edge, which is correct: the
 * panel sets `overflow: hidden`, so nothing rendered inside this journey can
 * escape it, and a drawer that belongs to a booking should not want to.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * BEHAVIOUR is the Broker Portal's mbpr_detailDrawer: scrim, Escape, a focus trap
 * that walks slotted content, and focus returned to whatever opened it. The LOOK
 * is this console's - mscStyles and mscTokens, not the portal's cream --mbpr-*
 * palette - so a drawer over the booking reads as part of it.
 *
 * IT OWNS NO CONTENT. Header, body and footer are slots.
 */

import { LightningElement, api } from "lwc";

/**
 * How long the drawer stays in the DOM after it is closed, so the exit can play.
 *
 * MUST match the exit durations in the CSS (.layer--closing). Shorter and the
 * panel is cut off mid-travel; longer and the journey underneath sits behind an
 * invisible, un-clickable layer for the difference.
 */
const EXIT_MS = 320;

export default class MscDrawer extends LightningElement {
  /**
   * 2.1 - an accessor rather than a plain field, so closing can be animated.
   *
   * `open` on its own unmounts the markup on the frame it goes false, which gives
   * the exit nothing to animate. What renders is `mounted`, which lags it by the
   * length of the exit.
   */
  _open = false;
  mounted = false;
  closing = false;
  _exitTimer = null;

  @api
  get open() {
    return this._open;
  }
  set open(value) {
    const next = !!value;
    if (next === this._open) {
      return;
    }
    this._open = next;
    if (next) {
      /* Re-opened during its own exit: cancel it and start clean, rather than
         letting the old timer unmount the drawer that was just asked for. */
      this.clearExit();
      this.closing = false;
      this._focusedOnOpen = false;
      this.mounted = true;
      return;
    }
    if (!this.mounted) {
      return;
    }
    this.closing = true;
    /* Now, not on unmount: focus is still inside the drawer at this point, and
       moving it back while the opener is definitely still there beats letting it
       fall to the body when the markup goes. */
    this.restoreFocus();
    this._exitTimer = setTimeout(() => {
      this._exitTimer = null;
      this.closing = false;
      this.mounted = false;
    }, EXIT_MS);
  }

  clearExit() {
    if (this._exitTimer) {
      clearTimeout(this._exitTimer);
      this._exitTimer = null;
    }
  }

  get layerClass() {
    return this.closing ? "layer layer--closing" : "layer";
  }

  @api drawerTitle;
  /** One line under the title, for context the title should not carry. */
  @api subtitle;
  /** 'standard' | 'wide'. Wide is for a document; standard is for a form. */
  @api size = "standard";
  /**
   * Whether the caller fills the footer slot. Declared rather than detected: the
   * CSS test for an unfilled slot is :has(), and a browser that cannot parse it
   * drops the rule and leaves a bordered empty strip on every drawer.
   */
  @api hasFooter = false;

  _focusedOnOpen = false;
  _previousFocus = null;

  get drawerClass() {
    return `drawer drawer--${this.size === "wide" ? "wide" : "standard"}`;
  }

  get showSubtitle() {
    return !!this.subtitle;
  }

  /**
   * Focus moves into the drawer on open and back out on close.
   *
   * The close button rather than the first field: a drawer that lands the cursor
   * in a text input has already decided the rep wants to type, and the commonest
   * reason to open this one is to LOOK at the document.
   */
  renderedCallback() {
    /* Not while closing: focus has already been handed back, and pulling it into a
       panel that is on its way out would take it straight off the screen. */
    if (!this.mounted || this.closing || this._focusedOnOpen) {
      return;
    }
    const close = this.template.querySelector(".drawer__close");
    if (close) {
      this._previousFocus = document.activeElement;
      /* preventScroll, and this is what stopped the journey behind the drawer
         twitching as it opened. focus() scrolls its target into view by default,
         walking every scrollable ancestor to do it - and this button's ancestors
         are the step-2 card bodies and the sheet's own scroll column. The drawer
         is fixed and already fully on screen, so there was nothing to scroll TO:
         the browser simply moved the journey underneath by a few pixels on the
         frame the drawer appeared. */
      close.focus({ preventScroll: true });
      this._focusedOnOpen = true;
    }
  }

  disconnectedCallback() {
    this.clearExit();
    this.restoreFocus();
  }

  restoreFocus() {
    const prev = this._previousFocus;
    this._previousFocus = null;
    if (!prev || typeof prev.focus !== "function") {
      return;
    }
    try {
      /* preventScroll here too: the opener is the Preview button inside a card
         that scrolls, so restoring focus on close would jump that card back to
         it - the same twitch as opening, in reverse. */
      prev.focus({ preventScroll: true });
    } catch (e) {
      /* The opener can be gone - the card unmounts when the step changes. Losing
         focus to the body is the correct outcome then, not an error. */
    }
  }

  handleClose() {
    if (this.closing) {
      return;
    }
    this.dispatchEvent(new CustomEvent("close"));
  }

  /* The scrim closes it. Unlike the verification dialog, nothing here is a
     decision being asked of the rep - this is a document they opened to read, and
     clicking away from it means what it always means. */
  handleScrim() {
    this.handleClose();
  }

  stop(event) {
    event.stopPropagation();
  }

  /**
   * Escape closes, and Tab cannot leave.
   *
   * stopPropagation on Escape matters here for the same reason it does in
   * mscUnitSelect: modonSheet listens on the window, so without it one keypress
   * would close the drawer AND the whole booking journey behind it.
   */
  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.handleClose();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const focusable = this.focusable();
    if (focusable.length < 2) {
      return;
    }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = this.template.activeElement;
    if (event.shiftKey && active === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  }

  /**
   * Shadow content AND slotted content. The body of this drawer is entirely
   * slotted, so a trap that only walked its own template would let Tab escape on
   * the first press - which is the bug this walk exists to prevent.
   */
  focusable() {
    const root = this.template.querySelector(".drawer");
    if (!root) {
      return [];
    }
    const sel =
      'button, [href], input, select, textarea, iframe, [tabindex]:not([tabindex="-1"])';
    const own = Array.from(root.querySelectorAll(sel));
    const slotted = Array.from(this.template.querySelectorAll("slot")).flatMap((slot) =>
      slot.assignedElements({ flatten: true }).flatMap((el) => {
        const nested = el.querySelectorAll ? Array.from(el.querySelectorAll(sel)) : [];
        return el.matches && el.matches(sel) ? [el, ...nested] : nested;
      })
    );
    return [...own, ...slotted].filter(
      (el) => !el.disabled && el.getAttribute("aria-hidden") !== "true"
    );
  }
}