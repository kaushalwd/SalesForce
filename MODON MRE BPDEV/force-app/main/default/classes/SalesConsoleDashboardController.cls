/**
 * SalesConsoleDashboardController - the console shell and its landing hub.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Running user's name, theme preference,
 *                                   and the four hub metrics.
 * 1.1      Aurelix IT  09 Aug 2026  Status filters corrected against this org. Two of
 *                                   them named values that do not exist here, so the
 *                                   counts behind them could only ever read low.
 * 1.2      Aurelix IT  12 Aug 2026  Available Units counts units the agent can BOOK,
 *                                   not every unit in the org. The browser beneath the
 *                                   card now shows only units they can edit, so the two
 *                                   disagreed - 1,116 against 25.
 * 1.3      Aurelix Dev 29 Sep 2026  Available Units uses the unit list's filter (the Sales App's
 *                                   UnitSearchLwcController.getUnitDetails), then edit access as
 *                                   before, so the card matches the list.
 */

/**
 * Everything the shell and hub need, in as few round trips as possible.
 *
 * Metrics are scoped to the running user, not the org - a rep's hub answers "how am I
 * doing", not "how is Modon doing". That now includes unit stock: it was counted
 * org-wide as shared inventory, but a unit the agent cannot edit cannot be booked by
 * them, so it was answering a question nobody on this screen asked.
 *
 * Ported from ModonSalesController in the PoC org, which ran on its own Booking__c /
 * Payment__c schema. Every count here is re-pointed at the real objects.
 */
public with sharing class SalesConsoleDashboardController {

    /** Four cards plus the funnel behind them. */
    public class DashboardDTO {
        @AuraEnabled public Integer availableUnits = 0;
        @AuraEnabled public Integer newLeads = 0;
        @AuraEnabled public Decimal totalSalesMTD = 0;
        @AuraEnabled public Integer activeEoi = 0;

        @AuraEnabled public Integer activeOpportunities = 0;
        @AuraEnabled public Integer bookings = 0;

        // Leads -> Qualified -> EOI -> Booked -> Paid.
        @AuraEnabled public Integer funnelLeads = 0;
        @AuraEnabled public Integer funnelQualified = 0;
        @AuraEnabled public Integer funnelEoi = 0;
        @AuraEnabled public Integer funnelBooked = 0;
        @AuraEnabled public Integer funnelPaid = 0;
    }

    /**
     * The real logged-in user. The shell also takes a userName design attribute, but
     * that is whoever configured the Experience Builder page - so every rep was being
     * greeted by the admin's name until this overrode it.
     */
    @AuraEnabled(cacheable=true)
    public static String getMyName() {
        return UserInfo.getFirstName() != null
            ? UserInfo.getFirstName()
            : UserInfo.getName();
    }

    /** 'Dark' | 'Light'. Blank until the user has ever chosen; the shell defaults to Dark. */
    @AuraEnabled(cacheable=true)
    public static String getMyThemePreference() {
        List<User> us = [
            SELECT Console_Theme__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        return us.isEmpty() ? null : us[0].Console_Theme__c;
    }

    /**
     * Persisted so the choice follows the rep between devices. The console writes
     * localStorage too and does not wait on this - a failed save costs a preference,
     * not a session, so it must never surface as an error mid-journey.
     */
    @AuraEnabled
    public static void saveThemePreference(String theme) {
        if (theme != 'Dark' && theme != 'Light') {
            return;
        }
        try {
            update new User(Id = UserInfo.getUserId(), Console_Theme__c = theme);
        } catch (Exception e) {
            // Some orgs restrict User DML for non-admins. Losing the preference is
            // survivable; throwing here would break the theme toggle for those users.
            System.debug('SalesConsoleDashboardController: theme not saved - ' + e.getMessage());
        }
    }

    /**
     * The hub, in one call.
     *
     * Sandbox note: almost every Sales Order here is owned by an admin, so a rep-scoped
     * total reads near zero. That is thin data, not a broken query.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardDTO getDashboardMetrics() {
        DashboardDTO d = new DashboardDTO();
        Id uid = UserInfo.getUserId();
        Date monthStart = System.today().toStartOfMonth();
        List<String> deadStatuses = cancelledSalesOrderStatuses();

        try {
            d.availableUnits = availableUnitsIcanBook();
        } catch (Exception e) {
            d.availableUnits = 0;
        }

        d.newLeads = [
            SELECT COUNT() FROM Lead WHERE IsConverted = FALSE AND OwnerId = :uid
        ];
        d.activeOpportunities = [
            SELECT COUNT() FROM Opportunity WHERE IsClosed = FALSE AND OwnerId = :uid
        ];
        // 1.1 - a cancelled or voided order is not a booking. Counting them made the
        // rep's own figure disagree with every other view of the same data in the org.
        d.bookings = [
            SELECT COUNT() FROM SalesOrder__c
            WHERE OwnerId = :uid AND Status__c NOT IN :deadStatuses
        ];

        // Sold this month, not collected. TotalAmount__c is the contract value on the
        // Sales Order; Receipt__c would answer a different question ("what came in").
        AggregateResult ar = [
            SELECT SUM(TotalAmount__c) total
            FROM SalesOrder__c
            WHERE OwnerId = :uid
              AND CreatedDate >= :monthStart
              AND Status__c NOT IN :deadStatuses
        ];
        Object total = ar == null ? null : ar.get('total');
        d.totalSalesMTD = total == null ? 0 : (Decimal) total;

        // --- Funnel -------------------------------------------------------------
        d.funnelLeads = [SELECT COUNT() FROM Lead WHERE OwnerId = :uid];

        // 1.1 - was Status = 'Working - Contacted', which is a standard Salesforce
        // value carried over from the PoC and is NOT in this org's Lead status
        // picklist (New, In Progress, Lead Qualified, Open - Not Contacted,
        // Expression of Interest, Qualified, Duplicate, Retired). It matched nothing,
        // so this stage only ever counted converted leads. Constants.LEAD_STATUS_QUALIFY
        // is the org's own name for the qualified state - LeadTriggerHandler already
        // uses it, so the funnel and the trigger now agree.
        d.funnelQualified = [
            SELECT COUNT() FROM Lead
            WHERE (Status = :Constants.LEAD_STATUS_QUALIFY OR IsConverted = TRUE)
              AND OwnerId = :uid
        ];

        d.funnelBooked = d.bookings;

        // 1.1 - was Status__c IN ('Sold', 'Completed'). 'Sold' is a Unit__c status,
        // not a SalesOrder__c one, so that half matched nothing. More to the point the
        // stage is called Paid, and the order's own status does not say whether money
        // arrived - Down_Payment_Status__c does, which is what CommissionLogicHandler
        // reads to decide the same question.
        d.funnelPaid = [
            SELECT COUNT() FROM SalesOrder__c
            WHERE OwnerId = :uid
              AND Down_Payment_Status__c = :Constants.PAYMENTSTATUS_PAID
              AND Status__c NOT IN :deadStatuses
        ];

        // The PoC interpolated this between Qualified and Booked because it had no EOI
        // object. This org does, so it is a real count - expect it to differ from the
        // PoC's figure for the same rep.
        //
        // Expressionofinterest__c has no OwnerId - it is not an ownable object here -
        // so "mine" is resolved through the Opportunity, which is owned. That is also
        // the truer reading: an EOI belongs to whoever is working the opportunity.
        d.activeEoi = [
            SELECT COUNT() FROM Expressionofinterest__c
            WHERE Opportunity__r.OwnerId = :uid
              AND Status__c NOT IN ('Cancelled', 'Voided', 'Expired', 'Rejected')
        ];
        d.funnelEoi = d.activeEoi;

        return d;
    }

    /*** 1.2  Start: the card counts what the agent can actually book ************
     *
     * This was `SELECT COUNT() FROM Unit__c WHERE Status__c = 'Available'`, org-wide,
     * on the reasoning that inventory is shared stock. That stopped being true when
     * SalesConsoleController.searchUnits began filtering the browser to units the
     * agent can EDIT - booking one needs edit access, and Unit__c is OWD Private. The
     * card promised 1,116 and the browser underneath it offered 25.
     *
     * Same rule as the leads card beside it: a headline number counts what the agent
     * can act on, or it is not worth showing.
     *
     * Bounded deliberately. There is no SOQL for "editable", so this reads the ids and
     * asks UserRecordAccess in blocks of 200 - the platform's per-query maximum. The
     * id read is capped so a much larger inventory cannot turn one dashboard into
     * hundreds of queries; past the cap the card reports the cap, which is a headline
     * figure behaving like one rather than a wrong number.
     */
    private static final Integer UNIT_SCAN_CAP = 5000;

    private static Integer availableUnitsIcanBook() {
        Id uid = UserInfo.getUserId();
        /* 1.3 - the Sales App's list filter (UnitSearchLwcController.getUnitDetails) */
        List<Unit__c> available = new List<Unit__c>();
        for (Unit__c u : [
            SELECT Id,
                   (SELECT Id FROM Sales_Orders__r
                    WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided') LIMIT 1)
            FROM Unit__c
            WHERE ((Status__c = :Constants.STATUS_AVAILABLE AND Sub_Status__c = 'Un-Assigned')
                   OR (Sub_Status__c = 'Assigned' AND BlockedFor__c = :uid))
              AND Opportunity__c = null
            LIMIT :UNIT_SCAN_CAP
        ]) {
            if (u.Sales_Orders__r.isEmpty()) {
                available.add(u);
            }
        }
        if (available.isEmpty()) {
            return 0;
        }
        Integer bookable = 0;
        List<Id> chunk = new List<Id>();
        for (Integer i = 0; i < available.size(); i++) {
            chunk.add(available[i].Id);
            if (chunk.size() == 200 || i == available.size() - 1) {
                // COUNT() is rejected here - UserRecordAccess requires RecordId in the
                // SELECT - so the rows are counted rather than the query.
                bookable += [
                    SELECT RecordId FROM UserRecordAccess
                    WHERE UserId = :uid AND RecordId IN :chunk AND HasEditAccess = TRUE
                ].size();
                chunk.clear();
            }
        }
        return bookable;
    }
    /*** 1.2  End ***************************************************************/

    /**
     * 1.1 - the org's own list of Sales Order statuses that mean "this did not
     * happen": Cancelled, System cancelled, Voided, Cancelled SR and the six
     * per-service-request cancellations.
     *
     * Read from the CommissionCancelStatus custom label rather than hardcoded here.
     * The label is a Modon-maintained list that five batches already depend on, so
     * a status added there reaches the console with no code change - and the console
     * cannot drift into disagreeing with the rest of the org about what a live
     * booking is. CollectionInsightSalesOrderController hardcodes the same ten
     * values twice, which is the drift this avoids.
     *
     * The label's name is a legacy of where it was first needed. Nothing about
     * commission is read, computed or shown here - see
     * SalesConsoleBookingListControllerTest.testNoCommissionFieldIsRead.
     */
    // 1.2 - public so SalesConsoleBookingListController reads the same list rather
    // than growing a second copy. Sharing the reader is the whole point of it.
    public static List<String> cancelledSalesOrderStatuses() {
        String raw;
        try {
            raw = System.Label.CommissionCancelStatus;
        } catch (Exception e) {
            raw = null;
        }
        if (String.isBlank(raw)) {
            // A missing label must not silently widen every count to include
            // cancelled orders, so fall back to the statuses that exist today.
            return new List<String>{
                'Cancelled', 'System cancelled', 'Voided', 'Cancelled SR'
            };
        }
        List<String> out = new List<String>();
        for (String s : raw.split(',')) {
            if (String.isNotBlank(s)) {
                out.add(s.trim());
            }
        }
        return out;
    }
}