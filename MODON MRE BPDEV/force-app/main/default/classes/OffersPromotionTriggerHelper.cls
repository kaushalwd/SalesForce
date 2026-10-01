public class OffersPromotionTriggerHelper {
    public static void duplicateProjectOfferCheck(list<SObject> newList){
        Set<Id> projectId = new Set<Id>();
        for(OffersPromotions__c offers: (List<OffersPromotions__c>) newList){
            projectId.add(offers.Project__c);
        }
        Map<Id,decimal> existingProjectCountMap = new Map<Id,decimal>();
        for(AggregateResult agg:[SELECT COUNT(Id)TOTAL,Project__c PRJT FROM OffersPromotions__c WHERE IsActive__c = true AND Project__c IN:projectId GROUP BY Project__c]){
            existingProjectCountMap.put((Id) agg.get('PRJT'),(Decimal) agg.get('TOTAL'));
        }
        for(OffersPromotions__c offers: (List<OffersPromotions__c>) newList){
            if(existingProjectCountMap.containsKey(offers.Project__c)){
                offers.addError('This Project related active Offers & Promotion Already Exist!');
            }
        }
    }
}