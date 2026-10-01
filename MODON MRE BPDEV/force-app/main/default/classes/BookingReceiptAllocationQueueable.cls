/**********************************************************************************************
 * Name           : BookingReceiptAllocationQueueable
 * Description     : Allocates already-collected booking-fee receipts (ADM & Dari, Down Payment)
 *                   to the Sales Order's ADM invoice and first-installment invoice on booking
 *                   SO creation. Receipts are created by the payment process (linked via
 *                   Booking_Fee_Allocation__c); this only allocates them - it does not create
 *                   receipts or touch the Booking Fee Line paid tracking. without sharing /
 *                   SYSTEM_MODE so the finance objects are reachable regardless of the booking
 *                   user's permissions.
 * Usage           : Enqueued via enqueueForSalesOrders from the SalesOrder_Link_Booking_Receipts
 *                   flow on booking SO create (Modon - Egypt excluded).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    12 Jul 2026    Initial version.
 * 1.1        Prateek Bansal    03 Aug 2026    Added enqueueForSalesOrders invocable; enqueue now fired from a Sales Order flow.
 * 1.2        Prateek Bansal    11 Aug 2026    Derive Charge PaymentStatus from balance (Invoice 'Generated' broke the restricted picklist).
 * 1.3        Priyanka Bagpatia 27 Aug 2026    Bulk-query installment invoices once (MCR-48); Down Payment path no longer SOQL-in-loop.
 **********************************************************************************************/
public without sharing class BookingReceiptAllocationQueueable implements Queueable {

    private final Set<Id> soIds;

    public BookingReceiptAllocationQueueable(Set<Id> soIds) {
        this.soIds = soIds;
    }

    // v1.1 - Fired from the SalesOrder_Link_Booking_Receipts flow (async after-save) on booking SO create.
    // Enqueues the allocation only for booking SOs whose Opportunity has a paid booking-fee line;
    // Modon - Egypt is excluded here as well as in the flow's entry criteria.
    @InvocableMethod(label='Enqueue Booking Receipt Allocation' description='Links collected booking-fee receipts to the given booking Sales Orders.')
    public static void enqueueForSalesOrders(List<Id> soIds) {
        if (soIds == null || soIds.isEmpty()) return;

        Set<Id> qualifiedSoIds = new Set<Id>();
        for (SalesOrder__c so : [
            SELECT Id
            FROM SalesOrder__c
            WHERE Id IN :soIds
              AND Source_Entity__c != 'Modon - Egypt'
              AND Opportunity__c IN (
                  SELECT Opportunity__c FROM Booking_Fee_Line__c WHERE Total_Paid_Amount__c > 0
              )
        ]) {
            qualifiedSoIds.add(so.Id);
        }

        if (!qualifiedSoIds.isEmpty()) {
            System.enqueueJob(new BookingReceiptAllocationQueueable(qualifiedSoIds));
        }
    }

    public void execute(QueueableContext ctx) {
        if (soIds == null || soIds.isEmpty()) return;

        Map<Id, SalesOrder__c> soById = new Map<Id, SalesOrder__c>([
            SELECT Id, Unit__c, Opportunity__c, CustomerAccount__c
            FROM SalesOrder__c WHERE Id IN :soIds
        ]);
        if (soById.isEmpty()) return;

        Set<Id> oppIds  = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();
        Map<String, Id> soByKey = new Map<String, Id>(); // Opportunity|Unit -> SO Id
        for (SalesOrder__c so : soById.values()) {
            if (so.Opportunity__c != null) oppIds.add(so.Opportunity__c);
            if (so.Unit__c != null) unitIds.add(so.Unit__c);
            soByKey.put(so.Opportunity__c + '|' + so.Unit__c, so.Id);
        }
        if (oppIds.isEmpty() || unitIds.isEmpty()) return;

        // collected receipts for these opp+units, from the fee-line allocations (Applied only)
        List<Booking_Fee_Allocation__c> allocs = [
            SELECT Payment__c, Allocation_Amount__c,
                   Booking_Fee_Line__r.Opportunity__c, Booking_Fee_Line__r.Unit__c, Booking_Fee_Line__r.Type__c
            FROM Booking_Fee_Allocation__c
            WHERE Status__c = 'Applied'
              AND Payment__c != null
              AND Allocation_Amount__c > 0
              AND Booking_Fee_Line__r.Opportunity__c IN :oppIds
              AND Booking_Fee_Line__r.Unit__c IN :unitIds
        ];
        if (allocs.isEmpty()) return;

        // skip receipts already allocated (idempotent on re-run)
        Set<Id> receiptIds = new Set<Id>();
        for (Booking_Fee_Allocation__c a : allocs) receiptIds.add(a.Payment__c);
        Set<Id> alreadyAllocated = new Set<Id>();
        for (Allocation__c ex : [SELECT Receipt__c FROM Allocation__c WHERE Receipt__c IN :receiptIds]) {
            alreadyAllocated.add(ex.Receipt__c);
        }

        // ADM & Dari invoice per SO
        Map<Id, Invoice__c> admInvoiceBySo   = new Map<Id, Invoice__c>();
        Map<Id, Decimal>    admRemaining     = new Map<Id, Decimal>(); // invoiceId -> amount left to allocate
        Map<Id, Id>         admInvoiceCharge = new Map<Id, Id>();
        Map<Id, Decimal>    admInvoicePaid   = new Map<Id, Decimal>(); // invoiceId -> total newly allocated
        for (Invoice__c inv : [
            SELECT Id, Sales_Order__c, Charge__c, InvoiceAmount__c
            FROM Invoice__c
            WHERE Sales_Order__c IN :soIds AND Is_ADM_Fees_and_Dari_charges__c = true
        ]) {
            admInvoiceBySo.put(inv.Sales_Order__c, inv);
            admRemaining.put(inv.Id, inv.InvoiceAmount__c != null ? inv.InvoiceAmount__c : 0);
            if (inv.Charge__c != null) admInvoiceCharge.put(inv.Id, inv.Charge__c);
        }

        // One query for all SOs — same filters/order as ReceiptAllocationService.createLogicalReceiptAllocations
        Map<Id, List<Invoice__c>> installmentInvoicesBySo = new Map<Id, List<Invoice__c>>();
        for (Invoice__c inv : [
            SELECT Id, InvoiceBalance__c, TotalPaidAmount__c, InvoiceAmount__c, SalesOrderInstallment__c,
                   SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.SalesOrder__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c IN :soIds
              AND InvoiceBalance__c > 0
              AND isCancelled__c = false
            ORDER BY SalesOrderInstallment__r.SalesOrder__c, SalesOrderInstallment__r.MilestoneNumber__c ASC
        ]) {
            Id instSoId = inv.SalesOrderInstallment__r.SalesOrder__c;
            if (!installmentInvoicesBySo.containsKey(instSoId)) {
                installmentInvoicesBySo.put(instSoId, new List<Invoice__c>());
            }
            installmentInvoicesBySo.get(instSoId).add(inv);
        }

        Map<Id, Receipt__c> receiptUpdateById  = new Map<Id, Receipt__c>();
        List<Allocation__c> allocationsToInsert = new List<Allocation__c>();

        for (Booking_Fee_Allocation__c a : allocs) {
            Id receiptId = a.Payment__c;
            if (alreadyAllocated.contains(receiptId)) continue;

            Id soId = soByKey.get(a.Booking_Fee_Line__r.Opportunity__c + '|' + a.Booking_Fee_Line__r.Unit__c);
            if (soId == null) continue;

            Decimal collected = a.Allocation_Amount__c;
            String  feeType   = a.Booking_Fee_Line__r.Type__c;
            SalesOrder__c so  = soById.get(soId);

            // link the receipt to the SO
            Receipt__c r = receiptUpdateById.containsKey(receiptId)
                ? receiptUpdateById.get(receiptId)
                : new Receipt__c(Id = receiptId);
            r.SalesOrder__c = soId;
            if (so != null && so.CustomerAccount__c != null) r.Account__c = so.CustomerAccount__c;

            if (feeType != null && feeType.toLowerCase().startsWith('adm')) {
                // ADM & Dari -> ADM invoice
                Invoice__c admInv = admInvoiceBySo.get(soId);
                if (admInv != null) {
                    Decimal remaining = admRemaining.get(admInv.Id);
                    Decimal allocAmt  = collected < remaining ? collected : remaining;
                    if (allocAmt > 0) {
                        allocationsToInsert.add(new Allocation__c(
                            Invoice__c               = admInv.Id,
                            Receipt__c               = receiptId,
                            Status__c                = 'Applied',
                            AllocationDate__c        = Date.today(),
                            AllocationAmount__c      = allocAmt,
                            ApprovedReceiptAmount__c = collected
                        ));
                        admRemaining.put(admInv.Id, remaining - allocAmt);
                        admInvoicePaid.put(admInv.Id,
                            (admInvoicePaid.containsKey(admInv.Id) ? admInvoicePaid.get(admInv.Id) : 0) + allocAmt);
                    }
                }
                r.Is_ADM_Fees_and_Dari_charges__c = true;
                r.Transaction_Type__c = 'ADM_CHARGES';
            } else {
                // Down Payment -> first-installment invoice(s) (in-memory; invoices queried once above)
                List<Invoice__c> soInstallmentInvoices = installmentInvoicesBySo.containsKey(soId)
                    ? installmentInvoicesBySo.get(soId)
                    : new List<Invoice__c>();
                allocationsToInsert.addAll(
                    ReceiptAllocationService.createLogicalReceiptAllocations(receiptId, collected, soInstallmentInvoices)
                );
            }
            receiptUpdateById.put(receiptId, r);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!receiptUpdateById.isEmpty()) {
                Database.update(receiptUpdateById.values(), AccessLevel.SYSTEM_MODE);
            }
            if (!allocationsToInsert.isEmpty()) {
                Database.insert(allocationsToInsert, AccessLevel.SYSTEM_MODE);
            }

            // update ADM Charge after allocation (invoice status/balance recomputed by the allocation trigger)
            if (!admInvoicePaid.isEmpty()) {
                Map<Id, Invoice__c> invAfter = new Map<Id, Invoice__c>([
                    SELECT Id, InvoiceStatus__c, InvoiceBalance__c
                    FROM Invoice__c WHERE Id IN :admInvoicePaid.keySet()
                ]);
                List<Charge__c> chargesToUpdate = new List<Charge__c>();
                for (Id invId : admInvoicePaid.keySet()) {
                    Id chargeId = admInvoiceCharge.get(invId);
                    if (chargeId == null) continue;
                    Invoice__c inv = invAfter.get(invId);
                    // v1.2 - Charge__c.PaymentStatus__c is a RESTRICTED picklist (Not Paid / Partially Paid /
                    // Paid / Cancelled / Waived). The Invoice status (e.g. 'Generated' on a fresh booking) is
                    // not a valid value there and threw INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST, rolling back
                    // the whole allocation. Derive a valid status from the post-allocation balance instead.
                    Decimal paidNow = admInvoicePaid.get(invId);
                    Decimal bal = (inv != null) ? inv.InvoiceBalance__c : null;
                    String payStatus = (bal != null && bal <= 0)
                        ? 'Paid'
                        : ((paidNow != null && paidNow > 0) ? 'Partially Paid' : 'Not Paid');
                    chargesToUpdate.add(new Charge__c(
                        Id                  = chargeId,
                        PaymentStatus__c    = payStatus,
                        Paid_Amount__c      = paidNow,
                        Remaining_Amount__c = (inv != null && inv.InvoiceBalance__c != null) ? inv.InvoiceBalance__c : null
                    ));
                }
                if (!chargesToUpdate.isEmpty()) {
                    Database.update(chargesToUpdate, AccessLevel.SYSTEM_MODE);
                }
            }
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('BookingReceiptAllocationQueueable error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            // Do not swallow: surface the failure so the AsyncApexJob is marked Failed and its
            // ExtendedStatus captures the real cause (queryable, visible in Apex Jobs), instead of
            // leaving the receipts silently unlinked.
            throw new BookingReceiptAllocationException(
                'Booking-fee receipt allocation failed for SO(s) ' + soIds + ': '
                + e.getMessage() + ' | line ' + e.getLineNumber()
            );
        }
    }

    public class BookingReceiptAllocationException extends Exception {}
}