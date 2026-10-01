/**
 * SalesConsoleBookingListController - the Total Sales pane.
 *
 * Version  Author      Date         Detail
 * 1.9      Aurelix Dev 29 Sep 2026  PAID adds what came in on a Partially Paid milestone (InstallmentAmount__c
 *                                   less Balance_Amount__c). "N of M milestones paid" still counts Paid only.
 * 1.8      Aurelix Dev 29 Sep 2026  BookingSummaryDTO.saleClosed (AurelixSaleClosed): a sale MODON's flow closed
 *                                   but left at New shows "Settled" in c/mscBookings, with no Resume.
 * 1.7      Aurelix Dev 02 Sep 2026  MSC-220. The pane shows stored status only. An awaiting row
 *                                   now carries its Booking_Fee_Line__c.Status__c (Pending,
 *                                   Partially Paid, Expired ...) instead of the invented
 *                                   "Awaiting payment"; and notStarted is withdrawn - MSC-219's
 *                                   "Booking not started" was a console-invented status with no
 *                                   record behind it, and business asked for it off the table.
 *                                   See the changelog for what that costs.
 * 1.6      Aurelix Dev 02 Sep 2026  MSC-218 / MSC-219. BookingSummaryDTO.unitAvailable (an
 *                                   awaiting row whose unit went Sold is a dead end, not a
 *                                   Resume); .dead (the label-driven cancelled list, so the
 *                                   pane can default to live rows without hardcoding MODON's
 *                                   vocabulary); notStarted - converted customers with no order
 *                                   and no fee line, reachable nowhere else in the console;
 *                                   totalValue no longer counts cancelled orders.
 * 1.5      Aurelix Dev 02 Sep 2026  MSC-217. An "Awaiting payment" row is dropped when the money
 *                                   it chases is owed by nobody: every Sales Order on that
 *                                   opportunity is dead (Voided / Cancelled / System cancelled)
 *                                   AND nothing was ever collected against its fee lines. The
 *                                   org's cancellation does not zero the unpaid request, so the
 *                                   pane was offering a Resume for a booking that no longer
 *                                   exists. Collected money always keeps the row.
 * 1.4      Aurelix IT  20 Aug 2026  MSC-088. partyCount became partyStats: one getOwners, three figures.
 * 1.3      Aurelix IT  20 Aug 2026  MSC-086. Documents tab reads Status__c and the file behind it.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-084. partyCount, from SalesConsoleJointOwnerService.
 * 1.1      Aurelix IT  12 Aug 2026  Bookings awaiting payment.
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Ports modonBookingWorkspace and modonRevenuePane onto SalesOrder__c.
 */

/**
 * The rep's bookings: list, detail, payment schedule, documents. No commission anywhere: no sales
 * user in this org has commission access.
 */
public with sharing class SalesConsoleBookingListController {

    /* Documents__c.Status__c, MODON's vocabulary: Pending Upload is the default; anything in RECEIVED is in */
    private static final String PENDING_UPLOAD = 'Pending Upload';
    private static final String UPLOADED = 'Uploaded';
    private static final Set<String> RECEIVED = new Set<String>{
        'Uploaded', 'Generated', 'Signed'
    };

    /** A row in the list. */
    public class BookingSummaryDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public String status;
        @AuraEnabled public String subStatus;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String unitName;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Datetime createdDate;
        /* awaiting-payment rows only */
        @AuraEnabled public Decimal balance;
        @AuraEnabled public Datetime holdExpiry;
        @AuraEnabled public Boolean holdExpired;
        /**
         * MSC-218. The unit can still be booked (Available). False when it went Sold or Reserved
         * under this rep - the row is then a dead end and the pane must not offer a Resume that
         * walks into "already booked". Null on rows that are not about a unit.
         */
        @AuraEnabled public Boolean unitAvailable;
        /**
         * MSC-219. This row is one of the cancelled statuses (the label-driven list), so the
         * pane can default to the live ones without hardcoding MODON's vocabulary.
         */
        @AuraEnabled public Boolean dead = false;
        /**
         * 1.8 - MODON has closed this sale though status still reads New or In Progress
         * (AurelixSaleClosed). False on awaiting rows.
         */
        @AuraEnabled public Boolean saleClosed = false;
    }

    /** One milestone on the payment schedule. */
    public class InstallmentDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Decimal milestoneNumber;
        @AuraEnabled public String description;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String paymentStatus;
    }

    /**
     * One row of the required-document checklist. The name is the only thing that leaves the
     * server: no file name, no ContentDocument Id, no link.
     */
    public class DocumentDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        /** Documents__c.Status__c as stored. */
        @AuraEnabled public String status;
        @AuraEnabled public Boolean received = false;
        /** Only when received. */
        @AuraEnabled public Datetime receivedOn;
    }

    /** The detail behind a row. */
    public class BookingDTO {
        @AuraEnabled public BookingSummaryDTO summary;
        @AuraEnabled public List<InstallmentDTO> installments = new List<InstallmentDTO>();
        @AuraEnabled public List<DocumentDTO> documents = new List<DocumentDTO>();
        @AuraEnabled public Decimal scheduledTotal = 0;
        @AuraEnabled public Decimal paidTotal = 0;
        /* the Documents tab's pair, from one count */
        @AuraEnabled public Integer documentsTotal = 0;
        @AuraEnabled public Integer documentsReceived = 0;
        /** Everyone who owns this booking, counted by person. Zero when there is nothing to show. */
        @AuraEnabled public Integer partyCount = 0;
        /** How many have verified, and how many ever could (company joint owners excluded). */
        @AuraEnabled public Integer verifiedCount = 0;
        @AuraEnabled public Integer verifiableCount = 0;
    }

    /** List plus the header figure. */
    public class BookingListDTO {
        @AuraEnabled public List<BookingSummaryDTO> bookings = new List<BookingSummaryDTO>();
        /** Total contract value of the list. Sold, not collected. */
        @AuraEnabled public Decimal totalValue = 0;
        /** Raised, held, waiting for money. No Sales Order yet. */
        @AuraEnabled public List<BookingSummaryDTO> awaiting = new List<BookingSummaryDTO>();
    }

    /** MSC-219: the one place a row learns whether its status is a cancelled one. */
    private static Set<String> deadStatusSet() {
        return new Set<String>(SalesConsoleDashboardController.cancelledSalesOrderStatuses());
    }

    private static BookingSummaryDTO toSummary(SalesOrder__c so, Set<String> deadStatuses) {
        BookingSummaryDTO d = new BookingSummaryDTO();
        d.id = so.Id;
        d.bookingRef = so.Name;
        d.status = so.Status__c;
        d.subStatus = so.Sub_Status__c;
        d.totalAmount = so.TotalAmount__c;
        d.unitName = so.Unit__r != null ? so.Unit__r.Name : null;
        d.customerName = so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null;
        d.opportunityId = so.Opportunity__c;
        d.createdDate = so.CreatedDate;
        d.dead = so.Status__c != null && deadStatuses.contains(so.Status__c);
        /* 1.8: the query must select SalesTeamVoidCheck__c, Opportunity__r.IsWon, Unit__r.Status__c */
        d.saleClosed = AurelixSaleClosed.isClosed(so);
        return d;
    }

    /** The rep's bookings, newest first. Cancelled and voided orders are included and labelled. */
    @AuraEnabled(cacheable=true)
    public static BookingListDTO getMyBookings() {
        BookingListDTO out = new BookingListDTO();
        Set<String> deadStatuses = deadStatusSet();
        for (SalesOrder__c so : [
            SELECT Id, Name, Status__c, Sub_Status__c, TotalAmount__c, Opportunity__c,
                   CreatedDate, Unit__r.Name, CustomerAccount__r.Name,
                   SalesTeamVoidCheck__c, Opportunity__r.IsWon, Unit__r.Status__c
            FROM SalesOrder__c
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            BookingSummaryDTO d = toSummary(so, deadStatuses);
            out.bookings.add(d);
            /* MSC-219: a cancelled or voided order is not contract value. The figure was
               summing every row, so a book of voided test orders read as hundreds of millions.
               Nothing renders it today - fixed before it is ever wired up. */
            if (d.totalAmount != null && !d.dead) {
                out.totalValue += d.totalAmount;
            }
        }
        out.awaiting = awaitingPayment();
        return out;
    }

    /* Bookings waiting for money: between Take payment and the money arriving there is no Sales
     * Order. Booking_Fee_Line__c is the source (raised by beginPayment, master-detail to Opportunity). */
    private static List<BookingSummaryDTO> awaitingPayment() {
        /* MSC-220: Status__c joins the grouping so the row can report the value that is stored
           rather than a word the console made up. It splits a unit's lines by status, which the
           sums below fold back together per opportunity. */
        List<AggregateResult> rows = [
            SELECT Opportunity__c oppId, Unit__c unitId, Status__c st,
                   SUM(Balance_Amount__c) bal, SUM(Total_Paid_Amount__c) paid
            FROM Booking_Fee_Line__c
            WHERE Opportunity__r.OwnerId = :UserInfo.getUserId()
              AND Balance_Amount__c > 0
            GROUP BY Opportunity__c, Unit__c, Status__c
        ];
        List<BookingSummaryDTO> out = new List<BookingSummaryDTO>();
        if (rows.isEmpty()) {
            return out;
        }

        Map<Id, Decimal> balanceByOpp = new Map<Id, Decimal>();
        Map<Id, Id> unitByOpp = new Map<Id, Id>();
        /* MSC-217: anything ever collected against this opportunity's outstanding fee lines */
        Map<Id, Decimal> paidByOpp = new Map<Id, Decimal>();
        /**
         * MSC-220: the stored status the row will report, and the balance that earned it. One
         * opportunity can carry lines at different statuses (Pending beside Partially Paid), and
         * a row shows one word - so the status standing over the most outstanding money wins.
         * Deterministic, and it names the state most of the balance is actually in.
         */
        Map<Id, String> statusByOpp = new Map<Id, String>();
        Map<Id, Decimal> statusWeight = new Map<Id, Decimal>();
        for (AggregateResult r : rows) {
            Id oppId = (Id) r.get('oppId');
            if (oppId == null) {
                continue;
            }
            Decimal bal = (Decimal) r.get('bal');
            Decimal balHere = bal == null ? 0 : bal;
            balanceByOpp.put(oppId, (balanceByOpp.get(oppId) == null ? 0 : balanceByOpp.get(oppId))
                + balHere);
            Decimal paid = (Decimal) r.get('paid');
            paidByOpp.put(oppId, (paidByOpp.get(oppId) == null ? 0 : paidByOpp.get(oppId))
                + (paid == null ? 0 : paid));
            if (r.get('unitId') != null) {
                unitByOpp.put(oppId, (Id) r.get('unitId'));
            }
            String st = (String) r.get('st');
            if (String.isNotBlank(st)) {
                Decimal held = statusWeight.get(oppId);
                if (held == null || balHere > held) {
                    statusWeight.put(oppId, balHere);
                    statusByOpp.put(oppId, st);
                }
            }
        }

        // already confirmed: belongs in the booked list
        Set<Id> booked = new Set<Id>();
        /* MSC-217: and the opportunities whose every order is dead - a fee request the
           cancellation left behind, chased from nobody */
        Set<Id> deadOnly = new Set<Id>();
        List<String> deadStatuses = SalesConsoleDashboardController.cancelledSalesOrderStatuses();
        for (SalesOrder__c so : [
            SELECT Opportunity__c, Status__c FROM SalesOrder__c
            WHERE Opportunity__c IN :balanceByOpp.keySet()
        ]) {
            if (deadStatuses.contains(so.Status__c)) {
                deadOnly.add(so.Opportunity__c);
            } else {
                booked.add(so.Opportunity__c);
            }
        }
        /* an opportunity with one live order is booked, never dead-only */
        deadOnly.removeAll(booked);

        Map<Id, Unit__c> units = new Map<Id, Unit__c>([
            SELECT Id, Name, Payment_Hold_Expiry__c, Status__c
            FROM Unit__c WHERE Id IN :unitByOpp.values()
        ]);
        Datetime now = System.now();

        // newest first
        for (Opportunity opp : [
            SELECT Id, Name, CreatedDate, Account.Name
            FROM Opportunity WHERE Id IN :balanceByOpp.keySet()
            ORDER BY CreatedDate DESC
        ]) {
            if (booked.contains(opp.Id)) {
                continue;
            }
            /* MSC-217: the booking was cancelled and nothing was ever collected - the unpaid
               request is debris the org's cancellation left behind, not money to chase. Any
               collected amount keeps the row: MODON's own rule is that money, not the hold,
               is what must never be stranded. */
            Decimal paidHere = paidByOpp.get(opp.Id);
            if (deadOnly.contains(opp.Id) && (paidHere == null || paidHere <= 0)) {
                continue;
            }
            Unit__c u = units.get(unitByOpp.get(opp.Id));
            BookingSummaryDTO d = new BookingSummaryDTO();
            d.id = opp.Id;
            d.opportunityId = opp.Id;
            /* MSC-220: Booking_Fee_Line__c.Status__c as stored - Pending, Partially Paid,
               Expired. "Awaiting payment" was the console's own word for it and matched no
               record, so the pane and the record disagreed about what state this was in. */
            d.status = statusByOpp.get(opp.Id);
            d.balance = balanceByOpp.get(opp.Id);
            d.unitName = u == null ? null : u.Name;
            d.customerName = opp.Account == null ? opp.Name : opp.Account.Name;
            d.createdDate = opp.CreatedDate;
            d.holdExpiry = u == null ? null : u.Payment_Hold_Expiry__c;
            /* an expired hold still resumes; beginPayment holds again */
            d.holdExpired = d.holdExpiry != null && d.holdExpiry < now;
            /* MSC-218: the unit went to somebody else while this request sat unpaid. Resuming
               would walk into "already booked", so the pane says so and offers no Resume.
               Null when the row carries no unit - not a claim either way. */
            d.unitAvailable = u == null
                ? null
                : Constants.STATUS_AVAILABLE.equalsIgnoreCase(u.Status__c);
            out.add(d);
        }
        return out;
    }

    /** One booking with its schedule and documents. Not scoped by owner: with sharing decides. */
    @AuraEnabled(cacheable=true)
    public static BookingDTO getBooking(Id salesOrderId) {
        if (salesOrderId == null) {
            return null;
        }
        List<SalesOrder__c> sos = [
            SELECT Id, Name, Status__c, Sub_Status__c, TotalAmount__c, Opportunity__c,
                   CreatedDate, Unit__r.Name, CustomerAccount__r.Name,
                   SalesTeamVoidCheck__c, Opportunity__r.IsWon, Unit__r.Status__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
        if (sos.isEmpty()) {
            return null;
        }

        BookingDTO dto = new BookingDTO();
        dto.summary = toSummary(sos[0], deadStatusSet());
        /* the badges on the Owners and Verification tabs; getOwners never throws */
        SalesConsoleJointOwnerService.PartyStats stats =
            SalesConsoleJointOwnerService.partyStats(sos[0].Opportunity__c);
        dto.partyCount      = stats.partyCount;
        dto.verifiedCount   = stats.verifiedCount;
        dto.verifiableCount = stats.verifiableCount;

        for (SalesOrderInstallments__c i : [
            SELECT Id, MilestoneNumber__c, MilestoneDescription__c, MilestoneDate__c,
                   InstallmentAmount__c, PaymentStatus__c, Balance_Amount__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :salesOrderId
            ORDER BY MilestoneNumber__c ASC NULLS LAST
            LIMIT 200
        ]) {
            InstallmentDTO d = new InstallmentDTO();
            d.id = i.Id;
            d.milestoneNumber = i.MilestoneNumber__c;
            d.description = i.MilestoneDescription__c;
            d.dueDate = i.MilestoneDate__c;
            d.amount = i.InstallmentAmount__c;
            d.paymentStatus = i.PaymentStatus__c;
            dto.installments.add(d);

            if (d.amount != null) {
                dto.scheduledTotal += d.amount;
                if (d.paymentStatus == 'Paid') {
                    dto.paidTotal += d.amount;
                } else if (d.paymentStatus == 'Partially Paid' && i.Balance_Amount__c != null
                        && i.Balance_Amount__c < d.amount) {
                    /* 1.9 - MODON keeps what is still owed; the rest came in */
                    dto.paidTotal += d.amount - i.Balance_Amount__c;
                }
            }
        }

        /* the required-document checklist, alphabetical; the limit is a backstop */
        List<Documents__c> docs = [
            SELECT Id, Name, Status__c, LastModifiedDate
            FROM Documents__c
            WHERE SalesOrder__c = :salesOrderId
            ORDER BY Name ASC
            LIMIT 200
        ];
        /* the status can lag the file, so the file is read too (SalesConsoleComplianceService.filesPresent) */
        Set<Id> withFile = SalesConsoleComplianceService.filesPresent(docs);

        /* outstanding first */
        List<DocumentDTO> outstanding = new List<DocumentDTO>();
        List<DocumentDTO> arrived = new List<DocumentDTO>();
        for (Documents__c doc : docs) {
            DocumentDTO d = new DocumentDTO();
            d.id = doc.Id;
            d.name = doc.Name;
            String stored = String.isBlank(doc.Status__c) ? PENDING_UPLOAD : doc.Status__c;
            d.received = RECEIVED.contains(stored) || withFile.contains(doc.Id);
            /* a Pending Upload row with its file attached is reported as Uploaded */
            d.status = (d.received == true && stored == PENDING_UPLOAD) ? UPLOADED : stored;
            if (d.received == true) {
                d.receivedOn = doc.LastModifiedDate;
                arrived.add(d);
            } else {
                outstanding.add(d);
            }
        }
        dto.documents.addAll(outstanding);
        dto.documents.addAll(arrived);
        dto.documentsTotal = docs.size();
        dto.documentsReceived = arrived.size();

        return dto;
    }
}