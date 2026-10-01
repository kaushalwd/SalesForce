/**********************************************************************************************************************
* Name               : AllocationTriggerHelper                                                        
* Description        : This class is helper for Allocation trigger
* Usage              : Called from AllocationTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         15 Jan 2024     Initial Draft    
* 2.0           Shahil Sinha (Horizontal)        27 Nov 2025     Modon Egypt: Added manageCurrencyISOCode method to set currency ISO code for Egypt allocations with multi-currency support 
* 2.1           Shahil Sinha (Horizontal)        23 Dec 2025     Modon Egypt: Added getAccurateAmount method to calculate the accurate amount for Egypt allocations with multi-currency support
* 2.2           Shahil Sinha (Horizontal)        06 Jan 2026     Updated to use ConversionRateWrapper for currency conversion
* 2.3           Shahil Sinha (Horizontal)        07 Jan 2026     Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
* 3.0			Manoj							 26 Jan 2025	 Un Applied Allocation and Ebs Sync
* 4.0           Dselvam                          13 Apr 2026     Added Buffer Amount Clearance Logic to Re-calc ADM & DP
* 5.0			Manoj							 05 May 2026	 Add Source_Entity__c in logic
* 6.0			Manoj							 24 May 2026	 Add bypass
******************************************************************************************************************/
public without sharing class AllocationTriggerHelper {
    public static void manageReceiptAmount(List<sObject> newList){        
        for(Allocation__c allObj :(List<Allocation__c>) newList){
            if(allObj.IsReceiptCancelled__c ){
                allObj.InProgressReceiptAmount__c = 0;
                allObj.ApprovedReceiptAmount__c = 0;
            }else{
                if(allObj.IsReceiptOpen__c){
                    allObj.InProgressReceiptAmount__c = allObj.AllocationAmount__c;
                    allObj.ApprovedReceiptAmount__c = 0;
                }else{
                    allObj.ApprovedReceiptAmount__c = allObj.AllocationAmount__c;
                    allObj.InProgressReceiptAmount__c = 0;
                }
            }  //2.0 Unapplid logic          
            if(allObj.Status__c == 'Unapplied'){
                allObj.InProgressReceiptAmount__c = 0;
                allObj.ApprovedReceiptAmount__c = 0;
                allObj.AllocationAmount__c =0;
            }
        }
    }
    /** 3.0
 * Handles updates to Allocation records when the Unapplied Amount changes.
 * If an Allocation's status changes to 'Unapplied' and it has an Oracle Party Id,
 * the Allocation Id is collected and sent to Oracle asynchronously.
 *
 * @param newList List of Allocation records after update
 * @param oldMap  Map of Allocation records before update
 */
    public static void handleUnAppliedAmountUpdate(List<sObject> newList,Map<Id,sObject> oldMap){
        Set<String> set_allocId = new Set<String>();
        for(Allocation__c alloc:(List<Allocation__c>)newList){
            Allocation__c oldRecord = oldMap <> null ? (Allocation__c) oldMap.get(alloc.Id):null;
            if(alloc.Status__c == 'Unapplied' && alloc.OraclePartyId__c != null && oldRecord <> null && alloc.Status__c <> oldRecord.Status__c){
                set_allocId.add(alloc.id);
            }
        }
        if(!set_allocId.isEmpty() && !TriggerControl.BypassCancelledTrigger){ // 6.0
           sendUnAllocationToOracle_Future(set_allocId);
        }
    }
    
    public static void handleAppliedAmountUpdate(List<sObject> newList,Map<Id,sObject> oldMap){
        Set<Id> invoiceIdset = new Set<Id>();
        for(Allocation__c alloc:(List<Allocation__c>)newList){
        	//4.0
            Allocation__c oldRecord = oldMap <> null ? (Allocation__c) oldMap.get(alloc.Id):null;
            if(alloc.AllocationAmount__c <> null && (oldRecord == null || (oldRecord <> null && ((alloc.AllocationAmount__c <> oldRecord.AllocationAmount__c) || (alloc.ApprovedReceiptAmount__c <> oldRecord.ApprovedReceiptAmount__c))))){ /** Added Buffer Amount Clearance Logic to Re-calc ADM & DP **///4.0
                invoiceIdset.add(alloc.Invoice__c);
            }
        }
        if(!invoiceIdset.isEmpty()){
            Set<Id> SalesOrderIdADMFee = new Set<Id>();
            Set<Id> SalesOrderIddownpayment = new Set<Id>();
			// 4.0
            for(Invoice__c inv:[SELECT Id,SalesOrderInstallment__c,Is_ADM_Fees_and_Dari_charges__c,SalesOrderInstallment__r.MilestoneNumber__c,SalesOrderInstallment__r.SalesOrder__c,Sales_Order__c,SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c,Sales_Order__r.Source_Entity__c FROM Invoice__c where RecordType.name NOT IN ('Debit Memo','Credit Memo') and Id IN: invoiceIdset  ]){
                if(inv.Is_ADM_Fees_and_Dari_charges__c == true && inv.Sales_Order__r.Source_Entity__c != 'Modon - Egypt'){ //6.0
                    SalesOrderIdADMFee.add(inv.Sales_Order__c);
                }
                if(inv.SalesOrderInstallment__c <> null && inv.SalesOrderInstallment__r.MilestoneNumber__c == 1 && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt'){ //4.0
                    SalesOrderIddownpayment.add(inv.SalesOrderInstallment__r.SalesOrder__c);
                }
            }
            if(!SalesOrderIdADMFee.isEmpty()){
                SalesOrderStatusAutomationHelper.checkADMFeeDariFeeStatus(SalesOrderIdADMFee);
            }
             if(!SalesOrderIddownpayment.isEmpty()){
                SalesOrderStatusAutomationHelper.checkDownPaymentStatus(SalesOrderIddownpayment);
            }
        }
    }
    /**
 * Future method to send Unapplied Allocation records to Oracle.
 * This method performs a callout and therefore runs asynchronously.
 *
 * @param recIds Set of Allocation record Ids that need to be sent to Oracle
 */
    @future(callout = true)
    public static void sendUnAllocationToOracle_Future(set<string> recIds){
        OIC_ManageEbsDataController.createUnAppliedAllocation(recIds);
    }
	
    //v2.0 (line 33 - 95)
    public static void manageCurrencyISOCode(List<sObject> newList) {
        List<Allocation__c> allocations = (List<Allocation__c>) newList;
        Set<Id> invoiceIds = new Set<Id>();
        Set<Id> receiptIds = new Set<Id>();
    
        for (Allocation__c allObj : allocations) {
            if (allObj.Invoice__c != null) invoiceIds.add(allObj.Invoice__c);
            if (allObj.Receipt__c != null) receiptIds.add(allObj.Receipt__c);
        }
        
        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>(
            [SELECT Id, CurrencyIsoCode, SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c, 
                InvoiceAmount__c, InvoiceBalance__c,
                Installment_Amount__c, Maintenance_Amount__c,
                Applied_InstallmentAmount__c, Applied_MaintenanceAmount__c
                FROM Invoice__c
                WHERE Id IN :invoiceIds
            ]
        );

        /* 
        * Currency conversion logic: 
        * Conversion will only be applied if the related Invoice's Sales Order Installment's 
        * Source Entity is Modon Egypt (to support multi-currency for Egypt allocations)
        */
        if (!invoiceMap.isEmpty() && invoiceMap.values()[0].SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c == 'Modon - Egypt') {     
            Map<Id, Receipt__c> receiptMap = new Map<Id, Receipt__c>(
                [SELECT Id, CurrencyIsoCode FROM Receipt__c WHERE Id IN :receiptIds]
            );
        
            // Apply conversion and set ISO codes
            for (Allocation__c allObj : allocations) {
                String source = receiptMap.get(allObj.Receipt__c)?.CurrencyIsoCode;
                String target = invoiceMap.get(allObj.Invoice__c)?.CurrencyIsoCode;
                
                allObj.CurrencyISOCode = invoiceMap.containsKey(allObj.Invoice__c) ? target : allObj.CurrencyISOCode;

                // Calculate effective balance by subtracting already applied amounts
                Invoice__c inv = invoiceMap.get(allObj.Invoice__c);
                Decimal invoiceBalance = allObj.isMaintenance__c
                    ? ((inv.Maintenance_Amount__c != null ? inv.Maintenance_Amount__c : 0) 
                       - (inv.Applied_MaintenanceAmount__c != null ? inv.Applied_MaintenanceAmount__c : 0))
                    : ((inv.Installment_Amount__c != null ? inv.Installment_Amount__c : 0) 
                       - (inv.Applied_InstallmentAmount__c != null ? inv.Applied_InstallmentAmount__c : 0));

                if (source != null && target != null) {
                    //v2.2 (line - 80) Updated to use ConversionRateWrapper for currency conversion
                    ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(source, target);
                    if (rateWrapper == null) { 
                        allObj.addError('Currency conversion rate not found for ' + source + 
                                                    ' to ' + target + ' for today. Please contact system administrator.');
                        continue;
                    }
                    Decimal rate = rateWrapper.conversionRate;
                    //Apply Conversion
                    allObj.Allocation_Amount_in_Receipt_Currency__c = allObj.AllocationAmount__c != null ? allObj.AllocationAmount__c : 0;
                    allObj.AllocationAmount__c = allObj.AllocationAmount__c != null ? getAccurateAmount(invoiceBalance, allObj.AllocationAmount__c, rate) : 0;
                    allObj.ApprovedReceiptAmount__c = allObj.ApprovedReceiptAmount__c != null ? getAccurateAmount(invoiceBalance, allObj.ApprovedReceiptAmount__c, rate) : 0;
                    allObj.InProgressReceiptAmount__c = allObj.InProgressReceiptAmount__c != null ? getAccurateAmount(invoiceBalance, allObj.InProgressReceiptAmount__c, rate) : 0;
                }
            }
        }    
    }

    ////v2.1 (line 99 - 106)
    //converting allocationAmount from receipt currency to invoice currency and checking if the decimal difference is between a range then passing invoice balance to allocationAmount
    private static Decimal getAccurateAmount(Decimal invoiceBalance, Decimal allocationAmount, Decimal rate) {
       //v2.3 (line 102) Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
        Decimal convertedAmount = (allocationAmount * rate);
        if (Math.abs(invoiceBalance - convertedAmount) <= ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD) {
            return invoiceBalance;
        }
        return convertedAmount;
    }
}