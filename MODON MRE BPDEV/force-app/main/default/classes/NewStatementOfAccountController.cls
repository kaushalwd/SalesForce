/**********************************************************************************************************************
* Name               :
* Description        : Class for BP framework
* Usage              : New SOA
* Created By         : Sivannarayana Peddireddi
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment
* 1.0           sivannaryana.p@modon.com     22-07-2026      Initial Draft
**********************************************************************************************************************/
public without sharing class NewStatementOfAccountController {

    public String currentRecordId { get; set; }
    public SOAWrapper soa { get; set; }

    // Late Payment Charges (column + related calculation) are shown only when
    // the custom label IsActivateLPCOnSOA is set to TRUE.
    public Boolean showLPC {
        get {
            if (showLPC == null) {
                String lbl = System.Label.IsActivateLPCOnSOA;
                showLPC = String.isNotBlank(lbl) && 'TRUE'.equalsIgnoreCase(lbl.trim());
            }
            return showLPC;
        }
        set;
    }

    private Decimal lpcInvoicePaidAmount = 0;
     private Decimal invoiceLPCDewAmmount = 0;

    // Running total of the excess carried by Cleared receipts on the Sales Order.
    // Feeds the "Total Excess Amount (AED)" line in buildGrandTotals().
    private Decimal clearedReceiptExcessAmount = 0;

    private Map<Id, LPCCalculationService.InstallmentLPCResult> lpcByInvoiceIdMap =
        new Map<Id, LPCCalculationService.InstallmentLPCResult>();

    public NewStatementOfAccountController() {
        currentRecordId = ApexPages.currentPage().getParameters().get('id');
        soa = new SOAWrapper();

        if (String.isNotBlank(currentRecordId)) {
            buildSOA();
        }
    }

    /*
     * Used by getStatementOfAccount() below. Avoids
     * ApexPages.currentPage(), which is only available
     * inside an actual Visualforce page request.
     */
    public NewStatementOfAccountController(Id salesOrderId) {
        currentRecordId = salesOrderId;
        soa = new SOAWrapper();

        if (String.isNotBlank(currentRecordId)) {
            buildSOA();
        }
    }

    /*
     * LWC entry point. Reuses the same SOA calculation logic
     * as the NewSOA Visualforce/PDF page, so the two stay in
     * sync instead of duplicating the business rules.
     */
    @AuraEnabled(cacheable=true)
    public static SOAWrapper getStatementOfAccount(
        Id salesOrderId
    ) {

        NewStatementOfAccountController ctrl =
            new NewStatementOfAccountController(salesOrderId);

        return ctrl.soa;
    }


    /*
     * LWC entry point for the "Download (PDF)" button. Delegates to the
     * existing downloadPDF() instance action so the LWC, the NewSOAPDF
     * Visualforce page, and any other caller all produce the exact same
     * file via the exact same logic.
     */
    @AuraEnabled
    public static String generateStatementOfAccountPdf(Id salesOrderId) {

        if (salesOrderId == null) {
            throw new AuraHandledException('Missing Sales Order.');
        }

        NewStatementOfAccountController ctrl =
            new NewStatementOfAccountController(salesOrderId);

        PageReference downloadPage = ctrl.downloadPDF();

        return downloadPage.getUrl();
    }


    private void buildSOA() {
        SalesOrder__c salesOrder = getSalesOrder((Id) currentRecordId);

        loadLPCResults(salesOrder.Id);

        soa.salesOrderId = salesOrder.Id;
        soa.todayDate = Date.today();
        soa.showLPC = showLPC;
        soa.customerName = salesOrder.CustomerAccount__r != null ? salesOrder.CustomerAccount__r.Name : '';
        soa.projectName = salesOrder.ProjectName__c;
        soa.spaDate = salesOrder.SOCreationDate__c;

        soa.unitType = salesOrder.Unit__r != null ? salesOrder.Unit__r.Type__c : '';
        soa.unitName = salesOrder.Unit__r != null ? salesOrder.Unit__r.Name : '';
        soa.price = nvl(salesOrder.TotalAmount__c);
        soa.admDistrict = salesOrder.Unit__r != null ? salesOrder.Unit__r.District__c : '';
        soa.admPlotNo = salesOrder.Unit__r != null ? salesOrder.Unit__r.PlotNo__c : '';

        soa.escrowAccountName = salesOrder.VirtualAccount__r != null ? salesOrder.VirtualAccount__r.ESCROWAccountName__c : '';
        soa.escrowBankName = salesOrder.VirtualAccount__r != null ? salesOrder.VirtualAccount__r.Escrow_Bank_Name__c : '';
        soa.virtualAccountNumber = salesOrder.VirtualAccount__r != null ? salesOrder.VirtualAccount__r.VirtualAccountNumber__c : '';
        soa.virtualIbanNumber = salesOrder.VirtualAccount__r != null ? salesOrder.VirtualAccount__r.VirtualIBANNumber__c : '';
        soa.swiftCode = salesOrder.VirtualAccount__r != null ? salesOrder.VirtualAccount__r.Swift_Code__c : '';

        soa.jointOwnerNames = getJointOwnerNames(salesOrder.Id);

        buildInstallmentPaymentRows(salesOrder.Id);
        buildOtherPaymentRows(salesOrder.Id);
        applyRowStripes();
        buildGrandTotals();
    }

    private static final String RECEIPT_STATUS_CLEARED = 'Cleared';

    // Receipt statuses that are considered "not Cleared" for the SOA. Sourced
    // from the custom label SOA_Receipt_Statuses (comma separated, e.g.
    // "In Progress,Confirmed") so the list can be tuned without a deployment.
    // This money has not landed yet, so it is reported as Uncleared Receipts.
    private static List<String> getUnclearedReceiptStatuses() {
        List<String> statuses = new List<String>();
        String lbl = System.Label.SOA_Receipt_Statuses;

        if (String.isNotBlank(lbl)) {
            for (String status : lbl.split(',')) {
                if (String.isNotBlank(status)) {
                    statuses.add(status.trim());
                }
            }
        }

        return statuses;
    }

    // Every status the SOA reports on: the label-driven uncleared statuses plus
    // Cleared, which is fixed because the Cleared branch below is hard-wired to
    // the excess-amount presentation.
    private static List<String> getSoaReceiptStatuses() {
        List<String> statuses = getUnclearedReceiptStatuses();

        if (!statuses.contains(RECEIPT_STATUS_CLEARED)) {
            statuses.add(RECEIPT_STATUS_CLEARED);
        }

        return statuses;
    }

    private SalesOrder__c getSalesOrder(Id salesOrderId) {
        return [
            SELECT Id,
                   SOCreationDate__c,
                   ProjectName__c,
                   TotalAmount__c,
                   CustomerAccount__r.Name,
                   Unit__r.Type__c,
                   Unit__r.Name,
                   Unit__r.District__c,
                   Unit__r.PlotNo__c,
                   VirtualAccount__r.ESCROWAccountName__c,
                   VirtualAccount__r.Escrow_Bank_Name__c,
                   VirtualAccount__r.VirtualIBANNumber__c,
                   VirtualAccount__r.Swift_Code__c,
                   VirtualAccount__r.VirtualAccountNumber__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
    }

    private void loadLPCResults(Id salesOrderId) {
        lpcByInvoiceIdMap.clear();

        if (salesOrderId == null) {
            return;
        }

        LPCCalculationService.LPCResult lpcResult =
            LPCCalculationService.calculateLPCBySalesOrder(salesOrderId);

        if (lpcResult == null || lpcResult.installmentResults == null) {
            return;
        }

        for (LPCCalculationService.InstallmentLPCResult instLpc : lpcResult.installmentResults) {
            if (instLpc.invoiceId != null) {
                lpcByInvoiceIdMap.put(instLpc.invoiceId, instLpc);
            }
        }
    }

    private void buildInstallmentPaymentRows(Id salesOrderId) {
        List<Invoice__c> invoiceList = [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           AppliedAmount__c,
           InvoiceBalance__c,
           InvoiceStatus__c,
           InvoiceDate__c,
           SalesOrderInstallment__c,
           SalesOrderInstallment__r.Id,
           SalesOrderInstallment__r.Name,
           SalesOrderInstallment__r.Milestone__c,
           SalesOrderInstallment__r.MilestoneNumber__c,
           SalesOrderInstallment__r.MilestoneDate__c,
           SalesOrderInstallment__r.ExtensionDate__c,
           SalesOrderInstallment__r.RFO_Date__c,
           SalesOrderInstallment__r.PaymentStatus__c,
           SalesOrderInstallment__r.IsHandoverPayment__c,
           (
               SELECT Id,
                      AllocationAmount__c,
                      ApprovedReceiptAmount__c,
                      AllocationDate__c,
                      Status__c,
                      Receipt__c,
                      Receipt__r.Name,
                      Receipt__r.TransactionNumber__c,
                      Receipt__r.Status__c,
                      Receipt__r.Modeofpayment__c,
                      Receipt__r.EBS_Clearing_Date__c
               FROM Allocations__r
               WHERE Receipt__r.Status__c = 'Cleared'
               AND Status__c = 'Applied'
               ORDER BY AllocationDate__c ASC
           )
    FROM Invoice__c
    WHERE SalesOrderInstallment__c != null
    AND SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
    AND InvoiceStatus__c != 'Cancelled'
    AND Transaction_Type__c != 'Advance Tax'
    ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC
];

        Integer counter = 0;
        Integer totalCount = invoiceList.size();
        for (Invoice__c inv : invoiceList) {
            counter++;
            PaymentRowWrapper row = new PaymentRowWrapper();
            row.invoiceId = inv.Id;
            row.installmentId = inv.SalesOrderInstallment__c;
            row.invoiceNo = getInvoiceNo(inv);
            row.amount = nvl(inv.InvoiceAmount__c);
            row.invoiceStatus = inv.InvoiceStatus__c;

            if (inv.SalesOrderInstallment__r != null) {
                row.installmentNumber = inv.SalesOrderInstallment__r.MilestoneNumber__c;
                row.installmentNumberDisplay = formatDecimalNoScale(inv.SalesOrderInstallment__r.MilestoneNumber__c);
                row.milestonePercent = inv.SalesOrderInstallment__r.Milestone__c;
                row.milestonePercentDisplay = formatDecimalNoScale(inv.SalesOrderInstallment__r.Milestone__c);
                row.milestoneDate = inv.SalesOrderInstallment__r.MilestoneDate__c;

                Date dueDate = inv.SalesOrderInstallment__r.MilestoneDate__c;
                if (inv.SalesOrderInstallment__r.ExtensionDate__c != null) {
                    dueDate = inv.SalesOrderInstallment__r.ExtensionDate__c;
                } else if (
                    inv.SalesOrderInstallment__r.IsHandoverPayment__c == true &&
                    inv.SalesOrderInstallment__r.RFO_Date__c != null) {
                    dueDate = inv.SalesOrderInstallment__r.RFO_Date__c;
                }
                row.milestoneDate = dueDate;
                row.dueDateDisplay = counter == totalCount
                    ? 'Handover'
                    : formatDate(dueDate);
                }

            Decimal clearedAllocationAmount = 0;
            if (inv.Allocations__r != null) {
                for (Allocation__c alloc : inv.Allocations__r) {
                    // A zero allocation contributes nothing to the collected
                    // amount, so it only adds a noise line under the instalment.
                    if (nvl(alloc.AllocationAmount__c) == 0) {
                        continue;
                    }
                    AllocationRowWrapper allocRow = convertAllocationToWrapper(alloc);
                    row.allocationRows.add(allocRow);
                    clearedAllocationAmount += nvl(alloc.AllocationAmount__c);
                }
            }

            row.amountCollected = clearedAllocationAmount;

            // Outstanding should be shown only when the effective installment due date has passed.
            // Effective due date is already stored in row.milestoneDate and considers:
            // ExtensionDate__c -> RFO_Date__c (handover) -> MilestoneDate__c.
            Decimal installmentBalance =
                calculateInstallmentOutstanding(inv, clearedAllocationAmount);

            if (
                row.milestoneDate != null &&
                row.milestoneDate < Date.today()
            ) {
                row.outstandingAmount = installmentBalance;
            } else {
                row.outstandingAmount = 0;
            }

            row.lpcAmount = showLPC ? calculateDynamicLpcForInstallment(inv) : 0;

            soa.paymentRows.add(row);

            soa.totalAmount += row.amount;
            soa.totalAmountCollected += row.amountCollected;
            soa.totalLatePayment += row.lpcAmount;

            if (row.milestoneDate != null && row.milestoneDate < Date.today()) {
                soa.totalAmountOutstanding += row.outstandingAmount;
            }
        }
    }

    // Assigns an alternating flag so the PDF renderer (which does not honour
    // CSS :nth-child reliably) can stripe every other row.
    private void applyRowStripes() {
        stripeRows(soa.paymentRows);
        stripeRows(soa.otherPaymentRows);
    }

    private void stripeRows(List<PaymentRowWrapper> rows) {
        if (rows == null) {
            return;
        }
        Integer index = 0;
        for (PaymentRowWrapper row : rows) {
            row.isAltRow = Math.mod(index, 2) == 1;
            index++;
        }
    }

    private void buildOtherPaymentRows(Id salesOrderId) {
        List<Invoice__c> otherInvoiceList = [
            SELECT Id,
                   Name,
                   Charge__c,
                   Charge__r.Name,
                   Charge__r.Type__c,
                   InvoiceAmount__c,
                   AppliedAmount__c,
                   TotalPaidAmount__c,
                   InvoiceBalance__c,
                   InvoiceStatus__c,
                   InvoiceDate__c,
                   Is_ADM_Fees_and_Dari_charges__c,
                   Transaction_Type__c,
                   (
                    SELECT Id,
                           AllocationAmount__c,
                           ApprovedReceiptAmount__c,
                           AllocationDate__c,
                           Status__c,
                           Mode_of_Payment__c,
                           Receipt__c,
                           Receipt__r.Name,
                           Receipt__r.TransactionNumber__c,
                           Receipt__r.Status__c,
                           Receipt__r.Modeofpayment__c,
                           Receipt__r.EBS_Clearing_Date__c
                    FROM Allocations__r
                    WHERE (
                        Status__c = 'Applied' AND
                        (Receipt__r.Status__c IN ('Cleared','In Progress','Confirmed')
                        OR Mode_of_Payment__c = 'Credit Note')
                    )
                    ORDER BY AllocationDate__c ASC
                   )
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = null
            AND Sales_Order__c = :salesOrderId
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
            ORDER BY InvoiceDate__c ASC
        ];

        for (Invoice__c inv : otherInvoiceList) {

    Boolean isLatePaymentCharge =
        inv.Charge__r != null &&
        inv.Charge__r.Name == 'Late Payment Charges';

    Decimal creditNoteAmount = 0;
    Decimal normalCollectedAmount = 0;

    List<AllocationRowWrapper> normalAllocationRows =
        new List<AllocationRowWrapper>();

    List<AllocationRowWrapper> creditNoteAllocationRows =
        new List<AllocationRowWrapper>();

    if (inv.Allocations__r != null) {
        for (Allocation__c alloc : inv.Allocations__r) {

            Decimal allocationAmount = nvl(alloc.AllocationAmount__c);

            Boolean isCreditNote =
                alloc.Mode_of_Payment__c == 'Credit Note';

            if (isLatePaymentCharge && isCreditNote) {

                creditNoteAmount += allocationAmount;
                creditNoteAllocationRows.add(
                    convertAllocationToWrapper(alloc)
                );

            } else if (
                alloc.Receipt__r != null &&
                alloc.Receipt__r.Status__c == 'Cleared'
            ) {

                normalCollectedAmount += allocationAmount;
                normalAllocationRows.add(
                    convertAllocationToWrapper(alloc)
                );
            }
        }
    }

    /*
     * Normal invoice/LPC row
     */
    PaymentRowWrapper row = new PaymentRowWrapper();

    row.invoiceId = inv.Id;
    row.invoiceNo = inv.Name;
    row.dueDateDisplay = formatDate(inv.InvoiceDate__c);

    row.transactionType =
        inv.Transaction_Type__c == 'Customer Refund'
            ? 'Customer Refund'
            : inv.Is_ADM_Fees_and_Dari_charges__c == true
                ? 'ADM/Dari Fee'
                : inv.Charge__r != null
                    ? inv.Charge__r.Name
                    : '';

    Decimal invoiceAmount = nvl(inv.InvoiceAmount__c);

    if (isLatePaymentCharge) {
        /*
         * Credit Note portion will be displayed separately
         * as Late Payment Charges Waiver.
         */
        row.amount = invoiceAmount - creditNoteAmount;

        if (row.amount < 0) {
            row.amount = 0;
        }

        row.amountCollected = normalCollectedAmount;

        Decimal calculatedOutstanding =
            row.amount - normalCollectedAmount;

        row.outstandingAmount =
            calculatedOutstanding > 0
                ? calculatedOutstanding
                : 0;
    } else {
        row.amount = invoiceAmount;
        row.amountCollected = normalCollectedAmount;
        row.outstandingAmount = nvl(inv.InvoiceBalance__c);
    }

    row.invoiceStatus = inv.InvoiceStatus__c;
    row.allocationRows.addAll(normalAllocationRows);

    soa.otherPaymentRows.add(row);

    soa.totalOtherAmount += row.amount;
    soa.totalOtherAmountCollected += row.amountCollected;

    if (
        inv.InvoiceDate__c != null &&
        inv.InvoiceDate__c < Date.today()
    ) {
        soa.totalOtherAmountOutstanding +=
            row.outstandingAmount;
    }

    /*
     * Create a separate waiver row for Credit Note allocations.
     */
    if (isLatePaymentCharge && creditNoteAmount > 0) {

        PaymentRowWrapper waiverRow =
            new PaymentRowWrapper();

        waiverRow.invoiceId = inv.Id;
        waiverRow.invoiceNo = inv.Name;
        waiverRow.dueDateDisplay =
            formatDate(inv.InvoiceDate__c);

        waiverRow.transactionType =
            'Late Payment Waiver';

        waiverRow.amount = creditNoteAmount;
        waiverRow.amountCollected = creditNoteAmount;
        waiverRow.outstandingAmount = 0;
        waiverRow.invoiceStatus = 'Applied';

        waiverRow.allocationRows.addAll(
            creditNoteAllocationRows
        );

        soa.otherPaymentRows.add(waiverRow);

        /*
         * The LPC row excludes this amount, so adding it here
         * keeps the total invoice amount unchanged.
         */
        soa.totalOtherAmount += waiverRow.amount;
        soa.totalOtherAmountCollected +=
            waiverRow.amountCollected;
    }
}

        buildFutureReceiptRowsAsOtherPayments(salesOrderId);

        if (showLPC) {
            lpcInvoicePaidAmount = getPaidLpcInvoiceAmount(salesOrderId);
            invoiceLPCDewAmmount = getLPCDewAmmount(salesOrderId);

            PaymentRowWrapper dynamicLpcRow = getDynamicLpcPaymentRow();

            if (dynamicLpcRow != null) {
                soa.otherPaymentRows.add(dynamicLpcRow);

                soa.totalOtherAmount += dynamicLpcRow.amount;
                soa.totalOtherAmountCollected += dynamicLpcRow.amountCollected;
                soa.totalOtherAmountOutstanding += dynamicLpcRow.outstandingAmount;
                // if(invoiceLPCDewAmmount > 0 )
                 //soa.totalOtherAmountOutstanding += invoiceLPCDewAmmount;

            } else {
                  if(invoiceLPCDewAmmount > 0 )
                  soa.totalOtherAmountOutstanding += invoiceLPCDewAmmount;
            }
        }

        reorderOtherPaymentRows();
    }

    private void reorderOtherPaymentRows() {
        List<PaymentRowWrapper> priorityRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> receiptRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> remainingRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> latePaymentRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> latePaymentWaiverRows = new List<PaymentRowWrapper>();

        for (PaymentRowWrapper row : soa.otherPaymentRows) {
            if (row.transactionType == 'Late Payment Charges') {
                latePaymentRows.add(row);
            } else if (row.transactionType == 'Late Payment Waiver') {
                latePaymentWaiverRows.add(row);
            } else if (row.transactionType == 'ADM/Dari Fee') {
                priorityRows.add(row);
            } else if (row.isReceiptRow) {
                receiptRows.add(row);
            } else {
                remainingRows.add(row);
            }
        }

        // Receipt rows are grouped by receipt status: Cleared first, then
        // Confirmed, then In Progress. ADM/Dari Fee and Late Payment Charges rows
        // are excluded from this ordering (they keep their own blocks).
        sortReceiptRowsByStatus(receiptRows);

        // Late Payment Waiver rows always sit immediately before the Late Payment
        // Charges rows, which close the table.
        soa.otherPaymentRows.clear();
        soa.otherPaymentRows.addAll(priorityRows);
        soa.otherPaymentRows.addAll(remainingRows);
        soa.otherPaymentRows.addAll(receiptRows);
        soa.otherPaymentRows.addAll(latePaymentWaiverRows);
        soa.otherPaymentRows.addAll(latePaymentRows);
    }

    private void sortReceiptRowsByStatus(List<PaymentRowWrapper> receiptRows) {
        if (receiptRows == null || receiptRows.size() < 2) {
            return;
        }

        List<PaymentRowWrapper> ordered = new List<PaymentRowWrapper>();

        // Stable grouping by predefined status rank; rows sharing a status keep
        // their original relative order.
        for (String status : new List<String>{ 'Cleared', 'Confirmed', 'In Progress' }) {
            for (PaymentRowWrapper row : receiptRows) {
                if (status.equalsIgnoreCase(row.invoiceStatus)) {
                    ordered.add(row);
                }
            }
        }

        // Any receipt row with an unrecognised / blank status is appended last.
        for (PaymentRowWrapper row : receiptRows) {
            if (!ordered.contains(row)) {
                ordered.add(row);
            }
        }

        receiptRows.clear();
        receiptRows.addAll(ordered);
    }

    /*
    public static Decimal getPaidLpcInvoiceAmount(Id salesOrderId) {
        return NewStatementOfAccountController.getPaidLpcInvoiceAmount(salesOrderId);
    }
    */

     public static Decimal getPaidLpcInvoiceAmount(Id salesOrderId) {
        Decimal paidAmount = 0;

        List<Invoice__c> lpcInvoiceList = [
            SELECT Id,
                   TotalPaidAmount__c,
                   Charge__r.Name,
                   InvoiceAmount__c
            FROM Invoice__c
            WHERE Sales_Order__c = :salesOrderId
            AND (Charge__r.Name = 'Late Payment Charges' OR Charge__r.Name = 'Late Payment Waiver')
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        for (Invoice__c inv : lpcInvoiceList) {
            paidAmount += nvl(inv.InvoiceAmount__c);
        }

        return paidAmount;
    }


     private Decimal getLPCDewAmmount(Id salesOrderId) {
        Decimal paidAmount = 0;

        List<Invoice__c> lpcInvoiceList = [
            SELECT Id,
                   TotalPaidAmount__c,
                   Charge__r.Name,
                   InvoiceAmount__c,InvoiceBalance__c
            FROM Invoice__c
            WHERE Sales_Order__c = :salesOrderId
            AND (Charge__r.Name = 'Late Payment Charges') AND InvoiceStatus__c!='Paid'
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        for (Invoice__c inv : lpcInvoiceList) {
            paidAmount += nvl(inv.InvoiceBalance__c);
        }

        return paidAmount;
    }


    private PaymentRowWrapper getDynamicLpcPaymentRow() {
        Decimal originalDynamicLpc = soa != null ? nvl(soa.totalLatePayment) : 0;
        Decimal paidLpcAmount = nvl(lpcInvoicePaidAmount);

        Decimal netDynamicLpcAmount = originalDynamicLpc - paidLpcAmount;

        System.debug('### Payment Details Total LPC => ' + originalDynamicLpc);
        System.debug('### Paid LPC Invoice Amount => ' + paidLpcAmount);
        System.debug('### Net Dynamic LPC Row Amount => ' + netDynamicLpcAmount);

        if (netDynamicLpcAmount <= 0) {
            soa.dynamicLatePaymentOutstanding = 0;

            return null;
        }

        netDynamicLpcAmount = netDynamicLpcAmount.setScale(2);
        soa.dynamicLatePaymentOutstanding = netDynamicLpcAmount;

        PaymentRowWrapper row = new PaymentRowWrapper();
        row.invoiceNo = '';
        row.dueDateDisplay = formatDate(Date.today());
        row.transactionType = 'Late Payment Charges';
        row.invoiceStatus = 'Pending';

        row.amount = netDynamicLpcAmount;
        row.amountCollected = 0;
        row.outstandingAmount = netDynamicLpcAmount;

        return row;
    }

    /*
     * Receipt-driven "Other Payments" rows.
     *
     * Everything below comes straight from Receipt__c on the Sales Order - no
     * Invoice__c / Allocation__c lookup is involved, so a receipt shows up
     * whether or not it has ever been allocated.
     *
     *  - Uncleared (In Progress / Confirmed, per the SOA_Receipt_Statuses label):
     *    always listed, with Amount 0.00. The money has not landed yet, so their
     *    real receipt amount is reported separately in the "Uncleared Receipts
     *    Amount (AED)" line instead of inflating the Other Payments total.
     *  - Cleared : listed only when the receipt carries an excess. The page
     *    renders that excess as <amount> in the Outstanding column.
     */
    private void buildFutureReceiptRowsAsOtherPayments(Id salesOrderId) {
        clearedReceiptExcessAmount = 0;
        soa.unclearedReceiptsAmount = 0;

        if (salesOrderId == null) {
            return;
        }

        List<String> soaReceiptStatuses = getSoaReceiptStatuses();

        List<Receipt__c> receiptList = [
            SELECT Id,
                   Name,
                   Status__c,
                   Modeofpayment__c,
                   Receipt_Amount__c,
                   AppliedAmount__c,
                   Receipt_Excess_Amount__c,
                   TransactionNumber__c,
                   EBS_Clearing_Date__c,
                   ChequeDate__c,
                   TransactionDate__c
            FROM Receipt__c
            WHERE SalesOrder__c = :salesOrderId
            AND Status__c IN :soaReceiptStatuses
            ORDER BY TransactionDate__c ASC
        ];

        for (Receipt__c rec : receiptList) {

            Boolean isCleared = RECEIPT_STATUS_CLEARED.equalsIgnoreCase(rec.Status__c);
            Decimal receiptAmount = nvl(rec.Receipt_Amount__c);
            Decimal excessAmount = nvl(rec.Receipt_Excess_Amount__c);

            // A Cleared receipt only earns a row when it left an excess behind;
            // its applied portion is already reflected on the invoice rows.
            if (isCleared && excessAmount == 0) {
                continue;
            }

            PaymentRowWrapper row = new PaymentRowWrapper();

            // Every row here represents a Receipt, so it takes part in the
            // receipt-status grouping in reorderOtherPaymentRows().
            row.isReceiptRow = true;
            row.invoiceStatus = rec.Status__c;

            if (isCleared) {
                // Excess receipt: hide Due Date / Invoice No. and tag the
                // transaction type with the receipt's mode of payment.
                row.dueDateDisplay = '';
                row.invoiceNo = '';
                row.transactionType = String.isNotBlank(rec.Modeofpayment__c)
                    ? 'Receipt - ' + rec.Modeofpayment__c
                    : 'Receipt';

                row.amount = receiptAmount;
                row.amountCollected = 0;
                row.outstandingAmount = -1 * excessAmount;

                // Tells the page to render the Outstanding value as <amount>.
                row.isClearedExcessRow = true;

                clearedReceiptExcessAmount += excessAmount;
                soa.excessOutstandingNotInOtherTotal += row.outstandingAmount;

            } else {
                row.dueDateDisplay = '';
                row.invoiceNo = '';
                row.transactionType = String.isNotBlank(rec.Modeofpayment__c)
                    ? 'Receipt - ' + rec.Modeofpayment__c
                    : 'Receipt - PDC';

                // Uncleared money is reported in Uncleared Receipts Amount, so the
                // table shows 0.00 to keep it out of the Other Payments total.
                row.amount = receiptAmount;
                row.amountCollected = 0;
                row.outstandingAmount = 0;

                soa.unclearedReceiptsAmount += receiptAmount;
            }

            // No Allocation__c is read here, so synthesise the allocation-detail
            // row from the receipt itself; otherwise the Cheque/Transaction No.
            // and Cleared Date columns render blank.
            row.allocationRows.add(convertReceiptToAllocationWrapper(rec));

            soa.otherPaymentRows.add(row);

            soa.totalOtherAmount += row.amount;
            soa.totalOtherAmountCollected += row.amountCollected;
        }
    }

    private AllocationRowWrapper convertReceiptToAllocationWrapper(Receipt__c rec) {
        AllocationRowWrapper allocRow = new AllocationRowWrapper();

        allocRow.receiptId = rec.Id;
        allocRow.receiptName = rec.Name;
        allocRow.receiptStatus = rec.Status__c;
        allocRow.transactionNumber =
            (String.isBlank(rec.TransactionNumber__c) &&
             rec.Modeofpayment__c == 'Equity Transfer')
                ? 'ET-' + rec.Name
                : rec.TransactionNumber__c;
        allocRow.ebsClearingDate = rec.EBS_Clearing_Date__c;
        allocRow.ebsClearingDateDisplay = formatDate(rec.EBS_Clearing_Date__c);

        return allocRow;
    }

    private void buildGrandTotals() {
        Decimal totalOutstanding =
            nvl(soa.totalAmountOutstanding) +
            nvl(soa.totalOtherAmountOutstanding);

        // "Total Excess Amount (AED)" starts as the sum of the excess carried by
        // the Cleared receipts, and is always deducted from the Total Outstanding.
        Decimal excessAmount = nvl(clearedReceiptExcessAmount);

        soa.grandTotalOutstanding = totalOutstanding - excessAmount;

        // Any outstanding balance is settled out of the excess first, so the
        // excess reported is only what is left after covering it.
        if (totalOutstanding > 0) {
            excessAmount = excessAmount - totalOutstanding;
        }
        soa.totalExcessAmount = excessAmount < 0 ? 0 : excessAmount;

        // Never show a negative Total Outstanding - an excess that exceeds the
        // outstanding balance floors it at zero.
        if (soa.grandTotalOutstanding < 0) {
            soa.grandTotalOutstanding = 0;
        }
    }

    private Decimal calculateInstallmentOutstanding(Invoice__c inv, Decimal clearedAllocationAmount) {
        Decimal balance = nvl(inv.InvoiceAmount__c) - nvl(clearedAllocationAmount);
        return balance < 0 ? 0 : balance;
    }

    private Decimal calculateDynamicLpcForInstallment(Invoice__c inv) {
        if (inv == null || inv.Id == null) {
            return 0;
        }

        LPCCalculationService.InstallmentLPCResult lpcResult =
            lpcByInvoiceIdMap.get(inv.Id);

        if (lpcResult == null || lpcResult.lpcAmount == null) {
            return 0;
        }

        return lpcResult.lpcAmount;
    }

    private String getInvoiceNo(Invoice__c inv) {
        if (
            inv.SalesOrderInstallment__r != null &&
            inv.SalesOrderInstallment__r.MilestoneDate__c != null &&
            inv.SalesOrderInstallment__r.MilestoneDate__c < Date.today()
        ) {
            return inv.Name;
        }

        return 'TBI';
    }

    private AllocationRowWrapper convertAllocationToWrapper(Allocation__c alloc) {
        AllocationRowWrapper row = new AllocationRowWrapper();

        row.allocationId = alloc.Id;
        row.allocationAmount = nvl(alloc.AllocationAmount__c);
        row.allocationDate = alloc.AllocationDate__c;
        row.allocationDateDisplay = formatDate(alloc.AllocationDate__c);

        if (alloc.Receipt__r != null) {
            row.receiptId = alloc.Receipt__c;
            row.receiptName = alloc.Receipt__r.Name;
            row.receiptStatus = alloc.Receipt__r.Status__c;
            row.transactionNumber = getTransactionNumber(alloc);
            row.ebsClearingDate = alloc.Receipt__r.EBS_Clearing_Date__c;
            row.ebsClearingDateDisplay = formatDate(alloc.Receipt__r.EBS_Clearing_Date__c);
        }

        return row;
    }

    private String getTransactionNumber(Allocation__c alloc) {
        if (alloc == null || alloc.Receipt__r == null) {
            return '';
        }

        if (
            String.isBlank(alloc.Receipt__r.TransactionNumber__c) &&
            alloc.Receipt__r.Modeofpayment__c == 'Equity Transfer'
        ) {
            return 'ET-' + alloc.Receipt__r.Name;
        }

        return alloc.Receipt__r.TransactionNumber__c;
    }

    private String getJointOwnerNames(Id salesOrderId) {
    List<JointOwner__c> joList = [
        SELECT JointOwnerAccount__r.Name
        FROM JointOwner__c
        WHERE SalesOrder__c = :salesOrderId
        AND JointOwnerAccount__c != null
        ORDER BY CreatedDate
    ];

    List<String> names = new List<String>();
    Set<String> uniqueNames = new Set<String>();

    for (JointOwner__c jo : joList) {
        if (jo.JointOwnerAccount__r != null &&
            String.isNotBlank(jo.JointOwnerAccount__r.Name)) {

            String name = jo.JointOwnerAccount__r.Name.trim();

            if (uniqueNames.add(name)) {
                names.add(name);
            }
        }
    }

    return names.isEmpty() ? null : String.join(names, ', ');
}

    private static Decimal nvl(Decimal value) {
        return value == null ? 0 : value;
    }

    private static String formatDate(Date inputDate) {
        if (inputDate == null) {
            return '';
        }

        DateTime dt = DateTime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));
        return dt.format('dd-MMM-yy');
    }

    private static String formatDecimalNoScale(Decimal inputValue) {
        if (inputValue == null) {
            return '';
        }

        return String.valueOf(inputValue.setScale(0));
    }

    public PageReference downloadPDF() {
        PageReference pdfPage = Page.NewSOAPDF;
        pdfPage.getParameters().put('id', currentRecordId);

        Blob pdfBlob;

        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        } else {
            pdfBlob = Blob.valueOf('Dummy PDF content');
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Statement_of_Account';
        cv.PathOnClient = 'StatementOfAccount.pdf';
        cv.VersionData = pdfBlob;
        insert cv;

        ContentVersion savedCV = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        String downloadUrl =
            URL.getOrgDomainUrl().toExternalForm() +
            '/sfc/servlet.shepherd/document/download/' +
            savedCV.ContentDocumentId;

        PageReference pr = new PageReference(downloadUrl);
        pr.setRedirect(true);
        return pr;
    }

    public class SOAWrapper {
        @AuraEnabled public Id salesOrderId { get; set; }
        @AuraEnabled public Date todayDate { get; set; }

        // Mirrors the controller's showLPC so the LWC can hide the LPC column
        // exactly like the NewSOA / NewSOAPDF pages do.
        @AuraEnabled public Boolean showLPC { get; set; }

        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String jointOwnerNames { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public Date spaDate { get; set; }

        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public String admDistrict { get; set; }
        @AuraEnabled public String admPlotNo { get; set; }

        @AuraEnabled public String escrowAccountName { get; set; }
        @AuraEnabled public String escrowBankName { get; set; }
        @AuraEnabled public String virtualAccountNumber { get; set; }
        @AuraEnabled public String virtualIbanNumber { get; set; }
        @AuraEnabled public String swiftCode { get; set; }

        @AuraEnabled public List<PaymentRowWrapper> paymentRows { get; set; }
        @AuraEnabled public List<PaymentRowWrapper> otherPaymentRows { get; set; }

        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Decimal totalAmountCollected { get; set; }
        @AuraEnabled public Decimal totalLatePayment { get; set; }
        @AuraEnabled public Decimal dynamicLatePaymentOutstanding { get; set; }
        @AuraEnabled public Decimal totalAmountOutstanding { get; set; }

        @AuraEnabled public Decimal totalOtherAmount { get; set; }
        @AuraEnabled public Decimal totalOtherAmountCollected { get; set; }
        @AuraEnabled public Decimal totalOtherAmountOutstanding { get; set; }
        @AuraEnabled public Decimal excessOutstandingNotInOtherTotal { get; set; }

        // Total amount of Receipts that are not yet Cleared (In Progress / Confirmed).
        @AuraEnabled public Decimal unclearedReceiptsAmount { get; set; }

        // Positive total of receipt excess amounts (shown as its own row).
        @AuraEnabled public Decimal totalExcessAmount { get; set; }

        @AuraEnabled public Decimal grandTotalOutstanding { get; set; }

        public SOAWrapper() {
            paymentRows = new List<PaymentRowWrapper>();
            otherPaymentRows = new List<PaymentRowWrapper>();

            totalAmount = 0;
            totalAmountCollected = 0;
            totalLatePayment = 0;
            dynamicLatePaymentOutstanding = 0;
            totalAmountOutstanding = 0;

            totalOtherAmount = 0;
            totalOtherAmountCollected = 0;
            totalOtherAmountOutstanding = 0;
            excessOutstandingNotInOtherTotal = 0;
            unclearedReceiptsAmount = 0;
            totalExcessAmount = 0;

            grandTotalOutstanding = 0;
            showLPC = false;
        }
    }

    public class PaymentRowWrapper {
        @AuraEnabled public Id invoiceId { get; set; }
        @AuraEnabled public Id installmentId { get; set; }

        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public String dueDateDisplay { get; set; }

        @AuraEnabled public Decimal installmentNumber { get; set; }
        @AuraEnabled public String installmentNumberDisplay { get; set; }

        @AuraEnabled public String invoiceNo { get; set; }

        @AuraEnabled public Decimal milestonePercent { get; set; }
        @AuraEnabled public String milestonePercentDisplay { get; set; }

        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String transactionType { get; set; }
        @AuraEnabled public String invoiceStatus { get; set; }

        @AuraEnabled public Decimal amountCollected { get; set; }
        @AuraEnabled public Decimal lpcAmount { get; set; }
        @AuraEnabled public Decimal outstandingAmount { get; set; }

        @AuraEnabled public Date milestoneDate { get; set; }

        @AuraEnabled public List<AllocationRowWrapper> allocationRows { get; set; }

        @AuraEnabled public Boolean isAltRow { get; set; }

        // TRUE for Other Payments rows that represent a Receipt (used to group
        // them by receipt status: Cleared -> Confirmed -> In Progress).
        @AuraEnabled public Boolean isReceiptRow { get; set; }

        // TRUE for a cleared receipt's excess amount shown under Other Payments -
        // the Outstanding column renders it as <amount> instead of -amount.
        @AuraEnabled public Boolean isClearedExcessRow { get; set; }

        public PaymentRowWrapper() {
            amount = 0;
            amountCollected = 0;
            lpcAmount = 0;
            outstandingAmount = 0;
            isAltRow = false;
            isReceiptRow = false;
            isClearedExcessRow = false;
            allocationRows = new List<AllocationRowWrapper>();
        }
    }

    public class AllocationRowWrapper {
        @AuraEnabled public Id allocationId { get; set; }
        @AuraEnabled public Id receiptId { get; set; }

        @AuraEnabled public Decimal allocationAmount { get; set; }

        @AuraEnabled public Date allocationDate { get; set; }
        @AuraEnabled public String allocationDateDisplay { get; set; }

        @AuraEnabled public String allocationStatus { get; set; }

        @AuraEnabled public String receiptName { get; set; }
        @AuraEnabled public String receiptStatus { get; set; }
        @AuraEnabled public String transactionNumber { get; set; }

        @AuraEnabled public Date ebsClearingDate { get; set; }
        @AuraEnabled public String ebsClearingDateDisplay { get; set; }

        public AllocationRowWrapper() {
            allocationAmount = 0;
        }
    }
}