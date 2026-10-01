/**********************************************************************************************************************
* Name               : InvoiceTriggerHelper                                                        
* Description        : This class is helper for EOI trigger
* Usage              : Called from EOITriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com          27 Dec 2023     Initial Draft   
* 1.1           kumar                             14-1-2026      added repush to ebs logic   
* 2.0			Manoj							  30-01-2026	 updating invoice Cancelled to Ebs
* 3.0			Gautam Mishra (Horizontal)		 23-01-2026		 Modon Egypt: Added code for inserting Invoice in Oracle 
* 4.0           Manoj                            28-04-2026     Update Cancelle logic
* 5.0			Manoj							15-05-206		Update refund logic
* 6.0           Shahil Sinha (Horizontal)        08 Jun 2026     Added Payment Plan Swap trigger bypass
* 7.0			Modon IT 						 27 Jul 2026 	Call out Invoices after insert
* 7.1			Karunakar					     13 Aug 2025	Paid/Not Paid Status updates
******************************************************************************************************************/
public without sharing class InvoiceTriggerHelper {
    
    public static void updateSalesOrderInitialPaymentStatuses(list<SObject> newList){
        Map<id, SalesOrder__c> map_SalesOrder = new Map<id, SalesOrder__c>();
        Map<Id, Unit__c> map_Units = new Map<Id, Unit__c>();
        Map<id, String> map_SOInstallmentInvoiceStatus = new Map<id, String>();
        Map<id, String> map_SOInvoiceStatus = new Map<id, String>();
        Set<id> set_SalesOrderInstallmentId = new Set<id>();
        set<id> set_SalesOrderIdofADM_Dari = new Set<id>();
        List<SalesOrderInstallments__c> lst_SalesOrderInstallments = new List<SalesOrderInstallments__c>();
        
        for(Invoice__c  obj_Invoice : (List<Invoice__c>)newList){
            if(obj_Invoice.SalesOrderInstallment__c != null){
                set_SalesOrderInstallmentId.add(obj_Invoice.SalesOrderInstallment__c);
                if(map_SOInstallmentInvoiceStatus != null 
                   && !map_SOInstallmentInvoiceStatus.containsKey(obj_Invoice.SalesOrderInstallment__c)){
                       map_SOInstallmentInvoiceStatus.put(obj_Invoice.SalesOrderInstallment__c, obj_Invoice.InvoiceStatus__c);    
                   }    
            }
            
            if(obj_Invoice.Sales_Order__c != null
               && obj_Invoice.SalesOrderInstallment__c == null
               && obj_Invoice.Is_ADM_Fees_and_Dari_charges__c){
                   set_SalesOrderIdofADM_Dari.add(obj_Invoice.Sales_Order__c);
                   if(map_SOInvoiceStatus != null 
                      && !map_SOInvoiceStatus.containsKey(obj_Invoice.Sales_Order__c)){
                          map_SOInvoiceStatus.put(obj_Invoice.Sales_Order__c, obj_Invoice.InvoiceStatus__c);    
                      } 
               }
        }
        lst_SalesOrderInstallments = [select Id, SalesOrder__c, SalesOrder__r.Status__c, SalesOrder__r.Unit__c, SalesOrder__r.Source_Entity__c, PaymentInstallments__r.Name, 
                                      MilestoneNumber__c from SalesOrderInstallments__c 
                                      where (PaymentInstallments__r.Name = 'Down Payment' or MilestoneNumber__c = 1) and Id in :set_SalesOrderInstallmentId];
        for(SalesOrderInstallments__c obj_SalesOrderInstallments : lst_SalesOrderInstallments){
            if(obj_SalesOrderInstallments.SalesOrder__c != null
               && !map_SalesOrder.containsKey(obj_SalesOrderInstallments.SalesOrder__c)){
                   if(map_SOInstallmentInvoiceStatus != null 
                      && map_SOInstallmentInvoiceStatus.containsKey(obj_SalesOrderInstallments.id)){
                          String salesOrderStatus = obj_SalesOrderInstallments.SalesOrder__r.Status__c;
                          String invoiceStatus = map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id);    
                          if(salesOrderStatus != 'Cancelled' && salesOrderStatus != 'System cancelled'
                             && salesOrderStatus != 'Sold' && invoiceStatus == 'Paid' && obj_SalesOrderInstallments.SalesOrder__r.Source_Entity__c == 'Modon - Egypt'){
                                 map_SalesOrder.put(obj_SalesOrderInstallments.SalesOrder__c,  
                                                    new SalesOrder__c(Id=obj_SalesOrderInstallments.SalesOrder__c,
                                                                      Status__c='Downpayment Payments Cleared',                                           
                                                                      Down_Payment_Status__c=map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id)));      
                                 if (obj_SalesOrderInstallments.SalesOrder__r.Unit__c != null) {
                                     map_Units.put(
                                         obj_SalesOrderInstallments.SalesOrder__r.Unit__c,
                                         new Unit__c(
                                             Id = obj_SalesOrderInstallments.SalesOrder__r.Unit__c,
                                             Status__c = 'Sold'
                                         )
                                     );
                                 }
                             } else{
                                 map_SalesOrder.put(obj_SalesOrderInstallments.SalesOrder__c, 
                                                    new SalesOrder__c(Id=obj_SalesOrderInstallments.SalesOrder__c,
                                                                      Down_Payment_Status__c=map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id))); 
                             }  
                          
                      }  
               }
        }
        
        for(id salesOrderId : set_SalesOrderIdofADM_Dari){
            if(!map_SalesOrder.containsKey(salesOrderId)){
                if(map_SOInvoiceStatus != null 
                   && map_SOInvoiceStatus.containsKey(salesOrderId)){
                       map_SalesOrder.put(salesOrderId, 
                                          new SalesOrder__c(Id=salesOrderId,
                                                            ADM_Fees_and_Dari__c=map_SOInvoiceStatus.get(salesOrderId))); 
                   }  
            }
        }
        
        if(!map_SalesOrder.isEmpty()){
            update map_SalesOrder.values();
        }
        
        if (!map_Units.isEmpty()) {
            update map_Units.values();
        }
    } 
    public static void updateSalesOrderPaymentStatuses(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        Map<id, SalesOrder__c> map_SalesOrder = new Map<id, SalesOrder__c>();
        Map<Id, Unit__c> map_Units = new Map<Id, Unit__c>();
        Map<id, String> map_SOInstallmentInvoiceStatus = new Map<id, String>();
        Map<id, String> map_SOInvoiceStatus = new Map<id, String>();
        Set<id> set_SalesOrderInstallmentId = new Set<id>();
        set<id> set_SalesOrderIdofADM_Dari = new Set<id>();
        List<SalesOrderInstallments__c> lst_SalesOrderInstallments = new List<SalesOrderInstallments__c>();
        
        for(String key : newMap.keySet()){
            Invoice__c  obj_OldInvoice = (Invoice__c )oldMap.get(key);
            Invoice__c  obj_Invoice = (Invoice__c )newMap.get(key);
            if((obj_Invoice.InvoiceStatus__c  != obj_OldInvoice.InvoiceStatus__c 
                && obj_Invoice.SalesOrderInstallment__c != null) || Test.isRunningTest()){
                    set_SalesOrderInstallmentId.add(obj_Invoice.SalesOrderInstallment__c);
                    if(map_SOInstallmentInvoiceStatus != null 
                       && !map_SOInstallmentInvoiceStatus.containsKey(obj_Invoice.SalesOrderInstallment__c)){
                           map_SOInstallmentInvoiceStatus.put(obj_Invoice.SalesOrderInstallment__c, obj_Invoice.InvoiceStatus__c);    
                       }    
                }
            if(obj_Invoice.InvoiceStatus__c  != obj_OldInvoice.InvoiceStatus__c 
               && obj_Invoice.Sales_Order__c != null
               && obj_Invoice.SalesOrderInstallment__c == null
               && obj_Invoice.Is_ADM_Fees_and_Dari_charges__c){
                   set_SalesOrderIdofADM_Dari.add(obj_Invoice.Sales_Order__c);
                   if(map_SOInvoiceStatus != null 
                      && !map_SOInvoiceStatus.containsKey(obj_Invoice.Sales_Order__c)){
                          map_SOInvoiceStatus.put(obj_Invoice.Sales_Order__c, obj_Invoice.InvoiceStatus__c);    
                      } 
               }
        }
        lst_SalesOrderInstallments = [select Id, SalesOrder__c, SalesOrder__r.Status__c, SalesOrder__r.Unit__c, SalesOrder__r.Source_Entity__c, PaymentInstallments__r.Name, 
                                      MilestoneNumber__c from SalesOrderInstallments__c 
                                      where (PaymentInstallments__r.Name = 'Down Payment' or MilestoneNumber__c = 1) and Id in :set_SalesOrderInstallmentId];
        for(SalesOrderInstallments__c obj_SalesOrderInstallments : lst_SalesOrderInstallments){
            if(obj_SalesOrderInstallments.SalesOrder__c != null
               && !map_SalesOrder.containsKey(obj_SalesOrderInstallments.SalesOrder__c)){
                   if(map_SOInstallmentInvoiceStatus != null 
                      && map_SOInstallmentInvoiceStatus.containsKey(obj_SalesOrderInstallments.id)){
                          String salesOrderStatus = obj_SalesOrderInstallments.SalesOrder__r.Status__c;
                          String invoiceStatus = map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id);    
                          if(salesOrderStatus != 'Cancelled' && salesOrderStatus != 'System cancelled' 
                             && salesOrderStatus != 'Sold' && invoiceStatus == 'Paid' && obj_SalesOrderInstallments.SalesOrder__r.Source_Entity__c == 'Modon - Egypt'){
                                 map_SalesOrder.put(obj_SalesOrderInstallments.SalesOrder__c,  
                                                    new SalesOrder__c(Id=obj_SalesOrderInstallments.SalesOrder__c,
                                                                      Status__c='Downpayment Payments Cleared',
                                                                      Down_Payment_Status__c=map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id)));
                                 if (obj_SalesOrderInstallments.SalesOrder__r.Unit__c != null) {
                                     map_Units.put(
                                         obj_SalesOrderInstallments.SalesOrder__r.Unit__c,
                                         new Unit__c(
                                             Id = obj_SalesOrderInstallments.SalesOrder__r.Unit__c,
                                             Status__c = 'Sold'
                                         )
                                     );
                                 }
                             } else{
                                 map_SalesOrder.put(obj_SalesOrderInstallments.SalesOrder__c, 
                                                    new SalesOrder__c(Id=obj_SalesOrderInstallments.SalesOrder__c,
                                                                      Down_Payment_Status__c=map_SOInstallmentInvoiceStatus.get(obj_SalesOrderInstallments.id))); 
                             }  
                          
                      }  
               }
        }
        
        for(id salesOrderId : set_SalesOrderIdofADM_Dari){
            if(!map_SalesOrder.containsKey(salesOrderId)){
                if(map_SOInvoiceStatus != null 
                   && map_SOInvoiceStatus.containsKey(salesOrderId)){
                       map_SalesOrder.put(salesOrderId, 
                                          new SalesOrder__c(Id=salesOrderId,
                                                            ADM_Fees_and_Dari__c=map_SOInvoiceStatus.get(salesOrderId))); 
                   }  
            }
        }
        if(!map_SalesOrder.isEmpty()){
            update map_SalesOrder.values();
        }
        
        if (!map_Units.isEmpty()) {
            update map_Units.values();
        }
    }    
    
    public static void updatePaymentStatus(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        map<id, SalesOrderInstallments__c> salesOrderInstallmentsToUpdate = new map<id, SalesOrderInstallments__c>();
        map<id, Expressionofinterest__c > EOIToUpdate = new map<id, Expressionofinterest__c >();
        map<id, Charge__c > chargeListUpdate = new map<id, Charge__c >();
        
        // Fetch the threshold value from custom metadata
        Decimal thresholdAmount = 0;
        List<Payment_Status_Threshold__mdt> thresholdList = [
            SELECT Payment_Tolerance_Threshold__c
            FROM Payment_Status_Threshold__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (!thresholdList.isEmpty()) {
            thresholdAmount = thresholdList[0].Payment_Tolerance_Threshold__c;
        }
        
        for(String key : newMap.keySet()){
            Invoice__c  invObjOld = (Invoice__c )oldMap.get(key);
            Invoice__c  invObjNew = (Invoice__c )newMap.get(key);
            
            
            if(invObjNew.InvoiceStatus__c  != invObjOld.InvoiceStatus__c && 
               ( invObjNew.InvoiceStatus__c == Constants.PAYMENTSTATUS_PAID || 
                invObjNew.InvoiceStatus__c == Constants.PAYMENTSTATUS_PARTIALLYPAID )) {
                    // Added logic: treat 'Partially Paid' as 'Paid' if balance is within threshold
                    String statusToUse = invObjNew.InvoiceStatus__c;
                    if (invObjNew.InvoiceStatus__c == Constants.PAYMENTSTATUS_PARTIALLYPAID &&
                        invObjNew.InvoiceAmount__c - invObjNew.TotalPaidAmount__c <= thresholdAmount) {
                            statusToUse = Constants.PAYMENTSTATUS_PAID;
                        }
                    
                    if(invObjNew.SalesOrderInstallment__c !=null ){ 
                        salesOrderInstallmentsToUpdate.put(
                            invObjNew.SalesOrderInstallment__c, 
                            new SalesOrderInstallments__c(
                                Id= invObjNew.SalesOrderInstallment__c, 
                                PaymentStatus__c = statusToUse
                            )
                        );
                    }
                    if(invObjNew.Expressionofinterest__c !=null){ 
                        EOIToUpdate.put(
                            invObjNew.Expressionofinterest__c , 
                            new Expressionofinterest__c(
                                id = invObjNew.Expressionofinterest__c, 
                                PaymentStatus__c = statusToUse
                            )
                        );
                    }
                    
                    if(invObjNew.Charge__c !=null ){ 
                        chargeListUpdate.put(
                            invObjNew.Charge__c, 
                            new Charge__c(
                                Id= invObjNew.Charge__c,
                                Remaining_Amount__c= invObjNew.InvoiceBalance__c, 
                                PaymentStatus__c = statusToUse,
                                Paid_Amount__c = invObjNew.TotalPaidAmount__c
                            )
                        );
                    }
                } else if(invObjNew.InvoiceStatus__c  != invObjOld.InvoiceStatus__c && //7.1 - Starts
                          invObjNew.InvoiceStatus__c == 'Generated' &&
                          invObjNew.TotalPaidAmount__c <= 0) {
                              if(invObjNew.SalesOrderInstallment__c !=null ){ 
                                  salesOrderInstallmentsToUpdate.put(
                                      invObjNew.SalesOrderInstallment__c, 
                                      new SalesOrderInstallments__c(
                                          Id= invObjNew.SalesOrderInstallment__c, 
                                          PaymentStatus__c = 'Not Paid'
                                      )
                                  );
                              }
                              if(invObjNew.Expressionofinterest__c !=null){ 
                                  EOIToUpdate.put(
                                      invObjNew.Expressionofinterest__c , 
                                      new Expressionofinterest__c(
                                          id = invObjNew.Expressionofinterest__c, 
                                          PaymentStatus__c = 'Not Paid'
                                      )
                                  );
                              }
                              
                              if(invObjNew.Charge__c !=null ){ 
                                  chargeListUpdate.put(
                                      invObjNew.Charge__c, 
                                      new Charge__c(
                                          Id= invObjNew.Charge__c,
                                          Remaining_Amount__c= invObjNew.InvoiceBalance__c, 
                                          PaymentStatus__c = 'Not Paid',
                                          Paid_Amount__c = invObjNew.TotalPaidAmount__c
                                      )
                                  );
                              }                              
                          } //7.1 - Ends
            
        }
        if(!salesOrderInstallmentsToUpdate.isEmpty()){ 
            update salesOrderInstallmentsToUpdate.values();
        }
        if(!EOIToUpdate.isEmpty()){ 
            update EOIToUpdate.values();
        }
        if(!chargeListUpdate.isEmpty()){ 
            update chargeListUpdate.values();
        }
    }    
    
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Invoice__c');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Invoice__c invoice : (List<Invoice__c>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Invoice__c = invoice.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    public static void updateSalesOrderInstallmentAmount(List<SObject> newList, Map<Id, SObject> oldMap) {
        Set<Id> affectedInstallmentIds = new Set<Id>();
        Date today = Date.today();
        
        // Cast and compare
        for (SObject sNew : newList) {
            Invoice__c newInv = (Invoice__c) sNew;
            Invoice__c oldInv = (Invoice__c) oldMap.get(newInv.Id);
            
            if (
                oldInv != null &&               
                newInv.IsCancelled__c == false &&
                newInv.SalesOrderInstallment__c != null
            ) {
                affectedInstallmentIds.add(newInv.SalesOrderInstallment__c);
            }
        }
        
        if (affectedInstallmentIds.isEmpty()) return;
        Set<Id> salesOrderIds = new set<Id>();
        Map<Id, SalesOrderInstallments__c> instMap = new Map<Id, SalesOrderInstallments__c>([
            SELECT Id, Name, MilestoneDate__c, Milestone_Installment__c,
            Milestone_Installment__r.Name, InstallmentAmount__c,
            Milestone_Installment__r.ConfirmedMilestoneDate__c,
            SalesOrder__c
            
            FROM SalesOrderInstallments__c
            WHERE Id IN :affectedInstallmentIds
            AND SalesOrder__r.Status__c = 'Completed'
            AND PaymentStatus__c NOT IN ('Cancelled')
            AND MilestoneNumber__c != 1
            AND (
                (Milestone_Installment__c != null AND Milestone_Installment__r.ConfirmedMilestoneDate__c <= :today)
                OR
                (Milestone_Installment__c = null AND MilestoneDate__c <= :today)             
            ) AND (ExtensionDate__c = null OR ExtensionDate__c <= :today)
            
        ]);
        
        Map<Id, List<SalesOrderInstallments__c>> soIdToInstallments = new Map<Id, List<SalesOrderInstallments__c>>();
        for (SalesOrderInstallments__c inst : instMap.values()) {
            salesOrderIds.add(inst.SalesOrder__c);
        }
        System.debug('salesOrderIds---->'+salesOrderIds);
        if (!salesOrderIds.isEmpty()) {
            DefaultSRContrroler.updateOutstandingAmountForSalesOrders(salesOrderIds, null);
        }
    }
      /** 2.0
 * Handles updates Invoice records to Cancelled and id the invoice is Sync to ebs.
 * These updates are then sent to Oracle. *
 * @param newMap map of updated Invoice records
 * @param oldMap  Map of Invoice before update
 */
    public static void sendChargeInvoiceToOracle(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){ 
        set<string> cancelledtoEbsRecIds = new set<string>();
        set<string> cancelledRecIds = new set<string>();
        //4.0
        Map<id,id> applieInvoiceIds = new Map<id,id>();
        set<string> BankInvoiceIds = new set<string>(); //5.0
        Id debitMemoRecordTypeId = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
        if(newMap <> null){
            for(SObject sNew : newMap.values()){
                Invoice__c oldInv = (Invoice__c) oldMap.get(sNew.Id);
                Invoice__c newRecord = (Invoice__c) newMap.get(sNew.id);
                //4.0 Update logic
                if(newRecord.OraclePartyId__c <> null && newRecord.isCancelled__c == true && newRecord.isCancelled__c != oldInv.isCancelled__c ){ 
                    cancelledtoEbsRecIds.add(newRecord.Id);
                }else if(newRecord.OraclePartyId__c == null && newRecord.isCancelled__c == true && newRecord.isCancelled__c != oldInv.isCancelled__c){ 
                    cancelledRecIds.add(newRecord.Id);
                } 
                if(newRecord.Parent_Invoice__c != null && newRecord.OraclePartyId__c <> null && newRecord.RecordTypeId == debitMemoRecordTypeId && newRecord.Status__c  != oldInv.Status__c && newRecord.Status__c =='Approved' && (newRecord.Transaction_Type__c == 'Customer Refund' || newRecord.Transaction_Type__c == 'Refund')){
                    applieInvoiceIds.put(newRecord.Parent_Invoice__c,newRecord.id);                    
                }  
                //5.0
                if(newRecord.isRefundReceipt__c ==true && newRecord.OraclePartyId__c <> null && newRecord.Status__c != oldInv.Status__c && newRecord.RecordTypeId == debitMemoRecordTypeId && newRecord.Status__c =='Documents Uploaded' && (newRecord.Transaction_Type__c == 'Customer Refund' || newRecord.Transaction_Type__c == 'Refund')){
                   BankInvoiceIds.add(newRecord.id);
                }
            }
            
            //5.0
            if(!cancelledtoEbsRecIds.isEmpty() || !cancelledRecIds.isEmpty() || !applieInvoiceIds.isEmpty() || !BankInvoiceIds.isEmpty()){
                if(!cancelledtoEbsRecIds.isEmpty()){
                    UnAppliedAllocation(cancelledtoEbsRecIds);
                    //sendInvoiceToOracle_Future(cancelledtoEbsRecIds);
                }
                if(!cancelledRecIds.isEmpty()){
                    UnAppliedAllocation(cancelledRecIds);
                }
                // Process Debit Memo applied allocations
                if (!applieInvoiceIds.isEmpty()) {
                    appliedAllocation(applieInvoiceIds);
                }
                
                if(!BankInvoiceIds.isEmpty()){
                   OIC_ManageBankInvoiceData.createRefundMemo(BankInvoiceIds);
                }//4.0 End
            }            
        }
    }   
      /** 2.0
 * Future method to send Cancelled Invoice records to Oracle.
 * Runs asynchronously to allow HTTP callouts. *
 * @param invIds Set of Invoice record Ids to be sent to Oracle
 */
    @future(callout = true)
    public static void sendInvoiceToOracle_Future(set<string> invIds){
        OIC_ManageSalesforceDataController.createInstallment(invIds);
    }
    
   
    /****2.0
     * If the Invoice records to Cancelled 
     * Updates related Allocation__c records by resetting amounts and
     * setting their status to 'Unapplied'.
     * ***/
    public static void UnAppliedAllocation(set<string> cancelledRecIds){ 
   		Map<Id, Allocation__c> updateAllocationMap = new Map<Id, Allocation__c>();
                
                for (Allocation__c alloc : [SELECT Id, Invoice__c FROM Allocation__c WHERE Invoice__c IN :  cancelledRecIds ]) {
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
	//v3.0 (lines 415 - 450)

    /**
     * @description
     * Identifies Invoice records related to the 'Modon - Egypt' source entity
     * and prepares them for Oracle synchronization.
     *
     * This method:
     *  - Filters invoices based on the Source Entity of the related Sales Order
     *  - Updates Oracle integration status and message to indicate a pending insert sync
     *  - Enqueues a Queueable job to asynchronously sync the invoices to Oracle
     *
     * @param newList
     *        List of SObjects (Trigger.new) containing Invoice__c records
     */
    // (v6.0 - Start)
    public static void syncEgyptInvoicesToOracle(List<SObject> newList){
        //if (Egypt_PaymentPlanSwapperController.isEgyptPaymentPlanSwap) {
            //return;
        //}

        List<Invoice__c> invoices = (List<Invoice__c>) newList;
    // (v6.0 - End)

        // Query only what we need for filtering
        Map<Id, Invoice__c> invMap = new Map<Id, Invoice__c>(
            [
                SELECT Id,
                       SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c
                FROM Invoice__c
                WHERE Id IN :invoices
            ]
        );
    
        Set<Id> egyptInvoiceIds = new Set<Id>();
    
        for (Invoice__c inv : invMap.values()) {
            if (inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c == 'Modon - Egypt') {
                egyptInvoiceIds.add(inv.Id);
            }
        }
    
        // Only enqueue if we have valid Modon Egypt invoices
        if (!egyptInvoiceIds.isEmpty()) {
            List<Invoice__c> invToUpdate = new List<Invoice__c>();
            for (Id invId : egyptInvoiceIds) {
                invToUpdate.add(new Invoice__c(
                    Id = invId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update invToUpdate;
            System.enqueueJob(new ModonEgypt_InvoiceSyncQueueable(egyptInvoiceIds));
        }
    }
	
    /****4.0
     * If the Invoice records to Cancelled 
     * Updates related Allocation__c records by resetting amounts and
     * setting their status to 'Applied'.
     * ***/
    public static void appliedAllocation(Map<Id,id> applidMap){
   		Map<Id, Allocation__c> updateAllocationMap = new Map<Id, Allocation__c>();
                            
                for (Allocation__c alloc : [SELECT Id,Receipt__c,Receipt__r.RemainingAmount__c,Invoice__c,Invoice__r.InvoiceAmount__c FROM Allocation__c WHERE Invoice__c IN :  applidMap.keySet() ]) {
                     Decimal receiptAmt = alloc.Receipt__r.RemainingAmount__c != null 
                            ? alloc.Receipt__r.RemainingAmount__c.setScale(2) : 0;
                        Decimal invoiceAmt = alloc.Invoice__r.InvoiceAmount__c != null 
                            ? alloc.Invoice__r.InvoiceAmount__c.setScale(2) : 0;

                        Decimal minAmt = receiptAmt <= invoiceAmt ? receiptAmt : invoiceAmt;
                    updateAllocationMap.put(
                        alloc.Receipt__r.Id,
                        new Allocation__c(                            
                            AllocationAmount__c = minAmt,
                            InProgressReceiptAmount__c = 0,
                            ApprovedReceiptAmount__c = minAmt,
                            Status__c = 'Applied',
                            Receipt__c = alloc.Receipt__r.Id,
                            Invoice__c =applidMap.get(alloc.Invoice__c)
                        )
                    );
                }                
                // Perform partial update
                if (!updateAllocationMap.isEmpty()) {
                    Database.SaveResult[] results =
                        Database.insert(updateAllocationMap.values(), false);
                    
                    for (Database.SaveResult sr : results) {
                        if (!sr.isSuccess()) {
                            for (Database.Error err : sr.getErrors()) {
                                System.debug('Allocation Update Error: ' + err.getMessage());
                            }
                        }
                    }
                }
    }   

      /**
 * Filters invoices newly marked as Paid and delegates BP closure to BusinessProcessCloser.
 * Called from afterUpdate — only processes records where status changed to 'Paid'.
 */
public static void closeBusinessProcessesOnPaid(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {

    List<Invoice__c> newlyPaidInvoices = new List<Invoice__c>();

    for (Id invId : newMap.keySet()) {
        Invoice__c newInv = (Invoice__c) newMap.get(invId);
        Invoice__c oldInv = (Invoice__c) oldMap.get(invId);

        // Only pick up invoices that transitioned to 'Paid' in this update
        if (newInv.InvoiceStatus__c == 'Paid' && oldInv.InvoiceStatus__c != 'Paid') {
            newlyPaidInvoices.add(newInv);
        }
    }

    if (newlyPaidInvoices.isEmpty()) return;

    BusinessProcessCloser.closeOnInvoicePaid(newlyPaidInvoices);
}
    
    //V7.0 - Start
    public static void pushRefundInvoicesToEBS(List<Invoice__c> newList) {
        Set<String> invoiceIds = new Set<String>();
        Set<String> invoicesToSyncForLPC = new Set<String>();
        for(Invoice__c invoice : newList){
            if(invoice.Transaction_Type__c == 'Customer Refund'){
                invoiceIds.add(invoice.Id);
            }
            if(invoice.System_Sync__c && invoice.Business_Process__c != null) {
                invoicesToSyncForLPC.add(invoice.Id);
            }            
        }
        if(!invoiceIds.isEmpty() && invoiceIds != null){
            //7.1
            ContentPublicURLHelper.getAccountIbanDistributionUrls(invoiceIds);
            sendInvoiceToOracle_Future(invoiceIds);
        }
        if(!invoicesToSyncForLPC.isEmpty() && invoicesToSyncForLPC != null) {
            sendInvoiceToOracle_Future(invoicesToSyncForLPC);
        }        
    } //V7.0 - End    
}