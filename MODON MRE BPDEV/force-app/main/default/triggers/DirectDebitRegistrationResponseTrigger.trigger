trigger DirectDebitRegistrationResponseTrigger on DirectDebit_Registration_Response__c (after insert, after update, before insert, before update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DirectDebitRegistrationResponseHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isInsert) {
        DirectDebitRegistrationResponseHandler.handleBeforeInsert(Trigger.new);      
    }
}