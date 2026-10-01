public class OfferLinesTriggerHandler extends TriggerHandler {
    //*** After Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        OfferLinesTriggerHelper.validateuniqueOffers(newList,null);
    } 
    //*** After Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
         OfferLinesTriggerHelper.lockApprovalRecord(newList,oldMap);
         OfferLinesTriggerHelper.validateuniqueOffers(newList,oldMap);
    }
}