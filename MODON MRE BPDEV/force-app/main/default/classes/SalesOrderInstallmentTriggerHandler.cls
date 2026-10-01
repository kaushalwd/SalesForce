/**********************************************************************************************************************
* Name               : SalesOrderInstallmentTriggerHandler                                                        
* Description        : This class is used to handle all the SalesOrderInstallment trigger instances
* Usage              : Called from SalesOrderInstallmentTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         17 Jan 2024     Initial Draft       
* 1.1 			Srikrishna.chaitanya.com		 27 Nov 2025	 Calc changes on SO
* 2.0           Shahil Sinha (Horizontal)        03 Feb 2026     Added call to updateEgyptAmountInWords for Modon Egypt SOIs to populate Sales Order amount in words fields after roll-up summaries are calculated
* 3.0           Milin Kapatel (Horizontal)       22 Apr 2026     Added call to updateMilestoneDescriptionArabic for Modon Egypt SOIs to populate Milestone Description in Arabic
******************************************************************************************************************/
public without sharing class SalesOrderInstallmentTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        //v3.0
        Map<String, Object> filteredSalesOrderInstallments = Modon_Egypt_SOIFilterHelper.filterBeforeInsert(newList, newMap);
        List<SalesOrderInstallments__c> modonEgyptSalesOrderInstallments = (List<SalesOrderInstallments__c>) filteredSalesOrderInstallments.get('ModonEgyptSalesOrderInstallments');

        if(!modonEgyptSalesOrderInstallments.isEmpty()) {
            SalesOrderInstallmentTriggerHelper.updateMilestoneDescriptionArabic(modonEgyptSalesOrderInstallments);
        }
    }

    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        //v3.0
        Map<String, Object> filteredSalesOrderInstallments = Modon_Egypt_SOIFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        List<SalesOrderInstallments__c> modonEgyptSalesOrderInstallments = (List<SalesOrderInstallments__c>) filteredSalesOrderInstallments.get('ModonEgyptSalesOrderInstallments');

        if(!modonEgyptSalesOrderInstallments.isEmpty()) {
            SalesOrderInstallmentTriggerHelper.updateMilestoneDescriptionArabic(modonEgyptSalesOrderInstallments);
        }
    }

    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        //new logic for calcultion on salesorder level 1.1
        Set<Id> changedInstallmentIds = new Set<Id>();
        for (SObject s : oldList) {changedInstallmentIds.add(((SalesOrderInstallments__c)s).Id);}

        if (!changedInstallmentIds.isEmpty()) {SalesOrderCollectionsServiceController.recalcFromInstallments(changedInstallmentIds);}
    }

    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        SalesOrderInstallmentTriggerHelper.createInvoice(newList);
        SalesOrderInstallmentTriggerHelper.updateSalesOrders(newMap,null);
        //new logic for calcultion on salesorder level 1.1
        Set<Id> changedInstallmentIds = new Set<Id>();
        for (SObject s : newList) {
            changedInstallmentIds.add(((SalesOrderInstallments__c)s).Id);
        }

        if (!changedInstallmentIds.isEmpty()) {
            SalesOrderCollectionsServiceController.recalcFromInstallments(changedInstallmentIds);
        }

        //v2.0
        Map<String, Object> filteredSalesOrderInstallments = Modon_Egypt_SOIFilterHelper.filterAfterInsert(newList, newMap);
        List<SalesOrderInstallments__c> modonEgyptSalesOrderInstallments = (List<SalesOrderInstallments__c>) filteredSalesOrderInstallments.get('ModonEgyptSalesOrderInstallments');
        if (!modonEgyptSalesOrderInstallments.isEmpty()) {
            system.debug('After Insert Called');
            SalesOrderInstallmentTriggerHelper.updateEgyptAmountInWords(modonEgyptSalesOrderInstallments);
        }
        //end v2.0
    }

    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        //EOITriggerHelper.manageInvoiceAmount(newMap, oldMap);
        Set<Id> salesOrderIdsToUpdate = new Set<Id>();
		set<Id> SoIdsToUpdate = new Set<Id>();
        
        SalesOrderInstallmentTriggerHelper.validateInvoicePaymentReminderChange(newMap, oldMap);
        SalesOrderInstallmentTriggerHelper.updateSalesOrders(newMap,oldMap);
        List<SObject> toProcess = new List<SObject>();

    for (SObject s : newList) {SalesOrderInstallments__c newSOI = (SalesOrderInstallments__c)s; SalesOrderInstallments__c oldSOI = (SalesOrderInstallments__c)oldMap.get(newSOI.Id);

        // Run only if status changed to 'Paid'
        if (oldSOI.PaymentStatus__c != 'Paid' && newSOI.PaymentStatus__c == 'Paid') {
            if(!newSOI.Exclude_LPC__c){ toProcess.add(newSOI); }
            if (newSOI.SalesOrder__c != null) {salesOrderIdsToUpdate.add(newSOI.SalesOrder__c);
        }
        }if (newSOI.IsHandoverPayment__c == True && (oldSOI.PaymentStatus__c != 'Paid' && newSOI.PaymentStatus__c == 'Paid')){
            SoIdsToUpdate.add(newSOI.SalesOrder__c);
        }
    }

    if (!toProcess.isEmpty()) {SalesOrderInstallmentTriggerHelper.handleManualLPCCharges(toProcess);}
        if (!salesOrderIdsToUpdate.isEmpty()) {
   // DefaultSRContrroler.updateOutstandingAmountForSalesOrders(salesOrderIdsToUpdate);
}
       // if(!SoIdsToUpdate.isEmpty()){SalesOrderInstallmentTriggerHelper.updateSalesOrderPaymentStatus(SoIdsToUpdate);}
        
        // new logic for calcultion on salesorder level 1.1
         Set<Id> changedInstallmentIds = new Set<Id>();

        for (SObject s : newList) { SalesOrderInstallments__c newSOI = (SalesOrderInstallments__c)s;SalesOrderInstallments__c oldSOI = (SalesOrderInstallments__c)oldMap.get(newSOI.Id);

            if (newSOI.PaymentStatus__c != oldSOI.PaymentStatus__c) {changedInstallmentIds.add(newSOI.Id);}
        }

        if (!changedInstallmentIds.isEmpty()) { SalesOrderCollectionsServiceController.recalcFromInstallments(changedInstallmentIds);}

    }
}