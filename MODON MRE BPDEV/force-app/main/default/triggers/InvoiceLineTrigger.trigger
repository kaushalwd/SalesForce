trigger InvoiceLineTrigger on Invoice_Line__c (before insert,before update, after insert, after update) {
	 new InvoiceLineTriggerHandler().run('Invoice_Line__c');
}