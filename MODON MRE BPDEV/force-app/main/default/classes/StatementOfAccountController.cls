/**
* @description       : 
* @author            : Manoj Kumar V
* @group             : 
* @last modified on  : 02-13-2026
* @last modified by  : Krishna Chaitanya
* 1.0     Kumaravel    30-12-2025   Added Mobile PDF Download Option ****************
* 1.1     Kumaravel    02-01-2026   Augument not null issue ****************
* 2.0	  Karunakar		Aug 21		Excess Amount for Other charges
**/
public with sharing class StatementOfAccountController {
    public String projectName {get; set;}
    public String dte {get; set;}
    public String spaDte {get; set;}
    public String orgPurchValue {get; set;}
    public Decimal rowNumber {get; set;}
    public Boolean showManualFooter {get; set;}
    public String jointOwnerNames { get; set; }
    public SalesOrder__c salesOrder {get; set;}
    public List<SalesOrderInstallments__c> saleOrderInstallments {get; set;}
    public List<Invoice__c> FutureMilestoneOtherPayments { get; set; }
    public List<Invoice__c> PayemntSalesList {get; set;}
    public List<Invoice__c> OtherPayemntSalesList {get; set;}
    public List<Receipt__c> ExcessReceiptsList {get; set;}//2.0
    public Decimal totalExcessAmount {get; set;}//2.0
    public Decimal totalAmount {get; set;}
    public Decimal totalAmountCollected {get; set;}
    public Decimal totalPercentage {get; set;}
    public Decimal totalAmountOutstanding {get; set;}
    public Decimal totalLatePayment {get; set;}
    public Decimal totalOtherAmount {get; set;}
    public Decimal totalOtherAmountCollected {get; set;}
    public Decimal totalOtherAmountOutstanding {get; set;}
    public Decimal excessOutstandingNotInOtherTotal {get; set;}
    public Decimal futureOtherAmount { get; set; }
    public Decimal futureOtherAmountCollected { get; set; }
    public Decimal futureOtherAmountOutstanding { get; set; }
    public Date Today { get { return Date.today(); } }
    public Decimal grandTotalOutstanding {get;set;}
    public String currentRecordId {get; set;}

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

    // Dynamic Late Payment Charges row (mirrors NewStatementOfAccountController)
    public Boolean showDynamicLpcRow {get; set;}
    public Decimal dynamicLpcAmount {get; set;}

    private Decimal lpcInvoicePaidAmount = 0;
    private Decimal invoiceLPCDewAmmount = 0;

    private Map<Id, LPCCalculationService.InstallmentLPCResult> lpcByInvoiceIdMap =
        new Map<Id, LPCCalculationService.InstallmentLPCResult>();

    //  Custom Map for computed balances (only cleared allocations)
    public Map<Id, Decimal> invoiceClearedBalanceMap { get; set; }

    public StatementOfAccountController() {
        this.showManualFooter = true;
        currentRecordId = ApexPages.CurrentPage().getParameters().get('id');
        invoiceClearedBalanceMap = new Map<Id, Decimal>();
        if (currentRecordId != null) {
            getAllSOA();
        }
    }
    
    public void getAllSOA() {
        salesOrder = [
            SELECT Id, SOCreationDate__c, SPACustomerSignedDate__c, ProjectName__c, TotalAmount__c,
            CustomerAccount__r.Masked_Phone__c, CustomerAccount__r.UnifiedNumber__c,
            CustomerAccount__r.PersonMailingAddress,CustomerAccount__r.Customer_MID__c, Unit__r.Type__c, CustomerAccount__r.Name,
            FormulaAccountName__c, CustomerType__c, Unit__r.Name, Unit__r.UnitClassification__c, Unit__r.PlotNo__c,
            Unit__r.Project_Name__c, Unit__r.Building_No__c, Unit__r.ADM_Plot_Number__c, Unit__r.Building_Name__c,
            Unit__r.Phase__r.Project__c, Unit__r.Phase__r.Name, Unit__r.District__c,
            VirtualAccount__r.ESCROWAccountName__c, VirtualAccount__r.Escrow_Bank_Name__c,
            VirtualAccount__r.VirtualIBANNumber__c, VirtualAccount__r.Swift_Code__c,
            VirtualAccount__r.VirtualAccountNumber__c
            FROM SalesOrder__c
            WHERE Id = :currentRecordId
        ];

        loadLPCResults(salesOrder.Id);

        PayemntSalesList = [
            SELECT Id, Applied_Percentage__c, Name, InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c,
            InvoiceStatus__c, InvoiceDate__c, SalesOrderInstallment__c,
            SalesOrderInstallment__r.Milestone__c, SalesOrderInstallment__r.MilestoneDescription__c,
            SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.MilestoneDate__c,
            SalesOrderInstallment__r.PaymentStatus__c,SalesOrderInstallment__r.IsHandoverPayment__c,
            (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,
             Receipt__r.EBS_Clearing_Date__c, Receipt__r.TransactionNumber__c, Receipt__r.Status__c,Receipt__r.Modeofpayment__c,Receipt__r.Name
             FROM Allocations__r
             WHERE Receipt__r.Status__c = 'Cleared' AND Status__c = 'Applied') 
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
            AND SalesOrderInstallment__r.SalesOrder__c = :currentRecordId
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
            ORDER BY SalesOrderInstallment__r.MilestoneNumber__c
        ];
        
        List<Invoice__c> newt = [
            SELECT Id, Name, InvoiceDate__c, InvoiceAmount__c, InvoiceBalance__c, Is_ADM_Fees_and_Dari_charges__c,
            InvoiceStatus__c, Charge__r.Name,
            SalesOrderInstallment__r.MilestoneDate__c,
            (SELECT Id, AllocationAmount__c, AllocationDate__c,
             Receipt__c,Receipt__r.Receipt_Excess_Amount__c,Receipt__r.EBS_Clearing_Date__c,Receipt__r.ChequeDate__c,
             Receipt__r.TransactionDate__c,
             Receipt__r.Receipt_Amount__c,Receipt__r.Name,
             Receipt__r.AppliedAmount__c, Receipt__r.TransactionNumber__c, Receipt__r.Status__c, Receipt__r.Modeofpayment__c
             FROM Allocations__r
             WHERE Receipt__c != null AND Status__c = 'Applied'
             AND (Receipt__r.Status__c IN ('In Progress','Confirmed') OR (Receipt__r.Status__c='Cleared' AND Receipt__r.Receipt_Excess_Amount__c !=0)))
            FROM Invoice__c
            WHERE Sales_Order__c = :currentRecordId
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];
        
        Set<Id> addedInvIds = new Set<Id>();
        if (FutureMilestoneOtherPayments == null) {
            FutureMilestoneOtherPayments = new List<Invoice__c>();
        }
        Set<Id> futureListReceiptIds = new Set<Id>(); // receipts already represented in FutureMilestoneOtherPayments
        
        
        for (Invoice__c inv : newt) {
            Date msDate = inv.SalesOrderInstallment__r != null ? inv.SalesOrderInstallment__r.MilestoneDate__c : null;
            
            // Decide if invoice should be considered (your existing conditions)
            Boolean candidate = false;
            
            // 1) Future milestone -> candidate
            if (msDate != null && msDate >= System.today()) {
                candidate = true;
            }
            
            // 2) Past milestone -> candidate only if any cleared receipt has remaining
            if (!candidate && msDate != null && msDate < System.today() && inv.Allocations__r != null) {
                for (Allocation__c alloc : inv.Allocations__r) {
                    if (alloc.Receipt__r == null) continue;
                    
                    Decimal rTotal   = alloc.Receipt__r.Receipt_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Amount__c;
                    Decimal rApplied = alloc.Receipt__r.AppliedAmount__c == null ? 0 : alloc.Receipt__r.AppliedAmount__c;
                    
                    if (alloc.Receipt__r.Status__c == 'Cleared' && rTotal > rApplied) {
                        candidate = true;
                        break;
                    }
                }
            }
            
            if (!candidate) continue;
            
            // DEDUPE at invoice-add time based on receipt usage
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
            
            // If invoice has no receipts, keep old behavior (optional)
            if (inv.Allocations__r == null || inv.Allocations__r.isEmpty()) {
                hasNewReceipt = true;
            }
            
            if (hasNewReceipt && !addedInvIds.contains(inv.Id)) {
                FutureMilestoneOtherPayments.add(inv);
                addedInvIds.add(inv.Id);
                
                // mark all receipts in this invoice as "represented"
                if (inv.Allocations__r != null) {
                    for (Allocation__c alloc : inv.Allocations__r) {
                        if (alloc.Receipt__c != null) futureListReceiptIds.add(alloc.Receipt__c);
                    }
                }
            }
        }
        
        List<JointOwner__c> joList = [
            SELECT JointOwnerAccount__r.Name
            FROM JointOwner__c
            WHERE SalesOrder__c = :currentRecordId
            AND JointOwnerAccount__c != null
            ORDER BY CreatedDate
        ];
        
        List<String> joNames = new List<String>();
        for (JointOwner__c jo : joList) {
            if (jo.JointOwnerAccount__r != null && String.isNotBlank(jo.JointOwnerAccount__r.Name)) {
                joNames.add(jo.JointOwnerAccount__r.Name.trim());
            }
        }
        // Remove duplicates (optional) and join
        Set<String> seen = new Set<String>();
        List<String> orderedUnique = new List<String>();
        for (String nm : joNames) {
            if (String.isBlank(nm)) continue;
            if (seen.add(nm)) orderedUnique.add(nm);
        }
        jointOwnerNames = String.join(orderedUnique, ', ');
        OtherPayemntSalesList = [
            SELECT Id, Applied_Percentage__c, Name, Charge__c, Charge__r.Name, Charge__r.Type__c,
            Charge__r.PaymentStatus__c, Charge__r.Paid_Amount__c, Charge__r.Remaining_Amount__c,
            InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c, InvoiceStatus__c, InvoiceDate__c,
            Is_ADM_Fees_and_Dari_charges__c, SalesOrderInstallment__c,
            (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,Receipt__r.Modeofpayment__c,Receipt__r.Name,
             Receipt__r.TransactionNumber__c, Receipt__r.EBS_Clearing_Date__c, Receipt__r.Status__c
             FROM Allocations__r
             WHERE Status__c = 'Applied' AND Receipt__r.Status__c = 'Cleared')
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = null
            AND Sales_Order__c = :salesOrder.Id
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        // Receipts directly linked to this Sales Order that carry an excess amount
        // 2.0 
        ExcessReceiptsList = [
            SELECT Id, Name, Status__c, ReceiptDate__c, EBS_Clearing_Date__c, ChequeDate__c,
                   TransactionNumber__c, Receipt_Amount__c, AppliedAmount__c, Receipt_Excess_Amount__c,
                   Modeofpayment__c,
                   (SELECT Id, Invoice__c, Invoice__r.Name FROM Allocations__r WHERE Status__c = 'Applied')
            FROM Receipt__c
            WHERE SalesOrder__c = :salesOrder.Id
            AND SalesOrderInstallment__c = null
            AND Status__c = 'Cleared'
            AND Receipt_Excess_Amount__c != null
            AND Receipt_Excess_Amount__c != 0
            ORDER BY EBS_Clearing_Date__c
        ];

        totalAmount = 0;
        totalAmountCollected = 0;
        totalAmountOutstanding = 0;
        totalLatePayment = 0;
        totalOtherAmount = 0;
        totalOtherAmountCollected = 0;
        totalOtherAmountOutstanding = 0;
        excessOutstandingNotInOtherTotal = 0;
        futureOtherAmount = 0;
        futureOtherAmountCollected = 0;
        futureOtherAmountOutstanding = 0;
        
        for (Invoice__c invRec : PayemntSalesList) {
            if (invRec.Applied_Percentage__c != null && invRec.Applied_Percentage__c > 0) {
                totalPercentage = totalPercentage == null ? invRec.Applied_Percentage__c : totalPercentage + invRec.Applied_Percentage__c;
            }
            
            Decimal invAmt = invRec.InvoiceAmount__c != null ? invRec.InvoiceAmount__c : 0;
            totalAmount = totalAmount == null ? invAmt : totalAmount + invAmt;
            
            Decimal clearedAlloc = 0;
            for (Allocation__c all : invRec.Allocations__r) {
                if (all.Receipt__r != null && all.Receipt__r.Status__c =='Cleared') {
                    totalAmountCollected += (all.AllocationAmount__c != null ? all.AllocationAmount__c : 0);
                    clearedAlloc += (all.AllocationAmount__c != null ? all.AllocationAmount__c : 0);
                }
            }
            
            Decimal balance = (invRec.InvoiceAmount__c != null ? invRec.InvoiceAmount__c : 0) - clearedAlloc;
            invoiceClearedBalanceMap.put(invRec.Id, balance);
            
            if (invRec.SalesOrderInstallment__r.MilestoneDate__c < system.today()) {
                totalAmountOutstanding += balance;
            }

            if (showLPC) {
                Decimal dynamicLpc = calculateDynamicLpcForInstallment(invRec);
                totalLatePayment = totalLatePayment == null ? dynamicLpc : totalLatePayment + dynamicLpc;
            }
        }
        
        for (Invoice__c invORec : OtherPayemntSalesList) {
            //totalOtherAmount = totalOtherAmount == null ? invORec.InvoiceAmount__c : totalOtherAmount + invORec.InvoiceAmount__c; // 1.1 
            totalOtherAmount = totalOtherAmount == null ? (invORec.InvoiceAmount__c != null ? invORec.InvoiceAmount__c : 0) : totalOtherAmount + (invORec.InvoiceAmount__c != null ? invORec.InvoiceAmount__c : 0);
            for (Allocation__c alloc : invORec.Allocations__r) {
                if (invORec.InvoiceStatus__c == 'Paid' && alloc.Receipt__r.Status__c == 'Cleared') {
                totalOtherAmountCollected = totalOtherAmountCollected == null ? invORec.AppliedAmount__c : totalOtherAmountCollected + invORec.AppliedAmount__c;
            }
            }
            
            if (invORec.InvoiceDate__c < system.today()) {
                totalOtherAmountOutstanding += invORec.InvoiceBalance__c;
            }
            
        }
        Set<Id> countedFutureReceiptIds = new Set<Id>();
        Set<Id> countedFutureExcessReceiptIds = new Set<Id>();
        for (Invoice__c futureInv : FutureMilestoneOtherPayments) {
            if (futureInv.Allocations__r != null) {
                
                Decimal allocatedAmt = 0;
                Decimal totalAmt = 0;
                for (Allocation__c alloc : futureInv.Allocations__r) {
                    if (alloc.Receipt__c == null || alloc.Receipt__r == null) continue;
                    
                    // count the same receipt only once across all future invoices
                    if (countedFutureReceiptIds.contains(alloc.Receipt__c)) continue;
                    countedFutureReceiptIds.add(alloc.Receipt__c);
                    
                    // keep your existing logic (receipt-based), but de-duped
                    if (alloc.Receipt__r.Receipt_Excess_Amount__c == null) {
                        allocatedAmt += (alloc.Receipt__r.AppliedAmount__c == null ? 0 : alloc.Receipt__r.AppliedAmount__c);
                    }
                    if (alloc.Receipt__r != null && alloc.Receipt__r.Status__c == 'Cleared') {
                        totalAmt +=(alloc.Receipt__r.Receipt_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Amount__c);
                    }
                }
                
                
                
                
                for (Allocation__c alloc : futureInv.Allocations__r) {
                    if (alloc.Receipt__c == null || alloc.Receipt__r == null) continue;
                    if (alloc.Receipt__r.Status__c != 'Cleared') continue;

                    if (countedFutureExcessReceiptIds.contains(alloc.Receipt__c)) continue;
                    countedFutureExcessReceiptIds.add(alloc.Receipt__c);

                    excessOutstandingNotInOtherTotal -= (alloc.Receipt__r.Receipt_Excess_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Excess_Amount__c);
                }
                totalOtherAmount +=totalAmt;
                totalOtherAmountCollected += allocatedAmt;
            }
        }

        // Dynamic Late Payment Charges row (mirrors NewStatementOfAccountController)
        showDynamicLpcRow = false;
        dynamicLpcAmount = 0;

        if (showLPC) {
            lpcInvoicePaidAmount = LPCCalculationService.getPaidLpcInvoiceAmount(currentRecordId);
            invoiceLPCDewAmmount = getLPCDewAmmount(currentRecordId);

            Decimal originalDynamicLpc = totalLatePayment == null ? 0 : totalLatePayment;
            Decimal paidLpcAmount = lpcInvoicePaidAmount == null ? 0 : lpcInvoicePaidAmount;
            Decimal netDynamicLpcAmount = originalDynamicLpc - paidLpcAmount;

            if (netDynamicLpcAmount > 0) {
                netDynamicLpcAmount = netDynamicLpcAmount.setScale(2);
                showDynamicLpcRow = true;
                dynamicLpcAmount = netDynamicLpcAmount;

                totalOtherAmount = totalOtherAmount == null ? netDynamicLpcAmount : totalOtherAmount + netDynamicLpcAmount;
                totalOtherAmountOutstanding += netDynamicLpcAmount;
            } else if (invoiceLPCDewAmmount != null && invoiceLPCDewAmmount > 0) {
                totalOtherAmountOutstanding += invoiceLPCDewAmmount;
            }
        }

        //2.0 - starts
        totalExcessAmount = 0;
        for (Receipt__c excessReceipt : ExcessReceiptsList) {
          totalExcessAmount += (excessReceipt.Receipt_Excess_Amount__c == null ? 0 : excessReceipt.Receipt_Excess_Amount__c);
        }
        excessOutstandingNotInOtherTotal -= totalExcessAmount;
        //2.0 - ends

        grandTotalOutstanding = totalOtherAmountOutstanding + totalAmountOutstanding + excessOutstandingNotInOtherTotal;

    }
    
    
    
    
    // Expose map to VF
    public Map<Id, Decimal> getInvoiceClearedBalanceMap() {
        return invoiceClearedBalanceMap;
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

    private Decimal getLPCDewAmmount(Id salesOrderId) {
        Decimal paidAmount = 0;

        List<Invoice__c> lpcInvoiceList = [
            SELECT Id, TotalPaidAmount__c, Charge__r.Name, InvoiceAmount__c, InvoiceBalance__c
            FROM Invoice__c
            WHERE Sales_Order__c = :salesOrderId
            AND (Charge__r.Name = 'Late Payment Charges') AND InvoiceStatus__c != 'Paid'
            AND InvoiceStatus__c != 'Cancelled'
            AND Transaction_Type__c != 'Advance Tax'
        ];

        for (Invoice__c inv : lpcInvoiceList) {
            paidAmount += (inv.InvoiceBalance__c == null ? 0 : inv.InvoiceBalance__c);
        }

        return paidAmount;
    }
    /** 1.0 Added Mobile PDF Download Option START **********/ 
    public PageReference downloadPDF() {
        
        
        PageReference pdfPage = Page.SOA3;
        pdfPage.getParameters().put('id', currentRecordId);
        
        Blob pdfBlob;
        
        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        }else {
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
        ];
        
        
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String downloadUrl =
            baseUrl +
            '/sfc/servlet.shepherd/document/download/' +
            savedCV.ContentDocumentId;
        
        
        PageReference pr = new PageReference(downloadUrl);
        pr.setRedirect(true);
        return pr;
    }  
    /** 1.0 Added Mobile PDF Download Option END **********/ 
}