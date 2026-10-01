/**
 * Quote an offer - preview the PDF and email it, without booking anything.
 *
 * Version  Author      Date         Detail
 * 2.5      Aurelix Dev 02 Sep 2026  MSC-225a. WhatsApp moves to the right of Email offer.
 * 2.4      Aurelix Dev 02 Sep 2026  MSC-225. A WhatsApp control beside the send: it opens a chat
 *                                   on the customer's number in a new tab and sends nothing.
 * 2.1      Aurelix Dev 16 Aug 2026  The PDF is requested from the site's own origin (previewBase).
 * 2.0      Aurelix Dev 16 Aug 2026  This component is the drawer, mounted at .page; the button is the parent's.
 * 1.1      Aurelix Dev 16 Aug 2026  One button on the card, the rest in a drawer.
 * 1.0      Aurelix IT  13 Aug 2026  Initial.
 *
 * The document is Modon's Visualforce PDF (OfferDetailsPDF_v1, or OfferDetailsPDF for YAMM and
 * Ras El Hekma). Sending is UnitSearchLwcController.sendSalesOfferPDF, which returns void.
 */

import { LightningElement, api } from "lwc";
import { LABELS } from "c/mscLabels";

/* the projects still on the older page */
const OLDER_OFFER_PROJECTS = [
  "YAMM",
  "Ras El Hekma, Egypt",
  "Ras El Hekma, Egypt(Egypt Only)"
];

export default class MscOffer extends LightningElement {
  @api opportunityId;
  @api unitId;
  @api unitName;
  @api projectName;
  @api planId;
  /** Falls back to the account name server-side. */
  @api customerName;
  /** 2.4: the customer's mobile as stored; the WhatsApp link is built from it. */
  @api customerMobile;
  /** Salesforce base URL, from the OrgURL label via the parent. */
  @api orgUrl;
  /** The site's URL path prefix ('/sales', '' at the root); null outside a site. */
  @api sitePrefix;
  @api busy = false;
  /** Set by the parent once sendSalesOfferPDF returns. */
  @api sentTo;
  /** The parent owns whether this is open. */
  @api open = false;

  labels = LABELS;

  nameDraft;

  connectedCallback() {
    this.nameDraft = this.customerName;
  }

  /** Re-seeded each open unless the rep typed their own. */
  renderedCallback() {
    if (this.open && !this._nameTouched && this.nameDraft !== this.customerName) {
      this.nameDraft = this.customerName;
    }
    this.armFrameTimeout();
  }

  /* the loader covers the frame until the PDF is there; keyed on the src */
  _loadedSrc;

  get showFrameLoader() {
    const src = this.previewSrc;
    return !!src && this._loadedSrc !== src;
  }

  handleFrameLoad() {
    this._loadedSrc = this.previewSrc;
    this.clearFrameTimeout();
  }

  /** A stuck loader is worse than the flash; reveal after a timeout whatever happened. */
  armFrameTimeout() {
    const src = this.previewSrc;
    if (!src || src === this._timedSrc) {
      return;
    }
    this._timedSrc = src;
    this.clearFrameTimeout();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._frameTimer = setTimeout(() => {
      this._frameTimer = null;
      this._loadedSrc = src;
    }, 12000);
  }

  clearFrameTimeout() {
    if (this._frameTimer) {
      clearTimeout(this._frameTimer);
      this._frameTimer = null;
    }
  }

  disconnectedCallback() {
    this.clearFrameTimeout();
  }

  /** Names what the document is about. */
  get offerSubtitle() {
    const bits = [this.unitName, this.projectName].filter(Boolean);
    return bits.length ? bits.join(" · ") : null;
  }

  /* routed up: the parent owns `open` */
  handleClose() {
    this.dispatchEvent(new CustomEvent("closeoffer", { bubbles: true, composed: true }));
  }

  get ready() {
    return !!this.opportunityId && !!this.unitId && !!this.planId;
  }

  get isOlderOfferProject() {
    return OLDER_OFFER_PROJECTS.indexOf(this.projectName) !== -1;
  }

  /**
   * Where the PDF is requested from: in a site, the site's own origin with the server's
   * urlPathPrefix (a bare /apex/ 301s into the Broker Portal; the browsed /sales path does not
   * serve Visualforce). Outside a site, the Visualforce domain.
   */
  get previewBase() {
    if (typeof this.sitePrefix !== "string") {
      return this.vfBase || null;
    }
    if (this.sitePrefix !== "") {
      return this.sitePrefix;
    }
    /* in a site with no prefix named: the domain root */
    const path = (window.location && window.location.pathname) || "";
    const first = path.split("/")[1] || "";
    return !first || first === "s" ? "" : `/${first}`;
  }

  /** My Domain refuses to be framed, so outside a site use the Visualforce domain. */
  get vfBase() {
    let base = this.orgUrl || "";
    try {
      const url = new URL(base);
      let host = url.hostname;
      if (host.indexOf(".sandbox.my.salesforce.com") !== -1) {
        host = host.replace(".sandbox.my.salesforce.com", "--c.sandbox.vf.force.com");
        base = `${url.protocol}//${host}`;
      } else if (host.indexOf(".my.salesforce.com") !== -1) {
        host = host.replace(".my.salesforce.com", "--c.vf.force.com");
        base = `${url.protocol}//${host}`;
      }
    } catch (e) {
      // an unparseable OrgURL is left alone
    }
    return base;
  }

  get previewSrc() {
    const base = this.previewBase;
    /* `base` is '' for a site at the root, so the test is for null */
    if (!this.ready || base === null || base === undefined) return null;
    const page = this.isOlderOfferProject ? "OfferDetailsPDF" : "OfferDetailsPDF_v1";
    const cust = encodeURIComponent(this.nameDraft || "");
    let src =
      `${base}/apex/${page}` +
      `?id=${this.opportunityId}` +
      `&currentUnit=${this.unitId}` +
      `&selectedPayment=${this.planId}` +
      `&customerName=${cust}` +
      `&unitOption=`;
    if (!this.isOlderOfferProject) {
      src += "&selectedDesign=&dpgLink=";
    }
    return src;
  }

  /**
   * 2.4: wa.me takes digits only - no plus, no spaces, no dashes. The number is used exactly
   * as the account stores it: a missing country code is NOT filled in, because guessing one
   * opens a chat with whoever owns that number in the guessed country.
   */
  get waDigits() {
    const digits = String(this.customerMobile || "").replace(/\D/g, "");
    /* 00 is the international prefix spelled out; no country code begins with 0 */
    const trimmed = digits.indexOf("00") === 0 ? digits.slice(2) : digits;
    /* c/mscConsole's own floor for "is this a phone number at all" */
    return trimmed.length >= 7 ? trimmed : null;
  }

  /** Null hides the control: a link to nowhere is worse than no link. */
  get waHref() {
    const digits = this.waDigits;
    return digits ? `https://wa.me/${digits}` : null;
  }

  get sendLabel() {
    return this.busy ? LABELS.OFFER_SENDING : LABELS.OFFER_SEND;
  }

  get sendDisabled() {
    return this.busy || !this.ready;
  }

  get sentNote() {
    return this.sentTo ? `Offer emailed to ${this.sentTo}.` : null;
  }

  handleName(event) {
    this._nameTouched = true;
    this.nameDraft = event.target.value;
  }

  handleSend() {
    if (this.sendDisabled) return;
    this.dispatchEvent(
      new CustomEvent("sendoffer", {
        detail: { customerName: this.nameDraft },
        bubbles: true,
        composed: true
      })
    );
  }
}