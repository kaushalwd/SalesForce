/**
 * Modon Sales Console - EOI journey helpers.
 *
 * Version  Author      Date         Detail
 * 1.4      Aurelix Dev 27 Sep 2026  MODON's Lead rules (27 Sep: Sales App parity; AurelixIdentityRuleService
 *                                   1.2). identityNeedsFor adds *Required flags beside the shown ones: only a
 *                                   Non-Resident's passport number is owed. identitySetComplete owes only those
 *                                   and checks an entered value's shape and date; an expiry of today is
 *                                   accepted, as MODON's "< TODAY()" rules accept it.
 * 1.3      Aurelix Dev 27 Sep 2026  identitySetComplete: a blank passport expiry no longer makes the set
 *                                   incomplete (business confirmed, 27 Sep 2026); an entered one must
 *                                   still be after today. Mirrors AurelixIdentityRuleService 1.1 and
 *                                   SalesConsoleLeadController 1.29. The field is still shown.
 * 1.2      Aurelix Dev 17 Sep 2026  MSC-174 (B2). identityNeedsFor: a Resident now needs the
 *                                   passport three as well as the Emirates ID pair (decision of
 *                                   17 Sep; the server table is AurelixIdentityRuleService.needsFor,
 *                                   which SalesConsoleLeadController delegates to). Without this
 *                                   the form would never show a resident the passport fields the
 *                                   server refuses without. identitySetComplete and the three
 *                                   consumers (c/mscConsole, c/mscIdentityFields, c/mscLeadList)
 *                                   follow with no edit of their own.
 * 1.1      Aurelix Dev 22 Aug 2026  MSC-110. Two additive exports, nothing existing changed.
 *                                   applyEmiratesIdMask - the caret-aware in-place mask that
 *                                   lived privately in c/mscConsole since 2.7, moved here
 *                                   verbatim because four inputs now want it (the console's
 *                                   search and create form, the identity step, and My Leads'
 *                                   New lead) and a second hand-copy is how the same ID ends
 *                                   up stored in two shapes - the exact duplicate the mask
 *                                   exists to prevent. Output is byte-identical to
 *                                   formatEmiratesId below, checked group by group.
 *                                   isPlainName - the Block_Special_Characters_In_Name
 *                                   regex, mirrored once so every form refuses at the field
 *                                   what the org would refuse after the round trip.
 * 1.0      Aurelix IT  17 Aug 2026  Initial. Pure functions ported from c/eoiHomeJourney so
 *                                   the console journey and the home-page journey share one
 *                                   set of rules for identifiers, requests and the range
 *                                   cascade. No DOM, no Apex, no component state.
 */

import { formatAED } from "c/modonSalesFormat";

/* ── Constants ─────────────────────────────────────────────────────────────── */

export const PHONE_REGEX = /^\+[0-9]{6,15}$/;
export const EMIRATES_ID_REGEX = /^[0-9]{3}-[0-9]{4}-[0-9]{7}-[0-9]{1}$/;
export const PASSPORT_REGEX = /^[A-Za-z0-9]+$/;
export const OTP_LENGTH = 6;
export const VERIFICATION_CONTEXT = "EOI_HOME";

export const CUSTOMER_TYPES = [
  { label: "Individual", value: "Individual" },
  { label: "Organisation", value: "Organization" }
];

export const RESIDENT_OPTIONS = [
  { label: "Resident", value: "Resident" },
  { label: "Non-Resident", value: "Non-Resident" }
];

/** Offline types create the EOI at once; Online routes through Checkout (EOI on capture). */
export const PAYMENT_TYPES = [
  { label: "Cheque", value: "Cheque" },
  { label: "POS", value: "POS" },
  { label: "Bank Transfer", value: "Bank Transfer" },
  { label: "Online", value: "Online" }
];

/* ── Value normalisers ─────────────────────────────────────────────────────── */

export function formatEmiratesId(value) {
  const digits = (value || "").replace(/\D/g, "").substring(0, 15);
  const parts = [];
  if (digits.length > 0) parts.push(digits.substring(0, 3));
  if (digits.length > 3) parts.push(digits.substring(3, 7));
  if (digits.length > 7) parts.push(digits.substring(7, 14));
  if (digits.length > 14) parts.push(digits.substring(14, 15));
  return parts.join("-");
}

export function sanitizePassportNumber(value) {
  return (value || "").replace(/[^a-zA-Z0-9]/g, "");
}

/*** 1.1  Start - the Emirates ID types itself, shared *************************
 *
 * WHY THIS IS NOT COSMETIC. findByIdentity matches EXACTLY:
 *
 *     WHERE EIDNumber__pc = :doc
 *
 * so "784199277100429" and "784-1992-7710042-9" are two different customers as
 * far as the search is concerned. Formatting as the rep types makes the stored
 * value and the searched value the same shape by construction - on every field
 * that captures one, which is why this lives here and not in one component.
 *
 * 3-4-7-1: the issuing authority (always 784), the year of birth, the serial,
 * and the check digit. 15 digits, fixed - which is what makes this safe to do
 * while the rep is still typing.
 */

/**
 * Where the caret belongs after reformatting, counted in DIGITS rather than
 * characters. Without this the caret jumps to the end on every keystroke, which
 * makes correcting a digit in the middle impossible - the one thing a rep does
 * when the customer says "no, it's a 7".
 */
function caretAfterDigits(formatted, digitCount) {
  if (digitCount <= 0) return 0;
  let seen = 0;
  for (let i = 0; i < formatted.length; i += 1) {
    if (formatted[i] >= "0" && formatted[i] <= "9") {
      seen += 1;
      if (seen === digitCount) return i + 1;
    }
  }
  return formatted.length;
}

function digitsBeforeCaret(value, caret) {
  return String(value || "")
    .slice(0, caret === null || caret === undefined ? 0 : caret)
    .replace(/\D/g, "").length;
}

/**
 * Reformats an Emirates ID input IN PLACE and returns what to store.
 *
 * The DOM write is NOT redundant. If the rep types something the mask strips - a
 * letter, a second dash - the stored value does not change, so LWC re-renders
 * nothing and the rejected character would sit on screen. Writing the element's
 * value here is what keeps the field and the state showing the same thing.
 */
export function applyEmiratesIdMask(input) {
  const raw = input.value;
  const wanted = digitsBeforeCaret(raw, input.selectionStart);
  const formatted = formatEmiratesId(raw);
  input.value = formatted;
  const caret = caretAfterDigits(formatted, wanted);
  /* Guarded: setSelectionRange throws on an input type that does not support
     selection, and this runs on a field whose type is set by the caller. */
  try {
    input.setSelectionRange(caret, caret);
  } catch (e) {
    /* Selection is a nicety; the value is the part that matters. */
  }
  return formatted;
}

/**
 * 1.1 - one name, as Block_Special_Characters_In_Name sees it: Arabic ranges,
 * A-Za-z and whitespace only. The RULE is an AND of two failures - it fires only
 * when first AND last both fail - so callers mirroring it must combine two calls
 * with &&, never refuse on one alone: "Ahmed / Al-Maktoum" passes the org,
 * "Al-Amin / Al-Maktoum" does not.
 */
/* Escapes, not literal Arabic characters: an RTL range inside a source file is
   one careless editor save away from being reordered. Same three blocks the rule
   names - Arabic, Arabic Supplement, Arabic Extended-A. */
const PLAIN_NAME_REGEX = /^[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF A-Za-z\s]+$/;

export function isPlainName(value) {
  return PLAIN_NAME_REGEX.test(value || "");
}

/**
 * 1.1 - the identity set a residency requires, and whether a set of values
 * satisfies it. THE CLIENT MIRROR of SalesConsoleLeadController.identityNeedsFor
 * and its date rules - one definition on each side of the wire, both commented at
 * the other. The server's copy is the gate (createLeadFull throws); this one is
 * why the button was already disabled before the gate could.
 *
 * 1.2 - MSC-174 (B2), the table decided on 17 Sep 2026 (build brief, section 3):
 * Resident: Emirates ID + expiry (Emirates_ID_Mandatory_Validation,
 * Emirates_Id_ExpiryDate_Validation) AND passport + issue + expiry. Non-Resident:
 * passport + issue + expiry only (Passport_Number_Mandatory_Validation,
 * Passport_IssueDate_Mandatory_Validation, Passport_ExpiryDate_Mandatory_Validation).
 * A non-resident is never asked for an Emirates ID. Blank residency requires
 * nothing yet - residency is asked first. The server's copy of this table is
 * AurelixIdentityRuleService.needsFor.
 */
export function identityNeedsFor(residentStatus) {
  const norm = normalizeResidentStatus(residentStatus || "");
  const resident = norm === "Resident" && !!residentStatus;
  const nonResident = norm === "Non-Resident";
  const passport = resident || nonResident;
  return {
    /* shown */
    eidNumber: resident,
    eidExpiry: resident,
    passportNumber: passport,
    passportIssueDate: passport,
    passportExpiryDate: passport,
    /* 1.4 - owed, as MODON's active Lead rules owe them */
    eidNumberRequired: false,
    eidExpiryRequired: false,
    passportNumberRequired: nonResident,
    passportIssueDateRequired: false,
    passportExpiryDateRequired: false
  };
}

/** Local calendar date as YYYY-MM-DD. NOT toISOString, which is UTC: in the UAE
 *  (UTC+4) an evening booking would call tomorrow "today" and accept an expiry
 *  the org refuses at midnight. */
export function localISODate(offsetDays) {
  const d = new Date();
  d.setDate(d.getDate() + (offsetDays || 0));
  const p = (x) => String(x).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/**
 * Every field the residency requires is present and in a shape the org accepts:
 * a full 784-XXXX-XXXXXXX-X Emirates ID (Emirates_Id_Number_Format), letters and
 * digits only for a passport (Passport_Number_Format_Check), expiries strictly in
 * the future (EID_ExpiryDate_Cannot_be_Past, Passport_Expir_Date_Should_not_be_
 * Past) and an issue date on or before today (Passport_Issue_Date_Should_not_be_
 * Future).
 *
 * `locked` marks values that came off a record the org already holds; they are
 * taken AS THEY ARE - present is enough - because a legacy Emirates ID stored
 * without dashes must not block the booking it identifies. Same rule the console
 * applies to a matched account's email.
 */
export function identitySetComplete(residentStatus, values, locked) {
  const needs = identityNeedsFor(residentStatus);
  const v = values || {};
  const lock = locked || {};
  const str = (x) => (x === null || x === undefined ? "" : String(x).trim());
  const today = localISODate(0);

  /* 1.4 - blank is refused only where owed; an entered value is checked as MODON checks it */
  if (needs.eidNumber) {
    const eid = str(v.eidNumber);
    if (!eid && needs.eidNumberRequired) return false;
    if (eid && !lock.eidNumber && !EMIRATES_ID_REGEX.test(eid)) return false;
  }
  if (needs.eidExpiry) {
    const d = str(v.eidExpiry);
    if (!d && needs.eidExpiryRequired) return false;
    if (d && !lock.eidExpiry && d < today) return false;
  }
  if (needs.passportNumber) {
    const pass = str(v.passportNumber);
    if (!pass && needs.passportNumberRequired) return false;
    if (pass && !lock.passportNumber && !PASSPORT_REGEX.test(pass)) return false;
  }
  if (needs.passportIssueDate) {
    const d = str(v.passportIssueDate);
    if (!d && needs.passportIssueDateRequired) return false;
    if (d && !lock.passportIssueDate && d > today) return false;
  }
  if (needs.passportExpiryDate) {
    const d = str(v.passportExpiryDate);
    if (!d && needs.passportExpiryDateRequired) return false;
    if (d && !lock.passportExpiryDate && d < today) return false;
  }
  return true;
}
/*** 1.1  End ******************/

export function isValidEmiratesId(value) {
  return EMIRATES_ID_REGEX.test(value || "");
}

export function isValidPhone(value) {
  return PHONE_REGEX.test((value || "").trim());
}

export function isValidEmailShape(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((value || "").trim());
}

export function normalizeResidentStatus(value) {
  const normalized = (value || "").trim().toLowerCase().replace(/[\s_]+/g, "-");
  if (normalized === "non-resident" || normalized === "nonresident") return "Non-Resident";
  if (normalized === "resident") return "Resident";
  return value || "Resident";
}

export function isDateField(field) {
  return field === "tradeLicenseExpiryDate" || field === "emiratesIdExpiryDate" || field === "passportExpiryDate";
}

export function normalizeDateValue(value) {
  if (!value) return null;
  const normalized = String(value).trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(normalized) ? normalized : null;
}

/** A search hit rendered "-" for empty; anything that came back that way is empty. */
export function clean(value) {
  if (value === null || value === undefined) return "";
  const text = String(value).trim();
  return text === "-" ? "" : text;
}

export function maskPhone(value) {
  const digits = (value || "").replace(/\D/g, "");
  return digits.length >= 4 ? digits.slice(-4) : digits;
}

export function maskEmail(value) {
  const email = value || "";
  const [name, domain] = email.split("@");
  if (!domain) return email;
  const shown = name.slice(0, Math.min(2, name.length));
  return `${shown}${"•".repeat(Math.max(2, name.length - shown.length))}@${domain}`;
}

/* ── Empty state factories ─────────────────────────────────────────────────── */

export function emptyCustomer(customerType = "Individual") {
  return {
    accountId: null,
    leadId: null,
    contactId: null,
    customerType,
    firstName: "",
    lastName: "",
    email: "",
    phone: "",
    residentStatus: "Resident",
    nationality: "",
    countryOfResidence: "",
    emiratesId: "",
    emiratesIdExpiryDate: "",
    passportNumber: "",
    passportExpiryDate: "",
    companyName: "",
    tradeLicenseNumber: "",
    tradeLicenseExpiryDate: "",
    registeredEmail: "",
    registeredPhone: "",
    authorizedFirstName: "",
    authorizedLastName: "",
    authorizedEmail: "",
    authorizedPhone: ""
  };
}

export function emptyLookup() {
  return {
    emiratesId: "",
    passportNumber: "",
    phone: "",
    email: "",
    companyName: "",
    tradeLicenseNumber: "",
    registeredEmail: "",
    registeredPhone: ""
  };
}

/* ── Identity requests ─────────────────────────────────────────────────────── */

export function hasLookupIdentifier(lookup, isOrg) {
  const l = lookup || {};
  return Boolean(
    isOrg
      ? (l.companyName || "").trim() || (l.tradeLicenseNumber || "").trim() || (l.registeredPhone || "").trim() || (l.registeredEmail || "").trim()
      : (l.emiratesId || "").trim() || (l.passportNumber || "").trim() || (l.phone || "").trim() || (l.email || "").trim()
  );
}

/** Mirrors eoiHomeJourney.buildCustomerSearchRequest. */
export function buildSearchRequest(customer, lookup, isOrg) {
  const c = customer || emptyCustomer();
  const l = lookup || emptyLookup();
  const request = isOrg
    ? {
        ...c,
        companyName: l.companyName,
        tradeLicenseNumber: l.tradeLicenseNumber,
        registeredEmail: l.registeredEmail,
        registeredPhone: l.registeredPhone,
        email: l.registeredEmail,
        phone: l.registeredPhone,
        requestId: String(Date.now())
      }
    : {
        ...c,
        email: l.email,
        phone: l.phone,
        emiratesId: formatEmiratesId(l.emiratesId),
        passportNumber: sanitizePassportNumber(l.passportNumber),
        requestId: String(Date.now())
      };
  request.email = (request.email || "").trim();
  request.phone = (request.phone || "").trim();
  request.passportNumber = sanitizePassportNumber(request.passportNumber);
  request.emiratesId = formatEmiratesId(request.emiratesId || "").trim();
  request.companyName = (request.companyName || "").trim();
  request.tradeLicenseNumber = (request.tradeLicenseNumber || "").trim();
  request.tradeLicenseExpiryDate = normalizeDateValue(request.tradeLicenseExpiryDate);
  request.emiratesIdExpiryDate = isOrg ? null : normalizeDateValue(request.emiratesIdExpiryDate);
  request.passportExpiryDate = isOrg ? null : normalizeDateValue(request.passportExpiryDate);
  request.registeredEmail = (request.registeredEmail || "").trim();
  request.registeredPhone = (request.registeredPhone || "").trim();
  return request;
}

/** Mirrors eoiHomeJourney.buildPrepareCustomerRequest. */
export function buildPrepareRequest(customer, projectId, projectName, isOrg, showEmiratesId) {
  const c = customer || emptyCustomer();
  const request = { ...c, projectId: projectId || null, projectInterest: projectName || "" };
  if (isOrg) {
    request.email = c.authorizedEmail || c.email || "";
    request.phone = c.authorizedPhone || c.phone || "";
    request.firstName = c.authorizedFirstName || c.firstName || "";
    request.lastName = c.authorizedLastName || c.lastName || "";
  }
  request.passportNumber = sanitizePassportNumber(request.passportNumber);
  request.passportExpiryDate = normalizeDateValue(request.passportExpiryDate);
  request.emiratesIdExpiryDate = showEmiratesId ? normalizeDateValue(request.emiratesIdExpiryDate) : null;
  if (!showEmiratesId) request.emiratesId = "";
  request.tradeLicenseExpiryDate = normalizeDateValue(request.tradeLicenseExpiryDate);
  return request;
}

/** Whether a prepare request carries enough to be worth a final duplicate check. */
export function hasPrepareIdentifier(request, isOrg) {
  const r = request || {};
  return Boolean(
    isOrg
      ? (r.companyName || "").trim() || (r.tradeLicenseNumber || "").trim() || (r.registeredEmail || "").trim() || (r.registeredPhone || "").trim() || (r.authorizedEmail || "").trim() || (r.authorizedPhone || "").trim()
      : (r.email || "").trim() || (r.phone || "").trim() || (r.emiratesId || "").trim() || (r.passportNumber || "").trim()
  );
}

/* ── Matches ───────────────────────────────────────────────────────────────── */

/**
 * A search hit shaped for the match cards. `raw` keeps the untouched server match so
 * applying a card never sees the "-" placeholders the display copies use.
 */
export function toDisplayMatch(match) {
  const isOrganization = match.accountType === "Organization";
  const displayFields = isOrganization
    ? [
        { key: "company", label: "Company", value: match.companyName || match.name || "-" },
        { key: "tradeLicense", label: "Trade licence", value: match.tradeLicenseNumber || "-" },
        { key: "email", label: "Email", value: match.email || "-" },
        { key: "phone", label: "Phone", value: match.phone || "-" }
      ]
    : [
        { key: "email", label: "Email", value: match.email || "-" },
        { key: "phone", label: "Phone", value: match.phone || "-" },
        { key: "passport", label: "Passport", value: match.passportNumber || "-" },
        { key: "emiratesId", label: "Emirates ID", value: match.emiratesId || "-" },
        { key: "residentStatus", label: "Residency", value: match.residentStatus ? normalizeResidentStatus(match.residentStatus) : "-" }
      ];
  return {
    raw: match,
    recordId: match.recordId,
    sourceType: match.sourceType,
    accountType: match.accountType,
    isOrganization,
    hasPortalUser: Boolean(match.hasPortalUser),
    displayName: match.name || [match.firstName, match.lastName].filter(Boolean).join(" ") || match.recordId,
    accountTypeLabel: isOrganization ? "Organisation account" : "Person account",
    portalLabel: match.hasPortalUser ? "Portal user" : "No portal user",
    displayFields
  };
}

/** Which fields an existing Account has already filled in - those stay read-only. */
export function buildLockedFields(match, isOrg) {
  const has = (value) => Boolean(clean(value));
  const m = match || {};
  if (isOrg) {
    return {
      companyName: has(m.companyName || m.name),
      tradeLicenseNumber: has(m.tradeLicenseNumber),
      registeredEmail: has(m.email),
      registeredPhone: has(m.phone),
      emiratesId: has(m.emiratesId),
      passportNumber: has(m.passportNumber),
      authorizedFirstName: has(m.firstName),
      authorizedLastName: has(m.lastName),
      authorizedEmail: has(m.email),
      authorizedPhone: has(m.phone)
    };
  }
  return {
    firstName: has(m.firstName),
    lastName: has(m.lastName),
    email: has(m.email),
    phone: has(m.phone),
    emiratesId: has(m.emiratesId),
    passportNumber: has(m.passportNumber),
    nationality: has(m.nationality),
    countryOfResidence: has(m.countryOfResidence)
  };
}

/**
 * Port of eoiHomeJourney.applySelectedCustomerMatch, with the placeholder bug fixed:
 * "-" is treated as empty for individuals as well as organisations.
 */
export function applyMatchToCustomer(current, match) {
  const c = current || emptyCustomer();
  const m = match || {};
  const isOrg = m.accountType === "Organization";
  const email = clean(m.email);
  const phone = clean(m.phone);
  if (isOrg) {
    return {
      ...c,
      customerType: "Organization",
      accountId: m.accountId || null,
      leadId: m.leadId || null,
      contactId: m.contactId || null,
      companyName: clean(m.companyName) || clean(m.name) || c.companyName || "",
      tradeLicenseNumber: clean(m.tradeLicenseNumber) || c.tradeLicenseNumber || "",
      registeredEmail: email || c.registeredEmail || "",
      registeredPhone: phone || c.registeredPhone || "",
      authorizedFirstName: clean(m.firstName) || c.authorizedFirstName || "",
      authorizedLastName: clean(m.lastName) || c.authorizedLastName || "",
      authorizedEmail: email || c.authorizedEmail || "",
      authorizedPhone: phone || c.authorizedPhone || "",
      email: email || c.authorizedEmail || c.email || "",
      phone: phone || c.authorizedPhone || c.phone || ""
    };
  }
  return {
    ...emptyCustomer("Individual"),
    accountId: m.accountId || null,
    leadId: m.leadId || null,
    contactId: m.contactId || null,
    firstName: clean(m.firstName),
    lastName: clean(m.lastName),
    email,
    phone,
    residentStatus: normalizeResidentStatus(clean(m.residentStatus) || c.residentStatus || "Resident"),
    nationality: clean(m.nationality),
    countryOfResidence: clean(m.countryOfResidence),
    emiratesId: formatEmiratesId(clean(m.emiratesId)),
    emiratesIdExpiryDate: m.emiratesIdExpiryDate || "",
    passportNumber: sanitizePassportNumber(clean(m.passportNumber)),
    passportExpiryDate: m.passportExpiryDate || ""
  };
}

/* ── Range matrix cascade ──────────────────────────────────────────────────── */

let selectionCounter = 0;

export function createEmptySelection() {
  selectionCounter += 1;
  return {
    key: `eoi-${Date.now()}-${selectionCounter}`,
    phaseId: "",
    phaseName: "",
    unitType: "",
    bedrooms: "",
    unitTypology: "",
    unitTypeOptions: [],
    bedroomOptions: [],
    unitTypologyOptions: [],
    showTypology: false,
    eoiRangeId: null,
    eoiAmount: null,
    rangeError: ""
  };
}

export function resetSelectionCounter() {
  selectionCounter = 0;
}

export function uniqueOptions(values) {
  const seen = new Set();
  return (values || [])
    .filter((value) => value !== null && value !== undefined && String(value).trim())
    .filter((value) => {
      if (seen.has(value)) return false;
      seen.add(value);
      return true;
    })
    .map((value) => ({ label: value, value }));
}

export function phaseOptionsFrom(matrix) {
  const seen = new Set();
  const options = [];
  (matrix || []).forEach((row) => {
    if (!row.phaseId || seen.has(row.phaseId)) return;
    seen.add(row.phaseId);
    options.push({ label: row.phaseName || row.phaseId, value: row.phaseId });
  });
  return options;
}

export function rowsFor(matrix, { phaseId, unitType, bedrooms } = {}) {
  return (matrix || []).filter(
    (row) => (!phaseId || row.phaseId === phaseId) && (!unitType || row.unitType === unitType) && (!bedrooms || row.bedrooms === bedrooms)
  );
}

/**
 * Apply one field change to a selection and recompute everything downstream of it -
 * the option lists, and the range/amount once the path is complete. Pure: returns a new
 * selection. Mirrors handleSelectionPhase/UnitType/Bedrooms/TypologyChange in the home
 * journey, collapsed into one resolver.
 */
export function applySelectionChange(selection, field, value, matrix, phaseOptions) {
  let next = { ...selection, rangeError: "" };
  const order = ["phaseId", "unitType", "bedrooms", "unitTypology"];
  const idx = order.indexOf(field);
  if (idx === -1) return next;

  next[field] = value || "";
  if (field === "phaseId") {
    next.phaseName = (phaseOptions || []).find((o) => o.value === value)?.label || "";
  }
  // Everything after the changed field starts again.
  order.slice(idx + 1).forEach((f) => {
    next[f] = "";
  });
  if (idx <= 0) next.unitTypeOptions = [];
  if (idx <= 1) next.bedroomOptions = [];
  if (idx <= 2) {
    next.unitTypologyOptions = [];
    next.showTypology = false;
  }
  next.eoiRangeId = null;
  next.eoiAmount = null;

  if (next.phaseId && idx <= 0) {
    next.unitTypeOptions = uniqueOptions(rowsFor(matrix, { phaseId: next.phaseId }).map((r) => r.unitType));
  }
  if (next.phaseId && next.unitType && idx <= 1) {
    next.bedroomOptions = uniqueOptions(rowsFor(matrix, { phaseId: next.phaseId, unitType: next.unitType }).map((r) => r.bedrooms));
  }
  if (next.phaseId && next.unitType && next.bedrooms) {
    const rows = rowsFor(matrix, { phaseId: next.phaseId, unitType: next.unitType, bedrooms: next.bedrooms });
    if (idx <= 2) {
      const typologies = uniqueOptions(rows.map((r) => r.unitTypology));
      next.unitTypologyOptions = typologies;
      next.showTypology = typologies.length > 0;
    }
    if (next.showTypology) {
      if (next.unitTypology) {
        const range = rows.find((r) => r.unitTypology === next.unitTypology);
        if (range) {
          next.eoiRangeId = range.rangeId;
          next.eoiAmount = range.amount;
        } else {
          next.rangeError = "No active EOI range for this typology.";
        }
      }
    } else {
      const range = rows.find((r) => !r.unitTypology);
      if (range) {
        next.eoiRangeId = range.rangeId;
        next.eoiAmount = range.amount;
      } else {
        next.rangeError = "No active EOI range for this selection.";
      }
    }
  }
  return next;
}

export function isSelectionComplete(selection) {
  const s = selection || {};
  return Boolean(s.phaseId && s.unitType && s.bedrooms && (!s.showTypology || s.unitTypology) && s.eoiRangeId && s.eoiAmount > 0);
}

export function selectionSummary(selection, projectName) {
  const s = selection || {};
  const title = [projectName, s.phaseName].filter(Boolean).join(" · ") || "Pending selection";
  const subtitle = [s.unitTypology, s.bedrooms ? `${s.bedrooms} BR` : "", s.unitType].filter(Boolean).join(" · ") || "Complete unit details";
  return { title, subtitle, amountLabel: s.eoiAmount ? formatAED(s.eoiAmount) : "-" };
}

/* ── Requests to the engine ────────────────────────────────────────────────── */

export function buildEoiRequest(opportunityId, projectId, paymentType, selections) {
  return {
    opportunityId,
    projectId,
    paymentType,
    remarks: "",
    selections: (selections || []).map((s) => ({
      phaseId: s.phaseId,
      unitType: s.unitType,
      bedrooms: s.bedrooms,
      unitTypology: s.unitTypology || null,
      eoiRangeId: s.eoiRangeId,
      eoiAmount: s.eoiAmount
    }))
  };
}

/** Single-EOI JSON stashed on the Checkout payment; materialised on capture. */
export function buildSelectionPayload(opportunityId, projectId, selection) {
  const s = selection || {};
  return JSON.stringify({
    opportunityId,
    projectId,
    phaseId: s.phaseId,
    unitType: s.unitType,
    bedrooms: s.bedrooms,
    unitTypology: s.unitTypology || null,
    numberOfUnits: 1,
    eoiRangeId: s.eoiRangeId,
    eoiAmount: s.eoiAmount,
    remarks: "",
    paymentType: "Online"
  });
}

/* ── Errors ────────────────────────────────────────────────────────────────── */

/**
 * Richer than modonSalesFormat.reduceError: the engine surfaces DML and validation
 * detail in pageErrors / fieldErrors, and the rep needs to read that, not "Something
 * went wrong."
 */
export function reduceError(error) {
  const messages = [];
  const add = (value) => {
    if (!value) return;
    if (Array.isArray(value)) {
      value.forEach(add);
      return;
    }
    if (typeof value === "string") {
      if (value.trim()) messages.push(value.trim());
      return;
    }
    if (value.message) add(value.message);
    if (value.pageErrors) add(value.pageErrors);
    if (value.errors) add(value.errors);
    if (value.fieldErrors) Object.values(value.fieldErrors).forEach(add);
    if (value.output) add(value.output);
  };
  add(error?.body);
  add(error);
  const unique = [...new Set(messages)];
  if (unique.length) return unique.join("; ");
  try {
    return JSON.stringify(error);
  } catch (e) {
    return "Unable to read error details.";
  }
}