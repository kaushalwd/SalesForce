trigger ChequeDetailsTrigger on Cheque_Details__c (before insert, before update) {
	  try {
        new ChequeDetailsTriggerHandler().run('Cheque_Details__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'ChequeDetailsTrigger','ChequeDetailsTrigger',''));throw e;
    } 
}