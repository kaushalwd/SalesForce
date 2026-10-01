/**
 * Who owns this booking - the primary owner and every joint owner.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-081, phase 2 of the joint owner module.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-082. Identity verification, per person: each row
 *                                   reports that person's own KYC state and carries AT
 *                                   MOST ONE action for it, and the head gains the
 *                                   tally. The action is never a disabled button - in
 *                                   DEV_1, 94.8% of joint owners cannot be sent
 *                                   anything, so a greyed-out Send would be the normal
 *                                   state of this panel rather than the exception. Where
 *                                   contact detail is the only thing missing the row
 *                                   offers to collect it; where nothing here can help,
 *                                   it says so in a sentence and offers nothing. Still
 *                                   dumb: the server decides all three cases.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-083. Compliance, per person - AND THE ROW STILL
 *                                   SAYS ONE THING. Compliance strictly follows identity
 *                                   verification: nobody reaches it without verifying
 *                                   first, and nobody goes back. So it is not a second
 *                                   axis needing a second chip, it is the far end of the
 *                                   one this row already has, and the chip simply keeps
 *                                   going - Verification not sent, KYC link sent,
 *                                   Verified, Submitted to compliance, Cleared. The
 *                                   action slot advances with it, still at most one and
 *                                   still never a disabled button. The head's tally does
 *                                   the same, naming the NEAREST OUTSTANDING STAGE rather
 *                                   than growing a third chip: "1 of 2 verified" while
 *                                   anyone is unverified, and only then the compliance
 *                                   fraction. A rep reads one number and it is always
 *                                   the one they can act on.
 * 1.3      Aurelix IT  20 Aug 2026  MSC-085. ONE CSS RULE, no markup and no logic.
 *                                   The phone block says in its own header that
 *                                   "every target reaches 44px" and then set the
 *                                   row's action, Edit and the small Add to 36 - so
 *                                   the comment was the only place that standard was
 *                                   actually kept. c/mscStyles states it outright:
 *                                   "a 36px control is a miss on a touch screen, and
 *                                   44px is the iOS and Android minimum". These are
 *                                   the three a rep presses most on a phone.
 * 1.4      Aurelix IT  20 Aug 2026  MSC-087. "1 unit without a joint owner" no longer
 *                                   fires on a booking that has no joint owner.
 *                                   unitsWithNoJointOwner is every unit without one,
 *                                   which on a sole-owned booking is all of them - so
 *                                   the amber warning was the default state of the
 *                                   commonest booking in the org, on a screen where
 *                                   nothing is wrong. A gap needs co-ownership to have
 *                                   started; before that the head reads Sole owner.
 *                                   Two conditions reordered, one guard added, no new
 *                                   state and no server change.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DUMB BY DESIGN. Every value arrives on `state` - one OwnersDTO from
 * SalesConsoleJointOwnerService.getOwners - and every decision leaves as an event.
 * This component works nothing out about the data: not whether a unit is still
 * open, not how much is left to allocate, not which units have nobody. All of
 * that is decided on the server, where the data is, and rendered here.
 *
 * It follows c/mscCompliance, which sits directly beneath it in the same
 * Verification card and keeps the same contract.
 *
 * WHY THE DRAWER IS NOT IN HERE. The card this panel lives in carries
 * backdrop-filter: blur(22px), which makes it the containing block for any
 * position: fixed descendant - so a drawer rendered here would become a pane
 * inside the card rather than a layer over the booking. c/mscOwnersDrawer is
 * mounted by mscBookingPage at .page level for that reason, exactly as
 * c-msc-compliance-check already is. c/mscDrawer's own header records the day
 * this was learned.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * VOCABULARY. Primary Owner, Joint Owner, Ownership %, Relationship Type and
 * Relationship Sub Type are Modon's own labels, from c/mscLabels. No user-facing
 * string is written in this file or its template.
 */

import { LightningElement, api } from "lwc";
/* complianceLabel is the console's ONE mapping of PassfortApprovalStatus__pc, already
   used by c/mscCompliance directly beneath this panel. Imported rather than copied so
   the row and the card can never call the same status two different things. */
import { LABELS, complianceLabel } from "c/mscLabels";

const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

/** The joint-owner segments of the meter, in order. See --seg-* in c/mscTokens. */
const SEGMENTS = ["ow__seg--1", "ow__seg--2", "ow__seg--3"];

/**
 * "30.00" -> "30", "33.33" -> "33.33". A percentage with a dead ".00" on it reads
 * as a measurement rather than a decision somebody made.
 */
function pct(value) {
  if (value === null || value === undefined || value === "") return "";
  const n = Number(value);
  if (Number.isNaN(n)) return "";
  return String(Math.round(n * 100) / 100);
}

/**
 * "2026-08-18" -> "18 Aug". Parsed by hand rather than through Date: an ISO date
 * string is read as UTC midnight, and toLocaleDateString would then move it a day
 * backwards for any viewer west of Greenwich.
 */
function shortDate(raw) {
  if (!raw) return "";
  const parts = String(raw).slice(0, 10).split("-");
  if (parts.length !== 3) return String(raw);
  const m = Number(parts[1]);
  if (!m || m < 1 || m > 12) return String(raw);
  return `${Number(parts[2])} ${MONTHS[m - 1]}`;
}

/** The name a meter key can carry. Two words is enough to tell people apart. */
function shortName(name) {
  if (!name) return "";
  const words = String(name).trim().split(/\s+/);
  return words.length <= 2 ? name : words.slice(0, 2).join(" ");
}

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

export default class MscOwners extends LightningElement {
  /** One OwnersDTO. Never mutated here. */
  @api state;
  /** A write is in flight somewhere on the page; every control waits. */
  @api busy = false;
  /**
   * 1.1 - whose link is being sent right now.
   *
   * Held by the page rather than read off the DTO, because SENDING is not a state
   * any record has: it is the gap between the queueable being enqueued and MODON's
   * Flow stamping KYC_Send_Date_Time__c. getOwners can only ever answer with what
   * is written down.
   */
  @api sendingAccountId;

  labels = LABELS;

  // ── the state, defensively ────────────────────────────────────────────
  get s() {
    return this.state || {};
  }
  get units() {
    return this.s.units || [];
  }
  get parties() {
    return this.s.parties || [];
  }
  get uncovered() {
    return this.s.unitsWithNoJointOwner || [];
  }
  get jointOwnerCount() {
    return this.s.jointOwnerCount || 0;
  }
  get isMultiUnit() {
    return !!this.s.isMultiUnit;
  }
  get readOnly() {
    return !!this.s.readOnly;
  }
  get blockedReason() {
    return this.s.blockedReason;
  }

  /**
   * Nothing at all when there is nothing to say. A card with an empty panel in it
   * is worse than a card without one.
   */
  get showPanel() {
    return !!this.state && (this.s.available === true || !!this.s.blockedReason);
  }

  // ── head ──────────────────────────────────────────────────────────────
  /** One fact, chosen by state. The most urgent one wins. */
  get headChip() {
    const total = this.jointOwnerCount + 1;
    if (this.readOnly) {
      return { cls: "chip", icon: "lock", dot: false, text: LABELS.JO_CHIP_LOCKED };
    }
    /*
     * 1.4 - SOLE OWNER IS NOT A GAP, AND WINS OVER ONE.
     *
     * unitsWithNoJointOwner is every unit that has no joint owner on it, which on a
     * booking nobody has co-owned is all of them - so the amber warning fired on the
     * commonest booking in the org, and on the one screen where the rep has done
     * nothing wrong. A gap is only a gap once co-ownership has started and a unit was
     * left out of it; before that the booking is simply sole-owned, and says so. The
     * server field is right and is untouched - the sequence of the two tests was what
     * was wrong, and the empty-panel wording below already read the count this way.
     */
    if (this.jointOwnerCount === 0) {
      return { cls: "chip", icon: "user", dot: false, text: LABELS.JO_CHIP_SOLE };
    }
    const gap = this.uncovered.length;
    if (gap > 0) {
      return {
        cls: "chip ow__chip--amber",
        icon: null,
        dot: true,
        text:
          gap === 1
            ? LABELS.JO_CHIP_UNCOVERED_ONE
            : fill(LABELS.JO_CHIP_UNCOVERED, gap)
      };
    }
    if (this.isMultiUnit) {
      return {
        cls: "chip",
        icon: null,
        dot: false,
        text: fill(LABELS.JO_CHIP_OWNERS_UNITS, total, this.units.length)
      };
    }
    return {
      cls: "chip",
      icon: null,
      dot: false,
      text: total === 1 ? LABELS.JO_CHIP_OWNERS_ONE : fill(LABELS.JO_CHIP_OWNERS, total)
    };
  }

  /**
   * 1.2 - ONE TALLY, NAMING THE NEAREST OUTSTANDING STAGE.
   *
   * Was the verification fraction alone (1.1). Compliance is the stage after it and
   * every person passes through both, so a second chip beside this one would put two
   * fractions with the same denominator side by side and leave the rep working out
   * which of them they were being asked to act on. This one moves instead: it counts
   * verification while anyone is still unverified, and compliance once nobody is.
   *
   * The denominator is the server's verifiableCount for both, which is people who could
   * EVER go through this route - counted by Account, not by row. A company joint owner
   * is outside it entirely, so the fraction can always reach its own denominator.
   *
   * ABSENT ON A SOLE-OWNER BOOKING, which is seven in eight. "0 of 1 verified" there
   * restates, less clearly, what the verification chain immediately below this panel
   * already says at full size.
   */
  get stageChip() {
    if (this.jointOwnerCount === 0) return null;
    const total = this.s.verifiableCount || 0;
    if (!total) return null;

    const verified = this.s.verifiedCount || 0;
    if (verified < total) {
      return { cls: "chip", text: fill(LABELS.JO_V_HEAD_COUNT, verified, total) };
    }
    const sent = this.s.complianceSubmittedCount || 0;
    return {
      cls: sent === total ? "chip ow__chip--green" : "chip",
      text:
        sent === total
          ? fill(LABELS.JO_C_HEAD_ALL, total)
          : fill(LABELS.JO_C_HEAD_COUNT, sent, total)
    };
  }

  /* No Add at all past the cut-off - not a disabled one. A control that can never
     work in this state is not an affordance, it is a question the rep has to
     answer. The server's sentence below says what to do instead.

     1.4 - and none at the ceiling either, for the same reason: MODON stores six
     joint owners and the server refuses a seventh, so at zero slots the button
     could only ever produce a refusal. Exactly zero, never a missing value - an
     answer that does not carry the figure must not take the Add away. */
  get canAdd() {
    return (
      this.s.available === true && !this.readOnly && this.s.slotsRemaining !== 0
    );
  }
  /**
   * 1.4 - one Add, in the footer, whether or not anybody is on the booking yet.
   *
   * It used to move: footer while the panel was empty, head once it was not - so the
   * control jumped the first time a rep used it, and wore "Add" in one place and
   * "Add Joint Owner" in the other. The footer is where it belongs, under the people
   * it adds to and beside the sentence that says how many more are allowed.
   */
  get showFootAdd() {
    return this.canAdd;
  }
  /**
   * 1.4 - no longer a button of its own, but still a real question: is there a unit
   * on this basket that co-ownership has left out? It decides where the one Add
   * points, not what it says. Only once somebody is actually co-owning the booking -
   * with no joint owner on it every unit is "without a joint owner", which is not a
   * gap, it is a sole-owned booking.
   */
  get hasGap() {
    return this.canAdd && this.jointOwnerCount > 0 && this.uncovered.length > 0;
  }

  // ── the basket ────────────────────────────────────────────────────────
  get showUnits() {
    return this.isMultiUnit && this.units.length > 0;
  }

  get unitTiles() {
    return this.units.map((u) => {
      let cls = "ow__unit";
      let icon = null;
      let caption;
      if (!u.open) {
        cls += " ow__unit--closed";
        icon = "lock";
        caption = LABELS.JO_UNIT_LOCKED;
      } else if (!u.ownerCount) {
        /* Amber, never red. One child on each of four villas and the fifth kept
           alone is a correct booking, and a correct booking must not be harder to
           enter than a careless one. */
        cls += " ow__unit--empty";
        caption = LABELS.JO_UNIT_NONE;
      } else if (u.ownerCount === 1) {
        caption = fill(LABELS.JO_UNIT_ONE, pct(u.allocatedShare));
      } else {
        caption = fill(LABELS.JO_UNIT_MANY, u.ownerCount, pct(u.allocatedShare));
      }
      if (u.hiddenOwnerCount) {
        const hidden =
          u.hiddenOwnerCount === 1
            ? LABELS.JO_UNIT_HIDDEN_ONE
            : fill(LABELS.JO_UNIT_HIDDEN, u.hiddenOwnerCount);
        caption = `${caption} · ${hidden}`;
      }
      return { key: u.salesOrderId, name: u.unitName, cls, icon, caption };
    });
  }

  // ── the meter ─────────────────────────────────────────────────────────
  get showMeter() {
    return this.parties.length > 0;
  }

  get meter() {
    const parts = [];
    const primary = Number(this.s.primaryShare || 0);
    /* Skipped when it is not positive rather than clamped to zero. A unit whose
       joint owners already hold more than 100% is a real state in the data - the
       figures in the rows still say so, and inventing a sliver of primary here
       would be the one place this panel disagreed with them. */
    if (primary > 0) {
      parts.push({
        key: "primary",
        cls: "ow__seg ow__seg--primary",
        value: primary
      });
    }
    this.jointOwners.forEach((p, i) => {
      const share = Number(p.share || 0);
      if (share <= 0) return;
      parts.push({
        key: p.accountId || `jo-${i}`,
        cls: `ow__seg ${SEGMENTS[Math.min(i, SEGMENTS.length - 1)]}`,
        value: share
      });
    });

    /* Normalised only when the total exceeds 100.
       DEV_1 holds a unit whose rows add up to 180% and another at 5,760% - data
       that predates the guard and that MODON's own trigger would refuse today.
       Laid out raw, those segments run past the end of the bar and the meter reads
       as a broken graphic rather than as a broken record. Scaling keeps the
       PROPORTIONS honest, and the percentages beside every name stay untouched:
       the numbers remain the thing that tells the truth here, not the bar. */
    const total = parts.reduce((sum, x) => sum + x.value, 0);
    const scale = total > 100 ? 100 / total : 1;
    return parts.map((x) => ({
      key: x.key,
      cls: x.cls,
      style: `flex:0 0 ${x.value * scale}%`
    }));
  }

  get jointOwners() {
    return this.parties.filter((p) => !p.isPrimary);
  }
  get primaryParty() {
    return this.parties.find((p) => p.isPrimary);
  }

  /** Colour is never the only signal - the key says the same thing in words. */
  get meterKey() {
    const out = [];
    const primary = this.primaryParty;
    const sole = this.jointOwners.length === 0;
    if (primary) {
      out.push({
        key: "primary",
        cls: "ow__swatch ow__seg--primary",
        text: sole
          ? fill(LABELS.JO_HOLDS, primary.name, pct(this.s.primaryShare))
          : `${shortName(primary.name)} ${pct(this.s.primaryShare)}%`
      });
    }
    this.jointOwners.forEach((p, i) => {
      out.push({
        key: p.accountId || `k-${i}`,
        cls: `ow__swatch ${SEGMENTS[Math.min(i, SEGMENTS.length - 1)]}`,
        text: `${shortName(p.name)} ${pct(p.share)}%`
      });
    });
    return out;
  }

  /** Which unit the meter is describing. Never let a share read as basket-wide. */
  get meterScope() {
    if (!this.isMultiUnit) return null;
    const focused = this.units.find(
      (u) => u.salesOrderId === this.s.focusedSalesOrderId
    );
    return focused ? `· ${focused.unitName}` : null;
  }

  get meterLabel() {
    return this.meterKey.map((k) => k.text).join(", ");
  }

  // ── the people ────────────────────────────────────────────────────────
  get rows() {
    return this.parties.map((p, i) => {
      const share = p.isPrimary ? this.s.primaryShare : p.share;

      const facts = [p.residentStatus, p.nationality].filter(Boolean);
      if (this.isMultiUnit && !p.isPrimary) {
        const names = p.unitNames || [];
        if (p.onAllUnits) {
          facts.push(fill(LABELS.JO_ON_ALL_UNITS, this.units.length));
        } else if (names.length) {
          facts.push(fill(LABELS.JO_ON_UNITS, names.join(", ")));
        }
      }

      /* The primary owner's Ownership % is 100 less the others and is not directly
         settable, so Edit never appears on their row. */
      const holdings = p.holdings || [];
      const editable = holdings.length > 0 && holdings.every((h) => h.editable);
      const canEdit = !p.isPrimary && !this.readOnly && editable;
      /* Locked rather than hidden: "why can't I change them?" is a question the
         screen should answer before it is asked. */
      const locked = !p.isPrimary && !this.readOnly && !editable;

      /* 1.1 - identity verification, per person. Every one of them goes through
         Signzy separately, against their own Account, so both the state and the
         action are read from the party and never from the booking.

         canEdit is passed in because "Add details" opens the EDIT drawer, and that
         save writes the joint owner rows as well as the account. On a row this rep
         cannot edit - a booking that changed hands, or one past the SPA cut-off -
         the write would be refused and the contact details would roll back with it,
         so offering it would be offering a button that undoes itself. */
      const sending =
        p.verificationStatus === "SENDING" ||
        (!!this.sendingAccountId && p.accountId === this.sendingAccountId);
      const status = this.stageState(p, sending);
      const action = this.stageAction(p, sending, p.isPrimary || canEdit);

      return {
        key: p.accountId || `p-${i}`,
        accountId: p.accountId,
        name: p.name,
        role: p.isPrimary
          ? LABELS.JO_ROLE_PRIMARY
          : p.relationshipSubType || p.relationshipType || LABELS.JO_ROLE_JOINT,
        shareText: share === null || share === undefined ? "" : `${pct(share)}%`,
        facts: facts.join(" · "),
        statusText: status.text,
        statusClass: status.cls,
        action,
        /* The reason is printed on the row ONLY when nothing here can act on it -
           a company joint owner, or somebody with no contact record. Where there
           IS an action the button names the fix and the drawer states it in full,
           and a sentence under every row that needs one would bury the panel it is
           meant to help.

           Verification's reason first: it is the earlier stage, so where both are
           set - a company account, which neither route accepts - the sentence the
           rep meets first is the one about where they actually are. Somebody who
           has verified has no verification reason left, so theirs is compliance's. */
        why: action ? null : p.verificationBlockedReason || p.complianceBlockedReason,
        canEdit,
        locked,
        lockTitle: LABELS.JO_ROW_LOCKED
      };
    });
  }

  /**
   * The chip: one word about where this person stands IN THE WHOLE CHAIN.
   *
   * The state words are the console's existing ones - the same booking says "KYC
   * link sent" on the deal tape and in the verification chain, and complianceLabel
   * is the same mapping c/mscCompliance uses directly beneath this panel. It must
   * not invent a third phrasing here for the same fact about the same person.
   *
   * COMPLIANCE IS READ BEFORE VERIFICATION, and that order is the point: everybody
   * who has reached compliance has verified, so testing verification first would
   * stop the chip at "Verified 18 Aug" for the rest of the booking's life and the
   * whole second half of the chain would never show.
   */
  stageState(p, sending) {
    if (sending) {
      return { text: LABELS.JO_V_SENDING, cls: "chip" };
    }
    if (p.complianceSubmitted === true) {
      return {
        /* Passfort's own answer where there is one, the console's own word for
           the wait where there is not. */
        text: complianceLabel(p.complianceStatus) || LABELS.KYC_STEP_SUBMITTED,
        cls: this.complianceChipClass(p.complianceStatus)
      };
    }
    if (p.kycCompletedDate) {
      return {
        text: fill(LABELS.JO_VERIFIED_ON, shortDate(p.kycCompletedDate)),
        cls: "chip ow__chip--green"
      };
    }
    switch (p.verificationStatus) {
      case "VERIFIED":
        /* Verified by KYC_Link_Status__c with no completion date on the record -
           rarer, and still verified. */
        return { text: LABELS.VERIFY_DONE, cls: "chip ow__chip--green" };
      case "SENT":
        return { text: LABELS.VERIFY_TAPE_SENT, cls: "chip ow__chip--blue" };
      case "EXPIRED":
        return { text: LABELS.VERIFY_STATUS_EXPIRED, cls: "chip ow__chip--amber" };
      default:
        /* No status at all means the server could not read that person's account -
           JointOwner__c is Private and a booking that changed hands carries rows
           whose accounts the new owner cannot see. Silence is the honest answer;
           any chip here would be a claim we are not entitled to make. */
        if (!p.verificationStatus) {
          return { text: null, cls: "chip" };
        }
        return p.canEverVerify === false
          ? { text: LABELS.JO_V_NOT_HERE, cls: "chip" }
          : { text: LABELS.JO_VERIFY_NOT_SENT, cls: "chip" };
    }
  }

  /**
   * 1.2 - which of Passfort's answers is good news, in the console's own colours.
   *
   * The words are complianceLabel's; only the colour is decided here, and it is
   * decided on the RAW status so that renaming a label can never change what a
   * colour means. Anything not named is the neutral blue of work in progress -
   * "Applied", "In review" and "Submitted to Operation team" are all somebody
   * else's turn, not a problem for the rep.
   */
  complianceChipClass(raw) {
    if (raw === "Approved") return "chip ow__chip--green";
    if (raw === "Rejected" || raw === "Canceled") return "chip ow__chip--red";
    if (raw === "Requires Resubmission") return "chip ow__chip--amber";
    return "chip ow__chip--blue";
  }

  /**
   * At most one action, and never one that cannot work.
   *
   * Every answer is the server's - canSendVerification, detailsMissing,
   * canCheckCompliance and the reasons - because they depend on fields of an
   * Account this component is not given and should not be reading. What is decided
   * here is only which of them becomes a button.
   *
   * THE ORDER IS THE CHAIN. Compliance is read first for the same reason the chip
   * reads it first: somebody who has reached it has already verified, and testing
   * verification first would leave a verified person with no action for ever.
   */
  stageAction(p, sending, canFix) {
    if (sending) {
      return { kind: "send", text: LABELS.JO_V_SENDING_BTN, disabled: true, title: null };
    }

    /* Already with compliance. Nothing to press - the same rule c/mscCompliance
       keeps for the buyer, whose own button withdraws the moment they are sent.
       The chip carries where they got to. */
    if (p.complianceSubmitted === true) {
      return null;
    }
    if (p.canCheckCompliance === true) {
      /* Not held by a send in flight, unlike the two below: opening a check reads,
         it does not write, and it is a different person's business anyway. */
      return {
        kind: "compliance",
        text: LABELS.JO_C_CHECK,
        disabled: this.busy,
        title: null
      };
    }
    /* Verified, and something the server named is still in the way of compliance.
       The row prints that sentence instead - see `why`. */
    if (p.verificationStatus === "VERIFIED" || p.kycCompletedDate) {
      return null;
    }

    /* One send at a time, across the whole panel. Each one is a real email to a
       real person and the answer takes a moment to come back, so a rep who presses
       three in that moment would start three journeys. */
    const held = !!this.sendingAccountId || this.busy;
    if (p.canSendVerification === true) {
      const again = p.verificationStatus === "SENT" || p.verificationStatus === "EXPIRED";
      return {
        kind: "send",
        text: again ? LABELS.JO_V_RESEND : LABELS.JO_V_SEND,
        disabled: held,
        title: null
      };
    }
    if (p.detailsMissing === true && canFix) {
      return {
        kind: "fix",
        text: LABELS.JO_V_FIX,
        disabled: held,
        /* The full sentence, for anyone who wants it before pressing. The row
           does not print it, because the button already names the fix. */
        title: p.verificationBlockedReason
      };
    }
    return null;
  }

  // ── the footer ────────────────────────────────────────────────────────
  /**
   * Permanent, never a validation that appears on failure. A screen that only
   * speaks up when it thinks something is wrong cannot be trusted when it is
   * silent - and silence is how 36% of multi-unit bookings ended up with a unit
   * nobody co-owns. The sentence itself is the server's.
   */
  get coverage() {
    const line = this.s.coverageLine;
    if (line) {
      return this.uncovered.length > 0
        ? { cls: "ow__cov ow__cov--warn", icon: "alert-triangle", text: line }
        : { cls: "ow__cov ow__cov--ok", icon: "check", text: line };
    }
    if (this.jointOwnerCount === 0) {
      return { cls: "ow__cov", icon: null, text: LABELS.JO_EMPTY };
    }
    /* 1.4 - the slot tally is gone. "5 of 6 joint owner slots remaining" counted
       down a ceiling almost nobody reaches - the median booking has one joint owner
       - so it spent the footer on a number that was never the rep's question, and
       read as a limit being approached when nothing was. At the ceiling the Add is
       simply not offered, which says the same thing without a sentence. A basket
       still gets its coverage line above: that one is about this booking. */
    return null;
  }

  /**
   * The footer reports on the owners, so it says nothing when there are none to
   * report on. Without this a blocked panel - a corporate booking, say - would
   * print "No joint owners have been added" underneath the sentence explaining
   * that joint owners are not added here at all.
   */
  get showFoot() {
    return this.s.available === true;
  }

  /** Something succeeded but is worth saying - a stale SPA, a deferred unit. */
  get noticeText() {
    return this.s.warning || this.s.deferred || null;
  }

  // ── out ───────────────────────────────────────────────────────────────
  /**
   * 1.4 - one button, one label, and the units it opens on chosen by the state of the
   * basket. Where a unit has been left without a joint owner the drawer opens on
   * those units instead of all of them - which is what the separate "Add to the N
   * without a joint owner" button did, minus a second control and a second wording
   * for the same act. The drawer shows what it preselected and the rep can change it.
   */
  handleAdd() {
    this.dispatchEvent(new CustomEvent(this.hasGap ? "addtouncovered" : "addowner"));
  }

  handleEdit(event) {
    const accountId = event.currentTarget.dataset.account;
    if (!accountId) return;
    this.dispatchEvent(new CustomEvent("editowner", { detail: { accountId } }));
  }

  /**
   * 1.2 - one button, three meanings, and the row already knows which.
   *
   * The page routes from here: sending the buyer's link is the same call the
   * verification chain below makes, collecting a joint owner's details is the edit
   * drawer, and a compliance check is the panel mscBookingPage already owns -
   * none of which is this component's business to know.
   */
  handleVerifyAction(event) {
    const accountId = event.currentTarget.dataset.account;
    const kind = event.currentTarget.dataset.kind;
    if (!accountId) return;
    const name =
      kind === "fix"
        ? "fixdetails"
        : kind === "compliance"
          ? "checkcompliance"
          : "sendverification";
    this.dispatchEvent(new CustomEvent(name, { detail: { accountId } }));
  }
}