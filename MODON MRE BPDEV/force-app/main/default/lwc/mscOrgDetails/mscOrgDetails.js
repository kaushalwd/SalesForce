/**
 * The company's verification details, on a surface of its own.
 *
 * Version  Author      Date         Detail
 * 2.3      Aurelix Dev 30 Sep 2026  Company dates use c/mscDatePicker and read dd/mm/yyyy (UI-13); an empty value reads
 *                                   "Not provided", not a dash (UI-21); the New Contact line has no dash.
 * 2.2      Aurelix Dev 29 Sep 2026  A value the server offers for an empty field (e.g. "What the company does", read
 *                                   from the trade licence) now counts as a pending edit, so Save details records it.
 * 2.1      Aurelix Dev 29 Sep 2026  A primary contact whose KYC is Active or manually approved needs no link, so the
 *                                   card shows them verified instead of "Not assigned as the Power of Attorney."
 *                                   Flags: signatory.poaRowNeeded, manuallyApproved (SalesConsoleOrgController 2.x+1).
 * 2.0      Aurelix Dev 30 Aug 2026  MSC-181. The Power of Attorney pane, rebuilt to the
 *                                   approved prototype: a Salesforce-standard lookup
 *                                   over the company's contacts (one field, a floating
 *                                   result panel, the violet contact tile, New Contact
 *                                   at the foot, keyboard nav) and ONE card for the
 *                                   chosen person - header, one status line with the
 *                                   one action, a details zone whose gaps say "Not
 *                                   provided", and the fill form inside the same card.
 *                                   No fact is stated twice. "Authorized signatory" is
 *                                   now "Power of Attorney" everywhere, and nothing is
 *                                   "recorded" - a Power of Attorney is ASSIGNED.
 *                                   Events out: assignsignatory {contactId} and
 *                                   createsignatory {name, nationality, residency,
 *                                   email, mobile} replace recordsignatory; every value
 *                                   and refusal on the pane stays the server's.
 * 1.0      Aurelix Dev 23 Aug 2026  MSC-146. The shell.
 * 1.4      Aurelix Dev 23 Aug 2026  MSC-155. The pane stops moving under the rep, and
 *                                   the next action moves into the footer, where every
 *                                   pane can see it.
 * 1.3      Aurelix Dev 23 Aug 2026  MSC-154. Names the record a filed signatory sits on,
 *                                   so the screen and Power_of_Attorney__c agree.
 * 1.2      Aurelix Dev 23 Aug 2026  MSC-149. The verification link is sent from the
 *                                   Signatory pane, so the rep opens this once and works
 *                                   top to bottom rather than closing it to press the
 *                                   card's button and reopening it.
 * 1.1      Aurelix Dev 23 Aug 2026  MSC-148. The workspace itself: a rail that SWITCHES
 *                                   panes rather than scrolling to them, so nothing in
 *                                   here scrolls in the ordinary case and one group is
 *                                   read at a time.
 *
 * WHY A SURFACE AND NOT A CARD. The Verification step is a list of subjects and their
 * tracks; the details behind one of those subjects are a dozen controls and a file
 * upload. Inline they would push the tracks off the screen and grow the step every time
 * it was opened. The page behind this never moves.
 *
 * THE CONTRACT (host-agnostic: mount at PAGE level, never inside a card. Every card runs
 * backdrop-filter, which makes it the containing block for position:fixed.)
 *
 *   in    open · companyName · bookingRef · details · loading · saving · submitting ·
 *         uploading · errorMessage
 *   out   close · savedetails · uploadlicence · uploadfailed · assignsignatory ·
 *         createsignatory · sendverification · submitcompliance · checksignatory
 *
 * IT DECIDES NOTHING. Every value, every count and every refusal is the server's,
 * exactly as c/mscComplianceCheck's are. The only thing this file works out on its own
 * is which pane to open on, and that is read from the server's counts too.
 */
import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/* Must match the exit duration in the CSS (.layer--closing). */
const EXIT_MS = 200;

/* 2.3 - UI-13: a date fact reads dd/mm/yyyy, as c/mscDatePicker writes it */
function ddmmyyyy(raw) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(raw || ""));
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null;
}
const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

const INPUT_TYPE = {
  date: "date",
  email: "email",
  phone: "tel",
  text: "text"
};

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

export default class MscOrgDetails extends LightningElement {
  /** The company this is about. Drawn under the title. */
  @api companyName;
  /** The Sales Order this booking is filed against, where the host has one. */
  @api bookingRef;

  @api loading = false;
  @api saving = false;
  @api submitting = false;
  @api uploading = false;
  @api sendingLink = false;
  /* MSC-155 - the server's own next step, the same answer c/mscVerifyNext reads on
     the card. The workspace does not work it out a second time; it renders it in the
     one place that is visible from every pane. */
  @api nextStep;
  /* Printed here rather than by the page, whose banner would sit behind this scrim. */
  @api errorMessage;

  labels = LABELS;

  /** key -> what the rep typed, until the server answers with the saved truth. */
  _edits = {};
  /** Which pane the rep chose. Undefined means "wherever the counts point". */
  _pane;

  _details;

  @api
  get details() {
    return this._details;
  }
  set details(value) {
    this._details = value;
    /* A new answer IS the reply to the last save, so anything held here is either on
       the record now or was refused. The server's copy wins either way. */
    /* 2.2 - a value offered for an empty field is a pending edit, so Save records it */
    const offered = {};
    ((value && value.groups) || []).forEach((g) => {
      ((g && g.fields) || []).forEach((f) => {
        if (
          f &&
          f.key &&
          f.readOnly !== true &&
          f.filled !== true &&
          f.value != null &&
          String(f.value).trim() !== ""
        ) {
          offered[f.key] = f.value;
        }
      });
    });
    this._edits = offered;
    /* MSC-181 - and the same answer reconciles the Power of Attorney pane. Once the
       server names a person, the client-side pick and the New Contact form have been
       answered; the fill form closes on every reply because the facts now speak. */
    const sigNew = value && value.signatory;
    if (sigNew && sigNew.contactId) {
      this.pickedContactId = null;
      this.sigChanging = false;
      this.sigAdding = false;
      this.newDraft = {};
    }
    this.sigFilling = false;
    /* MSC-155 - AND THE PANE IS PINNED BY THE FIRST ANSWER.
       paneKey resolves to the first group with something outstanding, which is right
       on the way in and wrong on the way back: recording the signatory completes that
       group, so the rep who had just pressed Record was moved to Company - and the
       Send verification link button that had appeared in the same instant was on the
       pane they had been moved off. They had to close the workspace to find it.

       Resolved through paneKey rather than re-derived here, so there is still one
       expression that decides which pane opens; this only stops it deciding twice.
       The open accessor clears _pane on every opening, so each opening still lands
       where that opening's counts point. */
    if (!this._pane) {
      this._pane = this.paneKey;
    }
  }

  get s() {
    return this._details || {};
  }

  /**
   * Open lags closed by EXIT_MS so the exit can animate - c/mscPaymentModal's accessor,
   * for the same reason: `open` alone unmounts the markup on the frame it goes false.
   */
  _open = false;
  mounted = false;
  closing = false;
  _exitTimer = null;

  @api
  get open() {
    return this._open;
  }
  set open(value) {
    const next = !!value;
    if (next === this._open) {
      return;
    }
    this._open = next;
    if (next) {
      this.clearExit();
      this.closing = false;
      this._focusedOnOpen = false;
      /* Every opening starts where the counts point, not where the last one ended. */
      this._pane = undefined;
      this.pickedFileName = undefined;
      this.resetSignatoryState();
      this.mounted = true;
      return;
    }
    if (!this.mounted) {
      return;
    }
    this.closing = true;
    this.restoreFocus();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._exitTimer = setTimeout(() => {
      this._exitTimer = null;
      this.closing = false;
      this.mounted = false;
    }, EXIT_MS);
  }

  _focusedOnOpen = false;
  _previousFocus = null;
  pickedFileName;

  /* -- the head ---------------------------------------------------------- */

  get subline() {
    return [this.companyName, this.bookingRef].filter(Boolean).join(" · ");
  }
  get hasSubline() {
    return !!this.subline;
  }

  /* -- which of the three states the body is in --------------------------- */

  get isBusy() {
    return (
      this.loading === true ||
      this.saving === true ||
      this.submitting === true ||
      this.uploading === true ||
      this.sendingLink === true
    );
  }
  get showLoading() {
    return this.loading === true && this.s.available !== true;
  }
  get showBlocked() {
    return this.loading !== true && this.s.available !== true;
  }
  get blockedReason() {
    return this.s.blockedReason || this.errorMessage || LABELS.ORGD_LOADING;
  }
  /* -- the rail: the count, and the way to each group --------------------- */

  get groups() {
    return this.s.groups || [];
  }

  /**
   * The pane the rep is on. Opens on the first group with something outstanding -
   * which is the whole reason they pressed the button - and stays wherever they move
   * to for as long as the panel is open.
   */
  get paneKey() {
    const groups = this.groups;
    if (!groups.length) {
      return null;
    }
    if (this._pane && groups.some((g) => g.key === this._pane)) {
      return this._pane;
    }
    const open = groups.find(
      (g) => g.counted !== false && (g.ready || 0) < (g.total || 0)
    );
    return (open || groups[0]).key;
  }

  get railRows() {
    const on = this.paneKey;
    return this.groups.map((g) => {
      const counted = g.counted !== false;
      const done = counted && (g.total || 0) > 0 && (g.ready || 0) >= g.total;
      let cls = "od__rl";
      if (g.key === on) {
        cls += " od__rl--on";
      }
      if (done) {
        cls += " od__rl--ok";
      }
      return {
        key: g.key,
        label: g.label,
        counted,
        count: `${g.ready || 0}/${g.total || 0}`,
        barStyle: `width:${this.pct(g.ready, g.total)}%`,
        cls,
        current: g.key === on ? "true" : "false"
      };
    });
  }

  get readyText() {
    return `${this.s.readyCount || 0} / ${this.s.totalCount || 0}`;
  }
  get meterStyle() {
    return `width:${this.pct(this.s.readyCount, this.s.totalCount)}%`;
  }
  get meterClass() {
    const r = this.s.readyCount || 0;
    const t = this.s.totalCount || 0;
    return t > 0 && r >= t ? "od__meter-fill od__meter-fill--ok" : "od__meter-fill";
  }

  pct(a, b) {
    if (!b) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round(((a || 0) / b) * 100)));
  }

  /* -- the pane ----------------------------------------------------------- */

  get group() {
    const key = this.paneKey;
    return this.groups.find((g) => g.key === key) || {};
  }
  get paneTitle() {
    return this.group.label || "";
  }
  get paneCount() {
    return `${this.group.ready || 0}/${this.group.total || 0}`;
  }
  get showPaneCount() {
    return this.group.counted !== false;
  }
  get paneCountClass() {
    const g = this.group;
    return (g.total || 0) > 0 && (g.ready || 0) >= g.total
      ? "od__pane-n od__pane-n--ok"
      : "od__pane-n";
  }

  get onSignatory() {
    return this.paneKey === "signatory";
  }
  get onCompany() {
    return this.paneKey === "company";
  }
  get onDocuments() {
    return this.paneKey === "documents";
  }

  get cells() {
    return (this.group.fields || []).map((f) => this.toCell(f));
  }
  get hasCells() {
    return (this.group.fields || []).length > 0;
  }
  /* MSC-181 - the Power of Attorney pane draws its fields on the card; the raw
     cell grid would say everything a second time. */
  get showCells() {
    return this.hasCells && !this.onSignatory;
  }

  /**
   * One field, ready for the template. LWC cannot branch on a value, so the shape of
   * the control is decided here and the markup only reads the flags.
   *
   * A value the server owns prints; anything else takes a control. Nothing else decides
   * this - not a mode, not whether the value happens to be there already.
   */
  toCell(f) {
    const wide = f.type === "textarea";
    const base = {
      key: f.key,
      label: f.label,
      note: f.note,
      hasNote: !!f.note,
      optional: f.optional === true,
      cellCls: wide ? "od__cell od__cell--wide" : "od__cell"
    };
    if (f.readOnly === true) {
      /* a date the server printed as yyyy-mm-dd; any other wording it chose is kept */
      const date = f.type === "date" ? ddmmyyyy(f.display) : null;
      return Object.assign(base, {
        isFact: true,
        /* 2.3 - UI-21: the card's own "Not provided", never a dash */
        display: date || f.display || LABELS.ORGD_POA_NOT_PROVIDED,
        valueCls: f.filled === true ? "od__fv" : "od__fv od__fv--none"
      });
    }
    const held = this._edits[f.key];
    const value = held === undefined ? f.value || "" : held;
    const isPicklist = f.type === "picklist";
    /* 2.3 - UI-13: a date is edited in c/mscDatePicker (dd/mm/yyyy) */
    const isDate = f.type === "date";
    return Object.assign(base, {
      isFact: false,
      value,
      isPicklist,
      isTextarea: wide,
      isDate,
      isPlain: !isPicklist && !wide && !isDate,
      inputType: INPUT_TYPE[f.type] || "text",
      options: (f.options || []).map((o) => ({
        label: o.label,
        value: o.value,
        selected: o.value === value
      }))
    });
  }

  /* ── MSC-181 · the Power of Attorney: a lookup, then one card ─────────────
     The pane's own client state is TRANSIENT - a pick, a query, an open panel -
     and every server reply reconciles it. Everything printed is the server's. */

  sigQuery = "";
  sigOpen = false;
  sigActive = 0;
  sigAdding = false;
  sigFilling = false;
  sigChanging = false;
  pickedContactId = null;
  newDraft = {};
  _focusSearch = false;
  _scrollActive = false;

  resetSignatoryState() {
    this.sigQuery = "";
    this.sigOpen = false;
    this.sigActive = 0;
    this.sigAdding = false;
    this.sigFilling = false;
    this.sigChanging = false;
    this.pickedContactId = null;
    this.newDraft = {};
  }

  get sig() {
    return this.s.signatory || {};
  }
  get people() {
    return this.s.people || [];
  }

  get showSigAdd() {
    return this.sigAdding;
  }
  get showSigCard() {
    return !this.sigAdding && !!this.cardPerson;
  }
  get showSigLookup() {
    return !this.sigAdding && !this.cardPerson;
  }

  /**
   * The person the card is about: the server's assigned signatory, unless the rep
   * pressed ✕ to change them (sigChanging) or nobody is named yet - then the rep's
   * own pick from the lookup, which stays client-side until Assign writes it.
   */
  get cardPerson() {
    const sig = this.sig;
    if (sig.contactId && this.sigChanging !== true) {
      return {
        contactId: sig.contactId,
        name: sig.name,
        title: sig.title || LABELS.ORGD_POA_ROLE_FALLBACK,
        isServer: true
      };
    }
    const picked = this.people.find((p) => p.contactId === this.pickedContactId);
    if (picked) {
      return {
        contactId: picked.contactId,
        name: picked.name,
        title: picked.title || LABELS.ORGD_POA_ROLE_FALLBACK,
        isServer: false,
        person: picked
      };
    }
    return null;
  }

  /**
   * ONE sentence, ONE action, decided once. Everything else on the card is a
   * labelled fact - nothing below restates what this line already said.
   */
  get cardState() {
    const cp = this.cardPerson;
    if (!cp) {
      return {};
    }
    const sig = this.sig;
    const warn = "sg__status sg__status--warn";
    const ok = "sg__status sg__status--ok";
    /* 2.1 - the row is asked for only while a link may have to be sent */
    const rowAsked = sig.poaRowNeeded !== false;
    if (!(cp.isServer && (sig.recorded === true || !rowAsked))) {
      return {
        cls: warn,
        dot: "od__mark",
        text: LABELS.ORGD_POA_NOT_ASSIGNED,
        showAssign: true
      };
    }
    if (sig.verified === true) {
      /* 2.1 - a manual approval has no completion date to quote */
      const byHand = sig.manuallyApproved === true && !sig.kycCompletedOn;
      return {
        cls: ok,
        dot: "od__mark od__mark--ok",
        text: byHand ? LABELS.KYCG_B_VERIFIED_MANUAL : LABELS.ORGD_POA_VERIFIED,
        when: byHand ? "" : this.day(sig.kycCompletedOn)
      };
    }
    if (sig.missing) {
      if (this.sigFilling) {
        return { cls: warn, dot: "od__mark", text: LABELS.ORGD_POA_FILLING };
      }
      return {
        cls: warn,
        dot: "od__mark",
        text: fill(LABELS.ORGD_POA_NEED, sig.missing),
        showFill: true
      };
    }
    if (sig.linkSentAt) {
      return {
        cls: ok,
        dot: "od__mark od__mark--ok od__mark--live",
        text: LABELS.ORGD_POA_SENT,
        when: this.dayTime(sig.linkSentAt),
        showResend: sig.canSendLink === true
      };
    }
    /* MSC-155 - the first send appears exactly once: the footer wins while the
       server's next step is offering the same act, because it is visible from
       every pane. A resend is never the next step, so it stays on the card. */
    return {
      cls: ok,
      dot: "od__mark od__mark--ok",
      text: LABELS.ORGD_POA_READY,
      showSend:
        sig.canSendLink === true &&
        !(this.footAction && this.footAction.action === "sendlink")
    };
  }

  get cardName() {
    const cp = this.cardPerson;
    return cp ? cp.name : "";
  }
  get cardRole() {
    const cp = this.cardPerson;
    return cp ? cp.title : "";
  }
  get changeDisabled() {
    if (this.isBusy) {
      return true;
    }
    const cp = this.cardPerson;
    if (cp && cp.isServer) {
      /* The link is addressed to this person; once it is out - and certainly once
         they have verified - the card no longer offers to swap them. The server
         refuses it anyway; this only stops the pane offering a dead end. */
      return !!this.sig.linkSentAt || this.sig.verified === true;
    }
    return false;
  }
  get assignLabel() {
    return this.saving === true ? LABELS.ORGD_POA_ASSIGNING : LABELS.ORGD_POA_ASSIGN;
  }
  get cardSendLabel() {
    return this.sendingLink === true ? LABELS.ORGD_SENDING : LABELS.ORGD_SEND_LINK;
  }
  get cardResendLabel() {
    return this.sendingLink === true ? LABELS.ORGD_SENDING : LABELS.ORGD_POA_RESEND;
  }

  /** The four facts, or "Not provided" in amber - never a second warning line. */
  get cardFacts() {
    const cp = this.cardPerson;
    if (!cp) {
      return [];
    }
    const asFact = (key, label, value, filled) => ({
      key,
      label,
      display: filled ? value : LABELS.ORGD_POA_NOT_PROVIDED,
      cls: filled ? "sg__fv" : "sg__fv sg__fv--gap"
    });
    if (cp.isServer) {
      return (this.group.fields || []).map((f) =>
        asFact(f.key, f.label, f.display, f.filled === true)
      );
    }
    const p = cp.person;
    const npf = this.s.newPersonFields || [];
    const labelOf = (api, fallback) => {
      const f = npf.find((x) => x.api === api);
      return (f && f.label) || fallback;
    };
    return [
      asFact("nat", labelOf("Nationality__c", "Nationality"), p.nationality, !!p.nationality),
      asFact("res", labelOf("UAE_Resident_Status__c", "Residency"), p.residency, !!p.residency),
      asFact("em", labelOf("Email", "Email address"), p.email, !!p.email),
      asFact("mo", labelOf("MobilePhone", "Mobile number"), p.mobile, !!p.mobile)
    ];
  }

  /* -- the fill form: only the gaps, inside the same card ------------------ */

  get showCardForm() {
    return this.sigFilling === true;
  }
  get cardFormCells() {
    return (this.group.fields || [])
      .filter((f) => f.filled !== true)
      .map((f) => this.toCell(f));
  }
  get cardFormReady() {
    const cells = this.cardFormCells;
    if (!cells.length) {
      return false;
    }
    return cells.every((c) => {
      const v = this._edits[c.key];
      return v !== undefined && String(v).trim() !== "";
    });
  }
  get cardSaveDisabled() {
    return this.isBusy || !this.cardFormReady;
  }
  get cardSaveLabel() {
    return this.saving === true ? LABELS.ORGD_SAVING : LABELS.ORGD_SAVE;
  }

  /* -- the lookup ---------------------------------------------------------- */

  get filteredPeople() {
    const q = (this.sigQuery || "").trim().toLowerCase();
    const all = this.people;
    if (!q) {
      return all;
    }
    return all.filter((p) =>
      [p.name, p.title, p.email, p.phone]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().indexOf(q) >= 0)
    );
  }

  /** {pre, hit, post, has} - the match, marked where it sits. */
  markOf(text, q) {
    const t = String(text || "");
    if (!q) {
      return { pre: t, hit: "", post: "", has: false };
    }
    const i = t.toLowerCase().indexOf(q);
    if (i < 0) {
      return { pre: t, hit: "", post: "", has: false };
    }
    return {
      pre: t.slice(0, i),
      hit: t.slice(i, i + q.length),
      post: t.slice(i + q.length),
      has: true
    };
  }

  get lookupRows() {
    const q = (this.sigQuery || "").trim().toLowerCase();
    const active = this.sigActive;
    return this.filteredPeople.map((p, i) => {
      const reach = [p.email, p.phone].filter(Boolean).join(" · ");
      return {
        contactId: p.contactId,
        index: String(i),
        cls: i === active ? "pr pr--active" : "pr",
        selected: i === active ? "true" : "false",
        name: this.markOf(p.name, q),
        role: this.markOf(p.title || LABELS.ORGD_POA_ROLE_FALLBACK, q),
        reach: this.markOf(reach, q),
        hasReach: !!reach,
        missing: p.missing ? fill(LABELS.ORGD_POA_MISSING, p.missing) : null,
        hasMissing: !!p.missing
      };
    });
  }
  get hasLookupRows() {
    return this.filteredPeople.length > 0;
  }
  get sigOpenAria() {
    return this.sigOpen ? "true" : "false";
  }
  get meterLine() {
    const total = this.people.length;
    const q = (this.sigQuery || "").trim();
    if (q) {
      return fill(
        LABELS.ORGD_POA_COUNT_MATCH,
        this.filteredPeople.length,
        total,
        q
      );
    }
    return total === 1
      ? LABELS.ORGD_POA_COUNT_ONE
      : fill(LABELS.ORGD_POA_COUNT_ALL, total);
  }
  get emptyLine() {
    return fill(LABELS.ORGD_POA_EMPTY, (this.sigQuery || "").trim());
  }
  get newContactLabel() {
    const q = (this.sigQuery || "").trim();
    return q ? fill(LABELS.ORGD_POA_NEW_Q, q) : LABELS.ORGD_POA_NEW;
  }

  /* -- the New Contact form: exactly sendKYCForm's required set ------------ */

  get draftName() {
    return this.newDraft.name || "";
  }
  get addFields() {
    const d = this.newDraft || {};
    const npf = this.s.newPersonFields || [];
    const byApi = {};
    npf.forEach((f) => {
      byApi[f.api] = f;
    });
    const mk = (api, key, fallbackLabel, fallbackType) => {
      const f = byApi[api] || {};
      const value = d[key] || "";
      const type = f.type || fallbackType;
      return {
        key,
        label: f.label || fallbackLabel,
        value,
        isPicklist: type === "picklist",
        inputType: INPUT_TYPE[type] || "text",
        options: (f.options || []).map((o) => ({
          label: o.label,
          value: o.value,
          selected: o.value === value
        }))
      };
    };
    return [
      mk("Nationality__c", "nationality", "Nationality", "text"),
      mk("UAE_Resident_Status__c", "residency", "Residency", "picklist"),
      mk("Email", "email", "Email address", "email"),
      mk("MobilePhone", "mobile", "Mobile number", "phone")
    ];
  }
  get addReady() {
    const d = this.newDraft || {};
    return ["name", "nationality", "residency", "email", "mobile"].every(
      (k) => d[k] && String(d[k]).trim() !== ""
    );
  }
  get createDisabled() {
    return this.isBusy || !this.addReady;
  }
  get createLabel() {
    return this.saving === true ? LABELS.ORGD_POA_CREATING : LABELS.ORGD_POA_CREATE;
  }

  /* Said under the pane and nowhere else: the LINK's own refusal, and only when
     the card is not already naming the same gaps - no fact is stated twice. */
  get showLinkNote() {
    if (!this.s.linkBlockedReason) {
      return false;
    }
    const sig = this.sig;
    if (!sig.contactId || sig.recorded !== true) {
      return false;
    }
    return !sig.missing;
  }
  get linkNote() {
    return this.s.linkBlockedReason;
  }

  /* -- the licence: one upload, six fields -------------------------------- */

  get licenceStatus() {
    if (this.uploading === true) {
      return LABELS.ORG_LICENCE_UPLOADING;
    }
    if (this.s.licenceRead === true) {
      return LABELS.ORG_LICENCE_VERIFIED;
    }
    if (this.s.licencePresent === true) {
      return LABELS.ORG_LICENCE_READING;
    }
    return LABELS.ORG_LICENCE_NONE;
  }
  get licenceChipClass() {
    if (this.s.licenceRead === true) {
      return "chip chip--paid";
    }
    if (this.s.licencePresent === true) {
      return "chip chip--partial";
    }
    return "chip chip--pending";
  }
  get licenceMarkClass() {
    return this.s.licencePresent === true ? "od__mark od__mark--ok" : "od__mark";
  }
  get licenceName() {
    return this.s.licenceDocName || LABELS.ORGD_LIC_HEAD;
  }
  get licenceCta() {
    return this.s.licencePresent === true
      ? LABELS.ORGD_LIC_REPLACE
      : LABELS.ORG_LICENCE_CHOOSE;
  }

  /* -- documents: status and date, never the file ------------------------- */

  get docRows() {
    return (this.s.documents || []).map((d) => ({
      key: d.name,
      name: d.name,
      cls: d.received === true ? "od__doc od__doc--ok" : "od__doc",
      status:
        d.received === true
          ? `Received ${this.day(d.receivedOn)}`
          : LABELS.COMPLIANCE_NOT_RECEIVED
    }));
  }

  /* -- the footer --------------------------------------------------------- */

  get hasPendingEdits() {
    return Object.keys(this._edits).length > 0;
  }
  get hasError() {
    return !!this.errorMessage;
  }
  get footClass() {
    if (this.hasError) {
      return "od__note od__note--bad";
    }
    return this.s.canSubmit === true && !this.hasPendingEdits
      ? "od__note od__note--ok"
      : "od__note";
  }
  get footText() {
    if (this.hasError) {
      return this.errorMessage;
    }
    if (this.hasPendingEdits) {
      return LABELS.COMPLIANCE_UNSAVED;
    }
    if (this.s.submitBlockedReason) {
      return this.s.submitBlockedReason;
    }
    return this.s.canSubmit === true ? LABELS.ORGD_ALL_DONE : "";
  }
  get showFootText() {
    return !!this.footText;
  }

  get saveLabel() {
    return this.saving === true ? LABELS.ORGD_SAVING : LABELS.ORGD_SAVE;
  }
  get saveDisabled() {
    return this.isBusy || !this.hasPendingEdits;
  }
  get saveHint() {
    if (this.saving === true) {
      return LABELS.COMPLIANCE_SAVING_HINT;
    }
    if (this.isBusy) {
      return LABELS.COMPLIANCE_BUSY_HINT;
    }
    return this.hasPendingEdits
      ? LABELS.COMPLIANCE_SAVE_HINT
      : LABELS.COMPLIANCE_NOTHING_TO_SAVE;
  }

  get submitLabel() {
    return this.submitting === true ? LABELS.ORGD_SUBMITTING : LABELS.ORGD_SUBMIT;
  }
  get submitDisabled() {
    return this.isBusy || this.hasPendingEdits || this.s.canSubmit !== true;
  }
  get submitHint() {
    if (this.submitting === true) {
      return LABELS.COMPLIANCE_SENDING_HINT;
    }
    if (this.isBusy) {
      return LABELS.COMPLIANCE_BUSY_HINT;
    }
    if (this.hasPendingEdits) {
      return LABELS.COMPLIANCE_UNSAVED;
    }
    if (this.s.canSubmit === true) {
      return LABELS.COMPLIANCE_SUBMIT_HINT;
    }
    return this.s.submitBlockedReason || LABELS.COMPLIANCE_SUBMIT_HELD;
  }
  /** Nothing to press once the company is with compliance. */
  get showActions() {
    return this.s.available === true && this.s.alreadySubmitted !== true;
  }

  /* ── MSC-155 · the next action, where every pane can see it ────────────────
     The footer carries the server's next step. Three of the eight states are
     actionable from in here; the rest are the panes' own work (a signatory to file,
     details to type) or a wait, and for those the footer offers nothing rather than
     inventing something.

     opendetails is deliberately not one of them: this IS that screen. */

  get footAction() {
    const step = this.nextStep || {};
    if (!step.buttonLabel) {
      return null;
    }
    if (step.action !== "sendlink" && step.action !== "submit" && step.action !== "check") {
      return null;
    }
    return { action: step.action, label: step.buttonLabel };
  }

  get showFootAction() {
    return !!this.footAction && this.showActions;
  }

  get footActionLabel() {
    const a = this.footAction;
    if (!a) {
      return "";
    }
    /* The two that already had a label of their own keep it while in flight. */
    if (a.action === "submit" && this.submitting === true) {
      return LABELS.ORGD_SUBMITTING;
    }
    if (a.action === "sendlink" && this.sendingLink === true) {
      return LABELS.ORGD_SENDING;
    }
    return a.label;
  }

  /**
   * The submit branch keeps EXACTLY the gate it had before this ticket - it is a
   * working path and nothing about it changes. The other two are new surface, and
   * they refuse for the one reason that applies to any write from here: unsaved work.
   */
  get footActionDisabled() {
    const a = this.footAction;
    if (!a) {
      return true;
    }
    if (a.action === "submit") {
      return this.submitDisabled;
    }
    return this.isBusy || this.hasPendingEdits;
  }

  get footActionHint() {
    const a = this.footAction;
    if (!a) {
      return null;
    }
    if (a.action === "submit") {
      return this.submitHint;
    }
    if (this.isBusy) {
      return LABELS.COMPLIANCE_BUSY_HINT;
    }
    return this.hasPendingEdits ? LABELS.COMPLIANCE_UNSAVED : a.label;
  }

  /**
   * Each action reports where its message belongs, so they keep their own events
   * rather than routing through the card's bar - a refusal from in here must land on
   * this panel and not on the page banner behind its scrim.
   */
  handleFootAction() {
    const a = this.footAction;
    if (!a || this.footActionDisabled) {
      return;
    }
    if (a.action === "sendlink") {
      this.dispatchEvent(new CustomEvent("sendverification"));
      return;
    }
    if (a.action === "submit") {
      this.dispatchEvent(new CustomEvent("submitcompliance"));
      return;
    }
    this.dispatchEvent(new CustomEvent("checksignatory"));
  }

  /* -- dates, in the console's own shape ---------------------------------- */

  day(v) {
    if (!v) {
      return "";
    }
    const t = new Date(v).getTime();
    if (isNaN(t)) {
      return "";
    }
    const d = new Date(t);
    return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }

  /** "23 Aug at 10:57" - the same shape the verification list prints. */
  dayTime(v) {
    const t = v ? new Date(v).getTime() : 0;
    if (!t || isNaN(t)) {
      return "";
    }
    const d = new Date(t);
    const hh = String(d.getHours()).padStart(2, "0");
    const mm = String(d.getMinutes()).padStart(2, "0");
    return `${this.day(v)} at ${hh}:${mm}`;
  }

  /* -- events ------------------------------------------------------------- */

  handleJump(event) {
    const key = event.currentTarget.dataset.key;
    if (key) {
      this._pane = key;
    }
  }

  handleEdit(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) {
      return;
    }
    this._edits = Object.assign({}, this._edits, {
      [key]: event.currentTarget.value
    });
  }

  handleSave() {
    if (this.saveDisabled) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("savedetails", {
        detail: { fields: Object.assign({}, this._edits) }
      })
    );
  }

  handleSubmit() {
    if (this.submitDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("submitcompliance"));
  }

  /* ── MSC-181 · the lookup's manners ─────────────────────────────────────── */

  handleSigFocus() {
    this.sigOpen = true;
  }

  handleSigInput(event) {
    this.sigQuery = event.target.value;
    this.sigActive = 0;
    this.sigOpen = true;
  }

  /**
   * The standard lookup's keys. Escape closes the panel, then clears the query -
   * and only an Escape with neither left reaches the workspace's own close.
   */
  handleSigKeydown(event) {
    const rows = this.filteredPeople;
    if (event.key === "ArrowDown") {
      event.preventDefault();
      event.stopPropagation();
      if (!this.sigOpen) {
        this.sigOpen = true;
        return;
      }
      this.sigActive = Math.min(this.sigActive + 1, rows.length - 1);
      this._scrollActive = true;
      return;
    }
    if (event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();
      this.sigActive = Math.max(this.sigActive - 1, 0);
      this._scrollActive = true;
      return;
    }
    if (event.key === "Enter") {
      if (this.sigOpen && rows[this.sigActive]) {
        event.preventDefault();
        event.stopPropagation();
        this.pickPerson(rows[this.sigActive].contactId);
      }
      return;
    }
    if (event.key === "Escape") {
      if (this.sigOpen || this.sigQuery) {
        event.preventDefault();
        event.stopPropagation();
        if (this.sigOpen) {
          this.sigOpen = false;
        } else {
          this.sigQuery = "";
        }
      }
    }
  }

  handleRowHover(event) {
    const i = Number(event.currentTarget.dataset.row);
    if (!isNaN(i)) {
      this.sigActive = i;
    }
  }

  handleRowPick(event) {
    this.pickPerson(event.currentTarget.dataset.contact);
  }

  pickPerson(contactId) {
    if (!contactId) {
      return;
    }
    this.pickedContactId = contactId;
    this.sigOpen = false;
    this.sigQuery = "";
    this.sigActive = 0;
  }

  /** ✕ on the card: back to the search. Nothing is written until Assign is. */
  handleChange() {
    if (this.changeDisabled) {
      return;
    }
    const cp = this.cardPerson;
    if (cp && cp.isServer) {
      this.sigChanging = true;
    }
    this.pickedContactId = null;
    this.sigQuery = "";
    this.sigOpen = true;
    this._focusSearch = true;
  }

  handleAssign() {
    if (this.isBusy) {
      return;
    }
    const cp = this.cardPerson;
    if (!cp) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("assignsignatory", { detail: { contactId: cp.contactId } })
    );
  }

  handleOpenFill() {
    if (this.isBusy) {
      return;
    }
    this.sigFilling = true;
  }

  handleCancelFill() {
    const next = Object.assign({}, this._edits);
    this.cardFormCells.forEach((c) => {
      delete next[c.key];
    });
    this._edits = next;
    this.sigFilling = false;
  }

  handleCardSend() {
    if (this.isBusy) {
      return;
    }
    this.dispatchEvent(new CustomEvent("sendverification"));
  }

  handleOpenAdd() {
    if (this.isBusy) {
      return;
    }
    this.sigAdding = true;
    this.sigOpen = false;
    this.newDraft = { name: (this.sigQuery || "").trim() };
  }

  handleCancelAdd() {
    this.sigAdding = false;
    this.newDraft = {};
  }

  handleDraft(event) {
    const key = event.currentTarget.dataset.d;
    if (!key) {
      return;
    }
    this.newDraft = Object.assign({}, this.newDraft, {
      [key]: event.currentTarget.value
    });
  }

  handleCreate() {
    if (this.createDisabled) {
      return;
    }
    const d = this.newDraft;
    this.dispatchEvent(
      new CustomEvent("createsignatory", {
        detail: {
          name: d.name.trim(),
          nationality: d.nationality,
          residency: d.residency,
          email: d.email,
          mobile: d.mobile
        }
      })
    );
  }

  /** A click anywhere on the panel outside the combo closes the result panel. */
  handlePanelClick(event) {
    event.stopPropagation();
    if (!this.sigOpen) {
      return;
    }
    const el = event.target;
    if (el && typeof el.closest === "function" && el.closest(".lk__combo")) {
      return;
    }
    this.sigOpen = false;
  }

  handleFile(event) {
    const input = event.target;
    const file = input.files && input.files[0];
    if (!file) {
      return;
    }
    this.pickedFileName = file.name;
    const reader = new FileReader();
    reader.onload = () => {
      this.dispatchEvent(
        new CustomEvent("uploadlicence", {
          detail: {
            fileName: file.name,
            base64: String(reader.result).split(",")[1]
          }
        })
      );
    };
    reader.onerror = () => {
      this.dispatchEvent(
        new CustomEvent("uploadfailed", {
          detail: { message: LABELS.ORG_LICENCE_UNREADABLE }
        })
      );
    };
    reader.readAsDataURL(file);
    /* So the same file can be chosen again after a failure. */
    input.value = null;
  }

  /* -- focus, escape, exit - c/mscPaymentModal's pattern ------------------- */

  renderedCallback() {
    if (!this.mounted || this.closing) {
      return;
    }
    if (!this._focusedOnOpen) {
      const close = this.template.querySelector(".od__x");
      if (close) {
        this._previousFocus = document.activeElement;
        close.focus({ preventScroll: true });
        this._focusedOnOpen = true;
      }
    }
    /* MSC-181 - ✕ hands the rep straight back to the search field. */
    if (this._focusSearch) {
      this._focusSearch = false;
      const box = this.template.querySelector(".lk__input");
      if (box) {
        box.focus({ preventScroll: true });
      }
    }
    if (this._scrollActive) {
      this._scrollActive = false;
      const row = this.template.querySelector(".pr--active");
      if (row && typeof row.scrollIntoView === "function") {
        row.scrollIntoView({ block: "nearest" });
      }
    }
  }

  disconnectedCallback() {
    this.clearExit();
    this.restoreFocus();
  }

  clearExit() {
    if (this._exitTimer) {
      clearTimeout(this._exitTimer);
      this._exitTimer = null;
    }
  }

  restoreFocus() {
    const prev = this._previousFocus;
    this._previousFocus = null;
    if (!prev || typeof prev.focus !== "function") {
      return;
    }
    try {
      prev.focus({ preventScroll: true });
    } catch (e) {
      /* The opener can be gone - losing focus to the body is correct then. */
    }
  }

  get layerClass() {
    return this.closing ? "layer layer--closing" : "layer";
  }

  handleClose() {
    if (this.closing) {
      return;
    }
    /* Mid-write the answer is still coming; closing now would lose it. */
    if (
      this.saving === true ||
      this.submitting === true ||
      this.uploading === true ||
      this.sendingLink === true
    ) {
      return;
    }
    this.dispatchEvent(new CustomEvent("close"));
  }

  stop(event) {
    event.stopPropagation();
  }

  /**
   * Escape closes. stopPropagation because modonSheet listens on the window, and one
   * keypress must not close the whole booking journey too.
   */
  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.handleClose();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const focusable = this.focusable();
    if (focusable.length < 2) {
      return;
    }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = this.template.activeElement;
    if (event.shiftKey && active === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  }

  focusable() {
    const root = this.template.querySelector(".od");
    if (!root) {
      return [];
    }
    const sel =
      'button, [href], input, select, textarea, iframe, [tabindex]:not([tabindex="-1"])';
    return Array.from(root.querySelectorAll(sel)).filter(
      (el) => !el.disabled && el.getAttribute("aria-hidden") !== "true"
    );
  }
}