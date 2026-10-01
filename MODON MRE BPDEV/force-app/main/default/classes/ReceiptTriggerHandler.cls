/**********************************************************************************************************************
* Name               : ReceiptTriggerHandler                                                        
* Description        : This class is used to handle all the Receipt trigger instances
* Usage              : Called from ReceiptTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         12 Jan 2024     Initial Draft       
* 2.0           Shahil Sinha (Horizontal)        22 Dec 2025     Updated the code to call other methods under after insert and update operations
* 2.1           Shahil Sinha (Horizontal)        16 Jan 2026     Calling checkReceiptMethodAndRemittanceBankAccountNumber under beforeInsert and beforeUpdate
*                                                                to check if the payment mode (Bank Name + Mode of Payment) is supported or not.
*                                                                This change is related to MODON EGYPT only.
* 3.0			Gautam Mishra (Horizontal)		23 Jan 2026		Added insert and update Receipt in Oracle method in after insert and after update   
* 2.2           Milin Kapatel (Horizontal)      06 Feb 2026     Calling new method rollUpChequeTotalAmountToSO from after insert and after update to roll up sum of all related receipts's Total Amount which has mode of payment as 'Cheque' to Sales Order.
* 4.0           manoj                            20 Jan 2026     Add to call the helper calss for statusupdate and unIdentifiedReceipts, Remove the manageCancelledReceipts  
* 5.0           Suresh                           09 Mar 2026     Added the changes for Receipt Acknowledgement
* 6.0           Dinesh                           07 Apr 2026     Handle Transaction Number for CreditNote
* 7.0			Manoj							 10 May 2026	 Add Excess Amount refound
* 9.0			Mirza Baig	                	17 July 2026	Trigger the duplication validation based on the receipt number
* 10.0			Modon IT						27 Jul 2026		Bank Details Validating before update Customer Refund
* 11.0			Prateek Bansal					23 Sep 2026		Stop calling the unused payment gateway URL on non-Egypt receipts.
******************************************************************************************************************/
public without sharing class ReceiptTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
     public override void beforeInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
        Map<String, Object> filteredReceipts = Modon_Egypt_ReceiptFilterHelper.filterBeforeInsert(newList);
        List<SObject> modonEgyptReceipts = (List<SObject>) filteredReceipts.get('ModonEgyptReceipts');
        List<SObject> otherReceipts = (List<SObject>) filteredReceipts.get('OtherReceipts');
        
        // Process Modon - Egypt receipts
        if (!modonEgyptReceipts.isEmpty()) {
            //v2.1 (line - 24) check if the payment mode (Bank Name + Mode of Payment + currencyIsoCode) is supported or not
            ReceiptTriggerHelper.checkReceiptMethodAndRemittanceBankAccountNumber(modonEgyptReceipts);
            ReceiptTriggerHelper.preventModonEgyptReceiptNumberDuplication(modonEgyptReceipts);//v9.0
        }
        
        // Process other receipts
        if (!otherReceipts.isEmpty()) {
            ReceiptTriggerHelper.addEscrowAccount(otherReceipts, null, null);
            ReceiptTriggerHelper.populateAmountText(otherReceipts);
            ReceiptTriggerHelper.populateTransactionDate(otherReceipts);
            SalesOrderStatusAutomationHelper.updatePDCinstrumentReceivedInfo(newList,null);
        }
    }
     
    //*** Before Update Action ***//
     public override void beforeUpdateMethod(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        Map<String, Object> filteredReceipts = Modon_Egypt_ReceiptFilterHelper.filterBeforeUpdate(newList, oldList);
        List<SObject> modonEgyptReceipts = (List<SObject>) filteredReceipts.get('ModonEgyptReceipts');
        List<SObject> otherReceipts = (List<SObject>) filteredReceipts.get('OtherReceipts');
        
          // Process Modon - Egypt receipts
        if (!modonEgyptReceipts.isEmpty()) {
            //v2.1 (line - 45) check if the payment mode (Bank Name + Mode of Payment + currencyIsoCode) is supported or not
            ReceiptTriggerHelper.checkReceiptMethodAndRemittanceBankAccountNumber(modonEgyptReceipts);
        }
         
        // Process only non-Modon Egypt receipts
        if (!otherReceipts.isEmpty()) {
            ReceiptTriggerHelper.addEscrowAccount(otherReceipts, newMap, oldMap);
            ReceiptTriggerHelper.populateAmountText(otherReceipts);
            ReceiptTriggerHelper.populateTransactionDate(otherReceipts);
			SalesOrderStatusAutomationHelper.updatePDCinstrumentReceivedInfo(newList,oldMap);
            ReceiptTriggerHelper.updatingEbsSyncReceipt(newMap, oldMap,true,false); // 4.0 Ebs sync
            // V10.0 Validate Account bank details when Customer Refund Amount is changed
            ReceiptTriggerHelper.validateAccountBankDetailsOnRefund(otherReceipts, oldMap);//V10.0
        }
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

    }

    //*** After Delete Action ***//
    public override void beforeDeleteMethod(List<SObject> oldList, Map<ID, SObject> oldMap) {
        Map<String, Object> filteredReceipts = Modon_Egypt_ReceiptFilterHelper.filterBeforeDelete(oldList);
        List<SObject> otherReceipts = (List<SObject>) filteredReceipts.get('OtherReceipts');
        
        // Process only non-Modon Egypt receipts
        if (!otherReceipts.isEmpty()) {
            ReceiptTriggerHelper.handleBeforeDelete(otherReceipts);
        }
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
        Map<String, Object> filteredReceipts = Modon_Egypt_ReceiptFilterHelper.filterAfterInsert(newList, newMap);
        List<SObject> otherReceipts = (List<SObject>) filteredReceipts.get('OtherReceipts');
        Map<ID, SObject> otherReceiptsMap = (Map<ID, SObject>) filteredReceipts.get('OtherReceiptsMap');
        List<Sobject> modonEgyptreceipts = (List<Sobject>) filteredReceipts.get('ModonEgyptReceipts');
        Map<Id, SObject>  modonEgyptreceiptsMap = (Map<ID, SObject>) filteredReceipts.get('ModonEgyptReceiptsMap');
        if(!modonEgyptreceipts.isEmpty()){
            ReceiptTriggerHelper.createModonEgyptDocumentRecords(modonEgyptreceipts);
            //v2.0 (line 82 - 90) process only modon - egypt receipts
            ReceiptTriggerHelper.createModonEgyptAllocationRecord(modonEgyptreceiptsMap);
            ReceiptTriggerHelper.updateSalesOrderDetails(modonEgyptreceiptsMap); 
            ReceiptTriggerHelper.generatePaymentGatewayURL(modonEgyptreceiptsMap);
            ReceiptTriggerHelper.calculateTotalPaid(modonEgyptreceipts,null);
            //v3.0
            ReceiptTriggerHelper.passEgyptReceipts(modonEgyptReceipts);
            //SalesOrderStatusAutomationHelper.handlePDCStatusReceipt(modonEgyptreceipts,null); 
            //v2.2 - roll up sum of all related receipts's Total Amount which has mode of payment as 'Cheque' to Sales Order on Updating and Creation.
            ReceiptTriggerHelper.rollUpChequeTotalAmountToSO(modonEgyptreceiptsMap, null);
        }
        // Process only non-Modon Egypt receipts
        if (!otherReceipts.isEmpty()) {
            ReceiptTriggerHelper.updateSalesOrderDetails(otherReceiptsMap); 
            ReceiptTriggerHelper.createAllocationRecord(otherReceiptsMap);
            // 11.0 - gateway integration is not in use: 10 URLs ever, none since May 2026. On an
            // Online receipt with no escrow account it threw before the callout, burning a future
            // slot and writing an error log each time. Egypt (line 97) is untouched.
            //ReceiptTriggerHelper.generatePaymentGatewayURL(otherReceiptsMap);
            ReceiptTriggerHelper.createDocumentRecords(otherReceipts);
            ReceiptTriggerHelper.calculateTotalPaid(otherReceipts,null);
            //ReceiptTriggerHelper.sendReceiptsToOracle(otherReceiptsMap, null);
			SalesOrderStatusAutomationHelper.handlePDCStatusReceipt(otherReceipts,null); 
            ADMWaiverController.updateCreditNoteTransactionNumber(otherReceipts,null); /** 6.0 Updated Transaction Number for CR Note **/
            //ReceiptTriggerHelper.updateCreditNoteTransactionNumber(otherReceipts,null); 
            //OIC_ManageEbsDataController.createUnidentifiedReceipt		    	           
        }
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        Map<String, Object> filteredReceipts = Modon_Egypt_ReceiptFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        List<SObject> otherReceipts = (List<SObject>) filteredReceipts.get('OtherReceipts');
        Map<ID, SObject> otherReceiptsMap = (Map<ID, SObject>) filteredReceipts.get('OtherReceiptsMap');
        Map<ID, SObject> otherOldReceiptsMap = (Map<ID, SObject>) filteredReceipts.get('OtherOldReceiptsMap');
        List<Sobject> modonEgyptreceipts = (List<Sobject>) filteredReceipts.get('ModonEgyptReceipts');
        Map<Id, SObject>  modonEgyptOldReceiptsMap = (Map<ID, SObject>) filteredReceipts.get('ModonEgyptOldReceiptsMap');
        Map<Id, SObject>  modonEgyptNewReceiptsMap = (Map<ID, SObject>) filteredReceipts.get('ModonEgyptNewReceiptsMap');

        if(!modonEgyptreceipts.isEmpty()){
            //v3.0
            ReceiptTriggerHelper.updateEgyptReceiptsToOracle(modonEgyptreceipts, ModonEgyptOldReceiptsMap);
            //v2.0 (line 115 - 123) process only modon - egypt receipts
           	ReceiptTriggerHelper.manageAllocationAmount(modonEgyptNewReceiptsMap, modonEgyptOldReceiptsMap);
            ReceiptTriggerHelper.updateSalesOrderDetails(modonEgyptNewReceiptsMap);
            //ReceiptTriggerHelper.manageCancelledReceipts(modonEgyptNewReceiptsMap, modonEgyptOldReceiptsMap);
            ReceiptTriggerHelper.validateReceiptStatusChange(modonEgyptNewReceiptsMap, modonEgyptOldReceiptsMap);
            ReceiptTriggerHelper.calculateTotalPaid(modonEgyptreceipts, modonEgyptOldReceiptsMap);
           // ReceiptTriggerHelper.sendReceiptsToOracle(modonEgyptNewReceiptsMap, modonEgyptOldReceiptsMap); 
           // ReceiptTriggerHelper.CreateDefaultSR((List<Receipt__c>)Trigger.new, (Map<Id, Receipt__c>)Trigger.oldMap);
           //v2.2 - roll up sum of all related receipts's Total Amount which has mode of payment as 'Cheque' to Sales Order on Updating and Creation.            
            ReceiptTriggerHelper.rollUpChequeTotalAmountToSO(modonEgyptNewReceiptsMap, modonEgyptOldReceiptsMap);
        }
        
        if (!otherReceipts.isEmpty() || Test.isRunningTest()) {
            ReceiptTriggerHelper.updateSalesOrderDetails(otherReceiptsMap);
            ReceiptTriggerHelper.manageAllocationAmount(otherReceiptsMap, otherOldReceiptsMap);
            //ReceiptTriggerHelper.manageCancelledReceipts(otherReceiptsMap, otherOldReceiptsMap); // 4.0 Removed
            ReceiptTriggerHelper.validateReceiptStatusChange(otherReceiptsMap, otherOldReceiptsMap);
            ReceiptTriggerHelper.calculateTotalPaid(otherReceipts,oldMap);
            ReceiptTriggerHelper.sendReceiptsToOracle(otherReceiptsMap, otherOldReceiptsMap); 
            ReceiptTriggerHelper.updatingEbsSyncReceipt(otherReceiptsMap, otherOldReceiptsMap,false,true); // 4.0 Ebs sync 
            //ReceiptTriggerHelper.sendPaymentStatusChangeNotification(otherReceiptsMap, otherOldReceiptsMap);
            ReceiptTriggerHelper.CreateDefaultSR((List<Receipt__c>)Trigger.new, (Map<Id, Receipt__c>)Trigger.oldMap);
		    SalesOrderStatusAutomationHelper.handlePDCStatusReceipt(otherReceipts,trigger.oldmap);  
       	    SalesOrderStatusAutomationHelper.updateMOPfromPayment(otherReceipts,oldmap);
			ReceiptTriggerHelper.sendUnIdentifiedReceiptUpdate(otherReceipts,oldmap); 
            ADMWaiverController.updateCreditNoteTransactionNumber(otherReceipts,otherOldReceiptsMap); /** 6.0 Updated Transaction Number for CR Note **/
            /*if(!System.isFuture() && !System.isBatch()){
                System.enqueueJob(new ChequesReceivedQueueable(otherReceipts, otherOldReceiptsMap));
           }*/
		   ReceiptTriggerHelper.processCustomerRefund(otherReceipts,otherOldReceiptsMap); // 7.0
        }
        

    }

    
}