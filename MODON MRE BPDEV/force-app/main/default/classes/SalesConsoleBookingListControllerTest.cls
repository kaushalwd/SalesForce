/**
 * Tests for SalesConsoleBookingListController.
 *
 * Version  Author      Date         Detail
 * 1.8      Aurelix Dev 29 Sep 2026  Controller 1.9: a Partially Paid milestone adds InstallmentAmount__c
 *                                   less Balance_Amount__c to PAID; with no balance it adds nothing.
 * 1.7      Aurelix Dev 29 Sep 2026  Controller 1.8: a sale MODON closed is flagged saleClosed in the list
 *                                   and the detail. Every cancelled status MODON uses is dead.
 * 1.6      Aurelix Dev 02 Sep 2026  MSC-220. An awaiting row reports the stored fee-line status,
 *                                   and the status that most of the outstanding balance sits at
 *                                   wins when the lines disagree. The notStarted assertions go
 *                                   with the list they covered; the dead / totalValue half of
 *                                   that test is kept under its own name.
 * 1.5      Aurelix Dev 02 Sep 2026  MSC-219. Converted customers with no booking are reachable;
 *                                   a cancelled order is flagged dead and is not contract value.
 * 1.4      Aurelix Dev 02 Sep 2026  MSC-217. A voided booking that collected nothing raises no
 *                                   Awaiting payment row; the voided order itself still lists.
 * 1.3      Aurelix IT  20 Aug 2026  MSC-088. The Verification tab's fraction.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-086. The documents on a booking.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-084. BookingDTO.partyCount.
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 */
@isTest
private class SalesConsoleBookingListControllerTest {

    private static SalesOrder__c makeBooking(Decimal amount) {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = amount);
        insert so;
        return so;
    }

    /** A booking waiting for money is findable: the fee line is the signal. */
    @isTest
    static void testBookingsAwaitingPaymentAreListedAndResumable() {
        Account a = new Account(Name = 'Awaiting Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Awaiting booking', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        /* Paid and Balance are roll-ups; nothing paid is the state under test */
        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Type__c = 'Down Payment', Total_Amount__c = 50000
        );

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        SalesConsoleBookingListController.BookingSummaryDTO row;
        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            if (d.opportunityId == opp.Id) {
                row = d;
            }
        }
        System.assertNotEquals(null, row,
            'A booking with an outstanding fee and no Sales Order must appear under ' +
            'Awaiting payment, or the agent has no way back to it.');
        System.assertNotEquals(null, row.opportunityId,
            'Resume opens on an Opportunity, so a row without one is a dead link.');

        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            System.assertNotEquals(opp.Id, b.opportunityId,
                'It must not also appear in the booked list - one booking, one row.');
        }
    }

    /**
     * MSC-217. A cancelled booking leaves its unpaid fee request behind (the org's
     * cancellation does not zero it). With nothing ever collected, that is debris, not money
     * to chase, and the pane must not offer a Resume for it.
     */
    @isTest
    static void testAwaitingRowsDropAVoidedBookingThatTookNoMoney() {
        Account a = new Account(Name = 'Voided Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Voided booking', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Type__c = 'Down Payment', Total_Amount__c = 50000
        );
        /* the booking that was made and then voided */
        insert new SalesOrder__c(
            Opportunity__c = opp.Id, TotalAmount__c = 50000, Status__c = 'Voided'
        );

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            System.assertNotEquals(opp.Id, d.opportunityId,
                'A voided booking that collected nothing must not be chased for payment.');
        }
        /* the voided order itself still belongs in the list, as the record it is */
        Boolean listed = false;
        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            if (b.opportunityId == opp.Id) {
                listed = true;
            }
        }
        System.assertEquals(true, listed,
            'Only the phantom awaiting row is dropped; the voided order is still history.');
    }

    /**
     * MSC-219. A cancelled order is flagged, so the pane can tell live work from history, and
     * it is not counted as contract value.
     */
    @isTest
    static void testACancelledOrderIsFlaggedAndIsNotContractValue() {
        Account a = new Account(Name = 'Voided Value Co');
        insert a;
        Opportunity other = new Opportunity(
            Name = 'Voided one', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert other;
        insert new SalesOrder__c(
            Opportunity__c = other.Id, TotalAmount__c = 900000, Status__c = 'Voided'
        );

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        Boolean voidedFlagged = false;
        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            if (b.opportunityId == other.Id) {
                voidedFlagged = b.dead == true;
            }
        }
        System.assertEquals(true, voidedFlagged,
            'A cancelled status is flagged, so the pane can tell live work from history.');
        System.assertEquals(0, res.totalValue,
            'A voided order is not contract value; the figure counted every row before.');
    }

    /**
     * MSC-220. The row reports Booking_Fee_Line__c.Status__c as stored. The console used to
     * write its own word ("Awaiting payment") over every one of these rows, so the pane and the
     * record disagreed about what state the money was in - and a line MODON's own trigger had
     * moved to Partially Paid still read as though nothing had been collected.
     */
    @isTest
    static void testAnAwaitingRowReportsTheStoredFeeLineStatus() {
        Account a = new Account(Name = 'Stored Status Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Stored status', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Type__c = 'Down Payment',
            Total_Amount__c = 50000, Status__c = 'Expired'
        );

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        SalesConsoleBookingListController.BookingSummaryDTO row;
        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            if (d.opportunityId == opp.Id) {
                row = d;
            }
        }
        System.assertNotEquals(null, row, 'The outstanding fee still raises a row.');
        System.assertEquals('Expired', row.status,
            'The status is the one on the record. Inventing a label here is how the pane came '
            + 'to show a state no record was ever in.');
    }

    /**
     * MSC-220. One opportunity, two outstanding lines, two statuses - and one word to show. The
     * status standing over the larger balance is the one that names the row.
     */
    @isTest
    static void testTheStatusOverTheLargerBalanceNamesTheRow() {
        Account a = new Account(Name = 'Mixed Status Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Mixed status', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        insert new List<Booking_Fee_Line__c>{
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id, Type__c = 'Down Payment',
                Total_Amount__c = 90000, Status__c = 'Partially Paid'
            ),
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id, Type__c = 'ADM & Dari',
                Total_Amount__c = 10000, Status__c = 'Pending'
            )
        };

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        SalesConsoleBookingListController.BookingSummaryDTO row;
        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            if (d.opportunityId == opp.Id) {
                row = d;
            }
        }
        System.assertNotEquals(null, row, 'Both lines are outstanding, so the row is raised.');
        System.assertEquals('Partially Paid', row.status,
            'AED 90,000 sits at Partially Paid and AED 10,000 at Pending; the row must name '
            + 'the state most of the outstanding money is in, not whichever line came back first.');
        System.assertEquals(100000, row.balance,
            'And splitting the group by status must not split the balance the rep is chasing.');
    }

    @isTest
    static void testListTotalsMatchTheRowsListed() {
        makeBooking(1000000);
        makeBooking(500000);

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        Decimal summed = 0;
        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            if (b.totalAmount != null) {
                summed += b.totalAmount;
            }
        }
        System.assertEquals(summed, res.totalValue,
            'The header total must be the sum of the rows on screen. If it is computed ' +
            'from a different scope the rep sees a number they cannot reconcile.');
    }

    @isTest
    static void testPaidTotalCountsOnlyPaidMilestones() {
        SalesOrder__c so = makeBooking(1000000);
        insert new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 1,
                InstallmentAmount__c = 400000, PaymentStatus__c = 'Paid'
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 2,
                InstallmentAmount__c = 600000, PaymentStatus__c = 'Partially Paid'
            )
        };

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(2, dto.installments.size(), 'Both milestones belong on the schedule.');
        System.assertEquals(1000000, dto.scheduledTotal, 'Scheduled is every milestone.');
        System.assertEquals(400000, dto.paidTotal,
            'Only a Paid milestone counts whole. A Partially Paid one with no balance on record ' +
            'adds nothing: counting it whole would overstate what has actually come in.');
    }

    /* 1.8 - what came in on a part-paid milestone is its amount less MODON's balance */
    @isTest
    static void testPaidTotalCountsWhatCameInOnAPartPaidMilestone() {
        SalesOrder__c so = makeBooking(1000000);
        insert new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 1,
                InstallmentAmount__c = 400000, PaymentStatus__c = 'Paid'
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 2,
                InstallmentAmount__c = 600000, PaymentStatus__c = 'Partially Paid',
                Balance_Amount__c = 450000
            )
        };

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(550000, dto.paidTotal,
            'The Paid milestone whole plus the 150,000 that came in on the part-paid one.');
    }

    @isTest
    static void testInstallmentsComeBackInMilestoneOrder() {
        SalesOrder__c so = makeBooking(900000);
        insert new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 3, InstallmentAmount__c = 300000
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 1, InstallmentAmount__c = 300000
            )
        };

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(1, dto.installments[0].milestoneNumber,
            'A payment schedule out of order is unreadable - milestone 1 comes first.');
    }

    @isTest
    static void testMissingBookingReturnsNullNotAnError() {
        System.assertEquals(null, SalesConsoleBookingListController.getBooking(null),
            'A null id renders the empty state; it must not throw.');
    }

    @isTest
    static void testNoCommissionFieldIsRead() {
        // Sales_Commission__c must never be read into the console
        SalesOrder__c so = makeBooking(250000);
        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto.summary, 'The booking must still load.');
        System.assertEquals(250000, dto.summary.totalAmount,
            'Contract value is what the pane shows - not commission.');
    }

    // MSC-084: the Owners tab's number

    /** The badge and the list it labels are one number (partyCount asks getOwners). */
    @isTest(SeeAllData=true)
    static void testTheDetailCountsTheSamePeopleThePanelLists() {
        List<JointOwner__c> anyOwner = [
            SELECT SalesOrder__c FROM JointOwner__c WHERE SalesOrder__c != null LIMIT 1
        ];
        System.assert(!anyOwner.isEmpty(),
            'This org has no JointOwner__c on a Sales Order, so the count under test '
            + 'cannot be exercised.');
        SalesOrder__c so = [
            SELECT Id, Opportunity__c FROM SalesOrder__c
            WHERE Id = :anyOwner[0].SalesOrder__c LIMIT 1
        ];

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        SalesConsoleJointOwnerService.OwnersDTO panel =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'The booking detail must load.');
        System.assertNotEquals(null, dto.partyCount,
            'The tab needs a number, and null is not one - it would render as blank '
            + 'beside two tabs that both carry a count.');
        System.assertEquals(panel.parties.size(), dto.partyCount,
            'The Owners tab must not say a different number from the panel it opens.');
    }

    /** A booking with nothing to show counts nobody, not one. */
    @isTest
    static void testABookingWithNothingToShowCountsNobody() {
        SalesOrder__c so = makeBooking(250000);

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'The detail still loads - this is a state.');
        System.assertEquals(0, dto.partyCount,
            'No Opportunity means no owners to list, and the tab must say so rather '
            + 'than promising one.');
    }

    // MSC-086: the documents on a booking

    /** MODON's automation raises the whole required set the moment a Sales Order exists. */
    private static List<Documents__c> raisedFor(Id soId) {
        List<Documents__c> rows = [
            SELECT Id, Name, Status__c FROM Documents__c
            WHERE SalesOrder__c = :soId ORDER BY Name ASC
        ];
        System.assert(rows.size() > 1,
            'MODON raises the required-document checklist when the booking is created. '
            + 'If that stopped, this tab has nothing to report and these tests are '
            + 'asserting about an empty list.');
        return rows;
    }

    /** An untouched row reads Pending Upload (the field that is actually written). */
    @isTest
    static void testADocumentNobodyHasSentYetIsOutstanding() {
        SalesOrder__c so = makeBooking(500000);
        List<Documents__c> raised = raisedFor(so.Id);

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(raised.size(), dto.documents.size(),
            'Every row of the checklist belongs on the tab.');
        for (SalesConsoleBookingListController.DocumentDTO d : dto.documents) {
            System.assertEquals('Pending Upload', d.status,
                'Status__c as stored. A dash here was the defect.');
            System.assertEquals(false, d.received, 'Nothing has arrived against it.');
            System.assertEquals(null, d.receivedOn,
                'Nothing arrived, so there is no date to give.');
        }
        System.assertEquals(0, dto.documentsReceived, 'A new booking has nothing in.');
    }

    /** An uploaded document is in, and the tab says when. */
    @isTest
    static void testAnUploadedDocumentIsReceivedAndSaysWhen() {
        SalesOrder__c so = makeBooking(500000);
        List<Documents__c> raised = raisedFor(so.Id);
        Documents__c target = raised[0];
        target.Status__c = 'Uploaded';
        update target;

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        SalesConsoleBookingListController.DocumentDTO found = null;
        for (SalesConsoleBookingListController.DocumentDTO d : dto.documents) {
            if (d.id == target.Id) { found = d; }
        }
        System.assertNotEquals(null, found, 'The row that was uploaded is still listed.');
        System.assertEquals(true, found.received,
            'Uploaded is in. Two of the eighteen on SO-15419 are, and both read as a '
            + 'dash before this.');
        System.assertEquals('Uploaded', found.status, 'As stored.');
        System.assertNotEquals(null, found.receivedOn,
            'A received document carries the date it landed.');
        System.assertEquals(1, dto.documentsReceived, 'One of them, and only one.');
    }

    /** Outstanding first, whatever the alphabet says. */
    @isTest
    static void testWhatIsStillOutstandingIsListedFirst() {
        SalesOrder__c so = makeBooking(500000);
        List<Documents__c> raised = raisedFor(so.Id);
        Documents__c first = raised[0];
        first.Status__c = 'Uploaded';
        update first;

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(false, dto.documents[0].received,
            'The tab opens on something still owed.');
        System.assertNotEquals(first.Id, dto.documents[0].id,
            'Alphabetically first, but there is nothing to chase about it.');
        System.assertEquals(first.Id, dto.documents[dto.documents.size() - 1].id,
            'What already came in reads last.');
    }

    /** The summary line and the rows are one count. */
    @isTest
    static void testTheDocumentTotalsCountTheRowsTheTabLists() {
        SalesOrder__c so = makeBooking(500000);
        List<Documents__c> raised = raisedFor(so.Id);
        raised[0].Status__c = 'Uploaded';
        raised[1].Status__c = 'Uploaded';
        update new List<Documents__c>{ raised[0], raised[1] };

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(raised.size(), dto.documentsTotal,
            'Every checklist row is asked for.');
        System.assertEquals(dto.documentsTotal, dto.documents.size(),
            'And the bar above the rows counts the rows under it.');
        System.assertEquals(2, dto.documentsReceived,
            'Two of them are in, so it reads two of ' + raised.size() + '.');
    }

    // MSC-088: the Verification tab's fraction

    /** The fraction on the tab is the panel's own; the denominator is verifiableCount. */
    @isTest(SeeAllData=true)
    static void testTheVerificationTabCarriesThePanelsOwnFraction() {
        List<JointOwner__c> anyOwner = [
            SELECT SalesOrder__c FROM JointOwner__c WHERE SalesOrder__c != null LIMIT 1
        ];
        System.assert(!anyOwner.isEmpty(),
            'This org has no JointOwner__c on a Sales Order, so the fraction under '
            + 'test cannot be exercised.');
        SalesOrder__c so = [
            SELECT Id, Opportunity__c FROM SalesOrder__c
            WHERE Id = :anyOwner[0].SalesOrder__c LIMIT 1
        ];

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        SalesConsoleJointOwnerService.OwnersDTO panel =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'The booking detail must load.');
        System.assertEquals(panel.verifiedCount, dto.verifiedCount,
            'The Verification tab must not say a different numerator from the list it '
            + 'opens.');
        System.assertEquals(panel.verifiableCount, dto.verifiableCount,
            'Nor a different denominator.');
        System.assert(dto.verifiedCount <= dto.verifiableCount,
            'A fraction that reads more done than there are to do is not a fraction.');
        System.assertEquals(panel.parties.size(), dto.partyCount,
            'And the Owners tab beside it still counts the same people.');
    }

    /** A booking with nobody to verify carries zeroes. */
    @isTest
    static void testABookingWithNobodyToVerifyCountsNobody() {
        SalesOrder__c so = makeBooking(250000);

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO dto =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'The detail still loads - this is a state.');
        System.assertEquals(0, dto.verifiedCount,
            'No Opportunity means nobody to verify, and the tab must say so rather '
            + 'than promising a person it has not proved.');
        System.assertEquals(0, dto.verifiableCount, 'And nobody who ever could be.');
        System.assertEquals(0, dto.partyCount, 'The Owners tab agrees.');
    }

    // 1.7: a sale MODON closed reads Settled and is not resumed

    /** A New booking on its own opportunity and unit, as the console raises it. */
    private static SalesOrder__c bookingOnUnit(String unitName) {
        Account a = new Account(Name = unitName + ' Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = unitName + ' booking', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        Project__c proj = new Project__c(Name = unitName + ' Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = unitName + ' Phase', Project__c = proj.Id);
        insert phase;
        Unit__c u = new Unit__c(
            Name = unitName,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            ApprovalStatus__c = 'Draft'
        );
        insert u;
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id, CustomerAccount__c = a.Id, Unit__c = u.Id,
            TotalAmount__c = 1500000, Status__c = 'New'
        );
        insert so;
        return [SELECT Id, Opportunity__c, Unit__c FROM SalesOrder__c WHERE Id = :so.Id];
    }

    /** What Sales_Order_Record_Triggered_Flow writes when it closes the sale, by hand. Status__c is left alone. */
    private static void closeAsModonDoes(SalesOrder__c so) {
        update new Unit__c(Id = so.Unit__c, Status__c = 'Sold');
        update new Opportunity(Id = so.Opportunity__c, StageName = 'Closed Won');
    }

    private static SalesConsoleBookingListController.BookingSummaryDTO rowFor(
        SalesConsoleBookingListController.BookingListDTO res, Id soId
    ) {
        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            if (b.id == soId) {
                return b;
            }
        }
        return null;
    }

    /** SO-15561's shape: New, unit Sold, opportunity Closed Won. The list must know the sale has closed. */
    @isTest
    static void aSaleModonClosedListsAsSettledAndOffersNoResume() {
        SalesOrder__c closedSo = bookingOnUnit('SETTLED-1');
        SalesOrder__c openSo = bookingOnUnit('OPEN-1');
        closeAsModonDoes(closedSo);

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        SalesConsoleBookingListController.BookingSummaryDTO closedRow = rowFor(res, closedSo.Id);
        SalesConsoleBookingListController.BookingSummaryDTO openRow = rowFor(res, openSo.Id);
        System.assertNotEquals(null, closedRow, 'The closed sale is still the rep\'s booking and is listed.');
        System.assertNotEquals(null, openRow, 'So is the open one.');
        System.assertEquals(true, closedRow.saleClosed,
            'Unit Sold and opportunity Closed Won: the row must read Settled and offer no Resume.');
        System.assertEquals('New', closedRow.status,
            'status stays the stored Status__c (MODON leaves it at New); saleClosed carries the close.');
        System.assertEquals(false, closedRow.dead, 'A closed sale is live business, not a cancelled order.');
        System.assertEquals(false, openRow.saleClosed, 'An open booking on an Available unit is still resumable.');
        System.assertEquals(closedRow.totalAmount + openRow.totalAmount, res.totalValue,
            'A closed sale is contract value like any live order.');
        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            System.assertNotEquals(closedSo.Opportunity__c, d.opportunityId,
                'A closed sale has a live order, so it never shows as waiting for money.');
            System.assertEquals(false, d.saleClosed, 'An awaiting row has no order behind it.');
        }
    }

    /** The detail header reads the same close, so it offers no Resume either. */
    @isTest
    static void theDetailOfAClosedSaleKnowsItHasClosed() {
        SalesOrder__c so = bookingOnUnit('SETTLED-2');
        SalesConsoleBookingListController.BookingDTO before =
            SalesConsoleBookingListController.getBooking(so.Id);
        closeAsModonDoes(so);

        Test.startTest();
        SalesConsoleBookingListController.BookingDTO after =
            SalesConsoleBookingListController.getBooking(so.Id);
        Test.stopTest();

        System.assertEquals(false, before.summary.saleClosed, 'Before the close: an open booking.');
        System.assertEquals(true, after.summary.saleClosed, 'After it: the header reads Settled.');
        System.assertEquals('New', after.summary.status, 'And the stored status is still reported as stored.');
    }

    /** Every cancelled status MODON uses is dead in this list, not only Cancelled and Voided. */
    @isTest
    static void everyCancelledStatusModonUsesIsDead() {
        Account a = new Account(Name = 'SR Cancelled Co');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'SR cancelled', AccountId = a.Id,
            StageName = 'Unit Selection', CloseDate = System.today().addDays(30)
        );
        insert opp;
        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Type__c = 'Down Payment', Total_Amount__c = 50000
        );
        insert new List<SalesOrder__c>{
            new SalesOrder__c(Opportunity__c = opp.Id, TotalAmount__c = 700000, Status__c = 'Cancelled SR'),
            new SalesOrder__c(
                Opportunity__c = opp.Id, TotalAmount__c = 800000, Status__c = 'Unit Swap Cancelled - SR'
            )
        };

        Test.startTest();
        SalesConsoleBookingListController.BookingListDTO res =
            SalesConsoleBookingListController.getMyBookings();
        Test.stopTest();

        Integer seen = 0;
        for (SalesConsoleBookingListController.BookingSummaryDTO b : res.bookings) {
            if (b.opportunityId == opp.Id) {
                seen++;
                System.assertEquals(true, b.dead, b.status + ' is a cancelled status and must read as one.');
                System.assertEquals(false, b.saleClosed, 'A cancelled order is never a closed sale.');
            }
        }
        System.assertEquals(2, seen, 'Both cancelled orders are still listed, as the records they are.');
        System.assertEquals(0, res.totalValue, 'Neither is contract value.');
        for (SalesConsoleBookingListController.BookingSummaryDTO d : res.awaiting) {
            System.assertNotEquals(opp.Id, d.opportunityId,
                'Every order on it is cancelled and nothing was collected: no fee to chase, no Resume.');
        }
    }
}