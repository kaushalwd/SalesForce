/**
 * mscKycCaptureModal - Update KYC, in a dialog, on MODON's own form.
 *
 * Version  Author      Date         Detail
 * 2.7      Aurelix Dev 30 Sep 2026  Escape or a click outside no longer drops what was typed: once the rep has worked
 *                                   in the form they are asked "Close without saving?" first (R2-06).
 * 2.6      Aurelix Dev 24 Sep 2026  The picklist dropdown is finished properly (testing showed a light
 *                                   panel with dark text inside the dark dialog). It is ordinary
 *                                   HTML, not a native select popup, so it can be styled: MODON
 *                                   use lightning-combobox, which renders an SLDS listbox as real
 *                                   elements in the page. 2.0 already painted the panel, but it
 *                                   scored two classes and the site's own
 *                                   dxp-slds-extensions.min.css paints the hovered and highlighted
 *                                   ROW at three, so that row kept the site's near-black text and a
 *                                   3px #005fb2 inset ring, and base-combobox highlights a row the
 *                                   instant the panel opens. Every rule now repeats a class, as
 *                                   2.3 does, and the dropdown's own dxp hooks are set by name in
 *                                   the stylesheet because overriding --dxp-g-root cannot reach
 *                                   them (see the note there). Panel, hover and selected are three
 *                                   steps of the dialog's own grey, no hue.
 * 2.5      Aurelix Dev 24 Sep 2026  The read-only caption is shown again, reversing 2.2. Where
 *                                   MODON lock a field that caption carries the REASON ("Set to
 *                                   Salary because Employment Status is Employed"), so hiding it
 *                                   left the rep an empty box that will not take input and no
 *                                   explanation at all. Shown in the console's muted
 *                                   grey at MODON's own size and spacing, so the form does not
 *                                   move.
 * 2.4      Aurelix Dev 20 Sep 2026  A save covers the whole dialog: their Save button's
 *                                   own disabled state drives a scrim and the console's loader
 *                                   mark over the dialog, so the form cannot read as editable
 *                                   while it is being written.
 * 2.3      Aurelix Dev 20 Sep 2026  Three rules were losing to MODON's own scoped stylesheet and
 *                                   had no effect: the address results read dark-on-dark until
 *                                   hovered, and the section divider kept their light
 *                                   line. A scoped selector's attribute counts as a class, so a
 *                                   descendant selector cannot outrank it; the three repeat a
 *                                   class to score level. See the note above the sheet.
 * 2.2      Aurelix Dev 20 Sep 2026  The "Read only" caption under each disabled field is hidden:
 *                                   the field already reads as inert and the caption
 *                                   only repeats it. Scoped so MODON's villa hint survives.
 * 2.1      Aurelix Dev 20 Sep 2026  The dialog paints with --panel-bg, not the translucent
 *                                   --surface: with MODON's white card gone the page showed
 *                                   straight through it.
 * 2.0      Aurelix Dev 20 Sep 2026  The dialog must look like the rest of the console.
 *                                   The token block on .kycm__body is inverted from 1.2's light
 *                                   values to the console's palette, and the injected sheet now
 *                                   also repaints MODON's own classes (.kyc-card, .card-title,
 *                                   .section-label, .field-note, .geo-results, .error-banner,
 *                                   .btn-save, .btn-cancel) and the SLDS dropdown. Their card
 *                                   loses its white panel and sits on the dialog's surface;
 *                                   Save becomes an outlined button, as everywhere else here.
 * 1.2      Aurelix Dev 18 Sep 2026  Labels inside MODON's form stayed light on its white card
 *                                   whatever hooks the well reset. Proved in the browser: a
 *                                   document-level rule reaches the base components' labels here
 *                                   (the site's shadow trees are synthetic - SLDS is loaded at
 *                                   document level and the console's --page-bg painted the inputs).
 *                                   So the dialog injects ONE scoped stylesheet into document.head,
 *                                   idempotently, exactly as c/mscTokenHost injects its layout fix:
 *                                   under c-msc-kyc-capture-modal only, labels dark, controls light.
 *                                   MODON's stylesheet is still untouched.
 * 1.1      Aurelix Dev 18 Sep 2026  Seen in the browser: hosted inside the KYC panel, the dialog was
 *                                   trapped in the customer card - the booking sheet's transform
 *                                   turns position:fixed into position:absolute. It is now hosted by
 *                                   c/mscBookingPage as a child of .page (position:relative), like
 *                                   the verification dialog, and covers the sheet. And it can tell a
 *                                   save from a cancel: MODON's form raises a ShowToastEvent before
 *                                   `close` on save; the toast bubbles composed through this host,
 *                                   so `close` now carries detail {saved, message}.
 * 1.0      Aurelix Dev 18 Sep 2026  MSC-179 (B4). The console stops rendering its own copy of the
 *                                   KYC capture form. This dialog hosts c/accountkycform - the
 *                                   component the internal app's "Update KYC" quick action runs -
 *                                   unchanged, with record-id set to the subject: the person's own
 *                                   Account, or for a company the authorised POA Contact (which
 *                                   makes MODON's resolveContext return the contact section, its
 *                                   Mailing address, the company fields and the company Billing
 *                                   address). Their field engine, dependent picklists, address
 *                                   lookup and date rules therefore behave exactly as in the app.
 *
 * WHAT THE HOSTED COMPONENT DOES ON SAVE (read from its source): a ShowToastEvent, which an LWR
 * site does not display; a CloseActionScreenEvent, harmless here; and a plain `close` event, which
 * is the one this dialog listens for. Cancel dispatches `close` too. This dialog cannot tell a
 * save from a cancel, so it reports `close` and the opener re-reads the server rather than
 * assuming anything was written.
 *
 * ITS STYLING IS OVERPAINTED, NOT FORKED (2.0). MODON style the form light - white card, blue
 * focus, filled blue Save. On the console's dark site that read as a white island, so this
 * dialog repaints it in the console's palette from two places it owns: the design tokens on
 * .kycm__body (their base components resolve colours from these) and one document-level sheet
 * scoped to this tag (their own classes are painted by class, which a component stylesheet
 * cannot reach here). MODON's stylesheet and component are byte-for-byte untouched, and
 * nothing here can affect their quick action in the staff app.
 *
 * FOCUS. The Close control takes focus on open; Escape closes; the opener is told to take focus
 * back through the `close` event. The dialog is fixed to the viewport and scrolls internally, so
 * a 900px form still works on a phone.
 */
import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/* 1.2 - the document-level, dialog-scoped light scheme. Precedent: c/mscTokenHost.GLOBAL_CSS. */
const OLD_STYLE_ID = "msc-kyc-modal-light";
const STYLE_ID = "msc-kyc-modal-dark";

/*
 * Why a document-level sheet at all: the site's shadow trees are synthetic, SLDS is loaded at
 * document level, and MODON's own stylesheet paints by class. A rule written here, scoped under
 * this dialog's own tag, therefore reaches the form; a rule inside this component's stylesheet
 * does not (proved in the browser, 18 Sep). Every selector below starts with
 * c-msc-kyc-capture-modal, so nothing can touch MODON's quick action in their app, and their
 * stylesheet is not forked - it is overpainted, only here.
 *
 * Specificity, and the trap in it (2.3): a scoped LWC stylesheet compiles every compound
 * selector with an attribute - `.kyc-card[c-accountkycform_...]` - and an attribute counts in
 * the same column as a class. Where they style the classed element itself their rule scores two
 * in that column and mine, `tag .kycm__body .that-class`, scores two as well but wins on the
 * element column. Where they style a DESCENDANT of a classed element the attribute lands on
 * both halves - `.geo-results[scope] li[scope]` is three - and no amount of descendant nesting
 * on my side catches up, because that column is compared first. Those rules repeat a class to
 * score level and then win on elements. Three were affected and all three are marked 2.3.
 */
const DARK_CSS = `
  c-msc-kyc-capture-modal .kycm__body,
  c-msc-kyc-capture-modal .kycm__body legend,
  c-msc-kyc-capture-modal .kycm__body p,
  c-msc-kyc-capture-modal .kycm__body span,
  c-msc-kyc-capture-modal .kycm__body h1,
  c-msc-kyc-capture-modal .kycm__body h2,
  c-msc-kyc-capture-modal .kycm__body h3 { color: #fafafa; }
  c-msc-kyc-capture-modal .kycm__body label,
  c-msc-kyc-capture-modal .kycm__body .slds-form-element__label,
  c-msc-kyc-capture-modal .kycm__body .slds-form-element__legend,
  c-msc-kyc-capture-modal .kycm__body .slds-checkbox__label,
  c-msc-kyc-capture-modal .kycm__body .slds-radio__label { color: #a3a3a3; }
  c-msc-kyc-capture-modal .kycm__body .slds-form-element__help { color: #8a8a8a; }
  c-msc-kyc-capture-modal .kycm__body abbr,
  c-msc-kyc-capture-modal .kycm__body .slds-required { color: #f87171; }

  /* the controls */
  c-msc-kyc-capture-modal .kycm__body input,
  c-msc-kyc-capture-modal .kycm__body select,
  c-msc-kyc-capture-modal .kycm__body textarea,
  c-msc-kyc-capture-modal .kycm__body .slds-input,
  c-msc-kyc-capture-modal .kycm__body .slds-select,
  c-msc-kyc-capture-modal .kycm__body .slds-textarea,
  c-msc-kyc-capture-modal .kycm__body .slds-combobox__input {
    background-color: #1c1c1d; color: #fafafa; border-color: rgba(255, 255, 255, 0.16);
  }
  c-msc-kyc-capture-modal .kycm__body input::placeholder,
  c-msc-kyc-capture-modal .kycm__body textarea::placeholder { color: #8a8a8a; }
  c-msc-kyc-capture-modal .kycm__body input:focus,
  c-msc-kyc-capture-modal .kycm__body select:focus,
  c-msc-kyc-capture-modal .kycm__body textarea:focus,
  c-msc-kyc-capture-modal .kycm__body .slds-input:focus,
  c-msc-kyc-capture-modal .kycm__body .slds-combobox__input:focus {
    border-color: #a8a8a8; box-shadow: 0 0 0 3px rgba(168, 168, 168, 0.16);
  }
  c-msc-kyc-capture-modal .kycm__body input[disabled],
  c-msc-kyc-capture-modal .kycm__body input[readonly],
  c-msc-kyc-capture-modal .kycm__body select[disabled] {
    background-color: rgba(255, 255, 255, 0.03); color: #a3a3a3;
  }
  /* 2.6 - THE PICKLIST DROPDOWN.
     What it is, first, because this project has twice tried to restyle a NATIVE select popup
     and had to revert it: this is not one. MODON's form renders every picklist as
     <lightning-combobox>, and that renders lightning-base-combobox, whose panel is a real
     element in the page,
       <div class="slds-listbox slds-listbox_vertical slds-dropdown slds-dropdown_fluid"
            role="listbox">
     holding one <lightning-base-combobox-item class="slds-media slds-listbox__option">
     per value. CSS reaches it. An OS popup would not have classes to aim at.

     It also stays inside this dialog, so the tag envelope every rule in this sheet uses is
     enough. base-combobox only hands the panel to lightning/positionLibrary, which DOES
     reparent it to document.body, when dropdown-alignment is "auto"; lightning-combobox
     defaults to "left" and MODON do not set it. Nothing here is written wider than the
     envelope, so it cannot reach another console page's comboboxes.

     Why 2.0's version of this block was not enough. The site loads
     dxp-slds-extensions.min.css, which paints the hovered and highlighted row with
       .slds-listbox_vertical .slds-listbox__option:hover / :focus / .slds-has-focus
     That is three classes. 2.0 scored two and lost, so that row kept the site's own
     near-black --dxp-s-dropdown-text-color-hover and a 3px #005fb2 inset ring, and it is the
     row the rep is looking at: base-combobox highlights the current value the moment the
     panel opens. Measured against the site's real stylesheets, not guessed. So every rule
     below repeats .slds-listbox__option to score past them, the same trick as 2.3.

     The palette is three steps of the dialog's own grey and no hue at all: the panel at
     #141414, a hovered row at 6% white over it, the current value at 10% with a muted grey
     rule down its inside edge. Text is #fafafa throughout, which measures 17.65:1 on the
     panel, 15.24:1 on a hovered row and 13.38:1 on the selected one. The inset rule is drawn with a
     shadow, not a border, so no row moves; nothing here sets display, padding or position,
     so the closed state and the layout are exactly as MODON leave them. */
  c-msc-kyc-capture-modal .kycm__body .slds-dropdown.slds-dropdown {
    background-color: #141414;
    color: #fafafa;
    border-color: rgba(255, 255, 255, 0.16);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
  }
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option {
    background-color: transparent;
    color: #fafafa;
  }
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option:hover,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option:focus,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option.slds-has-focus {
    background-color: rgba(255, 255, 255, 0.06);
    color: #fafafa;
    box-shadow: none;
    outline: 0;
  }
  /* the value already on the record. lightning-combobox marks it with aria-checked and its
     own tick; older base-combobox variants use aria-selected, so both are listed. */
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-checked="true"],
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-selected="true"] {
    background-color: rgba(255, 255, 255, 0.1);
    color: #fafafa;
    box-shadow: inset 2px 0 0 0 #8a8a8a;
  }
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-checked="true"]:hover,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-selected="true"]:hover,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-checked="true"].slds-has-focus,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option[aria-selected="true"].slds-has-focus {
    background-color: rgba(255, 255, 255, 0.13);
    color: #fafafa;
    box-shadow: inset 2px 0 0 0 #a3a3a3;
  }
  /* their tick is Salesforce blue by default; sub-text and a grouped picklist's heading are
     the console's two muted greys */
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option .slds-listbox__option-icon,
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-is-selected .slds-listbox__option-icon {
    color: #a3a3a3;
  }
  c-msc-kyc-capture-modal .kycm__body .slds-listbox__option.slds-listbox__option .slds-listbox__option-meta {
    color: #8a8a8a;
  }
  c-msc-kyc-capture-modal .kycm__body .slds-dropdown.slds-dropdown .slds-listbox__option-header {
    color: #8a8a8a;
  }

  /* MODON's own card chrome, by their class names */
  c-msc-kyc-capture-modal .kycm__body .kyc-card {
    background: transparent; border: 0; padding: 4px 4px 0;
  }
  c-msc-kyc-capture-modal .kycm__body .card-title { color: #fafafa; }
  c-msc-kyc-capture-modal .kycm__body .card-subtitle,
  c-msc-kyc-capture-modal .kycm__body .section-label,
  c-msc-kyc-capture-modal .kycm__body .field-note,
  c-msc-kyc-capture-modal .kycm__body .field-count { color: #8a8a8a; }
  c-msc-kyc-capture-modal .kycm__body .footer-actions {
    border-top-color: rgba(255, 255, 255, 0.13);
  }
  /* 2.4 - a save takes over the whole dialog, not just its button.
     MODON's Save carries its own x-small spinner and disables itself while isSaving is true,
     which on a dialog this tall is easy to miss and leaves the form looking editable while it
     is not. Their button is the SIGNAL, not the display: the disabled attribute is on it
     exactly while the save runs, so :has() drives a scrim and the console's own loader mark
     over the dialog, and drops both the moment they re-enable it. Nothing observes, nothing
     times out, nothing can stick - if :has() is unavailable the dialog simply behaves as it
     did before. The mark is the one in c/mscLoader, as a data URI because a pseudo-element
     cannot hold markup; the rotation is on the box, and the mark is centred in it, so it
     turns about its own centre. */
  c-msc-kyc-capture-modal .kycm:has(.btn-save:disabled)::after {
    content: "";
    position: absolute;
    inset: 0;
    z-index: 5;
    border-radius: 12px;
    background: rgba(0, 0, 0, 0.58);
    -webkit-backdrop-filter: blur(8px);
    backdrop-filter: blur(8px);
  }
  c-msc-kyc-capture-modal .kycm:has(.btn-save:disabled)::before {
    content: "";
    position: absolute;
    inset: 0;
    z-index: 6;
    background-image: url("data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20.03 20" fill="%23fafafa"><g transform="translate(-23.27 0)"><path d="M39.2272 1.83225C39.2186 1.82522 39.2069 1.81662 39.1983 1.80959C39.0889 1.74318 38.9467 1.75802 38.853 1.84944C38.8389 1.86272 38.828 1.87678 38.8217 1.88928C38.8061 1.90725 38.7975 1.92679 38.7889 1.9471L36.8489 5.51222C36.8372 5.52785 36.8286 5.54347 36.8223 5.56066C36.7825 5.66145 36.7997 5.78099 36.8825 5.86381C37.8935 6.82326 38.4748 8.2515 38.4748 9.97273C38.4748 13.1956 36.4106 15.4263 33.2705 15.4263C30.1304 15.4263 28.0904 13.1956 28.0904 9.97273C28.0904 8.30697 28.6334 6.92171 29.5827 5.9646C29.6632 5.88179 29.6835 5.76146 29.6429 5.66146C29.6366 5.6427 29.6249 5.62552 29.614 5.60755L27.6568 2.01586C27.6505 1.99789 27.6388 1.97992 27.6302 1.96195C27.6193 1.94866 27.6083 1.93538 27.5966 1.92366C27.506 1.83225 27.363 1.8174 27.2568 1.87834C27.2364 1.89241 27.2193 1.90569 27.2013 1.92132C24.8097 3.70115 23.2705 6.55762 23.2705 9.97195C23.2705 15.7841 27.7334 19.9977 33.2713 19.9977C38.8092 19.9977 43.2971 15.7849 43.2971 9.97195C43.2971 6.50215 41.6962 3.6027 39.228 1.8299L39.2272 1.83225Z"/><path d="M33.2331 4.6612C33.2448 4.6612 33.2558 4.65964 33.2683 4.65964C33.2855 4.65964 33.3019 4.6612 33.3191 4.66198C34.5863 4.64167 35.6083 3.61034 35.6083 2.33837C35.6083 1.06639 34.5676 0.0131836 33.2831 0.0131836C31.9986 0.0131836 30.9572 1.05389 30.9572 2.33837C30.9572 3.62284 31.9721 4.63464 33.2331 4.6612Z"/></g></svg>");
    background-repeat: no-repeat;
    background-position: center;
    background-size: 44px 44px;
    animation: kycmMarkSpin 1.4s linear infinite, kycmMarkPulse 1.4s ease-in-out infinite;
  }
  @keyframes kycmMarkSpin { to { transform: rotate(360deg); } }
  @keyframes kycmMarkPulse { 0%, 100% { opacity: 0.55; } 50% { opacity: 1; } }
  /* the same concession c/mscLoader makes: the overlay still appears and still blocks,
     only the movement stops */
  @media (prefers-reduced-motion: reduce) {
    c-msc-kyc-capture-modal .kycm:has(.btn-save:disabled)::before { animation: none; opacity: 0.9; }
  }

  /* 2.3 - the doubled class is deliberate, see the note on specificity below. */
  c-msc-kyc-capture-modal .kycm__body .form-section + .form-section.form-section {
    border-top-color: rgba(255, 255, 255, 0.13);
  }
  /* 2.5 - the caption under every disabled field is shown again, reversing 2.2. It is not
     always the bare "Read only": where MODON lock a field they put the REASON in it, for
     example "Set to Salary because Employment Status is Employed". Hiding it left the rep an
     empty box that will not take input and nothing at all to say why.
     The selector still has to be exact - their template uses .field-note twice, and the other
     one is the villa hint ("Added to the start of the street line when you save"), which is
     visible already. The read-only note follows a lightning-input carrying data-field; the
     villa input carries data-section and no data-field.
     Quiet, not loud: MODON's own size, leading and margin, so the cell grows by exactly what
     it grows by in the staff app and nothing else on the row moves; the colour is the
     console's muted grey rather than their #706e6b, which is near invisible on #141414. */
  c-msc-kyc-capture-modal .kycm__body lightning-input[data-field] + .field-note {
    display: block;
    font-size: 11px;
    line-height: 1.3;
    margin: 3px 0 0;
    color: #8a8a8a;
  }
  c-msc-kyc-capture-modal .kycm__body .inline-error { color: #f87171; }
  c-msc-kyc-capture-modal .kycm__body .error-banner,
  c-msc-kyc-capture-modal .kycm__body .fatal-error {
    background: rgba(248, 113, 113, 0.08); border-color: rgba(248, 113, 113, 0.34); color: #f87171;
  }
  c-msc-kyc-capture-modal .kycm__body .geo-results {
    background: #141414; border-color: rgba(255, 255, 255, 0.13);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
  }
  /* 2.3 - .geo-results twice, again for specificity: their rule for the ROW is
     .geo-results[scope] li[scope], and the scoping attributes outweigh a plain descendant
     selector however long it is. Without this the result text stayed their #181818 on the
     dark panel - invisible until hovered, when their own light hover background made it
     readable again, which is exactly what testing showed. */
  c-msc-kyc-capture-modal .kycm__body .geo-results.geo-results li { color: #fafafa; }
  c-msc-kyc-capture-modal .kycm__body .geo-results.geo-results li:hover,
  c-msc-kyc-capture-modal .kycm__body .geo-results.geo-results li:focus {
    background: rgba(255, 255, 255, 0.06); color: #fafafa;
  }

  /* their buttons, in the console's own shape: outlined, never filled - the rule the rest of
     the site follows so a dialog's Save never outweighs the step's own Continue */
  c-msc-kyc-capture-modal .kycm__body .btn-cancel {
    background: transparent; color: #fafafa; border-color: rgba(255, 255, 255, 0.16);
  }
  c-msc-kyc-capture-modal .kycm__body .btn-save {
    background: transparent; color: #fafafa;
    border: 1px solid #a3a3a3;
  }
  c-msc-kyc-capture-modal .kycm__body .btn-cancel:hover:not(:disabled),
  c-msc-kyc-capture-modal .kycm__body .btn-save:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.06);
  }
  c-msc-kyc-capture-modal .kycm__body .btn-save:disabled,
  c-msc-kyc-capture-modal .kycm__body .btn-cancel:disabled {
    background: transparent; color: #8a8a8a;
    border-color: rgba(255, 255, 255, 0.13); opacity: 1;
  }
`;

function ensureDarkStyle() {
  try {
    if (typeof document === "undefined" || !document.head) {
      return;
    }
    /* 1.2's light sheet, if this tab has been through the old build in the same SPA session:
       two sheets fighting would be worse than either. */
    const stale = document.getElementById(OLD_STYLE_ID);
    if (stale && stale.parentNode) {
      stale.parentNode.removeChild(stale);
    }
    if (document.getElementById(STYLE_ID)) {
      return;
    }
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = DARK_CSS;
    document.head.appendChild(style);
  } catch (e) {
    /* cosmetic only - the form still works with MODON's own colours */
  }
}

/* 2.7 - the one question before an unsaved form is closed */
const TEXT = {
  ASK: "Close without saving?",
  DISCARD: "Close",
  KEEP: "Keep editing"
};

export default class MscKycCaptureModal extends LightningElement {
  labels = LABELS;

  /** 2.7 - true once the rep has typed, clicked or picked inside MODON's form in this opening. */
  _touched = false;
  /** 2.7 - the question is on screen. */
  confirmClose = false;
  _focusKeep = false;

  get text() {
    return TEXT;
  }

  /** The Account (person) or Contact (POA) the form opens on. */
  @api subjectId;
  /** Who the form is about, for the title. */
  @api subjectName;

  _open = false;
  _focusPending = false;
  /** 1.1 - true once MODON's form raised its success toast in this opening. */
  _saved = false;
  _savedMessage;
  _toastBound = false;

  @api
  get open() {
    return this._open;
  }
  set open(value) {
    const next = !!value;
    if (next && !this._open) {
      this._focusPending = true;
      this._saved = false;
      this._savedMessage = undefined;
      this._toastBound = false;
      this._touched = false;
      this.confirmClose = false;
    }
    this._open = next;
  }

  /** 1.1 - MODON's toast never displays in an LWR site, but its event still passes through here. */
  handleToast = (event) => {
    const d = (event && event.detail) || {};
    if (String(d.variant || "").toLowerCase() === "success") {
      this._saved = true;
      this._savedMessage = d.message || d.title || null;
    }
  };

  get title() {
    const base = this.labels.KYCM_TITLE;
    return this.subjectName ? `${base} · ${this.subjectName}` : base;
  }

  get show() {
    return this._open && !!this.subjectId;
  }

  connectedCallback() {
    ensureDarkStyle();
  }

  renderedCallback() {
    if (this._open && !this._toastBound) {
      const form = this.template.querySelector("c-accountkycform");
      if (form) {
        form.addEventListener("lightning__showtoast", this.handleToast);
        this._toastBound = true;
      }
    }
    /* 2.7 - the question takes focus on its safe answer */
    if (this._focusKeep) {
      const keep = this.template.querySelector(".kycm__btn--keep");
      if (keep) {
        keep.focus();
        this._focusKeep = false;
      }
    }
    if (!this._focusPending || !this._open) {
      return;
    }
    const btn = this.template.querySelector(".kycm__close");
    if (btn) {
      btn.focus();
      this._focusPending = false;
    }
  }

  /** 2.7 - any typing, click or pick inside the form. */
  markTouched() {
    this._touched = true;
  }

  handleBodyKey(event) {
    const k = event.key || "";
    if (k.length === 1 || k === "Backspace" || k === "Delete") {
      this._touched = true;
    }
  }

  /**
   * 2.7 - R2-06: Escape closes at once only while nothing has been done in the form; after that it
   * asks. Escape on the question keeps the form.
   */
  handleKey(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      if (this.confirmClose) {
        this.handleKeep();
        return;
      }
      this.closeOrAsk();
    }
  }

  /** The backdrop closes; a click inside the dialog does not. 2.7: asks first, as Escape does. */
  handleBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.closeOrAsk();
    }
  }

  closeOrAsk() {
    if (this._touched) {
      this.confirmClose = true;
      this._focusKeep = true;
      return;
    }
    this.close();
  }

  handleDiscard() {
    this.close();
  }

  handleKeep() {
    this.confirmClose = false;
  }

  /** 2.7 - the header's Close asks too while something typed is unsaved. */
  handleClose() {
    if (this._saved) {
      this.close();
      return;
    }
    this.closeOrAsk();
  }

  /** The hosted form's own `close` - after a save or a cancel alike. */
  handleFormClose() {
    this.close();
  }

  close() {
    if (!this._open) {
      return;
    }
    this.confirmClose = false;
    this._open = false;
    this.dispatchEvent(
      new CustomEvent("close", { detail: { saved: this._saved, message: this._savedMessage } })
    );
  }
}