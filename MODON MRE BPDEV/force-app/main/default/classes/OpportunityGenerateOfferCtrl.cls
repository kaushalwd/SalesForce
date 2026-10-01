public class OpportunityGenerateOfferCtrl {
    //*********** Checking the User Email to enable the Select Offers Option in Offer Selection Screen ****************//
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserEmail() {
        return [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
    }
    //*********** @Depricated - Functionality - Final Dev Freeze Code will be remove ****************//
    @AuraEnabled
    public static List<OffersPromotions__c> getOfferDetails(Id projectId){
        if(projectId <> null){ 
            return [SELECT Id,OfferName__c,Name FROM OffersPromotions__c WHERE Project__c =:projectId AND IsActive__c =true AND Approval_Status__c = 'Approved'];
        }
        return null;
    }
    //*********** Query the available Offer Line - Based on certain Criteria ****************//
    @AuraEnabled 
    public static offerLineWrapper queryOffers(Id projectId, Id opptyId, Id unitId,Id offerId,List<String> unitIdList){
        Decimal totalSalesValue = 0;
        offerLineWrapper offerWrapper = new offerLineWrapper();
        Opportunity accountData = [SELECT Id,CustomerType__c,UAE_Resident_Status__c,Nationality__c,AccountId FROM Opportunity WHERE Id =: opptyId];
        List<Unit__c> unitObjDataList = [SELECT Id,Type__c,Phase__c,TotalPrice__c,Phase__r.Project__c FROM Unit__c WHERE Id IN: unitIdList];
        Map<String,OfferLines__c> offerLinesMap = new Map<String,OfferLines__c>();
        Map<Id,Unit__c> unitMap = new Map<Id,Unit__c>();
        for(Unit__c unit: unitObjDataList){
            totalSalesValue += unit.totalPrice__c;  
            unitMap.put(unit.Id,unit);
        }
        //************ Query the offer line *** Based on Priority **************************************//
        for(OfferLines__c offerLines: [
            SELECT Id, OfferNameFormula__c, OfferName__r.Project__c, OfferType__c, OfferOn__c, Unit__c, Phase__c, PromoValue__c, Is_Default_Offer__c, IsActive__c, Offer_Approval_Status__c, Customer_Specific__c, Unit_Price_From__c, Unit_Price_To__c, OfferValue__c, Name, OfferName__c 
            FROM OfferLines__c 
            WHERE OfferName__r.IsActive__c = true 
            AND IsActive__c = true 
            AND Offer_Approval_Status__c = 'Approved' 
            ORDER BY CustomerSpecificFlag__c DESC, Unit_Price_From__c DESC, UnitSpecificFlag__c DESC, PhaseSpecific__c DESC
        ]){
            system.debug('offerLine Val:'+offerLines);
            if(!offerLinesMap.containsKey(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c) && offerLines.IsActive__c == true && offerLines.Offer_Approval_Status__c == 'Approved'){
                if(offerLines.Customer_Specific__c <> null || offerLines.Unit_Price_From__c <> null ||offerLines.Unit__c <> null || offerLines.Phase__c <> null || offerLines.OfferName__r.Project__c <> null){
                    if(offerLines.Customer_Specific__c <> null){
                        if(offerLines.Customer_Specific__c == accountData.AccountId){
                            offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                        }
                    }
                    else if(offerLines.Unit_Price_From__c <> null){
                        if(offerLines.Unit_Price_From__c <= totalSalesValue && offerLines.Unit_Price_To__c >= totalSalesValue){
                            offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                        }
                    }
                 //   for(Id unitIdvalue: unitMap.keySet()){
                    else if(offerLines.Unit__c <> null && unitMap.containsKey(unitId) && unitMap.get(unitId).Id <> null){
                            if(offerLines.Unit__c == unitMap.get(unitId).Id){
                                offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                            }
                        }
                    else if(offerLines.Phase__c <> null && unitMap.containsKey(unitId) && unitMap.get(unitId).Phase__c <> null){
                            if(offerLines.Phase__c == unitMap.get(unitId).Phase__c){
                                offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                            }
                        }
                  	 else if(offerLines.OfferName__r.Project__c <> null && unitMap.containsKey(unitId) && unitMap.get(unitId).Phase__r.Project__c <> null){
                            if(offerLines.OfferName__r.Project__c == unitMap.get(unitId).Phase__r.Project__c){
                                offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                            }
                        }
                   // }
                }	else{
                    offerLinesMap.put(offerLines.OfferName__c+'-'+offerLines.OfferType__c+'-'+offerLines.OfferOn__c,offerLines);
                }
            }
        }
        offerWrapper.unitId = unitId;
        offerWrapper.offerLinesList = offerLinesMap.values();
        System.debug('offerLinesMap:'+offerLinesMap.values());
        return offerWrapper;
    }
    public class offerLineWrapper{
        @AuraEnabled public string unitId;
        @AuraEnabled public List<OfferLines__c> offerLinesList = new List<OfferLines__c>();
    }
}