/**********************************************************************************************************************
* Name               : CustomerStatementOfAccountController
* Description         : Controller for the consolidated Customer Statement of Account (CustomerSOA page).
*                       Lists every non-excluded Sales Order that belongs to a customer Account and, for each of
*                       them, reuses the same data-calculation rules as the single Sales Order SOA
*                       (NewStatementOfAccountController) so the two documents stay in sync.
*
*                       The page can be launched from either:
*                         - an Account            -> id = Account Id
*                         - a Sales Order         -> id = SalesOrder__c Id (its CustomerAccount__c is resolved)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment
* 1.0           MODON                                           Initial consolidated SOA
* 2.0           MODON                           06-09-2026      Ported NewStatementOfAccountController data logic,
*                                                               NewSOA styling and Account / Sales Order entry points
**********************************************************************************************************************/
public with sharing class CustomerStatementOfAccountController {

    public Id customerAccountId { get; set; }
    public CustomerSOAWrapper customerSOA { get; set; }

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

    // Per Sales Order LPC bookkeeping - reset for every Sales Order in the loop.
    private Decimal lpcInvoicePaidAmount = 0;
    private Decimal invoiceLPCDewAmmount = 0;

    private Map<Id, LPCCalculationService.InstallmentLPCResult> lpcByInvoiceIdMap =
        new Map<Id, LPCCalculationService.InstallmentLPCResult>();

    public CustomerStatementOfAccountController() {
        customerAccountId = resolveCustomerAccountId(
            ApexPages.currentPage().getParameters().get('id')
        );

        customerSOA = new CustomerSOAWrapper();

        if (customerAccountId != null) {
            buildCustomerSOA();
        }
    }

    /*
     * Accepts either an Account Id (SOA opened from an Account) or a
     * SalesOrder__c Id (SOA opened from a Sales Order) and always returns the
     * customer Account Id whose Sales Orders should be listed.
     */
    private Id resolveCustomerAccountId(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }

        Id parsedId;
        try {
            parsedId = (Id) recordId;
        } catch (Exception e) {
            return null;
        }

        Schema.SObjectType sObjType = parsedId.getSObjectType();

        if (sObjType == Account.SObjectType) {
            return parsedId;
        }

        if (sObjType == SalesOrder__c.SObjectType) {
            List<SalesOrder__c> salesOrderList = [
                SELECT CustomerAccount__c
                FROM SalesOrder__c
                WHERE Id = :parsedId
                LIMIT 1
            ];

            return (salesOrderList.isEmpty() || salesOrderList[0].CustomerAccount__c == null)
                ? null
                : salesOrderList[0].CustomerAccount__c;
        }

        return null;
    }

    private void buildCustomerSOA() {

        String soStatusExcludeLabel = System.Label.SO_Status_List;
        List<String> excludedStatusList = new List<String>();

        if (!String.isBlank(soStatusExcludeLabel)) {
            for (String statusValue : soStatusExcludeLabel.split(',')) {
                excludedStatusList.add(statusValue.trim());
            }
        }

        List<Account> accList = [
            SELECT Id,
                   Name,
                   (
                       SELECT Id,
                              Name,
                              Status__c,
                              SOCreationDate__c,
                              ProjectName__c,
                              TotalAmount__c,
                              Unit__r.Type__c,
                              Unit__r.UnitClassification__c,
                              Unit__r.Name,
                              Unit__r.District__c,
                              Unit__r.PlotNo__c,
                              VirtualAccount__r.ESCROWAccountName__c,
                              VirtualAccount__r.Escrow_Bank_Name__c,
                              VirtualAccount__r.VirtualIBANNumber__c,
                              VirtualAccount__r.Swift_Code__c,
                              VirtualAccount__r.VirtualAccountNumber__c
                       FROM Sales_Orders__r
                       WHERE Status__c NOT IN :excludedStatusList
                       ORDER BY ProjectName__c ASC, Unit__r.Name ASC
                   )
            FROM Account
            WHERE Id = :customerAccountId
            LIMIT 1
        ];

        if (accList.isEmpty()) {
            return;
        }

        Account acc = accList[0];

        customerSOA.customerId = acc.Id;
        customerSOA.customerName = acc.Name;
        customerSOA.todayDate = Date.today();

        if (acc.Sales_Orders__r == null || acc.Sales_Orders__r.isEmpty()) {
            return;
        }

        for (SalesOrder__c salesOrder : acc.Sales_Orders__r) {

            SOAWrapper soa = new SOAWrapper();

            lpcInvoicePaidAmount = 0;
            invoiceLPCDewAmmount = 0;
            loadLPCResults(salesOrder.Id);

            soa.salesOrderId = salesOrder.Id;
            soa.salesOrderName = salesOrder.Name;
            soa.todayDate = Date.today();
            soa.customerName = acc.Name;
            soa.projectName = salesOrder.ProjectName__c;
            soa.spaDate = salesOrder.SOCreationDate__c;

            soa.unitType = salesOrder.Unit__r != null
                ? (!String.isBlank(salesOrder.Unit__r.UnitClassification__c)
                    ? salesOrder.Unit__r.UnitClassification__c
                    : salesOrder.Unit__r.Type__c)
                : '';

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

            buildInstallmentPaymentRows(salesOrder.Id, soa);
            buildOtherPaymentRows(salesOrder.Id, soa);
            applyRowStripes(soa);
            buildGrandTotals(soa);

            soa.unclearedReceiptsAmount = calculateUnclearedReceiptsAmount(salesOrder.Id);

            soa.summaryOutstanding = soa.price - soa.totalAmountCollected;
            if (soa.summaryOutstanding < 0) {
                soa.summaryOutstanding = 0;
            }

            soa.collectionPercentage = soa.price > 0
                ? (soa.totalAmountCollected / soa.price) * 100
                : 0;

            customerSOA.salesOrderSOAs.add(soa);

            customerSOA.totalSalesValue += soa.price;
            customerSOA.totalAmount += soa.totalAmount;
            customerSOA.totalAmountCollected += soa.totalAmountCollected;
            customerSOA.totalLatePayment += soa.totalLatePayment;
            customerSOA.totalAmountOutstanding += soa.totalAmountOutstanding;

            customerSOA.totalOtherAmount += soa.totalOtherAmount;
            customerSOA.totalOtherAmountCollected += soa.totalOtherAmountCollected;
            customerSOA.totalOtherAmountOutstanding += soa.totalOtherAmountOutstanding;
            customerSOA.excessOutstandingNotInOtherTotal += soa.excessOutstandingNotInOtherTotal;

            customerSOA.totalUnclearedReceiptsAmount += soa.unclearedReceiptsAmount;
            customerSOA.grandTotalOutstanding += soa.grandTotalOutstanding;
            customerSOA.totalSummaryOutstanding += soa.summaryOutstanding;
        }

        customerSOA.collectionPercentage = customerSOA.totalSalesValue > 0
            ? (customerSOA.totalAmountCollected / customerSOA.totalSalesValue) * 100
            : 0;

        sortSalesOrderSOAsByProjectName();

        for (Integer i = 0; i < customerSOA.salesOrderSOAs.size(); i++) {
            customerSOA.salesOrderSOAs[i].isLast = i == customerSOA.salesOrderSOAs.size() - 1;
        }
    }

    private void sortSalesOrderSOAsByProjectName() {
        if (customerSOA == null || customerSOA.salesOrderSOAs == null || customerSOA.salesOrderSOAs.size() <= 1) {
            return;
        }

        for (Integer i = 0; i < customerSOA.salesOrderSOAs.size(); i++) {
            for (Integer j = i + 1; j < customerSOA.salesOrderSOAs.size(); j++) {

                SOAWrapper firstSoa = customerSOA.salesOrderSOAs[i];
                SOAWrapper secondSoa = customerSOA.salesOrderSOAs[j];

                String firstProject = String.isBlank(firstSoa.projectName) ? '' : firstSoa.projectName.toLowerCase();
                String secondProject = String.isBlank(secondSoa.projectName) ? '' : secondSoa.projectName.toLowerCase();

                String firstUnit = String.isBlank(firstSoa.unitName) ? '' : firstSoa.unitName.toLowerCase();
                String secondUnit = String.isBlank(secondSoa.unitName) ? '' : secondSoa.unitName.toLowerCase();

                Boolean shouldSwap = false;

                if (firstProject.compareTo(secondProject) > 0) {
                    shouldSwap = true;
                } else if (firstProject == secondProject && firstUnit.compareTo(secondUnit) > 0) {
                    shouldSwap = true;
                }

                if (shouldSwap) {
                    customerSOA.salesOrderSOAs[i] = secondSoa;
                    customerSOA.salesOrderSOAs[j] = firstSoa;
                }
            }
        }
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

    private void buildInstallmentPaymentRows(Id salesOrderId, SOAWrapper soa) {

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

                Date dueDate = inv.SalesOrderInstallment__r.MilestoneDate__c;
                if (inv.SalesOrderInstallment__r.ExtensionDate__c != null) {
                    dueDate = inv.SalesOrderInstallment__r.ExtensionDate__c;
                } else if (
                    inv.SalesOrderInstallment__r.IsHandoverPayment__c == true &&
                    inv.SalesOrderInstallment__r.RFO_Date__c != null
                ) {
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
                    AllocationRowWrapper allocRow = convertAllocationToWrapper(alloc);
                    row.allocationRows.add(allocRow);
                    clearedAllocationAmount += nvl(alloc.AllocationAmount__c);
                }
            }

            row.amountCollected = clearedAllocationAmount;

            Decimal installmentBalance =
                calculateInstallmentOutstanding(inv, clearedAllocationAmount);

            if (row.milestoneDate != null && row.milestoneDate < Date.today()) {
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
    private void applyRowStripes(SOAWrapper soa) {
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

    private void buildOtherPaymentRows(Id salesOrderId, SOAWrapper soa) {

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
                           (Receipt__r.Status__c = 'Cleared'
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

            List<AllocationRowWrapper> normalAllocationRows = new List<AllocationRowWrapper>();
            List<AllocationRowWrapper> creditNoteAllocationRows = new List<AllocationRowWrapper>();

            if (inv.Allocations__r != null) {
                for (Allocation__c alloc : inv.Allocations__r) {

                    Decimal allocationAmount = nvl(alloc.AllocationAmount__c);
                    Boolean isCreditNote = alloc.Mode_of_Payment__c == 'Credit Note';

                    if (isLatePaymentCharge && isCreditNote) {
                        creditNoteAmount += allocationAmount;
                        creditNoteAllocationRows.add(convertAllocationToWrapper(alloc));
                    } else if (
                        alloc.Receipt__r != null &&
                        alloc.Receipt__r.Status__c == 'Cleared'
                    ) {
                        normalCollectedAmount += allocationAmount;
                        normalAllocationRows.add(convertAllocationToWrapper(alloc));
                    }
                }
            }

            PaymentRowWrapper row = new PaymentRowWrapper();
            row.invoiceId = inv.Id;
            row.invoiceNo = inv.Name;
            row.dueDateDisplay = formatDate(inv.InvoiceDate__c);

            row.transactionType =
                inv.Is_ADM_Fees_and_Dari_charges__c == true
                    ? 'ADM/Dari Fee'
                    : inv.Charge__r != null
                        ? inv.Charge__r.Name
                        : '';

            Decimal invoiceAmount = nvl(inv.InvoiceAmount__c);

            if (isLatePaymentCharge) {
                row.amount = invoiceAmount - creditNoteAmount;
                if (row.amount < 0) {
                    row.amount = 0;
                }

                row.amountCollected = normalCollectedAmount;

                Decimal calculatedOutstanding = row.amount - normalCollectedAmount;
                row.outstandingAmount = calculatedOutstanding > 0 ? calculatedOutstanding : 0;
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

            if (inv.InvoiceDate__c != null && inv.InvoiceDate__c < Date.today()) {
                soa.totalOtherAmountOutstanding += row.outstandingAmount;
            }

            if (isLatePaymentCharge && creditNoteAmount > 0) {

                PaymentRowWrapper waiverRow = new PaymentRowWrapper();
                waiverRow.invoiceId = inv.Id;
                waiverRow.invoiceNo = inv.Name;
                waiverRow.dueDateDisplay = formatDate(inv.InvoiceDate__c);
                waiverRow.transactionType = 'Late Payment Waiver';
                waiverRow.amount = creditNoteAmount;
                waiverRow.amountCollected = creditNoteAmount;
                waiverRow.outstandingAmount = 0;
                waiverRow.invoiceStatus = 'Applied';
                waiverRow.allocationRows.addAll(creditNoteAllocationRows);

                soa.otherPaymentRows.add(waiverRow);

                soa.totalOtherAmount += waiverRow.amount;
                soa.totalOtherAmountCollected += waiverRow.amountCollected;
            }
        }

        buildFutureReceiptRowsAsOtherPayments(salesOrderId, soa);

        if (showLPC) {
            lpcInvoicePaidAmount = getPaidLpcInvoiceAmount(salesOrderId);
            invoiceLPCDewAmmount = getLPCDewAmmount(salesOrderId);

            PaymentRowWrapper dynamicLpcRow = getDynamicLpcPaymentRow(soa);

            if (dynamicLpcRow != null) {
                soa.otherPaymentRows.add(dynamicLpcRow);

                soa.totalOtherAmount += dynamicLpcRow.amount;
                soa.totalOtherAmountCollected += dynamicLpcRow.amountCollected;
                soa.totalOtherAmountOutstanding += dynamicLpcRow.outstandingAmount;
            } else {
                if (invoiceLPCDewAmmount > 0) {
                    soa.totalOtherAmountOutstanding += invoiceLPCDewAmmount;
                }
            }
        }

        reorderOtherPaymentRows(soa);
    }

    private void reorderOtherPaymentRows(SOAWrapper soa) {
        List<PaymentRowWrapper> priorityRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> receiptRows = new List<PaymentRowWrapper>();
        List<PaymentRowWrapper> remainingRows = new List<PaymentRowWrapper>();

        for (PaymentRowWrapper row : soa.otherPaymentRows) {
            if (row.transactionType == 'ADM/Dari Fee' || row.transactionType == 'Late Payment Charges') {
                priorityRows.add(row);
            } else if (row.isReceiptRow) {
                receiptRows.add(row);
            } else {
                remainingRows.add(row);
            }
        }

        sortReceiptRowsByStatus(receiptRows);

        soa.otherPaymentRows.clear();
        soa.otherPaymentRows.addAll(priorityRows);
        soa.otherPaymentRows.addAll(remainingRows);
        soa.otherPaymentRows.addAll(receiptRows);
    }

    private void sortReceiptRowsByStatus(List<PaymentRowWrapper> receiptRows) {
        if (receiptRows == null || receiptRows.size() < 2) {
            return;
        }

        List<PaymentRowWrapper> ordered = new List<PaymentRowWrapper>();

        for (String status : new List<String>{ 'Cleared', 'Confirmed', 'In Progress' }) {
            for (PaymentRowWrapper row : receiptRows) {
                if (status.equalsIgnoreCase(row.invoiceStatus)) {
                    ordered.add(row);
                }
            }
        }

        for (PaymentRowWrapper row : receiptRows) {
            if (!ordered.contains(row)) {
                ordered.add(row);
            }
        }

        receiptRows.clear();
        receiptRows.addAll(ordered);
    }

    private static Decimal getPaidLpcInvoiceAmount(Id salesOrderId) {
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
                   InvoiceAmount__c,
                   InvoiceBalance__c
            FROM Invoice__c
            WHERE Sales_Order__c = :salesOrderId
            AND (Charge__r.Name = 'Late Payment Charges') AND InvoiceStatus__c != 'Paid'
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        for (Invoice__c inv : lpcInvoiceList) {
            paidAmount += nvl(inv.InvoiceBalance__c);
        }

        return paidAmount;
    }

    private PaymentRowWrapper getDynamicLpcPaymentRow(SOAWrapper soa) {
        Decimal originalDynamicLpc = soa != null ? nvl(soa.totalLatePayment) : 0;
        Decimal paidLpcAmount = nvl(lpcInvoicePaidAmount);

        Decimal netDynamicLpcAmount = originalDynamicLpc - paidLpcAmount;

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

    private void buildFutureReceiptRowsAsOtherPayments(Id salesOrderId, SOAWrapper soa) {

        List<String> unclearedReceiptStatuses = getUnclearedReceiptStatuses();

        List<Invoice__c> futureInvoiceList = [
            SELECT Id,
                   Name,
                   InvoiceDate__c,
                   InvoiceAmount__c,
                   InvoiceBalance__c,
                   InvoiceStatus__c,
                   Is_ADM_Fees_and_Dari_charges__c,
                   Charge__r.Name,
                   SalesOrderInstallment__c,
                   SalesOrderInstallment__r.MilestoneDate__c,
                   (
                       SELECT Id,
                              AllocationAmount__c,
                              AllocationDate__c,
                              Receipt__c,
                              Receipt__r.Name,
                              Receipt__r.Receipt_Amount__c,
                              Receipt__r.AppliedAmount__c,
                              Receipt__r.Receipt_Excess_Amount__c,
                              Receipt__r.TransactionNumber__c,
                              Receipt__r.Status__c,
                              Receipt__r.EBS_Clearing_Date__c,
                              Receipt__r.ChequeDate__c,
                              Receipt__r.TransactionDate__c,
                              Receipt__r.Modeofpayment__c
                       FROM Allocations__r
                       WHERE Receipt__c != null
                       AND Status__c = 'Applied'
                       AND (
                            Receipt__r.Status__c IN :unclearedReceiptStatuses
                            OR (
                                Receipt__r.Status__c = 'Cleared'
                                AND Receipt__r.Receipt_Excess_Amount__c != 0
                            )
                       )
                   )
            FROM Invoice__c
            WHERE (
                Sales_Order__c = :salesOrderId
                OR SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
            )
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        Set<Id> representedReceiptIds = new Set<Id>();

        for (Invoice__c inv : futureInvoiceList) {
            if (inv.Allocations__r == null || inv.Allocations__r.isEmpty()) {
                continue;
            }

            Date milestoneDate = inv.SalesOrderInstallment__r != null
                ? inv.SalesOrderInstallment__r.MilestoneDate__c
                : null;

            Boolean isCandidate = false;

            if (inv.SalesOrderInstallment__c == null) {
                isCandidate = true;
            }

            if (!isCandidate && milestoneDate != null && milestoneDate >= Date.today()) {
                isCandidate = true;
            }

            if (!isCandidate && milestoneDate != null && milestoneDate < Date.today()) {
                for (Allocation__c alloc : inv.Allocations__r) {
                    if (alloc.Receipt__r == null) {
                        continue;
                    }

                    Decimal receiptAmount = nvl(alloc.Receipt__r.Receipt_Amount__c);
                    Decimal appliedAmount = nvl(alloc.Receipt__r.AppliedAmount__c);

                    if (alloc.Receipt__r.Status__c == 'Cleared' && receiptAmount > appliedAmount) {
                        isCandidate = true;
                        break;
                    }
                }
            }

            if (!isCandidate) {
                continue;
            }

            for (Allocation__c alloc : inv.Allocations__r) {
                if (alloc.Receipt__c == null || representedReceiptIds.contains(alloc.Receipt__c)) {
                    continue;
                }

                representedReceiptIds.add(alloc.Receipt__c);

                PaymentRowWrapper row = new PaymentRowWrapper();
                row.invoiceId = inv.Id;

                Decimal excessAmount = alloc.Receipt__r != null ? nvl(alloc.Receipt__r.Receipt_Excess_Amount__c) : 0;

                Boolean isAdmDariOrLpc =
                    inv.Is_ADM_Fees_and_Dari_charges__c == true ||
                    (inv.Charge__r != null && inv.Charge__r.Name == 'Late Payment Charges');

                if (alloc.Receipt__r != null && alloc.Receipt__r.Status__c == 'Cleared') {
                    row.invoiceStatus = 'Cleared';
                    row.amountCollected = alloc.Receipt__r.Receipt_Excess_Amount__c != null ? 0 : nvl(alloc.AllocationAmount__c);
                    row.outstandingAmount = excessAmount != 0 ? -1 * excessAmount : 0;

                    if (excessAmount != 0) {
                        row.dueDateDisplay = '';
                        row.invoiceNo = '';
                        row.transactionType = String.isNotBlank(alloc.Receipt__r.Modeofpayment__c)
                            ? 'Receipt - ' + alloc.Receipt__r.Modeofpayment__c
                            : 'Receipt';
                    } else {
                        row.dueDateDisplay = formatDate(alloc.Receipt__r.EBS_Clearing_Date__c);
                        row.invoiceNo = alloc.Receipt__r.Name;
                        row.transactionType = 'Receipt';
                    }
                } else {
                    if (excessAmount != 0) {
                        row.dueDateDisplay = '';
                        row.invoiceNo = '';
                        row.transactionType = String.isNotBlank(alloc.Receipt__r.Modeofpayment__c)
                            ? 'Receipt - ' + alloc.Receipt__r.Modeofpayment__c
                            : 'Receipt';
                    } else {
                        Date fallbackDueDate = null;
                        if (alloc.Receipt__r != null) {
                            fallbackDueDate = alloc.Receipt__r.ChequeDate__c != null
                                ? alloc.Receipt__r.ChequeDate__c
                                : (alloc.Receipt__r.TransactionDate__c != null ? alloc.Receipt__r.TransactionDate__c.date() : null);
                        }
                        row.dueDateDisplay = formatDate(fallbackDueDate);
                        row.invoiceNo = 'TBI';
                        row.transactionType = alloc.Receipt__r.Modeofpayment__c != null ? alloc.Receipt__r.Modeofpayment__c : 'PDC';
                    }
                    row.invoiceStatus = alloc.Receipt__r != null ? alloc.Receipt__r.Status__c : '';
                    row.amountCollected = 0;
                    row.outstandingAmount = 0;
                }

                row.amount = alloc.Receipt__r != null ? nvl(alloc.Receipt__r.Receipt_Amount__c) : 0;

                row.allocationRows.add(convertAllocationToWrapper(alloc));

                row.isReceiptRow = true;

                soa.otherPaymentRows.add(row);

                soa.totalOtherAmount += row.amount;
                soa.totalOtherAmountCollected += row.amountCollected;

                if (excessAmount == 0 || isAdmDariOrLpc) {
                    soa.totalOtherAmountOutstanding += row.outstandingAmount;
                } else {
                    soa.excessOutstandingNotInOtherTotal += row.outstandingAmount;
                }
            }
        }

        buildUnallocatedExcessReceiptRows(salesOrderId, soa, representedReceiptIds);
    }

    private void buildUnallocatedExcessReceiptRows(Id salesOrderId, SOAWrapper soa, Set<Id> representedReceiptIds) {
        if (salesOrderId == null) {
            return;
        }

        List<String> unclearedReceiptStatuses = getUnclearedReceiptStatuses();

        List<Receipt__c> unallocatedReceipts = [
            SELECT Id,
                   Name,
                   Status__c,
                   Modeofpayment__c,
                   Receipt_Amount__c,
                   AppliedAmount__c,
                   Receipt_Excess_Amount__c,
                   TransactionNumber__c,
                   EBS_Clearing_Date__c
            FROM Receipt__c
            WHERE SalesOrder__c = :salesOrderId
            AND Id NOT IN :representedReceiptIds
            AND (
                Status__c IN :unclearedReceiptStatuses
                OR (Status__c = 'Cleared' AND Receipt_Excess_Amount__c != 0)
            )
            AND Id NOT IN (
                SELECT Receipt__c
                FROM Allocation__c
                WHERE Receipt__c != null
                AND Status__c = 'Applied'
            )
        ];

        for (Receipt__c rec : unallocatedReceipts) {
            Decimal excessAmount = nvl(rec.Receipt_Excess_Amount__c);
            if (excessAmount == 0) {
                excessAmount = nvl(rec.Receipt_Amount__c) - nvl(rec.AppliedAmount__c);
            }
            if (excessAmount == 0) {
                continue;
            }

            representedReceiptIds.add(rec.Id);

            PaymentRowWrapper row = new PaymentRowWrapper();
            row.invoiceId = null;
            row.dueDateDisplay = '';
            row.invoiceNo = '';
            row.transactionType = String.isNotBlank(rec.Modeofpayment__c)
                ? 'Receipt - ' + rec.Modeofpayment__c
                : 'Receipt';
            row.invoiceStatus = rec.Status__c;
            row.amount = nvl(rec.Receipt_Amount__c);
            row.amountCollected = 0;
            row.outstandingAmount = -1 * excessAmount;
            row.isReceiptRow = true;

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
            row.allocationRows.add(allocRow);

            soa.otherPaymentRows.add(row);

            soa.totalOtherAmount += row.amount;
            soa.totalOtherAmountCollected += row.amountCollected;
            soa.excessOutstandingNotInOtherTotal += row.outstandingAmount;
        }
    }

    // Receipt statuses that are considered "not Cleared" for the SOA. Sourced
    // from the custom label SOA_Receipt_Statuses (comma separated).
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

    // Total amount of Receipts linked to the Sales Order that are not in a
    // Cleared status (i.e. still In Progress / Confirmed per SOA_Receipt_Statuses).
    private Decimal calculateUnclearedReceiptsAmount(Id salesOrderId) {
        if (salesOrderId == null) {
            return 0;
        }

        List<String> unclearedReceiptStatuses = getUnclearedReceiptStatuses();
        if (unclearedReceiptStatuses.isEmpty()) {
            return 0;
        }

        Decimal total = 0;

        for (Receipt__c rec : [
            SELECT Receipt_Amount__c
            FROM Receipt__c
            WHERE SalesOrder__c = :salesOrderId
            AND Status__c IN :unclearedReceiptStatuses
        ]) {
            total += nvl(rec.Receipt_Amount__c);
        }

        return total;
    }

    private void buildGrandTotals(SOAWrapper soa) {
        soa.grandTotalOutstanding =
            soa.totalAmountOutstanding +
            soa.totalOtherAmountOutstanding +
            soa.excessOutstandingNotInOtherTotal;
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
            ORDER BY CreatedDate ASC
        ];

        Set<String> seenNames = new Set<String>();
        List<String> names = new List<String>();

        for (JointOwner__c jo : joList) {
            if (jo.JointOwnerAccount__r == null || String.isBlank(jo.JointOwnerAccount__r.Name)) {
                continue;
            }

            String nameValue = jo.JointOwnerAccount__r.Name.trim();

            if (seenNames.add(nameValue)) {
                names.add(nameValue);
            }
        }

        return String.join(names, ', ');
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
        PageReference pdfPage = Page.CustomerSOA;
        pdfPage.getParameters().put('id', customerAccountId);

        Blob pdfBlob;

        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        } else {
            pdfBlob = Blob.valueOf('Dummy Customer SOA PDF content');
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Customer_Statement_of_Account';
        cv.PathOnClient = 'CustomerStatementOfAccount.pdf';
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

    public class CustomerSOAWrapper {
        public Id customerId { get; set; }
        public String customerName { get; set; }
        public Date todayDate { get; set; }

        public List<SOAWrapper> salesOrderSOAs { get; set; }

        public Decimal totalSalesValue { get; set; }
        public Decimal collectionPercentage { get; set; }
        public Decimal totalSummaryOutstanding { get; set; }

        public Decimal totalAmount { get; set; }
        public Decimal totalAmountCollected { get; set; }
        public Decimal totalLatePayment { get; set; }
        public Decimal totalAmountOutstanding { get; set; }

        public Decimal totalOtherAmount { get; set; }
        public Decimal totalOtherAmountCollected { get; set; }
        public Decimal totalOtherAmountOutstanding { get; set; }
        public Decimal excessOutstandingNotInOtherTotal { get; set; }

        public Decimal totalUnclearedReceiptsAmount { get; set; }
        public Decimal grandTotalOutstanding { get; set; }

        public CustomerSOAWrapper() {
            salesOrderSOAs = new List<SOAWrapper>();

            totalSalesValue = 0;
            collectionPercentage = 0;
            totalSummaryOutstanding = 0;

            totalAmount = 0;
            totalAmountCollected = 0;
            totalLatePayment = 0;
            totalAmountOutstanding = 0;

            totalOtherAmount = 0;
            totalOtherAmountCollected = 0;
            totalOtherAmountOutstanding = 0;
            excessOutstandingNotInOtherTotal = 0;

            totalUnclearedReceiptsAmount = 0;
            grandTotalOutstanding = 0;
        }
    }

    public class SOAWrapper {
        public Id salesOrderId { get; set; }
        public String salesOrderName { get; set; }
        public Boolean isLast { get; set; }
        public Date todayDate { get; set; }

        public String customerName { get; set; }
        public String jointOwnerNames { get; set; }
        public String projectName { get; set; }
        public Date spaDate { get; set; }

        public String unitType { get; set; }
        public String unitName { get; set; }
        public Decimal price { get; set; }
        public String admDistrict { get; set; }
        public String admPlotNo { get; set; }

        public String escrowAccountName { get; set; }
        public String escrowBankName { get; set; }
        public String virtualAccountNumber { get; set; }
        public String virtualIbanNumber { get; set; }
        public String swiftCode { get; set; }

        public Decimal collectionPercentage { get; set; }
        public Decimal summaryOutstanding { get; set; }

        public List<PaymentRowWrapper> paymentRows { get; set; }
        public List<PaymentRowWrapper> otherPaymentRows { get; set; }

        public Decimal totalAmount { get; set; }
        public Decimal totalAmountCollected { get; set; }
        public Decimal totalLatePayment { get; set; }
        public Decimal dynamicLatePaymentOutstanding { get; set; }
        public Decimal totalAmountOutstanding { get; set; }

        public Decimal totalOtherAmount { get; set; }
        public Decimal totalOtherAmountCollected { get; set; }
        public Decimal totalOtherAmountOutstanding { get; set; }
        public Decimal excessOutstandingNotInOtherTotal { get; set; }

        public Decimal unclearedReceiptsAmount { get; set; }
        public Decimal grandTotalOutstanding { get; set; }

        public SOAWrapper() {
            isLast = false;

            paymentRows = new List<PaymentRowWrapper>();
            otherPaymentRows = new List<PaymentRowWrapper>();

            collectionPercentage = 0;
            summaryOutstanding = 0;

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
            grandTotalOutstanding = 0;
        }
    }

    public class PaymentRowWrapper {
        public Id invoiceId { get; set; }
        public Id installmentId { get; set; }

        public Date dueDate { get; set; }
        public String dueDateDisplay { get; set; }

        public Decimal installmentNumber { get; set; }
        public String installmentNumberDisplay { get; set; }

        public String invoiceNo { get; set; }

        public Decimal milestonePercent { get; set; }
        public String milestonePercentDisplay { get; set; }

        public Decimal amount { get; set; }
        public String transactionType { get; set; }
        public String invoiceStatus { get; set; }

        public Decimal amountCollected { get; set; }
        public Decimal lpcAmount { get; set; }
        public Decimal outstandingAmount { get; set; }

        public Date milestoneDate { get; set; }

        public List<AllocationRowWrapper> allocationRows { get; set; }

        public Boolean isAltRow { get; set; }

        // TRUE for Other Payments rows that represent a Receipt (used to group
        // them by receipt status: Cleared -> Confirmed -> In Progress).
        public Boolean isReceiptRow { get; set; }

        public PaymentRowWrapper() {
            amount = 0;
            amountCollected = 0;
            lpcAmount = 0;
            outstandingAmount = 0;
            isAltRow = false;
            isReceiptRow = false;
            allocationRows = new List<AllocationRowWrapper>();
        }
    }

    public class AllocationRowWrapper {
        public Id allocationId { get; set; }
        public Id receiptId { get; set; }

        public Decimal allocationAmount { get; set; }

        public Date allocationDate { get; set; }
        public String allocationDateDisplay { get; set; }

        public String allocationStatus { get; set; }

        public String receiptName { get; set; }
        public String receiptStatus { get; set; }
        public String transactionNumber { get; set; }

        public Date ebsClearingDate { get; set; }
        public String ebsClearingDateDisplay { get; set; }

        public AllocationRowWrapper() {
            allocationAmount = 0;
        }
    }
}