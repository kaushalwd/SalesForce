/**
 * The compliance check, before the submit.
 *
 * Version  Author      Date         Detail
 * x.y+2    Aurelix Dev 30 Sep 2026  Save takes what is in the controls and a re-read no longer drops typing (R2-07);
 *                                   Occupation reads "Position" (R2-08); dates dd/mm/yyyy (UI-13); grey closed Submit (R2-16).
 * x.y+1    Aurelix Dev 28 Sep 2026  Required and missing, shown (testing, 28 Sep). Submit sat
 *                                   disabled with the reason only in the footer, and the missing fields
 *                                   could be below the fold. Every field the submit waits on now has a
 *                                   muted star on its label (FieldDTO.required, SalesConsoleCompliance-
 *                                   Service 1.x+3; a section detail counts as required if an older
 *                                   answer lacks the flag). One still empty has a quiet amber edge: the
 *                                   control's border, or a blank line under a fact the rep cannot type.
 *                                   A rail row now scrolls to and focuses the first missing field of its
 *                                   group (its heading, as before, when none is missing), and the
 *                                   footer's "still needed" sentence does the same for the whole form.
 *                                   Counts, footer wording, what is required and the submit rules are
 *                                   unchanged.
 * x.y      Aurelix Dev 18 Sep 2026  The three Transaction Details selects open with the theme's own
 *                                   colours (color-scheme + option rule), as MSC-173 did for the
 *                                   manual-KYC form. CSS only.
 * 1.0      Aurelix IT  19 Aug 2026  Initial. MSC-069.
 * 1.1      Aurelix IT  19 Aug 2026  Form grouped to match the rail. MSC-070.
 * 1.2      Aurelix IT  19 Aug 2026  Verified details are read only. MSC-071.
 * 1.3      Aurelix IT  19 Aug 2026  No edit mode; one details block. MSC-072.
 * 1.4      Aurelix IT  19 Aug 2026  Two halves; an unsaved edit holds the submit. MSC-073.
 * 1.5      Aurelix IT  19 Aug 2026  Refresh, for documents that arrive while the rep waits. MSC-073.
 * 1.6      Aurelix IT  19 Aug 2026  Identity Proof reads below the line. MSC-074.
 * 1.7      Aurelix IT  19 Aug 2026  No pre-fill; the verification is dated in full. MSC-076.
 * 1.8      Aurelix IT  19 Aug 2026  Booking context holds the submit, and both buttons
 *                                   say why they are closed. MSC-077.
 * 1.9      Aurelix IT  19 Aug 2026  The real-beneficiary declaration. MSC-078.
 * 1.10     Aurelix IT  20 Aug 2026  A read-only context detail reads with the rest of
 *                                   what the verification settled. MSC-079.
 * 1.11     Aurelix IT  20 Aug 2026  MSC-083. The party strip: one booking can have up to
 *                                   seven people to send, and each of them is a separate
 *                                   submission with a separate checklist. Everything
 *                                   below the strip is unchanged - it swaps WHICH
 *                                   ChecklistDTO the rail, the form, the documents and
 *                                   the footer are rendering, and nothing else.
 *
 *                                   A TAB IS NEVER A COUNT. The sketch for this had each
 *                                   tab reading "12/17", which cannot be true without an
 *                                   Apex call per person on every open - so a tab carries
 *                                   a name, a role and one state word, all of which the
 *                                   page already holds from the Ownership panel. The
 *                                   count belongs to the person actually open.
 *
 *                                   SWITCHING IS HELD WHILE AN EDIT IS UNSAVED, by the
 *                                   same reasoning that already holds Submit: the server
 *                                   checks the RECORD, so moving away over a typed
 *                                   control would silently discard what was typed. Held
 *                                   with a reason on the tab, not a modal asking a
 *                                   question the footer has already answered.
 *
 * Automatic submission is off (MSC-068), so the rep sends the customer to compliance
 * themselves. This is what they read before they do: a readiness rail that does not
 * scroll away, and a form grouped the way the rail counts.
 *
 * ONE GROUPING, NOT TWO. The rail counts Identity, Personal, Address and Documents, so
 * the form is written in those same four groups and a rail row scrolls to its own
 * heading. Splitting the form a second way instead - everything missing, then everything
 * known - meant the rep held two pictures of the same customer at once, and put a field
 * away from the value it refers to.
 *
 * NO EDIT MODE. There were once two ways to read a field - fact or control - and a
 * toggle in the header to swap between them. An edit mode exists to protect a large
 * writable surface from a slip; here the writable surface is three fields and the rest
 * is protected by the server, so the toggle guarded nothing and hid the only controls on
 * the screen behind a link the rep had to find first. The three are simply controls, all
 * the time, and there is no mode to be in.
 *
 * EXCEPT WHAT THE VERIFICATION OWNS. A detail the identity verification writes is never a
 * control here - not when it is missing, and not under the toggle either. Missing, it
 * reads exactly as a missing document does, because the rep does the same thing about it:
 * ask the customer to finish, or call Sales Operations. The server keeps the rule whatever
 * the panel renders; this flag only decides what is drawn.
 *
 * TWO HALVES. Every required detail belongs to the identity verification - the last one
 * that did not, Identity Proof, is derived from residency and reads with the rest - so
 * what is left above the rule is the booking context, and it holds every control on the
 * panel. The rule marks where reading begins.
 *
 * AN UNSAVED EDIT HOLDS THE SUBMIT. The submit re-runs its checks against the RECORD, not
 * against this panel, so submitting over a control the rep has typed into but not saved
 * would discard what they typed and send the customer without it. While anything is
 * pending, Save is the lit button and Submit is held, with the footer saying why.
 *
 * DOCUMENTS ARE A STATUS, NOT A FILE. Received or not received, and when. There is no
 * preview, no file name and no link, and the server sends no document reference for one
 * to be built from - a file the customer uploaded through identity verification cannot
 * reach the rep through this panel.
 *
 * Dumb by design: every value comes in through @api and every decision leaves as an
 * event. mscBookingPage owns the Apex, as it does for the rest of the journey.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/* x.y+1 - the one new sentence, kept here rather than in c/mscLabels: a tooltip only. */
const SHOW_MISSING = "Show what is missing";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** Field type from the server → the native input type that edits it. A date uses c/mscDatePicker. */
const INPUT_TYPE = {
  date: "date",
  email: "email",
  phone: "tel",
  number: "number"
};

/* x.y+2 - R2-08: MODON's Update KYC form calls Occupation__pc "Position" (AccountKycController), so the
   check uses the same word for the same field */
const LABEL_OF = {
  Occupation__pc: "Position",
  Occupation__c: "Position"
};

/* x.y+2 - UI-13: a date reads dd/mm/yyyy, as the console's date picker writes it */
function ddmmyyyy(raw) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(raw || ""));
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null;
}

export default class MscComplianceCheck extends LightningElement {
  labels = LABELS;

  @api open = false;
  /**
   * 1.11 - everybody this booking could send, buyer first, exactly as the Ownership
   * panel lists them. Raw PartyDTOs: the page holds them already and works nothing out.
   * Fewer than two and there is no strip at all - which is 88% of bookings.
   */
  @api parties;
  /** Whose checklist is showing. The server echoes it back on `state.partyAccountId`. */
  @api activeAccountId;
  /** SalesConsoleComplianceService.ChecklistDTO */
  @api loading = false;
  @api saving = false;
  @api submitting = false;
  /* Whatever the last save or submit came back with. It is printed here rather than by
     the page, whose banner would be drawn behind this panel. */
  @api errorMessage;

  /** api → what the rep typed, until the server answers with the saved truth. */
  _edits = {};
  /* A refresh rebuilds the panel from the server, which cannot re-make something a person
     typed - so the refresh is held while any of it is unsaved, rather than quietly
     throwing it away. */
  _typed = false;

  _state;

  @api
  get state() {
    return this._state;
  }
  set state(value) {
    const previous = this._state;
    this._state = value;
    /* x.y+2 - R2-07: a re-read of the same person that is not the answer to a save keeps what the
       rep typed; before, any new checklist wiped it without a word */
    const sameParty =
      !!previous && !!value && previous.partyAccountId === value.partyAccountId;
    if (sameParty && !this._awaitingSave && Object.keys(this._edits).length) {
      return;
    }
    this._awaitingSave = false;
    /* A new checklist IS the answer to the last save, so anything held here is
       either now on the record or was refused. Either way the server's copy wins. */
    /* Nothing is seeded. A suggestion held here was indistinguishable from a value the
       rep had typed, so clearing a booking-context field and saving looked as though the
       old value had come back - the save had worked, and this put the server's suggestion
       straight back into the control. The panel now shows the record and nothing else. */
    this._edits = {};
    this._typed = false;
  }

  /* x.y+2 - set by Save, spent by the checklist that answers it */
  _awaitingSave = false;

  get s() {
    return this._state || {};
  }

  /**
   * Focus moves into the panel once per opening, and back to whatever opened it on the
   * way out. Without it a keyboard user is left on the card behind a modal they cannot
   * reach, which is the one thing a dialog must never do.
   */
  _focusedOnOpen = false;
  _previousFocus = null;

  renderedCallback() {
    if (!this.open) {
      this._focusedOnOpen = false;
      return;
    }
    if (this._focusedOnOpen) {
      return;
    }
    const close = this.template.querySelector(".cc__x");
    if (close) {
      this._previousFocus = document.activeElement;
      close.focus();
      this._focusedOnOpen = true;
    }
  }

  restoreFocus() {
    const previous = this._previousFocus;
    this._previousFocus = null;
    if (previous && typeof previous.focus === "function") {
      previous.focus();
    }
  }

  disconnectedCallback() {
    this.restoreFocus();
  }

  // ── gates ───────────────────────────────────────────────────────────────

  get isBusy() {
    return this.loading === true || this.saving === true || this.submitting === true;
  }
  get showBody() {
    return this.s.available === true && this.loading !== true;
  }
  get showLoading() {
    return this.loading === true;
  }
  get showUnavailable() {
    return this.loading !== true && this.s.available !== true;
  }
  get unavailableReason() {
    return this.s.blockedReason || "This customer cannot be checked just now.";
  }

  // ── header ──────────────────────────────────────────────────────────────

  /**
   * 1.11 - the name that came back WITH this checklist, and never the last one.
   *
   * The panel switches from one person to another without closing, so a title held from
   * before the switch would be the previous person's for as long as the call took - and
   * a checklist under the wrong name is worse than no checklist.
   *
   * While the answer is still coming there is no checklist to be wrong about, and the
   * strip's own active tab is the honest stand-in: it is the person the rep just pressed,
   * described by the same server answer the Ownership panel above is rendering. Nothing
   * here is invented, and the header keeps its two lines instead of collapsing and
   * jumping back on every switch.
   */
  get activeTab() {
    return this.partyTabs.find((t) => t.accountId === this.activeAccountId);
  }
  get title() {
    if (this.s.partyName || this.s.customerName) {
      return this.s.partyName || this.s.customerName;
    }
    const tab = this.activeTab;
    return (tab && tab.name) || "Compliance check";
  }
  get subtitle() {
    const bits = [];
    /* The role only where there is somebody to be distinguished from. On a sole-buyer
       booking "Primary Owner" answers a question nobody asked. */
    if (this.hasStrip) {
      const tab = this.activeTab;
      const role = this.s.partyRole || (tab && tab.role);
      if (role) {
        bits.push(role);
      }
    }
    if (this.s.residency) {
      bits.push(this.s.residency);
    }
    if (this.s.kycCompletedDate) {
      bits.push("Identity verified " + this.fullDate(this.s.kycCompletedDate));
    }
    return bits.join(" · ");
  }

  // ── 1.11 · the party strip ──────────────────────────────────────────────

  get hasStrip() {
    return (this.parties || []).length > 1;
  }

  /**
   * One tab per person. EVERY TAB IS PRESSABLE, including the ones that cannot be
   * checked: pressing them is how the rep finds out why, and the server's own sentence
   * is already what this panel shows when a checklist is unavailable. A tab that did
   * nothing would leave that sentence with no way of being read.
   */
  get partyTabs() {
    if (!this.hasStrip) {
      return [];
    }
    const held = this.hasPendingEdits;
    return (this.parties || []).map((p) => {
      const active = p.accountId === this.activeAccountId;
      const state = this.tabState(p);
      return {
        key: p.accountId,
        accountId: p.accountId,
        name: p.name,
        role: p.isPrimary
          ? this.labels.JO_ROLE_PRIMARY
          : p.relationshipSubType || p.relationshipType || this.labels.JO_ROLE_JOINT,
        state,
        hasState: !!state,
        cls: active ? "cc__tab cc__tab--on" : "cc__tab",
        current: active ? "true" : "false",
        disabled: !active && (held || this.isBusy),
        title: !active && held ? this.labels.JO_C_SWITCH_HELD : null
      };
    });
  }

  /**
   * One word, and a deliberately shorter vocabulary than the Ownership row's chip.
   *
   * The row answers "where is this person"; a tab answers "is there anything to do
   * here". Passfort's own status belongs on the row, where there is width for it and
   * where the rep is reading about people - inside this panel it would compete with the
   * readiness count that is the whole point of the screen.
   */
  tabState(p) {
    if (p.complianceSubmitted === true) {
      return this.labels.JO_C_TAB_SENT;
    }
    if (p.canCheckCompliance === true) {
      return this.labels.JO_C_TAB_NOT_SENT;
    }
    /* No verification status at all means the server could not read that person's
       account - JointOwner__c is Private, and a booking that changed hands carries rows
       whose accounts the new owner cannot see. Silence, for the same reason the Ownership
       row shows no chip for them: every other answer here would be a claim about a record
       we were not able to open, and "Sales Operations" in particular would assert they
       are a company when we do not know that. Pressing the tab still reaches the server's
       own sentence. */
    if (!p.verificationStatus) {
      return null;
    }
    if (p.canEverVerify === false) {
      return this.labels.JO_C_TAB_LOCKED;
    }
    return this.labels.JO_C_TAB_NOT_READY;
  }

  handleSwitchParty(event) {
    const accountId = event.currentTarget.dataset.account;
    if (!accountId || accountId === this.activeAccountId) {
      return;
    }
    /* Re-checked here as well as on the tab's disabled flag: a disabled button is a
       hint, and this one is guarding something a person typed. */
    if (this.hasPendingEdits || this.isBusy) {
      return;
    }
    this.dispatchEvent(new CustomEvent("switchparty", { detail: { accountId } }));
  }
  get showSubtitle() {
    return !!this.subtitle;
  }

  // ── the rail ────────────────────────────────────────────────────────────

  /** Fields and documents together: the headline counts what the check covers. */
  get readyCount() {
    return (this.s.readyCount || 0) + (this.s.contextReady || 0) + (this.s.documentsReady || 0);
  }
  get totalCount() {
    return (this.s.totalCount || 0) + (this.s.contextTotal || 0) + (this.s.documentsTotal || 0);
  }
  get readyText() {
    return `${this.readyCount} / ${this.totalCount}`;
  }
  get meterStyle() {
    return `width:${this.pct(this.readyCount, this.totalCount)}%`;
  }
  get meterClass() {
    return this.readyCount >= this.totalCount && this.totalCount > 0
      ? "cc__meter-fill cc__meter-fill--ok"
      : "cc__meter-fill";
  }

  /** The rail reads in the order the form does, top to bottom. */
  get railRows() {
    const rows = [];
    if (this.s.contextTotal) {
      rows.push(
        this.railRow("context", this.labels.COMPLIANCE_CONTEXT, this.s.contextReady, this.s.contextTotal)
      );
    }
    (this.s.sections || []).forEach((sec) =>
      rows.push(this.railRow(sec.key, sec.label, sec.ready, sec.total))
    );
    if (this.s.documentsTotal) {
      rows.push(
        this.railRow("documents", this.labels.COMPLIANCE_DOCUMENTS, this.s.documentsReady, this.s.documentsTotal)
      );
    }
    return rows;
  }

  railRow(key, label, ready, total) {
    const r = ready || 0;
    const t = total || 0;
    const done = t > 0 && r >= t;
    return {
      key,
      label,
      count: `${r}/${t}`,
      cls: done ? "cc__rl cc__rl--ok" : "cc__rl",
      barStyle: `width:${this.pct(r, t)}%`
    };
  }

  pct(a, b) {
    if (!b) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round((a / b) * 100)));
  }

  /**
   * KYC_Completed_Date__c carries no time, so the minute comes from the verification
   * response when the org kept one. Date alone when it did not - never an invented time.
   */
  get kycDateText() {
    if (this.s.kycCompletedOn) {
      return `${this.fullDate(this.s.kycCompletedOn)}, ${this.clock(this.s.kycCompletedOn)}`;
    }
    return this.s.kycCompletedDate ? this.fullDate(this.s.kycCompletedDate) : "";
  }
  get showKycDate() {
    return !!(this.s.kycCompletedOn || this.s.kycCompletedDate);
  }

  // ── the fields: yours above the line, verified below it ─────────────────

  /** x.y+1 - each detail with the rail row it counts toward, so a cell knows its group. */
  get allEntries() {
    const out = [];
    (this.s.sections || []).forEach((sec) =>
      (sec.fields || []).forEach((f) => out.push({ f, sec: sec.key }))
    );
    return out;
  }
  get allFields() {
    return this.allEntries.map((e) => e.f);
  }

  /** The rep's own. Always controls - there is nothing to unlock. */
  get ownCells() {
    return this.allEntries
      .filter((e) => e.f.readOnly !== true)
      .map((e) => this.toCell(e.f, e.sec));
  }
  get hasOwnCells() {
    return this.allFields.some((f) => f.readOnly !== true);
  }

  /**
   * The verification's. One block, no sub-headings: subject told the rep nothing.
   *
   * A booking-context detail the rep cannot write belongs here too, whichever list the
   * server sent it in - the line on this screen is drawn on who owns a value, not on
   * which collection it arrived in.
   */
  get verifiedCells() {
    return this.allEntries
      .filter((e) => e.f.readOnly === true)
      .map((e) => this.toCell(e.f, e.sec))
      .concat(this.readOnlyContext.map((f) => this.toCell(f, "context")));
  }
  get hasVerifiedCells() {
    return this.allFields.some((f) => f.readOnly === true) || this.readOnlyContext.length > 0;
  }
  get readOnlyContext() {
    return (this.s.context || []).filter((f) => f.readOnly === true);
  }
  /** The rail row for the details lands here. */
  get detailsKey() {
    const first = (this.s.sections || [])[0];
    return first ? first.key : "identity";
  }

  /** Said once, under the details, and only while one is actually outstanding. */
  get showVerifiedNote() {
    return this.allFields.some((f) => f.readOnly === true && f.filled !== true);
  }

  /**
   * A field the verification owns prints; anything else takes a control. Nothing else
   * decides this - not a mode, not whether the value happens to be there already.
   */
  toCell(f, sec) {
    /* x.y+1 - required and still missing, on every cell. data-missing is what a jump
       looks for, so it is always "true" or "false", never left to an absent attribute. */
    const required = this.isRequired(f, sec);
    const missing = required && this.isMissing(f);
    const mark = {
      sec,
      required,
      ariaRequired: required ? "true" : "false",
      missing: missing ? "true" : "false",
      cellCls: missing ? "cc__cell cc__cell--missing" : "cc__cell"
    };
    if (f.readOnly === true) {
      const known = f.filled === true;
      return {
        ...mark,
        /* A fact takes focus only while it is the thing a jump can land on. */
        focusIndex: missing ? "-1" : undefined,
        key: f.api,
        label: this.labelFor(f),
        isFact: true,
        /* 1.29 - a detail the verification has not sent back prints NOTHING. The
           label alone says what is missing; repeating "Not received yet" under
           six of them in one block read as noise. The count on the rail and
           COMPLIANCE_VERIFIED_NOTE below still name the gap, so nothing is lost.
           Documents keep the wording - that column IS a status. */
        display: known ? this.displayOf(f) : "",
        valueCls: known ? "cc__fact-v" : "cc__fact-v cc__fact-v--none"
      };
    }
    const cell = this.toInput(f);
    cell.isFact = false;
    return Object.assign(cell, mark);
  }

  /** x.y+2 - R2-08: the word MODON's own KYC form uses, else the server's label. */
  labelFor(f) {
    return LABEL_OF[f.api] || f.label;
  }

  /** x.y+2 - UI-13: a date fact reads dd/mm/yyyy; everything else as the server printed it. */
  displayOf(f) {
    /* a date the server printed as yyyy-mm-dd; any other wording it chose is kept */
    if (f.type === "date") {
      return ddmmyyyy(f.display) || f.display;
    }
    return f.display;
  }

  /**
   * x.y+1 - the server's own flag. An older answer without it: every section detail is
   * counted, so it is required; a context field is not assumed to be.
   */
  isRequired(f, sec) {
    if (f.required === true || f.required === false) {
      return f.required;
    }
    return sec !== "context";
  }

  /**
   * x.y+1 - empty on the record, or emptied by the rep and not yet saved. A value typed
   * and not saved counts as there: the rep has dealt with it, and Save is the lit button.
   */
  isMissing(f) {
    const held = f.readOnly === true ? undefined : this._edits[f.api];
    if (held !== undefined) {
      return String(held).trim() === "";
    }
    return f.filled !== true;
  }

  count(ready, total) {
    return `${ready || 0}/${total || 0}`;
  }
  countClass(ready, total) {
    return (total || 0) > 0 && (ready || 0) >= total
      ? "cc__grp-count cc__grp-count--ok"
      : "cc__grp-count";
  }

  /**
   * One field, ready for the template. LWC cannot branch on a value, so the shape of
   * the control is decided here and the markup just reads the flags.
   */
  toInput(f) {
    const held = this._edits[f.api];
    const value = held === undefined ? f.value || "" : held;
    const isPicklist = f.type === "picklist";
    const isTextarea = f.type === "textarea";
    /* x.y+2 - UI-13: the console's date picker (dd/mm/yyyy), not the browser's regional one */
    const isDate = f.type === "date";
    return {
      key: f.api,
      api: f.api,
      label: this.labelFor(f),
      value,
      isPicklist,
      isTextarea,
      isDate,
      isPlain: !isPicklist && !isTextarea && !isDate,
      inputType: INPUT_TYPE[f.type] || "text",
      options: (f.options || []).map((o) => ({
        label: o.label,
        value: o.value,
        selected: o.value === value
      }))
    };
  }

  // ── documents ───────────────────────────────────────────────────────────

  get docRows() {
    return (this.s.documents || []).map((d) => ({
      key: d.name,
      name: d.name,
      /* x.y+1 - a document still to come is where the Documents row of the rail lands */
      missing: d.received === true ? "false" : "true",
      focusIndex: d.received === true ? undefined : "-1",
      cls: d.received === true ? "cc__doc cc__doc--ok" : "cc__doc cc__doc--missing",
      status:
        d.received === true
          ? "Received " + this.day(d.receivedOn)
          : this.labels.COMPLIANCE_NOT_RECEIVED
    }));
  }
  get hasDocs() {
    return (this.s.documents || []).length > 0;
  }
  get docsCountText() {
    return this.count(this.s.documentsReady, this.s.documentsTotal);
  }
  get docsCountClass() {
    return this.countClass(this.s.documentsReady, this.s.documentsTotal);
  }
  /** Named only while something is actually outstanding. */
  get showDocsNote() {
    return (this.s.documentsTotal || 0) > (this.s.documentsReady || 0);
  }

  // ── booking context ─────────────────────────────────────────────────────

  /**
   * Everything above the line, in one group: the two the submit waits on, then what the
   * rep declares about the customer. They are the same kind of thing to a rep - values
   * only they can give - and two headings over four fields said nothing the fields did
   * not already say.
   */
  get contextCells() {
    return this.editableContext
      .concat(this.s.declarations || [])
      .map((f) => this.toCell(f, "context"));
  }
  get hasContext() {
    return this.editableContext.length > 0 || (this.s.declarations || []).length > 0;
  }
  get editableContext() {
    return (this.s.context || []).filter((f) => f.readOnly !== true);
  }

  // ── footer ──────────────────────────────────────────────────────────────

  get hasError() {
    return !!this.errorMessage;
  }

  /** Only ever what is standing in the way. Nothing to say when nothing is. */
  get blockerText() {
    if (this.hasPendingEdits) {
      return this.labels.COMPLIANCE_UNSAVED;
    }
    return this.s.canSubmit === true ? "" : this.s.submitBlockedReason || "";
  }
  get blockerClass() {
    return this.s.canSubmit === true && !this.hasPendingEdits
      ? "cc__blocker cc__blocker--ok"
      : "cc__blocker";
  }
  get showBlocker() {
    return !this.hasError && !!this.blockerText;
  }

  /**
   * x.y+1 - the footer's sentence takes the rep to the first thing it counts. Only while
   * it is the server's "still needed" answer: an unsaved edit says Save, and there is
   * nowhere to go when nothing on the panel is missing.
   */
  get blockerJumps() {
    return !this.hasPendingEdits && this.s.canSubmit !== true && this.hasMissing;
  }
  get hasMissing() {
    return (
      this.allEntries.some((e) => this.isRequired(e.f, e.sec) && this.isMissing(e.f)) ||
      (this.s.context || []).some((f) => this.isRequired(f, "context") && this.isMissing(f)) ||
      (this.s.documents || []).some((d) => d.received !== true)
    );
  }
  get showMissingHint() {
    return SHOW_MISSING;
  }

  get submitDisabled() {
    return this.s.canSubmit !== true || this.isBusy || this.hasPendingEdits;
  }
  /**
   * Only ever one of the two is the next thing to press: the brand button is Save while
   * something is unsaved, and Submit once nothing is.
   */
  get saveClass() {
    return this.hasPendingEdits ? "btn btn-primary btn-sm" : "btn btn-ghost btn-sm";
  }
  get saveDisabled() {
    return this.isBusy || !this.hasPendingEdits;
  }
  get hasPendingEdits() {
    return Object.keys(this._edits).length > 0;
  }
  get submitLabel() {
    return this.submitting === true ? "Sending…" : "Submit to compliance";
  }
  get saveLabel() {
    return this.saving === true ? "Saving…" : "Save details";
  }
  /** Documents arrive from the customer while the rep is on this screen. */
  get refreshLabel() {
    return this.loading === true
      ? this.labels.COMPLIANCE_REFRESHING
      : this.labels.COMPLIANCE_REFRESH;
  }
  get refreshDisabled() {
    return this.isBusy || this._typed;
  }
  /**
   * Why a button is closed, on the button. A disabled control that gives no reason makes
   * the rep hunt the screen for one - and a browser will not show a title on a disabled
   * button, so the template hangs these on the wrapper instead.
   */
  get saveHint() {
    if (this.saving === true) {
      return this.labels.COMPLIANCE_SAVING_HINT;
    }
    if (this.isBusy) {
      return this.labels.COMPLIANCE_BUSY_HINT;
    }
    return this.hasPendingEdits
      ? this.labels.COMPLIANCE_SAVE_HINT
      : this.labels.COMPLIANCE_NOTHING_TO_SAVE;
  }
  get submitHint() {
    if (this.submitting === true) {
      return this.labels.COMPLIANCE_SENDING_HINT;
    }
    if (this.isBusy) {
      return this.labels.COMPLIANCE_BUSY_HINT;
    }
    if (this.hasPendingEdits) {
      return this.labels.COMPLIANCE_UNSAVED;
    }
    if (this.s.canSubmit === true) {
      return this.labels.COMPLIANCE_SUBMIT_HINT;
    }
    return this.s.submitBlockedReason || this.labels.COMPLIANCE_SUBMIT_HELD;
  }

  get showActions() {
    return this.s.available === true && this.s.alreadySubmitted !== true;
  }
  get showSubmittedNote() {
    return !this.hasError && this.s.alreadySubmitted === true;
  }
  get submittedNote() {
    return this.s.submittedOn
      ? `Sent for compliance ${this.day(this.s.submittedOn)}, ${this.clock(this.s.submittedOn)}`
      : "Already sent for compliance.";
  }

  // ── dates, in the console's own shape ───────────────────────────────────

  ms(v) {
    if (!v) {
      return 0;
    }
    const t = new Date(v).getTime();
    return isNaN(t) ? 0 : t;
  }
  /**
   * "18 Aug 2026". A date-only value arrives as yyyy-MM-dd, which new Date() reads as UTC
   * midnight - one timezone west of the org and it prints the day before. Read the parts.
   */
  fullDate(v) {
    if (!v) {
      return "";
    }
    const parts = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(v));
    const d = parts
      ? new Date(Number(parts[1]), Number(parts[2]) - 1, Number(parts[3]))
      : new Date(this.ms(v));
    if (isNaN(d.getTime())) {
      return "";
    }
    return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
  }
  /** "18 Aug" */
  day(v) {
    const t = this.ms(v);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }
  /** "14:20" */
  clock(v) {
    const t = this.ms(v);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  // ── events ──────────────────────────────────────────────────────────────

  handleEdit(event) {
    const api = event.currentTarget.dataset.api;
    if (!api) {
      return;
    }
    this._edits = Object.assign({}, this._edits, { [api]: event.currentTarget.value });
    this._typed = true;
  }

  /**
   * A rail row is the group's way in. x.y+1: pressing it goes to the first field of that
   * group still missing, and focuses it; with nothing missing it brings the heading into
   * view, as before.
   */
  handleJump(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) {
      return;
    }
    const missing = this.firstMissing(key);
    if (missing) {
      this.goTo(missing);
      return;
    }
    const target =
      this.template.querySelector(`[data-group="${key}"]`) ||
      this.template.querySelector(`[data-sec="${key}"]`);
    if (!target || typeof target.scrollIntoView !== "function") {
      return;
    }
    target.scrollIntoView({ block: "start", behavior: this.scrollBehaviour() });
  }

  /** x.y+1 - the footer's sentence: the first missing field anywhere, top to bottom. */
  handleShowMissing() {
    const missing = this.firstMissing();
    if (missing) {
      this.goTo(missing);
    }
  }

  /** x.y+1 - in the order the form reads, which is the order of the markup. */
  firstMissing(sec) {
    const selector = sec
      ? `[data-missing="true"][data-sec="${sec}"]`
      : `[data-missing="true"]`;
    return this.template.querySelector(selector);
  }

  /**
   * x.y+1 - into the middle of the view, then focus: the control itself where there is
   * one, else the cell or document row, which is focusable only while it is missing.
   */
  goTo(cell) {
    if (typeof cell.scrollIntoView === "function") {
      cell.scrollIntoView({ block: "center", behavior: this.scrollBehaviour() });
    }
    const target = cell.querySelector("select, input, textarea, c-msc-date-picker") || cell;
    if (typeof target.focus !== "function") {
      return;
    }
    try {
      target.focus({ preventScroll: true });
    } catch (e) {
      target.focus();
    }
  }

  scrollBehaviour() {
    const still =
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    return still ? "auto" : "smooth";
  }

  handleRefresh() {
    if (this.refreshDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("refreshcheck"));
  }

  handleSave() {
    /* x.y+2 - R2-07: what is in the controls right now is what gets saved, including a value
       still being typed that has not raised its change yet */
    this.commitControls();
    if (!this.hasPendingEdits) {
      return;
    }
    this._awaitingSave = true;
    this.dispatchEvent(
      new CustomEvent("savedetails", { detail: { fields: Object.assign({}, this._edits) } })
    );
  }

  /** x.y+2 - every enabled control whose value differs from the record joins the edits. */
  commitControls() {
    const record = {};
    this.allFields
      .concat(this.s.context || [])
      .forEach((f) => {
        if (f && f.api) {
          record[f.api] = f.value === null || f.value === undefined ? "" : String(f.value);
        }
      });
    const next = Object.assign({}, this._edits);
    let moved = false;
    this.template.querySelectorAll("[data-api]").forEach((el) => {
      const api = el.dataset.api;
      if (!api || el.disabled || !(api in record)) {
        return;
      }
      const v = el.value === null || el.value === undefined ? "" : String(el.value);
      if (v !== record[api] && next[api] !== v) {
        next[api] = v;
        moved = true;
      }
    });
    if (moved) {
      this._edits = next;
      this._typed = true;
    }
  }

  handleSubmit() {
    if (this.submitDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("submitcompliance"));
  }

  handleClose() {
    /* x.y+2 - closing leaves nothing typed behind for the next opening, as before */
    this._edits = {};
    this._typed = false;
    this._awaitingSave = false;
    /* While focus is still inside the panel, not on unmount: the opener is definitely
       still there now. Same reasoning as c/mscDrawer's own close. */
    this.restoreFocus();
    this.dispatchEvent(new CustomEvent("closecheck"));
  }

  /** The scrim closes; a click inside the panel must not. */
  handleScrim() {
    if (!this.isBusy) {
      this.handleClose();
    }
  }
  stop(event) {
    event.stopPropagation();
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.isBusy) {
      event.stopPropagation();
      this.handleClose();
    }
  }
}