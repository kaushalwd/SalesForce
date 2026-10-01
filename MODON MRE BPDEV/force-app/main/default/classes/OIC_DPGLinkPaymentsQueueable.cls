/**********************************************************************************************************************
* Name               : OIC_DPGLinkPaymentsQueueable
* Description        : Asynchronously links collected Booking Fee Payments (Receipt__c), Invoices (Invoice__c),
*                      and Allocations (Allocation__c) to a newly created Sales Order.
*                      Runs in the background so it has zero impact on OIC_DPGCreateSalesOrderAPI response time.
*                      - ADM Dari Fees Payment: Attaches SalesOrder__c, SalesOrderInstallment__c = null, links to ADM Invoice.
*                      - Downpayment Payment: Attaches SalesOrder__c, SalesOrderInstallment__c = Milestone 1 Installment,
*                        links to Milestone 1 Installment Invoice.
* Created By         : pprajapati@horizontal.com
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           pprajapati@horizontal.com   02 Sep 2026     Initial Implementation
***********************************************************************************************************************/
public without sharing class OIC_DPGLinkPaymentsQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> salesOrderIds;

    public OIC_DPGLinkPaymentsQueueable(Set<Id> soIds) {
        this.salesOrderIds = (soIds != null) ? soIds : new Set<Id>();
    }

    public void execute(QueueableContext ctx) {
        if (salesOrderIds.isEmpty()) return;

        try {
            linkPaymentsForSalesOrders(salesOrderIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OIC_DPGLinkPaymentsQueueable exception: ' + e.getMessage() + ' | Line: ' + e.getLineNumber() + '\n' + e.getStackTraceString());
        }
    }

    public static void linkPaymentsForSalesOrders(Set<Id> soIds) {
        if (soIds == null || soIds.isEmpty()) return;

        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([
            SELECT Id, Opportunity__c, Unit__c, CustomerAccount__c
            FROM SalesOrder__c
            WHERE Id IN :soIds
        ]);
        if (soMap.isEmpty()) return;

        Set<Id> oppIds  = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();
        Map<String, Id> soByKey = new Map<String, Id>(); // Key: OppId|UnitId -> SalesOrderId
        for (SalesOrder__c so : soMap.values()) {
            if (so.Opportunity__c != null && so.Unit__c != null) {
                oppIds.add(so.Opportunity__c);
                unitIds.add(so.Unit__c);
                soByKey.put(so.Opportunity__c + '|' + so.Unit__c, so.Id);
            }
        }
        if (oppIds.isEmpty() || unitIds.isEmpty()) return;

        // Query Booking Fee Allocations with collected Payments (Receipt__c)
        List<Booking_Fee_Allocation__c> feeAllocs = [
            SELECT Id, Payment__c, Allocation_Amount__c,
                   Booking_Fee_Line__c, Booking_Fee_Line__r.Type__c,
                   Booking_Fee_Line__r.Opportunity__c, Booking_Fee_Line__r.Unit__c
            FROM Booking_Fee_Allocation__c
            WHERE Status__c = 'Applied'
              AND Payment__c != null
              AND Allocation_Amount__c > 0
              AND Booking_Fee_Line__r.Opportunity__c IN :oppIds
              AND Booking_Fee_Line__r.Unit__c IN :unitIds
        ];
        if (feeAllocs.isEmpty()) return;

        // Collect Receipt IDs
        Set<Id> receiptIds = new Set<Id>();
        for (Booking_Fee_Allocation__c bfa : feeAllocs) {
            receiptIds.add(bfa.Payment__c);
        }

        // Query existing Allocations to ensure idempotency
        Map<String, Allocation__c> existingAllocMap = new Map<String, Allocation__c>();
        for (Allocation__c ex : [
            SELECT Id, Receipt__c, Invoice__c
            FROM Allocation__c
            WHERE Receipt__c IN :receiptIds
        ]) {
            existingAllocMap.put(ex.Receipt__c + '|' + ex.Invoice__c, ex);
        }

        // Query Milestone 1 Installments for each Sales Order
        Map<Id, SalesOrderInstallments__c> m1InstallmentBySo = new Map<Id, SalesOrderInstallments__c>();
        for (SalesOrderInstallments__c soi : [
            SELECT Id, SalesOrder__c, MilestoneNumber__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :soIds
              AND MilestoneNumber__c = 1
        ]) {
            m1InstallmentBySo.put(soi.SalesOrder__c, soi);
        }

        // Query Invoices for the Sales Orders
        Map<Id, Invoice__c> admInvoiceBySo = new Map<Id, Invoice__c>();
        Map<Id, Invoice__c> m1InvoiceBySo  = new Map<Id, Invoice__c>();
        for (Invoice__c inv : [
            SELECT Id, Sales_Order__c, SalesOrderInstallment__c, Is_ADM_Fees_and_Dari_charges__c,
                   InvoiceAmount__c, InvoiceBalance__c, SalesOrderInstallment__r.MilestoneNumber__c,
                   SalesOrderInstallment__r.SalesOrder__c
            FROM Invoice__c
            WHERE (Sales_Order__c IN :soIds OR SalesOrderInstallment__r.SalesOrder__c IN :soIds)
              AND isCancelled__c = false
        ]) {
            if (inv.Is_ADM_Fees_and_Dari_charges__c == true && inv.Sales_Order__c != null) {
                admInvoiceBySo.put(inv.Sales_Order__c, inv);
            }
            if (inv.SalesOrderInstallment__r != null && inv.SalesOrderInstallment__r.MilestoneNumber__c == 1) {
                m1InvoiceBySo.put(inv.SalesOrderInstallment__r.SalesOrder__c, inv);
            }
        }

        Map<Id, Receipt__c> receiptsToUpdate = new Map<Id, Receipt__c>();
        List<Allocation__c> allocationsToInsert = new List<Allocation__c>();

        for (Booking_Fee_Allocation__c bfa : feeAllocs) {
            Id rId = bfa.Payment__c;
            String key = bfa.Booking_Fee_Line__r.Opportunity__c + '|' + bfa.Booking_Fee_Line__r.Unit__c;
            Id soId = soByKey.get(key);
            if (soId == null) continue;

            SalesOrder__c so = soMap.get(soId);
            String feeType = bfa.Booking_Fee_Line__r.Type__c;
            Boolean isAdm = (feeType != null && feeType.containsIgnoreCase('ADM'));

            Receipt__c r = receiptsToUpdate.containsKey(rId)
                ? receiptsToUpdate.get(rId)
                : new Receipt__c(Id = rId);

            r.SalesOrder__c = soId;
            if (so != null && so.CustomerAccount__c != null) {
                r.Account__c = so.CustomerAccount__c;
            }

            if (isAdm) {
                // ADM Dari Fees Payment: SalesOrderInstallment__c explicitly omitted (null)
                r.SalesOrderInstallment__c = null;
                r.Is_ADM_Fees_and_Dari_charges__c = true;
                r.Transaction_Type__c = 'ADM_CHARGES';

                // Link to ADM Invoice via Allocation__c
                Invoice__c admInv = admInvoiceBySo.get(soId);
                if (admInv != null) {
                    String allocKey = rId + '|' + admInv.Id;
                    if (!existingAllocMap.containsKey(allocKey)) {
                        Decimal allocAmt = (bfa.Allocation_Amount__c != null) ? bfa.Allocation_Amount__c : 0;
                        allocationsToInsert.add(new Allocation__c(
                            Invoice__c               = admInv.Id,
                            Receipt__c               = rId,
                            Status__c                = 'Applied',
                            AllocationDate__c        = Date.today(),
                            AllocationAmount__c      = allocAmt,
                            ApprovedReceiptAmount__c = allocAmt
                        ));
                    }
                }
            } else {
                // Downpayment Payment: Attach SalesOrderInstallment__c (Milestone 1)
                SalesOrderInstallments__c m1 = m1InstallmentBySo.get(soId);
                if (m1 != null) {
                    r.SalesOrderInstallment__c = m1.Id;
                }
                r.Is_ADM_Fees_and_Dari_charges__c = false;

                // Link to Milestone 1 Installment Invoice via Allocation__c
                Invoice__c m1Inv = m1InvoiceBySo.get(soId);
                if (m1Inv != null) {
                    String allocKey = rId + '|' + m1Inv.Id;
                    if (!existingAllocMap.containsKey(allocKey)) {
                        Decimal allocAmt = (bfa.Allocation_Amount__c != null) ? bfa.Allocation_Amount__c : 0;
                        allocationsToInsert.add(new Allocation__c(
                            Invoice__c               = m1Inv.Id,
                            Receipt__c               = rId,
                            Status__c                = 'Applied',
                            AllocationDate__c        = Date.today(),
                            AllocationAmount__c      = allocAmt,
                            ApprovedReceiptAmount__c = allocAmt
                        ));
                    }
                }
            }

            receiptsToUpdate.put(rId, r);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!receiptsToUpdate.isEmpty()) {
                update receiptsToUpdate.values();
                System.debug('OIC_DPGLinkPaymentsQueueable: Successfully updated ' + receiptsToUpdate.size() + ' payment (Receipt__c) records.');
            }
            if (!allocationsToInsert.isEmpty()) {
                insert allocationsToInsert;
                System.debug('OIC_DPGLinkPaymentsQueueable: Successfully inserted ' + allocationsToInsert.size() + ' Allocation__c records.');
            }
        } catch (Exception dmlEx) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'OIC_DPGLinkPaymentsQueueable DML error: ' + dmlEx.getMessage() + '\n' + dmlEx.getStackTraceString());
            throw dmlEx;
        }
    }
}