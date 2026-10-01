/**********************************************************************************************************************
* Name               : OffersAndCollectionsTrigger                                                         
* Description        : Apex Trigger to handle before/after events on Offers_Collections__c.
* Usage              : Called by system processes on Offers_Collections__c record create, update, delete, undelete
* Created By         : AMGS                                                   
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Fatima Khan          13 Nov 2025     Initial Draft       
******************************************************************************************************************/
trigger OffersAndCollectionsTrigger on Offers_Collections__c (after update) {
   /* try {
        new OffersAndCollectionsTriggerHandler().run(Trigger.new, Trigger.operationType);
    } catch(Exception e) {
        LoggerService.save(LoggerService.createApexLog(e, 'OffersAndCollectionsTrigger', 'OffersAndCollectionsTriggerHandler', ''));
        throw e; 
    } */
    if(Trigger.isUpdate && Trigger.isAfter){
        OffersAndCollectionsTriggerHelper.createCreditNoteWaiverADM(trigger.new,trigger.OldMap);
    }
}