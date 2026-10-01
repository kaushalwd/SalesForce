/** Name              : BPCancellationSharedServices
 * description        : Standalone counterpart of CancellationSharedServices.InvoiceCancellationService
 *                      for the Business_Process__c cancellation migration.
 *
 *                      Business_Process__c cancellation strategies reuse the existing,
 *                      unmodified CancellationSharedServices.ReceiptCancellationService,
 *                      CancellationSharedServices.AllocationUnapplyService,
 *                      CancellationSharedServices.SalesOrderCancellationService and
 *                      CancellationSharedServices.EquityTransferReceiptService.createFromClearedReceipts/
 *                      .allocate directly — none of those depend on ServiceRequest__c.
 *
 *                      Only the invoice-cancellation pipeline is duplicated here, because
 *                      the source implementation hard-types its parameter as
 *                      ServiceRequest__c and stamps sr.Id directly onto Invoice__c.Service_Request__c /
 *                      Charge__c.Service_Request__c — lookups that only accept a real
 *                      ServiceRequest__c record. Business_Process__c records driving this
 *                      migration are not required to have a related ServiceRequest__c, so
 *                      this class stamps the new Invoice__c.Business_Process__c /
 *                      Charge__c.Business_Process__c lookups instead, and reads the
 *                      Unit_Consolidation__c split lines via the new
 *                      Unit_Consolidation__c.Business_Process__c lookup rather than
 *                      Unit_Consolidation__c.Service_Request__c.
 *
 *                      EquityTransferReceiptService.createFromUnitConsolidation(Id serviceRequestId, ...)
 *                      is intentionally NOT duplicated here — it is unused by the active
 *                      cancellation strategies today (the equivalent call is commented out
 *                      in ConsolidationCancellationStrategy), so there is nothing live to mirror.
 *Created By          : Active Minds
**********************************************************************************/
public without sharing class BPCancellationSharedServices {

    /**
     * Inner class: InvoiceCancellationService
     * Standalone counterpart of CancellationSharedServices.InvoiceCancellationService.
     */
    public class InvoiceCancellationService {

        /**
         * @description Full pipeline for cancellation:
         *   1. Marks every invoice isCancelled__c = true.
         *   2. Creates a forfeiture Debit_Memo if forfeitureAmount > 0.
         *   3. Unapplies (zeroes) all active Allocation__c records on paid invoices.
         *   4. Finds every unique Cleared Receipt linked via Allocation__c and
         *      distributes the forfeitureAmount sequentially.
         *   5. For standard cancellations: one Debit_Memo per cleared receipt
         *      for the remaining (post-forfeiture) refund amount.
         *      For Consolidation Cancellation: the post-forfeiture remainder is
         *      split across Unit_Consolidation__c records under the Business Process,
         *      one Debit_Memo per consolidation line stamped with its Fund_Transfer__c.
         *   6. Creates an Allocation__c (Status = 'Unapplied') linking each
         *      Debit_Memo to its source Cleared Receipt.
         *
         * param invoices          Full invoice list from BPCancellationContext.
         * param cancellationType  Drives Debit Memo Transaction_Type__c and
         *                          Consolidation split logic when value is
         *                          'Consolidation Cancellation'.
         * param forfeitureAmount  Amount retained by the company (from BP.Forfeiture_Amount__c).
         *                          Pass 0 or null when no forfeiture applies.
         * param bp                Parent Business_Process__c — also used to look up
         *                          Unit_Consolidation__c children for consolidation splits.
         */
        public Map<Id, String> cancel(
            List<Invoice__c>   invoices,
            String              cancellationType,
            Decimal             forfeitureAmount,
            Business_Process__c bp
        ) {
            if (invoices == null || invoices.isEmpty()) {
                return new Map<Id, String>();
            }

            Map<Id, String> invoicesIdMap = new Map<Id, String>();
            Id debitMemoRTId = Schema.SObjectType.Invoice__c
                .getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
            List<SalesOrderInstallments__c> toUpdateSOI = new List<SalesOrderInstallments__c>();
            List<Invoice__c>    toUpsert       = new List<Invoice__c>();
            Set<Id>             paidInvoiceIds = new Set<Id>();
            Map<Id, Invoice__c> paidInvoiceMap = new Map<Id, Invoice__c>();

            try {
                // ── Steps 1 + 2: Mark cancelled; queue forfeiture Debit Memo ────────
                for (Invoice__c inv : invoices) {
                    toUpsert.add(new Invoice__c(
                        Id                  = inv.Id,
                        Account__c          = inv.Account__c,
                        isCancelled__c      = true,
                        Business_Process__c = bp.Id
                    ));
                    if (inv.SalesOrderInstallment__c != null) {
                        toUpdateSOI.add(new SalesOrderInstallments__c(
                            Id               = inv.SalesOrderInstallment__c,
                            PaymentStatus__c = 'Cancelled'
                        ));
                    }
                    // Collect invoices that are already in Oracle — these need
                    // credit memo / debit memo treatment on the Oracle side
                    if (inv.OraclePartyId__c != null && bp.Cancellation_Type__c != 'Cancellation without Refund') {
                        paidInvoiceIds.add(inv.Id);
                        paidInvoiceMap.put(inv.Id, inv);
                    }
                }

                Id forfeitureInvoiceId = null;
                if (forfeitureAmount != null && forfeitureAmount > 0 && bp.Management_Fee__c > 0 && bp.Cancellation_Type__c != 'Cancellation without Refund') {
                    Invoice__c debitMemo = createChange(bp, forfeitureAmount, debitMemoRTId);
                    if (debitMemo != null) {
                        toUpsert.add(debitMemo);
                    }
                }

                TriggerControl.BypassCancelledTrigger = true;
                upsertWithErrorHandling(toUpsert, 'Invoice / Credit Memo upsert');
                if (!toUpdateSOI.isEmpty()) {
                    Database.update(toUpdateSOI, false);
                }
                // After upsert the forfeiture Debit Memo now has an Id — find it
                // by the presence of Charge__c (set inside createChange)
                Set<Id> chargeIds = new Set<Id>();
                for (Invoice__c inv : toUpsert) {
                    if (inv.Charge__c != null && inv.Id != null) {
                        forfeitureInvoiceId = inv.Id;
                        chargeIds.add(forfeitureInvoiceId);
                    }
                }

                // ── Steps 3–6: Unapply allocations + build Debit Memos ──────────────
                if (!paidInvoiceIds.isEmpty() && bp.Cancellation_Type__c != 'Cancellation without Refund') {
                    processAllocationsAndDebitMemos(
                        paidInvoiceIds,
                        paidInvoiceMap,
                        forfeitureAmount,
                        cancellationType,
                        bp,
                        forfeitureInvoiceId
                    );
                }

                // ── Step 7: Collect newly created child invoices for OIC sync ───────
                Set<Id> parentIds = new Map<Id, Invoice__c>(invoices).keySet();
                paidInvoiceIds.addAll(chargeIds);

                for (Invoice__c inv : [
                    SELECT Id, OraclePartyId__c, InvoiceStatus__c,
                           Transaction_Type__c, RecordTypeId, RecordType.Name,
                           Charge__c, Charge__r.Name
                    FROM Invoice__c
                    WHERE (Parent_Invoice__c IN :parentIds OR Id IN :paidInvoiceIds)
                ]) {
                    if (inv.InvoiceStatus__c == 'Cancelled' && inv.OraclePartyId__c != null) {
                        invoicesIdMap.put(inv.Id, 'Cancelled');
                    }
                }

                return invoicesIdMap;

            } catch (AuraHandledException ahe) {
                return new Map<Id, String>();
            } catch (Exception e) {
                return new Map<Id, String>();
            }
        }

        /**
         * @description Single query retrieves all Allocation__c records for the paid
         *              invoices. From that result set it:
         *                - Collects non-Unapplied allocations for a bulk update (Step 3).
         *                - Collects unique allocations whose Receipt is 'Cleared'
         *                  (deduplicated by Receipt Id) for Debit Memo creation (Steps 4–6).
         *
         *              For Consolidation Cancellation the Unit_Consolidation__c children
         *              of the Business Process are fetched here (via the new
         *              Unit_Consolidation__c.Business_Process__c lookup) and passed down
         *              to createDebitMemosAndAllocations so the refund split can be applied.
         */
        private void processAllocationsAndDebitMemos(
            Set<Id>             paidInvoiceIds,
            Map<Id, Invoice__c> paidInvoiceMap,
            Decimal             forfeitureAmount,
            String              cancellationType,
            Business_Process__c bp,
            Id                  forfeitureInvoiceId
        ) {
            List<Allocation__c> allAllocations = [
                SELECT Id, Status__c, Invoice__c, Invoice__r.OraclePartyId__c,
                       Receipt__c, Receipt__r.Is_ADM_Fees_and_Dari_charges__c,
                       Receipt__r.Status__c, Receipt__r.OraclePartyId__c,
                       Receipt__r.Receipt_Amount__c, Receipt__r.Receipt_Excess_Amount__c
                FROM Allocation__c
                WHERE Invoice__c IN :paidInvoiceIds
            ];

            if (allAllocations.isEmpty()) return;

            List<Allocation__c> toUnapply         = new List<Allocation__c>();
            List<Allocation__c> clearedAllocations = new List<Allocation__c>();
            Set<Id>             seenReceiptIds     = new Set<Id>();

            for (Allocation__c alloc : allAllocations) {
                // Step 3: gather active allocations for bulk unapply
                if (alloc.Status__c != 'Unapplied') {
                    toUnapply.add(new Allocation__c(
                        Id                         = alloc.Id,
                        Status__c                  = 'Unapplied',
                        AllocationAmount__c        = 0,
                        InProgressReceiptAmount__c = 0,
                        ApprovedReceiptAmount__c   = 0
                    ));
                }
                // Steps 4+5+6: one Debit_Memo per unique Cleared receipt
                if (alloc.Receipt__r.Status__c == 'Cleared'
                        && !seenReceiptIds.contains(alloc.Receipt__c)) {
                    seenReceiptIds.add(alloc.Receipt__c);
                    clearedAllocations.add(alloc);
                }
            }

            // Step 3: Bulk unapply all active allocations
            if (!toUnapply.isEmpty()) {
                try {
                    update toUnapply;
                } catch (DmlException e) {
                    throw new AuraHandledException(
                        'Allocation unapply failed: ' + e.getMessage());
                }
            }

            if (clearedAllocations.isEmpty()) return;

            // For Consolidation Cancellation, fetch the Unit_Consolidation__c split
            // records under this Business Process so the refund can be divided per
            // consolidation line. For all other cancellation types this list stays
            // empty and the standard single-receipt Debit Memo path is used.
            List<Unit_Consolidation__c> consolidationLines = new List<Unit_Consolidation__c>();
            if (cancellationType == 'Consolidation Cancellation') {
                consolidationLines = [
                    SELECT Id, Fund_Transfer__c, Transfer_Amount__c, Sales_Order__c, Unit__c
                    FROM Unit_Consolidation__c
                    WHERE Business_Process__c = :bp.Id
                      AND Transfer_Amount__c > 0 AND Fund_Transfer__c = true
                    ORDER BY CreatedDate ASC
                ];
            }

            // Steps 4+5+6: create Debit Memos and their Allocations
            createDebitMemosAndAllocations(
                clearedAllocations,
                paidInvoiceMap,
                forfeitureAmount,
                cancellationType,
                bp,
                forfeitureInvoiceId,
                consolidationLines
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // PRIVATE — Debit Memo + Allocation creation
        // ═══════════════════════════════════════════════════════════════════

        /**
         * @description Forfeiture distribution + Debit_Memo + Allocation creation.
         *              See CancellationSharedServices.InvoiceCancellationService for the
         *              full narrative — this mirrors that logic against Business_Process__c.
         */
        private void createDebitMemosAndAllocations(
            List<Allocation__c>         clearedAllocations,
            Map<Id, Invoice__c>         paidInvoiceMap,
            Decimal                     forfeitureAmount,
            String                      cancellationType,
            Business_Process__c         bp,
            Id                          forfeitureInvoiceId,
            List<Unit_Consolidation__c> consolidationLines
        ) {
            Id debitMemoRTId = Schema.SObjectType.Invoice__c
                .getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();

            // For consolidation: keep a mutable tracker of each line's remaining
            // transfer capacity so multiple receipts correctly share the same lines
            List<Decimal> consolidationRemaining = new List<Decimal>();
            if (cancellationType == 'Consolidation Cancellation') {
                for (Unit_Consolidation__c line : consolidationLines) {
                    consolidationRemaining.add(
                        line.Transfer_Amount__c != null ? line.Transfer_Amount__c : 0
                    );
                }
            }

            List<Invoice__c> debitMemos      = new List<Invoice__c>();
            List<Id>         receiptIdPerMemo = new List<Id>();

            // Track which receipt absorbs the forfeiture so we can link the
            // forfeiture Debit Memo (already inserted) to it via Allocation
            Id forfeitureReceiptId = null;

            for (Allocation__c alloc : clearedAllocations) {
                Decimal receiptAmt = alloc.Receipt__r.Receipt_Amount__c != null
                    ? alloc.Receipt__r.Receipt_Amount__c : 0;

                if (receiptAmt <= 0) continue;

                Boolean isADMCharge = alloc.Receipt__r.Is_ADM_Fees_and_Dari_charges__c == true;
                if (isADMCharge) {
                    // ADM / Dari receipts are always fully refunded regardless of
                    // cancellation type — forfeiture and consolidation splits do not apply
                    Invoice__c dm = buildDebitMemo(
                        paidInvoiceMap.get(alloc.Invoice__c),
                        receiptAmt,
                        debitMemoRTId,
                        cancellationType,
                        bp,
                        alloc.Receipt__r.OraclePartyId__c,
                        null   // no Fund_Transfer__c for ADM receipts
                    );
                    if (dm != null) {
                        debitMemos.add(dm);
                        receiptIdPerMemo.add(alloc.Receipt__c);
                    }
                    continue;
                } else if (cancellationType != 'Consolidation Cancellation') {
                    // Standard path: one Debit Memo for the full post-forfeiture amount
                    Invoice__c dm = buildDebitMemo(
                        paidInvoiceMap.get(alloc.Invoice__c),
                        receiptAmt,
                        debitMemoRTId,
                        cancellationType,
                        bp,
                        alloc.Receipt__r.OraclePartyId__c,
                        null
                    );
                    if (dm != null) {
                        debitMemos.add(dm);
                        receiptIdPerMemo.add(alloc.Receipt__c);
                    }
                    continue;
                }

                // ── Split across consolidation lines ─────────────────────────────────
                if (cancellationType == 'Consolidation Cancellation'
                        && !consolidationLines.isEmpty()) {
                    Decimal sliceRemaining = 0;
                    for (Integer i = 0; i < consolidationLines.size(); i++) {
                        if (sliceRemaining <= 0) break;
                        Decimal lineCapacity = consolidationRemaining[i];
                        if (lineCapacity <= 0) continue;
                        Decimal sliceAmt = consolidationLines[i].Transfer_Amount__c;
                        Decimal debitMemoAmount = 0;
                        if (sliceAmt < receiptAmt) {
                            sliceRemaining = receiptAmt - sliceAmt;
                            debitMemoAmount = receiptAmt - sliceAmt;
                            continue;
                        } else if (sliceAmt > receiptAmt) {
                            sliceRemaining = receiptAmt - sliceAmt;
                            debitMemoAmount = receiptAmt - sliceAmt;
                            continue;
                        } else {
                            debitMemoAmount = receiptAmt;
                        }
                        Invoice__c dm = buildDebitMemo(
                            paidInvoiceMap.get(alloc.Invoice__c),
                            debitMemoAmount,
                            debitMemoRTId,
                            cancellationType,
                            bp,
                            alloc.Receipt__r.OraclePartyId__c,
                            consolidationLines[i].Sales_Order__c
                        );
                        if (dm != null) {
                            debitMemos.add(dm);
                            receiptIdPerMemo.add(alloc.Receipt__c);
                        }
                        consolidationRemaining[i] -= debitMemoAmount;
                        sliceRemaining            -= debitMemoAmount;
                    }

                    // Safety net: if consolidation lines didn't fully cover the receipt
                    if (sliceRemaining > 0) {
                        Invoice__c dm = buildDebitMemo(
                            paidInvoiceMap.get(alloc.Invoice__c),
                            sliceRemaining,
                            debitMemoRTId,
                            cancellationType,
                            bp,
                            alloc.Receipt__r.OraclePartyId__c,
                            null
                        );
                        if (dm != null) {
                            debitMemos.add(dm);
                            receiptIdPerMemo.add(alloc.Receipt__c);
                        }
                    }
                }
            }

            // ── Insert Debit Memos ────────────────────────────────────────────────────
            List<Allocation__c> newAllocs  = new List<Allocation__c>();
            List<String>        insertErrs = new List<String>();
            if (!debitMemos.isEmpty()) {
                Database.SaveResult[] debitResults = Database.insert(debitMemos, false);

                for (Integer i = 0; i < debitResults.size(); i++) {
                    if (debitResults[i].isSuccess()) {
                        debitMemos[i].Id = debitResults[i].getId();
                        newAllocs.add(new Allocation__c(
                            Invoice__c                 = debitMemos[i].Id,
                            Receipt__c                 = receiptIdPerMemo[i],
                            Status__c                  = 'Applied',
                            AllocationAmount__c        = debitMemos[i].InvoiceAmount__c,
                            InProgressReceiptAmount__c = debitMemos[i].InvoiceAmount__c,
                            ApprovedReceiptAmount__c   = 0
                        ));
                    } else {
                        List<String> errs = new List<String>();
                        for (Database.Error e : debitResults[i].getErrors()) {
                            errs.add(e.getStatusCode() + ': ' + e.getMessage());
                        }
                        insertErrs.add(
                            'Debit Memo for Receipt ' + receiptIdPerMemo[i] +
                            ' — ' + String.join(errs, '; '));
                    }
                }

                if (!insertErrs.isEmpty()) {
                    throw new AuraHandledException(
                        'Debit Memo creation failed:\n' + String.join(insertErrs, '\n'));
                }
            }

            // Link the forfeiture (Management Fee) Debit Memo to the receipt
            // that absorbed it — only when a receipt was identified and the
            // forfeiture invoice was successfully inserted earlier in cancel()
            if (forfeitureInvoiceId != null && forfeitureReceiptId != null) {
                newAllocs.add(new Allocation__c(
                    Invoice__c                 = forfeitureInvoiceId,
                    Receipt__c                 = forfeitureReceiptId,
                    Status__c                  = 'Applied',
                    AllocationAmount__c        = forfeitureAmount,
                    InProgressReceiptAmount__c = forfeitureAmount,
                    ApprovedReceiptAmount__c   = 0
                ));
            }

            // ── Insert all Allocations ────────────────────────────────────────────────
            if (newAllocs.isEmpty()) return;

            Database.SaveResult[] allocResults = Database.insert(newAllocs, false);
            List<String> allocErrs = new List<String>();

            for (Integer i = 0; i < allocResults.size(); i++) {
                if (!allocResults[i].isSuccess()) {
                    List<String> errs = new List<String>();
                    for (Database.Error e : allocResults[i].getErrors()) {
                        errs.add(e.getStatusCode() + ': ' + e.getMessage());
                    }
                    allocErrs.add(
                        'Allocation for Invoice ' + newAllocs[i].Invoice__c +
                        ' — ' + String.join(errs, '; '));
                }
            }

            if (!allocErrs.isEmpty()) {
                throw new AuraHandledException(
                    'Allocation creation failed:\n' + String.join(allocErrs, '\n'));
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // PRIVATE — Debit Memo factory
        // ═══════════════════════════════════════════════════════════════════

        /**
         * @description Clones the source invoice into a Debit_Memo shell and
         *              overrides only the fields that differ per memo.
         *              Returns null if srcInv is null so callers can safely skip.
         */
        private Invoice__c buildDebitMemo(
            Invoice__c          srcInv,
            Decimal             amount,
            Id                  debitMemoRTId,
            String              cancellationType,
            Business_Process__c bp,
            String              receiptOracleId,
            Id                  fundTransferId
        ) {
            if (srcInv == null) return null;

            Invoice__c dm               = srcInv.clone(false, true, false, false);
            dm.Parent_Invoice__c        = srcInv.Id;
            dm.RecordTypeId             = debitMemoRTId;
            dm.InvoiceAmount__c         = amount;
            dm.OraclePartyId__c         = null;
            dm.OICIntegrationStatus__c  = null;
            dm.OICIntegrationMessage__c = null;
            dm.Transaction_Type__c      = (cancellationType == 'Cancellation with Refund')
                                             ? 'Customer Refund' : 'Refund';
            dm.Status__c                = 'Draft';
            dm.Business_Process__c      = bp.Id;
            dm.RefundOracleid__c        = receiptOracleId;
            dm.SalesOrderInstallment__c = srcInv.SalesOrderInstallment__c;

            // Stamp Fund_Transfer__c only for consolidation Debit Memos —
            // this tells Oracle which new unit/account to transfer the funds to
            dm.Transfer_Sales_Order__c = fundTransferId;
            return dm;
        }

        /**
         * @description Wraps Database.upsert in consistent per-record error handling.
         *              Collects all failure messages and throws a single
         *              AuraHandledException so the caller receives the complete error list.
         */
        private void upsertWithErrorHandling(List<Invoice__c> records, String context) {
            try {
                Database.UpsertResult[] results = Database.upsert(records, false);
                List<String> errors = new List<String>();
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        List<String> errs = new List<String>();
                        for (Database.Error e : results[i].getErrors()) {
                            errs.add(e.getStatusCode() + ': ' + e.getMessage());
                        }
                        errors.add('[index ' + i + '] ' + String.join(errs, '; '));
                    }
                }
                if (!errors.isEmpty()) {
                    throw new AuraHandledException(
                        context + ' failed:\n' + String.join(errors, '\n'));
                }
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, context + ' DML error: ' + e.getMessage());
                throw new AuraHandledException(context + ' failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Creates the Management Fee Charge__c + its Debit_Memo Invoice__c
     *              shell for the forfeiture amount. Standalone counterpart of
     *              CancellationSharedServices.createChange, stamping the new
     *              Charge__c.Business_Process__c / Invoice__c.Business_Process__c
     *              lookups instead of Service_Request__c.
     */
    public static Invoice__c createChange(Business_Process__c bp, Decimal forfeitureAmount, Id debitMemoRTId) {

        Id recordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName().get('Management_Fee').getRecordTypeId();
        List<Charge__c> chargesToInsert = new List<Charge__c>();

        Charge__c ch = new Charge__c(
            Name                = 'Management Fee',
            Amount__c            = forfeitureAmount,
            VAT_Amount__c        = 0,
            Type__c              = 'Cancellation Fee',
            PaymentStatus__c     = 'Not Paid',
            Sales_Order__c       = bp.Sales_Order__c,
            Account__c           = bp.Sales_Order__r.CustomerAccount__c,
            RecordTypeId         = recordTypeId,
            Business_Process__c  = bp.Id
        );
        chargesToInsert.add(ch);

        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        if (!chargesToInsert.isEmpty()) {
            insert chargesToInsert;

            for (Charge__c chRec : chargesToInsert) {
                Decimal vat = chRec.VAT_Amount__c != null ? chRec.VAT_Amount__c : 0;
                invoicesToInsert.add(new Invoice__c(
                    InvoiceAmount__c                = chRec.Amount__c + vat,
                    InvoiceDate__c                  = System.today(),
                    Sales_Order__c                  = chRec.Sales_Order__c,
                    Account__c                       = chRec.Account__c,
                    Charge__c                        = chRec.Id,
                    Business_Process__c              = bp.Id,
                    Is_ADM_Fees_and_Dari_charges__c = false,
                    RecordTypeId                     = debitMemoRTId
                ));
            }
        }

        if (invoicesToInsert.size() > 0) {
            return invoicesToInsert[0];
        }
        return null;
    }
}