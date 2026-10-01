@isTest
public class OpportunityGenerateOfferCtrlTest {
    @testSetup
    static void setupData() {

        Account acct = new Account(Name = 'Test Account');
        Account otherAcct = new Account(Name = 'Other Account');
        insert new List<Account>{ acct, otherAcct };

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            CustomerType__c = 'New Client',
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'Afghanistan',
            EmiratesIDExpiryDate__c = Date.today().addDays(30),
            EIDNumber__c = '784-1234-1234567-1'
        );
        insert opp;

        Project__c proj = new Project__c(Name = 'Test Project');
        Project__c otherProj = new Project__c(Name = 'Other Project');
        insert new List<Project__c>{ proj, otherProj };

        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = proj.Id);
        Phase__c otherPhase = new Phase__c(Name = 'Other Phase', Project__c = otherProj.Id);
        insert new List<Phase__c>{ phase, otherPhase };

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Type__c = 'Apartment',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            BasePrice__c = 1234,
            AdditionalPrice__c = 1234,
            PlotNo__c = '101-5B'
        );
        Unit__c otherUnit = new Unit__c(
            Name = 'Other Unit',
            Type__c = 'Apartment',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Phase__c = otherPhase.Id,
            BasePrice__c = 2000,
            AdditionalPrice__c = 100,
            PlotNo__c = '202-9A'
        );
        insert new List<Unit__c>{ unit, otherUnit };

        unit = [SELECT Id, TotalPrice__c FROM Unit__c WHERE Id = :unit.Id];
        Decimal totalSalesValue = unit.TotalPrice__c;

        OffersPromotions__c offerPromo = new OffersPromotions__c(
            Project__c = proj.Id,
            OfferName__c = 'Test Offer',
            Name = 'Test Offer',
            Approval_Status__c = 'Approved',
            StartDate__c = System.today(),
            EndDate__c = System.today() + 30
        );
        OffersPromotions__c genericPromo = new OffersPromotions__c(
            OfferName__c = 'Generic Offer',
            Name = 'Generic Offer',
            Approval_Status__c = 'Approved',
            StartDate__c = System.today(),
            EndDate__c = System.today() + 30
        );
        insert new List<OffersPromotions__c>{ offerPromo, genericPromo };

        insert new List<OfferLines__c>{
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Additional Discount',
                OfferOn__c = 'Selling Price',
                OfferValueType__c = '%',
                Customer_Specific__c = acct.Id,
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Additional Discount',
                OfferOn__c = 'Selling Price',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'ADM Fees',
                OfferValueType__c = '%',
                Unit_Price_From__c = totalSalesValue - 100,
                Unit_Price_To__c = totalSalesValue + 100,
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'Transfer Charges',
                OfferValueType__c = 'AED',
                Unit__c = unit.Id,
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'Service Charges',
                OfferValueType__c = 'Years',
                Phase__c = phase.Id,
                OfferValue__c = 1,
                Waiver_Percent__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Rebate',
                OfferOn__c = 'Net Amount',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Premium',
                OfferOn__c = 'Net Amount',
                OfferValueType__c = '%',
                Customer_Specific__c = otherAcct.Id,
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = offerPromo.Id,
                OfferType__c = 'Dari Charges',
                OfferOn__c = 'ADM Fees',
                OfferValueType__c = '%',
                Unit__c = otherUnit.Id,
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            ),
            new OfferLines__c(
                OfferName__c = genericPromo.Id,
                OfferType__c = 'Points',
                OfferOn__c = 'Net Amount',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                IsActive__c = true,
                Offer_Line_Approval_Status__c = 'Approved'
            )
        };
    }

    @isTest
    static void testGetCurrentUserEmail() {
        Test.startTest();
        String email = OpportunityGenerateOfferCtrl.getCurrentUserEmail();
        Test.stopTest();
        System.assertNotEquals(null, email);
    }

    @isTest
    static void testGetOfferDetails() {
        Project__c proj = [SELECT Id FROM Project__c WHERE Name = 'Test Project' LIMIT 1];

        Test.startTest();
        List<OffersPromotions__c> offers = OpportunityGenerateOfferCtrl.getOfferDetails(proj.Id);
        List<OffersPromotions__c> noProject = OpportunityGenerateOfferCtrl.getOfferDetails(null);
        Test.stopTest();

        System.assertNotEquals(null, offers, 'Approved active offers for the project should be returned');
        System.assertEquals(null, noProject, 'Null project id returns null');
    }

    @isTest
    static void testQueryOffersAllConditions() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c unit = [SELECT Id, TotalPrice__c FROM Unit__c WHERE Name = 'Test Unit' LIMIT 1];
        OffersPromotions__c offerPromo = [SELECT Id, Project__c FROM OffersPromotions__c WHERE Name = 'Test Offer' LIMIT 1];

        Test.startTest();
        OpportunityGenerateOfferCtrl.offerLineWrapper wrapper = OpportunityGenerateOfferCtrl.queryOffers(
            offerPromo.Project__c,
            opp.Id,
            unit.Id,
            offerPromo.Id,
            new List<String>{ unit.Id }
        );
        OpportunityGenerateOfferCtrl.offerLineWrapper emptyBasket = OpportunityGenerateOfferCtrl.queryOffers(
            offerPromo.Project__c,
            opp.Id,
            unit.Id,
            offerPromo.Id,
            new List<String>()
        );
        Test.stopTest();

        System.assertNotEquals(null, wrapper);
        System.assertNotEquals(null, wrapper.offerLinesList, 'Eligible offer lines should be returned');
        System.assert(wrapper.offerLinesList.size() > 0, 'At least one matching offer line is expected');
        System.assertNotEquals(null, emptyBasket);
    }
}