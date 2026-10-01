/**
 * What is still attached to a confirmed booking.
 *
 * Version  Author            Date         Detail
 * 1.0      Aurelix Developer 17 Aug 2026  Initial. Phase 4 of the Screen 3 rebuild.
 */
import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/**
 * WHY THIS COMPONENT EXISTS
 *
 * Confirming a booking is the loudest thing that happens on this screen and, until
 * now, the last. The card said "Booking confirmed" and stopped - while the booking
 * still had money owed on it, a Sales document checklist nobody had touched, and an
 * identity check that had not been sent.
 *
 * All three were ON the screen already, and that was the problem: the money in the
 * ledger, the documents in a collapsed checklist, the identity on a different step
 * entirely. Three regions, three vocabularies, and an agent reopening a booking from
 * Total Sales had to visit all three and hold the answer in their head to work out
 * what a customer on the phone was asking them.
 *
 * One list, in the order the work actually blocks the sale.
 *
 * THE FIRST ITEM IS THE ONLY PRIMARY
 *
 * The design language for this screen allows exactly one primary control visible at a
 * time. So the first row - the most urgent outstanding thing - is the emphasised,
 * obviously-pressable one, and the rest are quiet rows that still navigate. That is
 * the plan's "next action is singular" without hiding the other two from someone who
 * wants to jump straight to them.
 *
 * The parent decides membership and order; this renders it. Everything here is
 * presentation, which is what keeps the ranking in one place (mscBookingPage.stillToDo)
 * rather than split across a component boundary where the two could disagree.
 */
export default class MscStillToDo extends LightningElement {
  /** Ordered list from mscBookingPage.stillToDo. First entry carries isNext. */
  @api items = [];

  labels = LABELS;

  get hasItems() {
    return (this.items || []).length > 0;
  }

  get rows() {
    return (this.items || []).map((it) => ({
      ...it,
      /* The kind drives the icon, not the wording: an agent scanning the list should
         be able to tell money from paperwork before reading either. */
      icon: ICONS[it.kind] || "circle",
      rowClass: it.isNext ? "todo__row todo__row--next" : "todo__row",
      iconColor: it.isNext
        ? "var(--chip-amber, #fbbf24)"
        : "var(--text-dim, #8a8a8a)"
    }));
  }

  handleClick(event) {
    const key = event.currentTarget.dataset.key;
    const item = (this.items || []).find((i) => i.key === key);
    if (!item) {
      return;
    }
    /* Composed, because this crosses out of the card region it is rendered in and the
       page's handler is what owns navigation. */
    this.dispatchEvent(
      new CustomEvent("todojump", {
        detail: { section: item.section, rowId: item.rowId, kind: item.kind }
      })
    );
  }
}

/* The three kinds this list can hold. Deliberately from the icon set the rest of the
   console already uses, so a money row here looks like a money row everywhere else. */
const ICONS = {
  MONEY: "credit-card",
  DOCUMENT: "file-check",
  VERIFICATION: "shield-check"
};