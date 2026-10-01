/**
 * Identity verification and compliance, one track per person.
 *
 * Version  Author      Date         Detail
 * 2.x+3    Aurelix Dev 30 Sep 2026  Ownership line with full names (UI-22); a manual KYC with no link reads "Manual
 *                                   KYC" (UI-23); bands inside the card, covered while pinned (UI-06); no blue step (UI-08).
 * 2.x+2    Aurelix Dev 29 Sep 2026  A company's primary contact approved by hand reads as verified on the
 *                                   Power of Attorney track, with no Power of Attorney row needed. Flag:
 *                                   nextStep.signatoryManual (SalesConsoleOrgController 2.x+1).
 * 2.x+1    Aurelix Dev 18 Sep 2026  The owner's checklist is drawn only where the rep collects the
 *                                   files (in branch, or verified with files missing), see
 *                                   c/mscKycGate 3.2.
 * 2.x      Aurelix Dev 18 Sep 2026  MSC-175 (B5). A joint owner's card carries the required-
 *                                   documents checklist (c/mscKycDocuments, compact) for THEIR
 *                                   residency, with Upload on each row. Needs opportunity-id from
 *                                   the host; without it nothing is drawn. An upload raises
 *                                   `documentschanged` so the host re-reads the owners.
 * 1.17     Aurelix Dev 07 Sep 2026  Signzy Phase 3. PRIMARY BUYER / POA KYC IS NOW DONE IN
 *                                   DETAILS, so this screen keeps their track and loses their
 *                                   duplicate KYC controls: stageAction returns no send/resend
 *                                   for isPrimary, and nextStepForBar strips the button from the
 *                                   corporate 'sendlink' step only. JOINT OWNERS ARE UNTOUCHED -
 *                                   their verification never moved and stays fully actionable,
 *                                   which is why this is a per-row test and not a read-only
 *                                   mode on the list. Compliance actions are decided before the
 *                                   guard and are unaffected for everyone.
 * 1.16     Aurelix Dev 02 Sep 2026  MSC-226. The stage track fills the booking detail's wider
 *                                   sheet (css only, one added rule). The journey is scoped
 *                                   out by :not(.vl--journey) and keeps its 900px cap.
 * 1.15     Aurelix Dev 01 Sep 2026  MSC-193. A hairline returns between a company and its
 *                                   signatory (business ask), on the same rhythm and width as
 *                                   the rule between parties; the sections gain balanced space
 *                                   around it. Company bookings with a filed signatory only.
 * 1.14     Aurelix Dev 01 Sep 2026  MSC-192. The last hairlines go (approved artifact
 *                                   "Verification Lines"): the group heading is held up by its
 *                                   own ground, not two rules; no rule between a company and its
 *                                   signatory (one buyer, two tracks); none above ownership. The
 *                                   only line left separates two different parties. CSS only.
 * 1.13     Aurelix Dev 01 Sep 2026  MSC-191. Readability after the boxes came off (approved
 *                                   artifact "Verification Pane"): the group name is said once
 *                                   and sticks to the top of the pane while its parties scroll
 *                                   under it, with a count; the amber edge becomes an "Action
 *                                   needed" flag on the row; the signatory's elbow goes (indent
 *                                   only); the rail stops stretching; a party's sentence keeps
 *                                   no rule above it. Presentation plus one derived flag.
 * 1.12     Aurelix Dev 01 Sep 2026  MSC-190. One surface (approved artifact "Verification Pane"):
 *                                   the pane's own card, the company wrapper and every party's
 *                                   border come off - parties are split by hairlines instead.
 *                                   In the journey (variant="journey") the pane keeps one card,
 *                                   because that step has no section card around it. Presentation
 *                                   only: no data, wording, stage, action or handler changes.
 * 1.11     Aurelix Dev 30 Aug 2026  MSC-182. Two groups (buyerRows / ownerRows); a company joint owner draws
 *                                   no rail; unreached stages print nothing; head chips retire; amber edge
 *                                   on a row that needs the rep. Markup and two flags only.
 * 1.10     Aurelix Dev 30 Aug 2026  MSC-180. An organisation's list gains its joint owners.
 * 1.9      Aurelix Dev 25 Aug 2026  MSC-172. showSignatoryTrack holds the track until the POA row exists.
 * 1.8      Aurelix Dev 23 Aug 2026  MSC-151. The org rows lose their action row; c/mscVerifyNext carries it.
 * 1.7      Aurelix Dev 23 Aug 2026  MSC-149. The link stage ticks off the signatory's linkSentAt.
 * 1.6      Aurelix Dev 23 Aug 2026  MSC-147. "Not yet submitted to compliance" gone from the org cards.
 * 1.5      Aurelix Dev 23 Aug 2026  MSC-146. The two actions the org cards carry.
 * 1.4      Aurelix Dev 23 Aug 2026  MSC-145. The organisation rows render (showRows gate fixed).
 * 1.2      Aurelix Dev 22 Aug 2026  MSC-115. A corporate booking has two subjects: company and signatory.
 * 1.1      Aurelix Dev 20 Aug 2026  MSC-094. The two head tallies are gone.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-088.
 *
 * Every person carries their own four-stage chain (KYC_STEP_* and complianceLabel, the console's
 * existing words), all from PartyDTO; buyerDetail adds what exists for the buyer alone. It
 * decides nothing: every gate and refusal sentence is the server's.
 */

import { LightningElement, api } from "lwc";
import { LABELS, complianceLabel } from "c/mscLabels";

const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];
const DASH = "";
const HOUR_MS = 3600 * 1000;
/* "Copied" holds for a moment after Copy link */
const COPIED_MS = 1200;

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

function pct(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const n = Number(value);
  return isNaN(n) ? null : Math.round(n * 100) / 100;
}

/* 2.x+3 - UI-22: the whole name, never shortened to two words */
function fullName(name) {
  return name ? String(name).trim() : "";
}

/** "19 Aug" from a Date or Datetime, read off the string. */
function dayOf(raw) {
  if (!raw) {
    return null;
  }
  const parts = String(raw).slice(0, 10).split("-");
  if (parts.length !== 3) {
    return String(raw);
  }
  const m = Number(parts[1]);
  if (!m || m < 1 || m > 12) {
    return String(raw);
  }
  return `${Number(parts[2])} ${MONTHS[m - 1]}`;
}

/** "20:23", local. */
function clockOf(raw) {
  if (!raw) {
    return null;
  }
  const d = new Date(raw);
  if (isNaN(d.getTime())) {
    return null;
  }
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

function msOf(raw) {
  const d = new Date(raw);
  return isNaN(d.getTime()) ? null : d.getTime();
}

/** A rough span in the largest unit that still reads as a number. */
function spanOf(ms) {
  if (ms === null || ms === undefined || isNaN(ms)) {
    return null;
  }
  const abs = Math.abs(ms);
  const days = Math.floor(abs / (24 * HOUR_MS));
  if (days >= 1) {
    return days === 1 ? "1 day" : `${days} days`;
  }
  const hours = Math.floor(abs / HOUR_MS);
  if (hours >= 1) {
    return hours === 1 ? "1 hour" : `${hours} hours`;
  }
  const mins = Math.max(1, Math.floor(abs / 60000));
  return mins === 1 ? "1 minute" : `${mins} minutes`;
}

export default class MscVerifyList extends LightningElement {
  /** One OwnersDTO. Never mutated here. */
  @api state;
  /** B5 - the booking, so a joint owner's documents can be listed and uploaded here. */
  @api opportunityId;
  /** A write is in flight on the host; every control waits. */
  @api busy = false;
  /** Whose link is being sent right now; SENDING is not a record state. */
  @api sendingAccountId;
  /** A status re-read is in flight. */
  @api refreshing = false;
  /** The buyer's ComplianceStateDTO, where the host has one. Optional. */
  @api buyerDetail;
  /** Where this list is mounted: "journey" (carries the ownership strip) or "tab". A string, not a boolean. */
  @api variant = "tab";
  /** When the status was last re-read, as ISO; used only without buyerDetail. */
  @api checkedAt;

  labels = LABELS;
  /* "Copied" for a moment after Copy link; client-side only */
  copied = false;
  _copyTimer;

  disconnectedCallback() {
    window.clearTimeout(this._copyTimer);
  }

  get s() {
    return this.state || {};
  }
  get parties() {
    return this.s.parties || [];
  }
  get units() {
    return this.s.units || [];
  }
  get isMultiUnit() {
    return this.s.isMultiUnit === true;
  }
  get blockedReason() {
    return this.s.blockedReason;
  }

  /** Nothing at all when there is nothing to say. */
  get showPanel() {
    return !!this.state && (this.s.available === true || !!this.blockedReason);
  }

  /**
   * MSC-190: exactly one surface, wherever the pane is mounted. The Verification tab is already
   * inside c/mscOwnersPane's card, so the pane draws nothing; the journey's verify step has no
   * section card (MSC-090), so there it keeps one of its own.
   */
  get panelClass() {
    return this.variant === "journey" ? "vl vl--journey" : "vl";
  }
  /** One list, two sources: a company's two subjects as rows; a person account returns `people` untouched. */
  /* MSC-182: the two groups, split by the flag every row carries */
  get buyerRows() {
    if (this.orgMode) {
      return this.orgRows.map((r) => this.withEdge(r));
    }
    return this.people.filter((r) => r.isPrimaryRow === true);
  }
  get ownerRows() {
    /* from `people`, never from `rows`: the org tracks carry no isPrimaryRow flag */
    return this.people.filter((r) => r.isPrimaryRow !== true);
  }
  get showBuyerGroup() {
    return this.showRows && this.buyerRows.length > 0;
  }
  get showOwnerGroup() {
    return this.showRows && this.ownerRows.length > 0;
  }
  get ownerCount() {
    return String(this.ownerRows.length);
  }
  /** In org mode the two tracks sit in one card. */
  get showCompanyCard() {
    return this.orgMode;
  }

  /** Which org section the server's next step points at; colours only. */
  withEdge(row) {
    const key = (this.nextStep && this.nextStep.key) || "";
    const forCompany = key === "details" || key === "submit";
    const forSignatory = key === "signatory" || key === "fixsignatory";
    const you =
      (row.key === "org-company" && forCompany) ||
      (row.key === "org-signatory" && forSignatory);
    return Object.assign({}, row, {
      sectionClass: you ? "vl__sec vl__sec--you" : "vl__sec",
      /* MSC-191: the amber edge became a word on the row's own line */
      needsYou: you
    });
  }

  get rows() {
    /* MSC-180: the joint owners follow the org tracks through the same person markup; the
       primary row is filtered (the company is the two tracks) */
    if (!this.orgMode) {
      return this.people;
    }
    const owners = this.people.filter((r) => r.isPrimaryRow !== true);
    return [...this.orgRows, ...owners];
  }

  /**
   * The org rows are built from buyerDetail and read nothing from the joint owner service, so
   * they must not be gated on its `available` (false on every corporate booking). The person
   * path is the same test it always was.
   */
  get showRows() {
    return this.rows.length > 0 && (this.orgMode || this.s.available === true);
  }
  get showEmpty() {
    return this.s.available === true && this.parties.length === 0 && !this.orgMode;
  }

  // the organisation's two tracks
  /* only where the host passes the buyer's compliance answer (the journey) */
  get orgMode() {
    return !!this.buyerDetail && this.buyerDetail.isPersonAccount === false;
  }

  /** The sentence renders once. */
  get showBlockedNote() {
    return !!this.blockedReason && !this.orgMode;
  }

  /* MSC-151: the bar's two props and its one event, carried straight through so the bar sits
     inside this card above the rows */
  @api nextStep;
  @api nextBusy = false;

  handleNextAction(event) {
    this.dispatchEvent(
      new CustomEvent("nextaction", { detail: (event.detail || {}) })
    );
  }

  /**
   * 1.17 - PHASE 3. The authorised POA's identity verification is now performed in Details
   * (c/mscKycGate), where the rep and the customer are still together. This bar therefore
   * keeps the server's sentence but drops the BUTTON for that one action, so a corporate
   * booking never carries two live "send the POA a link" controls on two screens - which is
   * how a customer ends up with two links and a rep ends up unsure which one is live.
   *
   * Only 'sendlink' is affected. 'opendetails', 'submit' and 'check' are the company's
   * post-booking compliance work, they never moved, and they keep their buttons.
   * Nothing is filtered when the server offers no action at all.
   */
  get nextStepForBar() {
    const step = this.nextStep;
    if (!step || step.action !== "sendlink") {
      return step;
    }
    return Object.assign({}, step, { buttonLabel: null, action: null });
  }

  /* orgNote retired (MSC-151); KYC_CORPORATE untouched */

  /* orgCompany and orgSignatory retired; orgRow / orgStagesOf build the two subjects as rows */
  get showNoSignatory() {
    return this.orgMode && !(this.buyerDetail && this.buyerDetail.signatory);
  }

  /**
   * MSC-172. Is the signatory actually on record? nextStep.key is 'signatory' when, and only
   * when, the POA row is missing. Nothing in flight is ever hidden.
   */
  get showSignatoryTrack() {
    const sig = (this.buyerDetail && this.buyerDetail.signatory) || null;
    if (!sig) {
      return false;
    }
    if (sig.linkSentAt || sig.kycCompletedDate || sig.submitted === true || this.signatoryManual) {
      return true;
    }
    const step = this.nextStep;
    return !(step && step.key === "signatory");
  }

  /** 2.x+2 - the server says the primary contact was approved by hand (no completion date). */
  get signatoryManual() {
    return !!(this.nextStep && this.nextStep.signatoryManual === true);
  }

  /** The company and its signatory, as rows with the same keys the people carry. */
  get orgRows() {
    const d = this.buyerDetail || {};
    const out = [];
    if (d.company) {
      out.push(this.orgRow(d.company, LABELS.VL_ORG_ROLE_COMPANY, true));
    }
    /* only once filed; see showSignatoryTrack */
    if (d.signatory && this.showSignatoryTrack) {
      out.push(this.orgRow(d.signatory, LABELS.VL_ORG_ROLE_SIGNATORY, false));
    }
    return out;
  }

  orgRow(t, role, isCompany) {
    const track = this.orgTrack(t, role, null);
    const stages = this.orgStagesOf(t, isCompany);
    /* MSC-151: an org row is a report and carries no controls; c/mscVerifyNext carries the one
       button. Passfort's comment goes with them (the chip carries the verdict). */
    const next = isCompany ? t.comment || null : null;
    const action = null;
    return {
      key: isCompany ? "org-company" : "org-signatory",
      /* no accountId: an org track is not a party row */
      accountId: null,
      name: t.name,
      meta: role,
      statusText: track.statusText,
      statusClass: track.statusClass,
      stages,
      trackClass: stages.length === 2 ? "vl__track vl__track--two" : "vl__track",
      next,
      action,
      showCopy: false,
      copyLabel: LABELS.VL_COPY,
      showAnyAction: !!action
    };
  }

  /** Where a company stands, in the list's existing words. */
  /* orgCompanyLine, orgCompanyAction and orgSignatoryAction retired (MSC-151); nextStep decides */

  orgStagesOf(t, isCompany) {
    const cleared = String(t.approvalStatus || "").toLowerCase() === "approved";
    const submitted = t.submitted === true || !!t.approvalStatus;
    const labels = isCompany
      ? [LABELS.KYC_STEP_SUBMITTED, LABELS.KYC_STEP_APPROVED]
      : [
          LABELS.KYC_STEP_SENT,
          LABELS.KYC_STEP_DONE,
          LABELS.KYC_STEP_SUBMITTED,
          LABELS.KYC_STEP_APPROVED
        ];
    let done;
    let facts;
    /* a stage that has not happened says nothing */
    if (isCompany) {
      done = [submitted, cleared];
      facts = [
        "",
        cleared ? "" : t.approvalStatus ? complianceLabel(t.approvalStatus) : ""
      ];
    } else {
      /* 2.x+2: a manual approval is verified too, with no date to show (as for a person) */
      const manual = this.signatoryManual;
      const verified = !!t.kycCompletedDate || submitted || manual;
      /* MSC-149: the link stage reads the signatory's own KYC_Send_Date_Time__c */
      const sent = verified || !!t.linkSentAt;
      done = [sent, verified, submitted, cleared];
      facts = [
        t.linkSentAt ? `${dayOf(t.linkSentAt)} · ${clockOf(t.linkSentAt)}` : "",
        t.kycCompletedDate ? dayOf(t.kycCompletedDate) : manual ? LABELS.VL_FACT_MANUAL : "",
        "",
        cleared ? "" : t.approvalStatus ? complianceLabel(t.approvalStatus) : ""
      ];
    }
    const activeIdx = done.indexOf(false);
    return labels.map((label, i) => {
      const tone = done[i] ? "is-done" : i === activeIdx ? "is-now" : "";
      return {
        key: `os-${i}`,
        label,
        fact: facts[i] || DASH,
        cls: `vl__st ${tone}`,
        barClass: `vl__st-bar ${tone}`,
        markClass: `vl__st-mark ${tone}`,
        showTick: done[i] === true
      };
    });
  }

  /* one shape for both tracks; the chip vocabulary is the list's own */
  orgTrack(t, role, fact) {
    const verdict = t.approvalStatus;
    return {
      name: t.name,
      role,
      fact,
      showCheck: false,
      /* no chip until there is something to report; the template draws it only lwc:if={p.statusText} */
      statusText: verdict
        ? complianceLabel(verdict)
        : t.submitted === true
          ? LABELS.VL_FACT_SUBMITTED
          : null,
      statusClass: verdict
        ? this.verdictClass(verdict)
        : t.submitted === true
          ? "vl__chip vl__chip--blue"
          : "vl__chip"
    };
  }

  /* the list's own colours: cleared green, refused red, in Passfort's hands amber */
  verdictClass(verdict) {
    const v = String(verdict || "").toLowerCase();
    if (v === "approved") return "vl__chip vl__chip--green";
    if (v === "rejected" || v === "canceled" || v === "cancelled") {
      return "vl__chip vl__chip--red";
    }
    return "vl__chip vl__chip--amber";
  }

  /* the signatory's Check left this component (MSC-151) */

  // the head
  /* MSC-094: verifiedChip and complianceChip are gone with the head tallies */

  /** "Checked 19:03". */
  get checkedLabel() {
    const raw =
      (this.buyerDetail && this.buyerDetail.refreshedOn) || this.checkedAt || null;
    const t = clockOf(raw);
    return t ? fill(LABELS.VL_CHECKED, t) : null;
  }
  get refreshTitle() {
    return this.refreshing ? LABELS.KYC_REFRESHING : LABELS.KYC_REFRESH;
  }
  get refreshDisabled() {
    return this.refreshing === true || this.busy === true;
  }
  get refreshClass() {
    return this.refreshing ? "vl__refresh vl__refresh--busy" : "vl__refresh";
  }

  // the people
  get people() {
    return this.parties.map((p, i) => {
      const sending =
        p.verificationStatus === "SENDING" ||
        (!!this.sendingAccountId && p.accountId === this.sendingAccountId);
      const detail = p.isPrimary ? this.buyerDetail : null;

      const status = this.stageState(p, sending);
      /* canEdit is the server's answer; read to know whether "Add details" can do anything */
      const action = this.stageAction(p, sending, p.isPrimary || p.canEdit === true);
      /* MSC-182: a company party draws no rail and one sentence (canEverVerify) */
      const noRail = p.canEverVerify === false;

      return {
        key: p.accountId || `p-${i}`,
        accountId: p.accountId,
        name: p.name,
        noRail,
        showRail: !noRail,
        /* B5: a person who is not the buyer lists their own documents here; the buyer's are on
           Details, and a company party has none of its own. 3.2: only where the rep collects the
           files - released to the branch, or verified with files still to come - never while the
           owner's Signzy link is the route (the callback files the documents itself). */
        showDocuments:
          !noRail && !!p.accountId && p.isPrimary !== true && !!this.opportunityId &&
          (p.verificationStatus === "IN_BRANCH" || !!p.kycCompletedDate),
        /* amber only when the rep's move is the primary one */
        cardClass:
          action && String(action.cls).indexOf("vl__act--primary") >= 0
            ? "vl__person vl__person--you"
            : "vl__person",
        /* MSC-191: the same fact, said in words on the row instead of drawn as an edge */
        needsYou:
          !!action && String(action.cls).indexOf("vl__act--primary") >= 0,
        /* MSC-180: read only by the orgMode merge; the primary party is the company */
        isPrimaryRow: p.isPrimary === true,
        meta: this.metaOf(p),
        statusText: status.text,
        statusClass: status.cls,
        stages: this.stagesOf(p, detail),
        /* a person always has four; the class is on the row so the shared block needs no branch */
        trackClass: "vl__track",
        next: noRail ? LABELS.JO_V_NOT_HERE_LINE : this.nextLine(p, sending, action),
        action,
        /* the buyer's link, copyable while live and unused */
        showCopy:
          !!detail &&
          !!detail.linkUrl &&
          detail.linkActive === true &&
          detail.kycComplete !== true,
        copyLabel: this.copied ? LABELS.VL_COPIED : LABELS.VL_COPY,
        showAnyAction:
          !!action ||
          (!!detail &&
            !!detail.linkUrl &&
            detail.linkActive === true &&
            detail.kycComplete !== true)
      };
    });
  }

  /** B5: an upload changed a party's rows - the host re-reads the owners. */
  handleDocumentsChanged() {
    this.dispatchEvent(new CustomEvent("documentschanged"));
  }

  /** Role, residency and, on a basket, which units. */
  metaOf(p) {
    /* MSC-182: the BUYER heading says the role; the meta says it for a joint owner only */
    const parts = p.isPrimary
      ? []
      : [p.relationshipSubType || p.relationshipType || LABELS.JO_ROLE_JOINT];
    const residency = [p.residentStatus, p.nationality].filter(Boolean).join(" · ");
    if (residency) {
      parts.push(residency);
    }
    if (this.isMultiUnit && !p.isPrimary) {
      const names = p.unitNames || [];
      if (p.onAllUnits === true) {
        parts.push(fill(LABELS.JO_ON_ALL_UNITS, this.units.length));
      } else if (names.length) {
        parts.push(fill(LABELS.JO_ON_UNITS, names.join(", ")));
      }
    }
    return parts.join(" · ");
  }

  /** The four stages for one person; done is read from the latest evidence backwards. */
  stagesOf(p, detail) {
    const submitted = p.complianceSubmitted === true;
    const verified =
      submitted || !!p.kycCompletedDate || p.verificationStatus === "VERIFIED" ||
      p.manuallyApproved === true;
    const expired = p.verificationStatus === "EXPIRED";
    const sent =
      verified ||
      expired ||
      !!p.verificationSentOn ||
      p.verificationStatus === "SENT";
    const cleared = p.complianceStatus === "Approved";
    /* 2.x+3 - UI-23: approved by manual KYC with no link ever sent: the first step is the manual route */
    const manualRoute =
      (p.manuallyApproved === true || (!!detail && detail.manuallyApproved === true)) &&
      !p.verificationSentOn &&
      !(detail && detail.linkSentAt) &&
      p.verificationStatus !== "SENT";

    const done = [sent, verified, submitted, cleared];
    const activeIdx = done.indexOf(false);

    const facts = [
      manualRoute ? "" : this.sentFact(p, detail, sent),
      this.verifiedFact(p, detail, verified, expired, sent),
      this.submittedFact(p, detail, submitted),
      this.clearedFact(p, detail)
    ];

    return [
      manualRoute ? LABELS.VL_STEP_MANUAL : LABELS.KYC_STEP_SENT,
      LABELS.KYC_STEP_DONE,
      LABELS.KYC_STEP_SUBMITTED,
      LABELS.KYC_STEP_APPROVED
    ].map((label, i) => {
      let tone = done[i] ? "is-done" : i === activeIdx ? "is-now" : "";
      /* an expired link needs attention: a resend */
      if (i === 0 && expired) {
        tone = "is-warn";
      }
      return {
        key: `s-${i}`,
        label,
        fact: facts[i] || DASH,
        cls: `vl__st ${tone}`,
        barClass: `vl__st-bar ${tone}`,
        markClass: `vl__st-mark ${tone}`,
        showTick: done[i] === true
      };
    });
  }

  /* MSC-182: a fact is a date or a verdict, never the sentence again */
  sentFact(p, detail, sent) {
    if (!sent) {
      return "";
    }
    const when = p.verificationSentOn || (detail && detail.linkSentAt);
    let text = when ? `${dayOf(when)} · ${clockOf(when)}` : "";
    /* buyer only: a joint owner's Account does not record link expiry */
    if (detail && detail.linkExpiresAt && detail.kycComplete !== true) {
      const exp = msOf(detail.linkExpiresAt);
      const span = spanOf(exp === null ? null : exp - Date.now());
      if (span) {
        text +=
          " · " +
          (detail.linkActive
            ? fill(LABELS.VL_FACT_EXPIRES_IN, span)
            : fill(LABELS.VL_FACT_EXPIRED_AGO, span));
      }
    }
    return text;
  }

  verifiedFact(p, detail, verified, expired, sent) {
    if (verified) {
      if (p.kycCompletedDate) {
        return dayOf(p.kycCompletedDate);
      }
      /* 18 Sep 2026: a manual approval has no completion date - say so instead of nothing */
      return p.manuallyApproved === true || (detail && detail.manuallyApproved === true)
        ? LABELS.VL_FACT_MANUAL
        : "";
    }
    if (expired) {
      return LABELS.VL_FACT_EXPIRED;
    }
    /* buyer only: where the customer got to */
    if (detail && detail.journeyStatus) {
      return fill(LABELS.VL_FACT_CUSTOMER_AT, detail.journeyStatus);
    }
    return "";
  }

  submittedFact(p, detail, submitted) {
    if (submitted) {
      return detail && detail.lastAttemptOn ? dayOf(detail.lastAttemptOn) : "";
    }
    return "";
  }

  clearedFact(p, detail) {
    const verdict = complianceLabel(p.complianceStatus);
    if (!verdict || p.complianceStatus === "Approved") {
      return "";
    }
    const risk = detail && detail.riskStatus;
    return risk
      ? fill(LABELS.VL_FACT_RISK, verdict, String(risk).toLowerCase())
      : verdict;
  }

  /** The chip: one word about the whole chain. Compliance is read before verification. */
  stageState(p, sending) {
    if (sending) {
      return { text: LABELS.JO_V_SENDING, cls: "chip" };
    }
    if (p.complianceSubmitted === true) {
      return {
        text: complianceLabel(p.complianceStatus) || LABELS.KYC_STEP_SUBMITTED,
        cls: this.complianceChipClass(p.complianceStatus)
      };
    }
    if (p.kycCompletedDate) {
      return {
        text: fill(LABELS.JO_VERIFIED_ON, dayOf(p.kycCompletedDate)),
        cls: "chip vl__chip--green"
      };
    }
    switch (p.verificationStatus) {
      case "VERIFIED":
        return { text: LABELS.VERIFY_DONE, cls: "chip vl__chip--green" };
      case "SENT":
        return { text: LABELS.VERIFY_TAPE_SENT, cls: "chip vl__chip--blue" };
      case "EXPIRED":
        return { text: LABELS.VERIFY_STATUS_EXPIRED, cls: "chip vl__chip--amber" };
      default:
        /* no status means the server could not read that account; silence */
        if (!p.verificationStatus) {
          return { text: null, cls: "chip" };
        }
        return p.canEverVerify === false
          ? { text: LABELS.JO_V_NOT_HERE, cls: "chip" }
          : { text: LABELS.JO_VERIFY_NOT_SENT, cls: "chip" };
    }
  }

  /** Which of Passfort's answers is good news, decided on the raw status. */
  complianceChipClass(raw) {
    if (raw === "Approved") return "chip vl__chip--green";
    if (raw === "Rejected" || raw === "Canceled") return "chip vl__chip--red";
    if (raw === "Requires Resubmission") return "chip vl__chip--amber";
    return "chip vl__chip--blue";
  }

  /** At most one action, never one that cannot work. Compliance is read first. */
  stageAction(p, sending, canFix) {
    /*
     * 1.17 - PHASE 3. The PRIMARY BUYER's identity verification moved to Details
     * (c/mscKycGate). Their row here becomes a read-only track: the stage chips and the
     * dates still render, but the KYC send/resend is not offered a second time.
     *
     * JOINT OWNERS ARE NOT AFFECTED, and that is the point of testing isPrimary rather
     * than making the list read-only: their verification is a genuinely post-booking
     * activity that never moved, so Send, Resend and Add details all stay exactly as they
     * were for them.
     *
     * Compliance is deliberately decided BEFORE this guard: submitting the buyer to
     * compliance is post-booking work that did not move either, so the buyer keeps that
     * control.
     */
    const kycMovedToDetails = p.isPrimary === true;

    if (sending && !kycMovedToDetails) {
      return {
        kind: "send",
        text: LABELS.JO_V_SENDING_BTN,
        disabled: true,
        cls: "pill vl__act"
      };
    }
    /* already with compliance: nothing to press */
    if (p.complianceSubmitted === true) {
      return null;
    }
    if (p.canCheckCompliance === true) {
      /* not held by a send in flight: a check reads, it does not write */
      return {
        kind: "compliance",
        text: LABELS.JO_C_CHECK,
        disabled: this.busy === true,
        cls: "pill vl__act vl__act--primary"
      };
    }
    /* verified, and something the server named is still in the way */
    if (p.verificationStatus === "VERIFIED" || p.kycCompletedDate) {
      return null;
    }
    /* 1.17: past compliance, the buyer's KYC controls live in Details now. Everything
       below this line is a KYC action, so the buyer takes none of it. */
    if (kycMovedToDetails) {
      return null;
    }
    /* one send at a time across the whole list */
    const held = !!this.sendingAccountId || this.busy === true;
    if (p.canSendVerification === true) {
      const again =
        p.verificationStatus === "SENT" || p.verificationStatus === "EXPIRED";
      return {
        kind: "send",
        text: again ? LABELS.JO_V_RESEND : LABELS.JO_V_SEND,
        disabled: held,
        cls: again ? "pill vl__act" : "pill vl__act vl__act--primary"
      };
    }
    if (p.detailsMissing === true && canFix) {
      return {
        kind: "fix",
        text: LABELS.JO_V_FIX,
        disabled: held,
        cls: "pill vl__act vl__act--primary"
      };
    }
    return null;
  }

  /** One sentence under each track; where nothing can act, it is the server's own reason. */
  nextLine(p, sending, action) {
    if (sending) {
      return LABELS.VL_NEXT_SENDING;
    }
    if (p.complianceSubmitted === true) {
      return p.complianceStatus === "Approved"
        ? LABELS.VL_NEXT_CLEARED
        : LABELS.VL_NEXT_SUBMITTED;
    }
    if (p.canCheckCompliance === true) {
      return LABELS.VL_NEXT_CHECK;
    }
    if (p.verificationStatus === "VERIFIED" || p.kycCompletedDate) {
      return p.complianceBlockedReason || LABELS.VL_NEXT_CHECK;
    }
    if (p.canSendVerification === true) {
      if (p.verificationStatus === "EXPIRED") {
        return LABELS.VL_NEXT_EXPIRED;
      }
      return p.verificationStatus === "SENT"
        ? LABELS.VL_NEXT_WAITING
        : LABELS.VL_NEXT_SEND;
    }
    if (p.detailsMissing === true && action && action.kind === "fix") {
      return LABELS.VL_NEXT_DETAILS;
    }
    return p.verificationBlockedReason || p.complianceBlockedReason || null;
  }

  // the ownership strip
  /** Context, not content: one quiet line on the journey, with the Add that belongs to it. */
  get ownershipLine() {
    const primary = this.parties.find((x) => x.isPrimary);
    const bits = [];
    /* 2.x+3 - UI-22: full names; the line wraps rather than cutting one */
    if (primary) {
      bits.push(`${fullName(primary.name)} ${pct(this.s.primaryShare)}%`);
    }
    this.parties
      .filter((x) => !x.isPrimary)
      .forEach((x) => bits.push(`${fullName(x.name)} ${pct(x.share)}%`));
    if (!bits.length) {
      return null;
    }
    const line = bits.join(" · ");
    return this.s.coverageLine ? `${line} · ${this.s.coverageLine}` : line;
  }
  get canAdd() {
    return (
      this.s.available === true &&
      this.s.readOnly !== true &&
      this.s.slotsRemaining !== 0
    );
  }
  get showStrip() {
    return this.variant === "journey" && this.s.available === true;
  }


  // out
  /** One event per act, each carrying the account it is about; both hosts route them. */
  handleAction(event) {
    const kind = event.currentTarget.dataset.kind;
    const accountId = event.currentTarget.dataset.account;
    if (!kind) {
      return;
    }
    /* the three org kinds are gone (MSC-151); every kind here belongs to a person row */
    if (!accountId) {
      return;
    }
    const name =
      kind === "compliance"
        ? "checkcompliance"
        : kind === "fix"
          ? "fixdetails"
          : "sendverification";
    this.dispatchEvent(new CustomEvent(name, { detail: { accountId } }));
  }

  /** The drawer opens on the units left without a joint owner, where there are any. */
  get hasGap() {
    return (
      this.canAdd &&
      (this.s.jointOwnerCount || 0) > 0 &&
      (this.s.unitsWithNoJointOwner || []).length > 0
    );
  }

  handleAdd() {
    if (this.busy) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent(this.hasGap ? "addtouncovered" : "addowner")
    );
  }

  /** Client-side only: the URL is already on the buyer's DTO. */
  handleCopy() {
    const url = this.buyerDetail && this.buyerDetail.linkUrl;
    if (!url || !navigator.clipboard || !navigator.clipboard.writeText) {
      return;
    }
    navigator.clipboard.writeText(url).then(() => {
      this.copied = true;
      window.clearTimeout(this._copyTimer);
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._copyTimer = window.setTimeout(() => {
        this.copied = false;
      }, COPIED_MS);
    }, () => {});
  }

  handleRefresh() {
    if (this.refreshDisabled) {
      return;
    }
    this.dispatchEvent(new CustomEvent("refreshcompliance"));
  }
}