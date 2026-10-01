/**
 * mscPicklist - the console's own dropdown, drawn in the page.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix Dev 21 Sep 2026  Replaces the native <select> on the customer and identity forms.
 *                                   On Chromium for Linux a select's list is a separate OS window
 *                                   that appears before it has painted, so the long lists
 *                                   (Nationality, Country of residence) showed as a large empty grey
 *                                   panel, even over the browser's tab bar (seen in testing, 21 Sep).
 *                                   SCW-127 proved no CSS reaches that window. This list is part of
 *                                   the page, so there is no window to be late. Lists longer than
 *                                   twelve get a search box. On a touch screen the native select is
 *                                   kept: the phone's own picker is the better control there and
 *                                   has no such window.
 * 1.2      Aurelix Dev 21 Sep 2026  The panel is placed by c/mscFloat - position: fixed, against the
 *                                   window - instead of inside the form. Opening upward in the short
 *                                   booking modal, the form's scroll box cut the list's top off, and
 *                                   with it the search box, which only reappeared once typing shrank
 *                                   the list (seen in testing, 21 Sep). It now never grows taller than the room
 *                                   it has, and follows its field while the form scrolls.
 * 1.1      Aurelix Dev 21 Sep 2026  size="compact" (the 30px, 11.5px controls of the cheque sheet and
 *                                   the direct debit form) and `invalid`, so a form whose own classes
 *                                   cannot reach inside this component keeps its look and error state.
 * 1.3      Aurelix Dev 21 Sep 2026  A click inside the open list - its search box, its scrollbar, the
 *                                   field itself - no longer closes it. The old check asked
 *                                   event.composedPath() for this host, which the site never returns,
 *                                   so every such click counted as outside; option clicks only worked
 *                                   because the pick ran before the close landed. c/mscFloat 1.1's
 *                                   outsideClicks() decides instead (SCW-135).
 *
 * A drop-in for the forms' existing onchange handlers: the value is set BEFORE `change` is fired
 * from the host, so event.target.value and event.target.dataset.* read exactly as they did on a
 * <select>. `options` takes the forms' existing shape - { value, label | text, selected }.
 */
import { LightningElement, api } from "lwc";
import { follow, isTouch, outsideClicks } from "c/mscFloat";

/* a list longer than this gets a search box */
const SEARCH_FROM = 12;
/* the tallest the panel grows; less when the room runs out */
const PANEL_MAX = 300;
const PANEL_MIN = 120;

export default class MscPicklist extends LightningElement {
  /** What the closed control says before anything is chosen. */
  @api placeholder = "Select…";
  /** Accessible name; the forms' visible <label> cannot point into this component. */
  @api label;
  /** The trigger's class - the forms pass field__select, with field__input--error when invalid. */
  @api selectClass = "field__select";
  /** "compact" for the dense forms; anything else is the standard 44px field. */
  @api size;
  /** Truthy draws the error border - a form passes its own error flag or message. */
  @api invalid;

  _disabled = false;
  @api
  get disabled() {
    return this._disabled;
  }
  set disabled(v) {
    this._disabled = v === true || v === "true" || v === "";
    if (this._disabled && this.open) this.close(false);
  }

  _options = [];
  _value = "";
  _explicit = false;

  @api
  get options() {
    return this._options;
  }
  set options(v) {
    this._options = Array.isArray(v) ? v : [];
    /* the forms mark the chosen option `selected` rather than passing a value */
    if (!this._explicit) {
      const sel = this._options.find((o) => o && o.selected);
      this._value = sel ? String(sel.value) : "";
    }
  }

  @api
  get value() {
    return this._value;
  }
  set value(v) {
    this._explicit = v !== undefined && v !== null;
    this._value = v === undefined || v === null ? "" : String(v);
  }

  /** So a form's "focus the first gap" code lands on the control. */
  @api
  focus() {
    const el = this.template.querySelector(".pk__trigger") || this.template.querySelector("select");
    if (el) el.focus();
  }

  open = false;
  query = "";
  activeIndex = -1;
  isNative = false;
  _scrollPending = false;

  connectedCallback() {
    this.isNative = isTouch();
    this._clicks = outsideClicks(() => this.close(true));
  }

  disconnectedCallback() {
    if (this._clicks) this._clicks.disarm();
    this.stopFollow();
  }

  renderedCallback() {
    if (!this.open) return;
    if (!this._stopFollow) {
      const trigger = this.template.querySelector(".pk__trigger");
      const panel = this.template.querySelector(".pk__panel");
      /* the panel's natural height: the search box plus a row per option */
      const want = (this.searchable ? 52 : 8) + this.items.length * 38;
      this._stopFollow = follow(
        trigger,
        panel,
        { want, max: PANEL_MAX, min: PANEL_MIN, matchWidth: true },
        () => this.close(true)
      );
    }
    if (this._focusSearch) {
      this._focusSearch = false;
      const s = this.template.querySelector(".pk__search");
      if (s) s.focus();
    }
    if (this._scrollPending) {
      this._scrollPending = false;
      this.scrollActiveIntoView();
    }
  }

  /* ── what the template reads ─────────────────────────────────────────── */

  get items() {
    return this._options
      .filter((o) => o && o.value !== undefined && o.value !== null && String(o.value) !== "")
      .map((o, i) => {
        const value = String(o.value);
        return {
          key: value + "::" + i,
          value,
          label: o.label || o.text || value,
          selected: value === this._value
        };
      });
  }

  get searchable() {
    return this.items.length > SEARCH_FROM;
  }

  get visible() {
    const q = (this.query || "").trim().toLowerCase();
    let list = this.items;
    if (q) {
      /* what starts with the typing first, then what merely contains it */
      const starts = list.filter((o) => o.label.toLowerCase().startsWith(q));
      const contains = list.filter(
        (o) => !o.label.toLowerCase().startsWith(q) && o.label.toLowerCase().includes(q)
      );
      list = starts.concat(contains);
    }
    return list.map((o, index) => ({
      ...o,
      index,
      ariaSelected: o.selected ? "true" : "false",
      cls:
        "pk__opt" +
        (index === this.activeIndex ? " pk__opt--active" : "") +
        (o.selected ? " pk__opt--selected" : "")
    }));
  }

  get noMatch() {
    return this.open && this.visible.length === 0;
  }

  get selectedItem() {
    return this.items.find((o) => o.selected);
  }

  get displayText() {
    const s = this.selectedItem;
    return s ? s.label : this.placeholder;
  }

  get displayClass() {
    return this.selectedItem ? "pk__value" : "pk__value pk__value--placeholder";
  }

  get baseClass() {
    if (this.size === "compact") {
      return "pk__compact" + (this.invalid ? " pk__bad" : "");
    }
    return (this.selectClass || "field__select") + (this.invalid ? " field__input--error" : "");
  }

  get triggerClass() {
    return this.baseClass + " pk__trigger";
  }

  get nativeClass() {
    return this.baseClass;
  }

  get panelSizeClass() {
    return this.size === "compact" ? " pk__panel--compact" : "";
  }

  get expandedAttr() {
    return this.open ? "true" : "false";
  }

  get panelClass() {
    return "pk__panel" + this.panelSizeClass;
  }

  /* ── opening and closing ─────────────────────────────────────────────── */

  /* a mousedown on this control, which is never a click elsewhere */
  handleInsideDown() {
    if (this._clicks) this._clicks.inside();
  }

  toggle() {
    if (this._disabled) return;
    if (this.open) {
      this.close(false);
    } else {
      this.openPanel("");
    }
  }

  openPanel(seed) {
    if (this._disabled || this.open) return;
    this.query = this.searchable ? seed || "" : "";
    const list = this.visible;
    const at = list.findIndex((o) => o.selected);
    this.activeIndex = at >= 0 ? at : list.length ? 0 : -1;
    this.open = true;
    this._focusSearch = this.searchable;
    this._scrollPending = true;
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
    this.query = "";
    this._clicks.disarm();
    /* the forms mark a field touched on blur; closing is when the rep has left it */
    if (fireBlur) this.dispatchEvent(new CustomEvent("blur"));
  }

  /* ── choosing ────────────────────────────────────────────────────────── */

  pick(value) {
    const changed = String(value) !== this._value;
    this._value = String(value);
    this.close(true);
    this.focus();
    /* after the value is set, from the host: event.target.value reads the new value */
    if (changed) this.dispatchEvent(new CustomEvent("change"));
  }

  handleOptionDown(event) {
    /* mousedown, not click: the search box must not blur first and close the list */
    event.preventDefault();
    this.pick(event.currentTarget.dataset.value);
  }

  handleOptionHover(event) {
    this.activeIndex = Number(event.currentTarget.dataset.index);
  }

  handleQuery(event) {
    this.query = event.target.value;
    this.activeIndex = this.visible.length ? 0 : -1;
    this._scrollPending = true;
  }

  handleNative(event) {
    this._value = event.target.value;
    event.stopPropagation();
    this.dispatchEvent(new CustomEvent("change"));
  }

  handleNativeBlur() {
    this.dispatchEvent(new CustomEvent("blur"));
  }

  /* ── the keyboard, as a select answers it ───────────────────────────── */

  handleKey(event) {
    const k = event.key;
    if (!this.open) {
      if (k === "ArrowDown" || k === "ArrowUp" || k === "Enter" || k === " ") {
        event.preventDefault();
        this.openPanel("");
        return;
      }
      /* a printable key on the closed control: open and start the search with it, or jump to
         the first option that starts with it on a short list */
      if (k.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
        event.preventDefault();
        if (this.searchable) {
          this.openPanel(k);
        } else {
          this.openPanel("");
          this.jumpTo(k);
        }
      }
      return;
    }
    const n = this.visible.length;
    if (k === "ArrowDown") {
      event.preventDefault();
      this.activeIndex = n ? Math.min(n - 1, this.activeIndex + 1) : -1;
      this._scrollPending = true;
    } else if (k === "ArrowUp") {
      event.preventDefault();
      this.activeIndex = n ? Math.max(0, this.activeIndex - 1) : -1;
      this._scrollPending = true;
    } else if (k === "Home" && !this.searchable) {
      event.preventDefault();
      this.activeIndex = n ? 0 : -1;
      this._scrollPending = true;
    } else if (k === "End" && !this.searchable) {
      event.preventDefault();
      this.activeIndex = n ? n - 1 : -1;
      this._scrollPending = true;
    } else if (k === "Enter") {
      event.preventDefault();
      const o = this.visible[this.activeIndex];
      if (o) this.pick(o.value);
    } else if (k === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.close(false);
      this.focus();
    } else if (k === "Tab") {
      this.close(true);
    } else if (!this.searchable && k.length === 1) {
      this.jumpTo(k);
    }
  }

  jumpTo(ch) {
    const c = String(ch).toLowerCase();
    const list = this.visible;
    const from = this.activeIndex + 1;
    const order = list.slice(from).concat(list.slice(0, from));
    const hit = order.find((o) => o.label.toLowerCase().startsWith(c));
    if (hit) {
      this.activeIndex = hit.index;
      this._scrollPending = true;
    }
  }

  scrollActiveIntoView() {
    const list = this.template.querySelector(".pk__list");
    const el = this.template.querySelector(".pk__opt--active");
    if (!list || !el) return;
    /* the list's own scroll only - scrollIntoView would move the page as well */
    if (el.offsetTop < list.scrollTop) {
      list.scrollTop = el.offsetTop - 4;
    } else if (el.offsetTop + el.offsetHeight > list.scrollTop + list.clientHeight) {
      list.scrollTop = el.offsetTop + el.offsetHeight - list.clientHeight + 4;
    }
  }
}