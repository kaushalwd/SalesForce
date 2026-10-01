/**
 * Modon Sales Console - theme tokens.
 *
 * Version  Author      Date         Detail
 * 1.5      Aurelix Dev 31 Aug 2026  MSC-184. --page-gradient and --page-overlay; page ground reset.
 * 1.5      Aurelix Dev 20 Sep 2026  SCW-127. --input-bg-solid: an opaque field background for
 *                                   the autofill overpaint. Additive; nothing else reads it.
 * 1.4      Aurelix Dev 22 Aug 2026  MSC-111. --control-scheme and --chevron.
 * 1.3      Aurelix IT  20 Aug 2026  MSC-081. --seg-*, --edge-*, --wash-green.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

/**
 * CSS custom properties on the app host; they pierce Shadow DOM. Never hardcode a colour.
 * Do not import any mbp* bundle here.
 */
const TOKENS = {
  dark: {
    /* MSC-184: the page ground and the gradient's bottom stop. Stays a solid colour: applyTokens
       writes it into --dxp-g-root, which takes a colour and drops a gradient. */
    "--page-bg": "#08090b",
    /* MSC-184: the .bg layer, replacing the hero render */
    "--page-gradient": "linear-gradient(180deg, #1a1e24 0%, #08090b 100%)",
    /* MSC-184: the tint over it; the render needed one, the gradient does not. Not --overlay,
       which is the sheet and loader scrim. */
    "--page-overlay": "transparent",
    // deep enough that text with no surface stays readable over the backdrop
    "--overlay": "rgba(0,0,0,0.58)",
    "--surface": "rgba(15,15,15,0.68)",
    "--surface-border": "rgba(255,255,255,0.16)",
    /* an opaque panel floating over a scrim: the drawer, the verification dialog */
    "--panel-bg": "#141414",
    /* the card still waiting on the rep; mirrored in light because applyTokens never clears */
    "--section-active-border": "rgba(255,255,255,0.42)",
    "--bar": "#111",
    "--bar-border": "rgba(255,255,255,0.12)",
    "--text": "#fafafa",
    "--text-muted": "#a3a3a3",
    /* UI-14: the eyebrow sits on the backdrop photo, so light text needs a shadow here */
    "--eyebrow-shadow": "0 1px 4px rgba(0,0,0,0.55)",
    // the uppercase micro-labels; ~5.2:1 on the card surface
    "--text-dim": "#8a8a8a",
    "--input-bg": "rgba(255,255,255,0.06)",
    "--input-border": "rgba(255,255,255,0.16)",
    /* SCW-127: the OPAQUE equivalent of a field's background on a card, for the one thing a
       translucent token cannot serve - the inset shadow that paints over Chrome's autofill
       colours. --input-bg over --surface over --page-bg, flattened. */
    "--input-bg-solid": "#1c1c1d",
    /* MSC-111: what the UA paints native control internals with */
    "--control-scheme": "dark",
    /* MSC-111: the select chevron, per theme */
    "--chevron": "url(data:image/svg+xml,%3Csvg%20xmlns=%27http://www.w3.org/2000/svg%27%20width=%2712%27%20height=%2712%27%20viewBox=%270%200%2024%2024%27%20fill=%27none%27%20stroke=%27%23a3a3a3%27%20stroke-width=%272%27%20stroke-linecap=%27round%27%20stroke-linejoin=%27round%27%3E%3Cpolyline%20points=%276%209%2012%2015%2018%209%27/%3E%3C/svg%3E)",
    // the summary rail is pinned over scrolling content, so more opaque
    "--rail-bg": "rgba(10,10,10,0.88)",
    "--rail-border": "rgba(255,255,255,0.18)",
    "--row-bg": "rgba(255,255,255,0.03)",
    "--divider": "rgba(255,255,255,0.13)",
    "--text-inverse": "#111",
    // action pill: outlined, never filled
    "--pill-bg": "transparent",
    "--pill-fg": "#fafafa",
    "--pill-border": "#fafafa",
    /* semantic status colours, defined in both sets: applyTokens only sets properties, and the
       fallbacks had drifted */
    "--chip-green": "#4ade80",
    "--chip-red": "#f87171",
    "--chip-amber": "#fbbf24",
    "--chip-blue": "#60a5fa",
    "--chip-purple": "#a78bfa",
    "--tab-inactive": "rgba(255,255,255,0.35)",
    "--tab-active": "#fafafa",
    // section states
    "--step-done": "#16a34a",
    "--step-future": "rgba(255,255,255,0.08)",
    "--step-locked": "rgba(255,255,255,0.04)",
    /* restrained platinum, not a literal gold; per theme */
    "--gold": "#a8a8a8",
    /* the selected-row wash; a token rather than color-mix() */
    "--gold-wash": "rgba(168,168,168,0.10)",
    /* MSC-081: the ownership meter; steps from --gold, --seg-free is the unallocated tail */
    "--seg-1": "rgba(250,250,250,0.46)",
    "--seg-2": "rgba(250,250,250,0.28)",
    "--seg-3": "rgba(250,250,250,0.18)",
    "--seg-free": "rgba(250,250,250,0.08)",
    /* semantic borders, at the weight a 1px edge needs */
    "--edge-green": "rgba(74,222,128,0.34)",
    "--edge-amber": "rgba(251,191,36,0.44)",
    "--edge-blue": "rgba(96,165,250,0.34)",
    "--edge-red": "rgba(248,113,113,0.34)",
    /* the found-person card's ground */
    "--wash-green": "rgba(74,222,128,0.07)",
    "--focus-ring": "#fafafa",
    // the page backdrop, as a token
    "--backdrop": "radial-gradient(120% 80% at 50% 0%, #141414 0%, #000 60%)"
  },
  light: {
    // MSC-184: mirrors the dark keys
    "--page-bg": "#e7e3dc",
    "--page-gradient": "linear-gradient(180deg, #f5f3ef 0%, #e7e3dc 100%)",
    "--page-overlay": "transparent",
    "--overlay": "rgba(240,237,233,0.7)",
    "--surface": "rgba(255,255,255,0.88)",
    "--surface-border": "rgba(0,0,0,0.14)",
    /* the page value, so a panel matches the modals and the cards on it keep their contrast */
    "--panel-bg": "#e7e3dc",
    // mirrors the dark key
    "--section-active-border": "rgba(0,0,0,0.34)",
    "--bar": "rgba(255,255,255,0.96)",
    "--bar-border": "rgba(0,0,0,0.15)",
    "--text": "#0f0f0f",
    "--text-muted": "#2e2e2e",
    /* UI-14: dark text on a light page; the same shadow read as a smudge */
    "--eyebrow-shadow": "none",
    // on light surfaces contrast improves by going down
    "--text-dim": "#4a4a4a",
    "--input-bg": "rgba(0,0,0,0.05)",
    /* SCW-127: see the dark set */
    "--input-bg-solid": "#efeeed",
    "--input-border": "rgba(0,0,0,0.20)",
    // MSC-111: mirrors the dark keys
    "--control-scheme": "light",
    "--chevron": "url(data:image/svg+xml,%3Csvg%20xmlns=%27http://www.w3.org/2000/svg%27%20width=%2712%27%20height=%2712%27%20viewBox=%270%200%2024%2024%27%20fill=%27none%27%20stroke=%27%234a4a4a%27%20stroke-width=%272%27%20stroke-linecap=%27round%27%20stroke-linejoin=%27round%27%3E%3Cpolyline%20points=%276%209%2012%2015%2018%209%27/%3E%3C/svg%3E)",
    "--rail-bg": "rgba(255,255,255,0.94)",
    "--rail-border": "rgba(0,0,0,0.15)",
    "--row-bg": "rgba(0,0,0,0.04)",
    "--divider": "rgba(0,0,0,0.14)",
    "--text-inverse": "#fff",
    "--pill-bg": "transparent",
    "--pill-fg": "#0f0f0f",
    "--pill-border": "#0f0f0f",
    // semantic status chips, mirrored key-for-key
    "--chip-green": "#16a34a",
    "--chip-red": "#dc2626",
    "--chip-amber": "#d97706",
    "--chip-blue": "#2563eb",
    "--chip-purple": "#7c3aed",
    "--tab-inactive": "rgba(0,0,0,0.32)",
    "--tab-active": "#0f0f0f",
    "--step-done": "#15803d",
    "--step-future": "rgba(0,0,0,0.08)",
    "--step-locked": "rgba(0,0,0,0.04)",
    /* the dark theme's #a8a8a8 fails on this page-bg; darkened to the same warm platinum */
    "--gold": "#6f6558",
    "--gold-wash": "rgba(111,101,88,0.10)",
    // MSC-081: mirrors the dark keys, inverted
    "--seg-1": "rgba(15,15,15,0.46)",
    "--seg-2": "rgba(15,15,15,0.28)",
    "--seg-3": "rgba(15,15,15,0.18)",
    "--seg-free": "rgba(15,15,15,0.08)",
    "--edge-green": "rgba(22,163,74,0.36)",
    "--edge-amber": "rgba(217,119,6,0.46)",
    "--edge-blue": "rgba(37,99,235,0.34)",
    "--edge-red": "rgba(220,38,38,0.34)",
    "--wash-green": "rgba(22,163,74,0.07)",
    "--focus-ring": "#0f0f0f",
    // the same warm off-white the light page-bg uses
    "--backdrop": "radial-gradient(120% 80% at 50% 0%, #ffffff 0%, #f0ede9 60%)"
  }
};

/** Restrained platinum-grey. */
const DEFAULT_ACCENT = "#a8a8a8";

/** Backdrop when no image is configured: a token gradient, never a resourceUrl. */
const DEFAULT_BACKDROP =
  "radial-gradient(120% 80% at 50% 0%, #141414 0%, #000 60%)";

/**
 * Serialise a token set into an inline style string for :host.
 * @param {'dark'|'light'} theme
 * @param {string} accentColor
 */
function hostStyle(theme, accentColor) {
  const set = TOKENS[theme] || TOKENS.dark;
  const decls = Object.keys(set).map((k) => `${k}:${set[k]}`);
  /* a configured accent wins; otherwise the theme's gold */
  if (accentColor) decls.push(`--gold:${accentColor}`);
  return decls.join(";");
}

/**
 * Writes tokens onto a DOM element (documentElement). Emitted with an --msc- prefix as well
 * as bare names.
 */
function applyTokens(element, theme, accentColor) {
  if (!element || !element.style) return;
  const set = TOKENS[theme] || TOKENS.dark;
  Object.keys(set).forEach((k) => {
    element.style.setProperty(k, set[k]);
    element.style.setProperty(k.replace(/^--/, "--msc-"), set[k]);
  });
  const accent = accentColor || set["--gold"] || DEFAULT_ACCENT;
  element.style.setProperty("--gold", accent);
  element.style.setProperty("--msc-gold", accent);

  // map the LWR branding tokens so platform chrome inherits the palette
  element.style.setProperty("--dxp-g-root", set["--page-bg"]);
  element.style.setProperty("--dxp-g-root-contrast", set["--text"]);
  element.style.setProperty("--dxp-g-brand", accent);
  element.style.setProperty("--dxp-g-brand-contrast", set["--text-inverse"]);
}

export { TOKENS, DEFAULT_ACCENT, DEFAULT_BACKDROP, hostStyle, applyTokens };