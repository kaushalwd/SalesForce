/**
 * EOI journey - step 3, Details.
 *
 * Version  Author      Date         Detail
 * 1.4      Aurelix Dev 29 Sep 2026  Send link only: the Pay now / Send link segment is gone and the
 *                                   button reads as in the Sales App's eoiHomeJourney. checkoutMethod
 *                                   stays an @api but nothing reads it.
 * 1.3      Aurelix Dev 02 Sep 2026  MSC-228 polish. The Payment card is gone: with one payment
 *                                   rail there is nothing to choose there, so the Pay now /
 *                                   Send link segment moved into the summary rail, directly
 *                                   above the button it changes. The hint line went with it -
 *                                   the button label says what happens. paymentType stays an
 *                                   @api (the orchestrator still passes it; isOnline reads it).
 * 1.2      Aurelix Dev 02 Sep 2026  MSC-228. Client reversal of MSC-227: card-only, pay-first
 *                                   through Checkout. The Pay now / Send link choice is back
 *                                   (single selection only; several selections always send
 *                                   links), the payment-type segment disappears when there is
 *                                   only one type to offer, and the hint + submit say what
 *                                   truly happens: nothing is created until a payment captures.
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-227. Online collects through ModonPay: the Pay now /
 *                                   Send link choice (Checkout) is gone from the payment
 *                                   card, the hint says what actually happens, and the
 *                                   submit reads "Create EOI & send to ModonPay". The
 *                                   orchestrator owns the flow; this file only stopped
 *                                   drawing a choice that no longer exists.
 * 1.0      Aurelix IT  17 Aug 2026  Initial. Unit selections (phase -> type -> bedrooms ->
 *                                   typology -> amount from the range matrix), payment
 *                                   type, summary rail and the one action.
 *
 * Dumb: props in, events out. The cascade itself is resolved by the orchestrator through
 * mscEoiUtils.applySelectionChange; this file only draws each selection card and raises
 * `selectionchange {key, field, value}`.
 */

import { LightningElement, api } from "lwc";
import { formatAED } from "c/modonSalesFormat";
import { selectionSummary, isSelectionComplete } from "c/mscEoiUtils";

export default class MscEoiDetails extends LightningElement {
  @api projectName = "";
  @api customerName = "";
  @api phaseOptions = [];
  @api selections = [];
  @api activeKey = "";
  @api paymentType = "";
  @api paymentTypeOptions = [];
  @api checkoutMethod = "send";
  @api sentLinks = {};
  @api linkErrors = {};
  @api totalLabel = "";
  @api quotaText = "";
  @api quotaCountError = false;
  @api quotaCountErrorText = "";
  @api projectClosed = false;
  @api projectClosedText = "";
  @api addDisabled = false;
  @api submitDisabled = false;
  @api busy = false;

  // ── Derived ──────────────────────────────────────────────────────────────

  get isOnline() {
    return this.paymentType === "Online";
  }
  get isSingle() {
    return (this.selections || []).length === 1;
  }
  get count() {
    return (this.selections || []).length;
  }
  get countLabel() {
    return this.count === 1 ? "1 unit" : `${this.count} units`;
  }

  get metaLabel() {
    return [this.countLabel, this.quotaText].filter(Boolean).join(" · ");
  }

  get cards() {
    const withOpts = (options, value) => (options || []).map((o) => ({ ...o, selected: o.value === value }));
    return (this.selections || []).map((s, i) => {
      const summary = selectionSummary(s, this.projectName);
      const active = s.key === this.activeKey;
      const complete = isSelectionComplete(s);
      const sent = Boolean((this.sentLinks || {})[s.key]);
      const linkError = (this.linkErrors || {})[s.key] || "";
      return {
        ...s,
        n: i + 1,
        title: `Unit ${i + 1}`,
        active,
        complete,
        sent,
        linkError,
        cls: `sel${active ? " sel--active" : ""}${complete ? " sel--complete" : ""}`,
        summaryTitle: summary.title,
        summarySubtitle: summary.subtitle,
        amountLabel: s.eoiAmount ? formatAED(s.eoiAmount) : "",
        amountOrDash: s.eoiAmount ? formatAED(s.eoiAmount) : "-",
        phaseOpts: withOpts(this.phaseOptions, s.phaseId),
        typeOpts: withOpts(s.unitTypeOptions, s.unitType),
        bedOpts: withOpts(s.bedroomOptions, s.bedrooms),
        typoOpts: withOpts(s.unitTypologyOptions, s.unitTypology),
        showType: Boolean(s.phaseId),
        showBeds: Boolean(s.phaseId && s.unitType),
        showTypo: Boolean(s.showTypology),
        canRemove: this.count > 1 && !this.busy,
        statusChip: sent ? "chip chip--paid" : complete ? "chip chip--partial" : "chip chip--pending",
        statusLabel: sent ? "Link sent" : complete ? "Ready" : "Incomplete"
      };
    });
  }

  /* 1.4 - the Sales App's button: always a link, one per unit */
  get submitLabel() {
    if (this.busy) return this.isOnline ? "Sending…" : "Working…";
    if (!this.isOnline) return this.count > 1 ? "Create EOIs" : "Create EOI";
    return this.count > 1 ? "Send links" : "Send link";
  }
  get submitIcon() {
    return this.isOnline ? "send" : "check";
  }

  get summaryRows() {
    return this.cards.map((c) => ({
      key: c.key,
      title: c.title,
      sub: c.complete ? [c.phaseName, c.unitTypology, c.bedrooms ? `${c.bedrooms} BR` : "", c.unitType].filter(Boolean).join(" · ") : "Incomplete",
      amount: c.amountLabel || "-",
      cls: `sum__row${c.active ? " sum__row--active" : ""}`
    }));
  }

  // ── Events ───────────────────────────────────────────────────────────────

  emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail }));
  }
  handleField(e) {
    const { key, field } = e.target.dataset;
    this.emit("selectionchange", { key, field, value: e.target.value });
  }
  handleActivate(e) {
    const key = e.currentTarget.dataset.key;
    if (key && key !== this.activeKey) this.emit("activate", { key });
  }
  handleRemove(e) {
    e.stopPropagation();
    this.emit("removeselection", { key: e.currentTarget.dataset.key });
  }
  handleAdd() {
    this.emit("addselection");
  }
  handleSubmit() {
    this.emit("submit");
  }
}