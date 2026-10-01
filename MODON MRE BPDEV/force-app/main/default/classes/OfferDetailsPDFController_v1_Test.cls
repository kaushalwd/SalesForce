@isTest
public class OfferDetailsPDFController_v1_Test {

    @testSetup
    static void setupData() {
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;
        
Account acc = new Account(Name = 'Test Account');
insert acc;

Contact con = new Contact(
    LastName = 'Test Contact',
    AccountId = acc.Id
);
insert con;

Opportunity opp = new Opportunity(
    Name = 'Test Opportunity',
    StageName = 'Prospecting',
    CloseDate = Date.today().addDays(30),
    AccountId = acc.Id,
    Type = 'New',
    LeadSource = 'Web',
    Probability = 10,
    Nationality__c = 'Pakistan',
    UAE_Resident_Status__c = 'Resident',
    EmiratesIDExpiryDate__c = Date.TODAY(),
    EIDNumber__c = '784-1997-1234567-8'
);
insert opp;

OpportunityContactRole ocr = new OpportunityContactRole(
    OpportunityId = opp.Id,
    ContactId = con.Id,
    Role = 'Decision Maker',
    IsPrimary = true
);
insert ocr;

        // Create Project & Phase
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = project.Id);
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            BasePrice__c = 500000,
            PlotNo__c = '100',
            Number_Of_Bedrooms__c = '3',
            UnitClassification__c = 'Villa'
        );
        insert unit;

        // Create Unit Option
        Unit_Option__c unitOption = new Unit_Option__c(
            Name = 'Test Unit Option',
            Unit__c = unit.Id,
            BasePrice__c = 500000,
            PlotAreasqm__c = 100,
            NumberofBedrooms__c = 3,
            Internal_Area__c = 80,
            BalconyArea__c = 20,
            TotalGrossSellableAreaGSA__c = 120,
            PlotNo__c = '1234'
        );
        insert unitOption;

        // Create Payment Plan
        PaymentPlan__c plan = new PaymentPlan__c(Name = 'Test Plan', Type__c = 'Standard');
        insert plan;

        PaymentInstallements__c pi = new PaymentInstallements__c(
            Name = 'Handover Payment',
            PaymentInstallment__c = plan.Id,
            IsHandoverPayment__c = true,
            MilestoneDate__c = Date.today().addMonths(6),
            MilestoneNumber__c = 1
        );
        insert pi;

        ContentVersion cv = new ContentVersion(
            Title = 'interior_image',
            PathOnClient = 'Test.jpg',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = unitOption.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @isTest
    static void testControllerWithUnitOption() {
        // Fetch required data
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Unit_Option__c uo = [SELECT Id FROM Unit_Option__c LIMIT 1];
        PaymentPlan__c plan = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('/apex/DummyPage'));

        // Set parameters
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('unitOption', uo.Id);
        ApexPages.currentPage().getParameters().put('selectedPayment', plan.Id);
        ApexPages.currentPage().getParameters().put('customerName', 'Test Customer');

        OfferDetailsPDFController_v1 controller = new OfferDetailsPDFController_v1();
        System.assertNotEquals(null, controller.customerName);
        System.assert(controller.totalPrice > 0);
        Test.stopTest();
    }

    @isTest
    static void testControllerWithUnit() {
        // Fetch required data
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c plan = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Test.startTest();
        Test.setCurrentPageReference(new PageReference('/apex/DummyPage'));

        // Set parameters
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('currentUnit', unit.Id);
        ApexPages.currentPage().getParameters().put('selectedPayment', plan.Id);
        ApexPages.currentPage().getParameters().put('customerName', '');

        OfferDetailsPDFController_v1 controller = new OfferDetailsPDFController_v1();
        System.assertNotEquals(null, controller.projectName);
        Test.stopTest();
    }

    @isTest
    static void testGenerateRandomString() {
        String result = OfferDetailsPDFController_v1.generateRandomString(10);
        System.assertEquals(10, result.length());
    }

    @isTest
    static void testGetImageUrlsByCategory() {
        Project__c uo = [SELECT Id FROM Project__c LIMIT 1];
        OfferDetailsPDFController_v1.ImageCategoryWrapper wrapper = OfferDetailsPDFController_v1.getImageUrlsByCategory(uo.Id,'test','3','');
        System.assert(wrapper.interiorImages.size() == 0);
    }
}