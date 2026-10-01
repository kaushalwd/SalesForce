@isTest
public class OfferLinesTriggerHelperTest {
    @TestSetup static void testData(){
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
        
        //*** ADM Waiver ***//
        OfferLines__c offerLine = new OfferLines__c();
        offerLine.OfferName__c = offerPromotion.Id;
        offerLine.OfferType__c = 'Waiver';
		offerLine.OfferOn__c = 'ADM Fees';
        offerLine.OfferValueType__c = '%';
        offerLine.OfferValue__c = 1;
        offerLine.Offer_Line_Approval_Status__c = 'Approved';
        offerLine.Is_Default_Offer__c = true;
        offerLine.IsActive__c = true;
       
        insert offerLine;
        
        OfferLines__c offerLine1 = new OfferLines__c();
        offerLine1.OfferValue__c = 1;
        offerLine1.Id = offerLine.Id;
       
        update offerLine1;
        
        
        Test.stopTest();
    }
    @isTest static void testUniqueKeyCombination(){
        Test.startTest();
        OfferLines__c offerLine = new OfferLines__c();
        offerLine.OfferName__c = [SELECT Id FROM OffersPromotions__c LIMIT 1].Id;
        offerLine.OfferType__c = 'Waiver';
		offerLine.OfferOn__c = 'ADM Fees';
        offerLine.OfferValueType__c = '%';
        offerLine.OfferValue__c = 1;
        offerLine.Offer_Line_Approval_Status__c = 'Approved';
        offerLine.Is_Default_Offer__c = true;
        offerLine.IsActive__c = true;
       
        try{
            insert offerLine;
        }catch(Exception ex){
            
        }
        
        Test.stopTest();
    }
    @isTest static void exceptionTest(){
         try{
             OfferLines__c offerLine = new OfferLines__c();
             insert offerLine;
        }catch(Exception ex){
            
        }
    }
}