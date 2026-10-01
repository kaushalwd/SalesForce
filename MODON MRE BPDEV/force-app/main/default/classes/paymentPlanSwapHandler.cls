public  without sharing class paymentPlanSwapHandler  implements ITriggerHandler{
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return isTriggerDisabled;
    }
    
    public void beforeInsert(List<sObject> newList) {
       List<ServiceRequest__c> newSRs = (List<ServiceRequest__c>) newList;
      paymentPlanSwapHelper.validateNoPaymentsInProgress(newSRs);
      paymentPlanSwapHelper.populateAccountAndUnit(newSRs); 
      paymentPlanSwapHelper.updatePreviousPaymentPlan(newSRs); 
      for (ServiceRequest__c sr : newSRs) {
        PaymentPlanSwapHelper.evaluateSwap(sr);
    }
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
       PaymentPlanSwapHelper.emptyMethod();
    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        // PaymentPlanSwapHelper.emptyMethod();
       /*List<ServiceRequest__c> newSRs = (List<ServiceRequest__c>) newList;
      paymentPlanSwapHelper.validateNoPaymentsInProgress(newSRs);*/
        
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        PaymentPlanSwapHelper.emptyMethod();
    }       
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
         PaymentPlanSwapHelper.emptyMethod();
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
         PaymentPlanSwapHelper.emptyMethod();
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
         PaymentPlanSwapHelper.emptyMethod();
    }
}