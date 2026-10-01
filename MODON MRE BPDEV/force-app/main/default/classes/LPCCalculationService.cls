public with sharing class LPCCalculationService {

    // Public so LpcAnalysisViewerController uses the exact same LPC rule
    // (12% per year / 365 days, 30 grace days) as the Statement of Account.
    public static final Decimal LPC_ANNUAL_RATE = 0.12;
    public static final Integer LPC_DAYS_PER_YEAR = 365;
    public static final Integer GRACE_DAYS = 30;

    public class LPCResult {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public Decimal totalLPC = 0;
        @AuraEnabled public List<InstallmentLPCResult> installmentResults = new List<InstallmentLPCResult>();
    }

    public class InstallmentLPCResult {
        @AuraEnabled public Id installmentId;
        @AuraEnabled public String installmentName;
        @AuraEnabled public String milestoneDisplay; // MilestoneNumber__c (Milestone__c%)
        @AuraEnabled public String invoiceStatus;

        @AuraEnabled public Id invoiceId;
        @AuraEnabled public Decimal invoiceAmount = 0;
        @AuraEnabled public Decimal lpcAmount = 0;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public List<String> logs = new List<String>();
    }

    public class PaymentEvent implements Comparable {
        public Date paidDate;
        public Decimal amount;

        public PaymentEvent(Date paidDate, Decimal amount) {
            this.paidDate = paidDate;
            this.amount = amount;
        }

        public Integer compareTo(Object obj) {
            PaymentEvent other = (PaymentEvent)obj;

            if (this.paidDate == other.paidDate) {
                return 0;
            }

            return this.paidDate < other.paidDate ? -1 : 1;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static LPCResult getLPCAnalysisForLWC(Id salesOrderId) {
        return calculateLPCBySalesOrder(salesOrderId);
    }

    public static Decimal getLPCBySalesOrder(String salesOrderId) {
        if (String.isBlank(salesOrderId)) {
            return 0;
        }

        LPCResult result = calculateLPCBySalesOrder((Id)salesOrderId);
        return result.totalLPC;
    }
    
    public static Decimal getPaidLpcInvoiceAmount(Id salesOrderId) {
       return NewStatementOfAccountController.getPaidLpcInvoiceAmount(salesOrderId);       
    }


    public static LPCResult calculateLPCBySalesOrder(Id salesOrderId) {
        Map<Id, LPCResult> resultMap =
            calculateLPCBySalesOrders(new Set<Id>{ salesOrderId });

        return resultMap.containsKey(salesOrderId)
            ? resultMap.get(salesOrderId)
            : new LPCResult();
    }

    public static Map<Id, LPCResult> calculateLPCBySalesOrders(Set<Id> salesOrderIds) {

        Map<Id, LPCResult> finalResultMap = new Map<Id, LPCResult>();

        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            return finalResultMap;
        }

        for (Id soId : salesOrderIds) {
            LPCResult res = new LPCResult();
            res.salesOrderId = soId;
            finalResultMap.put(soId, res);
        }

        List<SalesOrderInstallments__c> installments = [
            SELECT Id,
                   Name,
                   SalesOrder__c,
                   MilestoneDate__c,
                   ExtensionDate__c,
                   RFO_Date__c,
                   LPC_Freeze_Start_Date__c,
                   LPC_Freeze_End_Date__c,
                   MilestoneNumber__c,
                   Milestone__c,
                   PaymentStatus__c,
                   SalesOrder__r.Unit__r.Name,
                   Exclude_LPC__c,
                   SalesOrder__r.Unit__r.Project_Name__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :salesOrderIds
            AND (
                MilestoneDate__c <= TODAY
                OR ExtensionDate__c <= TODAY
                OR RFO_Date__c <= TODAY
            )
              ORDER BY
              SalesOrder__c ASC,
              MilestoneNumber__c ASC,
              MilestoneDate__c ASC,
              CreatedDate ASC
            ];

        if (installments.isEmpty()) {
            System.debug('No eligible installments found for Sales Orders: ' + salesOrderIds);
            return finalResultMap;
        }

        Map<Id, SalesOrderInstallments__c> installmentMap =
            new Map<Id, SalesOrderInstallments__c>(installments);

        List<Invoice__c> invoices = [
            SELECT Id,
                   SalesOrderInstallment__c,
                   InvoiceAmount__c,
                   InvoiceBalance__c,
                   AppliedAmount__c,
                   TotalPaidAmount__c,
                   InvoiceStatus__c,
                   InvoiceDate__c,
                   CreatedDate
            FROM Invoice__c
            WHERE SalesOrderInstallment__c IN :installmentMap.keySet() 
            ORDER BY SalesOrderInstallment__c, CreatedDate DESC
        ];

        Map<Id, Invoice__c> latestInvoiceByInstallment = new Map<Id, Invoice__c>();

        for (Invoice__c inv : invoices) {
            if (!latestInvoiceByInstallment.containsKey(inv.SalesOrderInstallment__c)) {
                latestInvoiceByInstallment.put(inv.SalesOrderInstallment__c, inv);
            }
        }

        Set<Id> invoiceIds = new Set<Id>();

        for (Invoice__c inv : latestInvoiceByInstallment.values()) {
            invoiceIds.add(inv.Id);
        }

        Map<Id, List<Allocation__c>> allocationMap = new Map<Id, List<Allocation__c>>();

        if (!invoiceIds.isEmpty()) {
            for (Allocation__c alloc : [
                SELECT Id,
                       Invoice__c,
                       Receipt__c,
                       Status__c,
                       AllocationAmount__c,
                       Receipt__r.Status__c,
                       Receipt__r.EBS_Clearing_Date__c,
                       Receipt__r.TransactionDate__c
                FROM Allocation__c
                WHERE Invoice__c IN :invoiceIds
                AND Status__c = 'Applied'
            ]) {
                if (!allocationMap.containsKey(alloc.Invoice__c)) {
                    allocationMap.put(alloc.Invoice__c, new List<Allocation__c>());
                }

                allocationMap.get(alloc.Invoice__c).add(alloc);
            }
        }

        for (SalesOrderInstallments__c inst : installments) {
            
            if (inst.Exclude_LPC__c == true) {
        InstallmentLPCResult excludedResult = new InstallmentLPCResult();

        excludedResult.installmentId = inst.Id;
        excludedResult.installmentName = inst.Name;
        excludedResult.milestoneDisplay =
            String.valueOf(inst.MilestoneNumber__c) +
            ' (' +
            String.valueOf(inst.Milestone__c) +
            '%)';

        excludedResult.lpcAmount = 0;
        excludedResult.logs.add(
            'Skipped: LPC calculation is excluded for this installment.'
        );

        finalResultMap
            .get(inst.SalesOrder__c)
            .installmentResults
            .add(excludedResult);

        continue;
    }
            

            Invoice__c inv = latestInvoiceByInstallment.get(inst.Id);

            if (inv == null) {
                InstallmentLPCResult noInvoiceResult = new InstallmentLPCResult();

                noInvoiceResult.installmentId = inst.Id;
                noInvoiceResult.installmentName = inst.Name;
                noInvoiceResult.milestoneDisplay =
                    String.valueOf(inst.MilestoneNumber__c) +
                    ' (' +
                    String.valueOf(inst.Milestone__c) +
                    '%)';
                noInvoiceResult.logs.add('Skipped: No invoice found for this installment.');

                finalResultMap.get(inst.SalesOrder__c).installmentResults.add(noInvoiceResult);
                continue;
            }

            List<Allocation__c> allocList = allocationMap.containsKey(inv.Id)
                ? allocationMap.get(inv.Id)
                : new List<Allocation__c>();

            InstallmentLPCResult instResult = getLPCByInstallment(
                inst,
                inv,
                allocList,
                Date.today()
            );

            LPCResult soResult = finalResultMap.get(inst.SalesOrder__c);

            soResult.totalLPC += instResult.lpcAmount;
            soResult.installmentResults.add(instResult);

            System.debug('SO LPC Result After Installment => ' + JSON.serializePretty(soResult));
        }

        System.debug('Final LPC Result Map => ' + JSON.serializePretty(finalResultMap));

        return finalResultMap;
    }

    public static InstallmentLPCResult getLPCByInstallment(
        SalesOrderInstallments__c installment,
        Invoice__c invoiceRec,
        List<Allocation__c> allocations,
        Date calculationDate
    ) {
        InstallmentLPCResult result = new InstallmentLPCResult();

        result.installmentId = installment.Id;
        result.installmentName = installment.Name;

        result.milestoneDisplay =
            String.valueOf(installment.MilestoneNumber__c) +
            ' (' +
            String.valueOf(installment.Milestone__c) +
            '%)';

        result.invoiceStatus = invoiceRec.InvoiceStatus__c;
        result.invoiceId = invoiceRec.Id;

        result.invoiceAmount = invoiceRec.InvoiceAmount__c == null
            ? 0
            : invoiceRec.InvoiceAmount__c;
        
        if (installment.Exclude_LPC__c == true) {
            result.lpcAmount = 0;
            result.logs.add(
                'Skipped: Exclude LPC is enabled for this installment.'
            );
        
            return result;
        }

        if (calculationDate == null) {
            calculationDate = Date.today();
        }

        result.startDate = getLPCStartDate(installment);

        result.endDate = calculationDate;

        result.logs.add(
            'Started LPC calculation. Installment = ' + result.installmentName +
            ', Milestone = ' + result.milestoneDisplay +
            ', Invoice Status = ' + result.invoiceStatus +
            ', Invoice Amount = ' + result.invoiceAmount +
            ', Start Date = ' + result.startDate +
            ', Freeze Start Date = ' + installment.LPC_Freeze_Start_Date__c +
            ', Freeze End Date = ' + installment.LPC_Freeze_End_Date__c +
            ', Calculation Date = ' + calculationDate
        );

        if (result.startDate == null || result.invoiceAmount <= 0) {
            result.logs.add('Skipped: Start date or invoice amount missing.');
            System.debug('LPC Installment Result => ' + JSON.serializePretty(result));
            return result;
        }

        Date freezeStartDate = getValidFreezeStartDate(installment);
        Date freezeEndDate = getValidFreezeEndDate(installment);

        if (freezeStartDate != null && freezeEndDate != null) {
            result.logs.add(
                'LPC freeze period applied. Freeze Start Date = ' + freezeStartDate +
                ', Freeze End Date = ' + freezeEndDate +
                '. LPC will not be calculated for this period, but cleared payments within the freeze period will still reduce outstanding.'
            );
        } else if (installment.LPC_Freeze_Start_Date__c != null || installment.LPC_Freeze_End_Date__c != null) {
            result.logs.add(
                'LPC freeze period ignored because both start and end dates are required, and end date must be greater than or equal to start date.'
            );
        }

        List<PaymentEvent> paymentEvents = new List<PaymentEvent>();

        if (allocations != null && !allocations.isEmpty()) {
            for (Allocation__c alloc : allocations) {

                if (alloc.AllocationAmount__c == null || alloc.AllocationAmount__c <= 0) {
                    result.logs.add('Ignored allocation ' + alloc.Id + ' because allocation amount is blank or zero.');
                    continue;
                }

                if (alloc.Receipt__r == null || alloc.Receipt__r.EBS_Clearing_Date__c == null) {
                    result.logs.add(
                        'Ignored allocation ' + alloc.Id +
                        ' because EBS Clearing Date is blank.'
                    );
                    continue;
                }

                paymentEvents.add(
                    new PaymentEvent(
                        alloc.Receipt__r.EBS_Clearing_Date__c,
                        alloc.AllocationAmount__c
                    )
                );

                result.logs.add(
                    'Payment considered. Allocation = ' + alloc.Id +
                    ', Clearing Date = ' + alloc.Receipt__r.EBS_Clearing_Date__c +
                    ', Amount = ' + alloc.AllocationAmount__c
                );
            }
        } else {
            result.logs.add('No applied allocations found for this invoice.');
        }

        paymentEvents.sort();

        Date graceDate = result.startDate.addDays(GRACE_DAYS);
        Decimal totalPaidWithinGrace = 0;

        for (PaymentEvent pe : paymentEvents) {
            if (pe.paidDate <= graceDate) {
                totalPaidWithinGrace += pe.amount;
            }
        }

        result.logs.add(
            'Grace Date = ' + graceDate +
            ', Total Paid Within Grace = ' + totalPaidWithinGrace
        );

        if (totalPaidWithinGrace >= result.invoiceAmount) {
            result.logs.add('No LPC: Fully paid within grace period.');
            System.debug('LPC Installment Result => ' + JSON.serializePretty(result));
            return result;
        }

        Decimal outstandingAmount = result.invoiceAmount;
        Date bracketStartDate = result.startDate;

        for (PaymentEvent pe : paymentEvents) {

            if (pe.paidDate < result.startDate) {
                outstandingAmount -= pe.amount;

                if (outstandingAmount < 0) {
                    outstandingAmount = 0;
                }

                result.logs.add(
                    'Payment before start date adjusted. Paid Date = ' + pe.paidDate +
                    ', Amount = ' + pe.amount +
                    ', Remaining Outstanding = ' + outstandingAmount
                );

                continue;
            }

            if (outstandingAmount <= 0) {
                result.logs.add('Outstanding amount became zero. Stopping LPC calculation.');
                break;
            }

            Date bracketEndDate = pe.paidDate.addDays(-1);

            if (bracketEndDate >= bracketStartDate) {
                Decimal bracketLPC = calculateLPCAmountExcludingFreeze(
                    outstandingAmount,
                    bracketStartDate,
                    bracketEndDate,
                    freezeStartDate,
                    freezeEndDate,
                    result.logs
                );

                result.lpcAmount += bracketLPC;

                result.logs.add(
                    'LPC calculated from ' + bracketStartDate +
                    ' to ' + bracketEndDate +
                    ', Days = ' + getDaysInclusive(bracketStartDate, bracketEndDate) +
                    ', Outstanding = ' + outstandingAmount +
                    ', LPC = ' + bracketLPC
                );
            }

            outstandingAmount -= pe.amount;

            if (outstandingAmount < 0) {
                outstandingAmount = 0;
            }

            result.logs.add(
                'Payment applied after LPC bracket. Paid Date = ' + pe.paidDate +
                ', Amount = ' + pe.amount +
                ', Remaining Outstanding = ' + outstandingAmount
            );

            bracketStartDate = pe.paidDate;
        }

        if (outstandingAmount > 0 && bracketStartDate <= calculationDate) {
            Decimal pendingLPC = calculateLPCAmountExcludingFreeze(
                outstandingAmount,
                bracketStartDate,
                calculationDate,
                freezeStartDate,
                freezeEndDate,
                result.logs
            );

            result.lpcAmount += pendingLPC;

            result.logs.add(
                'Pending LPC calculated from ' + bracketStartDate +
                ' to ' + calculationDate +
                ', Days = ' + getDaysInclusive(bracketStartDate, calculationDate) +
                ', Outstanding = ' + outstandingAmount +
                ', LPC = ' + pendingLPC
            );
        } else {
            result.logs.add(
                'No pending LPC block. Outstanding = ' + outstandingAmount +
                ', Bracket Start Date = ' + bracketStartDate +
                ', Calculation Date = ' + calculationDate
            );
        }

        result.lpcAmount = result.lpcAmount.setScale(2);

        result.logs.add(
            'Completed LPC calculation. Final LPC Amount = ' + result.lpcAmount
        );

        System.debug('LPC Installment Result => ' + JSON.serializePretty(result));

        return result;
    }

    private static Date getLPCStartDate(SalesOrderInstallments__c installment) {
        if (installment == null) {
            return null;
        }

        /*
         * LPC start date priority:
         * 1. RFO Date
         * 2. Extension Date
         * 3. Milestone Date
         */
        if (installment.RFO_Date__c != null) {
            return installment.RFO_Date__c;
        }

        if (installment.ExtensionDate__c != null) {
            return installment.ExtensionDate__c;
        }

        return installment.MilestoneDate__c;
    }

    private static Date getValidFreezeStartDate(SalesOrderInstallments__c installment) {
        if (
            installment == null ||
            installment.LPC_Freeze_Start_Date__c == null ||
            installment.LPC_Freeze_End_Date__c == null ||
            installment.LPC_Freeze_End_Date__c < installment.LPC_Freeze_Start_Date__c
        ) {
            return null;
        }

        return installment.LPC_Freeze_Start_Date__c;
    }

    private static Date getValidFreezeEndDate(SalesOrderInstallments__c installment) {
        if (
            installment == null ||
            installment.LPC_Freeze_Start_Date__c == null ||
            installment.LPC_Freeze_End_Date__c == null ||
            installment.LPC_Freeze_End_Date__c < installment.LPC_Freeze_Start_Date__c
        ) {
            return null;
        }

        return installment.LPC_Freeze_End_Date__c;
    }

    private static Decimal calculateLPCAmountExcludingFreeze(
        Decimal outstandingAmount,
        Date fromDate,
        Date toDate,
        Date freezeStartDate,
        Date freezeEndDate,
        List<String> logs
    ) {
        if (fromDate == null || toDate == null || toDate < fromDate) {
            return 0;
        }

        if (outstandingAmount == null || outstandingAmount <= 0) {
            return 0;
        }

        if (freezeStartDate == null || freezeEndDate == null) {
            return calculateLPCAmount(outstandingAmount, fromDate, toDate);
        }

        if (freezeEndDate < fromDate || freezeStartDate > toDate) {
            return calculateLPCAmount(outstandingAmount, fromDate, toDate);
        }

        Decimal totalLPC = 0;

        Date beforeFreezeEndDate = freezeStartDate.addDays(-1);

        if (fromDate <= beforeFreezeEndDate) {
            Date segmentEndDate = beforeFreezeEndDate < toDate ? beforeFreezeEndDate : toDate;

            Decimal beforeFreezeLPC = calculateLPCAmount(
                outstandingAmount,
                fromDate,
                segmentEndDate
            );

            totalLPC += beforeFreezeLPC;

            if (logs != null) {
                logs.add(
                    'LPC calculated before freeze from ' + fromDate +
                    ' to ' + segmentEndDate +
                    ', Days = ' + getDaysInclusive(fromDate, segmentEndDate) +
                    ', Outstanding = ' + outstandingAmount +
                    ', LPC = ' + beforeFreezeLPC
                );
            }
        }

        Date excludedStartDate = fromDate > freezeStartDate ? fromDate : freezeStartDate;
        Date excludedEndDate = toDate < freezeEndDate ? toDate : freezeEndDate;

        if (excludedStartDate <= excludedEndDate && logs != null) {
            logs.add(
                'LPC freeze excluded from ' + excludedStartDate +
                ' to ' + excludedEndDate +
                ', Days Excluded = ' + getDaysInclusive(excludedStartDate, excludedEndDate)
            );
        }

        Date afterFreezeStartDate = freezeEndDate.addDays(1);

        if (afterFreezeStartDate <= toDate) {
            Date segmentStartDate = afterFreezeStartDate > fromDate ? afterFreezeStartDate : fromDate;

            Decimal afterFreezeLPC = calculateLPCAmount(
                outstandingAmount,
                segmentStartDate,
                toDate
            );

            totalLPC += afterFreezeLPC;

            if (logs != null) {
                logs.add(
                    'LPC calculated after freeze from ' + segmentStartDate +
                    ' to ' + toDate +
                    ', Days = ' + getDaysInclusive(segmentStartDate, toDate) +
                    ', Outstanding = ' + outstandingAmount +
                    ', LPC = ' + afterFreezeLPC
                );
            }
        }

        return totalLPC.setScale(2);
    }

    private static Decimal calculateLPCAmount(
        Decimal outstandingAmount,
        Date fromDate,
        Date toDate
    ) {
        Integer days = getDaysInclusive(fromDate, toDate);

        if (days <= 0 || outstandingAmount == null || outstandingAmount <= 0) {
            return 0;
        }

       Decimal lpcAmount =
        outstandingAmount *
        LPC_ANNUAL_RATE *
        days /
        LPC_DAYS_PER_YEAR;

        return lpcAmount.setScale(2);
    }

    private static Integer getDaysInclusive(Date fromDate, Date toDate) {
        if (fromDate == null || toDate == null || toDate < fromDate) {
            return 0;
        }

        return fromDate.daysBetween(toDate) + 1;
    }
}