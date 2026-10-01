/**
 * Customer address - the one thing that blocks a booking and the console could not fix.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  11 Aug 2026  Initial.
 * 1.1      Aurelix IT  11 Aug 2026  Same Geoapify lookup as the Save Address quick action,
 *                                   so a console address carries the same coordinates and
 *                                   the same city/state spelling as one entered there.
 * 1.3      Aurelix IT  12 Aug 2026  Saves through SalesConsoleController.saveAddress rather
 *                                   than AccountAddressController.saveAccount, whose 1.1 made
 *                                   trade licence and VAT mandatory for an org account - a
 *                                   rule belonging to the Save Address quick action's form,
 *                                   not to this one, and which stopped organisations saving
 *                                   an address at all. The READS stay shared.
 * 1.2      Aurelix IT  12 Aug 2026  Picking a result no longer unmounts the form before it
 *                                   can be saved, and Save names what is missing instead of
 *                                   going quietly dead - most UAE addresses carry no
 *                                   postcode, which the button demanded and never said.
 * 1.4      Aurelix IT  12 Aug 2026  Backend waits raise c-msc-loader - not the address
 *                                   type-ahead, which fires while the rep types.
 * 1.5      Aurelix IT  12 Aug 2026  A rule and a real sub-heading, so the address stops
 *                                   reading as a continuation of the customer fields.
 * 1.6      Aurelix IT  12 Aug 2026  autocomplete="off" on every field, so Chrome stops
 *                                   offering to save a CUSTOMER's address into the rep's own
 *                                   browser profile. A hint, not a guarantee - see the note
 *                                   above the constants.
 * 1.7      Aurelix IT  12 Aug 2026  Keyboard hints per address part, bound from PARTS
 *                                   because all five render from one input. Enter reads
 *                                   Search on the lookup.
 * 1.8      Aurelix IT  12 Aug 2026  The lookup suggestions hang off the input instead of
 *                                   sitting in flow beneath it, where they pushed the address
 *                                   fields down and back on every keystroke.
 * 1.9      Aurelix IT  13 Aug 2026  focusFirstGap() - take the rep to the first empty part
 *                                   (the body carried this version; the header had not).
 * 1.10     Aurelix IT  13 Aug 2026  The same footer the payment plan card has (ditto).
 * 1.11     Aurelix IT  22 Aug 2026  MSC-113. Header repaired - 1.9 and 1.10 existed only
 *                                   as body comments. No functional change here; the org
 *                                   guard fix this release lives in
 *                                   SalesConsoleController.saveAddress (1.47), which no
 *                                   longer demands nationality/residency for a business
 *                                   account and fills the Opportunity copies only when
 *                                   blank.
 */

import { LightningElement, api, track } from "lwc";
import resolveAccountId from "@salesforce/apex/AccountAddressController.resolveAccountId";
import loadAccount from "@salesforce/apex/AccountAddressController.loadAccount";
import saveAddress from "@salesforce/apex/SalesConsoleController.saveAddress";
import searchLocation from "@salesforce/apex/GeoapifyLocationController.searchLocation";
import getAddressFromLatLong from "@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong";
import { reduceError } from "c/modonSalesFormat";

/* Chrome's "Save address?" prompt
   ------------------------------------------------------------------------------
   The fields here hold a CUSTOMER's address, captured by a rep on a shared machine.
   Chrome reads them as the person at the keyboard entering their own details and
   offers to store them in the rep's browser profile - wrong, and on a shared login
   it leaks one customer's address into the next rep's autofill.

   Every input now carries autocomplete="off", in this component and in
   mscCustomerInfo, because Chrome infers one form per PAGE: the name and email in
   that prompt come from the customer card, not from here.

   It is a hint, not a guarantee. Chrome deliberately overrides autocomplete="off"
   in some versions, and its heuristics also read the visible labels - "Street",
   "City", "Postal code" - which we are not going to rename. If the prompt persists,
   the only certain control is the browser's own setting:
   chrome://settings/addresses - "Save and fill addresses". */

/** Below this the API returns noise, and gelocationlwc uses the same floor. */
const MIN_SEARCH = 3;
const DEBOUNCE_MS = 350;

/* Geoapify returns "Abu Dhabi Emirate"; the org stores "Abu Dhabi". Same rule as
   gelocationlwc.stripEmirateSuffix - without it the console would write a different
   spelling of the same emirate than the quick action does. */
function strip(value) {
  return value ? value.replace(/\s+emirate$/i, "").trim() : "";
}

/* The five parts checkBookingEligibility tests for, each with the name it has on a
   Person Account and on a business one. One list, so the form, the completeness test
   and the "what is missing" message cannot drift apart. */
/* 1.7 - `mode` and `caps` are on-screen keyboard hints. All five render from ONE
   <input> in a for:each, so they cannot be set as literal attributes the way the
   other forms do it - they are bound per row instead. Hints only: they change the
   keyboard, never validation or the value submitted. */
const PARTS = [
  { key: "street", label: "Street", person: "personMailingStreet", org: "billingStreet", wide: true, caps: "words" },
  { key: "city", label: "City", person: "personMailingCity", org: "billingCity", caps: "words" },
  { key: "state", label: "State / Emirate", person: "personMailingState", org: "billingState", caps: "words" },
  // Digits with separators, so inputmode rather than type="number".
  { key: "postal", label: "Postal code", person: "personMailingPostalCode", org: "billingPostalCode", mode: "numeric", caps: "none" },
  { key: "country", label: "Country", person: "personMailingCountry", org: "billingCountry", caps: "words" }
];

/**
 * A thin form over AccountAddressController - the SAME Apex behind the Opportunity's
 * "Save Address" quick action.
 *
 * The quick action's own component (gelocationlwc) cannot be reused: it imports
 * lightning/actions, which LWR does not support, and it is not exposed to a community
 * target. Its controller is reused whole instead, so an address saved here and one
 * saved from the record page go through one code path rather than two that drift.
 *
 * Offered even when the customer form is locked. An existing customer is exactly who
 * turns out to be missing an address, and an address does not identify anyone - name,
 * Emirates ID, email and mobile stay read-only.
 */
export default class MscAddress extends LightningElement {
  @api opportunityId;
  /** Falls back to what the booking knows when the Account carries neither. */
  @api nationality;
  @api residentStatus;

  @track wrap;
  loading = false;
  saving = false;
  errorMsg;
  savedOnce = false;
  /** 1.2 - see showForm. Set from the record on load, never from the form. */
  open = false;

  connectedCallback() {
    this.load();
  }

  async load() {
    if (!this.opportunityId) return;
    this.loading = true;
    this.errorMsg = undefined;
    try {
      const accountId = await resolveAccountId({ sourceRecordId: this.opportunityId });
      if (!accountId) return;
      const w = await loadAccount({ accountId });
      this.wrap = { ...w, opportunityId: this.opportunityId };
      this.open = !this.isComplete;
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.loading = false;
    }
  }

  get isPerson() {
    return !!(this.wrap && this.wrap.isPersonAccount);
  }

  get isOrg() {
    return !!(this.wrap && this.wrap.isPersonAccount === false);
  }

  /** The name each part has on this kind of Account. */
  nameOf(part) {
    return this.isPerson ? part.person : part.org;
  }

  /**
   * 1.9 - TAKE THE REP TO THE GAP.
   *
   * The forward button validates on the press now, and a message that names a
   * missing address without moving anything is only marginally better than the
   * banner it replaced: this block sits below the fold of a card the rep has
   * already scrolled past. This scrolls the first blank box into the middle of the
   * pane and puts the cursor in it.
   *
   * Returns false when there is nothing to focus - the form is not rendered, or
   * every part is filled and the gap is somewhere else - so the caller can try
   * elsewhere rather than assuming this landed.
   */
  @api
  focusFirstGap() {
    if (!this.showForm) {
      return false;
    }
    const w = this.wrap || {};
    const part = PARTS.find((p) => !String(w[this.nameOf(p)] || "").trim());
    if (!part) {
      return false;
    }
    const el = this.template.querySelector(`[data-key="${part.key}"]`);
    if (!el) {
      return false;
    }
    /* Centre, not start: `start` puts the field under the section heading that
       sticks above it, and the rep lands on a box they cannot see the label of. */
    el.scrollIntoView({ block: "center", behavior: "smooth" });
    el.focus();
    return true;
  }

  /** Parts still blank, by their on-screen label. Drives the Save message. */
  get missingLabels() {
    const w = this.wrap || {};
    return PARTS.filter((p) => !String(w[this.nameOf(p)] || "").trim()).map((p) => p.label);
  }

  /**
   * Complete means what checkBookingEligibility means by it - all five parts. A
   * partial address blocks the booking exactly as a missing one does.
   */
  get isComplete() {
    return !!this.wrap && this.missingLabels.length === 0;
  }

  /**
   * 1.2 - decided from the RECORD on load, not from the form's current contents.
   *
   * This was `!this.isComplete`, evaluated live. Picking a search result fills all
   * five parts at once, so isComplete flipped true and the form unmounted - fields,
   * Save button and all - before anything reached the Account. The rep watched the
   * section vanish and the "address required" banner stay.
   */
  get showForm() {
    return !!this.wrap && this.open;
  }

  /**
   * 1.10 - A SAVED ADDRESS IS A FACT, AND FACTS ARE ONE LINE.
   *
   * The form closes on a successful save (open goes false), and until now that
   * left the section rendering nothing at all: the rep had just typed five boxes
   * and got a blank space back, with no way to see what had landed. One read-only
   * line under the same heading the form carried, and nothing else - no Edit
   * button, because c/mscAddress is still the one writer and reopens itself
   * whenever the address is incomplete.
   *
   * Both buyer types, because nameOf already answers which five fields this
   * account keeps its address in.
   */
  get showSummary() {
    return !!this.wrap && !this.open && this.isComplete;
  }

  get addressLine() {
    const w = this.wrap || {};
    return PARTS.map((p) => String(w[this.nameOf(p)] || "").trim())
      .filter(Boolean)
      .join(", ");
  }

  get fields() {
    const w = this.wrap || {};
    return PARTS.map((p) => ({
      key: p.key,
      label: p.label,
      value: w[this.nameOf(p)] || "",
      cls: p.wide ? "field field--wide" : "field",
      mode: p.mode || "text",
      caps: p.caps || "none"
    }));
  }

  handleField(event) {
    const key = event.currentTarget.dataset.key;
    const part = PARTS.find((p) => p.key === key);
    if (!part) return;
    this.wrap = { ...this.wrap, [this.nameOf(part)]: event.target.value };
  }

  // ---- 1.1 the same Geoapify lookup the quick action uses -----------------

  searchText = "";
  @track results = [];
  searching = false;
  _timer;

  get hasResults() {
    return this.results.length > 0;
  }

  handleSearchChange(event) {
    this.searchText = event.target.value;
    window.clearTimeout(this._timer);
    if (!this.searchText || this.searchText.length < MIN_SEARCH) {
      this.results = [];
      return;
    }
    // Debounced: this is a paid callout on every keystroke otherwise.
    this._timer = window.setTimeout(() => this.runSearch(), DEBOUNCE_MS);
  }

  async runSearch() {
    this.searching = true;
    try {
      const hits = (await searchLocation({ searchText: this.searchText })) || [];
      this.results = hits.map((r, i) => ({ ...r, key: r.placeId || `${r.label}-${i}` }));
    } catch (e) {
      // A lookup failure must not block typing the address by hand.
      this.results = [];
    } finally {
      this.searching = false;
    }
  }

  /**
   * Fills every part from the API's own values, exactly as gelocationlwc does -
   * including the coordinates, which is why this matters. Typing the address by
   * hand leaves PersonMailingLatitude/Longitude null, so a console-entered address
   * would differ from a quick-action one on the same record.
   */
  async handlePick(event) {
    const lat = parseFloat(event.currentTarget.dataset.lat);
    const lon = parseFloat(event.currentTarget.dataset.lon);
    this.searchText = event.currentTarget.dataset.label || "";
    this.results = [];
    this.searching = true;
    try {
      const geo = await getAddressFromLatLong({ latitude: lat, longitude: lon });
      const isUae = (geo.countryCode || "").toLowerCase() === "ae";
      const p = this.isPerson;
      const picked = {
        street: geo.street || geo.addressLine1,
        city: isUae ? strip(geo.city) : geo.city,
        state: isUae ? strip(geo.state) : geo.state,
        postal: geo.postcode,
        country: geo.country
      };
      const next = { ...this.wrap };
      /* A part the geocoder has no value for keeps what is already there. Google
         returns no postal_code for most UAE addresses, and `|| ""` wiped one the
         record already held. */
      PARTS.forEach((part) => {
        const value = picked[part.key];
        if (value) next[this.nameOf(part)] = value;
      });
      next[p ? "personMailingLatitude" : "billingLatitude"] = lat;
      next[p ? "personMailingLongitude" : "billingLongitude"] = lon;
      this.wrap = next;
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.searching = false;
    }
  }

  /**
   * 1.2 - live unless a save is in flight. It used to require a complete address,
   * which made the button dead with nothing on screen explaining why - and the part
   * usually missing is the postal code, which Google does not return for most UAE
   * addresses. handleSave now names what is missing, as the Save Address quick
   * action does.
   */
  get saveDisabled() {
    return this.saving;
  }

  get saveLabel() {
    return this.saving ? "Saving…" : "Save address";
  }

  async handleSave() {
    if (this.saving) return;
    const missing = this.missingLabels;
    if (missing.length) {
      this.errorMsg = "Fill in: " + missing.join(", ");
      return;
    }
    this.saving = true;
    this.errorMsg = undefined;
    try {
      /* Named explicitly, not spread from `wrap`. loadAccount's wrapper carries
         recordTypeName, unifiedNumber, tradeLicenseNumber and uaeVatRegisterNumber,
         which AddressInput does not declare - and an undeclared property fails
         deserialisation rather than being ignored.

         Residency is required and must match the Opportunity, so it comes from the
         booking rather than being asked for a second time. */
      const w = this.wrap;
      const input = {
        opportunityId: this.opportunityId,
        accountId: w.accountId,
        isPersonAccount: !!w.isPersonAccount,
        personMailingStreet: w.personMailingStreet,
        personMailingCity: w.personMailingCity,
        personMailingState: w.personMailingState,
        personMailingPostalCode: w.personMailingPostalCode,
        personMailingCountry: w.personMailingCountry,
        personMailingLatitude: w.personMailingLatitude,
        personMailingLongitude: w.personMailingLongitude,
        billingStreet: w.billingStreet,
        billingCity: w.billingCity,
        billingState: w.billingState,
        billingPostalCode: w.billingPostalCode,
        billingCountry: w.billingCountry,
        billingLatitude: w.billingLatitude,
        billingLongitude: w.billingLongitude,
        nationality: w.nationality || this.nationality,
        uaeResidentStatus: w.uaeResidentStatus || this.residentStatus
      };
      await saveAddress({ input });
      this.savedOnce = true;
      // Collapses now that the address is actually stored, not when it is merely typed.
      this.open = false;
      // The parent re-reads console state, which clears the eligibility banner.
      this.dispatchEvent(new CustomEvent("addresssaved"));
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.saving = false;
    }
  }

  /**
   * Deliberately NOT `searching`. That is the debounced address type-ahead, which fires
   * while the rep is still typing - a blocking overlay on every keystroke would make the
   * field unusable. It keeps its own quiet "Searching..." line instead.
   */
  get isBusy() {
    return !!(this.loading || this.saving);
  }
}