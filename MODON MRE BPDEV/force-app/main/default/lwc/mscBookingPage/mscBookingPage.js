/**
 * Section shell and orchestrator for the single-page booking journey.
 *
 * Version  Author      Date         Detail
 * 1.x+22   Aurelix Dev 30 Sep 2026  The "not submitted for compliance" banner goes after a successful submit once the
 *                                   person it names reads as sent (UI-29). MODON's sentence is unchanged.
 * 1.x+21   Aurelix Dev 30 Sep 2026  Windows check: summary after the step, no empty footer band, company name on the tab,
 *                                   fee wording after Confirm, unit facts on the card, fee links shown together.
 * 1.x+20   Aurelix Dev 29 Sep 2026  Unit option: with several, the list starts empty ("Select an option") and the
 *                                   unit shows its own price until the rep picks (SalesConsoleController 1.87).
 * 1.x+19   Aurelix Dev 29 Sep 2026  Saving the company's verification details re-reads the Verification step, so it
 *                                   no longer shows details as missing after they are saved.
 * 1.x+18   Aurelix Dev 29 Sep 2026  With BOOKING_FEE_BY_LINK on, Send payment link replaces Take payment
 *                                   (startBookingFeeLink, then sendBookingFeeLink once per fee); Resend link; Release
 *                                   unit disabled while a link is live. Switch off: as before.
 * 1.x+17   Aurelix Dev 29 Sep 2026  Every eligible offer arrives ticked and several may apply to one charge, as the
 *                                   Sales App saves them. First unit option preselected (controller 1.83).
 * 1.x+16   Aurelix Dev 29 Sep 2026  EOI list per unit on the plan card: one fitting EOI is chosen, several ask the rep
 *                                   ("Please select an EOI for unit: X"). First plan preselected. Release unit calls
 *                                   cancelPaymentHold, also on a lapsed hold.
 * 1.x+15   Aurelix Dev 29 Sep 2026  Unit options from the server's list (Sales App order and Wadeem rule), priced only
 *                                   where the option prices the order; a UAE national in Wadeem sees
 *                                   UAE_Citizen_Price__c.
 * 1.x+14   Aurelix Dev 28 Sep 2026  The side summary's chip beside the Sales Order number read "Booking started"
 *                                   on a sold booking (SO-15561), because MODON closes the sale without moving
 *                                   Status__c off New. The server now says when the sale has closed
 *                                   (summary.saleClosed, SalesConsoleController 1.78) and the chip reads
 *                                   "Settled" (LABELS.SETTLE_DONE, the word Payment & Confirm already uses) in
 *                                   the settled tone. Every other status keeps its label (SCW-211).
 * 1.x+13   Aurelix Dev 27 Sep 2026  The Sales App's booking rules (business confirmed, 27 Sep: same behaviour as
 *                                   MODON's Sales App; SalesConsoleController 1.77). (1) UNIT OPTIONS: the unit configuration
 *                                   already carried generateSalesOffer's unitOptiontDetailObj; each unit entry
 *                                   now keeps its options, the plan card offers them, leaving Details is refused
 *                                   with the Sales App's sentence until one is chosen where any exist, the choice
 *                                   travels as unitOptionId, and the single unit's summary is read priced at the
 *                                   option (getBookingSummaryWithOption). (2) EOIs are assigned only to units
 *                                   whose phase requires one (cfg.eoiRequired), as the Sales App offers the EOI
 *                                   picker only there. (3) Payment & Confirm lists the chosen unit option, facade
 *                                   style and pre-approval number before Confirm (reviewExtras), as the Sales
 *                                   App's review page does. (4) A made booking's "Offers applied" are its saved
 *                                   Offers_Collections__c rows (getAppliedOffers), no longer the defaults re-ticked.
 * 1.x+12   Aurelix Dev 27 Sep 2026  Three fixes found in the SCW-193 end-to-end test.
 *                                   (1) The Sales App's pre-approval default: when a unit's EOI carries a
 *                                   Pre-Approval Number and its plan is not a pre-approval plan, the first
 *                                   pre-approval plan is chosen (applyPreApprovalDefaults), once per unit and
 *                                   EOI, when the EOI is assigned or the plans arrive. A resumed booking keeps
 *                                   its saved plan. The rep can still change it.
 *                                   (2) After Confirm on a paid fee the card stayed on "Captured in full,
 *                                   waiting for finance" until a reload, though MODON's allocation job closes
 *                                   the sale within seconds: the settle watch stopped as soon as money showed
 *                                   on the closing rows. It now also waits while the booking is mid-close
 *                                   (settlementClearing), inside the same one-minute window, and re-reads
 *                                   the page state once the sale closes, so the side summary's stage follows.
 *                                   (3) A unit that takes no booking fee read "Payable to confirm this booking"
 *                                   before Confirm. The header is told (settlementNoFee, from loadFees' answer
 *                                   for this unit, now also asked when the unit's summary loads) and says
 *                                   "No booking fee"; so does the collapsed line in the step bar, and the
 *                                   side summary drops its "Booking fee" figure and row (summaryTotals.dueNow).
 *                                   (4) The payment watch stopped on the tick where the fee status first read
 *                                   paid, but the settlement and the rows on that tick were read in parallel
 *                                   and could predate the money (seen 27 Sep: "Payable" and two "not been
 *                                   received" blockers beside an enabled Confirm Booking until Refresh). The
 *                                   watch now reads both once more as it stops.
 * 1.x+11   Aurelix Dev 27 Sep 2026  Facade style and the ADIB pre-approval number, as MODON's Sales App asks
 *                                   for them (engine 17.0 and 19.0, MODON confirmed on 26 Sep). The unit's
 *                                   configuration already carried offer.facadeStyleRequired and
 *                                   facadeStyleOptions; each unit entry now keeps them, auto-selects a single
 *                                   option, and the plan card shows a facade picker when the phase needs one.
 *                                   On a plan with Pre_Approval__c it shows the EOI's number when the unit's
 *                                   EOI has one, or asks for it. Leaving Details forward is refused, with the
 *                                   Sales App's own sentences, until both are given, and both travel in the
 *                                   payment and confirm requests. The engine stays the authority at save.
 *                                   Not mirrored: the Sales App's pre-selection of a pre-approval plan when
 *                                   the EOI carries a number.
 * 1.x+10   Aurelix Dev 22 Sep 2026  loadFees asks getBookingFeeNeed with the unit's EOI mapping: with the
 *                                   switch EOI_SKIPS_BOOKING_FEE on, a unit whose EOI has a cleared receipt
 *                                   takes no booking fee and confirms straight away (feeCoveredByEoi).
 * 1.x+9    Aurelix Dev 22 Sep 2026  handleOwnerPersonFound: the joint owner drawer created a person
 *                                   without adding them (they do KYC first), so show them as found.
 * 1.x+8    Aurelix Dev 22 Sep 2026  Auto-assignment compares bedrooms the way MODON's engine does since
 *                                   UnitSearchLwcController v16.0 (bedroomsMatch): the number only, so an
 *                                   EOI's "5 BR" meets a "5" unit (sameBedrooms, as in
 *                                   SalesConsoleController 1.73). Previous version:
 *                                   _backup/2026-09-22_081155 (WL-019).
 * 1.x+7    Aurelix Dev 21 Sep 2026  With the EOI match switched on (EOI_Enforce_Typology_Check 'true'),
 *                                   auto-assignment gives a unit an EOI with the same bedrooms; typology
 *                                   is no longer compared (MODON's answer to open question 9, and
 *                                   SalesConsoleController 1.72). With the match off, nothing changes:
 *                                   typology+bedrooms first, then typology, then oldest. eoiFilterPreset
 *                                   is unchanged; the grid already ignores a typology no unit carries.
 *                                   Previous version: _backup/2026-09-21_233502 (WL-017).
 * 1.x+6    Aurelix Dev 21 Sep 2026  MODON's EOI booking gates, as the Sales App runs them
 *                                   (unitSearchLwc, "EOI v2.1"): on the way out of unit
 *                                   selection - its Book Unit/s - the server's checkEoiGate is
 *                                   asked, and a refusal stops the step with the Sales App's own
 *                                   sentence. The rail jump asks too. Auto-assignment offers a unit
 *                                   only matching EOIs when enforceTypology is on, as the Sales
 *                                   App's picker does. The early banner (eoiGateMsg) is retired:
 *                                   the Sales App deliberately says nothing until the rep tries to
 *                                   book, and the decision was the same behaviour in both.
 * 1.x+5    Aurelix Dev 21 Sep 2026  Turning a single-unit booking into a basket left the single
 *                                   unit's booking-fee buckets behind, so "ADM + Dari has not
 *                                   been received yet" went on disabling Generate Sales Orders
 *                                   for a basket that takes no fee at all. Seen booking a DEV test
 *                                   customer from EOI-3531 (GV-144 + GV-149): only pressing Refresh, which
 *                                   nothing asked for, freed it. afterSelectionChange now drops
 *                                   the money state with the plan state and re-reads it.
 * 1.x+4    Aurelix Dev 21 Sep 2026  A resumed booking whose unit is already on the
 *                                   opportunity restored the selection but not the unit's
 *                                   payment plans, so the plan panel offered nothing to
 *                                   select and the ticked unit could only be un-ticked.
 *                                   restoreSingleUnitPlans fetches the configuration the
 *                                   way handleUnitSelect does.
 * 1.x+3    Aurelix Dev 20 Sep 2026  One address, not two. c/mscAddress is unmounted and Update KYC
 *                                   (Modon's own form) owns the customer address, as it does in their
 *                                   Sales App; handleEditAddress opens that dialog.
 * 1.x+2    Aurelix Dev 18 Sep 2026  SCW-125. The mandate form sends e-mail and city too; the card's
 *                                   ddchanged reloads the box and the buckets; MODON's validation
 *                                   problems on a saved Draft are shown as the page note.
 * 1.x+1    Aurelix Dev 18 Sep 2026  The page-level payment Refresh (MSC-177) hides while a terminal
 *                                   payment is awaited: the confirm block's Check payment already
 *                                   re-reads fees, settlement and buckets (handleRefreshFees), so
 *                                   two refresh icons side by side said nothing different.
 * 1.x      Aurelix Dev 18 Sep 2026  MSC-182 (B10). ?ref= is the journey's record in the URL (?opp=
 *                                   still read as an alias, never written). The Offer control -
 *                                   the Preview offer button and c/mscOffer - sits behind
 *                                   LABELS.OFFER_ENABLED (false): hidden, code kept.
 * 1.114    Aurelix Dev 07 Sep 2026  Signzy Phase 4. Continue is held when c/mscKycGate reports
 *                                   the hard gate blocks this customer (kycstate event). The
 *                                   button is a courtesy: SalesConsoleController refuses the
 *                                   money itself, so the journey is safe with or without it.
 * 1.113    Aurelix Dev 07 Sep 2026  Signzy Phase 3. c/mscKycGate is now the ACTIVE pre-booking
 *                                   KYC workspace, so the mount gained primary-unit-id - the
 *                                   unit context sendCustomerVerification stamps on the
 *                                   customer's form before the send. Markup only, again: this
 *                                   file still has no KYC handler, no wire and no state, and
 *                                   Continue, payment and Confirm remain untouched. The panel
 *                                   calls the same SalesConsoleController methods the
 *                                   Verification step already used.
 * 1.112    Aurelix Dev 07 Sep 2026  Signzy Phase 2. c/mscKycGate mounted in step 2's customer
 *                                   card, above c/mscCustomerInfo. Markup only - the panel
 *                                   fetches and owns its own state from
 *                                   AurelixKycEligibilityService, so this file gained no
 *                                   handler, no wire and no state. Nothing here can block:
 *                                   Continue, payment and Confirm are untouched this phase.
 * 1.111    Aurelix Dev 03 Sep 2026  MSC-231 (W5). Booking against the EOI: eligible EOIs read
 *                                   from the org engine (getBookingEois), deposits auto-assigned
 *                                   to selected units (typology match first, oldest first, one
 *                                   per unit), typology preference pre-set through the unit
 *                                   grid's own filters, deposit rows on the Settle step with a
 *                                   Change swap sheet, and the {unitId: eoiId} mapping riding
 *                                   into reviewAndConfirm. eoi-id seeds a Book unit door entry.
 * 1.110    Aurelix Dev 02 Sep 2026  MSC-225. customerMobile passed to c/mscOffer for its
 *                                   WhatsApp control. Read only - nothing is sent.
 * 1.109    Aurelix Dev 02 Sep 2026  MSC-215. A seeded project with nothing this rep can take
 *                                   falls back to the default landing (which MSC-213 already
 *                                   made bookable-aware) instead of an empty grid.
 * 1.108    Aurelix Dev 02 Sep 2026  MSC-214. The seeded journey is FOR its lead: buyer-type
 *                                   switch hidden while the seed is live (the panel ignores
 *                                   it), Change customer hidden for the whole lead journey
 *                                   (swapping them out would orphan the conversion), and Back
 *                                   off the seeded panel (`seedcancel`) restores the plain
 *                                   picker, switch included.
 * 1.107    Aurelix Dev 02 Sep 2026  MSC-212. lead-id: the journey opened from a lead resolves it
 *                                   first (leadRowById) - a converted lead is adopted as its
 *                                   opportunity, everyone else lands on their project with the
 *                                   customer step pre-seeded (seed-lead -> c/mscConsole). The
 *                                   seed dies the moment a customer is picked.
 * 1.106    Aurelix Dev 30 Aug 2026  MSC-181. handleAssignSignatory / handleCreateSignatory for the POA pane.
 * 1.105    Aurelix Dev 25 Aug 2026  MSC-168. Verification step wording on an unconfirmed booking.
 * 1.104    Aurelix Dev 25 Aug 2026  MSC-166. Close control on the other two page banners.
 * 1.103    Aurelix Dev 24 Aug 2026  MSC-163. Page error banner can be closed; clears on a step change.
 * 1.102    Aurelix Dev 24 Aug 2026  MSC-161. Basket row plan chip is grey "Pending" until chosen.
 * 1.101    Aurelix Dev 24 Aug 2026  MSC-157. Customer blocker wording.
 * 1.100    Aurelix Dev 23 Aug 2026  MSC-156. Payment & Confirm goes green once settled.
 * 1.99     Aurelix Dev 23 Aug 2026  MSC-152 / MSC-153. buyerType held here; nav floor rises on money.
 * 1.98     Aurelix Dev 23 Aug 2026  MSC-151. c-msc-verify-next fed by compliance.nextStep.
 * 1.97     Aurelix Dev 23 Aug 2026  MSC-149. handleSendLinkFromWorkspace.
 * 1.96     Aurelix Dev 23 Aug 2026  MSC-148. Company verification workspace wired.
 * 1.95     Aurelix Dev 20 Aug 2026  MSC-093. Plan card opens on the first unit of the basket.
 * 1.94     Aurelix Dev 22 Aug 2026  MSC-126 / MSC-083. Save toasts; compliance per party.
 * 1.93     Aurelix Dev 22 Aug 2026  MSC-115 / MSC-116 / MSC-082. Corporate compliance door; per-owner verification.
 * 1.92     Aurelix Dev 22 Aug 2026  MSC-113 / MSC-081. Forward button holds a company; joint owners panel.
 * 1.91     Aurelix Dev 22 Aug 2026  MSC-112 / MSC-071. Per-field lockReasons; country of residence.
 * 1.90     Aurelix IT  19 Aug 2026  MSC-069. Rep sends the customer to compliance.
 * 1.89     Aurelix Developer 19 Aug 2026  KYC-link question off (ASK_TO_SEND_KYC_LINK).
 * 1.88     Aurelix Developer 19 Aug 2026  Sending the link completes verification; nav floor; pre-Confirm ledger hidden.
 * 1.87     Aurelix Developer 19 Aug 2026  A proof records a Payment; c/mscPaymentModal (MSC-099).
 * 1.86     Aurelix Developer 18 Aug 2026  Milestone box wired; confirm rule removed (MSC-098b).
 * 1.85     Aurelix Developer 18 Aug 2026  ledgerRows: fee lines dropped post-Confirm.
 * 1.84     Aurelix Developer 17 Aug 2026  Document checklist off.
 * 1.83     Aurelix Developer 17 Aug 2026  Direct Debit box removed.
 * 1.82     Aurelix Developer 17 Aug 2026  awaitingFeeReceipt; rail hold line gone; no em dashes.
 * 1.81     Aurelix Developer 17 Aug 2026  One Sales Order is one booking (bookingId, focusedSalesOrderId).
 * 1.80     Aurelix Developer 17 Aug 2026  A basket resumes as a basket.
 * 1.79     Aurelix Developer 17 Aug 2026  allSalesOrderIds on a resumed basket; Still to do list.
 * 1.78     Aurelix Developer 17 Aug 2026  Poll waits for a visible tab; ledger refreshed.
 * 1.77     Aurelix Developer 17 Aug 2026  Documents alert removed from the payment step.
 * 1.76     Aurelix Developer 17 Aug 2026  Rail verification focus line removed.
 * 1.75     Aurelix Developer 17 Aug 2026  After Confirm: confirmation at the top, forward action.
 * 1.74     Aurelix Developer 17 Aug 2026  awaitingPayment derived from the hold.
 * 1.69     Aurelix Developer 16 Aug 2026  Resume opens on Payment & Confirm; Back floor.
 * 1.66     Aurelix Developer 16 Aug 2026  Summary rail derived here (summaryLines).
 * 1.46     Aurelix IT  13 Aug 2026  Multi-unit payable; offers per unit.
 * 1.43     Aurelix IT  13 Aug 2026  Hold countdown; guards; one disconnectedCallback.
 * 1.41     Aurelix IT  12 Aug 2026  Resume on the payment step; payment watch.
 * 1.38     Aurelix IT  12 Aug 2026  Every wait raises c-msc-loader.
 * 1.37     Aurelix IT  12 Aug 2026  Take payment raises fee lines before the hold.
 * 1.34     Aurelix IT  12 Aug 2026  One summary panel for one unit or many.
 * 1.33     Aurelix IT  12 Aug 2026  Continue advances one step.
 * 1.31     Aurelix IT  11 Aug 2026  Unit screen opens in one round trip.
 * 1.30     Aurelix IT  11 Aug 2026  Black screen fix in handleChangeCustomer.
 * 1.14     Aurelix IT  10 Aug 2026  Three steps, not six.
 * 1.5      Aurelix IT  09 Aug 2026  Unit selection first.
 * 1.4      Aurelix IT  09 Aug 2026  embedded mode.
 * 1.2      Aurelix IT  07 Aug 2026  Multi-unit booking.
 * 1.1      Aurelix IT  06 Aug 2026  Identity verification and compliance chain.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { hostStyle } from "c/mscTokens";
/* stageLabel lives here: the journey knows whether the booking is confirmed */
import { LABELS, stageLabel } from "c/mscLabels";

/* MSC-152: values, not labels; c/mscConsole compares against these */
/* MSC-168: the one blocked note the journey may replace, copied verbatim from
   SalesConsoleJointOwnerService; any other reason passes through untouched */
const NO_ORDER_NOTE = "This booking has no confirmed unit yet.";
const BUYER_INDIVIDUAL = "Individual";
const BUYER_ORGANISATION = "Organisation";

/* 1.x+8: the engine's bedrooms compare (UnitSearchLwcController.bedroomsMatch, v16.0), as in
   SalesConsoleController.sameBedrooms: the number only, so "5 BR" matches "5"; when neither side
   holds a digit, trimmed text in any case */
function sameBedrooms(eoiBeds, unitBeds) {
  const eoiText = String(eoiBeds == null ? "" : eoiBeds).trim();
  const unitText = String(unitBeds == null ? "" : unitBeds).trim();
  const a = eoiText.replace(/[^0-9]/g, "");
  const b = unitText.replace(/[^0-9]/g, "");
  if (!a && !b) {
    return eoiText.toLowerCase() === unitText.toLowerCase();
  }
  return a === b;
}
/* which milestones are scheduled, asked where the ledger asks it */
import { isScheduledMilestone } from "c/mscPaymentFacts";
import { formatAED, formatDate, reduceError, unitTourUrl } from "c/modonSalesFormat";

import getConsoleState from "@salesforce/apex/SalesConsoleController.getConsoleState";
// the same state, opened on one Sales Order; see bookingId
import getConsoleStateForOrder from "@salesforce/apex/SalesConsoleController.getConsoleStateForOrder";
import saveCustomerInfo from "@salesforce/apex/SalesConsoleController.saveCustomerInfo";
import getUnitBrowser from "@salesforce/apex/SalesConsoleController.getUnitBrowser";
import searchUnits from "@salesforce/apex/SalesConsoleController.searchUnits";
import getUnitConfiguration from "@salesforce/apex/SalesConsoleController.getUnitConfiguration";
/* 1.x+13 - the summary priced as the Sales App prices the order (unit option, plan mapping, unit);
   replaces getBookingSummary here */
import getBookingSummaryWithOption from "@salesforce/apex/SalesConsoleController.getBookingSummaryWithOption";
import getBookingSummaryForOrders from "@salesforce/apex/SalesConsoleController.getBookingSummaryForOrders";
import getPaymentBucketsForOrders from "@salesforce/apex/SalesConsoleController.getPaymentBucketsForOrders";
import getSettlement from "@salesforce/apex/SalesConsoleController.getSettlement";
import planHasSchedule from "@salesforce/apex/SalesConsoleController.planHasSchedule";
import getRequiredDocuments from "@salesforce/apex/SalesConsoleController.getRequiredDocuments";
import getDirectDebitState from "@salesforce/apex/SalesConsoleController.getDirectDebitState";
import getMilestoneBatch from "@salesforce/apex/SalesConsoleController.getMilestoneBatch";
import createChequePayments from "@salesforce/apex/SalesConsoleController.createChequePayments";
import submitDirectDebitMandate from "@salesforce/apex/SalesConsoleController.submitDirectDebitMandate";
import createProofSlot from "@salesforce/apex/SalesConsoleController.createProofSlot";
import uploadProofImage from "@salesforce/apex/SalesConsoleController.uploadProofImage";
import recordProofPayment from "@salesforce/apex/SalesConsoleController.recordProofPayment";
import getEligibleOffersForBasket from "@salesforce/apex/SalesConsoleController.getEligibleOffersForBasket";
/* 1.x+13 - the offers a made booking carries (its Offers_Collections__c rows) */
import getAppliedOffers from "@salesforce/apex/SalesConsoleController.getAppliedOffers";
import sendOffer from "@salesforce/apex/SalesConsoleController.sendOffer";
import getOrgUrl from "@salesforce/apex/SalesConsoleController.getOrgUrl";
import getSitePathPrefix from "@salesforce/apex/SalesConsoleController.getSitePathPrefix";
import deleteProofSlot from "@salesforce/apex/SalesConsoleController.deleteProofSlot";
import reviewAndConfirm from "@salesforce/apex/SalesConsoleController.reviewAndConfirm";
import getBookingEois from "@salesforce/apex/SalesConsoleController.getBookingEois";
import checkEoiGate from "@salesforce/apex/SalesConsoleController.checkEoiGate";
import sendKycLink from "@salesforce/apex/SalesConsoleController.sendKycLink";
import refreshComplianceState from "@salesforce/apex/SalesConsoleController.refreshComplianceState";
import sendCustomerVerification from "@salesforce/apex/SalesConsoleController.sendCustomerVerification";
import releaseVerificationToBranch from "@salesforce/apex/SalesConsoleController.releaseVerificationToBranch";
import ensureComplianceDocSlots from "@salesforce/apex/SalesConsoleController.ensureComplianceDocSlots";
/* MSC-081: joint owners; SalesConsoleJointOwnerService owns every rule */
import getOwners from "@salesforce/apex/SalesConsoleJointOwnerService.getOwners";
import findJointOwnerPerson from "@salesforce/apex/SalesConsoleJointOwnerService.findPerson";
import addJointOwner from "@salesforce/apex/SalesConsoleJointOwnerService.addOwner";
import updateJointOwner from "@salesforce/apex/SalesConsoleJointOwnerService.updateOwner";
/* MSC-082: one party's identity verification (the buyer uses sendCustomerVerification) */
import sendOwnerVerification from "@salesforce/apex/SalesConsoleJointOwnerService.sendVerification";
import getComplianceChecklist from "@salesforce/apex/SalesConsoleComplianceService.getChecklist";
import saveComplianceDetails from "@salesforce/apex/SalesConsoleComplianceService.saveDetails";
import submitToCompliance from "@salesforce/apex/SalesConsoleComplianceService.submit";
/* MSC-083: compliance document slots for one party, on demand */
import ensurePartyDocSlots from "@salesforce/apex/SalesConsoleComplianceService.ensureDocSlots";
/* MSC-148: the company's verification workspace, on its own controller */
import getOrgDetails from "@salesforce/apex/SalesConsoleOrgController.getOrgDetails";
import saveOrgDetails from "@salesforce/apex/SalesConsoleOrgController.saveOrgDetails";
import assignOrgSignatory from "@salesforce/apex/SalesConsoleOrgController.assignSignatory";
import createOrgSignatoryContact from "@salesforce/apex/SalesConsoleOrgController.createSignatoryContact";
import uploadCompanyLicence from "@salesforce/apex/SalesConsoleOrgController.uploadCompanyLicence";
import submitOrganisationCompliance from "@salesforce/apex/SalesConsoleOrgController.submitOrganisationCompliance";
/* taking the booking fee */
import getFeeStatus from "@salesforce/apex/SalesConsoleController.getFeeStatus";
import getBookingFeeNeed from "@salesforce/apex/SalesConsoleController.getBookingFeeNeed";
import beginPayment from "@salesforce/apex/SalesConsoleController.beginPayment";
import getPaymentHoldMinutes from "@salesforce/apex/SalesConsoleController.getPaymentHoldMinutes";
import endPaymentHold from "@salesforce/apex/SalesConsoleController.endPaymentHold";
/* 1.x+16 - the rep's Release unit, live or lapsed hold, refused while money sits on the fee lines */
import cancelPaymentHold from "@salesforce/apex/SalesConsoleController.cancelPaymentHold";
import getHoldSecondsRemaining from "@salesforce/apex/SalesConsoleController.getHoldSecondsRemaining";
import getPaymentTerminalUrl from "@salesforce/apex/SalesConsoleController.getPaymentTerminalUrl";
/* 1.x+18 - the booking fee by payment link */
import startBookingFeeLink from "@salesforce/apex/SalesConsoleController.startBookingFeeLink";
import sendBookingFeeLink from "@salesforce/apex/SalesConsoleController.sendBookingFeeLink";
import getBookingFeeLinkState from "@salesforce/apex/SalesConsoleController.getBookingFeeLinkState";
import resendBookingFeeLink from "@salesforce/apex/SalesConsoleController.resendBookingFeeLink";
/* nationality picklist, from the org */
import getLeadQualifyOptions from "@salesforce/apex/SalesConsoleLeadController.getLeadQualifyOptions";
/* MSC-212: the lead a "Book a unit" journey was opened from */
import leadRowById from "@salesforce/apex/SalesConsoleLeadController.leadRowById";
import getLegalStructureOptions from "@salesforce/apex/SalesConsoleController.getLegalStructureOptions";
/* Contact.CountryOfResidence__c is a restricted picklist: its own describe */
import getCountryOfResidenceOptions from "@salesforce/apex/SalesConsoleController.getCountryOfResidenceOptions";

/**
 * The single-page booking journey. Owns all journey state and every Apex call; children are
 * presentational and talk upward through events.
 */

/** Three steps, not six: what they are buying, who it is for and on what terms, then settling it. */
/* Verification is a fourth step, after the booking: it unlocks on Confirm, never blocks, and
 * its action bar closes the journey. */
/* shortLabel: the tab's name where the full one does not fit (R2-03) */
const GROUPS = [
  { key: "unit", label: LABELS.SECTION_UNIT, shortLabel: LABELS.SECTION_UNIT_SHORT, index: 1, members: ["unit"] },
  {
    key: "details",
    label: LABELS.SECTION_DETAILS,
    shortLabel: LABELS.SECTION_DETAILS_SHORT,
    index: 2,
    members: ["customer", "plan"]
  },
  /* one member: payment and review were two cards doing one job */
  {
    key: "settle",
    label: LABELS.SECTION_SETTLE,
    shortLabel: LABELS.SECTION_SETTLE_SHORT,
    index: 3,
    members: ["settlement"]
  },
  { key: "verify", label: LABELS.SECTION_VERIFY, shortLabel: LABELS.SECTION_VERIFY, index: 4, members: ["verify"] }
];

const NEXT_ORDER = ["unit", "details", "settle", "verify"];

/** What a step says before it has a value ("Awaiting ..."), never the label repeated. */
const NAV_PROMPTS = {
  unit: "Awaiting unit",
  details: "Awaiting customer",
  settle: "Awaiting payment",
  verify: "Awaiting verification"
};

/** Which step a section belongs to. */
const GROUP_OF = {
  unit: "unit",
  customer: "details",
  plan: "details",
  summary: "details",
  /* the two old keys are kept as aliases for stored ?section= links */
  settlement: "settle",
  payment: "settle",
  review: "settle",
  verify: "verify"
};

/** The rail needs ~360px beside an 860px column; below this it becomes a card. */
/* 1024, matching the PoC (768 must not split: portrait iPad). Must stay in sync with the
   @media (min-width: 1024px) rules in the CSS. */
const RAIL_MIN_WIDTH = 1024;

/** Still to do is built and switched off, by request. Set true to bring it back. */
const SHOW_STILL_TO_DO = false;

/** The KYC-link question is switched off, by request. With this false a new customer
 * continues as "Continue without KYC" did. */
const ASK_TO_SEND_KYC_LINK = false;

export default class MscBookingPage extends LightningElement {
  @api recordId;
  @api backgroundImage;
  @api accentColor;

  /* the Sales Order this journey was opened on (Resume click or URL). A request only: the page
   * reads state.focusedSalesOrderId after bootstrap. A change after bootstrap remounts the page. */
  @api bookingId;
  /** MSC-212: the lead this journey was opened from ("Book a unit" on the lead drawer). Resolved
   * once at bootstrap; meaningless beside a recordId (the opportunity always wins). */
  @api leadId;
  /** The resolved lead row, handed to the customer step; cleared the moment a customer is picked. */
  leadSeed;
  _leadSeedTried = false;
  /** MSC-214: true for the life of the mount once the journey resolved a lead - seeded or
   * adopted. Gates Change customer: this booking is FOR that person. */
  isLeadJourney = false;
  /** ?so= / ?booking= from the URL, when there is no @api bookingId. */
  _urlOrderId;

  /** The order to ask the server for. Embedded reads bookingId only; standalone reads ?so=. */
  get requestedOrderId() {
    if (this.embedded) {
      return this.bookingId || null;
    }
    return this.bookingId || this._urlOrderId || null;
  }

  /** The server's answer: the one order this page is about, or null for the whole opportunity. */
  get focusedOrderId() {
    return (this.state && this.state.focusedSalesOrderId) || null;
  }

  /** One order of a multi-unit booking opened on its own: no fee panel, no terminal, no hold clock. */
  get isBasketMember() {
    const booked = (this.state && this.state.bookedUnits) || [];
    return !!this.focusedOrderId && booked.length > 1;
  }

  /** The other live orders of this booking, for the rail. */
  get siblingUnits() {
    if (!this.isBasketMember) {
      return [];
    }
    const focus = this.focusedOrderId;
    return ((this.state && this.state.bookedUnits) || []).filter(
      (b) => b && b.salesOrderId && b.salesOrderId !== focus
    );
  }

  @track state = {};
  @track summary;
  @track buckets = [];
  @track docs;
  @track ddState;
  /* milestone box facts, one per Sales Order */
  @track milestoneBatch = {};
  /* what the last cheque batch came back with, for the sheet */
  chequeResult;
  chequeError;
  /* what the last Create Payment came back with, for that row */
  proofResult;
  /* proof uploads run one after another */
  _proofChain = Promise.resolve();
  @track projects = [];
  @track phases = [];
  @track units = [];
  @track plans = [];

  opportunityId;
  salesOrderId;
  bookingRef;
  selectedProjectId;
  selectedPhaseId;
  selectedPlanId;
  planRows = [];
  proofSlots = {};

  /* multi-unit */
  /** The selection, as a list. */
  @track selectedUnitIds = [];
  /* every unit the whole booking covers; resume restores a single unit */
  @track bookedUnits = [];
  /** unitId -> { name, plans[], planId } for the basket. */
  @track unitPlans = {};
  /** Sales Orders created by a basket confirmation. */
  @track createdSalesOrderIds = [];

  /** Undefined the moment a basket exists, so the single-unit calls do not fire. */
  get selectedUnitId() {
    return this.selectedUnitIds.length === 1 ? this.selectedUnitIds[0] : undefined;
  }

  get isMultiUnit() {
    return this.selectedUnitIds.length > 1;
  }

  get isSingleUnit() {
    return this.selectedUnitIds.length === 1;
  }

  /** MSC-095: units in the draft basket, for mscSettlementHeader.isDraftBasket only. */
  get draftUnitCount() {
    return (this.selectedUnitIds || []).length;
  }

  /* unit first */
  /** Section 2 shows the customer picker until a customer has been chosen. */
  get needsCustomer() {
    /* and while the verification dialog is being asked for or is open */
    return !this.opportunityId || this._holdCustomerPane;
  }

  /** The plan card renders only once a customer is on the booking. */
  /**
   * MSC-152: who the booking is for, held here because the switch is slotted into the card's
   * aside. Individual by default; not reset when a customer is picked.
   */
  buyerType = BUYER_INDIVIDUAL;

  get buyerTypeSegments() {
    return [
      { key: BUYER_INDIVIDUAL, label: LABELS.BUYER_INDIVIDUAL },
      { key: BUYER_ORGANISATION, label: LABELS.BUYER_ORGANISATION }
    ].map((o) => ({
      ...o,
      cls:
        this.buyerType === o.key
          ? "buyer-type__seg buyer-type__seg--on"
          : "buyer-type__seg",
      pressed: this.buyerType === o.key ? "true" : "false"
    }));
  }

  handleBuyerType(event) {
    const value = event.currentTarget.dataset.value;
    /* same answer, no render */
    if (!value || value === this.buyerType) {
      return;
    }
    this.buyerType = value;
  }

  /** MSC-214: the switch hides while a lead seed is live - the seeded panel ignores it. */
  get showBuyerTypeSwitch() {
    return this.needsCustomer && !this.leadSeed;
  }

  /** MSC-214: Back off the seeded panel abandons the seed; the plain picker (and switch) return. */
  handleSeedCancel() {
    this.leadSeed = undefined;
  }

  get hasCustomerPicked() {
    return !this.needsCustomer;
  }

  /* customerLocked is gone; the per-field policy is summaryCustomer.lockReasons */

  /* eligibility, shown on the customer step where it can be acted on */
  get eligibilityMessage() {
    return this.state ? this.state.eligibilityMessage : undefined;
  }

  /* guarded: a nullish summary threw mid-render */
  get summaryCustomer() {
    return this.summary ? this.summary.customer : undefined;
  }

  /* saveAccount demands both; carried through */
  get summaryNationality() {
    return this.summary && this.summary.customer
      ? this.summary.customer.nationality
      : undefined;
  }

  get summaryResidentStatus() {
    return this.summary && this.summary.customer
      ? this.summary.customer.residentStatus
      : undefined;
  }

  /** The address landed; re-read state. */
  async handleAddressSaved() {
    await this.reloadState();
    this.toast(LABELS.TOAST_ADDRESS_SAVED);
  }

  /** One line of news, four seconds, raised only after the state that proves it came back. */
  toast(message, variant) {
    const el = this.template.querySelector("c-msc-toast");
    if (el && typeof el.show === "function") el.show(message, variant);
  }

  /* showEligibilityBlock removed; customerReady and customerGapMessage read the same state */

  /** The picker is full width: above 1440px the two cards sit side by side. */
  /** The customer card fills the row only when it has a neighbour. */
  get customerCardFill() {
    return !this.needsCustomer;
  }

  get customerCellClass() {
    return this.needsCustomer ? "pair__cell pair__cell--wide" : "pair__cell";
  }

  /** A customer was chosen: load their state, then the calls that need a unit and an opportunity. */
  async handleCustomerPicked(event) {
    const detail = event.detail || {};
    const oppId = detail.opportunityId;
    if (!oppId || this.busyPage) {
      return;
    }
    /* set before the awaits, read by needsCustomer; cleared by closeVerifyDialog */
    this._holdCustomerPane = detail.isNewCustomer === true;
    /* remembered for the customer card, which folds its fields on this journey only */
    this.isNewCustomerJourney = detail.isNewCustomer === true;
    /* MSC-212: the seed dies with the choice - Change customer later shows the plain picker */
    this.leadSeed = undefined;
    this.opportunityId = oppId;
    this._bootstrapped = true;
    this.reportOpportunity();
    await this.bootstrap();
    if (this.selectedUnitIds.length) {
      await this.afterSelectionChange();
    }
    /* a new customer is asked how to verify, here and after bootstrap (the send stamps the unit) */
    /* only while the question is switched on */
    if (detail.isNewCustomer && ASK_TO_SEND_KYC_LINK) {
      this.verifyDialogOpen = true;
      this.verifyCustomerName = detail.customerName;
      this.verifyCanSend = detail.canSendVerification === true;
      this.verifyBlockedReason = detail.verificationBlockedReason;
    } else {
      this._holdCustomerPane = false;
    }
  }

  /** Tell the shell which booking is open, so it reaches the URL. Embedded only. */
  reportOpportunity() {
    if (!this.embedded || !this.opportunityId) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("opportunitychange", {
        detail: { opportunityId: this.opportunityId },
        bubbles: true,
        composed: true
      })
    );
  }

  /** And which order, from the server's answer. Sent once per bootstrap. Embedded only. */
  reportBooking() {
    if (!this.embedded || !this.opportunityId) {
      return;
    }
    const st = this.state || {};
    const unit = this.summary && this.summary.unit;
    this.dispatchEvent(
      new CustomEvent("bookingopened", {
        detail: {
          opportunityId: this.opportunityId,
          salesOrderId: st.focusedSalesOrderId || null,
          bookingRef: st.focusedSalesOrderId ? st.bookingRef || null : null,
          unitName: unit ? unit.name || null : null,
          /* UI-24: the company on a company booking, as the tab and the summary name it */
          customerName: this.bookingPartyName || st.customerName || null
        },
        bubbles: true,
        composed: true
      })
    );
  }

  /** Put the customer picker back. Only while the booking is still a draft. */
  get canChangeCustomer() {
    /* MSC-214: a journey opened from a lead is FOR that person - swapping them out would
       orphan the conversion it just made */
    return this.hasCustomerPicked && !this.bookingIsCommitted && !this.isLeadJourney;
  }

  /** Everything the customer chose goes with them. The unit stays. */
  handleChangeCustomer() {
    if (!this.canChangeCustomer) return;

    /* the pane flag must not survive a customer swap */
    this.closeVerifyDialog();
    /* and the journey flag */
    this.isNewCustomerJourney = false;
    this.opportunityId = undefined;
    this._bootstrapped = false;

    /* these must match how the properties are declared: `compliance` is a getter, `buckets`
       is an array */
    this.state = {}; // clears compliance AND the previous customer's eligibility
    this.summary = {};
    this.planRows = [];
    this.selectedPlanId = undefined;
    this.buckets = []; // @track buckets = []
    this.docs = {};
    this.ddState = {};
    this.milestoneBatch = {};
    this.chequeResult = undefined;
    this.chequeError = undefined;
    this.proofSlots = {}; // a map keyed by sourceId, not a list
    this.salesOrderId = undefined;
    this.bookingRef = undefined;
    this.confirmed = false;
    this.customerDirty = false;
    this.errorMsg = undefined;

    // back to the step the picker lives on
    this.openSection("details");
  }

  customerDirty = false;
  confirmed = false;
  errorMsg;

  busyPage = false;
  /** searchUnits is in flight. */
  busyUnits = false;
  /** getUnitConfiguration for a ticked unit; separate from busyUnits so the list does not say "Loading units". */
  busyUnitConfig = false;
  busyCustomer = false;
  busyKycLink = false;
  busyComplianceRefresh = false;

  /* MSC-069: the compliance check; complianceCheck is the server's picture */
  complianceCheckOpen = false;
  /* MSC-083: whose check is showing; null is the buyer */
  compliancePartyAccountId;
  complianceCheck;
  busyComplianceCheck = false;
  busyComplianceSave = false;
  busyComplianceSubmit = false;
  complianceCheckError;

  /* MSC-146/148: the company's details workspace; orgDetails is the server's whole answer */
  orgDetailsOpen = false;
  orgDetails;
  busyOrgDetails = false;
  busyOrgSave = false;
  busyOrgSubmit = false;
  busyOrgUpload = false;
  busyOrgSendLink = false;
  orgDetailsError;

  /* MSC-081: the ownership panel; owners is the server's whole answer */
  owners;
  busyOwners = false;
  ownersDrawerOpen = false;
  ownersDrawerMode = "add";
  ownersEditAccountId;
  ownersPreselected;
  ownersPerson;
  ownersSearchStatus = "idle";
  busyOwnersSave = false;
  ownersError;
  ownersGateOpen = false;
  ownersGateAnswered = false;
  _ownersPendingSection;
  /* MSC-082: whose verification link is going out (SENDING is not a record state) */
  ownersSendingAccountId;

  kycLinkMsg = undefined;
  complianceWarning = undefined;
  busyPayment = false;
  busyConfirm = false;

  /** One page, no page scroll: exactly one section open at a time. No IntersectionObserver. */
  openGroup = "unit";

  /** The nav's active key is the step. */
  get activeKey() {
    return this.openGroup;
  }

  layoutMode = "rail";

  labels = LABELS;

  _mql;

  // lifecycle

  connectedCallback() {
    // one media-query listener for the page; children receive `mode` as a prop
    if (typeof window !== "undefined" && window.matchMedia) {
      this._phoneMql = window.matchMedia("(max-width: 767px)");
      this._onPhone = (e) => {
        this.isPhone = e.matches;
      };
      this.isPhone = this._phoneMql.matches;
      this._phoneMql.addEventListener("change", this._onPhone);
      this.loadHoldMinutes();
      this.loadOrgUrl();

      this._mql = window.matchMedia(`(min-width: ${RAIL_MIN_WIDTH}px)`);
      this._onLayout = (e) => {
        this.layoutMode = e.matches ? "rail" : "strip";
      };
      this.layoutMode = this._mql.matches ? "rail" : "strip";
      this._mql.addEventListener("change", this._onLayout);
    }
    // a background tab throttles setInterval; re-read the hold clock on return
    if (typeof document !== "undefined") {
      document.addEventListener("visibilitychange", this.handleVisibility);
    }
  }

  /** One disconnectedCallback (a second definition silently replaces the first). */
  disconnectedCallback() {
    // a timer that outlives the page keeps calling Apex
    this.stopVerificationPoll();
    if (this._phoneMql && this._onPhone) {
      this._phoneMql.removeEventListener("change", this._onPhone);
    }
    if (this._mql && this._onLayout) {
      this._mql.removeEventListener("change", this._onLayout);
    }
    if (typeof document !== "undefined") {
      document.removeEventListener("visibilitychange", this.handleVisibility);
    }
    this.stopPayPolling();
    this.stopHoldTick();
    this.stopSettleWatch();
  }

  /** Reads ?opp= and ?so= from CurrentPageReference (window.location lags LWR routing). */
  @wire(CurrentPageReference)
  handlePageRef(pageRef) {
    if (!pageRef) return;
    const params = pageRef.state || {};
    const opp = this.recordId || params.ref || params.opp || params.opportunityId;
    /* `so` (Book route) or `booking` (the shell's param); the request only */
    if (params.so || params.booking) {
      this._urlOrderId = params.so || params.booking;
    }
    if (opp && opp !== this.opportunityId) {
      this.opportunityId = opp;
      this._bootstrapped = true;
      this.bootstrap();
    } else if (!opp && !this._bootstrapped) {
      // no opportunity is a legitimate starting point
      this._bootstrapped = true;
      this.bootstrap();
    }
  }

  _bootstrapped = false;
  /** Carries the parallel getUnitBrowser result across the resume branch. */
  _browser;

  // bootstrap

  /** Runs with or without an opportunity; without one it loads the project list and stops. */
  async bootstrap() {
    // fire and forget: needed by the customer card, not the unit grid
    this.loadNationalities();
    this.loadLegalStructures();
    this.loadCountryOptions();
    if (!this.opportunityId) {
      this.busyPage = true;
      this.busyUnits = true;
      try {
        /* MSC-212: a lead handoff resolves the lead before the grid. An already-converted lead
           is adopted as its opportunity - true means the full branch below re-ran on it. */
        if (await this.resolveLeadSeed()) {
          return;
        }
        // one round trip
        this.applyUnitBrowser(await getUnitBrowser({
          opportunityId: null, projectId: null, phaseId: null
        }));
        /* MSC-212: land the grid on the seeded lead's project of interest */
        await this.applySeedProject();
      } catch (e) {
        this.errorMsg = reduceError(e);
      } finally {
        this.busyUnits = false;
        this.busyPage = false;
      }
      return;
    }
    this.busyPage = true;
    this.busyUnits = true;
    this.errorMsg = undefined;
    try {
      /* independent, so they overlap */
      const [state, browser] = await Promise.all([
        this.fetchState(),
        getUnitBrowser({
          opportunityId: this.opportunityId, projectId: null, phaseId: null
        })
      ]);
      this._browser = browser;
      this.state = state || {};
      this.salesOrderId = this.state.salesOrderId;
      // every unit this booking made
      this.bookedUnits = this.state.bookedUnits || [];
      this.bookingRef = this.state.bookingRef;
      this.summary = this.state.summary;
      // tell the shell which order the server opened
      this.reportBooking();
      /* a basket resumes as a basket: the unit cache is seeded from bookedUnits (name, price,
       * plan) because the grid returns Available units only and the plan picker does not run on
       * a committed booking. `plans` stays empty: the plan card is locked. */
      /* and only when no order is in focus; a basket member opened alone is the single-unit page */
      const bookedList = this.bookedUnits.filter((b) => b && b.unitId);
      if (bookedList.length > 1 && !this.focusedOrderId) {
        this.selectedUnitIds = bookedList.map((b) => b.unitId);
        const seeded = {};
        bookedList.forEach((b) => {
          seeded[b.unitId] = {
            unitId: b.unitId,
            name: b.unitName || b.unitId,
            plans: [],
            planId: b.planId || undefined,
            planName: b.planName || null,
            totalPrice: b.totalPrice != null ? Number(b.totalPrice) : null,
            salesOrderId: b.salesOrderId,
            bookingRef: b.bookingRef,
            projectName: null,
            tourUrl: null,
            booked: true
          };
        });
        this.unitPlans = seeded;
        /* focus the unit the server focused */
        if (this.summary && this.summary.unit && seeded[this.summary.unit.unitId]) {
          this._focusedUnitId = this.summary.unit.unitId;
        }
      } else if (this.summary && this.summary.unit) {
        this.selectedUnitIds = [this.summary.unit.unitId];
      }
      /* plan.planId, not plan (always an object). Single unit only: on a basket selectedPlanId
         belongs to no unit. */
      if (!this.isMultiUnit && this.summary && this.summary.plan && this.summary.plan.planId) {
        this.selectedPlanId = this.summary.plan.planId;
        this.planRows = this.summary.plan.rows || [];
      }
      /* applied whether or not a unit was restored; getUnitBrowser opens on the booking's own
         project and phase */
      this.applyUnitBrowser(this._browser);
      this._browser = undefined;
      /* the unit is ticked above; this gives it its plans (restoreSingleUnitPlans) */
      await this.restoreSingleUnitPlans();
      if (this.salesOrderId) {
        await Promise.all([
          this.loadBuckets(),
          this.loadDocs(),
          this.loadDirectDebit(),
          this.loadSettlement(),
          this.loadMilestoneBatch()
        ]);
      }
      /* open where the booking actually is (resumeStepFor); openSection also loads the step's data */
      if (this.state.resumeStep) {
        this.openSection(this.state.resumeStep);
      }
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyUnits = false;
      this.busyPage = false;
    }
  }

  /**
   * MSC-212. Resolve the lead this journey was opened from, once. A converted lead comes back
   * as its Opportunity (row.id) and the full bootstrap re-runs on it - the return true tells
   * the no-opportunity branch to stop. Anything the server refuses to seed (queue-owned,
   * Retired, deleted) degrades to the plain journey: the seed is a convenience, never a gate.
   */
  async resolveLeadSeed() {
    if (!this.leadId || this._leadSeedTried) {
      return false;
    }
    this._leadSeedTried = true;
    let row;
    try {
      row = await leadRowById({ leadId: this.leadId });
    } catch (e) {
      return false;
    }
    if (!row) {
      return false;
    }
    if (row.id) {
      /* qualified while the drawer was open: continue as that booking */
      this.isLeadJourney = true;
      this.opportunityId = row.id;
      this.reportOpportunity();
      await this.bootstrap();
      return true;
    }
    this.leadSeed = row;
    this.isLeadJourney = true;
    /* the heading-row switch follows the lead (and hides while the seed is live) */
    if (row.isOrganisation === true) {
      this.buyerType = BUYER_ORGANISATION;
    }
    return false;
  }

  /** MSC-212. Open the grid on the lead's project of interest, when it names a real one. */
  async applySeedProject() {
    const want =
      this.leadSeed && ((this.leadSeed.projectInterest || "").trim().toLowerCase() || null);
    if (!want) {
      return;
    }
    const hit = (this.projects || []).find(
      (p) => p && (p.label || "").trim().toLowerCase() === want
    );
    if (!hit || hit.value === this.selectedProjectId) {
      return;
    }
    /* MSC-215: the default landing (bookable-aware since MSC-213) is kept aside - a lead's
       project with nothing this rep can take falls back to it instead of an empty grid. The
       lead's project stays in the dropdown for the rep who insists. */
    const fallback = {
      projectId: this.selectedProjectId,
      phaseId: this.selectedPhaseId,
      phases: this.phases,
      units: this.units
    };
    /* the same road a project click takes; selectProject contains its own errors */
    await this.selectProject(hit.value);
    if (!(this.units || []).length && (fallback.units || []).length) {
      this.selectedProjectId = fallback.projectId;
      this.selectedPhaseId = fallback.phaseId;
      this.phases = fallback.phases;
      this.units = fallback.units;
    }
  }

  // section states. Customer and Plan unlock together the moment a unit is chosen; nothing
  // ever re-locks.

  get hasUnit() {
    return this.selectedUnitIds.length > 0;
  }
  get hasCustomer() {
    return !!(this.summary && this.summary.customer && this.summary.customer.residentStatus);
  }

  /* one answer to "is the customer step done": eligibilityBlocked is the server's verdict on
   * exactly the fields this step captures, so the tick, the tape, the button and the banner agree */
  get eligibilityBlocked() {
    return !!(this.state && this.state.eligibilityBlocked);
  }

  get customerReady() {
    return this.hasCustomer && !this.eligibilityBlocked;
  }

  /** The forward button holds a company too. Read from the server's customer block, not the pills. */
  get isOrganisationCustomer() {
    const c = this.summary && this.summary.customer;
    return !!(c && c.customerType === "Organisation");
  }
  get hasPlan() {
    // a basket needs a plan on every unit
    return this.isMultiUnit ? this.allUnitsHavePlan : !!this.selectedPlanId;
  }
  get paymentReady() {
    return this.hasUnit && this.hasCustomer && this.hasPlan;
  }

  stateFor(key) {
    /* verify is settled before the blanket rule: confirming starts it, not finishes it */
    if (key === "verify") {
      if (this.complianceDeclined) return "blocked";
      /* a sent link, a verified customer or cleared compliance each read complete */
      const v = this.verificationStatus;
      if (this.complianceCleared || v === "VERIFIED" || v === "SENT") return "complete";
      /* bookingIsCommitted, not confirmed: `confirmed` is a session fact */
      if (!this.bookingIsCommitted) return "todo";
      return "active";
    }
    if (this.bookingIsCommitted && key !== "settlement") return "complete";
    switch (key) {
      case "unit":
        /* a step the agent is still standing on is never complete */
        if (!this.hasUnit) return "active";
        return this.unitOpen ? "active" : "complete";
      case "customer":
        if (!this.hasUnit) return "todo";
        /* customerReady, not hasCustomer */
        return this.customerReady ? "complete" : "active";
      case "plan":
        if (!this.hasUnit) return "todo";
        return this.hasPlan ? "complete" : "active";
      /* the merged card takes the stricter of the two it replaces */
      case "settlement":
        if (!this.paymentReady) return "todo";
        return this.blockers.length ? "blocked" : "active";
      default:
        return "active";
    }
  }

  /** Three entries, one per step; a step inherits a blocker from any member. */
  groupState(groupKey) {
    const group = GROUPS.find((g) => g.key === groupKey);
    if (!group) {
      return "todo";
    }
    const states = group.members.map((m) => this.stateFor(m));
    if (states.every((x) => x === "complete")) {
      return "complete";
    }
    if (states.some((x) => x === "blocked")) {
      return "blocked";
    }
    /* MSC-156: Payment & Confirm goes green when settled. Decided here, not in stateFor, so the
       card does not fold shut on every settled booking. */
    if (groupKey === "settle" && (this.settlementSettled || this.saleClosed)) {
      return "complete";
    }
    return states.some((x) => x === "active") ? "active" : "todo";
  }

  /* the bar carries the deal: a value per step, read from getters already on screen; a step
   * with no value shows a prompt */
  get navSections() {
    return GROUPS.map((g) => ({
      key: g.key,
      label: g.label,
      shortLabel: g.shortLabel || g.label,
      index: g.index,
      state: this.groupState(g.key),
      value: this.navValueFor(g.key),
      prompt: NAV_PROMPTS[g.key]
    }));
  }

  navValueFor(groupKey) {
    if (groupKey === "unit") {
      /* a basket is counted and summed */
      if (this.selectedUnitCount > 1) {
        return `${this.selectedUnitCount} units · ${formatAED(this.basketTotal)}`;
      }
      if (this.unitSummaryLine) {
        return this.unitSummaryLine;
      }
      /* before commit there is no summary, but a unit is ticked */
      const u = this.focusedUnitRecord;
      return u ? `${u.Name} · ${formatAED(u.TotalPrice__c)}` : null;
    }

    if (groupKey === "details") {
      const c = this.summary && this.summary.customer;
      const p = this.summary && this.summary.plan;
      if (!c) {
        return null;
      }
      /* name and plan; a company booking names the company, as the summary does (UI-24) */
      const name = this.bookingPartyName;
      return p && p.planName ? `${name} · ${p.planName}` : name || null;
    }

    if (groupKey === "settle") {
      return this.settlementSummaryLine;
    }

    if (groupKey === "verify") {
      /* the tape reports the link before compliance */
      const status = this.verificationStatus;
      if (status === "VERIFIED" || this.complianceCleared) {
        return LABELS.VERIFIED;
      }
      /* a sent link is the step done from the rep's side */
      if (status === "SENT") {
        return LABELS.VERIFY_TAPE_SENT;
      }
      if (status === "SENDING") {
        return LABELS.VERIFY_SENDING;
      }
      if (status === "EXPIRED") {
        return LABELS.VERIFY_EXPIRED_TITLE;
      }
      if (status === "IN_BRANCH") {
        return LABELS.VERIFY_LATER_TITLE;
      }
      if (status === "SENT") {
        return LABELS.VERIFY_WAITING_TITLE.replace(
          "{0}",
          this.customerDisplayName || "the customer"
        );
      }
      return null;
    }

    return null;
  }

  /**
   * Deliberately not stateFor("unit"): the card would auto-collapse the moment a unit was
   * ticked. It stays open until the agent collapses it.
   */
  get unitSectionState() {
    return this.confirmed ? "complete" : "active";
  }
  get customerSectionState() {
    return this.stateFor("customer");
  }
  get planSectionState() {
    return this.stateFor("plan");
  }
  get settlementSectionState() {
    return this.stateFor("settlement");
  }

  get unitAside() {
    return this.hasUnit ? null : LABELS.LOCKED_NEED_UNIT;
  }
  get customerAside() {
    return this.hasUnit ? null : LABELS.LOCKED_NEED_UNIT;
  }
  get planAside() {
    if (!this.hasUnit) {
      return LABELS.LOCKED_NEED_UNIT;
    }
    /* a basket says how far through it is */
    if (this.isMultiUnit) {
      const total = this.selectedUnitIds.length;
      const done = this.selectedUnitIds.filter(
        (id) => this.unitPlans[id] && this.unitPlans[id].planId
      ).length;
      return done === total ? `All ${total} units` : `${done} of ${total} units`;
    }
    return null;
  }
  /** One aside for the merged card, naming the first thing missing. */
  get settlementAside() {
    if (this.paymentReady) return null;
    if (!this.hasUnit) return LABELS.LOCKED_NEED_UNIT;
    if (!this.hasCustomer) return LABELS.LOCKED_NEED_CUSTOMER;
    return LABELS.LOCKED_NEED_PLAN;
  }

  get unitSummaryLine() {
    const u = this.summary && this.summary.unit;
    return u ? `${u.name} · ${formatAED(u.totalPrice)}` : null;
  }
  get customerSummaryLine() {
    const c = this.summary && this.summary.customer;
    return c ? `${this.bookingPartyName || ""} · ${c.residentStatus || ""}`.trim() : null;
  }

  /** Who the booking is for: the company on a company booking (its contact is c.name), else the person. */
  get bookingPartyName() {
    const c = this.summary && this.summary.customer;
    if (!c) {
      return null;
    }
    const isCompany = String(c.customerType || "").toLowerCase().indexOf("organ") === 0;
    return (isCompany && c.companyName) || c.name || null;
  }
  /** The line Payment collapses into. */
  /**
   * MSC-156: the booking is settled (nothing outstanding on the closing legs and the gate
   * satisfied). Not the same as committed.
   */
  get settlementSettled() {
    const s = this.settlement;
    return !!s && s.fullySettled === true && s.gateSatisfied === true;
  }

  /** MODON has closed the sale (Closed Won, unit Sold), though the order may still read New. */
  get saleClosed() {
    return !!this.summary && this.summary.saleClosed === true;
  }

  get settlementSummaryLine() {
    /* the documents branch is gone: Further_Documents_Required__c fires on Partially Paid */
    /* the settlement figure, not Due Now (null for a basket) */
    const s = this.settlement;
    /* 1.x+12 - the preview is the fee formula, which a no-fee unit never pays */
    if (this.settlementNoFee && s && Number(s.totalCollected || 0) === 0) {
      return LABELS.SETTLE_HEAD_NO_FEE;
    }
    if (s && Number(s.totalRemaining || 0) > 0) {
      /* "Balance" was wrong before Confirm: the figure is the deposit */
      const word = s.isBookingFee
        ? LABELS.SETTLE_TAPE_FEE
        : LABELS.SETTLE_TAPE_OUTSTANDING;
      return `${word} · ${formatAED(s.totalRemaining)}`;
    }
    /* R2-11: a fee that is in reads as collected, before Confirm and after; the header says the same */
    if (s && Number(s.totalRequired || 0) > 0 && (s.isBookingFee === true || s.bookingConfirmed !== true)) {
      return LABELS.SETTLE_HEAD_FEE_IN;
    }
    /* MSC-156: same expression the tape's colour reads */
    if (this.settlementSettled || this.saleClosed || this.ledgerFinalising) {
      return LABELS.SETTLE_HEAD_SETTLED;
    }
    if (s && Number(s.totalRequired || 0) > 0) {
      return LABELS.SETTLE_CLEARING;
    }
    if (this.isMultiUnit) {
      return LABELS.MULTI_NO_PAYMENT_TITLE;
    }
    return null;
  }

  get planSummaryLine() {
    const p = this.summary && this.summary.plan;
    return p && p.planName ? `${p.planName} · ${p.milestoneCount} ${LABELS.MILESTONES}` : null;
  }

  // layout

  /** The console's theme: prop first, then the cache the shell writes, then dark. */
  @api theme;

  get resolvedTheme() {
    if (this.theme === "light" || this.theme === "dark") {
      return this.theme;
    }
    try {
      const cached = window.localStorage.getItem("msc-theme");
      if (cached === "light" || cached === "dark") {
        return cached;
      }
    } catch {
      // private browsing denies localStorage
    }
    return "dark";
  }

  /** Embedded, the sheet's themed subtree already supplies every token. */
  get hostStyleAttr() {
    if (this.embedded) {
      return "";
    }
    const tokens = hostStyle(this.resolvedTheme, this.accentColor);
    // only when an image is configured; otherwise --backdrop tracks the theme
    return this.backgroundImage
      ? `${tokens};--msc-backdrop:url(${this.backgroundImage})`
      : tokens;
  }

  /* embedded mode */
  /** True when hosted inside the hub's sheet rather than on the Book route. Changes chrome only. */
  @api embedded = false;

  get showOwnChrome() {
    return !this.embedded;
  }

  /** Embedded, the sheet owns the height and the backdrop. */
  get pageClass() {
    return this.embedded ? "page page--embedded" : "page";
  }

  get isRail() {
    return this.layoutMode === "rail";
  }

  /** Always: one panel for either shape of booking. */
  get showSummaryPanel() {
    return true;
  }

  /** The rail is wider while it holds the walkthrough; 360 once the summary takes over. */
  /**
   * Three states, from the PoC's bodyClass: a column is reserved only when there is something
   * to put in it.
   *   tour     unit picked, tour resolves, not a phone -> list 34% | tour 66%
   *   summary  booking has content to recap           -> summary 300px | form
   *   neither  single column, capped measure, centred
   */
  get bodyClass() {
    if (!this.isRail) {
      return "body";
    }
    if (this.showRailTour) {
      return "body body--rail body--rail-tour";
    }
    if (this.showRailSummaryPane) {
      return "body body--rail body--rail-summary";
    }
    return "body";
  }

  /** Either occupant of the summary rail. */
  get showRailSummaryPane() {
    return this.showRailSummary;
  }

  /** The rail renders only when one of the panes will fill it. */
  get showRail() {
    return this.showRailTour || this.showRailSummaryPane;
  }

  /* the rail: one right-hand column, two occupants. The walkthrough while the agent is choosing,
   * the summary once they have named a customer. Always present at this width. */

  /** The unit the walkthrough is showing; the newest tick is the default. */
  _focusedUnitId;

  get focusedUnitId() {
    const ids = this.selectedUnitIds || [];
    if (this._focusedUnitId && ids.includes(this._focusedUnitId)) {
      return this._focusedUnitId;
    }
    return ids.length ? ids[ids.length - 1] : null;
  }

  get focusedUnitName() {
    const id = this.focusedUnitId;
    if (!id) {
      return null;
    }
    const cached = this.unitPlans[id];
    if (cached && cached.name) {
      return cached.name;
    }
    const u = (this.units || []).find((x) => x.Id === id);
    if (u && u.Name) {
      return u.Name;
    }
    const s = this.summary && this.summary.unit;
    return (s && s.name) || null;
  }

  /** Two sources: the per-unit cache, then the booking summary (a resumed booking). */
  get focusedUnitTourUrl() {
    const id = this.focusedUnitId;
    if (!id) {
      return null;
    }
    const cached = this.unitPlans[id];
    if (cached && cached.tourUrl) {
      return cached.tourUrl;
    }
    // a committed basket's units carry their own tour URL
    const svr = this.serverUnitBlock(id);
    if (svr && svr.tourUrl) {
      return svr.tourUrl;
    }
    if (this.isSingleUnit) {
      const u = this.summary && this.summary.unit;
      if (u && u.tourUrl) {
        return u.tourUrl;
      }
    }
    /* the PoC's derived URL for units MBP_MasterplanSyncBatch has not reached */
    return unitTourUrl(this.focusedUnitName);
  }

  get hasTour() {
    return !!this.focusedUnitTourUrl && !this.isPhone;
  }

  /** A basket has no one unit to walk through, so the agent names which. */
  get tourUnitChips() {
    if (!this.isMultiUnit) {
      return [];
    }
    const focus = this.focusedUnitId;
    return (this.selectedUnitIds || []).map((id) => {
      const cached = this.unitPlans[id];
      const u = (this.units || []).find((x) => x.Id === id);
      const on = id === focus;
      return {
        id,
        name: (cached && cached.name) || (u && u.Name) || id,
        cls: on ? "tour-chip tour-chip--on" : "tour-chip"
      };
    });
  }

  handleTourUnit(event) {
    this.handleFocusUnit(event);
  }

  /* the basket's payment plan card: the same card focused on one unit at a time, tabs name
   * which (the same focusedUnitId as the walkthrough). c/mscPlanSelect is reused unchanged. */
  handleFocusUnit(event) {
    this._focusedUnitId = event.currentTarget.dataset.id;
  }

  /**
   * MSC-093: the plan card opens on the first unit of the basket, on arrival at the step only,
   * never once the booking is committed.
   */
  focusFirstUnitForPlans() {
    if (!this.isMultiUnit || this.bookingIsCommitted) {
      return;
    }
    const ids = this.selectedUnitIds || [];
    if (ids.length) {
      this._focusedUnitId = ids[0];
    }
  }

  /* the per-unit fee block is gone, with getUnitPlanFees */

  get focusedUnitEntry() {
    const id = this.focusedUnitId;
    return (id && this.unitPlans[id]) || null;
  }

  /* a duplicate focusedUnitRecord getter used to sit here; the later declaration wins */

  /** Raw PaymentPlan__c records; mscPlanSelect reads p.Id || p.id. */
  get focusedUnitPlans() {
    const e = this.focusedUnitEntry;
    return (e && e.plans) || [];
  }

  get focusedUnitPlanId() {
    const e = this.focusedUnitEntry;
    return e ? e.planId : undefined;
  }

  get focusedUnitPlan() {
    const e = this.focusedUnitEntry;
    if (!e || !e.planId) return null;
    /* p.Id, not p.planId */
    return (e.plans || []).find((p) => (p.Id || p.id) === e.planId) || null;
  }

  get focusedUnitPrice() {
    /* 1.x+15 - the chosen option prices the unit, as basketTotal and the order already do */
    const entry = this.focusedUnitEntry;
    const optionPrice =
      entry && entry.unitOptionId && entry.optionPrices ? entry.optionPrices[entry.unitOptionId] : null;
    if (Number(optionPrice) > 0) {
      return Number(optionPrice);
    }
    const u = this.focusedUnitRecord;
    if (u && u.TotalPrice__c != null) {
      return u.TotalPrice__c;
    }
    // a resumed basket's unit is not in the grid; its booked price is cached
    const e = this.focusedUnitEntry;
    return e && e.totalPrice != null ? e.totalPrice : null;
  }

  get focusedUnitPlanRows() {
    const fromTemplate = this.rawScheduleForPlan(this.focusedUnitPlan, this.focusedUnitPrice);
    if (fromTemplate.length) {
      return fromTemplate;
    }
    /* a committed basket has the schedule its Sales Order carries, from the summary */
    const svr = this.serverPlanBlock(this.focusedUnitId);
    return svr && Array.isArray(svr.rows) ? svr.rows : [];
  }

  /** One tab per unit, with a dot saying whether that unit has a plan yet. */
  get unitPlanTabs() {
    const focus = this.focusedUnitId;
    return (this.selectedUnitIds || []).map((id) => {
      const entry = this.unitPlans[id];
      const u = (this.units || []).find((x) => x.Id === id);
      const name = (entry && entry.name) || (u && u.Name) || id;
      const on = id === focus;
      const done = !!(entry && entry.planId);
      return {
        id,
        name,
        cls: on ? "plantab plantab--on" : "plantab",
        dotCls: done ? "plantab__dot plantab__dot--ok" : "plantab__dot plantab__dot--no",
        selected: on ? "true" : "false",
        title: done ? `${name}: payment plan chosen` : `${name}: no payment plan yet`
      };
    });
  }

  /* the key fields under the walkthrough (the walkthrough's own panel reads "Total price: TBC").
   * Fields checked against the org: price, bedrooms, typology, GSA, plot area. View, Area, GFA
   * and Floor are dropped because they are populated on almost no records. */
  get focusedUnitRecord() {
    const id = this.focusedUnitId;
    if (!id) {
      return null;
    }
    return (this.units || []).find((u) => u.Id === id) || null;
  }

  get focusedUnitFacts() {
    const u = this.focusedUnitRecord;
    if (!u) {
      return [];
    }
    const sqm = (v) =>
      v == null || v === ""
        ? null
        : `${Number(v).toLocaleString("en-AE", { maximumFractionDigits: 2 })} sqm`;

    return [
      { key: "price", label: LABELS.TOTAL_PRICE, value: formatAED(u.TotalPrice__c) },
      {
        key: "beds",
        label: "Bedrooms",
        value: u.Number_of_Bedrooms__c == null ? null : String(u.Number_of_Bedrooms__c)
      },
      { key: "typology", label: "Typology", value: u.Typology__c },
      { key: "gsa", label: "GSA", value: sqm(u.TotalGrossSellableAreaGSA__c) },
      { key: "plot", label: "Plot area", value: sqm(u.PlotAreasqm__c) },
      {
        key: "phase",
        label: "Phase",
        value: u.Phase__r ? u.Phase__r.Name : null
      }
      /* dropped rather than rendered blank */
    ].filter((f) => f.value !== null && f.value !== undefined && f.value !== "");
  }

  get showUnitFacts() {
    return this.focusedUnitFacts.length > 0;
  }

  /* basketRows, basketTotalDisplay and scheduleForPlan are gone; the rail takes one `lines` model */

  /**
   * The schedule in c/mscPlanSelect's own shape (raw percent, amount, date), computed here for
   * a basket from the installments that arrive with getUnitConfiguration.
   */
  rawScheduleForPlan(plan, totalPrice) {
    if (!plan) return [];
    const list = plan.installments || [];
    return list
      .slice()
      .sort((a, b) => (a.MilestoneNumber__c || 0) - (b.MilestoneNumber__c || 0))
      .map((pi, i) => {
        const pct = pi.Milestone__c;
        return {
          installmentId: pi.Id,
          milestoneNumber: pi.MilestoneNumber__c,
          description: pi.MilestoneDescription__c || pi.Name || `Milestone ${i + 1}`,
          percent: pct != null ? pct : null,
          amount: totalPrice != null && pct != null ? (totalPrice * pct) / 100 : null,
          dueDate: pi.MilestoneDate__c || null
        };
      });
  }

  /* the summary rail: one panel for one unit or many. A row appears because the data exists,
   * never because a mode flag says so. Everything is derived here from state the journey holds. */

  /**
   * The units as one model. Three sources in precedence order: the server's UnitBlock, the unit
   * cache, the browsed record.
   */
  get summaryLines() {
    const ids = this.selectedUnitIds || [];
    if (!ids.length) {
      return [];
    }
    const single = ids.length === 1;
    const su = this.summary && this.summary.unit ? this.summary.unit : null;
    const sp = this.summary && this.summary.plan ? this.summary.plan : null;
    const sqm = (v) =>
      v == null || v === ""
        ? null
        : `${Number(v).toLocaleString("en-AE", { maximumFractionDigits: 0 })} sqm`;

    return ids.map((id) => {
      const cached = this.unitPlans[id] || {};
      const rec = (this.units || []).find((x) => x.Id === id) || null;
      /* the server's block for this unit first (a committed basket carries one per order) */
      const svr =
        this.serverUnitBlock(id) || (su && (su.unitId === id || single) ? su : null);
      const svrPlan = this.serverPlanBlock(id);

      /* a PaymentPlan__c record carries Id and Name; match on p.Id */
      const chosenPlanId = single ? this.selectedPlanId || cached.planId : cached.planId;
      const cachedPlan = (cached.plans || []).find((p) => (p.Id || p.id) === chosenPlanId);
      let planName = cachedPlan ? cachedPlan.Name || cachedPlan.name : null;
      if (!planName && svrPlan && svrPlan.planName) {
        // the plan this unit was booked on
        planName = svrPlan.planName;
      }
      if (!planName && cached.planName) {
        // or the one bookedUnits seeded
        planName = cached.planName;
      }
      if (!planName && single && sp && sp.planName) {
        /* a resumed single-unit booking has the plan on the server summary first */
        planName = sp.planName;
      }

      const beds =
        svr && svr.bedrooms
          ? svr.bedrooms
          : rec && rec.Number_of_Bedrooms__c != null
            ? String(rec.Number_of_Bedrooms__c)
            : null;
      const type = (svr && svr.classification) || (rec && rec.Typology__c) || null;
      const project =
        (svr && svr.project) || cached.projectName || (rec && rec.Project_Name__c) || null;
      const phase = (svr && svr.phase) || (rec && rec.Phase__r ? rec.Phase__r.Name : null);
      const area =
        svr && svr.area != null
          ? svr.area
          : rec
            ? rec.TotalGrossSellableAreaGSA__c
            : null;
      const price =
        svr && svr.totalPrice != null
          ? svr.totalPrice
          : cached.totalPrice != null
            ? cached.totalPrice
            : rec
              ? rec.TotalPrice__c
              : null;

      return {
        id,
        name: (svr && svr.name) || cached.name || (rec && rec.Name) || id,
        meta: [beds ? `${beds} BR` : null, type].filter(Boolean).join(" · "),
        where: [project, phase, sqm(area)].filter(Boolean).join(" · "),
        price: price == null ? null : formatAED(price),
        planName: planName || LABELS.BASKET_NO_PLAN,
        /* MSC-161: chip--pending, not chip--due; amber is for what the rep must act on */
        planCls: planName ? "chip chip--paid" : "chip chip--pending",
        hasPlan: !!planName
      };
    });
  }

  get summaryPlansChosen() {
    return this.summaryLines.filter((l) => l.hasPlan).length;
  }

  /** "1 unit" / "3 units". */
  get summaryUnitCountText() {
    const n = this.summaryLines.length;
    if (!n) {
      return null;
    }
    return n === 1 ? LABELS.SUMMARY_UNIT_ONE : LABELS.SUMMARY_UNITS_N.replace("{0}", String(n));
  }

  /** Every amount the booking has, formatted, null when it does not exist. */
  /** Is the money on this screen the deposit or the closing amount? SummaryDTO.fees is a preview. */
  get settlementIsBookingFee() {
    return !!this.settlement && this.settlement.isBookingFee === true;
  }

  get summaryTotals() {
    const s = this.summary || {};
    const f = s.fees || null;
    const money = (v) => (v == null || Number(v) === 0 ? null : formatAED(v));
    /* the server's figure where there is one, the client's sum where there is not */
    const totalRaw =
      s.totalPrice != null && Number(s.totalPrice) > 0 ? Number(s.totalPrice) : this.basketTotal;
    /* once the Sales Order exists the record is the ledger's: Collected is what its rows show as
       paid, Balance what is left */
    const committed = this.bookingIsCommitted;
    const ledger = committed
      ? (this.buckets || []).filter((b) => b.sourceObject !== "Booking_Fee_Line__c")
      : [];
    const sum = (rows, pick) => rows.reduce((acc, r) => acc + (Number(pick(r)) || 0), 0);
    const admCharge = sum(ledger.filter((b) => b.key === "ADM_DARI_CHARGE"), (b) => b.requiredAmount);
    const ledgerCollected = sum(ledger, (b) => b.paidAmount);
    const ledgerLeft = sum(ledger, (b) => Math.max(0, Number(b.remainingAmount) || 0));
    const useLedger = committed && ledger.length > 0;
    return {
      total: money(totalRaw),
      downPayment: f ? money(f.downPayment) : null,
      admFee: f ? money(f.admFee) : null,
      /* 1.x+12 - a unit that takes no booking fee has none to show, here or in the masthead */
      dueNow: f && !this.settlementNoFee ? money(f.minimum) : null,
      // which set of names these figures may wear
      isBookingFee: this.settlementIsBookingFee,
      collected: useLedger ? money(ledgerCollected) : money(s.collected),
      /* only once something has been collected */
      balance: useLedger
        ? money(ledgerLeft)
        : Number(s.collected) > 0 ? money(s.balance) : null,
      // the post-Confirm shape
      isCommitted: useLedger,
      admCharge: useLedger ? money(admCharge) : null,
      leftRaw: useLedger ? ledgerLeft : null,
      scheduledCount: useLedger ? ledger.length : 0
    };
  }

  /** The masthead: the one figure the current step is about (the total, then Due Now, then a state). */
  get summaryHeadline() {
    const s = this.summary || {};
    const t = this.summaryTotals;
    const step = this.currentSectionKey;

    const cancelled =
      s.stage === "Cancelled" || s.stage === "System cancelled" || s.stage === "Voided";
    /* 1.x+14 - MODON closed the sale but left Status__c on New: the server says so */
    const saleClosed = s.saleClosed === true;
    const stage = saleClosed
      ? LABELS.SETTLE_DONE
      : stageLabel(s.stage, s.subStage) || LABELS.SUMMARY_DRAFT;
    /* amber is reserved for something being wrong */
    const stageTone = cancelled ? "bad" : saleClosed || this.confirmed ? "good" : "flat";

    let label = LABELS.TOTAL_PRICE;
    let figure = t.total || "-";
    let figureSmall = false;
    let sub = null;

    if (step === "verify") {
      label = LABELS.SUMMARY_VERIFICATION;
      /* navValueFor already words every verification state */
      figure = this.navValueFor("verify") || LABELS.VERIFY_STATUS_WAITING;
      figureSmall = true;
      sub = t.total ? `${this.summaryUnitCountText} · ${t.total}` : this.summaryUnitCountText;
    } else if (step === "settle" && t.isCommitted) {
      /* the booking is made: what is still to collect, with the booking fee said in words */
      label = LABELS.SUMMARY_LEFT;
      figure = t.balance || "-";
      const fs = this.feeStatus;
      const feeDue = fs && fs.totalDue != null ? Number(fs.totalDue) : 0;
      const feePaid = fs && fs.totalPaid != null ? Number(fs.totalPaid) : 0;
      const bits = [];
      if (feeDue > 0) {
        bits.push(
          feePaid + 0.005 >= feeDue
            ? LABELS.SUMMARY_FEE_IN_FULL
            : LABELS.SUMMARY_FEE_PART.replace("{0}", formatAED(feePaid))
        );
      }
      if (t.scheduledCount > 0) {
        bits.push(
          t.scheduledCount === 1
            ? LABELS.SUMMARY_PAYMENT_SCHEDULED
            : LABELS.SUMMARY_PAYMENTS_SCHEDULED.replace("{0}", String(t.scheduledCount))
        );
      }
      sub = bits.length ? bits.join(" · ") : t.total ? `${LABELS.TOTAL_PRICE} ${t.total}` : null;
    } else if (step === "settle" && t.dueNow) {
      /* "Booking fee", not "Due Now", while that is what the figure is (isBookingFee) */
      label = this.settlementIsBookingFee ? LABELS.BOOKING_FEE : LABELS.DUE_NOW;
      figure = t.dueNow;
      const fs = this.feeStatus;
      const outstanding =
        fs && fs.totalBalance != null && Number(fs.totalBalance) > 0
          ? formatAED(fs.totalBalance)
          : null;
      if (t.collected && outstanding) {
        sub = LABELS.SUMMARY_COLLECTED_OUTSTANDING.replace("{0}", t.collected).replace(
          "{1}",
          outstanding
        );
      } else if (t.collected) {
        sub = `${t.collected} collected`;
      } else if (t.total) {
        sub = `${LABELS.TOTAL_PRICE} ${t.total}`;
      }
    } else {
      const n = this.summaryLines.length;
      sub = this.summaryUnitCountText;
      if (sub && n > 1) {
        sub = `${sub} · ${LABELS.SUMMARY_PLANS_CHOSEN.replace(
          "{0}",
          String(this.summaryPlansChosen)
        ).replace("{1}", String(n))}`;
      }
    }

    return {
      reference: s.bookingReference || LABELS.SUMMARY_NOT_BOOKED,
      stage,
      stageTone,
      label,
      figure,
      figureSmall,
      sub
      /* `steps` is gone with the meter it fed */
    };
  }

  /**
   * The focus line: what is needed to move on. Ordered by urgency; blockers verbatim so the rail
   * cannot phrase an obstacle differently from Review. Null when nothing is outstanding.
   */
  get summaryFocus() {
    const step = this.currentSectionKey;

    /* the hold line is gone from here: the card carries the clock beside the button */

    if (step === "verify") {
      if (this.complianceDeclined) {
        return { text: LABELS.FOCUS_VERIFY_DECLINED, tone: "bad" };
      }
      /* verified is the masthead's own figure; a sent link asks nothing of the rep */
      if (this.complianceCleared || this.verificationStatus === "VERIFIED"
          || this.verificationStatus === "SENT") {
        return null;
      }
      return { text: LABELS.FOCUS_VERIFY_WAIT, tone: "warn" };
    }

    /* the unit step answers for itself */
    if (step === "unit") {
      return this.hasUnit ? null : { text: LABELS.FOCUS_CHOOSE_UNIT, tone: "flat" };
    }

    /* the verification line is removed: it named a button on another step. The gate itself is
       untouched (barBlockedReason). */

    /* while the fee is awaited the fee blockers are already on the header; only structural
       blockers remain */
    const blocking = this.awaitingFeeReceipt ? this.structuralBlockers : this.blockers;
    if (blocking.length) {
      return { text: blocking[0], tone: "warn" };
    }

    /* gated on the count, not on Further_Documents_Required__c. outstandingLabels is the real
       list (docs.outstandingCount never existed). */
    /* the outstanding-documents line is off for now, with the checklist region */

    /* and nothing when there is nothing to act on */
    return null;
  }

  /** Every Sales Order's obligations (buckets), not just summary.payments' one order. */
  get summaryPayments() {
    if (Array.isArray(this.buckets) && this.buckets.length) {
      return this.buckets;
    }
    return (this.summary && this.summary.payments) || [];
  }

  /* the rail switch and its getters are deleted; the step decides the occupant */

  // what the rail renders at rail width
  /* the rail follows the step: the walkthrough on the unit step, the summary on every other */
  get showRailTour() {
    return this.isRail && this.unitOpen && this.hasTour;
  }

  /* one getter for both shapes */
  get showRailSummary() {
    return this.isRail && !this.unitOpen && this.hasUnit;
  }

  /* showRailHint is gone: no second column until there is content */

  /** Never on a phone: world.modon.com is not legible at 390px. */
  isPhone = false;

  /** Below the rail breakpoint the tour falls back under the grid, collapsed. */
  /* the inline fallbacks follow the same rule as the rail */
  get showInlineTour() {
    return !this.isRail && this.unitOpen && this.hasTour;
  }

  /* showInlineSummary covers both shapes */

  /** Below 1280px the rail becomes a card inline in the scroll column. */
  /* not on a phone: the action bar reaches the same panel */
  get showInlineSummary() {
    return !this.isRail && !this.isPhone && !this.unitOpen && this.hasUnit;
  }

  /** UI-17: the unit facts go on the selected card wherever the rail's tour is not beside the list. */
  get showCardFacts() {
    return !this.showRailTour;
  }

  /** The pinned section rail is kept only where the summary is not persistent. */
  /* always: the rail recaps the booking, the path shows progress */
  get showProgressNav() {
    return true;
  }

  /* open another unit of this booking: embedded, `opensibling` makes mscWorkspace remount the
   * page (a clean mount is the only honest way to drop per-booking state); standalone, a real
   * navigation to ?opp=&so= */
  handleOpenSibling(e) {
    const d = (e && e.detail) || {};
    const salesOrderId = d.salesOrderId;
    if (!salesOrderId || salesOrderId === this.focusedOrderId) {
      return;
    }
    if (this.embedded) {
      this.dispatchEvent(
        new CustomEvent("opensibling", {
          detail: { opportunityId: this.opportunityId, salesOrderId },
          bubbles: true,
          composed: true
        })
      );
      return;
    }
    if (typeof window !== "undefined" && window.location) {
      const url = new URL(window.location.href);
      url.searchParams.set("ref", this.opportunityId);
      url.searchParams.delete("opp");
      url.searchParams.set("so", salesOrderId);
      url.searchParams.delete("booking");
      window.location.assign(url.toString());
    }
  }

  /**
   * MSC-104: refuses a step below the floor, whatever raised it. Forward jumps and uncommitted
   * bookings behave as before.
   */
  async handleJump(event) {
    const d = event.detail || {};
    const key = d.key || d.section;
    if (this.isBelowNavFloor(key)) {
      return;
    }
    /* 1.x+11: nor round the facade style and pre-approval number */
    if (!this.bookingExtrasPass(this.currentSectionKey, key)) {
      return;
    }
    /* 1.x+6: the rail is not a way round the EOI gates */
    if (!(await this.eoiGatePasses(this.currentSectionKey, key))) {
      return;
    }
    this.openSection(key);
  }

  /** The step after Confirm; openSection is the same navigation the tape uses. */
  handleAdvanceToVerify() {
    this.openSection("verify");
  }

  /** Opening is the navigation: nothing to scroll or measure. */
  openSection(key) {
    if (!key) {
      return;
    }
    /* MSC-081: leaving Verification with an unowned unit asks once; either answer continues */
    if (this.ownersGateNeeded(key)) {
      this._ownersPendingSection = key;
      this.ownersGateOpen = true;
      return;
    }
    // section key or step key; both mean "open the step this belongs to"
    const group = GROUP_OF[key] || key;
    /* MSC-093: arriving at a step is not re-opening the one on screen */
    const arriving = this.openGroup !== group;
    /* MSC-163: the error banner clears only when the step actually changes */
    if (arriving) {
      this.errorMsg = undefined;
      /* MSC-166: the "link sent" line clears too; complianceWarning is kept for Verification */
      this.kycLinkMsg = undefined;
    }
    this.openGroup = group;
    if (group === "details" && arriving) {
      this.focusFirstUnitForPlans();
    }
    // MSC-081: owners, read on arrival at the step that shows them
    if (this.openGroup === "verify") {
      this.loadOwners();
    }
    /* the fee is read on arrival at the confirm step (it changes with the plan) */
    if (this.openGroup === "settle") {
      /* and start watching if a fee is still owed, on resume too */
      /* the hold is read before the watch starts, so the watch takes the real deadline */
      Promise.all([this.loadFees(), this.syncHold()]).then(() =>
        this.maybeStartPayPolling()
      );
      // offers, read at the same moment
      this.loadOffers();
      /* and the settlement figure, for the same reason as the fee */
      this.loadSettlement();
    } else {
      this.stopPayPolling();
      this.stopHoldTick();
    }
  }

  /* both members of a step open together */
  get unitOpen() {
    return this.openGroup === "unit";
  }
  get customerOpen() {
    return this.openGroup === "details";
  }
  get paymentOpen() {
    return this.openGroup === "settle";
  }
  get verifyOpen() {
    return this.openGroup === "verify";
  }

  get verifySectionState() {
    return this.stateFor("verify");
  }

  /** Only says anything while the step is out of reach. */
  get verifyAside() {
    return this.bookingIsCommitted ? null : LABELS.VERIFY_ASIDE;
  }

  /** The compliance chain has run to a clear result, read off ComplianceStateDTO. */
  get complianceCleared() {
    /* "Approved" is the raw PassfortApprovalStatus__pc value; the one terminal-good state */
    return (this.compliance || {}).approvalStatus === "Approved";
  }

  /** Declined is terminal too; the step shows it as blocked. */
  get complianceDeclined() {
    return (this.compliance || {}).approvalStatus === "Rejected";
  }

  /* forward action */
  /** The forward button. It scrolls; it does not gate or submit. */

  /** The next step, not the next incomplete one: the groups are separate screens now. */
  nextKeyAfter(key) {
    const i = NEXT_ORDER.indexOf(key);
    if (i === -1) {
      return null;
    }
    if (i + 1 < NEXT_ORDER.length) {
      return NEXT_ORDER[i + 1];
    }
    /* once confirmed the end of the road is verification, not settle */
    return this.confirmed ? "verify" : "settle";
  }

  nextLabelAfter(key) {
    const target = this.nextKeyAfter(key);
    if (!target) {
      return null;
    }
    const group = GROUPS.find((g) => g.key === target);
    return LABELS.CTA_CONTINUE_TO.replace("{0}", group ? group.label : "");
  }

  get unitNextLabel() {
    return this.nextLabelAfter("unit");
  }
  get unitNextDisabled() {
    return !this.hasUnit;
  }
  get unitNextHint() {
    return LABELS.LOCKED_NEED_UNIT;
  }

  get customerNextLabel() {
    /* "details", not "customer": nextKeyAfter indexes step keys */
    return this.nextLabelAfter("details");
  }
  get customerNextDisabled() {
    return !this.hasCustomer;
  }
  get customerNextHint() {
    // nobody chosen, versus chosen but not saved
    return this.needsCustomer
      ? LABELS.LOCKED_NEED_CUSTOMER_PICK
      : LABELS.LOCKED_NEED_CUSTOMER;
  }

  get planNextLabel() {
    return this.nextLabelAfter("plan");
  }
  get planNextDisabled() {
    return !this.hasPlan;
  }
  get planNextHint() {
    return LABELS.LOCKED_NEED_PLAN;
  }

  /* paymentNextLabel / paymentNextDisabled / paymentNextHint deleted with the per-section button */

  /* the action bar: one sticky bar at the foot of the page, following the section being read */

  /** The open section. */
  get currentSectionKey() {
    return NEXT_ORDER.includes(this.openGroup) ? this.openGroup : "unit";
  }

  /** UI-09: the bar shows only when it holds something (Back, the forward button, the gap line or the phone summary). */
  get showActionBar() {
    return this.showBack || this.showNext || this.showCustomerGap || this.showBarSummary;
  }

  /** Settle ends in Confirm; verify is the end of the journey. */
  get showNext() {
    return this.currentSectionKey !== "settle" && this.currentSectionKey !== "verify";
  }

  get barLabel() {
    return this.nextLabelAfter(this.currentSectionKey);
  }

  /**
   * PHASE 4. Whether c/mscKycGate says this customer's KYC holds up the step. Set from that
   * panel's `kycstate` event, and false whenever the hard gate for their buyer type is off.
   *
   * This is a courtesy, not the gate. SalesConsoleController refuses the money inside the
   * money methods themselves, so a stale tab, a re-enabled button or a direct Apex call is
   * refused regardless of what this holds.
   */
  kycBlocks = false;

  /* B4: the Update KYC dialog, hosted here at .page level. Opened by c/mscKycCapture's `openkyc`
     (composed, through c/mscKycGate); on close the gate re-reads everything. */
  kycModalOpen = false;
  kycModalSubjectId;
  kycModalSubjectName;

  handleOpenKyc(event) {
    const d = (event && event.detail) || {};
    if (!d.subjectId) {
      return;
    }
    this.kycModalSubjectId = d.subjectId;
    this.kycModalSubjectName = d.subjectName;
    this.kycModalOpen = true;
  }

  handleKycModalClose(event) {
    this.kycModalOpen = false;
    const saved = !!(event && event.detail && event.detail.saved);
    const gate = this.template.querySelector("c-msc-kyc-gate");
    if (gate && typeof gate.refresh === "function") {
      gate.refresh(saved);
    }
  }

  handleKycState(event) {
    this.kycBlocks = !!(event.detail && event.detail.blocks);
  }

  get barDisabled() {
    if (this.currentSectionKey === "unit") {
      /* held while the unit's configuration is in flight */
      return !this.hasUnit || this.busyUnitConfig;
    }
    if (this.currentSectionKey === "details") {
      // both halves of the step
      if (!this.hasCustomer || !this.hasPlan) {
        return true;
      }
      /* the customer's completeness is not a disabled button: handleBarNext validates on the
         press and scrolls to the gap */
      /* and the verification gate; reviewAndConfirm re-checks it server-side */
      /* Phase 4: and the KYC hard gate, which reviewAndConfirm and every money method
         re-check server-side and independently of this button */
      return this.verificationBlocks || this.kycBlocks;
    }
    return false;
  }



  /** The running state of the booking, on the strip that is always visible. */
  get barContext() {
    /* nothing on the unit step */
    if (this.currentSectionKey === "unit" && !this.hasUnit) {
      return "";
    }
    if (this.isMultiUnit) {
      return `${this.selectedUnitCount} units · ${formatAED(this.basketTotal)}`;
    }
    return this.unitSummaryLine || "";
  }

  async handleBarNext() {
    /* the one validation this button performs itself: the field is below the fold */
    if (this.customerHasGap) {
      this._navErrorRaised = true;
      this.scrollToCustomerGap();
      return;
    }
    this._navErrorRaised = false;
    const target = this.nextKeyAfter(this.currentSectionKey);
    /* 1.x+11: facade style and pre-approval number, before the EOI gates as the Sales App does */
    if (!this.bookingExtrasPass(this.currentSectionKey, target)) {
      return;
    }
    if (!(await this.eoiGatePasses(this.currentSectionKey, target))) {
      return;
    }
    this.openSection(target);
  }

  /**
   * 1.x+6 - MODON's EOI gates, at the point the Sales App runs them: leaving unit selection
   * (its Book Unit/s). The rule is the server's (checkEoiGate), the same one beginPayment and
   * reviewAndConfirm apply, so this is where the rep hears it first, not the only place it is
   * enforced. EOIs belong to the opportunity, so a new booking - no opportunity until the
   * customer is chosen - is asked on leaving the customer step instead. Forward moves only.
   * A failed call lets the rep on: the money and the confirm still refuse.
   */
  async eoiGatePasses(fromKey, toKey) {
    if (this.bookingIsCommitted || !this.opportunityId || !this.hasUnit) {
      return true;
    }
    if (fromKey !== "unit" && fromKey !== "details") {
      return true;
    }
    const target = GROUP_OF[toKey] || toKey;
    if (NEXT_ORDER.indexOf(target) <= NEXT_ORDER.indexOf(fromKey)) {
      return true;
    }
    if (this._eoiGateBusy) {
      return false;
    }
    this._eoiGateBusy = true;
    try {
      const r = await checkEoiGate({
        opportunityId: this.opportunityId,
        unitIds: this.selectedUnitIds || [],
        eoiMappingJson: null
      });
      if (r && r.ok === false) {
        this.errorMsg = r.message;
        return false;
      }
      return true;
    } catch (e) {
      return true;
    } finally {
      this._eoiGateBusy = false;
    }
  }
  _eoiGateBusy = false;

  /* the running total on a phone: the action bar gets its own row, tappable to open the summary */

  /** Rendered while mounted; `summaryOpen` drives the animation. */
  summarySheetMounted = false;
  summaryOpen = false;

  /** Only once there is something in it. */
  get showBarSummary() {
    return this.isPhone && !!this.barContext;
  }

  openSummarySheet() {
    this.summarySheetMounted = true;
    this.summaryOpen = true;
  }

  /** modonSheet asks rather than closes, so the exit animation can play. */
  requestSummaryClose() {
    this.summaryOpen = false;
  }

  handleSummarySheetClosed() {
    this.summarySheetMounted = false;
  }

  /** Every summary row is a jump button, so the sheet doubles as navigation. */
  handleSummaryJump(event) {
    this.requestSummaryClose();
    this.handleJump(event);
  }

  /** Back. Does not skip completed steps. */
  /**
   * And it stops at Payment & Confirm once the booking is made: a floor rather than hiding
   * Back, so settle <-> verify still works. Keyed on bookingIsCommitted.
   */
  /**
   * MSC-104: the floor is named once (the earliest step still open) and Back, the tape and
   * handleJump all read it. Null while nothing is written.
   */
  get navFloorKey() {
    /* MSC-153: the second reason, read from hasCollected (the same fact that hides Release
       unit). A hold is not money: the terminal collects nothing, so the floor stays reversible. */
    return this.bookingIsCommitted || this.hasCollected ? "settle" : null;
  }

  /** MSC-153: why the floor is where it is, for the tape. Committed wins when both are true. */
  get navFloorReason() {
    if (this.bookingIsCommitted) {
      return LABELS.NAV_FLOOR_COMMITTED;
    }
    return this.hasCollected ? LABELS.NAV_FLOOR_COLLECTED : null;
  }

  /**
   * Below the floor = earlier in NEXT_ORDER. Section keys resolve to their step through GROUP_OF;
   * an unknown key is openSection's to handle.
   */
  isBelowNavFloor(key) {
    const floorKey = this.navFloorKey;
    if (!key || !floorKey) {
      return false;
    }
    const i = NEXT_ORDER.indexOf(GROUP_OF[key] || key);
    const floor = NEXT_ORDER.indexOf(floorKey);
    return i > -1 && floor > -1 && i < floor;
  }

  get previousKey() {
    const i = NEXT_ORDER.indexOf(this.currentSectionKey);
    if (i <= 0) {
      return null;
    }
    /* MSC-104: the same floor from the one getter */
    const floor = this.navFloorKey ? NEXT_ORDER.indexOf(this.navFloorKey) : 0;
    return i - 1 >= floor ? NEXT_ORDER[i - 1] : null;
  }

  get showBack() {
    return !!this.previousKey;
  }

  get backLabel() {
    const group = GROUPS.find((g) => g.key === this.previousKey);
    return group ? group.label : "Back";
  }

  handleBarBack() {
    this.openSection(this.previousKey);
  }

  // section 1: unit

  async handleProjectChange(event) {
    await this.selectProject(event.detail.value);
  }

  /** One payload -> the whole unit screen, applied in one tick. */
  applyUnitBrowser(b) {
    if (!b) return;
    this.projects = b.projects || [];
    this.phases = b.phases || [];
    this.selectedProjectId = b.selectedProjectId || undefined;
    this.selectedPhaseId = b.selectedPhaseId || undefined;
    this.units = this.salesAppUnitPrices(b.units);
  }

  /* 1.x+15 - in "Wadeem" a UAE national sees UAE_Citizen_Price__c where set, as in the Sales App */
  salesAppUnitPrices(data) {
    const list = (data && data.units) || [];
    if (!(data && data.isResidentCustomer === true) || this.selectedProjectName !== "Wadeem") {
      return list;
    }
    return list.map((u) =>
      u && u.UAE_Citizen_Price__c != null ? { ...u, TotalPrice__c: u.UAE_Citizen_Price__c } : u
    );
  }

  async selectProject(projectId) {
    this.selectedProjectId = projectId;
    this.selectedPhaseId = undefined;
    this.units = [];
    this.phases = [];
    if (!this.selectedProjectId) return;
    this.busyUnits = true;
    try {
      /* one call; getUnitBrowser resolves the phase server-side */
      this.applyUnitBrowser(await getUnitBrowser({
        opportunityId: this.opportunityId || null,
        projectId: this.selectedProjectId,
        phaseId: null
      }));
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyUnits = false;
    }
  }

  /* auto-select */
  /** Put units on the screen without making the rep work: first project, first phase. Silent. */
  /** The project being booked in, for the customer picker (ProjectInterest__c is required on a Lead). */
  get selectedProjectName() {
    const p = (this.projects || []).find(
      (x) => x && x.value === this.selectedProjectId
    );
    return p ? p.label : undefined;
  }

  /* autoSelectFirst deleted; getUnitBrowser resolves all three server-side */

  async handlePhaseChange(event) {
    await this.selectPhase(event.detail.value);
  }

  async selectPhase(phaseId) {
    this.selectedPhaseId = phaseId;
    if (!this.selectedPhaseId) {
      this.units = [];
      return;
    }
    this.busyUnits = true;
    try {
      const res = await searchUnits({
        phaseId: this.selectedPhaseId,
        opportunityId: this.opportunityId,
        unitType: null,
        qualityType: null,
        bedrooms: null,
        gfaRange: null,
        floor: null,
        unitNumber: null
      });
      this.units = this.salesAppUnitPrices(res);
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyUnits = false;
    }
  }

  /* multi-unit */
  /** Toggles a unit in or out. Plans are per unit and cached. */
  async handleUnitSelect(event) {
    const { unitId, selected } = event.detail;
    if (!unitId) return;
    /* once the Sales Order exists the booking is a record: refuse edits */
    if (this.bookingIsCommitted) return;

    if (selected === false) {
      this.selectedUnitIds = this.selectedUnitIds.filter((id) => id !== unitId);
      // the cached plan stays
      if (this.selectedUnitIds.length !== 1) this.selectedPlanId = undefined;
      await this.afterSelectionChange();
      return;
    }

    if (!this.selectedUnitIds.includes(unitId)) {
      this.selectedUnitIds = [...this.selectedUnitIds, unitId];
    }

    this.busyUnitConfig = true;
    try {
      if (!this.unitPlans[unitId]) {
        const cfg = await getUnitConfiguration({
          unitId,
          opportunityId: this.opportunityId
        });
        const unit = (this.units || []).find((u) => u.Id === unitId);
        const plans = this.extractPlans(cfg);
        this.unitPlans = {
          ...this.unitPlans,
          [unitId]: {
            unitId,
            name: unit ? unit.Name : unitId,
            /* cached: the basket's offer needs it and summary.unit does not exist for a basket */
            projectName:
              (cfg && cfg.unit && cfg.unit.project) ||
              (unit && unit.Project_Name__c) ||
              null,
            plans,
            /* 1.x+11 - facade style and the typed pre-approval number, per unit */
            ...this.bookingExtrasFrom(cfg),
            /* 1.x+16 - the Sales App's first plan, chosen for the rep */
            planId: this.defaultPlanId(cfg, plans),
            // searchUnits does not select Masterplan_URL__c; cached from the configuration
            tourUrl: (cfg && cfg.unit && cfg.unit.tourUrl) || null
            /* paymentRequired is not cached here: it depends on the opportunity (loadFees asks) */
          }
        };
      }
      await this.afterSelectionChange();
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyUnitConfig = false;
    }
  }

  /** Keeps the single-unit surface in step with the selection; not populated for a basket. */
  /* ── MSC-231: booking against the EOI ────────────────────────────────────
   * Eligibility is the org engine's answer (getBookingEois wraps its
   * getCompletedEOIs and prices the deposits by the engine's own receipt rules).
   * 1.x+16: a unit that exactly one EOI fits gets it; otherwise the rep picks it on
   * the plan card (the Sales App's page 2), one EOI per unit. Deposits surface on
   * the Settle step, with Change (a swap sheet) where there is a real choice. The
   * mapping rides into beginPayment and reviewAndConfirm, where the server
   * re-validates it against the engine. */

  /** The EOI a Book unit door carried in; wins the first assignment and sets the filters. */
  @api eoiId;

  /** Guarded by _eoiLoadKey, so this is a string compare on every render and a fetch
   *  only when the opportunity or phase actually changed. */
  renderedCallback() {
    this.ensureBookingEois();
  }
  bookingEois = [];
  eoiMeta = null;
  eoiAssignments = {}; // unitId -> eoiId
  eoiSwapUnitId = null; // the unit whose deposit the swap sheet is changing
  _eoiLoadKey = "";
  _eoiFetching = false;

  /** Guarded, cheap re-entry: one fetch per (opportunity, phase) pair. */
  async ensureBookingEois() {
    const opp = this.opportunityId;
    if (!opp) {
      return;
    }
    const key = opp + ":" + (this.selectedPhaseId || "");
    if (key === this._eoiLoadKey || this._eoiFetching) {
      return;
    }
    this._eoiFetching = true;
    try {
      const r = await getBookingEois({ opportunityId: opp, phaseId: this.selectedPhaseId || null });
      this._eoiLoadKey = key;
      this.bookingEois = (r && r.eois) || [];
      this.eoiMeta = r || null;
      this.reassignEois();
      /* 1.x+12 - an EOI with a pre-approval number chooses its plan */
      this.applyPreApprovalDefaultsAndRefresh();
    } catch (e) {
      /* the journey and the engine stay the authority; nothing here may block booking */
      this._eoiLoadKey = key;
      this.bookingEois = [];
      this.eoiMeta = null;
    } finally {
      this._eoiFetching = false;
    }
  }

  /** Deterministic auto-assignment; keeps valid picks (the rep's swaps included). */
  reassignEois() {
    if (this.bookingIsCommitted) {
      return;
    }
    /* 1.x+13 - only units whose phase requires an EOI, as the Sales App offers one only there */
    const units = (this.selectedUnitIds || []).filter(
      (u) => this.unitPlans[u] && this.unitPlans[u].eoiRequired === true
    );
    const byId = {};
    this.bookingEois.forEach((e) => {
      byId[e.eoiId] = e;
    });
    const next = {};
    const used = new Set();
    /* 1. keep what still holds: a selected unit with a still-eligible, unduplicated EOI */
    units.forEach((u) => {
      const kept = this.eoiAssignments[u];
      if (kept && byId[kept] && !used.has(kept)) {
        next[u] = kept;
        used.add(kept);
      }
    });
    /* 2. the door's EOI (the rep chose it on the EOI page) takes the first open unit it fits */
    if (this.eoiId && byId[this.eoiId] && !used.has(this.eoiId)) {
      const open = units.find((u) => !next[u] && this.eoiCandidatesFor(u).some((e) => e.eoiId === this.eoiId));
      if (open) {
        next[open] = this.eoiId;
        used.add(this.eoiId);
      }
    }
    /* 3. 1.x+16 - chosen only where exactly one EOI fits; with more the rep picks on the plan card */
    units.forEach((u) => {
      if (next[u]) {
        return;
      }
      const fits = this.eoiCandidatesFor(u);
      if (fits.length === 1 && !used.has(fits[0].eoiId)) {
        next[u] = fits[0].eoiId;
        used.add(fits[0].eoiId);
      }
    });
    this.eoiAssignments = next;
  }

  /**
   * 1.x+16 - The EOIs that fit one unit: every eligible EOI, or, while MODON's match is on
   * (EOI_Enforce_Typology_Check), those with the unit's bedrooms.
   */
  eoiCandidatesFor(unitId) {
    const all = this.bookingEois || [];
    if (!(this.eoiMeta && this.eoiMeta.enforceTypology)) {
      return all;
    }
    /* the grid's row, else the unit's own configuration (a held or resumed unit is not in the grid) */
    const unit = (this.units || []).find((x) => x.Id === unitId);
    const entry = this.unitPlans[unitId] || {};
    const beds = unit ? unit.Number_of_Bedrooms__c : entry.unitBedrooms;
    const uBeds = beds == null ? "" : String(beds);
    return all.filter((e) => sameBedrooms(e.bedrooms, uBeds));
  }

  /** 1.x+16 - One EOI for one unit. Taking it from another unit leaves that unit to choose again. */
  assignEoi(unitId, eoiId) {
    if (!unitId || this.bookingIsCommitted) {
      return;
    }
    const next = { ...this.eoiAssignments };
    Object.keys(next).forEach((u) => {
      if (next[u] === eoiId && u !== unitId) {
        delete next[u];
      }
    });
    if (eoiId) {
      next[unitId] = eoiId;
    } else {
      delete next[unitId];
    }
    this.eoiAssignments = next;
    /* 1.x+12 - the rep's own choice is a new EOI for this unit, even on a resumed booking */
    const entry = this.unitPlans[unitId];
    if (entry && entry.keepPlan) {
      this.unitPlans = { ...this.unitPlans, [unitId]: { ...entry, keepPlan: false } };
    }
    this.applyPreApprovalDefaultsAndRefresh();
    /* on the Settle step the fee answer follows the EOI (EOI_SKIPS_BOOKING_FEE) */
    if (this.openGroup === "settle" && !this.isMultiUnit) {
      this.loadFees();
    }
  }

  /** 1.x+16 - the plan card's EOI list */
  handleEoiPick(event) {
    this.assignEoi(event.currentTarget.dataset.unitId, event.target.value || "");
    this.errorMsg = undefined;
  }

  /** The filter preset the unit grid applies through its own Filters control: the door
   *  EOI's preference; without a door, a preference every eligible EOI agrees on. The
   *  management bypass on the opportunity means no preset at all. */
  get eoiFilterPreset() {
    if (!this.bookingEois.length || (this.eoiMeta && this.eoiMeta.bypassTypology)) {
      return null;
    }
    let src = this.eoiId ? this.bookingEois.find((e) => e.eoiId === this.eoiId) : null;
    if (!src) {
      const typs = new Set(this.bookingEois.map((e) => e.unitTypology || ""));
      const beds = new Set(this.bookingEois.map((e) => String(e.bedrooms || "")));
      if (typs.size !== 1 || beds.size !== 1) {
        return null; // mixed preferences: never guess
      }
      src = this.bookingEois[0];
    }
    if (!src || (!src.unitTypology && !src.bedrooms)) {
      return null;
    }
    return {
      typology: src.unitTypology || "",
      bedrooms: src.bedrooms == null ? "" : String(src.bedrooms),
      source: src.name || ""
    };
  }

  /** Formerly an early banner that the engine would refuse this phase; see 1.x+6. */
  get eoiGateMsg() {
    /* 1.x+6: retired. The Sales App keeps this silent and says it only when the rep tries to
       book ("so they are not confused by a message before selecting any unit"); the decision
       was the same behaviour in both, so eoiGatePasses says it, at that moment. */
    return null;
  }

  /** The Settle step's deposit rows. Before Confirm: this journey's own assignment,
   *  applying on confirm. After: the receipts the engine actually linked. */
  get eoiDepositRows() {
    if (this.bookingIsCommitted) {
      const applied = (this.settlement && this.settlement.eoiDeposits) || [];
      return applied.map((d, i) => ({
        key: "applied-" + i,
        label: "EOI deposit · " + d.eoiName,
        sub: d.unitName || "",
        figure: formatAED(d.amount || 0),
        chipLabel: "Applied",
        chipClass: "chip chip--paid",
        canChange: false
      }));
    }
    const units = this.selectedUnitIds || [];
    const byId = {};
    this.bookingEois.forEach((e) => {
      byId[e.eoiId] = e;
    });
    const rows = [];
    units.forEach((u) => {
      const eoi = byId[this.eoiAssignments[u]];
      if (!eoi) {
        /* 1.x+16 - an EOI phase unit with fitting EOIs and none chosen: shown here with Change */
        const entry = this.unitPlans[u];
        if (entry && entry.eoiRequired === true && this.eoiCandidatesFor(u).length > 0) {
          rows.push({
            key: u,
            unitId: u,
            label: "EOI deposit",
            sub: entry.name || "",
            figure: "",
            chipLabel: LABELS.BOOK_EOI_NONE,
            chipClass: "chip chip--due",
            canChange: true
          });
        }
        return;
      }
      const unit = (this.units || []).find((x) => x.Id === u);
      rows.push({
        key: u,
        unitId: u,
        label: "EOI deposit · " + eoi.name,
        sub: (unit && unit.Name) || (this.unitPlans[u] && this.unitPlans[u].name) || "",
        figure: eoi.amount ? formatAED(eoi.amount) : "",
        chipLabel: "On confirm",
        chipClass: "chip chip--pending",
        /* 1.x+16 - only where the rep has a choice */
        canChange: this.eoiCandidatesFor(u).length > 1
      });
    });
    return rows;
  }

  /** JSON for the server, or undefined when nothing is assigned. */
  get eoiMappingJson() {
    const m = {};
    (this.selectedUnitIds || []).forEach((u) => {
      if (this.eoiAssignments[u]) {
        m[u] = this.eoiAssignments[u];
      }
    });
    return Object.keys(m).length ? JSON.stringify(m) : undefined;
  }

  /* the swap sheet: one small list, one tap swaps */
  handleDepositChange(event) {
    this.eoiSwapUnitId = event.detail && event.detail.unitId ? event.detail.unitId : null;
  }
  closeEoiSwap() {
    this.eoiSwapUnitId = null;
  }
  get eoiSwapOpen() {
    return !!this.eoiSwapUnitId;
  }
  get eoiSwapUnitName() {
    const u = (this.units || []).find((x) => x.Id === this.eoiSwapUnitId);
    const entry = this.unitPlans[this.eoiSwapUnitId];
    return (u && u.Name) || (entry && entry.name) || "";
  }
  get eoiSwapRows() {
    const unitId = this.eoiSwapUnitId;
    if (!unitId) {
      return [];
    }
    const holder = {};
    Object.keys(this.eoiAssignments).forEach((u) => {
      holder[this.eoiAssignments[u]] = u;
    });
    /* 1.x+16 - only the EOIs that fit this unit */
    return this.eoiCandidatesFor(unitId).map((e) => {
      const onThis = this.eoiAssignments[unitId] === e.eoiId;
      const elsewhere = !onThis && holder[e.eoiId];
      const otherUnit = elsewhere ? (this.units || []).find((x) => x.Id === holder[e.eoiId]) : null;
      return {
        id: e.eoiId,
        name: e.name,
        figure: e.amount ? formatAED(e.amount) : "",
        chipLabel: onThis ? "Applied here" : elsewhere ? "On " + ((otherUnit && otherUnit.Name) || (this.unitPlans[holder[e.eoiId]] || {}).name || "another unit") : e.hasReceipt ? "Deposit ready" : "No deposit",
        chipClass: onThis ? "chip chip--paid" : "chip",
        cls: onThis ? "eoiswap__row eoiswap__row--on" : "eoiswap__row"
      };
    });
  }
  handleEoiSwapPick(event) {
    const eoiId = event.currentTarget?.dataset?.id;
    const unitId = this.eoiSwapUnitId;
    if (!eoiId || !unitId) {
      return;
    }
    this.eoiSwapUnitId = null;
    /* one EOI, one unit (1.x+16: assignEoi, shared with the plan card's list) */
    this.assignEoi(unitId, eoiId);
  }

  /**
   * A booking is resumed from the opportunity, and the opportunity carries the unit, so the
   * load above ticks that unit in the grid. It used to stop there: `unitPlans` held nothing for
   * it, so the plan panel showed "Select a payment plan" with no plans under it, and because the
   * unit was already ticked, clicking it removed it rather than loading them. Fetch the unit's
   * configuration here, exactly as handleUnitSelect does for a unit the rep clicks.
   */
  async restoreSingleUnitPlans() {
    if (this.isMultiUnit || this.bookingIsCommitted) {
      return;
    }
    const ids = this.selectedUnitIds || [];
    const unitId = ids.length === 1 ? ids[0] : null;
    if (!unitId || this.unitPlans[unitId]) {
      return;
    }
    const su = (this.summary && this.summary.unit) || {};
    try {
      const cfg = await getUnitConfiguration({
        unitId,
        opportunityId: this.opportunityId
      });
      const unit = (this.units || []).find((u) => u.Id === unitId);
      const plans = this.extractPlans(cfg);
      const entry = {
        unitId,
        name: (unit && unit.Name) || su.name || unitId,
        projectName:
          (cfg && cfg.unit && cfg.unit.project) ||
          (unit && unit.Project_Name__c) ||
          su.project ||
          null,
        plans,
        /* 1.x+11 - facade style and the typed pre-approval number, per unit */
        ...this.bookingExtrasFrom(cfg),
        /* a plan already chosen on the booking stays chosen; 1.x+16 - else the Sales App's first */
        planId: this.selectedPlanId || this.defaultPlanId(cfg, plans),
        /* 1.x+12 - and the EOI's pre-approval default does not replace it */
        keepPlan: !!this.selectedPlanId,
        tourUrl: (cfg && cfg.unit && cfg.unit.tourUrl) || su.tourUrl || null
      };
      this.unitPlans = { ...this.unitPlans, [unitId]: entry };
      this.plans = entry.plans;
      /* 1.x+16 - the entry says whether the unit takes an EOI; assign now it is known */
      this.reassignEois();
      /* 1.x+16 - with no saved plan, the Sales App's first becomes the unit's plan */
      if (!this.selectedPlanId && entry.planId) {
        this.selectedPlanId = entry.planId;
        this.applyPreApprovalDefaults();
        this.refreshSummary();
      } else {
        this.applyPreApprovalDefaultsAndRefresh();
      }
    } catch (e) {
      /* the booking is still workable without the plan list, so this reports and does not throw */
      this.errorMsg = reduceError(e);
    }
  }

  async afterSelectionChange() {
    this.reassignEois();
    /* 1.x+12 - before the cached plan is read; the summary below follows it */
    this.applyPreApprovalDefaults();
    if (this.isSingleUnit) {
      const only = this.selectedUnitIds[0];
      const cached = this.unitPlans[only];
      this.plans = cached ? cached.plans : [];
      this.selectedPlanId = cached ? cached.planId : undefined;
      await this.refreshSummary();
      return;
    }
    this.plans = [];
    this.planRows = [];
    /* a basket keeps the customer block and loses only the per-unit ones (`= undefined` blanked
       the page) */
    this.summary =
      this.isMultiUnit && this.summary
        ? { ...this.summary, unit: undefined, plan: undefined, fees: undefined, totalPrice: undefined }
        : this.summary;
    /* 1.x+5 - and the money state goes the same way. The buckets were raised against ONE unit,
       and feeBlockers turns an unpaid blocking bucket into "… has not been received yet", which
       disables Confirm. A basket takes no booking fee, so those rows are not merely stale, they
       are about a route this booking is no longer on. Cleared here so the blockers disappear with
       them, then re-read for the basket. Not on a committed booking: there the buckets are the
       real obligations of real Sales Orders. */
    if (!this.bookingIsCommitted) {
      this.buckets = [];
      this.loadBuckets();
      this.loadSettlement();
    }
  }

  /** Plan pickers for the basket, one per selected unit. */
  get unitPlanRows() {
    return this.selectedUnitIds
      .map((id) => this.unitPlans[id])
      .filter(Boolean)
      .map((entry) => ({
        ...entry,
        key: entry.unitId,
        /* the template reads p.planId / p.planName; a plan record carries Id and Name */
        options: (entry.plans || []).map((p) => {
          const planId = p.Id || p.id;
          return {
            planId,
            planName: p.Name || p.name || planId,
            selected: planId === entry.planId
          };
        })
      }));
  }

  get allUnitsHavePlan() {
    return (
      this.selectedUnitIds.length > 0 &&
      this.selectedUnitIds.every((id) => this.unitPlans[id] && this.unitPlans[id].planId)
    );
  }

  handleUnitPlanChange(event) {
    const unitId = event.currentTarget.dataset.unitId;
    const planId = event.detail ? event.detail.planId : event.target.value;
    const entry = this.unitPlans[unitId];
    if (!entry) return;
    this.unitPlans = { ...this.unitPlans, [unitId]: { ...entry, planId } };
  }

  /**
   * 1.x+16 - The plan the Sales App starts a unit on (generateSalesOffer's selectedPayment), else the
   * first plan. Undefined with no plans.
   */
  defaultPlanId(cfg, plans) {
    const ids = (plans || []).map((p) => p.Id || p.id).filter(Boolean);
    const detail = cfg && cfg.offer && cfg.offer.unitPaymentDetailObj;
    const preset = detail && detail.selectedPayment;
    if (preset && ids.includes(preset)) {
      return preset;
    }
    return ids.length ? ids[0] : undefined;
  }

  /** generateSalesOffer returns a deep wrapper; the plans live under unitPaymentDetailObj.paymentLst. */
  extractPlans(cfg) {
    const offer = cfg && cfg.offer;
    const detail = offer && offer.unitPaymentDetailObj;
    const list = (detail && (detail.paymentLst || detail.paymentPlanList)) || [];
    return list
      .map((row) => {
        /* `paymentObj` first: the wrapper is {paymentObj, paymentInstallment, isSelected} */
        const plan = row.paymentObj || row.paymentPlan || row.paymentPlanObj || row;
        if (!plan || !(plan.Id || plan.id)) {
          return null;
        }
        /* the installments arrive alongside the plan; the count is carried across */
        const installments =
          row.paymentInstallment ||
          (plan.Payment_Installments__r && plan.Payment_Installments__r.records) ||
          [];
        /* the installments are kept: the only schedule source for a multi-unit booking */
        return { ...plan, installments, milestoneCount: installments.length };
      })
      .filter(Boolean);
  }

  /* ── 1.x+11: facade style and pre-approval number ─────────────────────────
   * The Sales App (unitSearchLwc) asks for both on its booking page and saveSalesOrder
   * refuses without them (engine 17.0 facade, 19.0 pre-approval). Same rules, same words. */

  /** The unit configuration's facade fields, with a single option chosen for the rep. */
  bookingExtrasFrom(cfg) {
    const offer = (cfg && cfg.offer) || {};
    const options = (offer.facadeStyleOptions || [])
      .map((o) => ({ label: o.label || o.value, value: o.value || o.label }))
      .filter((o) => !!o.value);
    const required = offer.facadeStyleRequired === true;
    /* 1.x+15 - the server's unit options: the Sales App's list, the Wadeem rule, the preselection */
    const uo = (cfg && cfg.unitOptions) || {};
    const optionRows = Array.isArray(uo.rows) ? uo.rows.filter((o) => o && o.value) : [];
    const optionPrices = {};
    optionRows.forEach((o) => {
      /* only where the option prices the order; a Wadeem option carries none */
      if (o.price != null) {
        optionPrices[o.value] = o.price;
      }
    });
    const unitOptions = optionRows.map((o) => ({ label: o.label || o.value, value: o.value }));
    return {
      facadeRequired: required,
      facadeOptions: options,
      facadeStyle: required && options.length === 1 ? options[0].value : "",
      preApprovalNumber: "",
      optionRequired: uo.required === true && unitOptions.length > 0,
      unitOptions,
      optionPrices,
      unitOptionId: uo.defaultId || "",
      /* 1.x+20 - set when the unit has one option or a saved one; several start empty */
      optionPreset: !!uo.defaultId,
      /* 1.x+13 - the Sales App offers an EOI only on a phase that requires one */
      eoiRequired: !!cfg && cfg.eoiRequired === true,
      /* 1.x+16 - the unit's bedrooms, for the EOIs that fit it when it is not in the grid */
      unitBedrooms: cfg && cfg.unit && cfg.unit.bedrooms != null ? String(cfg.unit.bedrooms) : null
    };
  }

  /** What one unit needs, from its entry, its plan and its EOI. */
  bookingExtrasFor(unitId) {
    const entry = unitId ? this.unitPlans[unitId] : null;
    if (!entry) {
      return null;
    }
    const planId = this.isMultiUnit ? entry.planId : this.selectedPlanId;
    const plan = (entry.plans || []).find((p) => (p.Id || p.id) === planId);
    const eoi = (this.bookingEois || []).find((e) => e.eoiId === this.eoiAssignments[unitId]);
    return {
      unitId,
      unitName: entry.name || "",
      planName: plan ? plan.Name || plan.name || "" : "",
      facadeRequired: entry.facadeRequired === true,
      facadeOptions: entry.facadeOptions || [],
      facadeStyle: entry.facadeStyle || "",
      preApprovalPlan: !!(plan && plan.Pre_Approval__c === true),
      eoiNumber: (eoi && eoi.preApprovalNumber) || "",
      typedNumber: entry.preApprovalNumber || "",
      /* 1.x+13 */
      optionRequired: entry.optionRequired === true,
      unitOptions: entry.unitOptions || [],
      unitOptionId: entry.unitOptionId || "",
      optionPreset: entry.optionPreset === true,
      unitOptionName: ((entry.unitOptions || []).find((o) => o.value === entry.unitOptionId) || {}).label || "",
      /* 1.x+16 - the EOIs that fit, where the unit's phase takes one; the rep's choice */
      eoiFits: entry.eoiRequired === true ? this.eoiCandidatesFor(unitId) : [],
      eoiId: this.eoiAssignments[unitId] || ""
    };
  }

  /** The unit the plan card is showing: the focused tab of a basket, else the one unit. */
  get planUnitId() {
    if (this.isMultiUnit) {
      return this.focusedUnitId;
    }
    const ids = this.selectedUnitIds || [];
    return ids.length === 1 ? ids[0] : null;
  }

  /** The plan card's view of that unit; null when it needs neither field. */
  get planUnitExtras() {
    const x = this.bookingExtrasFor(this.planUnitId);
    const eoiPicker = !!x && !this.bookingIsCommitted && x.eoiFits.length > 0;
    if (!x || (!x.facadeRequired && !x.preApprovalPlan && !x.optionRequired && !eoiPicker)) {
      return null;
    }
    /* 1.x+16 - an EOI held by another unit says so; choosing it moves it */
    const holder = {};
    Object.keys(this.eoiAssignments).forEach((u) => {
      holder[this.eoiAssignments[u]] = u;
    });
    const unitName = (id) => ((this.unitPlans[id] && this.unitPlans[id].name) || "");
    return {
      ...x,
      eoiPicker,
      eoiBlank: !x.eoiId,
      eoiRows: x.eoiFits.map((e) => {
        const other = holder[e.eoiId] && holder[e.eoiId] !== x.unitId ? unitName(holder[e.eoiId]) : "";
        return {
          value: e.eoiId,
          label: other ? `${e.name} · ${this.labels.BOOK_EOI_ON.replace("{0}", other)}` : e.name,
          selected: e.eoiId === x.eoiId
        };
      }),
      facadeNone: x.facadeRequired && x.facadeOptions.length === 0,
      facadeRows: x.facadeOptions.map((o) => ({ ...o, selected: o.value === x.facadeStyle })),
      showTyped: x.preApprovalPlan && !x.eoiNumber,
      optionRows: x.unitOptions.map((o) => ({ ...o, selected: o.value === x.unitOptionId })),
      /* an empty first entry unless an option is preselected */
      optionBlank: !x.optionPreset
    };
  }

  updateUnitExtra(unitId, patch) {
    const entry = unitId ? this.unitPlans[unitId] : null;
    if (!entry) {
      return;
    }
    this.unitPlans = { ...this.unitPlans, [unitId]: { ...entry, ...patch } };
  }

  handleFacadeChange(event) {
    this.updateUnitExtra(event.currentTarget.dataset.unitId, { facadeStyle: event.target.value || "" });
    this.errorMsg = undefined;
  }

  handlePreApprovalInput(event) {
    this.updateUnitExtra(event.currentTarget.dataset.unitId, {
      preApprovalNumber: (event.target.value || "").slice(0, 80)
    });
  }

  /** 1.x+13 - the option sets the order's price, so a single unit's summary is read again. */
  handleUnitOptionChange(event) {
    this.updateUnitExtra(event.currentTarget.dataset.unitId, { unitOptionId: event.target.value || "" });
    this.errorMsg = undefined;
    if (!this.isMultiUnit) {
      this.refreshSummary();
    }
  }

  /** 1.x+13 - what the Sales App's review page lists per unit before Confirm. Empty when nothing applies. */
  get reviewExtras() {
    if (this.bookingIsCommitted) {
      return [];
    }
    const rows = [];
    (this.selectedUnitIds || []).forEach((unitId) => {
      const x = this.bookingExtrasFor(unitId);
      if (!x) {
        return;
      }
      const prefix = this.isMultiUnit ? `${x.unitName} · ` : "";
      if (x.unitOptionName) {
        rows.push({ key: `${unitId}-opt`, label: prefix + LABELS.BOOK_OPTION, value: x.unitOptionName });
      }
      if (x.facadeStyle) {
        rows.push({ key: `${unitId}-fac`, label: prefix + LABELS.BOOK_FACADE, value: x.facadeStyle });
      }
      const number = x.eoiNumber || (x.preApprovalPlan ? x.typedNumber.trim() : "");
      if (number) {
        rows.push({ key: `${unitId}-pre`, label: prefix + LABELS.BOOK_PREAPPROVAL, value: number });
      }
    });
    return rows;
  }

  get hasReviewExtras() {
    return this.reviewExtras.length > 0;
  }

  /** The first thing a selected unit still lacks, in the Sales App's words; null when none. */
  bookingExtrasProblem() {
    for (const unitId of this.selectedUnitIds || []) {
      const x = this.bookingExtrasFor(unitId);
      if (!x) {
        continue;
      }
      /* 1.x+13 - the Sales App checks the unit option before the facade */
      if (x.optionRequired && !x.unitOptionId) {
        return this.labels.BOOK_OPTION_MISSING.replace("{0}", x.unitName);
      }
      if (x.facadeRequired && x.facadeOptions.length === 0) {
        return this.labels.BOOK_FACADE_NONE;
      }
      if (x.facadeRequired && !x.facadeStyle) {
        return this.labels.BOOK_FACADE_MISSING.replace("{0}", x.unitName);
      }
      if (x.preApprovalPlan && !x.eoiNumber && !x.typedNumber.trim()) {
        return this.labels.BOOK_PREAPPROVAL_MISSING.replace("{0}", x.planName).replace("{1}", x.unitName);
      }
    }
    /* 1.x+16 - then the EOI, last, as the Sales App; a unit no EOI fits is left to the EOI gate */
    for (const unitId of this.selectedUnitIds || []) {
      const x = this.bookingExtrasFor(unitId);
      if (x && x.eoiFits.length > 0 && !x.eoiId) {
        return this.labels.BOOK_EOI_MISSING.replace("{0}", x.unitName);
      }
    }
    return null;
  }

  /** Forward past Details only with both in place, where the Sales App checks (before page 3). */
  bookingExtrasPass(fromKey, toKey) {
    if (this.bookingIsCommitted || !this.hasUnit) {
      return true;
    }
    const from = NEXT_ORDER.indexOf(GROUP_OF[fromKey] || fromKey);
    const to = NEXT_ORDER.indexOf(GROUP_OF[toKey] || toKey);
    const details = NEXT_ORDER.indexOf("details");
    if (to <= details || from > details) {
      return true;
    }
    const problem = this.bookingExtrasProblem();
    if (problem) {
      this.errorMsg = problem;
      return false;
    }
    return true;
  }

  /** The two values for one unit, as saveSalesOrder expects them. */
  bookingExtrasPayload(unitId) {
    const x = this.bookingExtrasFor(unitId);
    if (!x) {
      return {};
    }
    const out = {};
    if (x.facadeStyle) {
      out.facadeStyle = x.facadeStyle;
    }
    /* 1.x+13 */
    if (x.unitOptionId) {
      out.unitOptionId = x.unitOptionId;
    }
    const number = x.eoiNumber || (x.preApprovalPlan ? x.typedNumber.trim() : "");
    if (number) {
      out.preApprovalNumber = number;
    }
    return out;
  }

  /* 1.x+12 - the Sales App's default (unitSearchLwc v19.0, applyPaymentPlanFilter with
   * forceDefault): when a unit's EOI carries a Pre-Approval Number and the unit's plan is not a
   * pre-approval plan, the first pre-approval plan is chosen. Once per unit and EOI, when the EOI
   * is assigned or the unit's plans arrive; the rep can still change the plan afterwards. */
  _preApprovalDefaultFor = {}; // unitId -> the eoiId the default was applied for

  /** Applies the default where it is due. True when the single unit's plan changed. */
  applyPreApprovalDefaults() {
    if (this.bookingIsCommitted) {
      return false;
    }
    const next = {};
    let singleChanged = false;
    let plans = this.unitPlans;
    (this.selectedUnitIds || []).forEach((unitId) => {
      const entry = plans[unitId];
      /* not recorded until the plans are here, so their arrival applies it */
      if (!entry || !(entry.plans || []).length) {
        return;
      }
      const eoiId = this.eoiAssignments[unitId] || "";
      next[unitId] = eoiId;
      if (this._preApprovalDefaultFor[unitId] === eoiId) {
        return;
      }
      /* a resumed booking's saved plan is the rep's earlier choice: kept through the first EOI */
      if (entry.keepPlan) {
        if (eoiId) {
          plans = { ...plans, [unitId]: { ...entry, keepPlan: false } };
        }
        return;
      }
      const eoi = (this.bookingEois || []).find((e) => e.eoiId === eoiId);
      if (!eoi || !eoi.preApprovalNumber) {
        return;
      }
      /* the entry mirrors the single unit's plan (handlePlanChange); selectedPlanId may still be
         the previous unit's while the selection changes */
      const currentId = this.isMultiUnit ? entry.planId : entry.planId || this.selectedPlanId;
      const current = entry.plans.find((p) => (p.Id || p.id) === currentId);
      if (current && current.Pre_Approval__c === true) {
        return;
      }
      const first = entry.plans.find((p) => p.Pre_Approval__c === true);
      if (!first) {
        return;
      }
      const planId = first.Id || first.id;
      plans = { ...plans, [unitId]: { ...entry, planId } };
      if (!this.isMultiUnit) {
        this.selectedPlanId = planId;
        singleChanged = true;
      }
    });
    this._preApprovalDefaultFor = next;
    if (plans !== this.unitPlans) {
      this.unitPlans = plans;
    }
    return singleChanged;
  }

  /** The same, followed by the single unit's schedule and figures when its plan moved. */
  applyPreApprovalDefaultsAndRefresh() {
    if (this.applyPreApprovalDefaults()) {
      this.refreshSummary();
    }
  }

  // section 2: customer

  handleCustomerDirty() {
    this.customerDirty = true;
  }

  async handleResidencyChange() {
    // recompute required documents; never delete what is uploaded
    if (this.salesOrderId) await this.loadDocs();
  }

  async handleCustomerSave(event) {
    this.busyCustomer = true;
    this.errorMsg = undefined;
    try {
      const input = { opportunityId: this.opportunityId, ...event.detail };
      const state = await saveCustomerInfo({ input });
      this.state = state || {};
      // same reason as reloadState: this used to drop the unit and the price
      await this.applyStateSummary();
      this.customerDirty = false;
      // residency is known, so the placeholders can be created
      await this.ensureDocSlots();
      if (this.salesOrderId) await this.loadDocs();
      this.toast(LABELS.TOAST_CUSTOMER_SAVED);
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyCustomer = false;
    }
  }

  /** The card's "Edit address": c/mscAddress is the one form that edits it. */
  /**
   * The address lives in Modon's own form now (see the note in the template where c/mscAddress
   * used to mount), so asking to edit it opens Update KYC on the buyer rather than hunting for a
   * block on the page. Falls back to scrolling the customer card when there is no subject yet.
   */
  handleEditAddress() {
    /* the buyer's Account: a person resolves to their PersonMailing address in Modon's form,
       a company to its Billing address and company fields - the same record the KYC subject
       resolution uses. */
    const subjectId = this.state ? this.state.accountId : null;
    if (subjectId) {
      this.kycModalSubjectId = subjectId;
      this.kycModalSubjectName = this.summaryCustomerName;
      this.kycModalOpen = true;
      return;
    }
    const card = this.template.querySelector('[data-anchor="customer"]');
    if (card && card.scrollIntoView) {
      card.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }

  // identity verification

  get compliance() {
    return this.state ? this.state.compliance : undefined;
  }

  /* the verification gate. Everything reads ComplianceStateDTO, filled by
   * SalesConsoleVerificationService; nothing re-derives the decision. */

  busyVerification = false;

  /* the dialog stays open after sending and closes on verified or released to branch */
  verifyDialogOpen = false;
  verifyCustomerName;
  verifyCanSend = false;
  verifyBlockedReason;
  /* declared: needsCustomer reads it, so it must be reactive */
  _holdCustomerPane = false;
  /* which journey this booking's customer arrived by; reaches the card as a prop */
  isNewCustomerJourney = false;

  get showVerifyDialog() {
    return this.verifyDialogOpen;
  }

  /** Every way out of the dialog. */
  closeVerifyDialog() {
    this.verifyDialogOpen = false;
    this._holdCustomerPane = false;
  }

  /** Both buttons in the choice phase land here. */
  async handleVerifyChoice(event) {
    if (!(event.detail || {}).send) {
      /* "Continue without sending" */
      this.closeVerifyDialog();
      return;
    }
    await this.sendVerificationLink();
    /* the dialog closes on send, whatever came back; sending is the rep's part */
    this.closeVerifyDialog();
    if (this.verificationStatus === "SENT" || this.verificationStatus === "SENDING") {
      this.kycLinkMsg = LABELS.KYC_LINK_SENT;
    }
  }

  /** Closes the dialog the moment the gate has nothing left to hold. */
  closeVerifyDialogIfDone() {
    if (this.verifyDialogOpen && !this.verificationBlocks) {
      this.closeVerifyDialog();
    }
  }

  get verificationStatus() {
    return (this.compliance || {}).verificationStatus;
  }

  /** The single source for "may the journey move on". */
  get verificationBlocks() {
    return (this.compliance || {}).blocksAdvance === true;
  }

  /** The strip renders only while it is holding something up. */
  get showVerifyGate() {
    return this.verificationBlocks && this.currentSectionKey === "details";
  }

  /** Sits on the disabled forward button. */
  get barBlockedReason() {
    if (this.verificationBlocks) {
      return LABELS.VERIFY_GATE_BLOCKED;
    }
    /* a customer is picked but residency is still blank: the one state with no sentence */
    if (
      this.currentSectionKey === "details" &&
      this.summary &&
      this.summary.customer &&
      !this.summary.customer.residentStatus
    ) {
      return LABELS.CUST_NEEDS_RESIDENCY;
    }
    return null;
  }

  /* validation on the press, not on the card: the forward button answers with what is left and
   * scrolls to it; the message is derived, not stored */
  _navErrorRaised = false;

  /** True when this step still owes something the rep can fix here. */
  get customerHasGap() {
    /* no org exemption any more */
    return (
      this.currentSectionKey === "details" &&
      this.hasCustomer &&
      !this.customerReady
    );
  }

  get customerGapMessage() {
    return this._navErrorRaised && this.customerHasGap
      ? this.eligibilityMessage || LABELS.CUSTOMER_INCOMPLETE
      : null;
  }

  get showCustomerGap() {
    return !!this.customerGapMessage;
  }

  /** Take them to the gap: mscAddress first, the customer card second, the anchor last. */
  scrollToCustomerGap() {
    const addr = this.template.querySelector("c-msc-address");
    if (addr && typeof addr.focusFirstGap === "function" && addr.focusFirstGap()) {
      return;
    }
    const info = this.template.querySelector("c-msc-customer-info");
    if (info && typeof info.focusFirstGap === "function" && info.focusFirstGap()) {
      return;
    }
    const card = this.template.querySelector('[data-anchor="customer"]');
    if (card && card.scrollIntoView) {
      card.scrollIntoView({ block: "start", behavior: "smooth" });
    }
  }

  /** The choice made in the popup. Sent from here because the send needs the unit. */
  async sendVerificationLink() {
    if (!this.opportunityId) {
      return;
    }
    this.busyVerification = true;
    this.errorMsg = undefined;
    try {
      const state = await sendCustomerVerification({
        opportunityId: this.opportunityId,
        primaryUnitId: this.primaryUnitId
      });
      this.applyComplianceState(state);
      this.startVerificationPoll();
    } catch (e) {
      /* the server's own sentence */
      this.errorMsg = reduceError(e);
    } finally {
      this.busyVerification = false;
    }
  }

  /** A basket sends one unit (KYCUnitName__pc is one Text field). */
  get primaryUnitId() {
    const ids = this.selectedUnitIds || [];
    return ids.length ? ids[0] : null;
  }

  /** The exit. */
  async handleVerifyInBranch() {
    if (!this.opportunityId) {
      return;
    }
    this.busyVerification = true;
    this.errorMsg = undefined;
    try {
      const state = await releaseVerificationToBranch({
        opportunityId: this.opportunityId
      });
      this.applyComplianceState(state);
      this.stopVerificationPoll();
      /* no banner: the dialog closing is the confirmation */
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyVerification = false;
    }
  }

  handleVerifyResend() {
    return this.sendVerificationLink();
  }

  handleVerifyRefresh() {
    return this.handleRefreshCompliance();
  }

  /** Replaces only the compliance block, never the whole state. */
  applyComplianceState(state) {
    if (!state || !this.state) {
      return;
    }
    this.state = { ...this.state, compliance: state };
    /* every route into the waiting phase leaves through here */
    this.closeVerifyDialogIfDone();
  }

  /* polling: the one place in this journey that polls. Stops when the gate lifts, when the tab
   * is hidden, and after twenty minutes. */
  _verifyPoll;
  _verifyPollStartedAt;
  _verifyVisibility;

  /* the settling window after Confirm: MODON's chain (receipt -> allocation -> invoice -> Sales
   * Order) runs behind Confirm, so the closing rows are re-read with backoff until they land */
  _settleWatch;
  _settleTicks = 0;
  /* 5s x 6 then 10s x 3 */
  SETTLE_STEPS = [5000, 5000, 5000, 5000, 5000, 5000, 10000, 10000, 10000];
  /** Drawn by c/mscObligations as "Finalising". */
  ledgerFinalising = false;

  startSettleWatch() {
    this.stopSettleWatch();
    this._settleTicks = 0;
    this.ledgerFinalising = true;
    this.scheduleSettleTick();
  }

  scheduleSettleTick() {
    const wait = this.SETTLE_STEPS[this._settleTicks];
    if (wait === undefined) {
      this.stopSettleWatch();
      /* R2-11: the last read of the page state, so a sale MODON closed in the meantime reads closed */
      this.reloadState().catch(() => {});
      return;
    }
    this._settleWatch = setTimeout(async () => {
      this._settleTicks += 1;
      /* not behind a hidden tab */
      if (typeof document !== "undefined" && document.hidden) {
        this.stopSettleWatch();
        return;
      }
      const wasClearing = this.settlementClearing;
      try {
        await Promise.all([this.loadBuckets(), this.loadSettlement()]);
        /* 1.x+12 - the sale just closed: the side summary's stage moved with it */
        if (wasClearing && !this.settlementClearing) {
          await this.reloadState();
        }
      } catch (e) {
        /* swallowed: a silent refresh the rep can repeat by hand */
      }
      if (this.settleWatchDone) {
        this.stopSettleWatch();
        return;
      }
      this.scheduleSettleTick();
    }, wait);
  }

  stopSettleWatch() {
    if (this._settleWatch) {
      clearTimeout(this._settleWatch);
      this._settleWatch = undefined;
    }
    this.ledgerFinalising = false;
  }

  /** Have the booking's records caught up? Any money recognised against a closing row. */
  /* MSC-177: a manual refresh for the payment summary. The automatic watch keys on closesSale,
   * which moves once fee lines exist, so on the Take payment route it never starts. A button
   * cannot go stale. Pure read: the same two calls the watch makes. */
  refreshingPayments = false;

  /* only once there is a payment summary to refresh */
  /* 18 Sep 2026 (seen in testing): not while the terminal wait is showing - c/mscReviewConfirm's
     "Check payment" is the one control there; two refresh icons side by side read as a mistake. */
  get showPaymentRefresh() {
    return this.hasBuckets && this.awaitingPayment !== true;
  }

  /* never while a payment is being recorded: loadBuckets replaces `buckets` wholesale */
  get paymentRefreshDisabled() {
    return this.refreshingPayments === true || this.busyPayment === true;
  }

  get paymentRefreshLabel() {
    return this.refreshingPayments ? LABELS.PAY_REFRESHING : LABELS.PAY_REFRESH;
  }

  get paymentRefreshClass() {
    return this.refreshingPayments
      ? "btn btn-ghost pay-refresh pay-refresh--busy"
      : "btn btn-ghost pay-refresh";
  }

  async handleRefreshPayments() {
    if (this.paymentRefreshDisabled) {
      return;
    }
    this.refreshingPayments = true;
    try {
      /* both together: rows from the buckets, headline from the settlement */
      await Promise.all([this.loadBuckets(), this.loadSettlement()]);
    } catch (e) {
      /* say so, and leave every figure alone */
      this.errorMsg = LABELS.PAY_REFRESH_FAILED;
    } finally {
      this.refreshingPayments = false;
    }
  }

  /* 1.x+12 - the money is in but the booking is not closed yet (the header's "Captured in full").
   * MODON's allocation job closes the sale seconds after Confirm, so the watch waits for it too. */
  get settlementClearing() {
    const s = this.settlement;
    return (
      !!s &&
      s.bookingConfirmed === true &&
      Number(s.totalRequired || 0) > 0 &&
      Number(s.totalRemaining || 0) <= 0 &&
      !(s.fullySettled === true && s.gateSatisfied === true)
    );
  }

  /** The watch's finish line: the rows have caught up and the booking is not mid-close. */
  get settleWatchDone() {
    return this.settledFiguresLanded && !this.settlementClearing;
  }

  get settledFiguresLanded() {
    /* R2-11: with a fee collected, the due-now rows (ADM + Dari and Milestone 1) wait for the
       fee's allocation too; until then they read "Finalising", not the full amount as pending */
    const rows = (this.ledgerRows || []).filter(
      (r) =>
        r &&
        (r.closesSale === true ||
          (this.hasCollected && this.bookingIsCommitted && !isScheduledMilestone(r)))
    );
    if (!rows.length) {
      return true;
    }
    return rows.some(
      (r) => Number(r.paidAmount || 0) > 0 || Number(r.withFinanceAmount || 0) > 0
    );
  }

  startVerificationPoll() {
    if (this._verifyPoll) {
      return;
    }
    this._verifyPollStartedAt = Date.now();
    this._verifyPoll = setInterval(() => this.verificationTick(), 20000);
    /* one early look: the send usually lands within seconds */
    setTimeout(() => {
      if (this._verifyPoll) this.verificationTick();
    }, 5000);
    this._verifyVisibility = () => {
      if (document.visibilityState === "hidden") {
        this.stopVerificationPoll();
      }
    };
    document.addEventListener("visibilitychange", this._verifyVisibility);
  }

  stopVerificationPoll() {
    if (this._verifyPoll) {
      clearInterval(this._verifyPoll);
      this._verifyPoll = undefined;
    }
    if (this._verifyVisibility) {
      document.removeEventListener("visibilitychange", this._verifyVisibility);
      this._verifyVisibility = undefined;
    }
  }

  async verificationTick() {
    /* the poll only turns "Sending" into "KYC link sent", for every party, in one loop */
    const owners = this.ownersSending;
    const sending = this.verificationStatus === "SENDING";
    if ((!this.verificationBlocks && !sending && !owners) || !this.opportunityId) {
      this.stopVerificationPoll();
      return;
    }
    if (Date.now() - this._verifyPollStartedAt > 20 * 60 * 1000) {
      this.stopVerificationPoll();
      return;
    }
    try {
      const state = await refreshComplianceState({ opportunityId: this.opportunityId });
      this.applyComplianceState(state);
      /* quiet, and only while somebody is sending */
      if (owners) {
        await this.loadOwners(true);
      }
      if (
        !this.verificationBlocks &&
        this.verificationStatus !== "SENDING" &&
        !this.ownersSending
      ) {
        this.stopVerificationPoll();
      }
    } catch (e) {
      /* an unreachable vendor must not kill the loop */
    }
  }

  /** Sends the Signzy link; the error string names the missing field. State reloaded either way. */
  async handleSendKycLink() {
    this.busyKycLink = true;
    this.errorMsg = undefined;
    this.kycLinkMsg = undefined;
    try {
      const problem = await sendKycLink({ opportunityId: this.opportunityId });
      if (problem) {
        this.errorMsg = problem;
      } else {
        this.kycLinkMsg = LABELS.KYC_LINK_SENT;
      }
      await this.reloadState();
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyKycLink = false;
    }
  }

  /** Pulls the latest compliance state; replaces only the compliance block. */
  /** MSC-088: both answers (compliance and owners), because Refresh sits on a list that draws from both. The owners read is quiet. */
  async handleRefreshCompliance() {
    this.busyComplianceRefresh = true;
    this.errorMsg = undefined;
    this.kycLinkMsg = undefined;
    try {
      const compliance = await refreshComplianceState({
        opportunityId: this.opportunityId
      });
      this.state = { ...this.state, compliance };
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyComplianceRefresh = false;
    }
    await this.loadOwners(true);
  }

  // MSC-069: the compliance check

  /** The Sales Order compliance attaches to: the focused one; the server picks the newest otherwise. */
  get complianceOrderId() {
    return this.focusedOrderId || this.salesOrderId || null;
  }

  /* which subject of a corporate booking the panel shows: 'COMPANY', 'Primary Contact', or undefined */
  complianceOrgEntity;

  /** The signatory track's door (MSC-116); the server decides whether it is offered (signatory.canCheck). */
  async handleCheckSignatory() {
    this.compliancePartyAccountId = undefined;
    this.complianceOrgEntity = "Primary Contact";
    this.orgDetailsOpen = false;
    this.complianceCheckOpen = true;
    this.complianceCheckError = undefined;
    this.busyComplianceCheck = true;
    this.complianceCheck = undefined;
    await this.loadComplianceCheck();
  }

  /* MSC-151: the one thing to do now. The server decided the state; this routes it to the
     existing handler. nextStep is null on an individual booking. */

  get verifyNextStep() {
    return (this.compliance || {}).nextStep || null;
  }

  /** Every write the bar can start. */
  get verifyNextBusy() {
    return !!(
      this.busyKycLink ||
      this.busyOrgSubmit ||
      this.busyComplianceCheck ||
      this.busyComplianceRefresh
    );
  }

  handleVerifyNextAction(event) {
    const action = (event.detail || {}).action;
    if (action === "opendetails") {
      return this.handleOpenOrgDetails();
    }
    if (action === "sendlink") {
      return this.handleSendKycLink();
    }
    if (action === "submit") {
      return this.handleSubmitOrgCompliance();
    }
    if (action === "check") {
      return this.handleCheckSignatory();
    }
    return undefined;
  }

  /* MSC-146/148: the company's details workspace. One overlay at a time: this and the
     compliance check are both fixed layers on z-index 70. */
  handleOpenOrgDetails() {
    this.complianceCheckOpen = false;
    this.orgDetailsOpen = true;
    this.orgDetailsError = undefined;
    return this.loadOrgDetails();
  }

  /** Reads what the company still owes; every gate is decided on the server. */
  async loadOrgDetails() {
    if (!this.opportunityId) {
      return;
    }
    this.busyOrgDetails = true;
    /* on the panel, never on the page: the page banner (z 20) is behind the scrim (z 70) */
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await getOrgDetails({ opportunityId: this.opportunityId });
    } catch (e) {
      this.orgDetailsError = reduceError(e);
      this.orgDetails = undefined;
    } finally {
      this.busyOrgDetails = false;
    }
  }

  /** Writes what the rep filled in; the reply is the recomputed picture. */
  async handleSaveOrgDetails(event) {
    const fields = (event.detail && event.detail.fields) || {};
    if (!Object.keys(fields).length) {
      return;
    }
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    let saved = false;
    try {
      this.orgDetails = await saveOrgDetails({
        opportunityId: this.opportunityId,
        fieldsJson: JSON.stringify(fields)
      });
      saved = true;
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
    /* 1.x+19 - the step behind the surface reads the saved details too */
    if (saved) {
      await this.handleRefreshCompliance();
    }
  }

  /** Assigns the company's Power of Attorney. Both pictures are re-read: the POA row arms the card's Send. */
  async handleAssignSignatory(event) {
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await assignOrgSignatory({
        opportunityId: this.opportunityId,
        contactId: (event.detail && event.detail.contactId) || null
      });
      this.busyOrgSave = false;
      await this.handleRefreshCompliance();
      return;
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
  }

  /** MSC-181: the lookup's New Contact, created and assigned in one transaction. Both pictures re-read. */
  async handleCreateSignatory(event) {
    const d = event.detail || {};
    this.busyOrgSave = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await createOrgSignatoryContact({
        opportunityId: this.opportunityId,
        fullName: d.name,
        nationality: d.nationality,
        residency: d.residency,
        email: d.email,
        mobile: d.mobile
      });
      this.busyOrgSave = false;
      await this.handleRefreshCompliance();
      return;
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSave = false;
    }
  }


  /** The licence upload; the extraction is queued, so the workspace is read again. */
  async handleUploadLicence(event) {
    const detail = event.detail || {};
    if (!detail.base64 || !detail.fileName) {
      return;
    }
    this.busyOrgUpload = true;
    this.orgDetailsError = undefined;
    try {
      this.orgDetails = await uploadCompanyLicence({
        opportunityId: this.opportunityId,
        base64: detail.base64,
        fileName: detail.fileName
      });
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgUpload = false;
    }
  }

  /** MSC-149: the verification link sent from inside the workspace; reports onto the panel, re-reads both pictures. */
  async handleSendLinkFromWorkspace() {
    this.busyOrgSendLink = true;
    this.orgDetailsError = undefined;
    try {
      const problem = await sendKycLink({ opportunityId: this.opportunityId });
      this.busyOrgSendLink = false;
      if (problem) {
        this.orgDetailsError = problem;
      } else {
        this.kycLinkMsg = LABELS.KYC_LINK_SENT;
      }
      await this.loadOrgDetails();
      await this.handleRefreshCompliance();
    } catch (e) {
      this.orgDetailsError = reduceError(e);
    } finally {
      this.busyOrgSendLink = false;
    }
  }

  /** A file the browser could not read never reaches the server. */
  handleLicenceUnreadable(event) {
    this.orgDetailsError =
      (event.detail && event.detail.message) || LABELS.ORG_LICENCE_UNREADABLE;
  }

  /** Sends the company to compliance; a refusal is shown on the panel and the picture re-read. */
  async handleSubmitOrgCompliance() {
    this.busyOrgSubmit = true;
    this.orgDetailsError = undefined;
    try {
      const problem = await submitOrganisationCompliance({
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId
      });
      this.busyOrgSubmit = false;
      if (problem) {
        this.reportOrgProblem(problem);
        if (this.orgDetailsOpen) {
          await this.loadOrgDetails();
          this.orgDetailsError = problem;
        }
        return;
      }
      this.orgDetailsOpen = false;
      this.orgDetails = undefined;
      /* both blocks: the company's track and the Ownership row */
      await this.handleRefreshCompliance();
      this.settleComplianceWarning();
      return;
    } catch (e) {
      const message = reduceError(e);
      if (this.orgDetailsOpen) {
        await this.loadOrgDetails();
        // loadOrgDetails clears it on the way in
        this.orgDetailsError = message;
      } else {
        this.reportOrgProblem(message);
      }
    } finally {
      this.busyOrgSubmit = false;
    }
  }

  /** MSC-151: a refusal lands where the rep is looking (the bar, when the workspace is shut). */
  reportOrgProblem(message) {
    if (this.orgDetailsOpen) {
      this.orgDetailsError = message;
    } else {
      this.errorMsg = message;
    }
  }

  handleOrgDetailsClose() {
    // mid-write the answer is still coming
    if (
      this.busyOrgSave ||
      this.busyOrgSubmit ||
      this.busyOrgUpload ||
      this.busyOrgSendLink
    ) {
      return;
    }
    this.orgDetailsOpen = false;
    this.orgDetails = undefined;
    this.orgDetailsError = undefined;
  }

  /** The company, off the compliance answer. */
  get orgDetailsCompanyName() {
    const co = (this.compliance || {}).company;
    return (co && co.name) || null;
  }

  /** Which Sales Order this booking is filed against, named as the rest of the page names it. */
  get orgDetailsBookingRef() {
    const id = this.complianceOrderId;
    if (!id) {
      return null;
    }
    const hit = (this.bookedUnits || []).find((b) => b && b.salesOrderId === id);
    return (hit && hit.bookingRef) || null;
  }

  handleOpenComplianceCheck() {
    // the buyer's own button
    this.compliancePartyAccountId = undefined;
    this.complianceOrgEntity = undefined;
    this.complianceCheckOpen = true;
    this.complianceCheckError = undefined;
    return this.loadComplianceCheck();
  }

  /**
   * MSC-083: the same panel opened on one named person from the Ownership row (the buyer's own
   * button is not offered once the buyer is submitted). Slots are ensured first and silently.
   */
  async handleCheckOwnerCompliance(event) {
    const accountId = (event.detail && event.detail.accountId) || null;
    if (!accountId) {
      return;
    }
    this.compliancePartyAccountId = this.isPrimaryOwnerAccount(accountId)
      ? undefined
      : accountId;
    this.complianceCheckOpen = true;
    this.complianceCheckError = undefined;
    /* busy before the first await, and the last person's checklist dropped */
    this.busyComplianceCheck = true;
    this.complianceCheck = undefined;
    await this.ensurePartySlots();
    await this.loadComplianceCheck();
  }

  /** Moving from one person to the next without closing; the panel holds the switch while anything is unsaved. */
  async handleSwitchComplianceParty(event) {
    const accountId = (event.detail && event.detail.accountId) || null;
    if (!accountId || this.busyComplianceSave || this.busyComplianceSubmit) {
      return;
    }
    /* on a corporate booking the tabs are the booking's subjects, not parties; the tab key
       names the entity */
    if (this.isOrganisationCustomer) {
      this.complianceOrgEntity =
        accountId === this.orgSignatoryTabId ? "Primary Contact" : "COMPANY";
      this.compliancePartyAccountId = undefined;
      this.complianceCheckError = undefined;
      this.busyComplianceCheck = true;
      this.complianceCheck = undefined;
      await this.loadComplianceCheck();
      return;
    }
    this.compliancePartyAccountId = this.isPrimaryOwnerAccount(accountId)
      ? undefined
      : accountId;
    this.complianceCheckError = undefined;
    /* set here, not in loadComplianceCheck, so two presses cannot race */
    this.busyComplianceCheck = true;
    this.complianceCheck = undefined;
    await this.ensurePartySlots();
    await this.loadComplianceCheck();
  }

  /** Silent by design. */
  async ensurePartySlots() {
    try {
      await ensurePartyDocSlots({
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId,
        partyAccountId: this.compliancePartyAccountId || null
      });
    } catch (e) {
      // deliberately swallowed
    }
  }

  /** Everybody this booking could send, for the party strip. Deduped by account. */
  /** The signatory's tab key: their Contact id. */
  get orgSignatoryTabId() {
    const sig = this.compliance && this.compliance.signatory;
    return sig ? `sig-${this.opportunityId}` : null;
  }

  get complianceParties() {
    /* a corporate booking's strip is its two subjects, from the compliance answer */
    if (this.isOrganisationCustomer) {
      const c = this.compliance || {};
      const out = [];
      if (c.company) {
        out.push({
          accountId: `co-${this.opportunityId}`,
          name: c.company.name,
          relationshipType: LABELS.VL_ORG_ROLE_COMPANY,
          isPrimary: true,
          complianceSubmitted: c.company.submitted === true
        });
      }
      if (c.signatory) {
        out.push({
          accountId: this.orgSignatoryTabId,
          name: c.signatory.name,
          relationshipType: LABELS.VL_ORG_ROLE_SIGNATORY,
          isPrimary: false,
          canCheckCompliance: c.signatory.canCheck === true,
          complianceSubmitted: c.signatory.submitted === true
        });
      }
      return out;
    }
    const parties = (this.owners && this.owners.parties) || [];
    const seen = new Set();
    const out = [];
    parties.forEach((p) => {
      if (!p.accountId || seen.has(p.accountId)) {
        return;
      }
      seen.add(p.accountId);
      out.push(p);
    });
    return out;
  }

  /** null for the buyer. */
  get complianceActiveAccountId() {
    if (this.isOrganisationCustomer) {
      return this.complianceOrgEntity === "COMPANY"
        ? `co-${this.opportunityId}`
        : this.orgSignatoryTabId;
    }
    if (this.compliancePartyAccountId) {
      return this.compliancePartyAccountId;
    }
    const primary = this.complianceParties.find((p) => p.isPrimary === true);
    return primary ? primary.accountId : undefined;
  }

  /** Reads what compliance still needs; every gate is decided on the server. */
  async loadComplianceCheck() {
    this.busyComplianceCheck = true;
    /* on the panel, never on the page */
    this.complianceCheckError = undefined;
    try {
      this.complianceCheck = await getComplianceChecklist({
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId,
        partyAccountId: this.compliancePartyAccountId || null,
        orgEntity: this.complianceOrgEntity || null
      });
    } catch (e) {
      this.complianceCheckError = reduceError(e);
      this.complianceCheck = undefined;
    } finally {
      this.busyComplianceCheck = false;
    }
  }

  /** Re-read without closing (documents arrive while the rep is here). */
  handleRefreshComplianceCheck() {
    if (this.busyComplianceSave || this.busyComplianceSubmit) {
      return;
    }
    return this.loadComplianceCheck();
  }

  handleCloseComplianceCheck() {
    // mid-save the answer is still coming
    if (this.busyComplianceSave || this.busyComplianceSubmit) {
      return;
    }
    this.complianceCheckOpen = false;
    this.compliancePartyAccountId = undefined;
    this.complianceCheck = undefined;
    this.complianceCheckError = undefined;
  }

  /** Writes what the rep filled in; the reply is the recomputed checklist. */
  async handleSaveComplianceDetails(event) {
    const fields = (event.detail && event.detail.fields) || {};
    if (!Object.keys(fields).length) {
      return;
    }
    this.busyComplianceSave = true;
    this.complianceCheckError = undefined;
    try {
      this.complianceCheck = await saveComplianceDetails({
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId,
        partyAccountId: this.compliancePartyAccountId || null,
        fieldsJson: JSON.stringify(fields),
        orgEntity: this.complianceOrgEntity || null
      });
    } catch (e) {
      this.complianceCheckError = reduceError(e);
    } finally {
      this.busyComplianceSave = false;
    }
  }

  /** Sends the customer to compliance; the checklist is re-read either way. */
  async handleSubmitCompliance() {
    this.busyComplianceSubmit = true;
    this.complianceCheckError = undefined;
    try {
      const res = await submitToCompliance({
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId,
        partyAccountId: this.compliancePartyAccountId || null,
        orgEntity: this.complianceOrgEntity || null
      });
      if (res && res.success === true) {
        this.complianceCheckOpen = false;
        this.compliancePartyAccountId = undefined;
        this.complianceOrgEntity = undefined;
        this.complianceCheck = undefined;
        this.busyComplianceSubmit = false;
        /* both blocks: the chain and the Ownership row */
        await this.handleRefreshCompliance();
        await this.loadOwners(true);
        this.settleComplianceWarning();
        return;
      }
      await this.loadComplianceCheck();
    } catch (e) {
      const message = reduceError(e);
      await this.loadComplianceCheck();
      // loadComplianceCheck clears it on the way in
      this.complianceCheckError = message;
    } finally {
      this.busyComplianceSubmit = false;
    }
  }

  // MSC-081: the joint owners

  /** Who owns this booking. Read on the Verification step and after every write. getOwners never throws. */
  /** B5: a joint owner's document upload on Verification - re-read the owners quietly. */
  handleOwnerDocumentsChanged() {
    this.loadOwners(true);
  }

  async loadOwners(quiet) {
    if (!this.opportunityId) {
      return;
    }
    /* a poll refresh passes quiet */
    if (!quiet) {
      this.busyOwners = true;
    }
    try {
      this.owners = this.withAwaitingBookingNote(
        await getOwners({
          opportunityId: this.opportunityId,
          salesOrderId: this.complianceOrderId
        })
      );
    } catch (e) {
      /* quiet reloads keep whatever we already had */
      if (!quiet) {
        this.owners = undefined;
      }
    } finally {
      this.busyOwners = false;
    }
  }

  /**
   * MSC-168: what the Verification step says before there is a Sales Order. The journey
   * supplies its own sentence for the no-order note only; any other note passes through.
   */
  withAwaitingBookingNote(state) {
    if (!state || state.available === true || this.bookingIsCommitted) {
      return state;
    }
    if (state.blockedReason !== NO_ORDER_NOTE) {
      return state;
    }
    /* a new object: an Apex result is read-only in LWC */
    return { ...state, blockedReason: this.awaitingBookingNote };
  }

  /** The claim has to match the state. */
  get awaitingBookingNote() {
    const name = this.summaryCustomerName;
    if (!name) {
      return LABELS.VERIFY_AWAIT_PLAIN;
    }
    if (this.complianceCleared || this.verificationStatus === "VERIFIED") {
      return LABELS.VERIFY_AWAIT_DONE.replace("{0}", name);
    }
    if (this.verificationStatus === "SENT") {
      return LABELS.VERIFY_AWAIT_SENT.replace("{0}", name);
    }
    return LABELS.VERIFY_AWAIT_PLAIN;
  }

  /* busyKycLink joins these: the buyer's send and the owners share one list */
  get ownersBusy() {
    return this.busyOwners || this.busyOwnersSave || this.busyKycLink;
  }

  get ownersUncovered() {
    return (this.owners && this.owners.unitsWithNoJointOwner) || [];
  }

  get ownersPrimaryName() {
    const parties = (this.owners && this.owners.parties) || [];
    const primary = parties.find((p) => p.isPrimary);
    return primary ? primary.name : "";
  }

  openOwnersDrawer(mode, opts) {
    this.ownersDrawerMode = mode;
    this.ownersEditAccountId = (opts && opts.accountId) || undefined;
    this.ownersPreselected = (opts && opts.orderIds) || undefined;
    this.ownersPerson = undefined;
    this.ownersSearchStatus = "idle";
    this.ownersError = undefined;
    this.ownersDrawerOpen = true;
  }

  handleAddOwner() {
    this.openOwnersDrawer("add");
  }

  handleEditOwner(event) {
    this.openOwnersDrawer("edit", { accountId: event.detail.accountId });
  }

  /** The coverage line's one-press correction. */
  handleAddToUncovered() {
    const empty = ((this.owners && this.owners.units) || [])
      .filter((u) => u.open && !u.ownerCount)
      .map((u) => u.salesOrderId);
    this.openOwnersDrawer("add", { orderIds: empty });
  }

  handleCloseOwnersDrawer() {
    // mid-save the answer is still coming
    if (this.busyOwnersSave) {
      return;
    }
    this.ownersDrawerOpen = false;
    this.ownersPerson = undefined;
    this.ownersSearchStatus = "idle";
    this.ownersError = undefined;
  }

  handleResetOwnerSearch() {
    this.ownersPerson = undefined;
    this.ownersSearchStatus = "idle";
    this.ownersError = undefined;
  }

  /** Identity first: the console has one identity matcher (SalesConsoleLeadController). */
  async handleFindOwnerPerson(event) {
    const idNumber = ((event.detail && event.detail.idNumber) || "").trim();
    if (!idNumber) {
      return;
    }
    this.ownersSearchStatus = "searching";
    this.ownersError = undefined;
    try {
      const found = await findJointOwnerPerson({
        opportunityId: this.opportunityId,
        idNumber
      });
      if (found && found.length) {
        this.ownersPerson = found[0];
        this.ownersSearchStatus = "found";
      } else {
        this.ownersPerson = undefined;
        this.ownersSearchStatus = "notfound";
      }
    } catch (e) {
      this.ownersError = reduceError(e);
      this.ownersSearchStatus = "idle";
    }
  }

  /* 1.x+9: the drawer created a person without adding them; show them as found */
  handleOwnerPersonFound(event) {
    this.ownersPerson = (event.detail || {}).person;
    this.ownersSearchStatus = this.ownersPerson ? "found" : "idle";
    this.ownersError = undefined;
  }

  /** The one write. Every rule runs again on the server; a refusal is reported on the drawer. */
  async handleSaveOwner(event) {
    const d = event.detail || {};
    this.busyOwnersSave = true;
    this.ownersError = undefined;
    try {
      const input = {
        opportunityId: this.opportunityId,
        salesOrderId: this.complianceOrderId,
        targetOrderIds: d.targetOrderIds,
        accountId: d.accountId,
        share: d.share,
        relationshipType: d.relationshipType,
        relationshipSubType: d.relationshipSubType
      };
      if (d.mode === "edit") {
        /* MSC-082: only the fields blank on the account today */
        this.owners = await updateJointOwner({
          input: {
            ...input,
            email: d.email,
            mobile: d.mobile,
            nationality: d.nationality,
            residentStatus: d.residentStatus
          }
        });
      } else {
        this.owners = await addJointOwner({
          input: {
            ...input,
            firstName: d.firstName,
            lastName: d.lastName,
            email: d.email,
            mobile: d.mobile,
            nationality: d.nationality,
            residentStatus: d.residentStatus,
            eidNumber: d.eidNumber,
            passportNumber: d.passportNumber,
            /* MSC-180: the company path's three; the flag only picks which create runs */
            isCompany: d.isCompany === true,
            companyName: d.companyName,
            tradeLicence: d.tradeLicence
          }
        });
      }
      this.ownersDrawerOpen = false;
      this.ownersPerson = undefined;
      this.ownersSearchStatus = "idle";
      /* a new person on the booking is a new person for compliance */
      await this.handleRefreshCompliance();
    } catch (e) {
      this.ownersError = reduceError(e);
    } finally {
      this.busyOwnersSave = false;
    }
  }

  // MSC-082: identity verification, per person

  /**
   * One button per row, two routes. The primary owner goes through handleSendKycLink (the same
   * call as the chain); a joint owner through the joint owner service, which stamps the unit.
   * Not sendCustomerVerification: that is step 2's. Both routes refresh both blocks.
   */
  async handleSendOwnerVerification(event) {
    const accountId = (event.detail || {}).accountId;
    if (!accountId || this.ownersSendingAccountId) {
      return;
    }
    this.ownersSendingAccountId = accountId;
    this.ownersError = undefined;
    this.errorMsg = undefined;
    try {
      if (this.isPrimaryOwnerAccount(accountId)) {
        /* reloads the whole state and reports its own refusal */
        await this.handleSendKycLink();
        await this.loadOwners(true);
      } else {
        this.owners = await sendOwnerVerification({
          opportunityId: this.opportunityId,
          salesOrderId: this.complianceOrderId,
          accountId
        });
        await this.handleRefreshCompliance();
        this.startVerificationPoll();
      }
    } catch (e) {
      /* the server's own sentence, on the page (no drawer is open) */
      this.errorMsg = reduceError(e);
    } finally {
      this.ownersSendingAccountId = undefined;
    }
  }

  /** The way to the missing details: the drawer for a joint owner, the Customer card for the buyer. */
  handleFixOwnerDetails(event) {
    const accountId = (event.detail || {}).accountId;
    if (!accountId) {
      return;
    }
    if (this.isPrimaryOwnerAccount(accountId)) {
      this.scrollToCustomerGap();
      return;
    }
    this.openOwnersDrawer("edit", { accountId });
  }

  isPrimaryOwnerAccount(accountId) {
    const parties = (this.owners && this.owners.parties) || [];
    const primary = parties.find((p) => p.isPrimary);
    return !!primary && primary.accountId === accountId;
  }

  /** True while any party's link is between enqueued and stamped. */
  get ownersSending() {
    if (this.ownersSendingAccountId) {
      return true;
    }
    const parties = (this.owners && this.owners.parties) || [];
    return parties.some((p) => p.verificationStatus === "SENDING");
  }

  /** Whether leaving the step should ask: only when somebody was actually added. */
  ownersGateNeeded(nextKey) {
    if (this.ownersGateAnswered || this.openGroup !== "verify") {
      return false;
    }
    if ((GROUP_OF[nextKey] || nextKey) === "verify") {
      return false;
    }
    if (!this.owners || this.owners.readOnly || !this.owners.jointOwnerCount) {
      return false;
    }
    return this.ownersUncovered.length > 0;
  }

  handleOwnersGateAdd() {
    this.ownersGateOpen = false;
    this._ownersPendingSection = undefined;
    this.handleAddToUncovered();
  }

  handleOwnersGateConfirm() {
    this.ownersGateOpen = false;
    this.ownersGateAnswered = true;
    const next = this._ownersPendingSection;
    this._ownersPendingSection = undefined;
    if (next) {
      this.openSection(next);
    }
  }

  /** Creates the Documents__c placeholders. Silent by design. */
  async ensureDocSlots() {
    try {
      await ensureComplianceDocSlots({ opportunityId: this.opportunityId });
    } catch (e) {
      // deliberately swallowed
    }
  }

  async reloadState() {
    const state = await this.fetchState();
    this.state = state || {};
    await this.applyStateSummary();
  }

  /**
   * The one place the page asks for its state: getConsoleStateForOrder with an order,
   * getConsoleState without. Both bootstrap and reloadState go through here.
   */
  fetchState() {
    const salesOrderId = this.requestedOrderId;
    return salesOrderId
      ? getConsoleStateForOrder({ opportunityId: this.opportunityId, salesOrderId })
      : getConsoleState({ opportunityId: this.opportunityId });
  }

  /**
   * Take the server's state without losing the unit the agent picked: Opportunity.Unit__c is
   * only written on Confirm, so the summary is refreshed with the client's unit.
   */
  async applyStateSummary() {
    this.summary = this.state.summary;

    if (this.isMultiUnit) {
      /* a basket being assembled is stripped of per-unit blocks; a committed basket keeps them */
      if (!this.bookingIsCommitted) {
        this.summary = this.summary
          ? { ...this.summary, unit: undefined, plan: undefined, fees: undefined, totalPrice: undefined }
          : this.summary;
      }
      return;
    }

    /* repair a summary missing the plan too, not only the unit */
    const needsUnit = !(this.summary && this.summary.unit);
    const needsPlan =
      !!this.selectedPlanId && !(this.summary && this.summary.plan && this.summary.plan.planId);
    if (this.selectedUnitId && (needsUnit || needsPlan)) {
      await this.refreshSummary();
    }
  }

  // section 3: plan

  async handlePlanChange(event) {
    // belt and braces: the event mutates state, so the guard lives here too
    if (this.bookingIsCommitted) return;
    this.selectedPlanId = event.detail.planId;
    // mirror onto the per-unit cache
    const only = this.selectedUnitIds.length === 1 ? this.selectedUnitIds[0] : null;
    if (only && this.unitPlans[only]) {
      this.unitPlans = {
        ...this.unitPlans,
        [only]: { ...this.unitPlans[only], planId: this.selectedPlanId }
      };
    }
    await this.refreshSummary();
  }

  get planLocked() {
    return this.bookingIsCommitted;
  }

  /* the offer drawer is a child of .page (the card carries backdrop-filter); this flag connects them */
  offerOpen = false;

  /** An offer needs a unit and a plan. */
  /** Which unit an offer is for: the focused unit, read by the button, the drawer and the send. */
  get offerUnitId() {
    return this.isMultiUnit ? this.focusedUnitId : this.selectedUnitId;
  }

  get offerPlanId() {
    return this.isMultiUnit ? this.focusedUnitPlanId : this.selectedPlanId;
  }

  get offerReady() {
    return !!this.opportunityId && !!this.offerUnitId && !!this.offerPlanId;
  }

  get offerDisabled() {
    return !this.offerReady;
  }

  /** B10: the Offer control is off the screen behind a label switch; the code stays. */
  get offerEnabled() {
    return LABELS.OFFER_ENABLED === true;
  }

  /* disabled rather than hidden */
  get offerBlockedReason() {
    if (!this.offerUnitId) {
      return LABELS.OFFER_NEEDS_UNIT;
    }
    if (!this.offerPlanId) {
      return LABELS.OFFER_NEEDS_PLAN;
    }
    return null;
  }

  /* MSC-175: the reason is the tooltip now (offerButtonTitle) */
  get showOfferBlocked() {
    return !this.offerReady && !!this.offerBlockedReason;
  }

  /* MSC-175: why the button is disabled, or what it does. Never blank. */
  get offerButtonTitle() {
    return this.showOfferBlocked ? this.offerBlockedReason : LABELS.OFFER_OPEN;
  }

  handleOpenOffer() {
    if (!this.offerReady) {
      return;
    }
    this.offerOpen = true;
  }

  handleCloseOffer() {
    this.offerOpen = false;
  }

  /* getBookingSummary is in flight for the plan card. Local, never in isBusy. */
  busyPlan = false;

  /** The two waits the plan card owns, as one flag for its skeleton. */
  get planPaneBusy() {
    return this.busyPlan || this.busyUnitConfig;
  }

  /** What the customer must pay before this booking can be made, shown the moment a plan is chosen. */
  get planFeeRows() {
    /* a basket shows no fee block */
    const f = this.summary && this.summary.fees;
    if (this.isMultiUnit || !f || !this.selectedPlanId || !Number(f.minimum)) {
      return [];
    }
    return [
      { key: "adm", label: "ADM & Dari fee", value: formatAED(f.admFee) },
      { key: "down", label: "Down payment", value: formatAED(f.downPayment) },
      { key: "total", label: "Payable before booking", value: formatAED(f.minimum), strong: true }
    ];
  }

  get showPlanFees() {
    return this.planFeeRows.length > 0;
  }

  /** The booking has been written. `confirmed` is this session's flag; `salesOrderId` survives a reload. */
  get bookingIsCommitted() {
    return !!this.salesOrderId || this.confirmed === true;
  }

  /** Was this booking made in this session, or reopened? `confirmed` is the one durable session fact. */
  get resumed() {
    return this.bookingIsCommitted && this.confirmed !== true;
  }

  /* Still to do: money first (closing obligations), then documents, then identity. Built here
   * because every input is already on this page. */
  get stillToDo() {
    if (!this.bookingIsCommitted) {
      return [];
    }
    const items = [];

    /* money: closing rows only */
    const owing = (this.paymentBlocks || []).filter(
      (b) => b.closesSale === true && Number(b.remainingAmount) > 0
    );
    owing.forEach((b) => {
      items.push({
        key: `money-${b.sourceId}`,
        kind: "MONEY",
        text: LABELS.TODO_MONEY.replace(
          "{0}",
          formatAED(b.remainingAmount)
        ).replace("{1}", b.label),
        section: "settle",
        rowId: b.sourceId
      });
    });

    // documents: outstandingLabels
    const docsLeft = ((this.docs && this.docs.outstandingLabels) || []).length;
    if (docsLeft > 0) {
      items.push({
        key: "docs",
        kind: "DOCUMENT",
        text:
          docsLeft === 1
            ? LABELS.TODO_DOCS_ONE
            : LABELS.TODO_DOCS.replace("{0}", String(docsLeft)),
        section: "settle",
        rowId: null
      });
    }

    /* identity: verified and in-branch are both finished */
    const v = this.verificationStatus;
    /* and SENT: the rep has done their part */
    if (!this.complianceCleared && v !== "VERIFIED" && v !== "IN_BRANCH" && v !== "SENT") {
      let text = LABELS.TODO_VERIFY_NONE;
      if (this.complianceDeclined) {
        text = LABELS.TODO_VERIFY_DECLINED;
      } else if (v === "EXPIRED") {
        text = LABELS.TODO_VERIFY_EXPIRED;
      } else if (v === "SENT") {
        text = LABELS.TODO_VERIFY_WAIT;
      }
      items.push({
        key: "verify",
        kind: "VERIFICATION",
        text,
        section: "verify",
        rowId: null
      });
    }

    /* the first item is the next action */
    return items.map((it, i) => ({ ...it, isNext: i === 0 }));
  }

  /* the one switch: SHOW_STILL_TO_DO */
  get hasStillToDo() {
    return SHOW_STILL_TO_DO && this.stillToDo.length > 0;
  }

  /** Open the place the work is done; for a money item, open the ledger row too. */
  handleStillToDoJump(event) {
    const d = event.detail || {};
    this.pendingRowId = d.rowId || undefined;
    if (d.section) {
      this.openSection(d.section);
    }
  }

  /** Consumed by c-msc-obligations. */
  pendingRowId;

  handleRowOpened() {
    this.pendingRowId = undefined;
  }

  /* MSC-097: the milestone payments modal, mounted at .page. The modal is dumb: it is fed
   * milestoneBatch and the milestone slice of ledgerRows and re-raises chequesubmit / ddcreate. */
  milestoneModalOpen = false;
  milestoneModalFocusSo;
  milestoneModalFocusRow;

  /** The schedule the modal holds: milestones after the down payment, every unit's, asked of c/mscPaymentFacts. */
  get milestoneModalRows() {
    return this.ledgerRows.filter((r) => r.closesSale !== true && isScheduledMilestone(r));
  }

  handleManageMilestones(event) {
    const d = (event && event.detail) || {};
    this.milestoneModalFocusSo = d.salesOrderId || undefined;
    this.milestoneModalFocusRow = undefined;
    /* one overlay at a time */
    this.paymentModalRowId = undefined;
    this.milestoneModalOpen = true;
  }

  /** The deep link. */
  handleOpenMilestones(event) {
    const d = (event && event.detail) || {};
    this.milestoneModalFocusSo = d.salesOrderId || undefined;
    this.milestoneModalFocusRow = d.sourceId || undefined;
    this.paymentModalRowId = undefined;
    this.milestoneModalOpen = true;
  }

  handleMilestoneModalClose() {
    this.milestoneModalOpen = false;
    this.milestoneModalFocusRow = undefined;
  }

  /* MSC-099: one payment on a surface of its own. The state is the id, never the row object,
   * so the modal always shows what the server last said. */
  paymentModalRowId;

  /** The one payment the modal is about, or undefined if it left the ledger (then the modal closes itself). */
  get paymentModalRow() {
    const id = this.paymentModalRowId;
    return id ? this.ledgerRows.find((r) => r.sourceId === id) : undefined;
  }

  get paymentModalOpen() {
    return !!this.paymentModalRowId && !!this.paymentModalRow;
  }

  handleOpenPayment(event) {
    const d = (event && event.detail) || {};
    if (!d.sourceId) {
      return;
    }
    /* one overlay at a time */
    this.milestoneModalOpen = false;
    this.milestoneModalFocusRow = undefined;
    /* MSC-201: the last attempt's answer is not this one's */
    this.proofResult = undefined;
    this.paymentModalRowId = d.sourceId;
  }

  handlePaymentModalClose() {
    const row = this.paymentModalRow;
    this.paymentModalRowId = undefined;
    /* MSC-201: it is matched by sourceId, so without this the same row reopens still showing
       the refusal it was given last time */
    this.proofResult = undefined;
    /* MSC-202: closing without recording abandons the attempt, files included. ONLY on a row
       that records a payment - on a proof-only row the uploaded file IS the submission and is
       never touched. deleteProofSlot itself refuses anything already on a Payment. */
    if (row && row.recordsPayment === true) {
      const ids = new Set(this.proofSlots[row.sourceId] || []);
      (row.proofs || []).forEach((p) => {
        if (p.documentId && p.contentDocumentId && !p.receiptId) ids.add(p.documentId);
      });
      if (ids.size) {
        const next = { ...this.proofSlots };
        delete next[row.sourceId];
        this.proofSlots = next;
        this.discardSlots([...ids])
          .then(() => this.loadBuckets())
          .catch(() => {});
      }
    }
  }

  /** MSC-202: best-effort deletes; a slot that refuses (already recorded) is left alone. */
  async discardSlots(ids) {
    await Promise.all(ids.map((id) => deleteProofSlot({ documentId: id }).catch(() => {})));
  }

  /* refuse to restart a booking that cannot finish: hasExistingSalesOrder and activeHold.blockReason */
  get openBlockReason() {
    const hold = this.state && this.state.activeHold;
    if (hold && hold.blockReason) {
      return hold.blockReason;
    }
    /* a committed booking is not blocked; only an existing order this session did not book */
    if (this.state && this.state.hasExistingSalesOrder && !this.bookingIsCommitted) {
      return (
        "This customer already has a booking on this opportunity. " +
        "Open it from Total Sales rather than starting again."
      );
    }
    return null;
  }

  get isOpenBlocked() {
    return !!this.openBlockReason;
  }

  // section 5: payment

  get paymentBlocks() {
    const list = this.buckets || [];
    return list.map((b, i) => {
      const slots = this.proofSlots[b.sourceId] || [];
      return {
        ...b,
        position: i + 1,
        total: list.length,
        // the newest slot is the upload target
        proofSlotId: slots.length ? slots[slots.length - 1] : undefined,
        hasSlot: slots.length > 0,
        allowDirectDebit:
          b.key === "MILESTONE" && (b.allowedMethods || []).indexOf("Direct Debit") > -1
      };
    });
  }

  /* what the ledger is handed: post-Confirm the two booking-fee lines are dropped (the deposit
     is already inside the Scheduled rows). Everything else keeps reading paymentBlocks. */
  get ledgerRows() {
    const rows = this.paymentBlocks;
    if (!this.bookingIsCommitted) return rows;
    return rows.filter((b) => b.sourceObject !== "Booking_Fee_Line__c");
  }

  /** MSC-096: the payments that close the booking, for the settlement header's strip. */
  get closingLedgerRows() {
    return this.ledgerRows.filter((r) => r.closesSale === true);
  }

  /* paymentGroups deleted; c-msc-obligations groups by closesSale */

  get hasBuckets() {
    return this.paymentBlocks.length > 0;
  }

  get showDirectDebit() {
    // only when at least one milestone offers it (Residents)
    return this.paymentBlocks.some((b) => b.allowDirectDebit);
  }

  /** Every Sales Order in the booking, not just the first. */
  async loadBuckets() {
    if (!this.opportunityId) return;
    const ids = this.allSalesOrderIds;
    this.buckets =
      (await getPaymentBucketsForOrders({
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId,
        salesOrderIds: ids
      })) || [];
  }

  /**
   * Every Sales Order in this booking, on a resumed one too: createdSalesOrderIds is filled by
   * Confirm only, so the fall-through is bookedUnits.
   */
  get allSalesOrderIds() {
    if (this.createdSalesOrderIds && this.createdSalesOrderIds.length) {
      return this.createdSalesOrderIds;
    }
    /* one order in focus is one order's obligations */
    if (this.focusedOrderId) {
      return [this.focusedOrderId];
    }
    const booked = (this.state && this.state.bookedUnits) || [];
    const fromState = booked.map((b) => b.salesOrderId).filter(Boolean);
    if (fromState.length) {
      return fromState;
    }
    return this.salesOrderId ? [this.salesOrderId] : [];
  }

  async loadDocs() {
    this.docs = await getRequiredDocuments({
      salesOrderId: this.salesOrderId,
      opportunityId: this.opportunityId
    });
  }

  async loadDirectDebit() {
    if (!this.salesOrderId) return;
    this.ddState = await getDirectDebitState({ salesOrderId: this.salesOrderId });
  }

  /** The milestone box's facts, one call per Sales Order. Never fatal. */
  async loadMilestoneBatch() {
    if (!this.bookingIsCommitted) {
      this.milestoneBatch = {};
      return;
    }
    const ids = this.allSalesOrderIds || [];
    if (!ids.length) return;
    try {
      const results = await Promise.all(
        ids.map((id) => getMilestoneBatch({ salesOrderId: id }).catch(() => null))
      );
      const next = {};
      results.forEach((dto, i) => {
        if (dto) next[ids[i]] = dto;
      });
      this.milestoneBatch = next;
    } catch (e) {
      // leave the last known batch in place
    }
  }

  /** Record N cheques: whole batch or none; a refusal is handed back to the sheet per line. */
  async handleChequeSubmit(event) {
    const d = (event && event.detail) || {};
    if (!d.salesOrderId || !d.lines || !d.lines.length) return;
    this.busyPayment = true;
    this.chequeError = undefined;
    this.chequeResult = undefined;
    this.errorMsg = undefined;
    try {
      const res = await createChequePayments({
        input: { salesOrderId: d.salesOrderId, bank: d.bank, lines: d.lines }
      });
      if (res && res.recorded) {
        await Promise.all([
          this.loadBuckets(),
          this.loadSettlement(),
          this.loadMilestoneBatch(),
          this.loadDirectDebit()
        ]);
        /* MSC-097: the sheet lives in the modal */
        const modal = this.template.querySelector("c-msc-milestone-modal");
        if (modal && modal.closePanels) modal.closePanels(d.salesOrderId);
      } else {
        this.chequeResult = res;
        this.chequeError = res && res.message ? res.message : "Something went wrong. Please try again.";
      }
    } catch (e) {
      this.chequeError = reduceError(e);
    } finally {
      this.busyPayment = false;
    }
  }

  /**
   * Creates the Documents__c slot the file input attaches to. The map holds a list per
   * obligation. The Sales Order comes from the bucket, not the page.
   */
  async handleRequestSlot(event) {
    const d = event.detail;
    this.busyPayment = true;
    try {
      const proof = await createProofSlot({
        req: {
          salesOrderId: d.salesOrderId || this.salesOrderId,
          bucketKey: d.paymentType,
          sourceId: d.relatedRecordId,
          amount: d.amount,
          reference: d.reference
        }
      });
      const existing = this.proofSlots[d.relatedRecordId] || [];
      this.proofSlots = {
        ...this.proofSlots,
        [d.relatedRecordId]: [...existing, proof.documentId]
      };
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyPayment = false;
    }
  }

  async handleProofUploaded() {
    await this.loadBuckets();
    await this.loadSettlement();
    await this.refreshSummary();
    this.loadMilestoneBatch();
  }

  /** A proof photographed or picked: find or make the row's slot, upload, reload, settle the chip. Uploads queue. */
  handleCaptureProof(event) {
    const d = (event && event.detail) || {};
    if (!d.base64 || !d.relatedRecordId) {
      if (typeof d.done === "function") d.done(false, "The file was empty. Attach it again.");
      return;
    }
    this._proofChain = this._proofChain
      .then(() => this.stageProof(d))
      .catch(() => {});
  }

  async stageProof(d) {
    this.errorMsg = undefined;
    let slotId;
    try {
      slotId = await this.slotFor(d);
      await uploadProofImage({
        documentId: slotId,
        base64Data: d.base64,
        fileName: d.fileName
      });
      /* MSC-203: a new file on this row is a new attempt - the last attempt's answer (the
         refusal in red, or a stale success) does not describe it */
      if (this.proofResult && this.proofResult.sourceId === d.relatedRecordId) {
        this.proofResult = undefined;
      }
      await this.handleProofUploaded();
      if (typeof d.done === "function") d.done(true);
    } catch (e) {
      const message = reduceError(e);
      /* the slot was made for this file; with no file it is nothing */
      if (slotId) {
        try {
          await deleteProofSlot({ documentId: slotId });
        } catch (ignore) {
          // an empty placeholder is harmless
        }
        const kept = (this.proofSlots[d.relatedRecordId] || []).filter((id) => id !== slotId);
        this.proofSlots = { ...this.proofSlots, [d.relatedRecordId]: kept };
      }
      if (typeof d.done === "function") d.done(false, message);
      else this.errorMsg = message;
    }
  }

  /** One slot per file, made here; a chip's "x" removes exactly that file. */
  async slotFor(d) {
    const rowId = d.relatedRecordId;
    const known = this.proofSlots[rowId] || [];
    const proof = await createProofSlot({
      req: {
        salesOrderId: d.salesOrderId || this.salesOrderId,
        bucketKey: d.paymentType,
        sourceId: rowId,
        amount: d.amount,
        reference: d.reference
      }
    });
    this.proofSlots = { ...this.proofSlots, [rowId]: [...known, proof.documentId] };
    return proof.documentId;
  }

  /** The "x" on an attached-not-yet-recorded chip: slot and file go together. */
  async handleProofRemoved(event) {
    const d = (event && event.detail) || {};
    const documentId = d.documentId;
    if (!documentId) return;
    try {
      await deleteProofSlot({ documentId });
      /* MSC-203: pulling the file off is starting over; the old answer goes with it */
      this.proofResult = undefined;
      /* forget the slot as well as the record */
      const next = {};
      Object.keys(this.proofSlots || {}).forEach((k) => {
        const kept = (this.proofSlots[k] || []).filter((id) => id !== documentId);
        if (kept.length) {
          next[k] = kept;
        }
      });
      this.proofSlots = next;
      await this.loadBuckets();
      await this.loadSettlement();
      if (typeof d.done === "function") d.done(true);
    } catch (e) {
      const message = reduceError(e);
      if (typeof d.done === "function") d.done(false, message);
      else this.errorMsg = message;
    }
  }

  /**
   * Create Payment: on a row that records payments this calls recordProofPayment; the answer
   * lands on that row and the ledger reloads.
   */
  async handleSubmitProof(event) {
    const d = (event && event.detail) || {};
    if (d.recordsPayment !== true) {
      // the proof record already carries the file
      this.loadBuckets();
      this.loadSettlement();
      this.loadMilestoneBatch();
      return;
    }
    const sourceId = d.relatedRecordId;
    this.busyPayment = true;
    this.proofResult = undefined;
    this.errorMsg = undefined;
    try {
      const res = await recordProofPayment({
        input: {
          salesOrderId: d.salesOrderId || this.salesOrderId,
          bucketKey: d.paymentType,
          sourceId,
          method: d.method,
          transactionNumber: d.transactionNumber,
          paidDate: d.paidDate,
          amount: d.amount,
          bank: d.bank,
          documentIds: d.documentIds || [],
          /* MSC-197: the read the form already has for this cheque image; the server stamps it
             instead of reading the same file again. Undefined on anything else. */
          chequeRead: d.chequeRead || null
        }
      });
      /* the slots are recorded now; the next file needs its own */
      const next = { ...this.proofSlots };
      delete next[sourceId];
      this.proofSlots = next;
      this.proofResult = { sourceId, ok: true, message: res && res.message ? res.message : LABELS.CTA_CREATE_PAYMENT };
      await Promise.all([this.loadBuckets(), this.loadSettlement(), this.loadMilestoneBatch()]);
      await this.refreshSummary();
    } catch (e) {
      this.proofResult = { sourceId, ok: false, message: reduceError(e) };
      /* MSC-202: a refused attempt takes its photo with it - the wrong cheque's image must not
         become the next payment's proof. The refusal above still shows; the chip goes. */
      const ids = (d.documentIds || []).filter(Boolean);
      if (ids.length) {
        const next = { ...this.proofSlots };
        delete next[sourceId];
        this.proofSlots = next;
        try {
          await this.discardSlots(ids);
          await this.loadBuckets();
        } catch (ignore) {
          /* the reload can be repeated by hand; the delete is best-effort */
        }
      }
    } finally {
      this.busyPayment = false;
    }
  }

  /** MSC-197: a cheque read was retried from the ledger; the answer is on the record. */
  handleLedgerRefresh() {
    this.loadBuckets();
  }

  /** Direct Debit from the milestone box; on success the box's batch reloads. */
  async handleDirectDebitCreate(event) {
    const d = (event && event.detail) || {};
    const salesOrderId = d.salesOrderId || this.salesOrderId;
    if (!salesOrderId) return;
    this.busyPayment = true;
    this.errorMsg = undefined;
    try {
      const state = await submitDirectDebitMandate({
        input: {
          salesOrderId,
          accountName: d.accountName,
          bankName: d.bankName,
          accountType: d.accountType,
          iban: d.iban,
          idType: d.idType,
          idNumber: d.idNumber,
          mobile: d.mobile,
          email: d.email,
          city: d.city
        }
      });
      if (salesOrderId === this.salesOrderId) this.ddState = state;
      if (state && state.linkNote) {
        this.errorMsg = LABELS.DD_LINK_NOTE.replace("{0}", state.linkNote);
      } else if (state && state.problems && state.problems.length) {
        /* saved; Finance will have to fix these before sending */
        this.errorMsg = `${LABELS.DD_PROBLEMS} ${state.problems.join(" · ")}`;
      }
      await Promise.all([this.loadMilestoneBatch(), this.loadBuckets()]);
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyPayment = false;
    }
  }

  /** SCW-125: the mandate card acted (refresh, discard, fetch, cancellation request). */
  async handleDdChanged() {
    try {
      await Promise.all([this.loadMilestoneBatch(), this.loadBuckets()]);
    } catch (e) {
      // the card already shows its own outcome
    }
  }

  // section 6: review

  /** Plain-language reasons confirmation is not yet possible, each naming the section that fixes it. */
  get blockers() {
    return [...this.structuralBlockers, ...this.feeBlockers];
  }

  /* two lists: structural (the deal) and money (the fee legs); `blockers` is the whole list */
  get structuralBlockers() {
    const out = [];
    if (!this.hasUnit) out.push("Select a unit.");
    if (!this.hasCustomer) out.push("Complete customer information.");
    if (!this.hasPlan) {
      out.push(this.isMultiUnit ? LABELS.MULTI_PLAN_PER_UNIT : "Select a payment plan.");
    }
    if (this.state && this.state.eligibilityBlocked && this.state.eligibilityMessage) {
      out.push(this.state.eligibilityMessage);
    }
    /* the plan has to have a schedule (createPaymentInstallments throws on an empty one).
       `false` only: undefined means unanswered. */
    if (this.planScheduleOk === false) {
      out.push(LABELS.LEDGER_PLAN_NO_SCHEDULE);
    }
    return out;
  }

  get feeBlockers() {
    const out = [];
    // the booking fees gate confirmation; future milestones do not
    /* Array.isArray, not `|| []`: this runs on every render */
    const unpaid = (Array.isArray(this.buckets) ? this.buckets : []).filter(
      (b) => b.blocksConfirmation && Number(b.paidAmount || 0) < Number(b.requiredAmount || 0)
    );
    if (unpaid.length) {
      unpaid.forEach((b) =>
        out.push(`${b.label} has not been received yet (${formatAED(b.requiredAmount)}).`)
      );
    }
    return out;
  }

  /* recapRows deleted: the rail is the record of the booking */

  /* the settlement figure: loaded alongside the buckets because it previews before any Sales
   * Order exists */
  settlement;

  async loadSettlement() {
    if (!this.opportunityId) return;
    try {
      this.settlement = await getSettlement({
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId || null,
        salesOrderIds: this.allSalesOrderIds || [],
        planId: this.selectedPlanId || null,
        totalAmount: this.settlementPreviewPrice
      });
    } catch (e) {
      /* never fatal: the header simply does not render */
      this.settlement = undefined;
    }
  }

  /* the plan-has-a-schedule guard: undefined until asked; a separate call so a basket's other
   * units are covered */
  planScheduleOk;

  async checkPlanSchedule(planId) {
    if (!planId) {
      this.planScheduleOk = undefined;
      return;
    }
    try {
      this.planScheduleOk = await planHasSchedule({ paymentPlanId: planId });
    } catch (e) {
      /* saveSalesOrder is still the authority */
      this.planScheduleOk = undefined;
    }
  }

  /** The price the preview is taken against. Single unit only. */
  get settlementPreviewPrice() {
    if (this.isMultiUnit) return null;
    if (this.summary && this.summary.totalPrice != null) {
      return this.summary.totalPrice;
    }
    const u = this.focusedUnitRecord;
    return u ? u.TotalPrice__c : null;
  }

  get dueNow() {
    // a basket collects nothing: null, not zero
    if (this.isMultiUnit) return null;
    return this.summary && this.summary.fees ? this.summary.fees.minimum : null;
  }

  /* multi-unit */
  get selectedUnitCount() {
    return this.selectedUnitIds.length;
  }

  /** Three sources: the server's total when committed, the seeded price, the grid record. */
  get basketTotal() {
    const s = this.summary;
    if (this.bookingIsCommitted && s && Number(s.totalPrice) > 0) {
      return Number(s.totalPrice);
    }
    return this.selectedUnitIds.reduce((sum, id) => {
      const cached = this.unitPlans[id];
      /* 1.x+13 - the chosen option prices the unit, as on the order */
      const optionPrice =
        cached && cached.unitOptionId && cached.optionPrices ? cached.optionPrices[cached.unitOptionId] : null;
      if (Number(optionPrice) > 0) {
        return sum + Number(optionPrice);
      }
      if (cached && cached.totalPrice != null) {
        return sum + Number(cached.totalPrice || 0);
      }
      const u = (this.units || []).find((x) => x.Id === id);
      return sum + Number((u && u.TotalPrice__c) || 0);
    }, 0);
  }

  /** The server's own block for one unit of a basket, looked up by unitId. */
  serverUnitBlock(unitId) {
    const list = (this.summary && this.summary.units) || [];
    return list.find((u) => u && u.unitId === unitId) || null;
  }

  serverPlanBlock(unitId) {
    const units = (this.summary && this.summary.units) || [];
    const plans = (this.summary && this.summary.plans) || [];
    const i = units.findIndex((u) => u && u.unitId === unitId);
    return i >= 0 && plans[i] ? plans[i] : null;
  }

  get summaryCustomerName() {
    return this.summary && this.summary.customer ? this.summary.customer.name : null;
  }

  get confirmLabel() {
    return this.isMultiUnit ? LABELS.MULTI_CONFIRM_CTA : LABELS.CTA_CONFIRM;
  }

  get confirmingLabel() {
    return this.isMultiUnit ? LABELS.MULTI_CONFIRMING : LABELS.CTA_CONFIRMING;
  }

  /** Replaces the payment section for a basket. */
  /** The section exists when it has something in it (fee lines or documents). */
  get showPaymentSection() {
    /* and not while the booking fee is being waited for */
    if (this.awaitingFeeReceipt) return false;
    /* and not before the booking is made, by request */
    if (!this.bookingIsCommitted) return false;
    /* the ledger alone */
    return this.hasBuckets;
  }

  /** A booking fee is owed, the booking is not made, and nothing has landed against the fee yet. */
  get awaitingFeeReceipt() {
    return (
      this.paymentRequired === true &&
      !this.bookingIsCommitted &&
      !this.feeSettled &&
      !this.hasCollected
    );
  }

  /** Direct debit has no place in a basket, and is not mounted on the card at all (by request). */
  get showDirectDebitSafe() {
    return false;
  }

  get multiConfirmedMessage() {
    return LABELS.MULTI_CONFIRMED.replace(
      "{0}",
      String(this.createdSalesOrderIds.length)
    );
  }

  /* the booking fee: hold the unit, send the agent to the terminal, watch for the money */
  @track feeStatus;
  paymentRequired = false;
  /* 1.x+10: the unit's EOI deposit stands in for the booking fee (switch on) */
  feeCoveredByEoi = false;
  /**
   * The waiting state is derived from the hold (the server's record that a payment run is open),
   * not remembered. `_payRequested` covers the round trip.
   */
  _payRequested = false;
  /** True only while beginPayment is in flight. */
  busyPayStart = false;
  _payPoll;
  /* a status check the agent asked for, and that automatic checking has given up */
  busyFeeRefresh = false;
  watchStopped = false;

  /* the hold as a running clock, resynced from the server on step open, payment, and tab return */
  holdSecondsLeft;
  _holdTick;
  busyHoldCancel = false;

  /* the hold window, from the same custom label the server honours */
  holdMinutes = 10;

  /* 1.x+18 - the booking fee by payment link: the server's AurelixBookingFeeLink.LinkState */
  @track feeLinkState;
  busyLinkResend = false;

  /** True when the fee is collected by links (BOOKING_FEE_BY_LINK), false for the MODON Pay card page. */
  get linkMode() {
    return !!this.feeLinkState && this.feeLinkState.linkMode === true;
  }

  /** A link the customer can still pay. */
  get linkLive() {
    return this.linkMode && this.feeLinkState.anyLive === true;
  }

  /** One quiet row per fee for c/mscReviewConfirm. */
  get feeLinkRows() {
    const links = (this.feeLinkState && this.feeLinkState.links) || [];
    return links.map((l) => {
      let statusText = l.status || "";
      let tone = "";
      if (l.live) {
        statusText = "Link sent";
        tone = " links__status--live";
      } else if (l.paid) {
        statusText = "Paid";
        tone = " links__status--paid";
      } else if (l.status === "Link Created" || l.status === "Expired") {
        statusText = "Expired";
      }
      let untilText = "";
      if (l.live && l.expiresOn) {
        const t = new Date(l.expiresOn);
        untilText = `until ${t.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })}`;
      }
      return {
        key: l.id || l.purpose,
        label: l.label || l.purpose || "",
        amountText: l.amount !== null && l.amount !== undefined ? formatAED(l.amount) : "",
        statusText,
        untilText,
        cls: `links__status${tone}`
      };
    });
  }

  /** The link state, read with the fee. A failed read only costs the rows. */
  async loadLinkState() {
    if (!this.opportunityId || !this.selectedUnitId || !this.paymentRequired) {
      this.feeLinkState = undefined;
      return;
    }
    try {
      this.feeLinkState = await getBookingFeeLinkState({
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId
      });
    } catch (e) {
      // the server refuses a release or a second link on its own
    }
  }

  /** The one place "the booking fee is in" is decided. */
  get feeSettled() {
    const f = this.feeStatus;
    return !!f && (f.isFullyPaid === true || f.allowPartialBooking === true);
  }

  /** Has any money landed against this booking fee? "> 0", not "fully paid". */
  get hasCollected() {
    const f = this.feeStatus;
    return !!f && Number(f.totalPaid) > 0;
  }

  /** A hold is running against an unsettled fee. */
  get payRunOpen() {
    return (
      this.paymentRequired === true &&
      !this.feeSettled &&
      Number(this.holdSecondsLeft) > 0
    );
  }

  /* server truth first; settled wins over both */
  get awaitingPayment() {
    if (this.feeSettled) {
      return false;
    }
    return this._payRequested === true || this.payRunOpen;
  }

  async loadHoldMinutes() {
    try {
      const mins = await getPaymentHoldMinutes();
      if (mins) this.holdMinutes = mins;
    } catch (e) {
      // the default matches the server's own fallback
    }
  }

  /** Read on the confirm step and after every payment poll. */
  async loadFees() {
    /* a basket member opened alone was never asked for a fee */
    if (!this.opportunityId || !this.selectedUnitId || this.isMultiUnit || this.isBasketMember) {
      this.feeStatus = undefined;
      this.paymentRequired = false;
      this.feeCoveredByEoi = false;
      this.feeNeedUnitId = undefined;
      return;
    }
    try {
      /* asked here, not read off the unit cache: it is a per-opportunity question.
         1.x+10: with the unit's EOI, so a paid EOI can stand in for the fee (switch on) */
      const need = await getBookingFeeNeed({
        unitId: this.selectedUnitId,
        opportunityId: this.opportunityId,
        eoiMappingJson: this.eoiMappingJson
      });
      this.paymentRequired = !!need && need.required === true;
      this.feeCoveredByEoi = !!need && need.coveredByEoi === true;
      this.feeNeedUnitId = need ? this.selectedUnitId : undefined;
      if (!this.paymentRequired) {
        this.feeStatus = undefined;
        this.feeLinkState = undefined;
        return;
      }
      this.feeStatus = await getFeeStatus({
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId
      });
      /* 1.x+18 - and the links, which say which button this step offers */
      await this.loadLinkState();
    } catch (e) {
      // never blocks the recap; the confirm button is gated server-side
      this.feeNeedUnitId = undefined;
      this.errorMsg = reduceError(e);
    }
  }

  /** 1.x+12 - the unit the fee answer above belongs to; the answer is stale for any other. */
  feeNeedUnitId;

  /**
   * 1.x+12 - a single unit that takes no booking fee before Confirm (the phase takes none, or the
   * unit's EOI covers it). The settlement preview is the booking-fee formula, so the header must
   * not call it payable.
   */
  get settlementNoFee() {
    return (
      !!this.selectedUnitId &&
      this.feeNeedUnitId === this.selectedUnitId &&
      this.paymentRequired !== true &&
      !this.isMultiUnit &&
      !this.isBasketMember &&
      !this.bookingIsCommitted
    );
  }

  /** Hold the unit, open the terminal, then watch. 1.x+18: or send the payment links. */
  async handleTakePayment() {
    /* guarded on the call being in flight, not on the state being open */
    if (this.busyPayStart || !this.selectedUnitId) return;
    if (this.linkMode) {
      await this.handleSendLink();
      return;
    }
    this.busyPayStart = true;
    this._payRequested = true;
    this.errorMsg = undefined;
    try {
      /* beginPayment, not startPaymentHold: it raises the fee lines first */
      this.feeStatus = await beginPayment({
        req: {
          opportunityId: this.opportunityId,
          unitId: this.selectedUnitId,
          paymentPlanId: this.selectedPlanId,
          payNow: false,
          /* 1.x+16 - the rep's EOI; the server refuses a fee without one where one must be chosen */
          eoiMappingJson: this.eoiMappingJson,
          /* 1.x+11 - the server refuses a fee when a required facade style is missing */
          ...this.bookingExtrasPayload(this.selectedUnitId)
        }
      });
      const base = await getPaymentTerminalUrl();
      // window.open, not a redirect
      window.open(`${base}?op=${this.opportunityId}`, "_blank", "noopener");
      /* the hold before the watch, and the settlement with them */
      await this.syncHold();
      this.startPayPolling();
      this.loadSettlement();
    } catch (e) {
      this._payRequested = false;
      this.errorMsg = reduceError(e);
    } finally {
      this.busyPayStart = false;
    }
  }

  /**
   * 1.x+18 - Send payment link: hold and reserve the unit in one call, then one call per fee link
   * (each is a callout, which cannot follow a write in the same call). Then the same watch as the terminal.
   */
  async handleSendLink() {
    this.busyPayStart = true;
    this._payRequested = true;
    this.errorMsg = undefined;
    try {
      const start = await startBookingFeeLink({
        req: {
          opportunityId: this.opportunityId,
          unitId: this.selectedUnitId,
          paymentPlanId: this.selectedPlanId,
          payNow: false,
          eoiMappingJson: this.eoiMappingJson,
          ...this.bookingExtrasPayload(this.selectedUnitId)
        }
      });
      if (start && start.feeStatus) this.feeStatus = start.feeStatus;
      const purposes = (start && start.linkState && start.linkState.purposesToSend) || [];
      /* R2-17: each send answers with the links so far; the list is shown once every fee has its link,
         so it never reads one fee for the seconds the second callout takes */
      let linkState = start && start.linkState;
      const failed = [];
      for (const purpose of purposes) {
        try {
          // eslint-disable-next-line no-await-in-loop
          linkState = await sendBookingFeeLink({
            opportunityId: this.opportunityId,
            unitId: this.selectedUnitId,
            purpose
          });
        } catch (e) {
          failed.push(reduceError(e));
        }
      }
      if (linkState) this.feeLinkState = linkState;
      if (failed.length) {
        this.errorMsg = failed[0];
        await this.loadLinkState();
      }
      await this.syncHold();
      this.startPayPolling();
      this.loadSettlement();
    } catch (e) {
      this._payRequested = false;
      this.errorMsg = reduceError(e);
      this.loadLinkState();
    } finally {
      this.busyPayStart = false;
    }
  }

  /** 1.x+18 - the same stored link message again, for every live link. */
  async handleResendLink() {
    if (this.busyLinkResend) return;
    this.busyLinkResend = true;
    this.errorMsg = undefined;
    try {
      await resendBookingFeeLink({ opportunityId: this.opportunityId, unitId: this.selectedUnitId });
      this.toast("Payment link sent again.");
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyLinkResend = false;
      this.loadLinkState();
    }
  }

  /**
   * Money lands via a REST callback, so polling is the only way to know. Starts wherever the
   * step is open with a balance outstanding; gives up after the hold window and says so.
   */
  startPayPolling() {
    this.stopPayPolling();
    this.watchStopped = false;
    /* measured against the hold that is actually running, plus a minute of grace */
    const held = Number(this.holdSecondsLeft);
    const seconds = held > 0 ? held + 60 : (Number(this.holdMinutes) + 1) * 60;
    const deadline = Date.now() + seconds * 1000;
    this._payPoll = setInterval(async () => {
      /* not while nobody is looking: round trips wait for a visible tab; the deadline check
         still runs */
      if (document.visibilityState === "visible") {
        /* the header and the ledger are refreshed on the same tick as the fee panel */
        /* 1.x+18 - loadFees re-reads the links too, so Release unit wakes when a link lapses */
        await Promise.all([
          this.loadFees(),
          this.loadSettlement(),
          this.loadBuckets()
        ]);
      }
      if (this.feeSettled) {
        this.stopPayPolling();
        this._payRequested = false;
        /* 1.x+12 - one more read of the card and the rows: the three calls above run side by side,
           so the money can land after the settlement was read and before the fee status was */
        Promise.all([this.loadSettlement(), this.loadBuckets()]);
        return;
      }
      if (Date.now() > deadline) {
        this.stopPayPolling();
        this._payRequested = false;
        this.watchStopped = true;
      }
    }, 5000);
  }

  /* the hold clock */

  /** Ask the server what is left, then run the clock down. */
  async syncHold() {
    if (!this.opportunityId || !this.selectedUnitId || this.isMultiUnit) {
      this.stopHoldTick();
      this.holdSecondsLeft = undefined;
      return;
    }
    try {
      const left = await getHoldSecondsRemaining({
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId
      });
      this.holdSecondsLeft = left === null || left === undefined ? undefined : Number(left);
      if (this.holdSecondsLeft > 0) {
        this.startHoldTick();
      } else {
        this.stopHoldTick();
      }
    } catch (e) {
      // a failed read only costs the countdown
      this.stopHoldTick();
    }
  }

  startHoldTick() {
    this.stopHoldTick();
    this._holdTick = setInterval(() => {
      if (this.holdSecondsLeft === undefined || this.holdSecondsLeft <= 0) {
        this.stopHoldTick();
        return;
      }
      this.holdSecondsLeft -= 1;
      if (this.holdSecondsLeft <= 0) {
        this.holdSecondsLeft = 0;
        this.stopHoldTick();
        /* expired: stop watching */
        this._payRequested = false;
        this.stopPayPolling();
        this.watchStopped = true;
        /* 1.x+18 - the link lapsed with the hold: re-read it so Release unit wakes up */
        if (this.linkMode) {
          // eslint-disable-next-line @lwc/lwc/no-async-operation
          setTimeout(() => this.loadLinkState(), 2000);
        }
      }
    }, 1000);
  }

  stopHoldTick() {
    if (this._holdTick) {
      clearInterval(this._holdTick);
      this._holdTick = undefined;
    }
  }

  /** A throttled background tab drifts, so the clock is re-read on return. */
  handleVisibility = () => {
    if (document.visibilityState !== "visible" || this.openGroup !== "settle") {
      return;
    }
    /* and the settlement, the watch and the ledger: returning to the tab has to bring back everything */
    Promise.all([
      this.syncHold(),
      this.loadFees(),
      this.loadSettlement(),
      this.loadBuckets()
    ]).then(() => this.maybeStartPayPolling());
  };

  /** Give the unit back. 1.x+16 - live or lapsed hold; the server refuses while money is on the fee lines. */
  async handleCancelHold() {
    if (this.busyHoldCancel || !this.selectedUnitId) return;
    this.busyHoldCancel = true;
    this.errorMsg = undefined;
    try {
      await cancelPaymentHold({ opportunityId: this.opportunityId, unitId: this.selectedUnitId });
      this.stopPayPolling();
      this.stopHoldTick();
      this.holdSecondsLeft = undefined;
      this._payRequested = false;
      this.watchStopped = false;
      /* and the settlement and the ledger, both built from those fee lines */
      await Promise.all([
        this.loadFees(),
        this.loadSettlement(),
        this.loadBuckets()
      ]);
    } catch (e) {
      this.errorMsg = reduceError(e);
      /* refused because money landed: the fee panel reads it, and Release goes */
      this.loadFees();
    } finally {
      this.busyHoldCancel = false;
    }
  }

  /* offers and discounts: shown rather than applied silently; 1.x+17 - every eligible offer arrives ticked */
  /* keyed by unit */
  @track offersByUnit = {};
  @track offerChoice = {};

  /** Loaded for every unit; the basket is passed as the priced set for the price band. */
  async loadOffers() {
    const units = this.selectedUnitIds || [];
    if (!this.opportunityId || !units.length) {
      this.offersByUnit = {};
      this.offerChoice = {};
      return;
    }
    /* 1.x+13 - a made booking shows what it carries, not what it could have had */
    if (this.bookingIsCommitted) {
      try {
        const applied = (await getAppliedOffers({
          opportunityId: this.opportunityId,
          salesOrderIds: this.allSalesOrderIds || []
        })) || {};
        const picked = {};
        Object.keys(applied).forEach((unitId) => {
          (applied[unitId] || []).forEach((o) => {
            picked[`${unitId}|${o.id}`] = true;
          });
        });
        this.offersByUnit = applied;
        this.offerChoice = picked;
      } catch (e) {
        this.offersByUnit = {};
        this.offerChoice = {};
      }
      return;
    }
    try {
      const byUnit = {};
      const picked = {};
      for (const unitId of units) {
        // sequential on purpose: queryOffers is a chain of SOQL per call
        // eslint-disable-next-line no-await-in-loop
        const rows = await getEligibleOffersForBasket({
          opportunityId: this.opportunityId,
          unitId,
          basketUnitIds: units
        });
        byUnit[unitId] = rows || [];
        /* 1.x+17 - every eligible offer, as the Sales App saves them, not only the default ones */
        (rows || []).forEach((o) => {
          picked[`${unitId}|${o.id}`] = true;
        });
      }
      this.offersByUnit = byUnit;
      this.offerChoice = picked;
    } catch (e) {
      // booking at full price is the safe direction to fail in
      this.offersByUnit = {};
      this.offerChoice = {};
    }
  }

  /** One group per unit; the heading is suppressed for a single booking. */
  get offerGroups() {
    const units = this.selectedUnitIds || [];
    const multi = units.length > 1;
    const groups = [];
    units.forEach((unitId) => {
      const rows = this.offersByUnit[unitId] || [];
      if (!rows.length) return;
      groups.push({
        key: unitId,
        unitName: this.unitNameFor(unitId),
        showHeading: multi,
        rows: rows.map((o) => ({
          ...o,
          key: `${unitId}|${o.id}`,
          choiceKey: `${unitId}|${o.id}`,
          unitId,
          checked: !!this.offerChoice[`${unitId}|${o.id}`],
          sub: [o.offerType, o.offerOn].filter(Boolean).join(" · ")
        }))
      });
    });
    return groups;
  }

  unitNameFor(unitId) {
    const row = (this.unitPlanRows || []).find((r) => r.unitId === unitId);
    return row ? row.name : null;
  }

  get hasOffers() {
    return this.offerGroups.length > 0;
  }

  /** 1.x+17 - the rep may untick an offer and tick it again; the Sales App has no one-per-charge rule. */
  handleOfferToggle(event) {
    const id = event.target.dataset.id;
    const unitId = event.target.dataset.unit;
    const next = { ...this.offerChoice };
    if (event.target.checked) {
      next[`${unitId}|${id}`] = true;
    } else {
      delete next[`${unitId}|${id}`];
    }
    this.offerChoice = next;
  }

  /** Flat list for the single-unit request. */
  get selectedOfferIds() {
    return this.offerIdsForUnit(this.selectedUnitId);
  }

  offerIdsForUnit(unitId) {
    if (!unitId) return [];
    return Object.keys(this.offerChoice || {})
      .filter((k) => this.offerChoice[k] && k.indexOf(`${unitId}|`) === 0)
      .map((k) => k.split("|")[1]);
  }

  /* quoting an offer: books nothing and holds nothing */
  orgUrl;
  /** The site's URL path prefix, or '' in a site with no prefix; undefined means Lightning Experience. */
  sitePrefix;
  busyOffer = false;
  offerSentTo;

  async loadOrgUrl() {
    /* both in parallel, neither takes the other down */
    const [org, prefix] = await Promise.all([
      getOrgUrl().catch(() => undefined),
      getSitePathPrefix().catch(() => undefined)
    ]);
    if (org !== undefined) {
      this.orgUrl = org;
    }
    if (prefix !== undefined && prefix !== null) {
      this.sitePrefix = prefix;
    }
  }

  /** A basket has no summary.unit; c/mscOffer picks the PDF page from this name. */
  get offerProjectName() {
    if (this.isMultiUnit) {
      const e = this.focusedUnitEntry;
      if (e && e.projectName) {
        return e.projectName;
      }
      const u = this.focusedUnitRecord;
      return (u && u.Project_Name__c) || null;
    }
    const u = this.summary && this.summary.unit;
    return u ? u.project : null;
  }

  /** Prefills who the offer is addressed to. */
  get customerDisplayName() {
    const c = this.summary && this.summary.customer;
    return c ? c.name : null;
  }

  /** MSC-225: same block, same load; c/mscOffer builds its wa.me link from this. */
  get customerMobile() {
    const c = this.summary && this.summary.customer;
    return c ? c.mobile : null;
  }

  async handleSendOffer(event) {
    if (this.busyOffer) return;
    this.busyOffer = true;
    this.errorMsg = undefined;
    this.offerSentTo = undefined;
    try {
      const res = await sendOffer({
        opportunityId: this.opportunityId,
        /* the focused unit on a basket */
        unitId: this.offerUnitId,
        planId: this.offerPlanId,
        customerName: (event && event.detail && event.detail.customerName) || null
      });
      if (res && res.isSuccess) {
        this.offerSentTo = res.sentTo;
      } else {
        this.errorMsg = (res && res.message) || "The offer could not be sent.";
      }
    } catch (e) {
      this.errorMsg = reduceError(e);
    } finally {
      this.busyOffer = false;
    }
  }

  /** Poll only where it can pay off. */
  maybeStartPayPolling() {
    /* and not on a hold that has already lapsed */
    const lapsed =
      this.holdSecondsLeft !== undefined &&
      this.holdSecondsLeft !== null &&
      Number(this.holdSecondsLeft) <= 0;
    if (
      this.openGroup === "settle" &&
      this.paymentRequired &&
      !this.feeSettled &&
      !lapsed
    ) {
      this.startPayPolling();
    } else {
      this.stopPayPolling();
    }
  }

  stopPayPolling() {
    if (this._payPoll) {
      clearInterval(this._payPoll);
      this._payPoll = undefined;
    }
  }

  /** The agent asking directly. Not behind c-msc-loader. */
  async handleRefreshFees() {
    if (this.busyFeeRefresh) return;
    this.busyFeeRefresh = true;
    try {
      /* and the settlement and the ledger with it */
      await Promise.all([
        this.loadFees(),
        this.loadSettlement(),
        this.loadBuckets()
      ]);
      // a check that finds it still unpaid resumes watching
      this.maybeStartPayPolling();
    } finally {
      this.busyFeeRefresh = false;
    }
  }

  // teardown lives in the single disconnectedCallback

  async handleConfirm() {
    this.busyConfirm = true;
    this.errorMsg = undefined;
    try {
      /* one request shape for both routes */
      const req = {
        opportunityId: this.opportunityId,
        unitId: this.selectedUnitId,
        paymentPlanId: this.selectedPlanId,
        payNow: false,
        // ids only; the server re-reads each offer's value
        offerLineIds: this.selectedOfferIds,
        /* MSC-231: the deposits; the server re-validates against the engine's eligible list */
        eoiMappingJson: this.eoiMappingJson,
        /* 1.x+11 - facade style and pre-approval number (single unit) */
        ...(this.isMultiUnit ? {} : this.bookingExtrasPayload(this.selectedUnitId))
      };
      if (this.isMultiUnit) {
        req.unitLines = this.unitPlanRows.map((r) => ({
          unitId: r.unitId,
          paymentPlanId: r.planId,
          // offers per unit
          offerLineIds: this.offerIdsForUnit(r.unitId),
          /* 1.x+11 - per unit, as saveSalesOrder checks them per row */
          ...this.bookingExtrasPayload(r.unitId)
        }));
      }

      const res = await reviewAndConfirm({ req });
      if (res && res.isSuccess) {
        this.confirmed = true;
        this.salesOrderId = res.salesOrderId;
        this.bookingRef = res.bookingRef;
        this.createdSalesOrderIds = res.salesOrderIds || [];
        /* release the hold: saveSalesOrder set the unit Reserved. Best-effort. */
        this.stopPayPolling();
        this.stopHoldTick();
        this.holdSecondsLeft = undefined;
        // the payment run is over
        this._payRequested = false;
        this.watchStopped = false;
        if (this.selectedUnitId && !this.isMultiUnit) {
          try {
            await endPaymentHold({ unitId: this.selectedUnitId });
          } catch (e) {
            // swallowed: the hold expires on its own
          }
        }
        // summary is null for a basket by design
        if (res.summary) this.summary = res.summary;
        // non-blocking: an unsubmitted customer is the normal state here
        this.complianceWarning = res.complianceWarning;
        /* R2-11: "Finalising" from the first frame after Confirm, not "waiting for finance" */
        this.ledgerFinalising = true;
        /* the rep stays on Payment & Confirm, by request */
        await Promise.all([
          this.loadBuckets(),
          this.loadDocs(),
          this.loadDirectDebit(),
          this.loadSettlement(),
          this.loadMilestoneBatch()
        ]);
        // a Sales Order now exists, so compliance has something to attach to
        await this.reloadState();
        /* MODON's chain is still running; watch the closing rows until they land, and
           1.x+12 until the sale closes when the money is already in */
        if (!this.settleWatchDone) {
          this.startSettleWatch();
        } else {
          this.ledgerFinalising = false;
        }
      } else {
        this.errorMsg = (res && res.message) || "The booking could not be confirmed.";
        /* the server refused on its own reading of the fee lines; re-read */
        await this.loadFees();
        this.maybeStartPayPolling();
      }
    } catch (e) {
      this.errorMsg = reduceError(e);
      /* a failed read after Confirm must not leave the rows on "Finalising" with no watch running */
      if (!this._settleWatch) {
        this.ledgerFinalising = false;
      }
    } finally {
      this.busyConfirm = false;
    }
  }

  // shared

  /** Fetches the schedule and fees a plan produces; busyPlan drives the card's skeleton, not isBusy. */
  async refreshSummary() {
    this.busyPlan = true;
    try {
      /* the basket form when the booking is a committed basket: every order, the focused unit,
         no plan override */
      const orderIds = this.allSalesOrderIds;
      if (this.isMultiUnit && orderIds.length > 1) {
        this.summary = await getBookingSummaryForOrders({
          opportunityId: this.opportunityId,
          unitId: this.focusedUnitId,
          paymentPlanId: null,
          salesOrderIds: orderIds
        });
      } else {
        /* 1.x+13 - priced at the unit option when one is chosen */
        const extras = this.bookingExtrasFor(this.selectedUnitId);
        this.summary = await getBookingSummaryWithOption({
          opportunityId: this.opportunityId,
          unitId: this.selectedUnitId,
          paymentPlanId: this.selectedPlanId,
          salesOrderId: this.salesOrderId,
          unitOptionId: (extras && extras.unitOptionId) || null
        });
      }
      if (!this.isMultiUnit && this.summary && this.summary.plan) {
        this.planRows = this.summary.plan.rows || [];
      }
      /* the settlement follows the plan (down payment is a percentage of the first milestone);
         not awaited */
      this.loadSettlement();
      /* 1.x+12 - the fee answer, once per unit, so the step bar does not call a no-fee unit's
         figure a booking fee before Payment & Confirm is opened */
      if (!this.isMultiUnit && this.selectedUnitId && this.feeNeedUnitId !== this.selectedUnitId) {
        this.loadFees();
      }
      this.checkPlanSchedule(this.selectedPlanId);
    } finally {
      /* finally: a failed summary must not leave the pane skeletonised */
      this.busyPlan = false;
    }
  }

  get bookingReference() {
    return this.summary ? this.summary.bookingReference : null;
  }

  get docItems() {
    return this.docs ? this.docs.items : [];
  }
  get docsFurtherRequired() {
    return !!(this.docs && this.docs.furtherDocumentsRequired);
  }
  /* the checks the later teams carry, stated as one sentence */
  get docsLaterCount() {
    return this.docs && this.docs.laterCount ? this.docs.laterCount : 0;
  }
  get docsLaterTeams() {
    return this.docs && this.docs.laterTeams ? this.docs.laterTeams : [];
  }
  get hasDocs() {
    return !!(this.docs && this.docs.items && this.docs.items.length);
  }

  /** Every wait this page owns, in one place. Blocking also stops a double press. */
  get isBusy() {
    return !!(
      this.busyPage ||
      this.busyUnits ||
      this.busyUnitConfig ||
      this.busyCustomer ||
      this.busyConfirm ||
      this.busyPayment ||
      this.busyKycLink ||
      this.busyComplianceRefresh
    );
  }

  /** Only the long waits earn a caption. */
  get busyLabel() {
    if (this.busyConfirm) return LABELS.CTA_CONFIRMING;
    if (this.busyPayment) return "Preparing the payment…";
    if (this.busyCustomer) return "Saving customer details…";
    return null;
  }

  get hasError() {
    return !!this.errorMsg;
  }

  /* MSC-163: the banner's close control */
  handleDismissError() {
    this.errorMsg = undefined;
  }

  /* MSC-166: the same for the other two banners */
  handleDismissKycLink() {
    this.kycLinkMsg = undefined;
  }

  handleDismissComplianceWarning() {
    this.complianceWarning = undefined;
  }

  /**
   * 1.x+22 UI-29: MODON's sentence names the first person not yet sent. After a submission
   * and the re-read, the banner goes once that person (or everybody) reads as sent.
   * The sentence itself is MODON's and is shown as written.
   */
  settleComplianceWarning() {
    const warning = this.complianceWarning;
    if (!warning) {
      return;
    }
    const people = this.compliancePeople();
    if (!people.length) {
      return;
    }
    const match = /:\s*(.+?)\s+is not submitted/i.exec(warning);
    const named = match ? people.filter((p) => p.name === match[1].trim()) : [];
    const cleared = named.length
      ? named.every((p) => p.sent)
      : people.every((p) => p.sent);
    if (cleared) {
      this.complianceWarning = undefined;
    }
  }

  /** Everyone MODON's check reads (the customer, then each joint owner), from the last read. */
  compliancePeople() {
    const out = [];
    const parties = (this.owners && this.owners.parties) || [];
    if (this.isOrganisationCustomer) {
      const co = (this.compliance || {}).company;
      if (co) {
        out.push({ name: co.name, sent: co.submitted === true });
      }
    } else if (!parties.some((p) => p.isPrimary === true) && this.compliance) {
      out.push({ name: null, sent: this.compliance.submitted === true });
    }
    parties.forEach((p) => {
      if (this.isOrganisationCustomer && p.isPrimary === true) {
        return;
      }
      out.push({ name: p.name, sent: p.complianceSubmitted === true });
    });
    return out;
  }

  /** Nationality options from the schema, through the same call the customer picker uses. */
  @track nationalityValues = [];

  get nationalityOptions() {
    return this.nationalityValues;
  }

  async loadNationalities() {
    if (this.nationalityValues.length) return;
    try {
      const opts = await getLeadQualifyOptions();
      this.nationalityValues = (opts && opts.nationality) || [];
    } catch (e) {
      // a missing list must not take the journey down
      this.nationalityValues = [];
    }
  }

  /* Account.LegalStructure__c */
  @track legalStructureValues = [];

  get legalStructureOptions() {
    return this.legalStructureValues;
  }

  async loadLegalStructures() {
    if (this.legalStructureValues.length) return;
    try {
      this.legalStructureValues = (await getLegalStructureOptions()) || [];
    } catch (e) {
      this.legalStructureValues = [];
    }
  }

  /* Contact.CountryOfResidence__c, restricted picklist */
  @track countryValues = [];

  get countryOptions() {
    return this.countryValues;
  }

  async loadCountryOptions() {
    if (this.countryValues.length) return;
    try {
      this.countryValues = (await getCountryOfResidenceOptions()) || [];
    } catch (e) {
      this.countryValues = [];
    }
  }
}