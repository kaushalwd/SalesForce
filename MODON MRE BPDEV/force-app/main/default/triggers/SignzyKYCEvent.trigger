trigger SignzyKYCEvent on SignzyKYCPlatformEvent__e (after insert) {
    for (SignzyKYCPlatformEvent__e evt : Trigger.New) {
       SignzyKYCCalloutFuture.callWebservice(evt.AccountID__c,evt.DocumentID__c,evt.KYCID__c);
    }
}