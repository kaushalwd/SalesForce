/**
 * Modon Sales Console - user-facing vocabulary.
 *
 * Version  Author      Date         Detail
 * 1.117    Aurelix Dev 30 Sep 2026  MM_ROW_UNNUMBERED is empty instead of a dash (the badge keeps its size).
 * 1.116    Aurelix Dev 30 Sep 2026  KYC and customer side: KYCD_VIEW and KYCC_VIEW_SIGNED say Download; KYCD_NEEDED_BEFORE_ADDING,
 *                                   KYCC_B_GENERATED_EARLIER, VL_STEP_MANUAL, JO_NEW_CHIP; JO_OWNERSHIP_* and ORGD_POA_NEW_Q reworded.
 * 1.115    Aurelix Dev 30 Sep 2026  Booking side: SECTION_*_SHORT tab names, SETTLE_LINK_SENT, SETTLE_HEAD_SETTLED reads
 *                                   "Collected in full", SHEET_AWAIT is an empty box instead of a dash.
 * 1.114    Aurelix Dev 29 Sep 2026  No em dash in rep-facing text: LED_STILL_DUE_LINE and JO_UNIT_CAN_ADD reworded.
 *                                   SHEET_AWAIT, a one-character blank marker, is left as it is.
 * 1.113    Aurelix Dev 29 Sep 2026  ROW_ROUTE_LINK: a booking fee row while the fee is paid by payment link.
 * 1.112    Aurelix Dev 29 Sep 2026  RC_CONFIRM_ALL: the Sales App's "Confirm all selection" tick
 *                                   (c/mscReviewConfirm 1.20).
 * 1.111    Aurelix Dev 29 Sep 2026  PAY_RELEASE_ASK reads "Release the hold on this unit?": the console keeps the rep
 *                                   on the booking after a release, so it cancels nothing.
 * 1.110    Aurelix Dev 29 Sep 2026  BOOK_EOI_*: the EOI the rep picks per unit, refusal in the Sales App's words.
 *                                   PAY_RELEASE_ASK / PAY_RELEASE_YES: the question before Release unit.
 * 1.109    Aurelix Dev 27 Sep 2026  IDF_*_LABEL lose their asterisks (c/mscIdentityFields 1.4 adds one where
 *                                   MODON's Lead rules owe the field); IDF_EXPIRY_PAST accepts today.
 * 1.108    Aurelix Dev 27 Sep 2026  BOOK_OPTION / BOOK_OPTION_PICK / BOOK_OPTION_MISSING: the unit option the
 *                                   Sales App asks for; the refusal is its own sentence.
 * 1.107    Aurelix Dev 27 Sep 2026  SETTLE_HEAD_NO_FEE "No booking fee", for the settlement header before
 *                                   Confirm on a unit that takes no booking fee. IDF_PASSPORT_EXPIRY_LABEL
 *                                   loses its asterisk: passport expiry is optional. KYCC_B_APPROVED_ORG
 *                                   names the form, since a company can now generate one.
 * 1.106    Aurelix Dev 27 Sep 2026  BOOK_FACADE_* and BOOK_PREAPPROVAL_* for the booking page, which now asks
 *                                   for a facade style and an ADIB pre-approval number as MODON's Sales App
 *                                   does (engine 17.0 and 19.0). The three refusals are the Sales App's and
 *                                   the engine's own sentences, so both apps say the same thing.
 *                                   MKYC_SUBJ_COMPANY "Approval on" becomes "Company": a company's manual
 *                                   KYC approval now lands on its Power of Attorney, not on the company.
 * 1.105    Aurelix Dev 24 Sep 2026  KYCC_RETRY / KYCC_RETRYING_BTN. 1.104 gave the failed state its words
 *                                   but there was still nothing to press, so the representative could see
 *                                   that the form had not been produced and do nothing about it.
 *                                   The Error state's own control is the same quiet button with a
 *                                   different word on it: "Try again" beside "Form not generated" says the
 *                                   whole thing, so there is no extra sentence and no alert.
 * 1.104    Aurelix Dev 24 Sep 2026  KYCC_S_FAILED / KYCC_B_FAILED and KYCC_S_UNCLEAR / KYCC_B_UNCLEAR. The
 *                                   KYC panel had wording for four states and a record that can be in six,
 *                                   so a failed render and an unrecognised status both borrowed the words
 *                                   "Form requested". A failed attempt now says so, and a
 *                                   status outside MODON's four values names the value rather than
 *                                   pretending to understand it. Both stay to one status word and one short
 *                                   sentence, like the states beside them.
 * 1.103    Aurelix Dev 24 Sep 2026  KYCC_S_GENERATED / KYCC_B_GENERATED: a form whose PDF is already on
 *                                   the record read "The form is being generated and sent for
 *                                   signature.", which is the state before it, so the panel now says the
 *                                   form is generated and what it is waiting for.
 * 1.102    Aurelix Dev 24 Sep 2026  KYCC_MISSING_FILES_INTRO: the KYC box listed the passport and the
 *                                   Emirates ID scans under "Complete these in Update KYC", where no
 *                                   file can be uploaded. The documents now have a
 *                                   heading of their own that says what they are: files to upload.
 * 1.101    Aurelix Dev 22 Sep 2026  RC_FEE_BY_EOI: the booking fee is covered by the unit's EOI deposit.
 * 1.100    Aurelix Dev 22 Sep 2026  JO_KYC_* and JO_CREATE_*: the joint owner drawer shows MODON's KYC
 *                                   check on a found person, sends them a KYC link, and creates a new
 *                                   person before adding them.
 * 1.99     Aurelix Dev 21 Sep 2026  The manual KYC states show one sentence and no status word.
 *                                   KYCG_B_WITHDRAWN names the request itself ("Request withdrawn on
 *                                   {0}. Send it again."). KYCG_S_WITHDRAWN and KYCG_REQUEST_SENT(_TO)
 *                                   are no longer used and are removed (SCW-142).
 * 1.98     Aurelix Dev 21 Sep 2026  A pending manual KYC reads "Waiting for manual KYC approval.",
 *                                   with "Sent <day> to <approvers>" beneath (KYCG_REQUEST_SENT*, replacing
 *                                   KYCG_B_AWAITING_SENT). The digital link gets its own labelled row in
 *                                   the manual states, so Resend is not read as re-sending the approval:
 *                                   KYCG_LINK_LABEL / KYCG_LINK_* / KYCG_A_SEND_LINK (SCW-141).
 * 1.97     Aurelix Dev 21 Sep 2026  The KYC box's manual request in plain words: "With
 *                                   compliance" was wrong - compliance is the later screening step -
 *                                   so KYCG_S_AWAITING is "Pending approval" and says when it was sent
 *                                   and to whom (KYCG_B_AWAITING_SENT). KYCG_S_WITHDRAWN /
 *                                   KYCG_B_WITHDRAWN* for a recalled request, KYCC_B_REJECTED_ON for a
 *                                   rejection's date and approver. KYCG_A_RESEND is "Resend link": it
 *                                   re-sends the customer's KYC link, not the approval (SCW-139).
 * 1.96     Aurelix Dev 21 Sep 2026  MODON's action matrix: discard is Finance's, permanently, so
 *                                   DDC_ACTIONS_OFF stops naming it (that note is temporary) and
 *                                   DDC_DISCARD_FINANCE says where it is done (that one is not).
 * 1.95     Aurelix Dev 20 Sep 2026  DDC_ACTIONS_OFF no longer claims Refresh happens in Modon's
 *                                   app - it happens right below the line.
 * 1.94     Aurelix Dev 20 Sep 2026  Two refreshes told apart on the mandate card: DDC_REREAD
 *                                   re-reads what Salesforce holds (no callout, always offered),
 *                                   CTA_REFRESH_BANK now reads "Ask the bank now" because that
 *                                   one is a call to UAEDDS and needs the credential.
 * 1.93     Aurelix Dev 18 Sep 2026  SCW-125. Direct debit re-based on MODON's UAEDDS build: the mandate
 *                                   card (DDC_*), e-mail / city on the form, live rule feedback, stage
 *                                   wording in the box and the modal foot, the "not offered" reason.
 * 1.91     Aurelix Dev 18 Sep 2026  KYCC_B_SIGNED no longer says "Refresh to re-check eligibility":
 *                                   the verdict re-reads itself after the signed copy.
 * 1.90     Aurelix Dev 18 Sep 2026  KYCC_GENERATING_BTN / KYCC_GENERATING_NOTE: Generate said nothing
 *                                   while Nintex rendered (seen in testing).
 * 1.89     Aurelix Dev 18 Sep 2026  KYCC_B_APPROVED_ORG: an approved company was told to "generate
 *                                   the form", a control it never sees (seen in the browser).
 * 1.88     Aurelix Dev 18 Sep 2026  MSC-175/176/178/179 (B3-B10). KYCD_* for c/mscKycDocuments (the
 *                                   required-documents checklist), KYCM_* for c/mscKycCaptureModal
 *                                   (Update KYC on MODON's own form), MKYC_* reworded for the
 *                                   optional file and the company subject line, KYCC_* gains the
 *                                   generation-gate sentence, and two switches: OFFER_ENABLED
 *                                   (false - the Offer control is hidden, code kept) and
 *                                   KYCC_INLINE_FORM (false - the console's own capture renderer
 *                                   is retired in favour of the modal, code kept one release).
 *                                   No user-facing string says "Opportunity" any more.
 * 1.87     Aurelix Dev 17 Sep 2026  MSC-173 (B1). MKYC_UPLOADED ({0} is the file's title): the
 *                                   manual-KYC panel now says which file the upload produced. The
 *                                   dropdown alone never showed it, so reps uploaded twice.
 * 1.86     Aurelix Dev 08 Sep 2026  SC-UI-008. KYCG_S_MANUAL_APPROVED / KYCG_B_MANUAL_APPROVED:
 *                                   an approved manual route no longer reads "Not started".
 * 1.85     Aurelix Dev 07 Sep 2026  Signzy Phase 3B. KYCC_* for c/mscKycCapture - the
 *                                   post-approval route: Update KYC, generate, signed, refresh.
 * 1.84     Aurelix Dev 07 Sep 2026  Signzy Phase 3. The KYCG_* block gains the ACTIVE states and
 *                                   the three actions, because step 2 is now where primary-buyer
 *                                   and POA KYC is actually done. The digital states are the
 *                                   org's own (NOT_SENT / SENT / EXPIRED / IN_BRANCH) rather
 *                                   than a second vocabulary. KYCG_SUBJ_POA exists because a
 *                                   company's KYC subject is a person - the authorised POA -
 *                                   and the panel must say whose verification it is showing.
 * 1.83     Aurelix Dev 07 Sep 2026  Signzy Phase 2. The KYCG_* block for c/mscKycGate - the
 *                                   read-only KYC panel in step 2. Separate from the KYC_*
 *                                   block above, which belongs to the POST-booking verification
 *                                   journey: these two say different things at different points
 *                                   and must not be shared. KYCG_ADVISORY exists to state that
 *                                   this phase blocks nothing, and is retired in Phase 4.
 * 1.82     Aurelix Dev 02 Sep 2026  MSC-225. OFFER_WHATSAPP: the offer drawer's second control.
 * 1.81     Aurelix Dev 02 Sep 2026  MSC-214. QUALIFY_LEDE_SEEDED withdrawn same day (client:
 *                                   the seeded panel carries no lede).
 * 1.80     Aurelix Dev 02 Sep 2026  MSC-212. QUALIFY_LEDE_SEEDED: the qualify panel opened by
 *                                   "Book a unit" on the lead drawer says where the lead came
 *                                   from instead of reading like a search result.
 * 1.79     Aurelix Dev 02 Sep 2026  MSC-211. LEAD_HANDED_OVER ({0} is the lead's name): said
 *                                   once when a qualified lead leaves the rep's own list.
 * 1.78     Aurelix Dev 01 Sep 2026  MSC-205. CHQ_* - four short flags on a cheque a bank would
 *                                   question; two words each, business wants no sentences.
 * 1.77     Aurelix Dev 01 Sep 2026  MSC-202a. The read line carries no commentary: "Filled in
 *                                   for you; check the boxes." and "Matches what is filled in."
 *                                   are gone - the line states the values and stops.
 * 1.76     Aurelix Dev 01 Sep 2026  MSC-200c. The read explains itself: "Also on the image",
 *                                   the cheque-image sentence on the payment form and the same
 *                                   claim in the sheet's own two sentences are all gone.
 * 1.75     Aurelix Dev 01 Sep 2026  MSC-200. The cheque screens are filled by the read alone:
 *                                   SHEET_HINT / SHEET_RULES rewritten, SHEET_AWAIT and
 *                                   PROOF_CHEQUE_LOCKED added, SHEET_FIRST_NO retired with the
 *                                   sequence control.
 * 1.74     Aurelix Dev 01 Sep 2026  MSC-198. SHEET_ATTACHED replaces the raw file name in the
 *                                   cheque table's image cell.
 * 1.73     Aurelix Dev 01 Sep 2026  MSC-197. PROOF_READ_* for the cheque read on the main
 *                                   payment form, ROW_PAY_OCR_* for a cheque already recorded.
 * 1.72     Aurelix Dev 01 Sep 2026  MSC-196 follow-up. The read line no longer scolds: a value
 *                                   that differs from the boxes is stated, not judged.
 * 1.71     Aurelix Dev 01 Sep 2026  MSC-196. SHEET_READ_* for a read that failed, was unreadable
 *                                   or was not a cheque, plus the context line and Read again.
 * 1.70     Aurelix Dev 01 Sep 2026  MSC-194. PROOF_REQUIRED_CAMERA for touch, where there is no picker.
 * 1.69     Aurelix Dev 30 Aug 2026  MSC-182. VL_GROUP_BUYER / VL_GROUP_OWNERS; JO_V_NOT_HERE_LINE.
 * 1.68     Aurelix Dev 30 Aug 2026  MSC-181. "Power of Attorney" everywhere; ORGD_POA_* replaces ORGD_SIG_*.
 * 1.67     Aurelix Dev 30 Aug 2026  MSC-180. JO_KIND_*, JO_F_TRADE_LICENCE, JO_F_COMPANY_NAME, JO_NOT_FOUND_COMPANY.
 * 1.66     Aurelix Dev 25 Aug 2026  MSC-168. VERIFY_AWAIT_*.
 * 1.65     Aurelix Dev 24 Aug 2026  MSC-163. BANNER_DISMISS.
 * 1.64     Aurelix Dev 24 Aug 2026  MSC-161. BASKET_NO_PLAN reads "Pending".
 * 1.63     Aurelix Dev 24 Aug 2026  MSC-160. IDST_FACT_RESIDENCY.
 * 1.62     Aurelix Dev 22 Aug 2026  MSC-134. FIND_KEY_* for the segmented search control.
 * 1.61     Aurelix Dev 22 Aug 2026  MSC-132. IDST_RESIDENCY_*; MATCH_RESIDENCY retired.
 * 1.60     Aurelix Dev 22 Aug 2026  MSC-130. CUST_ON_FILE_NOTE rewritten.
 * 1.59     Aurelix Dev 22 Aug 2026  MSC-128. IDST_NOTE removed.
 * 1.58     Aurelix Dev 22 Aug 2026  MSC-126. TOAST_*.
 * 1.57     Aurelix Dev 22 Aug 2026  MSC-122. CTA_SAVE_MISSING.
 * 1.56     Aurelix Dev 22 Aug 2026  MSC-121. CUST_RESIDENT_STATUS.
 * 1.55     Aurelix Dev 22 Aug 2026  MSC-118. One search key at a time.
 * 1.54     Aurelix Dev 22 Aug 2026  MSC-117. One Find customer button; MATCH_NONE_KEY_*.
 * 1.53     Aurelix Dev 22 Aug 2026  MSC-115 / MSC-116. KYC_CORPORATE and the VL_ORG_* block.
 * 1.52     Aurelix Dev 22 Aug 2026  MSC-113 / MSC-114. CUST_REAL_BEN_*, ORG_LICENCE_NO_HINT, MATCH_ROW_ADDRESS*,
 *                                   LEAD_QUEUED, LEAD_PHONE_SHAPE; ORG_OWNER* retired.
 * 1.51     Aurelix Dev 22 Aug 2026  MSC-112. The CUST_ block.
 * 1.50     Aurelix Dev 22 Aug 2026  MSC-111. Second search key, what-matched chips, candidates chooser.
 * 1.49     Aurelix Dev 22 Aug 2026  MSC-110. IDF_ and IDST_ blocks; LEAD_FORM_*.
 * 1.48     Aurelix Dev 21 Aug 2026  MSC-108. Company rows and the SIG_ block.
 * 1.47     Aurelix Dev 21 Aug 2026  MSC-107. SHEET_FILE_TOO_LARGE / SHEET_FILE_UNREADABLE.
 * 1.46     Aurelix Dev 23 Aug 2026  MSC-154 / MSC-102. "Authorized" spelling; "Allocated" in the payment modal.
 * 1.45     Aurelix Dev 23 Aug 2026  MSC-153. NAV_FLOOR_COMMITTED / NAV_FLOOR_COLLECTED.
 * 1.44     Aurelix Dev 23 Aug 2026  MSC-151 / MSC-100. VL_ORG_* action labels retired; LED_PENDING_*.
 * 1.43     Aurelix Dev 23 Aug 2026  MSC-150. ORGD_SIG_WHY retired; BOX_BY_CHEQUE retired.
 * 1.42     Aurelix Dev 23 Aug 2026  MSC-149. VL_ORG_SIG_WAITING and the ORGD_*_LINK block.
 * 1.41     Aurelix Dev 23 Aug 2026  MSC-148. The ORGD_* block; ROW_PAY_COVERED wording.
 * 1.40     Aurelix Dev 21 Aug 2026  MM_IL_REMAINING.
 * 1.39     Aurelix Dev 21 Aug 2026  BLOCK_AMOUNT_HINT retired.
 * 1.38     Aurelix Dev 21 Aug 2026  MSC-099. CTA_CLOSE; CTA_HIDE retired.
 * 1.37     Aurelix Dev 21 Aug 2026  MSC-098c. LED_COL_STILL_DUE retired.
 * 1.36     Aurelix Dev 21 Aug 2026  MSC-098b. ADVANCE_NOTE* retired.
 * 1.35     Aurelix Dev 21 Aug 2026  MSC-098. LED_* column words.
 * 1.34     Aurelix Dev 21 Aug 2026  MSC-097. MM_* for the milestone modal.
 * 1.33     Aurelix Dev 20 Aug 2026  MSC-096. The obligation ledger as a table.
 * 1.32     Aurelix IT  20 Aug 2026  MSC-088. OT_* and VL_*.
 * 1.31     Aurelix IT  20 Aug 2026  MSC-084. JO_B_* block.
 * 1.30     Aurelix IT  20 Aug 2026  MSC-083. Compliance per person.
 * 1.29     Aurelix IT  20 Aug 2026  MSC-082. JO_V_* block.
 * 1.28     Aurelix IT  20 Aug 2026  MSC-081. The joint-owner vocabulary, Modon's own.
 * 1.27     Aurelix IT  19 Aug 2026  MSC-077. Each button says what it is waiting for.
 * 1.26     Aurelix IT  19 Aug 2026  MSC-073. The two halves of the check.
 * 1.25     Aurelix IT  19 Aug 2026  MSC-071. Verified details are read only.
 * 1.24     Aurelix IT  19 Aug 2026  MSC-069. COMPLIANCE_CTA and the panel's vocabulary.
 * 1.23     Aurelix IT  19 Aug 2026  MSC-061. Verification chain wording.
 * 1.22     Aurelix Dev 19 Aug 2026  VERIFY_TAPE_SENT / KYC_SENT_DONE.
 * 1.21     Aurelix Dev 19 Aug 2026  A proof records a Payment: ROW_PAY_*, PROOF_*, Create Payment fields.
 * 1.20     Aurelix Dev 18 Aug 2026  The milestone box: BOX_*, SHEET_*, ROW_CHEQUE_*, DD_*.
 * 1.19     Aurelix Dev 17 Aug 2026  FOCUS_DOCS removed.
 * 1.18     Aurelix Dev 17 Aug 2026  LEDGER_SHOW_SETTLED / LEDGER_HIDE_SETTLED removed.
 * 1.17     Aurelix Dev 17 Aug 2026  No em dashes in visible strings; CONTACT_*, EID_INCOMPLETE.
 * 1.16     Aurelix Developer 17 Aug 2026  SUMMARY_ONE_OF / SUMMARY_OPEN_SIBLING / SETTLE_MULTI_NO_FEE_ONE.
 * 1.15     Aurelix Dev 17 Aug 2026  The multi-unit no-fee rule, stated on the header.
 * 1.14     Aurelix Dev 17 Aug 2026  Still to do and the resume statement.
 * 1.13     Aurelix Dev 17 Aug 2026  The hold in the ledger; a lapsed hold is two situations; payRoute.
 * 1.10     Aurelix Dev 17 Aug 2026  The WAITING state; "Booking fee" on the rail.
 * 1.5      Aurelix Dev 16 Aug 2026  Settlement vocabulary; "ADM + Dari".
 * 1.4      Aurelix IT  11 Aug 2026  Buyer type in Modon's words.
 * 1.3      Aurelix IT  10 Aug 2026  Company vocabulary.
 * 1.2      Aurelix IT  07 Aug 2026  Multi-unit booking copy.
 * 1.1      Aurelix IT  06 Aug 2026  Compliance and KYC vocabulary.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 */

/**
 * Single source of truth for every string an agent reads. A JS module rather than Custom
 * Labels so a wording tweak is a diff, not a metadata deploy. Renames nothing in the org.
 */

const LABELS = Object.freeze({
  // Sections
  SECTION_UNIT: "Unit Selection",
  SECTION_CUSTOMER: "Customer Information",
  SECTION_PLAN: "Payment Plan",
  SECTION_SUMMARY: "Booking Summary", // was "Sales Order"
  SECTION_PAYMENT: "Payment Information",
  SECTION_REVIEW: "Review & Confirm", // was "Generate Sales Order"
  /* the two above are one card now, SECTION_SETTLE ("Payment & Confirm"); action labels match the internal journey */

  // Primary actions
  CTA_CONFIRM: "Confirm Booking",
  CTA_CONFIRMING: "Confirming your booking…",
  CTA_SAVE_CUSTOMER: "Save customer details",
  /* the customer card's button: it commits blanks only */
  CTA_SAVE_MISSING: "Save missing details",
  /* what the toast says */
  TOAST_CUSTOMER_SAVED: "Customer details saved.",
  TOAST_ADDRESS_SAVED: "Address saved.",
  CTA_SUBMIT_PROOF: "Submit payment proof",
  CTA_SETUP_DD: "Set up Direct Debit",
  /* the step after Confirm */
  ADVANCE_CTA: "Continue to Verification",
  /* ADVANCE_NOTE / ADVANCE_NOTE_MANY retired with the advance strip */
  CTA_EDIT: "Edit",

  // Record references
  BOOKING_REFERENCE: "Booking Reference", // was "Sales Order Number"
  TRANSACTION_NUMBER: "Transaction Number", // was "Txn No"

  // Money
  TOTAL_PRICE: "Total Price",
  DOWN_PAYMENT: "Down Payment",
  /* "ADM + Dari", the name Modon uses; the picklist value stays 'ADM Registration Fee' */
  ADM_FEE: "ADM + Dari",
  DUE_NOW: "Due Now",
  /* what the rail's Amounts group lists before Confirm: the three parts of the deposit */
  BOOKING_FEE: "Booking fee",
  BOOKING_FEE_SUB: "Payable now, held against the purchase price",
  COLLECTED: "Collected",
  BALANCE: "Balance",
  MILESTONE: "Payment milestone", // was "Installment"
  MILESTONES: "Payment milestones",

  /* Settlement: four states, because captured-here and recognised-by-the-org differ for hours */
  SETTLE_NOT_STARTED: "Not started",
  SETTLE_PARTLY: "Partly paid",
  SETTLE_CLEARING: "Awaiting clearance",
  SETTLE_DONE: "Settled",
  /* 1.115: a fee leg with a live payment link and nothing paid yet */
  SETTLE_LINK_SENT: "Link sent",

  SETTLE_HEAD_OUTSTANDING: "Outstanding to close this booking",
  /* before Confirm the figures are the booking fee (the deposit), not the closing amounts */
  SETTLE_HEAD_BOOKING_FEE: "Payable to confirm this booking",
  SETTLE_SUB_BOOKING_FEE:
    "Booking fee, held against the purchase price. The full instalments follow once the booking is confirmed.",
  /* SETTLE_FEE_FORMULA(_ESTIMATE) are gone with the formula line */
  /* after Confirm: an unpaid fee outlives the booking being made */
  SETTLE_HEAD_FEE_AFTER: "Booking fee still outstanding",
  SETTLE_SUB_FEE_AFTER:
    "The booking is made and the unit is reserved. This is what is left of the fee that holds it.",
  /* before Confirm there is nothing for finance to allocate against yet */
  SETTLE_HEAD_FEE_IN: "Booking fee collected",
  SETTLE_SUB_FEE_IN:
    "The full booking fee is in. Confirm the booking to reserve the unit and raise the instalments.",
  SETTLE_HEAD_CLEARING: "Captured in full",
  /* 1.115: "settled" is the sale status chip's word only */
  SETTLE_HEAD_SETTLED: "Collected in full",
  SETTLE_HEAD_NONE: "Nothing to collect yet",
  /* 1.107: a unit that takes no booking fee, before Confirm */
  SETTLE_HEAD_NO_FEE: "No booking fee",

  SETTLE_SUB_OF: "of {0}",
  SETTLE_SUB_OF_WITH_PAID: "of {0} · {1} collected",
  SETTLE_SUB_CLEARING:
    "Waiting for finance to allocate the payments. The booking closes once they do.",
  SETTLE_SUB_SETTLED: "Collected in full and confirmed.",
  SETTLE_SUB_NONE: "Amounts appear once the booking is confirmed.",

  /* "left" implies progress, so it is wrong before anything has been paid */
  SETTLE_TAPE_FEE: "Booking fee",
  SETTLE_TAPE_OUTSTANDING: "Outstanding",
  SETTLE_LEG_LEFT: "{0} left",
  SETTLE_LEG_DUE: "{0} due",
  SETTLE_LEG_NONE: "Nothing due",
  /* MSC-095: a draft basket is not calculated yet, so "Nothing due" would be false */
  SETTLE_LEG_AFTER: "After booking",
  SETTLE_LEG_CLEARING: "Received here, not yet reflected on the booking record.",
  /* SETTLE_ESTIMATE_NOTE gone with the formula line */
  /* journey 07: a basket takes no booking fee; each leg is invoiced against its own Sales Order */
  /* MSC-096: one sentence; the ledger names every payment */
  SETTLE_MULTI_NO_FEE:
    "No booking fee is taken on a multi-unit booking. Each unit is invoiced against its own Sales Order.",
  /* the same rule from inside one order of the booking */
  SETTLE_MULTI_NO_FEE_ONE:
    "One of {0} units on this booking. No booking fee is taken; each unit is invoiced against its own Sales Order.",

  /* MSC-096: how far the closing money has got, under the figure */
  SETTLE_PROGRESS_NONE: "{0} · nothing collected yet",
  SETTLE_PROGRESS_SOME: "{0} · {1} collected",

  /* The obligation ledger: two groups, titled by what each group is to the agent */
  LEDGER_CLOSES_TITLE: "Closes the booking",
  /* MSC-096b: on a single unit that took a fee, the ADM + Dari charge and Milestone 1 fall due
     on booking day and get their own heading */
  LEDGER_DUE_NOW_TITLE: "Due now",
  /* MSC-096: scheduled when */
  LEDGER_SCHEDULED_TITLE: "Scheduled after booking",
  LEDGER_ITEMS: "{0} payments",
  /* MSC-096: the singular */
  LEDGER_ITEM_ONE: "1 payment",
  /* LEDGER_OUTSTANDING retired; the count says what the rows say, over three states */
  LEDGER_PENDING: "{0} pending",
  LEDGER_NONE_PENDING: "nothing pending",
  LEDGER_ALL_SETTLED: "all settled",
  LEDGER_MILESTONES: "{0} milestones",
  /* the singular */
  LEDGER_MILESTONE_ONE: "1 milestone",
  LEDGER_FIRST_DUE: "first due {0}",
  /* a due date in the past, said out loud */
  LEDGER_OVERDUE: "{0} overdue",
  LEDGER_OVERDUE_ONE: "1 overdue",
  LEDGER_ROW_OVERDUE: "Overdue",
  LEDGER_OVERDUE_NOTE:
    "Dated before this booking was made. Check the payment plan's schedule with Sales Operations.",
  LEDGER_OF_PAID: "of {0} · {1} paid",
  LEDGER_DUE: "due {0}",

  /* MSC-096: the ledger as a table; column names for screen readers */
  LEDGER_COL_UNIT: "Unit",
  LEDGER_COL_PAYMENT: "Payment",
  LEDGER_COL_AMOUNT: "Amount",
  LEDGER_COL_STATUS: "Status",
  LEDGER_COL_ACTION: "Action",
  /* a basket has no single booking reference; each unit names its own */
  LEDGER_SO_COUNT: "{0} Sales Orders",
  /* the scheduled tier's own total */
  LEDGER_SCHED_SUMMARY: "{0} · {1}",

  /* MSC-098: one meaning per number (Total / Recorded / Still due); RECORDED is paid plus with Finance */
  LED_COL_TOTAL: "Total",
  /* MSC-100: LED_COL_RECORDED retired; LED_COL_PENDING is the accessible name of the empty header */
  LED_COL_PENDING: "Pending",
  /* LED_COL_PAID retired */
  /* MSC-098c: LED_COL_STILL_DUE retired */
  LED_ROW_DUE: "Due {0}",
  /* MSC-100: the row line, figure then keyword */
  LED_PENDING_WORD: "pending",
  /* the seconds after Confirm while MODON's chain runs */
  LED_FINALISING: "Finalising\u2026",
  LED_NONE_PENDING: "No amount pending",
  /* MSC-102: the money Finance has allocated; one word, said once */
  LED_ALLOCATED: "Allocated",
  LED_STILL_DUE_LINE: "Still due on this payment. Record it below",

  /* The milestone box: cheques or a Direct Debit mandate, one instrument per schedule */
  BOX_TITLE: "Pay the milestones after the down payment",
  BOX_RANGE: "Milestones {0} to {1}",
  BOX_RANGE_ONE: "Milestone {0}",
  BOX_NONE_COVERED: "none covered yet",
  BOX_RECORDING: "recording cheques",
  BOX_SETTING_DD: "setting up Direct Debit",
  /* BOX_BY_CHEQUE retired */
  BOX_CHEQUES_WITH_FINANCE: "{0} cheques with Finance",
  BOX_CHEQUE_WITH_FINANCE: "1 cheque with Finance",
  BOX_STILL_OPEN: "milestones {0} to {1} still open",
  BOX_STILL_OPEN_ONE: "milestone {0} still open",
  BOX_STILL_OPEN_SOME: "{0} milestones still open",
  BOX_ALL_COVERED: "every milestone covered",
  BOX_DD_STATUS: "Direct Debit · {0}",
  BOX_DD_LINE: "Direct Debit · {2} · covers milestones {0} to {1}",
  BOX_DD_LINE_ACTIVE: "Approved by the bank · collects milestones {0} to {1} as they fall due",
  BOX_DD_LINE_REJECTED: "Direct Debit · {0} · cheques can be recorded",
  BOX_NOTHING_LEFT: "nothing left to pay",
  CTA_ADD_CHEQUES: "Add cheques",
  CTA_VIEW_MANDATE: "View mandate",
  CTA_HIDE_MANDATE: "Hide mandate",
  CTA_RECORD_CHEQUES: "Record {0} cheques",
  CTA_RECORD_CHEQUE: "Record 1 cheque",
  CTA_RECORDING_CHEQUES: "Recording…",
  CTA_CANCEL: "Cancel",
  /* MSC-096: the closing rows carry a named control */
  /* MSC-099: one fact decides which: is anything still due */
  CTA_RECORD_PAYMENT: "Complete payment",
  CTA_VIEW_PAYMENT: "View payment",
  /* MSC-099: CTA_HIDE retired */
  CTA_CLOSE: "Close",
  /* MSC-096: the scheduled tier's action, shortened; CTA_SETUP_DD stays for the form */
  CTA_DIRECT_DEBIT: "Direct Debit",
  CTA_CHEQUES: "Cheques",

  /* The milestone modal (MSC-097) */
  CTA_MANAGE_MILESTONES: "Manage milestone payments",
  MM_TITLE: "Milestone payments",
  MM_UNITS_SUB: "{0} units",
  MM_RAIL_TITLE: "Units",
  MM_STATE_NONE: "Nothing arranged yet",
  /* "Cheques · 3 of 6" */
  MM_STATE_CHEQUES: "Cheques · {0} of {1}",
  /* "{covered} of {total} covered" */
  MM_COVERED_OF: "{0} of {1} covered",
  MM_YEAR_ONE: "1 milestone",
  MM_YEAR_ALL: "all covered",
  /* an undated milestone still has to be listed */
  MM_YEAR_UNDATED: "No date",
  MM_RAIL_NONE: "nothing arranged",
  MM_FILTER_ALL: "All {0}",
  MM_FILTER_OPEN: "Open {0}",
  MM_FILTER_COVERED: "Covered {0}",
  /* the foot's one question */
  MM_FOOT_HOW: "How will these be paid?",
  MM_FOOT_OPEN_ONE: "1 milestone still open",
  /* requestName · bank iban */
  MM_FOOT_MANDATE: "Mandate {0}",
  MM_HEAD_DD_VIEW: "Direct Debit mandate",
  /* MSC-097a: the covered row and its instrument lines */
  /* the number badge on a milestone that has none: an empty badge */
  MM_ROW_UNNUMBERED: "",
  MM_IL_CHIP: "In Progress with Finance",
  /* the instrument line is the Payment */
  MM_IL_PAYMENT: "Payment {0}",
  MM_IL_SUBMITTED: "Submitted on {0}",
  /* "Remaining on this milestone", not "Still open" */
  MM_IL_REMAINING: "Remaining on this milestone",
  /* the one quiet word after the recorded figure */
  MM_REC_WORD: "recorded",
  /* MM_PAID_WORD retired; MM_REC_WORD stays */

  /* The cheque sheet: column names are the Create Payment flow's */
  SHEET_TITLE: "Cheques for milestones {0} to {1}",
  SHEET_TITLE_ONE: "Cheques for milestone {0}",
  SHEET_HINT: "Tick the milestones these cheques cover and attach each cheque's image.",
  SHEET_BANK: "Customer Bank (all cheques)",
  SHEET_BANK_PLACEHOLDER: "Choose the bank",
  /* MSC-200: SHEET_FIRST_NO retired - nothing is typed or sequenced on this sheet any more */
  SHEET_COL_MILESTONE: "Milestone",
  SHEET_COL_DUE: "Due",
  SHEET_COL_LEFT: "Left",
  SHEET_COL_IMAGE: "Cheque image *",
  SHEET_COL_NUMBER: "Cheque Number",
  SHEET_COL_DATE: "Cheque Date",
  SHEET_COL_AMOUNT: "Amount",
  SHEET_ATTACH: "Attach image",
  SHEET_ATTACHING: "Attaching the image for {0}",
  SHEET_IMAGE_OK: "image attached",
  SHEET_ANOTHER: "Add another cheque for this milestone",
  SHEET_ANOTHER_ROW: "{0} cheque",
  SHEET_REMOVE_ROW: "Remove this cheque",
  SHEET_COVERED: "covered",
  SHEET_IMAGE_NEEDED: "{0} needs its cheque image before these can be recorded.",
  SHEET_IMAGES_NEEDED: "{0} milestones need their cheque image before these can be recorded.",
  SHEET_OVER: "{0}: the cheques add up to more than what is left.",
  SHEET_NUMBER_TWICE: "Cheque {0} is entered twice.",
  SHEET_READ_MATCH: "{0}: read from the image · {1}.",
  SHEET_READ_DIFF: "{0}: read from the image · {1}.",
  SHEET_READ_FILLED: "{0}: read from the image · {1}.",
  SHEET_RULES:
    "A cheque can be for less than what is left on a milestone, never more. Photograph with the camera or pick a file, as for proof today.",
  /* MSC-200: what stands in the boxes until the image has been read; 1.115: an empty box, not a dash */
  SHEET_AWAIT: "",
  SHEET_AWAIT_TITLE: "Read from the cheque image",
  SHEET_SUM: "{0} cheques · {1} · {2}",
  SHEET_SUM_ONE: "1 cheque · {0} · {1}",
  SHEET_SUM_NONE: "No milestone ticked yet",
  SHEET_SUM_MISSING: "{0} image missing",
  SHEET_SUM_MISSING_MANY: "{0} images missing",
  SHEET_SUM_NO_BANK: "bank not chosen",
  SHEET_RESULT_OK: "recorded · with Finance",
  SHEET_RESULT_NOALLOC: "recorded · Finance to allocate",
  SHEET_CAPTURE_LABEL: "Capture cheque",
  SHEET_CAPTURE_HINT: "Fit the whole cheque inside the frame",
  SHEET_STAGING: "Saving the image…",
  SHEET_READING: "Reading the image…",
  /* MSC-198: a phone's file name says nothing and stretched the column; the name is the title */
  SHEET_ATTACHED: "Attached",
  /* MSC-196: a read that did not land says so - silence read as "nothing happened" */
  SHEET_READ_FAILED: "{0}: the image could not be read.",
  SHEET_READ_UNCLEAR: "{0}: the image is too unclear. Attach a clearer photo.",
  SHEET_READ_NOT_CHEQUE: "{0}: that image does not look like a cheque. Attach the cheque itself.",
  SHEET_READ_AGAIN: "Read again",
  /* what the image also said, shown as context and never written to a box */
  /* MSC-200c: SHEET_READ_CONTEXT retired with the "Also on the image" line */
  /* MSC-107: the desktop route's two failures, no camera in either */
  SHEET_FILE_TOO_LARGE: "{0} is too large. Use a file up to 4 MB.",
  SHEET_FILE_UNREADABLE: "That file could not be read. Please try another.",

  /* a row covered by an instrument */
  ROW_CHEQUE_CHIP: "Cheque with Finance",
  ROW_CHEQUE_SUB: "Cheque {0} · {1}",
  ROW_CHEQUES_SUB: "{0} cheques · {1}",
  ROW_CHEQUE_IMAGE: "image attached",
  ROW_CHEQUE_CARD:
    "Cheque {0} dated {1} for {2}, {3} · Payment {4} is In Progress with Finance for approval; the milestone reads Settled once it is allocated.",
  ROW_CHEQUE_CARD_NOBANK:
    "Cheque {0} dated {1} for {2} · Payment {3} is In Progress with Finance for approval; the milestone reads Settled once it is allocated.",
  ROW_CHEQUE_CARD_RECORDED: "recorded {0} by {1}",
  ROW_CHEQUE_CARD_STATUS: "Payment {0} · {1}",
  ROW_CHEQUE_NOTHING_ELSE: "No form here: nothing else is asked for this milestone.",
  ROW_STILL_OPEN: "{0} still open on this milestone · use Add cheques above.",
  ROW_BOX_NOTE:
    "Nothing to capture here. Cheques for this milestone are recorded with Add cheques above; Set up Direct Debit covers the whole schedule.",
  /* a lead row a payment with Finance covers */
  /* MSC-197: what the image said about a cheque already recorded */
  ROW_PAY_OCR: "Image read · {0}",
  ROW_PAY_OCR_DIFF: "Image read · {0} · does not match what was recorded",
  ROW_PAY_OCR_FAILED: "The cheque image could not be read.",
  ROW_PAY_OCR_RETRY: "Retry",
  ROW_PAY_OCR_WAIT: "Reading the cheque image…",
  ROW_PAY_CHIP: "Payment with Finance",
  ROW_PAY_SUB: "{0} {1} · {2}",
  ROW_PAYS_SUB: "{0} payments with Finance · {1}",
  ROW_PAY_CARD:
    "{0} {1} dated {2} for {3} · Payment {4} is In Progress with Finance for approval; the row reads Settled once it is allocated.",
  ROW_PAY_CARD_CHEQUE:
    "Cheque {0} dated {1} for {2}, {3} · Payment {4} is In Progress with Finance for approval; the row reads Settled once it is allocated.",
  ROW_PAY_FILES: "{0} files attached",
  /* "recorded" is the console's word for money handed over but not yet allocated */
  ROW_PAY_COVERED: "The full amount is recorded and with Finance.",
  ROW_PAY_STILL_OPEN: "{0} is still due on this payment. Record it below.",
  ROW_PAY_SUB_OPEN: "{0} still open",
  ROW_DD_NOTE:
    "Direct Debit mandate {0}. The bank collects this milestone when it is due; nothing else is asked here.",
  ROW_DD_SUB: "collected by the bank when due",

  /* The mandate form: DirectDebitRequest__c's labels */
  DD_TITLE: "Direct Debit for milestones {0} to {1}",
  DD_TITLE_ONE: "Direct Debit for milestone {0}",
  DD_HINT: "Saved as a draft for Finance, who sends it to the bank. The customer signs in UAE PASS and the bank collects each milestone as it falls due.",
  DD_FIELD_HOLDER: "Customer Bank Account Name",
  DD_FIELD_BANK: "Customer Bank Name",
  DD_FIELD_TYPE: "Customer Bank Account Type",
  DD_FIELD_IBAN: "Customer IBAN Number",
  DD_FIELD_ID_TYPE: "Customer Id Type",
  DD_FIELD_ID_NUMBER: "Customer ID Number",
  DD_FIELD_MOBILE: "Customer Mobile",
  DD_CHOOSE: "Choose",
  DD_REQUIRED: "Required.",
  DD_IBAN_INVALID: "Enter a valid UAE IBAN (AE followed by 21 digits).",
  DD_COMPUTED: "Covers milestones {0} to {1} · up to {2} per collection · from {3} to {4}. Set by Modon's rules from the schedule, not typed here.",
  DD_FIELD_EMAIL: "Customer Email",
  DD_FIELD_CITY: "Customer City",
  DD_FIELD_HOLDER_HINT: "as the bank holds it",
  DD_MOBILE_HINT: "UAE mobile · saved as 05XXXXXXXX",
  DD_EMAIL_INVALID: "Enter a valid e-mail address.",
  DD_RULES_CHECKING: "Checking against Modon's rules…",
  DD_RULES_OK: "Modon's checks pass.",
  DD_RULES_FAILING: "{0} of Modon's checks still fail · shown under the fields.",
  DD_RULES_FAILING_OTHER: "{0} of Modon's checks still fail:",
  DD_RULES_UNAVAILABLE: "Modon's checks could not run; the draft is checked again when saved.",
  DD_PROBLEMS: "Saved. Finance will need to fix these before sending:",
  DD_COMPUTED_ONE: "Covers milestone {0} · up to {1} · from {2} to {3}. Set by Modon's rules from the schedule, not typed here.",
  DD_FOOT: "Finance sends the draft to the bank. Collections start once the bank approves.",
  DD_VIEW_TITLE: "Direct Debit Request {0}",
  DD_VIEW_REQUESTED: "requested {0}",
  DD_VIEW_COVERS: "Covers milestones {0} to {1} · up to {2} per collection · from {3} to {4}",
  DD_LINK_NOTE: "The mandate was raised. The Sales Order's Direct Debit link could not be set: {0}",
  CTA_SUBMIT_MANDATE: "Submit mandate request",
  CTA_SUBMITTING_MANDATE: "Saving…",
  /* 1.93: the mandate card (c/mscMandateCard) */
  DDC_TITLE: "Direct Debit mandate {0}",
  DDC_STEP_RAISED: "Raised",
  DDC_STEP_FINANCE: "Finance",
  DDC_STEP_SIGNATURE: "Customer signature",
  DDC_STEP_BANK: "Bank",
  DDC_STAGE_LEGACY: "Requested",
  DDC_STAGE_DRAFT: "With Finance",
  DDC_STAGE_FINANCE_REJECTED: "Rejected by Finance",
  DDC_STAGE_PENDING: "Awaiting the customer's signature",
  DDC_STAGE_SENT: "Signed · with the bank",
  DDC_STAGE_ACTIVE: "Active",
  DDC_STAGE_BANK_REJECTED: "Rejected by the bank",
  DDC_STAGE_DISCARDED: "Discarded",
  DDC_STAGE_CANCEL_PENDING: "Cancellation requested · with Finance",
  DDC_STAGE_CANCEL_REQUESTED: "Cancellation requested · awaiting the customer",
  DDC_STAGE_CANCELLED: "Cancelled",
  DDC_NOTE_LEGACY: "Raised before the bank link. Finance handles it from the mandate record.",
  DDC_NOTE_DRAFT: "Finance reviews the draft and sends it to the bank.",
  DDC_NOTE_PENDING: "Sent to the bank on {0}. The customer signs in UAE PASS.",
  DDC_NOTE_SENT: "Signed on {0}. The bank usually answers within two working days.",
  DDC_NOTE_ACTIVE: "Bank reference {0}. Milestones are collected as they fall due.",
  DDC_NOTE_DISCARDED: "Discarded on {0}. A new mandate can be set up.",
  DDC_NOTE_CANCEL_PENDING: "Reason {0}. Finance sends the cancellation to the bank.",
  DDC_NOTE_CANCEL_REQUESTED: "Reason {0}. The customer accepts the cancellation in the UAE DDS app.",
  DDC_NOTE_CANCELLED: "A new mandate can be set up.",
  DDC_FACT_REFERENCE: "Bank reference",
  DDC_FACT_BANK_STATUS: "Bank status",
  DDC_FACT_SYNC: "Status checked",
  DDC_FACT_EMAIL: "Email",
  DDC_FACT_CITY: "City",
  DDC_DOCS: "Forms",
  DDC_DOC_UNSIGNED: "Mandate · unsigned",
  DDC_DOC_SIGNED: "Mandate · signed",
  DDC_DOC_CANCEL_UNSIGNED: "Cancellation form · unsigned",
  DDC_DOC_CANCEL_SIGNED: "Cancellation form · signed",
  DDC_DOC_NONE: "not on file yet",
  DDC_ACTIONS_OFF: "Refreshing, cancelling and fetching forms are done in Modon's Direct Debit app for now.",
  DDC_DISCARD_FINANCE: "Finance can still withdraw this mandate from Modon's Direct Debit app.",
  DDC_CANCEL_REASON: "Reason",
  DDC_CANCEL_COMMENT: "Note for Finance",
  DDC_CANCEL_HINT: "Finance approves the cancellation and sends it to the bank; the customer then accepts it in the UAE DDS app.",
  DDC_DISCARD_HINT: "The request is withdrawn from the bank. A new mandate can be set up afterwards.",
  DDC_WORKING: "Contacting the bank…",
  CTA_REFRESH_BANK: "Ask the bank now",
  DDC_REREAD: "Refresh",
  DDC_REREAD_HINT: "Last read {0}",
  CTA_DISCARD_MANDATE: "Discard",
  CTA_REQUEST_CANCELLATION: "Request cancellation",
  CTA_SEND_CANCELLATION: "Send cancellation request",
  CTA_CONFIRM_DISCARD: "Discard mandate",
  CTA_FETCH_FORM: "Fetch",
  CTA_SETUP_AGAIN: "Set up again",
  CTA_VIEW_FORM: "View",
  /* the C5 guard: a plan with no installment rows */
  LEDGER_PLAN_NO_SCHEDULE:
    "The selected payment plan has no milestone schedule, so this booking cannot be created. Choose another plan.",

  /* The hold, where the obligations are. LEDGER_HOLD_SAFE is journey 07's rule: money, not
     the hold, secures the unit. */
  /* MSC-153: why a finished step will not reopen */
  NAV_FLOOR_COMMITTED:
    "This booking is confirmed, so the earlier steps cannot be changed here.",
  NAV_FLOOR_COLLECTED:
    "A payment has been collected against this unit and plan, so they cannot be changed here. Sales Operations can move or refund a payment that has already been taken.",

  LEDGER_HOLD_LIVE: "Unit held",
  LEDGER_HOLD_GONE: "Hold expired",
  LEDGER_HOLD_SAFE: "Still reserved",
  LEDGER_HOLD_SAFE_NOTE:
    "The payment already received keeps this unit reserved. Collect the balance. There is no need to start again.",

  /* How a row is paid: only the terminal case needs saying */
  ROW_ROUTE_TERMINAL:
    "Collected at the Modon Pay terminal, both fees together, using Take payment above. Capture proof here only for a bank transfer or cheque.",
  /* 1.113 - the same row while the booking fee is paid by payment link */
  ROW_ROUTE_LINK:
    "Paid through the payment link sent to the customer. Capture proof here only for a bank transfer or cheque.",

  /* "Amount Received": the agent is recording money already handed over */
  /* the pay decision, in one place */
  PAY_TERMINAL_NOTE:
    "Payment is taken at the Modon Pay terminal, which opens in a new tab.",
  PAY_WATCHING: "This screen checks for the payment every few seconds.",
  PAY_WATCH_STOPPED:
    "The unit hold has lapsed, so this screen has stopped checking on its own. Check payment to bring it up to date.",
  PAY_CONFIRM_APPEARS:
    "Confirm Booking appears once the booking fee has been received.",

  /* Waiting, as a state rather than a dead button */
  PAY_WAIT_TITLE: "Waiting for the payment",
  PAY_WAIT_BODY:
    "The terminal is open in another tab. This screen checks every few seconds on its own, and Confirm Booking appears here the moment the payment lands.",
  PAY_WAIT_BODY_STOPPED:
    "This screen has stopped checking on its own. Use Check payment to bring it up to date.",
  /* Take payment keeps its label */
  PAY_REOPEN_HINT: "Take payment opens the terminal again and extends the hold.",
  /* PAY_HOLD_AGAIN is gone */

  /* A lapsed hold is two situations: with money collected the unit stays reserved */
  /* the button under these notes is "Hold and take payment" */
  PAY_LAPSED_OPEN:
    "Another agent can take this unit now. Press Hold and take payment to hold it again. Nothing is charged twice, and the amounts above do not change.",
  /* 1.110 - asked before Release unit, live or lapsed hold (the Sales App's Cancel booking prompt) */
  PAY_RELEASE_ASK: "Release the hold on this unit?",
  PAY_RELEASE_YES: "Release",
  /* 1.112 - unitSearchLwc's required tick before Generate sales order */
  RC_CONFIRM_ALL: "Confirm all selection",
  PAY_LAPSED_SAFE:
    "This unit stays reserved because a payment has been received against it. Press Hold and take payment to collect the balance. Nothing is charged twice.",

  /* What is left: one ordered list, money first. No entry for "nothing left". */
  TODO_TITLE: "Still to do",
  TODO_MONEY: "{0} outstanding on {1}",
  TODO_DOCS_ONE: "1 document still to be approved",
  TODO_DOCS: "{0} documents still to be approved",
  TODO_VERIFY_NONE: "Identity verification not started",
  TODO_VERIFY_WAIT: "Waiting for the customer to finish identity verification",
  TODO_VERIFY_EXPIRED: "The identity verification link has expired",
  TODO_VERIFY_DECLINED: "Identity verification was declined",
  /* the list navigates; it does not act */
  TODO_GO: "Open",

  /* The resume statement */
  RESUME_CONFIRMED_ON: "Confirmed {0}",
  /* MSC-096: RESUME_COLLECTED retired */
  /* the completion truth, in the org's own terms */
  RESUME_CLOSED: "This booking is closed",
  /* RESUME_CLOSED_SUB removed by request */

  /* LEDGER_SHOW_SETTLED / LEDGER_HIDE_SETTLED gone with the toggle */
  /* the per-unit heading a basket's ledger groups under */
  LEDGER_UNIT_OUTSTANDING_OF: "{0} of {1} outstanding",
  LEDGER_UNIT_SETTLED: "Settled",
  LEDGER_UNIT_UNNAMED: "Unit",

  BLOCK_AMOUNT_LABEL: "Amount Received",
  /* one line */
  /* BLOCK_AMOUNT_HINT retired */
  BLOCK_AMOUNT_OVER: "Cannot exceed the {0} still outstanding",

  /* the row form records a Payment: Modon's Create Receipt flow's labels */
  BLOCK_MODE: "Mode of payment",
  BLOCK_REFERENCE_CHEQUE: "Cheque Number",
  BLOCK_DATE: "Transaction Date",
  BLOCK_DATE_CHEQUE: "Cheque Date",
  BLOCK_BANK: "Customer Bank",
  BLOCK_DATE_FUTURE: "Cannot be in the future.",
  BLOCK_STILL_OPEN: "{0} still open · record the rest here",
  CTA_CREATE_PAYMENT: "Create Payment",
  BLOCK_RECORDED: "{0} · the row reads Settled once Finance approves it.",

  /* the proof region */
  PROOF_TITLE: "Proof of payment",
  PROOF_ATTACH: "Attach proof",
  PROOF_NONE: "No file attached yet.",
  /* the console's own attach control */
  PROOF_REQUIRED: "Attach the proof of payment before creating the payment.",
  /* MSC-194: phone and tablet have no picker - the camera is the only way in */
  PROOF_REQUIRED_CAMERA: "Photograph the proof of payment before creating the payment.",
  PROOF_ATTACHING: "Attaching {0}…",
  PROOF_TYPE: "Use a JPG, PNG or PDF.",
  PROOF_TOO_LARGE: "{0} is too large. Use a file up to 4 MB, or photograph it with the camera.",
  PROOF_FAILED: "{0} could not be attached. Try again.",
  PROOF_PENDING_HINT: "attached · not yet recorded",
  /* MSC-197: the cheque read on the main payment form. Cheque only - a transfer receipt is
     never sent to the model. */
  PROOF_READING: "Reading the cheque…",
  PROOF_READ_FILLED: "Read from the image · {0}.",
  PROOF_READ_MATCH: "Read from the image · {0}.",
  PROOF_READ_PLAIN: "Read from the image · {0}.",
  PROOF_READ_FAILED: "The cheque could not be read.",
  PROOF_READ_UNCLEAR: "The image is too unclear. Attach a clearer photo.",
  PROOF_READ_NOT_CHEQUE: "That image does not look like a cheque. Attach the cheque itself.",
  PROOF_READ_AGAIN: "Read again",
  /* MSC-200c: PROOF_READ_CONTEXT retired with the "Also on the image" line */
  /* MSC-200c: PROOF_CHEQUE_LOCKED retired - the form says it with the fields themselves */
  /* MSC-205: flags, not sentences. Red will be refused on submit; amber says look once. */
  CHQ_STALE: "Older than 6 months",
  CHQ_FAR: "Check the year",
  CHQ_WORDS: "Words differ",
  CHQ_PAYEE: "Payee not MODON",
  CHQ_BANK: "Bank differs",

  /* Who is buying. "Buying as", shared with mscCustomerInfo. */
  BUYER_TYPE: "Buying as",
  BUYER_INDIVIDUAL: "Individual",
  BUYER_ORGANISATION: "Organisation",

  /* The customer search: the row says what a click will do */
  /* MATCH_RESIDENCY removed with the search step's residency pills */
  MATCH_ONE: "Found 1 person",
  MATCH_MANY: "Found {0} people",
  MATCH_IS_CUSTOMER: "Already a customer. Click to book for them.",
  MATCH_IS_LEAD: "A lead. Click to qualify and continue.",
  /* {0} is documentWord */
  MATCH_NONE: "No one found with that {0}.",
  /* appended to MATCH_NONE; said before the button that creates the duplicate */
  MATCH_NONE_WARN:
    "Check the number before creating a new customer. They may already exist.",
  /* the second key, offered when the document found nobody; {0} is FIND_CONTACT_WORD */
  MATCH_NONE_TRY_CONTACT:
    "Try their {0} before adding a new customer. They may already be here.",
  MATCH_NONE_TRY_CONTACT_COMPANY:
    "Try the company's {0} before adding a new company. It may already be here.",
  /* the same caution after the contact key ran */
  MATCH_NONE_WARN_CONTACT:
    "Check the address or number before creating a new customer. They may already exist.",
  MATCH_NONE_WARN_CONTACT_COMPANY:
    "Check the address or number before adding a new company. It may already be here.",
  /* MSC-108: a company hit is a company */
  MATCH_ONE_COMPANY: "Found 1 company",
  MATCH_MANY_COMPANY: "Found {0} companies",
  /* the chip names the buyer */
  MATCH_CHIP_COMPANY: "Company",
  MATCH_CHIP_LEAD: "Lead",
  MATCH_CHIP_COMPANY_LEAD: "Company lead",

  /* MSC-111: find who we already have; matchedOn arrives as a code */
  /* the field's label when the contact key is asked for */
  /* the three keys on the segmented control; the search still matches both document fields */
  FIND_KEY_EID: "Emirates ID",
  FIND_KEY_PASSPORT: "Passport",
  FIND_KEY_CONTACT_SEG: "Email or mobile",
  /* placeholders, per key */
  FIND_EID_PLACEHOLDER: "784-XXXX-XXXXXXX-X",
  FIND_PASSPORT_PLACEHOLDER: "Passport number",
  /* mid-sentence, for MATCH_NONE's {0} */
  FIND_EID_WORD: "Emirates ID",
  FIND_PASSPORT_WORD: "passport number",
  FIND_CONTACT_LABEL: "Email or mobile",
  FIND_CONTACT_LABEL_COMPANY: "Email or phone",
  /* mid-sentence, lower case */
  FIND_CONTACT_WORD: "email or mobile",
  FIND_CONTACT_WORD_COMPANY: "email or phone",
  /* FIND_KEY_USE removed with the flip */
  /* not an example address: the demo autofill wrote @example.com onto real accounts */
  FIND_CONTACT_PLACEHOLDER: "Email, or mobile with country code",
  FIND_CONTACT_PLACEHOLDER_COMPANY: "Email, or phone with country code",
  /* the what-matched chip */
  MATCHED_EID: "Emirates ID",
  MATCHED_PASSPORT: "Passport",
  MATCHED_EMAIL: "Email",
  MATCHED_MOBILE: "Mobile",
  MATCHED_LICENCE: "Trade licence",
  MATCHED_UNIFIED: "Unified number",
  /* the chooser: opens only when more than one existing customer matched */
  CAND_TITLE: "Which customer is this?",
  CAND_FOUND: "{0} existing customers hold these details. Choose the right one.",
  /* CAND_NOTE and CAND_NONE_WARN retired */
  /* amber on a candidate row: a fact about the record */
  CAND_ROW_DOCS: "Identity documents need attention.",
  /* the escape hatch: createCustomer with forceCreate */
  CAND_NONE: "Continue With New Details",

  /* MSC-114: the address gap, said before the rep chooses */
  MATCH_ROW_ADDRESS: "This customer still needs an address.",
  MATCH_ROW_ADDRESS_COMPANY: "This company still needs its address or licence number.",

  /* {0} is the licence the row matched on */
  MATCH_ORG_LICENCE: "Trade licence {0}",
  /* who will sign, said before the click */
  MATCH_ORG_SIGNS: "{0} signs for this company",
  MATCH_ORG_SIGNS_MANY: "{0} people can sign for this company",
  MATCH_ORG_SIGNS_NONE: "No contact on file yet",
  /* {0} is documentWord; a company is not a "one" */
  MATCH_NONE_COMPANY: "No company found with that {0}.",
  /* the licence is recorded three ways, so say which form to type */
  MATCH_NONE_WARN_COMPANY:
    "Check the number exactly as printed on the licence before adding a new company. It may already be here.",
  /* moved out of mscConsole's markup */
  CTA_NEW_CUSTOMER: "New customer",
  CTA_NEW_COMPANY: "New company",
  /* not an example value: licences are held in two shapes */
  ORG_LICENCE_PLACEHOLDER: "As printed on the licence",

  /* MSC-108: who signs for the company, asked only where there is a choice.
     MSC-138: "primary contact", not "signatory": nobody has confirmed they can sign. */
  ORG_CONTACT_LEGEND_CONSOLE: "Primary contact",
  SIG_TITLE: "Who should we deal with at this company?",
  SIG_FIELD: "Primary contact *",
  SIG_FACT_LICENCE: "Trade licence",
  SIG_FACT_CONTACTS: "Contacts on file",
  SIG_FACT_ON_FILE: "{0} on file",
  SIG_PRIMARY_TAG: "first on file",
  SIG_OPTION_OTHER: "Someone else…",
  SIG_NOTE:
    "Their name, email and mobile go on the booking and on the compliance checks. The company's own details do not change.",
  SIG_CTA: "Continue",
  SIG_CTA_BUSY: "Continuing…",
  /* the create form for a company with no contact on file */
  /* MSC-139: asked on the create form, organisation only */
  SIG_IS_AUTHORISED: "Is Power of Attorney Contact",
  SIG_NEW_LEGEND: "New primary contact",
  SIG_NEW_NOTE:
    "This company is already on file. Add the person signing for it and the booking carries on.",

  /* Find customer waits for the whole number */
  EID_INCOMPLETE: "Enter the full 15-digit Emirates ID (784-XXXX-XXXXXXX-X) to search.",

  /* MSC-110: field labels for c/mscIdentityFields */
  /* 1.109: no asterisk here; c/mscIdentityFields adds one where MODON's rules owe the field */
  IDF_EID_LABEL: "Emirates ID",
  IDF_EID_EXPIRY_LABEL: "Emirates ID expiry",
  IDF_PASSPORT_LABEL: "Passport number",
  IDF_PASSPORT_ISSUE_LABEL: "Passport issue date",
  /* 1.107: optional since 27 Sep 2026 */
  IDF_PASSPORT_EXPIRY_LABEL: "Passport expiry",
  /* shape refusals, at the field */
  IDF_EID_SHAPE: "Enter the full 15-digit Emirates ID (784-XXXX-XXXXXXX-X).",
  IDF_PASSPORT_SHAPE: "Letters and numbers only, as printed in the passport.",
  IDF_EXPIRY_PAST: "The expiry date cannot be in the past.",
  IDF_ISSUE_FUTURE: "The issue date cannot be in the future.",
  /* why a stored value was not enough; {0} is the stored date */
  IDF_REASON_EID_EXPIRED: "The Emirates ID on file expired on {0}. Enter the renewed date.",
  IDF_REASON_PASSPORT_EXPIRED: "The passport on file expired on {0}. Enter the renewed date.",
  IDF_REASON_ISSUE_FUTURE: "The issue date on file is in the future. Enter the date printed in the passport.",

  /* the identity step */
  IDST_TITLE: "Check their identity documents first.",
  /* residency, asked here only: the record holds none */
  IDST_RESIDENCY_ASK: "UAE resident status *",
  IDST_RESIDENCY_WHY:
    "Modon holds no resident status for this customer. It decides which document is required.",
  /* IDST_NOTE removed; IDST_SIG_NOTE stays */
  IDST_SIG_NOTE:
    "These are the primary contact's own documents. They go on the booking and on the compliance checks.",
  IDST_FACT_CUSTOMER: "Customer",
  IDST_FACT_SIGNATORY: "Primary contact",
  /* MSC-160: the residency fact row */
  IDST_FACT_RESIDENCY: "UAE Residency Status",
  IDST_CTA: "Continue",
  IDST_CTA_BUSY: "Continuing…",

  /* Block_Special_Characters_In_Name, mirrored at the field */
  CREATE_NAME_INVALID:
    "First and last names can only contain letters. Correct them to continue.",

  /* My Leads' New lead form */
  LEAD_FORM_RESIDENCY: "UAE resident status *",
  LEAD_FORM_NATIONALITY: "Nationality *",
  LEAD_FORM_SELECT: "Select…",

  /* MSC-114: LEAD_QUEUED ({0} is Owner.Name), LEAD_PHONE_SHAPE, LEAD_DUP_CLOSED ({0} is the status) */
  LEAD_QUEUED:
    'This buyer already exists in Modon\'s records, so the lead was routed to "{0}" for review and will not appear in this list. Search their details and book against the existing customer instead.',
  LEAD_FORM_FOOT_NOTE: "Saved leads appear at the top of the list.",
  LEAD_PHONE_SHAPE: "Enter the mobile in international format, e.g. +9715XXXXXXXX.",
  LEAD_DUP_CLOSED: "You already had this lead - it was marked {0}. A new one may be routed for review.",
  /* MSC-211: said once when a qualified lead leaves the rep's book ({0} is the lead's name) */
  LEAD_HANDED_OVER:
    "{0} is qualified and has been handed to another sales associate, so the lead has left your list.",

  /* the create form's contact checks, same words as c/mscEoiJourney */
  CONTACT_EMAIL_INVALID: "Please enter a valid email address.",
  CONTACT_EMAIL_UNCHECKED: "Unable to validate the email address right now.",
  CONTACT_PHONE_SHAPE: "Mobile must start with + and contain digits only (e.g. +971501234567).",
  CONTACT_PHONE_INVALID: "Please enter a valid mobile number.",
  CONTACT_PHONE_UNCHECKED: "Unable to validate the mobile number right now.",
  /* {0} is "email address", "mobile number", or both */
  CONTACT_FIX_ABOVE: "Check the {0} above before continuing.",

  // The company
  ORG_SECTION: "Company details",
  ORG_NAME: "Company name",
  ORG_NAME_HINT: "As printed on the trade licence",
  ORG_LICENCE_NO: "Licence number",
  /* the official alias (Unified Number), said once under the field */
  ORG_LICENCE_NO_HINT: "Also recorded as the company's Unified Number",
  ORG_LICENCE_EXPIRY: "Licence expires",
  ORG_FORMED_ON: "Date the company was formed",
  ORG_TYPE: "Type of company",
  ORG_ACTIVITY: "What the company does",
  ORG_VAT: "VAT number",
  ORG_VAT_HINT: "Only if the company is registered for VAT",
  ORG_ADDRESS: "Company address",
  ORG_CONTACT_LEGEND: "Primary contact",
  ORG_PERSON_LEGEND: "Customer",

  // the licence itself
  ORG_LICENCE_DOC: "Trade licence",
  ORG_LICENCE_HINT:
    "Upload the licence and we will fill in the company details for you. This is also what releases the booking for its checks.",
  ORG_LICENCE_VERIFIED: "Verified",
  /* short enough for a chip */
  ORG_LICENCE_READING: "Uploaded",
  ORG_LICENCE_NONE: "Not uploaded",
  ORG_LICENCE_UPLOADING: "Uploading...",
  ORG_LICENCE_CHOOSE: "Choose a file",
  ORG_LICENCE_UNREADABLE: "That file could not be read.",

  /* ORG_OWNER* retired with the shareholder form */

  ORG_OUTSTANDING: "Still needed before checks can start",

  /* non-UAE companies: say what to do instead of failing at insert */
  ORG_NON_RESIDENT_BLOCKED:
    "Companies based outside the UAE are booked by Sales Operations rather than here. Please pass this customer to them.",

  // Customer / residency
  RESIDENCY: "Residency",
  RESIDENT: "UAE Resident",
  NON_RESIDENT: "Non-Resident",

  /* the offer drawer: "Preview offer" names the document */
  OFFER_OPEN: "Preview offer",
  /* one word, with the unit and project as the subtitle */
  OFFER_TITLE: "Offer",
  OFFER_NEEDS_UNIT: "Choose a unit to quote for.",
  OFFER_NEEDS_PLAN: "Choose a payment plan. The offer prices it.",
  OFFER_ADDRESS_TO: "Address the offer to",
  OFFER_ADDRESS_HINT: "Leave blank to use the customer's account name",
  OFFER_SEND: "Email offer",
  OFFER_SENDING: "Sending…",
  /* MSC-225: opens WhatsApp on the customer's number. It sends nothing. */
  OFFER_WHATSAPP: "WhatsApp",

  /* "Edit" rather than "Expand" */
  CUSTOMER_EDIT: "Edit details",
  /* CUSTOMER_VIEW_ALL removed */
  CUSTOMER_FOLD: "Hide details",
  RESIDENT_HINT: "Emirates ID required. Direct Debit available for milestones.",
  NON_RESIDENT_HINT:
    "Passport required. International transfers take 2-3 working days.",

  /* MSC-112: the Customer Information card; amber only where an org rule is the reason */
  /* shown only when something is missing */
  /* MSC-137: the verification block on the card */
  CUST_VERIFY_TITLE: "Verification details",
  CUST_VERIFY_LEDE: "Needed before the KYC link and for compliance. None of it holds up this booking.",
  CUST_VERIFY_COUNT: "{0} still needed",
  CUST_VERIFY_DONE: "All captured",
  CUST_GATE_NEEDED: "needed to continue",
  CUST_FACT_LICENCE: "Licence",
  CUST_FACT_SIGNATORY: "Contact",

  CUST_ON_FILE_NOTE:
    "Some details are missing. Add them below. Everything else is already on Modon's file and can only be changed by Sales Operations.",
  CUST_WHY_IDENTITY: "Only Sales Operations can change a saved Emirates ID or passport.",
  CUST_WHY_RESIDENCY: "Residency is set on this booking. Only Sales Operations can change it.",
  CUST_WHY_NAME: "Modon locks a saved contact's name. Ask Sales Operations to correct it.",
  CUST_WHY_NO_SIGNATORY: "Choose the company's primary contact first - these details belong to them.",
  /* the AML declaration: asked, never assumed; never blocks Save */
  CUST_REAL_BEN: "Real beneficiary",
  CUST_REAL_BEN_Q: "Is the signatory the real beneficiary of this purchase?",
  CUST_REAL_BEN_YES: "Yes",
  CUST_REAL_BEN_NO: "No",
  CUST_REAL_BEN_HINT: "Modon must record who ultimately benefits from this transaction.",
  /* the disabled Continue's sentence when residency is blank */
  CUST_NEEDS_RESIDENCY: "Choose the customer's nationality and resident status to continue.",
  /* field labels; the * marks stay in the template */
  CUST_FIRST_NAME: "First Name",
  CUST_LAST_NAME: "Last Name",
  CUST_EMAIL: "Email",
  CUST_MOBILE: "Mobile",
  CUST_NATIONALITY: "Nationality",
  /* MODON's own label and values for UAE_Resident_Status__pc */
  CUST_RESIDENT_STATUS: "UAE Resident Status",
  CUST_EID: "Emirates ID",
  CUST_PASSPORT: "Passport number",
  CUST_COUNTRY_RES: "Country of residence",
  CUST_EID_EXPIRY: "Emirates ID expiry",
  CUST_PASSPORT_ISSUE: "Passport issue date",
  CUST_PASSPORT_EXPIRY: "Passport expiry",
  /* the registered address is read-only here; c/mscAddress owns it */
  CUST_EDIT_ADDRESS: "Edit address",
  CUST_ADDRESS_NONE: "No address on file yet - add it below.",
  CUST_ADDRESS_INCOMPLETE:
    "The registered address is incomplete - add the missing lines below.",
  /* folded-summary row labels */
  CUST_F_NAME: "Name",
  CUST_F_PASSPORT: "Passport",
  /* error sentences; date sanity reuses IDF_EXPIRY_PAST / IDF_ISSUE_FUTURE */
  CUST_E_REQUIRED: "Required.",
  CUST_E_EMAIL: "Enter a valid email address.",
  CUST_E_RESIDENCY: "Select a residency to continue.",
  CUST_E_EID: "Required for UAE residents.",
  CUST_E_PASSPORT: "Required for non-residents.",
  CUST_E_DOE: "Required - compliance is rejected without it.",

  // Identity verification
  KYC: "Identity verification", // was "KYC"
  COMPLIANCE: "Verification", // was "Compliance check"

  // the four links; the wording says whose turn it is
  KYC_STEP_SENT: "Link sent",
  KYC_STEP_DONE: "Customer verification",
  KYC_STEP_SUBMITTED: "Submitted to compliance",
  KYC_STEP_APPROVED: "Cleared",

  KYC_SEND: "Send verification link",
  KYC_RESEND: "Resend link",
  KYC_WAITING:
    "Waiting for the customer to complete identity verification. Once they do, " +
    "check their details and send them for compliance.",
  KYC_NOT_SENT:
    "The customer has not been sent an identity verification link yet.",
  KYC_EXPIRED:
    "This customer's identity verification has expired and needs to be done again.",
  KYC_SUBMITTED:
    "Identity verified. Compliance checks are running - this usually takes a day or two.",
  KYC_APPROVED: "Compliance cleared.",
  /* a sent link is the rep's part done */
  KYC_SENT_DONE:
    "KYC link sent. Verification is complete from your side: the customer finishes it on " +
    "their phone, and you send them for compliance once they do.",
  KYC_REJECTED: "Compliance declined this customer. Sales Operations will be in touch.",
  KYC_RESUBMIT: "Compliance needs more from this customer before it can continue.",
  /* the truth about a company: proved by the signed KYC & Wealth Form and by Passfort */
  KYC_CORPORATE:
    "Identity for a company is proved by the signed KYC and Wealth Form and by " +
    "Passfort. There is no verification link for a company.",
  /* MSC-174: inside the company workspace when opened from My Bookings */
  OP_CHECK_ON_JOURNEY:
    "Resume the booking to run the compliance check for the signatory.",
  KYC_BLOCKED_TITLE: "Cannot send the link yet",
  KYC_ATTEMPT_TITLE: "Last compliance attempt",
  KYC_LINK_SENT: "Verification link sent to the customer.",
  KYC_REFRESH: "Check for the latest status",
  KYC_REFRESHING: "Checking...",

  /* Signzy Phase 2: c/mscKycGate, the PRE-booking KYC panel in step 2.
     Short by intention - the panel reports a state, it does not explain a policy. */
  KYCG_S_VERIFIED: "Verified",
  KYCG_S_EXPIRED: "Expired",
  KYCG_S_DOCUMENTS: "Documents outstanding",
  KYCG_S_AWAITING: "Pending approval",
  KYCG_S_INCOMPLETE: "Not verified",
  /* {0} completed, {1} valid until - three calendar months, per the Account formula */
  KYCG_B_VERIFIED: "Verified {0}. Active until {1}.",
  /* the manual route sets no completion date, so it carries no expiry to quote */
  KYCG_B_VERIFIED_MANUAL: "Approved manually.",
  KYCG_B_EXPIRED: "Verified {0}. Validity ended {1}.",
  KYCG_B_DOCUMENTS: "Identity is verified. These still need a file on record:",
  KYCG_B_AWAITING: "Waiting for manual KYC approval.",
  KYCG_LINK_LABEL: "Digital KYC link",
  KYCG_LINK_SENT: "Sent {0}",
  KYCG_LINK_EXPIRED: "Expired",
  KYCG_LINK_NOT_SENT: "Not sent",
  KYCG_LINK_SENDING: "Sending",
  KYCG_B_WITHDRAWN: "Request withdrawn on {0}. Send it again.",
  KYCG_B_WITHDRAWN_NONE: "No approval request is open. Send it again.",
  KYCG_B_INCOMPLETE: "Identity verification has not been completed.",
  /* Phase 2 says so plainly rather than letting a status panel imply a block. */
  KYCG_ADVISORY: "For information - this does not hold up the booking.",

  /* Signzy Phase 3: the same panel becomes the ACTIVE pre-booking KYC workspace.
     The digital link states below come from SalesConsoleController.getComplianceState
     (NOT_SENT / SENT / EXPIRED / VERIFIED / IN_BRANCH) - they are the org's own states,
     not new ones. Wording stays short: a status, a subject, and what to press. */
  KYCG_S_NOT_STARTED: "Not started",
  KYCG_S_WAITING: "Waiting",
  KYCG_S_LINK_EXPIRED: "Link expired",
  KYCG_S_IN_BRANCH: "In branch",
  /* SC-UI-008: an approved manual route is the customer's actual route, so it gets its own
     headline instead of being reported as the digital state "Not started". */
  KYCG_S_MANUAL_APPROVED: "Manual KYC approved",
  KYCG_B_MANUAL_APPROVED: "Approved manually. Complete the KYC details below.",
  KYCG_B_NOT_STARTED: "No verification link has been sent yet.",
  KYCG_B_WAITING: "Waiting for the customer to complete verification.",
  KYCG_B_LINK_EXPIRED: "The link expired before it was completed. Send it again.",
  KYCG_B_IN_BRANCH: "Verification was released to the branch.",
  /* who is being verified. For a company this is the authorised POA Contact - the
     person Signzy actually verifies - never the company itself. */
  KYCG_SUBJ_BUYER: "Buyer",
  KYCG_SUBJ_POA: "POA",
  /* {0} the moment the link went out */
  KYCG_SENT_ON: "Link sent {0}",
  /* actions. Each maps to a method that already exists; none is new behaviour. */
  KYCG_A_SEND: "Send KYC",
  KYCG_A_RESEND: "Resend link",
  KYCG_A_SEND_LINK: "Send link",
  KYCG_A_REFRESH: "Refresh",
  KYCG_A_WORKING: "Working...",
  /* MODON's own refusal is shown verbatim where there is one; this is the fallback. */
  KYCG_CANNOT_SEND: "The verification link cannot be sent yet.",
  KYCG_SEND_FAILED: "That did not go through. {0}",
  KYCG_SENT_OK: "Verification link sent.",
  KYCG_REFRESHED: "Status checked.",
  /* the manual route, offered under the digital one rather than beside it */
  /* Phase 4: the one phrase beside a disabled Continue. Never a paragraph, never a banner. */
  KYCG_BLOCKS_CONTINUE: "KYC required before payment.",
  KYCG_MANUAL_OPEN: "Manual KYC",
  KYCG_MANUAL_CLOSE: "Close",

  /* Signzy Phase 3: c/mscManualKyc. The three answers MODON's quick action already asks for,
     in its own order. No field is marked with an asterisk - the rule is stated once. */
  /* 1.106 - booking: facade style and pre-approval number (engine 17.0 / 19.0) */
  BOOK_FACADE: "Facade style",
  BOOK_FACADE_PICK: "Choose a facade style",
  BOOK_FACADE_NONE: "No Facade Style is configured for this phase. Booking is not allowed.",
  BOOK_FACADE_MISSING: "Please select a Facade Style for unit {0}.",
  BOOK_PREAPPROVAL: "Pre-approval number",
  /* 1.108 - the unit option; the refusal is the Sales App's own sentence */
  BOOK_OPTION: "Unit option",
  BOOK_OPTION_PICK: "Select an option",
  BOOK_OPTION_MISSING: "Unit option is not selected for {0} unit.",
  /* 1.110 - the EOI, chosen by the rep where more than one fits the unit; the refusal is the Sales App's */
  BOOK_EOI: "EOI",
  BOOK_EOI_PICK: "Select an EOI",
  BOOK_EOI_ON: "on {0}",
  BOOK_EOI_MISSING: "Please select an EOI for unit: {0}",
  BOOK_EOI_NONE: "Not chosen",
  BOOK_PREAPPROVAL_FROM_EOI: "From the EOI",
  BOOK_PREAPPROVAL_MISSING: "Pre-Approval Number is required for pre-approval payment plan {0} (unit {1}).",
  MKYC_TITLE: "Manual KYC",
  MKYC_REASON: "Reason",
  MKYC_REASON_PICK: "Choose a reason",
  MKYC_COMMENT: "Comment",
  MKYC_ATTACHMENT: "Supporting document (optional)",
  MKYC_FILE_PICK: "Choose a file",
  MKYC_UPLOAD: "Upload",
  MKYC_ALL_REQUIRED: "A reason and a comment are required.",
  /* 1.88 - the company route: whose details the approval is about, and where it lands */
  MKYC_SUBJ_POA: "POA",
  MKYC_SUBJ_COMPANY: "Company",
  MKYC_STILL_NEEDED: "Still needed before compliance can approve:",
  MKYC_SUBMIT: "Submit for approval",
  MKYC_WORKING: "Submitting...",
  MKYC_DONE: "Submitted for manual KYC approval.",
  /* 1.87 - {0} is MODON's title for the file, "Manual KYC - dd-MM-yyyy HH:mm:ss.pdf" */
  MKYC_UPLOADED: "Uploaded: {0}",

  /* Signzy Phase 3B: c/mscKycCapture - what happens AFTER a manual KYC is approved.
     One status word, one sentence, and at most three controls. */
  KYCC_S_PENDING: "Manual KYC pending",
  KYCC_S_REJECTED: "Manual KYC rejected",
  KYCC_S_APPROVED: "Manual KYC approved",
  KYCC_S_GENERATING: "Form requested",
  /* 1.103 - the PDF is on the record; the signed copy is not back yet */
  KYCC_S_GENERATED: "Form generated",
  KYCC_S_SIGNED: "Signed form received",
  /* 1.104 - Document_Status__c reached Error: the attempt ran and did not produce a form */
  KYCC_S_FAILED: "Form not generated",
  /* 1.104 - a status outside MODON's four values. Named, never guessed at. */
  KYCC_S_UNCLEAR: "Form status unclear",
  KYCC_B_PENDING: "The manual submission is with Sales Operations.",
  KYCC_B_REJECTED: "The manual submission was not approved.",
  KYCC_B_REJECTED_ON: "Rejected {0} by {1}.",
  KYCC_B_APPROVED: "Update the customer's KYC details, then generate the form for signature.",
  /* 1.89 - a company never sees Generate; its sentence stops at the details */
  KYCC_B_APPROVED_ORG:
    "Update the signatory's and the company's KYC details, then generate the form for signature.",
  KYCC_B_GENERATING: "The form is being generated and sent for signature.",
  /* 1.103 - true whether or not the DocuSign auto send is on: the form exists, the signature is not back */
  KYCC_B_GENERATED: "Waiting for the signed form.",
  /* 1.116 - after a regeneration: MODON's booking check still accepts the earlier signed form */
  KYCC_B_GENERATED_EARLIER: "Waiting for the new signed form. The earlier signed form is on record.",
  KYCC_B_SIGNED: "The signed form is on record.",
  /* 1.104 - factual, and it promises no retry: who re-runs a failed render is MODON's to say */
  KYCC_B_FAILED: "The last attempt to produce the form did not succeed.",
  /* 1.104 - {0} is the value on the record, quoted so it reads as a value and not as our wording */
  KYCC_B_UNCLEAR: "The form record reads \u201c{0}\u201d.",
  KYCC_UPDATE: "Update KYC",
  KYCC_CLOSE: "Close",
  KYCC_SAVE: "Save",
  KYCC_GENERATE: "Generate KYC form",
  KYCC_REFRESH: "Refresh",
  KYCC_SAVED: "Details saved.",
  KYCC_REQUESTED: "KYC form requested.",
  /* Option B: the console links to the signed Salesforce file rather than embedding
     loadsignedkycform, which resolves its record from a URL parameter it never receives here. */
  /* 1.116 - UI-27: the file servlet downloads, so the link says so */
  KYCC_VIEW_SIGNED: "Download signed form",
  /* 1.88 - B8: the gate's one sentence under a disabled Generate; B4: the modal replaces the
     inline renderer. KYCC_INLINE_FORM keeps the old renderer reachable for one release. */
  KYCC_GENERATE_OFF: "Generate is unavailable: {0}",
  /* 1.90 - feedback while Nintex renders (twenty seconds or more) */
  KYCC_GENERATING_BTN: "Generating…",
  KYCC_GENERATING_NOTE: "Producing the form. This can take half a minute.",
  /* 1.105 - the same control, worded for a second attempt (c/mscKycCapture 2.10) */
  KYCC_RETRY: "Try again",
  KYCC_RETRYING_BTN: "Trying again…",
  KYCC_MISSING_INTRO: "Complete these in Update KYC before generating:",
  /* 1.102 - the identity documents are uploaded, not typed into Update KYC. Own heading, own list. */
  KYCC_MISSING_FILES_INTRO: "Files to upload:",
  KYCC_INLINE_FORM: false,

  /* 1.88 - B4: c/mscKycCaptureModal, hosting MODON's own Update KYC form. */
  KYCM_TITLE: "Update KYC",
  KYCM_CLOSE: "Close",

  /* 1.88 - B5: c/mscKycDocuments, the required-documents checklist. */
  KYCD_TITLE: "Documents",
  KYCD_COUNTER: "{0} of {1}",
  KYCD_UPLOADED: "Uploaded {0}",
  KYCD_UPLOADED_NODATE: "Uploaded",
  KYCD_MISSING: "Missing",
  KYCD_NO_ROW: "No document record",
  KYCD_FROM_SIGNING: "Arrives from signing",
  KYCD_OR: "or",
  /* 1.116 - UI-27: the file servlet downloads, it cannot preview on the site */
  KYCD_VIEW: "Download",
  KYCD_UPLOAD: "Upload",
  KYCD_UPLOADING: "Uploading...",
  KYCD_TOO_LARGE: "That file is too large. The limit is 4 MB.",
  KYCD_READ_FAILED: "The file could not be read.",
  KYCD_ALL_PRESENT: "All documents are on record.",
  KYCD_NEEDED_BEFORE_PAYMENT: "All {0} are needed before payment.",
  /* 1.116 - UI-28: the Add Joint Owner drawer; MODON's joint owner check refuses the add without them */
  KYCD_NEEDED_BEFORE_ADDING: "All {0} are needed before they can be added.",
  KYCD_ROLE_BUYER: "Buyer",
  KYCD_ROLE_OWNER: "Joint owner",
  KYCD_ROLE_SIGNATORY: "Signatory",
  KYCD_ROLE_COMPANY: "Company",

  /* 1.88 - B10: the Offer control stays in the code but off the screen. */
  OFFER_ENABLED: false,

  /* the compliance check (MSC-069); no vendor named */
  COMPLIANCE_CTA: "Verify and submit to compliance",
  COMPLIANCE_CHECK: "Compliance Submission",
  COMPLIANCE_CHECKING: "Loading customer details…",
  COMPLIANCE_READY: "Ready",
  COMPLIANCE_KYC_DONE: "Identity verified",
  COMPLIANCE_DOCUMENTS: "Documents",
  COMPLIANCE_CONTEXT: "Transaction Details",
  COMPLIANCE_DOCS_NOTE:
    "These come from the customer's identity verification. Ask the customer to finish it, " +
    "or contact Sales Operations.",
  COMPLIANCE_SENT: "Sent for compliance.",
  /* one wording for anything the identity verification owns */
  COMPLIANCE_NOT_RECEIVED: "Not received yet",
  COMPLIANCE_VERIFIED: "Identity Verification",
  /* the two halves of the panel */
  COMPLIANCE_REFRESH: "Refresh",
  COMPLIANCE_REFRESHING: "Refreshing…",
  COMPLIANCE_UNSAVED: "Save your changes before submitting",
  /* what each button is waiting for */
  COMPLIANCE_SAVE_HINT: "Save what you have changed",
  COMPLIANCE_NOTHING_TO_SAVE: "Nothing has changed yet",
  COMPLIANCE_SAVING_HINT: "Saving your changes…",
  COMPLIANCE_SENDING_HINT: "Sending to compliance…",
  COMPLIANCE_BUSY_HINT: "Please wait for the last action to finish",
  COMPLIANCE_SUBMIT_HINT: "Send this customer to compliance",
  COMPLIANCE_SUBMIT_HELD: "Compliance still needs more before this can be sent",
  COMPLIANCE_VERIFIED_NOTE:
    "These come from the customer's identity verification and cannot be changed here. " +
    "Ask the customer to finish it, or contact Sales Operations.",

  // Documents
  DOCS_REQUIRED: "Further Documents Required",
  DOCS_COMPLETE: "All documents received",
  DOCS_OUTSTANDING: "outstanding",
  /* "Your checklist": only the items this rep owns */
  DOCS_YOUR_CHECKLIST: "Your checklist",
  /* "approved", not "complete" */
  DOCS_PROGRESS: "{0} of {1} approved",
  DOCS_RECEIVED: "Approved",
  DOCS_AND: "and",
  DOCS_LATER:
    "{0} further checks by {1} once this booking is handed over.",

  // Empty states
  EMPTY_UNIT: "Choose a unit to see pricing.",
  EMPTY_CUSTOMER: "Add customer details to continue.",
  EMPTY_PLAN: "Select a payment plan to see the schedule.",

  /* MSC-173: the payment plan filter; PLAN_FILTER_PH names what the field matches */
  PLAN_FILTER_PH: "Search payment plans by name or type",
  PLAN_FILTER_CLEAR: "Clear search",
  PLAN_FILTER_CLOSE: "Close",
  /* tooltip on the collapsed row */
  PLAN_CHANGE_HINT: "Change payment plan",
  /* the x on the chosen plan: "Clear" */
  PLAN_CLEAR_HINT: "Clear and choose another plan",
  /* both counts, always */
  PLAN_FILTER_COUNT: "{0} of {1} plans",
  PLAN_FILTER_ALL: "{0} payment plans",
  PLAN_FILTER_ONE: "1 payment plan",
  PLAN_FILTER_NONE: "No payment plans match \u201c{0}\u201d.",
  /* shown when the chosen plan is not in the filtered list */
  PLAN_FILTER_HIDDEN: "Selected: {0}",
  /* the milestone count */
  PLAN_MILESTONES: "{0} milestones",
  PLAN_MILESTONE_ONE: "1 milestone",
  /* EMPTY_PAYMENT removed */

  /* the summary rail shows all five groups at every step, so two more empty states */
  EMPTY_AMOUNTS: "Amounts appear once a unit and a plan are chosen.",
  /* EMPTY_PAYMENTS removed */
  /* the masthead's own two, before commit */
  SUMMARY_NOT_BOOKED: "Not yet booked",
  /* MSC-177: the payment summary's refresh */
  PAY_REFRESH: "Refresh",
  PAY_REFRESH_HINT:
    "Re-read the payments and the settlement figure from Salesforce.",
  PAY_REFRESHING: "Refreshing\u2026",
  PAY_REFRESH_FAILED:
    "The payment summary could not be refreshed. The figures below are unchanged - try again in a moment.",
  /* MSC-176: the rail's org row, "Company" */
  SUMMARY_COMPANY: "Company",
  SUMMARY_DRAFT: "Draft",
  SUMMARY_VERIFICATION: "Identity verification",
  SUMMARY_UNIT_ONE: "1 unit",
  SUMMARY_UNITS_N: "{0} units",
  SUMMARY_PLANS_CHOSEN: "{0} of {1} plans chosen",
  /* the two ladders counted separately */
  SUMMARY_PAID_OF: "{0} of {1} paid",
  SUMMARY_PAID_OF_DUE: "{0} of {1} due paid",
  SUMMARY_SCHEDULED_N: "{0} scheduled",
  SUMMARY_NOTHING_DUE: "Nothing due yet",
  /* a basket resumes as one unit; the rail says so */
  SUMMARY_BOOKING_COVERS: "This booking covers {0} units",
  /* one order of a multi-unit booking opened alone */
  SUMMARY_ONE_OF: "One of {0} units on this booking",
  SUMMARY_OPEN_SIBLING: "Open {0}",
  SUMMARY_SHOWING_ONE: "Showing {0}. Open the others from Total Sales.",
  SUMMARY_COLLECTED_OUTSTANDING: "{0} collected · {1} outstanding",
  /* the rail once the booking is confirmed */
  SUMMARY_LEFT: "Still to collect",
  SUMMARY_FEE_IN_FULL: "Booking fee collected in full",
  SUMMARY_FEE_PART: "{0} of the booking fee collected",
  SUMMARY_PAYMENTS_SCHEDULED: "{0} payments scheduled",
  SUMMARY_PAYMENT_SCHEDULED: "1 payment scheduled",
  SUMMARY_ADM_CHARGE: "ADM + Dari",

  /* The focus line: only the states nothing else had a sentence for. The five "ready" lines
     are deleted. */
  FOCUS_CHOOSE_UNIT: "Choose a unit to begin.",
  FOCUS_VERIFY_DECLINED: "Verification was declined. This booking cannot complete.",
  /* FOCUS_HOLD and FOCUS_HOLD_LAPSED are gone */
  /* FOCUS_DOCS is gone */
  FOCUS_VERIFY_WAIT: "Waiting on the customer to finish verifying.",

  /* the rail */
  /* RAIL_TOUR / RAIL_SUMMARY removed */
  // sits in the rail before anything is chosen
  /* RAIL_HINT / RAIL_HINT_NO_TOUR removed */
  /* MSC-163: the dismiss control on a page banner */
  BANNER_DISMISS: "Dismiss",
  /* MSC-168: the Verification step of a booking with no Sales Order yet */
  VERIFY_AWAIT_DONE:
    "Verification is complete for {0}. Confirm the booking to attach joint owners and documents.",
  VERIFY_AWAIT_SENT:
    "The verification link has been sent to {0}. Confirm the booking to attach joint owners and documents.",
  VERIFY_AWAIT_PLAIN:
    "Confirm the booking to attach joint owners and documents.",
  BASKET_TITLE: "Selected Units",
  BASKET_TOTAL: "Total",
  /* chip on a basket row with no plan yet: "Pending" */
  BASKET_NO_PLAN: "Pending",

  /* three steps, not six */
  // the six sections grouped into three
  SECTION_DETAILS: "Customer & Payment Plan",
  SECTION_SETTLE: "Payment & Confirm",
  /* step 4: "Verification" */
  SECTION_VERIFY: "Verification",
  /* 1.115: the step tabs' names where the full ones do not fit (800, 956) */
  SECTION_UNIT_SHORT: "Unit",
  SECTION_DETAILS_SHORT: "Customer & Plan",
  SECTION_SETTLE_SHORT: "Payment",
  VERIFY_ASIDE: "Available once the booking is confirmed",

  /* MSC-081: JOINT OWNERS, in Modon's own words (field, object and picklist labels, Service
     Request types). Picklist options and server-written sentences are not here. */

  JO_EYEBROW: "Ownership",
  JO_ADD: "Add Joint Owner",
  JO_EDIT: "Edit",
  JO_CANCEL: "Cancel",
  JO_SAVE: "Save Changes",
  JO_SAVING: "Saving…",

  /* the head chip */
  JO_CHIP_SOLE: "Sole owner",
  JO_CHIP_OWNERS_ONE: "1 owner",
  JO_CHIP_OWNERS: "{0} owners",
  JO_CHIP_OWNERS_UNITS: "{0} owners · {1} units",
  JO_CHIP_UNCOVERED_ONE: "1 unit without a joint owner",
  JO_CHIP_UNCOVERED: "{0} units without a joint owner",
  JO_CHIP_LOCKED: "Locked",

  /* a person's row */
  JO_ROLE_PRIMARY: "Primary Owner",
  JO_ROLE_JOINT: "Joint Owner",
  /* the meter key when nobody else is on the unit */
  JO_HOLDS: "{0} holds {1}%",
  JO_ON_ALL_UNITS: "On all {0} units",
  JO_ON_UNITS: "On {0}",
  /* the verification chip is per person */
  JO_VERIFIED_ON: "Verified {0}",
  JO_VERIFY_NOT_SENT: "Verification not sent",
  /* a row a colleague created that sharing will not let this rep change */
  JO_ROW_LOCKED: "Added by another user",

  /* the footer */
  JO_EMPTY: "No joint owners have been added.",

  /* the unit strip */
  JO_UNIT_NONE: "No joint owner",
  JO_UNIT_ONE: "1 joint owner · {0}% allocated",
  JO_UNIT_MANY: "{0} joint owners · {1}% allocated",
  JO_UNIT_LOCKED: "Locked",
  /* reported, not hidden */
  JO_UNIT_HIDDEN_ONE: "1 owner not visible to you",
  JO_UNIT_HIDDEN: "{0} owners not visible to you",

  /* the drawer */
  JO_DRAWER_ADD: "Add Joint Owner",
  JO_DRAWER_EDIT: "Edit Joint Owner",
  JO_STEP_IDENTIFY: "Identify the Joint Owner",
  JO_STEP_DETAILS: "Joint Owner Details",
  JO_STEP_OWNERSHIP: "Ownership & Relationship",
  JO_STEP_UNITS: "Apply to Units",

  JO_F_RESIDENT_STATUS: "Resident Status",
  JO_F_EID: "Emirates ID Number",
  JO_F_PASSPORT: "Passport Number",
  /* MSC-180: the drawer's two kinds of party */
  JO_KIND_LABEL: "Joint Owner Type",
  JO_KIND_PERSON: "Individual",
  JO_KIND_COMPANY: "Company",
  JO_F_TRADE_LICENCE: "Trade Licence Number",
  JO_F_TL_HINT:
    "We search for an existing company account before creating a new one.",
  JO_F_COMPANY_NAME: "Company Name",
  /* what the console does not do for a company */
  JO_F_COMPANY_HINT:
    "The company is created with this name and the licence number above. " +
    "Its compliance is handled by Sales Operations from the account record.",
  JO_NOT_FOUND_COMPANY:
    "No company account found for {0}. Enter the company name below.",
  /* search before create */
  JO_F_ID_HINT: "We search for an existing account before creating a new one.",
  JO_SEARCH: "Search",
  JO_SEARCHING: "Searching…",
  JO_FIND_FIRST: "Identify the joint owner to continue",
  JO_FOUND_CHIP: "Existing account",
  /* 1.116 - UI-30: the person was just created in this drawer */
  JO_NEW_CHIP: "New account",
  JO_SEARCH_AGAIN: "Search again",
  JO_NOT_FOUND: "No account found for {0}. Enter their details below.",

  JO_F_FIRST_NAME: "First Name",
  JO_F_LAST_NAME: "Last Name",
  JO_F_EMAIL: "Email",
  JO_F_MOBILE: "Mobile",
  JO_F_NATIONALITY: "Nationality",
  /* mandatory: SendEnvelope refuses the whole envelope on a blank resident status */
  JO_F_RESIDENT_HINT:
    "Required. The SPA cannot be sent for signature without it.",

  JO_CHOOSE: "Select…",
  JO_F_REL_TYPE: "Relationship Type",
  JO_F_REL_SUBTYPE: "Relationship Sub Type",
  JO_F_OWNERSHIP: "Ownership %",
  JO_F_OWNERSHIP_ALL: "Ownership % on every unit they hold",
  /* 1.116 - R2-12: MODON refuses joint owners who together reach 100% (JointOwnerTriggerHelper), so the
     buyer always keeps a share; said plainly */
  JO_OWNERSHIP_HINT: "{0} would hold {1}%. Joint owners together must hold less than 100%.",
  JO_OWNERSHIP_OVER: "Joint owners together must hold less than 100%, so the buyer keeps a share.",
  JO_OWNERSHIP_APPLIES: "Applies to {0}.",

  JO_UNITS_ALL: "Select all",
  JO_UNITS_UNCOVERED: "Only units without a joint owner",
  JO_UNITS_CLEAR: "Clear",
  JO_UNITS_SAME_PCT: "The same Ownership % applies to every unit selected.",
  JO_UNIT_CAN_ADD: "No joint owner. One can be added",
  JO_UNITS_LOCKED_HINT:
    "Units already held are locked. Removal requires a Joint Owner Deletion service request.",
  JO_UNITS_NONE_SELECTED: "Select at least one unit.",

  JO_SUBMIT_ONE: "Add Joint Owner",
  JO_SUBMIT_MANY: "Add to {0} units",
  /* 22 Sep 2026: joint owner KYC (MODON checks it before a joint owner is added) */
  JO_KYC_OK: "KYC complete",
  JO_KYC_SEND: "Send KYC link",
  JO_KYC_RESEND: "Send again",
  JO_KYC_SENDING: "Sending link. Check again in a minute.",
  JO_KYC_SENT: "Link sent {0}",
  JO_KYC_EXPIRED: "Link expired",
  JO_KYC_CHECK: "Check again",
  JO_KYC_BUSY: "Please wait…",
  JO_CREATE_PERSON: "Create person",
  JO_CREATE_COMPANY: "Create company",
  /* 22 Sep 2026: EOI_SKIPS_BOOKING_FEE on and the unit has a paid EOI */
  RC_FEE_BY_EOI: "No booking fee. The EOI deposit covers it.",

  /* leaving the step with a unit uncovered: an acknowledgement, never a block */
  JO_GATE_EYEBROW: "Before you continue",
  JO_GATE_TITLE_ONE: "1 unit has no joint owner",
  JO_GATE_TITLE: "{0} units have no joint owner",
  JO_GATE_BODY:
    "This is correct if {0} is the sole owner of them. If it was an oversight, add the joint owner now.",
  JO_GATE_ADD: "Add joint owner",
  JO_GATE_CONFIRM_ONE: "Primary owner holds it alone",
  JO_GATE_CONFIRM: "Primary owner holds these alone",

  /* MSC-082: identity verification per person; state words reused, only actions and reasons are new */
  JO_V_HEAD_COUNT: "{0} of {1} verified",
  JO_V_HEAD_ALL: "All {0} verified",
  JO_V_SENDING: "Sending",
  /* not "Cannot verify": it happens, just not from here */
  JO_V_NOT_HERE: "Verified by Sales Operations",
  /* MSC-182: a company joint owner's whole row */
  JO_V_NOT_HERE_LINE: "Verified by Sales Operations from the account record.",
  JO_V_SEND: "Send link",
  JO_V_RESEND: "Resend link",
  JO_V_SENDING_BTN: "Sending…",
  /* the row's action when contact detail is all that is missing */
  JO_V_FIX: "Add details",
  JO_V_SENT_ON: "Link sent {0}",

  /* MSC-083: compliance per person; one action, one tally, and the party strip */
  JO_C_HEAD_COUNT: "{0} of {1} sent to compliance",
  JO_C_HEAD_ALL: "All {0} sent to compliance",
  /* the rep's move once somebody has verified */
  JO_C_CHECK: "Check compliance",
  /* the party strip: name, role and one state word */
  JO_C_STRIP_LABEL: "Who this check is for",
  JO_C_TAB_SENT: "Sent",
  JO_C_TAB_NOT_SENT: "Not sent",
  JO_C_TAB_NOT_READY: "Not verified yet",
  JO_C_TAB_LOCKED: "Sales Operations",
  /* held, not lost */
  JO_C_SWITCH_HELD: "Save your changes before moving to another person.",

  /* MSC-084: the same module on My Bookings; five strings */
  JO_B_TAB: "Owners",
  /* the rep opened a cancelled unit while others are live */
  JO_B_OTHER_UNIT:
    "This unit is no longer part of the booking. The people below own its remaining units.",
  /* the primary owner's details live in the journey's Customer card */
  JO_B_FIX_ON_ACCOUNT:
    "Add it on the customer's account, then send the link from here.",
  JO_B_DISMISS: "Dismiss",
  JO_B_LOADING: "Reading the owners…",
  /* an empty getOwners answer means the read did not come back */
  JO_B_UNAVAILABLE: "The owners could not be read. Try again in a moment.",
  JO_B_TAB_VERIFY: "Verification",

  /* MSC-088: two subjects, two screens. No new vocabulary: column headings and the sentence
     under each person are new; every state word is reused. */

  /* the ownership record (c/mscOwnersTable) */
  OT_EYEBROW: "Owners",
  OT_COL_OWNER: "Owner",
  OT_COL_ROLE: "Role",
  OT_COL_RESIDENCY: "Residency",
  OT_COL_UNIT: "Unit",
  OT_COL_UNITS: "Units",
  OT_COL_SHARE: "Share",
  /* the head chip, always both halves */
  OT_ALLOCATED: "{0}% allocated",
  OT_UNIT_ONE: "1 unit",
  OT_UNIT_MANY: "{0} units",
  OT_ALL_UNITS: "All {0} units",
  /* the row opens the drawer */
  OT_OPEN: "Edit {0}",
  OT_NOT_RECORDED: "Not recorded",

  /* identity verification, person by person (c/mscVerifyList) */
  VL_EYEBROW: "Verification",
  VL_CHECKED: "Checked {0}",
  /* the facts under the four stages, never an instruction */
  VL_FACT_NOT_SENT: "Not sent",
  VL_FACT_SENT: "Sent",
  VL_FACT_WAITING: "Waiting for the customer",
  VL_FACT_EXPIRED: "The link has expired",
  VL_FACT_READY: "Ready for the check",
  VL_FACT_VERIFIED: "Verified",
  VL_FACT_SUBMITTED: "Submitted",
  VL_FACT_EXPIRES_IN: "Expires in {0}",
  VL_FACT_EXPIRED_AGO: "Expired {0} ago",
  VL_FACT_CUSTOMER_AT: "Customer is at: {0}",
  VL_FACT_RISK: "{0} · risk {1}",
  /* the sentence under each person's track, one per state */
  VL_NEXT_SENDING: "Sending the link…",
  VL_NEXT_SEND: "No identity verification link has been sent yet.",
  VL_NEXT_WAITING: "Waiting for the customer to complete their verification.",
  VL_NEXT_EXPIRED: "The link has expired before it was used. Send a new one.",
  VL_NEXT_DETAILS: "Contact details are needed before a link can be sent.",
  VL_NEXT_CHECK: "Verified. Ready for the compliance check.",
  VL_NEXT_SUBMITTED: "With compliance. There is nothing further to do here.",
  VL_NEXT_CLEARED: "Cleared by compliance.",
  /* the ownership strip at the foot of the verification step */
  /* the buyer's link, client-side only */
  VL_COPY: "Copy link",
  VL_COPIED: "Copied",
  VL_OWNERSHIP: "Ownership",
  VL_EMPTY: "There is nobody to verify on this booking yet.",
  /* MSC-182: the two groups the step reads in */
  /* MSC-191: the row the rep must act on, said in words instead of an amber border */
  VL_NEEDS_YOU: "Action needed",
  VL_GROUP_BUYER: "Buyer",
  VL_GROUP_OWNERS: "Joint owners",

  /* MSC-115: the two tracks a corporate booking has */
  VL_ORG_ROLE_COMPANY: "Company",
  VL_ORG_ROLE_SIGNATORY: "Power of Attorney",
  /* MSC-147: VL_ORG_NOT_SUBMITTED retired; an org row prints a dash where nothing has happened */
  /* MSC-151: VL_ORG_NOTE and the org action labels retired; nextStep writes every sentence.
     KYC_CORPORATE stays (c/mscConsole and c/mscCompliance read it). */
  VL_ORG_SIG_VERIFIED: "Identity verified {0}",
  /* MSC-149: between the link going out and the customer finishing it */
  VL_ORG_NO_SIGNATORY:
    "No Power of Attorney is assigned for this company yet.",
  /* MSC-142: the note heading the two tracks, deliberately not KYC_CORPORATE (a company's POA contacts do get a link) */

  /* MSC-146: the landing cards' two actions; no count on the button */

  /* MSC-148: c/mscOrgDetails; no group names here, the rail reads the server's labels */
  ORGD_TITLE: "Verification details",

  /* MSC-181: the Power of Attorney pane; a POA is assigned, never "recorded" */
  ORGD_POA_LABEL: "Power of Attorney",
  ORGD_POA_SEARCH_PH: "Search Contacts\u2026",
  ORGD_POA_COUNT_ALL: "This company has {0} contacts",
  ORGD_POA_COUNT_ONE: "This company has 1 contact",
  ORGD_POA_COUNT_MATCH: "{0} of {1} contacts match \u201c{2}\u201d",
  ORGD_POA_SEARCH_BY: "Search by name, position, email or mobile",
  ORGD_POA_KEYS_MOVE: "to move",
  ORGD_POA_KEYS_PICK: "to select",
  ORGD_POA_KEYS_CLOSE: "to close",
  ORGD_POA_EMPTY: "No matching contacts found for \u201c{0}\u201d.",
  ORGD_POA_NEW: "New Contact",
  ORGD_POA_NEW_Q: "New Contact: \u201c{0}\u201d",
  ORGD_POA_NEW_SUB: "Create a new contact for this company",
  ORGD_POA_ROLE_FALLBACK: "Contact",
  /* said only when something is missing */
  ORGD_POA_MISSING: "Missing {0}",
  ORGD_POA_NOT_PROVIDED: "Not provided",
  /* the one status line */
  ORGD_POA_NOT_ASSIGNED: "Not assigned as the Power of Attorney.",
  ORGD_POA_ASSIGN: "Assign as Power of Attorney",
  ORGD_POA_ASSIGNING: "Assigning\u2026",
  ORGD_POA_NEED: "Required before sending: {0}.",
  ORGD_POA_FILL: "Add details",
  ORGD_POA_FILLING: "Enter the required details below.",
  ORGD_POA_READY: "All required details are complete.",
  ORGD_POA_SENT: "Verification link sent.",
  ORGD_POA_RESEND: "Resend",
  ORGD_POA_VERIFIED: "Identity verified.",
  ORGD_POA_CHANGE: "Remove and choose someone else",
  /* the New Contact form: sendKYCForm's required set, plus the name */
  ORGD_POA_NEW_HEAD: "New contact",
  ORGD_POA_NEW_NOTE: "Enter the details required for identity verification.",
  ORGD_POA_BACK: "Back to search",
  ORGD_POA_F_NAME: "Full name",
  ORGD_POA_F_NAME_HINT: "As printed on the passport",
  ORGD_POA_CREATE: "Add and select",
  ORGD_POA_CREATING: "Adding\u2026",
  ORGD_POA_CREATE_NOTE:
    "The contact will be created and assigned as the Power of Attorney for this booking.",

  /* the licence leads the company group */
  ORGD_LIC_HEAD: "Trade licence",
  ORGD_LIC_FILLS:
    "Uploading it fills the licence number, the date the company was formed, " +
    "the expiry, the VAT number and the registered address.",
  ORGD_LIC_REPLACE: "Replace",

  ORGD_DOCS_NOTE: "These arrive from the customer's identity verification.",
  ORGD_ALL_DONE: "Everything compliance needs is here.",
  ORGD_OPTIONAL: "Optional",

  /* MSC-149: the link is sent from the workspace */
  ORGD_SEND_LINK: "Send verification link",
  ORGD_SENDING: "Sending\u2026",
  ORGD_SAVE: "Save details",
  ORGD_SAVING: "Saving\u2026",
  ORGD_SUBMIT: "Send for compliance",
  ORGD_SUBMITTING: "Sending\u2026",
  ORGD_LOADING: "Loading the company's details\u2026",

  /* the Contact Details section of the edit drawer */
  JO_STEP_CONTACT: "Contact Details",
  JO_V_CONTACT_HINT:
    "Needed before an identity verification link can be sent to this joint owner.",
  /* under the section, always */
  JO_V_CONTACT_NOTE:
    "Blank fields only. A detail already on the account is never overwritten from here.",
  JO_V_CONTACT_LOCKED: "Already on the account",

  /* the fallback when the server's blocked sentence is missing */
  CUSTOMER_INCOMPLETE:
    "This customer's details are not complete yet. Check the highlighted fields below.",

  /* The step-2 verification choice; every string names the person, not the system */
  /* one line, two buttons */
  VERIFY_CHOICE_TITLE: "How would you like to verify this customer?",
  VERIFY_SEND_CTA: "Send KYC link",
  VERIFY_LATER_CTA: "Continue without KYC",
  /* the deal tape's value for a released booking */
  VERIFY_LATER_TITLE: "KYC pending",
  VERIFY_SENDING: "Sending the link…",
  /* the sent body */
  VERIFY_SENDING_BODY: "This takes a few seconds.",
  VERIFY_SENT_TO: "Verification link sent to {0}",
  VERIFY_WAITING_TITLE: "Waiting for {0} to verify",
  VERIFY_WAITING_BODY:
    "They have been sent a link. This booking continues once they have finished.",
  /* the state, as one uppercase word */
  VERIFY_STATUS_SENDING: "Sending",
  VERIFY_STATUS_WAITING: "Waiting on customer",
  /* 1.92 - the verified stage's fact for a manual approval (no completion date) */
  VL_FACT_MANUAL: "Approved manually",
  /* 1.116 - UI-23: the first step of a track approved by manual KYC, where no link was ever sent */
  VL_STEP_MANUAL: "Manual KYC",
  VERIFY_STATUS_EXPIRED: "Link expired",
  VERIFY_EXPIRED_TITLE: "The verification link has expired",
  VERIFY_EXPIRED_BODY:
    "{0} did not finish in time. Send a new link, or continue and verify them later.",
  VERIFY_EXPIRES_IN: "Expires in {0}",
  VERIFY_REFRESH: "Check again",
  VERIFY_RESEND: "Send a new link",
  /* renamed from "Verify in branch instead": states only what the button does */
  VERIFY_IN_BRANCH_CTA: "Continue and verify later",
  /* VERIFY_IN_BRANCH_DONE removed */
  VERIFY_DONE: "Identity verified",
  /* sits on the disabled forward button */
  VERIFY_GATE_BLOCKED:
    "Waiting for the customer to finish verifying. Use “Continue and verify later” to move on without it.",
  /* the verification step's value on the deal tape */
  VERIFIED: "Verified",
  /* the step's value once the link is sent */
  VERIFY_TAPE_SENT: "KYC link sent",
  VERIFY_NOTE:
    "Send the customer their verification link. Compliance screening starts automatically once they complete it. You can close this and the booking will progress on its own.",

  /* forward action */
  // {0} is the destination section's own name
  CTA_CONTINUE_TO: "Continue to {0}",

  // Section gating copy
  LOCKED_NEED_UNIT: "Select a unit first",
  LOCKED_NEED_CUSTOMER: "Complete customer details first",
  LOCKED_NEED_CUSTOMER_PICK: "Choose who this booking is for",
  LOCKED_NEED_PLAN: "Select a payment plan first",
  LOCKED_NEED_PAYMENT: "Payment must be confirmed first",

  // Progress copy
  BUSY_PREPARING: "Preparing your payment details…",
  BUSY_SAVING: "Saving…",
  BUSY_LOADING: "Loading…",

  // Unit hold
  HOLD_PREFIX: "Unit reserved for you",
  HOLD_EXPIRED: "Your hold on this unit has expired.",

  /* multi-unit booking */
  // plain about the trade-off: two or more units book with no hold and no payment
  UNITS_SELECTED_MULTI:
    "{0} units selected. Booking several units at once generates a Sales Order for " +
    "each and does not collect payment or hold the units. To take a payment now, " +
    "book one unit at a time.",
  MULTI_NO_PAYMENT_TITLE: "No payment is collected for a multi-unit booking",
  MULTI_NO_PAYMENT_BODY:
    "A Sales Order is generated for each unit. Payment is collected against each one " +
    "afterwards, from the Sales Order itself.",
  MULTI_CONFIRM_CTA: "Generate Sales Orders",
  MULTI_CONFIRMING: "Generating Sales Orders…",
  MULTI_RECAP_UNITS: "Units",
  MULTI_CONFIRMED: "{0} Sales Orders generated.",
  MULTI_PLAN_PER_UNIT: "Choose a payment plan for each unit.",

  NOT_SAVED: "Not saved"
});

/**
 * Presentation labels for SalesOrder__c.Status__c. "In Progress" cannot be removed from the
 * picklist (routing keys and reports depend on it), so the console never renders raw Status__c.
 */
const STAGE_LABELS = Object.freeze({
  New: "Booking started",
  "In Progress": "Booking in progress",
  "KYC - In progress": "Identity verification underway",
  "KYC - Completed / KYC Rejected": "Identity verification reviewed",
  "Reservation form generated": "Reservation form ready",
  "Reservation form signed": "Reservation form signed",
  "Down payment collected": "Down payment received",
  "DP Payment Confirmed": "Down payment confirmed",
  "Downpayment Payments Cleared": "Down payment cleared",
  "Installment Payment Collected": "Milestone payment received",
  "Payments Collected": "Payments received",
  "Pending Blocking Fees": "Awaiting booking fees",
  "Blocking Fees Collected": "Booking fees received",
  "SPA Generated": "Contract ready",
  "SPA Sent to customer": "Contract sent to customer",
  "SPA Signed (Customer)": "Contract signed by customer",
  "SPA Signed (Modon)": "Contract signed by Modon",
  "SPA Validated": "Contract validated",
  "SPA Delivered": "Contract delivered",
  Sold: "Completed",
  Completed: "Completed",
  Cancelled: "Cancelled",
  "System cancelled": "Cancelled",
  Voided: "Voided"
});

/** Sub-status labels; more specific, so these win when present. */
const SUB_STAGE_LABELS = Object.freeze({
  "Pending with Sales": "With the sales team",
  "Pending With Sales.": "With the sales team",
  "Pending With Sales Operation": "With sales operations",
  "Pending with CM": "With customer management",
  "Under Finance Verification": "Under finance verification",
  "Document Checklist Verified By - Sales Operation":
    "Documents verified by sales operations",
  "Document Checklist Verified By - Customer Management":
    "Documents verified by customer management",
  "SPA In Progress": "Contract being prepared",
  "SPA In-Progress": "Contract being prepared",
  "Signed SPA (Customer)": "Contract signed by customer",
  "Signed SPA (Modon)": "Contract signed by Modon",
  "Down Payment Collected": "Down payment received",
  "ADM + Dari Fee Collected": "ADM registration fee received",
  "Reservation Form Signed": "Reservation form signed",
  "Broker Form Signed": "Broker form signed"
});

/** Sub-status wins because it is the more specific of the pair. */
function stageLabel(status, subStatus) {
  if (subStatus && SUB_STAGE_LABELS[subStatus]) return SUB_STAGE_LABELS[subStatus];
  if (status && STAGE_LABELS[status]) return STAGE_LABELS[status];
  return status || "";
}

/** Payment-bucket status wording. */
const PAYMENT_STATUS_LABELS = Object.freeze({
  "Not Paid": "Not paid",
  "Partially Paid": "Partially paid",
  Paid: "Paid",
  Cancelled: "Cancelled",
  Pending: "Awaiting payment",
  "ADM Received": "ADM fee received",
  "Down Payment Received": "Down payment received",
  "Fully Received": "Fully received",
  Expired: "Expired",
  PROOF_UPLOADED: "Proof submitted · awaiting verification"
});

/**
 * Passfort approval vocabulary, translated. "Requires Resubmission" is the real
 * "Further Documents Required" signal.
 */
const COMPLIANCE_STATUS_LABELS = Object.freeze({
  Approved: "Cleared",
  Rejected: "Declined",
  Applied: "With compliance",
  "In review": "Under review",
  Canceled: "Cancelled",
  "Requires Resubmission": "Further documents required",
  "Submitted to Operation team": "With Sales Operations"
});

/** KYC_Status__c is a formula; these are its only three values. */
const KYC_STATUS_LABELS = Object.freeze({
  "KYC not complete": "Not verified",
  "KYC Active": "Verified",
  "KYC Expired": "Verification expired"
});

function complianceLabel(raw) {
  if (!raw) return "";
  return COMPLIANCE_STATUS_LABELS[raw] || raw;
}

export {
  LABELS,
  STAGE_LABELS,
  SUB_STAGE_LABELS,
  PAYMENT_STATUS_LABELS,
  COMPLIANCE_STATUS_LABELS,
  KYC_STATUS_LABELS,
  stageLabel,
  complianceLabel
};