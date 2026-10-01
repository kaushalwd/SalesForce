trigger ServiceRequestTrigger on ServiceRequest__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
   TriggerDispatcher.run(new ServiceRequestTriggerHandler());
   // TriggerDispatcher.run(new paymentPlanSwapHandler());
    
    
  
}