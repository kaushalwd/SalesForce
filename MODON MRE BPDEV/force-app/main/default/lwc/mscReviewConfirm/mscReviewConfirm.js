/**
 * Section 6 - Review and Confirm.
 *
 * Version  Author      Date         Detail
 * 1.22     Aurelix Dev 30 Sep 2026  The link list waits until every fee's link is sent. Hold chip and a paid link
 *                                   in quiet text with a small mark.
 * 1.21     Aurelix Dev 29 Sep 2026  Booking fee by payment link (linkMode, set from BOOKING_FEE_BY_LINK): link
 *                                   wording and one row per fee link, Resend link while a link is live, and
 *                                   Release unit disabled until it lapses. The hold lasts as long as the link.
 * 1.20     Aurelix Dev 29 Sep 2026  "Confirm all selection" tick beside Confirm Booking (confirmAll). Confirm
 *                                   stays disabled until it is ticked, as in the Sales App's unitSearchLwc.
 * 1.19     Aurelix Dev 29 Sep 2026  Release unit is also offered on a lapsed hold while nothing is collected
 *                                   (showLapsedRelease), and asks the Sales App's question before it raises
 *                                   cancelhold. The server still refuses if money has landed.
 * 1.18     Aurelix Dev 22 Sep 2026  feeCoveredByEoi: with the switch EOI_SKIPS_BOOKING_FEE on, a unit
 *                                   whose EOI has a cleared receipt takes no booking fee; one quiet
 *                                   line beside Confirm says why.
 * 1.17     Aurelix Dev 21 Aug 2026  MSC-098b. The advance strip is gone: its note ("The
 *                                   unit is reserved...") and its rule are retired, and
 *                                   Continue to Verification rides beside the settlement
 *                                   header's figure instead (c-msc-settlement-header
 *                                   `advance` / `advance` event). This card now ends on
 *                                   its last real control and the ledger sits closer.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.1      Aurelix IT  07 Aug 2026  Multi-unit wording and no "due now" for a basket.
 * 1.16     Aurelix Dev 19 Aug 2026  THE HOLD, BESIDE CONFIRM BOOKING. The ledger region
 *                                   below this component is no longer shown before the
 *                                   booking is confirmed (page 1.88, by request), and it
 *                                   was where the "Unit held" / "Still reserved" pill
 *                                   lived once the fee was in. That pill now sits at the
 *                                   left of the Confirm Booking button, on the same
 *                                   words and colours the ledger used (LEDGER_HOLD_*).
 *                                   Nothing after Confirm changes.
 * 1.2      Aurelix IT  10 Aug 2026  Takes the booking fee before it books.
 * 1.4      Aurelix IT  12 Aug 2026  Confirm Booking is hidden, not disabled, while a required
 *                                   booking fee is outstanding - it is the step after the
 *                                   money, so offering it early describes a sequence that
 *                                   does not exist.
 * 1.3      Aurelix IT  12 Aug 2026  Take payment now confirms first, because it blocks the
 *                                   unit for other agents and raises the fee records. The
 *                                   "Outstanding" total is hidden until the fee lines exist -
 *                                   it read AED 0 beneath a six-figure Due Now - and a
 *                                   disabled Confirm now says what it is waiting for.
 * 1.5      Aurelix IT  12 Aug 2026  Phone rules - the action rows stack instead of squeezing.
 * 1.6      Aurelix IT  12 Aug 2026  A Check payment button, and a note that says whether the
 *                                   screen is still watching. The money arrives through a
 *                                   callback outside this page, so there was nothing to press
 *                                   and no way to tell a settled figure from a stale one.
 * 1.8      Aurelix Dev 16 Aug 2026  The recap and Due Now are gone. Both were duplicates -
 *                                   the recap of the summary rail, Due Now of the settlement
 *                                   header that now states the one figure for this step.
 *                                   Every ACTION label is untouched, so reps navigate by
 *                                   the same words they already know from this console.
 *                                   [Corrected 17 Aug 2026 - this note used to claim the
 *                                   labels were Modon's own. They are not. Modon's Book
 *                                   Units journey says Open Modon Pay, Refresh status,
 *                                   Cancel booking, Book / Confirm and Book, Resume
 *                                   payment, Time left to pay and Total to pay now. The
 *                                   console's plainer set was reviewed and kept
 *                                   deliberately - see CHANGELOG MSC-038 - but nothing
 *                                   here should be read as sourced from Modon.]
 * 1.9      Aurelix Dev 16 Aug 2026  The fee ROW LIST removed - a third copy of the two
 *                                   obligations the settlement header states above and the
 *                                   ledger states below - and the two action rows realigned:
 *                                   the terminal note now sits ABOVE the buttons instead of
 *                                   opposite them, and Confirm is right-aligned by its
 *                                   container rather than by an empty spacer element.
 * 1.10     Aurelix Dev 17 Aug 2026  ONE DECISION AT A TIME. `lwc:else` hung off showHold
 *                                   rather than confirmingPay, so pressing Take payment
 *                                   opened its confirmation AND left the original buttons
 *                                   rendered below it - two primary buttons, one of them a
 *                                   live Take payment beneath the prompt asking whether to
 *                                   take payment. It also stranded the expired-hold note,
 *                                   which tells the agent to press a button that was not
 *                                   rendered in that state.
 * 1.13     Aurelix Dev 17 Aug 2026  The THIRD dead control on this card, and the worst
 *                                   placed: once the fee was in, Take payment turned
 *                                   into a disabled "Payment received" and stayed
 *                                   directly above a live Confirm Booking - two stacked
 *                                   primaries, the top one unpressable. It is gone once
 *                                   there is nothing to take.
 * 1.12     Aurelix Dev 17 Aug 2026  AFTER CONFIRM IS A DIFFERENT SCREEN. Three things
 *                                   carried on as though it were not: the pre-Confirm
 *                                   blockers rendered BELOW "Booking confirmed", the
 *                                   confirmation itself sat in the middle of the card,
 *                                   and the primary slot held a disabled "Booking
 *                                   confirmed" - so the one place an agent looks for
 *                                   what to do next contained a control that did
 *                                   nothing. The banner moved up to the settlement
 *                                   header, the blockers stop at Confirm, and the
 *                                   button now goes where the booking goes.
 * 1.14     Aurelix Dev 17 Aug 2026  MONEY, NOT THE HOLD, SECURES THE UNIT - journey 07,
 *                                   and this card was ignoring it twice. Release unit
 *                                   was offered on bookings with cash already collected,
 *                                   and endPaymentHold hands the unit over AND lets the
 *                                   release flow clear the fee lines behind it, so the
 *                                   receipt would have been stranded against records
 *                                   that no longer existed. And the expired-hold note
 *                                   was one hardcoded sentence - "Another agent can take
 *                                   this unit now" - printed over part-paid bookings,
 *                                   where the truth is the opposite: the unit stays
 *                                   reserved and the agent collects the balance. Both
 *                                   now ask hasCollected, which is the question the
 *                                   journey says decides it.
 * 1.15     Aurelix Dev 17 Aug 2026  THREE FIXES FROM THE FLOOR. (a) The hold prompt is
 *                                   the action, not a step before it: Take payment used
 *                                   to open "X will be held for you for 10 minutes" with
 *                                   Cancel beside it, so the rep pressed once to read the
 *                                   sentence and again to act. The block is on screen
 *                                   outright now, with its one button, and Cancel is
 *                                   gone; Take payment inside the waiting strip acts at
 *                                   once, its hint having already said what it does.
 *                                   (b) NOTHING BELOW THE WAIT UNTIL THE MONEY IS IN. The
 *                                   "Before confirming" list rendered under the waiting
 *                                   strip, restating the two amounts the header and the
 *                                   strip already carry, and the ledger below it did the
 *                                   same a third time; both are held back until the
 *                                   backend has confirmed a payment (see
 *                                   awaitingFeeReceipt, and mscBookingPage for the
 *                                   ledger). (c) No em dashes in anything a rep reads.
 * 1.11     Aurelix Dev 17 Aug 2026  WAITING IS A STATE, NOT A DISABLED BUTTON. After Take
 *                                   payment the panel was four unrelated bands - the hold
 *                                   row, a watch sentence, a button row whose visual anchor
 *                                   was an inert grey slab reading "Waiting for payment…",
 *                                   and a fourth sentence about Confirm. They are one
 *                                   object now, and the primary button went back to being
 *                                   a button: it reopens the terminal, which an agent who
 *                                   had closed that tab previously had no way to do.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/* 1.21 - the payment link's words, kept with the only component that says them */
const LINK_NOTE = "The customer receives a payment link for each fee by email and SMS.";
const LINK_WAIT_BODY =
  "The customer pays by the link. This screen checks every few seconds, and Confirm Booking appears here once the payment lands.";
const LINK_RELEASE_WAIT = "Release is available once the payment link expires.";
const LINK_RESEND_HINT = "Resend link sends the same link again. Nothing is charged twice.";
const LINK_SEND_AGAIN_HINT = "Send payment link sends a new link and reserves the unit again.";
const LINK_LAPSED_OPEN =
  "The unit is given back shortly. Send payment link to reserve it again, or release it now.";
const LINK_LAPSED_SAFE =
  "A payment has been received, so this unit stays reserved. Send payment link to collect the balance.";

/**
 * Section 6 - Review & Confirm (Modon comment 4).
 *
 * One "Confirm Booking" action and the recap it acts on - Modon asked that the
 * backend steps stay unexposed, so "Generate Sales Order" appears nowhere.
 *
 * Blockers are listed rather than just disabling the button: each names its remedy,
 * so a disabled button is never a dead end.
 */
export default class MscReviewConfirm extends LightningElement {
  /* 1.8 - `rows` and `dueNow` removed. The recap duplicated the summary rail
     verbatim, and Due Now was a third total on a screen that now has one. */
  /** Plain-language reasons confirmation is not yet possible. */
  @api blockers = [];
  @api busy = false;
  @api confirmed = false;
  @api bookingReference;
  /**
   * 1.1 - How many units this confirmation covers. Drives the wording only; the
   * decision about what actually happens is the controller's.
   */
  @api unitCount = 1;

  /*** 1.2 - the booking fee.
   *
   * The console confirmed bookings without collecting a dirham: the fee lines were
   * created and then ignored, and a unit went to Reserved unpaid. Modon's own
   * journey gates its Book button on the money having landed, so this one does too.
   ***/
  /** BookingFeeLineController.FeeStatus - what is owed and what has been received. */
  @api feeStatus;
  /** False for phases that do not take a booking fee; the panel then never shows. */
  @api paymentRequired = false;
  /** 1.18: true when the unit's EOI deposit stands in for the booking fee. */
  @api feeCoveredByEoi = false;
  /**
   * True while a payment run is open - the terminal has been sent for and the money
   * has not landed.
   *
   * 1.11 - the parent DERIVES this from the unit hold now rather than remembering it,
   * so it survives the booking being closed and reopened. Nothing here changed except
   * that it can now be true on a screen that has just loaded.
   */
  @api awaitingPayment = false;
  /** True only while beginPayment is in flight. Guards the double-press, nothing else. */
  @api busyPay = false;

  /*** 1.3 - taking payment blocks the unit, so it is confirmed first. ***/
  /** From the same custom label the server honours - never hardcode this. */
  @api holdMinutes = 10;
  @api unitName;

  /*** 1.6 - checking on the money.
   *
   * The money lands through a REST callback outside this page, so the screen has no
   * way of knowing until it asks. It asked automatically only in the tab that pressed
   * Take payment, and nowhere else - so an agent returning to a booking saw a figure
   * frozen at whatever it was when they left, with nothing to press.
   ***/
  /** True while a status check is in flight. Spins the icon; blocks nothing else. */
  @api refreshing = false;
  /** Set when the hold has lapsed and automatic checking has stopped. */
  @api watchStopped = false;

  /*** 1.7 - the hold, as a clock.
   *
   * `holdMinutes` above is the LENGTH of the window and is right for the confirmation
   * prompt ("held for you for 10 minutes"). It is wrong once the hold is running: an
   * agent resuming a booking read the same 10 whether eight minutes were left or none.
   * This is what actually remains, counted down by the page and resynced from the
   * server, so the number on screen is the number the server would enforce.
   ***/
  @api holdSecondsLeft;
  @api cancellingHold = false;
  /**
   * 1.14 - has any money landed against this booking fee?
   *
   * Journey 07, stated as a principle: "Money, not the hold, is what secures the
   * unit. Once any payment exists, the Cancel button disappears and the hold's
   * expiry stops mattering. The console must not offer a release path that strands
   * collected cash." Two things here were deciding without asking it - see
   * showCancelHold and lapsedNote.
   */
  @api hasCollected = false;

  /* 1.15 - `confirmingPay` is gone with the deciding state. */

  /*** 1.21 - the booking fee by payment link ***/
  /** True when the fee is collected by links sent to the customer, not at the MODON Pay card page. */
  @api linkMode = false;
  /** One row per fee: { key, label, amountText, statusText, untilText, cls }. */
  @api feeLinks = [];
  /** A link the customer can still pay. While true the unit cannot be released. */
  @api linkLive = false;
  /** True while Resend link is in flight. */
  @api busyResend = false;

  labels = LABELS;

  /* 1.18: the one line beside Confirm */
  get showEoiFeeNote() {
    return this.feeCoveredByEoi === true && !this.isMultiUnit && !this.confirmed;
  }

  get showFees() {
    return this.paymentRequired === true && !this.isMultiUnit && !this.confirmed;
  }


  /* One line. The first version also spelled out that other agents are locked out and
     that the fee gets raised - both true, neither the agent's problem at the moment
     they are asking to take a payment.
     1.15 - only ever read in the idle state now, where no hold is running (a running
     hold against an unsettled fee IS the waiting state), so the "stays held for
     another N minutes" branch that 1.11 added has no reader and is gone. */
  get holdPrompt() {
    const unit = this.unitName ? this.unitName : "This unit";
    /* 1.21 - a link holds the unit for the link's life, not the terminal's window */
    if (this.linkMode) {
      return `${unit} will be reserved while the payment link is live.`;
    }
    return `${unit} will be held for you for ${this.holdMinutes} minutes.`;
  }

  /* 1.21 - what happens when the button is pressed, in one line */
  get payNote() {
    return this.linkMode ? LINK_NOTE : LABELS.PAY_TERMINAL_NOTE;
  }

  /* 1.21 - the prompt's one button */
  get startLabel() {
    return this.linkMode ? "Send payment link" : "Hold and take payment";
  }

  /* 1.21 - the waiting strip's title */
  get waitTitle() {
    return this.linkMode ? "Payment link sent" : LABELS.PAY_WAIT_TITLE;
  }

  /* 1.21 - the fee rows, only where there is a link to speak of */
  get showLinks() {
    /* 1.22 - not while the links are being sent: the list appears whole, never one fee at a time */
    return this.linkMode && this.showFees && this.busyPay !== true && (this.feeLinks || []).length > 0;
  }

  /* 1.21 - Release unit is on screen but not usable while the customer can still pay */
  get releaseBlocked() {
    return this.linkMode === true && this.linkLive === true;
  }

  get releaseDisabled() {
    return this.cancellingHold || this.releaseBlocked;
  }

  get releaseTitle() {
    return this.releaseBlocked ? LINK_RELEASE_WAIT : "";
  }

  /* 1.21 - the reason, said once under the actions while Release is blocked */
  get showReleaseWait() {
    return this.releaseBlocked && (this.showCancelHold || this.showLapsedRelease);
  }

  get releaseWaitText() {
    return LINK_RELEASE_WAIT;
  }

  /* 1.21 - the hint under the waiting strip's buttons */
  get payHint() {
    if (!this.linkMode) return LABELS.PAY_REOPEN_HINT;
    return this.linkLive ? LINK_RESEND_HINT : LINK_SEND_AGAIN_HINT;
  }

  /**
   * 1.4 - Confirm is absent, not disabled, while a required fee is outstanding.
   *
   * `isSettled` is already true whenever no fee is required, so a phase that takes no
   * booking fee is unaffected and confirms immediately as before.
   */
  get showConfirm() {
    /* 1.12 - and NOT once it is done. A disabled button reading "Booking confirmed"
       is a status wearing the clothes of a control - the same defect 1.11 removed
       from the waiting state - and it held the position the next action belongs in.
       showAdvance renders that action instead. */
    return this.isSettled && !this.confirmed;
  }

  /* 1.16 - the hold, beside Confirm Booking. Only while there IS a hold to speak of
     (the page passes holdSecondsLeft only once one was taken) and the fee is in, so
     the pill the ledger used to carry is not lost with the ledger. A lapsed hold on a
     fee still being collected keeps its own row above (showLapsedHold). */
  get showConfirmHold() {
    return this.showConfirm
      && this.holdSecondsLeft !== undefined && this.holdSecondsLeft !== null;
  }

  get confirmHoldText() {
    if (this.holdActive) return LABELS.LEDGER_HOLD_LIVE;
    return this.hasCollected ? LABELS.LEDGER_HOLD_SAFE : LABELS.LEDGER_HOLD_GONE;
  }

  get confirmHoldClass() {
    if (this.holdActive) return "chip chip--due confirm__hold";
    return this.hasCollected ? "chip chip--paid confirm__hold" : "chip chip--alert confirm__hold";
  }

  /* Said in full only where the pill alone would be a riddle: a lapsed hold on a
     booking whose money is in stays reserved (journey 07). */
  get confirmHoldNote() {
    return this.showConfirmHold && !this.holdActive && this.hasCollected
      ? LABELS.LEDGER_HOLD_SAFE_NOTE : null;
  }

  /* ── 1.11  the states, named ────────────────────────────────────────────────
     Exactly one of these is on screen at a time. They were already exclusive after
     1.10; naming them stops the markup from carrying the logic in its nesting.
     1.15 - two states, not three: `deciding` (the hold prompt as a step of its own)
     is gone. The prompt IS the idle state's action now. */

  /** The terminal has been sent for and the money has not landed. */
  get waiting() {
    return this.showFees && !this.isSettled && this.awaitingPayment === true;
  }

  /** Nothing in flight: the prompt with its one button, and whatever is blocking Confirm. */
  get idle() {
    return !this.waiting;
  }

  /**
   * 1.15 - the fee is owed, a payment has been asked for or could be, and NOTHING has
   * landed yet. While this is true the "Before confirming" list is held back: it
   * would only restate the two amounts the header above and the strip beside it
   * already carry. mscBookingPage holds the ledger back on the same condition. Any
   * money at all (hasCollected) or the fee settling brings both back.
   */
  get awaitingFeeReceipt() {
    return this.showFees && !this.isSettled && !this.hasCollected;
  }

  /** Why Confirm is not there yet. Its absence should not be a mystery either. */
  get feeBlockerText() {
    /* 1.11 - silent while waiting, where the strip says the same thing in the
       place the agent is already reading. */
    if (!this.idle) {
      return null;
    }
    return this.showFees && !this.isSettled
      ? LABELS.PAY_CONFIRM_APPEARS
      : null;
  }

  /**
   * What the waiting strip says while it waits.
   *
   * One sentence, covering the two things an agent standing at a terminal wants to
   * know: is this screen watching, and where does Confirm come from. Both used to be
   * separate bands - one above the buttons and one below them.
   */
  get waitBody() {
    if (this.watchStopped) return LABELS.PAY_WAIT_BODY_STOPPED;
    /* 1.21 - no terminal tab in link mode */
    return this.linkMode ? LINK_WAIT_BODY : LABELS.PAY_WAIT_BODY;
  }

  /* The dot is a live indicator, so it goes still when checking has stopped -
     an animation that keeps running past the thing it represents is a lie. */
  get waitDotClass() {
    return this.watchStopped ? "paywait__dot paywait__dot--off" : "paywait__dot";
  }

  /*** 1.6 - the manual status check ***************************************/

  /** Only where it means something: a fee is owed and not yet settled. */
  get showRefresh() {
    return this.showFees && !this.isSettled;
  }

  get refreshDisabled() {
    return this.refreshing || this.busy;
  }

  get refreshIconClass() {
    return this.refreshing ? "fees__refresh fees__refresh--spin" : "fees__refresh";
  }

  get refreshTitle() {
    return this.refreshing ? "Checking payment…" : "Check payment status";
  }

  handleRefresh() {
    if (this.refreshDisabled) return;
    this.dispatchEvent(new CustomEvent("refreshfees"));
  }

  /** Said out loud, because silence looks identical to "still waiting". */
  get watchNote() {
    if (!this.showFees || this.isSettled) return null;
    /* 1.10 - "payment is taken at the terminal" moved into the confirmation prompt,
       which is where it is actually needed. What is left here is only what this
       line is for: whether the screen is still watching.
       1.11 - and only when it has STOPPED. "This screen checks for the payment every
       few seconds" was printed from the moment the step opened, over a Take payment
       button nobody had pressed - announcing a watch on a payment that had not been
       requested. While one IS in flight the waiting strip carries it instead. */
    return this.watchStopped ? LABELS.PAY_WATCH_STOPPED : null;
  }

  /*** 1.7 - the hold clock **************************************************/

  get holdActive() {
    return Number(this.holdSecondsLeft) > 0;
  }

  /** Only once a hold exists: before Take payment there is nothing to count down. */
  get showHold() {
    return this.showFees && !this.isSettled
      && this.holdSecondsLeft !== undefined && this.holdSecondsLeft !== null;
  }

  /* 1.11 - the LAPSED hold, on its own. A running hold belongs inside the waiting
     strip, beside what it is protecting; a lapsed one belongs above the idle actions,
     with the note telling the agent to press the button now rendered below it. */
  get showLapsedHold() {
    return this.idle && this.showHold && !this.holdActive;
  }

  get holdExpired() {
    return this.showHold && !this.holdActive;
  }

  /** "7:04". Seconds shown throughout - under a minute, minutes alone read as zero. */
  get holdClock() {
    const total = Math.max(0, Number(this.holdSecondsLeft) || 0);
    const m = Math.floor(total / 60);
    const s = `${total % 60}`.padStart(2, "0");
    return `${m}:${s}`;
  }

  get holdText() {
    /* 1.21 - in link mode the hold and the reservation last as long as the link */
    if (this.linkMode) {
      return this.holdActive
        ? `Reserved for ${this.holdClock}`
        : "The payment link has expired";
    }
    return this.holdActive
      ? `Unit held for ${this.holdClock}`
      : "The hold on this unit has expired";
  }

  /**
   * 1.14 - A LAPSED HOLD IS TWO DIFFERENT SITUATIONS, and this said only one of them.
   *
   * The note under an expired hold was a single hardcoded sentence opening "Another
   * agent can take this unit now" - printed regardless of whether anything had been
   * collected. Journey 07 lists the two cases separately and they have opposite
   * meanings: expired with nothing collected really does release the unit; expired
   * with part collected leaves it reserved and the agent completes the balance. So
   * the console was raising a false alarm about losing the unit on precisely the
   * booking where the customer had already handed over money for it.
   */
  get lapsedNote() {
    /* 1.21 - the link's words: the buttons are Send payment link and Release unit */
    if (this.linkMode) {
      return this.hasCollected ? LINK_LAPSED_SAFE : LINK_LAPSED_OPEN;
    }
    return this.hasCollected ? LABELS.PAY_LAPSED_SAFE : LABELS.PAY_LAPSED_OPEN;
  }

  /* Reassurance and warning must not be set in the same tone. */
  get lapsedNoteClass() {
    return this.hasCollected ? "hold__note hold__note--safe" : "hold__note";
  }

  /* The pill itself follows the money, for the same reason: red is wrong for a unit
     that is not going anywhere. */
  get lapsedHoldClass() {
    return this.hasCollected ? "hold hold--safe" : "hold hold--out";
  }

  get lapsedHoldText() {
    if (this.linkMode) {
      return this.hasCollected
        ? "The payment link has expired. This unit stays reserved"
        : "The payment link has expired";
    }
    return this.hasCollected
      ? "The hold has expired. This unit stays reserved"
      : "The hold on this unit has expired";
  }

  /* Amber while it runs, red once it has gone - the same two states the rest of the
     console uses for "in progress" and "needs attention". */
  get holdClass() {
    return this.holdActive ? "hold hold--live" : "hold hold--out";
  }

  /**
   * Only worth offering while there is something to give back - and only while
   * giving it back is safe.
   *
   * 1.14 - `hasCollected` added. Release ran `endPaymentHold`, which hands the unit
   * over AND lets the "Unit - Release Expired Payment Hold" flow clear the fee lines
   * behind it. Do that on a booking the customer has already part-paid and the money
   * is stranded: a receipt against fee lines that no longer exist, on a unit another
   * agent can now book. Journey 17.4 asks for exactly this gate, and Modon's own Book
   * Units journey hides Cancel here rather than disabling it - so this does too. The
   * ledger states what happened instead, in the same place it states everything else.
   */
  get showCancelHold() {
    return this.holdActive && !this.confirmed && !this.hasCollected && !this.confirmingRelease;
  }

  /* 1.19 - also beside a lapsed hold's pill while nothing is collected, as in the Sales App */
  get showLapsedRelease() {
    return this.showLapsedHold && !this.confirmed && !this.hasCollected && !this.confirmingRelease;
  }

  get cancelHoldLabel() {
    return this.cancellingHold ? "Releasing…" : "Release unit";
  }

  /* 1.19 - the question before the release, one at a time, in the Sales App's words */
  confirmingRelease = false;

  /** True while the question is open and the release is still on offer. */
  get askRelease() {
    return this.confirmingRelease && !this.confirmed && !this.hasCollected
      && this.holdSecondsLeft !== undefined && this.holdSecondsLeft !== null;
  }

  /** The question beside a running hold (inside the waiting strip). */
  get askReleaseLive() {
    return this.askRelease && this.waiting;
  }

  /** The question beside a lapsed hold (the idle state). */
  get askReleaseLapsed() {
    return this.askRelease && !this.waiting;
  }

  handleCancelHold() {
    /* 1.21 - not while the customer can still pay the link (the server refuses it too) */
    if (this.cancellingHold || this.releaseBlocked) return;
    this.confirmingRelease = true;
  }

  handleReleaseYes() {
    if (this.cancellingHold) return;
    this.confirmingRelease = false;
    this.dispatchEvent(new CustomEvent("cancelhold"));
  }

  handleReleaseNo() {
    this.confirmingRelease = false;
  }

  handleReleaseKey(event) {
    if (event.key === "Escape") {
      this.confirmingRelease = false;
    }
  }

  /**
   * 1.15 - one press, one event. Both buttons that raise this - "Hold and take
   * payment" in the idle prompt and "Take payment" in the waiting strip - now act at
   * once; the confirmation step (confirmingPay / cancelPay / confirmPay) is gone.
   * Safe from the waiting strip too: beginPayment is documented safe to repeat (it
   * syncs the fee lines rather than duplicating them, and re-taking the hold extends
   * it), and the strip's hint says exactly that before the button is pressed.
   */
  handlePayClick() {
    if (this.payDisabled) return;
    /* 1.21 - while a link is live the primary sends the same link again */
    if (this.linkMode && this.linkLive) {
      this.dispatchEvent(new CustomEvent("resendlink"));
      return;
    }
    this.dispatchEvent(new CustomEvent("pay"));
  }

  get isSettled() {
    if (!this.showFees) return true;
    const f = this.feeStatus;
    // allowPartialBooking is a deliberate management override from Manage
    // Inventory, not a loophole - unitBookingJourney honours it and so does this.
    return !!f && (f.isFullyPaid === true || f.allowPartialBooking === true);
  }

  /**
   * 1.11 - always "Take payment" until the money is in.
   *
   * It used to read "Waiting for payment…" and go dead, which put the state of the
   * booking on a control instead of in the copy - and left the one thing an agent
   * needs when the terminal tab has been closed, or when they have come back to the
   * booking from Total Sales, with nothing to press. The waiting strip states the
   * state; this stays a button and reopens the terminal.
   */
  get payLabel() {
    /* 1.21 - link mode: resend while a link is live, send a new one once none is */
    if (this.linkMode) {
      if (this.busyResend) return "Sending\u2026";
      return this.linkLive ? "Resend link" : "Send payment link";
    }
    return "Take payment";
  }

  get payDisabled() {
    return this.busy || this.busyPay === true || this.busyResend === true;
  }

  /**
   * 1.13 - GONE once the money is in, rather than greyed out.
   *
   * It used to turn into a disabled "Payment received" and stay on screen - the third
   * dead control this card has carried, and the worst placed: it sat directly above a
   * live Confirm Booking, so the two primaries stacked and the top one, the one the eye
   * lands on first, could not be pressed.
   *
   * There is nothing to take once nothing is owed. Both legs read Settled and the
   * header says so in 28px; a button restating it is a third copy that also happens to
   * look broken. showConfirm renders the action that IS available in its place.
   */
  get showPayAction() {
    return this.showFees && !this.isSettled;
  }

  /** The row exists only if something is in it. */
  get showActionRow() {
    return this.showRefresh || this.showPayAction;
  }


  get isMultiUnit() {
    return Number(this.unitCount || 1) > 1;
  }

  get blockerRows() {
    return (this.blockers || []).map((b, i) => ({ key: `b-${i}`, text: b }));
  }

  get hasBlockers() {
    return this.blockerRows.length > 0;
  }

  /**
   * 1.12 - blockers are a PRE-Confirm concept and stop existing at Confirm.
   *
   * "Before confirming: ADM + Dari has not been received yet" rendered directly under
   * "Booking confirmed", which reads as though the booking had been made in error. The
   * fee is genuinely still owed - the settlement header above states exactly that, and
   * states it as the subject of the screen rather than as a warning - but it is no
   * longer blocking anything, because there is nothing left for it to block.
   */
  get showBlockers() {
    /* 1.15 - and not while the booking fee is being waited for. See awaitingFeeReceipt. */
    return this.hasBlockers && !this.confirmed && !this.awaitingFeeReceipt;
  }

  /* 1.17 / MSC-098b - the advance strip (showAdvance / advanceNote / handleAdvance)
     moved to c-msc-settlement-header: the button rides beside the headline figure,
     the note and the rule retired with the strip. */

  get canConfirm() {
    // 1.2 - and the fee has to have been received. The server refuses this too;
    // disabling here is so the agent is not invited to click something that
    // cannot succeed. 1.20 - and "Confirm all selection" is ticked, as the Sales App requires.
    return !this.busy && !this.hasBlockers && !this.confirmed && this.isSettled && this.confirmAll;
  }

  /* 1.20 - the Sales App's required "Confirm all selection" tick */
  confirmAll = false;

  handleConfirmAllChange(event) {
    this.confirmAll = event.target.checked === true;
  }

  get confirmDisabled() {
    return !this.canConfirm;
  }

  get confirmLabel() {
    // 1.1 - "Generate Sales Orders" for a basket. Modon asked that backend processes
    // stay hidden, and for a single booking they are. But a basket produces several
    // Sales Orders and takes no payment, and calling that "Confirm Booking" would
    // describe something that is not happening.
    if (this.busy) {
      return this.isMultiUnit ? LABELS.MULTI_CONFIRMING : LABELS.CTA_CONFIRMING;
    }
    if (this.confirmed) {
      return this.isMultiUnit ? "Sales Orders generated" : "Booking confirmed";
    }
    return this.isMultiUnit ? LABELS.MULTI_CONFIRM_CTA : LABELS.CTA_CONFIRM;
  }

  handleConfirm() {
    if (!this.canConfirm) return;
    this.dispatchEvent(new CustomEvent("confirm"));
  }
}