/**
 * SalesConsoleController - entry point for the Modon Sales Console LWR site.
 *
 * Version  Author              Date         Detail
 * 1.88     Aurelix Dev         30 Sep 2026  The summary's unit carries the booking's price (the order's amount, or the
 *                                           chosen option's), so the step bar and the summary show one price.
 * 1.87     Aurelix Dev         29 Sep 2026  Unit option: preselected only when the unit has exactly one; with
 *                                           several the rep picks one. A live order keeps its saved option.
 * 1.86     Aurelix Dev         29 Sep 2026  Direct debit preview uses MODON's maximum (largest unpaid milestone
 *                                           except the last, as derivedTerms). The compliance state reads the
 *                                           primary contact's Manual_KYC_Approval__c.
 * 1.85     Aurelix Dev         29 Sep 2026  MODON's refusals (engine sentences, validation rule errors) reach the
 *                                           rep word for word (modonsWords, dmlWords). Ledger fee rows carry
 *                                           payByLink.
 * 1.84     Aurelix Dev         29 Sep 2026  Booking fee by payment link behind BOOKING_FEE_BY_LINK
 *                                           (AurelixBookingFeeLink); the unit is reserved while held
 *                                           (AurelixUnitReservation); no release while a link is live.
 * 1.83     Aurelix Dev         29 Sep 2026  First unit option preselected for the rep; a live order keeps its
 *                                           saved option (savedOptionOf).
 * 1.82     Aurelix Dev         29 Sep 2026  The KYC refusal on money is MODON's checkKYCEligibility sentence as is.
 * 1.81     Aurelix Dev         29 Sep 2026  No booking fee until an EOI is chosen for a unit on an EOI phase.
 *                                           cancelPaymentHold releases a live or lapsed hold while nothing is paid.
 * 1.80     Aurelix Dev         29 Sep 2026  Live-order filters use MODON's full cancelled status list
 *                                           (deadOrderStatuses); saleClosed calls AurelixSaleClosed.
 * 1.79     Aurelix Dev         29 Sep 2026  Unit options listed and priced as the Sales App does, including its
 *                                           Wadeem rule; unitOptionGuard checks the same list; the plan mapping
 *                                           price is used only for Modon Egypt users.
 * 1.78     Aurelix Dev         28 Sep 2026  THE SUMMARY KNOWS THE SALE HAS CLOSED (SCW-211). MODON's flow
 *                                           Sales_Order_Record_Triggered_Flow closes a sale by setting the
 *                                           opportunity Closed Won and the unit Sold; it never moves
 *                                           SalesOrder__c.Status__c, which stays New, so the side summary's chip
 *                                           read "Booking started" on a sold booking (SO-15561). buildSummary now
 *                                           sets BookingSummaryDTO.saleClosed (saleClosed): the order is still
 *                                           New or In Progress, its unit is Sold, and its opportunity is Closed
 *                                           Won or its gate (SalesTeamVoidCheck__c) is met. Closed Won alone is
 *                                           not enough: a basket's opportunity closes with its first order. Every
 *                                           other status keeps its own label. stage and subStage are unchanged.
 * 1.77     Aurelix Dev         27 Sep 2026  THE SALES APP'S BOOKING RULES (business confirmed, 27 Sep: the console must
 *                                           behave as MODON's Sales App does; audit of unitSearchLwc against this class).
 *                                           (1) A resumed booking no longer falls back to Opportunity.Unit__c,
 *                                           which the Sales App never reads (only the fee sync writes it and
 *                                           nothing clears it); 74 open DEV opportunities pointed at Sold,
 *                                           Reserved or other unbookable units; nor does the grid's opening phase
 *                                           (journeyUnitFor). (2) checkUnitStatus, which the
 *                                           Sales App runs at Book Unit/s, Proceed and Generate, now runs before
 *                                           a fee and before both confirm routes (unitStatusGuard). (3) A unit
 *                                           option is required where the unit or its phase has any, as the Sales
 *                                           App requires ("Unit option is not selected for X unit."), and the
 *                                           Sales Order is priced as the Sales App prices it (salesAppPrice): the
 *                                           option's total, else the plan's UnitPaymentPlanMapping__c base price,
 *                                           else the unit's price, in the plan's currency. The summary quotes the
 *                                           same price before Confirm (getBookingSummaryWithOption). (4) An EOI
 *                                           is linked only to a unit whose phase has EOI_Required__c, as the
 *                                           Sales App only offers one there: validatedEoiMapping drops any other
 *                                           entry, and getUnitConfiguration says which units need one. (5) The
 *                                           single-unit order takes FitoutPalete__c from the unit, as the basket
 *                                           order and the Sales App do. (6) getAppliedOffers: once a booking is
 *                                           made, the offers it carries are read from its Offers_Collections__c
 *                                           rows, not re-derived (a resumed booking showed the defaults ticked).
 * 1.76     Aurelix Dev         27 Sep 2026  NO FEE LINES WHERE MODON TAKES NO FEE. reviewAndConfirm raised
 *                                           the two Booking_Fee_Line__c rows on every booking, so a phase
 *                                           without Payment_Required__c (Zone 1 in the SCW-193 test,
 *                                           SO-15559) carried an unpaid "booking fee" of AED 600,249.50
 *                                           that nobody was asked to pay. The card read "Booking fee still
 *                                           outstanding" and the side panel "ADM + Dari has not been
 *                                           received yet", while the real closing rows were the ADM invoice
 *                                           and the first milestone. MODON's own journey (unitBookingJourney
 *                                           handleConfirmBook) raises fee lines only when isPaymentRequired
 *                                           is true and otherwise books directly. Confirm now does the same.
 *                                           For bookings that already carry such lines, buildSettlement and
 *                                           buildBuckets leave them out while nothing has been paid on them
 *                                           (feeLinesApply), so the closing obligations are read instead.
 * 1.75     Aurelix Dev         27 Sep 2026  In step with MODON's booking engine 17.0 and 19.0 (MODON
 *                                           confirmed 26 Sep). (1) FACADE STYLE: the booking now sends
 *                                           the style the rep picks, per unit, for a phase with
 *                                           Facade_Style__c; beginPayment refuses to take a fee when
 *                                           that phase has no style chosen, in the engine's own
 *                                           words, since saveSalesOrder would refuse the booking
 *                                           after the money was taken. The single unit builder now
 *                                           defaults FacadeStyle__c from the unit as the basket one
 *                                           and the Sales App already do. (2) PRE-APPROVAL NUMBER:
 *                                           UnitLine and ConfirmRequest carry preApprovalNumber
 *                                           into SalesOrder__c.Pre_Approval_Number__c, and
 *                                           getBookingEois returns each EOI's number, so the journey
 *                                           can show it or ask for one on a pre-approval (ADIB) plan.
 *                                           The engine stays the authority: it uses the EOI's number
 *                                           when there is one, requires the typed one otherwise on a
 *                                           pre-approval plan, and clears it on a normal plan.
 * 1.74     Aurelix Dev         22 Sep 2026  Booking fee with an EOI, behind the switch EOI_SKIPS_BOOKING_FEE
 *                                           (AurelixEoiBookingFee, off by default). When on, a one unit
 *                                           booking whose unit carries an EOI with a cleared receipt takes no
 *                                           booking fee: no fee lines, no terminal payment, straight to
 *                                           saveSalesOrder with the EOI mapping, as the Sales App books it.
 *                                           getBookingFeeNeed tells the page; reviewAndConfirm applies the
 *                                           same rule (eoiCoversFee). Switch off: nothing changes.
 * 1.73     Aurelix Dev         22 Sep 2026  In step with MODON's 21 Sep changes. (1) The engine's own bedrooms
 *                                           compare (UnitSearchLwcController.bedroomsMatch, v16.0): digits only,
 *                                           so "5 BR" matches "5"; with no digit on either side, trimmed text in
 *                                           any case (sameBedrooms). (2) An EOI receipt is spendable again once
 *                                           its Sales Order is Cancelled or Voided, as the engine's
 *                                           isReceiptFree (v16.2) says; EoiReadContext priced only receipts
 *                                           with no order at all (receiptIsFree). (3) Direct debit: the bank
 *                                           list is DirectDebitRequest__c.UAEDDSBankName__c, the field MODON's
 *                                           createMandateRecord reads since UAEDDS_LWCController 2.2 (it no
 *                                           longer reads Customer_Bank_Name__c, so the rep's bank was dropped);
 *                                           the prefilled bank is matched to that picklist the way MODON's
 *                                           knownBank does, or left blank. (4) MODON's answer to D7: a
 *                                           company pays from the Sales Order's Primary Contact, so
 *                                           ddPrefillFor seeds name, Emirates ID, mobile and e-mail from that
 *                                           contact (payerIsContact); the rep types the bank. Still behind
 *                                           DIRECT_DEBIT_ORGANISATION. Previous version:
 *                                           _backup/2026-09-22_081155 (WL-019).
 * 1.72     Aurelix Dev         21 Sep 2026  The EOI match is on bedrooms only (MODON's answer to open question 9,
 *                                           21 Sep: "Both EOI and Unit Bedrooms should match"). Typology cannot
 *                                           be matched as the data stands: EOIs say "Range Villas", "Select
 *                                           Villas", "Par 3" or nothing, units say "Range Villa", "Golf
 *                                           Townhomes". matchesEoi compares bedrooms alone, the refusal is
 *                                           "EOI Bedrooms Mismatch" (one helper, bedroomsRefusal), and the gate
 *                                           no longer reads Typology__c. Still behind EOI_Enforce_Typology_Check
 *                                           and the opportunity bypass, so nothing changes while the label is
 *                                           'false'. unitSearchLwc needs the same change before MODON sets the
 *                                           label to 'true'. Previous version:
 *                                           _backup/2026-09-21_233502 (WL-017).
 * 1.71     Aurelix Dev         21 Sep 2026  The retired eligibility check is no longer called, as in the Sales
 *                                           App (business confirmed, 21 Sep). UnitSearchLwcController.checkBookingEligibility
 *                                           (MODON v13.0) blocked on an Opportunity / Account nationality or
 *                                           residency mismatch and on a missing address, nationality or
 *                                           residency; unitSearchLwc v15.0 (2 Sep) stopped calling it and moved
 *                                           the nationality requirement into checkKYCEligibility (Check 2A).
 *                                           Removed: the calls in buildConsoleState, reviewAndConfirm and the
 *                                           multi-unit confirm, and their message helpers
 *                                           (preciseEligibilityMessage, consoleEligibilityMessage, humanJoin).
 *                                           KYC still gates every money and confirm path on the server
 *                                           (assertKycEligibleForMoney). eligibilityBlocked now means only that
 *                                           the opportunity could not be read. Previous version:
 *                                           Backup_2026-09-21/run-2032 (SCW-137).
 * 1.70     Aurelix Dev         21 Sep 2026  P8. Refusals reach the rep in the console's words: MODON's
 *                                           "...for this opportunity" and "...the Primary Contact" are
 *                                           rewritten to booking and customer by consoleWording, applied
 *                                           in refusal() and at the end of friendly(). lastRawError keeps
 *                                           the original. The EOI gate's sentences are left untouched -
 *                                           they are the Sales App's own.
 * 1.69     Aurelix Dev         21 Sep 2026  MODON's EOI booking gates, mirrored from the staff app
 *                                           (unitSearchLwc, "EOI v2.1"): phase EOI_Required__c /
 *                                           EOI_Strict_Required__c, the typology+bedroom match behind
 *                                           EOI_Enforce_Typology_Check and the opportunity bypass, the
 *                                           units-versus-EOIs count, and one EOI per unit. MODON runs
 *                                           them in that component; saveSalesOrder keeps one safety net
 *                                           (a required phase with no mapping) and none of the rest - so
 *                                           the console carries its own copy, server-side:
 *                                           checkEoiGate for the Continue button, and the same rule
 *                                           inside beginPayment and both reviewAndConfirm routes. Same
 *                                           order, same conditions, same wording as the Sales App
 *                                           (MODON confirmed, 21 Sep). BookingEoiResult gains
 *                                           enforceTypology so auto-assignment picks only a matching EOI
 *                                           when the label asks for it.
 * 1.68     Aurelix Dev         18 Sep 2026  SCW-125. Direct debit re-based on MODON's UAEDDS build.
 *                                           submitDirectDebitMandate no longer inserts a status-less
 *                                           DirectDebitRequest__c: the console's gates run here
 *                                           (KYC, standing mandate, cheques, order status,
 *                                           residency, organisation) and the Draft is raised through
 *                                           AurelixDirectDebitService.createDraft, i.e. MODON's own
 *                                           UAEDDS_LWCController.createMandateRecord (record type
 *                                           UAEDDS, Status Draft, e-mail, city, + 548-day expiry).
 *                                           getDirectDebitState reads the card from the same
 *                                           service; the DTO keeps its shape and gains `card`,
 *                                           `stage`, `slotFree`, `problems`. The slot rule is
 *                                           MODON's DEAD_STATUSES (Discarded and Rejected free
 *                                           the order - 1.41 treated both as standing).
 *                                           MilestoneBatchDTO.directDebitReason says why the option
 *                                           is not offered. Prefill carries e-mail, city, bank and
 *                                           IBAN from the Account; the computed line quotes + 548.
 * 1.67     Aurelix Dev         02 Sep 2026  MSC-213. The unit grid opens where THIS rep can book.
 *                                           defaultPhase's doc always said "first phase with
 *                                           stock"; the code took the first row, and every stock
 *                                           signal was org-wide - but the grid filters to units
 *                                           the rep holds edit access on (OWD Private buckets),
 *                                           so a defaulted open landed on "No units are assigned
 *                                           to you" whenever the auto-pick missed their bucket.
 *                                           firstBookablePhase picks by Available + not-held +
 *                                           HasEditAccess (memoised, capped); a fully-defaulted
 *                                           open retargets to a bookable project. An explicit
 *                                           project/phase choice and the booked-unit branch are
 *                                           untouched.
 * 1.66     Aurelix Dev         01 Sep 2026  MSC-205. Cheque guards a bank would apply: refuse a
 *                                           cheque older than six months (stale in the UAE) or
 *                                           dated an implausible ten years ahead, and refuse a
 *                                           cheque number already live on ANY of the customer's
 *                                           bookings, not only this one. The read DTO carries
 *                                           wordsAmount so the screen can flag words vs figures.
 * 1.65     Aurelix Dev         01 Sep 2026  MSC-200. isChequeReadOn(): the cheque screens lock
 *                                           their fields to the read, and must know before a
 *                                           file is attached whether reading is switched on.
 * 1.64     Aurelix Dev         01 Sep 2026  MSC-197. The cheque read reaches the main screen:
 *                                           InstrumentDTO carries what the image said about a
 *                                           recorded cheque, and recordProofPayment accepts the
 *                                           read the console already has so the cheque is read
 *                                           once, not twice.
 * 1.63     Aurelix Dev         01 Sep 2026  MSC-196. Cheque OCR at capture time: the read is given
 *                                           100s (a real read takes ~28s; 30s cut most of them
 *                                           off), it says WHY it could not read instead of
 *                                           returning null, and it hands back everything the
 *                                           model found, not four fields of eight.
 * 1.62     Aurelix Dev         30 Aug 2026  MSC-181. Wording: link gap fallback says 'a Power of Attorney'.
 * 1.61     Aurelix Dev         24 Aug 2026  MSC-165. Take payment refuses a unit held at another rep's
 *                                           terminal (covers a null-expiry hold); own hold still allowed.
 * 1.60     Aurelix Dev         24 Aug 2026  MSC-164. Units on a live payment hold dropped from the grid
 *                                           and its counts, for the holder too. Expired hold is not a hold.
 * 1.59     Aurelix Dev         23 Aug 2026  MSC-153. beginPayment / reviewAndConfirm refuse a unit or plan
 *                                           different from the one money was collected against.
 * 1.58     Aurelix Dev         23 Aug 2026  MSC-151. ComplianceStateDTO.nextStep for corporate bookings.
 * 1.57     Aurelix Dev         23 Aug 2026  MSC-149. Signatory track reads the link state off the Contact.
 * 1.56     Aurelix Dev         23 Aug 2026  MSC-148. Corporate branch reads SalesConsoleOrgController.missingForLink.
 * 1.49     Aurelix Dev         22 Aug 2026  MSC-121. A recorded payment comes off what is still due;
 *                                           the invoice gate only caps it. Write path unchanged.
 * 1.48     Aurelix IT          22 Aug 2026  MSC-115. getComplianceState carries the company and
 *                                           signatory tracks (Account.Passfort*__c, Contact twins).
 * 1.47     Aurelix IT          22 Aug 2026  MSC-113. companyUpdate billing arm retired; saveAddress works
 *                                           for an organisation; realBeneficiary; 'licence number' wording.
 * 1.46     Aurelix IT          22 Aug 2026  MSC-112. Customer card read/write: branch-correct identity,
 *                                           document dates, masked values, lockReasons, write policy.
 * 1.45     Aurelix IT          20 Aug 2026  MSC-083. ensureComplianceDocSlots takes a party.
 * 1.44     Aurelix IT          19 Aug 2026  MSC-069. requiredComplianceDocNames public; open
 *                                           PassfortTransaction__c counts as submitted.
 * 1.43     Aurelix Developer   19 Aug 2026  Sending the KYC link no longer holds the journey.
 * 1.42     Aurelix Developer   19 Aug 2026  recordProofPayment writes the Receipt__c as Create Payment does;
 *                                           rows carry every live payment; deleteProofSlot.
 * 1.41     Aurelix Developer   18 Aug 2026  Milestone box: cheque batch, direct debit mandate,
 *                                           FinanceReadContext, LedgerWriteContext.
 * 1.40     Aurelix Developer   17 Aug 2026  ADM + Dari charge row from Invoice__c (BUCKET_ADM_CHARGE).
 * 1.39     Aurelix Developer   17 Aug 2026  One Sales Order is one booking: getConsoleStateForOrder,
 *                                           focusedSalesOrderId, bookingUnitCount.
 * 1.38     Aurelix Developer   17 Aug 2026  buildSummary takes a list (basket); units/plans lists.
 * 1.37     Aurelix Developer   17 Aug 2026  Pay-first counts the orders (basket takes no fee).
 * 1.36     Aurelix Developer   17 Aug 2026  SettlementDTO.confirmedOn / bookingReference.
 * 1.35     Aurelix Developer   17 Aug 2026  PaymentBucketDTO.payRoute / paymentRequired.
 * 1.34     Aurelix Developer   17 Aug 2026  furtherDocumentsRequired no longer forced; bookingConfirmed;
 *                                           ConsoleState.bookedUnits.
 * 1.33     Aurelix Developer   17 Aug 2026  SettlementDTO.isBookingFee.
 * 1.32     Aurelix Developer   17 Aug 2026  getRequiredDocuments: Sales items only, rest in laterItems.
 * 1.31     Aurelix Developer   16 Aug 2026  closesSale, remainingAmount, proofRequired; planHasSchedule.
 * 1.31     Aurelix Dev         03 Sep 2026  MSC-231 (W5). Booking against the EOI: getBookingEois
 *                                           (org getCompletedEOIs + deposit amounts + phase gate),
 *                                           eoiMappingJson on ConfirmRequest validated and passed
 *                                           to saveSalesOrder (was null), EOI deposit rows on the
 *                                           settlement (post-confirm, from the org's own receipts).
 * 1.30     Aurelix Developer   16 Aug 2026  getSettlement: one figure and the two closing legs.
 * 1.27     Aurelix Developer   16 Aug 2026  getUnitPlanFees.
 * 1.26     Aurelix Developer   16 Aug 2026  getSitePathPrefix reads Network.UrlPathPrefix first.
 * 1.25     Aurelix Developer   16 Aug 2026  getSitePathPrefix falls back to the Network record.
 * 1.24     Aurelix Developer   16 Aug 2026  getSitePathPrefix for the offer preview frame.
 * 1.23     Aurelix IT          13 Aug 2026  Basket is payable: buckets and offers cover every order.
 * 1.22     Aurelix IT          13 Aug 2026  sendOffer / getOrgUrl.
 * 1.21     Aurelix IT          13 Aug 2026  Offers and discounts passed to saveSalesOrder.
 * 1.20     Aurelix IT          13 Aug 2026  uploadProofImage (camera capture).
 * 1.19     Aurelix IT          13 Aug 2026  Hold countdown; KYC send success; fit-out and facade on the order.
 * 1.18     Aurelix IT          13 Aug 2026  Plan read back from fee lines; hold and lines are one action.
 * 1.17     Aurelix IT          12 Aug 2026  getConsoleState returns the resume step.
 * 1.16     Aurelix IT          12 Aug 2026  Unit browser offers only editable units.
 * 1.15     Aurelix IT          12 Aug 2026  CustomerBlock.firstName / lastName.
 * 1.14     Aurelix IT          12 Aug 2026  beginPayment raises fee lines before the hold; getPaymentHoldMinutes.
 * 1.13     Aurelix IT          12 Aug 2026  isPaymentRequired asked when it can be answered.
 * 1.12     Aurelix IT          12 Aug 2026  saveAddress, the console's own address write.
 * 1.11     Aurelix IT          12 Aug 2026  Eligibility messages reworded for this journey.
 * 1.10     Aurelix IT          11 Aug 2026  getUnitBrowser: one round trip.
 * 1.9      Aurelix IT          11 Aug 2026  Billing postal code.
 * 1.8      Aurelix IT          11 Aug 2026  Masked contact details for an existing customer.
 * 1.7      Aurelix IT          10 Aug 2026  Organisation customers.
 * 1.6      Aurelix IT          09 Aug 2026  getRequiredDocuments typed and merged with approval state.
 * 1.5      Aurelix IT          09 Aug 2026  Masterplan_URL__c on UnitBlock.
 * 1.4      Aurelix IT          09 Aug 2026  Resume lookup isolated so getConsoleState degrades, not fails.
 * 1.3      Aurelix IT          07 Aug 2026  Multi-unit booking via saveSalesOrder, no payment.
 * 1.2      Aurelix IT          06 Aug 2026  On-demand compliance refresh.
 * 1.1      Aurelix IT          06 Aug 2026  Identity verification and compliance.
 * 1.0      Aurelix IT          05 Aug 2026  Initial. Single-page booking journey.
 */
public with sharing class SalesConsoleController {

    /** Booking_Fee_Line__c.Type__c values (Booking_Fee_Line_Type global value set). */
    private static final String FEE_TYPE_ADM = 'ADM & Dari';
    private static final String FEE_TYPE_DOWN = 'Down Payment';

    /** Payment bucket keys. The bucket is the upload boundary. */
    public static final String BUCKET_DOWN = 'DOWN_PAYMENT';
    public static final String BUCKET_ADM = 'ADM_REGISTRATION_FEE';
    public static final String BUCKET_MILESTONE = 'MILESTONE';
    /* the ADM + Dari charge invoice, as distinct from BUCKET_ADM (the deposit toward it) */
    public static final String BUCKET_ADM_CHARGE = 'ADM_DARI_CHARGE';

    /* PaymentBucketDTO.payRoute */
    public static final String ROUTE_TERMINAL = 'TERMINAL';
    public static final String ROUTE_PROOF = 'PROOF';

    /** Documents__c.Payment_Proof_Type__c values; restricted picklist, must match exactly. */
    private static final Map<String, String> PROOF_TYPE_BY_BUCKET = new Map<String, String>{
        BUCKET_DOWN => 'Down Payment',
        BUCKET_ADM => 'ADM Registration Fee',
        BUCKET_MILESTONE => 'Milestone Payment',
        BUCKET_ADM_CHARGE => 'ADM Registration Fee'
    };

    /* display labels, not the picklist values */
    private static final String LABEL_ADM_DARI = 'ADM + Dari';
    private static final String LABEL_DOWN_PAYMENT = 'Down Payment';

    /* Receipt__c.Status__c values after which a cheque no longer counts against its milestone.
       'In Progress' is applied but not paid: AppliedAmount__c moves at once, TotalPaidAmount__c
       only when Finance approves, so the open amount for a new cheque is InvoiceAmount - AppliedAmount. */
    private static final Set<String> RECEIPT_DEAD = new Set<String>{
        'Rejected', 'Cancelled', 'Reversed', 'Bounced', 'Returned', 'Returned to customer'
    };
    private static final String RECEIPT_IN_PROGRESS = 'In Progress';
    private static final String MOP_CHEQUE = 'Cheque';
    /* Receipt__c.Modeofpayment__c values a rep can record from a proof. Cheque for Residents only;
       Direct Debit is a mandate for the schedule, never a row method. */
    private static final String MOP_BANK_TRANSFER = 'Bank Transfer';
    private static final String MOP_POS = 'POS';
    private static final String MOP_ONLINE = 'Online';
    private static final List<String> PROOF_MODES = new List<String>{ MOP_BANK_TRANSFER, MOP_POS, MOP_ONLINE };
    private static final String CONSOLE_RECEIPT_REMARK = 'Recorded in the Sales Console';
    private static final String CHEQUE_REGISTER_PROCESSED = 'Processed';
    /* 1.68: the slot and covering rules moved to AurelixDirectDebitService (MODON's DEAD_STATUSES);
       these three are kept only so older readers of this file find the names. Not consulted. */
    private static final Set<String> DD_UNIQUENESS_EXCLUDED = new Set<String>{ 'Cancelled', 'Rejected By Bank' };
    private static final Set<String> DD_NOT_COVERING = new Set<String>{ 'Cancelled', 'Rejected', 'Rejected By Bank' };
    private static final String DD_REQUEST_TYPE_NEW = 'New Registration';
    private static final String ID_TYPE_EID = 'UAE Emirates Identity Card';
    private static final String ID_TYPE_TRADE_LICENCE = 'Trade Licence Number';
    /** 1.73: the Sales Order statuses that free an EOI receipt again (the engine's DEAD_SO_STATUSES). */
    private static final Set<String> RECEIPT_FREEING_ORDER_STATUSES = new Set<String>{ 'Cancelled', 'Voided' };
    /* not offered per row for milestones after the down payment: the box owns them */
    private static final Set<String> BOX_ROUTES = new Set<String>{ 'Cheque', 'Direct Debit' };

    /**
     * Resident status vocabulary. DocumentChecklistController compares these as raw strings and
     * silently returns the full checklist for anything else; never pass a KYC_Response__c value.
     */
    private static final String RESIDENT = 'Resident';
    private static final String NON_RESIDENT = 'Non-Resident';
    /* matches SalesConsoleLeadController's equalsIgnoreCase test */
    private static final String INDIVIDUAL = 'Individual';
    private static final String ORGANISATION = 'Organisation';

    // Elevated read island

    /**
     * Read-only finance aggregation. Sales profiles cannot see Receipt__c or Allocation__c.
     * No DML here; write in the outer with-sharing context.
     */
    private without sharing class FinanceReadContext {

        /** Collected-to-date per SalesOrderInstallments__c id. */
        public Map<Id, Decimal> paidByInstallment(Set<Id> installmentIds) {
            Map<Id, Decimal> out = new Map<Id, Decimal>();
            if (installmentIds == null || installmentIds.isEmpty()) {
                return out;
            }
            for (SalesOrderInstallments__c soi : [
                SELECT Id, InstallmentAmount__c, Balance_Amount__c
                FROM SalesOrderInstallments__c
                WHERE Id IN :installmentIds
            ]) {
                Decimal amount = soi.InstallmentAmount__c == null ? 0 : soi.InstallmentAmount__c;
                Decimal balance = soi.Balance_Amount__c == null ? amount : soi.Balance_Amount__c;
                Decimal paid = amount - balance;
                out.put(soi.Id, paid < 0 ? 0 : paid);
            }
            return out;
        }

        /**
         * ADM + Dari charge invoice per Sales Order (one flagged invoice per order; cancelled ones
         * ignored, oldest kept). Read here so Invoice__c sharing cannot blank the ledger.
         */
        public Map<Id, Invoice__c> admChargeBySalesOrder(Set<Id> salesOrderIds) {
            Map<Id, Invoice__c> out = new Map<Id, Invoice__c>();
            if (salesOrderIds == null || salesOrderIds.isEmpty()) {
                return out;
            }
            for (Invoice__c inv : [
                SELECT Id, Name, Sales_Order__c, InvoiceAmount__c, TotalPaidAmount__c,
                       InvoiceBalance__c, InvoiceDate__c, Status__c,
                       AppliedAmount__c, Charge__c,
                       Sales_Order__r.Unit__r.Name
                FROM Invoice__c
                WHERE Sales_Order__c IN :salesOrderIds
                  AND Is_ADM_Fees_and_Dari_charges__c = true
                  AND isCancelled__c = false
                ORDER BY CreatedDate ASC
            ]) {
                if (!out.containsKey(inv.Sales_Order__c)) {
                    out.put(inv.Sales_Order__c, inv);
                }
            }
            return out;
        }

        /* cheques standing against each installment, newest first, dead statuses excluded */
        public Map<Id, List<Receipt__c>> chequesByInstallment(Set<Id> installmentIds) {
            Map<Id, List<Receipt__c>> out = new Map<Id, List<Receipt__c>>();
            if (installmentIds == null || installmentIds.isEmpty()) {
                return out;
            }
            for (Receipt__c r : [
                SELECT Id, Name, Modeofpayment__c, Status__c, PaymentStatus__c,
                       TotalAmount__c, Receipt_Amount__c, TransactionNumber__c,
                       Cheque_Number__c, ChequeDate__c, Bank__c, BankName__c,
                       ReceiptDate__c, CreatedDate, CreatedBy.Name,
                       SalesOrderInstallment__c, Cheque_Details__c,
                       (SELECT ContentDocumentId, ContentDocument.Title,
                               ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLinks
                        ORDER BY SystemModstamp DESC LIMIT 1)
                FROM Receipt__c
                WHERE SalesOrderInstallment__c IN :installmentIds
                  AND Modeofpayment__c = :MOP_CHEQUE
                  AND Status__c NOT IN :RECEIPT_DEAD
                ORDER BY CreatedDate DESC
            ]) {
                if (!out.containsKey(r.SalesOrderInstallment__c)) {
                    out.put(r.SalesOrderInstallment__c, new List<Receipt__c>());
                }
                out.get(r.SalesOrderInstallment__c).add(r);
            }
            return out;
        }

        /* every live payment (any mode) against each installment; chequesByInstallment stays for
         * the box's cheque-only questions */
        public Map<Id, List<Receipt__c>> receiptsByInstallment(Set<Id> installmentIds) {
            Map<Id, List<Receipt__c>> out = new Map<Id, List<Receipt__c>>();
            if (installmentIds == null || installmentIds.isEmpty()) {
                return out;
            }
            for (Receipt__c r : [
                SELECT Id, Name, Modeofpayment__c, Status__c, PaymentStatus__c,
                       TotalAmount__c, Receipt_Amount__c, TransactionNumber__c,
                       Cheque_Number__c, ChequeDate__c, TransactionDate__c, Bank__c, BankName__c,
                       ReceiptDate__c, CreatedDate, CreatedBy.Name,
                       SalesOrderInstallment__c, Cheque_Details__c,
                       (SELECT ContentDocumentId, ContentDocument.Title,
                               ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLinks
                        ORDER BY SystemModstamp DESC)
                FROM Receipt__c
                WHERE SalesOrderInstallment__c IN :installmentIds
                  AND Status__c NOT IN :RECEIPT_DEAD
                ORDER BY CreatedDate DESC
            ]) {
                if (!out.containsKey(r.SalesOrderInstallment__c)) {
                    out.put(r.SalesOrderInstallment__c, new List<Receipt__c>());
                }
                out.get(r.SalesOrderInstallment__c).add(r);
            }
            return out;
        }

        /* payments against each order's ADM + Dari charge (Create_Receipt_SO shape, no installment) */
        public Map<Id, List<Receipt__c>> admReceiptsBySalesOrder(Set<Id> salesOrderIds) {
            Map<Id, List<Receipt__c>> out = new Map<Id, List<Receipt__c>>();
            if (salesOrderIds == null || salesOrderIds.isEmpty()) {
                return out;
            }
            for (Receipt__c r : [
                SELECT Id, Name, Modeofpayment__c, Status__c, PaymentStatus__c,
                       TotalAmount__c, Receipt_Amount__c, TransactionNumber__c,
                       Cheque_Number__c, ChequeDate__c, TransactionDate__c, Bank__c, BankName__c,
                       ReceiptDate__c, CreatedDate, CreatedBy.Name,
                       SalesOrder__c, Cheque_Details__c,
                       (SELECT ContentDocumentId, ContentDocument.Title,
                               ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLinks
                        ORDER BY SystemModstamp DESC)
                FROM Receipt__c
                WHERE SalesOrder__c IN :salesOrderIds
                  AND SalesOrderInstallment__c = null
                  AND Is_ADM_Fees_and_Dari_charges__c = true
                  AND Status__c NOT IN :RECEIPT_DEAD
                ORDER BY CreatedDate DESC
            ]) {
                if (!out.containsKey(r.SalesOrder__c)) {
                    out.put(r.SalesOrder__c, new List<Receipt__c>());
                }
                out.get(r.SalesOrder__c).add(r);
            }
            return out;
        }

        /* references already on a live payment of this order, upper-cased and trimmed, for the
         * duplicate check */
        public Set<String> liveReferencesFor(Id salesOrderId) {
            Set<String> out = new Set<String>();
            if (salesOrderId == null) {
                return out;
            }
            for (Receipt__c r : [
                SELECT TransactionNumber__c, Cheque_Number__c
                FROM Receipt__c
                WHERE (SalesOrder__c = :salesOrderId
                       OR SalesOrderInstallment__r.SalesOrder__c = :salesOrderId)
                  AND Status__c NOT IN :RECEIPT_DEAD
            ]) {
                if (String.isNotBlank(r.TransactionNumber__c)) out.add(r.TransactionNumber__c.trim().toUpperCase());
                if (String.isNotBlank(r.Cheque_Number__c)) out.add(r.Cheque_Number__c.trim().toUpperCase());
            }
            return out;
        }

        /* proof slots being submitted; read elevated so another user's slot on this booking counts */
        public List<Documents__c> proofSlots(Set<Id> documentIds) {
            if (documentIds == null || documentIds.isEmpty()) {
                return new List<Documents__c>();
            }
            return [
                SELECT Id, SalesOrder__c, Booking_Fee_Line__c, Sales_Order_Installment__c,
                       Invoice__c, Receipt__c, Status__c, Payment_Proof_Type__c,
                       (SELECT ContentDocumentId FROM ContentDocumentLinks)
                FROM Documents__c
                WHERE Id IN :documentIds
            ];
        }

        /* live invoice per installment (Invoice__c.SalesOrderInstallment__c); oldest kept */
        public Map<Id, Invoice__c> invoiceByInstallment(Set<Id> installmentIds) {
            Map<Id, Invoice__c> out = new Map<Id, Invoice__c>();
            if (installmentIds == null || installmentIds.isEmpty()) {
                return out;
            }
            for (Invoice__c inv : [
                SELECT Id, Name, SalesOrderInstallment__c, InvoiceAmount__c,
                       AppliedAmount__c, TotalPaidAmount__c, InvoiceBalance__c
                FROM Invoice__c
                WHERE SalesOrderInstallment__c IN :installmentIds
                  AND isCancelled__c = false
                ORDER BY CreatedDate ASC
            ]) {
                if (!out.containsKey(inv.SalesOrderInstallment__c)) {
                    out.put(inv.SalesOrderInstallment__c, inv);
                }
            }
            return out;
        }

        /* cheque numbers already standing on an order (both fields), for the batch duplicate check */
        public Set<String> liveChequeNumbersFor(Id salesOrderId) {
            Set<String> out = new Set<String>();
            if (salesOrderId == null) {
                return out;
            }
            for (Receipt__c r : [
                SELECT TransactionNumber__c, Cheque_Number__c
                FROM Receipt__c
                WHERE (SalesOrder__c = :salesOrderId
                       OR SalesOrderInstallment__r.SalesOrder__c = :salesOrderId)
                  AND Modeofpayment__c = :MOP_CHEQUE
                  AND Status__c NOT IN :RECEIPT_DEAD
            ]) {
                if (String.isNotBlank(r.TransactionNumber__c)) out.add(r.TransactionNumber__c.trim().toUpperCase());
                if (String.isNotBlank(r.Cheque_Number__c)) out.add(r.Cheque_Number__c.trim().toUpperCase());
            }
            return out;
        }

        /* cheques against milestones after the down payment: the mandate exclusivity question */
        public Integer liveChequeCountAfterDownPayment(Id salesOrderId) {
            if (salesOrderId == null) {
                return 0;
            }
            return [
                SELECT COUNT()
                FROM Receipt__c
                WHERE SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
                  AND SalesOrderInstallment__r.MilestoneNumber__c > 1
                  AND Modeofpayment__c = :MOP_CHEQUE
                  AND Status__c NOT IN :RECEIPT_DEAD
            ];
        }

        /* which receipts got their allocation; ReceiptTriggerHelper swallows its own DML failure */
        public Set<Id> receiptsWithAllocation(Set<Id> receiptIds) {
            Set<Id> out = new Set<Id>();
            if (receiptIds == null || receiptIds.isEmpty()) {
                return out;
            }
            for (Allocation__c a : [
                SELECT Receipt__c FROM Allocation__c
                WHERE Receipt__c IN :receiptIds AND Status__c = 'Applied'
            ]) {
                out.add(a.Receipt__c);
            }
            return out;
        }

        /* the mandate standing on an order, newest first; elevated because Sales Management has no
         * access to DirectDebitRequest__c */
        public DirectDebitRequest__c mandateFor(Id salesOrderId, Set<String> ignoredStatuses) {
            if (salesOrderId == null) {
                return null;
            }
            List<DirectDebitRequest__c> found = [
                SELECT Id, Name, Status__c, Approve__c, Commences_On__c, Expires_On__c,
                       Maximum_Amount__c, Customer_Bank_Account_Name__c,
                       Customer_Bank_Name__c, Customer_Bank_Account_Type__c,
                       Customer_IBAN_Number__c, Customer_Id_Type__c, Customer_ID_Number__c,
                       Customer_Mobile__c, CreatedDate
                FROM DirectDebitRequest__c
                WHERE SalesOrder__c = :salesOrderId
                  AND Status__c NOT IN :ignoredStatuses
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return found.isEmpty() ? null : found[0];
        }

        /* 1.81 - a paid amount, an allocation of any status, or a receipt on this unit's fee lines */
        public Boolean moneyOnFeeLines(Id opportunityId, Id unitId) {
            Set<Id> lineIds = new Set<Id>();
            for (Booking_Fee_Line__c l : [
                SELECT Id, Total_Paid_Amount__c FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
            ]) {
                if (l.Total_Paid_Amount__c != null && l.Total_Paid_Amount__c > 0) {
                    return true;
                }
                lineIds.add(l.Id);
            }
            if (lineIds.isEmpty()) {
                return false;
            }
            if ([SELECT COUNT() FROM Booking_Fee_Allocation__c WHERE Booking_Fee_Line__c IN :lineIds] > 0) {
                return true;
            }
            return [SELECT COUNT() FROM Receipt__c WHERE Booking_Fee_Line__c IN :lineIds] > 0;
        }
    }

    /**
     * The one place this class writes finance records. without sharing: every write is preceded
     * by a with-sharing read of the Sales Order; the elevation covers the Receipt__c insert
     * (master-detail on Account, writeRequiresMasterRead=false). Nothing here decides anything.
     */
    private without sharing class LedgerWriteContext {
        public void insertRegisters(List<Cheque_Details__c> rows) {
            if (rows != null && !rows.isEmpty()) insert rows;
        }
        public void insertReceipts(List<Receipt__c> rows) {
            if (rows != null && !rows.isEmpty()) insert rows;
        }
        public void insertLinks(List<ContentDocumentLink> links) {
            if (links != null && !links.isEmpty()) insert links;
        }
        public void insertMandate(DirectDebitRequest__c ddr) {
            insert ddr;
        }
        /* stamp the slots with the Payment they belong to */
        public void updateSlots(List<Documents__c> slots) {
            if (slots != null && !slots.isEmpty()) update slots;
        }
        /* remove an unrecorded proof and its files */
        public void deleteSlotWithFiles(Documents__c slot, List<ContentDocument> files) {
            if (files != null && !files.isEmpty()) delete files;
            delete slot;
        }
        /* SalesOrder__c.Direct_Debit_Request__c, traversed by Modon's collection batch. Best effort:
           a Sales Order rule refusing this must not take the mandate down. */
        public String linkMandateToOrder(Id salesOrderId, Id mandateId) {
            try {
                update new SalesOrder__c(Id = salesOrderId, Direct_Debit_Request__c = mandateId);
                return null;
            } catch (Exception e) {
                return e.getMessage();
            }
        }
    }

    // DTOs

    public class ConsoleState {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id primaryContactId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String nationality;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public Boolean isPersonAccount = false;
        @AuraEnabled public Boolean eligibilityBlocked = false;
        @AuraEnabled public String eligibilityMessage;
        @AuraEnabled public String complianceMessage;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public Boolean hasExistingSalesOrder = false;
        @AuraEnabled public UnitBookingJourneyController.HeldUnit activeHold;
        @AuraEnabled public BookingSummaryDTO summary;
        @AuraEnabled public ComplianceStateDTO compliance;
        /* step to open on resume; null starts at the beginning */
        @AuraEnabled public String resumeStep;
        /* every unit this booking made, not only the one that resumes */
        @AuraEnabled public List<BookedUnitDTO> bookedUnits = new List<BookedUnitDTO>();
        /* set when getConsoleStateForOrder found the requested order live on this opportunity;
         * the client keys on this, not on how it was called */
        @AuraEnabled public Id focusedSalesOrderId;
    }

    /** One confirmed unit of a booking. */
    public class BookedUnitDTO {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        /* price, plan and state from the Sales Order, so the client can rebuild a basket it never
         * loaded (Reserved units are not in the grid; unitPlans is only written by the picker) */
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Id planId;
        @AuraEnabled public String planName;
        @AuraEnabled public String status;
        @AuraEnabled public String subStatus;
    }

    public class CustomerInput {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String nationality { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        /* identity and country of residence: Account (__pc) for a person, signatory Contact for an
           organisation, never the Opportunity */
        @AuraEnabled public String emiratesId { get; set; }
        @AuraEnabled public Date emiratesIdExpiry { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        @AuraEnabled public Date passportIssueDate { get; set; }
        @AuraEnabled public Date passportExpiry { get; set; }
        @AuraEnabled public String countryOfResidence { get; set; }
        /* AML declaration, organisation only; null means unanswered and nothing is written */
        @AuraEnabled public Boolean realBeneficiary { get; set; }
        /* company fields PassfortTransactionProcessHelper reads off the Account */
        @AuraEnabled public String customerType { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String tradeLicenceNumber { get; set; }
        @AuraEnabled public Date tradeLicenceExpiry { get; set; }
        @AuraEnabled public Date dateOfEstablishment { get; set; }
        @AuraEnabled public String legalStructure { get; set; }
        @AuraEnabled public String businessActivity { get; set; }
        @AuraEnabled public String vatNumber { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public String billingPostalCode { get; set; }
        @AuraEnabled public String billingCountry { get; set; }
        /* customerType is derived from Account.IsPersonAccount; billing* kept declared so an older
           cached payload still deserialises */
        // no-arg constructor required for LWC deserialisation
        public CustomerInput() {}
    }

    public class UnitBlock {
        @AuraEnabled public Id unitId;
        @AuraEnabled public String name;
        @AuraEnabled public String project;
        @AuraEnabled public String phase;
        @AuraEnabled public String classification;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public Decimal area;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public String status;
        /** Unit's 3D tour URL (MBP_MasterplanSyncBatch); blank means no tour. */
        @AuraEnabled public String tourUrl;
    }

    public class CustomerBlock {
        @AuraEnabled public String name;
        /* first and last name for the card's two fields */
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String nationality;
        @AuraEnabled public String residentStatus;
        /* identity documents live on the Account, not the Opportunity */
        @AuraEnabled public String emiratesId;
        @AuraEnabled public String passportNumber;
        /* existing customer display: encrypted first, masked fallback, never the plain field */
        @AuraEnabled public String maskedEmail;
        @AuraEnabled public String maskedMobile;
        /* EmiratesIDExpiryDate / PassportIssueDate / PassportExpiryDate (Account __pc or Contact __c);
           not EID_Expiry_Date__c, which is unused */
        @AuraEnabled public Date emiratesIdExpiry;
        @AuraEnabled public Date passportIssueDate;
        @AuraEnabled public Date passportExpiry;
        @AuraEnabled public String countryOfResidence;
        /* what a locked field displays; never seeds an input */
        @AuraEnabled public String maskedEmiratesId;
        @AuraEnabled public String maskedPassport;
        /* AML declaration as stored: true or null (a stored false is indistinguishable from
           never asked). Always null for a person account. */
        @AuraEnabled public Boolean realBeneficiary;
        /* edit policy: field name -> reason code (IDENTITY_SAVED | ON_FILE | RESIDENCY_SAVED |
           NAME_RULE | NO_SIGNATORY). Absent = editable. Enforced again in saveCustomerInfo. */
        @AuraEnabled public Map<String, String> lockReasons = new Map<String, String>();
        // the company, when the buyer is one
        @AuraEnabled public String customerType;
        @AuraEnabled public String companyName;
        @AuraEnabled public String tradeLicenceNumber;
        @AuraEnabled public Date tradeLicenceExpiry;
        @AuraEnabled public Date dateOfEstablishment;
        @AuraEnabled public String legalStructure;
        @AuraEnabled public String businessActivity;
        @AuraEnabled public String vatNumber;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
        /* tradeLicenceUploaded removed: unread flag, no consumers */
    }

    public class InstallmentRow {
        @AuraEnabled public Id installmentId;
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String status;
    }

    public class PlanBlock {
        @AuraEnabled public Id planId;
        @AuraEnabled public String planName;
        @AuraEnabled public Integer milestoneCount = 0;
        @AuraEnabled public List<InstallmentRow> rows = new List<InstallmentRow>();
    }

    public class FeeBlock {
        @AuraEnabled public Decimal admFee = 0;
        @AuraEnabled public Decimal downPayment = 0;
        @AuraEnabled public Decimal minimum = 0;
        @AuraEnabled public Decimal totalDue = 0;
        @AuraEnabled public Decimal totalPaid = 0;
        @AuraEnabled public Decimal totalBalance = 0;
        @AuraEnabled public Boolean minimumMet = false;
        @AuraEnabled public Boolean allowPartialBooking = false;
    }

    public class DocBlock {
        @AuraEnabled public Integer requiredCount = 0;
        @AuraEnabled public Integer outstandingCount = 0;
        @AuraEnabled public Boolean furtherDocumentsRequired = false;
        @AuraEnabled public List<String> outstanding = new List<String>();
    }

    public class BookingSummaryDTO {
        @AuraEnabled public UnitBlock unit;
        @AuraEnabled public CustomerBlock customer;
        @AuraEnabled public PlanBlock plan;
        @AuraEnabled public FeeBlock fees;
        @AuraEnabled public DocBlock documents;
        @AuraEnabled public List<PaymentBucketDTO> payments = new List<PaymentBucketDTO>();
        @AuraEnabled public Decimal totalPrice = 0;
        @AuraEnabled public Decimal collected = 0;
        @AuraEnabled public Decimal balance = 0;
        /** Presentation labels, never raw Status__c ('In Progress' is never rendered). */
        @AuraEnabled public String stage;
        @AuraEnabled public String subStage;
        /** 1.78 - MODON has closed the sale (Closed Won, unit Sold) though stage still reads New or
         *  In Progress. The booking's (first order), like stage. */
        @AuraEnabled public Boolean saleClosed = false;
        @AuraEnabled public String bookingReference;
        /* the basket. Singular fields keep the focused unit; totalPrice, bookingReference, stage,
         * subStage and payments describe the whole booking.
         *   units      one per live Sales Order, CreatedDate ASC
         *   plans      the plan each unit was booked on, parallel to units
         *   unitCount  units.size()
         * fees is not summed: it previews one unit on one plan and a basket raises no fee. */
        @AuraEnabled public List<UnitBlock> units = new List<UnitBlock>();
        @AuraEnabled public List<PlanBlock> plans = new List<PlanBlock>();
        @AuraEnabled public Integer unitCount = 0;
    }

    public class ProofDTO {
        @AuraEnabled public Id documentId;
        @AuraEnabled public String bucketKey;
        @AuraEnabled public String label;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String status;
        @AuraEnabled public String reference;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String fileName;
        @AuraEnabled public Datetime uploadedDate;
        /* the Payment this proof was recorded on (Documents__c.Receipt__c); null until recorded */
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String receiptName;
    }

    public class PaymentBucketDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Id sourceId;
        @AuraEnabled public String sourceObject;
        @AuraEnabled public Decimal requiredAmount = 0;
        @AuraEnabled public Decimal paidAmount = 0;
        @AuraEnabled public Decimal balanceAmount = 0;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean blocksConfirmation = false;
        /* closesSale       does paying this satisfy a leg of SalesTeamVoidCheck__c? The two booking
         *                  fees do; so does milestone 1 (the down payment).
         * remainingAmount  computed here; Balance_Amount__c is a roll-up that can be null.
         * proofRequired    something is still to collect on this row; drives the outstanding
         *                  count only, blocksConfirmation is separate. */
        @AuraEnabled public Boolean closesSale = false;
        @AuraEnabled public Decimal remainingAmount = 0;
        @AuraEnabled public Boolean proofRequired = false;
        @AuraEnabled public List<String> allowedMethods = new List<String>();
        @AuraEnabled public List<ProofDTO> proofs = new List<ProofDTO>();
        /* which Sales Order this obligation belongs to (a basket has N orders) */
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String unitName;
        /* payRoute         'TERMINAL' or 'PROOF'. Guidance only. There is no online route that
         *                  settles this ledger: Checkout links never raise Booking_Fee_Line__c
         *                  or reconcile to an installment (Receipt -> Allocation -> Invoice), so
         *                  the terminal is the only working online route and beginPayment drives it.
         * paymentRequired  the pay-first condition (one unit, a phase that asks for the fee,
         *                  no bypass), asked once per call. */
        @AuraEnabled public String payRoute;
        @AuraEnabled public Boolean paymentRequired = false;
        /* payByLink        1.85: a TERMINAL row paid by payment link (BOOKING_FEE_BY_LINK on). Wording only. */
        @AuraEnabled public Boolean payByLink = false;
        /* instruments        live payments against a milestone, newest first
         * withFinanceAmount  sum of those still In Progress
         * openAmount         what the rep is still asked to record: remainingAmount less what is
         *                    with Finance, capped at InvoiceAmount - AppliedAmount (MSC-121: the
         *                    cap is a ceiling, not the answer) */
        @AuraEnabled public List<InstrumentDTO> instruments = new List<InstrumentDTO>();
        @AuraEnabled public Decimal withFinanceAmount = 0;
        @AuraEnabled public Decimal openAmount = 0;
        /* does this row's form record a Payment? True for the ADM + Dari charge and Milestone 1
         * once the Sales Order exists; false for booking-fee lines and boxed milestones. */
        @AuraEnabled public Boolean recordsPayment = false;
    }

    /** One payment standing against a row. */
    public class InstrumentDTO {
        @AuraEnabled public Id receiptId;
        /** Modon's Receipt No, R-xxxxx. */
        @AuraEnabled public String receiptName;
        @AuraEnabled public String mode;
        /** Cheque number (TransactionNumber__c, else Cheque_Number__c). */
        @AuraEnabled public String reference;
        @AuraEnabled public Date instrumentDate;
        @AuraEnabled public Decimal amount;
        /** Receipt__c.Status__c verbatim. */
        @AuraEnabled public String status;
        /** True while In Progress. */
        @AuraEnabled public Boolean live = false;
        @AuraEnabled public String bank;
        @AuraEnabled public Datetime recordedOn;
        @AuraEnabled public String recordedBy;
        @AuraEnabled public Id contentDocumentId;
        /** Latest version, for the thumbnail. */
        @AuraEnabled public Id contentVersionId;
        /** Number of files on the payment. */
        @AuraEnabled public Integer fileCount = 0;
        @AuraEnabled public String fileName;
        @AuraEnabled public Id chequeDetailsId;
        /* MSC-197: what the image said about this cheque, once it is recorded. Null on anything
           that is not a cheque, and on a cheque nobody has read. */
        @AuraEnabled public String ocrStatus;
        @AuraEnabled public String ocrChequeNumber;
        @AuraEnabled public Date ocrChequeDate;
        @AuraEnabled public Decimal ocrAmount;
        @AuraEnabled public String ocrBank;
        @AuraEnabled public Boolean ocrMismatch = false;
        @AuraEnabled public String ocrError;
    }

    public class ProofSlotRequest {
        @AuraEnabled public Id salesOrderId { get; set; }
        @AuraEnabled public String bucketKey { get; set; }
        @AuraEnabled public Id sourceId { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String reference { get; set; }
        public ProofSlotRequest() {}
    }

    /** One selected unit and its plan, option and configuration (saveSalesOrder takes them per row). */
    public class UnitLine {
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public Id paymentPlanId { get; set; }
        @AuraEnabled public Id unitOptionId { get; set; }
        @AuraEnabled public String interior { get; set; }
        @AuraEnabled public String facadeStyle { get; set; }
        /* 1.75 - typed on a pre-approval (ADIB) plan when the unit's EOI carries none */
        @AuraEnabled public String preApprovalNumber { get; set; }
        /* offers are per unit in a basket */
        @AuraEnabled public List<Id> offerLineIds { get; set; }
        public UnitLine() {}
    }

    public class ConfirmRequest {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public Id paymentPlanId { get; set; }
        @AuraEnabled public Id unitOptionId { get; set; }
        @AuraEnabled public String interior { get; set; }
        @AuraEnabled public String facadeStyle { get; set; }
        /* 1.75 - see UnitLine.preApprovalNumber */
        @AuraEnabled public String preApprovalNumber { get; set; }
        @AuraEnabled public Boolean payNow { get; set; }
        /* approved offer ids; the server re-reads each value */
        @AuraEnabled public List<Id> offerLineIds { get; set; }
        /* populated only for a multi-unit basket; single-unit fields stay authoritative otherwise */
        @AuraEnabled public List<UnitLine> unitLines { get; set; }
        /* MSC-231: JSON {unitId: eoiId}. Validated here (units of this request, one EOI per
         * unit, every EOI in the org engine's own eligible list) then handed to
         * UnitSearchLwcController.saveSalesOrder verbatim. Blank = no EOI linking, as before. */
        @AuraEnabled public String eoiMappingJson { get; set; }
        public ConfirmRequest() {}
    }

    public class ConfirmResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String message;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public Boolean resumed = false;
        @AuraEnabled public BookingSummaryDTO summary;
        // non-blocking: set when the customer has not yet been submitted to Passfort
        @AuraEnabled public String complianceWarning;

        /** Every Sales Order created. */
        @AuraEnabled public List<Id> salesOrderIds = new List<Id>();
        /** Units this confirmation covered. */
        @AuraEnabled public Integer unitCount = 0;
        /** False for a multi-unit basket. */
        @AuraEnabled public Boolean paymentCollected = true;
    }

    /** Identity-verification and compliance chain. Always fully populated. */
    public class ComplianceStateDTO {
        @AuraEnabled public String kycStatus;            // KYC not complete / KYC Active / KYC Expired
        @AuraEnabled public Boolean kycLinkSent = false;
        @AuraEnabled public Boolean kycComplete = false;
        @AuraEnabled public Date kycCompletedDate;
        /** 18 Sep 2026 - Manual_KYC_Approval__c = Approved; verified without a completion date. */
        @AuraEnabled public Boolean manuallyApproved = false;
        @AuraEnabled public Boolean submitted = false;   // profileId__c present
        @AuraEnabled public String approvalStatus;       // raw PassfortApprovalStatus__c
        @AuraEnabled public String riskStatus;           // Low / High
        @AuraEnabled public String passfortComment;
        @AuraEnabled public Boolean canSendLink = false;
        @AuraEnabled public String blockedReason;        // why the link cannot be sent yet
        @AuraEnabled public String lastAttemptStatus;    // from Logger__c
        @AuraEnabled public String lastAttemptDetail;    // full reason, Integration_Request_Body__c
        @AuraEnabled public Datetime lastAttemptOn;
        @AuraEnabled public Boolean isPersonAccount = false;
        @AuraEnabled public String journeyStatus;        // where the customer got to in Signzy
        @AuraEnabled public Datetime refreshedOn;
        @AuraEnabled public String refreshMessage;       // what the poll actually did
        @AuraEnabled public Boolean canRefresh = false;
        /* step-2 verification choice and gate; values owned by SalesConsoleVerificationService */
        @AuraEnabled public String verificationStatus;   // NOT_SENT|SENT|EXPIRED|VERIFIED|IN_BRANCH
        @AuraEnabled public Datetime linkSentAt;
        @AuraEnabled public Datetime linkExpiresAt;
        @AuraEnabled public Boolean linkActive = false;
        @AuraEnabled public String linkUrl;              // KYCSiteLink__pc, not SignzyURL__c
        @AuraEnabled public Boolean releasedToBranch = false;
        /* whether the journey may leave the customer step; reviewAndConfirm re-checks it */
        @AuraEnabled public Boolean blocksAdvance = false;
        /* the two tracks a company has; null for a person or when the org read failed */
        @AuraEnabled public OrgTrackDTO company;
        @AuraEnabled public OrgTrackDTO signatory;
        /* MSC-151. The one thing to do now; null on an individual booking. Decided in
           SalesConsoleOrgController.nextStep. */
        @AuraEnabled public SalesConsoleOrgController.OrgNextStepDTO nextStep;
    }

    /** One compliance subject on a corporate booking (company or signatory). */
    public class OrgTrackDTO {
        @AuraEnabled public String name;
        /* profile id, verdict, or a transaction in flight */
        @AuraEnabled public Boolean submitted = false;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String riskStatus;
        @AuraEnabled public String comment;
        /** Signatory only. */
        @AuraEnabled public Date kycCompletedDate;
        /** Signatory only; the server decides. */
        @AuraEnabled public Boolean canCheck = false;
        /* link state read off the signatory Contact, where sendKYCForm's organisation branch stamps
           it. KYC_Send_Date_Time__c survives the send; Send_KYC_Verification_Email__c is cleared. */
        @AuraEnabled public Datetime linkSentAt;
        @AuraEnabled public Boolean linkActive = false;
        @AuraEnabled public Datetime linkExpiresAt;
    }

    /* MSC-151. The one thing to do now for a corporate booking; null for an individual one. */
    public class ChecklistItemDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String team;
        @AuraEnabled public String status;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public Boolean received = false;
    }

    public class DocumentRequirementDTO {
        @AuraEnabled public String residentStatus;
        /* items is the Sales team's checklist only; the other teams' rows are in laterItems */
        @AuraEnabled public List<ChecklistItemDTO> items = new List<ChecklistItemDTO>();
        @AuraEnabled public List<ChecklistItemDTO> laterItems = new List<ChecklistItemDTO>();
        @AuraEnabled public Integer laterCount = 0;
        /** Distinct owning teams for laterItems, in handoff order. */
        @AuraEnabled public List<String> laterTeams = new List<String>();
        @AuraEnabled public Boolean furtherDocumentsRequired = false;
        /** Outstanding labels for the Sales items only. */
        @AuraEnabled public List<String> outstandingLabels = new List<String>();
    }

    /** The team whose checklist a sales rep owns. */
    private static final String TEAM_SALES = 'Sales';

    /** Handoff order. */
    private static final List<String> TEAM_ORDER = new List<String>{
        'Sales Operation', 'Finance', 'Customer Management', 'Exceptional Approval'
    };

    public class DirectDebitStateDTO {
        @AuraEnabled public Boolean canRequest = false;
        @AuraEnabled public Id mandateId;
        @AuraEnabled public String mandateStatus;
        @AuraEnabled public String mandateStatusLabel;
        @AuraEnabled public Boolean coversMilestones = false;
        @AuraEnabled public Date commencesOn;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Decimal maximumAmount;
        /* covering: the mandate still stands over the schedule, so cheques are not offered.
         * canRequest is Modon's uniqueness rule (DD_UNIQUENESS_EXCLUDED). */
        @AuraEnabled public Boolean covering = false;
        @AuraEnabled public String requestName;
        @AuraEnabled public Boolean approve = false;
        @AuraEnabled public String holderName;
        @AuraEnabled public String bank;
        @AuraEnabled public String accountType;
        @AuraEnabled public String ibanMasked;
        @AuraEnabled public String idType;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String mobile;
        @AuraEnabled public Datetime requestedOn;
        /** Set when the Sales Order lookup could not be written. */
        @AuraEnabled public String linkNote;
        /* 1.68: the UAEDDS lifecycle for c/mscMandateCard */
        @AuraEnabled public String stage;
        @AuraEnabled public Boolean slotFree = true;
        @AuraEnabled public AurelixDirectDebitService.CardDTO card;
        /** MODON's validation problems on a Draft, returned after a save. */
        @AuraEnabled public List<String> problems;
    }

    public class DirectDebitInput {
        @AuraEnabled public Id salesOrderId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String iban { get; set; }
        @AuraEnabled public String bankName { get; set; }
        @AuraEnabled public Decimal maximumAmount { get; set; }
        @AuraEnabled public Date commencesOn { get; set; }
        @AuraEnabled public Date expiresOn { get; set; }
        /* the rest of what New Direct Debit Request captures */
        @AuraEnabled public String accountType { get; set; }
        @AuraEnabled public String idType { get; set; }
        @AuraEnabled public String idNumber { get; set; }
        @AuraEnabled public String mobile { get; set; }
        /* 1.68: MODON's capture carries these on the mandate */
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String city { get; set; }
        public DirectDebitInput() {}
    }

    /* The milestone box: one call, one shape */

    public class OptionDTO {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        public OptionDTO(String value, String label) { this.value = value; this.label = label; }
    }

    /** One milestone after the down payment, as the cheque sheet lists it. */
    public class BatchLineDTO {
        @AuraEnabled public Id installmentId;
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public String label;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Boolean overdue = false;
        @AuraEnabled public Decimal remainingAmount = 0;
        @AuraEnabled public Decimal openAmount = 0;
        @AuraEnabled public Decimal withFinanceAmount = 0;
        @AuraEnabled public Integer instrumentCount = 0;
        /** Milestone date, or today when it has passed. */
        @AuraEnabled public Date chequeDateDefault;
    }

    /** Mandate form seed, from the Account. */
    public class DdPrefillDTO {
        @AuraEnabled public String holderName;
        @AuraEnabled public String idType;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String mobile;
        /* 1.68 */
        @AuraEnabled public String email;
        @AuraEnabled public String city;
        @AuraEnabled public String bankName;
        @AuraEnabled public String iban;
        @AuraEnabled public Boolean isPersonAccount = true;
        /** 1.73: a company paying from the Sales Order's Primary Contact (D7) - an Emirates ID, not a licence. */
        @AuraEnabled public Boolean payerIsContact = false;
    }

    /** What Modon's trigger will stamp on the mandate. */
    public class DdComputedDTO {
        @AuraEnabled public Integer firstMilestone;
        @AuraEnabled public Integer lastMilestone;
        @AuraEnabled public Decimal maximumAmount;
        @AuraEnabled public Date commencesOn;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Integer milestoneCount = 0;
    }

    public class MilestoneBatchDTO {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public List<BatchLineDTO> lines = new List<BatchLineDTO>();
        @AuraEnabled public List<OptionDTO> bankOptions = new List<OptionDTO>();
        @AuraEnabled public List<OptionDTO> ddBankOptions = new List<OptionDTO>();
        @AuraEnabled public List<OptionDTO> ddAccountTypes = new List<OptionDTO>();
        @AuraEnabled public List<OptionDTO> ddIdTypes = new List<OptionDTO>();
        @AuraEnabled public DdPrefillDTO prefill = new DdPrefillDTO();
        @AuraEnabled public DdComputedDTO computed = new DdComputedDTO();
        @AuraEnabled public DirectDebitStateDTO dd = new DirectDebitStateDTO();
        /** No mandate covers the schedule. */
        @AuraEnabled public Boolean chequesAllowed = false;
        /** Uniqueness rule allows one, no cheque stands, customer is not a Non-Resident. */
        @AuraEnabled public Boolean directDebitAllowed = false;
        /** 1.68: why not, in one sentence, when there is something to say. */
        @AuraEnabled public String directDebitReason;
        @AuraEnabled public Integer liveChequeCount = 0;
        @AuraEnabled public Decimal liveChequeTotal = 0;
        /** Milestones already covered in full by cheques with Finance. */
        @AuraEnabled public Integer coveredMilestones = 0;
        @AuraEnabled public Integer openMilestones = 0;
    }

    /** A staged cheque image, before the cheque is recorded. */
    public class ChequeImageDTO {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String fileName;
    }

    /** OCR read of a cheque image; a proposal, never a record. */
    public class ChequeReadDTO {
        /** MSC-196: 'read' | 'unreadable' | 'notcheque' | 'failed'. Null DTO means OCR is off. */
        @AuraEnabled public String status;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public Date chequeDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String bankName;
        /* MSC-196: read but never written back - context the rep can eyeball against the paper */
        @AuraEnabled public String payee;
        /** MSC-205: the number the amount-in-words spells out; null when unreadable. */
        @AuraEnabled public Decimal wordsAmount;
        @AuraEnabled public String iban;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String amountInWords;
        @AuraEnabled public Boolean legible = true;
    }

    public class ChequeLineInput {
        /** Sheet row id, so a result lands on the right line. */
        @AuraEnabled public String clientKey { get; set; }
        @AuraEnabled public Id installmentId { get; set; }
        @AuraEnabled public String chequeNumber { get; set; }
        @AuraEnabled public Date chequeDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Id contentDocumentId { get; set; }
        public ChequeLineInput() {}
    }

    public class ChequeBatchInput {
        @AuraEnabled public Id salesOrderId { get; set; }
        /** Receipt__c.Bank__c, one for the batch. */
        @AuraEnabled public String bank { get; set; }
        @AuraEnabled public List<ChequeLineInput> lines { get; set; }
        public ChequeBatchInput() {}
    }

    public class ChequeLineResultDTO {
        @AuraEnabled public String clientKey;
        @AuraEnabled public Id installmentId;
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String receiptName;
        @AuraEnabled public Boolean allocated = false;
        @AuraEnabled public Boolean ok = false;
        @AuraEnabled public String message;
    }

    public class ChequeBatchResultDTO {
        /** True only when every line was written. */
        @AuraEnabled public Boolean recorded = false;
        @AuraEnabled public Integer count = 0;
        @AuraEnabled public String message;
        @AuraEnabled public List<ChequeLineResultDTO> lines = new List<ChequeLineResultDTO>();
    }

    /* What the row's form sends on Create Payment. */
    public class ProofPaymentInput {
        @AuraEnabled public Id salesOrderId { get; set; }
        /** BUCKET_ADM_CHARGE or BUCKET_MILESTONE. */
        @AuraEnabled public String bucketKey { get; set; }
        /** The row's sourceId: Invoice__c or SalesOrderInstallments__c. */
        @AuraEnabled public Id sourceId { get; set; }
        /** Receipt__c.Modeofpayment__c, one of the row's allowedMethods. */
        @AuraEnabled public String method { get; set; }
        /** Transaction number, or cheque number for a cheque. */
        @AuraEnabled public String transactionNumber { get; set; }
        /** Transaction date, or cheque date for a cheque. */
        @AuraEnabled public Date paidDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        /** Receipt__c.Bank__c, cheque only. */
        @AuraEnabled public String bank { get; set; }
        /** Proof slots carrying the files, none recorded yet. */
        @AuraEnabled public List<Id> documentIds { get; set; }
        /**
         * MSC-197: the read the console was already given for this cheque's image, so the same
         * image is not sent to the model a second time after the save. Optional: without it the
         * queueable reads it as before. The cheque's own number, date and amount already travel
         * from the browser on this same input, so this adds no new trust.
         */
        @AuraEnabled public ChequeReadInput chequeRead { get; set; }
        public ProofPaymentInput() {}
    }

    /** MSC-197: what readChequeImage handed the screen, coming back to be stamped. */
    public class ChequeReadInput {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String chequeNumber { get; set; }
        @AuraEnabled public Date chequeDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String amountInWords { get; set; }
        @AuraEnabled public String bankName { get; set; }
        @AuraEnabled public String accountNumber { get; set; }
        @AuraEnabled public String iban { get; set; }
        @AuraEnabled public String payee { get; set; }
        public ChequeReadInput() {}
    }

    public class ProofPaymentResultDTO {
        @AuraEnabled public Boolean recorded = false;
        @AuraEnabled public Id receiptId;
        /** Modon's Receipt No. */
        @AuraEnabled public String receiptName;
        @AuraEnabled public Boolean allocated = false;
        @AuraEnabled public String message;
    }

    // 1. Bootstrap

    /**
     * Hydrates the whole page in one round trip. Not cacheable: the journey is transactional
     * and every panel re-reads this after a mutation.
     */
    @AuraEnabled(cacheable=false)
    public static ConsoleState getConsoleState(Id opportunityId) {
        return buildConsoleState(opportunityId, null);
    }

    /**
     * Same state, opened on one Sales Order (Resume from Total Sales). Separate method because
     * AuraEnabled methods cannot be overloaded. An order that is not a live order of this
     * opportunity is ignored and the whole-opportunity shape comes back with focusedSalesOrderId null.
     */
    @AuraEnabled(cacheable=false)
    public static ConsoleState getConsoleStateForOrder(Id opportunityId, Id salesOrderId) {
        return buildConsoleState(opportunityId, salesOrderId);
    }

    private static ConsoleState buildConsoleState(Id opportunityId, Id salesOrderId) {
        ConsoleState state = new ConsoleState();
        if (opportunityId == null) {
            return state;
        }
        try {
            /* the order the rep opened, if this opportunity can show it */
            SalesOrder__c focus = null;
            if (salesOrderId != null) {
                /* 1.80: MODON's full cancelled list, so a "Cancelled SR" order is not reopened */
                List<String> dead = deadOrderStatuses();
                List<SalesOrder__c> asked = [
                    SELECT Id, Name, Unit__c
                    FROM SalesOrder__c
                    WHERE Id = :salesOrderId
                      AND Opportunity__c = :opportunityId
                      AND Status__c NOT IN :dead
                    LIMIT 1
                ];
                focus = asked.isEmpty() ? null : asked[0];
            }

            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.Name, Account.IsPersonAccount,
                       Account.PersonEmail, Account.PersonMobilePhone,
                       PrimaryContact__c, PrimaryContact__r.Name,
                       PrimaryContact__r.Email, PrimaryContact__r.MobilePhone,
                       Nationality__c, UAE_Resident_Status__c, Unit__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            if (opps.isEmpty()) {
                state.eligibilityBlocked = true;
                state.eligibilityMessage = 'This opportunity could not be found, or you do not have access to it.';
                return state;
            }
            Opportunity opp = opps[0];
            state.opportunityId = opp.Id;
            state.accountId = opp.AccountId;
            state.primaryContactId = opp.PrimaryContact__c;
            state.nationality = opp.Nationality__c;
            state.residentStatus = opp.UAE_Resident_Status__c;
            state.isPersonAccount = opp.Account != null && opp.Account.IsPersonAccount;

            if (opp.PrimaryContact__c != null) {
                state.customerName = opp.PrimaryContact__r.Name;
                state.email = opp.PrimaryContact__r.Email;
                state.mobile = opp.PrimaryContact__r.MobilePhone;
            } else if (opp.Account != null) {
                state.customerName = opp.Account.Name;
                state.email = opp.Account.PersonEmail;
                state.mobile = opp.Account.PersonMobilePhone;
            }

            /* 1.71 - checkBookingEligibility is not called: the Sales App retired it on 2 Sep and
               gates the booking on KYC alone, which this class enforces server-side. */

            state.hasExistingSalesOrder =
                UnitSearchLwcController.checkExistingSalesOrder(String.valueOf(opportunityId));

            // Resume: find a hold or unfinished pay-first booking. Isolated: getActiveJourneyState
            // uses WITH SECURITY_ENFORCED on hold fields, and losing the hint is a degraded page
            // rather than a blank one.
            UnitBookingJourneyController.HeldUnit held = null;
            try {
                held = UnitBookingJourneyController.getPaidUnbookedUnit(opportunityId);
                if (held == null) {
                    List<UnitBookingJourneyController.HeldUnit> active =
                        UnitBookingJourneyController.getActiveJourneyState(opportunityId);
                    if (active != null && !active.isEmpty()) {
                        held = active[0];
                    }
                }
            } catch (Exception e) {
                held = null;
            }
            state.activeHold = held;

            /* the opened order names the unit; the hold is the fallback. 1.77: Opportunity.Unit__c
               is no longer one: MODON's Sales App never reads it (only the fee sync writes it, and
               nothing clears it), so it pointed resumed bookings at Sold and Reserved units */
            Id resumeUnitId = focus != null
                ? focus.Unit__c
                : (held != null ? held.unitId : null);
            if (resumeUnitId != null) {
                SalesOrderCheckoutController.BookingStatus bs =
                    SalesOrderCheckoutController.getActiveBooking(
                        String.valueOf(resumeUnitId), String.valueOf(opportunityId));
                if (bs != null) {
                    state.bookingRef = bs.bookingRef;
                    state.salesOrderId = bs.salesOrderId;
                }
            }

            /* getActiveBooking resolves the pay-first route only (Checkout_Payment__c); bookings
             * made by reviewAndConfirm write SalesOrder__c directly, so resolve them here too */
            /* the opened order wins over the pay-first route */
            if (focus != null) {
                state.salesOrderId = focus.Id;
                state.bookingRef = focus.Name;
                state.focusedSalesOrderId = focus.Id;
            }
            if (state.salesOrderId == null) {
                SalesOrder__c booked = activeSalesOrderFor(opportunityId, resumeUnitId);
                if (booked != null) {
                    state.salesOrderId = booked.Id;
                    state.bookingRef = booked.Name;
                    /* the order carries the unit when Opportunity.Unit__c does not */
                    if (resumeUnitId == null) {
                        resumeUnitId = booked.Unit__c;
                    }
                }
            }

            // what the whole booking covers
            state.bookedUnits = bookedUnitsFor(opportunityId);

            /* every live order goes into the summary; the focused one is picked out by resumeUnitId.
               Falls back to the single-order call when bookedUnitsFor found nothing. */
            List<Id> everyOrder = new List<Id>();
            for (BookedUnitDTO b : state.bookedUnits) {
                everyOrder.add(b.salesOrderId);
            }
            if (everyOrder.isEmpty() && state.salesOrderId != null) {
                everyOrder.add(state.salesOrderId);
            }
            /* unless one order was opened: then the summary is that order's alone */
            state.summary = focus != null
                ? buildSummary(opportunityId, resumeUnitId, null, new List<Id>{ focus.Id })
                : buildSummary(opportunityId, resumeUnitId, null,
                    everyOrder.isEmpty() ? null : everyOrder);

            /* open where the agent left off; see resumeStepFor */
            state.resumeStep = resumeStepFor(opportunityId, resumeUnitId, state.summary);

            // identity verification / compliance chain
            state.compliance = getComplianceState(opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return state;
    }

    /**
     * Saves customer details and residency. Writes Account and Opportunity together so the two copies
     * agree (MODON's retired checkBookingEligibility blocked when they did not; 1.71 no longer calls it).
     *
     * Write policy mirrors lockReasons, from one pre-DML snapshot: identity goes to the Account
     * (person) or signatory Contact (organisation), never the Opportunity; starred values are
     * skipped (masked round-trip); populated values are overwritten only while the customer is
     * fresh (created by this rep within a day); residency is written to all records or none and
     * only when the Opportunity's copy is blank or agrees (Sales_user_cant_change_Passport_and_EID);
     * Contact is written first so the residency trigger's backfill finds the rep's values;
     * Opportunity is updated only when it actually changes (its format rules have no ISCHANGED).
     */
    @AuraEnabled
    public static ConsoleState saveCustomerInfo(CustomerInput input) {
        if (input == null || input.opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        if (String.isNotBlank(input.residentStatus)
                && input.residentStatus != RESIDENT
                && input.residentStatus != NON_RESIDENT) {
            // guard the residency vocabulary; DocumentChecklistController returns an unfiltered
            // checklist for anything else
            throw new AuraHandledException(
                'Residency must be either "' + RESIDENT + '" or "' + NON_RESIDENT + '".');
        }
        try {
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.IsPersonAccount, PrimaryContact__c,
                       Account.CreatedById, Account.CreatedDate,
                       Account.FirstName, Account.LastName,
                       Account.PersonEmail, Account.PersonMobilePhone,
                       Account.Nationality__pc, Account.UAE_Resident_Status__pc,
                       Account.CountryOfResidence__pc,
                       Account.EIDNumber__pc, Account.PassportNumber__pc,
                       Account.EmiratesIDExpiryDate__pc, Account.PassportIssueDate__pc,
                       Account.PassportExpiryDate__pc,
                       UAE_Resident_Status__c, Nationality__c,
                       PrimaryContact__r.Email, PrimaryContact__r.MobilePhone,
                       PrimaryContact__r.Nationality__c,
                       PrimaryContact__r.UAE_Resident_Status__c,
                       PrimaryContact__r.CountryOfResidence__c,
                       PrimaryContact__r.EIDNumber__c, PrimaryContact__r.PassportNumber__c,
                       PrimaryContact__r.EmiratesIDExpiryDate__c,
                       PrimaryContact__r.PassportIssueDate__c,
                       PrimaryContact__r.PassportExpiryDate__c,
                       PrimaryContact__r.AreYouRealBeneficiaryOfThis__c
                FROM Opportunity
                WHERE Id = :input.opportunityId
                LIMIT 1
            ];
            if (opps.isEmpty()) {
                throw new AuraHandledException('This opportunity could not be found.');
            }
            Opportunity opp = opps[0];
            Boolean person = opp.Account != null && opp.Account.IsPersonAccount == true;
            Boolean fresh = opp.Account != null
                && opp.Account.CreatedById == UserInfo.getUserId()
                && opp.Account.CreatedDate >= System.now().addHours(-24);

            /* residency: all records or none, never a change the Opportunity's rule would refuse */
            String residency = null;
            if (String.isNotBlank(input.residentStatus)
                    && (String.isBlank(opp.UAE_Resident_Status__c)
                        || opp.UAE_Resident_Status__c == input.residentStatus)) {
                residency = input.residentStatus;
            }

            List<SObject> toUpdate = new List<SObject>();

            if (!person && opp.AccountId != null) {
                /* an organisation's identity, email and mobile belong to the signatory Contact */
                Boolean hasIdentityInput = String.isNotBlank(input.emiratesId)
                    || String.isNotBlank(input.passportNumber)
                    || input.emiratesIdExpiry != null
                    || input.passportIssueDate != null
                    || input.passportExpiry != null;
                /* the declaration needs the signatory too */
                if (opp.PrimaryContact__c == null
                        && (hasIdentityInput || input.realBeneficiary != null)) {
                    // otherwise the values vanish behind a clean success
                    throw new AuraHandledException(
                        'Choose the company\'s signatory first - these details belong to them.');
                }
                if (opp.PrimaryContact__c != null) {
                    Contact conUpd = new Contact(Id = opp.PrimaryContact__c);
                    Boolean conTouched = false;
                    /* difference-gated: a no-change update still runs every Contact trigger */
                    if (residency != null
                            && residency != opp.PrimaryContact__r.UAE_Resident_Status__c) {
                        conUpd.UAE_Resident_Status__c = residency;
                        conTouched = true;
                    }
                    if (writable(input.email, opp.PrimaryContact__r.Email, fresh)) {
                        conUpd.Email = input.email;
                        conTouched = true;
                    }
                    if (writable(input.mobile, opp.PrimaryContact__r.MobilePhone, fresh)) {
                        conUpd.MobilePhone = input.mobile;
                        conTouched = true;
                    }
                    // Passfort reads Contact.Nationality__c; overwrite when not blank
                    if (String.isNotBlank(input.nationality)
                            && !input.nationality.contains('*')
                            && input.nationality != opp.PrimaryContact__r.Nationality__c) {
                        conUpd.Nationality__c = input.nationality;
                        conTouched = true;
                    }
                    if (String.isNotBlank(input.countryOfResidence)
                            && input.countryOfResidence != opp.PrimaryContact__r.CountryOfResidence__c) {
                        conUpd.CountryOfResidence__c = input.countryOfResidence;
                        conTouched = true;
                    }
                    /* AML declaration, difference-gated; null = not answered, not written */
                    if (input.realBeneficiary != null
                            && input.realBeneficiary
                                != opp.PrimaryContact__r.AreYouRealBeneficiaryOfThis__c) {
                        conUpd.AreYouRealBeneficiaryOfThis__c = input.realBeneficiary;
                        conTouched = true;
                    }
                    /* names are not written: Sales_user_cant_update_contact_details refuses it */
                    if (writable(input.emiratesId, opp.PrimaryContact__r.EIDNumber__c, fresh)) {
                        conUpd.EIDNumber__c = input.emiratesId.trim();
                        conUpd.En_EIDNumber__c = input.emiratesId.trim();
                        conTouched = true;
                    }
                    if (writable(input.passportNumber, opp.PrimaryContact__r.PassportNumber__c, fresh)) {
                        conUpd.PassportNumber__c = input.passportNumber.trim();
                        conUpd.En_PassportNumber__c = input.passportNumber.trim();
                        conTouched = true;
                    }
                    if (input.emiratesIdExpiry != null
                            && (fresh || opp.PrimaryContact__r.EmiratesIDExpiryDate__c == null)) {
                        conUpd.EmiratesIDExpiryDate__c = input.emiratesIdExpiry;
                        conTouched = true;
                    }
                    if (input.passportIssueDate != null
                            && (fresh || opp.PrimaryContact__r.PassportIssueDate__c == null)) {
                        conUpd.PassportIssueDate__c = input.passportIssueDate;
                        conTouched = true;
                    }
                    if (input.passportExpiry != null
                            && (fresh || opp.PrimaryContact__r.PassportExpiryDate__c == null)) {
                        conUpd.PassportExpiryDate__c = input.passportExpiry;
                        conTouched = true;
                    }
                    if (conTouched) {
                        toUpdate.add(conUpd);
                    }
                }
                /* company fields, fill-only; added only when something was set */
                Account companyUpd = companyUpdate(opp.AccountId, input);
                if (companyUpd.getPopulatedFieldsAsMap().size() > 1) {
                    toUpdate.add(companyUpd);
                }
            }

            if (person) {
                /* a person's writes go through the Account alone (no extra Contact DML) */
                Account accUpd = new Account(Id = opp.AccountId);
                Boolean accTouched = false;
                /* difference-gated */
                if (residency != null
                        && residency != opp.Account.UAE_Resident_Status__pc) {
                    accUpd.UAE_Resident_Status__pc = residency;
                    accTouched = true;
                }
                if (writable(input.email, opp.Account.PersonEmail, fresh)) {
                    accUpd.PersonEmail = input.email;
                    accTouched = true;
                }
                if (writable(input.mobile, opp.Account.PersonMobilePhone, fresh)) {
                    accUpd.PersonMobilePhone = input.mobile;
                    accTouched = true;
                }
                // nationality on the Account too: sendKYCForm refuses a link without
                // Nationality__pc, UAE_Resident_Status__pc, PersonEmail and PersonMobilePhone
                if (String.isNotBlank(input.nationality)
                        && !input.nationality.contains('*')
                        && input.nationality != opp.Account.Nationality__pc) {
                    accUpd.Nationality__pc = input.nationality;
                    accTouched = true;
                }
                if (String.isNotBlank(input.countryOfResidence)
                        && input.countryOfResidence != opp.Account.CountryOfResidence__pc) {
                    accUpd.CountryOfResidence__pc = input.countryOfResidence;
                    accTouched = true;
                }
                /* names, fill-only */
                if (writable(input.firstName, opp.Account.FirstName, fresh)) {
                    accUpd.FirstName = input.firstName.trim();
                    accTouched = true;
                }
                if (writable(input.lastName, opp.Account.LastName, fresh)) {
                    accUpd.LastName = input.lastName.trim();
                    accTouched = true;
                }
                if (writable(input.emiratesId, opp.Account.EIDNumber__pc, fresh)) {
                    accUpd.EIDNumber__pc = input.emiratesId.trim();
                    accUpd.En_EIDNumber__pc = input.emiratesId.trim();
                    accTouched = true;
                }
                if (writable(input.passportNumber, opp.Account.PassportNumber__pc, fresh)) {
                    accUpd.PassportNumber__pc = input.passportNumber.trim();
                    accUpd.En_PassportNumber__pc = input.passportNumber.trim();
                    accTouched = true;
                }
                if (input.emiratesIdExpiry != null
                        && (fresh || opp.Account.EmiratesIDExpiryDate__pc == null)) {
                    accUpd.EmiratesIDExpiryDate__pc = input.emiratesIdExpiry;
                    accTouched = true;
                }
                if (input.passportIssueDate != null
                        && (fresh || opp.Account.PassportIssueDate__pc == null)) {
                    accUpd.PassportIssueDate__pc = input.passportIssueDate;
                    accTouched = true;
                }
                if (input.passportExpiry != null
                        && (fresh || opp.Account.PassportExpiryDate__pc == null)) {
                    accUpd.PassportExpiryDate__pc = input.passportExpiry;
                    accTouched = true;
                }
                if (accTouched) {
                    toUpdate.add(accUpd);
                }
            }

            /* Opportunity last, and only when it changes */
            Opportunity oppUpd = new Opportunity(Id = opp.Id);
            Boolean oppTouched = false;
            if (String.isNotBlank(input.nationality)
                    && !input.nationality.contains('*')
                    && input.nationality != opp.Nationality__c) {
                oppUpd.Nationality__c = input.nationality;
                oppTouched = true;
            }
            if (residency != null && residency != opp.UAE_Resident_Status__c) {
                oppUpd.UAE_Resident_Status__c = residency;
                oppTouched = true;
            }
            if (oppTouched) {
                toUpdate.add(oppUpd);
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        } catch (AuraHandledException e) {
            /* guards reach the rep as written */
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return getConsoleState(input.opportunityId);
    }

    /* The console's own address write. Not AccountAddressController.saveAccount: that is the Save
     * Address quick action's handler and enforces its own completeness policy (trade licence and VAT
     * on an org account). Same fields written, minus the policy; reads stay shared. */
    public class AddressInput {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Boolean isPersonAccount { get; set; }
        @AuraEnabled public String personMailingStreet { get; set; }
        @AuraEnabled public String personMailingCity { get; set; }
        @AuraEnabled public String personMailingState { get; set; }
        @AuraEnabled public String personMailingPostalCode { get; set; }
        @AuraEnabled public String personMailingCountry { get; set; }
        @AuraEnabled public Decimal personMailingLatitude { get; set; }
        @AuraEnabled public Decimal personMailingLongitude { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public String billingPostalCode { get; set; }
        @AuraEnabled public String billingCountry { get; set; }
        @AuraEnabled public Decimal billingLatitude { get; set; }
        @AuraEnabled public Decimal billingLongitude { get; set; }
        @AuraEnabled public String nationality { get; set; }
        @AuraEnabled public String uaeResidentStatus { get; set; }
        public AddressInput() {}
    }

    @AuraEnabled
    public static ConsoleState saveAddress(AddressInput input) {
        if (input == null || input.accountId == null) {
            throw new AuraHandledException('No customer was supplied to save the address to.');
        }
        /* nationality and residency are required together for a person only; an organisation holds
           residency on the Opportunity and nationality on its signatory */
        if (input.isPersonAccount == true) {
            if (String.isBlank(input.nationality)) {
                throw new AuraHandledException('Nationality is required.');
            }
            if (String.isBlank(input.uaeResidentStatus)) {
                throw new AuraHandledException('UAE Resident Status is required.');
            }
        }
        try {
            Account acc = new Account(Id = input.accountId);

            if (input.isPersonAccount == true) {
                acc.PersonMailingStreet     = input.personMailingStreet;
                acc.PersonMailingCity       = input.personMailingCity;
                acc.PersonMailingState      = input.personMailingState;
                acc.PersonMailingPostalCode = input.personMailingPostalCode;
                acc.PersonMailingCountry    = input.personMailingCountry;
                acc.PersonMailingLatitude   = input.personMailingLatitude;
                acc.PersonMailingLongitude  = input.personMailingLongitude;
                // Person Accounts hold residency; an org's lives on the Opportunity
                acc.Nationality__pc         = input.nationality;
                acc.UAE_Resident_Status__pc = input.uaeResidentStatus;
            }

            // billing applies to both, as the quick action does
            acc.BillingStreet     = input.billingStreet;
            acc.BillingCity       = input.billingCity;
            acc.BillingState      = input.billingState;
            acc.BillingPostalCode = input.billingPostalCode;
            acc.BillingCountry    = input.billingCountry;
            acc.BillingLatitude   = input.billingLatitude;
            acc.BillingLongitude  = input.billingLongitude;

            update acc;

            /* fill-only: a populated Opportunity residency is left alone (the active rule refuses
               changing it) and no change means no DML */
            if (input.opportunityId != null) {
                for (Opportunity o : [SELECT Nationality__c, UAE_Resident_Status__c
                                      FROM Opportunity WHERE Id = :input.opportunityId LIMIT 1]) {
                    Opportunity oppUpd = new Opportunity(Id = o.Id);
                    Boolean touched = false;
                    if (String.isNotBlank(input.nationality) && String.isBlank(o.Nationality__c)) {
                        oppUpd.Nationality__c = input.nationality;
                        touched = true;
                    }
                    if (String.isNotBlank(input.uaeResidentStatus)
                            && String.isBlank(o.UAE_Resident_Status__c)) {
                        oppUpd.UAE_Resident_Status__c = input.uaeResidentStatus;
                        touched = true;
                    }
                    if (touched) {
                        update oppUpd;
                    }
                }
            }
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return getConsoleState(input.opportunityId);
    }

    /** Account.LegalStructure__c values from the schema. */
    @AuraEnabled(cacheable=true)
    public static List<String> getLegalStructureOptions() {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry e :
                Account.LegalStructure__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                out.add(e.getValue());
            }
        }
        return out;
    }

    /** Contact.CountryOfResidence__c values from the schema (restricted Countries set), described
        separately from the nationality list because it follows the field it saves into. */
    @AuraEnabled(cacheable=true)
    public static List<String> getCountryOfResidenceOptions() {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry e :
                Contact.CountryOfResidence__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                out.add(e.getValue());
            }
        }
        return out;
    }

    /**
     * Company fields Passfort reads for a Company entity. Licence goes to all three fields, matching
     * CustomerKYCHandler.mapKYCTradeLicenseValues.
     */
    private static Account companyUpdate(Id accountId, CustomerInput input) {
        Account acc = new Account(Id = accountId);
        if (String.isNotBlank(input.companyName)) {
            acc.Name = input.companyName.trim();
            acc.Company_Name_as_per_Trade_License__c = input.companyName.trim();
        }
        if (String.isNotBlank(input.tradeLicenceNumber)) {
            String licence = input.tradeLicenceNumber.trim();
            acc.UnifiedNumber__c        = licence;
            acc.TradeLicenseNumber__c   = licence;
            acc.Trade_License_Number__c = licence;
        }
        if (input.tradeLicenceExpiry != null) {
            acc.TradeLicenseExpiryDate__c = input.tradeLicenceExpiry;
        }
        // Passfort errors when incorporation_date is null
        if (input.dateOfEstablishment != null) {
            acc.DateOfEstablishment__c = input.dateOfEstablishment;
        }
        if (String.isNotBlank(input.legalStructure)) {
            acc.LegalStructure__c = input.legalStructure;
        }
        if (String.isNotBlank(input.businessActivity)) {
            acc.Description = input.businessActivity.trim();
        }
        if (String.isNotBlank(input.vatNumber)) {
            acc.UAEVATRegisterNumber__c = input.vatNumber.trim();
        }
        /* billing arm retired; c/mscAddress via saveAddress is the one address writer.
           CustomerInput.billing* stays declared for deserialisation. */
        return acc;
    }

    // 2. Unit and plan

    /**
     * Works with no opportunity so the console can offer unit selection first. getUnitDetails
     * copes with a blank id; getAllProjects does not (its single-row ProjectInterest__c query
     * throws and is swallowed into an empty list), so with no opportunity the projects are
     * listed directly.
     */
    /* cacheable=false: the client cache kept serving a stale project order */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getProjects(String opportunityId) {
        if (String.isNotBlank(opportunityId)) {
            return UnitSearchLwcController.getAllProjects(opportunityId);
        }

        // same shape getAllProjects returns: meta entry first, then {label, value} rows
        List<Map<String, String>> out = new List<Map<String, String>>();
        out.add(new Map<String, String>{
            'type' => 'meta',
            'projectInterest' => ''
        });
        try {
            /* ordered by sellable stock, not alphabetically: the first project is auto-selected */
            Map<Id, Integer> stock = availableUnitsByProject();
            List<Project__c> projects = [
                SELECT Id, Name FROM Project__c
                // Modon Egypt has its own console
                WHERE Source_Entity__c != 'Modon - Egypt'
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
            /* deepest inventory first; ties keep the query order */
            List<Project__c> ordered = new List<Project__c>();
            Map<Id, Project__c> byId = new Map<Id, Project__c>(projects);
            List<Id> ids = new List<Id>(byId.keySet());
            // insertion sort; single-digit list, and no comparator for a plain SObject list
            for (Id candidate : ids) {
                Integer c = stock.containsKey(candidate) ? stock.get(candidate) : 0;
                Integer at = ordered.size();
                for (Integer i = 0; i < ordered.size(); i++) {
                    Integer existing = stock.containsKey(ordered[i].Id)
                        ? stock.get(ordered[i].Id) : 0;
                    if (c > existing) { at = i; break; }
                }
                // add(index, element) throws on an empty list and on index == size()
                if (at >= ordered.size()) {
                    ordered.add(byId.get(candidate));
                } else {
                    ordered.add(at, byId.get(candidate));
                }
            }
            for (Project__c p : ordered) {
                out.add(new Map<String, String>{
                    'label' => p.Name,
                    'value' => p.Id
                });
            }
        } catch (Exception e) {
            // WITH SECURITY_ENFORCED throws on a missing field; an empty list is better than a thrown page
            System.debug('getProjects: project list unavailable - ' + e.getMessage());
        }
        return out;
    }

    /** Same as getProjects: the ordering must not be served stale. */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getPhases(String projectId) {
        List<Map<String, String>> phases = UnitSearchLwcController.getAllBuildings(projectId);
        return withStockFirst(phases, projectId);
    }

    /* Stock-first ordering */

    /** Available unit counts per project, for ordering only. */
    private static Map<Id, Integer> availableUnitsByProject() {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Phase__r.Project__c pid, COUNT(Id) total
            FROM Unit__c
            WHERE Status__c = :Constants.STATUS_AVAILABLE
              AND Phase__r.Project__c != NULL
            GROUP BY Phase__r.Project__c
        ]) {
            counts.put((Id) ar.get('pid'), (Integer) ar.get('total'));
        }
        return counts;
    }

    /**
     * Phases with available units first, order otherwise preserved. Done here because
     * getAllBuildings is shared with the broker portal and Modon Egypt.
     */
    private static List<Map<String, String>> withStockFirst(
        List<Map<String, String>> phases, String projectId
    ) {
        if (phases == null || phases.size() < 2 || String.isBlank(projectId)) {
            return phases;
        }
        Set<Id> stocked = new Set<Id>();
        try {
            for (AggregateResult ar : [
                SELECT Phase__c phase
                FROM Unit__c
                WHERE Status__c = :Constants.STATUS_AVAILABLE
                  AND Phase__r.Project__c = :projectId
                GROUP BY Phase__c
            ]) {
                stocked.add((Id) ar.get('phase'));
            }
        } catch (Exception e) {
            System.debug('getPhases: stock ordering unavailable - ' + e.getMessage());
            return phases;
        }
        if (stocked.isEmpty()) {
            return phases;
        }
        List<Map<String, String>> withStock = new List<Map<String, String>>();
        List<Map<String, String>> without = new List<Map<String, String>>();
        for (Map<String, String> row : phases) {
            // meta row carries no value and stays at the front
            String v = row.get('value');
            if (String.isBlank(v)) {
                withStock.add(row);
            } else if (stocked.contains((Id) v)) {
                withStock.add(row);
            } else {
                without.add(row);
            }
        }
        withStock.addAll(without);
        return withStock;
    }

    /** Unit search. isModonProfile is false: this is the UAE residential journey. */
    @AuraEnabled(cacheable=false)
    public static UnitSearchLwcController.UnitDataWrapper searchUnits(
        Id phaseId, String opportunityId, String unitType, String qualityType,
        String bedrooms, String gfaRange, String floor, String unitNumber
    ) {
        UnitSearchLwcController.UnitDataWrapper data =
            UnitSearchLwcController.getUnitDetails(
                phaseId, opportunityId, unitType, qualityType, bedrooms,
                gfaRange, floor, unitNumber, false);
        if (data != null) {
            /* MSC-164. Access first, then the hold. Both only remove rows, and every figure on the
               unit screen derives from this one list. */
            data.units = notOnLiveHold(bookableOnly(data.units));
        }
        return data;
    }

    /**
     * The plan the agent chose, read back off the booking fee lines (raised by beginPayment with
     * Payment_Plan__c). Ordered and taken singly because a null is meaningful.
     */
    private static Id planFromFeeLines(Id opportunityId, Id unitId) {
        for (Booking_Fee_Line__c line : [
            SELECT Payment_Plan__c
            FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :opportunityId
              AND Unit__c = :unitId
              AND Payment_Plan__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]) {
            return line.Payment_Plan__c;
        }
        return null;
    }

    /**
     * The step to reopen on, or null to start at the beginning. Answers for the whole journey:
     * booking has everything -> Payment & Confirm; has a unit but no customer or plan -> that
     * step; no unit -> null. Fee lines are not the signal: a basket or a bypassed phase never
     * raises any.
     */
    private static String resumeStepFor(
        Id opportunityId, Id unitId, BookingSummaryDTO summary
    ) {
        if (opportunityId == null || unitId == null
                || summary == null || summary.unit == null) {
            return null;
        }
        /* residentStatus is what the client's hasCustomer tests */
        Boolean hasCustomer = summary.customer != null
            && String.isNotBlank(summary.customer.residentStatus);
        /* plan.planId, not plan: buildPlanBlock always returns an object */
        Boolean hasPlan = summary.plan != null && summary.plan.planId != null;
        if (!hasCustomer || !hasPlan) {
            return 'details';
        }
        return 'settle';
    }

    /**
     * 1.80 - Sales Order statuses that end a booking: MODON's CommissionCancelStatus label, read the same
     * way as Total Sales. Every live-order filter in this class uses it.
     */
    @TestVisible
    private static List<String> deadOrderStatuses() {
        return SalesConsoleDashboardController.cancelledSalesOrderStatuses();
    }

    /**
     * Every live Sales Order on the opportunity, with its unit. Same filter as activeSalesOrderFor
     * (deadOrderStatuses). Best-effort: getConsoleState cannot fail on this.
     */
    private static List<BookedUnitDTO> bookedUnitsFor(Id opportunityId) {
        List<BookedUnitDTO> rows = new List<BookedUnitDTO>();
        if (opportunityId == null) {
            return rows;
        }
        try {
            List<String> dead = deadOrderStatuses();
            for (SalesOrder__c so : [
                SELECT Id, Name, Unit__c, Unit__r.Name,
                       // price, plan and state, so the client can rebuild the basket
                       TotalAmount__c, PaymentPlan__c, PaymentPlan__r.Name,
                       Status__c, Sub_Status__c
                FROM SalesOrder__c
                WHERE Opportunity__c = :opportunityId
                  AND Status__c NOT IN :dead
                ORDER BY CreatedDate ASC
                LIMIT 50
            ]) {
                BookedUnitDTO row = new BookedUnitDTO();
                row.salesOrderId = so.Id;
                row.bookingRef = so.Name;
                row.unitId = so.Unit__c;
                row.unitName = so.Unit__r == null ? null : so.Unit__r.Name;
                row.totalPrice = so.TotalAmount__c;
                row.planId = so.PaymentPlan__c;
                row.planName = so.PaymentPlan__r == null ? null : so.PaymentPlan__r.Name;
                row.status = so.Status__c;
                row.subStatus = so.Sub_Status__c;
                rows.add(row);
            }
        } catch (Exception e) {
            return new List<BookedUnitDTO>();
        }
        return rows;
    }

    /**
     * The live Sales Order on this opportunity, or null. 1.80: live means not in deadOrderStatuses.
     * unitId chooses between a basket's orders; otherwise the newest wins.
     */
    private static SalesOrder__c activeSalesOrderFor(Id opportunityId, Id unitId) {
        if (opportunityId == null) {
            return null;
        }
        try {
            List<String> dead = deadOrderStatuses();
            List<SalesOrder__c> orders = [
                SELECT Id, Name, Unit__c, Status__c
                FROM SalesOrder__c
                WHERE Opportunity__c = :opportunityId
                  AND Status__c NOT IN :dead
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            if (orders.isEmpty()) {
                return null;
            }
            if (unitId != null) {
                for (SalesOrder__c so : orders) {
                    if (so.Unit__c == unitId) {
                        return so;
                    }
                }
            }
            return orders[0];
        } catch (Exception e) {
            /* losing this costs the landing step; throwing would cost the page */
            return null;
        }
    }

    /**
     * The unit this journey is about, before getConsoleState has run: the live Sales Order.
     * 1.77: no longer Opportunity.Unit__c first, which the Sales App never reads; a stale one opened
     * the grid on a phase with nothing the rep could take.
     */
    private static Unit__c journeyUnitFor(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        try {
            Id unitId = null;
            SalesOrder__c so = activeSalesOrderFor(opportunityId, null);
            unitId = so == null ? null : so.Unit__c;
            if (unitId == null) {
                return null;
            }
            for (Unit__c u : [
                SELECT Id, Phase__c, Phase__r.Project__c
                FROM Unit__c WHERE Id = :unitId LIMIT 1
            ]) {
                return u;
            }
        } catch (Exception e) {
            /* ordering hint only */
        }
        return null;
    }

    /* Only offer units the agent can edit. Unit__c is OWD Private and every booking write is
     * with sharing, so a read-only unit fails at Take payment with INSUFFICIENT_ACCESS_OR_READONLY.
     * Edit access comes from the Unit trigger's shares and cannot be granted from here. */
    /**
     * MSC-164. A unit on a live payment hold is not offered, to anybody (the org's own predicate
     * keeps a unit held by the running user). The hold fields are re-queried because
     * getUnitDetails does not select them. An expired hold is not a hold: nothing clears
     * Payment_In_Progress__c in the background. A null expiry is treated as live, as the org does.
     */
    private static List<Unit__c> notOnLiveHold(List<Unit__c> units) {
        if (units == null || units.isEmpty()) {
            return units;
        }
        Set<Id> ids = new Set<Id>();
        for (Unit__c u : units) {
            ids.add(u.Id);
        }
        Datetime asOf = System.now();
        Set<Id> held = new Set<Id>();
        try {
            for (Unit__c u : [
                SELECT Id, Payment_Hold_Expiry__c
                FROM Unit__c
                WHERE Id IN :ids AND Payment_In_Progress__c = TRUE
            ]) {
                if (u.Payment_Hold_Expiry__c == null || u.Payment_Hold_Expiry__c >= asOf) {
                    held.add(u.Id);
                }
            }
        } catch (Exception e) {
            /* fails open: this filter only removes rows */
            System.debug('notOnLiveHold: hold state unavailable - ' + e.getMessage());
            return units;
        }
        if (held.isEmpty()) {
            return units;
        }
        List<Unit__c> out = new List<Unit__c>();
        for (Unit__c u : units) {
            if (!held.contains(u.Id)) {
                out.add(u);
            }
        }
        return out;
    }

    private static List<Unit__c> bookableOnly(List<Unit__c> units) {
        if (units == null || units.isEmpty()) {
            return units;
        }
        Set<Id> editable = new Set<Id>();
        Id uid = UserInfo.getUserId();
        // UserRecordAccess takes at most 200 ids per query
        List<Id> chunk = new List<Id>();
        for (Integer i = 0; i < units.size(); i++) {
            chunk.add(units[i].Id);
            if (chunk.size() == 200 || i == units.size() - 1) {
                for (UserRecordAccess a : [
                    SELECT RecordId
                    FROM UserRecordAccess
                    WHERE UserId = :uid AND RecordId IN :chunk AND HasEditAccess = TRUE
                ]) {
                    editable.add(a.RecordId);
                }
                chunk.clear();
            }
        }
        List<Unit__c> bookable = new List<Unit__c>();
        for (Unit__c u : units) {
            if (editable.contains(u.Id)) {
                bookable.add(u);
            }
        }
        return bookable;
    }

    /** The whole unit screen in one payload. */
    public class UnitBrowserDTO {
        @AuraEnabled public List<Map<String, String>> projects = new List<Map<String, String>>();
        @AuraEnabled public List<Map<String, String>> phases = new List<Map<String, String>>();
        @AuraEnabled public String selectedProjectId;
        @AuraEnabled public String selectedPhaseId;
        @AuraEnabled public UnitSearchLwcController.UnitDataWrapper units;
    }

    /**
     * Projects, phases and units in one round trip (was three chained uncacheable calls).
     * Same internals, ordering and filters. Also serves a project change: pass projectId,
     * leave phaseId blank.
     */
    @AuraEnabled(cacheable=false)
    public static UnitBrowserDTO getUnitBrowser(
        String opportunityId, String projectId, String phaseId
    ) {
        UnitBrowserDTO dto = new UnitBrowserDTO();
        try {
            dto.projects = getProjects(opportunityId);

            /* the booking's own unit decides where the grid opens when the caller names nothing */
            Unit__c journeyUnit = String.isBlank(opportunityId)
                ? null
                : journeyUnitFor((Id) opportunityId);

            dto.selectedProjectId = String.isNotBlank(projectId)
                ? projectId
                : defaultProject(dto.projects, journeyUnit);
            if (String.isBlank(dto.selectedProjectId)) {
                return dto;
            }

            dto.phases = getPhases(dto.selectedProjectId);
            dto.selectedPhaseId = String.isNotBlank(phaseId)
                ? phaseId
                : defaultPhase(dto.phases, dto.selectedProjectId, opportunityId, journeyUnit);

            /* MSC-213: a fully-defaulted open (no project, no phase, no booked unit) must not
               strand the rep on a project they cannot book in - org-wide inventory depth says
               nothing about this rep's bucket. The re-check is a memo hit, not a re-query. */
            if (String.isBlank(projectId) && String.isBlank(phaseId) && journeyUnit == null
                    && String.isBlank(
                        firstBookablePhase(dto.phases, dto.selectedProjectId, opportunityId))) {
                retargetToBookableProject(dto, opportunityId);
            }

            if (String.isBlank(dto.selectedPhaseId)) {
                return dto;
            }

            dto.units = searchUnits(
                (Id) dto.selectedPhaseId, opportunityId,
                null, null, null, null, null, null
            );
        } catch (Exception e) {
            /* a failure here must leave working dropdowns; return whatever resolved */
            System.debug(LoggingLevel.WARN,
                'getUnitBrowser: partial result - ' + e.getMessage());
        }
        return dto;
    }

    /**
     * Which project the unit grid opens on when the caller names none. With an opportunity,
     * getAllProjects is alphabetical, so index 1 could be a project with no stock; the meta row
     * at index 0 carries the opportunity's own project. Falls through to the first project with
     * stock, then to index 1.
     */
    private static String defaultProject(
        List<Map<String, String>> rows, Unit__c journeyUnit
    ) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }
        /* 0. the unit the booking is actually on, ahead of the interest field */
        if (journeyUnit != null && journeyUnit.Phase__r != null
                && journeyUnit.Phase__r.Project__c != null) {
            String fromUnit = String.valueOf(journeyUnit.Phase__r.Project__c);
            for (Map<String, String> row : rows) {
                if (fromUnit == row.get('value')) {
                    return fromUnit;
                }
            }
        }
        // 1. the opportunity's own project, matched by label
        String interest = rows[0].get('projectInterest');
        if (String.isNotBlank(interest)) {
            for (Integer i = 1; i < rows.size(); i++) {
                if (interest.equalsIgnoreCase(rows[i].get('label'))) {
                    return rows[i].get('value');
                }
            }
        }
        // 2. otherwise the deepest inventory
        try {
            Map<Id, Integer> stock = availableUnitsByProject();
            String best;
            Integer bestCount = 0;
            for (Integer i = 1; i < rows.size(); i++) {
                String value = rows[i].get('value');
                Integer count = String.isBlank(value) ? null : stock.get((Id) value);
                if (count != null && count > bestCount) {
                    bestCount = count;
                    best = value;
                }
            }
            if (String.isNotBlank(best)) {
                return best;
            }
        } catch (Exception e) {
            /* ordering help only; fall through to index 1 */
        }
        // 3. index 1, as before
        return firstValue(rows);
    }

    /** Index 0 of both lists is getAllProjects' meta row. */
    /**
     * Which phase the grid opens on: the phase holding the booking's unit, else the first phase
     * this rep can actually book in, else the first row. MSC-213: the doc always said "with
     * stock" but the code took the first row - and org-wide stock was never this rep's bucket.
     */
    private static String defaultPhase(
        List<Map<String, String>> rows, String projectId, String opportunityId,
        Unit__c journeyUnit
    ) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }
        if (journeyUnit != null && journeyUnit.Phase__c != null) {
            String fromUnit = String.valueOf(journeyUnit.Phase__c);
            for (Map<String, String> row : rows) {
                if (fromUnit == row.get('value')) {
                    return fromUnit;
                }
            }
        }
        String bookable = firstBookablePhase(rows, projectId, opportunityId);
        if (String.isNotBlank(bookable)) {
            return bookable;
        }
        /* nothing bookable anywhere in this project: the first row, and the grid says so */
        return firstValue(rows);
    }

    /* MSC-213: cap, so a huge phase list cannot spend the transaction on picking a default */
    private static final Integer PHASE_PICK_UNIT_CAP = 1000;

    /** Per-transaction memo: projectId -> first bookable phase id, or '' for "none found". */
    private static Map<String, String> bookablePhaseByProject = new Map<String, String>();

    /**
     * MSC-213. The first listed phase (display order) holding a unit this rep can actually
     * book: Available, not on a live hold, and HasEditAccess - the same three predicates
     * searchUnits applies after the fact (bookableOnly + notOnLiveHold). Null when no listed
     * phase qualifies within the cap; fails open to null so the caller falls back.
     */
    private static String firstBookablePhase(
        List<Map<String, String>> phaseRows, String projectId, String opportunityId
    ) {
        /* the opportunity never changes inside one transaction, so the project keys the memo */
        String memoKey = String.isBlank(projectId) ? '' : projectId;
        if (bookablePhaseByProject.containsKey(memoKey)) {
            String hit = bookablePhaseByProject.get(memoKey);
            return String.isBlank(hit) ? null : hit;
        }
        String answer = null;
        try {
            answer = firstBookablePhaseUncached(phaseRows, opportunityId);
        } catch (Exception e) {
            /* picking a default must never break the browser */
            System.debug(LoggingLevel.WARN,
                'firstBookablePhase: unavailable - ' + e.getMessage());
        }
        bookablePhaseByProject.put(memoKey, answer == null ? '' : answer);
        return answer;
    }

    private static String firstBookablePhaseUncached(
        List<Map<String, String>> phaseRows, String opportunityId
    ) {
        if (phaseRows == null || phaseRows.isEmpty()) {
            return null;
        }
        List<Id> order = new List<Id>();
        Set<Id> phaseIds = new Set<Id>();
        for (Map<String, String> row : phaseRows) {
            String v = row.get('value');
            /* the meta row carries no value */
            if (String.isNotBlank(v) && phaseIds.add((Id) v)) {
                order.add((Id) v);
            }
        }
        if (order.isEmpty()) {
            return null;
        }
        Datetime asOf = System.now();
        Id uid = UserInfo.getUserId();
        Id oppId = String.isBlank(opportunityId) ? null : (Id) opportunityId;
        /* the same availability arms getUnitDetails queries with - minus its held-by-me arm,
           which notOnLiveHold strips again anyway (MSC-164: a held unit is offered to nobody) */
        List<Unit__c> units = [
            SELECT Id, Phase__c
            FROM Unit__c
            WHERE Phase__c IN :phaseIds
              AND ((Status__c = :Constants.STATUS_AVAILABLE AND Sub_Status__c = 'Un-Assigned')
                   OR (Sub_Status__c = 'Assigned' AND BlockedFor__c = :uid))
              AND (Payment_In_Progress__c = FALSE
                   OR (Payment_Hold_Expiry__c != NULL AND Payment_Hold_Expiry__c < :asOf))
              AND (Opportunity__c = NULL OR Opportunity__c = :oppId)
            LIMIT :PHASE_PICK_UNIT_CAP
        ];
        if (units.isEmpty()) {
            return null;
        }
        /* edit access, as bookableOnly checks it; 200 ids per UserRecordAccess query */
        Set<Id> editable = new Set<Id>();
        List<Id> chunk = new List<Id>();
        for (Integer i = 0; i < units.size(); i++) {
            chunk.add(units[i].Id);
            if (chunk.size() == 200 || i == units.size() - 1) {
                for (UserRecordAccess a : [
                    SELECT RecordId
                    FROM UserRecordAccess
                    WHERE UserId = :uid AND RecordId IN :chunk AND HasEditAccess = TRUE
                ]) {
                    editable.add(a.RecordId);
                }
                chunk.clear();
            }
        }
        if (editable.isEmpty()) {
            return null;
        }
        Set<Id> phasesWithBookable = new Set<Id>();
        for (Unit__c u : units) {
            if (editable.contains(u.Id)) {
                phasesWithBookable.add(u.Phase__c);
            }
        }
        for (Id p : order) {
            if (phasesWithBookable.contains(p)) {
                return String.valueOf(p);
            }
        }
        return null;
    }

    /**
     * MSC-213. A fully-defaulted open found nothing bookable in the picked project: walk the
     * remaining projects, deepest org inventory first (the order defaultProject already
     * prefers), and land on the first with a phase this rep can book in. Bounded to a few
     * candidates; leaves the dto exactly as it was when none qualifies.
     */
    private static void retargetToBookableProject(UnitBrowserDTO dto, String opportunityId) {
        Map<Id, Integer> stock;
        try {
            stock = availableUnitsByProject();
        } catch (Exception e) {
            return;
        }
        /* candidates: every listed project but the current pick, deepest stock first */
        List<String> candidates = new List<String>();
        for (Map<String, String> row : dto.projects) {
            String v = row.get('value');
            if (String.isNotBlank(v) && v != dto.selectedProjectId) {
                candidates.add(v);
            }
        }
        for (Integer i = 0; i < candidates.size(); i++) {
            for (Integer j = i + 1; j < candidates.size(); j++) {
                Integer a = stock.get((Id) candidates[i]);
                Integer b = stock.get((Id) candidates[j]);
                if ((b == null ? 0 : b) > (a == null ? 0 : a)) {
                    String swap = candidates[i];
                    candidates[i] = candidates[j];
                    candidates[j] = swap;
                }
            }
        }
        Integer tried = 0;
        for (String pid : candidates) {
            if (tried >= 3) {
                break;
            }
            /* a project with no org-wide stock has nothing for this rep either */
            Integer projectStock = stock.get((Id) pid);
            if (projectStock == null || projectStock == 0) {
                break;
            }
            tried++;
            List<Map<String, String>> phases = getPhases(pid);
            String phase = firstBookablePhase(phases, pid, opportunityId);
            if (String.isNotBlank(phase)) {
                dto.selectedProjectId = pid;
                dto.phases = phases;
                dto.selectedPhaseId = phase;
                return;
            }
        }
    }

    private static String firstValue(List<Map<String, String>> rows) {
        if (rows == null) {
            return null;
        }
        for (Map<String, String> row : rows) {
            String v = row.get('value');
            if (String.isNotBlank(v)) {
                return v;
            }
        }
        return null;
    }

    /**
     * Everything the plan panel needs in one call: the offer (plans and template milestones), the
     * fee preview, and whether this unit is pay-first.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getUnitConfiguration(Id unitId, Id opportunityId) {
        Map<String, Object> out = new Map<String, Object>();
        if (unitId == null) {
            return out;
        }
        try {
            UnitSearchLwcController.UnitDetailsWrapper offer =
                UnitSearchLwcController.generateSalesOffer(String.valueOf(unitId), false);
            out.put('offer', offer);

            Unit__c unit = loadUnit(unitId);
            out.put('unit', toUnitBlock(unit));

            /* always put the key: an absent key reads as undefined on the client and was stored as
               a settled "no fee required" */
            out.put('paymentRequired',
                opportunityId == null
                    ? false
                    : UnitBookingJourneyController.isPaymentRequired(unitId, opportunityId));
            /* 1.77 - the Sales App offers an EOI only where the unit's phase requires one */
            out.put('eoiRequired', eoiRequiredUnits(new Set<Id>{ unitId }).contains(unitId));
            /* 1.79 - the options the rep may choose, as the Sales App offers them to this buyer */
            out.put('unitOptions', unitOptionConfig(offer, unitId, opportunityId));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return out;
    }

    /** Fee preview. Pure read. */
    @AuraEnabled(cacheable=false)
    public static BookingFeeLineController.FeePreview previewFees(
        Id unitId, Id planId, Decimal totalAmount
    ) {
        return BookingFeeLineController.previewBookingFees(unitId, planId, totalAmount);
    }

    /* Taking the booking payment. Thin delegates: fee maths in BookingFeeLineController, the hold
     * in UnitBookingJourneyController, matching lwc/unitBookingJourney. */

    /**
     * Does this booking take a booking fee? Per opportunity (Bypass_Modon_Pay__c before the
     * phase's Payment_Required__c), so it is asked when the opportunity exists rather than cached
     * from the unit configuration.
     */
    @AuraEnabled(cacheable=false)
    public static Boolean isPaymentRequired(Id unitId, Id opportunityId) {
        if (unitId == null || opportunityId == null) {
            return false;
        }
        try {
            return UnitBookingJourneyController.isPaymentRequired(unitId, opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** 1.74: whether the page must take a booking fee, and whether an EOI covers it. */
    public class FeeNeedDTO {
        /** True when the booking fee has to be taken before Confirm. */
        @AuraEnabled public Boolean required = false;
        /** True when a fee would apply but the unit's EOI covers it (switch on). */
        @AuraEnabled public Boolean coveredByEoi = false;
    }

    /**
     * 1.74: the page's question, with the EOI taken into account. isPaymentRequired is MODON's
     * answer (phase and opportunity); eoiCoversFee is the switch plus a valid EOI on this unit.
     */
    @AuraEnabled(cacheable=false)
    public static FeeNeedDTO getBookingFeeNeed(Id unitId, Id opportunityId, String eoiMappingJson) {
        FeeNeedDTO out = new FeeNeedDTO();
        if (!isPaymentRequired(unitId, opportunityId)) {
            return out;
        }
        try {
            out.coveredByEoi = eoiCoversFee(opportunityId, unitId, eoiMappingJson);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        out.required = !out.coveredByEoi;
        return out;
    }

    /**
     * 1.74: does this unit's EOI stand in for the booking fee? Only with the switch on, and only
     * for an EOI the engine lists as eligible (validatedEoiMapping) with a cleared receipt
     * (getBookingEois). Everything is read here; the decision itself is decideFeeByEoi.
     */
    private static Boolean eoiCoversFee(Id opportunityId, Id unitId, String eoiMappingJson) {
        if (!AurelixEoiBookingFee.isOn() || opportunityId == null || unitId == null
                || String.isBlank(eoiMappingJson)) {
            return false;
        }
        EoiMappingCheck check = validatedEoiMapping(eoiMappingJson, new Set<Id>{ unitId }, opportunityId);
        if (check.error != null) {
            return false;
        }
        Map<String, Boolean> receiptByEoi = new Map<String, Boolean>();
        for (BookingEoiDTO d : getBookingEois(opportunityId, null).eois) {
            receiptByEoi.put(String.valueOf(d.eoiId), d.hasReceipt == true);
        }
        return decideFeeByEoi(true, unitId, check.mappingJson, receiptByEoi);
    }

    /** 1.74: the rule on values alone, so it can be tested without data. */
    @TestVisible
    private static Boolean decideFeeByEoi(
        Boolean switchOn, Id unitId, String cleanMappingJson, Map<String, Boolean> receiptByEoi
    ) {
        if (switchOn != true || unitId == null || String.isBlank(cleanMappingJson)) {
            return false;
        }
        Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(cleanMappingJson);
        Object eoiId = mapping.get(String.valueOf(unitId));
        if (eoiId == null) {
            return false;
        }
        return receiptByEoi != null && receiptByEoi.get(String.valueOf(eoiId)) == true;
    }

    /** What is owed and how much has been received. */
    @AuraEnabled(cacheable=false)
    public static BookingFeeLineController.FeeStatus getFeeStatus(Id opportunityId, Id unitId) {
        try {
            return BookingFeeLineController.getBookingFeeStatus(
                String.valueOf(opportunityId), String.valueOf(unitId)
            );
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /**
     * The hold window, for the confirmation prompt. Coupled to
     * UnitBookingJourneyController.holdMinutes(): same label, same fallback.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getPaymentHoldMinutes() {
        try {
            Integer mins = Integer.valueOf(System.Label.Unit_Hold_Minutes_1_Unit);
            if (mins != null && mins > 0) {
                return mins;
            }
        } catch (Exception e) {
            // fall through, as the journey does
        }
        return 10;
    }

    /* MSC-153. Money is collected against a unit and a plan (Booking_Fee_Line__c). The client's
       navigation floor stops the rep walking back; these two writers guard a stale tab or a
       direct call. */

    private class Collected {
        Id unitId;
        Id planId;
        Decimal paid = 0;
        String unitName;
    }

    /**
     * What has been collected on this booking, and against what. Partial counts
     * (Total_Paid_Amount__c > 0). Fails open: the client's floor is the first guard.
     */
    private static Collected collectedFor(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        try {
            for (Booking_Fee_Line__c l : [
                SELECT Unit__c, Unit__r.Name, Payment_Plan__c, Total_Paid_Amount__c
                FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :opportunityId AND Total_Paid_Amount__c > 0
                ORDER BY Total_Paid_Amount__c DESC
                LIMIT 1
            ]) {
                Collected c = new Collected();
                c.unitId   = l.Unit__c;
                c.planId   = l.Payment_Plan__c;
                c.paid     = l.Total_Paid_Amount__c;
                c.unitName = l.Unit__r == null ? null : l.Unit__r.Name;
                return c;
            }
        } catch (Exception e) {
            // the client's floor is the guard that must hold
        }
        return null;
    }

    /**
     * Null when this action is safe; the reason otherwise. The same unit on the same plan is
     * always allowed (finishing a part-paid fee).
     */
    private static String moneyGuard(Id opportunityId, Id unitId, Id planId) {
        Collected c = collectedFor(opportunityId);
        if (c == null) {
            return null;
        }
        Boolean unitMoved = unitId != null && c.unitId != null && unitId != c.unitId;
        Boolean planMoved = planId != null && c.planId != null && planId != c.planId;
        if (!unitMoved && !planMoved) {
            return null;
        }
        return 'AED ' + c.paid.setScale(2).format()
            + ' has already been collected'
            + (String.isBlank(c.unitName) ? '' : ' on ' + c.unitName)
            + ', so the ' + (unitMoved ? 'unit' : 'payment plan')
            + ' cannot be changed. Sales Operations can move or refund a payment '
            + 'that has already been taken.';
    }

    /**
     * MSC-165. Null when Take payment is safe; the reason otherwise. Refused before the savepoint.
     * Does not refuse the rep's own hold (Take payment extends it and is the way back into a
     * resumed booking) or an expired hold (the flag outlives the hold). Adds to
     * initiatePaymentHold's check, which passes a hold with a null expiry.
     */
    private static String holdGuard(Id unitId) {
        if (unitId == null) {
            return null;
        }
        Datetime asOf = System.now();
        Id me = UserInfo.getUserId();
        for (Unit__c u : [
            SELECT Id, Name, Payment_In_Progress__c, Payment_Hold_Expiry__c, Payment_Hold_By__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ]) {
            if (u.Payment_In_Progress__c != true) {
                return null;
            }
            Boolean live = u.Payment_Hold_Expiry__c == null || u.Payment_Hold_Expiry__c > asOf;
            if (!live || u.Payment_Hold_By__c == me) {
                return null;
            }
            return 'Unit ' + u.Name + ' is already at the payment terminal for another '
                + 'booking. It becomes available again when that hold expires or is released.';
        }
        return null;
    }

    /**
     * Raise the booking fee, then hold the unit (lwc/unitBookingJourney's sequence). Safe to call
     * more than once: syncBookingFeeLines is keyed on unit + fee type. Returns the fee status.
     */
    @AuraEnabled
    public static BookingFeeLineController.FeeStatus beginPayment(ConfirmRequest req) {
        /* 1.84 - with payment links on, the MODON Pay card page is not offered */
        if (AurelixBookingFeeLink.isOn()) {
            throw refusedAsIs(FEE_BY_LINK_REFUSAL);
        }
        return holdForFee(req, false);
    }

    /** 1.84 - the MODON Pay card page asked for while links are on. */
    @TestVisible
    private static final String FEE_BY_LINK_REFUSAL =
        'The booking fee is paid by payment link. Use Send payment link.';

    /** 1.84 - a link asked for while the switch is off. */
    @TestVisible
    private static final String FEE_BY_TERMINAL_REFUSAL =
        'The booking fee is taken at the MODON Pay terminal. Use Take payment.';

    /**
     * beginPayment's body: every check, the fee lines, the hold and the reservation, all or nothing.
     * `linkRun` also starts a payment link run on the unit (AurelixBookingFeeLink.beginRun).
     */
    private static BookingFeeLineController.FeeStatus holdForFee(ConfirmRequest req, Boolean linkRun) {
        if (req == null || req.opportunityId == null || req.unitId == null) {
            throw new AuraHandledException('Select a unit before taking payment.');
        }
        if (req.paymentPlanId == null) {
            throw new AuraHandledException('Select a payment plan before taking payment.');
        }
        /* Phase 4: before the savepoint, before moneyGuard, before any fee line or hold exists.
           This is the earliest point at which the request is understood, and nothing has been
           written yet. */
        assertKycEligibleForMoney(req.opportunityId);
        /* 1.69: the EOI gates, before any money is asked for - a fee taken on a unit the Sales
           App would refuse could not then be booked. 1.81: with the rep's EOI choice, so no fee
           is taken until an EOI is chosen. */
        EoiGateDTO eoiCheck = eoiGate(req.opportunityId, new List<Id>{ req.unitId },
            req.eoiMappingJson, true);
        if (!eoiCheck.ok) {
            throw refusedAsIs(eoiCheck.message);
        }
        EoiMappingCheck eoiChoice = validatedEoiMapping(
            req.eoiMappingJson, new Set<Id>{ req.unitId }, req.opportunityId);
        if (eoiChoice.error != null) {
            throw refusedAsIs(eoiChoice.error);
        }
        /* 1.75: a phase that needs a facade style must have one before any money is taken, or
           saveSalesOrder would refuse the booking after the fee. Presence only; the engine checks
           the value against MODON's list at confirm. */
        String facadeMissing = facadeGuard(req.unitId, req.facadeStyle);
        if (facadeMissing != null) {
            throw new AuraHandledException(facadeMissing);
        }
        /* 1.77: the Sales App's unit checks, before any money */
        String unitProblem = unitStatusGuard(new List<Id>{ req.unitId });
        if (unitProblem == null) {
            unitProblem = unitOptionGuard(req.unitId, req.unitOptionId, req.opportunityId);
        }
        if (unitProblem != null) {
            throw new AuraHandledException(unitProblem);
        }
        /* MSC-153: before the savepoint, this refuses rather than rolls back */
        String moved = moneyGuard(req.opportunityId, req.unitId, req.paymentPlanId);
        if (moved != null) {
            throw new AuraHandledException(moved);
        }
        /* MSC-165: same */
        String atTerminal = holdGuard(req.unitId);
        if (atTerminal != null) {
            throw new AuraHandledException(atTerminal);
        }
        /* fee lines and hold are one action or neither: lines without a hold have no expiry, and
           only the Release Expired Payment Hold flow ever clears abandoned lines */
        Savepoint sp = Database.setSavepoint();
        try {
            Unit__c unit = loadUnit(req.unitId);
            SalesOrder__c so = buildSalesOrder(req, unit);

            // returns an error string rather than throwing
            String sync = BookingFeeLineController.syncBookingFeeLines(
                new List<SalesOrder__c>{ so }, String.valueOf(req.opportunityId));
            if (!isSaveSuccess(sync)) {
                /* 1.85: MODON's sentence as unitBookingJourney shows it */
                throw refusedAsIs(modonsWords(sync));
            }

            UnitBookingJourneyController.HoldResult hold =
                UnitBookingJourneyController.initiatePaymentHold(req.unitId, req.opportunityId);
            if (hold == null || hold.status != 'Success') {
                throw refusedAsIs(
                    hold == null ? 'The unit could not be held.' : modonsWords(hold.status));
            }

            /* 1.84 - reserve the unit as soon as it is held; a refusal undoes the fee lines and the hold */
            String notReserved = AurelixUnitReservation.reserve(req.opportunityId, req.unitId);
            if (notReserved != null) {
                throw refusedAsIs(notReserved);
            }
            if (linkRun == true) {
                AurelixBookingFeeLink.beginRun(req.unitId);
            }

            return BookingFeeLineController.getBookingFeeStatus(
                String.valueOf(req.opportunityId), String.valueOf(req.unitId));
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (DmlException e) {
            /* the one failure worth naming: the agent cannot edit this unit */
            Database.rollback(sp);
            /* 1.85: a MODON validation rule's sentence as is; anything else as before */
            String message = wordsFor(e);
            if (e.getNumDml() > 0
                && e.getDmlType(0) == StatusCode.INSUFFICIENT_ACCESS_OR_READONLY) {
                message = 'You do not have access to reserve this unit. '
                    + 'Ask your administrator to assign it to you.';
            }
            throw new AuraHandledException(message);
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /**
     * 1.75 - the engine's own refusal (UnitSearchLwcController 17.0) when the unit's phase needs a
     * facade style and none was chosen; null when none is needed or one was given.
     */
    /* ══ 1.77 - the Sales App's unit rules ══════════════════════════════════════ */

    /** MODON's checkUnitStatus, as the Sales App calls it; null when it answers Success. */
    @TestVisible
    private static String unitStatusGuard(List<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) { return null; }
        List<String> ids = new List<String>();
        for (Id u : unitIds) { if (u != null) { ids.add(String.valueOf(u)); } }
        if (ids.isEmpty()) { return null; }
        String r = UnitSearchLwcController.checkUnitStatus(ids);
        return String.isBlank(r) || r == 'Success' ? null : r;
    }

    /**
     * The options the Sales App lists for a unit (generateSalesOffer): Unit_Option__c on the unit or
     * on its phase, one per name, the unit's own winning over the phase's.
     */
    @TestVisible
    private static Map<Id, Unit_Option__c> unitOptionsFor(Id unitId) {
        Map<Id, Unit_Option__c> out = new Map<Id, Unit_Option__c>();
        if (unitId == null) { return out; }
        Id phaseId;
        for (Unit__c u : [SELECT Phase__c FROM Unit__c WHERE Id = :unitId LIMIT 1]) { phaseId = u.Phase__c; }
        Map<String, Unit_Option__c> byName = new Map<String, Unit_Option__c>();
        List<Unit_Option__c> rows = phaseId == null
            ? [SELECT Id, Name, Phase__c, Unit__c, TotalPrice__c FROM Unit_Option__c WHERE Unit__c = :unitId]
            : [SELECT Id, Name, Phase__c, Unit__c, TotalPrice__c FROM Unit_Option__c
               WHERE Unit__c = :unitId OR Phase__c = :phaseId];
        for (Unit_Option__c o : rows) { if (o.Phase__c != null) { byName.put(o.Name, o); } }
        for (Unit_Option__c o : rows) { if (o.Unit__c != null) { byName.put(o.Name, o); } }
        for (Unit_Option__c o : byName.values()) { out.put(o.Id, o); }
        return out;
    }

    /* ══ 1.79 - unit options as the Sales App offers them to this buyer ═════════════ */

    /** unitSearchLwc isWadeemProject: the selected project's name is exactly "Wadeem" (case matters). */
    @TestVisible
    private static final String WADEEM_PROJECT = 'Wadeem';

    @TestVisible
    private static Boolean isWadeemProject(String projectName) {
        /* equals, not ==: the Sales App compares in JavaScript, where case matters */
        return projectName != null && projectName.equals(WADEEM_PROJECT);
    }

    /** getUnitDetails isResidentCustomer: the primary contact's nationality is exactly this. */
    @TestVisible
    private static Boolean isUaeNational(String nationality) {
        return String.isNotEmpty(nationality) && nationality.equals('United Arab Emirates');
    }

    /** The buyer the Sales App calls a resident customer (the opportunity's primary contact). */
    private static Boolean buyerIsUaeNational(Id opportunityId) {
        if (opportunityId == null) { return false; }
        for (Opportunity o : [
            SELECT PrimaryContact__c, PrimaryContact__r.Nationality__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            return o.PrimaryContact__c != null && isUaeNational(o.PrimaryContact__r.Nationality__c);
        }
        return false;
    }

    private static String projectNameOfUnit(Id unitId) {
        if (unitId == null) { return null; }
        for (Unit__c u : [SELECT Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unitId LIMIT 1]) {
            return u.Phase__r == null || u.Phase__r.Project__r == null ? null : u.Phase__r.Project__r.Name;
        }
        return null;
    }

    /**
     * The rows the rep may choose from, from generateSalesOffer's availableUnitOptions (label,
     * value) in its order. The empty "--None--" row is dropped (the console's picker has its own
     * empty choice). Wadeem (unitSearchLwc generateOffer): only names containing "Option 1" or
     * "Type 1" for a UAE national, "Option 2" or "Type 2" for anyone else. A value listed twice (a
     * unit option and a phase option of the same name) is kept once.
     */
    @TestVisible
    private static List<Map<String, String>> salesAppOptionRows(
        List<Map<String, String>> available, Boolean wadeem, Boolean national
    ) {
        List<Map<String, String>> out = new List<Map<String, String>>();
        if (available == null) { return out; }
        Set<String> seen = new Set<String>();
        for (Map<String, String> row : available) {
            String value = row == null ? null : row.get('value');
            if (String.isBlank(value) || seen.contains(value)) { continue; }
            String label = row.get('label');
            if (wadeem == true) {
                String name = label == null ? '' : label;
                Boolean match = national == true
                    ? (name.contains('Option 1') || name.contains('Type 1'))
                    : (name.contains('Option 2') || name.contains('Type 2'));
                if (!match) { continue; }
            }
            seen.add(value);
            out.add(new Map<String, String>{ 'value' => value, 'label' => label });
        }
        return out;
    }

    /**
     * What the plan card offers for one unit: rows (value, label, and the price the option puts on
     * the order, null where it puts none), whether one must be chosen, and the option preselected:
     * the only one when there is exactly one, none when there are several (1.87). A live order keeps
     * the option it was saved with.
     */
    private static Map<String, Object> unitOptionConfig(
        UnitSearchLwcController.UnitDetailsWrapper offer, Id unitId, Id opportunityId
    ) {
        Map<String, Object> cfg = new Map<String, Object>();
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        cfg.put('rows', rows);
        cfg.put('required', false);
        cfg.put('defaultId', null);
        UnitSearchLwcController.UnitsUnitOptionDetails uo = offer == null ? null : offer.unitOptiontDetailObj;
        if (uo == null || uo.unitOptionLst == null || uo.unitOptionLst.isEmpty()) {
            return cfg;
        }
        Map<String, Decimal> priceById = new Map<String, Decimal>();
        for (UnitSearchLwcController.UnitOptionDetails d : uo.unitOptionLst) {
            if (d != null && d.unitOptionObj != null) {
                priceById.put(String.valueOf(d.unitOptionObj.Id), d.unitOptionObj.TotalPrice__c);
            }
        }
        Boolean wadeem = isWadeemProject(projectNameOfUnit(unitId));
        Boolean national = wadeem && buyerIsUaeNational(opportunityId);
        for (Map<String, String> r : salesAppOptionRows(uo.availableUnitOptions, wadeem, national)) {
            Decimal price = priceById.get(r.get('value'));
            rows.add(new Map<String, Object>{
                'value' => r.get('value'),
                'label' => r.get('label'),
                /* a Wadeem option does not reprice the order, as in the Sales App */
                'price' => wadeem || price == null || price <= 0 ? null : price
            });
        }
        cfg.put('required', !rows.isEmpty());
        /* 1.87 - one option is preselected; with several the rep picks */
        String chosen = rows.size() == 1 ? (String) rows[0].get('value') : null;
        String saved = savedOptionOf(opportunityId, unitId);
        for (Map<String, Object> r : rows) {
            if (saved != null && saved.equals((String) r.get('value'))) {
                chosen = saved;
            }
        }
        cfg.put('defaultId', chosen);
        return cfg;
    }

    /** 1.83 - the unit option a live order on this opportunity and unit was saved with, or null. */
    private static String savedOptionOf(Id opportunityId, Id unitId) {
        if (opportunityId == null || unitId == null) { return null; }
        List<String> dead = deadOrderStatuses();
        for (SalesOrder__c so : [
            SELECT UnitOption__c FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
              AND Status__c NOT IN :dead AND UnitOption__c != null
            ORDER BY CreatedDate DESC LIMIT 1
        ]) {
            return String.valueOf(so.UnitOption__c);
        }
        return null;
    }

    /**
     * An option is required where the Sales App offers any for this unit and buyer, and must be
     * one of those. Null when fine.
     */
    @TestVisible
    private static String unitOptionGuard(Id unitId, Id unitOptionId) {
        return unitOptionGuard(unitId, unitOptionId, null);
    }

    @TestVisible
    private static String unitOptionGuard(Id unitId, Id unitOptionId, Id opportunityId) {
        Map<Id, Unit_Option__c> options = unitOptionsFor(unitId);
        if (options.isEmpty() && unitOptionId == null) { return null; }
        String unitName = '';
        String projectName;
        for (Unit__c u : [SELECT Name, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unitId LIMIT 1]) {
            unitName = u.Name;
            projectName = u.Phase__r == null || u.Phase__r.Project__r == null ? null : u.Phase__r.Project__r.Name;
        }
        List<Map<String, String>> available = new List<Map<String, String>>();
        for (Unit_Option__c o : options.values()) {
            available.add(new Map<String, String>{ 'value' => String.valueOf(o.Id), 'label' => o.Name });
        }
        Boolean wadeem = isWadeemProject(projectName);
        Set<String> offered = new Set<String>();
        for (Map<String, String> r : salesAppOptionRows(
                available, wadeem, wadeem && buyerIsUaeNational(opportunityId))) {
            offered.add(r.get('value'));
        }
        if (unitOptionId == null) {
            /* the Sales App's sentence; nothing is owed where it offers nothing */
            return offered.isEmpty() ? null : 'Unit option is not selected for ' + unitName + ' unit.';
        }
        if (!offered.contains(String.valueOf(unitOptionId))) {
            return 'The selected unit option is not available for unit ' + unitName + '.';
        }
        return null;
    }

    public class SalesAppPrice {
        public Decimal amount;
        public String currencyCode;
    }

    /** 1.79 - unitSearchLwc isModonEgyptProfile: the user's profile name contains "Modon Egypt". */
    @TestVisible
    private static Boolean modonEgyptUserMemo;

    @TestVisible
    private static Boolean isModonEgyptProfile(String profileName) {
        return profileName != null && profileName.contains('Modon Egypt');
    }

    private static Boolean isModonEgyptUser() {
        if (modonEgyptUserMemo == null) {
            String profileName;
            for (User u : [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]) {
                profileName = u.Profile == null ? null : u.Profile.Name;
            }
            modonEgyptUserMemo = isModonEgyptProfile(profileName);
        }
        return modonEgyptUserMemo;
    }

    /**
     * The Sales App's Sales Order price (unitSearchLwc, the saveSalesOrder payload): the chosen
     * option's total when it has one, else the UnitPaymentPlanMapping__c base price for this unit,
     * plan and the plan's currency (Modon Egypt users only: generateSalesOffer returns mappings only
     * for them), else the unit's price; and the plan's currency. 1.79: in Wadeem the unit's price is
     * UAE_Citizen_Price__c for a UAE national (the unit's own price when that is blank), and the
     * option does not reprice the order.
     */
    @TestVisible
    private static SalesAppPrice salesAppPrice(Unit__c unit, Id unitOptionId, Id planId) {
        return salesAppPrice(unit, unitOptionId, planId, null);
    }

    @TestVisible
    private static SalesAppPrice salesAppPrice(Unit__c unit, Id unitOptionId, Id planId, Id opportunityId) {
        SalesAppPrice p = new SalesAppPrice();
        p.amount = unit == null ? null : unit.TotalPrice__c;
        if (planId != null) {
            for (PaymentPlan__c plan : [SELECT CurrencyIsoCode FROM PaymentPlan__c WHERE Id = :planId LIMIT 1]) {
                p.currencyCode = plan.CurrencyIsoCode;
            }
        }
        Boolean wadeem = false;
        if (unit != null && unit.Id != null) {
            for (Unit__c u : [
                SELECT UAE_Citizen_Price__c, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unit.Id LIMIT 1
            ]) {
                wadeem = isWadeemProject(
                    u.Phase__r == null || u.Phase__r.Project__r == null ? null : u.Phase__r.Project__r.Name);
                if (wadeem && u.UAE_Citizen_Price__c != null && buyerIsUaeNational(opportunityId)) {
                    p.amount = u.UAE_Citizen_Price__c;
                }
            }
        }
        if (unitOptionId != null && !wadeem) {
            for (Unit_Option__c o : [SELECT TotalPrice__c FROM Unit_Option__c WHERE Id = :unitOptionId LIMIT 1]) {
                if (o.TotalPrice__c != null && o.TotalPrice__c > 0) {
                    p.amount = o.TotalPrice__c;
                    return p;
                }
            }
        }
        if (unit != null && planId != null && isModonEgyptUser()) {
            for (UnitPaymentPlanMapping__c m : [
                SELECT Base_Price__c FROM UnitPaymentPlanMapping__c
                WHERE Unit__c = :unit.Id AND Payment_Plan__c = :planId AND CurrencyIsoCode = :p.currencyCode
                LIMIT 1
            ]) {
                if (m.Base_Price__c != null && m.Base_Price__c > 0) {
                    p.amount = m.Base_Price__c;
                }
            }
        }
        return p;
    }

    /** The units, of those given, whose phase requires an EOI. */
    @TestVisible
    private static Set<Id> eoiRequiredUnits(Set<Id> unitIds) {
        Set<Id> out = new Set<Id>();
        if (unitIds == null || unitIds.isEmpty()) { return out; }
        for (Unit__c u : [SELECT Id, Phase__r.EOI_Required__c FROM Unit__c WHERE Id IN :unitIds]) {
            if (u.Phase__r != null && u.Phase__r.EOI_Required__c == true) { out.add(u.Id); }
        }
        return out;
    }

    /** 1.77 - set by getBookingSummaryWithOption for the one summary it builds. */
    private static Decimal summaryPriceOverride;

    /** 1.77 - the summary priced as the Sales App prices the order: option, plan mapping, unit. */
    @AuraEnabled(cacheable=false)
    public static BookingSummaryDTO getBookingSummaryWithOption(
        Id opportunityId, Id unitId, Id paymentPlanId, Id salesOrderId, Id unitOptionId
    ) {
        try {
            if (salesOrderId == null && unitId != null) {
                Map<Id, Unit__c> units = loadUnits(new Set<Id>{ unitId });
                summaryPriceOverride = salesAppPrice(units.get(unitId), unitOptionId, paymentPlanId, opportunityId).amount;
            }
            return buildSummary(opportunityId, unitId, paymentPlanId, salesOrderId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        } finally {
            summaryPriceOverride = null;
        }
    }

    @TestVisible
    private static String facadeGuard(Id unitId, String facadeStyle) {
        if (unitId == null || String.isNotBlank(facadeStyle)) {
            return null;
        }
        for (Unit__c u : [SELECT Name, Phase__r.Facade_Style__c FROM Unit__c WHERE Id = :unitId LIMIT 1]) {
            if (u.Phase__r != null && u.Phase__r.Facade_Style__c == true) {
                return 'Please select a Facade Style for unit ' + u.Name + '.';
            }
        }
        return null;
    }

    /**
     * Hold the unit while the agent is at the terminal (Payment_In_Progress__c + expiry). The
     * console calls beginPayment instead; kept for a caller that wants the hold alone.
     */
    @AuraEnabled
    public static void startPaymentHold(Id unitId, Id opportunityId) {
        /* Phase 4: a hold takes the unit off other agents, so it is a commitment. Checked
           before initiatePaymentHold, which writes the hold fields. */
        assertKycEligibleForMoney(opportunityId);
        try {
            UnitBookingJourneyController.initiatePaymentHold(unitId, opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /**
     * Seconds left on the hold, or null when not held. Exposed on its own so the countdown can
     * resync without reloading the journey.
     */
    @AuraEnabled(cacheable=false)
    public static Integer getHoldSecondsRemaining(Id opportunityId, Id unitId) {
        if (opportunityId == null || unitId == null) {
            return null;
        }
        try {
            List<UnitBookingJourneyController.HeldUnit> held =
                UnitBookingJourneyController.getActiveJourneyState(opportunityId);
            if (held == null) {
                return null;
            }
            for (UnitBookingJourneyController.HeldUnit h : held) {
                if (h != null && h.unitId == unitId) {
                    return h.remainingSeconds;
                }
            }
            return null;
        } catch (Exception e) {
            /* the server enforces the hold regardless of the clock on screen */
            return null;
        }
    }

    /* ══ 1.84 - the booking fee by payment link ════════════════════════════════ */

    /** What Send payment link's first call answers: the fee and the links still to send. */
    public class FeeLinkStartDTO {
        @AuraEnabled public BookingFeeLineController.FeeStatus feeStatus;
        @AuraEnabled public AurelixBookingFeeLink.LinkState linkState;
    }

    /**
     * Send payment link, first call: beginPayment's checks (KYC first) and writes - the fee lines, the
     * hold, the reservation - and a new link run on the unit. The links themselves follow, one per call
     * (sendBookingFeeLink), because each is a callout and a callout cannot follow a write in one call.
     */
    @AuraEnabled
    public static FeeLinkStartDTO startBookingFeeLink(ConfirmRequest req) {
        if (!AurelixBookingFeeLink.isOn()) {
            throw refusedAsIs(FEE_BY_TERMINAL_REFUSAL);
        }
        FeeLinkStartDTO out = new FeeLinkStartDTO();
        out.feeStatus = holdForFee(req, true);
        out.linkState = AurelixBookingFeeLink.state(req.opportunityId, req.unitId);
        return out;
    }

    /**
     * Send payment link, one fee: MODON's booking link for that fee's balance (purpose 'ADM Fee' or
     * 'Down Payment'), sent to the customer by MODON's Checkout trigger. KYC is asserted again first:
     * no money is asked for without it. Reads only before the callout. Returns the link state.
     */
    @AuraEnabled
    public static AurelixBookingFeeLink.LinkState sendBookingFeeLink(Id opportunityId, Id unitId, String purpose) {
        if (!AurelixBookingFeeLink.isOn()) {
            throw refusedAsIs(FEE_BY_TERMINAL_REFUSAL);
        }
        assertKycEligibleForMoney(opportunityId);
        try {
            AurelixBookingFeeLink.send(opportunityId, unitId, purpose);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return AurelixBookingFeeLink.state(opportunityId, unitId);
    }

    /** The links, the reservation, and whether links are on at all. Not cacheable: it moves. */
    @AuraEnabled(cacheable=false)
    public static AurelixBookingFeeLink.LinkState getBookingFeeLinkState(Id opportunityId, Id unitId) {
        try {
            return AurelixBookingFeeLink.state(opportunityId, unitId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Resend link: the same stored message again for every live link. How many went out. */
    @AuraEnabled
    public static Integer resendBookingFeeLink(Id opportunityId, Id unitId) {
        try {
            return AurelixBookingFeeLink.resend(opportunityId, unitId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** 1.84 - Release unit asked for while the customer can still pay a link. */
    @TestVisible
    private static final String LINK_LIVE_REFUSAL =
        'A payment link is live for this unit. It can be released once the link expires.';

    /** Released after booking (the Sales Order reserves the unit). 1.81: the rep's cancel is cancelPaymentHold. */
    @AuraEnabled
    public static void endPaymentHold(Id unitId) {
        try {
            UnitBookingJourneyController.releasePaymentHold(new List<Id>{ unitId });
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** 1.81 - said when money already sits on the unit's fee lines. */
    @TestVisible
    private static final String HOLD_PAID_REFUSAL =
        'A payment has been received for this unit, so it cannot be released. '
        + 'Sales Operations can move or refund a payment that has already been taken.';

    /**
     * 1.81 - The rep releases the unit, live or lapsed hold, while nothing is paid (as the Sales App's
     * Cancel booking). Money is checked without sharing, then MODON's releasePaymentHold runs.
     */
    @AuraEnabled
    public static void cancelPaymentHold(Id opportunityId, Id unitId) {
        if (opportunityId == null || unitId == null) {
            throw refusedAsIs('Select a unit before releasing it.');
        }
        Boolean paid;
        try {
            paid = new FinanceReadContext().moneyOnFeeLines(opportunityId, unitId);
        } catch (Exception e) {
            /* never release on a question that could not be answered */
            throw refusedAsIs('The payments on this unit could not be checked, so it was not released. '
                + 'Please try again.');
        }
        if (paid) {
            throw refusedAsIs(HOLD_PAID_REFUSAL);
        }
        /* 1.84 - not while a payment link is live */
        if (AurelixBookingFeeLink.anyLive(opportunityId, unitId)) {
            throw refusedAsIs(LINK_LIVE_REFUSAL);
        }
        try {
            UnitBookingJourneyController.releasePaymentHold(new List<Id>{ unitId });
            /* 1.84 - and give the reservation back */
            AurelixUnitReservation.release(opportunityId, unitId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Payment terminal URL, from the Custom Label (differs per environment). */
    @AuraEnabled(cacheable=true)
    public static String getPaymentTerminalUrl() {
        return System.Label.Modon_Pay_Terminal_URL;
    }

    // 3. Booking Summary

    /** The always-visible panel. Pre-SO computes from unit, plan template and fee preview;
     * post-SO reads the SalesOrder__c and its installments. */
    @AuraEnabled(cacheable=false)
    public static BookingSummaryDTO getBookingSummary(
        Id opportunityId, Id unitId, Id paymentPlanId, Id salesOrderId
    ) {
        try {
            return buildSummary(opportunityId, unitId, paymentPlanId, salesOrderId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Basket form, same shape as getPaymentBucketsForOrders. The client refreshes the summary
     * after every proof upload and must not collapse a basket to one order. */
    @AuraEnabled(cacheable=false)
    public static BookingSummaryDTO getBookingSummaryForOrders(
        Id opportunityId, Id unitId, Id paymentPlanId, List<Id> salesOrderIds
    ) {
        try {
            return buildSummary(opportunityId, unitId, paymentPlanId, salesOrderIds);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    private static BookingSummaryDTO buildSummary(
        Id opportunityId, Id unitId, Id paymentPlanId, Id salesOrderId
    ) {
        return buildSummary(opportunityId, unitId, paymentPlanId,
            salesOrderId == null ? null : new List<Id>{ salesOrderId });
    }

    /**
     * Basket form, mirroring buildSettlement. The focused order (caller's unitId, else the first)
     * fills the singular fields; totalPrice, reference, stage, payments and the two lists come
     * from every order. Order of the set is preserved (CreatedDate ASC from getConsoleState).
     */
    private static BookingSummaryDTO buildSummary(
        Id opportunityId, Id unitId, Id paymentPlanId, List<Id> salesOrderIds
    ) {
        BookingSummaryDTO dto = new BookingSummaryDTO();
        dto.fees = new FeeBlock();
        dto.documents = new DocBlock();

        // every live order, in the order given
        List<SalesOrder__c> orders = loadSalesOrders(salesOrderIds);

        /* the focused order fills the singular fields */
        SalesOrder__c so = null;
        for (SalesOrder__c candidate : orders) {
            if (unitId != null && candidate.Unit__c == unitId) {
                so = candidate;
                break;
            }
        }
        if (so == null && !orders.isEmpty()) {
            so = orders[0];
        }
        Id salesOrderId = so == null ? null : so.Id;

        if (so != null) {
            dto.documents.furtherDocumentsRequired = so.Further_Documents_Required__c == true;
            if (unitId == null) {
                unitId = so.Unit__c;
            }
            if (paymentPlanId == null) {
                paymentPlanId = so.PaymentPlan__c;
            }
        }
        /* reference, stage and sub-stage are the booking's (first order); further documents is
           the focused order's */
        if (!orders.isEmpty()) {
            dto.bookingReference = orders[0].Name;
            dto.stage = orders[0].Status__c;
            dto.subStage = orders[0].Sub_Status__c;
            /* 1.78 - MODON closes the sale without moving Status__c. 1.80: same rule as Total Sales */
            dto.saleClosed = AurelixSaleClosed.isClosed(orders[0]);
        }

        /* the plan, when there is no Sales Order yet: read back from the fee lines */
        if (paymentPlanId == null && opportunityId != null && unitId != null) {
            paymentPlanId = planFromFeeLines(opportunityId, unitId);
        }

        /* every unit in the booking, one query; a pre-Confirm unit is loaded on its own */
        Set<Id> unitIds = new Set<Id>();
        for (SalesOrder__c o : orders) {
            if (o.Unit__c != null) {
                unitIds.add(o.Unit__c);
            }
        }
        if (unitId != null) {
            unitIds.add(unitId);
        }
        Map<Id, Unit__c> unitsById = unitIds.isEmpty()
            ? new Map<Id, Unit__c>() : loadUnits(unitIds);

        Unit__c unit = unitId == null ? null : unitsById.get(unitId);
        /* the focused unit's own price, which the fee preview is quoted on */
        Decimal focusedPrice = null;
        if (unit != null) {
            dto.unit = toUnitBlock(unit);
            focusedPrice = unit.TotalPrice__c;
        }
        if (so != null && so.TotalAmount__c != null) {
            focusedPrice = so.TotalAmount__c;
        } else if (so == null && summaryPriceOverride != null) {
            /* 1.77 - the Sales App's price for the chosen option or plan, before Confirm */
            focusedPrice = summaryPriceOverride;
        }
        /* 1.88 - the unit reads at the booking's price, as the basket list below already does */
        if (dto.unit != null && focusedPrice != null) {
            dto.unit.totalPrice = focusedPrice;
        }

        /* totalPrice is the booking's: one order's amount, or the sum of TotalAmount__c across
           orders (falling back to the unit price where an order has none) */
        if (orders.size() > 1) {
            Decimal sum = 0;
            for (SalesOrder__c o : orders) {
                Decimal price = o.TotalAmount__c;
                if (price == null && o.Unit__c != null && unitsById.containsKey(o.Unit__c)) {
                    price = unitsById.get(o.Unit__c).TotalPrice__c;
                }
                sum += (price == null ? 0 : price);
            }
            dto.totalPrice = sum;
        } else {
            dto.totalPrice = focusedPrice;
        }

        if (opportunityId != null) {
            dto.customer = loadCustomerBlock(opportunityId);
        }

        // the focused unit's plan, priced on the focused unit
        dto.plan = buildPlanBlock(paymentPlanId, salesOrderId, focusedPrice);

        /* the two lists, one entry per order, in booking order */
        for (SalesOrder__c o : orders) {
            UnitBlock ub = o.Unit__c == null ? null : toUnitBlock(unitsById.get(o.Unit__c));
            if (ub == null) {
                ub = new UnitBlock();
                ub.unitId = o.Unit__c;
            }
            /* the booked price wins over today's list price */
            if (o.TotalAmount__c != null) {
                ub.totalPrice = o.TotalAmount__c;
            }
            dto.units.add(ub);
            dto.plans.add(o.Id == salesOrderId
                ? dto.plan
                : buildPlanBlock(o.PaymentPlan__c, o.Id, o.TotalAmount__c));
        }
        dto.unitCount = dto.units.size();

        // fees: preview pre-SO, actual fee lines once they exist
        if (unitId != null && paymentPlanId != null) {
            BookingFeeLineController.FeePreview preview =
                BookingFeeLineController.previewBookingFees(unitId, paymentPlanId, focusedPrice);
            if (preview != null) {
                dto.fees.admFee = preview.admFee;
                dto.fees.downPayment = preview.downPayment;
                dto.fees.minimum = preview.minimum;
            }
        }
        if (opportunityId != null && unitId != null) {
            BookingFeeLineController.FeeStatus fs =
                BookingFeeLineController.getBookingFeeStatus(
                    String.valueOf(opportunityId), String.valueOf(unitId));
            if (fs != null) {
                dto.fees.totalDue = fs.totalDue;
                dto.fees.totalPaid = fs.totalPaid;
                dto.fees.totalBalance = fs.totalBalance;
                dto.fees.minimumMet = fs.isFullyPaid == true;
                dto.fees.allowPartialBooking = fs.allowPartialBooking == true;
                dto.collected = fs.totalPaid;
            }
        }
        dto.balance = (dto.totalPrice == null ? 0 : dto.totalPrice)
            - (dto.collected == null ? 0 : dto.collected);

        /* every order's obligations; buildBuckets stamps salesOrderId and unitName per row */
        dto.payments = buildBuckets(opportunityId, unitId,
            salesOrderIds == null || salesOrderIds.isEmpty() ? null : salesOrderIds);
        return dto;
    }

    /**
     * The orders behind a summary, re-sequenced to the input order. Ids that resolve to nothing
     * are dropped.
     */
    private static List<SalesOrder__c> loadSalesOrders(List<Id> salesOrderIds) {
        List<SalesOrder__c> ordered = new List<SalesOrder__c>();
        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            return ordered;
        }
        Map<Id, SalesOrder__c> byId = new Map<Id, SalesOrder__c>([
            SELECT Id, Name, Status__c, Sub_Status__c, Unit__c, PaymentPlan__c,
                   TotalAmount__c, CustomerAccount__c, Opportunity__c,
                   UAE_Resident_Status__c, Down_Payment_Status__c,
                   ADM_Fees_and_Dari__c, Further_Documents_Required__c,
                   SalesTeamVoidCheck__c, Opportunity__r.IsWon, Unit__r.Status__c
            FROM SalesOrder__c WHERE Id IN :salesOrderIds
        ]);
        for (Id soId : salesOrderIds) {
            if (soId != null && byId.containsKey(soId)) {
                ordered.add(byId.get(soId));
            }
        }
        return ordered;
    }

    private static PlanBlock buildPlanBlock(Id planId, Id salesOrderId, Decimal totalPrice) {
        PlanBlock block = new PlanBlock();
        if (salesOrderId != null) {
            // post-SO: the snapshot is authoritative
            for (SalesOrderInstallments__c soi : [
                SELECT Id, MilestoneNumber__c, MilestoneDescription__c, Milestone__c,
                       InstallmentAmount__c, MilestoneDate__c, PaymentStatus__c
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c = :salesOrderId
                ORDER BY MilestoneNumber__c ASC
            ]) {
                InstallmentRow row = new InstallmentRow();
                row.installmentId = soi.Id;
                row.milestoneNumber = soi.MilestoneNumber__c == null ? null : Integer.valueOf(soi.MilestoneNumber__c);
                row.description = soi.MilestoneDescription__c;
                row.percent = soi.Milestone__c;
                row.amount = soi.InstallmentAmount__c;
                row.dueDate = soi.MilestoneDate__c;
                row.status = soi.PaymentStatus__c;
                block.rows.add(row);
            }
        }
        if (block.rows.isEmpty() && planId != null) {
            // pre-SO: derive from the plan template
            List<PaymentPlan__c> plans = [
                SELECT Id, Name,
                       (SELECT Id, MilestoneNumber__c, MilestoneDescription__c,
                               Milestone__c, MilestoneDate__c
                        FROM Payment_Installments__r
                        ORDER BY MilestoneNumber__c ASC)
                FROM PaymentPlan__c
                WHERE Id = :planId
                LIMIT 1
            ];
            if (!plans.isEmpty()) {
                block.planId = plans[0].Id;
                block.planName = plans[0].Name;
                for (PaymentInstallements__c pi : plans[0].Payment_Installments__r) {
                    InstallmentRow row = new InstallmentRow();
                    row.milestoneNumber = pi.MilestoneNumber__c == null ? null : Integer.valueOf(pi.MilestoneNumber__c);
                    row.description = pi.MilestoneDescription__c;
                    row.percent = pi.Milestone__c;
                    row.dueDate = pi.MilestoneDate__c;
                    if (totalPrice != null && pi.Milestone__c != null) {
                        row.amount = (totalPrice * pi.Milestone__c / 100).setScale(2, System.RoundingMode.HALF_UP);
                    }
                    block.rows.add(row);
                }
            }
        }
        if (block.planId == null && planId != null) {
            block.planId = planId;
            for (PaymentPlan__c p : [SELECT Id, Name FROM PaymentPlan__c WHERE Id = :planId LIMIT 1]) {
                block.planName = p.Name;
            }
        }
        block.milestoneCount = block.rows.size();
        return block;
    }

    // 4. Payment buckets, one per obligation

    /**
     * One bucket per obligation, each with its own sourceId, required amount and proof list, so
     * proof uploads are separated by payment type.
     */
    @AuraEnabled(cacheable=false)
    public static List<PaymentBucketDTO> getPaymentBuckets(
        Id opportunityId, Id unitId, Id salesOrderId
    ) {
        try {
            return buildBuckets(opportunityId, unitId,
                salesOrderId == null ? null : new List<Id>{ salesOrderId });
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Basket form: one Sales Order per unit, all covered. Separate entry point so the
     * single-unit callers stay as they are. */
    @AuraEnabled(cacheable=false)
    public static List<PaymentBucketDTO> getPaymentBucketsForOrders(
        Id opportunityId, Id unitId, List<Id> salesOrderIds
    ) {
        try {
            return buildBuckets(opportunityId, unitId, salesOrderIds);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    private static List<PaymentBucketDTO> buildBuckets(
        Id opportunityId, Id unitId, List<Id> salesOrderIds
    ) {
        List<PaymentBucketDTO> buckets = new List<PaymentBucketDTO>();
        List<Id> orderIds = salesOrderIds == null ? new List<Id>() : salesOrderIds;
        /* per row sourceId, the invoice's unapplied remainder (InvoiceAmount - AppliedAmount):
           the cap on what a new payment may cover */
        Map<Id, Decimal> unappliedBySource = new Map<Id, Decimal>();
        // residency is the customer's, so the first order is representative
        String residency = residencyFor(
            opportunityId, orderIds.isEmpty() ? null : orderIds[0]);

        // the two booking fees
        if (opportunityId != null && unitId != null) {
            List<Booking_Fee_Line__c> feeLines = [
                SELECT Id, Type__c, Total_Amount__c, Total_Paid_Amount__c,
                       Balance_Amount__c, Status__c, Fee_Status__c
                FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
            ];
            /* 1.76: as in buildSettlement */
            if (!feeLinesCount(opportunityId, unitId, feeLines)) {
                feeLines.clear();
            }
            for (Booking_Fee_Line__c line : feeLines) {
                PaymentBucketDTO b = new PaymentBucketDTO();
                b.key = line.Type__c == FEE_TYPE_ADM ? BUCKET_ADM : BUCKET_DOWN;
                /* display label "ADM + Dari"; the restricted picklist value stays 'ADM Registration Fee' */
                b.label = line.Type__c == FEE_TYPE_ADM ? LABEL_ADM_DARI : LABEL_DOWN_PAYMENT;
                b.sourceId = line.Id;
                b.sourceObject = 'Booking_Fee_Line__c';
                b.requiredAmount = line.Total_Amount__c;
                b.paidAmount = line.Total_Paid_Amount__c;
                b.balanceAmount = line.Balance_Amount__c;
                b.status = String.isNotBlank(line.Fee_Status__c) ? line.Fee_Status__c : line.Status__c;
                // both booking fees gate confirmation
                b.blocksConfirmation = true;
                b.allowedMethods = methodsFor(b.key, residency);
                buckets.add(b);
            }
        }

        // milestones, for every order in the basket
        if (!orderIds.isEmpty()) {
            /* ordered by Sales Order so a basket's rows arrive grouped by unit */
            List<SalesOrderInstallments__c> soiList = [
                SELECT Id, MilestoneNumber__c, MilestoneDescription__c, Milestone__c,
                       InstallmentAmount__c, Balance_Amount__c, MilestoneDate__c,
                       PaymentStatus__c, SalesOrder__c, SalesOrder__r.Unit__r.Name
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c IN :orderIds
                ORDER BY SalesOrder__r.Unit__r.Name ASC, MilestoneNumber__c ASC
            ];
            Set<Id> soiIds = new Map<Id, SalesOrderInstallments__c>(soiList).keySet();
            FinanceReadContext finance = new FinanceReadContext();
            Map<Id, Decimal> paidMap = finance.paidByInstallment(soiIds);
            /* live payments and invoice per installment, and the ADM + Dari charge's own payments */
            Map<Id, List<Receipt__c>> receiptMap = finance.receiptsByInstallment(soiIds);
            Map<Id, Invoice__c> invoiceMap = finance.invoiceByInstallment(soiIds);
            Map<Id, List<Receipt__c>> admReceiptMap = finance.admReceiptsBySalesOrder(new Set<Id>(orderIds));

            /* the ADM + Dari charge, one row per order, ahead of its milestones; the booking-fee
               line above is the deposit toward this invoice */
            Map<Id, PaymentBucketDTO> admChargeRows = new Map<Id, PaymentBucketDTO>();
            for (Invoice__c inv : finance.admChargeBySalesOrder(new Set<Id>(orderIds)).values()) {
                PaymentBucketDTO a = new PaymentBucketDTO();
                a.key = BUCKET_ADM_CHARGE;
                a.label = LABEL_ADM_DARI;
                a.sourceId = inv.Id;
                a.sourceObject = 'Invoice__c';
                a.requiredAmount = nz(inv.InvoiceAmount__c);
                a.paidAmount = nz(inv.TotalPaidAmount__c);
                a.balanceAmount = inv.InvoiceBalance__c;
                /* due when raised; same date as Milestone 1 */
                a.dueDate = inv.InvoiceDate__c;
                a.status = inv.Status__c;
                a.blocksConfirmation = false;
                /* no Direct Debit: that is an installment instrument */
                a.allowedMethods = methodsFor(BUCKET_ADM, residency);
                a.salesOrderId = inv.Sales_Order__c;
                a.unitName = inv.Sales_Order__r != null && inv.Sales_Order__r.Unit__r != null
                    ? inv.Sales_Order__r.Unit__r.Name : null;
                /* payments standing against the charge, the cap on a new one, and the form records a Payment */
                a.instruments = toInstruments(admReceiptMap.get(inv.Sales_Order__c));
                a.withFinanceAmount = liveTotalOf(a.instruments);
                unappliedBySource.put(inv.Id, nz(inv.InvoiceAmount__c) - nz(inv.AppliedAmount__c));
                a.recordsPayment = true;
                admChargeRows.put(inv.Sales_Order__c, a);
            }

            Id lastOrder = null;
            for (SalesOrderInstallments__c soi : soiList) {
                if (soi.SalesOrder__c != lastOrder) {
                    lastOrder = soi.SalesOrder__c;
                    if (admChargeRows.containsKey(soi.SalesOrder__c)) {
                        buckets.add(admChargeRows.remove(soi.SalesOrder__c));
                    }
                }
                PaymentBucketDTO b = new PaymentBucketDTO();
                b.key = BUCKET_MILESTONE;
                Integer num = soi.MilestoneNumber__c == null
                    ? null : Integer.valueOf(soi.MilestoneNumber__c);
                b.milestoneNumber = num;
                b.label = 'Milestone ' + (num == null ? '' : String.valueOf(num))
                    + (String.isBlank(soi.MilestoneDescription__c)
                        ? '' : ' - ' + soi.MilestoneDescription__c);
                b.sourceId = soi.Id;
                b.sourceObject = 'SalesOrderInstallments__c';
                b.requiredAmount = soi.InstallmentAmount__c;
                b.paidAmount = paidMap.containsKey(soi.Id) ? paidMap.get(soi.Id) : 0;
                b.balanceAmount = soi.Balance_Amount__c;
                b.dueDate = soi.MilestoneDate__c;
                b.status = soi.PaymentStatus__c;
                b.blocksConfirmation = false;
                b.allowedMethods = methodsFor(BUCKET_MILESTONE, residency);
                /* milestones after the down payment are paid through the box */
                if (num != null && num > 1) {
                    b.allowedMethods = withoutBoxRoutes(b.allowedMethods);
                }
                b.instruments = toInstruments(receiptMap.get(soi.Id));
                b.withFinanceAmount = liveTotalOf(b.instruments);
                Invoice__c soiInvoice = invoiceMap.get(soi.Id);
                if (soiInvoice != null) {
                    unappliedBySource.put(soi.Id, nz(soiInvoice.InvoiceAmount__c) - nz(soiInvoice.AppliedAmount__c));
                }
                /* the down payment row records a Payment; later milestones carry no form */
                b.recordsPayment = num == null || num <= 1;
                // so a proof lands on the right booking
                b.salesOrderId = soi.SalesOrder__c;
                b.unitName = soi.SalesOrder__r != null && soi.SalesOrder__r.Unit__r != null
                    ? soi.SalesOrder__r.Unit__r.Name : null;
                buckets.add(b);
            }
            /* an order with a charge but no schedule still belongs in the list */
            buckets.addAll(admChargeRows.values());
        }

        /* the booking fees belong to whichever single order this is */
        if (!orderIds.isEmpty()) {
            for (PaymentBucketDTO b : buckets) {
                if (b.salesOrderId == null) {
                    b.salesOrderId = orderIds[0];
                }
            }
        }

        /* classify every row once, where both shapes meet */
        /* with the booking's own fee lines, they carry the two closing legs and milestone 1 must
           not claim the same leg again; a basket has no fee lines, so milestone 1 closes it */
        Boolean hasFeeLines = false;
        for (PaymentBucketDTO b : buckets) {
            if (b.key == BUCKET_ADM || b.key == BUCKET_DOWN) { hasFeeLines = true; break; }
        }
        /* pay-first, asked once for the whole list. The fee lines are the fact: a booking that
           raised them took a fee; one that raised none and shares its opportunity with another
           live order is a basket member and took none; only a booking with no lines and no
           company is left to isPaymentRequired. */
        Boolean oneUnit = hasFeeLines
            || (orderIds.size() <= 1 && liveOrderCountFor(opportunityId) <= 1);
        Boolean payFirst = oneUnit
            && (opportunityId != null && unitId != null)
            && phaseTakesFee(unitId, opportunityId);
        /* 1.85 - read once, only where a fee is taken */
        Boolean feeByLink = payFirst && AurelixBookingFeeLink.isOn();

        for (PaymentBucketDTO b : buckets) {
            b.closesSale = closesTheSale(b, hasFeeLines);
            /* to the fil; an invoice can store three decimals */
            Decimal remaining = fils(nz(b.requiredAmount) - nz(b.paidAmount));
            b.remainingAmount = remaining > 0 ? remaining : 0;
            b.proofRequired = b.remainingAmount > 0;
            b.withFinanceAmount = fils(nz(b.withFinanceAmount));
            /* what a new payment may still cover: what is left, capped at the invoice's unapplied
               remainder (Create_Receipt_SO / _SOI's gate); with no invoice, what is left less what
               is already standing */
            if (b.key == BUCKET_MILESTONE || b.key == BUCKET_ADM_CHARGE) {
                Decimal cap = unappliedBySource.get(b.sourceId);
                /* MSC-121. What is already recorded comes off, invoice or no invoice: an
                   installment's AppliedAmount__c does not move until Finance allocates, so the
                   invoice remainder alone asked for money already recorded. The recorded figure
                   sets the number; the invoice gate only caps it. Write path (openAmountFor)
                   is untouched. */
                Decimal open = b.remainingAmount - nz(b.withFinanceAmount);
                if (cap != null) {
                    open = Math.min(open, fils(cap));
                }
                b.openAmount = open > 0 ? open : 0;
            }
            b.paymentRequired = payFirst;
            /* the booking fee is collected at the terminal as one payment covering both legs */
            b.payRoute = (payFirst && (b.key == BUCKET_ADM || b.key == BUCKET_DOWN))
                ? ROUTE_TERMINAL
                : ROUTE_PROOF;
            /* 1.85 - with links on, the fee is paid through the link */
            b.payByLink = feeByLink && b.payRoute == ROUTE_TERMINAL;
        }

        attachProofs(buckets, orderIds);
        attachChequeReads(buckets);
        return buckets;
    }

    /**
     * Live Sales Orders on this opportunity (one per unit), same exclusion as bookedUnitsFor
     * (deadOrderStatuses). Zero when there is no opportunity.
     */
    private static Integer liveOrderCountFor(Id opportunityId) {
        if (opportunityId == null) {
            return 0;
        }
        List<String> dead = deadOrderStatuses();
        return [
            SELECT COUNT()
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
              AND Status__c NOT IN :dead
        ];
    }

    /**
     * Does paying this obligation satisfy a leg of SalesTeamVoidCheck__c? Booking fees always;
     * a milestone only if it is the first (InvoiceTriggerHelper keys Down_Payment_Status__c on
     * it). Does not touch blocksConfirmation: a basket's installments exist only after Confirm.
     */
    private static Boolean closesTheSale(PaymentBucketDTO b, Boolean hasFeeLines) {
        if (b.key == BUCKET_ADM || b.key == BUCKET_DOWN) {
            return true;
        }
        /* the ADM + Dari charge follows the milestone-1 rule: scheduled when fee lines carry the
           leg, closing otherwise */
        if (b.key == BUCKET_ADM_CHARGE) {
            return !hasFeeLines;
        }
        if (b.key != BUCKET_MILESTONE) {
            return false;
        }
        /* fee lines already carry both legs, so milestone 1 is a scheduled installment here */
        if (hasFeeLines) {
            return false;
        }
        if (b.milestoneNumber != null && b.milestoneNumber == 1) {
            return true;
        }
        return String.isNotBlank(b.label) && b.label.containsIgnoreCase('Down Payment');
    }

    /**
     * Does this plan have a schedule? createPaymentInstallments throws on a plan with no
     * installment rows and rolls the whole booking back, so ask first.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean planHasSchedule(Id paymentPlanId) {
        if (paymentPlanId == null) {
            return true; // nothing chosen yet is not a fault; other gates cover it
        }
        try {
            return [
                SELECT COUNT() FROM PaymentInstallements__c
                WHERE PaymentInstallment__c = :paymentPlanId
            ] > 0;
        } catch (Exception e) {
            /* an unreadable plan must not block here; saveSalesOrder is the authority */
            return true;
        }
    }

    /**
     * Payment methods by residency. Direct Debit is Residents-only; Non-Residents get
     * International Wire. Hard-coded: the org has no residency-to-method rule.
     */
    private static List<String> methodsFor(String bucketKey, String residency) {
        Boolean isResident = residency == RESIDENT;
        /* Modon's Mode of Payment values, since the row's Submit writes Receipt__c.Modeofpayment__c.
           Direct Debit is never a row method. */
        List<String> methods = new List<String>(PROOF_MODES);
        if (isResident) {
            methods.add(MOP_CHEQUE);
        }
        return methods;
    }

    /** Money still with Finance on a row: the sum of its live payments. */
    private static Decimal liveTotalOf(List<InstrumentDTO> instruments) {
        Decimal total = 0;
        if (instruments == null) {
            return total;
        }
        for (InstrumentDTO ins : instruments) {
            if (ins.live == true) {
                total += nz(ins.amount);
            }
        }
        return total;
    }

    /** Two decimals, half up. */
    private static Decimal fils(Decimal v) {
        return v == null ? 0 : v.setScale(2, System.RoundingMode.HALF_UP);
    }

    /** The two routes the box owns, taken off a milestone's method list. */
    private static List<String> withoutBoxRoutes(List<String> methods) {
        List<String> out = new List<String>();
        if (methods == null) {
            return out;
        }
        for (String m : methods) {
            if (!BOX_ROUTES.contains(m)) {
                out.add(m);
            }
        }
        return out;
    }

    /** Receipt__c rows -> the row's instruments. */
    private static List<InstrumentDTO> toInstruments(List<Receipt__c> receipts) {
        List<InstrumentDTO> out = new List<InstrumentDTO>();
        if (receipts == null) {
            return out;
        }
        for (Receipt__c r : receipts) {
            InstrumentDTO i = new InstrumentDTO();
            i.receiptId = r.Id;
            i.receiptName = r.Name;
            i.mode = r.Modeofpayment__c;
            i.reference = String.isNotBlank(r.TransactionNumber__c) ? r.TransactionNumber__c : r.Cheque_Number__c;
            /* cheque date, else the transaction date's day, else the receipt date */
            i.instrumentDate = r.ChequeDate__c != null
                ? r.ChequeDate__c
                : (r.TransactionDate__c != null ? r.TransactionDate__c.date() : r.ReceiptDate__c);
            /* the flow puts the cheque amount in Receipt_Amount__c; Manage Cheques fills TotalAmount__c only */
            i.amount = r.Receipt_Amount__c != null ? r.Receipt_Amount__c : r.TotalAmount__c;
            i.status = r.Status__c;
            i.live = r.Status__c == RECEIPT_IN_PROGRESS;
            i.bank = String.isNotBlank(r.Bank__c) ? r.Bank__c : r.BankName__c;
            i.recordedOn = r.CreatedDate;
            i.recordedBy = r.CreatedBy != null ? r.CreatedBy.Name : null;
            if (r.ContentDocumentLinks != null && !r.ContentDocumentLinks.isEmpty()) {
                ContentDocumentLink cdl = r.ContentDocumentLinks[0];
                i.contentDocumentId = cdl.ContentDocumentId;
                i.fileName = cdl.ContentDocument != null ? cdl.ContentDocument.Title : null;
                i.contentVersionId = cdl.ContentDocument != null
                    ? cdl.ContentDocument.LatestPublishedVersionId : null;
                i.fileCount = r.ContentDocumentLinks.size();
            }
            i.chequeDetailsId = r.Cheque_Details__c;
            out.add(i);
        }
        return out;
    }

    /**
     * MSC-197: one query for every cheque on the page. The read is written by
     * ChequeOcrService (the queueable after a payment is recorded, or the console's own live read
     * handed to applyRead) - this only carries it to the screen.
     */
    private static void attachChequeReads(List<PaymentBucketDTO> buckets) {
        Map<Id, List<InstrumentDTO>> byCheque = new Map<Id, List<InstrumentDTO>>();
        for (PaymentBucketDTO b : buckets) {
            if (b.instruments == null) {
                continue;
            }
            for (InstrumentDTO i : b.instruments) {
                if (i.chequeDetailsId == null) {
                    continue;
                }
                if (!byCheque.containsKey(i.chequeDetailsId)) {
                    byCheque.put(i.chequeDetailsId, new List<InstrumentDTO>());
                }
                byCheque.get(i.chequeDetailsId).add(i);
            }
        }
        if (byCheque.isEmpty()) {
            return;
        }
        for (Cheque_Details__c c : [
            SELECT Id, OCR_Status__c, OCR_Cheque_No__c, OCR_Cheque_Date__c, OCR_Amount__c,
                   OCR_Bank__c, OCR_Mismatch__c, OCR_Error__c
            FROM Cheque_Details__c
            WHERE Id IN :byCheque.keySet()
        ]) {
            for (InstrumentDTO i : byCheque.get(c.Id)) {
                i.ocrStatus = c.OCR_Status__c;
                i.ocrChequeNumber = c.OCR_Cheque_No__c;
                i.ocrChequeDate = c.OCR_Cheque_Date__c;
                i.ocrAmount = c.OCR_Amount__c;
                i.ocrBank = c.OCR_Bank__c;
                i.ocrMismatch = c.OCR_Mismatch__c == true;
                i.ocrError = c.OCR_Error__c;
            }
        }
    }

    private static void attachProofs(List<PaymentBucketDTO> buckets, List<Id> salesOrderIds) {
        if (buckets.isEmpty() || salesOrderIds == null || salesOrderIds.isEmpty()) {
            return;
        }
        Map<Id, PaymentBucketDTO> bySource = new Map<Id, PaymentBucketDTO>();
        for (PaymentBucketDTO b : buckets) {
            if (b.sourceId != null) {
                bySource.put(b.sourceId, b);
            }
        }
        for (Documents__c doc : [
            SELECT Id, Name, Status__c, Payment_Proof_Type__c, Proof_Amount__c,
                   Booking_Fee_Line__c, Sales_Order_Installment__c, Invoice__c,
                   Receipt__c, Receipt__r.Name,
                   (SELECT Id, ContentDocumentId, ContentDocument.Title,
                           ContentDocument.CreatedDate
                    FROM ContentDocumentLinks
                    ORDER BY ContentDocument.CreatedDate DESC)
            FROM Documents__c
            WHERE SalesOrder__c IN :salesOrderIds
              AND Payment_Proof_Type__c != NULL
        ]) {
            // a deleted fee line nulls the lookup and orphans the proof; skip it
            Id source = doc.Booking_Fee_Line__c != null
                ? doc.Booking_Fee_Line__c
                : (doc.Sales_Order_Installment__c != null
                    ? doc.Sales_Order_Installment__c
                    : doc.Invoice__c); // 1.40 - the ADM + Dari charge
            if (source == null || !bySource.containsKey(source)) {
                continue;
            }
            PaymentBucketDTO bucket = bySource.get(source);
            if (doc.ContentDocumentLinks == null || doc.ContentDocumentLinks.isEmpty()) {
                // a slot with no file yet is still shown
                ProofDTO empty = new ProofDTO();
                empty.documentId = doc.Id;
                empty.bucketKey = bucket.key;
                empty.label = doc.Name;
                empty.amount = doc.Proof_Amount__c;
                empty.status = doc.Status__c;
                empty.receiptId = doc.Receipt__c;
                empty.receiptName = doc.Receipt__r != null ? doc.Receipt__r.Name : null;
                bucket.proofs.add(empty);
                continue;
            }
            /* one row per file, not per document */
            for (ContentDocumentLink link : doc.ContentDocumentLinks) {
                ProofDTO proof = new ProofDTO();
                proof.documentId = doc.Id;
                proof.bucketKey = bucket.key;
                proof.label = doc.Name;
                proof.amount = doc.Proof_Amount__c;
                proof.status = doc.Status__c;
                proof.contentDocumentId = link.ContentDocumentId;
                proof.fileName = link.ContentDocument.Title;
                proof.uploadedDate = link.ContentDocument.CreatedDate;
                proof.receiptId = doc.Receipt__c;
                proof.receiptName = doc.Receipt__r != null ? doc.Receipt__r.Name : null;
                bucket.proofs.add(proof);
            }
        }
    }

    // 4b. Settlement

    /* A booking is sold when SalesTeamVoidCheck__c turns true, which has two legs:
     *     ADM leg  <- SalesOrder__c.ADM_Fees_and_Dari__c    (the ADM-flagged invoice)
     *     DP  leg  <- SalesOrder__c.Down_Payment_Status__c  (the milestone-1 invoice)
     * Two clocks are reported separately: consoleStatus (what this screen collected) and
     * orderStatus (what the org says via the allocation chain). They diverge for hours, which is
     * why AWAITING_CLEARANCE exists. */

    /** Console-side settlement states. */
    // ── EOI deposits (MSC-231 / W5) ──────────────────────────────────────────
    // Booking against the EOI. Eligibility is the org engine's alone
    // (UnitSearchLwcController.getCompletedEOIs); this console reads it, prices the
    // deposits from the same receipt rules the engine spends, and hands the chosen
    // {unitId: eoiId} mapping back to saveSalesOrder. Nothing is decided here.

    public class BookingEoiDTO {
        @AuraEnabled public Id eoiId;
        @AuraEnabled public String name;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public String bedrooms;
        /** The engine's own flag: true = it will apply the money (Allocation + Charge). */
        @AuraEnabled public Boolean hasReceipt = false;
        /** Sum of the receipts the engine would spend (valid status, not yet on an order). */
        @AuraEnabled public Decimal amount = 0;
        @AuraEnabled public Datetime createdDate;
        /** 1.75 - ExpressionofInterest__c.Pre_Approval_Number__c, as the engine lists it. */
        @AuraEnabled public String preApprovalNumber;
    }

    public class BookingEoiResult {
        /** Oldest first - the auto-assignment order. */
        @AuraEnabled public List<BookingEoiDTO> eois = new List<BookingEoiDTO>();
        @AuraEnabled public Boolean bypassTypology = false;
        @AuraEnabled public Boolean allowAnyStatus = false;
        /** EOIs exist on the opportunity, whether or not any is eligible right now. */
        @AuraEnabled public Boolean hasAnyEoi = false;
        /** The engine's refusal wording when it returned no eligible EOIs; null otherwise. */
        @AuraEnabled public String engineMessage;
        /** Phase gate, when a phaseId was given. */
        @AuraEnabled public Boolean phaseRequiresEoi = false;
        @AuraEnabled public Boolean phaseStrictRequiresEoi = false;
        /** 1.69: the EOI match is ON - the label says 'true' and the opportunity is not bypassed.
         *  Each unit is then offered only the EOIs that match it (on bedrooms, from 1.72). */
        @AuraEnabled public Boolean enforceTypology = false;
    }

    /** One applied (or incoming) EOI deposit on the settlement. */
    public class EoiDepositDTO {
        @AuraEnabled public String eoiName;
        @AuraEnabled public String unitName;
        @AuraEnabled public Decimal amount = 0;
    }

    /**
     * The EOIs the org engine would accept for this opportunity, priced. The engine
     * signals "none eligible" with an exception; here that is an empty list plus its
     * wording, so the journey can warn early instead of failing late.
     */
    @AuraEnabled
    public static BookingEoiResult getBookingEois(Id opportunityId, Id phaseId) {
        BookingEoiResult out = new BookingEoiResult();
        if (opportunityId == null) {
            return out;
        }
        List<Map<String, String>> engineRows;
        try {
            engineRows = UnitSearchLwcController.getCompletedEOIs(String.valueOf(opportunityId));
        } catch (Exception e) {
            engineRows = new List<Map<String, String>>();
            /* 1.85: the engine's own sentence, as the EOI gate reads it */
            out.engineMessage = engineRefusal(e, opportunityId);
        }
        Map<Id, BookingEoiDTO> byId = new Map<Id, BookingEoiDTO>();
        for (Map<String, String> row : engineRows) {
            if (row.get('type') == 'meta') {
                out.bypassTypology = row.get('bypass') == 'true';
                out.allowAnyStatus = row.get('allowAnyStatus') == 'true';
                out.hasAnyEoi = row.get('hasAnyEOI') == 'true';
                continue;
            }
            if (String.isBlank(row.get('value'))) continue;
            BookingEoiDTO d = new BookingEoiDTO();
            d.eoiId = (Id) row.get('value');
            d.name = row.get('label');
            d.unitTypology = row.get('unitTypology');
            d.bedrooms = row.get('bedrooms');
            d.hasReceipt = row.get('hasReceipt') == 'true';
            d.preApprovalNumber = String.isBlank(row.get('preApprovalNumber'))
                ? null : row.get('preApprovalNumber');
            byId.put(d.eoiId, d);
        }
        new EoiReadContext().price(byId, out, phaseId, opportunityId);
        /* 1.69: the staff app's rule, bypass = opportunity flag OR label not 'true' */
        out.enforceTypology = !out.bypassTypology && System.Label.EOI_Enforce_Typology_Check == 'true';
        return out;
    }

    // ── 1.69: MODON's EOI booking gates, mirrored ───────────────────────────────
    // The staff app (unitSearchLwc, "EOI v2.1") refuses a booking on these. saveSalesOrder
    // keeps one safety net - a phase that needs an EOI, booked with no mapping - and none of the
    // rest: not the typology match, not the count, not one-EOI-per-unit. The order, the conditions and the wording
    // below are the staff app's, so a rep is told in the console exactly what the Sales App
    // would tell them. MODON confirmed on 21 Sep 2026: same behaviour in both.
    //
    //   Gate 0  the engine refused on load (e.g. EOIs exist, none with a valid receipt)
    //   Gate 1  the phase needs an EOI and none qualifies: refused when the phase is strict
    //           or the opportunity has any EOI at all; otherwise booking goes ahead without one
    //   Gate 2  every unit matches an EOI on bedrooms, unless bypassed (1.72: bedrooms only;
    //           the staff app still compares typology too until MODON changes it)
    //   Gate 3  no more units than EOIs
    //   and, once EOIs are in play, every unit carries its own EOI (the Sales App's page 2).
    //
    // All of it applies only when a selected unit's phase has EOI_Required__c = true, as there.
    // Not mirrored: the Modon Egypt exemption, which keys on a profile no console user holds.

    public class EoiGateDTO {
        @AuraEnabled public Boolean ok = true;
        /** The staff app's toast title, kept so the two can be compared line for line. */
        @AuraEnabled public String title;
        @AuraEnabled public String message;
    }

    /** One selected unit, as the gate needs it. */
    @TestVisible
    private class EoiGateUnit {
        public Id unitId;
        public String name;
        public String bedrooms;
        public Boolean eoiRequired = false;
        public Boolean eoiStrictRequired = false;
    }

    /**
     * The Continue button's question: may these units go ahead for this opportunity?
     * `eoiMappingJson` is null while the rep is still choosing, and the {unitId: eoiId} map
     * once the journey has assigned deposits.
     */
    @AuraEnabled
    public static EoiGateDTO checkEoiGate(Id opportunityId, List<Id> unitIds, String eoiMappingJson) {
        try {
            return eoiGate(opportunityId,
                unitIds == null ? new List<Id>() : unitIds, eoiMappingJson, eoiMappingJson != null);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** The reads, then the pure rule. */
    @TestVisible
    private static EoiGateDTO eoiGate(Id opportunityId, List<Id> unitIds, String mappingJson, Boolean checkMapping) {
        EoiGateDTO pass = new EoiGateDTO();
        if (opportunityId == null || unitIds == null || unitIds.isEmpty()) {
            return pass;
        }
        Map<Id, Unit__c> byId = new Map<Id, Unit__c>([
            SELECT Id, Name, Number_of_Bedrooms__c,
                   Phase__r.EOI_Required__c, Phase__r.EOI_Strict_Required__c
            FROM Unit__c WHERE Id IN :unitIds
        ]);
        List<EoiGateUnit> units = new List<EoiGateUnit>();
        Boolean anyRequired = false;
        for (Id uid : unitIds) {
            Unit__c u = byId.get(uid);
            if (u == null) {
                continue;
            }
            EoiGateUnit g = new EoiGateUnit();
            g.unitId = u.Id;
            g.name = u.Name;
            g.bedrooms = u.Number_of_Bedrooms__c == null ? '' : u.Number_of_Bedrooms__c;
            g.eoiRequired = u.Phase__r != null && u.Phase__r.EOI_Required__c == true;
            g.eoiStrictRequired = u.Phase__r != null && u.Phase__r.EOI_Strict_Required__c == true;
            anyRequired = anyRequired || g.eoiRequired;
            units.add(g);
        }
        /* the staff app never calls into the EOIs for a phase that does not need one */
        if (!anyRequired) {
            return pass;
        }
        List<Map<String, String>> rows = new List<Map<String, String>>();
        String engineError;
        try {
            rows = UnitSearchLwcController.getCompletedEOIs(String.valueOf(opportunityId));
        } catch (Exception e) {
            engineError = engineRefusal(e, opportunityId);
        }
        Map<String, String> mapping = new Map<String, String>();
        if (String.isNotBlank(mappingJson)) {
            try {
                Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(mappingJson);
                for (String k : raw.keySet()) {
                    if (raw.get(k) != null && String.isNotBlank(String.valueOf(raw.get(k)))) {
                        mapping.put(String.valueOf(Id.valueOf(k)), String.valueOf(raw.get(k)));
                    }
                }
            } catch (Exception e) {
                /* validatedEoiMapping reports an unreadable map in its own words */
                mapping.clear();
            }
        }
        return decideEoiGate(units, rows, engineError,
            System.Label.EOI_Enforce_Typology_Check, mapping, checkMapping);
    }

    /**
     * The staff app's rule, with nothing read from the database - so every branch is
     * provable in a test. `typologyLabel` is EOI_Enforce_Typology_Check's value.
     */
    @TestVisible
    private static EoiGateDTO decideEoiGate(
        List<EoiGateUnit> units, List<Map<String, String>> engineRows, String engineError,
        String typologyLabel, Map<String, String> mapping, Boolean checkMapping
    ) {
        EoiGateDTO g = new EoiGateDTO();
        Boolean anyRequired = false;
        Boolean anyStrict = false;
        for (EoiGateUnit u : units) {
            anyRequired = anyRequired || u.eoiRequired;
            anyStrict = anyStrict || u.eoiStrictRequired;
        }
        if (!anyRequired) {
            return g;
        }

        /* Gate 0 */
        if (engineError != null) {
            return refuseEoi(g, 'EOI Validation', engineError);
        }

        Boolean oppBypass = false;
        Boolean hasAnyEoi = false;
        List<Map<String, String>> eois = new List<Map<String, String>>();
        for (Map<String, String> row : engineRows == null ? new List<Map<String, String>>() : engineRows) {
            if (row.get('type') == 'meta') {
                oppBypass = row.get('bypass') == 'true';
                hasAnyEoi = row.get('hasAnyEOI') == 'true';
            } else if (String.isNotBlank(row.get('value'))) {
                eois.add(row);
            }
        }

        /* Gate 1 */
        if (eois.isEmpty()) {
            if (anyStrict || hasAnyEoi) {
                return refuseEoi(g, 'EOI Required', 'Only a Completed EOI is allowed to book this unit.');
            }
            /* no EOI on the opportunity at all, and the phase is not strict: book without one */
            return g;
        }

        Boolean bypass = oppBypass || typologyLabel != 'true';

        /* Gate 2 */
        if (!bypass) {
            for (EoiGateUnit u : units) {
                if (!matchesAnyEoi(u, eois)) {
                    return bedroomsRefusal(g, u);
                }
            }
        }

        /* Gate 3 */
        if (eois.size() < units.size()) {
            return refuseEoi(g, 'Error!',
                'Number of units selected (' + units.size()
                + ') cannot exceed the number of available EOIs (' + eois.size() + ').');
        }

        /* the Sales App's page 2: every unit its own EOI, from the ones it is offered */
        if (checkMapping) {
            Map<String, Map<String, String>> eoiById = new Map<String, Map<String, String>>();
            for (Map<String, String> e : eois) {
                eoiById.put(String.valueOf(Id.valueOf(e.get('value'))), e);
            }
            Set<String> used = new Set<String>();
            for (EoiGateUnit u : units) {
                String eoiId = mapping == null ? null : mapping.get(String.valueOf(u.unitId));
                if (String.isBlank(eoiId)) {
                    return refuseEoi(g, 'EOI Required',
                        'Please select an EOI for unit ' + u.name + ' before proceeding.');
                }
                String key = String.valueOf(Id.valueOf(eoiId));
                if (used.contains(key)) {
                    return refuseEoi(g, 'Duplicate EOI',
                        'The same EOI cannot be assigned to multiple units. '
                        + 'Please select a unique EOI for each unit.');
                }
                used.add(key);
                Map<String, String> chosen = eoiById.get(key);
                if (!bypass && (chosen == null || !matchesEoi(u, chosen))) {
                    return bedroomsRefusal(g, u);
                }
            }
        }
        return g;
    }

    /**
     * 1.72: bedrooms only. Typology is not compared: EOIs and units spell it differently.
     * @param u   the selected unit
     * @param eoi one engine row (getCompletedEOIs)
     * @return true when the EOI's bedrooms are the unit's (sameBedrooms)
     */
    private static Boolean matchesEoi(EoiGateUnit u, Map<String, String> eoi) {
        return sameBedrooms(eoi.get('bedrooms'), u.bedrooms);
    }

    /**
     * 1.73: the engine's compare, line for line (UnitSearchLwcController.bedroomsMatch, v16.0):
     * the number only, so "5 Bedrooms", "5 BR" and "5" all match; when neither side holds a
     * digit (a studio), trimmed text in any case.
     * @param eoiBeds  EOI Bedrooms__c
     * @param unitBeds Unit__c.Number_of_Bedrooms__c
     * @return true when the engine would call them the same
     */
    @TestVisible
    private static Boolean sameBedrooms(String eoiBeds, String unitBeds) {
        String a = String.isBlank(eoiBeds) ? '' : eoiBeds.replaceAll('[^0-9]', '');
        String b = String.isBlank(unitBeds) ? '' : unitBeds.replaceAll('[^0-9]', '');
        if (String.isBlank(a) && String.isBlank(b)) {
            String eoiText = String.isBlank(eoiBeds) ? '' : eoiBeds.trim();
            String unitText = String.isBlank(unitBeds) ? '' : unitBeds.trim();
            return eoiText.equalsIgnoreCase(unitText);
        }
        return a == b;
    }

    /**
     * 1.73: the engine's isReceiptFree (v16.2): on no order, or on one that was Cancelled or Voided.
     * @param salesOrderId the receipt's SalesOrder__c
     * @param orderStatus  that order's Status__c
     * @return true when the engine would spend this receipt on a new booking
     */
    @TestVisible
    private static Boolean receiptIsFree(Id salesOrderId, String orderStatus) {
        return salesOrderId == null || RECEIPT_FREEING_ORDER_STATUSES.contains(orderStatus);
    }

    /**
     * 1.73: the receipts the engine would still spend.
     * @param rows receipts read with SalesOrder__c and SalesOrder__r.Status__c
     * @return the free ones (receiptIsFree)
     */
    private static List<Receipt__c> freeReceipts(List<Receipt__c> rows) {
        List<Receipt__c> out = new List<Receipt__c>();
        for (Receipt__c r : rows) {
            if (receiptIsFree(r.SalesOrder__c, r.SalesOrder__r?.Status__c)) {
                out.add(r);
            }
        }
        return out;
    }

    /**
     * 1.72: the one refusal Gate 2 and the per-unit check give.
     * @param g the verdict to fill
     * @param u the unit that has no EOI with its bedrooms
     * @return g, refused
     */
    private static EoiGateDTO bedroomsRefusal(EoiGateDTO g, EoiGateUnit u) {
        return refuseEoi(g, 'EOI Bedrooms Mismatch',
            'Cannot proceed. Unit "' + u.name + '" (Bedrooms: '
            + (String.isBlank(u.bedrooms) ? 'N/A' : u.bedrooms)
            + ') does not match any available EOI. '
            + 'Please select a unit with the same number of bedrooms as your EOI.');
    }

    private static Boolean matchesAnyEoi(EoiGateUnit u, List<Map<String, String>> eois) {
        for (Map<String, String> e : eois) {
            if (matchesEoi(u, e)) {
                return true;
            }
        }
        return false;
    }

    private static EoiGateDTO refuseEoi(EoiGateDTO g, String title, String message) {
        g.ok = false;
        g.title = title;
        g.message = message;
        return g;
    }

    /**
     * The engine's refusal in its own words. An AuraHandledException caught in Apex reports
     * "Script-thrown exception" rather than its text, so when that is all there is, the two
     * sentences getCompletedEOIs throws are restored by the same flag it chooses between them on.
     */
    private static String engineRefusal(Exception e, Id opportunityId) {
        String m = e == null ? null : e.getMessage();
        if (String.isNotBlank(m) && !m.containsIgnoreCase('Script-thrown exception')) {
            return m;
        }
        Boolean vip = false;
        for (Opportunity o : [
            SELECT Allow_EOI_Any_Status__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            vip = o.Allow_EOI_Any_Status__c == true;
        }
        return vip
            ? 'Receipt exists but status is not valid. Only Cleared receipts are accepted.'
            : 'EOI must be Completed with a Cleared Receipt to book.';
    }

    @TestVisible private class EoiMappingCheck {
        public String mappingJson; // null = book with no EOI linking, exactly as before
        public String error;       // set = refuse the confirm with this message
    }

    /**
     * MSC-231. The mapping is only ever forwarded after proving: every key is a unit of
     * THIS request, every value is an EOI the org engine itself lists as eligible for
     * THIS opportunity, and no EOI pays for two units. Blank in = null out (no linking).
     */
    @TestVisible
    private static EoiMappingCheck validatedEoiMapping(String mappingJson, Set<Id> unitIds, Id opportunityId) {
        EoiMappingCheck check = new EoiMappingCheck();
        if (String.isBlank(mappingJson)) {
            return check;
        }
        Map<String, Object> raw;
        try {
            raw = (Map<String, Object>) JSON.deserializeUntyped(mappingJson);
        } catch (Exception e) {
            check.error = 'The EOI selection could not be read. Please reopen the booking and try again.';
            return check;
        }
        if (raw == null || raw.isEmpty()) {
            return check;
        }
        Set<Id> eligible = new Set<Id>();
        for (BookingEoiDTO d : getBookingEois(opportunityId, null).eois) {
            eligible.add(d.eoiId);
        }
        /* 1.77 - the Sales App links an EOI only where the unit's phase requires one */
        Set<Id> eoiUnits = eoiRequiredUnits(unitIds);
        Map<String, String> clean = new Map<String, String>();
        Set<String> usedEois = new Set<String>();
        for (String unitKey : raw.keySet()) {
            Object v = raw.get(unitKey);
            if (v == null || String.isBlank(String.valueOf(v))) continue;
            Id unitId;
            Id eoiId;
            try {
                unitId = (Id) unitKey;
                eoiId = (Id) String.valueOf(v);
            } catch (Exception e) {
                check.error = 'The EOI selection could not be read. Please reopen the booking and try again.';
                return check;
            }
            if (!unitIds.contains(unitId)) {
                check.error = 'An EOI was assigned to a unit that is not part of this booking.';
                return check;
            }
            if (!eoiUnits.contains(unitId)) {
                continue;
            }
            if (!eligible.contains(eoiId)) {
                check.error = 'One of the selected EOIs is no longer eligible for this booking. Please reopen the booking and try again.';
                return check;
            }
            if (usedEois.contains(String.valueOf(eoiId))) {
                check.error = 'The same EOI cannot pay the deposit for two units.';
                return check;
            }
            usedEois.add(String.valueOf(eoiId));
            /* 18-char ids: saveSalesOrder keys its mapping by SalesOrder__c.Unit__c verbatim */
            clean.put(String.valueOf(unitId), String.valueOf(eoiId));
        }
        if (!clean.isEmpty()) {
            check.mappingJson = JSON.serialize(clean);
        }
        return check;
    }

    /**
     * System-context reads for the deposit money. Without sharing on purpose: the rep's
     * row visibility over receipts and phases must never under-price a deposit the org
     * engine will spend in full - the same reason the engine reads them without sharing.
     */
    private without sharing class EoiReadContext {

        void price(Map<Id, BookingEoiDTO> byId, BookingEoiResult out, Id phaseId, Id opportunityId) {
            if (!byId.isEmpty()) {
                Set<String> validStatuses = new Set<String>();
                for (String s : System.Label.EOI_Receipt_Valid_Statuses.split(',')) {
                    validStatuses.add(s.trim());
                }
                /* the engine's own spend rules: valid status (or the per-receipt override), and free
                   (1.73: no order, or one that was Cancelled or Voided) */
                for (Receipt__c r : freeReceipts([
                    SELECT ExpressionOfInterest__c, Receipt_Amount__c, SalesOrder__c, SalesOrder__r.Status__c
                    FROM Receipt__c
                    WHERE ExpressionOfInterest__c IN :byId.keySet()
                      AND (Status__c IN :validStatuses OR Allow_Any_Status_for_Booking__c = true)
                ])) {
                    BookingEoiDTO d = byId.get(r.ExpressionOfInterest__c);
                    if (d != null && r.Receipt_Amount__c != null) {
                        d.amount += r.Receipt_Amount__c;
                    }
                }
                for (Expressionofinterest__c e : [
                    SELECT Id, CreatedDate FROM Expressionofinterest__c
                    WHERE Id IN :byId.keySet() ORDER BY CreatedDate ASC
                ]) {
                    BookingEoiDTO d = byId.get(e.Id);
                    if (d != null) {
                        d.createdDate = e.CreatedDate;
                        out.eois.add(d); // oldest first
                    }
                }
            }
            if (phaseId != null) {
                for (Phase__c p : [
                    SELECT EOI_Required__c, EOI_Strict_Required__c FROM Phase__c WHERE Id = :phaseId LIMIT 1
                ]) {
                    out.phaseRequiresEoi = p.EOI_Required__c == true;
                    out.phaseStrictRequiresEoi = p.EOI_Strict_Required__c == true;
                }
            }
            if (!out.hasAnyEoi && opportunityId != null) {
                out.hasAnyEoi = [
                    SELECT COUNT() FROM Expressionofinterest__c WHERE Opportunity__c = :opportunityId
                ] > 0;
            }
        }

        /** Post-confirm: the deposits the engine actually linked to these orders. */
        List<EoiDepositDTO> depositsFor(Set<Id> orderIds) {
            List<EoiDepositDTO> out = new List<EoiDepositDTO>();
            for (Receipt__c r : [
                SELECT Receipt_Amount__c, ExpressionOfInterest__r.Name, SalesOrder__r.Unit__r.Name
                FROM Receipt__c
                WHERE SalesOrder__c IN :orderIds AND ExpressionOfInterest__c != null
                ORDER BY ExpressionOfInterest__r.Name ASC
            ]) {
                EoiDepositDTO d = new EoiDepositDTO();
                d.eoiName = r.ExpressionOfInterest__r.Name;
                d.unitName = r.SalesOrder__r != null && r.SalesOrder__r.Unit__r != null
                    ? r.SalesOrder__r.Unit__r.Name : null;
                d.amount = r.Receipt_Amount__c == null ? 0 : r.Receipt_Amount__c;
                out.add(d);
            }
            return out;
        }
    }

    /** Facade for buildSettlement, which lives outside the inner class. */
    private static List<EoiDepositDTO> eoiDepositsFor(Set<Id> orderIds) {
        return new EoiReadContext().depositsFor(orderIds);
    }

    @TestVisible private static final String SETTLE_NONE = 'NOT_STARTED';
    @TestVisible private static final String SETTLE_PARTLY = 'PARTLY_PAID';
    @TestVisible private static final String SETTLE_CLEARING = 'AWAITING_CLEARANCE';
    @TestVisible private static final String SETTLE_DONE = 'SETTLED';

    /**
     * Picklist values that do not satisfy a leg, copied from SalesTeamVoidCheck__c's formula.
     * A partial payment satisfies it; that is Modon's rule.
     */
    private static final Set<String> LEG_UNSATISFIED = new Set<String>{
        'Generated', 'Cancelled', 'Reversed'
    };

    /** One leg of SalesTeamVoidCheck__c, with both clocks. */
    public class SettlementLegDTO {
        @AuraEnabled public String key;              // 'adm' | 'down'
        @AuraEnabled public String label;
        @AuraEnabled public Decimal requiredAmount = 0;
        @AuraEnabled public Decimal paidAmount = 0;
        @AuraEnabled public Decimal remainingAmount = 0;
        /** What this console has collected; one of SETTLE_*. */
        @AuraEnabled public String consoleStatus = SETTLE_NONE;
        /** Sales Order picklist verbatim, or null before an order exists. */
        @AuraEnabled public String orderStatus;
        /** The org's answer for this leg; null without an order. */
        @AuraEnabled public Boolean satisfied;
        /** True while the figures are a preview. */
        @AuraEnabled public Boolean isEstimate = false;
    }

    /** Everything the settlement header needs. */
    public class SettlementDTO {
        @AuraEnabled public Decimal totalRequired = 0;
        @AuraEnabled public Decimal totalCollected = 0;
        @AuraEnabled public Decimal totalRemaining = 0;
        @AuraEnabled public SettlementLegDTO admLeg;
        @AuraEnabled public SettlementLegDTO downPaymentLeg;
        /** SalesTeamVoidCheck__c across every order. */
        @AuraEnabled public Boolean gateSatisfied = false;
        /** False before any Sales Order exists. */
        @AuraEnabled public Boolean gateKnown = false;
        /** True once every leg is settled and the org agrees. */
        @AuraEnabled public Boolean fullySettled = false;
        /* MSC-231: EOI deposits the engine linked to these orders (post-confirm only;
         * before the orders exist the journey shows its own pending assignment) */
        @AuraEnabled public List<EoiDepositDTO> eoiDeposits = new List<EoiDepositDTO>();
        /** Milestones 2..n, not owed today. */
        @AuraEnabled public Integer scheduledCount = 0;
        @AuraEnabled public Decimal scheduledTotal = 0;
        @AuraEnabled public Date scheduledFirstDue;
        /** Units this view covers; wording only. */
        @AuraEnabled public Integer unitCount = 1;
        /* live orders on the opportunity, whatever this view covers, so one order of a basket
         * opened alone still reads as part of a multi-unit booking */
        @AuraEnabled public Integer bookingUnitCount = 1;
        /** True when the figures are previews. */
        @AuraEnabled public Boolean isEstimate = false;
        /* has this booking been made? A Sales Order existing is the confirmation. Independent of
         * isBookingFee: an unpaid booking fee outlives Confirm. */
        @AuraEnabled public Boolean bookingConfirmed = false;
        /* are these the booking fee (the deposit: max(50% ADM, 50k) + max(25% milestone 1, 50k))
         * or the real closing obligations? The header must not call one the other. */
        @AuraEnabled public Boolean isBookingFee = false;
        /* when this booking was made and what it is called; null until a Sales Order exists.
         * Not Booking_Date__c, which nothing writes. */
        @AuraEnabled public Date confirmedOn;
        @AuraEnabled public String bookingReference;
    }

    /**
     * What is outstanding on the obligations that close this booking. Pure read. Three stages:
     *   1. fee lines exist     -> the real Booking_Fee_Line__c figures
     *   2. Sales Orders exist  -> the ADM invoice and milestone-1 installments (a basket)
     *   3. neither yet         -> previewBookingFees
     * planId and totalAmount are used only for the stage-3 preview.
     */
    @AuraEnabled(cacheable=false)
    public static SettlementDTO getSettlement(
        Id opportunityId, Id unitId, List<Id> salesOrderIds, Id planId, Decimal totalAmount
    ) {
        try {
            return buildSettlement(opportunityId, unitId, salesOrderIds, planId, totalAmount);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    private static SettlementDTO buildSettlement(
        Id opportunityId, Id unitId, List<Id> salesOrderIds, Id planId, Decimal totalAmount
    ) {
        SettlementDTO dto = new SettlementDTO();
        List<Id> orderIds = salesOrderIds == null ? new List<Id>() : salesOrderIds;
        // a Sales Order exists, so Confirm has run
        dto.bookingConfirmed = !orderIds.isEmpty();

        SettlementLegDTO adm = newLeg('adm', LABEL_ADM_DARI);
        SettlementLegDTO down = newLeg('down', LABEL_DOWN_PAYMENT);

        // stage 1: the real fee lines
        Boolean sawAdmLine = false;
        Boolean sawDownLine = false;
        if (opportunityId != null && unitId != null) {
            List<Booking_Fee_Line__c> feeLines = [
                SELECT Type__c, Total_Amount__c, Total_Paid_Amount__c
                FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
            ];
            /* 1.76: an unpaid line on a no-fee phase is not this booking's fee */
            if (!feeLinesCount(opportunityId, unitId, feeLines)) {
                feeLines.clear();
            }
            for (Booking_Fee_Line__c line : feeLines) {
                SettlementLegDTO leg = line.Type__c == FEE_TYPE_ADM ? adm : down;
                leg.requiredAmount = nz(line.Total_Amount__c);
                leg.paidAmount = nz(line.Total_Paid_Amount__c);
                dto.isBookingFee = true;
                if (line.Type__c == FEE_TYPE_ADM) { sawAdmLine = true; } else { sawDownLine = true; }
            }
        }

        // stage 2: the orders' own obligations
        Set<Id> orderIdSet = new Set<Id>(orderIds);
        if (!orderIdSet.isEmpty()) {
            dto.gateKnown = true;
            /* MSC-231: the deposits the engine actually spent on these orders. Their money
             * is already inside the ADM invoice figures below - these rows only name it. */
            dto.eoiDeposits = eoiDepositsFor(orderIdSet);
            /* the ADM position for a booking that never raised a fee line: one flagged invoice per order */
            if (!sawAdmLine) {
                for (AggregateResult ar : [
                    SELECT SUM(InvoiceAmount__c) req, SUM(TotalPaidAmount__c) paid
                    FROM Invoice__c
                    WHERE Sales_Order__c IN :orderIdSet
                      AND Is_ADM_Fees_and_Dari_charges__c = true
                      AND isCancelled__c = false
                ]) {
                    adm.requiredAmount = nz((Decimal) ar.get('req'));
                    adm.paidAmount = nz((Decimal) ar.get('paid'));
                }
            }

            /* Milestone 1 is the down payment (InvoiceTriggerHelper's own test) */
            List<SalesOrderInstallments__c> soiList = [
                SELECT Id, MilestoneNumber__c, MilestoneDescription__c,
                       InstallmentAmount__c, MilestoneDate__c
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c IN :orderIdSet
                ORDER BY MilestoneNumber__c ASC
            ];
            Map<Id, Decimal> paidByInstallment = soiList.isEmpty()
                ? new Map<Id, Decimal>()
                : new FinanceReadContext().paidByInstallment(
                      new Map<Id, SalesOrderInstallments__c>(soiList).keySet());

            for (SalesOrderInstallments__c soi : soiList) {
                Boolean isDownPayment = soi.MilestoneNumber__c == 1
                    || (String.isNotBlank(soi.MilestoneDescription__c)
                        && soi.MilestoneDescription__c.containsIgnoreCase('Down Payment'));
                Decimal paid = paidByInstallment.containsKey(soi.Id)
                    ? nz(paidByInstallment.get(soi.Id)) : 0;
                if (isDownPayment) {
                    if (!sawDownLine) {
                        down.requiredAmount += nz(soi.InstallmentAmount__c);
                        down.paidAmount += paid;
                    }
                } else {
                    dto.scheduledCount++;
                    dto.scheduledTotal += nz(soi.InstallmentAmount__c);
                    if (soi.MilestoneDate__c != null
                            && (dto.scheduledFirstDue == null
                                || soi.MilestoneDate__c < dto.scheduledFirstDue)) {
                        dto.scheduledFirstDue = soi.MilestoneDate__c;
                    }
                }
            }

            // what the org says
            Boolean allAdmOk = true;
            Boolean allDownOk = true;
            Boolean allGateOk = true;
            Integer orderCount = 0;
            /* Name and CreatedDate join a query already running; Booking_Date__c is never written */
            for (SalesOrder__c so : [
                SELECT Name, CreatedDate,
                       ADM_Fees_and_Dari__c, Down_Payment_Status__c, SalesTeamVoidCheck__c,
                       IsADMCollectedWithWaiverRequest__c, ExcludeADMCheck__c,
                       IsDownPaymentCollected__c, ExcludeDPCheck__c
                FROM SalesOrder__c
                WHERE Id IN :orderIdSet
                ORDER BY CreatedDate ASC
            ]) {
                orderCount++;
                if (adm.orderStatus == null) { adm.orderStatus = so.ADM_Fees_and_Dari__c; }
                if (down.orderStatus == null) { down.orderStatus = so.Down_Payment_Status__c; }
                /* the earliest order's date: one date for one booking, same ordering as bookedUnitsFor */
                if (dto.confirmedOn == null) {
                    dto.confirmedOn = so.CreatedDate.date();
                    dto.bookingReference = so.Name;
                }
                /* the override booleans are part of the leg: SO-15400 and SO-15399 carry
                   SalesTeamVoidCheck__c = true with both picklists still Generated */
                if (!legSatisfied(so.ADM_Fees_and_Dari__c,
                        so.IsADMCollectedWithWaiverRequest__c, so.ExcludeADMCheck__c)) {
                    allAdmOk = false;
                }
                if (!legSatisfied(so.Down_Payment_Status__c,
                        so.IsDownPaymentCollected__c, so.ExcludeDPCheck__c)) {
                    allDownOk = false;
                }
                if (so.SalesTeamVoidCheck__c != true) { allGateOk = false; }
            }
            /* every order: a basket is not closed until all are; orderCount guards vacuous truth */
            if (orderCount > 0) {
                adm.satisfied = allAdmOk;
                down.satisfied = allDownOk;
                dto.gateSatisfied = allGateOk;
                dto.unitCount = orderCount;
                /* the booking's own size; never less than the orders in view */
                Integer live = liveOrderCountFor(opportunityId);
                dto.bookingUnitCount = live > orderCount ? live : orderCount;
            } else {
                dto.gateKnown = false;
            }
        }

        // stage 3: preview
        if (adm.requiredAmount == 0 && down.requiredAmount == 0
                && unitId != null && planId != null && totalAmount != null) {
            try {
                BookingFeeLineController.FeePreview p =
                    BookingFeeLineController.previewBookingFees(unitId, planId, totalAmount);
                if (p != null) {
                    adm.requiredAmount = nz(p.admFee);
                    down.requiredAmount = nz(p.downPayment);
                    adm.isEstimate = true;
                    down.isEstimate = true;
                    dto.isEstimate = true;
                    /* the preview is the same deposit the lines would carry */
                    dto.isBookingFee = true;
                }
            } catch (Exception e) {
                /* a phase with no Financial_Setup__c or a plan with no installments previews nothing */
            }
        }

        finishLeg(adm);
        finishLeg(down);
        dto.admLeg = adm;
        dto.downPaymentLeg = down;

        /* the headline: closes-the-sale obligations only */
        dto.totalRequired = adm.requiredAmount + down.requiredAmount;
        dto.totalCollected = adm.paidAmount + down.paidAmount;
        dto.totalRemaining = dto.totalRequired - dto.totalCollected;
        if (dto.totalRemaining < 0) { dto.totalRemaining = 0; }

        dto.fullySettled = adm.consoleStatus == SETTLE_DONE && down.consoleStatus == SETTLE_DONE;
        return dto;
    }

    private static SettlementLegDTO newLeg(String key, String label) {
        SettlementLegDTO leg = new SettlementLegDTO();
        leg.key = key;
        leg.label = label;
        return leg;
    }

    /** Remaining, then the console state. */
    private static void finishLeg(SettlementLegDTO leg) {
        leg.remainingAmount = leg.requiredAmount - leg.paidAmount;
        if (leg.remainingAmount < 0) { leg.remainingAmount = 0; }

        if (leg.requiredAmount == 0) {
            /* nothing owed on this leg: honour the org's answer if it has one (a waived fee) */
            leg.consoleStatus = leg.satisfied == true ? SETTLE_DONE : SETTLE_NONE;
            return;
        }
        if (leg.remainingAmount > 0) {
            leg.consoleStatus = leg.paidAmount > 0 ? SETTLE_PARTLY : SETTLE_NONE;
            return;
        }
        /* fully collected here: SETTLED only if the org agrees or there is no order yet */
        leg.consoleStatus = (leg.satisfied == null || leg.satisfied == true)
            ? SETTLE_DONE : SETTLE_CLEARING;
    }

    /**
     * One leg of SalesTeamVoidCheck__c, as the formula evaluates it:
     *     OR( collectedFlag, excludeFlag, picklist NOT IN (Generated, Cancelled, Reversed, blank) )
     */
    private static Boolean legSatisfied(
        String picklistValue, Boolean collectedFlag, Boolean excludeFlag
    ) {
        if (collectedFlag == true || excludeFlag == true) {
            return true;
        }
        return String.isNotBlank(picklistValue) && !LEG_UNSATISFIED.contains(picklistValue);
    }

    /**
     * 1.76 - do these fee lines describe the booking? Yes where the phase takes a fee, and yes once
     * money is on them. Otherwise they were raised by Confirm before 1.76 on a phase MODON takes no
     * fee on, and the closing obligations are the booking's figures.
     */
    private static Boolean feeLinesCount(Id opportunityId, Id unitId, List<Booking_Fee_Line__c> lines) {
        if (lines == null || lines.isEmpty()) {
            return true;
        }
        Decimal paid = 0;
        for (Booking_Fee_Line__c l : lines) {
            paid += nz(l.Total_Paid_Amount__c);
        }
        /* money on them settles it without asking the phase */
        if (paid > 0) {
            return true;
        }
        return feeLinesApply(phaseTakesFee(unitId, opportunityId), paid);
    }

    /* 1.76 - MODON's isPaymentRequired (two queries), asked once per unit and opportunity in a
       request: Confirm, the settlement and the buckets all need it */
    private static Map<String, Boolean> phaseTakesFeeCache = new Map<String, Boolean>();

    private static Boolean phaseTakesFee(Id unitId, Id opportunityId) {
        String key = unitId + ':' + opportunityId;
        if (!phaseTakesFeeCache.containsKey(key)) {
            phaseTakesFeeCache.put(key,
                UnitBookingJourneyController.isPaymentRequired(unitId, opportunityId));
        }
        return phaseTakesFeeCache.get(key);
    }

    /** 1.76 - the rule on values alone. */
    @TestVisible
    private static Boolean feeLinesApply(Boolean paymentRequired, Decimal paidOnLines) {
        return paymentRequired == true || nz(paidOnLines) > 0;
    }

    private static Decimal nz(Decimal v) {
        return v == null ? 0 : v;
    }

    // 5. Proof slots

    /**
     * Creates the Documents__c placeholder a proof file attaches to. Placeholder-then-upload
     * because the org has no base64 upload Apex; ContentDocumentLinkTriggerHelper flips Status__c.
     */
    @AuraEnabled
    public static ProofDTO createProofSlot(ProofSlotRequest req) {
        if (req == null || req.salesOrderId == null || req.sourceId == null) {
            throw new AuraHandledException('A payment must be selected before uploading proof.');
        }
        String proofType = PROOF_TYPE_BY_BUCKET.get(req.bucketKey);
        if (String.isBlank(proofType)) {
            throw new AuraHandledException('Unknown payment type: ' + req.bucketKey);
        }
        try {
            Documents__c doc = new Documents__c();
            doc.SalesOrder__c = req.salesOrderId;
            doc.Payment_Proof_Type__c = proofType;
            doc.Proof_Amount__c = req.amount;
            doc.Status__c = 'Pending Upload';
            // exactly one target (the Documents__c validation rule enforces it too); three targets
            // since the ADM + Dari charge is an Invoice__c
            if (req.bucketKey == BUCKET_MILESTONE) {
                doc.Sales_Order_Installment__c = req.sourceId;
            } else if (req.bucketKey == BUCKET_ADM_CHARGE) {
                doc.Invoice__c = req.sourceId;
            } else {
                doc.Booking_Fee_Line__c = req.sourceId;
            }
            insert doc;

            ProofDTO dto = new ProofDTO();
            dto.documentId = doc.Id;
            dto.bucketKey = req.bucketKey;
            dto.amount = req.amount;
            dto.status = 'Pending Upload';
            dto.reference = req.reference;
            return dto;
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /* Offers and discounts. The agent never types a number: OfferLines__c are pre-approved and
     * createOfferLineCollection re-reads OfferValue__c by id. */
    public class OfferLineDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String offerType;
        @AuraEnabled public String offerOn;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isDefault = false;
    }

    /**
     * 1.77 - the offers a made booking actually carries, per unit: its Offers_Collections__c rows,
     * as saveSalesOrder wrote them. Same row shape as the eligible list, so the page draws them alike.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, List<OfferLineDTO>> getAppliedOffers(Id opportunityId, List<Id> salesOrderIds) {
        Map<String, List<OfferLineDTO>> out = new Map<String, List<OfferLineDTO>>();
        if (opportunityId == null || salesOrderIds == null || salesOrderIds.isEmpty()) {
            return out;
        }
        try {
            for (Offers_Collections__c c : [
                SELECT Offer_Lines__c, Unit__c, Sales_Order__r.Unit__c,
                       Offer_Lines__r.OfferNameFormula__c, Offer_Lines__r.OfferType__c,
                       Offer_Lines__r.OfferOn__c, Offer_Lines__r.PromoValue__c
                FROM Offers_Collections__c
                WHERE Sales_Order__c IN :salesOrderIds AND Offer_Lines__c != null
                ORDER BY CreatedDate ASC
            ]) {
                Id unitId = c.Unit__c != null ? c.Unit__c : c.Sales_Order__r.Unit__c;
                if (unitId == null) { continue; }
                OfferLineDTO d = new OfferLineDTO();
                d.id = c.Offer_Lines__c;
                d.name = c.Offer_Lines__r.OfferNameFormula__c;
                d.offerType = c.Offer_Lines__r.OfferType__c;
                d.offerOn = c.Offer_Lines__r.OfferOn__c;
                d.value = c.Offer_Lines__r.PromoValue__c;
                d.isDefault = true;
                String key = String.valueOf(unitId);
                if (!out.containsKey(key)) { out.put(key, new List<OfferLineDTO>()); }
                out.get(key).add(d);
            }
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return out;
    }

    /**
     * Approved offers this unit and customer qualify for, from OpportunityGenerateOfferCtrl.queryOffers,
     * which owns the eligibility cascade.
     */
    @AuraEnabled(cacheable=false)
    public static List<OfferLineDTO> getEligibleOffers(Id opportunityId, Id unitId) {
        return getEligibleOffersForBasket(opportunityId, unitId, null);
    }

    /**
     * Same question with the whole basket in view: queryOffers sums TotalPrice__c across the units
     * for the price band.
     */
    @AuraEnabled(cacheable=false)
    public static List<OfferLineDTO> getEligibleOffersForBasket(
        Id opportunityId, Id unitId, List<Id> basketUnitIds
    ) {
        List<OfferLineDTO> out = new List<OfferLineDTO>();
        if (opportunityId == null || unitId == null) {
            return out;
        }
        List<String> priced = new List<String>();
        if (basketUnitIds != null) {
            for (Id b : basketUnitIds) {
                if (b != null) {
                    priced.add(String.valueOf(b));
                }
            }
        }
        if (priced.isEmpty()) {
            priced.add(String.valueOf(unitId));
        }
        try {
            Unit__c unit = loadUnit(unitId);
            Id projectId = null;
            for (Phase__c p : [
                SELECT Project__c FROM Phase__c WHERE Id = :unit.Phase__c LIMIT 1
            ]) {
                projectId = p.Project__c;
            }
            OpportunityGenerateOfferCtrl.offerLineWrapper w =
                OpportunityGenerateOfferCtrl.queryOffers(
                    projectId, opportunityId, unitId, null, priced);
            if (w == null || w.offerLinesList == null) {
                return out;
            }
            for (OfferLines__c l : w.offerLinesList) {
                OfferLineDTO d = new OfferLineDTO();
                d.id = l.Id;
                d.name = l.OfferNameFormula__c;
                d.offerType = l.OfferType__c;
                d.offerOn = l.OfferOn__c;
                d.value = l.PromoValue__c;
                d.isDefault = l.Is_Default_Offer__c == true;
                out.add(d);
            }
        } catch (Exception e) {
            /* an offer that cannot be read must not stop a booking */
            System.debug(LoggingLevel.WARN, 'getEligibleOffers: ' + e.getMessage());
        }
        return out;
    }

    /**
     * saveSalesOrder's offerLinesListStr, in unitSearchLwc's shape: [{ unitId, offerLinesLst: [{ Id }] }].
     * Ids only; the value is re-read server-side.
     */
    private static String offerPayload(Id unitId, List<Id> offerLineIds) {
        Map<Id, List<Id>> byUnit = new Map<Id, List<Id>>();
        if (unitId != null && offerLineIds != null && !offerLineIds.isEmpty()) {
            byUnit.put(unitId, offerLineIds);
        }
        return offerPayload(byUnit);
    }

    /** Basket form: one list keyed by unit covers every Sales Order. */
    private static String offerPayload(Map<Id, List<Id>> offerLineIdsByUnit) {
        if (offerLineIdsByUnit == null || offerLineIdsByUnit.isEmpty()) {
            return null;
        }
        List<Object> payload = new List<Object>();
        for (Id unitId : offerLineIdsByUnit.keySet()) {
            List<Id> ids = offerLineIdsByUnit.get(unitId);
            if (unitId == null || ids == null || ids.isEmpty()) {
                continue;
            }
            List<Map<String, Object>> lines = new List<Map<String, Object>>();
            for (Id offerId : ids) {
                lines.add(new Map<String, Object>{ 'Id' => offerId });
            }
            payload.add(new Map<String, Object>{
                'unitId' => unitId, 'offerLinesLst' => lines
            });
        }
        return payload.isEmpty() ? null : JSON.serialize(payload);
    }

    /* Quoting an offer. sendSalesOfferPDF renders Modon's Visualforce PDF and emails it. */
    public class OfferSendResult {
        @AuraEnabled public Boolean isSuccess = false;
        /** Who it went to. */
        @AuraEnabled public String sentTo;
        @AuraEnabled public String message;
    }

    /**
     * sendSalesOfferPDF returns void, so the recipient is resolved here first (same contact it
     * will use) and the agent is told a name.
     */
    @AuraEnabled
    public static OfferSendResult sendOffer(
        Id opportunityId, Id unitId, Id planId, String customerName
    ) {
        OfferSendResult out = new OfferSendResult();
        if (opportunityId == null || unitId == null || planId == null) {
            out.message = 'Choose a unit and a payment plan before sending an offer.';
            return out;
        }
        try {
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.Name, PrimaryContact__c, PrimaryContact__r.Email,
                       PrimaryContact__r.Name, Account.PersonContactId, Account.IsPersonAccount
                FROM Opportunity WHERE Id = :opportunityId LIMIT 1
            ];
            if (opps.isEmpty()) {
                out.message = 'This opportunity could not be found.';
                return out;
            }
            Opportunity opp = opps[0];
            /* mirrors sendSalesOfferPDF's target: person account contact, else primary contact */
            Boolean hasTarget = opp.Account != null && opp.Account.PersonContactId != null
                || opp.PrimaryContact__c != null;
            if (!hasTarget) {
                out.message = 'This customer has no contact to email the offer to.';
                return out;
            }

            Unit__c unit = loadUnit(unitId);
            UnitSearchLwcController.sendSalesOfferPDF(
                String.valueOf(unitId),
                unit == null ? '' : unit.Name,
                String.valueOf(opportunityId),
                customerName == null ? '' : customerName,
                String.valueOf(planId),
                null
            );

            out.isSuccess = true;
            out.sentTo = opp.PrimaryContact__r != null && String.isNotBlank(opp.PrimaryContact__r.Name)
                ? opp.PrimaryContact__r.Name
                : (opp.Account == null ? 'the customer' : opp.Account.Name);
            return out;
        } catch (Exception e) {
            out.message = wordsFor(e);
            return out;
        }
    }

    /**
     * What is payable before booking for one unit on one plan, for the basket view. Same call
     * buildSummary makes (BookingFeeLineController.previewBookingFees). Empty block, not null,
     * when it cannot answer.
     */
    @AuraEnabled(cacheable=true)
    public static FeeBlock getUnitPlanFees(Id unitId, Id paymentPlanId) {
        FeeBlock fees = new FeeBlock();
        if (unitId == null || paymentPlanId == null) {
            return fees;
        }
        try {
            Unit__c unit = loadUnit(unitId);
            BookingFeeLineController.FeePreview preview =
                BookingFeeLineController.previewBookingFees(
                    unitId, paymentPlanId, unit == null ? null : unit.TotalPrice__c
                );
            if (preview != null) {
                fees.admFee = preview.admFee;
                fees.downPayment = preview.downPayment;
                fees.minimum = preview.minimum;
            }
        } catch (Exception e) {
            /* supporting detail, not a gate; must not take the plan card down */
        }
        return fees;
    }

    /** Org base URL for the Visualforce preview link. */
    @AuraEnabled(cacheable=true)
    public static String getOrgUrl() {
        try {
            return System.Label.OrgURL;
        } catch (Exception e) {
            return URL.getOrgDomainUrl().toExternalForm();
        }
    }

    /**
     * The Experience site's URL path prefix. The offer preview must be requested from the site's
     * own origin: the Visualforce domain redirects to lightning.force.com/visualforce/session,
     * which refuses framing. It must be this site's prefix, not a bare /apex/ (which 301s into
     * the default site), and it is the Network's UrlPathPrefix, not the path the rep browses
     * (/salesconsolevforcesite serves Visualforce; /sales does not). Null outside a site.
     */
    @AuraEnabled(cacheable=true)
    public static String getSitePathPrefix() {
        try {
            Id networkId = Network.getNetworkId();
            if (networkId == null) {
                return null;
            }
            /* Network.UrlPathPrefix first (salesconsolevforcesite, where Visualforce is served);
               Site.getPathPrefix() returns the /sales alias, which 404s for /apex/ */
            List<Network> nets = [
                SELECT UrlPathPrefix FROM Network WHERE Id = :networkId LIMIT 1
            ];
            String fromNetwork = nets.isEmpty() ? null : nets[0].UrlPathPrefix;
            if (String.isNotBlank(fromNetwork)) {
                return fromNetwork.startsWith('/') ? fromNetwork : '/' + fromNetwork;
            }
            String prefix = Site.getPathPrefix();
            return String.isBlank(prefix)
                ? ''
                : (prefix.startsWith('/') ? prefix : '/' + prefix);
        } catch (Exception e) {
            return null;
        }
    }

    /* A photographed proof from c/mscCapture (base64). ChequeFileController.uploadChequeImage is not
     * reused: it refuses anything but a Cheque_Details__c id. Same downstream shape as a picked file. */
    private static final Map<String, String> PROOF_EXT_TO_MIME = new Map<String, String>{
        'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg',
        'png' => 'image/png', 'pdf' => 'application/pdf'
    };
    // matches c/mscCapture's ceiling
    private static final Integer PROOF_MAX_BYTES = 4 * 1024 * 1024;

    @AuraEnabled
    public static Id uploadProofImage(Id documentId, String base64Data, String fileName) {
        if (documentId == null) {
            throw new AuraHandledException('No proof slot was supplied.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('The image was empty. Please capture it again.');
        }
        String safeName = String.isBlank(fileName) ? 'proof.jpg' : fileName.trim();
        String ext = safeName.contains('.')
            ? safeName.substringAfterLast('.').toLowerCase()
            : 'jpg';
        if (!PROOF_EXT_TO_MIME.containsKey(ext)) {
            throw new AuraHandledException(
                'That file type is not supported. Use a JPG, PNG or PDF.');
        }

        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('The image could not be read. Please capture it again.');
        }
        if (body.size() > PROOF_MAX_BYTES) {
            throw new AuraHandledException(
                'That image is too large. Please retake it, or attach a smaller file.');
        }

        /* read the slot with sharing first: a bare ContentVersion insert is not sharing-filtered */
        List<Documents__c> slots = [
            SELECT Id, Status__c FROM Documents__c WHERE Id = :documentId LIMIT 1
        ];
        if (slots.isEmpty()) {
            throw new AuraHandledException(
                'This proof could not be found, or you do not have access to it.');
        }

        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = safeName;
            cv.PathOnClient = safeName;
            cv.VersionData = body;
            // link the file to the slot and keep it out of the private library
            cv.FirstPublishLocationId = documentId;
            insert cv;
            return cv.Id;
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /**
     * Removes a proof the rep attached and has not recorded, slot and files together. Refuses once
     * the proof sits on a Payment.
     */
    @AuraEnabled
    public static void deleteProofSlot(Id documentId) {
        if (documentId == null) {
            return;
        }
        try {
            List<Documents__c> docs = [
                SELECT Id, Status__c, Receipt__c, Receipt__r.Name,
                       (SELECT ContentDocumentId FROM ContentDocumentLinks)
                FROM Documents__c WHERE Id = :documentId LIMIT 1
            ];
            if (docs.isEmpty()) {
                return;
            }
            Documents__c slot = docs[0];
            if (slot.Receipt__c != null) {
                throw refusal(
                    'This proof is recorded on Payment ' + (slot.Receipt__r != null ? slot.Receipt__r.Name : '')
                    + ' and cannot be removed here.');
            }
            List<ContentDocument> files = new List<ContentDocument>();
            if (slot.ContentDocumentLinks != null) {
                for (ContentDocumentLink cdl : slot.ContentDocumentLinks) {
                    files.add(new ContentDocument(Id = cdl.ContentDocumentId));
                }
            }
            /* elevated: the ContentDocument is owned by the uploader; the slot was read with sharing */
            new LedgerWriteContext().deleteSlotWithFiles(slot, files);
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }


    // 5b. A proof records a Payment

    /**
     * Records the payment a captured proof is evidence of, as Modon's Create Payment does:
     * Create_Receipt_SO for the ADM + Dari charge (Receipt__c on the Sales Order with Charge__c and
     * the ADM flag), Create_Receipt_SOI for an installment. In Progress, with mode, reference and
     * date (or cheque number, date, bank and a Cheque_Details__c row), amount, and the proof files
     * linked. Modon's trigger allocates it; Finance approves it. Slots are stamped with the Payment.
     * Every check runs before any DML; savepoint; amount capped at the invoice's unapplied remainder.
     */
    @AuraEnabled
    public static ProofPaymentResultDTO recordProofPayment(ProofPaymentInput input) {
        if (input == null || input.salesOrderId == null || input.sourceId == null) {
            throw refusal('A payment must be selected before it can be recorded.');
        }
        /* Phase 4: before the savepoint and before any Receipt, Cheque_Details__c or file link
           is written. Resolved from the Sales Order, which is what this method is given. */
        assertKycEligibleForSalesOrder(input.salesOrderId);
        SalesOrder__c so = loadSalesOrder(input.salesOrderId);
        if (so == null) {
            throw refusal(
                'This booking could not be found, or you do not have access to it.');
        }
        FinanceReadContext finance = new FinanceReadContext();

        // the row: which invoice, and is it still open
        SalesOrderInstallments__c soi;
        Invoice__c inv;
        String rowLabel;
        Decimal open;
        if (input.bucketKey == BUCKET_MILESTONE) {
            List<SalesOrderInstallments__c> found = [
                SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                       Balance_Amount__c, MilestoneDate__c, PaymentStatus__c, SalesOrder__c
                FROM SalesOrderInstallments__c
                WHERE Id = :input.sourceId AND SalesOrder__c = :so.Id
                LIMIT 1
            ];
            if (found.isEmpty()) {
                throw refusal('That milestone does not belong to this booking.');
            }
            soi = found[0];
            rowLabel = milestoneLabelFor(soi);
            if (soi.MilestoneNumber__c != null && soi.MilestoneNumber__c > 1) {
                throw refusal(rowLabel
                    + ' is paid through Add cheques or Set up Direct Debit on the milestone box.');
            }
            inv = finance.invoiceByInstallment(new Set<Id>{ soi.Id }).get(soi.Id);
            if (inv == null) {
                throw refusal(rowLabel + ': no invoice has been raised for it yet.');
            }
            open = fils(openAmountFor(soi, inv));
        } else if (input.bucketKey == BUCKET_ADM_CHARGE) {
            rowLabel = LABEL_ADM_DARI;
            inv = finance.admChargeBySalesOrder(new Set<Id>{ so.Id }).get(so.Id);
            if (inv == null || inv.Id != input.sourceId) {
                throw refusal(
                    'The ADM + Dari charge of this booking could not be found.');
            }
            open = openAmountOfInvoice(inv);
        } else {
            throw refusal(
                'Payments are recorded here for the ADM + Dari charge and the down payment only.');
        }
        if (nz(inv.InvoiceBalance__c) <= 0) {
            throw refusal(rowLabel + ': the invoice is already paid.');
        }

        // the fields, as Modon's form asks them
        String method = blankToNull(input.method);
        String residency = residencyFor(so.Opportunity__c, so.Id);
        Set<String> allowed = new Set<String>(methodsFor(
            input.bucketKey == BUCKET_MILESTONE ? BUCKET_MILESTONE : BUCKET_ADM, residency));
        if (method == null) {
            throw refusal('Choose the Mode of payment.');
        }
        if (!allowed.contains(method)) {
            throw refusal('"' + method + '" is not a Mode of payment offered here.');
        }
        Boolean isCheque = method == MOP_CHEQUE;
        String reference = blankToNull(input.transactionNumber);
        if (reference == null) {
            throw refusal(isCheque ? 'Enter the Cheque Number.' : 'Enter the Transaction Number.');
        }
        if (input.paidDate == null) {
            throw refusal(isCheque ? 'Enter the Cheque Date.' : 'Enter the Transaction Date.');
        }
        if (!isCheque && input.paidDate > Date.today()) {
            throw refusal('The Transaction Date cannot be in the future.');
        }
        String bank = blankToNull(input.bank);
        if (isCheque) {
            if (bank == null) {
                throw refusal('Choose the Customer Bank the cheque is drawn on.');
            }
            Set<String> banks = new Set<String>();
            for (OptionDTO o : picklistOptions(Receipt__c.Bank__c.getDescribe())) {
                banks.add(o.value);
            }
            if (!banks.contains(bank)) {
                throw refusal('Choose the Customer Bank from the list.');
            }
        } else {
            bank = null;
        }
        Decimal amount = input.amount == null ? null : fils(input.amount);
        if (amount == null || amount <= 0) {
            throw refusal('The amount must be more than zero.');
        }
        if (open <= 0) {
            throw refusal(rowLabel
                + ': nothing is open to a new payment - what is left is already with Finance.');
        }
        if (amount > open) {
            throw refusal(rowLabel + ': AED ' + amount.format()
                + ' is more than the AED ' + open.format() + ' still open on it.');
        }
        if (finance.liveReferencesFor(so.Id).contains(reference.toUpperCase())) {
            throw refusal('A payment with '
                + (isCheque ? 'cheque number ' : 'transaction number ') + reference
                + ' is already recorded on this booking.');
        }
        if (isCheque) {
            /* MSC-205: what a bank would refuse, refused here */
            String dateProblem = chequeDateProblem(input.paidDate);
            if (dateProblem != null) {
                throw refusal(dateProblem);
            }
            String other = otherBookingWithCheque(so, reference);
            if (other != null) {
                throw refusal('Cheque ' + reference + ' is already recorded on booking ' + other + '.');
            }
        }

        // the proof: at least one file, on this row, not yet recorded
        Set<Id> docIds = new Set<Id>();
        if (input.documentIds != null) {
            for (Id d : input.documentIds) {
                if (d != null) docIds.add(d);
            }
        }
        if (docIds.isEmpty()) {
            throw refusal('Attach the proof of payment before creating the payment.');
        }
        List<Documents__c> slots = finance.proofSlots(docIds);
        if (slots.size() != docIds.size()) {
            throw refusal('One of the attached proofs could not be found. Attach it again.');
        }
        Set<Id> fileIds = new Set<Id>();
        for (Documents__c slot : slots) {
            if (slot.SalesOrder__c != so.Id) {
                throw refusal('One of the attached proofs belongs to another booking.');
            }
            Id target = slot.Sales_Order_Installment__c != null
                ? slot.Sales_Order_Installment__c
                : (slot.Invoice__c != null ? slot.Invoice__c : slot.Booking_Fee_Line__c);
            if (target != input.sourceId) {
                throw refusal('One of the attached proofs belongs to another payment on this booking.');
            }
            if (slot.Receipt__c != null) {
                throw refusal('One of the attached proofs is already recorded on a Payment.');
            }
            if (slot.ContentDocumentLinks == null || slot.ContentDocumentLinks.isEmpty()) {
                throw refusal('One of the proofs has no file on it. Attach the file again.');
            }
            for (ContentDocumentLink cdl : slot.ContentDocumentLinks) {
                fileIds.add(cdl.ContentDocumentId);
            }
        }

        // write: payment, files, slots, or nothing
        Savepoint sp = Database.setSavepoint();
        Receipt__c rec = new Receipt__c();
        Cheque_Details__c reg;
        try {
            LedgerWriteContext writer = new LedgerWriteContext();
            if (isCheque) {
                // Manage Cheques' register row
                reg = new Cheque_Details__c();
                reg.Cheque_No__c = reference;
                reg.Cheque_Date__c = input.paidDate;
                reg.Amount__c = amount;
                reg.Bank__c = bank;
                reg.Sales_Order__c = so.Id;
                reg.Sales_Order_Installment__c = soi == null ? null : soi.Id;
                reg.Invoice__c = inv.Id;
                reg.MileStoneNumber__c = soi == null || soi.MilestoneNumber__c == null
                    ? null : String.valueOf(Integer.valueOf(soi.MilestoneNumber__c));
                reg.Unit__c = so.Unit__c;
                reg.Account__c = so.CustomerAccount__c;
                reg.Status__c = CHEQUE_REGISTER_PROCESSED;
                writer.insertRegisters(new List<Cheque_Details__c>{ reg });
            }
            rec.Account__c = so.CustomerAccount__c;
            rec.SalesOrder__c = so.Id;
            if (soi != null) {
                // Create_Receipt_SOI's shape: on the installment
                rec.SalesOrderInstallment__c = soi.Id;
            } else {
                /* Create_Receipt_SO's shape: on the Sales Order, ADM flag, invoice's Charge__c */
                rec.Is_ADM_Fees_and_Dari_charges__c = true;
                rec.Charge__c = inv.Charge__c;
            }
            rec.Modeofpayment__c = method;
            rec.TransactionNumber__c = reference;
            if (isCheque) {
                rec.Cheque_Number__c = reference;
                rec.ChequeDate__c = input.paidDate;   // Modon's before-insert copies it to TransactionDate__c
                rec.Bank__c = bank;
                rec.Cheque_Details__c = reg.Id;
            } else {
                rec.TransactionDate__c = Datetime.newInstance(input.paidDate, Time.newInstance(0, 0, 0, 0));
            }
            rec.Receipt_Amount__c = amount;
            rec.TotalAmount__c = amount;
            rec.ReceiptDate__c = Date.today();
            rec.Status__c = RECEIPT_IN_PROGRESS;
            rec.ReceiptRemarks__c = CONSOLE_RECEIPT_REMARK;
            writer.insertReceipts(new List<Receipt__c>{ rec });

            // proof files onto the payment, and the register
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Id fileId : fileIds) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = fileId, LinkedEntityId = rec.Id,
                    ShareType = 'V', Visibility = 'AllUsers'));
                if (reg != null) {
                    links.add(new ContentDocumentLink(
                        ContentDocumentId = fileId, LinkedEntityId = reg.Id,
                        ShareType = 'V', Visibility = 'AllUsers'));
                }
            }
            writer.insertLinks(links);

            // slots now belong to this payment
            List<Documents__c> stamped = new List<Documents__c>();
            for (Documents__c slot : slots) {
                stamped.add(new Documents__c(Id = slot.Id, Receipt__c = rec.Id));
            }
            writer.updateSlots(stamped);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw refusedAsIs('Nothing was recorded. ' + dmlWords(e));
        } catch (Exception e) {
            Database.rollback(sp);
            throw refusedAsIs('Nothing was recorded. ' + wordsFor(e));
        }

        // read back: did Modon's trigger allocate it?
        ProofPaymentResultDTO out = new ProofPaymentResultDTO();
        out.recorded = true;
        out.receiptId = rec.Id;
        List<Receipt__c> named = [SELECT Id, Name FROM Receipt__c WHERE Id = :rec.Id LIMIT 1];
        out.receiptName = named.isEmpty() ? null : named[0].Name;
        out.allocated = finance.receiptsWithAllocation(new Set<Id>{ rec.Id }).contains(rec.Id);
        out.message = 'Payment ' + (out.receiptName == null ? '' : out.receiptName)
            + (out.allocated ? ' recorded · with Finance' : ' recorded · Finance to allocate');
        if (isCheque && reg != null && ChequeOcrService.isConfigured()) {
            /* MSC-197: the console reads the image while the rep is filling the form. When it
               succeeded, stamp what it found instead of paying for the same read twice; only a
               cheque nobody has read goes to the queueable. */
            ChequeReadInput given = input.chequeRead;
            if (given != null && given.status == 'read') {
                try {
                    ChequeOcrService.ChequeRead r = new ChequeOcrService.ChequeRead();
                    r.isCheque = true;
                    r.legible = true;
                    r.chequeNumber = given.chequeNumber;
                    r.chequeDate = given.chequeDate;
                    r.amount = given.amount;
                    r.amountInWords = given.amountInWords;
                    r.bankName = given.bankName;
                    r.accountNumber = given.accountNumber;
                    r.iban = given.iban;
                    r.payee = given.payee;
                    ChequeOcrService.applyRead(reg.Id, r, JSON.serialize(given));
                } catch (Exception ignore) {
                    /* a read is a convenience; it never costs the rep the payment */
                }
            } else {
                for (Id fileId : fileIds) {
                    ChequeOcrService.requestRead(reg.Id, fileId);
                    break;
                }
            }
        }
        return out;
    }

    /** buildBuckets' openAmount for an invoice row (the ADM + Dari charge). */
    private static Decimal openAmountOfInvoice(Invoice__c inv) {
        if (inv == null) {
            return 0;
        }
        Decimal remaining = fils(nz(inv.InvoiceAmount__c) - nz(inv.TotalPaidAmount__c));
        Decimal cap = fils(nz(inv.InvoiceAmount__c) - nz(inv.AppliedAmount__c));
        Decimal open = Math.min(remaining, cap);
        return open > 0 ? open : 0;
    }

    /**
     * AuraHandledException with setMessage too, so getMessage() in Apex returns the reason and
     * tests can assert it.
     */
    private static AuraHandledException refusal(String message) {
        /* 1.70: in the console's words - see consoleWording */
        String worded = consoleWording(message);
        AuraHandledException e = new AuraHandledException(worded);
        e.setMessage(worded);
        return e;
    }

    /** 1.81 - the same, word for word (the Sales App's own sentences are not reworded). */
    private static AuraHandledException refusedAsIs(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * 1.70 - P8. MODON's refusals name their records: "...for this opportunity", "...the Primary
     * Contact". The console calls the same things a booking and the customer, and no screen says
     * Opportunity. Whole words only, so nothing inside another word is touched.
     */
    @TestVisible
    private static String consoleWording(String raw) {
        if (String.isBlank(raw)) {
            return raw;
        }
        String s = raw;
        s = s.replaceAll('(?i)\\bthe primary contact\\b', 'the customer');
        s = s.replaceAll('\\bPrimary Contact\\b', 'Customer');
        s = s.replaceAll('(?i)\\bprimary contact\\b', 'customer');
        s = s.replaceAll('(?i)\\ban opportunity\\b', 'a booking');
        s = s.replaceAll('(?i)\\b(this|the|a) opportunity\\b', '$1 booking');
        s = s.replaceAll('\\bOpportunities\\b', 'Bookings');
        s = s.replaceAll('\\bOpportunity\\b', 'Booking');
        s = s.replaceAll('\\bopportunities\\b', 'bookings');
        s = s.replaceAll('\\bopportunity\\b', 'booking');
        return s;
    }

    /* ══ 1.85 - MODON's refusals in MODON's words ═══════════════════════════════════
     * Engine sentences and validation rule errors are shown as written, as the Sales App does.
     * Only a raw platform error still goes through friendly(). */

    /** Marks of a raw platform error rather than a sentence written for a rep. Lower case. */
    private static final List<String> PLATFORM_ERROR_MARKS = new List<String>{
        'insufficient access', 'field integrity', 'unable to lock row', 'unable to obtain exclusive access',
        'first error:', 'first exception on row', 'script-thrown exception', 'attempt to de-reference',
        'list has no rows', 'list index out of bounds', 'too many soql', 'too many dml',
        'cpu time limit', 'invalid id:', 'invalid id field', 'invalid cross reference',
        'required fields are missing', 'entity is deleted', 'duplicate value found',
        'argument cannot be null', 'no such column', 'uncommitted work pending', 'maximum trigger depth'
    };

    /** True for a raw platform error: an Apex exception type, a status code, or one of the marks above. */
    @TestVisible
    private static Boolean isPlatformError(String raw) {
        if (String.isBlank(raw)) {
            return false;
        }
        /* an exception type (System.DmlException) or a status code (UNABLE_TO_LOCK_ROW) */
        if (Pattern.compile('[a-z]Exception\\b|\\b[A-Z]{2,}(_[A-Z]+)+\\b').matcher(raw).find()) {
            return true;
        }
        String m = raw.toLowerCase();
        for (String mark : PLATFORM_ERROR_MARKS) {
            if (m.contains(mark)) {
                return true;
            }
        }
        return false;
    }

    /**
     * What MODON's engine returned as a refusal (saveSalesOrder, syncBookingFeeLines,
     * initiatePaymentHold, finalizeBooking), word for word. A blank answer or a raw platform error
     * keeps friendly(), as before.
     */
    @TestVisible
    private static String modonsWords(String raw) {
        if (String.isBlank(raw) || isPlatformError(raw)) {
            return friendly(raw);
        }
        lastRawError = raw;
        return raw;
    }

    /**
     * A save refused by MODON's validation rule, trigger or flow: that sentence as written, the
     * way Salesforce shows it in the Sales App. Any other DML failure: friendly(), as before.
     */
    private static String dmlWords(DmlException e) {
        return e != null && e.getNumDml() > 0
            ? dmlWords(e.getDmlType(0), e.getDmlMessage(0))
            : friendly(e == null ? null : e.getMessage());
    }

    @TestVisible
    private static String dmlWords(StatusCode code, String message) {
        if (code == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION && String.isNotBlank(message)) {
            lastRawError = message;
            return message;
        }
        return friendly(message);
    }

    /** Any caught exception: a MODON validation rule's sentence as is, anything else as before. */
    private static String wordsFor(Exception e) {
        if (e instanceof DmlException) {
            DmlException d = (DmlException) e;
            if (d.getNumDml() > 0 && d.getDmlType(0) == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
                return dmlWords(d);
            }
        }
        return friendly(e == null ? null : e.getMessage());
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * SIGNZY PHASE 4 - THE KYC HARD GATE, INSIDE THE MONEY.
     *
     * WHY IT LIVES HERE AND NOT IN A WRAPPER. Every @AuraEnabled method below is reachable
     * directly by anything that can call Apex - a crafted client, a stale tab, another
     * component. A guard in an LWC, or in a separate service the caller could skip, is a hint
     * rather than a rule. Putting the check inside the money methods themselves is what makes
     * it enforcement, and it is why ownership of this class was granted.
     *
     * ONE HELPER, NO DUPLICATED RULES. This decides only WHEN to ask. What "eligible" means
     * stays entirely inside AurelixKycEligibilityService - both buyer types take MODON's own
     * checkKYCEligibility; a company on its primary contact, the POA (AurelixKycEligibilityService
     * 2.9). No KYC arithmetic is written here and none may be.
     *
     * THE SWITCH IS RUNTIME, NOT COMPILE TIME. enforcementActive on the verdict reflects
     * Sales_Console_Config__mdt for THIS customer's type: PERSON_KYC_HARD_GATE for a person,
     * ORGANISATION_KYC_HARD_GATE for a company. Off means this method behaves exactly as it did
     * before Phase 4 - so rollback is unticking a checkbox in Setup, with no deployment.
     * ══════════════════════════════════════════════════════════════════════════════ */

    /** Said to the representative when the gate refuses and there is nothing safer to say. */
    private static final String KYC_BLOCK_DEFAULT = 'Complete customer KYC before payment.';
    /** Said when the verdict itself could not be reached while a gate is on. */
    private static final String KYC_BLOCK_UNKNOWN =
        'KYC status could not be verified. Refresh and try again.';

    /**
     * Refuse this booking's money or commitment unless KYC passes. Call it BEFORE the first
     * side effect of whatever method you are in - before DML, before a hold, before a callout,
     * before a fee line. A guard after the write is not a guard.
     *
     * A null Opportunity is left alone: every caller already refuses that in its own words, and
     * inventing a second refusal here would change messages the console has shipped with.
     */
    private static void assertKycEligibleForMoney(Id opportunityId) {
        if (opportunityId == null) {
            return;
        }

        AurelixKycEligibilityService.KycStateDTO verdict;
        try {
            verdict = AurelixKycEligibilityService.evaluate(opportunityId);
        } catch (Exception e) {
            /* FAIL CLOSED, but only while a gate is on. In Phase 2/3 this panel was advisory and
               a failure was silently ignored; once money depends on the answer, "we could not
               tell" must never be read as "verified". With every gate off, an evaluation failure
               still changes nothing - old behaviour is preserved exactly. */
            if (AurelixKycEligibilityService.isEnforcementOn()) {
                throw refusal(KYC_BLOCK_UNKNOWN);
            }
            return;
        }

        /* Same reasoning for a verdict that came back empty. */
        if (verdict == null) {
            if (AurelixKycEligibilityService.isEnforcementOn()) {
                throw refusal(KYC_BLOCK_UNKNOWN);
            }
            return;
        }

        /* The service decided which switch applies to this buyer type. Off: nothing changes. */
        if (verdict.enforcementActive != true) {
            return;
        }
        if (verdict.eligible == true) {
            return;
        }

        /* The specific reason where the service gave one - "these documents are missing" helps a
           rep far more than a generic sentence - and the generic sentence otherwise. Neither
           names a class, a field or anything about the integration. */
        /* 1.82: MODON's sentence word for word; the console's default is its own. */
        if (String.isNotBlank(verdict.blockedReason)) {
            throw refusedAsIs(verdict.blockedReason);
        }
        throw refusal(KYC_BLOCK_DEFAULT);
    }

    /**
     * The same gate for the post-booking money methods, which are handed a Sales Order rather
     * than an Opportunity. Resolves the booking's Opportunity and asks the same question.
     */
    private static void assertKycEligibleForSalesOrder(Id salesOrderId) {
        if (salesOrderId == null) {
            return;
        }
        Id opportunityId;
        for (SalesOrder__c so : [
            SELECT Opportunity__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
        ]) {
            opportunityId = so.Opportunity__c;
        }
        assertKycEligibleForMoney(opportunityId);
    }

    /** Receipt__c.Bank__c values, for the cheque path. */
    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> getReceiptBankOptions() {
        return picklistOptions(Receipt__c.Bank__c.getDescribe());
    }

    // 6. Required documents

    /**
     * Merges the checklist catalogue (by residency) with its approval state; merging on the client
     * would duplicate DocumentChecklistController's team/label keying.
     */
    @AuraEnabled(cacheable=false)
    public static DocumentRequirementDTO getRequiredDocuments(Id salesOrderId, Id opportunityId) {
        DocumentRequirementDTO dto = new DocumentRequirementDTO();
        dto.residentStatus = residencyFor(opportunityId, salesOrderId);
        if (String.isBlank(dto.residentStatus)) {
            // no residency, no correct document list
            return dto;
        }
        try {
            /* typed, not JSON round-tripped: the untyped map read keys ChecklistWrapper does not have,
             * so every document came back unlabelled and unapproved */
            Map<String, List<DocumentChecklistController.ChecklistWrapper>> catalogue;
            try {
                catalogue = DocumentChecklistController.getDocumentChecklistMetadata(
                    dto.residentStatus, true, null);
            } catch (Exception ignored) {
                catalogue = null;
            }

            // catalogue = what this residency requires; approval lives on Document_Checklist__c,
            // keyed team + label
            Map<String, Map<String, DocumentChecklistController.ChecklistItemDTO>> reviewed =
                latestChecklistState(salesOrderId);

            if (catalogue != null) {
                for (String team : catalogue.keySet()) {
                    Map<String, DocumentChecklistController.ChecklistItemDTO> teamState =
                        reviewed.get(team);
                    for (DocumentChecklistController.ChecklistWrapper w : catalogue.get(team)) {
                        ChecklistItemDTO item = new ChecklistItemDTO();
                        item.team = team;
                        item.label = w.label;

                        DocumentChecklistController.ChecklistItemDTO state =
                            (teamState == null || String.isBlank(w.label))
                                ? null : teamState.get(w.label);
                        if (state != null) {
                            item.status = state.approvalSts;
                            item.rejectionReason = state.rejectionReason;
                        }
                        item.received = item.status == 'Approved';

                        /* Sales' own items are the checklist; other teams' go in the fold */
                        if (team == TEAM_SALES) {
                            dto.items.add(item);
                            if (!item.received) {
                                dto.outstandingLabels.add(item.label);
                            }
                        } else {
                            dto.laterItems.add(item);
                        }
                    }
                }
            }

            /* the fold's summary, counted here */
            dto.laterCount = dto.laterItems.size();
            Set<String> seen = new Set<String>();
            for (ChecklistItemDTO item : dto.laterItems) {
                if (String.isNotBlank(item.team)) { seen.add(item.team); }
            }
            for (String team : TEAM_ORDER) {
                if (seen.remove(team)) { dto.laterTeams.add(team); }
            }
            /* teams the order does not name are still listed */
            List<String> leftovers = new List<String>(seen);
            leftovers.sort();
            dto.laterTeams.addAll(leftovers);
            if (salesOrderId != null) {
                for (SalesOrder__c so : [
                    SELECT Id, Further_Documents_Required__c
                    FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
                ]) {
                    dto.furtherDocumentsRequired = so.Further_Documents_Required__c == true;
                }
            }
            /* outstanding items no longer force furtherDocumentsRequired: the field is a formula
             * meaning "parked with a review team, or a payment landed short", and it is false on a
             * booking that has simply not been worked yet. Progress is items/outstandingLabels. */
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return dto;
    }

    /**
     * Approval state for a Sales Order's checklist, team -> label -> item. Empty before a Sales
     * Order exists. Delegates to DocumentChecklistController.getLatestChecklistMap.
     */
    private static Map<String, Map<String, DocumentChecklistController.ChecklistItemDTO>>
            latestChecklistState(Id salesOrderId) {
        Map<String, Map<String, DocumentChecklistController.ChecklistItemDTO>> empty =
            new Map<String, Map<String, DocumentChecklistController.ChecklistItemDTO>>();
        if (salesOrderId == null) {
            return empty;
        }
        try {
            Map<String, Object> raw =
                DocumentChecklistController.getLatestChecklistMap(salesOrderId);
            Object m = raw == null ? null : raw.get('teamChecklistMap');
            if (m == null) {
                return empty;
            }
            return (Map<String, Map<String, DocumentChecklistController.ChecklistItemDTO>>) m;
        } catch (Exception e) {
            // advisory only; losing the review state must not take the panel down
            return empty;
        }
    }

    // 7. Direct Debit

    /**
     * Direct Debit is a mandate request, not a payment; coversMilestones stays false until the bank
     * approves. Read through the elevated island because Sales Management cannot see
     * DirectDebitRequest__c and another user's mandate must still show and block a second.
     */
    @AuraEnabled(cacheable=false)
    public static DirectDebitStateDTO getDirectDebitState(Id salesOrderId) {
        DirectDebitStateDTO dto = new DirectDebitStateDTO();
        if (salesOrderId == null) {
            return dto;
        }
        try {
            /* 1.68: the whole lifecycle comes from AurelixDirectDebitService; this DTO keeps the
               shape the milestone box binds to and carries the card for c/mscMandateCard. */
            AurelixDirectDebitService.CardDTO card = AurelixDirectDebitService.cardForOrder(salesOrderId);
            dto.card = card;
            dto.stage = card.stage;
            dto.slotFree = card.slotFree == true;
            dto.canRequest = card.slotFree == true;
            if (card.mandateId == null) {
                dto.mandateStatusLabel = 'Not requested';
                return dto;
            }
            dto.mandateId = card.mandateId;
            dto.mandateStatus = card.status;
            dto.mandateStatusLabel = card.stageLabel;
            dto.coversMilestones = card.coversMilestones == true;
            dto.covering = card.covering == true;
            dto.commencesOn = card.commencesOn;
            dto.expiresOn = card.expiresOn;
            dto.maximumAmount = card.maximumAmount;
            dto.requestName = card.name;
            dto.approve = card.approved == true;
            dto.holderName = card.holderName;
            dto.bank = card.bank;
            dto.accountType = card.accountType;
            dto.ibanMasked = card.ibanMasked;
            dto.idType = card.idType;
            dto.idNumber = card.idNumber;
            dto.mobile = card.mobile;
            dto.requestedOn = card.requestedOn;
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return dto;
    }

    /** 1.68: kept for older readers; the stage label now comes from AurelixDirectDebitService. */
    private static String ddLabel(String status) {
        if (status == 'Approved' || status == 'Approved By Bank') return 'Active';
        if (status == 'Rejected' || status == 'Rejected By Bank') return 'Rejected';
        if (status == 'Send To Bank') return 'With the bank';
        if (status == 'Cancelled') return 'Cancelled';
        if (String.isBlank(status)) return 'Submitted';
        return 'In review';
    }

    /** "AE07 **** **** **** **** 456" */
    private static String maskIban(String iban) {
        if (String.isBlank(iban)) {
            return null;
        }
        String flat = iban.replaceAll('\\s', '');
        if (flat.length() <= 8) {
            return flat;
        }
        return flat.substring(0, 4) + ' **** ' + flat.substring(flat.length() - 4);
    }

    /* MSC-112 helpers: fallbacks, masking, write policy */

    /** First non-blank of the lot, or null. */
    @TestVisible
    private static String firstNonBlank(List<String> values) {
        for (String v : values) {
            if (String.isNotBlank(v)) {
                return v;
            }
        }
        return null;
    }

    /* self-contained masking; the org's Serviceclass maskers throw on short values */
    @TestVisible
    private static String maskEmailValue(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        Integer at = email.indexOf('@');
        if (at <= 0) {
            return '***';
        }
        String localPart = email.substring(0, at);
        return localPart.substring(0, Math.min(2, localPart.length()))
            + '***@' + email.substring(at + 1);
    }

    @TestVisible
    private static String maskPhoneValue(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() < 4) {
            return '****';
        }
        return '****' + digits.substring(digits.length() - 4);
    }

    /** Mask a document number, maskIban's shape. */
    @TestVisible
    private static String maskTail(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String flat = value.replaceAll('\\s', '');
        if (flat.length() <= 4) {
            return '****';
        }
        return '**** ' + flat.substring(flat.length() - 4);
    }

    /**
     * A "masked" field is not guaranteed masked (AccountTriggerHelper copies En_ into Masked_ after
     * masking, and En_ read from Apex is clear). Masks unless it already carries a star.
     */
    @TestVisible
    private static String ensureMasked(String value, String kind) {
        if (String.isBlank(value)) {
            return null;
        }
        if (value.contains('*')) {
            return value;
        }
        if (kind == 'email') {
            return maskEmailValue(value);
        }
        if (kind == 'phone') {
            return maskPhoneValue(value);
        }
        return maskTail(value);
    }

    /**
     * May this input land on this stored value? Blank inputs are skipped; a starred value is a
     * masked round-trip; a populated stored value is overwritten only while the customer is fresh.
     */
    @TestVisible
    private static Boolean writable(String incoming, String current, Boolean fresh) {
        return String.isNotBlank(incoming)
            && !incoming.contains('*')
            && incoming != current
            && (fresh == true || String.isBlank(current));
    }

    /** Lock the field when a stored value exists, with the reason. */
    private static void lockIf(Map<String, String> locks, String field, String stored, String reason) {
        if (String.isNotBlank(stored)) {
            locks.put(field, reason);
        }
    }

    /**
     * 1.68: raises the mandate as MODON's own Draft. The console's gates run first - KYC (Phase 4),
     * a standing mandate (MODON's DEAD_STATUSES), cheques with Finance, order status, residency,
     * organisation - then AurelixDirectDebitService.createDraft calls
     * UAEDDS_LWCController.createMandateRecord (record type UAEDDS, Status Draft, e-mail, city,
     * config defaults, + 548-day expiry; MODON's trigger derives commences / maximum / originator
     * and creates the document placeholder). The Sales Order's Direct Debit lookup is set best
     * effort, as before. Finance sends the Draft to the bank from MODON's Direct Debit Actions.
     */
    @AuraEnabled
    public static DirectDebitStateDTO submitDirectDebitMandate(DirectDebitInput input) {
        if (input == null || input.salesOrderId == null) {
            throw new AuraHandledException('No booking was supplied.');
        }
        /* Phase 4: a mandate is a payment instrument against the schedule. Checked before any
           DirectDebitRequest__c is written. */
        assertKycEligibleForSalesOrder(input.salesOrderId);
        DirectDebitStateDTO current = getDirectDebitState(input.salesOrderId);
        if (!current.canRequest) {
            // re-check server-side; the client may be stale
            throw new AuraHandledException(
                'A Direct Debit mandate already stands for this booking (' +
                current.mandateStatusLabel + ').');
        }
        SalesOrder__c so = loadSalesOrder(input.salesOrderId);
        if (so == null) {
            throw new AuraHandledException(
                'This booking could not be found, or you do not have access to it.');
        }
        FinanceReadContext finance = new FinanceReadContext();
        /* the cheap refusal first (one query), as 1.41 did; residency costs two more */
        Integer liveCheques = finance.liveChequeCountAfterDownPayment(so.Id);
        if (liveCheques > 0) {
            throw new AuraHandledException(AurelixDirectDebitService.REASON_CHEQUES + ' '
                + 'Direct Debit is not offered while they stand.');
        }
        AurelixDirectDebitService.EligibilityInput ein = new AurelixDirectDebitService.EligibilityInput();
        ein.salesOrderStatus = so.Status__c;
        ein.residency = residencyFor(so.Opportunity__c, so.Id);
        ein.isPersonAccount = so.CustomerAccount__r == null || so.CustomerAccount__r.IsPersonAccount == true;
        ein.liveChequeCount = liveCheques;
        ein.hasLines = true;
        ein.card = current.card;
        AurelixDirectDebitService.EligibilityDTO verdict = AurelixDirectDebitService.eligibility(ein);
        if (verdict.allowed != true) {
            throw new AuraHandledException(
                String.isBlank(verdict.reason) ? 'Direct Debit is not offered on this booking.' : verdict.reason);
        }
        String linkNote;
        List<String> problems;
        try {
            AurelixDirectDebitService.DraftInput d = new AurelixDirectDebitService.DraftInput();
            d.salesOrderId = so.Id;
            d.holderName = input.accountName;
            d.bankName = input.bankName;
            d.accountType = input.accountType;
            d.iban = input.iban;
            d.idType = input.idType;
            d.idNumber = input.idNumber;
            d.mobile = input.mobile;
            d.email = input.email;
            d.city = input.city;
            AurelixDirectDebitService.CardDTO card = AurelixDirectDebitService.createDraft(d);
            problems = card.problems;
            linkNote = new LedgerWriteContext().linkMandateToOrder(so.Id, card.mandateId);
        } catch (AurelixDirectDebitService.ConsoleException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        DirectDebitStateDTO after = getDirectDebitState(input.salesOrderId);
        after.linkNote = linkNote;
        after.problems = problems;
        return after;
    }

    private static String blankToNull(String v) {
        return String.isBlank(v) ? null : v.trim();
    }

    // 7b. The milestone box: cheques after the down payment, and the mandate

    /**
     * Everything the box needs in one call: milestone lines after the down payment with what is
     * open to a cheque (from buildBuckets), the picklists (from the schema), the customer prefill,
     * the mandate state, the line Modon's trigger will stamp, and the two exclusivity answers.
     */
    @AuraEnabled(cacheable=false)
    public static MilestoneBatchDTO getMilestoneBatch(Id salesOrderId) {
        MilestoneBatchDTO dto = new MilestoneBatchDTO();
        dto.salesOrderId = salesOrderId;
        if (salesOrderId == null) {
            return dto;
        }
        try {
            SalesOrder__c so = loadSalesOrder(salesOrderId);
            if (so == null) {
                throw new AuraHandledException(
                    'This booking could not be found, or you do not have access to it.');
            }
            String residency = residencyFor(so.Opportunity__c, so.Id);
            List<PaymentBucketDTO> rows = buildBuckets(
                so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });
            Date today = Date.today();
            for (PaymentBucketDTO b : rows) {
                if (b.key != BUCKET_MILESTONE || b.milestoneNumber == null || b.milestoneNumber <= 1
                        || b.salesOrderId != so.Id) {
                    continue;
                }
                BatchLineDTO l = new BatchLineDTO();
                l.installmentId = b.sourceId;
                l.milestoneNumber = b.milestoneNumber;
                l.label = b.label;
                l.dueDate = b.dueDate;
                l.remainingAmount = nz(b.remainingAmount);
                l.openAmount = nz(b.openAmount);
                l.withFinanceAmount = nz(b.withFinanceAmount);
                l.overdue = b.dueDate != null && b.dueDate < today && l.remainingAmount > 0;
                l.chequeDateDefault = (b.dueDate == null || b.dueDate < today) ? today : b.dueDate;
                /* instruments are every live payment; the box's questions are about cheques */
                Integer live = 0;
                Decimal liveCheques = 0;
                for (InstrumentDTO ins : b.instruments) {
                    if (ins.live == true && ins.mode == MOP_CHEQUE) {
                        live++;
                        liveCheques += nz(ins.amount);
                    }
                }
                l.instrumentCount = live;
                dto.lines.add(l);
                dto.liveChequeCount += live;
                dto.liveChequeTotal += fils(liveCheques);
                if (l.remainingAmount > 0 && l.openAmount <= 0) {
                    dto.coveredMilestones++;
                } else if (l.openAmount > 0) {
                    dto.openMilestones++;
                }
            }
            dto.bankOptions = picklistOptions(Receipt__c.Bank__c.getDescribe());
            /* 1.73: the bank field MODON's createMandateRecord and vendor payload read */
            dto.ddBankOptions = picklistOptions(DirectDebitRequest__c.UAEDDSBankName__c.getDescribe());
            dto.ddAccountTypes = picklistOptions(DirectDebitRequest__c.Customer_Bank_Account_Type__c.getDescribe());
            dto.ddIdTypes = picklistOptions(DirectDebitRequest__c.Customer_Id_Type__c.getDescribe());
            dto.prefill = ddPrefillFor(so.CustomerAccount__c, so.PrimaryContact__c);
            dto.computed = ddComputedFor(so.Id);
            dto.dd = getDirectDebitState(so.Id);
            dto.chequesAllowed = dto.dd.covering != true;
            /* 1.68: one rule, in AurelixDirectDebitService (switch, standing mandate, cheques, order
               status, residency, organisation); the reason feeds the modal's foot */
            AurelixDirectDebitService.EligibilityInput ein = new AurelixDirectDebitService.EligibilityInput();
            ein.salesOrderStatus = so.Status__c;
            ein.residency = residency;
            ein.isPersonAccount = dto.prefill == null ? true : dto.prefill.isPersonAccount;
            ein.liveChequeCount = dto.liveChequeCount;
            ein.hasLines = !dto.lines.isEmpty();
            ein.card = dto.dd.card;
            AurelixDirectDebitService.EligibilityDTO verdict = AurelixDirectDebitService.eligibility(ein);
            dto.directDebitAllowed = verdict.allowed == true;
            dto.directDebitReason = verdict.reason;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return dto;
    }

    /** Active picklist values as options. */
    private static List<OptionDTO> picklistOptions(Schema.DescribeFieldResult f) {
        List<OptionDTO> out = new List<OptionDTO>();
        for (Schema.PicklistEntry e : f.getPicklistValues()) {
            if (e.isActive()) {
                out.add(new OptionDTO(e.getValue(), e.getLabel()));
            }
        }
        return out;
    }

    /**
     * What New Direct Debit Request seeds the form with. A person pays from their own account: name,
     * Emirates ID, mobile, e-mail, bank and IBAN from the Account. 1.73: a company pays from the
     * Sales Order's Primary Contact (MODON confirmed, D7): name, Emirates ID, mobile and e-mail from that
     * contact, and the bank and IBAN are typed, because a contact holds none. A company with no
     * primary contact keeps the licence route.
     */
    private static DdPrefillDTO ddPrefillFor(Id accountId, Id primaryContactId) {
        DdPrefillDTO p = new DdPrefillDTO();
        if (accountId == null) {
            return p;
        }
        for (Account a : [
            SELECT Id, Name, IsPersonAccount, EIDNumber__pc, PersonMobilePhone, Phone,
                   TradeLicenseNumber__c, UnifiedNumber__c,
                   PersonEmail, BillingCity, IBAN_Number__c, Bank_Name__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ]) {
            p.holderName = a.Name;
            p.isPersonAccount = a.IsPersonAccount == true;
            /* 1.68: what MODON's capture seeds too (getSalesOrderDefaults) */
            p.city = a.BillingCity;
            if (a.IsPersonAccount == true) {
                p.idType = ID_TYPE_EID;
                p.idNumber = a.EIDNumber__pc;
                p.mobile = a.PersonMobilePhone;
                p.email = a.PersonEmail;
                p.bankName = knownUaeddsBank(a.Bank_Name__c);
                p.iban = a.IBAN_Number__c;
            } else if (!seedFromPrimaryContact(p, primaryContactId)) {
                p.idType = ID_TYPE_TRADE_LICENCE;
                p.idNumber = String.isNotBlank(a.TradeLicenseNumber__c) ? a.TradeLicenseNumber__c : a.UnifiedNumber__c;
                p.mobile = a.Phone;
                p.bankName = knownUaeddsBank(a.Bank_Name__c);
                p.iban = a.IBAN_Number__c;
            }
        }
        return p;
    }

    /**
     * 1.73 (D7): the payer's details from the Sales Order's Primary Contact.
     * @param p         the prefill to fill
     * @param contactId SalesOrder__c.PrimaryContact__c
     * @return false when there is no such contact to read
     */
    private static Boolean seedFromPrimaryContact(DdPrefillDTO p, Id contactId) {
        if (contactId == null) {
            return false;
        }
        /* FLS as the rep: a field they cannot read comes back blank and is typed instead */
        List<Contact> found = (List<Contact>) Security.stripInaccessible(AccessType.READABLE, [
            SELECT Name, EIDNumber__c, MobilePhone, Email FROM Contact WHERE Id = :contactId LIMIT 1
        ]).getRecords();
        for (Contact c : found) {
            p.payerIsContact = true;
            p.holderName = c.Name;
            p.idType = ID_TYPE_EID;
            p.idNumber = c.EIDNumber__c;
            p.mobile = c.MobilePhone;
            p.email = c.Email;
            return true;
        }
        return false;
    }

    /**
     * 1.73: the Account's free-text bank as a UAEDDSBankName__c value, matched the way MODON's
     * UAEDDS_LWCController.knownBank does (whole value, any case), or null: a near miss is how
     * the wrong bank gets debited, and the rep picks from the list instead.
     * @param raw Account.Bank_Name__c
     * @return the active picklist value it names, or null
     */
    @TestVisible
    private static String knownUaeddsBank(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String needle = raw.trim();
        for (Schema.PicklistEntry e : DirectDebitRequest__c.UAEDDSBankName__c.getDescribe().getPicklistValues()) {
            if (e.isActive() && e.getValue().equalsIgnoreCase(needle)) {
                return e.getValue();
            }
        }
        return null;
    }

    /**
     * What the saved mandate will carry: commences on the first unpaid milestone after the down
     * payment, maximum = largest installment except the last (1.86, as MODON's derivedTerms), expires 548 days after the last
     * (UAEDDS_LWCController.createMandateRecord corrects the trigger's 365 to 548 - 1.68). Display only.
     */
    @TestVisible
    private static DdComputedDTO ddComputedFor(Id salesOrderId) {
        DdComputedDTO c = new DdComputedDTO();
        List<SalesOrderInstallments__c> rows = [
            SELECT MilestoneNumber__c, MilestoneDate__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :salesOrderId
              AND MilestoneNumber__c != null
              AND MilestoneDate__c != null
              AND MilestoneNumber__c > 1
              AND PaymentStatus__c != 'Paid'
            ORDER BY MilestoneNumber__c ASC
        ];
        if (rows.isEmpty()) {
            return c;
        }
        c.milestoneCount = rows.size();
        c.firstMilestone = Integer.valueOf(rows[0].MilestoneNumber__c);
        c.lastMilestone = Integer.valueOf(rows[rows.size() - 1].MilestoneNumber__c);
        c.commencesOn = rows[0].MilestoneDate__c;
        c.expiresOn = rows[rows.size() - 1].MilestoneDate__c.addDays(548);
        /* 1.86 - as MODON's derivedTerms: the largest except the last (the only one when there is one) */
        Decimal max = 0;
        Integer counted = rows.size() > 1 ? rows.size() - 1 : 1;
        for (Integer k = 0; k < counted; k++) {
            SalesOrderInstallments__c r = rows[k];
            if (r.InstallmentAmount__c != null && r.InstallmentAmount__c > max) {
                max = r.InstallmentAmount__c;
            }
        }
        c.maximumAmount = max;
        return c;
    }

    /**
     * Stores a cheque image before the cheque is recorded (uploadProofImage's pattern), linked to
     * the installment from the start and to the payment and register when the batch is recorded.
     */
    @AuraEnabled
    public static ChequeImageDTO stageChequeImage(Id installmentId, String base64Data, String fileName) {
        if (installmentId == null) {
            throw new AuraHandledException('No milestone was supplied.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('The image was empty. Please capture it again.');
        }
        String safeName = String.isBlank(fileName) ? 'cheque.jpg' : fileName.trim();
        String ext = safeName.contains('.') ? safeName.substringAfterLast('.').toLowerCase() : 'jpg';
        if (!PROOF_EXT_TO_MIME.containsKey(ext)) {
            throw new AuraHandledException('That file type is not supported. Use a JPG, PNG or PDF.');
        }
        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('The image could not be read. Please capture it again.');
        }
        if (body.size() > PROOF_MAX_BYTES) {
            throw new AuraHandledException('That image is too large. Please retake it, or attach a smaller file.');
        }
        /* sharing pre-read: a bare ContentVersion insert is not sharing-filtered */
        List<SalesOrderInstallments__c> soi = [
            SELECT Id FROM SalesOrderInstallments__c WHERE Id = :installmentId LIMIT 1
        ];
        if (soi.isEmpty()) {
            throw new AuraHandledException('This milestone could not be found, or you do not have access to it.');
        }
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = safeName;
            cv.PathOnClient = safeName;
            cv.VersionData = body;
            cv.FirstPublishLocationId = installmentId;
            insert cv;
            ChequeImageDTO dto = new ChequeImageDTO();
            dto.contentVersionId = cv.Id;
            dto.contentDocumentId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ].ContentDocumentId;
            dto.fileName = safeName;
            return dto;
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /**
     * MSC-205: the same physical cheque cannot pay two bookings. Looks across the customer's
     * OTHER bookings for a live cheque receipt with this number; the same-booking case is
     * already refused by liveReferencesFor. Returns the other booking's name, or null.
     */
    private static String otherBookingWithCheque(SalesOrder__c so, String reference) {
        if (so.CustomerAccount__c == null || String.isBlank(reference)) {
            return null;
        }
        String ref = reference.trim();
        for (Receipt__c r : [
            SELECT Id, SalesOrder__r.Name, SalesOrderInstallment__r.SalesOrder__r.Name
            FROM Receipt__c
            WHERE Account__c = :so.CustomerAccount__c
              AND Modeofpayment__c = :MOP_CHEQUE
              AND (Cheque_Number__c = :ref OR TransactionNumber__c = :ref)
              AND Status__c NOT IN :RECEIPT_DEAD
            LIMIT 5
        ]) {
            String name = r.SalesOrder__r != null
                ? r.SalesOrder__r.Name
                : (r.SalesOrderInstallment__r != null && r.SalesOrderInstallment__r.SalesOrder__r != null
                    ? r.SalesOrderInstallment__r.SalesOrder__r.Name : null);
            if (name != null && name != so.Name) {
                return name;
            }
        }
        return null;
    }

    /**
     * MSC-205: the two dates no bank accepts. Stale: a UAE cheque must be presented within six
     * months of its date. Implausible: ten years ahead is a typo, not a payment plan - milestone
     * cheques legitimately run years out, so the ceiling is deliberately generous.
     */
    private static String chequeDateProblem(Date d) {
        if (d == null) {
            return null;
        }
        if (d < Date.today().addMonths(-6)) {
            return 'The cheque is older than six months; a bank will not accept it.';
        }
        if (d > Date.today().addYears(10)) {
            return 'The cheque date is too far ahead - check the year on the cheque.';
        }
        return null;
    }

    /**
     * MSC-200: is automatic cheque reading switched on? The cheque sheet and the payment form ask
     * before they draw: with reading on the number, date and amount come from the image and the
     * boxes are read-only; with it off they stay typeable, so switching it off cannot make a
     * cheque impossible to record.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isChequeReadOn() {
        try {
            return ChequeOcrService.isConfigured();
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * MSC-196: what one read may take. Measured on a real UAE cheque against
     * gemini-3.1-flash-lite-preview: 28 seconds. The old 30s cut most reads off at the knee; the
     * service's own ceiling is 120s (AI_Service_Config.Cheque_OCR.Timeout_Ms__c) and this stays
     * under it with room. The call is awaited in the background - the rep keeps typing.
     */
    private static final Integer CHEQUE_READ_TIMEOUT_MS = 100000;

    /**
     * OCR read of a staged image; a proposal, never a record. Null ONLY when automatic reading is
     * switched off; every other outcome comes back as a status the screen can say out loud.
     */
    @AuraEnabled
    public static ChequeReadDTO readChequeImage(Id contentDocumentId) {
        if (contentDocumentId == null) {
            return null;
        }
        try {
            /* null still means one thing only: the org has automatic reading switched off, and
               the screen stays silent about it */
            if (!ChequeOcrService.isConfigured()) {
                return null;
            }
            ChequeOcrService.ChequeRead r =
                ChequeOcrService.readNow(contentDocumentId, CHEQUE_READ_TIMEOUT_MS);
            ChequeReadDTO dto = new ChequeReadDTO();
            if (r == null) {
                /* timeout, HTTP error, unsupported file, oversize - readNow swallows them all */
                dto.status = 'failed';
                return dto;
            }
            if (r.isCheque == false) {
                dto.status = 'notcheque';
                return dto;
            }
            if (r.legible == false) {
                dto.status = 'unreadable';
                dto.legible = false;
                return dto;
            }
            dto.status = 'read';
            dto.chequeNumber = r.chequeNumber;
            dto.chequeDate = r.chequeDate;
            dto.amount = r.amount;
            dto.bankName = r.bankName;
            dto.payee = r.payee;
            dto.wordsAmount = r.amountInWordsValue;
            dto.iban = r.iban;
            dto.accountNumber = r.accountNumber;
            dto.amountInWords = r.amountInWords;
            dto.legible = true;
            return dto;
        } catch (Exception e) {
            ChequeReadDTO dto = new ChequeReadDTO();
            dto.status = 'failed';
            return dto;
        }
    }

    /**
     * Removes a staged image the rep replaced, only if they uploaded it and it is linked to nothing
     * but the milestone. Best effort.
     */
    @AuraEnabled
    public static void discardChequeImage(Id contentDocumentId) {
        if (contentDocumentId == null) {
            return;
        }
        try {
            List<ContentDocument> docs = [
                SELECT Id FROM ContentDocument
                WHERE Id = :contentDocumentId AND OwnerId = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (docs.isEmpty()) {
                return;
            }
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocumentId
            ]) {
                Schema.SObjectType t = l.LinkedEntityId.getSObjectType();
                if (t == User.SObjectType || t == SalesOrderInstallments__c.SObjectType) {
                    continue;
                }
                return;
            }
            delete docs;
        } catch (Exception e) {
            // best effort
        }
    }

    /**
     * Records a batch of cheques against the milestones after the down payment: one Receipt__c per
     * cheque (Modon's Create Payment shape, In Progress, image linked) plus a Cheque_Details__c
     * register row. Whole batch or none; every line checked before any DML. Receipts go in rounds
     * (one per installment per DML) because ReceiptTriggerHelper.createAllocationRecord keys
     * allocations one receipt per installment within a trigger batch.
     */
    @AuraEnabled
    public static ChequeBatchResultDTO createChequePayments(ChequeBatchInput input) {
        if (input == null || input.salesOrderId == null) {
            throw new AuraHandledException('No booking was supplied.');
        }
        if (input.lines == null || input.lines.isEmpty()) {
            throw new AuraHandledException('No cheques were entered.');
        }
        /* Phase 4: before any Receipt__c or Cheque_Details__c row exists. */
        assertKycEligibleForSalesOrder(input.salesOrderId);
        String bank = blankToNull(input.bank);
        if (bank == null) {
            throw new AuraHandledException('Choose the Customer Bank the cheques are drawn on.');
        }
        SalesOrder__c so = loadSalesOrder(input.salesOrderId);
        if (so == null) {
            throw new AuraHandledException(
                'This booking could not be found, or you do not have access to it.');
        }
        FinanceReadContext finance = new FinanceReadContext();

        // one instrument per schedule: a covering mandate means no cheques
        DirectDebitRequest__c mandate = finance.mandateFor(so.Id, DD_NOT_COVERING);
        if (mandate != null) {
            throw new AuraHandledException(
                'Milestones on this booking are collected by Direct Debit ('
                + ddLabel(mandate.Status__c) + '). Cheques are not offered while the mandate stands.');
        }

        // validate every line before any DML
        Map<Id, SalesOrderInstallments__c> soiById = new Map<Id, SalesOrderInstallments__c>([
            SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                   Balance_Amount__c, MilestoneDate__c, PaymentStatus__c, SalesOrder__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id
        ]);
        Map<Id, Invoice__c> invBySoi = finance.invoiceByInstallment(soiById.keySet());
        Set<String> takenNumbers = finance.liveChequeNumbersFor(so.Id);
        Set<String> seenNumbers = new Set<String>();
        Map<Id, Decimal> sumBySoi = new Map<Id, Decimal>();
        Set<Id> docIds = new Set<Id>();
        ChequeBatchResultDTO result = new ChequeBatchResultDTO();
        List<String> problems = new List<String>();
        Integer n = 0;
        for (ChequeLineInput l : input.lines) {
            n++;
            ChequeLineResultDTO r = new ChequeLineResultDTO();
            r.clientKey = l == null ? null : l.clientKey;
            r.installmentId = l == null ? null : l.installmentId;
            result.lines.add(r);
            String at = 'Cheque ' + n;
            if (l == null || l.installmentId == null) {
                r.message = at + ': no milestone was chosen.'; problems.add(r.message); continue;
            }
            SalesOrderInstallments__c soi = soiById.get(l.installmentId);
            if (soi == null) {
                r.message = at + ': that milestone does not belong to this booking.'; problems.add(r.message); continue;
            }
            String label = milestoneLabelFor(soi);
            if (soi.MilestoneNumber__c == null || soi.MilestoneNumber__c <= 1) {
                r.message = label + ': only the milestones after the down payment are paid here.'; problems.add(r.message); continue;
            }
            Invoice__c inv = invBySoi.get(soi.Id);
            if (inv == null) {
                r.message = label + ': no invoice has been raised for it yet.'; problems.add(r.message); continue;
            }
            if (nz(inv.InvoiceBalance__c) <= 0) {
                r.message = label + ': the invoice is already paid.'; problems.add(r.message); continue;
            }
            String num = blankToNull(l.chequeNumber);
            if (num == null) {
                r.message = label + ': the cheque number is missing.'; problems.add(r.message); continue;
            }
            String key = num.toUpperCase();
            if (seenNumbers.contains(key)) {
                r.message = label + ': cheque ' + num + ' is entered twice.'; problems.add(r.message); continue;
            }
            if (takenNumbers.contains(key)) {
                r.message = label + ': cheque ' + num + ' is already with Finance on this booking.'; problems.add(r.message); continue;
            }
            seenNumbers.add(key);
            /* MSC-205: the same guards the single-payment path applies */
            String otherBooking = otherBookingWithCheque(so, num);
            if (otherBooking != null) {
                r.message = label + ': cheque ' + num + ' is already recorded on booking '
                    + otherBooking + '.'; problems.add(r.message); continue;
            }
            if (l.chequeDate == null) {
                r.message = label + ': the cheque date is missing.'; problems.add(r.message); continue;
            }
            String dateProblem = chequeDateProblem(l.chequeDate);
            if (dateProblem != null) {
                r.message = label + ': ' + dateProblem; problems.add(r.message); continue;
            }
            if (l.amount == null || l.amount <= 0) {
                r.message = label + ': the amount must be more than zero.'; problems.add(r.message); continue;
            }
            if (l.contentDocumentId == null) {
                r.message = label + ': the cheque image is missing.'; problems.add(r.message); continue;
            }
            docIds.add(l.contentDocumentId);
            Decimal running = (sumBySoi.containsKey(soi.Id) ? sumBySoi.get(soi.Id) : 0) + l.amount;
            sumBySoi.put(soi.Id, running);
            Decimal open = openAmountFor(soi, inv);
            if (running > open + 0.005) {
                r.message = label + ': the cheques add up to more than what is left (AED '
                    + open.setScale(2, System.RoundingMode.HALF_UP).format() + ').';
                problems.add(r.message);
                continue;
            }
        }
        // the images must exist
        Map<Id, ContentVersion> cvByDoc = new Map<Id, ContentVersion>();
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, Title
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ]) {
                cvByDoc.put(cv.ContentDocumentId, cv);
            }
            n = 0;
            for (ChequeLineInput l : input.lines) {
                ChequeLineResultDTO r = result.lines[n++];
                if (r.message == null && l != null && l.contentDocumentId != null
                        && !cvByDoc.containsKey(l.contentDocumentId)) {
                    r.message = milestoneLabelFor(soiById.get(l.installmentId))
                        + ': the cheque image could not be found. Attach it again.';
                    problems.add(r.message);
                }
            }
        }
        if (!problems.isEmpty()) {
            result.recorded = false;
            result.count = 0;
            result.message = 'Nothing was recorded. ' + problems[0]
                + (problems.size() > 1 ? ' (' + (problems.size() - 1) + ' more)' : '');
            return result;
        }

        // write: whole batch or none
        Savepoint sp = Database.setSavepoint();
        List<Cheque_Details__c> registers = new List<Cheque_Details__c>();
        List<Receipt__c> receiptsInOrder = new List<Receipt__c>();
        try {
            LedgerWriteContext writer = new LedgerWriteContext();
            // 1. the register rows, one per cheque
            for (ChequeLineInput l : input.lines) {
                SalesOrderInstallments__c soi = soiById.get(l.installmentId);
                Invoice__c inv = invBySoi.get(soi.Id);
                Cheque_Details__c reg = new Cheque_Details__c();
                reg.Cheque_No__c = l.chequeNumber.trim();
                reg.Cheque_Date__c = l.chequeDate;
                reg.Amount__c = l.amount;
                reg.Bank__c = bank;
                reg.Sales_Order__c = so.Id;
                reg.Sales_Order_Installment__c = soi.Id;
                reg.Invoice__c = inv.Id;
                reg.MileStoneNumber__c = String.valueOf(Integer.valueOf(soi.MilestoneNumber__c));
                reg.Unit__c = so.Unit__c;
                reg.Account__c = so.CustomerAccount__c;
                reg.Status__c = CHEQUE_REGISTER_PROCESSED;
                registers.add(reg);
            }
            writer.insertRegisters(registers);

            // 2. the payments, in rounds: round k holds the k-th cheque of every milestone
            Map<Id, List<Integer>> lineIdxBySoi = new Map<Id, List<Integer>>();
            List<Id> soiOrder = new List<Id>();
            for (Integer i = 0; i < input.lines.size(); i++) {
                Id soiId = input.lines[i].installmentId;
                if (!lineIdxBySoi.containsKey(soiId)) {
                    lineIdxBySoi.put(soiId, new List<Integer>());
                    soiOrder.add(soiId);
                }
                lineIdxBySoi.get(soiId).add(i);
            }
            Integer rounds = 0;
            for (Id soiId : soiOrder) {
                rounds = Math.max(rounds, lineIdxBySoi.get(soiId).size());
            }
            Map<Integer, Receipt__c> receiptByLine = new Map<Integer, Receipt__c>();
            for (Integer round = 0; round < rounds; round++) {
                List<Receipt__c> batch = new List<Receipt__c>();
                List<Integer> batchLines = new List<Integer>();
                for (Id soiId : soiOrder) {
                    List<Integer> idx = lineIdxBySoi.get(soiId);
                    if (idx.size() <= round) {
                        continue;
                    }
                    Integer i = idx[round];
                    ChequeLineInput l = input.lines[i];
                    Receipt__c rec = new Receipt__c();
                    rec.Account__c = so.CustomerAccount__c;
                    rec.SalesOrder__c = so.Id;
                    rec.SalesOrderInstallment__c = soiId;
                    rec.Modeofpayment__c = MOP_CHEQUE;
                    rec.TransactionNumber__c = l.chequeNumber.trim();
                    rec.Cheque_Number__c = l.chequeNumber.trim();
                    rec.ChequeDate__c = l.chequeDate;
                    rec.Bank__c = bank;
                    rec.Receipt_Amount__c = l.amount;
                    rec.TotalAmount__c = l.amount;
                    rec.ReceiptDate__c = Date.today();
                    rec.Status__c = RECEIPT_IN_PROGRESS;
                    rec.ReceiptRemarks__c = CONSOLE_RECEIPT_REMARK;
                    rec.Cheque_Details__c = registers[i].Id;
                    batch.add(rec);
                    batchLines.add(i);
                }
                writer.insertReceipts(batch);
                for (Integer k = 0; k < batch.size(); k++) {
                    receiptByLine.put(batchLines[k], batch[k]);
                }
            }
            for (Integer i = 0; i < input.lines.size(); i++) {
                receiptsInOrder.add(receiptByLine.get(i));
            }

            // 3. the images, on the payment and on the register
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Integer i = 0; i < input.lines.size(); i++) {
                Id docId = input.lines[i].contentDocumentId;
                links.add(new ContentDocumentLink(
                    ContentDocumentId = docId, LinkedEntityId = receiptsInOrder[i].Id,
                    ShareType = 'V', Visibility = 'AllUsers'));
                links.add(new ContentDocumentLink(
                    ContentDocumentId = docId, LinkedEntityId = registers[i].Id,
                    ShareType = 'V', Visibility = 'AllUsers'));
            }
            writer.insertLinks(links);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException('Nothing was recorded. ' + dmlWords(e));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Nothing was recorded. ' + wordsFor(e));
        }

        // read back: did Modon's trigger allocate each one?
        Set<Id> receiptIds = new Set<Id>();
        for (Receipt__c r : receiptsInOrder) {
            receiptIds.add(r.Id);
        }
        Set<Id> allocated = finance.receiptsWithAllocation(receiptIds);
        Map<Id, Receipt__c> named = new Map<Id, Receipt__c>([
            SELECT Id, Name FROM Receipt__c WHERE Id IN :receiptIds
        ]);
        Integer unallocated = 0;
        for (Integer i = 0; i < input.lines.size(); i++) {
            ChequeLineResultDTO r = result.lines[i];
            Receipt__c rec = receiptsInOrder[i];
            r.ok = true;
            r.receiptId = rec.Id;
            r.receiptName = named.containsKey(rec.Id) ? named.get(rec.Id).Name : null;
            r.allocated = allocated.contains(rec.Id);
            if (!r.allocated) unallocated++;
            r.message = r.allocated ? 'recorded · with Finance' : 'recorded · Finance to allocate';
        }
        result.recorded = true;
        result.count = input.lines.size();
        result.message = (result.count == 1 ? '1 cheque recorded' : result.count + ' cheques recorded')
            + (unallocated == 0 ? ' · with Finance' : ' · ' + unallocated + ' for Finance to allocate');

        /* OCR on each register, only where the service is switched on */
        if (ChequeOcrService.isConfigured()) {
            for (Integer i = 0; i < input.lines.size(); i++) {
                ChequeOcrService.requestRead(registers[i].Id, input.lines[i].contentDocumentId);
            }
        }
        return result;
    }

    /** The row's label, so a refusal names the milestone as the ledger does. */
    private static String milestoneLabelFor(SalesOrderInstallments__c soi) {
        if (soi == null) {
            return 'Milestone';
        }
        Integer num = soi.MilestoneNumber__c == null ? null : Integer.valueOf(soi.MilestoneNumber__c);
        return 'Milestone ' + (num == null ? '' : String.valueOf(num))
            + (String.isBlank(soi.MilestoneDescription__c) ? '' : ' - ' + soi.MilestoneDescription__c);
    }

    /** buildBuckets' openAmount, computed the same way from the two records the batch holds. */
    private static Decimal openAmountFor(SalesOrderInstallments__c soi, Invoice__c inv) {
        Decimal amount = nz(soi.InstallmentAmount__c);
        Decimal balance = soi.Balance_Amount__c == null ? amount : soi.Balance_Amount__c;
        Decimal remaining = balance > 0 ? balance : 0;
        if (inv == null) {
            return remaining;
        }
        Decimal cap = nz(inv.InvoiceAmount__c) - nz(inv.AppliedAmount__c);
        Decimal open = Math.min(remaining, cap);
        return open > 0 ? open : 0;
    }

    // 8. Review & Confirm

    /**
     * What "Confirm Booking" calls. Resumes an in-flight booking rather than duplicating;
     * saveSalesOrder refuses a second Sales Order per Opportunity anyway.
     */
    @AuraEnabled
    public static ConfirmResult reviewAndConfirm(ConfirmRequest req) {
        ConfirmResult result = new ConfirmResult();

        /* Phase 4: FIRST, above the multi-unit dispatch, so a basket cannot route around it and
           so the single-unit and confirmMultiUnit paths are both covered by one check. Nothing
           has been written at this point - the Sales Order is created much further down.
           RECHECKED here even though Details already asked: a tab can be stale, KYC can expire
           between the two screens, the POA can be replaced, and a direct call never saw the
           Details screen at all. */
        if (req != null) {
            assertKycEligibleForMoney(req.opportunityId);
        }

        /* identity verification gate. First, above the multi-unit dispatch, so a basket cannot
         * route around it. Server-side because the disabled button is a hint. A message, not an
         * exception, like every other gate here. */
        if (req != null && req.opportunityId != null
                && SalesConsoleVerificationService.blocksAdvance(req.opportunityId)) {
            result.message =
                'This customer was sent an identity verification link and has not completed '
                + 'it yet. Wait for them to finish, or choose "Verify in branch instead" to '
                + 'continue without it.';
            return result;
        }

        // a basket takes the direct-book route; checked before the unitId guard
        if (req != null && req.unitLines != null && req.unitLines.size() > 1) {
            return confirmMultiUnit(req);
        }

        if (req == null || req.opportunityId == null || req.unitId == null) {
            result.message = 'Select a unit before confirming.';
            return result;
        }
        if (req.paymentPlanId == null) {
            result.message = 'Select a payment plan before confirming.';
            return result;
        }
        /* 1.77: the Sales App's unit checks at Generate */
        String unitProblem = unitStatusGuard(new List<Id>{ req.unitId });
        if (unitProblem == null) {
            unitProblem = unitOptionGuard(req.unitId, req.unitOptionId, req.opportunityId);
        }
        if (unitProblem != null) {
            result.message = unitProblem;
            return result;
        }
        /* MSC-153: single-unit path only; a basket never raises a booking fee line */
        String movedOn = moneyGuard(req.opportunityId, req.unitId, req.paymentPlanId);
        if (movedOn != null) {
            result.message = movedOn;
            return result;
        }
        try {
            // resume before create
            SalesOrderCheckoutController.BookingStatus active =
                SalesOrderCheckoutController.getActiveBooking(
                    String.valueOf(req.unitId), String.valueOf(req.opportunityId));
            if (active != null && active.salesOrderId != null) {
                result.isSuccess = true;
                result.resumed = true;
                result.salesOrderId = active.salesOrderId;
                result.bookingRef = active.bookingRef;
                result.message = 'This booking has already been confirmed.';
                result.summary = buildSummary(
                    req.opportunityId, req.unitId, req.paymentPlanId, active.salesOrderId);
                return result;
            }

            // gates (1.71: no checkBookingEligibility - retired in the Sales App; KYC is asserted above)

            Unit__c unit = loadUnit(req.unitId);
            String projectName = unit == null ? null : unit.Project_Name__c;

            // a warning, not a block: profileId__c only exists after Passfort accepts, and
            // compliance now waits for KYC
            String complianceMsg =
                UnitSearchLwcController.checkComplianceSubmitted(req.opportunityId, projectName);
            if (String.isNotBlank(complianceMsg)) {
                result.complianceWarning = complianceMsg;
            }

            // server-authored payload
            SalesOrder__c so = buildSalesOrder(req, unit);

            /* 1.74: with the switch on and a valid EOI on this unit there is no booking fee, so no
               fee lines either (the Sales App raises none on this route) */
            Boolean feeByEoi = eoiCoversFee(req.opportunityId, req.unitId, req.eoiMappingJson);
            /* 1.76: asked once; MODON's journey raises fee lines only where the phase takes a fee */
            Boolean feeRequired = phaseTakesFee(req.unitId, req.opportunityId);

            // fee lines must exist before proof uploads can bind to them
            if (!feeByEoi && (feeRequired || req.payNow == true)) {
                BookingFeeLineController.syncBookingFeeLines(
                    new List<SalesOrder__c>{ so }, String.valueOf(req.opportunityId));
            }

            if (req.payNow == true) {
                // pay-first: startBooking owns the hold window; do not also call initiatePaymentHold
                SalesOrderCheckoutController.BookingResult br =
                    SalesOrderCheckoutController.startBooking(
                        new List<SalesOrder__c>{ so }, String.valueOf(req.opportunityId), null);
                result.isSuccess = br != null && br.isSuccess == true;
                result.message = br == null ? null : br.message;
                result.bookingRef = br == null ? null : br.bookingRef;
            } else {
                /* do not book a unit nobody has paid for; unitBookingJourney gates on isFullyPaid too.
                   allowPartialBooking is a management override from Manage Inventory. */
                if (!feeByEoi && feeRequired) {
                    BookingFeeLineController.FeeStatus fs =
                        BookingFeeLineController.getBookingFeeStatus(
                            String.valueOf(req.opportunityId), String.valueOf(req.unitId));
                    Boolean settled = fs != null
                        && (fs.isFullyPaid == true || fs.allowPartialBooking == true);
                    if (!settled) {
                        result.isSuccess = false;
                        result.message =
                            'The booking fee has not been received yet. Take the payment, '
                            + 'then confirm.';
                        result.summary = buildSummary(
                            req.opportunityId, req.unitId, req.paymentPlanId, (Id) null);
                        return result;
                    }
                }

                /* MSC-231: the EOI deposits, validated against the org engine's own eligible
                 * list before they ride into saveSalesOrder. A refusal is a message, not an
                 * exception, like every other gate here. */
                /* 1.69: the staff app's EOI gates, deposits included, before the mapping */
                EoiGateDTO eoiCheck = eoiGate(req.opportunityId, new List<Id>{ req.unitId },
                    req.eoiMappingJson, true);
                if (!eoiCheck.ok) {
                    result.isSuccess = false;
                    result.message = eoiCheck.message;
                    return result;
                }
                EoiMappingCheck mappingCheck = validatedEoiMapping(
                    req.eoiMappingJson, new Set<Id>{ req.unitId }, req.opportunityId);
                if (mappingCheck.error != null) {
                    result.isSuccess = false;
                    result.message = mappingCheck.error;
                    return result;
                }

                /* the offers; this argument used to be hardcoded null */
                String saveMsg = UnitSearchLwcController.saveSalesOrder(
                    new List<SalesOrder__c>{ so }, String.valueOf(req.opportunityId),
                    offerPayload(req.unitId, req.offerLineIds), mappingCheck.mappingJson);
                // saveSalesOrder returns error strings, not exceptions
                if (isSaveSuccess(saveMsg)) {
                    result.isSuccess = true;
                    result.salesOrderId = findLatestSalesOrder(req.opportunityId, req.unitId);
                } else {
                    /* 1.85: saveSalesOrder's refusal as unitSearchLwc shows it */
                    result.message = modonsWords(saveMsg);
                }
            }

            result.summary = buildSummary(
                req.opportunityId, req.unitId, req.paymentPlanId, result.salesOrderId);

            // keep the multi-unit fields meaningful on the single-unit path too
            result.unitCount = 1;
            // 1.74: nothing was taken at the terminal when the EOI covered the fee
            result.paymentCollected = !feeByEoi;
            if (result.salesOrderId != null) {
                result.salesOrderIds = new List<Id>{ result.salesOrderId };
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = wordsFor(e);
        }
        return result;
    }

    /**
     * Books two or more units and collects nothing (pay-to-hold is single-unit by design). No
     * availability pre-check: saveSalesOrder locks FOR UPDATE.
     */
    private static ConfirmResult confirmMultiUnit(ConfirmRequest req) {
        ConfirmResult result = new ConfirmResult();
        result.paymentCollected = false;

        if (req.opportunityId == null) {
            result.message = 'Select a unit before confirming.';
            return result;
        }

        Map<Id, UnitLine> lineByUnit = new Map<Id, UnitLine>();
        for (UnitLine line : req.unitLines) {
            if (line == null || line.unitId == null) {
                continue;
            }
            if (line.paymentPlanId == null) {
                result.message = 'Select a payment plan for every unit before confirming.';
                return result;
            }
            // same unit ticked twice is a UI slip
            lineByUnit.put(line.unitId, line);
        }
        if (lineByUnit.size() < 2) {
            result.message = 'Select at least two units, or confirm them one at a time.';
            return result;
        }
        result.unitCount = lineByUnit.size();

        /* 1.77: the Sales App's unit checks at Generate, for every unit of the basket */
        String unitProblem = unitStatusGuard(new List<Id>(lineByUnit.keySet()));
        for (Id unitId : lineByUnit.keySet()) {
            if (unitProblem != null) { break; }
            unitProblem = unitOptionGuard(unitId, lineByUnit.get(unitId).unitOptionId, req.opportunityId);
        }
        if (unitProblem != null) {
            result.message = unitProblem;
            return result;
        }

        try {
            /* 1.71: no checkBookingEligibility - retired in the Sales App. KYC was asserted by
               reviewAndConfirm before it dispatched here. */

            Map<Id, Unit__c> units = loadUnits(lineByUnit.keySet());

            // warning only, as on the single-unit path; compliance is per customer
            String projectName;
            for (Unit__c u : units.values()) {
                if (projectName == null) {
                    projectName = u.Project_Name__c;
                }
            }
            String complianceMsg =
                UnitSearchLwcController.checkComplianceSubmitted(req.opportunityId, projectName);
            if (String.isNotBlank(complianceMsg)) {
                result.complianceWarning = complianceMsg;
            }

            Opportunity opp = [
                SELECT Id, AccountId, PrimaryContact__c, CurrencyIsoCode,
                       UAE_Resident_Status__c
                FROM Opportunity
                WHERE Id = :req.opportunityId
                LIMIT 1
            ];

            List<SalesOrder__c> orders = new List<SalesOrder__c>();
            for (Id unitId : lineByUnit.keySet()) {
                orders.add(buildSalesOrderForLine(
                    req.opportunityId, lineByUnit.get(unitId), units.get(unitId), opp));
            }

            /* the offers each unit qualifies for; this was null */
            Map<Id, List<Id>> offersByUnit = new Map<Id, List<Id>>();
            for (Id unitId : lineByUnit.keySet()) {
                UnitLine line = lineByUnit.get(unitId);
                if (line.offerLineIds != null && !line.offerLineIds.isEmpty()) {
                    offersByUnit.put(unitId, line.offerLineIds);
                }
            }

            /* MSC-231: the basket's EOI deposits, validated exactly as on the single path */
            /* 1.69: and the basket through the same EOI gates - this is where two units on
               one EOI used to go through (GV-144 + GV-149, 21 Sep) */
            EoiGateDTO eoiCheck = eoiGate(req.opportunityId, new List<Id>(lineByUnit.keySet()),
                req.eoiMappingJson, true);
            if (!eoiCheck.ok) {
                result.isSuccess = false;
                result.message = eoiCheck.message;
                return result;
            }
            EoiMappingCheck mappingCheck = validatedEoiMapping(
                req.eoiMappingJson, lineByUnit.keySet(), req.opportunityId);
            if (mappingCheck.error != null) {
                result.isSuccess = false;
                result.message = mappingCheck.error;
                return result;
            }

            // no syncBookingFeeLines: it refuses more than one unit, and there is no payment here
            String saveMsg = UnitSearchLwcController.saveSalesOrder(
                orders, String.valueOf(req.opportunityId), offerPayload(offersByUnit), mappingCheck.mappingJson);

            if (isSaveSuccess(saveMsg)) {
                result.isSuccess = true;
                result.salesOrderIds = findSalesOrders(req.opportunityId, lineByUnit.keySet());
                if (!result.salesOrderIds.isEmpty()) {
                    result.salesOrderId = result.salesOrderIds[0];
                }
            } else {
                /* 1.85: saveSalesOrder's refusal as unitSearchLwc shows it */
                result.message = modonsWords(saveMsg);
            }

            /* the summary describes the whole basket now, so the rail reads the same shape after
               a two-unit Confirm as after a one-unit one */
            if (result.isSuccess && !result.salesOrderIds.isEmpty()) {
                result.summary = buildSummary(
                    req.opportunityId, null, null, result.salesOrderIds);
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = wordsFor(e);
        }
        return result;
    }

    /** buildSalesOrder for one basket row, Opportunity queried once. */
    @TestVisible
    private static SalesOrder__c buildSalesOrderForLine(
        Id opportunityId, UnitLine line, Unit__c unit, Opportunity opp
    ) {
        SalesOrder__c so = new SalesOrder__c();
        so.Opportunity__c = opportunityId;
        so.Unit__c = line.unitId;
        so.PaymentPlan__c = line.paymentPlanId;
        so.CustomerAccount__c = opp.AccountId;
        so.PrimaryContact__c = opp.PrimaryContact__c;
        /* 1.77: the Sales App's price and currency */
        SalesAppPrice price = salesAppPrice(unit, line.unitOptionId, line.paymentPlanId, opportunityId);
        so.TotalAmount__c = price.amount;
        so.CurrencyIsoCode = price.currencyCode != null ? price.currencyCode : opp.CurrencyIsoCode;
        so.UAE_Resident_Status__c = opp.UAE_Resident_Status__c;
        if (line.unitOptionId != null) {
            so.UnitOption__c = line.unitOptionId;
        }
        if (String.isNotBlank(line.interior)) {
            so.Interior__c = line.interior;
        }
        if (String.isNotBlank(line.facadeStyle)) {
            so.FacadeStyle__c = line.facadeStyle;
        }
        /* 1.75 - the engine keeps it only on a pre-approval plan whose EOI has no number */
        if (String.isNotBlank(line.preApprovalNumber)) {
            so.Pre_Approval_Number__c = line.preApprovalNumber.trim();
        }

        /* fit-out and facade defaulted from the unit when the client did not send them, as Modon's
           journey does. FitoutPalete__c is the field their downstream reads; Interior__c is left to
           an explicit client value. */
        if (unit != null) {
            if (String.isBlank(line.interior) && String.isNotBlank(unit.Interior__c)) {
                so.FitoutPalete__c = unit.Interior__c;
            }
            if (String.isBlank(line.facadeStyle) && String.isNotBlank(unit.FacadeStyle__c)) {
                so.FacadeStyle__c = unit.FacadeStyle__c;
            }
        }
        return so;
    }

    private static List<Id> findSalesOrders(Id opportunityId, Set<Id> unitIds) {
        List<Id> ids = new List<Id>();
        for (SalesOrder__c so : [
            SELECT Id FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId AND Unit__c IN :unitIds
            ORDER BY CreatedDate DESC
        ]) {
            ids.add(so.Id);
        }
        return ids;
    }

    /**
     * Builds the Sales Order from queried values: the field set the existing JS payload sets, plus
     * UAE_Resident_Status__c, which unitSearchLwc never stamps.
     */
    @TestVisible
    private static SalesOrder__c buildSalesOrder(ConfirmRequest req, Unit__c unit) {
        Opportunity opp = [
            SELECT Id, AccountId, PrimaryContact__c, CurrencyIsoCode,
                   UAE_Resident_Status__c
            FROM Opportunity
            WHERE Id = :req.opportunityId
            LIMIT 1
        ];
        SalesOrder__c so = new SalesOrder__c();
        so.Opportunity__c = req.opportunityId;
        so.Unit__c = req.unitId;
        so.PaymentPlan__c = req.paymentPlanId;
        so.CustomerAccount__c = opp.AccountId;
        so.PrimaryContact__c = opp.PrimaryContact__c;
        /* 1.77: the Sales App's price and currency */
        SalesAppPrice price = salesAppPrice(unit, req.unitOptionId, req.paymentPlanId, req.opportunityId);
        so.TotalAmount__c = price.amount;
        so.CurrencyIsoCode = price.currencyCode != null ? price.currencyCode : opp.CurrencyIsoCode;
        so.UAE_Resident_Status__c = opp.UAE_Resident_Status__c;
        if (req.unitOptionId != null) {
            so.UnitOption__c = req.unitOptionId;
        }
        if (String.isNotBlank(req.interior)) {
            so.Interior__c = req.interior;
        } else if (unit != null && String.isNotBlank(unit.Interior__c)) {
            /* 1.77 - the unit's fit-out, as the basket builder and the Sales App do */
            so.FitoutPalete__c = unit.Interior__c;
        }
        if (String.isNotBlank(req.facadeStyle)) {
            so.FacadeStyle__c = req.facadeStyle;
        } else if (unit != null && String.isNotBlank(unit.FacadeStyle__c)) {
            /* 1.75 - the unit's own style when none was chosen, as the basket builder and the
               Sales App do */
            so.FacadeStyle__c = unit.FacadeStyle__c;
        }
        /* 1.75 - the engine keeps it only on a pre-approval plan whose EOI has no number */
        if (String.isNotBlank(req.preApprovalNumber)) {
            so.Pre_Approval_Number__c = req.preApprovalNumber.trim();
        }
        return so;
    }

    /** saveSalesOrder signals failure by returning a message; blank or 'Success' is the only success. */
    private static Boolean isSaveSuccess(String msg) {
        if (String.isBlank(msg)) {
            return true;
        }
        String m = msg.toLowerCase();
        return m == 'success' || m.startsWith('success');
    }

    private static Id findLatestSalesOrder(Id opportunityId, Id unitId) {
        for (SalesOrder__c so : [
            SELECT Id FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
            ORDER BY CreatedDate DESC LIMIT 1
        ]) {
            return so.Id;
        }
        return null;
    }

    /** Finalises a pay-first booking once the captured total clears the minimum. */
    @AuraEnabled
    public static ConfirmResult finalizeBooking(String bookingRef, Id opportunityId, Id unitId, Id planId) {
        ConfirmResult result = new ConfirmResult();
        /* Phase 4: before SalesOrderCheckoutController.finalizeBooking commits anything. */
        assertKycEligibleForMoney(opportunityId);
        try {
            SalesOrderCheckoutController.FinalizeResult fr =
                SalesOrderCheckoutController.finalizeBooking(bookingRef);
            result.isSuccess = fr != null && fr.isSuccess == true;
            /* 1.85: MODON's sentence as is */
            result.message = fr == null ? null : modonsWords(fr.message);
            result.salesOrderId = fr == null ? null : fr.salesOrderId;
            result.bookingRef = bookingRef;
            result.summary = buildSummary(opportunityId, unitId, planId, result.salesOrderId);
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = wordsFor(e);
        }
        return result;
    }

    /**
     * Live payment status. Not cacheable and expensive: getBookingStatus refreshes each open link
     * from Checkout.com synchronously. Call only when the agent asks or after returning from payment.
     */
    @AuraEnabled(cacheable=false)
    public static SalesOrderCheckoutController.BookingStatus refreshPaymentStatus(String bookingRef) {
        if (String.isBlank(bookingRef)) {
            return null;
        }
        try {
            return SalesOrderCheckoutController.getBookingStatus(bookingRef);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    // Helpers

    private static Unit__c loadUnit(Id unitId) {
        for (Unit__c u : [
            SELECT Id, Name, Status__c, TotalPrice__c, BasePrice__c,
                   UnitClassification__c, Number_of_Bedrooms__c, TotalGFAsqm__c,
                   Project_Name__c, Phase_Name__c, Phase__c,
                   // the unit's own finish, for the Sales Order
                   Interior__c, FacadeStyle__c,
                   // 3D tour URL
                   Masterplan_URL__c
            FROM Unit__c WHERE Id = :unitId LIMIT 1
        ]) {
            return u;
        }
        return null;
    }

    /* Basket form of loadUnit, one query. */
    private static Map<Id, Unit__c> loadUnits(Set<Id> unitIds) {
        return new Map<Id, Unit__c>([
            SELECT Id, Name, Status__c, TotalPrice__c, BasePrice__c,
                   UnitClassification__c, Number_of_Bedrooms__c, TotalGFAsqm__c,
                   Project_Name__c, Phase_Name__c, Phase__c,
                   // the unit's own finish, for the Sales Order
                   Interior__c, FacadeStyle__c,
                   // 3D tour URL
                   Masterplan_URL__c
            FROM Unit__c WHERE Id IN :unitIds
        ]);
    }

    private static SalesOrder__c loadSalesOrder(Id salesOrderId) {
        for (SalesOrder__c so : [
            SELECT Id, Name, Status__c, Sub_Status__c, Unit__c, PaymentPlan__c,
                   TotalAmount__c, CustomerAccount__c, Opportunity__c,
                   UAE_Resident_Status__c, Down_Payment_Status__c,
                   ADM_Fees_and_Dari__c, Further_Documents_Required__c,
                   CustomerAccount__r.IsPersonAccount, PrimaryContact__c
            FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
        ]) {
            return so;
        }
        return null;
    }

    private static UnitBlock toUnitBlock(Unit__c u) {
        if (u == null) {
            return null;
        }
        UnitBlock b = new UnitBlock();
        b.unitId = u.Id;
        b.name = u.Name;
        b.project = u.Project_Name__c;
        b.phase = u.Phase_Name__c;
        b.classification = u.UnitClassification__c;
        b.bedrooms = u.Number_of_Bedrooms__c;
        b.area = u.TotalGFAsqm__c;
        b.totalPrice = u.TotalPrice__c;
        b.status = u.Status__c;
        b.tourUrl = u.Masterplan_URL__c;
        return b;
    }

    /**
     * The card's read side (MSC-112). Identity is branch-correct (Account for a person, signatory
     * Contact for an organisation); fallbacks are per field; every masked value ends at ensureMasked;
     * lockReasons is computed here and a locked field's clear value is nulled before it leaves.
     */
    private static CustomerBlock loadCustomerBlock(Id opportunityId) {
        for (Opportunity opp : [
            SELECT Id, PrimaryContact__c, Account.Name,
                   Account.PersonEmail, Account.PersonMobilePhone,
                   Account.Nationality__pc, Account.UAE_Resident_Status__pc,
                   Account.EIDNumber__pc, Account.PassportNumber__pc,
                   Account.En_EIDNumber__pc, Account.En_PassportNumber__pc,
                   Account.Masked_EmiratesId__c, Account.Masked_Passport_Number__c,
                   Account.EmiratesIDExpiryDate__pc, Account.PassportIssueDate__pc,
                   Account.PassportExpiryDate__pc, Account.CountryOfResidence__pc,
                   Account.CreatedById, Account.CreatedDate,
                   /* encrypted first, masked fallback (En_* is empty in a sandbox), clear field last
                      behind ensureMasked */
                   Account.En_PersonEmail__c, Account.Masked_Email__c,
                   Account.En_PersonMobilePhone__c, Account.Masked_Phone__c,
                   // the company, so the form seeds
                   Account.IsPersonAccount, Account.UnifiedNumber__c,
                   Account.TradeLicenseExpiryDate__c, Account.DateOfEstablishment__c,
                   Account.LegalStructure__c, Account.Description,
                   Account.UAEVATRegisterNumber__c,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                   // split name for the card's two fields
                   Account.FirstName, Account.LastName,
                   PrimaryContact__r.Name, PrimaryContact__r.FirstName,
                   PrimaryContact__r.LastName, PrimaryContact__r.Email,
                   PrimaryContact__r.MobilePhone,
                   /* the signatory's identity and masked twins (Contact spells it Masked_Emirates_Id__c
                      and has no masked passport field; maskTail covers it) */
                   PrimaryContact__r.EIDNumber__c, PrimaryContact__r.PassportNumber__c,
                   PrimaryContact__r.En_EIDNumber__c, PrimaryContact__r.En_PassportNumber__c,
                   PrimaryContact__r.EmiratesIDExpiryDate__c,
                   PrimaryContact__r.PassportIssueDate__c,
                   PrimaryContact__r.PassportExpiryDate__c,
                   PrimaryContact__r.CountryOfResidence__c,
                   PrimaryContact__r.Nationality__c, PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.En_Email__c, PrimaryContact__r.Masked_Email__c,
                   PrimaryContact__r.En_MobilePhone__c, PrimaryContact__r.Masked_Phone__c,
                   PrimaryContact__r.Masked_Emirates_Id__c,
                   PrimaryContact__r.AreYouRealBeneficiaryOfThis__c,
                   Nationality__c, UAE_Resident_Status__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            CustomerBlock c = new CustomerBlock();
            Account acc = opp.Account;
            Contact con = opp.PrimaryContact__c == null ? null : opp.PrimaryContact__r;
            Boolean person = acc != null && acc.IsPersonAccount == true;

            // per field, contact first, record second
            c.name = firstNonBlank(new List<String>{
                con == null ? null : con.Name,
                acc == null ? null : acc.Name });
            /* split name for Person Accounts only; a business Account's Name is the company */
            c.firstName = firstNonBlank(new List<String>{
                con == null ? null : con.FirstName,
                person ? acc.FirstName : null });
            c.lastName = firstNonBlank(new List<String>{
                con == null ? null : con.LastName,
                person ? acc.LastName : null });
            c.email = firstNonBlank(new List<String>{
                con == null ? null : con.Email,
                person ? acc.PersonEmail : null });
            c.mobile = firstNonBlank(new List<String>{
                con == null ? null : con.MobilePhone,
                person ? acc.PersonMobilePhone : null });

            /* Opportunity first, the record second */
            c.nationality = firstNonBlank(new List<String>{
                opp.Nationality__c,
                person ? acc.Nationality__pc : (con == null ? null : con.Nationality__c) });
            c.residentStatus = firstNonBlank(new List<String>{
                opp.UAE_Resident_Status__c,
                person ? acc.UAE_Resident_Status__pc
                       : (con == null ? null : con.UAE_Resident_Status__c) });

            if (person) {
                c.emiratesId = acc.EIDNumber__pc;
                c.passportNumber = acc.PassportNumber__pc;
                c.emiratesIdExpiry = acc.EmiratesIDExpiryDate__pc;
                c.passportIssueDate = acc.PassportIssueDate__pc;
                c.passportExpiry = acc.PassportExpiryDate__pc;
                c.countryOfResidence = acc.CountryOfResidence__pc;
                c.maskedEmail = ensureMasked(firstNonBlank(new List<String>{
                    acc.En_PersonEmail__c, acc.Masked_Email__c, c.email }), 'email');
                c.maskedMobile = ensureMasked(firstNonBlank(new List<String>{
                    acc.En_PersonMobilePhone__c, acc.Masked_Phone__c, c.mobile }), 'phone');
                c.maskedEmiratesId = ensureMasked(firstNonBlank(new List<String>{
                    acc.Masked_EmiratesId__c, c.emiratesId }), 'tail');
                c.maskedPassport = ensureMasked(firstNonBlank(new List<String>{
                    acc.Masked_Passport_Number__c, c.passportNumber }), 'tail');
            } else if (acc != null) {
                // the signatory's documents, not the Account's absent __pc
                if (con != null) {
                    c.emiratesId = con.EIDNumber__c;
                    c.passportNumber = con.PassportNumber__c;
                    c.emiratesIdExpiry = con.EmiratesIDExpiryDate__c;
                    c.passportIssueDate = con.PassportIssueDate__c;
                    c.passportExpiry = con.PassportExpiryDate__c;
                    c.countryOfResidence = con.CountryOfResidence__c;
                }
                c.maskedEmail = ensureMasked(firstNonBlank(new List<String>{
                    con == null ? null : con.En_Email__c,
                    con == null ? null : con.Masked_Email__c, c.email }), 'email');
                c.maskedMobile = ensureMasked(firstNonBlank(new List<String>{
                    con == null ? null : con.En_MobilePhone__c,
                    con == null ? null : con.Masked_Phone__c, c.mobile }), 'phone');
                c.maskedEmiratesId = ensureMasked(firstNonBlank(new List<String>{
                    con == null ? null : con.Masked_Emirates_Id__c, c.emiratesId }), 'tail');
                c.maskedPassport = ensureMasked(maskTail(c.passportNumber), 'tail');
            }

            if (acc != null) {
                Boolean isCompany = !person;
                c.customerType = isCompany ? ORGANISATION : INDIVIDUAL;
                if (isCompany) {
                    c.companyName         = acc.Name;
                    c.tradeLicenceNumber  = acc.UnifiedNumber__c;
                    c.tradeLicenceExpiry  = acc.TradeLicenseExpiryDate__c;
                    c.dateOfEstablishment = acc.DateOfEstablishment__c;
                    c.legalStructure      = acc.LegalStructure__c;
                    c.businessActivity    = acc.Description;
                    c.vatNumber           = acc.UAEVATRegisterNumber__c;
                    c.billingStreet       = acc.BillingStreet;
                    c.billingCity         = acc.BillingCity;
                    c.billingState        = acc.BillingState;
                    c.billingPostalCode   = acc.BillingPostalCode;
                    c.billingCountry      = acc.BillingCountry;
                }
            }

            /* the lock map. Fresh = this rep created the customer within the last day, so the create
               form's fields stay editable. A blank field on an existing customer stays editable. */
            Boolean fresh = acc != null
                && acc.CreatedById == UserInfo.getUserId()
                && acc.CreatedDate >= System.now().addHours(-24);
            Map<String, String> locks = c.lockReasons;
            // buyer type is structural
            locks.put('customerType', 'ON_FILE');
            /* Sales_user_cant_change_Passport_and_EID refuses changing a populated Opportunity
               residency; Opp blank + record populated stays editable */
            if (String.isNotBlank(opp.UAE_Resident_Status__c)) {
                locks.put('residentStatus', 'RESIDENCY_SAVED');
            }
            if (person && !fresh) {
                lockIf(locks, 'firstName', acc.FirstName, 'ON_FILE');
                lockIf(locks, 'lastName', acc.LastName, 'ON_FILE');
                lockIf(locks, 'email', firstNonBlank(new List<String>{
                    acc.PersonEmail, acc.En_PersonEmail__c, acc.Masked_Email__c }), 'ON_FILE');
                lockIf(locks, 'mobile', firstNonBlank(new List<String>{
                    acc.PersonMobilePhone, acc.En_PersonMobilePhone__c,
                    acc.Masked_Phone__c }), 'ON_FILE');
                /* nationality lock follows what eligibility reads: Opportunity and Account; either
                   blank = editable */
                if (String.isNotBlank(opp.Nationality__c)
                        && String.isNotBlank(acc.Nationality__pc)) {
                    locks.put('nationality', 'ON_FILE');
                }
                lockIf(locks, 'countryOfResidence', c.countryOfResidence, 'ON_FILE');
                /* any tier counts: encrypted or masked twin still means the document is held */
                lockIf(locks, 'emiratesId', firstNonBlank(new List<String>{
                    acc.EIDNumber__pc, acc.En_EIDNumber__pc,
                    acc.Masked_EmiratesId__c }), 'IDENTITY_SAVED');
                lockIf(locks, 'passportNumber', firstNonBlank(new List<String>{
                    acc.PassportNumber__pc, acc.En_PassportNumber__pc,
                    acc.Masked_Passport_Number__c }), 'IDENTITY_SAVED');
                if (acc.EmiratesIDExpiryDate__pc != null) {
                    locks.put('emiratesIdExpiry', 'IDENTITY_SAVED');
                }
                if (acc.PassportIssueDate__pc != null) {
                    locks.put('passportIssueDate', 'IDENTITY_SAVED');
                }
                if (acc.PassportExpiryDate__pc != null) {
                    locks.put('passportExpiry', 'IDENTITY_SAVED');
                }
            } else if (!person && acc != null) {
                if (con == null) {
                    /* no signatory yet: say whose these values are instead of losing them */
                    for (String k : new List<String>{
                            'firstName', 'lastName', 'email', 'mobile',
                            'emiratesId', 'emiratesIdExpiry', 'passportNumber',
                            'passportIssueDate', 'passportExpiry',
                            'countryOfResidence', 'realBeneficiary' }) {
                        locks.put(k, 'NO_SIGNATORY');
                    }
                } else {
                    /* the declaration, stored truth only */
                    if (con.AreYouRealBeneficiaryOfThis__c == true) {
                        c.realBeneficiary = true;
                    }
                    /* Sales_user_cant_update_contact_details refuses a name change; said here, not at Save */
                    locks.put('firstName', 'NAME_RULE');
                    locks.put('lastName', 'NAME_RULE');
                    if (!fresh) {
                        lockIf(locks, 'email', firstNonBlank(new List<String>{
                            con.Email, con.En_Email__c, con.Masked_Email__c }), 'ON_FILE');
                        lockIf(locks, 'mobile', firstNonBlank(new List<String>{
                            con.MobilePhone, con.En_MobilePhone__c,
                            con.Masked_Phone__c }), 'ON_FILE');
                        /* an organisation's eligibility reads the Opportunity only, so a contact-only
                           nationality stays editable */
                        if (String.isNotBlank(opp.Nationality__c)) {
                            locks.put('nationality', 'ON_FILE');
                        }
                        lockIf(locks, 'countryOfResidence', c.countryOfResidence, 'ON_FILE');
                        lockIf(locks, 'emiratesId', firstNonBlank(new List<String>{
                            con.EIDNumber__c, con.En_EIDNumber__c,
                            con.Masked_Emirates_Id__c }), 'IDENTITY_SAVED');
                        lockIf(locks, 'passportNumber', firstNonBlank(new List<String>{
                            con.PassportNumber__c, con.En_PassportNumber__c }), 'IDENTITY_SAVED');
                        if (con.EmiratesIDExpiryDate__c != null) {
                            locks.put('emiratesIdExpiry', 'IDENTITY_SAVED');
                        }
                        if (con.PassportIssueDate__c != null) {
                            locks.put('passportIssueDate', 'IDENTITY_SAVED');
                        }
                        if (con.PassportExpiryDate__c != null) {
                            locks.put('passportExpiry', 'IDENTITY_SAVED');
                        }
                    }
                }
                if (!fresh) {
                    lockIf(locks, 'companyName', c.companyName, 'ON_FILE');
                    lockIf(locks, 'tradeLicenceNumber', c.tradeLicenceNumber, 'ON_FILE');
                    if (c.tradeLicenceExpiry != null) {
                        locks.put('tradeLicenceExpiry', 'ON_FILE');
                    }
                    if (c.dateOfEstablishment != null) {
                        locks.put('dateOfEstablishment', 'ON_FILE');
                    }
                    lockIf(locks, 'legalStructure', c.legalStructure, 'ON_FILE');
                    lockIf(locks, 'businessActivity', c.businessActivity, 'ON_FILE');
                    lockIf(locks, 'vatNumber', c.vatNumber, 'ON_FILE');
                }
            }

            /* a locked field's clear value never leaves the server */
            if (locks.containsKey('email')) {
                c.email = null;
            }
            if (locks.containsKey('mobile')) {
                c.mobile = null;
            }
            if (locks.containsKey('emiratesId')) {
                c.emiratesId = null;
            }
            if (locks.containsKey('passportNumber')) {
                c.passportNumber = null;
            }
            return c;
        }
        return null;
    }

    /** Sales Order wins when present. */
    private static String residencyFor(Id opportunityId, Id salesOrderId) {
        if (salesOrderId != null) {
            for (SalesOrder__c so : [
                SELECT UAE_Resident_Status__c FROM SalesOrder__c
                WHERE Id = :salesOrderId LIMIT 1
            ]) {
                if (String.isNotBlank(so.UAE_Resident_Status__c)) {
                    return so.UAE_Resident_Status__c;
                }
            }
        }
        if (opportunityId != null) {
            for (Opportunity opp : [
                SELECT UAE_Resident_Status__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1
            ]) {
                return opp.UAE_Resident_Status__c;
            }
        }
        return null;
    }

    /** Turns platform and legacy-controller strings into something an agent can act on. */
    /** The last raw platform error friendly() was handed, so a test can say which one was refused. */
    @TestVisible
    private static String lastRawError;

    private static String friendly(String raw) {
        lastRawError = raw;
        if (String.isBlank(raw)) {
            return 'Something went wrong. Please try again.';
        }
        /* 1.85: only a raw platform error or an unexpected fault comes here now */
        String m = raw.toLowerCase();
        if (m.contains('virtual account')) {
            return 'This unit is not ready to be booked yet - its account setup is incomplete. Please contact Sales Operations.';
        }
        if (m.contains('escrow')) {
            return 'This phase is not ready to be booked yet - its escrow account is not configured. Please contact Sales Operations.';
        }
        if (m.contains('being booked by another')) {
            return 'Another agent is booking this unit right now. Please choose a different unit.';
        }
        if (m.contains('eoi is mandatory') || m.contains('eoi')) {
            return 'This unit requires a completed Expression of Interest before it can be booked.';
        }
        if (m.contains('minimum booking amount')) {
            return 'The minimum booking amount has not been received yet.';
        }
        if (m.contains('insufficient access') || m.contains('field integrity')) {
            return 'You do not have access to complete this step. Please contact your administrator.';
        }
        if (m.contains('unable to lock row')) {
            return 'This record is being updated by another process. Please try again in a moment.';
        }
        /* 1.70: in the console's words; since 1.85 only a raw error or fault reaches this line */
        return consoleWording(raw);
    }

    // Identity verification and compliance. The console sends the existing Signzy link, reads the
    // state back and prepares the Documents__c rows. It never submits to Passfort itself.

    /**
     * Sends or re-sends the Signzy KYC link (sendKYCForm). Returns null on success; sendKYCForm's
     * error string is passed through untouched.
     */
    @AuraEnabled
    public static String sendKycLink(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        try {
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.IsPersonAccount
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            if (opps.isEmpty() || opps[0].AccountId == null) {
                throw new AuraHandledException(
                    'This opportunity has no customer account, so a verification link cannot be sent.');
            }
            String result = CustomerKYCHandler.sendKYCForm(opps[0].AccountId);
            /* matched against the label, not the word 'Success': the success label is
               "Success! Mail send successfully...". Prefix-matched, since the wording is Modon's. */
            if (String.isBlank(result)) {
                return null;
            }
            String sent = null;
            try {
                sent = System.Label.SignzyMailSentSuccessMsg;
            } catch (Exception ignored) {
                sent = null;
            }
            Boolean succeeded = result.equalsIgnoreCase('Success')
                || (String.isNotBlank(sent) && result.equalsIgnoreCase(sent))
                || result.startsWithIgnoreCase('Success');
            return succeeded ? null : result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Identity-verification and compliance chain for one opportunity. Never null, never throws. */
    @AuraEnabled
    public static ComplianceStateDTO getComplianceState(Id opportunityId) {
        ComplianceStateDTO dto = new ComplianceStateDTO();
        dto.kycStatus = 'KYC not complete';
        if (opportunityId == null) {
            dto.blockedReason = 'No opportunity selected.';
            return dto;
        }
        try {
            List<Opportunity> opps = [
                SELECT Id, AccountId, PrimaryContact__c,
                       Verification_In_Branch__c,
                       Account.IsPersonAccount,
                       Account.PersonContactId,
                       Account.KYC_Status__c,
                       Account.KYC_Completed_Date__c,
                       Account.Manual_KYC_Approval__c,
                       Account.Nationality__pc,
                       Account.PersonEmail,
                       Account.PersonMobilePhone,
                       Account.UAE_Resident_Status__pc,
                       Account.Send_KYC_Verification_Email__c,
                       Account.profileId__c,
                       Account.profileId__pc,
                       Account.PassfortApprovalStatus__pc,
                       Account.PassfortRiskStatus__pc,
                       Account.PassfortComment__pc,
                       // what the step-2 gate reads
                       Account.KYCSiteLink__pc,
                       Account.KYC_Send_Date_Time__c,
                       Account.KYC_Link_Status__c,
                       Account.Is_KYC_Link_Active__c,
                       Account.KYC_Link_Expiry_At__c,
                       /* the company's own Passfort twins and the signatory's; null on a person booking */
                       Account.Name,
                       Account.PassfortApprovalStatus__c,
                       Account.PassfortRiskStatus__c,
                       Account.PassfortComment__c,
                       PrimaryContact__r.Name,
                       PrimaryContact__r.Email,
                       PrimaryContact__r.MobilePhone,
                       PrimaryContact__r.KYC_Completed_Date__c,
                       /* 1.86 - a company is verified on its primary contact */
                       PrimaryContact__r.Manual_KYC_Approval__c,
                       PrimaryContact__r.PassfortApprovalStatus__c,
                       PrimaryContact__r.PassfortRiskStatus__c,
                       PrimaryContact__r.PassfortComment__c,
                       PrimaryContact__r.profileId__c,
                       // the signatory's own link
                       PrimaryContact__r.KYC_Send_Date_Time__c,
                       PrimaryContact__r.Is_KYC_Link_Active__c,
                       PrimaryContact__r.KYC_Link_Expiry_At__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            if (opps.isEmpty() || opps[0].Account == null) {
                dto.blockedReason = 'This opportunity has no customer account yet.';
                return dto;
            }
            Opportunity opp = opps[0];
            dto.isPersonAccount = opp.Account.IsPersonAccount == true;

            dto.kycStatus        = opp.Account.KYC_Status__c;
            dto.kycCompletedDate = opp.Account.KYC_Completed_Date__c;
            /* 18 Sep 2026: a manual approval is identity done for the Verification step too */
            dto.manuallyApproved = SalesConsoleVerificationService.isManuallyApproved(opp.Account);
            dto.kycComplete      = opp.Account.KYC_Completed_Date__c != null || dto.manuallyApproved;
            /* KYC_Send_Date_Time__c, not Send_KYC_Verification_Email__c (a trigger Modon's Flow
               clears the moment it sends) */
            dto.kycLinkSent      = opp.Account.KYC_Send_Date_Time__c != null;

            dto.submitted = String.isNotBlank(opp.Account.profileId__c)
                || String.isNotBlank(opp.Account.profileId__pc);
            /* a submission exists before Passfort answers: an open PassfortTransaction__c counts,
               so the button is not offered for a customer already on their way */
            if (dto.submitted != true && opp.Account.PersonContactId != null) {
                dto.submitted = [
                    SELECT COUNT()
                    FROM PassfortTransaction__c
                    WHERE Contact__c = :opp.Account.PersonContactId
                    AND EntityType__c = 'Individual'
                ] > 0;
            }
            dto.approvalStatus  = opp.Account.PassfortApprovalStatus__pc;
            dto.riskStatus      = opp.Account.PassfortRiskStatus__pc;
            dto.passfortComment = opp.Account.PassfortComment__pc;

            // mirror sendKYCForm's preconditions so the button is not offered when it would fail
            /* the same four fields live in SalesConsoleVerificationService.missingForSend (joint
               owner rows); kept in step by SalesConsoleVerificationServiceTest. Change both. */
            List<String> missing = new List<String>();
            if (String.isBlank(opp.Account.Nationality__pc))           missing.add('nationality');
            if (String.isBlank(opp.Account.UAE_Resident_Status__pc))   missing.add('residency');
            if (String.isBlank(opp.Account.PersonEmail))               missing.add('email address');
            if (String.isBlank(opp.Account.PersonMobilePhone))         missing.add('mobile number');

            if (!dto.isPersonAccount) {
                /* MSC-148. A company has a link too (sendKYCForm's Organization Account branch).
                   The gate is SalesConsoleOrgController.missingForLink, which mirrors its refusals. */
                List<String> orgMissing;
                try {
                    orgMissing = SalesConsoleOrgController.missingForLink(opp.AccountId);
                } catch (Exception orgLinkEx) {
                    orgMissing = new List<String>{ 'a Power of Attorney' };
                }
                if (orgMissing == null || orgMissing.isEmpty()) {
                    dto.canSendLink = true;
                } else {
                    dto.canSendLink = false;
                    dto.blockedReason = 'Add ' + String.join(orgMissing, ', ')
                        + ' before sending the verification link.';
                }
            } else if (!missing.isEmpty()) {
                dto.canSendLink = false;
                dto.blockedReason = 'Add the customer\'s '
                    + String.join(missing, ', ') + ' before sending the verification link.';
            } else {
                dto.canSendLink = true;
            }

            applyLastComplianceAttempt(dto, opp.Id);
            applyJourneyStatus(dto, opp.AccountId);
            applyLinkState(dto, opp);
            /* last, and fenced: this method fails open, and a company-side failure must not blank
               the panel */
            if (dto.isPersonAccount != true) {
                try {
                    applyOrganisationTracks(dto, opp);
                } catch (Exception orgEx) {
                    // the sentence still renders; tracks stay null
                }
            }
            dto.refreshedOn = System.now();
        } catch (Exception e) {
            // read-only panel: degrade rather than break the page
            dto.blockedReason = wordsFor(e);
        }
        return dto;
    }

    /**
     * The two tracks a corporate booking has (MSC-115). Read directly off the Account and the
     * signatory Contact, not through PassfortRelatedEntitiesController.getEntityRecords (NPEs on
     * a joint owner with no person contact). "Submitted" is a profile id, a verdict, or an open
     * transaction of this entity type.
     */
    private static void applyOrganisationTracks(ComplianceStateDTO dto, Opportunity opp) {
        Account acc = opp.Account;
        if (acc == null) {
            return;
        }
        OrgTrackDTO co = new OrgTrackDTO();
        co.name           = acc.Name;
        co.approvalStatus = acc.PassfortApprovalStatus__c;
        co.riskStatus     = acc.PassfortRiskStatus__c;
        co.comment        = acc.PassfortComment__c;
        co.submitted      = String.isNotBlank(acc.profileId__c)
            || String.isNotBlank(acc.PassfortApprovalStatus__c);
        if (co.submitted != true) {
            co.submitted = [
                SELECT COUNT()
                FROM PassfortTransaction__c
                WHERE Account__c = :opp.AccountId
                AND EntityType__c = 'Company'
            ] > 0;
        }
        dto.company = co;

        if (opp.PrimaryContact__c != null && opp.PrimaryContact__r != null) {
            Contact con = opp.PrimaryContact__r;
            OrgTrackDTO sig = new OrgTrackDTO();
            sig.name             = con.Name;
            sig.linkSentAt       = con.KYC_Send_Date_Time__c;
            sig.linkActive       = con.Is_KYC_Link_Active__c == true;
            sig.linkExpiresAt    = con.KYC_Link_Expiry_At__c;
            sig.approvalStatus   = con.PassfortApprovalStatus__c;
            sig.riskStatus       = con.PassfortRiskStatus__c;
            sig.comment          = con.PassfortComment__c;
            sig.kycCompletedDate = con.KYC_Completed_Date__c;
            sig.submitted        = String.isNotBlank(con.profileId__c)
                || String.isNotBlank(con.PassfortApprovalStatus__c);
            if (sig.submitted != true) {
                sig.submitted = [
                    SELECT COUNT()
                    FROM PassfortTransaction__c
                    WHERE Contact__c = :opp.PrimaryContact__c
                    AND EntityType__c = 'Primary Contact'
                ] > 0;
            }
            /* compliance check door: signatory verified and not already with Passfort */
            sig.canCheck = sig.kycCompletedDate != null && sig.submitted != true;
            dto.signatory = sig;
        }

        /* the step's headline verdict is the company's; it cannot block Confirm, which reads
           blocksAdvance alone */
        dto.approvalStatus  = acc.PassfortApprovalStatus__c;
        dto.riskStatus      = acc.PassfortRiskStatus__c;
        dto.passfortComment = acc.PassfortComment__c;
        if (dto.submitted != true) {
            dto.submitted = co.submitted == true;
        }

        /* last, fed the two facts just established so nextStep does not ask Passfort again */
        dto.nextStep = SalesConsoleOrgController.nextStep(
            opp.Id,
            co.submitted == true,
            dto.signatory != null && dto.signatory.submitted == true
        );
    }

    /* The step-2 verification gate */

    /** Copies the verification link's state onto the DTO; decisions live in SalesConsoleVerificationService. */
    private static void applyLinkState(ComplianceStateDTO dto, Opportunity opp) {
        if (dto == null || opp == null) {
            return;
        }
        dto.verificationStatus = SalesConsoleVerificationService.statusFor(opp);
        dto.blocksAdvance      = SalesConsoleVerificationService.blocksAdvance(opp);
        dto.releasedToBranch   = opp.Verification_In_Branch__c == true;
        if (opp.Account != null) {
            dto.linkSentAt    = opp.Account.KYC_Send_Date_Time__c;
            dto.linkExpiresAt = opp.Account.KYC_Link_Expiry_At__c;
            dto.linkActive    = opp.Account.Is_KYC_Link_Active__c == true;
            dto.linkUrl       = opp.Account.KYCSiteLink__pc;
        }
    }

    /**
     * Step 2's "send the customer their verification link". Unit context is stamped on the account
     * here, synchronously; the Signzy call is enqueued after commit (sendKYCForm makes a callout
     * then commits, and Modon's email Flow fires on its update, so stamping after it would send a
     * form naming no unit). Prerequisites are checked first because sendKYCForm returns a label
     * that a queueable cannot surface.
     */
    @AuraEnabled
    public static ComplianceStateDTO sendCustomerVerification(Id opportunityId, Id primaryUnitId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        ComplianceStateDTO state = getComplianceState(opportunityId);
        if (state.canSendLink != true) {
            /* Modon's own wording where it came from them */
            throw new AuraHandledException(
                String.isNotBlank(state.blockedReason)
                    ? state.blockedReason
                    : 'This customer cannot be sent a verification link yet.');
        }
        try {
            SalesConsoleVerificationService.stampUnitContext(opportunityId, primaryUnitId);
            List<Opportunity> opps = [
                SELECT Id, AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1
            ];
            if (!opps.isEmpty() && opps[0].AccountId != null) {
                SalesConsoleVerificationService.enqueueSend(opps[0].AccountId);
            }
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        /* SENDING, not SENT: the link exists only after the queueable has run and the Flow has
           stamped KYC_Send_Date_Time__c; the console polls */
        state.verificationStatus = 'SENDING';
        /* the gate is stood down: the journey is not held for the link */
        state.blocksAdvance = false;
        return state;
    }

    /**
     * The way out of the gate for an abandoned or expired link. The flag is history-tracked.
     */
    @AuraEnabled
    public static ComplianceStateDTO releaseVerificationToBranch(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        try {
            SalesConsoleVerificationService.releaseToBranch(opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
        return getComplianceState(opportunityId);
    }

    /** How far the customer got; Journey_Status__c is the only visibility into a half-finished verification. */
    private static void applyJourneyStatus(ComplianceStateDTO dto, Id accountId) {
        if (accountId == null) {
            return;
        }
        List<KYC_Response__c> kycs = [
            SELECT Id, Journey_Status__c, Signzy_Journey_Status__c
            FROM KYC_Response__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (kycs.isEmpty()) {
            return;
        }
        dto.journeyStatus = String.isNotBlank(kycs[0].Journey_Status__c)
            ? kycs[0].Journey_Status__c
            : kycs[0].Signzy_Journey_Status__c;

        // only worth polling while the answer could still change
        dto.canRefresh = true;
    }

    /**
     * Pull the latest state on demand. Mostly a re-read; the Signzy poll covers the customer who
     * finished but never returned to the portal. Runs only while KYC_Completed_Date__c is blank,
     * and before any DML (callout).
     */
    @AuraEnabled
    public static ComplianceStateDTO refreshComplianceState(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        String pollMessage;
        try {
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.KYC_Completed_Date__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            if (!opps.isEmpty() && opps[0].AccountId != null
                    && opps[0].Account.KYC_Completed_Date__c == null) {
                pollMessage = pollSignzy(opps[0].AccountId);
            }
        } catch (Exception e) {
            // an unreachable vendor must not hide the state we already hold
            pollMessage = 'Could not reach identity verification just now. '
                + 'Showing the last known status.';
        }

        ComplianceStateDTO dto = getComplianceState(opportunityId);
        dto.refreshMessage = pollMessage;
        return dto;
    }

    /** Asks Signzy where the customer got to (the portal's own call). Null means nothing to show. */
    private static String pollSignzy(Id accountId) {
        List<KYC_Response__c> kycs = [
            SELECT Id FROM KYC_Response__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (kycs.isEmpty()) {
            return 'No identity verification has been started for this customer yet.';
        }
        String result = CustomerKYCHandler.getSignzyJourney(kycs[0].Id);
        if (String.isBlank(result)) {
            return null;
        }
        // returns its own error text prefixed with 'Error!'
        return result.startsWith('Error!')
            ? 'Could not reach identity verification just now. Showing the last known status.'
            : null;
    }

    /**
     * What the automatic compliance submission last did (Logger__c). Full reason is in
     * Integration_Request_Body__c; the Response field is a 255-char summary.
     */
    private static void applyLastComplianceAttempt(ComplianceStateDTO dto, Id opportunityId) {
        List<SalesOrder__c> sos = [
            SELECT Id FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (sos.isEmpty()) {
            return;
        }
        List<Logger__c> logs = [
            SELECT Id, LogType__c, Integration_Request_Body__c,
                   Integration_Status_Code__c, CreatedDate
            FROM Logger__c
            WHERE Sales_Order__c = :sos[0].Id
            AND ExecutingProcessName__c IN ('Auto Passfort Compliance Submission',
                                            'Manual Compliance Submission')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (logs.isEmpty()) {
            return;
        }
        dto.lastAttemptStatus = logs[0].LogType__c;
        dto.lastAttemptDetail = logs[0].Integration_Request_Body__c;
        dto.lastAttemptOn     = logs[0].CreatedDate;
    }

    /**
     * Creates the Documents__c placeholders the compliance validator matches by Name against the
     * Custom Labels. Re-runnable, never deletes.
     */
    @AuraEnabled
    public static Integer ensureComplianceDocSlots(Id opportunityId) {
        return ensureComplianceDocSlots(opportunityId, null);
    }

    /**
     * MSC-083. The same slots for a party who is not the buyer (Documents__c is keyed on
     * PrimaryContact__c). Not @AuraEnabled (two annotated methods cannot share a name);
     * SalesConsoleComplianceService.ensureDocSlots is the entry point and proves the party is on
     * this booking.
     */
    public static Integer ensureComplianceDocSlots(Id opportunityId, Id partyAccountId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity was supplied.');
        }
        try {
            Id contactId;
            String residency;

            if (partyAccountId == null) {
                List<Opportunity> opps = [
                    SELECT Id, AccountId, PrimaryContact__c,
                           Account.IsPersonAccount, Account.PersonContactId,
                           Account.UAE_Resident_Status__pc
                    FROM Opportunity
                    WHERE Id = :opportunityId
                    LIMIT 1
                ];
                if (opps.isEmpty() || opps[0].Account == null
                        || opps[0].Account.IsPersonAccount != true) {
                    return 0;
                }
                contactId = opps[0].Account.PersonContactId != null
                    ? opps[0].Account.PersonContactId
                    : opps[0].PrimaryContact__c;
                residency = opps[0].Account.UAE_Resident_Status__pc;
            } else {
                List<Account> parties = [
                    SELECT Id, IsPersonAccount, PersonContactId, UAE_Resident_Status__pc
                    FROM Account
                    WHERE Id = :partyAccountId
                    LIMIT 1
                ];
                if (parties.isEmpty() || parties[0].IsPersonAccount != true) {
                    return 0;
                }
                /* no PrimaryContact__c fallback: that is the booking's contact, and borrowing it would
                   create the buyer's placeholders under somebody else's name */
                contactId = parties[0].PersonContactId;
                residency = parties[0].UAE_Resident_Status__pc;
            }

            if (contactId == null) {
                return 0;
            }
            if (String.isBlank(residency)) {
                // no residency, no way to know which set is required
                return 0;
            }

            List<String> required = requiredComplianceDocNames(residency);
            if (required.isEmpty()) {
                return 0;
            }

            Set<String> existing = new Set<String>();
            for (Documents__c d : [
                SELECT Id, Name FROM Documents__c
                WHERE PrimaryContact__c = :contactId
                AND Name IN :required
            ]) {
                existing.add(d.Name);
            }

            List<Documents__c> toCreate = new List<Documents__c>();
            for (String name : required) {
                if (existing.contains(name)) {
                    continue;
                }
                toCreate.add(new Documents__c(
                    Name              = name,
                    PrimaryContact__c = contactId,
                    Status__c         = 'Pending Upload'
                ));
            }
            if (!toCreate.isEmpty()) {
                insert toCreate;
            }
            return toCreate.size();
        } catch (DmlException e) {
            throw new AuraHandledException(dmlWords(e));
        } catch (Exception e) {
            throw new AuraHandledException(wordsFor(e));
        }
    }

    /** Document names compliance requires for a residency, from the same Custom Labels
     * AutoPassfortComplianceService reads. */
    public static List<String> requiredComplianceDocNames(String residency) {
        String raw = (residency == NON_RESIDENT)
            ? System.Label.AutoComplianceNonResidentDocNames
            : System.Label.AutoComplianceResidentDocNames;

        List<String> names = new List<String>();
        if (String.isBlank(raw)) {
            return names;
        }
        for (String part : raw.split(',')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                names.add(trimmed);
            }
        }
        return names;
    }
}