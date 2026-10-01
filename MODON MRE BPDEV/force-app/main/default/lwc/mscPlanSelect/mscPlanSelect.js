/**
 * Section 3 - Payment Plan.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.4      Aurelix IT  11 Aug 2026  Pills, not cards. The plan is the third answer on this
 *                                   screen and was rendered at several times the weight of
 *                                   the two above it; it now uses the same .pill classes.
 * 1.5      Aurelix Dev 16 Aug 2026  It says when it is loading, in its own pane.
 * 1.6      Aurelix Dev 20 Aug 2026  MSC-093 - the card opens on the first plan.
 * 1.8      Aurelix Dev 25 Aug 2026  MSC-174. THE FIRST PLAN IS NO LONGER PROPOSED
 *                                   WHERE THERE IS A CHOICE. MSC-093 proposed one on
 *                                   every unit; on a unit offering fourteen that is an
 *                                   answer picked by list order that the agent never
 *                                   gave, and the schedule under it looks exactly like
 *                                   a schedule somebody chose. A unit with ONE plan
 *                                   keeps 1.6's behaviour - there is no choice to make.
 *                                   Nothing downstream changes: structuralBlockers,
 *                                   barDisabled, offerBlockedReason and
 *                                   checkPlanSchedule all already handle an unchosen
 *                                   plan. The empty row is now the normal first view,
 *                                   so it is drawn as a prompt rather than in the
 *                                   weight of a real plan name.
 * 1.7      Aurelix Dev 25 Aug 2026  MSC-173. THE PILLS BECOME A SEARCHABLE LIST.
 *                                   A Hudayriyat unit offers fourteen plans and 1.4 drew
 *                                   them as wrapping pills - five rows of them, so the
 *                                   schedule those plans produce was pushed off the
 *                                   screen on the one card whose whole point is reading
 *                                   the two together. Names like "Golf - 17 Milestones
 *                                   Semi-Annual" cannot be scanned in a wrapped row.
 *                                   Now: a full-width filter over a single-column list,
 *                                   one plan per line, milestone count on the right.
 *                                   The filter is ABSENT when locked or when there is
 *                                   one plan - a search box over a list nobody can
 *                                   change is a control that does nothing. Selection,
 *                                   the planchange event and MSC-093's first-plan
 *                                   proposal are untouched; the proposal still reads the
 *                                   UNFILTERED list, or typing would change what the
 *                                   card proposes.
 * 1.10     Aurelix Dev 30 Sep 2026  The schedule's table follows the card's width and keeps the amount whole
 *                                   (CSS). A missing due date reads "Not set", a missing percentage is empty.
 */

import { LightningElement, api } from "lwc";
import { formatAED, formatDate } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";

/**
 * Section 3 - Payment Plan. Cards and the resulting milestone schedule inline, on the
 * same screen as customer information. The schedule comes from the plan template's
 * percentages against the unit price, so it is visible before any Sales Order exists.
 *
 * Locks once one is created: the schedule is then written to SalesOrderInstallments__c
 * and changing it is a Payment Plan Change Request, not an edit.
 */
export default class MscPlanSelect extends LightningElement {
  @api plans = [];
  @api selectedPlanId;
  @api unitPrice;
  @api rows = [];
  @api locked = false;
  /**
   * 1.5 - getUnitConfiguration or getBookingSummary is in flight FOR THIS CARD.
   *
   * The parent used to route every wait through one full-screen overlay, and this
   * particular wait through none at all: choosing a plan fetched its schedule with
   * no feedback anywhere, so the milestone table just appeared a second later. The
   * card now says so where the rows are about to be.
   */
  @api busy = false;

  labels = LABELS;

  /* The plan grid is skeletonised only when there is nothing to show yet.
     Once the chips exist they STAY - blanking a choice the agent has already made
     to report that its schedule is loading loses more than it says. */
  get showPlanSkeleton() {
    return this.busy && !this.hasPlans;
  }

  get showPlans() {
    return this.hasPlans && !this.showPlanSkeleton;
  }

  /* Nothing to choose from and nothing on the way: that is genuinely empty. */
  get showEmpty() {
    return !this.hasPlans && !this.busy;
  }

  /* The schedule is the part that actually changes on every selection, so it is
     the part that gets replaced while the call is out. */
  get showScheduleSkeleton() {
    return this.busy && this.hasPlans;
  }

  get showSchedule() {
    return this.hasSchedule && !this.busy;
  }

  /* Fixed-length lists, keyed, purely so the template can repeat a bar. Widths
     vary down the list so it reads as content rather than as a progress bar. */
  /* 1.7 - full-width bars, because the list they stand in for is a column now.
     Three of them: enough to read as a list, few enough that a unit with two plans
     does not make the card shrink when the real rows land. */
  get skeletonPlanRows() {
    return [
      { key: "sp1", cls: "sk sk--planrow" },
      { key: "sp2", cls: "sk sk--planrow" },
      { key: "sp3", cls: "sk sk--planrow" }
    ];
  }

  get skeletonRows() {
    return [
      { key: "sr1", cls: "sk sk--row sk--w10" },
      { key: "sr2", cls: "sk sk--row sk--w9" },
      { key: "sr3", cls: "sk sk--row sk--w10" },
      { key: "sr4", cls: "sk sk--row sk--w8" }
    ];
  }

  get planCards() {
    return (this.plans || []).map((p) => {
      const id = p.Id || p.id;
      const selected = id === this.shownSelectedId;
      return {
        id,
        name: p.Name || p.name,
        type: p.Type__c,
        milestones: p.milestoneCount,
        selected,
        /* 1.7 - a row, not a pill. .pill carried a pill's radius, its inline
           width and its centred text, none of which belong on a full-width line
           in a column. The row draws its own selected state instead of leaning
           on .active, which is a pill modifier. */
        cls: selected ? "lk__opt lk__opt--on" : "lk__opt",
        /* The template cannot say `if not selected`, and a lookup row needs a
           leading glyph in BOTH states or the names sit at two different
           indents down the list. */
        unselected: !selected,
        /* 1.7 - the milestone count, on the right of the row where the eye can
           run down it. extractPlans carries it across from the plan's own
           installments, so it is the org's number and not a guess; a plan whose
           installments did not arrive simply shows nothing. */
        meta: MscPlanSelect.metaFor(p.milestoneCount),
        // The plan type still rides in the tooltip, as it did as a pill.
        title: p.Type__c ? `${p.Name || p.name} - ${p.Type__c}` : p.Name || p.name
      };
    });
  }

  /* Static, because it needs nothing from the instance and is called from inside
     the map above. Blank rather than "0 milestones" when the count is missing:
     zero installments is not a fact this card has established. */
  static metaFor(count) {
    const n = Number(count || 0);
    if (!n) {
      return "";
    }
    return n === 1
      ? LABELS.PLAN_MILESTONE_ONE
      : LABELS.PLAN_MILESTONES.replace("{0}", n);
  }

  /*** MSC-173  Start - the filter ********************************************/

  /* Plain field, not @track: a string is reactive on its own, and the list below
     is a getter that reads it. */
  query = "";

  get hasQuery() {
    return this.query.trim().length > 0;
  }

  /* Lower-cased once per render rather than once per plan. */
  get needle() {
    return this.query.trim().toLowerCase();
  }

  /* NAME AND TYPE, because those are the two things the placeholder promises and
     the only two strings a plan carries. A plan whose type never arrived is still
     matched on its name. */
  get matchedPlans() {
    const q = this.needle;
    if (!q) {
      return this.planCards;
    }
    return this.planCards.filter((p) => {
      const name = (p.name || "").toLowerCase();
      const type = (p.type || "").toLowerCase();
      return name.includes(q) || type.includes(q);
    });
  }

  /* SERVER ORDER, ALWAYS. The selected plan is not floated to the top: a list
     that reorders itself under the cursor every time a plan is chosen is harder
     to use than one that does not, and the row is already marked. */
  get visiblePlans() {
    return this.matchedPlans;
  }

  get hasVisiblePlans() {
    return this.visiblePlans.length > 0;
  }

  /* A filter over one plan is a control that cannot do anything, and over a
     locked plan it is a control that must not. */
  get showFilter() {
    return !this.locked && this.planCards.length > 1;
  }

  /* ── open / closed ──────────────────────────────────────────────────────────
     The picker is ONE ROW until the agent asks for the list. Rendering it open
     cost exactly the height the pills cost and left the schedule half-covered,
     which was the entire problem being fixed. */
  open = false;

  /* ── THE CLEARED FIELD ──────────────────────────────────────────────────────
   * The agent pressed the x on the chosen plan. The FIELD is empty; the BOOKING
   * is not. Nothing has been dispatched, selectedPlanId still holds the plan the
   * host gave us, and the schedule below still belongs to it.
   *
   * That separation is the whole point. "No payment plan" is not a state this
   * journey supports - the schedule would empty, the offer could not be
   * previewed, and MSC-093 would propose the first plan back within one render.
   * So x means "I am changing this", and the change only lands when a plan is
   * chosen. Abandon it - click away, press Escape, close the field - and
   * close() drops this flag, the pill redraws from selectedPlanId, and the old
   * plan is simply there again.
   */
  cleared = false;

  /* What the LIST should mark as chosen - which is nothing once the field has
     been cleared, because a row still wearing a tick under an emptied field
     contradicts the thing the agent just did. The REAL selection is never read
     from here; select() and proposeFirstPlan both use selectedPlanId. */
  get shownSelectedId() {
    return this.cleared ? undefined : this.selectedPlanId;
  }

  get showTrigger() {
    return !this.open;
  }

  /* No x with nothing chosen, none when locked, and none on a unit with a single
     plan - in all three the control would either do nothing or offer a change
     that is not available. */
  get pillClearable() {
    return this.hasSelection && this.showFilter;
  }

  /* Clears the field and opens the search in one press, because clearing exists
     in order to choose again - leaving the agent with an empty closed row and a
     second press to make would be a worse version of the same thing. */
  handlePillClear() {
    if (!this.pillClearable) {
      return;
    }
    this.open = true;
    this.query = "";
    this.cleared = true;
    this.focusInput();
  }

  /* Locked, or a single plan on the unit: the row still names the plan - that is
     how the agent sees which one is theirs - it just stops being a door. */
  get triggerDisabled() {
    return !this.showFilter;
  }

  /* THE REAL one, found by id rather than by the `selected` flag: that flag is
     suppressed while the field is cleared, and the pill has to be able to draw
     the plan it is about to revert to. */
  get selectedPlan() {
    const id = this.selectedPlanId;
    return id ? this.planCards.find((p) => p.id === id) || null : null;
  }

  get hasSelection() {
    return this.selectedPlan !== null;
  }

  /* The chosen plan's name, or the invitation to choose one. Never a blank row:
     an empty field here reads as a control that failed to load. */
  get triggerText() {
    const chosen = this.selectedPlan;
    return chosen ? chosen.name : LABELS.PLAN_FILTER_PH;
  }

  get triggerMeta() {
    const chosen = this.selectedPlan;
    return chosen ? chosen.meta : "";
  }

  get triggerTitle() {
    const chosen = this.selectedPlan;
    if (!chosen) {
      return LABELS.PLAN_FILTER_PH;
    }
    return this.locked ? chosen.title : LABELS.PLAN_CHANGE_HINT;
  }

  /* 1.8 - THE EMPTY ROW IS NOW THE NORMAL FIRST VIEW. MSC-174.
     Until this version a multi-plan unit always arrived with a plan proposed, so
     the unchosen state was barely reachable and drew its placeholder in the same
     weight as a real plan name - which reads as a plan called "Search payment
     plans by name or type". It is a prompt, so it is drawn like one. */
  get pillClass() {
    return this.hasSelection ? "lk__pill" : "lk__pill lk__pill--empty";
  }

  get pillMainClass() {
    return this.hasSelection
      ? "lk__pill-main"
      : "lk__pill-main lk__pill-main--empty";
  }

  get closeTitle() {
    return LABELS.PLAN_FILTER_CLOSE;
  }

  handleOpen() {
    /* Locked, or a single plan: there is nothing to open onto. The row still
       renders - it is how the agent sees which plan is theirs - it just is not a
       door. */
    if (!this.showFilter) {
      return;
    }
    this.open = true;
    this.query = "";
    /* BLANK, AND NOTHING MARKED - both doors into the search behave the same way.
       The field opens empty rather than pre-filled with the current plan, and no
       row wears a tick, so the agent is choosing rather than editing a value.
       Nothing has been dispatched; abandoning it puts the plan back. */
    this.cleared = true;
    this.focusInput();
  }

  /* Set when the field has just been asked for; cleared by renderedCallback once
     the focus has actually been given. A microtask was not enough - LWC re-renders
     asynchronously, so `open = true` does not mean the input exists yet, and the
     querySelector fired against a template that still held the closed row. */
  _needsFocus = false;

  focusInput() {
    this._needsFocus = true;
  }

  giveFocus() {
    if (!this._needsFocus) {
      return;
    }
    const el = this.template.querySelector(".lk__input");
    if (!el) {
      return;
    }
    this._needsFocus = false;
    el.focus();
  }

  /* THE REVERT. Dropping `cleared` is all it takes: the pill reads
     selectedPlanId, which no clear ever touched. */
  close() {
    this.open = false;
    this.query = "";
    this.cleared = false;
    this._needsFocus = false;
  }

  handleCloseButton() {
    this.close();
  }

  /* Clicking away closes it, which is what every picker on this journey does.
     relatedTarget is the element about to receive focus: when it is still inside
     this component - moving from the input to a result row - the picker stays
     open. A null relatedTarget means focus left the document entirely (the agent
     clicked the page chrome or switched tab), which also closes. */
  handleFocusOut() {
    if (!this.open) {
      return;
    }
    /* DEFERRED, and this is the whole fix.
     *
     * Opening the picker REPLACES the closed row with the field, so the button
     * the agent just pressed is destroyed by that very render. The browser fires
     * focusout for it with relatedTarget null - focus went nowhere, because the
     * element holding it no longer exists - which is indistinguishable, in the
     * moment, from the agent clicking away. Read synchronously it closed the
     * picker on the same click that opened it, so pressing x appeared to do
     * nothing at all.
     *
     * A macrotask lets the render finish and focus settle. template.activeElement
     * is the shadow root's own answer to "is focus still inside me", which is the
     * question relatedTarget could not answer once the element was gone. */
    clearTimeout(this._blurTimer);
    this._blurTimer = setTimeout(() => {
      if (!this.open) {
        return;
      }
      /* Still waiting to hand focus to a field that has not rendered yet. */
      if (this._needsFocus) {
        return;
      }
      if (this.template.activeElement) {
        return;
      }
      this.close();
    }, 0);
  }

  disconnectedCallback() {
    clearTimeout(this._blurTimer);
  }

  get countText() {
    const total = this.planCards.length;
    if (!this.hasQuery) {
      return total === 1
        ? LABELS.PLAN_FILTER_ONE
        : LABELS.PLAN_FILTER_ALL.replace("{0}", total);
    }
    return LABELS.PLAN_FILTER_COUNT.replace("{0}", this.matchedPlans.length).replace(
      "{1}",
      total
    );
  }

  /* THE CHOSEN PLAN, WHEN THE FILTER HAS HIDDEN IT.
     The schedule below always belongs to the selected plan, so a filter that
     hides its row leaves a table with no visible owner - which reads as a
     rendering fault. Named here instead, on the count line, in one short string. */
  get hiddenSelectedText() {
    /* Nothing is shown as chosen while the field is cleared, so there is nothing
       for this line to say it has hidden. */
    if (this.cleared || !this.hasQuery || !this.selectedPlanId) {
      return "";
    }
    const shown = this.visiblePlans.some((p) => p.selected);
    if (shown) {
      return "";
    }
    const chosen = this.planCards.find((p) => p.selected);
    return chosen ? LABELS.PLAN_FILTER_HIDDEN.replace("{0}", chosen.name) : "";
  }

  get showNoMatch() {
    return this.hasQuery && this.matchedPlans.length === 0;
  }

  get noMatchText() {
    return LABELS.PLAN_FILTER_NONE.replace("{0}", this.query.trim());
  }

  handleFilter(event) {
    this.query = event.target.value || "";
  }

  /* Enter selects when the filter has narrowed to a single plan - the natural end
     of typing a plan's name. Escape clears, which is what Escape does in every
     search field the agent has used today. Nothing else is intercepted. */
  handleFilterKey(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      /* Escape closes the picker outright rather than only emptying the field.
         A cleared box still covering the schedule is not what Escape promises. */
      this.close();
      return;
    }
    if (event.key !== "Enter") {
      return;
    }
    event.preventDefault();
    const only = this.matchedPlans.length === 1 ? this.matchedPlans[0] : null;
    if (only && !only.selected) {
      this.select(only.id);
    }
  }

  handleClear() {
    this.clearQuery();
    /* Focus returns to the field, so clearing does not cost the agent their place
       - and the No-match button, which is about to unmount, does not leave focus
       on the document body, which would read as a click-away and close the picker.

       THROUGH focusInput, like every other focus request here. This method used to
       carry its own querySelector and its own selector string, and when the markup
       became a lookup that string was left pointing at a class that no longer
       existed. One helper means one selector to keep true. */
    this.focusInput();
  }

  clearQuery() {
    this.query = "";
  }
  /*** MSC-173  End ***********************************************************/

  get hasPlans() {
    return this.planCards.length > 0;
  }

  get scheduleRows() {
    return (this.rows || []).map((r, i) => ({
      key: r.installmentId || `row-${i}`,
      number: r.milestoneNumber,
      description: r.description || `${LABELS.MILESTONE} ${r.milestoneNumber || i + 1}`,
      /* 1.10 - no dash as a blank: a missing percentage is an empty cell, and a missing due
         date says "Not set" (an empty date column reads as a rendering fault; DEV does have
         installments with no date set). */
      percent: r.percent != null ? `${r.percent}%` : "",
      amount: formatAED(r.amount),
      due: r.dueDate ? formatDate(r.dueDate) : "Not set",
      status: r.status
    }));
  }

  get hasSchedule() {
    return this.scheduleRows.length > 0;
  }

  /*** MSC-093  Start - the card opens on a plan, not on a question ***********
   *
   * Every unit reached this card with nothing chosen, so the agent's first act
   * was always the same press. Until they made it the schedule below was empty,
   * the offer could not be previewed, and on a basket the summary rail read
   * "0 of 2 plans chosen" on the one screen whose job is to choose them.
   *
   * The card now proposes the first plan on the list and draws its schedule.
   * Nothing is committed by that: the pills are unchanged, the choice is one
   * press away, and it reaches the Sales Order only at Confirm.
   *
   * Never while `locked` - the booking is a record by then, and a plan on a
   * record is a Payment Plan Change Request - and never while `busy`, because a
   * list still arriving has no first plan to speak of.
   */

  /* The list this card has already proposed against, held BY REFERENCE. The
     basket hands each unit's own array, so moving to another unit's tab re-arms
     the proposal while a re-render of the same card does not - and if the host
     declines the event, this does not ask a second time. */
  _proposedFor;

  renderedCallback() {
    this.resetQueryOnNewList();
    this.giveFocus();
    this.proposeFirstPlan();
  }

  /* 1.7 - A FILTER BELONGS TO THE LIST IT WAS TYPED AGAINST. MSC-173.
   *
   * On a basket the SAME component instance is re-fed each unit's own plans as the
   * agent moves between unit tabs. A query left over from the last unit would then
   * filter this one - and because plan names differ by project, the usual result is
   * a list that appears empty for a unit that has fourteen plans.
   *
   * By REFERENCE, exactly as _proposedFor tracks the same thing: mscBookingPage
   * hands each unit its own array, so a new unit is a new array while a re-render of
   * the same unit is not. Assigning query re-renders, but the next pass finds
   * _queryFor === list and does nothing, so this settles in one extra pass.
   */
  _queryFor;

  resetQueryOnNewList() {
    const list = this.plans;
    if (this._queryFor === list) {
      return;
    }
    this._queryFor = list;
    if (this.query !== "") {
      this.query = "";
    }
    if (this.open) {
      this.open = false;
    }
    if (this.cleared) {
      this.cleared = false;
    }
  }

  proposeFirstPlan() {
    const list = this.plans;
    if (this._proposedFor !== list) {
      this._proposedFor = undefined;
    }
    if (this.locked || this.busy || this.selectedPlanId) {
      return;
    }
    /* 1.8 - ONLY WHERE THERE IS NOTHING TO CHOOSE BETWEEN. MSC-174.
     *
     * MSC-093 proposed the first plan on every unit, and on a unit offering
     * fourteen that is not a convenience - it is an answer, picked by list order,
     * that the agent never gave. The schedule underneath then belongs to a plan
     * nobody chose, and it looks exactly like a plan somebody did.
     *
     * One plan is a different question: there is no choice to make, so making the
     * agent press the only button on the screen buys nothing. That case keeps
     * MSC-093's behaviour unchanged.
     *
     * Nothing downstream needs the proposal. structuralBlockers already says
     * "Select a payment plan.", barDisabled already refuses to advance past step
     * two without one, offerBlockedReason already explains what quoting is waiting
     * for, and checkPlanSchedule already returns early on a null id. The empty
     * state was designed for; it was just never reached. */
    if (this.planCards.length !== 1) {
      return;
    }
    const first = this.planCards[0];
    if (!first || !first.id) {
      return;
    }
    this._proposedFor = list;
    /* Marked BEFORE the dispatch and fired after the render pass, so two renders
       in the same tick cannot both propose. */
    Promise.resolve().then(() => {
      this.dispatchEvent(new CustomEvent("planchange", { detail: { planId: first.id } }));
    });
  }
  /*** MSC-093  End **********************************************************/

  handleSelect(event) {
    this.select(event.currentTarget.dataset.id);
  }

  /* 1.7 - the one place the choice leaves this card. Extracted so the row press
     and the Enter key in the filter cannot drift apart; the guards and the event
     are 1.0's, unchanged and in the same order. */
  select(planId) {
    if (this.locked) return;
    if (!planId) return;
    /* Closes even when the agent picks the plan that was already chosen. They
       opened the list, they looked, they confirmed - leaving it open would make
       the one press that means "this one" the only press that does nothing. */
    this.close();
    if (planId === this.selectedPlanId) return;
    this.dispatchEvent(new CustomEvent("planchange", { detail: { planId } }));
  }
}