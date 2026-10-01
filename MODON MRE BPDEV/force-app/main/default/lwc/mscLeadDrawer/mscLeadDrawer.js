/**
 * The lead work drawer: disposition the open call task, schedule, note, read the history.
 *
 * Version  Author      Date         Detail
 * 1.18     Aurelix Dev 30 Sep 2026  The follow-up date uses c/mscDatePicker (dd/mm/yyyy) like the console's other
 *                                   date fields (UI-13); blank selects read "Select…" and blanks show nothing (UI-21).
 * 1.17     Aurelix Dev 29 Sep 2026  Template only: the handover tooltip no longer uses an em dash. The
 *                                   dash-only blank option in the selects is unchanged.
 * 1.16     Aurelix Dev 21 Sep 2026  Native date input again (21 Sep). Withdrawn: the same day's
 *                                   c/mscDatePicker for the follow-up date, which avoided a grey
 *                                   calendar pop-up that only a Linux desktop shows (SCW-137).
 * 1.15     Aurelix Dev 03 Sep 2026  MSC-232 (W7). Retire: a fourth button in the action bar,
 *                                   after a hairline, opening the same composer with the org's
 *                                   own Lead.RetiredReason__c chips and an optional comment
 *                                   (required on Egypt leads). Shown only where the org would
 *                                   accept the status (qualify.canRetire) - no message, no
 *                                   disabled control, nothing to explain.
 * 1.14     Aurelix Dev 02 Sep 2026  MSC-212. "Book a unit" in the head: fires `startbooking`
 *                                   ({leadId, name}, composed) and the workspace opens the
 *                                   journey seeded with this lead. Hidden on Retired/Duplicate,
 *                                   the statuses the booking surfaces exclude.
 * 1.13     Aurelix Dev 02 Sep 2026  MSC-210. A qualified lead queued for round-robin handover
 *                                   carries a quiet 'handover' marker beside its status, read
 *                                   from QualifyStateDTO.pendingReassign. Marker only.
 * 1.12     Aurelix Dev 02 Sep 2026  MSC-209 fix. Hovering Log Call painted its inverse label
 *                                   over the ghost hover tint (.act:hover ties .act--key:hover
 *                                   on specificity and swapped the fill out from under the
 *                                   label). The filled hover re-asserts its background token.
 *                                   CSS only, both themes.
 * 1.11     Aurelix Dev 02 Sep 2026  MSC-208. Aligned with the org's SLA ladder: a 'Busy'
 *                                   response on Reached (the trigger continues the ladder on
 *                                   it exactly as on Not Reachable, and the result line says
 *                                   so); 'Call back' says the truth ("Call closed · book the
 *                                   callback next") and a successful save opens the Schedule
 *                                   composer, because the org opens nothing for a callback.
 * 1.10     Aurelix Dev 01 Sep 2026  MSC-195. 'Not interested' is selectable: choosing it asks for
 *                                   the retired reason the org makes mandatory (values from
 *                                   getQualifyOptions, never hardcoded). Still refused - as a
 *                                   disabled chip that says why - when the org offers no reasons.
 * 1.9      Aurelix Dev 31 Aug 2026  MSC-188. Task strip restyled to the approved artifact:
 *                                   two lines - subject in full, then "Due <date>" with a bold
 *                                   "Overdue" word when late. The relative countdown is gone
 *                                   (the date already says it); relative() helper removed.
 * 1.8      Aurelix Dev 31 Aug 2026  MSC-187 fix. A scheduled call's row says WHEN it is for
 *                                   ("for tomorrow 18:30") as the artifact showed; the bar adds
 *                                   the exact due beside the relative one.
 * 1.7      Aurelix Dev 31 Aug 2026  MSC-187. History redesigned to the approved artifact:
 *                                   recency bands (sticky in the drawer's own scroll),
 *                                   outcome-first rows on an icon rail, expand-in-place with
 *                                   one quiet meta line, consecutive system entries folded,
 *                                   'Show earlier' paging. Presentation only - same DTO plus
 *                                   isSystem/subtype.
 * 1.6      Aurelix Dev 31 Aug 2026  MSC-186 fix. Times render from epoch millis (dueAtMs/atMs),
 *                                   never from Datetime strings - parsing those is ambiguous
 *                                   about UTC and could show GMT on the rep's clock.
 * 1.5      Aurelix Dev 31 Aug 2026  MSC-186. Schedule takes an optional time of day
 *                                   (Task.ReminderDateTime; CurrentTaskSLA__c stays untouched).
 * 1.4      Aurelix Dev 31 Aug 2026  MSC-186 fix. Hover on a selected chip / the primary button
 *                                   painted text-on-text; filled hovers now dim instead of
 *                                   turning #fff (which erased labels in the light theme);
 *                                   skeleton shimmer tokenised. CSS only.
 * 1.3      Aurelix Dev 31 Aug 2026  MSC-186. Button relabelled 'Log Call' (business choice).
 * 1.2      Aurelix Dev 31 Aug 2026  MSC-186 fix. The action bar never wraps: the buttons hold one
 *                                   row, the task strip shrinks and ellipsises; on a phone the
 *                                   strip takes its own line. CSS only.
 * 1.1      Aurelix Dev 31 Aug 2026  MSC-186 fix. `open` and `lead` land in template-attribute
 *                                   order, so loading from the open setter could fetch the
 *                                   PREVIOUS lead's activity. Both setters now defer to one
 *                                   microtask sync keyed by lead id, with a stale-response guard.
 * 1.0      Aurelix Dev 31 Aug 2026  MSC-186. Initial.
 *
 * The org's model, not ours: LeadTriggerHelper opens `Call Task N` and the rep changes its
 * STATUS here; TaskTriggerHelper then moves the lead (qualify + reassign on Reached/Interested,
 * next call task on Not Reachable and on Reached/Busy). The drawer never creates a call task and never writes
 * Send_Customer_Notification__c - the org's before-save flow owns that field, and the customer
 * "we tried to reach you" email/SMS it can raise is the org's standard journey.
 *
 * Mounted by c/mscLeadList; position:fixed like the list's own slide-over, one z-index layer
 * above it. Emits `close`, and `changed` after any successful write.
 */

import { LightningElement, api, wire } from "lwc";
import getActivity from "@salesforce/apex/SalesConsoleActivityController.getActivity";
import getQualifyOptions from "@salesforce/apex/SalesConsoleActivityController.getQualifyOptions";
import recordOutcome from "@salesforce/apex/SalesConsoleActivityController.recordOutcome";
import scheduleFollowUp from "@salesforce/apex/SalesConsoleActivityController.scheduleFollowUp";
import addNote from "@salesforce/apex/SalesConsoleActivityController.addNote";
import retireLead from "@salesforce/apex/SalesConsoleActivityController.retireLead";
import { reduceError } from "c/modonSalesFormat";

const MIN_MS = 60 * 1000;
const HOUR_MS = 60 * MIN_MS;
const DAY_MS = 24 * HOUR_MS;
/* 1.18 - UI-21: a blank value shows as nothing, not a dash */
const DASH = "";
/** The one disposition the org guards with a mandatory retired reason. */
const STATUS_NOT_INTERESTED = "Customer Not Interested";
/** History rows shown before "Show earlier". */
const HISTORY_PAGE = 20;

/** The dispositions the console records; Task.Status values verbatim. */
const STATUSES = [
  { value: "Customer Reached", label: "Reached" },
  { value: "Customer Not Reachable", label: "No answer" },
  { value: "Mobile Switched Off", label: "Phone off" },
  { value: "Invalid Number", label: "Wrong number" },
  /* MSC-195: the org demands a retired reason with this one (Retired_Reason_Mandatory_Check);
     statusOptions disables it only when the org has no reasons to offer */
  { value: "Customer Not Interested", label: "Not interested" }
];

/** CustomerResponse__c values, paired the way the org pairs them (never crossed in real data). */
const RESPONSES = {
  "Customer Reached": [
    { value: "Customer Interested", label: "Interested" },
    { value: "Requested Callback", label: "Call back" },
    /* MSC-208: the org's ladder continues on Reached+Busy exactly as on Not Reachable */
    { value: "Busy", label: "Busy" },
    { value: "Interest Lost", label: "Lost interest" }
  ],
  "Customer Not Reachable": [
    { value: "No Answer", label: "No answer" },
    { value: "Switched off", label: "Phone off" }
  ]
};

export default class MscLeadDrawer extends LightningElement {
  /** {id, name, initials, statusText, mobileText, emailText, projectText, sourceText} */
  _lead;

  @api
  get lead() {
    return this._lead;
  }
  set lead(value) {
    this._lead = value;
    /* never load here: `open` may not have landed yet - sync() decides */
    this.scheduleSync();
  }

  activity = null;
  options = null;
  loading = false;
  busy = false;
  errorMsg = "";

  /* composer */
  mode = null; // null | 'call' | 'sched' | 'note'
  pickStatus = "";
  pickResponse = "";
  /* MSC-195: Task.RetiredReason__c, mandatory with 'Customer Not Interested' */
  pickReason = "";
  desc = "";
  schedKind = "Call";
  schedDate = "";
  schedTime = "";
  gate = { projectId: "", bedrooms: "", budget: "", finance: "", investment: "" };
  /** Lead.Status as the server last said it; fresher than the row the list passed in. */
  liveStatus = "";
  /* 1.7: history interactivity */
  openKeys = {};
  showAllHistory = false;

  _open = false;
  _keyHandler;
  /** The lead id the drawer last loaded; null forces the next sync to load. */
  _loadedFor = null;
  _syncPending = false;
  /** Monotonic request token: a slow response for a lead the rep left never lands. */
  _req = 0;

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
      /* reopening the same lead still refetches - the org may have moved it meanwhile */
      this._loadedFor = null;
      this.scheduleSync();
    }
  }

  /**
   * `open` and `lead` arrive in template-attribute order within one rehydration; neither setter
   * may act alone. One microtask later both have landed, and the load is keyed by lead id.
   */
  scheduleSync() {
    if (this._syncPending) {
      return;
    }
    this._syncPending = true;
    Promise.resolve().then(() => {
      this._syncPending = false;
      this.sync();
    });
  }
  sync() {
    if (!this._open) {
      return;
    }
    const id = this._lead && this._lead.id;
    if (!id || id === this._loadedFor) {
      return;
    }
    this._loadedFor = id;
    this.reset();
    this.load();
  }

  connectedCallback() {
    this._keyHandler = (e) => {
      if (e.key === "Escape" && this._open) {
        e.stopPropagation();
        this.requestClose();
      }
    };
    document.addEventListener("keydown", this._keyHandler);
  }
  disconnectedCallback() {
    document.removeEventListener("keydown", this._keyHandler);
  }

  @wire(getQualifyOptions)
  wiredOptions({ data }) {
    if (data) {
      this.options = data;
    }
  }

  reset() {
    this.activity = null;
    this.errorMsg = "";
    this.liveStatus = "";
    this.openKeys = {};
    this.showAllHistory = false;
    this.closeComposer();
  }

  async load() {
    if (!this.lead || !this.lead.id) {
      return;
    }
    const reqId = ++this._req;
    this.loading = true;
    try {
      const data = await getActivity({ leadId: this.lead.id });
      if (reqId !== this._req) {
        return; // the rep moved on; a newer load owns the drawer
      }
      this.applyActivity(data);
    } catch (e) {
      if (reqId === this._req) {
        this.errorMsg = reduceError(e);
      }
    }
    if (reqId === this._req) {
      this.loading = false;
    }
  }

  applyActivity(a) {
    this.activity = a;
    if (a && a.qualify) {
      this.liveStatus = a.qualify.leadStatus || "";
      /* the gate opens prefilled with what the lead already holds */
      this.gate = {
        projectId: a.qualify.projectId || "",
        bedrooms: a.qualify.bedrooms || "",
        budget: a.qualify.budget || "",
        finance: a.qualify.finance || "",
        investment: a.qualify.investment || ""
      };
    }
  }

  /* header */
  get name() {
    return this.lead ? this.lead.name : "";
  }
  get initials() {
    return this.lead ? this.lead.initials : "";
  }
  get statusText() {
    return this.liveStatus || (this.lead ? this.lead.statusText : "");
  }
  /** 1.13: qualified and queued for handover; the server's word, refreshed by every write. */
  get pendingReassign() {
    const q = this.activity && this.activity.qualify;
    return q ? q.pendingReassign === true : !!(this.lead && this.lead.pendingReassign);
  }
  get phoneText() {
    return this.lead ? this.lead.mobileText : DASH;
  }
  get emailText() {
    return this.lead ? this.lead.emailText : DASH;
  }
  get projectText() {
    return this.lead ? this.lead.projectText : DASH;
  }
  get sourceText() {
    return this.lead ? this.lead.sourceText : DASH;
  }

  /* the open call task strip */
  get openTask() {
    return this.activity ? this.activity.openTask : null;
  }
  get hasOpenTask() {
    return !!this.openTask;
  }
  get noOpenTask() {
    return !this.loading && this.activity && !this.openTask;
  }
  get taskSubject() {
    return this.openTask ? this.openTask.subject : "";
  }
  /** 1.9: one quiet sentence under the subject - the date alone, no countdown. */
  get taskDueLine() {
    return this.openTask
      ? "Due " + this.dueWord(this.openTask.dueAtMs, this.openTask.dueHasTime)
      : "";
  }
  get taskOverdue() {
    return !!(this.openTask && this.openTask.overdue);
  }
  /** Log Call exists only while there is a task to disposition. */
  get outcomeDisabled() {
    return !this.hasOpenTask || this.busy;
  }

  /* action bar */
  get callBtnClass() {
    return this.mode === "call" ? "act act--key act--on" : "act act--key";
  }
  get schedBtnClass() {
    return this.mode === "sched" ? "act act--on" : "act";
  }
  get noteBtnClass() {
    return this.mode === "note" ? "act act--on" : "act";
  }
  /* MSC-232 */
  get retireBtnClass() {
    return this.mode === "retire" ? "act act--on" : "act";
  }
  toggleCall() {
    this.toggleMode("call");
  }
  toggleSched() {
    this.toggleMode("sched");
  }
  toggleNote() {
    this.toggleMode("note");
  }
  toggleRetire() {
    this.toggleMode("retire");
  }
  toggleMode(kind) {
    if (kind === "call" && !this.hasOpenTask) {
      return;
    }
    if (this.mode === kind) {
      this.closeComposer();
    } else {
      this.closeComposer();
      this.mode = kind;
      if (kind === "sched" && !this.schedDate) {
        this.schedDate = this.todayIso(1);
      }
      /* the textarea node survives a mode switch; desc was just cleared, so mirror it */
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      Promise.resolve().then(() => {
        const ta = this.template.querySelector(".desc-input");
        if (ta) {
          ta.value = "";
        }
      });
    }
  }
  get showTopError() {
    return !!this.errorMsg && !this.showComposer;
  }
  closeComposer() {
    this.mode = null;
    this.pickStatus = "";
    this.pickResponse = "";
    this.pickReason = "";
    this.pickLeadReason = ""; // MSC-232
    this.desc = "";
    this.errorMsg = "";
  }
  todayIso(plusDays) {
    const d = new Date(Date.now() + (plusDays || 0) * DAY_MS);
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return d.getFullYear() + "-" + m + "-" + day;
  }
  get minDate() {
    return this.todayIso(0);
  }

  get showComposer() {
    return this.mode !== null;
  }
  get isCall() {
    return this.mode === "call";
  }
  get isSched() {
    return this.mode === "sched";
  }
  get isNote() {
    return this.mode === "note";
  }
  get notesLabel() {
    if (this.mode === "retire") {
      return "Comment"; // MSC-232
    }
    return this.mode === "note" ? "Note" : "Notes";
  }

  /* ── retire (MSC-232) ────────────────────────────────────────────────────
   * The org owns the rules: Lead.RetiredReason__c is mandatory (and a comment too on Egypt
   * leads), and an 800-Modon lead can never be retired. The server says which through
   * qualify.canRetire / retireNeedsComment; here that only decides what is offered. */
  pickLeadReason = "";
  get isRetire() {
    return this.mode === "retire";
  }
  /** Hidden wherever the org would refuse the status, or with no reasons to offer. */
  get canRetire() {
    const q = this.activity && this.activity.qualify;
    return !!q && q.canRetire === true && this.leadReasonValues.length > 0;
  }
  get leadReasonValues() {
    return (this.options && this.options.leadRetiredReasons) || [];
  }
  get leadReasonOptions() {
    return this.leadReasonValues.map((v) => ({
      value: v,
      label: v,
      pressed: v === this.pickLeadReason ? "true" : "false"
    }));
  }
  pickLeadReasonHandler(e) {
    this.pickLeadReason = e.currentTarget.dataset.value;
    this.errorMsg = "";
  }
  /** The org demands a comment as well on Modon - Egypt leads. */
  get retireNeedsComment() {
    const q = this.activity && this.activity.qualify;
    return !!q && q.retireNeedsComment === true;
  }

  /* outcome step */
  /** The org's own Task.RetiredReason__c values; empty until getQualifyOptions lands. */
  get reasonValues() {
    return (this.options && this.options.retiredReasons) || [];
  }
  get statusOptions() {
    /* MSC-195: never offer a save that must fail - without a reason list the org's rule
       refuses this status, so the chip stays disabled and says so. */
    const noReasons = this.reasonValues.length === 0;
    return STATUSES.map((s) => {
      const blocked = s.value === STATUS_NOT_INTERESTED && noReasons;
      return {
        ...s,
        disabled: blocked,
        title: blocked ? "A retired reason is required, and none is available" : undefined,
        pressed: s.value === this.pickStatus ? "true" : "false"
      };
    });
  }
  pickStatusHandler(e) {
    const v = e.currentTarget.dataset.value;
    if (this.pickStatus === v) {
      return;
    }
    this.pickStatus = v;
    this.pickResponse = "";
    this.pickReason = "";
    this.errorMsg = "";
  }
  get reasonOptions() {
    return this.reasonValues.map((v) => ({
      value: v,
      label: v,
      pressed: v === this.pickReason ? "true" : "false"
    }));
  }
  get showReasons() {
    return (
      this.isCall && this.pickStatus === STATUS_NOT_INTERESTED && this.reasonOptions.length > 0
    );
  }
  pickReasonHandler(e) {
    this.pickReason = e.currentTarget.dataset.value;
    this.errorMsg = "";
  }
  get responseOptions() {
    return (RESPONSES[this.pickStatus] || []).map((r) => ({
      ...r,
      pressed: r.value === this.pickResponse ? "true" : "false"
    }));
  }
  get showResponses() {
    return this.isCall && this.responseOptions.length > 0;
  }
  pickResponseHandler(e) {
    this.pickResponse = e.currentTarget.dataset.value;
    this.errorMsg = "";
  }

  /** One quiet line: what the org will do with this disposition. */
  get resultLine() {
    if (this.pickStatus === "Customer Reached" && this.pickResponse === "Customer Interested") {
      return "Lead Qualified · reassigned";
    }
    if (this.pickStatus === STATUS_NOT_INTERESTED && this.pickReason) {
      /* nothing in the org reads this status: no next task, and the lead is left as it is */
      return "Call closed · no further call is opened";
    }
    /* MSC-208: the org opens nothing for a callback - the rep books it (save() opens Schedule) */
    if (this.pickStatus === "Customer Reached" && this.pickResponse === "Requested Callback") {
      return "Call closed · book the callback next";
    }
    /* MSC-208: TaskTriggerHelper continues the ladder on Reached+Busy exactly as on Not Reachable */
    const ladder =
      (this.pickStatus === "Customer Not Reachable" && this.pickResponse) ||
      (this.pickStatus === "Customer Reached" && this.pickResponse === "Busy");
    if (ladder) {
      const t = this.openTask;
      /* NextTaskMilestone__c, never the subject; 0 or blank means the ladder ends here */
      const next = t && t.nextMilestone > 0 ? t.nextMilestone : null;
      return next ? "In Progress · Call Task " + next + " opens" : "No further call is opened";
    }
    return "";
  }
  get showResult() {
    return this.isCall && !!this.resultLine;
  }

  /* qualify gate */
  get showGate() {
    return (
      this.isCall &&
      this.pickStatus === "Customer Reached" &&
      this.pickResponse === "Customer Interested"
    );
  }
  get projectChoices() {
    const list = this.options ? this.options.projects : [];
    return list.map((p) => ({ ...p, selected: p.id === this.gate.projectId }));
  }
  get bedroomChoices() {
    return this.gateChoices("bedrooms");
  }
  get budgetChoices() {
    return this.gateChoices("budgets");
  }
  get financeChoices() {
    return this.gateChoices("finance");
  }
  get investmentChoices() {
    return this.gateChoices("investment");
  }
  gateChoices(key) {
    const gateKey = key === "budgets" ? "budget" : key;
    return ((this.options && this.options[key]) || []).map((v) => ({
      value: v,
      selected: v === this.gate[gateKey]
    }));
  }
  handleGate(e) {
    this.gate = { ...this.gate, [e.target.dataset.field]: e.target.value };
  }

  handleDesc(e) {
    this.desc = e.target.value;
  }
  handleSchedKind(e) {
    this.schedKind = e.target.value;
  }
  handleSchedDate(e) {
    this.schedDate = e.target.value;
  }
  handleSchedTime(e) {
    this.schedTime = e.target.value;
  }
  get schedKindChoices() {
    return ["Call", "Meeting"].map((v) => ({ value: v, selected: v === this.schedKind }));
  }

  /* save */
  get saveDisabled() {
    /* MSC-232: the org refuses Retired without a reason (and without a comment on Egypt
       leads), so the button carries the rule - it simply cannot be pressed until both hold. */
    if (this.mode === "retire") {
      return (
        this.busy ||
        !this.pickLeadReason ||
        (this.retireNeedsComment && !(this.desc || "").trim())
      );
    }
    return this.busy;
  }
  get saveLabel() {
    if (this.busy) {
      return "Saving…";
    }
    return this.mode === "retire" ? "Retire lead" : "Save";
  }

  async save() {
    if (this.busy) {
      return;
    }
    this.errorMsg = "";
    const note = (this.desc || "").trim();
    /* MSC-232: retiring takes an optional comment; every other composer requires its note */
    if (this.mode === "retire") {
      await this.saveRetire(note);
      return;
    }
    if (!note) {
      this.errorMsg = this.mode === "note" ? "Write the note first." : "Notes are required.";
      return;
    }
    let saved = "";
    /* MSC-208: read before the composer state is cleared - a promised callback is booked
       there and then, because the org opens no follow-up for it */
    const bookCallback =
      this.mode === "call" &&
      this.pickStatus === "Customer Reached" &&
      this.pickResponse === "Requested Callback";
    this.busy = true;
    try {
      if (this.mode === "call") {
        if (!this.pickStatus) {
          this.errorMsg = "Select an outcome.";
          this.busy = false;
          return;
        }
        if (this.showResponses && !this.pickResponse) {
          this.errorMsg = "Select a response.";
          this.busy = false;
          return;
        }
        if (this.pickStatus === STATUS_NOT_INTERESTED && !this.pickReason) {
          this.errorMsg = "Select a reason.";
          this.busy = false;
          return;
        }
        const qualifying = this.showGate;
        this.applyActivity(
          await recordOutcome({
            taskId: this.openTask.id,
            status: this.pickStatus,
            response: this.pickResponse || null,
            description: note,
            projectId: qualifying ? this.gate.projectId || null : null,
            bedrooms: qualifying ? this.gate.bedrooms || null : null,
            budget: qualifying ? this.gate.budget || null : null,
            finance: qualifying ? this.gate.finance || null : null,
            investment: qualifying ? this.gate.investment || null : null,
            retiredReason:
              this.pickStatus === STATUS_NOT_INTERESTED ? this.pickReason : null
          })
        );
        saved = qualifying ? "Qualified · reassigned" : "Recorded";
      } else if (this.mode === "sched") {
        if (!this.schedDate) {
          this.errorMsg = "Pick a date.";
          this.busy = false;
          return;
        }
        this.applyActivity(
          await scheduleFollowUp({
            leadId: this.lead.id,
            kind: this.schedKind,
            dueDate: this.schedDate,
            note,
            timeOfDay: this.schedTime || null
          })
        );
        saved = "Scheduled";
      } else {
        this.applyActivity(await addNote({ leadId: this.lead.id, body: note }));
        saved = "Saved";
      }
    } catch (e) {
      this.errorMsg = reduceError(e);
      this.busy = false;
      return;
    }
    this.busy = false;
    this.closeComposer();
    if (bookCallback) {
      /* the Schedule composer opens on fresh state; toggleMode seeds tomorrow's date */
      this.toggleMode("sched");
    }
    const toast = this.template.querySelector("c-msc-toast");
    if (toast) {
      toast.show(saved);
    }
    this.dispatchEvent(
      new CustomEvent("changed", { detail: { leadId: this.lead.id, leadStatus: this.liveStatus } })
    );
  }

  /**
   * MSC-232. Writes the org's status, reason and comment, and the server closes the lead's
   * open call task with it. The list and the workspace hear it through the same `changed`
   * event every other save fires, so the row's status follows without a reload.
   */
  async saveRetire(note) {
    if (!this.pickLeadReason) {
      this.errorMsg = "Select a reason.";
      return;
    }
    this.busy = true;
    try {
      this.applyActivity(
        await retireLead({
          leadId: this.lead.id,
          reason: this.pickLeadReason,
          comment: note || null
        })
      );
    } catch (e) {
      this.errorMsg = reduceError(e);
      this.busy = false;
      return;
    }
    this.busy = false;
    this.closeComposer();
    const toast = this.template.querySelector("c-msc-toast");
    if (toast) {
      toast.show("Retired");
    }
    this.dispatchEvent(
      new CustomEvent("changed", { detail: { leadId: this.lead.id, leadStatus: this.liveStatus } })
    );
  }

  cancel() {
    this.closeComposer();
  }

  /* timeline: recency bands, outcome-first rows, folded system runs (MSC-187) */

  /** Statuses that read as an outcome even without a CustomerResponse__c. */
  isOutcomeStatus(status) {
    return (
      !!status && status !== "Open" && status !== "Not Started" && status !== "Completed"
    );
  }

  decorate(t) {
    const ms = Number(t.atMs) || 0;
    const title = t.title || "";
    const kind =
      t.kind === "note"
        ? "note"
        : t.subtype === "Email" || title.indexOf("Email:") === 0
          ? "email"
          : "task";
    const outcome =
      kind === "task" ? t.response || (this.isOutcomeStatus(t.status) ? t.status : "") : "";
    let head;
    if (kind === "note") {
      head = "Note";
    } else if (kind === "email") {
      head = "Email";
    } else if (outcome) {
      head = title.indexOf("Call Task") === 0 ? "Call" : title;
    } else if (t.open) {
      head = title === "Call" || title === "Meeting" ? title + " scheduled" : title;
    } else {
      head = title;
    }
    const emailSubject = kind === "email" ? title.replace(/^Email:\s*/, "") : "";
    const note = t.description || "";
    const scheduled = kind === "task" && t.open && !outcome;
    /* the appointment, not the booking moment */
    const dueWord = scheduled ? this.dueWord(t.dueAtMs, t.dueHasTime) : "";
    let tone = "";
    if (outcome === "Customer Interested") {
      tone = "g";
    } else if (
      outcome === "Interest Lost" ||
      outcome === "No Answer" ||
      outcome === "Switched off" ||
      outcome === "Invalid Number" ||
      outcome === "Customer Not Reachable" ||
      outcome === "Mobile Switched Off"
    ) {
      tone = "r";
    } else if (scheduled) {
      tone = "a";
    }
    const meta = [t.byName, this.stamp(ms)];
    if (title && title !== head) {
      meta.push(title);
    }
    return {
      key: t.id,
      ms,
      bandLabel: this.bandOf(ms),
      when: this.whenOf(ms),
      kind,
      head,
      outcome: kind === "email" ? emailSubject : scheduled && dueWord ? "for " + dueWord : outcome,
      preview: (note.split("\n")[0] || "").trim() || (kind === "email" ? emailSubject : ""),
      note,
      metaline: meta.filter(Boolean).join(" \u00b7 "),
      scheduled,
      tone,
      /* an auto entry nobody has acted on yet: folds into the quiet cluster line */
      sys: t.isSystem === true && kind === "task" && !outcome
    };
  }

  /** "today 18:30" / "tomorrow 18:30" / "2 Sep, 18:30" / "2 Sep" (no clock on date-only). */
  dueWord(ms, hasTime) {
    const t = Number(ms);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    const now = new Date();
    const day = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
    const diff = Math.round((day(d) - day(now)) / DAY_MS);
    const hm = hasTime
      ? d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })
      : "";
    if (diff === 0) {
      return ("today " + hm).trim();
    }
    if (diff === 1) {
      return ("tomorrow " + hm).trim();
    }
    const dd = d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
    return hm ? dd + ", " + hm : dd;
  }

  bandOf(ms) {
    if (!ms) {
      return "Earlier";
    }
    const now = new Date();
    const d = new Date(ms);
    const day = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
    const diff = Math.round((day(now) - day(d)) / DAY_MS);
    if (diff <= 0) {
      return "Today";
    }
    if (diff === 1) {
      return "Yesterday";
    }
    if (diff < 7) {
      return "This week";
    }
    return "Earlier";
  }
  whenOf(ms) {
    if (!ms) {
      return "";
    }
    const d = new Date(ms);
    const band = this.bandOf(ms);
    const hm = d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
    if (band === "Today" || band === "Yesterday") {
      return hm;
    }
    if (band === "This week") {
      return d.toLocaleDateString("en-GB", { weekday: "short" }) + " " + hm;
    }
    return d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
  }
  stamp(ms) {
    const t = Number(ms);
    if (!t) {
      return "";
    }
    const d = new Date(t);
    return (
      d.toLocaleDateString("en-GB", { day: "numeric", month: "short" }) +
      ", " +
      d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })
    );
  }

  /** Consecutive un-actioned system entries fold into one quiet line per band. */
  get historyRows() {
    const items = ((this.activity && this.activity.timeline) || []).map((t) =>
      this.decorate(t)
    );
    const out = [];
    let run = null;
    items.forEach((r) => {
      if (r.sys) {
        /* the artifact's sub-line: name plus its due ("… · for today 09:15") */
        const subText = r.outcome ? r.head + " \u00b7 " + r.outcome : r.head;
        if (run && run.bandLabel === r.bandLabel) {
          run.subs.push({ key: r.key, text: subText, when: r.when });
        } else {
          run = {
            isCluster: true,
            key: "c-" + r.key,
            bandLabel: r.bandLabel,
            when: r.when,
            subs: [{ key: r.key, text: subText, when: r.when }]
          };
          out.push(run);
        }
      } else {
        run = null;
        out.push(r);
      }
    });
    out.forEach((r) => {
      if (r.isCluster) {
        r.head = r.subs.length === 1 ? "1 system update" : r.subs.length + " system updates";
      }
    });
    return out;
  }

  get bands() {
    const all = this.historyRows;
    const rows = this.showAllHistory ? all : all.slice(0, HISTORY_PAGE);
    const bands = [];
    let cur = null;
    rows.forEach((r) => {
      if (!cur || cur.label !== r.bandLabel) {
        cur = { key: "b-" + r.bandLabel, railKey: "r-" + r.bandLabel, label: r.bandLabel, items: [] };
        bands.push(cur);
      }
      const open = !!this.openKeys[r.key];
      cur.items.push({
        ...r,
        openState: open,
        expandedAttr: open ? "true" : "false",
        showDetail: open && !r.isCluster,
        showSubs: open && !!r.isCluster,
        evClass:
          "ev" +
          (r.tone ? " ev--" + r.tone : "") +
          (r.isCluster ? " cluster" : "") +
          (open ? " ev--openrow" : ""),
        iconCall: !r.isCluster && r.kind === "task" && !r.scheduled,
        iconSched: !r.isCluster && r.kind === "task" && r.scheduled,
        iconNote: !r.isCluster && r.kind === "note",
        iconEmail: !r.isCluster && r.kind === "email",
        iconSys: !!r.isCluster
      });
    });
    return bands;
  }
  get hasMoreHistory() {
    return !this.showAllHistory && this.historyRows.length > HISTORY_PAGE;
  }
  get moreHistoryLabel() {
    return "Show earlier \u00b7 " + (this.historyRows.length - HISTORY_PAGE) + " more";
  }
  showEarlier() {
    this.showAllHistory = true;
  }
  toggleItem(e) {
    const key = e.currentTarget.dataset.key;
    this.openKeys = { ...this.openKeys, [key]: !this.openKeys[key] };
  }

  get emptyTimeline() {
    return (
      !this.loading &&
      this.activity &&
      ((this.activity && this.activity.timeline) || []).length === 0
    );
  }

  /* 1.14 (MSC-212): the from-lead booking entry */

  /** Hidden only where the booking surfaces exclude the lead (leadRowById refuses the same). */
  get canBook() {
    const s = (
      this.liveStatus ||
      (this._lead && this._lead.statusText) ||
      ""
    ).toLowerCase();
    return !!this._lead && s !== "retired" && s !== "duplicate";
  }

  /** The workspace listens on the list; composed, so it crosses both shadow roots. */
  startBooking() {
    if (!this._lead) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("startbooking", {
        detail: { leadId: this._lead.id, name: this._lead.name },
        bubbles: true,
        composed: true
      })
    );
  }

  /* chrome */
  get layerClass() {
    return this._open ? "layer layer--open" : "layer";
  }
  get hiddenAttr() {
    return this._open ? "false" : "true";
  }
  requestClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
  stop(e) {
    e.stopPropagation();
  }
}