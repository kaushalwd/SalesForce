/**********************************************************************************************************************
* Name               : PaymentPlanInstallmentHelper
* Description        : Handler class for PaymentInstallements__c trigger logic
* Usage              : Called from PaymentPlanInstallmentTriggerHandler
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               19 Aug 2025     Initial Draft       
**********************************************************************************************************************/
public without sharing class PaymentPlanTriggerHandler extends TriggerHandler {
    
    // Before Insert
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        List<PaymentPlan__c> plans = (List<PaymentPlan__c>) newList;
        for (PaymentPlan__c plan : plans) {
            plan.Nawy_Status__c = 'Pending Sync';
        }
    }
    
    // After Insert
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        List<PaymentPlan__c> installments = (List<PaymentPlan__c>) newList;
        Modon_Egypt_PaymentPlanTriggerHelper.syncPaymentPlanToNawy(installments);
    }
    
    // Before Update
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<PaymentPlan__c> newPlans = (List<PaymentPlan__c>) newList;
        Map<Id, PaymentPlan__c> oldPlans = new Map<Id, PaymentPlan__c>();
        
        for (Id planId : oldMap.keySet()) {
            oldPlans.put(planId, (PaymentPlan__c) oldMap.get(planId));
        }
        
        for (PaymentPlan__c newRec : newPlans) {
            PaymentPlan__c oldRec = oldPlans.get(newRec.Id);
            
            // Check if any tracked field has changed
            Boolean hasChanged = false;
            
            // Fields to track for changes
            List<String> trackedFields = new List<String>{ 'ExpiryDate__c', 'Status__c' };                
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
        List<PaymentPlan__c> installments = (List<PaymentPlan__c>) newList;
        Map<Id, PaymentPlan__c> oldInstallments = new Map<Id, PaymentPlan__c>();
        for (Id paymentPlanId : oldMap.keySet()) {
            oldInstallments.put(paymentPlanId, (PaymentPlan__c) oldMap.get(paymentPlanId));
        }
        Modon_Egypt_PaymentPlanTriggerHelper.syncPaymentPlanUpdatesToNawy(installments, oldInstallments);
    }
    
    
    // After Delete
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap) {
        // No logic needed for delete
    }
}