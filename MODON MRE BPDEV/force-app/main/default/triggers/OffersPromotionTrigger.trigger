trigger OffersPromotionTrigger on OffersPromotions__c (before insert,before update,after insert,after update) {
  //  try {
        new OffersPromotionTriggerHandler().run('OffersPromotions__c');
   /* } catch(Exception e) {        
            LoggerService.save(LoggerService.createApexLog(e,'OffersPromotionTrigger ','OffersPromotionTriggerHandler',''));
            throw e;
    } */
}