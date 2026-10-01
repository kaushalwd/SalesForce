/**
 * The one question asked when a booking leaves Verification with a unit nobody
 * co-owns.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-081, phase 2 of the joint owner module.
 *
 * AN ACKNOWLEDGEMENT, NEVER A BLOCK. 36% of multi-unit bookings that have a joint
 * owner have at least one unit with none - 33 units in PREPROD. Some of those are
 * deliberate: a real booking in the org puts one child on each of four villas and
 * keeps the fifth for the primary owner alone. No code can tell that apart from an
 * omission, so this asks rather than refuses. A correct booking must never be
 * slower to enter than a careless one.
 *
 * ASKED ONCE PER BOOKING. mscBookingPage remembers the answer. A dialog that
 * reappears is a dialog that gets dismissed unread.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

export default class MscOwnersGate extends LightningElement {
  @api open = false;
  /** The unit names, from OwnersDTO.unitsWithNoJointOwner. */
  @api units;
  /** The primary owner's name, so the claim names a person. */
  @api primaryName;

  labels = LABELS;

  get list() {
    return this.units || [];
  }

  get title() {
    return this.list.length === 1
      ? LABELS.JO_GATE_TITLE_ONE
      : fill(LABELS.JO_GATE_TITLE, this.list.length);
  }

  /** Named, not counted. "3 units" alone would send the rep hunting for which. */
  get unitList() {
    const n = this.list;
    if (n.length <= 1) return n.join("");
    return `${n.slice(0, -1).join(", ")} and ${n[n.length - 1]}.`;
  }

  get bodyText() {
    return fill(LABELS.JO_GATE_BODY, this.primaryName || "");
  }

  get confirmText() {
    return this.list.length === 1
      ? LABELS.JO_GATE_CONFIRM_ONE
      : LABELS.JO_GATE_CONFIRM;
  }

  renderedCallback() {
    if (!this.open || this._focused) return;
    const first = this.template.querySelector(".og__sm");
    if (first) {
      first.focus({ preventScroll: true });
      this._focused = true;
    }
  }

  /* A decision is being asked of the rep, so - unlike c/mscDrawer, which shows a
     document they opened to read - clicking away does not answer it. */
  handleScrim() {}

  stop(event) {
    event.stopPropagation();
  }

  /**
   * Escape is the same as "add them now": it withdraws the question rather than
   * answering it, so the acknowledgement is never recorded by a keypress.
   *
   * stopPropagation for the reason c/mscDrawer records - modonSheet listens on the
   * window, so without it one press would close this AND the whole booking behind it.
   */
  handleKeydown(event) {
    if (event.key !== "Escape") return;
    event.preventDefault();
    event.stopPropagation();
    this.handleAdd();
  }

  handleAdd() {
    this._focused = false;
    this.dispatchEvent(new CustomEvent("gateadd"));
  }

  handleConfirm() {
    this._focused = false;
    this.dispatchEvent(new CustomEvent("gateconfirm"));
  }
}