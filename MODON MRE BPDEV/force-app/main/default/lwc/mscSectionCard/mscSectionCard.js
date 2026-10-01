/**
 * Section chrome for the single-page booking journey.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 * 1.4      Aurelix Dev 30 Sep 2026  On a phone the heading's controls drop under the title rather than wrap it
 *                                   (UI-18). CSS only; wider screens unchanged.
 */

import { LightningElement, api } from "lwc";

/**
 * Section chrome for the single-page journey. The rule it encodes: VISIBLE IS NOT
 * EDITABLE. A section the agent cannot act on yet is dimmed and inert, never hidden,
 * so the shape of the whole journey is legible from first paint.
 *
 *   todo      dimmed + inert; the aside says what unblocks it
 *   active    editable, border brightened
 *   complete  collapsed to a one-line summary with an Edit affordance
 *   blocked   amber rule; the aside carries the reason
 */
export default class MscSectionCard extends LightningElement {
  /** 1-6. Rendered in the eyebrow so the section index and nav agree. */
  @api index;
  /** Small uppercase label above the heading. */
  @api eyebrow;
  @api heading;
  /** 'todo' | 'active' | 'complete' | 'blocked' */
  @api state = "todo";
  /** Stable key used by the scroll-spy and the summary's jumpto. */
  @api sectionKey;
  /** One-line recap shown when complete and collapsed. */
  @api summaryLine;
  /** Short reason shown in the aside when todo or blocked. */
  @api asideText;
  @api collapsible = false;

  get isComplete() {
    return this.state === "complete";
  }
  get isBlocked() {
    return this.state === "blocked";
  }

  /**
   * 1.2 - any collapsed section with something to say, not just a complete one.
   * The journey now collapses the section behind the agent when they press
   * Continue, and the unit section is deliberately never "complete" - so gating
   * this on isComplete left a collapsed card showing its number and heading and
   * no trace of the unit that was picked.
   */
  get showSummaryLine() {
    return !this.isOpen && !!this.summaryLine;
  }

  /**
   * 1.4 - a card that is the ONLY card in its step does not need to name itself:
   * the stepper directly above already reads "1 Unit Selection", and the card was
   * repeating it twice more as an eyebrow and an h2. Three statements of the same
   * two words cost ~90px of the first screen and told the agent nothing. When the
   * journey passes no eyebrow and no heading, the header is dropped entirely.
   */
  /**
   * 1.5 - only when it adds something. An eyebrow that repeats the heading
   * verbatim is decoration that costs a line of vertical space and reads as a
   * rendering fault. It survives when it carries a step number, or genuinely
   * differs from the heading.
   */
  get showEyebrow() {
    if (!this.eyebrow) return false;
    if (this.index) return true;
    return String(this.eyebrow).trim().toLowerCase() !==
      String(this.heading || "").trim().toLowerCase();
  }

  get showHead() {
    return !!(
      this.eyebrow ||
      this.heading ||
      this.showSummaryLine ||
      this.showAside ||
      this.collapsible
    );
  }

  get showAside() {
    return !!this.asideText && (this.state === "todo" || this.state === "blocked");
  }

  /**
   * Drops the card's own frame - border, glass fill and padding - and leaves only
   * its head and body.
   *
   * For a card that is ALREADY inside a frame. The unit step is one: it fills the
   * left column of a two-pane layout that is itself bounded and bordered, so the
   * card drew a second rounded rectangle a few pixels inside the first and spent
   * 40px of column width on the gap between them. The state colour goes with it,
   * which is acceptable there because the head's own chip already carries it.
   */
  @api bare = false;

  /**
   * 1.6 - THE BODY SCROLLS INSIDE THE CARD, AND THE SCROLLBAR IS INVISIBLE.
   *
   * Opt-in, because it is wrong for most cards here: a section that scrolls
   * inside a page that also scrolls is two scroll regions for one hand, and the
   * journey deliberately gives each step one card's worth of content. It is right
   * for the STEP 2 PAIR, where two tall cards sit side by side and the taller one
   * decides how far the rep has to scroll to reach anything in the shorter one.
   *
   * The height comes from --section-body-max, set by the parent on this element.
   * A custom property, not an @api number: it crosses the shadow boundary on its
   * own and lets the parent express the height as the same clamp() arithmetic it
   * uses for the pane, rather than as a number this component would have to be
   * told again on every breakpoint.
   */
  @api scrollBody = false;

  /**
   * 1.7 - fill the height the host is given, rather than the height the content
   * wants.
   *
   * Opt-in, and only step 2's pair uses it. Two cards side by side whose contents
   * differ by a screen and a half ended on two different lines, which is the
   * single thing that made that step read as unfinished. With a height on the
   * cell, this makes the card take all of it and its body take what is left after
   * the head - so both cards end where the row ends and each scrolls its own
   * content.
   *
   * Every other card in the console leaves this false and is untouched: without
   * it the section is laid out exactly as it was.
   */
  @api fill = false;

  get rootClass() {
    const base = `section section--${this.state}`;
    const withBare = this.bare ? `${base} section--bare` : base;
    return this.fill ? `${withBare} section--fill` : withBare;
  }

  get bodyClass() {
    return this.scrollBody ? "section__body section__body--scroll" : "section__body";
  }

  get eyebrowLabel() {
    return this.index ? `${this.index} · ${this.eyebrow || ""}` : this.eyebrow;
  }

  get toggleLabel() {
    return this.isOpen ? "Collapse" : "Edit";
  }

  /*** 1.3  Start - Aurelix IT 09 Aug 2026, parent-controlled open ********
   *
   * The journey now keeps exactly ONE section open, so which one that is cannot
   * live in here - two cards each holding their own boolean cannot enforce a rule
   * about the pair of them. The page owns it; this card renders it and asks.
   *
   * Replaces collapse()/expand() and the tri-state _openOverride, both of which
   * existed to reconcile a local guess with the journey's intent.
   */
  /* Left undefined rather than defaulted to true - LWC rejects a boolean public
     property initialised to true (LWC1503). Undefined means "nobody said close
     me", which is the right default now that the journey only renders a card
     when its step is the open one. */
  @api open;

  get isOpen() {
    return this.open !== false;
  }
  /*** 1.3  End *******************/

  handleToggle() {
    this.dispatchEvent(
      new CustomEvent("toggle", {
        detail: { sectionKey: this.sectionKey, open: !this.open }
      })
    );
  }
}