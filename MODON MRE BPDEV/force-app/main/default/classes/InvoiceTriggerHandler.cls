/**********************************************************************************************************************
* Name               : InvoiceTriggerHandler                                                        
* Description        : This class is used to handle all the Invoice trigger instances
* Usage              : Called from InvoiceTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft
* 2.0			Gautam Mishra (Horizontal)		 23 Jan 2026		Added insert Invoice in Oracle method in after insert (syncEgyptInvoicesToOracle)
* 3.0           Manoj                            30 Jan 2026     invoice Cancelled to Ebs 
* 4.0           Manoj                            29 Apr 2026     Add By psss for Cancelled process
* 5.0			Manoj							15 May 2026		Added method sendChargeInvoiceToOracle
* 4.0 			Modon IT						27 Jul 2026		Call out Invoices after insert
******************************************************************************************************************/
public without sharing class InvoiceTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
       
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
       
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    	//v2.0 line (31)
        //InvoiceTriggerHelper.syncEgyptInvoicesToOracle(newList);
        InvoiceTriggerHelper.createDocumentRecords(newList);        
        InvoiceTriggerHelper.updateSalesOrderInitialPaymentStatuses(newList);
        InvoiceTriggerHelper.pushRefundInvoicesToEBS(newList);
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        if(!TriggerControl.BypassCancelledTrigger){ // 4.0
            InvoiceTriggerHelper.updatePaymentStatus(newMap,oldMap);
            InvoiceTriggerHelper.updateSalesOrderPaymentStatuses(newMap, oldMap);
            InvoiceTriggerHelper.updateSalesOrderInstallmentAmount(newlist, oldMap);  
             InvoiceTriggerHelper.sendChargeInvoiceToOracle(newMap,oldMap); //5.0
        }else if(TriggerControl.BypassCancelledTrigger){ // 4.0 
            InvoiceTriggerHelper.sendChargeInvoiceToOracle(newMap,oldMap); // 3.0
        }
        //InvoiceTriggerHelper.closeBusinessProcessesOnPaid(newMap, oldMap); // Closes linked Business Processes when Invoice status transitions to 'Paid'
        
    }
}