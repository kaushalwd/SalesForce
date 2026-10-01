/**
 * The rail panel for a multi-unit booking.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 * 1.1      Aurelix IT  12 Aug 2026  SUPERSEDED - no longer rendered anywhere.
 *                                   c-msc-booking-summary now covers a basket too, in its
 *                                   Units group, because keeping two recaps of the same
 *                                   booking let them drift: this one never gained the
 *                                   customer block the other has had since 1.0. Left in
 *                                   place rather than deleted - removing deployed metadata
 *                                   is a destructive change and belongs in its own run.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/**
 * What c-msc-booking-summary shows for one unit, this shows for a basket.
 *
 * It exists because BookingSummaryDTO describes ONE unit and one plan, so the
 * summary rail was simply hidden whenever two or more units were ticked. That left
 * a basket agent with no running total and no per-unit plan status anywhere until
 * the Review section at the very bottom of the page - the one place it is too late
 * to notice that unit three still has no payment plan.
 *
 * Presentational only. Every row is built by the journey from state it already
 * holds, so there is no second source of truth for the basket and no extra Apex.
 */
export default class MscBasketSummary extends LightningElement {
  /** [{ id, name, price, planName, planCls }] */
  @api rows = [];
  /** Already formatted - the journey owns the currency. */
  @api total;

  labels = LABELS;

  get hasRows() {
    return (this.rows || []).length > 0;
  }

  get countLabel() {
    const n = (this.rows || []).length;
    return `${n} units`;
  }

  /**
   * Rows jump to the unit section rather than the plan section. Plan is where an
   * incomplete basket has to be fixed, but the unit is what the agent is looking
   * for when they read a row - and section 3 is directly beside section 2 anyway.
   */
  handleJump(event) {
    this.dispatchEvent(
      new CustomEvent("jumpto", {
        detail: { key: event.currentTarget.dataset.section }
      })
    );
  }
}