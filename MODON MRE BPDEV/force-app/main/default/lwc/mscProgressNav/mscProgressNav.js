/**
 * The journey's top bar - the deal tape.
 *
 * Version  Author      Date         Detail
 * 1.12     Aurelix Dev 30 Sep 2026  Narrow tabs (800, 956) use the step's short name and put the value on two
 *                                   lines; a short screen shows the names only. Nothing is cut.
 * 1.11     Aurelix Dev 23 Aug 2026  MSC-153. floorReason - a step closed by the floor
 *                                   says why, on the segment itself. Optional; without
 *                                   one a refused segment keeps its old title.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.1      Aurelix IT  09 Aug 2026  Compact "Step n of N" on phone, replacing the
 *                                   unlabelled dot row.
 * 1.4      Aurelix IT  12 Aug 2026  No longer clickable. 1.2 had already locked steps
 *                                   ahead of the agent; a completed one still let them
 *                                   jump from Unit Selection straight to Payment &
 *                                   Confirm, past the step in between. The action bar's
 *                                   Back and Continue are the only way between steps
 *                                   now, and this is purely an index of where you are.
 * 1.6      Aurelix IT  15 Aug 2026  A COMPLETED SEGMENT IS A BUTTON, and its rule is
 *                                   green. One condition drives both, so the bar cannot
 *                                   say two different things about the same step: green
 *                                   means "this step has everything it needs", and
 *                                   everything green is somewhere the agent can go back
 *                                   to. Nothing else is clickable.
 *
 *                                   This answers 1.4 rather than reversing it. 1.4
 *                                   removed the click because a completed chip let an
 *                                   agent jump from Unit Selection straight to Payment &
 *                                   Confirm, past the step in between. It cannot happen
 *                                   under this rule: a step only completes once its own
 *                                   requirements are met, and stateFor gates those on the
 *                                   steps before it - customer and plan on hasUnit,
 *                                   payment on paymentReady, verify on confirmed. There
 *                                   is no state where a completed segment is a route
 *                                   past an unfinished one. Forward is still Continue.
 * 1.5      Aurelix IT  15 Aug 2026  THE DEAL TAPE. Numbered chips out, values in.
 *
 *                                   The chips reported a position the agent already
 *                                   knew, in 64px, while the same figures were printed
 *                                   twice more - in the action bar and the summary rail.
 *                                   Each segment now shows the VALUE its step produced;
 *                                   a step still waiting shows a prompt instead. The
 *                                   fill rule under a segment is the whole progress
 *                                   indicator, which is what lets the circles go.
 *
 *                                   Full width by construction: four equal flex tracks,
 *                                   so the tape spans the sheet instead of huddling at
 *                                   the left edge the way a row of chips did.
 * 1.7      Aurelix Dev 16 Aug 2026  GREEN MEANS FINISHED. AMBER MEANS NOT.
 *
 *                                   1.6 gave position and readiness a channel each and
 *                                   then let them fight in the cascade: --current painted
 *                                   gold, --ready painted green, and --ready was declared
 *                                   second, so it won. A step the agent was still filling
 *                                   in read as done - Customer & Payment Plan went green
 *                                   the moment a residency was picked, directly above a
 *                                   banner asking for the mailing address.
 *
 *                                   One tone per segment now, chosen in the JS, and
 *                                   position is carried by weight instead of by colour.
 * 1.8      Aurelix IT  19 Aug 2026  NO PROMPT. "Awaiting unit / customer / payment /
 *                                   verification" no longer prints under a step that has
 *                                   no value yet - the business read it as noise. The
 *                                   slot stays (min-height), so the tape does not reflow
 *                                   as values arrive. Values themselves unchanged.
 * 1.9      Aurelix IT  19 Aug 2026  An empty step's label grows to the value size and the
 *                                   empty slot is not drawn - a small caption over a blank
 *                                   line looked like a hole. CSS only.
 * 1.10     Aurelix Dev 21 Aug 2026  MSC-104. A FLOOR: THE STEPS THAT MADE THE SALES ORDER
 *                                   ARE NOT A WAY BACK.
 *
 *                                   1.6 made a completed segment clickable and said
 *                                   "everything green is somewhere you can go back to".
 *                                   That held while completeness was the only question,
 *                                   and it is not. Once a Sales Order exists the unit is
 *                                   written on it and the plan is on its fee lines, so
 *                                   Unit Selection and Customer & Payment Plan are green
 *                                   BECAUSE they are finished for good - and pressing one
 *                                   landed the rep on the screen that greets them with
 *                                   "This customer already has a booking on this
 *                                   opportunity". A way out that is not one.
 *
 *                                   The action bar's Back already stopped there
 *                                   (mscBookingPage 1.69); the tape did not, so the same
 *                                   journey said two different things about the same step.
 *
 *                                   `floorKey` names the earliest step still open. Every
 *                                   segment before it keeps its place, its label, its
 *                                   value and its green rule, and stops being a control -
 *                                   the treatment a step ahead already gets. The floor is
 *                                   the parent's to decide: this component knows nothing
 *                                   about Sales Orders, and reads the floor off the
 *                                   segment ORDER rather than any key of its own, so it
 *                                   stays a renderer.
 */

import { LightningElement, api } from "lwc";

/**
 * The journey's step index, carrying the deal.
 *
 * 1.5 - it still REPORTS position and does not change it. That is 1.4's decision and
 * it stands: the action bar's Back and Continue are the only way between steps, and a
 * tape that could be clicked would let an agent skip the step in between. The segments
 * are list items, not buttons, so nothing here promises an action it does not have.
 *
 * 1.1 - on a phone this is a CAPTION, not a rail.
 *
 * Four segments will not fit 390px - three chips did not fit either, which is what 1.1
 * was written for. The caption states position in words and the value gets its own
 * line beneath it, so the phone loses the shape of the journey but keeps the number an
 * agent is reading out.
 */
export default class MscProgressNav extends LightningElement {
  /** [{ key, label, index, state, value, prompt }] - state mirrors mscSectionCard's. */
  @api sections = [];
  @api activeKey;

  /**
   * 1.10 - THE EARLIEST STEP STILL OPEN. Everything before it in `sections` is
   * history: drawn, green where it is finished, and not a way to get anywhere.
   *
   * A key rather than a boolean, and an index read off `sections` rather than a
   * constant, because the tape does not know the journey - it renders the list it
   * is handed, and the parent is the only thing that knows what a closed step is.
   *
   * Unset is the ordinary case: nothing is closed, and 1.6's rule stands alone.
   */
  @api floorKey;
  /* MSC-153 - why the floor is where it is, in the parent's words. The tape knows a
     step is closed; only the page knows whether that is because the booking is
     committed or because money has been collected against this unit. Optional: with
     none, a refused segment keeps the title it has always had. */
  @api floorReason;

  /**
   * 1.6 - POSITION AND READINESS ARE TWO SIGNALS, AND THEY GET TWO CHANNELS.
   *
   * They were one before, which forced a choice the bar should not have to make: a
   * step that both holds all its data AND is the one you are standing on can only
   * be painted once. So:
   *
   *   where you are   the label goes accent, the value goes white and semibold
   *   has its data    the rule underneath goes green
   *
   * A step can now say both at once, which is the common case on Customer & Payment
   * Plan - the agent has filled it in and has not moved on yet.
   *
   * `ready` is the parent's own `complete`, not a second opinion about it. That
   * matters for the unit step, which stateFor deliberately holds at `active` while
   * the agent is standing on it (see its 1.23 note: an agent can tick a second unit
   * for a basket, so green the instant one is picked was simply wrong). The tape
   * inherits that judgement rather than re-deriving it.
   */
  /** -1 when there is no floor, or when the parent names a step this tape does not
      hold - either way nothing is closed and every completed step stays clickable. */
  get floorIndex() {
    if (!this.floorKey) {
      return -1;
    }
    return (this.sections || []).findIndex((s) => s.key === this.floorKey);
  }

  get items() {
    const list = this.sections || [];
    const floor = this.floorIndex;

    return list.map((s, i) => {
      const isCurrent = s.key === this.activeKey;
      const isReady = s.state === "complete";

      /* 1.7 - ONE COLOUR PER SEGMENT, DECIDED HERE.

         It used to be decided by the cascade: --current painted gold, --ready
         painted green, and --ready was declared second so it won. The result was
         a step reading green while it was still being filled in - Customer &
         Payment Plan went green the moment a residency was chosen, over a banner
         asking for the mailing address.

         The rule now, and it is the whole rule:

           green   the step has everything it needs
           amber   THE STEP YOU ARE ON, and it is not finished
           grey    everything else

         EXACTLY ONE SEGMENT CAN BE AMBER. The first pass at this also painted
         `active` and `blocked` amber wherever they appeared, and stateFor calls a
         step active as soon as its PRECONDITIONS are met - Payment & Confirm goes
         active the moment a unit, a customer and a plan exist. So standing on
         Customer & Payment Plan lit both it and the step after it, and two ambers
         say "two things need you" when only one does.

         Amber is therefore tied to position, not to readiness. A step ahead is
         grey until the agent is standing on it, whatever its internal state; the
         step's own card is where its detail belongs.

         Position also has its own channel on top of the colour - the current
         segment's value goes white and semibold - so "you are here" survives
         even when the step is finished and the rule under it is green. */
      let tone;
      if (isReady) {
        tone = "ready";
      } else if (isCurrent) {
        tone = "wip";
      } else {
        tone = "todo";
      }

      /* A COMPLETED STEP IS THE ONLY ONE YOU CAN CLICK, and it is the same
         condition that turns the rule green - one fact, one rule, two expressions
         of it. So the tape reads honestly in both directions: green means "this
         step has everything it needs", and everything green is somewhere you can
         go back to - until the parent closes a step behind a floor, which is 1.10
         below and the one exception to this paragraph.

         This also settles 1.4's objection without a second guard. Reaching a step
         requires that step to be complete, and a step cannot complete before the
         ones it depends on - stateFor gates customer and plan on hasUnit, payment
         on paymentReady, verify on confirmed - so there is no arrangement of state
         where a completed segment is a way to skip an unfinished one.

         Not the current step: clicking where you already are does nothing, and for
         Payment & Confirm it would re-run loadFees, syncHold and loadOffers for
         the privilege.

         1.10 - AND NOT BELOW THE FLOOR. A step before floorKey is finished for
         good, not merely finished, so green stops implying "you can go back to
         it". It keeps its place, its label, its value and its green rule and
         simply is not a control - exactly what a step ahead already gets, and the
         same line the action bar's Back draws (mscBookingPage's previousKey).

         Position, not state: the segment is refused because of where it sits in
         the journey, so a step ahead of the floor is untouched and forward
         movement through the tape works as it always did. */
      const behindFloor = floor > -1 && i < floor;
      const canJump = isReady && !isCurrent && !behindFloor;

      const classes = ["seg", `seg--${tone}`];
      /* Emphasis only. It carries no colour of its own now, so it can sit on top
         of any tone without arguing with it. */
      if (isCurrent) classes.push("seg--current");
      if (!s.value) classes.push("seg--empty");
      if (canJump) classes.push("seg--jump");

      /* 1.12: the value in two parts at its first " · ", so a narrow tab can put them on two lines */
      const value = s.value || "";
      const cut = value.indexOf(" · ");
      return {
        key: s.key,
        label: s.label,
        shortLabel: s.shortLabel || s.label,
        valueHead: cut > -1 ? value.slice(0, cut) : value,
        valueTail: cut > -1 ? value.slice(cut + 3) : "",
        /* The prompt IS the value slot when there is nothing yet - same line, same
           position, so the tape does not reflow as the booking fills in. Falling back
           to the label last means a segment is never blank, whatever the parent
           passes. */
        /* 1.8 - no prompt. A step with no value yet shows nothing in the slot; the
           slot keeps its height (CSS min-height) so the tape still does not reflow. */
        display: s.value || "",
        cls: classes.join(" "),
        ariaCurrent: isCurrent ? "step" : null,
        /* Disabled rather than absent: the segment keeps its place in the tape and
           its value stays readable. It simply is not a way to get anywhere. */
        disabled: !canJump,
        /* MSC-153 - a step refused BY THE FLOOR says why, in the one place a rep
           reaches for it. Every other refusal keeps the value it always showed:
           a step ahead is not refused, it simply has not been reached. */
        title:
          canJump
            ? `Go back to ${s.label}`
            : (behindFloor && this.floorReason) || s.value || s.label
      };
    });
  }

  /**
   * The parent decides what opening a step means - it owns which sections are open
   * and, for Payment & Confirm, refreshes fees, holds and offers on arrival. This
   * reports the request and nothing else.
   */
  handleJump(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) {
      return;
    }
    this.dispatchEvent(new CustomEvent("jumpto", { detail: { key } }));
  }

  /** Phone caption. Reads position out of the same list the tape renders. */
  get stepCaption() {
    const list = this.sections || [];
    const i = list.findIndex((s) => s.key === this.activeKey);
    if (i === -1 || !list.length) {
      return "";
    }
    return `Step ${i + 1} of ${list.length} · ${list[i].label}`;
  }

  /** The one figure worth keeping when the rail itself will not fit. */
  get stepValue() {
    const list = this.sections || [];
    const s = list.find((x) => x.key === this.activeKey);
    return (s && s.value) || null;
  }

  get showStepValue() {
    return !!this.stepValue;
  }
}