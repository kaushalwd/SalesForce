/**
 * @description       : 
 * @author            : Suresh
 * @group             : 
 * @last modified on  : 30-07-2026
 * @last modified by  : Suresh
 --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Suresh   	       11 May 2026    		Initial Draft
* 2.0           Suresh   	       01 06 2026           Updated SOQL query and response message
* 2.1			Suresh			   30 07 2026		    SOA changes
* 3.0           Suresh   	       19 08 2026           Pay button display logic added
*********************************************************************************************************************/
public class SOASAPdfController {

    public static List<SOAWrapper> getSOAData(Set<Id> set_salesOrderId) {
        
        List<SOAWrapper> lst_Result = new List<SOAWrapper>();
        List<SalesOrder__c> lst_SO = new List<SalesOrder__c>();
        Map<String, List<JointOwner__c>> map_JO = new Map<String, List<JointOwner__c>>();
        
        List<Invoice__c> lst_PayemntSales = new List<Invoice__c>();
        Map<String, List<Invoice__c>> map_PaymentSales = new Map<String, List<Invoice__c>>();
        
        List<Invoice__c> lst_OtherPayemntSales = new List<Invoice__c>();
        Map<String, List<Invoice__c>> map_OtherPayemntSales = new Map<String, List<Invoice__c>>();
        
        List<Invoice__c> lst_FuturPayemntSales = new List<Invoice__c>();
        Map<String, List<Invoice__c>> map_FuturPayemntSales = new Map<String, List<Invoice__c>>();
        
        Set<Id> set_InvoiceIds = new Set<Id>();
        Set<Id> set_SOIIds = new Set<Id>();
        Map<Id, List<PayDisplayFlagType>> map_PayDisplayFlag = new Map<Id, List<PayDisplayFlagType>>();
        // -----------------------------
        // Sales Order
        // -----------------------------
        //2.0 - updated
        lst_SO = [SELECT Id, Name, Status__c,Sub_Status__c, SPAStatus__c, Unit__c,  
                               Unit__r.Status__c, Unit__r.TotalGrossSellableAreaGSA__c, 
                               Unit__r.GrossFloorAreaGFA__c, Unit__r.Number_of_Bedrooms__c, 
                               Unit__r.NumberofAllocatedParking__c, Unit__r.NumberofBedrooms__c, 
                               Unit__r.AED_SQM__c, Unit__r.Category__c, Unit__r.District__c, 
                               Unit__r.FacadeStyle__c,Unit__r.FacadeType__c, Unit__r.FloorNumber__c, 
                               Unit__r.Internal_Area__c, Unit__r.Model__c,Unit__r.PlotAreasqm__c, 
                               Unit__r.Project_Launch_Date__c,  
                               Unit__r.Typology__c,Unit__r.Unit_Sold_Date__c,  
                               Unit__r.View__c, Unit__r.Zone__c,Unit__r.Phase__c, Unit__r.Phase__r.EstimatedCompletionDate__c, 
                               Unit__r.Phase__r.EstimatedHandoverDate__c, CustomerAccount__c, JO1__c, JO1__r.Name,JO2__c, 
                               JO2__r.Name,JO3__c, JO3__r.Name,JO4__c, JO4__r.Name,JO5__c, JO5__r.Name,JO6__c, JO6__r.Name, 
                               PrimaryContact__r.Email, JO1__r.Email, JO2__r.Email, 
                               JO3__r.Email, JO4__r.Email, JO5__r.Email, JO6__r.Email,
                               Unit__r.Unit_Image_URL__c,Unit__r.DPG_Unit_Image_URL__c,Owner.Name, Owner.Email, 
                               Owner.Phone, Unit__r.Phase__r.EscrowAccount__r.MerchantID__c, ADM_Registration_Status__c,
                               UAE_Resident_Status__c, Nationality__c,
                               SOCreationDate__c, SPACustomerSignedDate__c, ProjectName__c, TotalAmount__c,
                               CustomerAccount__r.EmailID__c, CustomerAccount__r.Masked_Phone__c, CustomerAccount__r.UnifiedNumber__c, 
                               CustomerAccount__r.NumberPC__c,
                               CustomerAccount__r.PersonMailingAddress, Unit__r.Type__c, CustomerAccount__r.Name, CustomerAccount__r.Customer_MID__c,
                               FormulaAccountName__c, CustomerType__c, Unit__r.Name, Unit__r.UnitClassification__c, Unit__r.PlotNo__c,
                               Unit__r.Project_Name__c, Unit__r.ADM_Plot_Number__c, Unit__r.Building_Name__c,
                               Unit__r.Phase__r.Project__c, Unit__r.Phase__r.Name, Unit__r.Phase__r.Project__r.Project_Location__c,
                               VirtualAccount__r.ESCROWAccountName__c, VirtualAccount__r.Escrow_Bank_Name__c,
                               VirtualAccount__r.VirtualIBANNumber__c, VirtualAccount__r.Swift_Code__c,
                               VirtualAccount__r.VirtualAccountNumber__c
                        FROM SalesOrder__c
                        WHERE Id IN :set_salesOrderId
                    ];

        // -----------------------------
        // Joint Owners (ordered + unique)
        // -----------------------------
        List<JointOwner__c> lst_jo = [SELECT JointOwnerAccount__r.Name, SalesOrder__c FROM JointOwner__c WHERE SalesOrder__c IN :set_salesOrderId
              						  AND JointOwnerAccount__c != null ORDER BY CreatedDate];
        for(JointOwner__c obj_JO : lst_jo){
            if(!map_JO.containsKey(obj_JO.SalesOrder__c)){
                List<JointOwner__c> lst_tmpJO = new List<JointOwner__c>();
                lst_tmpJO.add(obj_JO);
                map_JO.put(obj_JO.SalesOrder__c, lst_tmpJO);
            } else {
                map_JO.get(obj_JO.SalesOrder__c).add(obj_JO);
            }
        }
		
        //2.1 changes
        lst_PayemntSales = [SELECT Id, Applied_Percentage__c, Name, InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c,
                                   InvoiceStatus__c, InvoiceDate__c, SalesOrderInstallment__c, SalesOrderInstallment__r.SalesOrder__c,
                                   SalesOrderInstallment__r.Milestone__c, SalesOrderInstallment__r.MilestoneDescription__c,
                                   SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.MilestoneDate__c,
                                   SalesOrderInstallment__r.PaymentStatus__c, SalesOrderInstallment__r.IsHandoverPayment__c,
                                   (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,
                                           Receipt__r.Receipt_Amount__c,Receipt__r.EBS_Clearing_Date__c, Receipt__r.TransactionNumber__c, 
                                           Receipt__r.Status__c
                                    FROM Allocations__r
                                    WHERE Status__c ='Applied' and Receipt__r.Status__c = 'Cleared')
                                    FROM Invoice__c
                                    WHERE SalesOrderInstallment__c != null
                                      AND SalesOrderInstallment__r.SalesOrder__c IN :set_salesOrderId
                                    ORDER BY SalesOrderInstallment__r.MilestoneNumber__c];
        
        for(Invoice__c obj_Invoice : lst_PayemntSales){
            set_InvoiceIds.add(obj_Invoice.Id);
            if(String.isNotBlank(obj_Invoice.SalesOrderInstallment__c)){
                set_SOIIds.add(obj_Invoice.SalesOrderInstallment__c);
            }            
            if(!map_PaymentSales.containsKey(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c)){
                List<Invoice__c> lst_tmpInvoice = new List<Invoice__c>();
                lst_tmpInvoice.add(obj_Invoice);
                map_PaymentSales.put(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c, lst_tmpInvoice);
            } else {
                map_PaymentSales.get(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c).add(obj_Invoice);
            }
        }
        
        lst_OtherPayemntSales = [SELECT Id, Sales_Order__c, Applied_Percentage__c, Name, Charge__c, Charge__r.Name, Charge__r.Type__c,
                                   Charge__r.PaymentStatus__c, Charge__r.Paid_Amount__c, Charge__r.Remaining_Amount__c,
                                   InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c, InvoiceStatus__c, InvoiceDate__c,
                                   Is_ADM_Fees_and_Dari_charges__c, SalesOrderInstallment__c,
                                   (SELECT Id, AllocationAmount__c, ApprovedReceiptAmount__c, AllocationDate__c, Status__c,
                                           Receipt__r.TransactionNumber__c, Receipt__r.EBS_Clearing_Date__c, Receipt__r.Status__c,
                                           Receipt__r.Receipt_Amount__c
                                    FROM Allocations__r
                                    WHERE Status__c ='Applied' and Receipt__r.Status__c = 'Cleared')
                                    FROM Invoice__c
                                    WHERE SalesOrderInstallment__c = null AND Sales_Order__c IN :set_salesOrderId];
        
        for(Invoice__c obj_Invoice : lst_OtherPayemntSales){
            set_InvoiceIds.add(obj_Invoice.Id);
            if(!map_OtherPayemntSales.containsKey(obj_Invoice.Sales_Order__c)){
                List<Invoice__c> lst_tmpInvoice = new List<Invoice__c>();
                lst_tmpInvoice.add(obj_Invoice);
                map_OtherPayemntSales.put(obj_Invoice.Sales_Order__c, lst_tmpInvoice);
            } else {
                map_OtherPayemntSales.get(obj_Invoice.Sales_Order__c).add(obj_Invoice);
            }
        }
        
        Decimal NEGATIVE_THRESHOLD = 0.0;
        lst_FuturPayemntSales = [SELECT Id, Name, InvoiceDate__c, InvoiceAmount__c, InvoiceBalance__c, InvoiceStatus__c,
                                   Is_ADM_Fees_and_Dari_charges__c, Charge__r.Name,
                                   SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneDate__c,SalesOrderInstallment__r.SalesOrder__c,
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
                                    AND SalesOrderInstallment__r.SalesOrder__c IN :set_salesOrderId];
		
        for(Invoice__c obj_Invoice : lst_FuturPayemntSales){
            if(!map_FuturPayemntSales.containsKey(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c)){
                List<Invoice__c> lst_tmpInvoice = new List<Invoice__c>();
                lst_tmpInvoice.add(obj_Invoice);
                map_FuturPayemntSales.put(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c, lst_tmpInvoice);
            } else {
                map_FuturPayemntSales.get(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c).add(obj_Invoice);
            }
        }
        
        map_PayDisplayFlag = getInvoicePaymentDetails(set_InvoiceIds, set_SOIIds);
        
        for(SalesOrder__c obj_SO : lst_SO){
            SOAWrapper result = new SOAWrapper();
            
            result.salesOrder = obj_SO;
            
            if(map_JO.containsKey(obj_SO.Id)){
                List<JointOwner__c> joList = map_JO.get(obj_SO.Id);
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
            }
            
            if(map_PaymentSales.containsKey(obj_SO.Id)){
                result.PayemntSalesList = map_PaymentSales.get(obj_SO.Id);
            }
            
            if(map_OtherPayemntSales.containsKey(obj_SO.Id)){
                result.otherPayemntSalesList = map_OtherPayemntSales.get(obj_SO.Id);
            }
            
            if(map_PayDisplayFlag.containsKey(obj_SO.Id)){
                result.PayDisplayFlag = map_PayDisplayFlag.get(obj_SO.Id);
            }
            
            if(map_FuturPayemntSales.containsKey(obj_SO.Id)){
                List<Invoice__c> newt = map_FuturPayemntSales.get(obj_SO.Id);
                list<Invoice__c> invFinalList= new list<Invoice__c>();
                Set<Id> addedInvIds = new Set<Id>();
        		Set<Id> futureListReceiptIds = new Set<Id>();
                
                result.FutureMilestoneOtherPayments = new List<Invoice__c>();
                //System.debug('>>>>>>>>> newt >>>> '+System.JSON.serialize(newt));
                for (Invoice__c inv : newt) {
                     Date msDate = (inv.SalesOrderInstallment__r != null) ? inv.SalesOrderInstallment__r.MilestoneDate__c : null;
                     Boolean candidate = false;
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
                        addedInvIds.add(inv.Id);
        
                        if (inv.Allocations__r != null) {
                            for (Allocation__c alloc : inv.Allocations__r) {
                                if (alloc.Receipt__c != null) futureListReceiptIds.add(alloc.Receipt__c);
                            }
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
    
            List<Invoice__c> tempPaymentSales = new List<Invoice__c>();
            tempPaymentSales = map_PaymentSales.get(obj_SO.Id)!=null?map_PaymentSales.get(obj_SO.Id):new List<Invoice__c>();
            System.debug('>>>>>>>>>>>>>>>  Size >>>> '+tempPaymentSales.size());
            // Installment totals
            for (Invoice__c invRec : tempPaymentSales) {
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
                if (invRec.SalesOrderInstallment__r != null && invRec.SalesOrderInstallment__r.MilestoneDate__c != null
                    && invRec.SalesOrderInstallment__r.MilestoneDate__c < System.today()) {
                    totalAmountOutstanding += balance;
                }
            }
    
            List<Invoice__c> tempOtherPaymentSales = new List<Invoice__c>();
            tempOtherPaymentSales = map_OtherPayemntSales.get(obj_SO.Id)!=null? map_OtherPayemntSales.get(obj_SO.Id):new List<Invoice__c>();
            System.debug('>>>>>>>>>>>>>>>  Size >>>> '+tempOtherPaymentSales.size());
            // Other payment totals (non-installment invoices)
            for (Invoice__c invORec : tempOtherPaymentSales) {
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
    		List<Invoice__c> tempFuturPaymentSales = new List<Invoice__c>();
            tempFuturPaymentSales = result.FutureMilestoneOtherPayments!=null? result.FutureMilestoneOtherPayments:new List<Invoice__c>();
            System.debug('>>>>>>>>>>>>>>>  Size >>>> '+tempFuturPaymentSales.size());
            for (Invoice__c futureInv : tempFuturPaymentSales) {
                if (futureInv.Allocations__r == null) continue;
    
                Decimal allocatedAmt = 0;
                Decimal totalAmt = 0;
    			
                List<Allocation__c> tempAllocateAmtList = new List<Allocation__c>();
                tempAllocateAmtList = futureInv.Allocations__r!=null? futureInv.Allocations__r:new List<Allocation__c>();
                System.debug('>>>>>>>>>>>>>>> tempAllocateAmtList Size >>>> '+tempAllocateAmtList.size());
                for (Allocation__c alloc : tempAllocateAmtList) {
                    if (alloc.Receipt__c == null || alloc.Receipt__r == null) continue;
    
                    if (countedFutureReceiptIds.contains(alloc.Receipt__c)) continue;
                    
                    countedFutureReceiptIds.add(alloc.Receipt__c);
    
                    allocatedAmt += (alloc.Receipt__r.AppliedAmount__c == null ? 0 : alloc.Receipt__r.AppliedAmount__c);
    
                    if (alloc.Receipt__r.Status__c == 'Cleared' ) {
                        totalAmt += (alloc.Receipt__r.Receipt_Amount__c == null ? 0 : alloc.Receipt__r.Receipt_Amount__c);
                    }
                }
    
                Decimal balance = totalOtherAmountOutstanding;
                List<Allocation__c> tempAllocateBalanceList = new List<Allocation__c>();
                tempAllocateBalanceList = futureInv.Allocations__r!=null? futureInv.Allocations__r:new List<Allocation__c>();
                System.debug('>>>>>>>>>>>>>>> tempAllocateBalanceList Size >>>> '+tempAllocateBalanceList.size());
                for (Allocation__c alloc : tempAllocateBalanceList) {
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
            if(result.FutureMilestoneOtherPayments != null && result.FutureMilestoneOtherPayments.size() > 0){
                if(result.otherPayemntSalesList == null){
                    List<Invoice__c> lst_tmpInvoice = new List<Invoice__c>();
                    result.otherPayemntSalesList = lst_tmpInvoice;
                }
                result.otherPayemntSalesList.addAll(result.FutureMilestoneOtherPayments);
            }
            lst_Result.add(result);
        }
        
        return lst_Result;
    }

    private static Map<Id, List<PayDisplayFlagType>> getInvoicePaymentDetails(Set<Id> set_InvoiceIds, Set<Id> set_SOIIds){
        Map<Id, List<PayDisplayFlagType>> map_PayDisplayFlag = new Map<Id, List<PayDisplayFlagType>>();
        Date twoWeeksBefore = System.today().addDays(-14);
        Date twoWeeksAfter = System.today().addDays(14);
        
        if (set_InvoiceIds == null || set_InvoiceIds.isEmpty()) {
            return map_PayDisplayFlag;
        }
        try{
            if(set_InvoiceIds.isEmpty()){
                return null;
            }
            
            Map<Id, DirectDebit_Transactions__c> map_DDT = new Map<Id, DirectDebit_Transactions__c>();
            Map<Id, Invoice__c> map_IFInvoices = new Map<Id, Invoice__c>();
            
            List<Invoice__c> lst_AllInvoices = [SELECT Id, Name, SalesOrderInstallment__c, Sales_Order__c, 
                                                SalesOrderInstallment__r.SalesOrder__c, 
                                                SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c, 
                                                Sales_Order__r.UAE_Resident_Status__c, InvoiceDate__c, ReceiptOnlineAppliedAmount__c,
                                                InvoiceBalance__c
                                                FROM Invoice__c WHERE Id IN :set_InvoiceIds WITH SYSTEM_MODE];
            
            List<Invoice__c> lst_Invoices = [SELECT Id, Name, InvoiceDate__c, ReceiptOnlineAppliedAmount__c, InvoiceBalance__c,
                                               (SELECT Id FROM Allocations__r
                                                WHERE Receipt__r.Status__c = 'Bounced' 
                                                AND Receipt__r.Cheque_Bounce_Reason__c = 'Insufficient Funds' 
                                                AND Receipt__r.Modeofpayment__c = 'Cheque')
                                                FROM Invoice__c
                                                WHERE InvoiceStatus__c != 'Paid' AND Id IN :set_InvoiceIds WITH SYSTEM_MODE];
            for(Invoice__c objInvoice : lst_Invoices){
                    if(!map_IFInvoices.containsKey(objInvoice.Id) && objInvoice.Allocations__r != null 
                       && objInvoice.Allocations__r.size() > 0){
                       map_IFInvoices.put(objInvoice.Id, objInvoice); 
                    }
            }
            if (set_SOIIds != null && !set_SOIIds.isEmpty()) {
                List<DirectDebit_Transactions__c> lst_DDT = [
                    SELECT Id, SOInstallment__c, Rejection_Reason__c 
                    FROM DirectDebit_Transactions__c 
                    WHERE Request_Type__c = 'Collection' 
                    AND Transaction_Status__c != 'Success'
                    AND SOInstallment__c IN :set_SOIIds
                    WITH SYSTEM_MODE
                ];
                
                for (DirectDebit_Transactions__c obj_DDT : lst_DDT) {
                    if (obj_DDT.SOInstallment__c != null && 
                        !map_DDT.containsKey(obj_DDT.SOInstallment__c) && 
                        'I'.equalsIgnoreCase(obj_DDT.Rejection_Reason__c)) {
                        map_DDT.put(obj_DDT.SOInstallment__c, obj_DDT); 
                    }
                }
            }
            
            for(Invoice__c obj_Invoice : lst_AllInvoices){
                
                if (String.isBlank(obj_Invoice.Sales_Order__c) && String.isBlank(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c)) {
                    continue;
                }
                
                Id salesOrderId = String.isNotBlank(obj_Invoice.Sales_Order__c)?obj_Invoice.Sales_Order__c : 
                				     obj_Invoice.SalesOrderInstallment__r.SalesOrder__c;
                String UAEResidenceStatus = String.isNotBlank(obj_Invoice.Sales_Order__c)?obj_Invoice.Sales_Order__r.UAE_Resident_Status__c : 
                				     obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c;
                    
                PayDisplayFlagType obj_PayDisplay = new PayDisplayFlagType();
                obj_PayDisplay.InvoiceId = obj_Invoice.Id;
                obj_PayDisplay.InvoiceName = obj_Invoice.Name;
                
                Boolean hasRejectedDD = String.isNotBlank(obj_Invoice.SalesOrderInstallment__c) && map_DDT.containsKey(obj_Invoice.SalesOrderInstallment__c);
                Boolean isIFInvoice = map_IFInvoices.containsKey(obj_Invoice.Id);
                Boolean isNonUAEResident = String.isNotBlank(UAEResidenceStatus) && UAEResidenceStatus.equals('Non-Resident');
                Boolean isWithInRange = obj_Invoice.InvoiceDate__c > twoWeeksAfter || obj_Invoice.InvoiceDate__c < twoWeeksBefore;
                Boolean checkBalanceAmount = (obj_Invoice.InvoiceBalance__c - obj_Invoice.ReceiptOnlineAppliedAmount__c) > 0;
                obj_PayDisplay.PayEnableFlag = (hasRejectedDD || isIFInvoice || isNonUAEResident) && isWithInRange && checkBalanceAmount;
                
                if (!map_PayDisplayFlag.containsKey(salesOrderId)) {
                    map_PayDisplayFlag.put(salesOrderId, new List<PayDisplayFlagType>());
                }
                map_PayDisplayFlag.get(salesOrderId).add(obj_PayDisplay);
           } 
            
        }catch(Exception exe){
            System.debug(LoggingLevel.ERROR, '>>>> Error in getInvoicePaymentDetails: ' + exe.getMessage());
            System.debug(LoggingLevel.ERROR, '>>>> Stack Trace: ' + exe.getStackTraceString());
        }
        return map_PayDisplayFlag;
    }
    public class SOAWrapper {
        @AuraEnabled public SalesOrder__c salesOrder;
        @AuraEnabled public List<Invoice__c> PayemntSalesList;
        @AuraEnabled public List<Invoice__c> otherPayemntSalesList;
        @AuraEnabled public List<Invoice__c> FutureMilestoneOtherPayments;
        @AuraEnabled public List<PayDisplayFlagType> PayDisplayFlag;
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
    public class PayDisplayFlagType{
        @AuraEnabled public String InvoiceId;
        @AuraEnabled public String InvoiceName;
        @AuraEnabled public Boolean PayEnableFlag;
    }
}