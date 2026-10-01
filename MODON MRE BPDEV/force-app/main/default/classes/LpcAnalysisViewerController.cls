/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : LPC Process                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     22-07-2026      Initial Draft    
**********************************************************************************************************************/
public with sharing class LpcAnalysisViewerController {

    // Taken from LPCCalculationService (used by the SOA) so the analyser
    // always shows the same LPC as the Statement of Account.
    private static final Decimal LPC_ANNUAL_RATE = LPCCalculationService.LPC_ANNUAL_RATE;
    private static final Integer LPC_DAYS_PER_YEAR = LPCCalculationService.LPC_DAYS_PER_YEAR;
    private static final Integer GRACE_DAYS = LPCCalculationService.GRACE_DAYS;

    @AuraEnabled(cacheable=false)
    public static LpcAnalysisResponse getLpcAnalysis(Id salesOrderId) {

        if (salesOrderId == null) {
            throw new AuraHandledException('Sales Order Id is required.');
        }

        LpcAnalysisResponse response = new LpcAnalysisResponse();

        SalesOrder__c so = [
            SELECT Id,
                   Name,
                   Unit__r.Name,
                   Unit__r.Project_Name__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        response.salesOrderId = so.Id;
        response.salesOrderName = so.Name;
        response.unitName = so.Unit__r != null ? so.Unit__r.Name : null;
        response.projectName = so.Unit__r != null ? so.Unit__r.Project_Name__c : null;

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
                   Exclude_LPC__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :salesOrderId
            AND (
                MilestoneDate__c <= TODAY
                OR ExtensionDate__c <= TODAY
                OR RFO_Date__c <= TODAY
            )
            ORDER BY MilestoneNumber__c ASC NULLS LAST,
                     MilestoneDate__c ASC NULLS LAST,
                     CreatedDate ASC
        ];

        if (installments.isEmpty()) {
            return response;
        }

        Map<Id, SalesOrderInstallments__c> installmentMap =
            new Map<Id, SalesOrderInstallments__c>(installments);

        List<Invoice__c> invoices = [
            SELECT Id,
                   Name,
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
            ORDER BY SalesOrderInstallment__c ASC, CreatedDate DESC
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
                       Name,
                       Invoice__c,
                       Receipt__c,
                       Status__c,
                       AllocationAmount__c,
                       Receipt__r.Name,
                       Receipt__r.Status__c,
                       Receipt__r.EBS_Clearing_Date__c,
                       Receipt__r.TransactionDate__c
                FROM Allocation__c
                WHERE Invoice__c IN :invoiceIds
                ORDER BY CreatedDate ASC
            ]) {
                if (!allocationMap.containsKey(alloc.Invoice__c)) {
                    allocationMap.put(alloc.Invoice__c, new List<Allocation__c>());
                }

                allocationMap.get(alloc.Invoice__c).add(alloc);
            }
        }
        
        List<Business_Process__c> waiverProcesses = [
        SELECT Id,
               Name,
               Type__c,
               Sales_Order__c,
               LPC_Waived_Amount__c,
               Waiver_Percentage__c,
               LPC_Amount__c,
               LPCWaivedAmount__c,
               Status__c
        FROM Business_Process__c
        WHERE Type__c = 'Late Payment Charge Waiver'
        AND Sales_Order__c = :salesOrderId
        AND Status__c IN ('In Progress', 'Completed')
        ORDER BY CreatedDate DESC
    ];

        for (Business_Process__c bp : waiverProcesses) {
            LpcWaiverProcessWrapper wp = new LpcWaiverProcessWrapper();
            wp.businessProcessId = bp.Id;
            wp.name = bp.Name;
            wp.lpcCollectedAmount = nvl(bp.LPC_Waived_Amount__c);
            wp.waiverPercentage = nvl(bp.Waiver_Percentage__c);
            wp.lpcAmount = nvl(bp.LPC_Amount__c);
            wp.lpcWaiverAmount = nvl(bp.LPCWaivedAmount__c);
            wp.status = bp.Status__c;
        
            response.waiverProcesses.add(wp);
        }

        for (SalesOrderInstallments__c inst : installments) {

            Invoice__c inv = latestInvoiceByInstallment.get(inst.Id);

            InstallmentAnalysisWrapper iw = new InstallmentAnalysisWrapper();
            iw.installmentId = inst.Id;
            iw.installmentName = inst.Name;
            iw.milestoneNumber = inst.MilestoneNumber__c;
            iw.milestonePercent = inst.Milestone__c;
            iw.milestoneDisplay = String.valueOf(inst.MilestoneNumber__c) +
                ' (' + String.valueOf(inst.Milestone__c) + '%)';
            iw.milestoneDate = inst.MilestoneDate__c;
            iw.extensionDate = inst.ExtensionDate__c;
            iw.rfoDate = inst.RFO_Date__c;
            iw.lpcFreezeStartDate = inst.LPC_Freeze_Start_Date__c;
            iw.lpcFreezeEndDate = inst.LPC_Freeze_End_Date__c;
            iw.lpcStartBaseDate = getLPCStartDate(inst);
            iw.isLpcExcluded = inst.Exclude_LPC__c == true;

            // Same rule as LPCCalculationService (used by the SOA): an installment
            // flagged Exclude LPC carries no LPC. Invoice details are still shown
            // for reference, but no brackets are calculated and it adds nothing
            // to Total LPC.
            if (iw.isLpcExcluded) {
                if (inv != null) {
                    populateInvoiceDetails(iw, inv);
                }

                iw.lpcAmount = 0;
                iw.reason = 'Skipped: Exclude LPC is enabled for this installment.';
                iw.logs.add(iw.reason);
                response.installments.add(iw);
                continue;
            }

            if (inv == null) {
                iw.reason = 'Skipped: No invoice found for this installment.';
                iw.logs.add(iw.reason);
                response.installments.add(iw);
                continue;
            }

            populateInvoiceDetails(iw, inv);

            List<Allocation__c> allocList = allocationMap.containsKey(inv.Id)
                ? allocationMap.get(inv.Id)
                : new List<Allocation__c>();

            calculateInstallmentAnalysis(iw, allocList, Date.today());

            response.totalLpc += iw.lpcAmount;
            response.installments.add(iw);
        }

        response.totalLpc = response.totalLpc.setScale(2);
        return response;
    }

    private static void populateInvoiceDetails(InstallmentAnalysisWrapper iw, Invoice__c inv) {
        iw.invoiceId = inv.Id;
        iw.invoiceName = inv.Name;
        iw.invoiceAmount = nvl(inv.InvoiceAmount__c);
        iw.balanceAmount = nvl(inv.InvoiceBalance__c);
        iw.appliedAmount = nvl(inv.AppliedAmount__c);
        iw.totalPaidAmount = nvl(inv.TotalPaidAmount__c);
        iw.invoiceStatus = inv.InvoiceStatus__c;
        iw.invoiceDate = inv.InvoiceDate__c;
    }

    private static void calculateInstallmentAnalysis(
        InstallmentAnalysisWrapper result,
        List<Allocation__c> allocations,
        Date calculationDate
    ) {
        if (calculationDate == null) {
            calculationDate = Date.today();
        }

        result.calculationDate = calculationDate;

        result.logs.add(
            'Started LPC calculation. Installment = ' + result.installmentName +
            ', Milestone = ' + result.milestoneDisplay +
            ', Invoice Status = ' + result.invoiceStatus +
            ', Invoice Amount = ' + result.invoiceAmount +
            ', LPC Start Date = ' + result.lpcStartBaseDate +
            ', Milestone Date = ' + result.milestoneDate +
            ', Extension Date = ' + result.extensionDate +
            ', RFO Date = ' + result.rfoDate +
            ', Freeze Start Date = ' + result.lpcFreezeStartDate +
            ', Freeze End Date = ' + result.lpcFreezeEndDate +
            ', Calculation Date = ' + calculationDate
        );

        if (result.lpcStartBaseDate == null || result.invoiceAmount <= 0) {
            result.reason = 'Skipped: Start date or invoice amount missing.';
            result.logs.add(result.reason);
            return;
        }

        List<PaymentEvent> paymentEvents = new List<PaymentEvent>();

        Integer allocationIndex = 1;

        if (allocations != null && !allocations.isEmpty()) {
            for (Allocation__c alloc : allocations) {

                AllocationWrapper aw = new AllocationWrapper();
                aw.sequence = 'Allocation ' + allocationIndex;
                aw.allocationId = alloc.Id;
                aw.allocationName = alloc.Name;
                aw.appliedAmount = nvl(alloc.AllocationAmount__c);
                aw.allocationStatus = alloc.Status__c;
                aw.receiptName = alloc.Receipt__r != null ? alloc.Receipt__r.Name : null;
                aw.receiptStatus = alloc.Receipt__r != null ? alloc.Receipt__r.Status__c : null;
                aw.ebsClearedDate = alloc.Receipt__r != null ? alloc.Receipt__r.EBS_Clearing_Date__c : null;
                aw.transactionDate = alloc.Receipt__r != null ? alloc.Receipt__r.TransactionDate__c : null;

                result.allocations.add(aw);
                allocationIndex++;

                if (alloc.Status__c != 'Applied') {
                    result.logs.add('Ignored allocation ' + alloc.Id + ' because status is not Applied.');
                    continue;
                }

                if (alloc.AllocationAmount__c == null || alloc.AllocationAmount__c <= 0) {
                    result.logs.add('Ignored allocation ' + alloc.Id + ' because allocation amount is blank or zero.');
                    continue;
                }

                if (alloc.Receipt__r == null || alloc.Receipt__r.EBS_Clearing_Date__c == null) {
                    result.logs.add('Ignored allocation ' + alloc.Id + ' because EBS Clearing Date is blank.');
                    continue;
                }

                paymentEvents.add(
                    new PaymentEvent(
                        alloc.Receipt__r.EBS_Clearing_Date__c,
                        alloc.AllocationAmount__c,
                        alloc.Id
                    )
                );

                result.logs.add(
                    'Payment considered. Allocation = ' + alloc.Id +
                    ', Clearing Date = ' + alloc.Receipt__r.EBS_Clearing_Date__c +
                    ', Amount = ' + alloc.AllocationAmount__c
                );
            }
        } else {
            result.logs.add('No allocations found for this invoice.');
        }

        paymentEvents.sort();

        Date graceDate = result.lpcStartBaseDate.addDays(GRACE_DAYS);
        result.graceDate = graceDate;

        Decimal totalPaidWithinGrace = 0;

        for (PaymentEvent pe : paymentEvents) {
            if (pe.paidDate <= graceDate) {
                totalPaidWithinGrace += pe.amount;
            }
        }

        result.paidWithinGrace = totalPaidWithinGrace;

        result.logs.add(
            'Grace Date = ' + graceDate +
            ', Total Paid Within Grace = ' + totalPaidWithinGrace
        );

        if (totalPaidWithinGrace >= result.invoiceAmount) {
            result.reason = 'No LPC: Fully paid within grace period.';
            result.logs.add(result.reason);
            return;
        }

        Decimal outstandingAmount = result.invoiceAmount;
        Date bracketStartDate = result.lpcStartBaseDate;
        Integer bracketIndex = 1;

        for (PaymentEvent pe : paymentEvents) {

            if (pe.paidDate < result.lpcStartBaseDate) {
                outstandingAmount -= pe.amount;

                if (outstandingAmount < 0) {
                    outstandingAmount = 0;
                }

                result.logs.add(
                    'Payment before LPC start date adjusted. Paid Date = ' + pe.paidDate +
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
                bracketIndex = addChargeableAndFreezeBrackets(
                    result,
                    bracketIndex,
                    'Partial Bracket',
                    outstandingAmount,
                    bracketStartDate,
                    bracketEndDate
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
            bracketIndex = addChargeableAndFreezeBrackets(
                result,
                bracketIndex,
                result.brackets.isEmpty() ? 'Full Bracket' : 'Partial Bracket',
                outstandingAmount,
                bracketStartDate,
                calculationDate
            );
        } else {
            result.logs.add(
                'No pending LPC block. Outstanding = ' + outstandingAmount +
                ', Bracket Start Date = ' + bracketStartDate +
                ', Calculation Date = ' + calculationDate
            );
        }

        result.outstandingAfterPayments = outstandingAmount;
        result.lpcAmount = result.lpcAmount.setScale(2);
        result.reason = 'Completed LPC calculation.';
        result.logs.add('Completed LPC calculation. Final LPC Amount = ' + result.lpcAmount);
    }

    private static Integer addChargeableAndFreezeBrackets(
        InstallmentAnalysisWrapper result,
        Integer bracketIndex,
        String bracketType,
        Decimal outstandingAmount,
        Date periodStart,
        Date periodEnd
    ) {
        if (periodStart == null || periodEnd == null || periodEnd < periodStart) {
            return bracketIndex;
        }

        Date freezeStart = result.lpcFreezeStartDate;
        Date freezeEnd = result.lpcFreezeEndDate;

        Boolean hasValidFreeze = freezeStart != null && freezeEnd != null && freezeEnd >= freezeStart;

        if (!hasValidFreeze || periodEnd < freezeStart || periodStart > freezeEnd) {
            BracketWrapper bw = buildBracket(
                bracketIndex,
                bracketType,
                outstandingAmount,
                periodStart,
                periodEnd,
                false
            );

            result.brackets.add(bw);
            result.lpcAmount += bw.lpcAmount;

            result.logs.add(
                'LPC calculated from ' + periodStart +
                ' to ' + periodEnd +
                ', Days = ' + bw.days +
                ', Outstanding = ' + outstandingAmount +
                ', LPC = ' + bw.lpcAmount
            );

            return bracketIndex + 1;
        }

        if (periodStart < freezeStart) {
            Date chargeableEndBeforeFreeze = freezeStart.addDays(-1);

            if (chargeableEndBeforeFreeze >= periodStart) {
                BracketWrapper beforeFreeze = buildBracket(
                    bracketIndex,
                    bracketType,
                    outstandingAmount,
                    periodStart,
                    chargeableEndBeforeFreeze,
                    false
                );

                result.brackets.add(beforeFreeze);
                result.lpcAmount += beforeFreeze.lpcAmount;

                result.logs.add(
                    'LPC calculated before freeze from ' + periodStart +
                    ' to ' + chargeableEndBeforeFreeze +
                    ', Days = ' + beforeFreeze.days +
                    ', Outstanding = ' + outstandingAmount +
                    ', LPC = ' + beforeFreeze.lpcAmount
                );

                bracketIndex++;
            }
        }

        Date overlapStart = periodStart > freezeStart ? periodStart : freezeStart;
        Date overlapEnd = periodEnd < freezeEnd ? periodEnd : freezeEnd;

        if (overlapEnd >= overlapStart) {
            BracketWrapper freezeBracket = buildBracket(
                bracketIndex,
                'Freeze Period - LPC Not Calculated',
                outstandingAmount,
                overlapStart,
                overlapEnd,
                true
            );

            result.brackets.add(freezeBracket);

            FreezeWrapper fw = buildFreezeSection(
                result.freezeSections.size() + 1,
                outstandingAmount,
                overlapStart,
                overlapEnd
            );
            result.freezeSections.add(fw);

            result.logs.add(
                'Freeze period excluded from LPC. Freeze Start = ' + overlapStart +
                ', Freeze End = ' + overlapEnd +
                ', Days Excluded = ' + freezeBracket.days +
                ', Outstanding During Freeze = ' + outstandingAmount +
                ', LPC Amount Excluded = ' + fw.lpcAmountExcluded
            );

            bracketIndex++;
        }

        if (periodEnd > freezeEnd) {
            Date chargeableStartAfterFreeze = freezeEnd.addDays(1);

            if (periodEnd >= chargeableStartAfterFreeze) {
                BracketWrapper afterFreeze = buildBracket(
                    bracketIndex,
                    bracketType,
                    outstandingAmount,
                    chargeableStartAfterFreeze,
                    periodEnd,
                    false
                );

                result.brackets.add(afterFreeze);
                result.lpcAmount += afterFreeze.lpcAmount;

                result.logs.add(
                    'LPC calculated after freeze from ' + chargeableStartAfterFreeze +
                    ' to ' + periodEnd +
                    ', Days = ' + afterFreeze.days +
                    ', Outstanding = ' + outstandingAmount +
                    ', LPC = ' + afterFreeze.lpcAmount
                );

                bracketIndex++;
            }
        }

        return bracketIndex;
    }

    private static Date getLPCStartDate(SalesOrderInstallments__c installment) {
        if (installment == null) {
            return null;
        }

        if (installment.RFO_Date__c != null) {
            return installment.RFO_Date__c;
        }

        if (installment.ExtensionDate__c != null) {
            return installment.ExtensionDate__c;
        }

        return installment.MilestoneDate__c;
    }

    private static FreezeWrapper buildFreezeSection(
        Integer sequence,
        Decimal amountNotCalculatedForLpc,
        Date freezeStartDate,
        Date freezeEndDate
    ) {
        FreezeWrapper fw = new FreezeWrapper();
        fw.sequence = sequence;
        fw.freezeStartDate = freezeStartDate;
        fw.freezeEndDate = freezeEndDate;
        fw.amountNotCalculatedForLpc = nvl(amountNotCalculatedForLpc);
        fw.freezeDays = getDaysInclusive(freezeStartDate, freezeEndDate);
        fw.lpcAmountExcluded = calculateLPCAmount(amountNotCalculatedForLpc, freezeStartDate, freezeEndDate);
        fw.remarks = 'LPC not calculated during freeze period. Amount reflects outstanding amount after considering payments cleared before this freeze bracket.';
        return fw;
    }

    private static BracketWrapper buildBracket(
        Integer sequence,
        String bracketType,
        Decimal amount,
        Date startDate,
        Date endDate,
        Boolean isFreezePeriod
    ) {
        BracketWrapper bw = new BracketWrapper();
        bw.sequence = sequence;
        bw.bracketType = bracketType;
        bw.amountConsideredForLpc = nvl(amount);
        bw.lpcStartDate = startDate;
        bw.lpcEndDate = endDate;
        bw.days = getDaysInclusive(startDate, endDate);
        bw.isFreezePeriod = isFreezePeriod == true;
        bw.lpcAmount = bw.isFreezePeriod ? 0 : calculateLPCAmount(amount, startDate, endDate);
        return bw;
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

    private static Decimal nvl(Decimal value) {
        return value == null ? 0 : value;
    }

    public class PaymentEvent implements Comparable {
        public Date paidDate;
        public Decimal amount;
        public Id allocationId;

        public PaymentEvent(Date paidDate, Decimal amount, Id allocationId) {
            this.paidDate = paidDate;
            this.amount = amount;
            this.allocationId = allocationId;
        }

        public Integer compareTo(Object obj) {
            PaymentEvent other = (PaymentEvent)obj;

            if (this.paidDate == other.paidDate) {
                return 0;
            }

            return this.paidDate < other.paidDate ? -1 : 1;
        }
    }

    public class LpcAnalysisResponse {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String unitName;
        @AuraEnabled public Decimal totalLpc = 0;
        @AuraEnabled public List<InstallmentAnalysisWrapper> installments = new List<InstallmentAnalysisWrapper>();
        @AuraEnabled public List<LpcWaiverProcessWrapper> waiverProcesses = new List<LpcWaiverProcessWrapper>();
    }

    public class InstallmentAnalysisWrapper {
        @AuraEnabled public Id installmentId;
        @AuraEnabled public String installmentName;
        @AuraEnabled public Decimal milestoneNumber;
        @AuraEnabled public Decimal milestonePercent;
        @AuraEnabled public String milestoneDisplay;
        @AuraEnabled public Date milestoneDate;
        @AuraEnabled public Date extensionDate;
        @AuraEnabled public Date rfoDate;
        @AuraEnabled public Date lpcStartBaseDate;
        @AuraEnabled public Date lpcFreezeStartDate;
        @AuraEnabled public Date lpcFreezeEndDate;
        @AuraEnabled public Date calculationDate;
        @AuraEnabled public Date graceDate;
        @AuraEnabled public Boolean isLpcExcluded = false;

        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String invoiceName;
        @AuraEnabled public Decimal invoiceAmount = 0;
        @AuraEnabled public Decimal balanceAmount = 0;
        @AuraEnabled public Decimal appliedAmount = 0;
        @AuraEnabled public Decimal totalPaidAmount = 0;
        @AuraEnabled public String invoiceStatus;
        @AuraEnabled public Date invoiceDate;

        @AuraEnabled public Decimal paidWithinGrace = 0;
        @AuraEnabled public Decimal outstandingAfterPayments = 0;
        @AuraEnabled public Decimal lpcAmount = 0;
        @AuraEnabled public String reason;

        @AuraEnabled public List<AllocationWrapper> allocations = new List<AllocationWrapper>();
        @AuraEnabled public List<BracketWrapper> brackets = new List<BracketWrapper>();
        @AuraEnabled public List<FreezeWrapper> freezeSections = new List<FreezeWrapper>();
        @AuraEnabled public List<String> logs = new List<String>();
    }

    public class AllocationWrapper {
        @AuraEnabled public String sequence;
        @AuraEnabled public Id allocationId;
        @AuraEnabled public String allocationName;
        @AuraEnabled public Decimal appliedAmount = 0;
        @AuraEnabled public String allocationStatus;
        @AuraEnabled public String receiptName;
        @AuraEnabled public String receiptStatus;
        @AuraEnabled public Date ebsClearedDate;
        @AuraEnabled public Datetime transactionDate;
    }

    public class FreezeWrapper {
        @AuraEnabled public Integer sequence;
        @AuraEnabled public Date freezeStartDate;
        @AuraEnabled public Date freezeEndDate;
        @AuraEnabled public Decimal amountNotCalculatedForLpc = 0;
        @AuraEnabled public Integer freezeDays = 0;
        @AuraEnabled public Decimal lpcAmountExcluded = 0;
        @AuraEnabled public String remarks;
    }

    public class BracketWrapper {
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String bracketType;
        @AuraEnabled public Decimal amountConsideredForLpc = 0;
        @AuraEnabled public Date lpcStartDate;
        @AuraEnabled public Date lpcEndDate;
        @AuraEnabled public Integer days = 0;
        @AuraEnabled public Decimal lpcAmount = 0;
        @AuraEnabled public Boolean isFreezePeriod = false;
    }
    
    public class LpcWaiverProcessWrapper {
    @AuraEnabled public Id businessProcessId;
    @AuraEnabled public String name;
    @AuraEnabled public Decimal lpcCollectedAmount = 0;
    @AuraEnabled public Decimal waiverPercentage = 0;
    @AuraEnabled public Decimal lpcAmount = 0;
    @AuraEnabled public Decimal lpcWaiverAmount = 0;
    @AuraEnabled public String status;
}
    
}