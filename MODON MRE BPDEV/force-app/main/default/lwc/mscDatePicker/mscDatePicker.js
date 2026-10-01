/**
 * mscDatePicker - the console's own date field, with a calendar drawn in the page.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 21 Sep 2026  Replaces <input type="date"> on the console's forms. Chromium for
 *                                   Linux opens the native calendar as a separate OS window that
 *                                   shows as an empty grey panel before it paints (seen in testing, 21 Sep -
 *                                   the same defect as the Nationality list, SCW-134). The calendar
 *                                   here is part of the page and placed by c/mscFloat. The field
 *                                   takes typing as dd/mm/yyyy; the calendar's title opens a month
 *                                   grid and then a year grid, so a passport date years away is three
 *                                   clicks. On a touch screen the native date input is kept: the
 *                                   phone's own picker is the better control there.
 * 1.1      Aurelix Dev 21 Sep 2026  The calendar no longer closes when its own month title or arrows
 *                                   are clicked. The old check asked event.composedPath() for this
 *                                   host, which the site never returns, so every click inside counted
 *                                   as outside; a day click only worked because the pick ran before
 *                                   the close landed. c/mscFloat 1.1's outsideClicks() decides
 *                                   instead (SCW-135).
 * 1.2      Aurelix Dev 21 Sep 2026  The month and year grids keep the day grid's height. Opening
 *                                   upward, the calendar is pinned by its bottom edge, so the shorter
 *                                   grids moved the whole panel - title included - 60px down, out
 *                                   from under the pointer.
 *
 * A drop-in for the forms' handlers: the value is an ISO date (yyyy-mm-dd) exactly as the native
 * input's, set BEFORE `input` and `change` are fired from the host, so event.target.value and
 * event.target.dataset.* read as they did.
 */
import { LightningElement, api } from "lwc";
import { follow, isTouch, outsideClicks } from "c/mscFloat";

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August",
  "September", "October", "November", "December"];
const MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

const pad = (n) => (n < 10 ? "0" + n : "" + n);
const toISO = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const daysIn = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

function parseISO(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || ""));
  if (!m) return null;
  const y = +m[1];
  const mo = +m[2];
  const d = +m[3];
  if (mo < 1 || mo > 12 || d < 1 || d > daysIn(y, mo)) return null;
  return { y, m: mo, d };
}

/** dd/mm/yyyy (also - or . between), or yyyy-mm-dd; null when it is not a real date. */
function parseTyped(s) {
  const t = String(s || "").trim();
  if (!t) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(t)) return parseISO(t);
  const m = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/.exec(t);
  if (!m) return null;
  const d = +m[1];
  const mo = +m[2];
  const y = +m[3];
  if (mo < 1 || mo > 12 || d < 1 || d > daysIn(y, mo)) return null;
  return { y, m: mo, d };
}

function todayParts() {
  const n = new Date();
  return { y: n.getFullYear(), m: n.getMonth() + 1, d: n.getDate() };
}

export default class MscDatePicker extends LightningElement {
  @api label;
  @api placeholder = "dd/mm/yyyy";
  /** The field's class - the forms pass field__input, with field__input--error when invalid. */
  @api inputClass = "field__input";
  @api invalid;
  /** "compact" (the cheque sheet's 30px fields) or "small" (the lead drawer's 36px); else standard. */
  @api size;
  /** ISO bounds, as the native input's min / max. */
  @api min;
  @api max;

  _disabled = false;
  @api
  get disabled() {
    return this._disabled;
  }
  set disabled(v) {
    this._disabled = v === true || v === "true" || v === "";
    if (this._disabled) this.close(false);
  }

  _readonly = false;
  @api
  get readonly() {
    return this._readonly;
  }
  set readonly(v) {
    this._readonly = v === true || v === "true" || v === "";
    if (this._readonly) this.close(false);
  }

  _value = "";
  @api
  get value() {
    return this._value;
  }
  set value(v) {
    const iso = v === undefined || v === null ? "" : String(v);
    this._value = parseISO(iso) ? iso : "";
    if (!this._typing) this.text = this.format(this._value);
  }

  @api
  focus() {
    const el = this.template.querySelector("input");
    if (el) el.focus();
  }

  isNative = false;
  open = false;
  text = "";
  view = "days"; // days | months | years
  cursor = { y: 0, m: 1 }; // the month on show
  focusDay = null; // { y, m, d } moved by the keyboard
  _typing = false;

  connectedCallback() {
    this.isNative = isTouch();
    this.text = this.format(this._value);
    this._clicks = outsideClicks(() => this.close(true));
  }

  disconnectedCallback() {
    if (this._clicks) this._clicks.disarm();
    this.stopFollow();
  }

  renderedCallback() {
    if (!this.open) return;
    if (!this._stopFollow) {
      const field = this.template.querySelector(".dp__input");
      const panel = this.template.querySelector(".dp__panel");
      this._stopFollow = follow(field, panel, { want: 360, max: 380, min: 300, width: 296 }, () =>
        this.close(true)
      );
      if (panel) panel.focus();
    }
  }

  /* ── the field ────────────────────────────────────────────────────────── */

  format(iso) {
    const p = parseISO(iso);
    return p ? `${pad(p.d)}/${pad(p.m)}/${p.y}` : "";
  }

  get baseClass() {
    if (this.size === "compact" || this.size === "small") {
      return `dp__${this.size}` + (this.invalid ? " dp__bad" : "");
    }
    return (this.inputClass || "field__input") + (this.invalid ? " field__input--error" : "");
  }

  get fieldClass() {
    return this.baseClass + " dp__input";
  }

  get nativeClass() {
    return this.baseClass;
  }

  get showIcon() {
    return !this._readonly && !this._disabled;
  }

  get expandedAttr() {
    return this.open ? "true" : "false";
  }

  handleText(event) {
    this._typing = true;
    this.text = event.target.value;
  }

  handleTextKey(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.commitText();
    } else if (event.key === "ArrowDown" && !this.open) {
      event.preventDefault();
      this.openPanel();
    } else if (event.key === "Escape" && this.open) {
      event.preventDefault();
      this.close(false);
    }
  }

  handleTextBlur() {
    /* leaving for the calendar is not leaving the field */
    if (this.open) return;
    this.commitText();
    this.dispatchEvent(new CustomEvent("blur"));
  }

  commitText() {
    this._typing = false;
    const t = (this.text || "").trim();
    if (!t) {
      this.setValue("");
      return;
    }
    const p = parseTyped(t);
    if (p) {
      this.setValue(toISO(p.y, p.m, p.d));
    } else {
      /* not a date: show the last good value rather than invent one */
      this.text = this.format(this._value);
    }
  }

  setValue(iso) {
    const changed = iso !== this._value;
    this._value = iso;
    this.text = this.format(iso);
    if (changed) {
      this.dispatchEvent(new CustomEvent("input"));
      this.dispatchEvent(new CustomEvent("change"));
    }
  }

  handleNative(event) {
    event.stopPropagation();
    this._value = event.target.value || "";
    this.dispatchEvent(new CustomEvent(event.type === "change" ? "change" : "input"));
  }

  handleNativeBlur() {
    this.dispatchEvent(new CustomEvent("blur"));
  }

  /* ── opening ─────────────────────────────────────────────────────────── */

  /* a mousedown on this control, which is never a click elsewhere */
  handleInsideDown() {
    if (this._clicks) this._clicks.inside();
  }

  toggle() {
    if (this.open) this.close(false);
    else this.openPanel();
  }

  openPanel() {
    if (this._disabled || this._readonly || this.open) return;
    const typed = parseTyped(this.text);
    const cur = typed || parseISO(this._value) || this.clampParts(todayParts());
    this.cursor = { y: cur.y, m: cur.m };
    this.focusDay = { ...cur };
    this.view = "days";
    this.open = true;
    this._clicks.arm();
  }

  stopFollow() {
    if (this._stopFollow) {
      this._stopFollow();
      this._stopFollow = null;
    }
  }

  close(fireBlur) {
    if (!this.open) return;
    this.stopFollow();
    this.open = false;
    this._clicks.disarm();
    if (fireBlur) this.dispatchEvent(new CustomEvent("blur"));
  }

  /** Today, or the nearest allowed day when today is out of bounds - where the calendar opens. */
  clampParts(p) {
    const iso = toISO(p.y, p.m, p.d);
    if (this.min && iso < this.min) return parseISO(this.min) || p;
    if (this.max && iso > this.max) return parseISO(this.max) || p;
    return p;
  }

  allowed(iso) {
    if (this.min && iso < this.min) return false;
    if (this.max && iso > this.max) return false;
    return true;
  }

  /* ── the calendar ────────────────────────────────────────────────────── */

  get isDays() {
    return this.view === "days";
  }
  get isMonths() {
    return this.view === "months";
  }
  get isYears() {
    return this.view === "years";
  }

  get title() {
    if (this.view === "days") return `${MONTHS[this.cursor.m - 1]} ${this.cursor.y}`;
    if (this.view === "months") return `${this.cursor.y}`;
    const start = Math.floor(this.cursor.y / 12) * 12;
    return `${start} – ${start + 11}`;
  }

  get weekdays() {
    return WEEKDAYS.map((w) => ({ key: w, label: w }));
  }

  get days() {
    const { y, m } = this.cursor;
    const first = new Date(Date.UTC(y, m - 1, 1)).getUTCDay(); // 0 = Sunday
    const lead = (first + 6) % 7; // Monday first
    const start = new Date(Date.UTC(y, m - 1, 1 - lead));
    const today = todayParts();
    const todayIso = toISO(today.y, today.m, today.d);
    const focusIso = this.focusDay ? toISO(this.focusDay.y, this.focusDay.m, this.focusDay.d) : "";
    const out = [];
    for (let i = 0; i < 42; i++) {
      const dt = new Date(start.getTime() + i * 86400000);
      const dy = dt.getUTCFullYear();
      const dm = dt.getUTCMonth() + 1;
      const dd = dt.getUTCDate();
      const iso = toISO(dy, dm, dd);
      const ok = this.allowed(iso);
      let cls = "dp__day";
      if (dm !== m) cls += " dp__day--out";
      if (iso === todayIso) cls += " dp__day--today";
      if (iso === this._value) cls += " dp__day--sel";
      if (iso === focusIso) cls += " dp__day--focus";
      out.push({
        key: iso,
        iso,
        label: dd,
        cls,
        disabled: !ok,
        aria: `${dd} ${MONTHS[dm - 1]} ${dy}`,
        selected: iso === this._value ? "true" : "false"
      });
    }
    return out;
  }

  get months() {
    const y = this.cursor.y;
    return MONTHS_SHORT.map((label, i) => {
      const m = i + 1;
      const last = toISO(y, m, daysIn(y, m));
      const first = toISO(y, m, 1);
      const ok = !(this.min && last < this.min) && !(this.max && first > this.max);
      const sel = parseISO(this._value);
      return {
        key: label,
        m,
        label,
        disabled: !ok,
        cls: "dp__cell" + (sel && sel.y === y && sel.m === m ? " dp__cell--sel" : "") + (m === this.cursor.m ? " dp__cell--focus" : "")
      };
    });
  }

  get years() {
    const start = Math.floor(this.cursor.y / 12) * 12;
    const sel = parseISO(this._value);
    const out = [];
    for (let y = start; y < start + 12; y++) {
      const ok = !(this.min && toISO(y, 12, 31) < this.min) && !(this.max && toISO(y, 1, 1) > this.max);
      out.push({
        key: "" + y,
        y,
        label: y,
        disabled: !ok,
        cls: "dp__cell" + (sel && sel.y === y ? " dp__cell--sel" : "") + (y === this.cursor.y ? " dp__cell--focus" : "")
      });
    }
    return out;
  }

  get todayAllowed() {
    const t = todayParts();
    return this.allowed(toISO(t.y, t.m, t.d));
  }
  get todayDisabled() {
    return !this.todayAllowed;
  }

  handleTitle() {
    this.view = this.view === "days" ? "months" : this.view === "months" ? "years" : "days";
  }

  handlePrev() {
    this.step(-1);
  }
  handleNext() {
    this.step(1);
  }

  step(dir) {
    const { y, m } = this.cursor;
    if (this.view === "days") {
      const nm = m + dir;
      this.cursor = nm < 1 ? { y: y - 1, m: 12 } : nm > 12 ? { y: y + 1, m: 1 } : { y, m: nm };
    } else if (this.view === "months") {
      this.cursor = { y: y + dir, m };
    } else {
      this.cursor = { y: y + dir * 12, m };
    }
  }

  handleDay(event) {
    event.preventDefault();
    const iso = event.currentTarget.dataset.iso;
    if (!iso || !this.allowed(iso)) return;
    this.pick(iso);
  }

  handleMonth(event) {
    event.preventDefault();
    this.cursor = { y: this.cursor.y, m: Number(event.currentTarget.dataset.m) };
    this.view = "days";
  }

  handleYear(event) {
    event.preventDefault();
    this.cursor = { y: Number(event.currentTarget.dataset.y), m: this.cursor.m };
    this.view = "months";
  }

  handleToday(event) {
    event.preventDefault();
    const t = todayParts();
    const iso = toISO(t.y, t.m, t.d);
    if (this.allowed(iso)) this.pick(iso);
  }

  handleClear(event) {
    event.preventDefault();
    this.pick("");
  }

  /* the value first, so a form validating on blur sees it; focus goes back to the field, whose
     own blur reports leaving it */
  pick(iso) {
    this._typing = false;
    this.setValue(iso);
    this.close(false);
    this.focus();
  }

  /* the keyboard on the open calendar */
  handlePanelKey(event) {
    const k = event.key;
    if (k === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.close(false);
      this.focus();
      return;
    }
    if (this.view !== "days" || !this.focusDay) return;
    const f = this.focusDay;
    let delta = 0;
    if (k === "ArrowLeft") delta = -1;
    else if (k === "ArrowRight") delta = 1;
    else if (k === "ArrowUp") delta = -7;
    else if (k === "ArrowDown") delta = 7;
    if (delta) {
      event.preventDefault();
      const dt = new Date(Date.UTC(f.y, f.m - 1, f.d + delta));
      this.focusDay = { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
      this.cursor = { y: this.focusDay.y, m: this.focusDay.m };
      return;
    }
    if (k === "PageUp" || k === "PageDown") {
      event.preventDefault();
      const dir = k === "PageUp" ? -1 : 1;
      const dt = new Date(Date.UTC(f.y, f.m - 1 + dir, 1));
      const y = dt.getUTCFullYear();
      const m = dt.getUTCMonth() + 1;
      this.focusDay = { y, m, d: Math.min(f.d, daysIn(y, m)) };
      this.cursor = { y, m };
      return;
    }
    if (k === "Enter" || k === " ") {
      event.preventDefault();
      const iso = toISO(f.y, f.m, f.d);
      if (this.allowed(iso)) this.pick(iso);
    }
  }
}