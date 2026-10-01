@isTest
public class OffersPromotionTriggerHelperTest {
    @TestSetup static void setupdData(){
        Test.startTest();
        Project__c projectRecord = new Project__c();
        projectRecord.Name = 'Test Project';
        insert projectRecord;
        
        OffersPromotions__c offerPromotion = new OffersPromotions__c();
        offerPromotion.Project__c = projectRecord.Id;
        offerPromotion.Name = 'Test1';
        offerPromotion.OfferName__c = 'Test1';
        offerPromotion.StartDate__c = System.today()+1;
        offerPromotion.EndDate__c = System.today()+30;
        offerPromotion.Approval_Status__c = 'Approved';
        offerPromotion.SalesEventCampaignName__c = 'Test1';
        insert offerPromotion;
        
        OffersPromotions__c offerPromotion1 = new OffersPromotions__c();
        offerPromotion1.Id = offerPromotion.Id;
        update offerPromotion1;
        
        Test.stopTest();
    }
    @isTest static void projectOfferDupeCheck(){
        Test.startTest();
        OffersPromotions__c offerPromotion = new OffersPromotions__c();
        offerPromotion.Project__c = [SELECT Id FROM Project__c LIMIT 1].Id;
        offerPromotion.Name = 'Test1';
        offerPromotion.OfferName__c = 'Test1';
        offerPromotion.StartDate__c = System.today()+2;
        offerPromotion.EndDate__c = System.today()+30;
        offerPromotion.Approval_Status__c = 'Approved';
        offerPromotion.SalesEventCampaignName__c = 'Test1';
        
        try{
            insert offerPromotion;
        }catch(Exception ex){
            
        }
        Test.stopTest();
    }
}