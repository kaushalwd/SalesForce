/**
 * Booking summary - sticky rail above 1024px, inline strip below.
 *
 * Version  Author             Date         Detail
 * 1.0      Aurelix IT         05 Aug 2026  Initial.
 * 1.4      Aurelix IT         10 Aug 2026  Groups collapse. The rail packed five groups and ~20
 *                                   rows into one viewport, so an agent scrolled it to
 *                                   read the total. The group matching the active step
 *                                   opens itself, Amounts stays pinned, and a click
 *                                   overrides until the step changes.
 * 1.5      Aurelix IT         11 Aug 2026  Fixes 1.4: the open-set was compared against SECTION
 *                                   keys while activeKey carries STEP keys, so the
 *                                   customer step opened nothing but Amounts.
 * 1.6      Aurelix IT         12 Aug 2026  One summary for one unit or many, replacing
 *                                   mscBasketSummary - a basket had no customer on it at
 *                                   all. Everything starts collapsed and only one group
 *                                   opens at a time, Amounts included; it used to be
 *                                   pinned open with no chevron.
 * 1.7      Aurelix IT         12 Aug 2026  Unit, Customer, Payment Plan and Amounts no longer
 *                                   navigate - the panel reads rather than routes. Only
 *                                   Payment Status still jumps.
 * 1.8      Aurelix Developer  16 Aug 2026  ONE PANEL, AND IT ANSWERS SOMETHING ON ARRIVAL.
 *                                   A masthead that never collapses and carries the one
 *                                   figure the current step is about; a focus line saying
 *                                   what is needed or what is running out; every group
 *                                   showing its headline value while shut; and the
 *                                   isBasket branching gone - see the class comment.
 * 1.9      Aurelix Developer  16 Aug 2026  The record scrolls inside the card, on the same
 *                                   invisible-scrollbar rule the section cards use. The
 *                                   step meter is dropped - the progress tape above says
 *                                   the same thing in words - and one type scale runs
 *                                   through every expanded group; they were carrying five
 *                                   different sizes between them.
 * 1.10     Aurelix Developer  16 Aug 2026  Payment Status is not rendered until there is
 *                                   something to collect. Before Confirm the group was a
 *                                   permanent heading whose whole content read "Nothing to
 *                                   collect yet".
 * 1.18     Aurelix Developer  22 Aug 2026  MSC-112. The customer's email and mobile rows
 *                                   read the MASKED fields. The server now nulls a
 *                                   locked field's clear value before it leaves, and
 *                                   the masked chain is non-blank wherever the clear
 *                                   one was - one console, one exposure policy: the
 *                                   card beside this rail shows the same masked pair.
 * 1.17     Aurelix Developer  20 Aug 2026  MSC-093. The unit rows no longer repeat the plan.
 *                                   Each carried its plan chip directly above a Payment
 *                                   plan group listing the same unit-and-plan pairs. The
 *                                   unit rows say what is being bought and for how much;
 *                                   the plan group says on what terms.
 * 1.16     Aurelix Developer  19 Aug 2026  THE AMOUNTS GROUP, ONCE THE BOOKING IS MADE. It
 *                                   listed Booking fee and Collected as two rows that
 *                                   carried the same figure, under a masthead that
 *                                   carried it twice more - one number five times on one
 *                                   screen. Post-Confirm (`totals.isCommitted`, page 1.87)
 *                                   the group is Total Price / ADM + Dari (the charge) /
 *                                   Collected / Balance: the ledger's own arithmetic, one
 *                                   figure each, once. Before Confirm it is unchanged.
 * 1.16     Aurelix Dev        25 Aug 2026  MSC-176. A COMPANY STOPS BEING DESCRIBED AS A
 *                                   PERSON. The customer group rendered one row set -
 *                                   name, email, mobile, nationality, residency - so an
 *                                   organisation booking reported the PRIMARY CONTACT's
 *                                   nationality and residency as though they were the
 *                                   company's. Wrong information, not missing, on the
 *                                   card that sits beside the agent for the whole
 *                                   journey. A company now reads Company, Contact,
 *                                   Email, Mobile; the collapsed strip names the
 *                                   company rather than the contact. No new Apex and no
 *                                   new query - companyName and customerType have been
 *                                   on CustomerBlock since 1.7 and were never read. The
 *                                   individual branch is untouched, to the row, the key
 *                                   and the order.
 * 1.15     Aurelix Developer  17 Aug 2026  THE OTHER UNITS, AS A WAY IN. Modon's direction:
 *                                   Total Sales lists a row per Sales Order and Resume
 *                                   opens that order alone (page 1.81, Apex 1.39). So on
 *                                   one order of a two-unit booking this rail shows one
 *                                   unit - correctly - and must say "one of two" and let
 *                                   the agent open the other without a trip back to
 *                                   Total Sales. `siblingUnits` (@api) is the page's list
 *                                   of the OTHER live orders; each renders as a row the
 *                                   agent can press, and the press is `opensibling`. When
 *                                   siblings are supplied the 1.12/1.14 "covers" line
 *                                   stands down: it named the missing units without a way
 *                                   to reach them, and this is that way.
 * 1.13     Aurelix Developer  17 Aug 2026  The Payment Status group is gone, permanently
 *                                   and by request. It restated the obligation ledger
 *                                   without the money's actions attached, and its
 *                                   collapsed heading truncated to "2 of 8 paid · 1
 *                                   sched…" at the rail's width.
 * 1.12     Aurelix Developer  17 Aug 2026  Two counts that misread a healthy booking. The
 *                                   Payment Status group swept seven milestones that are
 *                                   not due for years in with the two obligations owed
 *                                   today, so "0 of 9 paid" made a brand-new booking look
 *                                   untouched; and a basket resuming as one unit showed
 *                                   half a booking with nothing saying so.
 * 1.11     Aurelix Developer  17 Aug 2026  The Amounts group stops calling a deposit by the
 *                                   names of the full obligations. Before Confirm its
 *                                   three fee rows are all parts of the booking fee, and
 *                                   they were labelled Down Payment, ADM + Dari and Due
 *                                   Now - three rows, three wrong names, one of them
 *                                   contradicting the card beside it. One row, "Booking
 *                                   fee", until the real amounts exist.
 * 1.17     Aurelix Dev        30 Sep 2026  The stage chip, plan chips and the positive focus line in quiet
 *                                   text with a small mark, no bright green (CSS only).
 */

import { LightningElement, api } from "lwc";
import { formatAED } from "c/modonSalesFormat";
import { LABELS } from "c/mscLabels";

/* MSC-176 - both spellings, lower case, compared against a lower-cased value.
   Local consts rather than a shared export, matching c/mscCustomerInfo which
   declares its own ORGANISATION the same way. */
const ORGANISATION = "organisation";
const ORGANIZATION = "organization";

/**
 * 1.8 - which group a STEP opens on first arrival.
 *
 * The pairing is "what does the rail add that the screen does not already show".
 * On the customer step the customer and the plan are both on screen in full, so
 * the rail's job is to say what is being bought - Units. On the payment step the
 * screen is a list of obligations and the rail's job is the arithmetic - Amounts.
 * After confirmation the money is the record - Payment status.
 */
const STEP_GROUP = {
  unit: "units",
  details: "units",
  settle: "amounts",
  /* 1.13 - was "payments", the group this rail no longer has. A step whose mapping
     names a missing group opens nothing at all. */
  verify: "amounts"
};

/* 1.13 - `isPast` removed with paymentRows, the only thing that used it. */

/** Semantic tone -> the console's own chip classes. */
const TONE_CHIP = {
  good: "chip chip--paid",
  warn: "chip chip--due",
  bad: "chip chip--alert",
  flat: "chip chip--pending"
};

/** Semantic tone -> the focus line's own classes. */
const TONE_FOCUS = {
  good: "summary__focus summary__focus--ok",
  warn: "summary__focus summary__focus--warn",
  bad: "summary__focus summary__focus--bad",
  flat: "summary__focus"
};

/**
 * The Booking Summary (Modon comment 3), visible throughout the journey.
 *
 * 1.8 - THE GOVERNING RULE: A ROW APPEARS BECAUSE THE DATA EXISTS, NEVER BECAUSE A
 * MODE FLAG SAYS SO.
 *
 * This component used to be two panels wearing one name. `isBasket` branched
 * through it: a basket got no Payment Plan group at all, an Amounts group cut down
 * to a single Total, and unit rows in a different shape - so one unit and three
 * units read as different products. That rule dissolves the split. There is no
 * basket view and no single view, only a list of `lines`, and a one-unit booking is
 * a list of one. Where a basket genuinely has no down payment the row is absent for
 * the same reason it is absent on a single unit that has not reached payment: there
 * is no figure. Labels pluralise on `lines.length`.
 *
 * Three tiers:
 *   1. a masthead that never collapses - reference, stage, THE ONE FIGURE THIS STEP
 *      IS ABOUT, its supporting line, and a segment per step
 *   2. one focus sentence - what is blocking, or what is running out
 *   3. the four groups that describe the booking, always, each showing its
 *      headline value while shut - plus Payment Status once obligations exist
 *
 * Everything in tiers 1 and 2 is DERIVED BY THE PARENT and handed down formatted.
 * That is deliberate: the journey already holds every figure, every blocker and the
 * hold clock, and a second copy of any of them here is a second thing to keep in
 * sync. In particular the hold countdown ticks once a second in the parent's
 * existing interval and arrives here as a string - a timer in the rail would be a
 * second clock against the same deadline.
 *
 * Provenance of the record itself, in precedence order, resolved by the parent:
 *   1. server DTO once a Sales Order exists (authoritative)
 *   2. previewBookingFees - server-computed, creates no records
 *   3. client arithmetic over the plan template's percentages
 *   4. live form state, badged "Not saved"
 *   5. null -> the empty affordance
 *
 * 1.7 - it READS, it does not navigate. Unit, Customer, Payment Plan and Amounts are
 * a record of the booking, not a route back into editing it; only Payment Status
 * still jumps, because chasing an outstanding payment is an action rather than a
 * fact. 1.8 moves that jump onto the payment ROWS, which are the precise target
 * anyway, so all five group headings now behave identically.
 */
export default class MscBookingSummary extends LightningElement {
  /** BookingSummaryDTO from SalesConsoleController - the record, not the framing. */
  @api summary;
  /** 'rail' | 'strip' - set by the parent's matchMedia listener, never here. */
  @api mode = "rail";
  /** True while the customer form has unsaved edits. */
  @api customerDirty = false;
  /** The STEP key - unit | details | settle | verify. 1.8 uses it again; see below. */
  @api activeKey;

  /**
   * 1.8 - the units, as one model for one unit or many.
   * [{ id, name, meta, where, price, planName, planCls, hasPlan }]
   * Replaces `units` + `basketTotal` + `multi`, which existed only to tell the two
   * shapes of booking apart.
   */
  @api lines = [];

  /** { total, downPayment, admFee, dueNow, collected, balance } - formatted, or null. */
  @api totals;

  /** { reference, stage, stageTone, label, figure, figureSmall, sub, steps }. */
  @api headline;

  /** { text, tone } - tone is good | warn | bad | flat.
   *  NOT `focus`: LightningElement extends HTMLElement, so an @api of that name
   *  shadows element.focus() on every instance of this component. */
  @api focusLine;

  /** PaymentBucketDTO[] - every Sales Order in the booking, not just the first. */
  @api payments = [];
  /*** 1.12 - every unit this booking made, from ConsoleState.bookedUnits.
   *
   * `lines` is what the console currently has open, which after a basket resumes is
   * one unit of several. This is what the BOOKING is, and the two disagreeing in
   * silence is how an agent closes a screen believing they have seen it all. */
  @api bookedUnits = [];

  labels = LABELS;

  /*** 1.14 - RESTORED. These three were lost, and the markup kept calling them.
   *
   * 1.12 added the "this booking covers N units" line and its three getters. During
   * MSC-041 this component was retrieved from the org to recover an unrelated
   * deletion, and the retrieve brought back a JS file from before 1.12 while the
   * template kept the newer block. So mscBookingSummary.html has been referencing
   * showBookingCovers / bookingCoversText / bookingCoversNames against a class that
   * defines none of them.
   *
   * An LWC template resolves a missing property to `undefined` rather than throwing,
   * so nothing broke visibly - the line simply never rendered. Which means the one
   * mitigation standing between a resumed basket and an agent believing they had seen
   * the whole booking has never once appeared on screen. MSC-034 wrote it, MSC-043
   * relied on it, and it was not there.
   ***/

  /*** 1.15 - THE OTHER UNITS OF THIS BOOKING, AS A WAY IN.
   *
   * The page's siblingUnits: every live order of the booking except the one this
   * page is opened on (BookedUnitDTO - salesOrderId, unitId, unitName, bookingRef,
   * totalPrice, planName). Empty on a single-unit booking, on a basket viewed
   * whole, and on a fresh journey - so nothing here renders in any of those.
   ***/
  @api siblingUnits = [];

  get hasSiblings() {
    return (this.siblingUnits || []).length > 0;
  }

  /** "One of 2 units on this booking" - the booking's size, not the sibling count. */
  get siblingLead() {
    const booked = (this.bookedUnits || []).length;
    const total = booked > 1 ? booked : (this.siblingUnits || []).length + 1;
    return LABELS.SUMMARY_ONE_OF.replace("{0}", String(total));
  }

  get siblingList() {
    return (this.siblingUnits || []).map((b) => {
      const bits = [];
      if (b.totalPrice != null && b.totalPrice !== "") {
        bits.push(formatAED(b.totalPrice));
      }
      if (b.planName) {
        bits.push(b.planName);
      }
      const name = b.unitName || b.bookingRef || "";
      return {
        id: b.salesOrderId,
        name,
        ref: b.bookingRef || null,
        meta: bits.length ? bits.join(" · ") : null,
        title: LABELS.SUMMARY_OPEN_SIBLING.replace("{0}", b.bookingRef || name)
      };
    });
  }

  handleSiblingOpen(event) {
    const id = event.currentTarget.dataset.id;
    const b = (this.siblingUnits || []).find((x) => x && x.salesOrderId === id);
    if (!b) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("opensibling", {
        detail: {
          salesOrderId: b.salesOrderId,
          unitId: b.unitId,
          unitName: b.unitName,
          bookingRef: b.bookingRef
        }
      })
    );
  }

  /** Only when the counts genuinely differ - on a fresh journey they do not.
      1.15 - and not when the siblings are offered as rows; that IS the line, with a way in. */
  get showBookingCovers() {
    if (this.hasSiblings) {
      return false;
    }
    const booked = (this.bookedUnits || []).length;
    return booked > 1 && booked > this.lineList.length;
  }

  get bookingCoversText() {
    return LABELS.SUMMARY_BOOKING_COVERS.replace(
      "{0}",
      String((this.bookedUnits || []).length)
    );
  }

  /**
   * The units this panel is NOT already showing, named.
   *
   * A count alone ("covers 2 units") tells an agent something is missing without
   * telling them what, which is the same dead end as no line at all.
   */
  get bookingCoversNames() {
    const shown = new Set(this.lineList.map((l) => l.id));
    const missing = (this.bookedUnits || [])
      .filter((b) => !shown.has(b.unitId))
      .map((b) => b.unitName)
      .filter(Boolean);
    return missing.length ? missing.join(" · ") : null;
  }

  /**
   * 1.8 - THE ONE BOOLEAN.
   *
   * 1.4 opened the group matching the step and 1.6 removed that again, for a good
   * reason: it reset on every step change, so a group the agent had deliberately
   * opened shut itself underneath them. The behaviour is worth having - a panel
   * whose default state answers no question is five chevrons - so it comes back
   * under one rule: THE STEP OPENS A GROUP ONLY UNTIL THE AGENT TOUCHES ONE. The
   * moment they open or close anything, the panel stops choosing for them for the
   * rest of the session and never closes a group on their behalf again.
   */
  agentChose = false;
  chosenGroup;

  // ---- tier 1: the masthead ---------------------------------------------

  get head() {
    return this.headline || {};
  }
  get hasStage() {
    return !!this.head.stage;
  }
  get stageClass() {
    return TONE_CHIP[this.head.stageTone] || TONE_CHIP.flat;
  }
  /** A verification state is words, not money, so it does not take the money size. */
  get figureClass() {
    return this.head.figureSmall ? "summary__fig summary__fig--sm" : "summary__fig";
  }
  // ---- tier 2: the focus line -------------------------------------------

  get hasFocus() {
    return !!(this.focusLine && this.focusLine.text);
  }
  get focusClass() {
    return TONE_FOCUS[(this.focusLine || {}).tone] || TONE_FOCUS.flat;
  }

  // ---- tier 3, group 1: the units ---------------------------------------

  get lineList() {
    return Array.isArray(this.lines) ? this.lines : [];
  }
  get hasLines() {
    return this.lineList.length > 0;
  }
  /** Pluralised on the COUNT. There is no `multi` flag left to branch on. */
  get unitsLabel() {
    return this.lineList.length === 1 ? "Unit" : "Units";
  }
  /**
   * What a shut group says. This is the change that makes the panel worth having
   * closed: "2 · AED 32,624,996" is an answer, "Units ›" is not.
   */
  get unitsValue() {
    const n = this.lineList.length;
    if (!n) return null;
    const total = (this.totals || {}).total;
    return total ? `${n} · ${total}` : this.unitCountText;
  }
  get unitCountText() {
    const n = this.lineList.length;
    return n === 1 ? LABELS.SUMMARY_UNIT_ONE : LABELS.SUMMARY_UNITS_N.replace("{0}", String(n));
  }

  // ---- group 2: the customer --------------------------------------------

  get customer() {
    return this.summary && this.summary.customer ? this.summary.customer : null;
  }
  get hasCustomer() {
    return !!(this.customer && this.customer.name);
  }
  /**
   * MSC-176 - IS THIS BOOKING A COMPANY'S?
   *
   * getBookingSummary writes 'Organisation' into customerType, but BOTH spellings
   * are accepted and the test is case-insensitive: 'Organization' is the spelling
   * the EOI journey and the Salesforce record type use, and a rail that disagreed
   * with the customer card about which one counts is exactly the class of bug this
   * change exists to remove.
   *
   * FALSE ON ANYTHING ELSE, INCLUDING BLANK - and that is deliberate. A record with
   * no customerType renders precisely what it renders today; the company shape only
   * ever appears on an explicit answer, never on an absent one.
   */
  get isOrganisationCustomer() {
    const t = ((this.customer && this.customer.customerType) || "")
      .trim()
      .toLowerCase();
    return t === ORGANISATION || t === ORGANIZATION;
  }

  /* The one line the strip shows while the group is shut. For a company that is the
     COMPANY - c.name is the primary contact (see the note on customerRows), and a
     collapsed rail reading "Abdul Rais" over an expanded one reading "Acme Trading
     LLC" describes one booking two ways. */
  get customerValue() {
    const c = this.customer;
    if (!c) return null;
    if (this.isOrganisationCustomer && c.companyName) {
      return c.companyName;
    }
    return c.name;
  }

  /**
   * MSC-176 - A COMPANY IS NOT A PERSON, AND THIS ROW SET SAID IT WAS.
   *
   * The five rows below are a person's: name, contact details, nationality,
   * residency. An organisation booking rendered the same five - so the rail
   * reported a company's Nationality as Afghanistan and its Residency as Resident,
   * which are the PRIMARY CONTACT's answers presented as though they were the
   * company's. Not merely missing information; wrong information, on the card that
   * sits beside the agent through the entire journey.
   *
   * The two values are genuinely distinct and always have been.
   * SalesConsoleController builds the block contact-first:
   *
   *     c.name        = firstNonBlank({ con.Name, acc.Name })   -> the PERSON
   *     c.companyName = acc.Name                                -> the COMPANY
   *
   * with its own comment saying so: "a business Account's Name is the company, and
   * the person on an organisation booking is the primary contact". Nothing new is
   * fetched here; both fields have been on CustomerBlock since 1.7 and the rail
   * simply never read one of them.
   *
   * Nationality and residency are DROPPED for a company rather than relabelled.
   * They belong to the contact, they are already on the customer card under that
   * person, and repeating them here is what created the false reading.
   *
   * "Contact" is CUST_FACT_SIGNATORY - the customer card's own word for this
   * person - so both surfaces name them identically.
   *
   * AND THIS DOES NOT BREAK 1.8's GOVERNING RULE, which the next reader will
   * reasonably ask. That rule forbids branching on a MODE - isBasket, rail versus
   * strip - because a mode is a fact about the screen, not about the booking.
   * customerType is a fact about the booking, written by getBookingSummary from
   * IsPersonAccount. The rule's own test still holds throughout: every row here is
   * still dropped by .filter when its value is absent, so a company with no contact
   * on file shows three rows and not a blank one.
   *
   * Nor could the rule be honoured by data alone. nationality and residentStatus
   * ARE populated on an organisation booking - they are the contact's - so a purely
   * value-driven list would keep printing exactly the two rows that caused the
   * misreading. Suppressing them needs to know whose booking it is.
   *
   * The individual branch is untouched, to the row, the key and the order.
   */
  get customerRows() {
    const c = this.customer;
    if (!c) return [];
    /* 1.18 - masked, matching the card. The clear twins are nulled by the
       server whenever the field is locked; these are always populated. */
    if (this.isOrganisationCustomer) {
      return [
        { key: "company", label: LABELS.SUMMARY_COMPANY, value: c.companyName },
        { key: "name", label: LABELS.CUST_FACT_SIGNATORY, value: c.name },
        { key: "email", label: "Email", value: c.maskedEmail },
        { key: "mobile", label: "Mobile", value: c.maskedMobile }
      ].filter((r) => r.value);
    }
    return [
      { key: "name", label: "Customer", value: c.name },
      { key: "email", label: "Email", value: c.maskedEmail },
      { key: "mobile", label: "Mobile", value: c.maskedMobile },
      { key: "nationality", label: "Nationality", value: c.nationality },
      { key: "residency", label: LABELS.RESIDENCY, value: c.residentStatus }
    ].filter((r) => r.value);
  }
  get showNotSaved() {
    return this.customerDirty;
  }

  // ---- group 3: the payment plan ----------------------------------------

  /**
   * 1.8 - THE PLAN GROUP EXISTS FOR A BASKET TOO.
   *
   * `showPlanGroup = !isBasket` is gone. The reasoning behind it was that plans are
   * per unit and one group could only name a single unit's plan as though it were
   * the booking's - but that is an argument for what the group CONTAINS, not for
   * removing it. It contains one row per unit, and says "2 of 3 plans chosen" while
   * shut, which is precisely the fact a basket agent needs and never had.
   */
  get plansChosen() {
    return this.lineList.filter((l) => l.hasPlan).length;
  }
  get planValue() {
    const lines = this.lineList;
    if (!lines.length) return null;
    if (lines.length === 1) {
      return lines[0].hasPlan ? lines[0].planName : null;
    }
    return LABELS.SUMMARY_PLANS_CHOSEN.replace("{0}", String(this.plansChosen)).replace(
      "{1}",
      String(lines.length)
    );
  }
  /** One row per unit, whatever the count - the single unit is a list of one. */
  get planLines() {
    return this.lineList;
  }
  get hasAnyPlan() {
    return this.plansChosen > 0;
  }
  /** Milestone count, when the server has resolved a plan for a single unit. */
  get planMilestones() {
    const p = this.summary && this.summary.plan ? this.summary.plan : null;
    if (this.lineList.length !== 1 || !p || !p.milestoneCount) return null;
    return `${p.milestoneCount} ${LABELS.MILESTONES}`;
  }

  // ---- group 4: the amounts ---------------------------------------------

  /**
   * 1.8 - ONE SET OF ROWS, EACH SHOWN WHEN ITS FIGURE EXISTS.
   *
   * This used to return a single Total for a basket and five rows for a single
   * unit. It now returns whatever the booking actually has: a basket collecting no
   * payment has no down payment row because there is no down payment, not because
   * `multi` is true - and the moment one exists, it appears.
   */
  get amountRows() {
    const t = this.totals || {};
    /* 1.11 - THREE ROWS BECOME ONE WHILE THE FIGURES ARE THE DEPOSIT.
       SummaryDTO.fees is a FeePreview - admFee, downPayment and minimum are the three
       parts of the BOOKING FEE - and this listed them under "Down Payment", "ADM +
       Dari" and "Due Now", the names of the full obligations. On a 16.3m villa that
       printed "Down Payment AED 204,056.28" against a real first milestone of AED
       815,745, four rows below a Total Price that made the claim look plausible.
       The card states both legs of the fee, with their statuses, a few hundred pixels
       away; what the rail owes the agent is the one figure and its right name. */
    /* 1.16 - post-Confirm: the price, the ADM + Dari charge invoiced against the
       order, what has come in (deposit + approvals) and what is still to collect. The
       booking fee is not a row any more - it is history inside Collected, and the
       masthead says so in words. */
    if (t.isCommitted) {
      return [
        { key: "total", label: LABELS.TOTAL_PRICE, value: t.total, total: true },
        { key: "admc", label: LABELS.SUMMARY_ADM_CHARGE, value: t.admCharge },
        { key: "collected", label: LABELS.COLLECTED, value: t.collected },
        { key: "balance", label: LABELS.BALANCE, value: t.balance }
      ]
        .filter((r) => !!r.value)
        .map((r) => ({
          key: r.key,
          label: r.label,
          value: r.value,
          cls: r.total
            ? "summary-row summary-row--amt summary-row--total summary-row--static"
            : "summary-row summary-row--amt summary-row--static"
        }));
    }
    const feeRows = t.isBookingFee
      ? [{ key: "fee", label: LABELS.BOOKING_FEE, value: t.dueNow }]
      : [
          { key: "down", label: LABELS.DOWN_PAYMENT, value: t.downPayment },
          { key: "adm", label: LABELS.ADM_FEE, value: t.admFee },
          { key: "due", label: LABELS.DUE_NOW, value: t.dueNow }
        ];
    return [
      { key: "total", label: LABELS.TOTAL_PRICE, value: t.total, total: true },
      ...feeRows,
      { key: "collected", label: LABELS.COLLECTED, value: t.collected },
      { key: "balance", label: LABELS.BALANCE, value: t.balance }
    ]
      .filter((r) => !!r.value)
      .map((r) => ({
        key: r.key,
        label: r.label,
        value: r.value,
        cls: r.total
          ? "summary-row summary-row--amt summary-row--total summary-row--static"
          : "summary-row summary-row--amt summary-row--static"
      }));
  }
  get hasAmounts() {
    return this.amountRows.length > 0;
  }
  get amountsValue() {
    return (this.totals || {}).total || null;
  }

  // ---- group 5: payment status ------------------------------------------

  /* 1.13 - `paymentRows`, `hasPayments`, `paymentsValue` and `chipFor` removed with
     the Payment Status group they fed. The obligation ledger on the payment step
     states the same obligations with their money and their actions; this was the
     lesser copy, truncated to "2 of 8 paid · 1 sched…" at the rail's width.
     `payments` stays on the API - the parent still binds it - so restoring the group
     is a template block and these four getters. */

  // ---- chrome -----------------------------------------------------------

  get rootClass() {
    return this.mode === "strip" ? "summary summary--strip" : "summary";
  }

  handleJump(event) {
    const section = event.currentTarget.dataset.section;
    if (!section) return;
    this.dispatchEvent(new CustomEvent("jumpto", { detail: { section } }));
  }

  // ---- collapsing --------------------------------------------------------

  /**
   * Shut unless this is the one group that is open: the step's, until the agent has
   * touched a chevron, and theirs from then on. At most one is ever open, which is
   * what stops the panel arriving several groups deep the way 1.4's did.
   */
  isOpen(group) {
    if (this.agentChose) {
      return this.chosenGroup === group;
    }
    return STEP_GROUP[this.activeKey] === group;
  }

  handleGroupToggle(event) {
    const group = event.currentTarget.dataset.group;
    if (!group) return;
    const wasOpen = this.isOpen(group);
    /* Set BEFORE reading nothing else: from here on the step never chooses again,
       including on the very click that closes the group it had opened. */
    this.agentChose = true;
    this.chosenGroup = wasOpen ? undefined : group;
  }

  /* Templates cannot call methods, so each group exposes its own pair. */
  get unitsOpen() {
    return this.isOpen("units");
  }
  get customerOpen() {
    return this.isOpen("customer");
  }
  get planOpen() {
    return this.isOpen("plan");
  }
  get amountsOpen() {
    return this.isOpen("amounts");
  }

  get unitsChevron() {
    return this.unitsOpen ? "chevron-down" : "chevron-right";
  }
  get customerChevron() {
    return this.customerOpen ? "chevron-down" : "chevron-right";
  }
  get planChevron() {
    return this.planOpen ? "chevron-down" : "chevron-right";
  }
  get amountsChevron() {
    return this.amountsOpen ? "chevron-down" : "chevron-right";
  }

  /* The headline value is what a SHUT group carries; open, the rows say it. */
  get unitsClosed() {
    return this.unitsOpen ? null : this.unitsValue;
  }
  get customerClosed() {
    return this.customerOpen ? null : this.customerValue;
  }
  get planClosed() {
    return this.planOpen ? null : this.planValue;
  }
  get amountsClosed() {
    return this.amountsOpen ? null : this.amountsValue;
  }
}