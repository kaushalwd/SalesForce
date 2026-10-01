/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 02-20-2026
 * @last modified by  : Krishna Chaitanya
**/
public class SOAPdfController {

    public static SOAWrapper getSOAData(Id salesOrderId) {
        SOAWrapper result = new SOAWrapper();

        // -----------------------------
        // Sales Order
        // -----------------------------
        result.salesOrder = [
            SELECT Id, SOCreationDate__c, SPACustomerSignedDate__c, ProjectName__c, TotalAmount__c,
                   CustomerAccount__r.EmailID__c, CustomerAccount__r.Masked_Phone__c, CustomerAccount__r.UnifiedNumber__c, CustomerAccount__r.NumberPC__c,
                   CustomerAccount__r.PersonMailingAddress, Unit__r.Type__c, CustomerAccount__r.Name, CustomerAccount__r.Customer_MID__c,
                   FormulaAccountName__c, CustomerType__c, Unit__r.Name, Unit__r.UnitClassification__c, Unit__r.PlotNo__c,
                   Unit__r.Project_Name__c, Unit__r.ADM_Plot_Number__c, Unit__r.Building_Name__c,
                   Unit__r.Phase__r.Project__c, Unit__r.Phase__r.Name, Unit__r.District__c,
                   VirtualAccount__r.ESCROWAccountName__c, VirtualAccount__r.Escrow_Bank_Name__c,
                   VirtualAccount__r.VirtualIBANNumber__c, VirtualAccount__r.Swift_Code__c,
                   VirtualAccount__r.VirtualAccountNumber__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
        ];

        // -----------------------------
        // Joint Owners (ordered + unique)
        // -----------------------------
        List<JointOwner__c> joList = [
            SELECT JointOwnerAccount__r.Name
            FROM JointOwner__c
            WHERE SalesOrder__c = :salesOrderId
              AND JointOwnerAccount__c != null
            ORDER BY CreatedDate
        ];

        List<String> joNames = new List<String>();
        for (JointOwner__c jo : joList) {
            if (jo.JointOwnerAccount__r != null && String.isNotBlank(jo.JointOwnerAccount__r.Name)) {
                joNames.add(jo.JointOwnerAccount__r.Name.trim());
            }
        }

        Set<String> seen = new Set<String>();
        List<String> orderedUnique = new List<String>();
        for (String nm : joNames) {
            if (String.isBlank(nm)) continue;
            if (seen.add(nm)) orderedUnique.add(nm);
        }
        result.jointOwnerNames = String.join(orderedUnique, ', ');

        // -----------------------------
        // Payment Installment Invoices (cleared allocations only)
        // -----------------------------
        result.PayemntSalesList = [
            SELECT Id, Applied_Percentage__c, Name, InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c,
                   InvoiceStatus__c, InvoiceDate__c, SalesOrderInstallment__c,
                   SalesOrderInstallment__r.Milestone__c, SalesOrderInstallment__r.MilestoneDescription__c,
                   SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.MilestoneDate__c,
                   SalesOrderInstallment__r.PaymentStatus__c, SalesOrderInstallment__r.IsHandoverPayment__c,
                   (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,Receipt__r.Receipt_Amount__c,
                           Receipt__r.EBS_Clearing_Date__c, Receipt__r.TransactionNumber__c, Receipt__r.Status__c
                    FROM Allocations__r
                    WHERE Receipt__r.Status__c = 'Cleared')
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
              AND Sales_Order__c = null
              AND SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
            ORDER BY SalesOrderInstallment__r.MilestoneNumber__c
        ];

        // -----------------------------
        // Other Payments (ONLY non-installment invoices)
        // -----------------------------
        result.otherPayemntSalesList = [
            SELECT Id, Applied_Percentage__c, Name, Charge__c, Charge__r.Name, Charge__r.Type__c,
                   Charge__r.PaymentStatus__c, Charge__r.Paid_Amount__c, Charge__r.Remaining_Amount__c,
                   InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c, InvoiceStatus__c, InvoiceDate__c,
                   Is_ADM_Fees_and_Dari_charges__c, SalesOrderInstallment__c,
                   (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,
                           Receipt__r.TransactionNumber__c, Receipt__r.EBS_Clearing_Date__c, Receipt__r.Status__c,Receipt__r.Receipt_Amount__c
                    FROM Allocations__r
                    WHERE Receipt__r.Status__c = 'Cleared')
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = null
              AND Sales_Order__c = :salesOrderId
        ];

        // -----------------------------
        // FutureMilestoneOtherPayments (same build logic as StatementOfAccountController)
        // -----------------------------
        Decimal NEGATIVE_THRESHOLD = 0.0;
        list<Invoice__c> invFinalList= new list<Invoice__c>();
        List<Invoice__c> newt = [
            SELECT Id, Name, InvoiceDate__c, InvoiceAmount__c, InvoiceBalance__c, InvoiceStatus__c,
                   Is_ADM_Fees_and_Dari_charges__c, Charge__r.Name,
                   SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneDate__c,
                   (SELECT Id, AllocationAmount__c, AllocationDate__c,
                           Receipt__c,
                           Receipt__r.Receipt_Excess_Amount__c,
                           Receipt__r.EBS_Clearing_Date__c,
                           Receipt__r.ChequeDate__c,
                           Receipt__r.TotalAmount__c,
                           Receipt__r.Receipt_Amount__c,
                           Receipt__r.Name,
                           Receipt__r.AppliedAmount__c,
                           Receipt__r.TransactionNumber__c,
                           Receipt__r.Status__c
                    FROM Allocations__r
                    WHERE Receipt__c != null
                      AND (Receipt__r.Status__c IN ('In Progress','Confirmed')
                           OR (Receipt__r.Status__c = 'Cleared' AND Receipt__r.Receipt_Excess_Amount__c >: NEGATIVE_THRESHOLD)))
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
              AND SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
        ];

        result.FutureMilestoneOtherPayments = new List<Invoice__c>();

        Set<Id> addedInvIds = new Set<Id>();
        Set<Id> futureListReceiptIds = new Set<Id>(); // dedupe invoices by receipt used

        for (Invoice__c inv : newt) {
            Date msDate = (inv.SalesOrderInstallment__r != null) ? inv.SalesOrderInstallment__r.MilestoneDate__c : null;

            Boolean candidate = false;

            // 1) Future milestone invoices -> candidate
            if (msDate != null && msDate >= System.today() && inv.Allocations__r != null) {
                candidate = true;
                result.FutureMilestoneOtherPayments.add(inv);
            }

            // 2) Past milestone invoices -> candidate ONLY if any cleared receipt has remaining (Total > Applied)
            if (msDate != null && msDate < System.today() && inv.Allocations__r != null  ) {
                for (Allocation__c alloc : inv.Allocations__r) {
                    if (alloc.Receipt__r == null) continue;

                    Decimal rTotal   = (alloc.Receipt__r.Receipt_Amount__c == null) ? 0 : alloc.Receipt__r.Receipt_Amount__c;
                    Decimal rApplied = (alloc.Receipt__r.AppliedAmount__c == null) ? 0 : alloc.Receipt__r.AppliedAmount__c;
					
                    if (alloc.Receipt__r.Status__c == 'Cleared' && alloc.Receipt__r.Receipt_Excess_Amount__c != null &&
   						 alloc.Receipt__r.Receipt_Excess_Amount__c > NEGATIVE_THRESHOLD) {
                        candidate = true;
                        result.FutureMilestoneOtherPayments.add(inv);
                        break;
                    }
                }
            }

            if (!candidate) continue;

            // dedupe invoices at add-time based on receipt usage
            Boolean hasNewReceipt = false;
            if (inv.Allocations__r != null) {
                for (Allocation__c alloc : inv.Allocations__r) {
                    if (alloc.Receipt__c == null) continue;
                    if (!futureListReceiptIds.contains(alloc.Receipt__c)) {
                        hasNewReceipt = true;
                        break;
                    }
                }
            }

            if (inv.Allocations__r == null || inv.Allocations__r.isEmpty()) {
                hasNewReceipt = true; // fallback
            }

            if (hasNewReceipt && !addedInvIds.contains(inv.Id)) {
                //result.FutureMilestoneOtherPayments.add(inv);
                //invFinalList.add(inv);
                addedInvIds.add(inv.Id);

                if (inv.Allocations__r != null) {
                    for (Allocation__c alloc : inv.Allocations__r) {
                        if (alloc.Receipt__c != null) futureListReceiptIds.add(alloc.Receipt__c);
                    }
                }
            }
        }

        // -----------------------------
        // Totals (mirror final logic)
        // -----------------------------
        Decimal totalAmount = 0;
        Decimal totalAmountCollected = 0;
        Decimal totalAmountOutstanding = 0;
        Decimal totalLatePayment = 0;
        Decimal totalOtherAmount = 0;
        Decimal totalOtherAmountCollected = 0;
        Decimal totalOtherAmountOutstanding = 0;
        Decimal totalPercentage = 0;
        Decimal grandTotalOutstanding = 0;
        Decimal unclearedReceiptAmount = 0;

        // Installment totals
        for (Invoice__c invRec : result.PayemntSalesList) {
            if (invRec.Applied_Percentage__c != null && invRec.Applied_Percentage__c > 0) {
                totalPercentage = (totalPercentage == null) ? invRec.Applied_Percentage__c : totalPercentage + invRec.Applied_Percentage__c;
            }

            Decimal invAmt = (invRec.InvoiceAmount__c == null) ? 0 : invRec.InvoiceAmount__c;
            totalAmount += invAmt;

            Decimal clearedAlloc = 0;
            if (invRec.Allocations__r != null) {
                for (Allocation__c all : invRec.Allocations__r) {
                    if (all.Receipt__r != null && all.Receipt__r.Status__c == 'Cleared') {
                        Decimal a = (all.AllocationAmount__c == null) ? 0 : all.AllocationAmount__c;
                        totalAmountCollected += a;
                        clearedAlloc += a;
                    }
                }
            }

            Decimal balance = invAmt - clearedAlloc;
            if (invRec.SalesOrderInstallment__r != null
                && invRec.SalesOrderInstallment__r.MilestoneDate__c != null
                && invRec.SalesOrderInstallment__r.MilestoneDate__c < System.today()) {
                totalAmountOutstanding += balance;
            }
        }

        // Other payment totals (non-installment invoices)
        for (Invoice__c invORec : result.otherPayemntSalesList) {
            Decimal invAmt = (invORec.InvoiceAmount__c == null) ? 0 : invORec.InvoiceAmount__c;
            totalOtherAmount += invAmt;

            if (invORec.InvoiceStatus__c == 'Paid') {
                totalOtherAmountCollected += (invORec.AppliedAmount__c == null ? 0 : invORec.AppliedAmount__c);
            }

            if (invORec.InvoiceDate__c != null && invORec.InvoiceDate__c < System.today()) {
                totalOtherAmountOutstanding += (invORec.InvoiceBalance__c == null ? 0 : invORec.InvoiceBalance__c);
            }
        }

        // Future milestone totals (dedupe receipts across invoices)
        Set<Id> countedFutureReceiptIds = new Set<Id>();
        Set<Id> countedFutureExcessReceiptIds = new Set<Id>();

        for (Invoice__c futureInv : result.FutureMilestoneOtherPayments) {
            if (futureInv.Allocations__r == null) continue;

            Decimal allocatedAmt = 0;
            Decimal totalAmt = 0;

            for (Allocation__c alloc : futureInv.Allocations__r) {
                if (alloc.Receipt__c == null || alloc.Receipt__r == null) continue;

                if (countedFutureReceiptIds.contains(alloc.Receipt__c)) continue;
                countedFutureReceiptIds.add(alloc.Receipt__c);

                allocatedAmt += (alloc.Receipt__r.AppliedAmount__c == null ? 0 : alloc.Receipt__r.AppliedAmount__c);

                if (alloc.Receipt__r.Status__c == 'Cleared') {
                    totalAmt += (alloc.Receipt__r.Receipt_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Amount__c);
                }
            }

            Decimal balance = totalOtherAmountOutstanding;
            for (Allocation__c alloc : futureInv.Allocations__r) {
                if (alloc.Receipt__c == null || alloc.Receipt__r == null) continue;
                if (alloc.Receipt__r.Status__c != 'Cleared') continue;

                if (countedFutureExcessReceiptIds.contains(alloc.Receipt__c)) continue;
                countedFutureExcessReceiptIds.add(alloc.Receipt__c);

                balance -= (alloc.Receipt__r.Receipt_Excess_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Excess_Amount__c);
            }

            totalOtherAmount += totalAmt;
            totalOtherAmountCollected += allocatedAmt;
            totalOtherAmountOutstanding = balance;
        }

        grandTotalOutstanding = totalOtherAmountOutstanding + totalAmountOutstanding;

        // -----------------------------
        // Wrapper strings (OIC safe)
        // -----------------------------
        result.totalAmountStr = String.valueOf(totalAmount.setScale(2));
        result.totalCollectedStr = String.valueOf(totalAmountCollected.setScale(2));
        result.totalOutstandingStr = String.valueOf(totalAmountOutstanding.setScale(2));
        result.totalOtherAmountStr = String.valueOf(totalOtherAmount.setScale(2));
        result.totalOtherCollectedStr = String.valueOf(totalOtherAmountCollected.setScale(2));
        result.totalOtherOutstandingStr = String.valueOf(totalOtherAmountOutstanding.setScale(2));
        result.grandTotalOutstandingStr = String.valueOf(grandTotalOutstanding.setScale(2));
        result.totalLatePaymentStr = String.valueOf(totalLatePayment.setScale(2));
        result.unclearedReceiptAmountStr = String.valueOf(unclearedReceiptAmount.setScale(2));
		result.otherPayemntSalesList.addAll(result.FutureMilestoneOtherPayments);
        return result;
    }

    public class SOAWrapper {
        @AuraEnabled public SalesOrder__c salesOrder;
        @AuraEnabled public List<Invoice__c> PayemntSalesList;
        @AuraEnabled public List<Invoice__c> otherPayemntSalesList;
        @AuraEnabled public List<Invoice__c> FutureMilestoneOtherPayments;
        @AuraEnabled public Date currentdate = System.today();

        @AuraEnabled public Integer totalInstallments = 0;
        @AuraEnabled public Integer totalPaidInstallments = 0;

        @AuraEnabled public String totalAmountStr;
        @AuraEnabled public String totalCollectedStr;
        @AuraEnabled public String totalOutstandingStr;
        @AuraEnabled public String totalOtherAmountStr;
        @AuraEnabled public String totalOtherCollectedStr;
        @AuraEnabled public String totalOtherOutstandingStr;
        @AuraEnabled public String grandTotalOutstandingStr;
        @AuraEnabled public String jointOwnerNames;
        @AuraEnabled public String totalLatePaymentStr;
        @AuraEnabled public String unclearedReceiptAmountStr;
    }
}