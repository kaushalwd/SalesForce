/**********************************************************************************************************************
 * Name               : ReceiptTriggerHelper
 * Description        : This class is helper for Receipt trigger
 * Usage              : Called from ReceiptTriggerHandler
 * Created By         : PWC Digital Middle East
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           prateek.b.bansal@pwc.com         12 Jan 2024     Initial Draft
 * 2.0           mdixit@horizontal.com            11-10-2025      Added lines 477-488(To support mutlicurrency for Egypt)
 * 3.0           Manoj							  20-10-2025        Update the cutoffdata
 * 4.0           Shahil Sinha (Horizontal)        27-11-2025      Handled allocation for Modon - Egypt with multi-currency conversion starting from specific milestone
 * 4.1           Shahil Sinha (Horizontal)        22-12-2025      Created separate class for Currency conversion rate management
 * 4.2           Shahil Sinha (Horizontal)        31-11-2025      Handled allocation for Modon - Egypt -> Added check for receipt type and handling Installment and Maintenance receipts accordingly
 * 4.3           Shahil Sinha (Horizontal)        06-01-2026      Updated to use ConversionRateWrapper for currency conversion
 * 4.4           Shahil Sinha (Horizontal)        07-01-2026      Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
 * 4.5           Shahil Sinha (Horizontal)        13-01-2026      passEgyptReceipts - Updated logic to restrict EOI Receipts sync when reeipts gets created
 * 4.6           Shahil Sinha (Horizontal)        16-01-2026      checkReceiptMethodAndRemittanceBankAccountNumber - Added this method to check of the Payment mode is supported or not. (Modon Egypt only)
 * 4.7           Shahil Sinha (Horizontal)        22-01-2026      Added Threshold check
 * 5.0			 Gautam Mishra (Horizontal)		  23-01-2026	  Modon Egypt: Added code for inserting Receipt in Oracle 
 * 5.1			 Gautam Mishra (Horizontal)		  23-01-2026	  Modon Egypt: Added code for updating Receipt in Oracle
 * 5.2           Shahil Sinha (Horizontal)        29-01-2026      Fixed allocation bug for Modon Egypt: Added egyptSoiReceiptMap to support 

 *                                                                 multiple receipts per SOI (Installment + Maintenance). Original soiReceiptMap 

 *                                                                 was overwriting receipts, causing only Maintenance allocations.

 * 5.3           Milin Kapatel (Horizontal)        06-02-2026      Updated Validation check from Bank to MIRE bank for Modon Egypt in checkReceiptMethodAndRemittanceBankAccountNumber method
 * * 5.4           Milin Kapatel (Horizontal)        06-02-2025      Introduced method to rollUp Sum of all related receipts's Total Amount which has mode of payment as 'Cheque' to Sales Order on Updating and Creation.

 * 6.0           Dinesh Selvam                    30-11-2025      Added "NULL" check while creating the Receipt Allocation
 * 7.0           Manoj                            21-12-2025      Added logic to update the status to Confirmed,Cancelled, Bounced, or Returned to customer 
 * 8.0           kumar                            14-1-2026       Remove the logic for approved and apex method manageCancelledReceipts 
 * 9.0           Suresh							  22-01-2026		 Update Unidentified Receipt and Ebs sync
 * 10.0          Dinesh                           14-02-2026      Fix the total paid amount calculation in SO Level
 * 10.1          Dinesh                           16-02-2026      Fix the receipt 101 SOQL Exception
 * 11.0           Shahil Sinha (Horizontal)         26-02-2025      Updated rollUpChequeTotalAmountToSO to also populate EgyptChequeReceiptTotalAmountInWords__c directly, bypassing SO trigger recursion guard.
 * 12.0           Milin Kapatel (Horizontal)        06-03-2026     Updated rollUpChequeTotalAmountToSO to use utilities class for amount in words
 * 13.0			Manoj								25-03-2026	  Update bypass the status update on OraclePartyId
 * 14.0           Gautam Mishra (Horizontal)       09-04-2026     Added constants for all constant values and also updated these passEgyptReceipts and updateEgyptReceiptsToOracle methods
 * 15.0           Gautam Mishra (Horizontal)       14-04-2026     Updated SOQL and other code part in passEgyptReceipts method
 * 16.0           Milin Kapatel (Horizontal)       22-04-2026     Updated rollUpChequeTotalAmountToSO to use convertAmountInWordsTextEnglish instead of amountInWords
 * 17.0		      Manoj							   10-05-2026	  Update Excess Amount refound logic
 * 18.0			  Manoj							   22-05-2026	  Add the logic for fusion sync
 * 19.0           Shahil Sinha                      08 Jun 2026     Added trigger bypass checks for Egypt Payment Plan Swap
 * 20.0           Milin Kapatel (Horizontal)       18 Jun 2026     Excuding Cancelled Receipts from rollUpChequeTotalAmountToSO method for Modon Egypt 
 * 21.0          Narendra Agrawal (Horizontal)     29 Jun 2026     Pre Bulk-load SOI and invoice data once per transaction (avoids SOQL 101 in handleModonEgyptAllocation method)
 * 22.0          Mirza Baig                        17 July 2026    Prevent duplicate Modon Egypt receipts based on cheque and transaction numbers.
 * 23.0          Shahil Sinha (Horizontal)         21 July 2026    Updated passEgyptReceipts to allow receipts for any milestone to sync to Oracle once Downpayment is Collected/Cleared or SPA is Signed.
 * 24.0 		Modon IT							27 Jul 2026	   IBAN Placeholder copy creation 
 * 25.0 		Karunakar Pulkam					10 Aug 2026		IBAN Validation Service
 * 25.1			Karunakar 							13 Aug 2026		Union Primary Contact and Account
 * 25.2			Siva 							13 Aug 2026		    Old Default Process Remove
 * 26.0          Horizontal                     31 Aug 2026      Bulkify PDF/email, null/list guards, surface DML errors
 * 26.1         Suresh                          24 Sep 2026      Updated the Allocation flag to identify payments made online through Modon Connect.
 ******************************************************************************************************************/
public without sharing class ReceiptTriggerHelper {
    
    public static void updateSalesOrderDetails(Map<Id, SObject> newMap){
        
        Set<id> set_SalesOrderIds = new Set<id>();
        string RegIdsLable = System.Label.Salesorderpayments_Values;
        list<string> StatusValues = new list<string>();
        Map<id, List<Receipt__c>> map_SalesOrderReceipts = new Map<id, List<Receipt__c>>();
        Map<id, SalesOrder__c> map_SalesOrders = new Map<id, SalesOrder__c>();
        Set<id> set_ReceiptIds = new Set<id>();
        Map<id, Decimal> map_SalesOrderTotalAmount = new Map<id, Decimal>();
        Map<id, String> map_SalesOrderCollectDownPaymentStatus = new Map<id, String>();
        Set<string> SendtoEbsSoIds =new set<string>(); //18.0
        if(RegIdsLable.contains(',')){
            StatusValues = RegIdsLable.split(',');
        }else{
            if(!RegIdsLable.contains('null') ){
                StatusValues =new List<String>{RegIdsLable};
            }
            else{
                StatusValues =new List<String>{};
            }
        }
        
        for(String key : newMap.keySet()){
            Receipt__c  obj_Receipt = (Receipt__c )newMap.get(key);
            set_ReceiptIds.add(obj_Receipt.Id);
        }
        List<Receipt__c> lst_Receipts = [select id,Modeofpayment__c,SalesOrderInstallment__r.SalesOrder__c,TotalAmount__c,
                                         SalesOrderInstallment__r.PaymentInstallments__r.Name,
                                         Status__c,SalesOrderInstallment__r.MilestoneNumber__c
                                         from Receipt__c where id in :set_ReceiptIds];
        for(Receipt__c obj_Receipt : lst_Receipts){
            if(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c != null){
                set_SalesOrderIds.add(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c);
                if(!map_SalesOrderCollectDownPaymentStatus.containsKey(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c)
                    && (obj_Receipt.SalesOrderInstallment__r.PaymentInstallments__r.Name == 'Down Payment'
                || obj_Receipt.SalesOrderInstallment__r.MilestoneNumber__c == 1)){
                    map_SalesOrderCollectDownPaymentStatus.put(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c,
                    obj_Receipt.Status__c);
                    SendtoEbsSoIds.add(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c); // 18.0
                }
            }
        }
        System.debug('updateSalesOrderDetails >>>>   '+System.JSON.serialize(set_SalesOrderIds));
        
        List<SalesOrder__c> lst_SalesOrders = [select id, TotalAmount__c from SalesOrder__c where id in :set_SalesOrderIds];
        for(SalesOrder__c obj_SalesOrder : lst_SalesOrders){
            if(!map_SalesOrderTotalAmount.containsKey(obj_SalesOrder.id)){
                map_SalesOrderTotalAmount.put(obj_SalesOrder.id, obj_SalesOrder.TotalAmount__c);
            }
        }
        
        for(Receipt__c  rec : [select id,Modeofpayment__c,SalesOrderInstallment__r.SalesOrder__c,TotalAmount__c,status__c  
                               from Receipt__c where SalesOrderInstallment__r.SalesOrder__c in :set_SalesOrderIds
                               and status__c in :StatusValues]){
            if(map_SalesOrderReceipts.containsKey(rec.SalesOrderInstallment__r.SalesOrder__c)){
                map_SalesOrderReceipts.get(rec.SalesOrderInstallment__r.SalesOrder__c).add(rec);
            } else {
                list<Receipt__c> lst_Receipt = new list<Receipt__c>();
                lst_Receipt.add(rec);
                if(rec.SalesOrderInstallment__r.SalesOrder__c != null){
                    map_SalesOrderReceipts.put(rec.SalesOrderInstallment__r.SalesOrder__c, lst_Receipt);
                }
            }
        }
        
        for(id salesOrderId : map_SalesOrderReceipts.keySet()){
            Integer totalamount=0;
            Decimal fullTotalAmount = 0;
            list<string> paymentmode = new list<string>();
            map<Integer,string> salesamountSum= new map<Integer,string>();
            string modeofpayment = '';
            for(Receipt__c  receipt : map_SalesOrderReceipts.get(salesOrderId)){
                totalAmount += (receipt.TotalAmount__c != null ? Integer.valueOf(receipt.TotalAmount__c) :0 );
                if(!paymentmode.contains(receipt.Modeofpayment__c) ){
                    paymentmode.add(receipt.Modeofpayment__c);
                }
                modeofpayment= paymentmode.size() > 1 ? String.join( paymentmode, ', ' ):paymentmode[0];
            }
            if(map_SalesOrderTotalAmount.get(salesOrderId) != null){
                fullTotalAmount = map_SalesOrderTotalAmount.get(salesOrderId);
            }
            Decimal collectAmountPct = (fullTotalAmount != null && fullTotalAmount != 0)
                ? (totalAmount / fullTotalAmount) * 100
                : 0;
            System.debug('updateSalesOrderDetails >>>> '+totalAmount+'    '+fullTotalAmount+'   '+collectAmountPct);
            if(map_SalesOrderCollectDownPaymentStatus.containsKey(salesOrderId)){
                map_SalesOrders.put(salesOrderId, new SalesOrder__c(Id=salesOrderId,
                Collect_Amount__c=collectAmountPct,
                Modeofpayment__c = modeofpayment,
                Collect_Down_Payment_Status__c = map_SalesOrderCollectDownPaymentStatus.get(salesOrderId)));
            } else {
                map_SalesOrders.put(salesOrderId, new SalesOrder__c(Id=salesOrderId,
                Collect_Amount__c=collectAmountPct,
                Modeofpayment__c = modeofpayment));
            }
            
        }
        
        if(!map_SalesOrders.isEmpty()){
            update map_SalesOrders.values();
            if(!SendtoEbsSoIds.isEmpty() && !TriggerControl.bypassTransferTrigger && !TriggerControl.BypassCancelledTrigger){ // 18.0
                System.enqueueJob(new salesorderQueuableService(SendtoEbsSoIds));
            }
        }
    }

    public static void populateTransactionDate(List<sObject> newList){
        for(Receipt__c receipt : (List<Receipt__c>)newList){
            if(receipt.ChequeDate__c != null){
                receipt.TransactionDate__c = receipt.ChequeDate__c;
            }
        }
    }
    
    public static void createModonEgyptAllocationRecord(Map<Id, sObject> newMap){
        Map<String, String> eoiReceiptMap = new Map<String, String>();
        set<String> eoiSet = new set<String>();
        
        //v5.2 (line 138 - 139) Changed to List to support multiple receipts per SOI (Installment + Maintenance for Modon Egypt)

        //Map<String, String> soiReceiptMap = new Map<String, String>();
		Map<String, List<String>> soiReceiptMap = new Map<String, List<String>>();
        
        Map<String, String> chargeReceiptMap = new Map<String, String>();
        set<String> soiSet = new set<String>();
        set<String> chargeSet = new set<String>();
        // added for ADM Fees + Dari charges
        Map<String, String> soReceiptMap = new Map<String, String>();
        set<String> soSet = new set<String>();
        for(String key : newMap.keySet()){
            Receipt__c recObj = (Receipt__c) newMap.get(key);
            if(String.isNotBlank(recObj.Expressionofinterest__c)){
                eoiReceiptMap.put(recObj.Expressionofinterest__c,key);
                eoiSet.add(recObj.Expressionofinterest__c);
            }else if(String.isNotBlank(recObj.SalesOrderInstallment__c)){
                //v5.2 (line 155- 158) - Support multiple receipts per SOI
                if (!soiReceiptMap.containsKey(recObj.SalesOrderInstallment__c)) {
                    soiReceiptMap.put(recObj.SalesOrderInstallment__c, new List<String>());
                }
                soiReceiptMap.get(recObj.SalesOrderInstallment__c).add(key);
                
                soiSet.add(recObj.SalesOrderInstallment__c);
                // added for ADM Fees + Dari charges
            }else if(String.isNotBlank(recObj.Charge__c)){
                chargeReceiptMap.put(recObj.Charge__c,key);
                chargeSet.add(recObj.Charge__c);
            }else if(String.isNotBlank(recObj.SalesOrder__c) && recObj.Is_ADM_Fees_and_Dari_charges__c == TRUE){
                soReceiptMap.put(recObj.SalesOrder__c,key);
                soSet.add(recObj.SalesOrder__c);
            }
        }
        
        if((!eoiSet.isEmpty() && eoiSet.size() > 0) ||(!chargeSet.isEmpty() && chargeSet.size() > 0) || (!soiSet.isEmpty() && soiSet.size() > 0) || (!soSet.isEmpty() && soSet.size() > 0)){// added for ADM Fees + Dari charges
            Map<String, Invoice__c> eoiInvoiceMap = new Map<String, Invoice__c>();
            Map<String, Invoice__c> soiInvoiceMap = new Map<String, Invoice__c>();
            Map<String, Invoice__c> soInvoiceMap = new Map<String, Invoice__c>();// added for ADM Fees + Dari charges
            Map<String, Invoice__c> chargeInvoiceMap = new Map<String, Invoice__c>();
            List<Allocation__c> allLst = new List<Allocation__c>();
            Map<Id, Invoice__c> invById = new Map<Id, Invoice__c>();
            for(Invoice__c invObj : [SELECT Id,Charge__c,Expressionofinterest__c, SalesOrderInstallment__c,InvoiceAmount__c, InvoiceBalance__c, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c FROM Invoice__c 
                WHERE (Expressionofinterest__c IN : eoiSet OR SalesOrderInstallment__c IN : soiSet OR Sales_Order__c IN : soSet OR Charge__c IN :chargeSet ) AND InvoiceBalance__c > 0]){
                if(String.isNotBlank(invObj.Expressionofinterest__c)){
                    eoiInvoiceMap.put(invObj.Expressionofinterest__c, invObj);
                }else if(String.isNotBlank(invObj.SalesOrderInstallment__c)){
                    soiInvoiceMap.put(invObj.SalesOrderInstallment__c, invObj);
                }else if(String.isNotBlank(invObj.Charge__c)){
                    chargeInvoiceMap.put(invObj.Charge__c, invObj);
                }else if(String.isNotBlank(invObj.Sales_Order__c) && invObj.Is_ADM_Fees_and_Dari_charges__c == TRUE){// added for ADM Fees + Dari charges
                    soInvoiceMap.put(invObj.Sales_Order__c, invObj);
                }
            }
            
            if((eoiInvoiceMap != null && eoiInvoiceMap.size() > 0) || (soiInvoiceMap != null && soiInvoiceMap.size() > 0) || (soInvoiceMap != null && soInvoiceMap.size() > 0) || (chargeInvoiceMap != null && chargeInvoiceMap.size() > 0)){// added for ADM Fees + Dari charges
                if((eoiInvoiceMap != null && eoiInvoiceMap.size() > 0)){
                    for(String key : eoiInvoiceMap.keySet()){
                        Invoice__c invObj = eoiInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(eoiReceiptMap.get(key)) ? (Receipt__c) newMap.get(eoiReceiptMap.get(key)) : null;
                        if (recObj == null) {
                            continue;
                        }
                        
                        Allocation__c allObj = new Allocation__c();
                        allObj.AllocationDate__c = system.today();
                        allObj.Invoice__c = invObj.Id;
                        allObj.Receipt__c = recObj.Id;
                        if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                            allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                            //invObj.Status__c = 'Partially Paid';
                        }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){
                            allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                        } else {
                            allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                            //invObj.Status__c = 'Paid';
                        }
                        allLst.add(allObj);
                        invById.put(invObj.Id, invObj);
                    }
                }
                
                if((soiInvoiceMap != null && soiInvoiceMap.size() > 0)){

                    //(v21 - START)
                    // Pre Bulk-load SOI and invoice data once per transaction (avoids SOQL 101 in handleModonEgyptAllocation method)
                    Map<Id, SalesOrderInstallments__c> egyptSoiById = new Map<Id, SalesOrderInstallments__c>();
                    Map<Id, List<Invoice__c>> egyptInvoicesBySoId = new Map<Id, List<Invoice__c>>();
                    if (!soiSet.isEmpty()) {
                        egyptSoiById = new Map<Id, SalesOrderInstallments__c>([
                            SELECT Id, MilestoneNumber__c, SalesOrder__c
                            FROM SalesOrderInstallments__c
                            WHERE Id IN :soiSet
                        ]);
                        Set<Id> egyptSoIds = new Set<Id>();
                        for (SalesOrderInstallments__c soiRec : egyptSoiById.values()) {
                            if (soiRec.SalesOrder__c != null) {
                                egyptSoIds.add(soiRec.SalesOrder__c);
                            }
                        }
                        if (!egyptSoIds.isEmpty()) {
                            for (Invoice__c invRec : [
                                SELECT Id, InvoiceBalance__c, InvoiceAmount__c, CurrencyIsoCode,
                                    SalesOrderInstallment__r.MilestoneNumber__c,
                                    SalesOrderInstallment__r.SalesOrder__c,
                                    Installment_Amount__c, Maintenance_Amount__c,
                                    Applied_InstallmentAmount__c, Applied_MaintenanceAmount__c
                                FROM Invoice__c
                                WHERE SalesOrderInstallment__r.SalesOrder__c IN :egyptSoIds
                                ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC
                            ]) {
                                Id parentSoId = invRec.SalesOrderInstallment__r.SalesOrder__c;
                                if (!egyptInvoicesBySoId.containsKey(parentSoId)) {
                                    egyptInvoicesBySoId.put(parentSoId, new List<Invoice__c>());
                                }
                                egyptInvoicesBySoId.get(parentSoId).add(invRec);
                            }
                        }
                        ModonEgypt_CurrencyConversion.getTodaysConversionRateMap();
                    }
                    //(v21 - END)

                    for(String key : soiInvoiceMap.keySet()){
                        Invoice__c invObj = soiInvoiceMap.get(key);
                        //v5.2 (line 218 - 246) - Process ALL receipts for each SOI (handles both Installment + Maintenance for Egypt, single receipt for UAE)
                        List<String> receiptIds = soiReceiptMap.get(key);
                        if (receiptIds != null) {
                            for (String receiptId : receiptIds) {
                                Receipt__c recObj = (Receipt__c) newMap.get(receiptId);
                                if (recObj == null) {
                                    continue;
                                }
                                if (recObj.Source_Entity__c == 'Modon - Egypt') {
                                    //(v21 - START)
                                    // Call helper method for Modon - Egypt allocation with multi-currency
                                    List<Allocation__c> egyptAllocations = handleModonEgyptAllocation(
                                        recObj,
                                        recObj.SalesOrderInstallment__c,
                                        egyptSoiById,
                                        egyptInvoicesBySoId
                                    );
                                    //(v21 - END)
                                    if (!egyptAllocations.isEmpty()) {
                                        allLst.addAll(egyptAllocations);   
                                    }
                                } else {
                                    Allocation__c allObj = new Allocation__c();
                                    allObj.AllocationDate__c = system.today();
                                    allObj.Invoice__c = invObj.Id;
                                    allObj.Receipt__c = recObj.Id;
                                    if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                                        allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                                        //invObj.Status__c = 'Partially Paid';
                                    }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){
                                    } else {
                                        allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                                        //invObj.Status__c = 'Paid';   
                                    }
                                    allLst.add(allObj);
                                    invById.put(invObj.Id, invObj); 
                                }
                            } 
                        } 
                    }
                }
                
                if((chargeInvoiceMap != null && chargeInvoiceMap.size() > 0)){
                    for(String key : chargeInvoiceMap.keySet()){
                        Invoice__c invObj = chargeInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(chargeReceiptMap.get(key)) ? (Receipt__c) newMap.get(chargeReceiptMap.get(key)) : null;
                        if (recObj == null) {
                            continue;
                        }
                        
                        Allocation__c allObj = new Allocation__c();
                        allObj.AllocationDate__c = system.today();
                        allObj.Invoice__c = invObj.Id;
                        allObj.Receipt__c = recObj.Id;
                        
                        if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                            allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                            //invObj.Status__c = 'Partially Paid';
                        }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                            allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                        } else {
                            allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                            //invObj.Status__c = 'Paid';
                        }
                        allLst.add(allObj);
                        invById.put(invObj.Id, invObj);
                    }
                }
                
                // added for ADM Fees + Dari charges
                if((soInvoiceMap != null && soInvoiceMap.size() > 0)){
                    for(String key : soInvoiceMap.keySet()){
                        Invoice__c invObj = soInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(soReceiptMap.get(key)) ? (Receipt__c) newMap.get(soReceiptMap.get(key)) : null;
                        if (recObj == null) {
                            continue;
                        }
                        
                        Allocation__c allObj = new Allocation__c();
                        allObj.AllocationDate__c = system.today();
                        allObj.Invoice__c = invObj.Id;
                        allObj.Receipt__c = recObj.Id;
                        if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                            allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                            //invObj.Status__c = 'Partially Paid';
                        }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                            allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                        } else {
                            allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                            //invObj.Status__c = 'Paid';
                        }
                        allLst.add(allObj);
                        invById.put(invObj.Id, invObj);
                    }
                }
                
                
                if(!allLst.isEmpty() && allLst.size() > 0){
                    try{
                        INSERT allLst;
                        if (!invById.isEmpty()) {
                            UPDATE invById.values();
                        }
                    }catch(Exception ex){
                        addErrorsToSObjects(newMap.values(), ex);
                    }
                }
            }
        }
    }

    public static void createAllocationRecord(Map<Id, sObject> newMap){
        Map<String, String> eoiReceiptMap = new Map<String, String>();
        set<String> eoiSet = new set<String>();
        Map<String, String> soiReceiptMap = new Map<String, String>();
        Map<String, String> chargeReceiptMap = new Map<String, String>();
        set<String> soiSet = new set<String>();
        set<String> chargeSet = new set<String>();
        // added for ADM Fees + Dari charges
        Map<String, String> soReceiptMap = new Map<String, String>();
        set<String> soSet = new set<String>();
        for(String key : newMap.keySet()){
            Receipt__c recObj = (Receipt__c) newMap.get(key);
            if(String.isNotBlank(recObj.Expressionofinterest__c)){
                eoiReceiptMap.put(recObj.Expressionofinterest__c,key);
                eoiSet.add(recObj.Expressionofinterest__c);
            }else if(String.isNotBlank(recObj.SalesOrderInstallment__c)){
                soiReceiptMap.put(recObj.SalesOrderInstallment__c,key);
                soiSet.add(recObj.SalesOrderInstallment__c);
                // added for ADM Fees + Dari charges
            }else if(String.isNotBlank(recObj.Charge__c)){
                chargeReceiptMap.put(recObj.Charge__c,key);
                chargeSet.add(recObj.Charge__c);
            }else if(String.isNotBlank(recObj.SalesOrder__c) && recObj.Is_ADM_Fees_and_Dari_charges__c == TRUE){
                soReceiptMap.put(recObj.SalesOrder__c,key);
                soSet.add(recObj.SalesOrder__c);
            }
        }
        
        if((!eoiSet.isEmpty() && eoiSet.size() > 0) ||(!chargeSet.isEmpty() && chargeSet.size() > 0) || (!soiSet.isEmpty() && soiSet.size() > 0) || (!soSet.isEmpty() && soSet.size() > 0)){// added for ADM Fees + Dari charges
            Map<String, Invoice__c> eoiInvoiceMap = new Map<String, Invoice__c>();
            Map<String, Invoice__c> soiInvoiceMap = new Map<String, Invoice__c>();
            Map<String, Invoice__c> soInvoiceMap = new Map<String, Invoice__c>();// added for ADM Fees + Dari charges
            Map<String, Invoice__c> chargeInvoiceMap = new Map<String, Invoice__c>();
            List<Allocation__c> allLst = new List<Allocation__c>();
            Map<Id, Invoice__c> invById = new Map<Id, Invoice__c>();
            for(Invoice__c invObj : [SELECT Id,Charge__c,Expressionofinterest__c, SalesOrderInstallment__c,InvoiceAmount__c, InvoiceBalance__c, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c FROM Invoice__c 
                                     WHERE (Expressionofinterest__c IN : eoiSet OR SalesOrderInstallment__c IN : soiSet OR Sales_Order__c IN : soSet OR Charge__c IN :chargeSet ) AND InvoiceBalance__c > 0]){
                                         if(String.isNotBlank(invObj.Expressionofinterest__c)){
                                             eoiInvoiceMap.put(invObj.Expressionofinterest__c, invObj);
                                         }else if(String.isNotBlank(invObj.SalesOrderInstallment__c)){
                                             soiInvoiceMap.put(invObj.SalesOrderInstallment__c, invObj);
                                         }else if(String.isNotBlank(invObj.Charge__c)){
                                             chargeInvoiceMap.put(invObj.Charge__c, invObj);
                                         }else if(String.isNotBlank(invObj.Sales_Order__c) && invObj.Is_ADM_Fees_and_Dari_charges__c == TRUE){// added for ADM Fees + Dari charges
                                             soInvoiceMap.put(invObj.Sales_Order__c, invObj);
                                         }
                                     }
            
            if((eoiInvoiceMap != null && eoiInvoiceMap.size() > 0) || (soiInvoiceMap != null && soiInvoiceMap.size() > 0) || (soInvoiceMap != null && soInvoiceMap.size() > 0) || (chargeInvoiceMap != null && chargeInvoiceMap.size() > 0)){// added for ADM Fees + Dari charges
                if((eoiInvoiceMap != null && eoiInvoiceMap.size() > 0)){
                    for(String key : eoiInvoiceMap.keySet()){
                        Invoice__c invObj = eoiInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(eoiReceiptMap.get(key)) ? (Receipt__c) newMap.get(eoiReceiptMap.get(key)) : null;  /*** 4.0 - NULL Check Before Creating Allocation ***/
                        if(recObj <> null){
                            Allocation__c allObj = new Allocation__c();
                            allObj.AllocationDate__c = system.today();
                            allObj.Invoice__c = invObj.Id;
                            allObj.Receipt__c = recObj.Id;
                            if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                                allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                                //invObj.Status__c = 'Partially Paid';
                            }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                                allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                            } else {
                                allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                                //invObj.Status__c = 'Paid';
                            }
                            allLst.add(allObj);
                            invById.put(invObj.Id, invObj);
                        }
                    }
                }
                
                if((soiInvoiceMap != null && soiInvoiceMap.size() > 0)){
                    for(String key : soiInvoiceMap.keySet()){
                        Invoice__c invObj = soiInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(soiReceiptMap.get(key)) ? (Receipt__c) newMap.get(soiReceiptMap.get(key)) : null;  /*** 4.0 - NULL Check Before Creating Allocation ***/
                        if(recObj <> null){
                            Allocation__c allObj = new Allocation__c();
                            allObj.AllocationDate__c = system.today();
                            allObj.Invoice__c = invObj.Id;
                            allObj.Receipt__c = recObj.Id;
                            //26.1 - Updated the field below to identify the amount paid by the customer through Modon Connect.
                            if(recObj.Modeofpayment__c == 'Online'){
                                allObj.IsOnlineAllocation__c = true;
                            }
                            if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                                allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                                //invObj.Status__c = 'Partially Paid';
                            }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                                allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                            } else {
                                allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                                //invObj.Status__c = 'Paid';
                            }
                            allLst.add(allObj);
                            invById.put(invObj.Id, invObj);
                        }
                    }
                }
                
                if((chargeInvoiceMap != null && chargeInvoiceMap.size() > 0)){
                    for(String key : chargeInvoiceMap.keySet()){
                        Invoice__c invObj = chargeInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(chargeReceiptMap.get(key)) ? (Receipt__c) newMap.get(chargeReceiptMap.get(key)) : null; /*** 4.0 - NULL Check Before Creating Allocation ***/
                        if(recObj <> null){ 
                            Allocation__c allObj = new Allocation__c();
                            allObj.AllocationDate__c = system.today();
                            allObj.Invoice__c = invObj.Id;
                            allObj.Receipt__c = recObj.Id;
                            if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                                allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                                //invObj.Status__c = 'Partially Paid';
                            }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                                allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                            } else {
                                allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                                //invObj.Status__c = 'Paid';
                            }
                            allLst.add(allObj);
                            invById.put(invObj.Id, invObj);
                        }
                    }
                }
                
                // added for ADM Fees + Dari charges
                if((soInvoiceMap != null && soInvoiceMap.size() > 0)){
                    for(String key : soInvoiceMap.keySet()){
                        Invoice__c invObj = soInvoiceMap.get(key);
                        Receipt__c recObj = newMap.containsKey(soReceiptMap.get(key)) ? (Receipt__c) newMap.get(soReceiptMap.get(key)) : null; /*** 4.0 - NULL Check Before Creating Allocation ***/
                        if(recObj <> null){ 
                            Allocation__c allObj = new Allocation__c();
                            allObj.AllocationDate__c = system.today();
                            allObj.Invoice__c = invObj.Id;
                            allObj.Receipt__c = recObj.Id;
                            if(invObj.InvoiceBalance__c > recObj.RemainingAmount__c){
                                allObj.AllocationAmount__c = recObj.RemainingAmount__c;
                                //invObj.Status__c = 'Partially Paid';
                            }else if(invObj.InvoiceBalance__c > recObj.Receipt_Amount__c){                            
                                allObj.AllocationAmount__c = recObj.Receipt_Amount__c;
                            } else {
                                allObj.AllocationAmount__c = invObj.InvoiceBalance__c;
                                //invObj.Status__c = 'Paid';
                            }
                            /*if(recObj.Modeofpayment__c == 'Credit Note'){
                            allObj.Allocation_Type__c = 'Credit Note';    
                            }*/
                            allLst.add(allObj);
                            invById.put(invObj.Id, invObj);
                        }
                    }
                }
                
                
                if(!allLst.isEmpty() && allLst.size() > 0){
                    try{
                        INSERT allLst;
                        if (!invById.isEmpty()) {
                            UPDATE invById.values();
                        }
                    }catch(Exception ex){
                        addErrorsToSObjects(newMap.values(), ex);
                    }
                }
            }
        }
    }
    
   //v4.0 (line 317 - 466) Handles allocation for Modon - Egypt with multi-currency conversion starting from specific milestone
    //If receipt amount exceeds current milestone, allocates to subsequent milestones downwards
    //(v21 - START)
    private static List<Allocation__c> handleModonEgyptAllocation(
        Receipt__c recObj,
        Id soiId,
        Map<Id, SalesOrderInstallments__c> soiById,
        Map<Id, List<Invoice__c>> invoicesBySoId
    ) {
        List<Allocation__c> allocations = new List<Allocation__c>();
        
        // Get the starting installment details
        SalesOrderInstallments__c startSOI = soiById != null ? soiById.get(soiId) : null;
        if (startSOI == null) {
            List<SalesOrderInstallments__c> soiRows = [
                SELECT Id, MilestoneNumber__c, SalesOrder__c
                FROM SalesOrderInstallments__c
                WHERE Id = :soiId
                LIMIT 1
            ];
            startSOI = soiRows.isEmpty() ? null : soiRows[0];
        }
        if (startSOI == null) {
            return allocations;
        }

        // Fetch all invoices for this sales order with both balance fields and applied amounts
        List<Invoice__c> allInvoices = invoicesBySoId != null && invoicesBySoId.containsKey(startSOI.SalesOrder__c)
            ? invoicesBySoId.get(startSOI.SalesOrder__c)
            : [
                SELECT Id, InvoiceBalance__c, InvoiceAmount__c, CurrencyIsoCode,
                    SalesOrderInstallment__r.MilestoneNumber__c,
                    Installment_Amount__c, Maintenance_Amount__c,
                    Applied_InstallmentAmount__c, Applied_MaintenanceAmount__c
                FROM Invoice__c
                WHERE SalesOrderInstallment__r.SalesOrder__c = :startSOI.SalesOrder__c
                ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC
            ];
        //(v21 - END)
        String recCurrency = recObj.CurrencyIsoCode;
        Decimal recAmount = recObj.RemainingAmount__c != null ? recObj.RemainingAmount__c : recObj.TotalAmount__c;

        //v4.2 (line 343 - 382) Introduced receipt type to differentiate between Installment and maintenance receipt
        String recType = recObj.Receipt_Type__c;

        //Determine if this is a maintenance or installment receipt
        Boolean isMaintenanceReceipt = (recType == 'Maintenance Receipt');
        
        // Split invoices into previous and current/future milestones
        List<Invoice__c> prevInvoices = new List<Invoice__c>();
        List<Invoice__c> futureInvoices = new List<Invoice__c>();
        Decimal totalBalance = 0;
        
        for (Invoice__c inv : allInvoices) {
            if (inv.SalesOrderInstallment__r == null) {
                continue;
            }
            Decimal milestone = inv.SalesOrderInstallment__r.MilestoneNumber__c;

            // Get the appropriate balance based on receipt type and subtract already applied amounts
            Decimal relevantBalance = isMaintenanceReceipt
                ? ((inv.Maintenance_Amount__c != null ? inv.Maintenance_Amount__c : 0) 
                   - (inv.Applied_MaintenanceAmount__c != null ? inv.Applied_MaintenanceAmount__c : 0))
                : ((inv.Installment_Amount__c != null ? inv.Installment_Amount__c : 0) 
                   - (inv.Applied_InstallmentAmount__c != null ? inv.Applied_InstallmentAmount__c : 0));
            
            if (milestone < startSOI.MilestoneNumber__c) {
                prevInvoices.add(inv);
            } else if (relevantBalance > 0) {
                futureInvoices.add(inv);

                //Calculate total balance in receipt currency
                //v4.1 (line 371) Created a seperate class for currency comnversion rate management and calling it here to get the conversion rates.
                //v4.3 (line 371) updated to use ConversionRateWrapper for currency conversion
                ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(recCurrency, inv.CurrencyIsoCode);
                if (rateWrapper == null) { 
                    recObj.addError('Currency conversion rate not found for ' + recCurrency + 
                                                ' to ' + inv.CurrencyIsoCode + ' for today. Please contact system administrator.');
                    return allocations;
                } else {
                    Decimal rate = rateWrapper.inverseConversionRate;
                    totalBalance += (relevantBalance * rate);
                }
                
            }
        }
        
        if (futureInvoices.isEmpty()) {
            String balanceType = isMaintenanceReceipt ? 'maintenance' : 'installment';
            recObj.addError('No invoices found with outstanding ' +balanceType+ ' balance for allocation.');
            return allocations;
        }
        
        // Check for partially paid previous milestones
        // for (Invoice__c prev : prevInvoices) {
        //     if (prev.InvoiceBalance__c > 0 && prev.InvoiceBalance__c < prev.InvoiceAmount__c) {
        //         recObj.addError('Cannot create payment for Milestone ' + startSOI.MilestoneNumber__c + 
        //                     ' because Milestone ' + prev.SalesOrderInstallment__r.MilestoneNumber__c + 
        //                     ' is partially paid. Please complete previous milestone payments first.');
        //         return allocations;
        //     }
        // }
        

        // Check if payment exceeds available balance
       //v4.7 (line 403 - 410) Added Threshold Check
        if ((recAmount - totalBalance) > ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD) {
            String balanceType = isMaintenanceReceipt ? 'maintenance' : 'installment';
            recObj.addError('Payment amount (' + recAmount + ' ' + recCurrency + 
                        ') exceeds the total outstanding ' + balanceType + ' balance (' + 
                        totalBalance.setScale(2, RoundingMode.HALF_UP) + ' ' + recCurrency + 
                        ') for all remaining milestones or the balance may already be allocated to pending receipts. Please adjust the payment amount');
            return allocations;
        }
        
        // Process allocations
        Decimal remaining = recAmount;
        
        for (Invoice__c inv : futureInvoices) {
            if (remaining <= 0) break;
            
            // Get the appropriate balance based on receipt type and subtract already applied amounts
            Decimal relevantBalance = isMaintenanceReceipt
                ? ((inv.Maintenance_Amount__c != null ? inv.Maintenance_Amount__c : 0) 
                   - (inv.Applied_MaintenanceAmount__c != null ? inv.Applied_MaintenanceAmount__c : 0))
                : ((inv.Installment_Amount__c != null ? inv.Installment_Amount__c : 0) 
                   - (inv.Applied_InstallmentAmount__c != null ? inv.Applied_InstallmentAmount__c : 0));

            if (relevantBalance <= 0) continue;
            
            //v4.1 (line 430) Created a seperate class for currency comnversion rate management and calling it here to get the conversion rates.
            //v4.3 (line 430) updated to use ConversionRateWrapper for currency conversion
            ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(recCurrency, inv.CurrencyIsoCode);
            if (rateWrapper == null) { 
                recObj.addError('Currency conversion rate not found for ' + recCurrency + 
                                            ' to ' + inv.CurrencyIsoCode + ' for today. Please contact system administrator.');
                continue;
            }

            Decimal rate = rateWrapper.inverseConversionRate;
            
            Decimal invBalanceConverted = relevantBalance * rate;
            Decimal allocAmt;
            //v4.4 (line 441) Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
            if (Math.abs(remaining - invBalanceConverted) <= ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD) {
                allocAmt = invBalanceConverted;
            } else {
                allocAmt = Math.min(remaining, invBalanceConverted);
            }
            
            Allocation__c alloc = new Allocation__c();
            alloc.AllocationDate__c = System.today();
            alloc.Invoice__c = inv.Id;
            alloc.Receipt__c = recObj.Id;
            alloc.AllocationAmount__c = allocAmt;
            alloc.CurrencyIsoCode = inv.CurrencyIsoCode;
            alloc.isMaintenance__c = isMaintenanceReceipt; //set true if maintenance receipt
            allocations.add(alloc);
            
            remaining -= allocAmt;

            //v4.4 (line 460) Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
            // Absorb tiny remainder to prevent spillover 
            if (remaining > 0 && remaining <= ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD) {
                remaining = 0;
            }
        }
        return allocations;
    }
    

    //v4.1 Removing
    // Get conversion rate between currencies
    // private static Decimal getConversionRate(String fromCurr, String toCurr, Map<String, Decimal> rateMap) {
    //     if (fromCurr == toCurr) {
    //         return 1;
    //     }
    //     return rateMap.get(fromCurr + '-' + toCurr);
    // }
    
    public static void manageAllocationAmount(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        set<Id> recIds = new set<Id>();
        for(Id recId : newMap.keySet()){
            Receipt__c newRec = (Receipt__c) newMap.get(recId);
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(recId) : null;
            if (oldRec == null) {
                continue;
            }
            
            if(newRec.Status__c != oldRec.Status__c && (newRec.Status__c == 'Approved' || newRec.Status__c == 'Cleared')){
                recIds.add(newRec.Id);
            }
        }
        
        if(!recIds.isEmpty() && recIds.size() > 0){
            List<Allocation__c> allLst = [SELECT Id FROM Allocation__c WHERE Receipt__c IN : recIds];
            if(!allLst.isEmpty() && allLst.size() > 0){
                UPDATE allLst;
            }
        }
    }
    
    public static void handleBeforeDelete(List<sObject> oldList){
        for(Receipt__c recObj : (List<Receipt__c>) oldList){
            if(recObj.Status__c == 'Approved'){
                recObj.addError('You are not authorized for this action');
            }
        }
    }
    
    public static void generatePaymentGatewayURL(Map<Id, sObject> newMap){ // call this After Insert
        Set<String> onlineReceiptIds = new Set<String>();
        if (newMap == null) {
            return;
        }
        for(String key : newMap.keySet()){
            Receipt__c recObj = (Receipt__c) newMap.get(key);
            if(recObj != null && recObj.Modeofpayment__c == 'Online'){
                onlineReceiptIds.add(recObj.Id);
            }
        }
        // One @future for the batch. Each Online receipt still calls the same payment-gateway API.
        if (!onlineReceiptIds.isEmpty()) {
            createAllocationRecord(onlineReceiptIds);
        }
    }

    @future (callout = true)
    public static void createAllocationRecord(Set<String> recIds){
        if (recIds == null || recIds.isEmpty()) {
            return;
        }
        for (String recId : recIds) {
            if (String.isNotBlank(recId)) {
                PaymentGatewayUtility.getPaymentGatewayURL(recId);
            }
        }
    }
    
    @future (callout = true)
    public static void createAllocationRecord(string recID){
        PaymentGatewayUtility.getPaymentGatewayURL(recID);
    }
    
    
    public static void validateReceiptStatusChange(Map<Id, sObject> newMap, Map<Id, sObject> oldMap){
        Set<Id> receiptIds = new Set<Id>();
        for(Id recId : newMap.keySet()){
            Receipt__c newRec = (Receipt__c) newMap.get(recId);
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(recId) : null;
            if(oldRec == null){
                continue;
            }
            if(newRec.Status__c != oldRec.Status__c && newRec.Status__c == 'Approved'){
                receiptIds.add(newRec.Id);
            }
        }
        if(!receiptIds.isEmpty()){
            createReceiptPDFOnceApproved(receiptIds);
        }
    }
    
    @future (callout = true)
    public static void createReceiptPDFOnceApproved(Set<Id> receiptIds){
        
        // Map<Id, Documents__c> receiptToDocumentMap = new Map<Id, Documents__c>();
        // String emailTemplateId = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName = :Constants.PAYMENT_ACKN_EMAIL_TEMPLATE].Id;
        // OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName=:Constants.ORGWIDE_DEFAULT_NORPLY_NAME];
        // List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
        // List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        // List<Receipt__c> receipts = [SELECT Id, SalesOrderInstallment__r.Name, ExpressionOfInterest__r.Name, ExpressionOfInterest__c, SalesOrderInstallment__c, Account__r.PersonEmail, Account__r.IsPersonAccount, Account__r.PersonContactId, Account__c FROM Receipt__c WHERE Id IN :receiptIds];
        
        // for (Documents__c relatedDocument : [SELECT Id, Name, Invoice__c FROM Documents__c WHERE Receipt__c = :receipts AND Name = 'Receipt PDF']) {
            //     receiptToDocumentMap.put(relatedDocument.Invoice__c, relatedDocument);
        // }
        
        // for (Receipt__c receipt : receipts) {
            //     Documents__c relatedDocument = receiptToDocumentMap.get(receipt.Id);
            
            //     if (relatedDocument != null) {
                
                //         PageReference pdf = Page.ReceiptPDF;
                //         pdf.getParameters().put('receiptId', receipt.Id);
                //         Blob pdfBlob = pdf.getContentAsPDF();
                
                //         ContentVersion contentVersion = new ContentVersion();
                //         contentVersion.VersionData = pdfBlob;
                //         contentVersion.Title = receipt.ExpressionOfInterest__c != null ? receipt.ExpressionOfInterest__r.Name + ' - Receipt' : receipt.SalesOrderInstallment__r.Name + ' - Receipt';
                //         contentVersion.PathOnClient = contentVersion.Title;
                //         contentVersion.FirstPublishLocationId = receiptToDocumentMap.get(receipt.Id).Id;
                //         contentVersionsToInsert.add(contentVersion);
                
                //         Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                //         email.setToAddresses(new String[]{receipt.Account__r.PersonEmail});
                //         email.setWhatId(receipt.Id);
                //         email.setTargetObjectId(receipt.Account__r.PersonContactId);
                //         email.setTemplateId(emailTemplateId);
                //         email.setOrgWideEmailAddressId(owea.Id);
                //         email.setSaveAsActivity(false);
                
                //         Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
                //         fileAttachment.setFileName(contentVersion.Title);
                //         fileAttachment.setBody(contentVersion.VersionData);
                //         fileAttachment.setContentType('application/pdf');
                //         email.setFileAttachments(new List<Messaging.EmailFileAttachment>{fileAttachment});
                
                //         emailsToSend.add(email);
            //     }
        // }
        
        // if (!contentVersionsToInsert.isEmpty()) {
            //     insert contentVersionsToInsert;
        // }
        
        // if (!emailsToSend.isEmpty()) {
            //     try {
                //         Messaging.sendEmail(emailsToSend);
            //     } catch (Exception e) {
                //         System.debug('EXCEPTION EE -> ' + e.getMessage());
            //     }
        // }
        
        if (receiptIds == null || receiptIds.isEmpty()) {
            return;
        }

        List<Receipt__c> receipts = [SELECT Id, Status__c, SalesOrderInstallment__r.Name, ExpressionOfInterest__r.Name, ExpressionOfInterest__c, SalesOrderInstallment__c, Account__r.PersonEmail, Account__r.IsPersonAccount, Account__r.PersonContactId, Account__c, (SELECT id, Name FROM Documents__r WHERE Name = 'Receipt PDF' LIMIT 1) FROM Receipt__c WHERE Id IN :receiptIds];
        if (receipts.isEmpty()) {
            return;
        }

        List<EmailTemplate> emailTemplates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName = :Constants.PAYMENT_ACKN_EMAIL_TEMPLATE LIMIT 1];
        Id emailTemplateId = emailTemplates.isEmpty() ? null : emailTemplates[0].Id;
        List<OrgWideEmailAddress> lst_owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName=:Constants.ORGWIDE_DEFAULT_NORPLY_NAME];

        List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
        List<Receipt__c> receiptsWithPdf = new List<Receipt__c>();
        Map<Id, Id> receiptToDocId = new Map<Id, Id>();
        Map<Id, ContentVersion> receiptToContentVersion = new Map<Id, ContentVersion>();

        for (Receipt__c receipt : receipts) {
            if (receipt.Documents__r == null || receipt.Documents__r.isEmpty()) {
                continue;
            }

            PageReference pdf = Page.ReceiptPDF;
            pdf.getParameters().put('receiptId', receipt.Id);

            ContentVersion contentVersion = new ContentVersion();
            if (!Test.isRunningTest()) {
                contentVersion.VersionData = pdf.getContentAsPDF();
            } else {
                contentVersion.VersionData = Blob.valueOf('Test');
            }
            String pdfTitle = receipt.ExpressionOfInterest__c != null ? receipt.ExpressionOfInterest__r.Name + ' - Receipt' : receipt.SalesOrderInstallment__r.Name + ' - Receipt';
            contentVersion.Title = pdfTitle;
            contentVersion.PathOnClient = pdfTitle;
            contentVersion.FirstPublishLocationId = receipt.Documents__r[0].Id;
            contentVersionsToInsert.add(contentVersion);
            receiptsWithPdf.add(receipt);
            receiptToDocId.put(receipt.Id, receipt.Documents__r[0].Id);
            receiptToContentVersion.put(receipt.Id, contentVersion);
        }

        if (!contentVersionsToInsert.isEmpty()) {
            insert contentVersionsToInsert;
        }

        Map<Id, List<ContentDocumentLink>> attachmentsByDocId = new Map<Id, List<ContentDocumentLink>>();
        if (!receiptToDocId.isEmpty()) {
            for (ContentDocumentLink attachment : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :receiptToDocId.values()
            ]) {
                if (!attachmentsByDocId.containsKey(attachment.LinkedEntityId)) {
                    attachmentsByDocId.put(attachment.LinkedEntityId, new List<ContentDocumentLink>());
                }
                attachmentsByDocId.get(attachment.LinkedEntityId).add(attachment);
            }
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        if (emailTemplateId != null) {
            for (Receipt__c receipt : receiptsWithPdf) {
                if (receipt.Account__r == null
                    || String.isBlank(receipt.Account__r.PersonEmail)
                    || receipt.Account__r.PersonContactId == null) {
                    continue;
                }

                ContentVersion contentVersion = receiptToContentVersion.get(receipt.Id);
                Id documentId = receiptToDocId.get(receipt.Id);
                List<ContentDocumentLink> attachments = attachmentsByDocId.containsKey(documentId)
                    ? attachmentsByDocId.get(documentId)
                    : new List<ContentDocumentLink>();

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{receipt.Account__r.PersonEmail});
                email.setWhatId(receipt.Id);
                email.setTargetObjectId(receipt.Account__r.PersonContactId);
                email.setTemplateId(emailTemplateId);
                if (!lst_owea.isEmpty()) {
                    email.setOrgWideEmailAddressId(lst_owea[0].Id);
                }

                List<Messaging.EmailFileAttachment> fileAttachments = new List<Messaging.EmailFileAttachment>();
                for (ContentDocumentLink attachment : attachments) {
                    Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
                    fileAttachment.setFileName(contentVersion.Title);
                    fileAttachment.setBody(contentVersion.VersionData);
                    fileAttachment.setcontenttype('application/pdf');
                    fileAttachments.add(fileAttachment);
                }
                email.setFileAttachments(fileAttachments);
                emailsToSend.add(email);
            }
        }

        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(emailsToSend, false);
                List<String> emailErrors = new List<String>();
                if (emailResults != null) {
                    for (Messaging.SendEmailResult emailResult : emailResults) {
                        if (emailResult != null && !emailResult.isSuccess()) {
                            for (Messaging.SendEmailError emailError : emailResult.getErrors()) {
                                if (emailError != null && String.isNotBlank(emailError.getMessage())) {
                                    emailErrors.add(emailError.getMessage());
                                }
                            }
                        }
                    }
                }
                if (!emailErrors.isEmpty()) {
                    throw new ReceiptHelperException(String.join(emailErrors, '; '));
                }
            } catch (Exception e) {
                // Persist the failure so it is not silent; do not rethrow or the PDF insert rolls back.
                try {
                    LoggerService.save(LoggerService.createApexLog(
                        e,
                        'Receipt PDF Email',
                        'ReceiptTriggerHelper',
                        'createReceiptPDFOnceApproved'
                    ));
                } catch (Exception logEx) {
                    System.debug(LoggingLevel.ERROR, 'Receipt PDF email failed: ' + e.getMessage() + ' | log: ' + logEx.getMessage());
                }
            }
        }
    }
    public static void populateAmountText(List<SObject> newList){
        // For egypt we have different currency
        for(Receipt__c receipt : (List<Receipt__c>)newList){
            String currencyUnit = 'dirhams';
            String currencySubUnit = 'fils';
            if(receipt.TotalAmount__c!=null){ 
                if( receipt.currencyISOCode == 'EGP' ){
                    currencyUnit = 'egyptian pound';
                    currencySubUnit = 'piastres';
                }
                //Added lines 477-488, Monali - Dixit, HZTL(To support mutlicurrency for Egypt)
                if( receipt.currencyISOCode == 'USD' ){
                    currencyUnit = 'us dollar';
                    currencySubUnit = 'cents';
                }
                if( receipt.currencyISOCode == 'EUR' ){
                    currencyUnit = 'euro';
                    currencySubUnit = 'cents';
                }
                if( receipt.currencyISOCode == 'SAR' ){
                    currencyUnit = 'saudi riyal';
                    currencySubUnit = 'halalas';
                }                
                receipt.Totalamountinwords__c = Utilities.amountInWords (receipt.TotalAmount__c,currencyUnit,currencySubUnit ); 
            }
        }
    }
    /** 10.0 Fix the Total Paid Amount **/
    public static void handleAlloccalculateTotalPaid(List<SObject> newList, Map<Id,sObject> oldMap){
        List<sObject> receiptList = new List<sObject>();
        Set<Id> receiptIdset = new Set<Id>();
        for(Allocation__c alloc: (List<Allocation__c>) newList){
            Allocation__c oldData = oldMap <> null ? (Allocation__c) oldMap.get(alloc.Id) : null;
            if(alloc.Status__c <> null && alloc.ApprovedReceiptAmount__c <> null && (oldData == null ||(oldData <> null && (alloc.Status__c <> oldData.Status__c  || alloc.ApprovedReceiptAmount__c <> oldData.ApprovedReceiptAmount__c)))){
                receiptIdset.add(alloc.Receipt__c);
            }
        }
        if(!receiptIdset.isEmpty()){
           receiptList = [SELECT Id,SalesOrder__c,Is_ADM_Fees_and_Dari_charges__c,Status__c,TotalAmount__c,SalesOrderInstallment__c FROM Receipt__c WHERE Id IN: receiptIdset];
           if(!receiptList.isEmpty()){
                calculateTotalPaid(receiptList,null);
            }
        }
    }
        public static void calculateTotalPaid(List<SObject> newList, Map<Id,SObject> oldMap){
    
    set<ID> salesOrderInstallmentIDs = new set<ID>();
    Map<Id, Decimal> salesOrderReceiptMap = new Map<Id, Decimal>();
    Map<Id, Decimal> salesOrderDariAmount = new Map<Id, Decimal>();
    
    /*** ORIGINAL: Loop through receipts and build sets/maps based on status change conditions ***/
    for(Receipt__c receipt : (List<Receipt__c>)newList){
        
        Receipt__c oldData = oldMap <> null ? (Receipt__c) oldMap.get(receipt.Id) : null; 
        /** 8.1 ADDED IF CONDITION to FIX 101 SOQL Exception **/
        
        if(String.isNotBlank(receipt.SalesOrder__c) 
            && receipt.Is_ADM_Fees_and_Dari_charges__c 
            && receipt.Status__c == 'Cleared' 
            && (oldData == null || (oldData <> null && receipt.Status__c <> oldData.Status__c))){
                salesOrderReceiptMap.put(receipt.SalesOrder__c, receipt.TotalAmount__c);
        }
        
        if(receipt.SalesOrderInstallment__c != null 
            && (oldData == null || (oldData <> null && (oldData.SalesOrderInstallment__c <> receipt.SalesOrderInstallment__c 
            || oldData.Status__c <> receipt.Status__c)))){  
            /** 8.1 ADDED IF CONDITION to FIX 101 SOQL Exception **/
                salesOrderInstallmentIDs.add(receipt.SalesOrderInstallment__c);
        }
    }
    
    system.debug('salesOrderReceiptMap==>' + salesOrderReceiptMap);
    
    /*** ORIGINAL: Query SalesOrder Dari charges for ADM/Dari fee receipts ***/
    if(salesOrderReceiptMap != null && salesOrderReceiptMap.keySet().size() > 0){
        for(SalesOrder__c soObj : [
            SELECT Id, Daricharges__c 
            FROM SalesOrder__c 
            WHERE Id IN :salesOrderReceiptMap.keySet()
        ]){
            salesOrderDariAmount.put(soObj.Id, soObj.Daricharges__c);
        }
    }
    
    /*** ORIGINAL: Build soLst with ReceivedDariAmount and ReceivedADMFees values ***/
    set<String> soSet = new set<String>();
    List<SalesOrder__c> soLst = new List<SalesOrder__c>();
    for(String key : salesOrderDariAmount.keySet()){
        if(!soSet.contains(key)){
            SalesOrder__c so = new SalesOrder__c(
                id                   = key, 
                ReceivedDariAmount__c = salesOrderDariAmount.get(key), 
                ReceivedADMFees__c   = (salesOrderReceiptMap.get(key) - salesOrderDariAmount.get(key))
            );
            soSet.add(key);
            soLst.add(so);
        }
    }
    
    system.debug('soLst==>' + soLst);
    
    map<Id, SalesOrder__c> soToUpdate = new map<Id, SalesOrder__c>();
    
    if(!salesOrderInstallmentIDs.isEmpty()){
        
        /*** ORIGINAL: Get SalesOrder Ids from installment records ***/
        for(SalesOrderInstallments__c soi : [
            SELECT Id, SalesOrder__c 
            FROM SalesOrderInstallments__c 
            WHERE Id IN :salesOrderInstallmentIDs
        ]){
            soToUpdate.put(soi.SalesOrder__c, new SalesOrder__c(
                Id                = soi.SalesOrder__c,
                Totalpaidamount__c = 0
            ));
        }
        
        /*** ORIGINAL: Calculate total paid amount from cleared allocations ***/
        for(Allocation__c alloc : [
            SELECT Id,
                   Invoice__r.SalesOrderInstallment__r.SalesOrder__c,
                   Receipt__r.TotalAmount__c,
                   ApprovedReceiptAmount__c 
            FROM Allocation__c 
            WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN :soToUpdate.keySet() 
            AND Receipt__r.Status__c IN ('Cleared') 
            AND Status__c = 'Applied' 
            AND ApprovedReceiptAmount__c <> null
        ]){
            soToUpdate.get(
                alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c
            ).Totalpaidamount__c += alloc.ApprovedReceiptAmount__c;
            /** 4.0: Fix the total paid amount calculation in SO Level **/
        }
        
        /*** ARVIND - START: Fetch existing SO field values to compare against calculated values.
             This prevents redundant DML when nothing has changed, which was causing the 
             SalesOrder trigger chain to fire unnecessarily and consuming ~20 extra SOQL queries ***/
        Map<Id, SalesOrder__c> existingSOMap = new Map<Id, SalesOrder__c>([
            SELECT Id, 
                   Totalpaidamount__c, 
                   ReceivedDariAmount__c, 
                   ReceivedADMFees__c 
            FROM SalesOrder__c 
            WHERE Id IN :soToUpdate.keySet()
        ]);
        /*** ARVIND - END ***/
        
        /*** ARVIND - START: Only include SalesOrder records where Totalpaidamount__c 
             has actually changed. Previously all records were updated unconditionally,
             causing the SalesOrder trigger chain to fire even when values were identical,
             wasting ~20 SOQL queries per unnecessary update ***/
        List<SalesOrder__c> soToUpdateFinal = new List<SalesOrder__c>();
        for(Id soId : soToUpdate.keySet()){
            SalesOrder__c calculated = soToUpdate.get(soId);
            SalesOrder__c existing   = existingSOMap.get(soId);
            if(existing != null && existing.Totalpaidamount__c != calculated.Totalpaidamount__c){
                soToUpdateFinal.add(calculated);
            }
        }
        /*** ARVIND - END ***/
        
        /*** ARVIND - START: Merge soLst records (ReceivedDariAmount__c + ReceivedADMFees__c) 
             into soToUpdateFinal to combine into a single DML statement.
             Previously there were two separate update calls which fired the SalesOrder 
             trigger chain twice (~40 extra queries). Now it fires only once.
             Any soLst records not already in soToUpdateFinal are appended at the end ***/
        if(!soLst.isEmpty()){
            Map<Id, SalesOrder__c> soLstMap = new Map<Id, SalesOrder__c>();
            for(SalesOrder__c so : soLst){
                soLstMap.put(so.Id, so);
            }
            
            // Merge soLst fields into matching soToUpdateFinal records
            for(SalesOrder__c soFinal : soToUpdateFinal){
                if(soLstMap.containsKey(soFinal.Id)){
                    SalesOrder__c soLstRecord     = soLstMap.get(soFinal.Id);
                    soFinal.ReceivedDariAmount__c = soLstRecord.ReceivedDariAmount__c;
                    soFinal.ReceivedADMFees__c    = soLstRecord.ReceivedADMFees__c;
                    soLstMap.remove(soFinal.Id); // remove merged record
                }
            }
            
            // Append any remaining soLst records that had no matching installment update
            soToUpdateFinal.addAll(soLstMap.values());
        }
        /*** ARVIND - END ***/
        
        /*** ARVIND - START: Single combined DML replacing the original two separate updates
             (soToUpdate.values() and soLst). SalesOrder trigger chain now fires once 
             instead of twice, saving ~20 SOQL queries ***/
        if(!soToUpdateFinal.isEmpty()){
            update soToUpdateFinal;
        }
        /*** ARVIND - END ***/
        
    } else {
        
        /*** ARVIND - START: Handle the case where only soLst has values and there are 
             no installment IDs. Apply same value-change guard here to avoid firing 
             the SalesOrder trigger chain when ReceivedDariAmount__c and ReceivedADMFees__c 
             have not actually changed ***/
        if(!soLst.isEmpty()){
            
            // Collect SalesOrder Ids from soLst
            Set<Id> soLstIds = new Set<Id>();
            for(SalesOrder__c so : soLst){ 
                soLstIds.add(so.Id); 
            }
            
            // Fetch existing values for comparison
            Map<Id, SalesOrder__c> existingSOLstMap = new Map<Id, SalesOrder__c>([
                SELECT Id, 
                       ReceivedDariAmount__c, 
                       ReceivedADMFees__c 
                FROM SalesOrder__c 
                WHERE Id IN :soLstIds
            ]);
            
            // Only update records where at least one field value has changed
            List<SalesOrder__c> soLstFinal = new List<SalesOrder__c>();
            for(SalesOrder__c so : soLst){
                SalesOrder__c existing = existingSOLstMap.get(so.Id);
                if(existing != null && (
                    existing.ReceivedDariAmount__c != so.ReceivedDariAmount__c ||
                    existing.ReceivedADMFees__c    != so.ReceivedADMFees__c
                )){
                    soLstFinal.add(so);
                }
            }
            
            if(!soLstFinal.isEmpty()){ 
                update soLstFinal; 
            }
        }
        /*** ARVIND - END ***/
        
    }
}
    /*public static void calculateTotalPaid(List<SObject> newList, Map<Id,SObject> oldMap){
        set<ID> salesOrderInstallmentIDs = new set<ID>();
        Map<Id, Decimal> salesOrderReceiptMap = new Map<Id, Decimal>();
        Map<Id, Decimal> salesOrderDariAmount = new Map<Id, Decimal>();
        
        for(Receipt__c receipt : (List<Receipt__c>)newList){
            Receipt__c oldData = oldMap <> null ? (Receipt__c) oldMap.get(receipt.Id) : null; 
            if(String.isNotBlank(receipt.SalesOrder__c) && receipt.Is_ADM_Fees_and_Dari_charges__c && receipt.Status__c == 'Cleared' && (oldData == null ||(oldData <> null && receipt.Status__c <> oldData.Status__c ))){
                salesOrderReceiptMap.put(receipt.SalesOrder__c, receipt.TotalAmount__c);
            }
            if(receipt.SalesOrderInstallment__c!=null && (oldData == null ||(oldData <> null && (oldData.SalesOrderInstallment__c <> receipt.SalesOrderInstallment__c || oldData.Status__c <> receipt.Status__c )))){  
                salesOrderInstallmentIDs.add(receipt.SalesOrderInstallment__c);
            }
        }
        
        system.debug('salesOrderReceiptMap==>' + salesOrderReceiptMap);
        if(salesOrderReceiptMap != null && salesOrderReceiptMap.keySet().size() > 0){
            for(SalesOrder__c soObj : [SELECT Id, Daricharges__c FROM SalesOrder__c WHERE Id IN : salesOrderReceiptMap.keySet()]){
                salesOrderDariAmount.put(soObj.Id, soObj.Daricharges__c);
            }
        }
        set<String> soSet = new set<String>();
        List<SalesOrder__c> soLst = new List<SalesOrder__c>();
        for(String key : salesOrderDariAmount.keySet()){
            if(!soSet.contains(key)){
                SalesOrder__c so = new SalesOrder__c(id=key, ReceivedDariAmount__c=salesOrderDariAmount.get(key), ReceivedADMFees__c=(salesOrderReceiptMap.get(key)-salesOrderDariAmount.get(key)));
                soSet.add(key);
                soLst.add(so);
            }
        }
        system.debug('soLst==>' + soLst);
        map<id,SalesOrder__c> soToUpdate= new map<id,SalesOrder__c>();
        if(!salesOrderInstallmentIDs.isEmpty()){
            for(SalesOrderInstallments__c  soi : [select id,SalesOrder__c from SalesOrderInstallments__c where id in :salesOrderInstallmentIDs]){
                soToUpdate.put(soi.SalesOrder__c,new SalesOrder__c(id=soi.SalesOrder__c,Totalpaidamount__c=0));
            }
            /*for(Receipt__c  rec : [select id,SalesOrderInstallment__r.SalesOrder__c,TotalAmount__c from Receipt__c where SalesOrderInstallment__r.SalesOrder__c in :soToUpdate.keySet() and Status__c in ('Cleared')]){
                soToUpdate.get(rec.SalesOrderInstallment__r.SalesOrder__c).Totalpaidamount__c +=rec.TotalAmount__c;
            }*/ /** To avoid the wrong value in updating the "Total Paid Amount"***/
           
           // for(Allocation__c alloc:[SELECT Id,Invoice__r.SalesOrderInstallment__r.SalesOrder__c,Receipt__r.TotalAmount__c,ApprovedReceiptAmount__c FROM Allocation__c WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c in :soToUpdate.keySet() and Receipt__r.Status__c in ('Cleared') AND Status__c = 'Applied' AND ApprovedReceiptAmount__c <> null]){
            //    soToUpdate.get(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c).Totalpaidamount__c +=alloc.ApprovedReceiptAmount__c;  /** 4.0: Fix the total paid amount calculation in SO Level **/
           // }
           // if(!soToUpdate.isEmpty()){
            //    update soToUpdate.values();
           // }
       // }
       // if(!soLst.isEmpty()){update soLst;}
   // } //Arvind comment the code
    
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Receipt__c');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Receipt__c receipt : (List<Receipt__c>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Receipt__c = receipt.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    public static void addEscrowAccount(List<SObject> newList,Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        set<Id> eOIIds = new set<Id>();
        set<Id> sOrdersIds = new set<Id>();
        
        if(newList.size() > 0 && oldMap == null){
            for(Receipt__c recObj : (List<Receipt__c>) newList){
                if(recObj.ExpressionOfInterest__c != null){
                    eOIIds.add(recObj.ExpressionOfInterest__c);
                }else if(recObj.SalesOrderInstallment__c != null){
                    sOrdersIds.add(recObj.SalesOrderInstallment__c);
                }
            }
        }else{
            for(Id recId : newMap.keySet()){
                Receipt__c newRec = (Receipt__c) newMap.get(recId);
                Receipt__c oldRec = (Receipt__c) oldMap.get(recId);
                if(newRec.ExpressionOfInterest__c != null && newRec.ExpressionOfInterest__c != oldRec.ExpressionOfInterest__c){
                    eOIIds.add(newRec.ExpressionOfInterest__c);
                }
                else if(newRec.SalesOrderInstallment__c != null && newRec.SalesOrderInstallment__c != oldRec.SalesOrderInstallment__c){
                    sOrdersIds.add(newRec.SalesOrderInstallment__c);
                }
            }
        }
        
        map<string,string> eOIEscrowMap = new map<string,string>();
        map<string,string> sOrderEscrowMap = new map<string,string>();
        
        if(eOIIds.size() > 0){
            //get the first escrow from the EOI
            list<Expressionofinterest__c> eOIList = new list<Expressionofinterest__c>([select id,Phase__c,Phase__r.EscrowAccount__c from Expressionofinterest__c where id in:eOIIds ]);
            for(Expressionofinterest__c eoi: eOIList){
                if(eoi.Phase__c != null && eoi.Phase__r.EscrowAccount__c != null)
                    eOIEscrowMap.put(eoi.id,eoi.Phase__r.EscrowAccount__c);
            }
        }
        
        if(sOrdersIds.size() > 0){
            //get the second escrow from SO
            list<SalesOrderInstallments__c> sOrderList = new list<SalesOrderInstallments__c>([select id,SalesOrder__c,SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.Phase__c,SalesOrder__r.Unit__r.Phase__r.EscrowAccount__c  from SalesOrderInstallments__c where id in:sOrdersIds ]);
            for(SalesOrderInstallments__c so: sOrderList){
                if(so.SalesOrder__c != null && so.SalesOrder__r.Unit__c != null && so.SalesOrder__r.Unit__r.Phase__c != null && so.SalesOrder__r.Unit__r.Phase__r.EscrowAccount__c != null )
                    sOrderEscrowMap.put(so.id,so.SalesOrder__r.Unit__r.Phase__r.EscrowAccount__c);
            }
        }
        if(eOIEscrowMap.size() > 0 || sOrderEscrowMap.size() > 0 ){
            for(Receipt__c newRec : (List<Receipt__c>) newList){
                if(newRec.ExpressionOfInterest__c != null && eOIEscrowMap.containskey(newRec.ExpressionOfInterest__c)){
                    newRec.EOIEscrowAccount__c = eOIEscrowMap.get(newRec.ExpressionOfInterest__c);
                }else if(newRec.SalesOrderInstallment__c != null && sOrderEscrowMap.containskey(newRec.SalesOrderInstallment__c)){
                    newRec.PaymentEscrowAccount__c = sOrderEscrowMap.get(newRec.SalesOrderInstallment__c);
                }
            }
        }
    }
    
    /*
    public static void shareAccountAndOpportunityWithReceiptCreator(Map<Id, SObject> newMap){
        if(newMap <> null){
            map<string, string> mp_receiptCreator_OppId = new map<string, string>();
            map<string, string> mp_soOwner_OppId = new map<string, string>();
            map<string, string> mp_receiptCreator_AccId = new map<string, string>();
            map<string, string> mp_soOwner_AccId = new map<string, string>();
            
            for(String key : newMap.keySet()){
                Receipt__c recObj = (Receipt__c) newMap.get(key);
                
                mp_receiptCreator_OppId.put(recObj.createdById, recObj.SalesOrderOpportunityIDFormula__c);
                mp_soOwner_OppId.put(recObj.SalesOrderOwnerIDFormula__c, recObj.SalesOrderOpportunityIDFormula__c);
                
                mp_receiptCreator_AccId.put(recObj.createdById, recObj.SalesOrderAccountIDFormula__c);
                mp_soOwner_AccId.put(recObj.SalesOrderOwnerIDFormula__c, recObj.SalesOrderAccountIDFormula__c);
                
            }
            
            // Opportunity Share
            set<string> userID_OppID_Combo = new set<string>();
            list<OpportunityShare> oppShare = [select Id, OpportunityId, UserOrGroupId from OpportunityShare where OpportunityId in :mp_receiptCreator_OppId.values() or OpportunityId in :mp_soOwner_OppId.values() ];
            
            list<OpportunityShare> opp_shareRecordToBeCreated = new list<OpportunityShare> ();
            if(oppShare <> null && !oppShare.isEmpty()){
                for(OpportunityShare oshare: oppShare){
                    userID_OppID_Combo.add(oshare.UserOrGroupId + '-' + oshare.OpportunityId);
                }
            }
            
            for(String key : newMap.keySet()){
                Receipt__c recObj = (Receipt__c) newMap.get(key);
                
                if(!userID_OppID_Combo.contains(recObj.createdById + '-' + recObj.SalesOrderOpportunityIDFormula__c)){
                    opp_shareRecordToBeCreated.add(new OpportunityShare(OpportunityAccessLevel ='Edit', OpportunityId=recObj.SalesOrderOpportunityIDFormula__c, RowCause='Manual',UserOrGroupId=recObj.createdById));
                }
                if(!userID_OppID_Combo.contains(recObj.SalesOrderOwnerIDFormula__c + '-' + recObj.SalesOrderOpportunityIDFormula__c)){
                    opp_shareRecordToBeCreated.add(new OpportunityShare(OpportunityAccessLevel ='Edit', OpportunityId=recObj.SalesOrderOpportunityIDFormula__c, RowCause='Manual',UserOrGroupId=recObj.SalesOrderOwnerIDFormula__c));
                }
            }
            
            if(!opp_shareRecordToBeCreated.isEmpty()){
                database.insert(opp_shareRecordToBeCreated,false);
            }
            
            // Account Share
            set<string> userID_AccID_Combo = new set<string>();
            list<AccountShare> accShare = [select Id, AccountId, UserOrGroupId from AccountShare where AccountId in :mp_receiptCreator_AccId.values() or AccountId in :mp_soOwner_AccId.values() ];
            
            list<AccountShare> acc_shareRecordToBeCreated = new list<AccountShare> ();
            if(accShare <> null && !accShare.isEmpty()){
                for(AccountShare ashare: accShare){
                    userID_AccID_Combo.add(ashare.UserOrGroupId + '-' + ashare.AccountId);
                }
            }
            
            for(String key : newMap.keySet()){
                Receipt__c recObj = (Receipt__c) newMap.get(key);
                
                if(!userID_AccID_Combo.contains(recObj.createdById + '-' + recObj.SalesOrderAccountIDFormula__c)){
                    acc_shareRecordToBeCreated.add(new AccountShare(AccountAccessLevel ='Edit', AccountId=recObj.SalesOrderAccountIDFormula__c, RowCause='Manual',UserOrGroupId=recObj.createdById));
                }
                if(!userID_AccID_Combo.contains(recObj.SalesOrderOwnerIDFormula__c + '-' + recObj.SalesOrderAccountIDFormula__c)){
                    acc_shareRecordToBeCreated.add(new AccountShare(AccountAccessLevel ='Edit', AccountId=recObj.SalesOrderAccountIDFormula__c, RowCause='Manual',UserOrGroupId=recObj.SalesOrderOwnerIDFormula__c));
                }
            }
            
            if(!acc_shareRecordToBeCreated.isEmpty()){
                database.insert(acc_shareRecordToBeCreated,false);
            }
            
        }
        
    } */
    
    //Receipt API Callout Trigger Point - BEGIN
    public static void sendReceiptsToOracle(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){ // call this After Insert and After Update
        
        set<string> currRecIds = new set<string>();
        set<string> bulkApproveRecIds = new set<string>(); // Bulk approve process
        set<string> currRecInvoiceocIds = new set<string>();
        set<string> lstcurrRecAllocIds = new set<string>();
        
        set<string> issueTypeCurrRecIds = new set<string>(); // issue type EBS
        set<string> isCreditNoteRecIds = new set<string>(); // issue type Credit Note
        
        //OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('Cut_Off_Date');
        //Date cutOffDate = Date.valueOf(oicParams.Value__c);
        
        
        /*if(oldMap == null){ // for Insert
            
            for(String key : newMap.keySet()){
                Receipt__c rec = (Receipt__c) newMap.get(key);
                if(rec.createdDate >= cutOffDate && rec.TransactionDate__c <> null && rec.TransactionDate__c <= system.Today() && rec.OraclePartyId__c <> null
                && rec.status__c == 'Cleared' && rec.OICIntegrationStatus__c <> 'S'){
                    currRecIds.add(rec.Id);  
                    system.debug('receipt id k: ' + rec.Id);
                } 
            }
            
            
        }
        else */
        if(oldMap <> null){ // for Update
            String TriggerEBSDate = Label.TriggerEBSDate; 
            for(String key : newMap.keySet()){
                Receipt__c newRecord = (Receipt__c) newMap.get(key);
                Receipt__c oldRecord;
                oldRecord = (Receipt__c)oldMap.get(newRecord.Id);
                
                // if(newRecord.createdDate >= cutOffDate && newRecord.OraclePartyId__c <> null && newRecord.TransactionDate__c <> null && newRecord.TransactionDate__c <= system.Today() && newRecord.TransactionDate__c <> oldRecord.TransactionDate__c){

                if(newRecord.OraclePartyId__c <> null && newRecord.status__c <> null && newRecord.status__c == 'Cleared' && newRecord.EBS_Clearing_Date__c >= Date.valueOf(TriggerEBSDate)){ // && newRecord.status__c != oldRecord.status__c
                    currRecIds.add(newRecord.Id);
                    
                }

                // bulk approve process from the screen
                //8.0 Comments this proces Moved to Approval Lwc
               /* if(newRecord.Receipt_Approved_By__c <> null && newRecord.Receipt_Approved_Checker__c == true && newRecord.Receipt_Approved_Checker__c != oldRecord.Receipt_Approved_Checker__c){
                    bulkApproveRecIds.add(newRecord.Id);
                } */
                
                
                /*if(newRecord.OraclePartyId__c == null && newRecord.status__c <> null && newRecord.status__c <> oldRecord.status__c && newRecord.status__c == 'Cleared' && newRecord.Modeofpayment__c == 'Credit Note'){
                    isCreditNoteRecIds.add(newRecord.Id);
                }*/                
            }            
        }       
        
          /*  if(!lstcurrRecAllocIds.isEmpty()){
                for(Allocation__c allIds :  [select id,Invoice__c from Allocation__c where Receipt__c IN :lstcurrRecAllocIds] ){
                    currRecInvoiceocIds.add(allIds.Invoice__c);
                }
            }*/

        if(!currRecIds.isEmpty()){
            //if(!system.isBatch() && system.label.OIC_ServiceActive == 'True' && !Test.isRunningTest())
            //sendReceiptsToOracle_Future(currRecIds);
            // kumaravel enabled API service for testing - charge api
            //sendReceiptsToOracle_Future(currRecIds);
            //18.0
            for(Allocation__c alloc : [ select id,Invoice__c,Invoice__r.RecordType.name from Allocation__c where Invoice__r.RecordType.name NOT IN ('Credit Memo','Debit Memo') AND Receipt__c IN :currRecIds] ){
                lstcurrRecAllocIds.add(alloc.id);
            }                           
        }

        // for bulk process 
        if(!bulkApproveRecIds.isEmpty()){
            sendReceiptsToOracle_Future(bulkApproveRecIds);
        }
        //8.0 Comments this proces Moved to Approval Lwc
        // ISSUE TYPE EBS
        /*if(!issueTypeCurrRecIds.isEmpty()){
            sendReceiptsToOracle_Future(issueTypeCurrRecIds);
        }*/
        
        if(!lstcurrRecAllocIds.isEmpty()){           
            //System.enqueueJob(new ReceiptClearedAllocation_Callout(currRecInvoiceocIds));  
            sendAllocationToOracle_Future(lstcurrRecAllocIds);         
        }
        // Credit Note Service
        /*if(!isCreditNoteRecIds.isEmpty()){
            sendCreditNoteOracle_Future(isCreditNoteRecIds);   
        }*/
        
    }
    
    @future(callout = true)
    public static void sendReceiptsToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createReceipt(recIds);
    }
    
    // 8.0 Receipt API Callout Trigger Point - START
    @InvocableMethod(label='Receipt OIC Callout' description='details page callout')
    public static void calloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendReceiptsToOracle_Future(recIds);
    }
    
    @future(callout = true) 
    public static void sendAllocationToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAllocation(recIds);
    }
    // Credit Note Service // // for test class issue to modon fee invoice deployment
    /*@future(callout = true) 
    public static void sendCreditNoteOracle_Future(set<string> recIds){
    OIC_ManageSalesforceDataController.createCreditReceipt(recIds);
    }*/
    //Receipt API Callout Trigger Point - END
    
    
    public static void createModonEgyptDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        
        lstDocumentsCurrent = DocumentsUtility.getEgyptDocumentsForSObject('Receipt__c', 'Modon - Egypt');
        
        Documents__c doc;
        
        
        
        if(!lstDocumentsCurrent.isEmpty()){
            
            
            
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            
            
            
            for(Receipt__c rObj : (List<Receipt__c>)newList){
                
                for(Documents__c templateDoc: lstDocumentsCurrent){
                    
                    doc = new Documents__c();
                    
                    doc.Name = templateDoc.Name;
                    
                    doc.Status__c = templateDoc.Status__c;
                    
                    doc.GenerateDocument__c = templateDoc.GenerateDocument__c;
                    
                    doc.SendForESignature__c = templateDoc.SendForESignature__c;
                    
                    doc.Receipt__c = rObj.Id;
                    
                    doc.ExpressionOfInterest__c = rObj.ExpressionOfInterest__c;
                    
                    lstDocumentsToInsert.add(doc);
                    
                }
                
            }
            
            
            
            if(!lstDocumentsToInsert.isEmpty()){
                
                insert lstDocumentsToInsert;
                
            }
            
        }
        
    }
    
    /*public static void sendPaymentStatusChangeNotification(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<Id> receiptsToNotify = new List<Id>();
    
        // Identify receipts where Status__c has changed
        for (Id recId : newMap.keySet()) {
            Receipt__c newRec = (Receipt__c)newMap.get(recId);
            Receipt__c oldRec = (Receipt__c)oldMap.get(recId);
            if (newRec.Status__c != oldRec.Status__c) {
                receiptsToNotify.add(recId);
            }
        }
    
        if (!receiptsToNotify.isEmpty()) {
            List<Receipt__c> receipts = [
                SELECT Id, Name, Status__c,
                       SalesOrder__c,
                       SalesOrder__r.Name,
                       SalesOrder__r.OwnerId,
                       SalesOrderInstallment__r.SalesOrder__c,
                       SalesOrderInstallment__r.SalesOrder__r.Name,
                       SalesOrderInstallment__r.SalesOrder__r.OwnerId
                FROM Receipt__c
                WHERE Id IN :receiptsToNotify
            ];
    
            for (Receipt__c rec : receipts) {
                Id ownerId;
                String salesOrderName;
    
                // Resolve Sales Order Owner and Name based on available relationship
                if (rec.SalesOrderInstallment__r != null && rec.SalesOrderInstallment__r.SalesOrder__r != null) {
                    ownerId = rec.SalesOrderInstallment__r.SalesOrder__r.OwnerId;
                    salesOrderName = rec.SalesOrderInstallment__r.SalesOrder__r.Name;
                } else if (rec.SalesOrder__r != null) {
                    ownerId = rec.SalesOrder__r.OwnerId;
                    salesOrderName = rec.SalesOrder__r.Name;
                }
    
                System.debug('>>> OwnerId: ' + ownerId + ', SalesOrder Name: ' + salesOrderName);
    
                List<Id> userRecipients = new List<Id>();
    
                // Determine recipients (user or queue members)
                if (ownerId != null) {
                    String ownerIdPrefix = String.valueOf(ownerId).substring(0, 3);
                    if (ownerIdPrefix == '005') {
                        userRecipients.add(ownerId);
                    } else if (ownerIdPrefix == '00G') {
                        for (GroupMember gm : [
                            SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :ownerId
                        ]) {
                            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                                userRecipients.add(gm.UserOrGroupId);
                            }
                        }
                    }
                }
    
                System.debug('>>> Final Recipients for Email: ' + userRecipients);
    
                if (!userRecipients.isEmpty()) {
                    NotificationUtility.sendNotification(
                        'Receipt_Status_Change', // Email Template Developer Name
                        userRecipients, // User Recipients
                        true, // sendBellNotification
                        rec.Id, // whatId
                        null,   // whoId
                        'Payment Status Changed', // Bell Title
                        'A receipt status has been updated.', // Bell Body
                        rec.Id,  // Target Record id for Bell Notification
                        'Receipt_Status_Change'        // ✅ Bell Notification Type DeveloperName
                    );
                } else {
                    System.debug('>>> No recipients found for Receipt: ' + rec.Id);
                }
            }
        }
    }*/
    
    
    public static void CreateDefaultSR(List<Receipt__c> newList, Map<Id, Receipt__c> oldMap) {
        Set<Id> salesOrderIds = new Set<Id>();

        for (Receipt__c newRec : newList) {
            if (oldMap == null || !oldMap.containsKey(newRec.Id)) {
                continue;
            }
            Receipt__c oldRec = oldMap.get(newRec.Id);
            if (oldRec == null) {
                continue;
            }

            if (
                newRec.Cheque_Bounce_Reason__c == 'Insufficient Funds' &&
                oldRec.Cheque_Bounce_Reason__c != 'Insufficient Funds'
            ) {
                if (newRec.SalesOrderInstallment__c != null) {
                    salesOrderIds.add(newRec.SalesOrderInstallment__c);
                }
            }
        }

        if (!salesOrderIds.isEmpty()) {
            List<Receipt__c> receiptsWithSO = [
                SELECT Id,
                       SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.Name 
                FROM Receipt__c
                WHERE SalesOrderInstallment__c IN :salesOrderIds
                      AND Cheque_Bounce_Reason__c = 'Insufficient Funds'
            ];
                
                            Map<Id, Set<String>> soIdToInstIds = new Map<Id, Set<String>>();
                Set<Id> soIds = new Set<Id>();
                
                for (Receipt__c rec : receiptsWithSO) {
                    Id soId = rec.SalesOrderInstallment__r?.SalesOrder__c;
                    String instName = rec.SalesOrderInstallment__r?.Name;
                    if (soId != null) {
                        soIds.add(soId);
                        if (instName != null) {
                            if (!soIdToInstIds.containsKey(soId)) {
                                soIdToInstIds.put(soId, new Set<String>());
                            }
                            soIdToInstIds.get(soId).add(instName);
                        }
                    }
                }


            if (!soIds.isEmpty()) {
                List<SalesOrder__c> salesOrders = [
                    SELECT Id, Name, CustomerAccount__c, Unit__c, Opportunity__c
                    FROM SalesOrder__c
                    WHERE Id IN :soIds
                ];

                String reason=Label.SRCheckBounceReason;
                //Old Default Process Remove
               // DefaultSRContrroler.createDefaultSRForSalesOrders(salesOrders,reason,soIdToInstIds);
            }
        }
    }

    //v5.0 (lines 1183 - 1221)
    /**
     * @description
     * Prepares Modon Egypt Receipt records for Oracle insertion and enqueues
     * an asynchronous sync job.
     *
     * This method:
     *  - Skips execution when the current user is the Modon Egypt integration user
     *    to prevent recursive or duplicate Oracle sync calls
     *  - Filters eligible Receipts based on business rules:
     *      • EOI Receipts are synced only when the EOI status is 'EOI Confirmed'
     *      • Sales Order–linked Receipts are always eligible
     *  - Updates Oracle integration status and message to indicate a pending insert sync
     *  - Enqueues a Queueable job to insert eligible Receipts into Oracle
     *
     * @param newList
     *        List of SObjects (typically Trigger.new) containing Receipt__c records
     */
    public static void passEgyptReceipts(List<SObject> newList){
        // (v17.0 - Start)
        //if (Egypt_PaymentPlanSwapperController.isEgyptPaymentPlanSwap) {
            //return;
        //}
        // (v17.0 - End)
        // Check if the current user is an integration user
        User currentUser = [SELECT Id, Name, Profile.Name 
                            FROM User 
                            WHERE Id = :UserInfo.getUserId()];
        
        Boolean isIntegrationUser = false;
        
        // Check profile
        if (currentUser.Profile.Name == ModonEgyptConstants.MODON_EGYPT_INTEGRATION_PROFILE  && currentUser.Name == ModonEgyptConstants.MODON_EGYPT_INTEGRATION_USER) {	//v14.0 (Updated constants)
            isIntegrationUser = true;
        }
        
        if (!isIntegrationUser) {	//v15.0 (Updated code and SOQL)
            Set<Id> installmentIds = new Set<Id>();
    
            //Collect Installment Ids
            for (Receipt__c rec : (List<Receipt__c>)newList) {
                if (rec.SalesOrderInstallment__c != null) {
                    installmentIds.add(rec.SalesOrderInstallment__c);
                }
            }
            
            System.debug('installmentIds>>>'+installmentIds);
            
            //Get Installments with Sales Order
            Map<Id, SalesOrderInstallments__c> installmentMap =
                new Map<Id, SalesOrderInstallments__c>([
                    SELECT Id, SalesOrder__c,
                           SalesOrder__r.Status__c,
                    	   MilestoneNumber__c,
                    	   SalesOrder__r.Is_Downpayment_Collected_Modon_Egypt__c, SalesOrder__r.Is_SPA_Signed_Customer__c //14.0 (Added SalesOrder__r.Is_SPA_Signed_Customer__c field in query)

                    FROM SalesOrderInstallments__c
                    WHERE Id IN :installmentIds
                ]);
            
            Set<Id> receiptIds = new Set<Id>();
            for(Receipt__c receipt : (List<Receipt__c>)newList){
                //v4.5 (line 1195 - 1200) Updated logic to restrict EOI Receipts sync when reeipts gets created
                if (receipt.ExpressionOfInterest__c != null && receipt.ExpressionOfInterest__r.Status__c == ModonEgyptConstants.EOI_STATUS_CONFIRMED) {
                    System.debug('Entered>>>>>');
                    receiptIds.add(receipt.Id);
                }
                else if (receipt.SalesOrder__c != null) {
                    SalesOrderInstallments__c inst = installmentMap.get(receipt.SalesOrderInstallment__c);
                    if(inst != null && inst.SalesOrder__c != null){
                        //(v23 START) Updated logic to allow receipts for any milestone to sync to Oracle once Downpayment is Collected/Cleared
                        if (inst.SalesOrder__r.Is_Downpayment_Collected_Modon_Egypt__c == true) {
                            receiptIds.add(receipt.Id);
                        }
                        //(v23 END)
                    }
                }               
            }

            if(!receiptIds.isEmpty()){
                List<Receipt__c> recsToUpdate = new List<Receipt__c>();
                for (Id recId : receiptIds) {
                    recsToUpdate.add(new Receipt__c(
                        Id = recId,
                        Oracle_Integration_Status_Modon_Egypt__c = ModonEgyptConstants.ORACLE_INTEGRATION_STATUS_PENDING,
                        Oracle_Integration_Message_Modon_Egypt__c = ModonEgyptConstants.ORACLE_INTEGRATION_MESSAGE_INSERT_PENDING
                    ));
                }
                Database.update(recsToUpdate, false);	//v15.0
                System.enqueueJob(new ModonEgypt_ReceiptInsertOracleQueueable(receiptIds));
            }
        }
    }
    
    //v5.1 (lines 1244 - 1304)
    /**
     * @description
     * Detects meaningful updates to Modon Egypt Receipt records and synchronizes
     * those changes with Oracle.
     *
     * This method:
     *  - Skips execution when invoked by the Modon Egypt integration user to
     *    prevent recursive Oracle updates
     *  - Converts generic trigger inputs (SObject collections) into Receipt__c
     *    types for safe field-level comparison
     *  - Compares key financial and payment-related fields to identify Receipts
     *    requiring an Oracle update sync
     *  - Updates Oracle integration status and message to indicate a pending update
     *  - Enqueues a Queueable job to asynchronously update Receipts in Oracle
     *
     * @param newListGeneric
     *        List of SObjects (typically Trigger.new) containing Receipt__c records
     * @param oldMapGeneric
     *        Map of SObjects (typically Trigger.oldMap) containing previous Receipt__c values
     */
    public static void updateEgyptReceiptsToOracle(List<SObject> newListGeneric, Map<Id, SObject> oldMapGeneric) {

        // (v19.0 - Start)
        //if (Egypt_PaymentPlanSwapperController.isEgyptPaymentPlanSwap) {
            //return;
        //}
        // (v19.0 - End)
        
        // Check if the current user is an integration user
        User currentUser = [SELECT Id, Name, Profile.Name 
                            FROM User 
                            WHERE Id = :UserInfo.getUserId()];
        
        Boolean isIntegrationUser = currentUser.Profile.Name == ModonEgyptConstants.MODON_EGYPT_INTEGRATION_PROFILE 
            						&& currentUser.Name == ModonEgyptConstants.MODON_EGYPT_INTEGRATION_USER;	//v14.0 (Added Constants)
        
        // Check profile
        if (isIntegrationUser) {
            return;
        }
        
		// Now the original logic works perfectly	//v15.0
		Map<Id, Receipt__c> receiptsToSync = new Map<Id, Receipt__c>();

		for (SObject recSObject : newListGeneric) {
			Receipt__c rec = (Receipt__c) recSObject;
            Receipt__c oldRec = (oldMapGeneric != null) ? (Receipt__c) oldMapGeneric.get(rec.Id) : null;
            if (oldRec == null) {
                continue;
            }

			if (!String.isBlank(rec.Oracle_Receipt_Id__c) &&
                (rec.Status__c != oldRec.Status__c ||
                    rec.AppliedAmount__c != oldRec.AppliedAmount__c ||
                    rec.RemainingAmount__c != oldRec.RemainingAmount__c ||
                    rec.Modeofpayment__c != oldRec.Modeofpayment__c ||
                    rec.Cheque_Number__c != oldRec.Cheque_Number__c ||
                    rec.TransactionNumber__c != oldRec.TransactionNumber__c ||
                    rec.SalesOrder__c != oldRec.SalesOrder__c ||
                    rec.SalesOrderInstallment__c != oldRec.SalesOrderInstallment__c
                    )) 
                {
				    receiptsToSync.put(rec.id, rec);
                }
            }
        
            if (!receiptsToSync.isEmpty()) {
                List<Receipt__c> recsToUpdate = new List<Receipt__c>();
			for (Id recId : receiptsToSync.keySet()) {
                    recsToUpdate.add(new Receipt__c(
                        Id = recId,
					Oracle_Integration_Status_Modon_Egypt__c = ModonEgyptConstants.ORACLE_INTEGRATION_STATUS_PENDING,
					Oracle_Integration_Message_Modon_Egypt__c = ModonEgyptConstants.ORACLE_INTEGRATION_MESSAGE_UPDATE_PENDING
                    ));
                }
			Database.update(recsToUpdate, false);
			System.enqueueJob(new ModonEgypt_ReceiptOracleSyncQueueable((List<Receipt__c>)receiptsToSync.values()));
            }
        }

    
    /**
        * 5.0 Handles EBS receipt synchronization logic during Receipt__c updates.
        *
        * This method is invoked from both BEFORE UPDATE and AFTER UPDATE trigger contexts.
        * It performs the following actions:
        * 1. Updates Receipt status based on Oracle Party ID changes and business rules.
        * 2. Resets approval-related fields when a receipt is returned.
        * 3. Collects affected Receipt records whose status changes to
        *    Cancelled, Bounced, or Reversed.
        * 4. Updates related Allocation__c records by resetting amounts and
        *    setting their status to 'Unapplied'.
        *
        * param oldMap   Map of old Receipt__c records from trigger.old
        * param isBefore Indicates execution in BEFORE UPDATE context
        * param isAfter  Indicates execution in AFTER UPDATE context
        */
    
    public static void updatingEbsSyncReceipt(Map<Id, SObject> newMap,Map<Id, SObject> oldMap,Boolean isBefore,Boolean isAfter) {
        // Set to store Receipt Ids whose allocations need to be updated
        Set<Id> lstCurrRecAllocIds = new Set<Id>();
        
        // Validate oldMap (required for update comparison)
        if (oldMap != null) {
            
            for (Id key : newMap.keySet()) {
                
                Receipt__c newRecord = (Receipt__c) newMap.get(key);
                Receipt__c oldRecord = (Receipt__c) oldMap.get(key);
                if (newRecord == null || oldRecord == null) {
                    continue;
                }
                
                // Set status to Confirmed when Oracle Party ID is updated
                 // 13.0 bypass the status update on OraclePartyId 
                if (isBefore && newRecord.OraclePartyId__c != null && newRecord.OraclePartyId__c != oldRecord.OraclePartyId__c && newRecord.Status__c == 'In Progress') {
                    newRecord.Status__c = 'Confirmed';
                }                 
                
                // When status is Returned, reset approval details // // need to test and remove belowm code
                if (isBefore && newRecord.Oracle_Id_Temporary__c != null && newRecord.Status__c != oldRecord.Status__c && newRecord.Status__c == 'Rejected') {
                    newRecord.Status__c = 'In Progress';
                    newRecord.Receipt_Approved_Checker__c = false;
                    newRecord.Receipt_Approved_Date__c = null;
                    newRecord.Receipt_Approved_By__c = null;
                    newRecord.Oracle_Id_Temporary__c=null;
                }
               
                // Collect Receipt IDs for allocation reset  // need to test and remove belowm code
                if (isAfter && newRecord.Status__c != oldRecord.Status__c && 
                    (newRecord.Status__c == 'Bounced' || newRecord.Status__c == 'Cancelled' || newRecord.Status__c == 'Returned to customer' )) {
                        lstCurrRecAllocIds.add(newRecord.Id);
                    }
            }
            
            if (!lstCurrRecAllocIds.isEmpty()) {
                
                Map<Id, Allocation__c> updateAllocationMap = new Map<Id, Allocation__c>();
                
                for (Allocation__c alloc : [SELECT Id, Receipt__c FROM Allocation__c WHERE Receipt__c IN :lstCurrRecAllocIds   ]) {
                    updateAllocationMap.put(
                        alloc.Id,
                        new Allocation__c(
                            Id = alloc.Id,
                            AllocationAmount__c = 0,
                            InProgressReceiptAmount__c = 0,
                            ApprovedReceiptAmount__c = 0,
                            Status__c = 'Unapplied'
                        )
                    );
                }
                
                // Perform partial update
                if (!updateAllocationMap.isEmpty()) {
                    Database.SaveResult[] results =
                        Database.update(updateAllocationMap.values(), false);
                    
                    for (Database.SaveResult sr : results) {
                        if (!sr.isSuccess()) {
                            for (Database.Error err : sr.getErrors()) {
                                System.debug('Allocation Update Error: ' + err.getMessage());
                            }
                        }
                    }
                }
            }
        }
    }

    /** 7.0
 * Handles updates to Receipt records and identifies those that
 * transition from an Unidentified Account to a valid Account.
 * These updates are then sent to Oracle.
 *
 * @param newList List of updated Receipt records
 * @param oldMap  Map of Receipt records before update
 */
    public static void sendUnIdentifiedReceiptUpdate(List<Receipt__c> newList, Map<Id, sObject> oldMap){
        Set<String> receiptIds = new Set<String>();
        map<id,sObject> newMap=new Map<id,sObject>();
        if(oldMap != null){
            for (Receipt__c newRec : newList) {
                Receipt__c old_Receipt = (Receipt__c)oldMap.get(newRec.Id);
                if (old_Receipt == null) {
                    continue;
                }
                if(newRec.OraclePartyId__c != '' && old_Receipt.Account__c == System.Label.Unidentified_Account
                   && old_Receipt.Account__c != newRec.Account__c && newRec.Account__c != null){
                    receiptIds.add(newRec.Id);
                    newMap.put(newRec.Id,newRec);
                }
            }
        }
        
        if(receiptIds.size() > 0){
            createAllocationRecord(newMap);
            sendUnIdentifiedReceipt_Future(receiptIds);
        }
    }
    /** 7.0
 * Future method to send Unidentified Receipt records to Oracle.
 * Runs asynchronously to allow HTTP callouts.
 *
 * @param recIds Set of Receipt record Ids to be sent to Oracle
 */
    @future(callout = true)
    public static void sendUnIdentifiedReceipt_Future(set<string> recIds){
        OIC_ManageEbsDataController.createUnidentifiedReceipt(recIds);
    }
    
    //v4.6 (line 1282 - 1345)
    //Only related to Modon - Egypt
    //Added this method to check of the Payment mode is supported or not.
    public static void checkReceiptMethodAndRemittanceBankAccountNumber(List<SObject> modonEgyptReceipts) {
        
        List<SObject> validReceipts = new List<SObject>();

        if (modonEgyptReceipts == null || modonEgyptReceipts.isEmpty()) {
            return;
        }

        // First check: Validate CurrencyIsoCode is not null/empty
        for (SObject sobj : modonEgyptReceipts) {
            Receipt__c receipt = (Receipt__c) sobj;
            if (String.isBlank(receipt.CurrencyIsoCode)) {
                receipt.addError('Currency is required for Modon - Egypt payments.');
            }
        }

        Set<String> bankNames = new Set<String>();
        Set<String> modeofPayments = new Set<String>();
        Set<String> currencies = new Set<String>();

        for (SObject sobj : modonEgyptReceipts) {
            Receipt__c receipt = (Receipt__c) sobj;
            if (String.isNotBlank(receipt.MIRE_Bank__c)) bankNames.add(receipt.MIRE_Bank__c);
            if (String.isNotBlank(receipt.Modeofpayment__c)) modeofPayments.add(receipt.Modeofpayment__c);
            if (String.isNotBlank(receipt.CurrencyIsoCode)) currencies.add(receipt.CurrencyIsoCode);
        }

        Map<String, Modon_Receipt_Mapping__mdt> mappingsMap = new Map<String, Modon_Receipt_Mapping__mdt>();

        if (!bankNames.isEmpty() && !modeofPayments.isEmpty()) {
            for (Modon_Receipt_Mapping__mdt m : [
                SELECT Bank_Name__c, Mode_of_Payment__c, Remittance_Bank_Account_No__c, Receipt_Method__c, Currency__c
                FROM Modon_Receipt_Mapping__mdt
                WHERE Bank_Name__c IN :bankNames AND Mode_of_Payment__c IN :modeofPayments AND Currency__c IN : currencies
            ]) {
                mappingsMap.put(m.Bank_Name__c + '|' + m.Mode_of_Payment__c + '|' + m.Currency__c, m);
            }
        }

        for (SObject sobj : modonEgyptReceipts) {
            Receipt__c receipt = (Receipt__c) sobj;

            // Skip records that already have currency error
            if (String.isBlank(receipt.CurrencyIsoCode)) {
                continue;
            }

            String mappingKey = receipt.MIRE_Bank__c
                + '|' + receipt.Modeofpayment__c + '|' + receipt.currencyISOCode;
            Modon_Receipt_Mapping__mdt mapping = mappingsMap.get(mappingKey);
            
            if (mapping == null) {
                receipt.addError('The payment with Bank "' + receipt.MIRE_Bank__c + '", Mode of Payment "' + receipt.Modeofpayment__c + '" and Currency "' + receipt.CurrencyIsoCode + '" is not supported.');
            } else {
                validReceipts.add(receipt);
            }
        }
        
        //Calling the populateAmountText method which was called earlier from the BeforeInsert and beforeUpdate methods of the trigger handler
        //This method gets called when the error is not thrown
        if (!validReceipts.isEmpty()) {
            populateAmountText(validReceipts);
        }
      
    }
    
    //v5.4 - Introduced method to rollUp Sum of all related receipts's Total Amount which has mode of payment as 'Cheque' to Sales Order on Updating and Creation.
    //v11.0  Updated rollUpChequeTotalAmountToSO to also populate EgyptChequeReceiptTotalAmountInWords__c directly, bypassing SO trigger recursion guard.
    public static void rollUpChequeTotalAmountToSO(
        Map<Id, SObject> newMap,
        Map<Id, SObject> oldMap
    ) {
        Set<Id> soIds = new Set<Id>();

        // Collect parent IDs
        for (SObject sobj : newMap.values()) {
            Receipt__c receipt = (Receipt__c) sobj;
            if (receipt.SalesOrder__c != null) {
                soIds.add(receipt.SalesOrder__c);
            }
        }

        if (oldMap != null) {
            for (SObject oldSobj : oldMap.values()) {
                Receipt__c oldReceipt = (Receipt__c) oldSobj;
                if (oldReceipt.SalesOrder__c != null) {
                    soIds.add(oldReceipt.SalesOrder__c);
                }
            }
        }

        if (soIds.isEmpty()) return;

        // Query Sales Orders to get CurrencyIsoCode
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([
            SELECT Id, CurrencyIsoCode
            FROM SalesOrder__c
            WHERE Id IN :soIds
        ]);

        // Aggregate query with FILTER
        List<AggregateResult> results = [
            SELECT SalesOrder__c soId, SUM(TotalAmount__c) total
            FROM Receipt__c
            WHERE SalesOrder__c IN :soIds
            AND Modeofpayment__c = 'Cheque'
            AND SalesOrderInstallment__r.MilestoneNumber__c != 1
            AND Status__c != 'Cancelled' //v20.0
            GROUP BY SalesOrder__c
        ];

        Map<Id, Decimal> totalsBySO = new Map<Id, Decimal>();
        for (AggregateResult soRec : results) {
            totalsBySO.put(
                (Id) soRec.get('soId'),
                (Decimal) soRec.get('total')
            );
        }

        // Prepare parent updates
        List<SalesOrder__c> salesOrdersToUpdate = new List<SalesOrder__c>();
        for (Id soId : soIds) {
            Decimal chequeTotal = totalsBySO.containsKey(soId)
                ? totalsBySO.get(soId)
                : 0;

            //v13.0 - removed local method call and replaced with utilities class for amount in words conversion
            SalesOrder__c soToUpdate = new SalesOrder__c(
                Id = soId,
                EgyptChequeReceiptTotalAmount__c = chequeTotal
            );

            // Populate amount in words directly to avoid dependency on SO trigger re-firing
            //v12.0 - updated to use utilities class for amount in words conversion
            if (chequeTotal != null && chequeTotal != 0 && soMap.containsKey(soId) && soMap.get(soId).CurrencyIsoCode != null) {
                //v16.0
                soToUpdate.EgyptChequeReceiptTotalAmountInWords__c = ModonEgyptUtilities.convertAmountInWordsTextEnglish(chequeTotal, soMap.get(soId).CurrencyIsoCode);
            } else {
                soToUpdate.EgyptChequeReceiptTotalAmountInWords__c = null;
            }

            salesOrdersToUpdate.add(soToUpdate);
        }

        if (!salesOrdersToUpdate.isEmpty()) {
            update salesOrdersToUpdate;
        }
    }
    // start 17.0 
	// This is used for the Excess Amount refound to AR and AP
     public static void processCustomerRefund(List<Receipt__c> newList, Map<Id, sObject> oldMap) {
        Map<Id, sObject>          newMap       = new Map<Id, sObject>();
        Map<String, Receipt__c>   map_Receipt  = new Map<String, Receipt__c>();
        Map<String, Invoice__c>   map_Invoice  = new Map<String, Invoice__c>();
        Map<Id, Id>               invoiceParent = new Map<Id, Id>(); 
        Set<Id>                   receiptIds   = new Set<Id>();
        Set<Id>                   customerIds   = new Set<Id>();//V24.0
        List<Invoice__c>          lst_Invoice  = new List<Invoice__c>();
    
        Schema.RecordTypeInfo debitMemoRt =
            Schema.SObjectType.Invoice__c
                .getRecordTypeInfosByDeveloperName()
                .get('Debit_Memo');
        if (debitMemoRt == null) {
            return;
        }
        Id debitMemoRecordTypeId = debitMemoRt.getRecordTypeId();
    
        if (oldMap != null) {
            for (Receipt__c newRec : newList) {
                if (newRec == null || newRec.Id == null) {
                    continue;
                }
                receiptIds.add(newRec.Id);
            }
            
            if (!receiptIds.isEmpty()) {  
                for (Allocation__c alloc : [
                    SELECT Id, Receipt__c, Invoice__c
                    FROM   Allocation__c
                    WHERE  Receipt__c IN :receiptIds
                ]) {
                    invoiceParent.put(alloc.Receipt__c, alloc.Invoice__c);
                }
            }
    
            for (Receipt__c newRec : newList) {
                Receipt__c old_Receipt = (Receipt__c) oldMap.get(newRec.Id);
    			system.debug('old_Receipt----'+old_Receipt);
                system.debug('newRec----'+newRec);
                if (old_Receipt == null) {
                    continue;
                }
                if (newRec.Receipt_Excess_Amount__c  >  0
                    && newRec.CustomerRefundAmount__c != old_Receipt.CustomerRefundAmount__c
                    && newRec.CustomerRefundAmount__c >  0
                    && newRec.Status__c               == 'Cleared'
                    && String.isNotBlank(newRec.OraclePartyId__c)
                    && newRec.Receipt_Excess_Amount__c >= newRec.CustomerRefundAmount__c) {
    
                    Invoice__c obj_Invoice = new Invoice__c();
                    obj_Invoice.RecordTypeId             = debitMemoRecordTypeId;
                    obj_Invoice.Account__c               = newRec.Account__c;
                    obj_Invoice.Transaction_Type__c      = 'Customer Refund';
                    obj_Invoice.Sales_Order__c           = newRec.SalesOrder__c;
                    obj_Invoice.SalesOrderInstallment__c = newRec.SalesOrderInstallment__c;
                    obj_Invoice.InvoiceAmount__c         = newRec.CustomerRefundAmount__c;
                    obj_Invoice.InvoiceDate__c           = System.today();
                    obj_Invoice.RefundOracleid__c        = newRec.OraclePartyId__c;
                    obj_Invoice.isRefundReceipt__c       = true;
                    obj_Invoice.Parent_Invoice__c        = invoiceParent.containsKey(newRec.Id)
                                                            ? invoiceParent.get(newRec.Id)
                                                            : null;
                    lst_Invoice.add(obj_Invoice);
    
                    if (!map_Receipt.containsKey(newRec.Id)) {
                        map_Receipt.put(newRec.Id, newRec);
                    }
                    if (!map_Invoice.containsKey(newRec.Id)) {
                        map_Invoice.put(newRec.Id, obj_Invoice);
                    }
                }
            }
        }
    
        if (!lst_Invoice.isEmpty()) { 
            try {
            insert lst_Invoice;
    
            List<Allocation__c> lst_Allocation = new List<Allocation__c>();
            Set<String>         setInvId       = new Set<String>();
    
            for (Receipt__c obj_Receipt : map_Receipt.values()) {
                Invoice__c obj_Inv = map_Invoice.containsKey(obj_Receipt.Id)
                                        ? map_Invoice.get(obj_Receipt.Id)
                                        : null;
                if (obj_Inv != null) {
                    setInvId.add(obj_Inv.Id);
    
                    Allocation__c obj_Allocation = new Allocation__c();
                    obj_Allocation.Receipt__c                 = obj_Receipt.Id;
                    obj_Allocation.Invoice__c                 = obj_Inv.Id;
                    obj_Allocation.AllocationDate__c          = System.today();
                    obj_Allocation.AllocationAmount__c        = obj_Inv.InvoiceAmount__c;
                    obj_Allocation.Status__c                  = 'Applied';
                    obj_Allocation.InProgressReceiptAmount__c = obj_Inv.InvoiceAmount__c;
                    lst_Allocation.add(obj_Allocation);
                }
            }
    
            if (!lst_Allocation.isEmpty()) {
                insert lst_Allocation;
            }
    
            if (!setInvId.isEmpty()) {                      
                // OIC_ManageBankInvoiceData.createRefundMemo(setInvId);





            }
            } catch (Exception ex) {
                addErrorsToSObjects(newList, ex);
            }
        }
    } // End 14.0

    //v22.0
    /**
     * Prevents insertion of a Receipt__c record if its Cheque_Number__c or
     * TransactionNumber__c already exists on:
     *   1) Any existing record in the database, OR
     *   2) Another record within the same insert batch (bulk-safety).
     *
     * @param newReceipts  Trigger.new list of Receipt__c records being inserted
     */
    public static void preventModonEgyptReceiptNumberDuplication(List<Receipt__c> newReceipts) {

        // 1. Collect non-blank Cheque Numbers & Transaction Numbers from the incoming batch
        Set<String> chequeNumbers = new Set<String>();
        Set<String> transactionNumbers = new Set<String>();

        for (Receipt__c rec : newReceipts) {
            if (String.isNotBlank(rec.Cheque_Number__c)) {
                chequeNumbers.add(rec.Cheque_Number__c);

            }
            if (String.isNotBlank(rec.TransactionNumber__c)) {
                transactionNumbers.add(rec.TransactionNumber__c);







            }
        }

        // Nothing to validate — exit early to avoid an unnecessary query
        if (chequeNumbers.isEmpty() && transactionNumbers.isEmpty()) {
            return;
        }

        // 2. Single bulkified query to fetch existing matches (no SOQL inside a loop)
        Map<String, Receipt__c> existingByCheque = new Map<String, Receipt__c>();
        Map<String, Receipt__c> existingByTransaction = new Map<String, Receipt__c>();

        for (Receipt__c existing : [
            SELECT Id, Name, Cheque_Number__c, TransactionNumber__c
            FROM Receipt__c
            WHERE Source_Entity__c = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY AND Status__c IN:ModonEgyptConstants.RECEIPT_DUPLICATE_CHECK_STATUSES
                AND (Cheque_Number__c IN :chequeNumbers OR TransactionNumber__c IN :transactionNumbers)
        ]) {
            if (String.isNotBlank(existing.Cheque_Number__c)) {
                existingByCheque.put(existing.Cheque_Number__c, existing);
            }
            if (String.isNotBlank(existing.TransactionNumber__c)) {
                existingByTransaction.put(existing.TransactionNumber__c, existing);
            }
        }

        // 3. Track values seen within this same batch (handles duplicates
        //    inserted together in one DML statement, before they hit the DB)
        Set<String> seenChequeInBatch = new Set<String>();
        Set<String> seenTransactionInBatch = new Set<String>();

        // 4. Validate each incoming record and attach an error if duplicate found
        for (Receipt__c rec : newReceipts) {

            if (String.isNotBlank(rec.Cheque_Number__c)) {
                Boolean existsInDb    = existingByCheque.containsKey(rec.Cheque_Number__c);
                Boolean existsInBatch = seenChequeInBatch.contains(rec.Cheque_Number__c);

                if (existsInDb || existsInBatch) {
                    rec.Cheque_Number__c.addError(
                        'A receipt "' + existingByCheque?.get(rec.Cheque_Number__c)?.Name + '" with Cheque Number "' + rec.Cheque_Number__c + '" already exists.'
                    );
                } else {
                    seenChequeInBatch.add(rec.Cheque_Number__c);



                }
            }

            if (String.isNotBlank(rec.TransactionNumber__c)) {
                Boolean existsInDb    = existingByTransaction.containsKey(rec.TransactionNumber__c);
                Boolean existsInBatch = seenTransactionInBatch.contains(rec.TransactionNumber__c);

                if (existsInDb || existsInBatch) {
                    rec.TransactionNumber__c.addError(
                        'A receipt "' + existingByTransaction?.get(rec.TransactionNumber__c)?.Name + '" with Transaction Number "' + rec.TransactionNumber__c + '" already exists.'
                    );
                } else {
                    seenTransactionInBatch.add(rec.TransactionNumber__c);
                }
            }
        }
    }
    
    /**
	* Validates that the related Account's bank details are populated whenever
	* Customer Refund Amount is changed on the Receipt. If any bank field is
	* blank, an error is added to the Receipt record so the save is blocked.
	*/
    //V24.0 For Entire method
    public static void validateAccountBankDetailsOnRefund(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Receipt__c> receipts = (List<Receipt__c>) newList;
        
        // Collect Account Ids only for receipts where the refund amount actually changed
        Set<Id> accountIds = new Set<Id>();
        for (Receipt__c rec : receipts) {
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(rec.Id) : null;
            if (oldRec != null
                && rec.CustomerRefundAmount__c != oldRec.CustomerRefundAmount__c
                && rec.Account__c != null) {
                    accountIds.add(rec.Account__c);
                }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        // Query the bank detail fields for the related Accounts
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Bank_Account_Number__c, Swift_Code__c, Bank_Branch_Type__c,
            Beneficiary_Name__c,Bank_Name__c,IBAN_Number__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
        
        // Query the 'IBAN Letter' Documents__c child records for the related Accounts
        Map<Id, Id> accountToIbanDocId = new Map<Id, Id>();
        Set<Id> ibanDocIds = new Set<Id>();
        for (Documents__c doc : [
            SELECT Id, PrimaryContact__r.AccountId, Account__c
            FROM Documents__c
            WHERE (PrimaryContact__r.AccountId IN :accountIds OR Account__c IN:accountIds) AND Name = 'IBAN Letter'
        ]) {
        	//V25.0 - primaryContact accountId
        	//V25.1 - Union Primary Contact and Account
            if(doc.Account__c != null){
                accountToIbanDocId.put(doc.Account__c, doc.Id);
            }else if(doc.PrimaryContact__r.AccountId != null){
                accountToIbanDocId.put(doc.PrimaryContact__r.AccountId, doc.Id);
            }            
            ibanDocIds.add(doc.Id);
        }
        
        // Determine which IBAN Letter documents actually have a file attached
        Set<Id> ibanDocIdsWithFile = new Set<Id>();
        if (!ibanDocIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :ibanDocIds
            ]) {
                ibanDocIdsWithFile.add(cdl.LinkedEntityId);
            }
        }
        
        // Add an error on each receipt whose Account is missing any bank detail
        for (Receipt__c rec : receipts) {
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(rec.Id) : null;
            if (oldRec == null || rec.CustomerRefundAmount__c == oldRec.CustomerRefundAmount__c || rec.Account__c == null) {
                continue;
            }
            
            Account acc = accountMap.get(rec.Account__c);
            if (acc == null
                || String.isBlank(acc.Bank_Account_Number__c)
                || String.isBlank(acc.Swift_Code__c)
                || String.isBlank(acc.Bank_Name__c)
                || String.isBlank(acc.IBAN_Number__c)
                || String.isBlank(acc.Beneficiary_Name__c)) {
                    rec.addError('Customer Bank details are incomplete, ' +
                                 'Please populate all bank detail fields before entering a Customer Refund Amount.');
                }
            
            // Ensure the 'IBAN Letter' document exists and has a file attached
            Id ibanDocId = accountToIbanDocId.get(rec.Account__c);
            if (ibanDocId == null || !ibanDocIdsWithFile.contains(ibanDocId)) {
                rec.addError('IBAN Letter is Missing for Customer, Please attach under Document placeholder');
            }
        }
    }
    //V24.0 - Ends

    private static void addErrorsToSObjects(List<SObject> records, Exception ex) {
        if (ex == null) {
            return;
        }
        if (records == null || records.isEmpty()) {
            throw ex;
        }
        for (SObject record : records) {
            if (record != null) {
                record.addError(ex.getMessage());
            }
        }
    }

    private class ReceiptHelperException extends Exception {}
}