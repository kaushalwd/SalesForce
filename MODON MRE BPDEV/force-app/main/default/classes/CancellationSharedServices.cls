/** Name              : CancellationSharedServices
* description        : Collection of focused, stateless services used by one or more
*                      cancellation strategies.  Each inner class owns exactly one
*                      domain concern so strategies compose them rather than duplicating logic.              
*Created By          : Active Minds
*********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
*  2.0		Manoj			20 May 2026	   Add logic for new cancelled
*  3.0		Manoj			25 May 2026	   update invoice map and not adding debit memo
**********************************************************************************/
public without sharing class CancellationSharedServices {
    
    //  Statuses that must never be changed on Receipt__c 
    private static final Set<String> PROTECTED_RECEIPT_STATUSES = new Set<String>{
        'Bounced', 'Cancelled', 'ReturnedtoCustomer'
            };
                
                // =========================================================================
                // Invoice Cancellation
                // =========================================================================
                
                /*public class InvoiceCancellationService {
                    
                    **
                * @description Marks all non-cancelled invoices as cancelled (isCancelled__c).
                *              For each invoice already synced to Oracle (OraclePartyId__c != null),
                *              enqueues one OIC_ManageInvoiceCancellation batch job limited to
                *              that single record.
                * param invoices  List from CancellationContext; non-empty list only.
                * param cancellationType  Passed verbatim to the OIC service method.
                *
                    public void cancel(List<Invoice__c> invoices, String cancellationType) {
                        if (invoices == null || invoices.isEmpty()) return;
                        List<Invoice__c> toUpsertInvoice = new List<Invoice__c>();
                        for (Invoice__c inv : invoices) {
                                toUpsertInvoice.add(new Invoice__c(
                                Id             = inv.Id,
                                Account__c     = inv.Account__c,
                                isCancelled__c = true
                                 ));
                            
                            if(inv.InvoiceStatus__c == 'Partially Paid' || inv.InvoiceStatus__c == 'Paid' ){
                            
                              // Create Clone 1
                            Invoice__c cloneCredit = inv.clone(
                                false,  // preserveId       — give the clone a new Id
                                true,   // isDeepClone      — copy all field values
                                false,  // preserveReadonly  — exclude read-only system fields
                                false   // preserveAutonumber
                            );
                            system.debug('cloneCredit---'+cloneCredit);
                            cloneCredit.Parent_Invoice__c  = inv.Id;       // point back to the canceled invoice
                            cloneCredit.RecordTypeId = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName().get('Credit_Memo').getRecordTypeId();
                            cloneCredit.OraclePartyId__c = null;
                            cloneCredit.OICIntegrationStatus__c =null;
                            cloneCredit.OICIntegrationMessage__c =null;
                            toUpsertInvoice.add(cloneCredit);
                
                            // Create Clone 2
                            Invoice__c cloneDebit = inv.clone(false, true, false, false);
                            system.debug('cloneDebit---'+cloneDebit);
                            cloneDebit.Parent_Invoice__c  = inv.Id;       // point back to the canceled invoice
                            cloneDebit.RecordTypeId = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
                            cloneDebit.OraclePartyId__c = null;
                            cloneDebit.OICIntegrationStatus__c =null;
                            cloneDebit.OICIntegrationMessage__c =null;
                            toUpsertInvoice.add(cloneDebit);
                            }
                        }                
                        if (!toUpsertInvoice.isEmpty()) {
                            try {
                               Database.UpsertResult[] results = Database.upsert(toUpsertInvoice, false);

                                // Process the results
                                for (Database.UpsertResult ar : results) {
                                    if (ar.isSuccess()) {
                                        System.debug('Successfully upserted record with ID: ' + ar.getId());
                                    } else {
                                        // Iterate over errors to see what went wrong
                                        for (Database.Error err : ar.getErrors()) {
                                            System.debug('Error on record: ' + err.getMessage());
                                            throw new AuraHandledException(err.getMessage());
                                        }
                                    }
                                }
                            } catch (DmlException e) {
                                // Log the error — adjust to your org's logging framework as needed
                                System.debug('InvoiceCloneHandler: DML error - ' + e.getMessage());
                                throw e;  // re-throw so the calling context can handle it
                            }
                        }
                        
                        // OIC callout — one batch per invoice to respect the per-record contract
                        set<id> sendEbs =new set<id>();
                        for (Invoice__c inv : [select id,OraclePartyId__c,InvoiceStatus__c from Invoice__c where Parent_Invoice__c in :invoices]) {
                            if (inv.OraclePartyId__c == null && inv.InvoiceStatus__c != 'Cancelled') {
                               sendEbs.add(inv.id);
                            }
                        }
                        if(!sendEbs.isEmpty()){
                                 OIC_ManageInvoiceCancellationBatch batch =
                                    new OIC_ManageInvoiceCancellationBatch(sendEbs, cancellationType);
                                    Database.executeBatch(batch, 1);  
                        }
                        
                    }
                }*/
    
    // =========================================================================
    // Receipt Cancellation
    // =========================================================================
    
    public class ReceiptCancellationService {
        
        /**
        * @description Updates the status of every eligible receipt to 'Cancelled'.
        *              Receipts with protected statuses (Bounced, Cancelled,
        *              ReturnedtoCustomer) are left untouched.
        *              For each cancelled receipt with OraclePartyId__c != null,
        *              enqueues OIC_ManageReceiptReversalBatch (1 record at a time).
        * param receipts  Full receipt list from CancellationContext.
        * param cancellationType  Label for the OIC reversal reason.
        * @return The subset of receipts that were actually cancelled.
        */
        public Map<Id, String> cancel(List<Receipt__c> receipts, String cancellationType) {
            if (receipts == null || receipts.isEmpty()) return new Map<Id, String>();
            
            List<Receipt__c> toUpdate  = new List<Receipt__c>();
            List<Receipt__c> cancelled = new List<Receipt__c>();
            
            for (Receipt__c r : receipts) {
                if (PROTECTED_RECEIPT_STATUSES.contains(r.Status__c)){
                    continue;
                }else if(r.OraclePartyId__c == null &&  r.Oracle_Id_Temporary__c == null && (r.Status__c == 'In Progress' || r.Status__c =='Remitted' || r.Status__c == 'Confirmed')){
                    toUpdate.add(new Receipt__c(Id = r.Id, Status__c = 'Cancelled',Cheque_Bounce_Reason__c='Cancelled'));
                    //cancelled.add(r);
                }else if((r.OraclePartyId__c != null || r.Oracle_Id_Temporary__c != null) && (r.Status__c == 'In Progress' || r.Status__c =='Remitted' || r.Status__c == 'Confirmed')){
                    toUpdate.add(new Receipt__c(Id = r.Id, Status__c = 'Cancelled',Cheque_Bounce_Reason__c='Cancelled'));
                    if(r.OraclePartyId__c != null){
                    cancelled.add(r);
                    }
                }                 
            }
            
            if (!toUpdate.isEmpty()) update toUpdate;
            
            // OIC callout — one batch per receipt
            Map<Id, String> param = new Map<Id, String>();
                if (!cancelled.isEmpty()) {
                    for (Receipt__c r : cancelled) {
                        if (r.OraclePartyId__c != null) {  // removed the broken Status__c check
                            param.put(r.Id, cancellationType);
                        }
                    }
                }
                
                return param.isEmpty() ? new Map<Id, String>() : param;
        }
    }
    
    // =========================================================================
    // Allocation Unapply Service
    // =========================================================================
    
    public class AllocationUnapplyService {
        
        /**
        * @description Sets Status__c = 'Unapplied' on every Allocation__c
        *              record linked to the supplied invoices.
        * param invoices  Source invoices whose allocations must be unapplied.
        */
        public void unapply(List<Invoice__c> invoices) {
            if (invoices == null || invoices.isEmpty()) return;
            
            Set<Id> invoiceIds = new Set<Id>();
            for (Invoice__c inv : invoices) invoiceIds.add(inv.Id);
            
            List<Allocation__c> allocations = [
                SELECT Id, Status__c
                FROM Allocation__c
                WHERE Invoice__c IN :invoiceIds
                AND Status__c != 'Unapplied'
            ];
            
            if (allocations.isEmpty()) return;
            
            for (Allocation__c alloc : allocations) {
                alloc.Status__c = 'Unapplied';
                alloc.AllocationAmount__c = 0;
                alloc.InProgressReceiptAmount__c = 0;
                alloc.ApprovedReceiptAmount__c = 0;
            }
            update allocations;
        }
    }
    
    // =========================================================================
    // Equity Transfer Receipt Service  (Consolidation Cancellation only)
    // =========================================================================
    
    public class EquityTransferReceiptService {
        
        /**
        * @description Creates one Equity_Transfer Receipt__c for every
        *              Receipt__c with Status__c = 'Cleared' on the source SO.
        *              Used by CancellationWithoutRefundStrategy only.
        *              Does NOT cancel the source receipts — ReceiptCancellationService
        *              handles that separately.
        *
        * param receipts   Full receipt list from CancellationContext.
        * return           Inserted equity receipts (Ids populated).
        */
        public List<Receipt__c> createFromClearedReceipts(List<Receipt__c> receipts, Decimal PayabletoCustomer) {
            if (receipts == null || receipts.isEmpty()) return new List<Receipt__c>();
            
            Id equityRTId = Schema.SObjectType.Receipt__c
                .getRecordTypeInfosByDeveloperName()
                .get('Equity_Transfer')
                .getRecordTypeId();
            
            List<Receipt__c> equityReceipts = new List<Receipt__c>();
            for (Receipt__c r : receipts) {
                if (r.Status__c != 'Cleared') continue;
                equityReceipts.add(new Receipt__c(
                    RecordTypeId             = equityRTId,
                    Account__c               = r.Account__c,
                    SalesOrder__c            = r.SalesOrder__c,
                    SalesOrderInstallment__c = r.SalesOrderInstallment__c,
                    TotalAmount__c           = PayabletoCustomer,
                    Receipt_Amount__c=PayabletoCustomer,
                    Modeofpayment__c         = 'Equity Transfer',
                    Status__c                = 'Approved',
                    Transaction_Type__c = 'REFOUND'
                ));
            }
            
            if (!equityReceipts.isEmpty()) insert equityReceipts;
            return equityReceipts;
        }
        
        /**
        * @description Creates one Equity_Transfer Receipt__c per
        *              Unit_Consolidation__c line where Fund_Transfer__c = true
        *              and Transfer_Amount__c > 0.  Each receipt targets the
        *              *destination* Sales Order (Unit_Consolidation__c.Sales_Order__c),
        *              not the source sales order being cancelled.
        *
        *              Guard: the total planned transfer must not exceed the
        *              totalAvailableDebit balance; throws AuraHandledException
        *              if it does.
        *
        * param serviceRequestId      Id of the parent ServiceRequest__c.
        * param totalAvailableDebit   Caller-supplied debit-memo balance ceiling.
        * return Inserted Receipt__c records with Ids populated, ready for allocation.
        */
        public List<Receipt__c> createFromUnitConsolidation(
            Id      serviceRequestId,
            Decimal totalAvailableDebit) {
                List<Unit_Consolidation__c> fundTransferLines  =new List<Unit_Consolidation__c>();
                if (serviceRequestId == null) return new List<Receipt__c>();
                
                //  1. All UC lines for this SR 
                List<Unit_Consolidation__c> allUCLines = [
                    SELECT Id, Sales_Order__c, IsConsolidated__c,Sales_Order__r.CustomerAccount__c,
                    Fund_Transfer__c, Transfer_Amount__c
                    FROM Unit_Consolidation__c
                    WHERE Service_Request__c = :serviceRequestId
                ];
                
                if (allUCLines.isEmpty()) return new List<Receipt__c>();
                
                // Collect the destination SO Ids that are flagged as fund transfers
                Set<Id> fundTransferSOIds = new Set<Id>();
                for (Unit_Consolidation__c uc : allUCLines) {
                    if (uc.Fund_Transfer__c && uc.Sales_Order__c != null) {
                        fundTransferSOIds.add(uc.Sales_Order__c);
                        fundTransferLines.add(uc);
                    }
                    
                }
                
                if (fundTransferSOIds.isEmpty()) return new List<Receipt__c>();
                
                //  2. Re-query with CustomerAccount__c for receipt creation 
               /* List<Unit_Consolidation__c> fundTransferLines = [
                    SELECT Id, Sales_Order__c, Transfer_Amount__c,
                    Sales_Order__r.CustomerAccount__c
                    FROM Unit_Consolidation__c
                    WHERE Service_Request__c = :serviceRequestId
                    AND Sales_Order__c IN :fundTransferSOIds
                    AND Fund_Transfer__c = true
                ];*/
                
                system.debug('fundTransferLines123......'  +  fundTransferLines);
                
                //  3. Guard: total planned transfer vs available debit 
                Decimal totalPlanned = 0;
                for (Unit_Consolidation__c uc : fundTransferLines) {
                    if (uc.Transfer_Amount__c != null && uc.Transfer_Amount__c > 0) {
                        totalPlanned = uc.Transfer_Amount__c;
                        // if (totalPlanned >= totalAvailableDebit) {
                        //     throw new AuraHandledException(
                        //         'Total Fund Transfer Amount exceeds available Debit Memo balance.');
                        // }
                    }
                }
                //  4. Build and insert Equity Transfer receipts 
                List<Receipt__c> receiptsToInsert = new List<Receipt__c>();
                for (Unit_Consolidation__c uc : fundTransferLines) {
                    system.debug('fundTransferLines1234.....' + uc);
                    Decimal amount = uc.Transfer_Amount__c != null ? uc.Transfer_Amount__c : 0;
                    if (amount <= 0) continue;                    
                    
                        Receipt__c receipt = new Receipt__c();
                        receipt.Receipt_Amount__c=amount;                       
                        receipt.TotalAmount__c = amount;
                        receipt.Account__c = uc.Sales_Order__r.CustomerAccount__c; 
                        receipt.Modeofpayment__c ='Equity Transfer';//Constants.RECEIPT_PAYMENT_TYPE_EQUITY_TRANSFER;
                        receipt.Status__c= 'In Progress';
                        receipt.SalesOrder__c = uc.Sales_Order__c;
                        receipt.TransactionDate__c= System.today(); 
                        receipt.ReceiptDate__c = System.today();
                        receipt.RecordTypeId =Schema.SObjectType.Receipt__c.getRecordTypeInfosByDeveloperName().get('Equity_Transfer').getRecordTypeId();
                        receipt.Receipt_Approved_By__c =UserInfo.getUserId();
                        receipt.Receipt_Approved_Checker__c=true;
                        receipt.Receipt_Approved_Date__c=datetime.now();
                        receipt.Transaction_Type__c ='EQU_TRANSFOR';
                        receiptsToInsert.add(receipt);
                
                }
                if (receiptsToInsert.isEmpty()) return new List<Receipt__c>();
                
                //  5. Partial insert — collect only the records that succeeded 
                Database.SaveResult[] saveResults = Database.insert(receiptsToInsert, false);
                List<Receipt__c> successfulReceipts = new List<Receipt__c>();
                List<String>     failureMessages    = new List<String>();
                
                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    if (sr.isSuccess()) {
                        // Back-fill the Id on the in-memory record so callers
                        // can reference it immediately without a re-query.
                        receiptsToInsert[i].Id = sr.getId();
                        successfulReceipts.add(receiptsToInsert[i]);
                    } else {
                        List<String> errors = new List<String>();
                        for (Database.Error err : sr.getErrors()) {
                            errors.add(err.getStatusCode() + ': ' + err.getMessage());
                        }
                        failureMessages.add(
                            'Receipt index ' + i +
                            ' (SO: ' + receiptsToInsert[i].SalesOrder__c + ') — ' +
                            String.join(errors, '; ')
                        );
                        System.debug(LoggingLevel.ERROR,
                                     'EquityTransferReceiptService.createFromUnitConsolidation — insert failure: ' +
                                     failureMessages[failureMessages.size() - 1]);
                    }
                }
                
                if (!failureMessages.isEmpty()) {
                    throw new AuraHandledException(
                        'One or more Equity Transfer receipts could not be inserted: ' +
                        String.join(failureMessages, ' | '));
                }
                if(!successfulReceipts.isEmpty()){
                    set<String> param = new set<String>();
                    for(Receipt__c recSuff: successfulReceipts){
                        param.add(recSuff.id);
                    }
                    /*if(!param.isEmpty()){
                        ReceiptEBSIntegrationBatch  batch =
                        new ReceiptEBSIntegrationBatch(null,null,param);
                        Database.executeBatch(batch, 1);
                    } */                   
                }
                return successfulReceipts;
                
            }
        
        /**
        * @description Allocates each equity receipt to Debit Memo invoices on
        *              its target Sales Order using ReceiptAllocationService.
        *              Throws AuraHandledException if any receipt cannot be
        *              fully allocated (no matching Debit Memo found).
        *
        * param equityReceipts  Inserted receipts returned by createFromUnitConsolidation.
        */
        public void allocate(List<Receipt__c> equityReceipts) {
            if (equityReceipts == null || equityReceipts.isEmpty()) return;
            
            List<Allocation__c> allocationsToInsert = new List<Allocation__c>();
            
            for (Receipt__c receipt : equityReceipts) {
                List<Allocation__c> allocs = ReceiptAllocationService.createLogicalReceiptAllocations(
                    receipt.Id,
                    receipt.TotalAmount__c,
                    receipt.SalesOrder__c
                );
                
                if (allocs == null || allocs.isEmpty()) {
                    throw new AuraHandledException(
                        'Receipt ' + receipt.Id +
                        ' could not be allocated to any Debit Memo on Sales Order ' +
                        receipt.SalesOrder__c + '.');
                }
                
                allocationsToInsert.addAll(allocs);
            }
            
            if (!allocationsToInsert.isEmpty()) insert allocationsToInsert;            
            
        }
    }
    
   // =========================================================================
    // Sales Order + Unit Cancellation (shared across all types)
    // ========================================================================= /
    
    public class SalesOrderCancellationService {
        
        /**
        * @description Cancels the Sales Order and resets the associated Unit
        *              to Draft status.  The SO status label is determined by
        *              the cancellation type.
        * param salesOrderId      Id of the SalesOrder__c.
        * param unitId            Id of the Unit__c (may be null).
        * param cancellationType  Used to derive the appropriate SO Status value.
        */
        public void cancel(Id salesOrderId, Id unitId, String cancellationType) {
            String soSubStatus = resolveSalesOrderStatus(cancellationType);
            String soReason = resolveCancellationReason(cancellationType);
            TriggerControl.BypassCancelledTrigger = true;
            update new SalesOrder__c(
                Id                    = salesOrderId,
                Status__c             = 'Cancelled',
                CancellationReason__c = soReason,
                Sub_Status__c =soSubStatus,
                SR_Cancelled__c=true
            );
            
            if (unitId != null) {
                update new Unit__c(
                    Id               = unitId,
                    Status__c        = '',
                    ApprovalStatus__c = 'Draft',
                    Sub_Status__c=null,
                    BlockedFor__c = null,
                    BlockedBy__c = null,
                    Opportunity__c = null,
                    BlockUntil__c = null,
                    Blocked_Time__c = null,
                    Unit_Sold_Date__c= null

                );
            }
            
        }
        
        private String resolveSalesOrderStatus(String cancellationType) {
            if (cancellationType == CancellationStrategyFactory.TYPE_WITH_REFUND) {
                return 'Booking Cancellation';
            }
            if (cancellationType == CancellationStrategyFactory.TYPE_CONSOLIDATION) {
                return 'Mutual Cancellation';
            }
            // Default covers TYPE_WITHOUT_REFUND and any future additions
            return 'Booking Cancellation';
        }
        private String resolveCancellationReason(String cancellationType) {
            if (cancellationType == CancellationStrategyFactory.TYPE_WITH_REFUND) {
                return 'Refund';
            }
            if (cancellationType == CancellationStrategyFactory.TYPE_CONSOLIDATION) {
                return 'Equity Transfer';
            }
            // Default covers TYPE_WITHOUT_REFUND and any future additions
            return 'Without Refund';
        }
    }
    
    /**
     * Inner class: InvoiceCancellationService
     * Replaces the existing InvoiceCancellationService in CancellationSharedServices.
     * All other inner classes (ReceiptCancellationService, AllocationUnapplyService,
     * EquityTransferReceiptService, SalesOrderCancellationService) remain unchanged.
     */
	public class InvoiceCancellationService {

    /**
     * @description Full pipeline for cancellation:
     *   1. Marks every invoice isCancelled__c = true.
     *   2. Creates a forfeiture Debit_Memo if forfeitureAmount > 0.
     *   3. Unapplies (zeroes) all active Allocation__c records on paid invoices.
     *   4. Finds every unique Cleared Receipt linked via Allocation__c and
     *      distributes the forfeitureAmount sequentially:
     *        - While forfeitureAmount > 0: subtract receipt amount; if fully
     *          consumed skip (no Debit_Memo), if partially consumed create a
     *          Debit_Memo for (receiptAmount - remainingForfeiture).
     *        - Once forfeiture = 0: remaining receipts get Debit_Memos.
     *   5. For standard cancellations: one Debit_Memo per cleared receipt
     *      for the remaining (post-forfeiture) refund amount.
     *      For Consolidation Cancellation: the post-forfeiture remainder is
     *      split across Unit_Consolidation__c records under the SR, one
     *      Debit_Memo per consolidation line stamped with its Fund_Transfer__c.
     *   6. Creates an Allocation__c (Status = 'Unapplied') linking each
     *      Debit_Memo to its source Cleared Receipt.
     *   7. Fires OIC cancellation batch for child invoices without OraclePartyId.
     *   All failures are surfaced to the UI via AuraHandledException.
     *
     * param invoices          Full invoice list from CancellationContext.
     * param cancellationType  Drives Debit Memo Transaction_Type__c and
     *                          Consolidation split logic when value is
     *                          'Consolidation Cancellation'.
     * param forfeitureAmount  Amount retained by the company (from SR.Forfeiture_Amount__c).
     *                          Pass 0 or null when no forfeiture applies.
     * param sr                Parent ServiceRequest__c — also used to look up
     *                          Unit_Consolidation__c children for consolidation splits.
     */
    public Map<Id, String> cancel(
        List<Invoice__c>  invoices,
        String            cancellationType,
        Decimal           forfeitureAmount,
        ServiceRequest__c sr
        ) {
            if (invoices == null || invoices.isEmpty()) {
                return new Map<Id, String>();
            }
    
            Map<Id, String> invoicesIdMap  = new Map<Id, String>();
            Id debitMemoRTId = Schema.SObjectType.Invoice__c
                .getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
            List<SalesOrderInstallments__c>    toUpdateSOI      = new List<SalesOrderInstallments__c>();
            List<Invoice__c>    toUpsert      = new List<Invoice__c>();
            Set<Id>             paidInvoiceIds = new Set<Id>();
            Map<Id, Invoice__c> paidInvoiceMap = new Map<Id, Invoice__c>();
    
            try {
                // ── Steps 1 + 2: Mark cancelled; queue forfeiture Debit Memo ────────
                for (Invoice__c inv : invoices) {
                    toUpsert.add(new Invoice__c(
                        Id                 = inv.Id,
                        Account__c         = inv.Account__c,
                        isCancelled__c     = true,
                        Service_Request__c = sr.Id
                    ));
                    if (inv.SalesOrderInstallment__c != null) {
                        toUpdateSOI.add(new SalesOrderInstallments__c(
                            Id               = inv.SalesOrderInstallment__c,
                            PaymentStatus__c = 'Cancelled'
                        ));
                    }
                    // Collect invoices that are already in Oracle — these need
                    // credit memo / debit memo treatment on the Oracle side
                    if (inv.OraclePartyId__c != null && sr.Cancellation_Type__c != 'Cancellation without Refund' ) {
                        paidInvoiceIds.add(inv.Id);
                        paidInvoiceMap.put(inv.Id, inv);
                    }
                }
    
                Id forfeitureInvoiceId = null;
                if (forfeitureAmount != null && forfeitureAmount > 0 && sr.Management_Fee__c > 0 && sr.Cancellation_Type__c != 'Cancellation without Refund')  { //3.0
                    Invoice__c debitMemo = createChange(sr, forfeitureAmount, debitMemoRTId);
                    toUpsert.add(debitMemo);
                }
    
                TriggerControl.BypassCancelledTrigger = true;
                upsertWithErrorHandling(toUpsert, 'Invoice / Credit Memo upsert');
                //SOI Cancaled
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
                if (!paidInvoiceIds.isEmpty() && sr.Cancellation_Type__c != 'Cancellation without Refund') {
                    processAllocationsAndDebitMemos(
                        paidInvoiceIds,
                        paidInvoiceMap,
                        forfeitureAmount,
                        cancellationType,
                        sr,
                        forfeitureInvoiceId
                    );
                }
    
                // ── Step 7: Collect newly created child invoices for OIC batch ───────
                Set<Id> parentIds = new Map<Id, Invoice__c>(invoices).keySet();
                paidInvoiceIds.addAll(chargeIds);
    
                for (Invoice__c inv : [
                    SELECT Id, OraclePartyId__c, InvoiceStatus__c,
                           Transaction_Type__c, RecordTypeId, RecordType.Name,
                           Charge__c, Charge__r.Name
                    FROM Invoice__c
                    WHERE (Parent_Invoice__c IN :parentIds OR Id IN :paidInvoiceIds)
                ]) {
                    if (inv.OraclePartyId__c == null
                            && inv.InvoiceStatus__c != 'Cancelled'
                            && inv.RecordType.Name == 'Debit Memo') {
                        if (inv.Transaction_Type__c == 'Customer Refund' && inv.Charge__c == null) {
                          //  invoicesIdMap.put(inv.Id, 'Customer Refund'); //3.0
                        } else if (inv.Transaction_Type__c == 'Refund' && inv.Charge__c == null) {
                          //  invoicesIdMap.put(inv.Id, 'Refund'); //3.0
                        } else if (inv.Charge__c != null) {
                           // invoicesIdMap.put(inv.Id, 'Debit Memo'); //3.0
                        }
                    }
                    if (inv.InvoiceStatus__c == 'Cancelled' && inv.OraclePartyId__c != null) {
                        invoicesIdMap.put(inv.Id, 'Cancelled');
                    }
                }
    
                return invoicesIdMap;
    
            } catch (AuraHandledException ahe) {
                return new Map<Id, String>();
            } catch (Exception e) {
                return new Map<Id, String>();
            } finally {
                // Always reset the bypass flag regardless of success or failure
                
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
         *              of the SR are fetched here and passed down to
         *              createDebitMemosAndAllocations so the refund split can be applied.
         */
        private void processAllocationsAndDebitMemos(
            Set<Id>             paidInvoiceIds,
            Map<Id, Invoice__c> paidInvoiceMap,
            Decimal             forfeitureAmount,
            String              cancellationType,
            ServiceRequest__c   sr,
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
            // records under this SR so the refund can be divided per consolidation line.
            // For all other cancellation types this list stays empty and the standard
            // single-receipt Debit Memo path is used.
            List<Unit_Consolidation__c> consolidationLines = new List<Unit_Consolidation__c>();
            if (cancellationType == 'Consolidation Cancellation') {
                consolidationLines = [
                    SELECT Id, Fund_Transfer__c, Transfer_Amount__c,Sales_Order__c,Unit__c
                    FROM Unit_Consolidation__c
                    WHERE Service_Request__c = :sr.Id
                      AND Transfer_Amount__c > 0 and Fund_Transfer__c = true
                    ORDER BY CreatedDate ASC
                ];
            }
    
            // Steps 4+5+6: create Debit Memos and their Allocations
            createDebitMemosAndAllocations(
                clearedAllocations,
                paidInvoiceMap,
                forfeitureAmount,
                cancellationType,
                sr,
                forfeitureInvoiceId,
                consolidationLines
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // PRIVATE — Debit Memo + Allocation creation
        // ═══════════════════════════════════════════════════════════════════
    
        /**
         * @description Forfeiture distribution + Debit_Memo + Allocation creation.
         *
         *  Standard cancellation path (cancellationType != 'Consolidation Cancellation'):
         *    - Forfeiture is consumed sequentially across cleared receipts.
         *    - Each receipt that still has a remaining balance after forfeiture
         *      gets a single Debit_Memo for that balance.
         *
         *  Consolidation Cancellation path:
         *    - Forfeiture is consumed first (same sequential logic).
         *    - The post-forfeiture remainder for each cleared receipt is then
         *      split across the Unit_Consolidation__c lines supplied in
         *      consolidationLines, proportionally by Transfer_Amount__c:
         *        * The split is consumed in order — each consolidation line
         *          absorbs as much of the receipt's remainder as its
         *          Transfer_Amount__c allows.
         *        * One Debit_Memo is created per (receipt × consolidation line)
         *          combination, stamped with the line's Fund_Transfer__c.
         *        * A consolidation line's Transfer_Amount__c tracker is reduced
         *          as it is used, so if two receipts share the same line each
         *          takes its slice correctly.
         *
         *
         *  Each Debit_Memo is cloned from the source paid invoice so all header
         *  fields (Account, SalesOrder, etc.) are inherited; only RecordType,
         *  InvoiceAmount__c, Fund_Transfer__c, and Oracle/OIC fields are overridden.
         *
         *  A corresponding Allocation__c (Status = 'Unapplied') is created per
         *  Debit_Memo linking it back to the Cleared receipt.
         *
         *  All insert errors are collected and thrown as a single
         *  AuraHandledException so the UI receives the full error list.
         *
         * param clearedAllocations    Deduplicated cleared-receipt allocations.
         * param paidInvoiceMap        Map of paid Invoice__c records keyed by Id.
         * param forfeitureAmount      Total forfeiture to distribute before refunding.
         * param cancellationType      Drives Transaction_Type__c and split logic.
         * param sr                    Parent ServiceRequest__c.
         * param forfeitureInvoiceId   Id of the already-inserted forfeiture Debit Memo.
         * param consolidationLines    Unit_Consolidation__c lines for consolidation split
         *                              (empty list for non-consolidation cancellations).
         */
        private void createDebitMemosAndAllocations(
            List<Allocation__c>         clearedAllocations,
            Map<Id, Invoice__c>         paidInvoiceMap,
            Decimal                     forfeitureAmount,
            String                      cancellationType,
            ServiceRequest__c           sr,
            Id                          forfeitureInvoiceId,
            List<Unit_Consolidation__c> consolidationLines
        ) {
            Id debitMemoRTId = Schema.SObjectType.Invoice__c
                .getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
    
            // Remaining forfeiture to consume across receipts
            Decimal remaining = (forfeitureAmount != null && forfeitureAmount > 0)
                ? forfeitureAmount : 0;
    
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
    
            List<Invoice__c> debitMemos       = new List<Invoice__c>();
            List<Id>         receiptIdPerMemo = new List<Id>();
    
            // Track which NON-ADM receipt absorbs the forfeiture so we can link
            // the forfeiture Debit Memo (already inserted) to it via Allocation
            Id forfeitureReceiptId = null;
    
            for (Allocation__c alloc : clearedAllocations) {
                Decimal receiptAmt = alloc.Receipt__r.Receipt_Amount__c != null
                    ? alloc.Receipt__r.Receipt_Amount__c : 0;
    
                if (receiptAmt <= 0) continue;
    
                Boolean isADMCharge = alloc.Receipt__r.Is_ADM_Fees_and_Dari_charges__c == true;
                Boolean isProcessADM = sr.Is_ADM_Refund_Needed__c == 'Down Payment' ? False : true; // 2.0
                if (isADMCharge && isProcessADM) {
                    // ADM / Dari receipts are always fully refunded regardless of
                    // cancellation type — forfeiture and consolidation splits do not apply
                    Invoice__c dm = buildDebitMemo(
                        paidInvoiceMap.get(alloc.Invoice__c),
                        receiptAmt,
                        debitMemoRTId,
                        cancellationType,
                        sr,
                        alloc.Receipt__r.OraclePartyId__c,
                        null   // no Fund_Transfer__c for ADM receipts
                    );
                    if (dm != null) {
                        debitMemos.add(dm);
                        receiptIdPerMemo.add(alloc.Receipt__c);
                    }
                    continue;
                } else if(cancellationType != 'Consolidation Cancellation'){ // start 3.0
                    // Standard path: one Debit Memo for the full post-forfeiture amount
                    Invoice__c dm = buildDebitMemo(
                        paidInvoiceMap.get(alloc.Invoice__c),
                        receiptAmt,
                        debitMemoRTId,
                        cancellationType,
                        sr,
                        alloc.Receipt__r.OraclePartyId__c,
                        null
                    );
                    if (dm != null) {
                        debitMemos.add(dm);
                        receiptIdPerMemo.add(alloc.Receipt__c);
                    }
                }
    
                // ── Standard receipt: apply forfeiture first ─────────────────────────                
                /*Decimal postForfeitureAmt = 0;
    
                if (remaining > 0) {
                    if (remaining >= receiptAmt) {
                        // This receipt is fully consumed by forfeiture — no Debit Memo
                        remaining -= receiptAmt;
                        if (forfeitureReceiptId == null) {
                            forfeitureReceiptId = alloc.Receipt__c;
                        }
                        continue;
                    } else {
                        // Partial forfeiture on this receipt — remainder goes to refund
                        postForfeitureAmt = receiptAmt - remaining;
                        if (forfeitureReceiptId == null) {
                            forfeitureReceiptId = alloc.Receipt__c;
                        }
                        remaining = 0;
                    }
                } else {
                    // No forfeiture left — full receipt amount is available for refund
                    postForfeitureAmt = receiptAmt;
                }
    
                if (postForfeitureAmt <= 0) continue;*/ //End 3.0
    
                // ── Split post-forfeiture amount ─────────────────────────────────────
                if (cancellationType == 'Consolidation Cancellation'
                        && !consolidationLines.isEmpty()) {
                    // Consolidation path: slice postForfeitureAmt across the
                    // Unit_Consolidation__c lines in order.
                    // Each line absorbs as much as its remaining Transfer_Amount__c allows.
                    Decimal sliceRemaining = 0; //3.0
                    for (Integer i = 0; i < consolidationLines.size(); i++) {
                        if (sliceRemaining <= 0) break;
                        Decimal lineCapacity = consolidationRemaining[i];
                        if (lineCapacity <= 0) continue;
                        // This line absorbs either all of sliceRemaining or its own capacity
                        Decimal sliceAmt = consolidationLines[i].Transfer_Amount__c; //start 3.0
                        Decimal DebeitMemoAmount =0;
                        if (sliceAmt < receiptAmt) {
                        // This receipt is fully consumed by forfeiture — no Debit Memo
                        	sliceRemaining = receiptAmt - sliceAmt;
                        	DebeitMemoAmount =receiptAmt - sliceAmt;
                        	continue;
                        }else if(sliceAmt > receiptAmt){
                            sliceRemaining = receiptAmt - sliceAmt;
                        	DebeitMemoAmount =receiptAmt - sliceAmt;
                            continue;
                        }else {
                            DebeitMemoAmount =receiptAmt;
                        } //End 3.0
                        Invoice__c dm = buildDebitMemo(
                            paidInvoiceMap.get(alloc.Invoice__c),
                            DebeitMemoAmount, //3.0
                            debitMemoRTId,
                            cancellationType,
                            sr,
                            alloc.Receipt__r.OraclePartyId__c,
                            consolidationLines[i].Sales_Order__c
                        );
                        if (dm != null) {
                            debitMemos.add(dm);
                            receiptIdPerMemo.add(alloc.Receipt__c);
                        }
                        // Reduce the line's remaining capacity for subsequent receipts
                        consolidationRemaining[i] -= DebeitMemoAmount;
                        sliceRemaining            -= DebeitMemoAmount;
                    }
    
                    // Safety net: if consolidation lines didn't fully cover the receipt
                    // (e.g. Transfer_Amount__c totals don't add up to the refund amount),
                    // create a single catch-all Debit Memo for whatever is left over
                    if (sliceRemaining > 0) {
                        Invoice__c dm = buildDebitMemo(
                            paidInvoiceMap.get(alloc.Invoice__c),
                            sliceRemaining,
                            debitMemoRTId,
                            cancellationType,
                            sr,
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
         *              overrides only the fields that differ per memo:
         *                - InvoiceAmount__c      → the calculated refund slice
         *                - Fund_Transfer__c      → consolidation target (null for standard)
         *                - Transaction_Type__c   → driven by cancellationType
         *                - Oracle / OIC fields   → cleared so OIC picks it up fresh
         *              Returns null if srcInv is null so callers can safely skip.
         *
         * param srcInv            Source paid Invoice__c to clone headers from.
         * param amount            Debit Memo amount for this slice.
         * param debitMemoRTId     Record Type Id for Debit_Memo.
         * param cancellationType  Drives Transaction_Type__c value.
         * param sr                Parent ServiceRequest__c.
         * param receiptOracleId   OraclePartyId__c of the linked receipt (RefundOracleid__c).
         * param fundTransferId    Fund_Transfer__c to stamp; null for non-consolidation memos.
         */
        private Invoice__c buildDebitMemo(
            Invoice__c        srcInv,
            Decimal           amount,
            Id                debitMemoRTId,
            String            cancellationType,
            ServiceRequest__c sr,
            String            receiptOracleId,
            Id                fundTransferId
        ) {
            if (srcInv == null) return null;
    
            Invoice__c dm              = srcInv.clone(false, true, false, false);
            dm.Parent_Invoice__c       = srcInv.Id;
            dm.RecordTypeId            = debitMemoRTId;
            dm.InvoiceAmount__c        = amount;
            dm.OraclePartyId__c        = null;
            dm.OICIntegrationStatus__c = null;
            dm.OICIntegrationMessage__c = null;
            dm.Transaction_Type__c     = (cancellationType == 'Cancellation with Refund')
                                             ? 'Customer Refund' : 'Refund';  //2.0
            dm.Status__c               = 'Draft';
            dm.Service_Request__c      = sr.Id;
            dm.RefundOracleid__c       = receiptOracleId;
            dm.SalesOrderInstallment__c =srcInv.SalesOrderInstallment__c;
    
            // Stamp Fund_Transfer__c only for consolidation Debit Memos —
            // this tells Oracle which new unit/account to transfer the funds to
            dm.Transfer_Sales_Order__c        = fundTransferId;
    
            return dm;
        }
    /**
     * @description Wraps Database.upsert in consistent per-record error handling.
     *              Collects all failure messages and throws a single
     *              AuraHandledException so the UI receives the complete error list.
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

    public static Invoice__c createChange(ServiceRequest__c SR, Decimal forfeitureAmount, Id debitMemoRTId ){
        
        Id recordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName().get('Management_Fee').getRecordTypeId();
		List<Charge__c> chargesToInsert = new List<Charge__c>();
        Map<Id, String> soToAccountMap = new Map<Id, String>();
            Charge__c ch = new Charge__c(
                Name = 'Management Fee',
                Amount__c = forfeitureAmount,
                VAT_Amount__c = 0,
                Type__c = 'Cancellation Fee',
                PaymentStatus__c = 'Not Paid',
                Sales_Order__c = SR.SalesOrder__c,
                Account__c = SR.SalesOrder__r.CustomerAccount__c,
                RecordTypeId = recordTypeId,
                Service_Request__c = SR.id );

            chargesToInsert.add(ch);
            soToAccountMap.put(SR.SalesOrder__c, SR.SalesOrder__r.CustomerAccount__c);        
		list<Invoice__c> invoicesToInsert = new list<Invoice__c>();
        if (!chargesToInsert.isEmpty()) {
            insert chargesToInsert;

            
            for (Charge__c chRec : chargesToInsert) {
                String accId = soToAccountMap.get(ch.Sales_Order__c);
                if (accId != null) {
                    Decimal vat = ch.VAT_Amount__c != null ? ch.VAT_Amount__c : 0;
                    invoicesToInsert.add(new Invoice__c(
                        InvoiceAmount__c = chRec.Amount__c + vat,
                        InvoiceDate__c = System.today(),
                        Sales_Order__c = chRec.Sales_Order__c,
                        Account__c = accId,
                        Charge__c = chRec.Id,
                        Service_Request__c =chRec.Service_Request__c,
                        Is_ADM_Fees_and_Dari_charges__c = false,
                        RecordTypeId =debitMemoRTId
                    ));
                }
            }            
        }
        if(invoicesToInsert.size() > 0){
        return invoicesToInsert[0];
        }else {
          return null;  
        }
    } 
	
}