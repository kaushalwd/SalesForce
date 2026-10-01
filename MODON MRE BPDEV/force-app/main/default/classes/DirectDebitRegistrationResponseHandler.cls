public class DirectDebitRegistrationResponseHandler {
     public static void handleAfterInsert(List<DirectDebit_Registration_Response__c> newResponses) {
        DirectDebitRegistrationResponseHelper.processResponses(newResponses);
    }
	public static void handleBeforeInsert(List<DirectDebit_Registration_Response__c> newResponses) {
        DirectDebitRegistrationResponseHelper.processResponsesBeforeUpdate(newResponses);
    }
}