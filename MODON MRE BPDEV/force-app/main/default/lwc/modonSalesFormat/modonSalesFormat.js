/**
 * Shared pure helpers for the Modon Sales Console.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

/**
 * Shared pure helpers for the Modon Sales Console.
 *
 * Shadow DOM stops components sharing CSS, but JS modules import fine, so the
 * formatting helpers live here once instead of being copy-pasted. JS only, no template.
 *
 * Two PoC exports are deliberately gone: PROJECT (that org had one project; this one
 * is multi-project) and unitTourUrl() (hardcoded one floorplan viewer; real units
 * carry their own URL fields).
 */

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

/**
 * "AED 8,400,000.00" - the full form used in tables and detail rows.
 *
 * ALWAYS two decimals, never "as many as the number happens to have".
 * toLocaleString's default gave 367550.8 -> "367,550.8" and 163494.52 ->
 * "163,494.52", so a settlement panel showed one decimal directly above two and a
 * column of figures could not be read down its decimal point. Money is a fixed
 * scale; a formatter that varies it is not formatting, it is echoing.
 */
export function formatAED(v) {
  if (v == null) {
    return "-";
  }
  return (
    "AED " +
    Number(v).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  );
}

/** "AED 4.2M" / "AED 850K" - the compact form used in the summary rail. */
export function formatAEDShort(v) {
  if (v == null) {
    return "-";
  }
  const n = Number(v);
  if (n >= 1000000) {
    return "AED " + (n / 1000000).toFixed(1) + "M";
  }
  if (n >= 1000) {
    return "AED " + Math.round(n / 1000) + "K";
  }
  return "AED " + n.toLocaleString("en-US");
}

/**
 * "25 Jul 2026". Read in UTC deliberately: Apex Date fields serialise as
 * midnight UTC, and using local getters shifts them a day west of Greenwich.
 */
export function formatDate(v) {
  if (!v) {
    return "-";
  }
  const d = new Date(v);
  if (isNaN(d.getTime())) {
    return v;
  }
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

/**
 * "16:12" from a Datetime. LOCAL, unlike formatDate above - a Datetime is a real
 * instant rather than a calendar day, and a hold expiring at 16:12 for the agent
 * watching the clock must not be rendered in UTC.
 */
export function formatTime(v) {
  if (!v) {
    return "-";
  }
  const d = new Date(v);
  if (isNaN(d.getTime())) {
    return "-";
  }
  const hh = `${d.getHours()}`.padStart(2, "0");
  const mm = `${d.getMinutes()}`.padStart(2, "0");
  return `${hh}:${mm}`;
}

/** Date -> "YYYY-MM-DD", the only shape Apex will deserialise into a Date field. */
export function toApexDate(v) {
  if (!v) {
    return null;
  }
  const d = v instanceof Date ? v : new Date(v);
  if (isNaN(d.getTime())) {
    return null;
  }
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}-${m}-${day}`;
}

/** Pull a human message out of whatever shape the platform threw. */
export function reduceError(e) {
  return (
    (e && e.body && e.body.message) ||
    (e && e.message) ||
    "Something went wrong."
  );
}

/** "Layla Al Zaabi" -> "LA". Falls back to a single char, then to "?". */
export function initials(name) {
  const parts = String(name || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (!parts.length) {
    return "?";
  }
  if (parts.length === 1) {
    return parts[0].charAt(0).toUpperCase();
  }
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

/** Percentage of a total, guarding the divide-by-zero that an unpriced unit gives. */
export function pctOf(part, total) {
  const t = Number(total);
  if (!t) {
    return 0;
  }
  return Math.round((Number(part || 0) / t) * 100);
}

/**
 * Status -> chip modifier class. Substring order matters: "Not Paid" contains "paid",
 * so the negative test runs first. Reversing these branches paints every unpaid
 * milestone green.
 */
/**
 * The world.modon.com walkthrough for a unit, derived from its name.
 *
 * Ported from the PoC, where every unit got a tour because the org held nothing
 * but Hudayriyat Golf Estates stock and this URL is hardcoded to that zone and
 * villa type. BPDev holds 1,423 units across ten projects, so the derivation is
 * guarded: it is correct for Golf Estates and would show a Golf Estates villa
 * floorplan for a Nawayef apartment, which is worse than showing nothing.
 *
 * The guard costs almost nothing here - 1,103 of the 1,110 currently sellable
 * units are Golf Estates and match this naming.
 *
 * Preferred source is still Unit__c.Masterplan_URL__c, written per unit by
 * MBP_MasterplanSyncBatch from Oracle. This is the fallback for the units that
 * batch has not reached, which today is all but one of them.
 *
 * Requires the World_Modon CSP Trusted Site with isApplicableToFrameSrc.
 */
export function unitTourUrl(unitName) {
  const name = String(unitName || "");
  if (name.indexOf("GolfEstate-") !== 0) {
    return null;
  }
  const code = name.replace("GolfEstate-", "").replace("-", "_");
  if (!code) {
    return null;
  }
  return (
    "https://world.modon.com/abu-dhabi/hudayriyat/?zone=hudayriyat-golf-estates" +
    `&unit=HW_GE_${code}&floor=GF&type=second_row_villa&opt=00` +
    "&state=floorplan_hudayriyat-golf-estates"
  );
}

export function statusChip(status) {
  const s = String(status || "").toLowerCase();
  if (!s) {
    return "chip chip--pending";
  }
  if (s.indexOf("not paid") !== -1 || s.indexOf("pending") !== -1) {
    return "chip chip--pending";
  }
  if (s.indexOf("cancel") !== -1 || s.indexOf("reject") !== -1 || s.indexOf("expired") !== -1) {
    return "chip chip--alert";
  }
  if (s.indexOf("partial") !== -1) {
    return "chip chip--partial";
  }
  if (
    s.indexOf("paid") !== -1 ||
    s.indexOf("received") !== -1 ||
    s.indexOf("collected") !== -1 ||
    s.indexOf("cleared") !== -1
  ) {
    return "chip chip--paid";
  }
  if (s.indexOf("due") !== -1 || s.indexOf("await") !== -1) {
    return "chip chip--due";
  }

  /* Lead statuses. Deliberately last, so a payment status can never fall
     through into a lead colour, and deliberately narrow: only terms no
     SalesOrder__c or installment status contains. This org's Lead picklist is
     New, In Progress, Lead Qualified, Open - Not Contacted, Duplicate, Retired,
     Qualified and Expression of Interest - before this, every one of them
     reached the fallback below and the whole list rendered one colour.
     chip--qualified and chip--closed live in mscLeadList.css; the panes that do
     not define them never produce these strings. */
  if (s.indexOf("qualified") !== -1) {
    return "chip chip--qualified";
  }
  if (s.indexOf("retired") !== -1 || s.indexOf("duplicate") !== -1) {
    return "chip chip--closed";
  }

  return "chip chip--pending";
}