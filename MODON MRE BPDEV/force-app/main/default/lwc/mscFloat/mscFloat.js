/**
 * mscFloat - puts a console-drawn popover next to its trigger, the way the browser places a
 * native select's list: against the window, above every scrolling box, never taller than the
 * room it has.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 21 Sep 2026  Shared by c/mscPicklist and c/mscDatePicker. An absolutely placed
 *                                   panel inside the booking form was clipped by the form's own
 *                                   scroll box: opening upward in a short modal, the list's top -
 *                                   where the search box is - was cut off until typing shrank it
 *                                   (seen in testing, 21 Sep). The panel is now position: fixed. Where an
 *                                   ancestor has a transform or a backdrop-filter (mscShell's .glass
 *                                   does), `fixed` is measured from that ancestor instead of the
 *                                   window, so the real origin is measured once and allowed for.
 *                                   While open the panel follows its trigger every frame, so a
 *                                   scrolling form carries it along, and it closes when the trigger
 *                                   leaves the window.
 * 1.1      Aurelix Dev 21 Sep 2026  outsideClicks(): the "click elsewhere closes it" rule. Both controls
 *                                   asked event.composedPath() whether a document-level mousedown
 *                                   included their host. On the site it never does, so every click
 *                                   INSIDE a panel counted as outside: the calendar closed on its
 *                                   month title and arrows, the list on its search box and scrollbar
 *                                   (browser test, SCW-135). Now the control's own root marks its
 *                                   mousedowns, and the document waits until the event has finished
 *                                   before deciding. Nothing depends on object identity.
 * 1.2      Aurelix Dev 21 Sep 2026  The panel opens as a popover, in the browser's top layer. 1.0's
 *                                   `fixed` did not escape the booking pop-up: a .section or .glass
 *                                   card's backdrop-filter makes the card the panel's containing
 *                                   block, so the booking body's scroll box still cut it off - the
 *                                   reason c/mscPicklist and c/mscDatePicker were withdrawn (SCW-137).
 *                                   The top layer sits over the whole page and no ancestor can clip
 *                                   it; no z-index is involved. Where the Popover API is missing or
 *                                   refused, the panel is placed exactly as in 1.1.
 */

const GAP = 6; // between trigger and panel
const EDGE = 8; // kept clear of the window's edge

function viewport() {
  return {
    w: window.innerWidth || document.documentElement.clientWidth,
    h: window.innerHeight || document.documentElement.clientHeight
  };
}

/** Where a fixed box at 0,0 really lands: the window, or a transformed / filtered ancestor. */
function fixedOrigin(panel) {
  const top = panel.style.top;
  const left = panel.style.left;
  panel.style.top = "0px";
  panel.style.left = "0px";
  const b = panel.getBoundingClientRect();
  panel.style.top = top;
  panel.style.left = left;
  return { top: b.top, left: b.left };
}

/**
 * Moves the panel into the browser's top layer. Returns false, leaving the panel as it was,
 * where the Popover API is missing (older browsers, Lightning Locker) or refuses the call.
 */
function lift(panel) {
  if (typeof panel.showPopover !== "function") {
    return false;
  }
  try {
    panel.setAttribute("popover", "manual");
    panel.showPopover();
    return true;
  } catch {
    /* a panel left with the attribute but not shown would be display: none */
    panel.removeAttribute("popover");
    return false;
  }
}

/** Takes a lifted panel out of the top layer. A panel already removed with its template is hidden by the browser. */
function lower(panel) {
  if (panel.isConnected && panel.matches(":popover-open")) {
    panel.hidePopover();
  }
}

/**
 * One placement. `opts`: want (preferred height), max, min, matchWidth, width.
 * Returns { up, gone } - gone when the trigger is out of the window.
 */
function place(trigger, panel, opts, origin) {
  const r = trigger.getBoundingClientRect();
  const v = viewport();
  if (r.bottom <= 0 || r.top >= v.h || r.width === 0) {
    return { up: false, gone: true };
  }
  const below = v.h - r.bottom - GAP - EDGE;
  const above = r.top - GAP - EDGE;
  const want = Math.min(opts.max, opts.want || opts.max);
  const up = below < want && above > below;
  const room = Math.max(opts.min || 0, up ? above : below);
  panel.style.maxHeight = Math.min(opts.max, room) + "px";
  if (opts.matchWidth) {
    panel.style.width = r.width + "px";
  } else if (opts.width) {
    panel.style.width = opts.width + "px";
  }
  const ph = panel.offsetHeight;
  const pw = panel.offsetWidth;
  const top = up ? r.top - GAP - ph : r.bottom + GAP;
  let left = r.left;
  if (left + pw > v.w - EDGE) left = Math.max(EDGE, v.w - EDGE - pw);
  panel.style.top = top - origin.top + "px";
  panel.style.left = left - origin.left + "px";
  panel.style.visibility = "visible";
  return { up, gone: false };
}

/**
 * Places `panel` beside `trigger` and keeps it there until the returned stop() is called.
 * `onGone` runs if the trigger leaves the window.
 */
export function follow(trigger, panel, opts, onGone) {
  if (!trigger || !panel) return () => {};
  /* before measuring: in the top layer the window is the origin, and fixedOrigin() finds 0,0 */
  const lifted = lift(panel);
  let origin = fixedOrigin(panel);
  let stopped = false;
  let frame = 0;
  let lastKey = "";
  const onResize = () => {
    origin = fixedOrigin(panel);
    lastKey = "";
  };
  window.addEventListener("resize", onResize);
  const tick = () => {
    if (stopped) return;
    const r = trigger.getBoundingClientRect();
    /* re-place only when the trigger has moved or resized */
    const key = `${Math.round(r.top)}:${Math.round(r.left)}:${Math.round(r.width)}:${panel.offsetHeight}`;
    if (key !== lastKey) {
      lastKey = key;
      const res = place(trigger, panel, opts, origin);
      if (res.gone) {
        stop();
        if (onGone) onGone();
        return;
      }
    }
    frame = window.requestAnimationFrame(tick);
  };
  function stop() {
    stopped = true;
    if (frame) window.cancelAnimationFrame(frame);
    window.removeEventListener("resize", onResize);
    if (lifted) lower(panel);
  }
  place(trigger, panel, opts, origin);
  frame = window.requestAnimationFrame(tick);
  return stop;
}

/** The query the console's other components use for a touch screen. */
export function isTouch() {
  try {
    return !!(window.matchMedia && window.matchMedia("(pointer: coarse)").matches);
  } catch (e) {
    return false;
  }
}

/**
 * Closes a popover on a mousedown anywhere else. The control calls inside() from a mousedown
 * handler on its own root element. The document hears every mousedown first (capture), but the
 * decision waits for the event to finish, by which time inside() has run if the mousedown was
 * on the control. arm() when the panel opens, disarm() when it closes.
 */
export function outsideClicks(onOutside) {
  let armed = false;
  let pending = false;
  const listener = () => {
    pending = true;
    setTimeout(() => {
      if (pending && armed) onOutside();
      pending = false;
    }, 0);
  };
  return {
    arm() {
      if (armed) return;
      armed = true;
      document.addEventListener("mousedown", listener, true);
    },
    disarm() {
      pending = false;
      if (!armed) return;
      armed = false;
      document.removeEventListener("mousedown", listener, true);
    },
    inside() {
      pending = false;
    }
  };
}