trigger DocuSignRecipientStatusTrigger on dfsle__RecipientStatus__c (after insert) {
    new DocuSignRecipientStatusTriggerHandler().run('dfsle__RecipientStatus__c');
}