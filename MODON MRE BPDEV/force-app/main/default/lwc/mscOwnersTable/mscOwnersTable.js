/**
 * Who owns this booking, and how much of it.
 *
 * Version  Author      Date         Detail
 * 1.2      Aurelix Dev 30 Sep 2026  No dash as a blank share or unit (UI-21).
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-226. Columns fitted to the immersive sheet (css only):
 *                                   shares of the width instead of fixed px, so the surplus
 *                                   no longer lands on Owner alone. Phone layout untouched.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-088.
 *
 * The ownership record only (verification lives in c/mscVerifyList). One fact per column, no
 * buttons on a row (the row is the control). It decides nothing: HoldingDTO.editable is the
 * server's answer.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/** The meter's joint-owner colours, in order. */
const SEGMENTS = ["ot__seg--1", "ot__seg--2", "ot__seg--3"];
/* 1.2 - UI-21: an empty cell, not a dash */
const DASH = "";

function fill(template, ...values) {
  let out = template;
  values.forEach((v, i) => {
    out = out.replace(`{${i}}`, String(v));
  });
  return out;
}

/** 20, not 20.00. */
function pct(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const n = Number(value);
  if (isNaN(n)) {
    return null;
  }
  return Math.round(n * 100) / 100;
}

/** Two words for a legend. */
function shortName(name) {
  if (!name) {
    return "";
  }
  const words = String(name).trim().split(/\s+/);
  return words.length <= 2 ? name : words.slice(0, 2).join(" ");
}

export default class MscOwnersTable extends LightningElement {
  /** One OwnersDTO. */
  @api state;
  /** A write is in flight on the host. */
  @api busy = false;

  labels = LABELS;

  get s() {
    return this.state || {};
  }
  get parties() {
    return this.s.parties || [];
  }
  get units() {
    return this.s.units || [];
  }
  get readOnly() {
    return this.s.readOnly === true;
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
  get showRecord() {
    return this.s.available === true && this.parties.length > 0;
  }

  // the head
  /** Allocated and units, always both. */
  get headChip() {
    const allocated = pct(this.allocatedTotal);
    const unitCount = this.units.length;
    const parts = [];
    if (allocated !== null) {
      parts.push(fill(LABELS.OT_ALLOCATED, allocated));
    }
    if (unitCount > 0) {
      parts.push(
        unitCount === 1
          ? LABELS.OT_UNIT_ONE
          : fill(LABELS.OT_UNIT_MANY, unitCount)
      );
    }
    return parts.length ? parts.join(" · ") : null;
  }

  /** Summed rather than assumed: rows that disagree should say so. */
  get allocatedTotal() {
    let total = Number(this.s.primaryShare) || 0;
    this.parties.forEach((p) => {
      if (!p.isPrimary) {
        total += Number(p.share) || 0;
      }
    });
    return total;
  }

  // the meter
  get primaryParty() {
    return this.parties.find((p) => p.isPrimary);
  }
  get jointOwners() {
    return this.parties.filter((p) => !p.isPrimary);
  }

  get meterSegments() {
    const out = [];
    const primary = this.primaryParty;
    if (primary) {
      const share = pct(this.s.primaryShare) || 0;
      out.push({
        key: "primary",
        cls: "ot__seg ot__seg--primary",
        style: `width:${Math.max(0, Math.min(100, share))}%`
      });
    }
    this.jointOwners.forEach((p, i) => {
      const share = pct(p.share) || 0;
      out.push({
        key: p.accountId || `s-${i}`,
        cls: `ot__seg ${SEGMENTS[i % SEGMENTS.length]}`,
        style: `width:${Math.max(0, Math.min(100, share))}%`
      });
    });
    return out;
  }

  /** Colour is never the only signal. */
  get meterKey() {
    const out = [];
    const primary = this.primaryParty;
    if (primary) {
      out.push({
        key: "primary",
        cls: "ot__swatch ot__seg--primary",
        name: shortName(primary.name),
        share: `${pct(this.s.primaryShare)}%`
      });
    }
    this.jointOwners.forEach((p, i) => {
      out.push({
        key: p.accountId || `k-${i}`,
        cls: `ot__swatch ${SEGMENTS[i % SEGMENTS.length]}`,
        name: shortName(p.name),
        share: `${pct(p.share)}%`
      });
    });
    return out;
  }

  get meterLabel() {
    return this.meterKey.map((k) => `${k.name} ${k.share}`).join(", ");
  }

  // the rows
  get unitColumnLabel() {
    return this.isMultiUnit ? LABELS.OT_COL_UNITS : LABELS.OT_COL_UNIT;
  }

  get rows() {
    return this.parties.map((p, i) => {
      const share = p.isPrimary ? this.s.primaryShare : p.share;
      const shareValue = pct(share);

      /* whether this row opens is the server's answer; updateOwner refuses on the same rule */
      const canOpen = p.canEdit === true && !this.busy;

      return {
        key: p.accountId || `p-${i}`,
        accountId: p.accountId,
        name: p.name,
        role: p.isPrimary
          ? LABELS.JO_ROLE_PRIMARY
          : p.relationshipSubType || p.relationshipType || LABELS.JO_ROLE_JOINT,
        residency: this.residencyOf(p),
        unitText: this.unitsOf(p),
        shareText: shareValue === null ? DASH : `${shareValue}%`,
        canOpen,
        rowClass: canOpen ? "ot__row ot__row--open" : "ot__row",
        openLabel: fill(LABELS.OT_OPEN, p.name || ""),
        /* locked rather than hidden, with the server's sentence; not while the whole booking is closed */
        lockTitle: p.editBlockedReason || LABELS.JO_ROW_LOCKED,
        showLock:
          !p.isPrimary && !this.readOnly && p.canEdit !== true
      };
    });
  }

  residencyOf(p) {
    const parts = [p.residentStatus, p.nationality].filter(Boolean);
    return parts.length ? parts.join(" · ") : LABELS.OT_NOT_RECORDED;
  }

  /** Which units this person holds. */
  unitsOf(p) {
    const all = this.units;
    if (!all.length) {
      return DASH;
    }
    if (p.isPrimary || p.onAllUnits === true) {
      return all.length === 1
        ? all[0].unitName
        : fill(LABELS.OT_ALL_UNITS, all.length);
    }
    const names = p.unitNames || [];
    return names.length ? names.join(", ") : DASH;
  }

  // the foot
  /** The server's own coverage sentence. */
  get coverageLine() {
    return this.s.coverageLine || null;
  }
  /** No Add past the cut-off or at the ceiling. */
  get canAdd() {
    return (
      this.s.available === true && !this.readOnly && this.s.slotsRemaining !== 0
    );
  }
  get showFoot() {
    return this.s.available === true && (this.canAdd || !!this.coverageLine);
  }

  // out
  /** The drawer opens on the units left without a joint owner, once co-ownership has started. */
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

  /** The row is the control; it asks the row's own canOpen (the primary owner's row carries no chevron). */
  handleOpen(event) {
    const accountId = event.currentTarget.dataset.account;
    if (!accountId || this.busy) {
      return;
    }
    const row = this.rows.find((r) => r.accountId === accountId);
    if (!row || !row.canOpen) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("editowner", { detail: { accountId } })
    );
  }
}