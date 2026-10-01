trigger InvoiceBundleTrigger on Invoice_Bundle__c (before insert, before update, after insert, after update) {
    new InvoiceBundleTriggerHandler().run('Invoice_Bundle__c');
}