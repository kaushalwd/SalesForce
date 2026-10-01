/**
 * Paging helpers for the console's list panes (MSC-057, 18 Aug 2026).
 *
 * The panes (My Leads, Expressions of Interest, Total Sales) hold their whole
 * list client-side (each read is capped at 200), so paging is a slice, not a
 * query. What makes it "fit": the page size is measured, not fixed. The pane
 * host is the scroll container (mscWorkspace's .pane), so the visible height is
 * known; the page size is however many rows fit between the top of the list
 * and the pager pinned at the bottom - no vertical scroll on the sheet.
 *
 * Pure functions plus one measurement; no state, no DOM ownership. Each pane
 * keeps `page` / `pageSize` itself and calls these.
 */

/** Never fewer rows than this on a page, however small the viewport. */
export const PAGE_MIN = 3;
/** Never more than this: past it the row is small enough that scrolling wins. */
export const PAGE_MAX = 50;
/** Before the first measurement lands (or if it cannot). */
export const PAGE_DEFAULT = 8;
/** The pager's height plus its top padding, used while the pager is not rendered yet. */
const PAGER_RESERVE = 56;
/** Space under the last row: .grid-scroll's bottom padding plus a little slack. */
const LIST_TAIL = 8;

/**
 * How many rows fit. `tpl` is the component's template (querySelector root),
 * `host` the pane element that scrolls. Returns null when it cannot measure
 * (nothing rendered, hidden, zero-height) so the caller keeps its size.
 */
export function fitPageSize(tpl, host, gap = 8) {
  try {
    if (!tpl || !host) {
      return null;
    }
    const list = tpl.querySelector(".list");
    // A real row, or a skeleton row while loading - both carry the row pitch.
    const row = tpl.querySelector(".list .row, .list .sk");
    if (!list || !row) {
      return null;
    }
    const hostRect = host.getBoundingClientRect();
    if (!(hostRect.height > 0)) {
      return null;
    }
    const cs = window.getComputedStyle(host);
    const borderTop = parseFloat(cs.borderTopWidth) || 0;
    const padBottom = parseFloat(cs.paddingBottom) || 0;
    // Bottom of the pane's content box, in viewport terms.
    const innerBottom = hostRect.top + borderTop + host.clientHeight - padBottom;
    // Top of the list as if the pane were not scrolled.
    const listTop = list.getBoundingClientRect().top + host.scrollTop;
    const pager = tpl.querySelector(".pager");
    let reserve = PAGER_RESERVE;
    if (pager) {
      const pcs = window.getComputedStyle(pager);
      // margin-top is `auto` (pinned to the bottom); only the fixed parts count.
      reserve =
        pager.offsetHeight +
        (parseFloat(pcs.marginBottom) || 0);
    }
    const avail = innerBottom - listTop - reserve - LIST_TAIL;
    const pitch = row.getBoundingClientRect().height + gap;
    if (!(pitch > 0) || isNaN(avail)) {
      return null;
    }
    // The last row needs no gap after it, hence + gap.
    const n = Math.floor((avail + gap) / pitch);
    return Math.max(PAGE_MIN, Math.min(PAGE_MAX, n));
  } catch (e) {
    return null;
  }
}

/** 1..count, or 1 when there is nothing. */
export function pageCount(total, size) {
  const s = Math.max(1, Number(size) || 1);
  return Math.max(1, Math.ceil((Number(total) || 0) / s));
}

/** Keeps a requested page inside 1..count. */
export function clampPage(page, count) {
  const p = Math.floor(Number(page) || 1);
  return Math.max(1, Math.min(count, p));
}

/** "1–8 of 42" (en dash), or "0 of 0". */
export function pageInfo(page, size, total) {
  const t = Number(total) || 0;
  if (!t) {
    return "0 of 0";
  }
  const start = (page - 1) * size + 1;
  const end = Math.min(t, page * size);
  return `${start}–${end} of ${t}`;
}

/**
 * The page numbers to draw: first, last, the current one and its neighbours,
 * with a gap where numbers are skipped - "1 … 4 5 6 … 12". Every item carries a
 * key for the template; number items carry `n`, `current` ("page" | "false")
 * and a class; gap items carry `gap: true`.
 */
export function pageItems(current, count) {
  const nums = [];
  if (count <= 7) {
    for (let i = 1; i <= count; i++) {
      nums.push(i);
    }
  } else {
    nums.push(1);
    let lo = Math.max(2, current - 1);
    let hi = Math.min(count - 1, current + 1);
    // Keep the window three wide near either end so the bar does not jump.
    if (current <= 3) {
      lo = 2;
      hi = 4;
    } else if (current >= count - 2) {
      lo = count - 3;
      hi = count - 1;
    }
    if (lo > 2) {
      nums.push("gap-lo");
    }
    for (let i = lo; i <= hi; i++) {
      nums.push(i);
    }
    if (hi < count - 1) {
      nums.push("gap-hi");
    }
    nums.push(count);
  }
  return nums.map((n) =>
    typeof n === "string"
      ? { key: n, gap: true }
      : {
          key: "p" + n,
          n,
          gap: false,
          current: n === current ? "page" : "false",
          cls: n === current ? "pager__btn pager__num is-current" : "pager__btn pager__num",
          label: "Page " + n
        }
  );
}