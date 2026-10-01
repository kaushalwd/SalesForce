/**
 * Alerts panel: pending approvals and lead calls, triaged.
 *
 * Version  Author      Date         Detail
 * 2.4      Aurelix Dev 31 Aug 2026  MSC-189 fix. A booking task's destination is resolved
 *                                   imperatively on click (bookingFor) - the wired feed is
 *                                   cacheable and can be stale, which silently sent clicks to
 *                                   the record fallback. An Opportunity target is recognised
 *                                   by its id prefix, so even a stale feed routes correctly.
 * 2.4      Aurelix Dev 02 Sep 2026  MSC-207. The feed loads imperatively on every open of the
 *                                   drawer instead of through the cacheable wire, which served
 *                                   one session-old answer forever.
 * 2.3      Aurelix Dev 31 Aug 2026  MSC-189. Opportunity tasks open the console's own booking
 *                                   journey (`openbooking`, the Resume handoff) instead of the
 *                                   Salesforce record - the identity-verification section lives
 *                                   there. Tasks the console cannot host keep the record link.
 * 2.2      Aurelix Dev 31 Aug 2026  MSC-189 fix. Record rows (approvals, other tasks) open the
 *                                   record in the Salesforce app via the feed's lightningHost -
 *                                   NavigationMixin built dead site-relative URLs on LWR. The
 *                                   footer hint line is removed (business ask).
 * 2.1      Aurelix Dev 31 Aug 2026  MSC-189 fix. The "N pending" header line goes - the badge
 *                                   already carries the count (business ask).
 * 2.0      Aurelix Dev 31 Aug 2026  MSC-189. The 50-row dump becomes triage cards per the
 *                                   approved artifact "Alerts Triage": Action required
 *                                   (approvals, always individual; overdue calls - a digest
 *                                   at 4+, named leads at <=3), Due today, one quiet line for
 *                                   calls scheduled ahead. Lead cards raise `openleads`
 *                                   (filter or leadId) so the workspace lands the rep on the
 *                                   console's own list or drawer; approvals and non-lead
 *                                   tasks keep the record page.
 * 1.0      Aurelix IT  09 Aug 2026  Ports modonNotifications; reads the standard records the bell is raised about.
 */

import { LightningElement } from "lwc";
import getMyAlerts from "@salesforce/apex/SalesConsoleNotificationController.getMyAlerts";
import bookingFor from "@salesforce/apex/SalesConsoleNotificationController.bookingFor";
import { reduceError } from "c/modonSalesFormat";

const DAY_MS = 24 * 3600 * 1000;
/* 4+ identical facts fold into one digest card; 3 or fewer stay named leads */
const DIGEST_AT = 4;

export default class MscNotifications extends LightningElement {
  feed;
  loading = true;
  errorMsg = "";

  /* MSC-207: fetched fresh on every mount - the drawer is recreated on each open, so each
     open re-reads the server. The old cacheable wire replayed one stale answer all session. */
  connectedCallback() {
    this.load();
  }

  async load() {
    try {
      this.feed = await getMyAlerts();
    } catch (e) {
      this.errorMsg = reduceError(e);
    }
    this.loading = false;
  }

  get ready() {
    return !this.loading && !!this.feed;
  }

  /* ── action required ── */

  get approvals() {
    const f = this.feed;
    return ((f && f.alerts) || [])
      .filter((a) => a.kind === "approval")
      .map((a) => ({
        key: a.id,
        targetId: a.targetId,
        sub: a.detail + this.sinceSuffix(a.occurredAtMs)
      }));
  }

  get overdueAsDigest() {
    const f = this.feed;
    return !!f && (f.overdueCalls || []).length >= DIGEST_AT;
  }
  get overdueDigest() {
    const calls = (this.feed && this.feed.overdueCalls) || [];
    if (!calls.length) {
      return null;
    }
    return {
      title: calls.length + " overdue calls",
      sub: this.digestSub(calls, "oldest due ")
    };
  }
  get overdueRows() {
    if (this.overdueAsDigest) {
      return [];
    }
    return (((this.feed && this.feed.overdueCalls) || [])).map((c) => ({
      key: c.taskId,
      leadId: c.leadId,
      name: c.leadName || "Lead",
      sub: "Call overdue · due " + this.dueWord(c.dueAtMs, c.dueHasTime)
    }));
  }
  get hasAction() {
    return this.approvals.length > 0 || this.hasOverdue;
  }
  get hasOverdue() {
    return !!this.feed && (this.feed.overdueCalls || []).length > 0;
  }

  /* ── due today ── */

  get todayAsDigest() {
    const f = this.feed;
    return !!f && (f.todayCalls || []).length >= DIGEST_AT;
  }
  get todayDigest() {
    const calls = (this.feed && this.feed.todayCalls) || [];
    if (!calls.length) {
      return null;
    }
    return {
      title: calls.length + " calls due today",
      sub: this.digestSub(calls, "first at ")
    };
  }
  get todayRows() {
    if (this.todayAsDigest) {
      return [];
    }
    return (((this.feed && this.feed.todayCalls) || [])).map((c) => ({
      key: c.taskId,
      leadId: c.leadId,
      name: c.leadName || "Lead",
      sub: "Call due " + this.dueWord(c.dueAtMs, c.dueHasTime)
    }));
  }
  get hasToday() {
    return !!this.feed && (this.feed.todayCalls || []).length > 0;
  }

  /* ── the rest ── */

  get otherTasks() {
    const f = this.feed;
    return ((f && f.alerts) || [])
      .filter((a) => a.kind === "task")
      .map((a) => ({
        key: a.id,
        targetId: a.targetId,
        title: a.title,
        sub: a.overdue ? "Overdue · " + (a.detail || "") : a.detail || "",
        /* 2.3: booking work resumes the journey in-console */
        opportunityId: a.opportunityId || "",
        salesOrderId: a.salesOrderId || "",
        bookingRef: a.bookingRef || "",
        unitName: a.unitName || "",
        customerName: a.customerName || ""
      }));
  }
  get hasOther() {
    return this.otherTasks.length > 0;
  }

  get hasAnything() {
    return this.hasAction || this.hasToday || this.hasOther;
  }
  get isEmpty() {
    return this.ready && !this.hasAnything;
  }

  /* ── clicks ── */

  /** Approvals and non-lead tasks: the record, in the Salesforce app (a new tab -
      the LWR site itself has no record pages, so a site-relative URL is a dead end). */
  handleOpenRecord(e) {
    const id = e.currentTarget.dataset.target;
    const host = this.feed && this.feed.lightningHost;
    if (!id || !host) {
      return;
    }
    window.open(host + "/lightning/r/" + id + "/view", "_blank", "noopener");
  }

  /** Lead work lands back inside the console; the workspace routes it. */
  openLeads(detail) {
    this.dispatchEvent(new CustomEvent("openleads", { detail }));
  }
  handleOverdueDigest() {
    this.openLeads({ filter: "over" });
  }
  handleTodayDigest() {
    this.openLeads({ filter: "today" });
  }
  handleLeadRow(e) {
    const leadId = e.currentTarget.dataset.lead;
    if (leadId) {
      this.openLeads({ leadId });
    }
  }

  /** An opportunity task opens its booking in the console; anything else falls back to
      the record. The Sales Order is resolved fresh on click - never trusted from the
      cacheable feed, which can be stale in the browser. */
  async handleOtherTask(e) {
    const ds = e.currentTarget.dataset;
    /* the target's own prefix says what it is, so even a stale feed routes correctly */
    const oppId = ds.opp || (ds.target && ds.target.indexOf("006") === 0 ? ds.target : "");
    if (!oppId) {
      this.handleOpenRecord(e);
      return;
    }
    let d = { opportunityId: oppId, salesOrderId: null };
    try {
      const fresh = await bookingFor({ opportunityId: oppId });
      d = {
        opportunityId: fresh.opportunityId || oppId,
        salesOrderId: fresh.salesOrderId || null,
        bookingRef: fresh.bookingRef || null,
        unitName: fresh.unitName || null,
        customerName: fresh.customerName || null
      };
    } catch (ignore) {
      /* resolution failing must not strand the click - the workspace still opens the journey */
    }
    this.dispatchEvent(new CustomEvent("openbooking", { detail: d }));
  }

  /* ── words ── */

  sinceSuffix(ms) {
    const t = Number(ms);
    if (!t) {
      return "";
    }
    const diff = Date.now() - t;
    if (diff < 3600 * 1000) {
      return " · since " + Math.max(1, Math.round(diff / 60000)) + " min";
    }
    if (diff < DAY_MS) {
      return " · since " + Math.round(diff / (3600 * 1000)) + " h";
    }
    return " · since " + Math.round(diff / DAY_MS) + " d";
  }

  /** The digest's one-line story: the edge due plus the first names. */
  digestSub(calls, prefix) {
    const parts = [];
    const first = calls[0];
    if (first && first.dueAtMs) {
      parts.push(prefix + this.dueWord(first.dueAtMs, first.dueHasTime));
    }
    const names = calls
      .map((c) => (c.leadName || "").split(" ")[0])
      .filter(Boolean)
      .slice(0, 3);
    if (names.length) {
      const more = calls.length - names.length;
      parts.push(names.join(", ") + (more > 0 ? " +" + more : ""));
    }
    return parts.join(" · ");
  }

  /** Same wording as the drawer: today/tomorrow/yesterday get their names. */
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
    if (diff === -1) {
      return ("yesterday " + hm).trim();
    }
    const dd = d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
    return hm ? dd + ", " + hm : dd;
  }
}