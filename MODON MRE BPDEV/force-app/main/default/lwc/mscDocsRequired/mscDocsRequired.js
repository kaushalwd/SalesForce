/**
 * Required-documents checklist.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.1      Aurelix Dev 17 Aug 2026  THE REP'S OWN NINE, not everybody's thirty-four.
 *                                   Progress instead of a column of "Pending", and the
 *                                   other teams' work stated once as what happens after
 *                                   the handoff rather than listed as if it were owed now.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/**
 * "Further Documents Required" (Modon comment 10).
 *
 * WHAT WAS WRONG
 *
 * It drew every active row of Document_Checklists__mdt - all 34 - so a rep taking a
 * payment was shown 34 obligations of which 25 belonged to Sales Operations, Finance
 * and Customer Management. Those teams only receive the booking later, through the
 * sub-status ladder, so the rep could not act on any of them; there was no grouping
 * and no owner named; and the word "Pending" ran 34 times down the right-hand edge,
 * a column with no information in it.
 *
 * The server now returns the rep's nine as `items` and the rest as a count. So this
 * component shows a checklist a person can finish, says how far through it they are,
 * and states the remainder once, as a fact about what happens next.
 *
 * TWO DIFFERENT THINGS, KEPT APART
 *
 *   furtherRequired  SalesOrder__c.Further_Documents_Required__c - a real flag that
 *                    someone reviewing this booking has asked for more. It is a
 *                    genuine alert and keeps its amber banner.
 *   outstanding      how much of the checklist is simply not done yet. Ordinary
 *                    early in a booking, and not an alert at all.
 *
 * They used to share one banner, so a brand-new booking with nothing filled in
 * shouted "Further Documents Required" at a rep who had done nothing wrong.
 */
export default class MscDocsRequired extends LightningElement {
  /** The SALES team's items only: [{ label, status, received, team, rejectionReason }] */
  @api items = [];
  /**
   * SalesOrder__c.Further_Documents_Required__c. No longer rendered - see 1.4.
   *
   * Not "a reviewer has asked for more": the formula is
   *   Sub_Status__c IN (Pending with Sales, Pending With Sales.,
   *                     Pending With Sales Operation, Pending with CM)
   *   OR Down_Payment_Status__c IN (Partially Collected, Partially Paid)
   *   OR ADM_Fees_and_Dari__c   IN (Partially Collected, Partially Paid)
   */
  @api furtherRequired = false;
  /** How many checks the later teams carry. Stated, never listed. */
  @api laterCount = 0;
  /** Those teams, in handoff order. */
  @api laterTeams = [];

  labels = LABELS;

  /*** 1.2 - COLLAPSED BY DEFAULT ********************************************
   *
   * Nine rows and a 25-check footnote sat permanently between the settlement figure
   * and the obligation ledger - the two things the payment step exists for - so an
   * agent scrolled past a wall of items belonging to a stage that has not started to
   * reach the money. The heading already carries the whole answer ("0 of 9
   * approved"); the rows are detail, and detail on a working screen is something you
   * open.
   *
   * `_touched` records that the agent has decided for themselves. Without it, an
   * item being approved mid-session would yank the panel open under their hands -
   * or slam it shut - every time the poll refreshed.
   */
  _open = false;
  _touched = false;

  /**
   * 1.4 - SHUT ON ARRIVAL, ALWAYS.
   *
   * It used to open itself when Further_Documents_Required__c was on or a document
   * carried a rejection reason. The first of those turned out to be nearly always true
   * - the formula fires on either payment status reading Partially Paid, which every
   * booking does from the moment its fee lands - so "opens only when it matters" meant
   * "opens every time", and a nine-row list was back between the money and the ledger.
   *
   * A rejection reason still renders inside its row, and the progress line states the
   * count while shut, so nothing is hidden that the heading does not account for.
   */
  get open() {
    return this._touched ? this._open : false;
  }

  get openAttr() {
    return this.open ? "true" : "false";
  }

  get chevron() {
    return this.open ? "chevron-up" : "chevron-down";
  }

  get headClass() {
    return this.open ? "chk-head chk-head--open" : "chk-head";
  }

  handleToggle() {
    this._touched = true;
    this._open = !this.open;
  }

  get rows() {
    return (this.items || []).map((d, i) => ({
      key: `${d.label}-${i}`,
      label: d.label,
      received: d.received,
      reason: d.rejectionReason,
      /* A filled tick against a hollow ring: the difference is SHAPE, so it survives
         greyscale and colour blindness, and the state is written out beside it too. */
      icon: d.received ? "check-circle" : "circle",
      iconColor: d.received
        ? "var(--step-done, #16a34a)"
        : "var(--text-dim, #8a8a8a)",
      rowCls: d.received ? "chk-row chk-row--done" : "chk-row",
      nameCls: d.received ? "chk-name chk-name--done" : "chk-name",
      /* Only the finished rows carry a word. Nine rows each labelled "Pending" is
         the same column of noise the 34-row version had, just shorter - and the
         hollow ring already says it. */
      state: d.received ? LABELS.DOCS_RECEIVED : null
    }));
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get doneCount() {
    return this.rows.filter((r) => r.received).length;
  }

  get outstandingCount() {
    return this.rows.length - this.doneCount;
  }

  get allDone() {
    return this.hasRows && this.outstandingCount === 0;
  }

  /** "3 of 9 approved" - one figure, and it counts UP, which is what progress is. */
  get progressText() {
    return LABELS.DOCS_PROGRESS.replace("{0}", this.doneCount).replace(
      "{1}",
      this.rows.length
    );
  }

  get progressCls() {
    return this.allDone ? "chk-progress chk-progress--done" : "chk-progress";
  }

  /* 1.4 - `showAlert` removed with the banner it gated. `furtherRequired` stays on the
     API because the parent still binds it and the DTO still carries it; restoring the
     banner is one template block. */

  /* ── what happens after the handoff ─────────────────────────────────────── */

  get showLater() {
    return Number(this.laterCount || 0) > 0 && (this.laterTeams || []).length > 0;
  }

  /**
   * "25 further checks by Sales Operations, Finance and Customer Management once
   * this booking is handed over."
   *
   * Stated once, in a sentence, rather than listed as 25 rows. The rep cannot do any
   * of them and is not waiting on them today - but they should not be invisible
   * either, because the customer will ask what happens next.
   */
  get laterText() {
    const teams = this.laterTeams || [];
    const names =
      teams.length > 1
        ? `${teams.slice(0, -1).join(", ")} ${LABELS.DOCS_AND} ${teams[teams.length - 1]}`
        : teams[0];
    return LABELS.DOCS_LATER.replace("{0}", this.laterCount).replace("{1}", names);
  }
}