/**********************************************************************************************************************
* Name               : OfferLinesTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the lead record.
* Usage              : Called by system processes on Offer Lines record create, update
* Created By         : Dinesh                                                    
* --------------------------------------------------------------------------------------------------------------------     
******************************************************************************************************************/
trigger OfferLinesTrigger on OfferLines__c (before insert,before update,after insert,after update) {
    //try {
        new OfferLinesTriggerHandler().run('OfferLines__c');
	/*} catch(Exception e) {        
            LoggerService.save(LoggerService.createApexLog(e,'OfferLinesTrigger','OfferLinesTriggerHandler',''));
            throw e;
    } */ 
}