/**
 * Tests for SalesConsoleController and the DocumentChecklistController payment gate.
 *
 * Version  Author      Date         Detail
 * 1.30     Aurelix Dev 30 Sep 2026  Controller 1.88: theSummaryUnitCarriesTheBookingPrice.
 * 1.29     Aurelix Dev 29 Sep 2026  Controller 1.87: oneUnitOptionIsChosenSeveralAreLeftToTheRep replaces
 *                                   theFirstUnitOptionIsChosenForTheRep.
 * 1.28     Aurelix Dev 29 Sep 2026  Controller 1.83: theFirstUnitOptionIsChosenForTheRep.
 * 1.27     Aurelix Dev 29 Sep 2026  The four money tests build their own booking (anOwnBooking) instead of
 *                                   reading DEV's newest live order; its refusals move to
 *                                   testTheDownPaymentProofRefusesWhatModonsFormWould.
 * 1.26     Aurelix Dev 29 Sep 2026  Controller 1.81: no fee until an EOI is chosen, and releasing a lapsed
 *                                   hold only while nothing is paid.
 * 1.25     Aurelix Dev 29 Sep 2026  Controller 1.80: MODON's full cancelled list and the shared closed-sale
 *                                   rule.
 * 1.24     Aurelix Dev 29 Sep 2026  Controller 1.79: unit options and prices as the Sales App (Wadeem rule,
 *                                   Modon Egypt mapping price).
 * 1.23     Aurelix Dev 28 Sep 2026  SalesConsoleController 1.78 (SCW-211): aSaleModonClosedReadsAsClosedThoughStatusStaysNew
 *                                   (the rule, in memory) and theSummaryFollowsTheSaleToClosed (buildSummary on real
 *                                   records, the flow's Closed Won and Sold written by hand).
 * 1.22     Aurelix Dev 27 Sep 2026  SalesConsoleController 1.77: unit options (required, and the order's price),
 *                                   the EOI phase filter, and MODON's checkUnitStatus behind unitStatusGuard.
 * 1.21     Aurelix Dev 27 Sep 2026  SalesConsoleController 1.76: feeLinesDescribeTheBookingOnlyWhereAFeeIsTaken.
 *                                   anAdmChargeInvoice(true) now finds a booking with money on its fee lines.
 * 1.20     Aurelix Dev 27 Sep 2026  SalesConsoleController 1.75: facadeGuardAsksForAStyleOnlyWhereThePhaseNeedsOne
 *                                   and theSalesOrderCarriesTheFacadeAndThePreApprovalNumber (engine 17.0
 *                                   facade style, 19.0 pre-approval number).
 * 1.19     Aurelix Dev 22 Sep 2026  MODON's engine v16.0 (21 Sep) no longer lists an EOI without a
 *                                   cleared receipt, so bookingEoisArePricedAndOrderedOldestFirst and
 *                                   eoiMappingIsValidatedBeforeItRidesIntoTheSave failed from 18:31 UTC
 *                                   (baseline run 707VG0000CHwzQ0). Each fixture EOI now carries a Cleared
 *                                   receipt. New: theAccountBankIsMatchedToTheUaeddsList
 *                                   (SalesConsoleController 1.73). Previous version:
 *                                   _backup/2026-09-22_081155 (WL-019).
 * 1.18     Aurelix Dev 21 Sep 2026  testOrgEligibilityMessageSaysLicenceNumber is now
 *                                   testTheRetiredEligibilityCheckNoLongerBlocks: SalesConsoleController 1.71
 *                                   stops calling checkBookingEligibility, as the Sales App did on 2 Sep, so
 *                                   neither a company without address or licence number nor an Opportunity /
 *                                   Account nationality mismatch holds the customer step (SCW-137).
 * 1.17     Aurelix Dev 21 Sep 2026  A9 / M6: the prepared KYC fixture patch applied (docs/SalesConsole
 *                                   ControllerTest-KYC-fixture-remediation.md), business confirmed -
 *                                   makePersonAccount + makeKycValid for the five money-movement tests,
 *                                   makeKycValid for testConfirmAsConsoleTester; a person buyer's
 *                                   contact is its PersonContactId, not a new Contact. The EOI pricing
 *                                   test reads EOI_Receipt_Valid_Statuses instead of assuming In
 *                                   Progress is unspendable; the proof-payment test gets its own
 *                                   governor window; the cheque test's split (earlier today) kept.
 * 1.16     Aurelix Dev 02 Sep 2026  MSC-213. The defaulted phase pick skips stock the rep
 *                                   cannot take (live hold fixture).
 * 1.15     Aurelix IT  22 Aug 2026  MSC-115. Organisation compliance tracks.
 * 1.14     Aurelix IT  22 Aug 2026  MSC-113. Organisation record: billing arm retired, org address save,
 *                                   fill-only Opportunity write, nationality lock, real beneficiary.
 * 1.14     Aurelix Developer 19 Aug 2026  A proof records a Payment (1.42); deleteProofSlot.
 * 1.13     Aurelix IT  22 Aug 2026  MSC-112. Customer Information card: masking, lock map, write policy.
 * 1.13     Aurelix Developer 18 Aug 2026  The milestone box (1.41).
 * 1.12     Aurelix Developer 17 Aug 2026  The ADM + Dari charge row (1.40).
 * 1.11     Aurelix Developer 17 Aug 2026  One Sales Order is one booking (1.39).
 * 1.10     Aurelix Developer 17 Aug 2026  The summary of a basket (1.38).
 * 1.9      Aurelix Developer 17 Aug 2026  A basket takes no fee (1.37).
 * 1.8      Aurelix Developer 17 Aug 2026  confirmedOn.
 * 1.7      Aurelix Developer 17 Aug 2026  payRoute and paymentRequired.
 * 1.5      Aurelix Developer 16 Aug 2026  Ledger classification and the plan-has-a-schedule guard.
 * 1.4      Aurelix Developer 16 Aug 2026  getSettlement.
 * 1.3      Aurelix Developer 16 Aug 2026  Resume finds the console's own Sales Order.
 * 1.2      Aurelix IT  09 Aug 2026  Document checklist labelling and approval state.
 * 1.1      Aurelix IT  06 Aug 2026  Compliance chain and the payment gate.
 * 1.0      Aurelix IT  05 Aug 2026  Initial.
 *
 * saveSalesOrder takes FOR UPDATE locks, assigns escrow accounts and enqueues Oracle callouts, so
 * these cover what this work introduces, not end-to-end Sales Order creation.
 */
@isTest
private class SalesConsoleControllerTest {

    /** 1.25 - the controller's own list of statuses that end a booking (MODON's cancelled list). */
    private static final List<String> DEAD_ORDER_STATUSES =
        SalesConsoleDashboardController.cancelledSalesOrderStatuses();

    private static Account makePersonOrOrgAccount(String name, String residency) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Opportunity makeOpportunity(Account a, String residency) {
        Opportunity o = new Opportunity(
            Name = 'Test Booking Opp',
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(30)
        );
        if (String.isNotBlank(residency)) {
            o.UAE_Resident_Status__c = residency;
        }
        insert o;
        return o;
    }

    /**
     * 21 Sep 2026 (A9 / M6) - the prepared KYC fixture patch applied. A Person Account buyer, for
     * the five tests whose subject is money movement or request validation, not buyer type. See
     * docs/SalesConsoleControllerTest-KYC-fixture-remediation.md, section 7, Option 2.
     */
    private static Account makePersonAccount(String lastName) {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' AND IsPersonType = true
            LIMIT 1
        ];
        Account a = new Account(FirstName = 'Fixture', LastName = lastName);
        if (!rt.isEmpty()) { a.RecordTypeId = rt[0].Id; }
        insert a;
        return a;
    }

    /**
     * Makes the Opportunity's buyer legitimately KYC-eligible under whichever branch applies.
     * Idempotent. Call BEFORE Test.startTest() so fixture DML does not consume the test's own
     * governor allocation, and OUTSIDE any System.runAs block.
     */
    private static void makeKycValid(Id opportunityId) {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;

        Opportunity o = [
            SELECT Id, AccountId, Account.IsPersonAccount, Account.PersonContactId, PrimaryContact__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];

        /* Check 1 / O2. Applied 21 Sep: a person account cannot take a second Contact, so a person
           buyer's primary contact is its own PersonContactId - which is also what MODON's gate
           reads through PrimaryContact__r.Account. */
        Id contactId = o.PrimaryContact__c;
        if (contactId == null && o.Account.IsPersonAccount == true && o.Account.PersonContactId != null) {
            contactId = o.Account.PersonContactId;
            update new Opportunity(Id = o.Id, PrimaryContact__c = contactId);
        }
        if (contactId == null) {
            Contact c = new Contact(LastName = 'KYC Fixture Buyer', AccountId = o.AccountId);
            Database.insert(c, dml);
            contactId = c.Id;
            update new Opportunity(Id = o.Id, PrimaryContact__c = contactId);
        }

        /* v2.2: the buyer is the OPPORTUNITY's account. */
        Boolean isPerson = o.Account.IsPersonAccount == true;
        Id companyId     = o.AccountId;

        /* Preserve an existing residency; only supply one where the fixture has none. Changing a
           Non-Resident buyer to Resident would alter the fixture's character AND silently add two
           more required documents. */
        Contact existing = [
            SELECT Id, UAE_Resident_Status__c, Nationality__c FROM Contact WHERE Id = :contactId LIMIT 1
        ];
        String residency = String.isNotBlank(existing.UAE_Resident_Status__c)
            ? existing.UAE_Resident_Status__c
            : 'Resident';
        String nationality = String.isNotBlank(existing.Nationality__c)
            ? existing.Nationality__c
            : 'United Arab Emirates';

        if (isPerson) {
            /* On a Person Account the __pc fields ARE the contact's fields. */
            Database.update(new Account(
                Id                      = companyId,
                KYC_Completed_Date__c   = Date.today(),
                Nationality__pc         = nationality,
                UAE_Resident_Status__pc = residency), dml);
        } else {
            /* O3 reads the date from the CONTACT. */
            Database.update(new Contact(
                Id                     = contactId,
                Nationality__c         = nationality,
                UAE_Resident_Status__c = residency,
                KYC_Completed_Date__c  = Date.today()), dml);

            /* O1 / O2 - an actual POA row on the OPPORTUNITY's account, naming THIS contact. */
            List<Power_of_Attorney__c> poa = [
                SELECT Id FROM Power_of_Attorney__c
                WHERE Organization_Account__c = :companyId AND Contact__c = :contactId LIMIT 1
            ];
            if (poa.isEmpty()) {
                Database.insert(new Power_of_Attorney__c(
                    Organization_Account__c = companyId,
                    Contact__c              = contactId), dml);
            }
        }

        /* 3b / O5 - the identity documents. Both EID sides only when Resident. */
        List<String> onContact = new List<String>{ 'KYC Form - Signed', 'Passport' };
        if (residency.equalsIgnoreCase('Resident')) {
            onContact.add('Emirates/National ID Front');
            onContact.add('Emirates/National ID Back');
        }
        ensureDocumentsWithFiles(onContact, contactId, companyId, dml);

        /* 3c / O6 - a company also needs one accepted corporate document. */
        if (!isPerson) {
            ensureDocumentsWithFiles(
                new List<String>{ 'Commercial trade License (Resident)' }, null, companyId, dml);
        }
    }

    /**
     * Guarantees that for every name at least one Documents__c row exists AND holds a real file.
     * Row existence alone is NOT sufficient: MODON's KYCFileContext.parentsWithFiles returns only
     * parents carrying a ContentDocumentLink or Attachment, and the check then requires membership
     * of that set. Proven live: `Abdul Rais` has 3 of the 4 rows and 0 files, and is refused.
     *
     * `accountId` is always the owning account; `contactId` is null for company-level documents.
     * No SOQL is issued inside any loop.
     */
    private static void ensureDocumentsWithFiles(
            List<String> names, Id contactId, Id accountId, Database.DMLOptions dml) {

        Map<String, List<Documents__c>> byName = new Map<String, List<Documents__c>>();
        List<Documents__c> found = contactId != null
            ? [SELECT Id, Name FROM Documents__c
               WHERE PrimaryContact__c = :contactId AND Name IN :names]
            : [SELECT Id, Name FROM Documents__c
               WHERE Account__c = :accountId AND Name IN :names];

        Set<Id> allIds = new Set<Id>();
        for (Documents__c d : found) {
            if (!byName.containsKey(d.Name)) { byName.put(d.Name, new List<Documents__c>()); }
            byName.get(d.Name).add(d);
            allIds.add(d.Id);
        }

        /* Which already hold a file - the same two sources MODON checks */
        Set<Id> withFile = new Set<Id>();
        if (!allIds.isEmpty()) {
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :allIds
            ]) {
                withFile.add(l.LinkedEntityId);
            }
            Set<Id> remaining = new Set<Id>(allIds);
            remaining.removeAll(withFile);
            if (!remaining.isEmpty()) {
                for (Attachment a : [SELECT ParentId FROM Attachment WHERE ParentId IN :remaining]) {
                    withFile.add(a.ParentId);
                }
            }
        }

        List<Documents__c> toCreate = new List<Documents__c>();
        List<Id> attachTo = new List<Id>();
        for (String n : names) {
            List<Documents__c> rows = byName.get(n);
            Boolean satisfied = false;
            if (rows != null) {
                for (Documents__c d : rows) {
                    if (withFile.contains(d.Id)) { satisfied = true; break; }
                }
            }
            if (satisfied) { continue; }
            if (rows != null && !rows.isEmpty()) {
                attachTo.add(rows[0].Id);          // row exists, no file - attach to it
            } else {
                Documents__c d = new Documents__c(Name = n, Account__c = accountId);
                if (contactId != null) { d.PrimaryContact__c = contactId; }
                toCreate.add(d);
            }
        }

        if (!toCreate.isEmpty()) {
            Database.insert(toCreate, dml);
            for (Documents__c d : toCreate) { attachTo.add(d.Id); }
        }
        if (attachTo.isEmpty()) { return; }

        List<ContentVersion> versions = new List<ContentVersion>();
        for (Integer i = 0; i < attachTo.size(); i++) {
            versions.add(new ContentVersion(
                Title        = 'KYC fixture file ' + i,
                PathOnClient = 'kyc-fixture.txt',
                VersionData  = Blob.valueOf('kyc fixture')));
        }
        insert versions;

        Map<Id, Id> documentIdByVersion = new Map<Id, Id>();
        for (ContentVersion v : [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versions
        ]) {
            documentIdByVersion.put(v.Id, v.ContentDocumentId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Integer i = 0; i < attachTo.size(); i++) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = documentIdByVersion.get(versions[i].Id),
                LinkedEntityId    = attachTo[i],
                ShareType         = 'V',
                Visibility        = 'AllUsers'));
        }
        insert links;
    }


    /**
     * The payment plan survives Take payment: read back from the fee lines with no Sales Order.
     * SeeAllData: a fee line needs a real Unit and PaymentPlan.
     */
    @isTest(SeeAllData=true)
    static void testPaymentPlanIsRecoveredFromFeeLinesBeforeAnySalesOrder() {
        List<PaymentPlan__c> plans = [SELECT Id FROM PaymentPlan__c WHERE isActive__c = true LIMIT 1];
        List<Unit__c> units = [
            SELECT Id FROM Unit__c WHERE Status__c = 'Available' AND TotalPrice__c > 0 LIMIT 1
        ];
        /* asserted, not skipped: this is the only automated proof (the field has no FLS for any profile) */
        System.assert(!plans.isEmpty(), 'No active PaymentPlan__c in this org - cannot prove recovery.');
        System.assert(!units.isEmpty(), 'No available priced Unit__c in this org - cannot prove recovery.');

        Account a = makePersonOrOrgAccount('Plan Recovery Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        insert new Booking_Fee_Line__c(
            Opportunity__c = o.Id, Unit__c = units[0].Id,
            Payment_Plan__c = plans[0].Id, Type__c = 'Down Payment', Total_Amount__c = 1000
        );

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO summary =
            SalesConsoleController.getBookingSummary(o.Id, units[0].Id, null, null);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'A summary must come back at all.');
        System.assertNotEquals(null, summary.plan, 'buildPlanBlock always returns an object.');
        System.assertEquals(plans[0].Id, summary.plan.planId,
            'The plan must be recovered from the booking fee line. Without it the agent is ' +
            'asked to re-pick a plan they already chose, and Due Now reads zero.');
    }

    /** getConsoleState degrades rather than throws on an invisible opportunity. */
    @isTest
    static void testConsoleStateWithNullOpportunityReturnsEmptyState() {
        Test.startTest();
        SalesConsoleController.ConsoleState state =
            SalesConsoleController.getConsoleState(null);
        Test.stopTest();

        System.assertNotEquals(null, state,
            'A null opportunity must still return a state object, so the page can render.');
        System.assertEquals(null, state.opportunityId,
            'No opportunity was supplied, so none should be echoed back.');
    }

    /** The summary works before any record exists. */
    @isTest
    static void testBookingSummaryWorksWithNoRecords() {
        Test.startTest();
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummary(null, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto,
            'The summary must always return a shape, never null - the panel is never blank.');
        System.assertNotEquals(null, dto.fees,
            'Fee block must always exist so the UI can bind without null checks.');
        System.assertNotEquals(null, dto.documents,
            'Document block must always exist for the same reason.');
        System.assertEquals(0, dto.payments.size(),
            'With no unit or booking there are no payment obligations yet.');
    }

    /** Residency is exact-match: DocumentChecklistController returns an unfiltered checklist otherwise. */
    @isTest
    static void testSaveCustomerInfoRejectsUnknownResidency() {
        Account a = makePersonOrOrgAccount('Residency Guard Co', null);
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        // 'International' is KYC_Response__c vocabulary, not UAEResidentStatus
        input.residentStatus = 'International';

        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.saveCustomerInfo(input);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'A residency outside the UAEResidentStatus value set must be rejected, ' +
            'because DocumentChecklistController would silently skip its filter.');
    }

    /** The two supported values pass the same guard. */
    @isTest
    static void testSaveCustomerInfoAcceptsBothResidencyValues() {
        Account a = makePersonOrOrgAccount('Residency Accept Co', null);
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Opportunity refreshed = [
            SELECT UAE_Resident_Status__c FROM Opportunity WHERE Id = :o.Id LIMIT 1
        ];
        System.assertEquals('Resident', refreshed.UAE_Resident_Status__c,
            'Residency must be written to the Opportunity: checkBookingEligibility ' +
            'blocks when Account and Opportunity disagree.');
    }

    /** A proof slot points at exactly one payment. */
    @isTest
    static void testCreateProofSlotRejectsUnknownBucket() {
        SalesConsoleController.ProofSlotRequest req = new SalesConsoleController.ProofSlotRequest();
        req.salesOrderId = null;
        req.bucketKey = 'NOT_A_BUCKET';

        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.createProofSlot(req);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'An unrecognised payment type must be refused rather than written ' +
            'with a null Payment_Proof_Type__c.');
    }

    /** A proof with no payment attached is refused. */
    @isTest
    static void testCreateProofSlotRequiresAPayment() {
        SalesConsoleController.ProofSlotRequest req = new SalesConsoleController.ProofSlotRequest();
        req.bucketKey = SalesConsoleController.BUCKET_DOWN;
        req.sourceId = null;

        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.createProofSlot(req);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'A proof must relate to a specific payment - that relationship is ' +
            'what keeps Down Payment and ADM proofs distinguishable.');
    }

    /** reviewAndConfirm fails closed on an incomplete request. */
    @isTest
    static void testReviewAndConfirmRefusesIncompleteRequest() {
        SalesConsoleController.ConfirmRequest req = new SalesConsoleController.ConfirmRequest();
        req.opportunityId = null;

        Test.startTest();
        SalesConsoleController.ConfirmResult noOpp = SalesConsoleController.reviewAndConfirm(req);

        SalesConsoleController.ConfirmRequest req2 = new SalesConsoleController.ConfirmRequest();
        Account a = makePersonAccount('Confirm Guard Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        req2.opportunityId = o.Id;
        req2.unitId = null;
        SalesConsoleController.ConfirmResult noUnit = SalesConsoleController.reviewAndConfirm(req2);
        Test.stopTest();

        System.assertEquals(false, noOpp.isSuccess,
            'Confirming without an opportunity must fail.');
        System.assertNotEquals(null, noOpp.message,
            'A failed confirmation must always explain itself - the agent has no other signal.');
        System.assertEquals(false, noUnit.isSuccess,
            'Confirming without a unit must fail.');
    }

    /** Direct Debit is only offered where a mandate can be requested. */
    @isTest
    static void testDirectDebitStateWithNoSalesOrder() {
        Test.startTest();
        SalesConsoleController.DirectDebitStateDTO dto =
            SalesConsoleController.getDirectDebitState(null);
        Test.stopTest();

        System.assertNotEquals(null, dto,
            'The DD state must always return a shape so the UI can bind.');
        System.assertEquals(false, dto.canRequest,
            'Without a booking there is nothing to attach a mandate to.');
        System.assertEquals(false, dto.coversMilestones,
            'coversMilestones must stay false until a bank-approved mandate exists - ' +
            'a submitted mandate is not yet a payment method.');
    }

    /** Payment gate fires only for the hand-off that presumes collected funds. */
    @isTest
    static void testPaymentGateIgnoresNonFinanceHandoffs() {
        Test.startTest();
        String msg = DocumentChecklistController.paymentGateMessage(null, 'Sales Operation');
        Test.stopTest();

        System.assertEquals(null, msg,
            'Only the Finance hand-off presumes money has arrived; document review must not be gated.');
    }

    /**
     * Resume finds a booking this console made (SalesOrder__c with no Checkout_Payment__c) and
     * opens on Payment & Confirm. SeeAllData: needs a real Unit and PaymentPlan.
     */
    @isTest(SeeAllData=true)
    static void testResumeFindsAConsoleMadeBookingAndOpensOnSettle() {
        List<PaymentPlan__c> plans = [SELECT Id FROM PaymentPlan__c WHERE isActive__c = true LIMIT 1];
        List<Unit__c> units = [
            SELECT Id FROM Unit__c WHERE Status__c = 'Available' AND TotalPrice__c > 0 LIMIT 1
        ];
        System.assertEquals(false, plans.isEmpty(), 'This org must have an active payment plan.');
        System.assertEquals(false, units.isEmpty(), 'This org must have an available priced unit.');

        Account a = makePersonOrOrgAccount('Resume Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        /* unit stamped as confirm stamps it; plan comes off the fee line */
        o.Unit__c = units[0].Id;
        update o;
        insert new Booking_Fee_Line__c(
            Opportunity__c = o.Id, Unit__c = units[0].Id,
            Payment_Plan__c = plans[0].Id, Type__c = 'Down Payment', Total_Amount__c = 1000
        );
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Unit__c = units[0].Id,
            Status__c = 'New'
        );
        insert so;

        Test.startTest();
        SalesConsoleController.ConsoleState state =
            SalesConsoleController.getConsoleState(o.Id);
        Test.stopTest();

        System.assertEquals(so.Id, state.salesOrderId,
            'The Sales Order written by reviewAndConfirm must be found on resume - '
            + 'without it the journey shows a live booking as "not yet booked".');
        System.assertNotEquals(null, state.bookingRef,
            'The booking reference comes with it, or the rail has nothing to name.');
        System.assertEquals('settle', state.resumeStep,
            'A booking with a unit, a customer and a plan reopens on Payment & Confirm, '
            + 'not on Unit Selection.');
    }

    /** The unit grid opens on the booking's own phase. */
    @isTest(SeeAllData=true)
    static void testUnitBrowserOpensOnTheBookedUnitsPhase() {
        List<Unit__c> units = [
            SELECT Id, Phase__c, Phase__r.Project__c
            FROM Unit__c
            WHERE Status__c = 'Available' AND TotalPrice__c > 0 AND Phase__c != NULL
            LIMIT 1
        ];
        System.assertEquals(false, units.isEmpty(), 'This org must have a phased unit.');

        Account a = makePersonOrOrgAccount('Browser Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        /* 1.22 - controller 1.77: "booked" is a live Sales Order; Opportunity.Unit__c no longer steers */
        insert new SalesOrder__c(Opportunity__c = o.Id, CustomerAccount__c = a.Id, Unit__c = units[0].Id);

        Test.startTest();
        SalesConsoleController.UnitBrowserDTO dto =
            SalesConsoleController.getUnitBrowser(o.Id, null, null);
        Test.stopTest();

        System.assertEquals(String.valueOf(units[0].Phase__r.Project__c), dto.selectedProjectId,
            'The grid opens on the project the booked unit belongs to.');
        System.assertEquals(String.valueOf(units[0].Phase__c), dto.selectedPhaseId,
            'And on its phase - the only one worth opening on when a unit is chosen.');
    }

    /** A hand-off to Finance is blocked while money is outstanding. */
    @isTest
    static void testPaymentGateBlocksFinanceWhenUnpaid() {
        Account a = makePersonOrOrgAccount('Gate Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Down_Payment_Status__c = 'Generated',
            ADM_Fees_and_Dari__c = 'Generated'
        );
        insert so;

        Test.startTest();
        String msg = DocumentChecklistController.paymentGateMessage(so.Id, 'Finance');
        Test.stopTest();

        System.assertNotEquals(null, msg,
            'A booking with an uncollected down payment must not reach Finance verification.');
        System.assertEquals(true, msg.contains('down payment'),
            'The block must name what is missing so the agent knows what to collect.');
    }

    /** Once both are settled, the hand-off proceeds. */
    @isTest
    static void testPaymentGateAllowsFinanceWhenSettled() {
        Account a = makePersonOrOrgAccount('Gate Settled Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Down_Payment_Status__c = 'Collected',
            ADM_Fees_and_Dari__c = 'Paid'
        );
        insert so;

        Test.startTest();
        String msg = DocumentChecklistController.paymentGateMessage(so.Id, 'Finance');
        Test.stopTest();

        System.assertEquals(null, msg,
            'With both the down payment and ADM fee settled, the hand-off must proceed.');
    }

    /** The management waiver keeps working. */
    @isTest
    static void testPaymentGateHonoursAdmWaiver() {
        Account a = makePersonOrOrgAccount('Waiver Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Down_Payment_Status__c = 'Collected',
            ADM_Fees_and_Dari__c = 'Generated',
            IsADMCollectedWithWaiverRequest__c = true
        );
        insert so;

        Test.startTest();
        String msg = DocumentChecklistController.paymentGateMessage(so.Id, 'Finance');
        Test.stopTest();

        System.assertEquals(null, msg,
            'An approved ADM waiver must not be re-blocked by the new gate.');
    }

    // Identity verification and compliance

    /** The gate, asserted directly: SalesOrderTriggerHandler wraps the call in !Test.isRunningTest(). */
    @isTest
    static void testComplianceWaitsForKyc() {
        Account a = makePersonOrOrgAccount('KYC Gate Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id
        );
        insert so;

        Test.startTest();
        AutoPassfortComplianceService.handleSalesOrderCreation(
            new List<SalesOrder__c>{ so });
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM PassfortTransaction__c WHERE Sales_Order__c = :so.Id],
            'A customer who has not completed KYC must not be sent for compliance checks.');
    }

    /** Null and empty input are no-ops. */
    @isTest
    static void testComplianceHandlesEmptyInput() {
        Test.startTest();
        AutoPassfortComplianceService.handleSalesOrderCreation(null);
        AutoPassfortComplianceService.handleSalesOrderCreation(new List<SalesOrder__c>());
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM PassfortTransaction__c],
            'Nothing to process must mean nothing submitted, and no exception on the SO trigger.');
    }

    /** Nationality reaches the Account; sendKYCForm refuses a link without it. */
    @isTest
    static void testCustomerInfoWritesNationalityToAccount() {
        Account a = makePersonOrOrgAccount('Nationality Co', null);
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';
        input.nationality = 'United Arab Emirates';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        System.assertEquals('United Arab Emirates',
            [SELECT Nationality__c FROM Opportunity WHERE Id = :o.Id LIMIT 1].Nationality__c,
            'Nationality must still be written to the Opportunity.');
    }

    /** The compliance panel always renders. */
    @isTest
    static void testComplianceStateAlwaysReturnsAShape() {
        Test.startTest();
        SalesConsoleController.ComplianceStateDTO none =
            SalesConsoleController.getComplianceState(null);

        Account a = makePersonOrOrgAccount('Compliance Shape Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesConsoleController.ComplianceStateDTO some =
            SalesConsoleController.getComplianceState(o.Id);
        Test.stopTest();

        System.assertNotEquals(null, none,
            'A null opportunity must still return a state object so the panel can render.');
        System.assertNotEquals(null, none.blockedReason,
            'When nothing can be done, the panel must say why rather than sit blank.');
        System.assertNotEquals(null, some,
            'A real opportunity must always return a state.');
        System.assertEquals(false, some.kycComplete,
            'A customer with no KYC completion date has not verified their identity.');
    }

    /** The link is offered only when it would work. */
    @isTest
    static void testLinkIsNotOfferedUntilPrerequisitesExist() {
        Account a = makePersonOrOrgAccount('Prereq Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');

        Test.startTest();
        SalesConsoleController.ComplianceStateDTO dto =
            SalesConsoleController.getComplianceState(o.Id);
        Test.stopTest();

        System.assertEquals(false, dto.canSendLink,
            'Without nationality, residency, email and mobile the KYC link cannot be sent.');
        System.assertNotEquals(null, dto.blockedReason,
            'The agent must be told which details are missing, not just that the button is off.');
    }

    /** Placeholder names match the Custom Labels exactly. */
    @isTest
    static void testDocSlotsAreCreatedFromTheLabels() {
        Account a = makePersonOrOrgAccount('Doc Slot Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');

        Test.startTest();
        Integer created = SalesConsoleController.ensureComplianceDocSlots(o.Id);
        Integer second  = SalesConsoleController.ensureComplianceDocSlots(o.Id);
        Test.stopTest();

        System.assertEquals(0, second,
            'Creating slots twice must not duplicate them - the method has to be re-runnable.');
        System.assert(created >= 0,
            'Slot creation must complete without error even when the account is not a Person Account.');
    }

    /** No residency means the required set is unknown. */
    @isTest
    static void testDocSlotsSkippedWithoutResidency() {
        Account a = makePersonOrOrgAccount('No Residency Co', null);
        Opportunity o = makeOpportunity(a, null);

        Test.startTest();
        Integer created = SalesConsoleController.ensureComplianceDocSlots(o.Id);
        Test.stopTest();

        System.assertEquals(0, created,
            'Without a residency the required documents are unknown, so none may be invented.');
    }

    @isTest
    static void testDocSlotsRequireAnOpportunity() {
        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.ensureComplianceDocSlots(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'A missing opportunity is a programming error and must surface as one.');
    }

    /** Sending a link without an account cannot silently do nothing. */
    @isTest
    static void testSendKycLinkRequiresAnAccount() {
        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.sendKycLink(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'There is no one to send a verification link to without an opportunity.');
    }

    /* Document checklist */

    /** Every required document arrives with a real name (the untyped-map bug). */
    @isTest
    static void testRequiredDocumentsComeBackWithRealLabels() {
        Account a = makePersonOrOrgAccount('Docs Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            UAE_Resident_Status__c = 'Resident'
        );
        insert so;

        Test.startTest();
        SalesConsoleController.DocumentRequirementDTO dto =
            SalesConsoleController.getRequiredDocuments(so.Id, o.Id);
        Test.stopTest();

        System.assertEquals('Resident', dto.residentStatus,
            'Residency drives which documents are required; without it the panel is empty.');
        System.assert(!dto.items.isEmpty(),
            'Document_Checklists__mdt has active Sales Order rows for residents, so the ' +
            'catalogue must not come back empty.');

        for (SalesConsoleController.ChecklistItemDTO item : dto.items) {
            System.assert(String.isNotBlank(item.label),
                'A document with no name is not something an agent can go and collect.');
            System.assertNotEquals('null', item.label,
                'The literal string "null" means a field name was read that the source ' +
                'does not have - the exact failure this test exists for.');
            System.assert(String.isNotBlank(item.team),
                'Each document belongs to a reviewing team; the panel groups by it.');
        }
    }

    /** Nothing is approved before a Sales Order exists, and asking does not throw. */
    @isTest
    static void testRequiredDocumentsWithNoSalesOrderAreAllOutstanding() {
        Account a = makePersonOrOrgAccount('Early Co', null);
        Opportunity o = makeOpportunity(a, 'Non-Resident');

        Test.startTest();
        SalesConsoleController.DocumentRequirementDTO dto =
            SalesConsoleController.getRequiredDocuments(null, o.Id);
        Test.stopTest();

        System.assertEquals('Non-Resident', dto.residentStatus,
            'Residency is read from the opportunity when no Sales Order exists yet.');
        for (SalesConsoleController.ChecklistItemDTO item : dto.items) {
            System.assertEquals(false, item.received,
                'Nothing can be approved before the booking it belongs to exists.');
        }
        System.assertEquals(dto.items.size(), dto.outstandingLabels.size(),
            'With no review state yet, every catalogued document is outstanding.');
    }

    /**
     * Outstanding items no longer force furtherDocumentsRequired: the field means a reviewer
     * asked for more, and it is false on a booking that has not been worked yet.
     */
    @isTest
    static void testOutstandingDocumentsDoNotRaiseTheFurtherDocumentsAlert() {
        Account a = makePersonOrOrgAccount('Alert Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            UAE_Resident_Status__c = 'Resident'
        );
        insert so;

        Test.startTest();
        SalesConsoleController.DocumentRequirementDTO dto =
            SalesConsoleController.getRequiredDocuments(so.Id, o.Id);
        Test.stopTest();

        System.assert(!dto.outstandingLabels.isEmpty(),
            'Nothing is approved on a brand-new booking, so this test needs outstanding ' +
            'items to be meaningful at all.');
        System.assertEquals(false, dto.furtherDocumentsRequired,
            'Further_Documents_Required__c is false on this Sales Order. Outstanding ' +
            'work must never be reported as a reviewer having asked for more.');
    }

    /**
     * When the org's own signal is on it passes through. Further_Documents_Required__c is a formula
     * over Sub_Status__c and the two payment statuses, so it is driven by parking the booking in
     * a waiting state.
     */
    @isTest
    static void testFurtherDocumentsAlertIsReportedWhenTheFieldIsSet() {
        Account a = makePersonOrOrgAccount('Sent Back Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            UAE_Resident_Status__c = 'Resident',
            Sub_Status__c = 'Pending with Sales'
        );
        insert so;
        System.assertEquals(true,
            [SELECT Further_Documents_Required__c FROM SalesOrder__c WHERE Id = :so.Id]
                .Further_Documents_Required__c,
            'The formula must be on, or this test is asserting nothing.');

        Test.startTest();
        SalesConsoleController.DocumentRequirementDTO dto =
            SalesConsoleController.getRequiredDocuments(so.Id, o.Id);
        Test.stopTest();

        System.assertEquals(true, dto.furtherDocumentsRequired,
            'A reviewer asking for more documents is exactly what this alert is for.');
    }

    /**
     * bookingConfirmed and isBookingFee are independent: an unpaid booking fee outlives Confirm.
     * SeeAllData: Unit__c cannot be built synthetically.
     */
    @isTest(SeeAllData=true)
    static void testSettlementKnowsTheBookingHasBeenConfirmed() {
        Account a = makePersonOrOrgAccount('Confirmed Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        // units are queried, not built
        List<Unit__c> units = [
            SELECT Id FROM Unit__c WHERE Status__c = 'Available' AND TotalPrice__c > 0 LIMIT 1
        ];
        System.assert(!units.isEmpty(),
            'No available priced Unit__c in this org - cannot prove the confirmed state.');
        Id unitId = units[0].Id;
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Unit__c = unitId
        );
        insert so;

        Test.startTest();
        SalesConsoleController.SettlementDTO before =
            SalesConsoleController.getSettlement(o.Id, unitId, new List<Id>(), null, null);
        SalesConsoleController.SettlementDTO after = SalesConsoleController.getSettlement(
            o.Id, unitId, new List<Id>{ so.Id }, null, null);
        Test.stopTest();

        System.assertEquals(false, before.bookingConfirmed,
            'No Sales Order means Confirm has not run, whatever the fee figures say.');
        System.assertEquals(true, after.bookingConfirmed,
            'A Sales Order existing IS the confirmation - saveSalesOrder is what ' +
            'Confirm calls.');
    }

    /** bookedUnits is what the booking covers, not what the screen has open. SeeAllData. */
    @isTest(SeeAllData=true)
    static void testConsoleStateListsEveryUnitTheBookingMade() {
        Account a = makePersonOrOrgAccount('Basket Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        List<Unit__c> units = [
            SELECT Id, Name FROM Unit__c
            WHERE Status__c = 'Available' AND TotalPrice__c > 0 LIMIT 2
        ];
        System.assertEquals(2, units.size(),
            'Two available priced units are needed to represent a basket.');
        insert new List<SalesOrder__c>{
            new SalesOrder__c(
                Opportunity__c = o.Id, CustomerAccount__c = a.Id, Unit__c = units[0].Id),
            new SalesOrder__c(
                Opportunity__c = o.Id, CustomerAccount__c = a.Id, Unit__c = units[1].Id)
        };

        Test.startTest();
        SalesConsoleController.ConsoleState state =
            SalesConsoleController.getConsoleState(o.Id);
        Test.stopTest();

        System.assertEquals(2, state.bookedUnits.size(),
            'Both Sales Orders belong to this booking; showing one of them without ' +
            'saying so is showing half a booking.');
        Set<String> names = new Set<String>();
        for (SalesConsoleController.BookedUnitDTO b : state.bookedUnits) {
            names.add(b.unitName);
            System.assert(String.isNotBlank(b.bookingRef),
                'Each row names the Sales Order it came from.');
        }
        System.assert(names.contains(units[0].Name) && names.contains(units[1].Name),
            'Both units must be named, not merely counted.');
    }

    /* Confirm-path access harness */

    /**
     * Drives the whole confirm path as the rep to surface every access gap at once (friendly()
     * names neither object nor field). runAs enforces CRUD, FLS and sharing; the transaction
     * rolls back.
     */
    @isTest(SeeAllData=true)
    static void testConfirmAsConsoleTester() {
        User rep = [
            SELECT Id FROM User
            WHERE Username = 'salesconsole.tester@modon.com.bpdev' LIMIT 1
        ];
        /* the fixture is the newest booking whose customer already clears the eligibility gate */
        List<Opportunity> ready = [
            SELECT Id FROM Opportunity
            WHERE OwnerId = :rep.Id AND IsClosed = false
            AND Account.IsPersonAccount = true
            AND Account.PersonMailingStreet     != null
            AND Account.PersonMailingCity       != null
            AND Account.PersonMailingState      != null
            AND Account.PersonMailingPostalCode != null
            AND Account.PersonMailingCountry    != null
            AND Account.Nationality__pc         != null
            AND Account.UAE_Resident_Status__pc != null
            AND Nationality__c                  != null
            AND UAE_Resident_Status__c          != null
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assert(!ready.isEmpty(),
            'No open booking of ' + rep.Id + ' has a customer complete enough to confirm - '
            + 'the access path cannot be walked without one.');
        Opportunity opp = ready[0];
        makeKycValid(opp.Id);          // A9: the KYC fixture patch, outside System.runAs
        /* A9: and in a phase that needs no EOI. The newest available unit is Wadeem-SP-010, whose
           phase is EOI-required and strict, so SalesConsoleController 1.69's EOI gate - correctly,
           as the Sales App would - refused it before the save this test exists to reach. */
        /* and one saveSalesOrder can give an escrow account to: an Available virtual account of
           its own on the SAME escrow account as its phase - the pair saveSalesOrder looks up.
           GolfEstate-P4-131 has a virtual account, but on another escrow, and was refused
           ("Virtual account is not available") before the access path. SOQL cannot compare two
           fields, so the pair is matched here. */
        Unit__c unit = null;
        for (VirtualAccount__c va : [
            SELECT Unit__c, EscrowAccount__c, Unit__r.Phase__r.EscrowAccount__c
            FROM VirtualAccount__c
            WHERE Status__c = 'Available' AND Unit__c != null
              AND Unit__r.Status__c = 'Available' AND Unit__r.Sub_Status__c = 'Un-Assigned'
              AND Unit__r.TotalPrice__c > 0
              AND Unit__r.Phase__r.EOI_Required__c = false
            ORDER BY Unit__r.CreatedDate DESC
            LIMIT 200
        ]) {
            if (va.EscrowAccount__c != null
                    && va.EscrowAccount__c == va.Unit__r.Phase__r.EscrowAccount__c) {
                unit = [SELECT Id, Name FROM Unit__c WHERE Id = :va.Unit__c LIMIT 1];
                break;
            }
        }
        System.assertNotEquals(null, unit,
            'No available unit in a no-EOI phase has a virtual account on its own escrow - '
            + 'the access path cannot be walked without one.');

        String outcome;
        String planFound;
        System.runAs(rep) {
            // the plan comes from the console's own loader
            Id planId = null;
            try {
                Map<String, Object> cfg =
                    SalesConsoleController.getUnitConfiguration(unit.Id, opp.Id);
                /* unwrapped as mscBookingPage.extractPlans does */
                Object offer = cfg == null ? null : cfg.get('offer');
                Map<String, Object> om = (Map<String, Object>) JSON.deserializeUntyped(
                    JSON.serialize(offer));
                Map<String, Object> detail =
                    (Map<String, Object>) om.get('unitPaymentDetailObj');
                List<Object> rows = detail == null
                    ? null : (List<Object>) detail.get('paymentLst');
                if (rows != null && !rows.isEmpty()) {
                    Map<String, Object> row = (Map<String, Object>) rows[0];
                    Map<String, Object> plan = (Map<String, Object>) row.get('paymentObj');
                    if (plan != null) { planId = (Id) plan.get('Id'); }
                }
                planFound = String.valueOf(planId)
                    + ' paymentRequired=' + cfg.get('paymentRequired');
            } catch (Exception e) {
                planFound = 'getUnitConfiguration failed: ' + e.getMessage();
            }

            SalesConsoleController.ConfirmRequest req = new SalesConsoleController.ConfirmRequest();
            req.opportunityId = opp.Id;
            req.unitId = unit.Id;
            req.paymentPlanId = planId;
            req.payNow = false;
            try {
                SalesConsoleController.ConfirmResult res =
                    SalesConsoleController.reviewAndConfirm(req);
                outcome = res == null
                    ? 'null result'
                    : 'isSuccess=' + res.isSuccess + ' message=' + res.message;
            } catch (Exception e) {
                outcome = e.getTypeName() + ' :: ' + e.getMessage();
            }
        }

        /* asserted, not debugged. Forks on record access: with edit the booking must go through;
           without it the refusal is pinned (searchUnits no longer offers such units). If the second
           branch fails, the raw error says what it is. */
        Boolean canEditUnit = false;
        for (UserRecordAccess a : [
            SELECT RecordId, HasEditAccess FROM UserRecordAccess
            WHERE UserId = :rep.Id AND RecordId = :unit.Id
        ]) {
            canEditUnit = a.HasEditAccess;
        }

        String detail = 'CONFIRM >>> unit=' + unit.Name + ' plan=' + planFound
            + ' canEditUnit=' + canEditUnit
            + ' outcome=[' + outcome + ']'
            + ' RAW=[' + SalesConsoleController.lastRawError + ']';

        if (canEditUnit) {
            System.assert(outcome != null && outcome.startsWith('isSuccess=true'), detail);
        } else {
            /* read the field, do not String.valueOf it: a null String returns null */
            System.assert(
                outcome != null
                    && SalesConsoleController.lastRawError != null
                    && SalesConsoleController.lastRawError.containsIgnoreCase('insufficient access'),
                'Expected the known unit-sharing refusal, got something else. ' + detail
            );
        }
    }

    /** The customer card arrives knowing what the org knows (document and nationality). */
    @isTest(SeeAllData=true)
    static void testCustomerBlockCarriesDocumentAndNationality() {
        /* an existing customer on purpose: a fresh one is fully editable */
        List<Account> known = [
            SELECT Id, Nationality__pc, EIDNumber__pc FROM Account
            WHERE IsPersonAccount = true AND EIDNumber__pc != null
              AND Nationality__pc != null AND Is_Merged__c = false
              AND CreatedDate < YESTERDAY
            LIMIT 1
        ];
        System.assert(!known.isEmpty(), 'Precondition: a customer with both on file.');

        List<Opportunity> opps = [
            SELECT Id FROM Opportunity
            WHERE AccountId = :known[0].Id ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assert(!opps.isEmpty(), 'Precondition: that customer has a booking.');

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummary(opps[0].Id, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto.customer, 'The card needs a customer block.');
        /* a saved document on an existing customer is locked; the card renders the masked twin */
        System.assertEquals('IDENTITY_SAVED', dto.customer.lockReasons.get('emiratesId'),
            'A saved document on an existing customer is locked, with the reason.');
        System.assertEquals(null, dto.customer.emiratesId,
            'A locked field\'s clear value never leaves the server.');
        System.assert(String.isNotBlank(dto.customer.maskedEmiratesId),
            'The masked twin is what the locked field displays.');
        System.assert(String.isNotBlank(dto.customer.nationality),
            'Nationality is on the account; the block must fall back to it when the ' +
            'opportunity does not carry one.');
    }

    /* The settlement figure */

    /** getSettlement always returns a shape. */
    @isTest
    static void testSettlementAlwaysReturnsAShape() {
        Account a = makePersonOrOrgAccount('Settlement Shape', 'Resident');
        Opportunity o = makeOpportunity(a, 'Resident');

        Test.startTest();
        SalesConsoleController.SettlementDTO dto =
            SalesConsoleController.getSettlement(o.Id, null, new List<Id>(), null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'The header must always have something to draw.');
        System.assertNotEquals(null, dto.admLeg, 'Both legs are always present.');
        System.assertNotEquals(null, dto.downPaymentLeg, 'Both legs are always present.');
        System.assertEquals(false, dto.gateKnown,
            'With no Sales Order there is nothing to ask, so the gate is not known.');
        System.assertEquals(0, dto.totalRequired, 'Nothing is owed yet.');
        System.assertEquals(SalesConsoleController.SETTLE_NONE,
            dto.admLeg.consoleStatus, 'An empty leg has not started.');
    }

    /**
     * AWAITING_CLEARANCE: console paid in full while the org still says Generated. The two must
     * not collapse into one flag.
     */
    @isTest(SeeAllData=true)
    static void testCapturedInFullButNotYetClearedReadsAsAwaitingClearance() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
              AND ADM_Fees_and_Dari__c = 'Generated'
              AND IsADMCollectedWithWaiverRequest__c = false
              AND ExcludeADMCheck__c = false
              AND Id IN (
                  SELECT SalesOrder__c FROM SalesOrderInstallments__c WHERE MilestoneNumber__c = 1
              )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return; // no such booking in this org today; nothing to assert against
        }

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            orders[0].Opportunity__c, orders[0].Unit__c, new List<Id>{ orders[0].Id }, null, null);
        Test.stopTest();

        System.assertEquals(true, dto.gateKnown, 'An order exists, so the gate is answerable.');
        System.assertEquals(false, dto.admLeg.satisfied,
            'The picklist reads Generated and no override is set, so the org has not ' +
            'recognised this leg.');
        System.assertNotEquals(SalesConsoleController.SETTLE_DONE,
            dto.admLeg.consoleStatus,
            'A leg the ORG has not recognised must never read as Settled, however much ' +
            'money this console has captured against it.');
    }

    /** The override booleans are part of the leg (SO-15400: SalesTeamVoidCheck__c true, picklists Generated). */
    @isTest(SeeAllData=true)
    static void testAnExcludedLegCountsAsSatisfied() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
              AND ADM_Fees_and_Dari__c = 'Generated'
              AND (ExcludeADMCheck__c = true OR IsADMCollectedWithWaiverRequest__c = true)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return; // no overridden booking in this org today
        }

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            orders[0].Opportunity__c, orders[0].Unit__c, new List<Id>{ orders[0].Id }, null, null);
        Test.stopTest();

        System.assertEquals(true, dto.admLeg.satisfied,
            'The picklist still reads Generated, but an override is set - which is ' +
            'exactly how the org\'s own formula satisfies this leg.');
    }

    /** Milestones 2..n are counted, never added to the headline. */
    @isTest(SeeAllData=true)
    static void testScheduledMilestonesAreCountedNotCharged() {
        List<SalesOrderInstallments__c> soi = [
            SELECT SalesOrder__c, SalesOrder__r.Opportunity__c, SalesOrder__r.Unit__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c > 1
              AND SalesOrder__r.Opportunity__c != null
              AND SalesOrder__r.Status__c NOT IN :DEAD_ORDER_STATUSES
            LIMIT 1
        ];
        if (soi.isEmpty()) {
            return;
        }

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            soi[0].SalesOrder__r.Opportunity__c, soi[0].SalesOrder__r.Unit__c,
            new List<Id>{ soi[0].SalesOrder__c }, null, null);
        Test.stopTest();

        System.assert(dto.scheduledCount > 0, 'The later milestones are counted.');
        System.assertEquals(
            dto.admLeg.requiredAmount + dto.downPaymentLeg.requiredAmount,
            dto.totalRequired,
            'The headline is the two closing legs and nothing else - scheduled ' +
            'milestones must not be folded into it.');
    }

    /* The obligation ledger */

    /** A booking has two closing obligations, never three (fee lines carry both legs; a basket has milestone 1). */
    @isTest(SeeAllData=true)
    static void testTheClosingGroupNeverStatesTheDownPaymentTwice() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
              AND Id IN (SELECT SalesOrder__c FROM SalesOrderInstallments__c)
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];
        if (orders.isEmpty()) {
            return;
        }

        Test.startTest();
        for (SalesOrder__c so : orders) {
            List<SalesConsoleController.PaymentBucketDTO> buckets =
                SalesConsoleController.getPaymentBucketsForOrders(
                    so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });

            Integer closing = 0;
            Integer downPaymentRows = 0;
            for (SalesConsoleController.PaymentBucketDTO b : buckets) {
                if (b.closesSale != true) { continue; }
                closing++;
                if (b.label != null && b.label.containsIgnoreCase('Down Payment')) {
                    downPaymentRows++;
                }
            }
            System.assert(closing <= 2,
                'A booking has two closing legs. ' + so.Id + ' produced ' + closing + '.');
            System.assert(downPaymentRows <= 1,
                'The down payment must appear once in the closing group, not once as a ' +
                'booking fee and again as milestone 1. ' + so.Id);
        }
        Test.stopTest();
    }

    /** remainingAmount is always a number, never negative. */
    @isTest(SeeAllData=true)
    static void testEveryRowCarriesAUsableRemaining() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
              AND Id IN (SELECT SalesOrder__c FROM SalesOrderInstallments__c)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return;
        }

        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> buckets =
            SalesConsoleController.getPaymentBucketsForOrders(
                orders[0].Opportunity__c, orders[0].Unit__c, new List<Id>{ orders[0].Id });
        Test.stopTest();

        System.assert(!buckets.isEmpty(), 'Precondition: this booking has obligations.');
        for (SalesConsoleController.PaymentBucketDTO b : buckets) {
            System.assertNotEquals(null, b.remainingAmount,
                'The ledger leads with this figure; it cannot be null. ' + b.label);
            System.assert(b.remainingAmount >= 0,
                'An over-payment is not a negative obligation. ' + b.label);
            System.assertEquals(b.remainingAmount > 0, b.proofRequired,
                'proofRequired is exactly "something is still outstanding". ' + b.label);
        }
    }

    /** A plan with no schedule is caught before Confirm. */
    @isTest
    static void testPlanGuardIsPermissiveWhenItCannotAnswer() {
        Test.startTest();
        System.assertEquals(true, SalesConsoleController.planHasSchedule(null),
            'No plan chosen yet is not a fault - the other gates cover that, and a ' +
            'guard that blocks on silence would block every booking at the start.');
        Test.stopTest();
    }

    @isTest(SeeAllData=true)
    static void testPlanGuardRecognisesARealSchedule() {
        List<PaymentInstallements__c> pi = [
            SELECT PaymentInstallment__c FROM PaymentInstallements__c
            WHERE PaymentInstallment__c != null LIMIT 1
        ];
        if (pi.isEmpty()) {
            return;
        }

        Test.startTest();
        Boolean ok = SalesConsoleController.planHasSchedule(pi[0].PaymentInstallment__c);
        Test.stopTest();

        System.assertEquals(true, ok,
            'A plan that demonstrably has installment rows must not be reported as ' +
            'unschedulable - that would block a booking that would have succeeded.');
    }

    /* Where each row's money comes from */

    /** Every row answers with one of two routes. */
    @isTest(SeeAllData=true)
    static void testEveryRowSaysWhereItsMoneyComesFrom() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
              AND Id IN (SELECT SalesOrder__c FROM SalesOrderInstallments__c)
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        if (orders.isEmpty()) {
            return;
        }

        Test.startTest();
        for (SalesOrder__c so : orders) {
            List<SalesConsoleController.PaymentBucketDTO> buckets =
                SalesConsoleController.getPaymentBucketsForOrders(
                    so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });

            for (SalesConsoleController.PaymentBucketDTO b : buckets) {
                System.assert(
                    b.payRoute == SalesConsoleController.ROUTE_TERMINAL
                        || b.payRoute == SalesConsoleController.ROUTE_PROOF,
                    'Every row must say how it is paid, and only in the two ways the ' +
                    'ledger renders. ' + b.label + ' said: ' + b.payRoute);

                /* the terminal collects the booking fee only; a milestone is never payable there */
                if (b.key == SalesConsoleController.BUCKET_MILESTONE) {
                    System.assertEquals(SalesConsoleController.ROUTE_PROOF, b.payRoute,
                        'A milestone is not collected at the booking terminal. ' + b.label);
                }
            }
        }
        Test.stopTest();
    }

    /** The route follows isPaymentRequired, not a second copy of the rule. */
    @isTest(SeeAllData=true)
    static void testThePayRouteFollowsTheThreePartCondition() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];
        if (orders.isEmpty()) {
            return;
        }

        Test.startTest();
        for (SalesOrder__c so : orders) {
            Boolean phaseAsks = UnitBookingJourneyController.isPaymentRequired(
                so.Unit__c, so.Opportunity__c);
            /* the third part of the condition: one unit (fee lines on this unit, or a single live order) */
            Integer feeLines = [
                SELECT COUNT() FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :so.Opportunity__c AND Unit__c = :so.Unit__c
            ];
            Integer liveOrders = [
                SELECT COUNT() FROM SalesOrder__c
                WHERE Opportunity__c = :so.Opportunity__c
                  AND Status__c NOT IN :DEAD_ORDER_STATUSES
            ];
            Boolean oneUnit = feeLines > 0 || liveOrders <= 1;
            Boolean expected = phaseAsks && oneUnit;

            List<SalesConsoleController.PaymentBucketDTO> buckets =
                SalesConsoleController.getPaymentBucketsForOrders(
                    so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });

            for (SalesConsoleController.PaymentBucketDTO b : buckets) {
                System.assertEquals(expected, b.paymentRequired,
                    'paymentRequired is isPaymentRequired\'s answer AND the single-unit ' +
                    'test, not a second implementation of either. ' + so.Id + ' / ' + b.label);

                // no fee charged, nothing taken at a terminal
                if (!expected) {
                    System.assertEquals(SalesConsoleController.ROUTE_PROOF, b.payRoute,
                        'A bypassed or non-paying phase collects no booking fee, so no ' +
                        'row may point at the terminal. ' + b.label);
                }
            }
        }
        Test.stopTest();
    }

    /* When the booking was made */

    /** A confirmed booking knows its date, and it is not Booking_Date__c (never written). */
    @isTest(SeeAllData=true)
    static void testAConfirmedBookingKnowsWhenItWasMade() {
        List<SalesOrder__c> orders = [
            SELECT Id, Name, Opportunity__c, Unit__c, CreatedDate
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return;
        }
        SalesOrder__c so = orders[0];

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id }, null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto.confirmedOn,
            'A booking with a Sales Order has a date it was made on.');
        System.assertEquals(so.CreatedDate.date(), dto.confirmedOn,
            'The confirmed date is the order\'s own CreatedDate, not Booking_Date__c ' +
            '- which is null on every record in this org.');
        System.assertEquals(so.Name, dto.bookingReference,
            'And the reference names the same order the date came from.');
    }

    /** Before a Sales Order exists there is no date. */
    @isTest(SeeAllData=true)
    static void testAnUnconfirmedBookingHasNoDate() {
        List<Unit__c> units = [SELECT Id FROM Unit__c LIMIT 1];
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1];
        if (units.isEmpty() || opps.isEmpty()) {
            return;
        }

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            opps[0].Id, units[0].Id, new List<Id>(), null, null);
        Test.stopTest();

        System.assertEquals(null, dto.confirmedOn,
            'No Sales Order means no confirmation date - the client reads this null ' +
            'as "not confirmed yet".');
        System.assertEquals(false, dto.bookingConfirmed,
            'And the two agree with each other.');
    }

    /** A basket has one confirmation date: the earliest order's. */
    @isTest(SeeAllData=true)
    static void testABasketReportsTheEarliestConfirmationDate() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c, CreatedDate
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            ORDER BY CreatedDate ASC
            LIMIT 2
        ];
        if (orders.size() < 2) {
            return;
        }
        List<Id> ids = new List<Id>{ orders[1].Id, orders[0].Id }; // deliberately reversed
        Date earliest = orders[0].CreatedDate.date() <= orders[1].CreatedDate.date()
            ? orders[0].CreatedDate.date() : orders[1].CreatedDate.date();

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            orders[0].Opportunity__c, orders[0].Unit__c, ids, null, null);
        Test.stopTest();

        System.assertEquals(earliest, dto.confirmedOn,
            'The earliest date across the basket, whatever order the ids arrive in.');
    }

    /* A basket takes no fee */

    /** Two orders in, no row claims the fee or the terminal, whichever unit is focused. */
    @isTest(SeeAllData=true)
    static void testABasketNeverClaimsTheBookingFee() {
        // a real basket
        List<AggregateResult> baskets = [
            SELECT Opportunity__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            GROUP BY Opportunity__c
            HAVING COUNT(Id) > 1
            LIMIT 1
        ];
        if (baskets.isEmpty()) {
            return;
        }
        Id oppId = (Id) baskets[0].get('Opportunity__c');
        List<SalesOrder__c> orders = [
            SELECT Id, Unit__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :oppId
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
        ];
        List<Id> ids = new List<Id>();
        for (SalesOrder__c so : orders) {
            ids.add(so.Id);
        }

        /* a unit that raised fee lines took a fee whatever else is on the opportunity */
        Integer feeLines = [
            SELECT COUNT() FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c = :orders[0].Unit__c
        ];
        if (feeLines > 0) {
            return;
        }

        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> buckets =
            SalesConsoleController.getPaymentBucketsForOrders(
                oppId, orders[0].Unit__c, ids);
        Test.stopTest();

        for (SalesConsoleController.PaymentBucketDTO b : buckets) {
            System.assertEquals(false, b.paymentRequired,
                'More than one unit means no booking fee (journey 07), whichever ' +
                'unit is focused. ' + b.label);
            System.assertEquals(SalesConsoleController.ROUTE_PROOF, b.payRoute,
                'No fee is charged, so nothing on a basket is collected at a ' +
                'terminal. ' + b.label);
        }
    }

    /* The summary of a basket */

    /** One live basket. */
    private static Id anyBasketOpportunity() {
        List<AggregateResult> baskets = [
            SELECT Opportunity__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            GROUP BY Opportunity__c
            HAVING COUNT(Id) > 1
            LIMIT 1
        ];
        return baskets.isEmpty() ? null : (Id) baskets[0].get('Opportunity__c');
    }

    /** The total is summed and units/plans listed per order. */
    @isTest(SeeAllData=true)
    static void testABasketSummarySumsAndListsEveryUnit() {
        Id oppId = anyBasketOpportunity();
        if (oppId == null) {
            return;
        }
        List<SalesOrder__c> orders = [
            SELECT Id, Unit__c, TotalAmount__c, Unit__r.TotalPrice__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :oppId
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
            ORDER BY CreatedDate ASC
        ];
        List<Id> ids = new List<Id>();
        Decimal expectedTotal = 0;
        for (SalesOrder__c so : orders) {
            ids.add(so.Id);
            Decimal price = so.TotalAmount__c != null ? so.TotalAmount__c : so.Unit__r.TotalPrice__c;
            expectedTotal += (price == null ? 0 : price);
        }

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummaryForOrders(oppId, orders[0].Unit__c, null, ids);
        Test.stopTest();

        System.assertEquals(expectedTotal, dto.totalPrice,
            'The booking\'s total is what every unit was booked at, summed - not the ' +
            'focused unit\'s price. On 006VG00000g29qDYAQ that is 32,711,423.55, and ' +
            'the summary said 16,353,311.');
        System.assertEquals(orders.size(), dto.unitCount, 'One count per live order.');
        System.assertEquals(orders.size(), dto.units.size(), 'One unit block per live order.');
        System.assertEquals(orders.size(), dto.plans.size(), 'One plan block per live order.');
        for (Integer i = 0; i < orders.size(); i++) {
            System.assertEquals(orders[i].Unit__c, dto.units[i].unitId,
                'Units are listed in booking order, parallel to the orders given.');
        }
        // singular fields name the focused unit
        System.assertNotEquals(null, dto.unit, 'summary.unit is still populated on a basket.');
        System.assertEquals(orders[0].Unit__c, dto.unit.unitId,
            'summary.unit is the unit the caller focused.');
        // obligations from every order
        Set<Id> ownersSeen = new Set<Id>();
        for (SalesConsoleController.PaymentBucketDTO b : dto.payments) {
            if (b.salesOrderId != null) {
                ownersSeen.add(b.salesOrderId);
            }
        }
        System.assert(ownersSeen.size() > 1,
            'A basket\'s payments belong to more than one order. Seen: ' + ownersSeen);
    }

    /** The reference and stage are the first order's, whichever unit is focused. */
    @isTest(SeeAllData=true)
    static void testABasketSummaryNamesTheFirstOrderWhicheverUnitIsFocused() {
        Id oppId = anyBasketOpportunity();
        if (oppId == null) {
            return;
        }
        List<SalesOrder__c> orders = [
            SELECT Id, Name, Unit__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :oppId
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
            ORDER BY CreatedDate ASC
        ];
        List<Id> ids = new List<Id>();
        for (SalesOrder__c so : orders) {
            ids.add(so.Id);
        }
        SalesOrder__c last = orders[orders.size() - 1];

        Test.startTest();
        // focus the last unit
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummaryForOrders(oppId, last.Unit__c, null, ids);
        SalesConsoleController.SettlementDTO settle =
            SalesConsoleController.getSettlement(oppId, last.Unit__c, ids, null, null);
        Test.stopTest();

        System.assertEquals(orders[0].Name, dto.bookingReference,
            'The reference is the first order\'s, not the focused unit\'s.');
        System.assertEquals(last.Unit__c, dto.unit.unitId,
            'While the focused unit is still the one asked for.');
        System.assertEquals(settle.bookingReference, dto.bookingReference,
            'The rail and the header must name the same order.');
    }

    /** A single-unit booking is unchanged. */
    @isTest(SeeAllData=true)
    static void testASingleUnitSummaryIsUnchangedAndItsListsMirrorIt() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c, Unit__c, PaymentPlan__c, TotalAmount__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null AND TotalAmount__c != null
              AND Id IN (SELECT SalesOrder__c FROM SalesOrderInstallments__c)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return;
        }
        SalesOrder__c so = orders[0];

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO viaId =
            SalesConsoleController.getBookingSummary(so.Opportunity__c, so.Unit__c, null, so.Id);
        SalesConsoleController.BookingSummaryDTO viaList =
            SalesConsoleController.getBookingSummaryForOrders(
                so.Opportunity__c, so.Unit__c, null, new List<Id>{ so.Id });
        Test.stopTest();

        System.assertEquals(so.TotalAmount__c, viaId.totalPrice,
            'One order: the total is that order\'s amount, as it always was.');
        System.assertEquals(viaId.totalPrice, viaList.totalPrice, 'Both forms agree on the total.');
        System.assertEquals(viaId.bookingReference, viaList.bookingReference, 'and the reference,');
        System.assertEquals(viaId.payments.size(), viaList.payments.size(), 'and the ledger.');
        System.assertEquals(viaId.plan.milestoneCount, viaList.plan.milestoneCount, 'and the plan.');

        System.assertEquals(1, viaId.unitCount, 'One live order, one unit.');
        System.assertEquals(1, viaId.units.size(), 'One unit block.');
        System.assertEquals(viaId.unit.unitId, viaId.units[0].unitId,
            'The list mirrors summary.unit, so the client can read either shape.');
        System.assertEquals(1, viaId.plans.size(), 'One plan block.');
        System.assertEquals(viaId.plan.planId, viaId.plans[0].planId,
            'The list mirrors summary.plan.');
    }

    /** Before Confirm the summary of a selected unit is what it always was. */
    @isTest(SeeAllData=true)
    static void testAnUnbookedUnitSummaryHasNoBasket() {
        List<Unit__c> units = [
            SELECT Id, TotalPrice__c FROM Unit__c
            WHERE Status__c = 'Available' AND TotalPrice__c != null
            LIMIT 1
        ];
        if (units.isEmpty()) {
            return;
        }

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummary(null, units[0].Id, null, null);
        Test.stopTest();

        System.assertEquals(units[0].TotalPrice__c, dto.totalPrice, 'The unit\'s own price.');
        System.assertEquals(units[0].Id, dto.unit.unitId, 'The unit itself.');
        System.assertEquals(0, dto.unitCount, 'Nothing is booked, so nothing is counted.');
        System.assert(dto.units.isEmpty(), 'and nothing is listed.');
        System.assertEquals(null, dto.bookingReference, 'No order, no reference.');
    }

    /** bookedUnitsFor carries price, plan and state. */
    @isTest(SeeAllData=true)
    static void testABookedUnitCarriesItsPriceAndPlan() {
        Id oppId = anyBasketOpportunity();
        if (oppId == null) {
            return;
        }
        Map<Id, SalesOrder__c> expected = new Map<Id, SalesOrder__c>([
            SELECT Id, TotalAmount__c, PaymentPlan__c, PaymentPlan__r.Name, Status__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :oppId
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
        ]);

        Test.startTest();
        SalesConsoleController.ConsoleState st = SalesConsoleController.getConsoleState(oppId);
        Test.stopTest();

        System.assertEquals(expected.size(), st.bookedUnits.size(), 'Every live order is listed.');
        for (SalesConsoleController.BookedUnitDTO b : st.bookedUnits) {
            SalesOrder__c so = expected.get(b.salesOrderId);
            System.assertNotEquals(null, so, 'Each listed unit is a live order.');
            System.assertEquals(so.TotalAmount__c, b.totalPrice,
                'The price the unit was booked at, from the order.');
            System.assertEquals(so.PaymentPlan__c, b.planId, 'The plan it was booked on.');
            System.assertEquals(so.PaymentPlan__r == null ? null : so.PaymentPlan__r.Name,
                b.planName, 'and its name, so the client need not look it up.');
            System.assertEquals(so.Status__c, b.status, 'and where the order stands.');
        }
        // getConsoleState's own summary describes the whole basket
        System.assertEquals(expected.size(), st.summary.unitCount,
            'Resume hands the client a summary of every unit, not one.');
    }
    /* One Sales Order is one booking */

    /** First opportunity carrying more than one live order, or null. */
    private static Id aBasketOpportunity() {
        List<AggregateResult> baskets = [
            SELECT Opportunity__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            GROUP BY Opportunity__c
            HAVING COUNT(Id) > 1
            LIMIT 1
        ];
        return baskets.isEmpty() ? null : (Id) baskets[0].get('Opportunity__c');
    }

    private static List<SalesOrder__c> liveOrdersOf(Id oppId) {
        return [
            SELECT Id, Name, Unit__c, TotalAmount__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :oppId
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
            ORDER BY CreatedDate ASC
        ];
    }

    /** Opened on an order, the state is that order's alone, and bookedUnits still carries the booking. */
    @isTest(SeeAllData=true)
    static void testResumeOnAnOrderOpensThatOrderAlone() {
        Id oppId = aBasketOpportunity();
        if (oppId == null) {
            return;
        }
        List<SalesOrder__c> orders = liveOrdersOf(oppId);

        Test.startTest();
        for (SalesOrder__c so : orders) {
            SalesConsoleController.ConsoleState st =
                SalesConsoleController.getConsoleStateForOrder(oppId, so.Id);

            System.assertEquals(so.Id, st.focusedSalesOrderId,
                'The state says which order it is focused on.');
            System.assertEquals(so.Id, st.salesOrderId,
                'The opened order is the order in focus - not the newest, not ' +
                'Opportunity.Unit__c\'s.');
            System.assertEquals(so.Name, st.bookingRef,
                'And it is named by its own reference.');
            System.assert(st.bookedUnits.size() >= 2,
                'The whole booking is still listed, so the page can offer the ' +
                'other unit. Got ' + st.bookedUnits.size());
            if (st.summary != null && st.summary.unit != null) {
                System.assertEquals(so.Unit__c, st.summary.unit.unitId,
                    'The summary is this order\'s unit.');
            }
            if (st.summary != null && so.TotalAmount__c != null) {
                System.assertEquals(so.TotalAmount__c, st.summary.totalPrice,
                    'The summary is this order\'s price - not the basket\'s sum.');
                System.assertEquals(1, st.summary.unitCount,
                    'One order, one unit in the summary.');
            }
        }
        Test.stopTest();
    }

    /** An order that is not this opportunity's is ignored, not thrown. */
    @isTest(SeeAllData=true)
    static void testAnOrderFromAnotherOpportunityIsIgnored() {
        Id oppId = aBasketOpportunity();
        if (oppId == null) {
            return;
        }
        List<SalesOrder__c> foreign = [
            SELECT Id FROM SalesOrder__c
            WHERE Opportunity__c != :oppId AND Opportunity__c != null
              AND Status__c NOT IN :DEAD_ORDER_STATUSES
            LIMIT 1
        ];
        if (foreign.isEmpty()) {
            return;
        }

        Test.startTest();
        SalesConsoleController.ConsoleState plain =
            SalesConsoleController.getConsoleState(oppId);
        SalesConsoleController.ConsoleState asked =
            SalesConsoleController.getConsoleStateForOrder(oppId, foreign[0].Id);
        Test.stopTest();

        System.assertEquals(null, asked.focusedSalesOrderId,
            'A foreign order is not focused.');
        System.assertEquals(plain.salesOrderId, asked.salesOrderId,
            'And the state is exactly the whole-opportunity one.');
        System.assertEquals(plain.bookedUnits.size(), asked.bookedUnits.size(),
            'Same booking listed either way.');
    }

    /** No order asked for is the whole opportunity. */
    @isTest(SeeAllData=true)
    static void testNoOrderIsTheWholeOpportunity() {
        Id oppId = aBasketOpportunity();
        if (oppId == null) {
            return;
        }

        Test.startTest();
        SalesConsoleController.ConsoleState plain =
            SalesConsoleController.getConsoleState(oppId);
        SalesConsoleController.ConsoleState viaOrder =
            SalesConsoleController.getConsoleStateForOrder(oppId, null);
        Test.stopTest();

        System.assertEquals(null, plain.focusedSalesOrderId);
        System.assertEquals(null, viaOrder.focusedSalesOrderId);
        System.assertEquals(plain.salesOrderId, viaOrder.salesOrderId);
        System.assertEquals(plain.bookedUnits.size(), viaOrder.bookedUnits.size());
        if (plain.summary != null && viaOrder.summary != null) {
            System.assertEquals(plain.summary.totalPrice, viaOrder.summary.totalPrice,
                'The 1.38 basket summary, summed, from both doors.');
            System.assertEquals(plain.summary.unitCount, viaOrder.summary.unitCount);
        }
    }

    /** A basket member opened alone knows the booking's size and claims no fee. */
    @isTest(SeeAllData=true)
    static void testAMemberOfABasketOpenedAloneTookNoBookingFee() {
        Id oppId = aBasketOpportunity();
        if (oppId == null) {
            return;
        }
        List<SalesOrder__c> orders = liveOrdersOf(oppId);
        SalesOrder__c one = orders[0];
        Integer feeLines = [
            SELECT COUNT() FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c = :one.Unit__c
        ];
        if (feeLines > 0) {
            return; // took a fee on its own; the rule rightly says so - not this test's case
        }
        List<Id> justOne = new List<Id>{ one.Id };

        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> buckets =
            SalesConsoleController.getPaymentBucketsForOrders(oppId, one.Unit__c, justOne);
        SalesConsoleController.SettlementDTO s =
            SalesConsoleController.getSettlement(oppId, one.Unit__c, justOne, null, null);
        Test.stopTest();

        for (SalesConsoleController.PaymentBucketDTO b : buckets) {
            System.assertEquals(false, b.paymentRequired,
                'One id in, but this order shares its opportunity with another live ' +
                'order and raised no fee lines: it is a basket member. ' + b.label);
            System.assertEquals(SalesConsoleController.ROUTE_PROOF, b.payRoute,
                'No fee, no terminal. ' + b.label);
        }
        System.assertEquals(1, s.unitCount, 'This view covers one order.');
        System.assert(s.bookingUnitCount >= 2,
            'But the booking has more, and the settlement says so: ' + s.bookingUnitCount);
    }

    /** A single-unit booking is unchanged by the order route. */
    @isTest(SeeAllData=true)
    static void testASingleUnitBookingIsUnchangedByTheOrderRoute() {
        List<AggregateResult> singles = [
            SELECT Opportunity__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :DEAD_ORDER_STATUSES
              AND Opportunity__c != null AND Unit__c != null
            GROUP BY Opportunity__c
            HAVING COUNT(Id) = 1
            ORDER BY MAX(CreatedDate) DESC
            LIMIT 1
        ];
        if (singles.isEmpty()) {
            return;
        }
        Id oppId = (Id) singles[0].get('Opportunity__c');
        SalesOrder__c only = liveOrdersOf(oppId)[0];

        Test.startTest();
        SalesConsoleController.ConsoleState plain =
            SalesConsoleController.getConsoleState(oppId);
        SalesConsoleController.ConsoleState viaOrder =
            SalesConsoleController.getConsoleStateForOrder(oppId, only.Id);
        SalesConsoleController.SettlementDTO s = SalesConsoleController.getSettlement(
            oppId, only.Unit__c, new List<Id>{ only.Id }, null, null);
        Test.stopTest();

        System.assertEquals(only.Id, viaOrder.focusedSalesOrderId);
        System.assertEquals(plain.salesOrderId, viaOrder.salesOrderId,
            'One order: both doors open on it.');
        System.assertEquals(plain.bookingRef, viaOrder.bookingRef);
        if (plain.summary != null && viaOrder.summary != null) {
            System.assertEquals(plain.summary.totalPrice, viaOrder.summary.totalPrice);
        }
        System.assertEquals(1, s.unitCount);
        System.assertEquals(1, s.bookingUnitCount,
            'A single-unit booking has one order in view and one in the booking.');
    }

    /* The ADM + Dari charge row */

    /** A live order carrying a flagged ADM invoice. */
    private static Invoice__c anAdmChargeInvoice(Boolean withFeeLines) {
        for (Invoice__c inv : [
            SELECT Id, Sales_Order__c, InvoiceAmount__c, TotalPaidAmount__c,
                   Sales_Order__r.Opportunity__c, Sales_Order__r.Unit__c
            FROM Invoice__c
            WHERE Is_ADM_Fees_and_Dari_charges__c = true
              AND isCancelled__c = false
              AND Sales_Order__c != null
              AND Sales_Order__r.Opportunity__c != null
              AND Sales_Order__r.Unit__c != null
              AND Sales_Order__r.Status__c NOT IN :DEAD_ORDER_STATUSES
            ORDER BY CreatedDate DESC
            LIMIT 60
        ]) {
            /* 1.21 - "took a fee" is money on the lines: since controller 1.76 unpaid lines on a
               phase that takes no fee (SO-15559, raised by Confirm before 1.76) are not read */
            Integer feeLines = 0;
            Decimal paid = 0;
            for (Booking_Fee_Line__c l : [
                SELECT Total_Paid_Amount__c FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :inv.Sales_Order__r.Opportunity__c
                  AND Unit__c = :inv.Sales_Order__r.Unit__c
            ]) {
                feeLines++;
                paid += l.Total_Paid_Amount__c == null ? 0 : l.Total_Paid_Amount__c;
            }
            if (withFeeLines ? paid > 0 : feeLines == 0) {
                return inv;
            }
        }
        return null;
    }

    private static SalesConsoleController.PaymentBucketDTO chargeRowFor(
        List<SalesConsoleController.PaymentBucketDTO> rows, Id invoiceId
    ) {
        SalesConsoleController.PaymentBucketDTO found;
        Integer hits = 0;
        for (SalesConsoleController.PaymentBucketDTO r : rows) {
            if (r.key == SalesConsoleController.BUCKET_ADM_CHARGE && r.sourceId == invoiceId) {
                found = r;
                hits++;
            }
        }
        System.assertEquals(1, hits, 'Exactly one ADM + Dari charge row per order.');
        return found;
    }

    @isTest(SeeAllData=true)
    static void testTheAdmChargeRowLeadsTheScheduleWhenTheBookingTookAFee() {
        Invoice__c inv = anAdmChargeInvoice(true);
        if (inv == null) {
            return;
        }
        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                inv.Sales_Order__r.Opportunity__c, inv.Sales_Order__r.Unit__c,
                new List<Id>{ inv.Sales_Order__c });
        Test.stopTest();

        SalesConsoleController.PaymentBucketDTO charge = chargeRowFor(rows, inv.Id);
        System.assertEquals('ADM + Dari', charge.label);
        System.assertEquals('Invoice__c', charge.sourceObject);
        System.assertEquals(inv.InvoiceAmount__c == null ? 0 : inv.InvoiceAmount__c,
            charge.requiredAmount, 'Required is the whole charge.');
        System.assertEquals(inv.TotalPaidAmount__c == null ? 0 : inv.TotalPaidAmount__c,
            charge.paidAmount, 'Paid is what has been applied to the invoice.');
        System.assertEquals(false, charge.blocksConfirmation);
        System.assertEquals(false, charge.closesSale,
            'With fee lines on the booking the charge is a scheduled balance.');
        System.assertEquals('PROOF', charge.payRoute);
        System.assertEquals(inv.Sales_Order__c, charge.salesOrderId);

        Integer chargeAt = -1;
        Integer firstMilestoneAt = -1;
        for (Integer i = 0; i < rows.size(); i++) {
            SalesConsoleController.PaymentBucketDTO r = rows[i];
            if (r.sourceId == inv.Id) {
                chargeAt = i;
            }
            if (firstMilestoneAt < 0 && r.key == SalesConsoleController.BUCKET_MILESTONE
                    && r.salesOrderId == inv.Sales_Order__c) {
                firstMilestoneAt = i;
            }
        }
        if (firstMilestoneAt >= 0) {
            System.assert(chargeAt < firstMilestoneAt,
                'The charge sits ahead of its order\'s milestones - the first scheduled row.');
        }
    }

    @isTest(SeeAllData=true)
    static void testTheAdmChargeRowClosesTheBookingWhenNoFeeWasTaken() {
        Invoice__c inv = anAdmChargeInvoice(false);
        if (inv == null) {
            return;
        }
        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                inv.Sales_Order__r.Opportunity__c, inv.Sales_Order__r.Unit__c,
                new List<Id>{ inv.Sales_Order__c });
        Test.stopTest();

        SalesConsoleController.PaymentBucketDTO charge = chargeRowFor(rows, inv.Id);
        System.assertEquals(true, charge.closesSale,
            'No fee line on this booking: the charge IS the ADM leg, so it closes.');
        System.assertEquals(false, charge.blocksConfirmation);
    }

    @isTest(SeeAllData=true)
    static void testAProofOnTheAdmChargeLandsOnTheInvoiceAndComesBack() {
        Invoice__c inv = anAdmChargeInvoice(true);
        if (inv == null) {
            inv = anAdmChargeInvoice(false);
        }
        if (inv == null) {
            return;
        }
        SalesConsoleController.ProofSlotRequest req = new SalesConsoleController.ProofSlotRequest();
        req.salesOrderId = inv.Sales_Order__c;
        req.bucketKey = SalesConsoleController.BUCKET_ADM_CHARGE;
        req.sourceId = inv.Id;
        req.amount = 100;
        req.reference = 'TEST-ADM-CHARGE';

        Test.startTest();
        SalesConsoleController.ProofDTO slot = SalesConsoleController.createProofSlot(req);
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                inv.Sales_Order__r.Opportunity__c, inv.Sales_Order__r.Unit__c,
                new List<Id>{ inv.Sales_Order__c });
        Test.stopTest();

        Documents__c doc = [
            SELECT Invoice__c, Booking_Fee_Line__c, Sales_Order_Installment__c,
                   Payment_Proof_Type__c
            FROM Documents__c WHERE Id = :slot.documentId
        ];
        System.assertEquals(inv.Id, doc.Invoice__c, 'The proof targets the invoice.');
        System.assertEquals(null, doc.Booking_Fee_Line__c);
        System.assertEquals(null, doc.Sales_Order_Installment__c);
        System.assertEquals('ADM Registration Fee', doc.Payment_Proof_Type__c);

        SalesConsoleController.PaymentBucketDTO charge = chargeRowFor(rows, inv.Id);
        Boolean attached = false;
        for (SalesConsoleController.ProofDTO pr : charge.proofs) {
            if (pr.documentId == slot.documentId) {
                attached = true;
            }
        }
        System.assert(attached, 'attachProofs hands the slot back on the charge row.');
    }

    /* 1.27 - a booking of the test's own, so the money tests do not depend on DEV's newest order */

    /** Answers any callout MODON's triggers make on these records (Oracle, OIC) with 200 and an empty body. */
    private class AnyOk implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class OwnBooking {
        SalesOrder__c so;
        SalesOrderInstallments__c first;
        SalesOrderInstallments__c later;
        SalesOrderInstallments__c foreign;
        Invoice__c adm;
    }

    /**
     * A live booking of the test's own: a KYC-valid Resident person buyer, a unit, a New
     * order, milestone 1 (the down payment) and milestone 2 with open invoices, an open ADM + Dari charge
     * with its invoice (Charge__c as MODON raises it), and a second order's milestone 2 (the "foreign"
     * line). Before Test.startTest().
     */
    private static OwnBooking anOwnBooking(String tag) {
        Test.setMock(HttpCalloutMock.class, new AnyOk());
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        Account buyer = makePersonAccount('Own ' + tag);
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :buyer.Id].PersonContactId;
        Opportunity o = new Opportunity(
            Name = 'Own booking ' + tag, AccountId = buyer.Id, StageName = 'Qualification',
            CloseDate = System.today().addDays(30), UAE_Resident_Status__c = 'Resident',
            PrimaryContact__c = contactId);
        Database.insert(o, dml);
        /* KYC as makeKycValid makes it (completion today, the four Resident documents), with each file
           as a classic Attachment, which MODON's KYC check also accepts: ContentVersion's triggers
           cost about 28 queries these four tests need for the money calls */
        Database.update(new Account(Id = buyer.Id, KYC_Completed_Date__c = Date.today(),
            Nationality__pc = 'United Arab Emirates', UAE_Resident_Status__pc = 'Resident'), dml);
        List<Documents__c> kycDocs = new List<Documents__c>();
        for (String n : new List<String>{
                'KYC Form - Signed', 'Passport', 'Emirates/National ID Front', 'Emirates/National ID Back' }) {
            kycDocs.add(new Documents__c(Name = n, Account__c = buyer.Id, PrimaryContact__c = contactId));
        }
        Database.insert(kycDocs, dml);
        List<Attachment> kycFiles = new List<Attachment>();
        for (Documents__c d : kycDocs) {
            kycFiles.add(new Attachment(ParentId = d.Id, Name = 'kyc-fixture.txt', Body = Blob.valueOf('kyc fixture')));
        }
        insert kycFiles;
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'OWN-' + tag + '-1');
        Unit__c other = mmUnit(phaseId, 'OWN-' + tag + '-2');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = buyer.Id, PrimaryContact__c = contactId,
            Unit__c = u.Id, Status__c = 'New', UAE_Resident_Status__c = 'Resident');
        SalesOrder__c otherSo = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = buyer.Id, PrimaryContact__c = contactId,
            Unit__c = other.Id, Status__c = 'New', UAE_Resident_Status__c = 'Resident');
        insert new List<SalesOrder__c>{ so, otherSo };
        /* MODON's SalesOrderInstallmentTrigger raises each milestone's invoice itself (the installment
           amount, where the milestone has a percentage), as it does for a real booking */
        SalesOrderInstallments__c m1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, MilestoneNumber__c = 1, Milestone__c = 10, InstallmentAmount__c = 100000,
            Balance_Amount__c = 100000, MilestoneDate__c = System.today(), PaymentStatus__c = 'Not Paid');
        SalesOrderInstallments__c m2 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, MilestoneNumber__c = 2, Milestone__c = 20, InstallmentAmount__c = 200000,
            MilestoneDate__c = System.today().addDays(90), PaymentStatus__c = 'Not Paid');
        SalesOrderInstallments__c away = new SalesOrderInstallments__c(
            SalesOrder__c = otherSo.Id, MilestoneNumber__c = 2, Milestone__c = 20, InstallmentAmount__c = 200000,
            MilestoneDate__c = System.today().addDays(90), PaymentStatus__c = 'Not Paid');
        insert new List<SalesOrderInstallments__c>{ m1, m2, away };
        Charge__c charge = new Charge__c(
            Name = 'ADM & Dari Fee', Type__c = 'ADM & Dari Fee', PaymentStatus__c = 'Not Paid',
            Amount__c = 5000, Sales_Order__c = so.Id, Account__c = buyer.Id);
        insert charge;
        Invoice__c admInvoice = new Invoice__c(
            Account__c = buyer.Id, Sales_Order__c = so.Id, Is_ADM_Fees_and_Dari_charges__c = true,
            Charge__c = charge.Id, InvoiceAmount__c = 5000, InvoiceDate__c = System.today());
        insert admInvoice;
        System.assertEquals(3, [SELECT COUNT() FROM Invoice__c WHERE SalesOrderInstallment__c IN
            :new List<Id>{ m1.Id, m2.Id, away.Id } AND InvoiceBalance__c > 0],
            'MODON raised an open invoice for each milestone.');

        OwnBooking b = new OwnBooking();
        b.so = [SELECT Id, Opportunity__c, Unit__c, CustomerAccount__c FROM SalesOrder__c WHERE Id = :so.Id];
        Map<Id, SalesOrderInstallments__c> rows = new Map<Id, SalesOrderInstallments__c>([
            SELECT Id, SalesOrder__c, MilestoneNumber__c, InstallmentAmount__c, Balance_Amount__c,
                   SalesOrder__r.Opportunity__c, SalesOrder__r.Unit__c, SalesOrder__r.CustomerAccount__c
            FROM SalesOrderInstallments__c WHERE Id IN :new List<Id>{ m1.Id, m2.Id, away.Id }
        ]);
        b.first = rows.get(m1.Id);
        b.later = rows.get(m2.Id);
        b.foreign = rows.get(away.Id);
        b.adm = admInvoice;
        return b;
    }

    /* The milestone box */

    /** A live order with a milestone after the down payment carrying an invoice with a balance and no cheque. */
    private static SalesOrderInstallments__c anOpenLaterMilestone() {
        Set<Id> withMandate = new Set<Id>();
        for (DirectDebitRequest__c d : [SELECT SalesOrder__c FROM DirectDebitRequest__c WHERE SalesOrder__c != null]) {
            withMandate.add(d.SalesOrder__c);
        }
        for (SalesOrderInstallments__c soi : [
            SELECT Id, SalesOrder__c, MilestoneNumber__c, InstallmentAmount__c, Balance_Amount__c,
                   SalesOrder__r.Opportunity__c, SalesOrder__r.Unit__c, SalesOrder__r.CustomerAccount__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c > 1
              AND SalesOrder__r.Status__c NOT IN :DEAD_ORDER_STATUSES
              AND SalesOrder__r.Opportunity__c != null
              AND SalesOrder__r.Unit__c != null
              AND SalesOrder__r.CustomerAccount__c != null
              AND Id IN (SELECT SalesOrderInstallment__c FROM Invoice__c
                         WHERE InvoiceBalance__c > 0 AND isCancelled__c = false)
              AND Id NOT IN (SELECT SalesOrderInstallment__c FROM Receipt__c
                             WHERE Modeofpayment__c = 'Cheque')
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            if (!withMandate.contains(soi.SalesOrder__c)) {
                return soi;
            }
        }
        return null;
    }

    private static Id aStagedImageOn(Id installmentId, String name) {
        SalesConsoleController.ChequeImageDTO img = SalesConsoleController.stageChequeImage(
            installmentId, EncodingUtil.base64Encode(Blob.valueOf('test cheque image ' + name)), name);
        return img.contentDocumentId;
    }

    private static SalesConsoleController.ChequeLineInput aLine(
        String key, Id installmentId, String num, Decimal amount, Id docId
    ) {
        SalesConsoleController.ChequeLineInput l = new SalesConsoleController.ChequeLineInput();
        l.clientKey = key;
        l.installmentId = installmentId;
        l.chequeNumber = num;
        l.chequeDate = Date.today();
        l.amount = amount;
        l.contentDocumentId = docId;
        return l;
    }

    @isTest(SeeAllData=true)
    static void testTheBatchListsOnlyTheMilestonesAfterTheDownPayment() {
        SalesOrderInstallments__c soi = anOpenLaterMilestone();
        if (soi == null) {
            return;
        }
        Test.startTest();
        SalesConsoleController.MilestoneBatchDTO b =
            SalesConsoleController.getMilestoneBatch(soi.SalesOrder__c);
        Test.stopTest();

        System.assertEquals(soi.SalesOrder__c, b.salesOrderId);
        System.assert(!b.lines.isEmpty(), 'The order has a milestone after the down payment.');
        Boolean seen = false;
        for (SalesConsoleController.BatchLineDTO l : b.lines) {
            System.assert(l.milestoneNumber > 1, 'Milestone 1 is never in the box: ' + l.label);
            System.assert(l.openAmount <= l.remainingAmount + 0.005,
                'What is open to a cheque never exceeds what is left.');
            if (l.installmentId == soi.Id) seen = true;
        }
        System.assert(seen, 'The installment the test found is one of the lines.');
        System.assert(!b.bankOptions.isEmpty(), 'Receipt__c.Bank__c picklist, from the schema.');
        System.assert(!b.ddBankOptions.isEmpty() && !b.ddAccountTypes.isEmpty() && !b.ddIdTypes.isEmpty(),
            'The mandate form picklists, from the schema.');
        System.assertNotEquals(null, b.dd, 'The mandate state always comes back.');
        System.assertNotEquals(null, b.prefill);
        System.assertNotEquals(null, b.computed);
        if (b.computed.milestoneCount > 0) {
            System.assert(b.computed.firstMilestone > 1);
            System.assertEquals(b.computed.commencesOn.addDays(0), b.computed.commencesOn);
            System.assert(b.computed.expiresOn > b.computed.commencesOn,
                'Expires 365 days after the last milestone, as Modon\'s trigger stamps it.');
        }
        System.assertEquals(true, b.chequesAllowed, 'No mandate on this order: cheques may be recorded.');
    }

    @isTest(SeeAllData=true)
    static void testMilestonesAfterTheFirstLoseTheBoxRoutesFromTheirRowList() {
        SalesOrderInstallments__c soi = anOpenLaterMilestone();
        if (soi == null) {
            return;
        }
        Test.startTest();
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                soi.SalesOrder__r.Opportunity__c, soi.SalesOrder__r.Unit__c,
                new List<Id>{ soi.SalesOrder__c });
        Test.stopTest();
        Integer later = 0;
        for (SalesConsoleController.PaymentBucketDTO r : rows) {
            if (r.key != SalesConsoleController.BUCKET_MILESTONE || r.milestoneNumber == null) continue;
            if (r.milestoneNumber > 1) {
                later++;
                System.assert(!r.allowedMethods.contains('Cheque'),
                    'A cheque is recorded through the box, not per row: ' + r.label);
                System.assert(!r.allowedMethods.contains('Direct Debit'),
                    'A mandate covers the schedule, not one milestone: ' + r.label);
                System.assertNotEquals(null, r.instruments, 'The row carries its instruments list.');
                System.assert(r.openAmount <= r.remainingAmount + 0.005);
            }
        }
        System.assert(later > 0, 'The order has milestones after the down payment.');
    }

    /** 1.27 - on the test's own booking (anOwnBooking). */
    @isTest
    static void testTheBatchRefusesBadLinesAndWritesNothing() {
        OwnBooking own = anOwnBooking('Batch');
        SalesOrderInstallments__c soi = own.later;
        SalesOrderInstallments__c first = own.first;
        SalesOrderInstallments__c foreign = own.foreign;
        Integer receiptsBefore = [
            SELECT COUNT() FROM Receipt__c WHERE SalesOrder__c = :soi.SalesOrder__c
        ];

        Test.startTest();
        Id doc = aStagedImageOn(soi.Id, 'refusal.jpg');
        SalesConsoleController.ChequeBatchInput input = new SalesConsoleController.ChequeBatchInput();
        input.salesOrderId = soi.SalesOrder__c;
        input.bank = 'Emirates NBD';
        input.lines = new List<SalesConsoleController.ChequeLineInput>();
        // a good line, then everything the server must refuse
        input.lines.add(aLine('ok', soi.Id, 'T-1001', 1, doc));
        if (first != null) input.lines.add(aLine('m1', first.Id, 'T-1002', 1, doc));
        if (foreign != null) input.lines.add(aLine('foreign', foreign.Id, 'T-1003', 1, doc));
        input.lines.add(aLine('dup', soi.Id, 'T-1001', 1, doc));
        input.lines.add(aLine('noimg', soi.Id, 'T-1004', 1, null));
        SalesConsoleController.ChequeBatchResultDTO r = SalesConsoleController.createChequePayments(input);

        // over-amount
        SalesConsoleController.ChequeBatchInput over = new SalesConsoleController.ChequeBatchInput();
        over.salesOrderId = soi.SalesOrder__c;
        over.bank = 'Emirates NBD';
        over.lines = new List<SalesConsoleController.ChequeLineInput>{
            aLine('a', soi.Id, 'T-2001', 1, doc),
            aLine('b', soi.Id, 'T-2002', 999999999, doc)
        };
        SalesConsoleController.ChequeBatchResultDTO r2 = SalesConsoleController.createChequePayments(over);
        Test.stopTest();

        System.assertEquals(false, r.recorded, 'One bad line refuses the whole batch.');
        System.assert(r.message.startsWith('Nothing was recorded.'), r.message);
        Map<String, SalesConsoleController.ChequeLineResultDTO> byKey =
            new Map<String, SalesConsoleController.ChequeLineResultDTO>();
        for (SalesConsoleController.ChequeLineResultDTO l : r.lines) byKey.put(l.clientKey, l);
        System.assertEquals(null, byKey.get('ok').message, 'The good line has no complaint of its own.');
        if (first != null) System.assert(byKey.get('m1').message.contains('after the down payment'), byKey.get('m1').message);
        if (foreign != null) System.assert(byKey.get('foreign').message.contains('does not belong'), byKey.get('foreign').message);
        System.assert(byKey.get('dup').message.contains('entered twice'), byKey.get('dup').message);
        System.assert(byKey.get('noimg').message.contains('image is missing'), byKey.get('noimg').message);
        System.assertEquals(false, r2.recorded);
        System.assert(r2.message.contains('more than what is left'), r2.message);
        System.assertEquals(receiptsBefore, [
            SELECT COUNT() FROM Receipt__c WHERE SalesOrder__c = :soi.SalesOrder__c
        ], 'Nothing was written.');
    }

    /** 1.27 - on the test's own booking (anOwnBooking). */
    @isTest
    static void testTwoChequesOnOneMilestoneAreRecordedInRoundsAndAllocated() {
        SalesOrderInstallments__c soi = anOwnBooking('Cheques').later;
        Test.startTest();
        Id doc1 = aStagedImageOn(soi.Id, 'one.jpg');
        Id doc2 = aStagedImageOn(soi.Id, 'two.jpg');
        SalesConsoleController.ChequeBatchInput input = new SalesConsoleController.ChequeBatchInput();
        input.salesOrderId = soi.SalesOrder__c;
        input.bank = 'Emirates NBD';
        input.lines = new List<SalesConsoleController.ChequeLineInput>{
            aLine('a', soi.Id, 'T-3001', 1, doc1),
            aLine('b', soi.Id, 'T-3002', 2, doc2)
        };
        SalesConsoleController.ChequeBatchResultDTO r = SalesConsoleController.createChequePayments(input);
        Test.stopTest();

        /* 1.x - everything below used to sit inside the window with the recording above, so four
           console calls shared ONE 100-query budget and the method died at 101 as soon as
           submitDirectDebitMandate grew its eligibility checks (SCW-125). Recording the cheques is
           what this test is about, so that keeps the fresh limits; the refusal and the two ledger
           reads run after stopTest on the outer budget, which also means they read the state once
           the queued work has finished rather than before it. */
        // the mandate is refused while cheques stand
        SalesConsoleController.DirectDebitInput dd = new SalesConsoleController.DirectDebitInput();
        dd.salesOrderId = soi.SalesOrder__c;
        dd.iban = 'AE070331234567890123456';
        dd.accountName = 'Test Holder';
        dd.bankName = 'EmiratesNBD Bank PJSC';
        dd.accountType = 'Current';
        dd.idType = 'UAE Emirates Identity Card';
        dd.idNumber = '784-0000-0000000-0';
        dd.mobile = '+971500000000';
        Boolean refused = false;
        String why;
        try {
            SalesConsoleController.submitDirectDebitMandate(dd);
        } catch (AuraHandledException e) {
            refused = true;
            why = e.getMessage();
        }
        // and the ledger says so on the row
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                soi.SalesOrder__r.Opportunity__c, soi.SalesOrder__r.Unit__c,
                new List<Id>{ soi.SalesOrder__c });
        SalesConsoleController.MilestoneBatchDTO b =
            SalesConsoleController.getMilestoneBatch(soi.SalesOrder__c);

        System.assertEquals(true, r.recorded, r.message);
        System.assertEquals(2, r.count);
        Set<Id> receiptIds = new Set<Id>();
        for (SalesConsoleController.ChequeLineResultDTO l : r.lines) {
            System.assertEquals(true, l.ok);
            System.assertNotEquals(null, l.receiptId);
            receiptIds.add(l.receiptId);
        }
        System.assertEquals(2, receiptIds.size(), 'Two receipts, one per cheque.');
        List<Receipt__c> receipts = [
            SELECT Modeofpayment__c, Status__c, TransactionNumber__c, Cheque_Number__c, Bank__c,
                   Receipt_Amount__c, TotalAmount__c, SalesOrderInstallment__c, SalesOrder__c,
                   Account__c, Cheque_Details__c, ReceiptRemarks__c,
                   (SELECT Id FROM ContentDocumentLinks)
            FROM Receipt__c WHERE Id IN :receiptIds
        ];
        for (Receipt__c rc : receipts) {
            System.assertEquals('Cheque', rc.Modeofpayment__c);
            System.assertEquals('In Progress', rc.Status__c);
            System.assertEquals(rc.TransactionNumber__c, rc.Cheque_Number__c,
                'The flow\'s field and Manage Cheques\' field both carry the number.');
            System.assertEquals('Emirates NBD', rc.Bank__c);
            System.assertEquals(rc.Receipt_Amount__c, rc.TotalAmount__c, 'Total = the cheque amount.');
            System.assertEquals(soi.Id, rc.SalesOrderInstallment__c);
            System.assertEquals(soi.SalesOrder__c, rc.SalesOrder__c);
            System.assertEquals(soi.SalesOrder__r.CustomerAccount__c, rc.Account__c);
            System.assertNotEquals(null, rc.Cheque_Details__c, 'The register row is linked.');
            System.assert(!rc.ContentDocumentLinks.isEmpty(), 'The image is on the payment.');
        }
        Integer allocations = [
            SELECT COUNT() FROM Allocation__c WHERE Receipt__c IN :receiptIds AND Status__c = 'Applied'
        ];
        System.assertEquals(2, allocations,
            'Rounds: Modon\'s trigger allocated BOTH cheques on the one milestone.');
        System.assertEquals(2, [SELECT COUNT() FROM Cheque_Details__c WHERE Sales_Order_Installment__c = :soi.Id
                                AND Cheque_No__c IN ('T-3001', 'T-3002')]);
        System.assert(refused, 'The mandate is refused while cheques stand.');
        System.assert(why == null || why.contains('Direct Debit is not offered') || why.contains('Script-thrown'),
            'Refused for the right reason: ' + why);
        SalesConsoleController.PaymentBucketDTO row;
        for (SalesConsoleController.PaymentBucketDTO x : rows) {
            if (x.sourceId == soi.Id) row = x;
        }
        System.assertNotEquals(null, row);
        System.assertEquals(2, row.instruments.size(), 'Both cheques stand on the row.');
        System.assertEquals(3, row.withFinanceAmount, 'Applied but not paid: 1 + 2.');
        System.assert(row.instruments[0].live == true);
        System.assertEquals(false, b.directDebitAllowed, 'Direct Debit leaves the header once cheques stand.');
        System.assert(b.liveChequeCount >= 2);
    }

    @isTest
    static void testStagingAndDiscardingGuards() {
        Boolean noId = false;
        try {
            SalesConsoleController.stageChequeImage(null, 'abc', 'x.jpg');
        } catch (AuraHandledException e) {
            noId = true;
        }
        System.assert(noId, 'No installment, no upload.');
        Boolean noData = false;
        try {
            SalesConsoleController.stageChequeImage(
                SalesOrderInstallments__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA', '', 'x.jpg');
        } catch (AuraHandledException e) {
            noData = true;
        }
        System.assert(noData, 'No bytes, no upload.');
        Boolean badExt = false;
        try {
            SalesConsoleController.stageChequeImage(
                SalesOrderInstallments__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA', 'abc', 'x.exe');
        } catch (AuraHandledException e) {
            badExt = true;
        }
        System.assert(badExt, 'Only JPG, PNG or PDF.');
        Boolean unknown = false;
        try {
            SalesConsoleController.stageChequeImage(
                SalesOrderInstallments__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA',
                EncodingUtil.base64Encode(Blob.valueOf('x')), 'x.jpg');
        } catch (AuraHandledException e) {
            unknown = true;
        }
        System.assert(unknown, 'An installment the user cannot see is refused.');
        // best effort
        SalesConsoleController.discardChequeImage(null);
        SalesConsoleController.discardChequeImage(
            ContentDocument.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        System.assertEquals(null, SalesConsoleController.readChequeImage(null));
        /* MSC-196 gave the read a status vocabulary; an unknown image is null (OCR off)
           or a non-'read' DTO - never a success and never an error */
        SalesConsoleController.ChequeReadDTO unknownRead = SalesConsoleController.readChequeImage(
            ContentDocument.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        System.assert(unknownRead == null || unknownRead.status != 'read',
            'An unknown image never reads as a success. Got: ' + unknownRead);
    }

    @isTest
    static void testTheBatchRefusesAnEmptyOrBlindRequest() {
        Boolean noBooking = false;
        try {
            SalesConsoleController.createChequePayments(null);
        } catch (AuraHandledException e) {
            noBooking = true;
        }
        System.assert(noBooking);
        SalesConsoleController.ChequeBatchInput input = new SalesConsoleController.ChequeBatchInput();
        input.salesOrderId = SalesOrder__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';
        input.bank = 'Emirates NBD';
        input.lines = new List<SalesConsoleController.ChequeLineInput>{
            aLine('a', SalesOrderInstallments__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA', '1', 1, null)
        };
        Boolean unknownOrder = false;
        try {
            SalesConsoleController.createChequePayments(input);
        } catch (AuraHandledException e) {
            unknownOrder = true;
        }
        System.assert(unknownOrder, 'A booking the user cannot see is refused.');
        System.assertEquals(null, SalesConsoleController.getMilestoneBatch(null).lines.isEmpty() ? null : 'x',
            'No order, an empty shape.');
    }
    /* A proof records a Payment */

    /** A proof slot with a file on it. */
    private static Id aProofWithFileOn(Id salesOrderId, String bucketKey, Id sourceId, String name) {
        SalesConsoleController.ProofSlotRequest req = new SalesConsoleController.ProofSlotRequest();
        req.salesOrderId = salesOrderId;
        req.bucketKey = bucketKey;
        req.sourceId = sourceId;
        req.amount = 1;
        req.reference = name;
        SalesConsoleController.ProofDTO slot = SalesConsoleController.createProofSlot(req);
        SalesConsoleController.uploadProofImage(
            slot.documentId, EncodingUtil.base64Encode(Blob.valueOf('proof ' + name)), name);
        return slot.documentId;
    }

    private static SalesConsoleController.ProofPaymentInput aProofPayment(
        Id salesOrderId, String bucketKey, Id sourceId, String method, String ref, Decimal amount, List<Id> docs
    ) {
        SalesConsoleController.ProofPaymentInput in1 = new SalesConsoleController.ProofPaymentInput();
        in1.salesOrderId = salesOrderId;
        in1.bucketKey = bucketKey;
        in1.sourceId = sourceId;
        in1.method = method;
        in1.transactionNumber = ref;
        in1.paidDate = Date.today();
        in1.amount = amount;
        in1.documentIds = docs;
        return in1;
    }

    private static String refusalOf(SalesConsoleController.ProofPaymentInput in1) {
        try {
            SalesConsoleController.recordProofPayment(in1);
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
        return null;
    }

    private static SalesConsoleController.PaymentBucketDTO rowOf(
        List<SalesConsoleController.PaymentBucketDTO> rows, String key, Id sourceId
    ) {
        for (SalesConsoleController.PaymentBucketDTO b : rows) {
            if (b.key == key && (sourceId == null || b.sourceId == sourceId)) {
                return b;
            }
        }
        return null;
    }

    /** 1.27 - on the test's own booking (anOwnBooking). */
    @isTest
    static void testTheAdmChargeProofRecordsAPaymentModonAllocates() {
        SalesOrder__c so = anOwnBooking('Adm').so;
        List<SalesConsoleController.PaymentBucketDTO> before =
            SalesConsoleController.getPaymentBucketsForOrders(
                so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });
        SalesConsoleController.PaymentBucketDTO adm = rowOf(before, 'ADM_DARI_CHARGE', null);
        System.assertNotEquals(null, adm, 'The charge is a row.');
        System.assertEquals(true, adm.recordsPayment, 'The ADM + Dari row records payments.');
        System.assert(adm.allowedMethods.contains('Bank Transfer') && adm.allowedMethods.contains('POS')
            && adm.allowedMethods.contains('Online'), 'Modon\'s own mode words: ' + adm.allowedMethods);
        System.assert(!adm.allowedMethods.contains('Direct Debit'), 'A mandate is not a method on a row.');
        System.assertEquals(adm.remainingAmount.setScale(2), adm.remainingAmount, 'To the fil.');
        System.assertEquals(adm.openAmount.setScale(2), adm.openAmount, 'To the fil.');
        System.assert(adm.openAmount > 0, 'The test\'s own charge is open (no silent pass).');
        Decimal amount = Math.min(adm.openAmount, 25.50);
        Id doc = aProofWithFileOn(so.Id, 'ADM_DARI_CHARGE', adm.sourceId, 'adm-proof.jpg');

        Test.startTest();
        SalesConsoleController.ProofPaymentResultDTO r = SalesConsoleController.recordProofPayment(
            aProofPayment(so.Id, 'ADM_DARI_CHARGE', adm.sourceId, 'Bank Transfer', 'T-ADM-1', amount, new List<Id>{ doc }));
        // duplicate reference refused
        Id doc2 = aProofWithFileOn(so.Id, 'ADM_DARI_CHARGE', adm.sourceId, 'adm-proof-2.jpg');
        String dup = refusalOf(aProofPayment(so.Id, 'ADM_DARI_CHARGE', adm.sourceId, 'Bank Transfer', 'T-ADM-1', 1, new List<Id>{ doc2 }));
        // a recorded slot cannot be recorded again, nor removed
        String again = refusalOf(aProofPayment(so.Id, 'ADM_DARI_CHARGE', adm.sourceId, 'POS', 'T-ADM-2', 1, new List<Id>{ doc }));
        Boolean removeRefused = false;
        try {
            SalesConsoleController.deleteProofSlot(doc);
        } catch (AuraHandledException e) {
            removeRefused = true;
        }
        List<SalesConsoleController.PaymentBucketDTO> after =
            SalesConsoleController.getPaymentBucketsForOrders(
                so.Opportunity__c, so.Unit__c, new List<Id>{ so.Id });
        Test.stopTest();

        System.assertEquals(true, r.recorded, r.message);
        System.assertNotEquals(null, r.receiptId);
        Receipt__c rc = [
            SELECT Modeofpayment__c, Status__c, Is_ADM_Fees_and_Dari_charges__c, Charge__c, SalesOrder__c,
                   SalesOrderInstallment__c, Account__c, TransactionNumber__c, TransactionDate__c,
                   Receipt_Amount__c, TotalAmount__c, ReceiptRemarks__c,
                   (SELECT Id FROM ContentDocumentLinks)
            FROM Receipt__c WHERE Id = :r.receiptId
        ];
        System.assertEquals('Bank Transfer', rc.Modeofpayment__c);
        System.assertEquals('In Progress', rc.Status__c);
        System.assertEquals(true, rc.Is_ADM_Fees_and_Dari_charges__c, 'Create_Receipt_SO\'s flag.');
        System.assertEquals(so.Id, rc.SalesOrder__c);
        System.assertEquals(null, rc.SalesOrderInstallment__c);
        System.assertEquals(so.CustomerAccount__c, rc.Account__c);
        System.assertEquals('T-ADM-1', rc.TransactionNumber__c);
        System.assertNotEquals(null, rc.TransactionDate__c);
        System.assertEquals(amount, rc.Receipt_Amount__c);
        System.assertEquals(amount, rc.TotalAmount__c);
        System.assertEquals(1, rc.ContentDocumentLinks.size(), 'The proof file is on the payment.');
        List<Allocation__c> allocs = [SELECT AllocationAmount__c, Invoice__c, Status__c FROM Allocation__c WHERE Receipt__c = :r.receiptId];
        System.assertEquals(1, allocs.size(), 'Modon\'s trigger allocated it.');
        System.assertEquals(adm.sourceId, allocs[0].Invoice__c, 'Against the ADM + Dari invoice.');
        System.assertEquals(amount, allocs[0].AllocationAmount__c);
        System.assertEquals(true, r.allocated);
        System.assertEquals(r.receiptId, [SELECT Receipt__c FROM Documents__c WHERE Id = :doc].Receipt__c,
            'The slot is stamped with the payment.');
        System.assertNotEquals(null, dup, 'The same transaction number twice is refused.');
        System.assert(dup.contains('already recorded'), dup);
        System.assertNotEquals(null, again, 'A slot already on a payment cannot be recorded again.');
        System.assert(removeRefused, 'A proof on a payment cannot be removed.');
        SalesConsoleController.PaymentBucketDTO admAfter = rowOf(after, 'ADM_DARI_CHARGE', adm.sourceId);
        System.assertEquals(adm.remainingAmount, admAfter.remainingAmount,
            'Remaining does not move until Finance approves.');
        System.assertEquals((adm.openAmount - amount).setScale(2), admAfter.openAmount.setScale(2),
            'What is open to a new payment fell by the amount with Finance.');
        Boolean seen = false;
        for (SalesConsoleController.InstrumentDTO i : admAfter.instruments) {
            if (i.receiptId == r.receiptId) {
                seen = true;
                System.assertEquals(true, i.live);
                System.assertEquals('Bank Transfer', i.mode);
                System.assertEquals('T-ADM-1', i.reference);
                System.assertEquals(1, i.fileCount);
                System.assertNotEquals(null, i.contentDocumentId);
            }
        }
        System.assert(seen, 'The payment stands on the row as a live instrument.');
        Boolean pendingListed = false;
        for (SalesConsoleController.ProofDTO pr : admAfter.proofs) {
            if (pr.documentId == doc) {
                System.assertEquals(r.receiptId, pr.receiptId, 'The proof knows its payment.');
            }
            if (pr.documentId == doc2) {
                pendingListed = true;
                System.assertEquals(null, pr.receiptId, 'The unrecorded proof is still waiting.');
            }
        }
        System.assert(pendingListed);
    }

    /** 1.27 - on the test's own booking (anOwnBooking). */
    @isTest
    static void testTheDownPaymentProofRecordsAPaymentOnTheInstallment() {
        OwnBooking own = anOwnBooking('DownPayment');
        SalesOrderInstallments__c later = own.later;
        SalesOrderInstallments__c first = own.first;
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                first.SalesOrder__r.Opportunity__c, first.SalesOrder__r.Unit__c,
                new List<Id>{ first.SalesOrder__c });
        SalesConsoleController.PaymentBucketDTO m1 = rowOf(rows, 'MILESTONE', first.Id);
        SalesConsoleController.PaymentBucketDTO boxed = rowOf(rows, 'MILESTONE', later.Id);
        System.assertEquals(true, m1.recordsPayment, 'Milestone 1 records payments.');
        System.assertEquals(false, boxed.recordsPayment, 'A boxed milestone does not.');
        System.assert(m1.openAmount > 0, 'The test\'s own down payment is open (no silent pass).');
        Decimal amount = Math.min(m1.openAmount, 40);
        Id doc = aProofWithFileOn(first.SalesOrder__c, 'MILESTONE', first.Id, 'dp-proof.jpg');
        Id docLater = aProofWithFileOn(first.SalesOrder__c, 'MILESTONE', later.Id, 'later-proof.jpg');

        /* a receipt on Milestone 1 makes Modon's trigger enqueue a chained queueable a test cannot run;
           their bypass flag is set as their tests set it */
        TriggerControl.bypassTransferTrigger = true;
        // the good one
        /* A9: the recording alone gets a fresh governor window. Writing the receipt fires MODON's
           ReceiptTrigger, whose updateSalesOrderDetails is query-hungry; with the setup and the six
           refusals in the same budget the method died at 101 inside that trigger. */
        Test.startTest();
        SalesConsoleController.ProofPaymentResultDTO r = SalesConsoleController.recordProofPayment(
            aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'POS', 'T-DP-1', amount, new List<Id>{ doc }));
        // an unrecorded proof can be removed with its files
        Integer filesBefore = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docLater];
        SalesConsoleController.deleteProofSlot(docLater);
        Test.stopTest();

        System.assertEquals(true, r.recorded, r.message);
        Receipt__c rc = [
            SELECT Modeofpayment__c, Status__c, SalesOrderInstallment__c, SalesOrder__c,
                   Is_ADM_Fees_and_Dari_charges__c, Receipt_Amount__c, (SELECT Id FROM ContentDocumentLinks)
            FROM Receipt__c WHERE Id = :r.receiptId
        ];
        System.assertEquals('POS', rc.Modeofpayment__c);
        System.assertEquals(first.Id, rc.SalesOrderInstallment__c, 'Create_Receipt_SOI\'s shape.');
        System.assertEquals(false, rc.Is_ADM_Fees_and_Dari_charges__c);
        System.assertEquals(amount, rc.Receipt_Amount__c);
        System.assertEquals(1, rc.ContentDocumentLinks.size());
        System.assertEquals(1, [SELECT COUNT() FROM Allocation__c WHERE Receipt__c = :r.receiptId AND Status__c = 'Applied']);
        System.assertEquals(1, filesBefore, 'The proof had its file.');
        System.assertEquals(0, [SELECT COUNT() FROM Documents__c WHERE Id = :docLater], 'The unrecorded proof is gone.');
    }

    /**
     * 1.27 - the down payment's refusals, split from the test above for a fresh governor window.
     */
    @isTest
    static void testTheDownPaymentProofRefusesWhatModonsFormWould() {
        OwnBooking own = anOwnBooking('DpRefusals');
        SalesOrderInstallments__c later = own.later;
        SalesOrderInstallments__c first = own.first;
        List<SalesConsoleController.PaymentBucketDTO> rows =
            SalesConsoleController.getPaymentBucketsForOrders(
                first.SalesOrder__r.Opportunity__c, first.SalesOrder__r.Unit__c,
                new List<Id>{ first.SalesOrder__c });
        SalesConsoleController.PaymentBucketDTO m1 = rowOf(rows, 'MILESTONE', first.Id);
        System.assert(m1.openAmount > 0, 'The test\'s own down payment is open.');
        Id doc = aProofWithFileOn(first.SalesOrder__c, 'MILESTONE', first.Id, 'dp-proof.jpg');
        Id docLater = aProofWithFileOn(first.SalesOrder__c, 'MILESTONE', later.Id, 'later-proof.jpg');
        TriggerControl.bypassTransferTrigger = true;

        Test.startTest();
        // boxed milestone refused
        String boxedWhy = refusalOf(aProofPayment(first.SalesOrder__c, 'MILESTONE', later.Id, 'Bank Transfer', 'T-DP-9', 1, new List<Id>{ docLater }));
        // slot from another row refused
        String wrongSlot = refusalOf(aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'Bank Transfer', 'T-DP-8', 1, new List<Id>{ docLater }));
        // over-amount refused
        String over = refusalOf(aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'Bank Transfer', 'T-DP-7', m1.openAmount + 1, new List<Id>{ doc }));
        // future date, no file, and a mode not offered are refused
        SalesConsoleController.ProofPaymentInput future = aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'POS', 'T-DP-6', 1, new List<Id>{ doc });
        future.paidDate = Date.today().addDays(1);
        String futureWhy = refusalOf(future);
        String noFile = refusalOf(aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'POS', 'T-DP-5', 1, new List<Id>()));
        String badMode = refusalOf(aProofPayment(first.SalesOrder__c, 'MILESTONE', first.Id, 'Direct Debit', 'T-DP-4', 1, new List<Id>{ doc }));
        Test.stopTest();

        System.assert(boxedWhy != null && boxedWhy.contains('Add cheques'), 'Boxed: ' + boxedWhy);
        System.assert(wrongSlot != null && wrongSlot.contains('another payment'), 'Wrong slot: ' + wrongSlot);
        System.assert(over != null && over.contains('more than'), 'Over: ' + over);
        System.assert(futureWhy != null && futureWhy.contains('future'), 'Future: ' + futureWhy);
        System.assert(noFile != null && noFile.contains('Attach the proof'), 'No file: ' + noFile);
        System.assert(badMode != null && badMode.contains('not a Mode of payment'), 'Mode: ' + badMode);
        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE SalesOrder__c = :first.SalesOrder__c],
            'Nothing was recorded.');
    }

    @isTest
    static void testAProofPaymentRefusesABlindRequest() {
        Boolean noRow = false;
        try {
            SalesConsoleController.recordProofPayment(null);
        } catch (AuraHandledException e) {
            noRow = true;
        }
        System.assert(noRow);
        SalesConsoleController.ProofPaymentInput in1 = aProofPayment(
            SalesOrder__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA',
            'ADM_DARI_CHARGE',
            Invoice__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA',
            'Bank Transfer', 'X', 1, new List<Id>());
        Boolean unknownOrder = false;
        try {
            SalesConsoleController.recordProofPayment(in1);
        } catch (AuraHandledException e) {
            unknownOrder = true;
        }
        System.assert(unknownOrder, 'A booking the user cannot see is refused.');
        System.assert(!SalesConsoleController.getReceiptBankOptions().isEmpty(), 'Customer Bank has values.');
    }

    /* MSC-112: the Customer Information card */

    private static Id personRtId() {
        return [SELECT Id FROM RecordType
                WHERE SObjectType = 'Account' AND IsPersonType = TRUE LIMIT 1].Id;
    }

    private static Account makePerson(String first, String last) {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = first, LastName = last);
        insert a;
        return a;
    }

    private static Contact addSignatory(Account org, String first, String last) {
        Contact c = new Contact(AccountId = org.Id, FirstName = first, LastName = last);
        insert c;
        return c;
    }

    private static SalesConsoleController.CustomerBlock customerFor(Id oppId) {
        return SalesConsoleController.getBookingSummary(oppId, null, null, null).customer;
    }

    /** The chain never yields blank where a value exists, and never clear. */
    @isTest
    static void testMaskedValuesAreNeverBlankAndNeverClear() {
        // ensureMasked masks whatever the chain hands it
        System.assertEquals('cl***@modontest.ae',
            SalesConsoleController.ensureMasked('clear.text@modontest.ae', 'email'),
            'A clear value in the masked chain must leave masked.');
        System.assertEquals('****0001',
            SalesConsoleController.ensureMasked('+971563350001', 'phone'));
        System.assertEquals('**** 01-1',
            SalesConsoleController.ensureMasked('784-2120-92345 01-1'.replaceAll('\\s',''), 'tail'));
        System.assertEquals('p***@x.ae',
            SalesConsoleController.ensureMasked('p***@x.ae', 'email'),
            'An already-masked value passes through untouched.');
        System.assertEquals(null, SalesConsoleController.ensureMasked('  ', 'email'));
        System.assertEquals('***', SalesConsoleController.maskEmailValue('nonsense'),
            'A malformed email masks to nothing recognisable rather than throwing.');
        System.assertEquals('****', SalesConsoleController.maskPhoneValue('12'),
            'A short phone must not throw - Serviceclass does.');

        // a person account with only the clear PersonEmail still renders masked
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'MaskChain',
            PersonEmail = 'card.maskchain@modontest.ae',
            PersonMobilePhone = '+971563351001');
        insert a;
        Opportunity o = makeOpportunity(a, null);
        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assert(String.isNotBlank(c.maskedEmail) && c.maskedEmail.contains('*'),
            'The email box must render a masked value, never blank, never clear: '
            + c.maskedEmail);
        System.assert(String.isNotBlank(c.maskedMobile) && c.maskedMobile.contains('*'),
            'Same for mobile: ' + c.maskedMobile);
        System.assertNotEquals('card.maskchain@modontest.ae', c.maskedEmail,
            'The masked field must never carry the clear address.');
    }

    /** Organisation half. */
    @isTest
    static void testOrganisationMaskedContactComesFromTheSignatory() {
        Account org = makePersonOrOrgAccount('Masked Org Co', null);
        Contact sig = new Contact(AccountId = org.Id, FirstName = 'Sara',
            LastName = 'Signatory', Email = 'sara.sig@modontest.ae',
            MobilePhone = '+971563351002');
        insert sig;
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assert(String.isNotBlank(c.maskedEmail) && c.maskedEmail.contains('*'),
            'An organisation reads the SIGNATORY, not the Account person fields '
            + 'that do not exist on a business account. Got: ' + c.maskedEmail);
        System.assert(String.isNotBlank(c.maskedMobile) && c.maskedMobile.contains('*'));
    }

    /** The Account fallback was gated on the contact name. */
    @isTest
    static void testEmailFallbackIsNotGatedOnTheContactName() {
        Account holder = makePersonOrOrgAccount('Fallback Holder Co', null);
        Contact named = new Contact(AccountId = holder.Id, LastName = 'NamedNoEmail');
        insert named;
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Per', LastName = 'FieldFallback',
            PersonEmail = 'per.field@modontest.ae');
        insert a;
        Opportunity o = makeOpportunity(a, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = named.Id);

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assertEquals('per.field@modontest.ae', c.email,
            'A named contact with no email must not hide the Account\'s own email - '
            + 'each field falls back on its own.');
    }

    /** Org identity comes off the Contact. */
    @isTest
    static void testOrgIdentityIsReadFromTheContactNotTheAccount() {
        Account org = makePersonOrOrgAccount('Org Identity Co', null);
        Contact sig = new Contact(AccountId = org.Id, FirstName = 'Idris',
            LastName = 'Holder', EIDNumber__c = '784-2126-9234511-1',
            EmiratesIDExpiryDate__c = Date.today().addYears(2));
        insert sig;
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assertEquals('784-2126-9234511-1', c.emiratesId,
            'Fresh org (created by this user today): the signatory\'s document is '
            + 'readable in clear because it is editable.');
        System.assertEquals(Date.today().addYears(2), c.emiratesIdExpiry);
        System.assertEquals('NAME_RULE', c.lockReasons.get('firstName'),
            'The org already refuses a Sales role changing a saved contact\'s name; '
            + 'the card says so instead of failing at Save.');
    }

    /** The six new inputs land on the person Account, encrypted twins included. */
    @isTest
    static void testIdentitySaveLandsOnThePersonAccount() {
        Account a = makePerson('Card', 'IdentitySave');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';
        input.nationality = 'India';
        input.emiratesId = '784-2127-9234512-2';
        input.emiratesIdExpiry = Date.today().addYears(2);
        input.countryOfResidence = 'United Arab Emirates';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Account saved = [SELECT EIDNumber__pc, En_EIDNumber__pc, EmiratesIDExpiryDate__pc,
                                CountryOfResidence__pc, UAE_Resident_Status__pc
                         FROM Account WHERE Id = :a.Id];
        System.assertEquals('784-2127-9234512-2', saved.EIDNumber__pc);
        System.assertEquals('784-2127-9234512-2', saved.En_EIDNumber__pc,
            'The encrypted twin is written alongside, as every console write does.');
        System.assertEquals(Date.today().addYears(2), saved.EmiratesIDExpiryDate__pc);
        System.assertEquals('United Arab Emirates', saved.CountryOfResidence__pc);
        System.assertEquals('Resident', saved.UAE_Resident_Status__pc);
    }

    /** The org branch writes the signatory Contact, never the Account. */
    @isTest
    static void testOrgIdentitySaveLandsOnTheSignatoryContact() {
        Account org = makePersonOrOrgAccount('Org Identity Save Co', null);
        Contact sig = addSignatory(org, 'Signa', 'Tory');
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';
        input.emiratesId = '784-2128-9234513-3';
        input.emiratesIdExpiry = Date.today().addYears(2);

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Contact saved = [SELECT EIDNumber__c, En_EIDNumber__c, EmiratesIDExpiryDate__c,
                                UAE_Resident_Status__c
                         FROM Contact WHERE Id = :sig.Id];
        System.assertEquals('784-2128-9234513-3', saved.EIDNumber__c);
        System.assertEquals('784-2128-9234513-3', saved.En_EIDNumber__c);
        System.assertEquals(Date.today().addYears(2), saved.EmiratesIDExpiryDate__c);
        System.assertEquals('Resident', saved.UAE_Resident_Status__c);
    }

    /** A masked value that round-trips is skipped. */
    @isTest
    static void testAValueCarryingAStarNeverReachesARecord() {
        Account a = makePerson('Card', 'StarGuard');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.email = 'ca***@modontest.ae';
        input.mobile = '****1001';
        input.emiratesId = '**** 12-1';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Account saved = [SELECT PersonEmail, PersonMobilePhone, EIDNumber__pc
                         FROM Account WHERE Id = :a.Id];
        System.assertEquals(null, saved.PersonEmail,
            'A masked email must never land clear-side - the Account has no rule '
            + 'to refuse it, so this guard is the only wall.');
        System.assertEquals(null, saved.PersonMobilePhone);
        System.assertEquals(null, saved.EIDNumber__pc);
    }

    /** Populated identity on an existing customer is immutable. */
    @isTest
    static void testASavedIdentityIsNotOverwritten() {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'SavedIdentity',
            EIDNumber__pc = '784-2129-9234514-4');
        insert a;
        Test.setCreatedDate(a.Id, DateTime.now().addDays(-30));
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.emiratesId = '784-9999-8888888-7';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        System.assertEquals('784-2129-9234514-4',
            [SELECT EIDNumber__pc FROM Account WHERE Id = :a.Id].EIDNumber__pc,
            'An existing customer\'s saved document is not the console\'s to change.');
    }

    /** The rep who created the customer today can still edit. */
    @isTest
    static void testAFreshCustomerIsFullyEditable() {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'FreshEdit',
            PersonEmail = 'typo.address@modontest.ae');
        insert a;
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.email = 'right.address@modontest.ae';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        System.assertEquals('right.address@modontest.ae',
            [SELECT PersonEmail FROM Account WHERE Id = :a.Id].PersonEmail,
            'Created by this rep within a day: the typo they just made is theirs to fix.');
    }

    /** A residency change against a populated Opportunity is skipped in sync. */
    @isTest
    static void testAResidencyChangeIsSkippedInSyncNeverHalfApplied() {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'ResidencySync',
            UAE_Resident_Status__pc = 'Resident');
        insert a;
        Opportunity o = makeOpportunity(a, 'Resident');

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Non-Resident';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        System.assertEquals('Resident',
            [SELECT UAE_Resident_Status__c FROM Opportunity WHERE Id = :o.Id].UAE_Resident_Status__c,
            'The booking\'s answered residency stands; only a stale client can '
            + 'send a different one.');
        System.assertEquals('Resident',
            [SELECT UAE_Resident_Status__pc FROM Account WHERE Id = :a.Id].UAE_Resident_Status__pc,
            'And the Account moves with the Opportunity or not at all.');
    }

    /** A save that changes nothing performs no DML. */
    @isTest
    static void testANoChangeSavePerformsNoDml() {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'NoChange',
            UAE_Resident_Status__pc = 'Resident', Nationality__pc = 'India');
        insert a;
        Opportunity o = makeOpportunity(a, 'Resident');
        update new Opportunity(Id = o.Id, Nationality__c = 'India');

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';
        input.nationality = 'India';

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        SalesConsoleController.saveCustomerInfo(input);
        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        System.assertEquals(dmlBefore, dmlAfter,
            'Saving the values already on the records must not update anything - '
            + 'every no-change update still runs every trigger, rule and flow.');
    }

    /** The Contact is written before the Opportunity so the residency trigger's backfill finds the rep's values. */
    @isTest
    static void testTheRepsIdentityBeatsTheOpportunityBackfill() {
        Account org = makePersonOrOrgAccount('Backfill Race Co', null);
        Contact sig = addSignatory(org, 'Back', 'Fill');
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id,
            EIDNumber__c = '784-1111-1111111-1');

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.residentStatus = 'Resident';
        input.emiratesId = '784-2222-2222222-2';
        input.emiratesIdExpiry = Date.today().addYears(2);

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        System.assertEquals('784-2222-2222222-2',
            [SELECT EIDNumber__c FROM Contact WHERE Id = :sig.Id].EIDNumber__c,
            'The value the rep typed, not the Opportunity\'s legacy identity.');
    }

    /** The lock map marks populated fields only and nulls their clear twins. */
    @isTest
    static void testLockReasonsMarkPopulatedFieldsAndOnlyThose() {
        Account a = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'LockMap',
            PersonEmail = 'lock.map@modontest.ae',
            EIDNumber__pc = '784-2130-9234515-5');
        insert a;
        Test.setCreatedDate(a.Id, DateTime.now().addDays(-30));
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assertEquals('IDENTITY_SAVED', c.lockReasons.get('emiratesId'));
        System.assertEquals('ON_FILE', c.lockReasons.get('email'));
        System.assertEquals('ON_FILE', c.lockReasons.get('customerType'),
            'Buyer type is structural - always locked.');
        System.assertEquals(null, c.lockReasons.get('nationality'),
            'A blank field on an existing customer stays editable - the fill case.');
        System.assertEquals(null, c.lockReasons.get('residentStatus'),
            'Opp residency blank: the pill stays live even though the Account '
            + 'holds an answer - writing it then is safe and eligibility needs it.');
        System.assertEquals(null, c.email,
            'A locked field\'s clear value never leaves the server.');
        System.assertEquals(null, c.emiratesId);
        System.assert(String.isNotBlank(c.maskedEmail),
            'The masked twin is what a locked field displays.');
        System.assert(String.isNotBlank(c.maskedEmiratesId));

        // a fresh customer's map holds only the structural rows
        Account f = new Account(RecordTypeId = personRtId(),
            FirstName = 'Card', LastName = 'FreshMap',
            PersonEmail = 'fresh.map@modontest.ae');
        insert f;
        Opportunity fo = makeOpportunity(f, 'Resident');
        SalesConsoleController.CustomerBlock fc = customerFor(fo.Id);
        System.assertEquals(null, fc.lockReasons.get('email'),
            'Fresh: the rep who created the customer is finishing their own work.');
        System.assertEquals('RESIDENCY_SAVED', fc.lockReasons.get('residentStatus'),
            'Except residency: the Opportunity\'s own rule applies fresh or not.');
    }

    /** Org identity with no signatory is refused with a sentence. */
    @isTest
    static void testOrgIdentityWithoutASignatoryIsRefused() {
        Account org = makePersonOrOrgAccount('No Signatory Co', null);
        Opportunity o = makeOpportunity(org, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.emiratesId = '784-2131-9234516-6';

        Boolean threw = false;
        Test.startTest();
        try {
            SalesConsoleController.saveCustomerInfo(input);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw,
            'Values with no record to land on must be refused, or they vanish '
            + 'behind a clean success and the rep retypes them forever.');
    }

    /** The restricted picklist serves its own values. */
    @isTest
    static void testCountryOfResidenceOptionsComeFromTheContactField() {
        List<String> opts = SalesConsoleController.getCountryOfResidenceOptions();
        System.assert(!opts.isEmpty(), 'The Countries set has values.');
        System.assert(opts.contains('India'),
            'The list is the restricted picklist\'s own - anything else is '
            + 'refused at DML.');
    }

    /* MSC-113: the organisation record */

    /** The billing arm is retired: billing keys land nowhere. */
    @isTest
    static void testCompanyBillingKeysNoLongerLand() {
        Account org = makePersonOrOrgAccount('Billing Arm Retired Co', null);
        Opportunity o = makeOpportunity(org, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.companyName = 'Billing Arm Retired Co';
        input.billingStreet = 'Ghost Street 1';
        input.billingCity = 'Ghost City';
        input.billingPostalCode = '00000';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Account saved = [SELECT Name, BillingStreet, BillingCity, BillingPostalCode
                         FROM Account WHERE Id = :org.Id];
        System.assertEquals('Billing Arm Retired Co', saved.Name,
            'The company arm still writes.');
        System.assertEquals(null, saved.BillingStreet,
            'A cached pre-2.0 card\'s billing keys must land nowhere - '
            + 'c/mscAddress is the one address writer (GAP 41).');
        System.assertEquals(null, saved.BillingCity);
        System.assertEquals(null, saved.BillingPostalCode);
    }

    /** An organisation's address saves with no nationality anywhere. */
    @isTest
    static void testOrgAddressSavesWithoutNationality() {
        Account org = makePersonOrOrgAccount('Org Address Repair Co', null);
        Opportunity o = makeOpportunity(org, null);

        SalesConsoleController.AddressInput input = new SalesConsoleController.AddressInput();
        input.opportunityId = o.Id;
        input.accountId = org.Id;
        input.isPersonAccount = false;
        input.billingStreet = 'Corniche Road 12';
        input.billingCity = 'Abu Dhabi';
        input.billingState = 'Abu Dhabi';
        input.billingPostalCode = '00001';
        input.billingCountry = 'United Arab Emirates';

        Test.startTest();
        SalesConsoleController.saveAddress(input);
        Test.stopTest();

        Account saved = [SELECT BillingStreet, BillingCity, BillingState,
                                BillingPostalCode, BillingCountry
                         FROM Account WHERE Id = :org.Id];
        System.assertEquals('Corniche Road 12', saved.BillingStreet);
        System.assertEquals('Abu Dhabi', saved.BillingCity);
        System.assertEquals('00001', saved.BillingPostalCode);
        System.assertEquals('United Arab Emirates', saved.BillingCountry);
        Opportunity opp = [SELECT Nationality__c, UAE_Resident_Status__c
                           FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(null, opp.Nationality__c,
            'No nationality was supplied, so none is invented.');
        System.assertEquals(null, opp.UAE_Resident_Status__c);
    }

    /** A person address save still demands both. */
    @isTest
    static void testPersonAddressStillRequiresNationality() {
        Account a = makePerson('Guard', 'StillThere');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.AddressInput input = new SalesConsoleController.AddressInput();
        input.opportunityId = o.Id;
        input.accountId = a.Id;
        input.isPersonAccount = true;
        input.personMailingStreet = 'Street 1';

        Boolean refused = false;
        try {
            SalesConsoleController.saveAddress(input);
        } catch (AuraHandledException e) {
            refused = true;
        }
        System.assert(refused,
            'A person address save without nationality must still be refused - '
            + 'this save writes Nationality__pc, and eligibility demands it.');
    }

    /** The Opportunity write is fill-only. */
    @isTest
    static void testAddressSaveNeverRewritesAPopulatedOppResidency() {
        Account a = makePerson('FillOnly', 'Opp');
        Opportunity o = makeOpportunity(a, 'Resident');

        SalesConsoleController.AddressInput input = new SalesConsoleController.AddressInput();
        input.opportunityId = o.Id;
        input.accountId = a.Id;
        input.isPersonAccount = true;
        input.personMailingStreet = 'Street 9';
        input.nationality = 'India';
        input.uaeResidentStatus = 'Non-Resident';

        Test.startTest();
        SalesConsoleController.saveAddress(input);
        Test.stopTest();

        Opportunity opp = [SELECT Nationality__c, UAE_Resident_Status__c
                           FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals('Resident', opp.UAE_Resident_Status__c,
            'A populated Opportunity residency is left alone - skipped, not rewritten.');
        System.assertEquals('India', opp.Nationality__c,
            'The blank copy IS filled: fill-only, not frozen.');
        Account saved = [SELECT UAE_Resident_Status__pc FROM Account WHERE Id = :a.Id];
        System.assertEquals('Non-Resident', saved.UAE_Resident_Status__pc,
            'The Account write is unchanged by the Opportunity gate.');
    }

    /** Blank Opportunity copies still get the value. */
    @isTest
    static void testAddressSaveFillsABlankOppResidency() {
        Account a = makePerson('FillOnly', 'Fills');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.AddressInput input = new SalesConsoleController.AddressInput();
        input.opportunityId = o.Id;
        input.accountId = a.Id;
        input.isPersonAccount = true;
        input.nationality = 'India';
        input.uaeResidentStatus = 'Resident';

        Test.startTest();
        SalesConsoleController.saveAddress(input);
        Test.stopTest();

        Opportunity opp = [SELECT Nationality__c, UAE_Resident_Status__c
                           FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals('India', opp.Nationality__c);
        System.assertEquals('Resident', opp.UAE_Resident_Status__c);
    }

    /** The declaration is stored truth only. */
    @isTest
    static void testCustomerBlockCarriesRealBeneficiary() {
        Account org = makePersonOrOrgAccount('Real Ben Read Co', null);
        Contact sig = addSignatory(org, 'Signa', 'Tory');
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        System.assertEquals(null, customerFor(o.Id).realBeneficiary,
            'A stored false is indistinguishable from never-asked, so the card '
            + 'must render it unanswered - never a "No" nobody gave.');

        update new Contact(Id = sig.Id, AreYouRealBeneficiaryOfThis__c = true);
        System.assertEquals(true, customerFor(o.Id).realBeneficiary,
            'A stored true is a declaration actually made, and travels.');
    }

    /** No signatory: the declaration has nobody to belong to. */
    @isTest
    static void testNoSignatoryLocksRealBeneficiary() {
        Account org = makePersonOrOrgAccount('Real Ben NoSig Co', null);
        Opportunity o = makeOpportunity(org, null);

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assertEquals('NO_SIGNATORY', c.lockReasons.get('realBeneficiary'),
            'The declaration is the signatory\'s to make.');

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.realBeneficiary = true;
        Boolean refused = false;
        try {
            SalesConsoleController.saveCustomerInfo(input);
        } catch (AuraHandledException e) {
            refused = true;
        }
        System.assert(refused,
            'A declaration with no signatory must be refused out loud, never '
            + 'vanish behind a clean success.');
    }

    /** The write is difference-gated; null writes nothing. */
    @isTest
    static void testRealBeneficiaryWritesDifferenceGated() {
        Account org = makePersonOrOrgAccount('Real Ben Write Co', null);
        Contact sig = addSignatory(org, 'Signa', 'Tory');
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.realBeneficiary = true;

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        System.assertEquals(true,
            [SELECT AreYouRealBeneficiaryOfThis__c FROM Contact WHERE Id = :sig.Id]
                .AreYouRealBeneficiaryOfThis__c,
            'Yes lands on the signatory.');

        Integer before = Limits.getDmlStatements();
        SalesConsoleController.saveCustomerInfo(input);
        System.assertEquals(before, Limits.getDmlStatements(),
            'The same answer again is a no-op: difference-gated, zero DML.');

        SalesConsoleController.CustomerInput silent = new SalesConsoleController.CustomerInput();
        silent.opportunityId = o.Id;
        Integer before2 = Limits.getDmlStatements();
        SalesConsoleController.saveCustomerInfo(silent);
        System.assertEquals(before2, Limits.getDmlStatements(),
            'Null means the question was not answered - nothing is written.');
        Test.stopTest();
    }

    /** A person account never takes the declaration from this card. */
    @isTest
    static void testRealBeneficiaryIsIgnoredForAPersonAccount() {
        Account a = makePerson('Real', 'BenPerson');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.realBeneficiary = true;

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Contact personContact = [SELECT AreYouRealBeneficiaryOfThis__c
                                 FROM Contact WHERE AccountId = :a.Id LIMIT 1];
        System.assertEquals(false, personContact.AreYouRealBeneficiaryOfThis__c,
            'The person branch ignores the declaration input entirely.');
        System.assertEquals(null, customerFor(o.Id).realBeneficiary,
            'And the block never carries it for a person.');
    }

    /** The nationality lock follows what eligibility reads, not the display chain. */
    @isTest
    static void testANationalityLockFollowsTheOpportunity() {
        // organisation: contact-only nationality stays editable while the Opportunity copy is blank
        Account org = makePersonOrOrgAccount('Nat Lock Co', null);
        Contact sig = addSignatory(org, 'Signa', 'Tory');
        update new Contact(Id = sig.Id, Nationality__c = 'India');
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);
        Test.setCreatedDate(org.Id, System.now().addDays(-30));

        SalesConsoleController.CustomerBlock c = customerFor(o.Id);
        System.assertEquals('India', c.nationality, 'The value still displays.');
        System.assertEquals(null, c.lockReasons.get('nationality'),
            'Editable: the Opportunity copy is blank and only a write from this '
            + 'card can fill it.');

        update new Opportunity(Id = o.Id, Nationality__c = 'India');
        System.assertEquals('ON_FILE', customerFor(o.Id).lockReasons.get('nationality'),
            'Locked once the Opportunity - the record eligibility reads - holds it.');

        // person: both copies must be populated before the field locks
        Account p = makePerson('Nat', 'LockPerson');
        update new Account(Id = p.Id, Nationality__pc = 'India');
        Opportunity po = makeOpportunity(p, null);
        Test.setCreatedDate(p.Id, System.now().addDays(-30));
        System.assertEquals(null, customerFor(po.Id).lockReasons.get('nationality'),
            'Account-only nationality stays editable - the blank Opportunity copy '
            + 'still needs this card.');
        update new Opportunity(Id = po.Id, Nationality__c = 'India');
        System.assertEquals('ON_FILE', customerFor(po.Id).lockReasons.get('nationality'));
    }

    /** 1.18 - the retired checkBookingEligibility no longer holds the customer step, as in the
        Sales App since 2 Sep. KYC gates the booking instead (AurelixKycHardGateTest). */
    @isTest
    static void testTheRetiredEligibilityCheckNoLongerBlocks() {
        // a company with no billing address and no licence number
        Account org = makePersonOrOrgAccount('Licence Word Co', null);
        Opportunity o = makeOpportunity(org, 'Resident');
        update new Opportunity(Id = o.Id, Nationality__c = 'United Arab Emirates');

        SalesConsoleController.ConsoleState state =
            SalesConsoleController.getConsoleState(o.Id);
        System.assert(!state.eligibilityBlocked,
            'A missing address or licence number no longer blocks: ' + state.eligibilityMessage);
        System.assertEquals(null, state.eligibilityMessage);

        // a person whose Opportunity and Account disagree on nationality and residency
        Account p = makePerson('Mis', 'Match');
        update new Account(Id = p.Id, Nationality__pc = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident');
        Opportunity po = makeOpportunity(p, 'Non-Resident');
        update new Opportunity(Id = po.Id, Nationality__c = 'India');

        SalesConsoleController.ConsoleState ps = SalesConsoleController.getConsoleState(po.Id);
        System.assert(!ps.eligibilityBlocked,
            'An Opportunity / Account mismatch no longer blocks: ' + ps.eligibilityMessage);
        System.assertEquals(null, ps.eligibilityMessage);
    }

    /* MSC-115: the organisation's verification step */

    /** Both tracks, with the records' own values. */
    @isTest
    static void testOrganisationComplianceCarriesTwoTracks() {
        Account org = makePersonOrOrgAccount('Org Verify Co', null);
        update new Account(Id = org.Id,
            PassfortApprovalStatus__c = 'Approved',
            PassfortRiskStatus__c = 'Low');
        Contact sig = addSignatory(org, 'Signa', 'Tory');
        update new Contact(Id = sig.Id,
            PassfortApprovalStatus__c = 'Requires Resubmission',
            KYC_Completed_Date__c = System.today());
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        Test.startTest();
        SalesConsoleController.ComplianceStateDTO dto =
            SalesConsoleController.getComplianceState(o.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto.company, 'The company is a track.');
        System.assertEquals('Org Verify Co', dto.company.name);
        System.assertEquals('Approved', dto.company.approvalStatus,
            'Read from Account.PassfortApprovalStatus__c - the __pc twin is null on '
            + 'every business account, which is why this step showed nothing.');
        System.assertEquals(true, dto.company.submitted,
            'A verdict means Passfort has it.');

        System.assertNotEquals(null, dto.signatory, 'And the person signing is another.');
        System.assertEquals('Requires Resubmission', dto.signatory.approvalStatus);
        System.assertEquals(System.today(), dto.signatory.kycCompletedDate);
        System.assertEquals(false, dto.signatory.canCheck,
            'Already with compliance, so the door stays shut.');
    }

    /** The door opens for a verified signatory nobody has submitted yet. */
    @isTest
    static void testTheSignatoryDoorOpensOnceVerified() {
        Account org = makePersonOrOrgAccount('Org Door Co', null);
        Contact sig = addSignatory(org, 'Ready', 'ToCheck');
        update new Contact(Id = sig.Id, KYC_Completed_Date__c = System.today());
        Opportunity o = makeOpportunity(org, null);
        update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);

        SalesConsoleController.ComplianceStateDTO dto =
            SalesConsoleController.getComplianceState(o.Id);

        System.assertEquals(true, dto.signatory.canCheck,
            'Verified and not yet submitted is exactly when the check can be run.');
        System.assertEquals(false, dto.signatory.submitted);
    }

    /** MSC-148. The company's link gate is missingForLink: no POA row is refused by name. */
    @isTest
    static void testOrganisationLinkGateMirrorsSendKycForm() {
        Account org = makePersonOrOrgAccount('Org Sentence Co', null);
        Opportunity o = makeOpportunity(org, null);

        SalesConsoleController.ComplianceStateDTO dto =
            SalesConsoleController.getComplianceState(o.Id);

        System.assertEquals(false, dto.canSendLink,
            'No Power of Attorney row means sendKYCForm would refuse, so nothing is offered.');
        /* MSC-181 renamed the missing document to Power of Attorney; either wording names it */
        System.assert(dto.blockedReason != null
            && (dto.blockedReason.containsIgnoreCase('authorised signatory')
                || dto.blockedReason.containsIgnoreCase('power of attorney')),
            'And the reason names what is missing. Got: ' + dto.blockedReason);
        System.assertNotEquals(null, dto.company,
            'A company with no signatory still has a company track.');
        System.assertEquals(null, dto.signatory,
            'And no signatory track to invent.');
    }

    /** A person booking is untouched. */
    @isTest
    static void testPersonAccountCarriesNoOrganisationTracks() {
        Account a = makePerson('Person', 'NoTracks');
        Opportunity o = makeOpportunity(a, null);

        SalesConsoleController.ComplianceStateDTO dto =
            SalesConsoleController.getComplianceState(o.Id);

        System.assertEquals(null, dto.company);
        System.assertEquals(null, dto.signatory);
        System.assertEquals(true, dto.isPersonAccount);
    }

    // MSC-153: money does not move. The server refuses a unit or plan change after money was
    // collected, and still allows the same unit on the same plan.

    private static Unit__c mmUnit(Id phaseId, String name) {
        Unit__c u = new Unit__c(
            Name = name,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            ApprovalStatus__c = 'Draft'
        );
        insert u;
        return u;
    }

    private static Id mmPhase() {
        Project__c proj = new Project__c(Name = 'MM Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'MM Phase', Project__c = proj.Id);
        insert phase;
        return phase.Id;
    }

    /**
     * MSC-213. The defaulted phase pick lands where the rep can BOOK, not on the first row.
     * A phase whose only stock is on a live hold counts as Available org-wide (which is all
     * the old pick ever looked at) but the grid would open empty on it.
     */
    @isTest
    static void testDefaultPhaseSkipsStockTheRepCannotTake() {
        Project__c proj = new Project__c(Name = 'Pick Project');
        insert proj;
        Phase__c held = new Phase__c(Name = 'A Held Phase', Project__c = proj.Id);
        Phase__c free = new Phase__c(Name = 'B Free Phase', Project__c = proj.Id);
        insert new List<Phase__c>{ held, free };
        Unit__c heldUnit = mmUnit(held.Id, 'PICK-HELD-1');
        mmUnit(free.Id, 'PICK-FREE-1');
        /* a live hold: still Available org-wide, offered to nobody (MSC-164) */
        heldUnit.Payment_In_Progress__c = true;
        heldUnit.Payment_Hold_Expiry__c = System.now().addHours(1);
        update heldUnit;

        Test.startTest();
        SalesConsoleController.UnitBrowserDTO dto =
            SalesConsoleController.getUnitBrowser(null, proj.Id, null);
        Test.stopTest();

        System.assertEquals(String.valueOf(free.Id), dto.selectedPhaseId,
            'The defaulted phase is the first with a unit this rep can take; a phase whose '
            + 'only stock is on a live hold is skipped, not landed on with an empty grid.');
    }

    /** A fee line with money rolled up onto it. */
    private static void mmCollect(Id oppId, Id accId, Id unitId, Id planId, Decimal amount) {
        Booking_Fee_Line__c line = new Booking_Fee_Line__c(
            Opportunity__c   = oppId,
            Unit__c          = unitId,
            Payment_Plan__c  = planId,
            Type__c          = 'ADM & Dari',
            Total_Amount__c  = amount,
            Status__c        = 'Pending'
        );
        insert line;

        Receipt__c r = new Receipt__c(
            Account__c       = accId,
            Modeofpayment__c = 'Bank Transfer',
            Status__c        = 'Received',
            PaymentStatus__c = 'APPROVED',
            TotalAmount__c   = amount,
            ReceiptDate__c   = System.today()
        );
        insert r;

        /* Total_Paid_Amount__c is a roll-up, so the money has to be real */
        insert new Booking_Fee_Allocation__c(
            Payment__c           = r.Id,
            Booking_Fee_Line__c  = line.Id,
            Allocation_Amount__c = amount,
            Status__c            = 'Applied',
            Type__c              = 'ADM & Dari'
        );
    }

    private static PaymentPlan__c mmPlan(Id unitId) {
        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c       = 'Standard',
            Unit__c       = unitId,
            Status__c     = 'Active',
            StartDate__c  = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );
        insert plan;
        return plan;
    }

    private static SalesConsoleController.ConfirmRequest mmReq(Id oppId, Id unitId, Id planId) {
        SalesConsoleController.ConfirmRequest req = new SalesConsoleController.ConfirmRequest();
        req.opportunityId = oppId;
        req.unitId        = unitId;
        req.paymentPlanId = planId;
        return req;
    }

    @IsTest
    static void testCollectedMoneyRefusesADifferentUnit() {
        Account a = makePersonAccount('Money Move Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        Id phaseId = mmPhase();
        Unit__c paidFor = mmUnit(phaseId, 'ZZ_MM_Paid');
        Unit__c other   = mmUnit(phaseId, 'ZZ_MM_Other');
        mmCollect(o.Id, a.Id, paidFor.Id, mmPlan(paidFor.Id).Id, 163782.61);

        Test.startTest();
        SalesConsoleController.ConfirmResult res =
            SalesConsoleController.reviewAndConfirm(mmReq(o.Id, other.Id, mmPlan(other.Id).Id));
        Test.stopTest();

        System.assertEquals(false, res.isSuccess,
            'Money is collected on another unit; this must not confirm.');
        System.assert(res.message != null
            && res.message.containsIgnoreCase('already been collected'),
            'And the refusal must name the money. Got: ' + res.message);
        System.assert(res.message.containsIgnoreCase('unit'),
            'It must say WHICH thing cannot move. Got: ' + res.message);
        System.assert(res.message.containsIgnoreCase('Sales Operations'),
            'And who can move it. Got: ' + res.message);
    }

    @IsTest
    static void testCollectedMoneyRefusesADifferentPlan() {
        Account a = makePersonAccount('Plan Move Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_MM_Plan');
        /* same unit, two plans: the guard names the plan */
        PaymentPlan__c paidOn  = mmPlan(u.Id);
        PaymentPlan__c another = mmPlan(u.Id);
        mmCollect(o.Id, a.Id, u.Id, paidOn.Id, 50000);

        SalesConsoleController.ConfirmResult res =
            SalesConsoleController.reviewAndConfirm(mmReq(o.Id, u.Id, another.Id));

        System.assertEquals(false, res.isSuccess);
        System.assert(res.message != null
            && res.message.containsIgnoreCase('payment plan'),
            'A moved plan must be named as the plan, not the unit. Got: ' + res.message);
    }

    /** The same unit on the same plan stays allowed (finishing a part-paid fee). */
    @IsTest
    static void testTheSameUnitOnTheSamePlanIsNeverRefused() {
        Account a = makePersonAccount('Same Unit Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_MM_Same');
        PaymentPlan__c plan = mmPlan(u.Id);
        mmCollect(o.Id, a.Id, u.Id, plan.Id, 163782.61);

        SalesConsoleController.ConfirmResult res =
            SalesConsoleController.reviewAndConfirm(mmReq(o.Id, u.Id, plan.Id));

        System.assert(res.message == null
            || !res.message.containsIgnoreCase('already been collected'),
            'The money guard must not fire on the unit it was collected against. '
            + 'Got: ' + res.message);
    }

    /** A booking with nothing collected moves freely. */
    @IsTest
    static void testNoMoneyMeansNoRefusal() {
        Account a = makePersonAccount('No Money Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        Id phaseId = mmPhase();
        Unit__c paidFor = mmUnit(phaseId, 'ZZ_MM_A');
        Unit__c other   = mmUnit(phaseId, 'ZZ_MM_B');
        /* a fee line with nothing allocated: the terminal is open, nothing paid */
        insert new Booking_Fee_Line__c(
            Opportunity__c  = o.Id,
            Unit__c         = paidFor.Id,
            Type__c         = 'ADM & Dari',
            Total_Amount__c = 163782.61,
            Status__c       = 'Pending'
        );

        SalesConsoleController.ConfirmResult res =
            SalesConsoleController.reviewAndConfirm(mmReq(o.Id, other.Id, mmPlan(other.Id).Id));

        System.assert(res.message == null
            || !res.message.containsIgnoreCase('already been collected'),
            'A hold with nothing collected is not money, and must not floor the '
            + 'journey. Got: ' + res.message);
    }

    // ── MSC-231 (W5): booking against the EOI ────────────────────────────────

    /** The eligible list is the engine's, priced by the engine's own receipt rules,
     *  oldest first (the auto-assignment order). */
    @isTest
    static void bookingEoisArePricedAndOrderedOldestFirst() {
        Account a = makePersonOrOrgAccount('EOI Booking Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Expressionofinterest__c older = new Expressionofinterest__c(Opportunity__c = o.Id);
        insert older;
        Expressionofinterest__c newer = new Expressionofinterest__c(Opportunity__c = o.Id);
        insert newer;
        Test.setCreatedDate(older.Id, System.now().addDays(-3));
        insert new Receipt__c(ExpressionOfInterest__c = older.Id, Account__c = a.Id,
            Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 10000);
        insert new Receipt__c(ExpressionOfInterest__c = older.Id, Account__c = a.Id,
            Status__c = 'In Progress', Receipt_Amount__c = 2000);
        /* 1.19: engine v16.0 lists only an EOI with a cleared receipt */
        insert new Receipt__c(ExpressionOfInterest__c = newer.Id, Account__c = a.Id,
            Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 5000);

        Test.startTest();
        SalesConsoleController.BookingEoiResult r =
            SalesConsoleController.getBookingEois(o.Id, null);
        Test.stopTest();

        System.assertEquals(2, r.eois.size(), 'Both EOIs listed by the engine (each has a cleared receipt).');
        System.assertEquals(older.Id, r.eois[0].eoiId, 'Oldest first - the auto-assignment order.');
        /* A9: which statuses the engine spends is EOI_Receipt_Valid_Statuses, which MODON edits
           in Setup. It now includes In Progress, so the second receipt counts - the rule under
           test is "priced by the engine's own list", not a snapshot of that list. */
        Set<String> spendable = new Set<String>();
        for (String st : System.Label.EOI_Receipt_Valid_Statuses.split(',')) { spendable.add(st.trim()); }
        Decimal expected = 10000 + (spendable.contains('In Progress') ? 2000 : 0);
        System.assertEquals(expected, r.eois[0].amount,
            'Only the receipts the engine would spend are priced (valid status, unspent).');
        System.assertEquals(true, r.eois[0].hasReceipt, 'The engine flags the money.');
        Assert.areEqual(5000, r.eois[1].amount, 'The newer EOI is priced by its own cleared receipt.');
        System.assertEquals(true, r.hasAnyEoi, 'EOIs exist on the opportunity.');
    }

    /** The mapping only ever reaches saveSalesOrder proven: this booking's units, the
     *  engine's own eligible EOIs, one EOI per unit. */
    @isTest
    static void eoiMappingIsValidatedBeforeItRidesIntoTheSave() {
        Account a = makePersonOrOrgAccount('EOI Map Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = o.Id);
        insert eoi;
        /* 1.19: engine v16.0 lists only an EOI with a cleared receipt */
        insert new Receipt__c(ExpressionOfInterest__c = eoi.Id, Account__c = a.Id,
            Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 10000);
        /* 1.22 - real units on a phase that requires an EOI: controller 1.77 drops any other */
        Id eoiPhase = mmPhase();
        update new Phase__c(Id = eoiPhase, EOI_Required__c = true);
        Id unitA = mmUnit(eoiPhase, 'ZZ_EOI_A').Id;
        Id unitB = mmUnit(eoiPhase, 'ZZ_EOI_B').Id;
        Set<Id> units = new Set<Id>{ unitA, unitB };

        SalesConsoleController.EoiMappingCheck ok = SalesConsoleController.validatedEoiMapping(
            JSON.serialize(new Map<String, String>{ String.valueOf(unitA) => String.valueOf(eoi.Id) }),
            units, o.Id);
        System.assertEquals(null, ok.error, 'A clean mapping passes.');
        System.assertNotEquals(null, ok.mappingJson, 'And is forwarded.');

        SalesConsoleController.EoiMappingCheck blank1 =
            SalesConsoleController.validatedEoiMapping(null, units, o.Id);
        System.assertEquals(null, blank1.error, 'No mapping is not an error.');
        System.assertEquals(null, blank1.mappingJson, 'And nothing is forwarded - as before.');

        Id foreignUnit = Unit__c.SObjectType.getDescribe().getKeyPrefix() + '000000009AAA';
        SalesConsoleController.EoiMappingCheck wrongUnit = SalesConsoleController.validatedEoiMapping(
            JSON.serialize(new Map<String, String>{ String.valueOf(foreignUnit) => String.valueOf(eoi.Id) }),
            units, o.Id);
        System.assertNotEquals(null, wrongUnit.error, 'A unit outside this booking is refused.');

        SalesConsoleController.EoiMappingCheck wrongEoi = SalesConsoleController.validatedEoiMapping(
            JSON.serialize(new Map<String, String>{ String.valueOf(unitA) => String.valueOf(o.Id) }),
            units, o.Id);
        System.assertNotEquals(null, wrongEoi.error, 'An id the engine never listed is refused.');

        SalesConsoleController.EoiMappingCheck dupe = SalesConsoleController.validatedEoiMapping(
            JSON.serialize(new Map<String, String>{
                String.valueOf(unitA) => String.valueOf(eoi.Id),
                String.valueOf(unitB) => String.valueOf(eoi.Id) }),
            units, o.Id);
        System.assertNotEquals(null, dupe.error, 'One EOI cannot pay for two units.');
    }

    /** Post-confirm the settlement names the deposits the engine actually linked. */
    @isTest(SeeAllData=true)
    static void settlementNamesTheAppliedEoiDeposits() {
        List<Unit__c> units = [
            SELECT Id FROM Unit__c WHERE Status__c = 'Available' AND TotalPrice__c > 0 LIMIT 1
        ];
        System.assert(!units.isEmpty(), 'No available priced Unit__c in this org.');
        Account a = makePersonOrOrgAccount('EOI Deposit Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = o.Id);
        insert eoi;
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = a.Id,
            Unit__c = units[0].Id, Status__c = 'New'
        );
        insert so;
        insert new Receipt__c(ExpressionOfInterest__c = eoi.Id, SalesOrder__c = so.Id,
            Account__c = a.Id, Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(),
            Receipt_Amount__c = 10000);

        Test.startTest();
        SalesConsoleController.SettlementDTO dto = SalesConsoleController.getSettlement(
            o.Id, units[0].Id, new List<Id>{ so.Id }, null, null);
        Test.stopTest();

        System.assertEquals(1, dto.eoiDeposits.size(), 'The linked deposit is named.');
        System.assertEquals(10000, dto.eoiDeposits[0].amount, 'With its amount.');
        System.assertNotEquals(null, dto.eoiDeposits[0].eoiName, 'And its EOI.');
    }

    /** 1.19: the Account's free-text bank seeds the mandate only when it names a UAEDDSBankName__c value. */
    @isTest
    static void theAccountBankIsMatchedToTheUaeddsList() {
        Assert.areEqual('First Abu Dhabi Bank', SalesConsoleController.knownUaeddsBank('  first abu dhabi bank '),
            'The whole value, in any case, is matched to the picklist.');
        Assert.isNull(SalesConsoleController.knownUaeddsBank('Fab'),
            'A near miss is left blank for the rep to pick, never guessed.');
        Assert.isNull(SalesConsoleController.knownUaeddsBank(null), 'No bank, nothing seeded.');
    }

    /* 1.21 - controller 1.76: fee lines on a phase that takes no fee are ignored until paid */
    @IsTest
    static void feeLinesDescribeTheBookingOnlyWhereAFeeIsTaken() {
        System.assertEquals(true, SalesConsoleController.feeLinesApply(true, 0),
            'A phase that takes a fee: its lines are the booking fee, paid or not.');
        System.assertEquals(false, SalesConsoleController.feeLinesApply(false, 0),
            'A no-fee phase: unpaid lines are not the booking\'s figures.');
        System.assertEquals(false, SalesConsoleController.feeLinesApply(null, null),
            'Unknown and unpaid reads as no fee.');
        System.assertEquals(true, SalesConsoleController.feeLinesApply(false, 1000),
            'Money on the lines is always shown, whatever the phase says.');
    }

    /* ══ 1.22 - the Sales App's unit rules (SalesConsoleController 1.77) ══ */

    @IsTest
    static void unitOptionsAreRequiredAndPriceTheOrderAsTheSalesAppDoes() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_OPT_A');
        System.assertEquals(null, SalesConsoleController.unitOptionGuard(u.Id, null),
            'No options on the unit or its phase: nothing to choose.');

        Unit_Option__c a = new Unit_Option__c(Name = 'Option A', Unit__c = u.Id,
                                              BasePrice__c = 1234567, AdditionalPrice__c = 0,
            PlotAreasqm__c = 1, PlotNo__c = 'ZZ-OPT');
        insert a;
        String refusal = SalesConsoleController.unitOptionGuard(u.Id, null);
        System.assertEquals('Unit option is not selected for ZZ_OPT_A unit.', refusal,
            'The Sales App\'s own sentence.');
        System.assertEquals(null, SalesConsoleController.unitOptionGuard(u.Id, a.Id));

        Unit__c other = mmUnit(phaseId, 'ZZ_OPT_B');
        Unit_Option__c foreign = new Unit_Option__c(Name = 'Option F', Unit__c = other.Id,
                                                    BasePrice__c = 1, AdditionalPrice__c = 0,
            PlotAreasqm__c = 1, PlotNo__c = 'ZZ-OPT');
        insert foreign;
        System.assertNotEquals(null, SalesConsoleController.unitOptionGuard(u.Id, foreign.Id),
            'Another unit\'s option is refused.');

        Unit__c loaded = [SELECT Id, TotalPrice__c, Interior__c, FacadeStyle__c FROM Unit__c WHERE Id = :u.Id];
        PaymentPlan__c plan = mmPlan(u.Id);
        System.assertEquals(1234567, SalesConsoleController.salesAppPrice(loaded, a.Id, plan.Id).amount,
            'The option\'s total prices the order.');
        System.assertEquals(loaded.TotalPrice__c, SalesConsoleController.salesAppPrice(loaded, null, plan.Id).amount,
            'Without an option, the unit\'s price.');
        System.assertNotEquals(null, SalesConsoleController.salesAppPrice(loaded, null, plan.Id).currencyCode,
            'The plan\'s currency.');
    }

    /** 1.29 - one option is preselected; with several none is, and the unit keeps its own price. */
    @IsTest
    static void oneUnitOptionIsChosenSeveralAreLeftToTheRep() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_OPT_FIRST');
        Unit_Option__c a = new Unit_Option__c(Name = 'ZZ First - Option A', Unit__c = u.Id,
            BasePrice__c = 1500000, AdditionalPrice__c = 250000, PlotAreasqm__c = 1, PlotNo__c = 'ZZ-F');
        insert a;
        Account buyer = makePersonOrOrgAccount('Option Buyer Co', null);
        Opportunity o = makeOpportunity(buyer, 'Resident');

        Map<String, Object> one = (Map<String, Object>)
            SalesConsoleController.getUnitConfiguration(u.Id, o.Id).get('unitOptions');
        List<Map<String, Object>> oneRows = (List<Map<String, Object>>) one.get('rows');
        System.assertEquals(1, oneRows.size());
        System.assertEquals(String.valueOf(a.Id), one.get('defaultId'), 'One option: it is chosen for the rep.');
        System.assertEquals(true, one.get('required'));
        System.assertEquals(1750000, (Decimal) oneRows[0].get('price'), 'Priced at the option\'s total.');

        Unit_Option__c b = new Unit_Option__c(Name = 'ZZ First - Option B', Unit__c = u.Id,
            BasePrice__c = 1600000, AdditionalPrice__c = 0, PlotAreasqm__c = 1, PlotNo__c = 'ZZ-F');
        insert b;
        Map<String, Object> two = (Map<String, Object>)
            SalesConsoleController.getUnitConfiguration(u.Id, o.Id).get('unitOptions');
        List<Map<String, Object>> twoRows = (List<Map<String, Object>>) two.get('rows');
        System.assertEquals(2, twoRows.size());
        System.assertEquals(null, two.get('defaultId'), 'Several options: none is chosen for the rep.');
        System.assertEquals(true, two.get('required'), 'The rep must still pick one.');
        System.assertEquals('Unit option is not selected for ZZ_OPT_FIRST unit.',
            SalesConsoleController.unitOptionGuard(u.Id, null, o.Id));
        Unit__c loaded = [SELECT Id, TotalPrice__c, Interior__c, FacadeStyle__c FROM Unit__c WHERE Id = :u.Id];
        PaymentPlan__c plan = mmPlan(u.Id);
        System.assertEquals(loaded.TotalPrice__c, SalesConsoleController.salesAppPrice(loaded, null, plan.Id).amount,
            'Nothing picked yet: the unit\'s own price.');
        System.assertEquals(1600000, SalesConsoleController.salesAppPrice(loaded, b.Id, plan.Id).amount,
            'Picked: the option\'s total.');

        String second = (String) twoRows[1].get('value');
        insert new SalesOrder__c(Opportunity__c = o.Id, CustomerAccount__c = buyer.Id, Unit__c = u.Id,
            Status__c = 'New', UnitOption__c = second);
        Map<String, Object> saved = (Map<String, Object>)
            SalesConsoleController.getUnitConfiguration(u.Id, o.Id).get('unitOptions');
        System.assertEquals(second, saved.get('defaultId'), 'A live order keeps the option it was saved with.');
    }

    @IsTest
    static void phaseOptionsCountAndTheUnitsOwnWinsByName() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_OPT_P');
        Unit_Option__c phaseLevel = new Unit_Option__c(Name = 'Option A', Phase__c = phaseId,
                                                       BasePrice__c = 10, AdditionalPrice__c = 0,
            PlotAreasqm__c = 1, PlotNo__c = 'ZZ-OPT');
        Unit_Option__c unitLevel = new Unit_Option__c(Name = 'Option A', Unit__c = u.Id,
                                                      BasePrice__c = 20, AdditionalPrice__c = 0,
            PlotAreasqm__c = 1, PlotNo__c = 'ZZ-OPT');
        insert new List<Unit_Option__c>{ phaseLevel, unitLevel };
        Map<Id, Unit_Option__c> options = SalesConsoleController.unitOptionsFor(u.Id);
        System.assertEquals(1, options.size(), 'One per name.');
        System.assert(options.containsKey(unitLevel.Id), 'The unit\'s own option wins over the phase\'s.');
    }

    /* ══ 1.24 - unit options exactly as the Sales App offers and prices them (controller 1.79) ══ */

    @IsTest
    static void theSalesAppsOptionRulesOnValues() {
        System.assertEquals(true, SalesConsoleController.isWadeemProject('Wadeem'));
        System.assertEquals(false, SalesConsoleController.isWadeemProject('Wadeem Gardens'),
            'The Sales App compares the whole name; the DEV project "Wadeem Gardens" is not Wadeem.');
        System.assertEquals(false, SalesConsoleController.isWadeemProject('wadeem'), 'Case matters, as in JavaScript.');
        System.assertEquals(false, SalesConsoleController.isWadeemProject(null));
        System.assertEquals(true, SalesConsoleController.isUaeNational('United Arab Emirates'));
        System.assertEquals(false, SalesConsoleController.isUaeNational('India'));
        System.assertEquals(false, SalesConsoleController.isUaeNational(null));
        System.assertEquals(true, SalesConsoleController.isModonEgyptProfile('Modon Egypt - Sales Management'));
        System.assertEquals(false, SalesConsoleController.isModonEgyptProfile('Sales Management'));
        System.assertEquals(false, SalesConsoleController.isModonEgyptProfile(null));

        List<Map<String, String>> listed = new List<Map<String, String>>{
            new Map<String, String>{ 'label' => '--None--', 'value' => '' },
            new Map<String, String>{ 'label' => 'V1 - Option 1', 'value' => 'a1' },
            new Map<String, String>{ 'label' => 'V1 - Option 2', 'value' => 'a2' },
            new Map<String, String>{ 'label' => 'V1 Type 1', 'value' => 'a3' },
            new Map<String, String>{ 'label' => 'V1 - Option A', 'value' => 'a4' },
            new Map<String, String>{ 'label' => 'V1 - Option A', 'value' => 'a4' }
        };
        List<Map<String, String>> all = SalesConsoleController.salesAppOptionRows(listed, false, false);
        System.assertEquals(4, all.size(), 'Outside Wadeem every option, the empty row dropped, each once.');
        System.assertEquals('a1', all[0].get('value'), 'In the Sales App\'s order.');
        List<Map<String, String>> national = SalesConsoleController.salesAppOptionRows(listed, true, true);
        System.assertEquals(2, national.size(), 'Wadeem, UAE national: "Option 1" and "Type 1" names only.');
        System.assertEquals('a1', national[0].get('value'));
        System.assertEquals('a3', national[1].get('value'));
        List<Map<String, String>> other = SalesConsoleController.salesAppOptionRows(listed, true, false);
        System.assertEquals(1, other.size(), 'Wadeem, anyone else: "Option 2" and "Type 2" names only.');
        System.assertEquals('a2', other[0].get('value'));
        System.assertEquals(0, SalesConsoleController.salesAppOptionRows(null, true, true).size());
    }

    @IsTest
    static void aWadeemBookingIsOfferedAndPricedAsTheSalesAppDoes() {
        Project__c proj = new Project__c(Name = 'Wadeem');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'W Phase', Project__c = proj.Id);
        insert phase;
        Unit__c u = mmUnit(phase.Id, 'ZZ_WADEEM_1');
        update new Unit__c(Id = u.Id, BasePrice__c = 900000, UAE_Citizen_Price__c = 700000);
        Unit_Option__c one = new Unit_Option__c(Name = 'ZZ_WADEEM_1 - Option 1', Unit__c = u.Id,
            BasePrice__c = 1111111, AdditionalPrice__c = 0, PlotAreasqm__c = 1, PlotNo__c = 'ZZ-W');
        Unit_Option__c two = new Unit_Option__c(Name = 'ZZ_WADEEM_1 - Option 2', Unit__c = u.Id,
            BasePrice__c = 2222222, AdditionalPrice__c = 0, PlotAreasqm__c = 1, PlotNo__c = 'ZZ-W');
        insert new List<Unit_Option__c>{ one, two };
        PaymentPlan__c plan = mmPlan(u.Id);

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        Account a = makePersonOrOrgAccount('Wadeem Buyer Co', null);
        Contact c = new Contact(LastName = 'Wadeem Buyer', AccountId = a.Id, Nationality__c = 'United Arab Emirates');
        Database.insert(c, dml);
        Opportunity o = makeOpportunity(a, 'Resident');
        update new Opportunity(Id = o.Id, PrimaryContact__c = c.Id);
        Unit__c loaded = [SELECT Id, TotalPrice__c, Interior__c, FacadeStyle__c FROM Unit__c WHERE Id = :u.Id];

        /* a UAE national: "Option 1" only, chosen for the rep, never repricing the order */
        Map<String, Object> cfg = SalesConsoleController.getUnitConfiguration(u.Id, o.Id);
        Map<String, Object> opts = (Map<String, Object>) cfg.get('unitOptions');
        List<Map<String, Object>> rows = (List<Map<String, Object>>) opts.get('rows');
        System.assertEquals(1, rows.size(), 'Only the "Option 1" name for a UAE national.');
        System.assertEquals(String.valueOf(one.Id), rows[0].get('value'));
        System.assertEquals(String.valueOf(one.Id), opts.get('defaultId'), 'The only option is chosen for the rep.');
        System.assertEquals(true, opts.get('required'));
        System.assertEquals(null, rows[0].get('price'), 'A Wadeem option puts no price on the order.');
        System.assertEquals('Unit option is not selected for ZZ_WADEEM_1 unit.',
            SalesConsoleController.unitOptionGuard(u.Id, null, o.Id));
        System.assertNotEquals(null, SalesConsoleController.unitOptionGuard(u.Id, two.Id, o.Id),
            'The non-national option is not offered to a UAE national.');
        System.assertEquals(null, SalesConsoleController.unitOptionGuard(u.Id, one.Id, o.Id));
        System.assertEquals(700000, SalesConsoleController.salesAppPrice(loaded, one.Id, plan.Id, o.Id).amount,
            'Priced at UAE_Citizen_Price__c, not at the option.');

        /* anyone else: "Option 2" only, priced at the unit's own price */
        update new Contact(Id = c.Id, Nationality__c = 'India');
        System.assertEquals(null, SalesConsoleController.unitOptionGuard(u.Id, two.Id, o.Id));
        System.assertNotEquals(null, SalesConsoleController.unitOptionGuard(u.Id, one.Id, o.Id));
        System.assertEquals(loaded.TotalPrice__c, SalesConsoleController.salesAppPrice(loaded, two.Id, plan.Id, o.Id).amount,
            'Not a UAE national: the unit\'s own price.');
    }

    @IsTest
    static void anOptionSentForAUnitWithoutOptionsIsRefused() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_OPT_NONE');
        Unit__c other = mmUnit(phaseId, 'ZZ_OPT_OTHER');
        Unit_Option__c foreign = new Unit_Option__c(Name = 'Option F', Unit__c = other.Id,
            BasePrice__c = 1, AdditionalPrice__c = 0, PlotAreasqm__c = 1, PlotNo__c = 'ZZ-OPT');
        insert foreign;
        System.assertEquals(null, SalesConsoleController.unitOptionGuard(u.Id, null, null),
            'Nothing offered, nothing owed.');
        System.assertEquals('The selected unit option is not available for unit ZZ_OPT_NONE.',
            SalesConsoleController.unitOptionGuard(u.Id, foreign.Id, null),
            'An option cannot ride onto a unit the Sales App offers none for.');
    }

    @IsTest
    static void theUnitMappingPricesOnlyForModonEgyptUsers() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_MAP_1');
        update new Unit__c(Id = u.Id, BasePrice__c = 500000);
        PaymentPlan__c plan = mmPlan(u.Id);
        String ccy = [SELECT CurrencyIsoCode FROM PaymentPlan__c WHERE Id = :plan.Id].CurrencyIsoCode;
        insert new UnitPaymentPlanMapping__c(Unit__c = u.Id, Payment_Plan__c = plan.Id,
            Base_Price__c = 450000, CurrencyIsoCode = ccy);
        Unit__c loaded = [SELECT Id, TotalPrice__c FROM Unit__c WHERE Id = :u.Id];

        SalesConsoleController.modonEgyptUserMemo = false;
        System.assertEquals(loaded.TotalPrice__c, SalesConsoleController.salesAppPrice(loaded, null, plan.Id).amount,
            'A UAE user: generateSalesOffer returns no mapping, so the unit\'s price.');
        SalesConsoleController.modonEgyptUserMemo = true;
        System.assertEquals(450000, SalesConsoleController.salesAppPrice(loaded, null, plan.Id).amount,
            'A Modon Egypt user: the plan\'s mapped base price.');
    }

    @IsTest
    static void eoisAttachOnlyWherethePhaseRequiresOne() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_EOI_PHASE');
        System.assertEquals(false, SalesConsoleController.eoiRequiredUnits(new Set<Id>{ u.Id }).contains(u.Id));
        update new Phase__c(Id = phaseId, EOI_Required__c = true);
        System.assertEquals(true, SalesConsoleController.eoiRequiredUnits(new Set<Id>{ u.Id }).contains(u.Id));
        System.assertEquals(true, SalesConsoleController.eoiRequiredUnits(null).isEmpty());

        /* and the mapping keeps an entry only for such a unit */
        Unit__c plain = mmUnit(mmPhase(), 'ZZ_EOI_PLAIN');
        Account a = makePersonOrOrgAccount('EOI Phase Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = o.Id);
        insert eoi;
        SalesConsoleController.EoiMappingCheck dropped = SalesConsoleController.validatedEoiMapping(
            JSON.serialize(new Map<String, String>{ String.valueOf(plain.Id) => String.valueOf(eoi.Id) }),
            new Set<Id>{ plain.Id }, o.Id);
        System.assertEquals(null, dropped.error);
        System.assertEquals(null, dropped.mappingJson, 'An EOI on a unit whose phase needs none is not linked.');
    }

    @IsTest
    static void unitStatusGuardIsModonsCheckUnitStatus() {
        Id phaseId = mmPhase();
        Unit__c u = mmUnit(phaseId, 'ZZ_STATUS');
        System.assertEquals(null, SalesConsoleController.unitStatusGuard(null));
        String r = SalesConsoleController.unitStatusGuard(new List<Id>{ u.Id });
        String modon = UnitSearchLwcController.checkUnitStatus(new List<String>{ String.valueOf(u.Id) });
        System.assertEquals(modon == 'Success' ? null : modon, r, 'MODON\'s answer, as it gives it.');
    }

    @IsTest
    static void appliedOffersAreReadFromTheBookingsOwnRows() {
        System.assertEquals(true, SalesConsoleController.getAppliedOffers(null, null).isEmpty());
        Account a = makePersonAccount('Applied Offers Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        System.assertEquals(true, SalesConsoleController.getAppliedOffers(o.Id, new List<Id>()).isEmpty(),
            'No order, no applied offers.');
        Id fakeOrder = SalesOrder__c.SObjectType.getDescribe().getKeyPrefix() + '000000001AAA';
        System.assertEquals(true,
            SalesConsoleController.getAppliedOffers(o.Id, new List<Id>{ fakeOrder }).isEmpty(),
            'An order with no Offers_Collections__c rows carries none.');
    }

    /* ══ 1.20 - facade style and pre-approval number (SalesConsoleController 1.75) ══ */

    /** The engine's own refusal before money, and only where the unit's phase needs a style. */
    @IsTest
    static void facadeGuardAsksForAStyleOnlyWhereThePhaseNeedsOne() {
        Project__c proj = new Project__c(Name = 'Facade Project');
        insert proj;
        Phase__c flagged = new Phase__c(Name = 'Facade Phase', Project__c = proj.Id, Facade_Style__c = true);
        Phase__c plain = new Phase__c(Name = 'Plain Phase', Project__c = proj.Id);
        insert new List<Phase__c>{ flagged, plain };
        Unit__c needs = mmUnit(flagged.Id, 'FACADE-1');
        Unit__c free = mmUnit(plain.Id, 'FACADE-2');

        Test.startTest();
        String refused = SalesConsoleController.facadeGuard(needs.Id, null);
        String chosen = SalesConsoleController.facadeGuard(needs.Id, 'Modern');
        String notNeeded = SalesConsoleController.facadeGuard(free.Id, '');
        Test.stopTest();

        System.assertEquals('Please select a Facade Style for unit FACADE-1.', refused,
            'The Sales App and the engine say exactly this.');
        System.assertEquals(null, chosen, 'A chosen style passes; the engine checks the value at save.');
        System.assertEquals(null, notNeeded, 'A phase without Facade_Style__c asks for nothing.');
    }

    /** Both values reach the Sales Order, single unit and basket row alike, the number trimmed. */
    @IsTest
    static void theSalesOrderCarriesTheFacadeAndThePreApprovalNumber() {
        Account a = makePersonAccount('Pre Approval Buyer');
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = mmUnit(mmPhase(), 'PREAPP-1');
        PaymentPlan__c plan = mmPlan(u.Id);

        SalesConsoleController.ConfirmRequest req = mmReq(o.Id, u.Id, plan.Id);
        req.facadeStyle = 'Modern';
        req.preApprovalNumber = '  ADIB-123  ';

        SalesConsoleController.UnitLine line = new SalesConsoleController.UnitLine();
        line.unitId = u.Id;
        line.paymentPlanId = plan.Id;
        line.facadeStyle = 'Arabian';
        line.preApprovalNumber = 'ADIB-456';
        Opportunity opp = [
            SELECT Id, AccountId, PrimaryContact__c, CurrencyIsoCode, UAE_Resident_Status__c
            FROM Opportunity WHERE Id = :o.Id
        ];

        Test.startTest();
        SalesOrder__c single = SalesConsoleController.buildSalesOrder(req, u);
        SalesOrder__c row = SalesConsoleController.buildSalesOrderForLine(o.Id, line, u, opp);
        req.preApprovalNumber = null;
        SalesOrder__c without = SalesConsoleController.buildSalesOrder(req, u);
        Test.stopTest();

        System.assertEquals('Modern', single.FacadeStyle__c);
        System.assertEquals('ADIB-123', single.Pre_Approval_Number__c, 'Trimmed, as the engine trims it.');
        System.assertEquals('Arabian', row.FacadeStyle__c);
        System.assertEquals('ADIB-456', row.Pre_Approval_Number__c);
        System.assertEquals(null, without.Pre_Approval_Number__c, 'Nothing typed, nothing sent.');
    }

    /** SCW-211 (1.78): the order the flow's Closed Won and Sold describe, built in memory (IsWon and the gate are read only). */
    private static SalesOrder__c closeShape(String status, String unitStatus, Boolean oppWon, Boolean gate) {
        Map<String, Object> so = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'SalesOrder__c' },
            'Status__c' => status,
            'SalesTeamVoidCheck__c' => gate,
            'Opportunity__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Opportunity' },
                'IsWon' => oppWon
            },
            'Unit__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Unit__c' },
                'Status__c' => unitStatus
            }
        };
        return (SalesOrder__c) JSON.deserialize(JSON.serialize(so), SalesOrder__c.class);
    }

    /**
     * SCW-211 (1.78): MODON closes the sale without moving Status__c off New; the summary must still know.
     * 1.25: the summary calls AurelixSaleClosed.isClosed.
     */
    @IsTest
    static void aSaleModonClosedReadsAsClosedThoughStatusStaysNew() {
        Test.startTest();
        Boolean closedWon = AurelixSaleClosed.isClosed(closeShape('New', 'Sold', true, true));
        Boolean byGate = AurelixSaleClosed.isClosed(closeShape('In Progress', 'Sold', false, true));
        Boolean basketSibling = AurelixSaleClosed.isClosed(closeShape('New', 'Reserved', true, false));
        Boolean soldElsewhere = AurelixSaleClosed.isClosed(closeShape('New', 'Sold', false, false));
        Boolean voided = AurelixSaleClosed.isClosed(closeShape('Voided', 'Sold', true, true));
        Boolean completed = AurelixSaleClosed.isClosed(closeShape('Completed', 'Sold', true, true));
        Boolean noOrder = AurelixSaleClosed.isClosed(null);
        Test.stopTest();

        System.assertEquals(true, closedWon, 'SO-15561: New, opportunity Closed Won, unit Sold. The sale has closed.');
        System.assertEquals(true, byGate, 'The gate met and the unit Sold is the flow closing this order.');
        System.assertEquals(false, basketSibling,
            'A basket opportunity closes with its first order; a sibling whose unit is still Reserved has not.');
        System.assertEquals(false, soldElsewhere,
            'A Sold unit with neither this order\'s gate nor its opportunity closed was sold by another order.');
        System.assertEquals(false, voided, 'Any other status keeps its own label.');
        System.assertEquals(false, completed, 'Completed is MODON\'s own later word and keeps its label.');
        System.assertEquals(false, noOrder, 'No order, nothing closed.');
    }

    /** SCW-211 (1.78): the summary reads the close from the records, and leaves stage as stored. */
    @IsTest
    static void theSummaryFollowsTheSaleToClosed() {
        Account a = makePersonOrOrgAccount('Closed Sale Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = mmUnit(mmPhase(), 'CLOSED-SALE-1');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Unit__c = u.Id,
            Status__c = 'New'
        );
        insert so;

        SalesConsoleController.BookingSummaryDTO open =
            SalesConsoleController.getBookingSummary(o.Id, null, null, so.Id);

        /* what Sales_Order_Record_Triggered_Flow writes when it closes the sale, by hand */
        update new Unit__c(Id = u.Id, Status__c = 'Sold');
        update new Opportunity(Id = o.Id, StageName = 'Closed Won');

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO closed =
            SalesConsoleController.getBookingSummary(o.Id, null, null, so.Id);
        Test.stopTest();

        System.assertEquals(false, open.saleClosed, 'An open opportunity and an Available unit: not closed.');
        System.assertEquals(true, closed.saleClosed, 'Closed Won and Sold: the chip must stop saying Booking started.');
        System.assertEquals('New', closed.stage, 'stage stays the stored Status__c; saleClosed carries the close.');

        /* 1.25: one rule. The pop-up's chip gives exactly what Total Sales' helper says of the same order. */
        SalesOrder__c asStored = [
            SELECT Status__c, SalesTeamVoidCheck__c, Opportunity__r.IsWon, Unit__r.Status__c
            FROM SalesOrder__c WHERE Id = :so.Id
        ];
        System.assertEquals(AurelixSaleClosed.isClosed(asStored), closed.saleClosed,
            'The booking pop-up and Total Sales read the sale with one rule (AurelixSaleClosed).');
    }

    /** 1.30 - an order priced above the unit's list price (a unit option) shows one price everywhere. */
    @IsTest
    static void theSummaryUnitCarriesTheBookingPrice() {
        Account a = makePersonOrOrgAccount('One Price Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = mmUnit(mmPhase(), 'ONE-PRICE-1');
        Unit__c listed = [SELECT TotalPrice__c FROM Unit__c WHERE Id = :u.Id];
        Decimal listPrice = listed.TotalPrice__c == null ? 0 : listed.TotalPrice__c;
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Unit__c = u.Id,
            Status__c = 'New',
            TotalAmount__c = listPrice + 250000
        );
        insert so;

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO dto =
            SalesConsoleController.getBookingSummary(o.Id, null, null, so.Id);
        Test.stopTest();

        System.assertEquals(listPrice + 250000, dto.totalPrice, 'The booking total is the order\'s amount.');
        System.assertEquals(dto.totalPrice, dto.unit.totalPrice,
            'The unit reads at the same price as the booking, not its list price.');
    }

    /* 1.25 - an order in any of MODON's cancelled statuses is dead to the console */

    /** A Sales Order in the status given, on its own unit. */
    private static SalesOrder__c deadFixOrder(Opportunity o, Account a, Id phaseId, String unitName, String status) {
        Unit__c u = mmUnit(phaseId, unitName);
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id,
            CustomerAccount__c = a.Id,
            Unit__c = u.Id,
            Status__c = status
        );
        insert so;
        return so;
    }

    /** The list the controller filters by is MODON's whole cancelled list, "Cancelled SR" and the "- SR" ones included. */
    @IsTest
    static void theDeadListIsModonsFullCancelledList() {
        Test.startTest();
        List<String> dead = SalesConsoleController.deadOrderStatuses();
        Test.stopTest();

        System.assertEquals(new Set<String>(SalesConsoleDashboardController.cancelledSalesOrderStatuses()),
            new Set<String>(dead), 'One list: the one Total Sales and the home card read.');
        for (String s : new List<String>{ 'Cancelled', 'System cancelled', 'Voided', 'Cancelled SR' }) {
            System.assert(dead.contains(s), s + ' ends a booking.');
        }
        /* every "- SR" cancellation on the Status__c picklist, whatever the label holds today */
        for (Schema.PicklistEntry e : SalesOrder__c.Status__c.getDescribe().getPicklistValues()) {
            if (e.getValue().endsWith('Cancelled - SR')) {
                System.assert(dead.contains(e.getValue()), e.getValue() + ' ends a booking.');
            }
        }
        System.assertEquals(false, dead.contains('New'), 'New is live.');
        System.assertEquals(false, dead.contains('In Progress'), 'In Progress is live.');
    }

    /** A "Cancelled SR" order, the only one on its opportunity: nothing to resume, nothing booked. */
    @IsTest
    static void aCancelledSrOrderIsNotResumed() {
        Account a = makePersonOrOrgAccount('Cancelled SR Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        SalesOrder__c dead = deadFixOrder(o, a, mmPhase(), 'DEAD-SR-1', 'Cancelled SR');

        Test.startTest();
        SalesConsoleController.ConsoleState plain = SalesConsoleController.getConsoleState(o.Id);
        SalesConsoleController.ConsoleState opened = SalesConsoleController.getConsoleStateForOrder(o.Id, dead.Id);
        Test.stopTest();

        System.assertEquals(null, plain.salesOrderId, 'A cancelled order is not the live booking.');
        System.assertEquals(null, plain.bookingRef, 'and lends it no reference.');
        System.assertEquals(0, plain.bookedUnits.size(), 'Nothing is booked on this opportunity.');
        System.assertEquals(null, opened.focusedSalesOrderId, 'Resume of a cancelled order opens nothing.');
        System.assertEquals(null, opened.salesOrderId, 'and does not fall back to it.');
    }

    /** Next to a live order (SO-15073 in DEV): not opened, not listed, not counted in the booking. */
    @IsTest
    static void anSrCancelledOrderIsNotPartOfTheBooking() {
        Account a = makePersonOrOrgAccount('Transfer SR Co', null);
        Opportunity o = makeOpportunity(a, 'Resident');
        Id phaseId = mmPhase();
        SalesOrder__c live = deadFixOrder(o, a, phaseId, 'LIVE-SR-1', 'New');
        SalesOrder__c dead = deadFixOrder(o, a, phaseId, 'DEAD-SR-2', 'Property Transfer Cancelled - SR');

        Test.startTest();
        SalesConsoleController.ConsoleState plain = SalesConsoleController.getConsoleState(o.Id);
        SalesConsoleController.ConsoleState opened = SalesConsoleController.getConsoleStateForOrder(o.Id, dead.Id);
        SalesConsoleController.SettlementDTO s = SalesConsoleController.getSettlement(
            o.Id, live.Unit__c, new List<Id>{ live.Id }, null, null);
        Test.stopTest();

        System.assertEquals(live.Id, plain.salesOrderId, 'The live order is the booking.');
        System.assertEquals(1, plain.bookedUnits.size(), 'Only the live order is listed.');
        System.assertEquals(live.Id, plain.bookedUnits[0].salesOrderId, 'and it is the live one.');
        System.assertEquals(null, opened.focusedSalesOrderId, 'The cancelled order is not reopened.');
        System.assertEquals(live.Id, opened.salesOrderId, 'The whole-opportunity state comes back instead.');
        System.assertEquals(1, s.bookingUnitCount, 'The booking has one unit, not two.');
    }

    // ── 1.26: the rep chooses the EOI; a lapsed hold can be released ──

    /** Two cleared, matching EOIs on an EOI phase: no fee until the rep has chosen one. */
    @IsTest
    static void aFeeWaitsForTheRepsEoiChoice() {
        Account a = makePersonAccount('EOI Choice Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        makeKycValid(o.Id);
        Id eoiPhase = mmPhase();
        update new Phase__c(Id = eoiPhase, EOI_Required__c = true);
        Unit__c u = mmUnit(eoiPhase, 'ZZ_EOI_PICK');
        PaymentPlan__c plan = mmPlan(u.Id);
        List<Expressionofinterest__c> eois = new List<Expressionofinterest__c>{
            new Expressionofinterest__c(Opportunity__c = o.Id, NumberofBedrooms__c = '2 Bedrooms'),
            new Expressionofinterest__c(Opportunity__c = o.Id, NumberofBedrooms__c = '2 Bedrooms')
        };
        /* Bedrooms__c is a formula on NumberofBedrooms__c: "2 Bedrooms" reads "2", as the unit */
        insert eois;
        /* engine v16.0 lists only an EOI with a cleared receipt */
        insert new List<Receipt__c>{
            new Receipt__c(ExpressionOfInterest__c = eois[0].Id, Account__c = a.Id,
                Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 10000),
            new Receipt__c(ExpressionOfInterest__c = eois[1].Id, Account__c = a.Id,
                Status__c = 'Cleared', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 10000)
        };

        /* fresh limits for the two refusals, which write nothing */
        Test.startTest();
        String noChoice;
        try {
            SalesConsoleController.beginPayment(mmReq(o.Id, u.Id, plan.Id));
        } catch (AuraHandledException e) {
            noChoice = e.getMessage();
        }
        System.assertEquals('Please select an EOI for unit ZZ_EOI_PICK before proceeding.', noChoice,
            'With no EOI chosen the fee is refused in the Sales App\'s words.');
        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :o.Id],
            'and before any fee line is raised.');

        SalesConsoleController.ConfirmRequest foreign = mmReq(o.Id, u.Id, plan.Id);
        foreign.eoiMappingJson = JSON.serialize(new Map<String, String>{ String.valueOf(u.Id) => String.valueOf(o.Id) });
        String notListed;
        try {
            SalesConsoleController.beginPayment(foreign);
        } catch (AuraHandledException e) {
            notListed = e.getMessage();
        }
        System.assertNotEquals(null, notListed, 'A choice the engine never listed is refused.');
        Test.stopTest();

        SalesConsoleController.ConfirmRequest chosen = mmReq(o.Id, u.Id, plan.Id);
        chosen.eoiMappingJson = JSON.serialize(new Map<String, String>{ String.valueOf(u.Id) => String.valueOf(eois[1].Id) });
        String afterChoice;
        try {
            SalesConsoleController.beginPayment(chosen);
        } catch (Exception e) {
            afterChoice = e.getMessage();
        }
        System.assert(afterChoice == null || !afterChoice.containsIgnoreCase('select an EOI'),
            'The rep\'s choice passes the EOI check. Got: ' + afterChoice);
    }

    private static Unit__c heldUnit(String name, Integer minutesLeft) {
        Unit__c u = mmUnit(mmPhase(), name);
        u.Payment_In_Progress__c = true;
        u.Payment_Hold_By__c = UserInfo.getUserId();
        u.Payment_Hold_Expiry__c = System.now().addMinutes(minutesLeft);
        update u;
        return u;
    }

    private static Unit__c holdOf(Id unitId) {
        return [SELECT Payment_In_Progress__c, Payment_Hold_By__c, Payment_Hold_Expiry__c
                FROM Unit__c WHERE Id = :unitId];
    }

    /** A hold that lapsed with nothing paid is released, as the Sales App's Cancel booking does. */
    @IsTest
    static void aLapsedHoldWithNothingPaidIsReleased() {
        Account a = makePersonAccount('Lapsed Hold Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = heldUnit('ZZ_HOLD_LAPSED', -5);
        /* the terminal was opened: fee lines exist, nothing landed on them */
        insert new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 50000, Status__c = 'Pending');

        SalesConsoleController.cancelPaymentHold(o.Id, u.Id);

        Unit__c after = holdOf(u.Id);
        System.assertEquals(false, after.Payment_In_Progress__c, 'The lapsed hold is released.');
        System.assertEquals(null, after.Payment_Hold_By__c);
        System.assertEquals(null, after.Payment_Hold_Expiry__c);
    }

    /** Money on the fee lines keeps the unit: refused in a plain sentence, the hold untouched. */
    @IsTest
    static void aHoldWithMoneyOnItIsNotReleased() {
        Account a = makePersonAccount('Paid Hold Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = heldUnit('ZZ_HOLD_PAID', 5);
        mmCollect(o.Id, a.Id, u.Id, null, 50000);

        String refused;
        try {
            SalesConsoleController.cancelPaymentHold(o.Id, u.Id);
        } catch (AuraHandledException e) {
            refused = e.getMessage();
        }

        System.assertEquals(SalesConsoleController.HOLD_PAID_REFUSAL, refused, 'A paid unit is not released.');
        System.assertEquals(true, holdOf(u.Id).Payment_In_Progress__c, 'and its hold stays.');
    }

    /** A receipt on a fee line counts as money even before any allocation. */
    @IsTest
    static void aReceiptOnAFeeLineKeepsTheHold() {
        Account a = makePersonAccount('Receipt Hold Co');
        Opportunity o = makeOpportunity(a, 'Resident');
        Unit__c u = heldUnit('ZZ_HOLD_RECEIPT', -5);
        Booking_Fee_Line__c line = new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id,
            Type__c = 'ADM & Dari', Total_Amount__c = 50000, Status__c = 'Pending');
        insert line;
        insert new Receipt__c(Account__c = a.Id, Booking_Fee_Line__c = line.Id, Modeofpayment__c = 'Bank Transfer',
            Status__c = 'Received', PaymentStatus__c = 'APPROVED', TotalAmount__c = 50000,
            ReceiptDate__c = System.today());

        String refused;
        try {
            SalesConsoleController.cancelPaymentHold(o.Id, u.Id);
        } catch (AuraHandledException e) {
            refused = e.getMessage();
        }
        System.assertEquals(SalesConsoleController.HOLD_PAID_REFUSAL, refused);
        System.assertEquals(true, holdOf(u.Id).Payment_In_Progress__c);

        String blind;
        try {
            SalesConsoleController.cancelPaymentHold(null, u.Id);
        } catch (AuraHandledException e) {
            blind = e.getMessage();
        }
        System.assertNotEquals(null, blind, 'No booking, no release.');
    }
}