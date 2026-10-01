/**********************************************************************************************************************
* Name               : PaymentPlanInstallmentHelper
* Description        : Handler class for PaymentInstallements__c trigger logic
* Usage              : Called from PaymentPlanInstallmentTriggerHandler
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               19 Aug 2025     Initial Draft       
**********************************************************************************************************************/
public without sharing class PaymentInstallmentTriggerHandler extends TriggerHandler {
    
    // Before Insert
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        List<PaymentInstallements__c> installments = (List<PaymentInstallements__c>) newList;
        for (PaymentInstallements__c rec : installments) {
            rec.Nawy_Status__c = 'Pending Sync';
        }
    }
    
    // After Insert
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        List<PaymentInstallements__c> installments = (List<PaymentInstallements__c>) newList;
        Modon_Egypt_PaymentInstallmentHelper.syncPaymentInstallmentToNawy(installments);
    }
    
    // Before Update
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<PaymentInstallements__c> newInstallments = (List<PaymentInstallements__c>) newList;
        Map<Id, PaymentInstallements__c> oldInstallments = new Map<Id, PaymentInstallements__c>();
        
        for (Id id : oldMap.keySet()) {
            oldInstallments.put(id, (PaymentInstallements__c) oldMap.get(id));
        }
        
        for (PaymentInstallements__c newRec : newInstallments) {
            PaymentInstallements__c oldRec = oldInstallments.get(newRec.Id);
            
            Boolean hasChanged = false;
            
            // Add fields you want to track for changes
            List<String> trackedFields = new List<String>{ 'Milestone__c', 'MilestoneDate__c' };
                
                for (String fieldName : trackedFields) {
                    Object newValue = newRec.get(fieldName);
                    Object oldValue = oldRec.get(fieldName);
                    
                    if (newValue != oldValue) {
                        hasChanged = true;
                        break;
                    }
                }
            
            if (hasChanged) {
                newRec.Nawy_Status__c = 'Pending Sync';
            }
        }
    }
    
    
    // After Update
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<PaymentInstallements__c> installments = (List<PaymentInstallements__c>) newList;
        Map<Id, PaymentInstallements__c> oldInstallments = new Map<Id, PaymentInstallements__c>();
        for (Id paymentPlanId : oldMap.keySet()) {
            oldInstallments.put(paymentPlanId, (PaymentInstallements__c) oldMap.get(paymentPlanId));
        }
        Modon_Egypt_PaymentInstallmentHelper.syncUpdatedPaymentInstallmentToNawy(installments, oldInstallments);
    }
    
    // After Delete
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap) {
        // No logic needed for delete
    }
}