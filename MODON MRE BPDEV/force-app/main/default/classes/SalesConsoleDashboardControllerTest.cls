/**
 * Tests for SalesConsoleDashboardController.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 * 1.1      Aurelix IT  09 Aug 2026  Guards for the corrected status filters.
 * 1.2      Aurelix Dev 29 Sep 2026  Available Units counts with the Sales App's unit list
 *                                   filter (testAvailableUnitsFollowTheSalesAppsListFilter).
 *
 * What these protect: the hub is scoped to the running user, and one bad card never
 * takes the whole hub down. Both are easy to lose in a refactor and neither shows up
 * as an error - the numbers just quietly become someone else's.
 *
 * 1.1 adds the other silent failure. Two filters named picklist values this org does
 * not have - Lead 'Working - Contacted' and SalesOrder__c 'Sold' - so those stages
 * read low with nothing to indicate anything was wrong. A wrong status string cannot
 * fail loudly, so it has to be tested for.
 */
@isTest
private class SalesConsoleDashboardControllerTest {

    /** Owned by the running user by default, which is the scope the hub counts. */
    private static SalesOrder__c makeOrder(Decimal amount, String status, String downPayment) {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = amount);
        if (String.isNotBlank(status)) {
            so.Status__c = status;
        }
        if (String.isNotBlank(downPayment)) {
            so.Down_Payment_Status__c = downPayment;
        }
        insert so;
        return so;
    }

    @isTest
    static void testThemeRoundTrips() {
        Test.startTest();
        SalesConsoleDashboardController.saveThemePreference('Light');
        Test.stopTest();

        System.assertEquals('Light',
            SalesConsoleDashboardController.getMyThemePreference(),
            'A saved theme must come back, or the choice will not follow the rep between devices.');
    }

    @isTest
    static void testThemeRejectsUnknownValue() {
        SalesConsoleDashboardController.saveThemePreference('Light');
        Test.startTest();
        SalesConsoleDashboardController.saveThemePreference('Neon');
        Test.stopTest();

        System.assertEquals('Light',
            SalesConsoleDashboardController.getMyThemePreference(),
            'An unrecognised theme must be ignored rather than stored - the picklist is ' +
            'restricted, so writing one would throw on a field the toggle cannot recover from.');
    }

    @isTest
    static void testNameIsResolved() {
        System.assert(String.isNotBlank(SalesConsoleDashboardController.getMyName()),
            'The shell greets the running user by name; blank would render "Good morning, ".');
    }

    @isTest
    static void testMetricsCountOnlyTheRunningUser() {
        // ProjectInterest__c is the one required custom field on Lead in this org.
        Lead mine = new Lead(
            FirstName = 'Mine',
            LastName = 'Lead',
            Company = 'Test Co',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert mine;

        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertNotEquals(null, d, 'The hub must always render.');
        System.assert(d.newLeads >= 1,
            'A lead owned by the running user must appear in their own count.');
        System.assertEquals(d.activeEoi, d.funnelEoi,
            'The EOI card and the EOI funnel stage are the same number - the PoC ' +
            'interpolated the funnel value because it had no EOI object; this org has one.');
    }

    @isTest
    static void testMetricsNeverReturnNull() {
        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        // Every card renders a number. A null here reaches the UI as "undefined",
        // which reads as a broken console rather than an empty one.
        System.assertNotEquals(null, d.totalSalesMTD, 'Total sales must default to zero, not null.');
        System.assertNotEquals(null, d.availableUnits, 'Available units must default to zero, not null.');
        System.assertNotEquals(null, d.activeEoi, 'EOI must default to zero, not null.');
        System.assertNotEquals(null, d.funnelLeads, 'Funnel stages must default to zero, not null.');
    }

    /*** 1.1  Start: Aurelix IT 09 Aug 2026, corrected status filters ***********/

    /**
     * The Qualified stage previously filtered on 'Working - Contacted', a standard
     * Salesforce value that this org's Lead status picklist does not contain. It
     * matched nothing, so an unconverted qualified lead never reached the stage.
     */
    @isTest
    static void testQualifiedStageCountsThisOrgsLeadStatus() {
        Lead l = new Lead(
            FirstName = 'Qualified',
            LastName = 'Lead',
            Company = 'Test Co',
            ProjectInterest__c = 'Nawayef Homes',
            Status = Constants.LEAD_STATUS_QUALIFY
        );
        insert l;
        // Lead automation can reassign on insert, and the hub counts by owner.
        update new Lead(
            Id = l.Id,
            OwnerId = UserInfo.getUserId(),
            Status = Constants.LEAD_STATUS_QUALIFY
        );

        Lead check = [SELECT Status, OwnerId, IsConverted FROM Lead WHERE Id = :l.Id];
        System.assertEquals(Constants.LEAD_STATUS_QUALIFY, check.Status,
            'Precondition: the qualified status must have stuck, or this test proves nothing.');
        System.assertEquals(UserInfo.getUserId(), check.OwnerId,
            'Precondition: the lead must be owned by the running user.');
        System.assertEquals(false, check.IsConverted,
            'Precondition: it must count through Status, not through IsConverted - ' +
            'a converted lead would pass even with the wrong status string.');

        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertEquals(1, d.funnelQualified,
            'A lead at ' + Constants.LEAD_STATUS_QUALIFY + ' must reach the Qualified ' +
            'stage. If this is 0 the filter is naming a status this org does not have.');
    }

    /**
     * The Paid stage previously filtered on Status__c IN ('Sold', 'Completed').
     * 'Sold' is a Unit__c status, not a SalesOrder__c one. Whether money arrived is
     * Down_Payment_Status__c, which is what the rest of the org reads.
     */
    @isTest
    static void testPaidStageReadsTheDownPaymentStatus() {
        makeOrder(1000000, null, Constants.PAYMENTSTATUS_PAID);
        makeOrder(750000, null, null);

        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertEquals(1, d.funnelPaid,
            'Only the order whose down payment is Paid reaches the Paid stage.');
        System.assertEquals(2, d.funnelBooked,
            'Both are real bookings; only one of them has been paid.');
    }

    /**
     * A cancelled order is not a booking and not a sale. Counting it made the rep's
     * hub disagree with every other view of the same data in the org.
     */
    @isTest
    static void testCancelledOrdersAreLeftOutOfBookingsAndSales() {
        makeOrder(1000000, null, null);
        makeOrder(400000, 'Cancelled', null);

        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertEquals(1, d.bookings,
            'A cancelled order must not be counted as a booking.');
        System.assertEquals(1000000, d.totalSalesMTD,
            'Total sales for the month must exclude the cancelled order - ' +
            'AED 1.4M here would be money Modon never sold.');
    }
    /*** 1.1  End *******************/

    /*** 1.2  Start - Aurelix Dev 29 Sep 2026, unit list filter *******************/

    /** The card counts what the unit list offers: the Sales App's filter, then edit access. */
    @isTest
    static void testAvailableUnitsFollowTheSalesAppsListFilter() {
        Project__c pr = new Project__c(Name = 'QA Dashboard Project');
        insert pr;
        Phase__c ph = new Phase__c(Name = 'QA Dashboard Phase', Project__c = pr.Id);
        insert ph;
        List<Unit__c> units = new List<Unit__c>{
            dashUnit(ph.Id, 'QA-DASH-1', 'Un-Assigned', null),
            dashUnit(ph.Id, 'QA-DASH-2', null, null),
            dashUnit(ph.Id, 'QA-DASH-3', 'Assigned', null),
            dashUnit(ph.Id, 'QA-DASH-4', 'Assigned', UserInfo.getUserId()),
            dashUnit(ph.Id, 'QA-DASH-5', 'Un-Assigned', null)
        };
        insert units;
        insert new SalesOrder__c(TotalAmount__c = 1, Unit__c = units[4].Id);

        Test.startTest();
        SalesConsoleDashboardController.DashboardDTO d =
            SalesConsoleDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertEquals(2, d.availableUnits,
            'Only the Un-Assigned unit and the unit Assigned to this rep are bookable; a blank sub '
            + 'status, a unit assigned to nobody in particular and a unit with a live order are not.');
    }

    private static Unit__c dashUnit(Id phaseId, String name, String subStatus, Id blockedFor) {
        return new Unit__c(
            Name = name,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = '4',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = subStatus,
            BlockedFor__c = blockedFor,
            ApprovalStatus__c = 'Draft'
        );
    }
    /*** 1.2  End ***************************************************************/
}